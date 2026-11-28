class_name CyberObjectShardM4WorkbenchPort
extends RefCounted

# M4 ordinary-Workbench transport contract. This is not a native World, a
# physics simulator or the M3 standalone worker host. Its default state refuses.
# The three methods below must eventually be implemented by the EXISTING
# CyberSimulationWorker, with values copied under its mutex. They must never
# call the native World on the main thread.
const REQUIRED_METHODS: Array[String] = [
	"object_shard_same_world_capabilities",
	"object_shard_queue_workbench_action",
	"object_shard_take_workbench_results",
]
const MAX_PENDING: int = 16
const MAX_RESULTS: int = 128
const ACTIONS: Array[String] = ["erase", "ignite", "inspect"]
const TERMINAL_OUTCOMES: Array[String] = [
	"Applied", "TargetChanged", "Capacity", "Refused", "Cancelled", "Failed",
]

var enabled: bool = false
var generation: int = 1
var last_status: Dictionary = {"ready": false, "outcome": "FeatureDisabled"}
var results: Array[Dictionary] = []
var _next_action: int = 0
var _pending: Dictionary = {}
var _held_reason: String = ""
var _pinned_owner: Dictionary = {}
var _latest_edit_delivery: Dictionary = {} # One authenticated mutation, not the diagnostic result ring.


func _init(requested: bool = false) -> void:
	enabled = requested


func _refusal(reason: String) -> Dictionary:
	last_status = {"ready": false, "ok": false, "outcome": reason}
	return last_status.duplicate()


func _hold(reason: String, action_id: int = 0, detail: String = "") -> Dictionary:
	# A previously admitted edit may already have changed native inventory.
	# A malformed or alien terminal receipt must prevent ALL further edits
	# until explicit source-owned disposal, never merely drop that receipt.
	if _held_reason.is_empty():
		_held_reason = reason
	last_status = {"ready": false, "ok": false, "outcome": _held_reason,
		"action_id": action_id, "pending": _pending.size(), "may_have_executed": true}
	if not detail.is_empty():
		last_status["detail"] = detail
	return last_status.duplicate(true)


func pending_count() -> int:
	return _pending.size()


func held_reason() -> String:
	return _held_reason


func latest_edit_presented(publication: Dictionary, capabilities: Dictionary) -> bool:
	if _latest_edit_delivery.is_empty(): return true
	if not _held_reason.is_empty() or _latest_edit_delivery.port_generation != generation: return false
	for key: String in ["native_instance_id", "world_generation", "session", "owner_epoch",
			"shard_session", "world_incarnation", "transport_generation"]:
		if _latest_edit_delivery[key] != capabilities.get(key): return false
	for key: String in ["world_generation", "session", "owner_epoch", "shard_session",
			"world_incarnation", "transport_generation"]:
		if _latest_edit_delivery[key] != publication.get(key): return false
	# Coordinator consumes this monotonic transaction before minting its edit
	# receipt. Main can receive that receipt while both of its retained frames
	# still agree on the older geometry. Only a later same-owner publication,
	# together with the caller's real physics/geometry readiness, closes that gap.
	return typeof(publication.get("next_transaction")) == TYPE_INT \
		and int(publication.next_transaction) > int(_latest_edit_delivery.transaction_id)


