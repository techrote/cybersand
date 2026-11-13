extends SceneTree

## Actual production palette-shader pixels at magnification, including a
## discriminating reproduction of the old whole-cell camera rounding.
## Run with a real GL/ANGLE display. A headless invocation is a failed graphics
## qualification, not a pass or a claimed screenshot.
const Camera = preload("res://scripts/pixel_camera_transform.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const WORLD := Vector2i(512,256)
const VIEW := Vector2i(32,24)
const COLOUR_TOLERANCE: float = 1.0/255.0 + 0.000001
const FIXTURE_WATER_MODE: float = 0.0

class PaintFillFixture extends "res://scripts/workbench_paint_editor_overlay.gd":
	var fixture_camera := Vector2.ZERO
	var fixture_content := Rect2()
	var fixture_region := Rect2i(65,62,5,6)
	var rendered_rect := Rect2()

	func _draw() -> void:
		# Exercise the actual PAINT clipping/point/filled-region implementation;
		# only the editor/session prerequisites and outline are isolated here.
		_content = fixture_content
		_camera = fixture_camera
		_scale = Vector2(2.5,2.5)
		_extent = Vector2i(512,256)
		rendered_rect = _screen_region(fixture_region)
		_draw_region(fixture_region,Color.WHITE,Color.TRANSPARENT)

class RootWindowCameraHost extends "res://scripts/main.gd":
	var former_screen_helper := false
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _notification(_what: int) -> void: pass
	func _exit_tree() -> void: pass
	func _world_view_screen_transform() -> Transform2D:
		if former_screen_helper: return world_view.get_screen_transform()
		return super._world_view_screen_transform()

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
var overlay_measurements: Array[Dictionary] = []
var water_measurements: Array[Dictionary] = []
var root_window_measurements: Array[Dictionary] = []
var root_window_gui_inputs: Array[Dictionary] = []
var unit_scale_fractional_requests: Array[Dictionary] = []

const CURRENT_COORDINATES: String = "\tvec2 continuous_world_pixel = camera_origin_px + fitted_uv * view_size_px;\n\tif (native_pixel_mapping_enabled) {\n\t\tvec2 sample_position = floor(content_screen_origin + raw_fitted_uv * content_screen_size) + vec2(0.5);\n\t\t// Clip in the same physical space as picking. UV roundoff at a fitted\n\t\t// half-pixel edge must not drop the first column or leak the last row.\n\t\tinside_view = all(greaterThanEqual(sample_position, content_screen_origin))\n\t\t\t&& all(lessThan(sample_position, content_screen_origin + content_screen_size));\n\t\tcontinuous_world_pixel = (sample_position - world_zero_screen) * world_units_per_screen_pixel;\n\t}\n\tvec2 world_pixel = floor(continuous_world_pixel);\n\tvec2 cell_fraction = fract(continuous_world_pixel);"
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
	material.set_shader_parameter("water_presentation_mode",FIXTURE_WATER_MODE)
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


func configure_sample_mapping(target: ShaderMaterial, origin: Vector2, view: Vector2i,
		content: Rect2, native_sampling: bool = true) -> void:
	target.set_shader_parameter("camera_origin_px",origin)
	target.set_shader_parameter("native_pixel_mapping_enabled",native_sampling)
	if not native_sampling: return
	var mapping: Transform2D = Camera.presentation_screen_transform(origin,view,content,
		Transform2D.IDENTITY,Vector2(WORLD-view))
	target.set_shader_parameter("content_screen_origin",content.position)
	target.set_shader_parameter("content_screen_size",content.size)
	target.set_shader_parameter("world_zero_screen",mapping.origin)
	target.set_shader_parameter("world_units_per_screen_pixel",Camera.world_units_per_screen_pixel(mapping))


func render_frame(origin: Vector2, view: Vector2i, output: Vector2i,
		fitted: Rect2 = Rect2(0,0,1,1), native_sampling: bool = true,
		physical_content: Rect2 = Rect2()) -> Image:
	var resized: bool = viewport.size != output
	viewport.size = output
	surface.size = Vector2(output)
	material.set_shader_parameter("view_size_px",Vector2(view))
	material.set_shader_parameter("view_rect_uv",Vector4(fitted.position.x,fitted.position.y,fitted.size.x,fitted.size.y))
	# Like Main, supply the original physical content rectangle independently
	# of normalized UVs. A UV round trip can move a half-pixel boundary by one
	# float ULP, changing which physical samples the half-open clip includes.
	var content: Rect2 = physical_content if physical_content.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO,Vector2(output))
	var uniform_start: int = Time.get_ticks_usec()
	configure_sample_mapping(material,origin,view,content,native_sampling)
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
		"render_wait_usec":frame_elapsed,"resized":resized,"native_pixel_mapping":native_sampling})
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
		content: Rect2, label: String, letterbox_colour: Color = Color(0,0,0,-1)) -> void:
	# Derive the physical cell lattice independently from the production helper.
	# Camera inversion followed by a second float addition loses exact integer
	# ties at realistic fractional zoom, so the oracle retains the screen phase.
	var pixels_per_cell: Vector2 = content.size/Vector2(view)
	var world_zero: Vector2 = (content.position-origin*pixels_per_cell).round()
	world_zero = world_zero.clamp(content.position-Vector2(WORLD-view)*pixels_per_cell,content.position)
	var reciprocal: Vector2 = Vector2.ONE/pixels_per_cell
	var bad := 0
	var first_bad := Vector2i(-1,-1)
	var compared := 0
	var outside_compared := 0
	var outside_bad := 0
	var first_outside_bad := Vector2i(-1,-1)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var centre := Vector2(x+0.5,y+0.5)
			if not content.has_point(centre):
				if letterbox_colour.a >= 0:
					outside_compared += 1
					if not colour_equal(image.get_pixel(x,y),letterbox_colour):
						outside_bad += 1
						if first_outside_bad.x < 0: first_outside_bad = Vector2i(x,y)
				continue
			var world: Vector2 = (centre-world_zero)*reciprocal
			var cell := Vector2i(world.floor())
			if cell.x < 0 or cell.y < 0 or cell.x >= WORLD.x or cell.y >= WORLD.y: continue
			compared += 1
			if not colour_equal(image.get_pixel(x,y),reference.get_pixelv(cell)):
				bad += 1
				if first_bad.x < 0: first_bad = Vector2i(x,y)
	check(compared > 100 and bad == 0,
		label+" sharp nearest-cell pixels; mismatches="+str(bad)+" first="+str(first_bad))
	if letterbox_colour.a >= 0:
		check(outside_compared > 100 and outside_bad == 0,
			label+" half-open content boundary has no letterbox bleed; mismatches="
			+str(outside_bad)+" first="+str(first_outside_bad))


