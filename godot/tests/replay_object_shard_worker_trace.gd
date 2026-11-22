extends SceneTree

const Capture = preload("res://scripts/object_shard_capture.gd")
const Host = preload("res://scripts/object_shard_worker_host.gd")
var host = Host.new()
var differences: Array[Dictionary] = []
var actions: int = 0
var ticks: int = 0
var checks: int = 0
var incomplete_barrier: bool = false
var replay_admitted: bool = false
var recorded_session: int = 0
var replay_session: int = 0


func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")


func _idle() -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		host.poll()
		if host.failed:
			return false
		if host.state == "Idle" and host.actions.is_empty() and host.pending.is_empty():
			return true
		await process_frame
	return false


func _difference(row: Dictionary, reason: String, observed: Dictionary = {}) -> void:
	if differences.size() < 64:
		differences.append({"sequence": row.get("sequence", -1), "reason": reason, "observed": observed})


func _run() -> void:
	var input_path: String = ""
	var output_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--objectshard-replay="):
			input_path = argument.trim_prefix("--objectshard-replay=")
		elif argument.begins_with("--objectshard-replay-report="):
			output_path = argument.trim_prefix("--objectshard-replay-report=")
	var trace: Dictionary = Capture.read_trace(input_path, OS.get_environment("CYBERSAND_SOURCE_REVISION"))
	checks += 1
	if not trace.get("ok", false):
		_difference({}, "Trace admission refused", trace)
		_finish(output_path)
		return
	checks += 1
	if trace.header.get("host") != "standalone-exclusive-worker-rehearsal":
		_difference({}, "ReplayHostMismatch")
		_finish(output_path)
		return
	var issue: Dictionary = admission_issue(trace)
	checks += 1
	if not issue.is_empty():
		incomplete_barrier = bool(issue.get("incomplete_barrier", false))
		_difference({"sequence": issue.get("sequence", -1)}, str(issue.reason), issue.get("observed", {}))
		_finish(output_path)
		return
	replay_admitted = true
	recorded_session = int(trace.header.session)
	var configuration: Dictionary = {"scenario": int(trace.header.scenario), "seed": int(trace.header.seed),
		"width": int(trace.header.get("width", 192)), "height": int(trace.header.get("height", 128))}
	var started: Dictionary = host.open(configuration, int(trace.header.get("transport_generation", 1)))
	checks += 1
	if not started.get("ok", false) or not await _idle():
		_difference({}, "Actual worker host could not open", started)
	else:
		replay_session = host.session
		var requested_tick: int = -1
		for row: Dictionary in trace.rows:
			if differences.size() >= 64:
				break
			match str(row.kind):
				"step_requested":
					if requested_tick >= 0:
						_difference(row, "OverlappingRecordedSemanticSteps")
						break
					requested_tick = int(row.tick)
				"step_completed":
					checks += 1
					if requested_tick < 0 or int(host.frame.tick) != requested_tick:
						_difference(row, "CompletedStepHasNoMatchingSourceTick", {"native_tick": host.frame.get("tick", -1), "requested_tick": requested_tick})
						break
					if not host.request_tick().get("ok", false) or not await _idle():
						_difference(row, "ActualSemanticStepRefused", {"state": host.state, "status": host.status})
						break
					ticks += 1
					requested_tick = -1
					checks += 1
					if int(host.frame.tick) != int(row.tick):
						_difference(row, "SemanticTickMismatch", {"tick": host.frame.tick})
				"action":
					var name: String = str(row.detail.action)
					actions += 1
					if name == "pause":
						continue
					checks += 1
					if name not in ["edit", "ignite", "inspect"] or requested_tick >= 0:
						_difference(row, "UnsupportedOrInterleavedRecordedAction", {"action": name, "pending_tick": requested_tick})
						break
					var input: Dictionary = row.detail.parameters
					var parameters: Dictionary = {"position": Vector2i(int(input.position[0]), int(input.position[1]))}
					if name == "edit":
						for key: String in ["material", "state_a", "state_b", "temperature"]:
							parameters[key] = int(input[key])
					if input.has("only_if_empty"):
						parameters["only_if_empty"] = input.only_if_empty
					if input.has("target"):
						var decoded: Dictionary = _decode_target(input.target)
						if decoded.is_empty():
							_difference(row, "MalformedRecordedTarget")
							break
						# Only a fresh registry's session namespace is rebound. Every
						# owner/cell/generation/pose/material witness stays untouched.
						decoded.session = replay_session if int(decoded.get("session", 0)) == recorded_session else 0
						parameters["target"] = decoded
					var queued: Dictionary = host.queue_action(name, parameters)
					var observed: Dictionary = queued
					if queued.get("ok", false):
						if not await _idle():
							_difference(row, "ActualActionDidNotComplete", {"state": host.state, "status": host.status})
							break
						observed = host.last_action
					var expected: Dictionary = row.detail.result
					checks += 1
					if observed.get("ok", false) != expected.get("ok", false) or observed.get("outcome", "") != expected.get("outcome", ""):
						_difference(row, "NamedActionOutcomeMismatch", observed)
				"failure", "footer", "checkpoint":
					if requested_tick >= 0:
						incomplete_barrier = true
						_difference(row, "IncompleteAsyncBarrierNeedsRecordedAdversarialSchedule", {"native_tick_before_barrier": requested_tick})
						break
			if not differences.is_empty():
				break
	host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.state != "Closed" and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	checks += 1
	if host.state != "Closed":
		_difference({}, "OwnerShutdownHeld", {"state": host.state, "status": host.status})
	_finish(output_path)


