extends SceneTree

# ACT-004 regressions for actual folding-joint motion and passive held-body
# lifecycle after authority is revoked. The fixture uses the pinned Rapier
# server and measures body angles/collision pairs, not just requested targets.
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const DT: float = 1.0 / 60.0

var failures: int = 0
var assertions: int = 0
var owner: Node2D
var rig: CyberPhysicalActorRig
var bridge: CyberRapierPhysicsBridge


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("PHYSICAL_ACTUATION: " + message)


func setup(model: StringName, deployment_override: float = 0.0) -> bool:
	var definition: Dictionary = Catalog.entry(model)
	definition.profile.gravity = 0.0
	definition.profile.gyro = 0.0
	# The rooted fixture prevents vehicle attitude, glide lift and gravity from
	# obscuring relative fin/mast motion. Rapier still solves every moving joint.
	if deployment_override != 0.0:
		for joint: Dictionary in definition.joints:
			if str(joint.get("role", "")) in ["wing", "sail"]:
				joint["deployment_sign"] = deployment_override
	rig = Rig.new()
	owner.add_child(rig)
	expect(rig.configure(definition, Vector2(120, 120)) == OK, "fixture configure " + str(model))
	if not rig.configured:
		return false
	rig.bodies()[0].freeze = true
	bridge = Bridge.new()
	expect(bridge.initialize(owner.get_world_2d().space, rig.bodies(), rig.body_sizes()) == OK,
		"fixture bridge " + str(model))
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


func step(action: Dictionary, allowed: bool = true) -> Dictionary:
	rig.advance(action, DT, allowed)
	bridge.step()
	rig.refresh_observation()
	return rig.observation()


func folding_angles() -> Dictionary:
	var result: Dictionary = {}
	var definitions: Array = rig.capabilities().joints
	var observed: Array = rig.observation().joints
	for index: int in range(definitions.size()):
		if str(definitions[index].get("role", "")) in ["wing", "sail"]:
			result[str(definitions[index].id)] = float(observed[index].angle)
	return result


func test_folding_motion(model: StringName, expected_signs: Array[float], override_sign: float = 0.0) -> void:
	if not setup(model, override_sign):
		await close_fixture()
		return
	for tick: int in range(150):
		step({"secondary": false, "effort": 1.0})
	var folded: Dictionary = folding_angles()
	for tick: int in range(180):
		step({"secondary": true, "effort": 1.0})
	var deployed: Dictionary = folding_angles()
	expect(deployed.size() == expected_signs.size(), str(model) + " folding-joint fixture coverage")
	var index: int = 0
	for joint_id: String in deployed:
		var change: float = float(deployed[joint_id]) - float(folded[joint_id])
		expect(change * expected_signs[index] > 0.30,
			"%s %s failed to deploy physically (folded %.3f, deployed %.3f)" %
			[model, joint_id, folded[joint_id], deployed[joint_id]])
		index += 1
	print("ACT004_FOLD_METRICS ", JSON.stringify({"rig": str(model), "override": override_sign,
		"folded": folded, "deployed": deployed}))
	await close_fixture()


