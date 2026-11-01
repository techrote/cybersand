extends "res://tests/support/render_copy_worker.gd"

# Opt-in qualification only. The inherited owner still executes its ordinary
# source-selected publication policy; no E/R behavior is selected by this class.
var pending_rectangle_high_water: int = 0
var _observed_baseline_serial: int = 0
var _observed_baseline_generation: int = 0
var _observed_baseline_channels: int = 0

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
	super._clear_pending_render_patches()
	_observed_baseline_serial = 0
	_observed_baseline_generation = 0
	_observed_baseline_channels = 0

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
		var channels: int = int(packet.get("channels", 0))
		var complete: bool = channels in [1, 2] and cells.size() == CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * channels
		complete = complete and rectangles == PackedInt32Array([0, 0, CyberCellWorld.WORLD_WIDTH,
			CyberCellWorld.WORLD_HEIGHT, 0, CyberCellWorld.WORLD_WIDTH * channels])
		_observed_baseline_serial = int(after.pending_serial) if complete else 0
		_observed_baseline_generation = _world_generation if complete else 0
		_observed_baseline_channels = channels if complete else 0
	trace.record("production_append_end", attempt)
