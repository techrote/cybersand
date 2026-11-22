extends SceneTree

# Exact production Workbench coupling, real cells/Rapier and ACT-005 effects.
# This synchronous qualification fixture does not claim desktop playfeel.
const Session = preload("res://scripts/physical_actor_session.gd")
const Registry = preload("res://scripts/workbench_actor_catalog.gd")
const Capacity = preload("res://scripts/workbench_sandbox_capacity.gd")
const Usables = preload("res://scripts/physical_usable_runtime.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const DT := 1.0 / 60.0
var checks := 0
var failures := 0
var native_bridge: Variant
var checked: Dictionary
var world: Variant
var owner: Node2D
var session
var runtime = Usables.new()


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("WB_COMPOSE_NATIVE: " + label)


func definition(model: String, instance: int, source: String, position: Vector2) -> Dictionary:
	var control := Registry.default_control(model)
	control.source = source
	return {"model":model, "instance_id":instance, "position":position,
		"producer":Registry.producer_for(source), "usable_index":control.usable_index,
		"canvas_extent":Vector2i(512,256), "workbench_control":control,
		"workbench_options":{"response":"LA-SELECTIVE", "budget":20.0,
			"mass_multiplier":1.0, "inertia_multiplier":1.0,
			"thrust_multiplier":1.0, "torque_multiplier":1.0, "boost_multiplier":2.0}}


func prepare(sample: Dictionary, generic: PackedFloat32Array, rects: PackedInt32Array) -> int:
	return native_bridge.prepare_liquid_world(world, rects, checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics), PackedInt32Array(),
		native_bridge.default_liquid_policy(), {"workbench_extent":Vector2i(512,256),
			"workbench_response":"LA-SELECTIVE", "workbench_sample":sample,
			"region":PackedInt32Array([0,0,512,256]), "intent":"exploratory",
			"definition_hash":checked.hash, "initial_bodies":generic, "workbench_worker_threads":1})


func capacity() -> void:
	for count: int in [64,65,Capacity.MAX_BODIES,Capacity.MAX_BODIES+1]:
		var sample := {"session":99, "epoch":99, "states":PackedFloat64Array(),
			"geometry":PackedFloat64Array(), "bodies":[]}
		var generic := PackedFloat32Array()
		for index: int in count:
			# All records, including the over-capacity adversary, have valid
			# geometry inside the canvas. Refusal must be a resource boundary,
			# not an accidental out-of-bounds placement at high population.
			var position := Vector2(2 + (index % 128) * 4, 2 + (index / 128) * 4)
			sample.states.append_array(PackedFloat64Array([index+1,position.x,position.y,0,4,4,0,0,0,1,1,2.6666667,position.x,position.y,0.4,DT,99]))
			sample.geometry.append_array(PackedFloat64Array([0,0,4,4]))
			sample.bodies.append({"id":index+1,"instance_id":9000+index,"generation":99,
				"first_proxy":index+1,"count":1,"budget":20.0,"gravity":92.0,"external_drive":false})
			generic.append_array(PackedFloat32Array([index+1,position.x,position.y,0,4,4,0,0,0,1,1]))
		var old_revision: int = world.get_revision()
		var old_result: Dictionary = world.workbench_coupling_results()
		var token: int = prepare(sample,generic,PackedInt32Array([0,200,512,8,1]))
		var admitted := count <= Capacity.MAX_BODIES
		check(token > 0 if admitted else token == 0, "%d real body owners/masks explicitly %s" % [count,"admitted" if admitted else "refused"])
		check(world.get_revision() == old_revision, "preparation preserves prior live World")
		check(world.workbench_coupling_results() == old_result, "preparation preserves prior native registration map")
		if token > 0:
			if admitted:
				check(native_bridge.commit_liquid_world(world,token),"%d native owners commit" % count)
				var result: Dictionary = world.workbench_coupling_results()
				check(int(result.body_limit)==Capacity.MAX_BODIES,"native reports its configured response ceiling")
				check(int(result.active_bodies)==count,"%d actual native response owners registered" % count)
				check(int(result.active_proxies)==count,"%d actual native occupancy proxies registered" % count)
				check(world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true),
					"%d registered owners accept live native response calculation" % count)
				check(world.workbench_coupling_results().rows.size()==count,"%d owners retain distinct native response rows" % count)
			else:
				native_bridge.discard_liquid_world(world,token)


