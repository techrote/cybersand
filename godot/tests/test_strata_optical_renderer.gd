extends SceneTree

## Isolated real-renderer contract. Uses actual transparent SubViewport source
## pixels so alpha correctness is measured rather than inferred from compilation.
const Renderer = preload("res://scripts/depth/strata_optical_renderer.gd")
const HAZE := "shader_type canvas_item; render_mode unshaded; uniform float haze=0.0; varying vec4 vertex_colour; void vertex(){vertex_colour=COLOR;} void fragment(){vec4 c=texture(TEXTURE,UV);c.rgb=mix(c.rgb,vec3(0.055,0.105,0.15),haze);COLOR=c*vertex_colour;}"
var failures := 0
var checks := 0
var output_path := ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	checks += 1
	if value: return
	failures += 1
	push_error(message)


func configuration() -> Dictionary:
	var planes := {}
	for id: String in ["play", "scripted", "effects", "background"]:
		planes[id] = {"participates":id != "play", "depth":0.0 if id == "play" else 1.0,
			"contrast":1.0,"saturation":1.0,"tint":[1.0,1.0,1.0],"brightness":1.0,
			"defocus":1.0,"atmosphere":1.0,"glow":1.0,"opacity":1.0,"parallax":1.0}
	return {"enabled":true,"profile":"test","strength":1.0,"focus_mode":"play","focus_distance":0.0,
		"dof_width":0.0,"defocus":0.0,"transition_speed":0.0,"atmosphere":0.0,"tonal":0.0,
		"chromatic":0.0,"illumination":0.0,"shadow":0.0,"detail":0.0,"clarity":0.0,
		"defocus_method":"pixel","planes":planes}


func settle() -> void:
	for frame: int in 3:
		await process_frame
		await RenderingServer.frame_post_draw


func save_capture(name: String, image: Image) -> void:
	if output_path.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output_path)
	expect(image.save_png(output_path.path_join(name + ".png")) == OK, "Save original " + name)


