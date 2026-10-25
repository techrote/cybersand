extends Control

const PhysicalTrial = preload("res://scripts/physical_actor_trial.gd")
const PhysicalCatalog = preload("res://scripts/physical_actor_catalog.gd")
const PhysicalSession = preload("res://scripts/physical_actor_session.gd")
const PhysicalOverlay = preload("res://scripts/physical_actor_overlay.gd")
const PhysicalLoadouts = preload("res://scripts/physical_usable_loadouts.gd")
const PhysicalEquipment = preload("res://scripts/physical_usable_equipment.gd")
const PreparedPhysical = preload("res://scripts/prepared_physical_session.gd")
const PreparedReferenceBody = preload("res://scripts/prepared_reference_body_session.gd")
var _pending_physical_candidate: RefCounted
var _accepted_physical_candidate: RefCounted
var _prepared_physical_identity: Dictionary = {}
var _prepared_physical_ready_sent: bool = false
var _prepared_physical_factory: Callable = Callable()
var _prepared_reference_factory: Callable = Callable()
var _accepted_reference_candidate: RefCounted
var exploratory_actor_configuration: Dictionary = {}
var physical_trial_arm: String = ""
var physical_trial_input = PhysicalTrial.new()
var physical_rig_id: StringName = &""
var physical_actor_session: CyberPhysicalActorSession
var physical_actor_overlay: CyberPhysicalActorOverlay
var _physical_epoch: int = 0
var _physical_terrain_ready: bool = false
const PHYSICAL_TOOL_KEYS: Array[int] = [KEY_M, KEY_N, KEY_U]

const GameplayRecorder = preload("res://scripts/gameplay_recorder.gd")
const PlayerEnvironmentProfiles = preload("res://scripts/player_environment_profiles.gd")
const PlayerEnvironmentPanel = preload("res://scripts/player_environment_panel.gd")
const ShowcasePresentation = preload("res://scripts/showcase_presentation.gd")
const BlacksiteNinePresentation = preload("res://scripts/blacksite_nine_presentation.gd")
const ActorPrototypePanel = preload("res://scripts/actor_prototype_panel.gd")
const ActorPrototypeOverlay = preload("res://scripts/actor_prototype_overlay.gd")
const ActorRigCatalog = preload("res://scripts/actor_rig_catalog.gd")
const UsableCatalog = preload("res://scripts/usable_catalog.gd")
const UsableOverlay = preload("res://scripts/usable_overlay.gd")
const ACTOR_CONTROL_KEYS: Array[int] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT,
	KEY_Q, KEY_E, KEY_Z, KEY_X, KEY_C, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]
const ACTOR_PARAMETRIC_KEYS: Array[int] = [KEY_Q, KEY_E, KEY_Z, KEY_X, KEY_C,
	KEY_BRACKETLEFT, KEY_BRACKETRIGHT]
const DEFAULT_RECORDING_HZ: int = 15
const DEFAULT_RECORDING_QUEUE_CAPACITY: int = 8

# Presentation and orchestration only. A dedicated worker owns all mutable
# cellular and sampled-character physics and publishes immutable snapshots.
const DEFAULT_VIEW_SIZE: Vector2i = Vector2i(320, 180)
const VIEW_SIZE_PRESETS: Array[Vector2i] = [
	Vector2i(320, 180),
	Vector2i(480, 270),
	Vector2i(640, 360),
	Vector2i(960, 540),
]
const SIMULATION_MARGIN_PRESETS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(32, 36),
	Vector2i(128, 128),
	Vector2i(256, 256),
]
const STATUS_INTERVAL: float = 0.25
const CAMERA_PAN_SPEED: float = 150.0
const CAMERA_FOLLOW_RATE: float = 9.0
const CHARACTER_SPAWN: Vector2 = Vector2(150.0, 145.0)
const TEST_RIGID_BODY_SIZE: Vector2 = Vector2(8.0, 14.0)
const HARD_SURFACE_REBUILD_INTERVAL: float = 0.10
const HARD_SURFACE_CHUNKS_PER_FRAME: int = 32
const HARD_SURFACE_FRAME_BUDGET_USEC: int = 750
const RENDER_PATCH_METADATA_STRIDE: int = 6
const RENDER_SNAPSHOT_HZ_PRESETS: Array[int] = [30, 45, 60]
const BRUSH_SHAPES: Array[String] = ["circle", "square", "rectangle"]
const BRUSH_MIN_SIZE_PX: int = 1
const BRUSH_MAX_SIZE_PX: int = 32
const BRUSH_MIN_RECTANGLE_RATIO: int = 1
const BRUSH_MAX_RECTANGLE_RATIO: int = 4
const BRUSH_PREVIEW_SEGMENTS: int = 32
const WATER_POLICY_PATH: String = "user://water-experiment-policy.json"
# Prototype paint-tool slots are UI identifiers, not material IDs. Their
# mappings may change without changing simulation or serialized material identity.
const PAINT_SLOT_SAND: int = 1
const PAINT_SLOT_WATER: int = 2
const PAINT_SLOT_WALL: int = 3
const PAINT_SLOT_SMOKE: int = 4
const PAINT_SLOT_PASTE: int = 5
const PAINT_SLOT_SLUSH: int = 6
const PAINTABLE_MATERIAL_IDS: Array[int] = [
	CyberCellWorld.SAND,
	CyberCellWorld.WATER,
	CyberCellWorld.WALL,
	CyberCellWorld.SMOKE,
	CyberCellWorld.PASTE,
	CyberCellWorld.SLUSH,
	CyberCellWorld.FIRE,
	CyberCellWorld.WOOD,
	CyberCellWorld.OIL,
	CyberCellWorld.LAVA,
	CyberCellWorld.ICE,
	CyberCellWorld.ACID,
	CyberCellWorld.STONE,
	CyberCellWorld.DUST,
	CyberCellWorld.PLANT,
	CyberCellWorld.FUNGUS,
	CyberCellWorld.SEED,
	CyberCellWorld.CLONER,
	CyberCellWorld.MITE,
	CyberCellWorld.ROCKET,
	CyberCellWorld.STEAM,
	CyberCellWorld.SALT,
	CyberCellWorld.BRINE,
	CyberCellWorld.SODIUM,
	CyberCellWorld.GUNPOWDER,
	CyberCellWorld.COAL,
	CyberCellWorld.METAL,
	CyberCellWorld.RUST,
	CyberCellWorld.CEMENT,
	CyberCellWorld.CONCRETE,
	CyberCellWorld.TOXIC_SLUDGE,
	CyberCellWorld.MERCURY,
	CyberCellWorld.SPARK,
	CyberCellWorld.GLASS,
	CyberCellWorld.MOLTEN_GLASS,
	CyberCellWorld.FOAM,
	CyberCellWorld.LIMESTONE_BLOCK,
	CyberCellWorld.SANDSTONE_BLOCK,
	CyberCellWorld.GRANITE_BLOCK,
	CyberCellWorld.COBBLESTONE,
	CyberCellWorld.MOSSY_COBBLESTONE,
	CyberCellWorld.RED_BRICK,
	CyberCellWorld.LIME_PLASTER,
	CyberCellWorld.WATTLE_AND_DAUB,
	CyberCellWorld.OAK_TIMBER,
	CyberCellWorld.THATCH,
	CyberCellWorld.TERRACOTTA_TILE,
	CyberCellWorld.SLATE,
	CyberCellWorld.WROUGHT_IRON,
	CyberCellWorld.LEAD_SHEET,
	CyberCellWorld.BRONZE,
	CyberCellWorld.COPPER,
	CyberCellWorld.VERDIGRIS_COPPER,
	CyberCellWorld.STAINED_GLASS,
	CyberCellWorld.PACKED_EARTH,
	CyberCellWorld.INDUSTRIAL_BRICK,
	CyberCellWorld.REINFORCED_CONCRETE,
	CyberCellWorld.ASPHALT,
	CyberCellWorld.WET_ASPHALT,
	CyberCellWorld.WET_COBBLESTONE,
	CyberCellWorld.STEEL_PLATE,
	CyberCellWorld.PAINTED_STEEL,
	CyberCellWorld.CORRUGATED_STEEL,
	CyberCellWorld.RUSTED_STEEL,
	CyberCellWorld.STEEL_GRATING,
	CyberCellWorld.CHAINLINK,
	CyberCellWorld.STEEL_PIPE,
	CyberCellWorld.COPPER_PIPE,
	CyberCellWorld.CERAMIC_TILE,
	CyberCellWorld.CHEMICAL_GLASS,
	CyberCellWorld.DARK_GLASS,
	CyberCellWorld.RUBBER,
	CyberCellWorld.CABLE_BUNDLE,
	CyberCellWorld.INSULATION,
	CyberCellWorld.HAZARD_STRIPE,
	CyberCellWorld.NEON_CYAN,
	CyberCellWorld.NEON_MAGENTA,
	CyberCellWorld.NEON_AMBER,
	CyberCellWorld.LED_WHITE,
	CyberCellWorld.PINE_PLANKS,
	CyberCellWorld.BIRCH_LOG,
	CyberCellWorld.OAK_LOG,
	CyberCellWorld.WALNUT_PANEL,
	CyberCellWorld.MAHOGANY_PANEL,
	CyberCellWorld.BAMBOO,
	CyberCellWorld.PLYWOOD,
	CyberCellWorld.DRIFTWOOD,
	CyberCellWorld.CEDAR_SHINGLES,
	CyberCellWorld.CHARRED_TIMBER,
	CyberCellWorld.CORK,
	CyberCellWorld.WICKER,
	CyberCellWorld.CARDBOARD,
	CyberCellWorld.PAPER_SCREEN,
	CyberCellWorld.TAR_BLOCK,
	CyberCellWorld.ACRYLIC_SHEET,
	CyberCellWorld.MOSS_WALL,
	CyberCellWorld.MARBLE,
	CyberCellWorld.CHALK_BLOCK,
	CyberCellWorld.BASALT_COLUMNS,
	CyberCellWorld.OBSIDIAN,
	CyberCellWorld.ADOBE_BRICK,
	CyberCellWorld.RAW_CLAY,
	CyberCellWorld.FIREBRICK,
	CyberCellWorld.PACKED_SNOW,
	CyberCellWorld.ROCK_SALT_BLOCK,
	CyberCellWorld.GYPSUM_BOARD,
	CyberCellWorld.QUICKLIME_BLOCK,
	CyberCellWorld.RAMMED_EARTH,
	CyberCellWorld.SANDBAG,
	CyberCellWorld.TERRAZZO,
	CyberCellWorld.GABION,
	CyberCellWorld.ZINC_SHEET,
	CyberCellWorld.ALUMINIUM_PANEL,
	CyberCellWorld.MAGNESIUM_PLATE,
	CyberCellWorld.THERMITE_BRICK,
	CyberCellWorld.BARE_IRON,
	CyberCellWorld.GOLD_LEAF,
	CyberCellWorld.BRASS_PANEL,
	CyberCellWorld.GLASS_BLOCK,
	CyberCellWorld.FROSTED_GLASS,
	CyberCellWorld.QUARTZ_CRYSTAL,
	CyberCellWorld.URANIUM_GLASS,
	CyberCellWorld.SUGAR_GLASS,
	CyberCellWorld.WAX_BLOCK,
	CyberCellWorld.SULFUR_BLOCK,
	CyberCellWorld.PHOSPHOR_PANEL,
	CyberCellWorld.POLYMER_PANEL,
	CyberCellWorld.SOLAR_PANEL,
	CyberCellWorld.CARBON_FIBRE,
	CyberCellWorld.HEAT_SHIELD_TILE,
]
const MATERIAL_GROUP_FIRST_IDS: Array[int] = [
	CyberCellWorld.SAND,
	CyberCellWorld.LIMESTONE_BLOCK,
	CyberCellWorld.INDUSTRIAL_BRICK,
	CyberCellWorld.NEON_CYAN,
	CyberCellWorld.PINE_PLANKS,
	CyberCellWorld.MARBLE,
	CyberCellWorld.ZINC_SHEET,
	CyberCellWorld.GLASS_BLOCK,
]

@onready var world_view: TextureRect = $Layout/World
@onready var status_label: Label = $Layout/Status
@onready var world_shader: ShaderMaterial = world_view.material as ShaderMaterial
@onready var test_rigid_body_1: RigidBody2D = $RigidBodies/TestBody1
@onready var test_rigid_body_2: RigidBody2D = $RigidBodies/TestBody2
@onready var test_rigid_body_3: RigidBody2D = $RigidBodies/TestBody3

var simulation_worker: CyberSimulationWorker = CyberSimulationWorker.new()
var gameplay_recorder = GameplayRecorder.new()
var recording_button: Button
var player_environment_panel
var player_environment_button: Button
var active_player_environment_profile: Dictionary = PlayerEnvironmentProfiles.preset(
	PlayerEnvironmentProfiles.PRESET_CURRENT
)
var pending_player_environment_profile: Dictionary = {}
var tower_panel: CyberTowerPanel
var tower_active: bool = false
var tower_floor: int = 0
var tower_context: Dictionary = {}
var tower_profile_panel: CyberTransportProfilePanel
var tower_profile: Dictionary = CyberTransportProfiles.preset(0)
var water_experiment_panel: CyberWaterExperimentPanel
var water_policy_resolved: Dictionary = CyberWaterExperimentProfiles.resolve()
var water_blind_set: Dictionary = {}
var water_blind_base: Dictionary = {}
var water_blind_index: int = 0
var water_active_blind_label: String = ""
var pending_water_apply: Dictionary = {}
var pending_water_exit: Dictionary = {}
var _water_exit_request_serial: int = 0
var water_policy_available: bool = true

var brush_shape: String = "circle"
var brush_size_px: int = 9
var brush_rectangle_ratio: int = 2
var brush_rectangle_vertical: bool = false
var brush_preview: Line2D
var microscenario_panel: CyberMicroScenarioPanel
var microscenario_mode: String = "Inspect"
var microscenario_error: String = ""
var microscenario_hud_hidden: bool = false
var _microscenario_saved_help: String = ""
var pending_microscenario_apply: Dictionary = {}
var _microscenario_request_serial: int = 0
var microscenario_capture_seen: int = 0
var microscenario_definition: Dictionary = {}
var microscenario_liquid_policy: Variant = null
var microscenario_liquid_setup: Dictionary = {}
var _liquid_tower_active: bool = false
var _liquid_water_active: bool = false
var _liquid_default_active: bool = false
var _liquid_default_generation: int = 0
var showcase_presentation: CyberShowcasePresentation
var blacksite_nine_presentation: CyberBlacksiteNinePresentation

func microscenario_launch(scenario_id: String, mode: String = "Inspect", seed: int = 0) -> bool:
	if not water_blind_set.is_empty() or not water_active_blind_label.is_empty(): return false
	if not mode in CyberMicroScenarioContract.MODES: return false
	var definition: Dictionary = CyberMicroScenarioCatalogue.definition(scenario_id, seed)
	var checked: Dictionary = CyberMicroScenarioContract.validate(definition)
	if not checked.get("ok", false):
		microscenario_error = str(checked.get("error", "Unknown scenario"))
		return false
	microscenario_mode = mode
	microscenario_error = ""
	if scenario_id == "experiment-tower":
		tower_reset()
		return true
	if scenario_id.begins_with("water/"):
		# Keep #19 policy, transactional reset and blind/reveal ownership intact.
		var policy: Dictionary = water_policy_resolved.get("policy", {}).duplicate(true)
		policy["scenario_id"] = scenario_id.trim_prefix("water/")
		policy["seed"] = seed
		var resolved: Dictionary = CyberWaterExperimentProfiles.resolve({}, {}, policy)
		if not resolved.get("ok", false): return false
		water_lab_apply_result(resolved)
		return true
	return microscenario_apply_definition(checked.definition, mode)

func microscenario_apply_definition(definition: Dictionary, mode: String = "Inspect") -> bool:
	return _apply_microscenario_definition(definition, mode)

func microscenario_apply_controlled_liquid(definition: Dictionary, liquid_policy: PackedInt32Array,
		normalize_water: bool = false, mode: String = "Inspect", maximum_rule_radius: int = 2) -> bool:
	return _apply_microscenario_definition(definition, mode, {}, liquid_policy,
		{"normalization":"water-normalize-v1" if normalize_water else "","maximum_rule_radius":maximum_rule_radius})

func liquid_comparison_active_definition() -> Dictionary:
	if tower_context.get("water_active",false): return CyberMicroScenarioCatalogue.prepared_water(water_policy_resolved)
	if tower_active and tower_context.get("active",false) and not tower_context.get("micro_active",false) \
		and not tower_context.get("water_active",false):
		return CyberMicroScenarioCatalogue.prepared_tower(tower_profile,tower_floor)
	return microscenario_definition.duplicate(true)

func liquid_comparison_can_apply_active(exploratory: bool) -> bool:
	# This is the native constructor's copied origin, published by its exclusive
	# owner. A demo label or an imported copy of the same pixels is insufficient.
	var origin: Dictionary = tower_context.get("native_default_demo",{})
	return (exploratory and origin.get("native_recipe_id","") == "cybersand-desktop-default-demo-v1"
		and not tower_active and not tower_context.get("active",false)
		and physical_actor_session == null and physical_rig_id == &"" and actor_model_selection == &""
		and not player_uses_barrel() and _actor_reset_receipt == 0
		and pending_microscenario_apply.is_empty() and pending_water_apply.is_empty()
		and pending_water_exit.is_empty() and water_blind_set.is_empty() and water_active_blind_label.is_empty())

func liquid_comparison_apply_active(policy: PackedInt32Array, normalize_water: bool, exploratory: bool,
		mode: String, radius: int) -> bool:
	if not tower_context.get("native_default_demo",{}).is_empty() and not tower_active:
		return _apply_prepared_liquid_default(policy,normalize_water,radius,exploratory)
	if tower_context.get("water_active",false):
		if not exploratory:
			microscenario_error = "Water Feel requires Exploratory mode with its existing sampled player"
			return false
		return _apply_prepared_liquid_water(policy,normalize_water,radius,water_policy_resolved)
	if tower_active and tower_context.get("active",false) and not tower_context.get("micro_active",false) \
		and not tower_context.get("water_active",false):
		if not exploratory:
			microscenario_error = "Experiment Tower requires Exploratory mode with its existing sampled player"
			return false
		return _apply_prepared_liquid_tower(policy,normalize_water,radius,CyberTransportProfiles.resolve(tower_profile))
	return (microscenario_apply_exploratory_liquid(microscenario_definition,policy,normalize_water,mode,{},radius)
		if exploratory else microscenario_apply_controlled_liquid(microscenario_definition,policy,normalize_water,mode,radius))

func _apply_prepared_liquid_default(policy: PackedInt32Array, normalize_water: bool, radius: int,
		exploratory: bool = true, requested_recovery: Variant = null, requested_profile: Dictionary = {}) -> bool:
	if not liquid_comparison_can_apply_active(exploratory):
		microscenario_error = "Native default demo requires Exploratory with its ordinary sampled player and reference bodies"
		return false
	if simulation_worker.has_failed() or not tower_context.native_default_demo.get("healthy",false):
		microscenario_error = "Prepared Restart requires a healthy World; load Current or another setup to recover"
		return false
	var staged: RefCounted = _prepared_reference_factory.call() if _prepared_reference_factory.is_valid() else PreparedReferenceBody.new()
	var positions := PackedVector2Array()
	var rotations := PackedFloat32Array()
	for index: int in range(3):
		positions.append(test_rigid_body_spawn(index));rotations.append(test_rigid_body_rotation(index))
	var templates: Array[RigidBody2D] = [test_rigid_body_1,test_rigid_body_2,test_rigid_body_3]
	if not staged.prepare_reference(self,templates,TEST_RIGID_BODY_SIZE,positions,rotations):
		microscenario_error = staged.last_error;staged.close()
		return false
	var origin: Vector2 = clamped_camera_origin(CHARACTER_SPAWN+CyberSampledCharacter.BODY_SIZE*0.5-Vector2(current_view_size)*0.5)
	var owner: Dictionary = {"view_origin":Vector2i(origin.floor()),"view_size":current_view_size,
		"horizontal_buffer":simulation_margin.x,"vertical_buffer":simulation_margin.y,
		"simulation_window_enabled":simulation_window_enabled,"cadence_lod_enabled":cadence_lod_enabled,
		"liquid_surface_adhesion_enabled":liquid_surface_adhesion_enabled}
	var setup: Dictionary = {"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "",
		"maximum_rule_radius":radius,"physical_owner":{"kind":"reference_body","epoch":0,
			"instance_id":staged.get_instance_id(),"initial_bodies":staged.initial_body_states()}}
	_microscenario_request_serial += 1
	var recovery: bool = sampled_runtime_recovery_enabled if requested_recovery == null else bool(requested_recovery)
	_pending_physical_candidate = staged
	_prepared_physical_identity = {};_prepared_physical_ready_sent = false
	pending_microscenario_apply = {"route":"native_default","serial":_microscenario_request_serial,
		"previous_paused":paused,"previous_mode":microscenario_mode,"liquid_policy":policy.duplicate(),
		"controlled_liquid_setup":setup.duplicate(true),"owner_execution":owner.duplicate(true),"runtime_recovery":recovery,
		"profile_request":not requested_profile.is_empty()}
	paused = true
	var command: Dictionary = {"default_liquid_reset":true,"expected_default_generation":int(tower_context.native_default_demo.session_generation),
		"scenario_request_serial":_microscenario_request_serial,"sampled_character_enabled":true,
		"runtime_enclosure_recovery_enabled":recovery,
		"liquid_policy":policy.duplicate(),"controlled_liquid_setup":setup,"default_owner_execution":owner}
	if not requested_profile.is_empty(): command["_prepared_player_environment_profile"] = requested_profile.duplicate(true)
	simulation_worker.queue_lab(command)
	return true

func _prepared_liquid_default_installed() -> void:
	_liquid_default_active = true
	_liquid_default_generation = int(tower_context.native_default_demo.session_generation)
	_liquid_tower_active = false;_liquid_water_active = false
	microscenario_error = "";microscenario_definition = {}
	microscenario_liquid_policy = pending_microscenario_apply.liquid_policy.duplicate()
	microscenario_liquid_setup = pending_microscenario_apply.controlled_liquid_setup.duplicate(true)
	microscenario_liquid_setup.erase("physical_owner")
	sampled_runtime_recovery_enabled = bool(pending_microscenario_apply.runtime_recovery)
	character_position = CHARACTER_SPAWN;camera_follow_enabled = true;paused = true
	camera_origin = Vector2(pending_microscenario_apply.owner_execution.view_origin)
	_adopt_prepared_physical_candidate()
	simulation_worker.acknowledge_prepared_liquid_configuration(int(pending_microscenario_apply.serial))

func _apply_prepared_liquid_tower(policy: PackedInt32Array, normalize_water: bool, radius: int,
		resolved: Dictionary) -> bool:
	if not resolved.get("ok",false) or not pending_microscenario_apply.is_empty() \
		or not pending_water_apply.is_empty() or not water_blind_set.is_empty() or not water_active_blind_label.is_empty(): return false
	if physical_actor_session != null or not rigid_bodies.is_empty() or player_uses_barrel():
		microscenario_error = "Prepared Tower requires its existing sampled owner; prior session retained"
		return false
	var checked: Dictionary = CyberMicroScenarioContract.validate(CyberMicroScenarioCatalogue.prepared_tower(resolved.profile,tower_floor))
	if not checked.ok:
		microscenario_error = str(checked.error)
		return false
	_microscenario_request_serial += 1
	var setup: Dictionary = {"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "",
		"maximum_rule_radius":radius}
	pending_microscenario_apply = {"route":"tower","serial":_microscenario_request_serial,"hash":checked.hash,
		"definition":checked.definition,"previous_paused":paused,"previous_mode":microscenario_mode,
		"liquid_policy":policy.duplicate(),"controlled_liquid_setup":setup,"profile":resolved.profile.duplicate(true),"floor":tower_floor}
	paused = true
	simulation_worker.queue_lab({"reset":true,"floor":tower_floor,"profile":resolved,"scenario_mode":microscenario_mode,
		"scenario_request_serial":_microscenario_request_serial,"sampled_character_enabled":true,
		"runtime_enclosure_recovery_enabled":sampled_runtime_recovery_enabled,"liquid_policy":policy.duplicate(),
		"controlled_liquid_setup":setup})
	return true

