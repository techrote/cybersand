extends SceneTree

# Real GPU pixels check both occupancy safety and world-coordinate continuity.
# Native collision/traversal is tested separately in test_blacksite_nine.gd.
const Layout = preload("res://scripts/blacksite_nine_layout.gd")
var failures: int = 0
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func same(a: Color, b: Color) -> bool:
	return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) < 0.012

func pixels(view: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("BLACKSITE_NINE_RENDER: skipped (a rendering display is required)")
		quit(0)
		return
	var current := Image.create(1024,1024,false,Image.FORMAT_RG8)
	var previous := Image.create(1024,1024,false,Image.FORMAT_RG8)
	current.set_pixel(505,205,Color(62.0/255.0,0,0,1))
	current.set_pixel(506,205,Color(3.0/255.0,1,0,1))
	previous.set_pixel(507,205,Color(2.0/255.0,0,0,1))
	var current_texture := ImageTexture.create_from_image(current)
	var previous_texture := ImageTexture.create_from_image(previous)
	var view := SubViewport.new()
	view.size = Vector2i(64,64)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var under := ColorRect.new()
	under.size = Vector2(64,64)
	under.color = Color(0.8,0.4,0.3,1)
	view.add_child(under)
	var baseline: Image = await pixels(view)
	for effect: String in ["backdrop", "grade"]:
		var overlay := ColorRect.new()
		overlay.size = Vector2(64,64)
		var shader := ShaderMaterial.new()
		shader.shader = load("res://shaders/blacksite_nine_" + effect + ".gdshader")
		shader.set_shader_parameter("current_world_texture",current_texture)
		shader.set_shader_parameter("previous_world_texture",previous_texture)
		shader.set_shader_parameter("view_size_px",Vector2(16,16))
		shader.set_shader_parameter("camera_origin_px",Vector2(500,200))
		shader.set_shader_parameter("snapshot_blend",0.5)
		shader.set_shader_parameter("player_origin_px",Vector2(509,208))
		shader.set_shader_parameter("player_size_px",Vector2(2,3))
		overlay.material = shader
		view.add_child(overlay)
		var rendered: Image = await pixels(view)
		expect(same(rendered.get_pixel(38,34),baseline.get_pixel(38,34)),effect + " covered the sampled player")
		for point: Vector2i in [Vector2i(22,22),Vector2i(26,22),Vector2i(30,22)]:
			expect(same(rendered.get_pixelv(point),baseline.get_pixelv(point)) == (effect == "backdrop"),
				effect + " has an incorrect current/fading occupancy mask at " + str(point))
		expect(same(rendered.get_pixel(34,22),baseline.get_pixel(34,22)) == (effect == "grade"),
			effect + " has an incorrect Empty mask")
		shader.set_shader_parameter("snapshot_blend",1.0)
		var completed: Image = await pixels(view)
		expect(same(completed.get_pixel(30,22),baseline.get_pixel(30,22)) == (effect == "grade"),
			effect + " retained a completed previous-cell transition")
		current.set_pixel(505,205,Color(0,0,0,1))
		current.set_pixel(508,205,Color(62.0/255.0,0,0,1))
		current_texture.update(current)
		var edited: Image = await pixels(view)
		expect(same(edited.get_pixel(22,22),baseline.get_pixel(22,22)) == (effect == "grade"),
			effect + " retained a stale erased-cell mask")
		expect(same(edited.get_pixel(34,22),baseline.get_pixel(34,22)) == (effect == "backdrop"),
			effect + " did not reflect newly painted material")
		# A known mix of solid slabs and air exposes camera dependence in both
		# shaders. Neighbour reads always use the full immutable world texture.
		current.fill(Color(49.0/255.0,0,0,1))
		for x: int in range(32,992,41): current.fill_rect(Rect2i(x,32,7,960),Color(0,0,0,1))
		for y: int in range(32,992,53): current.fill_rect(Rect2i(32,y,960,5),Color(0,0,0,1))
		current_texture.update(current)
		shader.set_shader_parameter("view_size_px",Vector2(32,32))
		shader.set_shader_parameter("player_origin_px",Vector2(-1000,-1000))
		for edge: Dictionary in Layout.EDGES:
			var ports: Array[Vector2i] = Layout.edge_points(edge)
			var origin: Vector2i = (ports[0] + ports[1]) / 2 - Vector2i(16,16)
			var shift := Vector2i(4,0) if edge.axis == "x" else Vector2i(0,4)
			shader.set_shader_parameter("camera_origin_px",Vector2(origin))
			var left: Image = await pixels(view)
			shader.set_shader_parameter("camera_origin_px",Vector2(origin + shift))
			var right: Image = await pixels(view)
			var overlap := Vector2i(64,64) - shift * 2
			expect(left.get_region(Rect2i(shift*2,overlap)).get_data()
				== right.get_region(Rect2i(Vector2i.ZERO,overlap)).get_data(),
				effect + " changed pixels under camera motion across " + str(edge.name))
		overlay.queue_free()
		await process_frame
		current.fill(Color(0,0,0,1))
		current.set_pixel(505,205,Color(62.0/255.0,0,0,1))
		current.set_pixel(506,205,Color(3.0/255.0,1,0,1))
		current_texture.update(current)
	view.queue_free()
	await process_frame
	print("BLACKSITE_NINE_RENDER: ",checks," checks; 12 shared edges × 2 world-anchored effects; failures=",failures)
	quit(0 if failures == 0 else 1)
