extends RefCounted

## Opt-in RENDER-UPLOAD-577 publication, never native material authority.
## Dense/full submissions use the ordinary compact R8/RG8 ImageTexture pair.
## Only sustained sparse work enters the independently journalled drawable pair.
## Each sparse entry seeds each destination at most once from the complete
## accepted current texture, then applies current CPU-image regions. Seed costs
## are explicit; they are not claimed to be partial GPU writes.
##
## Public Godot calls return void. Acceptance means validated commands submitted,
## not GPU completion or scanout. The startup canary and graphical tests establish
## the byte contract on the actual backend; normal publication never reads back.

const COPY_SHADER = preload("res://shaders/material_upload_copy.gdshader")
const METADATA_STRIDE := 6
const TILE_SIZE := 64
const MAX_JOURNAL_TILES := 4096
const MAX_SPARSE_RECTANGLES := 8
const SPARSE_AREA_DIVISOR := 16
const SPARSE_ENTRY_PUBLICATIONS := 4
const MAX_PENDING_STAGING_BYTES := 16 * 1024 * 1024
const MAX_PENDING_BATCHES := 32
const MAX_POOLED_STAGING_BYTES := 2 * 1024 * 1024
const MAX_POOLED_STAGING_TEXTURES := 16
const STAGING_RETIRE_DRAW_BOUNDARIES := 3

var current: Texture2D
var previous: Texture2D
var initialized := false
var last_error := ""
var last_metrics: Dictionary = {}
var canary_result: Dictionary = {}
var accepted_serial := 0
var accepted_generation := -1

var _size := Vector2i.ZERO
var _format: Image.Format = Image.FORMAT_RG8
var _channels := 2
var _grid := Vector2i.ZERO
var _compact: Array[ImageTexture] = []
var _drawables: Array[DrawableTexture2D] = []
var _dirty_slots: Array[PackedByteArray] = []
var _slot_serials: Array[int] = []
var _seed_pending: Array[bool] = [true, true]
var _compact_slot := 0
var _drawable_slot := 1
var _sparse_streak := 0
var _sparse_mode := false
var _copy_material: ShaderMaterial
var _staging_batches: Array[Dictionary] = []
var _pending_staging_bytes := 0
var _source_pool: Array[ImageTexture] = []
var _pooled_bytes := 0
var _completed_draw_boundaries := 0
var _seed_blits_total := 0
var _compact_publications_total := 0
var _partial_publications_total := 0
var _texture_allocations_total := 0


func initialize(image: Image, serial: int = 0, generation: int = -1,
		accepted_current: Texture2D = null, accepted_previous: Texture2D = null) -> bool:
	last_error = _image_error(image, false)
	if not last_error.is_empty():
		return false
	var candidate_size := image.get_size()
	if (accepted_current == null) != (accepted_previous == null):
		last_error = "material upload history adoption requires both accepted textures"
		return false
	if accepted_current != null:
		if not accepted_current.get_rid().is_valid() or not accepted_previous.get_rid().is_valid() \
				or accepted_current.get_size() != Vector2(candidate_size) \
				or accepted_previous.get_size() != Vector2(candidate_size):
			last_error = "material upload adopted history has incompatible dimensions/resources"
			return false
	var candidate_grid := Vector2i(ceili(float(candidate_size.x) / TILE_SIZE),
		ceili(float(candidate_size.y) / TILE_SIZE))
	if candidate_grid.x * candidate_grid.y > MAX_JOURNAL_TILES:
		last_error = "material upload exceeds bounded tile journal"
		return false
	var canary := _check_canary()
	if not canary.get("passed", false):
		last_error = "material upload exact-byte canary failed: " + str(canary.get("error", "unknown"))
		return false
	var candidates: Array[ImageTexture] = []
	for slot: int in range(2):
		var target := ImageTexture.create_from_image(image)
		if target == null or not target.get_rid().is_valid():
			last_error = "compact material texture allocation failed"
			return false
		candidates.append(target)
	close()
	_size = candidate_size
	_grid = candidate_grid
	_format = image.get_format()
	_channels = 2 if _format == Image.FORMAT_RG8 else 1
	_compact = candidates
	_compact_slot = 0
	_drawable_slot = 1
	_copy_material = ShaderMaterial.new()
	_copy_material.shader = COPY_SHADER
	_slot_serials = [serial, serial]
	for slot: int in range(2):
		var journal := PackedByteArray()
		journal.resize(_grid.x * _grid.y)
		journal.fill(1)
		_dirty_slots.append(journal)
	_seed_pending = [true, true]
	_sparse_reset()
	# External accepted history is read-only. Our new compact destinations cannot
	# alias it, and the first publication preserves accepted_current as previous.
	current = _compact[0] if accepted_current == null else accepted_current
	previous = _compact[1] if accepted_previous == null else accepted_previous
	accepted_serial = serial
	accepted_generation = generation
	initialized = true
	canary_result = canary
	_texture_allocations_total = 2
	last_error = ""
	if not RenderingServer.frame_post_draw.is_connected(_release_staging):
		RenderingServer.frame_post_draw.connect(_release_staging)
	last_metrics = {"initialization": true, "mode": "compact_initialization",
		"logical_staging_bytes": _full_bytes() * 2, "destination_write_bytes": _full_bytes() * 2,
		"blit_count": 0, "seed_blit_count": 0, "texture_allocations": 2,
		"resident_target_bytes": _resident_bytes(), "completion_measured": false}
	last_metrics.merge(_staging_metrics(), true)
	return true