func save_capture(image: Image, label: String) -> void:
	if capture_folder.is_empty(): return
	var path := capture_folder.path_join(label+".png")
	if check(image.save_png(path) == OK,"saved graphical capture "+label):
		captures.append({"file":label+".png","sha256":FileAccess.get_sha256(path),
			"size":[image.get_width(),image.get_height()]})


func magnification_cases() -> void:
	for zoom: float in [2.0,4.0,8.0,2.5,1.0]:
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


func unit_scale_fractional_sequence() -> void:
	# At one physical pixel per cell, fractional requests must accumulate even
	# when a frame holds its pixel phase. Use binary-exact increments so the
	# reverse path can prove that presentation rounding never becomes input.
	var output := VIEW
	var area := Rect2(Vector2.ZERO,Vector2(output))
	var initial := Vector2(59.125,60.25)
	var requested := initial
	var world_zero := (area.position-requested).round()
	var presented: Vector2 = Camera.presentation_origin(requested,VIEW,area,Transform2D.IDENTITY)
	var previous: Image = await render_frame(presented,VIEW,output)
	var first: Image = previous
	compare_cell_oracle(previous,requested,VIEW,area,"1x fractional sequence initial")
	save_capture(first,"native-pixel-scrolling-1x-fractional-initial")
	var holds := 0
	var forward := Vector2i.ZERO
	var reverse := Vector2i.ZERO
	for direction: int in [1,-1]:
		for index: int in range(16):
			requested += Vector2(0.125,0.0625)*direction
			var next_zero := (area.position-requested).round()
			var delta := Vector2i(world_zero-next_zero)
			presented = Camera.presentation_origin(requested,VIEW,area,Transform2D.IDENTITY)
			var current: Image = await render_frame(presented,VIEW,output)
			var label := "1x fractional direction=%d frame=%d" % [direction,index]
			check(absi(delta.x)<=1 and absi(delta.y)<=1,label+" advances by at most one physical pixel")
			compare_cell_oracle(current,requested,VIEW,area,label)
			compare_translation(previous,current,delta,label)
			if delta == Vector2i.ZERO: holds += 1
			if direction == 1: forward += delta
			else: reverse += delta
			unit_scale_fractional_requests.append({"direction":direction,"frame":index,
				"requested_origin":[requested.x,requested.y],"presented_origin":[presented.x,presented.y],
				"expected_world_zero":[next_zero.x,next_zero.y],"physical_pixel_delta":[delta.x,delta.y]})
			world_zero = next_zero
			previous = current
		save_capture(previous,"native-pixel-scrolling-1x-fractional-"+("forward" if direction==1 else "reverse"))
	check(holds>0,"1x fractional requests retain identical frames until the pixel phase advances")
	check(forward==Vector2i(2,1) and reverse==Vector2i(-2,-1),"1x fractional requests advance and reverse both axes")
	check(requested==initial,"1x fractional request accumulator returns exactly without rounded feedback")
	compare_translation(first,previous,Vector2i.ZERO,"1x fractional sequence returns to its original framebuffer")


