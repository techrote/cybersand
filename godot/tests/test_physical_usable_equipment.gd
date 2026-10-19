extends SceneTree

# Admission/receipt negatives use the real Rapier body owner. Cellular effect
# correctness has a separate real-World integration test; this test proves that
# a successful copied receipt is the sole one-shot entry for physical recoil.
const Session = preload("res://scripts/physical_actor_session.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Loadouts = preload("res://scripts/physical_usable_loadouts.gd")
const Usables = preload("res://scripts/usable_catalog.gd")
const Rig = preload("res://scripts/physical_actor_rig.gd")
const DT: float = 1.0 / 60.0
var assertions: int = 0
var failures: int = 0
var owner: Node2D
var session: CyberPhysicalActorSession


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_USABLE_EQUIPMENT: " + message)


func step() -> void:
	session.advance(DT)
	session.bridge.step()
	session.complete_step()


func equip_action(extra: Dictionary = {}, actor: int = 0) -> Dictionary:
	var value: Dictionary = {"usable_index": session.observation(actor).equipment.usable_index}
	value.merge(extra, true)
	return {"equipment": value}


func receipt(request: Dictionary, accepted: bool = true) -> Dictionary:
	var value: Dictionary = request.duplicate(true)
	value.merge({"accepted": accepted, "consumed": true, "reason": "launched" if accepted else "cooldown",
		"changed_cells": 0, "charge": 97.5, "cooldown": 0.14}, true)
	return value


func feedback(value: Dictionary) -> Dictionary:
	return {"run_id": session.run_id, "epoch": session.epoch, "receipts": [value]}


func velocity(body: RigidBody2D) -> Vector2:
	return PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "real Rapier is required")
	if failures:
		quit(1)
		return
	for id: StringName in Catalog.RIG_IDS:
		var base: Dictionary = Catalog.entry(id)
		var retained: Dictionary = base.duplicate(true)
		var prepared: Dictionary = Equipment.definition(base, Loadouts.entry(id))
		expect(not prepared.is_empty() and Rig.validate_definition(prepared).is_empty(), "%s has a connected physical equipment body" % id)
		expect(prepared.parts.size() <= 8 and prepared.mounts[0].held_part < prepared.parts.size(), "%s counts held equipment inside the eight-part budget" % id)
		expect(int(prepared.part_count) == prepared.parts.size() and prepared.body_size == prepared.bounds.size \
			and is_equal_approx(float(prepared.spawn_floor_clearance), float(prepared.bounds.end.y) + 2.0),
			"%s prepared spawn metadata accounts for its actual held body" % id)
		expect(base == retained, "%s base catalogue is immutable" % id)
		var loadout: Dictionary = Loadouts.entry(id)
		expect(int(loadout.usable_index) >= -1 and int(loadout.usable_index) < Usables.count() \
			and not str(loadout.reason).is_empty(), "%s has an explicit loadout policy" % id)
	expect(Usables.count() == 32, "all stable U01-U32 entries remain present")
	for id: StringName in [&"rocketjumper", &"lineshank", &"rocketblade", &"hammerhead", &"heavylift"]:
		expect(Equipment.definition(Catalog.entry(id)).parts.size() == Catalog.entry(id).parts.size(),
			"%s reuses its authored held body" % id)
	var malformed: Array = [
		{"usable_index": 32}, {"usable_index": 1.5}, {"instance_id": ""}, {"equipment_epoch": 0},
		{"equipment_epoch": 1.2}, {"power": NAN}, {"aim": Vector2(INF, 0)}, {"aim": [true, 0]},
		{"trigger": 1}, {"drop": "true"}, {"body_id": 1}, {"mount_id": "invented"}, {"force": Vector2.ONE}]
	var normalized: Dictionary = {"usable_index": 12, "instance_id": "example", "equipment_epoch": 1}
	for changes: Dictionary in malformed:
		var bad: Dictionary = normalized.duplicate(true)
		bad.merge(changes, true)
		expect(Equipment.normalized_action(bad).is_empty(), "strict nested action refuses %s" % str(changes))
	var finite: Dictionary = normalized.duplicate(true)
	finite.merge({"aim": [3, 4], "power": 8.0})
	var normal: Dictionary = Equipment.normalized_action(finite)
	expect(normal.aim.is_equal_approx(Vector2(0.6, 0.8)) and normal.power == 1.0,
		"finite equipment aim and power normalize")
	session = Session.new()
	owner.add_child(session)
	expect(session.configure([
		{"model": &"runner", "producer": &"policy", "position": Vector2(90, 90), "usable_index": 12},
		{"model": &"gyrocrate", "producer": &"policy", "position": Vector2(150, 90), "usable_index": 6}],
		owner.get_world_2d().space, 11), "two real equipped rigs configure")
	if not session.active():
		quit(1)
		return
	for body: RigidBody2D in session.bodies():
		body.gravity_scale = 0.0
	var first: Dictionary = session.observation(0)
	var second: Dictionary = session.observation(1)
	expect(first.equipment.instance_id != second.equipment.instance_id and first.equipment.body_id != second.equipment.body_id,
		"actor slots own unique instances and real body identities")
	var sample: Dictionary = session.equipment_frame()
	var retained_sample: Dictionary = sample.duplicate(true)
	sample.actors[0].parts[0].position = Vector2.ZERO
	expect(session.equipment_frame() == retained_sample, "worker frames are deep copied")
	var command: Dictionary = Session.make_command(first, 0, equip_action({"trigger": true}), 18)
	var stale: Dictionary = command.duplicate(true)
	stale.action.equipment.equipment_epoch += 1
	expect(not session.submit(stale) and session.last_error == "equipment_epoch_or_instance", "stale equipment epoch rejected")
	stale = command.duplicate(true)
	stale.action.equipment.instance_id = second.equipment.instance_id
	expect(not session.submit(stale) and session.last_error == "equipment_epoch_or_instance", "another actor cannot claim this grip")
	expect(session.submit(command), "fresh physical command admitted")
	var held: RigidBody2D = session.bodies()[int(first.equipment.body_id) - 1]
	var before: Vector2 = velocity(held)
	session.advance(DT)
	var requests: Array = session.drain_equipment_requests()
	expect(requests.size() == 1 and requests[0].operation == "use", "one discrete cellular request emitted")
	expect(velocity(held).is_equal_approx(before) and session.drain_effects().is_empty(),
		"queueing a usable has no premature recoil or legacy material duplicate")
	if requests.is_empty():
		quit(1)
		return
	var pending: Dictionary = requests[0]
	var forged: Dictionary = receipt(pending)
	for key: String in ["epoch", "generation", "equipment_epoch", "body_id", "sequence", "usable_index"]:
		var bad: Dictionary = forged.duplicate(true)
		bad[key] = int(bad[key]) + 1
		expect(session.accept_equipment_feedback(feedback(bad)) == 0, "receipt must match %s" % key)
	for key: String in ["run_id", "instance_id", "request_id", "operation"]:
		var bad: Dictionary = forged.duplicate(true)
		bad[key] = "forged"
		expect(session.accept_equipment_feedback(feedback(bad)) == 0, "receipt must match %s" % key)
	var bad_resource: Dictionary = forged.duplicate(true)
	bad_resource.charge = INF
	expect(session.accept_equipment_feedback(feedback(bad_resource)) == 0 and velocity(held) == before,
		"nonfinite resource receipt cannot change physics")
	expect(session.accept_equipment_feedback(feedback(receipt(pending, false))) == 1,
		"worker refusal consumes the pending token explicitly")
	expect(velocity(held).is_equal_approx(before) and not session.observation(0).equipment.pending,
		"refusal clears pending work with no recoil")
	expect(session.submit_local(0, equip_action(), &"policy", 18), "release re-arms projectile press")
	for index: int in range(10):
		step()
	expect(session.submit_local(0, equip_action({"trigger": true}), &"policy", 18), "next projectile press admitted")
	session.advance(DT)
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1, "cooldown eventually permits a new token")
	if requests.is_empty():
		quit(1)
		return
	var success: Dictionary = receipt(requests[0])
	before = velocity(held)
	expect(session.accept_equipment_feedback(feedback(success)) == 1, "matching successful worker receipt consumed")
	var after: Vector2 = velocity(held)
	var item: Dictionary = session.observation(0).equipment
	expect((after - before).dot(item.aim_direction) < -1.0 and item.last_recoil.length() > 0.0,
		"accepted firing applies bounded reaction to the actual held Rapier body")
	expect(session.accept_equipment_feedback(feedback(success)) == 0 and velocity(held) == after,
		"replayed success cannot apply recoil twice")
	var root_body: RigidBody2D = session.bodies()[0]
	var root_before: Vector2 = velocity(root_body)
	session.bridge.step()
	session.complete_step()
	expect(velocity(root_body).distance_to(root_before) > 0.01,
		"real grip constraint transfers the held-body reaction to the actor")
	# Cancellation retires queued work and capabilities without modifying any
	# body's momentum, including the recently fired item.
	var retained_view: Dictionary = session.observation(0)
	var states: Array = []
	for body: RigidBody2D in session.bodies():
		states.append([velocity(body), PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)])
	expect(session.cancel_input(0, session.epoch, &"policy"), "input cancellation accepted")
	for index: int in range(session.bodies().size()):
		var body: RigidBody2D = session.bodies()[index]
		expect(velocity(body) == states[index][0] and PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY) == states[index][1],
			"cancellation preserves body %d momentum" % index)
	expect(not session.submit(Session.make_command(retained_view, int(retained_view.last_sequence) + 1, equip_action({"trigger": true}))),
		"late copied observation cannot resurrect equipment input")
	# Selecting a different usable requires a neutral input before a new rise.
	expect(session.submit_local(0, equip_action({"usable_index": 13, "trigger": true}), &"policy", 18), "held-only retool request admitted")
	step()
	var selected: Dictionary = session.observation(0)
	expect(selected.equipment.usable_index == 13 and selected.equipment.equipment_epoch > first.equipment.equipment_epoch \
		and not selected.equipment.ready and session.drain_equipment_requests().is_empty(),
		"selection advances equipment epoch and held trigger cannot fire the new item")
	expect(not session.submit(Session.make_command(first, 100, {"equipment": {"trigger": true}}, 18)),
		"old copied equipment cannot re-equip its previous selection")
	# A separate equipment aim steers the actual joint without changing the
	# locomotion/ability aim or instantly redirecting the published barrel.
	var aim_before: Vector2 = session.observation(1).equipment.aim_direction
	var steering: Dictionary = {"aim": Vector2.UP, "effort": 0.0,
		"equipment": {"usable_index": 6, "aim": Vector2.LEFT}}
	expect(session.submit_local(1, steering, &"policy", 18), "independent equipment aim admitted")
	session.advance(DT)
	expect(session.observation(1).equipment.aim_direction.is_equal_approx(aim_before) \
		and session._rigs[1].observation().action.aim == Vector2.UP,
		"a new target does not teleport the physical aim or retarget movement")
	for index: int in range(90):
		if index % 6 == 0:
			session.submit_local(1, steering, &"policy", 18)
		step()
	var aimed: Dictionary = session.observation(1)
	var mount_joint: Dictionary = {}
	for joint: Dictionary in aimed.joints:
		if joint.id == "equipment_grip":
			mount_joint = joint
	print("PHYSICAL_USABLE_AIM_METRICS ", {"joint": mount_joint, "limits": aimed.equipment.aim_limits,
		"body_aim": aimed.equipment.aim_direction, "requested": aimed.equipment.requested_aim})
	expect(not mount_joint.is_empty() and absf(float(mount_joint.angle)) > 2.2 \
		and float(mount_joint.angle) >= float(aimed.equipment.aim_limits.x) - 0.1 \
		and float(mount_joint.angle) <= float(aimed.equipment.aim_limits.y) + 0.1,
		"real mount motor aims within its physical limits with zero locomotion effort")
	# A queued request cannot return at the lease boundary after its copied
	# observation's authority has expired, even before the next cancel sweep.
	session.submit_local(0, equip_action(), &"policy", 18)
	step()
	expect(session.submit_local(0, equip_action({"trigger": true}), &"policy", 1), "one-tick firing lease admitted")
	session.advance(DT)
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1, "leased command queues exactly one request")
	if not requests.is_empty():
		var expired_success: Dictionary = receipt(requests[0])
		session.bridge.step()
		session.complete_step()
		before = velocity(held)
		expect(session.accept_equipment_feedback(feedback(expired_success)) == 0 and velocity(held) == before,
			"receipt at the exact expired lease boundary cannot apply recoil")
		step()
		expect(not session.observation(0).equipment.pending and session.drain_equipment_requests().is_empty(),
			"expiry discards the pending equipment token without a delayed shot")
	# An alternate addresses a committed payload rather than paying another
	# launch cost. A copied resource readback can report an empty launch reserve
	# and active cooldown without disabling the independent activation button.
	expect(session.submit_local(0, equip_action({"usable_index": 15}), &"policy", 18),
		"held slot selects the timer payload for alternate admission")
	step()
	var resource_row: Dictionary = session.equipment_frame().actors[0].duplicate(true)
	resource_row.merge({"run_id": session.run_id, "epoch": session.epoch, "charge": 0.0, "cooldown": 2.0}, true)
	var resources: Dictionary = {"run_id": session.run_id, "epoch": session.epoch, "tick": session.tick,
		"receipts": [], "actors": [resource_row], "projectiles": [{"owner": 0, "usable_index": 15,
			"entity_id": 1, "state": "flight", "age": 0.7}], "objects": []}
	session.accept_equipment_feedback(resources)
	expect(not session.observation(0).equipment.ready and session.observation(0).equipment.charge == 0.0 \
		and session.observation(0).equipment.projectiles.size() == 1,
		"copied resources can block a new launch while retaining an owned payload")
	expect(session.submit_local(0, equip_action({"alternate": true, "power": 0.0}), &"policy", 18),
		"zero-power alternate command enters the same issued-observation envelope")
	session.advance(DT)
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1 and requests[0].operation == "alternate" and requests[0].power == 0.0,
		"existing-payload activation reaches native admission despite launch cooldown and empty charge")
	if not requests.is_empty():
		var activation: Dictionary = receipt(requests[0])
		activation.merge({"reason": "activated", "charge": 0.0, "cooldown": 1.9}, true)
		before = velocity(held)
		expect(session.accept_equipment_feedback(feedback(activation)) == 1 \
			and velocity(held) == before and session.observation(0).equipment.last_recoil == Vector2.ZERO,
			"accepted activation consumes its token without another launch recoil")
	var snapshot: Dictionary = session.snapshot()
	var saved_snapshot: Dictionary = snapshot.duplicate(true)
	session.close()
	expect(snapshot == saved_snapshot and not session.active() and session.bodies().is_empty(),
		"reset retires bodies without mutating retained observations")
	expect(session.accept_equipment_feedback(feedback(success)) == 0, "closed owner rejects a late accepted receipt")
	session.free()
	owner.free()
	await process_frame
	print("Physical usable equipment: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
