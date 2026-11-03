extends SceneTree

const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

const Trial=preload("res://scripts/prepared_trial_body_session.gd")
const Held=preload("res://tests/fixtures/lcb/trial_body_held_owner.gd")
const Refusal=preload("res://tests/fixtures/lcb/trial_body_terrain_refusal.gd")
const Coupling=preload("res://scripts/rigid_body_coupling.gd")
const Observer=preload("res://tests/fixtures/lcb/trial_body_play_observer.gd")
const FinalBarrier=preload("res://tests/fixtures/lcb/desktop_default_commit_barrier.gd")
const SubtleDrift=preload("res://tests/fixtures/lcb/trial_body_subtle_drift.gd")
var assertions: int=0
var failures: int=0
var desktop: Control

func _initialize() -> void: _run.call_deferred()
func expect(value: bool, message: String) -> void:
	assertions+=1
	if not value: failures+=1;push_error("LIQUID_TRIAL_BODY: "+message)
func wait_for(predicate: Callable) -> bool:
	var deadline: int=Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if predicate.call(): return true
	return false
func receipt() -> Dictionary: return desktop.tower_context.get("liquid_construction_receipt",{}).duplicate(true)
func states() -> PackedFloat32Array:
	desktop.rapier_bridge.refresh_all_states()
	return Trial._pose_values(desktop.rapier_bridge.pack_body_states())
func set_motion(position: Vector2=Vector2(155,140), angle: float=-0.31) -> void:
	var rid: RID=desktop.rigid_bodies[0].get_rid()
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(angle,position))
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(7.25,-2.5))
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,-0.625)
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_SLEEPING,false)
	desktop.rapier_bridge.refresh_all_states()
func choose(bridge: Variant, family: String, variant: String="reference") -> PackedInt32Array:
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(bridge.default_liquid_policy(),3):
		if choice.accepted and choice.family==family and choice.variant==variant: return choice.request
	return PackedInt32Array()

