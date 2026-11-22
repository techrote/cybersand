extends SceneTree

# Real patched Rapier, actual composed rigs, joints, control leases and proxy
# packing. No substitute body or mocked physics server participates in this test.
const Session = preload("res://scripts/physical_actor_session.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Manipulator = preload("res://scripts/workbench_actor_manipulator.gd")
const DT := 1.0 / 60.0
var checks := 0
var failures: Array[String] = []
var host: Node2D
var session: CyberPhysicalActorSession
var measurements: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("WB_ACTOR_MANIPULATION: " + label)
	return value


func actor(model: String, identity: int, position: Vector2, source: String = "passive", rotation: float = 0.0) -> Dictionary:
	var control: Dictionary = Catalog.default_control(model)
	control.source = source
	return {"model":model, "instance_id":identity, "position":position,
		"canvas_extent":Vector2i(1024,1024), "producer":Catalog.producer_for(source),
		"usable_index":control.usable_index, "workbench_control":control,
		"spawn_rotation":rotation, "workbench_options":{"response":"LA-SELECTIVE",
			"budget":20.0, "mass_multiplier":1.0, "inertia_multiplier":1.0}}


func create(definitions: Array, epoch_value: int) -> bool:
	if session != null:
		session.close()
		session.free()
	session = Session.new()
	host.add_child(session)
	return check(session.configure(definitions, host.get_world_2d().space, epoch_value), "real session configuration: " + session.last_error)


func step(count: int = 1) -> void:
	for index: int in range(count):
		session.advance(DT)
		session.bridge.step()
		session.complete_step()


func pose(body: RigidBody2D) -> Transform2D:
	return PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)


func velocity(body: RigidBody2D) -> Vector2:
	return PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)


func bounded_joint_error(rig: CyberPhysicalActorRig, limit: float) -> bool:
	var parts: Array = rig.bodies()
	for joint: Dictionary in rig._joints:
		if not bool(joint.enabled) or str(joint.type) != "rotary": continue
		var a: Vector2 = pose(parts[int(joint.a)]) * Vector2(joint.anchor_a_local)
		var b: Vector2 = pose(parts[int(joint.b)]) * Vector2(joint.anchor_b_local)
		if not a.is_finite() or not b.is_finite() or a.distance_to(b) > limit: return false
	return true


