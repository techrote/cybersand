extends "res://tests/play_life001_shared_host_case.gd"

# NONQUALIFYING steady-state render-pacing apparatus (PLAY-PACE-003 successor).
# One actual Main lifetime: main.tscn, the exclusive CyberSimulationWorker and
# main-thread Rapier. Records separate clocks per presented frame: frame-post-draw
# interval, Main _process CPU, snapshot consumption/upload CPU, shader-parameter
# CPU, viewport CPU/GPU render time, native ticks and Rapier ticks. Timing is
# observed only; nothing here is an acceptance threshold.
#   <godot> --rendering-method gl_compatibility --path godot \
#     --script res://tests/play_render_pacing_probe.gd
# Environment: CYBERSAND_PACING_OUTPUT=<dir> (optional raw/summary JSON),
#   CYBERSAND_PACING_VSYNC=0 disables V-Sync (default keeps the project setting),
#   CYBERSAND_PACING_SECONDS=<phase seconds, default 6>.
const Policy = preload("res://tests/support/ci_execution_policy.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const RIG: StringName = &"acrobat"
const BRUSH_CENTRES: Array[Vector2i] = [Vector2i(396, 176), Vector2i(576, 176)]
const BRUSH_MATERIALS: Array[int] = [2, 3]
const BRUSH_PERIOD_USEC: int = 100000

var phase: String = "startup"
var frames: Array[Dictionary] = []
var last_frame_usec: int = 0
var desktop: Control
var viewport_rid: RID
var latency: Array[Dictionary] = []
var probe_started: int = 0


class TimedMain:
	extends "res://scripts/main.gd"
	var cost: Dictionary = {"process": 0, "physics": 0, "physics_max": 0, "consume": 0, "shader_parameters": 0, "uploads": 0, "upload_ms": 0.0}

	func _actor_window_has_focus() -> bool:
		return true

	func _process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		super(delta)
		cost.process += Time.get_ticks_usec() - started

	func _physics_process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		super(delta)
		var spent: int = Time.get_ticks_usec() - started
		cost.physics += spent
		cost.physics_max = maxi(int(cost.physics_max), spent)

	func consume_worker_snapshot() -> void:
		var started: int = Time.get_ticks_usec()
		var before: int = last_uploaded_render_snapshot_serial
		super()
		cost.consume += Time.get_ticks_usec() - started
		if last_uploaded_render_snapshot_serial != before:
			cost.uploads += 1
			cost.upload_ms += upload_time_ms

	func update_shader_parameters() -> void:
		var started: int = Time.get_ticks_usec()
		super()
		cost.shader_parameters += Time.get_ticks_usec() - started


func _frame_drawn() -> void:
	var now: int = Time.get_ticks_usec()
	if desktop == null or not is_instance_valid(desktop):
		last_frame_usec = now
		return
	var row: Dictionary = {"phase": phase, "usec": now, "interval_usec": now - last_frame_usec if last_frame_usec > 0 else 0,
		"process_usec": desktop.cost.process, "physics_usec": desktop.cost.physics,
		"physics_max_usec": desktop.cost.physics_max, "consume_usec": desktop.cost.consume,
		"shader_parameters_usec": desktop.cost.shader_parameters, "uploads": desktop.cost.uploads,
		"upload_ms": desktop.cost.upload_ms,
		"viewport_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid),
		"viewport_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid),
		"native_tick": int(desktop.latest_snapshot.tick_index) if desktop.latest_snapshot != null else -1,
		"rapier_tick": int(desktop.physical_actor_session.tick) if desktop.physical_actor_session != null else -1,
		"camera": [desktop.camera_origin.x, desktop.camera_origin.y]}
	desktop.cost = {"process": 0, "physics": 0, "physics_max": 0, "consume": 0, "shader_parameters": 0, "uploads": 0, "upload_ms": 0.0}
	last_frame_usec = now
	frames.append(row)


func percentile(values: Array, fraction: float) -> float:
	if values.is_empty():
		return -1.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size() - 1, int(floor(fraction * float(sorted.size() - 1) + 0.5)))])


func stats(values: Array) -> Dictionary:
	var total: float = 0.0
	for value: float in values:
		total += value
	return {"n": values.size(), "mean": total / maxf(1.0, float(values.size())), "p50": percentile(values, 0.5),
		"p95": percentile(values, 0.95), "p99": percentile(values, 0.99), "max": percentile(values, 1.0)}


func summarize(name: String) -> Dictionary:
	var rows: Array = frames.filter(func(row: Dictionary) -> bool: return row.phase == name)
	if rows.size() < 3:
		return {"frames": rows.size()}
	rows = rows.slice(1)
	var seconds: float = float(rows.back().usec - rows.front().usec) / 1000000.0
	var pick: Callable = func(key: String, scale: float) -> Array:
		return rows.map(func(row: Dictionary) -> float: return float(row[key]) * scale)
	var uploads: int = 0
	var upload_ms: float = 0.0
	for row: Dictionary in rows:
		uploads += int(row.uploads)
		upload_ms += float(row.upload_ms)
	return {"frames": rows.size(), "seconds": seconds,
		"fps": float(rows.size() - 1) / maxf(seconds, 0.000001),
		"interval_ms": stats(pick.call("interval_usec", 0.001)),
		"process_ms": stats(pick.call("process_usec", 0.001)),
		"physics_ms": stats(pick.call("physics_usec", 0.001)),
		"consume_ms": stats(pick.call("consume_usec", 0.001)),
		"shader_parameters_ms": stats(pick.call("shader_parameters_usec", 0.001)),
		"viewport_cpu_ms": stats(pick.call("viewport_cpu_ms", 1.0)),
		"viewport_gpu_ms": stats(pick.call("viewport_gpu_ms", 1.0)),
		"uploads": uploads, "uploads_per_second": float(uploads) / maxf(seconds, 0.000001),
		"upload_ms_mean": upload_ms / maxf(1.0, float(uploads)),
		"native_ticks_per_second": float(int(rows.back().native_tick) - int(rows.front().native_tick)) / maxf(seconds, 0.000001),
		"rapier_steps_per_second": float(int(rows.back().rapier_tick) - int(rows.front().rapier_tick)) / maxf(seconds, 0.000001)}


