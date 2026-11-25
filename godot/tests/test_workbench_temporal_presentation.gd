extends SceneTree

# CAMERA-STACK-COHERENCE-001: a real mounted Workbench, native World receipts,
# real Rapier bodies and Main's production presentation callback. Controlled
# RID placement is a causal presentation stimulus, not a claim about natural
# flight. Completed Rapier steps provide real monotonic simulation indices.
# The independent 2048² Test It fixture owns live cross-cadence performance.
const Setup = preload("res://scripts/workbench_setup.gd")
const Trace = preload("res://scripts/workbench_pose_trace.gd")
const Clearance = preload("res://scripts/workbench_presentation_coherence.gd")
const History = preload("res://scripts/workbench_presentation_history.gd")
const WAIT_MS: int = 90000
const SPAWN := Vector2(240,300)
const VIEW := Vector2i(240,135)
var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var receipts: Array[Dictionary] = []
var expect_legacy: bool = false
var output: String = ""
var saved_environment: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg=="--temporal-expect-legacy": expect_legacy=true
		if arg.begins_with("--temporal-evidence="):
			output=arg.trim_prefix("--temporal-evidence=")
	for key: String in ["CYBERSAND_DIAG_PRESENTATION","CYBERSAND_DIAG_FLYER_POSE","CYBERSAND_DIAG_RENDER_CADENCE",
			"CYBERSAND_DIAG_MATERIAL_TIMING"]:
		saved_environment[key]=OS.get_environment(key)
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","legacy" if expect_legacy else "coherent")
	OS.set_environment("CYBERSAND_DIAG_FLYER_POSE","")
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE","")
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","")
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks+=1
	if not ok:
		failures.append(label)
		push_error("TEMPORAL_PRESENTATION: "+label)
	return ok

func until(predicate: Callable) -> bool:
	var deadline: int=Time.get_ticks_msec()+WAIT_MS
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func _install(camera: String="free", spawn: Vector2=SPAWN) -> bool:
	print("TEMPORAL_STAGE install ",camera," ",spawn)
	host.paused=true
	host.update_worker_frame_state()
	host.simulation_worker.set_engine_lab_pixel_pacing(60,true)
	host.engine_lab_set_render_hz(60)
	host.set_process(true)
	host.set_physics_process(true)
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE","")
	var setup: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	setup.actors=[Setup.instance("kestrel",1,spawn)]
	setup.next_id=2
	setup.selected=1
	setup.edits.append([260,285,5,35,58])
	var epoch: int=host._physical_epoch
	if not check(ui.apply(setup),camera+" authored native World requested"): return false
	if not check(await until(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch>epoch \
			and host.physical_actor_session!=null and host._physical_terrain_ready \
			and host._valid_workbench_mask_frame(host.workbench_display_frame()) \
			and host.image.get_pixel(260,300).r8==58),
		camera+" actual native material and actor receipt installed"): return false
	host.set_process(false)
	host.set_physics_process(false)
	host.engine_lab_wait_native_sample=false
	host.simulation_worker.set_engine_lab_pixel_pacing(1,false)
	_expire_blend()
	ui._camera.select(1 if camera=="follow" else 0)
	ui._set_view(SPAWN-Vector2(VIEW)*0.5,VIEW)
	host.paused=false
	host.physical_actor_session.set_suspended(false)
	return true

func _move_actual(position: Vector2, angle: float = 0.0) -> Transform2D:
	var session=host.physical_actor_session
	var bridge=session.bridge
	bridge.reset_body(0,position,angle)
	session.set_suspended(false)
	var before: int=session.tick
	session.advance(bridge.fixed_delta())
	bridge.step()
	session.complete_step()
	host._workbench_completed_step=session.tick
	host._workbench_completed_step_usec=Time.get_ticks_usec()
	check(session.tick==before+1,"controlled real Rapier step completes exactly once")
	var observed: Transform2D=bridge.body_transform(0)
	var physical: Transform2D=PhysicsServer2D.body_get_state(bridge._body_rids[0],PhysicsServer2D.BODY_STATE_TRANSFORM)
	check(observed.is_equal_approx(physical),"real RID and bridge agree after completed step")
	return observed

func _pose() -> Variant:
	var parts: Array=host.physical_actor_overlay._parts
	return parts[0].transform if not parts.is_empty() else null