func run() -> void:
	host = Node2D.new()
	root.add_child(host)
	var ground := StaticBody2D.new()
	ground.position = Vector2(512,500)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1024,20)
	collider.shape = shape
	ground.add_child(collider)
	host.add_child(ground)
	if not create([actor("reference_barrel",101,Vector2(90,180)),
		actor("runner",202,Vector2(260,170),"scripted"),
		actor("reference_barrel",303,Vector2(420,180))],11):
		finish()
		return
	var grab = session.manipulator()
	check(not grab.active(), "new session has no temporary grab")
	var original_settings: Dictionary = grab.settings()
	check(not grab.configure_settings({"stiffness":NAN,"damping":24.0,"max_force":24000.0}) \
		and grab.settings() == original_settings, "nonfinite settings refuse atomically")
	check(not grab.configure_settings({"stiffness":160.0,"damping":-1.0,"max_force":24000.0}), "negative damping refuses")
	check(not grab.configure_settings({"stiffness":160.0,"damping":24.0,"max_force":24000.0,"extra":true}), "unknown settings refuse")
	var barrel: RigidBody2D = session._rigs[0].bodies()[0]
	var body_identity := barrel.get_instance_id()
	var initial := pose(barrel)
	var other_generation: int = session._generations[1]
	var started: Dictionary = grab.begin_grab(initial.origin + Vector2(1,-2))
	check(started.get("active",false) and int(started.instance_id) == 101, "precise barrel pick claims actual body")
	check(session._generations[1] == other_generation and session._definitions[1].producer == "demo", "grab does not take over unrelated NPC")
	check(grab.update_target(initial.origin + Vector2(65,-65)), "moving target admitted")
	var max_force := 0.0
	for tick: int in range(120):
		step()
		var state: Dictionary = grab.state()
		max_force = maxf(max_force, Vector2(state.force).length())
		if tick == 0:
			var sample: Dictionary = session.pack_workbench_sample()
			check(sample.bodies.size() == 8 and bool(sample.bodies[0].external_drive), "real body sample marks grabbed response owner driven")
	var moved := pose(barrel)
	check(moved.origin.x > initial.origin.x + 40.0 and moved.origin.y < initial.origin.y - 20.0, "physical spring lifts and pulls barrel")
	check(absf(moved.get_rotation()) > 0.01, "off-centre grab creates real angular motion")
	check(max_force > 0.0 and max_force <= float(original_settings.max_force) + 0.1, "measured force is nonzero and bounded")
	check(session.tick == 120 and session._decision_total_usec[1] > 0, "Rapier and independent scripted decisions continue during grab")
	check(barrel.get_instance_id() == body_identity and not barrel.freeze, "grabbing preserves live colliding body identity")
	var before_release := pose(barrel)
	var release_velocity := velocity(barrel)
	grab.end_grab("released")
	check(not grab.active() and pose(barrel) == before_release and velocity(barrel) == release_velocity, "release preserves exact current pose and momentum")
	step(5)
	check(pose(barrel).origin.distance_to(before_release.origin) > 0.01, "released body continues real dynamics")
	measurements["barrel"] = {"initial":initial.origin, "held":moved.origin,
		"angle":moved.get_rotation(), "max_force":max_force, "rapier_ticks":session.tick}

	# An actual limb pulls its chassis through the existing rotary constraints.
	if not create([actor("runner",202,Vector2(240,200),"scripted"),
		actor("reference_barrel",303,Vector2(600,180))],12):
		finish()
		return
	grab = session.manipulator()
	var rig: CyberPhysicalActorRig = session._rigs[0]
	var limb: RigidBody2D = rig.bodies()[1]
	var snapshot: Dictionary = grab.capture_actor(202)
	var stale_view: Dictionary = session.observation(0)
	var stale_command := Session.make_command(stale_view,1,{"move":Vector2.RIGHT},12)
	var hit: Dictionary = grab.begin_grab(pose(limb).origin)
	check(int(hit.get("part_index",-1)) == 1 and hit.get("active",false), "pick a specific articulated limb")
	check(not session.submit(stale_command,&"demo") and session.last_error == "actor_physically_grabbed", "drive command refuses while grabbed")
	var joint_count := rig.physical_joint_count()
	var original_root := pose(rig.bodies()[0]).origin
	grab.configure_settings({"stiffness":480.0,"damping":45.0,"max_force":24000.0})
	grab.update_target(pose(limb).origin + Vector2(80,-30))
	var connection_ok := true
	for tick: int in range(120):
		step()
		connection_ok = connection_ok and bounded_joint_error(rig,6.0)
	check(connection_ok and rig.physical_joint_count() == joint_count, "drag retains and physically constrains actual joints")
	check(pose(rig.bodies()[0]).origin.x > original_root.x + 15.0, "limb pull propagates to the connected chassis")
	check(session._decision_total_usec[0] == 0 and rig._action.is_empty(), "only grabbed controller and motors are suppressed")
	check(session.workbench_control(202).status == "physically grabbed", "inspection reports temporary manipulation without source change")
	grab.end_grab("released")
	check(not session.submit(stale_command,&"demo"), "pre-grab observation cannot resume stale controller authority")
	step(8)
	check(session._decision_total_usec[0] > 0 and session._definitions[0].producer == "demo", "scripted controller resumes after fresh lease")

	# A value-only preview rotates the current bent pose, not just its drawing.
	session.set_suspended(true)
	snapshot = grab.capture_actor(202)
	var before_parts: Array = snapshot.parts.duplicate(true)
	var preview := Manipulator.placement_preview(snapshot,Vector2(430,260),float(snapshot.rotation)+PI*0.5)
	check(bool(preview.get("valid",false)) and preview.parts.size() == before_parts.size(), "whole-assembly rotated preview is in bounds")
	var rigid_transform_ok := true
	for index: int in range(before_parts.size()):
		var expected: Vector2 = Vector2(430,260) + (Vector2(before_parts[index].position)-Vector2(snapshot.position)).rotated(PI*0.5)
		rigid_transform_ok = rigid_transform_ok and Vector2(preview.parts[index].position).distance_to(expected) < 0.001
	check(rigid_transform_ok and grab.capture_actor(202).parts == before_parts, "preview preserves all relative part transforms without mutating bodies")
	check(not bool(Manipulator.placement_preview(snapshot,Vector2.ZERO,0.0).get("valid",true)), "out-of-bounds complete assembly refuses")
	check(grab.begin_grab(Vector2(before_parts[1].position)).is_empty(), "paused session refuses live force grabbing")
	session.set_suspended(false)
	grab.begin_grab(pose(limb).origin)
	session.set_suspended(true)
	check(not grab.active() and session._manipulated_actor == -1, "pause retires temporary body reference and authority")
	session.set_suspended(false)
	for index: int in range(12):
		grab.begin_grab(pose(limb).origin)
		grab.end_grab("rapid_release")
	check(rig.physical_joint_count() == joint_count and rig.bodies().size() == before_parts.size(), "repeated grabs allocate no bodies or joints")
	grab.begin_grab(pose(limb).origin)
	session.cancel_input(0,session.epoch,&"demo")
	check(not grab.active(), "external actor input cancellation retires grab")
	grab.begin_grab(pose(limb).origin)
	check(not grab.update_target(Vector2(NAN,0)) and not grab.active(), "nonfinite target cancels safely")
	grab.begin_grab(pose(limb).origin)
	session.close()
	grab.advance(DT)
	check(not grab.active(), "teardown invalidates selected body before later advance")
	measurements["articulated"] = {"parts":before_parts.size(),"joints":joint_count,"connection_ok":connection_ok}
	var placed := actor("runner",202,preview.position,"passive",preview.rotation)
	placed["retained_parts"] = preview.parts.duplicate(true)
	if create([placed],19):
		var installed_parts: Array = session.capture_workbench_assembly(202).parts
		var retained_pose_ok: bool = installed_parts.size() == preview.parts.size()
		var angle_error := 0.0
		for index: int in range(installed_parts.size()):
			var actual: Dictionary = installed_parts[index]
			var expected: Dictionary = preview.parts[index]
			# Transform2D/Rapier stores float32 geometry; the preview's radians
			# are GDScript float64. Preserve positions exactly and admit only the
			# measured sub-microradian rotation roundtrip, never pose drift.
			angle_error = maxf(angle_error,absf(wrapf(float(actual.rotation)-float(expected.rotation),-PI,PI)))
			retained_pose_ok = retained_pose_ok and actual.position == expected.position \
				and actual.linear_velocity == expected.linear_velocity and actual.angular_velocity == expected.angular_velocity
		measurements["rotation_roundtrip_max_radians"] = angle_error
		check(retained_pose_ok and angle_error <= 0.000001,
			"prepared replacement installs the complete rotated bent pose")
		step(12)
		check(bounded_joint_error(session._rigs[0],2.0), "retained bent pose preserves real local joint anchors after rotation")

	# Rotated creation includes real spring/groove axes and the occupancy sample.
	for model: String in ["runner","springjack","stuntbuggy"]:
		var angle := PI*0.5
		if not create([actor(model,401,Vector2(500,200),"passive",angle)],20): continue
		var definition: Dictionary = Catalog.definition(model)
		var created: Array = session._rigs[0].bodies()
		var geometry_ok := true
		for index: int in range(created.size()):
			var actual := pose(created[index])
			var expected := Vector2(500,200)+Vector2(definition.parts[index].offset).rotated(angle)
			geometry_ok = geometry_ok and actual.origin.distance_to(expected) < 0.001 \
				and absf(wrapf(actual.get_rotation()-float(definition.parts[index].get("angle",0.0))-angle,-PI,PI)) < 0.001
		check(geometry_ok, "authored rotation transforms every actual part: " + model)
		var sample: Dictionary = session.pack_workbench_sample()
		check(not sample.is_empty() and sample.states.size() == Catalog.proxy_count(model)*17, "rotated actual proxy sample: " + model)
		var proxy_geometry_ok := true
		for index: int in range(created.size()):
			var actual := pose(created[index])
			var offset := index*17
			proxy_geometry_ok = proxy_geometry_ok and Vector2(sample.states[offset+1],sample.states[offset+2]).distance_to(actual.origin) < 0.001 \
				and absf(wrapf(float(sample.states[offset+3])-actual.get_rotation(),-PI,PI)) < 0.001
		check(proxy_geometry_ok, "occupancy positions and angles match the actual rotated bodies: " + model)
		step(12)
		check(bounded_joint_error(session._rigs[0],2.0) and str(session._rigs[0].fault).is_empty(), "rotated graph remains connected during actual steps: " + model)
	if create([actor("runner",501,Vector2(500,200))],21):
		var equipped: CyberPhysicalActorRig = session._rigs[0]
		var live_snapshot: Dictionary = session.capture_workbench_assembly(501)
		check(str(live_snapshot.pose_error).is_empty(), "ordinary connected equipment supports pose retention")
		check(equipped.release_usable(), "real equipment release clears its physical joint")
		live_snapshot = session.capture_workbench_assembly(501)
		check(not str(live_snapshot.pose_error).is_empty() \
			and not bool(Manipulator.placement_preview(live_snapshot,Vector2(550,220),0.0).valid),
			"released equipment explicitly refuses unsafe retained-pose reconstruction")
		var held := int(equipped.equipment_mount_state().held_part)
		var released: RigidBody2D = equipped.bodies()[held]
		check(equipped.fix_usable(), "real fixed equipment freezes its existing body")
		var fixed_hit := {"run_id":session.run_id,"epoch":session.epoch,"instance_id":501,
			"actor_slot":0,"part_index":held,"body_identity":released.get_instance_id()}
		check(session.workbench_grab_body(fixed_hit) == null, "fixed equipment refuses force grabbing without silently unfreezing it")
	wheel_grab()
	finish()


