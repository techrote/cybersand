extends "res://scripts/main.gd"

const WaterFeelWebProbe = preload("res://scripts/water_feel_web_probe.gd")
const LiquidHostWebProbe = preload("res://scripts/liquid_host_web_probe.gd")
const PreparedLevel = preload("res://scripts/prepared_level_session.gd")
const PreparedSynchronousReference = preload("res://scripts/prepared_synchronous_reference_session.gd")

# Web compatibility owner. The original desktop scene/worker remains intact.
# Every native call here runs on Godot's main thread; cellular ticks remain
# fixed at 60 Hz and render publication has its own bounded cadence.
var micro_host: CyberMicroScenarioHost = CyberMicroScenarioHost.new()
var _liquid_context_generation: int = -1
var native_world: Variant
var demo_bridge: Variant
var player: CyberSampledCharacter = CyberSampledCharacter.new()
var ui: CyberWebDemoMenu
var demo_id: String = "neon_works"
var quality: int = 1
var ready_to_play: bool = false
var rapier_available: bool = false
var rapier_reason: String = "Not tested"
var focused: bool = true
var input_armed: bool = false
var publication_clock: float = 0.0
var force_publication: bool = true
var brush_radius: int = 4
var total_moves: int = 0
var paint_commands: int = 0
var imported_count: int = 0
var export_text: String = ""
var last_save_error: String = ""
var last_hash: String = ""
var test_enabled: bool = false
var test_callback: JavaScriptObject
var test_clock: float = 0.0
var worker_probe: Dictionary = {}
var rapier_test: Dictionary = {}
var tick_failure_test: Dictionary = {}
var _next_level_selection: Dictionary = {}
var _accepted_level: RefCounted
var _level_import_serial: int = 0
var _prepared_level_character_factory: Callable = Callable()
var _prepared_level_commit_barrier: Callable = Callable()
var _curated_demo_id: String = ""
var _curated_demo_generation: int = -1
var _accepted_demo: Dictionary = {}
var _prepared_demo_actor_factory: Callable = Callable()
var _prepared_demo_commit_barrier: Callable = Callable()
var _physics_pit_generation: int = -1
var _accepted_physics_demo: Dictionary = {}
var _water_generation: int = -1
var _water_transport_origin: Dictionary = {}
var _pending_web_reference: RefCounted
var _prepared_web_reference_factory: Callable = Callable()
var _prepared_web_reference_actor_factory: Callable = Callable()
var _prepared_web_reference_commit_barrier: Callable = Callable()
var interest_region_test: Dictionary = {}
var benchmark_running: bool = false
var benchmark_cancelled: bool = false
var benchmark_result: Dictionary = {}
var logical_threads: int = 1
var tower_single_step: bool = false
var tower_schedule: Array = []
var tower_inputs: Array = []
var water_actions: Array = []
var water_action_index: int = 0
var water_action_history: Array = []
var water_observations: Array = []
var water_initial_integer: int = 0
var water_current_integer: int = 0
var water_initial_requested_numerator_255: int = 0
var water_initial_quantization_error_numerator_255: int = 0
var water_explicit_source: int = 0
var water_explicit_sink: int = 0

func water_launch_arguments() -> PackedStringArray:
	var result:=PackedStringArray()
	if not OS.has_feature("web"): return result
	var encoded: Variant=JavaScriptBridge.eval("JSON.stringify(Array.from(new URLSearchParams(location.search).entries()).filter(([k])=>['water-policy-version','water-mass-bits','water-coherence','water-rest-policy','water-render-levels','water-interface','experiment','seed'].includes(k)).map(([k,v])=>'--'+k+'='+v))",true)
	var parsed: Variant=JSON.parse_string(str(encoded))
	if parsed is Array:
		for value: Variant in parsed: result.append(str(value))
	return result

func _water_observe_web(action: Dictionary = {}) -> Dictionary:
	var origin:=Vector2i.ZERO
	var size:=Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT)
	if not action.is_empty():
		origin=Vector2i(int(action.x),int(action.y))
		size=Vector2i(int(action.width),int(action.height))
	return native_world.water_experiment_observation(origin,size)

func _water_apply_due_web_actions() -> bool:
	var ok: bool = micro_host.before_tick()
	var state: Dictionary = micro_host.legacy_water_state()
	water_action_index = int(state.action_index)
	water_action_history = state.actions
	water_observations = state.observations
	water_explicit_source = int(state.explicit_source)
	water_explicit_sink = int(state.explicit_sink)
	water_current_integer = int(state.current)
	if not ok:
		paused = true
		tower_context["status"] = micro_host.last_error
	return ok

