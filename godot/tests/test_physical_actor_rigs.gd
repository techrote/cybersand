extends SceneTree

# Real Rapier articulation regression. This fixture owns one fresh space/rig at
# a time; it does not call native material effects or claim target-PC feel.
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Scripted = preload("res://scripts/physical_actor_script.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const Progress = preload("res://tests/helpers/physical_progress.gd")
const DT: float = 1.0 / 60.0

var _failures: int = 0
var _owner: Node2D
var _rig
var _bridge
var _terrain: Array[StaticBody2D] = []
var _results: Array[Dictionary] = []
var _roster_ticks: int = 1200
var _selected_rig: StringName = &""


func _init() -> void:
	if not Progress.begin("test_physical_actor_rigs"):
		quit(1)
		return
	Progress.mark("initialize")
	call_deferred("_run")


func _run() -> void:
	Progress.mark("run")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rig="):
			_selected_rig = StringName(argument.trim_prefix("--rig="))
		if argument.begins_with("--ticks="):
			_roster_ticks = clampi(int(argument.trim_prefix("--ticks=")), 360, 3600)
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=setup")
	_owner = Node2D.new()
	root.add_child(_owner)
	_expect(ClassDB.class_exists("RapierPhysicsServer2D"), "pinned real Rapier extension unavailable")
	if _failures != 0:
		Progress.finish()
		quit(1)
		return
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=admission")
	Progress.mark("admission")
	_test_admission()
	for rig_id: StringName in Catalog.RIG_IDS:
		if _selected_rig == &"" or _selected_rig == rig_id:
			Progress.mark("scenario", str(rig_id))
			await _test_roster_rig(rig_id)
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=obstructed_patrol")
	await _test_obstructed_patrol()
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=no_air_traction")
	await _test_no_air_traction()
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=cancel_charge")
	await _test_cancel_charge()
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=mount_and_release")
	await _test_mount_and_release()
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=surface_blast")
	await _test_surface_blast()
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=support_removal")
	await _test_support_removal()
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=slide_endstops")
	await _test_slide_endstops()
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=rope_controls")
	await _test_rope_controls()
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=recovery")
	await _test_recovery()
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=owner_reuse")
	await _test_owner_reuse()
	print("ACT004_ROSTER_METRICS ", JSON.stringify(_results))
	print("ACT004 real-Rapier rig fixture: ", Catalog.RIG_IDS.size(), " catalogue rigs; failures=", _failures)
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=teardown")
	_owner.queue_free()
	Progress.mark("process_frame_wait")
	await process_frame
	Progress.mark("process_frame_resumed")
	Progress.mark("quit")
	if not Progress.finish():
		_failures += 1
	quit(1 if _failures > 0 else 0)


func _test_admission() -> void:
	var bad: Dictionary = Catalog.entry(&"runner")
	bad.parts.append(bad.parts[0].duplicate(true))
	_expect(not Rig.validate_definition(bad).is_empty(), "duplicate part identity admitted")
	bad = Catalog.entry(&"runner")
	bad.parts[0].mass = NAN
	_expect(not Rig.validate_definition(bad).is_empty(), "nonfinite part mass admitted")
	bad = Catalog.entry(&"runner")
	bad.joints.clear()
	_expect(not Rig.validate_definition(bad).is_empty(), "disconnected cosmetic assembly admitted")
	bad = Catalog.entry(&"runner")
	bad.joints[0].max_force = INF
	_expect(not Rig.validate_definition(bad).is_empty(), "unbounded joint motor admitted")
	_expect(not Rig.valid_action({"move": Vector2(NAN, 0)}), "nonfinite control admitted")
	_expect(not Rig.valid_action({"primary": "true"}), "string boolean control admitted")


func _setup(rig_id: StringName, floor_enabled: bool = true, origin: Vector2 = Vector2.INF) -> bool:
	Progress.mark("setup", str(rig_id))
	var definition: Dictionary = Catalog.entry(rig_id)
	var error: String = Rig.validate_definition(definition)
	_expect(error.is_empty(), "%s definition rejected: %s" % [rig_id, error])
	if not error.is_empty():
		return false
	if not origin.is_finite():
		origin = Vector2(100, 156.0 - float(definition.spawn_floor_clearance))
	if floor_enabled:
		_box(Vector2(132, 163), Vector2(264, 14))
		_box(Vector2(2, 95), Vector2(4, 136))
		_box(Vector2(262, 95), Vector2(4, 136))
		_box(Vector2(136, 49), Vector2(210, 4))
		_box(Vector2(159, 150), Vector2(14, 12))
	_rig = Rig.new()
	_owner.add_child(_rig)
	_expect(_rig.configure(definition, origin, 0, 1) == OK, "configure failed: " + str(rig_id))
	if not _rig.configured:
		return false
	_bridge = Bridge.new()
	_expect(_bridge.initialize(_owner.get_world_2d().space, _rig.bodies(), _rig.body_sizes()) == OK,
		"bridge initialization failed: " + str(rig_id))
	Progress.mark("setup_complete", str(rig_id))
	return _bridge.is_initialized()


func _box(position: Vector2, size: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = position
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	_owner.add_child(body)
	_terrain.append(body)
	return body


func _step(action: Dictionary) -> Dictionary:
	Progress.tick("step")
	_rig.advance(action, DT)
	_bridge.step()
	_rig.refresh_observation()
	return _rig.observation()


func _teardown() -> void:
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=bridge_shutdown")
	Progress.mark("teardown")
	if _bridge != null:
		_bridge.shutdown()
		_bridge = null
	if is_instance_valid(_rig):
		_rig.close()
		_rig.free()
		_rig = null
	for body: StaticBody2D in _terrain:
		if is_instance_valid(body):
			body.free()
	_terrain.clear()
	Progress.mark("process_frame_wait")
	await process_frame
	Progress.mark("process_frame_resumed")


func _test_roster_rig(rig_id: StringName) -> void:
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=roster_setup rig=", rig_id)
	if not _setup(rig_id):
		await _teardown()
		return
	print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=world_built rig=", rig_id)
	var pilot = Scripted.new()
	pilot.configure(rig_id, _rig.centre(), 0)
	var initial: Vector2 = _rig.centre()
	var min_x: float = initial.x
	var max_x: float = initial.x
	var max_speed: float = 0.0
	var max_omega: float = 0.0
	var max_extent: float = 0.0
	var grounded_ticks: int = 0
	var articulated_motion: float = 0.0
	var articulated_translation: float = 0.0
	var max_anchor_error: float = 0.0
	var max_limit_error: float = 0.0
	var max_slide_angle: float = 0.0
	var max_slide_error: float = 0.0
	var late_min_x: float = INF
	var late_max_x: float = -INF
	var minimum_energy: float = 1.0
	var turnarounds: int = 0
	var previous_direction: float = 1.0
	var action: Dictionary = Scripted.neutral_action()
	var before: Dictionary = _rig.observation()
	for tick: int in range(_roster_ticks):
		if tick % 300 == 0:
			print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=roster_step rig=", rig_id, " tick=", tick)
		if tick % 6 == 0:
			action = pilot.next_action(before, DT * 6.0)
			var direction: float = float(pilot.diagnostics().direction)
			if direction != previous_direction:
				turnarounds += 1
			previous_direction = direction
		var observation: Dictionary = _step(action)
		_expect(str(observation.fault).is_empty(), "%s nonfinite/fault at tick %d" % [rig_id, tick])
		if not str(observation.fault).is_empty():
			break
		var centre: Vector2 = observation.centre
		min_x = minf(min_x, centre.x)
		max_x = maxf(max_x, centre.x)
		if tick >= _roster_ticks - 300:
			late_min_x = minf(late_min_x, centre.x)
			late_max_x = maxf(late_max_x, centre.x)
		minimum_energy = minf(minimum_energy, float(observation.energy))
		max_speed = maxf(max_speed, Vector2(observation.velocity).length())
		max_omega = maxf(max_omega, absf(float(observation.angular_velocity)))
		grounded_ticks += int(bool(observation.grounded))
		for part: Dictionary in observation.parts:
			max_extent = maxf(max_extent, centre.distance_to(part.position))
		for joint: Dictionary in observation.joints:
			articulated_motion = maxf(articulated_motion, absf(float(joint.angle)))
			max_anchor_error = maxf(max_anchor_error, float(joint.anchor_error))
			if str(joint.type) == "rotary" and bool(joint.limits_enabled):
				max_limit_error = maxf(max_limit_error, maxf(float(joint.limits.x) - float(joint.angle),
					float(joint.angle) - float(joint.limits.y)))
			elif str(joint.type) != "rotary":
				articulated_translation = maxf(articulated_translation, absf(float(joint.travel)))
				max_slide_angle = maxf(max_slide_angle, absf(float(joint.angle)))
				max_slide_error = maxf(max_slide_error, maxf(float(joint.limits.x) - float(joint.travel),
					float(joint.travel) - float(joint.limits.y)))
		_expect(int(observation.ray_queries) <= Rig.MAX_RAYS, "%s ray budget exceeded" % rig_id)
		before = observation
		if _selected_rig != &"" and tick % 60 == 0:
			print("ACT004_TRACE ", JSON.stringify({"rig": str(rig_id), "tick": tick,
				"x": centre.x, "y": centre.y, "vx": observation.velocity.x, "vy": observation.velocity.y,
				"angle": observation.rotation, "omega": observation.angular_velocity,
				"energy": observation.energy, "move": str(action.move), "grounded": observation.grounded}))
	_expect(max_extent < 70.0, "%s articulation separated beyond admitted geometry: %.3f" % [rig_id, max_extent])
	_expect(max_speed < 360.0, "%s scripted control produced excessive speed %.3f" % [rig_id, max_speed])
	_expect(max_anchor_error < 4.0, "%s joint anchors separated %.3f cells" % [rig_id, max_anchor_error])
	_expect(max_limit_error < 0.25, "%s rotary stop exceeded allowed impact play: %.3f radians" % [rig_id, max_limit_error])
	_expect(max_slide_angle < 0.25, "%s guided slide turned over: %.3f radians" % [rig_id, max_slide_angle])
	_expect(max_slide_error < 0.6, "%s slide passed its endstop: %.3f cells" % [rig_id, max_slide_error])
	_expect(_rig.bodies().size() == 1 or articulated_motion > 0.02 or articulated_translation > 0.12,
		"%s moved only as a rigid decorative assembly; no useful relative joint motion" % rig_id)
	_expect(max_x - min_x > 8.0, "%s script made no meaningful horizontal progress: %.3f" % [rig_id, max_x-min_x])
	_expect(late_max_x - late_min_x > 4.0, "%s script stalled after initial movement: %.3f" % [rig_id, late_max_x-late_min_x])
	_expect(turnarounds >= 1, "%s scripted patrol never reversed its route" % rig_id)
	var parts: Array = _rig.bodies()
	var drawings: Array = _rig.draw_parts()
	_expect(parts.size() == drawings.size() and parts.size() == Catalog.entry(rig_id).parts.size(),
		"%s physical/drawn/catalogue part counts disagree" % rig_id)
	for index: int in range(parts.size()):
		var shape: Shape2D = parts[index].get_child(0).shape
		var pose: Transform2D = _bridge.body_transform(index)
		var local_vertex: Vector2 = pose.affine_inverse() * Vector2(drawings[index].polygon[0])
		if shape is CircleShape2D:
			_expect(drawings[index].polygon.size() == 32, "%s circle tessellation" % rig_id)
			for point: Vector2 in drawings[index].polygon:
				_expect(absf((pose.affine_inverse() * point).length() - shape.radius) < 0.005,
					"%s circle drawing differs from collider radius" % rig_id)
		else:
			_expect(shape is RectangleShape2D and local_vertex.distance_to(-shape.size * 0.5) < 0.005,
				"%s drawn vertex differs from collider" % rig_id)
	var held: Dictionary = _rig.observation()
	held.parts[0].position = Vector2(-999, -999)
	_expect(Vector2(_rig.observation().parts[0].position).x > -900,
		"%s observation aliases live state" % rig_id)
	_results.append({"rig": str(rig_id), "parts": parts.size(), "travel_x": snappedf(max_x-min_x, 0.01),
		"late_travel_x": snappedf(late_max_x-late_min_x, 0.01), "turnarounds": turnarounds,
		"minimum_energy": snappedf(minimum_energy, 0.001),
		"peak_speed": snappedf(max_speed, 0.01), "peak_omega": snappedf(max_omega, 0.01),
		"peak_part_extent": snappedf(max_extent, 0.01), "grounded_ticks": grounded_ticks,
		"peak_anchor_error": snappedf(max_anchor_error, 0.001), "peak_limit_error": snappedf(max_limit_error, 0.001),
		"peak_slide_angle": snappedf(max_slide_angle, 0.001), "peak_slide_error": snappedf(max_slide_error, 0.001),
		"joint_motion": snappedf(articulated_motion, 0.001), "joint_translation": snappedf(articulated_translation, 0.001),
		"recovery_count": pilot.diagnostics().recovery_count})
	await _teardown()


func _test_obstructed_patrol() -> void:
	if not _setup(&"runner"):
		return
	# This wall is inside the patrol route and taller than an ordinary vault.
	# The controller must attempt it, recognize failed progress and leave it.
	_box(Vector2(118, 122), Vector2(6, 68))
	var pilot = Scripted.new()
	pilot.configure(&"runner", _rig.centre(), 0)
	var before: Dictionary = _rig.observation()
	var action: Dictionary = Scripted.neutral_action()
	var closest: float = 30.0
	var furthest_x: float = _rig.centre().x
	var escape_distance: float = 0.0
	var recovery_count: int = 0
	for tick: int in range(480):
		if tick % 6 == 0:
			action = pilot.next_action(before, DT * 6.0)
		before = _step(action)
		closest = minf(closest, float(before.wall_right))
		furthest_x = maxf(furthest_x, Vector2(before.centre).x)
		recovery_count = int(pilot.diagnostics().recovery_count)
		if recovery_count > 0:
			escape_distance = maxf(escape_distance, furthest_x - Vector2(before.centre).x)
	_expect(closest < 10.0, "obstructed patrol never approached the real wall")
	_expect(recovery_count > 0 and escape_distance > 12.0,
		"runner kept vaulting at an impassable wall instead of escaping: %.3f cells" % escape_distance)
	print("ACT004_OBSTRUCTION_METRICS ", JSON.stringify({"rig": "runner", "closest_wall": closest,
		"recoveries": recovery_count, "escape_distance": escape_distance}))
	await _teardown()


func _mass_centre() -> Vector2:
	var total: float = 0.0
	var value: Vector2 = Vector2.ZERO
	for part: Dictionary in _rig.observation().parts:
		total += float(part.mass)
		value += Vector2(part.position) * float(part.mass)
	return value / total


func _test_no_air_traction() -> void:
	if not _setup(&"ripper", false, Vector2(100, 50)):
		return
	var initial: Vector2 = _mass_centre()
	for _tick: int in range(30):
		_step({"move": Vector2.RIGHT, "effort": 1.0})
	_expect(absf(_mass_centre().x - initial.x) < 0.20,
		"ground traction translated the free-flight assembly")
	_expect(not bool(_rig.observation().grounded), "airborne Ripper reported ground")
	await _teardown()


func _test_cancel_charge() -> void:
	if not _setup(&"pouncer"):
		return
	for _tick: int in range(40):
		_step(Scripted.neutral_action())
	for _tick: int in range(30):
		_step({"primary": true, "aim": Vector2.UP, "effort": 1.0})
	_expect(_rig.charge > 0.3, "Pouncer did not charge on support")
	_rig.cancel()
	var before: float = float(_rig.observation().velocity.y)
	var result: Dictionary = _step(Scripted.neutral_action())
	_expect(_rig.charge == 0.0, "cancel retained a charge")
	_expect(Vector2(result.applied_impulse).y > -0.1 and float(result.velocity.y) >= before - 3.0,
		"cancel was interpreted as charge-release launch")
	await _teardown()


func _test_mount_and_release() -> void:
	if not _setup(&"rocketjumper", false, Vector2(100, 60)):
		return
	var count: int = _rig.bodies().size()
	_rig.refresh_observation()
	_expect(_rig.fire_mount(0, 1.0), "mounted launcher did not accept clear shot")
	var effects: Array = _rig.drain_effects()
	_expect(effects.size() == 1, "mounted launcher did not emit one bounded effect")
	if effects.size() == 1:
		_expect(int(effects[0].source_part) > 0 and int(effects[0].epoch) == 1,
			"held tool source identity lost")
	_bridge.step()
	_rig.refresh_observation()
	_expect(Vector2(_rig.observation().velocity).length() > 0.1, "recoil did not reach the physical assembly")
	_expect(_rig.release_usable(), "articulated usable did not release")
	_expect(_rig.bodies().size() == count, "release changed flattened coupling body identity")
	_expect(not _rig.fire_mount(0, 1.0), "released usable remained controllable")
	for _tick: int in range(20):
		_step(Scripted.neutral_action())
	_expect(bool(_rig.observation().parts[count-1].detached), "released held body not represented as detached")
	await _teardown()


func _test_surface_blast() -> void:
	if not _setup(&"rocketjumper", false, Vector2(100, 60)):
		return
	_rig.advance({"primary": true, "aim": Vector2.UP}, DT)
	_expect(_rig.drain_effects().is_empty(), "empty-air rocket blast emitted terrain effect")
	_expect(_rig.energy == 1.0, "empty-air surface blast spent energy")
	_expect(Vector2(_rig.observation().applied_impulse).length() < 0.001, "empty-air surface blast supplied recoil")
	await _teardown()


func _test_support_removal() -> void:
	if not _setup(&"ripper"):
		return
	for _tick: int in range(70):
		_step(Scripted.neutral_action())
	_expect(bool(_rig.observation().grounded), "Ripper did not acquire actual terrain support")
	_terrain[0].free()
	for _tick: int in range(10):
		_step(Scripted.neutral_action())
	_expect(not bool(_rig.observation().grounded), "terrain removal retained stale support")
	await _teardown()


func _test_slide_endstops() -> void:
	if not _setup(&"springjack", false, Vector2(100, 70)):
		return
	# Hold the fixture's chassis and strike the free piston/shoe in both
	# directions. This exercises the actual Rapier stops under external load,
	# independently of the controller's smaller desired-travel envelope.
	var parts: Array = _rig.bodies()
	parts[0].freeze = true
	var smallest: float = INF
	var largest: float = -INF
	var largest_angle: float = 0.0
	var limits: Vector2 = Catalog.entry(&"springjack").joints[0].limits
	for tick: int in range(180):
		if tick % 30 == 0:
			var direction: float = 1.0 if tick % 60 == 0 else -1.0
			for index: int in range(1, parts.size()):
				PhysicsServer2D.body_apply_central_impulse(parts[index].get_rid(), Vector2.DOWN * direction * 55.0 * parts[index].mass)
		var observation: Dictionary = _step(Scripted.neutral_action())
		var guide: Dictionary = observation.joints[0]
		smallest = minf(smallest, float(guide.travel))
		largest = maxf(largest, float(guide.travel))
		largest_angle = maxf(largest_angle, absf(float(guide.angle)))
	_expect(largest - smallest > 2.0, "slide fixture did not exercise a substantial part of its stroke")
	_expect(smallest >= limits.x - 0.6 and largest <= limits.y + 0.6,
		"externally struck piston bypassed its endstops: %.3f..%.3f" % [smallest, largest])
	_expect(largest_angle < 0.25, "externally struck piston lost guide alignment")
	print("ACT004_SLIDE_METRICS ", JSON.stringify({"minimum": smallest, "maximum": largest, "angle": largest_angle}))
	await _teardown()


func _test_rope_controls() -> void:
	for rig_id: StringName in [&"swinger", &"lineshank", &"winchbug"]:
		print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=rope_setup rig=", rig_id)
		if not _setup(rig_id):
			continue
		var ceiling: StaticBody2D = _box(Vector2(132, 96), Vector2(240, 4))
		var pilot = Scripted.new()
		pilot.configure(rig_id, _rig.centre(), 0)
		var start: Vector2 = _rig.centre()
		var before: Dictionary = _rig.observation()
		var action: Dictionary = Scripted.neutral_action()
		var attached_ticks: int = 0
		var attach_count: int = 0
		var release_count: int = 0
		var shortest: float = INF
		var highest: float = start.y
		var maximum_tension: float = 0.0
		for tick: int in range(600):
			if tick % 150 == 0:
				print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=rope_step rig=", rig_id, " tick=", tick)
			if tick % 6 == 0:
				action = pilot.next_action(before, DT * 6.0)
			var observation: Dictionary = _step(action)
			var attached: bool = bool(observation.rope_attached)
			attached_ticks += int(attached)
			attach_count += int(attached and not bool(before.rope_attached))
			release_count += int(not attached and bool(before.rope_attached))
			if attached:
				shortest = minf(shortest, float(observation.rope_length))
			highest = minf(highest, Vector2(observation.centre).y)
			maximum_tension = maxf(maximum_tension, float(observation.tension))
			before = observation
		_expect(attached_ticks > 60 and attach_count >= 2, "%s script did not repeatedly acquire a reachable rope anchor" % rig_id)
		_expect(release_count >= 1, "%s script never deliberately released its rope" % rig_id)
		var required_climb: float = 4.0 if rig_id == &"lineshank" else 7.0
		_expect(start.y - highest > required_climb, "%s rope demonstration never lifted clear of the floor" % rig_id)
		_expect(maximum_tension > 1.0 and maximum_tension <= 500.0, "%s rope tension was absent or unbounded" % rig_id)
		# Reacquire this ceiling, then remove it. A stale terrain anchor must not
		# continue towing the assembly or turn cancellation into a stored kick.
		_rig.release_rope(false)
		_rig.cooldown = 0.0
		_rig.refresh_observation()
		var reacquired: bool = _rig.cast_rope(Vector2.UP)
		_expect(reacquired, "%s missing live-anchor removal fixture precondition" % rig_id)
		if reacquired:
			for _tick: int in range(5):
				_step({"reel": 1.0})
			var body: RigidBody2D = _rig.bodies()[0]
			var velocity_before: Vector2 = PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			_rig.cancel()
			var velocity_after: Vector2 = PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			_expect(velocity_before.distance_to(velocity_after) < 0.0001,
				"%s cancellation incorrectly released a tether impulse" % rig_id)
			_rig.cooldown = 0.0
			_rig.refresh_observation()
			_expect(_rig.cast_rope(Vector2.UP), "%s could not reacquire its still-present ceiling" % rig_id)
			ceiling.free()
			_step(Scripted.neutral_action())
			_expect(not _rig.rope_attached, "%s retained an anchor after its ceiling was removed" % rig_id)
		_rig.cancel()
		_expect(not _rig.rope_attached and _rig.tension == 0.0, "%s cancellation retained tether energy" % rig_id)
		print("ACT004_ROPE_METRICS ", JSON.stringify({"rig": str(rig_id), "attached_ticks": attached_ticks,
			"attaches": attach_count, "releases": release_count, "climb": start.y - highest,
			"shortest": shortest, "maximum_tension": maximum_tension}))
		await _teardown()


func _test_recovery() -> void:
	for rig_id: StringName in [&"runner", &"scrabbler", &"clamberer", &"springjack", &"copter", &"gemini", &"tricopter"]:
		print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=recovery_setup rig=", rig_id)
		if not _setup(rig_id, true, Vector2(100, 110)):
			continue
		var initial: Dictionary = _rig.observation()
		var origin: Vector2 = initial.centre
		# This is fixture initialization. No controller receives pose-write
		# authority; every subsequent recovery step uses ordinary actuation.
		for part: Dictionary in initial.parts:
			_bridge.reset_body(int(part.index), origin + (Vector2(part.position) - origin).rotated(PI), float(part.rotation) + PI)
		_rig.refresh_observation()
		var pilot = Scripted.new()
		pilot.configure(rig_id, origin, 0)
		var before: Dictionary = _rig.observation()
		var action: Dictionary = Scripted.neutral_action()
		var upright_ticks: int = 0
		var recovery_tick: int = -1
		for tick: int in range(600):
			if tick % 150 == 0:
				print("REGRESSION_PROGRESS case=test_physical_actor_rigs phase=recovery_step rig=", rig_id, " tick=", tick)
			if tick % 6 == 0:
				action = pilot.next_action(before, DT * 6.0)
			before = _step(action)
			if absf(wrapf(float(before.rotation), -PI, PI)) < 0.8 and absf(float(before.angular_velocity)) < 3.0:
				if recovery_tick < 0:
					recovery_tick = tick
				if tick >= 300:
					upright_ticks += 1
		_expect(recovery_tick >= 0 and recovery_tick < 300, "%s did not recover from its initialized tumble within five seconds" % rig_id)
		_expect(upright_ticks > 90, "%s did not retain useful attitude after recovery" % rig_id)
		print("ACT004_RECOVERY_METRICS ", JSON.stringify({"rig": str(rig_id), "recovery_tick": recovery_tick,
			"late_upright_ticks": upright_ticks, "final_angle": before.rotation}))
		await _teardown()


func _test_owner_reuse() -> void:
	if not _setup(&"copter", false, Vector2(100, 70)):
		return
	_step({"auxiliary": true, "move": Vector2.RIGHT})
	_expect(not bool(_rig.observation().powered), "power-toggle precondition failed")
	_bridge.shutdown()
	_rig.close()
	_expect(_rig.configure(Catalog.entry(&"qwen"), Vector2(100, 70), 2, 7) == OK,
		"closed owner could not configure a replacement incarnation")
	var state: Dictionary = _rig.observation()
	_expect(int(state.epoch) == 7 and int(state.actor_slot) == 2 and int(state.tick) == 0,
		"owner reuse retained a prior identity or clock")
	_expect(bool(state.powered) and int(state.mode) == 0 and float(state.energy) == 1.0 \
		and float(state.charge) == 0.0 and not bool(state.rope_attached),
		"owner reuse retained previous motor, resource or attachment state")
	await _teardown()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
