extends "res://tests/test_persistent_areas_workbench.gd"

# Paired apparatus: run control and prefetch in genuinely separate fresh
# processes/profiles, with the same runtime, renderer and native worker count.
# Each begins from the exact authored B continuation at native/game tick zero.
# Setup, Save and arrival are outside the finite active measurement window.
var responsiveness_variant := "control"
var window_msec := 5000
var prefetch_delay_msec := 1000
var frame_intervals: Array[Dictionary] = []
var responsiveness: Dictionary = {}
var _collecting := false
var _last_frame_usec := 0
var _last_frame_tick := 0
var _request_sent := false
var _reverse_sent := false
var _reverse_request_pending := false


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--responsiveness-variant="):
			responsiveness_variant = argument.trim_prefix("--responsiveness-variant=")
		if argument.begins_with("--responsiveness-window-ms="):
			window_msec = clampi(int(argument.trim_prefix("--responsiveness-window-ms=")),3000,10000)
	process_frame.connect(_observe_active_frame)
	super._initialize()


func layout_checks() -> void:
	# The other graphical fixture exercises modal sizing. Keep this matched
	# performance workload at one fixed viewport throughout both processes.
	root.size = Vector2i(1280,720)
	await process_frame
	await process_frame


func _configure(changes: Dictionary) -> bool:
	var configuration: Dictionary = controller._cache_configuration.duplicate(true)
	configuration.merge(changes,true)
	if not check(controller.request_cache_configuration(configuration),"matched cache configuration admitted"): return false
	return await operation_finished("matched cache configuration")


func _residents() -> Dictionary:
	var id: String = controller.AreaStore.new_nonce()
	var admitted: Dictionary = worker.persistent_request({"kind":"resident_status","operation_id":id})
	if not check(admitted.get("ok",false),"actual native residency observation admitted"): return {}
	var observed: Dictionary = {}
	var deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		observed = worker.persistent_poll(int(admitted.token))
		if str(observed.get("status","")) in ["complete","failed"]: break
		await process_frame
	if not check(observed.get("ok",false) and str(observed.get("status",""))=="complete",
		"actual native residency observation completed"): return {}
	return observed.result


