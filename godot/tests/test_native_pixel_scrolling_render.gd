extends SceneTree

## Actual production palette-shader pixels at magnification, including a
## discriminating reproduction of the old whole-cell camera rounding.
## Run with a real GL/ANGLE display. A headless invocation is a failed graphics
## qualification, not a pass or a claimed screenshot.
const Camera = preload("res://scripts/pixel_camera_transform.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const WORLD := Vector2i(256,256)
const VIEW := Vector2i(32,24)
const COLOUR_TOLERANCE: float = 1.0/255.0 + 0.000001
var checks: int = 0
var failures: Array[String] = []
var measurements: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var viewport: SubViewport
var surface: TextureRect
var material: ShaderMaterial
var shader: Shader
var world_texture: ImageTexture
var reference: Image
var capture_folder: String
var pacing: Dictionary = {}

const CURRENT_COORDINATES: String = "\tvec2 continuous_world_pixel = camera_origin_px + fitted_uv * view_size_px;\n\tvec2 world_pixel = floor(continuous_world_pixel);\n\tvec2 cell_fraction = fract(continuous_world_pixel);"
const LEGACY_COORDINATES: String = "\tvec2 continuous_view_pixel = fitted_uv * view_size_px;\n\tvec2 view_pixel = floor(continuous_view_pixel);\n\tvec2 world_pixel = camera_origin_px + view_pixel;\n\tvec2 cell_fraction = fract(camera_origin_px + continuous_view_pixel);"


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("NATIVE_PIXEL_SCROLLING " + label)
	return ok


func create_fixture() -> void:
	# Nonperiodic opaque materials expose both axes, single-cell strips and
	# x/y=64 chunk boundaries. Native material law is not involved in this
	# immutable RG8 presentation fixture.
	var world := Image.create_empty(WORLD.x,WORLD.y,false,Image.FORMAT_RG8)
	var ids: Array[int] = [1,7,13,28,58,81,131]
	for y: int in range(WORLD.y):
		for x: int in range(WORLD.x):
			var index: int = posmod(x*17+y*29+int(x/3)*11+int(y/5)*7,ids.size())
			if x == 64 or y == 64: index = 4
			world.set_pixel(x,y,Color(float(ids[index])/255.0,0,0,1))
	world_texture = ImageTexture.create_from_image(world)
	shader = CyberPaletteShader.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("world_size_px",Vector2(WORLD))
	material.set_shader_parameter("view_rect_uv",Vector4(0,0,1,1))
	material.set_shader_parameter("player_origin_px",Vector2(-1000,-1000))
	material.set_shader_parameter("condition_projection_enabled",1.0)
	material.set_shader_parameter("snapshot_blend",1.0)
	material.set_shader_parameter("presentation_time_override",3.0)
	material.set_shader_parameter("structured_detail",0.0)
	material.set_shader_parameter("growth_decor",0.0)
	material.set_shader_parameter("current_world_texture",world_texture)
	material.set_shader_parameter("previous_world_texture",world_texture)
	material.set_shader_parameter("material_lut",CyberMaterialAppearanceLut.create_texture())
	material.set_shader_parameter("material_program_lut",CyberMaterialAppearanceLut.create_program_texture())
	material.set_shader_parameter("material_lut_size",Vector2(
		CyberMaterialAppearanceLut.ATLAS_WIDTH,CyberMaterialAppearanceLut.ATLAS_HEIGHT))
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	surface = TextureRect.new()
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode = TextureRect.STRETCH_SCALE
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	surface.texture = world_texture
	surface.material = material
	viewport.add_child(surface)


func render_frame(origin: Vector2, view: Vector2i, output: Vector2i,
		fitted: Rect2 = Rect2(0,0,1,1)) -> Image:
	var resized: bool = viewport.size != output
	viewport.size = output
	surface.size = Vector2(output)
	material.set_shader_parameter("view_size_px",Vector2(view))
	material.set_shader_parameter("view_rect_uv",Vector4(fitted.position.x,fitted.position.y,fitted.size.x,fitted.size.y))
	var uniform_start: int = Time.get_ticks_usec()
	material.set_shader_parameter("camera_origin_px",origin)
	var uniform_elapsed: int = Time.get_ticks_usec()-uniform_start
	var frame_start: int = Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	# Resize/resource creation may take a render update; ordinary pan captures
	# deliberately await exactly one frame after the uniform change.
	if resized: await RenderingServer.frame_post_draw
	var frame_elapsed: int = Time.get_ticks_usec()-frame_start
	var image: Image = viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	measurements.append({"output":[output.x,output.y],"view":[view.x,view.y],
		"origin":[origin.x,origin.y],"uniform_update_usec":uniform_elapsed,
		"render_wait_usec":frame_elapsed,"resized":resized})
	return image


func colour_equal(a: Color, b: Color) -> bool:
	return absf(a.r-b.r) <= COLOUR_TOLERANCE and absf(a.g-b.g) <= COLOUR_TOLERANCE \
		and absf(a.b-b.b) <= COLOUR_TOLERANCE and absf(a.a-b.a) <= COLOUR_TOLERANCE


func compare_translation(previous: Image, current: Image, pixel_delta: Vector2i, label: String) -> void:
	var bounds := Rect2i(Vector2i.ZERO,current.get_size()).intersection(
		Rect2i(-pixel_delta,previous.get_size()))
	var bad := 0
	var first_bad := Vector2i(-1,-1)
	for y: int in range(bounds.position.y,bounds.end.y):
		for x: int in range(bounds.position.x,bounds.end.x):
			if not colour_equal(current.get_pixel(x,y),previous.get_pixel(x+pixel_delta.x,y+pixel_delta.y)):
				bad += 1
				if first_bad.x < 0: first_bad = Vector2i(x,y)
	check(bounds.get_area() > 100 and bad == 0,
		label+" exact translated framebuffer; mismatches="+str(bad)+" first="+str(first_bad))


func compare_cell_oracle(image: Image, origin: Vector2, view: Vector2i,
		content: Rect2, label: String) -> void:
	var bad := 0
	var first_bad := Vector2i(-1,-1)
	var compared := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var centre := Vector2(x+0.5,y+0.5)
			if not content.has_point(centre): continue
			var world: Vector2 = origin+(centre-content.position)*Vector2(view)/content.size
			var cell := Vector2i(world.floor())
			if cell.x < 0 or cell.y < 0 or cell.x >= WORLD.x or cell.y >= WORLD.y: continue
			compared += 1
			if not colour_equal(image.get_pixel(x,y),reference.get_pixelv(cell)):
				bad += 1
				if first_bad.x < 0: first_bad = Vector2i(x,y)
	check(compared > 100 and bad == 0,
		label+" sharp nearest-cell pixels; mismatches="+str(bad)+" first="+str(first_bad))


func save_capture(image: Image, label: String) -> void:
	if capture_folder.is_empty(): return
	var path := capture_folder.path_join(label+".png")
	if check(image.save_png(path) == OK,"saved graphical capture "+label):
		captures.append({"file":label+".png","sha256":FileAccess.get_sha256(path),
			"size":[image.get_width(),image.get_height()]})


func magnification_cases() -> void:
	for zoom: float in [2.0,4.0,8.0,2.5]:
		var output := Vector2i(Vector2(VIEW)*zoom)
		var area := Rect2(Vector2.ZERO,Vector2(output))
		var requested := Vector2(59.0,60.0)
		var presented: Vector2 = Camera.presentation_origin(requested,VIEW,area,Transform2D.IDENTITY)
		var previous: Image = await render_frame(presented,VIEW,output)
		compare_cell_oracle(previous,presented,VIEW,area,"zoom="+str(zoom)+" initial")
		for delta: Vector2i in [Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),
				Vector2i(1,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(-1,-1),Vector2i(9,7)]:
			requested += Vector2(delta)/zoom
			presented = Camera.presentation_origin(requested,VIEW,area,Transform2D.IDENTITY)
			var current: Image = await render_frame(presented,VIEW,output)
			var label := "zoom=%s pan=%s" % [zoom,delta]
			compare_translation(previous,current,delta,label)
			compare_cell_oracle(current,presented,VIEW,area,label)
			previous = current
		save_capture(previous,"native-pixel-scrolling-zoom-"+str(zoom).replace(".","_"))
		# The final complete World row/column must remain present after panning
		# to the bounds; this samples the same texture, with no guard copying.
		presented = Vector2(WORLD-VIEW)
		var edge: Image = await render_frame(presented,VIEW,output)
		compare_cell_oracle(edge,presented,VIEW,area,"zoom="+str(zoom)+" far world edges")


func letterbox_case() -> void:
	var output := Vector2i(173,117)
	var area := Rect2(6.5,7.5,160,96)
	var uv := Rect2(area.position/Vector2(output),area.size/Vector2(output))
	var origin: Vector2 = Camera.presentation_origin(Vector2(60.25,60.75),VIEW,area,Transform2D.IDENTITY)
	var image: Image = await render_frame(origin,VIEW,output,uv)
	compare_cell_oracle(image,origin,VIEW,area,"odd-sized viewport and fractional fitted rectangle")
	var shifted_origin: Vector2 = Camera.presentation_origin(Vector2(60.25,60.75)+Vector2(1,1)/(area.size/Vector2(VIEW)),
		VIEW,area,Transform2D.IDENTITY)
	var shifted: Image = await render_frame(shifted_origin,VIEW,output,uv)
	# Restrict translation to the fitted content; fixed letterboxing itself
	# correctly does not move with the World.
	var cropped: Image = image.get_region(Rect2i(8,9,156,92))
	var cropped_shifted: Image = shifted.get_region(Rect2i(8,9,156,92))
	compare_translation(cropped,cropped_shifted,Vector2i(1,1),"fitted-view diagonal pan")
	compare_cell_oracle(shifted,shifted_origin,VIEW,area,"fitted-view shifted nearest cells")
	save_capture(shifted,"native-pixel-scrolling-letterbox")


func legacy_control_and_diagnostic() -> void:
	var output := VIEW*4
	var area := Rect2(Vector2.ZERO,Vector2(output))
	var old_frames: Array[Image] = []
	var new_frames: Array[Image] = []
	for index: int in range(5):
		var requested := Vector2(60+index*0.25,60)
		# With an integer origin the old floor(view)+origin and current
		# floor(view+origin) formula are mathematically identical. Passing the
		# original whole-cell camera here recreates the actual former pipeline.
		old_frames.append(await render_frame(requested.floor(),VIEW,output))
		var presented: Vector2 = Camera.presentation_origin(requested,VIEW,area,Transform2D.IDENTITY)
		new_frames.append(await render_frame(presented,VIEW,output))
		if index > 0:
			compare_translation(new_frames[index-1],new_frames[index],Vector2i(1,0),
				"4x slow native pan frame "+str(index))
	for index: int in range(1,4):
		check(old_frames[index].get_data() == old_frames[0].get_data(),
			"legacy negative control repeats frame for sub-cell pan "+str(index))
	check(old_frames[4].get_data() != old_frames[3].get_data(),"legacy negative control eventually jumps")
	compare_translation(old_frames[3],old_frames[4],Vector2i(4,0),"legacy jump spans four display pixels")
	check(new_frames[1].get_data() != new_frames[0].get_data(),"one native display pixel is visibly different")
	if not capture_folder.is_empty(): await contact_sheet(old_frames,new_frames)


func contact_sheet(old_frames: Array[Image], new_frames: Array[Image]) -> void:
	var sheet := SubViewport.new()
	sheet.size = Vector2i(576,1160)
	sheet.disable_3d = true
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	var background := ColorRect.new()
	background.color = Color(0.035,0.045,0.065)
	background.size = Vector2(sheet.size)
	sheet.add_child(background)
	for column: int in range(2):
		var heading := Label.new()
		heading.position = Vector2(16+column*280,10)
		heading.text = "Legacy: whole cells" if column == 0 else "Native: display pixels"
		heading.add_theme_font_size_override("font_size",19)
		sheet.add_child(heading)
	for index: int in range(old_frames.size()):
		for column: int in range(2):
			var caption := Label.new()
			caption.position = Vector2(16+column*280,42+index*222)
			caption.text = "Camera + %.2f world cells" % (index*0.25)
			caption.add_theme_font_size_override("font_size",14)
			sheet.add_child(caption)
			var picture := TextureRect.new()
			picture.texture = ImageTexture.create_from_image(old_frames[index] if column == 0 else new_frames[index])
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_SCALE
			picture.position = Vector2(16+column*280,65+index*222)
			picture.size = Vector2(VIEW*8)
			sheet.add_child(picture)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = sheet.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	save_capture(image,"native-pixel-scrolling-before-after")
	sheet.queue_free()
	await process_frame


func percentile(values: Array[int], fraction: float) -> int:
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(fraction*sorted.size())-1,0,sorted.size()-1)] if not sorted.is_empty() else 0


