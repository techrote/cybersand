extends RefCounted

## Deterministic, bounded raster-to-material proposal compiler. It has no World
## and performs no native writes. PNG bytes remain unchanged; alpha is an edit
## mask, not inferred depth or physical material. Work is stepped by the host.
const Module = preload("res://scripts/depth/strata_native_module.gd")
const MAX_PNG_BYTES := 16 * 1024 * 1024
const MAX_SOURCE_SIDE := 2048
const MAX_CROP_SIDE := 512
const MAX_OUTPUT_CELLS := 262144
const STEP_PIXELS := 4096
const OPTION_KEYS := ["crop", "origin", "scale", "transform", "alpha_mode", "alpha_threshold", "palette", "color_distance", "unmapped"]

var status := "idle"
var _source: Image
var _mask: Image
var _options: Dictionary = {}
var _admitted := PackedInt32Array()
var _cells := PackedByteArray()
var _write_mask := PackedByteArray()
var _preview: Image
var _size := Vector2i.ZERO
var _crop := Rect2i()
var _cursor := 0
var _counts: Dictionary = {}
var _unknown: Dictionary = {}
var _source_sha := ""
var _mask_sha := ""
var _decoded_sha := ""
var _decoded_mask_sha := ""
var _result: Dictionary = {}


static func _big_u32(bytes: PackedByteArray, offset: int) -> int:
	return (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) | (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3])


static func inspect_png(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 33 or bytes.size() > MAX_PNG_BYTES: return Module.failure("PNG input must contain 33 bytes–16 MiB.")
	if bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]) or bytes.slice(12, 16).get_string_from_ascii() != "IHDR": return Module.failure("The selected source is not a supported PNG.")
	var width := _big_u32(bytes, 16)
	var height := _big_u32(bytes, 20)
	if width < 1 or height < 1 or width > MAX_SOURCE_SIDE or height > MAX_SOURCE_SIDE: return Module.failure("PNG source dimensions must be 1–2048 pixels per side; refusal precedes decompression.")
	var offset := 8
	var saw_end := false
	while offset + 12 <= bytes.size():
		var length := _big_u32(bytes, offset)
		if length > MAX_PNG_BYTES or offset + length + 12 > bytes.size(): return Module.failure("Truncated or oversized PNG chunk.")
		var kind := bytes.slice(offset + 4, offset + 8).get_string_from_ascii()
		if kind == "acTL": return Module.failure("Animated PNG is not an authored material image; export one explicitly selected frame first.")
		offset += length + 12
		if kind == "IEND":
			saw_end = true
			break
	if not saw_end or offset != bytes.size(): return Module.failure("PNG must contain one complete image without trailing payload.")
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK or image.get_width() != width or image.get_height() != height: return Module.failure("PNG decoder refused the declared image.")
	image.convert(Image.FORMAT_RGBA8)
	return {"ok": true, "kind": "png", "extent": [width, height], "source_image": image,
		"source_sha256": Module.digest(bytes), "decoded_rgba_sha256": Module.digest(image.get_data()),
		"summary": "PNG decoded to RGBA8; no native authority or automatic layer assignment.", "error": ""}


static func inspect_source(path: String, admitted: PackedInt32Array) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return Module.failure("Could not open the selected local source.")
	var limit := MAX_PNG_BYTES if path.get_extension().to_lower() == "png" else Module.MAX_BYTES
	if file.get_length() < 1 or file.get_length() > limit: return Module.failure("Selected source exceeds its PNG/native-JSON byte budget.")
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if path.get_extension().to_lower() == "png": return inspect_png(bytes)
	if path.get_extension().to_lower() != "json": return Module.failure("Choose a PNG or a supported native module JSON file.")
	var read := Module.read_json(bytes, admitted)
	if not read.ok: return read
	read.kind = "native_module"
	read.extent = read.module.extent.duplicate()
	read.source_sha256 = Module.digest(bytes)
	read.summary = "Proposed native material IDs and explicit no-write mask; imported provenance remains historical."
	read.source_image = module_image(read.module, admitted)
	return read


static func defaults(extent: Vector2i, palette: Array) -> Dictionary:
	return {"crop": [0, 0, extent.x, extent.y], "origin": [32, 32], "scale": 1, "transform": "identity",
		"alpha_mode": "overlay", "alpha_threshold": 128, "palette": palette.duplicate(true),
		"color_distance": 0, "unmapped": "refuse"}


static func _colour(material: int) -> Color:
	# This is a labelled proposal key, not the native production material shader.
	if material == 0: return Color(0.85, 0.25, 0.35, 0.75)
	return Color.from_hsv(fmod(float(material) * 0.61803398875, 1.0), 0.45, 0.90, 1.0)


static func module_image(module: Dictionary, admitted: PackedInt32Array) -> Image:
	var checked := Module.validate(module, admitted)
	if not checked.ok: return null
	var size: Vector2i = checked.extent
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for i: int in size.x * size.y:
		if checked.mask[i] == 1: image.set_pixel(i % size.x, i / size.x, _colour(checked.cells.decode_u16(i * 2)))
	return image