func _capture(label: String, full_process: bool=true, supplied: Dictionary={}) -> Dictionary:
	# A wall-clock work budget can expire before its first scan if the OS
	# deschedules this process. Preserve that explicit refusal and retry the
	# identical causal stimulus at most four times; never retry material,
	# identity, timeline or previous-texture safety failures.
	var budget_attempts: Array[Dictionary]=[]
	for attempt: int in range(4):
		if full_process:
			host._process(1.0/60.0)
		else:
			host._present_physical_actor_overlay(supplied)
			host.update_shader_parameters()
		if int(host.workbench_presentation_last.get("budget_vetoes",0))==0: break
		budget_attempts.append(host.workbench_presentation_last.duplicate(true))
	var selected: Variant=_pose()
	var bridge=host.physical_actor_session.bridge
	var frame: Dictionary=host.workbench_display_frame()
	var row: Dictionary={"label":label,"live":Trace.pose_json(bridge.body_transform(0)),
		"selected":Trace.pose_json(selected),"rapier_step":host.physical_actor_session.tick,
		"native_tick":host.latest_snapshot.tick_index,"material_revision":host.last_uploaded_revision,
		"upload_serial":host.last_uploaded_render_snapshot_serial,
		"camera_requested":Trace.xy(host.camera_origin),
		"camera_presented":Trace.xy(host.presentation_camera_origin()),
		"guard":host.workbench_presentation_last.duplicate(true),"budget_retries":budget_attempts}
	if selected is Transform2D:
		var projection: Dictionary=Trace.projection(selected,host.presentation_camera_origin(),
			host.view_content_rect(),host.current_view_size,host._world_view_screen_transform(),
			host.presentation_camera_screen_transform())
		row.projection=projection
		check(float(projection.residual_magnitude_px)<0.01,label+" actual shader/overlay projection agrees")
		check(host.physical_actor_overlay._origin.is_equal_approx(host.presentation_camera_origin()),
			label+" overlay receives final terrain camera origin")
	if host.has_method("_resolve_workbench_presentation_frame"):
		var resolved: Dictionary=host.workbench_presentation_frame
		row.source=resolved.get("sources",{}).get(0,"hidden")
		row.reason=resolved.get("reasons",{}).get(0,"")
		row.selected_step=resolved.get("selected_steps",{}).get(0,-1)
		row.desired_step=resolved.get("desired_steps",{}).get(0,-1)
		row.intentional_hold=resolved.get("intentional_holds",{}).get(0,false)
		row.hold_age_usec=resolved.get("hold_age_usec",{}).get(0,0)
		row.explicit_reentry=resolved.get("explicit_reentries",{}).get(0,false)
		row.recovery_attempts=resolved.get("recovery_attempts",{}).get(0,0)
		row.resolve_usec=resolved.get("resolve_usec",-1)
		var target: Vector2=resolved.get("follow_target",Vector2.INF)
		row.follow_target=Trace.xy(target) if target.is_finite() else null
		if not expect_legacy and selected is Transform2D and ui._camera.selected==1:
			check(target.distance_to(selected.origin)<0.01,label+" Follow target is the actually selected actor")
			var wanted: Vector2=(selected.origin-Vector2(host.current_view_size)*0.5).clamp(
				Vector2.ZERO,Vector2(Setup.extent_of(ui.applied)-host.current_view_size))
			check(host.camera_origin.distance_to(wanted)<0.01,label+" continuous Follow camera resolves selected pose first")
		if not expect_legacy:
			check(resolved.get("upload_serial",-1)==host.last_uploaded_render_snapshot_serial,
				label+" resolved frame identifies actual uploaded texture")
			check(resolved.get("camera_mapping",Transform2D.IDENTITY).is_equal_approx(
				host.presentation_camera_screen_transform()),label+" final mapping is stored in resolved frame")
	if frame.get("instances",{}).has(1): row.bound=Trace.pose_json(frame.instances[1].pose)
	observations.append(row)
	return row

func _source_oscillation(camera: String) -> void:
	if not await _install(camera): return
	var material: PackedByteArray=host.image.get_data()
	var bound: Transform2D=host.workbench_display_frame().instances[1].pose
	var clear: Transform2D=_move_actual(bound.origin+Vector2(5,0))
	var first: Dictionary=_capture(camera+"-clear-ahead")
	if not check(_pose() is Transform2D,camera+" first clear pose visible"): return
	check(_pose().origin.distance_to(clear.origin)<0.01,camera+" first safe pose uses real live state")
	_move_actual(Vector2(260,300))
	var veto: Dictionary=_capture(camera+"-genuine-wall-veto")
	check(int(veto.guard.get("blocked_material",0))>0,camera+" real native Wall causes safety veto")
	if not check(_pose() is Transform2D,camera+" known-safe prior footprint stays visible"): return
	var step: Vector2=_pose().origin-clear.origin
	if expect_legacy:
		check(_pose().origin.distance_to(bound.origin)<0.01 and step.x < -4.0,
			camera+" untouched old policy reproduces backward source jump")
	else:
		check(step.length()<0.01,camera+" material veto holds last safe temporal state without rewind")
		check(veto.get("intentional_hold",false),camera+" conservative hold is identified explicitly")
		check(int(veto.get("selected_step",-1))==int(first.get("selected_step",-2)),
			camera+" hold retains selected simulation step")
		ui._pick(Vector2i(clear.origin))
		check(ui.selected_id()==1,camera+" held actor is picked at its displayed position")
		ui._pick(Vector2i(260,300))
		check(ui.selected_id()==0,camera+" hidden live position does not steal actor picking")
		ui.select_instance(1)
	var recovery: Transform2D=_move_actual(bound.origin+Vector2(7,0))
	var resumed: Dictionary=_capture(camera+"-clear-resume")
	check(_pose() is Transform2D and _pose().origin.distance_to(recovery.origin)<0.01,
		camera+" newly safe actual Rapier state resumes without smoothing")
	check(host.image.get_data()==material,camera+" presentation leaves actual material bytes unchanged")
	if not expect_legacy:
		check(int(resumed.get("selected_step",-1))>int(veto.get("selected_step",-1)),
			camera+" selected simulation time advances after hold")
	if _pose() is Transform2D:
		var selected: Transform2D=_pose()
		host.paused=true
		_capture(camera+"-pause")
		if not expect_legacy:
			check(_pose() is Transform2D and _pose().origin.distance_to(selected.origin)<0.01,
				camera+" pause does not restore an older mask pose")
		host.paused=false
		_capture(camera+"-resume")
		if not expect_legacy:
			check(_pose() is Transform2D and _pose().origin.distance_to(selected.origin)<0.01,
				camera+" resume retains timeline continuity")

