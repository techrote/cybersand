class_name CyberDepthLayerSurface
extends SubViewport

const Appearance = preload("res://scripts/material_appearance_lut.gd")
const NATIVE_SIZE: Vector2i = Vector2i(1024, 1024)
const MATERIAL_SURFACE_SIZE: Vector2i = Vector2i(640, 360)
const MAX_PATCHES: int = 4096
const MAX_PAYLOAD_BYTES: int = NATIVE_SIZE.x * NATIVE_SIZE.y * 2
const META_STRIDE: int = 6

var layer_id: String = ""
var reset_generation: int = -1
var layer_tick: int = 0
var last_serial: int = -1
var accepted_packets: int = 0
var rejected_packets: int = 0
var upload_count: int = 0
var uploaded_bytes: int = 0
var copied_patch_bytes: int = 0
var last_rejection: String = ""
var static_bake: bool = false
var material_surface_size: Vector2i = MATERIAL_SURFACE_SIZE
var render_enabled: bool = true
var bake_requests: int = 0
var _configured: bool = false

var cell_image: Image
var cell_texture: ImageTexture
var _material_rect: TextureRect
var _material: ShaderMaterial

func configure(id: String, frozen: bool = false, authored_size: Vector2i = MATERIAL_SURFACE_SIZE) -> bool:
	if (authored_size.x < 8 or authored_size.y < 8
			or authored_size.x > NATIVE_SIZE.x or authored_size.y > NATIVE_SIZE.y):
		return _reject("Material surface dimensions must be within 8..1024 cells on each axis")
	if _configured:
		return id == layer_id and frozen == static_bake and authored_size == material_surface_size
	_configured = true
	layer_id = id
	static_bake = frozen
	material_surface_size = authored_size
	# Each material plane needs its own canvas; inherited World2D would draw
	# every sibling plane into all four viewport textures.
	world_2d = World2D.new()
	size = material_surface_size
	transparent_bg = true
	render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	render_enabled = not static_bake
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if render_enabled else SubViewport.UPDATE_ONCE
	cell_image = Image.create(NATIVE_SIZE.x, NATIVE_SIZE.y, false, Image.FORMAT_RG8)
	cell_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	cell_texture = ImageTexture.create_from_image(cell_image)

	_material_rect = TextureRect.new()
	_material_rect.name = "MaterialSurface"
	_material_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_material_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_material_rect.position = Vector2.ZERO
	_material_rect.size = Vector2(material_surface_size)
	_material_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material_rect.texture = cell_texture
	_material_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_material_rect)

	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/material_palette.gdshader")
	_material_rect.material = _material
	_material.set_shader_parameter("world_size_px", Vector2(NATIVE_SIZE))
	_material.set_shader_parameter("view_size_px", Vector2(material_surface_size))
	_material.set_shader_parameter("view_rect_uv", Vector4(0.0, 0.0, 1.0, 1.0))
	_material.set_shader_parameter("camera_origin_px", Vector2.ZERO)
	_material.set_shader_parameter("player_origin_px", Vector2(-4096, -4096))
	_material.set_shader_parameter("player_size_px", Vector2.ZERO)
	_material.set_shader_parameter("rigid_body_data_0", Vector4(-4096, -4096, 0, 0))
	_material.set_shader_parameter("rigid_body_data_1", Vector4(-4096, -4096, 0, 0))
	_material.set_shader_parameter("rigid_body_data_2", Vector4(-4096, -4096, 0, 0))
	_material.set_shader_parameter("current_world_texture", cell_texture)
	_material.set_shader_parameter("previous_world_texture", cell_texture)
	_material.set_shader_parameter("condition_projection_enabled", 0.0)
	_material.set_shader_parameter("snapshot_blend", 1.0)
	_material.set_shader_parameter("material_lut", _transparent_empty_lut())
	_material.set_shader_parameter("material_program_lut", Appearance.create_program_texture())
	_material.set_shader_parameter("material_lut_size", Vector2(Appearance.ATLAS_WIDTH, Appearance.ATLAS_HEIGHT))
	return true

func set_source_texture(texture: Texture2D) -> void:
	_material_rect.texture = texture
	_material.set_shader_parameter("current_world_texture", texture)
	_material.set_shader_parameter("previous_world_texture", texture)

func apply_packet(packet: Dictionary) -> bool:
	var error: String = _validate_packet(packet)
	if not error.is_empty():
		return _reject(error)
	var rectangles: PackedInt32Array = packet["rectangles"]
	var cells: PackedByteArray = packet["cells"]
	var images: Array[Image] = []
	var locations: Array[Vector2i] = []
	var compacted_bytes: int = 0
	for offset: int in range(0, rectangles.size(), META_STRIDE):
		var width: int = rectangles[offset + 2]
		var height: int = rectangles[offset + 3]
		var data_offset: int = rectangles[offset + 4]
		var stride: int = rectangles[offset + 5]
		var row_bytes: int = width * 2
		var compact := PackedByteArray()
		if stride == row_bytes:
			compact = cells.slice(data_offset, data_offset + row_bytes * height)
		else:
			compact.resize(row_bytes * height)
			for row: int in range(height):
				for byte_index: int in range(row_bytes):
					compact[row * row_bytes + byte_index] = cells[data_offset + row * stride + byte_index]
		var patch: Image = Image.create_from_data(width, height, false, Image.FORMAT_RG8, compact)
		if patch == null or patch.is_empty():
			return _reject("Image construction rejected an otherwise bounded patch")
		images.append(patch)
		locations.append(Vector2i(rectangles[offset], rectangles[offset + 1]))
		compacted_bytes += compact.size()
	for index: int in range(images.size()):
		cell_image.blit_rect(
			images[index],
			Rect2i(Vector2i.ZERO, images[index].get_size()),
			locations[index]
		)
	if not images.is_empty():
		cell_texture.update(cell_image)
		set_source_texture(cell_texture)
		if not render_enabled: render_target_update_mode = SubViewport.UPDATE_ONCE
		upload_count += 1
		# ImageTexture.update uploads the complete backing image.
		uploaded_bytes += MAX_PAYLOAD_BYTES
		copied_patch_bytes += compacted_bytes
	var incoming_generation: int = int(packet["reset_generation"])
	if incoming_generation != reset_generation:
		last_serial = -1
	reset_generation = incoming_generation
	layer_tick = int(packet["layer_tick"])
	last_serial = maxi(last_serial, int(packet.get("serial", 0)))
	accepted_packets += 1
	last_rejection = ""
	if static_bake and not images.is_empty():
		bake_requests += 1
	return true

