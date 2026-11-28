extends SceneTree
## Real Workbench, real HTTPRequest, real native worker. Input is routed through
## embedded Window/Button hit testing; never substitutes close_requested.emit().
## The fixture profile and every endpoint are created by the Python loopback runner.
const Setup = preload("res://scripts/workbench_setup.gd")
const CANARY := "art-fixture-private-key::2026-QA"
const RESPONSE_CHUNK_BYTES := 256*1024
const MIB_RESPONSE_MODELS := ["fixture-large","fixture-large-error","fixture-large-envelope-error","fixture-malicious-usage"]
const PAYLOAD_MIB_TRANSPORT_SECONDS := 10.0
const PAYLOAD_NEAR_LIMIT_TRANSPORT_SECONDS := 90.0
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var wb: Control
var panel: Window
var spec: Dictionary = {}
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var unavailable: Array[String] = []
var monitor := false
var frame_previous := 0
var frame_largest := 0
var frame_gaps: Array[int] = []
var native_activity_count := 0
var active_manual_activity_count := 0
var transport_manual_activity_count := 0
var baseline_frames: Dictionary = {}
var shutdown_metrics: Dictionary = {}
var preparation_type: Script
var preparation_budgets: Array[Dictionary] = []


func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	process_frame.connect(_frame)
	run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	print("ART_FINAL_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)
	return ok


func _frame() -> void:
	if not monitor: return
	var now := Time.get_ticks_usec()
	var gap := now-frame_previous
	frame_largest = maxi(frame_largest,gap)
	if frame_gaps.size() < 20000: frame_gaps.append(gap)
	frame_previous = now


func begin_measurement() -> void:
	frame_gaps.clear()
	frame_largest = 0
	frame_previous = Time.get_ticks_usec()
	monitor = true


func end_measurement() -> Dictionary:
	monitor = false
	var samples := frame_gaps.duplicate()
	samples.sort()
	return {"frames":samples.size(),"max_usec":frame_largest,
		"p95_usec":samples[mini(samples.size()-1,int(samples.size()*0.95))] if not samples.is_empty() else 0}


func until(predicate: Callable, limit_ms: int = 15000) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return predicate.call()


func ready() -> bool:
	return is_instance_valid(host) and wb != null and not wb.applied.is_empty() and not wb.busy() \
		and wb.paint_editor != null and not wb.paint_editor.busy() \
		and host.pending_microscenario_apply.is_empty() and not host.simulation_worker.paint_state().busy \
		and not host.simulation_worker.paint_state().get("legacy_busy",false)


func settled() -> bool:
	return ready() and not panel.provider.active and not panel.executor.active \
		and not panel.capturing and not panel.log_draw and not panel._manual_log_pending and panel.remaining_turns == 0 \
		and (not panel.provider.has_method("response_preparation_active") or not panel.provider.response_preparation_active()) \
		and (not panel.provider.has_method("request_preparation_active") or not panel.provider.request_preparation_active())


func preparation_running(direction: String = "response") -> bool:
	var method := direction+"_preparation_active"
	if not panel.provider.has_method(method) or not panel.provider.call(method): return false
	# Older response-only checkpoints used a separate private slot. Retaining
	# this fallback keeps their source-specific negative/positive probe usable.
	var slot := "_preparation" if panel.provider.has_method("request_preparation_active") else "_response_preparation"
	var job: Variant = panel.provider.get(slot)
	return job != null and not job.reaped and not WorkerThreadPool.is_task_completed(job.task_id)


func preparation_pending_count() -> int:
	if preparation_type == null: preparation_type = load("res://scripts/art_response_preparation.gd")
	return preparation_type.pending_count()


func fixture_response_bound(model_name: String) -> int:
	if model_name in ["fixture-near-limit","fixture-large-assistant"] or model_name.begins_with("fixture-preparation-"):
		return 16*1024*1024
	if model_name in MIB_RESPONSE_MODELS: return 1024*1024+4096
	return 0


func fixture_response_minimum(model_name: String) -> int:
	var bound := fixture_response_bound(model_name)
	if bound==16*1024*1024: return bound-8192
	return 1024*1024 if bound>0 else 1


func fixture_transport_seconds(model_name: String, endpoint_name: String = "endpoint") -> float:
	if model_name in ["fixture-timeout","fixture-blackhole-timeout"] or endpoint_name=="slow_connect_endpoint": return 1.0
	if model_name.begins_with("fixture-outgoing-"): return 20.0
	var bound := fixture_response_bound(model_name)
	if bound==16*1024*1024: return PAYLOAD_NEAR_LIMIT_TRANSPORT_SECONDS
	if bound>0: return PAYLOAD_MIB_TRANSPORT_SECONDS
	return 3.0


func fixture_budget_record(model_name: String, transport_seconds: float, observation_ms: int) -> Dictionary:
	var response_bound := fixture_response_bound(model_name)
	return {"fixture":model_name,"transport_seconds":transport_seconds,
		"authoring_run_seconds":maxf(15.0,transport_seconds*2.0),"worker_observation_ms":observation_ms,
		"settlement_ms":maxi(12000,int(transport_seconds*2000.0)+5000),
		"response_bound_bytes":response_bound,"download_chunk_bytes":RESPONSE_CHUNK_BYTES,
		"full_chunk_body_reads_for_size_bound":ceili(float(response_bound)/RESPONSE_CHUNK_BYTES),
		"body_read_assumption":"Each read fills one configured chunk; partial reads can require more process frames",
		"budget_frame_basis_usec":250000}


func observe_incoming_preparation(limit_ms: int) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec()<deadline:
		if preparation_running(): return true
		# A completed/failed transport cannot later produce an unfinished job.
		# Preserve its failure immediately instead of consuming the whole budget.
		if not panel.provider.active: return false
		await process_frame
	return preparation_running()


func pointer_click(viewport: Viewport, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.position = at
		event.global_position = at
		viewport.push_input(event,true)


func click(button: Button) -> void:
	pointer_click(root,Vector2(button.get_window().position)+button.get_global_rect().get_center())


func ordinary_x() -> void:
	# Godot embedded titlebar geometry; this enters Viewport's close-button
	# hit testing and then the ordinary Window close_requested binding.
	var close_h_offset: int = panel.get_theme_constant("close_h_offset")
	var close_v_offset: int = panel.get_theme_constant("close_v_offset")
	var close_icon: Texture2D = panel.get_theme_icon("close")
	var center := Vector2(panel.position)+Vector2(panel.size.x-close_h_offset+close_icon.get_width()*0.5,
		-close_v_offset+close_icon.get_height()*0.5)
	pointer_click(root,center)


func log_length() -> int:
	if panel.provider.log_path.is_empty(): return 0
	var file := FileAccess.open(panel.provider.log_path,FileAccess.READ)
	return file.get_length() if file != null else 0


func event_counts(offset: int) -> Dictionary:
	var result := {}
	var file := FileAccess.open(panel.provider.log_path,FileAccess.READ)
	if file == null: return result
	file.seek(offset)
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var entry: Variant = JSON.parse_string(line)
		if entry is Dictionary:
			var kind := str(entry.get("kind",""))
			result[kind] = int(result.get(kind,0))+1
	return result


func native_tick() -> int:
	return int(host.simulation_worker.paint_state().get("tick",-1))


func optional_metrics(object: Object, name: String) -> Variant:
	var value: Variant = object.get(name)
	return value.duplicate(true) if value is Dictionary else value


func fixture_received(model_name: String) -> bool:
	return FileAccess.file_exists(str(spec.accepted_dir).path_join(model_name))


func fixture_post_arrivals() -> int:
	var directory := DirAccess.open(str(spec.post_arrival_dir))
	return directory.get_files().size() if directory != null else -1


func captured_cell(point: Vector2i) -> int:
	if not check(await until(ready),"native edit settles before stored readback"): return -1
	var worker: RefCounted = host.simulation_worker
	# Pausing can leave one already admitted simulation tick. Wait for the
	# owner's paused boundary before capturing an expected generation/tick.
	for _index in range(4): await process_frame
	var state: Dictionary = worker.paint_state()
	var admitted: Dictionary = worker.paint_queue({"kind":"capture","region":Rect2i(point,Vector2i.ONE),
		"expected_generation":state.generation,"expected_revision":state.revision,"expected_tick":state.tick,
		"expected_authoring_generation":state.get("authoring_generation",1)})
	if not check(admitted.get("status")=="queued","stored native readback admitted"): return -1
	if not check(await until(func() -> bool: return bool(worker.paint_state().receipt_ready)),"stored native readback ready"): return -1
	var receipt: Dictionary = worker.paint_take_result()
	if receipt.get("status")!="completed": print("ART_FINAL_CAPTURE_FAILURE ",JSON.stringify(receipt))
	if not check(receipt.get("status")=="completed" and receipt.get("operation_id")==admitted.operation_id \
		and receipt.get("backend")=="CyberNativeCellWorld","stored readback owns matching native receipt"): return -1
	var values: PackedInt32Array = receipt.get("materials",PackedInt32Array())
	return int(values[0]) if values.size()==1 else -1


func fresh_world() -> bool:
	if not await until(ready,90000): return check(false,"previous native World settles")
	var data := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))
	data.edits = [[0,500,512,12,58],[210,60,64,16,2]]
	if not check(wb.apply(data),"ordinary 512-square native Workbench installation queued"): return false
	return check(await until(ready,90000),"ordinary native Workbench installation acknowledged")


