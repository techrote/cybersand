extends SceneTree

# RENDER-ACK-001. Native source owner, opt-in trace and explicit ACK behavior.
# The stalled arm deliberately withholds acknowledgements while sending small,
# distinct edits. No production ACK/pacing/graphics policy is modified.

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_run.call_deferred()


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("RENDER_ACK_FEEDBACK: " + label)


func _wait_render(worker: CyberSimulationWorker, previous: int) -> CyberSimulationSnapshot:
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		if snapshot != null and snapshot.render_snapshot_serial > previous:
			return snapshot
		await process_frame
	return null


func _trace_contains(events: Array, name: String, reason: String = "") -> bool:
	for row: Dictionary in events:
		if row.get("event", "") == name and (reason.is_empty() or row.get("reason", "") == reason):
			return true
	return false


func _run() -> void:
	_test_policy_boundaries_and_opt_in()
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"),
		"source-matched native RG8 backend is required")
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		await _test_native_ack_case(true)
		await _test_native_ack_case(false)
	print("RENDER_ACK_FEEDBACK: %d assertions, %d failures" % [checks, failures])
	quit(failures)


func _test_policy_boundaries_and_opt_in() -> void:
	var worker := CyberSimulationWorker.new()
	_expect(not worker.read_render_ack_trace(0).enabled, "trace must be off by default")
	_expect(CyberSimulationWorker.render_pending_capacity_reason(100, 256 * 6, 100) == "",
		"at-limit policy must be accepted")
	_expect(CyberSimulationWorker.render_pending_capacity_reason(101, 256 * 6, 100) == "pending_bytes",
		"one byte beyond strict capacity")
	_expect(CyberSimulationWorker.render_pending_capacity_reason(100, 257 * 6, 100) == "pending_rectangles",
		"one rectangle beyond strict capacity")
	_expect(CyberSimulationWorker.render_pending_capacity_reason(101, 257 * 6, 100) == "both",
		"independent limits both exceeded")
	_expect(worker.enable_render_ack_trace(), "pre-start trace must be allowed")
	worker.acknowledge_render_snapshot(5)
	worker.acknowledge_render_snapshot(3)
	var first: Dictionary = worker.read_render_ack_trace(0)
	_expect(int(first.last_sequence) >= 2 and first.events.size() == 2,
		"ACK receipt events are observable without consuming a snapshot")
	_expect(first.events[0].event == "ack_arrived" and first.events[0].advanced,
		"advanced ACK event missing")
	_expect(not first.events[1].advanced and worker._acknowledged_render_snapshot_serial == 5,
		"old ACK must not rewind receipt")
	first.events[0]["event"] = "corrupted_caller_copy"
	_expect(worker.read_render_ack_trace(0).events[0].event == "ack_arrived",
		"event readback must never mutate the retained worker ring")
	_expect(worker.read_render_ack_trace(int(first.last_sequence)).events.is_empty(),
		"since-sequence read must return only new events")


func _test_native_ack_case(keep_acknowledging: bool) -> void:
	var worker := CyberSimulationWorker.new()
	_expect(worker.enable_render_ack_trace(), "trace admission for native case")
	worker.set_frame_state(0.0, false, true, Vector2i(160, 90),
		Vector2i.ZERO, Vector2i(320, 180), 0, 0, false, false, true)
	_expect(worker.start_worker(Vector2(150, 145)) == OK, "native worker starts")
	var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	_expect(initial != null and initial.render_channels == 2,
		"actual initial native RG8 packet")
	if initial == null:
		worker.stop_worker()
		return
	worker.acknowledge_render_snapshot(initial.render_snapshot_serial)
	var last_serial: int = initial.render_snapshot_serial
	var saw_escalation: bool = false
	var edit_count: int = 12 if keep_acknowledging else 275
	var escalation_count: int = 0
	for i: int in range(edit_count):
		# One cell, two distinct nonempty immobile materials. Unlike scattered
		# default-demo coordinates, every native source turn MUST be a change,
		# even with paused simulation, so missing ACK is the controlled variable.
		var material: int = CyberCellWorld.WALL if i % 2 == 0 else CyberCellWorld.STONE
		if not _expect_edit(worker, 500, 200, material):
			break
		var received: CyberSimulationSnapshot = await _wait_render(worker, last_serial)
		if received == null:
			var trace: Dictionary = worker.read_render_ack_trace(0)
			print("RENDER_ACK_NO_PUBLICATION ", JSON.stringify({
				"at_edit":i, "last_render_serial":last_serial,
				"tail":trace.events.slice(maxi(0,trace.events.size()-12))}))
			_expect(false, "native changed-render publication after edit %d" % i)
			break
		_expect(received.render_world_generation == initial.render_world_generation,
			"transport may not reset World generation")
		last_serial = received.render_snapshot_serial
		if keep_acknowledging:
			worker.acknowledge_render_snapshot(last_serial)
		else:
			var recent: Dictionary = worker.read_render_ack_trace(0)
			escalation_count = recent.events.filter(
				func(row: Dictionary) -> bool: return row.get("event", "") == "pending_capacity_escalation").size()
			if escalation_count >= 2:
				saw_escalation = true
				break
	worker.stop_worker()
	var retained: Dictionary = worker.read_render_ack_trace(0)
	var events: Array = retained.events
	_expect(retained.enabled and int(retained.evicted_total) == 0, "complete bounded native trace")
	_expect(_trace_contains(events, "ack_arrived"), "native ACK arrived")
	_expect(_trace_contains(events, "ack_latched"), "native worker latched ACK")
	_expect(_trace_contains(events, "pending_cleared_by_ack"),
		"acknowledgement cleared pending material bytes")
	if keep_acknowledging:
		_expect(not _trace_contains(events, "pending_capacity_escalation"),
			"ordinary acknowledged sparse edits cannot overflow the pending journal")
	else:
		_expect(saw_escalation, "withholding ACK must demonstrate two full refreshes")
		_expect(_trace_contains(events, "native_snapshot", "pending_capacity_escalation"),
			"worker overflow requested an actual native full packet")
		var reasons: Array[String] = []
		for row: Dictionary in events:
			if row.event == "pending_capacity_escalation":
				reasons.append(str(row.reason))
				_expect(int(row.pending_rectangles) > 256 or
					int(row.pending_bytes) > int(row.byte_limit),
					"overflow must record its strict measured threshold")
				_expect(int(row.acknowledged_serial) < int(row.pending_serial),
					"overflow has truly unacknowledged material serial")
		print("RENDER_ACK_ESCALATIONS ", JSON.stringify({
			"reasons":reasons, "last_serial":last_serial,
			"full_native_packets":events.filter(
				func(row: Dictionary) -> bool:
					return row.get("event","") == "native_snapshot" and row.get("full",false)).size()}))
		_expect("pending_rectangles" in reasons, "accumulating sparse rectangles exceeded 256")
		_expect("pending_bytes" in reasons,
			"after full recovery, one new delta exceeded full-image pending-byte cap")


func _expect_edit(worker: CyberSimulationWorker, x: int, y: int, material: int) -> bool:
	var queued: bool = worker.queue_emit_disc(x, y, 0, material)
	_expect(queued, "one native source edit admitted")
	return queued
