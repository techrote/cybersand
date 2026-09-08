extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 0)
	var cancel: Callable = func() -> bool: return false
	var progress: Callable = func(_text: String) -> void: pass
	var first: Dictionary = await CyberWorkerBenchmark.sample(self, 1, 480, 8, progress, cancel)
	await process_frame
	var second: Dictionary = await CyberWorkerBenchmark.sample(self, 2, 480, 8, progress, cancel)
	await process_frame
	var cancelled: Dictionary = await CyberWorkerBenchmark.sample(self, 1, 480, 8, progress, func() -> bool: return true)
	var stats: Dictionary = CyberWorkerBenchmark.statistics([1.0, 2.0, 3.0, 4.0])
	var suite: Dictionary = await CyberWorkerBenchmark.run(self, false, 0, progress, cancel, 8)
	var ok: bool = first.ok and second.ok and first.level_hash == second.level_hash and first.moves > 0 and first.native_ms.mean > 0 and first.frame_interval_ms.p95 > 0 and cancelled.get("cancelled", false) and stats.mean == 2.5 and stats.p95 == 4.0 and int(ProjectSettings.get_setting("cybersand/native_worker_threads")) == 0
	ok = ok and suite.get("ok", false) and suite.get("rows", []).size() >= 2
	print("Worker benchmark regression: ", ok)
	quit(0 if ok else 1)
