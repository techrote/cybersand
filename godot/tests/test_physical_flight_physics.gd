extends SceneTree

# 4LY-001 physical plant conformance, using the retained real Rapier backend.
# These bounded Trainer checks establish neither family handling calibration
# nor learned navigation, target-PC feel, or broad granular qualification.
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const DT: float = 1.0 / 60.0
const ORIGIN := Vector2(400, 400)
var assertions: int = 0
var failures: int = 0
var owner: Node2D
var rig: CyberPhysicalActorRig
var bridge: CyberRapierPhysicsBridge
var metrics: Array = []


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("4LY_PHYSICS: " + message)


func setup(max_force: float = -1.0, zero_environment: bool = false) -> bool:
	var definition: Dictionary = Catalog.entry(&"4ly_trainer")
	if max_force > 0.0:
		# A declared underpowered fixture, not a calibrated family profile.
		definition.flight_profile.max_force = max_force
	if zero_environment:
		# Explicit zero-gravity/drag accounting fixture: one real force step has
		# an independent analytic velocity oracle without passive decomposition.
		definition.flight_profile.gravity = 0.0
		definition.flight_profile.linear_drag = 0.0
		definition.flight_profile.angular_drag = 0.0
		definition.profile.gravity = 0.0
		definition.profile.air_drag = 0.0
		definition.profile.angular_drag = 0.0
	rig = Rig.new()
	owner.add_child(rig)
	expect(rig.configure(definition, ORIGIN) == OK, "Trainer physical fixture configures")
	if not rig.configured:
		return false
	bridge = Bridge.new()
	expect(bridge.initialize(owner.get_world_2d().space, rig.bodies(), rig.body_sizes()) == OK, "fixture uses actual manual-step Rapier")
	return bridge.is_initialized()


func close_fixture() -> void:
	if bridge != null:
		bridge.shutdown()
		bridge = null
	if is_instance_valid(rig):
		rig.close()
		rig.free()
		rig = null
	await process_frame


func step(move: Vector2 = Vector2.ZERO, allowed: bool = true) -> Dictionary:
	rig.advance({"move": move}, DT, allowed)
	bridge.step()
	rig.complete_step()
	rig.refresh_observation()
	return rig.observation()


func physics_velocity() -> Vector2:
	return PhysicsServer2D.body_get_state(rig.bodies()[0].get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)


func physics_angular_velocity() -> float:
	return float(PhysicsServer2D.body_get_state(rig.bodies()[0].get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))


func check_receipt(view: Dictionary, maximum_force: float = 360.0) -> void:
	var receipt: Dictionary = view.flight.controller
	expect(str(view.fault).is_empty() and bool(receipt.valid), "finite flight/controller state")
	expect(Vector2(receipt.applied_force).is_finite() and Vector2(receipt.applied_force).length() <= maximum_force + 0.001,
		"applied total force stays inside its declared budget, including gravity compensation")
	expect(is_finite(float(receipt.applied_torque)) and absf(float(receipt.applied_torque)) <= 300.001,
		"applied stabilization torque stays bounded")
	expect(Vector2(view.applied_impulse).distance_to(Vector2(receipt.applied_force) * DT) < 0.0001,
		"published actual impulse equals the controller's applied-force receipt")
	expect(absf(float(view.applied_torque_impulse) - float(receipt.applied_torque) * DT) < 0.0001,
		"published actual torque impulse equals bounded attitude receipt")


