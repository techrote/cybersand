extends SceneTree

# Direct actuator regressions: independent force equations and hard geometry.
# The existing test_actor_rigs.gd remains the unchanged intent-lane regression.
const Rig = preload("res://scripts/actor_rig_motor.gd")
const Actuation = preload("res://scripts/actor_rig_actuation.gd")
const DT: float = 1.0 / 60.0
const IDS: Array[StringName] = [&"ripper", &"copter", &"gemini"]
var assertions: int = 0
var failures: int = 0
var peak_queries: int = 0


class TestWorld:
	extends RefCounted
	var floor_y: float = 900.0
	var wall_x: float = INF
	var ceiling_y: float = 0.0
	var enclosed: bool = false
	var failed: bool = false
	var queries: int = 0
	var material_reads: int = 0
	var writes: int = 0
	var malformed: int = 0
	var obstacles: Array[Rect2] = []

	func has_failed() -> bool:
		return failed

	func box_collides(origin: Vector2, size: Vector2) -> bool:
		queries += 1
		return collides_untracked(origin, size)

	func character_box_collides(origin: Vector2, size: Vector2, _mode: int) -> bool:
		queries += 1
		return collides_untracked(origin, size)

	func collides_untracked(origin: Vector2, size: Vector2) -> bool:
		if not origin.is_finite() or not size.is_finite() or size.x <= 0.0 or size.y <= 0.0 \
			or size.x > 32.00001 or size.y > 32.00001:
			malformed += 1
			return true
		if enclosed or failed or origin.x < 0.0 or origin.y < ceiling_y - 0.00001 \
			or origin.x + size.x > 1024.0 or origin.y + size.y > floor_y + 0.00001:
			return true
		var hull := Rect2(origin, size)
		if is_finite(wall_x) and hull.intersects(Rect2(wall_x, 0.0, 1.0, 1024.0)):
			return true
		for obstacle: Rect2 in obstacles:
			if hull.intersects(obstacle):
				return true
		return false

	func material_at(_x: int, _y: int) -> int:
		material_reads += 1
		return 0

	func emit_disc(_x: int, _y: int, _radius: int, _material: int) -> void:
		writes += 1

	func character_disturb_granular(_origin: Vector2, _size: Vector2, _impact: float) -> int:
		return 0

	func clear_counters() -> void:
		queries = 0
		material_reads = 0
		writes = 0
		malformed = 0


class ProbeRig:
	extends CyberActorRigMotor
	var intent_calls: int = 0

	func _advance_rig(delta: float, movement: Vector2, aim: Vector2, effort: float,
			trim: float, reel: float, primary: bool, secondary: bool, auxiliary: bool,
			primary_edge: bool, secondary_edge: bool, auxiliary_edge: bool,
			primary_release: bool, world) -> void:
		intent_calls += 1
		super._advance_rig(delta, movement, aim, effort, trim, reel, primary, secondary,
			auxiliary, primary_edge, secondary_edge, auxiliary_edge, primary_release, world)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_schema()
	_test_direct_dispatch_and_passive_motion()
	_test_copter_mapping()
	_test_gemini_mapping()
	_test_ripper_support_and_brake()
	_test_resource_scaling_and_cancel()
	_test_invalid_frames()
	_test_collision_and_burial()
	_test_bounded_runs()
	print("Actor rig actuation: %d assertions, %d failures; peak occupancy %d/96; zero material reads/writes." % [assertions, failures, peak_queries])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL direct actuation: " + label)


func _near(actual: float, expected: float, label: String, tolerance: float = 0.0001) -> void:
	_check(is_finite(actual) and absf(actual - expected) <= tolerance,
		"%s (actual %.9f; expected %.9f)" % [label, actual, expected])


func _rig(id: StringName):
	var actor = Rig.new()
	_check(actor.configure_model(id), "configure " + str(id))
	actor.reset(Vector2(300.0, 300.0))
	return actor


func _step(actor, world: TestWorld, command: Vector4, delta: float = DT) -> bool:
	world.clear_counters()
	var before: Vector2 = actor.centre()
	var accepted: bool = actor.simulate_actuator_action(delta, command, world)
	peak_queries = maxi(peak_queries, world.queries)
	_check(world.queries == actor.query_count_last, "all occupancy calls are counted")
	_check(world.queries <= 96 and world.malformed == 0, "finite bounded occupancy")
	_check(world.material_reads == 0 and world.writes == 0 and actor.ray_queries_last == 0 \
		and actor.edited_cells_last == 0 and actor.effect_reads_last == 0, "locomotion-only metal has no ray/tool work")
	_check(absf(actor.centre().x - before.x) <= 6.001 and absf(actor.centre().y - before.y) <= 6.001,
		"centre travel obeys shared six-cell budget")
	var state: PackedFloat32Array = actor.actuation_observation()
	_check(state.size() == 32, "actuation observation has exactly32 values")
	for value: float in state:
		_check(is_finite(value), "finite actuation telemetry")
	return accepted