func begin_png(bytes: PackedByteArray, options: Dictionary, admitted: PackedInt32Array, mask_bytes: PackedByteArray = PackedByteArray()) -> Dictionary:
	if status == "preparing": return Module.failure("Finish or cancel the current raster preparation.")
	_result = {}
	_source = null
	_mask = null
	_preview = null
	_options = {}
	_admitted = PackedInt32Array()
	_cells = PackedByteArray()
	_write_mask = PackedByteArray()
	_size = Vector2i.ZERO
	_crop = Rect2i()
	_cursor = 0
	_counts = {}
	_unknown = {}
	_source_sha = ""
	_mask_sha = ""
	_decoded_sha = ""
	_decoded_mask_sha = ""
	status = "refused"
	var inspected := inspect_png(bytes)
	if not inspected.ok: return _fail(inspected.error)
	if not Module.keys(options, OPTION_KEYS): return _fail("Raster import requires the complete known mapping controls.")
	_crop = Module.rectangle(options.crop)
	var source_extent := Vector2i(int(inspected.extent[0]), int(inspected.extent[1]))
	if _crop.size.x < 1 or _crop.size.y < 1 or _crop.size.x > MAX_CROP_SIDE or _crop.size.y > MAX_CROP_SIDE or not Rect2i(Vector2i.ZERO, source_extent).encloses(_crop): return _fail("Choose an explicit in-source crop of at most 512 × 512 pixels.")
	if not Module.pair(options.origin, 0, 2047) or not Module.integer(options.scale, 1, 4) or options.transform not in Module.TRANSFORMS: return _fail("Choose an integer origin, scale 1–4 and exact orthogonal transform.")
	_size = Module.transformed_size(_crop.size, str(options.transform)) * int(options.scale)
	if _size.x * _size.y > MAX_OUTPUT_CELLS or _size.x > 2048 or _size.y > 2048: return _fail("The explicit nearest-neighbour output exceeds 262144 cells or the admitted side limit.")
	if options.alpha_mode not in ["overlay", "replace"] or not Module.integer(options.alpha_threshold, 1, 255) or options.unmapped not in ["refuse", "skip"] or not Module.integer(options.color_distance, 0, 442): return _fail("Invalid alpha, unknown-colour or RGB-distance policy.")
	if not options.palette is Array or options.palette.is_empty() or options.palette.size() > 32 or admitted.is_empty(): return _fail("Supply 1–32 explicit RGB-to-native-material palette rows.")
	var colours: Dictionary = {}
	for row: Variant in options.palette:
		if not Module.keys(row, ["rgb", "material", "role"]) or not row.rgb is Array or row.rgb.size() != 3 or not Module.integer(row.material, 0, 255) or int(row.material) not in admitted or not row.role is String or row.role.length() > 64: return _fail("Invalid palette row or material not admitted by the current native runtime.")
		for channel: Variant in row.rgb:
			if not Module.integer(channel, 0, 255): return _fail("Palette RGB channels must be exact bytes.")
		var key := int(row.rgb[0]) * 65536 + int(row.rgb[1]) * 256 + int(row.rgb[2])
		if colours.has(key): return _fail("Repeated palette RGB entries are ambiguous.")
		colours[key] = true
	_source = inspected.source_image
	_source_sha = inspected.source_sha256
	_decoded_sha = inspected.decoded_rgba_sha256
	_mask = null
	_mask_sha = ""
	if not mask_bytes.is_empty():
		var mask := inspect_png(mask_bytes)
		if not mask.ok: return _fail("Mask: " + str(mask.error))
		if mask.extent != inspected.extent: return _fail("An explicit mask must have the exact source resolution; masks are never silently resampled.")
		_mask = mask.source_image
		_mask_sha = mask.source_sha256
		_decoded_mask_sha = mask.decoded_rgba_sha256
	_options = Module.canonical(options)
	_admitted = admitted.duplicate()
	_cells = PackedByteArray()
	_cells.resize(_size.x * _size.y * 2)
	_write_mask = PackedByteArray()
	_write_mask.resize(_size.x * _size.y)
	_preview = Image.create(_size.x, _size.y, false, Image.FORMAT_RGBA8)
	_preview.fill(Color.TRANSPARENT)
	_cursor = 0
	_counts = {"mapped": 0, "no_write": 0, "unmapped": 0, "explicit_empty": 0, "alpha_skipped": 0, "mask_skipped": 0, "source_pixels": _crop.get_area(), "output_cells": _size.x * _size.y}
	_unknown = {}
	status = "preparing"
	return state()


func _fail(message: String) -> Dictionary:
	status = "refused"
	_result = Module.failure(message)
	_result.status = status
	return state()


func cancel() -> Dictionary:
	if status == "preparing":
		status = "cancelled"
		_result = {"ok": false, "status": status, "error": "Raster preparation cancelled; no native writes occurred."}
	return state()


