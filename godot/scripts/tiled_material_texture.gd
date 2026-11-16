class_name CyberTiledMaterialTexture
extends Texture2D

# A finite material plane carried by at most 256 array layers. Godot 4.7's
# Compatibility backend submits update_layer as glTexSubImage3D(depth = 1),
# unlike ImageTexture.update's whole-plane glTexImage2D. No native handles,
# RenderingDevice-only API, GPU readback or per-update GPU allocation is used
# by the production publication path.
const MAX_LAYERS: int = 256
const MIN_TILE_SIDE: int = 64
const MAX_TILE_SIDE: int = 1024
const PATCH_STRIDE: int = 6

var layers: Texture2DArray
var tile_side: int = MIN_TILE_SIDE
var columns: int = 0
var rows: int = 0
var extent := Vector2i.ZERO
var image_format: Image.Format = Image.FORMAT_RG8
var channels: int = 2
var last_update: Dictionary = {}
# This tiny texture is solely the CanvasItem's drawing carrier. Material
# sampling uses layers, and diagnostics expose its separate actual array RID.
var _carrier: ImageTexture
# Exact per-slot bytes let an accumulated/resync patch skip unchanged layers.
# PackedByteArray copies retain value semantics; callers cannot mutate them.
var _tile_bytes: Array[PackedByteArray] = []


static func supported_driver() -> bool:
	return DisplayServer.get_name() != "headless" and \
		RenderingServer.get_current_rendering_driver_name() in ["opengl3", "opengl3_angle"]


static func create_from_material(source: Image) -> CyberTiledMaterialTexture:
	if source == null or source.is_empty() or source.has_mipmaps() \
			or source.get_format() not in [Image.FORMAT_R8, Image.FORMAT_RG8]:
		return null
	var result := CyberTiledMaterialTexture.new()
	result.extent = source.get_size()
	result.image_format = source.get_format()
	result.channels = 1 if source.get_format() == Image.FORMAT_R8 else 2
	while true:
		result.columns = ceili(float(result.extent.x) / result.tile_side)
		result.rows = ceili(float(result.extent.y) / result.tile_side)
		if result.columns * result.rows <= MAX_LAYERS: break
		result.tile_side *= 2
		if result.tile_side > MAX_TILE_SIDE: return null
	var images: Array[Image] = []
	for layer: int in range(result.columns * result.rows):
		var tile: Image = result._extract_tile(source, layer)
		if tile == null or tile.is_empty(): return null
		images.append(tile)
		result._tile_bytes.append(tile.get_data())
	result.layers = Texture2DArray.new()
	if result.layers.create_from_images(images) != OK or not result.layers.get_rid().is_valid():
		return null
	var carrier := Image.create(1, 1, false, Image.FORMAT_R8)
	result._carrier = ImageTexture.create_from_image(carrier)
	if result._carrier == null or not result._carrier.get_rid().is_valid(): return null
	return result


func _get_width() -> int:
	return extent.x


func _get_height() -> int:
	return extent.y


func _has_alpha() -> bool:
	return false


func _get_rid() -> RID:
	return _carrier.get_rid() if _carrier != null else RID()


func publication_rid() -> RID:
	return layers.get_rid() if layers != null else RID()