# A status readback is a worker-published VALUE. The native specialist must
# prove that its native_instance_id is the exact _world already owned by
# CyberSimulationWorker, not a second CyberObjectShardLab World.
func interface_status(worker: Object, snapshot: CyberSimulationSnapshot) -> Dictionary:
	if not enabled:
		return _refusal("FeatureDisabled")
	# The UI must display a previously entered hold, not a new ready status.
	if not _held_reason.is_empty():
		return _refusal(_held_reason)
	if worker == null or not worker is CyberSimulationWorker:
		return _refusal("OrdinaryWorkerRequired")
	if snapshot == null or snapshot.simulation_failed:
		return _refusal("LiveSnapshotRequired")
	if not str(snapshot.lab_context.get("workbench_refusal", "")).is_empty():
		return _refusal("WorkbenchOwnerRefused")
	if not snapshot.lab_context.has("workbench_gcr"):
		return _refusal("OrdinaryWorkbenchRequired")
	for method_name: String in REQUIRED_METHODS:
		if not worker.has_method(StringName(method_name)):
			return _refusal("SameWorldAdapterMissing")
	var raw: Variant = worker.call(REQUIRED_METHODS[0])
	if not raw is Dictionary:
		return _refusal("InvalidNativeCapabilityReceipt")
	var capabilities: Dictionary = raw
	if capabilities.get("host") != "ordinary-workbench" \
			or capabilities.get("owner") != "simulation-worker" \
			or capabilities.get("mode") != "same-world" \
			or capabilities.get("attached") != true \
			or capabilities.get("worker_exclusive") != true:
		return _refusal("CompetingOrUnattachedWorld")
	for key: String in ["worker_instance_id", "native_instance_id", "world_generation",
			"session", "owner_epoch", "shard_session", "world_incarnation",
			"transport_generation"]:
		# RefCounted ObjectIDs use the high bit and can therefore be negative
		# when transported through Godot's signed integer Variant. They are
		# exact opaque identities, while generations/counters stay positive.
		if not capabilities.get(key) is int or (int(capabilities[key]) == 0 \
			if key in ["worker_instance_id","native_instance_id"] else int(capabilities[key]) <= 0):
			return _refusal("IncompleteWorldIdentity")
	if int(capabilities.worker_instance_id) != worker.get_instance_id():
		return _refusal("ForeignWorkerIdentity")
	if int(capabilities.world_generation) != snapshot.render_world_generation:
		return _refusal("StaleWorldGeneration")
	if not capabilities.get("operations") is Array:
		return _refusal("IncompleteActionCapabilities")
	for action: String in ACTIONS:
		if action not in capabilities.operations:
			return _refusal("IncompleteActionCapabilities")
	var candidate_owner: Dictionary = {}
	for key: String in ["worker_instance_id", "native_instance_id", "world_generation",
			"session", "owner_epoch", "shard_session", "world_incarnation",
			"transport_generation"]:
		candidate_owner[key] = capabilities[key]
	if not _pinned_owner.is_empty() and _pinned_owner != candidate_owner:
		_held_reason = "OwnerChangedWithoutRetirement"
		return _refusal(_held_reason)
	if _pinned_owner.is_empty():
		_pinned_owner = candidate_owner.duplicate()
	last_status = {"ready": true, "ok": true, "outcome": "SameWorldCandidate",
		"world_generation": capabilities.world_generation,
		"native_instance_id": capabilities.native_instance_id,
		"worker_instance_id": capabilities.worker_instance_id,
		"session": capabilities.session, "owner_epoch": capabilities.owner_epoch,
		"shard_session": capabilities.shard_session,
		"world_incarnation": capabilities.world_incarnation,
		"transport_generation": capabilities.transport_generation}
	return last_status.duplicate()


# The OBSERVATION is the immutable, already uploaded material+pose publication,
# never a convenient newly received worker snapshot or the latest Rapier pose.
# This function checks delivery identity; the native owner must subsequently
# compare exact contents and return TargetChanged on any stale witness.
static func visible_error(observation: Dictionary, uploaded: Dictionary) -> String:
	for key: String in ["world_generation", "world_revision", "render_serial"]:
		if not observation.get(key) is int or not uploaded.get(key) is int:
			return "VisiblePublicationRequired"
		if int(observation[key]) != int(uploaded[key]):
			return "VisiblePublicationChanged"
	for key: String in ["session", "owner_epoch", "shard_session",
			"world_incarnation", "transport_generation", "publication_sequence"]:
		if not observation.get(key) is int or int(observation[key]) <= 0:
			return "MissingObservationIdentity"
	return ""


static func target_error(target: Dictionary, position: Vector2i, observation: Dictionary) -> String:
	if target.get("position") != position \
			or target.get("session") != observation.get("session") \
			or target.get("owner_epoch") != observation.get("owner_epoch") \
			or target.get("shard_session") != observation.get("shard_session") \
			or target.get("world_incarnation") != observation.get("world_incarnation") \
			or target.get("transport_generation") != observation.get("transport_generation") \
			or target.get("publication_sequence") != observation.get("publication_sequence"):
		return "TargetObservationChanged"
	for key: String in ["owner", "cell", "generation", "body_generation", "geometry_revision",
			"applied_physics_revision", "pose_serial", "material_revision", "incarnation"]:
		if not target.get(key) is int:
			return "IncompleteMovingTarget"
	if int(target.owner) <= 0 or int(target.cell) < 0 or int(target.generation) <= 0 \
			or int(target.body_generation) <= 0 or int(target.incarnation) < 0:
		return "MovingTargetRequired"
	if not target.get("expected") is Dictionary:
		return "IncompleteMovingTarget"
	for key: String in ["material", "state_a", "state_b", "temperature"]:
		if not target.expected.get(key) is int:
			return "IncompleteMovingTarget"
	return ""


