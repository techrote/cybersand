extends SceneTree

# Real Rapier object identity, collision grace, local pickup and static processor
# lifecycle. Test fixtures may place bodies; admitted producer actions never do.
const Session = preload("res://scripts/physical_actor_session.gd")
const DT: float = 1.0 / 60.0
var owner: Node2D
var session: CyberPhysicalActorSession
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_USABLE_LIFECYCLE: " + message)


func step() -> void:
	session.advance(DT)
	session.bridge.step()
	session.complete_step()


func action(extra: Dictionary = {}) -> Dictionary:
	var item: Dictionary = session.observation(0).equipment
	var request: Dictionary = {"usable_index": int(item.usable_index)}
	request.merge(extra, true)
	return {"equipment": request}


func create(usable: int, epoch: int) -> bool:
	if session != null:
		session.close()
		session.free()
	session = Session.new()
	owner.add_child(session)
	var result: bool = session.configure([{"model": &"gyrocrate", "producer": &"policy",
		"position": Vector2(100, 100), "usable_index": usable}], owner.get_world_2d().space, epoch)
	if result:
		for body: RigidBody2D in session.bodies():
			body.gravity_scale = 0.0
	return result


func velocity(body: RigidBody2D) -> Vector2:
	return PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)


func pose(body: RigidBody2D) -> Transform2D:
	return PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)


func box(position: Vector2, size: Vector2) -> StaticBody2D:
	var result := StaticBody2D.new()
	result.position = position
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	result.add_child(collider)
	owner.add_child(result)
	return result


