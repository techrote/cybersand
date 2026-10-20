class_name CyberDepthCompositor
extends Control

const Surface = preload("res://scripts/depth/depth_layer_surface.gd")
const IDS: Array[String] = ["play", "scripted", "effects", "background"]
const MODES: Dictionary = {"flat": 0, "relief": 1, "stack": 2, "hybrid": 3, "diorama": 4}
const WORLD_SIZE: Vector2 = Vector2(640, 360)

var world_size: Vector2 = WORLD_SIZE
var view_size: Vector2 = Vector2(480, 270)
var camera_origin: Vector2 = Vector2(80, 45)
var layer_scale: Vector4 = Vector4(1.0, 0.94, 0.88, 0.78)
var layer_parallax: Vector4 = Vector4(1.0, 0.70, 0.44, 0.18)
var layer_visibility: Vector4 = Vector4.ONE
var parallax_strength: float = 1.0
var _surfaces: Array[CyberDepthLayerSurface] = []
var _output: TextureRect
var _material: ShaderMaterial
var _configured: bool = false
var _presentation_time: float = 0.0
var _frozen_material_animation: bool = false
var last_error: String = ""

func configure(authored_size: Vector2i = Vector2i(WORLD_SIZE)) -> bool:
	if (authored_size.x < 8 or authored_size.y < 8
			or authored_size.x > Surface.NATIVE_SIZE.x or authored_size.y > Surface.NATIVE_SIZE.y):
		last_error = "Depth dimensions must be within 8..1024 cells on each axis"
		return false
	if _configured:
		if world_size != Vector2(authored_size):
			last_error = "Configured depth surfaces cannot change authored dimensions"
			return false
		last_error = ""
		return true
	world_size = Vector2(authored_size)
	view_size = Vector2(minf(view_size.x, world_size.x), minf(view_size.y, world_size.y))
	camera_origin = camera_origin.clamp(Vector2.ZERO, world_size - view_size)
	_configured = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	for index: int in range(IDS.size()):
		var surface := Surface.new()
		surface.name = "Layer_%s" % IDS[index]
		surface.configure(IDS[index], IDS[index] == "background", authored_size)
		_surfaces.append(surface)
		add_child(surface)
	_output = TextureRect.new()
	_output.name = "Composite"
	_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	_output.texture = ImageTexture.create_from_image(white)
	_output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_output.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_output)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/depth_composite.gdshader")
	_output.material = _material
	for index: int in range(IDS.size()):
		_material.set_shader_parameter("layer_%d" % index, _surfaces[index].get_texture())
	_material.set_shader_parameter("play_cells", _surfaces[0].cell_texture)
	_sync_uniforms()
	resized.connect(_layout)
	_layout()
	last_error = ""
	return true

func apply_layer_packet(id: String, packet: Dictionary) -> bool:
	var index: int = IDS.find(id)
	if index < 0:
		return false
	var accepted: bool = _surfaces[index].apply_packet(packet)
	if accepted and index == 0:
		_material.set_shader_parameter("play_cells", _surfaces[0].cell_texture)
	return accepted

func set_camera(origin: Vector2) -> void:
	if not is_finite(origin.x) or not is_finite(origin.y):
		last_error = "Camera origin must be finite"
		return
	camera_origin = Vector2(
		clampf(origin.x, 0.0, world_size.x - view_size.x),
		clampf(origin.y, 0.0, world_size.y - view_size.y)
	)
	if _material != null:
		_material.set_shader_parameter("camera_origin", camera_origin)
	last_error = ""

func set_view(origin: Vector2, extent: Vector2) -> bool:
	# Reject the whole candidate before modifying either half of the view.
	if (not is_finite(origin.x) or not is_finite(origin.y)
			or not is_finite(extent.x) or not is_finite(extent.y)
			or extent.x <= 0.0 or extent.y <= 0.0
			or extent.x > world_size.x or extent.y > world_size.y):
		last_error = "View must be finite, positive and within the authored world"
		return false
	view_size = extent
	set_camera(origin)
	if _material != null:
		_sync_uniforms()
	_layout()
	last_error = ""
	return true

func set_time(value: float) -> void:
	_presentation_time = value
	if _material != null:
		_material.set_shader_parameter("presentation_time", value)

