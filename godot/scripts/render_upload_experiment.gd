extends RefCounted

## RENDER-UPLOAD-001 private experiment; ordinary ImageTexture remains default.
##
## Two complete DrawableTexture2D resources retain the same current/previous
## semantics as Main. Every accepted patch dirties BOTH slot journals. A reused
## slot is repaired from the complete CPU Image over ALL regions it has missed,
## not merely the newest native patch. Slot contents never become World authority.
##
## Godot 4.7's experimental drawable API returns void. `accepted` below means
## metadata/storage preflight passed and all commands were queued; it does NOT
## prove GPU completion. The graphical qualification/canary must establish exact
## sampled bytes on the selected backend before this experiment is admitted.

const COPY_SHADER = preload("res://shaders/render_upload_copy.gdshader")
const METADATA_STRIDE := 6
const MAX_JOURNAL_TILES := 4096
const MAX_PENDING_STAGING_BYTES := 128 * 1024 * 1024
const MAX_PENDING_BATCHES := 64

# Private research knobs; these are not product settings or measured optima.
var tile_size: int = 64
var full_area_fraction: float = 0.5
var maximum_partial_rectangles: int = 64

var current: Texture2D
var previous: Texture2D
var initialized: bool = false
var last_error: String = ""
var last_metrics: Dictionary = {}
var accepted_serial: int = 0
var accepted_generation: int = -1

var _size := Vector2i.ZERO
var _format: Image.Format = Image.FORMAT_RG8
var _channels: int = 2
var _grid := Vector2i.ZERO
var _slots: Array[DrawableTexture2D] = []
var _dirty_slots: Array[PackedByteArray] = []
var _slot_serials: Array[int] = []
var _current_slot: int = 0
var _copy_material: ShaderMaterial
var _staging_batches: Array[Array] = []
var _pending_staging_bytes: int = 0
var _batch_count: int = 0
var canary_result: Dictionary = {}


func initialize(image: Image, serial: int = 0, generation: int = -1) -> bool:
	last_error = _image_error(image, false)
	if not last_error.is_empty():
		return false
	if tile_size <= 0 or tile_size > 2048:
		last_error = "invalid experimental tile size"
		return false
	if full_area_fraction <= 0.0 or full_area_fraction > 1.0 or maximum_partial_rectangles < 1:
		last_error = "invalid experimental full-update threshold"
		return false
	var candidate_size := image.get_size()
	var candidate_grid := Vector2i(ceili(float(candidate_size.x) / tile_size),
		ceili(float(candidate_size.y) / tile_size))
	if candidate_grid.x * candidate_grid.y > MAX_JOURNAL_TILES:
		last_error = "world exceeds bounded experimental tile journal"
		return false
	canary_result = _check_canary()
	if not canary_result.get("passed", false):
		last_error = "drawable exact-byte startup canary failed: " + str(canary_result.get("error", "unknown"))
		return false
	var source: ImageTexture = ImageTexture.create_from_image(image)
	if source == null or not source.get_rid().is_valid():
		last_error = "initial staging texture allocation failed"
		return false
	var material := ShaderMaterial.new()
	material.shader = COPY_SHADER
	var candidates: Array[DrawableTexture2D] = []
	for slot: int in range(2):
		var target := DrawableTexture2D.new()
		target.setup(candidate_size.x, candidate_size.y,
			DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color(0, 0, 0, 1), false)
		if not target.get_rid().is_valid() or target.get_size() != Vector2(candidate_size):
			last_error = "drawable texture allocation failed"
			return false
		candidates.append(target)
	# All fallible application-side preflight precedes writes to either slot.
	for target: DrawableTexture2D in candidates:
		target.blit_rect(Rect2i(Vector2i.ZERO, candidate_size), source,
			Color.WHITE, 0, material)
	close()
	_size = candidate_size
	_grid = candidate_grid
	_format = image.get_format()
	_channels = 2 if _format == Image.FORMAT_RG8 else 1
	_slots = candidates
	_copy_material = material
	_dirty_slots = []
	_slot_serials = [serial, serial]
	for slot: int in range(2):
		var journal := PackedByteArray()
		journal.resize(_grid.x * _grid.y)
		journal.fill(0)
		_dirty_slots.append(journal)
	_current_slot = 0
	current = _slots[0]
	previous = _slots[1]
	accepted_serial = serial
	accepted_generation = generation
	initialized = true
	last_error = ""
	_retain_staging([source], _size.x * _size.y * _channels)
	if not RenderingServer.frame_post_draw.is_connected(_release_staging):
		RenderingServer.frame_post_draw.connect(_release_staging)
	last_metrics = {"initialization": true, "logical_staging_bytes": _size.x * _size.y * _channels,
		"destination_write_bytes": _size.x * _size.y * 4 * 2, "blit_count": 2,
		"resident_target_bytes": _size.x * _size.y * 4 * 2,
		"journal_bytes": _grid.x * _grid.y * 2, "completion_measured": false}
	return true


