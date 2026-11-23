class_name CyberObjectShardNativeWorker
extends RefCounted

signal results_available

# M3 preparation only. One actual CyberObjectShardLab and its one World live
# exclusively on this thread. No RIDs, nodes, resources or callables cross it.
# Main must await applied native receipts before advancing Rapier again.
const DATA_CAPACITY: int = 32
const CONTROL_CAPACITY: int = 8
const DATA_REPLY_CAPACITY: int = 32
const CONTROL_REPLY_CAPACITY: int = 8
const MAX_EXACT_SEQUENCE: int = 9007199254740991
const MAX_COMMAND_VALUE_BYTES: int = 65536
const MAX_EDIT_BATCH: int = 32
const DATA_OPERATIONS: Array[String] = ["edit", "edit_batch", "inspect", "erase_shard", "ignite", "ignite_shard", "tick", "motion", "prepare", "snapshot"]
const CONTROL_OPERATIONS: Array[String] = ["acknowledge", "cancel", "reset", "observe"]

var _thread := Thread.new()
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _data: Array[Dictionary] = []
var _control: Array[Dictionary] = []
var _data_results: Array[Dictionary] = []
var _control_results: Array[Dictionary] = []
var _next_sequence: int = 1
var _session: int = 0
var _generation: int = 0
var _started: bool = false
var _stopped: bool = false
var _stop_requested: bool = false
var _terminal: Dictionary = {}
var _inflight: Dictionary = {}
var _owner_thread: int = 0
var _maximum_pending: int = 0
var _maximum_reply_age_usec: int = 0
var _last_request_usec: int = 0
var _configuration: Dictionary = {}
var _maximum_snapshot_usec: int = 0
var _maximum_snapshot_value_bytes: int = 0
var _retained_reply_value_bytes: int = 0
var _maximum_reply_value_bytes: int = 0
var _maximum_godot_static_bytes: int = 0
var _snapshots: int = 0
var _maximum_execute_usec: int = 0
var _maximum_queue_wait_usec: int = 0


func start(configuration: Dictionary, transport_generation: int) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or transport_generation <= 0 or transport_generation > MAX_EXACT_SEQUENCE or not _copyable(configuration):
		return {"ok": false, "outcome": "InvalidTransportStart"}
	_mutex.lock()
	if _started or _stopped:
		_mutex.unlock()
		return {"ok": false, "outcome": "AlreadyStarted"}
	_started = true
	_generation = transport_generation
	_configuration = configuration.duplicate(true)
	_mutex.unlock()
	var code: Error = _thread.start(Callable(self, "_run"))
	if code != OK:
		_mutex.lock()
		_started = false
		_mutex.unlock()
		return {"ok": false, "outcome": "ThreadStartFailed", "error": code}
	return {"ok": true, "outcome": "Starting", "transport_generation": _generation}


func submit(operation: String, parameters: Dictionary, session: int, generation: int) -> Dictionary:
	var control: bool = operation in CONTROL_OPERATIONS
	if operation not in DATA_OPERATIONS and not control:
		return {"ok": false, "outcome": "UnsupportedTransportOperation"}
	if not _copyable(parameters):
		return {"ok": false, "outcome": "NonValuePayload"}
	if not _typed_parameters(operation, parameters):
		return {"ok": false, "outcome": "InvalidTransportParameters"}
	_mutex.lock()
	var reason: String = ""
	if not _started or _stopped or _stop_requested:
		reason = "TransportClosed"
	elif generation != _generation or session != _session or _session <= 0:
		reason = "StaleTransportIdentity"
	elif operation == "reset" and _pending_reset_sequence_locked() > 0:
		# Reset changes the session. A second queued reset cannot be admitted
		# against the old session while lost-receipt recovery is still queued
		# or executing. Check and enqueue under this same transport mutex.
		reason = "PreviousResetStillRunning"
	elif _next_sequence >= MAX_EXACT_SEQUENCE:
		reason = "TransportSequenceExhausted"
	elif (control and _control.size() >= CONTROL_CAPACITY) or (not control and _data.size() >= DATA_CAPACITY):
		reason = "ControlCapacity" if control else "DataCapacity"
	if not reason.is_empty():
		_mutex.unlock()
		return {"ok": false, "outcome": reason}
	var sequence: int = _next_sequence
	_next_sequence += 1
	var request: Dictionary = {"operation": operation, "parameters": parameters.duplicate(true), "session": session,
		"transport_generation": generation, "sequence": sequence, "control": control, "admitted_usec": Time.get_ticks_usec()}
	if control:
		_control.append(request)
	else:
		_data.append(request)
	_maximum_pending = maxi(_maximum_pending, _data.size() + _control.size())
	_mutex.unlock()
	_wake.post()
	return {"ok": true, "outcome": "Queued", "operation": operation, "sequence": sequence, "transport_generation": generation, "session": session}