func _long_clear_path() -> void:
	if not await _install("follow"): return
	var bound: Transform2D=host.workbench_display_frame().instances[1].pose
	var material: PackedByteArray=host.image.get_data()
	var last: Transform2D=bound
	var largest_gap: float=0.0
	for i: int in range(1,11):
		var live: Transform2D=_move_actual(bound.origin+Vector2(0,-float(i)*4.0))
		_capture("clear-flight-step-"+str(i))
		if not check(_pose() is Transform2D,"clear incremental path remains visible"): break
		var shown: Transform2D=_pose()
		largest_gap=maxf(largest_gap,shown.origin.distance_to(live.origin))
		if not expect_legacy:
			check(shown.origin.distance_to(live.origin)<0.01,
				"long flight uses each safe real state beyond original 32-cell mask radius")
			check(shown.origin.y<=last.origin.y+0.01,"clear flight never rewinds to stale native mask")
		last=shown
	if expect_legacy: check(largest_gap>32.0,"old policy reproduces stale-mask jump beyond old bound radius")
	check(host.image.get_data()==material,"long clear presentation does not edit material authority")
	# The actor receipt is intentionally stale here. Invalid identities must
	# hide, then a valid receipt may rejoin without resetting to its old pose.
	if not expect_legacy:
		var valid: Dictionary=host.workbench_display_frame().duplicate(true)
		for key: String in ["epoch","world_generation","revision"]:
			var invalid: Dictionary=valid.duplicate(true)
			invalid[key]=int(invalid.get(key,-1))+1
			_capture("invalid-"+key,false,invalid)
			check(_pose()==null,"stale "+key+" withholds actor rather than unchecked live fallback")
			ui._pick(Vector2i(last.origin))
			check(ui.selected_id()==0,"withheld "+key+" actor has no selectable visual footprint")
			ui.select_instance(1)
			_capture("rejoin-"+key,false,valid)
			check(_pose() is Transform2D and _pose().origin.distance_to(last.origin)<0.01,
				"valid rejoin after "+key+" preserves advanced presentation timeline")
		var invalid_actor: Dictionary=valid.duplicate(true)
		invalid_actor.instances[1].generation+=1
		_capture("invalid-actor-generation",false,invalid_actor)
		check(_pose()==null,"stale actor generation withholds actor")
		_capture("rejoin-actor-generation",false,valid)
		check(_pose() is Transform2D and _pose().origin.distance_to(last.origin)<0.01,
			"actor generation rejection does not rewind valid rejoin")