func letterbox_case() -> void:
	var output := Vector2i(173,117)
	var area := Rect2(6.5,7.5,160,96)
	var uv := Rect2(area.position/Vector2(output),area.size/Vector2(output))
	var origin: Vector2 = Camera.presentation_origin(Vector2(60.25,60.75),VIEW,area,Transform2D.IDENTITY)
	# A deliberately offscreen content rectangle gives an independent all-bar
	# render through the established fallback path, with no boundary ambiguity.
	# Every fixture material is an opaque relief solid, so Empty's contact shade
	# is constant across the outside pixels regardless of sampled world cell.
	var all_bars: Image = await render_frame(origin,VIEW,output,Rect2(2,2,1,1),false)
	var letterbox_colour: Color = all_bars.get_pixel(0,0)
	check(colour_equal(all_bars.get_pixel(output.x-1,output.y-1),letterbox_colour),
		"independent outside-view colour reference is uniform")
	var image: Image = await render_frame(origin,VIEW,output,uv,true,area)
	check(material.get_shader_parameter("content_screen_origin") == area.position
		and material.get_shader_parameter("content_screen_size") == area.size,
		"letterbox physical uniforms retain the exact authoritative fitted rectangle")
	compare_cell_oracle(image,origin,VIEW,area,"odd-sized viewport and fractional fitted rectangle",letterbox_colour)
	var shifted_origin: Vector2 = Camera.presentation_origin(Vector2(60.25,60.75)+Vector2(1,1)/(area.size/Vector2(VIEW)),
		VIEW,area,Transform2D.IDENTITY)
	var shifted: Image = await render_frame(shifted_origin,VIEW,output,uv,true,area)
	# Restrict translation to the fitted content; fixed letterboxing itself
	# correctly does not move with the World.
	var cropped: Image = image.get_region(Rect2i(8,9,156,92))
	var cropped_shifted: Image = shifted.get_region(Rect2i(8,9,156,92))
	compare_translation(cropped,cropped_shifted,Vector2i(1,1),"fitted-view diagonal pan")
	compare_cell_oracle(shifted,shifted_origin,VIEW,area,"fitted-view shifted nearest cells",letterbox_colour)
	save_capture(shifted,"native-pixel-scrolling-letterbox")


func realistic_fractional_zoom_case() -> void:
	# Realistic Workbench width, not only a tiny texture: float32 UV products
	# can cross an integer-cell tie differently after a one-pixel translation.
	# In particular, old x=349 and next x=348 both address world x=203 here.
	var view := Vector2i(240,128)
	var output := Vector2i(600,320)
	var area := Rect2(Vector2.ZERO,Vector2(output))
	var requested := Vector2(63.137,60.137)
	var first_origin: Vector2 = Camera.presentation_origin(requested,view,area,Transform2D.IDENTITY)
	var next_origin: Vector2 = Camera.presentation_origin(requested+Vector2(0.4,0),view,area,Transform2D.IDENTITY)
	check(absf(first_origin.x-63.2) < 0.0001 and absf(next_origin.x-63.6) < 0.0001,
		"realistic 2.5x fixture reaches the adversarial fractional phases")
	var first: Image = await render_frame(first_origin,view,output)
	var next: Image = await render_frame(next_origin,view,output)
	compare_cell_oracle(first,first_origin,view,area,"240-cell realistic 2.5x origin63.2")
	compare_cell_oracle(next,next_origin,view,area,"240-cell realistic 2.5x origin63.6")
	compare_translation(first,next,Vector2i(1,0),"240-cell realistic 2.5x one-display-pixel pan")
	var returned: Image = await render_frame(first_origin,view,output)
	compare_translation(next,returned,Vector2i(-1,0),"240-cell realistic 2.5x reverse pan")
	save_capture(first,"native-pixel-scrolling-realistic-2_5-before")
	save_capture(next,"native-pixel-scrolling-realistic-2_5-after")


func bind_fixture_texture(pixels: Texture2D) -> void:
	surface.texture = pixels
	material.set_shader_parameter("current_world_texture",pixels)
	material.set_shader_parameter("previous_world_texture",pixels)


func check_partial_water_coverage(baseline: Image, image: Image, target: Vector2i,
		origin: Vector2, zoom: float, mode: int) -> void:
	# The registered condition64 mask covers the lower half in mode1 and the
	# right half in mode2 when the right neighbour is full. Derive the expected
	# coverage from forward screen geometry, independently of shader sampling.
	var world_zero: Vector2 = -(origin*zoom).round()
	var cell := Rect2(Vector2(target)*zoom+world_zero,Vector2(zoom,zoom))
	var visible := 0
	var covered := 0
	var bad := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var sample := Vector2(x+0.5,y+0.5)
			if not cell.has_point(sample): continue
			visible += 1
			var before: Color = baseline.get_pixel(x,y)
			var after: Color = image.get_pixel(x,y)
			var changed: bool = (absf(before.r-after.r)+absf(before.g-after.g)
				+absf(before.b-after.b)+absf(before.a-after.a)) > 0.02
			if changed: covered += 1
			var expected: bool = sample.y >= cell.get_center().y if mode == 1 \
				else sample.x >= cell.get_center().x
			if changed != expected: bad += 1
	var label := "native partial Water mode=%d zoom=%s" % [mode,zoom]
	check(covered > 0 and covered < visible,label+" has nonzero partial coverage against empty baseline")
	check(bad == 0,label+" keeps its registered half-cell orientation; mismatches="+str(bad))
	if zoom == 4.0:
		check(visible == 16 and covered == 8,label+" retains exactly eight of sixteen target samples")
	water_measurements.append({"label":label,"material_id":3,"condition_byte":64,
		"fuller_right_neighbour_condition":255,"native_pixel_mapping":true,
		"target_cell":[target.x,target.y],"cell_screen_rect":[cell.position.x,cell.position.y,cell.size.x,cell.size.y],
		"visible_target_pixels":visible,"covered_target_pixels":covered,"mask_mismatches":bad})


