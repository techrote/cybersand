class_name CyberObjectShardWorkerHost
extends RefCounted

# Standalone M3 ownership rehearsal. This is not attached to the Workbench's
# immutable GCR roster or its World. Native owns one World on its worker;
# main owns one real Rapier space. Every async boundary is an applied receipt.
const Worker = preload("res://scripts/object_shard_native_worker.gd")
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
const Capture = preload("res://scripts/object_shard_capture.gd")
const ACTION_CAPACITY: int = 32
const EVENT_CAPACITY: int = 256
const ACTIONS_PER_TICK: int = 4
const TIMING_CAPACITY: int = 2048
const NOTIFICATION_RECEIPTS_PER_FRAME: int = 16
const NOTIFICATION_BUDGET_USEC: int = 2000
const RECEIPT_DEADLINE_USEC: int = 15000000
# Diagnostic upper bound only: the same one authoritative Rapier Main and
# exclusive native worker remain. Never spin without an explicit wall budget.
const MAX_RECEIPT_PUMP_USEC: int = 12000

var worker
var bridge
var capture = Capture.new()
var frame: Dictionary = {}
var publication: Dictionary = {}
var publication_sequence: int = 0
var capabilities: Dictionary = {}
var state: String = "Closed"
var status: String = "Standalone asynchronous ownership rehearsal"
var generation: int = 0
var session: int = 0
var failed: bool = false
var pending: Dictionary = {}
var actions: Array[Dictionary] = []
var events: Array[Dictionary] = []
var last_action: Dictionary = {}
var last_author_result: Dictionary = {}
var last_inspection: Dictionary = {}
var timings: Dictionary = {}
var timing_totals: Dictionary = {}
var action_results: Array[Dictionary] = []
var retired_action_results: Array[Dictionary] = []
var _held_request: Dictionary = {}
var _author_edits: Array[Dictionary] = []
var _action_sequence: int = 0
var _actions_since_tick: int = 0
var _publication_usec: int = 0
var _presented_sequence: int = 0
var _pending_visible_actions: Array[Dictionary] = []
var _awaiting_publication_actions: Array[Dictionary] = []
var _timing_summary_cache: Dictionary = {}
var _timing_summary_usec: int = 0
var event_driven_receipts: bool = false
var _receipt_consumption_allowed: bool = true
var _notification_receipts_left: int = 0
var _notification_usec_left: int = 0
var _inside_notification: bool = false
var _opening_started_usec: int = 0
var _closing_started_usec: int = 0
var completed_ticks: int = 0
var last_receipt_sequence: int = 0
var retired_sequence: int = 0
var rejected_receipts: int = 0
var maximum_wait_usec: int = 0
var maximum_tick_usec: int = 0
var maximum_actions: int = 0
var last_reset_wait_usec: int = 0
var defer_prepared_promotion: bool = false
var _configuration: Dictionary = {}
var _requested_configuration: Dictionary = {}
var _current_action: Dictionary = {}
var _sync_continuation: String = ""
var _tick_requested: bool = false
var _tick_started_usec: int = 0
var _last_tick: int = 0
var _promotion_started_usec: int = 0
var _trace_path: String = ""
var _package_identity: Dictionary = {}
var _fresh_native_registry: bool = true


func open(configuration: Dictionary, transport_generation: int, trace_path: String = "") -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or state != "Closed":
		return {"ok": false, "outcome": "MainOwnerOrClosedRequired"}
	if transport_generation <= generation:
		return {"ok": false, "outcome": "FreshTransportGenerationRequired"}
	if transport_generation > Worker.MAX_EXACT_SEQUENCE or not Worker._copyable(configuration):
		return {"ok": false, "outcome": "InvalidTransportStart"}
	bridge = Bridge.new()
	for method: String in ["begin_motion_tick", "advance_motion_segment", "acknowledge_motion_segment"]:
		if not bridge.has_method(method):
			bridge = null
			return {"ok": false, "outcome": "IncrementalPhysicsBarrierUnavailable", "method": method}
	worker = Worker.new()
	# The signal carries no World data or authority. Deferred delivery guarantees
	# only the main owner may consume a receipt and touch Rapier.
	worker.results_available.connect(_on_results_available, CONNECT_DEFERRED)
	frame = {}
	publication = {}
	capabilities = {}
	session = 0
	failed = false
	pending.clear()
	actions.clear()
	events.clear()
	retired_action_results.clear()
	_held_request.clear()
	_current_action.clear()
	_tick_requested = false
	completed_ticks = 0
	last_receipt_sequence = 0
	retired_sequence = 0
	rejected_receipts = 0
	maximum_wait_usec = 0
	maximum_tick_usec = 0
	maximum_actions = 0
	last_reset_wait_usec = 0
	_clear_session_observations()
	_requested_configuration.clear()
	_configuration = configuration.duplicate(true)
	_fresh_native_registry = true
	_trace_path = trace_path
	var started: Dictionary = worker.start(configuration, transport_generation)
	if not started.get("ok", false):
		worker = null
		bridge = null
		return started
	generation = transport_generation
	state = "Opening"
	_opening_started_usec = Time.get_ticks_usec()
	status = "Waiting for worker-owned native World"
	return started