func publish(image: Image, rectangles: PackedInt32Array, serial: int,
		generation: int, full_refresh: bool) -> Dictionary:
	var start_usec := Time.get_ticks_usec()
	var reason := _publication_error(image, rectangles, serial, generation, full_refresh)
	if not reason.is_empty():
		return _refused(reason)
	var candidate_dirty: Array[PackedByteArray] = [
		_dirty_slots[0].duplicate(), _dirty_slots[1].duplicate()]
	var latest := PackedByteArray()
	latest.resize(_grid.x * _grid.y)
	if full_refresh:
		latest.fill(1)
	else:
		_mark_rectangles(latest, rectangles)
	for slot: int in range(2):
		for tile: int in range(latest.size()):
			if latest[tile] != 0:
				candidate_dirty[slot][tile] = 1
	var latest_plan := _plan(latest)
	var compact_reason := ""
	var next_streak := _sparse_streak + 1
	if full_refresh:
		compact_reason = "explicit_full_refresh"
	elif not latest_plan.sparse:
		compact_reason = "latest_" + str(latest_plan.reason)
	elif not _sparse_mode and next_streak < SPARSE_ENTRY_PUBLICATIONS:
		compact_reason = "sparse_entry_dwell"
	if not compact_reason.is_empty():
		return _publish_compact(image, candidate_dirty, latest_plan, serial, generation,
			compact_reason, next_streak if compact_reason == "sparse_entry_dwell" else 0, start_usec)
	var target_slot := 1 - _drawable_slot
	var seed := _seed_pending[target_slot]
	# A seed copies complete accepted current history, so only the newest changes
	# must be applied. Otherwise repair ALL changes the reused target has missed.
	var plan := latest_plan if seed else _plan(candidate_dirty[target_slot])
	if not plan.sparse:
		return _publish_compact(image, candidate_dirty, latest_plan, serial, generation,
			"history_" + str(plan.reason), 0, start_usec)
	var staging_bytes := int(plan.area) * _channels
	if _pending_staging_bytes + staging_bytes > MAX_PENDING_STAGING_BYTES \
			or _staging_batches.size() >= MAX_PENDING_BATCHES:
		return _publish_compact(image, candidate_dirty, latest_plan, serial, generation,
			"staging_capacity", 0, start_usec)
	var allocations := 0
	if _drawables.is_empty():
		var allocated: Array[DrawableTexture2D] = []
		for slot: int in range(2):
			var target := DrawableTexture2D.new()
			target.setup(_size.x, _size.y, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8,
				Color(0, 0, 0, 1), false)
			if not target.get_rid().is_valid() or target.get_size() != Vector2(_size):
				return _publish_compact(image, candidate_dirty, latest_plan, serial, generation,
					"drawable_allocation", 0, start_usec)
			allocated.append(target)
		_drawables = allocated
		allocations += 2
	var regions: Array[Rect2i] = plan.rectangles
	var staging: Array[ImageTexture] = []
	var prepare_start := Time.get_ticks_usec()
	var extraction_usec := 0
	var source_create_usec := 0
	var source_update_usec := 0
	for region: Rect2i in regions:
		var extraction_start := Time.get_ticks_usec()
		var patch: Image = image.get_region(region)
		extraction_usec += Time.get_ticks_usec() - extraction_start
		if patch == null or patch.is_empty() or patch.get_size() != region.size \
				or patch.get_format() != _format:
			return _refused("material upload patch extraction failed")
		var source_start := Time.get_ticks_usec()
		var source := _take_source(region.size)
		if source == null:
			source = ImageTexture.create_from_image(patch)
			source_create_usec += Time.get_ticks_usec() - source_start
			allocations += 1
		else:
			source.update(patch)
			source_update_usec += Time.get_ticks_usec() - source_start
		if source == null or not source.get_rid().is_valid():
			return _refused("material upload staging allocation failed")
		staging.append(source)
	var prepared_usec := Time.get_ticks_usec()
	var target: DrawableTexture2D = _drawables[target_slot]
	var old_target_serial := _slot_serials[target_slot]
	if seed:
		target.blit_rect(Rect2i(Vector2i.ZERO, _size), current, Color.WHITE, 0, _copy_material)
	for index: int in range(regions.size()):
		target.blit_rect(regions[index], staging[index], Color.WHITE, 0, _copy_material)
	var submitted_usec := Time.get_ticks_usec()
	_staging_batches.append({"textures": staging, "bytes": staging_bytes,
		"retire_after_draw": _completed_draw_boundaries + STAGING_RETIRE_DRAW_BOUNDARIES})
	_pending_staging_bytes += staging_bytes
	candidate_dirty[target_slot].fill(0)
	_dirty_slots = candidate_dirty
	_slot_serials[target_slot] = serial
	_seed_pending[target_slot] = false
	previous = current
	current = target
	_drawable_slot = target_slot
	_sparse_mode = true
	_sparse_streak = next_streak
	_seed_blits_total += int(seed)
	_partial_publications_total += 1
	_texture_allocations_total += allocations
	accepted_serial = serial
	accepted_generation = generation
	last_error = ""
	last_metrics = {"initialization": false, "mode": "transition_seed" if seed else "partial_blit",
		"full_reason": "", "blit_count": regions.size() + int(seed), "seed_blit_count": int(seed),
		"dirty_tiles": plan.dirty_tiles, "dirty_area": latest_plan.area,
		"history_repair_area": plan.area, "submitted_area": plan.area,
		"logical_staging_bytes": staging_bytes, "equivalent_full_image_bytes": _full_bytes(),
		"destination_write_bytes": int(plan.area) * 4 + (_size.x * _size.y * 4 if seed else 0),
		"prepare_usec": prepared_usec - prepare_start, "extraction_usec": extraction_usec,
		"source_create_usec": source_create_usec, "source_update_usec": source_update_usec,
		"blit_submit_usec": submitted_usec - prepared_usec, "texture_submit_usec": submitted_usec - prepared_usec,
		"journal_and_validation_usec": prepare_start - start_usec,
		"total_usec": Time.get_ticks_usec() - start_usec,
		"previous_target_serial": old_target_serial, "target_serial": serial,
		"current_slot": target_slot, "texture_allocations": allocations,
		"resident_target_bytes": _resident_bytes(), "pending_staging_bytes": _pending_staging_bytes,
		"pooled_staging_bytes": _pooled_bytes, "journal_bytes": _grid.x * _grid.y * 2,
		"sparse_streak": _sparse_streak, "seed_blits_total": _seed_blits_total,
		"compact_publications_total": _compact_publications_total,
		"partial_publications_total": _partial_publications_total,
		"texture_allocations_total": _texture_allocations_total, "completion_measured": false}
	return _accepted()