func partial_water_native_mapping_case() -> void:
	# The established Water fixture uses standalone/default camera mapping.
	# Exercise the same real partial-cell material through physical sampling,
	# where fractional zoom can put a cell or its coverage edge on a pixel centre.
	var target := Vector2i(65,64)
	var empty := Image.create_empty(WORLD.x,WORLD.y,false,Image.FORMAT_RG8)
	var water: Image = empty.duplicate()
	water.set_pixelv(target,Color(3.0/255.0,64.0/255.0,0,1))
	water.set_pixelv(target+Vector2i.RIGHT,Color(3.0/255.0,1,0,1))
	var empty_texture := ImageTexture.create_from_image(empty)
	var water_texture := ImageTexture.create_from_image(water)
	for zoom: float in [4.0,2.5]:
		var output := Vector2i(Vector2(VIEW)*zoom)
		var origin := Vector2(60,60)
		var shifted := origin+Vector2(1.0/zoom,0)
		for mode: int in [1,2]:
			material.set_shader_parameter("water_presentation_mode",float(mode))
			bind_fixture_texture(empty_texture)
			var baseline: Image = await render_frame(origin,VIEW,output)
			bind_fixture_texture(water_texture)
			var first: Image = await render_frame(origin,VIEW,output)
			check(bool(material.get_shader_parameter("native_pixel_mapping_enabled")),
				"partial Water fixture uses actual native physical mapping")
			check_partial_water_coverage(baseline,first,target,origin,zoom,mode)
			var next: Image = await render_frame(shifted,VIEW,output)
			var label := "native partial Water mode=%d zoom=%s" % [mode,zoom]
			compare_translation(first,next,Vector2i(1,0),label+" one-display-pixel pan")
			var returned: Image = await render_frame(origin,VIEW,output)
			compare_translation(next,returned,Vector2i(-1,0),label+" reverse pan")
			check(first.get_data() != next.get_data(),label+" visibly moves its partial mask")
			var capture_label := "native-pixel-scrolling-water-mode-%d-zoom-%s" % [mode,str(zoom).replace(".","_")]
			save_capture(first,capture_label+"-before")
			save_capture(next,capture_label+"-after")
	bind_fixture_texture(world_texture)
	# Restore the explicitly registered fixture input; an unset shader default
	# is not a material override and get_shader_parameter() can return null.
	material.set_shader_parameter("water_presentation_mode",FIXTURE_WATER_MODE)


func compare_paint_fill_oracle(image: Image, world_zero: Vector2, region: Rect2i, label: String) -> void:
	# This forward physical rectangle keeps the exact phase rather than
	# recovering it from the inverse camera used by the production overlay.
	var expected_rect := Rect2(Vector2(region.position)*2.5+world_zero,Vector2(region.size)*2.5)
	var bad := 0
	var filled := 0
	var first_bad := Vector2i(-1,-1)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var expected: bool = expected_rect.has_point(Vector2(x+0.5,y+0.5))
			if expected: filled += 1
			if not colour_equal(image.get_pixel(x,y),Color.WHITE if expected else Color.BLACK):
				bad += 1
				if first_bad.x < 0: first_bad = Vector2i(x,y)
	check(filled > 100 and bad == 0,label+" actual PAINT fill covers exact cell samples; mismatches="
		+str(bad)+" first="+str(first_bad))
	overlay_measurements.append({"label":label,"expected_rect":[expected_rect.position.x,
		expected_rect.position.y,expected_rect.size.x,expected_rect.size.y],
		"expected_filled_pixels":filled,"mismatches":bad,"first_mismatch":[first_bad.x,first_bad.y]})


func paint_fill_fractional_boundary_case() -> void:
	# At these two phases, (65 - inverse_camera) * 2.5 lies just above then
	# below the exact half-pixel edge. Qualify actual raster coverage before
	# treating that CPU float difference as a visible overlay defect.
	var target := SubViewport.new()
	target.size = Vector2i(80,60)
	target.disable_3d = true
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(target)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.size = Vector2(target.size)
	target.add_child(background)
	var overlay := PaintFillFixture.new()
	overlay.fixture_content = Rect2(Vector2.ZERO,Vector2(target.size))
	target.add_child(overlay)
	var frames: Array[Image] = []
	for requested_x: float in [62.8,63.2]:
		var requested := Vector2(requested_x,60)
		overlay.fixture_camera = Camera.presentation_origin(requested,VIEW,overlay.fixture_content)
		overlay.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image: Image = target.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		frames.append(image)
		var exact_phase := -(requested*2.5).round()
		compare_paint_fill_oracle(image,exact_phase,overlay.fixture_region,
			"2.5x PAINT inverse camera "+str(overlay.fixture_camera.x))
		overlay_measurements.back()["actual_rect"] = [overlay.rendered_rect.position.x,
			overlay.rendered_rect.position.y,overlay.rendered_rect.size.x,overlay.rendered_rect.size.y]
		overlay_measurements.back()["presented_origin"] = [overlay.fixture_camera.x,overlay.fixture_camera.y]
	compare_translation(frames[0],frames[1],Vector2i(1,0),"2.5x actual PAINT fill one-pixel pan")
	check(frames[0].get_data() != frames[1].get_data(),"PAINT fill negative control detects retained frame")
	save_capture(frames[0],"native-pixel-scrolling-paint-fill-before")
	save_capture(frames[1],"native-pixel-scrolling-paint-fill-after")
	target.queue_free()
	await process_frame


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
		old_frames.append(await render_frame(requested.floor(),VIEW,output,Rect2(0,0,1,1),false))
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


