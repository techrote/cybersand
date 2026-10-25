extends SceneTree

const Prepared = preload("res://scripts/prepared_reference_body_session.gd")
const Profiles = preload("res://scripts/water_experiment_profiles.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const PLAY_TICKS: int = 240
const BLIND_CANDIDATES: Array[int] = [3,5,8]
var assertions: int = 0
var failures: int = 0
var owner: Control
var panel: CyberLiquidComparisonPanel
var cohorts: Array[Dictionary] = []

class Held extends "res://scripts/prepared_reference_body_session.gd":
	var permit: bool = false
	func ready() -> bool: return permit and super.ready()

class TerrainRefusal extends "res://scripts/prepared_reference_body_session.gd":
	func install_terrain(_chunks: PackedInt32Array) -> bool:
		last_error = "declared Water candidate terrain refusal";return false

class ActorRefusal extends CyberActorPrototypeSession:
	func configure(_definitions: Array, _world, _epoch_floor: int = -1) -> bool: return false

func _initialize() -> void: run.call_deferred()

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value: failures += 1;push_error("LIQUID_SYNCHRONOUS_WATER_REFERENCE_BODY: "+message)
	return value

func resolved(scenario: String = "supported-body-water", bits: int = 8) -> Dictionary:
	return Profiles.resolve({},{},{"scenario_id":scenario,"mass_bits":bits,"seed":31})

func snapshot() -> Dictionary:
	var summary: Dictionary = owner.micro_host.summary();summary.erase("error")
	return {"world":owner.native_world.get_physical_state_hash(),"receipt":owner.native_world.get_applied_liquid_construction_receipt(),
		"record":owner.micro_host.liquid_host_observation_record(),"host":summary,"player":owner.player,
		"bodies":owner.rigid_bodies.duplicate(),"poses":Prepared._pose_values(owner.rapier_bridge.pack_body_states()),
		"water":owner.water_policy_resolved.duplicate(true),"actions":owner.water_action_history.duplicate(true),
		"observations":owner.water_observations.duplicate(true),"index":owner.water_action_index}

func original_pose(states: PackedFloat32Array) -> bool:
	if states.size()!=3*Coupling.INPUT_STRIDE: return false
	for index: int in range(3):
		var offset: int = index*Coupling.INPUT_STRIDE
		if states[offset]!=index+1 or states[offset+1]!=[124,244,384][index] or states[offset+2]!=90 \
			or states[offset+3]!=0 or states[offset+4]!=8 or states[offset+5]!=14 \
			or states[offset+6]!=0 or states[offset+7]!=0 or states[offset+8]!=0: return false
	return true

func start(preset: int = 2) -> bool:
	owner.microscenario_panel.open_liquids()
	panel.select_preset(preset);panel.session_picker.select(1);panel.geometry_picker.select(0)
	panel.normalize_water.button_pressed = false;panel.refresh(owner.tower_context)
	if not expect(not panel.apply_button.disabled,"actual Water Feel panel admits explicit Exploratory body route"): return false
	panel.apply_button.pressed.emit()
	if owner._pending_web_reference==null:
		print("LIQUID_WATER_REFERENCE_PREPARE_REFUSAL ",JSON.stringify({"error":owner.microscenario_error,
			"panel":panel._refusal,"components":owner.native_world.get_liquid_run_receipt({}).get("components",{})}))
	return owner._pending_web_reference!=null

func complete() -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while owner._pending_web_reference!=null and Time.get_ticks_msec()<deadline:
		await physics_frame
		owner._advance_web_reference()
	var applied: bool = owner._pending_web_reference==null and owner.microscenario_error.is_empty()
	# Ordinary _process consumes the applied serial before another UI choice.
	# Manual test stepping must execute that actual owner acknowledgement too.
	if applied: owner._process(0)
	return applied

func run() -> void:
	owner = load("res://web_main.tscn").instantiate();root.add_child(owner);await process_frame
	owner.set_process(false);owner.set_physics_process(false)
	panel = owner.microscenario_panel.liquid_panel
	expect(owner.set_quality(0),"actual Current quality control selects Low before Water Feel construction")
	var result: Dictionary = resolved()
	owner.water_lab_apply_result(result)
	if not expect(owner.ready_to_play and owner.rapier_available and owner._water_owner_is_current()
		and original_pose(owner.rapier_bridge.pack_body_states()),"actual Current supported-body Water Feel keeps synchronous authored poses"): finish();return
	var baseline: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var baseline_host := CyberMicroScenarioHost.new()
	expect(baseline_host.install(baseline,Catalogue.water(result),owner.microscenario_mode)
		and owner.demo_bridge.export_level(baseline)==owner.demo_bridge.export_level(owner.native_world),
		"Current Water Feel ordered native recipe exactly matches independent original construction")
	var prior: Dictionary = snapshot()
	var held := Held.new()
	owner._prepared_web_reference_factory = func() -> RefCounted: return held
	if not expect(start(),"actual panel starts one pending Water body transaction"): finish();return
	var values: Dictionary = owner._pending_web_reference.values.duplicate(true)
	expect(original_pose(held.initial_body_states()) and values.initial_bodies==held.initial_body_states()
		and snapshot()==prior,"actual frozen initial mask input retains old Water/player/body graph/receipt/cursors")
	owner.ui.close_menu();owner.focused = true;owner.paused = false;owner.input_armed = false
	for frame: int in range(32):
		await physics_frame
		owner._advance_web_reference();owner._physics_process(1.0/60.0)
		expect(owner._pending_web_reference!=null and held.pose_unchanged() and snapshot()==prior,
			"pending real frame%d holds both graph poses and all old Water authority" % frame)
	held.permit = true
	expect(await complete(),"real frozen-frame and terrain readiness commits the exact candidate")
	owner._prepared_web_reference_factory = Callable()
	var receipt: Dictionary = owner.native_world.get_applied_liquid_construction_receipt()
	expect(owner._accepted_reference_candidate==held and owner.rapier_bridge==held.physics_bridge()
		and owner.rigid_bodies==held.bodies() and owner._liquid_water_active and owner._water_owner_is_current()
		and owner.tower_context.water_active and not owner.tower_context.get("micro_active",false)
		and owner.current_view_size==Vector2i(480,270) and owner.camera_origin==Vector2.ZERO
		and owner.quality==0 and owner.simulation_margin==Vector2i(16,18) and owner.render_snapshot_hz==30
		and owner.player.position==Vector2(24,222) and owner.paused,"success adopts permanent graph/player and original Water view/context")
	expect(receipt.initial_body_count==3 and receipt.initial_body_state_sha256==values.initial_body_state_sha256
		and receipt.physical_state_hash==owner.native_world.get_physical_state_hash() and receipt.qualifications==15
		and not receipt.eligible_for_full_matched_evidence and owner.native_world.rigid_body_id_at(124,90)==1
		and owner.native_world.rigid_body_id_at(244,90)==2 and owner.native_world.rigid_body_id_at(384,90)==3,
		"native receipt/masks describe actual adopted synchronous Water poses with frozen qualification")
	expect(owner.demo_bridge.export_level(owner.native_world)==owner.demo_bridge.export_level(baseline)
		and owner.water_actions==CyberWaterFeelScenarios.recipe("supported-body-water",31).actions
		and owner.demo_bridge.prepared_liquid_world_values(owner.native_world,values.token).is_empty(),
		"tick-zero tuples/actions remain exact and one-use candidate token is consumed")
	for preset: int in [2,3,4,0]:
		if preset!=2:
			if not expect(start(preset) and await complete(),"next explicit solver stages the original Water body owner"): continue
		_play(preset)
	prior = snapshot()
	owner._prepared_web_reference_factory = func() -> RefCounted: return TerrainRefusal.new()
	expect(not start() and snapshot()==prior and owner._pending_web_reference==null,"terrain refusal retains all Water owners, native authority, receipt and cursor")
	owner._prepared_web_reference_factory = Callable()
	owner._prepared_web_reference_actor_factory = func() -> Variant: return ActorRefusal.new()
	expect(not start() and snapshot()==prior,"sampled-player staging refusal retains previous Water identity")
	owner._prepared_web_reference_actor_factory = Callable()
	owner._prepared_web_reference_commit_barrier = func() -> void: owner.liquid_comparison_clear_import()
	expect(start() and not await complete() and snapshot()==prior,"final owner serial supersession refuses before native/body commit")
	owner._prepared_web_reference_commit_barrier = Callable()
	var hz: int = owner.render_snapshot_hz
	owner._prepared_web_reference_commit_barrier = func() -> void: owner.render_snapshot_hz += 1
	expect(start() and not await complete() and snapshot()==prior,"final actual execution-setting mutation refuses before swap")
	owner.render_snapshot_hz = hz;owner._prepared_web_reference_commit_barrier = Callable()
	owner._prepared_web_reference_commit_barrier = func() -> void: owner.native_world.paint_disc(700,700,0,1,0)
	expect(start() and not await complete() and owner.native_world.material_at(700,700)==1
		and owner.player==prior.player and owner.rigid_bodies==prior.bodies
		and owner.native_world.get_applied_liquid_construction_receipt()==prior.receipt
		and owner.micro_host.liquid_host_observation_record()==prior.record,
		"native retained-state fence preserves the actual old-world edit and refuses candidate adoption")
	owner._prepared_web_reference_commit_barrier = Callable();prior = snapshot()
	if expect(start(),"one pending transaction exists for token retirement"):
		owner.demo_bridge.discard_liquid_world(owner.native_world,owner._pending_web_reference.token)
		expect(not await complete() and snapshot()==prior,"retired native one-use token cannot install a replacement graph")
	if expect(start(),"one pending transaction exists for bounded expiry"):
		owner._pending_web_reference._started_msec = Time.get_ticks_msec()-20001
		owner._advance_web_reference()
		expect(owner._pending_web_reference==null and snapshot()==prior,"bounded readiness refusal preserves complete old Water session")
	panel.select_preset(1)
	expect(not owner._apply_prepared_liquid_water(panel.requested_policy,false,2,result) and snapshot()==prior
		and owner.micro_host.last_liquid_policy_refusal.get("code","")=="normalization_required"
		and owner.native_world.get_liquid_construction_attempt().get("kind","")=="construction_attempt",
		"fractional initial whole-cell Water refuses before authority replacement")
	expect(not owner._apply_prepared_liquid_water(panel.requested_policy,true,2,resolved("drips")) and snapshot()==prior,
		"explicit initial normalization does not admit unsupported future fractional whole-cell sources")
	panel.select_preset(5)
	var inertial: Dictionary = owner.demo_bridge.validate_liquid_policy(panel.requested_policy)
	expect(inertial.accepted and Catalogue.whole_cell_water_family("inertial_cellular_v1"),
		"future-source control uses an actually admitted whole-cell Water IN policy")
	expect(not owner._apply_prepared_liquid_water(panel.requested_policy,true,3,resolved("drips"))
		and owner.microscenario_error.contains("scheduled sources") and owner._pending_web_reference==null and snapshot()==prior,
		"explicit IN normalization/radius cannot admit future fractional sources or replace retained synchronous bodies")
	expect(not owner.water_lab_prepare_blind(BLIND_CANDIDATES,77) and owner.water_blind_set.is_empty() and snapshot()==prior,
		"prepared body route cannot silently enter blind selection")
	var old: RefCounted = owner._accepted_reference_candidate
	var generation: int = owner.native_world.get_liquid_policy_session_generation()
	owner.ui.buttons["restart"].pressed.emit()
	expect(owner._pending_web_reference!=null and await complete()
		and owner.native_world.get_liquid_policy_session_generation()!=generation and owner.native_world.get_tick_index()==0
		and owner._accepted_reference_candidate!=old and old.viewport==null and original_pose(owner.rapier_bridge.pack_body_states())
		and owner.water_action_index==0 and owner.water_observations.is_empty(),"actual Restart rebuilds accepted family, Water recipe and original poses with reset cursors")
	old = owner._accepted_reference_candidate
	owner.water_lab_apply_result(resolved("shallow-pool",5))
	expect(owner._pending_web_reference==null and owner._liquid_water_active and owner.rigid_bodies.is_empty()
		and old.viewport==null and owner.water_policy_resolved.hash==resolved("shallow-pool",5).hash
		and owner.native_world.get_applied_liquid_construction_receipt().initial_body_count==0,
		"body-free semantic/scenario change retains accepted family and closes physical graph only after success")
	owner.water_lab_apply_result(result)
	expect(owner._pending_web_reference!=null and await complete(),"body-free to body-bearing change stages the exact original graph")
	if expect(start(),"pending Water graph exists before explicit Current replacement"):
		var pending: RefCounted = owner._pending_web_reference.candidate
		owner.select_demo("neon_works",false)
		expect(owner._pending_web_reference==null and pending.viewport==null and owner.rigid_bodies.is_empty()
			and owner.native_world.get_applied_liquid_construction_receipt().is_empty()
			and owner.native_world.get_liquid_solver_policy().maximum_rule_radius==2,
			"explicit Current replacement cancels pending native/physical candidate and retires prepared identity")
	owner.water_lab_apply_result(result)
	var original_payload: PackedByteArray = owner.demo_bridge.export_level(owner.native_world)
	expect(owner.demo_bridge.import_level(owner.native_world,original_payload),"identical generic level import retires actual Water generation")
	prior = snapshot()
	expect(not owner._apply_prepared_liquid_water(owner.demo_bridge.default_liquid_policy(),false,2,result)
		and snapshot()==prior and not owner._water_owner_is_current(),
		"same native payload and Water UI label cannot borrow old constructor transport/source identity")
	owner.select_demo("neon_works",false)
	finish()

func _play(preset: int) -> void:
	var actual: Dictionary = owner.native_world.get_liquid_solver_policy()
	var water_assignment: Dictionary = {}
	for assignment: Dictionary in actual.assignments:
		if int(assignment.material)==3: water_assignment = assignment
	var expected_family: String = "freemass_v1" if preset==0 else "pressure_flow_v1"
	var expected_variant: String = "cached_dormant" if preset==4 else ("cached" if preset==3 else "reference")
	expect(water_assignment.get("applied_family","")==expected_family
		and water_assignment.get("applied_variant","")==expected_variant and actual.maximum_rule_radius==2
		and actual.policy_hash==owner.demo_bridge.validate_liquid_policy(panel.requested_policy).receipt.policy_hash,
		"actual native applied family/variant/policy and geometry match the requested cohort")
	var initial: PackedFloat32Array = owner.rapier_bridge.pack_body_states()
	var water: int = owner.native_world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024)).water_integer
	owner.microscenario_panel.liquid_dialog.hide()
	owner.ui.close_menu();owner.paused = false;owner.focused = true;owner.input_armed = false
	var contacts: int = 0
	var applications: int = 0
	var impulse := Vector2.ZERO
	var absolute: float = 0
	var ages: Array[int] = []
	owner.rapier_bridge.diagnostic_applications.resize(3*6)
	for tick: int in range(PLAY_TICKS):
		owner._physics_process(1.0/60.0)
		applications += owner.rapier_bridge.last_results_applied()
		var applied: PackedFloat64Array = owner.rapier_bridge.diagnostic_applications
		for index: int in range(3):
			if applied[index*6+5]==1 and applied[index*6+4]==0:
				var value := Vector2(applied[index*6+1],applied[index*6+2])
				impulse += value;absolute += absf(value.x)+absf(value.y);ages.append(int(applied[index*6]))
		var results: PackedFloat32Array = owner.native_world.rigid_body_results()
		for offset: int in range(0,results.size(),Coupling.RESULT_STRIDE): contacts += int(results[offset+Coupling.RESULT_CONTACT_COUNT])
	owner.paused = true;owner.ui.show_page("home")
	owner._water_apply_due_web_actions()
	var current: PackedFloat32Array = owner.rapier_bridge.pack_body_states()
	var gas_view: Dictionary = owner.native_world.inspect_gas_compartments()
	var gas: Dictionary = gas_view.get("ledger",{})
	var pressure: Dictionary = owner.native_world.get_pressure_flow_ledger()
	var pressure_closes: bool = (bool(pressure.get("available",false)) and bool(gas_view.get("available",false))
		and int(pressure.get("overfill_external",-1))==0 and bool(gas.get("closes",false))) if preset!=0 \
		else (not pressure.get("available",true) and not gas_view.get("available",true) and gas.is_empty())
	var state: Dictionary = owner.micro_host.legacy_water_state()
	expect(not owner.native_world.has_failed() and owner.native_world.get_tick_index()==PLAY_TICKS
		and owner.rapier_bridge.manual_step_count()==PLAY_TICKS and applications>0 and absolute>0 and contacts>0
		and not ages.is_empty() and ages.max()<=8 and owner.rapier_bridge.last_stale_results_rejected()==0
		and (current[1]!=initial[1] or current[2]!=initial[2]),"normal synchronous Water owner consumes signed cellular feedback with actual body motion/contact")
	expect(owner.native_world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024)).water_integer==water
		and pressure_closes and state.explicit_source==0 and state.explicit_sink==0 and state.current==water,
		"actual initial quantity/source/sink close; pressure gas closes when active and FM has no pressure authority")
	expect(state.action_index==1 and state.observations.size()==1 and state.observations[0].region.tick==180
		and owner.water_observations==state.observations,"original registered tick180 Water observation still executes once")
	cohorts.append({"preset":preset,"family":water_assignment.get("applied_family",""),
		"variant":water_assignment.get("applied_variant",""),"policy_hash":actual.policy_hash,"quality":owner.quality,
		"completed_ticks":owner.native_world.get_tick_index(),
		"manual_steps":owner.rapier_bridge.manual_step_count(),"contacts":contacts,"water":water,
		"gas_available":gas_view.get("available",false),"gas_closes":gas.get("closes",false),"pressure_accounting_valid":pressure_closes,
		"applications":applications,"accepted_impulse":[impulse.x,impulse.y],"absolute_impulse":absolute,"max_accepted_age":ages.max() if not ages.is_empty() else -1,
		"initial_body0":[initial[1],initial[2]],"final_body0":[current[1],current[2]],"observation_tick":180})
	print("LIQUID_SYNCHRONOUS_WATER_REFERENCE_PLAY ",JSON.stringify(cohorts.back()))

func finish() -> void:
	print("LIQUID_SYNCHRONOUS_WATER_REFERENCE_BODY_RESULT ",JSON.stringify({"ok":failures==0,"cohorts":cohorts,
		"whole_cell_source_refusal_families":["cellular_yield_v1","inertial_cellular_v1"],
		"scope":"actual synchronous supported-body Water Feel FM/PF staging/feedback and CY/IN future-source refusal; local native Windows only"}))
	print("LIQUID_SYNCHRONOUS_WATER_REFERENCE_BODY: %d assertions; %d failures" % [assertions,failures])
	if owner!=null: owner.queue_free()
	quit(1 if failures else 0)
