extends SceneTree

const Main = preload("res://scripts/main.gd")
const Program = preload("res://scripts/material_appearance_lut.gd")
const Composite = preload("res://shaders/glow_composite.gdshader")
const Emission = preload("res://shaders/material_emission.gdshader")
const SIMPLE = [0,2,3,58]

func _initialize() -> void:
	_run.call_deferred()


func target(extent: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = extent
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Glow comparison requires graphical HDR readback")
		quit(1)
		return
	var app := Main.new()
	var emission := ShaderMaterial.new()
	emission.shader = Emission
	app.glow_source_shader = emission
	var baseline := ShaderMaterial.new()
	var original := OS.get_environment("CYBERSAND_TEST_GLOW_CONTROL")
	baseline.shader = Composite if original.is_empty() else load(original)
	var candidate := ShaderMaterial.new()
	candidate.shader = Composite
	app.glow_composite_shader = candidate
	var source := target(Vector2i(240,135))
	var emitter := ColorRect.new()
	emitter.size = Vector2(source.size)
	emitter.material = emission
	source.add_child(emitter)
	var output := target(Vector2i(1280,720))
	var background := ColorRect.new()
	background.color = Color(0.125,0.32,0.5,0.4)
	background.size = Vector2(output.size)
	output.add_child(background)
	var halo := TextureRect.new()
	halo.texture = source.get_texture()
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	halo.size = Vector2(output.size)
	output.add_child(halo)
	var program := Program.create_program_texture()
	var defaults := program.get_image()
	var world := Image.create(480,270,false,Image.FORMAT_RG8)
	for band: int in range(4):
		world.fill_rect(Rect2i(band*120,0,120,270),Color(SIMPLE[band]/255.0,0.68,0,1))
	var plane := ImageTexture.create_from_image(world)
	emission.set_shader_parameter("world_texture",plane)
	emission.set_shader_parameter("world_size_px",Vector2(world.get_size()))
	emission.set_shader_parameter("view_size_px",Vector2(world.get_size()))
	emission.set_shader_parameter("condition_projection_enabled",1.0)
	emission.set_shader_parameter("presentation_time_override",1.25)
	var timed := not OS.get_environment("CYBERSAND_TEST_GLOW_TIMING").is_empty()
	var errors: Array[String] = []
	var rows: Array = []
	var black_hash := ""
	for variation in range(7):
		var edited := defaults.duplicate()
		if variation in [1,2,3,4]:
			var id: int = SIMPLE[variation-1]
			edited.set_pixel(1,id,Color(0,1,0,0))
			edited.set_pixel(2,id,Color(1,1,0.6 if variation%2 else 0.0,0.0 if variation%2 else 0.8))
			edited.set_pixel(3,id,Color(4,2,1,0))
		if variation == 3: program = ImageTexture.create_from_image(edited)
		else: program.update(edited)
		if variation == 5:
			world.fill_rect(Rect2i(200,80,32,40),Color(6.0/255.0,1,0,1))
			plane.update(world)
		if variation == 6:
			world.fill_rect(Rect2i(200,80,32,40),Color(2.0/255.0,0.68,0,1))
			plane.update(world)
		emission.set_shader_parameter("material_program_lut",program)
		app._ambient_sources_absent = variation != 5
		emission.set_shader_parameter("ambient_sources_absent",app._ambient_sources_absent)
		app._bind_glow_composite_proof()
		if candidate.get_shader_parameter("material_program_lut") != emission.get_shader_parameter("material_program_lut"):
			errors.append("active emission LUT reference mismatch")
		var witness := ""
		for policy: int in ([0,1,1,0,1,0,0,1] if timed and variation == 0 else [0,1]):
			halo.material = baseline if policy == 0 else candidate
			await RenderingServer.frame_post_draw
			RenderingServer.force_sync()
			var times: Array[int] = []
			for draw in (12 if timed and variation == 0 else 1):
				var began := Time.get_ticks_usec()
				RenderingServer.force_draw(false)
				RenderingServer.force_sync()
				times.append(Time.get_ticks_usec()-began)
			var image := output.get_texture().get_image()
			var identity := sha(image.get_data())
			if witness.is_empty(): witness = identity
			if image.get_format() not in [Image.FORMAT_RGBAH,Image.FORMAT_RGBAF] or witness != identity:
				errors.append("HDR bytes including alpha differ at variation %d policy %d" % [variation,policy])
			rows.append({"variation":variation,"policy":policy,"sha256":identity,"format":image.get_format(),"usec":times})
		if variation == 0: black_hash = witness
		elif (variation < 6) == (black_hash == witness): errors.append("missing emitter or stale glow at %d" % variation)
	var result := {"errors":errors,"rows":rows,"renderer":RenderingServer.get_video_adapter_name(),
		"output":[1280,720],"source":[240,135],"scope":"synchronous software/host render with full HDR byte comparison"}
	var path := OS.get_environment("CYBERSAND_TEST_GLOW_OUTPUT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify(result))
		file.close()
	print("WORKBENCH_GLOW_COMPOSITE ",JSON.stringify({"errors":errors,"rows":rows.size()}))
	app.free()
	quit(0 if errors.is_empty() else 1)
