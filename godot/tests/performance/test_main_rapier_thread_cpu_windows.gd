extends "res://tests/play_life001_shared_host_case.gd"

# INV-004 existing native Rapier bridge step/flush readback split with original-dispatch ABBA controls. This is an actual
# main.tscn, native CyberSimulationWorker and main-thread Rapier lifetime. It
# does not alter production physics, presentation, clocks or worker cadence.
# HOST RESTRICTION: graphical Windows ANGLE, not --headless.
const RIG: StringName = &"acrobat"
const MAX_PROCESS_ROWS: int = 12000
const MAX_DRAW_ROWS: int = 12000
const PERIOD_USEC: int = 100000
const PHASE_SECONDS: float = 4.0
var phase: String = "setup"
var desktop: Control
var process_rows: Array[Dictionary] = []
var draw_rows: Array[Dictionary] = []
var pre_draw_rows: Array[Dictionary] = []
var physics_rows: Array[Dictionary] = []
const MAX_SIGNAL_ROWS: int = 12000
var fps_readbacks: Dictionary = {}
var original_max_fps: int = 0
var original_vsync: int = -1
var last_draw_usec: int = 0
var last_draw_phase: String = ""
var viewport_rid: RID
var overflow: bool = false
var accepted_brush_commands: int = 0
var attempted_brush_commands: int = 0
var main_started_usec: int = 0
var main_ack_usec: int = 0
var profiling_enabled: bool = OS.get_environment("CYBERSAND_THREAD_CPU") == "1"
var bridge_state_preserved: bool = false
var counter_calibration: Array[Dictionary] = []


class ObservedBridge:
	extends "res://scripts/rapier_physics_bridge.gd"
	var probe_enabled: bool = false
	var probe_record: Dictionary = {}

	# Strip only CPU_PROBE lines and the disabled branch to recover source step().
	func step() -> void:
		if not probe_enabled: # CPU_PROBE
			super() # CPU_PROBE
			return # CPU_PROBE
		if not _initialized:
			return
		var cpu_before: PackedInt64Array = ClassDB.class_call_static(&"CyberRapierThreadProbe", &"sample") # CPU_PROBE
		var wall_before: int = Time.get_ticks_usec() # CPU_PROBE
		var step_start_usec: int = Time.get_ticks_usec()
		ClassDB.class_call_static(EXPECTED_SERVER_CLASS, &"space_step", _space, fixed_delta())
		_last_step_time_ms = float(Time.get_ticks_usec() - step_start_usec) / 1000.0
		var wall_after: int = Time.get_ticks_usec() # CPU_PROBE
		var cpu_after: PackedInt64Array = ClassDB.class_call_static(&"CyberRapierThreadProbe", &"sample") # CPU_PROBE
		probe_record = {"cpu_before":cpu_before,"cpu_after":cpu_after,"wall_before_usec":wall_before,"wall_after_usec":wall_after} # CPU_PROBE
		_manual_step_count += 1
	
		# Rapier exposes an active-body batch path, avoiding stale scene-node caches
		# and preparing the bridge for a larger dynamic-body count.
		var active_body_rids: Array = ClassDB.class_call_static(EXPECTED_SERVER_CLASS, &"space_get_active_bodies", _space)
		var active_transforms: Array = ClassDB.class_call_static(
			EXPECTED_SERVER_CLASS, &"space_get_bodies_transform",
			_space,
			active_body_rids
		)
		_last_active_body_count = active_body_rids.size()
		var active_count: int = mini(active_body_rids.size(), active_transforms.size())
		for active_index: int in range(active_count):
			var body_rid: RID = active_body_rids[active_index]
			if not _body_index_by_rid.has(body_rid):
				continue
			var body_index: int = int(_body_index_by_rid[body_rid])
			_transforms[body_index] = active_transforms[active_index]
	
		var flush_start_usec: int = Time.get_ticks_usec()
		ClassDB.class_call_static(EXPECTED_SERVER_CLASS, &"space_flush_queries", _space)
		_last_flush_time_ms = float(Time.get_ticks_usec() - flush_start_usec) / 1000.0
		refresh_dynamic_states()