func _bounded_native_rejoin() -> void:
	if expect_legacy or not await _install("follow"): return
	var clear: Transform2D=_move_actual(SPAWN+Vector2(5,0))
	_capture("rejoin-initial-clear")
	if not check(_pose() is Transform2D,"native-rejoin control has visible actor"): return
	var shown_step: int=host.workbench_presentation_frame.selected_steps[0]
	# A real completed physical step is now on the other side of the native
	# Wall. Obtain its genuine mask receipt without submitting another draw.
	# Endpoint clearance must not authorize the intervening displayed jump.
	var far: Transform2D=_move_actual(SPAWN+Vector2(40,0))
	host._publish_physical_body_state()
	var serial: int=host._workbench_wait_sample
	host.update_worker_frame_state()
	if not check(await until(func() -> bool:
		host.consume_worker_snapshot()
		var frame: Dictionary=host.workbench_display_frame()
		return host._valid_workbench_mask_frame(frame) and frame.instances.has(1) \
			and frame.instances[1].get("sample",-1)==serial),
		"newer native mask receipt arrives without intermediate display selection"): return
	_expire_blend()
	var blocked: Dictionary=_capture("native-endpoint-cannot-teleport",false,host.workbench_display_frame())
	check(_pose() is Transform2D and _pose().origin.distance_to(clear.origin)<0.01,
		"newer clear native endpoint cannot teleport consecutive visible frames across Wall")
	check(int(blocked.selected_step)==shown_step and blocked.intentional_hold,
		"failed continuous native rejoin retains the exact selected physical step")
	var physical_step: int=host.physical_actor_session.tick
	# SceneTree timers use frame delta and can outrun real wall time during a
	# headless campaign. The production cap uses the monotonic wall clock.
	var until_usec: int=Time.get_ticks_usec()+120000
	while Time.get_ticks_usec()<until_usec:
		await process_frame
	var expired: Dictionary=_capture("native-rejoin-hold-expired",false,host.workbench_display_frame())
	check(_pose()==null and str(expired.reason).begins_with("hold_expired:"),
		"100ms retention cap explicitly suppresses an unadvanceable actor")
	check(int(expired.hold_age_usec)>=100000,"actual hold age is recorded rather than nominal frame count")
	var reentry: Dictionary=_capture("native-rejoin-after-suppression",false,host.workbench_display_frame())
	check(_pose() is Transform2D and _pose().origin.distance_to(far.origin)<0.01,
		"safe actual native endpoint may re-enter after explicit suppression")
	check(reentry.explicit_reentry and reentry.reason=="native_receipt_reentry" \
		and int(reentry.selected_step)>shown_step,
		"discontinuous re-entry is identified and never rewinds physical time")
	check(host.physical_actor_session.tick==physical_step \
		and host.physical_actor_session.bridge.body_transform(0).is_equal_approx(far),
		"bounded retention, suppression and re-entry leave physical authority unchanged")
	# Stopped physics and an old/evicted native join must not leave a safe
	# actor permanently invisible after the bounded hold. Keep the actual
	# uploaded receipt, but deliberately exercise serial-journal retirement.
	var newer: Transform2D=_move_actual(SPAWN+Vector2(80,0))
	host._workbench_sample_steps.clear()
	_capture("rejoin-missing-native-history",false,host.workbench_display_frame())
	check(_pose() is Transform2D and _pose().is_equal_approx(far),
		"missing native sample provenance cannot authorize a direct visible jump")
	until_usec=Time.get_ticks_usec()+120000
	while Time.get_ticks_usec()<until_usec:
		await process_frame
	_capture("rejoin-stopped-physics-suppressed",false,host.workbench_display_frame())
	check(_pose()==null,"stopped physics still reaches the finite hold limit")
	var stopped_reentry: Dictionary=_capture("rejoin-stopped-physics-endpoint",false,host.workbench_display_frame())
	check(_pose() is Transform2D and _pose().is_equal_approx(newer) \
		and stopped_reentry.explicit_reentry and stopped_reentry.reason=="explicit_live_reentry",
		"known current physics may explicitly re-enter after complete footprint proof without a new native receipt")

func _wait_for_observation_expiry(observation: Dictionary, label: String) -> bool:
	# Use real completed-step monotonic time, not SceneTree frame delta or
	# fabricated observation clocks. This also covers slow hosted renderers.
	var completed_usec: int = int(observation.get("completed_usec",0))
	if not check(completed_usec > 0,label+" has a real Rapier completion clock"): return false
	var until_usec: int = completed_usec+History.MAX_HOLD_USEC+20000
	while Time.get_ticks_usec() < until_usec:
		await process_frame
	return true


func _expired_history_stays_withheld() -> void:
	if expect_legacy or not await _install("follow"): return
	var clear: Transform2D = _move_actual(SPAWN+Vector2(5,0))
	_capture("history-expiry-first-live")
	if not check(_pose() is Transform2D and _pose().is_equal_approx(clear),
			"history expiry begins at a visible certified current pose"): return
	var historical: Transform2D = _move_actual(SPAWN+Vector2(9,0))
	var observed: Dictionary = host._observe_workbench_presentation(0)
	var historical_step: int = host.physical_actor_session.tick
	var blocked: Transform2D = _move_actual(Vector2(260,300))
	var first: Dictionary = _capture("history-expiry-clear-prefix")
	if not check(first.source == "history" and int(first.selected_step) == historical_step \
			and _pose() is Transform2D and _pose().is_equal_approx(historical),
			"actual Wall refusal selects the recent real historical step"): return
	if not await _wait_for_observation_expiry(observed,"historical recovery"): return
	var genuine_frame: Dictionary = host.workbench_display_frame()
	for index: int in range(4):
		var row: Dictionary = _capture("history-expiry-withheld-"+str(index),false,genuine_frame)
		check(_pose() == null and row.source == "hidden",
			"expired observed pose stays absent across repeated submissions "+str(index))
		check(not bool(row.explicit_reentry) and int(row.selected_step) < 0,
			"expired observed pose cannot re-enter under a renewed hold timer "+str(index))
		check(int(row.guard.get("budget_vetoes",0)) == 0,
			"expiry fixture is an age refusal, not guard budget pressure "+str(index))
	check(host.physical_actor_session.bridge.body_transform(0).is_equal_approx(blocked) \
		and host.physical_actor_session.tick == historical_step+1,
		"expired historical withholding leaves authoritative Rapier untouched")


