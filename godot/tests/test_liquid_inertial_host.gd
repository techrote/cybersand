extends SceneTree

const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const PreparedPhysical = preload("res://scripts/prepared_physical_session.gd")
const MIXED: String = "res://tests/fixtures/lcb/lcb.mixed.water-oil-brine.v1.json"
var assertions: int = 0
var failures: int = 0
var desktop: Control

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_INERTIAL_HOST: " + message)

func choose(bridge: Variant, request: PackedInt32Array, material: int, family: String) -> PackedInt32Array:
	for value: Dictionary in bridge.liquid_policy_assignment_choices(request,material):
		if value.family == family and value.variant == "reference" and value.accepted: return value.request
	return PackedInt32Array()

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func fixture() -> Dictionary:
	var checked: Dictionary = Contract.parse(FileAccess.get_file_as_string(MIXED))
	var definition: Dictionary = checked.definition.duplicate(true)
	definition.rectangles = [0,0,96,96,0,0,80,96,1,1,0,0,1,80,1,95,0,1,80,1,
		28,60,8,6,3,36,60,8,6,16,32,40,8,6,24]
	definition.partial_water_fills = [];definition.events = [];definition.observations = [];definition.conditions = []
	definition.interest = {"policy":"fixed","region":[0,0,96,96]}
	definition.execution = {"policy":"fixed","cadence_lod_enabled":false,"liquid_surface_adhesion_enabled":true}
	return definition

func census(world: Variant) -> Dictionary:
	var counts: Dictionary = {3:0,16:0,24:0}
	var motion: bool = false
	for y: int in range(80):
		for x: int in range(96):
			var material: int = world.material_at(x,y)
			if counts.has(material): counts[material] += 1
			if material == 24:
				var state: Dictionary = world.inspect_inertial_cell(Vector2i(x,y))
				motion = motion or state.vx != 0 or state.vy != 0 or state.ax != 0 or state.ay != 0
	return {"counts":counts,"motion":motion}

func run() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if not bridge.has_method(&"liquid_policy_with_inertial_damping"):
		expect(false,"fresh integrated IN adapter required");finish();return
	var defaults: PackedInt32Array = bridge.default_liquid_policy()
	var request: PackedInt32Array = choose(bridge,defaults,24,"inertial_cellular_v1")
	expect(not request.is_empty(),"actual runtime admits Brine IN while retaining all foreign defaults")
	var oracle_path: String = ProjectSettings.globalize_path("res://").path_join("../docs/reference/inertial-parameter-vectors.json").simplify_path()
	var oracle: Variant = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	if not oracle is Dictionary:
		expect(false,"canonical independent IN parameter oracle must be staged");finish();return
	var expected: Dictionary = {}
	for vector: Dictionary in oracle.cases:
		var validation: Dictionary = bridge.validate_liquid_policy(PackedInt32Array(vector.words))
		expect(validation.accepted == vector.accepted,"native policy agrees with independent frozen parameter vector "+str(vector.name))
		if vector.accepted:
			expect(validation.receipt.policy_hash == vector.policy_hash
				and validation.receipt.family_parameters.inertial_cellular_v1.extension_identity == vector.extension_identity,
				"native effective identity and complete policy bytes match independent oracle")
			if vector.name != "omitted-default": expected[int(vector.damping_numerator)] = vector
		else:
			expect(validation.refusal.code == vector.refusal,"invalid native block keeps exact typed refusal")
	var definition: Dictionary = fixture()
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var host: CyberMicroScenarioHost = Host.new()
	expect(host.install(world,definition,"Benchmark",true,defaults,{"maximum_rule_radius":2}),"retained Current control prepares with radius two")
	var retained_hash: String = world.get_physical_state_hash()
	var retained_bytes: PackedByteArray = world.get_applied_liquid_construction_receipt().canonical_bytes
	expect(not host.install(world,definition,"Benchmark",true,request,{"maximum_rule_radius":2})
		and world.get_physical_state_hash() == retained_hash
		and world.get_applied_liquid_construction_receipt().canonical_bytes == retained_bytes,
		"IN cannot silently upgrade geometry or replace Current when radius two is selected")
	var identities: Dictionary = {}
	for numerator: int in range(17):
		var edited: Dictionary = bridge.liquid_policy_with_inertial_damping(request,numerator)
		expect(edited.accepted and request == choose(bridge,defaults,24,"inertial_cellular_v1"),"native damping edit preserves original immutable request")
		if expected.has(numerator):
			expect(edited.request == PackedInt32Array(expected[numerator].words)
				and edited.receipt.policy_hash == expected[numerator].policy_hash,"native damping editor emits exact independent request bytes")
		expect(host.install(world,definition,"Benchmark",true,edited.request,{"maximum_rule_radius":3}),"every admitted damping numerator constructs explicitly matched geometry")
		var readback: Dictionary = world.get_liquid_solver_policy()
		var parameters: Dictionary = readback.family_parameters.inertial_cellular_v1
		var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
		expect(parameters.damping_numerator == numerator and parameters.damping_denominator == 16
			and parameters.readback_source == "applied_world" and readback.maximum_rule_radius == 3
			and world.get_physical_state_hash_version() == 3 and world.get_physical_state_format_version() == 3,
			"readback uses actual immutable World parameters and instance versions")
		var extension: Dictionary = receipt.solver_state_extensions[0]
		expect(extension.family == 4 and extension.state_contract_version == 1 and extension.extension_identity_version == 1
			and extension.extension_digest == parameters.extension_identity
			and receipt.physical_state_hash_version == 3 and receipt.maximum_rule_radius == 3
			and receipt.physical_state_hash == world.get_physical_state_hash(),"captured native extension and mask-free tick-zero hash match actual applied law")
		expect(receipt.qualifications == 15 and not receipt.eligible_for_full_matched_evidence,"IN readback preserves frozen outer-v1 qualifications")
		identities[parameters.extension_identity] = true
	expect(identities.size() == 17,"all admitted damping values have distinct effective identities")
	for invalid: int in [-1,17,9223372036854775807]:
		expect(not bridge.liquid_policy_with_inertial_damping(request,invalid).accepted,"invalid damping refuses before any World mutation")
	var removed: PackedInt32Array = choose(bridge,bridge.liquid_policy_with_inertial_damping(request,7).request,24,"cellular_yield_v1")
	expect(removed == defaults,"switching away retires the now-unused IN block without resetting foreign assignments")
	for pressure: bool in [false,true]:
		await three_families(bridge,definition,request,pressure)
	await application_controls(bridge)
	await application_physical(bridge,request)
	finish()