class ObservedMain:
	extends "res://scripts/main.gd"
	var measurement_phase: String = ""
	var cost_usec: Dictionary = {}
	var sink: Callable = Callable()
	var physics_sink: Callable = Callable()

	func actor_keyboard_allowed() -> bool:
		# Same harness focus policy as existing PLAY-LIFE and PLAY-PACE probes.
		return (not paused and actor_prototypes_allowed()
			and _physical_terrain_ready and _actor_reset_receipt == 0
			and not actor_prototype_panel.visible)

	func mark(bucket: String, started: int) -> void:
		if measurement_phase != "":
			cost_usec[bucket] = int(cost_usec.get(bucket, 0)) + Time.get_ticks_usec() - started

	func consume_worker_snapshot() -> void:
		var start: int = Time.get_ticks_usec()
		super()
		mark("consume", start)

	func update_worker_frame_state() -> void:
		var start: int = Time.get_ticks_usec()
		super()
		mark("worker_state", start)

	func update_shader_parameters() -> void:
		var start: int = Time.get_ticks_usec()
		super()
		mark("shader_parameters", start)

	func update_brush_preview() -> void:
		var start: int = Time.get_ticks_usec()
		super()
		mark("brush_preview", start)

	func handle_painting() -> void:
		var start: int = Time.get_ticks_usec()
		super()
		mark("painting", start)

	func update_camera(delta: float) -> void:
		var start: int = Time.get_ticks_usec()
		super(delta)
		mark("camera", start)

	func _present_playable_course_targets() -> void:
		var start: int = Time.get_ticks_usec()
		super()
		mark("course_targets", start)

	func update_status() -> void:
		var start: int = Time.get_ticks_usec()
		super()
		mark("status", start)

	func _process(delta: float) -> void:
		var start: int = Time.get_ticks_usec()
		cost_usec = {}
		super(delta)
		if measurement_phase.is_empty():
			return
		var completed: int = Time.get_ticks_usec()
		var packet: CyberSimulationSnapshot = latest_snapshot
		var row: Dictionary = {
			"phase": measurement_phase, "start_usec": start, "end_usec": completed,
			"total_usec": completed - start, "cost_usec": cost_usec.duplicate(),
			"frame": Engine.get_process_frames(),
			"render_serial": int(packet.render_snapshot_serial) if packet != null else -1,
			"tick": int(packet.tick_index) if packet != null else -1,
			"worker_pub_usec": int(packet.published_usec) if packet != null else 0,
			"render_pub_usec": int(packet.render_generated_usec) if packet != null else 0,
			"rapier_tick": int(physical_actor_session.tick) if physical_actor_session != null else -1,
			"render_patch_bytes": last_render_patch_bytes,
			"upload_ms_last": upload_time_ms,
			"native_worker_participation": packet.native_worker_participation.duplicate(true) if packet != null else {}
		}
		if sink.is_valid():
			sink.call(row)

	var wrapper_cost_usec: Dictionary = {}
	func observe_wrapper(bucket: String, begin_usec: int) -> void:
		if not measurement_phase.is_empty():
			wrapper_cost_usec[bucket] = int(wrapper_cost_usec.get(bucket,0)) + Time.get_ticks_usec() - begin_usec

	# Production physics dispatch remains inside super(delta), with additive
	# wrapper clocks around existing virtual calls. No copied Main callback.
	func publish_actor_keyboard_input() -> void:
		var begin_usec: int = Time.get_ticks_usec()
		super()
		observe_wrapper("keyboard", begin_usec)

	func publish_actor_usable_input() -> void:
		var begin_usec: int = Time.get_ticks_usec()
		super()
		observe_wrapper("usable", begin_usec)

	func apply_latest_rigid_body_results(snapshot: CyberSimulationSnapshot = null) -> void:
		var begin_usec: int = Time.get_ticks_usec()
		super(snapshot)
		observe_wrapper("apply_results", begin_usec)

	func _publish_physical_body_state() -> void:
		var begin_usec: int = Time.get_ticks_usec()
		super()
		observe_wrapper("body_publication", begin_usec)

	func _record_completed_playable_course_step() -> void:
		var begin_usec: int = Time.get_ticks_usec()
		super()
		observe_wrapper("course_observation", begin_usec)

	func _physics_process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		# These getters are existing production bridge counters, not new production clocks.
		# Never pair a stale step/flush readback with a callback that did not step.
		var bridge_count_before: int = rapier_bridge.manual_step_count()
		wrapper_cost_usec = {}
		if measurement_phase == "timed_a" or measurement_phase == "timed_b":
			_instrumented_dispatch(delta)
		else:
			super(delta)
		if measurement_phase.is_empty(): return
		var ended: int = Time.get_ticks_usec()
		# Keep the readback outside the measured dispatch duration and measure its cost.
		var readback_start_usec: int = Time.get_ticks_usec()
		var bridge_count_after: int = rapier_bridge.manual_step_count()
		var bridge_step_delta: int = bridge_count_after - bridge_count_before
		var bridge_step_usec: int = -1
		var bridge_flush_usec: int = -1
		var bridge_active_bodies: int = -1
		if bridge_step_delta == 1:
			bridge_step_usec = roundi(rapier_bridge.last_step_time_ms() * 1000.0)
			bridge_flush_usec = roundi(rapier_bridge.last_flush_time_ms() * 1000.0)
			bridge_active_bodies = rapier_bridge.last_active_body_count()
		var bridge_readback_usec: int = Time.get_ticks_usec() - readback_start_usec
		var attributed: int = 0
		for value in wrapper_cost_usec.values():
			attributed += int(value)
		if physics_sink.is_valid():
			physics_sink.call({"phase": measurement_phase, "start_usec":started,
				"end_usec":ended,"duration_usec":ended-started,
				"physics_frames":Engine.get_physics_frames(),
				"dispatch_mode":"copied_timed" if measurement_phase in ["timed_a", "timed_b"] else "original_super",
				"wrapper_usec":wrapper_cost_usec.duplicate(true),
				"attributed_usec":attributed,"residual_usec":ended-started-attributed,
				"actor_tick":int(physical_actor_session.tick) if physical_actor_session!=null else -1,
				"native_tick":int(latest_snapshot.tick_index) if latest_snapshot!=null else -1,
				"bridge_step_delta":bridge_step_delta,
				"bridge_step_usec":bridge_step_usec,
				"bridge_flush_usec":bridge_flush_usec,
				"bridge_active_bodies":bridge_active_bodies,
				"bridge_readback_usec":bridge_readback_usec,
				"cpu_probe":rapier_bridge.probe_record.duplicate(true) if rapier_bridge is ObservedBridge else {}})

	# EXPERIMENTAL copied Main dispatcher; exact-source guard and mechanical clock removal verified in CI.
	func _instrumented_dispatch(_delta: float) -> void:
		var stage_started_usec: int = 0
		if _pending_physical_candidate != null:
			# The retained manually stepped space stays at its actual prior pose.
			# Do not reconfigure its equipment, revoke its leases or publish stale
			# body frames while the separate replacement graph is being prepared.
			return
		var single_step: bool = shared_workbench != null and shared_workbench.step_requested and paused
		if physical_actor_session != null:
			stage_started_usec = Time.get_ticks_usec()
			physical_actor_session.set_suspended((paused and not single_step) or simulation_worker.has_failed()
				or not _physical_terrain_ready or _actor_reset_receipt != 0
				or not pending_microscenario_apply.is_empty())
			observe_wrapper("session_suspend", stage_started_usec)
		publish_actor_keyboard_input()
		publish_actor_usable_input()
		var physics_snapshot: CyberSimulationSnapshot = latest_snapshot
		if shared_workbench != null and physical_actor_session != null:
			# Physics can consume an immutable completion before the next render
			# callback. Its native terrain revision, sample fence and wrench must
			# all belong to the same publication.
			stage_started_usec = Time.get_ticks_usec()
			physics_snapshot = simulation_worker.take_latest_snapshot(0)
			observe_wrapper("take_snapshot", stage_started_usec)
			if physics_snapshot == null or physics_snapshot.simulation_failed or physics_snapshot.rigid_body_epoch != _body_owner_epoch(): return
			if not str(physics_snapshot.lab_context.get("workbench_refusal","")).is_empty(): return
			if not _workbench_terrain_installed(physics_snapshot): return
			if paused and not single_step:
				_workbench_wait_sample = -1
				return
			# A single step can restart a previously unpublished paused frame.
			if _workbench_wait_sample >= 0 and physics_snapshot.lab_context.get("workbench_completed_sample",-1) != _workbench_wait_sample and not single_step: return
		if paused or simulation_worker.has_failed():
			physical_trial_input.armed = false
		if simulation_worker.has_failed():
			return
		if (
			rapier_bridge.is_initialized()
			and (not paused or single_step)
			and worker_start_error == OK
			and _actor_reset_receipt == 0
			and pending_microscenario_apply.is_empty()
			and (physical_actor_session == null or _physical_terrain_ready)
		):
			apply_latest_rigid_body_results(physics_snapshot)
			if physical_actor_session != null:
				stage_started_usec = Time.get_ticks_usec()
				physical_actor_session.advance(rapier_bridge.fixed_delta())
				observe_wrapper("session_advance", stage_started_usec)
			else:
				apply_barrel_player_control(_delta)
			stage_started_usec = Time.get_ticks_usec()
			rapier_bridge.step()
			observe_wrapper("rapier_step", stage_started_usec)
			if physical_actor_session != null:
				var before_completed_tick: int = physical_actor_session.tick
				stage_started_usec = Time.get_ticks_usec()
				physical_actor_session.complete_step()
				observe_wrapper("session_complete", stage_started_usec)
				# A gate visited and left between two rendered frames must still
				# count. This callback owns actual completed Rapier observations.
				if physical_actor_session.tick > before_completed_tick:
					_record_completed_playable_course_step()
		_publish_physical_body_state()
		if single_step and pending_microscenario_apply.is_empty() and worker_start_error == OK and (physical_actor_session == null or _physical_terrain_ready):
			shared_workbench.step_requested = false
			tower_command({"step":true,"workbench_step_serial":shared_workbench.step_serial})
			if physical_actor_session != null: physical_actor_session.set_suspended(true)