func measure_pacing(variant: ShaderMaterial, legacy: bool) -> Dictionary:
	surface.material = variant
	variant.set_shader_parameter("view_size_px",Vector2(128,96))
	variant.set_shader_parameter("view_rect_uv",Vector4(0,0,1,1))
	# Warm both variants before measuring. Shader compilation, resource setup,
	# screenshot readback and the previous image-comparison loops are excluded.
	for frame: int in range(12):
		variant.set_shader_parameter("camera_origin_px",Vector2(59,60))
		await RenderingServer.frame_post_draw
	var frames_usec: Array[int] = []
	var uniforms_usec: Array[int] = []
	var start: int = Time.get_ticks_usec()
	for frame: int in range(60):
		var requested := Vector2(59+float(frame)*0.1,60)
		var presented: Vector2 = requested.floor() if legacy else Camera.presentation_origin(requested,
			Vector2i(128,96),Rect2(0,0,1280,960),Transform2D.IDENTITY)
		var frame_start: int = Time.get_ticks_usec()
		variant.set_shader_parameter("camera_origin_px",presented)
		uniforms_usec.append(Time.get_ticks_usec()-frame_start)
		await RenderingServer.frame_post_draw
		frames_usec.append(Time.get_ticks_usec()-frame_start)
		if Time.get_ticks_usec()-start >= 3000000: break
	var elapsed: int = Time.get_ticks_usec()-start
	check(not frames_usec.is_empty() and elapsed > 0,"actual rendered pacing samples " + ("legacy" if legacy else "native"))
	return {"label":"same-source legacy-coordinate control" if legacy else "native-display-pixel camera",
		"frame_count":frames_usec.size(),"requested_frames":60,"budget_limited":frames_usec.size()<60,
		"warmup_frames":12,"measurement_budget_usec":3000000,"elapsed_usec":elapsed,
		"frame_median_usec":percentile(frames_usec,0.5),"frame_p95_usec":percentile(frames_usec,0.95),
		"uniform_median_usec":percentile(uniforms_usec,0.5),"uniform_p95_usec":percentile(uniforms_usec,0.95),
		"observed_frames_per_second":float(frames_usec.size())*1000000.0/float(maxi(elapsed,1)),
		"frame_samples_usec":frames_usec,"uniform_samples_usec":uniforms_usec,
		"shader_sha256":variant.shader.code.sha256_text()}


