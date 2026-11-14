extends SceneTree

# RENDER-ACK-002: native owner is exercised through its real worker thread.
# Missing/stale ACK, repeated-cell edits, explicit refresh, reset and immutable
# payload replay are checked without accepting worker-owned bytes as an oracle.
var failures: int = 0
var assertions: int = 0


func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_run.call_deferred()


func _check(valid: bool, label: String) -> void:
	assertions += 1
	if not valid:
		failures += 1
		push_error("RENDER_ACK_POLICY: " + label)


func _snapshot(worker: CyberSimulationWorker) -> CyberSimulationSnapshot:
	return worker.take_latest_snapshot(-1)


func _wait_revision(worker: CyberSimulationWorker, after_revision: int) -> CyberSimulationSnapshot:
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		var latest: CyberSimulationSnapshot = _snapshot(worker)
		if latest != null and latest.simulation_world_revision > after_revision:
			return latest
		await process_frame
	return null


func _wait_serial(worker: CyberSimulationWorker, after_serial: int) -> CyberSimulationSnapshot:
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		var latest: CyberSimulationSnapshot = _snapshot(worker)
		if latest != null and latest.render_snapshot_serial > after_serial:
			return latest
		await process_frame
	return null


func _event_count(events: Array, name: String) -> int:
	var n: int = 0
	for row: Dictionary in events:
		if str(row.get("event", "")) == name:
			n += 1
	return n


func _apply(previous: PackedByteArray, packet: CyberSimulationSnapshot) -> PackedByteArray:
	var cells: PackedByteArray = previous.duplicate()
	var data: PackedByteArray = packet.render_patch_cells
	var metadata: PackedInt32Array = packet.render_patch_rectangles
	var stride: int = CyberCellWorld.WORLD_WIDTH * packet.render_channels
	for p: int in range(0, metadata.size(), 6):
		var x: int = metadata[p]
		var y: int = metadata[p + 1]
		var width: int = metadata[p + 2]
		var height: int = metadata[p + 3]
		var offset: int = metadata[p + 4]
		var source_stride: int = metadata[p + 5]
		for row: int in range(height):
			var dst: int = (y + row) * stride + x * packet.render_channels
			var src: int = offset + row * source_stride
			for i: int in range(width * packet.render_channels):
				cells[dst + i] = data[src + i]
	return cells


func _run() -> void:
	var invalid := CyberSimulationWorker.new()
	_check(invalid.render_ack_policy() == "baseline", "omitted option is baseline")
	_check(not invalid.configure_render_ack_policy("unknown"), "invalid policy rejected")
	_check(invalid.render_ack_policy() == "baseline", "invalid option cannot arm experiment")
	_check(invalid.configure_render_ack_policy("gated"), "pre-start gated opt-in admitted")
	_check(invalid.render_ack_policy() == "gated", "policy is discoverable to tests")
	_check(ClassDB.class_exists(&"CyberNativeCellWorld"), "native World required")
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		await _test_repeated_edits()
		await _test_forced_recovery()
	print("RENDER_ACK_POLICY: %d assertions, %d failures" % [assertions, failures])
	quit(failures)


func _new_worker() -> CyberSimulationWorker:
	var worker := CyberSimulationWorker.new()
	_check(worker.configure_render_ack_policy("gated"), "gated policy configured")
	_check(worker.enable_render_ack_trace(), "source-owned trace enabled")
	worker.set_frame_state(0.0, false, true, Vector2i(160,90),
		Vector2i.ZERO, Vector2i(320,180), 0, 0, false, false, true)
	_check(worker.start_worker(Vector2(150,145)) == OK, "native owner starts")
	_check(not worker.configure_render_ack_policy("baseline"),
		"policy cannot change after worker thread starts")
	return worker