func queue_intent(worker: Object, snapshot: CyberSimulationSnapshot, uploaded: Dictionary,
		observation: Dictionary, action: String, position: Vector2i,
		target: Dictionary, captured_usec: int = 0, targets: Array = [],
		terrain_cells: Array = [], selection: Dictionary = {}) -> Dictionary:
	var status: Dictionary = interface_status(worker, snapshot)
	if not status.ready:
		return {"ok": false, "outcome": status.outcome}
	if action not in ACTIONS:
		return {"ok": false, "outcome": "UnsupportedAction"}
	if not _held_reason.is_empty():
		return {"ok": false, "outcome": _held_reason, "pending": _pending.size()}
	if _pending.size() >= MAX_PENDING:
		return {"ok": false, "outcome": "ActionCapacity"}
	var visible_reason: String = visible_error(observation, uploaded)
	if not visible_reason.is_empty():
		return {"ok": false, "outcome": visible_reason}
	if int(observation.world_generation) != int(status.world_generation) \
			or int(observation.session) != int(status.session) \
			or int(observation.owner_epoch) != int(status.owner_epoch) \
			or int(observation.shard_session) != int(status.shard_session) \
			or int(observation.world_incarnation) != int(status.world_incarnation) \
			or int(observation.transport_generation) != int(status.transport_generation):
		return {"ok": false, "outcome": "WorldIdentityChanged"}
	var terrain: bool = not terrain_cells.is_empty()
	if targets.size()>4096 or terrain_cells.size()>4096 or (terrain and not targets.is_empty()):
		return {"ok":false,"outcome":"FootprintCapacity"}
	if terrain:
		if action not in ["erase","ignite"] or terrain_cells[0]!=position:
			return {"ok":false,"outcome":"InvalidTerrainBatch"}
		for cell: Variant in terrain_cells:
			if not cell is Vector2i: return {"ok":false,"outcome":"InvalidTerrainCell"}
	else:
		var target_reason: String = target_error(target, position, observation)
		if not target_reason.is_empty(): return {"ok":false,"outcome":target_reason}
		if not targets.is_empty():
			if action not in ["erase","ignite"] or targets[0]!=target:
				return {"ok":false,"outcome":"InvalidMovingBatch"}
			for witness: Variant in targets:
				if not witness is Dictionary or not witness.get("position") is Vector2i:
					return {"ok":false,"outcome":"InvalidMovingBatch"}
				var error: String = target_error(witness,witness.position,observation)
				if not error.is_empty(): return {"ok":false,"outcome":error}
				for key: String in ["owner","generation","body_generation","geometry_revision","applied_physics_revision","pose_serial","material_revision"]:
					if witness[key]!=target[key]: return {"ok":false,"outcome":"MixedOwnerBatch"}
	for key: Variant in selection:
		if key not in ["probability_ppm","seed","material_filter"] or not selection[key] is int:
			return {"ok":false,"outcome":"InvalidBatchSelection"}
	if int(selection.get("probability_ppm",1000000))<0 or int(selection.get("probability_ppm",1000000))>1000000 \
			or int(selection.get("seed",0))<0 or int(selection.get("material_filter",-1)) < -1:
		return {"ok":false,"outcome":"InvalidBatchSelection"}
	var now_usec: int = Time.get_ticks_usec()
	if captured_usec < 0 or captured_usec > now_usec:
		return {"ok": false, "outcome": "InvalidInputTime"}
	_next_action += 1
	# Input carries only the already validated publication identity. The native
	# target is exact; copying an entire published World/shard image into every
	# click would be redundant and could exceed the bounded worker command.
	var observation_identity: Dictionary = {}
	for key: String in ["world_generation","world_revision","render_serial","session","owner_epoch",
		"shard_session","world_incarnation","transport_generation","publication_sequence"]:
		observation_identity[key] = observation[key]
	var request: Dictionary = {"action_id": _next_action, "port_generation": generation,
		"operation": action, "position": position, "target": target.duplicate(true),
		"observation": observation_identity, "world_generation": status.world_generation,
		"native_instance_id": status.native_instance_id, "session": status.session,
		"owner_epoch": status.owner_epoch, "shard_session": status.shard_session,
		"world_incarnation": status.world_incarnation,
		"transport_generation": status.transport_generation,
		"captured_usec": captured_usec if captured_usec > 0 else now_usec,
		"admitted_usec": now_usec}
	if terrain:
		request["domain"] = "terrain"
		request["terrain_cells"] = terrain_cells.duplicate()
	elif not targets.is_empty():
		request["targets"] = targets.duplicate(true)
	if terrain or not targets.is_empty():
		for key: String in ["probability_ppm","seed","material_filter"]:
			request[key] = int(selection.get(key,1000000 if key=="probability_ppm" else -1 if key=="material_filter" else 0))
	# Only the normal simulation worker can accept the request. Its queue must
	# separately check capacity and execute against the same World on its thread.
	var reply: Variant = worker.call(REQUIRED_METHODS[1], request.duplicate(true))
	# Explicit fenced refusal proves non-admission. A malformed acknowledgement
	# cannot establish whether the worker already accepted or executed the edit.
	if reply is Dictionary and reply.get("action_id") == _next_action \
			and reply.get("port_generation") == generation and reply.get("ok") == false:
		return {"ok": false, "outcome": str(reply.get("outcome", "WorkerAdmissionRefused"))}
	if not reply is Dictionary or reply.get("ok") != true or \
			reply.get("action_id") != _next_action or reply.get("port_generation") != generation:
		_pending[_next_action] = request
		_held_reason = "AdmissionUncertain"
		return {"ok": false, "outcome": _held_reason, "may_have_executed": true,
			"action_id": _next_action, "port_generation": generation}
	_pending[_next_action] = request
	return {"ok": true, "outcome": "QueuedOnOrdinaryWorker", "action_id": _next_action,
		"port_generation": generation}


