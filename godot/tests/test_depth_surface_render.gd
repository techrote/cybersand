extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Depth surface pixel check skipped: requires a rendering display")
		quit()
		return
	var lab: Control = load("res://depth_lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	# Reproduce the failed reconstruction: pause before any viewport draws.
	if not lab.paused: lab.toggle_pause()
	for frame: int in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	var previous := PackedByteArray()
	for plane: CyberDepthLayerSurface in lab.compositor._surfaces:
		var image: Image = plane.get_texture().get_image()
		expect(image.get_size() == Vector2i(640,360), "Material surface must retain its ROI")
		expect(image.get_used_rect().has_area(), "Pause-before-first-draw must still bake " + plane.layer_id)
		var pixels: PackedByteArray = image.get_data()
		expect(previous.is_empty() or pixels != previous, "Adjacent material planes must not share rendered content")
		previous = pixels
		if plane.static_bake:
			expect(not plane.render_enabled and plane.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "Frozen far plane must use a one-shot bake")
	lab.queue_free()
	await process_frame
	print("Depth surface pixel checks: %d failures" % failures)
	quit(1 if failures else 0)