func prepare_panel(model_name: String, endpoint_name: String = "endpoint", timeout_seconds: float = 2.0) -> void:
	panel.show()
	panel.position = Vector2i(240,160)
	panel.size = Vector2i(640,400)
	if panel.current_provider != "LM Studio": panel.change_provider(0)
	panel.source.select(0)
	panel.input_mode.select(1)
	panel.image_input.button_pressed = false
	panel.endpoint.text = str(spec[endpoint_name])
	panel.model.text = model_name
	panel.keys["LM Studio"] = CANARY
	panel.input.text = "Return the synthetic drawing fixture."
	panel.turn_limit.value = 1
	# This controls the complete authoring run, including value preparation,
	# whereas HTTPRequest.timeout covers transport. Large-response success
	# fixtures need a run budget larger than their transport budget.
	panel.run_seconds.value = maxf(15,timeout_seconds*2)
	panel.seconds.value = timeout_seconds
	panel.minimum_interval.value = 0
	panel.fields[0].value = 0
	panel.fields[1].value = 0
	panel.fields[2].value = 512
	panel.fields[3].value = 512
	panel.next_request_ms = 0
	panel.provider_wait_ms = 0
	panel.remaining_turns = 0
	panel.context_mode.select(1)
	for _index in range(3): await process_frame


