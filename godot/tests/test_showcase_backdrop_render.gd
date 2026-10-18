extends SceneTree

# Actual-pixel guard: scene dressing must never paint over material edits,
# temporal remnants or the sampled player. Headless CI cannot submit GL frames.
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func same(a: Color, b: Color) -> bool:
	return absf(a.r-b.r) + absf(a.g-b.g) + absf(a.b-b.b) < 0.012

func pixels(view: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOWCASE_BACKDROP_RENDER: skipped (headless DisplayServer has no frame submission)")
		quit(0)
		return
	var current := Image.create(1024, 1024, false, Image.FORMAT_RG8)
	var previous := Image.create(1024, 1024, false, Image.FORMAT_RG8)
	current.set_pixel(505, 205, Color(62.0/255.0, 0, 0, 1))
	current.set_pixel(506, 205, Color(3.0/255.0, 1, 0, 1))
	previous.set_pixel(507, 205, Color(2.0/255.0, 0, 0, 1))
	var current_texture := ImageTexture.create_from_image(current)
	var previous_texture := ImageTexture.create_from_image(previous)
	var view := SubViewport.new()
	view.size = Vector2i(64,64)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var under := ColorRect.new()
	under.size = Vector2(64,64)
	under.color = Color(0.8,0.1,0.4,1)
	view.add_child(under)
	var baseline: Image = await pixels(view)
	var overlay := ColorRect.new()
	overlay.size = Vector2(64,64)
	var shader := ShaderMaterial.new()
	shader.shader = load("res://shaders/neon_reliquary_backdrop.gdshader")
	shader.set_shader_parameter("current_world_texture", current_texture)
	shader.set_shader_parameter("previous_world_texture", previous_texture)
	shader.set_shader_parameter("view_size_px", Vector2(16,16))
	shader.set_shader_parameter("camera_origin_px", Vector2(500,200))
	shader.set_shader_parameter("snapshot_blend", 0.5)
	shader.set_shader_parameter("player_origin_px", Vector2(509,208))
	shader.set_shader_parameter("player_size_px", Vector2(2,3))
	overlay.material = shader
	view.add_child(overlay)
	for district: int in range(4):
		shader.set_shader_parameter("district_index", district)
		shader.set_shader_parameter("snapshot_blend", 0.5)
		current.set_pixel(505,205,Color(62.0/255.0,0,0,1))
		current.set_pixel(508,205,Color(0,0,0,1))
		current_texture.update(current)
		var rendered: Image = await pixels(view)
		for point: Vector2i in [Vector2i(22,22),Vector2i(26,22),Vector2i(30,22),Vector2i(38,34)]:
			expect(same(rendered.get_pixelv(point), baseline.get_pixelv(point)),
				"Backdrop covered current solid/liquid, fading previous cell or player: " + str(point))
		expect(not same(rendered.get_pixel(34,22), baseline.get_pixel(34,22)),
			"Backdrop did not render in empty space")
		shader.set_shader_parameter("snapshot_blend", 1.0)
		current.set_pixel(505,205,Color(0,0,0,1))
		current.set_pixel(508,205,Color(62.0/255.0,0,0,1))
		current_texture.update(current)
		var edited: Image = await pixels(view)
		expect(not same(edited.get_pixel(22,22), baseline.get_pixel(22,22)),
			"Erased cell retained a stale scenery mask")
		expect(not same(edited.get_pixel(30,22), baseline.get_pixel(30,22)),
			"Completed transition retained a stale previous-cell mask")
		expect(same(edited.get_pixel(34,22), baseline.get_pixel(34,22)),
			"Fresh paint was covered by the backdrop")
	view.queue_free()
	await process_frame
	print("SHOWCASE_BACKDROP_RENDER: actual pixels, four district palettes, occupancy/player/transition/edit masks; failures=", failures)
	quit(0 if failures == 0 else 1)