func _prepared_liquid_tower_installed() -> void:
	_liquid_tower_active = true
	_liquid_water_active = false
	microscenario_error = ""
	microscenario_definition = pending_microscenario_apply.definition.duplicate(true)
	microscenario_liquid_policy = pending_microscenario_apply.liquid_policy.duplicate()
	microscenario_liquid_setup = pending_microscenario_apply.controlled_liquid_setup.duplicate(true)
	tower_profile = pending_microscenario_apply.profile.duplicate(true)
	tower_floor = int(pending_microscenario_apply.floor)
	paused = true;current_view_size = Vector2i(480,270);camera_follow_enabled = false
	camera_origin = Vector2(microscenario_definition.camera_origin[0],microscenario_definition.camera_origin[1])
	character_position = Vector2(microscenario_definition.player_start[0],microscenario_definition.player_start[1])
	simulation_worker.acknowledge_prepared_liquid_configuration(int(pending_microscenario_apply.serial))

func _apply_prepared_liquid_water(policy: PackedInt32Array, normalize_water: bool, radius: int,
		result: Dictionary) -> bool:
	if not result.get("ok",false) or not tower_context.get("water_active",false) \
		or not pending_microscenario_apply.is_empty() or not pending_water_apply.is_empty() or not pending_water_exit.is_empty() \
		or not water_blind_set.is_empty() or not water_active_blind_label.is_empty(): return false
	var resolved: Dictionary = CyberWaterExperimentProfiles.resolve({},{},result.policy)
	if not resolved.ok or resolved.hash != result.hash: return false
	var recipe: Dictionary = CyberWaterFeelScenarios.recipe(str(resolved.policy.scenario_id),int(resolved.policy.seed))
	if recipe.is_empty(): return false
	if physical_actor_session != null or player_uses_barrel():
		microscenario_error = "Prepared Water Feel requires its sampled player and reference body owner; prior session retained"
		return false
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var admitted: Dictionary = bridge.validate_liquid_policy(policy)
	var source_refusal: String = CyberMicroScenarioCatalogue.prepared_water_source_refusal(admitted.get("receipt",{}),recipe)
	if not source_refusal.is_empty():
		microscenario_error = source_refusal
		return false
	var checked: Dictionary = CyberMicroScenarioContract.validate(CyberMicroScenarioCatalogue.prepared_water(resolved))
	if not checked.ok:
		microscenario_error = str(checked.error)
		return false
	_microscenario_request_serial += 1
	var setup: Dictionary = {"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "",
		"maximum_rule_radius":radius}
	if recipe.body_enabled:
		var staged: RefCounted = _prepared_reference_factory.call() if _prepared_reference_factory.is_valid() else PreparedReferenceBody.new()
		var templates: Array[RigidBody2D] = [test_rigid_body_1,test_rigid_body_2,test_rigid_body_3]
		if not staged.prepare_reference(self,templates,TEST_RIGID_BODY_SIZE):
			microscenario_error = staged.last_error
			staged.close()
			return false
		_pending_physical_candidate = staged
		_prepared_physical_identity = {};_prepared_physical_ready_sent = false
		# Ordinary reference rectangles carry no actor/equipment authority.
		setup.physical_owner = {"kind":"reference_body","epoch":0,"instance_id":staged.get_instance_id(),
			"initial_bodies":staged.initial_body_states()}
	pending_microscenario_apply = {"route":"water","serial":_microscenario_request_serial,"hash":checked.hash,
		"definition":checked.definition,"previous_paused":paused,"previous_mode":microscenario_mode,
		"liquid_policy":policy.duplicate(),"controlled_liquid_setup":setup,"water_result":result.duplicate(true),"water_recipe":recipe}
	paused = true
	simulation_worker.queue_lab({"water_reset":true,"water_policy":resolved.policy,"water_policy_hash":resolved.hash,
		"water_policy_provenance":result.get("provenance",{}),"blind_label":"","scenario_mode":microscenario_mode,
		"scenario_request_serial":_microscenario_request_serial,"sampled_character_enabled":true,
		"runtime_enclosure_recovery_enabled":sampled_runtime_recovery_enabled,"liquid_policy":policy.duplicate(),
		"controlled_liquid_setup":setup})
	return true

func _prepared_liquid_water_installed() -> void:
	_liquid_water_active = true;_liquid_tower_active = false;microscenario_error = ""
	microscenario_definition = pending_microscenario_apply.definition.duplicate(true)
	microscenario_liquid_policy = pending_microscenario_apply.liquid_policy.duplicate()
	microscenario_liquid_setup = pending_microscenario_apply.controlled_liquid_setup.duplicate(true)
	microscenario_liquid_setup.erase("physical_owner")
	water_policy_resolved = pending_microscenario_apply.water_result.duplicate(true)
	water_policy_available = true;water_active_blind_label = ""
	paused = true;tower_active = true;current_view_size = Vector2i(480,270);camera_follow_enabled = false
	camera_origin = Vector2(microscenario_definition.camera_origin[0],microscenario_definition.camera_origin[1])
	character_position = Vector2(microscenario_definition.player_start[0],microscenario_definition.player_start[1])
	$Layout/Title.text = "CYBERSAND / EXPERIMENT TOWER / WATER FEEL"
	if _pending_physical_candidate != null: _adopt_prepared_physical_candidate()
	else:
		_close_prepared_reference_bodies()
		for body: RigidBody2D in [test_rigid_body_1,test_rigid_body_2,test_rigid_body_3]:
			body.freeze = true;body.collision_layer = 0;body.collision_mask = 0
		rapier_bridge.shutdown();rigid_bodies.clear()
	simulation_worker.acknowledge_prepared_liquid_configuration(int(pending_microscenario_apply.serial))

func microscenario_apply_exploratory_liquid(definition: Dictionary, liquid_policy: PackedInt32Array,
		normalize_water: bool = false, mode: String = "Play", actor_configuration: Dictionary = {}, maximum_rule_radius: int = 2) -> bool:
	return _apply_microscenario_definition(definition, mode, actor_configuration, liquid_policy,
		{"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "","maximum_rule_radius":maximum_rule_radius})

func microscenario_supports_prepared_physical_liquid(definition: Dictionary) -> bool:
	if tower_context.get("water_active",false):
		return bool(definition.get("body_enabled",false)) and physical_actor_session == null and not player_uses_barrel()
	return physical_rig_id != &"" and microscenario_mode != "Benchmark" \
		and CyberMicroScenarioCatalogue.exploratory_actor_map(definition)

func _apply_microscenario_definition(definition: Dictionary, mode: String, actor_configuration: Dictionary = {},
		liquid_policy: Variant = null, controlled_setup: Dictionary = {}) -> bool:
	if not pending_microscenario_apply.is_empty() or not pending_water_apply.is_empty(): return false
	if not water_blind_set.is_empty() or not water_active_blind_label.is_empty(): return false
	# F5 rebuilds retain an explicitly accepted exploratory solver selection.
	if (not actor_configuration.is_empty() and liquid_policy == null and controlled_setup.is_empty()
		and microscenario_liquid_setup.get("intent", "controlled") == "exploratory"):
		liquid_policy = microscenario_liquid_policy
		controlled_setup = microscenario_liquid_setup.duplicate(true)
	definition = definition.duplicate(true)
	var exploratory: bool = CyberMicroScenarioCatalogue.exploratory_actor_map(definition) and mode != "Benchmark"
	var selected_actor: Dictionary = actor_configuration if not actor_configuration.is_empty() else exploratory_actor_configuration
	if exploratory and not selected_actor.is_empty():
		selected_actor = selected_actor.duplicate(true)
		var model: StringName = StringName(str(selected_actor.get("actor_model", "")))
		if model != &"":
			selected_actor.actor_definitions = actor_prototype_definitions(model,
				StringName(str(selected_actor.get("actor_producer", "human"))),
				bool(selected_actor.get("actor_demo_npcs", false)),
				Vector2(definition.player_start[0], definition.player_start[1]))
		definition.body_enabled = selected_actor.representation == "barrel-rapier"
		definition.player_enabled = not definition.body_enabled
	var checked: Dictionary = CyberMicroScenarioContract.validate(definition)
	if not checked.get("ok", false) or not mode in CyberMicroScenarioContract.MODES:
		microscenario_error = str(checked.get("error", "Invalid mode"))
		return false
	if not controlled_setup.is_empty():
		var prepared_exploratory: bool = controlled_setup.get("intent", "controlled") == "exploratory"
		var articulated: bool = prepared_exploratory and exploratory \
			and not str(selected_actor.get("physical_rig", "")).is_empty()
		if int(checked.definition.schema_version) != 2 or (checked.definition.body_enabled and not articulated):
			microscenario_error = "Prepared liquid setup requires schema 2; this body route is not staged"
			return false
		if (not prepared_exploratory and (checked.definition.player_enabled
			or checked.definition.execution.policy != "fixed" or checked.definition.interest.policy != "fixed")):
			microscenario_error = "Controlled liquid setup requires a fixed actor-free MicroScenario"
			return false
	var player_configuration: Dictionary = (selected_actor.duplicate(true)
		if exploratory and not selected_actor.is_empty()
		else _player_configuration_for_microscenario(checked.definition))
	if player_configuration.is_empty():
		return false
	var prepared_physical: bool = not controlled_setup.is_empty() \
		and not str(player_configuration.get("physical_rig", "")).is_empty()
	if not controlled_setup.is_empty() and player_configuration.get("representation", "sampled") == "barrel-rapier":
		if not prepared_physical or not exploratory or mode == "Benchmark" \
			or controlled_setup.get("intent","controlled") != "exploratory":
			microscenario_error = "This prepared physical route is unavailable; current session retained"
			return false
	if prepared_physical:
		var staged: RefCounted = _prepared_physical_factory.call() if _prepared_physical_factory.is_valid() else PreparedPhysical.new()
		var definitions: Array = physical_actor_definitions(StringName(str(player_configuration.physical_rig)),
			StringName(str(player_configuration.get("actor_producer","human"))),
			bool(player_configuration.get("actor_demo_npcs",false)),
			Vector2(checked.definition.player_start[0],checked.definition.player_start[1]))
		if not staged.prepare(self,definitions,_physical_epoch+1):
			microscenario_error = staged.last_error
			staged.close()
			return false
		# Signal connection and all rig/equipment/space construction precede the
		# native preparation. The exact same graph survives successful adoption.
		staged.session.input_cancelled.connect(_on_physical_actor_input_cancelled)
		_pending_physical_candidate = staged
		_prepared_physical_identity = {};_prepared_physical_ready_sent = false
		controlled_setup = controlled_setup.duplicate(true)
		controlled_setup.physical_owner = {"epoch":_physical_epoch+1,"instance_id":staged.get_instance_id(),
			"initial_bodies":staged.initial_body_states()}
	if microscenario_panel != null: microscenario_panel.workbench.cancel_declared_window()
	_microscenario_request_serial += 1
	pending_microscenario_apply = {
		"serial":_microscenario_request_serial,
		"hash":checked.hash,
		"definition":checked.definition,
		"previous_paused":paused,
		"previous_mode":microscenario_mode,
		"player_configuration":player_configuration.duplicate(true),
		"liquid_policy":liquid_policy.duplicate() if liquid_policy != null else null,
		"controlled_liquid_setup":controlled_setup.duplicate(true),
	}
	microscenario_mode = mode
	paused = true
	var requested_representation := StringName(
		str(player_configuration.get("representation", "sampled"))
	)
	tower_command({
		"scenario_reset":checked.definition,
		"scenario_request_serial":_microscenario_request_serial,
		"scenario_mode":mode,
		"sampled_character_enabled":(
			(controlled_setup.is_empty() or controlled_setup.get("intent", "controlled") == "exploratory")
			and requested_representation != CyberPlayerRepresentation.BARREL_RAPIER
		),
		"runtime_enclosure_recovery_enabled":bool(
			player_configuration.get("runtime_recovery_enabled", true)
		),
		"exploratory_actor_definitions":player_configuration.get("actor_definitions", []),
		"liquid_policy":liquid_policy,
		"controlled_liquid_setup":controlled_setup,
	})
	return true

func _microscenario_installed(definition: Dictionary) -> void:
	_liquid_tower_active = false
	_liquid_water_active = false
	microscenario_error = ""
	var player_configuration: Dictionary = pending_microscenario_apply.get(
		"player_configuration",
		{
			"representation":"sampled",
			"runtime_recovery_enabled":true,
			"experimental":false,
		}
	)
	_apply_microscenario_player_configuration(definition, player_configuration)
	microscenario_definition = definition.duplicate(true)
	microscenario_liquid_policy = pending_microscenario_apply.get("liquid_policy", null)
	microscenario_liquid_setup = pending_microscenario_apply.get("controlled_liquid_setup", {}).duplicate(true)
	microscenario_liquid_setup.erase("physical_owner")
	tower_active = true
	paused = true
	current_view_size = Vector2i(480, 270)
	camera_follow_enabled = false
	camera_origin = Vector2(definition.camera_origin[0], definition.camera_origin[1])
	character_position = Vector2(definition.player_start[0], definition.player_start[1])
	if _pending_physical_candidate != null:
		_adopt_prepared_physical_candidate()
	elif physical_rig_id != &"":
		_activate_articulated_actor_rigs(character_position)
	elif player_uses_barrel():
		_activate_microscenario_barrel_player(character_position)
	else:
		_activate_water_body_scenario(bool(definition.body_enabled))
	$Layout/Title.text = "CYBERSAND / MICROSCENARIO / " + str(definition.id)
	if showcase_presentation != null:
		showcase_presentation.installed(definition)
	if blacksite_nine_presentation != null:
		blacksite_nine_presentation.installed(definition)
	if not microscenario_liquid_setup.is_empty():
		simulation_worker.acknowledge_prepared_liquid_configuration(int(pending_microscenario_apply.get("serial",0)))

func microscenario_reset() -> void:
	if not pending_microscenario_apply.is_empty() or not pending_water_apply.is_empty(): return
	if tower_context.get("micro_active", false):
		if not microscenario_liquid_setup.is_empty() and microscenario_liquid_policy != null:
			if microscenario_liquid_setup.get("intent", "controlled") == "exploratory":
				microscenario_apply_exploratory_liquid(microscenario_definition, microscenario_liquid_policy,
					microscenario_liquid_setup.get("normalization", "") == "water-normalize-v1", microscenario_mode,{},
					int(microscenario_liquid_setup.get("maximum_rule_radius",2)))
			else:
				microscenario_apply_controlled_liquid(microscenario_definition, microscenario_liquid_policy,
					microscenario_liquid_setup.get("normalization", "") == "water-normalize-v1", microscenario_mode,
					int(microscenario_liquid_setup.get("maximum_rule_radius",2)))
		else:
			microscenario_apply_definition(microscenario_definition, microscenario_mode)
	elif water_controlled_run_active():
		water_lab_reset()
	else:
		tower_reset()

func microscenario_capture() -> void:
	if not pending_microscenario_apply.is_empty() or not pending_water_apply.is_empty(): return
	if not water_blind_set.is_empty() or not water_active_blind_label.is_empty(): return
	var identity: Dictionary = CyberMicroScenarioIdentity.current()
	identity["player_environment_profile"] = active_player_environment_profile.duplicate(true)
	identity["player_representation"] = player_representation_identity()
	identity["sampled_runtime_recovery_enabled"] = sampled_runtime_recovery_enabled
	if player_uses_barrel():
		identity["player_body_index"] = CyberPlayerRepresentation.BARREL_BODY_INDEX
	tower_command({"scenario_capture":true, "identity":identity})

func _write_microscenario_capture(report: Dictionary) -> void:
	var target: String = "user://microscenario-observation.json"
	var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if file == null:
		microscenario_error = "Could not write MicroScenario capture"
		return
	var text: String = JSON.stringify(report, "  ")
	file.store_string(text + "\n")
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(target + ".tmp"), ProjectSettings.globalize_path(target)) != OK:
		microscenario_error = "Could not complete MicroScenario capture write"
		return
	if microscenario_panel != null: microscenario_panel.workbench.accept_capture(report)
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD): DisplayServer.clipboard_set(text)

func microscenario_toggle_hud() -> void:
	microscenario_hud_hidden = not microscenario_hud_hidden
	_refresh_microscenario_controls()

func _refresh_microscenario_controls() -> void:
	if microscenario_panel == null: return
	microscenario_panel.refresh(tower_context)
	microscenario_panel.visible = not microscenario_hud_hidden
	var help: Label = $Layout/Help
	if tower_context.get("micro_active",false):
		if _microscenario_saved_help.is_empty(): _microscenario_saved_help = help.text
		help.text = "F3 compact/details · Shift+F3 stats · F8 clean view · H publication Hz · J shape · -/+ size · ,/. rectangle ratio · O rotate · LMB paint primary · MMB paint secondary · RMB erase"
	elif not _microscenario_saved_help.is_empty():
		help.text = _microscenario_saved_help
		_microscenario_saved_help = ""
	$Layout/Title.visible = not microscenario_hud_hidden
	help.visible = (
		not microscenario_hud_hidden
		and debug_stats_visible
		and debug_stats_expanded
	)
	var failed: bool = latest_snapshot != null and latest_snapshot.simulation_failed
	status_label.visible = (
		not microscenario_hud_hidden
		and (debug_stats_visible or failed)
	)
	if microscenario_hud_hidden or tower_context.get("micro_active", false) or (
		tower_context.get("microscenario", {}).get("mode", "Inspect") == "Play"):
		tower_panel.visible = false
		for label: Label in tower_panel.labels: label.visible = false
	var launcher: Node = get_node_or_null("Layout/ExperimentTowerLauncher")
	if launcher != null: launcher.visible = not microscenario_hud_hidden
	var recording_launcher: Node = get_node_or_null("Layout/GameplayRecordingLauncher")
	if recording_launcher != null:
		recording_launcher.visible = not microscenario_hud_hidden
	if player_environment_button != null:
		player_environment_button.visible = not microscenario_hud_hidden
	if microscenario_hud_hidden and player_environment_panel != null:
		player_environment_panel.hide()
	if actor_prototype_button != null:
		actor_prototype_button.visible = not microscenario_hud_hidden
	if microscenario_hud_hidden and actor_prototype_panel != null:
		actor_prototype_panel.hide()

func showcase_launch_blocked() -> bool:
	return (_actor_reset_receipt != 0
		or (actor_prototype_panel != null and actor_prototype_panel.visible))

func _microscenario_execution_locked() -> bool:
	return tower_context.get("micro_active", false) and tower_context.get("microscenario", {}).get("execution_policy", "owner") == "fixed"

func _microscenario_tool_allowed(material_id: int) -> bool:
	if not tower_context.get("micro_active", false): return true
	return ("erase" if material_id == 0 else "paint") in tower_context.get("microscenario", {}).get("tools", [])

func setup_tower_panel() -> void:
	tower_panel = CyberTowerPanel.new()
	$Layout.add_child(tower_panel)
	$Layout.move_child(tower_panel,1)
	tower_panel.setup(self)
	tower_profile_panel = CyberTransportProfilePanel.new()
	add_child(tower_profile_panel)
	tower_profile_panel.setup(self)
	microscenario_panel = CyberMicroScenarioPanel.new()
	$Layout.add_child(microscenario_panel)
	$Layout.move_child(microscenario_panel, 1)
	microscenario_panel.setup(self)
	showcase_presentation = ShowcasePresentation.new()
	showcase_presentation.setup(self)
	blacksite_nine_presentation = BlacksiteNinePresentation.new()
	blacksite_nine_presentation.setup(self)
	water_experiment_panel = CyberWaterExperimentPanel.new()
	add_child(water_experiment_panel)
	var profile_input: Variant = {}
	if FileAccess.file_exists(WATER_POLICY_PATH):
		profile_input = FileAccess.get_file_as_string(WATER_POLICY_PATH)
	var launch_arguments: PackedStringArray=water_launch_arguments()
	water_experiment_panel.setup(profile_input,launch_arguments)
	water_experiment_panel.apply_requested.connect(water_lab_apply_result)
	var startup: Dictionary
	if profile_input is String:
		var parsed_profile: Dictionary=CyberWaterExperimentProfiles.parse_profile(profile_input)
		startup=(CyberWaterExperimentProfiles.resolve(parsed_profile.values,
			launch_arguments,{}) if parsed_profile.get("ok",false) else parsed_profile)
	else:
		startup=CyberWaterExperimentProfiles.resolve(profile_input,launch_arguments,{})
	water_policy_available=bool(startup.get("ok",false))
	if water_policy_available: water_policy_resolved=startup

func water_launch_arguments() -> PackedStringArray:
	return OS.get_cmdline_user_args()

func water_lab_open() -> void:
	if not water_blind_set.is_empty() or not water_active_blind_label.is_empty():
		return
	water_experiment_panel.popup_centered()

func water_lab_reset() -> void:
	if not water_policy_available: return
	water_lab_apply_result(water_policy_resolved,water_active_blind_label)

func water_lab_save_profile() -> bool:
	if (not water_policy_available or not water_policy_resolved.get("ok",false)
		or not water_blind_set.is_empty()
		or not water_active_blind_label.is_empty()): return false
	var file: FileAccess=FileAccess.open(WATER_POLICY_PATH,FileAccess.WRITE)
	if file==null: return false
	file.store_string(str(water_policy_resolved.canonical_json)+"\n")
	return true

func _water_blind_application_allowed(result: Dictionary, blind_label: String) -> bool:
	var blind_active: bool=(
		not water_blind_set.is_empty() or not water_active_blind_label.is_empty())
	if not blind_active:
		return blind_label.is_empty()
	if (blind_label.is_empty() or not water_blind_set.get("ok",false)
		or not blind_label in water_blind_set.get("hidden_mapping",{})):
		return false
	var hidden: Dictionary=water_blind_set.hidden_mapping[blind_label]
	return str(hidden.get("hash",""))==str(result.get("hash",""))

func water_controlled_run_active() -> bool:
	return (tower_context.get("water_active",false)
		or not pending_water_apply.is_empty()
		or (not pending_water_exit.is_empty() and not water_blind_set.is_empty()))