func test_unsupported_hover_and_translation() -> void:
	if not setup():
		await close_fixture()
		return
	var initial: Vector2 = rig.centre()
	var peak_drop: float = 0.0
	var supported_ticks: int = 0
	var hover_trace: Array = []
	var view: Dictionary = {}
	for tick: int in range(600):
		view = step()
		peak_drop = maxf(peak_drop, view.centre.y - initial.y)
		supported_ticks += int(bool(view.grounded))
		check_receipt(view)
		if tick % 60 == 59:
			hover_trace.append({"tick": tick + 1, "y": view.centre.y, "vy": view.velocity.y})
	expect(supported_ticks == 0, "ten-second flight has no supporting surface or clearance source")
	expect(absf(float(view.centre.y) - initial.y) < 10.0 and peak_drop < 10.0,
		"authorized neutral sustains unsupported hover after finite thrust spool-up")
	expect(Vector2(view.velocity).length() < 0.5, "neutral settles approximately stationary without a position target")
	var late_displacement: float = float(hover_trace[-1].y) - float(hover_trace[4].y)
	expect(absf(late_displacement) < 0.1, "settled neutral actually remains stationary across the final five seconds")
	expect(absf(late_displacement / 5.0 - float(view.velocity.y)) < 0.05,
		"neutral published velocity agrees with measured position travel")
	expect(float(view.energy) == 1.0 and float(view.energy_used) == 0.0,
		"ordinary stationary flight has no undeclared reserve drain or timeout")
	var hover_position: Vector2 = view.centre
	var hover_velocity: Vector2 = view.velocity
	for _tick: int in range(120):
		view = step(Vector2.UP)
		check_receipt(view)
	var ascent: float = hover_position.y - view.centre.y
	var upward_velocity: float = view.velocity.y
	expect(ascent > 30.0 and upward_velocity < -20.0, "upward request produces actual sustained ascent")
	var summit: Vector2 = view.centre
	for _tick: int in range(180):
		view = step(Vector2.DOWN)
		check_receipt(view)
	var descent: float = view.centre.y - summit.y
	expect(descent > 35.0 and float(view.velocity.y) > 20.0, "downward request produces actual controlled descent")
	for _tick: int in range(120):
		view = step(Vector2.RIGHT)
		check_receipt(view)
	var moving_position: Vector2 = view.centre
	var moving_speed: float = view.velocity.x
	expect(moving_speed > 30.0, "horizontal velocity request produces physical motion")
	for _tick: int in range(180):
		view = step()
		check_receipt(view)
	expect(Vector2(view.velocity).length() < 0.5, "authorized neutral brakes actual momentum")
	expect(float(view.centre.x) > moving_position.x + 1.0, "neutral braking preserves a finite stopping distance")
	expect(float(view.centre.x) - moving_position.x < 30.0, "neutral stops within the declared Trainer fixture envelope")
	metrics.append({"case": "unsupported_hover_translation", "hover_ticks": 600,
		"grounded_ticks": supported_ticks, "peak_spool_drop": peak_drop,
		"hover_final_y": hover_position.y, "hover_final_speed": hover_velocity.length(), "hover_trace": hover_trace,
		"late_hover_displacement": late_displacement,
		"ascent": ascent, "upward_velocity": upward_velocity,
		"descent": descent, "horizontal_speed": moving_speed,
		"braking_distance": view.centre.x - moving_position.x, "final_speed": Vector2(view.velocity).length()})
	await close_fixture()


