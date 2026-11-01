extends "res://tests/support/render_copy_worker.gd"

# Opt-in qualification only. The inherited owner still executes its ordinary
# source-selected publication policy; no E/R behavior is selected by this class.
var pending_rectangle_high_water: int = 0
var published_high_water: int = 0
var legacy_full_high_water: int = 0
var _observed_baseline_serial: int = 0
var _observed_baseline_generation: int = 0
var _observed_baseline_channels: int = 0
var _observed_baseline_accept_usec: int = 0
var _observed_baseline_birth_refresh: int = 0
var _observed_config_generation: int = -1
var baseline_observer_errors: int = 0

# Only the main thread enqueues and releases these real upload ACK requests.
# Fixed arrays bound test apparatus storage; their logical length is not an
# allocator-capacity measurement. N/W still use the inherited ordinary path.
const ACK_QUEUE_CAPACITY: int = 256
var ack_delay_usec: int = 0
var ack_queue_high_water: int = 0
var ack_queue_overflows: int = 0
var ack_queue_errors: int = 0
var _ack_queue_serials: PackedInt64Array = PackedInt64Array()
var _ack_queue_queued_usec: PackedInt64Array = PackedInt64Array()
var _ack_queue_due_usec: PackedInt64Array = PackedInt64Array()
var _ack_queue_sequences: PackedInt64Array = PackedInt64Array()
var _ack_queue_head: int = 0
var _ack_queue_count: int = 0
var _ack_queue_sequence: int = 0
var _ack_queue_last_serial: int = 0

func configure_ack_delay(delay_usec: int) -> void:
	ack_delay_usec = delay_usec
	if ack_delay_usec > 0:
		_ack_queue_serials.resize(ACK_QUEUE_CAPACITY)
		_ack_queue_queued_usec.resize(ACK_QUEUE_CAPACITY)
		_ack_queue_due_usec.resize(ACK_QUEUE_CAPACITY)
		_ack_queue_sequences.resize(ACK_QUEUE_CAPACITY)

func ack_queue_remaining() -> int:
	return _ack_queue_count

func ack_queue_logical_storage_bytes() -> int:
	return (_ack_queue_serials.size() + _ack_queue_queued_usec.size()
		+ _ack_queue_due_usec.size() + _ack_queue_sequences.size()) * 8

func acknowledge_render_snapshot(serial: int) -> void:
	if ack_delay_usec <= 0:
		super.acknowledge_render_snapshot(serial)
		return
	if serial <= _ack_queue_last_serial or withhold_ack:
		ack_queue_errors += 1
		trace.record("ack_queue_error", {"serial": serial, "reason": "nonmonotonic_or_conflicting_mode"})
		return
	if _ack_queue_count == ACK_QUEUE_CAPACITY:
		ack_queue_overflows += 1
		trace.record("ack_queue_error", {"serial": serial, "reason": "capacity_exceeded"})
		return # Qualification fails; never release early to manufacture space.
	var queued_usec: int = Time.get_ticks_usec()
	var index: int = (_ack_queue_head + _ack_queue_count) % ACK_QUEUE_CAPACITY
	_ack_queue_sequence += 1
	_ack_queue_serials[index] = serial
	_ack_queue_queued_usec[index] = queued_usec
	_ack_queue_due_usec[index] = queued_usec + ack_delay_usec
	_ack_queue_sequences[index] = _ack_queue_sequence
	_ack_queue_last_serial = serial
	_ack_queue_count += 1
	ack_queue_high_water = maxi(ack_queue_high_water, _ack_queue_count)
	trace.record("ack_queued", {"serial": serial, "queue_sequence": _ack_queue_sequence,
		"queued_usec": queued_usec, "due_usec": queued_usec + ack_delay_usec,
		"delay_usec": ack_delay_usec, "queue_count": _ack_queue_count})