func wheel_grab() -> void:
	# Matched ungrabbed controls distinguish the spring's physical consequences
	# from ordinary gravity and the articulated vehicle's passive suspension.
	for model: String in ["stuntbuggy","trialsbike"]:
		var definitions: Array = [actor(model,601,Vector2(500,180))]
		if not create(definitions,31): continue
		step(60)
		var control_chassis := pose(session._rigs[0].bodies()[0])
		if not create(definitions,32): continue
		var rig: CyberPhysicalActorRig = session._rigs[0]
		var wheel_index := -1
		for index: int in range(rig._part_defs.size()):
			if str(rig._part_defs[index].id) == "wheel_1": wheel_index = index
		if not check(wheel_index>=0,"actual front wheel exists: "+model): continue
		var wheel: RigidBody2D = rig.bodies()[wheel_index]
		var chassis: RigidBody2D = rig.bodies()[0]
		var body_ids: Array = []
		for body: RigidBody2D in rig.bodies(): body_ids.append(body.get_instance_id())
		var joint_count := rig.physical_joint_count()
		var grab = session.manipulator()
		var point := pose(wheel).origin+Vector2(2.0,1.5)
		var hit: Dictionary = grab.begin_grab(point)
		check(hit.get("active",false) and int(hit.get("part_index",-1))==wheel_index \
			and str(hit.get("part_id",""))=="wheel_1","precise circular wheel is the grabbed body: "+model)
		grab.configure_settings(Manipulator.DEFAULT_SETTINGS)
		grab.update_target(point+Vector2(55,-65))
		var finite := true
		var constrained := true
		var maximum_force := 0.0
		for tick: int in range(60):
			step()
			maximum_force = maxf(maximum_force,Vector2(grab.state().force).length())
			constrained = constrained and bounded_joint_error(rig,6.0)
			for body: RigidBody2D in rig.bodies():
				finite = finite and pose(body).origin.is_finite() and velocity(body).is_finite() \
					and is_finite(pose(body).get_rotation())
		var pulled := pose(chassis)
		var displacement := pulled.origin-control_chassis.origin
		var twist := absf(angle_difference(control_chassis.get_rotation(),pulled.get_rotation()))
		check(displacement.x>15.0 and displacement.y< -15.0,"wheel force translates and lifts its connected chassis beyond the passive control: "+model)
		check(twist>0.1,"one-wheel pull twists the chassis through its real suspension: "+model)
		var retained_ids: Array = []
		for body: RigidBody2D in rig.bodies(): retained_ids.append(body.get_instance_id())
		check(finite and constrained and rig.fault.is_empty() and retained_ids==body_ids \
			and rig.physical_joint_count()==joint_count,"wheel grab retains every finite body and rotary/spring constraint: "+model)
		check(maximum_force>0.0 and maximum_force<=24000.1,"actual wheel force is bounded: "+model)
		var released_pose := pose(chassis)
		var released_velocity := velocity(chassis)
		grab.end_grab("released")
		check(pose(chassis)==released_pose and velocity(chassis)==released_velocity,
			"wheel release preserves chassis pose and momentum: "+model)
		step(12)
		check(not grab.active() and pose(chassis).origin.distance_to(released_pose.origin)>0.01 \
			and rig.physical_joint_count()==joint_count,"released vehicle continues physical motion with its connected graph: "+model)
		measurements[model+"_wheel"] = {"part_index":wheel_index,"part_id":"wheel_1",
			"parts":body_ids.size(),"joints":joint_count,"control_chassis":control_chassis.origin,
			"pulled_chassis":pulled.origin,"relative_displacement":displacement,
			"chassis_twist_radians":twist,"maximum_force":maximum_force,"rapier_ticks":session.tick,
			"finite":finite,"rotary_constraints_bounded":constrained}


func finish() -> void:
	if session != null:
		session.close()
		session.free()
		session = null
	if host != null: host.free()
	print("WB_ACTOR_MANIPULATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements}))
	quit(0 if failures.is_empty() else 1)