func three_families(bridge: Variant, definition: Dictionary, request: PackedInt32Array, pressure: bool) -> void:
	var policy: PackedInt32Array = choose(bridge,request,3,"pressure_flow_v1") if pressure else request
	var hashes: Array[String] = []
	for workers: int in [1,4]:
		var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(world.diagnostic_reset({"workers":workers}),"three-family worker count admits")
		var host: CyberMicroScenarioHost = Host.new()
		expect(host.install(world,definition,"Benchmark",true,policy,{"maximum_rule_radius":3}),"three genuine native families install in one World")
		var observed_motion: bool = false
		for tick: int in range(30):
			expect(host.advance(),"three-family native tick completes")
			if tick == 3: observed_motion = census(world).motion
		var end: Dictionary = census(world)
		expect(observed_motion and end.counts[3] > 0 and end.counts[16] == 48 and end.counts[24] == 48
			and world.water_experiment_observation(Vector2i.ZERO,Vector2i(96,96)).water_integer == 48*255,
			"retained Brine motion coexists with exact Water quantity and Oil/Brine cell counts through contact: "+str(end)+" / observed="+str(observed_motion))
		var saved: PackedByteArray = bridge.export_physical_state(world)
		expect(not saved.is_empty() and saved.decode_u32(4) == 3,"actual IN continuation exports CYPS3")
		var restored: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(bridge.import_physical_state(restored,saved) and restored.get_physical_state_hash_version() == 3
			and restored.get_physical_state_format_version() == 3 and restored.get_physical_state_hash() == world.get_physical_state_hash(),
			"CYPS3 restores retained momentum and execution geometry into an initially Current adapter")
		for _tick: int in range(5):
			expect(world.simulation_tick() and restored.simulation_tick()
				and world.get_physical_state_hash() == restored.get_physical_state_hash(),"restored three-family continuation remains exact")
		hashes.append(world.get_physical_state_hash())
	expect(hashes[0] == hashes[1],"one/four-worker complete three-family physical state agrees")

