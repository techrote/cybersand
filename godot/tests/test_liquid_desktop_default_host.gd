extends SceneTree

const Prepared = preload("res://scripts/prepared_reference_body_session.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
var assertions: int = 0
var failures: int = 0
var desktop: Control
var common_initial_water: int = -1

const HeldOwner = preload("res://tests/fixtures/lcb/desktop_default_held_owner.gd")

const TerrainRefusal = preload("res://tests/fixtures/lcb/desktop_default_terrain_refusal.gd")

const EquipmentRefusal = preload("res://tests/fixtures/lcb/desktop_default_equipment_refusal.gd")

const PlayObserver = preload("res://tests/fixtures/lcb/desktop_default_play_observer.gd")

const FinalCommitBarrier = preload("res://tests/fixtures/lcb/desktop_default_commit_barrier.gd")

func _initialize() -> void: _run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1;push_error("LIQUID_DESKTOP_DEFAULT_HOST: "+message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if predicate.call(): return true
	return false

func choose(bridge: Variant, family: String, variant: String = "reference", material: int = 3) -> PackedInt32Array:
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(bridge.default_liquid_policy(),material):
		if choice.accepted and choice.family == family and choice.variant == variant: return choice.request
	return PackedInt32Array()

func receipt() -> Dictionary: return desktop.tower_context.get("liquid_construction_receipt",{}).duplicate(true)

func pose_matches(states: PackedFloat32Array) -> bool:
	if states.size()!=3*Coupling.INPUT_STRIDE: return false
	for i: int in range(3):
		var o: int = i*Coupling.INPUT_STRIDE
		var position: Vector2 = desktop.test_rigid_body_spawn(i)
		if states[o]!=i+1 or states[o+1]!=position.x or states[o+2]!=position.y \
			or absf(states[o+3]-desktop.test_rigid_body_rotation(i))>0.000001 \
			or states[o+4]!=8 or states[o+5]!=14 or states[o+6]!=0 or states[o+7]!=0 or states[o+8]!=0: return false
	return true

func _run() -> void:
	root.size = Vector2i(1600,1000)
	desktop = load("res://main.tscn").instantiate()
	desktop.paused = true
	root.add_child(desktop)
	if not await wait_for(func() -> bool: return not desktop.tower_context.get("native_default_demo",{}).is_empty()):
		expect(false,"actual ordinary Main bootstrap publishes native constructor origin");_finish();return
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var pressure: PackedInt32Array = choose(bridge,"pressure_flow_v1")
	var whole: PackedInt32Array = choose(bridge,"cellular_yield_v1")
	expect(desktop.microscenario_definition.is_empty() and desktop.liquid_comparison_can_apply_active(true)
		and not desktop.liquid_comparison_can_apply_active(false),"native origin admits only the ordinary Exploratory route without a fake MicroScenario")
	expect(not desktop.liquid_comparison_apply_active(pressure,false,false,"Inspect",2)
		and desktop.pending_microscenario_apply.is_empty(),"Controlled refuses before staging ordinary player and bodies")
	var retained_nodes: Array = desktop.rigid_bodies.duplicate()
	var retained_pose: PackedFloat32Array = Prepared._pose_values(desktop.rapier_bridge.pack_body_states())
	var held: RefCounted = HeldOwner.new()
	desktop._prepared_reference_factory = func() -> RefCounted: return held
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.requested_policy = whole.duplicate();panel.session_picker.select(0)
	panel.refresh(desktop.tower_context)
	expect(panel.apply_button.disabled,"actual panel disables Controlled for the ordinary native constructor")
	panel.session_picker.select(1);panel.geometry_picker.select(0);panel.normalize_water.set_pressed_no_signal(false)
	panel.refresh(desktop.tower_context)
	expect(not panel.apply_button.disabled and panel._active_owner_supported(),"actual panel admits the native-origin Exploratory fallback with an empty MicroScenario definition")
	expect(panel.apply_active(),"ordinary panel Apply callback queues the selected policy")
	expect(await wait_for(func() -> bool: return not desktop.simulation_worker.prepared_physical_liquid_values().is_empty()),
		"exclusive owner publishes private candidate terrain and body identity; status="+str(desktop.tower_context.get("status","unpublished")))
	if desktop.simulation_worker.prepared_physical_liquid_values().is_empty(): _finish();return
	var publication: Dictionary = desktop.simulation_worker.prepared_physical_liquid_values()
	expect(pose_matches(held.initial_body_states()) and publication.initial_bodies==held.initial_body_states(),
		"actual default positions and signed rotations feed the private permanent graph and native masks")
	for frame: int in range(12):
		await physics_frame
		expect(held.pose_unchanged() and desktop.rigid_bodies==retained_nodes
			and Prepared._pose_values(desktop.rapier_bridge.pack_body_states())==retained_pose,
			"pending physics frame %d retains both actual graphs"%frame)
	held.permit_ready = true
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"default owner continuation acknowledges native and main commit")
	desktop._prepared_reference_factory = Callable()
	expect(desktop._liquid_default_active and desktop._accepted_reference_candidate==held and desktop.rigid_bodies==held.bodies()
		and desktop.microscenario_definition.is_empty() and desktop.latest_snapshot.rigid_body_epoch==0,
		"acceptance adopts the exact prepared reference graph and ordinary epoch")
	var prior: Dictionary = receipt()
	var representation: StringName = desktop.player_representation
	expect(not desktop.cycle_player_representation() and desktop.player_representation==representation
		and desktop.pending_microscenario_apply.is_empty() and desktop._accepted_reference_candidate==held,
		"unsupported barrel switch refuses before changing Main representation or accepted graph")
	expect(not desktop.actor_prototypes_allowed(),"unsupported actor constructor stays unavailable for this prepared default owner")
	var observed: Dictionary = desktop.simulation_worker.liquid_default_host_observation_record()
	expect(prior.initial_body_count==3 and prior.initial_body_state_sha256==publication.initial_body_state_sha256
		and prior.run_intent=="exploratory" and prior.pacing=="host_paced"
		and desktop.tower_context.sampled_character_enabled,"receipt binds actual bodies, native constructor and sampled host pacing")
	expect(not observed.is_empty() and observed.identity.native_receipt_hash==prior.receipt_hash
		and observed.identity.session_generation==prior.session_generation
		and not observed.identity.host_eligible_for_full_matched_evidence
		and observed.values.host_claims.values.player_environment_profile.hash==desktop.active_player_environment_profile.hash
		and observed.values.host_claims.values.native_recipe_id=="cybersand-desktop-default-demo-v1",
		"qualified immutable host record binds native receipt and actual owner inputs")
	if not observed.is_empty(): observed.identity.digest = "caller mutation"
	expect(desktop.simulation_worker.liquid_default_host_observation_record().identity.digest != "caller mutation",
		"main receives a copied record and cannot mutate the accepted slot")
	var old_identity: Dictionary = desktop.tower_context.liquid_host_observation.duplicate(true)
	desktop._prepared_reference_factory = func() -> RefCounted: return TerrainRefusal.new()
	expect(desktop.liquid_comparison_apply_active(whole,false,true,"Inspect",2),"declared terrain refusal reaches a separate candidate")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._accepted_reference_candidate==held and receipt().canonical_bytes==prior.canonical_bytes
		and desktop.tower_context.liquid_host_observation==old_identity,"terrain failure preserves World, graph, receipt and host record")
	desktop._prepared_reference_factory = Callable()
	var held_recovery := HeldOwner.new()
	desktop._prepared_reference_factory = func() -> RefCounted: return held_recovery
	var prior_recovery: bool = desktop.sampled_runtime_recovery_enabled
	expect(desktop.liquid_comparison_apply_active(whole,false,true,"Inspect",2),"pending recovery guard control queues")
	expect(await wait_for(func() -> bool: return not desktop.simulation_worker.prepared_physical_liquid_values().is_empty()),"pending recovery control reaches physical readiness hold")
	expect(not desktop.toggle_sampled_runtime_recovery() and desktop.sampled_runtime_recovery_enabled==prior_recovery,
		"F7 during pending physical readiness refuses before mutating the captured recovery preference")
	held_recovery.permit_ready = true
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.sampled_runtime_recovery_enabled==prior_recovery and desktop.tower_context.sampled_runtime_recovery_enabled==prior_recovery,
		"accepted continuation keeps Main and actual sampled recovery input equal")
	held = held_recovery;prior = receipt();old_identity = desktop.tower_context.liquid_host_observation.duplicate(true)
	desktop._prepared_reference_factory = func() -> RefCounted: return TerrainRefusal.new()
	expect(desktop.toggle_sampled_runtime_recovery() and desktop.sampled_runtime_recovery_enabled==prior_recovery,
		"stable F7 stages only its requested candidate value")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.sampled_runtime_recovery_enabled==prior_recovery and desktop.tower_context.sampled_runtime_recovery_enabled==prior_recovery
		and desktop._accepted_reference_candidate==held and receipt().canonical_bytes==prior.canonical_bytes,
		"refused F7 replacement keeps Main, sampled owner, native receipt and body graph")
	var old_profile: String = desktop.active_player_environment_profile.hash
	var new_profile: Dictionary = load("res://scripts/player_environment_profiles.gd").preset(1)
	desktop.apply_player_environment_profile(new_profile)
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.active_player_environment_profile.hash==old_profile and desktop.tower_context.player_environment_profile.hash==old_profile
		and desktop.pending_player_environment_profile.is_empty() and receipt().canonical_bytes==prior.canonical_bytes,
		"refused PENV fresh reset preserves the old profile and clears only its rejected candidate preference")
	desktop._prepared_reference_factory = Callable()
	expect(desktop.toggle_sampled_runtime_recovery(),"stable F7 queues a complete fresh reset")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.sampled_runtime_recovery_enabled!=prior_recovery
		and desktop.tower_context.sampled_runtime_recovery_enabled==desktop.sampled_runtime_recovery_enabled,
		"successful F7 adopts the requested preference only with the replacement sampled owner")
	desktop.apply_player_environment_profile(new_profile)
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.active_player_environment_profile.hash==new_profile.hash and desktop.tower_context.player_environment_profile.hash==new_profile.hash
		and desktop.pending_player_environment_profile.is_empty(),"PENV applies through an actual prepared fresh reset without modifying the retained player first")
	held = desktop._accepted_reference_candidate;prior = receipt();old_identity = desktop.tower_context.liquid_host_observation.duplicate(true)
	desktop.simulation_worker._prepared_usable_factory = func() -> CyberUsableSession: return EquipmentRefusal.new()
	expect(desktop.liquid_comparison_apply_active(whole,false,true,"Inspect",2),"declared sampled equipment refusal reaches private owner staging")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._accepted_reference_candidate==held and receipt().canonical_bytes==prior.canonical_bytes
		and desktop.tower_context.liquid_host_observation==old_identity,"sampled equipment refusal preserves actual World, body graph and host observation")
	desktop.simulation_worker._prepared_usable_factory = Callable()
	var barrier := FinalCommitBarrier.new()
	desktop.simulation_worker._controlled_liquid_prepare_barrier = barrier.enter
	expect(desktop.liquid_comparison_apply_active(whole,false,true,"Inspect",2),"new default request reaches final owner fence")
	var arrived: bool = await wait_for(func() -> bool: return barrier.arrived.try_wait())
	expect(arrived,"actual worker reaches final commit after permanent body readiness")
	if arrived: desktop.simulation_worker.queue_lab({"scenario_capture":true})
	barrier.resume.post()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._accepted_reference_candidate==held and receipt().canonical_bytes==prior.canonical_bytes
		and desktop.tower_context.liquid_host_observation==old_identity,"newer owner request rejects final commit without retiring accepted owners")
	desktop.simulation_worker._controlled_liquid_prepare_barrier = Callable()
	var settings_barrier := FinalCommitBarrier.new()
	desktop.simulation_worker._controlled_liquid_prepare_barrier = settings_barrier.enter
	expect(desktop.liquid_comparison_apply_active(whole,false,true,"Inspect",2),"settings-fenced default request queues")
	var settings_arrived: bool = await wait_for(func() -> bool: return settings_barrier.arrived.try_wait())
	expect(settings_arrived,"actual worker reaches the final settings fence")
	var old_size: Vector2i = desktop.current_view_size
	if settings_arrived:
		desktop.current_view_size = Vector2i(480,270);desktop.update_worker_frame_state()
	settings_barrier.resume.post()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._accepted_reference_candidate==held and receipt().canonical_bytes==prior.canonical_bytes
		and desktop.tower_context.liquid_host_observation==old_identity,"changed actual view size rejects final commit and preserves accepted owner identity")
	desktop.current_view_size = old_size;desktop.update_worker_frame_state()
	desktop.simulation_worker._controlled_liquid_prepare_barrier = Callable()
	var invalid_radius: PackedInt32Array = choose(bridge,"inertial_cellular_v1","reference",CyberCellWorld.BRINE)
	expect(desktop.liquid_comparison_apply_active(invalid_radius,false,true,"Inspect",2),"explicit insufficient IN geometry reaches native refusal")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and receipt().canonical_bytes==prior.canonical_bytes and desktop._accepted_reference_candidate==held,
		"native geometry refusal keeps receipt and exact body graph")
	expect(desktop.liquid_comparison_apply_active(whole,true,true,"Inspect",2),"explicit normalized whole-cell default queues")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.microscenario_liquid_policy==whole and receipt().normalization.positive_delta==0
		and receipt().normalization.negative_delta==0, "whole native recipe admits with an exact zero-delta normalization ledger")
	var accepted: RefCounted = desktop._accepted_reference_candidate
	var accepted_generation: int = int(receipt().session_generation)
	desktop.reset_world()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and int(receipt().session_generation)>accepted_generation and desktop.microscenario_liquid_policy==whole
		and desktop.microscenario_liquid_setup.normalization=="water-normalize-v1"
		and desktop._accepted_reference_candidate!=accepted and accepted.viewport==null,
		"ordinary R reconstructs accepted policy and normalization before retiring the old permanent graph")
	desktop.simulation_worker.stop_worker()
	var world: Variant = desktop.simulation_worker._world
	expect(not world.has_failed() and world.get_tick_index()==0
		and world.get_applied_liquid_construction_receipt().canonical_bytes==receipt().canonical_bytes
		and world.get_physical_state_hash()==receipt().physical_state_hash,"stopped exclusive readback matches paused initial native receipt")
	for i: int in range(3):
		var position: Vector2 = desktop.test_rigid_body_spawn(i)
		expect(world.rigid_body_id_at(int(position.x),int(position.y))==i+1,"actual initial default mask %d is authoritative"%i)
	expect(pose_matches(desktop.rapier_bridge.pack_body_states()) and desktop.character_position==desktop.CHARACTER_SPAWN,
		"restart preserves original poses and sampled player spawn")
	desktop.queue_free();desktop = null;await process_frame
	for variant: String in ["freemass","reference","cached","cached_dormant","whole"]:
		await play_cohort(bridge,variant)
	_finish()