func retain_physics(row: Dictionary) -> void:
	if physics_rows.size() >= MAX_SIGNAL_ROWS:
		overflow = true
		return
	physics_rows.append(row)


func pre_drawn() -> void:
	if desktop != null and is_instance_valid(desktop) and phase in [
		"baseline_a", "timed_a", "timed_b", "baseline_b"]:
		if pre_draw_rows.size() >= MAX_SIGNAL_ROWS:
			overflow = true
			return
		pre_draw_rows.append({"phase": phase, "usec": Time.get_ticks_usec(),
			"frame": Engine.get_process_frames()})


func retain_process(row: Dictionary) -> void:
	if process_rows.size() >= MAX_PROCESS_ROWS:
		overflow = true
		return
	process_rows.append(row)


func drawn() -> void:
	var now: int = Time.get_ticks_usec()
	if desktop != null and is_instance_valid(desktop) and phase in ["baseline_a", "timed_a", "timed_b", "baseline_b"]:
		if last_draw_phase == phase and last_draw_usec > 0:
			if draw_rows.size() < MAX_DRAW_ROWS:
				draw_rows.append({
					"phase": phase, "draw_usec": now,
					"interval_usec": now - last_draw_usec,
					"cpu_render_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid),
					"gpu_render_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
				})
			else:
				overflow = true
	last_draw_usec = now
	last_draw_phase = phase