func consume_receipt(receipt: Dictionary) -> Dictionary:
	if not _held_reason.is_empty():
		return _refusal(_held_reason)
	var id: Variant = receipt.get("action_id")
	if not id is int or not _pending.has(id):
		# Genuine previous-generation completions are ignored, but an unknown
		# current-generation response while another mutation is pending is
		# an ambiguous delivery fault, not safe progress.
		if not _pending.is_empty() and (not receipt.get("port_generation") is int
				or int(receipt.port_generation) == generation):
			return _hold("UnknownOrRetiredAction")
		return {"ok": false, "outcome": "UnknownOrRetiredAction"}
	var request: Dictionary = _pending[id]
	if receipt.get("port_generation") != generation \
			or receipt.get("world_generation") != request.world_generation \
			or receipt.get("session") != request.session \
			or receipt.get("owner_epoch") != request.owner_epoch \
			or receipt.get("shard_session") != request.shard_session \
			or receipt.get("world_incarnation") != request.world_incarnation \
			or receipt.get("transport_generation") != request.transport_generation \
			or receipt.get("native_instance_id") != request.native_instance_id:
		return _hold("StaleOrForeignReceipt", int(id))
	var outcome: String = str(receipt.get("outcome", ""))
	if outcome=="Uncertain" or receipt.get("may_have_executed",false):
		var raw_uncertain: Variant = receipt.get("native_receipt",{})
		var uncertain_native: Dictionary = raw_uncertain if raw_uncertain is Dictionary else {}
		var uncertain: Dictionary = _hold("NativeEditCompletionUncertain",int(id),str(uncertain_native.get("outcome","Unknown")))
		uncertain["port_generation"] = generation
		uncertain["native_receipt"] = uncertain_native.duplicate(true)
		_append_result(uncertain)
		return uncertain
	if outcome not in TERMINAL_OUTCOMES:
		return _hold("NonterminalOrUnknownReceipt", int(id))
	if outcome == "Applied":
		var native_reason: String = _applied_receipt_error(receipt, request)
		if not native_reason.is_empty():
			return _hold("UnprovenNativeApplication", int(id), native_reason)
		if request.operation in ["erase", "ignite"]:
			var native: Dictionary = receipt.native_receipt
			var delivery: Dictionary = {"port_generation":generation,"transaction_id":native.transaction_id}
			for key: String in ["native_instance_id", "world_generation", "session", "owner_epoch",
					"shard_session", "world_incarnation", "transport_generation"]:
				delivery[key] = native[key]
			if not _latest_edit_delivery.is_empty():
				for key: String in delivery:
					if key != "transaction_id" and delivery[key] != _latest_edit_delivery.get(key):
						return _hold("ConflictingNativeEditOwner", int(id))
				delivery.transaction_id = maxi(int(delivery.transaction_id),int(_latest_edit_delivery.transaction_id))
			_latest_edit_delivery = delivery
	_pending.erase(id)
	var raw_native: Variant = receipt.get("native_receipt", {})
	var terminal: Dictionary = {"ok": outcome == "Applied", "outcome": outcome,
		"action_id": id, "port_generation": generation,
		"native_receipt": raw_native.duplicate(true) if raw_native is Dictionary else {}}
	if outcome!="Applied":
		# Refusal evidence is descriptive, never an authority-bearing receipt.
		# Keep only bounded scalars; untrusted nested targets must not be copied.
		var raw_refusal: Variant = receipt.get("refusal",{})
		var refusal: Dictionary = raw_refusal if raw_refusal is Dictionary else {}
		var requested: int = request.get("targets",request.get("terrain_cells",[request.target])).size()
		var summary: Dictionary = {"operation":str(request.operation),
			"domain":"terrain" if request.get("domain","")=="terrain" else "structural",
			"position":request.position,"requested_cells":requested}
		for key: String in ["outcome","detail"]:
			if refusal.get(key) is String: summary["native_outcome" if key=="outcome" else "detail"] = refusal[key].left(160)
		for key: String in ["unique_cells","eligible_cells"]:
			if refusal.get(key) is int and int(refusal[key])>=0 and int(refusal[key])<=requested: summary[key] = refusal[key]
		for key: String in ["seed","probability_ppm","material_filter"]:
			if request.get(key) is int: summary[key] = request[key]
		terminal["refusal"] = summary
	var raw_clocks: Variant = receipt.get("transport_timing",{})
	var clocks: Dictionary = raw_clocks if raw_clocks is Dictionary else {}
	if not clocks.is_empty():
		var valid_clocks: bool = true
		for key: String in ["captured_usec","admitted_usec","worker_started_usec","worker_completed_usec"]:
			if not clocks.get(key) is int: valid_clocks = false
		var observed: int = Time.get_ticks_usec()
		var captured: int = int(clocks.captured_usec) if valid_clocks else 0
		var admitted: int = int(clocks.admitted_usec) if valid_clocks else 0
		var started: int = int(clocks.worker_started_usec) if valid_clocks else 0
		var completed: int = int(clocks.worker_completed_usec) if valid_clocks else 0
		if valid_clocks and captured>0 and admitted>=captured and started>=admitted and completed>=started and observed>=completed:
			terminal["timing"] = {"input_admission_usec":admitted-captured,"worker_queue_usec":started-admitted,
				"native_owner_service_usec":completed-started,"main_receipt_delivery_usec":observed-completed,
				"input_to_receipt_usec":observed-captured}
		else:
			terminal["timing"] = {"timing_valid":false}
	_append_result(terminal)
	return terminal


