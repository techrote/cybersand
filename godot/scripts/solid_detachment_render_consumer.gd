extends RefCounted

# SOL281-only CPU image reader. No Godot texture upload, no native World access.
# Caller may ACK only after consume() succeeds for the exact immutable serial.
const WIDTH: int = CyberCellWorld.WORLD_WIDTH
const HEIGHT: int = CyberCellWorld.WORLD_HEIGHT
const STRIDE: int = 6

var last_serial: int = 0
var world_generation: int = 0
var channels: int = 0
var consumed: int = 0
var refused: int = 0
var consumed_rectangles: int = 0
var consumed_bytes: int = 0
var last_error: String = ""
var _image: Image

func _refuse(message: String) -> bool:
	refused += 1
	last_error = message
	return false

func consume(snapshot: CyberSimulationSnapshot) -> bool:
	var serial: int = int(snapshot.render_snapshot_serial)
	var generation: int = int(snapshot.render_world_generation)
	var count: int = int(snapshot.render_channels)
	var full: bool = bool(snapshot.render_full_refresh)
	var rects: PackedInt32Array = snapshot.render_patch_rectangles
	var pixels: PackedByteArray = snapshot.render_patch_cells
	if serial <= last_serial or serial <= 0:
		return _refuse("non-increasing/zero render serial")
	if generation <= 0 or (count != 1 and count != 2):
		return _refuse("invalid generation or channel count")
	if (last_serial == 0 or generation != world_generation or count != channels) and not full:
		return _refuse("no full baseline for changed image/generation/channels")
	if rects.is_empty() or rects.size() % STRIDE != 0 or pixels.is_empty():
		return _refuse("missing or misaligned patch metadata/bytes")
	# Native full packet must replace the entire image, not just a fragment.
	if full and (rects.size() != STRIDE or rects[0] != 0 or rects[1] != 0
		or rects[2] != WIDTH or rects[3] != HEIGHT or rects[4] != 0
		or rects[5] != WIDTH * count or pixels.size() != WIDTH * HEIGHT * count):
		return _refuse("incomplete full-frame baseline")
	var image_format: Image.Format = Image.FORMAT_RG8 if count == 2 else Image.FORMAT_R8
	var patches: Array[Image] = []
	var destinations: Array[Vector2i] = []
	for i: int in range(0,rects.size(),STRIDE):
		var x: int = rects[i]
		var y: int = rects[i+1]
		var width: int = rects[i+2]
		var height: int = rects[i+3]
		var offset: int = rects[i+4]
		var pitch: int = rects[i+5]
		if (width <= 0 or height <= 0 or x < 0 or y < 0
			or width > WIDTH - x or height > HEIGHT - y):
			return _refuse("out-of-bounds/empty patch")
		var row_bytes: int = width * count
		if (offset < 0 or pitch < row_bytes or offset > pixels.size()
			or offset + (height - 1) * pitch + row_bytes > pixels.size()):
			return _refuse("invalid stride, offset or truncated patch")
		var compact: PackedByteArray
		if pitch == row_bytes:
			compact = pixels.slice(offset,offset + pitch * height)
		else:
			compact = PackedByteArray()
			compact.resize(row_bytes * height)
			for row: int in range(height):
				for j: int in range(row_bytes):
					compact[row * row_bytes + j] = pixels[offset + row * pitch + j]
		if compact.size() != row_bytes * height:
			return _refuse("compacted patch byte count mismatch")
		var patch: Image = Image.create_from_data(width,height,false,image_format,compact)
		if patch == null or patch.is_empty():
			return _refuse("Image.create_from_data rejected validated patch")
		patches.append(patch)
		destinations.append(Vector2i(x,y))
	# Stage every patch first; a failed packet cannot partially update the image.
	var target: Image = _image
	if full:
		target = Image.create(WIDTH,HEIGHT,false,image_format)
	if target == null or target.is_empty():
		return _refuse("image not initialized")
	for i: int in range(patches.size()):
		var patch: Image = patches[i]
		target.blit_rect(patch,Rect2i(Vector2i.ZERO,patch.get_size()),destinations[i])
	_image = target
	last_serial = serial
	world_generation = generation
	channels = count
	consumed += 1
	consumed_rectangles += patches.size()
	consumed_bytes += pixels.size()
	last_error = ""
	return true

func material_at(x: int,y: int) -> int:
	if _image == null or x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return -1
	var pixels: PackedByteArray = _image.get_data()
	return int(pixels[(y * WIDTH + x) * channels])

func metrics() -> Dictionary:
	return {"enabled":true,"consumed":consumed,"refused":refused,
		"rectangles":consumed_rectangles,"bytes":consumed_bytes,
		"last_serial":last_serial,"generation":world_generation,
		"channels":channels,"last_error":last_error}