func poll(consume_receipts: bool = true) -> Dictionary:
	# The UI calls this without waiting. In particular, no queue lock spans a
	# native call or a frame, and no worker queue receipt authorizes physics.
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if worker == null:
		return {"ok": false, "outcome": "NoWorker"}
	if not _inside_notification:
		_receipt_consumption_allowed = consume_receipts
		_notification_receipts_left = NOTIFICATION_RECEIPTS_PER_FRAME
		_notification_usec_left = NOTIFICATION_BUDGET_USEC
	if state == "Closing":
		var terminal: Dictionary = worker.diagnostics().terminal
		if terminal.get("outcome", "") == "StopDisposalRefused":
			state = "ShutdownHeld"
			failed = true
			status = "Native shutdown refused; exact owner retained: " + str(terminal.disposal)
			_event("ShutdownHeld", terminal)
			return {"ok": false, "outcome": "ShutdownHeld", "terminal": terminal}
		var joined: Dictionary = worker.join_if_stopped()
		if joined.get("ok", false):
			bridge.shutdown()
			capture.close()
			state = "Closed"
			status = "Worker disposed its session; main released the RIDs"
			_event("Stopped", joined)
		elif Time.get_ticks_usec() - _closing_started_usec > RECEIPT_DEADLINE_USEC:
			state = "ShutdownHeld"
			failed = true
			status = "Worker shutdown deadline exceeded; native owner and RIDs retained. Export evidence, then retry close."
			_event("ShutdownDeadlineExceeded", worker.diagnostics())
		return {"ok": true, "outcome": state}
	if state == "Opening" and Time.get_ticks_usec() - _opening_started_usec > RECEIPT_DEADLINE_USEC:
		return _hold("WorkerStartupDeadlineExceeded", worker.diagnostics())
	if not pending.is_empty() and Time.get_ticks_usec() - int(pending.sent_usec) > RECEIPT_DEADLINE_USEC:
		return _hold("WorkerReceiptDeadlineExceeded", {"pending": pending.duplicate(true), "worker": worker.diagnostics()})
	if consume_receipts:
		for receipt: Dictionary in worker.take_results(16):
			accept_receipt(receipt)
	if not failed and state == "Idle" and pending.is_empty():
		_drive_idle()
	return {"ok": not failed, "outcome": state}


func set_event_driven(enabled: bool) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	event_driven_receipts = enabled
	return {"ok": true, "outcome": "NotificationModeChanged", "enabled": enabled}


func pump_receipts(budget_usec: int) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	var budget: int = clampi(budget_usec, 0, MAX_RECEIPT_PUMP_USEC)
	if budget == 0 or not _receipt_consumption_allowed or failed or worker == null:
		return {"ok": true, "outcome": "PumpInactive", "callbacks": 0, "elapsed_usec": 0}
	var started: int = Time.get_ticks_usec()
	var callbacks: int = 0
	# This opt-in rendezvous is wall-time bounded, yields the CPU while the
	# exclusive worker runs, and never starts a semantic interval on its own.
	# One already-started receipt handler can finish beyond the loop budget;
	# its actual duration is measured, never represented as a hard realtime cap.
	while Time.get_ticks_usec() - started < budget and callbacks < NOTIFICATION_RECEIPTS_PER_FRAME:
		if pending.is_empty() or state in ["Closed", "Closing", "Held", "ShutdownHeld"]:
			break
		var before: int = last_receipt_sequence
		poll(true)
		if last_receipt_sequence != before:
			callbacks += 1
		else:
			OS.delay_usec(50)
	var elapsed: int = Time.get_ticks_usec() - started
	_sample("main_receipt_pump_usec", elapsed)
	return {"ok": not failed, "outcome": "PumpCompleted", "callbacks": callbacks, "elapsed_usec": elapsed, "budget_usec": budget}


func set_receipt_hold(held: bool) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	_receipt_consumption_allowed = not held
	return {"ok": true, "outcome": "ReceiptHoldChanged", "held": held}


func _on_results_available() -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or not event_driven_receipts or _inside_notification:
		return
	if not _receipt_consumption_allowed or _notification_receipts_left <= 0 or _notification_usec_left <= 0:
		return
	var started: int = Time.get_ticks_usec()
	var before: int = last_receipt_sequence
	_inside_notification = true
	poll(true)
	_inside_notification = false
	_notification_receipts_left -= maxi(1, int(last_receipt_sequence > before))
	_notification_usec_left -= Time.get_ticks_usec() - started


func request_tick() -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if failed or state in ["Closed", "Opening", "Closing", "Resetting", "ShutdownHeld"]:
		return {"ok": false, "outcome": "Unavailable"}
	if _tick_requested:
		return {"ok": false, "outcome": "TickAlreadyRequested"}
	_tick_requested = true
	return {"ok": true, "outcome": "TickQueued"}


func queue_action(name: String, parameters: Dictionary, input_captured_usec: int = 0) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if name not in ["edit", "ignite", "inspect"] or not parameters.get("position") is Vector2i:
		return {"ok": false, "outcome": "UnsupportedNamedAction"}
	if failed or session <= 0 or state in ["Closed", "Opening", "Closing", "Resetting", "ShutdownHeld"]:
		return {"ok": false, "outcome": "Unavailable"}
	if actions.size() >= ACTION_CAPACITY:
		return {"ok": false, "outcome": "ActionCapacity"}
	var position: Vector2i = parameters.position
	if position.x < 0 or position.y < 0 or position.x >= int(frame.width) or position.y >= int(frame.height):
		return {"ok": false, "outcome": "NotResident"}
	if not Worker._copyable(parameters) or (name == "edit" and not Worker._typed_parameters("edit", parameters)):
		return {"ok": false, "outcome": "InvalidNamedAction"}
	var admitted_usec: int = Time.get_ticks_usec()
	if input_captured_usec < 0 or input_captured_usec > admitted_usec:
		return {"ok": false, "outcome": "InvalidInputObservationTime"}
	# Observational only: scene input can wait in its bounded queue before
	# host admission. Preserve that time without granting material authority.
	var captured_usec: int = input_captured_usec if input_captured_usec > 0 else admitted_usec
	var copied: Dictionary = parameters.duplicate(true)
	if copied.has("target") and not copied.target is Dictionary:
		return {"ok": false, "outcome": "InvalidInputTarget"}
	var target: Dictionary = copied.get("target", capture_target(position))
	if not _valid_target(target, position):
		return {"ok": false, "outcome": "InvalidInputTarget"}
	copied["target"] = target.duplicate(true)
	if name == "edit":
		for key: String in ["state_a", "state_b", "temperature"]:
			if not copied.has(key):
				copied[key] = 200 if key == "temperature" else 0
	_action_sequence += 1
	actions.append({"name": name, "parameters": copied, "session": session,
		"action_id": _action_sequence, "captured_usec": captured_usec, "admitted_usec": admitted_usec,
		"input_observation": "scene_intent" if input_captured_usec > 0 else "host_admission",
		"requested_tick": publication.get("tick", 0), "requested_owner": target.owner})
	maximum_actions = maxi(maximum_actions, actions.size())
	return {"ok": true, "outcome": "ActionQueued", "pending": actions.size(), "action_id": _action_sequence}