func transform_values(value: Transform2D) -> Array:
	return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]


func configure_root_window_host(host: Control, requested: Vector2) -> void:
	host.camera_origin = requested
	var area: Rect2 = host.view_content_rect()
	var size: Vector2 = host.world_view.size
	host.world_shader.set_shader_parameter("view_size_px",Vector2(host.current_view_size))
	host.world_shader.set_shader_parameter("view_rect_uv",Vector4(area.position.x/size.x,
		area.position.y/size.y,area.size.x/size.x,area.size.y/size.y))
	host.world_shader.set_shader_parameter("camera_origin_px",host.presentation_camera_origin())
	# The production owner supplies all physical mapping uniforms.
	host.configure_pixel_camera(host.world_shader)


func root_window_observations(image: Image, host: Control, requested: Vector2) -> Dictionary:
	# Independently compose the actual viewport raster transform. CanvasItem's
	# popup/screen helper is deliberately not used to derive expected pixels.
	var render_transform: Transform2D = root.get_final_transform() \
		* host.world_view.get_global_transform_with_canvas()
	var physical_content: Rect2 = render_transform*host.view_content_rect()
	# Match the renderer's float32 basis composition without deriving a size
	# by subtracting transformed rectangle endpoints (which loses one ULP).
	var logical_scale: Vector2 = host.view_content_rect().size/Vector2(host.current_view_size)
	var scale := Vector2(render_transform.x.x*logical_scale.x,render_transform.y.y*logical_scale.y)
	var reciprocal := Vector2.ONE/scale
	var world_zero: Vector2 = (physical_content.position-requested*scale).round()
	# KEEP attaches the smaller viewport texture inside the native window.
	# Its readback excludes those integer letterbox margins.
	var attachment_origin := (Vector2(root.size)-Vector2(image.get_size()))/2.0
	var viewport_inverse: Transform2D = root.get_final_transform().affine_inverse()
	var control_inverse: Transform2D = host.world_view.get_global_transform_with_canvas().affine_inverse()
	var combined_inverse: Transform2D = render_transform.affine_inverse()
	var pixel_bad := 0
	var pick_bad := 0
	var compared := 0
	var first_pixel_bad := Vector2i(-1,-1)
	var first_pick_bad := Vector2i(-1,-1)
	var first_pick_details: Dictionary = {}
	var combined_inverse_pick_bad := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var physical_pixel := Vector2(x,y)+attachment_origin
			var centre := physical_pixel+Vector2(0.5,0.5)
			if not physical_content.has_point(centre): continue
			var cell := Vector2i(((centre-world_zero)*reciprocal).floor())
			if not Rect2i(Vector2i.ZERO,WORLD).has_point(cell): continue
			compared += 1
			if not colour_equal(image.get_pixel(x,y),reference.get_pixelv(cell)):
				pixel_bad += 1
				if first_pixel_bad.x < 0: first_pixel_bad = Vector2i(x,y)
			# Input reports a pixel coordinate; Main must choose that pixel's
			# centre before picking, including the real root stretch.
			# Godot first localizes the OS event into the viewport, then into
			# the Control. Inverting the composed render transform instead has
			# different float32 cancellation at integer physical mouse positions.
			var local_pointer: Vector2 = control_inverse*(viewport_inverse*physical_pixel)
			var picked: Vector2i = host.world_cell_from_local_point(local_pointer)
			if picked != cell:
				pick_bad += 1
				if first_pick_bad.x < 0:
					first_pick_bad = Vector2i(x,y)
					first_pick_details = {"physical_pointer":str(physical_pixel),"local_pointer":str(local_pointer),
						"reprojected_pointer":str(render_transform*local_pointer),"picked":str(picked),"expected":str(cell)}
			if host.world_cell_from_local_point(combined_inverse*physical_pixel) != cell:
				combined_inverse_pick_bad += 1
	return {"compared_pixels":compared,"pixel_mismatches":pixel_bad,"picking_mismatches":pick_bad,
		"first_pixel_mismatch":[first_pixel_bad.x,first_pixel_bad.y],
		"first_picking_mismatch":[first_pick_bad.x,first_pick_bad.y],
		"first_picking_details":first_pick_details,"combined_inverse_diagnostic_picking_mismatches":combined_inverse_pick_bad,
		"input_localization":"Pinned Godot Viewport final inverse, then Control global-with-canvas inverse; integer OS pixel positions retained",
		"actual_window":[root.size.x,root.size.y],"framebuffer_size":[image.get_width(),image.get_height()],
		"framebuffer_attachment_origin":[attachment_origin.x,attachment_origin.y],
		"physical_content":[physical_content.position.x,physical_content.position.y,physical_content.size.x,physical_content.size.y],
		"physical_pixels_per_cell":[scale.x,scale.y],"expected_world_zero":[world_zero.x,world_zero.y],
		"root_final_transform":transform_values(root.get_final_transform()),
		"canvas_item_screen_transform":transform_values(host.world_view.get_screen_transform()),
		"actual_view_render_transform":transform_values(render_transform),
		"production_mapping":transform_values(host.presentation_camera_screen_transform())}


