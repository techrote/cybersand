extends SceneTree

const Capture = preload("res://scripts/object_shard_capture.gd")
var destination: String = ""
var failures: int = 0
var observations: Array[Dictionary] = []
var scene


func _init() -> void:
	Engine.max_fps = 240
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--objectshard-capture="):
			destination = argument.trim_prefix("--objectshard-capture=")
	call_deferred("_run")


func _idle() -> bool:
	var deadline: int = Time.get_ticks_msec() + 30000
	await process_frame
	while Time.get_ticks_msec() < deadline:
		if scene.host.failed or scene.setup_failed:
			return false
		if not scene.loading and not scene.replacing_owner and scene.host.state == "Idle" and scene.host.actions.is_empty() and scene.queued_cuts.is_empty():
			return true
		await process_frame
	return false


func _ticks(count: int) -> bool:
	for tick: int in range(count):
		var previous: int = scene.host.completed_ticks
		if not scene.host.request_tick().get("ok", false):
			return false
		var deadline: int = Time.get_ticks_msec() + 15000
		while scene.host.completed_ticks <= previous and not scene.host.failed and Time.get_ticks_msec() < deadline:
			await process_frame
		if scene.host.completed_ticks <= previous or not await _idle():
			return false
	return true


func _scenario(number: int) -> bool:
	scene.running = false
	scene.selector.select(number - 1)
	scene._change_scenario(number - 1)
	return await _idle()


func _capture(name: String, premise: bool, detail: Dictionary = {}) -> void:
	if not premise:
		failures += 1
		push_error("Rendered case premise failed: " + name)
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var filename: String = name + ".png"
	if picture.is_empty() or picture.save_png(destination.path_join(filename)) != OK or scene.host.failed:
		failures += 1
		push_error("Actual worker-host render failed: " + name)
	observations.append({"image": filename, "premise_passed": premise, "detail": detail,
		"preset": scene.selected_preset, "report": scene.host.diagnostics()})


func _run() -> void:
	if destination.is_empty() or DisplayServer.get_name() == "headless":
		push_error("M3 rendered evidence requires an actual display renderer and output directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	scene = load("res://object_shard_worker_rehearsal.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	if not await _idle():
		failures += 1
	else:
		await _capture("objectshard-m3-native-supported", scene.host.bridge.bodies.is_empty())
		scene._cut_support()
		var ready: bool = await _idle() and await _ticks(20)
		scene.view.overlays = true
		await _capture("objectshard-m3-falling", ready and scene.host.bridge.bodies.size() == 1)
		var sleeping: bool = false
		for attempt: int in range(40):
			if not await _ticks(30):
				break
			sleeping = true
			for body: Dictionary in scene.host.bridge.diagnostics().bodies:
				sleeping = sleeping and bool(body.get("sleeping", false))
			if sleeping:
				break
		scene._erode_resting_cell()
		var after_erosion: bool = await _idle() and await _ticks(120)
		await _capture("objectshard-m3-settled-after-erosion", sleeping and after_erosion,
			{"natural_sleep_observed_before_edit": sleeping, "continued_semantic_ticks_after_edit": 120})
		ready = await _scenario(7)
		if ready:
			scene._cut_support()
			ready = await _idle() and await _ticks(6)
		var largest: int = 0
		for shard: Dictionary in scene.host.publication.get("shards", []):
			largest = maxi(largest, int(shard.structural))
		await _capture("objectshard-m3-main-structure-priority", ready and largest >= 700,
			{"largest_admitted_structural_cells": largest})
		ready = await _scenario(3)
		if ready:
			scene._cut_support()
			ready = await _idle() and await _ticks(100)
		await _capture("objectshard-m3-water-sand-pocket", ready and scene.host.bridge.bodies.size() > 0)
		ready = await _scenario(10)
		if ready:
			scene._toggle_run()
			var deadline: int = Time.get_ticks_msec() + 30000
			while scene.host.completed_ticks < 20 and not scene.host.failed and Time.get_ticks_msec() < deadline:
				await process_frame
			scene._toggle_run()
			ready = await _idle()
		var fires: int = scene.host.publication.get("world_materials", PackedByteArray()).count(6)
		await _capture("objectshard-m3-external-fire", ready and fires > 1,
			{"native_world_fire_cells": fires, "accepted_fixture_actions": scene.authored_fixture_fire})
		ready = await _scenario(11)
		if ready:
			scene._cut_support()
			ready = await _idle() and await _ticks(80)
		await _capture("objectshard-m3-extended-320", ready and int(scene.host.publication.width) == 320 and scene.host.bridge.bodies.size() >= 2)
	var report: Dictionary = {"schema": "objectshard-worker-render-campaign-v1",
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "captures": observations.size(),
		"failures": failures, "observations": observations,
		"scope": "Actual exclusive-worker/native/Rapier presentation; separate-World integration rehearsal, not production World attachment or physical owner acceptance"}
	scene.running = false
	scene.host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while scene.host.state != "Closed" and Time.get_ticks_msec() < deadline:
		await process_frame
	if scene.host.state != "Closed":
		failures += 1
	scene.queue_free()
	await process_frame
	report.failures = failures
	var output: FileAccess = FileAccess.open(destination.path_join("render-campaign.json"), FileAccess.WRITE)
	if output == null:
		failures += 1
	else:
		output.store_string(JSON.stringify(Capture.json_value(report), "  ") + "\n")
		output.close()
	print(JSON.stringify({"schema": report.schema, "captures": observations.size(), "failures": failures}))
	quit(0 if failures == 0 else 1)