func comparative_pacing() -> void:
	# This explicit coordinate-only mutation is the prior presentation formula,
	# not a claim to be a separately checked-out former application build. All
	# other compiled palette code, textures, uniforms and output sizes match.
	if not check(shader.code.count(CURRENT_COORDINATES) == 1,
		"legacy pacing control replaces exactly the known coordinate block"): return
	var legacy_shader := Shader.new()
	legacy_shader.code = shader.code.replace(CURRENT_COORDINATES,LEGACY_COORDINATES)
	var legacy_material: ShaderMaterial = material.duplicate() as ShaderMaterial
	legacy_material.shader = legacy_shader
	check(legacy_shader.code.count(LEGACY_COORDINATES) == 1,
		"legacy pacing control retains its exact original coordinate formula")
	viewport.size = Vector2i(1280,960)
	surface.size = Vector2(viewport.size)
	var old_vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var legacy: Dictionary = await measure_pacing(legacy_material,true)
	var current: Dictionary = await measure_pacing(material,false)
	DisplayServer.window_set_vsync_mode(old_vsync)
	surface.material = material
	pacing = {"schema":"native-pixel-scrolling-pacing-v1","advisory":true,
		"scope":"same-process actual rendered palette; no image readback during timing; compile/warmup excluded; CPU and GPU are not separated",
		"output_pixels":[1280,960],"view_cells":[128,96],"world_cells":[WORLD.x,WORLD.y],
		"vsync":"requested disabled; driver/compositor may constrain cadence",
		"legacy":legacy,"native":current,
		"median_frame_ratio":float(current.frame_median_usec)/float(maxi(int(legacy.frame_median_usec),1)),
		"p95_frame_ratio":float(current.frame_p95_usec)/float(maxi(int(legacy.frame_p95_usec),1)),
		"control_source_sha256":legacy_shader.code.sha256_text(),"production_shader_sha256":shader.code.sha256_text(),
		"control_replacement_from":CURRENT_COORDINATES,"control_replacement_to":LEGACY_COORDINATES}