func author_batch(edits: Array) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if state != "Idle" or failed or _tick_requested or not actions.is_empty() or not frame.get("shards", []).is_empty():
		return {"ok": false, "outcome": "PausedEmptyOwnerFixtureRequired"}
	if not Worker._typed_parameters("edit_batch", {"edits": edits}) or not Worker._copyable(edits):
		return {"ok": false, "outcome": "InvalidFixtureBatch"}
	_author_edits.assign(edits.duplicate(true))
	last_author_result = {}
	return _send("edit_batch", {"edits": edits}, "author_batch")


func capture_target(position: Vector2i, observed_publication: Dictionary = {}) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {}
	# UI callers pass the snapshot actually submitted to their view. Deferred
	# receipts can advance host publication before the next visible frame.
	return _target_from(publication if observed_publication.is_empty() else observed_publication, position)


func _target_from(source: Dictionary, position: Vector2i) -> Dictionary:
	var target: Dictionary = {"session": source.get("session", 0), "transport_generation": generation,
		"position": position, "publication_sequence": publication_sequence, "owner": 0}
	var owned: Dictionary = _owned_cell(source, position)
	if owned.is_empty():
		return target
	var shard: Dictionary = owned.shard
	var cell: int = int(owned.cell)
	target["owner"] = int(owned.id)
	target["cell"] = cell
	for key: String in ["generation", "body_generation", "geometry_revision", "applied_physics_revision", "pose_serial", "material_revision"]:
		target[key] = shard[key]
	target["incarnation"] = shard.incarnations[cell]
	target["expected"] = {"material": shard.materials[cell], "state_a": shard.states_a[cell],
		"state_b": shard.states_b[cell], "temperature": shard.temperature[cell]}
	return target


func _valid_target(target: Dictionary, position: Vector2i) -> bool:
	if target.get("position") != position or target.get("session") != session or target.get("transport_generation") != generation:
		return false
	if not target.get("owner") is int or not target.get("publication_sequence") is int:
		return false
	if int(target.owner) != 0:
		for key: String in ["cell", "generation", "body_generation", "geometry_revision", "applied_physics_revision", "pose_serial", "material_revision", "incarnation"]:
			if not target.get(key) is int:
				return false
		if not target.get("expected") is Dictionary:
			return false
	return true


func _target_matches(target: Dictionary, position: Vector2i) -> bool:
	if not _valid_target(target, position):
		return false
	var actual: Dictionary = _target_from(frame, position)
	# Publication sequence is observational; exact native identity is authority.
	actual.erase("publication_sequence")
	var expected: Dictionary = target.duplicate(true)
	expected.erase("publication_sequence")
	return actual == expected


func reset(scenario: int, seed: int) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if worker == null or session <= 0 or state in ["Opening", "Closed", "Closing", "Resetting", "ShutdownHeld"]:
		return {"ok": false, "outcome": "Unavailable"}
	# A successful reset can outlive a lost receipt. Observe the worker's
	# current identity solely to authorize explicit disposal; do not adopt its
	# unseen World, publication or body identities for any ordinary operation.
	var owner: Dictionary = worker.diagnostics()
	var disposal_session: int = int(owner.get("session", 0))
	if int(owner.get("transport_generation", 0)) != generation or disposal_session <= 0:
		return {"ok": false, "outcome": "NativeOwnerIdentityUnavailable"}
	if _held_request.get("purpose", "") == "reset" and int(owner.get("inflight_sequence", 0)) == int(_held_request.get("sequence", -1)):
		return {"ok": false, "outcome": "PreviousResetStillRunning"}
	var ticket: Dictionary = worker.submit("reset", {"scenario": scenario, "seed": seed}, disposal_session, generation)
	if not ticket.get("ok", false):
		return ticket
	# A reset is explicit whole-session disposal. Old work may finish before the
	# control reaches the worker, but its reply can never resume old physics.
	retired_sequence = int(ticket.sequence) - 1
	_retire_actions("Reset")
	_tick_requested = false
	_requested_configuration = _configuration.duplicate(true)
	_requested_configuration.scenario = scenario
	_requested_configuration.seed = seed
	pending = ticket.duplicate(true)
	pending["purpose"] = "reset"
	pending["sent_usec"] = Time.get_ticks_usec()
	state = "Resetting"
	_event("ResetRequested", {"retired_sequence": retired_sequence, "scenario": scenario, "seed": seed})
	return ticket


func cancel_prepared() -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if state in ["Closing", "Closed", "ShutdownHeld"]:
		return {"ok": false, "outcome": "TransportClosingOrClosed"}
	if failed or state == "Held":
		return {"ok": false, "outcome": "HeldUntilExplicitReset"}
	if not bool(frame.get("promotion", {}).get("present", false)):
		return {"ok": false, "outcome": "NoPreparedPromotion"}
	# The native protocol decides whether commit already occurred. Do not claim
	# mutation-free cancellation merely because an acknowledgement is delayed.
	if not pending.is_empty():
		return {"ok": false, "outcome": "ReceiptPendingUseResetOrAwait"}
	return _send("cancel", {"transaction": frame.promotion.transaction}, "cancel")


func resume_prepared() -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if failed or state != "PreparedForReview" or not pending.is_empty():
		return {"ok": false, "outcome": "NoPreparedBarrier"}
	_reserve()
	return {"ok": not failed, "outcome": "PromotionResumed"}


func close() -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if worker == null or state in ["Closed", "Closing"]:
		return {"ok": true, "outcome": state}
	_tick_requested = false
	_retire_actions("Stop")
	retired_sequence = maxi(retired_sequence, int(pending.get("sequence", 0)))
	pending.clear()
	state = "Closing"
	_closing_started_usec = Time.get_ticks_usec()
	worker.request_stop()
	return {"ok": true, "outcome": "Closing"}