func flush_due_render_acknowledgements() -> void:
	while _ack_queue_count > 0:
		var now: int = Time.get_ticks_usec()
		if _ack_queue_due_usec[_ack_queue_head] > now:
			return
		var serial: int = _ack_queue_serials[_ack_queue_head]
		var release: Dictionary = {"serial": serial,
			"queue_sequence": _ack_queue_sequences[_ack_queue_head],
			"queued_usec": _ack_queue_queued_usec[_ack_queue_head],
			"due_usec": _ack_queue_due_usec[_ack_queue_head], "delay_usec": ack_delay_usec,
			"released_usec": now, "queue_count": _ack_queue_count - 1}
		_ack_queue_head = (_ack_queue_head + 1) % ACK_QUEUE_CAPACITY
		_ack_queue_count -= 1
		trace.record("ack_delay_release", release)
		# This is the original successful-upload serial, including when a reset
		# has meanwhile made it stale. Production performs its ordinary fencing.
		super.acknowledge_render_snapshot(serial)

func _baseline_identity() -> Dictionary:
	return {"serial": _observed_baseline_serial, "generation": _observed_baseline_generation,
		"channels": _observed_baseline_channels,
		"bytes": CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * _observed_baseline_channels,
		"accept_usec": _observed_baseline_accept_usec,
		"birth_refresh": _observed_baseline_birth_refresh, "refresh": refresh_sequence}

func _retire_observed_baseline(reason: String, pending_serial: int, end_usec: int,
		covering_ack_serial: int = 0, replacement_serial: int = 0, replacement_generation: int = 0) -> void:
	if _observed_baseline_serial <= 0:
		return
	var row: Dictionary = _baseline_identity()
	row.merge({"reason": reason, "end_usec": end_usec,
		"lifetime_usec": end_usec - _observed_baseline_accept_usec,
		"pending_serial_at_retirement": pending_serial, "covering_ack_serial": covering_ack_serial,
		"replacement_serial": replacement_serial, "replacement_generation": replacement_generation}, true)
	trace.record("baseline_end", row)

func record_baseline_censor() -> void:
	# Called only after owner join. Stop is observation censoring, never an ACK.
	if _observed_baseline_serial <= 0:
		return
	var row: Dictionary = _baseline_identity()
	var now: int = Time.get_ticks_usec()
	row.merge({"censor_usec": now, "age_usec": now - _observed_baseline_accept_usec,
		"pending_serial": _pending_render_snapshot_serial}, true)
	trace.record("baseline_censored", row)

func _publish_snapshot(step_ms: float, paused: bool, interval: int, force: bool = false,
		bodies: PackedFloat32Array = PackedFloat32Array(), epoch: int = 0) -> void:
	if _observed_config_generation != _world_generation:
		_observed_config_generation = _world_generation
		trace.record("worker_config", {"generation": _world_generation, "refresh": refresh_sequence + 1,
			"requested_native_workers": _native_worker_request,
			"actual_native_workers": int(_world.get_worker_threads()),
			"logical_processors": int(ClassDB.class_call_static(&"CyberNativeCellWorld", &"logical_processor_count"))})
	super._publish_snapshot(step_ms, paused, interval, force, bodies, epoch)
	published_high_water = maxi(published_high_water, _published_render_patch_cells.size())
	legacy_full_high_water = maxi(legacy_full_high_water, _snapshot_cells.size())
	# These are logical array lengths on the owner thread. Immutable or COW
	# arrays can share storage: do not sum these as unique heap allocations.
	trace.record("owner_payload_bytes", {"refresh": refresh_sequence, "generation": _world_generation,
		"pending_bytes": _pending_render_patch_cells.size(),
		"pending_rectangles": _pending_render_patch_rectangles.size() / 6,
		"published_bytes": _published_render_patch_cells.size(),
		"published_rectangles": _published_render_patch_rectangles.size() / 6,
		"legacy_full_bytes": _snapshot_cells.size()})