func water_lab_apply_result(result: Dictionary, blind_label: String = "") -> void:
	if not ready_to_play or not result.get("ok",false): return
	if not _water_blind_application_allowed(result,blind_label): return
	_cancel_web_reference("Superseded by a Water Feel request")
	if _liquid_water_active and tower_context.get("water_active",false):
		_apply_prepared_liquid_water(microscenario_liquid_policy,microscenario_liquid_setup.get("normalization","") == "water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),result)
		return
	var checked: Dictionary=CyberWaterExperimentProfiles.resolve({},{},result.policy)
	if not checked.get("ok",false) or str(checked.hash)!=str(result.hash): return
	var recipe: Dictionary=CyberWaterFeelScenarios.recipe(
		str(checked.policy.scenario_id),int(checked.policy.seed))
	if recipe.is_empty(): return
	var transport: Dictionary=CyberTransportProfiles.resolve(CyberTransportProfiles.preset(0))
	if not micro_host.install(native_world, CyberMicroScenarioCatalogue.water(checked), microscenario_mode):
		tower_context["status"]="Water Apply + Reset rejected; "+micro_host.last_error
		return
	_water_web_installed(result,checked,recipe,blind_label,false)

func _water_web_installed(result: Dictionary, checked: Dictionary, recipe: Dictionary, blind_label: String,
		prepared: bool) -> void:
	_curated_demo_id = "";_accepted_demo = {};_accepted_level = null
	_accepted_physics_demo = {};_physics_pit_generation = -1
	_liquid_water_active = prepared;_liquid_tower_active = false
	if not prepared:
		microscenario_liquid_policy = null;microscenario_liquid_setup = {};microscenario_definition = {}
	water_policy_resolved=result.duplicate(true)
	water_policy_available=true
	water_active_blind_label=blind_label
	demo_id="experiment_tower"
	tower_active=true
	current_view_size=Vector2i(480,270)
	paused=true
	camera_follow_enabled=false
	camera_origin=Vector2(recipe.camera_origin)
	if not prepared: player.reset(Vector2(recipe.player_start))
	character_position=player.position
	water_actions=recipe.actions.duplicate(true)
	water_action_index=0
	water_action_history.clear();water_observations.clear()
	water_explicit_source=0;water_explicit_sink=0
	water_initial_integer=int(_water_observe_web().get("water_integer",0))
	water_current_integer=water_initial_integer
	water_initial_requested_numerator_255=0
	for offset: int in range(0,recipe.partial_water_fills.size(),6):
		water_initial_requested_numerator_255+=(
			int(recipe.partial_water_fills[offset+2])*int(recipe.partial_water_fills[offset+3])
			*int(recipe.partial_water_fills[offset+4])*int(checked.derived.maximum))
	water_initial_quantization_error_numerator_255=(
		water_initial_integer*255-water_initial_requested_numerator_255)
	var status: String="Water Feel candidate %s / scenario %s / seed %d" % [blind_label,str(checked.policy.scenario_id),int(checked.policy.seed)] if not blind_label.is_empty() else "Water Feel unblinded / policy %s / recipe %s / seed %d" % [str(checked.hash).left(12),CyberWaterFeelScenarios.recipe_hash(recipe).left(12),int(checked.policy.seed)]
	tower_context={"active":true,"water_active":true,"water_policy":checked.policy.duplicate(true),
		"water_policy_hash":str(checked.hash),"water_policy_provenance":result.get("provenance",{}).duplicate(true),
		"water_recipe_hash":CyberWaterFeelScenarios.recipe_hash(recipe),"water_blind_label":blind_label,
		"status":status,"worker_count":int(native_world.get_worker_threads()),"backend":"web-main-thread"}
	if not prepared or not recipe.body_enabled: _activate_physics(bool(recipe.body_enabled))
	_water_generation = native_world.get_liquid_policy_session_generation()
	# Both actual Water constructors configure the recipe's known Baseline.
	# Bind its native readback to this origin, never a label or caller profile.
	_water_transport_origin = {"generation":_water_generation,"policy_hash":str(checked.hash),
		"receipt_hash":str(native_world.get_applied_liquid_construction_receipt().get("receipt_hash","")),
		"transport":str(native_world.get_liquid_run_receipt({}).components.transport_profile)}
	_update_liquid_context(true)
	force_publication=true
	_publish_world();update_shader_parameters();update_status()

func _apply_prepared_liquid_water(policy: PackedInt32Array, normalize_water: bool, radius: int,
		result: Dictionary) -> bool:
	if not ready_to_play or not tower_context.get("water_active",false) or not result.get("ok",false) \
		or not water_blind_set.is_empty() or not water_active_blind_label.is_empty(): return false
	var checked: Dictionary = CyberWaterExperimentProfiles.resolve({},{},result.policy)
	if not checked.ok or checked.hash != result.hash: return false
	var recipe: Dictionary = CyberWaterFeelScenarios.recipe(str(checked.policy.scenario_id),int(checked.policy.seed))
	if recipe.is_empty(): return false
	if not _water_owner_is_current() or physical_actor_session!=null or player_uses_barrel():
		microscenario_error = "Prepared Water Feel requires its current sampled/reference owner; prior session retained"
		return false
	var admitted: Dictionary = demo_bridge.validate_liquid_policy(policy)
	var source_refusal: String = CyberMicroScenarioCatalogue.prepared_water_source_refusal(admitted.get("receipt",{}),recipe)
	if not source_refusal.is_empty():
		microscenario_error = source_refusal
		return false
	var settings_refusal: String = _prepared_application_settings_refusal()
	if not settings_refusal.is_empty(): microscenario_error = settings_refusal;return false
	var definition: Dictionary = CyberMicroScenarioCatalogue.prepared_water(checked)
	if recipe.body_enabled:
		return _begin_web_water_reference(definition,policy,normalize_water,radius,result)
	_cancel_web_reference("Superseded by a body-free Water Feel request")
	_level_import_serial += 1
	var setup: Dictionary = {"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "",
		"maximum_rule_radius":radius,"owner_execution":_water_prepared_execution(definition)}
	if not micro_host.install(native_world,definition,microscenario_mode,true,policy,setup,_commit_web_prepared_sampled.bind(definition)):
		microscenario_error = micro_host.last_error
		if native_world.has_method(&"get_liquid_construction_attempt"):
			tower_context["liquid_construction_attempt"] = native_world.get_liquid_construction_attempt()
		return false
	microscenario_definition = definition.duplicate(true);microscenario_liquid_policy = policy.duplicate()
	microscenario_liquid_setup = setup.duplicate(true);microscenario_liquid_setup.erase("owner_execution")
	_water_web_installed(result,checked,recipe,"",true)
	microscenario_error = "Installed session apparatus failed: " + micro_host.last_error if micro_host.summary().get("failed",false) else ""
	return true

func _water_prepared_execution(definition: Dictionary) -> Dictionary:
	return CyberSimulationWorker.prepared_owner_execution(definition, {
			"simulation_window_enabled":native_world.get_simulation_window_enabled(),
			"cadence_lod_enabled":native_world.get_cadence_lod_enabled(),"liquid_surface_adhesion_enabled":liquid_surface_adhesion_enabled,
			"horizontal_buffer":simulation_margin.x,"vertical_buffer":simulation_margin.y})

func _water_owner_is_current() -> bool:
	return tower_context.get("water_active",false) and tower_active and water_policy_available \
		and _water_generation==native_world.get_liquid_policy_session_generation() \
		and water_policy_resolved.get("hash","")==tower_context.get("water_policy_hash","")

func _begin_web_water_reference(definition: Dictionary, policy: PackedInt32Array, normalize_water: bool,
		radius: int, result: Dictionary) -> bool:
	_cancel_web_reference("Superseded by a newer Water Feel request")
	_level_import_serial += 1
	var staged := PreparedSynchronousReference.new()
	if not staged.prepare(self,definition,policy,normalize_water,radius,_prepared_web_reference_factory,
		_prepared_web_reference_actor_factory,_prepared_web_reference_commit_barrier,result):
		microscenario_error = staged.last_error;return false
	_pending_web_reference = staged;pending_microscenario_apply = {"serial":_level_import_serial}
	if not staged.begin(self): _cancel_web_reference(staged.last_error);return false
	microscenario_error = ""
	return true

func microscenario_apply_definition(definition: Dictionary, mode: String = "Inspect") -> bool:
	return _install_web_microscenario(definition, mode)

func microscenario_apply_controlled_liquid(definition: Dictionary, liquid_policy: PackedInt32Array,
		normalize_water: bool = false, mode: String = "Inspect", maximum_rule_radius: int = 2) -> bool:
	return _install_web_microscenario(definition, mode, liquid_policy,
		{"normalization":"water-normalize-v1" if normalize_water else "","maximum_rule_radius":maximum_rule_radius})

func microscenario_apply_exploratory_liquid(definition: Dictionary, liquid_policy: PackedInt32Array,
		normalize_water: bool = false, mode: String = "Play", actor_configuration: Dictionary = {}, maximum_rule_radius: int = 2) -> bool:
	if not actor_configuration.is_empty():
		microscenario_error = "Web sampled rig/equipment owner staging remains pending; current session retained"
		return false
	return _install_web_microscenario(definition,mode,liquid_policy,
		{"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "","maximum_rule_radius":maximum_rule_radius})

func _curated_demo_is_current() -> bool:
	return _curated_demo_id == demo_id and not _curated_demo_id.is_empty() \
		and native_world.get_liquid_policy_session_generation() == _curated_demo_generation \
		and not tower_active and not tower_context.get("micro_active",false) \
		and not tower_context.get("water_active",false) and rigid_bodies.is_empty() \
		and physical_actor_session == null and not showcase_presentation.active() and not blacksite_nine_presentation.active()

func _physics_pit_is_current() -> bool:
	return demo_id=="physics_pit" and _physics_pit_generation==native_world.get_liquid_policy_session_generation() \
		and rigid_bodies.size()==3 and rapier_bridge.is_initialized() and physical_actor_session==null \
		and not tower_active and not tower_context.get("micro_active",false) and not tower_context.get("water_active",false) \
		and not showcase_presentation.active() and not blacksite_nine_presentation.active()

func liquid_comparison_active_definition() -> Dictionary:
	if _physics_pit_is_current():
		return _accepted_physics_demo.definition.duplicate(true) if not _accepted_physics_demo.is_empty() \
			else CyberMicroScenarioCatalogue.prepared_physics_pit()
	if _curated_demo_is_current():
		return _accepted_demo.definition.duplicate(true) if not _accepted_demo.is_empty() \
			else CyberMicroScenarioCatalogue.prepared_ordinary_demo(_curated_demo_id)
	return super.liquid_comparison_active_definition()

func liquid_comparison_can_apply_active(_exploratory: bool) -> bool:
	# Main's optional native-default fallback belongs to its desktop owner.
	# Synchronous routes supply their existing explicit supported definitions.
	return false

func liquid_comparison_apply_active(policy: PackedInt32Array, normalize_water: bool, exploratory: bool,
		mode: String, radius: int) -> bool:
	if _physics_pit_is_current():
		if not exploratory:
			microscenario_error = "Physics Pit requires Exploratory mode with its original physical and sampled owners";return false
		return _begin_web_reference(policy,normalize_water,radius)
	if _curated_demo_is_current():
		if not exploratory:
			microscenario_error = "Ordinary demos require Exploratory mode with their sampled player";return false
		return _apply_prepared_ordinary_demo(liquid_comparison_active_definition(),policy,normalize_water,radius)
	return super.liquid_comparison_apply_active(policy,normalize_water,exploratory,mode,radius)

func _ordinary_demo_execution(definition: Dictionary) -> Dictionary:
	var origin := Vector2i(definition.camera_origin[0],definition.camera_origin[1])
	var first := Vector2i(maxi(0,origin.x-simulation_margin.x),maxi(0,origin.y-simulation_margin.y))
	var last := Vector2i(mini(1024,origin.x+current_view_size.x+simulation_margin.x),
		mini(1024,origin.y+current_view_size.y+simulation_margin.y))
	var window: bool = native_world.get_simulation_window_enabled()
	return {"region":[first.x,first.y,last.x-first.x,last.y-first.y] if window else [0,0,1024,1024],
		"simulation_window_enabled":window,"cadence_lod_enabled":native_world.get_cadence_lod_enabled(),
		"liquid_surface_adhesion_enabled":liquid_surface_adhesion_enabled}

func _commit_web_ordinary_sampled(bridge: Variant, token: int, definition: Dictionary, serial: int) -> bool:
	var staged: Dictionary = CyberSimulationWorker.PreparedSampled.prepare(bridge,native_world,token,
		Vector2(definition.player_start[0],definition.player_start[1]),true,player.runtime_enclosure_recovery_enabled,
		player.active_profile(),[],0,_prepared_demo_actor_factory)
	if not staged.ok: microscenario_error = staged.error;return false
	if _prepared_demo_commit_barrier.is_valid(): _prepared_demo_commit_barrier.call()
	if serial != _level_import_serial or not is_inside_tree() or is_queued_for_deletion(): return false
	if not bridge.commit_liquid_world(native_world,token): return false
	player = staged.character
	return true

func _apply_prepared_ordinary_demo(definition: Dictionary, policy: PackedInt32Array,
		normalize_water: bool, radius: int) -> bool:
	if not ready_to_play or not _curated_demo_is_current() or not water_blind_set.is_empty() \
		or not water_active_blind_label.is_empty(): return false
	var refusal: String = _prepared_application_settings_refusal()
	if not refusal.is_empty(): microscenario_error = refusal;return false
	_level_import_serial += 1
	var serial: int = _level_import_serial
	var setup: Dictionary = {"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "",
		"maximum_rule_radius":radius,"owner_execution":_ordinary_demo_execution(definition)}
	if not micro_host.install(native_world,definition,"Play",false,policy,setup,
		_commit_web_ordinary_sampled.bind(definition,serial)):
		microscenario_error = micro_host.last_error;return false
	# The native commit and private sampled-owner stage have succeeded. Keep
	# ordinary demo presentation and tools, adopting values without reconfiguration.
	_accepted_level = null
	_curated_demo_generation = native_world.get_liquid_policy_session_generation()
	var receipt: Dictionary = native_world.get_applied_liquid_construction_receipt()
	_accepted_demo = {"definition":definition.duplicate(true),"policy":policy.duplicate(),
		"normalization":setup.normalization,"maximum_rule_radius":radius,
		"generation":_curated_demo_generation,"receipt_hash":receipt.receipt_hash,
		"transport":str(native_world.get_liquid_run_receipt({}).components.transport_profile)}
	_liquid_tower_active = false;_liquid_water_active = false
	microscenario_definition = definition.duplicate(true);microscenario_liquid_policy = policy.duplicate()
	microscenario_liquid_setup = setup.duplicate(true);microscenario_liquid_setup.erase("owner_execution")
	tower_context = {"active":false,"micro_active":false,"water_active":false,"status":"Ordinary demo / explicit liquid policy"}
	tower_active = false;tower_schedule.clear();tower_inputs.clear();water_actions.clear();tower_single_step = false
	camera_origin = Vector2(definition.camera_origin[0],definition.camera_origin[1]);camera_follow_enabled = false
	character_position = player.position;paused = true;microscenario_error = ""
	_update_liquid_context(true);force_publication = true;_publish_world();update_shader_parameters();update_status()
	return true

func _accepted_demo_retains_transport(transport: String) -> bool:
	return not _accepted_demo.is_empty() and _curated_demo_is_current() \
		and _accepted_demo.generation == _curated_demo_generation \
		and transport == _accepted_demo.transport \
		and native_world.get_applied_liquid_construction_receipt().get("receipt_hash","") == _accepted_demo.receipt_hash

func microscenario_supports_prepared_physical_liquid(definition: Dictionary) -> bool:
	return (_physics_pit_is_current() or _water_owner_is_current()) \
		and definition==liquid_comparison_active_definition()

func _begin_web_reference(policy: PackedInt32Array, normalize_water: bool, radius: int) -> bool:
	if not ready_to_play or not _physics_pit_is_current() or not water_blind_set.is_empty() \
		or not water_active_blind_label.is_empty(): return false
	var refusal: String = _prepared_application_settings_refusal()
	if not refusal.is_empty(): microscenario_error = refusal;return false
	_cancel_web_reference("Superseded by a newer Physics Pit request")
	_level_import_serial += 1
	var staged := PreparedSynchronousReference.new()
	if not staged.prepare(self,liquid_comparison_active_definition(),policy,normalize_water,radius,
		_prepared_web_reference_factory,_prepared_web_reference_actor_factory,_prepared_web_reference_commit_barrier):
		microscenario_error = staged.last_error;return false
	_pending_web_reference = staged
	pending_microscenario_apply = {"serial":_level_import_serial}
	if not staged.begin(self):
		_cancel_web_reference(staged.last_error);return false
	microscenario_error = ""
	return true

func _advance_web_reference() -> void:
	if _pending_web_reference==null: return
	var staged: RefCounted = _pending_web_reference
	var outcome: String = staged.advance(self)
	if outcome=="waiting": return
	if outcome!="committed": _cancel_web_reference(staged.last_error);return
	_pending_web_reference = null;pending_microscenario_apply.clear()
	if not staged.water_result.is_empty():
		var result: Dictionary = staged.water_result
		microscenario_definition = staged.definition.duplicate(true);microscenario_liquid_policy = staged.policy.duplicate()
		microscenario_liquid_setup = {"intent":"exploratory","normalization":staged.setup.normalization,
			"maximum_rule_radius":staged.setup.maximum_rule_radius}
		_water_web_installed(result,staged.water_checked,staged.water_recipe,"",true)
		tower_context["scenario_request_serial"] = staged.serial;tower_context["scenario_request_applied"] = true
		microscenario_error = "Installed session apparatus failed: " + micro_host.last_error if micro_host.summary().get("failed",false) else ""
		return
	_physics_pit_generation = native_world.get_liquid_policy_session_generation()
	var receipt: Dictionary = native_world.get_applied_liquid_construction_receipt()
	_accepted_physics_demo = {"definition":staged.definition.duplicate(true),"policy":staged.policy.duplicate(),
		"normalization":staged.setup.normalization,"maximum_rule_radius":staged.setup.maximum_rule_radius,
		"generation":_physics_pit_generation,"receipt_hash":receipt.receipt_hash,
		"transport":str(native_world.get_liquid_run_receipt({}).components.transport_profile)}
	_curated_demo_id = "";_accepted_demo = {};_accepted_level = null
	_liquid_tower_active = false;_liquid_water_active = false
	microscenario_definition = staged.definition.duplicate(true);microscenario_liquid_policy = staged.policy.duplicate()
	microscenario_liquid_setup = {"intent":"exploratory","normalization":staged.setup.normalization,
		"maximum_rule_radius":staged.setup.maximum_rule_radius}
	tower_context = {"active":false,"micro_active":false,"water_active":false,"status":"Physics Pit / explicit liquid policy",
		"scenario_request_serial":staged.serial,"scenario_request_applied":true}
	tower_active = false;tower_schedule.clear();tower_inputs.clear();water_actions.clear();tower_single_step = false
	camera_origin = Vector2(staged.definition.camera_origin[0],staged.definition.camera_origin[1]);camera_follow_enabled = false
	character_position = player.position;paused = true;microscenario_error = ""
	_update_liquid_context(true);force_publication = true;_publish_world();update_shader_parameters();update_status()

func _adopt_web_reference_candidate(candidate: RefCounted, character: CyberSampledCharacter) -> void:
	_close_prepared_reference_bodies()
	for body: RigidBody2D in [test_rigid_body_1,test_rigid_body_2,test_rigid_body_3]:
		body.freeze = true;body.collision_layer = 0;body.collision_mask = 0
	rapier_bridge.shutdown()
	_accepted_reference_candidate = candidate;rapier_bridge = candidate.physics_bridge();rigid_bodies = candidate.bodies()
	player = character;last_hard_surface_revision = native_world.get_hard_surface_revision();rapier_start_error = OK
	candidate.adopt()

func _cancel_web_reference(reason: String = "Prepared Physics Pit retired") -> void:
	if _pending_web_reference==null: return
	var staged: RefCounted = _pending_web_reference
	_pending_web_reference = null;pending_microscenario_apply.clear()
	staged.close();microscenario_error = reason
	tower_context["scenario_request_serial"] = staged.serial;tower_context["scenario_request_applied"] = false
	_update_liquid_context(true)

func _accepted_physics_retains_transport(transport: String) -> bool:
	return not _accepted_physics_demo.is_empty() and _physics_pit_is_current() \
		and _accepted_physics_demo.generation==_physics_pit_generation and transport==_accepted_physics_demo.transport \
		and native_world.get_applied_liquid_construction_receipt().get("receipt_hash","")==_accepted_physics_demo.receipt_hash

func _commit_web_prepared_sampled(bridge: Variant, token: int, definition: Dictionary) -> bool:
	var staged: Dictionary = CyberSimulationWorker.PreparedSampled.prepare(bridge,native_world,token,
		Vector2(definition.player_start[0],definition.player_start[1]),bool(definition.player_enabled),
		player.runtime_enclosure_recovery_enabled,player.active_profile(),[],0)
	if not staged.ok:
		microscenario_error = staged.error
		return false
	if not bridge.commit_liquid_world(native_world,token): return false
	player = staged.character
	return true

func _apply_prepared_liquid_tower(policy: PackedInt32Array, normalize_water: bool, radius: int,
		resolved: Dictionary) -> bool:
	if not ready_to_play or not resolved.get("ok",false) or not water_blind_set.is_empty() or not water_active_blind_label.is_empty(): return false
	if not rigid_bodies.is_empty():
		microscenario_error = "Prepared Tower requires its existing sampled owner; prior session retained"
		return false
	var definition: Dictionary = CyberMicroScenarioCatalogue.prepared_tower(resolved.profile,tower_floor)
	var setup: Dictionary = {"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "",
		"maximum_rule_radius":radius,"owner_execution":CyberSimulationWorker.prepared_owner_execution(definition, {
			"simulation_window_enabled":native_world.get_simulation_window_enabled(),
			"cadence_lod_enabled":native_world.get_cadence_lod_enabled(),"liquid_surface_adhesion_enabled":liquid_surface_adhesion_enabled,
			"horizontal_buffer":simulation_margin.x,"vertical_buffer":simulation_margin.y})}
	if not micro_host.install(native_world,definition,microscenario_mode,true,policy,setup,_commit_web_prepared_sampled.bind(definition)):
		microscenario_error = micro_host.last_error
		return false
	_liquid_tower_active = true
	_curated_demo_id = "";_accepted_demo = {};_accepted_level = null
	_liquid_water_active = false
	microscenario_error = "Installed session apparatus failed: " + micro_host.last_error if micro_host.summary().get("failed",false) else ""
	microscenario_definition = definition.duplicate(true);microscenario_liquid_policy = policy.duplicate()
	microscenario_liquid_setup = setup.duplicate(true);microscenario_liquid_setup.erase("owner_execution")
	tower_profile = resolved.profile.duplicate(true)
	tower_context = {"active":true,"micro_active":false,"water_active":false,"profile":tower_profile.duplicate(true),
		"profile_hash":str(resolved.hash),"status":"Experiment Tower / explicit liquid policy","microscenario":micro_host.summary()}
	tower_schedule.clear();tower_inputs.clear();tower_single_step = false
	paused = true;camera_follow_enabled = false
	camera_origin = Vector2(definition.camera_origin[0],definition.camera_origin[1]);character_position = player.position
	_update_liquid_context(true);force_publication = true;_publish_world()
	return true

func _install_web_microscenario(definition: Dictionary, mode: String, liquid_policy: Variant = null,
		controlled_setup: Dictionary = {}) -> bool:
	if str(definition.get("id", "")).begins_with("experimental/blacksite/"): return false
	if not ready_to_play or not water_blind_set.is_empty() or not water_active_blind_label.is_empty(): return false
	_cancel_web_reference("Superseded by a MicroScenario request")
	if not CyberMicroScenarioCatalogue.player_configuration(
		str(definition.get("id", ""))
	).is_empty():
		microscenario_error = (
			"PLAY-VAL player-representation fixtures require the desktop "
			+ "asynchronous owner; Web execution is intentionally refused."
		)
		return false
	var guard: Callable = Callable()
	if not controlled_setup.is_empty():
		var checked: Dictionary = CyberMicroScenarioContract.validate(definition)
		if not checked.ok:
			microscenario_error = str(checked.error)
			return false
		controlled_setup = controlled_setup.duplicate(true)
		controlled_setup.owner_execution = CyberSimulationWorker.prepared_owner_execution(checked.definition, {
			"simulation_window_enabled":native_world.get_simulation_window_enabled(),
			"cadence_lod_enabled":native_world.get_cadence_lod_enabled(),
			"liquid_surface_adhesion_enabled":liquid_surface_adhesion_enabled,
			"horizontal_buffer":simulation_margin.x,"vertical_buffer":simulation_margin.y})
		guard = _commit_web_prepared_sampled.bind(checked.definition)
	if not micro_host.install(native_world, definition, mode, true, liquid_policy, controlled_setup, guard):
		microscenario_error = micro_host.last_error
		if native_world.has_method(&"get_liquid_construction_attempt"):
			tower_context["liquid_construction_attempt"] = native_world.get_liquid_construction_attempt()
		return false
	if microscenario_panel != null: microscenario_panel.workbench.cancel_declared_window()
	var installed: Dictionary = micro_host.definition()
	_curated_demo_id = "";_accepted_demo = {};_accepted_level = null
	_liquid_tower_active = false
	_liquid_water_active = false
	microscenario_definition = installed.duplicate(true)
	microscenario_liquid_policy = liquid_policy.duplicate() if liquid_policy != null else null
	microscenario_liquid_setup = controlled_setup.duplicate(true)
	microscenario_mode = mode
	microscenario_error = "Installed session apparatus failed: " + micro_host.last_error \
		if micro_host.summary().get("failed", false) else ""
	paused = true
	tower_active = true
	demo_id = "experiment_tower"
	tower_schedule.clear()
	tower_inputs.clear()
	water_actions.clear()
	tower_single_step = false
	pending_microscenario_apply.clear()
	current_view_size = Vector2i(480,270)
	camera_follow_enabled = false
	camera_origin = Vector2(installed.camera_origin[0], installed.camera_origin[1])
	if controlled_setup.is_empty(): player.reset(Vector2(installed.player_start[0], installed.player_start[1]))
	character_position = player.position
	tower_context = {"active":true, "micro_active":true, "water_active":false,
		"microscenario":micro_host.summary(), "status":"MicroScenario " + str(installed.id),
		"liquid_construction_receipt":native_world.get_applied_liquid_construction_receipt() \
			if native_world.has_method(&"get_applied_liquid_construction_receipt") else {}}
	_update_liquid_context(true)
	_activate_physics(bool(installed.body_enabled))
	showcase_presentation.installed(installed)
	blacksite_nine_presentation.installed(installed)
	if CyberShowcaseTiles.contains(str(installed.id)):
		demo_id = CyberShowcaseTiles.demo_id(str(installed.id))
	elif str(installed.id) == CyberDemoWorlds.BlacksiteNine.SCENARIO_ID:
		demo_id = CyberDemoWorlds.BlacksiteNine.ID
	force_publication = true
	_publish_world()
	update_shader_parameters()
	return true

func microscenario_capture() -> void:
	if not water_blind_set.is_empty() or not water_active_blind_label.is_empty() or not micro_host.active(): return
	_write_microscenario_capture(micro_host.capture(CyberMicroScenarioIdentity.current()))

func tower_observation() -> void:
	if tower_context.get("water_active",false):
		water_current_integer=int(_water_observe_web().get("water_integer",water_current_integer))
		_update_water_web_context()
	super.tower_observation()

func _update_water_web_context() -> void:
	if not tower_context.get("water_active",false): return
	tower_context["tick"]=int(native_world.get_tick_index())
	tower_context["paused"]=paused
	tower_context["water_actions"]=water_action_history.duplicate(true)
	tower_context["water_observations"]=water_observations.duplicate(true)
	tower_context["water_accounting"]={"initial_integer":water_initial_integer,
		"initial_requested_numerator_255":water_initial_requested_numerator_255,
		"initial_quantization_error_numerator_255":water_initial_quantization_error_numerator_255,
		"explicit_source":water_explicit_source,"explicit_sink":water_explicit_sink,
		"outflow":0,"current":water_current_integer}

func tower_reset() -> void:
	if _liquid_tower_active and tower_active and not tower_context.get("micro_active",false) and not tower_context.get("water_active",false):
		_apply_prepared_liquid_tower(microscenario_liquid_policy,microscenario_liquid_setup.get("normalization","") == "water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),CyberTransportProfiles.resolve(tower_profile))
		return
	tower_schedule.clear();tower_inputs.clear()
	water_actions.clear();water_action_history.clear();water_observations.clear()
	select_demo("experiment_tower")

func tower_apply_profile(resolved: Dictionary) -> void:
	if _liquid_tower_active and not tower_context.get("micro_active",false) and not tower_context.get("water_active",false):
		_apply_prepared_liquid_tower(microscenario_liquid_policy,microscenario_liquid_setup.get("normalization","") == "water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),resolved)
		return
	if not resolved.get("ok", false) or not micro_host.install(native_world, CyberMicroScenarioCatalogue.tower(resolved.profile), microscenario_mode):
		tower_context["status"] = "Rejected / "+micro_host.last_error
		return
	_water_end_blind_session()
	tower_profile = resolved.profile.duplicate(true)
	tower_context = {"profile":tower_profile.duplicate(true),"profile_hash":str(resolved.hash),"status":str(tower_profile.name)+" / profile v1 "+str(resolved.hash).left(12)}
	tower_schedule.clear();tower_inputs.clear()
	tower_floor_select(tower_floor)
	force_publication = true

func tower_floor_select(index: int) -> void:
	if water_controlled_run_active() or tower_context.get("micro_active", false): return
	tower_schedule.clear()
	tower_floor = clampi(index,0,4)
	paused = true
	player.reset(CyberExperimentTower.landing(tower_floor))
	character_position = player.position
	camera_follow_enabled = false
	camera_origin = Vector2(0,CyberExperimentTower.floor_y(tower_floor))

func tower_release(index: int) -> void:
	if tower_context.get("water_active",false) or tower_context.get("micro_active",false): return
	var plugs: Array[Rect2i] = CyberExperimentTower.plugs(tower_floor)
	if index < 0 or index >= plugs.size(): return
	var plug: Rect2i = plugs[index]
	for y: int in range(plug.position.y,plug.end.y):
		for x: int in range(plug.position.x,plug.end.x): native_world.paint_disc(x,y,0,0,0)
	force_publication = true

func tower_command(command: Dictionary) -> bool:
	if tower_context.get("micro_active", false) and (command.has("release") or command.has("schedule") or command.has("floor")): return false
	if water_controlled_run_active() and (
		command.has("release") or command.has("schedule")
	):
		return false
	if command.has("step"):
		paused = true
		tower_single_step = true
	if command.has("release"):
		tower_release(int(command.release))
		if command.get("adjacent",false): tower_release(int(command.release)+1)
	if command.has("schedule"):
		var tick: int = int(native_world.get_tick_index())
		tower_schedule = [[tick+30,int(command.schedule),tower_floor],[tick+90,int(command.schedule)+1,tower_floor]]
	if tower_inputs.size() < 256: tower_inputs.append({"tick":int(native_world.get_tick_index()),"command":command.duplicate(true)})
	tower_context["inputs"] = tower_inputs.duplicate(true)
	return true

func _ready() -> void:
	setup_tower_panel()
	if OS.has_feature("web") and OS.has_feature("threads") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('test') === '1' && new URLSearchParams(location.search).get('parity') === '1'", true)):
		worker_probe = await CyberWebWorkerProbe.run(get_tree())
		print("WEB_WORKER_PARITY ", JSON.stringify(worker_probe))
	$Layout/World.custom_minimum_size.y = 180
	$Layout/Status.custom_minimum_size.y = 38
	$Layout/Status.add_theme_font_size_override("font_size", 14)
	$Layout/Help.add_theme_font_size_override("font_size", 14)
	$Layout/Title.text = "CYBERSAND / M11"
	$Layout/Help.text = "A/D move · Space jetpack · LMB paint primary · MMB paint secondary · RMB erase · 1–6 slots · Q/E materials · X blast · P pause · R reset · Esc menu"
	for body: RigidBody2D in [test_rigid_body_1, test_rigid_body_2, test_rigid_body_3]:
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
	# The staged export chooses a bounded pool; compatibility stays serial.
	if OS.has_feature("web") and not OS.has_feature("threads"):
		ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	Engine.max_physics_steps_per_frame = 2
	if CyberWebCapabilities.native_available():
		logical_threads = CyberWebCapabilities.reported_logical_threads()
		native_world = ClassDB.instantiate(&"CyberNativeCellWorld")
		demo_bridge = ClassDB.instantiate(&"CyberDemoBridge")
		var probe: Dictionary = CyberWebCapabilities.rapier_probe()
		rapier_available = bool(probe.ok)
		rapier_reason = str(probe.reason)
		print("WEB_RAPIER_PROBE ", JSON.stringify(probe))
	ui = CyberWebDemoMenu.new()
	add_child(ui)
	ui.setup(self)
	if native_world == null or demo_bridge == null:
		ui.capability.text = "FATAL / CYBERSAND WASM UNAVAILABLE"
		ui.message("The native extension did not load. This build cannot run the CyberSand simulation.")
		push_error("CyberSand native Web extension unavailable")
		return
	render_channels = 2
	render_image_format = Image.FORMAT_RG8
	image = Image.create_empty(1024, 1024, false, render_image_format)
	image.fill(Color(0, 0, 0, 1))
	texture = ImageTexture.create_from_image(image)
	previous_texture = ImageTexture.create_from_image(image)
	material_appearance_lut = CyberMaterialAppearanceLut.create_texture()
	material_appearance_program = CyberMaterialAppearanceLut.create_program_texture()
	world_view.texture = texture
	world_shader.set_shader_parameter("current_world_texture", texture)
	world_shader.set_shader_parameter("previous_world_texture", previous_texture)
	world_shader.set_shader_parameter("material_lut", material_appearance_lut)
	world_shader.set_shader_parameter("material_program_lut", material_appearance_program)
	world_shader.set_shader_parameter("material_lut_size", Vector2(CyberMaterialAppearanceLut.ATLAS_WIDTH, CyberMaterialAppearanceLut.ATLAS_HEIGHT))
	setup_glow_pipeline()
	set_quality(1)
	ready_to_play = true
	select_demo(demo_id, false)
	ui.capability.text = CyberWebCapabilities.status(native_world, rapier_available)
	if OS.has_feature("threads"):
		ui.capability.text += " · AUTO (%d logical threads)" % logical_threads
	ui.message(rapier_reason if not rapier_available else "")
	_init_browser_test()
	print("WEB_DEMO_READY ", ui.capability.text)
	if test_enabled and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('liquid-host-test') === '1'",true)):
		set_process(false);set_physics_process(false)
		var result: Dictionary = LiquidHostWebProbe.run(self)
		print("WEB_LIQUID_HOST ",JSON.stringify(result))
		JavaScriptBridge.eval("var p=document.createElement('pre');p.id='cybersand-liquid-host-result';p.textContent="+JSON.stringify(JSON.stringify(result))+";document.body.appendChild(p);fetch('/physics-results',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({userAgent:navigator.userAgent,isolated:crossOriginIsolated,result:"+JSON.stringify(result)+"})}).then(r=>{if(!r.ok)throw new Error('liquid host result POST '+r.status);console.log('LIQUID_HOST_EVIDENCE_SAVED',r.status)}).catch(e=>console.error('LIQUID_HOST_EVIDENCE_POST_FAILED',String(e)));",true)
		return
	if test_enabled and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('water') === '1'", true)):
		set_process(false)
		set_physics_process(false)
		var result: Dictionary = WaterFeelWebProbe.run_controller(self,world_shader)
		result["runtime_identity"] = water_runtime_identity()
		print("WEB_WATER_FEEL ", JSON.stringify(result))
		JavaScriptBridge.eval("var p=document.createElement('pre');p.id='cybersand-water-result';p.textContent="+JSON.stringify(JSON.stringify(result))+";document.body.appendChild(p);fetch('/physics-results',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({userAgent:navigator.userAgent,isolated:crossOriginIsolated,result:{ok:"+JSON.stringify(result.ok)+",results:["+JSON.stringify(result)+"]}})});", true)
		return
	if test_enabled and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('transport') === '1'",true)):
		set_process(false);set_physics_process(false)
		var result: Dictionary=await CyberTransportProbe.run(self,4 if OS.has_feature("threads") else 1)
		result["fault"]=await CyberTickFailureProbe.run(get_tree(),self)
		result["regions"]=await CyberTickFailureProbe.run_regions(get_tree(),self)
		result.ok=result.ok and result.fault.ok and result.regions.ok
		print("WEB_TRANSPORT ",JSON.stringify(result))
		JavaScriptBridge.eval("var p=document.createElement('pre');p.id='cybersand-transport-result';p.textContent="+JSON.stringify(JSON.stringify(result))+";document.body.appendChild(p);fetch('/physics-results',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({userAgent:navigator.userAgent,isolated:crossOriginIsolated,result:"+JSON.stringify(result)+"})});",true)
		return
	if test_enabled and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('interaction') === '1'", true)):
		set_process(false)
		set_physics_process(false)
		var workers: int = 4 if OS.has_feature("threads") else 1
		var policy: Dictionary = await CyberInteractionPolicyProbe.run(false,workers,self)
		policy["fault"] = await CyberTickFailureProbe.run(get_tree(),self)
		policy["regions"] = await CyberTickFailureProbe.run_regions(get_tree(),self)
		policy.ok = policy.ok and policy.fault.ok and policy.regions.ok
		var result: Dictionary = {"ok":policy.ok,"results":[policy]}
		print("WEB_INTERACTION_POLICY ",JSON.stringify(result))
		JavaScriptBridge.eval("var p=document.createElement('pre');p.id='cybersand-interaction-result';p.textContent="+JSON.stringify(JSON.stringify(result))+";document.body.appendChild(p);fetch('/physics-results',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({userAgent:navigator.userAgent,isolated:crossOriginIsolated,result:"+JSON.stringify(result)+"})});",true)
		return
	if test_enabled and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('rem003') === '1'", true)):
		set_process(false)
		set_physics_process(false)
		var workers: int = 4 if OS.has_feature("threads") else 1
		var cases: Array = [
			{"id":"rem003-ordinary","mode":"player","material":CyberCellWorld.SAND,
				"ticks":240,"workers":workers,"player_after_tick":true},
			{"id":"rem003-hard","mode":"player","material":CyberCellWorld.SAND,
				"ticks":240,"workers":workers,"player_initial_vy":86.0,"player_after_tick":true},
			{"id":"rem003-hard-terrain","mode":"player","material":0,"layout":"hard",
				"ticks":240,"workers":workers,"player_after_tick":true},
			{"id":"rem003-water","mode":"player","material":CyberCellWorld.WATER,
				"ticks":240,"workers":workers,"player_after_tick":true},
		]
		var result: Dictionary = await CyberPhysicsCharacterisation.run(self,cases)
		var counts: Dictionary = {}
		for report: Dictionary in result.get("results", []):
			counts[str(report.get("spec",{}).get("id",""))] = int(
				report.get("player_granular_disturbance_total",-1)
			)
		var candidate_ok: bool = (
			bool(result.get("ok",false))
			and int(counts.get("rem003-ordinary",-1)) == 1
			and int(counts.get("rem003-hard",-1)) == 2
			and int(counts.get("rem003-hard-terrain",-1)) == 0
			and int(counts.get("rem003-water",-1)) == 0
		)
		result["rem003_counts"] = counts
		result["ok"] = candidate_ok
		print("WEB_REM003_PLAYER_GRANULAR ",JSON.stringify(result))
		JavaScriptBridge.eval("var p=document.createElement('pre');p.id='cybersand-rem003-result';p.textContent="+JSON.stringify(JSON.stringify(result))+";document.body.appendChild(p);fetch('/physics-results',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({userAgent:navigator.userAgent,isolated:crossOriginIsolated,result:"+JSON.stringify(result)+"})});",true)
		return
	if test_enabled and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('physics') === '1'", true)):
		set_process(false)
		set_physics_process(false)
		var workers: int = 4 if OS.has_feature("threads") else 1
		var cases: Array = []
		for seed: int in range(5):
			for spec: Dictionary in [
				{"id":"P1","mode":"cellular","material":14,"top":2},
				{"id":"P2","mode":"cellular","material":2,"top":33},
				{"id":"P3","mode":"player","material":14},
				{"id":"P4","mode":"barrel","material":2},
				{"id":"hard","mode":"barrel","material":0,"layout":"hard"}]:
				cases.append(spec.merged({"seed":seed,"ticks":1800,"workers":workers}))
		var result: Dictionary = await CyberPhysicsCharacterisation.run(self,cases)
		print("WEB_PHYSICS_CHARACTERISATION ",JSON.stringify(result))
		JavaScriptBridge.eval("window.cybersandPhysics = " + JSON.stringify(result) + "; var p=document.createElement('pre');p.id='cybersand-physics-result';p.textContent=JSON.stringify(window.cybersandPhysics);document.body.appendChild(p);fetch('/physics-results',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({userAgent:navigator.userAgent,isolated:crossOriginIsolated,result:window.cybersandPhysics})}).then(r=>console.log('PHYSICS_EVIDENCE_SAVED',r.status));",true)
		return
	if test_enabled and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('tickfault') === '1'", true)):
		tick_failure_test = await CyberTickFailureProbe.run(get_tree(), self)
		print("WEB_TICK_FAILURE_TEST ", JSON.stringify(tick_failure_test))
		interest_region_test = await CyberTickFailureProbe.run_regions(get_tree(), self)
		print("WEB_INTEREST_REGION_TEST ", JSON.stringify(interest_region_test))
		_publish_test_state()
	if test_enabled and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('rapier') === '1'", true)):
		rapier_test = await CyberWebRapierProbe.run(self)
		print("WEB_RAPIER_TEST ", JSON.stringify(rapier_test))
		_publish_test_state()

func _exit_tree() -> void:
	_cancel_web_reference("Application closed")
	_close_prepared_reference_bodies()
	rapier_bridge.shutdown()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		focused = false
		input_armed = false
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		focused = true
		input_armed = false

func release_game_input() -> void:
	input_armed = false

func _update_liquid_context(force: bool = false) -> void:
	if native_world == null or not native_world.has_method(&"get_liquid_policy_session_generation"): return
	var generation: int = int(native_world.get_liquid_policy_session_generation())
	if not force and generation == _liquid_context_generation: return
	_liquid_context_generation = generation
	tower_context["liquid_solver_policy"] = native_world.get_liquid_solver_policy()
	tower_context["liquid_host_observation"] = micro_host.liquid_host_observation()
	if _accepted_level != null:
		var imported_identity: Dictionary = _accepted_level.identity(native_world)
		if imported_identity.is_empty(): _accepted_level = null
		else: tower_context["liquid_host_observation"] = imported_identity
	tower_context["liquid_construction_receipt"] = native_world.get_applied_liquid_construction_receipt() \
		if native_world.has_method(&"get_applied_liquid_construction_receipt") else {}
	tower_context["liquid_construction_attempt"] = native_world.get_liquid_construction_attempt() \
		if native_world.has_method(&"get_liquid_construction_attempt") else {}

func _process(delta: float) -> void:
	_advance_web_reference()
	if native_world != null: tower_context["tick"]=int(native_world.get_tick_index());tower_context["paused"]=paused
	_update_liquid_context()
	if native_world != null: _update_water_web_context()
	tower_context["microscenario"] = micro_host.summary()
	tower_panel.refresh(tower_active,tower_floor,tower_context)
	_refresh_microscenario_controls()
	if _pending_web_reference!=null: return
	if not ready_to_play:
		return
	frame_time_ms = delta * 1000.0
	if (
		not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		and not Input.is_physical_key_pressed(KEY_A)
		and not Input.is_physical_key_pressed(KEY_D)
		and not Input.is_physical_key_pressed(KEY_SPACE)
	):
		input_armed = focused and not ui.open and not _blacksite_keyboard_blocked()
	if not ui.open and focused:
		update_camera(delta)
	_sync_web_colliders()
	publication_clock += delta
	if force_publication or publication_clock >= 1.0 / float(render_snapshot_hz):
		publication_clock = fmod(publication_clock, 1.0 / float(render_snapshot_hz))
		_publish_world()
	update_shader_parameters()
	if rigid_bodies.is_empty():
		for i: int in range(3):
			world_shader.set_shader_parameter("rigid_body_data_%d" % i, Vector4(-1000, -1000, 0, 0))
	status_accumulator += delta
	if status_accumulator >= STATUS_INTERVAL:
		status_accumulator = 0.0
		update_status()
	if test_enabled:
		test_clock += delta
		if test_clock >= 0.15:
			test_clock = 0
			_publish_test_state()

func _physics_process(_delta: float) -> void:
	if not ready_to_play or ui.open or not focused or _pending_web_reference!=null:
		return
	native_world.set_simulation_window(Vector2i(camera_origin.floor()), current_view_size, simulation_margin.x, simulation_margin.y)
	micro_host.apply_interest()
	if native_world.has_failed():
		_report_tick_failure()
		return
	var controls_allowed: bool = input_armed and not _blacksite_keyboard_blocked()
	if controls_allowed:
		_paint_pointer()
	if paused and not tower_single_step:
		return
	tower_single_step = false
	if tower_context.get("water_active",false):
		if not _water_apply_due_web_actions(): return
	elif micro_host.active() and not micro_host.before_tick():
		paused = true
		tower_context["status"] = micro_host.last_error
		return
	if tower_active:
		for release: Array in tower_schedule.duplicate():
			if int(release[2]) == tower_floor and int(native_world.get_tick_index())+1 >= int(release[0]):
				tower_release(int(release[1]))
				tower_schedule.erase(release)
	if rapier_bridge.is_initialized():
		if rapier_bridge.pending_hard_surface_chunks() > 0:
			return
		rapier_bridge.apply_cellular_results(int(native_world.get_tick_index()), native_world.rigid_body_results())
		rapier_bridge.step()
		native_world.prepare_rigid_body_coupling(rapier_bridge.pack_body_states(), true)
	else:
		native_world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	if not native_world.simulation_tick():
		_report_tick_failure()
		return
	if micro_host.active() and not micro_host.after_tick():
		paused = true
		tower_context["status"] = micro_host.last_error
		return
	total_moves += int(native_world.get_moves_last_tick())
	var horizontal: float = get_horizontal_input() if controls_allowed else 0.0
	var jetpack: bool = controls_allowed and Input.is_physical_key_pressed(KEY_SPACE)
	if not tower_context.get("micro_active", false) or micro_host.player_enabled():
		player.simulate(1.0 / 60.0, horizontal, jetpack, native_world)
	character_position = player.position

func _report_tick_failure() -> void:
	paused = true
	input_armed = false
	ui.show_page("home")
	var prepared: bool = native_world.has_method(&"get_applied_liquid_construction_receipt") \
		and not native_world.get_applied_liquid_construction_receipt().is_empty()
	var recovery: String = ("Choose a Current demo or use an unarmed level import to recover. Prepared Restart requires a healthy World. "
		if prepared else "Restart world or load a saved level. ")
	ui.message("Simulation stopped. " + recovery + str(native_world.get_last_tick_error()))

func _world_pointer() -> Vector2i:
	var content: Rect2 = view_content_rect()
	var local: Vector2 = world_view.get_local_mouse_position()
	if not content.has_point(local) or content.size.x <= 0 or content.size.y <= 0:
		return Vector2i(-1, -1)
	var point: Vector2 = camera_origin.floor() + (local - content.position) / content.size * Vector2(current_view_size)
	return Vector2i(point.floor())

func queue_brush_mutation(
		world_x: int,
		world_y: int,
		radius: int,
		material_id: int,
		emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
	) -> bool:
	if water_controlled_run_active() or not _microscenario_tool_allowed(material_id):
		return false
	if material_id==CyberCellWorld.EMPTY:
		native_world.paint_disc(world_x,world_y,radius,0,0)
	else:
		native_world.emit_disc(world_x,world_y,radius,material_id,emission_flags)
	paint_commands+=1
	return true

func queue_brush_footprint_mutation(
		world_x: int,
		world_y: int,
		material_id: int,
		emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
	) -> bool:
	if water_controlled_run_active() or not _microscenario_tool_allowed(material_id):
		return false
	if brush_shape == "circle" and (brush_size_px & 1) == 1:
		return queue_brush_mutation(
			world_x,
			world_y,
			(brush_size_px - 1) / 2,
			material_id,
			emission_flags
		)
	var cells: PackedInt32Array = brush_footprint_cells(world_x, world_y)
	if cells.is_empty():
		return false
	for offset: int in range(0, cells.size(), 2):
		if material_id == CyberCellWorld.EMPTY:
			native_world.paint_disc(cells[offset], cells[offset + 1], 0, 0, 0)
		else:
			native_world.emit_disc(
				cells[offset],
				cells[offset + 1],
				0,
				material_id,
				emission_flags
			)
	paint_commands += 1
	return true


func queue_explosion_mutation(world_x: int, world_y: int, radius: int) -> bool:
	if water_controlled_run_active() or tower_context.get("micro_active", false): return false
	return bool(demo_bridge.queue_explosion(native_world,world_x,world_y,radius))

func set_liquid_surface_adhesion(enabled: bool) -> bool:
	if _microscenario_execution_locked(): return false
	if water_controlled_run_active(): return false
	liquid_surface_adhesion_enabled=enabled
	native_world.set_liquid_surface_adhesion_enabled(enabled)
	return true

func _paint_pointer() -> void:
	if showcase_presentation != null and showcase_presentation.input_blocked(): return
	if blacksite_nine_presentation != null and blacksite_nine_presentation.input_blocked(): return
	if microscenario_panel != null and microscenario_panel.modal_open(): return
	if tower_profile_panel.visible: return
	var point: Vector2i = _world_pointer()
	if point.x < 0 or point.y < 0 or point.x >= 1024 or point.y >= 1024:
		return
	var material_id: int = brush_material_for_buttons(
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)
	if material_id < 0:
		return
	var emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
	if material_id != CyberCellWorld.EMPTY and coherent_liquid_emission:
		emission_flags = CyberCellWorld.EMISSION_FLAG_COHERENT_LIQUID
	queue_brush_footprint_mutation(
		point.x,
		point.y,
		material_id,
		emission_flags
	)

func _publish_world() -> void:
	if native_world.has_failed():
		return
	var packet: Dictionary = native_world.take_render_snapshot(force_publication)
	var rectangles: PackedInt32Array = packet.get("rectangles", PackedInt32Array())
	var cells: PackedByteArray = packet.get("cells", PackedByteArray())
	if rectangles.is_empty():
		return
	if upload_texture_patches(rectangles, cells, int(native_world.get_revision()), 2):
		force_publication = false
		last_render_patch_count = rectangles.size() / 6
		last_render_patch_bytes = cells.size()
		last_render_was_full_refresh = bool(packet.get("full_refresh", false))
	else:
		force_publication = true
		rejected_render_snapshot_count += 1

func _sync_web_colliders() -> void:
	if native_world.has_failed():
		return
	if not rapier_bridge.is_initialized():
		return
	var revision: int = int(native_world.get_hard_surface_revision())
	if revision != last_hard_surface_revision:
		var rectangles: PackedInt32Array = native_world.get_hard_surface_chunk_rectangles()
		if rapier_bridge.queue_hard_surface_chunk_snapshot(rectangles):
			last_hard_surface_revision = revision
	rapier_bridge.process_hard_surface_collider_budget(HARD_SURFACE_CHUNKS_PER_FRAME, HARD_SURFACE_FRAME_BUDGET_USEC)

func _activate_physics(active: bool, saved_bodies: Array = []) -> void:
	_close_prepared_reference_bodies()
	_accepted_physics_demo = {};_physics_pit_generation = -1
	for body: RigidBody2D in [test_rigid_body_1, test_rigid_body_2, test_rigid_body_3]:
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
	rapier_bridge.shutdown()
	rigid_bodies.clear()
	last_hard_surface_revision = -1
	if not active or not rapier_available:
		return
	rigid_bodies = [test_rigid_body_1, test_rigid_body_2, test_rigid_body_3]
	for body: RigidBody2D in rigid_bodies:
		body.freeze = false
		body.collision_layer = 1
		body.collision_mask = 1
	var sizes: PackedVector2Array = PackedVector2Array([Vector2(8, 14), Vector2(8, 14), Vector2(8, 14)])
	rapier_start_error = rapier_bridge.initialize(get_world_2d().space, rigid_bodies, sizes)
	if rapier_start_error != OK:
		rapier_available = false
		_activate_physics(false)
		return
	for i: int in range(3):
		var position: Vector2 = Vector2([124, 244, 384][i], 90)
		var rotation: float = 0.0
		if i < saved_bodies.size():
			position = Vector2(saved_bodies[i][0], saved_bodies[i][1])
			rotation = float(saved_bodies[i][2])
		rapier_bridge.reset_body(i, position, rotation)
		if i < saved_bodies.size():
			var rid: RID = rigid_bodies[i].get_rid()
			PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(saved_bodies[i][3], saved_bodies[i][4]))
			PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, float(saved_bodies[i][5]))
			PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, bool(saved_bodies[i][6]))
	rapier_bridge.refresh_all_states()
	rapier_bridge.reset_result_tracking()
	_sync_web_colliders()

func select_demo(id: String, close: bool = true) -> void:
	_cancel_web_reference("Superseded by a Current demo request")
	if not ready_to_play or not CyberDemoWorlds.valid_id(id):
		return
	if id == CyberDemoWorlds.BlacksiteNine.ID:
		if blacksite_nine_presentation.launch() and close:
			ui.close_menu()
		return
	if CyberShowcaseTiles.contains(id):
		if showcase_presentation.launch(id) and close:
			ui.close_menu()
		return
	var leaving_showcase: bool = showcase_presentation.active() or blacksite_nine_presentation.active()
	if id == "physics_pit" and not rapier_available:
		ui.message("Physics Pit is unavailable in this build.")
		return
	var built: bool = false
	if id == "experiment_tower":
		var resolved: Dictionary = CyberTransportProfiles.resolve(tower_profile)
		built = micro_host.install(native_world, CyberMicroScenarioCatalogue.tower(resolved.profile), microscenario_mode)
		if built: tower_context = {"active":true,"profile":tower_profile.duplicate(true),"profile_hash":str(resolved.hash),"status":str(tower_profile.name)+" / profile v1 "+str(resolved.hash).left(12),"water_active":false}
	else:
		built = demo_bridge.build_world(native_world, CyberDemoWorlds.rectangles(id))
	if not built:
		ui.message(str(demo_bridge.get_last_error()))
		return
	_accepted_level = null
	_curated_demo_id = id if id in ["material_lab","waterworks","foundry","neon_works"] else ""
	_curated_demo_generation = native_world.get_liquid_policy_session_generation()
	_accepted_demo = {}
	_liquid_tower_active = false
	_liquid_water_active = false
	_water_end_blind_session()
	microscenario_liquid_policy = null;microscenario_liquid_setup = {};microscenario_definition = {}
	if id != "experiment_tower":
		micro_host.clear()
		tower_context = {}
	tower_schedule.clear();tower_inputs.clear();tower_single_step=false
	demo_id = id
	player.reset(CyberDemoWorlds.spawn(id))
	character_position = player.position
	camera_origin = Vector2.ZERO
	camera_follow_enabled = false
	paused = id == "experiment_tower"
	tower_active = id == "experiment_tower"
	if tower_active: tower_floor_select(tower_floor)
	if leaving_showcase:
		set_quality(quality)
	total_moves = 0
	_activate_physics(id == "physics_pit")
	if id=="physics_pit": _physics_pit_generation = native_world.get_liquid_policy_session_generation()
	native_world.set_liquid_surface_adhesion_enabled(liquid_surface_adhesion_enabled)
	force_publication = true
	_publish_world()
	update_shader_parameters()
	update_status()
	if close:
		ui.close_menu()

func set_quality(index: int) -> bool:
	if _microscenario_execution_locked(): return false
	if water_controlled_run_active(): return false
	quality = clampi(index, 0, 2)
	var views: Array[Vector2i] = [Vector2i(320, 180), Vector2i(480, 270), Vector2i(640, 360)]
	var margins: Array[Vector2i] = [Vector2i(16, 18), Vector2i(32, 36), Vector2i(64, 72)]
	current_view_size = views[quality]
	simulation_margin = margins[quality]
	render_snapshot_hz = [30, 45, 60][quality]
	camera_origin = clamped_camera_origin(camera_origin)
	if native_world != null:
		native_world.set_simulation_window(Vector2i(camera_origin.floor()), current_view_size, simulation_margin.x, simulation_margin.y)
	if ui != null and ui.notice != null:
		ui.message("%s / %d×%d view / %d Hz publication" % [["LOW", "NORMAL", "HIGH"][quality], current_view_size.x, current_view_size.y, render_snapshot_hz])
	return true

func liquid_comparison_arm_import(policy: PackedInt32Array, normalize_water: bool,
		exploratory: bool, radius: int = 2) -> bool:
	if not ready_to_play or not demo_bridge.has_method(&"prepare_liquid_level") or not exploratory:
		microscenario_error = "Prepared level imports require Exploratory and the rebuilt native importer"
		return false
	var checked: Dictionary = demo_bridge.validate_liquid_policy(policy)
	if not checked.get("accepted",false) or radius not in [2,3] \
		or int(checked.get("receipt",{}).get("minimum_rule_radius",2))>radius:
		microscenario_error = "Level import policy or explicit geometry refused";return false
	_level_import_serial += 1
	_next_level_selection = {"policy":policy.duplicate(),"normalization":"water-normalize-v1" if normalize_water else "",
		"maximum_rule_radius":radius,"intent":"exploratory","policy_hash":str(checked.receipt.policy_hash)}
	microscenario_error = ""
	return true

func liquid_comparison_clear_import() -> void:
	_level_import_serial += 1;_next_level_selection = {}

func liquid_comparison_import_state() -> Dictionary:
	var applied: bool = _accepted_level != null and not _accepted_level.identity(native_world).is_empty()
	return {"armed":not _next_level_selection.is_empty(),"applied":applied,
		"pending_policy_hash":str(_next_level_selection.get("policy_hash",""))}

func liquid_level_host_observation_record() -> Dictionary:
	return _accepted_level.record(native_world) if _accepted_level != null else {}

func restart_world() -> bool:
	if _liquid_water_active and _water_owner_is_current():
		return _apply_prepared_liquid_water(microscenario_liquid_policy,
			microscenario_liquid_setup.get("normalization","")=="water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),water_policy_resolved)
	if not _accepted_physics_demo.is_empty() and _physics_pit_is_current():
		return _begin_web_reference(_accepted_physics_demo.policy.duplicate(),
			_accepted_physics_demo.normalization=="water-normalize-v1",int(_accepted_physics_demo.maximum_rule_radius))
	if _accepted_level != null and not _accepted_level.identity(native_world).is_empty():
		var reconstruction: Dictionary = _accepted_level.reconstruction()
		return _import_prepared_level(reconstruction.payload,reconstruction.metadata,reconstruction.selection)
	if not _accepted_demo.is_empty() and _curated_demo_is_current():
		return _apply_prepared_ordinary_demo(_accepted_demo.definition.duplicate(true),_accepted_demo.policy.duplicate(),
			_accepted_demo.normalization=="water-normalize-v1",int(_accepted_demo.maximum_rule_radius))
	select_demo(demo_id)
	return true

func _prepared_import_configuration(metadata: Dictionary, selection: Dictionary) -> Dictionary:
	var index: int = int(metadata.quality)
	var views: Array[Vector2i] = [Vector2i(320,180),Vector2i(480,270),Vector2i(640,360)]
	var margins: Array[Vector2i] = [Vector2i(16,18),Vector2i(32,36),Vector2i(64,72)]
	var view: Vector2i = views[index]
	var centre := Vector2(metadata.player[0],metadata.player[1])+CyberSampledCharacter.BODY_SIZE*0.5
	var camera := Vector2(clampf(centre.x-view.x*0.5,0,1024-view.x),clampf(centre.y-view.y*0.5,0,1024-view.y))
	var margin: Vector2i = margins[index]
	var first := Vector2i(maxi(0,int(floor(camera.x))-margin.x),maxi(0,int(floor(camera.y))-margin.y))
	var last := Vector2i(mini(1024,int(floor(camera.x))+view.x+margin.x),mini(1024,int(floor(camera.y))+view.y+margin.y))
	var window: bool = native_world.get_simulation_window_enabled()
	var options: Dictionary = {"region":PackedInt32Array([first.x,first.y,last.x-first.x,last.y-first.y]) if window else PackedInt32Array([0,0,1024,1024]),
		"intent":"exploratory","pacing":"host_paced","normalization":selection.normalization,
		"maximum_rule_radius":selection.maximum_rule_radius,"simulation_window_enabled":window,
		"cadence_lod_enabled":native_world.get_cadence_lod_enabled(),"liquid_surface_adhesion_enabled":bool(metadata.adhesion)}
	return {"view":view,"margin":margin,"camera":camera,"options":options,"render_hz":[30,45,60][index]}

func _import_prepared_level(payload: PackedByteArray, metadata: Dictionary, selection: Dictionary) -> bool:
	var issue: String = CyberDemoSaveCodec.validate_metadata(metadata)
	if not issue.is_empty(): last_save_error = issue;ui.message(issue);return false
	if tower_active or showcase_presentation.active() or blacksite_nine_presentation.active() \
		or not rigid_bodies.is_empty() or physical_actor_session != null or str(metadata.demo) in ["physics_pit","experiment_tower"] \
		or not metadata.get("bodies",[]).is_empty() or CyberShowcaseTiles.contains(str(metadata.demo)) \
		or str(metadata.demo)==CyberDemoWorlds.BlacksiteNine.ID:
		last_save_error = "Prepared level imports currently support ordinary body-free demos; prior World and owners retained"
		ui.message(last_save_error);return false
	var settings_refusal: String = _prepared_application_settings_refusal()
	if not settings_refusal.is_empty():
		last_save_error = settings_refusal;ui.message(last_save_error);return false
	_level_import_serial += 1
	var serial: int = _level_import_serial
	var configuration: Dictionary = _prepared_import_configuration(metadata,selection)
	var transport: Dictionary = CyberTransportProfiles.resolve(CyberTransportProfiles.preset(0))
	var water: Dictionary = native_world.get_water_experiment_policy()
	var staged := PreparedLevel.new()
	if not staged.prepare(demo_bridge,native_world,payload,metadata,selection,transport.packed,
		PackedInt32Array([water.version,water.mass_bits,water.coherence_ticks,water.rest_policy]),configuration.options,
		player.active_profile(),player.runtime_enclosure_recovery_enabled,_prepared_level_character_factory):
		last_save_error = staged.last_error;ui.message(last_save_error);_update_liquid_context(true);return false
	if _prepared_level_commit_barrier.is_valid(): _prepared_level_commit_barrier.call()
	if serial != _level_import_serial or not is_inside_tree() or is_queued_for_deletion():
		staged.close_pending();last_save_error = "Level import owner request changed before commit; prior session retained"
		ui.message(last_save_error);return false
	if not staged.commit():
		last_save_error = staged.last_error;ui.message(last_save_error);_update_liquid_context(true);return false
	# Every fallible construction/observation step precedes native commit. This
	# tail adopts prepared values and existing presentation objects only.
	_accepted_level = staged;_next_level_selection = {}
	_curated_demo_id = "";_accepted_demo = {}
	player = staged.staged_player;character_position = player.position
	micro_host.clear();tower_context = {};tower_active = false
	_liquid_tower_active = false;_liquid_water_active = false
	microscenario_definition = {};microscenario_liquid_policy = selection.policy.duplicate()
	microscenario_liquid_setup = selection.duplicate(true);microscenario_liquid_setup.erase("policy")
	tower_schedule.clear();tower_inputs.clear();water_actions.clear();tower_single_step = false
	demo_id = str(metadata.demo);quality = int(metadata.quality)
	current_view_size = configuration.view;simulation_margin = configuration.margin;render_snapshot_hz = configuration.render_hz
	camera_origin = configuration.camera;camera_follow_enabled = false;paused = true
	selected_material_id = int(metadata.material);coherent_liquid_emission = bool(metadata.coherent)
	liquid_surface_adhesion_enabled = bool(metadata.adhesion);set_glow_enabled(bool(metadata.glow))
	force_publication = true;imported_count += 1;last_save_error = "";microscenario_error = ""
	_update_liquid_context(true);_publish_world();update_shader_parameters();update_status()
	ui.message("Prepared level restored paused. P resumes; Restart retains its imported setup and selected liquids.")
	return true

func _prepared_application_settings_refusal() -> String:
	# Native run-component v1 readback is authoritative. The prepared builder
	# supports production interaction/diagnostic laws and configured Baseline;
	# independently tuned laws/profiles must not silently reset during import.
	var actual: Dictionary = native_world.get_liquid_run_receipt({}).get("components",{})
	if actual.get("interaction_policy","") != "8:9:30" or actual.get("diagnostic_physics","") != "0:-1":
		return "Prepared solver rebuild cannot yet retain the current interaction or diagnostic settings; prior World and owners retained"
	var transport: String = str(actual.get("transport_profile",""))
	if transport != "baseline" and not _accepted_demo_retains_transport(transport) \
		and not _accepted_physics_retains_transport(transport) and not _accepted_water_retains_transport(transport) and (_accepted_level == null \
		or not _accepted_level.retains_prepared_transport(native_world,transport)):
		return "Prepared solver rebuild cannot yet retain this independent transport profile; prior World and owners retained"
	return ""

func _accepted_water_retains_transport(transport: String) -> bool:
	return not _water_transport_origin.is_empty() and _water_owner_is_current() \
		and _water_transport_origin.generation==_water_generation \
		and _water_transport_origin.policy_hash==water_policy_resolved.get("hash","") \
		and transport==_water_transport_origin.transport \
		and native_world.get_applied_liquid_construction_receipt().get("receipt_hash","")==_water_transport_origin.receipt_hash

func update_status() -> void:
	if native_world == null:
		return
	$Layout/Title.text = "CYBERSAND / " + (str(tower_context.get("microscenario", {}).get("id", "MicroScenario")) if tower_context.get("micro_active", false) else CyberDemoWorlds.title(demo_id).to_upper())
	if showcase_presentation != null and showcase_presentation.active():
		$Layout/Title.text = "CYBERSAND / " + CyberShowcaseTiles.title(showcase_presentation.current_scenario_id()).to_upper()
	elif blacksite_nine_presentation != null and blacksite_nine_presentation.active():
		$Layout/Title.text = "CYBERSAND / BLACKSITE NINE"
	var text: String = "%s / %s / %s" % [material_name(selected_material_id), "PAUSED" if paused else "60 TPS target", "CALM" if coherent_liquid_emission else "SPRAY"]
	if native_world.has_failed():
		text = "STOPPED / Restart world or load a saved level / " + str(native_world.get_last_tick_error())
	if debug_stats_visible:
		text += "   |   tick %d / %.2f ms native / %.2f ms upload / %d active blocks / %d patches" % [int(native_world.get_tick_index()), float(native_world.get_simulation_time_ms()), upload_time_ms, int(native_world.get_active_blocks_last_tick()), last_render_patch_count]
	status_label.text = text

func _unhandled_key_input(event: InputEvent) -> void:
	if blacksite_nine_presentation != null and blacksite_nine_presentation.map_popup.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE: blacksite_nine_presentation.map_popup.hide()
			elif event.keycode == KEY_F8: microscenario_toggle_hud()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		microscenario_toggle_hud()
		get_viewport().set_input_as_handled()
		return
	if tower_profile_panel != null and tower_profile_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: tower_profile_panel.hide()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if benchmark_running:
		if event.keycode == KEY_ESCAPE:
			benchmark_cancelled = true
		return
	if event.keycode == KEY_ESCAPE:
		if ui.open:
			ui.close_menu()
		else:
			ui.show_page("home")
		get_viewport().set_input_as_handled()
		return
	if not ready_to_play or ui.open:
		return
	match event.keycode:
		KEY_F11:
			if event.shift_pressed: blacksite_nine_presentation.launch()
			else: showcase_presentation.launch()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			selected_material_id = (CyberExperimentTower.QUICK[tower_floor] if tower_active and not tower_context.get("micro_active",false) else [2,3,1,4,20,21])[int(event.keycode)-KEY_1]
		KEY_Q, KEY_E:
			var direction: int = -1 if event.keycode == KEY_Q else 1
			var index: int = PAINTABLE_MATERIAL_IDS.find(selected_material_id)
			selected_material_id = PAINTABLE_MATERIAL_IDS[posmod(index + direction, PAINTABLE_MATERIAL_IDS.size())]
		KEY_P:
			paused = not paused
		KEY_R:
			if tower_context.get("micro_active", false): microscenario_reset()
			else: restart_world()
		KEY_F:
			set_camera_follow(not camera_follow_enabled)
		KEY_C:
			coherent_liquid_emission = not coherent_liquid_emission
		KEY_T:
			set_liquid_surface_adhesion(not liquid_surface_adhesion_enabled)
		KEY_J:
			cycle_brush_shape()
		KEY_MINUS:
			set_brush_size(brush_size_px - 1)
		KEY_EQUAL:
			set_brush_size(brush_size_px + 1)
		KEY_COMMA:
			set_brush_rectangle_ratio(brush_rectangle_ratio - 1)
		KEY_PERIOD:
			set_brush_rectangle_ratio(brush_rectangle_ratio + 1)
		KEY_O:
			set_brush_rectangle_vertical(not brush_rectangle_vertical)
		KEY_G:
			set_glow_enabled(not glow_enabled)
		KEY_F3:
			debug_stats_visible = not debug_stats_visible
		KEY_X:
			var point: Vector2i = _world_pointer()
			if point.x >= 0:
				queue_explosion_mutation(point.x,point.y,20)
	update_status()

func _metadata() -> Dictionary:
	var bodies: Array = []
	for body: RigidBody2D in rigid_bodies:
		var rid: RID = body.get_rid()
		var pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var velocity: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		bodies.append([pose.origin.x, pose.origin.y, pose.get_rotation(), velocity.x, velocity.y, float(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)), bool(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING))])
	return {"demo": demo_id, "player": [player.position.x, player.position.y, player.velocity.x, player.velocity.y], "material": selected_material_id, "quality": quality, "coherent": coherent_liquid_emission, "adhesion": liquid_surface_adhesion_enabled, "glow": glow_enabled, "bodies": bodies}

func _encode_current() -> Dictionary:
	if water_controlled_run_active() or tower_context.get("micro_active", false):
		return {"ok":false,"error":"Use scenario capture; level saves omit scenario lifecycle",
			"binary":PackedByteArray(),"text":""}
	var world: PackedByteArray = demo_bridge.export_level(native_world)
	return CyberDemoSaveCodec.encode(world, _metadata())

func export_save() -> void:
	var encoded: Dictionary = _encode_current()
	if not encoded.ok:
		last_save_error = str(encoded.error)
		ui.message(last_save_error)
		return
	export_text = str(encoded.text)
	ui.save_text.text = export_text
	last_save_error = ""
	ui.message("Exported %d bytes. Keep this text to restore the level." % encoded.binary.size())

func import_save(text: String) -> void:
	_import_decoded(CyberDemoSaveCodec.decode_text(text))

func _import_decoded(decoded: Dictionary) -> void:
	_cancel_web_reference("Superseded by a level import request")
	if water_controlled_run_active() or tower_context.get("micro_active", false):
		last_save_error="Leave the controlled scenario before importing a level"
		ui.message(last_save_error)
		return
	if not decoded.ok:
		last_save_error = str(decoded.error)
		ui.message(last_save_error)
		return
	var metadata: Dictionary = decoded.metadata
	if not _next_level_selection.is_empty():
		_import_prepared_level(decoded.world,metadata,_next_level_selection.duplicate(true))
		return
	if str(metadata.demo) == "physics_pit" and not rapier_available:
		last_save_error = "This save requires Rapier; current world unchanged."
		ui.message(last_save_error)
		return
	if not demo_bridge.import_level(native_world, decoded.world):
		last_save_error = str(demo_bridge.get_last_error())
		ui.message(last_save_error)
		return
	if _accepted_level != null or not _accepted_demo.is_empty() or not _accepted_physics_demo.is_empty():
		microscenario_liquid_policy = null;microscenario_liquid_setup = {};microscenario_definition = {}
		micro_host.clear();tower_context = {};tower_active = false
	_accepted_level = null
	_curated_demo_id = "";_accepted_demo = {}
	demo_id = str(metadata.demo)
	player.position = Vector2(metadata.player[0], metadata.player[1])
	player.velocity = Vector2(metadata.player[2], metadata.player[3])
	player.grounded = false
	character_position = player.position
	selected_material_id = int(metadata.material)
	coherent_liquid_emission = bool(metadata.coherent)
	liquid_surface_adhesion_enabled = bool(metadata.adhesion)
	set_glow_enabled(bool(metadata.glow))
	native_world.set_liquid_surface_adhesion_enabled(liquid_surface_adhesion_enabled)
	set_quality(int(metadata.quality))
	camera_origin = clamped_camera_origin(player.centre() - Vector2(current_view_size) * 0.5)
	camera_follow_enabled = false
	_activate_physics(demo_id == "physics_pit", metadata.get("bodies", []))
	_update_liquid_context(true)
	force_publication = true
	_publish_world()
	imported_count += 1
	last_save_error = ""
	ui.message("Level restored. Continue from the menu.")
	update_status()

func save_slot() -> void:
	var encoded: Dictionary = _encode_current()
	if not encoded.ok:
		ui.message(str(encoded.error))
		return
	var temporary: String = CyberDemoSaveCodec.LOCAL_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		ui.message("Local storage unavailable. Use Export Current.")
		return
	file.store_buffer(encoded.binary)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, CyberDemoSaveCodec.LOCAL_PATH) != OK:
		ui.message("Local save failed. Use Export Current.")
		return
	ui.message("Local slot written. Keep a portable copy; browser storage can be cleared.")

