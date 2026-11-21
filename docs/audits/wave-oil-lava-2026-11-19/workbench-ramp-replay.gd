extends SceneTree

# Use an extracted owner ZIP. Set application/config/name to a unique name
# containing CyberSandOilLavaQA in the scratch project's override.cfg.
# Arguments after -- are the packaged ramp path, output directory and optional
# Lava tick (721 by default; 1500 is the extended pre-Lava observation).
var host: Control
var bench: Control
var output := ""
var lava_tick := 721
var report := {"stages": [], "paints": [], "failures": []}

func _initialize() -> void:
	run.call_deferred()

func generation() -> int:
	return int(host.simulation_worker.paint_state().get("generation", -1))

func installed() -> bool:
	return bench != null and not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty()

func tick() -> int:
	return int(host.tower_context.get("wave_flow", {}).get("completed_tick", 0))

func wait_for(predicate: Callable, reason: String) -> bool:
	var deadline := Time.get_ticks_msec() + 120000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed():
			for frame in 3:
				await process_frame
			var snapshot = host.latest_snapshot
			report.native_failure = {
				"prior_published_tick": tick(), "attempted_tick": snapshot.failed_tick_index,
				"failure_count": snapshot.tick_failure_count, "message": snapshot.last_tick_error}
			print("OBSERVED_FAILURE ", report.native_failure)
			return false
		await process_frame
	if not predicate.call():
		report.failures.append("Timeout waiting for " + reason)
		return false
	return true

func advance(target: int) -> bool:
	while tick() < target:
		var before := tick()
		if not bench.step_once():
			report.failures.append("Step %d refused. %s" % [before + 1, bench.message])
			return false
		if not await wait_for(func() -> bool: return installed() and tick() > before, "tick %d" % (before + 1)):
			return false
		if tick() % 100 == 0:
			print("AT_TICK ", tick())
	return true

func checkpoint(tag: String) -> bool:
	var worker = host.simulation_worker
	var request: Dictionary = worker.material_capture_request(generation())
	if not request.get("ok", false):
		report.failures.append("Material capture refused. " + str(request))
		return false
	var token: int = request.token
	if not await wait_for(func() -> bool: return not worker.material_capture_poll(token).is_empty(), "material capture"):
		worker.material_capture_finish(token, false)
		return false
	var capture: Dictionary = worker.material_capture_poll(token)
	worker.material_capture_finish(token, false)
	if not capture.get("ok", false):
		report.failures.append("Material capture failed. " + str(capture))
		return false
	var plane_path := tag + ".le16"
	var file := FileAccess.open(output.path_join(plane_path), FileAccess.WRITE)
	file.store_buffer(capture.cells)
	file.close()
	var flow: Dictionary = host.tower_context.wave_flow
	report.stages.append({"tag": tag, "tick": tick(), "sha256_material_plane": capture.sha256,
		"plane": plane_path, "water_quantity": flow.water_quantity, "spill": flow.spill,
		"spray": host.tower_context.water_spray})
	if DisplayServer.get_name() != "headless":
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
		if image.save_png(output.path_join(tag + ".png")) != OK:
			report.failures.append("Could not save submitted frame at " + tag)
			return false
	print("CHECKPOINT ", tag, " tick ", tick())
	write_report()
	return true

func paint(x: int, y: int, material: int) -> bool:
	report.paints.append({"tick": tick(), "x": x, "y": y, "material": material, "radius": int(bench.applied.brush)})
	print("PAINT ", report.paints.back())
	if not bench.paint(Vector2i(x, y), material):
		report.failures.append("Brush refused. " + str(bench.message))
		return false
	return await wait_for(func() -> bool: return not host.simulation_worker.paint_state().get("legacy_busy", true), "paint receipt")

func start(map_path: String) -> bool:
	var userdir := OS.get_user_data_dir()
	report.userdir = userdir
	if not "cybersandoillavaqa" in userdir.to_lower():
		report.failures.append("A separate CyberSandOilLavaQA user directory is required. Resolved " + userdir)
		return false
	report.godot = Engine.get_version_info().string
	report.display = DisplayServer.get_name()
	report.dll_sha256 = FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll")
	report.map_sha256 = FileAccess.get_sha256(map_path)
	DirAccess.make_dir_recursive_absolute(userdir.path_join("workbench"))
	if DirAccess.copy_absolute(map_path, userdir.path_join("workbench/setup-water-ramp.json")) != OK:
		report.failures.append("Could not install the named setup in isolated user data.")
		return false
	root.gui_embed_subwindows = true
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	host = current_scene
	bench = host.shared_workbench
	if not await wait_for(installed, "ordinary Workbench"):
		return false
	var before := generation()
	host.workbench_water_options["workbench_worker_threads"] = 6
	bench._name.text = "water-ramp"
	if not bench.load_setup():
		report.failures.append("Named load refused. " + str(bench.message))
		return false
	if not await wait_for(func() -> bool: return installed() and generation() > before, "named water-ramp"):
		return false
	host.paused = true
	report.extent = bench.applied.extent
	report.profile = host.tower_context.wave_flow.duplicate(true)
	bench._brush.value = 24
	bench._set_view(Vector2(540, 285), Vector2i(530, 250))
	bench.paint_editor._overlay.hide()
	return true

func replay() -> void:
	if not await advance(360) or not await checkpoint("ramp"):
		return
	if not await paint(805, 448, 16):
		return
	for stage in [[361, "oil-first"], [481, "oil-120"], [721, "oil-360"]]:
		if not await advance(stage[0]) or not await checkpoint(stage[1]):
			return
	if lava_tick > 721:
		if not await advance(lava_tick) or not await checkpoint("pre-lava-%d" % lava_tick):
			return
	if not await paint(826, 452, 8):
		return
	for stage in [[lava_tick + 1, "lava-first"], [lava_tick + 120, "lava-120"]]:
		if not await advance(stage[0]) or not await checkpoint(stage[1]):
			return

func write_report() -> void:
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Supply an absolute packaged ramp path and an output directory after --.")
		quit(1)
		return
	if args.size() > 2:
		if not args[2].is_valid_int() or int(args[2]) < 721:
			push_error("The optional Lava tick must be an integer of 721 or larger.")
			quit(1)
			return
		lava_tick = int(args[2])
	output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	if await start(args[0]):
		await replay()
	write_report()
	print("DONE ", report.failures, " ", report.get("native_failure", {}))
	if is_instance_valid(host):
		host.queue_free()
	await process_frame
	quit(int(not report.failures.is_empty()))