func accept_receipt(receipt: Dictionary) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if state in ["Closing", "Closed", "ShutdownHeld"]:
		return {"ok": false, "outcome": "TransportClosingOrClosed"}
	if state == "Held":
		return _reject_receipt("HeldUntilExplicitReset")
	if not receipt.get("transport_generation") is int or int(receipt.transport_generation) != generation:
		return _reject_receipt("StaleTransportGeneration")
	if not receipt.get("sequence") is int or not receipt.get("result") is Dictionary or not receipt.get("frame") is Dictionary:
		return _hold("MalformedWorkerReceipt", receipt)
	var sequence: int = int(receipt.sequence)
	if sequence == 0 and state == "Opening":
		if receipt.get("operation") != "opened":
			return _hold("WorkerOperationMismatch", {"expected": "opened", "received": receipt.get("operation")})
		return _opened(receipt)
	if sequence <= retired_sequence or sequence <= last_receipt_sequence:
		return _reject_receipt("ExpiredOrDuplicate")
	if pending.is_empty() or sequence != int(pending.sequence):
		return _hold("UnexpectedWorkerSequence", {"receipt": sequence, "pending": pending.get("sequence", 0)})
	if receipt.get("operation") != pending.get("operation"):
		return _hold("WorkerOperationMismatch", {"expected": pending.get("operation"), "received": receipt.get("operation")})
	if not receipt.get("requested_session") is int or int(receipt.requested_session) != int(pending.session):
		return _hold("WorkerSessionMismatch", {"receipt": receipt.get("requested_session"), "pending": pending.session})
	var purpose: String = str(pending.purpose)
	# Compact applied motion is never allowed to become a visible World frame.
	var expected_compact: bool = purpose == "motion" and pending.get("final_segment", true) == false
	var actual_compact: bool = receipt.frame.get("transient_motion_receipt", false) == true
	if actual_compact != expected_compact and receipt.result.get("ok", false):
		return _hold("MotionPresentationBoundaryMismatch", {"expected_compact": expected_compact,
			"actual_compact": actual_compact, "sequence": sequence})
	if actual_compact and (int(receipt.frame.get("tick", -1)) != _last_tick + 1 or
			int(receipt.frame.get("session", -1)) != session):
		return _hold("IntermediateMotionIdentityMismatch", receipt.frame)
	if purpose != "reset" and int(receipt.frame.get("session", 0)) != session:
		return _hold("PublicationSessionMismatch", {"session": receipt.frame.get("session", 0)})
	var wait_usec: int = Time.get_ticks_usec() - int(pending.sent_usec)
	maximum_wait_usec = maxi(maximum_wait_usec, wait_usec)
	_sample("receipt_roundtrip_usec", wait_usec)
	for key: String in ["queue_wait_usec", "native_execute_usec", "snapshot_usec", "receipt_value_accounting_usec"]:
		if receipt.has(key):
			_sample(key, int(receipt[key]))
	if receipt.has("finished_usec"):
		_sample("receipt_delivery_usec", maxi(0, Time.get_ticks_usec() - int(receipt.finished_usec)))
	last_receipt_sequence = sequence
	pending.clear()
	# Keep the last complete material/pose frame until the final motion
	# acknowledgement publishes the next. Compact packets have no edit witness.
	if not actual_compact:
		frame = receipt.frame
	var result: Dictionary = receipt.result
	_event("NativeReceipt", {"purpose": purpose, "operation": receipt.operation, "sequence": sequence,
		"result": result.duplicate(true), "requested_session": receipt.requested_session,
		"published_session": frame.get("session", 0), "owner_thread": receipt.get("owner_thread", 0), "tick": frame.get("tick", 0)})
	if purpose == "reset":
		if not result.get("ok", false) or int(frame.get("session", 0)) <= int(receipt.requested_session):
			return _hold("NativeResetRefused", result)
		session = int(frame.session)
		failed = false
		_fresh_native_registry = false
		_held_request.clear()
		completed_ticks = 0
		last_reset_wait_usec = wait_usec
		maximum_wait_usec = 0
		maximum_tick_usec = 0
		maximum_actions = 0
		rejected_receipts = 0
		last_action.clear()
		_clear_session_observations()
		events.clear()
		_configuration = _requested_configuration
		_requested_configuration = {}
		var initialized: Dictionary = bridge.initialize(session)
		if not initialized.get("ok", false):
			return _hold("PhysicsResetRefused", initialized)
		_begin_capture()
		_event("SessionReset", {"previous_session": receipt.requested_session, "session": session, "wait_usec": last_reset_wait_usec})
		_sync("idle")
	elif purpose == "action":
		last_action = result.duplicate(true)
		last_action["action_name"] = str(_current_action.name)
		last_action["action_id"] = _current_action.action_id
		if str(_current_action.name) == "inspect":
			last_inspection = result.merged({"session": session, "position": _current_action.parameters.position})
		capture.action(int(frame.tick), str(_current_action.name), _current_action.parameters, result)
		_event("ActionApplied" if result.get("ok", false) else "ActionRefused", _current_action.merged({"result": result}))
		_action_finished(result)
		_current_action.clear()
		if frame.get("quarantined", false):
			return _hold("NativeActionQuarantined", result)
		_sync("idle")
	elif purpose == "author_batch":
		last_author_result = result.duplicate(true)
		for row: Dictionary in result.get("results", []):
			var index: int = int(row.get("index", -1))
			if index >= 0 and index < _author_edits.size():
				capture.action(int(frame.tick), "edit", _author_edits[index], row)
		_author_edits.clear()
		_event("FixtureBatchCompleted", result)
		if frame.get("quarantined", false) or not result.get("ok", false):
			return _hold("NativeFixtureBatchRefused", result)
		_sync("idle")
	elif purpose == "tick":
		if not result.get("ok", false) or int(frame.tick) != _last_tick + 1:
			return _hold("NativeSemanticStepRefused", result)
		_sync("discover")
	elif purpose == "prepare":
		if result.get("ok", false) and frame.get("promotion", {}).get("present", false):
			if defer_prepared_promotion:
				state = "PreparedForReview"
				status = "Non-authoritative preparation held; World still owns all material"
			else:
				_reserve()
		elif result.get("outcome", "") in ["Busy", "Anchored", "Capacity", "UnknownBoundary", "Unsupported", "PendingEvent", "Stale"]:
			_sync("motion")
		else:
			return _hold("NativePreparationFailed", result)
	elif purpose == "reserved":
		if not result.get("ok", false) or str(result.get("phase", "")) != "CommittedInactive":
			return _hold("NativeCommitRefused", result)
		_install_postcommit_terrain()
	elif purpose == "terrain":
		if not result.get("ok", false) or str(result.get("phase", "")) != "ReadyToActivate":
			return _hold("NativeMaskApplicationRefused", result)
		_activate()
	elif purpose == "activated":
		if not result.get("ok", false) or str(result.get("phase", "")) != "Active":
			return _hold("NativeActivationRefused", result)
		_event("PromotionActive", {"pause_usec": Time.get_ticks_usec() - _promotion_started_usec})
		_sync("motion")
	elif purpose == "geometry":
		if not result.get("ok", false):
			return _hold("NativeGeometryReceiptRefused", result)
		_sync(_sync_continuation)
	elif purpose == "motion":
		var applied: Dictionary = bridge.acknowledge_motion_segment(result)
		if not applied.get("ok", false):
			return _hold("AppliedMotionReceiptRefused", applied)
		if applied.get("finished", false):
			_finish_tick()
		else:
			_next_segment()
	elif purpose == "cancel":
		if not result.get("ok", false) and str(result.get("outcome", "")) != "Cancelled":
			return _hold("NativeCancellationRefused", result)
		for id: int in bridge.bodies.keys():
			if _find_shard(id).is_empty():
				bridge.remove_body(id)
		# Preparation follows this tick's completed native chemistry. Cancelling
		# the uncommitted promotion must still finish that same physical interval
		# for existing bodies; it is not permission to drop time or run chemistry
		# repeatedly while holding their motion.
		_sync("motion")
	return {"ok": not failed, "outcome": "ReceiptConsumed"}