func execute_case(label: String, model_name: String, endpoint_name: String = "endpoint", action: String = "hide",
		expectation: String = "failure", manual_activity: bool = true) -> void:
	checkpoint(label+" before Send")
	if not check(await until(settled),label+" prior model/native work settles"): return
	var outgoing := model_name.begins_with("fixture-outgoing-")
	# Godot 4.7's bounded nonblocking HTTPRequest reads at most one 64 KiB
	# body chunk per process frame. The measured software Windows display can
	# run near 5 Hz: 17/256 reads alone need roughly 4.25/64 s at a conservative
	# 0.25 s per frame. These fixture budgets do not change product defaults.
	var request_timeout := fixture_transport_seconds(model_name,endpoint_name)
	var observation_ms := 0
	if outgoing: observation_ms = 25000
	elif model_name.begins_with("fixture-preparation-"): observation_ms = int((request_timeout+15.0)*1000.0)
	var configured_budgets := fixture_budget_record(model_name,request_timeout,observation_ms)
	await prepare_panel(model_name,endpoint_name,request_timeout)
	if outgoing: panel.context_mode.select(0) # Full context is the measured request.
	var initial_log := str(panel.provider.log_path)
	var offset := log_length()
	var serial: int = panel.provider.serial
	var request_admissions: Array[Dictionary] = []
	var observe_request_start := func(id: int, request_offset: int) -> void:
		request_admissions.append({"id":id,"offset":request_offset})
	if outgoing: panel.provider.request_started.connect(observe_request_start)
	# Filesystem observations stay outside the Send/Stop/frame measurement.
	var post_arrivals_before := fixture_post_arrivals() if outgoing and expectation=="cancel" else -1
	var started := Time.get_ticks_usec()
	var tick_before := native_tick()
	begin_measurement()
	click(panel.draw)
	var send_usec := Time.get_ticks_usec()-started
	var send_stages: Variant = optional_metrics(panel,"last_send_timing")
	check(panel.provider.serial==serial+1 and panel.provider.active,label+" Send button hit-test starts one request")
	var stop_was_active := false
	var preparation_observed := false
	var outgoing_preparation_observed := false
	var stop_observation := {}
	var bounded_retry := {}
	if model_name.begins_with("fixture-preparation-"):
		preparation_observed = await observe_incoming_preparation(observation_ms)
		check(preparation_observed,label+" real HTTP response is actively running CPU preparation")
		check(panel.provider.response_preparation_jobs==1,label+" retains one preparation job")
	if outgoing:
		# Wait only for the ordinary UI projection while real CPU work remains.
		# A completed job cannot later qualify Stop-before-dispatch; fail that
		# precondition promptly instead of waiting for a nonexistent second job.
		if action=="stop_hide":
			var stop_deadline := Time.get_ticks_msec()+25000
			while panel.visible and panel.stop.disabled and panel.provider.active and panel.provider.request==null \
					and preparation_running("request") and Time.get_ticks_msec()<stop_deadline:
				await process_frame
		outgoing_preparation_observed = preparation_running("request")
		check(outgoing_preparation_observed,label+" actual Full context is actively running CPU preparation")
		check(panel.provider.request_preparation_jobs==1 and panel.provider.request==null,label+" one request value job precedes HTTP admission")
	if model_name.begins_with("fixture-blackhole-"):
		check(await until(func() -> bool: return fixture_received(model_name),3000),label+" actual POST received before withholding all response bytes")
		for _index in range(3): await process_frame
	if action=="stop_hide":
		if not outgoing: await process_frame
		if outgoing:
			# No yield separates this observation from the real mouse click. A
			# worker finishing in the meantime still cannot admit HTTP until the
			# main-thread reaper runs after this synchronous Stop input.
			stop_observation = {"panel_visible":panel.visible,"button_visible":panel.stop.is_visible_in_tree(),
				"button_enabled":not panel.stop.disabled,"unfinished_task":preparation_running("request"),
				"request_absent":panel.provider.request==null,"provider_active":panel.provider.active,
				"serial":panel.provider.serial,"request_admissions":request_admissions.size(),
				"since_send_usec":Time.get_ticks_usec()-started}
			check(bool(stop_observation.panel_visible) and bool(stop_observation.button_visible) and bool(stop_observation.button_enabled) \
				and bool(stop_observation.unfinished_task) and bool(stop_observation.request_absent) and bool(stop_observation.provider_active) \
				and int(stop_observation.serial)==serial+1 and int(stop_observation.request_admissions)==0,
				label+" ordinary enabled Stop observes an unfinished task before HTTP admission")
		stop_was_active = bool(panel.provider.active)
		if stop_was_active:
			click(panel.stop)
			check(not panel.provider.active,label+" explicit Stop button cancels active request")
			if preparation_observed and panel.provider.response_preparation_active():
				# Stop updates model ownership immediately, while ordinary button
				# enabled state refreshes on the next UI frame. A disabled click
				# cannot qualify the provider's bounded retry message.
				await process_frame
				if panel.provider.response_preparation_active() and not panel.draw.disabled:
					var cancelled_serial: int = panel.provider.serial
					var retry_begin := Time.get_ticks_usec()
					click(panel.draw)
					bounded_retry = {"usec":Time.get_ticks_usec()-retry_begin,"serial_before":cancelled_serial,"serial_after":panel.provider.serial,
						"observed":"enabled_send_while_cancelled_task_drains"}
					check(panel.provider.serial==cancelled_serial and not panel.provider.active,label+" quick Send cannot queue another body while cancelled CPU work drains")
					check(str(panel.input_error).contains("preparation"),label+" blocked quick Send gives a truthful short retry status")
				else:
					bounded_retry = {"observed":"cancelled_task_drained_or_send_still_disabled_before_retry"}
	if action in ["hide","stop_hide","reopen"]:
		var active_before_x: bool = panel.provider.active
		ordinary_x()
		check(not panel.visible,label+" ordinary embedded X hit-test hides Art")
		if active_before_x: check(panel.provider.active,label+" X leaves provider ownership active")
	if action=="reopen":
		wb.open_art_batches()
		check(panel.visible and wb.art_batches==panel,label+" ordinary reopen preserves same panel")
	var paint_point := Vector2i(300+cases.size(),30)
	var paint_queued := false
	var manual_during_activity := bool(panel.provider.active)
	var manual_phase := str(panel.provider.last_request_timing.get("status",""))
	var manual_during_transport := manual_during_activity and manual_phase=="in_flight"
	if manual_activity:
		wb.applied.brush = 0
		paint_queued = wb.paint(paint_point,58)
		check(paint_queued,label+" ordinary manual stroke accepted in request lifecycle")
	check(await until(settled,int(configured_budgets.settlement_ms)),label+" request/native operations reach bounded terminal state")
	for _index in range(12): await process_frame
	var frames := end_measurement()
	var post_arrivals_after := fixture_post_arrivals() if outgoing and expectation=="cancel" else -1
	if outgoing: panel.provider.request_started.disconnect(observe_request_start)
	var elapsed_usec := Time.get_ticks_usec()-started
	var timing: Dictionary = panel.provider.last_request_timing.duplicate(true)
	var kinds := event_counts(offset)
	var tick_after := native_tick()
	check(int(frames.max_usec)<int(spec.stall_limit_usec),label+" no multi-second frame gap in this environment")
	check(not panel.provider.log_path.is_empty() and (initial_log.is_empty() or initial_log==panel.provider.log_path),label+" same-session audit identity retained")
	check(not panel.provider.active and panel.remaining_turns==0,label+" no abandoned or retried request")
	if action in ["hide","stop_hide"]: check(not panel.visible,label+" completion never reopens hidden Art")
	if expectation=="failure" and not stop_was_active:
		check(not panel.input_error.is_empty(),label+" explicit failure reaches Art status")
		check(int(kinds.get("assistant",0))==0 and int(kinds.get("usage",0))==0,label+" failed transport/envelope is not an assistant turn")
	if expectation=="success":
		check((panel.input_error.is_empty() or panel.input_error=="Model finished.") \
			and int(timing.get("transport_result",-1))==0 and int(timing.get("http_code",0))==200 \
			and int(timing.get("response_bytes",0))>=fixture_response_minimum(model_name),
			label+" successful packet has actual complete HTTP 200 content and remains usable")
	if endpoint_name in ["absent_endpoint","localhost_absent_endpoint","ipv6_absent_endpoint","ipv6_short_absent_endpoint"] and not stop_was_active:
		check(int(timing.get("transport_result",0))!=0 and int(timing.get("http_code",-1))==0,label+" absent listener is transport failure without HTTP response")
	if endpoint_name=="slow_connect_endpoint":
		check(int(timing.get("transport_result",0))!=0 and int(timing.get("http_code",-1))==0,label+" saturated connect attempt has no HTTP response")
	if model_name=="fixture-invalid" and endpoint_name=="endpoint":
		check(int(timing.get("http_code",0))==404,label+" genuine HTTP model error remains separate")
	if model_name in ["fixture-large-error","fixture-large-envelope-error"]:
		var expected_http_code := 404 if model_name=="fixture-large-error" else 200
		check(str(panel.input_error).length()<800 and int(timing.get("transport_result",-1))==0 \
			and int(timing.get("http_code",0))==expected_http_code \
			and int(timing.get("response_bytes",0))>=fixture_response_minimum(model_name),
			label+" complete large HTTP failure has bounded UI/conversation projection")
	if model_name=="fixture-malicious-usage":
		check(not str(panel.state.text).contains(CANARY),label+" malformed usage cannot expose a credential in visible status")
		check(str(panel.state.text).length()<2000,label+" malformed usage cannot expand visible status without bound")
		check(str(panel.state.text).contains("In ? Out ?"),label+" malformed usage remains truthfully unknown")
	if preparation_observed:
		check(panel.provider.response_preparation_jobs==0 and preparation_pending_count()==0,label+" completed or cancelled task handles are reaped")
		check(panel.provider.peak_response_preparation_jobs==1,label+" peak retained CPU jobs stays bounded to one")
		if expectation=="cancel":
			check(int(kinds.get("response",0))==0 and int(kinds.get("assistant",0))==0 and int(kinds.get("usage",0))==0,
				label+" cancellation before audit commits no partial response or assistant")
	if outgoing_preparation_observed:
		check(panel.provider.request_preparation_jobs==0 and preparation_pending_count()==0,label+" outgoing task handles are reaped")
		check(panel.provider.peak_request_preparation_jobs==1,label+" retained outgoing CPU jobs stay bounded to one")
		if expectation=="cancel":
			check(int(kinds.get("request",0))==0 and int(kinds.get("assistant",0))==0 and int(kinds.get("usage",0))==0,
				label+" cancellation before dispatch commits no request or assistant")
			# The fixture server rejects bodies above 4 MiB before writing its
			# model receipt. Near-cap cancellation therefore also requires zero
			# actual successful HTTP admissions, independently of that receipt.
			check(request_admissions.is_empty(),label+" cancelled outgoing preparation has no successful HTTP admission")
			check(not fixture_received(model_name),label+" cancelled outgoing preparation sends no HTTP POST")
	if outgoing and expectation=="cancel":
		check(post_arrivals_before>=0 and post_arrivals_after==post_arrivals_before,
			label+" external loopback observes no POST arrival even before body validation")
	if model_name=="fixture-secret-boundary":
		check(not str(panel.input_error).contains("art-fixture"),label+" credential redaction precedes 512-character error excerpt")
		var traffic := FileAccess.get_file_as_string(panel.provider.log_path)
		check(not traffic.contains(CANARY) and traffic.contains("END-OF-COMPLETE-REDACTED-ERROR"),label+" full redacted error survives in audit")
	var snapshot := {"case":label,"fixture":model_name,"action":action,"expected":expectation,
		"send_usec":send_usec,"elapsed_usec":elapsed_usec,"frames":frames,"provider":timing,"fixture_budgets":configured_budgets,
		"send_stages":send_stages,"finished_stages":optional_metrics(panel,"last_finished_timing"),
		"last_audit":optional_metrics(panel.provider,"last_audit_timing"),
		"native_poll_usec":optional_metrics(panel,"last_native_poll_usec"),"close":panel.last_close_timing.duplicate(true) if action!="visible" else {},
		"stop":panel.last_stop_timing.duplicate(true) if action=="stop_hide" else {},
		"stop_was_active":stop_was_active,"stop_observation":stop_observation,"request_admissions":request_admissions,
		"post_arrivals":{"before":post_arrivals_before,"after":post_arrivals_after} if outgoing and expectation=="cancel" else {},
		"event_counts":kinds,"error_characters":str(panel.input_error).length(),
		"preparation_observed_running":preparation_observed,"bounded_retry":bounded_retry,
		"request_preparation_observed_running":outgoing_preparation_observed,
		"native_tick_before":tick_before,"native_tick_after":tick_after,"manual_queued":paint_queued,
		"manual_during_transport":manual_activity and manual_during_transport,
		"manual_during_provider_activity":manual_activity and manual_during_activity,"manual_activity_phase":manual_phase}
	cases.append(snapshot)
	if manual_activity:
		if not host.paused: wb.toggle_pause()
		var material: int = await captured_cell(paint_point)
		check(material==58,label+" concurrently queued human stroke has authoritative native readback")
		if material==58:
			native_activity_count += 1
			if manual_during_activity: active_manual_activity_count += 1
			if manual_during_transport: transport_manual_activity_count += 1
		check(wb.toggle_pause(),label+" native simulation resumes after independent readback")
	panel.hide()
	await process_frame
	checkpoint(label+" completed")


