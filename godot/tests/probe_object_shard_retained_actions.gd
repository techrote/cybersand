extends SceneTree

# Executes only actions actually retained by an owner export. Missing actions,
# process history, wall-clock pacing and backend solver history are not inferred.
# This is an owner-inspired diagnostic reproduction, never a complete replay.
const Session = preload("res://scripts/object_shard_lab_session.gd")
var input_path: String = ""
var output_path: String = "user://objectshard-retained-actions.json"
var end_tick: int = 3600
var trace: FileAccess
var session: CyberObjectShardLabSession
var expected_actions: int = 0
var expected_owners: int = 0
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--input="):
			input_path = argument.trim_prefix("--input=")
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--end-tick="):
			end_tick = int(argument.trim_prefix("--end-tick="))
	var input := FileAccess.open(input_path, FileAccess.READ)
	if input == null:
		push_error("An original owner report is required")
		quit(2)
		return
	var original: Variant = JSON.parse_string(input.get_as_text())
	if not original is Dictionary:
		quit(2)
		return
	trace = FileAccess.open(output_path + ".jsonl", FileAccess.WRITE)
	if trace == null:
		quit(2)
		return
	var pattern := RegEx.new()
	pattern.compile("^\\((-?[0-9]+), (-?[0-9]+)\\)$")
	var actions: Array[Dictionary] = []
	for event: Dictionary in original.get("events", []):
		if str(event.get("kind", "")) == "OrdinaryEdit":
			var position: RegExMatch = pattern.search(str(event.detail.position))
			if position != null:
				actions.append({"tick": int(event.tick), "position": Vector2i(int(position.get_string(1)), int(position.get_string(2))),
					"material": int(event.detail.material), "historical_result": event.detail.result})
	expected_actions = int(original.get("expected_retained_actions", actions.size()))
	expected_owners = int(original.get("expected_moving_owners", 3))
	_write({"schema": "objectshard-retained-action-probe-v1", "engine": Engine.get_version_info(),
		"input_sha256": FileAccess.get_sha256(input_path), "input_session": original.session,
		"retained_actions": actions.size(), "limitation": "Only retained OrdinaryEdit actions; not a complete deterministic replay."})
	session = Session.new()
	var opened: Dictionary = session.open(int(original.scenario), int(original.seed))
	if not opened.get("ok", false):
		_finish({"opened": opened})
		return
	var action_index: int = 0
	var geometry: Dictionary = {}
	var first_sleep: Dictionary = {}
	var final: Dictionary = {}
	while int(session.frame.tick) < end_tick and not session.failed:
		while action_index < actions.size() and int(actions[action_index].tick) <= int(session.frame.tick):
			var action: Dictionary = actions[action_index]
			# Historical OrdinaryEdit was World-only. Do not reinterpret these old
			# inputs as the new ownership-aware moving-shard editing capability.
			var edited: Dictionary = session.native.edit_cell(action.position, int(action.material), 0, 0, 200)
			session._refresh()
			_write({"tick": session.frame.tick, "action_index": action_index, "action": action, "result": edited})
			action_index += 1
		var before: Array = _poses()
		final = session.advance(true)
		var changed: Array = []
		for row: Dictionary in session.frame.get("shards", []):
			if int(geometry.get(int(row.id), 0)) != int(row.geometry_revision):
				changed.append(row)
				geometry[int(row.id)] = int(row.geometry_revision)
		var after: Array = _poses()
		for pose: Dictionary in after:
			if bool(pose.sleeping) and not first_sleep.has(int(pose.id)):
				first_sleep[int(pose.id)] = int(session.frame.tick)
		_write({"tick": session.frame.tick, "result": final, "before": before, "after": after,
			"geometry_publications": changed, "geometry_install_usec": session.bridge.timings.geometry_install_usec,
			"native_quarantined": session.frame.get("quarantined", false), "native_paused": session.frame.get("paused", false)})
		if int(session.frame.tick) % 120 == 0:
			await process_frame
	_expect(action_index == expected_actions and expected_actions > 0, "all declared retained actions executed")
	_expect(int(session.frame.tick) == end_tick, "long-duration semantic endpoint reached")
	_expect(not session.failed, "native and physics clocks remain healthy")
	_expect(session.bridge.bodies.size() == expected_owners, "expected independent physical owners retained")
	for row: Dictionary in session.frame.get("shards", []):
		if row.get("owns_inventory", false):
			_expect(int(row.structural) > 0, "native structural inventory remains authoritative")
			_expect(int(row.geometry_revision) == int(row.applied_physics_revision), "exact geometry revision applied")
			_expect(not bool(row.geometry_pending), "no sustained geometry backlog")
			if session.bridge.bodies.has(int(row.id)):
				var rid: RID = session.bridge.bodies[int(row.id)].rid
				_expect(bool(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING)), "body naturally resting at long endpoint")
	_expect(int(session.frame.metrics.get("products_created", 0)) > 0, "native chemistry produced authentic material")
	_finish({"last_result": final, "applied_retained_actions": action_index, "first_sleep_tick": first_sleep,
		"diagnostics": session.bridge.diagnostics() if session.bridge.has_method("diagnostics") else {}})


func _poses() -> Array:
	var result: Array = []
	for id: int in session.bridge.bodies:
		var body: Dictionary = session.bridge.bodies[id]
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var velocity: Vector2 = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		var com: Vector2 = PhysicsServer2D.body_get_param(body.rid, PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
		result.append({"id": id, "x": pose.origin.x, "y": pose.origin.y, "rotation": pose.get_rotation(),
			"continuous_rotation": body.rotation, "vx": velocity.x, "vy": velocity.y,
			"angular_velocity": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY),
			"sleeping": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING),
			"geometry_revision": body.geometry_revision, "geometry_digest": body.geometry_digest,
			"mass": PhysicsServer2D.body_get_param(body.rid, PhysicsServer2D.BODY_PARAM_MASS),
			"com": [com.x, com.y], "inertia": PhysicsServer2D.body_get_param(body.rid, PhysicsServer2D.BODY_PARAM_INERTIA)})
	return result


func _write(value: Dictionary) -> void:
	trace.store_line(JSON.stringify(value))


func _finish(details: Dictionary) -> void:
	var result: Dictionary = session.export_result()
	result["probe"] = details
	result["probe"]["limitation"] = "Only retained OrdinaryEdit actions; not a complete deterministic replay."
	result["probe"]["input_sha256"] = FileAccess.get_sha256(input_path)
	result["probe"]["checks"] = checks
	result["probe"]["failures"] = failures
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "  ") + "\n")
	output.close()
	trace.close()
	print(JSON.stringify({"schema": "objectshard-retained-action-probe-v1", "output": output_path,
		"tick": session.frame.tick, "failed": session.failed, "checks": checks,
		"failures": failures + int(session.failed), "status": session.status, "owners": session.frame.shards.size()}))
	var failed: bool = session.failed or failures > 0
	session.close()
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