func exercise_write() -> void:
	if not check(responsiveness_variant in ["control","prefetch","reversal"],"known matched responsiveness variant"): return
	if not check(controller.active_area=="a" and int(controller.clock.game_ticks)==0,
		"matched responsiveness uses a fresh paused profile"): return
	if not await _configure({"enabled":true,"budget_bytes":512*1024*1024,"deferred":true,
		"background":false,"prefetch":false}): return
	if not await travel("b"): return
	if not await save_current("exact initial B checkpoint before responsiveness window"): return
	# Suppress automatic adjacency scheduling in this controlled apparatus.
	# The candidate admits exactly one explicit C request in the active window;
	# reversal is a separate labelled case, never mixed with the paired result.
	controller._last_prediction_msec = Time.get_ticks_msec()+120000
	controller._prefetch_intent = "c"
	if not await _configure({"prefetch":responsiveness_variant!="control"}): return
	if not await until(settled,"matched initial state settled"): return
	var before: Dictionary = await _residents()
	if before.is_empty(): return
	var initial: Dictionary = controller.manifest.areas.b.duplicate(true)
	var target: Dictionary = controller._cache.entry("c")
	if not check(controller.active_area=="b" and host.paused and int(host.latest_snapshot.tick_index)==0 \
		and int(controller.clock.game_ticks)==0 and int(initial.completed_tick)==0,
		"each active window begins at the exact B native/game-time origin"): return
	if not check(target.hot.is_empty() and target.warm.is_empty(),"C is genuinely COLD before candidate preparation"): return
	if not check(int(controller._io_metrics.prefetch_requests)==0,"no speculative request precedes the measured window"): return
	var active_handle := int(before.active.handle)
	var active_generation := int(host.latest_snapshot.render_world_generation)
	responsiveness = {"schema":"gen006-ramcache-responsiveness-v1","variant":responsiveness_variant,
		"identity":controller.diagnostic_identity(),"graphical":graphical,"process_id":OS.get_process_id(),
		"initial":{"area_id":"b","native_sha256":initial.native_sha256,"physical_hash":initial.physical_hash,
			"authoring_sha256":initial.authoring_sha256,"authored_source_sha256":initial.authored_source_sha256,
			"physics_profile_sha256":initial.physics_profile_sha256,"native_tick":0,"game_tick":0,
			"worker_threads":int(before.active.worker_threads),"extent":[host.world_extent.x,host.world_extent.y],
			"camera_origin":[host.camera_origin.x,host.camera_origin.y],"view_size":[host.current_view_size.x,host.current_view_size.y],
			"target_native_sha256":controller.manifest.areas.c.native_sha256,
			"target_source_sha256":controller.manifest.areas.c.authored_source_sha256,
			"target_residency":"COLD","active_handle":active_handle,"world_generation":active_generation},
		"apparatus":{"automatic_prediction_suppressed":true,"background_checkpointing":false,
			"requested_window_msec":window_msec,"explicit_request_delay_msec":prefetch_delay_msec,
			"active_area":"b","prefetch_target":"c","arrival_outside_window":true},
		"io_before":controller._io_metrics.duplicate(true),"native_before":before.counters.duplicate(true)}
	await process_frame
	await process_frame
	var started := Time.get_ticks_usec()
	_last_frame_usec = started
	_last_frame_tick = int(host.latest_snapshot.tick_index)
	_collecting = true
	if not check(bench.toggle_pause(),"real native B gameplay starts for the finite active window"):
		_collecting = false
		return
	while Time.get_ticks_usec()-started<int(window_msec)*1000:
		await process_frame
		var elapsed := Time.get_ticks_usec()-started
		if responsiveness_variant!="control" and not _request_sent and elapsed>=prefetch_delay_msec*1000:
			_request_sent = true
			responsiveness["explicit_request_usec"] = Time.get_ticks_usec()
			if not check(controller.request_prefetch("c"),"explicit C preparation admitted during active B gameplay"):
				_collecting = false
				return
		if responsiveness_variant=="reversal" and _request_sent and not _reverse_sent \
			and int(controller._prefetch_token)>0 and controller._prefetch_busy:
			_reverse_sent = true
			_reverse_request_pending = true
			responsiveness["reversal_usec"] = Time.get_ticks_usec()
			check(controller.request_prefetch("a"),"reverse intent cancels the outstanding C preparation")
		if _reverse_request_pending and not controller._prefetch_busy:
			_reverse_request_pending = false
			check(controller.request_prefetch("a"),"reversed A preparation admitted after obsolete work retires")
	var ended := Time.get_ticks_usec()
	_observe_active_frame(ended)
	_collecting = false
	responsiveness["window_start_usec"] = started
	responsiveness["window_end_usec"] = ended
	responsiveness["actual_window_usec"] = ended-started
	responsiveness["native_ticks_observed_in_window"] = int(host.latest_snapshot.tick_index)
	responsiveness["global_tick_observed_at_window_end"] = int(controller.clock.game_ticks)
	responsiveness["target_hot_at_window_end"] = not controller._cache.entry("c").hot.is_empty()
	responsiveness["prefetch_busy_at_window_end"] = controller._prefetch_busy
	responsiveness["frame_intervals"] = frame_intervals.duplicate(true)
	responsiveness["frame_statistics"] = _frame_statistics()
	responsiveness["io_at_window_end"] = controller._io_metrics.duplicate(true)
	check(bench.toggle_pause(),"active B pauses after the measured window")
	if responsiveness_variant=="prefetch":
		var completed_in_window := false
		for preparation: Dictionary in controller.metrics.prefetch_records:
			if preparation.status!="completed" or preparation.area_id!="c": continue
			completed_in_window = _preparation_within_window(preparation,started,ended)
		responsiveness["all_candidate_preparation_inside_window"] = completed_in_window
		if not check(completed_in_window and responsiveness.target_hot_at_window_end \
			and not responsiveness.prefetch_busy_at_window_end and int(controller._io_metrics.prefetch_completed)==1,
			"entire cold preparation and cache admission complete inside the measured active window"):
			responsiveness["comparison_valid"] = false
			responsiveness["inconclusive_reason"] = "Candidate preparation exceeded the finite matched window; expand both cases equally before comparing."
			return
	if not check(controller.active_area=="b" and int(host.latest_snapshot.render_world_generation)==active_generation \
		and not worker.has_failed(),"private preparation never publishes a replacement active World"): return
	check(int(responsiveness.native_ticks_observed_in_window)>0,"window includes actual completed native B ticks")
	check(ended-started<=int(window_msec)*1000+3000000,"finite active window has no unbounded main-thread overrun")
	check(frame_intervals.size()>=10,"active window records a useful actual frame interval series")
	for frame: Dictionary in frame_intervals:
		if not check(frame.area_id=="b" and int(frame.world_generation)==active_generation,
			"each measured frame retains B's active authority"): return
	if responsiveness_variant=="control":
		check(int(controller._io_metrics.prefetch_requests)==0 and controller._cache.entry("c").hot.is_empty(),
			"control executes no speculation and leaves C cold")
	else:
		var destination := "a" if responsiveness_variant=="reversal" else "c"
		if not await until(func() -> bool:return not controller._prefetch_busy and not controller._cache.entry(destination).hot.is_empty(),
			"real destination preparation completes before arrival",90000): return
		if responsiveness_variant=="prefetch":
			check(int(controller._io_metrics.prefetch_requests)==1,"paired candidate has exactly one explicit C preparation")
			check(int(controller._io_metrics.prefetch_completed)==1,"paired candidate imports exactly one prepared destination")
		else:
			check(_reverse_sent and int(controller._io_metrics.prefetch_cancelled)>=1,
				"separate reversal case actually cancels obsolete preparation")
		var receipt: Dictionary = controller._cache.entry(destination).hot.duplicate(true)
		var restores := int(controller._io_metrics.native_deserializations)
		if not await travel(destination): return
		check(int(controller._cache.entry(destination).hot.handle)==int(receipt.handle) \
			and int(controller._io_metrics.native_deserializations)==restores,
			"arrival outside the measured window reuses the exact prepared native owner")
		responsiveness["arrival"] = controller.metrics.operation_records.back().duplicate(true)
		responsiveness["prepared_receipt"] = receipt
	var after: Dictionary = await _residents()
	if after.is_empty(): return
	responsiveness["native_after"] = after.counters.duplicate(true)
	responsiveness["prefetch_records"] = controller.metrics.prefetch_records.duplicate(true)
	responsiveness["cache_after"] = controller._cache.status(controller.clock)
	check(int(controller._cache.status().reserved_bytes)==0,"completed workload leaves no speculative reservation")
	responsiveness["completed"] = true
	responsiveness["comparison_valid"] = responsiveness_variant in ["control","prefetch"]
	await screenshot("responsiveness-"+responsiveness_variant+"-after-window")