func accepted_receipt(request: Dictionary) -> Dictionary:
	var value: Dictionary = request.duplicate(true)
	value.merge({"accepted": true, "consumed": true, "reason": "deployed", "changed_cells": 0,
		"charge": 82.0, "cooldown": 0.35}, true)
	return {"run_id": session.run_id, "epoch": session.epoch, "receipts": [value]}


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "real Rapier is required")
	expect(create(12, 20), "physical equipment owner starts")
	if not session.active():
		quit(1)
		return
	var item: Dictionary = session.observation(0).equipment
	var old_item: Dictionary = item.duplicate(true)
	var old_view: Dictionary = session.observation(0)
	var held: RigidBody2D = session.bodies()[int(item.body_id) - 1]
	var chassis: RigidBody2D = session.bodies()[0]
	var held_id: int = held.get_instance_id()
	var body_count: int = session.bodies().size()
	PhysicsServer2D.body_set_state(held.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(12, -3))
	PhysicsServer2D.body_set_state(chassis.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(20, 7))
	session._rigs[0].refresh_observation()
	var before_pose: Transform2D = pose(held)
	var before_velocity: Vector2 = velocity(held)
	var chassis_before: Vector2 = velocity(chassis)
	expect(session.submit_local(0, action({"drop": true}), &"policy", 18), "explicit drop command admitted")
	session.advance(DT)
	item = session.observation(0).equipment
	expect(item.state == "released" and not item.attached and item.equipment_epoch == int(old_item.equipment_epoch) + 1,
		"drop advances equipment incarnation and releases grip")
	expect(item.instance_id == old_item.instance_id and item.body_id == old_item.body_id \
		and held.get_instance_id() == held_id and session.bodies().size() == body_count,
		"drop preserves exactly the existing body and item identity")
	expect(pose(held) == before_pose and velocity(held) == before_velocity and velocity(chassis) == chassis_before,
		"drop does not teleport equipment or erase item/actor linear momentum")
	expect(chassis in held.get_collision_exceptions(), "release starts with owner collision grace")
	expect(not session.submit(Session.make_command(old_view, 100, {"equipment": {"trigger": true}}, 18)),
		"pre-release equipment observation cannot command the released item")
	expect(not session.submit_local(0, action({"usable_index": 13}), &"policy", 18) \
		and session.last_error == "selection_requires_held_body", "a dropped body cannot be replaced by retooling the slot")
	expect(session.cancel_input(0, session.epoch, &"policy"), "post-release cancellation accepted")
	for index: int in range(14):
		step()
	item = session.observation(0).equipment
	expect(item.state == "released" and item.release_age >= 0.2 and chassis not in held.get_collision_exceptions(),
		"collision grace expires passively even when all input is cancelled")
	# A policy may request pickup but has no authority to relocate the object.
	var far: Transform2D = pose(held)
	far.origin = pose(chassis).origin + Vector2(50, 0)
	PhysicsServer2D.body_set_state(held.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, far)
	session._rigs[0].refresh_observation()
	expect(session.submit_local(0, action({"attach": true}), &"policy", 18), "distant pickup request admitted for evaluation")
	session.advance(DT)
	expect(session.observation(0).equipment.last_result == "reattach_requires_proximity_and_clearance" \
		and session.observation(0).equipment.state == "released" and pose(held).is_equal_approx(far),
		"distant pickup is explicitly refused and leaves the physical object in place")
	var grip: Vector2 = session.observation(0).equipment.grip_position
	var nearby: Transform2D = far
	nearby.origin = grip + Vector2(0, 6)
	PhysicsServer2D.body_set_state(held.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, nearby)
	PhysicsServer2D.body_set_state(held.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(held.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	for body: RigidBody2D in session.bodies():
		if body != held:
			body.freeze = true
	var barrier: StaticBody2D = box(grip + Vector2(0, 3), Vector2(4, 0.7))
	session.bridge.step()
	session.complete_step()
	nearby = pose(held)
	session._rigs[0].refresh_observation()
	expect(not session.observation(0).equipment.reattach_ready, "real Rapier obstruction blocks advertised pickup clearance")
	session.submit_local(0, action(), &"policy", 18)
	session.advance(DT)
	session.submit_local(0, action({"attach": true}), &"policy", 18)
	session.advance(DT)
	expect(session.observation(0).equipment.state == "released" and pose(held).is_equal_approx(nearby),
		"nearby pickup cannot pass through a thin obstacle")
	barrier.free()
	session._rigs[0].refresh_observation()
	session.submit_local(0, action(), &"policy", 18)
	session.advance(DT)
	before_pose = pose(held)
	before_velocity = velocity(held)
	session.submit_local(0, action({"attach": true}), &"policy", 18)
	session.advance(DT)
	item = session.observation(0).equipment
	expect(item.state == "held" and item.attached and item.body_id == old_item.body_id \
		and item.instance_id == old_item.instance_id and held.get_instance_id() == held_id,
		"explicit clear nearby pickup reconnects the same body")
	expect(pose(held) == before_pose and velocity(held) == before_velocity and session.bodies().size() == body_count,
		"reattachment creates no clone and preserves current item pose/momentum")
	expect(chassis in held.get_collision_exceptions(), "reattachment restores owner collision exceptions")
	expect(item.equipment_epoch == int(old_item.equipment_epoch) + 2, "reattachment fences copied released-body commands")
	# Processor fixture: a small physical pedestal supports only the equipment
	# body, while the parked carrier is fixed to isolate settle/pickup admission.
	expect(create(22, 21), "physical processor owner starts")
	item = session.observation(0).equipment
	held = session.bodies()[int(item.body_id) - 1]
	held_id = held.get_instance_id()
	for body: RigidBody2D in session.bodies():
		if body != held:
			body.freeze = true
	var pedestal: StaticBody2D = box(Vector2(item.position) + Vector2(0, float(item.half_extents.y) + 0.5), Vector2(5.0, 1.0))
	session._rigs[0].refresh_observation()
	expect(session.submit_local(0, action({"trigger": true, "power": 0.0}), &"policy", 18),
		"zero-power processor command is evaluated explicitly")
	session.advance(DT)
	expect(session.observation(0).equipment.state == "held" and not session.observation(0).equipment.deploy_intent \
		and session.observation(0).equipment.last_result == "zero_power" and session.drain_equipment_requests().is_empty(),
		"zero-power processor command neither releases nor registers the real body")
	session.submit_local(0, action(), &"policy", 18)
	session.advance(DT)
	expect(session.submit_local(0, action({"trigger": true, "power": 0.37}), &"policy", 18), "processor deployment command admitted")
	step()
	expect(session.observation(0).equipment.state == "released" and session.observation(0).equipment.deploy_intent \
		and session.drain_equipment_requests().is_empty(), "deployment first detaches the physical body before native work")
	for index: int in range(40):
		if session.observation(0).equipment.state != "released":
			break
		session.submit_local(0, action(), &"policy", 18)
		step()
	item = session.observation(0).equipment
	var requests: Array = session.drain_equipment_requests()
	expect(item.state == "fixed" and held.freeze \
		and PhysicsServer2D.body_get_mode(held.get_rid()) == PhysicsServer2D.BODY_MODE_STATIC,
		"supported low-speed settling fixes the existing Rapier processor body")
	expect(requests.size() == 1 and requests[0].operation == "deploy" and item.pending,
		"only a fixed physical body may request native processor registration")
	expect(requests.size() == 1 and is_equal_approx(float(requests[0].power), 0.37),
		"settling retains the admitted deployment power across neutral lease renewals")
	expect(session.equipment_frame().devices.size() == 1 and held.get_instance_id() == held_id,
		"published deployment is the one actual held body, with no logical clone")
	if requests.is_empty():
		quit(1)
		return
	var obsolete: Dictionary = accepted_receipt(requests[0])
	var fixed_pose: Transform2D = pose(held)
	session.cancel_input(0, session.epoch, &"policy")
	expect(session.accept_equipment_feedback(obsolete) == 0 and session.observation(0).equipment.state == "fixed" \
		and pose(held) == fixed_pose and held.freeze, "cancelled pending deployment cannot return as an accepted receipt")
	session.submit_local(0, action({"trigger": true}), &"policy", 18)
	session.advance(DT)
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1 and requests[0].request_id != obsolete.receipts[0].request_id,
		"explicit fresh deployment retries use a new request token")
	if requests.is_empty():
		quit(1)
		return
	expect(session.accept_equipment_feedback(accepted_receipt(requests[0])) == 1 \
		and session.observation(0).equipment.state == "deployed", "native acceptance marks that same fixed body as deployed")
	session.cancel_input(0, session.epoch, &"policy")
	expect(session.observation(0).equipment.state == "deployed" and held.freeze \
		and session.equipment_frame().devices.size() == 1,
		"input cancellation preserves an already committed processor and its support")
	var deployed: Dictionary = session.observation(0).equipment
	before_pose = pose(held)
	session.submit_local(0, action({"attach": true}), &"policy", 18)
	session.advance(DT)
	item = session.observation(0).equipment
	expect(item.state == "held" and not held.freeze and item.body_id == deployed.body_id \
		and item.instance_id == deployed.instance_id and pose(held) == before_pose,
		"local explicit pickup resumes dynamics on the same physical processor")
	expect(session.equipment_frame().devices.is_empty() and item.equipment_epoch > deployed.equipment_epoch,
		"pickup retires the deployed epoch from the next worker frame")
	var retired_frame: Dictionary = session.equipment_frame()
	var retired_receipt: Dictionary = accepted_receipt(requests[0])
	session.close()
	expect(session.drain_equipment_requests().is_empty() and session.equipment_frame().actors.is_empty(),
		"reset retires all equipment commands and physical publications")
	expect(session.accept_equipment_feedback(retired_receipt) == 0, "reset cannot accept an obsolete processor receipt")
	pedestal.free()
	expect(create(22, 22), "replacement session starts with a fresh actor epoch")
	expect(session.run_id != retired_frame.run_id and session.observation(0).equipment.instance_id != deployed.instance_id,
		"slot reuse cannot inherit a previous session's released/deployed instance")
	expect(session.accept_equipment_feedback(retired_receipt) == 0, "late receipt remains invalid after slot reuse")
	session.close()
	session.free()
	owner.free()
	await process_frame
	print("Physical usable lifecycle: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
