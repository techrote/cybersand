extends SceneTree

const Worker = preload("res://scripts/object_shard_native_worker.gd")
var checks: int = 0
var failures: int = 0
var worker
var mailbox: Array[Dictionary] = []


func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _wait(sequence: int, controls: bool = false) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		mailbox.append_array(worker.take_results(16, controls))
		for at: int in range(mailbox.size()):
			if int(mailbox[at].sequence) == sequence:
				var value: Dictionary = mailbox[at]
				mailbox.remove_at(at)
				return value
		await process_frame
	return {}


func _run() -> void:
	worker = Worker.new()
	_expect(worker.start({"scenario": 0, "seed": 12, "width": 192, "height": 128}, 14001).get("ok", false),
		"Bounded command test starts an actual exclusive native owner")
	var opened: Dictionary = await _wait(0)
	_expect(not opened.is_empty() and opened.result.get("ok", false), "Actual native startup returns its copied frame")
	if opened.is_empty() or not opened.result.get("ok", false):
		await _finish()
		return
	var session: int = int(opened.session)
	var tick: int = int(opened.frame.tick)
	_expect(not worker.submit("edit_batch", {"edits": []}, session, 14001).get("ok", true), "Empty batch has no admission")
	var oversized: Array[Dictionary] = []
	for index: int in range(33):
		oversized.append({"position": Vector2i(10 + index, 10), "material": 7})
	_expect(not worker.submit("edit_batch", {"edits": oversized}, session, 14001).get("ok", true), "The 32-edit batch limit is enforced before enqueue")
	_expect(not worker.submit("edit_batch", {"edits": [{"position": Vector2i(10, 10), "material": 7},
		{"position": Vector2i(11, 10), "material": true}]}, session, 14001).get("ok", true),
		"Malformed later edit rejects the whole request before any native mutation")
	_expect(not worker.submit("inspect", {"position": Vector2(10, 10)}, session, 14001).get("ok", true),
		"Read-only inspection preserves the exact integer position boundary")
	_expect(not worker.submit("edit", {"position": Vector2i(10, 10), "material": 6, "state_a": 100, "temperature": 550, "only_if_empty": 1}, session, 14001).get("ok", true),
		"The fixture-only emptiness precondition accepts an actual boolean, never numeric coercion")
	var edits: Array[Dictionary] = []
	for index: int in range(32):
		edits.append({"position": Vector2i(10 + index, 10), "material": 7, "state_a": 3, "state_b": 0, "temperature": 417})
	var before_snapshots: int = int(worker.diagnostics().snapshot_copies)
	var request: Dictionary = worker.submit("edit_batch", {"edits": edits}, session, 14001)
	edits[0].material = 0
	edits[1].temperature = 999
	edits.clear()
	var applied: Dictionary = await _wait(int(request.sequence))
	_expect(not applied.is_empty() and applied.result.get("ok", false) and applied.result.outcome == "BatchCompleted",
		"A real native batch returns an explicit terminal completion")
	if applied.is_empty():
		await _finish()
		return
	_expect(int(applied.result.accepted) == 32 and int(applied.result.refused) == 0 and applied.result.results.size() == 32,
		"Every ordered native mutation has its own accepted receipt")
	_expect(int(worker.diagnostics().snapshot_copies) == before_snapshots + 1,
		"Thirty-two ordinary edits require one final copied World snapshot")
	_expect(applied.frame.world_materials.count(7) == 32 and int(applied.frame.tick) == tick,
		"Batched authoring neither invents a World nor advances chemistry")
	_expect(int(opened.frame.world_materials[10 * 192 + 10]) == 0,
		"The retained earlier publication stays immutable after the batch")
	var ordered: bool = true
	for index: int in range(applied.result.results.size()):
		ordered = ordered and int(applied.result.results[index].index) == index
		ordered = ordered and applied.result.results[index].position == Vector2i(10 + index, 10)
	_expect(ordered, "Per-cell results preserve exact admitted order and positions")
	var timing_sum: int = int(applied.native_execute_usec) + int(applied.snapshot_usec) + int(applied.receipt_value_accounting_usec)
	_expect(timing_sum == int(applied.worker_total_usec) and int(applied.queue_wait_usec) >= 0,
		"Native, snapshot and receipt timing stages partition worker duration without nested double counting")
	_expect(int(applied.finished_usec) - int(applied.started_usec) == timing_sum and
		int(applied.started_usec) - int(applied.admitted_usec) == int(applied.queue_wait_usec),
		"Monotonic timestamp differences match the reported timing stages")
	request = worker.submit("inspect", {"position": Vector2i(11, 10)}, session, 14001)
	var inspected: Dictionary = await _wait(int(request.sequence))
	_expect(inspected.result.get("ok", false) and int(inspected.result.material) == 7 and
		int(inspected.result.state_a) == 3 and int(inspected.result.state_b) == 0 and int(inspected.result.temperature) == 417,
		"Worker inspection confirms exact material, state and temperature from the copied original request")
	_expect(int(inspected.frame.tick) == tick and inspected.frame.world_materials == applied.frame.world_materials,
		"Read-only native inspection leaves material and semantic clocks unchanged")
	_expect(int(inspected.owner_thread) == int(opened.owner_thread) and int(inspected.owner_thread) != OS.get_main_thread_id(),
		"Authoring and inspection both execute on the same exclusive native owner")
	applied.frame.world_materials[10 * 192 + 11] = 0
	inspected.result.temperature = -900
	request = worker.submit("inspect", {"position": Vector2i(11, 10)}, session, 14001)
	var retained: Dictionary = await _wait(int(request.sequence))
	_expect(int(retained.result.material) == 7 and int(retained.result.temperature) == 417,
		"Caller mutation of consumed publications and inspection receipts cannot change native state")
	request = worker.submit("edit_batch", {"edits": [
		{"position": Vector2i(10, 20), "material": 7},
		{"position": Vector2i(-1, 20), "material": 7},
		{"position": Vector2i(11, 20), "material": 999},
		{"position": Vector2i(12, 20), "material": 7}]}, session, 14001)
	var partial: Dictionary = await _wait(int(request.sequence))
	_expect(partial.result.outcome == "BatchCompleted" and int(partial.result.accepted) == 2 and int(partial.result.refused) == 2,
		"A partially admissible batch reports its explicit per-cell success and refusal totals")
	_expect(partial.result.results[0].ok and not partial.result.results[1].ok and not partial.result.results[2].ok and partial.result.results[3].ok,
		"A refusal neither hides later accepted edits nor fabricates atomic rollback")
	_expect(int(partial.frame.world_materials[20 * 192 + 10]) == 7 and int(partial.frame.world_materials[20 * 192 + 11]) == 0 and
		int(partial.frame.world_materials[20 * 192 + 12]) == 7, "Copied final material agrees with the full mixed-outcome ledger")
	# These are queued without a main receipt gap: the external fixture must
	# inspect native occupancy when it executes, after the earlier Sand edit.
	var sand: Dictionary = worker.submit("edit", {"position": Vector2i(70, 20), "material": 2}, session, 14001)
	var burner: Dictionary = worker.submit("edit", {"position": Vector2i(70, 20), "material": 6, "state_a": 100, "temperature": 550, "only_if_empty": true}, session, 14001)
	var sand_result: Dictionary = await _wait(int(sand.sequence))
	var burner_result: Dictionary = await _wait(int(burner.sequence))
	_expect(sand_result.result.get("ok", false) and burner_result.result.outcome == "FixtureCellOccupied" and
		int(burner_result.frame.world_materials[20 * 192 + 70]) == 2,
		"A delayed external flame refuses to replace Sand that arrived after its input-time observation")
	request = worker.submit("edit", {"position": Vector2i(71, 20), "material": 6, "state_a": 100, "temperature": 550, "only_if_empty": true}, session, 14001)
	var empty_burner: Dictionary = await _wait(int(request.sequence))
	_expect(empty_burner.result.get("ok", false) and int(empty_burner.frame.world_materials[20 * 192 + 71]) == 6,
		"The same fixture can author genuine Fire into a still-empty World cell")
	# A full reply lane blocks queued data. Reset can still pass through its
	# independent control lane, making the next queued batch genuinely stale.
	for index: int in range(32):
		worker.submit("snapshot", {}, session, 14001)
	var deadline: int = Time.get_ticks_msec() + 10000
	while int(worker.diagnostics().data_results) < 32 and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(int(worker.diagnostics().data_results) == 32, "The real bounded reply lane is saturated before the reset adversary")
	var obsolete: Dictionary = worker.submit("edit_batch", {"edits": [{"position": Vector2i(80, 20), "material": 7}]}, session, 14001)
	var reset: Dictionary = worker.submit("reset", {"scenario": 0, "seed": 12}, session, 14001)
	var restarted: Dictionary = await _wait(int(reset.sequence), true)
	_expect(restarted.result.get("ok", false) and int(restarted.session) != session, "Control reset disposes the old session before the queued batch")
	var obsolete_result: Dictionary = await _wait(int(obsolete.sequence))
	_expect(obsolete_result.result.outcome == "StaleTransportIdentity" and int(obsolete_result.frame.world_materials[20 * 192 + 80]) == 0,
		"An already admitted batch cannot debit or author the replacement World")
	_expect(int(obsolete.sequence) < int(reset.sequence) and int(reset.sequence) > int(request.sequence),
		"Transport identities remain unique and monotonic even when the control lane overtakes data")
	await _finish()


func _finish() -> void:
	worker.request_stop()
	var deadline: int = Time.get_ticks_msec() + 10000
	while not worker.diagnostics().stopped and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(worker.join_if_stopped().get("ok", false), "The command owner disposes on its own thread")
	print(JSON.stringify({"schema": "objectshard-worker-command-test-v1", "checks": checks, "failures": failures,
		"scope": "Real native worker ordered bounded editing and exact inspection; no ordinary Workbench attachment claim",
		"transport": worker.diagnostics()}))
	quit(0 if failures == 0 else 1)