# An applied edit requires a source-bound same-World native transaction and
# native revisioned material/geometry/physics receipt, not a success boolean.
static func _applied_receipt_error(receipt: Dictionary, request: Dictionary) -> String:
	var value: Variant = receipt.get("native_receipt")
	if not value is Dictionary:
		return "MissingNativeReceipt"
	var native: Dictionary = value
	if native.get("accepted") != true or native.get("same_world") != true:
		return "NotAcceptedSameWorld"
	for key: String in ["native_instance_id", "session", "world_generation",
			"transport_generation", "owner_epoch", "shard_session",
			"world_incarnation", "action_id", "port_generation"]:
		if native.get(key) != request.get(key):
			return "NativeIdentityMismatch"
	if native.get("operation") != request.operation or native.get("position") != request.position:
		return "NativeOperationMismatch"
	# Compare immutable pre-edit witnesses separately from resulting revisions.
	if request.get("domain","")=="terrain":
		if native.get("domain","")!="terrain" or native.get("source_terrain_cells")!=request.terrain_cells:
			return "NativeTerrainTargetMismatch"
		if not native.get("terrain_changed_cells") is Array or native.terrain_changed_cells.size()>request.terrain_cells.size():
			return "IncompleteNativeTerrainMutation"
		var admitted: Dictionary = {}
		for cell: Vector2i in request.terrain_cells: admitted[cell] = true
		var changed: Dictionary = {}
		for cell: Variant in native.terrain_changed_cells:
			if not cell is Vector2i or not admitted.has(cell) or changed.has(cell): return "UnrequestedNativeTerrainMutation"
			changed[cell] = true
		if int(native.get("changed_cells",-1))!=changed.size(): return "NativeTerrainCountMismatch"
	else:
		if not native.get("source_target") is Dictionary or native.source_target != request.target:
			return "NativeTargetMismatch"
		if request.has("targets") and native.get("source_targets")!=request.targets:
			return "NativeBatchTargetMismatch"
	if request.has("targets") or request.has("terrain_cells"):
		for key: String in ["probability_ppm","seed","material_filter"]:
			if native.get(key)!=request.get(key): return "NativeSelectionMismatch"
		for key: String in ["requested_cells","unique_cells","eligible_cells","changed_cells","removed_cells","geometry_rebuilds","native_edit_ns"]:
			if not native.get(key) is int or int(native[key])<0: return "IncompleteNativeBatchReceipt"
		var requested: int = request.get("targets",request.get("terrain_cells",[])).size()
		if int(native.requested_cells)!=requested or int(native.unique_cells)>requested \
				or int(native.eligible_cells)>int(native.unique_cells) or int(native.changed_cells)>int(native.eligible_cells) \
				or int(native.removed_cells)>int(native.changed_cells) or int(native.geometry_rebuilds)>1:
			return "InvalidNativeBatchAccounting"
		var expected_rebuilds: int = 1 if request.has("targets") and request.operation=="erase" and int(native.changed_cells)>0 else 0
		if int(native.geometry_rebuilds)!=expected_rebuilds \
				or (request.operation=="erase" and int(native.removed_cells)!=int(native.changed_cells)) \
				or (request.operation=="ignite" and int(native.removed_cells)!=0):
			return "InvalidNativeBatchEffect"
	if request.get("domain","")=="terrain":
		if not native.get("transaction_id") is int or int(native.transaction_id)<=0 \
				or not native.get("world_revision") is int or int(native.world_revision)<int(request.observation.world_revision):
			return "IncompleteNativeTerrainReceipt"
		return ""
	for key: String in ["transaction_id", "material_revision", "geometry_revision",
			"applied_physics_revision", "pose_serial", "body_generation",
			"incarnation", "owner", "cell"]:
		if not native.get(key) is int or int(native[key]) < 0:
			return "IncompleteNativeMutationReceipt"
	if int(native.transaction_id) <= 0:
		return "IncompleteNativeMutationReceipt"
	if request.has("targets"):
		for key: String in ["owner","cell","body_generation","pose_serial"]:
			if native.get(key)!=request.target.get(key): return "NativeBatchOwnerMismatch"
	return ""