func publish(image: Image, rectangles: PackedInt32Array, serial: int,
		generation: int, full_refresh: bool) -> Dictionary:
	var start_usec := Time.get_ticks_usec()
	var reason := _publication_error(image, rectangles, serial, generation, full_refresh)
	if not reason.is_empty():
		return _refused(reason)
	# Transactional journal updates: a rejected publication cannot alter a slot,
	# a retained journal, accepted identity or current/previous bindings.
	var candidate_dirty: Array[PackedByteArray] = [
		_dirty_slots[0].duplicate(), _dirty_slots[1].duplicate()]
	for slot: int in range(2):
		if full_refresh:
			candidate_dirty[slot].fill(1)
		else:
			_mark_rectangles(candidate_dirty[slot], rectangles)
	var target_slot := 1 - _current_slot
	var plan := _plan(candidate_dirty[target_slot])
	var regions: Array[Rect2i] = plan.rectangles
	var staging_bytes: int = int(plan.area) * _channels
	if _pending_staging_bytes + staging_bytes > MAX_PENDING_STAGING_BYTES \
			or _batch_count >= MAX_PENDING_BATCHES:
		return _refused("experimental staging retention capacity exhausted before frame completion")
	var staging: Array[ImageTexture] = []
	var prepare_start_usec := Time.get_ticks_usec()
	var extraction_usec := 0
	var source_create_usec := 0
	for region: Rect2i in regions:
		var extraction_start_usec := Time.get_ticks_usec()
		var patch: Image = image.get_region(region)
		extraction_usec += Time.get_ticks_usec() - extraction_start_usec
		if patch == null or patch.is_empty() or patch.get_size() != region.size \
				or patch.get_format() != _format:
			return _refused("experimental patch extraction failed")
		var source_start_usec := Time.get_ticks_usec()
		var source := ImageTexture.create_from_image(patch)
		source_create_usec += Time.get_ticks_usec() - source_start_usec
		if source == null or not source.get_rid().is_valid():
			return _refused("experimental patch staging allocation failed")
		staging.append(source)
	var prepared_usec := Time.get_ticks_usec()
	var old_target_serial := _slot_serials[target_slot]
	var target: DrawableTexture2D = _slots[target_slot]
	for index: int in range(regions.size()):
		target.blit_rect(regions[index], staging[index], Color.WHITE, 0, _copy_material)
	var submitted_usec := Time.get_ticks_usec()
	_retain_staging(staging, staging_bytes)
	candidate_dirty[target_slot].fill(0)
	_dirty_slots = candidate_dirty
	_slot_serials[target_slot] = serial
	previous = _slots[_current_slot]
	_current_slot = target_slot
	current = target
	accepted_serial = serial
	accepted_generation = generation
	last_error = ""
	last_metrics = {"initialization": false, "mode": "full_blit" if plan.full else "partial_blit",
		"full_reason": plan.reason, "blit_count": regions.size(), "dirty_tiles": plan.dirty_tiles,
		"dirty_area": plan.dirty_area, "submitted_area": plan.area,
		"logical_staging_bytes": staging_bytes, "destination_write_bytes": int(plan.area) * 4,
		"equivalent_full_image_bytes": _size.x * _size.y * _channels,
		"prepare_usec": prepared_usec - prepare_start_usec,
		"extraction_usec": extraction_usec, "source_create_usec": source_create_usec,
		"blit_submit_usec": submitted_usec - prepared_usec,
		"journal_and_validation_usec": prepare_start_usec - start_usec,
		"total_usec": Time.get_ticks_usec() - start_usec,
		"previous_target_serial": old_target_serial, "target_serial": serial,
		"current_slot": target_slot, "resident_target_bytes": _size.x * _size.y * 8,
		"pending_staging_bytes": _pending_staging_bytes, "journal_bytes": _grid.x * _grid.y * 2,
		"completion_measured": false}
	return {"accepted": true, "current": current, "previous": previous,
		"metrics": last_metrics.duplicate(true), "error": ""}


