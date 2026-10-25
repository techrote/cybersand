extends SceneTree

class ReferencePreparationRefusal extends "res://scripts/prepared_reference_body_session.gd":
	func prepare_reference(_parent: Node, _templates: Array[RigidBody2D], _size: Vector2,
			_positions: PackedVector2Array = PackedVector2Array(), _rotations: PackedFloat32Array = PackedFloat32Array()) -> bool:
		last_error = "fixture declared reference body preparation refusal"
		return false

const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
const Profiles = preload("res://scripts/water_experiment_profiles.gd")
const BLIND_CANDIDATES: Array[int] = [3,5,8]
var assertions: int = 0
var failures: int = 0
var desktop: Control
var web: Control

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1;push_error("LIQUID_WATER_FEEL_HOST: "+message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func resolved(scenario: String, bits: int = 8) -> Dictionary:
	return Profiles.resolve({},{},{"scenario_id":scenario,"mass_bits":bits,"seed":31})

func apply(worker: CyberSimulationWorker, command: Dictionary) -> bool:
	worker.queue_lab(command)
	worker._mutex.lock();var owned: Dictionary = worker._lab_request;worker._lab_request = {};worker._mutex.unlock()
	return worker._apply_lab(owned)

func request(result: Dictionary, policy: PackedInt32Array, serial: int, normalize_water: bool = false, radius: int = 2) -> Dictionary:
	return {"water_reset":true,"water_policy":result.policy,"water_policy_hash":result.hash,"scenario_mode":"Inspect",
		"scenario_request_serial":serial,"sampled_character_enabled":true,"liquid_policy":policy,
		"controlled_liquid_setup":{"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "",
			"maximum_rule_radius":radius}}

func run() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var current: PackedInt32Array = bridge.default_liquid_policy()
	var whole := PackedInt32Array();var pressure := PackedInt32Array();var inertial := PackedInt32Array()
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(current,3):
		if choice.accepted and choice.family == "cellular_yield_v1": whole = choice.request
		if choice.accepted and choice.family == "pressure_flow_v1" and choice.variant == "reference": pressure = choice.request
		if choice.accepted and choice.family == "inertial_cellular_v1" and choice.variant == "reference": inertial = choice.request
	expect(not whole.is_empty() and not pressure.is_empty() and not inertial.is_empty(),"actual native Water CY/PF/IN families are available")
	for scenario: String in CyberWaterFeelScenarios.ids():
		var result: Dictionary = resolved(scenario)
		var original: Dictionary = Catalogue.water(result)
		var original_hash: String = Contract.validate(original).hash
		var prepared: Dictionary = Contract.validate(Catalogue.prepared_water(result))
		expect(prepared.ok and prepared.definition.player_enabled and prepared.definition.events == original.events
			and prepared.definition.source_recipe_hash == original.source_recipe_hash and prepared.definition.water_semantics == original.water_semantics
			and Contract.validate(Catalogue.water(result)).hash == original_hash,
			"copied prepared view preserves original player/actions/policy/recipe and original schema1: "+scenario)
	var worker := Worker.new();worker._running = true;worker._paused = true
	var shallow: Dictionary = resolved("shallow-pool")
	expect(apply(worker,{"water_reset":true,"water_policy":shallow.policy,"water_policy_hash":shallow.hash}),"ordinary Current Water Feel constructor remains available")
	var original_world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var original_host := CyberMicroScenarioHost.new()
	expect(original_host.install(original_world,Catalogue.water(shallow),"Inspect")
		and worker._world.get_physical_state_hash() == original_world.get_physical_state_hash()
		and worker._scenario_host.liquid_host_observation().is_empty(),"ordinary Current retains exact native state and no prepared identity")
	var retained_hash: String = worker._world.get_physical_state_hash()
	expect(not apply(worker,request(shallow,whole,1)) and worker._world.get_physical_state_hash() == retained_hash,
		"fractional whole-cell initial setup refuses without explicit normalization")
	expect(apply(worker,request(shallow,whole,2,true)),"Water Feel ordinary dispatcher admits explicit normalized whole-cell policy")
	if not worker._scenario_request_applied: worker._running = false;finish();return
	var receipt: Dictionary = worker._world.get_applied_liquid_construction_receipt()
	expect(worker._water_lab_active and not worker._micro_active and worker._water_policy_hash == shallow.hash
		and worker._water_recipe_hash == CyberWaterFeelScenarios.recipe_hash(CyberWaterFeelScenarios.recipe("shallow-pool",31)),
		"prepared installation stays Water Feel with original semantic policy and recipe identities")
	expect(not worker._prepared_frame_hold.is_empty() and receipt.run_intent == "exploratory"
		and receipt.normalization.rule == "water-normalize-v1" and receipt.initial_body_count == 0
		and worker._scenario_host.liquid_host_observation().native_receipt_hash == receipt.receipt_hash,
		"final sampled owner/native config and actual qualified record precede acknowledgement")
	worker.acknowledge_prepared_liquid_configuration(2)
	expect(worker._prepared_frame_hold.is_empty(),"matching actual Water Feel acknowledgement releases initial owner frame")
	retained_hash = worker._world.get_physical_state_hash()
	var retained_record: Dictionary = worker._scenario_host.liquid_host_observation_record()
	var retained_character: CyberSampledCharacter = worker._character
	for disposition: String in ["request","reset","stop"]:
		worker._controlled_liquid_prepare_barrier = func() -> void:
			if disposition == "request": worker.queue_lab({"floor":4})
			elif disposition == "reset": worker.queue_reset(Vector2(24,24))
			else: worker._running = false
		expect(not apply(worker,request(shallow,pressure,3)),"deterministic Water Feel final fence observes "+disposition)
		expect(worker._world.get_physical_state_hash() == retained_hash and worker._character == retained_character
			and worker._scenario_host.liquid_host_observation_record() == retained_record,"refused final fence retains actual old World/player/record")
		worker._running = true;worker._reset_requested = false
	worker._controlled_liquid_prepare_barrier = Callable()
	var blinded: Dictionary = request(shallow,whole,4,true);blinded["blind_label"] = "A"
	expect(not apply(worker,blinded),"blind candidate request refuses before experimental family preparation")
	expect(not apply(worker,request(resolved("supported-body-water"),whole,5,true)),"unstaged body reference refuses before replacing sampled owner")
	expect(not apply(worker,request(resolved("drips"),whole,6,true)) and worker._lab_status.contains("scheduled sources"),
		"initial normalization cannot silently change future fractional source actions")
	expect(worker._world.get_physical_state_hash() == retained_hash and worker._scenario_host.liquid_host_observation_record() == retained_record,
		"blind/body/future-source refusals preserve the old construction record")
	var retained_generation: int = worker._world.get_liquid_policy_session_generation()
	expect(not apply(worker,request(resolved("drips"),inertial,8,true,3)) and worker._lab_status.contains("scheduled sources"),
		"admitted Water IN with explicit radius/normalization still refuses fractional future sources")
	expect(worker._world.get_physical_state_hash()==retained_hash and worker._character==retained_character
		and worker._world.get_liquid_policy_session_generation()==retained_generation
		and worker._world.get_applied_liquid_construction_receipt()==receipt
		and worker._scenario_host.liquid_host_observation_record()==retained_record,
		"Water IN future-source refusal retains exact worker World/player/receipt/record/generation")
	expect(apply(worker,request(resolved("drips"),pressure,9)),"pressure Water retains registered fractional scheduled sources")
	worker.acknowledge_prepared_liquid_configuration(9)
	var advanced: bool = true
	for tick: int in range(32): advanced = worker._scenario_host.advance() and advanced
	var state: Dictionary = worker._scenario_host.legacy_water_state()
	expect(advanced and state.action_index == 2 and state.actions.size() == 2 and state.explicit_source > 0,
		"actual registered Water Feel scheduled refill still executes and contributes to explicit source ledger")
	expect(state.current == state.initial_integer+state.explicit_source-state.explicit_sink,
		"retained scheduled ledger stays exact under actual pressure-family execution")
	worker._running = false
	await application(shallow,whole,inertial)
	await synchronous(shallow,whole)
	finish()

func application(shallow: Dictionary, whole: PackedInt32Array, inertial: PackedInt32Array) -> void:
	root.size = Vector2i(1600,1000)
	desktop = load("res://main.tscn").instantiate();root.add_child(desktop);await process_frame
	desktop.water_lab_apply_result(shallow)
	expect(await wait_for(func() -> bool: return desktop.pending_water_apply.is_empty() and desktop.tower_context.get("water_active",false)),"actual ordinary Water Feel acknowledges")
	var original_hash: String = desktop.tower_context.water_policy_hash
	desktop.microscenario_panel.open_liquids()
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.session_picker.select(1);panel.select_preset(1);panel.normalize_water.button_pressed = false;panel.refresh(desktop.tower_context)
	expect(panel.apply_active(),"actual active-Water Feel panel queues experimental policy")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and not desktop._liquid_water_active and not desktop.microscenario_error.is_empty()
		and desktop.tower_context.water_policy_hash == original_hash,
		"same semantic-policy hash cannot falsely acknowledge a refused family rebuild")
	panel.normalize_water.button_pressed = true
	expect(panel.apply_active(),"actual panel queues explicit normalized Water Feel rebuild")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._liquid_water_active and not desktop.tower_context.micro_active and desktop.tower_context.water_active,
		"actual family selection stays ordinary Water Feel")
	var accepted: Dictionary = desktop.tower_context.liquid_host_observation
	desktop.water_lab_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.tower_context.liquid_host_observation.session_generation != accepted.session_generation
		and desktop.microscenario_liquid_policy == whole,"normal Water Feel reset retains accepted family and records its new generation")
	var deep: Dictionary = resolved("deep-pool",5)
	desktop.water_lab_apply_result(deep)
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.water_policy_resolved.hash == deep.hash and desktop.tower_context.water_policy.mass_bits == 5
		and desktop.microscenario_liquid_policy == whole,"ordinary Water Feel semantic/scenario change retains independent family selection")
	accepted = desktop.tower_context.liquid_host_observation.duplicate(true)
	desktop._prepared_reference_factory = func() -> RefCounted: return ReferencePreparationRefusal.new()
	desktop.water_lab_apply_result(resolved("supported-body-water"))
	expect(desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.liquid_host_observation == accepted
		and desktop.water_policy_resolved.hash == deep.hash,"declared reference body preparation refusal retains actual Water Feel policy/receipt")
	desktop._prepared_reference_factory = Callable()
	expect(not desktop.water_lab_prepare_blind(BLIND_CANDIDATES,77) and desktop.water_blind_set.is_empty()
		and desktop.tower_context.liquid_host_observation == accepted,"experimental owner refuses blind transition before creating a hidden mapping")
	expect(desktop.liquid_comparison_apply_active(inertial,true,true,"Inspect",3)
		and await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.microscenario_liquid_policy==inertial,
		"actual desktop owner admits explicit normalized Water IN before future-source control")
	accepted = desktop.tower_context.liquid_host_observation.duplicate(true)
	var retained_player: Array = [desktop.character_position,desktop.player_representation]
	var retained_bodies: Array = desktop.rigid_bodies.duplicate()
	var retained_policy: String = desktop.water_policy_resolved.hash
	desktop.water_lab_apply_result(resolved("drips"))
	expect(desktop.pending_microscenario_apply.is_empty() and desktop.microscenario_error.contains("scheduled sources")
		and desktop.tower_context.liquid_host_observation==accepted
		and [desktop.character_position,desktop.player_representation]==retained_player
		and desktop.rigid_bodies==retained_bodies and desktop.water_policy_resolved.hash==retained_policy
		and desktop.microscenario_liquid_policy==inertial,
		"actual desktop Water callback refuses IN drips and retains accepted policy/owners/copied identity")
	desktop.tower_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_water_exit.is_empty())
		and not desktop._liquid_water_active and desktop.tower_context.liquid_host_observation.is_empty(),"accepted ordinary exit retires Water-only selection/record")
	desktop.queue_free();await process_frame