func _run() -> void:
	root.size=Vector2i(1600,1000)
	desktop=load("res://main.tscn").instantiate();desktop.paused=true;root.add_child(desktop)
	if not await wait_for(func() -> bool: return not desktop.tower_context.get("native_default_demo",{}).is_empty()):
		expect(false,"actual ordinary bootstrap publishes native origin");_finish();return
	var bridge: Variant=ClassDB.instantiate(&"CyberDemoBridge")
	var policy: PackedInt32Array=bridge.default_liquid_policy()
	expect(desktop.apply_actor_prototype_configuration(&"physical/barrel",&"human",false),"actual Current F5 callback selects barrel")
	if not await wait_for(func() -> bool: return desktop._actor_reset_receipt==0 and not desktop.tower_context.get("sampled_character_enabled",true)):
		expect(false,"actual Current F5 reset acknowledges");_finish();return
	expect(desktop.physical_trial_arm=="barrel" and desktop.rigid_bodies.size()==1 and desktop.liquid_comparison_can_apply_active(true),
		"native origin admits Exploratory actual one-body trial")
	await round_trip_angles()
	set_motion()
	var prior_body: RigidBody2D=desktop.rigid_bodies[0]
	var prior_states: PackedFloat32Array=states()
	var prior_receipt: Dictionary=receipt()
	desktop._prepared_trial_factory=func() -> RefCounted: return SubtleDrift.new()
	expect(not desktop.liquid_comparison_apply_active(policy,false,true,"Play",2)
		and desktop.microscenario_error.contains("field 6 differs"),"one-ULP actual Rapier velocity drift refuses exactly before native preparation")
	expect(desktop.pending_microscenario_apply.is_empty() and desktop._pending_physical_candidate==null
		and desktop.rigid_bodies[0]==prior_body and states()==prior_states and receipt()==prior_receipt,
		"exactness refusal retains original World/receipt/body/motion without a fallback")
	desktop._prepared_trial_factory=Callable()
	var prior_input: RefCounted=desktop.physical_trial_input
	prior_input.pulse_cooldown=0.375
	var held: RefCounted=Held.new()
	desktop._prepared_trial_factory=func() -> RefCounted: return held
	var queued: bool=desktop.liquid_comparison_apply_active(policy,false,true,"Play",2)
	expect(queued,"Liquids Apply stages current trial motion; "+desktop.microscenario_error)
	if not queued: _finish();return
	if not await wait_for(func() -> bool: return not desktop.simulation_worker.prepared_physical_liquid_values().is_empty()):
		expect(false,"actual worker publishes trial continuation; "+str(desktop.tower_context.get("status","")));_finish();return
	var publication: Dictionary=desktop.simulation_worker.prepared_physical_liquid_values()
	expect(held.owner_kind()=="trial_body" and held.bodies().size()==1 and Trial._pose_values(held.initial_body_states())==prior_states,
		"private actual packet retains signed angle, asymmetric velocity, angular velocity, mass and exact barrel geometry")
	expect(publication.initial_bodies==held.initial_body_states() and publication.epoch==held.epoch,
		"native copied initial body input and fresh owner epoch bind the same retained graph")
	for frame: int in range(6):
		await physics_frame
		expect(held.pose_unchanged() and not PhysicsServer2D.space_is_active(held.viewport.world_2d.space)
			and held.bridge.manual_step_count()==0 and states()==prior_states and desktop.rigid_bodies[0]==prior_body,
			"real pending physics frame %d freezes candidate and retained graph; candidate=%s owner=%s source=%s"%[frame,held.last_error,desktop.microscenario_error,str(states())])
	expect(held._verified_physics_frames>=2 and desktop.physical_trial_input==prior_input and prior_input.pulse_cooldown==0.375,
		"readiness observes actual physics frames without speculative input-history mutation")
	held.permit_ready=true
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"actual Main adopts trial continuation");_finish();return
	desktop._prepared_trial_factory=Callable()
	if receipt().is_empty(): expect(false,"trial commit refused; "+desktop.microscenario_error);_finish();return
	var retained: Dictionary=receipt()
	var cancelled: RefCounted=Held.new()
	desktop._prepared_trial_factory=func() -> RefCounted: return cancelled
	expect(desktop.liquid_comparison_apply_active(policy,false,true,"Play",2),"bound readiness-refusal control queues")
	expect(await wait_for(func() -> bool: return not desktop.simulation_worker.prepared_physical_liquid_values().is_empty()),"bound readiness control publishes")
	var wrong: Dictionary=desktop.simulation_worker.prepared_physical_liquid_values()
	wrong.epoch+=1
	expect(not desktop.simulation_worker.complete_prepared_physical_liquid(wrong,true),"different trial epoch cannot acknowledge current native token")
	var correct: Dictionary=desktop.simulation_worker.prepared_physical_liquid_values()
	expect(desktop.simulation_worker.complete_prepared_physical_liquid(correct,false,"fixture cancel"),"exact copied trial identity can refuse its own candidate")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._accepted_reference_candidate==held and cancelled.viewport==null and states()==prior_states
		and receipt().canonical_bytes==retained.canonical_bytes,"explicit readiness refusal discards candidate only")
	desktop._prepared_trial_factory=Callable()
	var barrier: RefCounted=FinalBarrier.new()
	desktop.simulation_worker._controlled_liquid_prepare_barrier=barrier.enter
	expect(desktop.liquid_comparison_apply_active(policy,false,true,"Play",2),"final owner fence trial control queues")
	var arrived: bool=await wait_for(func() -> bool: return barrier.arrived.try_wait())
	expect(arrived,"actual trial worker reaches deterministic final commit barrier")
	if arrived: desktop.simulation_worker.queue_lab({"floor":0})
	barrier.resume.post()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._accepted_reference_candidate==held and receipt().canonical_bytes==retained.canonical_bytes
		and states()==prior_states,"newer request after readiness wins final fence without retiring old trial")
	desktop.simulation_worker._controlled_liquid_prepare_barrier=Callable()
	expect(desktop._liquid_default_active and desktop._accepted_reference_candidate==held and desktop.rigid_bodies==held.bodies()
		and desktop.physical_actor_session==null and desktop._body_owner_epoch()==held.epoch,
		"commit adopts exact one-body graph without articulated session or rebind")
	expect(states()==prior_states and desktop.physical_trial_input==prior_input and prior_input.pulse_cooldown==0.375,
		"successful Apply preserves actual motion and input owner")
	expect(receipt().initial_body_count==1 and receipt().initial_body_state_sha256==publication.initial_body_state_sha256
		and desktop.latest_snapshot.rigid_body_epoch==held.epoch and not desktop.tower_context.sampled_character_enabled,
		"applied native receipt and desktop readback identify actual physical owner")
	var record: Dictionary=desktop.simulation_worker.liquid_default_host_observation_record()
	expect(record.values.host_claims.values.physical_trial=="barrel"
		and record.values.host_claims.values.native_initial_body_input.values==Array(publication.initial_bodies)
		and not record.identity.host_eligible_for_full_matched_evidence,"qualified host record binds actual trial input without claiming full match")
	var identity: Dictionary=desktop.tower_context.liquid_host_observation.duplicate(true)
	desktop._prepared_trial_factory=func() -> RefCounted: return Refusal.new()
	expect(desktop.liquid_comparison_apply_active(policy,false,true,"Play",2),"trial terrain refusal reaches private candidate")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._accepted_reference_candidate==held and states()==prior_states
		and desktop.physical_trial_input==prior_input and receipt().canonical_bytes==retained.canonical_bytes
		and desktop.tower_context.liquid_host_observation==identity,"declared failure preserves World, receipt, graph, motion and input history")
	desktop._prepared_trial_factory=Callable()
	for variant: String in ["reference","cached","cached_dormant"]:
		expect(desktop.liquid_comparison_apply_active(choose(bridge,"pressure_flow_v1",variant),false,true,"Play",2),"default pressure %s reaches native capacity admission"%variant)
		expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
			and desktop.microscenario_error.contains("capacity") and desktop._accepted_reference_candidate==held
			and receipt().canonical_bytes==retained.canonical_bytes and states()==prior_states,
			"default pressure %s explicitly refuses capacity and retains live trial"%variant)
	var generation: int=int(receipt().session_generation)
	desktop.reset_world()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()) and int(receipt().session_generation)>generation,
		"ordinary Restart reconstructs accepted native recipe transactionally")
	var fresh: PackedFloat32Array=states()
	expect(fresh[1]==desktop.CHARACTER_SPAWN.x+CyberSampledCharacter.BODY_SIZE.x*0.5
		and fresh[2]==desktop.CHARACTER_SPAWN.y+CyberSampledCharacter.BODY_SIZE.y*0.5
		and fresh[3]==0 and fresh[6]==0 and fresh[7]==0 and fresh[8]==0 and desktop.physical_trial_input!=prior_input,
		"Restart uses authored fresh pose and zero motion rather than Apply capture")
	var old: RefCounted=desktop._accepted_reference_candidate
	expect(desktop.apply_actor_prototype_configuration(&"physical/ripper",&"human",false),"actual accepted-owner F5 callback stages Ripper")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.physical_trial_arm=="ripper" and states()[4]==18 and states()[5]==8 and states()[6]==0
		and desktop._accepted_reference_candidate!=old and old.viewport==null,"F5 adopts one actual fresh Ripper only after success")
	var ripper: RefCounted=desktop._accepted_reference_candidate
	expect(not desktop.apply_actor_prototype_configuration(&"rapier/runner",&"human",false)
		and desktop._accepted_reference_candidate==ripper and desktop.pending_microscenario_apply.is_empty(),"unsupported native-default articulated route refuses before mutation")
	expect(desktop.apply_actor_prototype_configuration(&"",&"human",false),"actual F5 baseline callback stages sampled/reference return")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.physical_trial_arm.is_empty() and desktop.rigid_bodies.size()==3 and desktop._body_owner_epoch()==0
		and desktop.tower_context.sampled_character_enabled and ripper.viewport==null,"successful sampled return retires single-body graph after commit")
	desktop.simulation_worker.stop_worker()
	expect(not desktop.simulation_worker._world.has_failed() and desktop.simulation_worker._world.get_tick_index()==0,
		"paused constructor/refusal controls leave a healthy authoritative World")
	desktop.queue_free();desktop=null;await process_frame
	for variant: String in ["freemass","whole","reference","cached","cached_dormant"]:
		await play_cohort(bridge,variant)
	_finish()

