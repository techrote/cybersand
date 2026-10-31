extends "res://tests/render_publication_worker.gd"

# E is installed only by the explicit investigation harness. No baseline is
# dropped, rebased, coalesced or acknowledged here. Existing full recovery and
# ordinary latest-serial ACK are the only ways to retire retained bytes.
const E_WIDTH: int = 1024
const E_HEIGHT: int = 1024
const E_BYTE_BUDGET: int = 2097152
const E_RECTANGLE_BUDGET: int = 256
var e_baseline_serial: int = 0
var e_baseline_generation: int = 0
var e_baseline_channels: int = 0
var e_recovery_required: bool = false
var e_retained_high_water: int = 0

func _revoke_e_baseline() -> void:
	e_baseline_serial = 0
	e_baseline_generation = 0
	e_baseline_channels = 0

func _complete_full_metadata(rectangles: PackedInt32Array, channels: int) -> bool:
	return channels in [1, 2] and rectangles.size() >= 6 and rectangles.slice(0, 6) == PackedInt32Array([
		0, 0, E_WIDTH, E_HEIGHT, 0, E_WIDTH * channels])

func _valid_e_patches(rectangles: PackedInt32Array, bytes: int, channels: int, initial_offset: int = 0) -> bool:
	if channels not in [1, 2] or rectangles.is_empty() or rectangles.size() % 6 != 0:
		return false
	var next_offset: int = initial_offset
	for index: int in range(0, rectangles.size(), 6):
		var x: int = rectangles[index]
		var y: int = rectangles[index + 1]
		var width: int = rectangles[index + 2]
		var height: int = rectangles[index + 3]
		var offset: int = rectangles[index + 4]
		var pitch: int = rectangles[index + 5]
		if x < 0 or y < 0 or width <= 0 or height <= 0 or x > E_WIDTH - width or y > E_HEIGHT - height:
			return false
		# Native packets use tightly packed, contiguous ordered payload extents.
		# Ambiguous/aliased/gapped/padded synthetic packets receive no exemption.
		if pitch != width * channels or offset != next_offset:
			return false
		next_offset += pitch * height
		if next_offset > bytes:
			return false
	return next_offset == bytes

func _e_has_qualified_baseline(newly_produced_full: bool = false) -> bool:
	return (e_baseline_serial > 0 and e_baseline_serial <= _pending_render_snapshot_serial
		and e_baseline_generation == _world_generation
		and (newly_produced_full or _pending_render_world_generation == _world_generation)
		and e_baseline_channels == _pending_render_channels
		and _pending_render_full_refresh
		and _pending_render_patch_cells.size() >= E_WIDTH * E_HEIGHT * e_baseline_channels
		and _complete_full_metadata(_pending_render_patch_rectangles, e_baseline_channels)
		and _valid_e_patches(_pending_render_patch_rectangles,
			_pending_render_patch_cells.size(), e_baseline_channels))

func _preflight_recovery(reason: String, bytes: int, rectangles: int,
		byte_overflow: bool = false, rectangle_overflow: bool = false) -> void:
	e_recovery_required = true
	trace.record("e_preflight_recovery", {"reason": reason,
		"predicted_bytes": bytes, "predicted_rectangles": rectangles,
		"byte_overflow": byte_overflow, "rectangle_overflow": rectangle_overflow,
		"generation": _world_generation, "pending_serial": _pending_render_snapshot_serial})