func _extract_tile(source: Image, layer: int) -> Image:
	var origin := Vector2i((layer % columns) * tile_side, (layer / columns) * tile_side)
	var size := Vector2i(mini(tile_side, extent.x - origin.x), mini(tile_side, extent.y - origin.y))
	var tile: Image = source.get_region(Rect2i(origin, size))
	if size != Vector2i(tile_side, tile_side):
		var padded := Image.create(tile_side, tile_side, false, image_format)
		padded.blit_rect(tile, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
		tile = padded
	return tile


# Diagnostic readback only. Reconstruct from the real GPU array, never from
# _tile_bytes or the authoritative CPU Image. Tests using get_image still
# verify what the shader samples. This synchronous operation is not gameplay.
func _get_image() -> Image:
	if layers == null or not layers.get_rid().is_valid(): return null
	var result := Image.create(extent.x, extent.y, false, image_format)
	for layer: int in range(columns * rows):
		var tile: Image = layers.get_layer_data(layer)
		if tile == null or tile.is_empty() or tile.get_format() != image_format: return null
		var origin := Vector2i((layer % columns) * tile_side, (layer / columns) * tile_side)
		var size := Vector2i(mini(tile_side, extent.x - origin.x), mini(tile_side, extent.y - origin.y))
		result.blit_rect(tile, Rect2i(Vector2i.ZERO, size), origin)
	return result


# Compatibility for explicit diagnostic callers that replace a whole image.
# Every layer is considered, but byte-identical layers need no GPU submission.
func update(source: Image) -> void:
	update_regions(source, PackedInt32Array())


func update_regions(source: Image, rectangles: PackedInt32Array) -> bool:
	last_update = {"mode":"tiled", "tile_side":tile_side,
		"tile_count":columns * rows, "candidate_layers":0, "updated_layers":0,
		"submitted_bytes":0, "tile_assembly_usec":0, "backend_submit_usec":0}
	if source == null or source.get_size() != extent or source.has_mipmaps() \
			or source.get_format() != image_format or layers == null \
			or not layers.get_rid().is_valid() or layers.get_layers() != columns * rows \
			or layers.get_width() != tile_side or layers.get_height() != tile_side \
			or layers.get_format() != image_format or layers.has_mipmaps() \
			or _tile_bytes.size() != columns * rows:
		last_update["failure"] = "invalid tiled resource or source shape"
		return false
	var started: int = Time.get_ticks_usec()
	var candidates := PackedByteArray()
	candidates.resize(columns * rows)
	if rectangles.is_empty():
		candidates.fill(1)
	else:
		if rectangles.size() % PATCH_STRIDE != 0: return false
		# Validate the complete region list before any resource mutation.
		for index: int in range(0, rectangles.size(), PATCH_STRIDE):
			var area := Rect2i(rectangles[index], rectangles[index + 1], rectangles[index + 2], rectangles[index + 3])
			if area.size.x <= 0 or area.size.y <= 0 or area.position.x < 0 or area.position.y < 0 \
					or area.end.x > extent.x or area.end.y > extent.y:
				return false
			var first := area.position / tile_side
			var last := (area.end - Vector2i.ONE) / tile_side
			for y: int in range(first.y, last.y + 1):
				for x: int in range(first.x, last.x + 1):
					candidates[y * columns + x] = 1
	var changed_layers := PackedInt32Array()
	var changed_images: Array[Image] = []
	var changed_bytes: Array[PackedByteArray] = []
	for layer: int in range(candidates.size()):
		if candidates[layer] == 0: continue
		last_update.candidate_layers += 1
		var tile: Image = _extract_tile(source, layer)
		if tile == null or tile.is_empty(): return false
		var bytes: PackedByteArray = tile.get_data()
		if tile.get_format() != image_format or tile.get_size() != Vector2i(tile_side, tile_side) \
				or tile.has_mipmaps() or bytes.size() != tile_side * tile_side * channels: return false
		if bytes == _tile_bytes[layer]: continue
		changed_layers.append(layer)
		changed_images.append(tile)
		changed_bytes.append(bytes)
	last_update.tile_assembly_usec = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for index: int in range(changed_layers.size()):
		# update_layer has no error return or GPU completion fence. All source,
		# layer and resource checks precede submission; arbitrary device loss is
		# not detectable here and is not claimed as a recoverable success.
		layers.update_layer(changed_images[index], changed_layers[index])
		_tile_bytes[changed_layers[index]] = changed_bytes[index]
	last_update.backend_submit_usec = Time.get_ticks_usec() - started
	last_update.updated_layers = changed_layers.size()
	last_update.submitted_bytes = changed_layers.size() * tile_side * tile_side * channels
	return true


static func bind_shader(shader: ShaderMaterial, current: Texture2D, previous: Texture2D = null) -> void:
	if shader == null: return
	var tiled: bool = current is CyberTiledMaterialTexture
	shader.set_shader_parameter("material_tiles_enabled", tiled)
	if not tiled:
		shader.set_shader_parameter("current_material_tiles", null)
		shader.set_shader_parameter("previous_material_tiles", null)
		return
	var plane := current as CyberTiledMaterialTexture
	shader.set_shader_parameter("current_material_tiles", plane.layers)
	shader.set_shader_parameter("material_tile_side", plane.tile_side)
	shader.set_shader_parameter("material_tile_columns", plane.columns)
	shader.set_shader_parameter("material_texture_size", Vector2(plane.extent))
	shader.set_shader_parameter("previous_material_tiles",
		(previous as CyberTiledMaterialTexture).layers if previous is CyberTiledMaterialTexture else plane.layers)