func water_lab_apply_result(result: Dictionary, blind_label: String = "") -> void:
	if not result.get("ok",false): return
	if not _water_blind_application_allowed(result,blind_label): return
	if _liquid_water_active and tower_context.get("water_active",false):
		_apply_prepared_liquid_water(microscenario_liquid_policy,microscenario_liquid_setup.get("normalization","") == "water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),result)
		return
	_force_sampled_player_for_lab()
	var checked: Dictionary=CyberWaterExperimentProfiles.resolve({},{},result.policy)
	if not checked.get("ok",false) or str(checked.hash)!=str(result.hash): return
	var recipe: Dictionary=CyberWaterFeelScenarios.recipe(
		str(checked.policy.scenario_id),int(checked.policy.seed))
	if recipe.is_empty(): return
	var previous_paused: bool=paused
	pending_microscenario_apply.clear()
	paused=true
	pending_water_apply={"result":result.duplicate(true),"recipe":recipe.duplicate(true),
		"blind_label":blind_label,"hash":str(checked.hash),
		"previous_paused":previous_paused}
	tower_command({
		"water_reset":true,
		"water_policy":checked.policy,
		"water_policy_hash":checked.hash,
		"water_policy_provenance":result.get("provenance",{}),
		"blind_label":blind_label,
	})

func water_lab_prepare_blind(
		mass_candidates: Array[int] = [3,5,8],
		blind_seed: int = -1
	) -> bool:
	if not water_policy_available: return false
	if _liquid_water_active:
		microscenario_error = "Prepared solver Water Feel is Exploratory; return to the original constructor before starting a blind run"
		return false
	if not water_blind_set.is_empty() or not water_active_blind_label.is_empty():
		return false
	var candidates: Array=[]
	var base: Dictionary=water_policy_resolved.policy.duplicate(true)
	water_blind_base=water_policy_resolved.duplicate(true)
	base.interface_mode="oriented"
	for bits: int in mass_candidates:
		var candidate: Dictionary=base.duplicate(true)
		candidate.mass_bits=bits
		var candidate_resolved: Dictionary=CyberWaterExperimentProfiles.resolve({},{},candidate)
		var provenance: Dictionary=water_policy_resolved.get("provenance",{}).duplicate(true)
		var origins: Dictionary=provenance.get("field_origins",{}).duplicate(true)
		origins["mass_bits"]="panel"
		origins["interface_mode"]="panel"
		var layers: Array=provenance.get("applied_layers",[]).duplicate()
		if not "panel" in layers: layers.append("panel")
		candidate_resolved.source="panel"
		candidate_resolved.provenance={"effective_source":"panel",
			"field_origins":origins,"applied_layers":layers}
		candidates.append(candidate_resolved)
	var seed_value: int=blind_seed if blind_seed>=0 else int(base.seed)+1009
	water_blind_set=CyberWaterExperimentBlind.create(candidates,seed_value)
	water_blind_index=0
	if not water_blind_set.get("ok",false): return false
	return water_lab_apply_blind(0)

func water_lab_apply_blind(index: int = -1) -> bool:
	if not water_blind_set.get("ok",false): return false
	if index<0: index=(water_blind_index+1)%water_blind_set.labels.size()
	if index<0 or index>=water_blind_set.labels.size(): return false
	water_blind_index=index
	var label: String=water_blind_set.labels[index]
	var hidden: Dictionary=water_blind_set.hidden_mapping[label]
	var resolved: Dictionary=CyberWaterExperimentProfiles.resolve({},{},hidden.policy)
	if not resolved.get("ok",false) or str(resolved.hash)!=str(hidden.hash): return false
	resolved.source=hidden.source
	resolved.provenance=hidden.provenance.duplicate(true)
	water_lab_apply_result(resolved,label)
	return true

func _activate_water_body_scenario(active: bool) -> void:
	_close_prepared_reference_bodies()
	_close_physical_actors()
	var default_shape := RectangleShape2D.new()
	default_shape.size = TEST_RIGID_BODY_SIZE
	test_rigid_body_1.get_node("CollisionShape2D").shape = default_shape
	if not active:
		for body: RigidBody2D in [test_rigid_body_1,test_rigid_body_2,test_rigid_body_3]:
			body.freeze=true
			body.collision_layer=0
			body.collision_mask=0
		rapier_bridge.shutdown()
		rigid_bodies.clear()
		for i: int in range(3):
			world_shader.set_shader_parameter("rigid_body_data_%d" % i,Vector4(-1000,-1000,0,0))
		return
	if rigid_bodies.is_empty():
		rigid_bodies=[test_rigid_body_1,test_rigid_body_2,test_rigid_body_3]
	var body_sizes:=PackedVector2Array()
	body_sizes.resize(rigid_bodies.size())
	body_sizes.fill(TEST_RIGID_BODY_SIZE)
	if not rapier_bridge.is_initialized():
		rapier_start_error=rapier_bridge.initialize(
			get_viewport().world_2d.space,rigid_bodies,body_sizes)
	for i: int in range(rigid_bodies.size()):
		rigid_bodies[i].freeze=false
		rigid_bodies[i].collision_layer=1
		rigid_bodies[i].collision_mask=1
		if rapier_bridge.is_initialized():
			rapier_bridge.reset_body(i,Vector2(160+i*52,176),0.0)

func tower_command(command: Dictionary) -> bool:
	if water_controlled_run_active() and (
		command.has("release") or command.has("schedule")
	):
		return false
	if (tower_context.get("micro_active", false) and not command.has("reset")
		and (command.has("release") or command.has("schedule") or command.has("floor"))): return false
	if not pending_microscenario_apply.is_empty() and not command.has("scenario_reset"): return false
	if command.has("step"): paused = true
	var request: Dictionary = command.duplicate(true)
	request["scenario_mode"] = microscenario_mode
	simulation_worker.queue_lab(request)
	return true

func tower_floor_select(index: int) -> void:
	if water_controlled_run_active() or tower_context.get("micro_active", false): return
	tower_floor = clampi(index,0,4)
	paused = true
	camera_follow_enabled = false
	camera_origin = Vector2(0,CyberExperimentTower.floor_y(tower_floor))
	tower_command({"floor":tower_floor})

func tower_reset() -> void:
	if _liquid_tower_active and tower_active and not tower_context.get("micro_active",false) and not tower_context.get("water_active",false):
		_apply_prepared_liquid_tower(microscenario_liquid_policy,microscenario_liquid_setup.get("normalization","") == "water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),CyberTransportProfiles.resolve(tower_profile))
		return
	_liquid_tower_active = false
	_force_sampled_player_for_lab()
	pending_microscenario_apply.clear()
	_water_exit_request_serial += 1
	pending_water_exit={"kind":"fresh","request_serial":_water_exit_request_serial}
	pending_water_apply.clear()
	tower_active = true
	current_view_size = Vector2i(480,270)
	paused = true
	for body: RigidBody2D in rigid_bodies: body.freeze = true
	rapier_bridge.shutdown()
	rigid_bodies.clear()
	for i: int in range(3): world_shader.set_shader_parameter("rigid_body_data_%d" % i,Vector4(-1000,-1000,0,0))
	$Layout/Title.text = "CYBERSAND / EXPERIMENT TOWER"
	var resolved: Dictionary = CyberTransportProfiles.resolve(tower_profile)
	tower_command({"reset":true,"floor":tower_floor,"profile":resolved,
		"water_exit_request_serial":_water_exit_request_serial})
	camera_follow_enabled = false
	camera_origin = Vector2(0,CyberExperimentTower.floor_y(tower_floor))

func tower_tuning() -> void:
	paused = true
	tower_profile_panel.popup_centered()

func tower_focus_tube(index: int) -> void:
	if water_controlled_run_active(): return
	var tubes: Array=CyberExperimentTower.tubes(tower_floor)
	if index < 0 or index >= tubes.size(): return
	paused=true
	camera_follow_enabled=false
	camera_origin=Vector2(clampf(float(tubes[index][0])-100.0,0.0,1024.0-current_view_size.x),CyberExperimentTower.floor_y(tower_floor))

func tower_apply_profile(resolved: Dictionary) -> void:
	if _liquid_tower_active and not tower_context.get("micro_active",false) and not tower_context.get("water_active",false):
		_apply_prepared_liquid_tower(microscenario_liquid_policy,microscenario_liquid_setup.get("normalization","") == "water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),resolved)
		return
	pending_microscenario_apply.clear()
	_water_exit_request_serial += 1
	pending_water_exit={"kind":"profile","request_serial":_water_exit_request_serial}
	pending_water_apply.clear()
	paused = true
	tower_command({"reset":true,"floor":tower_floor,"profile":resolved,
		"water_exit_request_serial":_water_exit_request_serial})

func tower_observation() -> void:
	var report: Dictionary = {"recipe_version":CyberExperimentTower.VERSION,"seed":0,"floor":tower_floor,"context":tower_context,"platform":OS.get_name(),"utc":Time.get_datetime_string_from_system(true)}
	if tower_context.get("water_active",false):
		report["runtime_identity"]=water_runtime_identity()
		report["water_feel_version"]=CyberWaterFeelScenarios.VERSION
		report["effective_policy"]=tower_context.get("water_policy",{}).duplicate(true)
		report["effective_policy_hash"]=str(tower_context.get("water_policy_hash",""))
		report["policy_provenance"]=tower_context.get("water_policy_provenance",{}).duplicate(true)
		report["scenario_id"]=str(report.effective_policy.get("scenario_id",""))
		report["seed"]=int(report.effective_policy.get("seed",0))
		report["recipe_hash"]=str(tower_context.get("water_recipe_hash",""))
		report["presentation_mode"]="four-level-"+str(report.effective_policy.get("interface_mode","coverage"))
		report["worker_count"]=latest_snapshot.scheduler_thread_capacity_hint if latest_snapshot!=null else int(tower_context.get("worker_count",1))
		report["backend"]=latest_snapshot.backend_name if latest_snapshot!=null else str(tower_context.get("backend","unknown"))
		report["action_history"]=tower_context.get("water_actions",[]).duplicate(true)
		report["observations"]=tower_context.get("water_observations",[]).duplicate(true)
		report["water_accounting"]=tower_context.get("water_accounting",{}).duplicate(true)
		report["blind_label"]=str(tower_context.get("water_blind_label",""))
		if water_blind_set.get("ok",false):
			var blind_export: Dictionary=CyberWaterExperimentBlind.export_metadata(
				water_blind_set,{"scenario_id":report.scenario_id,"seed":report.seed,
					"recipe_hash":report.recipe_hash,"platform":report.platform,
					"worker_count":report.worker_count,"action_history":report.action_history})
			if blind_export.get("ok",false):
				report["blind"]=blind_export.metadata
	var file: FileAccess = FileAccess.open("user://tower-observation.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"  "))
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD): DisplayServer.clipboard_set(JSON.stringify(report,"  "))

func _water_end_blind_session() -> void:
	if not water_active_blind_label.is_empty() and water_blind_base.get("ok",false):
		water_policy_resolved=water_blind_base.duplicate(true)
		water_policy_available=true
	water_blind_base.clear()
	water_blind_set.clear()
	water_blind_index=0
	water_active_blind_label=""

func _reconcile_water_exit(context: Dictionary) -> void:
	if pending_water_exit.is_empty(): return
	var request_serial: int = int(pending_water_exit.get("request_serial",0))
	if (request_serial <= 0
		or int(context.get("water_exit_request_serial",0)) != request_serial
		or not context.has("water_exit_request_applied")):
		return
	# Status text can persist in later snapshots of an older rejected request.
	# Only this request's owner receipt may retire it or end the blind session.
	if not bool(context.water_exit_request_applied):
		pending_water_exit.clear()
	elif not bool(context.get("water_active",true)) and context.has("profile"):
		_water_end_blind_session()
		_liquid_water_active = false
		if not _liquid_tower_active and not context.get("micro_active",false):
			microscenario_liquid_policy = null;microscenario_liquid_setup = {};microscenario_definition = {}
		pending_water_exit.clear()

func water_runtime_identity() -> Dictionary:
	var path: String=(
		"res://addons/cybersand_native/runtime-provenance.web.json"
		if OS.has_feature("web")
		else "res://addons/cybersand_native/runtime-provenance.json")
	var result: Dictionary={"platform":OS.get_name(),
		"godot":Engine.get_version_info().get("string","unknown"),"manifest":path}
	if not FileAccess.file_exists(path):
		result["status"]="manifest-unavailable"
		return result
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		result["status"]="manifest-invalid"
		return result
	result.merge(parsed,true)
	return result


func recording_runtime_identity() -> Dictionary:
	var source_revision: String = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	if source_revision.is_empty():
		source_revision = OS.get_environment("GITHUB_SHA")
	if source_revision.is_empty():
		source_revision = "unavailable"
	return {
		"source": CyberMicroScenarioIdentity.current(source_revision),
		"native_runtime": water_runtime_identity(),
		"recorder_script": {
			"path": "res://scripts/gameplay_recorder.gd",
			"sha256": FileAccess.get_sha256("res://scripts/gameplay_recorder.gd"),
		},
		"worker": {
			"backend": latest_snapshot.backend_name if latest_snapshot != null else "unavailable",
			"worker_count": latest_snapshot.scheduler_thread_capacity_hint if latest_snapshot != null else 0,
		},
		"desktop_configuration": {
			"render_snapshot_hz": render_snapshot_hz,
			"simulation_window_enabled": simulation_window_enabled,
			"cadence_lod_enabled": cadence_lod_enabled,
			"liquid_surface_adhesion_enabled": liquid_surface_adhesion_enabled,
			"view_size": [current_view_size.x, current_view_size.y],
			"simulation_margin": [simulation_margin.x, simulation_margin.y],
			"requested_native_worker_threads": int(
				ProjectSettings.get_setting("cybersand/native_worker_threads", 0)
			),
			"player_environment_profile": active_player_environment_profile.duplicate(true),
		},
	}


func recording_configuration() -> Dictionary:
	var roi: Rect2i = Rect2i(
		floori(camera_origin.x),
		floori(camera_origin.y),
		current_view_size.x,
		current_view_size.y
	)
	var result: Dictionary = {
		"capture_hz": DEFAULT_RECORDING_HZ,
		"queue_capacity": DEFAULT_RECORDING_QUEUE_CAPACITY,
		"roi": roi,
		"retain_raw_ids": true,
		"selected_material_id_at_start": selected_material_id,
		"selected_paint_slot_at_start": selected_paint_slot,
	}
	for raw_argument: String in OS.get_cmdline_user_args():
		var argument: String = str(raw_argument)
		if argument.begins_with("--record-hz="):
			result.capture_hz = clampi(
				int(argument.trim_prefix("--record-hz=")),
				1,
				60
			)
		elif argument.begins_with("--record-queue="):
			result.queue_capacity = clampi(
				int(argument.trim_prefix("--record-queue=")),
				1,
				GameplayRecorder.MAX_QUEUE_CAPACITY
			)
		elif argument.begins_with("--record-roi="):
			var parts: PackedStringArray = argument.trim_prefix("--record-roi=").split(",")
			if parts.size() == 4:
				result.roi = Rect2i(
					int(parts[0]),
					int(parts[1]),
					maxi(1, int(parts[2])),
					maxi(1, int(parts[3]))
				)
	return result


func toggle_gameplay_recording() -> void:
	if gameplay_recorder.is_active():
		var current_status: Dictionary = gameplay_recorder.status()
		if bool(current_status.get("accepting", false)):
			var requested: Dictionary = gameplay_recorder.request_stop()
			print("REC-001 recording finalization requested: ", JSON.stringify(requested))
		_refresh_recording_button()
		return
	var start_error: Error = gameplay_recorder.start_recording(
		recording_configuration(),
		recording_runtime_identity()
	)
	if start_error != OK:
		push_error("REC-001 recorder failed to start: error %d" % int(start_error))
		_refresh_recording_button()
		return
	# A full immutable render publication primes the recorder's private ROI. The
	# recorder never reaches back into mutable World storage.
	simulation_worker.request_render_full_refresh()
	print("REC-001 recording started: ", gameplay_recorder.session_path())
	_refresh_recording_button()


func _refresh_recording_button() -> void:
	if recording_button == null:
		return
	var recorder_status: Dictionary = gameplay_recorder.status()
	recording_button.disabled = bool(recorder_status.get("finalizing", false))
	if bool(recorder_status.get("active", false)):
		if bool(recorder_status.get("failed", false)):
			recording_button.text = "Recording failed (finalizing)"
		elif bool(recorder_status.get("finalizing", false)):
			recording_button.text = "Finalizing recording..."
		elif not bool(recorder_status.get("primed", false)):
			recording_button.text = "Recording (priming) / F10"
		else:
			recording_button.text = "Stop Recording / F10"
		recording_button.tooltip_text = (
			"%s | written %d | queued %d/%d | dropped %d" % [
				str(recorder_status.get("session_path", "")),
				int(recorder_status.get("written_frames", 0)),
				int(recorder_status.get("queued_frames", 0)),
				int(recorder_status.get("queue_capacity", 0)),
				int(recorder_status.get("dropped_frames", 0)),
			]
		)
	else:
		recording_button.disabled = false
		recording_button.text = "Start Recording / F10"
		var prior_path: String = str(recorder_status.get("session_path", ""))
		recording_button.tooltip_text = (
			"Last recording: " + prior_path
			if not prior_path.is_empty()
			else "Record low-overhead material-state evidence"
		)


var latest_snapshot: CyberSimulationSnapshot
var worker_start_error: Error = OK
var consumed_snapshot_serial: int = -1

var image: Image
var texture: ImageTexture
var previous_texture: ImageTexture
var material_appearance_lut: ImageTexture
var material_appearance_program: ImageTexture
var render_channels: int = 1
var render_image_format: Image.Format = Image.FORMAT_R8
var last_uploaded_render_snapshot_serial: int = 0
var last_uploaded_world_generation: int = -1
var last_render_patch_count: int = 0
var last_render_patch_bytes: int = 0
var last_render_was_full_refresh: bool = false
var rejected_render_snapshot_count: int = 0
var last_rejected_render_snapshot_serial: int = -1
var last_render_patch_validation_error: String = ""
var last_render_publication_usec: int = -1
var measured_render_publication_hz: float = 0.0
var snapshot_blend_start_usec: int = 0
var glow_enabled: bool = true
var debug_stats_visible: bool = true
var debug_stats_expanded: bool = false
var glow_viewport: SubViewport
var glow_source: ColorRect
var glow_source_shader: ShaderMaterial
var glow_overlay: TextureRect
var glow_composite_shader: ShaderMaterial
# Presentation-only Steam/Smoke afterimage: two half-float viewports ping-pong
# once per rendered frame (see material_vapour_trail.gdshader).
var vapour_trail_viewports: Array[SubViewport] = []
var vapour_trail_shaders: Array[ShaderMaterial] = []
var vapour_trail_origins: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var vapour_trail_latest: int = -1
var vapour_trail_frame: int = -1
var vapour_trail_usec: int = 0
var vapour_trail_enabled: bool = true
var selected_paint_slot: int = PAINT_SLOT_SAND
var selected_material_id: int = CyberCellWorld.SAND
var view_size_index: int = 0
var current_view_size: Vector2i = DEFAULT_VIEW_SIZE
var simulation_margin_index: int = 1
var simulation_margin: Vector2i = SIMULATION_MARGIN_PRESETS[simulation_margin_index]
var paused: bool = false
var simulation_window_enabled: bool = true
var cadence_lod_enabled: bool = true
var coherent_liquid_emission: bool = false
var liquid_surface_adhesion_enabled: bool = true
var render_snapshot_hz_index: int = 2
var render_snapshot_hz: int = RENDER_SNAPSHOT_HZ_PRESETS[render_snapshot_hz_index]
var status_accumulator: float = 0.0
var upload_time_ms: float = 0.0
var last_uploaded_revision: int = -1
var frame_time_ms: float = 0.0
var maximum_frame_time_ms: float = 0.0
var maximum_collider_time_ms: float = 0.0

var character_position: Vector2 = CHARACTER_SPAWN
var camera_origin: Vector2 = Vector2.ZERO
var camera_follow_enabled: bool = true
var player_representation: StringName = CyberPlayerRepresentation.SAMPLED
var sampled_runtime_recovery_enabled: bool = true
var barrel_player_spawn_position: Vector2 = CHARACTER_SPAWN
var player_representation_button: Button
var actor_prototype_button: Button
var actor_prototype_panel: CyberActorPrototypePanel
var actor_prototype_overlay: CyberActorPrototypeOverlay
var actor_model_selection: StringName = &""
var actor_producer_selection: StringName = &"human"
var actor_demo_npcs: bool = false
var _actor_input_epoch: int = -1
var _actor_input_sequence: int = 0
var _actor_input_rearm: bool = true
var _actor_reset_receipt: int = 0
var _actor_effort: float = 0.7
var actor_usable_index: int = -1
var _actor_usable_requested_index: int = -1
var _actor_usable_power: float = 0.8
var _actor_usable_input_epoch: int = -1
var _actor_usable_input_sequence: int = 0
var _actor_usable_input_rearm: bool = true
var _actor_usable_pointer_rearm: bool = true
var _actor_usable_transition_pending: bool = false
var usable_overlay: CyberUsableOverlay
var rigid_bodies: Array[RigidBody2D] = []
var rapier_bridge: CyberRapierPhysicsBridge = CyberRapierPhysicsBridge.new()
var rapier_start_error: Error = OK
var fallback_rigid_body_sample_serial: int = 0
var last_hard_surface_revision: int = -1
var hard_surface_rebuild_cooldown: float = 0.0


func setup_player_environment_tuning() -> void:
	active_player_environment_profile = PlayerEnvironmentProfiles.preset(
		PlayerEnvironmentProfiles.PRESET_CURRENT
	)
	player_environment_button = Button.new()
	player_environment_button.name = "PlayerEnvironmentTuningLauncher"
	player_environment_button.text = "Player / Environment Tuning"
	player_environment_button.focus_mode = Control.FOCUS_NONE
	player_environment_button.pressed.connect(toggle_player_environment_tuning)
	$Layout.add_child(player_environment_button)

	player_environment_panel = PlayerEnvironmentPanel.new()
	player_environment_panel.configure(
		PlayerEnvironmentProfiles,
		active_player_environment_profile
	)
	player_environment_panel.apply_requested.connect(apply_player_environment_profile)
	player_environment_panel.visible = false
	$Layout.add_child(player_environment_panel)


func toggle_player_environment_tuning() -> void:
	if player_environment_panel == null:
		return
	player_environment_panel.visible = not player_environment_panel.visible


func apply_player_environment_profile(candidate: Dictionary) -> void:
	if actor_model_selection != &"":
		player_environment_panel.set_error(
			"Actor prototypes own their movement settings. Select Current sampled character in F5 to tune PENV."
		)
		return
	if (
		not water_blind_set.is_empty()
		or not water_active_blind_label.is_empty()
	):
		player_environment_panel.set_error(
			"Finish/reveal the active Water blind set before changing player tuning."
		)
		return
	var resolved: Dictionary = PlayerEnvironmentProfiles.resolve(candidate)
	if not resolved.get("ok", false):
		player_environment_panel.set_error(
			"Rejected: " + str(resolved.get("error", "invalid profile"))
		)
		return
	if _liquid_default_active:
		# Profile tuning remains a fresh reset. Keep the request inside its
		# private candidate rather than modifying the retained player first.
		if _apply_prepared_liquid_default(microscenario_liquid_policy,
			microscenario_liquid_setup.get("normalization","") == "water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),true,null,resolved.profile):
			pending_player_environment_profile = resolved.profile.duplicate(true)
		else: player_environment_panel.set_error(microscenario_error)
		return
	if not simulation_worker.queue_player_environment_profile(resolved.profile):
		player_environment_panel.set_error("Worker rejected the player/environment profile.")
		return

	pending_player_environment_profile = resolved.profile.duplicate(true)
	paused = true

	# Keep TEST-UX brush/HUD state and PCHAR representation/recovery ownership
	# independent. Only simulation/player tuning is rebuilt at the fresh-reset
	# boundary.
	if tower_context.get("micro_active", false):
		microscenario_reset()
	elif water_controlled_run_active():
		water_lab_reset()
	elif tower_active:
		tower_reset()
	else:
		reset_world()


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--depth-lab") and not get_tree().has_meta("cybersand_depth_lab_visited"):
		set_process(false)
		call_deferred("open_depth_lab")
		return
	setup_tower_panel()
	setup_brush_preview()
	setup_player_representation_button()
	setup_player_environment_tuning()
	setup_depth_lab_launcher()
	setup_actor_prototypes()
	setup_flight_lab_launcher()
	var tower_button: Button = Button.new()
	tower_button.name = "ExperimentTowerLauncher"
	tower_button.text = "Experiment Tower / F9"
	tower_button.focus_mode = Control.FOCUS_NONE
	tower_button.pressed.connect(tower_reset)
	$Layout.add_child(tower_button)
	recording_button = Button.new()
	recording_button.name = "GameplayRecordingLauncher"
	recording_button.text = "Start Recording / F10"
	recording_button.focus_mode = Control.FOCUS_NONE
	recording_button.pressed.connect(toggle_gameplay_recording)
	$Layout.add_child(recording_button)
	_refresh_recording_button()
	if OS.get_processor_count() < 4:
		var warning: Label = Label.new()
		warning.text = "4 physical CPU cores are the recommended minimum. Fewer than 4 logical threads reported."
		warning.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
		$Layout.add_child(warning)
	status_label.visible = debug_stats_visible
	$Layout/Help.visible = debug_stats_visible and debug_stats_expanded
	rigid_bodies = [test_rigid_body_1, test_rigid_body_2, test_rigid_body_3]
	var body_sizes: PackedVector2Array = PackedVector2Array()
	body_sizes.resize(rigid_bodies.size())
	body_sizes.fill(TEST_RIGID_BODY_SIZE)
	rapier_start_error = rapier_bridge.initialize(
		get_viewport().world_2d.space,
		rigid_bodies,
		body_sizes
	)
	if rapier_start_error != OK:
		for body: RigidBody2D in rigid_bodies:
			body.freeze = true
	camera_origin = clamped_camera_origin(character_centre() - Vector2(current_view_size) * 0.5)
	update_worker_frame_state()
	_publish_physical_body_state()
	simulation_worker.set_render_snapshot_hz(render_snapshot_hz)
	worker_start_error = simulation_worker.start_worker(CHARACTER_SPAWN)
	if worker_start_error != OK:
		for body: RigidBody2D in rigid_bodies:
			body.freeze = true
	latest_snapshot = simulation_worker.take_latest_snapshot(-1)
	if latest_snapshot != null:
		consumed_snapshot_serial = latest_snapshot.serial
		character_position = latest_snapshot.character_position
		sync_hard_surface_colliders()

	var initial_cells: PackedByteArray = PackedByteArray()
	if latest_snapshot != null:
		render_channels = latest_snapshot.render_channels
		render_image_format = (
			Image.FORMAT_RG8 if render_channels == 2 else Image.FORMAT_R8
		)
		record_render_payload(latest_snapshot)
	initial_cells.resize(
		CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * render_channels
	)
	image = Image.create_from_data(
		CyberCellWorld.WORLD_WIDTH,
		CyberCellWorld.WORLD_HEIGHT,
		false,
		render_image_format,
		initial_cells
	)
	var initial_render_uploaded: bool = false
	if latest_snapshot != null:
		initial_render_uploaded = apply_render_patches_to_image(
			latest_snapshot.render_patch_rectangles,
			latest_snapshot.render_patch_cells,
			latest_snapshot.render_channels
		)
	texture = ImageTexture.create_from_image(image)
	previous_texture = ImageTexture.create_from_image(image)
	material_appearance_lut = CyberMaterialAppearanceLut.create_texture()
	material_appearance_program = CyberMaterialAppearanceLut.create_program_texture()
	world_view.texture = texture
	world_shader.set_shader_parameter("current_world_texture", texture)
	world_shader.set_shader_parameter("previous_world_texture", previous_texture)
	world_shader.set_shader_parameter("material_lut", material_appearance_lut)
	world_shader.set_shader_parameter("material_program_lut", material_appearance_program)
	world_shader.set_shader_parameter(
		"material_lut_size",
		Vector2(
			CyberMaterialAppearanceLut.ATLAS_WIDTH,
			CyberMaterialAppearanceLut.ATLAS_HEIGHT
		)
	)
	setup_glow_pipeline()
	snapshot_blend_start_usec = Time.get_ticks_usec()
	if latest_snapshot != null and initial_render_uploaded:
		last_uploaded_render_snapshot_serial = latest_snapshot.render_snapshot_serial
		last_uploaded_world_generation = latest_snapshot.render_world_generation
		last_uploaded_revision = latest_snapshot.world_revision
		simulation_worker.acknowledge_render_snapshot(
			latest_snapshot.render_snapshot_serial
		)
	elif latest_snapshot != null:
		reject_render_snapshot(latest_snapshot)
	update_shader_parameters()
	update_status()
	var feature: String = str(get_tree().get_meta("cybersand_feature", ""))
	if PhysicalTrial.contains(feature):
		microscenario_launch.call_deferred(feature, "Play", 0)
	elif feature == "blacksite":
		blacksite_nine_presentation.launch.call_deferred()
	elif feature == "showcase":
		showcase_presentation.launch.call_deferred()
	elif feature == "actors":
		toggle_actor_prototypes.call_deferred()
	elif feature == "liquid_comparison":
		microscenario_panel.open_liquids.call_deferred(true)
	elif feature.is_empty() and "--blacksite-nine" in OS.get_cmdline_user_args():
		blacksite_nine_presentation.launch.call_deferred()
	elif feature.is_empty() and "--showcase" in OS.get_cmdline_user_args():
		showcase_presentation.launch.call_deferred()


func _exit_tree() -> void:
	if gameplay_recorder.is_active():
		var stopped: Dictionary = gameplay_recorder.stop_recording()
		print("REC-001 recording finalized at exit: ", JSON.stringify(stopped))
	_close_pending_physical_candidate()
	_close_prepared_reference_bodies()
	_close_physical_actors()
	simulation_worker.stop_worker()
	rapier_bridge.shutdown()


func _process(delta: float) -> void:
	tower_panel.refresh(tower_active,tower_floor,tower_context)
	_refresh_microscenario_controls()
	frame_time_ms = delta * 1000.0
	maximum_frame_time_ms = maxf(maximum_frame_time_ms, frame_time_ms)
	consume_worker_snapshot()
	_advance_prepared_physical_candidate()
	if _pending_physical_candidate == null: refresh_actor_usables()
	gameplay_recorder.poll_finalization()
	_refresh_recording_button()
	sync_player_presentation_position()
	refresh_player_representation_button()
	hard_surface_rebuild_cooldown = maxf(0.0, hard_surface_rebuild_cooldown - delta)
	if hard_surface_rebuild_cooldown <= 0.0:
		sync_hard_surface_colliders()
	rapier_bridge.process_hard_surface_collider_budget(
		HARD_SURFACE_CHUNKS_PER_FRAME,
		HARD_SURFACE_FRAME_BUDGET_USEC
	)
	_update_physical_terrain_ready()
	maximum_collider_time_ms = maxf(
		maximum_collider_time_ms,
		rapier_bridge.last_hard_surface_build_time_ms()
	)
	update_brush_preview()
	handle_painting()
	update_camera(delta)
	actor_prototype_overlay.present(
		latest_snapshot.actor_prototypes if latest_snapshot != null else {},
		camera_origin.floor(), current_view_size, view_content_rect()
	)
	usable_overlay.present(
		(latest_snapshot.physical_usables if physical_actor_session != null else latest_snapshot.actor_usables) if latest_snapshot != null else {},
		camera_origin.floor(), current_view_size, view_content_rect()
	)
	physical_actor_overlay.present(
		physical_actor_session.render_parts() if physical_actor_session != null else [],
		camera_origin.floor(), current_view_size, view_content_rect())
	update_worker_frame_state()
	update_shader_parameters()

	status_accumulator += delta
	if status_accumulator >= STATUS_INTERVAL:
		status_accumulator = 0.0
		update_status()
		refresh_actor_prototypes()
		maximum_frame_time_ms = frame_time_ms
		maximum_collider_time_ms = 0.0


func _physics_process(_delta: float) -> void:
	if _pending_physical_candidate != null:
		# The retained manually stepped space stays at its actual prior pose.
		# Do not reconfigure its equipment, revoke its leases or publish stale
		# body frames while the separate replacement graph is being prepared.
		return
	if physical_actor_session != null:
		physical_actor_session.set_suspended(paused or simulation_worker.has_failed()
			or not _physical_terrain_ready or _actor_reset_receipt != 0
			or not pending_microscenario_apply.is_empty())
	publish_actor_keyboard_input()
	publish_actor_usable_input()
	if paused or simulation_worker.has_failed():
		physical_trial_input.armed = false
	if simulation_worker.has_failed():
		return
	if (
		rapier_bridge.is_initialized()
		and not paused
		and worker_start_error == OK
		and _actor_reset_receipt == 0
		and pending_microscenario_apply.is_empty()
		and (physical_actor_session == null or _physical_terrain_ready)
	):
		apply_latest_rigid_body_results()
		if physical_actor_session != null:
			physical_actor_session.advance(rapier_bridge.fixed_delta())
		else:
			apply_barrel_player_control(_delta)
		rapier_bridge.step()
		if physical_actor_session != null:
			physical_actor_session.complete_step()
	_publish_physical_body_state()


func setup_depth_lab_launcher() -> void:
	var launcher := Button.new()
	launcher.name = "DepthLabLauncher"
	launcher.text = "Depth lab / F4"
	launcher.tooltip_text = "Open the separate layering/parallax prototype scene. Returning starts a fresh sandbox."
	launcher.focus_mode = Control.FOCUS_NONE
	launcher.pressed.connect(open_depth_lab)
	$Layout.add_child(launcher)


func setup_flight_lab_launcher() -> void:
	var launcher := Button.new()
	launcher.name = "PhysicalFlightLabLauncher"
	launcher.text = "4LY flight lab"
	launcher.tooltip_text = "Open the native-material/Rapier four-drone course; F2 returns to feature selection."
	launcher.focus_mode = Control.FOCUS_NONE
	launcher.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://flight_lab.tscn"))
	$Layout.add_child(launcher)


func open_depth_lab() -> void:
	get_tree().set_meta("cybersand_depth_lab_visited", true)
	get_tree().change_scene_to_file("res://depth_lab.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
		and actor_equipment_active()
	):
		var trigger: bool = event.pressed if event.button_index == MOUSE_BUTTON_LEFT else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var alternate: bool = event.pressed if event.button_index == MOUSE_BUTTON_RIGHT else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		_publish_actor_usable_buttons(trigger, alternate)
		get_viewport().set_input_as_handled()



func _unhandled_key_input(event: InputEvent) -> void:
	if physical_rig_id != &"" and event is InputEventKey \
		and (event.keycode in ACTOR_CONTROL_KEYS or event.keycode in PHYSICAL_TOOL_KEYS):
		if actor_human_control_active() and actor_keyboard_allowed() and event.pressed and not event.echo:
			if event.keycode == KEY_BRACKETLEFT:
				_actor_effort = clampf(_actor_effort - 0.05, 0.0, 1.0)
			elif event.keycode == KEY_BRACKETRIGHT:
				_actor_effort = clampf(_actor_effort + 0.05, 0.0, 1.0)
		if not event.echo:
			publish_actor_keyboard_input()
		get_viewport().set_input_as_handled()
		return
	if not physical_trial_arm.is_empty() and event is InputEventKey and event.keycode in [KEY_Q, KEY_E]:
		# Trial torque owns these keys; do not also cycle the brush material.
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		get_viewport().set_input_as_handled()
		open_depth_lab()
		return
	if blacksite_nine_presentation != null and blacksite_nine_presentation.map_popup.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE: blacksite_nine_presentation.map_popup.hide()
			elif event.keycode == KEY_F8: microscenario_toggle_hud()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		if event.shift_pressed:
			blacksite_nine_presentation.launch()
		else:
			showcase_presentation.launch()
		get_viewport().set_input_as_handled()
		return
	if (
		event is InputEventKey and event.keycode in ACTOR_PARAMETRIC_KEYS
		and actor_human_control_active() and actor_keyboard_allowed()
		and int(latest_snapshot.actor_prototypes.get("rig_version", 1)) >= 2
		and not CyberActorPrototypeSession.MODEL_IDS.has(StringName(str(latest_snapshot.actor_prototypes.models[0])))
	):
		if event.pressed and not event.echo:
			if event.keycode == KEY_BRACKETLEFT:
				_actor_effort = clampf(_actor_effort - 0.05, 0.0, 1.0)
			elif event.keycode == KEY_BRACKETRIGHT:
				_actor_effort = clampf(_actor_effort + 0.05, 0.0, 1.0)
		if not event.echo:
			publish_actor_keyboard_input()
		get_viewport().set_input_as_handled()
		return
	if (
		event is InputEventKey and not event.echo
		and event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT]
	):
		# Publish both edges as well as the regular physics sample, preserving a
		# quick tap that starts and ends between two physics callbacks. GUI-owned
		# events never reach this handler; focus/rearm admission still applies.
		publish_actor_keyboard_input()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		toggle_actor_prototypes()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		microscenario_toggle_hud()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		toggle_gameplay_recording()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		if cycle_player_representation():
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		if toggle_sampled_runtime_recovery():
			get_viewport().set_input_as_handled()
		return
	if tower_profile_panel != null and tower_profile_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: tower_profile_panel.hide()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		tower_reset()
		return
	if tower_active and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6 and not tower_context.get("micro_active",false):
			selected_material_id = CyberExperimentTower.QUICK[tower_floor][int(event.keycode)-KEY_1]
			return
		if event.keycode == KEY_R:
			if tower_context.get("micro_active", false): microscenario_reset()
			else: tower_reset()
			return
	if event is not InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.shift_pressed:
		if key_event.keycode == KEY_Q or key_event.keycode == KEY_PAGEUP:
			cycle_material_group(-1)
			return
		if key_event.keycode == KEY_E or key_event.keycode == KEY_PAGEDOWN:
			cycle_material_group(1)
			return

	match key_event.keycode:
		KEY_1:
			select_paint_slot(PAINT_SLOT_SAND)
		KEY_2:
			select_paint_slot(PAINT_SLOT_WATER)
		KEY_3:
			select_paint_slot(PAINT_SLOT_WALL)
		KEY_4:
			select_paint_slot(PAINT_SLOT_SMOKE)
		KEY_5:
			select_paint_slot(PAINT_SLOT_PASTE)
		KEY_6:
			select_paint_slot(PAINT_SLOT_SLUSH)
		KEY_PAGEUP, KEY_Q:
			cycle_material(-1)
		KEY_PAGEDOWN, KEY_E:
			cycle_material(1)
		KEY_V:
			cycle_view_size()
		KEY_B:
			cycle_simulation_margin()
		KEY_C:
			coherent_liquid_emission = not coherent_liquid_emission
		KEY_T:
			set_liquid_surface_adhesion(not liquid_surface_adhesion_enabled)
		KEY_R:
			reset_world()
		KEY_P:
			paused = not paused
		KEY_F:
			set_camera_follow(not camera_follow_enabled)
		KEY_L:
			set_simulation_window(not simulation_window_enabled)
		KEY_K:
			set_cadence_lod(not cadence_lod_enabled)
		KEY_H:
			cycle_render_snapshot_hz()
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
			if key_event.shift_pressed:
				debug_stats_visible = not debug_stats_visible
			else:
				debug_stats_expanded = not debug_stats_expanded
			$Layout/Help.visible = (
				debug_stats_visible
				and debug_stats_expanded
				and not microscenario_hud_hidden
			)
			status_label.visible = debug_stats_visible and not microscenario_hud_hidden
			if debug_stats_visible:
				update_status()


func select_paint_slot(slot: int) -> void:
	var material_id: int = material_id_for_paint_slot(slot)
	if material_id < 0:
		return
	selected_paint_slot = slot
	selected_material_id = material_id


func cycle_material(direction: int) -> void:
	var material_index: int = PAINTABLE_MATERIAL_IDS.find(selected_material_id)
	if material_index < 0:
		material_index = 0
	material_index = posmod(material_index + direction, PAINTABLE_MATERIAL_IDS.size())
	selected_paint_slot = 0
	selected_material_id = PAINTABLE_MATERIAL_IDS[material_index]


func cycle_material_group(direction: int) -> void:
	var group_index: int = 0
	for index: int in range(MATERIAL_GROUP_FIRST_IDS.size()):
		if selected_material_id >= MATERIAL_GROUP_FIRST_IDS[index]:
			group_index = index
	group_index = posmod(group_index + direction, MATERIAL_GROUP_FIRST_IDS.size())
	selected_paint_slot = 0
	selected_material_id = MATERIAL_GROUP_FIRST_IDS[group_index]


func effective_secondary_material_id() -> int:
	var material_index: int = PAINTABLE_MATERIAL_IDS.find(selected_material_id)
	if material_index < 0:
		return PAINTABLE_MATERIAL_IDS[0]
	return PAINTABLE_MATERIAL_IDS[
		posmod(material_index + 1, PAINTABLE_MATERIAL_IDS.size())
	]


func set_brush_shape(shape: String) -> bool:
	if not shape in BRUSH_SHAPES:
		return false
	brush_shape = shape
	return true


func cycle_brush_shape() -> void:
	var index: int = BRUSH_SHAPES.find(brush_shape)
	if index < 0:
		index = 0
	set_brush_shape(BRUSH_SHAPES[(index + 1) % BRUSH_SHAPES.size()])


func set_brush_size(size_px: int) -> bool:
	if size_px < BRUSH_MIN_SIZE_PX or size_px > BRUSH_MAX_SIZE_PX:
		return false
	brush_size_px = size_px
	return true


func set_brush_rectangle_ratio(ratio: int) -> bool:
	if ratio < BRUSH_MIN_RECTANGLE_RATIO or ratio > BRUSH_MAX_RECTANGLE_RATIO:
		return false
	brush_rectangle_ratio = ratio
	return true


func set_brush_rectangle_vertical(vertical: bool) -> void:
	brush_rectangle_vertical = vertical


func brush_dimensions() -> Vector2i:
	if brush_shape != "rectangle":
		return Vector2i(brush_size_px, brush_size_px)
	var short_edge: int = brush_size_px
	var long_edge: int = brush_size_px * brush_rectangle_ratio
	return (
		Vector2i(short_edge, long_edge)
		if brush_rectangle_vertical
		else Vector2i(long_edge, short_edge)
	)


func brush_summary() -> String:
	var dimensions: Vector2i = brush_dimensions()
	match brush_shape:
		"circle":
			return "circle Ø%dpx" % brush_size_px
		"square":
			return "square %d×%dpx" % [dimensions.x, dimensions.y]
		"rectangle":
			return "rect %d×%dpx %s r%d" % [
				dimensions.x,
				dimensions.y,
				"V" if brush_rectangle_vertical else "H",
				brush_rectangle_ratio,
			]
	return brush_shape


func brush_footprint_cells(world_x: int, world_y: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	if brush_shape == "circle" and (brush_size_px & 1) == 1:
		# Odd diameters map exactly to the retained emit_disc lattice. This keeps
		# the default 9 px brush identical to the historical radius-4 tool.
		var radius: int = (brush_size_px - 1) / 2
		var radius_squared: int = radius * radius
		for offset_y: int in range(-radius, radius + 1):
			for offset_x: int in range(-radius, radius + 1):
				if offset_x * offset_x + offset_y * offset_y > radius_squared:
					continue
				cells.append(world_x + offset_x)
				cells.append(world_y + offset_y)
		return cells

	var dimensions: Vector2i = brush_dimensions()
	var start_x: int = world_x - int((dimensions.x - 1) / 2)
	var start_y: int = world_y - int((dimensions.y - 1) / 2)
	var circle_radius: float = float(brush_size_px) * 0.5
	var circle_radius_squared: float = circle_radius * circle_radius
	for local_y: int in range(dimensions.y):
		for local_x: int in range(dimensions.x):
			if brush_shape == "circle":
				var dx: float = float(local_x) + 0.5 - float(dimensions.x) * 0.5
				var dy: float = float(local_y) + 0.5 - float(dimensions.y) * 0.5
				if dx * dx + dy * dy > circle_radius_squared:
					continue
			cells.append(start_x + local_x)
			cells.append(start_y + local_y)
	return cells


func brush_material_for_buttons(
		left_pressed: bool,
		middle_pressed: bool,
		right_pressed: bool
	) -> int:
	if right_pressed:
		return CyberCellWorld.EMPTY
	if middle_pressed:
		return effective_secondary_material_id()
	if left_pressed:
		return selected_material_id
	return -1


func cycle_view_size() -> bool:
	if water_controlled_run_active(): return false
	var previous_centre: Vector2 = camera_origin + Vector2(current_view_size) * 0.5
	view_size_index = (view_size_index + 1) % VIEW_SIZE_PRESETS.size()
	current_view_size = VIEW_SIZE_PRESETS[view_size_index]
	camera_origin = clamped_camera_origin(previous_centre - Vector2(current_view_size) * 0.5)
	update_worker_frame_state()
	update_shader_parameters()
	return true


func cycle_simulation_margin() -> bool:
	if water_controlled_run_active(): return false
	simulation_margin_index = (simulation_margin_index + 1) % SIMULATION_MARGIN_PRESETS.size()
	simulation_margin = SIMULATION_MARGIN_PRESETS[simulation_margin_index]
	update_worker_frame_state()
	return true


func set_liquid_surface_adhesion(enabled: bool) -> bool:
	if _microscenario_execution_locked(): return false
	if water_controlled_run_active(): return false
	liquid_surface_adhesion_enabled=enabled
	update_worker_frame_state()
	return true


func set_camera_follow(enabled: bool) -> bool:
	if water_controlled_run_active(): return false
	if enabled and blacksite_nine_presentation != null and blacksite_nine_presentation.active():
		current_view_size = Vector2i(480, 270)
	camera_follow_enabled=enabled
	return true


func set_simulation_window(enabled: bool) -> bool:
	if _microscenario_execution_locked(): return false
	if water_controlled_run_active(): return false
	simulation_window_enabled=enabled
	update_worker_frame_state()
	return true


func set_cadence_lod(enabled: bool) -> bool:
	if _microscenario_execution_locked(): return false
	if water_controlled_run_active(): return false
	cadence_lod_enabled=enabled
	update_worker_frame_state()
	return true


func cycle_render_snapshot_hz() -> void:
	render_snapshot_hz_index = (
		(render_snapshot_hz_index + 1) % RENDER_SNAPSHOT_HZ_PRESETS.size()
	)
	render_snapshot_hz = RENDER_SNAPSHOT_HZ_PRESETS[render_snapshot_hz_index]
	simulation_worker.set_render_snapshot_hz(render_snapshot_hz)
	snapshot_blend_start_usec = Time.get_ticks_usec()


func material_id_for_paint_slot(slot: int) -> int:
	match slot:
		PAINT_SLOT_SAND:
			return CyberCellWorld.SAND
		PAINT_SLOT_WATER:
			return CyberCellWorld.WATER
		PAINT_SLOT_WALL:
			return CyberCellWorld.WALL
		PAINT_SLOT_SMOKE:
			return CyberCellWorld.SMOKE
		PAINT_SLOT_PASTE:
			return CyberCellWorld.PASTE
		PAINT_SLOT_SLUSH:
			return CyberCellWorld.SLUSH
		_:
			return -1


func setup_player_representation_button() -> void:
	player_representation_button = Button.new()
	player_representation_button.name = "PlayerRepresentation"
	player_representation_button.focus_mode = Control.FOCUS_NONE
	player_representation_button.pressed.connect(cycle_player_representation)
	$Layout.add_child(player_representation_button)
	refresh_player_representation_button()


func player_representation_identity() -> String:
	if physical_rig_id != &"": return "articulated-rapier/" + str(physical_rig_id)
	if not physical_trial_arm.is_empty(): return "physical-" + physical_trial_arm
	if latest_snapshot != null and not latest_snapshot.actor_prototypes.is_empty():
		return latest_snapshot.player_representation
	return CyberPlayerRepresentation.identity(
		player_representation,
		sampled_runtime_recovery_enabled
	)


func player_uses_barrel() -> bool:
	return player_representation == CyberPlayerRepresentation.BARREL_RAPIER


func refresh_player_representation_button() -> void:
	if player_representation_button == null:
		return
	var recovery_text: String = ""
	if actor_model_selection != &"":
		recovery_text = " | prototype controls / F5 | burial-safe"
	elif not player_uses_barrel():
		recovery_text = (
			" | runtime surfacing ON / F7"
			if sampled_runtime_recovery_enabled
			else " | burial-safe ON / F7"
		)
		if latest_snapshot != null and latest_snapshot.character_runtime_recovery_attempts > 0:
			recovery_text += " | recover %d/%d up %dpx" % [
				latest_snapshot.character_runtime_recovery_successes,
				latest_snapshot.character_runtime_recovery_attempts,
				latest_snapshot.character_runtime_recovery_upward_cells,
			]
	else:
		recovery_text = " | articulated controls / F5" if physical_rig_id != &"" else (" | impulses + torque + upward pulse" if not physical_trial_arm.is_empty() else " | horizontal impulse control only")
	player_representation_button.text = "Player %s / F6%s" % [
		player_representation_identity(),
		recovery_text,
	]
	player_representation_button.visible = (
		not tower_active
		and not water_controlled_run_active()
		and not tower_context.get("micro_active", false)
	)


func cycle_player_representation() -> bool:
	if _liquid_default_active:
		microscenario_error = "Prepared native default demo retains its sampled player; load a Current setup before changing player representation"
		return false
	if (
		tower_active
		or water_controlled_run_active()
		or tower_context.get("micro_active", false)
		or not pending_microscenario_apply.is_empty()
		or not pending_water_apply.is_empty()
	):
		return false
	var restore_reference_bodies: bool = not physical_trial_arm.is_empty() or physical_rig_id != &""
	_close_physical_actors()
	physical_rig_id = &""
	physical_trial_arm = ""
	physical_trial_input = PhysicalTrial.new()
	actor_model_selection = &""
	_actor_reset_receipt = 0
	_actor_input_rearm = true
	player_representation = (
		CyberPlayerRepresentation.BARREL_RAPIER
		if player_representation == CyberPlayerRepresentation.SAMPLED
		else CyberPlayerRepresentation.SAMPLED
	)
	barrel_player_spawn_position = CHARACTER_SPAWN
	if restore_reference_bodies:
		_activate_water_body_scenario(false)
		_activate_water_body_scenario(true)
	# Never convert an actor in place. Rebuild both simulation and body state from
	# the ordinary fresh-reset boundary under the newly selected owner.
	reset_world()
	return true


func toggle_sampled_runtime_recovery() -> bool:
	if (
		player_uses_barrel() or actor_model_selection != &""
		or tower_active
		or water_controlled_run_active()
		or tower_context.get("micro_active", false)
		or not pending_microscenario_apply.is_empty() or not pending_water_apply.is_empty()
	):
		return false
	if _liquid_default_active:
		# The requested flag belongs to the candidate player. Main adopts it only
		# with the accepted native World and physical graph; refusal retains it.
		return _apply_prepared_liquid_default(microscenario_liquid_policy,
			microscenario_liquid_setup.get("normalization","") == "water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),true,not sampled_runtime_recovery_enabled)
	sampled_runtime_recovery_enabled = not sampled_runtime_recovery_enabled
	reset_world()
	return true


func _force_sampled_player_for_lab() -> void:
	_close_physical_actors()
	physical_rig_id = &""
	physical_trial_arm = ""
	physical_trial_input = PhysicalTrial.new()
	actor_model_selection = &""
	_actor_reset_receipt = 0
	_actor_input_rearm = true
	if actor_prototype_panel != null:
		actor_prototype_panel.hide()
	# Registered Tower/Water/MicroScenario definitions retain their historical
	# sampled-player identity and body layout. PCHAR switching is an
	# ordinary-sandbox experiment only.
	var restore_body_layout: bool = player_uses_barrel()
	player_representation = CyberPlayerRepresentation.SAMPLED
	sampled_runtime_recovery_enabled = true
	barrel_player_spawn_position = CHARACTER_SPAWN
	if restore_body_layout and not rigid_bodies.is_empty():
		reset_test_rigid_bodies()
		_publish_physical_body_state()
		character_position = CHARACTER_SPAWN
	refresh_player_representation_button()


func _player_configuration_for_microscenario(definition: Dictionary) -> Dictionary:
	var configuration: Dictionary = CyberMicroScenarioCatalogue.player_configuration(
		str(definition.get("id", ""))
	)
	if configuration.is_empty():
		return {
			"representation":"sampled",
			"runtime_recovery_enabled":true,
			"experimental":false,
		}

	var representation := StringName(
		str(configuration.get("representation", "sampled"))
	)
	var runtime_recovery: bool = bool(
		configuration.get("runtime_recovery_enabled", true)
	)
	if not CyberPlayerRepresentation.is_valid(representation):
		microscenario_error = "Experimental fixture has an invalid player representation"
		return {}
	var barrel: bool = representation == CyberPlayerRepresentation.BARREL_RAPIER
	if barrel != bool(definition.body_enabled):
		microscenario_error = (
			"Experimental fixture body ownership does not match its player representation"
		)
		return {}
	if barrel == bool(definition.player_enabled):
		microscenario_error = (
			"Experimental fixture sampled-player ownership does not match its representation"
		)
		return {}

	return {
		"representation":str(representation),
		"runtime_recovery_enabled":runtime_recovery,
		"experimental":true,
		"physical_trial":str(configuration.get("physical_trial", "")),
	}


func _apply_microscenario_player_configuration(
	definition: Dictionary,
	configuration: Dictionary
) -> void:
	physical_trial_arm = str(configuration.get("physical_trial", ""))
	physical_rig_id = StringName(str(configuration.get("physical_rig", "")))
	physical_trial_input = PhysicalTrial.new()
	exploratory_actor_configuration = configuration.duplicate(true) if CyberMicroScenarioCatalogue.exploratory_actor_map(definition) and configuration.has("actor_model") else {}
	actor_model_selection = StringName(str(configuration.get("actor_model", "")))
	actor_producer_selection = StringName(str(configuration.get("actor_producer", "human")))
	actor_demo_npcs = bool(configuration.get("actor_demo_npcs", false))
	_actor_reset_receipt = 0
	_actor_input_rearm = true
	if actor_prototype_panel != null:
		actor_prototype_panel.hide()
	player_representation = StringName(
		str(configuration.get("representation", "sampled"))
	)
	sampled_runtime_recovery_enabled = bool(
		configuration.get("runtime_recovery_enabled", true)
	)
	barrel_player_spawn_position = Vector2(
		definition.player_start[0],
		definition.player_start[1]
	)
	refresh_player_representation_button()


func _activate_microscenario_barrel_player(spawn_position: Vector2) -> void:
	# PLAY-VAL-001 uses only body 0 as the player. Do not activate the other two
	# generic reference bodies, because they would contaminate matched A/B geometry.
	_activate_water_body_scenario(false)
	rigid_bodies = [test_rigid_body_1]
	var size: Vector2 = PhysicalTrial.body_size(physical_trial_arm)
	var shape := RectangleShape2D.new()
	shape.size = size
	test_rigid_body_1.get_node("CollisionShape2D").shape = shape
	var body_sizes := PackedVector2Array([size])
	rapier_start_error = rapier_bridge.initialize(
		get_viewport().world_2d.space,
		rigid_bodies,
		body_sizes
	)
	test_rigid_body_1.freeze = false
	test_rigid_body_1.collision_layer = 1
	test_rigid_body_1.collision_mask = 1
	barrel_player_spawn_position = spawn_position
	if rapier_start_error == OK and rapier_bridge.is_initialized():
		reset_test_rigid_bodies()
	else:
		microscenario_error = "Could not initialize barrel-player Rapier bridge"
	_publish_physical_body_state()


func barrel_player_spawn_centre() -> Vector2:
	return (
		barrel_player_spawn_position
		+ CyberSampledCharacter.BODY_SIZE * 0.5
	)


func apply_barrel_player_control(delta: float) -> void:
	if (
		not player_uses_barrel()
		or not rapier_bridge.is_initialized()
		or rigid_bodies.size() <= CyberPlayerRepresentation.BARREL_BODY_INDEX
	):
		return
	var drive: float = get_horizontal_input()
	if not physical_trial_arm.is_empty():
		drive = _apply_physical_trial_input(delta)
	rapier_bridge.apply_horizontal_control(
		CyberPlayerRepresentation.BARREL_BODY_INDEX,
		drive,
		70.0 if physical_trial_arm == "ripper" else CyberPlayerRepresentation.BARREL_WALK_SPEED,
		260.0 if physical_trial_arm == "ripper" else CyberPlayerRepresentation.BARREL_HORIZONTAL_ACCELERATION,
		CyberPlayerRepresentation.BARREL_MAX_HORIZONTAL_IMPULSE,
		delta
	)


func _apply_physical_trial_input(delta: float) -> float:
	var allowed: bool = get_window().has_focus() and not paused and not _blacksite_keyboard_blocked()
	allowed = allowed and get_viewport().gui_get_focus_owner() == null
	allowed = allowed and not microscenario_panel.modal_open() and not tower_profile_panel.visible and not player_environment_panel.visible and not actor_prototype_panel.visible
	var trim: float = float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	var action: Dictionary = physical_trial_input.sample(delta, allowed, get_horizontal_input(), trim, Input.is_key_pressed(KEY_SPACE))
	rapier_bridge.apply_trial_impulses(0, Vector2(0,-24.0) if action.pulse else Vector2.ZERO, float(action.trim) * delta * 12.0)
	return float(action.drive)


func sync_player_presentation_position() -> void:
	if (
		player_uses_barrel()
		and rapier_bridge.is_initialized()
		and rigid_bodies.size() > CyberPlayerRepresentation.BARREL_BODY_INDEX
	):
		character_position = (
			rapier_bridge.body_transform(
				CyberPlayerRepresentation.BARREL_BODY_INDEX
			).origin
			- CyberSampledCharacter.BODY_SIZE * 0.5
		)


func reset_world() -> void:
	if water_controlled_run_active(): return
	if _liquid_default_active:
		_apply_prepared_liquid_default(microscenario_liquid_policy,
			microscenario_liquid_setup.get("normalization","") == "water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)))
		return
	if physical_rig_id != &"":
		apply_actor_prototype_configuration(StringName("rapier/" + str(physical_rig_id)),
			actor_producer_selection, actor_demo_npcs)
		return
	physical_trial_input = PhysicalTrial.new()
	if actor_model_selection != &"":
		var receipt: int = simulation_worker.queue_actor_prototype_reset(
			actor_prototype_definitions(actor_model_selection, actor_producer_selection, actor_demo_npcs),
			CHARACTER_SPAWN
		)
		if receipt == 0:
			return
		_actor_reset_receipt = receipt
	else:
		simulation_worker.queue_reset(
			CHARACTER_SPAWN,
			not player_uses_barrel(),
			sampled_runtime_recovery_enabled
		)
	_actor_input_rearm = true
	reset_test_rigid_bodies()
	character_position = CHARACTER_SPAWN
	camera_follow_enabled = true
	camera_origin = clamped_camera_origin(character_centre() - Vector2(current_view_size) * 0.5)
	update_worker_frame_state()
	_publish_physical_body_state()


func reset_test_rigid_bodies() -> void:
	if physical_actor_session != null:
		return # Recreate the complete assembly through the fresh-reset path.
	for body_index: int in range(rigid_bodies.size()):
		if rapier_bridge.is_initialized():
			rapier_bridge.reset_body(
				body_index,
				test_rigid_body_spawn(body_index),
				test_rigid_body_rotation(body_index)
			)
			continue
		var body: RigidBody2D = rigid_bodies[body_index]
		body.position = test_rigid_body_spawn(body_index)
		body.rotation = test_rigid_body_rotation(body_index)
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
		body.sleeping = false
	rapier_bridge.reset_result_tracking()


func test_rigid_body_spawn(body_index: int) -> Vector2:
	match body_index:
		0:
			return (
				barrel_player_spawn_centre()
				if player_uses_barrel()
				else Vector2(124.0, 92.0)
			)
		1:
			return Vector2(140.0, 72.0)
		_:
			return Vector2(176.0, 52.0)


func test_rigid_body_rotation(body_index: int) -> float:
	match body_index:
		1:
			return 0.12
		2:
			return -0.1
		_:
			return 0.0


func pack_rigid_body_states() -> PackedFloat32Array:
	if rapier_bridge.is_initialized():
		return rapier_bridge.pack_body_states()
	var states: PackedFloat32Array = PackedFloat32Array()
	fallback_rigid_body_sample_serial = (
		fallback_rigid_body_sample_serial + 1
	) % 1000000
	for body_index: int in range(rigid_bodies.size()):
		var body: RigidBody2D = rigid_bodies[body_index]
		CyberRigidBodyCoupling.append_input(
			states,
			body_index + 1,
			body.position,
			body.rotation,
			TEST_RIGID_BODY_SIZE,
			body.linear_velocity,
			body.angular_velocity,
			body.mass,
			fallback_rigid_body_sample_serial
		)
	return states


func apply_latest_rigid_body_results() -> void:
	if latest_snapshot == null or latest_snapshot.simulation_failed or not rapier_bridge.is_initialized():
		return
	if _actor_reset_receipt != 0 or not pending_microscenario_apply.is_empty():
		return
	if latest_snapshot.rigid_body_epoch != (_physical_epoch if physical_actor_session != null else 0):
		return
	rapier_bridge.apply_cellular_results(
		latest_snapshot.serial,
		latest_snapshot.rigid_body_results
	)


func consume_worker_snapshot() -> void:
	var snapshot: CyberSimulationSnapshot = simulation_worker.take_latest_snapshot(consumed_snapshot_serial)
	if snapshot == null:
		return
	latest_snapshot = snapshot
	_reconcile_actor_prototype_reset()
	tower_context = snapshot.lab_context
	if _liquid_default_active and pending_microscenario_apply.is_empty() \
		and int(tower_context.get("liquid_solver_policy",{}).get("session_generation",0)) != _liquid_default_generation:
		_liquid_default_active = false
	if not pending_microscenario_apply.is_empty():
		if (pending_microscenario_apply.get("route","") == "native_default"
			and int(tower_context.get("scenario_request_serial",0)) == int(pending_microscenario_apply.serial)
			and tower_context.get("scenario_request_applied",false)
			and tower_context.get("native_default_demo",{}).get("prepared",false)):
			_prepared_liquid_default_installed()
			pending_microscenario_apply.clear()
		elif (pending_microscenario_apply.get("route","") == "water" and tower_context.get("water_active",false)
			and int(tower_context.get("scenario_request_serial",0)) == int(pending_microscenario_apply.serial)
			and bool(tower_context.get("scenario_request_applied",false))
			and str(tower_context.get("microscenario",{}).get("definition_hash","")) == str(pending_microscenario_apply.hash)):
			_prepared_liquid_water_installed()
			if tower_context.get("microscenario",{}).get("failed",false):
				microscenario_error = "Installed session apparatus failed: " + str(tower_context.microscenario.get("error","unavailable"))
			pending_microscenario_apply.clear()
		elif (pending_microscenario_apply.get("route","") == "tower" and not tower_context.get("micro_active",false)
			and int(tower_context.get("scenario_request_serial",0)) == int(pending_microscenario_apply.serial)
			and bool(tower_context.get("scenario_request_applied",false))
			and str(tower_context.get("microscenario",{}).get("definition_hash","")) == str(pending_microscenario_apply.hash)):
			_prepared_liquid_tower_installed()
			if tower_context.get("microscenario",{}).get("failed",false):
				microscenario_error = "Installed session apparatus failed: " + str(tower_context.microscenario.get("error","unavailable"))
			pending_microscenario_apply.clear()
		elif (tower_context.get("micro_active", false)
			and int(tower_context.get("scenario_request_serial", 0)) == int(pending_microscenario_apply.serial)
			and bool(tower_context.get("scenario_request_applied", false))
			and str(tower_context.get("microscenario", {}).get("definition_hash", "")) == str(pending_microscenario_apply.hash)):
			_microscenario_installed(pending_microscenario_apply.definition)
			if tower_context.get("microscenario", {}).get("failed", false):
				microscenario_error = "Installed session apparatus failed: " + str(tower_context.microscenario.get("error", "unavailable"))
			pending_microscenario_apply.clear()
		elif (int(tower_context.get("scenario_request_serial", 0)) == int(pending_microscenario_apply.serial)
			and not bool(tower_context.get("scenario_request_applied", true))):
			if pending_microscenario_apply.get("profile_request",false): pending_player_environment_profile = {}
			paused = bool(pending_microscenario_apply.previous_paused)
			microscenario_mode = str(pending_microscenario_apply.get("previous_mode", microscenario_mode))
			microscenario_error = str(tower_context.status)
			_close_pending_physical_candidate()
			pending_microscenario_apply.clear()
	var capture_serial: int = int(tower_context.get("micro_capture_serial", 0))
	if capture_serial > microscenario_capture_seen and not tower_context.get("micro_capture", {}).is_empty():
		microscenario_capture_seen = capture_serial
		_write_microscenario_capture(tower_context.micro_capture)
	_reconcile_water_exit(tower_context)
	if not pending_water_apply.is_empty():
		if tower_context.get("water_active",false) and str(
			tower_context.get("water_policy_hash",""))==str(pending_water_apply.hash):
			var applied: Dictionary=pending_water_apply
			var recipe: Dictionary=applied.recipe
			water_policy_resolved=applied.result.duplicate(true)
			_liquid_water_active = false
			water_policy_available=true
			water_active_blind_label=str(applied.blind_label)
			tower_active=true
			current_view_size=Vector2i(480,270)
			camera_follow_enabled=false
			camera_origin=Vector2(recipe.camera_origin)
			character_position=Vector2(recipe.player_start)
			$Layout/Title.text="CYBERSAND / EXPERIMENT TOWER / WATER FEEL"
			_activate_water_body_scenario(bool(recipe.body_enabled))
			pending_water_apply.clear()
		elif ("rejected" in str(tower_context.get("status","")).to_lower()
			or "requires" in str(tower_context.get("status","")).to_lower()):
			paused=bool(pending_water_apply.get("previous_paused",true))
			pending_water_apply.clear()
	if tower_context.has("profile"): tower_profile = tower_context.profile
	var published_player_profile: Dictionary = tower_context.get(
		"player_environment_profile",
		{}
	)
	if not published_player_profile.is_empty():
		active_player_environment_profile = published_player_profile.duplicate(true)
		if (
			not pending_player_environment_profile.is_empty()
			and str(pending_player_environment_profile.get("hash", ""))
				== str(active_player_environment_profile.get("hash", ""))
		):
			pending_player_environment_profile.clear()
		if player_environment_panel != null:
			player_environment_panel.set_active(active_player_environment_profile)
	consumed_snapshot_serial = snapshot.serial
	if snapshot.simulation_failed:
		paused = true
	if not player_uses_barrel():
		character_position = snapshot.character_position
	if snapshot.render_snapshot_serial > last_uploaded_render_snapshot_serial:
		record_render_payload(snapshot)
		var render_uploaded: bool = upload_texture_patches(
			snapshot.render_patch_rectangles,
			snapshot.render_patch_cells,
			snapshot.world_revision,
			snapshot.render_channels
		)
		if render_uploaded:
			# Only an accepted World replacement invalidates presentation history.
			# Full refreshes also occur during resync and every fallback frame.
			if snapshot.render_world_generation != last_uploaded_world_generation:
				reset_vapour_trail()
			last_uploaded_world_generation = snapshot.render_world_generation
			last_uploaded_render_snapshot_serial = snapshot.render_snapshot_serial
			simulation_worker.acknowledge_render_snapshot(
				snapshot.render_snapshot_serial
			)
		else:
			reject_render_snapshot(snapshot)
	gameplay_recorder.ingest_snapshot(snapshot)


func record_render_payload(snapshot: CyberSimulationSnapshot) -> void:
	var publication_usec: int = Time.get_ticks_usec()
	if last_render_publication_usec >= 0 and publication_usec > last_render_publication_usec:
		var instantaneous_hz: float = 1000000.0 / float(
			publication_usec - last_render_publication_usec
		)
		measured_render_publication_hz = (
			instantaneous_hz
			if measured_render_publication_hz <= 0.0
			else lerpf(measured_render_publication_hz, instantaneous_hz, 0.2)
		)
	last_render_publication_usec = publication_usec
	last_render_patch_count = snapshot.render_patch_rectangles.size() / 6
	last_render_patch_bytes = snapshot.render_patch_cells.size()
	last_render_was_full_refresh = snapshot.render_full_refresh


func sync_hard_surface_colliders() -> void:
	if (
		latest_snapshot == null
		or not rapier_bridge.is_initialized()
		or latest_snapshot.hard_surface_revision == last_hard_surface_revision
	):
		return
	if physical_actor_session != null and not _physical_terrain_ready \
		and (latest_snapshot.rigid_body_epoch != _physical_epoch or _actor_reset_receipt != 0
			or not pending_microscenario_apply.is_empty()):
		return
	if latest_snapshot.hard_surface_chunk_rectangles_valid:
		if not rapier_bridge.queue_hard_surface_chunk_snapshot(
			latest_snapshot.hard_surface_chunk_rectangles
		):
			microscenario_error = "Terrain collider snapshot was refused"
			return
	elif latest_snapshot.hard_surface_rectangles_valid:
		rapier_bridge.rebuild_hard_surface_colliders_from_rectangles_chunked(
			latest_snapshot.hard_surface_rectangles,
			CyberCellWorld.WORLD_WIDTH,
			CyberCellWorld.WORLD_HEIGHT
		)
	else:
		rapier_bridge.rebuild_hard_surface_colliders(
			latest_snapshot.cells,
			CyberCellWorld.WORLD_WIDTH,
			CyberCellWorld.WORLD_HEIGHT
		)
	last_hard_surface_revision = latest_snapshot.hard_surface_revision
	hard_surface_rebuild_cooldown = HARD_SURFACE_REBUILD_INTERVAL


func _update_physical_terrain_ready() -> void:
	# New actors wait for their own native reset/pose acknowledgement and the
	# complete initial terrain install. Subsequent edits keep the ordinary
	# budgeted refresh path; this fence prevents an early unpause falling through
	# colliders that have not been installed yet.
	if physical_actor_session == null or _physical_terrain_ready or latest_snapshot == null:
		return
	_physical_terrain_ready = (_actor_reset_receipt == 0 and pending_microscenario_apply.is_empty()
		and latest_snapshot.rigid_body_epoch == _physical_epoch
		and last_hard_surface_revision >= 0
		and last_hard_surface_revision == latest_snapshot.hard_surface_revision
		and rapier_bridge.is_initialized() and rapier_bridge.pending_hard_surface_chunks() == 0)


func get_horizontal_input() -> float:
	if _blacksite_keyboard_blocked(): return 0.0
	var move_left: float = 1.0 if Input.is_key_pressed(KEY_A) else 0.0
	var move_right: float = 1.0 if Input.is_key_pressed(KEY_D) else 0.0
	return move_right - move_left


func _blacksite_keyboard_blocked() -> bool:
	return blacksite_nine_presentation != null and blacksite_nine_presentation.keyboard_blocked()


func setup_actor_prototypes() -> void:
	actor_prototype_button = Button.new()
	actor_prototype_button.name = "ActorPrototypes"
	actor_prototype_button.text = "Sampled baseline / actors / F5"
	actor_prototype_button.focus_mode = Control.FOCUS_NONE
	actor_prototype_button.pressed.connect(toggle_actor_prototypes)
	$Layout.add_child(actor_prototype_button)
	actor_prototype_panel = ActorPrototypePanel.new()
	actor_prototype_panel.name = "ActorPrototypePanel"
	add_child(actor_prototype_panel)
	actor_prototype_panel.apply_requested.connect(apply_actor_prototype_configuration)
	actor_prototype_panel.equipment_requested.connect(apply_actor_equipment_configuration)
	actor_prototype_overlay = ActorPrototypeOverlay.new()
	actor_prototype_overlay.name = "ActorPrototypeOverlay"
	actor_prototype_overlay.clip_contents = true
	$Layout/World.add_child(actor_prototype_overlay)
	usable_overlay = UsableOverlay.new()
	usable_overlay.name = "UsableOverlay"
	usable_overlay.clip_contents = true
	$Layout/World.add_child(usable_overlay)
	physical_actor_overlay = PhysicalOverlay.new()
	physical_actor_overlay.name = "PhysicalActorOverlay"
	$Layout/World.add_child(physical_actor_overlay)


func actor_prototypes_allowed() -> bool:
	var exploratory: bool = (tower_context.get("micro_active", false)
		and CyberMicroScenarioCatalogue.exploratory_actor_map(microscenario_definition)
		and microscenario_mode != "Benchmark")
	return ((exploratory or (not tower_active and not tower_context.get("micro_active", false)))
		and not water_controlled_run_active() and not _liquid_default_active
		and pending_microscenario_apply.is_empty() and pending_water_apply.is_empty())


func toggle_actor_prototypes() -> void:
	if not actor_prototypes_allowed():
		return
	if actor_prototype_panel.visible:
		actor_prototype_panel.hide()
		return
	_actor_input_rearm = true
	var selected_model: StringName = StringName("physical/" + physical_trial_arm) if not physical_trial_arm.is_empty() else actor_model_selection
	if physical_rig_id != &"": selected_model = StringName("rapier/" + str(physical_rig_id))
	actor_prototype_panel.configure_selection(selected_model, actor_producer_selection, actor_demo_npcs)
	actor_prototype_panel.set_context(str(microscenario_definition.get("id", "Sandbox")) if tower_context.get("micro_active", false) else "Sandbox")
	actor_prototype_panel.effort_slider.value = _actor_effort
	actor_prototype_panel.configure_equipment(actor_usable_index, _actor_usable_power, physical_actor_session != null)
	actor_prototype_panel.show_selection()


func actor_prototype_definitions(model_id: StringName, producer: StringName, demo_npcs: bool, spawn: Vector2 = CHARACTER_SPAWN) -> Array:
	if model_id == &"":
		return []
	var definitions: Array = [{"model": model_id, "producer": producer, "position": spawn}]
	if demo_npcs:
		for candidate: StringName in ActorRigCatalog.rigs_in_set(ActorRigCatalog.set_for(model_id)):
			if candidate != model_id:
				definitions.append({"model": candidate, "producer": &"demo",
					"position": spawn + Vector2(float(definitions.size()) * 22.0, -4.0)})
	return definitions


func physical_actor_definitions(model_id: StringName, producer: StringName, demo_npcs: bool, spawn: Vector2) -> Array:
	if not PhysicalCatalog.has_rig(model_id):
		return []
	var models: Array[StringName] = [model_id]
	if demo_npcs:
		for candidate: StringName in PhysicalCatalog.rigs_in_set(PhysicalCatalog.set_for(model_id)):
			if candidate != model_id and models.size() < PhysicalSession.MAX_ACTORS:
				models.append(candidate)
	var definitions: Array = []
	var next_x: float = spawn.x + CyberSampledCharacter.BODY_SIZE.x * 0.5
	for index: int in range(models.size()):
		var data: Dictionary = PhysicalEquipment.definition(PhysicalCatalog.entry(models[index]))
		var bounds: Rect2 = data.bounds
		# Align the lowest part above the authored player's feet. Neighbours are
		# spaced by their complete assembly widths, including the usable mount.
		if index > 0:
			next_x += -bounds.position.x + 8.0
		var origin := Vector2(next_x, spawn.y + CyberSampledCharacter.BODY_SIZE.y - float(data.spawn_floor_clearance))
		origin.x = clampf(origin.x, -bounds.position.x + 2.0, 1022.0 - bounds.end.x)
		origin.y = clampf(origin.y, -bounds.position.y + 2.0, 1022.0 - bounds.end.y)
		definitions.append({"model": models[index], "producer": producer if index == 0 else &"demo", "position": origin})
		next_x = origin.x + bounds.end.x
	return definitions


func _close_pending_physical_candidate() -> void:
	if _pending_physical_candidate != null: _pending_physical_candidate.close()
	_pending_physical_candidate = null
	_prepared_physical_identity = {};_prepared_physical_ready_sent = false

func _advance_prepared_physical_candidate() -> void:
	if _pending_physical_candidate == null or _prepared_physical_ready_sent: return
	var publication: Dictionary = simulation_worker.prepared_physical_liquid_values()
	if publication.is_empty(): return
	if int(publication.get("serial",0)) != int(pending_microscenario_apply.get("serial",-1)) \
		or int(publication.get("instance_id",0)) != _pending_physical_candidate.get_instance_id(): return
	if _prepared_physical_identity.is_empty():
		_prepared_physical_identity = publication.duplicate(true)
		if publication.initial_bodies != _pending_physical_candidate.initial_body_states() \
			or not _pending_physical_candidate.install_terrain(publication.terrain):
			simulation_worker.complete_prepared_physical_liquid(_prepared_physical_identity,false,
				"initial body identity or terrain refused")
			_prepared_physical_ready_sent = true
			return
	if not _pending_physical_candidate.verify_physics_frame() \
		or not _pending_physical_candidate.prepare_terrain_budget(HARD_SURFACE_CHUNKS_PER_FRAME,HARD_SURFACE_FRAME_BUDGET_USEC):
		simulation_worker.complete_prepared_physical_liquid(_prepared_physical_identity,false,
			_pending_physical_candidate.last_error)
		_prepared_physical_ready_sent = true
		return
	if _pending_physical_candidate.ready():
		_prepared_physical_ready_sent = simulation_worker.complete_prepared_physical_liquid(
			_prepared_physical_identity,true)

func _adopt_prepared_physical_candidate() -> void:
	# Every declared fallible operation completed before main sent readiness.
	# Retire the old owner only after native and worker state accepted this graph.
	var accepted: RefCounted = _pending_physical_candidate
	_pending_physical_candidate = null
	_close_physical_actors()
	_close_prepared_reference_bodies()
	for body: RigidBody2D in [test_rigid_body_1,test_rigid_body_2,test_rigid_body_3]:
		body.freeze = true;body.collision_layer = 0;body.collision_mask = 0
	rapier_bridge.shutdown()
	if accepted.owner_kind() == "reference_body":
		_accepted_reference_candidate = accepted
		rapier_bridge = accepted.physics_bridge()
		rigid_bodies = accepted.bodies()
		_physical_terrain_ready = true
		rapier_start_error = OK
		last_hard_surface_revision = latest_snapshot.hard_surface_revision
		hard_surface_rebuild_cooldown = 0.0
		accepted.adopt()
		_prepared_physical_identity = {};_prepared_physical_ready_sent = false
		return
	_accepted_physical_candidate = accepted
	physical_actor_session = accepted.session
	_physical_epoch = physical_actor_session.epoch
	rapier_bridge = physical_actor_session.bridge
	rigid_bodies = physical_actor_session.bodies()
	_physical_terrain_ready = true
	rapier_start_error = OK
	last_hard_surface_revision = latest_snapshot.hard_surface_revision
	hard_surface_rebuild_cooldown = 0.0
	var loadout: Dictionary = PhysicalLoadouts.entry(physical_rig_id)
	actor_usable_index = int(loadout.get("usable_index",-1))
	_actor_usable_requested_index = actor_usable_index
	_actor_usable_power = float(loadout.get("power",0.8))
	_actor_usable_transition_pending = false;_actor_usable_pointer_rearm = true
	simulation_worker.set_physical_actor_epoch(_physical_epoch)
	accepted.adopt()
	_prepared_physical_identity = {};_prepared_physical_ready_sent = false

func _close_prepared_reference_bodies() -> void:
	if _accepted_reference_candidate == null: return
	_accepted_reference_candidate.close()
	_accepted_reference_candidate = null
	rigid_bodies.clear()
	last_hard_surface_revision = -1

func _activate_articulated_actor_rigs(spawn: Vector2) -> bool:
	var definitions: Array = physical_actor_definitions(physical_rig_id,
		actor_producer_selection, actor_demo_npcs, spawn)
	if not PhysicalSession.valid_definitions(definitions):
		microscenario_error = "Physical actor configuration exceeds its bounded assembly budget"
		return false
	_activate_water_body_scenario(false)
	_physical_epoch += 1
	_physical_terrain_ready = false
	physical_actor_session = PhysicalSession.new()
	physical_actor_session.name = "PhysicalActorSession"
	physical_actor_session.visible = false
	add_child(physical_actor_session)
	if not physical_actor_session.configure(definitions, get_viewport().world_2d.space, _physical_epoch):
		microscenario_error = physical_actor_session.last_error
		_close_physical_actors()
		return false
	physical_actor_session.input_cancelled.connect(_on_physical_actor_input_cancelled)
	physical_actor_session.set_suspended(true)
	var loadout: Dictionary = PhysicalLoadouts.entry(physical_rig_id)
	actor_usable_index = int(loadout.get("usable_index", -1))
	_actor_usable_requested_index = actor_usable_index
	_actor_usable_power = float(loadout.get("power", 0.8))
	_actor_usable_transition_pending = false
	_actor_usable_pointer_rearm = true
	rapier_bridge = physical_actor_session.bridge
	rigid_bodies = physical_actor_session.bodies()
	rapier_start_error = OK
	last_hard_surface_revision = -1
	hard_surface_rebuild_cooldown = 0.0
	simulation_worker.set_physical_actor_epoch(_physical_epoch)
	_publish_physical_body_state()
	return true


func _close_physical_actors() -> void:
	_physical_terrain_ready = false
	if physical_actor_session == null:
		return
	simulation_worker.set_physical_actor_epoch(0)
	if _accepted_physical_candidate != null:
		_accepted_physical_candidate.close()
		_accepted_physical_candidate = null
	else:
		physical_actor_session.close()
		physical_actor_session.free()
	physical_actor_session = null
	rigid_bodies.clear()
	rapier_bridge = CyberRapierPhysicsBridge.new()
	last_hard_surface_revision = -1
	if physical_actor_overlay != null:
		physical_actor_overlay.present([], Vector2.ZERO, current_view_size, view_content_rect())


func _publish_physical_body_state() -> void:
	var effects: Array = physical_actor_session.drain_effects() if physical_actor_session != null else []
	var states: PackedFloat32Array = pack_rigid_body_states()
	if physical_actor_session != null:
		var requests: Array = physical_actor_session.drain_equipment_requests()
		var admission: Dictionary = simulation_worker.set_physical_usable_state(
			physical_actor_session.equipment_frame(), requests, states)
		if str(admission.get("status", "")) == "refused":
			physical_actor_session.reject_equipment_requests(requests, str(admission.get("reason", "admission")))
	simulation_worker.set_rigid_body_states(states,
		_physical_epoch if physical_actor_session != null else 0, effects)


func physical_actor_observation(actor_id: int = 0) -> Dictionary:
	return physical_actor_session.observation(actor_id) if physical_actor_session != null else {}


func submit_physical_actor_command(command: Dictionary) -> bool:
	return (physical_actor_session != null and actor_prototypes_allowed()
		and not paused and _physical_terrain_ready and _actor_reset_receipt == 0
		and physical_actor_session.submit(command, &"policy"))


func cancel_physical_actor_command(actor_id: int = 0) -> bool:
	return physical_actor_session != null and physical_actor_session.cancel_input(
		actor_id, _physical_epoch, &"policy")


func _on_physical_actor_input_cancelled(actor_id: int, actor_epoch: int) -> void:
	simulation_worker.cancel_physical_actor_effects(actor_epoch, actor_id)


func _publish_physical_keyboard_input(trigger_override: Variant = null, alternate_override: Variant = null) -> void:
	if actor_producer_selection != &"human":
		return
	if not _actor_usable_input_allowed() or _actor_reset_receipt != 0 or simulation_worker.has_failed():
		_actor_input_rearm = true
		_actor_usable_pointer_rearm = true
		physical_actor_session.cancel_input(0, _physical_epoch, &"human")
		return
	if _actor_input_rearm:
		for key: int in ACTOR_CONTROL_KEYS + PHYSICAL_TOOL_KEYS:
			if Input.is_key_pressed(key):
				return
		_actor_input_rearm = false
	var trigger: bool = bool(trigger_override) if trigger_override is bool else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var alternate: bool = bool(alternate_override) if alternate_override is bool else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var pointer_inside: bool = view_content_rect().has_point(world_view.get_local_mouse_position())
	trigger = trigger and pointer_inside
	alternate = alternate and pointer_inside
	trigger = trigger or Input.is_key_pressed(KEY_M)
	if _actor_usable_pointer_rearm:
		if trigger or alternate:
			trigger = false
			alternate = false
		else:
			_actor_usable_pointer_rearm = false
	var action: Dictionary = {
		"move": Vector2(get_horizontal_input(), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))),
		"aim": actor_pointer_aim(), "effort": _actor_effort,
		"trim": float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q)),
		"reel": float(Input.is_key_pressed(KEY_X)) - float(Input.is_key_pressed(KEY_Z)),
		"primary": Input.is_key_pressed(KEY_SPACE), "secondary": Input.is_key_pressed(KEY_SHIFT),
		"auxiliary": Input.is_key_pressed(KEY_C),
		"equipment": {"usable_index": _actor_usable_requested_index if _actor_usable_transition_pending else actor_usable_index,
			"aim": actor_pointer_aim(), "power": _actor_usable_power,
			"trigger": trigger and not _actor_usable_transition_pending,
			"alternate": alternate and not _actor_usable_transition_pending,
			"drop": Input.is_key_pressed(KEY_N), "attach": Input.is_key_pressed(KEY_U)},
	}
	if physical_actor_session.is_flight_actor(0):
		# The reserved 4LY interpretation has exactly two velocity outputs.
		action = {"move": action.move}
	physical_actor_session.submit_local(0, action, &"human", 6)


func apply_actor_prototype_configuration(model_id: StringName, producer: StringName, demo_npcs: bool) -> bool:
	if not actor_prototypes_allowed():
		actor_prototype_panel.set_error("Actor changes are available in exploratory maps and the sandbox; controlled scenarios are protected.")
		return false
	var trial: bool = model_id in [&"physical/barrel", &"physical/ripper"]
	var articulated: bool = str(model_id).begins_with("rapier/")
	var bare_id := StringName(str(model_id).trim_prefix("rapier/")) if articulated else &""
	if articulated and not PhysicalCatalog.has_rig(bare_id): return false
	var physical: bool = trial or articulated
	if not physical and model_id != &"" and not ActorRigCatalog.has_rig(model_id): return false
	if not CyberActorPrototypeSession.PRODUCERS.has(producer): return false
	var spawn: Vector2 = CHARACTER_SPAWN
	if tower_context.get("micro_active", false):
		spawn = Vector2(microscenario_definition.player_start[0], microscenario_definition.player_start[1])
	var definitions: Array = [] if physical else actor_prototype_definitions(model_id, producer, demo_npcs, spawn)
	if articulated and not PhysicalSession.valid_definitions(physical_actor_definitions(bare_id, producer, demo_npcs, spawn)):
		return false
	var arm: String = str(model_id).trim_prefix("physical/") if trial else ""
	var configuration: Dictionary = {
		"representation":"barrel-rapier" if physical else "sampled",
		"runtime_recovery_enabled":not physical and model_id == &"",
		"experimental":true, "physical_trial":arm,
		"physical_rig":str(bare_id),
		"actor_model":"" if physical else str(model_id),
		"actor_producer":"human" if trial else str(producer),
		"actor_demo_npcs":demo_npcs and not trial,
		"actor_definitions":definitions,
	}
	if tower_context.get("micro_active", false):
		_actor_effort = actor_prototype_panel.effort_slider.value
		return _apply_microscenario_definition(microscenario_definition, microscenario_mode, configuration)
	var receipt: int = simulation_worker.queue_actor_prototype_reset(definitions, spawn, not physical)
	if receipt == 0:
		actor_prototype_panel.set_error("A scenario reset is pending; finish that transition first.")
		return false
	_actor_reset_receipt = receipt
	paused = true
	actor_model_selection = &"" if physical else model_id
	actor_producer_selection = &"human" if trial else producer
	actor_demo_npcs = demo_npcs and not trial
	_actor_effort = actor_prototype_panel.effort_slider.value
	_actor_input_rearm = true
	physical_trial_arm = arm
	physical_rig_id = bare_id
	physical_trial_input = PhysicalTrial.new()
	player_representation = CyberPlayerRepresentation.BARREL_RAPIER if physical else CyberPlayerRepresentation.SAMPLED
	sampled_runtime_recovery_enabled = not physical and model_id == &""
	if articulated:
		if not _activate_articulated_actor_rigs(spawn):
			actor_prototype_panel.set_error(microscenario_error)
			return false
	elif physical:
		_activate_microscenario_barrel_player(spawn)
	else:
		_activate_water_body_scenario(false)
		_activate_water_body_scenario(true)
		reset_test_rigid_bodies()
		_publish_physical_body_state()
	character_position = spawn
	camera_follow_enabled = true
	camera_origin = clamped_camera_origin(character_centre() - Vector2(current_view_size) * 0.5)
	actor_prototype_panel.hide()
	return true


func apply_actor_equipment_configuration(usable_index: int, power: float) -> bool:
	if physical_actor_session != null:
		if physical_actor_session.is_flight_actor(0):
			actor_prototype_panel.set_error("4LY drones have an explicitly empty loadout; select a different actor to equip tools.")
			return false
		if actor_producer_selection != &"human" or paused or simulation_worker.has_failed() \
			or not _physical_terrain_ready or _actor_reset_receipt != 0:
			actor_prototype_panel.set_error("Equip-only requires an active, unpaused human actor.")
			return false
		if usable_index < -1 or usable_index >= UsableCatalog.count() or not is_finite(power):
			actor_prototype_panel.set_error("Unknown equipment or invalid power.")
			return false
		var physical_view: Dictionary = physical_actor_session.observation(0)
		var equipment: Dictionary = physical_view.get("equipment", {})
		if not bool(equipment.get("attached", false)) or bool(equipment.get("pending", false)):
			actor_prototype_panel.set_error("Recover the released device and finish its pending use before switching equipment.")
			return false
		if not physical_actor_session.submit_local(0, {"equipment": {
			"usable_index": usable_index, "power": clampf(power, 0.0, 1.0),
			"trigger": false, "alternate": false}}, &"human", 6):
			actor_prototype_panel.set_error("Equipment request refused: " + physical_actor_session.last_error)
			return false
		_actor_usable_requested_index = usable_index
		_actor_usable_power = clampf(power, 0.0, 1.0)
		_actor_usable_transition_pending = true
		_actor_usable_pointer_rearm = true
		actor_prototype_panel.hide()
		return true
	if (
		latest_snapshot == null or latest_snapshot.actor_prototypes.is_empty()
		or latest_snapshot.actor_prototypes.producers[0] != &"human"
		or paused or simulation_worker.has_failed() or _actor_reset_receipt != 0
	):
		actor_prototype_panel.set_error("Equip-only requires an active, unpaused human sampled actor.")
		return false
	if usable_index < -1 or usable_index >= UsableCatalog.count():
		actor_prototype_panel.set_error("Unknown equipment selection.")
		return false
	var context: Dictionary = latest_snapshot.actor_prototypes
	var epoch: int = int(context.epoch)
	if epoch != _actor_usable_input_epoch:
		_actor_usable_input_epoch = epoch
		_actor_usable_input_sequence = 0
	_actor_usable_input_sequence += 1
	var accepted: bool = simulation_worker.submit_actor_usable_action(
		0, epoch, _actor_usable_input_sequence, int(context.tick),
		usable_index, actor_pointer_aim(), clampf(power, 0.0, 1.0),
		false, false, 6, &"human"
	)
	if not accepted:
		actor_prototype_panel.set_error("Equipment command was stale or refused by the simulation owner.")
		return false
	_actor_usable_requested_index = usable_index
	_actor_usable_power = clampf(power, 0.0, 1.0)
	_actor_usable_transition_pending = true
	_actor_usable_input_rearm = true
	_actor_usable_pointer_rearm = true
	actor_prototype_panel.hide()
	return true


func actor_equipment_active() -> bool:
	if physical_actor_session != null:
		var view: Dictionary = physical_actor_session.observation(0)
		return int(view.get("equipment", {}).get("usable_index", -1)) >= 0
	if latest_snapshot == null or latest_snapshot.actor_usables.is_empty():
		return false
	var equipped: PackedInt32Array = latest_snapshot.actor_usables.get("equipped", PackedInt32Array())
	return not equipped.is_empty() and equipped[0] >= 0


func refresh_actor_usables() -> void:
	if physical_actor_session != null:
		if latest_snapshot != null:
			physical_actor_session.accept_equipment_feedback(latest_snapshot.physical_usables)
		var equipment: Dictionary = physical_actor_session.observation(0).get("equipment", {})
		actor_usable_index = int(equipment.get("usable_index", -1))
		if _actor_usable_transition_pending and actor_usable_index == _actor_usable_requested_index:
			_actor_usable_transition_pending = false
			_actor_usable_pointer_rearm = true
		return
	if latest_snapshot == null or latest_snapshot.actor_usables.is_empty():
		actor_usable_index = -1
		_actor_usable_transition_pending = false
		return
	var equipped: PackedInt32Array = latest_snapshot.actor_usables.get("equipped", PackedInt32Array())
	if equipped.is_empty():
		return
	actor_usable_index = int(equipped[0])
	if _actor_usable_transition_pending and actor_usable_index == _actor_usable_requested_index:
		_actor_usable_transition_pending = false
		_actor_usable_pointer_rearm = true


func _actor_usable_input_allowed() -> bool:
	if not actor_keyboard_allowed():
		return false
	if showcase_presentation != null and showcase_presentation.input_blocked():
		return false
	if blacksite_nine_presentation != null and blacksite_nine_presentation.input_blocked():
		return false
	return true


func _publish_actor_usable_buttons(trigger: bool, alternate: bool) -> void:
	if physical_actor_session != null:
		_publish_physical_keyboard_input(trigger, alternate)
		return
	if latest_snapshot == null or latest_snapshot.actor_prototypes.is_empty():
		return
	var context: Dictionary = latest_snapshot.actor_prototypes
	if context.producers[0] != &"human":
		return
	var epoch: int = int(context.epoch)
	if epoch != _actor_usable_input_epoch:
		_actor_usable_input_epoch = epoch
		_actor_usable_input_sequence = 0
		_actor_usable_input_rearm = true
		_actor_usable_pointer_rearm = true
	if _actor_usable_transition_pending:
		return
	if (
		not _actor_usable_input_allowed() or context.get("suspended", false)
		or _actor_reset_receipt != 0 or simulation_worker.has_failed()
	):
		_actor_usable_input_rearm = true
		simulation_worker.cancel_actor_usable_input(0, epoch, &"human")
		return
	if actor_usable_index < 0:
		return
	if _actor_usable_pointer_rearm:
		if trigger or alternate:
			return
		_actor_usable_pointer_rearm = false
	_actor_usable_input_sequence += 1
	simulation_worker.submit_actor_usable_action(
		0, epoch, _actor_usable_input_sequence, int(context.tick),
		actor_usable_index, actor_pointer_aim(), _actor_usable_power,
		trigger, alternate, 6, &"human"
	)


func publish_actor_usable_input() -> void:
	# Physical keyboard publication already includes equipment. The event path
	# above still captures a complete press/release between physics frames.
	if physical_actor_session != null:
		return
	_publish_actor_usable_buttons(
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)


func _reconcile_actor_prototype_reset() -> void:
	if _actor_reset_receipt == 0 or latest_snapshot.actor_prototype_reset_serial < _actor_reset_receipt:
		return
	_actor_reset_receipt = 0
	if latest_snapshot.actor_prototype_reset_applied:
		last_hard_surface_revision = -1
		hard_surface_rebuild_cooldown = 0.0
		return
	# The owner may have accepted a scenario after the last displayed snapshot.
	# Reconcile a refused request with actual actor identity, never UI optimism.
	var context: Dictionary = latest_snapshot.actor_prototypes
	if physical_actor_session != null:
		_close_physical_actors()
		physical_rig_id = &""
		player_representation = CyberPlayerRepresentation.SAMPLED if latest_snapshot.player_body_id == 0 else CyberPlayerRepresentation.BARREL_RAPIER
		_activate_water_body_scenario(true)
	actor_model_selection = &"" if context.is_empty() else StringName(str(context.models[0]))
	if not context.is_empty():
		actor_producer_selection = StringName(str(context.producers[0]))
		sampled_runtime_recovery_enabled = false
	else:
		sampled_runtime_recovery_enabled = latest_snapshot.character_runtime_recovery_enabled
	_actor_input_rearm = true
	if actor_prototype_panel != null:
		actor_prototype_panel.set_error(latest_snapshot.actor_prototype_status)
	if actor_prototype_button != null:
		actor_prototype_button.tooltip_text = latest_snapshot.actor_prototype_status


func actor_keyboard_allowed() -> bool:
	if paused or not get_window().has_focus() or not actor_prototypes_allowed():
		return false
	if physical_actor_session != null and not _physical_terrain_ready:
		return false
	if actor_prototype_panel.visible or player_environment_panel.visible:
		return false
	if tower_profile_panel != null and tower_profile_panel.visible:
		return false
	if microscenario_panel != null and microscenario_panel.modal_open():
		return false
	var focus: Control = get_viewport().gui_get_focus_owner()
	return focus == null


func actor_human_control_active() -> bool:
	if physical_actor_session != null:
		return actor_producer_selection == &"human"
	return (
		latest_snapshot != null and not latest_snapshot.actor_prototypes.is_empty()
		and latest_snapshot.actor_prototypes.producers[0] == &"human"
	)


func actor_pointer_aim() -> Vector2:
	return actor_pointer_aim_at(world_view.get_local_mouse_position())


func actor_pointer_aim_at(pointer: Vector2) -> Vector2:
	# Read only displayed actor/camera state, using the terrain's aspect-fit map.
	var content: Rect2 = view_content_rect()
	if not pointer.is_finite() or content.size.x <= 0.0 or content.size.y <= 0.0 or not content.has_point(pointer):
		return Vector2.ZERO
	var world_point: Vector2 = camera_origin.floor() + (pointer - content.position) / content.size * Vector2(current_view_size)
	return (world_point - character_centre()).normalized()


func publish_actor_keyboard_input() -> void:
	if physical_actor_session != null:
		_publish_physical_keyboard_input()
		return
	if latest_snapshot == null or latest_snapshot.actor_prototypes.is_empty():
		return
	var context: Dictionary = latest_snapshot.actor_prototypes
	if context.producers[0] != &"human":
		return
	var epoch: int = int(context.epoch)
	if epoch != _actor_input_epoch:
		_actor_input_epoch = epoch
		_actor_input_sequence = 0
		_actor_input_rearm = true
	var movement: Vector2 = Vector2(get_horizontal_input(),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var primary: bool = Input.is_key_pressed(KEY_SPACE)
	var secondary: bool = Input.is_key_pressed(KEY_SHIFT)
	var auxiliary: bool = Input.is_key_pressed(KEY_C)
	var trim: float = float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	var reel: float = float(Input.is_key_pressed(KEY_X)) - float(Input.is_key_pressed(KEY_Z))
	if (
		not actor_keyboard_allowed() or context.get("suspended", false)
		or _actor_reset_receipt != 0 or simulation_worker.has_failed()
	):
		_actor_input_rearm = true
		simulation_worker.cancel_actor_input(0, epoch, &"human")
		return
	if _actor_input_rearm:
		for key: int in ACTOR_CONTROL_KEYS:
			if Input.is_key_pressed(key):
				return
		_actor_input_rearm = false
	_actor_input_sequence += 1
	if int(context.get("rig_version", 1)) < 2 or CyberActorPrototypeSession.MODEL_IDS.has(StringName(str(context.models[0]))):
		# Keep the original Set A desktop adapter path and its public v1 seam.
		simulation_worker.submit_actor_action(0, epoch, _actor_input_sequence,
			int(context.tick), movement, primary, secondary, 6, &"human")
		return
	simulation_worker.submit_actor_rig_action(0, epoch, _actor_input_sequence,
		int(context.tick), movement, actor_pointer_aim(), _actor_effort, trim, reel,
		primary, secondary, auxiliary, 6, &"human")


func refresh_actor_prototypes() -> void:
	actor_prototype_button.disabled = not actor_prototypes_allowed()
	if physical_actor_session != null:
		var state: Dictionary = physical_actor_session.snapshot()
		var equipment: Dictionary = state.actors[0].get("equipment", {}) if not state.actors.is_empty() else {}
		actor_prototype_button.text = "Rapier %s / F5 | %s | %d actors / %d parts" % [
			PhysicalCatalog.name_for(physical_rig_id), str(actor_producer_selection), state.actor_count, state.body_count]
		if physical_actor_session.is_flight_actor(0) and not state.actors.is_empty():
			var flight: Dictionary = state.actors[0].flight
			actor_prototype_button.text += " | 4LY: %s" % str(flight.get("mode", "unknown"))
			actor_prototype_button.tooltip_text = PhysicalCatalog.controls_text(physical_rig_id) \
				+ "\nAssistance: %s | Command live: %s | Fallback: %s\nProfile hash: %s" % [
				str(flight.get("mode", "unknown")), str(flight.get("command_live", false)),
				str(flight.get("fallback_reason", "")), str(flight.get("capabilities", {}).get("profile_hash", ""))]
		else:
			actor_prototype_button.text += " | %s: %s" % [UsableCatalog.name_for(actor_usable_index), str(equipment.get("last_result", "ready"))]
			actor_prototype_button.tooltip_text = PhysicalCatalog.controls_text(physical_rig_id) + "\nLeft/M use · right alternate · N release · U nearby pickup. Equipment uses the physical mount."
		return
	if not physical_trial_arm.is_empty():
		actor_prototype_button.text = "Rapier %s / impulses + torque / F5" % physical_trial_arm
		return
	if latest_snapshot == null or latest_snapshot.actor_prototypes.is_empty():
		actor_prototype_button.text = "Sampled baseline / actors / F5"
		return
	var context: Dictionary = latest_snapshot.actor_prototypes
	var states: PackedFloat32Array = context.states
	var rig_id: StringName = StringName(str(context.models[0]))
	var power_text: String = ""
	if ActorRigCatalog.entry(rig_id).channels.has("effort"):
		var power: float = _actor_effort
		var applied: PackedFloat32Array = context.get("applied_actions", PackedFloat32Array())
		if context.producers[0] != &"human":
			power = applied[4] if applied.size() >= CyberActorPrototypeSession.ACTION_STRIDE else 0.0
		power_text = " | power %d%%" % roundi(power * 100.0)
	actor_prototype_button.text = "Sampled %s · %s / F5 | %s | energy %d%%%s | %d rigs" % [
		ActorRigCatalog.name_for(rig_id), str(ActorRigCatalog.set_for(rig_id)), str(context.producers[0]),
		roundi(states[6] * 100.0), power_text, int(context.count)]
	actor_prototype_button.tooltip_text = ActorRigCatalog.controls_text(rig_id) + "\nRelease control keys after UI/focus changes."


func update_camera(delta: float) -> void:
	if water_controlled_run_active(): return
	if _blacksite_keyboard_blocked(): return
	var pan_input: Vector2 = Vector2(
		(1.0 if Input.is_key_pressed(KEY_RIGHT) else 0.0) - (1.0 if Input.is_key_pressed(KEY_LEFT) else 0.0),
		(1.0 if Input.is_key_pressed(KEY_DOWN) else 0.0) - (1.0 if Input.is_key_pressed(KEY_UP) else 0.0)
	)

	if pan_input.length_squared() > 0.0:
		camera_follow_enabled = false
		camera_origin += pan_input.normalized() * CAMERA_PAN_SPEED * delta
	elif camera_follow_enabled:
		var desired: Vector2 = character_centre() - Vector2(current_view_size) * 0.5
		var follow_weight: float = 1.0 - exp(-CAMERA_FOLLOW_RATE * delta)
		camera_origin = camera_origin.lerp(desired, follow_weight)

	camera_origin = clamped_camera_origin(camera_origin)


func character_centre() -> Vector2:
	if (
		player_uses_barrel()
		and rapier_bridge.is_initialized()
		and rigid_bodies.size() > CyberPlayerRepresentation.BARREL_BODY_INDEX
	):
		return rapier_bridge.body_transform(
			CyberPlayerRepresentation.BARREL_BODY_INDEX
		).origin
	if latest_snapshot != null and not latest_snapshot.actor_prototypes.is_empty():
		var rig_states: PackedFloat32Array = latest_snapshot.actor_prototypes.get("rig_states", PackedFloat32Array())
		if rig_states.size() >= CyberActorPrototypeSession.RIG_OBSERVATION_STRIDE:
			return character_position + Vector2(rig_states[35], rig_states[36]) * 0.5
	return character_position + CyberSampledCharacter.BODY_SIZE * 0.5


func clamped_camera_origin(candidate: Vector2) -> Vector2:
	return Vector2(
		clampf(candidate.x, 0.0, float(CyberCellWorld.WORLD_WIDTH - current_view_size.x)),
		clampf(candidate.y, 0.0, float(CyberCellWorld.WORLD_HEIGHT - current_view_size.y))
	)


func update_worker_frame_state() -> void:
	var view_origin: Vector2i = Vector2i(floori(camera_origin.x), floori(camera_origin.y))
	var interest: Vector2i = view_origin + Vector2i(
		current_view_size.x >> 1,
		current_view_size.y >> 1
	)
	simulation_worker.set_frame_state(
		get_horizontal_input(),
		Input.is_key_pressed(KEY_SPACE) and not _blacksite_keyboard_blocked(),
		paused,
		interest,
		view_origin,
		current_view_size,
		simulation_margin.x,
		simulation_margin.y,
		simulation_window_enabled,
		cadence_lod_enabled,
		liquid_surface_adhesion_enabled
	)


func setup_brush_preview() -> void:
	brush_preview = Line2D.new()
	brush_preview.name = "BrushPreview"
	brush_preview.width = 1.5
	brush_preview.default_color = Color(0.95, 0.98, 1.0, 0.9)
	brush_preview.antialiased = false
	brush_preview.z_index = 64
	brush_preview.visible = false
	world_view.add_child(brush_preview)


func view_pixel_from_local_point(mouse: Vector2) -> Vector2i:
	var content_rect: Rect2 = view_content_rect()
	if content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		return Vector2i(-1, -1)
	if not content_rect.has_point(mouse):
		return Vector2i(-1, -1)
	var normalized_position: Vector2 = (mouse - content_rect.position) / content_rect.size
	var view_pixel: Vector2i = Vector2i(normalized_position * Vector2(current_view_size))
	if (
		view_pixel.x < 0
		or view_pixel.x >= current_view_size.x
		or view_pixel.y < 0
		or view_pixel.y >= current_view_size.y
	):
		return Vector2i(-1, -1)
	return view_pixel


func brush_outline_points(view_pixel: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	if view_pixel.x < 0 or view_pixel.y < 0:
		return points
	var content_rect: Rect2 = view_content_rect()
	if content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		return points
	var scale: Vector2 = content_rect.size / Vector2(current_view_size)
	var dimensions: Vector2i = brush_dimensions()
	var start: Vector2 = Vector2(
		view_pixel.x - int((dimensions.x - 1) / 2),
		view_pixel.y - int((dimensions.y - 1) / 2)
	)
	if brush_shape == "circle":
		var centre: Vector2 = (
			content_rect.position
			+ (start + Vector2(dimensions) * 0.5) * scale
		)
		var radii: Vector2 = Vector2(dimensions) * scale * 0.5
		for step: int in range(BRUSH_PREVIEW_SEGMENTS + 1):
			var angle: float = TAU * float(step) / float(BRUSH_PREVIEW_SEGMENTS)
			points.append(
				centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
			)
		return points
	var top_left: Vector2 = content_rect.position + start * scale
	var bottom_right: Vector2 = top_left + Vector2(dimensions) * scale
	points.append(top_left)
	points.append(Vector2(bottom_right.x, top_left.y))
	points.append(bottom_right)
	points.append(Vector2(top_left.x, bottom_right.y))
	points.append(top_left)
	return points


func update_brush_preview() -> void:
	if brush_preview == null:
		return
	if (
		(microscenario_panel != null and microscenario_panel.modal_open())
		or (tower_profile_panel != null and tower_profile_panel.visible)
		or (actor_prototype_panel != null and actor_prototype_panel.visible)
		or (showcase_presentation != null and showcase_presentation.input_blocked())
		or (blacksite_nine_presentation != null and blacksite_nine_presentation.input_blocked())
	):
		brush_preview.visible = false
		return
	var view_pixel: Vector2i = view_pixel_from_local_point(
		world_view.get_local_mouse_position()
	)
	var points: PackedVector2Array = brush_outline_points(view_pixel)
	brush_preview.visible = not points.is_empty()
	if brush_preview.visible:
		brush_preview.points = points


func queue_brush_mutation(
		world_x: int,
		world_y: int,
		radius: int,
		material_id: int,
		emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
	) -> bool:
	# Retained compatibility entry point for existing disc-oriented fixtures.
	if water_controlled_run_active() or not _microscenario_tool_allowed(material_id):
		return false
	return simulation_worker.queue_emit_disc(
		world_x,world_y,radius,material_id,emission_flags)


func queue_brush_footprint_mutation(
		world_x: int,
		world_y: int,
		material_id: int,
		emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
	) -> bool:
	if water_controlled_run_active() or not _microscenario_tool_allowed(material_id):
		return false
	if brush_shape == "circle" and (brush_size_px & 1) == 1:
		return simulation_worker.queue_emit_disc(
			world_x,
			world_y,
			(brush_size_px - 1) / 2,
			material_id,
			emission_flags
		)
	var cells: PackedInt32Array = brush_footprint_cells(world_x, world_y)
	if cells.is_empty():
		return false
	return simulation_worker.queue_emit_cells(cells, material_id, emission_flags)


func handle_painting() -> void:
	if _actor_usable_transition_pending or actor_equipment_active():
		return
	if _actor_usable_pointer_rearm:
		if (
			Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		):
			return
		_actor_usable_pointer_rearm = false
	if showcase_presentation != null and showcase_presentation.input_blocked(): return
	if blacksite_nine_presentation != null and blacksite_nine_presentation.input_blocked(): return
	if actor_prototype_panel != null and actor_prototype_panel.visible: return
	if microscenario_panel != null and microscenario_panel.modal_open(): return
	if tower_profile_panel != null and tower_profile_panel.visible: return
	var view_pixel: Vector2i = view_pixel_from_local_point(
		world_view.get_local_mouse_position()
	)
	if view_pixel.x < 0:
		return

	var emitted_material_id: int = brush_material_for_buttons(
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)
	if emitted_material_id < 0:
		return
	var emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
	if emitted_material_id != CyberCellWorld.EMPTY and coherent_liquid_emission:
		emission_flags = CyberCellWorld.EMISSION_FLAG_COHERENT_LIQUID

	var world_x: int = floori(camera_origin.x) + view_pixel.x
	var world_y: int = floori(camera_origin.y) + view_pixel.y
	queue_brush_footprint_mutation(
		world_x,
		world_y,
		emitted_material_id,
		emission_flags
	)


func view_content_rect() -> Rect2:
	# This is the single aspect-fit calculation used by both the shader and
	# pointer mapping. The backing texture is square, while the logical camera
	# is normally 16:9, so relying on TextureRect's texture aspect would make
	# the image and mouse coordinates disagree after a view-size change.
	var available_size: Vector2 = world_view.size
	if (
		available_size.x <= 0.0
		or available_size.y <= 0.0
		or current_view_size.x <= 0
		or current_view_size.y <= 0
	):
		return Rect2()
	var fit_scale: float = minf(
		available_size.x / float(current_view_size.x),
		available_size.y / float(current_view_size.y)
	)
	var shown_size: Vector2 = Vector2(current_view_size) * fit_scale
	return Rect2((available_size - shown_size) * 0.5, shown_size)


func upload_texture(material_cells: PackedByteArray, world_revision: int) -> void:
	if image == null or texture == null or previous_texture == null:
		return
	var start_usec: int = Time.get_ticks_usec()
	image.set_data(
		CyberCellWorld.WORLD_WIDTH,
		CyberCellWorld.WORLD_HEIGHT,
		false,
		render_image_format,
		material_cells
	)
	finish_texture_upload(world_revision, start_usec)


func upload_texture_patches(
	patch_rectangles: PackedInt32Array,
	patch_cells: PackedByteArray,
	world_revision: int,
	patch_channels: int
) -> bool:
	if image == null or texture == null or previous_texture == null:
		last_render_patch_validation_error = "render images are not initialized"
		return false
	var start_usec: int = Time.get_ticks_usec()
	if not apply_render_patches_to_image(
		patch_rectangles,
		patch_cells,
		patch_channels
	):
		return false
	finish_texture_upload(world_revision, start_usec)
	return true


func apply_render_patches_to_image(
	patch_rectangles: PackedInt32Array,
	patch_cells: PackedByteArray,
	patch_channels: int
) -> bool:
	last_render_patch_validation_error = validate_render_patch_payload(
		patch_rectangles,
		patch_cells,
		patch_channels
	)
	if not last_render_patch_validation_error.is_empty():
		return false
	for metadata_offset: int in range(
		0,
		patch_rectangles.size(),
		RENDER_PATCH_METADATA_STRIDE
	):
		var patch_x: int = patch_rectangles[metadata_offset]
		var patch_y: int = patch_rectangles[metadata_offset + 1]
		var patch_width: int = patch_rectangles[metadata_offset + 2]
		var patch_height: int = patch_rectangles[metadata_offset + 3]
		var data_offset: int = patch_rectangles[metadata_offset + 4]
		var row_stride: int = patch_rectangles[metadata_offset + 5]
		var row_bytes: int = patch_width * patch_channels
		var compact_cells: PackedByteArray
		if row_stride == row_bytes:
			compact_cells = patch_cells.slice(
				data_offset,
				data_offset + row_stride * patch_height
			)
		else:
			compact_cells.resize(row_bytes * patch_height)
			for row: int in range(patch_height):
				var source_row: int = data_offset + row * row_stride
				var destination_row: int = row * row_bytes
				for byte_index: int in range(row_bytes):
					compact_cells[destination_row + byte_index] = (
						patch_cells[source_row + byte_index]
					)
		var expected_compact_size: int = row_bytes * patch_height
		if compact_cells.size() != expected_compact_size:
			last_render_patch_validation_error = (
				"patch %d compacted to %d bytes; expected %d" % [
					metadata_offset / RENDER_PATCH_METADATA_STRIDE,
					compact_cells.size(),
					expected_compact_size,
				]
			)
			return false
		var patch_image: Image = Image.create_from_data(
			patch_width,
			patch_height,
			false,
			render_image_format,
			compact_cells
		)
		if patch_image == null or patch_image.is_empty():
			last_render_patch_validation_error = (
				"Image.create_from_data rejected patch %d (%dx%d, %d bytes)" % [
					metadata_offset / RENDER_PATCH_METADATA_STRIDE,
					patch_width,
					patch_height,
					compact_cells.size(),
				]
			)
			return false
		image.blit_rect(
			patch_image,
			Rect2i(0, 0, patch_width, patch_height),
			Vector2i(patch_x, patch_y)
		)
	return true


func validate_render_patch_payload(
	patch_rectangles: PackedInt32Array,
	patch_cells: PackedByteArray,
	patch_channels: int
) -> String:
	if patch_channels != render_channels:
		return "snapshot channel count %d does not match renderer channel count %d" % [
			patch_channels,
			render_channels,
		]
	if patch_channels != 1 and patch_channels != 2:
		return "unsupported render channel count %d" % patch_channels
	if patch_rectangles.is_empty():
		return "patch metadata is empty"
	if patch_rectangles.size() % RENDER_PATCH_METADATA_STRIDE != 0:
		return "patch metadata contains %d integers; expected a multiple of 6" % (
			patch_rectangles.size()
		)
	if patch_cells.is_empty():
		return "patch payload is empty"

	for metadata_offset: int in range(
		0,
		patch_rectangles.size(),
		RENDER_PATCH_METADATA_STRIDE
	):
		var patch_index: int = metadata_offset / RENDER_PATCH_METADATA_STRIDE
		var patch_x: int = patch_rectangles[metadata_offset]
		var patch_y: int = patch_rectangles[metadata_offset + 1]
		var patch_width: int = patch_rectangles[metadata_offset + 2]
		var patch_height: int = patch_rectangles[metadata_offset + 3]
		var data_offset: int = patch_rectangles[metadata_offset + 4]
		var row_stride: int = patch_rectangles[metadata_offset + 5]
		if patch_width <= 0 or patch_height <= 0:
			return "patch %d has non-positive dimensions %dx%d" % [
				patch_index,
				patch_width,
				patch_height,
			]
		if (
			patch_x < 0
			or patch_y < 0
			or patch_x > CyberCellWorld.WORLD_WIDTH - patch_width
			or patch_y > CyberCellWorld.WORLD_HEIGHT - patch_height
		):
			return "patch %d rectangle (%d,%d %dx%d) exceeds the world" % [
				patch_index,
				patch_x,
				patch_y,
				patch_width,
				patch_height,
			]
		var row_bytes: int = patch_width * patch_channels
		if data_offset < 0:
			return "patch %d has negative data offset %d" % [patch_index, data_offset]
		if row_stride < row_bytes:
			return "patch %d row stride %d is smaller than %d bytes" % [
				patch_index,
				row_stride,
				row_bytes,
			]
		var required_end: int = (
			data_offset + (patch_height - 1) * row_stride + row_bytes
		)
		if data_offset > patch_cells.size() or required_end > patch_cells.size():
			return "patch %d requires payload bytes [%d,%d), but only %d exist" % [
				patch_index,
				data_offset,
				required_end,
				patch_cells.size(),
			]
	return ""


func reject_render_snapshot(snapshot: CyberSimulationSnapshot) -> void:
	rejected_render_snapshot_count += 1
	if snapshot.render_snapshot_serial != last_rejected_render_snapshot_serial:
		push_error(
			"Rejected render snapshot %d (%d metadata integers, %d payload bytes): %s; requesting full refresh" % [
				snapshot.render_snapshot_serial,
				snapshot.render_patch_rectangles.size(),
				snapshot.render_patch_cells.size(),
				last_render_patch_validation_error,
			]
		)
		last_rejected_render_snapshot_serial = snapshot.render_snapshot_serial
	simulation_worker.request_render_full_refresh()


func finish_texture_upload(world_revision: int, start_usec: int) -> void:
	# Ping-pong two GPU textures. The shader blends movable occupancy from the
	# previous snapshot to the current one, masking the intentional two-cell
	# sparse-flight leap without changing authoritative physics or collisions.
	var old_current_texture: ImageTexture = texture
	texture = previous_texture
	previous_texture = old_current_texture
	texture.update(image)
	world_view.texture = texture
	world_shader.set_shader_parameter("current_world_texture", texture)
	world_shader.set_shader_parameter("previous_world_texture", previous_texture)
	if glow_source_shader != null:
		glow_source_shader.set_shader_parameter("world_texture", texture)
	snapshot_blend_start_usec = Time.get_ticks_usec()
	last_uploaded_revision = world_revision
	upload_time_ms = float(Time.get_ticks_usec() - start_usec) / 1000.0


func update_shader_parameters() -> void:
	if world_shader == null:
		return
	world_shader.set_shader_parameter(
		"world_size_px",
		Vector2(CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT)
	)
	world_shader.set_shader_parameter("view_size_px", Vector2(current_view_size))
	var content_rect: Rect2 = view_content_rect()
	update_glow_parameters(content_rect)
	update_vapour_trail()
	var inverse_control_size: Vector2 = Vector2(
		1.0 / maxf(world_view.size.x, 1.0),
		1.0 / maxf(world_view.size.y, 1.0)
	)
	world_shader.set_shader_parameter(
		"view_rect_uv",
		Vector4(
			content_rect.position.x * inverse_control_size.x,
			content_rect.position.y * inverse_control_size.y,
			content_rect.size.x * inverse_control_size.x,
			content_rect.size.y * inverse_control_size.y
		)
	)
	world_shader.set_shader_parameter(
		"camera_origin_px",
		Vector2(floori(camera_origin.x), floori(camera_origin.y))
	)
	var sampled_player_visible: bool = (
		not player_uses_barrel()
		and (latest_snapshot == null or latest_snapshot.actor_prototypes.is_empty())
		and not (
			tower_context.get("micro_active", false)
			and not tower_context.get("microscenario", {}).get("player_enabled", true)
		)
	)
	world_shader.set_shader_parameter(
		"player_origin_px",
		character_position if sampled_player_visible else Vector2(-1000,-1000)
	)
	world_shader.set_shader_parameter("player_size_px", CyberSampledCharacter.BODY_SIZE)
	var snapshot_blend: float = 1.0
	if cadence_lod_enabled:
		snapshot_blend = clampf(
			float(Time.get_ticks_usec() - snapshot_blend_start_usec)
			/ (1000000.0 / float(render_snapshot_hz)),
			0.0,
			1.0
		)
	world_shader.set_shader_parameter("snapshot_blend", snapshot_blend)
	world_shader.set_shader_parameter(
		"condition_projection_enabled",
		1.0 if render_channels == 2 else 0.0
	)
	var water_mode: int=0
	if tower_context.get("water_active",false):
		water_mode=2 if str(tower_context.get("water_policy",{}).get(
			"interface_mode","coverage"))=="oriented" else 1
	world_shader.set_shader_parameter("water_presentation_mode",water_mode)
	for body_index: int in range(mini(3, rigid_bodies.size()) if physical_actor_session == null else 0):
		var body_transform: Transform2D
		if rapier_bridge.is_initialized():
			body_transform = rapier_bridge.body_transform(body_index)
		else:
			body_transform = rigid_bodies[body_index].transform
		world_shader.set_shader_parameter(
			"rigid_body_data_%d" % body_index,
			Vector4(
				body_transform.origin.x,
				body_transform.origin.y,
				(PhysicalTrial.body_size(physical_trial_arm).x if body_index == 0 and player_uses_barrel() else TEST_RIGID_BODY_SIZE.x),
				(PhysicalTrial.body_size(physical_trial_arm).y if body_index == 0 and player_uses_barrel() else TEST_RIGID_BODY_SIZE.y)
			)
		)
		world_shader.set_shader_parameter(
			"rigid_body_rotation_%d" % body_index,
			body_transform.get_rotation()
		)
	if showcase_presentation != null:
		showcase_presentation.refresh()
	if blacksite_nine_presentation != null:
		blacksite_nine_presentation.refresh()


func recording_status_for_hud() -> Dictionary:
	# REC-001 is an independent sibling and may land before or after TEST-UX-001.
	# Discover its public recorder property dynamically so this branch stays
	# independently mergeable while consuming the real status() contract once it
	# is present.
	for property_info: Dictionary in get_property_list():
		if str(property_info.get("name", "")) != "gameplay_recorder":
			continue
		var recorder: Variant = get("gameplay_recorder")
		if recorder is Object and recorder.has_method("status"):
			var raw_status: Variant = recorder.call("status")
			if raw_status is Dictionary:
				return (raw_status as Dictionary).duplicate(true)
		break
	return {}


func update_status() -> void:
	if latest_snapshot != null and latest_snapshot.simulation_failed:
		status_label.visible = not microscenario_hud_hidden
		status_label.text = "STOPPED — R reset | fault %d | %s" % [
			latest_snapshot.tick_failure_count,
			latest_snapshot.last_tick_error,
		]
		return
	status_label.visible = debug_stats_visible and not microscenario_hud_hidden
	if not debug_stats_visible or microscenario_hud_hidden:
		return
	if latest_snapshot == null:
		status_label.text = "Simulation worker did not publish an initial snapshot."
		return

	var snapshot_age_ms: float = maxf(
		0.0,
		float(Time.get_ticks_usec() - latest_snapshot.published_usec) / 1000.0
	)
	var publication_text: String = "%dHz target" % render_snapshot_hz
	if measured_render_publication_hz > 0.0:
		publication_text += "/%.1f actual" % measured_render_publication_hz
	var player_available: bool = (
		player_uses_barrel()
		or not tower_context.get("micro_active", false)
		or tower_context.get("microscenario", {}).get("player_enabled", false)
	)
	var player_text: String = (
		"%.0f,%.0f" % [character_position.x, character_position.y]
		if player_available
		else "disabled"
	)
	player_text += " / " + player_representation_identity()
	player_text += " / " + str(active_player_environment_profile.get("id", "current-baseline"))
	var secondary_id: int = effective_secondary_material_id()
	var brush_hint: String = (
		"[J shape · -/+ size · ,/. ratio · O rotate]"
		if brush_shape == "rectangle"
		else "[J shape · -/+ size]"
	)
	var tool_text: String = "P %d:%s · M %d:%s · %s %s" % [
		selected_material_id,
		material_name(selected_material_id),
		secondary_id,
		material_name(secondary_id),
		brush_summary(),
		brush_hint,
	]
	var profile_text: String = str(tower_profile.get("name", "baseline"))
	if tower_context.get("micro_active", false):
		var micro: Dictionary = tower_context.get("microscenario", {})
		profile_text = "%s/%s" % [
			str(micro.get("id", "micro")),
			str(micro.get("mode", microscenario_mode)),
		]
	elif tower_context.get("water_active", false):
		profile_text = "water %s" % str(
			tower_context.get("water_policy_hash", "")
		).left(8)
	var recording_data: Dictionary = recording_status_for_hud()
	var recording_text: String = "rec n/a"
	if not recording_data.is_empty():
		if bool(recording_data.get("failed", false)):
			recording_text = "REC FAILED"
		elif bool(recording_data.get("active", false)):
			recording_text = "REC %dHz q%d/%d drop%d%s" % [
				int(recording_data.get("capture_hz", 0)),
				int(recording_data.get("queued_frames", 0)),
				int(recording_data.get("queue_capacity", 0)),
				int(recording_data.get("dropped_frames", 0)),
				" priming" if not bool(recording_data.get("primed", false)) else "",
			]
		else:
			recording_text = "rec off"
	var run_text: String = "PAUSED" if paused else "RUN"
	status_label.text = (
		"FPS %d · frame %.2f/%.2fms · sim %.2fms · pub %s [H] age %.1fms · tick %d · cells %d + %d dormant · moved %d · overruns %d\n"
		+ "player %s · %s · profile %s · %s · %s · F3 details"
	) % [
		int(Engine.get_frames_per_second()),
		frame_time_ms,
		maximum_frame_time_ms,
		latest_snapshot.worker_step_time_ms,
		publication_text,
		snapshot_age_ms,
		latest_snapshot.tick_index,
		latest_snapshot.scanned_last_tick,
		latest_snapshot.dormant_cells_skipped_last_tick,
		latest_snapshot.moves_last_tick,
		latest_snapshot.worker_overruns,
		player_text,
		tool_text,
		profile_text,
		recording_text,
		run_text,
	]

	if debug_stats_expanded:
		var thread_text: String = "%s/%d threads" % [
			latest_snapshot.backend_name,
			latest_snapshot.scheduler_thread_capacity_hint,
		]
		if worker_start_error != OK:
			thread_text = "thread-error-%d" % int(worker_start_error)
		var physics_text: String = "rapier-error-%d" % int(rapier_start_error)
		if rapier_bridge.is_initialized():
			physics_text = "Rapier %.2f+%.2fms hard=%d collider=%.2fms pending=%d" % [
				rapier_bridge.last_step_time_ms(),
				rapier_bridge.last_flush_time_ms(),
				rapier_bridge.hard_surface_shape_count(),
				maximum_collider_time_ms,
				rapier_bridge.pending_hard_surface_chunks(),
			]
		status_label.text += (
			"\nDETAIL %s · bridge %d/%.1fKiB%s · blocks %d/%d+%d frozen · sched %d jobs/%d phases cap~%d · ballistic %d"
			% [
				thread_text,
				last_render_patch_count,
				float(last_render_patch_bytes) / 1024.0,
				" full" if last_render_was_full_refresh else "",
				latest_snapshot.active_blocks_last_tick,
				latest_snapshot.eligible_blocks_last_tick,
				latest_snapshot.frozen_blocks_last_tick,
				latest_snapshot.scheduler_jobs_last_tick,
				latest_snapshot.scheduler_parallel_phases_last_tick,
				latest_snapshot.scheduler_thread_capacity_hint,
				latest_snapshot.sparse_flight_moves_last_tick,
			]
		)
		status_label.text += (
			"\nPHYS %s · bodies %d/%d/%d · view %dx%d +%dx%d · camera %.0f,%.0f %s · %s · %s · %s"
			% [
				physics_text,
				latest_snapshot.rigid_body_contacts_last_tick,
				latest_snapshot.rigid_body_displaced_last_tick,
				latest_snapshot.rigid_body_unresolved_last_tick,
				current_view_size.x,
				current_view_size.y,
				simulation_margin.x,
				simulation_margin.y,
				camera_origin.x,
				camera_origin.y,
				"follow" if camera_follow_enabled else "free",
				"windowed" if simulation_window_enabled else "whole-world",
				"smooth" if cadence_lod_enabled else "raw",
				"glow" if glow_enabled else "no-glow",
			]
		)

	if latest_snapshot.tick_failure_count > 0:
		status_label.text += " // STOPPED — R reset. Fault %d: %s" % [
			latest_snapshot.tick_failure_count,
			latest_snapshot.last_tick_error,
		]


func setup_glow_pipeline() -> void:
	# The root canvas uses HDR so emissive palette values can exceed 1.0. Glow
	# itself is produced in a half-resolution viewport and composited once.
	get_viewport().use_hdr_2d = true
	glow_viewport = SubViewport.new()
	glow_viewport.name = "MaterialGlowViewport"
	glow_viewport.disable_3d = true
	glow_viewport.transparent_bg = true
	glow_viewport.use_hdr_2d = true
	glow_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(glow_viewport)

	glow_source_shader = ShaderMaterial.new()
	glow_source_shader.shader = load("res://shaders/material_emission.gdshader") as Shader
	glow_source = ColorRect.new()
	glow_source.name = "MaterialEmissionSource"
	glow_source.color = Color.WHITE
	glow_source.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_source.material = glow_source_shader
	glow_viewport.add_child(glow_source)

	glow_composite_shader = ShaderMaterial.new()
	glow_composite_shader.shader = load("res://shaders/glow_composite.gdshader") as Shader
	glow_overlay = TextureRect.new()
	glow_overlay.name = "MaterialGlow"
	glow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	glow_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow_overlay.texture = glow_viewport.get_texture()
	glow_overlay.material = glow_composite_shader
	world_view.add_child(glow_overlay)
	set_glow_enabled(glow_enabled)
	setup_vapour_trail_pipeline()
	glow_source_shader.set_shader_parameter("world_texture", texture)
	glow_source_shader.set_shader_parameter(
		"material_program_lut",
		material_appearance_program
	)


# Single owner of glow state. Desktop/Web input, initialization and level
# restoration all route here so the flag, overlay and source updates agree.
func set_glow_enabled(enabled: bool) -> void:
	glow_enabled = enabled
	if glow_overlay != null:
		glow_overlay.visible = enabled
	if glow_viewport != null:
		glow_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
		)


func setup_vapour_trail_pipeline() -> void:
	if not vapour_trail_viewports.is_empty():
		return
	var trail_shader: Shader = load("res://shaders/material_vapour_trail.gdshader") as Shader
	for index: int in range(2):
		var viewport: SubViewport = SubViewport.new()
		viewport.name = "MaterialVapourTrail%d" % index
		viewport.disable_3d = true
		viewport.transparent_bg = false
		viewport.use_hdr_2d = true
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.size = current_view_size
		add_child(viewport)
		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = trail_shader
		var source: ColorRect = ColorRect.new()
		source.name = "VapourTrailSource"
		source.color = Color.WHITE
		source.size = Vector2(current_view_size)
		source.mouse_filter = Control.MOUSE_FILTER_IGNORE
		source.material = shader_material
		viewport.add_child(source)
		vapour_trail_viewports.append(viewport)
		vapour_trail_shaders.append(shader_material)
	# Each viewport reads the other's previous frame.
	vapour_trail_shaders[0].set_shader_parameter("history_texture", vapour_trail_viewports[1].get_texture())
	vapour_trail_shaders[1].set_shader_parameter("history_texture", vapour_trail_viewports[0].get_texture())
	vapour_trail_shaders[0].set_shader_parameter("delta_seconds", 0.0)
	vapour_trail_shaders[1].set_shader_parameter("delta_seconds", 0.0)


# Invalidates both generations without an extra clear pass. The next target
# records current gas with zero history weight; its successor can only sample
# that newly written target. Also used when a quality setting disables the pass.
func reset_vapour_trail() -> void:
	vapour_trail_latest = -1
	vapour_trail_frame = -1
	vapour_trail_usec = 0
	vapour_trail_origins.fill(Vector2.ZERO)
	for viewport: SubViewport in vapour_trail_viewports:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if world_shader != null:
		world_shader.set_shader_parameter("vapour_trail_strength", 0.0)


func set_vapour_trail_enabled(enabled: bool) -> void:
	if vapour_trail_enabled == enabled:
		return
	vapour_trail_enabled = enabled
	reset_vapour_trail()


# Advances the afterimage once per rendered frame, however often the shader
# parameters are refreshed. Pausing the simulation still lets ghosts fade.
func update_vapour_trail() -> void:
	if not vapour_trail_enabled or vapour_trail_viewports.is_empty() or world_shader == null:
		return
	# Resize both generations together. Resizing only the alternating target
	# drops the first history frame and can revive a buffer after rapid resizes.
	if vapour_trail_viewports[0].size != current_view_size or vapour_trail_viewports[1].size != current_view_size:
		reset_vapour_trail()
		for resized: SubViewport in vapour_trail_viewports:
			resized.size = current_view_size
			var source: ColorRect = resized.get_child(0) as ColorRect
			source.size = Vector2(current_view_size)
	var frame: int = Engine.get_process_frames()
	if frame == vapour_trail_frame:
		return
	vapour_trail_frame = frame
	var now_usec: int = Time.get_ticks_usec()
	var delta_seconds: float = 0.0
	if vapour_trail_latest >= 0:
		delta_seconds = maxf(float(now_usec - vapour_trail_usec) / 1000000.0, 0.0)
	vapour_trail_usec = now_usec
	var target: int = 0 if vapour_trail_latest != 0 else 1
	var history: int = 1 - target
	var viewport: SubViewport = vapour_trail_viewports[target]
	vapour_trail_viewports[history].render_target_update_mode = SubViewport.UPDATE_DISABLED
	var origin: Vector2 = Vector2(floori(camera_origin.x), floori(camera_origin.y))
	var shader_material: ShaderMaterial = vapour_trail_shaders[target]
	shader_material.set_shader_parameter("world_texture", texture)
	shader_material.set_shader_parameter(
		"world_size_px", Vector2(CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT))
	shader_material.set_shader_parameter("view_size_px", Vector2(current_view_size))
	shader_material.set_shader_parameter("camera_origin_px", origin)
	shader_material.set_shader_parameter("history_origin_px", vapour_trail_origins[history])
	shader_material.set_shader_parameter(
		"delta_seconds",
		delta_seconds if vapour_trail_viewports[history].size == current_view_size else 0.0
	)
	shader_material.set_shader_parameter(
		"condition_projection_enabled", 1.0 if render_channels == 2 else 0.0)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	vapour_trail_origins[target] = origin
	vapour_trail_latest = target
	world_shader.set_shader_parameter("vapour_trail_texture", viewport.get_texture())
	world_shader.set_shader_parameter("vapour_trail_origin_px", origin)
	world_shader.set_shader_parameter("vapour_trail_strength", 1.0)


func update_glow_parameters(content_rect: Rect2) -> void:
	if glow_viewport == null or glow_source_shader == null or glow_overlay == null:
		return
	var downsampled_size: Vector2i = Vector2i(
		maxi(80, current_view_size.x / 2),
		maxi(45, current_view_size.y / 2)
	)
	if glow_viewport.size != downsampled_size:
		glow_viewport.size = downsampled_size
		glow_source.position = Vector2.ZERO
		glow_source.size = Vector2(downsampled_size)
	glow_overlay.position = content_rect.position
	glow_overlay.size = content_rect.size
	glow_source_shader.set_shader_parameter(
		"world_size_px",
		Vector2(CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT)
	)
	glow_source_shader.set_shader_parameter("view_size_px", Vector2(current_view_size))
	glow_source_shader.set_shader_parameter(
		"camera_origin_px",
		Vector2(floori(camera_origin.x), floori(camera_origin.y))
	)
	glow_source_shader.set_shader_parameter(
		"condition_projection_enabled",
		1.0 if render_channels == 2 else 0.0
	)


func material_name(material_id: int) -> String:
	match material_id:
		CyberCellWorld.EMPTY:
			return "empty"
		CyberCellWorld.WALL:
			return "wall"
		CyberCellWorld.SAND:
			return "sand"
		CyberCellWorld.WATER:
			return "water"
		CyberCellWorld.SMOKE:
			return "smoke"
		CyberCellWorld.CLONER:
			return "cloner"
		CyberCellWorld.FIRE:
			return "fire"
		CyberCellWorld.WOOD:
			return "wood"
		CyberCellWorld.LAVA:
			return "lava"
		CyberCellWorld.ICE:
			return "ice"
		CyberCellWorld.PLANT:
			return "plant"
		CyberCellWorld.ACID:
			return "acid"
		CyberCellWorld.STONE:
			return "stone"
		CyberCellWorld.DUST:
			return "dust"
		CyberCellWorld.MITE:
			return "mite"
		CyberCellWorld.OIL:
			return "oil"
		CyberCellWorld.ROCKET:
			return "rocket"
		CyberCellWorld.FUNGUS:
			return "fungus"
		CyberCellWorld.SEED:
			return "seed"
		CyberCellWorld.PASTE:
			return "paste"
		CyberCellWorld.SLUSH:
			return "slush"
		CyberCellWorld.STEAM:
			return "steam"
		CyberCellWorld.SALT:
			return "salt"
		CyberCellWorld.BRINE:
			return "brine"
		CyberCellWorld.SODIUM:
			return "sodium"
		CyberCellWorld.GUNPOWDER:
			return "gunpowder"
		CyberCellWorld.COAL:
			return "coal"
		CyberCellWorld.METAL:
			return "metal"
		CyberCellWorld.RUST:
			return "rust"
		CyberCellWorld.CEMENT:
			return "cement"
		CyberCellWorld.CONCRETE:
			return "concrete"
		CyberCellWorld.TOXIC_SLUDGE:
			return "toxic sludge"
		CyberCellWorld.MERCURY:
			return "mercury"
		CyberCellWorld.SPARK:
			return "spark"
		CyberCellWorld.GLASS:
			return "glass"
		CyberCellWorld.MOLTEN_GLASS:
			return "molten glass"
		CyberCellWorld.FOAM:
			return "foam"
		CyberCellWorld.LIMESTONE_BLOCK:
			return "limestone block"
		CyberCellWorld.SANDSTONE_BLOCK:
			return "sandstone block"
		CyberCellWorld.GRANITE_BLOCK:
			return "granite block"
		CyberCellWorld.COBBLESTONE:
			return "cobblestone"
		CyberCellWorld.MOSSY_COBBLESTONE:
			return "mossy cobblestone"
		CyberCellWorld.RED_BRICK:
			return "red brick"
		CyberCellWorld.LIME_PLASTER:
			return "lime plaster"
		CyberCellWorld.WATTLE_AND_DAUB:
			return "wattle and daub"
		CyberCellWorld.OAK_TIMBER:
			return "oak timber"
		CyberCellWorld.THATCH:
			return "thatch"
		CyberCellWorld.TERRACOTTA_TILE:
			return "terracotta tile"
		CyberCellWorld.SLATE:
			return "slate"
		CyberCellWorld.WROUGHT_IRON:
			return "wrought iron"
		CyberCellWorld.LEAD_SHEET:
			return "lead sheet"
		CyberCellWorld.BRONZE:
			return "bronze"
		CyberCellWorld.COPPER:
			return "copper"
		CyberCellWorld.VERDIGRIS_COPPER:
			return "verdigris copper"
		CyberCellWorld.STAINED_GLASS:
			return "stained glass"
		CyberCellWorld.PACKED_EARTH:
			return "packed earth"
		CyberCellWorld.INDUSTRIAL_BRICK:
			return "industrial brick"
		CyberCellWorld.REINFORCED_CONCRETE:
			return "reinforced concrete"
		CyberCellWorld.ASPHALT:
			return "asphalt"
		CyberCellWorld.WET_ASPHALT:
			return "wet asphalt"
		CyberCellWorld.WET_COBBLESTONE:
			return "wet cobblestone"
		CyberCellWorld.STEEL_PLATE:
			return "steel plate"
		CyberCellWorld.PAINTED_STEEL:
			return "painted steel"
		CyberCellWorld.CORRUGATED_STEEL:
			return "corrugated steel"
		CyberCellWorld.RUSTED_STEEL:
			return "rusted steel"
		CyberCellWorld.STEEL_GRATING:
			return "steel grating"
		CyberCellWorld.CHAINLINK:
			return "chainlink"
		CyberCellWorld.STEEL_PIPE:
			return "steel pipe"
		CyberCellWorld.COPPER_PIPE:
			return "copper pipe"
		CyberCellWorld.CERAMIC_TILE:
			return "ceramic tile"
		CyberCellWorld.CHEMICAL_GLASS:
			return "chemical glass"
		CyberCellWorld.DARK_GLASS:
			return "dark glass"
		CyberCellWorld.RUBBER:
			return "rubber"
		CyberCellWorld.CABLE_BUNDLE:
			return "cable bundle"
		CyberCellWorld.INSULATION:
			return "insulation"
		CyberCellWorld.HAZARD_STRIPE:
			return "hazard stripe"
		CyberCellWorld.NEON_CYAN:
			return "neon cyan"
		CyberCellWorld.NEON_MAGENTA:
			return "neon magenta"
		CyberCellWorld.NEON_AMBER:
			return "neon amber"
		CyberCellWorld.LED_WHITE:
			return "LED white"
		_:
			if material_id >= CyberCellWorld.FIRST_BUILDING_MATERIAL and material_id <= CyberCellWorld.LAST_MATERIAL:
				return CyberCellWorld.BUILDING_MATERIAL_NAMES[material_id - CyberCellWorld.FIRST_BUILDING_MATERIAL]
			return "material-%d" % material_id
