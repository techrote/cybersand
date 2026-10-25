extends SceneTree

const Observer=preload("res://tests/fixtures/lcb/default_actor_play_observer.gd")
const Physical=preload("res://scripts/prepared_physical_session.gd")
const Borrow=preload("res://scripts/prepared_default_actor_session.gd")
const Coupling=preload("res://scripts/rigid_body_coupling.gd")
var assertions: int=0
var failures: int=0
var desktop: Control
func _initialize() -> void: _run.call_deferred()
func expect(value: bool, message: String) -> void:
	assertions+=1
	if not value: failures+=1;push_error("LIQUID_DEFAULT_ACTOR_PLAY: "+message)
func wait_for(predicate: Callable) -> bool:
	var deadline: int=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if predicate.call(): return true
	return false
func choose(bridge: Variant, family: String) -> PackedInt32Array:
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(bridge.default_liquid_policy(),3):
		if choice.accepted and choice.family==family and choice.variant=="reference": return choice.request
	return PackedInt32Array()
func _run() -> void:
	root.size=Vector2i(1600,1000)
	var bridge: Variant=ClassDB.instantiate(&"CyberDemoBridge")
	for family: String in ["freemass_v1","cellular_yield_v1","inertial_cellular_v1"]:
		await play(bridge,family)
	_finish()