func take_results(maximum: int = 16, control_only: bool = false) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	_mutex.lock()
	for index: int in range(clampi(maximum, 0, 40)):
		var row: Dictionary = {}
		if not _control_results.is_empty():
			row = _control_results.pop_front()
		elif not control_only and not _data_results.is_empty():
			row = _data_results.pop_front()
		else:
			break
		_maximum_reply_age_usec = maxi(_maximum_reply_age_usec, Time.get_ticks_usec() - int(row.finished_usec))
		_retained_reply_value_bytes -= int(row.get("value_payload_bytes", 0))
		rows.append(row)
	_mutex.unlock()
	if not rows.is_empty():
		_wake.post()
	return rows


func request_stop() -> void:
	# Stop has its own slot and wakeup. Saturated data/control queues cannot
	# consume the capacity needed to request explicit whole-session disposal.
	_mutex.lock()
	if _stopped or _stop_requested:
		_mutex.unlock()
		return
	if not _started:
		_stopped = true
		_terminal = {"ok": true, "outcome": "Stopped", "scope": "No native thread was started"}
		_mutex.unlock()
		results_available.emit()
		return
	_stop_requested = true
	_terminal.clear()
	_mutex.unlock()
	_wake.post()


func join_if_stopped() -> Dictionary:
	_mutex.lock()
	var stopped: bool = _stopped
	var terminal: Dictionary = _terminal.duplicate(true)
	_mutex.unlock()
	if not stopped:
		return {"ok": false, "outcome": "StillRunning"}
	if _thread.is_started():
		_thread.wait_to_finish()
	return terminal


func diagnostics() -> Dictionary:
	_mutex.lock()
	var result: Dictionary = {"transport_generation": _generation, "session": _session,
		"started": _started, "stopped": _stopped, "stop_requested": _stop_requested,
		"owner_thread": _owner_thread, "inflight_sequence": _inflight.get("sequence", 0),
		"pending_reset_sequence": _pending_reset_sequence_locked(),
		"pending_data": _data.size(), "pending_control": _control.size(),
		"data_results": _data_results.size(), "control_results": _control_results.size(),
		"maximum_pending": _maximum_pending, "maximum_reply_age_usec": _maximum_reply_age_usec,
		"last_native_call_usec": _last_request_usec,
		"maximum_native_execute_usec": _maximum_execute_usec, "maximum_queue_wait_usec": _maximum_queue_wait_usec,
		"snapshot_copies": _snapshots, "maximum_snapshot_usec": _maximum_snapshot_usec,
		"maximum_snapshot_value_bytes": _maximum_snapshot_value_bytes,
		"retained_reply_value_bytes": _retained_reply_value_bytes, "maximum_reply_value_bytes": _maximum_reply_value_bytes,
		"maximum_godot_static_bytes": _maximum_godot_static_bytes,
		"byte_scope": "Value payload sizes include packed buffers, scalar fields and UTF-32 strings; exclude container/allocator overhead and shared-copy deduplication. Godot static bytes are process-wide and exclude native std allocations.",
		"limits": {"data": DATA_CAPACITY, "control": CONTROL_CAPACITY,
			"data_results": DATA_REPLY_CAPACITY, "control_results": CONTROL_REPLY_CAPACITY,
			"command_value_bytes": MAX_COMMAND_VALUE_BYTES, "edit_batch": MAX_EDIT_BATCH,
			"native_world_area": 262144, "native_total_shard_bbox_area": 12288},
		"terminal": _terminal.duplicate(true)}
	_mutex.unlock()
	return result