func clear_fixture_conversation() -> void:
	panel._open_conversation()
	panel.conversation_editor.draft.clear()
	panel._apply_conversation_edits()
	check(panel.conversation.is_empty(),"fixture conversation Apply clears future context without deleting prior audit")
	for _index in range(3): await process_frame


func seed_outgoing_context(size_bytes: int) -> Dictionary:
	checkpoint("constructing outgoing fixture context %d bytes"%size_bytes)
	await clear_fixture_conversation()
	var began := Time.get_ticks_usec()
	check(panel.remember_turn("user","x".repeat(size_bytes)),"synthetic Full context is admitted for outgoing preparation qualification")
	# This is fixture construction, not an assertion about a user typing or
	# applying a giant note. Its cost is retained separately from actual Send.
	return {"context_bytes":size_bytes,"fixture_admission_usec":Time.get_ticks_usec()-began,
		"admission_path":"synthetic remember_turn before measured ordinary Send"}


func outgoing_preparation_checks() -> void:
	if not check(panel.provider.has_method("request_preparation_active"),"provider exposes outgoing value-worker lifecycle for qualification"): return
	var seed: Dictionary = await seed_outgoing_context(1024*1024)
	await execute_case("outgoing-cpu-visible","fixture-outgoing-visible","endpoint","visible","success")
	cases[-1].context_fixture = seed
	await execute_case("outgoing-cpu-hide-reopen","fixture-outgoing-hide","endpoint","reopen","success")
	cases[-1].context_fixture = seed
	# A displayed UI frame can outlast the 1 MiB worker. Reuse this existing
	# near-cap context for genuine CPU work through the ordinary Stop refresh,
	# then for the following absent-listener Send; no worker delay is injected.
	seed = await seed_outgoing_context(16*1024*1024-8192)
	await execute_case("outgoing-cpu-stop-close","fixture-outgoing-stop","endpoint","stop_hide","cancel")
	cases[-1].context_fixture = seed
	await execute_case("near-limit-full-context-no-listener","fixture-outgoing-near-limit","absent_endpoint","hide")
	cases[-1].context_fixture = seed
	check(bool(cases[-1].provider.get("request_preparation_async",false)),"near-limit actual Send uses value-only outgoing preparation")
	await seed_outgoing_context(1024*1024)
	await prepare_panel("fixture-outgoing-world","endpoint",20.0)
	panel.context_mode.select(0)
	var offset := log_length()
	click(panel.draw)
	check(await until(func() -> bool: return preparation_running("request"),25000),"World replacement begins during genuine outgoing CPU work")
	ordinary_x()
	checkpoint("outgoing CPU work before World replacement")
	var old_epoch: int = host.simulation_worker.art_state().epoch
	check(wb.new_canvas(),"World replacement is admitted during outgoing preparation")
	checkpoint("outgoing World replacement queued")
	check(await until(func() -> bool: return ready() and host.simulation_worker.art_state().epoch!=old_epoch),"outgoing replacement changes native epoch")
	check(await until(settled,15000),"outgoing old-World job is cancelled and reaped")
	var kinds := event_counts(offset)
	check(int(kinds.get("request",0))==0 and int(kinds.get("assistant",0))==0,"old-World outgoing values are never admitted as a request or assistant")
	check(not fixture_received("fixture-outgoing-world"),"old-World outgoing values never reach loopback HTTP")
	check(preparation_pending_count()==0,"outgoing World replacement leaves no task handle")
	await cpu_preparation_shutdown(false,"request")