func _opened(receipt: Dictionary) -> Dictionary:
	if not receipt.result.get("ok", false) or int(receipt.frame.get("session", 0)) <= 0:
		return _hold("NativeOpenRefused", receipt.result)
	frame = receipt.frame
	session = int(frame.session)
	capabilities = receipt.get("capabilities", {})
	var initialized: Dictionary = bridge.initialize(session)
	if not initialized.get("ok", false):
		return _hold("PhysicsOpenRefused", initialized)
	_begin_capture()
	_sync("idle")
	return {"ok": not failed, "outcome": "Opened"}


func _begin_capture() -> void:
	_package_identity = _read_package_identity()
	var path: String = _trace_path
	if not path.is_empty():
		path = path.get_basename() + "-session-" + str(session) + ".jsonl"
	capture.begin({"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"package_manifest_sha256": _package_identity.get("sha256", ""), "package_identity": _package_identity,
		"scenario": _configuration.get("scenario", 0), "seed": _configuration.get("seed", 12),
		"width": frame.width, "height": frame.height, "session": session, "transport_generation": generation,
		"initial_tick": frame.tick, "host": "standalone-exclusive-worker-rehearsal", "production_workbench": false,
		"standalone_replay": _fresh_native_registry,
		"replay_identity_scope": "fresh-native-registry" if _fresh_native_registry else "inherited-native-registry",
		"replay_driver": "res://tests/replay_object_shard_worker_trace.gd",
		"host_replay_scope": "Named operations and completed semantic ticks only; asynchronous arrival timing and incomplete motion barriers require the recorded adverse schedule and are not replayed"}, path)


static func _read_package_identity() -> Dictionary:
	var path: String = OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")
	var identity: Dictionary = {"path": path, "sha256": "", "source_commit": "",
		"status": "unavailable-development", "scope": "Manifest byte readback; sealed package verification remains the launcher gate"}
	if path.is_empty():
		return identity
	var input: FileAccess = FileAccess.open(path, FileAccess.READ)
	if input == null or input.get_length() > 4 * 1024 * 1024:
		identity.status = "unavailable-or-oversize"
		return identity
	var bytes: PackedByteArray = input.get_buffer(input.get_length())
	input.close()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	identity.sha256 = context.finish().hex_encode()
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.get("source_commit") is String:
		identity.status = "malformed-manifest"
		return identity
	identity.source_commit = parsed.source_commit
	identity.status = "observed-package-manifest" if parsed.source_commit == OS.get_environment("CYBERSAND_SOURCE_REVISION") else "manifest-source-mismatch"
	return identity


func _drive_idle() -> void:
	if failed or state != "Idle" or not pending.is_empty():
		return
	if _tick_requested and (actions.is_empty() or _actions_since_tick >= ACTIONS_PER_TICK):
		_start_tick()
		return
	if not actions.is_empty():
		_current_action = actions.pop_front()
		_actions_since_tick += 1
		_sample("input_to_dispatch_usec", Time.get_ticks_usec() - int(_current_action.captured_usec))
		_sample("host_admission_to_dispatch_usec", Time.get_ticks_usec() - int(_current_action.admitted_usec))
		var parameters: Dictionary = _current_action.parameters
		var owned: Dictionary = _owned_cell(frame, parameters.position)
		if str(_current_action.name) != "inspect" and not _target_matches(parameters.target, parameters.position):
			_refuse_action("TargetChanged", "Observed owner, pose, geometry or material changed; make a fresh stroke")
			return
		if str(_current_action.name) == "inspect":
			_send("inspect", {"position": parameters.position}, "action")
		elif str(_current_action.name) == "ignite":
			if owned.is_empty():
				_send("ignite", parameters, "action")
			else:
				_send("ignite_shard", {"id": owned.id, "generation": owned.shard.generation, "cell": owned.cell}, "action")
		elif owned.is_empty():
			_send("edit", parameters, "action")
		elif int(parameters.material) != 0 or int(owned.shard.roles[int(owned.cell)]) != 1:
			_refuse_action("OnlyStructuralEraseSupported", "Moving inventory supports structural erasure and ignition")
		else:
			_send("erase_shard", _erase_receipt(owned), "action")


func _start_tick() -> void:
	_tick_requested = false
	_actions_since_tick = 0
	_tick_started_usec = Time.get_ticks_usec()
	_last_tick = int(frame.tick)
	bridge.begin_frame()
	capture.write("step_requested", _last_tick, {"host": "exclusive-worker", "paused": true, "force": true})
	_send("tick", {"poses": bridge.sample_poses()}, "tick")