func application_controls(bridge: Variant) -> void:
	root.size = Vector2i(1600,1000)
	desktop = load("res://main.tscn").instantiate();root.add_child(desktop);await process_frame
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.setup_picker.select(1);panel.select_preset(7)
	panel.geometry_picker.select(1);panel.geometry_picker.item_selected.emit(1)
	panel.damping_numerator.value = 7
	expect(panel.load_selected(),"actual normal panel requests three-family fixture, explicit geometry and damping")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"IN application owner acknowledges")
	panel.refresh(desktop.tower_context)
	expect(desktop.microscenario_error.is_empty()
		and desktop.tower_context.liquid_solver_policy.family_parameters.inertial_cellular_v1.damping_numerator == 7
		and desktop.tower_context.liquid_solver_policy.maximum_rule_radius == 3
		and panel.receipt_label.text.contains("7/16"),"applied native IN parameter identity drives visible readback")
	desktop.microscenario_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"IN reset acknowledges")
	expect(desktop.tower_context.liquid_solver_policy.maximum_rule_radius == 3
		and desktop.tower_context.liquid_solver_policy.family_parameters.inertial_cellular_v1.damping_numerator == 7,
		"reset retains accepted explicit geometry and parameters")
	panel.select_preset(0)
	expect(panel.load_selected(),"matched Current comparator uses same explicit radius three")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"matched Current acknowledges")
	expect(desktop.tower_context.liquid_solver_policy.maximum_rule_radius == 3
		and desktop.tower_context.liquid_solver_policy.physical_state_hash_version == 2,"non-IN comparator keeps hash/CYPS2 with explicitly matched geometry")
	expect(panel.load_current_control(),"original protected Current control remains distinct")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"original Current acknowledges")
	desktop.simulation_worker.stop_worker()
	var reference: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var checked: Dictionary = Contract.parse(FileAccess.get_file_as_string(MIXED))
	var current_host: CyberMicroScenarioHost = Host.new()
	expect(current_host.install(reference,checked.definition,"Inspect",true),"independent ordinary Current host installs exact fixed execution")
	expect(desktop.simulation_worker._world.get_liquid_solver_policy().maximum_rule_radius == 2
		and desktop.simulation_worker._world.get_physical_state_hash_version() == 2
		and desktop.simulation_worker._world.get_physical_state_hash() == reference.get_physical_state_hash(),
		"original Current restores radius two and exact original constructor state after IN/matched controls")
	desktop.queue_free();desktop = null;await process_frame

func application_physical(bridge: Variant, request: PackedInt32Array) -> void:
	desktop = load("res://main.tscn").instantiate();root.add_child(desktop);await process_frame
	var definition: Dictionary = Catalogue.definition(CyberShowcaseTiles.scenario_ids()[0])
	definition.body_enabled = false;definition.player_enabled = true
	expect(desktop.microscenario_apply_definition(definition,"Play"),"ordinary actor map remains available before IN physical preparation")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"ordinary actor map acknowledges")
	expect(desktop.apply_actor_prototype_configuration(&"rapier/runner",&"human",false),"actual articulated graph is available before IN rebuild")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"ordinary articulated graph acknowledges")
	var retained: CyberPhysicalActorSession = desktop.physical_actor_session
	var edited: Dictionary = bridge.liquid_policy_with_inertial_damping(request,7)
	expect(desktop.microscenario_apply_exploratory_liquid(desktop.microscenario_definition,edited.request,false,"Inspect",{},3),
		"normal application admits explicit IN geometry with actual articulated actors and equipment")
	var staged: RefCounted = desktop._pending_physical_candidate
	expect(staged != null and desktop.physical_actor_session == retained and staged.pose_unchanged(),
		"actual replacement graph remains frozen while the old physical owner is retained")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"IN physical preparation receives terminal owner acknowledgement")
	expect(desktop.microscenario_error.is_empty() and desktop._accepted_physical_candidate == staged
		and desktop.physical_actor_session == staged.session and desktop.physical_actor_session != retained,
		"IN adopts the exact pre-captured physical graph after native commit")
	desktop.simulation_worker.stop_worker()
	var world: Variant = desktop.simulation_worker._world
	var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	var applied: Dictionary = world.get_liquid_solver_policy()
	expect(receipt.initial_body_count > 0 and receipt.initial_body_count == desktop.rigid_bodies.size()
		and str(receipt.initial_body_state_sha256).length() == 64
		and PreparedPhysical._pose_values(desktop.simulation_worker._rigid_body_states) == PreparedPhysical._pose_values(staged.initial_body_states())
		and receipt.physical_state_hash == world.get_physical_state_hash(),
		"IN native receipt binds the actual retained initial poses and masks")
	expect(receipt.physical_state_hash_version == 3 and receipt.maximum_rule_radius == 3
		and applied.family_parameters.inertial_cellular_v1.damping_numerator == 7
		and receipt.solver_state_extensions[0].extension_digest == applied.family_parameters.inertial_cellular_v1.extension_identity
		and receipt.qualifications == 15 and not receipt.eligible_for_full_matched_evidence,
		"physical IN installation preserves actual law identity and frozen native-v1 qualifications")
	desktop.queue_free();desktop = null;await process_frame

func finish() -> void:
	if desktop != null: desktop.queue_free()
	print("LIQUID_INERTIAL_HOST: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