func load_slot() -> void:
	var file: FileAccess = FileAccess.open(CyberDemoSaveCodec.LOCAL_PATH, FileAccess.READ)
	if file == null:
		ui.message("No local slot available.")
		return
	if file.get_length() > CyberDemoSaveCodec.MAX_BINARY:
		file.close()
		ui.message("Local save exceeds size limit.")
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	_import_decoded(CyberDemoSaveCodec.decode_binary(bytes))

# Opt-in browser acceptance hook. No network calls, telemetry, arbitrary code
# execution or engine pointers. Normal URLs never expose this interface.
func _init_browser_test() -> void:
	if not OS.has_feature("web"):
		return
	test_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('test') === '1'", true))
	if not test_enabled:
		return
	# Exercise the side module's actual C++ catch path without changing the level.
	var revision_before: int = int(native_world.get_revision())
	var rejected: bool = not demo_bridge.import_level(native_world, PackedByteArray())
	var exception_probe: bool = rejected and str(demo_bridge.get_last_error()) == "Wrong world payload length" and int(native_world.get_revision()) == revision_before
	print("WEB_CPP_EXCEPTION_PROBE ", exception_probe)
	JavaScriptBridge.eval("window.cybersandTest = {state: {}, invoke: null};", true)
	# Mirror the existing opt-in diagnostics for read-only DOM test tools.
	JavaScriptBridge.eval("const stateNode = document.createElement('script'); stateNode.id = 'cybersand-test-state'; stateNode.type = 'application/json'; document.body.appendChild(stateNode); console.log('WEB_TEST_BROWSER ' + navigator.userAgent);", true)
	test_callback = JavaScriptBridge.create_callback(_test_command)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.cybersandTest.invoke = test_callback