func test_impulse_accounting_and_attitude() -> void:
	if not setup(-1.0, true):
		await close_fixture()
		return
	for _tick: int in range(60):
		step()
	var body: RigidBody2D = rig.bodies()[0]
	PhysicsServer2D.body_apply_central_impulse(body.get_rid(), Vector2(500, 0) * body.mass)
	PhysicsServer2D.body_apply_torque_impulse(body.get_rid(), 35.0 * body.inertia)
	rig.refresh_observation()
	var before_velocity: Vector2 = physics_velocity()
	var before_omega: float = physics_angular_velocity()
	var before_pose: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
	rig.advance({"move": Vector2.ZERO}, DT)
	var view: Dictionary = rig.observation()
	var receipt: Dictionary = view.flight.controller
	var after_pose: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
	expect(after_pose.is_equal_approx(before_pose), "controller never writes pose to perform locomotion")
	expect(physics_velocity().is_equal_approx(before_velocity) and is_equal_approx(physics_angular_velocity(), before_omega),
		"continuous force requests do not replace or impulsively assign velocity before Rapier steps")
	bridge.step()
	rig.complete_step()
	rig.refresh_observation()
	view = rig.observation()
	var after_velocity: Vector2 = physics_velocity()
	var after_omega: float = physics_angular_velocity()
	expect((after_velocity - before_velocity).distance_to(Vector2(receipt.applied_force) * DT / body.mass) < 0.001,
		"zero-environment force step gives exactly its bounded force integral, without hidden speed limiting")
	expect(absf((after_omega - before_omega) - float(receipt.applied_torque) * DT / body.inertia) < 0.001,
		"zero-drag torque step gives exactly the bounded stabilization integral")
	expect(after_velocity.x > 450.0 and after_omega > 30.0, "desired speed bounds do not delete collision-induced linear/angular velocity")
	check_receipt(view)
	metrics.append({"case": "external_impulse_accounting_zero_gravity_drag", "before_vx": before_velocity.x,
		"after_vx": after_velocity.x, "before_omega": before_omega, "after_omega": after_omega,
		"force": [receipt.applied_force.x, receipt.applied_force.y], "torque": receipt.applied_torque})
	# A force prepared for the next step is future actuator work. Cancel it
	# before the bridge consumes it; unlike a past impulse, it must not leak.
	before_velocity = physics_velocity()
	before_omega = physics_angular_velocity()
	rig.advance({"move": Vector2.ZERO}, DT)
	expect(Vector2(rig.observation().flight.controller.applied_force).length() > 0.0,
		"pending cancellation fixture queued a real force")
	rig.cancel()
	bridge.step()
	rig.complete_step()
	rig.refresh_observation()
	expect(physics_velocity().distance_to(before_velocity) < 0.001
		and absf(physics_angular_velocity() - before_omega) < 0.001,
		"cancellation retracts an unconsumed force without changing prior momentum")
	await close_fixture()
	if not setup():
		await close_fixture()
		return
	for _tick: int in range(60):
		step()
	body = rig.bodies()[0]
	PhysicsServer2D.body_apply_torque_impulse(body.get_rid(), 6.0 * body.inertia)
	var peak_angle: float = 0.0
	var peak_torque: float = 0.0
	for _tick: int in range(300):
		view = step()
		check_receipt(view)
		peak_angle = maxf(peak_angle, absf(wrapf(float(view.rotation), -PI, PI)))
		peak_torque = maxf(peak_torque, absf(float(view.flight.controller.applied_torque)))
	expect(peak_angle > 0.08, "external torque physically disturbs the chassis")
	expect(absf(wrapf(float(view.rotation), -PI, PI)) < 0.05 and absf(float(view.angular_velocity)) < 0.05,
		"bounded attitude assistance physically recovers the disturbed chassis")
	metrics.append({"case": "attitude_recovery", "peak_angle": peak_angle, "peak_torque": peak_torque,
		"final_angle": view.rotation, "final_omega": view.angular_velocity})
	await close_fixture()


