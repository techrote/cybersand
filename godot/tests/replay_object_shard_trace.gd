extends SceneTree

const Session = preload("res://scripts/object_shard_lab_session.gd")
const Capture = preload("res://scripts/object_shard_capture.gd")
var failures: int = 0
var differences: Array[Dictionary] = []
var actions: int = 0
var steps: int = 0


func _init() -> void:
	call_deferred("_run")


func _difference(detail: Dictionary) -> void:
	failures += 1
	if differences.size() < 128:
		differences.append(detail)


func _run() -> void:
	var path: String = ""
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--objectshard-replay="):
			path = argument.trim_prefix("--objectshard-replay=")
		if argument.begins_with("--objectshard-replay-report="):
			output = argument.trim_prefix("--objectshard-replay-report=")
	var loaded: Dictionary = Capture.read_trace(path, OS.get_environment("CYBERSAND_SOURCE_REVISION"))
	var session = Session.new()
	if not loaded.get("ok", false):
		_difference({"reason": "Trace admission", "result": loaded})
	elif loaded.header.get("host") == "standalone-exclusive-worker-rehearsal":
		_difference({"reason": "ReplayHostMismatch", "required_driver": "res://tests/replay_object_shard_worker_trace.gd"})
	else:
		var header: Dictionary = loaded.header
		var opened: Dictionary = session.open(int(header.scenario), int(header.seed), {"width": header.get("width", 192), "height": header.get("height", 128)})
		if not opened.get("ok", false):
			_difference({"reason": "Session admission", "result": opened})
		else:
			for row: Dictionary in loaded.rows:
				var kind: String = str(row.kind)
				var detail: Dictionary = row.detail
				if kind == "action":
					var actual: Dictionary = _action(session, detail)
					var expected: Dictionary = detail.get("result", {})
					actions += 1
					if bool(actual.get("ok", false)) != bool(expected.get("ok", false)) or str(actual.get("outcome", "")) != str(expected.get("outcome", "")):
						_difference({"sequence": row.sequence, "action": detail.action, "expected": expected, "actual": actual})
				elif kind == "step_requested":
					if int(row.tick) != int(session.frame.get("tick", -1)):
						_difference({"sequence": row.sequence, "reason": "Semantic tick divergence", "expected": row.tick,
							"actual": session.frame.get("tick", -1)})
						break
					session.advance(true)
					steps += 1
				elif kind == "step_completed" and session.failed:
					_difference({"sequence": row.sequence, "reason": "Unexpected held replay", "status": session.status})
					break
				elif kind == "failure" and not session.failed:
					_difference({"sequence": row.sequence, "reason": "Recorded failure did not reproduce", "recorded": detail})
				if steps % 120 == 0:
					await process_frame
	var report: Dictionary = {"schema": "objectshard-action-replay-v1", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"input": path, "actions": actions, "steps": steps, "failures": failures, "differences": differences,
		"scope": "Named operation/refusal and semantic-step reproduction. Pose bit identity and subjective playability are separate gates.",
		"final": session.export_result() if session.native != null else {}}
	if not output.is_empty():
		var stream: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if stream != null:
			stream.store_string(JSON.stringify(Capture.json_value(report), "\t") + "\n")
			stream.close()
		else:
			failures += 1
	print(JSON.stringify({"schema": report.schema, "actions": actions, "steps": steps, "failures": failures}))
	session.close()
	quit(0 if failures == 0 else 1)


func _action(session: CyberObjectShardLabSession, detail: Dictionary) -> Dictionary:
	var parameters: Dictionary = detail.get("parameters", {})
	var xy: Array = parameters.get("position", [0, 0])
	var position := Vector2i(int(xy[0]), int(xy[1]))
	match str(detail.get("action", "")):
		"edit":
			return session.edit(position, int(parameters.get("material", 0)), int(parameters.get("state_a", 0)),
				int(parameters.get("state_b", 0)), int(parameters.get("temperature", 200)))
		"erase_shard":
			# Re-resolve the new session's owner and incarnation. Never replay an
			# old transaction token against a different live registry generation.
			return session.edit(position, 0)
		"ignite":
			return session.ignite(position)
		"pause":
			session.set_paused(bool(parameters.get("paused", true)))
			return {"ok": true}
		"burner":
			var cells: Array[Vector2i] = []
			for point: Array in parameters.get("cells", []):
				if point.size() != 2:
					return {"ok": false, "outcome": "MalformedBurner"}
				cells.append(Vector2i(int(point[0]), int(point[1])))
			return session.set_burner(cells, bool(parameters.get("enabled", false)))
	return {"ok": false, "outcome": "UnsupportedReplayAction"}