func _check_canary() -> Dictionary:
	# Startup/reinitialization only. The readback deliberately synchronizes once;
	# normal publication never reads back a complete GPU texture.
	var start_usec := Time.get_ticks_usec()
	var bytes := PackedByteArray([0, 255, 255, 0, 1, 127, 128, 254])
	var input := Image.create_from_data(2, 2, false, Image.FORMAT_RG8, bytes)
	var source := ImageTexture.create_from_image(input)
	var target := DrawableTexture2D.new()
	target.setup(2, 2, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color(0, 0, 0, 1), false)
	var material := ShaderMaterial.new()
	material.shader = COPY_SHADER
	target.blit_rect(Rect2i(0, 0, 2, 2), source, Color.WHITE, 0, material)
	var result: Image = target.get_image()
	if result == null or result.is_empty() or result.get_size() != Vector2i(2, 2):
		return {"passed": false, "error": "readback unavailable"}
	result.convert(Image.FORMAT_RGBA8)
	var output := result.get_data()
	for pixel: int in range(4):
		if output[pixel * 4] != bytes[pixel * 2] or output[pixel * 4 + 1] != bytes[pixel * 2 + 1] \
				or output[pixel * 4 + 2] != 0 or output[pixel * 4 + 3] != 255:
			return {"passed": false, "error": "normalized material bytes changed", "pixel": pixel}
	return {"passed": true, "readback_usec": Time.get_ticks_usec() - start_usec,
		"scope": "startup RG8-to-linear-RGBA8 copy; no per-publication completion claim"}


func _publication_error(image: Image, rectangles: PackedInt32Array, serial: int,
		generation: int, full_refresh: bool) -> String:
	if not initialized:
		return "experimental textures are not initialized"
	var image_reason := _image_error(image, true)
	if not image_reason.is_empty():
		return image_reason
	if serial <= accepted_serial:
		return "experimental publication serial is stale or repeated"
	if generation < accepted_generation:
		return "experimental World generation is stale"
	if rectangles.is_empty() or rectangles.size() % METADATA_STRIDE != 0:
		return "experimental patch metadata is empty or malformed"
	var contains_full_rect := false
	for offset: int in range(0, rectangles.size(), METADATA_STRIDE):
		var rect := Rect2i(rectangles[offset], rectangles[offset + 1],
			rectangles[offset + 2], rectangles[offset + 3])
		if rect.size.x <= 0 or rect.size.y <= 0 or rect.position.x < 0 or rect.position.y < 0 \
				or rect.size.x > _size.x or rect.size.y > _size.y \
				or rect.position.x > _size.x - rect.size.x or rect.position.y > _size.y - rect.size.y:
			return "experimental patch rectangle exceeds the complete CPU image"
		if rect.position == Vector2i.ZERO and rect.size == _size:
			contains_full_rect = true
	if full_refresh and not contains_full_rect:
		return "experimental full refresh lacks complete-image coverage"
	if generation != accepted_generation and not (full_refresh and contains_full_rect):
		return "experimental World replacement requires a complete full refresh"
	return ""