func _pending_reset_sequence_locked() -> int:
	# Call only with _mutex held. No native call or wait is performed here.
	if _inflight.get("operation", "") == "reset":
		return int(_inflight.sequence)
	for request: Dictionary in _control:
		if request.operation == "reset":
			return int(request.sequence)
	return 0


func _run() -> void:
	# Construction, every call, reset disposal and destruction happen here.
	var native: RefCounted
	var configured: bool = false
	var configuration: Dictionary = _configuration.duplicate(true)
	var opened: Dictionary = {"ok": false, "outcome": "NativeUnavailable"}
	var frame: Dictionary = {}
	var capabilities: Dictionary = {}
	if ClassDB.class_exists(&"CyberObjectShardLab"):
		native = ClassDB.instantiate(&"CyberObjectShardLab")
		opened = native.configure(configuration)
		configured = bool(opened.get("ok", false))
		if configured:
			frame = _snapshot(native)
			capabilities = native.capabilities()
	var opened_reply: Dictionary = {"operation": "opened", "sequence": 0, "transport_generation": _generation,
		"session": int(frame.get("session", 0)), "result": opened, "frame": frame, "finished_usec": Time.get_ticks_usec(),
		"owner_thread": OS.get_thread_caller_id(), "capabilities": capabilities}
	opened_reply["value_payload_bytes"] = _value_payload_bytes(opened_reply)
	_mutex.lock()
	_owner_thread = OS.get_thread_caller_id()
	_session = int(frame.get("session", 0))
	_control_results.append(opened_reply)
	_retained_reply_value_bytes += int(opened_reply.value_payload_bytes)
	_maximum_reply_value_bytes = maxi(_maximum_reply_value_bytes, _retained_reply_value_bytes)
	_mutex.unlock()
	# Notification carries no authority or payload. Main connects DEFERRED and
	# still consumes/validates the bounded mailbox; no native or RID call is
	# made on another owner. Never emit while holding the queue mutex.
	results_available.emit()
	while true:
		_mutex.lock()
		var stopping: bool = _stop_requested
		_mutex.unlock()
		if stopping:
			var disposed: Dictionary = native.reset(0, 12) if native != null else {"ok": true, "outcome": "NoNativeOwner"}
			if not configured and disposed.get("outcome", "") == "ExclusiveOwnerRequired":
				# This object was constructed here and has never left this thread;
				# the native refusal therefore means no coordinator was configured.
				disposed = {"ok": true, "outcome": "UnconfiguredOwnerReleased"}
			_mutex.lock()
			_terminal = {"ok": disposed.get("ok", false), "outcome": "Stopped" if disposed.get("ok", false) else "StopDisposalRefused",
				"transport_generation": _generation, "disposed_session": _session, "disposal": disposed,
				"cancelled_data": _data.size(), "cancelled_control": _control.size(), "owner_thread": _owner_thread,
				"scope": "Explicit whole-session shutdown: prior inventory accounted by reset; the fresh scenario-0 fixture is released with the owner"}
			if not disposed.get("ok", false):
				# Retain the native owner on this thread. A terminal refusal is not
				# permission to free possibly retained material on the main thread.
				_stop_requested = false
				_mutex.unlock()
				results_available.emit()
				_wake.wait()
				continue
			_data.clear()
			_control.clear()
			_mutex.unlock()
			native = null
			_mutex.lock()
			_stopped = true
			_mutex.unlock()
			results_available.emit()
			return
		var request: Dictionary = _take_request()
		if request.is_empty():
			_wake.wait()
			continue
		var started: int = Time.get_ticks_usec()
		var result: Dictionary
		if not configured:
			result = {"ok": false, "outcome": "NativeUnavailable"}
		elif int(request.session) != _session or int(request.transport_generation) != _generation:
			result = {"ok": false, "outcome": "StaleTransportIdentity"}
		else:
			result = _execute(native, str(request.operation), request.parameters)
		var executed: int = Time.get_ticks_usec()
		# Intermediate applied Rapier segments have exact native pose receipts
		# but no new semantic tick. Avoid redundant full World snapshots.
		var intermediate_motion: bool = configured and _compact_motion_packet_eligible(
			str(request.operation), request.parameters, result)
		if intermediate_motion:
			frame = {"session": _session,
				"tick": int(result.semantic_tick),
				"quarantined": false, "transient_motion_receipt": true}
		else:
			frame = _snapshot(native) if configured else {}
		if str(request.operation) == "inspect" and result.get("ok", false):
			# The facade reads World only. Resolve moving inventory from the
			# same authoritative native publication on its exclusive worker.
			result = _inspect_snapshot(frame, request.parameters.position, result)
		var snapshotted: int = Time.get_ticks_usec()
		var response: Dictionary = {"operation": request.operation, "sequence": request.sequence,
			"transport_generation": request.transport_generation, "requested_session": request.session,
			"session": frame.get("session", _session), "result": result, "frame": frame,
			"admitted_usec": request.admitted_usec, "started_usec": started, "finished_usec": 0,
			"queue_wait_usec": started - int(request.admitted_usec), "native_execute_usec": executed - started,
			"snapshot_usec": snapshotted - executed, "receipt_value_accounting_usec": 0, "worker_total_usec": 0,
			"owner_thread": _owner_thread}
		response["value_payload_bytes"] = _value_payload_bytes(response)
		var finished: int = Time.get_ticks_usec()
		response.finished_usec = finished
		response.receipt_value_accounting_usec = finished - snapshotted
		response.worker_total_usec = finished - started
		_mutex.lock()
		_session = int(frame.get("session", _session))
		_last_request_usec = finished - started
		_maximum_execute_usec = maxi(_maximum_execute_usec, executed - started)
		_maximum_queue_wait_usec = maxi(_maximum_queue_wait_usec, started - int(request.admitted_usec))
		if request.control:
			_control_results.append(response)
		else:
			_data_results.append(response)
		_retained_reply_value_bytes += int(response.value_payload_bytes)
		_maximum_reply_value_bytes = maxi(_maximum_reply_value_bytes, _retained_reply_value_bytes)
		_inflight.clear()
		_mutex.unlock()
		results_available.emit()