func quantiles(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"n": 0}
	values.sort()
	var n: int = values.size()
	return {"n": n, "p50": values[int(round((n - 1) * 0.50))],
		"p95": values[int(round((n - 1) * 0.95))],
		"p99": values[int(round((n - 1) * 0.99))], "max": values[n - 1]}


func summarize(label: String) -> Dictionary:
	var selected: Array[Dictionary] = process_rows.filter(
		func(row: Dictionary) -> bool: return row.phase == label)
	var draws: Array[Dictionary] = draw_rows.filter(
		func(row: Dictionary) -> bool: return row.phase == label)
	var buckets: Dictionary = {}
	var totals: Array[float] = []
	var visible_ages: Array[float] = []
	var newest_tick: int = -1
	var oldest_tick: int = -1
	var newest_rapier: int = -1
	var oldest_rapier: int = -1
	var last_render_serial: int = -1
	var new_render_publications: int = 0
	for row: Dictionary in selected:
		totals.append(float(row.total_usec) / 1000.0)
		for key: String in row.cost_usec:
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(float(row.cost_usec[key]) / 1000.0)
		if int(row.worker_pub_usec) > 0 and int(row.end_usec) >= int(row.worker_pub_usec):
			visible_ages.append(float(int(row.end_usec) - int(row.worker_pub_usec)) / 1000.0)
		if int(row.tick) >= 0:
			if oldest_tick == -1: oldest_tick = int(row.tick)
			newest_tick = int(row.tick)
		if int(row.rapier_tick) >= 0:
			if oldest_rapier == -1: oldest_rapier = int(row.rapier_tick)
			newest_rapier = int(row.rapier_tick)
		if int(row.render_serial) >= 0 and int(row.render_serial) != last_render_serial:
			new_render_publications += 1
			last_render_serial = int(row.render_serial)
	var distributions: Dictionary = {}
	for key: String in buckets:
		var values: Array[float] = []
		for v: float in buckets[key]:
			values.append(v)
		distributions[key] = quantiles(values)
	var intervals: Array[float] = []
	var renderer_cpu: Array[float] = []
	var renderer_gpu: Array[float] = []
	for draw: Dictionary in draws:
		intervals.append(float(draw.interval_usec) / 1000.0)
		renderer_cpu.append(float(draw.cpu_render_ms))
		renderer_gpu.append(float(draw.gpu_render_ms))
	var elapsed_seconds: float = float(int(selected.back().end_usec) -
		int(selected.front().start_usec)) / 1000000.0 if selected.size() >= 2 else 0.0
	return {
		"process": quantiles(totals), "subcalls_inclusive_ms": distributions,
		"render_interval_ms": quantiles(intervals),
		"viewport_cpu_ms": quantiles(renderer_cpu),
		"viewport_gpu_ms": quantiles(renderer_gpu),
		"worker_publication_age_ms": quantiles(visible_ages),
		"render_publications_observed": new_render_publications,
		"native_ticks_per_second": float(newest_tick - oldest_tick) / elapsed_seconds
			if elapsed_seconds > 0.0 and oldest_tick >= 0 else -1.0,
		"rapier_steps_per_second": float(newest_rapier - oldest_rapier) / elapsed_seconds
			if elapsed_seconds > 0.0 and oldest_rapier >= 0 else -1.0,
		"elapsed_seconds": elapsed_seconds
	}