func frequency_contract(renderer, source: SubViewport, output: SubViewport,
		drawables: Dictionary, document_planes: Array) -> void:
	# Flat bars establish alpha correctness but cannot prove detail suppression.
	# This rendered one-cell checker and isolated white impulse exercise distinct
	# frequency, highlight and quality paths without changing the production code.
	for child: CanvasItem in source.get_children(): child.hide()
	var pattern := Image.create(64,64,false,Image.FORMAT_RGBA8)
	pattern.fill(Color.TRANSPARENT)
	for y: int in range(8,24):
		for x: int in range(8,24):
			var value := 0.9 if (x+y)%2 == 0 else 0.1
			pattern.set_pixel(x,y,Color(value,value,value,1))
	pattern.set_pixel(40,16,Color.WHITE)
	pattern.set_pixel(0,44,Color.WHITE)
	pattern.fill_rect(Rect2i(40,40,8,8),Color(0,0,1,0.5))
	var image_view := TextureRect.new()
	image_view.texture = ImageTexture.create_from_image(pattern)
	image_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image_view.size = Vector2(64,64)
	source.add_child(image_view)
	var config := configuration()
	renderer.set_quality("balanced")
	renderer.configure(config,"play",document_planes,true)
	await settle()
	var reference := output.get_texture().get_image()
	var reference_contrast := absf(reference.get_pixel(14,14).r-reference.get_pixel(15,14).r)
	expect(reference_contrast > 0.75,"Rendered frequency fixture retains its one-cell checker contrast")
	save_capture("frequency-reference",reference)
	config.defocus_method = "detail"
	config.detail = 0.75
	renderer.configure(config,"play",document_planes,true)
	await settle()
	var detail := output.get_texture().get_image()
	var detail_contrast := absf(detail.get_pixel(14,14).r-detail.get_pixel(15,14).r)
	expect(detail_contrast < reference_contrast*0.4 and detail_contrast > 0.05,
		"Detail treatment suppresses one-cell interior contrast without erasing all local variation")
	var same_coverage := true
	for y: int in 64:
		for x: int in 64:
			if detail.get_pixel(x,y).a != reference.get_pixel(x,y).a: same_coverage = false
	expect(same_coverage,"Detail suppression preserves every source silhouette/partial-alpha pixel")
	save_capture("frequency-detail",detail)
	config.defocus_method = "diffusion"
	config.detail = 0.0
	config.defocus = 0.6666666667
	config.illumination = 1.5
	renderer.configure(config,"play",document_planes,true)
	await settle()
	var diffusion := output.get_texture().get_image()
	var halo := diffusion.get_pixel(38,16)
	expect(halo.a > 0.01 and halo.a < 0.2 and absf(halo.r-halo.a) < 0.01 and absf(halo.g-halo.a) < 0.01,
		"Isolated white highlight spreads bounded coverage with no dark or coloured halo")
	expect(diffusion.get_pixel(40,16).r > 0.98 and diffusion.get_pixel(40,16).a > 0.98,
		"Diffusion retains the sharp white impulse centre")
	save_capture("frequency-diffusion",diffusion)
	config.defocus_method = "pixel"
	config.illumination = 0.0
	renderer.set_quality("high")
	var previous_contrast := 1.0
	var progression := []
	var high: Image
	for radius: float in [0.0,1.0,2.0,3.0,6.0]:
		config.defocus = radius/3.0
		renderer.configure(config,"play",document_planes,true)
		await settle()
		high = output.get_texture().get_image()
		var contrast := absf(high.get_pixel(14,14).r-high.get_pixel(15,14).r)
		expect(contrast <= previous_contrast+0.01,"Increasing dense aperture does not restore checker contrast at radius"+str(radius))
		if radius > 0.0: expect(contrast < 0.02,"Dense aperture suppresses the one-cell checker at radius"+str(radius))
		var pure_hue := true
		for y: int in range(8,24):
			for x: int in range(32,48):
				var pixel := high.get_pixel(x,y)
				if absf(pixel.r-pixel.a) > 0.01 or absf(pixel.g-pixel.a) > 0.01 or absf(pixel.b-pixel.a) > 0.01: pure_hue = false
		expect(pure_hue,"Thin white structure retains correct RGB/coverage throughout focus at radius"+str(radius))
		progression.append({"radius_cells":radius,"checker_contrast":contrast,"thin_white_hue_preserved":pure_hue})
		previous_contrast = contrast
		save_capture("frequency-aperture-"+str(int(radius)),high)
	print("STRATA003_APERTURE_PROGRESSION "+JSON.stringify(progression))
	expect(absf(high.get_pixel(39,16).a-0.09668) < 0.015,"High-quality dense aperture uses normalized radius-six near weights")
	expect(high.get_pixel(63,44).a < 0.01,"Maximum-radius high tier does not wrap the texture-edge impulse")
	renderer.set_quality("balanced")
	expect(renderer.statistics().aperture_max_radius_cells == 3.0 and renderer.statistics().defocus_cells.scripted == 3.0,
		"Balanced tier caps support at three cells and thirteen source samples")
	renderer.set_quality("low")
	await settle()
	var low := output.get_texture().get_image()
	expect(low.get_pixel(39,16).a > 0.05 and low.get_pixel(34,16).a < 0.01,
		"Low-quality rendering actually bounds the aperture to one material cell")
	save_capture("frequency-low-aperture",low)
	config.defocus = 0.0
	renderer.configure(config,"play",document_planes,true)
	for id: String in drawables:
		drawables[id].modulate = Color(1,1,1,0.5)
		renderer.set_classic_haze(id,0.3)
	await settle()
	var faded := output.get_texture().get_image()
	var half_blue := faded.get_pixel(44,44)
	expect(absf(half_blue.b-0.25) < 0.02 and absf(half_blue.a-0.25) < 0.02,
		"Parent opacity scales partial source RGB and coverage exactly once")
	renderer.set_inspection({"bypass":true})
	await settle()
	var classic := output.get_texture().get_image()
	save_capture("frequency-haze-opacity-classic",classic)
	renderer.set_inspection({"bypass":false,"wipe":0.5})
	await settle()
	var wipe := output.get_texture().get_image()
	var classic_bytes := classic.get_region(Rect2i(128,0,64,64)).get_data()
	var wipe_bytes := wipe.get_region(Rect2i(128,0,64,64)).get_data()
	var changed_channels := 0
	var maximum_delta := 0
	for index: int in classic_bytes.size():
		var delta := absi(int(classic_bytes[index])-int(wipe_bytes[index]))
		if delta > 0: changed_channels += 1
		maximum_delta = maxi(maximum_delta,delta)
	print("STRATA003_CLASSIC_WIPE_PRECISION "+JSON.stringify({"changed_channels":changed_channels,"maximum_u8_delta":maximum_delta,"compared_bytes":classic_bytes.size()}))
	expect(wipe_bytes == classic_bytes,
		"Wipe Classic half remains exact under nonzero haze and parent opacity")
	save_capture("frequency-haze-opacity-wipe",wipe)
	renderer.set_inspection({"wipe":1.0})
	renderer.set_quality("balanced")
	for id: String in drawables:
		drawables[id].modulate = Color.WHITE
		renderer.set_classic_haze(id,0.0)
	image_view.queue_free()
	for child: CanvasItem in source.get_children():
		if child != image_view: child.show()
	await settle()