func _expired_native_receipt_first_refusal() -> void:
	if expect_legacy or not await _install("follow"): return
	var clear: Transform2D = _move_actual(SPAWN+Vector2(5,0))
	var first: Dictionary = _capture("native-expiry-first-live")
	if not check(first.source == "live" and _pose() is Transform2D \
			and _pose().is_equal_approx(clear),"native expiry starts with visible current physical step"): return
	var native_clear: Transform2D = _move_actual(SPAWN+Vector2(8,0))
	var observed: Dictionary = host._observe_workbench_presentation(0)
	var native_step: int = host.physical_actor_session.tick
	host._publish_physical_body_state()
	var serial: int = host._workbench_wait_sample
	host.update_worker_frame_state()
	if not check(await until(func() -> bool:
		host.consume_worker_snapshot()
		var frame: Dictionary = host.workbench_display_frame()
		return host._valid_workbench_mask_frame(frame) and frame.instances.has(1) \
			and int(frame.instances[1].get("sample",-1)) == serial),
		"genuine native sample returns the step-two endpoint without a new overlay submission"): return
	var received: Dictionary = host.workbench_display_frame().duplicate(true)
	check(host._workbench_bound_step(received.instances[1]) == native_step \
		and Transform2D(received.instances[1].pose).is_equal_approx(native_clear),
		"received native mask is bound to the actual observed Rapier step")
	_expire_blend()
	var blocked: Transform2D = _move_actual(Vector2(260,300))
	host._observe_workbench_presentation(0)
	if not await _wait_for_observation_expiry(observed,"delayed native receipt"): return
	var decision: Dictionary = _capture("native-expiry-first-refusal",false,received)
	check(int(decision.guard.get("blocked_material",0)) > 0,
		"newest actual pose is conservatively refused against Wall")
	# The old, actually displayed current pose may be certified as a short
	# hold; this is not permission to substitute the expired native receipt.
	var short_hold: bool = decision.source == "held" and int(decision.selected_step) == int(first.selected_step) \
		and _pose() is Transform2D and _pose().is_equal_approx(clear)
	var suppressed: bool = decision.source == "hidden" and _pose() == null
	check((short_hold or suppressed) and int(decision.selected_step) != native_step,
		"first refusal cannot substitute expired native receipt for the last visible pose")
	check(not decision.explicit_reentry and int(decision.guard.get("budget_vetoes",0)) == 0,
		"first refusal is not an unverified reentry or budget veto")
	if short_hold:
		# Neither a stale native sample nor the old current-origin hold can
		# reappear after the separate 100ms refusal timer expires.
		var hold_until: int = Time.get_ticks_usec()+History.MAX_HOLD_USEC+20000
		while Time.get_ticks_usec() < hold_until:
			await process_frame
		for index: int in range(3):
			var expired: Dictionary = _capture("native-expiry-held-cap-"+str(index),false,received)
			check(_pose() == null and expired.source == "hidden",
				"expired first-refusal hold cannot restart across withheld frames "+str(index))
	check(host.physical_actor_session.bridge.body_transform(0).is_equal_approx(blocked) \
		and host.physical_actor_session.tick == native_step+1,
		"native receipt rejection does not change Rapier physical authority")

func _bounded_history_prefix() -> void:
	if expect_legacy or not await _install("follow"): return
	_move_actual(SPAWN+Vector2(5,0))
	_capture("history-initial-clear")
	_move_actual(SPAWN+Vector2(7,0),0.25)
	host._observe_workbench_presentation(0)
	var intermediate: Transform2D=_move_actual(SPAWN+Vector2(9,0),0.5)
	host._observe_workbench_presentation(0)
	var intermediate_step: int=host.physical_actor_session.tick
	var refused: Transform2D=_move_actual(Vector2(260,300),1.0)
	host._observe_workbench_presentation(0)
	var physical_step: int=host.physical_actor_session.tick
	var recovered: Dictionary=_capture("history-translating-rotating-prefix")
	check(_pose() is Transform2D and _pose().is_equal_approx(intermediate),
		"blocked latest pose advances to actual clear translating/rotating history endpoint")
	check(recovered.source=="history" and int(recovered.selected_step)==intermediate_step \
		and int(recovered.recovery_attempts)<=3,
		"bounded recovery records the real historical step and attempt count")
	check(host.physical_actor_session.tick==physical_step \
		and host.physical_actor_session.bridge.body_transform(0).is_equal_approx(refused),
		"historical presentation never changes latest physical pose or step")