func preparation_checks() -> void:
	if not check(panel.provider.has_method("response_preparation_active"),"provider exposes value-worker lifecycle for qualification"): return
	await execute_case("cpu-preparation-hide-reopen","fixture-preparation-hide","endpoint","reopen","success")
	await execute_case("cpu-preparation-stop-close","fixture-preparation-stop","endpoint","stop_hide","cancel")
	# A large successful assistant must traverse decoded text, assistant/message
	# audit and conversation admission too; padding outside choices is insufficient.
	await clear_fixture_conversation()
	await execute_case("near-limit-successful-assistant","fixture-large-assistant","endpoint","hide","success")
	check(panel.conversation.any(func(turn: Dictionary) -> bool: return turn.role=="assistant" and str(turn.content).length()>16000000),
		"complete large assistant is retained in the live conversation")
	await clear_fixture_conversation()
	var world_timeout := fixture_transport_seconds("fixture-preparation-world")
	var world_observation_ms := int((world_timeout+15.0)*1000.0)
	var world_budgets := fixture_budget_record("fixture-preparation-world",world_timeout,world_observation_ms)
	world_budgets.erase("settlement_ms")
	world_budgets.merge({"phase":"response_world_replacement","world_replacement_ready_ms":15000,"post_cancel_settlement_ms":15000})
	preparation_budgets.append(world_budgets)
	await prepare_panel("fixture-preparation-world","endpoint",world_timeout)
	var offset := log_length()
	click(panel.draw)
	check(await observe_incoming_preparation(world_observation_ms),"World replacement begins while actual CPU preparation runs")
	ordinary_x()
	checkpoint("response CPU work before World replacement")
	var old_epoch: int = host.simulation_worker.art_state().epoch
	check(wb.new_canvas(),"World replacement is admitted during CPU preparation")
	check(await until(func() -> bool: return ready() and host.simulation_worker.art_state().epoch!=old_epoch),"CPU preparation replacement changes native epoch")
	check(await until(settled,15000),"replaced-World CPU task is cancelled and reaped")
	var kinds := event_counts(offset)
	check(int(kinds.get("assistant",0))==0 and int(kinds.get("drawing_admission",0))==0,"cancelled old-World CPU preparation admits no assistant drawing")
	check(preparation_pending_count()==0,"World replacement leaves no uncollected CPU task")
	if not host.paused: wb.toggle_pause()
	check(await captured_cell(Vector2i(20,20))==0,"old CPU-prepared rectangle cannot paint the replacement World")
	await cpu_preparation_shutdown(false)