func wrapper_distribution(label: String) -> Dictionary:
	var selected: Array[Dictionary] = physics_rows.filter(
		func(row: Dictionary) -> bool: return row.phase == label)
	var complete: Array[float] = []
	var residual: Array[float] = []
	var buckets: Dictionary = {}
	var long_count: int = 0
	for row: Dictionary in selected:
		complete.append(float(row.duration_usec) / 1000.0)
		residual.append(float(row.residual_usec) / 1000.0)
		if int(row.duration_usec) > 40000: long_count += 1
		for key: String in row.wrapper_usec:
			if not buckets.has(key): buckets[key] = []
			buckets[key].append(float(row.wrapper_usec[key]) / 1000.0)
	var observed: Dictionary = {}
	for key: String in buckets:
		var values: Array[float] = []
		for value: float in buckets[key]: values.append(value)
		observed[key] = quantiles(values)
	return {"all_ms": quantiles(complete), "residual_ms": quantiles(residual),
		"wrapper_ms": observed, "over_40ms": long_count}


func hold(label: String) -> void:
	phase = label
	desktop.measurement_phase = label
	var end_usec: int = Time.get_ticks_usec() + int(PHASE_SECONDS * 1000000.0)
	while Time.get_ticks_usec() < end_usec:
		await process_frame
	desktop.measurement_phase = ""
	phase = "between"


