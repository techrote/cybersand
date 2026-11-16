extends RefCounted

# Optional value-only transport accumulator. It never owns native cells or GPU
# resources. An ACK retires source captures, not the newest pending serial only.
# A bounded CPU image is admitted only when the ordinary compact journal fills;
# its tile versions allow an older ACK to retire already accepted regions while
# current native captures continue at the ordinary cadence.
const STRIDE := 6
const MAX_PATCHES := 256
const TILE_SIZE := 64
const MAX_SIDE := 2048

var extent := Vector2i.ZERO
var generation: int = -1
var channels: int = 2
var last_serial: int = 0
var acknowledged_serial: int = 0
var needs_full_capture: bool = false
var payload_version: int = 0
var _batches: Array[Dictionary] = []
var _cache: Image
var _tile_serials := PackedInt64Array()
var _tiles_wide: int = 0
var _full_required_until: int = 0
var _packet: Dictionary = {}
var _packet_dirty: bool = true
var _stats := {"captures": 0, "retired_batches": 0, "superseded_batches": 0,
	"cache_activations": 0, "cache_update_usec": 0, "payload_build_usec": 0,
	"full_capture_requests": 0, "refusals": 0, "full_payloads": 0,
	"sparse_cache_payloads": 0, "peak_retained_source_bytes": 0}


func configure(canvas: Vector2i, world_generation: int) -> bool:
	if canvas.x <= 0 or canvas.y <= 0 or canvas.x > MAX_SIDE or canvas.y > MAX_SIDE:
		return false
	if canvas != extent or world_generation != generation:
		clear()
		extent = canvas
		generation = world_generation
	return true


func clear() -> void:
	payload_version += 1
	_batches.clear()
	_cache = null
	_tile_serials = PackedInt64Array()
	_full_required_until = 0
	needs_full_capture = false
	_packet = {}
	_packet_dirty = true
	# Worker-lifetime serials and ACKs remain monotonic across World replacement.


func retire(serial: int) -> void:
	if serial <= acknowledged_serial:
		return
	acknowledged_serial = serial
	payload_version += 1
	if serial >= last_serial:
		_stats.retired_batches += _batches.size()
		var recovery_required: bool = needs_full_capture
		clear()
		# An ACK of the last accepted capture cannot acknowledge rejected bytes.
		needs_full_capture = recovery_required
		return
	if _cache == null:
		var retained: Array[Dictionary] = []
		for batch: Dictionary in _batches:
			if int(batch.serial) <= serial:
				_stats.retired_batches += 1
			else:
				retained.append(batch)
		_batches = retained
	_packet_dirty = true


func append(packet: Dictionary, serial: int) -> bool:
	var rectangles: PackedInt32Array = packet.get("rectangles", PackedInt32Array())
	var cells: PackedByteArray = packet.get("cells", PackedByteArray())
	var incoming_channels: int = int(packet.get("channels", 2))
	if rectangles.is_empty() or cells.is_empty():
		return false
	if serial <= last_serial or not _valid(rectangles, cells, incoming_channels):
		_stats.refusals += 1
		needs_full_capture = true
		return false
	var is_full: bool = bool(packet.get("full_refresh", false))
	if is_full and not _starts_with_complete_plane(rectangles):
		_stats.refusals += 1
		needs_full_capture = true
		return false
	if incoming_channels != channels:
		if not is_full:
			_stats.refusals += 1
			needs_full_capture = true
			return false
		clear()
	channels = incoming_channels
	last_serial = serial
	payload_version += 1
	_stats.captures += 1
	_packet = {}
	_packet_dirty = true
	if _cache != null:
		_apply_cache(rectangles, cells, serial, is_full)
		return true
	var wanted_cache: bool = needs_full_capture
	if is_full:
		_batches.clear()
		needs_full_capture = false
	# Equal ordered geometry is an exact overwrite of every older covered byte.
	# The replacement is appended last so overlapping intervening captures retain
	# the correct ordering. Different shapes are never guessed equivalent.
	var retained: Array[Dictionary] = []
	for batch: Dictionary in _batches:
		if batch.rectangles == rectangles:
			is_full = is_full or bool(batch.full_refresh)
			_stats.superseded_batches += 1
		else:
			retained.append(batch)
	_batches = retained
	_batches.append({"serial": serial, "rectangles": rectangles.duplicate(),
		"cells": cells.duplicate(), "full_refresh": is_full})
	var counts: Vector2i = _journal_counts()
	_stats.peak_retained_source_bytes = maxi(int(_stats.peak_retained_source_bytes), counts.y)
	if wanted_cache or counts.x > MAX_PATCHES or counts.y > extent.x * extent.y * channels:
		if not _batches.is_empty() and bool(_batches[0].full_refresh):
			_activate_cache()
		else:
			if not needs_full_capture:
				_stats.full_capture_requests += 1
			needs_full_capture = true
	return true