func _test_schema() -> void:
	_check(Actuation.OBSERVATION_SIZE == 32 and Actuation.VERSION == 1, "schema constants")
	for index: int in range(IDS.size()):
		var id: StringName = IDS[index]
		_check(Actuation.supports_model(id), "supported metal profile")
		var profile: Dictionary = Actuation.profile(id)
		_check(profile["observation_fields"].size() == 32 and profile["channels"].size() == 4, "named fixed strides")
		_check(profile["profile_index"] == index + 1, "stable profile index")
		_check(profile["profile_id"] == str(Actuation.profile_id_for(id)), "stable profile ID")
		_check(JSON.parse_string(JSON.stringify(profile)) is Dictionary, "profile is JSON serializable")
		_check(Actuation.valid_command(id, Vector4.ZERO), "neutral admitted")
		for channel: int in range(4):
			var invalid: Vector4 = Vector4.ZERO
			invalid[channel] = NAN
			_check(not Actuation.valid_command(id, invalid), "every nonfinite channel refused")
			_check(Actuation.clamp_command(id, invalid) == Vector4.ZERO, "invalid command does not produce a NaN clamp")
	_check(not Actuation.supports_model(&"runner") and Actuation.profile(&"runner").is_empty(), "SetA not converted to metal")
	_check(not Actuation.supports_model(&"scout"), "unmapped new rig refuses metal")
	_check(not Actuation.valid_command(&"ripper", Vector4(0.0, 0.0, 0.0, 0.1)), "Ripper reserved channel must be zero")
	_check(not Actuation.valid_command(&"gemini", Vector4(0.0, 0.0, 1.0, 0.0)), "Gemini third reserved channel")
	_check(not Actuation.valid_command(&"gemini", Vector4(0.0, 0.0, 0.0, 1.0)), "Gemini fourth reserved channel")
	_check(Actuation.clamp_command(&"ripper", Vector4(1.0e30, -1.0e30, 1.0e30, 0.0)) == Vector4(1.0, -1.0, 1.0, 0.0), "Ripper finite clamp")
	_check(Actuation.clamp_command(&"copter", Vector4(-1.0e30, 1.0e30, -1.0e30, 1.0e30)) == Vector4(0.0, 1.0, -1.0, 1.0), "Copter per-channel ranges")


func _test_direct_dispatch_and_passive_motion() -> void:
	var world := TestWorld.new()
	var actor := ProbeRig.new()
	_check(actor.configure_model(&"copter"), "dispatch probe configured")
	actor.reset(Vector2(300.0, 300.0))
	actor.rotation = 0.37
	actor.velocity = Vector2(30.0, 0.0)
	_check(_step(actor, world, Vector4.ZERO), "neutral direct tick admitted")
	_check(actor.intent_calls == 0, "metal never dispatches high-level rig policy")
	_near(actor.rotation, 0.37, "neutral direct copter adds no wobble or self-right")
	_near(actor.velocity.x, 30.0 * (1.0 - 0.08 * DT), "neutral direct motion coasts through passive drag")
	_near(actor.velocity.y, 156.0 * DT, "neutral direct motion keeps gravity")
	_check(not actor.primary_ready and not actor.secondary_ready, "wire button readiness is inactive in metal lane")
	actor.simulate_rig_action(DT, Vector2.ZERO, Vector2.ZERO, 0.7, 0.0, 0.0, false, false, false, world)
	_check(actor.intent_calls == 1, "legacy wire call still dispatches existing rig policy")
	_check(actor.actuation.flags == 0, "wire update clears old metal readback")