func test_release_grace_after_cancel(explicit_cancel: bool) -> void:
	var session := Session.new()
	owner.add_child(session)
	expect(session.configure([{"model": &"lineshank", "producer": &"policy",
		"position": Vector2(140, 100)}], owner.get_world_2d().space, 7), "release session configured")
	if not session.active():
		session.free()
		return
	var bodies: Array[RigidBody2D] = session.bodies()
	var held: int = int(Catalog.entry(&"lineshank").mounts[0].held_part)
	var released_body: RigidBody2D = bodies[held]
	PhysicsServer2D.body_apply_central_impulse(released_body.get_rid(), Vector2(0.6, -0.3))
	var before: Vector2 = PhysicsServer2D.body_get_state(released_body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	expect(session.submit_local(0, {"release_usable": true}, &"policy", 1), "release command admitted")
	session.advance(DT)
	var after: Vector2 = PhysicsServer2D.body_get_state(released_body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	expect(bool(session.observation(0).parts[held].detached), "held part released")
	expect(before.is_equal_approx(after), "release does not assign or erase held-body velocity")
	expect(released_body.get_collision_exceptions().has(bodies[0]), "release starts with bounded owner collision grace")
	session.bridge.step()
	session.complete_step()
	if explicit_cancel:
		expect(session.cancel_input(0, session.epoch, &"policy"), "producer cancellation admitted")
	for tick: int in range(20):
		session.advance(DT)
		session.bridge.step()
		session.complete_step()
	for index: int in range(bodies.size()):
		if index != held:
			expect(not released_body.get_collision_exceptions().has(bodies[index]),
				"cancelled producer left held-body collision grace against part %d" % index)
			expect(not bodies[index].get_collision_exceptions().has(released_body),
				"cancelled producer left reciprocal collision grace against part %d" % index)
	expect(session.snapshot().actors[0].pending_input_edges == 0, "passive grace does not restore cancelled input")
	session.close()
	session.free()
	await process_frame


func test_vector_pod_steering(model: StringName) -> void:
	if not setup(model):
		await close_fixture()
		return
	for tick: int in range(120):
		step({"move": Vector2.RIGHT, "effort": 1.0})
	var right: Array = rig.observation().joints
	for tick: int in range(180):
		step({"move": Vector2.LEFT, "effort": 1.0})
	var left: Array = rig.observation().joints
	var definitions: Array = rig.capabilities().joints
	var measured: Array = []
	for index: int in range(definitions.size()):
		if str(definitions[index].get("role", "")) != "thruster":
			continue
		expect(float(right[index].angle) > 0.03 and float(left[index].angle) < -0.03,
			"%s actual pod %d failed to steer in both commanded directions (%.3f, %.3f)" %
			[model, index, right[index].angle, left[index].angle])
		expect(absf(float(right[index].angle)) <= float(right[index].limits.y) + 0.1
			and absf(float(left[index].angle)) <= absf(float(left[index].limits.x)) + 0.1,
			"%s pod steering bypassed its rotary endstops" % model)
		measured.append({"joint": str(definitions[index].id), "right": right[index].angle,
			"left": left[index].angle})
	print("ACT004_GIMBAL_METRICS ", JSON.stringify({"rig": str(model), "pods": measured}))
	await close_fixture()


func box(position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collider.shape = rectangle
	body.add_child(collider)
	owner.add_child(body)
	return body


func expect_cancelled_observation() -> void:
	var before: Dictionary = rig.observation()
	rig.cancel()
	var cancelled: Dictionary = rig.observation()
	expect(float(cancelled.charge) == 0.0 and not cancelled.rope_attached and not cancelled.gripped,
		"fresh cancellation observation clears charge, rope and grip immediately")
	expect(cancelled.action.is_empty() and cancelled.thruster_levels == Vector2.ZERO
		and cancelled.anchor == Vector2.ZERO and float(cancelled.tension) == 0.0,
		"fresh cancellation observation clears command and attachment intent")
	for joint: Dictionary in cancelled.joints:
		expect(float(joint.target) == 0.0, "fresh cancellation observation clears joint target")
	expect(before.parts == cancelled.parts and before.tick == cancelled.tick,
		"cancellation publishes lifecycle without stepping or changing physics samples")
	var bodies: Array[RigidBody2D] = rig.bodies()
	for index: int in range(bodies.size()):
		var velocity: Vector2 = PhysicsServer2D.body_get_state(bodies[index].get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		expect(velocity.is_equal_approx(before.parts[index].velocity), "cancellation retains actual body momentum")


func test_cancelled_observation() -> void:
	if setup(&"pouncer"):
		var floor_y: float = 120.25 + float(Catalog.entry(&"pouncer").bounds.end.y)
		var floor_body: StaticBody2D = box(Vector2(120, floor_y + 1.0), Vector2(80, 2))
		for tick: int in range(30):
			step({"primary": true, "effort": 1.0})
		expect(float(rig.observation().charge) > 0.3, "cancel fixture stored a real supported charge")
		expect_cancelled_observation()
		floor_body.free()
	await close_fixture()
	if setup(&"lineshank"):
		var ceiling: StaticBody2D = box(Vector2(120, 88), Vector2(60, 2))
		step({"primary": true, "aim": Vector2.UP, "effort": 1.0})
		expect(bool(rig.observation().rope_attached), "cancel fixture attached a terrain rope")
		expect_cancelled_observation()
		ceiling.free()
	await close_fixture()
	if setup(&"clamberer"):
		var floor_y: float = 120.25 + float(Catalog.entry(&"clamberer").bounds.end.y)
		var floor_body: StaticBody2D = box(Vector2(120, floor_y + 1.0), Vector2(80, 2))
		step({"secondary": true, "aim": Vector2.DOWN, "effort": 1.0})
		expect(bool(rig.observation().gripped), "cancel fixture established a terrain grip")
		expect_cancelled_observation()
		floor_body.free()
	await close_fixture()


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "pinned real Rapier extension available")
	if failures == 0:
		await test_folding_motion(&"pouncer", [-1.0, 1.0])
		await test_folding_motion(&"skatesail", [1.0, 1.0])
		await test_folding_motion(&"pouncer", [1.0, 1.0], 1.0)
		await test_vector_pod_steering(&"astra")
		await test_vector_pod_steering(&"luna")
		await test_release_grace_after_cancel(true)
		await test_release_grace_after_cancel(false)
		await test_cancelled_observation()
	owner.free()
	await process_frame
	print("Physical actor actuation: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