func _take_request() -> Dictionary:
	_mutex.lock()
	var request: Dictionary = {}
	if not _control.is_empty() and _control_results.size() < CONTROL_REPLY_CAPACITY:
		request = _control.pop_front()
	elif not _data.is_empty() and _data_results.size() < DATA_REPLY_CAPACITY:
		request = _data.pop_front()
	_inflight = request
	_mutex.unlock()
	return request


func _execute(native: RefCounted, operation: String, parameters: Dictionary) -> Dictionary:
	match operation:
		"edit":
			if parameters.get("only_if_empty", false):
				var before: Dictionary = native.inspect(parameters.position)
				if not before.get("ok", false) or int(before.get("material", -1)) != 0:
					return {"ok": false, "outcome": "FixtureCellOccupied", "detail": "External fixture never replaces existing World inventory"}
			return native.edit_cell(parameters.get("position", Vector2i(-1, -1)), int(parameters.get("material", -1)),
				int(parameters.get("state_a", 0)), int(parameters.get("state_b", 0)), int(parameters.get("temperature", 200)))
		"edit_batch":
			# Fixture authoring keeps one authoritative World and uses the same
			# native edit admission for every cell. This is an ordered set of
			# individual mutations, not an all-or-none transaction. Every refusal
			# is retained, and there is one copied publication after the batch.
			var results: Array[Dictionary] = []
			var accepted: int = 0
			for index: int in range(parameters.edits.size()):
				var edit: Dictionary = parameters.edits[index]
				var row: Dictionary = _execute(native, "edit", edit)
				row["index"] = index
				row["position"] = edit.position
				results.append(row)
				if row.get("ok", false):
					accepted += 1
			return {"ok": true, "outcome": "BatchCompleted", "accepted": accepted,
				"refused": results.size() - accepted, "results": results}
		"inspect": return native.inspect(parameters.position)
		"erase_shard": return native.erase_shard(parameters)
		"ignite": return native.ignite(parameters.get("position", Vector2i(-1, -1)))
		"ignite_shard": return native.ignite_shard(int(parameters.get("id", 0)), int(parameters.get("generation", 0)), int(parameters.get("cell", -1)))
		"tick": return native.step(parameters.get("poses", []))
		"motion": return native.accept_motion(parameters.get("poses", []))
		"prepare": return native.prepare_next()
		"acknowledge": return native.acknowledge(parameters)
		"cancel": return native.cancel(int(parameters.get("transaction", 0)))
		"reset": return native.reset(int(parameters.get("scenario", 0)), int(parameters.get("seed", 12)))
		"snapshot", "observe": return {"ok": true, "outcome": "Observed"}
	return {"ok": false, "outcome": "UnsupportedTransportOperation"}