func synchronous(shallow: Dictionary, whole: PackedInt32Array) -> void:
	web = load("res://web_main.tscn").instantiate();root.add_child(web);await process_frame
	web.water_lab_apply_result(shallow)
	expect(web.tower_context.water_active and not web._liquid_water_active,"native synchronous ordinary Water Feel remains available")
	expect(not web._apply_prepared_liquid_water(whole,false,2,shallow),"synchronous fractional initial whole-cell setup refuses")
	expect(web._apply_prepared_liquid_water(whole,true,2,shallow) and web._liquid_water_active
		and web.tower_context.water_active and not web.tower_context.get("micro_active",false),"synchronous prepared route keeps Water Feel semantics")
	var accepted: Dictionary = web.tower_context.liquid_host_observation.duplicate(true)
	web.water_lab_reset()
	expect(web.tower_context.liquid_host_observation.session_generation != accepted.session_generation
		and web.microscenario_liquid_policy == whole,"synchronous Water Feel restart retains actual family choice")
	accepted = web.tower_context.liquid_host_observation.duplicate(true)
	expect(not web._apply_prepared_liquid_water(whole,true,2,resolved("drips"))
		and web.tower_context.liquid_host_observation == accepted,"synchronous future source refusal retains accepted record")
	expect(not web.water_lab_prepare_blind(BLIND_CANDIDATES,77) and web.water_blind_set.is_empty(),"synchronous experimental session cannot alter blind mapping")
	web.queue_free();await process_frame

func finish() -> void:
	print("LIQUID_WATER_FEEL_HOST: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