static func admission_issue(trace: Dictionary) -> Dictionary:
	var requested_tick: int = -1
	for row: Dictionary in trace.get("rows", []):
		var kind: String = str(row.get("kind", ""))
		var detail: Dictionary = row.get("detail", {})
		if kind == "step_requested":
			requested_tick = int(row.get("tick", -1))
		elif kind == "step_completed":
			requested_tick = -1
		if kind in ["checkpoint", "footer", "failure"] and requested_tick >= 0:
			return {"reason": "IncompleteAsyncBarrierNeedsRecordedAdversarialSchedule", "sequence": row.sequence,
				"incomplete_barrier": true, "observed": {"native_tick_before_barrier": requested_tick}}
		if kind == "event" and str(detail.get("kind", "")) in ["ActionRetired", "FixtureBatchRetired"]:
			var retirement: Variant = detail.get("detail", {})
			if not retirement is Dictionary:
				return {"reason": "MalformedRetiredMutationEvidence", "sequence": row.sequence}
			if not retirement.get("may_have_executed") is bool or retirement.get("may_have_executed") != false or str(retirement.get("outcome", "")).contains("OutcomeUnknown"):
				return {"reason": "UnknownMutationOutcomeRequiresAdversarialSchedule", "sequence": row.sequence,
					"observed": {"event": detail.kind, "outcome": retirement.get("outcome", "unknown")}}
		if kind == "footer" and (not detail.get("complete_prefix") is bool or detail.get("complete_prefix") != true):
			return {"reason": "IncompleteTracePrefix", "sequence": row.sequence, "observed": detail}
		if kind == "checkpoint":
			var metadata: Variant = detail.get("capture", {})
			if detail.has("capture") and (not metadata is Dictionary or not metadata.get("complete_prefix") is bool or metadata.get("complete_prefix") != true):
				return {"reason": "IncompleteTracePrefix", "sequence": row.sequence}
			var pending: Variant = detail.get("pending", {})
			var held: Variant = detail.get("held_request", {})
			if not pending is Dictionary or not held is Dictionary or not pending.is_empty() or not held.is_empty():
				return {"reason": "UnresolvedNativeOperationRequiresAdversarialSchedule", "sequence": row.sequence}
		if kind == "failure":
			return {"reason": "RecordedWorkerFailureRequiresAdversarialSchedule", "sequence": row.sequence}
	var header: Dictionary = trace.get("header", {})
	if header.get("standalone_replay") == false or header.get("replay_identity_scope") == "inherited-native-registry":
		return {"reason": "InheritedRegistryHistoryRequiresPriorSessionReplay", "sequence": 0}
	if not header.get("standalone_replay") is bool or header.get("standalone_replay") != true or header.get("replay_identity_scope") != "fresh-native-registry":
		return {"reason": "ExplicitFreshRegistryReplayContractRequired", "sequence": 0}
	if not Capture._integer(header.get("session"), 1, 9007199254740991):
		return {"reason": "MalformedReplaySessionIdentity", "sequence": 0}
	return {}


static func _decode_target(value: Variant) -> Dictionary:
	if not value is Dictionary or not Capture._position(value.get("position")):
		return {}
	var target: Dictionary = value.duplicate(true)
	target.position = Vector2i(int(value.position[0]), int(value.position[1]))
	for key: String in ["session", "transport_generation", "publication_sequence", "owner", "cell", "generation", "body_generation", "geometry_revision", "applied_physics_revision", "pose_serial", "material_revision", "incarnation"]:
		if target.has(key):
			if not Capture._integer(target[key], 0, 9007199254740991):
				return {}
			target[key] = int(target[key])
	if target.has("expected"):
		if not target.expected is Dictionary:
			return {}
		for key: String in ["material", "state_a", "state_b", "temperature"]:
			if not Capture._integer(target.expected.get(key), -32768, 65535):
				return {}
			target.expected[key] = int(target.expected[key])
	return target


func _finish(output_path: String) -> void:
	var report: Dictionary = {"schema": "objectshard-worker-action-replay-v1", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"host": "standalone-exclusive-worker-rehearsal", "checks": checks, "failures": differences.size(),
		"actions": actions, "semantic_steps": ticks, "differences": differences, "incomplete_barrier": incomplete_barrier,
		"replay_admitted": replay_admitted, "session_identity": {"recorded": recorded_session, "replay": replay_session,
			"scope": "Fresh-registry session alias only; no body, generation, pose or material-witness remapping"},
		"limits": "Checks named operation outcomes and completed semantic tick order on the actual exclusive-worker host. Does not compare checkpoint inventory or pose equivalence, or reproduce OS scheduling, receipt arrival timing, incomplete physics barriers, inherited registry history, uncertain mutation outcomes, or cross-platform pose bit identity."}
	if not output_path.is_empty():
		var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
		if output == null:
			differences.append({"reason": "ReportWriteFailed"})
			report.failures = differences.size()
		else:
			output.store_string(JSON.stringify(report, "  ") + "\n")
			output.close()
	print(JSON.stringify(report))
	quit(0 if differences.is_empty() else 1)