func _test_copter_mapping() -> void:
	var world := TestWorld.new()
	var actor = _rig(&"copter")
	_check(_step(actor, world, Vector4(0.25, 0.5, 0.5, 0.0)), "direct copter mixed command")
	var state: PackedFloat32Array = actor.actuation_observation()
	_near(state[8], 42.0, "cyclic maps proportionally to body-right force")
	_near(state[9], -78.0, "collective maps proportionally to body-up force")
	_near(state[10], 208.0, "rotor torque gain")
	_near(state[11], 42.0, "fully powered force accepted")
	_near(state[14], 0.0, "no initial passive horizontal force")
	_near(state[15], 156.0, "gravity reports mass times acceleration")
	_near(state[17], 0.7, "delta-v integrates force over mass")
	_near(state[18], 1.3, "gravity and collective sum once")
	_near(state[19], 0.2, "delta-omega integrates torque over inertia")
	_near(state[23], (0.25 * 0.24 + 0.5 * 0.08 + 0.5 * 0.07) * DT, "mixed power resource accounting")
	_near(state[26], actor.velocity.x * DT, "actual centre x displacement", 0.00004)
	_near(state[27], actor.velocity.y * DT, "actual centre y displacement", 0.00004)
	var full = _rig(&"copter")
	_step(full, world, Vector4(0.5, 1.0, 1.0, 0.0))
	_near(full.actuation.requested_force.x, state[8] * 2.0, "double raw cyclic doubles requested force")
	_near(full.actuation.requested_force.y, state[9] * 2.0, "double raw collective doubles requested force")
	_near(full.actuation.requested_torque, state[10] * 2.0, "double raw torque doubles torque")
	var tilted = _rig(&"copter")
	tilted.rotation = PI * 0.5
	_step(tilted, world, Vector4(0.5, 0.0, 0.0, 0.0))
	_near(tilted.actuation.applied_force.x, 156.0, "body orientation rotates thrust into world x")
	_near(tilted.actuation.applied_force.y, 0.0, "sideways rotor does not auto-hover")
	_near(tilted.rotation, PI * 0.5, "throttle does not auto-level")
	var braked = _rig(&"copter")
	braked.angular_velocity = 3.0
	braked.energy = 0.0
	_step(braked, world, Vector4(0.0, 0.0, 0.0, 1.0))
	_near(braked.angular_velocity, 3.0 * (1.0 - (10.0 + 0.18) * DT), "rotor brake is proportional damping")
	_near(braked.actuation.energy_used, 0.0, "passive brake needs no powered reserve")
	_check(braked.angular_velocity > 0.0 and braked.angular_velocity < 3.0, "brake neither reverses nor instantly stops rotation")


func _test_gemini_mapping() -> void:
	var world := TestWorld.new()
	var left = _rig(&"gemini")
	var right = _rig(&"gemini")
	var paired = _rig(&"gemini")
	_step(left, world, Vector4(1.0, 0.0, 0.0, 0.0))
	_step(right, world, Vector4(0.0, 1.0, 0.0, 0.0))
	_step(paired, world, Vector4(0.5, 0.5, 0.0, 0.0))
	_near(left.actuation.requested_torque, 156.0 * 4.0, "left thruster moment arm")
	_near(right.actuation.requested_torque, -156.0 * 4.0, "right thruster opposite moment")
	_near(left.angular_velocity, -right.angular_velocity, "independent mirrored angular response")
	_near(left.velocity.y, 0.0, "one full thruster balances weight initially")
	_near(paired.angular_velocity, 0.0, "equal actuator pair cancels torque")
	_near(paired.velocity.y, 0.0, "half pair balances gravity initially")
	_near(paired.actuation.energy_used, 0.14 * DT, "paired consumption follows sum of actuator levels")
	_check(left.actuation != right.actuation and left.actuation != paired.actuation, "actuator state belongs to each actor")


func _test_ripper_support_and_brake() -> void:
	var world := TestWorld.new()
	var grounded_actor = _rig(&"ripper")
	world.floor_y = grounded_actor.position.y + grounded_actor.body_size.y
	_step(grounded_actor, world, Vector4(1.0, 0.0, 0.0, 0.0))
	_near(grounded_actor.actuation.applied_force.x, 600.0, "supported track force")
	_near(grounded_actor.velocity.x, 300.0 * DT, "track acceleration uses effective mass")
	_near(grounded_actor.actuation.delta_velocity.y, 0.0, "floor constraint appears in actual motion readback")
	_check(grounded_actor.actuation.passive_force.y > 0.0, "reported gravity exists despite floor reaction")
	var airborne = _rig(&"ripper")
	world.floor_y = 900.0
	_step(airborne, world, Vector4(1.0, 0.0, 0.0, 0.0))
	_near(airborne.actuation.requested_force.x, 600.0, "airborne motor request remains visible")
	_near(airborne.actuation.applied_force.x, 0.0, "airborne tracks cannot become jets")
	_check(bool(airborne.actuation.flags & Actuation.CONTACT_LIMITED), "unsupported track force reports contact limit")
	var tilted = _rig(&"ripper")
	tilted.rotation = PI / 3.0
	world.floor_y = tilted.centre().y + tilted._half_extents(tilted.rotation).y
	_step(tilted, world, Vector4(1.0, 0.0, 0.0, 0.0))
	_near(tilted.actuation.contact_scale, 0.5, "track contact diminishes with tilt")
	_near(tilted.actuation.applied_force.x, 150.0, "tilted drive projects onto the support tangent")
	_near(tilted.actuation.applied_force.y, 0.0, "track drive provides no vertical lift")
	var braked = _rig(&"ripper")
	world.floor_y = braked.position.y + braked.body_size.y
	braked.velocity.x = 60.0
	braked.energy = 0.4
	_step(braked, world, Vector4(0.0, 0.0, 1.0, 0.0))
	_near(braked.velocity.x, 60.0 * (1.0 - (18.0 + 1.2 + 0.08) * DT), "track brake adds explicit supported drag")
	_near(braked.energy, 0.4 + 0.30 * DT, "unpowered brake permits idle recharge")
	var ledge = _rig(&"ripper")
	ledge.position = Vector2(300.0, 890.0)
	world.floor_y = 900.0
	world.obstacles.append(Rect2(310.0, 899.0, 30.0, 1.0))
	for _tick: int in range(30):
		_step(ledge, world, Vector4(1.0, 0.0, 0.0, 0.0))
	_check(ledge.position.x <= 300.001 and ledge.position.y >= 889.999, "direct tracks do not invoke automatic ledge climbing")


