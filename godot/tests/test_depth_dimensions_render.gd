extends SceneTree

const DepthCompositor = preload("res://scripts/depth/depth_compositor.gd")
const Cell = preload("res://scripts/cell_world.gd")

var checks: int = 0
var failures: int = 0
var serial: int = 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Depth dimension pixels require a rendering display")
		quit(2)
		return
	root.size = Vector2i(256,256)
	root.content_scale_size = Vector2i(256,256)
	var compositor: CyberDepthCompositor = DepthCompositor.new()
	compositor.size = Vector2(256,256)
	_expect(compositor.configure(Vector2i(1024,1024)), "full-size compositor rejected")
	root.add_child(compositor)
	_expect(compositor.set_view(Vector2(896,896), Vector2(128,128)), "far corner view rejected")
	compositor.set_options({"mode":"stack", "freeze_material_animation":true, "parallax_strength":0.0})
	var materials: Array[int] = [Cell.PINE_PLANKS, Cell.NEON_CYAN, Cell.SPARK, Cell.PHOSPHOR_PANEL]
	for layer: int in range(4):
		_expect(compositor.apply_layer_packet(compositor.IDS[layer], _packet(compositor.IDS[layer], Rect2i(990,990,8,8), materials[layer])),
			"far-corner publication rejected")
	await _settle()
	var previous := PackedByteArray()
	for layer: int in range(4):
		var surface: CyberDepthLayerSurface = compositor._surfaces[layer]
		var image: Image = surface.get_texture().get_image()
		_expect(image.get_size() == Vector2i(1024,1024), "surface retained the old 640x360 ROI")
		_expect(image.get_pixel(993,993).a > 0.05, "far-corner cells were absent from rendered plane " + surface.layer_id)
		_expect(image.get_pixel(989,993).a < 0.01, "empty cell did not remain transparent")
		_expect(previous.is_empty() or image.get_data() != previous, "planes shared rendered content")
		previous = image.get_data()
		if layer == 3:
			_expect(not surface.render_enabled and surface.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "far backdrop was not baked")
	compositor.set_options({"mode":"flat"})
	await _settle()
	var rendered: Image = root.get_texture().get_image()
	var marker_pixel: Vector2i = Vector2i(compositor.get_layer_screen_position(Vector2(993.5,993.5), 0))
	var marker: Color = rendered.get_pixelv(marker_pixel)
	var empty: Color = rendered.get_pixel(marker_pixel.x - 14, marker_pixel.y)
	_expect(_colour_distance(marker, empty) > 0.035, "far-corner material did not reach the final composite")
	_expect(compositor.screen_to_layer(Vector2(marker_pixel) + Vector2(0.5,0.5),0).distance_to(Vector2(993.5,993.5)) < 1.0,
		"far-corner pixels and pointer coordinates disagree")

	# Render the same native-cell-shaped block with three different MAT-002
	# families. Measure the actual additional horizontal silhouette, rather
	# than mirroring the shader's numeric classification in GDScript.
	_expect(compositor.set_view(Vector2(480,480), Vector2(128,128)), "relief view rejected")
	compositor.set_options({"layer_visibility":Vector4(1,0,0,0), "relief_depth":32.0,
		"relief_slices":8, "relief_quantization":1.0, "parallax_strength":0.0})
	compositor._material.set_shader_parameter("relief_direction", Vector2(1,0))
	var lengths: Array[int] = []
	for material: int in [Cell.GLASS_BLOCK, Cell.PINE_PLANKS, Cell.HEAT_SHIELD_TILE]:
		_expect(compositor.apply_layer_packet("play", _packet("play", Rect2i(512,512,16,16), material)), "MAT-002 relief block rejected")
		compositor.set_options({"mode":"flat"})
		await _settle()
		var flat: Image = root.get_texture().get_image()
		compositor.set_options({"mode":"relief"})
		await _settle()
		var relief: Image = root.get_texture().get_image()
		var changed: int = 0
		for x: int in range(96,200):
			if _colour_distance(flat.get_pixel(x,80), relief.get_pixel(x,80)) > 0.01:
				changed += 1
		lengths.append(changed)
	_expect(lengths[0] > 0, "new glass block has no rendered relief")
	_expect(lengths[1] > lengths[0], "timber relief is not deeper than glass")
	_expect(lengths[2] > lengths[1], "hard building relief is not deeper than timber")
	print("Depth dimension pixels: %d checks, %d failures; glass/timber/hard relief pixels %s" % [checks, failures, lengths])
	compositor.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _packet(id: String, rect: Rect2i, material: int) -> Dictionary:
	serial += 1
	var cells := PackedByteArray()
	cells.resize(rect.size.x * rect.size.y * 2)
	for index: int in range(0,cells.size(),2):
		cells[index] = material
	return {"failed":false, "serial":serial, "channels":2, "full_refresh":false,
		"rectangles":PackedInt32Array([rect.position.x,rect.position.y,rect.size.x,rect.size.y,0,rect.size.x * 2]),
		"cells":cells, "layer_id":id, "reset_generation":1, "layer_tick":0}

func _settle() -> void:
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw

func _colour_distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b)))

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
