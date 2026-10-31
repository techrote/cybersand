extends "res://tests/test_ejection_capsules.gd"

# A2 reuses the same real fixture, original search helpers and replay oracle.
# The ONLY acquisition differences are diagnostic stream retention and reads.
var _stream_mode: bool = true
var _event_file: FileAccess
var _event_count: int = 0
var _highwater: int = 0
var _trace_rows: Array = []


func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "cannot write artifact: " + path)
	if file != null:
		file.store_string(JSON.stringify(value, "", false, true) + "\n")


func _stream_controls() -> void:
	var world: Object = _new_world()
	_check(world.diagnostic_ejection_stream(), "stream enable")
	_check(world.diagnostic_fill_rect(Vector2i(100,100),Vector2i(32,32),CyberCellWorld.SAND), "stream control fill")
	world.prepare_rigid_body_coupling(PackedFloat32Array([1,116,116,0,32,32,0,0,0,1,1]), true)
	var physical: String = world.get_physical_state_hash()
	var batch: Dictionary = world.diagnostic_take_ejection_events()
	_check(int(batch.get("stream_total_limit",-1)) == 8192 and batch.has("capture_instance_id"), "A2 stream runtime version mismatch")
	_check(batch.capsules.size() == 256, "stream overflow did not retain bounded256")
	_check(int(batch.dropped_capacity) > 0, "stream overflow not explicit")
	_check(int(batch.attempts) == int(batch.stream_emitted) + int(batch.dropped), "stream accounting")
	batch.capsules[0].cells[0][0] = -123
	_check_immutable(world.get_physical_state_hash() == physical, "drained values alias World")
	_check(world.diagnostic_take_ejection_events().capsules.is_empty(), "drain retained pending values")
	_check(world.diagnostic_reset({"workers":1}), "stream reset")
	var empty: Dictionary = world.diagnostic_ejection_corpus()
	_check(not empty.stream_mode and empty.capsules.is_empty() and int(empty.attempts) == 0, "reset retained stream incarnation")
	_check(world.diagnostic_ejection_stream(), "stream reenable")
	_check(world.diagnostic_ejection_capture(64,16), "legacy enable")
	_check(not world.diagnostic_ejection_corpus().stream_mode, "legacy policy changed by prior stream")