func _map(colour: Color) -> int:
	var best := 2147483647
	var material := -1
	for row: Dictionary in _options.palette:
		var dr := colour.r8 - int(row.rgb[0])
		var dg := colour.g8 - int(row.rgb[1])
		var db := colour.b8 - int(row.rgb[2])
		var distance := dr * dr + dg * dg + db * db
		# Exact ties retain the earlier explicit palette row.
		if distance < best:
			best = distance
			material = int(row.material)
	return material if best <= int(_options.color_distance) * int(_options.color_distance) else -1


func step(max_pixels: int = STEP_PIXELS) -> Dictionary:
	if status != "preparing": return state()
	if max_pixels < 1 or max_pixels > STEP_PIXELS: return _fail("Raster preparation steps admit 1–4096 source pixels.")
	var stop := mini(_crop.get_area(), _cursor + max_pixels)
	var scale_value := int(_options.scale)
	var copies := scale_value * scale_value
	while _cursor < stop:
		var local := Vector2i(_cursor % _crop.size.x, _cursor / _crop.size.x)
		var source_point := _crop.position + local
		var colour := _source.get_pixelv(source_point)
		var material := -1
		var masked := false
		if _mask != null:
			var mask_colour := _mask.get_pixelv(source_point)
			masked = mask_colour.a8 == 0 or mask_colour.r8 + mask_colour.g8 + mask_colour.b8 < 384
		if masked:
			_counts.mask_skipped += copies
		elif colour.a8 == 0 or colour.a8 < int(_options.alpha_threshold):
			_counts.alpha_skipped += copies
			if _options.alpha_mode == "replace": material = 0
		else:
			material = _map(colour)
			if material < 0:
				_counts.unmapped += copies
				var rgb_key := "%02x%02x%02x" % [colour.r8, colour.g8, colour.b8]
				if _unknown.has(rgb_key) or _unknown.size() < 32: _unknown[rgb_key] = int(_unknown.get(rgb_key, 0)) + copies
		var transformed := Module.transform_point(local, _crop.size, str(_options.transform)) * scale_value
		for sy: int in scale_value:
			for sx: int in scale_value:
				var point := transformed + Vector2i(sx, sy)
				var index := point.y * _size.x + point.x
				if material >= 0:
					_cells.encode_u16(index * 2, material)
					_write_mask[index] = 1
					_preview.set_pixelv(point, _colour(material))
					_counts.mapped += 1
					if material == 0: _counts.explicit_empty += 1
				else: _counts.no_write += 1
		_cursor += 1
	if _cursor == _crop.get_area(): return _finish()
	return state()


func _finish() -> Dictionary:
	if Module.digest(_source.get_data()) != _decoded_sha or (_mask != null and Module.digest(_mask.get_data()) != _decoded_mask_sha): return _fail("The inspected image or mask changed during preparation; choose Preview again from the original source bytes.")
	var provenance := {"source_kind": "raster-proposal", "source_sha256": _source_sha,
		"source_extent": [_source.get_width(), _source.get_height()], "decoded_rgba_sha256": _decoded_sha,
		"mask_sha256": _mask_sha, "mask_policy": "nonzero alpha and RGB mean at least128; excluded mask pixels always no-write",
		"options": _options.duplicate(true), "mapping_sha256": Module.digest(Module.json_bytes(_options)),
		"sampling": "RGBA8 source pixels; crop then exact orthogonal transform then nearest-neighbour integer replication",
		"colour_distance": "Euclidean RGB bytes; equal-distance ties use earlier palette row",
		"counts": _counts.duplicate(true), "counts_domain": "output grid cells except source_pixels", "unknown_rgb_first32": _unknown.duplicate(true),
		"scope": "Proposed material mapping; native application and actual target readback require separate owner approval."}
	var built := Module.create("raster-" + _source_sha.left(16), "Raster import " + _source_sha.left(8), _size, _cells, _write_mask, provenance, _admitted)
	# The new masked Strata interchange preserves wide integer-grid outputs;
	# the separately owned #770 format retains its original512-side reader limit.
	if not built.ok: return _fail(str(built.error))
	_result = built
	_result.provenance = provenance
	_result.geometry_sha256 = built.module.geometry.sha256
	_result.mapping_sha256 = provenance.mapping_sha256
	if int(_counts.unmapped) > 0 and _options.unmapped == "refuse":
		status = "refused"
		_result.ok = false
		_result.error = "Unmapped opaque pixels remain. Add palette rows, choose a declared distance, or explicitly choose Skip unmapped."
	else: status = "ready"
	return state()


func state() -> Dictionary:
	var result := _result.duplicate(true)
	result.status = status
	result.ok = status in ["preparing", "ready"]
	result.busy = status == "preparing"
	result.cancellable = result.busy
	result.can_approve = false # A native-source/revision preview is still required.
	result.processed = _cursor
	result.total = _crop.get_area()
	result.counts = _counts.duplicate(true)
	for key: String in _counts: result[key] = _counts[key]
	result.source_sha256 = _source_sha
	result.source_image = _source
	result.mask_image = _mask
	result.output_image = _preview
	result.extent = [_size.x, _size.y]
	result.options = _options.duplicate(true)
	result.zero_writes = true
	result.preview_kind = "material-ID proposal colours; not native production appearance"
	return result
