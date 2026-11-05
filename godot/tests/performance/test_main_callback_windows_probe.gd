extends "res://tests/play_life001_shared_host_case.gd"

# INV-004 isolated observational Main callback attribution. This is an actual
# main.tscn, native CyberSimulationWorker and main-thread Rapier lifetime. It
# does not alter production physics, presentation, clocks or worker cadence.
# HOST RESTRICTION: graphical Windows ANGLE, not --headless.
const RIG: StringName = &"acrobat"
const MAX_PROCESS_ROWS: int = 2400
const MAX_DRAW_ROWS: int = 2400
const PERIOD_USEC: int = 100000
const PHASE_SECONDS: float = 4.0
var phase: String = "setup"
var desktop: Control
var process_rows: Array[Dictionary] = []
var draw_rows: Array[Dictionary] = []
var last_draw_usec: int = 0
var last_draw_phase: String = ""
var viewport_rid: RID
var overflow: bool = false
var accepted_brush_commands: int = 0
var attempted_brush_commands: int = 0
var main_started_usec: int = 0
var main_ack_usec: int = 0


class ObservedMain:
	extends "res://scripts/main.gd"
	var measurement_phase: String = ""
	var cost_usec: Dictionary = {}
	var sink: Callable = Callable()

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
			"upload_ms_last": upload_time_ms
		}
		if sink.is_valid():
			sink.call(row)


func retain_process(row: Dictionary) -> void:
	if process_rows.size() >= MAX_PROCESS_ROWS:
		overflow = true
		return
	process_rows.append(row)


func drawn() -> void:
	var now: int = Time.get_ticks_usec()
	if desktop != null and is_instance_valid(desktop) and phase in ["baseline", "brush"]:
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


func hold(label: String) -> void:
	phase = label
	desktop.measurement_phase = label
	var end_usec: int = Time.get_ticks_usec() + int(PHASE_SECONDS * 1000000.0)
	while Time.get_ticks_usec() < end_usec:
		await process_frame
	desktop.measurement_phase = ""
	phase = "between"


func brush() -> void:
	phase = "brush"
	desktop.measurement_phase = "brush"
	desktop.set_brush_shape("square")
	desktop.set_brush_size(8)
	var start: int = Time.get_ticks_usec()
	var pulse: int = 0
	var end_usec: int = start + int(PHASE_SECONDS * 1000000.0)
	while Time.get_ticks_usec() < end_usec:
		if Time.get_ticks_usec() >= start + pulse * PERIOD_USEC:
			for pair: Vector3i in [Vector3i(396,176,2), Vector3i(576,176,3)]:
				attempted_brush_commands += 1
				if desktop.queue_brush_footprint_mutation(pair.x,pair.y,pair.z,0):
					accepted_brush_commands += 1
			pulse += 1
		await process_frame
	desktop.measurement_phase = ""
	phase = "between"


func run() -> void:
	main_started_usec = Time.get_ticks_usec()
	if DisplayServer.get_name() == "headless" or OS.get_name() != "Windows":
		expect(false, "actual Windows graphical host required")
		quit(1)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads", 0)
	viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	RenderingServer.frame_post_draw.connect(drawn)
	release_controls()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(ObservedMain)
	desktop.sink = Callable(self, "retain_process")
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var ready: bool = worker != null and desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "exclusive native worker began")
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
		desktop.playable_session_panel.resume_play()
		# Untimed warm-up. Never pause/slow native simulation to fill samples.
		phase = "warmup"
		for _i: int in range(60):
			await process_frame
		await hold("baseline")
		await brush()
	phase = "shutdown"
	var result: Dictionary = {
		"schema": "inv154-main-phase-observer-v1",
		"platform": OS.get_name(), "display_server": DisplayServer.get_name(),
		"godot": Engine.get_version_info().get("string", "unknown"),
		"driver": RenderingServer.get_rendering_device().get_device_name()
			if RenderingServer.get_rendering_device() != null else "unavailable",
		"main_ack_seconds": float(main_ack_usec - main_started_usec) / 1000000.0,
		"baseline": summarize("baseline"), "brush": summarize("brush"),
		"process_rows": process_rows.size(), "draw_rows": draw_rows.size(),
		"attempted_brush_commands": attempted_brush_commands,
		"accepted_brush_commands": accepted_brush_commands,
		"overflow": overflow, "assertions": assertions, "failures": failures,
		"source": "current-main retained native World/Rapier/graphical Main; observational only",
		"scope": "inclusive method subcall times are NOT an additive frame cost; GPU timer may be unsupported"
	}
	expect(not overflow, "bounded process/draw buffers did not overflow")
	if ready:
		expect(result.baseline.process.n >= 40 and result.brush.process.n >= 40,
			"both registered real Main sample windows populated")
		expect(accepted_brush_commands > 0, "normal worker brush admission occurred")
	var session = desktop.physical_actor_session if desktop != null else null
	var retiring: Control = desktop
	desktop = null
	if retiring != null:
		await close_cycle(retiring, worker, session, "inv154 main probe: ")
	result.failures = failures
	result.assertions = assertions
	result["joined_worker"] = worker != null and not worker._thread.is_started()
	print("INV154_MAIN_PHASE ", JSON.stringify(result))
	var out: String = OS.get_environment("CYBERSAND_PHASE_OUTPUT")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		var file: FileAccess = FileAccess.open(out.path_join("main-phase.json"),FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"result":result, "process_rows":process_rows,
				"draw_rows":draw_rows}, "\t"))
			file.close()
	quit(0 if ready and failures == 0 else 1)
