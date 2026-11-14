extends SceneTree

# ENG-LAB-001: mounted real Main/Workbench/Rapier smoke, no synthetic source writes.
var errors: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	set_meta("cybersand_feature", "shared_workbench")
	_run.call_deferred()


func expect(ok: bool, claim: String) -> void:
	checks += 1
	if not ok:
		errors.append(claim)
		push_error("ENGINE_LAB_MOUNT: " + claim)


func _wait(predicate: Callable, timeout_ms: int = 120000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return false


func _run() -> void:
	var host: Control = load("res://main.tscn").instantiate()
	root.add_child(host)
	var ready: bool = await _wait(func() -> bool:
		return host.shared_workbench != null and not host.shared_workbench.applied.is_empty()
			and host.latest_snapshot != null and not host.simulation_worker.has_failed())
	expect(ready, "real shared Workbench source available")
	if not ready:
		_finish(host)
		return
	var panel: Window = host.shared_workbench.engine_lab
	expect(panel != null and not panel.visible, "Engine Lab exists but is default hidden")
	expect(not host.engine_lab_benchmark_active, "live passive measurement is default off")
	expect(host.engine_lab_coupling_counts().workbench_sample == 0, "no capture-time observer counts yet")
	panel.open_for(host)
	expect(panel.visible, "Art Workbench-style Engine Lab window opens")
	expect(panel.title.find("Engine Lab") != -1, "recognisable Engine Lab title")
	expect(host.paused, "World is initially paused")
	panel.begin_benchmark()
	expect(not panel.recorder.running, "paused source cannot start a misleading 10-second sample")
	expect(host.shared_workbench.toggle_pause(), "actual source unpaused")
	var active: bool = await _wait(func() -> bool:
		return host.latest_snapshot != null and host.latest_snapshot.tick_index >= 2, 30000)
	expect(active, "actual native World progresses under no injected input")
	if active:
		var start_usec: int = Time.get_ticks_usec()
		expect(panel.recorder.begin(panel._identity(),start_usec,500000),
			"test-only bounded 0.5s benchmark")
		host.engine_lab_benchmark_active = true
		expect(await _wait(func() -> bool: return panel.recorder.finished,30000),
			"actual Main clock capture completes without controller input")
		var report: Dictionary = panel.recorder.outcome
		expect(report.get("status","") == "passed" and report.frame_count > 2,
			"real per-frame passive capture qualifies")
		expect(report.native_ticks > 0 and report.actual_native_hz > 0.0,
			"source-backed completed native ticks/s measured")
		expect(report.has("actual_rapier_hz") and report.has("coupling_held_physics_frames"),
			"Rapier and coupling clocks are recorded separately even if absent")
		expect(report.identity.get("world_extent",[]).size() == 2 and
			report.identity.get("native_runtime_sha256","").length() == 64,
			"recording includes source and actual native runtime provenance")
		expect(not panel._last_report_path.is_empty()
			and FileAccess.file_exists(panel._last_report_path),
			"one JSON report persisted after capture, not per frame")
	panel.hide()
	expect(not host.engine_lab_benchmark_active, "closing Engine Lab disarms read-only counters")
	_finish(host)


func _finish(host: Control) -> void:
	if is_instance_valid(host):
		host.queue_free()
	await process_frame
	print("ENGINE_LAB_MOUNT: %d checks, %d failures" % [checks, errors.size()])
	quit(errors.size())