func _paced_recovery_after_contact() -> void:
	if expect_legacy or not await _install("follow"): return
	_move_actual(SPAWN+Vector2(5,0))
	_capture("paced-initial-clear")
	for index: int in range(1,10):
		_move_actual(SPAWN+Vector2(5,-index),float(index)*0.03)
		host._observe_workbench_presentation(0)
	_move_actual(Vector2(260,300),0.6)
	var blocked: Dictionary=_capture("paced-genuine-contact")
	check(int(blocked.guard.blocked_material)>0 and blocked.source=="history",
		"genuine native Wall veto leaves a bounded clear observed prefix")
	var previous_step: int=int(blocked.selected_step)
	var previous_desired: int=int(blocked.desired_step)
	# Real physics leaves contact, but a delayed visual actor must not repay
	# all retained history in one source switch to the now-clear newest pose.
	var live: Transform2D=_move_actual(SPAWN+Vector2(5,-18),0.3)
	var physical_step: int=host.physical_actor_session.tick
	for index: int in range(3):
		var row: Dictionary=_capture("paced-clear-contact-"+str(index))
		var ceiling: int=previous_step+maxi(0,physical_step-previous_desired)+1
		check(_pose() is Transform2D and int(row.selected_step)>previous_step \
			and int(row.selected_step)<=ceiling,
			"recovery advances at most newly completed steps plus one retained sample")
		check(int(row.selected_step)<physical_step and row.source=="history",
			"clear live endpoint cannot bypass remaining visible playback lag")
		check(int(row.recovery_attempts)<=3,"paced playback retains three-attempt geometry bound")
		previous_step=int(row.selected_step)
		previous_desired=physical_step
	check(host.physical_actor_session.tick==physical_step \
		and host.physical_actor_session.bridge.body_transform(0).is_equal_approx(live),
		"paced recovery does not change the stopped authoritative physical state")

func _expire_blend() -> void:
	host.snapshot_blend_start_usec=Time.get_ticks_usec()-2000000

func _activate_blend() -> void:
	host.snapshot_blend_start_usec=Time.get_ticks_usec()
	if host.get("material_presentation_timeline") != null:
		var previous: Dictionary = host.material_presentation_timeline.frame(Time.get_ticks_usec()).previous
		check(previous.get("generation",-1) == host.last_uploaded_world_generation,
			"active blend uses the actual native same-World predecessor")

func _real_unknown_previous() -> void:
	if not await _install("follow"): return
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE","legacy")
	host.paused=true
	host.update_worker_frame_state()
	host.set_process(true)
	host.set_physics_process(true)
	var old_serial: int=host.last_uploaded_render_snapshot_serial
	host.simulation_worker.request_render_full_refresh()
	if not check(await until(func() -> bool:
		return host.last_uploaded_render_snapshot_serial>old_serial and host.last_render_was_full_refresh \
			and host._valid_workbench_mask_frame(host.workbench_display_frame())),
		"genuine full native material refresh uploaded for previous-texture uncertainty"): return
	host.set_process(false)
	host.set_physics_process(false)
	check(host.last_render_patch_bytes>host.PRESENTATION_PREVIOUS_PATCH_LIMIT \
		and host._presentation_previous_unknown,"legacy genuine old texture exceeds exact history bound")
	host.paused=false
	var frame: Dictionary=host.workbench_display_frame().duplicate(true)
	var bound: Transform2D=frame.instances[1].pose
	var live: Transform2D=_move_actual(bound.origin+Vector2(0,-5))
	_expire_blend()
	_capture("unknown-expired-clear",false,frame)
	check(_pose() is Transform2D and _pose().origin.distance_to(live.origin)<0.01,
		"exact native receipt admits live actor when previous texture is expired")
	host.render_snapshot_hz=1
	_activate_blend()
	var active: Dictionary=_capture("unknown-active-veto",false,frame)
	if expect_legacy:
		check(_pose() is Transform2D and _pose().origin.distance_to(bound.origin)<0.01,
			"old active previous-texture uncertainty reproduces mask rewind")
	else:
		check(_pose()==null,"genuine previous-texture uncertainty withholds unprovable pose")
		check(str(active.get("reason","")).contains("previous") or int(active.guard.get("blocked_unknown",0))>0,
			"unknown old texture withholding has explicit safety reason")
	_expire_blend()
	_capture("unknown-expired-rejoin",false,frame)
	check(_pose() is Transform2D and _pose().origin.distance_to(live.origin)<0.01,
		"expired previous texture rejoins actual selected timeline")
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE","")