func _append_native_render_packet(packet: Dictionary) -> void:
	# Validate types before GDScript's value constructors can coerce them.
	if (typeof(packet.get("cells")) != TYPE_PACKED_BYTE_ARRAY
		or typeof(packet.get("rectangles")) != TYPE_PACKED_INT32_ARRAY
		or typeof(packet.get("channels")) != TYPE_INT
		or typeof(packet.get("full_refresh")) != TYPE_BOOL
		or (packet.has("failed") and typeof(packet.failed) != TYPE_BOOL)):
		_revoke_e_baseline()
		_preflight_recovery("invalid_field_type", _pending_render_patch_cells.size(), _pending_render_patch_rectangles.size() / 6)
		return
	var cells: PackedByteArray = packet.get("cells", PackedByteArray())
	var rectangles: PackedInt32Array = packet.get("rectangles", PackedInt32Array())
	var channels: int = int(packet.get("channels", 0))
	var full: bool = bool(packet.get("full_refresh", false))
	# A forced full copy can accompany any known native publish outcome (even
	# Backpressure/NoChanges with serial zero). Explicit failure or an unknown
	# envelope cannot establish a qualified baseline.
	if (packet.get("failed", false) or typeof(packet.get("status")) != TYPE_INT
		or int(packet.status) not in [0, 1, 2, 3] or typeof(packet.get("serial")) != TYPE_INT
		or int(packet.serial) < 0):
		_revoke_e_baseline()
		_preflight_recovery("invalid_envelope", cells.size(), rectangles.size() / 6)
		return
	if not full and cells.is_empty() and rectangles.is_empty() and int(packet.status) in [0, 2]:
		return # Ordinary NoChanges/backpressure carries no newly appended payload.
	if full:
		_revoke_e_baseline()
		if (rectangles.size() != 6 or not _complete_full_metadata(rectangles, channels)
			or cells.size() != E_WIDTH * E_HEIGHT * channels):
			_preflight_recovery("malformed_full", cells.size(), rectangles.size() / 6)
			return
		super._append_native_render_packet(packet)
		e_baseline_serial = _pending_render_snapshot_serial
		e_baseline_generation = _world_generation
		e_baseline_channels = channels
		e_recovery_required = false
	else:
		if (int(packet.get("status", -1)) != 1 or int(packet.get("serial", 0)) <= 0
			or not _valid_e_patches(rectangles, cells.size(), channels)):
			_revoke_e_baseline()
			_preflight_recovery("malformed_dirty", _pending_render_patch_cells.size() + cells.size(),
				(_pending_render_patch_rectangles.size() + rectangles.size()) / 6)
			return
		if (not _pending_render_patch_cells.is_empty() and (channels != _pending_render_channels
			or _pending_render_world_generation != _world_generation)):
			_revoke_e_baseline()
			_preflight_recovery("channel_or_generation_mismatch", _pending_render_patch_cells.size() + cells.size(),
				(_pending_render_patch_rectangles.size() + rectangles.size()) / 6)
			return
		var exempt_bytes: int = E_WIDTH * E_HEIGHT * channels if _e_has_qualified_baseline() else 0
		var exempt_records: int = 1 if exempt_bytes > 0 else 0
		var predicted_bytes: int = _pending_render_patch_cells.size() + cells.size()
		var predicted_records: int = (_pending_render_patch_rectangles.size() + rectangles.size()) / 6
		var byte_overflow: bool = predicted_bytes - exempt_bytes > E_BYTE_BUDGET
		var rectangle_overflow: bool = predicted_records - exempt_records > E_RECTANGLE_BUDGET
		if byte_overflow or rectangle_overflow:
			_preflight_recovery("dirty_budget", predicted_bytes, predicted_records, byte_overflow, rectangle_overflow)
			return
		super._append_native_render_packet(packet)
	e_retained_high_water = maxi(e_retained_high_water, _pending_render_patch_cells.size())

func _pending_render_exceeds_budget() -> bool:
	if e_recovery_required:
		return true
	if not _e_has_qualified_baseline():
		return super._pending_render_exceeds_budget()
	return (_pending_render_patch_cells.size() - E_WIDTH * E_HEIGHT * e_baseline_channels > E_BYTE_BUDGET
		or _pending_render_patch_rectangles.size() - 6 > E_RECTANGLE_BUDGET * 6)

func _retain_full_render_cells() -> void:
	# The legacy cells field keeps the last complete frame, as on ordinary dirty
	# publication. Real consumers apply render_patch_* in order to get current pixels.
	if (_e_has_qualified_baseline(true)
		and _pending_render_patch_cells.size() == E_WIDTH * E_HEIGHT * e_baseline_channels):
		super._retain_full_render_cells()

func _clear_pending_render_patches() -> void:
	super._clear_pending_render_patches()
	_revoke_e_baseline()
	e_recovery_required = false