func _test_command(arguments: Array) -> void:
	if not test_enabled or arguments.size() != 1:
		return
	var command: Variant = JSON.parse_string(str(arguments[0]))
	if not command is Dictionary:
		return
	match str(command.get("op", "")):
		"set_text":
			ui.save_text.text = str(command.get("text", ""))
		"hash":
			var bytes: PackedByteArray = demo_bridge.export_level(native_world)
			var hasher: HashingContext = HashingContext.new()
			hasher.start(HashingContext.HASH_SHA256)
			hasher.update(bytes)
			last_hash = hasher.finish().hex_encode()
	_publish_test_state()

func _publish_test_state() -> void:
	var content: Rect2 = view_content_rect()
	content.position += world_view.global_position
	var body_positions: Array = []
	for i: int in range(rigid_bodies.size()):
		var pose: Transform2D = rapier_bridge.body_transform(i)
		body_positions.append([pose.origin.x, pose.origin.y])
	var state: Dictionary = {"ready": ready_to_play, "demo": demo_id, "menu": ui.open, "tick": int(native_world.get_tick_index()), "moves": total_moves, "player": [player.position.x, player.position.y], "paused": paused, "paint_commands": paint_commands, "rapier": rapier_available, "rapier_reason": rapier_reason, "bodies": body_positions, "imports": imported_count, "error": last_save_error, "text": export_text, "hash": last_hash, "buttons": ui.test_rects(), "view": [content.position.x, content.position.y, content.size.x, content.size.y], "logical": [current_view_size.x, current_view_size.y], "camera": [camera_origin.x, camera_origin.y], "probe": int(native_world.material_at(420, 25)), "native_ms": float(native_world.get_simulation_time_ms()), "upload_ms": upload_time_ms, "render_rejections": rejected_render_snapshot_count, "local_slot": FileAccess.file_exists(CyberDemoSaveCodec.LOCAL_PATH)}
	state["workers"] = int(native_world.get_worker_threads())
	state["worker_probe"] = worker_probe
	state["rapier_test"] = rapier_test
	state["tick_failure_test"] = tick_failure_test
	state["interest_region_test"] = interest_region_test
	state["rapier_steps"] = rapier_bridge.manual_step_count()
	state["collider_pending"] = rapier_bridge.pending_hard_surface_chunks()
	state["collider_shapes"] = rapier_bridge.hard_surface_shape_count()
	state["logical_threads"] = logical_threads
	state["benchmark_running"] = benchmark_running
	state["benchmark"] = benchmark_result
	JavaScriptBridge.eval("window.cybersandTest.state = " + JSON.stringify(state) + "; document.getElementById('cybersand-test-state').textContent = JSON.stringify(window.cybersandTest.state);", true)

