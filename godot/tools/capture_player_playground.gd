extends SceneTree

# Optional real-renderer review apparatus. No images or machine-local outputs
# are committed. Invoke with -- --player-capture-output=/absolute/directory.
var _output: String = "user://player-playground-captures"


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--player-capture-output="):
			_output = argument.trim_prefix("--player-capture-output=")
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Player capture requires a real graphical DisplayServer.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = Vector2i(1600, 1000)
	var scene: Control = load("res://player_playground.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var records: Array = []
	for index: int in range(scene.Course.PRESETS.size()):
		if not scene.select_preset(index):
			push_error("Player capture preset configuration failed.")
			quit(1)
			return
		# Tick through the same public action owner the live input sampler uses.
		scene.advance_frame({}, true)
		for step: int in range(45):
			await physics_frame
			var action: Dictionary = {"move": Vector2(1, 0), "aim": Vector2(0.8, -0.6)}
			if index in [0, 1]:
				action.move = Vector2(0, -1)
			elif index in [3, 6]:
				action.move = Vector2(0.12, -1)
				action.primary = true
			elif index == 2 and step > 24:
				action.secondary = true
			scene.advance_frame(action, true)
		scene._toggle_pause()
		for frame: int in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var pixels: Image = root.get_texture().get_image()
		if pixels == null or pixels.is_empty():
			push_error("Player capture returned no rendered image.")
			quit(1)
			return
		var filename: String = "%02d-%s.png" % [index + 1, scene.Course.PRESETS[index]]
		if pixels.save_png(_output.path_join(filename)) != OK:
			push_error("Could not save player capture.")
			quit(1)
			return
		records.append({"preset": str(scene.Course.PRESETS[index]), "file": filename,
			"snapshot": scene.runtime.snapshot(), "surface": scene._surface.diagnostics()})
	var manifest: Dictionary = {"engine": Engine.get_version_info(),
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_device": RenderingServer.get_video_adapter_name(), "captures": records,
		"scope": "Real-rendered Linux presentation review; scripted actions, not human feel or target hardware acceptance."}
	var file := FileAccess.open(_output.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	print("PLAYER_PLAYGROUND_CAPTURE: wrote 7 real-rendered presets to ", ProjectSettings.globalize_path(_output))
	scene.queue_free()
	await process_frame
	quit(0)