func _native_paint(cell: Vector2i, material: int) -> bool:
	print("TEMPORAL_STAGE paint ",cell," ",material)
	# Ordinary native edit queue and receipt; no Image.set_pixel shortcuts.
	host.paused=true
	host.update_worker_frame_state()
	host.set_process(true)
	var state: Dictionary=host.simulation_worker.paint_state()
	var queued: Dictionary=host.simulation_worker.paint_queue({"kind":"edit",
		"cells":PackedInt32Array([cell.x,cell.y,material]),
		"expected_generation":int(state.generation),"expected_revision":int(state.revision),
		"expected_tick":int(state.tick)})
	if not check(queued.get("status","")=="queued","native PAINT queued material "+str(material)): return false
	if not check(await until(func() -> bool: return host.simulation_worker.paint_state().receipt_ready),
		"native PAINT receipt completed for "+str(material)): return false
	var result: Dictionary=host.simulation_worker.paint_take_result()
	receipts.append({"cell":[cell.x,cell.y],"material":material,"status":result.get("status",""),
		"after":Array(result.get("after",PackedInt32Array()))})
	if not check(result.get("status","")=="completed" \
		and result.get("after",PackedInt32Array())==PackedInt32Array([material]),
		"native PAINT authoritative readback equals requested material"): return false
	if not check(await until(func() -> bool:
		return host.image.get_pixel(cell.x,cell.y).r8==material),
		"native edit reaches actual uploaded material"): return false
	host.set_process(false)
	host.paused=false
	return true

func _paint_revalidates_hold() -> void:
	print("TEMPORAL_STAGE paint-hold")
	if expect_legacy or not await _install("follow"): return
	var clear: Transform2D=_move_actual(SPAWN+Vector2(5,0))
	_capture("paint-before-clear")
	_move_actual(Vector2(260,300))
	_capture("paint-before-hold")
	if not check(_pose() is Transform2D and _pose().origin.distance_to(clear.origin)<0.01,
		"native PAINT control starts from certified held pose"): return
	var held_step: int=host.workbench_presentation_frame.selected_steps.get(0,-1)
	var cell:=Vector2i(245,300)
	if not await _native_paint(cell,6): return
	_expire_blend()
	var physical_before: Transform2D=host.physical_actor_session.bridge.body_transform(0)
	var tick: int=host.physical_actor_session.tick
	_capture("paint-occupied-held-footprint")
	check(_pose()==null,"new actual Fire under prior held footprint invalidates safety certificate")
	check(host.workbench_presentation_frame.sources.get(0,"hidden")=="hidden",
		"occupied held footprint explicitly withholds instead of restoring old native pose")
	# Paused PAINT may invalidate the native actor receipt until a tick. The
	# production path must hide then; separately exercise the exact stationary
	# recertification query against those actual native current/previous bytes.
	var assess: Callable=Clearance.assess
	var current_check: Dictionary=assess.callv([clear,clear,host.physical_actor_session.bridge._rects[0],
		host.image,{},false,false,Clearance.MAX_SCAN_CELLS,0,null,true])
	check(not current_check.safe and current_check.reason=="material_in_swept_mask",
		"forced zero-motion recertification detects new native material under held pose")
	if not await _native_paint(cell,0): return
	var previous: Image=host._presentation_previous_image
	check(previous!=null and previous!=host.image and previous.get_pixel(cell.x,cell.y).r8==6,
		"real native erase retains old-only Fire in distinct previous texture source")
	check(host.image.get_pixel(cell.x,cell.y).r8==0,"erased current material is Empty")
	if DisplayServer.get_name()!="headless":
		var gpu_old: Image=host.previous_texture.get_image()
		check(gpu_old!=null and gpu_old.get_pixel(cell.x,cell.y).r8==6,
			"GPU previous texture still contains the actual erased Fire")
	host.render_snapshot_hz=1
	_activate_blend()
	_capture("paint-old-fire-crossfade-active")
	check(_pose()==null,"active actual previous-texture Fire forbids recertifying held actor")
	var old_check: Dictionary=assess.callv([clear,clear,host.physical_actor_session.bridge._rects[0],
		host.image,{},false,true,Clearance.MAX_SCAN_CELLS,0,previous,true])
	check(not old_check.safe and old_check.reason=="material_in_swept_mask",
		"stationary recertification refuses actual old-only Fire through active crossfade")
	_expire_blend()
	_capture("paint-old-fire-crossfade-expired")
	var expired_check: Dictionary=assess.callv([clear,clear,host.physical_actor_session.bridge._rects[0],
		host.image,{},false,false,Clearance.MAX_SCAN_CELLS,0,previous,true])
	check(expired_check.safe,"expired old Fire no longer blocks the actual cleared footprint")
	if _pose() is Transform2D:
		check(int(host.workbench_presentation_frame.selected_steps.get(0,-2))>=held_step,
			"valid post-erase presentation never substitutes older native sample time")
	else:
		check(not host._valid_workbench_mask_frame(host.workbench_display_frame()),
			"expired-crossfade withholding is explained by genuinely invalidated paused PAINT receipt")
	check(host.physical_actor_session.tick==tick \
		and host.physical_actor_session.bridge.body_transform(0).is_equal_approx(physical_before),
		"PAINT and visual withholding preserve authoritative physical state")
	# A genuine newer native receipt must also admit a rapid physical move
	# beyond the per-render sweep limit; never clamp the authoritative pose.
	var recovery: Transform2D=_move_actual(SPAWN+Vector2(0,-80))
	check(recovery.origin.distance_to(clear.origin)>Clearance.MAX_SHIFT_CELLS,
		"rapid recovery exceeds the incremental presentation sweep bound")
	var published_step: int=host.physical_actor_session.tick
	host._publish_physical_body_state()
	var published_sample: int=host._workbench_wait_sample
	host.update_worker_frame_state()
	host.set_process(false)
	if not check(await until(func() -> bool:
		host.consume_worker_snapshot()
		var frame: Dictionary=host.workbench_display_frame()
		return host._valid_workbench_mask_frame(frame) and frame.instances.has(1) \
			and int(frame.instances[1].get("sample",-1))==published_sample),
		"native completion returns actual published Rapier sample after PAINT"): return
	host.set_process(false)
	_expire_blend()
	var received: Dictionary=host.workbench_display_frame().instances[1]
	check(host._workbench_bound_step(received)==published_step,
		"native mask receipt maps to exact published Rapier step, independently of native tick")
	receipts.append({"sample":published_sample,"published_rapier_step":published_step,
		"bound_rapier_step":host._workbench_bound_step(received),"native_tick":host.latest_snapshot.tick_index})
	var resumed: Dictionary=_capture("paint-cleared-resume")
	check(_pose() is Transform2D and _pose().origin.distance_to(recovery.origin)<0.01,
		"newer actual native receipt rejoins rapid movement without smoothing or clamping")
	check(int(host.workbench_presentation_frame.selected_steps.get(0,-2))>=held_step,
		"recomputed real native receipt rejoins without temporal rewind")
	check(resumed.explicit_reentry,"80-cell controlled physical reset rejoins through explicit prior suppression")