func attach_bridge_probe() -> bool:
	var bridge: CyberRapierPhysicsBridge = desktop.rapier_bridge
	if bridge == null or not bridge.is_initialized(): return false
	var properties: Dictionary = {}
	for property: Dictionary in bridge.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			properties[property.name] = bridge.get(property.name)
	bridge.set_script(ObservedBridge)
	for key: String in properties:
		bridge.set(key, properties[key])
	for key: String in properties:
		if bridge.get(key) != properties[key]: return false
	bridge.probe_enabled = profiling_enabled
	return desktop.physical_actor_session.bridge == bridge and bridge.is_initialized()


func calibrate_counters() -> void:
	# Bounded counter calibration precedes actor construction and warmup.
	if not profiling_enabled: return
	for index: int in range(10):
		for mode: String in ["busy", "sleep"]:
			var before: PackedInt64Array = ClassDB.class_call_static(&"CyberRapierThreadProbe", &"sample")
			var start: int = Time.get_ticks_usec()
			if mode == "sleep":
				OS.delay_msec(100)
			else:
				while Time.get_ticks_usec() - start < 100000: pass
			var end: int = Time.get_ticks_usec()
			var after: PackedInt64Array = ClassDB.class_call_static(&"CyberRapierThreadProbe", &"sample")
			counter_calibration.append({"index":index,"mode":mode,"start_usec":start,"end_usec":end,"cpu_before":before,"cpu_after":after})