func _publish_compact(image: Image, dirty: Array[PackedByteArray], plan: Dictionary,
		serial: int, generation: int, reason: String, streak: int, start_usec: int) -> Dictionary:
	var target_slot := 1 - _compact_slot
	var target := _compact[target_slot]
	# This is precisely the existing compact full-image operation. Never seed or
	# touch a drawable in a dense/full event, including after sparse publication.
	var submit_start := Time.get_ticks_usec()
	target.update(image)
	var submitted_usec := Time.get_ticks_usec()
	previous = current
	current = target
	_compact_slot = target_slot
	_dirty_slots = dirty
	_seed_pending = [true, true]
	_sparse_mode = false
	_sparse_streak = streak
	_compact_publications_total += 1
	accepted_serial = serial
	accepted_generation = generation
	last_error = ""
	last_metrics = {"initialization": false, "mode": "compact_full", "full_reason": reason,
		"blit_count": 0, "seed_blit_count": 0, "dirty_tiles": plan.dirty_tiles,
		"dirty_area": plan.area, "history_repair_area": 0, "submitted_area": _size.x * _size.y,
		"logical_staging_bytes": _full_bytes(), "destination_write_bytes": _full_bytes(),
		"equivalent_full_image_bytes": _full_bytes(), "prepare_usec": 0, "extraction_usec": 0,
		"source_create_usec": 0, "source_update_usec": 0, "blit_submit_usec": 0,
		"texture_submit_usec": submitted_usec - submit_start,
		"journal_and_validation_usec": submit_start - start_usec,
		"total_usec": Time.get_ticks_usec() - start_usec, "target_serial": serial,
		"current_slot": target_slot, "texture_allocations": 0,
		"resident_target_bytes": _resident_bytes(), "pending_staging_bytes": _pending_staging_bytes,
		"pooled_staging_bytes": _pooled_bytes, "journal_bytes": _grid.x * _grid.y * 2,
		"sparse_streak": _sparse_streak, "seed_blits_total": _seed_blits_total,
		"compact_publications_total": _compact_publications_total,
		"partial_publications_total": _partial_publications_total,
		"texture_allocations_total": _texture_allocations_total, "completion_measured": false}
	return _accepted()


