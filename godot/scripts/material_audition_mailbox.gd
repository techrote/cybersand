extends RefCounted

# This value-only mailbox has no thread or World of its own. Every method is
# called under CyberSimulationWorker._mutex; consume is called only by that
# worker between completed ticks. Cancellation and native commit share that
# same finite critical section.
const MAX_RECEIPTS := 16
const MAX_MATERIALS := 132
const MAX_REACTIONS := 56
var enabled := false
var session_id := "%d-%d" % [get_instance_id(),Time.get_ticks_usec()]
var _serial := 0
var _generation := -1
var _state: Dictionary = {"ok":false,"status":"waiting","error":"Waiting for the native owner boundary."}
var _pending: Dictionary = {}
var _receipts: Dictionary = {}
var _receipt_order: Array[String] = []

func state(reason: String = "") -> Dictionary:
	var result: Dictionary = _state.duplicate(true)
	result["session_id"] = session_id
	result["pending"] = not _pending.is_empty()
	result["request_id"] = str(_pending.get("request_id",""))
	if not reason.is_empty():
		result["ok"] = false
		result["status"] = "unavailable"
		result["error"] = reason
	return result

func _refusal(reason: String, code: String = "refused") -> Dictionary:
	return {"ok":false,"accepted":false,"status":"refused","code":code,"error":reason}

func _shape_error(request: Dictionary) -> String:
	if request.size() != 4: return "A request needs session_id, world_id, expected_revision and profile only."
	for key: Variant in request:
		if key not in ["session_id","world_id","expected_revision","profile"]: return "Unknown request field."
	if not request.get("session_id") is String or not request.get("world_id") is String:
		return "Session and World identities must be strings."
	if not request.get("expected_revision") is int or int(request.expected_revision) < 0:
		return "Expected configuration revision must be a nonnegative integer."
	if not request.get("profile") is Dictionary: return "Profile must be an object."
	var profile: Dictionary = request.profile
	if profile.size() != 4: return "Profile needs schema_version, profile_id, materials and reactions only."
	for key: Variant in profile:
		if key not in ["schema_version","profile_id","materials","reactions"]: return "Unknown profile field."
	if not profile.get("materials") is Array or not profile.get("reactions") is Array:
		return "Material and reaction changes must be arrays."
	if profile.materials.size() > MAX_MATERIALS or profile.reactions.size() > MAX_REACTIONS:
		return "Profile exceeds the bounded existing catalogue."
	# Reject nested/unbounded data before taking an immutable request copy.
	for collection: String in ["materials","reactions"]:
		for row: Variant in profile[collection]:
			if not row is Dictionary or row.size() > 3: return "Invalid bounded change row."
			for value: Variant in row.values():
				if typeof(value) not in [TYPE_INT,TYPE_FLOAT]: return "Change rows contain numeric values only."
	if typeof(profile.get("schema_version")) not in [TYPE_INT,TYPE_FLOAT] or not profile.get("profile_id") is String:
		return "Profile schema and identity have invalid types."
	if str(profile.profile_id).length() > 64: return "Profile identity is too long."
	return ""

func request(candidate: Dictionary, reason: String) -> Dictionary:
	enabled = true
	var error: String = _shape_error(candidate)
	if not error.is_empty(): return _refusal(error,"invalid_request")
	if not reason.is_empty(): return _refusal(reason,"owner_unavailable")
	if not _state.get("ok",false): return _refusal(str(_state.get("error","Native readback unavailable.")),"readback_unavailable")
	if not _pending.is_empty(): return _refusal("A configuration is pending. Wait for its receipt or cancel it.","busy")
	if candidate.session_id != session_id: return _refusal("The host session has retired.","session_mismatch")
	if candidate.world_id != _state.get("world_id",""): return _refusal("The native World has changed.","world_mismatch")
	if candidate.expected_revision != _state.get("revision",-1): return _refusal("The active configuration changed. Refresh before applying.","stale_revision")
	_serial += 1
	_pending = candidate.duplicate(true)
	_pending["request_id"] = "%s:%d" % [session_id,_serial]
	return {"ok":true,"accepted":true,"status":"pending","pending":true,"request_id":_pending.request_id}

func _record(receipt: Dictionary) -> Dictionary:
	var id: String = str(receipt.request_id)
	_receipts[id] = receipt.duplicate(true)
	_receipt_order.append(id)
	while _receipt_order.size() > MAX_RECEIPTS:
		_receipts.erase(_receipt_order.pop_front())
	return receipt

func refuse_pending(reason: String, code: String = "retired") -> void:
	if _pending.is_empty(): return
	var receipt: Dictionary = _refusal(reason,code)
	receipt["request_id"] = _pending.request_id
	receipt["session_id"] = session_id
	receipt["world_id"] = _pending.world_id
	receipt["revision"] = _state.get("revision",-1)
	_record(receipt)
	_pending.clear()

func poll(request_id: String) -> Dictionary:
	if not _pending.is_empty() and _pending.request_id == request_id:
		return {"ok":true,"status":"pending","pending":true,"request_id":request_id}
	if _receipts.has(request_id): return _receipts[request_id].duplicate(true)
	var result: Dictionary = {"ok":false,"status":"unavailable","code":"unknown_request",
		"error":"Unknown or expired request receipt; refresh the active configuration. Activation or refusal cannot be inferred from a missing receipt."}
	result["request_id"] = request_id
	return result

func cancel(request_id: String) -> Dictionary:
	if not _pending.is_empty() and _pending.request_id == request_id:
		refuse_pending("Cancelled before native activation.","cancelled")
		return poll(request_id)
	var result: Dictionary = poll(request_id)
	if result.get("accepted",false) or result.get("status") == "active":
		result["cancelled"] = false
		result["cancellation_note"] = "Already activated; use Revert to restore configuration."
	return result

func consume(world: Variant, generation: int, reason: String) -> void:
	if not enabled: return
	if not reason.is_empty():
		refuse_pending(reason,"owner_unavailable")
		return
	if world == null or not world.has_method(&"get_material_audition_state"):
		_state = _refusal("This runtime does not provide current-scene material audition. Rebuild its native extension.","unsupported_runtime")
		refuse_pending(str(_state.error),"unsupported_runtime")
		return
	if _generation != generation or not _state.get("ok",false):
		_state = world.get_material_audition_state()
		_generation = generation
		if not _pending.is_empty() and _pending.world_id != _state.get("world_id",""):
			refuse_pending("The native World was replaced before activation.","world_mismatch")
	if _pending.is_empty(): return
	var command: Dictionary = _pending
	_pending = {}
	var receipt: Dictionary = world.apply_material_audition({"world_id":command.world_id,
		"expected_revision":command.expected_revision,"profile":command.profile})
	# Native readback is the authority after success AND refusal. No UI-provided
	# field is allowed to substitute for the activated profile or its revision.
	_state = world.get_material_audition_state()
	if receipt.get("status") == "active_readback_failed" and _state.get("ok",false) \
		and _state.get("world_id") == command.world_id and int(_state.get("revision",-1)) == int(command.expected_revision)+1:
		receipt["ok"] = true
		receipt["status"] = "active"
		receipt["error"] = ""
		receipt["profile"] = _state.profile.duplicate(true)
		receipt["readback_recovered"] = true
	receipt["request_id"] = command.request_id
	receipt["session_id"] = session_id
	receipt["pending"] = false
	receipt["state"] = state()
	_record(receipt)