func play(bridge: Variant, family: String) -> void:
	var observer: CyberSimulationWorker=Observer.new()
	desktop=load("res://main.tscn").instantiate();desktop.simulation_worker=observer;desktop.paused=true;root.add_child(desktop)
	if not await wait_for(func() -> bool: return not desktop.tower_context.get("native_default_demo",{}).is_empty()):
		expect(false,"native bootstrap "+family);return
	expect(desktop.liquid_comparison_apply_active(bridge.default_liquid_policy(),false,true,"Inspect",2),"actual Liquids callback installs typed default "+family)
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"typed default acknowledgement");return
	expect(desktop.apply_actor_prototype_configuration(&"rapier/skimmer",&"policy",false),"actual F5 stages single authored skimmer "+family)
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"actor acknowledgement");return
	if desktop.physical_actor_session==null: expect(false,"real actor installed");return
	var session: CyberPhysicalActorSession=desktop.physical_actor_session
	var owner: RefCounted=desktop._accepted_physical_candidate
	var physics: CyberRapierPhysicsBridge=desktop.rapier_bridge
	# Move the actual paused assembly into existing native-authored Water. This
	# is an explicit fixture pose, not a recipe/geometry/default modification.
	for body: RigidBody2D in session.bodies():
		var transform: Transform2D=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
		transform.origin+=Vector2(105,0)
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,transform)
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(0.75,0.25))
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_SLEEPING,false)
	physics.refresh_all_states()
	var source: PackedFloat32Array=Physical._pose_values(physics.pack_body_states())
	var request: PackedInt32Array=choose(bridge,family)
	var normalized: bool=family!="freemass_v1"
	expect(not request.is_empty() and desktop.liquid_comparison_apply_active(request,normalized,true,"Inspect",3),
		"explicit radius3/normalization reaches the actual retained owner "+family)
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"selected actor acknowledgement");return
	expect(desktop.microscenario_error.is_empty() and desktop.physical_actor_session==session
		and desktop._accepted_physical_candidate==owner and Physical._pose_values(physics.pack_body_states())==source,
		"actual selected swap preserves same owner and captured motion "+family+": "+desktop.microscenario_error)
	observer.arm()
	if not await wait_for(func() -> bool: return not observer.initial().is_empty()): expect(false,"initial native readback");return
	var initial: Dictionary=observer.initial()
	var water: Dictionary={}
	for assignment: Dictionary in initial.policy.assignments:
		if assignment.material==3: water=assignment
	var masks_present: bool=initial.masks.size()==session.bodies().size()
	for mask: int in initial.masks: masks_present=masks_present and mask>0
	expect(initial.tick==0 and water.applied_family==family and water.applied_variant=="reference"
		and initial.receipt.maximum_rule_radius==3 and initial.receipt.initial_body_count==session.bodies().size()
		and masks_present and Physical._pose_values(initial.states)==source,
		"actual native policy, receipt and initial masks bind exact staged bodies "+family)
	expect(not normalized or (initial.receipt.normalization.get("rule","")=="water-normalize-v1"
		and desktop.microscenario_liquid_setup.normalization=="water-normalize-v1"
		and initial.receipt.normalization.water_after==initial.water.water_integer
		and initial.receipt.normalization.water_before+initial.receipt.normalization.positive_delta-initial.receipt.normalization.negative_delta==initial.receipt.normalization.water_after),
		"whole-cell Water admission uses explicit native normalization ledger "+family)
	physics.enable_diagnostics()
	var applications: int=0;var contacts: int=0;var invalid_age: int=0;var serial: int=-1
	var impulse:=Vector2.ZERO
	var deadline: int=Time.get_ticks_msec()+20000
	desktop.paused=false
	while Time.get_ticks_msec()<deadline:
		await physics_frame
		applications+=physics.last_results_applied()
		var values: PackedFloat64Array=physics.diagnostic_applications
		for offset: int in range(0,values.size(),6):
			if values[offset+5]>0:
				if values[offset]>physics.MAX_CELLULAR_RESULT_AGE_TICKS:
					if values[offset+4]!=1 or values[offset+1]!=0 or values[offset+2]!=0: invalid_age+=1
				elif values[offset+4]!=0: invalid_age+=1
			impulse+=Vector2(values[offset+1],values[offset+2])
		if desktop.latest_snapshot.serial!=serial:
			serial=desktop.latest_snapshot.serial;contacts+=desktop.latest_snapshot.rigid_body_contacts_last_tick
		if desktop.latest_snapshot.simulation_failed or (desktop.latest_snapshot.tick_index>=24 and contacts>0 and applications>0): break
	var live_apply: Dictionary={}
	if family=="inertial_cellular_v1": live_apply=await advanced_apply(request,observer,session,physics)
	desktop.paused=true;desktop.update_worker_frame_state();observer.stop_worker()
	var world: Variant=observer._world
	physics.refresh_all_states()
	var final: PackedFloat32Array=Physical._pose_values(physics.pack_body_states())
	var moved: bool=false
	for offset: int in range(0,source.size(),Coupling.INPUT_STRIDE):
		moved=moved or source[offset+1]!=final[offset+1] or source[offset+2]!=final[offset+2]
	expect(not world.has_failed() and not desktop.latest_snapshot.simulation_failed and world.get_tick_index()>=(4 if family=="inertial_cellular_v1" else 24)
		and world.get_attempted_tick_index()==world.get_tick_index() and physics.manual_step_count()>0 and moved,
		"real Main/worker callbacks advance healthy native and retained actor "+family)
	expect(applications>0 and contacts>0 and impulse!=Vector2.ZERO and invalid_age==0,
		"actual signed contact feedback obeys result-age rules "+family)
	var quantity: Dictionary=world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024))
	var whole: bool=not normalized or int(quantity.water_integer)==int(quantity.water_cells)*int(initial.water_policy.maximum)
	expect(int(quantity.water_integer)==int(initial.water.water_integer) and int(quantity.water_overfill)==0 and whole
		and not world.get_pressure_flow_ledger().available and not world.inspect_gas_compartments().get("available",false),
		"exact Water quantity/whole-cell ledger closes with no pressure/gas claim "+family)
	var history: Array=observer.history()
	var every_tick: bool=history.size()==world.get_tick_index()+1
	for index: int in range(history.size()):
		var row: Dictionary=history[index]
		every_tick=every_tick and row.tick==index and row.water_integer==initial.water.water_integer and row.water_overfill==0
		if normalized: every_tick=every_tick and int(row.water_integer)==int(row.water_cells)*int(initial.water_policy.maximum)
	expect(every_tick,"exclusive copied observation covers every completed tick with exact Water/whole-cell accounting "+family)
	if family=="inertial_cellular_v1":
		expect(world.get_physical_state_hash_version()==3 and world.get_physical_state_format_version()==3,
			"actual IN continuation uses hash/CYPS3")
	print("LIQUID_DEFAULT_ACTOR_PLAY_ROW: ",JSON.stringify({"family":water.applied_family,"variant":water.applied_variant,
		"radius":initial.receipt.maximum_rule_radius,"normalization":initial.receipt.normalization,
		"live_apply":live_apply,"body_count":session.bodies().size(),"ticks":world.get_tick_index(),"attempts":world.get_attempted_tick_index(),
		"steps":physics.manual_step_count(),"applications":applications,"contacts":contacts,"invalid_age":invalid_age,
		"impulse":[impulse.x,impulse.y],"initial_water":initial.water.water_integer,"final_water":quantity.water_integer,
		"observed_ticks":history.size(),"every_tick":every_tick,"water_cells":quantity.water_cells,"water_maximum":initial.water_policy.maximum,"whole":whole,"moved":moved,
		"failed":world.has_failed(),"snapshot_failed":desktop.latest_snapshot.simulation_failed}))
	desktop.queue_free();desktop=null;await process_frame