static func _compact_motion_packet_eligible(operation: String, parameters: Dictionary,
		result: Dictionary) -> bool:
	# Only an exact native applied-pose receipt can authorize the abbreviated
	# non-renderable packet; any refusal receives the full diagnostic snapshot.
	return operation == "motion" and parameters.get("final_segment", true) == false \
		and result.get("ok", false) == true and result.get("applied", false) == true \
		and result.get("semantic_tick") is int and int(result.semantic_tick) >= 0 \
		and result.get("accepted_pose_serials") is Array


static func _inspect_snapshot(frame: Dictionary, position: Vector2i, world_result: Dictionary) -> Dictionary:
	for shard: Dictionary in frame.get("shards", []):
		if not shard.get("owns_inventory", false):
			continue
		var transform := Transform2D(float(shard.rotation), Vector2(float(shard.position_x), float(shard.position_y)))
		var local: Vector2 = transform.affine_inverse() * (Vector2(position) + Vector2.ONE * 0.5)
		var x: int = floori(local.x)
		var y: int = floori(local.y)
		if x < 0 or y < 0 or x >= int(shard.width) or y >= int(shard.height):
			continue
		var cell: int = y * int(shard.width) + x
		if int(shard.roles[cell]) == 0:
			continue
		return {"ok": true, "outcome": "Observed", "owner": "ObjectShard", "position": position,
			"session": shard.session, "id": shard.id, "generation": shard.generation,
			"body_generation": shard.body_generation, "cell": cell, "incarnation": shard.incarnations[cell],
			"material": int(shard.materials[cell]), "state_a": int(shard.states_a[cell]),
			"state_b": int(shard.states_b[cell]), "temperature": int(shard.temperature[cell]),
			"geometry_revision": shard.geometry_revision, "pose_serial": shard.pose_serial,
			"material_revision": shard.material_revision, "tick": frame.tick}
	var result: Dictionary = world_result.duplicate(true)
	result["session"] = frame.get("session", 0)
	result["tick"] = frame.get("tick", 0)
	return result