func cpu_preparation_shutdown(exit_process: bool, direction: String = "response") -> void:
	if not host.paused: wb.toggle_pause()
	if not await fresh_world(): return
	check(wb.toggle_pause(),"native simulation runs before CPU-active shutdown")
	var model_name := "fixture-preparation-exit" if exit_process else "fixture-preparation-shutdown"
	if direction=="request":
		await seed_outgoing_context(1024*1024)
		model_name = "fixture-outgoing-exit" if exit_process else "fixture-outgoing-shutdown"
	var request_timeout := fixture_transport_seconds(model_name)
	var observation_ms := 25000 if direction=="request" else int((request_timeout+15.0)*1000.0)
	var configured_budgets := fixture_budget_record(model_name,request_timeout,observation_ms)
	configured_budgets.erase("settlement_ms")
	configured_budgets.phase = direction+("_process_exit" if exit_process else "_owner_destruction")
	if exit_process:
		configured_budgets.process_exit_limit_usec = int(spec.stall_limit_usec)
	else:
		configured_budgets.merge({"owner_teardown_limit_usec":int(spec.stall_limit_usec),
			"post_cancel_reap_ms":15000,"new_session_ready_ms":90000})
	preparation_budgets.append(configured_budgets)
	await prepare_panel(model_name,"endpoint",request_timeout)
	if direction=="request": panel.context_mode.select(0)
	if exit_process: await capture_graphical()
	click(panel.draw)
	var observed: bool
	if direction=="request": observed = await until(func() -> bool: return preparation_running(direction),observation_ms)
	else: observed = await observe_incoming_preparation(observation_ms)
	check(observed,"shutdown begins while actual "+direction+" CPU preparation runs")
	check(preparation_pending_count()==1,"shutdown owns exactly one unreaped preparation task")
	if exit_process:
		var receipt := {"requested_unix_seconds":Time.get_unix_time_from_system(),
			"preparation_active":preparation_running(direction),"direction":direction,"pending_jobs":preparation_pending_count(),
			"request_timing":panel.provider.last_request_timing.duplicate(true),"fixture_budgets":configured_budgets}
		var file := FileAccess.open(str(spec.output)+"/exit-request.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(receipt,"\t")+"\n")
		file.close()
		print_result("process_exit_requested_before_tree_teardown")
		# This is an actual SceneTree/process quit with unfinished value work.
		# The Python parent records the exit code and post-request wall time.
		quit(0 if failures.is_empty() else 1)
		return
	ordinary_x()
	var archive := str(panel.provider.log_path)
	checkpoint(direction+" CPU work before owner destruction")
	var began := Time.get_ticks_usec()
	host.queue_free()
	await process_frame
	await process_frame
	var elapsed_usec := Time.get_ticks_usec()-began
	shutdown_metrics[direction+"_preparation_owner_free_usec"] = elapsed_usec
	check(not is_instance_valid(host),"freeing the Workbench owner never waits for CPU preparation")
	check(elapsed_usec<int(spec.stall_limit_usec),"CPU-active owner teardown stays within the main-thread bound")
	var archive_hash := FileAccess.get_sha256(archive)
	check(await until(func() -> bool: return preparation_pending_count()==0,15000),"orphan value job is reaped after provider destruction")
	check(FileAccess.get_sha256(archive)==archive_hash,"orphan preparation never appends after owner destruction")
	if direction=="request": check(not fixture_received(model_name),"orphan outgoing job never dispatches HTTP after owner destruction")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	wb = host.shared_workbench
	check(await until(ready,90000),"new session starts after CPU-active owner teardown")
	panel = wb._ensure_art_batches()
	check(panel.conversation.is_empty() and panel.provider.log_path.is_empty(),"new session adopts no cancelled CPU transcript or archive")


func loaded_conversation_apply_checks() -> void:
	# This group runs alone in a fresh native process. Constructing an existing
	# synthetic conversation is outside the measured selection/Apply intervals;
	# no giant TextEdit assignment or clipboard allocation is involved.
	var content_bytes := 16*1024*1024-8192
	var expected_sha256 := "ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a"
	var serial_before: int = panel.provider.serial
	var authored_before: Array = wb.applied.edits.duplicate(true)
	panel.show()
	for _index in range(3): await process_frame
	checkpoint("before synthetic near-cap live-conversation admission")
	var began := Time.get_ticks_usec()
	check(panel.remember_turn("user","x".repeat(content_bytes)),"complete synthetic near-cap conversation is retained")
	var seed_usec := Time.get_ticks_usec()-began
	checkpoint("before ordinary bounded selection")
	var tick_before := native_tick()
	begin_measurement()
	began = Time.get_ticks_usec()
	click(panel.conversation_button)
	var open_usec := Time.get_ticks_usec()-began
	for _index in range(12): await process_frame
	var open_frames := end_measurement()
	var editor: Window = panel.conversation_editor
	check(editor.visible and editor.selected==0,"ordinary Conversation opens selected complete message")
	check(editor.content.text.length()<=4096,"loaded message assigns at most 4096 characters to TextEdit")
	check(editor.draft.size()==1 and str(editor.draft[0].content).length()==content_bytes,"complete draft survives bounded presentation")
	editor.content.grab_focus()
	editor.content.select(0,0,0,1)
	await process_frame
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_Z
		event.unicode = 90
		event.shift_pressed = true
		event.pressed = pressed
		editor.push_input(event,true)
	for _index in range(3): await process_frame
	check(editor.content.text.begins_with("Zx"),"ordinary TextEdit key event replaces the selected first character")
	if DisplayServer.get_name()!="headless":
		# Retain the actual edited Conversation and its Apply/Cancel controls.
		# Rendering/readback belongs outside both measured UI intervals.
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		check(screenshot != null and not screenshot.is_empty()
			and screenshot.save_png(str(spec.output)+"/conversation-before-apply.png")==OK,
			"displayed changed conversation framebuffer is retained before Apply")
	checkpoint("before actual edited near-cap Apply")
	begin_measurement()
	began = Time.get_ticks_usec()
	click(editor.get_ok_button())
	var apply_usec := Time.get_ticks_usec()-began
	var async_apply: bool = panel.conversation_apply_pending()
	if async_apply:
		check(await until(func() -> bool: return not panel.conversation_apply_pending(),90000),
			"large Apply finishes its bounded background preparation and owner commit")
	var apply_completion_usec := Time.get_ticks_usec()-began
	for _index in range(12): await process_frame
	var apply_frames := end_measurement()
	check(not editor.visible,"ordinary Apply closes changed large-message draft")
	check(panel.conversation.size()==1 and str(panel.conversation[0].content).length()==content_bytes,"Apply keeps complete message length")
	var actual_sha256 := str(panel.conversation[0].content).sha256_text()
	check(actual_sha256==expected_sha256,"Apply retains changed first character and every unshown byte")
	check(int(open_frames.max_usec)<int(spec.stall_limit_usec),"loaded-message selection stays within main-thread bound")
	check(int(apply_frames.max_usec)<int(spec.stall_limit_usec),"edited near-cap Apply stays within main-thread bound")
	check(panel.provider.serial==serial_before and not panel.provider.active,"conversation editing sends no model request")
	check(wb.applied.edits==authored_before,"conversation editing changes no authored native cells")
	check(native_tick()>tick_before,"native simulation progresses while loaded conversation is edited")
	cases.append({"case":"loaded-near-cap-edited-apply","context_bytes":content_bytes,
		"fixture_admission_usec":seed_usec,"open_usec":open_usec,"open_frames":open_frames,
		"apply_usec":apply_usec,"apply_completion_usec":apply_completion_usec,"asynchronous_apply":async_apply,
		"apply_preparation":panel.last_conversation_apply_timing.duplicate(true),
		"timing_scope":"apply_usec is click-return; completion includes preparation and durable owner commit; frames cover both",
		"frames":apply_frames,"expected_sha256":expected_sha256,"actual_sha256":actual_sha256,
		"last_audit":panel.provider.last_audit_timing.duplicate(true),"visible_characters":editor.content.text.length()})
	checkpoint("edited near-cap Apply completed")


func lifecycle_checks() -> void:
	if not host.paused: wb.toggle_pause()
	if not await fresh_world(): return
	await execute_case("model-native-drawing-hidden","fixture-draw","endpoint","hide","success",false)
	check(int(panel.executor.result.get("changed",0))==144,"model drawing applies exact native rectangle")
	check(await captured_cell(Vector2i(20,20))==58,"model rectangle is present in native stored cells")
	panel.show()
	for _index in range(3): await process_frame
	check(not panel.undo_button.disabled,"model edit exposes ordinary Undo")
	click(panel.undo_button)
	check(await until(settled),"Undo finishes through shared native history")
	check(await captured_cell(Vector2i(20,20))==0,"Undo restores original native material")
	for _index in range(3): await process_frame
	click(panel.redo_button)
	check(await until(settled),"Redo finishes through shared native history")
	check(await captured_cell(Vector2i(20,20))==58,"Redo restores confirmed model drawing")
	var conversation_before: int = panel.conversation.size()
	var audit_before := str(panel.provider.log_path)
	wb._name.text = "art-finisher-fixture"
	check(wb.save_setup(),"authored start saves after native completion")
	check(wb.new_canvas(),"new canvas replaces authored World")
	check(await until(ready),"new canvas installed")
	check(wb.load_setup(),"saved authored start reopens")
	check(await until(ready),"saved authored start acknowledged")
	check(await captured_cell(Vector2i(20,20))==58,"save/reopen preserves actual model edit")
	check(panel.conversation.size()==conversation_before and panel.provider.log_path==audit_before,
		"World save/reopen retains live-session conversation and audit")
	check(panel.remember_turn("user","SESSION-FINAL-COLLAB-MARKER"),"follow-up collaboration note is retained")
	await execute_case("same-session-follow-up","fixture-context","endpoint","reopen","success",false)
	check(panel.model_context().any(func(turn: Dictionary) -> bool: return str(turn.content).contains("SESSION-FINAL-COLLAB-MARKER")),
		"future context retains live-session follow-up")
	# A delayed native drawing response must be fenced when the World changes,
	# including while the Art window is hidden.
	await prepare_panel("fixture-delayed-draw")
	click(panel.draw)
	ordinary_x()
	check(not panel.visible and panel.provider.active,"replacement fixture has genuinely outstanding hidden request")
	check(await until(func() -> bool: return fixture_received("fixture-delayed-draw")),"old-World request reached loopback server before replacement")
	var old_epoch: int = host.simulation_worker.art_state().epoch
	check(wb.new_canvas(),"World replacement admitted during outstanding request")
	check(await until(func() -> bool: return ready() and host.simulation_worker.art_state().epoch!=old_epoch),"replacement changes native epoch")
	check(await until(settled),"hidden old-World request retires")
	await create_timer(0.6).timeout
	check(await captured_cell(Vector2i(20,20))==0,"late old-World response never paints replacement")
	check(panel.provider.log_path==audit_before and panel.conversation.size()>=conversation_before,
		"replacement fences editing authority without erasing collaboration")
	# Direct JSON uses the same worker and Stop. Wait for a confirmed prefix
	# before pressing Stop to exercise partial completion, not queue admission.
	panel.show()
	panel.input_mode.select(0)
	panel.input.text = '[{"shape":"rectangle","x0":0,"y0":0,"x1":511,"y1":499,"material":58}]'
	for _index in range(3): await process_frame
	click(panel.draw)
	check(await until(func() -> bool: return int(panel.executor.result.get("changed",0))>0),"large native drawing produces confirmed prefix")
	check(panel.executor.active,"large drawing remains active after first native prefix")
	click(panel.stop)
	check(await until(settled),"Stop drains current native boundary")
	check(panel.executor.result.status=="partial" and int(panel.executor.result.changed)>0 and int(panel.executor.result.changed)<256000,
		"Stop reports actual partial native application")
	for _index in range(3): await process_frame
	click(panel.undo_button)
	check(await until(settled),"partial native group can be undone")
	check(await captured_cell(Vector2i(0,0))==0,"Undo removes the applied prefix")


func shutdown_checks() -> void:
	await prepare_panel("fixture-blackhole-shutdown")
	click(panel.draw)
	ordinary_x()
	check(panel.provider.active and not panel.visible,"shutdown starts with an outstanding hidden request")
	check(await until(func() -> bool: return fixture_received("fixture-blackhole-shutdown")),"actual POST received before no-header shutdown")
	for _index in range(3): await process_frame
	var archive := str(panel.provider.log_path)
	var started := Time.get_ticks_usec()
	host.queue_free()
	await process_frame
	await process_frame
	var shutdown_usec := Time.get_ticks_usec()-started
	check(not is_instance_valid(host),"Workbench shutdown releases provider owner")
	var archive_hash := FileAccess.get_sha256(archive)
	await create_timer(0.6).timeout
	check(FileAccess.get_sha256(archive)==archive_hash,"late transport does not append after session shutdown")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	wb = host.shared_workbench
	check(await until(ready,90000),"new game session starts after outstanding transport shutdown")
	panel = wb._ensure_art_batches()
	check(panel.conversation.is_empty() and panel.provider.log_path.is_empty(),"new game session has no automatic transcript restore or audit adoption")
	check(panel.remember_turn("user","new-session-fixture"),"new session can create its own independent log")
	check(panel.provider.log_path!=archive and FileAccess.get_sha256(archive)==archive_hash,"old audit stays byte-identical after new session starts")
	shutdown_metrics.merge({"shutdown_usec":shutdown_usec,"old_audit_sha256":archive_hash},true)
	print("ART_FINAL_SHUTDOWN ",JSON.stringify(shutdown_metrics))


func run() -> void:
	var spec_path := OS.get_environment("WB_ART_FINAL_SPEC")
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	if not check(decoded is Dictionary,"runner supplies an isolated loopback specification"):
		await finish()
		return
	spec = decoded
	if not check(str(spec.get("endpoint","")).begins_with("http://127.0.0.1:"),"only runner-owned loopback transport is used"):
		await finish()
		return
	root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	wb = host.shared_workbench
	if not check(await until(ready,90000),"real native Workbench starts"):
		await finish()
		return
	panel = wb._ensure_art_batches()
	check(panel.conversation.is_empty() and panel.provider.log_path.is_empty(),"fresh isolated session starts empty and creates no audit while idle")
	if not await fresh_world():
		await finish()
		return
	await prepare_panel("fixture-valid")
	if str(spec.get("group","all"))=="preparation-exit":
		await cpu_preparation_shutdown(true)
		return
	if str(spec.get("group","all"))=="request-preparation-exit":
		await cpu_preparation_shutdown(true,"request")
		return
	if str(spec.get("group","all"))=="shutdown":
		await shutdown_checks()
		await finish()
		return
	ordinary_x()
	check(not panel.visible and not panel.provider.active,"idle ordinary X hides without provider work")
	check(wb.toggle_pause(),"ordinary native Workbench simulation is playing during failure matrix")
	var baseline_tick := native_tick()
	begin_measurement()
	await create_timer(0.35).timeout
	baseline_frames = end_measurement()
	check(native_tick()>baseline_tick,"native simulation progresses during baseline")
	print("ART_FINAL_BASELINE ",JSON.stringify(baseline_frames))
	if str(spec.get("group","all"))=="preparation":
		await preparation_checks()
		await finish()
		return
	if str(spec.get("group","all"))=="request-preparation":
		await outgoing_preparation_checks()
		await finish()
		return
	if str(spec.get("group","all"))=="lifecycle":
		# Replay native authoring/session boundaries in a fresh process without
		# requiring every large transport fixture to share its retained memory.
		await lifecycle_checks()
		await shutdown_checks()
		await finish()
		return
	if str(spec.get("group","all"))=="conversation-apply":
		await loaded_conversation_apply_checks()
		await finish()
		return
	for index: int in range(3):
		await execute_case("absent-numeric-hidden-%d"%index,"fixture-valid","absent_endpoint")
	for index: int in range(3):
		await execute_case("absent-localhost-hidden-%d"%index,"fixture-valid","localhost_absent_endpoint")
	if not str(spec.ipv6_absent_endpoint).is_empty():
		await execute_case("absent-ipv6-hidden","fixture-valid","ipv6_absent_endpoint")
		await execute_case("absent-ipv6-shorthand-hidden","fixture-valid","ipv6_short_absent_endpoint")
	else: unavailable.append("IPv6 loopback absent-listener bind unavailable")
	await execute_case("absent-visible","fixture-valid","absent_endpoint","visible")
	await execute_case("absent-stop-close","fixture-valid","absent_endpoint","stop_hide")
	await execute_case("absent-close-reopen","fixture-valid","absent_endpoint","reopen")
	if str(spec.get("group","all"))=="no-server":
		await finish()
		return
	if not str(spec.slow_connect_endpoint).is_empty():
		await execute_case("slow-tcp-connect-timeout","fixture-valid","slow_connect_endpoint")
	else: unavailable.append("Slow TCP connect: loopback backlog saturation unavailable on this kernel")
	await execute_case("invalid-model-http-404","fixture-invalid")
	await execute_case("delayed-http-hidden","fixture-delayed","endpoint","hide","success")
	await execute_case("delayed-http-visible","fixture-delayed","endpoint","visible","success")
	await execute_case("delayed-http-reopen","fixture-delayed","endpoint","reopen","success")
	await execute_case("explicit-stop-close","fixture-delayed","endpoint","stop_hide","cancel")
	await execute_case("header-blackhole-stop-close","fixture-blackhole-stop","endpoint","stop_hide","cancel")
	await execute_case("header-blackhole-timeout","fixture-blackhole-timeout")
	await execute_case("connected-then-dropped","fixture-drop")
	await execute_case("http-response-timeout","fixture-timeout")
	await execute_case("malformed-http-200-json","fixture-malformed")
	await execute_case("oversized-http-response","fixture-oversized")
	await execute_case("error-secret-at-excerpt-boundary","fixture-secret-boundary")
	await execute_case("large-complete-valid-response","fixture-large","endpoint","hide","success")
	await execute_case("large-complete-http-404","fixture-large-error")
	await execute_case("large-http-200-error-envelope","fixture-large-envelope-error")
	await execute_case("malformed-usage-visible","fixture-malicious-usage","endpoint","visible","success")
	await execute_case("near-limit-complete-valid-response","fixture-near-limit","endpoint","hide","success")
	await execute_case("malformed-drawing-packet","fixture-bad-drawing","endpoint","hide","drawing_refusal")
	await execute_case("valid-after-all-failures","fixture-valid","endpoint","reopen","success")
	check(native_activity_count>=20,"failure matrix confirms ordinary native manual editing in at least twenty arms")
	check(active_manual_activity_count>=20,"at least twenty confirmed manual edits were queued while transport remained active")
	check(DirAccess.get_files_at("user://art-traffic").size()==1,"all matrix arms use exactly one lazy root session audit")
	check(not FileAccess.get_file_as_string(panel.provider.log_path).contains(CANARY),"all session traffic is redacted")
	check(not FileAccess.get_file_as_string("user://art-provider.cfg").contains(CANARY),"saved provider preferences contain no credential")
	if str(spec.get("group","all"))=="network":
		await finish()
		return
	await preparation_checks()
	await outgoing_preparation_checks()
	await lifecycle_checks()
	if DisplayServer.get_name()!="headless":
		panel.show()
		for _index in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(str(spec.output)+"/art-window.png")
	await shutdown_checks()
	await finish()


func finish() -> void:
	# Every selected graphical group needs rendered evidence, including the
	# short no-server diagnostic and the replacement session after shutdown.
	await capture_graphical()
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await process_frame
	print_result("completed")
	quit(0 if failures.is_empty() else 1)


func capture_graphical() -> void:
	if DisplayServer.get_name()!="headless" and is_instance_valid(panel) and not spec.is_empty() \
			and not FileAccess.file_exists(str(spec.output)+"/art-window.png"):
		panel.show()
		for _index in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(str(spec.output)+"/art-window.png")


func print_result(phase: String) -> void:
	print("ART_WORKBENCH_FINAL_RESULT ",JSON.stringify(result_data(phase)))


func checkpoint(progress: String) -> void:
	# All calls are outside measured Send/close/frame intervals. A subsequent
	# external process kill must not erase earlier numeric case receipts.
	if spec.is_empty(): return
	var receipt := result_data("in_progress")
	receipt.progress = progress
	var file := FileAccess.open(str(spec.output)+"/report-checkpoint.json",FileAccess.WRITE)
	if file == null:
		check(false,"fixture progress receipt is writable")
		return
	file.store_string(JSON.stringify(receipt,"\t")+"\n")
	file.close()


func result_data(phase: String) -> Dictionary:
	return {"checks":checks,"failures":failures,"cases":cases,
		"completion_phase":phase,
		"native_activity_cases":native_activity_count,"manual_during_transport_cases":transport_manual_activity_count,
		"manual_during_provider_activity_cases":active_manual_activity_count,
		"baseline_frames":baseline_frames,"shutdown":shutdown_metrics,"unavailable":unavailable,
		"preparation_budgets":preparation_budgets,"process_watchdog":spec.get("process_watchdog",{}),
		"godot":Engine.get_version_info().string,"os":OS.get_name(),"display":DisplayServer.get_name(),
		"input_path":"InputEventMouseButton through embedded Window/Button hit testing; no physical mouse acceptance",
		"scope":"synthetic loopback only, isolated profile, ordinary native Workbench"}
