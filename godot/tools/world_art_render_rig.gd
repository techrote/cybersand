extends SubViewport
## Presentation-only material renderer shared by the interactive window and its exports.
## The RG8 Image is the immutable source; no native simulation or CPU colour substitute.
const BACKGROUND = Color(0.031, 0.043, 0.071, 1.0)
var _world: ImageTexture
var _world_size := Vector2i.ONE
var _background: ColorRect
var _paint: TextureRect
var _emission_viewport: SubViewport
var _emission_rect: ColorRect
var _overlay: TextureRect
var _palette: ShaderMaterial
var _emission: ShaderMaterial
var _composite: ShaderMaterial
var _atlas: ImageTexture
var _program: ImageTexture
var _origin := Vector2.ZERO
var _world_view := Vector2.ONE
var _time := 1.37
var _glow := true
var _quality := true

func setup(input: Image, output_pixels: Vector2i) -> void:
	if input == null or input.is_empty() or input.get_format() != Image.FORMAT_RG8:
		push_error("World-art preview requires a real RG8 image")
		return
	size = output_pixels.max(Vector2i.ONE)
	disable_3d = true
	use_hdr_2d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_size = input.get_size()
	_world = ImageTexture.create_from_image(input)
	_atlas = CyberMaterialAppearanceLut.create_texture()
	_program = CyberMaterialAppearanceLut.create_program_texture()
	_background = ColorRect.new()
	_background.color = BACKGROUND
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_palette = ShaderMaterial.new()
	_palette.shader = CyberPaletteShader.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	_paint = TextureRect.new()
	_paint.texture = _world
	_paint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paint.stretch_mode = TextureRect.STRETCH_SCALE
	_paint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint.material = _palette
	add_child(_paint)
	_emission_viewport = SubViewport.new()
	_emission_viewport.disable_3d = true
	_emission_viewport.transparent_bg = true
	_emission_viewport.use_hdr_2d = true
	_emission_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_emission_viewport)
	_emission = ShaderMaterial.new()
	_emission.shader = load("res://shaders/material_emission.gdshader")
	_emission_rect = ColorRect.new()
	_emission_rect.color = Color.WHITE
	_emission_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emission_rect.material = _emission
	_emission_viewport.add_child(_emission_rect)
	_composite = ShaderMaterial.new()
	_composite.shader = load("res://shaders/glow_composite.gdshader")
	_overlay = TextureRect.new()
	_overlay.texture = _emission_viewport.get_texture()
	_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.material = _composite
	add_child(_overlay)
	_palette.set_shader_parameter("player_origin_px", Vector2(-100000, -100000))
	_palette.set_shader_parameter("condition_projection_enabled", 1.0)
	_palette.set_shader_parameter("water_presentation_mode", 0.0)
	_palette.set_shader_parameter("snapshot_blend", 1.0)
	_palette.set_shader_parameter("growth_decor", 1.0)
	_palette.set_shader_parameter("material_lut", _atlas)
	_palette.set_shader_parameter("material_program_lut", _program)
	_palette.set_shader_parameter("material_lut_size", Vector2(
		CyberMaterialAppearanceLut.ATLAS_WIDTH, CyberMaterialAppearanceLut.ATLAS_HEIGHT))
	_emission.set_shader_parameter("material_program_lut", _program)
	_emission.set_shader_parameter("condition_projection_enabled", 1.0)
	_sync()

func replace_input(input: Image) -> void:
	if input == null or input.is_empty() or input.get_format() != Image.FORMAT_RG8:
		push_error("Invalid replacement RG8 world")
		return
	_world_size = input.get_size()
	_world = ImageTexture.create_from_image(input)
	_paint.texture = _world
	_sync()

func set_resolution(pixels: Vector2i) -> void:
	size = pixels.max(Vector2i.ONE)
	_sync()

func set_view(origin: Vector2, world_view: Vector2) -> void:
	_origin = origin
	_world_view = world_view.max(Vector2.ONE * 0.0001)
	_sync()

func set_presentation(time_seconds: float, glow_enabled: bool, high_quality: bool) -> void:
	_time = time_seconds
	_glow = glow_enabled
	_quality = high_quality
	_sync()

func renderer_identity() -> Dictionary:
	return {
		"godot": Engine.get_version_info().string,
		"os": OS.get_name(),
		"display": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"graphics_adapter": RenderingServer.get_video_adapter_name(),
		"palette": CyberPaletteShader.provenance(_palette.shader),
	}

func _sync() -> void:
	if _world == null or _paint == null:
		return
	var pixels: Vector2i = size.max(Vector2i.ONE)
	_background.size = Vector2(pixels)
	_paint.size = Vector2(pixels)
	_overlay.size = Vector2(pixels)
	_emission_viewport.size = Vector2i(maxi(1, (pixels.x + 1) / 2),
		maxi(1, (pixels.y + 1) / 2))
	_emission_rect.size = Vector2(_emission_viewport.size)
	var view_end: Vector2 = _origin + _world_view
	var clipped_origin: Vector2 = _origin.max(Vector2.ZERO)
	var clipped_end: Vector2 = view_end.min(Vector2(_world_size))
	var clipped_size: Vector2 = (clipped_end - clipped_origin).max(Vector2.ZERO)
	# The palette's existing view_rect_uv masks letterboxing instead of repeating
	# an edge cell. Actual cell coordinates remain in source/world space.
	var view_rect := Vector4(
		(clipped_origin.x - _origin.x) / _world_view.x,
		(clipped_origin.y - _origin.y) / _world_view.y,
		clipped_size.x / _world_view.x, clipped_size.y / _world_view.y)
	_palette.set_shader_parameter("world_size_px", Vector2(_world_size))
	_palette.set_shader_parameter("view_size_px", clipped_size.max(Vector2.ONE * 0.0001))
	_palette.set_shader_parameter("view_rect_uv", view_rect)
	_palette.set_shader_parameter("camera_origin_px", clipped_origin)
	_palette.set_shader_parameter("current_world_texture", _world)
	_palette.set_shader_parameter("previous_world_texture", _world)
	_palette.set_shader_parameter("structured_detail", 1.0 if _quality else 0.0)
	_palette.set_shader_parameter("presentation_time_override", _time)
	_emission.set_shader_parameter("world_size_px", Vector2(_world_size))
	_emission.set_shader_parameter("view_size_px", _world_view)
	_emission.set_shader_parameter("camera_origin_px", _origin)
	_emission.set_shader_parameter("world_texture", _world)
	_emission.set_shader_parameter("presentation_time_override", _time)
	_overlay.visible = _glow
	_emission_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if _glow else SubViewport.UPDATE_DISABLED)

func set_background_enabled(enabled: bool) -> void:
	if _background == null:
		return
	_background.visible = enabled
	_palette.set_shader_parameter("growth_decor", 1.0 if enabled else 0.0)