static func _copyable(value: Variant, depth: int = 0, remaining: Array = []) -> bool:
	if remaining.is_empty():
		remaining.append_array([1024, MAX_COMMAND_VALUE_BYTES])
	remaining[0] = int(remaining[0]) - 1
	remaining[1] = int(remaining[1]) - _leaf_value_bytes(value)
	if depth > 8 or int(remaining[0]) < 0 or int(remaining[1]) < 0:
		return false
	if typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME,
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_DICTIONARY, TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY]:
		return false
	if value is Dictionary:
		if value.size() > 128:
			return false
		for key: Variant in value:
			if not key is String and not key is StringName:
				return false
			remaining[1] = int(remaining[1]) - str(key).length() * 4
			if str(key).length() > 64 or int(remaining[1]) < 0 or not _copyable(value[key], depth + 1, remaining):
				return false
	elif value is Array:
		if value.size() > 64:
			return false
		for child: Variant in value:
			if not _copyable(child, depth + 1, remaining):
				return false
	elif (value is PackedByteArray or value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedVector2Array) and value.size() > 4096:
		return false
	elif (value is String or value is StringName) and str(value).length() > 256:
		return false
	elif value is float and not is_finite(value):
		return false
	return true


func _snapshot(native: RefCounted) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var value: Dictionary = native.snapshot()
	var elapsed: int = Time.get_ticks_usec() - started
	var bytes: int = _value_payload_bytes(value)
	_mutex.lock()
	_snapshots += 1
	_maximum_snapshot_usec = maxi(_maximum_snapshot_usec, elapsed)
	_maximum_snapshot_value_bytes = maxi(_maximum_snapshot_value_bytes, bytes)
	_maximum_godot_static_bytes = maxi(_maximum_godot_static_bytes, OS.get_static_memory_usage())
	_mutex.unlock()
	return value


static func _value_payload_bytes(value: Variant) -> int:
	var bytes: int = _leaf_value_bytes(value)
	if value is Dictionary:
		for key: Variant in value:
			bytes += str(key).length() * 4 + _value_payload_bytes(value[key])
	elif value is Array:
		for child: Variant in value:
			bytes += _value_payload_bytes(child)
	return bytes


static func _leaf_value_bytes(value: Variant) -> int:
	if value is Dictionary or value is Array:
		return 0
	if value is PackedByteArray:
		return value.size()
	if value is PackedInt32Array or value is PackedFloat32Array:
		return value.size() * 4
	if value is PackedInt64Array or value is PackedFloat64Array or value is PackedVector2Array:
		return value.size() * 8
	if value is String or value is StringName:
		return str(value).length() * 4
	if value is Rect2i or value is Rect2:
		return 16
	return 0 if value == null else 8


static func _typed_parameters(operation: String, parameters: Dictionary) -> bool:
	# Keep the native facade's typed boundary intact. Transport must never turn a
	# malformed String/bool/float into an integer authority by coercing it first.
	var integers: Array[String] = []
	match operation:
		"edit_batch":
			if not parameters.get("edits") is Array or parameters.edits.is_empty() or parameters.edits.size() > MAX_EDIT_BATCH:
				return false
			for edit: Variant in parameters.edits:
				if not edit is Dictionary or not _typed_parameters("edit", edit):
					return false
			return true
		"edit":
			if not parameters.get("position") is Vector2i:
				return false
			if parameters.has("only_if_empty") and not parameters.only_if_empty is bool:
				return false
			integers = ["material", "state_a", "state_b", "temperature"]
			if not parameters.has("material"):
				return false
		"ignite", "inspect":
			return parameters.get("position") is Vector2i
		"ignite_shard": integers = ["id", "generation", "cell"]
		"cancel": integers = ["transaction"]
		"reset": integers = ["scenario", "seed"]
		"tick", "motion":
			if operation == "motion" and parameters.has("final_segment") \
					and not parameters.final_segment is bool:
				return false
			return parameters.get("poses") is Array and parameters.poses.size() <= 3
	for key: String in integers:
		if parameters.has(key) and not parameters[key] is int:
			return false
	return true