func root_window_gui_input_cases(host: Control, image: Image, requested: Vector2, label: String) -> void:
	# Exercise the engine's real OS-to-viewport-to-Control localization, not
	# only its equivalent matrix formula. Fractional negatives must retain
	# their own containing pixel when the integer round-trip is repaired.
	var render_transform: Transform2D = root.get_final_transform()*host.world_view.get_global_transform_with_canvas()
	var content: Rect2 = render_transform*host.view_content_rect()
	var local_scale: Vector2 = host.view_content_rect().size/Vector2(host.current_view_size)
	var scale := Vector2(render_transform.x.x*local_scale.x,render_transform.y.y*local_scale.y)
	var reciprocal := Vector2.ONE/scale
	var world_zero := (content.position-requested*scale).round()
	var attachment := (Vector2(root.size)-Vector2(image.get_size()))/2.0
	var first := content.position.ceil()
	var fractional_base := first+Vector2(24,28)
	var points: Array[Vector2] = [first,fractional_base,first+Vector2(29,33),first+Vector2(34,38),
		first+Vector2(39,43),fractional_base+Vector2(-0.01,-0.01),
		fractional_base+Vector2(0.01,0.01),fractional_base+Vector2(0.99,0.99)]
	var pending := {"physical":Vector2.ZERO}
	var received: Array[Dictionary] = []
	var callback := func(event: InputEvent) -> void:
		if not event is InputEventMouseMotion: return
		var physical: Vector2 = pending.physical
		var sample := physical.floor()+Vector2(0.5,0.5)
		var expected := Vector2i(((sample-world_zero)*reciprocal).floor())
		var picked: Vector2i = host.world_cell_from_local_point(event.position)
		var reprojection: Vector2 = render_transform*event.position
		var stabilized: Vector2 = host._world_view_pointer_screen_position(event.position,render_transform)
		var pixel := Vector2i(physical.floor()-attachment)
		var record := {"label":label,"physical_pointer":[physical.x,physical.y],
			"event_local":[event.position.x,event.position.y],"reprojected_physical":[reprojection.x,reprojection.y],
			"stabilized_physical":[stabilized.x,stabilized.y],
			"picked_cell":[picked.x,picked.y],"expected_cell":[expected.x,expected.y],
			"framebuffer_pixel":[pixel.x,pixel.y],"matches":picked==expected,
			"framebuffer_matches_expected":colour_equal(image.get_pixelv(pixel),reference.get_pixelv(expected))}
		received.append(record)
	var old_filter: Control.MouseFilter = host.world_view.mouse_filter
	host.world_view.mouse_filter = Control.MOUSE_FILTER_STOP
	host.world_view.gui_input.connect(callback)
	for point: Vector2 in points:
		pending.physical = point
		var event := InputEventMouseMotion.new()
		event.position = point
		event.global_position = point
		root.push_input(event,false)
		await process_frame
	host.world_view.gui_input.disconnect(callback)
	host.world_view.mouse_filter = old_filter
	check(received.size()==points.size(),"actual root GUI delivers every integer/fractional pointer "+label)
	for record: Dictionary in received:
		check(bool(record.matches) and bool(record.framebuffer_matches_expected),
			"actual root GUI pointer matches framebuffer cell "+str(record))
	root_window_gui_inputs.append_array(received)


