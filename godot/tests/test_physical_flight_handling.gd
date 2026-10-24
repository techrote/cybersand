extends SceneTree

# 4LY-002 prospectively registered, actual-Rapier handling comparisons.
# The same two-output requests, independent external impulses and wall fixture
# are used for all four profiles. These are physical measurements, not a
# training-only controller and not subjective owner-feel qualification.
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
const Controller = preload("res://scripts/physical_flight_controller.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const DT: float = 1.0 / 60.0
const ORIGIN := Vector2(400.0, 400.0)
const WALL_LEFT: float = 496.0
const COMMON_SPEED: float = 20.0
var owner: Node2D
var rig: CyberPhysicalActorRig
var bridge: CyberRapierPhysicsBridge
var wall: StaticBody2D
var assertions: int = 0
var failures: int = 0
var results: Dictionary = {}
var registered: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, reason: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("4LY_HANDLING: " + reason)


func setup(model: StringName, contact: bool = false) -> bool:
	if contact:
		wall = StaticBody2D.new()
		wall.name = "IdenticalActualRapierWall"
		wall.position = Vector2(WALL_LEFT + 4.0, 400.0)
		var collider := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(8.0, 600.0)
		collider.shape = rectangle
		wall.add_child(collider)
		owner.add_child(wall)
	var definition: Dictionary = Catalog.entry(model)
	rig = Rig.new()
	owner.add_child(rig)
	expect(rig.configure(definition, ORIGIN) == OK and rig.configured,
		str(model) + " creates one live chassis at the identical admitted spawn")
	if not rig.configured:
		return false
	bridge = Bridge.new()
	expect(bridge.initialize(owner.get_world_2d().space, rig.bodies(), rig.body_sizes()) == OK
		and bridge.is_initialized(), str(model) + " initializes actual Rapier bridge")
	return bridge.is_initialized()


func close_fixture() -> void:
	if bridge != null:
		bridge.shutdown()
		bridge = null
	if is_instance_valid(rig):
		rig.close()
		rig.free()
		rig = null
	if is_instance_valid(wall):
		wall.free()
		wall = null
	await process_frame


func step(move: Vector2 = Vector2.ZERO) -> Dictionary:
	rig.advance({"move": move}, DT)
	bridge.step()
	rig.complete_step()
	rig.refresh_observation()
	return rig.observation()


func current_velocity() -> Vector2:
	return PhysicsServer2D.body_get_state(rig.bodies()[0].get_rid(),
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)


func check_actuator(view: Dictionary, model: StringName) -> void:
	var report: Dictionary = view.flight.controller
	var profile: Dictionary = Profile.entry(model)
	expect(str(view.fault).is_empty() and bool(report.valid), str(model) + " maintains finite physical control")
	expect(Vector2(report.applied_force).is_finite()
		and Vector2(report.applied_force).length() <= float(profile.max_force) + 0.01,
		str(model) + " obeys its total force budget, including gravity compensation")
	expect(is_finite(float(report.applied_torque))
		and absf(float(report.applied_torque)) <= float(profile.max_torque) + 0.01,
		str(model) + " obeys its bounded upright torque")
	expect(Vector2(view.applied_impulse).distance_to(Vector2(report.applied_force) * DT) < 0.0002,
		str(model) + " physical impulse matches admitted assistance")


func measure_commands(model: StringName) -> Dictionary:
	var out: Dictionary = {"id": str(model), "profile_hash": Profile.profile_hash(Profile.entry(model)),
		"controller_id": Profile.CONTROLLER_ID}
	if not setup(model):
		await close_fixture()
		return {}
	var grounded: int = 0
	var hover_start: Vector2 = rig.centre()
	var hover: Dictionary = {}
	for tick: int in range(240):
		hover = step()
		grounded += int(bool(hover.grounded))
		if tick % 20 == 0:
			check_actuator(hover, model)
	out["unsupported_hover_steps"] = 240 - grounded
	out["hover_final_speed"] = Vector2(hover.velocity).length()
	out["neutral_hover_displacement_cells"] = Vector2(hover.centre).distance_to(hover_start)
	expect(int(out.unsupported_hover_steps) >= int(registered.individual.minimum_hover_support_free_steps)
		and out.hover_final_speed <= float(registered.individual.maximum_final_hover_speed_cells_per_second),
		str(model) + " holds unsupported neutral hover and settles")
	var onset: int = -1
	var speed_60: float = 0.0
	var speed_120: float = 0.0
	var saturated: int = 0
	var view: Dictionary = {}
	for tick: int in range(120):
		view = step(Vector2.RIGHT)
		if onset < 0 and float(view.velocity.x) >= 3.0:
			onset = tick + 1
		if tick == 59:
			speed_60 = float(view.velocity.x)
		saturated += int(bool(view.flight.controller.thrust_saturated))
		if tick % 20 == 0:
			check_actuator(view, model)
	speed_120 = float(view.velocity.x)
	var brake_start: float = float(view.centre.x)
	var brake_time: int = -1
	var most_negative_vx: float = 0.0
	for tick: int in range(180):
		view = step()
		most_negative_vx = minf(most_negative_vx, float(view.velocity.x))
		if brake_time < 0 and absf(float(view.velocity.x)) <= 1.0:
			brake_time = tick + 1
		if tick % 30 == 0:
			check_actuator(view, model)
	var neutral_stop: float = float(view.centre.x) - brake_start
	expect(onset > 0 and speed_60 > 3.0, str(model) + " begins moving from normalized request")
	expect(float(view.velocity.length()) <= float(registered.individual.maximum_stop_speed_after_180_steps),
		str(model) + " has usable authorized stopping authority")
	out.merge({"onset_steps": onset, "vx_after_60": speed_60, "vx_after_120": speed_120,
		"neutral_brake_ticks_to_one": brake_time, "neutral_stop_distance": neutral_stop,
		"neutral_brake_velocity_overshoot": -most_negative_vx,
		"thrust_saturated_ticks": saturated}, true)
	for _tick: int in range(120):
		step(Vector2.RIGHT)
	var reverse_steps: int = -1
	for tick: int in range(180):
		view = step(Vector2.LEFT)
		if reverse_steps < 0 and float(view.velocity.x) < 0.0:
			reverse_steps = tick + 1
	out["reverse_crossing_steps"] = reverse_steps
	out["reverse_final_vx"] = float(view.velocity.x)
	expect(reverse_steps > 0 and float(view.velocity.x) < -float(registered.individual.minimum_reverse_final_left_speed_cells_per_second),
		str(model) + " reverses with the same two-output action")
	var ascent_start: float = float(view.centre.y)
	for _tick: int in range(90):
		view = step(Vector2.UP)
	out["ascent_cells"] = ascent_start - float(view.centre.y)
	expect(float(out.ascent_cells) >= float(registered.individual.minimum_upward_displacement_cells),
		str(model) + " climbs unsupported using bounded vertical thrust")
	var descent_start: float = float(view.centre.y)
	for _tick: int in range(120):
		view = step(Vector2.DOWN)
	out["descent_cells"] = float(view.centre.y) - descent_start
	expect(float(out.descent_cells) >= float(registered.individual.minimum_downward_displacement_cells),
		str(model) + " descends through an ordinary admitted action")
	var body: RigidBody2D = rig.bodies()[0]
	PhysicsServer2D.body_apply_torque_impulse(body.get_rid(), 4.0 * body.inertia)
	var peak_angle: float = 0.0
	for _tick: int in range(240):
		view = step()
		peak_angle = maxf(peak_angle, absf(wrapf(float(view.rotation), -PI, PI)))
	out["upright_peak_angle"] = peak_angle
	out["upright_final_angle"] = absf(wrapf(float(view.rotation), -PI, PI))
	out["upright_final_omega"] = absf(float(view.angular_velocity))
	expect(peak_angle > 0.05 and float(out.upright_final_angle) <= float(registered.individual.maximum_upright_angle_radians)
		and float(out.upright_final_omega) <= float(registered.individual.maximum_upright_angular_speed_radians_per_second),
		str(model) + " recovers from an actual angular impulse")
	await close_fixture()
	return out


func measure_equal_speed(model: StringName) -> Dictionary:
	if not setup(model):
		await close_fixture()
		return {}
	for _tick: int in range(180):
		step()
	var body: RigidBody2D = rig.bodies()[0]
	PhysicsServer2D.body_apply_central_impulse(body.get_rid(), Vector2(COMMON_SPEED * body.mass, 0.0))
	rig.refresh_observation()
	var vx_initial: float = current_velocity().x
	var start_x: float = rig.centre().x
	var time_to_one: int = -1
	var view: Dictionary = {}
	for tick: int in range(240):
		view = step()
		if time_to_one < 0 and absf(float(view.velocity.x)) <= 1.0:
			time_to_one = tick + 1
	var stop_distance: float = float(view.centre.x) - start_x
	expect(vx_initial > COMMON_SPEED - 0.05 and vx_initial < COMMON_SPEED + 0.05,
		str(model) + " uses exact common physical +20 cell/s impulse, not a special controller")
	expect(time_to_one > 0 and absf(float(view.velocity.x)) < 1.0,
		str(model) + " has finite common-speed braking")
	await close_fixture()
	return {"common_initial_vx": vx_initial, "common_brake_time_to_one": time_to_one,
		"common_brake_distance": stop_distance, "common_brake_final_vx": float(view.velocity.x)}


func measure_passive_coast(model: StringName) -> Dictionary:
	if not setup(model):
		await close_fixture()
		return {}
	for _tick: int in range(180):
		step()
	var body: RigidBody2D = rig.bodies()[0]
	PhysicsServer2D.body_apply_central_impulse(body.get_rid(), Vector2(COMMON_SPEED * body.mass, 0.0))
	rig.set_propulsion_enabled(false)
	var start_x: float = rig.centre().x
	var peak_force: float = 0.0
	var view: Dictionary = {}
	for _tick: int in range(60):
		view = step()
		peak_force = maxf(peak_force, Vector2(view.flight.controller.applied_force).length())
	expect(peak_force == 0.0 and view.flight.mode == "power_off",
		str(model) + " passive coasting must not retain active assistance")
	await close_fixture()
	return {"passive_coast_distance": float(view.centre.x) - start_x,
		"passive_coast_vx": float(view.velocity.x),
		"power_off_max_force": peak_force}


func measure_wall(model: StringName) -> Dictionary:
	if not setup(model, true):
		await close_fixture()
		return {}
	for _tick: int in range(240):
		step()
	var contact_ticks: int = 0
	var maximum_x: float = ORIGIN.x
	var view: Dictionary = {}
	for tick: int in range(480):
		view = step(Vector2.RIGHT)
		maximum_x = maxf(maximum_x, float(view.centre.x))
		var state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(rig.bodies()[0].get_rid())
		contact_ticks += int(state != null and state.get_contact_count() > 0)
		if tick % 60 == 0:
			check_actuator(view, model)
	var half_width: float = float(Profile.entry(model).collider_size[0]) * 0.5
	expect(contact_ticks >= int(registered.individual.minimum_contact_ticks),
		str(model) + " contacts the same real static Rapier wall")
	expect(maximum_x <= WALL_LEFT - half_width + float(registered.individual.maximum_final_wall_penetration_cells),
		str(model) + " cannot force the collider through the wall")
	expect(view.flight.mode == "velocity" and float(view.flight.controller.desired_velocity.x) > 0.0,
		str(model) + " retains distinct requested velocity when physically blocked")
	await close_fixture()
	return {"wall_contact_ticks": contact_ticks, "wall_max_x": maximum_x,
		"wall_final_vx": float(view.velocity.x)}


func run() -> void:
	var path: String = "res://tests/fixtures/4ly002_handling_thresholds.json"
	registered = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(registered is Dictionary and int(registered.get("schema_version", 0)) == 1,
		"independent prospective numeric registration is present")
	if not registered is Dictionary or registered.is_empty():
		quit(1)
		return
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "pinned actual Rapier backend required")
	if failures == 0:
		for model: StringName in Profile.IDS:
			var row: Dictionary = await measure_commands(model)
			if row.is_empty():
				continue
			row.merge(await measure_equal_speed(model), true)
			row.merge(await measure_passive_coast(model), true)
			row.merge(await measure_wall(model), true)
			results[str(model)] = row
		if results.size() == 4:
			var trainer: Dictionary = results["4ly_trainer"]
			var hauler: Dictionary = results["4ly_hauler"]
			var drifter: Dictionary = results["4ly_drifter"]
			var dart: Dictionary = results["4ly_dart"]
			var limits: Dictionary = registered.comparisons
			expect(float(hauler.vx_after_60) <= float(trainer.vx_after_60) * float(limits.hauler_speed_at_60_steps_max_of_trainer),
				"prospective Hauler-vs-Trainer acceleration/response ordering")
			expect(float(dart.vx_after_60) >= float(trainer.vx_after_60) * float(limits.dart_speed_at_60_steps_min_of_trainer),
				"prospective Dart-vs-Trainer response ordering")
			expect(float(drifter.common_brake_distance) >= float(trainer.common_brake_distance)
				* float(limits.drifter_equal_speed_stop_distance_min_of_trainer),
				"prospective Drifter-vs-Trainer braking distance at the SAME physical speed")
			expect(float(hauler.vx_after_120) < float(trainer.vx_after_120) and float(dart.vx_after_120) > float(trainer.vx_after_120),
				"resolved speed envelopes remain distinct after the normalized trace")
		else:
			expect(false, "four complete measured profiles required")
	owner.free()
	await process_frame
	print("4LY_002_HANDLING_METRICS ", JSON.stringify({
		"registered_thresholds": registered,
		"fixed_delta": DT, "common_impulse_speed": COMMON_SPEED,
		"controller_hash": Controller.controller_hash(), "profiles": results}))
	print("4LY-002 handling: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
