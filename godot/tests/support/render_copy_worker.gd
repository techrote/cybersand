extends "res://scripts/simulation_worker.gd"

const Trace = preload("res://tests/support/render_copy_trace.gd")
var trace = Trace.new()
var withhold_ack: bool = false
var refresh_sequence: int = 0
var calls_in_refresh: int = 0
var pending_high_water: int = 0
var _latched_ack_serial: int = 0
var _retained_baseline_serial: int = 0

func pending() -> Dictionary:
	return {"generation": _world_generation, "render_generation": _pending_render_world_generation,
		"revision": int(_world.revision), "tick": int(_world.tick_index), "refresh": refresh_sequence,
		"pending_serial": _pending_render_snapshot_serial, "full": _pending_render_full_refresh,
		"bytes": _pending_render_patch_cells.size(), "rectangles": _pending_render_patch_rectangles.size() / 6,
		"channels": _pending_render_channels, "baseline_serial": _retained_baseline_serial}

func take_latest_snapshot(after: int) -> CyberSimulationSnapshot:
	var result: CyberSimulationSnapshot = super.take_latest_snapshot(after)
	if result != null:
		trace.record("receipt", {"serial": result.render_snapshot_serial, "generation": result.render_world_generation,
			"snapshot_serial": result.serial, "revision": result.world_revision})
	return result

func acknowledge_render_snapshot(serial: int) -> void:
	trace.record("ack_withheld" if withhold_ack else "ack_issue", {"serial": serial})
	if not withhold_ack:
		super.acknowledge_render_snapshot(serial)
		trace.record("ack_visible", {"serial": serial})

func request_render_full_refresh() -> void:
	trace.record("full_request")
	super.request_render_full_refresh()

func _publish_snapshot(step_ms: float, paused: bool, interval: int, force: bool = false,
		bodies: PackedFloat32Array = PackedFloat32Array(), epoch: int = 0) -> void:
	refresh_sequence += 1
	calls_in_refresh = 0
	var before := pending()
	_mutex.lock()
	before["ack_serial"] = _acknowledged_render_snapshot_serial
	_mutex.unlock()
	trace.record("owner_begin", before)
	var start := Time.get_ticks_usec()
	super._publish_snapshot(step_ms, paused, interval, force, bodies, epoch)
	var end := Time.get_ticks_usec()
	var after := pending()
	after["duration_usec"] = end - start
	after["end_usec"] = end
	after["calls"] = calls_in_refresh
	# Visibility is bracketed by snapshot.published_usec and this post-return timestamp.
	after["snapshot_serial"] = _published_snapshot.serial if _published_snapshot != null else 0
	after["published_usec"] = _published_snapshot.published_usec if _published_snapshot != null else 0
	trace.record("owner_end", after)

func _observe_render_acknowledgement(serial: int) -> void:
	_latched_ack_serial = serial
	var event := pending()
	event["ack_serial"] = serial
	event["will_clear"] = serial >= _pending_render_snapshot_serial and _pending_render_snapshot_serial > 0 and not _pending_render_patch_cells.is_empty()
	trace.record("ack_observed", event)
	if serial > 0 and serial < _pending_render_snapshot_serial and not _pending_render_patch_cells.is_empty():
		trace.record("ack_stale", event)

func _take_native_render_snapshot(force: bool) -> Dictionary:
	calls_in_refresh += 1
	var before := pending()
	before["force_full"] = force
	before["call"] = calls_in_refresh
	trace.record("native_begin", before)
	var start := Time.get_ticks_usec()
	var packet: Dictionary = super._take_native_render_snapshot(force)
	var end := Time.get_ticks_usec()
	var record := pending()
	var channels: int = packet.get("channels", 0)
	var complete: bool = bool(packet.get("full_refresh", false)) and channels in [1, 2] and packet.get("cells", PackedByteArray()).size() == CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * channels and packet.get("rectangles", PackedInt32Array()) == PackedInt32Array([0, 0, CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT, 0, CyberCellWorld.WORLD_WIDTH * channels])
	record.merge({"start_usec": start, "end_usec": end, "duration_usec": end - start, "complete_full": complete,
		"force_full": force, "call": calls_in_refresh, "status": packet.get("status", -1),
		"packet_serial": packet.get("serial", 0), "packet_full": packet.get("full_refresh", false),
		"packet_channels": packet.get("channels", 0), "packet_bytes": packet.get("cells", PackedByteArray()).size(),
		"packet_rectangles": packet.get("rectangles", PackedInt32Array()).size() / 6}, true)
	trace.record("native_end", record)
	if calls_in_refresh == 1:
		trace.record("refresh", {"refresh": refresh_sequence})
	else:
		trace.record("forced_retry", {"refresh": refresh_sequence})
	return packet

func _append_native_render_packet(packet: Dictionary) -> void:
	var before := pending()
	var dirty_onto_full: bool = _pending_render_full_refresh and not packet.get("full_refresh", false) and not packet.get("cells", PackedByteArray()).is_empty()
	super._append_native_render_packet(packet)
	if packet.get("full_refresh", false) and not packet.get("cells", PackedByteArray()).is_empty():
		_retained_baseline_serial = _pending_render_snapshot_serial
	pending_high_water = maxi(pending_high_water, _pending_render_patch_cells.size())
	var after := pending()
	after["before"] = before
	after["packet_full"] = packet.get("full_refresh", false)
	after["byte_overflow"] = _pending_render_patch_cells.size() > CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2
	after["rectangle_overflow"] = _pending_render_patch_rectangles.size() > MAX_PENDING_RENDER_PATCHES * RENDER_PATCH_METADATA_STRIDE
	trace.record("accumulate", after)
	if dirty_onto_full:
		trace.record("dirty_onto_full", after)
	if packet.get("full_refresh", false):
		trace.record("full_publication", after)

func _clear_pending_render_patches() -> void:
	var before := pending()
	before["ack_serial"] = _latched_ack_serial
	super._clear_pending_render_patches()
	_retained_baseline_serial = 0
	trace.record("ack_clear" if int(before.bytes) > 0 else "ack_empty", before)