func _preparation_within_window(preparation: Dictionary, started: int, ended: int) -> bool:
	var phases: Dictionary = preparation.get("phase_timestamps",{})
	var native_work: Dictionary = preparation.get("native_work",{})
	var stamps := [preparation.get("start_usec",0),phases.get("worker_admission_started_usec",0),
		native_work.get("prepare_started_usec",0),native_work.get("prepare_completed_usec",0),
		native_work.get("import_started_usec",0),native_work.get("import_completed_usec",0),
		phases.get("native_result_observed_usec",0),phases.get("cache_admission_started_usec",0),
		phases.get("cache_admission_finished_usec",0),preparation.get("end_usec",0)]
	var previous := started
	for stamp: Variant in stamps:
		if not stamp is int or int(stamp)<=0 or int(stamp)<previous or int(stamp)>ended: return false
		previous = int(stamp)
	var admission_end: Variant = phases.get("worker_admission_finished_usec",0)
	return admission_end is int and int(admission_end)>=int(stamps[1]) and int(admission_end)<=int(stamps[6])


func _observe_active_frame(terminal_usec: int = 0) -> void:
	if not _collecting or host==null or host.latest_snapshot==null: return
	var now := terminal_usec if terminal_usec>0 else Time.get_ticks_usec()
	if now<=_last_frame_usec: return
	var tick := int(host.latest_snapshot.tick_index)
	frame_intervals.append({"start_usec":_last_frame_usec,"end_usec":now,"interval_usec":now-_last_frame_usec,
		"native_tick_before":_last_frame_tick,"native_tick_after":tick,"area_id":controller.active_area,
		"world_generation":int(host.latest_snapshot.render_world_generation),"snapshot_serial":int(host.latest_snapshot.serial),
		"game_tick":int(controller.clock.game_ticks),"prefetch_busy":controller._prefetch_busy,
		"prefetch_operation_id":str(controller._prefetch_operation.get("operation_id","")),
		"prefetch_status":str(controller._prefetch_state.get("status","")),"terminal_partial":terminal_usec>0})
	_last_frame_usec = now
	_last_frame_tick = tick


func _frame_statistics() -> Dictionary:
	var values: Array[float] = []
	for frame: Dictionary in frame_intervals: values.append(float(frame.interval_usec)/1000.0)
	values.sort()
	if values.is_empty(): return {"count":0}
	return {"count":values.size(),"p50_ms":values[int(ceil(values.size()*0.5))-1],
		"p95_ms":values[int(ceil(values.size()*0.95))-1],"worst_ms":values.back(),
		"scope":"Every observed frame interval within this finite active window, including its terminal partial interval."}


func _finish() -> void:
	_collecting = false
	check(bool(responsiveness.get("completed",false)),"matched responsiveness campaign reached all assertions")
	responsiveness["checks"] = checks
	responsiveness["failures"] = failures.duplicate()
	if not output.is_empty(): write_json(output.path_join("responsiveness-"+responsiveness_variant+".json"),responsiveness)
	print("GEN006_RAMCACHE_RESPONSIVENESS ",JSON.stringify({"variant":responsiveness_variant,"checks":checks,
		"failures":failures,"graphical":graphical,"pid":OS.get_process_id()}))
	await super._finish()
