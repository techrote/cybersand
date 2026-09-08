extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for workers: int in [1, 4]:
		ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
		var result: Dictionary = await CyberTickFailureProbe.run(self)
		failures.append_array(result.failures)
		print("TICK_FAILURE_ADAPTER ", JSON.stringify(result))
		var regions: Dictionary = await CyberTickFailureProbe.run_regions(self)
		failures.append_array(regions.failures)
		print("INTEREST_REGION_ADAPTER ", JSON.stringify(regions))
	await _desktop_owner()
	await _desktop_regions()
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	var web: Node = load("res://web_main.tscn").instantiate()
	root.add_child(web)
	web.set_process(false)
	web.set_physics_process(false)
	var web_result: Dictionary = await CyberTickFailureProbe.run(self, web)
	failures.append_array(web_result.failures)
	print("TICK_FAILURE_WEB_OWNER ", JSON.stringify(web_result))
	var regions: Dictionary = await CyberTickFailureProbe.run_regions(self, web)
	failures.append_array(regions.failures)
	print("INTEREST_REGION_WEB_OWNER ", JSON.stringify(regions))
	web.queue_free()
	await process_frame
	for failure: String in failures:
		push_error(failure)
	print("Tick failure regression: ", "passed" if failures.is_empty() else "failed")
	quit(0 if failures.is_empty() else 1)

func _desktop_owner() -> void:
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", 1)
	var worker: CyberSimulationWorker = CyberSimulationWorker.new()
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", null)
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	bridge.build_world(worker._world, PackedInt32Array([20, 20, 2, 1, 1, 160, 20, 1, 1, 2]))
	bridge.queue_explosion(worker._world, 20, 20, 1)
	worker.set_frame_state(1.0, true, true, Vector2i.ZERO, Vector2i.ZERO, Vector2i(320, 180), 0, 0, true, true, true)
	if worker.start_worker(Vector2(40, 40)) != OK:
		failures.append("desktop thread did not start")
		return
	var before: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	worker.set_frame_state(1.0, true, false, Vector2i.ZERO, Vector2i.ZERO, Vector2i(320, 180), 0, 0, true, true, true)
	var deadline: int = Time.get_ticks_msec() + 5000
	while not worker.has_failed() and Time.get_ticks_msec() < deadline:
		await process_frame
	var failed: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	if not failed.simulation_failed:
		failures.append("desktop did not latch/report failure")
	else:
		if failed.character_position != before.character_position or failed.render_patch_cells != before.render_patch_cells or failed.tick_index != 0:
			failures.append("desktop published partially completed tick")
		if not failed.rigid_body_results.is_empty() or not failed.paused:
			failures.append("desktop published body result or running state")
		if worker.queue_emit_disc(20, 20, 0, 2):
			failures.append("desktop accepted command while failed")
		await create_timer(0.08).timeout
		if worker.take_latest_snapshot(-1).failed_tick_index != failed.failed_tick_index:
			failures.append("desktop retried failure")
		worker.set_frame_state(0, false, true, Vector2i.ZERO, Vector2i(384, 0), Vector2i(64, 64), 0, 0, true, true, true)
		worker.queue_reset(Vector2(60, 60))
		deadline = Time.get_ticks_msec() + 5000
		while worker.has_failed() and Time.get_ticks_msec() < deadline:
			await process_frame
		var recovered: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		if recovered.simulation_failed or recovered.tick_index != 0 or recovered.character_position != Vector2(60, 60):
			failures.append("desktop reset did not publish fresh state")
	worker.stop_worker()

func _desktop_regions() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 4)
	var worker: CyberSimulationWorker = CyberSimulationWorker.new()
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	bridge.build_world(worker._world, PackedInt32Array([800, 20, 1, 1, 2]))
	worker.set_frame_state(0, false, false, Vector2i.ZERO, Vector2i.ZERO, Vector2i(64, 64), 0, 0, true, true, true)
	worker.start_worker(Vector2(40, 40))
	var deadline: int = Time.get_ticks_msec() + 5000
	while worker.take_latest_snapshot(-1).tick_index < 8 and Time.get_ticks_msec() < deadline:
		await process_frame
	worker.stop_worker()
	# Only inspect authoritative data after the exclusive owner has drained.
	if worker._world.get_tick_index() < 8 or worker._world.material_at(800, 20) != 2:
		failures.append("desktop excluded content advanced or tick timeout")
	var before: int = worker._world.get_tick_index()
	worker.set_frame_state(0, false, false, Vector2i.ZERO, Vector2i(768, 0), Vector2i(64, 64), 0, 0, true, true, true)
	worker.start_worker(Vector2(40, 40))
	deadline = Time.get_ticks_msec() + 5000
	while worker.take_latest_snapshot(-1).tick_index <= before and Time.get_ticks_msec() < deadline:
		await process_frame
	worker.stop_worker()
	if worker._world.has_failed() or worker._world.get_tick_index() <= before or worker._world.material_at(800, 20) != 0:
		failures.append("desktop re-entry failed to resume")
	print("INTEREST_REGION_DESKTOP_OWNER workers=4 passed=", failures.is_empty())