func run() -> void:
	main_started_usec = Time.get_ticks_usec()
	if DisplayServer.get_name() == "headless" or OS.get_name() != "Windows":
		expect(false, "actual Windows graphical host required")
		quit(1)
		return
	if profiling_enabled and not ClassDB.class_exists(&"CyberRapierThreadProbe"):
		expect(false, "diagnostic Windows thread counter extension loaded")
		quit(1)
		return
	calibrate_counters()
	original_max_fps = Engine.max_fps
	original_vsync = int(DisplayServer.window_get_vsync_mode())
	ProjectSettings.set_setting("cybersand/native_worker_threads", 0)
	viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	RenderingServer.frame_pre_draw.connect(pre_drawn)
	RenderingServer.frame_post_draw.connect(drawn)
	release_controls()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(ObservedMain)
	desktop.sink = Callable(self, "retain_process")
	desktop.physics_sink = Callable(self, "retain_physics")
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var ready: bool = worker != null and desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "exclusive native worker began")
	if ready: worker.set_worker_participation_sampling(true)
	if ready:
		var panel = desktop.playable_session_panel
		panel.show_selection()
		panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(RIG))
		panel.control_choice.select(1)
		panel.rule_choice.select(0)
		panel.camera_choice.select(0)
		panel.policy_editor.select_preset(0)
		ready = panel.build_selected()
		expect(ready, "normal selector admitted course")
	if ready:
		ready = await wait_for(Callable(self, "actor_ready").bind(desktop, RIG),
			Watchdogs.milliseconds("main_ack_seconds"))
		expect(ready, "native actor/Rapier/Main acknowledged")
	main_ack_usec = Time.get_ticks_usec()
	if ready:
		bridge_state_preserved = attach_bridge_probe()
		expect(bridge_state_preserved, "every live bridge script variable retained before warmup")
		ready = bridge_state_preserved
	if ready:
		desktop.playable_session_panel.resume_play()
		# No brush/paint commands. The only runtime contrast is process cap.
		Engine.max_fps = 60
		phase = "warmup"
		for _i: int in range(60):
			await process_frame
		for cfg: Dictionary in [
			{"label": "baseline_a", "fps": 60},
			{"label": "timed_a", "fps": 60},
			{"label": "timed_b", "fps": 60},
			{"label": "baseline_b", "fps": 60}
		]:
			Engine.max_fps = int(cfg["fps"])
			var label: String = str(cfg["label"])
			fps_readbacks[label] = Engine.max_fps
			expect(int(fps_readbacks[label]) == int(cfg["fps"]),
				"process cap readback matched: " + label)
			await hold(label)
	phase = "shutdown"
	if desktop != null:
		desktop.measurement_phase = ""
	Engine.max_fps = original_max_fps
	expect(Engine.max_fps == original_max_fps, "initial FPS cap restored before scene exit")
	var result: Dictionary = {
		"schema": "inv154-thread-cpu-v1",
		"profiling_enabled": profiling_enabled,
		"counter_calibration": counter_calibration,
		"bridge_state_preserved": bridge_state_preserved,
		"native_worker_request": 0,
		"native_worker_request_semantics": "automatic pool size; actual participants retained in process snapshot rows",
		"thread_counter_scope": "GetThreadTimes calling-thread CPU, not all Rapier workers; cannot distinguish blocked from ready/descheduled",
		"platform": OS.get_name(), "display_server": DisplayServer.get_name(),
		"godot": Engine.get_version_info().get("string", "unknown"),
		"driver": RenderingServer.get_rendering_device().get_device_name()
			if RenderingServer.get_rendering_device() != null else "unavailable",
		"main_ack_seconds": float(main_ack_usec - main_started_usec) / 1000000.0,
		"wrapper_observations": {"baseline_a": wrapper_distribution("baseline_a"),
			"timed_a": wrapper_distribution("timed_a"),
			"timed_b": wrapper_distribution("timed_b"),
			"baseline_b": wrapper_distribution("baseline_b")},
		"baseline_a": summarize("baseline_a"), "timed_a": summarize("timed_a"),
		"timed_b": summarize("timed_b"), "baseline_b": summarize("baseline_b"),
		"process_rows": process_rows.size(), "draw_rows": draw_rows.size(),
		"pre_draw_rows": pre_draw_rows.size(), "physics_rows": physics_rows.size(),
		"requested_fps_readbacks": fps_readbacks,
		"fps_setting_original": original_max_fps,
		"fps_setting_restored": Engine.max_fps,
		"vsync_mode_unchanged": original_vsync,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"engine_time_scale": Engine.time_scale,
		"attempted_brush_commands": 0, "accepted_brush_commands": 0,
		"overflow": overflow, "assertions": assertions, "failures": failures,
		"source": "production Main/native World/Rapier unmodified; instrumented source-equivalent test-only dispatcher",
		"scope": "constant FPS=60 original Main super vs source-matched timed copy; original bridge step/flush wall readbacks are not CPU-busy/GPU computation time"
	}
	expect(not overflow, "bounded process/draw/pre-draw/physics buffers did not overflow")
	if ready:
		for label: String in ["baseline_a", "timed_a", "timed_b", "baseline_b"]:
			var arm: Dictionary = result[label]
			expect(arm.process.get("n", 0) >= 20 and arm.render_interval_ms.get("n", 0) >= 20,
				"actual graphical process and draw windows populated: " + label)
			expect(arm.native_ticks_per_second > 0.0 and arm.rapier_steps_per_second > 0.0,
				"native/Rapier advanced under cap arm: " + label)
	var session = desktop.physical_actor_session if desktop != null else null
	var retiring: Control = desktop
	desktop = null
	if retiring != null:
		await close_cycle(retiring, worker, session, "inv154 cap ABBA: ")
	if ready:
		for timed_label: String in ["timed_a", "timed_b"]:
			var observed_ops: int = 0
			for row: Dictionary in physics_rows:
				if row.phase == timed_label and row.wrapper_usec.has("rapier_step") and row.wrapper_usec.has("session_advance") and row.wrapper_usec.has("session_complete"):
					observed_ops += 1
			expect(observed_ops >= 100, "actual source-copied Rapier/advance/complete stage samples: " + timed_label)
	result.failures = failures
	result.assertions = assertions
	result["joined_worker"] = worker != null and not worker._thread.is_started()
	print("INV154_THREAD_CPU ", JSON.stringify(result))
	var out: String = OS.get_environment("CYBERSAND_PHASE_OUTPUT")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		var file: FileAccess = FileAccess.open(out.path_join("physics-thread-cpu.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"result": result, "process_rows": process_rows,
				"draw_rows": draw_rows, "pre_draw_rows": pre_draw_rows,
				"physics_rows": physics_rows}, "\t"))
			file.close()
	quit(0 if ready and failures == 0 else 1)