func root_window_framebuffer_cases() -> void:
	var original := {"size":root.size,"content_size":root.content_scale_size,
		"mode":root.content_scale_mode,"aspect":root.content_scale_aspect,
		"factor":root.content_scale_factor,"embed":root.is_embedding_subwindows(),
		"canvas":root.canvas_transform,"global_canvas":root.global_canvas_transform,
		"hdr":root.use_hdr_2d}
	root.set_embedding_subwindows(true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_factor = 1.0
	root.content_scale_size = Vector2i(1920,1080)
	root.canvas_transform = Transform2D.IDENTITY
	root.global_canvas_transform = Transform2D.IDENTITY
	root.use_hdr_2d = false
	var host: Control = load("res://main.tscn").instantiate()
	host.set_script(RootWindowCameraHost)
	for body: RigidBody2D in host.get_node("RigidBodies").get_children(): body.freeze = true
	root.add_child(host)
	host.world_view.reparent(host)
	host.get_node("Layout").hide()
	host.world_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.world_view.custom_minimum_size = Vector2.ZERO
	host.world_view.position = Vector2(37,47)
	host.world_view.texture = world_texture
	host.world_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.world_shader = material.duplicate() as ShaderMaterial
	host.world_view.material = host.world_shader
	host.current_view_size = Vector2i(120,80)
	host.world_extent = WORLD
	var negative_pixels := 0
	var negative_picks := 0
	for settings: Dictionary in [
		{"window":Vector2i(960,720),"logical_size":Vector2(480,320),"zoom":2.0,"scale":0.5},
		{"window":Vector2i(1280,960),"logical_size":Vector2(450,300),"zoom":2.5,"scale":2.0/3.0},
		{"window":Vector2i(960,720),"logical_size":Vector2(240,160),"zoom":1.0,"scale":0.5,"label_suffix":"-zoom-1"}]:
		root.size = settings.window
		host.world_view.size = settings.logical_size
		await process_frame
		await process_frame
		check(root.size == settings.window and root.is_embedding_subwindows()
			and absf(root.get_final_transform().x.x-float(settings.scale)) < 0.00001,
			"actual embedded root window applies nonunit canvas stretch "+str(settings.window))
		var requested := Vector2(63.0,60.137)
		for former: bool in [true,false]:
			host.former_screen_helper = former
			configure_root_window_host(host,requested)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var first: Image = root.get_texture().get_image()
			first.convert(Image.FORMAT_RGBA8)
			var record := root_window_observations(first,host,requested)
			record.former_screen_helper = former
			record.requested_origin = [requested.x,requested.y]
			var label := "root-%dx%d%s-%s" % [settings.window.x,settings.window.y,
				settings.get("label_suffix",""),"former" if former else "corrected"]
			record.label = label
			root_window_measurements.append(record)
			check(Vector2(record.physical_pixels_per_cell[0],record.physical_pixels_per_cell[1])
				==Vector2.ONE*float(settings.zoom),"root-window actual dimensions establish physical magnification "+label)
			check(int(record.compared_pixels)>1000,"root-window oracle observes actual material pixels "+label)
			if former:
				negative_pixels += int(record.pixel_mismatches)
				negative_picks += int(record.picking_mismatches)
			else:
				check(int(record.pixel_mismatches)==0,"root-window physical cell/framebuffer oracle "+label+" "+str(record))
				check(int(record.picking_mismatches)==0,"root-window pointer selects the actual framebuffer cell "+label+" "+str(record))
				await root_window_gui_input_cases(host,first,requested,label)
				var moved := requested+Vector2(1.0/float(settings.zoom),0)
				configure_root_window_host(host,moved)
				await RenderingServer.frame_post_draw
				var next: Image = root.get_texture().get_image()
				next.convert(Image.FORMAT_RGBA8)
				var moved_record := root_window_observations(next,host,moved)
				moved_record.former_screen_helper = false
				moved_record.requested_origin = [moved.x,moved.y]
				moved_record.label = label+"-pan"
				root_window_measurements.append(moved_record)
				check(int(moved_record.pixel_mismatches)==0 and int(moved_record.picking_mismatches)==0,
					"root-window one-physical-pixel pan preserves material/picking agreement "+label+" "+str(moved_record))
				var content: Array = record.physical_content
				var offset: Array = record.framebuffer_attachment_origin
				var crop := Rect2i(Vector2i(ceili(float(content[0])-float(offset[0]))+2,
					ceili(float(content[1])-float(offset[1]))+2),Vector2i(floori(float(content[2]))-4,floori(float(content[3]))-4))
				compare_translation(first.get_region(crop),next.get_region(crop),Vector2i(1,0),label+" one-display-pixel translated framebuffer")
				save_capture(next,"native-pixel-scrolling-"+label+"-pan")
			save_capture(first,"native-pixel-scrolling-"+label)
	check(negative_pixels>100,"old root screen helper fails the independent framebuffer oracle; mismatches="+str(negative_pixels))
	check(negative_picks>100,"old root screen helper fails actual pixel-centre picking; mismatches="+str(negative_picks))
	host.queue_free()
	await process_frame
	root.content_scale_mode = original.mode
	root.content_scale_aspect = original.aspect
	root.content_scale_factor = original.factor
	root.content_scale_size = original.content_size
	root.canvas_transform = original.canvas
	root.global_canvas_transform = original.global_canvas
	root.use_hdr_2d = original.hdr
	root.set_embedding_subwindows(original.embed)
	root.size = original.size
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.size == original.size and root.content_scale_size == original.content_size
		and root.content_scale_mode == original.mode and root.content_scale_aspect == original.aspect,
		"root window settings restored before historical shader pacing")