func _test_repeated_edits() -> void:
	var worker: CyberSimulationWorker = _new_worker()
	var initial: CyberSimulationSnapshot = _snapshot(worker)
	_check(initial != null and initial.render_full_refresh, "initial complete native packet")
	if initial == null:
		worker.stop_worker()
		return
	var initial_cells: PackedByteArray = initial.render_patch_cells.duplicate()
	var initial_serial: int = initial.render_snapshot_serial
	worker.acknowledge_render_snapshot(initial_serial)
	_check(worker.queue_emit_disc(500,200,0,CyberCellWorld.WALL), "first edit queued")
	var first: CyberSimulationSnapshot = await _wait_serial(worker, initial_serial)
	_check(first != null, "first compact publication arrived")
	if first == null:
		worker.stop_worker()
		return
	var held_serial: int = first.render_snapshot_serial
	var first_payload: PackedByteArray = first.render_patch_cells.duplicate()
	var last_revision: int = first.simulation_world_revision
	for i: int in range(18):
		var material: int = CyberCellWorld.STONE if i % 2 == 0 else CyberCellWorld.WALL
		_check(worker.queue_emit_disc(500,200,0,material), "same-cell edit admitted")
		var observed: CyberSimulationSnapshot = await _wait_revision(worker,last_revision)
		_check(observed != null, "native edit completed while ACK withheld")
		if observed == null:
			break
		last_revision = observed.simulation_world_revision
		_check(observed.render_snapshot_serial == held_serial,
			"no new native publication before accepted ACK")
		_check(observed.world_revision == first.world_revision
			and observed.simulation_world_revision > observed.world_revision,
			"status cannot claim unsubmitted material bytes")
	worker.acknowledge_render_snapshot(initial_serial) # Stale receipt.
	var stale: CyberSimulationSnapshot = _snapshot(worker)
	_check(stale != null and stale.render_snapshot_serial == held_serial,
		"stale acknowledgement cannot release held publication")
	var prior_events: Array = worker.read_render_ack_trace(0).events
	_check(_event_count(prior_events, "native_capture_deferred") == 1,
		"bounded deferral event observed, not one event per tick")
	_check(_event_count(prior_events, "pending_capacity_escalation") == 0,
		"no pending worker-payload escalation")
	_check(_event_count(prior_events, "native_snapshot") == 2,
		"exactly initial and first captured native packets before ACK")
	_check(first.render_patch_cells == first_payload, "retained immutable packet never mutated")
	worker.acknowledge_render_snapshot(held_serial) # Simulates Main after accepted upload.
	var caught: CyberSimulationSnapshot = await _wait_serial(worker,held_serial)
	_check(caught != null, "ACK releases newest native dirty state")
	if caught != null:
		_check(caught.world_revision == caught.simulation_world_revision,
			"catch-up packet bound to current material revision")
		_check(not caught.render_full_refresh, "same-cell backlog coalesced to compact packet")
		_check(caught.render_world_generation == initial.render_world_generation,
			"no World generation change from pacing")
	worker.stop_worker()
	if caught != null:
		var native: Dictionary = worker._world.take_render_snapshot(true)
		var reconstructed: PackedByteArray = _apply(initial_cells,first)
		reconstructed = _apply(reconstructed,caught)
		_check(reconstructed == native.get("cells",PackedByteArray()),
			"native authoritative bytes exactly equal reconstructed accepted publications")
		_check(initial.render_patch_cells == initial_cells,
			"initial immutable full snapshot retained")
	var events: Array = worker.read_render_ack_trace(0).events
	_check(_event_count(events, "native_capture_resumed") >= 1,
		"ACK release recorded")
	_check(_event_count(events, "pending_capacity_escalation") == 0,
		"no false full escalation after ACK")
	print("RENDER_ACK_POLICY_REPEATED ", JSON.stringify({
		"native_captures":_event_count(events,"native_snapshot"),
		"deferred":_event_count(events,"native_capture_deferred"),
		"escalations":_event_count(events,"pending_capacity_escalation")}))


func _test_forced_recovery() -> void:
	var worker: CyberSimulationWorker = _new_worker()
	var initial: CyberSimulationSnapshot = _snapshot(worker)
	if initial == null:
		_check(false,"reset case startup")
		worker.stop_worker()
		return
	worker.acknowledge_render_snapshot(initial.render_snapshot_serial)
	_check(worker.queue_emit_disc(503,201,0,CyberCellWorld.WALL), "pending edit")
	var first: CyberSimulationSnapshot = await _wait_serial(worker, initial.render_snapshot_serial)
	if first == null:
		_check(false,"pending packet produced")
		worker.stop_worker()
		return
	worker.request_render_full_refresh()
	var explicit: CyberSimulationSnapshot = await _wait_serial(worker, first.render_snapshot_serial)
	_check(explicit != null and explicit.render_full_refresh, "explicit full bypasses unacknowledged packet")
	if explicit == null:
		worker.stop_worker()
		return
	_check(explicit.render_world_generation == initial.render_world_generation,
		"explicit full does not replace World")
	worker.acknowledge_render_snapshot(first.render_snapshot_serial)
	_check(worker.queue_emit_disc(504,201,0,CyberCellWorld.STONE), "post-refresh edit")
	var stale: CyberSimulationSnapshot = await _wait_revision(worker, explicit.simulation_world_revision)
	_check(stale != null and stale.render_snapshot_serial == explicit.render_snapshot_serial,
		"old ACK does not clear newer explicit full")
	worker.queue_reset(Vector2(150,145))
	var replaced: CyberSimulationSnapshot = await _wait_serial(worker, explicit.render_snapshot_serial)
	_check(replaced != null and replaced.render_full_refresh
		and replaced.render_world_generation > initial.render_world_generation,
		"accepted World replacement bypasses gate and changes generation")
	if replaced != null:
		worker.acknowledge_render_snapshot(replaced.render_snapshot_serial)
	worker.stop_worker()
	var events: Array = worker.read_render_ack_trace(0).events
	_check(_event_count(events,"pending_capacity_escalation") == 0,
		"force/reset never impersonate capacity overflow")
	_check(_event_count(events,"native_snapshot") >= 4,
		"initial, normal, explicit and reset captures occurred")
	print("RENDER_ACK_POLICY_RECOVERY ", JSON.stringify({
		"native_captures":_event_count(events,"native_snapshot"),
		"escalations":_event_count(events,"pending_capacity_escalation")}))
