extends SceneTree

## Real-renderer mode plates and camera-motion frames. Run with a graphical
## DisplayServer; this is deliberately not a headless pixel acceptance claim.
var _output_path: String = "user://depth-lab-captures"
var _motion: bool = false

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--depth-output="):
			_output_path = argument.trim_prefix("--depth-output=")
		elif argument == "--depth-motion":
			_motion = true
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Depth capture requires real frame submission; no capture produced.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_path))
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = Vector2i(1600, 1000)
	var scene: PackedScene = load("res://depth_lab.tscn")
	var lab: Control = scene.instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab._set_auto_pan(false)
	if not lab.paused:
		lab.toggle_pause()
	lab.set_camera_origin(Vector2(80, 45))
	lab.compositor.set_time(0.0)
	for index: int in range(5):
		lab.select_mode(index)
		await _settle()
		var image: Image = root.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Depth capture received no rendered pixels")
			quit(1)
			return
		var filename: String = "%02d-%s.png" % [index + 1, lab.MODES[index]]
		if image.save_png(_output_path.path_join(filename)) != OK:
			push_error("Could not write " + filename)
			quit(1)
			return
	lab.select_mode(3)
	lab.set_camera_origin(Vector2(30, 40))
	await _settle()
	root.get_texture().get_image().save_png(_output_path.path_join("06-camera-left.png"))
	lab.set_camera_origin(Vector2(130, 50))
	await _settle()
	root.get_texture().get_image().save_png(_output_path.path_join("07-camera-right.png"))
	lab.set_camera_origin(Vector2(80, 45))
	lab.runtime.scripted_blast(Vector2i(366, 218), 28)
	lab.runtime.advance(0.0, true)
	lab._publish_layers()
	await _settle()
	root.get_texture().get_image().save_png(_output_path.path_join("08-backdrop-breach.png"))
	var manifest: Dictionary = {
		"engine": Engine.get_version_info(),
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_device": RenderingServer.get_video_adapter_name(),
		"runtime": lab.runtime.stats(),
		"compositor": lab.compositor.get_diagnostics(),
		"scope": "Rendered native-material prototype, not target-GPU gameplay acceptance. Native clocks paused for mode and camera plates."
	}
	if _motion:
		lab.reset_lab()
		lab.select_mode(4)
		lab._set_labels(false)
		for frame: int in range(32):
			var phase: float = float(frame) / 32.0 * TAU
			lab.set_camera_origin(Vector2(80.0 + sin(phase) * 70.0, 45.0 + cos(phase) * 18.0))
			lab.compositor.set_options({"focus_position": lab.camera_origin + Vector2(240, 135)})
			await _settle()
			root.get_texture().get_image().save_png(_output_path.path_join("motion-%03d.png" % frame))
	var file := FileAccess.open(_output_path.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		push_error("Could not write capture manifest")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	print("DEPTH_LAB_CAPTURE: wrote real-rendered mode plates to ", ProjectSettings.globalize_path(_output_path))
	lab.queue_free()
	await process_frame
	quit(0)

func _settle() -> void:
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