func _observed_complete_baseline() -> bool:
	# Identical constant-size observer in every source arm. This is a tag from an
	# actual accepted exact full packet, not a second call to E's metadata scan.
	var metadata: PackedInt32Array = _pending_render_patch_rectangles
	return (_observed_baseline_serial > 0
		and _observed_baseline_serial <= _pending_render_snapshot_serial
		and _observed_baseline_generation == _world_generation
		and _pending_render_world_generation == _world_generation
		and _observed_baseline_channels == _pending_render_channels
		and _pending_render_full_refresh and metadata.size() >= 6
		and _pending_render_patch_cells.size() >= CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * _observed_baseline_channels
		and metadata[0] == 0 and metadata[1] == 0
		and metadata[2] == CyberCellWorld.WORLD_WIDTH and metadata[3] == CyberCellWorld.WORLD_HEIGHT
		and metadata[4] == 0 and metadata[5] == CyberCellWorld.WORLD_WIDTH * _observed_baseline_channels)

func _clear_pending_render_patches() -> void:
	var pending_serial: int = _pending_render_snapshot_serial
	var covering_ack: int = _latched_ack_serial
	super._clear_pending_render_patches()
	if _observed_baseline_serial > 0:
		if covering_ack < pending_serial:
			baseline_observer_errors += 1
		_retire_observed_baseline("ack", pending_serial, Time.get_ticks_usec(), covering_ack)
	_observed_baseline_serial = 0
	_observed_baseline_generation = 0
	_observed_baseline_channels = 0
	_observed_baseline_accept_usec = 0
	_observed_baseline_birth_refresh = 0

func _append_native_render_packet(packet: Dictionary) -> void:
	var before: Dictionary = pending()
	var cells: PackedByteArray = packet.get("cells", PackedByteArray())
	var rectangles: PackedInt32Array = packet.get("rectangles", PackedInt32Array())
	var complete_baseline: bool = _observed_complete_baseline()
	var charged_before: int = int(before.bytes)
	var charged_rectangles: int = int(before.rectangles)
	if complete_baseline:
		charged_before -= CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * int(before.channels)
		charged_rectangles -= 1
	var attempt: Dictionary = {
		"observer_accounting": "constant-time-full-tag-v2",
		"refresh": refresh_sequence, "generation": _world_generation,
		"before": before, "packet_full": bool(packet.get("full_refresh", false)),
		"packet_bytes": cells.size(), "packet_rectangles": rectangles.size() / 6,
		"observed_complete_baseline": complete_baseline,
		"predicted_raw_bytes": int(before.bytes) + cells.size(),
		"predicted_raw_rectangles": int(before.rectangles) + rectangles.size() / 6,
		"predicted_e_charged_bytes": charged_before + cells.size(),
		"predicted_e_charged_rectangles": charged_rectangles + rectangles.size() / 6,
	}
	trace.record("production_append_begin", attempt)
	super._append_native_render_packet(packet)
	var after: Dictionary = pending()
	pending_rectangle_high_water = maxi(pending_rectangle_high_water, int(after.rectangles))
	attempt["after"] = after
	attempt["accepted"] = int(after.pending_serial) != int(before.pending_serial)
	if bool(attempt.accepted) and bool(packet.get("full_refresh", false)):
		var accepted_at: int = Time.get_ticks_usec()
		_retire_observed_baseline("full_replacement", int(before.pending_serial), accepted_at,
			0, int(after.pending_serial), _world_generation)
		var channels: int = int(packet.get("channels", 0))
		var complete: bool = channels in [1, 2] and cells.size() == CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * channels
		complete = complete and rectangles == PackedInt32Array([0, 0, CyberCellWorld.WORLD_WIDTH,
			CyberCellWorld.WORLD_HEIGHT, 0, CyberCellWorld.WORLD_WIDTH * channels])
		_observed_baseline_serial = int(after.pending_serial) if complete else 0
		_observed_baseline_generation = _world_generation if complete else 0
		_observed_baseline_channels = channels if complete else 0
		_observed_baseline_accept_usec = accepted_at if complete else 0
		_observed_baseline_birth_refresh = refresh_sequence if complete else 0
		if complete:
			trace.record("baseline_begin", _baseline_identity())
		else:
			baseline_observer_errors += 1
	trace.record("production_append_end", attempt)