func start_benchmark(stress: bool) -> void:
	if benchmark_running or not ready_to_play:
		return
	ui.show_page("benchmark")
	benchmark_running = true
	benchmark_cancelled = false
	ui.set_benchmark_busy(true)
	ui.benchmark_text.text = "Starting reference test…"
	benchmark_result = await CyberWorkerBenchmark.run(get_tree(), stress, int(native_world.get_worker_threads()), func(text: String) -> void: ui.benchmark_text.text = text, func() -> bool: return benchmark_cancelled)
	benchmark_running = false
	ui.set_benchmark_busy(false)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s · %d reported logical threads" % ["Stress test" if stress else "Benchmark", logical_threads])
	lines.append("Separate reference worlds; your game is unchanged.")
	lines.append("Native tick: mean / p95 / max (ms)")
	for row: Dictionary in benchmark_result.get("rows", []):
		lines.append("%d workers · %d×%d · %.2f / %.2f / %.2f" % [row.workers, row.side, row.side, row.native_ms.mean, row.native_ms.p95, row.native_ms.max])
		lines.append("  Test frame interval p95: %.2f ms · %d moves" % [row.frame_interval_ms.p95, row.moves])
	lines.append("Completed" if benchmark_result.get("ok", false) else str(benchmark_result.get("error", "Level parity failed")))
	if not stress and benchmark_result.get("parity") == true:
		lines.append("Final level hashes match across worker counts.")
	lines.append("Frame intervals describe this test, not gameplay FPS.")
	ui.benchmark_text.text = "\n".join(lines)
	if benchmark_result.get("ok", false):
		var file: FileAccess = FileAccess.open("user://last_worker_benchmark.json", FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(benchmark_result, "  "))
			file.close()
	print("WORKER_BENCHMARK ", JSON.stringify(benchmark_result))
