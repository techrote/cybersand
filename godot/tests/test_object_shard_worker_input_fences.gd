extends SceneTree

const Host = preload("res://scripts/object_shard_worker_host.gd")
var host = Host.new()
var checks: int = 0
var failures: int = 0
var notifications: int = 0
var foreign_notifications: int = 0


func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label + " · " + host.status)


func _notice() -> void:
	notifications += 1
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		foreign_notifications += 1


func _idle() -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		host.poll()
		if host.failed:
			return false
		if host.state == "Idle" and host.actions.is_empty() and host.pending.is_empty() and not host._tick_requested:
			return true
		await process_frame
	return false


func _tick() -> bool:
	var before: int = host.completed_ticks
	return host.request_tick().get("ok", false) and await _idle() and host.completed_ticks == before + 1


func _structural() -> int:
	var count: int = 0
	for shard: Dictionary in host.frame.get("shards", []):
		if shard.get("owns_inventory", false):
			count += int(shard.structural)
	return count


func _hit() -> Dictionary:
	for shard: Dictionary in host.publication.get("shards", []):
		var transform := Transform2D(float(shard.rotation), Vector2(float(shard.position_x), float(shard.position_y)))
		# Prefer the interior: one real falling interval changes pose identity
		# while this World coordinate remains inside the same moving body.
		var order: Array[int] = []
		order.append((int(shard.height) / 2) * int(shard.width) + int(shard.width) / 2)
		for cell: int in range(shard.materials.size()):
			order.append(cell)
		for cell: int in order:
			if cell < 0 or cell >= shard.materials.size() or int(shard.roles[cell]) != 1:
				continue
			var point: Vector2 = transform * (Vector2(cell % int(shard.width), cell / int(shard.width)) + Vector2.ONE * 0.5)
			var position := Vector2i(floori(point.x), floori(point.y))
			var target: Dictionary = host.capture_target(position)
			if int(target.get("owner", 0)) == int(shard.id):
				return target
	return {}