func hold(seconds: float, label: String) -> void:
	phase = label
	var until: int = Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < until:
		await process_frame


func moving(seconds: float, label: String, key: Key) -> void:
	# Input-to-presented-frame latency: key edge to the first presented frame
	# whose submitted camera differs (the camera follows the actor).
	phase = label
	var before: Vector2 = desktop.camera_origin
	var pressed: int = Time.get_ticks_usec()
	var first_frame: int = frames.size()
	parse_key(key, true)
	var until: int = pressed + int(seconds * 1000000.0)
	var seen: bool = false
	while Time.get_ticks_usec() < until:
		await process_frame
		if not seen:
			for index: int in range(first_frame, frames.size()):
				var camera: Array = frames[index].camera
				if Vector2(camera[0], camera[1]) != before:
					latency.append({"phase": label, "key": key, "pressed_usec": pressed,
						"presented_usec": frames[index].usec, "latency_ms": float(frames[index].usec - pressed) / 1000.0,
						"frames": index - first_frame + 1})
					seen = true
					break
	parse_key(key, false)
	if not seen:
		latency.append({"phase": label, "key": key, "pressed_usec": pressed, "presented_usec": -1})


func brush(seconds: float, label: String) -> void:
	phase = label
	desktop.set_brush_shape("square")
	desktop.set_brush_size(8)
	var started: int = Time.get_ticks_usec()
	var pulses: int = 0
	var accepted: int = 0
	while Time.get_ticks_usec() < started + int(seconds * 1000000.0):
		if Time.get_ticks_usec() >= started + pulses * BRUSH_PERIOD_USEC:
			for slot: int in range(BRUSH_CENTRES.size()):
				var centre: Vector2i = BRUSH_CENTRES[slot]
				if desktop.queue_brush_footprint_mutation(centre.x, centre.y, BRUSH_MATERIALS[slot], 0):
					accepted += 1
			pulses += 1
		await process_frame
	expect(accepted > 0, "brush load reached the production worker queue")


func run() -> void:
	probe_started = Time.get_ticks_usec()
	Context.emit(get_script().resource_path)
	if DisplayServer.get_name() == "headless":
		expect(false, "actual graphical backend required")
		quit(1)
		return
	if OS.get_environment("CYBERSAND_PACING_VSYNC") == "0":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var phase_seconds: float = float(OS.get_environment("CYBERSAND_PACING_SECONDS")) if not OS.get_environment("CYBERSAND_PACING_SECONDS").is_empty() else 6.0
	viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	ProjectSettings.set_setting("cybersand/native_worker_threads", 0)
	RenderingServer.frame_post_draw.connect(_frame_drawn)
	release_controls()
	var started: int = Time.get_ticks_usec()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(TimedMain)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var ready: bool = worker != null and desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "actual exclusive Main worker started")
	var panel = desktop.playable_session_panel
	if ready:
		panel.show_selection()
		panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(RIG))
		panel.control_choice.select(1)
		panel.rule_choice.select(0)
		panel.camera_choice.select(0)
		panel.policy_editor.select_preset(0)
		ready = panel.build_selected()
		expect(ready, "actual integrated Play selector admitted")
	if ready:
		ready = await wait_for(Callable(self, "actor_ready").bind(desktop, RIG), Policy.milliseconds("main_ack_seconds"))
		expect(ready, "Main construction acknowledgement")
	var acknowledged: int = Time.get_ticks_usec()
	var phases: Array[String] = ["warmup", "idle", "move_right", "move_left", "brush", "settle"]
	if ready:
		panel.resume_play()
		await hold(2.0, "warmup")
		await hold(phase_seconds, "idle")
		await moving(phase_seconds, "move_right", KEY_D)
		await moving(phase_seconds, "move_left", KEY_A)
		await brush(phase_seconds * 1.5, "brush")
		await hold(phase_seconds, "settle")
	phase = "shutdown"
	var session = desktop.physical_actor_session
	var shutdown_started: int = Time.get_ticks_usec()
	var summary: Dictionary = {}
	for name: String in phases:
		summary[name] = summarize(name)
	var final_desktop: Control = desktop
	desktop = null
	await close_cycle(final_desktop, worker, session, "pacing: ")
	var record: Dictionary = {"schema": "play-render-pacing-v1", "context": Context.identity(get_script().resource_path),
		"assertions": assertions, "failures": failures, "rig": str(RIG),
		"vsync": DisplayServer.window_get_vsync_mode(), "window": [root.size.x, root.size.y],
		"screen_refresh_rate": DisplayServer.screen_get_refresh_rate(),
		"main_ack_seconds": float(acknowledged - started) / 1000000.0,
		"shutdown_ms": float(Time.get_ticks_usec() - shutdown_started) / 1000.0,
		"worker_joined": not worker._thread.is_started(), "phases": summary, "latency": latency,
		"scope": "NONQUALIFYING local steady-state pacing observation; synthetic focus; no physical-display or acceptance claim"}
	print("RENDER_PACING_RESULT ", JSON.stringify(record))
	var output: String = OS.get_environment("CYBERSAND_PACING_OUTPUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file: FileAccess = FileAccess.open(output.path_join("pacing.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"record": record, "frames": frames}, "\t"))
			file.close()
	quit(0 if failures == 0 and ready else 1)