func _refuse_action(reason: String, detail: String) -> void:
	last_action = {"ok": false, "outcome": reason, "detail": detail,
		"action_id": _current_action.action_id, "action_name": _current_action.name}
	capture.action(int(frame.tick), str(_current_action.name), _current_action.parameters, last_action)
	_event("ActionRefused", _current_action.merged({"result": last_action}))
	_action_finished(last_action)
	_current_action.clear()
	_publish()
	status = reason + ": " + detail


func _action_finished(result: Dictionary) -> void:
	var row: Dictionary = {"action_id": _current_action.action_id, "name": _current_action.name,
		"outcome": result.get("outcome", ""), "ok": result.get("ok", false),
		"captured_usec": _current_action.captured_usec, "admitted_usec": _current_action.admitted_usec,
		"input_observation": _current_action.input_observation, "completed_usec": Time.get_ticks_usec()}
	_sample("input_to_result_usec", int(row.completed_usec) - int(row.captured_usec))
	_sample("host_admission_to_result_usec", int(row.completed_usec) - int(row.admitted_usec))
	if action_results.size() >= EVENT_CAPACITY:
		action_results.pop_front()
	action_results.append(row.duplicate(true))
	_awaiting_publication_actions.append(row)


func _sync(continuation: String) -> void:
	_sync_continuation = continuation
	var terrain_started: int = Time.get_ticks_usec()
	var installed: Dictionary = bridge.install_terrain(frame.get("terrain_chunks", []))
	_sample("terrain_install_usec", Time.get_ticks_usec() - terrain_started)
	if not installed.get("ok", false):
		_hold("TerrainInstallationFailed", installed)
		return
	for shard: Dictionary in frame.get("shards", []):
		if bridge.bodies.has(int(shard.id)) and shard.get("geometry_pending", false):
			var geometry_started: int = Time.get_ticks_usec()
			var changed: Dictionary = bridge.install_geometry(shard)
			_sample("geometry_install_usec", Time.get_ticks_usec() - geometry_started)
			if not changed.get("ok", false):
				_hold("PhysicsGeometryInstallationFailed", changed)
				return
			var kind: String = "BodyRetired" if changed.get("retired_body", false) else "GeometryInstalled"
			_send("acknowledge", _ack(shard, kind), "geometry")
			return
		if bridge.bodies.has(int(shard.id)):
			var refreshed: Dictionary = bridge.refresh_motion_domain(shard)
			if not refreshed.get("ok",false):
				_hold("MotionDomainRefreshFailed",refreshed)
				return
	match continuation:
		"idle":
			_publish()
			state = "Idle"
			status = "Paused between asynchronous operations"
		"discover": _send("prepare", {}, "prepare")
		"motion": _begin_motion()


func _reserve() -> void:
	_promotion_started_usec = Time.get_ticks_usec()
	var shard: Dictionary = _find_shard(int(frame.promotion.id))
	if shard.is_empty():
		_hold("PreparedInventoryMissing", {})
		return
	var reserved: Dictionary = bridge.reserve_body(shard)
	if not reserved.get("ok", false):
		_send("cancel", {"transaction": frame.promotion.transaction}, "cancel")
		return
	_event("PhysicsReserved", {"id": shard.id, "geometry_revision": shard.geometry_revision})
	_send("acknowledge", _ack(shard, "PhysicsReserved"), "reserved")


func _install_postcommit_terrain() -> void:
	var installed: Dictionary = bridge.install_terrain(frame.terrain_chunks)
	if not installed.get("ok", false):
		_hold("PostcommitTerrainInstallationFailed", installed)
		return
	var shard: Dictionary = _find_shard(int(frame.promotion.id))
	var receipt: Dictionary = _ack(shard, "TerrainInstalled")
	var chunks: Array = []
	for required: Dictionary in frame.promotion.chunks:
		for actual: Dictionary in installed.chunks:
			if int(actual.id) == int(required.id):
				chunks.append(actual)
	receipt["chunks"] = chunks
	_send("acknowledge", receipt, "terrain")


func _activate() -> void:
	var shard: Dictionary = _find_shard(int(frame.promotion.id))
	var active: Dictionary = bridge.activate(shard)
	if not active.get("ok", false):
		_hold("PhysicsActivationFailed", active)
		return
	_send("acknowledge", _ack(shard, "BodyActivated"), "activated")


func _begin_motion() -> void:
	if frame.get("paused", true):
		_hold("NativeBarrierStillPending", {})
		return
	var started: Dictionary = bridge.begin_motion_tick(int(frame.tick))
	if not started.get("ok", false):
		_hold("PhysicsMotionBeginFailed", started)
		return
	if started.get("finished", false):
		_finish_tick()
	else:
		_next_segment()


func _next_segment() -> void:
	var started: int = Time.get_ticks_usec()
	var segment: Dictionary = bridge.advance_motion_segment()
	_sample("physics_segment_usec", Time.get_ticks_usec() - started)
	if not segment.get("ok", false):
		_hold("PhysicsSegmentRefused", segment)
		return
	if segment.get("finished", false):
		_finish_tick()
		return
	_event("PhysicsSegmentAwaitingNative", {"segment_sequence": segment.segment_sequence, "delta": segment.delta})
	# One complete World raster per semantic tick, not one per Rapier substep.
	# Every substep still requires its exact native applied-motion receipt.
	var final_segment: bool = (float(segment.get("motion", {}).get("completed_delta", 0.0)) >=
		Bridge.FIXED_DELTA - 0.000000001)
	_send("motion", {"poses": segment.poses, "final_segment": final_segment}, "motion")


func _finish_tick() -> void:
	_publish()
	completed_ticks += 1
	maximum_tick_usec = maxi(maximum_tick_usec, Time.get_ticks_usec() - _tick_started_usec)
	_sample("semantic_interval_usec", Time.get_ticks_usec() - _tick_started_usec)
	var observation: Dictionary = bridge.diagnostics()
	observation.erase("events")
	capture.write("step_completed", int(frame.tick), {"native_tick": frame.tick, "host": "exclusive-worker",
		"physics": observation, "completed_ticks": completed_ticks})
	state = "Idle"
	status = "Tick %d completed with applied worker receipts" % int(frame.tick)