func _test_resource_scaling_and_cancel() -> void:
	var world := TestWorld.new()
	var actor = _rig(&"copter")
	actor.energy = 0.24 * DT * 0.5
	_step(actor, world, Vector4(1.0, 0.0, 0.0, 0.0))
	_near(actor.actuation.resource_scale, 0.5, "partial reserve proportionally limits actuation")
	_near(actor.actuation.applied_force.y, -156.0, "partial reserve scales actual thrust")
	_near(actor.energy, 0.0, "partial stroke spends only available reserve")
	_check(bool(actor.actuation.flags & Actuation.RESOURCE_LIMITED), "partial reserve limit is visible")
	_step(actor, world, Vector4(1.0, 0.0, 0.0, 0.0))
	_near(actor.actuation.applied_force.length(), 0.0, "held exhausted actuator produces no force")
	_near(actor.energy, 0.0, "held empty actuator cannot recharge into automatic bursts")
	_step(actor, world, Vector4.ZERO)
	_near(actor.energy, 0.14 * DT, "coasting permits idle airborne recharge")
	actor.cooldown_remaining = 0.45
	var saved_energy: float = actor.energy
	var saved_velocity: Vector2 = actor.velocity
	var saved_position: Vector2 = actor.position
	actor.clear_actions()
	_near(actor.cooldown_remaining, 0.45, "cancellation preserves existing cooldown")
	_near(actor.energy, saved_energy, "cancellation does not refill resource")
	_check(actor.position == saved_position and actor.velocity == saved_velocity, "cancellation preserves physical state")
	_check(actor.actuation.flags == 0 and actor.actuation.requested_actuators == Vector4.ZERO \
		and actor.actuation.applied_force == Vector2.ZERO, "cancellation clears requested/applied output")


func _test_invalid_frames() -> void:
	var world := TestWorld.new()
	for id: StringName in IDS:
		var actor = _rig(id)
		actor.velocity = Vector2(2.0, -3.0)
		actor.angular_velocity = 0.4
		actor.energy = 0.6
		actor.cooldown_remaining = 0.4
		actor.charge = 0.2
		for bad_delta: float in [0.0, -0.1, NAN, INF]:
			var before: Vector2 = actor.position
			_check(not _step(actor, world, Vector4.ZERO, bad_delta), "invalid/nonpositive dt refused")
			_check(actor.position == before and actor.velocity == Vector2(2.0, -3.0), "invalid dt does not move actor")
			_near(actor.energy, 0.6, "invalid dt preserves energy")
			_near(actor.charge, 0.2, "invalid dt does not cancel or release armed state")
			_near(actor.cooldown_remaining, 0.4, "invalid dt does not advance cooldown")
			_check(world.queries == 0, "invalid dt performs no World reads")
		for channel: int in range(4):
			var malformed: Vector4 = Vector4.ZERO
			malformed[channel] = NAN
			_check(not _step(actor, world, malformed), "nonfinite raw channel refused at motor boundary")
			_near(actor.energy, 0.6, "malformed command never spends reserve")
			_check(world.queries == 0, "malformed command performs no World reads")
	var reserved = _rig(&"gemini")
	_check(not _step(reserved, world, Vector4(1.0, 1.0, 1.0, 0.0)), "reserved channel refused before any paired thrust")
	var unsupported = _rig(&"scout")
	_check(not _step(unsupported, world, Vector4.ZERO), "unsupported rig cannot enter direct lane")
	_check(bool(unsupported.actuation.flags & Actuation.UNSUPPORTED), "unsupported profile readback")