func poll_results(worker: Object, maximum: int = 16) -> Dictionary:
	if not _held_reason.is_empty():
		return _refusal(_held_reason)
	if not enabled or worker == null or not worker is CyberSimulationWorker \
			or not worker.has_method(StringName(REQUIRED_METHODS[2])):
		if not _pending.is_empty():
			return _hold("ReceiptTransportUnavailable")
		return {"ok": false, "outcome": "SameWorldAdapterMissing"}
	if maximum < 1 or maximum > MAX_PENDING:
		return {"ok": false, "outcome": "InvalidReceiptLimit"}
	var replies: Variant = worker.call(REQUIRED_METHODS[2], maximum)
	if not replies is Array or replies.size() > maximum:
		if not _pending.is_empty():
			return _hold("InvalidReceiptBatch")
		return {"ok": false, "outcome": "InvalidReceiptBatch"}
	var accepted: int = 0
	var refused: int = 0
	for value: Variant in replies:
		var disposition: Dictionary
		if value is Dictionary:
			disposition = consume_receipt(value)
		elif not _pending.is_empty():
			disposition = _hold("InvalidReceipt")
		else:
			disposition = {"ok": false, "outcome": "InvalidReceipt"}
		if disposition.ok:
			accepted += 1
		else:
			refused += 1
		# Never process later successful receipts after an unknown outcome.
		if not _held_reason.is_empty():
			return {"ok": false, "outcome": _held_reason, "accepted": accepted,
				"other": refused, "pending": _pending.size(), "may_have_executed": true,
				"action_id":disposition.get("action_id",0)}
	return {"ok": true, "outcome": "ReceiptsObserved", "accepted": accepted,
		"other": refused, "pending": _pending.size()}


func retire(reason: String = "OwnerRetired") -> void:
	for id: Variant in _pending.keys():
		_append_result({"ok": false, "outcome": reason, "action_id": id,
			"port_generation": generation, "may_have_executed": true})
	_pending.clear()
	_held_reason = ""
	_pinned_owner.clear()
	_latest_edit_delivery.clear()
	generation += 1
	last_status = {"ready": false, "outcome": reason}


func _append_result(value: Dictionary) -> void:
	if results.size() >= MAX_RESULTS:
		results.pop_front()
	results.append(value.duplicate(true))