func payload() -> Dictionary:
	if not _packet_dirty:
		return _packet
	var started: int = Time.get_ticks_usec()
	var rectangles := PackedInt32Array()
	var cells := PackedByteArray()
	var full: bool = false
	if _cache != null:
		if acknowledged_serial < _full_required_until:
			rectangles = PackedInt32Array([0, 0, extent.x, extent.y, 0, extent.x * channels])
			cells = _cache.get_data()
			full = true
		else:
			var regions: Array[Rect2i] = _dirty_regions()
			var area: int = 0
			for region: Rect2i in regions:
				area += region.size.x * region.size.y
			# One complete CPU payload also bounds fragmented/dense export. This
			# never asks native to refresh or changes the accepted source serial.
			if regions.size() > MAX_PATCHES or area >= extent.x * extent.y:
				rectangles = PackedInt32Array([0, 0, extent.x, extent.y, 0, extent.x * channels])
				cells = _cache.get_data()
				full = true
			else:
				for region: Rect2i in regions:
					rectangles.append_array(PackedInt32Array([region.position.x, region.position.y,
						region.size.x, region.size.y, cells.size(), region.size.x * channels]))
					cells.append_array(_cache.get_region(region).get_data())
				if not regions.is_empty():
					_stats.sparse_cache_payloads += 1
	elif _batches.size() == 1:
		# A single capture already has packet-relative offsets. Do not flatten
		# its bytes again, especially for an 8 MiB full plane and older ACKs.
		# Packed arrays alias on GDScript assignment; duplicate() creates an
		# independent value using Godot's copy-on-write backing storage.
		var batch: Dictionary = _batches[0]
		rectangles = batch.rectangles.duplicate()
		cells = batch.cells.duplicate()
		full = bool(batch.full_refresh)
	else:
		for batch: Dictionary in _batches:
			var source: PackedInt32Array = batch.rectangles
			var base_offset: int = cells.size()
			for offset: int in range(0, source.size(), STRIDE):
				rectangles.append_array(PackedInt32Array([source[offset], source[offset + 1],
					source[offset + 2], source[offset + 3], source[offset + 4] + base_offset,
					source[offset + 5]]))
			cells.append_array(batch.cells)
			full = full or bool(batch.full_refresh)
	if full:
		_stats.full_payloads += 1
	_packet = {"rectangles": rectangles, "cells": cells, "channels": channels,
		"full_refresh": full}
	_packet_dirty = false
	_stats.payload_build_usec += Time.get_ticks_usec() - started
	return _packet


func statistics() -> Dictionary:
	var result: Dictionary = _stats.duplicate()
	result["policy"] = "compact"
	result["cache_bytes"] = extent.x * extent.y * channels if _cache != null else 0
	result["cache_tiles"] = _tile_serials.size()
	result["pending_batches"] = _batches.size()
	result["acknowledged_serial"] = acknowledged_serial
	result["latest_serial"] = last_serial
	result["needs_full_capture"] = needs_full_capture
	return result


func _valid(rectangles: PackedInt32Array, cells: PackedByteArray, count: int) -> bool:
	if (count != 1 and count != 2) or rectangles.size() % STRIDE != 0:
		return false
	# Include one complete baseline plus one in-flight packet when adopting a
	# legacy journal; larger/malformed inputs take the existing explicit resync.
	if rectangles.size() > 2 * MAX_PATCHES * STRIDE or cells.size() > 2 * extent.x * extent.y * count:
		return false
	for offset: int in range(0, rectangles.size(), STRIDE):
		var x: int = rectangles[offset]
		var y: int = rectangles[offset + 1]
		var width: int = rectangles[offset + 2]
		var height: int = rectangles[offset + 3]
		var data_offset: int = rectangles[offset + 4]
		var row_stride: int = rectangles[offset + 5]
		if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > extent.x or y + height > extent.y:
			return false
		if data_offset < 0 or row_stride < width * count or data_offset + (height - 1) * row_stride + width * count > cells.size():
			return false
	return true


