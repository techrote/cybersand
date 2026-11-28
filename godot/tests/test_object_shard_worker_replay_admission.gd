extends SceneTree

const Host = preload("res://scripts/object_shard_worker_host.gd")
const Capture = preload("res://scripts/object_shard_capture.gd")
const Replay = preload("res://tests/replay_object_shard_worker_trace.gd")
var host
var checks: int = 0
var failures: int = 0
var destination: String = "user://ObjectShardReplayAdmission"
var evidence: Dictionary = {}


func _init() -> void:
	Engine.max_fps = 240
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			destination = argument.trim_prefix("--output-dir=")
	destination = ProjectSettings.globalize_path(destination)
	DirAccess.make_dir_recursive_absolute(destination)
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _idle() -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		host.poll()
		if host.state == "Idle" and host.pending.is_empty() and host.actions.is_empty() and not host._tick_requested:
			return not host.failed
		await process_frame
	return false


func _close() -> bool:
	host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.state != "Closed" and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	return host.state == "Closed"


func _trace(rows: Array[Dictionary]) -> Dictionary:
	return {"header": {"session": 7, "standalone_replay": true, "replay_identity_scope": "fresh-native-registry"}, "rows": rows}


func _row(kind: String, detail: Dictionary) -> Dictionary:
	return {"kind": kind, "detail": detail, "tick": 1, "sequence": 1}


func _run_cli(path: String, name: String, expected_exit: int, expected_reason: String = "") -> Dictionary:
	var output: Array = []
	var report_path: String = destination.path_join(name + "-replay.json")
	var result: int = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/replay_object_shard_worker_trace.gd", "--", "--objectshard-replay=" + path,
		"--objectshard-replay-report=" + report_path]), output, true)
	var log: FileAccess = FileAccess.open(destination.path_join(name + "-replay.log"), FileAccess.WRITE)
	if log != null:
		for line: String in output:
			log.store_string(line)
		log.close()
	_expect(result == expected_exit, "Actual fresh-process replayer returns the required disposition: " + name)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	_expect(parsed is Dictionary and parsed.get("schema") == "objectshard-worker-action-replay-v1", "Actual replay emits its structured source-bound receipt")
	if not parsed is Dictionary:
		return {}
	if expected_exit != 0:
		_expect(not parsed.get("replay_admitted", true) and int(parsed.get("actions", -1)) == 0 and int(parsed.get("semantic_steps", -1)) == 0,
			"Nonreplayable observation is refused before creating or mutating a replacement World")
		_expect(parsed.get("differences", []).size() == 1 and str(parsed.differences[0].reason) == expected_reason,
			"Replay refuses for the specific retained evidence reason")
	else:
		_expect(int(parsed.get("failures", -1)) == 0 and int(parsed.get("actions", 0)) >= 19 and int(parsed.get("semantic_steps", 0)) >= 2,
			"Fresh native registry replay executes actual World edits, stale/fresh moving cuts and real intervals")
	return parsed