func _publish() -> void:
	publication = frame
	publication_sequence += 1
	_publication_usec = Time.get_ticks_usec()
	for row: Dictionary in _awaiting_publication_actions:
		_sample("input_to_publication_usec", _publication_usec - int(row.captured_usec))
		_sample("host_admission_to_publication_usec", _publication_usec - int(row.admitted_usec))
		row["publication_sequence"] = publication_sequence
		if _pending_visible_actions.size() >= EVENT_CAPACITY:
			_pending_visible_actions.pop_front()
		_pending_visible_actions.append(row)
	_awaiting_publication_actions.clear()


func mark_presented(sequence: int) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if sequence != publication_sequence or sequence <= _presented_sequence:
		return {"ok": false, "outcome": "StaleOrDuplicatePresentation"}
	_presented_sequence = sequence
	var now: int = Time.get_ticks_usec()
	_sample("publication_to_presented_usec", now - _publication_usec)
	for row: Dictionary in _pending_visible_actions:
		_sample("input_to_presented_usec", now - int(row.captured_usec))
		_sample("host_admission_to_presented_usec", now - int(row.admitted_usec))
	_pending_visible_actions.clear()
	return {"ok": true, "outcome": "PresentationObserved", "publication_sequence": sequence}


func _sample(name: String, value: int) -> void:
	if not timings.has(name):
		timings[name] = []
		timing_totals[name] = {"count": 0, "maximum": 0}
	timing_totals[name].count = int(timing_totals[name].count) + 1
	timing_totals[name].maximum = maxi(int(timing_totals[name].maximum), value)
	var rows: Array = timings[name]
	if rows.size() >= TIMING_CAPACITY:
		rows.pop_front()
	rows.append(maxi(value, 0))


func _timing_summary() -> Dictionary:
	var now: int = Time.get_ticks_usec()
	if now - _timing_summary_usec < 250000 and not _timing_summary_cache.is_empty():
		return _timing_summary_cache.duplicate(true)
	var summary: Dictionary = {}
	for name: String in timings:
		var rows: Array = timings[name].duplicate()
		rows.sort()
		var count: int = rows.size()
		if count > 0:
			summary[name] = {"count": count, "total_count": timing_totals[name].count,
				"session_maximum": timing_totals[name].maximum, "p50": rows[clampi(ceili(count * 0.5) - 1, 0, count - 1)],
				"p95": rows[clampi(ceili(count * 0.95) - 1, 0, count - 1)],
				"p99": rows[clampi(ceili(count * 0.99) - 1, 0, count - 1)], "maximum": rows[-1]}
	_timing_summary_cache = summary
	_timing_summary_usec = now
	return summary.duplicate(true)


func _clear_session_observations() -> void:
	timings.clear()
	timing_totals.clear()
	action_results.clear()
	_author_edits.clear()
	last_author_result.clear()
	last_inspection.clear()
	_actions_since_tick = 0
	_awaiting_publication_actions.clear()
	_pending_visible_actions.clear()
	_timing_summary_cache.clear()
	_timing_summary_usec = 0
	_publication_usec = 0
	_presented_sequence = 0


func _send(operation: String, parameters: Dictionary, purpose: String) -> Dictionary:
	if failed or state in ["Held", "ShutdownHeld", "Closing", "Closed"]:
		return {"ok": false, "outcome": "HeldUntilExplicitReset"}
	if not pending.is_empty():
		return _hold("OverlappingHostOperation", {"existing": pending.purpose, "proposed": purpose})
	var ticket: Dictionary = worker.submit(operation, parameters, session, generation)
	if not ticket.get("ok", false):
		return _hold("WorkerAdmissionRefused", ticket)
	pending = ticket.duplicate(true)
	pending["purpose"] = purpose
	if purpose == "motion":
		pending["final_segment"] = parameters.get("final_segment", true)
	pending["sent_usec"] = Time.get_ticks_usec()
	state = "Awaiting:" + purpose
	status = "Waiting for applied " + purpose + " receipt; Rapier is not advancing"
	return ticket


func _ack(shard: Dictionary, kind: String) -> Dictionary:
	var receipt: Dictionary = {"kind": kind}
	for key: String in ["session", "id", "generation", "transaction", "body_generation", "payload_digest", "geometry_revision", "mask_digest", "shape_digest"]:
		receipt[key] = shard[key]
	return receipt


func _erase_receipt(owned: Dictionary) -> Dictionary:
	var shard: Dictionary = owned.shard
	var cell: int = int(owned.cell)
	return {"session": session, "id": shard.id, "generation": shard.generation,
		"sequence": frame.next_transaction, "body_generation": shard.body_generation,
		"geometry_revision": shard.applied_physics_revision, "pose_serial": shard.pose_serial,
		"material_revision": shard.material_revision, "cell": cell, "incarnation": shard.incarnations[cell],
		"capability_version": 1, "expected": {"material": shard.materials[cell], "state_a": shard.states_a[cell],
			"state_b": shard.states_b[cell], "temperature": shard.temperature[cell]}}


func _find_shard(id: int) -> Dictionary:
	for shard: Dictionary in frame.get("shards", []):
		if int(shard.id) == id:
			return shard
	return {}


static func _owned_cell(source: Dictionary, position: Vector2i) -> Dictionary:
	# Resolve against an applied native pose publication. A newer unacknowledged
	# RID pose is deliberately not used for material ownership or presentation.
	for shard: Dictionary in source.get("shards", []):
		if not shard.get("owns_inventory", false):
			continue
		var transform := Transform2D(float(shard.rotation), Vector2(float(shard.position_x), float(shard.position_y)))
		var local: Vector2 = transform.affine_inverse() * (Vector2(position) + Vector2.ONE * 0.5)
		var x: int = floori(local.x)
		var y: int = floori(local.y)
		if x >= 0 and y >= 0 and x < int(shard.width) and y < int(shard.height):
			var cell: int = y * int(shard.width) + x
			if int(shard.materials[cell]) != 0:
				return {"id": shard.id, "shard": shard, "cell": cell}
	return {}