func run() -> void:
	var normalized := true
	var monotone := true
	var previous_responses := {}
	for step_index: int in 25:
		var weights: PackedFloat32Array = Renderer.aperture_weights(float(step_index)*0.25)
		var mass: float = weights[0]
		for index: int in range(1,7): mass += 2.0*weights[index]
		if absf(mass-1.0) > 0.00001: normalized = false
		for value: float in weights:
			if value < 0.0: normalized = false
		for fx: int in 9:
			for fy: int in 9:
				var response: float = weights[0]
				for index: int in range(1,7): response += weights[index]*(cos(float(fx)*PI*float(index)/8.0)+cos(float(fy)*PI*float(index)/8.0))
				var key := Vector2i(fx,fy)
				if response < -0.00001 or response > float(previous_responses.get(key,1.0))+0.00001: monotone = false
				previous_responses[key] = response
	expect(normalized,"Dense aperture weights remain positive and normalized across fractional focus radii")
	expect(monotone,"Dense aperture transfer does not restore any sampled spatial frequency during a focus sweep")
	expect(Renderer.aperture_weights(1.0) == PackedFloat32Array([0.5,0.25,0,0,0,0,0]),
		"One-cell dense aperture preserves the original balanced detail kernel")
	var renderer = Renderer.new()
	var drawables := {}
	var original_materials := {}
	var document_planes := []
	var output := SubViewport.new()
	output.size = Vector2i(192,64)
	output.transparent_bg = true
	output.world_2d = World2D.new()
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var source := SubViewport.new()
	source.size = Vector2i(64,64)
	source.transparent_bg = true
	source.world_2d = World2D.new()
	source.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(source)
	var red := ColorRect.new()
	red.color = Color(1,0,0,1)
	red.position = Vector2(8,8)
	red.size = Vector2(16,48)
	source.add_child(red)
	var translucent := ColorRect.new()
	translucent.color = Color(0,1,0,0.5)
	translucent.position = Vector2(32,8)
	translucent.size = Vector2(16,48)
	source.add_child(translucent)
	var shader := Shader.new()
	shader.code = HAZE
	for index: int in 3:
		var id: String = ["scripted","effects","background"][index]
		var drawable := TextureRect.new()
		drawable.position = Vector2(index*64,0)
		drawable.size = Vector2(64,64)
		drawable.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		drawable.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		drawable.texture = source.get_texture()
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("haze",0.0)
		drawable.material = material
		output.add_child(drawable)
		drawables[id] = drawable
		original_materials[id] = material
		document_planes.append({"id":id,"depth":0.5})
		renderer.register_plane(id,drawable)
	var config := configuration()
	renderer.configure({},"play",document_planes,true)
	expect(not renderer.active(), "Legacy document is exactly Classic")
	expect(renderer.statistics().material_count == 0, "Classic allocates no optical materials")
	for id: String in drawables: expect(drawables[id].material == original_materials[id], "Classic material object identity " + id)
	renderer.configure(config,"play",document_planes,true)
	expect(renderer.active() and renderer.statistics().material_count == 3, "Enabled treatment owns exactly three lazy materials")
	for metadata: Dictionary in renderer._planes.values():
		expect(metadata.size() == 1 and metadata.has("depth"), "Optical settings cache excludes authored geometry")
	var uniforms: int = renderer.statistics().uniform_writes
	renderer.configure(config,"play",document_planes,true)
	expect(renderer.statistics().uniform_writes == uniforms, "Identical settings do not repeat uniform writes")
	for id: String in drawables:
		drawables[id].material.set_shader_parameter("surface_size",Vector2(64,64))
	var instances := []
	for id: String in drawables: instances.append(drawables[id].material.get_instance_id())
	expect(not renderer.set_inspection({"wipe":NAN}), "Nonfinite comparison is refused")
	expect(not renderer.set_inspection({"focus_override":"intruder"}), "Unknown focus plane is refused")
	expect(not renderer.set_quality("ultra"), "Unknown quality tier is refused")
	expect(renderer.set_inspection({"bypass":true,"clarity":true}), "Temporary bypass accepted even with clarity selected")
	expect(is_equal_approx(renderer.atmosphere_opacity("scripted"),1.0), "Classic bypass preserves procedural motifs")
	for id: String in drawables: expect(drawables[id].material == original_materials[id], "Bypass restores original material " + id)
	renderer.set_inspection({"bypass":false,"clarity":true})
	expect(is_equal_approx(renderer.atmosphere_opacity("scripted"),0.35), "Physical clarity attenuates separately drawn motifs")
	config.planes.scripted.participates = false
	renderer.configure(config,"play",document_planes,true)
	expect(drawables.scripted.material != original_materials.scripted and is_equal_approx(renderer.atmosphere_opacity("scripted"),0.35), "Temporary clarity covers a profile-excluded plane and its motifs")
	expect(not config.planes.scripted.participates, "Temporary clarity does not rewrite authored participation")
	renderer.set_inspection({"clarity":false})
	expect(drawables.scripted.material == original_materials.scripted and is_equal_approx(renderer.atmosphere_opacity("scripted"),1.0), "Releasing clarity restores authored plane exclusion")
	config.planes.scripted.participates = true
	renderer.configure(config,"play",document_planes,true)
	renderer.set_inspection({"clarity":true})
	renderer.set_inspection({"wipe":0.5})
	expect(is_equal_approx(renderer.atmosphere_opacity("scripted"),1.0), "Partial material wipe leaves motifs Classic")
	renderer.set_inspection({"bypass":true,"clarity":true,"wipe":1.0})
	uniforms = renderer.statistics().uniform_writes
	renderer.advance(0.1)
	renderer.sync_view(Vector2i(64,64),Vector2.ZERO,Vector2(64,64),1.0,null)
	expect(renderer.statistics().uniform_writes == uniforms, "Bypass does no per-frame optical uniform work")
	if DisplayServer.get_name() == "headless":
		print("STRATA003_OPTICAL_RENDERER graphical_required=true checks=%d failures=%d" % [checks,failures])
		quit(1 if failures else 0)
		return
	await settle()
	var classic: Image = output.get_texture().get_image()
	save_capture("classic-alpha",classic)
	expect(renderer.set_inspection({"bypass":false,"clarity":false}), "Restore processed view")
	await settle()
	var processed: Image = output.get_texture().get_image()
	save_capture("processed-alpha",processed)
	var green := processed.get_pixel(40,20)
	expect(absf(green.g - 0.5) < 0.035 and absf(green.a - 0.5) < 0.035,
		"Premultiplied half-opacity green retains colour/coverage without a dark halo: " + str(green))
	expect(processed.get_pixel(4,20).a < 0.01, "Empty texture remains transparent")
	expect(processed.get_pixel(16,20).r > 0.98 and processed.get_pixel(16,20).a > 0.98, "Opaque material centre is preserved")
	expect(classic.get_pixel(40,20).g < green.g - 0.15, "Graphical witness distinguishes historical double alpha from processed composition")
	renderer.set_inspection({"bypass":true})
	await settle()
	expect(output.get_texture().get_image().get_data() == classic.get_data(), "Classic return is pixel-exact after optical processing")
	renderer.set_inspection({"bypass":false,"wipe":0.5})
	await settle()
	var wipe := output.get_texture().get_image()
	expect(wipe.get_pixel(40,20).g > 0.45 and wipe.get_pixel(168,20).g < 0.3, "One-pass wipe shows processed left and exact Classic right")
	save_capture("wipe-alpha",wipe)
	renderer.set_inspection({"wipe":1.0})
	config.defocus = 0.6666666667
	renderer.configure(config,"play",document_planes,true)
	await settle()
	var defocused: Image = output.get_texture().get_image()
	var rim := defocused.get_pixel(7,20)
	expect(rim.a > 0.02 and absf(rim.r-rim.a) < 0.02 and rim.g < 0.01, "Defocus coverage spreads the pure red hue without dark/bright alpha edges: " + str(rim))
	expect(defocused.get_pixel(0,20).a < 0.01 and defocused.get_pixel(63,20).a < 0.01, "Bounded sampling does not wrap across texture borders")
	save_capture("pixel-aperture",defocused)
	config.defocus_method = "detail"
	config.detail = 0.65
	renderer.configure(config,"play",document_planes,true)
	await settle()
	var detail: Image = output.get_texture().get_image()
	expect(detail.get_pixel(7,20).a < 0.01, "Detail treatment preserves the architectural silhouette")
	expect(absf(detail.get_pixel(40,20).a-0.5) < 0.035, "Detail treatment preserves partial alpha")
	save_capture("detail-preserving",detail)
	config.defocus_method = "diffusion"
	config.illumination = 1.5
	renderer.configure(config,"play",document_planes,true)
	await settle()
	save_capture("highlight-diffusion",output.get_texture().get_image())
	# The real shader must include MAT002 basalt/aluminium/brass and preserve
	# negative controls for gas/liquid/powder/reserved IDs. No native World needed.
	config.defocus_method = "pixel"
	config.defocus = 0.0
	config.detail = 0.0
	config.illumination = 0.0
	config.shadow = 0.5
	config.shadow_offset = [0.0,0.0]
	config.shadow_softness = 0.0
	renderer.configure(config,"play",document_planes,true)
	var mask_image := Image.create(64,64,false,Image.FORMAT_RG8)
	var mask_texture := ImageTexture.create_from_image(mask_image)
	for id: String in drawables:
		drawables[id].material.set_shader_parameter("play_cells",mask_texture)
		drawables[id].material.set_shader_parameter("play_mask_available",true)
	for material: int in [95,97,100,101,114,119,3,4,13,29,10]:
		mask_image.fill(Color(float(material)/255.0,0,0,1))
		mask_texture.update(mask_image)
		await settle()
		var shadow_pixel := output.get_texture().get_image().get_pixel(16,20)
		var expected := 0.5 if material in [95,97,100,101,114,119] else 1.0
		expect(absf(shadow_pixel.r-expected) < 0.035,"Architectural shadow material%d expected%.2f got%s" % [material,expected,str(shadow_pixel)])
	config.shadow = 0.0
	config.clarity = 1.0
	renderer.configure(config,"play",document_planes,true)
	mask_image.fill(Color(0,0,0,1))
	mask_texture.update(mask_image)
	var play_shader := Shader.new()
	play_shader.code = "shader_type canvas_item; uniform sampler2D current_world_texture; uniform vec2 player_origin_px=vec2(-4096.0); uniform vec2 player_size_px=vec2(0.0);"
	var play_material := ShaderMaterial.new()
	play_material.shader = play_shader
	play_material.set_shader_parameter("current_world_texture",mask_texture)
	var actor_bounds: Array[Rect2] = [Rect2(11,17,4,4)]
	renderer.sync_view(Vector2i(64,64),Vector2.ZERO,Vector2(64,64),1.0,play_material,actor_bounds)
	expect(renderer.statistics().actor_reveal_rectangles == 1,"Published actor bound reaches the optical material without a native query")
	await settle()
	var revealed := output.get_texture().get_image()
	expect(absf(revealed.get_pixel(16,20).r-0.24) < 0.035,"Local actor reveal attenuates rear content near the published body")
	expect(absf(revealed.get_pixel(16,48).r-0.42) < 0.035,"Local actor reveal leaves distant rear content at the global clarity level")
	save_capture("actor-reveal",revealed)
	renderer.sync_view(Vector2i(64,64),Vector2.ZERO,Vector2(64,64),1.0,play_material)
	await settle()
	expect(renderer.statistics().actor_reveal_rectangles == 0 and absf(output.get_texture().get_image().get_pixel(16,20).r-0.42) < 0.035,
		"Retired actor publication clears local reveal rather than retaining a ghost")
	config.clarity = 0.0
	await frequency_contract(renderer,source,output,drawables,document_planes)
	config.focus_mode = "manual"
	config.focus_distance = 1.0
	config.transition_speed = 5.0
	renderer.configure(config,"play",document_planes,true)
	var before := float(renderer.statistics().focus_distance)
	renderer.advance(0.1)
	var after := float(renderer.statistics().focus_distance)
	expect(after > before and after < 1.0, "Focus transition advances without overshoot or changing authored distance")
	expect(float(config.focus_distance) == 1.0, "Focus interpolation does not mutate authored settings")
	renderer.set_inspection({"focus_override":"play"})
	expect(renderer.statistics().target_focus == 0.0, "Inspection focus is separate from selected edit plane")
	renderer.set_quality("low")
	for radius: Variant in renderer.statistics().defocus_cells.values(): expect(float(radius) <= 1.0,"Low tier bounds aperture to one native cell")
	for iteration: int in 30:
		renderer.set_inspection({"bypass":true})
		renderer.set_inspection({"bypass":false})
	var index := 0
	for id: String in drawables:
		expect(drawables[id].material.get_instance_id() == instances[index], "Repeated profile bypass reuses material " + id)
		index += 1
	expect(renderer.statistics().additional_worlds == 0 and renderer.statistics().additional_viewports == 0,
		"Renderer retains no native/render-target owner")
	renderer.restore()
	for id: String in drawables: expect(drawables[id].material == original_materials[id], "Retirement restores original material " + id)
	output.queue_free()
	source.queue_free()
	await process_frame
	print("STRATA003_OPTICAL_RENDERER graphical_required=false checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