func test_power_and_saturation() -> void:
	if not setup():
		await close_fixture()
		return
	for _tick: int in range(60):
		step()
	var before: Vector2 = rig.centre()
	rig.set_propulsion_enabled(false)
	var maximum_applied: float = 0.0
	var view: Dictionary = {}
	for _tick: int in range(60):
		view = step(Vector2.UP)
		maximum_applied = maxf(maximum_applied, Vector2(view.flight.controller.applied_force).length())
		expect(float(view.flight.controller.applied_torque) == 0.0, "power-off has no hidden attitude actuator")
	expect(maximum_applied == 0.0 and view.flight.mode == "power_off", "power-off is explicitly passive despite a live upward request")
	expect(float(view.centre.y) - before.y > 50.0 and float(view.velocity.y) > 100.0,
		"airborne body falls under actual gravity when propulsion is disabled")
	metrics.append({"case": "power_off", "ticks": 60, "fall": view.centre.y - before.y,
		"velocity_y": view.velocity.y, "maximum_force": maximum_applied})
	await close_fixture()
	if not setup(150.0):
		await close_fixture()
		return
	var saturated_ticks: int = 0
	var peak_force: float = 0.0
	for _tick: int in range(120):
		view = step()
		check_receipt(view, 150.0)
		saturated_ticks += int(bool(view.flight.controller.thrust_saturated))
		peak_force = maxf(peak_force, Vector2(view.flight.controller.applied_force).length())
	expect(saturated_ticks > 100 and peak_force <= 150.001, "underpowered neutral shares one finite budget with gravity compensation")
	expect(float(view.centre.y) - ORIGIN.y > 40.0 and float(view.velocity.y) > 30.0,
		"underpowered neutral cannot produce hidden unlimited hover")
	metrics.append({"case": "underpowered_saturation", "maximum_force": 150.0,
		"saturated_ticks": saturated_ticks, "peak_force": peak_force,
		"fall": view.centre.y - ORIGIN.y, "velocity_y": view.velocity.y})
	await close_fixture()


func test_native_contact() -> void:
	if not setup():
		await close_fixture()
		return
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world != null, "real native material owner is required")
	if world == null:
		await close_fixture()
		return
	expect(world.diagnostic_reset({"workers": 1}), "native contact world resets")
	expect(world.diagnostic_fill_rect(Vector2i(450, 300), Vector2i(6, 300), CyberCellWorld.WALL), "native wall is authored in cell authority")
	expect(bridge.queue_hard_surface_chunk_snapshot(world.get_hard_surface_chunk_rectangles()), "native wall enters existing hard-terrain publication path")
	bridge.process_hard_surface_collider_budget(256, 0)
	expect(bridge.pending_hard_surface_chunks() == 0 and bridge.hard_surface_shape_count() > 0, "native wall has actual Rapier collider geometry")
	var maximum_x: float = ORIGIN.x
	var contact_ticks: int = 0
	var view: Dictionary = {}
	for tick: int in range(240):
		var states: PackedFloat32Array = bridge.pack_body_states()
		expect(states.size() == CyberRigidBodyCoupling.INPUT_STRIDE, "exactly one body crosses copied native ABI")
		world.prepare_rigid_body_coupling(states, true)
		var result: PackedFloat32Array = world.rigid_body_results()
		expect(result.size() == CyberRigidBodyCoupling.RESULT_STRIDE and int(result[0]) == 1, "native result retains the chassis body identity")
		bridge.apply_cellular_results(tick + 1, result)
		view = step(Vector2.RIGHT)
		maximum_x = maxf(maximum_x, float(view.centre.x))
		var body_state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(rig.bodies()[0].get_rid())
		contact_ticks += int(body_state != null and body_state.get_contact_count() > 0)
		check_receipt(view)
	expect(maximum_x > 430.0 and maximum_x < 446.0, "bounded propulsion reaches but does not pass through the native wall")
	expect(contact_ticks > 30, "actual Rapier contacts persist while the requested velocity is blocked")
	expect(world.material_at(452, 400) == CyberCellWorld.WALL, "controller does not move or erase its obstacle")
	expect(view.flight.mode == "velocity" and view.flight.controller.desired_velocity.x > 0.0 and absf(float(view.velocity.x)) < 1.0,
		"requested motion remains distinct from physically blocked motion")
	metrics.append({"case": "native_wall", "maximum_x": maximum_x, "contact_ticks": contact_ticks,
		"final_vx": view.velocity.x, "desired_vx": view.flight.controller.desired_velocity.x})
	world = null
	await close_fixture()


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "actual pinned Rapier backend is required")
	if failures == 0:
		await test_unsupported_hover_and_translation()
		await test_impulse_accounting_and_attitude()
		await test_power_and_saturation()
		await test_native_contact()
	owner.free()
	await process_frame
	print("4LY_PHYSICAL_METRICS ", JSON.stringify(metrics))
	print("4LY physical flight physics: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
