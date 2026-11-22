extends SceneTree

# Reviewer-origin regressions. Every fault starts from a real native completion
# or bounded mailbox; only observation timestamps are advanced to avoid15s sleeps.
const Host = preload("res://scripts/object_shard_worker_host.gd")
var host
var checks: int = 0
var failures: int = 0
var cases: Array[Dictionary] = []


func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label + " · " + str(host.status if host != null else "No host"))


func _idle() -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		host.poll()
		if host.state == "Idle" and host.pending.is_empty() and host.actions.is_empty() and not host._tick_requested:
			return not host.failed
		# An explicit reset from Held intentionally keeps failed until its exact
		# new-session receipt arrives; observation must keep pumping that reset.
		if host.failed and host.state != "Resetting":
			return false
		await process_frame
	return false


func _state(target: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		host.poll()
		if host.state == target:
			return true
		if host.failed and host.state != "Resetting":
			return false
		await process_frame
	return false


func _receipt() -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var rows: Array[Dictionary] = host.worker.take_results(1)
		if not rows.is_empty():
			return rows[0]
		await process_frame
	return {}


func _open(transport: int, trace_path: String = "") -> bool:
	host = Host.new()
	return host.open({"scenario": 0, "seed": 12}, transport, trace_path).get("ok", false) and await _idle()


func _close() -> bool:
	host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.state != "Closed" and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	return host.state == "Closed"


func _block(origin: Vector2i) -> bool:
	for y: int in range(4):
		for x: int in range(4):
			if not host.queue_action("edit", {"position": origin + Vector2i(x, y), "material": 7}).get("ok", false):
				return false
	return await _idle()


func _retired(action_id: int) -> Dictionary:
	for row: Dictionary in host.retired_action_results:
		if int(row.action_id) == action_id:
			return row
	return {}


func _expire() -> Dictionary:
	host.pending.sent_usec = Time.get_ticks_usec() - Host.RECEIPT_DEADLINE_USEC - 1
	return host.poll(false)


func _invalid_start_identity() -> void:
	host = Host.new()
	var invalid: Dictionary = host.open({"scenario": 0, "seed": 12}, Host.Worker.MAX_EXACT_SEQUENCE + 1)
	_expect(not invalid.get("ok", true) and host.state == "Closed" and host.generation == 0 and
		host.worker == null and host.bridge == null,
		"An out-of-range transport identity refuses before changing the closed host or allocating either owner")
	var oversized := PackedByteArray()
	oversized.resize(4097)
	var oversized_start: Dictionary = host.open({"scenario": 0, "seed": 12, "unused": oversized}, 93000)
	_expect(not oversized_start.get("ok", true) and host.state == "Closed" and host.generation == 0 and
		host.worker == null and host.bridge == null,
		"An invalid configuration value payload cannot consume a generation or enter host state")
	_expect(host.open({"scenario": 0, "seed": 12}, 93000).get("ok", false) and await _idle() and
		int(host.worker.diagnostics().owner_thread) != OS.get_main_thread_id(),
		"The same host accepts a valid retry and constructs its real native owner on the exclusive thread")
	cases.append({"case": "invalid_start_identity", "invalid_identity": invalid, "invalid_payload": oversized_start,
		"recovered_generation": host.generation, "recovered_state": host.state})
	_expect(await _close(), "Valid retry after rejected startup disposes normally")


func _lost_cancel_fence() -> void:
	_expect(await _open(93001), "Lost-cancel test opens actual exclusive native and Rapier owners")
	_expect(await _block(Vector2i(50, 40)), "The first actual World component is authored")
	host.request_tick()
	_expect(await _idle() and host.bridge.bodies.size() == 1, "The first component is an active moving Rapier owner")
	if host.failed or host.bridge.bodies.size() != 1:
		await _close()
		return
	_expect(await _block(Vector2i(80, 40)), "A second actual World component remains independently owned")
	host.defer_prepared_promotion = true
	host.request_tick()
	_expect(await _state("PreparedForReview"), "The second component reaches a genuine precommit preparation")
	var first: Dictionary = host.cancel_prepared()
	var lost: Dictionary = await _receipt()
	_expect(first.get("ok", false) and lost.get("operation") == "cancel" and
		lost.get("result", {}).get("outcome") == "Cancelled" and not lost.get("frame", {}).get("promotion", {}).get("present", true),
		"The lost receipt proves native really cancelled the prepared component")
	if lost.is_empty() or host.pending.is_empty():
		await _close()
		return
	var queued: Dictionary = host.queue_action("edit", {"position": Vector2i(30, 20), "material": 7})
	_expect(queued.get("ok", false), "A later ordinary edit is admitted before the delivery deadline")
	var steps: int = host.bridge.steps
	var completed: int = host.completed_ticks
	var publication: int = host.publication_sequence
	var body: Dictionary = host.bridge.diagnostics().bodies[0].duplicate(true)
	var timeout: Dictionary = _expire()
	_expect(timeout.get("outcome") == "WorkerReceiptDeadlineExceeded" and host.state == "Held" and host.failed,
		"A genuinely missing cancellation result enters explicit Held")
	var retry: Dictionary = host.cancel_prepared()
	_expect(not retry.get("ok", true) and retry.get("outcome") == "HeldUntilExplicitReset",
		"Repeating precommit cancellation cannot escape the failed hold")
	_expect(not host.resume_prepared().get("ok", true) and not host.request_tick().get("ok", true),
		"Resume and semantic tick controls cannot escape the same hold")
	_expect(not host.queue_action("edit", {"position": Vector2i(31, 20), "material": 7}).get("ok", true),
		"New material input has no admission while ownership is held")
	_expect(host.accept_receipt(lost).get("outcome") == "HeldUntilExplicitReset",
		"The late exact cancellation result does not resume failed owners")
	for index: int in range(8):
		host.poll()
		await process_frame
	var after: Dictionary = host.bridge.diagnostics().bodies[0]
	_expect(host.state == "Held" and host.failed and host.bridge.steps == steps and host.completed_ticks == completed and
		host.publication_sequence == publication and after.x == body.x and after.y == body.y and after.vy == body.vy,
		"Real body pose, velocity, clocks and publication remain frozen after the refused retry")
	var observation: Dictionary = host.worker.submit("observe", {}, host.session, host.generation)
	var actual: Dictionary = await _receipt()
	_expect(observation.get("ok", false) and actual.get("operation") == "observe" and
		int(actual.frame.world_materials[20 * 192 + 30]) == 0 and actual.frame.world_materials.count(7) == 16,
		"Read-only native observation proves the queued edit never executed through the failed host")
	_expect(host.reset(0, 12).get("ok", false) and await _idle(), "Explicit disposal reset safely recovers the held native and physics owners")
	var retired: Dictionary = _retired(int(queued.action_id))
	_expect(retired.get("outcome") == "CancelledByReset" and not retired.get("may_have_executed", true),
		"The never-dispatched queued edit receives an exact cancellation disposition")
	_expect(host.bridge.bodies.is_empty() and host.frame.world_materials.count(7) == 0 and
		int(host.frame.accounting.reset_disposed[7]) == 32,
		"Explicit reset disposes both actual components exactly once and never invents the cancelled edit")
	cases.append({"case": "lost_cancel_hold", "retry": retry, "steps_before": steps,
		"held_body_before": body, "held_body_after": after, "retired": retired})
	_expect(await _close(), "Recovered lost-cancel owner shuts down on its exclusive thread")


func _lost_reset_recovery() -> void:
	_expect(await _open(93002), "Lost-reset test opens an actual native session")
	host.queue_action("edit", {"position": Vector2i(20, 20), "material": 7})
	_expect(await _idle(), "The old session contains one real authored Wood cell")
	var original_session: int = host.session
	var publication: int = host.publication_sequence
	_expect(host.reset(0, 12).get("ok", false), "The original explicit reset is admitted")
	var lost: Dictionary = await _receipt()
	_expect(lost.get("operation") == "reset" and lost.get("result", {}).get("ok", false) and
		int(lost.get("frame", {}).get("session", 0)) > original_session,
		"The missing result proves native actually completed a new session")
	if lost.is_empty() or host.pending.is_empty():
		await _close()
		return
	_expect(_expire().get("outcome") == "WorkerReceiptDeadlineExceeded" and host.state == "Held",
		"Lost reset completion reaches Held without adopting its unseen session")
	var retry: Dictionary = host.reset(0, 12)
	_expect(retry.get("ok", false) and int(retry.get("session", 0)) == int(lost.frame.session) and
		host.session == original_session and host.publication_sequence == publication,
		"Recovery uses the current worker identity only for explicit disposal and keeps presentation frozen")
	_expect(host.accept_receipt(lost).get("outcome") == "ExpiredOrDuplicate" and host.state == "Resetting",
		"The earlier reset result cannot replace the new recovery request")
	_expect(await _idle() and host.session > int(lost.frame.session) and not host.failed,
		"The exact recovery receipt finally admits a fresh native session and main physics owner")
	_expect(int(host.frame.accounting.reset_disposed[7]) == 1 and host.frame.world_materials.count(7) == 0,
		"Repeated explicit disposal accounts the original material exactly once")
	var recovered_session: int = host.session
	var recovered_publication: int = host.publication_sequence
	_expect(host.accept_receipt(lost).get("outcome") == "ExpiredOrDuplicate" and
		host.session == recovered_session and host.publication_sequence == recovered_publication,
		"Duplicate old reset delivery remains nonmutating after full recovery")
	cases.append({"case": "lost_reset_recovery", "old_session": original_session,
		"unseen_session": lost.frame.session, "recovered_session": recovered_session, "retry": retry})
	_expect(await _close(), "Recovered reset session disposes cleanly")


func _queued_reset_fence() -> void:
	_expect(await _open(93003), "Queued-reset test opens an actual native owner")
	for index: int in range(8):
		_expect(host.worker.submit("observe", {}, host.session, host.generation).get("ok", false),
			"An independent control observation is actually admitted")
	var deadline: int = Time.get_ticks_msec() + 10000
	while int(host.worker.diagnostics().control_results) != 8 and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(int(host.worker.diagnostics().control_results) == 8, "Eight real replies fill the separate control result capacity")
	var original: int = host.session
	var first: Dictionary = host.reset(0, 12)
	var blocked: Dictionary = host.worker.diagnostics()
	_expect(first.get("ok", false) and int(blocked.pending_control) == 1 and int(blocked.inflight_sequence) == 0,
		"The reset is genuinely queued, unable to start behind a full control reply lane")
	_expect(_expire().get("outcome") == "WorkerReceiptDeadlineExceeded", "A blocked reset has a bounded delivery hold")
	var retry: Dictionary = host.reset(0, 12)
	_expect(not retry.get("ok", true) and retry.get("outcome") == "PreviousResetStillRunning" and
		int(host.worker.diagnostics().pending_control) == 1,
		"Recovery refuses a second disposal while the original reset remains queued or in flight")
	deadline = Time.get_ticks_msec() + 10000
	while (int(host.worker.diagnostics().session) == original or not host.pending.is_empty()) and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	var unseen: int = int(host.worker.diagnostics().session)
	_expect(unseen > original and host.session == original and host.state == "Held",
		"Draining the bounded lane lets native complete the original reset without reviving Held presentation")
	var recovery: Dictionary = host.reset(0, 12)
	_expect(recovery.get("ok", false) and int(recovery.get("session", 0)) == unseen and await _idle(),
		"A later explicit recovery starts only after the earlier reset has actually finished")
	_expect(host.session > unseen and not host.failed, "The admitted recovery binds a strictly newer actual native session")
	cases.append({"case": "queued_reset_fence", "first": first, "retry_while_queued": retry,
		"unseen_session": unseen, "recovery": recovery, "final_session": host.session})
	_expect(await _close(), "Saturated-lane recovery still shuts down cleanly")


func _retirement_dispositions() -> void:
	var trace: String = ProjectSettings.globalize_path("res://tests/review-recovery-actions.jsonl")
	_expect(await _open(93004, trace), "Retirement test opens a real trace and native owner")
	var original_session: int = host.session
	var old_trace: String = host.capture.path
	var inflight: Dictionary = host.queue_action("edit", {"position": Vector2i(20, 20), "material": 7})
	host.poll(false)
	var lost: Dictionary = await _receipt()
	_expect(lost.get("operation") == "edit" and lost.get("result", {}).get("ok", false) and lost.frame.world_materials.count(7) == 1,
		"The unresolved in-flight action really applied before its receipt was withheld")
	var queued: Array[Dictionary] = []
	for index: int in range(3):
		queued.append(host.queue_action("edit", {"position": Vector2i(30 + index, 20), "material": 7}))
	_expect(host.reset(0, 12).get("ok", false), "Explicit reset retires unresolved and never-dispatched input")
	var uncertain: Dictionary = _retired(int(inflight.action_id))
	_expect(uncertain.get("outcome") == "RetiredByResetOutcomeUnknown" and uncertain.get("may_have_executed", false) and
		int(uncertain.get("session", 0)) == original_session,
		"In-flight retirement honestly preserves the original session and unknown execution outcome")
	_expect(not host.capture.complete, "The old trace cannot claim complete replay after unresolved native mutation")
	for ticket: Dictionary in queued:
		var terminal: Dictionary = _retired(int(ticket.action_id))
		_expect(terminal.get("outcome") == "CancelledByReset" and not terminal.get("may_have_executed", true),
			"Every queued action receives a distinct mutation-free reset cancellation")
	_expect(await _idle() and int(host.frame.accounting.reset_disposed[7]) == 1,
		"Native reset disposes only the one effect that actually happened")
	var file: FileAccess = FileAccess.open(old_trace, FileAccess.READ)
	var footer: Dictionary = {}
	if file != null:
		while not file.eof_reached():
			var line: String = file.get_line()
			if line.is_empty():
				continue
			var parsed: Variant = JSON.parse_string(line)
			if parsed is Dictionary and parsed.get("kind") == "footer":
				footer = parsed.detail
		file.close()
	_expect(not footer.is_empty() and not footer.get("complete_prefix", true),
		"The closed previous trace retains its explicit incomplete footer on disk")
	var before: int = host.retired_action_results.size()
	var stopped: Dictionary = host.queue_action("edit", {"position": Vector2i(40, 20), "material": 7})
	_expect(await _close(), "Explicit close terminates the current empty owner")
	var terminal: Dictionary = _retired(int(stopped.action_id))
	_expect(terminal.get("outcome") == "CancelledByStop" and not terminal.get("may_have_executed", true) and
		host.retired_action_results.size() == before + 1,
		"Stop records the final queued action exactly once")
	host.close()
	_expect(host.retired_action_results.size() == before + 1, "Duplicate close cannot duplicate retirement dispositions")
	cases.append({"case": "retirement_dispositions", "uncertain": uncertain,
		"retired": host.retired_action_results.duplicate(true), "old_trace_footer": footer})


func _run() -> void:
	await _invalid_start_identity()
	await _lost_cancel_fence()
	await _lost_reset_recovery()
	await _queued_reset_fence()
	await _retirement_dispositions()
	print(JSON.stringify({"schema": "objectshard-worker-recovery-test-v1", "checks": checks, "failures": failures,
		"scope": "Actual native and Rapier loss, queued control saturation, monotonic failed holds and explicit retirement", "cases": cases}))
	quit(0 if failures == 0 else 1)