func _test_collision_and_burial() -> void:
	var world := TestWorld.new()
	for id: StringName in IDS:
		var actor = _rig(id)
		world.enclosed = true
		actor.velocity = Vector2(80.0, 30.0)
		var original: Vector2 = actor.position
		var energy_before: float = actor.energy
		_check(not _step(actor, world, Vector4(1.0, 1.0, 0.0, 0.0)), "enclosed direct tick refuses actuation")
		_check(actor.position == original and actor.velocity == Vector2.ZERO, "runtime burial never relocates actor")
		_near(actor.energy, energy_before, "burial spends no actuator energy")
		_check(actor.runtime_enclosed and bool(actor.actuation.flags & Actuation.BLOCKED), "burial status explicit")
		_check(actor.runtime_recovery_attempts == 0, "no runtime spawn search")
		world.enclosed = false
		actor.reset(Vector2(300.0, 300.0))
		world.failed = true
		_check(not _step(actor, world, Vector4.ZERO), "failed World refuses direct step")
		_check(world.queries == 0, "failed World receives no reads")
		world.failed = false
	var wall = _rig(&"copter")
	wall.position = Vector2(300.0, 300.0)
	wall.velocity = Vector2(160.0, 0.0)
	world.wall_x = 315.0
	_step(wall, world, Vector4(0.5, 1.0, 0.0, 0.0), 1000.0)
	_check(wall.position.x + wall.body_size.x <= world.wall_x, "thin wall blocks oversized-dt direct motion")
	_check(bool(wall.actuation.flags & Actuation.COLLISION_CONSTRAINED), "wall constraint reports explicitly")
	_check(bool(wall.actuation.flags & Actuation.DELTA_CLAMPED), "oversized dt clamp reports explicitly")
	_check(wall.actuation.applied_force.x > 0.0 and wall.actuation.delta_velocity.x < 0.0,
		"applied actuator force and collision-constrained actual velocity are distinct")
	world.wall_x = INF
	var ceiling = _rig(&"copter")
	ceiling.position.y = 300.0
	ceiling.velocity.y = -160.0
	world.ceiling_y = 297.0
	_step(ceiling, world, Vector4(1.0, 0.0, 0.0, 0.0), 1000.0)
	_check(ceiling.position.y >= world.ceiling_y, "thin ceiling cannot be crossed")
	world.ceiling_y = 0.0
	var pivot = _rig(&"ripper")
	world.floor_y = pivot.position.y + pivot.body_size.y
	_step(pivot, world, Vector4(0.0, 1.0, 0.0, 0.0))
	_check(pivot.rotation > 0.0 and not world.collides_untracked(pivot.centre() - pivot._half_extents(pivot.rotation), pivot._half_extents(pivot.rotation) * 2.0),
		"direct torque uses safe anchored floor pivot")
	var blocked_pivot = _rig(&"ripper")
	world.floor_y = blocked_pivot.position.y + blocked_pivot.body_size.y
	world.ceiling_y = blocked_pivot.position.y
	_step(blocked_pivot, world, Vector4(0.0, 1.0, 0.0, 0.0))
	_near(blocked_pivot.rotation, 0.0, "ceiling rejects unsafe torque rotation")
	_check(blocked_pivot.actuation.applied_torque > 0.0 and blocked_pivot.actuation.delta_angular_velocity == 0.0,
		"blocked rotation distinguishes accepted torque from actual angular motion")


func _test_bounded_runs() -> void:
	for id: StringName in IDS:
		var world := TestWorld.new()
		var actor = _rig(id)
		for tick: int in range(180):
			var command: Vector4
			match id:
				&"ripper": command = Vector4(sin(float(tick) * 0.1) * 2.0, cos(float(tick) * 0.09), 0.2, 0.0)
				&"copter": command = Vector4(0.7, sin(float(tick) * 0.1), cos(float(tick) * 0.07), 0.3)
				&"gemini": command = Vector4(0.4 + 0.3 * sin(float(tick) * 0.1), 0.4 + 0.3 * cos(float(tick) * 0.1), 0.0, 0.0)
			_step(actor, world, command, 1.0 / 30.0)
			_check(actor.velocity.is_finite() and actor.velocity.length() <= 160.001 \
				and absf(actor.angular_velocity) <= 6.0001, "common velocity/rotation caps remain effective")
			_check(actor.energy >= 0.0 and actor.energy <= 1.0, "resource remains normalized")