func _session_reset_at_world_edge() -> void:
	if expect_legacy: return
	var previous_session: int=host.physical_actor_session.bridge._session
	var previous_tick: int=host.physical_actor_session.tick
	if not await _install("follow",Vector2(5,300)): return
	_capture("session-reset-valid-world-edge")
	check(host.physical_actor_session.bridge._session!=previous_session \
		and host.physical_actor_session.tick<previous_tick,
		"genuine replacement session can restart simulation index")
	var live: Transform2D=host.physical_actor_session.bridge.body_transform(0)
	check(_pose() is Transform2D and _pose().origin.distance_to(live.origin)<0.01,
		"valid near-edge native actor displays its current pose after session replacement")
	check(live.origin.x<6.0 and live.origin.x>4.5,
		"edge fixture places actual9x6 collider fully inside World despite larger turning-radius bounds")

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	root.add_child(host)
	root.size=Vector2i(1280,800)
	ui=host.shared_workbench
	if check(await until(func() -> bool: return ui!=null and not ui.applied.is_empty()),
			"mounted real native Shared Workbench ready"):
		if not expect_legacy: check(host.has_method("_resolve_workbench_presentation_frame"),"coherent frame resolver is installed")
		await _source_oscillation("free")
		await _source_oscillation("follow")
		await _long_clear_path()
		await _bounded_history_prefix()
		await _expired_history_stays_withheld()
		await _expired_native_receipt_first_refusal()
		await _paced_recovery_after_contact()
		await _bounded_native_rejoin()
		await _real_unknown_previous()
		await _paint_revalidates_hold()
		await _session_reset_at_world_edge()
	var result: Dictionary={"schema":"workbench-temporal-presentation-v1","checks":checks,
		"failures":failures,"expect_legacy":expect_legacy,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"platform":OS.get_name(),"display_server":DisplayServer.get_name(),"engine":Engine.get_version_info().string,
		"scope":"Mounted Main/native World/material receipts and real Rapier RID with completed steps. Controlled causal pose stimuli; not physical GPU acceptance.",
		"observations":observations,"receipts":receipts}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var writer: FileAccess=FileAccess.open(output.path_join("temporal.json"),FileAccess.WRITE)
		if writer!=null:
			writer.store_string(JSON.stringify(result,"  ")+"\n")
			writer.close()
		else: check(false,"temporal evidence file can be written")
	for key: String in saved_environment: OS.set_environment(key,str(saved_environment[key]))
	host.queue_free()
	await process_frame
	await process_frame
	print("TEMPORAL_PRESENTATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"expect_legacy":expect_legacy,"observations":observations.size()}))
	quit(int(not failures.is_empty()))
