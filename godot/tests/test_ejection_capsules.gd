extends SceneTree

# Opt-in Stage-A apparatus. Real Rapier supplies contacts once; replay consumes
# immutable copied values and never steps Rapier or a cellular simulation.
const WATCHDOG = preload("res://tests/helpers/physical_internal_watchdog.gd")
const FAILED_CAP: int = 64
const SUCCESS_CAP: int = 16
const FIXTURE_TICKS: int = 600
var _failed: bool = false
var _mutation_failures: int = 0
var _refusal_controls: int = 0
var _watchdog: RefCounted


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("EJECTION_CAPSULE: " + message)


func _check_immutable(condition: bool, message: String) -> void:
	if not condition:
		_mutation_failures += 1
	_check(condition, message)


func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return ""


func _new_world() -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	_check(world != null, "native World unavailable")
	if world != null:
		_check(world.diagnostic_reset({"workers": 1}), "native reset refused")
	return world


func _capture(world: Object) -> Dictionary:
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
	_check(world.diagnostic_ejection_capture(FAILED_CAP, SUCCESS_CAP), "capture enable")
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
		world.prepare_rigid_body_coupling(bridge.pack_body_states(), true)
		raw_unresolved += int(world.get_rigid_body_unresolved_last_tick())
		raw_displaced += int(world.get_rigid_body_displaced_last_tick())
		if not world.simulation_tick():
			_check(false, "native tick failed at %d: %s" % [tick, world.get_last_tick_error()])
			break
		bridge.apply_cellular_results(tick + 1, world.rigid_body_results())
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
	return corpus


func _load_fallback(fallback: CyberCellWorld, capsule: Dictionary) -> void:
	fallback.cells.fill(CyberCellWorld.EMPTY)
	fallback.rigid_body_occupancy.fill(0)
	var bounds: Array = capsule.bounds
	var copied: Array = capsule.cells
	for index: int in range(copied.size()):
		var x: int = int(bounds[0]) + index % int(bounds[2])
		var y: int = int(bounds[1]) + floori(float(index) / float(bounds[2]))
		if not fallback.in_bounds(x, y):
			continue
		var at: int = fallback.cell_index(x, y)
		fallback.cells[at] = int(copied[index][0])
		fallback.rigid_body_occupancy[at] = int(copied[index][4])


func _fallback_trace(fallback: CyberCellWorld, capsule: Dictionary) -> Dictionary:
	# Independent reason census instruments the *same ordered candidates*;
	# actual fallback target below is the differential oracle for this trace.
	var source := Vector2i(int(capsule.source[0]), int(capsule.source[1]))
	var normal := Vector2(float(capsule.normal[0]), float(capsule.normal[1]))
	var tangent := Vector2(-normal.y, normal.x)
	var first: int = maxi(1, ceili(float(capsule.penetration)))
	var trace: Array = []
	var target: Array = [-1, -1]
	for distance: int in range(first, first + 9):
		for probe: int in range(9):
			var point: Vector2 = Vector2(source) + Vector2(0.5, 0.5) + normal * distance + tangent * fallback._symmetric_probe_offset(probe)
			var x: int = floori(point.x)
			var y: int = floori(point.y)
			var reason: String = "accepted"
			if not fallback.in_bounds(x, y):
				reason = "bounds"
			else:
				var at: int = fallback.cell_index(x, y)
				var obstacle: int = fallback.rigid_body_occupancy[at]
				if obstacle != 0:
					reason = "source_body" if obstacle == int(capsule.body_id) else "foreign_body"
				elif fallback.cells[at] != CyberCellWorld.EMPTY:
					reason = "non_empty"
				else:
					reason = _fallback_path_reason(fallback, source, Vector2i(x, y), int(capsule.body_id))
			trace.append([x, y, reason])
			if reason == "accepted":
				target = [x, y]
				return {"target": target, "trace": trace}
	return {"target": target, "trace": trace}


func _fallback_path_reason(fallback: CyberCellWorld, source: Vector2i, target: Vector2i,
		body_id: int) -> String:
	var delta: Vector2i = target - source
	var samples: int = maxi(absi(delta.x), absi(delta.y)) * 2
	for sample: int in range(1, samples):
		var x: int = source.x + floori(float(delta.x * sample) / float(samples) + 0.5)
		var y: int = source.y + floori(float(delta.y * sample) / float(samples) + 0.5)
		if not fallback.in_bounds(x, y):
			return "path_bounds"
		var at: int = fallback.cell_index(x, y)
		var obstacle: int = fallback.rigid_body_occupancy[at]
		if obstacle != 0 and obstacle != body_id:
			return "path_foreign"
		if fallback._is_hard_surface_material(fallback.cells[at]):
			return "path_hard"
	return "accepted"


func _refused(world: Object, capsule: Dictionary, label: String) -> void:
	var before: String = world.get_physical_state_hash()
	var revision_before: int = world.get_revision()
	var input_before: PackedByteArray = var_to_bytes(capsule)
	var result: Dictionary = world.diagnostic_replay_ejection(capsule)
	_check(not bool(result.get("valid", false)), "malformed capsule accepted: " + label)
	_check_immutable(var_to_bytes(capsule) == input_before, "malformed replay mutated its input: " + label)
	_check_immutable(world.get_physical_state_hash() == before and world.get_revision() == revision_before,
		"malformed replay mutated World: " + label)
	_refusal_controls += 1