func sleeping_equipment_publication() -> void:
	# A sleeping body can be absent from Rapier's active-body batch. Deliberately
	# retain an older presentation cache while the actual RID and copied rig
	# observation agree, then demand one coherent native/equipment publication.
	var actor_slot := 1
	var rig = session._rigs[actor_slot]
	var mount: Dictionary = rig.equipment_mount_state()
	var body_index: int = session.bridge.actor_body_index(actor_slot) + int(mount.held_part)
	var body: RigidBody2D = session.bodies()[body_index]
	var rid: RID = body.get_rid()
	var actual: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var sleeping: bool = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_SLEEPING)
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_SLEEPING,true)
	check(PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_SLEEPING),
		"equipment adversary uses an actual sleeping Rapier body")
	var stale := Transform2D(actual.get_rotation()+0.2,actual.origin+Vector2(-8,4))
	session.bridge._transforms[body_index] = stale
	rig.refresh_observation()
	var sample: Dictionary = session.pack_workbench_sample()
	check(Usables.frame_error(sample.equipment_frame).is_empty(),
		"sleeping equipment ignores stale bridge cache without weakening mount validation")
	var row: Dictionary = Usables.actor_row(sample.equipment_frame,actor_slot)
	var published: Dictionary = {}
	for part: Dictionary in row.parts:
		if int(part.body_id) == int(row.body_id): published = part
	check(not published.is_empty() and Vector2(published.position) == actual.origin \
		and float(published.rotation) == actual.get_rotation(),
		"ACT005 mounted part uses the actual current RID pose")
	var native_pose := Vector2.ZERO
	var native_rotation := 0.0
	for offset: int in range(0,sample.states.size(),17):
		if int(sample.states[offset]) == int(row.body_id):
			native_pose = Vector2(sample.states[offset+1],sample.states[offset+2])
			native_rotation = float(sample.states[offset+3])
	check(Vector2(row.position) == native_pose and float(row.rotation) == native_rotation,
		"native occupancy and physical tool mount describe the same sleeping body")
	check(world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,false),
		"coherent sleeping equipment sample passes real native mask admission")
	var forged: Dictionary = sample.equipment_frame.duplicate(true)
	Usables.actor_row(forged,actor_slot).position += Vector2(3,0)
	check(Usables.frame_error(forged) == "mount_pose",
		"mismatched equipment geometry remains refused after cache repair")
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_SLEEPING,sleeping)
	session.bridge._transforms[body_index] = actual