func _run() -> void:
	_expect(host.open({"scenario": 0, "seed": 12, "width": 192, "height": 128}, 42001).get("ok", false),
		"Input-fence host opens one actual worker and Rapier owner")
	host.worker.results_available.connect(Callable(self, "_notice"), CONNECT_DEFERRED)
	_expect(await _idle(), "The real startup and initial terrain installation finish")
	if host.failed or host.state != "Idle":
		await _finish()
		return
	var ids: Array[int] = []
	for index: int in range(32):
		var queued: Dictionary = host.queue_action("edit", {"position": Vector2i(10 + index, 20), "material": 2})
		if queued.get("ok", false):
			ids.append(int(queued.action_id))
	_expect(ids.size() == 32 and host.actions.size() == 32, "Exactly32 pointer edits fit the bounded host queue")
	var overflow: Dictionary = host.queue_action("edit", {"position": Vector2i(70, 20), "material": 2})
	_expect(not overflow.get("ok", true) and overflow.outcome == "ActionCapacity" and host.actions.size() == 32,
		"The33rd action visibly refuses without removing any admitted input")
	_expect(host.request_tick().get("ok", false), "A semantic interval is requested behind the full edit backlog")
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.completed_ticks == 0 and not host.failed and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	_expect(host.completed_ticks == 1 and host.action_results.size() <= Host.ACTIONS_PER_TICK,
		"The requested real physics/native interval completes after at most four queued edits")
	_expect(host.actions.size() >= 27, "Fairness retains the remaining user inputs instead of discarding them")
	_expect(await _idle(), "All remaining admitted edits reach terminal results after the interval")
	var terminal_ids: Array[int] = []
	var accepted: int = 0
	for row: Dictionary in host.action_results:
		terminal_ids.append(int(row.action_id))
		if row.ok:
			accepted += 1
	_expect(terminal_ids == ids and accepted == 32, "Every accepted pointer command completes exactly once and in order")
	_expect(host.frame.world_materials.count(2) == 32, "The real native Sand inventory agrees with32 admitted material edits")
	_expect(notifications > 0 and foreign_notifications == 0,
		"Deferred mailbox notifications arrive on main without moving native or RID authority")
	_expect(host.queue_action("inspect", {"position": Vector2i(41, 20)}).get("ok", false) and await _idle(),
		"A read-only inspector request uses the bounded actual worker route")
	_expect(host.last_inspection.get("owner") == "World" and int(host.last_inspection.get("material", -1)) == 2,
		"World inspection identifies the authoritative owner and actual material")
	_expect(host.reset(0, 12).get("ok", false) and await _idle(), "Explicit native reset clears the first fixture safely")
	for half: int in range(2):
		var edits: Array[Dictionary] = []
		for index: int in range(32):
			edits.append({"position": Vector2i(44 + index % 8, 40 + half * 4 + index / 8), "material": 7})
		_expect(host.author_batch(edits).get("ok", false) and await _idle() and int(host.last_author_result.get("accepted", 0)) == 32,
			"Bounded author batch deposits32 real Wood cells with acknowledged final publication")
	_expect(host.frame.world_materials.count(7) == 64 and _structural() == 0, "World owns all64 authored cells before detachment admission")
	for attempt: int in range(8):
		if _structural() == 64 or not await _tick():
			break
	_expect(_structural() == 64 and host.bridge.bodies.size() == 1 and host.frame.world_materials.count(7) == 0,
		"The authored block transfers once and becomes an actual active Rapier body")
	if _structural() != 64 or host.failed:
		await _finish()
		return
	var old_target: Dictionary = _hit()
	_expect(not old_target.is_empty() and int(old_target.owner) > 0, "Pointer capture records an actual moving-owner witness")
	var position: Vector2i = old_target.position
	_expect(await _tick(), "One genuine falling interval advances that body's native pose serial")
	var later_target: Dictionary = host.capture_target(position)
	_expect(int(later_target.get("owner", 0)) == int(old_target.owner) and later_target.pose_serial != old_target.pose_serial,
		"The stale pointer still overlaps the same body but carries an obsolete pose")
	_expect(host.queue_action("edit", {"position": position, "material": 0, "target": old_target}).get("ok", false) and await _idle(),
		"A queued stale same-body cut reaches an explicit terminal refusal")
	_expect(host.last_action.get("outcome") == "TargetChanged" and _structural() == 64,
		"Stale falling/rotating intent never remaps onto another cell of the same body")
	var fresh: Dictionary = _hit()
	var captured_cell: int = int(fresh.cell)
	var captured_id: int = int(fresh.owner)
	var parameters: Dictionary = {"position": fresh.position, "material": 0, "target": fresh}
	_expect(host.queue_action("edit", parameters).get("ok", false), "A fresh exact moving-material witness is admitted")
	fresh.cell = 99999
	fresh.expected.material = 0
	parameters.position = Vector2i(1, 1)
	_expect(await _idle() and host.last_action.get("ok", false) and _structural() == 63,
		"Mutation of caller-owned input dictionaries cannot redirect the admitted one-cell erase")
	var changed: Dictionary = {}
	for shard: Dictionary in host.frame.shards:
		if int(shard.id) == captured_id:
			changed = shard
	_expect(not changed.is_empty() and int(changed.roles[captured_cell]) == 0 and changed.applied_physics_revision == changed.geometry_revision,
		"The originally captured cell is erased and actual replacement geometry is acknowledged")
	var malformed: Dictionary = host.queue_action("edit", {"position": position, "material": 0, "target": "obsolete"})
	_expect(not malformed.get("ok", true) and malformed.outcome == "InvalidInputTarget" and host.actions.is_empty() and not host.failed,
		"Malformed target values refuse safely without a queued mutation or host fault")
	var owned_inspect: Dictionary = _hit()
	_expect(host.queue_action("inspect", {"position": owned_inspect.position}).get("ok", false) and await _idle(),
		"Inspecting current moving material remains a bounded live operation")
	_expect(host.last_inspection.get("owner") == "ObjectShard" and int(host.last_inspection.get("material", -1)) == 7,
		"Moving-material inspection reports its actual owner, not the empty World cell beneath it")
	var old_session: int = host.session
	_expect(host.reset(0, 12).get("ok", false) and await _idle() and host.session != old_session,
		"Reset retires the native session and its formerly moving target")
	var retired: Dictionary = host.queue_action("edit", {"position": owned_inspect.position, "material": 0, "target": owned_inspect})
	_expect(not retired.get("ok", true) and retired.outcome == "InvalidInputTarget" and host.actions.is_empty(),
		"A target from the retired native generation cannot debit replacement material")
	var sequence: int = host.publication_sequence
	_expect(host.mark_presented(sequence).get("ok", false), "The current coherent publication accepts one observed draw")
	var before_samples: int = host.timings.get("publication_to_presented_usec", []).size()
	var duplicate: Dictionary = host.mark_presented(sequence)
	_expect(not duplicate.get("ok", true) and duplicate.outcome == "StaleOrDuplicatePresentation" and
		host.timings.get("publication_to_presented_usec", []).size() == before_samples and host.publication_sequence == sequence,
		"Duplicate presentation observation changes neither source publication nor timing sample inventory")
	await _delivery_faults()
	await _finish()