func _publication_error(image: Image, rectangles: PackedInt32Array, serial: int,
		generation: int, full_refresh: bool) -> String:
	if not initialized:
		return "material upload textures are not initialized"
	var image_reason := _image_error(image, true)
	if not image_reason.is_empty():
		return image_reason
	if serial <= accepted_serial:
		return "material upload serial is stale or repeated"
	if generation < accepted_generation:
		return "material upload World generation is stale"
	if rectangles.is_empty() or rectangles.size() % METADATA_STRIDE != 0:
		return "material upload patch metadata is empty or malformed"
	var contains_full_rect := false
	for offset: int in range(0, rectangles.size(), METADATA_STRIDE):
		var rect := Rect2i(rectangles[offset], rectangles[offset + 1],
			rectangles[offset + 2], rectangles[offset + 3])
		if rect.size.x <= 0 or rect.size.y <= 0 or rect.position.x < 0 or rect.position.y < 0 \
				or rect.size.x > _size.x or rect.size.y > _size.y \
				or rect.position.x > _size.x - rect.size.x or rect.position.y > _size.y - rect.size.y:
			return "material upload patch exceeds the complete CPU image"
		if rect.position == Vector2i.ZERO and rect.size == _size:
			contains_full_rect = true
	if full_refresh and not contains_full_rect:
		return "material upload full refresh lacks complete-image coverage"
	if generation != accepted_generation and not (full_refresh and contains_full_rect):
		return "material upload World replacement requires complete full refresh"
	return ""


func _image_error(image: Image, check_shape: bool) -> String:
	if image == null or image.is_empty() or image.has_mipmaps():
		return "material upload source must be nonempty without mipmaps"
	if image.get_format() != Image.FORMAT_R8 and image.get_format() != Image.FORMAT_RG8:
		return "material upload source must preserve R8 or RG8 bytes"
	if check_shape and (image.get_size() != _size or image.get_format() != _format):
		return "material upload dimensions/format changed without reinitialization"
	return ""


func _mark_rectangles(journal: PackedByteArray, rectangles: PackedInt32Array) -> void:
	for offset: int in range(0, rectangles.size(), METADATA_STRIDE):
		var first := Vector2i(rectangles[offset] / TILE_SIZE, rectangles[offset + 1] / TILE_SIZE)
		var last := Vector2i((rectangles[offset] + rectangles[offset + 2] - 1) / TILE_SIZE,
			(rectangles[offset + 1] + rectangles[offset + 3] - 1) / TILE_SIZE)
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				journal[y * _grid.x + x] = 1


func _plan(journal: PackedByteArray) -> Dictionary:
	var rectangles: Array[Rect2i] = []
	var area := 0
	var dirty_tiles := 0
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
			var left := begin * TILE_SIZE
			var right := mini(x * TILE_SIZE, _size.x)
			var top := y * TILE_SIZE
			var height := mini(TILE_SIZE, _size.y - top)
			area += (right - left) * height
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
	var reason := ""
	if area * SPARSE_AREA_DIVISOR > _size.x * _size.y:
		reason = "dirty_area"
	elif rectangles.size() > MAX_SPARSE_RECTANGLES:
		reason = "fragmentation"
	return {"rectangles": rectangles, "area": area, "dirty_tiles": dirty_tiles,
		"sparse": reason.is_empty(), "reason": reason}


