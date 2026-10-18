extends SceneTree

# Live-controller wiring capture (apparatus, not a regression). Loads the real
# desktop main.tscn or Web web_main.tscn controller, installs the Materials
# Laboratory, runs it unpaused for a wall-clock window, pauses, hides the HUD
# (F8) and saves the actual root-window framebuffer with glow on and off via
# the controller's own G handling. Not tick-exact; use the RG8 fixture for pairs.
#   <godot> --path godot --script res://tests/capture_controller_scene.gd -- \
#     --output=<dir> [--controller=desktop|web] [--seconds=1.5]
#     [--scenario=materials/contact-lab]

const Pack = preload("res://scripts/microscenario_reference_pack.gd")


func _init() -> void:
	call_deferred("_run")


func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _run() -> void:
	var output: String = ""
	var controller: String = "desktop"
	var seconds: float = 1.5
	var scenario: String = "materials/contact-lab"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument.begins_with("--controller="): controller = argument.trim_prefix("--controller=")
		elif argument.begins_with("--seconds="): seconds = float(argument.trim_prefix("--seconds="))
		elif argument.begins_with("--scenario="): scenario = argument.trim_prefix("--scenario=")
	if DisplayServer.get_name() == "headless" or output.is_empty():
		print("CONTROLLER_SCENE_CAPTURE: skipped (needs a display and --output)")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(output)
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	var scene: Control = load("res://main.tscn" if controller == "desktop" else "res://web_main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	if controller == "web":
		scene.focused = true
		scene.ui.close_menu()
	var installed: bool = scene.microscenario_apply_definition(Pack.definition(scenario, 0), "Inspect")
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline and not scene.tower_context.get("micro_active", false):
		await process_frame
	scene.paused = false
	await create_timer(seconds).timeout
	scene.paused = true
	if scene.microscenario_panel.visible:
		scene._unhandled_key_input(key(KEY_F8))
	# Freeze presentation time on the controller's own materials so glow
	# on/off frames differ only by glow.
	scene.world_shader.set_shader_parameter("presentation_time_override", 5.0)
	scene.glow_source_shader.set_shader_parameter("presentation_time_override", 5.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var record: Dictionary = {"controller": controller, "scenario": scenario, "installed": installed,
		"tick": scene.tower_context.get("tick", -1), "window": [root.size.x, root.size.y],
		"adapter": RenderingServer.get_video_adapter_name(), "images": {}}
	for state: String in ["glow-on", "glow-off", "glow-on-again"]:
		if state != "glow-on":
			scene._unhandled_key_input(key(KEY_G))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		var path: String = output.path_join("%s-%s-%s.png" % [controller, scenario.get_file(), state])
		image.save_png(path)
		record.images[state] = {"path": path.get_file(), "glow_enabled": scene.glow_enabled,
			"overlay_visible": scene.glow_overlay.visible,
			"source_update_mode": scene.glow_viewport.render_target_update_mode}
	var file: FileAccess = FileAccess.open(output.path_join("%s-%s.json" % [controller, scenario.get_file()]), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "  ") + "\n")
	file.close()
	print("CONTROLLER_SCENE_CAPTURE: ", JSON.stringify(record))
	if controller == "desktop":
		scene.simulation_worker.stop_worker()
		scene.rapier_bridge.shutdown()
	scene.queue_free()
	await process_frame
	quit(0)