func set_render_enabled(enabled: bool) -> void:
	render_enabled = enabled and not static_bake
	# Pausing before the first draw must still bake the latest admitted packet.
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if render_enabled else SubViewport.UPDATE_ONCE

func diagnostics() -> Dictionary:
	return {
		"layer_id": layer_id,
		"reset_generation": reset_generation,
		"layer_tick": layer_tick,
		"accepted_packets": accepted_packets,
		"rejected_packets": rejected_packets,
		"upload_count": upload_count,
		"uploaded_bytes": uploaded_bytes,
		"copied_patch_bytes": copied_patch_bytes,
		"last_rejection": last_rejection,
		"native_texture_size": NATIVE_SIZE,
		"material_surface_size": size,
		"static_bake": static_bake,
		"render_enabled": render_enabled,
		"bake_requests": bake_requests,
		"viewport_update_mode": render_target_update_mode,
	}

func _validate_packet(packet: Dictionary) -> String:
	if bool(packet.get("failed", false)):
		return "native packet is failed"
	if str(packet.get("layer_id", "")) != layer_id:
		return "packet layer identity mismatch"
	if not packet.has("reset_generation") or typeof(packet["reset_generation"]) != TYPE_INT:
		return "packet reset generation is missing or non-integer"
	if not packet.has("layer_tick") or typeof(packet["layer_tick"]) != TYPE_INT:
		return "packet layer tick is missing or non-integer"
	if int(packet["reset_generation"]) < 0 or int(packet["layer_tick"]) < 0:
		return "packet generation/tick cannot be negative"
	if int(packet["reset_generation"]) < reset_generation:
		return "packet reset generation moved backwards"
	if int(packet.get("channels", 0)) != 2:
		return "depth surface requires RG8 packets"
	if not packet.has("serial") or typeof(packet["serial"]) != TYPE_INT:
		return "packet serial must be an integer"
	var serial: int = int(packet["serial"])
	if serial < 0:
		return "packet serial cannot be negative"
	if int(packet["reset_generation"]) == reset_generation and serial < last_serial:
		return "packet serial moved backwards"
	if not packet.get("rectangles") is PackedInt32Array or not packet.get("cells") is PackedByteArray:
		return "packet payload types are invalid"
	var rectangles: PackedInt32Array = packet["rectangles"]
	var cells: PackedByteArray = packet["cells"]
	if rectangles.size() % META_STRIDE != 0:
		return "patch metadata stride is malformed"
	if rectangles.size() / META_STRIDE > MAX_PATCHES:
		return "patch count exceeds bounded capacity"
	if cells.size() > MAX_PAYLOAD_BYTES:
		return "patch payload exceeds RG8 backing capacity"
	if rectangles.is_empty():
		if not cells.is_empty():
			return "payload bytes exist without rectangles"
		return ""
	if cells.is_empty():
		return "patch payload is empty"
	var staged_area: int = 0
	for offset: int in range(0, rectangles.size(), META_STRIDE):
		var x: int = rectangles[offset]
		var y: int = rectangles[offset + 1]
		var width: int = rectangles[offset + 2]
		var height: int = rectangles[offset + 3]
		var data_offset: int = rectangles[offset + 4]
		var stride: int = rectangles[offset + 5]
		if width <= 0 or height <= 0:
			return "patch dimensions must be positive"
		if x < 0 or y < 0 or x + width > NATIVE_SIZE.x or y + height > NATIVE_SIZE.y:
			return "patch rectangle exceeds native backing"
		if data_offset < 0 or stride < width * 2:
			return "patch payload offset/stride is invalid"
		var required_end: int = data_offset + (height - 1) * stride + width * 2
		if required_end > cells.size():
			return "patch requires payload bytes outside supplied buffer"
		staged_area += width * height
		if staged_area > NATIVE_SIZE.x * NATIVE_SIZE.y:
			return "cumulative staged patch area exceeds one backing image"
	if bool(packet.get("full_refresh", false)):
		if rectangles.size() != META_STRIDE:
			return "full refresh must contain exactly one rectangle"
		if rectangles[0] != 0 or rectangles[1] != 0 or rectangles[2] != NATIVE_SIZE.x or rectangles[3] != NATIVE_SIZE.y:
			return "full refresh does not cover the native backing"
	return ""

func _reject(error: String) -> bool:
	rejected_packets += 1
	last_rejection = error
	return false

func _transparent_empty_lut() -> ImageTexture:
	var source: ImageTexture = Appearance.create_texture()
	var image: Image = source.get_image()
	for x: int in range(Appearance.ATLAS_WIDTH):
		var colour: Color = image.get_pixel(x, 0)
		colour.a = 0.0
		image.set_pixel(x, 0, colour)
	return ImageTexture.create_from_image(image)