func play_cohort(bridge: Variant, variant: String) -> void:
	var observer := PlayObserver.new()
	desktop = load("res://main.tscn").instantiate();desktop.simulation_worker = observer;desktop.paused = true
	root.add_child(desktop)
	if not await wait_for(func() -> bool: return not desktop.tower_context.get("native_default_demo",{}).is_empty()):
		expect(false,"play cohort native bootstrap acknowledges");return
	var request: PackedInt32Array = (bridge.default_liquid_policy() if variant=="freemass" else
		choose(bridge,"cellular_yield_v1") if variant=="whole" else choose(bridge,"pressure_flow_v1",variant))
	if variant in ["reference","cached","cached_dormant"]:
		expect(desktop.liquid_comparison_apply_active(bridge.default_liquid_policy(),false,true,"Inspect",2),"capacity refusal %s establishes a typed Current control"%variant)
		expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
			and desktop._liquid_default_active,"capacity refusal Current native owner acknowledges")
		var retained: Dictionary = receipt()
		var graph: RefCounted = desktop._accepted_reference_candidate
		var identity: Dictionary = desktop.tower_context.liquid_host_observation.duplicate(true)
		expect(desktop.liquid_comparison_apply_active(request,false,true,"Inspect",2),"capacity refusal %s reaches native admission"%variant)
		expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
			and not desktop.latest_snapshot.simulation_failed and desktop._accepted_reference_candidate==graph
			and receipt().canonical_bytes==retained.canonical_bytes and desktop.tower_context.liquid_host_observation==identity,
			"initial default gas capacity refusal retains healthy World, graph, receipt and host identity")
		expect(desktop.microscenario_error.contains("capacity")
			and desktop.tower_context.get("liquid_construction_attempt",{}).get("kind","")=="construction_attempt",
			"initial gas capacity refusal has actual native attempt readback and an explicit reason")
		observer.stop_worker()
		expect(not observer._world.has_failed() and observer._world.get_tick_index()==0,
			"capacity refusal leaves the retained native World unadvanced and usable")
		print("LIQUID_DESKTOP_DEFAULT_CAPACITY_REFUSAL: ",JSON.stringify({"variant":variant,
			"healthy":not observer._world.has_failed(),"tick":observer._world.get_tick_index(),
			"retained_receipt_hash":retained.receipt_hash,"actual_receipt_hash":receipt().receipt_hash,
			"attempt_kind":desktop.tower_context.liquid_construction_attempt.kind,"error":desktop.microscenario_error}))
		desktop.queue_free();desktop = null;await process_frame
		return
	expect(desktop.liquid_comparison_apply_active(request,false,true,"Inspect",2),"play %s native default request admits"%variant)
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"play %s owner acknowledgement"%variant);return
	expect(desktop._liquid_default_active and desktop._accepted_reference_candidate!=null,"play %s adopts prepared native origin and physical owner"%variant)
	observer.arm()
	if not await wait_for(func() -> bool: return not observer.initial().is_empty()):
		expect(false,"play %s exclusive initial readback acknowledges"%variant);return
	var initial: Dictionary = observer.initial()
	if common_initial_water<0: common_initial_water = int(initial.water)
	expect(initial.tick==0 and int(initial.water)==common_initial_water and common_initial_water>0,
		"play %s exact initial Water matches the Current native recipe control"%variant)
	var physics: CyberRapierPhysicsBridge = desktop.rapier_bridge
	var initial_pose: PackedFloat32Array = physics.pack_body_states()
	physics.enable_diagnostics()
	var applied: int = 0
	var contacts: int = 0
	var signed_impulse := Vector2.ZERO
	var invalid_age: int = 0
	var ages: Dictionary = {}
	var last_serial: int = -1
	var deadline: int = Time.get_ticks_msec()+20000
	desktop.paused = false
	while Time.get_ticks_msec()<deadline:
		await physics_frame
		applied += physics.last_results_applied()
		var values: PackedFloat64Array = physics.diagnostic_applications
		for body: int in range(3):
			var o: int = body*6
			if values[o+5]>0:
				var age: int = int(values[o]);ages[age] = int(ages.get(age,0))+1
				if age>physics.MAX_CELLULAR_RESULT_AGE_TICKS:
					if values[o+4]!=1 or values[o+1]!=0 or values[o+2]!=0: invalid_age += 1
				elif values[o+4]!=0: invalid_age += 1
			signed_impulse += Vector2(values[o+1],values[o+2])
		var snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
		if snapshot.serial!=last_serial:
			last_serial = snapshot.serial;contacts += snapshot.rigid_body_contacts_last_tick
		if snapshot.simulation_failed or (snapshot.tick_index>=96 and applied>0 and contacts>0): break
	desktop.paused = true;desktop.update_worker_frame_state();observer.stop_worker()
	var world: Variant = observer._world
	var final_pose: PackedFloat32Array = physics.pack_body_states()
	var moved: bool = false
	for body: int in range(3):
		var o: int = body*Coupling.INPUT_STRIDE
		moved = moved or initial_pose[o+1]!=final_pose[o+1] or initial_pose[o+2]!=final_pose[o+2]
	expect(not world.has_failed() and not desktop.latest_snapshot.simulation_failed
		and world.get_tick_index()>=96 and world.get_attempted_tick_index()==world.get_tick_index()
		and physics.manual_step_count()>0 and moved,"play %s advances healthy native ticks and actual original bodies"%variant)
	expect(applied>0 and contacts>0 and signed_impulse!=Vector2.ZERO and invalid_age==0,
		"play %s receives actual signed feedback with correct stale-age disposition"%variant)
	var water: int = int(world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024)).water_integer)
	var pressure: Dictionary = world.get_pressure_flow_ledger()
	var gas: Dictionary = world.inspect_gas_compartments().get("ledger",{})
	var closes: bool = (pressure.available and gas.get("closes",false) and int(pressure.overfill_external)==0) \
		if variant in ["reference","cached","cached_dormant"] else not pressure.available
	expect(water==common_initial_water and closes,"play %s preserves exact original Water and applicable gas ledger"%variant)
	print("LIQUID_DESKTOP_DEFAULT_PLAY: ",JSON.stringify({"variant":variant,"completed_ticks":world.get_tick_index(),
		"attempted_tick":world.get_attempted_tick_index(),"rapier_steps":physics.manual_step_count(),"contacts":contacts,
		"applications":applied,"signed_impulse":[signed_impulse.x,signed_impulse.y],"ages":ages,"water":water,
		"initial_water":initial.water,"gas":gas,"failed":world.has_failed(),"snapshot_failed":desktop.latest_snapshot.simulation_failed}))
	desktop.queue_free();desktop = null;await process_frame

func _finish() -> void:
	if desktop != null: desktop.queue_free();desktop = null
	print("LIQUID_DESKTOP_DEFAULT_HOST: %d assertions; %d failures"%[assertions,failures])
	quit(0 if failures==0 else 1)