func measure_pacing(variant: ShaderMaterial, legacy: bool) -> Dictionary:
	var extended := OS.get_environment("CYBERSAND_CAMERA_PACING_EXTENDED") == "1"
	var warmup_frames := 32 if extended else 12
	var requested_frames := 240 if extended else 60
	var budget_usec := 60000000 if extended else 3000000
	surface.material = variant
	variant.set_shader_parameter("view_size_px",Vector2(128,96))
	variant.set_shader_parameter("view_rect_uv",Vector4(0,0,1,1))
	# Warm both variants before measuring. Shader compilation, resource setup,
	# screenshot readback and the previous image-comparison loops are excluded.
	for frame: int in range(warmup_frames):
		configure_sample_mapping(variant,Vector2(59,60),Vector2i(128,96),Rect2(0,0,1280,960),not legacy)
		await RenderingServer.frame_post_draw
	var frames_usec: Array[int] = []
	var uniforms_usec: Array[int] = []
	var start: int = Time.get_ticks_usec()
	for frame: int in range(requested_frames):
		var requested := Vector2(59+float(frame)*0.1,60)
		var presented: Vector2 = requested.floor() if legacy else Camera.presentation_origin(requested,
			Vector2i(128,96),Rect2(0,0,1280,960),Transform2D.IDENTITY)
		var frame_start: int = Time.get_ticks_usec()
		configure_sample_mapping(variant,presented,Vector2i(128,96),Rect2(0,0,1280,960),not legacy)
		uniforms_usec.append(Time.get_ticks_usec()-frame_start)
		await RenderingServer.frame_post_draw
		frames_usec.append(Time.get_ticks_usec()-frame_start)
		if Time.get_ticks_usec()-start >= budget_usec: break
	var elapsed: int = Time.get_ticks_usec()-start
	check(not frames_usec.is_empty() and elapsed > 0,"actual rendered pacing samples " + ("legacy" if legacy else "native"))
	return {"label":"same-source legacy-coordinate control" if legacy else "native-display-pixel camera",
		"frame_count":frames_usec.size(),"requested_frames":requested_frames,"budget_limited":frames_usec.size()<requested_frames,
		"warmup_frames":warmup_frames,"measurement_budget_usec":budget_usec,"elapsed_usec":elapsed,
		"frame_median_usec":percentile(frames_usec,0.5),"frame_p95_usec":percentile(frames_usec,0.95),
		"frame_p99_usec":percentile(frames_usec,0.99),"frame_max_usec":percentile(frames_usec,1.0),
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
	var abba: Array[Dictionary] = []
	if OS.get_environment("CYBERSAND_CAMERA_PACING_EXTENDED") == "1":
		# Same frozen world, coverage, shader, output and workload as the original
		# short comparison. Reversed repeat order separates arm cost from drift.
		abba.append_array([legacy,current])
		abba.append(await measure_pacing(material,false))
		abba.append(await measure_pacing(legacy_material,true))
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
	if not abba.is_empty():
		pacing.extended_order = ["legacy","native","native","legacy"]
		pacing.extended_abba = abba
		var legacy_frames: Array[int] = []
		var native_frames: Array[int] = []
		for index: int in range(4):
			if index in [0,3]: legacy_frames.append_array(abba[index].frame_samples_usec)
			else: native_frames.append_array(abba[index].frame_samples_usec)
		pacing.extended_summary = {}
		for key: String in ["legacy","native"]:
			var values: Array[int] = legacy_frames if key == "legacy" else native_frames
			pacing.extended_summary[key] = {"count":values.size(),"median_usec":percentile(values,0.5),
				"p95_usec":percentile(values,0.95),"p99_usec":percentile(values,0.99),"max_usec":percentile(values,1.0)}


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
	await realistic_fractional_zoom_case()
	await partial_water_native_mapping_case()
	check(water_measurements.size() == 4,"all four native-mapped partial Water cases completed")
	await paint_fill_fractional_boundary_case()
	check(overlay_measurements.size() == 2,"both fractional-boundary PAINT fill cases completed")
	await legacy_control_and_diagnostic()
	await root_window_framebuffer_cases()
	await unit_scale_fractional_sequence()
	await comparative_pacing()
	var result := {"schema":"native-pixel-scrolling-render-v1","checks":checks,"failures":failures,
		"context":Context.identity(get_script().resource_path,shader),
		"transform_sha256":FileAccess.get_sha256("res://scripts/pixel_camera_transform.gd"),
		"paint_overlay_sha256":FileAccess.get_sha256("res://scripts/workbench_paint_editor_overlay.gd"),
		"paint_overlay_measurements":overlay_measurements,
		"water_measurements":water_measurements,
		"root_window_measurements":root_window_measurements,
		"root_window_gui_inputs":root_window_gui_inputs,
		"unit_scale_fractional_requests":unit_scale_fractional_requests,
		"captures":captures,"frame_measurements":measurements,"comparative_pacing":pacing,
		"timing_scope":"uniform submission and frame wait including test synchronization; not a throughput benchmark"}
	if not capture_folder.is_empty():
		var receipt := FileAccess.open(capture_folder.path_join("native-pixel-scrolling-render.json"),FileAccess.WRITE)
		if receipt != null: receipt.store_string(JSON.stringify(result,"\t")+"\n")
	viewport.queue_free()
	await process_frame
	print("NATIVE_PIXEL_SCROLLING_RESULT ",JSON.stringify(result))
	quit(int(not failures.is_empty()))