func round_trip_angles() -> void:
	# Source is always the actual live server readback, including its canonical
	# angle, rather than an authored/requested angle or a caller-owned label.
	for angle: float in [-0.31,-0.7,-1.234567,PI-0.000001,-PI+0.000001,PI-0.01,-PI+0.01]:
		set_motion(Vector2(155,140),angle)
		var source: PackedFloat32Array=states()
		var old_body: RigidBody2D=desktop.rigid_bodies[0]
		var candidate: RefCounted=Trial.new()
		var accepted: bool=candidate.prepare_trial(desktop,old_body,"barrel",17,source)
		var actual: PackedFloat32Array=Trial._pose_values(candidate._initial_states)
		var exact: bool=actual==source
		expect(accepted==exact,"actual canonical angle %.9f is admitted only with exact full packet reconstruction"%source[3])
		if accepted:
			for frame: int in range(2):
				await physics_frame
				expect(candidate.verify_physics_frame() and not PhysicsServer2D.space_is_active(candidate.viewport.world_2d.space)
					and candidate.bridge.manual_step_count()==0,"actual angle %.9f stays exact over physics frame%d"%[source[3],frame])
		else:
			expect(candidate.last_error.contains("differs") and candidate.viewport==null,
				"unrepresentable actual canonical angle explicitly refuses and closes only candidate")
		expect(desktop.rigid_bodies[0]==old_body and states()==source,"angle reconstruction never mutates retained live owner")
		print("LIQUID_TRIAL_BODY_ROUNDTRIP: ",JSON.stringify({"requested_angle":angle,"source":Array(source),
			"actual":Array(actual),"accepted":accepted,"exact":exact,"error":candidate.last_error}))
		candidate.close()