func _capture_a2(world: Object) -> Dictionary:
	# Reduced existing REM-002 P4 four-height barrel/flat-Sand fixture. The
	# unmodified manual bridge, body8x14 and all default coupling gains are used.
	# Walls/floor are ordinary hard terrain; no forced poses or target voids.
	var left: int = 96
	var surface: int = 160
	var width: int = 32
	var depth: int = 48
	var initial_rotation: float = 0.08
	var initial_angular_velocity: float = 1.0
	var floor_y: int = surface + depth
	world.set_simulation_window(Vector2i(left - 4, 0), Vector2i(width + 8, floor_y + 4), 0, 0)
	for rectangle: Array in [
		[left - 1, 0, 1, floor_y + 1], [left + width, 0, 1, floor_y + 1],
		[left - 1, floor_y, width + 2, 1], [left - 1, 0, width + 2, 1],
	]:
		_check(world.diagnostic_fill_rect(Vector2i(rectangle[0], rectangle[1]),
			Vector2i(rectangle[2], rectangle[3]), CyberCellWorld.WALL), "hard fixture fill")
	_check(world.diagnostic_fill_rect(Vector2i(left, surface), Vector2i(width, depth),
		CyberCellWorld.SAND), "Sand bed fill")
	_check(world.diagnostic_ejection_stream() if _stream_mode else world.diagnostic_ejection_capture(FAILED_CAP, SUCCESS_CAP), "capture enable")
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(128, 128)
	root.add_child(viewport)
	var body := RigidBody2D.new()
	body.mass = 1.0
	body.gravity_scale = 0.094
	body.linear_damp = 0.15
	body.angular_damp = 0.35
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var body_size := Vector2(8, 14)
	var initial := Vector2(left + width / 2.0, surface - body_size.y / 2.0 - 4.0 * body_size.y)
	body.position = initial
	body.rotation = initial_rotation
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	collision.shape = shape
	body.add_child(collision)
	viewport.add_child(body)
	await process_frame
	var bridge := CyberRapierPhysicsBridge.new()
	var bodies: Array[RigidBody2D] = [body]
	var initialized: Error = bridge.initialize(viewport.world_2d.space, bodies,
		PackedVector2Array([body_size]))
	_check(initialized == OK, "real Rapier bridge initialize")
	if initialized != OK:
		viewport.queue_free()
		await process_frame
		return {}
	bridge.enable_diagnostics()
	bridge.reset_body(0, initial, initial_rotation)
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,
		initial_angular_velocity)
	bridge.refresh_all_states()
	bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
	var raw_unresolved: int = 0
	var raw_displaced: int = 0
	var completed: int = 0
	for tick: int in range(FIXTURE_TICKS):
		_watchdog.publish("capture tick=%d" % tick)
		bridge.step()
		var input: PackedFloat32Array = bridge.pack_body_states()
		world.prepare_rigid_body_coupling(input, true)
		var before_metrics: Array = world.diagnostic_body_metrics()
		var before_results: Array = Array(world.rigid_body_results())
		var event_count: int = 0
		if _stream_mode:
			var batch: Dictionary = world.diagnostic_take_ejection_events()
			event_count = batch.capsules.size()
			_highwater = maxi(_highwater, event_count)
			_check(event_count <= 256, "native stream exceeded pending bound")
			for capsule: Dictionary in batch.capsules:
				if _event_count < 8192:
					_event_file.store_line(JSON.stringify(capsule, "", false, true))
				else:
					_check(false, "total acquisition budget exceeded8192 events")
				_event_count += 1
		raw_unresolved += int(world.get_rigid_body_unresolved_last_tick())
		raw_displaced += int(world.get_rigid_body_displaced_last_tick())
		if not world.simulation_tick():
			_check(false, "native tick failed at %d: %s" % [tick, world.get_last_tick_error()])
			break
		var result: PackedFloat32Array = world.rigid_body_results()
		var after_metrics: Array = world.diagnostic_body_metrics()
		bridge.apply_cellular_results(tick + 1, result)
		_trace_rows.append({"tick":tick,"body_input":Array(input),
			"pre_tick_metrics":before_metrics,"pre_tick_results":before_results,
			"post_tick_metrics":after_metrics,"requested_results":Array(result),
			"bridge_application":Array(bridge.diagnostic_applications),
			"live_velocity_after_application":Array([PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY).x,
				PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY).y]),
			"physical_hash":world.get_physical_state_hash(),"events":event_count})
		completed += 1
		# Yield only for main-thread health; data identity does not use frame time.
		if tick % 60 == 59:
			await process_frame
	var corpus: Dictionary = world.diagnostic_ejection_corpus()
	corpus["fixture"] = {"name": "rem002-reduced-p4-four-height", "left": left,
		"surface": surface, "width": width, "depth": depth, "body_size": [8, 14],
		"drop_heights": 4, "initial_rotation": initial_rotation,
		"initial_angular_velocity": initial_angular_velocity, "mass": 1, "ticks": completed, "workers": 1,
		"raw_unresolved": raw_unresolved, "raw_displaced": raw_displaced,
		"real_rapier": true, "capture_failed_cap": FAILED_CAP, "capture_success_cap": SUCCESS_CAP}
	bridge.shutdown()
	viewport.queue_free()
	await process_frame
	corpus["complete"] = not _failed and completed == FIXTURE_TICKS and (not _stream_mode or _event_count == int(corpus.attempts))
	corpus["maximum_pending_seen"] = _highwater
	corpus["events_written"] = _event_count
	corpus["final_physical_hash"] = world.get_physical_state_hash()
	return corpus