func advanced_apply(request: PackedInt32Array, observer: CyberSimulationWorker,
		session: CyberPhysicalActorSession, physics: CyberRapierPhysicsBridge) -> Dictionary:
	desktop.paused=true;desktop.update_worker_frame_state()
	expect(await wait_for(func() -> bool: return desktop.latest_snapshot.paused and session._suspended),
		"advanced owner reaches actual worker/Main paused acknowledgement")
	var old_tick: int=desktop.latest_snapshot.tick_index
	var prefix: Array=observer.history()
	var original: Dictionary=observer.initial()
	var prefix_exact: bool=prefix.size()==old_tick+1
	for index: int in range(prefix.size()):
		var row: Dictionary=prefix[index]
		prefix_exact=prefix_exact and row.tick==index and row.water_integer==original.water.water_integer 			and row.water_overfill==0 and int(row.water_integer)==int(row.water_cells)*int(original.water_policy.maximum)
	expect(prefix_exact,"advanced IN source prefix retains every original tick's exact whole-cell Water before replacement")
	physics.refresh_all_states()
	var pose: PackedFloat32Array=Physical._pose_values(physics.pack_body_states())
	var actor_tick: int=session.tick
	var steps: int=physics.manual_step_count()
	var owner: RefCounted=desktop._accepted_physical_candidate
	var equipment: RefCounted=session._equipment[0]
	var generation: int=int(desktop.tower_context.liquid_construction_receipt.session_generation)
	var main_state: Dictionary=Borrow.capture_state(session)
	observer._mutex.lock()
	var runtime: RefCounted=observer._physical_usables
	var runtime_tick: int=runtime._engine._tick
	var worker_state: Dictionary=runtime.snapshot().duplicate(true)
	var pending: Array=[observer._pending_physical_effects.duplicate(true),observer._pending_physical_usables.duplicate(true)]
	observer._mutex.unlock()
	expect(old_tick>=24 and actor_tick>0 and runtime_tick>0 and steps>0,
		"live Apply source has genuinely advanced native, physical actor, bridge and equipment clocks")
	expect(desktop.liquid_comparison_apply_active(request,true,true,"Inspect",3),
		"advanced Water-IN owner reaches same-policy explicit normalized radius3 Apply")
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"advanced Apply acknowledgement");return {"accepted":false}
	var after_state: Dictionary=Borrow.capture_state(session)
	observer._mutex.lock()
	var runtime_same: bool=observer._physical_usables==runtime and runtime._engine._tick==runtime_tick
	var state_same: bool=runtime.snapshot()==worker_state
	var mailbox_same: bool=[observer._pending_physical_effects,observer._pending_physical_usables]==pending
	observer._mutex.unlock()
	physics.refresh_all_states()
	expect(desktop.microscenario_error.is_empty() and desktop.physical_actor_session==session
		and desktop._accepted_physical_candidate==owner and session._equipment[0]==equipment
		and session.tick==actor_tick and physics.manual_step_count()==steps
		and Physical._pose_values(physics.pack_body_states())==pose and main_state.bytes==after_state.bytes
		and runtime_same and state_same and mailbox_same,
		"advanced Apply retains exact live motion, graph, controller/equipment clocks/state and admitted mailboxes: "+desktop.microscenario_error)
	observer.rearm()
	if not await wait_for(func() -> bool: return not observer.initial().is_empty()):
		expect(false,"new native generation readback");return {"accepted":false}
	var initial: Dictionary=observer.initial()
	expect(initial.tick==0 and int(initial.receipt.session_generation)>generation
		and Physical._pose_values(initial.states)==pose and initial.water.water_integer==628320,
		"new native World resets only its generation/tick and binds the retained actual body input")
	var contacts: int=0;var applications: int=0;var last_serial: int=-1
	var signed_impulse:=Vector2.ZERO
	var deadline: int=Time.get_ticks_msec()+20000
	desktop.paused=false
	while Time.get_ticks_msec()<deadline:
		await physics_frame
		applications+=physics.last_results_applied()
		var feedback: PackedFloat64Array=physics.diagnostic_applications
		for offset: int in range(0,feedback.size(),6): signed_impulse+=Vector2(feedback[offset+1],feedback[offset+2])
		if desktop.latest_snapshot.serial!=last_serial:
			last_serial=desktop.latest_snapshot.serial;contacts+=desktop.latest_snapshot.rigid_body_contacts_last_tick
		if desktop.latest_snapshot.simulation_failed or (desktop.latest_snapshot.tick_index>=4 and contacts>0 and applications>0): break
	desktop.paused=true;desktop.update_worker_frame_state()
	physics.refresh_all_states()
	var current: PackedFloat32Array=Physical._pose_values(physics.pack_body_states())
	expect(not desktop.latest_snapshot.simulation_failed and desktop.latest_snapshot.tick_index>=4
		and applications>0 and contacts>0 and signed_impulse!=Vector2.ZERO and current!=pose,
		"resumed advanced owner receives new native contact feedback and moves after clock reset")
	var result: Dictionary={"accepted":desktop.microscenario_error.is_empty(),"source_native_tick":old_tick,"source_observed_ticks":prefix.size(),"source_quantity_exact":prefix_exact,
		"retained_actor_tick":actor_tick,"retained_equipment_tick":runtime_tick,"retained_steps":steps,
		"source_generation":generation,"new_generation":initial.receipt.session_generation,
		"resumed_ticks":desktop.latest_snapshot.tick_index,"applications":applications,"contacts":contacts,
		"signed_impulse":[signed_impulse.x,signed_impulse.y],"runtime_state_same":state_same,"mailboxes_same":mailbox_same}
	print("LIQUID_DEFAULT_ACTOR_ADVANCED_APPLY: ",JSON.stringify(result))
	return result
func _finish() -> void:
	if desktop!=null: desktop.queue_free();desktop=null
	print("LIQUID_DEFAULT_ACTOR_PLAY: ",assertions," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