func play_cohort(bridge: Variant, variant: String) -> void:
	var observer: CyberSimulationWorker=Observer.new()
	desktop=load("res://main.tscn").instantiate();desktop.simulation_worker=observer;desktop.paused=true;root.add_child(desktop)
	if not await wait_for(func() -> bool: return not desktop.tower_context.get("native_default_demo",{}).is_empty()):
		expect(false,"play bootstrap acknowledges");return
	# Keep the actual allowlisted map untouched. Only the real live trial body
	# moves into its existing drowned nave before the Liquids Apply callback.
	var definition: Dictionary=CyberShowcaseTiles.definition(CyberShowcaseTiles.scenario_ids()[0])
	expect(desktop.microscenario_apply_definition(definition,"Play"),"play %s loads actual authored exploratory map"%variant)
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()): expect(false,"map acknowledgement");return
	var arm: String="ripper" if variant in ["whole","cached"] else "barrel"
	expect(desktop.apply_actor_prototype_configuration(StringName("physical/"+arm),&"human",false),"play %s actual F5 selects one trial hull"%variant)
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()): expect(false,"trial acknowledgement");return
	set_motion(Vector2(500,480))
	var captured: PackedFloat32Array=states()
	var request: PackedInt32Array=bridge.default_liquid_policy() if variant=="freemass" else choose(bridge,"cellular_yield_v1") if variant=="whole" else choose(bridge,"pressure_flow_v1",variant)
	var panel: CyberLiquidComparisonPanel=desktop.microscenario_panel.liquid_panel
	panel.requested_policy=request;panel.session_picker.select(1);panel.geometry_picker.select(0)
	panel.normalize_water.set_pressed_no_signal(variant=="whole");panel._dirty=true;panel.refresh(desktop.tower_context)
	expect(not panel.apply_button.disabled and panel.apply_active(),"play %s actual Liquids panel admits Exploratory trial"%variant)
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()): expect(false,"liquid acknowledgement");return
	if not expect_trial_adopted(captured,arm,variant): return
	var actual: Dictionary=desktop.tower_context.liquid_solver_policy
	var water: Dictionary={}
	for assignment: Dictionary in actual.assignments:
		if assignment.material==3: water=assignment
	var expected_family: String="freemass_v1" if variant=="freemass" else "cellular_yield_v1" if variant=="whole" else "pressure_flow_v1"
	var expected_variant: String=variant if variant in ["cached","cached_dormant"] else "reference"
	expect(water.get("applied_family","")==expected_family and water.get("applied_variant","")==expected_variant,
		"play %s has actual native family and pressure variant"%variant)
	observer.arm()
	if not await wait_for(func() -> bool: return not observer.initial().is_empty()): expect(false,"initial exclusive readback");return
	var initial: Dictionary=observer.initial()
	expect(initial.tick==0 and initial.mask==1 and Trial._pose_values(initial.states)==captured,
		"play %s exclusive worker readback binds native initial mask and captured body motion"%variant)
	if variant=="freemass":
		var graph: RefCounted=desktop._accepted_reference_candidate
		var prior_effort: float=desktop._actor_effort
		var prior_receipt: PackedByteArray=receipt().canonical_bytes
		desktop.actor_prototype_panel.effort_slider.value=0.2
		desktop._prepared_trial_factory=func() -> RefCounted: return Refusal.new()
		expect(desktop.apply_actor_prototype_configuration(&"physical/ripper",&"human",false)
			and desktop._actor_effort==prior_effort and desktop.physical_trial_arm==arm,"prepared MicroScenario F5 stages effort and arm without mutating retained Main")
		expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
			and desktop._accepted_reference_candidate==graph and states()==captured and desktop.physical_trial_arm==arm
			and desktop._actor_effort==prior_effort and receipt().canonical_bytes==prior_receipt,
			"MicroScenario F5 refusal retains graph, motion, arm, effort and receipt")
		desktop._prepared_trial_factory=Callable()
	var physics: CyberRapierPhysicsBridge=desktop.rapier_bridge
	physics.enable_diagnostics()
	var applications: int=0;var contacts: int=0;var last_serial: int=-1
	var impulse:=Vector2.ZERO
	var invalid_age: int=0
	var deadline: int=Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	desktop.paused=false
	while Time.get_ticks_msec()<deadline:
		await physics_frame
		applications+=physics.last_results_applied()
		var values: PackedFloat64Array=physics.diagnostic_applications
		if values.size()==6 and values[5]>0:
			if values[0]>physics.MAX_CELLULAR_RESULT_AGE_TICKS:
				if values[4]!=1 or values[1]!=0 or values[2]!=0: invalid_age+=1
			elif values[4]!=0: invalid_age+=1
			impulse+=Vector2(values[1],values[2])
		if desktop.latest_snapshot.serial!=last_serial:
			last_serial=desktop.latest_snapshot.serial;contacts+=desktop.latest_snapshot.rigid_body_contacts_last_tick
		if desktop.latest_snapshot.simulation_failed or (desktop.latest_snapshot.tick_index>=24 and applications>0 and contacts>0): break
	desktop.paused=true;desktop.update_worker_frame_state();observer.stop_worker()
	var world: Variant=observer._world
	var final: PackedFloat32Array=states()
	expect(not world.has_failed() and not desktop.latest_snapshot.simulation_failed and world.get_tick_index()>=24
		and world.get_attempted_tick_index()==world.get_tick_index() and physics.manual_step_count()>0
		and (final[1]!=captured[1] or final[2]!=captured[2]),"play %s adopted body advances through actual Main and worker callbacks"%variant)
	expect(applications>0 and contacts>0 and impulse!=Vector2.ZERO and invalid_age==0,
		"play %s accepts signed native feedback and rejects any stale responses according to age"%variant)
	var final_water: int=int(world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024)).water_integer)
	var pressure: Dictionary=world.get_pressure_flow_ledger()
	var gas: Dictionary=world.inspect_gas_compartments().get("ledger",{})
	expect(final_water==int(initial.water) and (gas.get("closes",false) and pressure.available and int(pressure.overfill_external)==0
		if expected_family=="pressure_flow_v1" else not pressure.available),"play %s exact Water and applicable pressure/gas ledger close"%variant)
	print("LIQUID_TRIAL_BODY_PLAY: ",JSON.stringify({"family":water.get("applied_family",""),"variant":water.get("applied_variant",""),
		"arm":arm,"ticks":world.get_tick_index(),"attempts":world.get_attempted_tick_index(),"steps":physics.manual_step_count(),
		"applications":applications,"contacts":contacts,"impulse":[impulse.x,impulse.y],"invalid_age":invalid_age,
		"initial_water":initial.water,"final_water":final_water,"failed":world.has_failed(),"gas":gas}))
	desktop.queue_free();desktop=null;await process_frame

func expect_trial_adopted(captured: PackedFloat32Array, arm: String, variant: String) -> bool:
	var accepted: bool=desktop._accepted_reference_candidate!=null and desktop._accepted_reference_candidate.owner_kind()=="trial_body"
	expect(accepted and desktop.physical_trial_arm==arm and states()==captured and desktop.rigid_bodies.size()==1,
		"play %s adopts same staged graph with captured motion; %s"%[variant,desktop.microscenario_error])
	return accepted

func _finish() -> void:
	if desktop!=null: desktop.queue_free();desktop=null
	print("LIQUID_TRIAL_BODY: ",assertions," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