func _controls(world: Object, corpus: Dictionary) -> void:
	var capsules: Array = corpus.get("capsules", [])
	if capsules.is_empty():
		return
	var original: Dictionary = capsules[0]
	for field: String in ["schema_version", "maximum_distance", "tangent_probes", "first_distance"]:
		var malformed: Dictionary = original.duplicate(true)
		malformed[field] = float(original[field]) + 0.5
		_refused(world, malformed, "fractional " + field)
		malformed = original.duplicate(true)
		malformed[field] = NAN
		_refused(world, malformed, "NaN " + field)
	var malformed: Dictionary = original.duplicate(true)
	malformed.penetration = INF
	_refused(world, malformed, "infinite penetration")
	malformed = original.duplicate(true)
	malformed.normal = [INF, 0.0]
	_refused(world, malformed, "infinite normal")
	malformed = original.duplicate(true)
	malformed.world_bounds = [0, 0, 1024, NAN]
	_refused(world, malformed, "nonfinite world bounds")
	malformed = original.duplicate(true)
	malformed.cells.resize(malformed.cells.size() - 1)
	_refused(world, malformed, "truncated cells")
	malformed = original.duplicate(true)
	malformed.cells[0][8] = "garbage"
	_refused(world, malformed, "malformed tuple bits")
	malformed = original.duplicate(true)
	malformed.cells[0][8] = "ffffffffffffffff"
	_refused(world, malformed, "inconsistent tuple bits")
	malformed = original.duplicate(true)
	malformed.replay_hash = "0".repeat(64)
	_refused(world, malformed, "changed search hash")
	var returned: Dictionary = world.diagnostic_ejection_corpus()
	if not returned.get("capsules", []).is_empty():
		var retained_before: String = JSON.stringify(returned, "", false, true)
		returned.capsules[0].cells[0][0] = -123
		returned.capsules[0].trace.clear()
		_check_immutable(JSON.stringify(world.diagnostic_ejection_corpus(), "", false, true) == retained_before,
			"caller mutated retained corpus through returned arrays")
	_check(world.diagnostic_reset({"workers": 1}), "reset control refused")
	var after_reset: Dictionary = world.diagnostic_ejection_corpus()
	_check(after_reset.get("capsules", []).is_empty() and int(after_reset.get("attempts", -1)) == 0,
		"reset retained stale capsule or attempt identities")
	# Offline replay deliberately accepts a retained old owner/incarnation. The
	# operation cannot install that data into the replacement simulation World.
	var old_replay: Dictionary = world.diagnostic_replay_ejection(original)
	_check(bool(old_replay.get("valid", false)), "offline replay rejected historical incarnation")


func _same_target(left: Array, right: Array) -> bool:
	# JSON parses integral coordinates as floats. Variant Array equality checks
	# element types; decision equality compares the exact coordinate values.
	if left.size() != 2 or right.size() != 2:
		return false
	for axis: int in range(2):
		if not (left[axis] is int or left[axis] is float) or not (right[axis] is int or right[axis] is float):
			return false
		var a: float = float(left[axis])
		var b: float = float(right[axis])
		if not is_finite(a) or not is_finite(b) or a != floorf(a) or b != floorf(b) or a != b:
			return false
	return true


func _same_trace(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if not left[index] is Array or not right[index] is Array:
			return false
		var a: Array = left[index]
		var b: Array = right[index]
		if a.size() != 3 or b.size() != 3 or not a[2] is String or not b[2] is String:
			return false
		if not _same_target([a[0], a[1]], [b[0], b[1]]) or a[2] != b[2]:
			return false
	return true


func _replay(world: Object, corpus: Dictionary) -> Dictionary:
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
		_check(not identities.has(str(capsule.replay_hash)), "duplicate replay state retained")
		identities[str(capsule.replay_hash)] = true
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
	_check(_watchdog.start("ejection-capsules", 120000) == OK, "watchdog start")
	var world: Object = _new_world()
	if world == null:
		_watchdog.stop()
		quit(1)
		return
	var corpus: Dictionary
	var input_path: String = _argument("--capsule-input=")
	if input_path.is_empty():
		corpus = await _capture(world)
	else:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(input_path))
		_check(parsed is Dictionary, "invalid corpus JSON")
		corpus = parsed if parsed is Dictionary else {}
	_controls(world, corpus)
	var report: Dictionary = _replay(world, corpus)
	corpus["stage_a"] = report
	corpus["source_revision"] = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	corpus["engine_version"] = Engine.get_version_info().string
	var output_path: String = _argument("--capsule-output=")
	if not output_path.is_empty():
		var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
		_check(file != null, "could not create corpus output")
		if file != null:
			file.store_string(JSON.stringify(corpus, "", false, true) + "\n")
	print("EJECTION_CAPSULE_RESULT ", JSON.stringify(report))
	_check(_watchdog.stop(), "watchdog stop")
	quit(1 if _failed else 0)