func run() -> void:
	if DisplayServer.get_name() == "headless":
		check(false,"graphical qualification requires a real rendering DisplayServer")
		print("NATIVE_PIXEL_SCROLLING_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
		quit(1)
		return
	capture_folder = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if not capture_folder.is_empty():
		check(DirAccess.make_dir_recursive_absolute(capture_folder) == OK,"capture directory available")
	create_fixture()
	Context.emit(get_script().resource_path,shader)
	reference = await render_frame(Vector2.ZERO,WORLD,WORLD)
	check(reference.get_size() == WORLD,"one-display-pixel-per-cell reference rendered")
	await magnification_cases()
	await letterbox_case()
	await legacy_control_and_diagnostic()
	await comparative_pacing()
	var result := {"schema":"native-pixel-scrolling-render-v1","checks":checks,"failures":failures,
		"context":Context.identity(get_script().resource_path,shader),
		"transform_sha256":FileAccess.get_sha256("res://scripts/pixel_camera_transform.gd"),
		"captures":captures,"frame_measurements":measurements,"comparative_pacing":pacing,
		"timing_scope":"uniform submission and frame wait including test synchronization; not a throughput benchmark"}
	if not capture_folder.is_empty():
		var receipt := FileAccess.open(capture_folder.path_join("native-pixel-scrolling-render.json"),FileAccess.WRITE)
		if receipt != null: receipt.store_string(JSON.stringify(result,"\t")+"\n")
	viewport.queue_free()
	await process_frame
	print("NATIVE_PIXEL_SCROLLING_RESULT ",JSON.stringify(result))
	quit(int(not failures.is_empty()))