func run() -> void:
	check(ClassDB.class_exists("CyberDemoBridge") and ClassDB.class_exists("RapierPhysicsServer2D"), "real native and Rapier extensions")
	if failures: quit(1); return
	checked = Contract.validate(Contract.parse(FileAccess.get_file_as_string("res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json")).definition)
	native_bridge = ClassDB.instantiate(&"CyberDemoBridge")
	world = ClassDB.instantiate(&"CyberNativeCellWorld")
	capacity()
	owner = Node2D.new()
	root.add_child(owner)
	session = Session.new()
	owner.add_child(session)
	var roster: Array = [definition("scooper",101,"human",Vector2(65,145)),
		definition("runner",202,"scripted",Vector2(150,170)),
		definition("crawler",303,"scripted",Vector2(240,170)),
		definition("copter",404,"scripted",Vector2(330,125)),
		definition("4ly_trainer",505,"policy",Vector2(415,125)),
		definition("reference_barrel",606,"passive",Vector2(465,180))]
	check(session.configure(roster,owner.get_world_2d().space,11), "mixed real Workbench session configured")
	if not session.active(): quit(1); return
	var sample: Dictionary = session.pack_workbench_sample()
	var token := prepare(sample,session.bridge.pack_body_states(),PackedInt32Array([
		0,200,512,8,1, 115,190,4,10,1, 180,186,7,14,1,
		210,195,50,5,2, 275,182,6,18,1]))
	check(token > 0 and native_bridge.commit_liquid_world(world,token), "native accepts actual heterogeneous prepared body map")
	if token <= 0: quit(1); return
	check(sample.bodies.size() > 8 and int(world.workbench_coupling_results().body_limit) == Capacity.MAX_BODIES,
		"native owns every part beyond historical eight-body ceiling")
	check(int(world.workbench_coupling_results().active_bodies)==sample.bodies.size(),
		"native response owner count matches real heterogeneous bodies")
	check(int(world.workbench_coupling_results().active_proxies)==sample.states.size()/17,
		"native proxy count matches real heterogeneous occupancy geometry")
	check(session.bridge.queue_hard_surface_chunk_snapshot(world.get_hard_surface_chunk_rectangles()), "actual native cell terrain enters Rapier bridge")
	session.bridge.process_hard_surface_collider_budget(256,0)
	check(session.bridge.hard_surface_shape_count() > 0, "cell floor has real Rapier contacts")
	sleeping_equipment_publication()
	var begin: Array = session.snapshot().actors.map(func(actor: Dictionary): return actor.position)
	var moved: Array[float] = [0.0,0.0,0.0,0.0,0.0,0.0]
	var contacted := false
	var writes := 0
	var accepted := 0
	var rejected := 0
	var terrain_revision: int = world.get_hard_surface_revision()
	var reactive_start := Vector2.ZERO
	for tick: int in 300:
		if tick == 240:
			reactive_start = session.observation(1).position
			var policy_control: Dictionary = roster[1].workbench_control.duplicate(true)
			policy_control.source = "policy"
			policy_control.policy = "fixture"
			check(session.set_workbench_control(202,policy_control),"ground actor admits bounded Thunderbowl policy fixture through live takeover")
		if tick % 6 == 0:
			session.submit_workbench_action(101,{"move":Vector2(0,-0.35),"auxiliary":true,"effort":1.0},
				{"q":false,"e":false,"s":false,"boost":false},false)
		session.advance(DT)
		sample = session.pack_workbench_sample()
		if not world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true):
			check(false,"live multipart native sample refused at tick %d" % tick)
			break
		var effects: Dictionary = runtime.step(DT,world,sample.equipment_frame,sample.equipment_requests)
		check(str(effects.get("last_error","" )).is_empty(),"ACT005 copied frame and matching mask accepted")
		writes += int(effects.get("write_count_last",0))
		for request: Dictionary in sample.equipment_requests:
			for receipt: Dictionary in effects.get("receipts",[]):
				if request.request_id == receipt.get("request_id"):
					accepted += int(receipt.get("accepted",false))
					rejected += int(not bool(receipt.get("accepted",false)))
		session.accept_equipment_feedback(effects)
		if not world.simulation_tick():
			check(false,"native progression failed")
			break
		session.apply_workbench_results(tick+1,world.workbench_coupling_results())
		if world.get_hard_surface_revision() != terrain_revision:
			session.bridge.queue_hard_surface_chunk_snapshot(world.get_hard_surface_chunk_rectangles())
			session.bridge.process_hard_surface_collider_budget(256,0)
			terrain_revision = world.get_hard_surface_revision()
		session.bridge.step()
		session.complete_step()
		var actors: Array = session.snapshot().actors
		for index: int in actors.size():
			moved[index] = maxf(moved[index],Vector2(actors[index].position).distance_to(begin[index]))
			if index in [1,2]: contacted = contacted or bool(actors[index].grounded)
	check(session.tick == 300 and world.get_tick_index() == 300, "Rapier and native progression both complete 300 coupled steps")
	check(contacted, "ground NPC observes actual native-terrain contact")
	check(moved[1] > 3.0 and moved[2] > 3.0 and moved[3] > 3.0 and moved[4] > 3.0,
		"mechanical, crawler, flight and external fixture physically travel")
	check(accepted > 0 and writes > 0, "scripted physical equipment visibly changes legitimate material cells")
	check(session.workbench_control(202).diagnostics.get("reactive",{}).get("decisions",0) >= 10,
		"compatible external fixture actually runs reused Thunderbowl wire decisions")
	check(Vector2(session.observation(1).position).distance_to(reactive_start) > 1.0 \
		and not session.observation(1).action.is_empty(),"physical wire adapter commands are consumed by real coupled ground motion")
	print("WB_COMPOSE_NATIVE_METRICS ",JSON.stringify({"actors":roster.size(),"bodies":sample.bodies.size(),
		"masks":sample.states.size()/17,"ticks":session.tick,"travel":moved,
		"equipment_accepted":accepted,"equipment_refused":rejected,"material_writes":writes}))
	session.close()
	session.free()
	owner.free()
	print("Workbench actor composition native: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