func _image_error(image: Image, check_shape: bool) -> String:
	if image == null or image.is_empty() or image.has_mipmaps():
		return "experimental source must be a nonempty image without mipmaps"
	if image.get_format() != Image.FORMAT_R8 and image.get_format() != Image.FORMAT_RG8:
		return "experimental source must preserve R8 or RG8 material bytes"
	if check_shape and (image.get_size() != _size or image.get_format() != _format):
		return "experimental source dimensions/format changed without reinitialization"
	return ""


func _mark_rectangles(journal: PackedByteArray, rectangles: PackedInt32Array) -> void:
	for offset: int in range(0, rectangles.size(), METADATA_STRIDE):
		var first := Vector2i(rectangles[offset] / tile_size, rectangles[offset + 1] / tile_size)
		var last := Vector2i((rectangles[offset] + rectangles[offset + 2] - 1) / tile_size,
			(rectangles[offset + 1] + rectangles[offset + 3] - 1) / tile_size)
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				journal[y * _grid.x + x] = 1


func _plan(journal: PackedByteArray) -> Dictionary:
	var rectangles: Array[Rect2i] = []
	var dirty_area := 0
	var dirty_tiles := 0
	# Merge touching tiles into row runs, then identical runs in consecutive rows.
	# This is bounded by MAX_JOURNAL_TILES and never scans material cells.
	var previous_runs: Dictionary = {}
	for y: int in range(_grid.y):
		var current_runs: Dictionary = {}
		var x := 0
		while x < _grid.x:
			if journal[y * _grid.x + x] == 0:
				x += 1
				continue
			var begin := x
			while x < _grid.x and journal[y * _grid.x + x] != 0:
				dirty_tiles += 1
				x += 1
			var left := begin * tile_size
			var right := mini(x * tile_size, _size.x)
			var top := y * tile_size
			var height := mini(tile_size, _size.y - top)
			dirty_area += (right - left) * height
			var key := Vector2i(begin, x)
			if previous_runs.has(key):
				var index: int = previous_runs[key]
				var extended: Rect2i = rectangles[index]
				extended.size.y += height
				rectangles[index] = extended
				current_runs[key] = index
			else:
				current_runs[key] = rectangles.size()
				rectangles.append(Rect2i(left, top, right - left, height))
		previous_runs = current_runs
	var full := false
	var reason := ""
	if dirty_area >= ceili(_size.x * _size.y * full_area_fraction):
		full = true
		reason = "dirty_area"
	elif rectangles.size() > maximum_partial_rectangles:
		full = true
		reason = "fragmentation"
	var area := dirty_area
	if full:
		rectangles = [Rect2i(Vector2i.ZERO, _size)]
		area = _size.x * _size.y
	return {"rectangles": rectangles, "area": area, "dirty_area": dirty_area,
		"dirty_tiles": dirty_tiles, "full": full, "reason": reason}


func _retain_staging(textures: Array, bytes: int) -> void:
	# Do not reuse a source texture while a preceding blit may still reference it.
	_staging_batches.append(textures)
	_pending_staging_bytes += bytes
	_batch_count += 1


func _release_staging() -> void:
	_staging_batches.clear()
	_pending_staging_bytes = 0
	_batch_count = 0


func _refused(reason: String) -> Dictionary:
	last_error = reason
	return {"accepted": false, "current": current, "previous": previous,
		"metrics": {}, "error": reason}


func close() -> void:
	if RenderingServer.frame_post_draw.is_connected(_release_staging):
		RenderingServer.frame_post_draw.disconnect(_release_staging)
	_release_staging()
	_slots.clear()
	_dirty_slots.clear()
	_slot_serials.clear()
	_copy_material = null
	current = null
	previous = null
	initialized = false