func _delivery_faults() -> void:
	# Exercise the optional notification path with an explicit delivery hold.
	# The worker still completes a real native tick, but its queued reply cannot
	# authorize physics or another semantic interval until main consumes it.
	_expect(host.set_event_driven(true).get("ok", false) and host.set_receipt_hold(true).get("ok", false),
		"Deferred delivery can be explicitly held before any interval is requested")
	var before_ticks: int = host.completed_ticks
	var before_physics: int = int(host.bridge.diagnostics().last_completed_semantic_tick)
	var before_publication: int = host.publication_sequence
	_expect(host.request_tick().get("ok", false), "One real interval is requested while deferred receipts are held")
	host.poll(false)
	var held_sequence: int = int(host.pending.get("sequence", 0))
	var held_receipt: int = host.last_receipt_sequence
	for index: int in range(8):
		await process_frame
	_expect(held_sequence > 0 and int(host.pending.get("sequence", 0)) == held_sequence and
		host.last_receipt_sequence == held_receipt and host.completed_ticks == before_ticks and
		host.publication_sequence == before_publication and
		int(host.bridge.diagnostics().last_completed_semantic_tick) == before_physics,
		"Eight notification-capable frames cannot consume the held receipt, publish it, or advance Rapier")
	_expect(int(host.worker.diagnostics().data_results) > 0,
		"The delivery hold retains a genuinely completed native reply rather than preventing native execution")
	_expect(host.set_receipt_hold(false).get("ok", false) and await _idle() and host.completed_ticks == before_ticks + 1,
		"Releasing deferred delivery completes exactly the requested native/physics interval")
	for index: int in range(8):
		host.poll()
		await process_frame
	_expect(host.completed_ticks == before_ticks + 1 and host.pending.is_empty() and not host._tick_requested,
		"Later queued notifications cannot fabricate an additional semantic tick")
	# Lose one successful data receipt after native mutation, then exercise the
	# deadline by moving only its observation timestamp. No test wait is needed
	# and the actual authoritative mutation remains present on the worker.
	host.set_receipt_hold(true)
	var disposed_before: int = int(host.frame.accounting.reset_disposed[7])
	var prior_session: int = host.session
	before_publication = host.publication_sequence
	_expect(host.queue_action("edit", {"position": Vector2i(20, 20), "material": 7}).get("ok", false),
		"The lost-receipt adversary starts with an admitted real Wood edit")
	host.poll(false)
	var deadline: int = Time.get_ticks_msec() + 10000
	while int(host.worker.diagnostics().data_results) == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	var completed: Array[Dictionary] = host.worker.take_results(1)
	_expect(completed.size() == 1 and completed[0].operation == "edit" and completed[0].result.get("ok", false) and
		completed[0].frame.world_materials.count(7) == 1 and host.frame.world_materials.count(7) == 0,
		"The removed receipt proves native accepted one Wood cell that main has not published")
	if completed.size() != 1 or host.pending.is_empty():
		return
	host.pending.sent_usec = Time.get_ticks_usec() - Host.RECEIPT_DEADLINE_USEC - 1
	var expired: Dictionary = host.poll(false)
	_expect(not expired.get("ok", true) and expired.get("outcome") == "WorkerReceiptDeadlineExceeded" and
		host.failed and host.state == "Held" and host.publication_sequence == before_publication,
		"A missing completed edit receipt reaches bounded Held without publishing uncertain ownership")
	var late: Dictionary = host.accept_receipt(completed[0])
	_expect(not late.get("ok", true) and late.get("outcome") == "HeldUntilExplicitReset" and
		host.state == "Held" and host.publication_sequence == before_publication,
		"A late successful receipt cannot revive a held session or reveal its unpublished edit")
	_expect(host.reset(0, 12).get("ok", false), "Explicit reset remains admitted after a lost-receipt hold")
	host.set_receipt_hold(false)
	deadline = Time.get_ticks_msec() + 10000
	while host.state == "Resetting" and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	_expect(await _idle() and not host.failed and host.session != prior_session and host.frame.world_materials.count(7) == 0 and
		int(host.frame.accounting.reset_disposed[7]) == disposed_before + 1,
		"Recovery accounts the unpublished Wood cell exactly once in reset disposal and resumes a fresh owner")


func _finish() -> void:
	var diagnostics: Dictionary = host.diagnostics()
	host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.state != "Closed" and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	_expect(host.state == "Closed", "The exact worker/Rapier test session shuts down cleanly")
	print(JSON.stringify({"schema": "objectshard-worker-input-fences-v1", "checks": checks, "failures": failures,
		"notifications": notifications, "foreign_notifications": foreign_notifications, "report": diagnostics}))
	quit(0 if failures == 0 else 1)