func _starts_with_complete_plane(rectangles: PackedInt32Array) -> bool:
	return rectangles.size() >= STRIDE and rectangles[0] == 0 and rectangles[1] == 0 \
		and rectangles[2] == extent.x and rectangles[3] == extent.y


func _journal_counts() -> Vector2i:
	var counts := Vector2i.ZERO
	for batch: Dictionary in _batches:
		counts.x += batch.rectangles.size() / STRIDE
		counts.y += batch.cells.size()
	return counts


func _activate_cache() -> void:
	_cache = Image.create(extent.x, extent.y, false, _format())
	_tiles_wide = ceili(float(extent.x) / TILE_SIZE)
	_tile_serials.resize(_tiles_wide * ceili(float(extent.y) / TILE_SIZE))
	_tile_serials.fill(0)
	for batch: Dictionary in _batches:
		_apply_cache(batch.rectangles, batch.cells, int(batch.serial), bool(batch.full_refresh))
	_batches.clear()
	needs_full_capture = false
	_stats.cache_activations += 1


func _apply_cache(rectangles: PackedInt32Array, cells: PackedByteArray, serial: int, full: bool) -> void:
	var started: int = Time.get_ticks_usec()
	for offset: int in range(0, rectangles.size(), STRIDE):
		var region := Rect2i(rectangles[offset], rectangles[offset + 1], rectangles[offset + 2], rectangles[offset + 3])
		var data_offset: int = rectangles[offset + 4]
		var row_stride: int = rectangles[offset + 5]
		var row_bytes: int = region.size.x * channels
		var data: PackedByteArray
		if row_stride == row_bytes:
			data = cells.slice(data_offset, data_offset + region.size.y * row_bytes)
		else:
			data = PackedByteArray()
			for row: int in region.size.y:
				data.append_array(cells.slice(data_offset + row * row_stride, data_offset + row * row_stride + row_bytes))
		if region == Rect2i(Vector2i.ZERO, extent):
			_cache.set_data(extent.x, extent.y, false, _format(), data)
		else:
			_cache.blit_rect(Image.create_from_data(region.size.x, region.size.y, false, _format(), data),
				Rect2i(Vector2i.ZERO, region.size), region.position)
		for tile_y: int in range(region.position.y / TILE_SIZE, (region.end.y - 1) / TILE_SIZE + 1):
			for tile_x: int in range(region.position.x / TILE_SIZE, (region.end.x - 1) / TILE_SIZE + 1):
				_tile_serials[tile_y * _tiles_wide + tile_x] = serial
	if full:
		_full_required_until = serial
	needs_full_capture = false
	_stats.cache_update_usec += Time.get_ticks_usec() - started


func _dirty_regions() -> Array[Rect2i]:
	var regions: Array[Rect2i] = []
	var active: Dictionary = {}
	var rows: int = _tile_serials.size() / _tiles_wide
	for y: int in rows:
		var next: Dictionary = {}
		var x: int = 0
		while x < _tiles_wide:
			if _tile_serials[y * _tiles_wide + x] <= acknowledged_serial:
				x += 1
				continue
			var first: int = x
			while x < _tiles_wide and _tile_serials[y * _tiles_wide + x] > acknowledged_serial:
				x += 1
			var key := Vector2i(first, x)
			if active.has(key):
				var index: int = int(active[key])
				var extended: Rect2i = regions[index]
				extended.size.y = mini((y + 1) * TILE_SIZE, extent.y) - extended.position.y
				regions[index] = extended
				next[key] = index
			else:
				next[key] = regions.size()
				regions.append(Rect2i(first * TILE_SIZE, y * TILE_SIZE,
					mini(x * TILE_SIZE, extent.x) - first * TILE_SIZE,
					mini(TILE_SIZE, extent.y - y * TILE_SIZE)))
		active = next
	return regions


func _format() -> Image.Format:
	return Image.FORMAT_RG8 if channels == 2 else Image.FORMAT_R8