func _take_source(size: Vector2i) -> ImageTexture:
	for index: int in range(_source_pool.size()):
		var source := _source_pool[index]
		if source.get_width() == size.x and source.get_height() == size.y:
			_source_pool.remove_at(index)
			_pooled_bytes -= size.x * size.y * _channels
			return source
	return null


func _release_staging() -> void:
	# A completed engine draw boundary is not a GPU fence. Keep recently sampled
	# source storage out of the reuse pool for three such boundaries to avoid
	# immediately updating storage still in the driver queue. This delays only
	# storage reuse: publication, visible history and ACK acceptance are unchanged.
	_completed_draw_boundaries += 1
	while not _staging_batches.is_empty() \
			and int(_staging_batches[0].retire_after_draw) <= _completed_draw_boundaries:
		var batch: Dictionary = _staging_batches.pop_front()
		_pending_staging_bytes -= int(batch.bytes)
		for source: ImageTexture in batch.textures:
			var bytes := source.get_width() * source.get_height() * _channels
			if _source_pool.size() < MAX_POOLED_STAGING_TEXTURES \
					and _pooled_bytes + bytes <= MAX_POOLED_STAGING_BYTES:
				_source_pool.append(source)
				_pooled_bytes += bytes


func _staging_metrics() -> Dictionary:
	return {"staging_retirement_draw_boundaries": STAGING_RETIRE_DRAW_BOUNDARIES,
		"completed_draw_boundaries": _completed_draw_boundaries,
		"pending_staging_batches": _staging_batches.size(),
		"pending_staging_bytes": _pending_staging_bytes,
		"pooled_staging_textures": _source_pool.size(), "pooled_staging_bytes": _pooled_bytes,
		"resident_staging_bytes": _pending_staging_bytes + _pooled_bytes,
		"resident_texture_logical_bytes": _resident_bytes() + _pending_staging_bytes + _pooled_bytes}


func _check_canary() -> Dictionary:
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
		return {"passed": false, "error": "graphical readback unavailable"}
	result.convert(Image.FORMAT_RGBA8)
	var output := result.get_data()
	for pixel: int in range(4):
		if output[pixel * 4] != bytes[pixel * 2] or output[pixel * 4 + 1] != bytes[pixel * 2 + 1] \
				or output[pixel * 4 + 2] != 0 or output[pixel * 4 + 3] != 255:
			return {"passed": false, "error": "material bytes changed", "pixel": pixel}
	return {"passed": true, "readback_usec": Time.get_ticks_usec() - start_usec,
		"scope": "startup exact RG8-to-linear-RGBA8 copy only"}


func _sparse_reset() -> void:
	_sparse_streak = 0
	_sparse_mode = false


func _full_bytes() -> int:
	return _size.x * _size.y * _channels


func _resident_bytes() -> int:
	return _full_bytes() * 2 + _drawables.size() * _size.x * _size.y * 4


func _accepted() -> Dictionary:
	last_metrics.merge(_staging_metrics(), true)
	return {"accepted": true, "current": current, "previous": previous,
		"metrics": last_metrics.duplicate(true), "error": ""}


func _refused(reason: String) -> Dictionary:
	last_error = reason
	return {"accepted": false, "current": current, "previous": previous,
		"metrics": {}, "error": reason}


func close() -> void:
	if RenderingServer.frame_post_draw.is_connected(_release_staging):
		RenderingServer.frame_post_draw.disconnect(_release_staging)
	_staging_batches.clear()
	_source_pool.clear()
	_pending_staging_bytes = 0
	_pooled_bytes = 0
	_completed_draw_boundaries = 0
	_compact.clear()
	_drawables.clear()
	_dirty_slots.clear()
	_slot_serials.clear()
	_copy_material = null
	current = null
	previous = null
	_sparse_reset()
	_seed_pending = [true, true]
	_seed_blits_total = 0
	_compact_publications_total = 0
	_partial_publications_total = 0
	_texture_allocations_total = 0
	initialized = false