func _replay_a2(world: Object, corpus: Dictionary) -> Dictionary:
	var capsules: Array = corpus.get("capsules", [])
	var fallback := CyberCellWorld.new()
	var failed_count: int = 0
	var successful_count: int = 0
	var replay_count: int = 0
	var matched_count: int = 0
	var reasons: Dictionary = {}
	var identities: Dictionary = {}
	var before: String = world.get_physical_state_hash()
	var revision_before: int = world.get_revision()
	for capsule: Dictionary in capsules:
		_watchdog.publish("replay capsule=%d" % replay_count)
		var serialized: String = JSON.stringify(capsule, "", false, true)
		# Parsing the retained representation is part of qualification; replaying
		# only the original in-memory doubles would miss lossy serialization.
		var copied: Dictionary = JSON.parse_string(serialized)
		var copied_before: String = JSON.stringify(copied, "", false, true)
		var replay: Dictionary = world.diagnostic_replay_ejection(copied)
		_check(bool(replay.get("valid", false)), "native replay invalid: " + str(replay))
		var native_target_matches: bool = _same_target(replay.get("target", []), capsule.target)
		var native_trace_matches: bool = _same_trace(replay.get("trace", []), capsule.trace)
		_check(native_target_matches, "native target mismatch")
		_check(native_trace_matches, "native candidate/reason mismatch")
		_check(str(replay.get("replay_hash", "")) == str(capsule.replay_hash), "serialized state hash mismatch")
		_check_immutable(JSON.stringify(copied, "", false, true) == copied_before, "native replay mutated its input capsule")
		_check_immutable(JSON.stringify(capsule, "", false, true) == serialized, "replay mutated capsule")
		_load_fallback(fallback, copied)
		var cells_before: PackedByteArray = fallback.cells.duplicate()
		var mask_before: PackedByteArray = fallback.rigid_body_occupancy.duplicate()
		var actual: Vector2i = fallback._find_body_ejection_target(int(copied.source[0]),
			int(copied.source[1]), int(copied.body_id),
			Vector2(float(copied.normal[0]), float(copied.normal[1])), float(copied.penetration))
		var differential: Dictionary = _fallback_trace(fallback, copied)
		var fallback_actual_matches: bool = _same_target([actual.x, actual.y], differential.target)
		var fallback_target_matches: bool = _same_target(differential.target, capsule.target)
		var fallback_trace_matches: bool = _same_trace(differential.trace, capsule.trace)
		_check(fallback_actual_matches, "fallback actual/trace target mismatch")
		_check(fallback_target_matches, "native/fallback target mismatch")
		_check(fallback_trace_matches, "native/fallback candidate/reason mismatch")
		if bool(replay.get("valid", false)) and native_target_matches and native_trace_matches \
				and str(replay.get("replay_hash", "")) == str(capsule.replay_hash) \
				and fallback_actual_matches and fallback_target_matches and fallback_trace_matches:
			matched_count += 1
		_check_immutable(fallback.cells == cells_before and fallback.rigid_body_occupancy == mask_before,
			"fallback replay mutated cellular state")
		_check(not identities.has(str(capsule.topology_hash)), "duplicate replay state retained")
		identities[str(capsule.topology_hash)] = true
		if int(capsule.target[0]) < 0:
			failed_count += 1
		else:
			successful_count += 1
		for candidate: Array in capsule.trace:
			var reason: String = str(candidate[2])
			reasons[reason] = int(reasons.get(reason, 0)) + 1
		replay_count += 1
	_check_immutable(world.get_physical_state_hash() == before and world.get_revision() == revision_before,
		"diagnostic replay mutated live World")
	_check(failed_count >= 32, "fewer than32 unique naturally unresolved contacts")
	_check(successful_count >= 8, "fewer than8 natural positive controls")
	return {"ok": not _failed, "capsules": replay_count, "failed_unique": failed_count,
		"success_unique": successful_count, "candidate_reasons": reasons,
		"native_fallback_target_trace_matches": matched_count, "mutation_failures": _mutation_failures,
		"malformed_refusal_controls": _refusal_controls,
		"serialization": "Godot JSON full_precision=true, parsed before replay"}


func _run() -> void:
	_watchdog = WATCHDOG.new()
	_check(_watchdog.start("ejection-a2", 120000) == OK, "watchdog start")
	var mode: String = _argument("--mode=")
	var world: Object = _new_world()
	if mode == "replay":
		var corpus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_argument("--capsule-input=")))
		var report: Dictionary = _replay_a2(world, corpus)
		_controls(world, corpus)
		report["malformed_refusal_controls"] = _refusal_controls
		report["mutation_failures"] = _mutation_failures
		report["ok"] = not _failed
		_write(_argument("--replay-report="), report)
		print("A2_REPLAY_RESULT ", JSON.stringify(report))
	else:
		_stream_controls()
		_stream_mode = mode != "legacy"
		if _stream_mode:
			_event_file = FileAccess.open(_argument("--events="), FileAccess.WRITE)
			_check(_event_file != null, "stream output unavailable")
		var captured: Dictionary = await _capture_a2(world)
		if _event_file != null:
			_event_file.close()
		var legacy_capsules: Array = captured.capsules
		captured.erase("capsules")
		var acquisition: Dictionary = {"complete":captured.complete,"native_counters":captured,
			"fixture":captured.fixture,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
			"mode":mode,"stream_controls":true,"legacy_hashes":[],"legacy_capsules":legacy_capsules}
		for capsule: Dictionary in legacy_capsules:
			acquisition.legacy_hashes.append(capsule.replay_hash)
		_write(_argument("--acquisition="), acquisition)
		_write(_argument("--trace="), {"frames":_trace_rows})
		print("A2_CAPTURE_RESULT ", JSON.stringify({"ok":not _failed,"attempts":captured.attempts,
			"no_target":captured.searched_no_target,"targets":captured.target_found,
			"dropped":captured.dropped,"events":_event_count,"maximum_pending":_highwater}))
	_check(_watchdog.stop(), "watchdog stop")
	quit(1 if _failed else 0)