func _reject_receipt(reason: String) -> Dictionary:
	rejected_receipts += 1
	return {"ok": false, "outcome": reason}


func _hold(reason: String, detail: Dictionary) -> Dictionary:
	failed = true
	_tick_requested = false
	if not pending.is_empty():
		_held_request = pending.duplicate(true)
	retired_sequence = maxi(retired_sequence, int(pending.get("sequence", 0)))
	pending.clear()
	state = "Held"
	status = reason + "; retained owners remain paused until explicit reset"
	_event("Held", {"reason": reason, "detail": detail})
	capture.write("failure", int(frame.get("tick", 0)), {"reason": reason, "detail": detail})
	return {"ok": false, "outcome": reason}


func _retire_actions(cause: String) -> void:
	# Accepted inputs always receive a terminal disposition. An in-flight
	# native edit may already have applied even if its receipt was lost; whole
	# session disposal resolves ownership but cannot reconstruct that outcome.
	for action: Dictionary in actions:
		_record_retired_action(action, "CancelledBy" + cause, false)
	actions.clear()
	if not _current_action.is_empty():
		_record_retired_action(_current_action, "RetiredBy" + cause + "OutcomeUnknown", true)
		_current_action.clear()
		capture.complete = false
		capture.reason = "In-flight action outcome retired by explicit " + cause.to_lower() + "; observation trace only"
	if not _author_edits.is_empty():
		_event("FixtureBatchRetired", {"outcome": "RetiredBy" + cause + "OutcomeUnknown", "may_have_executed": true,
			"edits": _author_edits.duplicate(true)})
		_author_edits.clear()
		capture.complete = false
		capture.reason = "In-flight fixture batch retired by explicit " + cause.to_lower() + "; observation trace only"


func _record_retired_action(action: Dictionary, outcome: String, may_have_executed: bool) -> void:
	var row: Dictionary = {"action_id": action.action_id, "name": action.name, "session": action.session,
		"outcome": outcome, "ok": false, "may_have_executed": may_have_executed,
		"captured_usec": action.captured_usec, "admitted_usec": action.admitted_usec,
		"input_observation": action.input_observation, "completed_usec": Time.get_ticks_usec()}
	if retired_action_results.size() >= EVENT_CAPACITY:
		retired_action_results.pop_front()
	retired_action_results.append(row.duplicate(true))
	# An event is evidence, never a replayable material mutation.
	_event("ActionRetired", row.merged({"parameters": action.parameters.duplicate(true)}))


func _event(kind: String, detail: Dictionary) -> void:
	if events.size() >= EVENT_CAPACITY:
		events.pop_front()
	events.append({"kind": kind, "session": session, "tick": frame.get("tick", 0), "state": state, "detail": detail.duplicate(true)})
	capture.write("event", int(frame.get("tick", 0)), {"kind": kind, "session": session, "state": state, "detail": detail})


func diagnostics() -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	return {"schema": "objectshard-worker-rehearsal-v1", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"package_manifest_sha256": _package_identity.get("sha256", ""), "package_identity": _package_identity.duplicate(true),
		"scope": "Standalone real World/Rapier asynchronous ownership rehearsal; not attached to the production Workbench",
		"state": state, "status": status, "failed": failed, "session": session, "transport_generation": generation,
		"tick": frame.get("tick", 0), "published_tick": publication.get("tick", 0), "completed_ticks": completed_ticks,
		"publication_sequence": publication_sequence,
		"pending": pending.duplicate(true), "actions_pending": actions.size(), "action_capacity": ACTION_CAPACITY,
		"maximum_actions": maximum_actions, "maximum_wait_usec": maximum_wait_usec, "maximum_tick_usec": maximum_tick_usec,
		"last_reset_wait_usec": last_reset_wait_usec,
		"event_driven_receipts": event_driven_receipts,
		"receipt_deadline_usec": RECEIPT_DEADLINE_USEC,
		"maximum_receipt_pump_budget_usec": MAX_RECEIPT_PUMP_USEC,
		"notification_limits": {"receipt_callbacks_per_frame": NOTIFICATION_RECEIPTS_PER_FRAME, "main_work_budget_usec": NOTIFICATION_BUDGET_USEC},
		"action_results": action_results.duplicate(true), "actions_per_tick": ACTIONS_PER_TICK,
		"retired_action_results": retired_action_results.duplicate(true), "held_request": _held_request.duplicate(true),
		"last_inspection": last_inspection.duplicate(true), "last_author_result": last_author_result.duplicate(true),
		"timings_usec": _timing_summary(), "timing_sample_capacity": TIMING_CAPACITY,
		"publication_age_usec": maxi(0, Time.get_ticks_usec() - _publication_usec),
		"timing_scope": "Latest bounded samples per current session. Input-to-result/publication/presented and receipt-roundtrip/semantic-interval are enclosing measures, not additive stages. Queue/native/snapshot/value-accounting/delivery are disjoint. Presentation is scene draw observation, not measured monitor scanout.",
		"host_metric_scope": "Current native session, including explicit delayed-ACK diagnostics; reset wait is separate. Worker resource maxima cover this transport lifetime. These are not steady-state physics-only costs.",
		"rejected_receipts": rejected_receipts, "last_receipt_sequence": last_receipt_sequence,
		"retired_sequence": retired_sequence, "last_action": last_action.duplicate(true),
		"worker": worker.diagnostics() if worker != null else {}, "physics": bridge.diagnostics() if bridge != null else {},
		"admission": frame.get("admission", {}), "accounting": frame.get("accounting", {}),
		"capture": capture.metadata(), "events": events.duplicate(true),
		"replay": {"driver": "res://tests/replay_object_shard_worker_trace.gd", "receipt_timing_replayed": false,
			"standalone_replay": _fresh_native_registry,
			"identity_scope": "fresh-native-registry" if _fresh_native_registry else "inherited-native-registry",
			"scope": "Named operations and completed semantic ticks; incomplete barriers retained as incident evidence"},
		"owner_physical_acceptance": "not claimed"}