func set_options(options: Dictionary) -> void:
	if _material == null:
		return
	if options.has("mode"):
		var raw: Variant = options["mode"]
		var mode: int = int(raw) if raw is int else int(MODES.get(str(raw), 3))
		_material.set_shader_parameter("mode", clampi(mode, 0, 4))
	if options.has("parallax_strength"):
		parallax_strength = clampf(float(options["parallax_strength"]), 0.0, 2.0)
		_material.set_shader_parameter("parallax_strength", parallax_strength)
	if options.has("relief_depth"):
		_material.set_shader_parameter("relief_depth", clampf(float(options["relief_depth"]), 0.0, 32.0))
	if options.has("relief_slices"):
		_material.set_shader_parameter("relief_slices", clampi(int(options["relief_slices"]), 1, 8))
	if options.has("relief_quantization"):
		_material.set_shader_parameter("relief_quantization", clampf(float(options["relief_quantization"]), 1.0, 8.0))
	if options.has("fog_strength"):
		_material.set_shader_parameter("fog_strength", clampf(float(options["fog_strength"]), 0.0, 1.0))
	if options.has("reflection_strength"):
		_material.set_shader_parameter("reflection_strength", clampf(float(options["reflection_strength"]), 0.0, 0.6))
	if options.has("occluder_strength"):
		_material.set_shader_parameter("occluder_strength", clampf(float(options["occluder_strength"]), 0.0, 1.0))
	if options.has("cutaway"):
		_material.set_shader_parameter("cutaway", bool(options["cutaway"]))
	if options.has("cutaway_radius"):
		_material.set_shader_parameter("cutaway_radius", clampf(float(options["cutaway_radius"]), 12.0, 160.0))
	if options.has("focus_position"):
		_material.set_shader_parameter("focus_position", Vector2(options["focus_position"]))
	if options.has("layer_visibility"):
		layer_visibility = options["layer_visibility"]
		_material.set_shader_parameter("layer_visibility", layer_visibility)
	if options.has("freeze_material_animation"):
		_frozen_material_animation = bool(options["freeze_material_animation"])
		for surface: CyberDepthLayerSurface in _surfaces:
			surface.set_render_enabled(not _frozen_material_animation or surface.static_bake)

func screen_to_layer(local_position: Vector2, layer_index: int) -> Vector2:
	if layer_index < 0 or layer_index >= IDS.size():
		return Vector2(-1, -1)
	var rect: Rect2 = content_rect()
	if not rect.has_point(local_position):
		return Vector2(-1, -1)
	var logical: Vector2 = (local_position - rect.position) / rect.size * view_size
	var factor: float = layer_parallax[layer_index]
	var scale: float = layer_scale[layer_index]
	var anchor: Vector2 = world_size * 0.5
	var delta: Vector2 = camera_origin + view_size * 0.5 - anchor
	var effective_factor: float = 1.0 + (factor - 1.0) * parallax_strength
	return anchor + delta * effective_factor + (logical - view_size * 0.5) / scale

func get_layer_screen_position(world_position: Vector2, layer_index: int) -> Vector2:
	if layer_index < 0 or layer_index >= IDS.size():
		return Vector2(-1, -1)
	var factor: float = layer_parallax[layer_index]
	var scale: float = layer_scale[layer_index]
	var anchor: Vector2 = world_size * 0.5
	var delta: Vector2 = camera_origin + view_size * 0.5 - anchor
	var effective_factor: float = 1.0 + (factor - 1.0) * parallax_strength
	var logical: Vector2 = (world_position - anchor - delta * effective_factor) * scale + view_size * 0.5
	var rect := content_rect()
	return rect.position + logical / view_size * rect.size

func content_rect() -> Rect2:
	var target_aspect: float = view_size.x / view_size.y
	var available: Vector2 = size
	if available.x <= 0.0 or available.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var fitted := available
	if available.x / available.y > target_aspect:
		fitted.x = available.y * target_aspect
	else:
		fitted.y = available.x / target_aspect
	return Rect2((available - fitted) * 0.5, fitted)

func get_diagnostics() -> Dictionary:
	var layer_info: Dictionary = {}
	var uploads: int = 0
	var bytes: int = 0
	for index: int in range(IDS.size()):
		var diagnostic: Dictionary = _surfaces[index].diagnostics()
		layer_info[IDS[index]] = diagnostic
		uploads += int(diagnostic["upload_count"])
		bytes += int(diagnostic["uploaded_bytes"])
	return {
		"world_size": world_size,
		"camera_origin": camera_origin,
		"view_size": view_size,
		"layer_scale": layer_scale,
		"layer_parallax": layer_parallax,
		"layer_visibility": layer_visibility,
		"presentation_time": _presentation_time,
		"full_rg8_uploads": uploads,
		"full_rg8_uploaded_bytes": bytes,
		"layers": layer_info,
	}

func _ready() -> void:
	if not _configured:
		configure()

func _layout() -> void:
	if _output == null:
		return
	var rect := content_rect()
	_output.position = rect.position
	_output.size = rect.size

func _sync_uniforms() -> void:
	_material.set_shader_parameter("world_size", world_size)
	_material.set_shader_parameter("view_size", view_size)
	_material.set_shader_parameter("camera_origin", camera_origin)
	_material.set_shader_parameter("layer_scale", layer_scale)
	_material.set_shader_parameter("layer_parallax", layer_parallax)
	_material.set_shader_parameter("layer_visibility", layer_visibility)
	_material.set_shader_parameter("parallax_strength", parallax_strength)
	_material.set_shader_parameter("cell_texture_size", Vector2(1024, 1024))
	_material.set_shader_parameter("presentation_time", _presentation_time)