func _run() -> void:
	_expect(Replay.admission_issue(_trace([_row("footer", {"complete_prefix": true})])).is_empty(), "Explicit complete fresh registry prefix is admissible")
	_expect(Replay.admission_issue(_trace([_row("footer", {"complete_prefix": false})])).get("reason") == "IncompleteTracePrefix", "An explicitly incomplete footer is not a successful empty replay")
	_expect(Replay.admission_issue(_trace([_row("footer", {"complete_prefix": 1})])).get("reason") == "IncompleteTracePrefix", "Completion requires an actual boolean, not a truthy scalar")
	_expect(Replay.admission_issue(_trace([_row("checkpoint", {"pending": 1})])).get("reason") == "UnresolvedNativeOperationRequiresAdversarialSchedule", "Malformed pending-operation evidence refuses without a script error")
	_expect(Replay.admission_issue(_trace([_row("checkpoint", {"capture": {"complete_prefix": false}})])).get("reason") == "IncompleteTracePrefix", "An incomplete exported checkpoint remains an observation")
	_expect(Replay.admission_issue(_trace([_row("checkpoint", {"pending": {"operation": "edit"}})])).get("reason") == "UnresolvedNativeOperationRequiresAdversarialSchedule", "An in-flight edit at export cannot be silently omitted")
	for kind: String in ["ActionRetired", "FixtureBatchRetired"]:
		_expect(Replay.admission_issue(_trace([_row("event", {"kind": kind, "detail": {"may_have_executed": true}})])).get("reason") == "UnknownMutationOutcomeRequiresAdversarialSchedule", "Unknown retired mutation refuses even without an incomplete footer: " + kind)
	_expect(Replay.admission_issue(_trace([_row("event", {"kind": "ActionRetired", "detail": {"may_have_executed": false, "outcome": "CancelledByReset"}}), _row("footer", {"complete_prefix": true})])).is_empty(), "A known unexecuted cancellation remains explicit nonmutation evidence")
	_expect(Replay.admission_issue(_trace([_row("failure", {})])).get("reason") == "RecordedWorkerFailureRequiresAdversarialSchedule", "Worker failure cannot manufacture a successful replay")
	_expect(Replay.admission_issue(_trace([_row("step_requested", {}), _row("footer", {"complete_prefix": true})])).get("incomplete_barrier", false), "Incomplete physical barrier remains distinguished")
	var inherited: Dictionary = _trace([_row("footer", {"complete_prefix": true})])
	inherited.header.standalone_replay = false
	inherited.header.replay_identity_scope = "inherited-native-registry"
	_expect(Replay.admission_issue(inherited).get("reason") == "InheritedRegistryHistoryRequiresPriorSessionReplay", "Inherited allocator history requires the preceding session chain")

	# A real mutation applies, but the host does not receive its success reply.
	host = Host.new()
	_expect(host.open({"scenario": 0, "seed": 12}, 94121, destination.path_join("uncertain.jsonl")).get("ok", false) and await _idle(), "Native unknown-outcome control opens")
	var uncertain_path: String = ProjectSettings.globalize_path(host.capture.path)
	_expect(host.queue_action("edit", {"position": Vector2i(20, 20), "material": 7}).get("ok", false), "Actual Wood edit is admitted")
	host.poll()
	var receipt: Dictionary = {}
	var deadline: int = Time.get_ticks_msec() + 10000
	while receipt.is_empty() and Time.get_ticks_msec() < deadline:
		var replies: Array[Dictionary] = host.worker.take_results(1)
		if not replies.is_empty():
			receipt = replies[0]
		await process_frame
	var applied: PackedByteArray = receipt.get("frame", {}).get("world_materials", PackedByteArray())
	_expect(receipt.get("result", {}).get("ok", false) and applied.size() > 20 * 192 + 20 and int(applied[20 * 192 + 20]) == 7,
		"The withheld reply proves real native Wood was applied")
	_expect(host.reset(0, 12).get("ok", false) and await _idle(), "Explicit reset retires the unknown outcome")
	var inherited_path: String = ProjectSettings.globalize_path(host.capture.path)
	_expect(await _close(), "Unknown-outcome control disposes its worker")
	var uncertain: Dictionary = Capture.read_trace(uncertain_path, OS.get_environment("CYBERSAND_SOURCE_REVISION"))
	_expect(uncertain.get("ok", false) and Replay.admission_issue(uncertain).get("reason") == "UnknownMutationOutcomeRequiresAdversarialSchedule", "Actual native-produced retirement trace is refused as replay")
	evidence["uncertain"] = _run_cli(uncertain_path, "uncertain", 1, "UnknownMutationOutcomeRequiresAdversarialSchedule")
	evidence["inherited"] = _run_cli(inherited_path, "inherited", 1, "InheritedRegistryHistoryRequiresPriorSessionReplay")

	# The UI's reset path creates a fresh registry even though process-global
	# session identity has advanced. Moving owner/generation/pose stay exact.
	host = Host.new()
	_expect(host.open({"scenario": 0, "seed": 12}, 94123, destination.path_join("fresh.jsonl")).get("ok", false) and await _idle(), "Fresh replacement registry opens after prior sessions")
	var fresh_path: String = ProjectSettings.globalize_path(host.capture.path)
	var source_session: int = host.session
	_expect(source_session > 1 and host.capture.header.get("standalone_replay", false), "Replacement trace declares fresh registry with noninitial session identity")
	for y: int in range(20, 24):
		for x: int in range(20, 24):
			_expect(host.queue_action("edit", {"position": Vector2i(x, y), "material": 7}).get("ok", false), "Native structural authoring admitted")
	_expect(await _idle(), "All source fixture edits have actual native receipts")
	for tick: int in range(8):
		_expect(host.request_tick().get("ok", false) and await _idle(), "Real native/Rapier interval completes")
		if not host.publication.get("shards", []).is_empty():
			break
	_expect(host.publication.get("shards", []).size() == 1, "Fresh registry promotes the real sixteen-cell native owner")
	var point := Vector2i(22, 22)
	var stale: Dictionary = host.capture_target(point)
	_expect(int(stale.get("owner", 0)) > 0 and host.request_tick().get("ok", false) and await _idle(), "An exact witnessed body advances through a real later pose")
	_expect(host.queue_action("edit", {"position": point, "material": 0, "target": stale}).get("ok", false) and await _idle() and host.last_action.get("outcome") == "TargetChanged", "Recorded old-pose target explicitly refuses")
	_expect(host.queue_action("edit", {"position": point, "material": 0, "target": host.capture_target(point)}).get("ok", false) and await _idle() and host.last_action.get("ok", false), "Fresh exact moving-cell target succeeds")
	_expect(int(host.publication.shards[0].structural) == 15, "Source owner lost exactly one structural cell")
	var stale_session_target: Dictionary = host.capture_target(Vector2i(21, 22))
	stale_session_target.session = 1
	var stale_session_input: Dictionary = {"position": Vector2i(21, 22), "material": 0, "state_a": 0, "state_b": 0,
		"temperature": 200, "target": stale_session_target}
	var stale_session_result: Dictionary = host.queue_action("edit", stale_session_input)
	_expect(stale_session_result.get("outcome") == "InvalidInputTarget", "An old source session is actually refused before replay")
	# Retain the actual rejected caller operation explicitly. It must not become
	# valid merely because a fresh replay process happens to allocate session1.
	host.capture.action(int(host.frame.tick), "edit", stale_session_input, stale_session_result)
	_expect(await _close(), "Fresh replacement control disposes coherently")
	evidence["fresh"] = _run_cli(fresh_path, "fresh", 0)
	_expect(int(evidence.fresh.get("session_identity", {}).get("recorded", 0)) == source_session and int(evidence.fresh.get("session_identity", {}).get("replay", 0)) != source_session,
		"Only the recorded fresh-registry session namespace is rebound")
	print(JSON.stringify({"schema": "objectshard-worker-replay-admission-test-v1", "checks": checks, "failures": failures,
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "evidence": evidence,
		"scope": "Actual withheld native edit, explicit observation refusal, and source-matched fresh-process replay with retained stale/fresh moving witnesses"}))
	quit(0 if failures == 0 else 1)
