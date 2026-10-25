extends SceneTree

const Borrow = preload("res://scripts/prepared_default_actor_session.gd")
const Held = preload("res://tests/fixtures/lcb/default_actor_held_borrow.gd")
const PhysicalCatalog = preload("res://scripts/physical_actor_catalog.gd")
const ActorCatalog = preload("res://scripts/actor_rig_catalog.gd")
const Physical = preload("res://scripts/prepared_physical_session.gd")
const FinalBarrier = preload("res://tests/fixtures/lcb/desktop_default_commit_barrier.gd")
var assertions: int = 0
var failures: int = 0
var desktop: Control

func _initialize() -> void: _run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures += 1; push_error("LIQUID_DEFAULT_ACTOR_HOST: " + message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if predicate.call(): return true
	return false

func receipt() -> Dictionary:
	return desktop.tower_context.get("liquid_construction_receipt",{}).duplicate(true)

func body_states() -> PackedFloat32Array:
	desktop.rapier_bridge.refresh_all_states()
	return Physical._pose_values(desktop.rapier_bridge.pack_body_states())

func choose(bridge: Variant, family: String, variant: String="reference") -> PackedInt32Array:
	for item: Dictionary in bridge.liquid_policy_assignment_choices(bridge.default_liquid_policy(),3):
		if item.accepted and item.family==family and item.variant==variant: return item.request
	return PackedInt32Array()

func configuration(model: String, physical: bool) -> Dictionary:
	return {"representation":"barrel-rapier" if physical else "sampled",
		"runtime_recovery_enabled":false,"physical_trial":"","physical_rig":model if physical else "",
		"actor_model":"" if physical else model,"actor_producer":"human","actor_demo_npcs":false,
		"actor_definitions":[] if physical else [{"model":StringName(model),"producer":&"human","position":Vector2(150,145)}]}

func _run() -> void:
	root.size=Vector2i(1600,1000)
	var physical_count: int=0
	var physical_models: Array=PhysicalCatalog.RIG_IDS.duplicate()
	physical_models.append_array(PhysicalCatalog.Flight.IDS)
	for model: StringName in physical_models:
		expect(Borrow.valid_single_configuration(configuration(str(model),true)),"registered physical descriptor " + str(model))
		physical_count += 1
	var sampled_count: int=0
	for model: StringName in ActorCatalog.RIG_IDS:
		expect(Borrow.valid_single_configuration(configuration(str(model),false)),"registered sampled descriptor " + str(model))
		sampled_count += 1
	var invalid: Dictionary=configuration("runner",true);invalid.actor_demo_npcs=true
	expect(not Borrow.valid_single_configuration(invalid),"NPC/multiple-owner requests remain explicit refusals")
	invalid=configuration("unknown-actor",true)
	expect(not Borrow.valid_single_configuration(invalid),"unknown physical actor refuses before any owner change")
	invalid=configuration("runner",false);invalid.actor_definitions.append(invalid.actor_definitions[0].duplicate())
	expect(not Borrow.valid_single_configuration(invalid),"multiple sampled definitions do not borrow single-owner admission")
	print("LIQUID_DEFAULT_ACTOR_DESCRIPTORS: ",JSON.stringify({"physical":physical_count,"sampled":sampled_count,"unknown_npc_multiple_refused":true}))
	desktop=load("res://main.tscn").instantiate();desktop.paused=true;root.add_child(desktop)
	if not await wait_for(func() -> bool: return not desktop.tower_context.get("native_default_demo",{}).is_empty()):
		expect(false,"ordinary bootstrap publishes native default origin");_finish();return
	var bridge: Variant=ClassDB.instantiate(&"CyberDemoBridge")
	expect(desktop.liquid_comparison_apply_active(bridge.default_liquid_policy(),false,true,"Inspect",2),"actual Liquids callback prepares initial selected default")
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"initial selected default finishes");_finish();return
	expect(desktop._liquid_default_active and not receipt().is_empty(),"initial selected default installs native receipt")
	expect(desktop.apply_actor_prototype_configuration(&"rapier/skimmer",&"policy",false),"actual accepted-owner F5 stages a registered actor and default equipment")
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"fresh articulated actor reaches actual owner acknowledgement");_finish();return
	if desktop.physical_actor_session==null:
		expect(false,"articulated default actor installed: "+desktop.microscenario_error);_finish();return
	var session: CyberPhysicalActorSession=desktop.physical_actor_session
	var owner: RefCounted=desktop._accepted_physical_candidate
	var physics: CyberRapierPhysicsBridge=desktop.rapier_bridge
	var item: RefCounted=session._equipment[0]
	expect(session.snapshot().actor_count==1 and session.bodies().size()>1 and receipt().initial_body_count==session.bodies().size(),
		"one actual articulated assembly/equipment supplies the complete native initial mask")
	expect(item.observation().usable_id=="water_lance" and item.observation().body_id>0,
		"actual authored loadout is a held physical Water Lance")
	expect(session.input_cancelled.is_connected(desktop._on_physical_actor_input_cancelled),
		"staged fresh owner binds the real Main cancellation callback before native commit")
	# Owner-local test state distinguishes retention from fresh construction.
	# It is not an assertion that a native tool transaction spent this charge.
	item.charge=71.25;item.cooldown=0.75
	for index: int in range(session.bodies().size()):
		var body: RigidBody2D=session.bodies()[index]
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(1.25+index,-0.5))
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,-0.125)
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_SLEEPING,false)
	var captured: PackedFloat32Array=body_states()
	var before_run: String=session.run_id
	var before_epoch: int=session.epoch
	var before_steps: int=physics.manual_step_count()
	var body_ids: Array=[]
	for body: RigidBody2D in session.bodies(): body_ids.append(body.get_instance_id())
	var prior: Dictionary=receipt()
	desktop._prepared_default_actor_factory=Held.make
	expect(desktop.liquid_comparison_apply_active(bridge.default_liquid_policy(),false,true,"Inspect",2),"retained actor Apply begins with a borrowed owner")
	if not await wait_for(func() -> bool: return not desktop.simulation_worker.prepared_physical_liquid_values().is_empty()):
		expect(false,"Native candidate reaches borrowed-owner preparation: "+desktop.microscenario_error);_finish();return
	var borrower: RefCounted=desktop._pending_physical_candidate
	var source_terrain: PackedInt32Array=desktop.simulation_worker.prepared_physical_liquid_values().terrain.duplicate()
	var rearm: bool=desktop._actor_usable_pointer_rearm
	desktop.handle_painting();desktop._publish_actor_usable_buttons(false,false)
	expect(desktop._actor_usable_pointer_rearm==rearm and borrower.pose_unchanged(),
		"pending normal paint/event callbacks preserve the retained owner input-rearm edge")
	await physics_frame;await physics_frame;await process_frame
	expect(session==desktop.physical_actor_session and body_states()==captured and physics.manual_step_count()==before_steps,
		"two real physics frames do not advance or recreate retained bodies")
	borrower.close()
	expect(item.charge==71.25 and item.cooldown==0.75 and session.active() and body_states()==captured,
		"direct borrower disposal leaves exact owner-local equipment test values and body state untouched")
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"disposing a prepared borrower produces bounded refusal");_finish();return
	desktop._prepared_default_actor_factory=Callable()
	expect(desktop.physical_actor_session==session and desktop._accepted_physical_candidate==owner and session.active()
		and item==session._equipment[0]
		and body_states()==captured and receipt().canonical_bytes==prior.canonical_bytes,
		"discarded borrowed helper cannot destroy/reset/mutate the installed graph, equipment, motion or receipt")
	# End the owner-local injection control. Its charge did not spend/refill
	# worker authority. Actual asynchronous accounting starts from the authored
	# 100/0 state shared with the unchanged cellular equipment runtime.
	item.charge=100.0;item.cooldown=0.0
	var actual_charge: float=item.charge
	var actual_cooldown: float=item.cooldown
	expect(desktop.liquid_comparison_apply_active(choose(bridge,"cellular_yield_v1"),true,true,"Inspect",2),
		"explicit normalization and whole-cell selection reaches same-owner Apply")
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"retained single actor Apply completes");_finish();return
	expect(receipt().receipt_hash!=prior.receipt_hash and desktop.physical_actor_session==session
		and desktop._accepted_physical_candidate==owner and desktop.rapier_bridge==physics
		and session.run_id==before_run and session.epoch==before_epoch and body_states()==captured,
		"successful native swap keeps exact live graph/run/epoch/motion and installed owning wrapper")
	expect(item==session._equipment[0] and item.charge==actual_charge and item.cooldown==actual_cooldown,
		"successful Apply retains actual copied equipment accounting and the same item")
	var after_ids: Array=[]
	for body: RigidBody2D in session.bodies(): after_ids.append(body.get_instance_id())
	expect(after_ids==body_ids and borrower.owner_kind()=="retained_default_actor" and session.active(),
		"retired borrower has no destruction authority over the exclusively owned live assembly")
	# Exercise complete terrain equality with the actual native prepared packet.
	# Neither a successful comparison nor a refusal may rebuild a live collider.
	var terrain_before: Array=physics._hard_surface_chunk_rectangles.duplicate(true)
	var equal_terrain: RefCounted=Borrow.new()
	expect(equal_terrain.prepare_retained(physics,session.bodies(),"articulated",before_epoch,desktop._default_actor_source_values)
		and equal_terrain.install_terrain(source_terrain),"actual complete native terrain packet admits exact installed collider equality")
	equal_terrain.close()
	var changed_terrain: RefCounted=Borrow.new()
	expect(changed_terrain.prepare_retained(physics,session.bodies(),"articulated",before_epoch,desktop._default_actor_source_values),
		"terrain mismatch control borrows the actual exclusive owner")
	var altered: PackedInt32Array=source_terrain.duplicate()
	for chunk: int in range(altered[0]):
		if altered[chunk+2]>altered[chunk+1]: altered[altered[chunk+1]]+=1;break
	expect(not changed_terrain.install_terrain(altered) and changed_terrain.last_error.contains("changed hard terrain"),
		"one changed actual collider coordinate refuses the whole comparison")
	changed_terrain.close()
	expect(not changed_terrain.install_terrain(source_terrain) and changed_terrain.last_error.contains("closed"),
		"a disposed borrower refuses subsequent API use without touching dead references")
	expect(physics._hard_surface_chunk_rectangles==terrain_before and desktop._accepted_physical_candidate==owner
		and session.active() and body_states()==captured,"terrain comparison/refusal/close leaves exact live colliders and graph untouched")
	# A copied equipment frame is an admitted value API even while paused. It
	# must retire a candidate that captured an earlier worker mailbox.
	var final_barrier: RefCounted=FinalBarrier.new()
	desktop.simulation_worker._controlled_liquid_prepare_barrier=final_barrier.enter
	var retained_before_mailbox: Dictionary=receipt()
	expect(desktop.liquid_comparison_apply_active(choose(bridge,"cellular_yield_v1"),true,true,"Inspect",2),
		"retained actor reaches actual final commit fence")
	var arrived: bool=await wait_for(func() -> bool: return final_barrier.arrived.try_wait())
	expect(arrived,"worker reaches deterministic retained-owner final barrier")
	var frame: Dictionary=session.equipment_frame();frame.tick+=1
	var admission: Dictionary=desktop.simulation_worker.set_physical_usable_state(frame)
	expect(arrived and admission.status=="no_requests" and admission.reason.is_empty(),
		"actual copied equipment-frame publication changes the worker mailbox after preparation")
	final_barrier.resume.post()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.physical_actor_session==session and desktop._accepted_physical_candidate==owner
		and receipt().canonical_bytes==retained_before_mailbox.canonical_bytes and body_states()==captured
		and desktop.microscenario_error.contains("mailbox"),
		"changed admitted mailbox refuses before native swap and keeps the installed graph/receipt/motion")
	desktop.simulation_worker._controlled_liquid_prepare_barrier=Callable()
	var held_equipment: RefCounted=Held.new()
	desktop._prepared_default_actor_factory=func() -> RefCounted: return held_equipment
	expect(desktop.liquid_comparison_apply_active(choose(bridge,"cellular_yield_v1"),true,true,"Inspect",2),
		"equipment-state refusal prepares an actual native candidate")
	expect(await wait_for(func() -> bool: return not desktop.simulation_worker.prepared_physical_liquid_values().is_empty()),
		"equipment-state control publishes its candidate")
	item.charge=70.5
	expect(not held_equipment.pose_unchanged(),"copied equipment state detects an exact owner-local charge change")
	desktop._actor_effort=0.375
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.physical_actor_session==session and desktop._accepted_physical_candidate==owner
		and desktop._actor_effort==0.375 and receipt().canonical_bytes==retained_before_mailbox.canonical_bytes
		and body_states()==captured,"changed source equipment refuses and preserves the actual newer owner state")
	desktop._prepared_default_actor_factory=Callable()
	for variant: String in ["reference","cached","cached_dormant"]:
		expect(desktop.liquid_comparison_apply_active(choose(bridge,"pressure_flow_v1",variant),false,true,"Inspect",2),
			"registered-actor pressure %s reaches actual native capacity admission"%variant)
		expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
			and desktop.microscenario_error.contains("capacity") and desktop.physical_actor_session==session
			and desktop._accepted_physical_candidate==owner and body_states()==captured
			and receipt().canonical_bytes==retained_before_mailbox.canonical_bytes,
			"pressure %s capacity refusal preserves actor/equipment/receipt without advancing the failed candidate"%variant)
	var retained: Dictionary=receipt()
	expect(not desktop.apply_actor_prototype_configuration(&"rapier/runner",&"human",true)
		and desktop.physical_actor_session==session and receipt().canonical_bytes==retained.canonical_bytes,
		"NPC request remains transactional after generic one-actor admission")
	desktop.reset_world()
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"Restart stages authored fresh actor");_finish();return
	expect(desktop.physical_actor_session!=session and desktop.physical_actor_session.run_id!=before_run
		and desktop.physical_actor_session._equipment[0].charge==100.0,
		"Restart explicitly constructs fresh authored owner/equipment instead of borrowing Apply state")
	expect(desktop.apply_actor_prototype_configuration(&"runner",&"human",false),"actual F5 callback stages a registered sampled actor")
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"sampled actor reaches owner acknowledgement");_finish();return
	expect(desktop.actor_model_selection==&"runner" and desktop.physical_actor_session==null
		and desktop.latest_snapshot.actor_prototypes.get("count",0)==1,
		"sampled actor and real reference-body graph are installed through selected default recipe")
	var sampled_actors: CyberActorPrototypeSession=desktop.simulation_worker._actor_session
	var sampled_usables: CyberUsableSession=desktop.simulation_worker._usable_session
	var sampled_graph: RefCounted=desktop._accepted_reference_candidate
	var sampled_epoch: int=sampled_actors.identity_epoch()
	var sampled_pose: PackedFloat32Array=body_states()
	var sampled_borrow: RefCounted=Borrow.new()
	desktop._prepared_default_actor_factory=func() -> RefCounted: return sampled_borrow
	expect(desktop.liquid_comparison_apply_active(choose(bridge,"cellular_yield_v1"),true,true,"Inspect",2),
		"sampled registered actor reaches retained Apply")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.simulation_worker._actor_session==sampled_actors
		and desktop.simulation_worker._usable_session==sampled_usables
		and sampled_actors.identity_epoch()==sampled_epoch
		and desktop._accepted_reference_candidate==sampled_graph and body_states()==sampled_pose
		and desktop.microscenario_error.is_empty(),
		"sampled Apply retains exact actor/usable owner, identity epoch and actual body graph: "+JSON.stringify({
			"error":desktop.microscenario_error,"borrow_error":sampled_borrow.last_error,"actors_same":desktop.simulation_worker._actor_session==sampled_actors,
			"usables_same":desktop.simulation_worker._usable_session==sampled_usables,
			"epoch_before":sampled_epoch,"epoch_after":sampled_actors.identity_epoch(),
			"graph_same":desktop._accepted_reference_candidate==sampled_graph,"pose_same":body_states()==sampled_pose}))
	desktop._prepared_default_actor_factory=Callable()
	print("LIQUID_DEFAULT_ACTOR_OWNERS: ",JSON.stringify({"articulated":"skimmer","equipment":"water_lance","sampled":"runner", "borrow_disposal_checked":true}))
	_finish()

func _finish() -> void:
	if desktop!=null:
		desktop._prepared_default_actor_factory=Callable()
		desktop.simulation_worker._controlled_liquid_prepare_barrier=Callable()
		desktop.simulation_worker.stop_worker()
		var owner: Control=desktop;desktop=null;owner.queue_free()
		await owner.tree_exited
		owner=null
		await process_frame
	print("LIQUID_DEFAULT_ACTOR_HOST: ",assertions," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
