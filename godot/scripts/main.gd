extends Control

const MaterialPublisher = preload("res://scripts/blit_material_publisher.gd")
const FullImageRingPublisher = preload("res://scripts/full_image_ring_publisher.gd")
const MaterialPublicationDeadline = preload("res://scripts/material_publication_deadline.gd")
const MaterialPublicationSteps = preload("res://scripts/material_publication_steps.gd")
const PixelCamera = preload("res://scripts/pixel_camera_transform.gd")
const PhysicalTrial = preload("res://scripts/physical_actor_trial.gd")
const PhysicalCatalog = preload("res://scripts/physical_actor_catalog.gd")
const PhysicalSession = preload("res://scripts/physical_actor_session.gd")
const WorkbenchBridge = preload("res://scripts/workbench_physics_bridge.gd")
const WorkbenchPresentationCoherence = preload("res://scripts/workbench_presentation_coherence.gd")
const WorkbenchWaterComposition = preload("res://scripts/workbench_water_composition.gd")
const WorkbenchMaterialTimeline = preload("res://scripts/workbench_material_timeline.gd")
const WorkbenchPresentationHistory = preload("res://scripts/workbench_presentation_history.gd")
const WorkbenchPresentationSubmission = preload("res://scripts/workbench_presentation_submission.gd")
const WorkbenchPoseTrace = preload("res://scripts/workbench_pose_trace.gd")
const OwnerGameplay = preload("res://scripts/workbench_owner_gameplay.gd")
const WorkbenchNativeRendezvous = preload("res://scripts/workbench_native_rendezvous.gd")
const WorkbenchSameFrameContinuation = preload("res://scripts/workbench_same_frame_continuation.gd")
const PhysicalOverlay = preload("res://scripts/physical_actor_overlay.gd")
const PhysicalLoadouts = preload("res://scripts/physical_usable_loadouts.gd")
const PhysicalEquipment = preload("res://scripts/physical_usable_equipment.gd")
const PlayerCourse = preload("res://scripts/player_playground_course.gd")
const PlayableCourseLap = preload("res://scripts/playable_course_lap.gd")
const PlayableCourseOverlay = preload("res://scripts/playable_course_overlay.gd")
const SnapshotPublicationCounter = preload("res://scripts/snapshot_publication_counter.gd")
const FACE_TUNING := ["workbench_face_budget","workbench_face_speed","workbench_face_period","workbench_face_min_height"]
const WAVE_TUNING := [
	"workbench_wave_substeps","workbench_wave_active_rows","workbench_wave_gain",
	"workbench_wave_deep_gain","workbench_wave_floor_gain","workbench_wave_flux_smoothing",
	"workbench_wave_gain_confined","workbench_wave_stiffness","workbench_wave_damp_shift",
	"workbench_wave_coast","workbench_wave_level_shift","workbench_wave_sleep_after",
	"workbench_wave_wake_peak","workbench_wave_rest_head","workbench_wave_stick",
	"workbench_wave_calm","workbench_wave_calm_damp_shift","workbench_wave_maximum_mass",
	"workbench_wave_empty_pour_shift","workbench_wave_flow_share_shift","workbench_wave_adhesion_shift",
	"workbench_wave_body_push","workbench_wave_body_push_by_mass",
]
# WAVE-WATERWALL-001 exposed-face spill: Wave-only construction requests.
const WAVE_SPILL_SWITCHES := ["workbench_wave_spill","workbench_wave_spill_parcels","workbench_wave_spill_full_face"]
const WAVE_SPILL_TUNING := [
	"workbench_wave_spill_fall","workbench_wave_spill_draw","workbench_wave_spill_deep_draw","workbench_wave_spill_draw_head","workbench_wave_spill_sheet_rate","workbench_wave_spill_coyote_ticks",
	"workbench_wave_spill_launch_speed","workbench_wave_spill_launch_budget",
	"workbench_wave_spill_stream_share","workbench_wave_spill_blobs","workbench_wave_spill_stream_draw",
]
const PlayableSessionPanel = preload("res://scripts/playable_session_panel.gd")
const DEFAULT_PLAYABLE_OPTIONS: Dictionary = {"controls":"keyboard_gamepad", "rules":"lap", "camera":"follow"}
const PLAYABLE_RECOVERY_META: StringName = &"cybersand_playable_recovery"
var playable_session_panel: PopupPanel
var playable_session_options: Dictionary = DEFAULT_PLAYABLE_OPTIONS.duplicate()
var _playable_recovery_queued: bool = false
var _playable_recovery_cancelled: bool = false
var _playable_recovery_error: String = ""
const PreparedPhysical = preload("res://scripts/prepared_physical_session.gd")
const PreparedReferenceBody = preload("res://scripts/prepared_reference_body_session.gd")
const PreparedTrialBody = preload("res://scripts/prepared_trial_body_session.gd")
var _pending_physical_candidate: RefCounted
var _accepted_physical_candidate: RefCounted
var _prepared_physical_identity: Dictionary = {}
var _prepared_physical_ready_sent: bool = false
var _prepared_physical_factory: Callable = Callable()
var _prepared_reference_factory: Callable = Callable()
var _prepared_trial_factory: Callable = Callable()
var _accepted_reference_candidate: RefCounted
var exploratory_actor_configuration: Dictionary = {}
var physical_trial_arm: String = ""
var physical_trial_input = PhysicalTrial.new()
var physical_rig_id: StringName = &""
var physical_actor_session: CyberPhysicalActorSession
var physical_actor_overlay: CyberPhysicalActorOverlay
# The evaluator can finish scheduled fixed steps as native samples become ready.
# No worker touches a RID. At most four recent callbacks are retained and the
# ordinary transaction still consumes exactly one new native result per step.
var _flight_pacing := OS.get_environment("CYBERSAND_WORKBENCH_FLIGHT_PACING") == "1"
var _held_flight_callbacks: int = 0
var _held_flight_times := PackedInt64Array()
var _held_flight_ticket: Dictionary = {}
var _serviced_flight_callbacks: int = 0
var _last_flight_sample_hold_usec: int = -1000000
var _workbench_wait_sample: int = -1
var _workbench_frame_error: String = ""
var _workbench_collider_frame: int = -1
var _workbench_native_rendezvous = WorkbenchNativeRendezvous.new()
# Separate renderer selection is independently controlled by Godot's existing
# --render-thread option. This scheduling experiment is never enabled silently.
var _workbench_native_rendezvous_selection: String = OS.get_environment("CYBERSAND_DIAG_NATIVE_RENDEZVOUS")
var _workbench_native_rendezvous_enabled: bool = _workbench_native_rendezvous_selection in ["1", "render-overlap"]
# Independent, explicitly selected experiment. Existing rendezvous and its
# waits are mutually exclusive with a nonblocking same-frame continuation.
var _workbench_same_frame = WorkbenchSameFrameContinuation.new()
var _workbench_same_frame_requested: bool = OS.get_environment("CYBERSAND_DIAG_SAME_FRAME_CONTINUATION") == "1"
var _workbench_same_frame_enabled: bool = _workbench_same_frame_requested and not _workbench_native_rendezvous_enabled
var shared_workbench: Control
# Opt-in physical presentation trace. Empty and inactive in normal operation.
var workbench_pose_trace = WorkbenchPoseTrace.new()
var _owner_gameplay: OwnerGameplay
var _workbench_pose_trace_reasons: Dictionary = {}
# Causal observation seam shared with the bounded worker trace. Ordinary play
# creates no event dictionaries or additional reads. Main retains no event log.
var _pubpres_trace_enabled: bool = OS.get_environment("CYBERSAND_DIAG_PHYSICS_CAUSAL_TRACE") == "1"
# One resolved presentation decision per Main render submission. Rapier and
# native World remain authoritative; this state owns only visual selection.
var workbench_presentation_frame: Dictionary = {}
var _workbench_presentation_state: Dictionary = {}
var _workbench_presentation_identity: Array = []
var _workbench_presentation_policy: String = ""
var _workbench_presentation_turn: int = 0
var _workbench_follow_state: Dictionary = {}
var _workbench_mapping_locked: bool = false
# Default-off live transaction required by the bounded engine experiment.
# Only the actual pre-draw callback commits visible history and mapping.
signal workbench_presentation_submitted(frame: Dictionary)
var _workbench_submission_requested: bool = OS.get_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION") == "1"
var _workbench_submission: Node
var _workbench_submission_preparing: bool = false
var _workbench_submission_refusal: String = ""
var _workbench_submission_notification_pending: bool = false
var _workbench_observation_identity: Array = []
# Sample serials are not Rapier steps. Retain their real correspondence at
# publication, independently of the physics bridge's short impulse history.
const PRESENTATION_SAMPLE_HISTORY: int = 2048
var _workbench_sample_steps: Dictionary = {}
var _workbench_sample_identity: Array = []
var _workbench_presentation_history = WorkbenchPresentationHistory.new()
var _workbench_completed_step: int = -1
var _workbench_completed_step_usec: int = 0
var _workbench_water_dependencies: Dictionary = {}
var _workbench_water_completion_context: Dictionary = {}
var _workbench_water_closure_cache: Dictionary = {}
var _workbench_water_closure_cache_hits: int = 0
var _workbench_water_coverage_cache: Dictionary = {}
var _workbench_water_coverage_cache_hits: int = 0
var engine_lab_wait_native_sample: bool = true
var engine_lab_ack_delay_frames: int = 0
var _engine_lab_pending_ack_serial: int = 0
var _engine_lab_pending_ack_frames: int = 0
# Each accepted upload owns a fixed deadline. Later uploads cannot restart it.
# At most five due-frame buckets exist (the UI delay is bounded to 0..4).
var _engine_lab_ack_queue: Array[Dictionary] = []
var _engine_lab_last_ack_serial: int = 0
var _engine_lab_last_ack_usec: int = 0
var _cadence_upload: Dictionary = {}
var _cadence_received_usec: int = 0
var _cadence_physics_hold_counts: Dictionary = {}
var engine_lab_scripted_input: bool = false
var _engine_lab_scripted_start_tick: int = 0
# Test It uses source-fenced, physics-tick-indexed inputs, not wall-clock keys.
# This mode is accessible only to the explicit --engine-lab-scripted runner.
var engine_lab_replay_active: bool = false
var engine_lab_replay_source_epoch: int = -1
var engine_lab_replay_source_generation: int = -1
var engine_lab_replay_tick_zero: int = -1
var engine_lab_replay_tape: Array[Dictionary] = []
var engine_lab_replay_events: Array[Dictionary] = []
var engine_lab_replay_error: String = ""
var _engine_lab_last_replay_segment: int = -1
# Experimental Water settings staged for explicit Apply/Load. Unrelated
# lifecycle rebuilds reuse the last acknowledged native construction options.
# Empty keeps every default.
var workbench_water_options: Dictionary = {}
var world_extent := Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT)
var playable_course_overlay: Control
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
# Workbench lock-step: Rapier cannot step until the current terrain is
# installed, so a blocked frame spends a larger (still bounded) budget rather
# than idling for several rendered frames per terrain revision.
const WORKBENCH_HARD_SURFACE_CHUNKS_PER_FRAME: int = 128
const WORKBENCH_HARD_SURFACE_FRAME_BUDGET_USEC: int = 4000
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
@onready var course_timing_label: Label = $Layout/CourseTiming
@onready var world_shader: ShaderMaterial = world_view.material as ShaderMaterial
@onready var test_rigid_body_1: RigidBody2D = $RigidBodies/TestBody1
@onready var test_rigid_body_2: RigidBody2D = $RigidBodies/TestBody2
@onready var test_rigid_body_3: RigidBody2D = $RigidBodies/TestBody3

# Desktop construction samples the current native capacity before entering the
# tree. The browser constructs its gameplay World in its synchronous controller.
var simulation_worker: CyberSimulationWorker = CyberSimulationWorker.new(not OS.has_feature("web"))
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
		and (not player_uses_barrel() or physical_trial_arm in ["barrel","ripper"]) and _actor_reset_receipt == 0
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
		exploratory: bool = true, requested_recovery: Variant = null, requested_profile: Dictionary = {},
		requested_player: Dictionary = {}, retain_trial_motion: bool = true) -> bool:
	if not liquid_comparison_can_apply_active(exploratory):
		microscenario_error = "Native default demo requires its ordinary Exploratory reference or single trial owner"
		return false
	if simulation_worker.has_failed() or not tower_context.native_default_demo.get("healthy",false):
		microscenario_error = "Prepared Restart requires a healthy World; load Current or another setup to recover"
		return false
	var player_configuration: Dictionary = requested_player.duplicate(true) if not requested_player.is_empty() else _default_trial_player_configuration()
	var arm: String = str(player_configuration.get("physical_trial",""))
	var retain_motion: bool = retain_trial_motion and requested_player.is_empty() and arm in ["barrel","ripper"]
	var staged: RefCounted
	if not arm.is_empty():
		staged = _prepare_trial_candidate(arm,CHARACTER_SPAWN,retain_motion)
	else:
		staged = _prepared_reference_factory.call() if _prepared_reference_factory.is_valid() else PreparedReferenceBody.new()
		var positions := PackedVector2Array()
		var rotations := PackedFloat32Array()
		for index: int in range(3):
			positions.append(test_rigid_body_spawn(index,false));rotations.append(test_rigid_body_rotation(index))
		var templates: Array[RigidBody2D] = [test_rigid_body_1,test_rigid_body_2,test_rigid_body_3]
		if not staged.prepare_reference(self,templates,TEST_RIGID_BODY_SIZE,positions,rotations):
			microscenario_error = staged.last_error;staged.close();return false
	if staged == null:
		return false
	if not staged.pose_unchanged():
		microscenario_error = staged.last_error;staged.close()
		return false
	var origin: Vector2 = clamped_camera_origin(CHARACTER_SPAWN+CyberSampledCharacter.BODY_SIZE*0.5-Vector2(current_view_size)*0.5)
	var owner: Dictionary = {"view_origin":Vector2i(origin.floor()),"view_size":current_view_size,
		"horizontal_buffer":simulation_margin.x,"vertical_buffer":simulation_margin.y,
		"simulation_window_enabled":simulation_window_enabled,"cadence_lod_enabled":cadence_lod_enabled,
		"liquid_surface_adhesion_enabled":liquid_surface_adhesion_enabled}
	var setup: Dictionary = {"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "",
		"maximum_rule_radius":radius,"physical_owner":{"kind":staged.owner_kind(),"epoch":0 if arm.is_empty() else staged.epoch,
			"instance_id":staged.get_instance_id(),"initial_bodies":staged.initial_body_states()}}
	if not arm.is_empty(): setup.physical_owner.trial_arm = arm
	_microscenario_request_serial += 1
	var recovery: bool = bool(player_configuration.get("runtime_recovery_enabled",sampled_runtime_recovery_enabled)) if requested_recovery == null else bool(requested_recovery)
	player_configuration.runtime_recovery_enabled=recovery
	_pending_physical_candidate = staged
	_prepared_physical_identity = {};_prepared_physical_ready_sent = false
	pending_microscenario_apply = {"route":"native_default","serial":_microscenario_request_serial,
		"previous_paused":paused,"previous_mode":microscenario_mode,"liquid_policy":policy.duplicate(),
		"controlled_liquid_setup":setup.duplicate(true),"owner_execution":owner.duplicate(true),"runtime_recovery":recovery,
		"profile_request":not requested_profile.is_empty(),"player_configuration":player_configuration,
		"retain_trial_input":retain_motion,"trial_source":_trial_source_binding() if retain_motion else {}}
	paused = true
	var command: Dictionary = {"default_liquid_reset":true,"expected_default_generation":int(tower_context.native_default_demo.session_generation),
		"scenario_request_serial":_microscenario_request_serial,"sampled_character_enabled":arm.is_empty(),
		"source_sampled_character_enabled":not player_uses_barrel(),"expected_rigid_body_epoch":_body_owner_epoch(),
		"default_player_configuration":player_configuration.duplicate(true),
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
	var retained_input: RefCounted = physical_trial_input
	_apply_microscenario_player_configuration({"player_start":[CHARACTER_SPAWN.x,CHARACTER_SPAWN.y]},pending_microscenario_apply.player_configuration)
	if pending_microscenario_apply.get("retain_trial_input",false): physical_trial_input = retained_input
	character_position = CHARACTER_SPAWN;camera_follow_enabled = true;paused = true
	camera_origin = Vector2(pending_microscenario_apply.owner_execution.view_origin)
	_adopt_prepared_physical_candidate()
	simulation_worker.acknowledge_prepared_liquid_configuration(int(pending_microscenario_apply.serial))

func _default_trial_player_configuration() -> Dictionary:
	return {"representation":"barrel-rapier" if physical_trial_arm in ["barrel","ripper"] else "sampled",
		"runtime_recovery_enabled":sampled_runtime_recovery_enabled,"physical_trial":physical_trial_arm,
		"physical_rig":"","actor_model":"","actor_producer":"human","actor_demo_npcs":false,"actor_definitions":[]}

func _prepare_trial_candidate(arm: String, spawn: Vector2, retain_motion: bool) -> RefCounted:
	var states := PackedFloat32Array()
	var template: RigidBody2D = test_rigid_body_1
	if retain_motion:
		if physical_trial_arm!=arm or rigid_bodies.size()!=1 or not rapier_bridge.is_initialized():
			microscenario_error="Trial Apply requires its actual live single body";return null
		template=rigid_bodies[0];rapier_bridge.refresh_all_states();states=rapier_bridge.pack_body_states()
	else:
		CyberRigidBodyCoupling.append_input(states,1,spawn+CyberSampledCharacter.BODY_SIZE*0.5,0,
			PhysicalTrial.body_size(arm),Vector2.ZERO,0,template.mass,0)
	var staged: RefCounted = _prepared_trial_factory.call() if _prepared_trial_factory.is_valid() else PreparedTrialBody.new()
	if not staged.prepare_trial(self,template,arm,_physical_epoch+1,states):
		microscenario_error=staged.last_error;staged.close();return null
	return staged

func _trial_source_binding() -> Dictionary:
	rapier_bridge.refresh_all_states()
	return {"bodies":rigid_bodies.duplicate(),"pose":PreparedPhysical._pose_values(rapier_bridge.pack_body_states()),
		"arm":physical_trial_arm,"representation":player_representation,"input":physical_trial_input,"epoch":_body_owner_epoch(),
		"input_values":[physical_trial_input.armed,physical_trial_input.jump_held,physical_trial_input.pulse_cooldown,physical_trial_input.action.duplicate(true)]}

func _body_owner_epoch() -> int:
	return _physical_epoch if physical_actor_session!=null or (_accepted_reference_candidate!=null \
		and _accepted_reference_candidate.owner_kind()=="trial_body") else 0

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
		{"intent":"exploratory","normalization":"water-normalize-v1" if normalize_water else "","maximum_rule_radius":maximum_rule_radius},
		actor_configuration.is_empty() and definition==microscenario_definition)

func microscenario_supports_prepared_physical_liquid(definition: Dictionary) -> bool:
	if tower_context.get("water_active",false):
		return bool(definition.get("body_enabled",false)) and physical_actor_session == null and not player_uses_barrel()
	return (physical_rig_id != &"" or physical_trial_arm in ["barrel","ripper"]) and microscenario_mode != "Benchmark" \
		and CyberMicroScenarioCatalogue.exploratory_actor_map(definition)


func playable_session_unavailable_reason() -> String:
	if _playable_recovery_queued:
		return "Rebuilding the applied session from its initial state."
	if not _playable_recovery_error.is_empty():
		return _playable_recovery_error
	if simulation_worker.has_failed():
		return ("World stopped. Restart the applied session to rebuild it from its initial state."
			if playable_session_can_recover() else "World stopped. Return to the launcher with F2 to start a fresh session.")
	if not pending_microscenario_apply.is_empty() or not pending_water_apply.is_empty():
		return "A session rebuild is still pending."
	if not water_blind_set.is_empty() or not water_active_blind_label.is_empty() \
		or not actor_prototypes_allowed():
		return "Leave the protected experiment before starting a playable session."
	return ""


func playable_session_can_recover() -> bool:
	# A failed prepared World cannot be the retained input to another native
	# preparation. Explicit recovery retires the WHOLE scene before its new
	# owner starts. Pending candidates belong to that retiring scene as well.
	return (not _playable_recovery_queued and not _playable_recovery_cancelled and is_inside_tree()
		and get_tree().current_scene == self and simulation_worker.has_failed()
		and _playable_course_controls_active() and water_blind_set.is_empty()
		and water_active_blind_label.is_empty()
		and microscenario_liquid_setup.get("intent", "") == "exploratory"
		and microscenario_liquid_policy is PackedInt32Array)


func _queue_failed_playable_restart() -> void:
	if not playable_session_can_recover(): return
	# Carry values from the accepted owner, never unsubmitted panel choices,
	# partial failed cells, commands, snapshots, nodes, RIDs or native pointers.
	var selection: Dictionary = playable_session_options.duplicate(true)
	selection.map = CyberMicroScenarioCatalogue.PLAYER_COURSE_ID
	selection.actor = str(physical_rig_id)
	var request: Dictionary = {"selection":selection,
		"policy":microscenario_liquid_policy.duplicate(),
		"definition":microscenario_definition.duplicate(true),
		# microscenario_mode can already describe an unaccepted pending request.
		# The completed worker context retains the accepted execution mode.
		"mode":str(tower_context.microscenario.mode),
		"setup":microscenario_liquid_setup.duplicate(true),
		"settings":{"simulation_window_enabled":simulation_window_enabled,
			"cadence_lod_enabled":cadence_lod_enabled,
			"liquid_surface_adhesion_enabled":liquid_surface_adhesion_enabled,
			"simulation_margin_index":simulation_margin_index, "simulation_margin":simulation_margin,
			"render_snapshot_hz_index":render_snapshot_hz_index, "render_snapshot_hz":render_snapshot_hz,
			"player_environment_profile":active_player_environment_profile.duplicate(true)}}
	_playable_recovery_queued = true
	_playable_recovery_error = ""
	paused = true
	cancel_playable_course_input()
	_reload_failed_playable_scene.call_deferred(request)


func workbench_restart(candidate: Dictionary) -> bool:
	if shared_workbench == null or not simulation_worker.has_failed(): return false
	if _playable_recovery_queued or _playable_recovery_cancelled or not is_inside_tree() or get_tree().current_scene != self:
		microscenario_error = "A scene change is already pending."
		return false
	const Setup = preload("res://scripts/workbench_setup.gd")
	var error: String = Setup.validate(candidate)
	if not error.is_empty():
		microscenario_error = error
		return false
	var recipe := Setup.rectangles(candidate)
	if recipe.has("error"):
		microscenario_error = recipe.error
		return false
	var checked: Dictionary = playable_session_panel.policy_editor.bridge.validate_liquid_policy(PackedInt32Array(candidate.liquid_policy))
	if not checked.get("accepted",false) or candidate.rule_radius < checked.receipt.minimum_rule_radius:
		microscenario_error = "Invalid liquid policy or rule radius for this starting setup."
		return false
	# A failed World cannot provide live cells or accept another prepared
	# replacement. Carry only the checked authored setup across teardown and
	# let fresh Main create its own worker before constructing this setup.
	_playable_recovery_queued = true
	_playable_recovery_error = ""
	paused = true
	cancel_playable_course_input()
	# A restart creates a new Main as well as a new native owner. Carry the last
	# accepted construction options, not unsubmitted/invalid edits in the panel.
	# Otherwise an active Wave World silently returns to its FreeMass carrier.
	var accepted_water := {}
	var construction_keys: Array = FACE_TUNING + WAVE_TUNING + WAVE_SPILL_SWITCHES + WAVE_SPILL_TUNING + [
		"workbench_wave_flow","workbench_ballistic","workbench_face_release",
		"workbench_inertial_signed","workbench_fine_cores","workbench_worker_threads",
		"pressure_gas_compartment_capacity"]
	for key: String in construction_keys:
		if microscenario_liquid_setup.has(key): accepted_water[key] = microscenario_liquid_setup[key]
	_reload_failed_playable_scene.call_deferred({"workbench":candidate.duplicate(true),
		"workbench_water_options":accepted_water})
	return true

func cancel_playable_session_recovery() -> void:
	# Navigation owns the user's latest intent. Fence a still-deferred restart
	# and discard an envelope whose pending replacement has not entered yet.
	_playable_recovery_cancelled = true
	_playable_recovery_queued = false
	if is_inside_tree() and get_tree().has_meta(PLAYABLE_RECOVERY_META):
		get_tree().remove_meta(PLAYABLE_RECOVERY_META)


func _reload_failed_playable_scene(request: Dictionary) -> void:
	# F2/another scene transition can win before this deferred request. Never
	# leave a recovery envelope for an unrelated future launch in that case.
	if _playable_recovery_cancelled or not _playable_recovery_queued \
		or not is_inside_tree() or get_tree().current_scene != self: return
	var tree: SceneTree = get_tree()
	tree.set_meta(PLAYABLE_RECOVERY_META, request.duplicate(true))
	var error: Error = tree.reload_current_scene()
	if error != OK:
		tree.remove_meta(PLAYABLE_RECOVERY_META)
		_playable_recovery_queued = false
		_playable_recovery_error = "Fresh session restart failed (%d); return to the launcher with F2." % error
		microscenario_error = _playable_recovery_error


func _restore_failed_playable_selection(request: Dictionary) -> void:
	# One attempt through the normal admission/receipt path. Failure stays
	# visible and paused; do not retry, coerce policy or resume automatically.
	var selection: Dictionary = request.selection
	if _apply_microscenario_definition(request.definition, request.mode,
		_playable_actor_configuration(StringName(str(selection.actor))), request.policy, request.setup):
		pending_microscenario_apply.playable_options = {"controls":str(selection.controls),
			"rules":str(selection.rules), "camera":str(selection.camera)}
	playable_session_panel.show_selection()


func _playable_actor_configuration(rig: StringName) -> Dictionary:
	return {"representation":"barrel-rapier", "runtime_recovery_enabled":false,
		"experimental":true, "physical_trial":"", "physical_rig":str(rig),
		"actor_model":"", "actor_producer":"human", "actor_demo_npcs":false, "actor_definitions":[]}


# One composed request, through the existing prepared native/physical transaction.
# Options remain candidate data until the matching worker acknowledgement.
func apply_playable_session(selection: Dictionary, policy: PackedInt32Array,
		normalize_water: bool = false, maximum_rule_radius: int = 2) -> bool:
	microscenario_error = playable_session_unavailable_reason()
	if not microscenario_error.is_empty(): return false
	var rig := StringName(str(selection.get("actor", "")))
	if selection.get("map", "") != CyberMicroScenarioCatalogue.PLAYER_COURSE_ID \
		or rig not in PlayerCourse.MECHANICAL_PRESETS \
		or selection.get("controls", "") not in ["keyboard_gamepad", "keyboard"] \
		or selection.get("rules", "") not in ["lap", "freeplay"] \
		or selection.get("camera", "") not in ["follow", "overview"]:
		microscenario_error = "Unsupported playable-session selection; current session retained."
		return false
	var configuration: Dictionary = _playable_actor_configuration(rig)
	var definition: Dictionary = CyberMicroScenarioCatalogue.definition(CyberMicroScenarioCatalogue.PLAYER_COURSE_ID, 0)
	if not microscenario_apply_exploratory_liquid(definition, policy, normalize_water, "Play",
		configuration, maximum_rule_radius):
		return false
	pending_microscenario_apply.playable_options = {"controls":str(selection.controls),
		"rules":str(selection.rules), "camera":str(selection.camera)}
	return true

# The workbench owns a finite authored recipe and configuration. Preparation,
# acknowledgement, World stepping and Rapier adoption remain the shared owners'.
func workbench_apply(candidate: Dictionary, actors: Array, rectangles: Array, extent: Vector2i,
		policy: PackedInt32Array, normalize_water: bool, radius: int, response: String,
		preserve_cells: bool = false, convert_liquid_inventory: bool = false, resume_play: bool = false,
		generated_packet: Dictionary = {}, material_baseline: Dictionary = {},
		apply_staged_water: bool = true, authoring_patch: Dictionary = {}) -> bool:
	if shared_workbench == null: return false
	if not authoring_patch.is_empty() and (not paused or not preserve_cells or convert_liquid_inventory \
			or not generated_packet.is_empty() or not material_baseline.is_empty() or apply_staged_water):
		microscenario_error = "Construction patch requires a paused retained World and unchanged settings."
		return false
	if not pending_microscenario_apply.is_empty():
		microscenario_error = "Wait for the pending workbench installation."
		return false
	if simulation_worker.has_failed():
		microscenario_error = "The cellular owner stopped. Reset or restore to rebuild from the starting setup."
		return false
	if response not in ["LA-SELECTIVE","LA","LA-EVENT-OFF","RFT"]:
		microscenario_error = "Unknown workbench response"
		return false
	var definition := CyberMicroScenarioContract.base(CyberMicroScenarioContract.WORKBENCH_ID)
	definition.schema_version = 2
	definition["extent"] = [extent.x,extent.y]
	definition.rectangles = rectangles
	definition["presentation"] = {"title":"Development workbench","instructions":"Build a starting setup",
		"duration_ticks":1,"baseline":"workbench","profile":"blank-canvas","regions":[]}
	definition.tools = ["paint","erase"]
	definition.interest = {"policy":"fixed","region":[0,0,extent.x,extent.y]}
	definition.execution.cadence_lod_enabled = false
	var config := {"actor_model":"","physical_rig":"workbench" if not actors.is_empty() else "",
		"actor_producer":"human","representation":"barrel-rapier" if not actors.is_empty() else "sampled",
		"workbench_actors":actors}
	# Saved normalization belongs to the starting recipe. A retained flyer
	# edit must not round live Water because an earlier recipe used it.
	if (not generated_packet.is_empty() or not material_baseline.is_empty()) and (preserve_cells or not rectangles.is_empty()) \
			or (not generated_packet.is_empty() and not material_baseline.is_empty()):
		microscenario_error = "A standalone terrain baseline requires one empty fresh construction recipe."
		return false
	var normalize_now := normalize_water and (not preserve_cells or convert_liquid_inventory)
	var settings := {"intent":"exploratory","normalization":"water-normalize-v1" if normalize_now else "",
		"maximum_rule_radius":radius,"workbench_response":response,"workbench_retain_cells":preserve_cells,
		"workbench_sample":{"session":_microscenario_request_serial+1,"epoch":_physical_epoch+1,
			"states":PackedFloat64Array(),"geometry":PackedFloat64Array(),"bodies":[],"emitters":[]}}
	# The copied native proposal belongs to preparation only; it is not a
	# second World, and never enters the saved v2 starting-setup schema.
	if not generated_packet.is_empty():
		settings["workbench_generated"] = generated_packet
	if not material_baseline.is_empty():
		settings["workbench_material_baseline"] = material_baseline
	if not authoring_patch.is_empty():
		settings["workbench_authoring_patch"] = authoring_patch.duplicate(true)
	# Editing a body or restoring the current authored start must not apply
	# unfinished Water controls. Only explicit Apply/Load promotes that proposal;
	# the accepted setup is recorded after native preparation and commit succeed.
	var water_options: Dictionary = (workbench_water_options if apply_staged_water or shared_workbench.applied.is_empty()
		else microscenario_liquid_setup)
	# Preserve present values until native validation. Silently dropping a wrong
	# type would falsely report that a different/default configuration applied.
	for key: String in ["workbench_ballistic","workbench_inertial_signed","workbench_face_release","workbench_fine_cores","workbench_wave_flow"]:
		if water_options.has(key):
			if not water_options[key] is bool:
				microscenario_error = key+" must be boolean; the running World is unchanged."
				return false
			settings[key] = water_options[key]
	if water_options.has("workbench_worker_threads"):
		settings["workbench_worker_threads"] = water_options.workbench_worker_threads
	# A fresh authored setup may explicitly assign Water to another family.
	# Its selected law wins on load. Validate retained/live Apply as requested.
	var wave_requested := bool(settings.get("workbench_wave_flow",false))
	var check_authored_law := not preserve_cells and apply_staged_water and wave_requested
	var has_pressure_capacity := water_options.has("pressure_gas_compartment_capacity")
	var water_family := ""
	if check_authored_law or (not wave_requested and has_pressure_capacity):
		var checked: Dictionary = shared_workbench._liquids.bridge.validate_liquid_policy(policy)
		# A refused policy has no receipt. Native preparation publishes its refusal.
		if checked.accepted:
			for assignment: Dictionary in checked.receipt.assignments:
				if int(assignment.material) == CyberCellWorld.WATER:
					water_family = str(assignment.applied_family)
					break
	var adopt_authored_law := check_authored_law and not water_family.is_empty() and water_family != "freemass_v1"
	if adopt_authored_law: settings.workbench_wave_flow = false
	# C2048 belongs to PressureFlow. Keep its staged value for comparison, but
	# every other law uses the ordinary non-pressure construction capacity.
	if has_pressure_capacity and water_family == "pressure_flow_v1":
		settings["pressure_gas_compartment_capacity"] = water_options.pressure_gas_compartment_capacity
	if settings.get("workbench_face_release",false) and settings.get("workbench_ballistic",false):
		for key: String in FACE_TUNING:
			if water_options.has(key): settings[key] = water_options[key]
	if settings.get("workbench_wave_flow",false):
		for key: String in WAVE_TUNING:
			if water_options.has(key): settings[key] = water_options[key]
		# Spill belongs to Wave only. A staged spill request is never sent to
		# another law, and its tuning only accompanies an enabled spill.
		for key: String in WAVE_SPILL_SWITCHES:
			if water_options.has(key):
				if not water_options[key] is bool:
					microscenario_error = key+" must be boolean; the running World is unchanged."
					return false
				settings[key] = water_options[key]
		if settings.get("workbench_wave_spill",false):
			for key: String in WAVE_SPILL_TUNING:
				if water_options.has(key): settings[key] = water_options[key]
	# Lossy conversion belongs only to an explicit developer policy switch.
	# Ordinary replacements (including Apply of an unchanged policy) keep
	# all compatible native inventory and use the normal refusal contract.
	if convert_liquid_inventory and preserve_cells:
		var applied: Dictionary = tower_context.get("liquid_solver_policy",{})
		if applied.has("envelope") and PackedInt32Array(applied.envelope) != policy:
			settings.workbench_convert_liquid_inventory = true
	cancel_playable_course_input()
	if not _apply_microscenario_definition(definition,"Play",config,policy,settings): return false
	pending_microscenario_apply.workbench = candidate.duplicate(true)
	pending_microscenario_apply.workbench_resume = resume_play
	pending_microscenario_apply.workbench_adopt_authored_law = adopt_authored_law
	return true

func _apply_microscenario_definition(definition: Dictionary, mode: String, actor_configuration: Dictionary = {},
		liquid_policy: Variant = null, controlled_setup: Dictionary = {}, retain_trial_motion: bool = false) -> bool:
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
		definition.player_enabled = not definition.body_enabled and definition.id != CyberMicroScenarioContract.WORKBENCH_ID
	var checked: Dictionary = CyberMicroScenarioContract.validate(definition)
	if not checked.get("ok", false) or not mode in CyberMicroScenarioContract.MODES:
		microscenario_error = str(checked.get("error", "Invalid mode"))
		return false
	var player_configuration: Dictionary = (selected_actor.duplicate(true)
		if exploratory and not selected_actor.is_empty()
		else _player_configuration_for_microscenario(checked.definition))
	if player_configuration.is_empty(): return false
	if not controlled_setup.is_empty():
		var prepared_exploratory: bool = controlled_setup.get("intent", "controlled") == "exploratory"
		var articulated: bool = prepared_exploratory and exploratory \
			and not str(player_configuration.get("physical_rig", "")).is_empty()
		var trial: bool = prepared_exploratory and exploratory \
			and str(player_configuration.get("physical_trial","")) in ["barrel","ripper"]
		if int(checked.definition.schema_version) != 2 or (checked.definition.body_enabled and not (articulated or trial)):
			microscenario_error = "Prepared liquid setup requires schema 2; this body route is not staged"
			return false
		if (not prepared_exploratory and (checked.definition.player_enabled
			or checked.definition.execution.policy != "fixed" or checked.definition.interest.policy != "fixed")):
			microscenario_error = "Controlled liquid setup requires a fixed actor-free MicroScenario"
			return false
	var prepared_physical: bool = not controlled_setup.is_empty() \
		and (not str(player_configuration.get("physical_rig", "")).is_empty() \
			or str(player_configuration.get("physical_trial","")) in ["barrel","ripper"])
	if not controlled_setup.is_empty() and player_configuration.get("representation", "sampled") == "barrel-rapier":
		if not prepared_physical or not exploratory or mode == "Benchmark" \
			or controlled_setup.get("intent","controlled") != "exploratory":
			microscenario_error = "This prepared physical route is unavailable; current session retained"
			return false
	if prepared_physical:
		var trial: String=str(player_configuration.get("physical_trial",""))
		var staged: RefCounted
		if trial in ["barrel","ripper"]:
			staged=_prepare_trial_candidate(trial,Vector2(checked.definition.player_start[0],checked.definition.player_start[1]),retain_trial_motion)
			if staged==null: return false
		else:
			staged = _prepared_physical_factory.call() if _prepared_physical_factory.is_valid() else PreparedPhysical.new()
			var definitions: Array = physical_actor_definitions(StringName(str(player_configuration.physical_rig)),
				StringName(str(player_configuration.get("actor_producer","human"))),
				bool(player_configuration.get("actor_demo_npcs",false)),
				Vector2(checked.definition.player_start[0],checked.definition.player_start[1]),
				str(checked.definition.id))
			if checked.definition.id == CyberMicroScenarioContract.WORKBENCH_ID:
				definitions = player_configuration.workbench_actors
			if not staged.prepare(self,definitions,_physical_epoch+1):
				microscenario_error = staged.last_error;staged.close();return false
		# Signal connection and all rig/equipment/space construction precede the
		# native preparation. The exact same graph survives successful adoption.
		if staged.owner_kind()=="articulated": staged.session.input_cancelled.connect(_on_physical_actor_input_cancelled)
		_pending_physical_candidate = staged
		_prepared_physical_identity = {};_prepared_physical_ready_sent = false
		controlled_setup = controlled_setup.duplicate(true)
		controlled_setup.physical_owner = {"epoch":_physical_epoch+1,"instance_id":staged.get_instance_id(),
			"initial_bodies":staged.initial_body_states()}
		if checked.definition.id == CyberMicroScenarioContract.WORKBENCH_ID:
			controlled_setup.workbench_sample = staged.initial_workbench_sample()
		if trial in ["barrel","ripper"]:
			controlled_setup.physical_owner.kind="trial_body";controlled_setup.physical_owner.trial_arm=trial
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
		"retain_trial_input":prepared_physical and retain_trial_motion and physical_trial_arm in ["barrel","ripper"],
		"trial_source":_trial_source_binding() if prepared_physical and retain_trial_motion and physical_trial_arm in ["barrel","ripper"] else {},
	}
	microscenario_mode = mode
	paused = true
	# A fallible Workbench preparation can pause and roll back between physics
	# callbacks. Retire the retained producers synchronously with worker pause;
	# preserve their bodies/resources and renew authority if adoption refuses.
	if shared_workbench != null and physical_actor_session != null:
		physical_actor_session.set_suspended(true)
	var requested_representation := StringName(
		str(player_configuration.get("representation", "sampled"))
	)
	tower_command({
		"scenario_reset":checked.definition,
		"scenario_request_serial":_microscenario_request_serial,
		"scenario_mode":mode,
		"sampled_character_enabled":(
			(controlled_setup.is_empty() or controlled_setup.get("intent", "controlled") == "exploratory")
			and checked.definition.id != CyberMicroScenarioContract.WORKBENCH_ID
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
	var retained_input: RefCounted=physical_trial_input
	_apply_microscenario_player_configuration(definition, player_configuration)
	if pending_microscenario_apply.get("retain_trial_input",false): physical_trial_input=retained_input
	microscenario_definition = definition.duplicate(true)
	microscenario_liquid_policy = pending_microscenario_apply.get("liquid_policy", null)
	microscenario_liquid_setup = pending_microscenario_apply.get("controlled_liquid_setup", {}).duplicate(true)
	microscenario_liquid_setup.erase("physical_owner")
	tower_active = true
	paused = true
	# Preserve the original course's 256x128 close actor view and its
	# optional 512x256 overview. Other MicroScenarios keep their 480x270 view.
	var mechanical_course_view: bool = (str(definition.get("id","")) == CyberMicroScenarioCatalogue.PLAYER_COURSE_ID
		and StringName(str(player_configuration.get("physical_rig",""))) in PlayerCourse.MECHANICAL_PRESETS)
	if mechanical_course_view:
		playable_session_options = pending_microscenario_apply.get("playable_options", playable_session_options).duplicate(true)
	else:
		playable_session_options = DEFAULT_PLAYABLE_OPTIONS.duplicate()
	current_view_size = Vector2i(256,128) if mechanical_course_view else Vector2i(480,270)
	camera_follow_enabled = mechanical_course_view
	camera_origin = Vector2(definition.camera_origin[0], definition.camera_origin[1])
	if mechanical_course_view and playable_session_options.camera == "overview":
		current_view_size = PlayerCourse.VIEW.size
		camera_follow_enabled = false
		camera_origin = Vector2(PlayerCourse.VIEW.position)
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
	if shared_workbench != null and pending_microscenario_apply.has("workbench"):
		_workbench_wait_sample = -1
		_workbench_frame_error = ""
		var extent := Vector2i(definition.extent[0],definition.extent[1])
		if world_extent != extent:
			world_extent = extent
			image = Image.create_empty(extent.x,extent.y,false,render_image_format)
			create_render_textures()
			world_view.texture = texture
			configure_material_textures(world_shader)
		shared_workbench.installed(pending_microscenario_apply.workbench)
	elif showcase_presentation != null:
		showcase_presentation.installed(definition)
	if shared_workbench == null and blacksite_nine_presentation != null:
		blacksite_nine_presentation.installed(definition)
	if not microscenario_liquid_setup.is_empty():
		simulation_worker.acknowledge_prepared_liquid_configuration(int(pending_microscenario_apply.get("serial",0)))

func microscenario_reset() -> void:
	if playable_session_can_recover():
		_queue_failed_playable_restart()
		return
	if _playable_recovery_queued or _playable_recovery_cancelled: return
	if not pending_microscenario_apply.is_empty() or not pending_water_apply.is_empty(): return
	if tower_context.get("micro_active", false):
		if not microscenario_liquid_setup.is_empty() and microscenario_liquid_policy != null:
			if microscenario_liquid_setup.get("intent", "controlled") == "exploratory":
				_apply_microscenario_definition(microscenario_definition,microscenario_mode,{},microscenario_liquid_policy,microscenario_liquid_setup.duplicate(true))
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
	if shared_workbench != null: return
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
			"lockstep_coupling_enabled": lockstep_coupling_enabled,
			"view_size": [current_view_size.x, current_view_size.y],
			"simulation_margin": [simulation_margin.x, simulation_margin.y],
			"requested_native_worker_threads": int(
				ProjectSettings.get_setting("cybersand/native_worker_threads", 0)
			),
			"player_environment_profile": active_player_environment_profile.duplicate(true),
		},
	}


func recording_configuration() -> Dictionary:
	# Enclose the displayed view, including partially visible edge cells. The
	# requested camera can differ from this origin after display-pixel rounding.
	var presented: Vector2 = presentation_camera_origin()
	var extent: Vector2i = world_extent.max(Vector2i.ZERO)
	var start: Vector2i = Vector2i(floori(presented.x), floori(presented.y)).clamp(
		Vector2i.ZERO, extent
	)
	# Add scalar components before ceil so a float32 Vector2 sum cannot erase a
	# small fractional remainder at the far edge.
	var end: Vector2i = Vector2i(
		ceili(presented.x + float(current_view_size.x)),
		ceili(presented.y + float(current_view_size.y))
	).clamp(Vector2i.ZERO, extent)
	var roi: Rect2i = Rect2i(start, (end - start).max(Vector2i.ZERO))
	var result: Dictionary = {
		"capture_hz": DEFAULT_RECORDING_HZ,
		"queue_capacity": DEFAULT_RECORDING_QUEUE_CAPACITY,
		"roi": roi,
		"world_extent": world_extent,
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
	if recording_button == null or (shared_workbench != null and not recording_button.is_visible_in_tree()):
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
var worker_publication_counter = SnapshotPublicationCounter.new()

# Opt-in coupled lockstep (owner decision 2026-11-06; COUPLING-LOCKSTEP-001).
# Default off; enabled only by the --lockstep-coupling launch argument on
# desktop. Rapier step N then applies exactly the native result that consumed
# main's previous body publication. Main holds by skipping physics frames, never
# by blocking; a hold longer than the limit steps without a fresh result and is
# counted, so a stall becomes slow motion or a counted stale step, never a freeze.
const LOCKSTEP_MAIN_HOLD_LIMIT_MSEC: int = 500
var lockstep_coupling_enabled: bool = false
var _lockstep_published: int = 0
var _lockstep_applied_serial: int = -1
var _lockstep_applied_publication: int = -1
var _lockstep_applied_tick: int = -1
var _lockstep_hold_started_msec: int = -1
var _lockstep_hold_frame: int = -1 # Physics frame of the last fence decision.
var _lockstep_publication_refused: bool = false # Last body publication did not advance.
var lockstep_main_held_frames: int = 0
var lockstep_main_hold_timeouts: int = 0
var lockstep_main_fenced_steps: int = 0
var lockstep_main_unfenced_steps: int = 0

var image: Image
var texture: Texture2D
var previous_texture: Texture2D
var _material_blit_publisher: MaterialPublisher
var _material_full_ring: FullImageRingPublisher
var _material_publication_mode: String = ""
var _material_publication_fallback: String = ""
var _material_publication_last: Dictionary = {}
var _material_pending_rectangles := PackedInt32Array()
var _material_image_patch_usec: int = 0
var _check_ambient_sources := OS.get_environment("CYBERSAND_WORKBENCH_EMPTY_EFFECTS") == "1"
var _ambient_sources_absent := false
var _vapour_history_possible := false

var material_appearance_lut: ImageTexture
var material_appearance_program: ImageTexture
var render_channels: int = 1
var render_image_format: Image.Format = Image.FORMAT_R8
var _uploaded_workbench_frame: Dictionary = {}
var _material_deadline = MaterialPublicationDeadline.new()
var _material_deadline_hz: int = MaterialPublicationDeadline.requested_hz(
	OS.get_environment("CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ"))
var _material_steps = MaterialPublicationSteps.new()
var _material_step_interval: int = MaterialPublicationSteps.requested_interval(
	OS.get_environment("CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL"))
var _material_step_uploads_after_cancellation: int = 0
# Changed-pixel old occupancy from the *previous* GPU texture, sampled before
# accepting each patch. Only consulted while palette snapshot_blend < 1.
# An oversized/full refresh is unknown rather than optimistically empty.
const PRESENTATION_PREVIOUS_PATCH_LIMIT: int = 16384
# Render-only guard work is capped globally across all Workbench bodies.
# Reaching a budget holds a certified selected pose or withholds that part;
# it never rewinds to an older receipt or displays unchecked geometry.
const PRESENTATION_FRAME_SCAN_BUDGET: int = 24000
const PRESENTATION_FRAME_TIME_BUDGET_USEC: int = 2000
var _presentation_previous_occupied: Dictionary = {}
var _presentation_previous_unknown: bool = true
# Exact CPU counterpart of previous_world_texture. One World-sized image,
# retained before mutation, replaces the old global 'unknown after 16K cells'
# shortcut. Swept queries still obey their existing local scan/time bounds.
var _presentation_previous_image: Image
# Immutable byte copies are taken once per upload, never once per actor query.
# They follow the same current/previous GPU texture swap as the Image history.
var _presentation_current_bytes := PackedByteArray()
var _presentation_previous_bytes := PackedByteArray()
# An upload serial or GPU slot is not a material-content identity. These IDs
# follow exact byte values (including size/format) through the two GPU slots.
# IDs are never recycled; comparisons happen once per upload, not per actor.
var _presentation_content_serial: int = 0
var _presentation_current_content_id: int = 0
var _presentation_previous_content_id: int = 0
var _presentation_current_content_shape := Vector3i.ZERO
var _presentation_previous_content_shape := Vector3i.ZERO
var _presentation_upload_cache_usec: int = 0
var _presentation_pending_cache_usec: int = 0
var _presentation_pending_clearance_cells: int = 0
var _workbench_dry_region: Dictionary = {}
var _workbench_dry_region_status: String = "none"
var workbench_presentation_last: Dictionary = {}
var workbench_presentation_totals: Dictionary = {
	"frames":0,"safe_live":0,"blocked_material":0,"blocked_unknown":0,
	"blocked_other":0,"budget_vetoes":0,"cells_examined":0,"elapsed_usec":0}
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
var material_presentation_timeline = WorkbenchMaterialTimeline.new()
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
var _playable_course_progress = PlayableCourseLap.new()
var _playable_course_observation_valid: bool = false
var _participation_sampling_requested: bool = false
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
var rapier_bridge: CyberRapierPhysicsBridge = CyberRapierPhysicsBridge.new():
	set(value):
		# Every adopted bridge (sandbox, actor, prepared or replacement) packs
		# rotations in the launch mode, so all its pack_body_states() callers agree.
		rapier_bridge = value
		if value != null:
			value.deterministic_rotation_packing = lockstep_coupling_enabled
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
	if not player_environment_panel.visible:
		cancel_playable_course_input()
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
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),true,null,resolved.profile,{},false):
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
	if _flight_pacing:
		simulation_worker.workbench_sample_completed.connect(_service_held_flight_callback, CONNECT_DEFERRED)
		RenderingServer.frame_post_draw.connect(_service_held_flight_callback)
	if get_tree().get_meta("cybersand_feature","") == "shared_workbench" \
			and not OS.get_environment("CYBERSAND_PLAYABILITY_OWNER_RECEIPT").is_empty():
		var recorder := OwnerGameplay.new()
		if recorder.start(get_instance_id()):
			_owner_gameplay = recorder
			RenderingServer.frame_post_draw.connect(_owner_gameplay.draw)
	if _workbench_submission_requested:
		if WorkbenchPresentationSubmission.atomic_admission_supported():
			if WorkbenchPresentationSubmission.revision_is_valid(OS.get_environment("CYBERSAND_SOURCE_REVISION")):
				_workbench_submission = WorkbenchPresentationSubmission.new()
				_workbench_submission.bind(self)
				add_child(_workbench_submission)
				RenderingServer.frame_pre_draw.connect(_commit_workbench_presentation_submission)
			else:
				# Refuse an unidentifiable experiment before publishing an enabled
				# handshake. Ordinary Workbench/error UI must remain drawable.
				_workbench_submission_refusal = "source_identity_invalid"
		else:
			_workbench_submission_refusal = "engine_atomic_admission_unavailable"
	_material_deadline.configure(_material_deadline_hz)
	_configure_material_steps()
	world_shader.shader = CyberPaletteShader.for_current_renderer(world_shader.shader)
	# Consume before any early return, so a later unrelated scene cannot inherit
	# an abandoned recovery. SceneTree retires old Main/_exit_tree before this
	# fresh scene's _ready starts its worker. The envelope contains copied values.
	var recovery: Dictionary = get_tree().get_meta(PLAYABLE_RECOVERY_META, {})
	if get_tree().has_meta(PLAYABLE_RECOVERY_META): get_tree().remove_meta(PLAYABLE_RECOVERY_META)
	if recovery.has("workbench_water_options"):
		workbench_water_options = recovery.workbench_water_options.duplicate(true)
	elif get_tree().get_meta("cybersand_feature","") == "shared_workbench" and ClassDB.class_exists(&"CyberNativeCellWorld"):
		# Recovery envelopes and caller-supplied Water selections already describe
		# a World. Only a new Workbench receives the current gameplay bundle.
		if not workbench_water_options.has("workbench_wave_flow"):
			var defaults: Dictionary = ClassDB.class_call_static(&"CyberNativeCellWorld",&"gameplay_water_options")
			defaults.merge(workbench_water_options,true)
			if defaults.get("workbench_ballistic") == false or defaults.get("workbench_wave_spill") == false:
				defaults.workbench_wave_spill_parcels = false
			if defaults.get("workbench_wave_spill") == false:
				defaults.workbench_wave_spill_full_face = false
			if defaults.get("workbench_face_release") == true or defaults.get("workbench_inertial_signed") == true:
				defaults.workbench_wave_flow = false
			workbench_water_options = defaults
	if not recovery.is_empty() or get_tree().get_meta("cybersand_feature","") == "shared_workbench": paused = true
	if OS.get_cmdline_user_args().has("--depth-lab") and not get_tree().has_meta("cybersand_depth_lab_visited"):
		set_process(false)
		call_deferred("open_depth_lab")
		return
	setup_tower_panel()
	setup_brush_preview()
	setup_player_representation_button()
	setup_player_environment_tuning()
	if recovery.has("settings"):
		var settings: Dictionary = recovery.settings
		simulation_window_enabled = bool(settings.simulation_window_enabled)
		cadence_lod_enabled = bool(settings.cadence_lod_enabled)
		liquid_surface_adhesion_enabled = bool(settings.liquid_surface_adhesion_enabled)
		simulation_margin_index = int(settings.simulation_margin_index)
		simulation_margin = settings.simulation_margin
		render_snapshot_hz_index = int(settings.render_snapshot_hz_index)
		render_snapshot_hz = int(settings.render_snapshot_hz)
		active_player_environment_profile = settings.player_environment_profile.duplicate(true)
		simulation_worker.queue_player_environment_profile(active_player_environment_profile)
		player_environment_panel.set_active(active_player_environment_profile)
	setup_depth_lab_launcher()
	setup_actor_prototypes()
	setup_playable_session_panel()
	get_viewport().gui_focus_changed.connect(_on_playable_course_gui_focus_changed)
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
	# Pacing is fixed before the worker starts; the worker refuses later changes.
	lockstep_coupling_enabled = (lockstep_coupling_requested()
		and simulation_worker.set_lockstep_coupling(true))
	rapier_bridge.deterministic_rotation_packing = lockstep_coupling_enabled
	update_worker_frame_state()
	_publish_physical_body_state()
	simulation_worker.set_render_snapshot_hz(render_snapshot_hz)
	worker_start_error = simulation_worker.start_worker(CHARACTER_SPAWN)
	if worker_start_error != OK:
		for body: RigidBody2D in rigid_bodies:
			body.freeze = true
	latest_snapshot = simulation_worker.take_latest_snapshot(-1)
	if latest_snapshot != null:
		worker_publication_counter.observe(latest_snapshot.serial)
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
		world_extent.x * world_extent.y * render_channels
	)
	image = Image.create_from_data(
		world_extent.x,
		world_extent.y,
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
	create_render_textures()
	material_appearance_lut = CyberMaterialAppearanceLut.create_texture()
	material_appearance_program = CyberMaterialAppearanceLut.create_program_texture()
	world_view.texture = texture
	configure_material_textures(world_shader)
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
	if recovery.has("selection"):
		_restore_failed_playable_selection.call_deferred(recovery)
		return
	var feature: String = str(get_tree().get_meta("cybersand_feature", ""))
	if feature == "shared_workbench":
		shared_workbench = load("res://scripts/shared_workbench.gd").new()
		shared_workbench.setup(self,recovery.get("workbench",{}))
		# These legacy launchers are normally hidden behind the Workbench. If a
		# caller reveals either, refresh its text and enabled state immediately.
		actor_prototype_button.visibility_changed.connect(refresh_actor_prototypes)
		recording_button.visibility_changed.connect(_refresh_recording_button)
	elif PhysicalTrial.contains(feature):
		microscenario_launch.call_deferred(feature, "Play", 0)
	elif feature == "blacksite":
		blacksite_nine_presentation.launch.call_deferred()
	elif feature == "showcase":
		showcase_presentation.launch.call_deferred()
	elif feature == "actors":
		toggle_actor_prototypes.call_deferred()
	elif feature == "liquid_comparison":
		microscenario_panel.open_liquids.call_deferred(true)
	elif feature == "play_session":
		playable_session_panel.show_selection.call_deferred()
	elif feature.is_empty() and "--blacksite-nine" in OS.get_cmdline_user_args():
		blacksite_nine_presentation.launch.call_deferred()
	elif feature.is_empty() and "--showcase" in OS.get_cmdline_user_args():
		showcase_presentation.launch.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# A loss/regain between physics callbacks must still retire old edges.
		cancel_playable_course_input()


func _exit_tree() -> void:
	if _owner_gameplay != null:
		RenderingServer.frame_post_draw.disconnect(_owner_gameplay.draw)
		_owner_gameplay.close()
		_owner_gameplay = null
	_workbench_submission_notification_pending = false
	if _workbench_submission != null: _workbench_submission.close()
	_material_deadline.cancel("exit_tree")
	_material_steps.cancel("exit_tree")
	if workbench_pose_trace.active:
		var saved: Dictionary = finish_workbench_pose_trace()
		print("WORKBENCH_POSE_TRACE_EXIT ",JSON.stringify(saved))
	if gameplay_recorder.is_active():
		var stopped: Dictionary = gameplay_recorder.stop_recording()
		print("REC-001 recording finalized at exit: ", JSON.stringify(stopped))
	_close_pending_physical_candidate()
	_close_prepared_reference_bodies()
	_close_physical_actors()
	simulation_worker.stop_worker()
	rapier_bridge.shutdown()


var _publication_detail_trace: bool = OS.get_environment("CYBERSAND_DIAG_COMMON_OBSERVER") != "1"
var _launcher_ready_receipt: String = OS.get_environment("CYBERSAND_LAUNCH_READY_RECEIPT")
var _launcher_ready_frames: int = 0

func _process(delta: float) -> void:
	var callback_started_usec: int = Time.get_ticks_usec() if workbench_pose_trace.active and _publication_detail_trace else 0
	var causal_started_usec: int = Time.get_ticks_usec() if _pubpres_trace_enabled else 0
	if _pubpres_trace_enabled:
		_pubpres_packet_observed("main_process_entry", causal_started_usec, null, {})
	if _flight_pacing: _service_held_flight_callback()
	if _workbench_same_frame_enabled: _try_same_frame_continuation()
	_workbench_mapping_locked = false
	_engine_lab_pump_ack()
	if shared_workbench == null:
		_refresh_microscenario_controls()
	frame_time_ms = delta * 1000.0
	maximum_frame_time_ms = maxf(maximum_frame_time_ms, frame_time_ms)
	# Drain an already admitted collider packet before uploading material. The
	# physics callback still requires the matching complete terrain revision.
	if shared_workbench != null and physical_actor_session != null \
			and _actor_reset_receipt == 0 and _pending_physical_candidate == null \
			and pending_microscenario_apply.is_empty() \
			and rapier_bridge.pending_hard_surface_chunks() > 0:
		if _pubpres_trace_enabled:
			_pubpres_terrain_budget(32, 1000, "process", null)
		else:
			rapier_bridge.process_hard_surface_collider_budget(32, 1000)
	var material_started_usec: int = Time.get_ticks_usec() if _pubpres_trace_enabled else 0
	consume_worker_snapshot()
	# A paused World may publish no newer mailbox. An already offered material
	# packet still drains at its fixed deadline on every ordinary process turn.
	_drain_material_deadline()
	_drain_material_steps()
	if _pubpres_trace_enabled:
		_pubpres_packet_observed("material_consumption", material_started_usec, latest_snapshot,
			{"uploaded_serial":last_uploaded_render_snapshot_serial, "ack_serial":_engine_lab_last_ack_serial})
	if _flight_pacing: _service_held_flight_callback()
	_advance_prepared_physical_candidate()
	if shared_workbench != null and physical_actor_session != null:
		physical_actor_session.ingest_ambient_snapshot(latest_snapshot)
		if physical_actor_session.take_ambient_refresh_request(): simulation_worker.request_render_full_refresh()
	if _pending_physical_candidate == null and shared_workbench == null: refresh_actor_usables()
	gameplay_recorder.poll_finalization()
	_refresh_recording_button()
	sync_player_presentation_position()
	_update_playable_course_progress()
	refresh_player_representation_button()
	if shared_workbench == null or physical_actor_session == null:
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
	if not workbench_presentation_submission_enabled():
		if shared_workbench != null:
			_resolve_workbench_presentation_frame(workbench_display_frame())
		update_camera(delta)
		if shared_workbench != null:
			_resolve_workbench_camera_mapping()
	if shared_workbench == null:
		tower_panel.refresh(tower_active,tower_floor,tower_context)
	update_brush_preview()
	handle_painting()
	_present_playable_course_targets()
	actor_prototype_overlay.present(
		latest_snapshot.actor_prototypes if latest_snapshot != null else {},
		presentation_camera_origin(), current_view_size, view_content_rect()
	)
	usable_overlay.present(
		(latest_snapshot.physical_usables if physical_actor_session != null else latest_snapshot.actor_usables) if latest_snapshot != null else {},
		presentation_camera_origin(), current_view_size, view_content_rect()
	)
	if not workbench_presentation_submission_enabled():
		if shared_workbench != null:
			_submit_workbench_presentation_frame()
		else:
			_present_physical_actor_overlay({})
	if _flight_pacing: _service_held_flight_callback()
	update_worker_frame_state()
	if not workbench_presentation_submission_enabled(): update_shader_parameters()
	_workbench_mapping_locked = false

	status_accumulator += delta
	if status_accumulator >= STATUS_INTERVAL:
		status_accumulator = 0.0
		update_status()
		refresh_actor_prototypes()
		maximum_frame_time_ms = frame_time_ms
		maximum_collider_time_ms = 0.0
	if callback_started_usec > 0 and workbench_pose_trace.active:
		workbench_pose_trace.observe_event({"event":"main_callback",
			"start_usec":callback_started_usec,"time_usec":Time.get_ticks_usec(),
			"process_frame":Engine.get_process_frames()})
	if not _launcher_ready_receipt.is_empty(): _write_launcher_ready_receipt()
	if _pubpres_trace_enabled:
		_pubpres_packet_observed("main_process_exit", causal_started_usec, null, {})


# Opt-in installed-launcher qualification. Ordinary sessions never enter this
# path. A loaded extension banner alone does not prove Workbench installation.
func _write_launcher_ready_receipt() -> void:
	if shared_workbench == null or shared_workbench.applied.is_empty() \
		or not pending_microscenario_apply.is_empty() or _pending_physical_candidate != null \
		or worker_start_error != OK or rapier_start_error != OK \
		or latest_snapshot == null or latest_snapshot.simulation_failed \
		or last_uploaded_revision < 0 or last_uploaded_world_generation < 0 \
		or last_uploaded_world_generation != latest_snapshot.render_world_generation \
		or rapier_bridge.pending_hard_surface_chunks() != 0:
		_launcher_ready_frames = 0
		return
	# A freshly installed blank Workbench deliberately retires its unused
	# reference-body bridge. Authored actors still require the adopted live
	# owner, initialized Rapier space and complete collision terrain.
	var authored_actor_count: int = shared_workbench.applied.get("actors",[]).size()
	var physics_required: bool = authored_actor_count > 0
	if physics_required != (physical_actor_session != null):
		_launcher_ready_frames = 0
		return
	if physics_required and (not rapier_bridge.is_initialized() \
		or _actor_reset_receipt != 0 or not _physical_terrain_ready):
		_launcher_ready_frames = 0
		return
	_launcher_ready_frames += 1
	if _launcher_ready_frames < 2: return
	var receipt := {"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"workbench_installed":true,"world_generation":last_uploaded_world_generation,
		"uploaded_revision":last_uploaded_revision,"snapshot_serial":latest_snapshot.serial,
		"native_tick":latest_snapshot.tick_index,"pending_hard_chunks":0,
		"physics_required":physics_required,"authored_actor_count":authored_actor_count,
		"rapier_initialized":rapier_bridge.is_initialized(),
		"native_rendezvous":native_rendezvous_status(),
		"material_publication":material_publication_status(),
		"physics_publication":simulation_worker.physics_publication_mode()}
	var output := FileAccess.open(_launcher_ready_receipt, FileAccess.WRITE)
	_launcher_ready_receipt = ""
	if output == null:
		push_error("Installed launcher could not write its readiness receipt")
		get_tree().quit(1)
		return
	output.store_string(JSON.stringify(receipt)+"\n")
	output.close()
	print("WORKBENCH_LAUNCH_READY ", JSON.stringify(receipt))
	if OS.get_environment("CYBERSAND_LAUNCH_QUIT_AFTER_READY") == "1": get_tree().quit()


func _physics_process(_delta: float) -> void:
	if _flight_pacing: _service_held_flight_callback()
	if _pubpres_trace_enabled:
		_pubpres_packet_observed("physics_callback_entry", Time.get_ticks_usec(), null,
			{"manual_steps":rapier_bridge.manual_step_count(), "paused":paused})
	if _workbench_same_frame_enabled:
		_workbench_same_frame.begin_callback(Engine.get_process_frames(), Engine.get_physics_frames(), Time.get_ticks_usec())
	if shared_workbench != null and not _workbench_frame_error.is_empty(): return
	if _workbench_native_rendezvous_enabled:
		_workbench_native_rendezvous.begin_callback(Engine.get_process_frames(),
			_workbench_native_rendezvous_selection == "render-overlap")
	if _pending_physical_candidate != null:
		# The retained manually stepped space stays at its actual prior pose.
		# Do not reconfigure its equipment, revoke its leases or publish stale
		# body frames while the separate replacement graph is being prepared.
		_cadence_physics_hold("preparing_actor")
		return
	var single_step: bool = shared_workbench != null and shared_workbench.step_requested and paused
	if physical_actor_session != null:
		physical_actor_session.set_suspended((paused and not single_step) or simulation_worker.has_failed()
			or not _physical_terrain_ready or _actor_reset_receipt != 0
			or not pending_microscenario_apply.is_empty())
	publish_actor_keyboard_input()
	publish_actor_usable_input()
	var physics_snapshot: CyberSimulationSnapshot = latest_snapshot
	if shared_workbench != null and physical_actor_session != null:
		# Physics consumes the bounded native/terrain mailbox before material
		# extraction and upload complete. Terrain, sample and wrench still
		# belong to one immutable owner turn and the ordinary strict fence.
		physics_snapshot = _pubpres_take_physics_snapshot("physics_callback") if _pubpres_trace_enabled \
			else simulation_worker.take_latest_physics_snapshot()
		if physics_snapshot == null or physics_snapshot.simulation_failed or physics_snapshot.rigid_body_epoch != _body_owner_epoch():
			_cadence_physics_hold("missing_failed_or_wrong_epoch",physics_snapshot)
			return
		if not str(physics_snapshot.lab_context.get("workbench_refusal","")).is_empty():
			_cadence_physics_hold("native_refusal",physics_snapshot)
			return
		if not (_pubpres_terrain_installed(physics_snapshot) if _pubpres_trace_enabled else _workbench_terrain_installed(physics_snapshot)):
			_cadence_physics_hold("terrain_installation",physics_snapshot)
			return
		physical_actor_session.ingest_ambient_snapshot(physics_snapshot)
		if paused and not single_step:
			_workbench_wait_sample = -1
			_cadence_physics_hold("paused",physics_snapshot)
			return
		# A single step can restart a previously unpublished paused frame.
		if engine_lab_wait_native_sample and _workbench_wait_sample >= 0 and physics_snapshot.lab_context.get("workbench_completed_sample",-1) != _workbench_wait_sample and not single_step:
			if _workbench_native_rendezvous_enabled and _workbench_native_rendezvous.callback_count > 1 \
					and _actor_reset_receipt == 0 and pending_microscenario_apply.is_empty() \
					and worker_start_error == OK and _physical_terrain_ready:
				var expected := {"sample":_workbench_wait_sample, "epoch":_body_owner_epoch(),
					"world_generation":physics_snapshot.physics_world_generation,
					"session":physical_actor_session.bridge._session}
				var waited: Dictionary = _workbench_native_rendezvous.wait_for_sample(
					_pubpres_try_physics_mailbox if _pubpres_trace_enabled else simulation_worker.try_read_physics_mailbox, expected)
				if workbench_pose_trace.active:
					var event: Dictionary = waited.duplicate()
					event.erase("snapshot")
					event.merge({"event":"native_rendezvous", "time_usec":waited.completed_usec,
						"physics_frame":Engine.get_physics_frames(), "sample":expected.sample,
						"epoch":expected.epoch, "session":expected.session,
						"world_generation":expected.world_generation})
					workbench_pose_trace.observe_event(event)
				if waited.status == "ready":
					physics_snapshot = waited.snapshot
					# No input, scene or physics work ran on another thread. Still
					# repeat every owner/terrain gate after observing a NEW packet.
					if paused or physical_actor_session == null or _pending_physical_candidate != null \
							or _body_owner_epoch() != expected.epoch \
							or physical_actor_session.bridge._session != expected.session \
							or physics_snapshot.simulation_failed \
							or physics_snapshot.rigid_body_epoch != _body_owner_epoch() \
							or physics_snapshot.physics_world_generation != expected.world_generation:
						_cadence_physics_hold("missing_failed_or_wrong_epoch",physics_snapshot)
						return
					if not str(physics_snapshot.lab_context.get("workbench_refusal", "")).is_empty():
						_cadence_physics_hold("native_refusal",physics_snapshot)
						return
					if not (_pubpres_terrain_installed(physics_snapshot) if _pubpres_trace_enabled else _workbench_terrain_installed(physics_snapshot)):
						_cadence_physics_hold("terrain_installation",physics_snapshot)
						return
			if physics_snapshot.lab_context.get("workbench_completed_sample",-1) != _workbench_wait_sample:
				if _flight_pacing: _hold_flight_callback(physics_snapshot)
				if _workbench_same_frame_enabled: _arm_same_frame_continuation(_delta, physics_snapshot)
				_cadence_physics_hold("native_sample",physics_snapshot)
				return
	_complete_physics_callback(_delta, single_step, physics_snapshot)


# The same sole Main owner completes a callback using its original admission
# and manual Rapier transaction. The continuation never calls _physics_process,
# publishes fresh keyboard/usable input, installs terrain or starts rendezvous.
func _complete_physics_callback(_delta: float, single_step: bool,
		physics_snapshot: CyberSimulationSnapshot) -> void:
	if paused or simulation_worker.has_failed():
		physical_trial_input.armed = false
	if simulation_worker.has_failed():
		return
	if (
		rapier_bridge.is_initialized()
		and (not paused or single_step)
		and worker_start_error == OK
		and _actor_reset_receipt == 0
		and pending_microscenario_apply.is_empty()
		and (physical_actor_session == null or _physical_terrain_ready)
	):
		if lockstep_coupling_enabled and shared_workbench == null:
			# Peek (not consume) the newest completion; rendering still takes it in _process.
			var fenced_snapshot: CyberSimulationSnapshot = simulation_worker.take_latest_snapshot(0)
			if fenced_snapshot != null and (not fenced_snapshot.lockstep_fence_active
					or _lockstep_publication_refused):
				# The worker is not fenced here (lab, MicroScenario, prepared liquid),
				# or main's last publication was refused so no completion can consume
				# it: step asynchronously, as the default does, and count it.
				_lockstep_hold_started_msec = -1
				lockstep_main_unfenced_steps += 1
			elif _lockstep_hold(fenced_snapshot):
				return # Skip this physics frame: no step and no new publication.
			elif fenced_snapshot != null:
				physics_snapshot = fenced_snapshot
		var cadence_step_started_usec: int = Time.get_ticks_usec() if workbench_pose_trace.active else 0
		if _pubpres_trace_enabled and shared_workbench != null and physical_actor_session != null:
			_pubpres_packet_observed("transaction_entry", Time.get_ticks_usec(), physics_snapshot,
				{"native_and_terrain_gate_passed":true, "manual_steps_before":rapier_bridge.manual_step_count(),
				"pending_hard_chunks":rapier_bridge.pending_hard_surface_chunks()})
		apply_latest_rigid_body_results(physics_snapshot)
		if _pubpres_trace_enabled and physical_actor_session != null and rapier_bridge is WorkbenchBridge:
			var application: Dictionary = rapier_bridge.last_application
			_pubpres_packet_observed("native_response_application", Time.get_ticks_usec(), physics_snapshot,
				{"accepted":application.get("accepted",false), "refusal":application.get("refusal",""),
				"application_snapshot":application.get("snapshot",-1)})
		if physical_actor_session != null:
			physical_actor_session.advance(rapier_bridge.fixed_delta())
		else:
			apply_barrel_player_control(_delta)
		rapier_bridge.step()
		if physical_actor_session != null:
			var before_completed_tick: int = physical_actor_session.tick
			physical_actor_session.complete_step()
			var cadence_step_completed_usec: int = Time.get_ticks_usec()
			# A gate visited and left between two rendered frames must still
			# count. This callback owns actual completed Rapier observations.
			if physical_actor_session.tick > before_completed_tick:
				_workbench_completed_step = physical_actor_session.tick
				_workbench_completed_step_usec = cadence_step_completed_usec
				if _owner_gameplay != null and rapier_bridge is WorkbenchBridge and physics_snapshot != null:
					_owner_gameplay.physics_step(self,cadence_step_completed_usec,physics_snapshot,single_step)
				_capture_workbench_water_dependencies(physics_snapshot)
				_record_completed_playable_course_step()
				_cadence_rapier_completed(cadence_step_started_usec,cadence_step_completed_usec,physics_snapshot)
	_publish_physical_body_state()
	if _pubpres_trace_enabled:
		_pubpres_packet_observed("transaction_exit", Time.get_ticks_usec(), physics_snapshot,
			{"manual_steps_after":rapier_bridge.manual_step_count(), "next_requested_sample":_workbench_wait_sample})
	if single_step and pending_microscenario_apply.is_empty() and worker_start_error == OK and (physical_actor_session == null or _physical_terrain_ready):
		shared_workbench.step_requested = false
		tower_command({"step":true,"workbench_step_serial":shared_workbench.step_serial})
		if physical_actor_session != null: physical_actor_session.set_suspended(true)

func _hold_flight_callback(snapshot: CyberSimulationSnapshot) -> void:
	_last_flight_sample_hold_usec = Time.get_ticks_usec()
	var identity := _same_frame_identity()
	if identity.is_empty():
		_clear_held_flight()
		return
	# The ordinary keyboard path renews a lease on each callback. Older
	# callbacks can share the renewal only while the actual command and all
	# control generations still match. Never carry old input across a change.
	var commands: Array = physical_actor_session._commands
	var last: Dictionary = _held_flight_ticket.get("identity",{})
	if last.get("sample") != identity.sample or last.get("generations") != identity.generations \
			or _held_flight_ticket.get("commands") != commands:
		_clear_held_flight()
	if _held_flight_times.size() == 4: _held_flight_times.remove_at(0)
	_held_flight_times.append(Time.get_ticks_usec())
	_held_flight_callbacks = _held_flight_times.size()
	_held_flight_ticket = {"identity":identity,"world_generation":snapshot.physics_world_generation,
		"required_revision":snapshot.lab_context.get("workbench_hard_surface_revision",-1),
		"commands":commands.duplicate(true)}


func _clear_held_flight() -> void:
	_held_flight_times.clear()
	_held_flight_callbacks = 0
	_held_flight_ticket = {}


func _service_held_flight_callback() -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or _held_flight_callbacks == 0: return
	var ticket := _held_flight_ticket
	var now := Time.get_ticks_usec()
	while not _held_flight_times.is_empty() and now - _held_flight_times[0] > 100000:
		_held_flight_times.remove_at(0)
	if _held_flight_times.is_empty() or not is_inside_tree() or _same_frame_identity() != ticket.identity:
		_clear_held_flight()
		return
	var result := WorkbenchSameFrameContinuation.validate_mailbox({}, ticket,
		ticket.identity, simulation_worker.try_read_physics_mailbox())
	if result.status != "ready": return
	_held_flight_times.remove_at(0)
	_held_flight_callbacks = _held_flight_times.size()
	_held_flight_ticket = {}
	physical_actor_session.ingest_ambient_snapshot(result.snapshot)
	_complete_physics_callback(rapier_bridge.fixed_delta(), false, result.snapshot)
	_serviced_flight_callbacks += 1
	if _held_flight_callbacks == 0: return
	# Validate each successor against its own sample, lease, epoch and fresh
	# native reply. Every completion returns to the normal event loop.
	var successor := _same_frame_identity()
	if successor.is_empty() or successor.generations != ticket.identity.generations \
			or successor.tick != int(ticket.identity.tick) + 1 \
			or physical_actor_session._commands != ticket.commands:
		_clear_held_flight()
		return
	ticket.identity = successor
	_held_flight_ticket = ticket


func same_frame_continuation_status() -> Dictionary:
	return {"version":WorkbenchSameFrameContinuation.VERSION,
		"requested":_workbench_same_frame_requested,"enabled":_workbench_same_frame_enabled,
		"disabled_reason":"rendezvous_selected" if _workbench_same_frame_requested and _workbench_native_rendezvous_enabled else "",
		"mode":"same_frame_once" if _workbench_same_frame_enabled else "off",
		"maximum_attempts_per_process_frame":1,"maximum_mailbox_reads_per_attempt":1,
		"wait_usec":0,"new_physics_callbacks":0,"carried_time_credit":false}


func _same_frame_identity() -> Dictionary:
	# All values are bounded copied owner/lease counters. In particular an
	# intervening cancellation, pause/resume or takeover changes generations,
	# even if it leaves the same actor pose and then restores the same input.
	if OS.get_thread_caller_id() != OS.get_main_thread_id() \
		or shared_workbench == null or physical_actor_session == null \
		or not physical_actor_session.bridge is WorkbenchBridge \
		or physical_actor_session.bridge != rapier_bridge \
		or not physical_actor_session.active() or physical_actor_session._suspended \
		or paused or shared_workbench.step_requested or shared_workbench.step_pending \
		or not _workbench_frame_error.is_empty() or not engine_lab_wait_native_sample \
		or _workbench_wait_sample < 0 or _pending_physical_candidate != null \
		or _actor_reset_receipt != 0 or not pending_microscenario_apply.is_empty() \
		or worker_start_error != OK or not _physical_terrain_ready \
		or not rapier_bridge.is_initialized() or rapier_bridge.pending_hard_surface_chunks() != 0:
		return {}
	return {"owner":str(physical_actor_session.get_instance_id()),"bridge":str(rapier_bridge.get_instance_id()),
		"worker":str(simulation_worker.get_instance_id()),"epoch":_body_owner_epoch(),
		"session":physical_actor_session.bridge._session,"tick":physical_actor_session.tick,
		"manual_steps":rapier_bridge.manual_step_count(),"sample":_workbench_wait_sample,
		"bridge_sample":physical_actor_session.bridge._serial,"installed_revision":last_hard_surface_revision,
		"accepted_commands":physical_actor_session.accepted_commands,
		"sequences":physical_actor_session._sequences.duplicate(),
		"generations":physical_actor_session._generations.duplicate(),
		"deadlines":physical_actor_session._deadlines.duplicate()}


func _arm_same_frame_continuation(delta: float, snapshot: CyberSimulationSnapshot) -> void:
	# Only the final native_sample hold may arm a permit. Every earlier gate
	# has already passed and no admitted step or body publication occurred.
	var identity: Dictionary = _same_frame_identity()
	if identity.is_empty() or snapshot == null: return
	_workbench_same_frame.arm(identity, snapshot.physics_world_generation,
		int(snapshot.lab_context.get("workbench_hard_surface_revision",-1)), delta, Time.get_ticks_usec())


func _same_frame_continuation_observed(_phase: String, _evidence: Dictionary) -> void:
	# Observation seam only. Ordinary Main records no unbounded history.
	pass


func _try_same_frame_continuation() -> void:
	if _workbench_same_frame.pending.is_empty(): return
	var started_usec: int = Time.get_ticks_usec()
	var before: int = physical_actor_session.tick if physical_actor_session != null else -1
	var attempt: Dictionary = _workbench_same_frame.take_ready(Engine.get_process_frames(),
		_same_frame_identity(), _pubpres_try_physics_mailbox if _pubpres_trace_enabled else simulation_worker.try_read_physics_mailbox)
	attempt["start_usec"] = started_usec
	attempt["before_step"] = before
	attempt["attempt_process_frame"] = Engine.get_process_frames()
	# Immutable snapshots are retained locally until the ordinary transaction
	# ends. The observer gets only identity/scalars, never a mutable packet.
	var snapshot: CyberSimulationSnapshot = attempt.get("snapshot")
	attempt.erase("snapshot")
	_same_frame_continuation_observed("begin", attempt.duplicate(true))
	if attempt.status == "ready":
		# No new event-loop turn can intervene here. Repeat the read-only Main
		# guards after the one nonblocking owner-mailbox observation. Changed
		# terrain waits for a real physics callback; no extra install allowance.
		if _same_frame_identity() != attempt.identity:
			attempt.status = "owner_or_input_changed"
		else:
			_complete_physics_callback(float(attempt.delta), false, snapshot)
	attempt["time_usec"] = Time.get_ticks_usec()
	attempt["after_step"] = physical_actor_session.tick if physical_actor_session != null else -1
	attempt["advanced"] = int(attempt.after_step) == before + 1
	_same_frame_continuation_observed("end", attempt.duplicate(true))
	if workbench_pose_trace.active:
		var event: Dictionary = attempt.duplicate(true)
		event["event"] = "physics_continuation"
		workbench_pose_trace.observe_event(event)


func _pubpres_transaction_observed(_event: String, _evidence: Dictionary) -> void:
	# No retained history or behavior in Main. The dedicated observer owns its
	# bounded sidecar and joins these observations to actual callback/step proof.
	pass


func _pubpres_packet_observed(event: String, started_usec: int,
		snapshot: CyberSimulationSnapshot, extra: Dictionary) -> void:
	var evidence := {"trace_version":2, "start_usec":started_usec, "time_usec":Time.get_ticks_usec(),
		"process_frame":Engine.get_process_frames(), "physics_frame":Engine.get_physics_frames(),
		"requested_sample":_workbench_wait_sample, "current_epoch":_body_owner_epoch(),
		"current_session":physical_actor_session.bridge._session if physical_actor_session != null \
			and physical_actor_session.bridge is WorkbenchBridge else -1,
		"physical_tick":physical_actor_session.tick if physical_actor_session != null else -1,
		"queued_hard_revision":last_hard_surface_revision, "packet_present":snapshot != null}
	if snapshot != null:
		evidence.merge({"world_generation":snapshot.physics_world_generation,
			"rigid_body_epoch":snapshot.rigid_body_epoch, "snapshot_serial":snapshot.serial,
			"tick_index":snapshot.tick_index,
			"completed_body_sample":snapshot.lab_context.get("workbench_completed_sample", -1),
			"packet_session":snapshot.lab_context.get("workbench_gcr", {}).get("session", -1),
			"required_hard_revision":snapshot.lab_context.get("workbench_hard_surface_revision", -1),
			"packet_hard_revision":snapshot.hard_surface_revision,
			"native_completed_usec":snapshot.last_native_tick_completed_usec,
			"physics_handoff_usec":snapshot.physics_handoff_usec,
			"simulation_failed":snapshot.simulation_failed,
			"native_refusal":str(snapshot.lab_context.get("workbench_refusal", ""))})
	evidence.merge(extra)
	_pubpres_transaction_observed(event, evidence)


func _pubpres_take_physics_snapshot(callsite: String) -> CyberSimulationSnapshot:
	var started_usec: int = Time.get_ticks_usec()
	var snapshot: CyberSimulationSnapshot = simulation_worker.take_latest_physics_snapshot()
	_pubpres_packet_observed("mailbox_observation", started_usec, snapshot,
		{"callsite":callsite, "status":"ready" if snapshot != null else "empty", "nonblocking":false})
	return snapshot


func _pubpres_try_physics_mailbox() -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var mailbox: Dictionary = simulation_worker.try_read_physics_mailbox()
	var snapshot: CyberSimulationSnapshot = mailbox.get("snapshot")
	_pubpres_packet_observed("mailbox_observation", started_usec, snapshot,
		{"callsite":"try_read", "status":str(mailbox.get("status", "invalid")), "nonblocking":true,
		"mailbox_epoch":mailbox.get("epoch", -1), "mailbox_session":mailbox.get("session", -1)})
	return mailbox


func _pubpres_terrain_installed(snapshot: CyberSimulationSnapshot) -> bool:
	var started_usec: int = Time.get_ticks_usec()
	var pending_before: int = rapier_bridge.pending_hard_surface_chunks()
	var queued_before: int = last_hard_surface_revision
	var ready: bool = _workbench_terrain_installed(snapshot)
	_pubpres_packet_observed("terrain_install", started_usec, snapshot,
		{"operation":"check", "pending_before":pending_before,
		"pending_after":rapier_bridge.pending_hard_surface_chunks(),
		"queued_revision_before":queued_before, "queued_revision_after":last_hard_surface_revision, "ready":ready})
	return ready


func _pubpres_terrain_budget(chunks: int, usec: int, callsite: String,
		snapshot: CyberSimulationSnapshot) -> void:
	var started_usec: int = Time.get_ticks_usec()
	var pending_before: int = rapier_bridge.pending_hard_surface_chunks()
	rapier_bridge.process_hard_surface_collider_budget(chunks, usec)
	_pubpres_packet_observed("terrain_install", started_usec, snapshot,
		{"operation":"budget", "callsite":callsite, "pending_before":pending_before,
		"pending_after":rapier_bridge.pending_hard_surface_chunks(), "chunks_allowance":chunks, "usec_allowance":usec})


func workbench_source(origin: Vector2i, material: int, command: String) -> bool:
	if shared_workbench == null: return false
	if not pending_microscenario_apply.is_empty() and not (command == "configure"
		and tower_context.get("scenario_request_applied",false)
		and tower_context.get("scenario_request_serial",-1) == pending_microscenario_apply.serial): return false
	return simulation_worker.queue_workbench_source(origin,material,command)

# IN-TOOLS #361 liquid equipment. Same admission window as the powder source:
# a configure may follow the acknowledged install of a pending replacement.
func workbench_equipment(request: Dictionary) -> bool:
	if shared_workbench == null: return false
	if not pending_microscenario_apply.is_empty() and not (str(request.get("command","")) == "configure"
		and tower_context.get("scenario_request_applied",false)
		and tower_context.get("scenario_request_serial",-1) == pending_microscenario_apply.serial): return false
	return simulation_worker.queue_workbench_equipment(request)

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
	if shared_workbench != null:
		if event is InputEventKey and event.pressed and not event.echo and not get_viewport().gui_get_focus_owner() is LineEdit:
			match event.keycode:
				KEY_P,KEY_ESCAPE: shared_workbench.toggle_pause()
				KEY_R: shared_workbench.reset_selected()
				KEY_PERIOD: shared_workbench.step_once()
				KEY_B: shared_workbench.burst()
				KEY_V: shared_workbench.equipment.toggle("valve")
				KEY_G: shared_workbench.equipment.toggle("drain")
				KEY_H: shared_workbench.equipment.toggle("nozzle")
				KEY_J: shared_workbench.equipment.nudge_aim(-10.0)
				KEY_K: shared_workbench.equipment.nudge_aim(10.0)
				KEY_BRACKETLEFT: shared_workbench.equipment.select_valve(-1)
				KEY_BRACKETRIGHT: shared_workbench.equipment.select_valve(1)
				_: return
			get_viewport().set_input_as_handled()
		return
	if physical_rig_id != &"" and event is InputEventKey \
		and (event.keycode in ACTOR_CONTROL_KEYS or event.keycode in PHYSICAL_TOOL_KEYS \
			or (_playable_course_controls_active() and event.keycode in [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT])):
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
			if _playable_course_controls_active():
				toggle_playable_course_pause()
			else:
				paused = not paused
		KEY_ESCAPE:
			if _playable_course_controls_active():
				toggle_playable_course_pause()
		KEY_F:
			toggle_playable_course_camera()
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


# A configurable presentation change only: no native reset, new World or
# parallel owner. Other MicroScenario and sandbox cameras are unchanged.
func toggle_playable_course_camera() -> void:
	if not _playable_course_controls_active():
		set_camera_follow(not camera_follow_enabled)
		return
	if camera_follow_enabled:
		set_camera_follow(false)
		current_view_size = PlayerCourse.VIEW.size
		camera_origin = Vector2(PlayerCourse.VIEW.position)
	else:
		current_view_size = Vector2i(256, 128)
		set_camera_follow(true)
		camera_origin = clamped_camera_origin(character_centre() - Vector2(current_view_size) * 0.5)
	# The worker sees only the copied interest/view change.
	update_worker_frame_state()


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
	if shared_workbench != null: return
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
		microscenario_error = "Prepared native default player changes use F5: sampled baseline, barrel or Ripper"
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
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),true,not sampled_runtime_recovery_enabled,{}, {},false)
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
	if configuration.has("prepared_actor_effort"): _actor_effort=float(configuration.prepared_actor_effort)
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
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),true,null,{}, {},false)
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


func test_rigid_body_spawn(body_index: int, barrel: Variant = null) -> Vector2:
	match body_index:
		0:
			return (
				barrel_player_spawn_centre()
				if (player_uses_barrel() if barrel==null else bool(barrel))
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


func lockstep_coupling_requested() -> bool:
	# Desktop only: Web already waits for native ticks on its own owner.
	return not OS.has_feature("web") and "--lockstep-coupling" in OS.get_cmdline_user_args()


func _lockstep_hold(snapshot: CyberSimulationSnapshot) -> bool:
	# True while the newest completion has not consumed main's last publication
	# or was already applied. Bounded: past the limit one counted stale step runs.
	# A physics frame that skipped this decision (pause, reset, actor install or
	# an early return) restarts the bound: the worker had nothing new to consume
	# meanwhile, so that wait is not owner lateness.
	var frame: int = Engine.get_physics_frames()
	if frame != _lockstep_hold_frame + 1:
		_lockstep_hold_started_msec = -1
	_lockstep_hold_frame = frame
	if (snapshot != null and snapshot.consumed_rigid_body_publication == _lockstep_published
		and snapshot.serial != _lockstep_applied_serial):
		_lockstep_hold_started_msec = -1
		_lockstep_applied_serial = snapshot.serial
		if snapshot.rigid_body_epoch != _body_owner_epoch():
			# Owner transition: apply_latest_rigid_body_results drops another
			# owner's result, so this step is counted as unfenced, not fenced.
			lockstep_main_unfenced_steps += 1
			return false
		_lockstep_applied_publication = snapshot.consumed_rigid_body_publication
		_lockstep_applied_tick = snapshot.tick_index
		lockstep_main_fenced_steps += 1
		return false
	var now_msec: int = Time.get_ticks_msec()
	if _lockstep_hold_started_msec < 0:
		_lockstep_hold_started_msec = now_msec
	elif now_msec - _lockstep_hold_started_msec > LOCKSTEP_MAIN_HOLD_LIMIT_MSEC:
		_lockstep_hold_started_msec = -1
		lockstep_main_hold_timeouts += 1
		return false
	lockstep_main_held_frames += 1
	return true


func lockstep_coupling_status() -> Dictionary:
	var status: Dictionary = {"enabled":lockstep_coupling_enabled,
		"main_fenced_steps":lockstep_main_fenced_steps, "main_held_frames":lockstep_main_held_frames,
		"main_unfenced_steps":lockstep_main_unfenced_steps,
		"main_hold_timeouts":lockstep_main_hold_timeouts,
		"main_hold_limit_msec":LOCKSTEP_MAIN_HOLD_LIMIT_MSEC, "published":_lockstep_published}
	status.worker = simulation_worker.lockstep_metrics()
	return status


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


func apply_latest_rigid_body_results(snapshot: CyberSimulationSnapshot = null) -> void:
	if snapshot == null: snapshot = latest_snapshot
	if snapshot == null or snapshot.simulation_failed or not rapier_bridge.is_initialized():
		return
	if _actor_reset_receipt != 0 or not pending_microscenario_apply.is_empty():
		return
	if snapshot.rigid_body_epoch != _body_owner_epoch():
		return
	if shared_workbench != null:
		if physical_actor_session != null:
			physical_actor_session.apply_workbench_results(snapshot.serial,snapshot.lab_context.get("workbench_gcr",{}))
			physical_actor_session.accept_equipment_feedback(snapshot.physical_usables)
		return
	rapier_bridge.apply_cellular_results(
		snapshot.serial,
		snapshot.rigid_body_results
	)


func consume_worker_snapshot() -> void:
	var snapshot: CyberSimulationSnapshot = simulation_worker.take_latest_snapshot(consumed_snapshot_serial)
	if snapshot == null:
		return
	if not worker_publication_counter.observe(snapshot.serial):
		return
	latest_snapshot = snapshot
	_cadence_received_usec = Time.get_ticks_usec()
	if workbench_pose_trace.active:
		workbench_pose_trace.observe_event({"event":"main_receipt","time_usec":_cadence_received_usec,
			"snapshot_serial":snapshot.serial,"render_serial":snapshot.render_snapshot_serial,
			"native_tick":snapshot.tick_index,"worker_handoff_usec":snapshot.worker_handoff_usec})
	_reconcile_actor_prototype_reset()
	tower_context = snapshot.lab_context
	if shared_workbench != null and not str(tower_context.get("workbench_refusal","")).is_empty():
		if not paused: cancel_playable_course_input()
		paused = true
		microscenario_error = tower_context.workbench_refusal
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
			var resume_play: bool = pending_microscenario_apply.get("workbench_resume",false)
			_microscenario_installed(pending_microscenario_apply.definition)
			if tower_context.get("microscenario", {}).get("failed", false):
				microscenario_error = "Installed session apparatus failed: " + str(tower_context.microscenario.get("error", "unavailable"))
			pending_microscenario_apply.clear()
			if resume_play and not snapshot.simulation_failed and microscenario_error.is_empty():
				paused = false
				update_worker_frame_state()
		elif (int(tower_context.get("scenario_request_serial", 0)) == int(pending_microscenario_apply.serial)
			and not bool(tower_context.get("scenario_request_applied", true))):
			if pending_microscenario_apply.get("profile_request",false): pending_player_environment_profile = {}
			paused = bool(pending_microscenario_apply.previous_paused)
			microscenario_mode = str(pending_microscenario_apply.get("previous_mode", microscenario_mode))
			microscenario_error = str(tower_context.status)
			_close_pending_physical_candidate()
			pending_microscenario_apply.clear()
			if shared_workbench != null and physical_actor_session != null:
				physical_actor_session.set_suspended(paused)
				update_worker_frame_state()
				if not paused and _workbench_frame_error.is_empty(): _publish_physical_body_state()
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
		if shared_workbench != null:
			cancel_playable_course_input()
			_close_pending_physical_candidate()
			pending_microscenario_apply.clear()
			microscenario_error = "Native tick %d stopped: %s. Reset or restore rebuilds the starting setup." % [
				snapshot.failed_tick_index,snapshot.last_tick_error]
	if not player_uses_barrel():
		character_position = snapshot.character_position
	if shared_workbench != null and physical_actor_session != null:
		physical_actor_session.ingest_ambient_snapshot(snapshot)
	_offer_material_snapshot(snapshot)
	gameplay_recorder.ingest_snapshot(snapshot)


# A Workbench receipt must describe the actual uploaded material texture,
# physical session and epoch. Absent/stale receipts never authorize a live
# Rapier fallback; the actor is temporarily hidden until a valid receipt.
func _valid_workbench_mask_frame(frame: Dictionary) -> bool:
	if shared_workbench == null or physical_actor_session == null:
		return false
	var bridge: Variant = physical_actor_session.bridge
	return bridge is WorkbenchBridge \
		and frame.get("session",-1) == bridge._session \
		and frame.get("epoch",-1) == bridge._epoch \
		and frame.get("world_generation",-1) == last_uploaded_world_generation \
		and frame.get("revision",-1) == last_uploaded_revision \
		and frame.get("instances") is Dictionary


# Direct test/compatibility entry. Production resolves before update_camera,
# then submits the same frame; this entry follows that identical ordering.
func _present_physical_actor_overlay(frame: Dictionary) -> void:
	if shared_workbench == null:
		physical_actor_overlay.present(physical_actor_session.render_parts() \
			if physical_actor_session != null else [],presentation_camera_origin(),
			current_view_size,view_content_rect())
		return
	if workbench_presentation_submission_enabled():
		_prepare_workbench_presentation_candidate(0.0,frame)
		return
	_workbench_mapping_locked = false
	_resolve_workbench_presentation_frame(frame)
	update_camera(0.0)
	_resolve_workbench_camera_mapping()
	_submit_workbench_presentation_frame()
	update_shader_parameters()
	_workbench_mapping_locked = false


func _workbench_presentation_mode() -> String:
	if OS.get_environment("CYBERSAND_DIAG_FLYER_POSE") == "mask": return "mask_baseline"
	return "coherent" if OS.get_environment("CYBERSAND_DIAG_PRESENTATION") == "coherent" else "legacy_guarded"


func _material_presentation_state(now_usec: int) -> Dictionary:
	var timing: Dictionary = material_presentation_timeline.frame(now_usec,cadence_lod_enabled)
	if shared_workbench != null and timing.previous.is_empty():
		# A recycled GPU plane may still contain another World (or an
		# unqualified upload). Requested cadence cannot authorize its colour
		# contribution. Both timing policies require an actual same-World
		# predecessor; keep the accepted upload, history bytes and ACK intact.
		return timing
	if shared_workbench == null or OS.get_environment("CYBERSAND_DIAG_MATERIAL_TIMING") != "measured":
		# Independent diagnostic control; it never changes upload ACK, texture
		# history, the native scheduler or Rapier's physical timestep.
		var duration: int = int(1000000.0/float(maxi(render_snapshot_hz,1)))
		var blend: float = clampf(float(now_usec-snapshot_blend_start_usec)/float(duration),0.0,1.0) \
			if cadence_lod_enabled else 1.0
		timing.merge({"snapshot_blend":blend,"previous_blend_active":blend < 1.0,
			"blend_duration_usec":duration,"timing_source":"legacy_requested"},true)
	return timing


func _workbench_bound_sample(entry: Dictionary) -> Dictionary:
	if physical_actor_session == null or not physical_actor_session.bridge is WorkbenchBridge:
		return {}
	var bridge: Variant = physical_actor_session.bridge
	if _workbench_sample_identity != [bridge._session,bridge._epoch]: return {}
	var serial: int = int(entry.get("sample",-1))
	if serial < 0: return {}
	var sample: Dictionary = _workbench_sample_steps.get(serial % PRESENTATION_SAMPLE_HISTORY,{})
	return sample if sample.get("serial",-1) == serial else {}


func _workbench_bound_step(entry: Dictionary) -> int:
	return int(_workbench_bound_sample(entry).get("step",-1))

func _observe_workbench_presentation(slot: int, sample_serial: int = -1) -> Dictionary:
	var bridge: Variant = physical_actor_session.bridge
	var member: Dictionary = bridge._members[slot]
	var owner: Array = [bridge.get_instance_id(),bridge._session,bridge._epoch]
	if not _workbench_presentation_history.bound_to(owner) \
			or not _workbench_presentation_history.member_matches(slot,int(member.instance_id),int(member.generation)):
		if not _workbench_presentation_history.bind_members(owner,bridge._members): return {}
	var step: int = physical_actor_session.tick
	# The bridge copies these values after every completed Rapier step. Drawing
	# must never query PhysicsServer or turn an old completion into a new one.
	return _workbench_presentation_history.observe(slot,int(member.instance_id),int(member.generation),
		step,bridge.body_transform(slot),bridge._linear_velocities[slot],bridge._angular_velocities[slot],
		_workbench_completed_step_usec if _workbench_completed_step == step else 0,sample_serial)


func _workbench_recovery_time_valid(observation: Dictionary, now_usec: int, current_step: int) -> bool:
	# Current physics may itself be old because it is paused. That does not
	# create display lag. Older playback observations must have a real known
	# completion clock and remain within the explicit100ms visual age bound.
	var completed: int = int(observation.get("completed_usec",0))
	return completed > 0 and completed <= now_usec \
		and (int(observation.get("step",-1)) == current_step \
		or now_usec-completed <= WorkbenchPresentationHistory.MAX_HOLD_USEC)


func _assess_workbench_presented_sweep(start: Transform2D, target: Transform2D,
		rectangles: Array, context: Dictionary, summary: Dictionary) -> Dictionary:
	var remaining: int = PRESENTATION_FRAME_SCAN_BUDGET-int(summary.cells_examined)
	if remaining <= 0 or Time.get_ticks_usec() >= int(context.deadline_usec):
		summary.budget_vetoes += 1
		return {"safe":false,"reason":"shared_budget","scanned":0}
	var result: Dictionary = WorkbenchPresentationCoherence.assess(start,target,
		rectangles,image,_presentation_previous_occupied,_presentation_previous_unknown,
		context.previous_blend_active,mini(remaining,WorkbenchPresentationCoherence.MAX_SCAN_CELLS),
		context.deadline_usec,_presentation_previous_image,true,
		_presentation_current_bytes,_presentation_previous_bytes,remaining,true)
	summary.cells_examined += int(result.scanned)
	if str(result.reason) in ["scan_budget","time_budget","shared_budget"]:
		summary.budget_vetoes += 1
	if bool(result.get("refined",false)):
		summary.refined_queries += 1
		if bool(result.safe): summary.refined_clear += 1
	return result


func _workbench_water_composition_enabled() -> bool:
	return OS.get_environment("CYBERSAND_DIAG_WATER_COMPOSITION") == "1" \
		and _workbench_presentation_mode() == "coherent"


func _capture_workbench_water_dependencies(snapshot: CyberSimulationSnapshot) -> void:
	_workbench_water_dependencies.clear()
	# Existing readers retain the immutable capsule; retire our reference.
	_workbench_water_completion_context = {}
	_workbench_water_closure_cache.clear()
	if not _workbench_water_composition_enabled() or physical_actor_session == null or snapshot == null:
		return
	var bridge: Variant = physical_actor_session.bridge
	if not bridge is WorkbenchBridge or bridge != rapier_bridge or snapshot.simulation_failed \
			or snapshot.rigid_body_epoch != bridge._epoch \
			or snapshot.last_native_tick_world_generation != snapshot.physics_world_generation:
		return
	var application: Dictionary = bridge.last_application
	if application.get("accepted",false) != true or not str(application.get("refusal","")).is_empty() \
			or application.get("snapshot",-1) != snapshot.serial:
		return
	# A fresh native coupling result can precede another material tick.
	# Keep the actual last material completion and the response clock distinct.
	var response_usec: int = snapshot.lab_context.get("coupling_response_usec",-1)
	var sample: int = snapshot.last_native_tick_body_sample
	if response_usec > 0:
		if response_usec < snapshot.last_native_tick_completed_usec or response_usec > _workbench_completed_step_usec: return
		sample = int(snapshot.lab_context.get("workbench_completed_sample",-1))
	var packet: Dictionary = snapshot.lab_context.get("workbench_gcr",{})
	if sample < 0 or snapshot.last_native_tick_completed_usec <= 0 \
			or snapshot.lab_context.get("workbench_completed_sample",-1) != sample \
			or packet.get("session",-1) != bridge._session or packet.get("epoch",-1) != bridge._epoch \
			or not packet.get("valid",false) or bridge._history.is_empty(): return
	var history: Dictionary = bridge._history[sample % bridge._history.size()]
	if history.get("serial",-1) != sample or history.get("bodies",[]).size() != bridge._members.size(): return
	_workbench_water_completion_context = {"bridge":bridge.get_instance_id(),"session":bridge._session,
		"epoch":bridge._epoch,"world":snapshot.physics_world_generation,"step":physical_actor_session.tick,
		"native_tick":snapshot.tick_index,"sample":sample,"revision":snapshot.simulation_world_revision,
		"coupling_response_usec":response_usec,"material_tick_body_sample":snapshot.last_native_tick_body_sample,
		"native_completed_usec":snapshot.last_native_tick_completed_usec,"completed_usec":_workbench_completed_step_usec}
	_workbench_water_completion_context.make_read_only()
	for action: Dictionary in bridge.last_application.get("bodies",[]):
		var slot: int = int(action.get("id",0))-1
		if slot < 0 or slot >= bridge._members.size() or action.has("refusal") \
				or action.get("sample",-1) != sample: continue
		var member: Dictionary = bridge._members[slot]
		_workbench_water_dependencies[slot] = {"bridge":bridge.get_instance_id(),
			"session":bridge._session,"epoch":bridge._epoch,"world":snapshot.physics_world_generation,
			"step":physical_actor_session.tick,"native_tick":snapshot.tick_index,"sample":sample,
			"revision":snapshot.simulation_world_revision,"rid":bridge._body_rids[slot].get_id(),
			"rectangles":bridge._rects[slot].duplicate(true),
			"instance_id":member.instance_id,"generation":member.generation,
			"native_response_applied":true,"input_pose":history.bodies[slot].pose,
			"output_pose":bridge.body_transform(slot),"completed_usec":_workbench_completed_step_usec,
			"coupling_response_usec":response_usec,"material_tick_body_sample":snapshot.last_native_tick_body_sample,
		"native_completed_usec":snapshot.last_native_tick_completed_usec}
		WorkbenchWaterComposition.freeze(_workbench_water_dependencies[slot])


func _workbench_water_dependency(slot: int, frame: Dictionary, entry: Dictionary,
		observation: Dictionary) -> Dictionary:
	if not _workbench_water_composition_enabled() or not _valid_workbench_mask_frame(frame) \
			or not _workbench_frame_error.is_empty() or simulation_worker.has_failed() \
			or not _physical_terrain_ready or _actor_reset_receipt != 0:
		return {}
	var bridge: Variant = physical_actor_session.bridge
	if bridge != rapier_bridge or slot < 0 or slot >= bridge._members.size() \
			or _workbench_sample_identity != [bridge._session,bridge._epoch]:
		return {}
	# Restore builds a separate owner while the installed session remains paused.
	# Only an already proved closure for that installed owner can survive staging.
	var staging := not pending_microscenario_apply.is_empty() or _pending_physical_candidate != null
	if staging and (not paused or _pending_physical_candidate == null
			or _pending_physical_candidate.physics_bridge() == bridge
			or not physical_actor_session._suspended):
		return {}
	var initialized: bool = physical_actor_session.tick == 0 and bridge.manual_step_count() == 0 \
		and bridge.is_initialized() and _workbench_completed_step <= 0 and _workbench_completed_step_usec == 0
	if not initialized and (physical_actor_session.tick != _workbench_completed_step \
			or int(observation.get("completed_usec",-1)) != _workbench_completed_step_usec):
		return {}
	var member: Dictionary = bridge._members[slot]
	var visible: Dictionary = {"world":last_uploaded_world_generation,"revision":last_uploaded_revision,
		"upload_serial":last_uploaded_render_snapshot_serial,"current_content":_presentation_current_content_id,
		"previous_content":_presentation_previous_content_id,"native_tick":frame.get("tick",-1),
		"native_sample":entry.get("sample",-1)}
	if not initialized and not _workbench_water_completion_context.is_empty():
		var current: Dictionary = _workbench_water_completion_context.duplicate()
		# Bind the immutable completion capsule to the CURRENT owner/World and
		# exact current member geometry. Visible material keeps separate clocks.
		current.merge({"bridge":bridge.get_instance_id(),"session":bridge._session,"epoch":bridge._epoch,
			"world":last_uploaded_world_generation,"step":physical_actor_session.tick,
			"rid":bridge._body_rids[slot].get_id(),"rectangles":bridge._rects[slot],
			"completed_usec":_workbench_completed_step_usec},true)
		var completed_proof: Dictionary = WorkbenchWaterComposition.completed_dependency(current,member,
			observation,_workbench_water_dependencies.get(slot,{}))
		if not completed_proof.is_empty():
			completed_proof["visible_material"] = visible
			return completed_proof
	var serial: int = int(entry.get("sample",-1))
	if serial < 0 or (not initialized and int(frame.get("native_completed_usec",0)) <= 0): return {}
	var context: Dictionary = {"bridge":bridge.get_instance_id(),"session":bridge._session,
		"epoch":bridge._epoch,"world":last_uploaded_world_generation,"revision":last_uploaded_revision,
		"step":physical_actor_session.tick,"native_tick":int(frame.get("tick",-1)),"sample":serial,
		"native_completed_usec":int(frame.get("native_completed_usec",-1)),
		"rid":bridge._body_rids[slot].get_id(),"initialized":initialized,"manual_steps":bridge.manual_step_count(),
		"initialized_pose":bridge.body_transform(slot),"completed_usec":_workbench_completed_step_usec}
	var identity: Dictionary = {"context":context,"entry":entry.duplicate(true),
		"member":[member.instance_id,member.generation,bridge._body_rids[slot].get_id(),
			bridge._rects[slot].duplicate(true)],
		"observation":[observation.get("instance_id"),observation.get("generation"),
			observation.get("step"),observation.get("completed_usec"),observation.get("pose")]}
	# Paused Main can publish enough same-step samples to evict the short
	# native wrench ring while its uploaded material frame stays unchanged.
	# Eviction retires force-application authority, not an already proved exact
	# completed-pose provenance. Retain at most one immutable proof per member.
	# This cache retains native pose provenance. The separate coverage cache
	# certifies the required visible material images and swept geometry.
	var cached: Dictionary = _workbench_water_closure_cache.get(slot,{})
	if cached.get("identity") == identity:
		_workbench_water_closure_cache_hits += 1
		var retained: Dictionary = cached.proof.duplicate(true)
		retained["visible_material"] = visible
		return retained
	if staging: return {}
	_workbench_water_closure_cache.erase(slot)
	var sampled: Dictionary = _workbench_bound_sample(entry).duplicate()
	if bridge._history.is_empty(): return {}
	var history: Dictionary = bridge._history[serial % bridge._history.size()]
	if sampled.get("water_poses",[]).size() == bridge._members.size():
		sampled.merge({"pose":sampled.water_poses[slot],"session":bridge._session,"epoch":bridge._epoch})
	elif history.get("serial",-1) == serial and history.get("bodies",[]).size() == bridge._members.size():
		sampled.merge({"pose":history.bodies[slot].pose,"session":bridge._session,"epoch":bridge._epoch})
	var proof: Dictionary = WorkbenchWaterComposition.initialized_closure(context,member,entry,observation,sampled) \
		if initialized else WorkbenchWaterComposition.dependency(context,member,entry,
			observation,sampled,_workbench_water_dependencies.get(slot,{}))
	if not proof.is_empty():
		WorkbenchWaterComposition.freeze(identity)
		proof.make_read_only()
		_workbench_water_closure_cache[slot] = {"identity":identity,"proof":proof}
	# The resolver attaches this draw's fresh coverage result to its own copy.
	var result: Dictionary = proof.duplicate(true)
	if not result.is_empty(): result["visible_material"] = visible
	return result


func _workbench_water_coverage_identity(slot: int, start: Transform2D, target: Transform2D,
		rectangles: Array, context: Dictionary) -> Dictionary:
	if physical_actor_session == null or not physical_actor_session.bridge is WorkbenchBridge \
			or _workbench_visible_material_contents(bool(context.previous_blend_active)).is_empty(): return {}
	var bridge: Variant = physical_actor_session.bridge
	if slot < 0 or slot >= bridge._members.size(): return {}
	var member: Dictionary = bridge._members[slot]
	var front_rid: int = context.current_texture_id if context.has("current_texture_id") else _material_publication_rid(texture).get_id()
	var back_rid: int = context.previous_texture_id if context.has("previous_texture_id") else _material_publication_rid(previous_texture).get_id()
	return {"owner":[bridge.get_instance_id(),bridge._session,bridge._epoch,
		member.instance_id,member.generation,bridge._body_rids[slot].get_id()],
		"material":[last_uploaded_world_generation,last_uploaded_revision,last_uploaded_render_snapshot_serial,
			_presentation_current_content_id,_presentation_current_content_shape,front_rid],
		"previous":[_presentation_previous_content_id,_presentation_previous_content_shape,
			back_rid,_presentation_previous_unknown]
			if bool(context.previous_blend_active) else [],
		"full_back_rid":back_rid if texture is ImageTexture and previous_texture is ImageTexture
			and _material_full_ring == null and _material_blit_publisher == null else 0,
		"sweep":[start,target,rectangles]}


# A paused Full refresh can rotate the same two GPU resources and restart a
# blend with two byte-identical material planes. finish_texture_upload assigns
# an existing content ID only after comparing all bytes AND the format/extent.
# The old scan must have tested exactly this one effective image: if a
# different visible previous image contributed Water, its result cannot stand
# in for the current image alone. Native/physical authority is proved anew.
func _same_paused_water_coverage(old: Dictionary, current: Dictionary) -> bool:
	if not paused or old.is_empty() or current.is_empty() or old.owner != current.owner \
			or old.sweep != current.sweep or current.sweep[0] != current.sweep[1]: return false
	var before: Array = old.material
	var after: Array = current.material
	if before[0] != after[0] or before[1] != after[1] or before[3] != after[3] or before[4] != after[4] \
			or old.full_back_rid == 0 or current.full_back_rid == 0 or after[5] == 0 \
			or current.full_back_rid == after[5]: return false
	for key: Dictionary in [old,current]:
		if not key.previous.is_empty() and (key.previous[0] != after[3] or key.previous[1] != after[4]
				or key.previous[2] != key.full_back_rid or key.previous[3]): return false
	if before[2] == after[2]:
		return before[5] == after[5] and old.full_back_rid == current.full_back_rid
	return after[2] == before[2]+1 and before[5] == current.full_back_rid and old.full_back_rid == after[5]


func _assess_workbench_water_sweep(slot: int, start: Transform2D, target: Transform2D,
		rectangles: Array, context: Dictionary, summary: Dictionary, cached_only: bool = false) -> Dictionary:
	var identity: Dictionary = _workbench_water_coverage_identity(slot,start,target,rectangles,context)
	var cached: Dictionary = _workbench_water_coverage_cache.get(slot,{})
	var exact: bool = not identity.is_empty() and cached.get("identity") == identity
	var rebound: bool = not exact and _same_paused_water_coverage(cached.get("identity",{}),identity)
	if exact or rebound:
		if rebound:
			# Holds and submissions still require the actual new upload and RID
			# identities. Keep the historical immutable receipt unmodified.
			var next: Dictionary = {"identity":identity.duplicate(true),"result":cached.result}
			WorkbenchWaterComposition.freeze(next.identity)
			next.make_read_only()
			_workbench_water_coverage_cache[slot] = next
		# This is an exact immutable image/geometry result, not physical or
		# visible-history authority. The caller must separately prove the current
		# actual owner/pose. No scan cells or elapsed time are invented on reuse.
		var retained: Dictionary = cached.result.duplicate(true)
		retained["original_scanned"] = retained.scanned
		retained["scanned"] = 0
		retained["coverage_reused"] = true
		if rebound: retained["equivalent_paused_publication"] = true
		return retained
	if cached_only: return {}
	var remaining: int = PRESENTATION_FRAME_SCAN_BUDGET-int(summary.cells_examined)
	if remaining <= 0 or Time.get_ticks_usec() >= int(context.deadline_usec):
		summary.budget_vetoes += 1
		return {"safe":false,"reason":"shared_budget","scanned":0}
	var result: Dictionary = WorkbenchPresentationCoherence.assess(start,target,
		rectangles,image,_presentation_previous_occupied,_presentation_previous_unknown,
		context.previous_blend_active,mini(remaining,WorkbenchPresentationCoherence.MAX_SCAN_CELLS),
		context.deadline_usec,_presentation_previous_image,true,
		_presentation_current_bytes,_presentation_previous_bytes,remaining,true,true)
	summary.cells_examined += int(result.scanned)
	if str(result.reason) in ["scan_budget","time_budget","shared_budget"]: summary.budget_vetoes += 1
	# Refusals, partial scans and unknown history never seed this bounded cache.
	# A single exact last result per real member is sufficient for stationary
	# actors across repeated draws; any changed image/geometry must scan again.
	if bool(result.safe) and not identity.is_empty():
		var value: Dictionary = {"identity":identity.duplicate(true),"result":result.duplicate(true)}
		WorkbenchWaterComposition.freeze(value)
		_workbench_water_coverage_cache[slot] = value
	return result


# A refused successor may briefly hold its last submitted Water pose under the
# same hold clock as a dry body. Only the prior endpoint is certified here.
# Never associate its historical physics proof with the successor's step.
func _submitted_water_hold(slot: int, previous: Dictionary, context: Dictionary) -> Dictionary:
	if not _workbench_water_composition_enabled() or not _workbench_frame_error.is_empty() \
			or simulation_worker.has_failed() or not _physical_terrain_ready or _actor_reset_receipt != 0 \
			or _pending_physical_candidate != null or not pending_microscenario_apply.is_empty():
		return {}
	var old: Dictionary = previous.get("water_coverage_identity",{})
	var proof: Dictionary = workbench_presentation_frame.get("water_proofs",{}).get(slot,{})
	if proof.is_empty() or old.is_empty() or not previous.get("water_composed",false) \
			or workbench_presentation_frame.get("poses",{}).get(slot) != previous.pose \
			or proof.get("step",-1) != previous.step:
		return {}
	var bridge: Variant = physical_actor_session.bridge
	if bridge != rapier_bridge: return {}
	var visible: Dictionary = proof.get("visible_material",{})
	var entry: Dictionary = context.mask_frame.instances.get(bridge._members[slot].instance_id,{})
	if visible.get("native_tick",-1) != context.mask_native_tick or visible.get("native_sample",-1) != entry.get("sample",-2):
		return {}
	var key: Dictionary = _workbench_water_coverage_identity(slot,previous.pose,previous.pose,bridge._rects[slot],context)
	if key.is_empty() or old.owner != key.owner or old.material != key.material \
			or old.sweep[1] != previous.pose or old.sweep[2] != key.sweep[2] \
			or (context.previous_blend_active and old.previous != key.previous):
		return {}
	return proof


func _workbench_visible_material_contents(previous_active: bool) -> Array[int]:
	var contents: Array[int] = []
	if _presentation_current_content_id <= 0:
		return contents
	# An identity cannot stand in for missing genuine previous-texture history.
	if previous_active and (_presentation_previous_unknown or _presentation_previous_content_id <= 0):
		return contents
	contents.append(_presentation_current_content_id)
	if previous_active and _presentation_previous_content_id != _presentation_current_content_id:
		contents.append(_presentation_previous_content_id)
	return contents


func _workbench_material_certificate_covers(certified: Array, required: Array) -> bool:
	if required.is_empty():
		return false
	for content_id: int in required:
		if not certified.has(content_id):
			return false
	return true


# On the first valid paused owner frame, check stationary material footprints
# together, before per-member native proof construction can exhaust the shared
# clearance deadline. These results authorize geometry only in this resolver
# call. Ordinary native, pose and submission checks still decide every draw.
func _initial_workbench_water_coverage(frame: Dictionary, context: Dictionary, summary: Dictionary,
		bridge: WorkbenchBridge, order: Array[int]) -> Dictionary:
	var results: Dictionary = {}
	if not paused or not _workbench_presentation_state.is_empty() or not _workbench_water_composition_enabled() \
			or not _valid_workbench_mask_frame(frame) or bridge != rapier_bridge or not bridge.is_initialized() \
			or not _physical_terrain_ready or _actor_reset_receipt != 0 or not _workbench_frame_error.is_empty() \
			or _pending_physical_candidate != null or not pending_microscenario_apply.is_empty() \
			or physical_actor_session.tick != 0 or bridge.manual_step_count() != 0 or _workbench_completed_step > 0 \
			or _workbench_completed_step_usec != 0 or _workbench_sample_identity != [bridge._session,bridge._epoch] \
			or order.is_empty() or order.size() > WorkbenchBridge.Capacity.DEFAULT_BODIES \
			or order.size() != bridge._rects.size() or order.size() != bridge._body_rids.size() \
			or _workbench_visible_material_contents(context.previous_blend_active).is_empty() or simulation_worker.has_failed():
		return results
	var start := Time.get_ticks_usec()
	var cells_before: int = summary.cells_examined
	var refused := 0
	for slot: int in order:
		var member: Dictionary = bridge._members[slot]
		var entry: Variant = frame.instances.get(member.instance_id)
		if not entry is Dictionary or entry.get("generation",-1) != member.generation \
				or not entry.get("pose") is Transform2D or not Transform2D(entry.pose).is_finite() \
				or entry.pose != bridge.body_transform(slot) or _workbench_bound_step(entry) != 0:
			continue
		var result := _assess_workbench_water_sweep(slot,entry.pose,entry.pose,bridge._rects[slot],context,summary)
		results[slot] = {"pose":entry.pose,"coverage":result}
		if not result.safe: refused += 1
	context["initial_water_coverage"] = {"members":results.size(),"refusals":refused,
		"cells":int(summary.cells_examined)-cells_before,"elapsed_usec":Time.get_ticks_usec()-start,
		"budget_at_entry_usec":maxi(0,int(context.deadline_usec)-start)}
	return results


func _resolve_workbench_presentation_frame(frame: Dictionary) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	# Charge immutable byte capture once to the presentation frame consuming
	# that upload. Its time was also included in the real upload interval.
	var cache_usec: int = _presentation_pending_cache_usec
	_presentation_pending_cache_usec = 0
	var mode: String = _workbench_presentation_mode()
	var material_timing: Dictionary = _material_presentation_state(started_usec)
	var blend: float = material_timing.snapshot_blend
	var resolved: Dictionary = {"policy":mode,"original_mask_frame":frame,
		"mask_frame":{},"poses":{},"sources":{},"selected_steps":{},"desired_steps":{},
		"reasons":{},"intentional_holds":{},"timeline_resets":{},"parts":[],
		"hold_age_usec":{},"selected_observations":{},"recovery_attempts":{},"explicit_reentries":{},
		"recovery_ceilings":{},"water_proofs":{},"water_composition":{},"contact_clips":{},"contact_cells":{},
		"follow_instance_id":shared_workbench.selected_id() if shared_workbench != null else -1,
		"follow_target":Vector2.INF,"follow_source_step":-1,"follow_held":false,
		"session":-1,"epoch":-1,"world_generation":last_uploaded_world_generation,
		"material_revision":last_uploaded_revision,"upload_serial":last_uploaded_render_snapshot_serial,
		"material_native_tick":_cadence_upload.get("native_tick",-1),
		"mask_native_tick":frame.get("tick",-1),"mask_sample_tick":frame.get("sample_tick",-1),
		"native_tick":latest_snapshot.tick_index if latest_snapshot != null else -1,
		"rapier_step":physical_actor_session.tick if physical_actor_session != null else -1,
		"snapshot_blend":blend,"previous_blend_active":blend < 1.0,"material_timing":material_timing,
		"draw_usec":started_usec,
		"current_texture_id":_material_publication_rid(texture).get_id(),
		"previous_texture_id":_material_publication_rid(previous_texture).get_id(),
		"deadline_usec":started_usec+maxi(0,PRESENTATION_FRAME_TIME_BUDGET_USEC-cache_usec),
		"valid":false,"reason":"invalid_frame","resolve_usec":0,"upload_cache_usec":cache_usec,
		"dry_region_status":_workbench_dry_region_status,"patch_count":_material_pending_rectangles.size()/RENDER_PATCH_METADATA_STRIDE}
	var summary: Dictionary = {"safe_live":0,"blocked_material":0,"blocked_unknown":0,
		"blocked_other":0,"budget_vetoes":0,"cells_examined":_presentation_pending_clearance_cells,"elapsed_usec":0,
		"intentional_holds":0,"withheld":0,"refined_queries":0,"refined_clear":0,
		"water_coverage_reuses":0}
	_presentation_pending_clearance_cells = 0
	var bridge: Variant = physical_actor_session.bridge if physical_actor_session != null else null
	var identity: Array = [bridge._session,bridge._epoch,last_uploaded_world_generation] \
		if bridge is WorkbenchBridge else []
	if identity != _workbench_presentation_identity or mode != _workbench_presentation_policy:
		if identity != _workbench_presentation_identity \
				and (not workbench_presentation_submission_enabled() or identity != _workbench_observation_identity):
			_workbench_presentation_history.clear()
			_workbench_observation_identity = identity.duplicate()
		_workbench_presentation_state.clear()
		_workbench_follow_state.clear()
		_workbench_presentation_identity = identity
		_workbench_presentation_policy = mode
		_workbench_presentation_turn = 0
	if bridge is WorkbenchBridge:
		resolved.session = bridge._session
		resolved.epoch = bridge._epoch
	if _valid_workbench_mask_frame(frame) and image != null:
		resolved.mask_frame = frame
		resolved.valid = true
		resolved.reason = "resolved"
		var material_contents: Array[int] = _workbench_visible_material_contents(resolved.previous_blend_active)
		resolved["material_contents"] = material_contents.duplicate()
		var legacy_poses: Dictionary = _safe_workbench_presentation_poses(frame,resolved.previous_blend_active) if mode != "coherent" else {}
		# Every actor receives the first opportunity once per complete rotation.
		# A permanently unsafe, unadmitted body must not stay ahead of retained
		# or suppressed peers and monopolize the shared guard deadline forever.
		var admission_order: Array[int] = []
		for offset: int in range(bridge._members.size()):
			var slot: int = (offset+_workbench_presentation_turn) % bridge._members.size()
			admission_order.append(slot)
		_workbench_presentation_turn = (_workbench_presentation_turn+1) % maxi(bridge._members.size(),1)
		var initial_water: Dictionary = _initial_workbench_water_coverage(frame,resolved,summary,bridge,admission_order) \
			if paused and _workbench_presentation_state.is_empty() else {}
		var no_coverage: Dictionary = {}
		for slot: int in admission_order:
			var member: Dictionary = bridge._members[slot]
			var entry: Dictionary = frame.instances.get(int(member.instance_id),{})
			resolved.sources[slot] = "hidden"
			resolved.reasons[slot] = "actor_receipt_invalid"
			resolved.desired_steps[slot] = physical_actor_session.tick
			resolved.intentional_holds[slot] = false
			resolved.timeline_resets[slot] = false
			resolved.hold_age_usec[slot] = 0
			resolved.recovery_attempts[slot] = 0
			resolved.explicit_reentries[slot] = false
			if entry.get("generation",-1) != member.generation or not entry.get("pose") is Transform2D \
					or not Transform2D(entry.pose).is_finite():
				continue
			var bound: Transform2D = entry.pose
			var bound_sample: Dictionary = _workbench_bound_sample(entry)
			var bound_step: int = int(bound_sample.get("step",-1))
			if bound_step > physical_actor_session.tick:
				resolved.reasons[slot] = "future_native_sample"
				continue
			if mode != "coherent":
				resolved.poses[slot] = legacy_poses.get(slot,bound)
				resolved.sources[slot] = "live" if legacy_poses.has(slot) else "mask_bound"
				resolved.selected_steps[slot] = physical_actor_session.tick if legacy_poses.has(slot) else bound_step
				resolved.reasons[slot] = _workbench_pose_trace_reasons.get(slot,workbench_presentation_last.status)
				continue
			var desired: Transform2D = bridge.body_transform(slot)
			var desired_observation: Dictionary = _observe_workbench_presentation(slot)
			var previous: Dictionary = _workbench_presentation_state.get(slot,{})
			if previous.get("instance_id",member.instance_id) != member.instance_id \
					or previous.get("generation",member.generation) != member.generation:
				previous = {}
			var initial: bool = previous.is_empty()
			var first_coverage: Dictionary = no_coverage
			if initial and initial_water.has(slot) and initial_water[slot].pose == desired and bound == desired:
				first_coverage = initial_water[slot].coverage
			resolved.timeline_resets[slot] = initial
			var anchor: Transform2D = bound if initial else previous.pose
			var recovering: bool = not initial and int(previous.get("withheld_frames",0)) == 0 \
				and int(previous.step) < int(previous.get("desired_step",previous.step))
			var ceiling: int = physical_actor_session.tick
			var target: Transform2D = desired
			var target_step: int = physical_actor_session.tick
			var target_observation: Dictionary = desired_observation
			if recovering:
				# Repay at most ONE extra physical step per graphical submission.
				# This adds no normal live delay, preserves actual fast movement,
				# and cannot convert accumulated hold lag into an instant snap.
				ceiling = mini(physical_actor_session.tick,int(previous.step)
					+maxi(0,physical_actor_session.tick-int(previous.desired_step))+1)
				target_observation = _workbench_presentation_history.newest_after_through(
					slot,int(previous.step),ceiling)
				if not target_observation.is_empty():
					target = target_observation.pose
					target_step = int(target_observation.step)
			resolved.recovery_ceilings[slot] = ceiling
			var certificate_valid: bool = not initial and not previous.get("water_composed",false) \
				and _workbench_material_certificate_covers(previous.get("material_contents",[]),material_contents)
			var selected: Variant = null
			var selected_step: int = -1
			var selected_observation: Dictionary = {}
			var hold_started_usec: int = int(previous.get("hold_started_usec",0))
			var reason: String = ""
			var decision: Dictionary
			if not initial and int(previous.step) > physical_actor_session.tick:
				decision = {"safe":false,"reason":"rapier_step_regressed"}
			elif recovering and target_observation.is_empty():
				decision = {"safe":false,"reason":"recovery_history_missing"}
			elif recovering and not _workbench_recovery_time_valid(target_observation,started_usec,physical_actor_session.tick):
				decision = {"safe":false,"reason":"recovery_time_unknown" if int(target_observation.get("completed_usec",0)) <= 0 else "recovery_age_expired"}
			elif certificate_valid and anchor == target:
				decision = {"safe":true,"reason":"same_presented_pose"}
			elif not _workbench_dry_region.is_empty() and not _presentation_previous_unknown \
					and _workbench_dry_region.world == last_uploaded_world_generation \
					and _workbench_dry_region.session == bridge._session and _workbench_dry_region.epoch == bridge._epoch \
					and _workbench_dry_region.current == _presentation_current_content_id \
					and _workbench_dry_region.previous == _presentation_previous_content_id \
					and WorkbenchPresentationCoherence.empty_region_covers_sweep(
						_workbench_dry_region.area,anchor,target,bridge._rects[slot]):
				decision = {"safe":true,"reason":"empty_published_region"}
			else:
				# Prove the actual current physical/native authority FIRST, then
				# ask the Water-compatible guard once. An empty-only guard would
				# inevitably reject Water, spend its refinement budget and starve
				# this same valid composition or a later member. The compatible
				# guard still scans both immutable histories, refuses hard material,
				# retains the same sweep/cell/time bounds and creates no completion.
				if _workbench_water_composition_enabled() and target_step == physical_actor_session.tick \
						and target == desired:
					var water_proof: Dictionary = _workbench_water_dependency(slot,frame,entry,desired_observation)
					if not water_proof.is_empty():
						# Exact COMPLETE image/sweep cache entries are checked before
						# the shared deadline. Any changed input requires a new scan.
						# Only an initial or actually withheld body may re-enter at
						# its endpoint; consecutive visible poses require the sweep.
						var water_reentry: bool = not initial and int(previous.get("withheld_frames",0)) > 0
						var water_start: Transform2D = desired if initial or water_reentry else anchor
						var water_check: Dictionary = first_coverage
						if water_check.is_empty() and water_proof.kind=="current_completed_native_dependency" \
								and (not paused or previous.get("contact_clipped",false)) and not recovering \
								and (not resolved.previous_blend_active or not _presentation_previous_unknown) and not material_contents.is_empty() \
								and resolved.current_texture_id!=0 and (not resolved.previous_blend_active or resolved.previous_texture_id!=0):
							# Independent native authority applies the actual physical endpoint.
							# The texture-backed clip cannot legalize a jump across a wall:
							# test the prior presented pose even after a withheld draw.
							var contact := WorkbenchPresentationCoherence.contact_sweep(anchor,desired,bridge._rects[slot],
								image,_presentation_previous_image,resolved.previous_blend_active,
								PRESENTATION_FRAME_SCAN_BUDGET-int(summary.cells_examined),resolved.deadline_usec)
							summary.cells_examined+=int(contact.scanned)
							if contact.has("contact_cell"): resolved.contact_cells[slot]=contact.contact_cell
							if contact.safe:
								water_check=contact
								if contact.has("clip"): resolved.contact_clips[slot]=contact.clip
						if water_check.is_empty():
							water_check=_assess_workbench_water_sweep(slot,water_start,
								desired,bridge._rects[slot],resolved,summary)
						decision = water_check
						if bool(water_check.safe):
							if water_check.get("coverage_reused",false):
								_workbench_water_coverage_cache_hits += 1
								summary.water_coverage_reuses += 1
							resolved.explicit_reentries[slot] = water_reentry
							# A complete Empty proof needs no Water layer or native
							# composition exception. Keep its ordinary certificate,
							# including across unchanged dry frames.
							if resolved.contact_clips.has(slot) or bool(water_check.get("water_in_bounds",false)) or int(water_check.get("water_contacts",0)) > 0:
								water_proof["coverage"] = water_check.duplicate()
								water_proof.coverage.erase("clip")
								resolved.water_proofs[slot] = water_proof
								decision = {"safe":true,"reason":("material_clipped:" if resolved.contact_clips.has(slot) else "water_composed:")+str(water_proof.kind)}
				# Certify only the motion since the last presented state. Old
				# material behind that state cannot invalidate elapsed motion.
				if decision.is_empty():
					if recovering: resolved.recovery_attempts[slot] += 1
					# A rejected Water-compatible check on the same endpoint cannot
					# justify an empty-only fallback. Never repeat that refusal.
					decision = first_coverage if not first_coverage.get("safe",true) else _assess_workbench_presented_sweep(anchor,target,bridge._rects[slot],resolved,summary)
			if bool(decision.safe):
				selected = target
				selected_step = target_step
				selected_observation = target_observation
				resolved.sources[slot] = "history" if target_step < physical_actor_session.tick else "live"
				if target_step == physical_actor_session.tick: summary.safe_live += 1
				reason = "paced_observed_recovery" if recovering else str(decision.reason)
			else:
				reason = str(decision.reason)
				if reason == "material_in_swept_mask": summary.blocked_material += 1
				elif reason == "previous_texture_unbounded": summary.blocked_unknown += 1
				else: summary.blocked_other += 1
				# A small ordered history can advance through a genuinely observed
				# clear prefix when the newest pose is blocked. Every proposed
				# displayed endpoint is swept from the last displayed pose, under
				# the SAME shared budget; never invent or smooth an unchecked pose.
				if not initial and reason in ["material_in_swept_mask","bounded_pose_delta"]:
					for observed: Dictionary in _workbench_presentation_history.recovery_candidates(
							slot,int(previous.step),mini(physical_actor_session.tick,ceiling+1)):
						if int(resolved.recovery_attempts[slot]) >= WorkbenchPresentationHistory.RECOVERY_ATTEMPTS: break
						if not _workbench_recovery_time_valid(observed,started_usec,physical_actor_session.tick): break
						resolved.recovery_attempts[slot] += 1
						var recovery: Dictionary = _assess_workbench_presented_sweep(
							anchor,observed.pose,bridge._rects[slot],resolved,summary)
						if not bool(recovery.safe): break
						selected = observed.pose
						selected_step = int(observed.step)
						selected_observation = observed
						resolved.sources[slot] = "history"
						reason = "safe_observed_prefix"
				# A native receipt is a timestamped endpoint, not proof of the
				# route from a retained actor. Consecutively visible frames must
				# prove that route too. Endpoint-only re-entry is an explicit
				# discontinuity following at least one withheld submission.
				var bound_can_advance: bool = bound_step >= 0 and (initial or bound_step > int(previous.step))
				var bound_observation: Dictionary = bound_sample
				# A native receipt identifies an endpoint, not fresh presentation time.
				# Its clock applies on FIRST refusal as well as recovery/re-entry:
				# neither the initial path nor a previous visible frame can bypass
				# expiration for a noncurrent physical step.
				if bound_can_advance and bound_step < physical_actor_session.tick \
						and not _workbench_recovery_time_valid(
							bound_observation,started_usec,physical_actor_session.tick):
					bound_can_advance = false
				if recovering and bound_step > ceiling:
					bound_can_advance = false
				if selected == null and bound_can_advance and reason != "rapier_step_regressed":
					var reentry: bool = not initial and int(previous.get("withheld_frames",0)) > 0
					var bound_start: Transform2D = bound if initial or reentry else anchor
					var bound_check: Dictionary = first_coverage if not first_coverage.get("safe",true) else _assess_workbench_presented_sweep(bound_start,bound,bridge._rects[slot],resolved,summary)
					if bool(bound_check.safe):
						selected = bound
						selected_step = bound_step
						selected_observation = bound_observation
						resolved.sources[slot] = "mask_bound"
						resolved.explicit_reentries[slot] = reentry
						reason = "native_receipt_initial" if initial else ("native_receipt_reentry" if reentry else "native_receipt_swept")
				if selected == null and not initial and int(previous.get("withheld_frames",0)) > 0 \
						and physical_actor_session.tick >= int(previous.step) and reason != "rapier_step_regressed":
					# Once an actual submission has withheld the body, a known
					# current endpoint may reappear if its FULL footprint is clear
					# in both visible textures. This explicit degraded transition
					# avoids waiting forever for an evicted or stopped native sample.
					var live_check: Dictionary = _assess_workbench_presented_sweep(
						desired,desired,bridge._rects[slot],resolved,summary)
					if bool(live_check.safe):
						selected = desired
						selected_step = physical_actor_session.tick
						selected_observation = desired_observation
						resolved.sources[slot] = "live"
						resolved.explicit_reentries[slot] = true
						reason = "explicit_live_reentry"
				if selected == null and not initial and reason != "rapier_step_regressed" \
						and int(previous.get("withheld_frames",0)) == 0:
					if hold_started_usec <= 0: hold_started_usec = started_usec
					resolved.hold_age_usec[slot] = maxi(0,started_usec-hold_started_usec)
					var submitted_water: Dictionary = _submitted_water_hold(slot,previous,resolved) if previous.get("water_composed",false) else {}
					var held_clear: bool = certificate_valid or not submitted_water.is_empty()
					if not held_clear:
						var held_check: Dictionary = _assess_workbench_presented_sweep(anchor,anchor,bridge._rects[slot],resolved,summary)
						held_clear = bool(held_check.safe)
					var held_observation: Dictionary = previous.get("observation",{})
					# Recheck the timestamp on EVERY submitted frame. Withholding
					# clears recovering but must never renew an expired historical
					# pose by starting a fresh hold timer. A genuinely current
					# physical step is exempt (e.g. a paused simulation).
					# A pose that was selected while physically current may be
					# retained for ONE short certified hold, timed from its first
					# material refusal. That is not historical playback. Poses
					# first selected from history still require their completion
					# age, even if a later withheld frame resets recovery.
					var held_time_valid: bool = int(previous.step) == physical_actor_session.tick \
						or bool(previous.get("origin_current",false)) \
						or (int(held_observation.get("step",-1)) == int(previous.step) \
							and _workbench_recovery_time_valid(
								held_observation,started_usec,physical_actor_session.tick))
					if held_clear and held_time_valid and reason != "recovery_age_expired" \
							and int(resolved.hold_age_usec[slot]) < WorkbenchPresentationHistory.MAX_HOLD_USEC:
						selected = anchor
						selected_step = int(previous.step)
						selected_observation = held_observation
						resolved.sources[slot] = "held"
						if not submitted_water.is_empty():
							resolved.water_proofs[slot] = submitted_water
						resolved.intentional_holds[slot] = true
						summary.intentional_holds += 1
					elif held_clear and not held_time_valid:
						reason = "held_observation_time_unknown" \
							if int(held_observation.get("completed_usec",0)) <= 0 \
							else "held_observation_age_expired"
					elif int(resolved.hold_age_usec[slot]) >= WorkbenchPresentationHistory.MAX_HOLD_USEC:
						reason = "hold_expired:"+reason
					previous.hold_started_usec = hold_started_usec
			resolved.reasons[slot] = reason
			if selected != null:
				if not initial and int(previous.get("withheld_frames",0)) > 0:
					resolved.explicit_reentries[slot] = true
				resolved.poses[slot] = selected
				resolved.selected_steps[slot] = selected_step
				# A held/unchanged pose retains its already checked contents. A new
				# pose receives only the contents this frame's sweep actually checked.
				var certified_contents: Array = previous.get("material_contents",[]) \
					if certificate_valid and selected == anchor else material_contents
				resolved.selected_observations[slot] = selected_observation
				_workbench_presentation_state[slot] = {"pose":selected,"step":selected_step,
					"desired_step":physical_actor_session.tick,
					"instance_id":member.instance_id,"generation":member.generation,"material_contents":certified_contents.duplicate(),
					"observation":selected_observation,"withheld_frames":0,
					"water_composed":resolved.water_proofs.has(slot),"contact_clipped":resolved.contact_clips.has(slot),
					"water_coverage_identity":(previous.get("water_coverage_identity",{}) if resolved.sources[slot] == "held"
						else _workbench_water_coverage_cache.get(slot,{}).get("identity",{})) if resolved.water_proofs.has(slot) and not resolved.contact_clips.has(slot) and not previous.get("contact_clipped",false) else {},
					"origin_current":bool(previous.get("origin_current",false)) \
						if resolved.sources[slot] == "held" else selected_step == physical_actor_session.tick,
					"hold_started_usec":hold_started_usec if resolved.sources[slot] == "held" else 0}
			else:
				summary.withheld += 1
		# Remove withheld instances from a copied render receipt. render_parts'
		# strict path cannot silently substitute a bound pose for a missing
		# selected pose. The unmodified receipt remains available to tracing.
		var render_frame: Dictionary = frame.duplicate()
		render_frame.instances = frame.instances.duplicate()
		for slot: int in range(bridge._members.size()):
			if not resolved.poses.has(slot): render_frame.instances.erase(int(bridge._members[slot].instance_id))
		resolved.parts = physical_actor_session.render_parts(render_frame,resolved.poses,true)
		if not resolved.water_proofs.is_empty():
			resolved.water_composition = {"enabled":true,"current_texture":texture,
				"previous_texture":previous_texture,"world_size":image.get_size(),
				"previous_active":resolved.previous_blend_active,"snapshot_blend":resolved.snapshot_blend}
			for part: Dictionary in resolved.parts:
				part["water_composed"] = resolved.water_proofs.has(int(part.get("physical_body_index",
					part.get("water_body_index",-1))))
		var pilot_slot: int = physical_actor_session.slot_for_instance(int(resolved.follow_instance_id))
		var pilot_body: int = bridge.actor_body_index(pilot_slot)
		if resolved.poses.has(pilot_body):
			resolved.follow_target = resolved.poses[pilot_body].origin
			resolved.follow_source_step = resolved.selected_steps.get(pilot_body,-1)
			_workbench_follow_state = {"instance_id":resolved.follow_instance_id,
				"position":resolved.follow_target,"step":resolved.follow_source_step}
	if mode == "coherent":
		for slot: int in _workbench_presentation_state:
			if not resolved.poses.has(slot):
				_workbench_presentation_state[slot].desired_step = physical_actor_session.tick
				_workbench_presentation_state[slot].withheld_frames = int(
					_workbench_presentation_state[slot].get("withheld_frames",0))+1
	if not Vector2(resolved.follow_target).is_finite() \
			and _workbench_follow_state.get("instance_id",-1) == resolved.follow_instance_id:
		resolved.follow_target = _workbench_follow_state.position
		resolved.follow_source_step = _workbench_follow_state.step
		resolved.follow_held = true
	if mode != "coherent" and shared_workbench != null:
		# Baseline Follow deliberately retains its independently sampled live
		# target. Trace that actual target, not the selected overlay position.
		var pilot: Dictionary = shared_workbench.body_state(int(resolved.follow_instance_id))
		resolved.follow_target = pilot.get("position",Vector2.INF)
		resolved.follow_source_step = physical_actor_session.tick if physical_actor_session != null else -1
		resolved.follow_held = false
	resolved.selection_usec = Time.get_ticks_usec()-started_usec
	resolved.resolve_usec = resolved.selection_usec+cache_usec
	if mode == "coherent" or not resolved.valid:
		summary.elapsed_usec = resolved.resolve_usec
		workbench_presentation_totals.frames += 1
		for key: String in summary:
			workbench_presentation_totals[key] = int(workbench_presentation_totals.get(key,0))+int(summary[key])
		summary.status = "coherent" if resolved.valid else "invalid_frame"
		workbench_presentation_last = summary
	_workbench_pose_trace_reasons = resolved.reasons
	workbench_presentation_frame = resolved
	return resolved


func _resolve_workbench_camera_mapping() -> void:
	_workbench_mapping_locked = false
	var content: Rect2 = view_content_rect()
	var screen: Transform2D = _world_view_screen_transform()
	var mapping: Transform2D = presentation_camera_screen_transform()
	workbench_presentation_frame.merge({"camera_requested":camera_origin,"camera_mapping":mapping,
		"camera_origin":PixelCamera.screen_to_world(screen*content.position,mapping),
		"screen_transform":screen,"content_rect":content,"view_size":current_view_size},true)
	_workbench_mapping_locked = true


func _submit_workbench_presentation_frame() -> void:
	var resolved: Dictionary = workbench_presentation_frame
	if shared_workbench.actor_interaction != null:
		shared_workbench.actor_interaction.present_mapping(resolved.screen_transform.affine_inverse() * resolved.camera_mapping)
	physical_actor_overlay.present(resolved.parts,resolved.camera_origin,resolved.view_size,resolved.content_rect,
		resolved.get("water_composition",{}))
	if _owner_gameplay != null and not _workbench_submission_preparing:
		_owner_gameplay.presentation(self,resolved,"stock_overlay_applied")
	if not _workbench_submission_preparing and workbench_pose_trace.active and physical_actor_session != null:
		_workbench_trace_presentation_frame(resolved.original_mask_frame,resolved.mask_frame,
			resolved.poses,resolved.parts,resolved.camera_origin,resolved.content_rect)


func workbench_presentation_submission_enabled() -> bool:
	return _workbench_submission != null and shared_workbench != null \
		and _workbench_submission_requested and _workbench_submission._alive


func workbench_presentation_submission_status() -> Dictionary:
	return _workbench_submission.status() if _workbench_submission != null else {
		"schema":WorkbenchPresentationSubmission.SCHEMA,"enabled":false,
		"connected":false,"candidate_ready":false,"committed_count":0,
		"requested":_workbench_submission_requested,"refusal":_workbench_submission_refusal,
		"engine_atomic_admission":WorkbenchPresentationSubmission.atomic_admission_supported()}


func _workbench_presentation_bookkeeping() -> Dictionary:
	return {"state":_workbench_presentation_state,"identity":_workbench_presentation_identity,
		"policy":_workbench_presentation_policy,"turn":_workbench_presentation_turn,
		"follow":_workbench_follow_state,"totals":workbench_presentation_totals,
		"last":workbench_presentation_last,"frame":workbench_presentation_frame,
		"reasons":_workbench_pose_trace_reasons,"cache_usec":_presentation_pending_cache_usec,
		"clearance_cells":_presentation_pending_clearance_cells,
		"camera_request":camera_origin,"view_request":current_view_size,
		"focus_pending":shared_workbench._focus_pending if shared_workbench != null else false}


func _install_workbench_presentation_bookkeeping(state: Dictionary) -> void:
	_workbench_presentation_state = state.state
	_workbench_presentation_identity = state.identity
	_workbench_presentation_policy = state.policy
	_workbench_presentation_turn = state.turn
	_workbench_follow_state = state.follow
	workbench_presentation_totals = state.totals
	workbench_presentation_last = state.last
	workbench_presentation_frame = state.frame
	_workbench_pose_trace_reasons = state.reasons
	_presentation_pending_cache_usec = state.cache_usec
	_presentation_pending_clearance_cells = state.clearance_cells
	camera_origin = state.camera_request
	current_view_size = state.view_request
	if shared_workbench != null: shared_workbench._focus_pending = state.focus_pending


func _workbench_presentation_submission_fence() -> Dictionary:
	var bridge: Variant = physical_actor_session.bridge if physical_actor_session != null else null
	var members: Array = []
	if bridge is WorkbenchBridge:
		for slot: int in bridge._members.size():
			var member: Dictionary = bridge._members[slot]
			members.append([member.instance_id,member.generation,bridge.body_transform(slot),
				bridge._body_rids[slot].get_id(),bridge._rects[slot]])
	return {"engine_admission":WorkbenchPresentationSubmission.atomic_admission_supported(),
		"owner":get_instance_id(),"worker":simulation_worker.get_instance_id(),
		"physical_owner":physical_actor_session.get_instance_id() if physical_actor_session != null else 0,
		"bridge":bridge.get_instance_id() if bridge != null else 0,
		"world":[last_uploaded_world_generation,world_extent],
		"session":[bridge._session,bridge._epoch] if bridge is WorkbenchBridge else [],
		"physical_completion":[physical_actor_session.tick if physical_actor_session != null else -1,
			_workbench_completed_step,_workbench_completed_step_usec],
		"members":members,"selected":shared_workbench.selected_id() if shared_workbench != null else -1,
		"material":[last_uploaded_revision,last_uploaded_render_snapshot_serial,
			_presentation_current_content_id,_presentation_previous_content_id,
			_presentation_current_content_shape,_presentation_previous_content_shape,
			_material_publication_rid(texture).get_id(),_material_publication_rid(previous_texture).get_id(),
			_presentation_previous_unknown],
		"policy":[_workbench_presentation_mode(),_material_publication_mode,
			_material_publication_fallback,cadence_lod_enabled,render_snapshot_hz,
			OS.get_environment("CYBERSAND_DIAG_MATERIAL_TIMING"),
			OS.get_environment("CYBERSAND_DIAG_ACTUAL_SUBMISSION"),
			OS.get_environment("CYBERSAND_DIAG_WATER_COMPOSITION"),
			OS.get_environment("CYBERSAND_SOURCE_REVISION")],
		"camera":[camera_origin,current_view_size,view_content_rect(),_world_view_screen_transform(),
			shared_workbench._camera.selected if shared_workbench != null else -1,
			shared_workbench._focus_pending if shared_workbench != null else false],
		"lifecycle":[paused,_physical_epoch,_actor_reset_receipt,_workbench_frame_error,
			pending_microscenario_apply,simulation_worker.has_failed(),_playable_recovery_queued,
			_pending_physical_candidate.get_instance_id() if _pending_physical_candidate != null else 0,
			shared_workbench.step_pending if shared_workbench != null else false]}


func _prepare_workbench_presentation_candidate(delta: float, supplied: Dictionary = {}) -> void:
	if not workbench_presentation_submission_enabled() or _workbench_submission_preparing: return
	var preparation_started: int = Time.get_ticks_usec()
	# Run the existing selection against a private copy of last SUBMITTED
	# bookkeeping. Its guard results stage canvas commands, but a skipped idle
	# turn cannot become a visible hold, recovery, Follow or fairness turn.
	var submitted: Dictionary = _workbench_presentation_bookkeeping()
	_install_workbench_presentation_bookkeeping(submitted.duplicate(true))
	_workbench_submission_preparing = true
	_workbench_mapping_locked = false
	_resolve_workbench_presentation_frame(workbench_display_frame() if supplied.is_empty() else supplied)
	update_camera(delta)
	_resolve_workbench_camera_mapping()
	update_brush_preview()
	_present_playable_course_targets()
	actor_prototype_overlay.present(
		latest_snapshot.actor_prototypes if latest_snapshot != null else {},
		presentation_camera_origin(),current_view_size,view_content_rect())
	usable_overlay.present(
		(latest_snapshot.physical_usables if physical_actor_session != null else latest_snapshot.actor_usables)
			if latest_snapshot != null else {},presentation_camera_origin(),current_view_size,view_content_rect())
	_submit_workbench_presentation_frame()
	update_shader_parameters()
	var staged_frame: Dictionary = workbench_presentation_frame
	var next_state: Dictionary = _workbench_presentation_bookkeeping()
	_install_workbench_presentation_bookkeeping(submitted)
	_workbench_mapping_locked = false
	_workbench_submission_preparing = false
	_workbench_submission.stage(staged_frame,next_state,_workbench_presentation_submission_fence())
	_workbench_submission.record_preparation_cost(Time.get_ticks_usec()-preparation_started)


func _commit_workbench_presentation_submission(engine_admission: bool = false) -> Dictionary:
	if not workbench_presentation_submission_enabled(): return {}
	if not engine_admission:
		# The engine validated the returned receipt and allocated an actual draw
		# before emitting this ordinary signal. External observers run only now;
		# no callbacks can intervene between the direct admission and its receipt.
		if _workbench_submission_notification_pending:
			_workbench_submission_notification_pending = false
			var submitted: Dictionary = workbench_presentation_frame
			if _owner_gameplay != null:
				_owner_gameplay.presentation(self,submitted,"atomic_submission_accepted")
			if workbench_pose_trace.active and physical_actor_session != null:
				_workbench_trace_presentation_frame(submitted.original_mask_frame,submitted.mask_frame,
					submitted.poses,submitted.parts,submitted.camera_origin,submitted.content_rect)
			workbench_presentation_submitted.emit(submitted)
		return {}
	var accepted: Dictionary = _workbench_submission.take(_workbench_presentation_submission_fence())
	if accepted.is_empty(): return {}
	# This exact typed receipt is constructed before any visible-history commit.
	# Its fields come from the same immutable candidate and current owner/frame
	# checked above. The engine validates the handshake before calling us. There
	# is no fallible branch or external observer between commit and return.
	var receipt: Dictionary = {"accepted":true,"owner_instance":get_instance_id(),
		"submission_serial":int(accepted.frame.submission_serial),
		"candidate_serial":int(accepted.frame.candidate_serial),
		"process_frame":Engine.get_process_frames(),
		"submitted_usec":int(accepted.frame.submitted_usec),
		"source_revision":str(_workbench_submission.source_revision)}
	receipt.make_read_only()
	# Bookkeeping only. CanvasItem drawing, shader values and node transforms
	# were prepared BEFORE Main's message flush. The new engine refuses the
	# entire draw on an empty receipt: no stale canvas reaches the framebuffer,
	# no draw signals/token/frames_drawn are fabricated, and time is conserved.
	_install_workbench_presentation_bookkeeping(accepted.next_state)
	workbench_presentation_frame = accepted.frame
	_workbench_submission_notification_pending = true
	return receipt


func begin_workbench_pose_trace(settings: Dictionary = {}) -> bool:
	if shared_workbench == null or physical_actor_session == null or latest_snapshot == null: return false
	var identity: Dictionary = settings.duplicate(true)
	identity["source_commit"] = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	identity["pose_mode"] = OS.get_environment("CYBERSAND_DIAG_FLYER_POSE")
	identity["native_sha256"] = FileAccess.get_sha256("res://addons/cybersand_native/bin/" +
		("cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows"
			else "libcybersand_native.linux.x86_64.so"))
	identity["render_cadence_mode"] = "legacy" if _legacy_render_cadence() else "repaired"
	identity["fixed_physics_delta"] = rapier_bridge.fixed_delta()
	identity["native_rendezvous"] = native_rendezvous_status()
	identity["same_frame_continuation"] = same_frame_continuation_status()
	identity["clock_notice"] = "Rapier targets alter callbacks; fixed 1/60 steps are compared by simulation index. CPU upload ACK and frame_post_draw are not GPU fences or scanout."
	if not workbench_pose_trace.begin(identity): return false
	_cadence_physics_hold_counts.clear()
	if not simulation_worker.begin_render_cadence_trace():
		# Do not finish/drain a worker capture owned by another caller.
		workbench_pose_trace.finish()
		return false
	if not RenderingServer.frame_post_draw.is_connected(_cadence_frame_post_draw):
		RenderingServer.frame_post_draw.connect(_cadence_frame_post_draw)
	return true


func finish_workbench_pose_trace() -> Dictionary:
	if not workbench_pose_trace.active: return {}
	if RenderingServer.frame_post_draw.is_connected(_cadence_frame_post_draw):
		RenderingServer.frame_post_draw.disconnect(_cadence_frame_post_draw)
	var worker_events: Dictionary = simulation_worker.finish_render_cadence_trace()
	return workbench_pose_trace.finish(worker_events)


func _legacy_render_cadence() -> bool:
	return OS.get_environment("CYBERSAND_DIAG_RENDER_CADENCE") == "legacy"


func native_rendezvous_status() -> Dictionary:
	var overlap: bool = _workbench_native_rendezvous_selection == "render-overlap"
	var separate: bool = not RenderingServer.is_on_render_thread()
	return {"enabled":_workbench_native_rendezvous_enabled,
		"mode":"render-overlap" if overlap else ("fixed16" if _workbench_native_rendezvous_enabled else "off"),
		"max_frame_wait_usec":WorkbenchNativeRendezvous.MAX_RENDER_OVERLAP_WAIT_USEC if overlap else WorkbenchNativeRendezvous.MAX_FRAME_WAIT_USEC,
		"poll_usec":WorkbenchNativeRendezvous.POLL_USEC,
		"separate_render_thread":separate,
		"render_overlap_available":overlap and separate,
		"render_marker_meaning":"Earlier RenderingServer calls returned; not GPU completion, scanout or a draw identity.",
		"fixed_physics_delta":rapier_bridge.fixed_delta(),
		"waits_for_native_sample":engine_lab_wait_native_sample}


func _cadence_frame_post_draw() -> void:
	if not workbench_pose_trace.active: return
	# Separate rendering queues this signal back to Main. Delivery can occur
	# after another submission; Engine's current frame/serial is not the draw's
	# identity. Preserve delivery timing without inventing a same-frame join.
	var inline_render: bool = RenderingServer.is_on_render_thread()
	workbench_pose_trace.observe_event({"event":"framebuffer_draw",
		"time_usec":Time.get_ticks_usec(),
		"process_frame":Engine.get_process_frames() if inline_render else -1,
		"callback_process_frame":Engine.get_process_frames(),
		"draw_identity_associated":inline_render,
		"signal_delivery":"inline_main" if inline_render else "main_deferred",
		"rendered_frames":Engine.get_frames_drawn(),
		"render_serial":last_uploaded_render_snapshot_serial,
		"render_serial_is_current_submission":true})


func _cadence_physics_hold(reason: String, snapshot: CyberSimulationSnapshot = null) -> void:
	if _owner_gameplay != null and (physical_actor_session == null or rapier_bridge is WorkbenchBridge):
		_owner_gameplay.physics_hold(self,reason,snapshot)
	if not workbench_pose_trace.active: return
	_cadence_physics_hold_counts[reason] = int(_cadence_physics_hold_counts.get(reason,0))+1
	workbench_pose_trace.observe_event({"event":"rapier_hold","reason":reason,
		"time_usec":Time.get_ticks_usec(),"physics_frame":Engine.get_physics_frames(),
		"process_frame":Engine.get_process_frames(),
		"step":physical_actor_session.tick if physical_actor_session != null else -1,
		"waiting_body_sample":_workbench_wait_sample,
		"completed_body_sample":snapshot.lab_context.get("workbench_completed_sample",-1) if snapshot != null else -1,
		"required_hard_revision":snapshot.lab_context.get("workbench_hard_surface_revision",-1) if snapshot != null else -1,
		"packet_hard_revision":snapshot.hard_surface_revision if snapshot != null else -1,
		# This revision is queued, not installed, while pending chunks remain.
		"queued_hard_revision":last_hard_surface_revision,
		"pending_hard_chunks":rapier_bridge.pending_hard_surface_chunks(),
		"last_collider_call_usec":roundi(rapier_bridge.last_hard_surface_build_time_ms()*1000.0),
		"waits_for_native_sample":engine_lab_wait_native_sample})


func _cadence_rapier_completed(started_usec: int, completed_usec: int,
		snapshot: CyberSimulationSnapshot) -> void:
	if not workbench_pose_trace.active or physical_actor_session == null: return
	var bridge: Variant = physical_actor_session.bridge
	if not bridge is WorkbenchBridge: return
	var bodies: Array[Dictionary] = []
	for slot: int in range(mini(bridge._members.size(),WorkbenchPoseTrace.MAX_BODIES)):
		var pose: Transform2D = bridge.body_transform(slot)
		bodies.append({"slot":slot,"instance_id":int(bridge._members[slot].instance_id),
			"xy":WorkbenchPoseTrace.xy(pose.origin),"angle":pose.get_rotation(),
			"velocity":WorkbenchPoseTrace.xy(bridge.body_linear_velocity(slot))})
	workbench_pose_trace.observe_event({"event":"rapier_step","start_usec":started_usec,
		"time_usec":completed_usec,"observed_usec":Time.get_ticks_usec(),
		"step":physical_actor_session.tick,
		"session":bridge._session,"epoch":bridge._epoch,
		"world_generation":(snapshot.physics_world_generation if snapshot.physics_world_generation >= 0
			else snapshot.render_world_generation) if snapshot != null else -1,
		"physics_publication_usec":snapshot.physics_handoff_usec if snapshot != null else 0,
		"native_completed_usec":snapshot.last_native_tick_completed_usec if snapshot != null else -1,
		"fixed_delta":rapier_bridge.fixed_delta(),
		"solver_usec":roundi(rapier_bridge.last_step_time_ms()*1000.0),
		"flush_usec":roundi(rapier_bridge.last_flush_time_ms()*1000.0),
		"hard_surface_shapes":rapier_bridge.hard_surface_shape_count(),
		"pending_hard_chunks":rapier_bridge.pending_hard_surface_chunks(),
		"simulation_time_sec":physical_actor_session.tick*rapier_bridge.fixed_delta(),
		"native_tick_used":snapshot.tick_index if snapshot != null else -1,
		"native_response":_cadence_response_json(bridge.last_application),
		"input_tape_index":_engine_lab_last_replay_segment,"bodies":bodies})


func _cadence_response_json(application: Dictionary) -> Dictionary:
	# Retain admission/refusal counts without putting Variant Vector2 objects
	# into JSON or confusing a rejected stale response with an applied impulse.
	var responses: Array[Dictionary] = []
	for row: Dictionary in application.get("bodies",[]):
		responses.append({"id":row.get("id",-1),"sample":row.get("sample",-1),
			"age":row.get("age",-1),"refusal":row.get("refusal","")})
	return {"accepted":application.get("accepted",false),
		"refusal":application.get("refusal",""),"bodies":responses}


# The shader and overlay should agree spatially for *the same* actor pose;
# the separate bound/live fields identify a disagreement in simulation time.
func _workbench_trace_presentation_frame(original_frame: Dictionary,
		frame: Dictionary, admitted: Dictionary, parts: Array,
		presented_origin: Vector2, content: Rect2) -> void:
	var bridge: Variant = physical_actor_session.bridge
	if not bridge is WorkbenchBridge: return
	var screen: Transform2D = _world_view_screen_transform()
	var shader_map: Transform2D = presentation_camera_screen_transform()
	var unsnapped: Vector2 = screen*content.position \
		- shader_map.x*camera_origin.x-shader_map.y*camera_origin.y
	var first_parts: Dictionary = {}
	for part: Dictionary in parts:
		# Workbench admits exactly one rigid body per actor. The ordinary
		# rectangular/circular render_parts rows identify actor_id, whereas
		# rectangle unions additionally expose physical_body_index.
		var slot: int = int(part.get("physical_body_index",part.get("actor_id",-1)))
		if slot >= 0 and not first_parts.has(slot):
			first_parts[slot] = part
	var rows: Array = []
	var instances: Dictionary = frame.get("instances",{})
	for slot: int in range(mini(bridge._members.size(),WorkbenchPoseTrace.MAX_BODIES)):
		var member: Dictionary = bridge._members[slot]
		var receipt: Dictionary = instances.get(int(member.instance_id),{})
		var bound: Variant = receipt.get("pose",null)
		var live: Transform2D = bridge.body_transform(slot)
		var visible: bool = first_parts.has(slot)
		var selected: Variant = admitted.get(slot,null) if visible else null
		var source: String = str(workbench_presentation_frame.sources.get(slot,"hidden")) if visible else "hidden"
		var selected_projection: Variant = WorkbenchPoseTrace.projection(
			selected,presented_origin,content,current_view_size,screen,shader_map)
		var render_part: Variant = first_parts[slot].transform \
			if visible else null
		var part_projection: Variant = WorkbenchPoseTrace.projection(
			render_part,presented_origin,content,current_view_size,screen,shader_map)
		var observation: Dictionary = workbench_presentation_frame.selected_observations.get(slot,{})
		var completed_usec: int = int(observation.get("completed_usec",0))
		var sampled_usec: int = int(observation.get("sampled_usec",0))
		var age_origin: int = completed_usec if completed_usec > 0 else sampled_usec
		rows.append({"slot":slot,"instance_id":int(member.instance_id),
			"generation":int(member.generation),
			"receipt_generation":receipt.get("generation",-1),
			"source":source,"visible":visible,
			"presentation_step":workbench_presentation_frame.selected_steps.get(slot,-1),
			"presentation_time_sec":float(workbench_presentation_frame.selected_steps.get(slot,-1))*rapier_bridge.fixed_delta(),
			"desired_step":workbench_presentation_frame.desired_steps.get(slot,physical_actor_session.tick),
			"source_reason":workbench_presentation_frame.reasons.get(slot,"invalid_frame"),
			"intentional_hold":workbench_presentation_frame.intentional_holds.get(slot,false),
			"hold_age_usec":workbench_presentation_frame.hold_age_usec.get(slot,0),
			"selected_completed_usec":completed_usec,"selected_sampled_usec":sampled_usec,
			"selected_age_usec":maxi(0,Time.get_ticks_usec()-age_origin) if age_origin > 0 else -1,
			"selected_velocity":WorkbenchPoseTrace.xy(observation.velocity) if observation.get("velocity") is Vector2 else null,
			"selected_angular_velocity":observation.get("angular_velocity",null),
			"recovery_attempts":workbench_presentation_frame.recovery_attempts.get(slot,0),
			"recovery_step_ceiling":workbench_presentation_frame.recovery_ceilings.get(slot,physical_actor_session.tick),
			"explicit_reentry":workbench_presentation_frame.explicit_reentries.get(slot,false),
			"timeline_reset":workbench_presentation_frame.timeline_resets.get(slot,false),
			"onscreen_center":visible and selected is Transform2D and content.has_point(
				PixelCamera.world_to_local(selected.origin,presented_origin,current_view_size,content)),
			"guard_reason":str(_workbench_pose_trace_reasons.get(slot,
				workbench_presentation_last.get("status","not_evaluated"))),
			"bound":WorkbenchPoseTrace.pose_json(bound),
			"live":WorkbenchPoseTrace.pose_json(live),
			"selected":WorkbenchPoseTrace.pose_json(selected),
			"first_drawn_part":WorkbenchPoseTrace.pose_json(render_part),
			"screen_selected":selected_projection,
			"screen_first_part":part_projection,
			"selected_screen":selected_projection.get("overlay_px",null) \
				if selected_projection is Dictionary else null,
			"live_screen":WorkbenchPoseTrace.xy(shader_map*live.origin),
			"bound_screen":WorkbenchPoseTrace.xy(shader_map*bound.origin) \
				if bound is Transform2D and bound.is_finite() else null})
	var pilot_id: int = shared_workbench.selected_id()
	var pilot_state: Dictionary = shared_workbench.body_state(pilot_id) \
		if pilot_id > 0 else {}
	var pilot_position: Vector2 = pilot_state.get("position",Vector2.INF)
	var now_usec: int = Time.get_ticks_usec()
	var native_tick: int = latest_snapshot.tick_index if latest_snapshot != null else -1
	var snapshot_serial: int = latest_snapshot.serial if latest_snapshot != null else -1
	workbench_pose_trace.observe({"type":"frame","time_usec":now_usec,
		"presentation":{"policy":workbench_presentation_frame.policy,
			"session":workbench_presentation_frame.session,"epoch":workbench_presentation_frame.epoch,
			"world_generation":workbench_presentation_frame.world_generation,
			"material_contents":workbench_presentation_frame.get("material_contents",[]),
			"resolve_usec":workbench_presentation_frame.resolve_usec,
			"selection_usec":workbench_presentation_frame.selection_usec,
			"upload_cache_usec":workbench_presentation_frame.upload_cache_usec,
			"material_timing":workbench_presentation_frame.material_timing.duplicate(true),
			"follow_instance_id":workbench_presentation_frame.follow_instance_id,
			"follow_position":WorkbenchPoseTrace.xy(workbench_presentation_frame.follow_target) \
				if Vector2(workbench_presentation_frame.follow_target).is_finite() else null,
			"follow_source_step":workbench_presentation_frame.follow_source_step,
			"follow_held":workbench_presentation_frame.follow_held,
			"valid":workbench_presentation_frame.valid,"reason":workbench_presentation_frame.reason},
		"process_frame":Engine.get_process_frames(),
		"physics_frame":Engine.get_physics_frames(),
		"frame_delta_ms":frame_time_ms,
		"native_tick":native_tick,"native_snapshot_serial":snapshot_serial,
		"rapier_step":physical_actor_session.tick,
		"paused":paused,
		"camera_mode":shared_workbench._camera.selected,
		"pilot_instance_id":pilot_id,
		"pilot_live_position":WorkbenchPoseTrace.xy(pilot_position) \
			if pilot_position.is_finite() else null,
		"camera_requested":WorkbenchPoseTrace.xy(camera_origin),
		"camera_presented":WorkbenchPoseTrace.xy(presented_origin),
		"camera_screen_phase_px":WorkbenchPoseTrace.xy(shader_map.origin-unsnapped),
		"shader_world_zero_screen_px":WorkbenchPoseTrace.xy(shader_map.origin),
		"screen_transform_origin":WorkbenchPoseTrace.xy(screen.origin),
		"screen_basis_x":WorkbenchPoseTrace.xy(screen.x),
		"screen_basis_y":WorkbenchPoseTrace.xy(screen.y),
		"shader_basis_x":WorkbenchPoseTrace.xy(shader_map.x),
		"shader_basis_y":WorkbenchPoseTrace.xy(shader_map.y),
		"view_world_cells":[current_view_size.x,current_view_size.y],
		"content_rect":[content.position.x,content.position.y,content.size.x,content.size.y],
		"mask_receipt_original_valid":_valid_workbench_mask_frame(original_frame),
		"mask_receipt_render_valid":_valid_workbench_mask_frame(frame),
		"mask_session":frame.get("session",-1),
		"mask_epoch":frame.get("epoch",-1),
		"mask_world_generation":frame.get("world_generation",-1),
		"mask_revision":frame.get("revision",-1),
		"uploaded_world_generation":last_uploaded_world_generation,
		"uploaded_revision":last_uploaded_revision,
		"uploaded_render_serial":last_uploaded_render_snapshot_serial,
		"snapshot_received_usec":_cadence_received_usec,
		"native_snapshot_published_usec":latest_snapshot.worker_handoff_usec,
		"native_completed_usec":latest_snapshot.last_native_tick_completed_usec,
		"native_tick_wall_usec":latest_snapshot.last_native_tick_completed_usec-latest_snapshot.last_native_tick_started_usec,
		"native_scheduler_lateness_usec":latest_snapshot.last_native_tick_lateness_usec,
		"native_tick_body_sample":latest_snapshot.last_native_tick_body_sample,
		"offered_body_sample":latest_snapshot.offered_body_sample,
		"worker_step_time_ms":latest_snapshot.worker_step_time_ms,
		"native_tick_time_ms":latest_snapshot.simulation_time_ms,
		"mask_native_completed_usec":frame.get("native_completed_usec",-1),
		"render_snapshot_built_usec":_cadence_upload.get("generated_usec",-1),
		"upload_started_usec":_cadence_upload.get("start_usec",-1),
		"upload_completed_usec":_cadence_upload.get("completed_usec",-1),
		"upload_native_tick":_cadence_upload.get("native_tick",-1),
		"upload_full_refresh":_cadence_upload.get("full_refresh",false),
		"last_ack_issued_usec":_engine_lab_last_ack_usec,
		"last_ack_issued_serial":_engine_lab_last_ack_serial,
		"render_ack_pending":_engine_lab_pending_ack_serial,
		"worker_ack_serial":latest_snapshot.render_acknowledged_serial,
		"worker_ack_observed_usec":latest_snapshot.render_ack_observed_usec,
		"worker_pending_patch_bytes":latest_snapshot.render_pending_patch_bytes,
		"worker_pending_patch_count":latest_snapshot.render_pending_patch_count,
		"ack_gated_publication":latest_snapshot.render_publication_ack_gated,
		"ack_gate_holds":latest_snapshot.render_publication_gate_holds,
		"physics_hold_counts":_cadence_physics_hold_counts.duplicate(),
		"previous_texture_known":not _presentation_previous_unknown,
		"previous_texture_bytes":_presentation_previous_image.get_width()*_presentation_previous_image.get_height()*render_channels \
			if _presentation_previous_image != null else 0,
		"render_hz_target":render_snapshot_hz,
		"blend_active":workbench_presentation_frame.previous_blend_active,
		"snapshot_blend":workbench_presentation_frame.snapshot_blend,
		"guard":workbench_presentation_last.duplicate(true),
		"body_count":bridge._members.size(),
		"truncated_bodies":maxi(0,bridge._members.size()-WorkbenchPoseTrace.MAX_BODIES),
		"visible_part_count":parts.size(),"bodies":rows})


# This ACK releases retained CPU publication data after successful upload
# submission. ImageTexture.update returning is NOT a GPU completion fence.
func _issue_render_ack(serial: int, uploaded_usec: int = 0, due_frame: int = -1) -> void:
	if serial <= _engine_lab_last_ack_serial: return
	simulation_worker.acknowledge_render_snapshot(serial)
	_engine_lab_last_ack_serial = serial
	_engine_lab_last_ack_usec = Time.get_ticks_usec()
	if workbench_pose_trace.active:
		workbench_pose_trace.observe_event({"event":"render_ack","render_serial":serial,
			"time_usec":_engine_lab_last_ack_usec,"uploaded_usec":uploaded_usec,
			"due_frame":due_frame,"process_frame":Engine.get_process_frames()})


# Native render ACK is mandatory. Delay only an accepted, uploaded serial.
func _engine_lab_ack_uploaded_snapshot(serial: int) -> void:
	if engine_lab_ack_delay_frames == 0:
		_issue_render_ack(serial,Time.get_ticks_usec(),Engine.get_process_frames())
		return
	if not _legacy_render_cadence():
		var due: int = Engine.get_process_frames()+engine_lab_ack_delay_frames
		var pending: Dictionary = {"serial":serial,"due_frame":due,
			"uploaded_usec":Time.get_ticks_usec()}
		# Several uploads in a single process callback have the same deadline;
		# acknowledging its newest serial also retires its earlier uploads.
		for index: int in _engine_lab_ack_queue.size():
			if int(_engine_lab_ack_queue[index].due_frame)==due:
				_engine_lab_ack_queue[index] = pending
				_engine_lab_pending_ack_serial = maxi(_engine_lab_pending_ack_serial,serial)
				return
		_engine_lab_ack_queue.append(pending)
		_engine_lab_pending_ack_serial = maxi(_engine_lab_pending_ack_serial,serial)
		return
	# Same-source negative control: retained #609 restart-on-every-upload bug.
	_engine_lab_pending_ack_serial = maxi(_engine_lab_pending_ack_serial,serial)
	_engine_lab_pending_ack_frames = engine_lab_ack_delay_frames


func _engine_lab_pump_ack() -> void:
	if not _legacy_render_cadence():
		var waiting: Array[Dictionary] = []
		var frame: int = Engine.get_process_frames()
		for pending: Dictionary in _engine_lab_ack_queue:
			if int(pending.due_frame) <= frame:
				_issue_render_ack(int(pending.serial),int(pending.uploaded_usec),int(pending.due_frame))
			else:
				waiting.append(pending)
		_engine_lab_ack_queue = waiting
		_engine_lab_pending_ack_serial = 0
		for pending: Dictionary in waiting:
			_engine_lab_pending_ack_serial = maxi(_engine_lab_pending_ack_serial,int(pending.serial))
		return
	if _engine_lab_pending_ack_serial <= 0: return
	_engine_lab_pending_ack_frames -= 1
	if _engine_lab_pending_ack_frames > 0: return
	_issue_render_ack(_engine_lab_pending_ack_serial)
	_engine_lab_pending_ack_serial = 0
	_engine_lab_pending_ack_frames = 0


func engine_lab_set_ack_delay(frames: int) -> void:
	engine_lab_ack_delay_frames = clampi(frames,0,4)
	if engine_lab_ack_delay_frames == 0 and _engine_lab_pending_ack_serial > 0:
		_issue_render_ack(_engine_lab_pending_ack_serial)
		_engine_lab_pending_ack_serial = 0
		_engine_lab_pending_ack_frames = 0
		_engine_lab_ack_queue.clear()


func engine_lab_set_render_hz(target_hz: int) -> void:
	render_snapshot_hz = clampi(target_hz,1,1000)
	simulation_worker.set_render_snapshot_hz(render_snapshot_hz)
	snapshot_blend_start_usec = Time.get_ticks_usec()


func engine_lab_set_rapier_hz(target_hz: int) -> void:
	# The flight solver demands a fixed 1/60 simulation delta each step.
	# Deliberately change callback cadence only, not the physics step size:
	# non-60Hz settings therefore change wall-clock simulation speed.
	Engine.physics_ticks_per_second = clampi(target_hz,1,1000)


func engine_lab_begin_tape(segments: Array[Dictionary]) -> bool:
	if engine_lab_replay_active or engine_lab_scripted_input \
			or not OS.get_cmdline_user_args().has("--engine-lab-scripted") \
			or physical_actor_session == null or shared_workbench == null \
			or shared_workbench.pilot_id() != 1 or shared_workbench.pilot_slot < 0 \
			or latest_snapshot == null or simulation_worker.has_failed():
		return false
	var previous_tick: int = -1
	for segment: Dictionary in segments:
		if segment.size()!=2 or not segment.has_all(["tick","move"]) \
				or not segment.tick is int or int(segment.tick)<=previous_tick \
				or int(segment.tick)>120 or not segment.move is Array \
				or segment.move.size()!=2:
			return false
		for number: Variant in segment.move:
			if not (number is int or number is float) \
					or not is_finite(float(number)) or absf(float(number))>1.0:
				return false
		previous_tick=int(segment.tick)
	if segments.is_empty() or int(segments[0].tick)!=0: return false
	engine_lab_replay_tape=segments.duplicate(true)
	engine_lab_replay_events.clear()
	engine_lab_replay_error=""
	_engine_lab_last_replay_segment=-1
	engine_lab_replay_source_epoch=physical_actor_session.epoch
	engine_lab_replay_source_generation=int(latest_snapshot.render_world_generation)
	engine_lab_replay_tick_zero=physical_actor_session.tick
	engine_lab_replay_active=true
	return true


func _engine_lab_replay_workbench_input() -> void:
	if not engine_lab_replay_active: return
	if paused or physical_actor_session==null or simulation_worker.has_failed() \
			or latest_snapshot==null \
			or shared_workbench.pilot_id()!=1 \
			or physical_actor_session.epoch!=engine_lab_replay_source_epoch \
			or int(latest_snapshot.render_world_generation)!=engine_lab_replay_source_generation:
		engine_lab_replay_error="scripted_replay_actor_or_world_owner_changed"
		engine_lab_replay_active=false
		return
	var tick: int=physical_actor_session.tick
	var relative: int=tick-engine_lab_replay_tick_zero
	var selected: int=-1
	for i: int in engine_lab_replay_tape.size():
		if int(engine_lab_replay_tape[i].tick)<=relative: selected=i
		else: break
	if selected<0:
		engine_lab_replay_error="scripted_replay_tick_before_origin"
		engine_lab_replay_active=false
		return
	var entry: Dictionary=engine_lab_replay_tape[selected]
	var axis: Array=entry.move
	var accepted: bool=physical_actor_session.submit_workbench_action(
		1,{"move":Vector2(float(axis[0]),float(axis[1]))},
		{"q":false,"e":false,"s":false,"boost":false},false)
	if not accepted:
		engine_lab_replay_error="scripted_replay_command_refused_at_tick_%d_%s" % [
			relative,str(physical_actor_session.last_error)]
		engine_lab_replay_active=false
		return
	if selected!=_engine_lab_last_replay_segment:
		_engine_lab_last_replay_segment=selected
		engine_lab_replay_events.append({
			"input_index":selected,
			"requested_physical_tick":int(entry.tick),
			"accepted_physical_tick":relative,
			"session_tick":tick,
			"world_generation":engine_lab_replay_source_generation,
			"native_tick_at_admission":int(latest_snapshot.tick_index),
			"wall_usec":Time.get_ticks_usec(),
			"move":[float(axis[0]),float(axis[1])],
			"accepted_commands":physical_actor_session.accepted_commands,
			"actor_epoch":physical_actor_session.epoch})


func engine_lab_tape_receipt() -> Dictionary:
	return {"active":engine_lab_replay_active,
		"error":engine_lab_replay_error,
		"source_epoch":engine_lab_replay_source_epoch,
		"source_generation":engine_lab_replay_source_generation,
		"tick_zero":engine_lab_replay_tick_zero,
		"segments":engine_lab_replay_tape.duplicate(true),
		"events":engine_lab_replay_events.duplicate(true)}


func engine_lab_end_tape() -> void:
	engine_lab_replay_active=false


func engine_lab_set_scripted_input(enabled: bool) -> bool:
	if not enabled:
		engine_lab_scripted_input = false
		if physical_actor_session != null and shared_workbench != null:
			var slot: int = physical_actor_session.slot_for_instance(shared_workbench.pilot_id())
			if slot >= 0:
				physical_actor_session.cancel_input(slot,physical_actor_session.epoch,&"human")
		return true
	if shared_workbench == null or paused or physical_actor_session == null \
			or shared_workbench.pilot_slot < 0:
		return false
	engine_lab_scripted_input = true
	_engine_lab_scripted_start_tick = physical_actor_session.tick
	return true


# Retained original guarded policy for explicit baseline diagnostics. The
# coherent resolver above retains its visual timeline and may request bounded
# contact refinement; this original policy retains the coarse oracle pass.
func _safe_workbench_presentation_poses(frame: Dictionary, blend_active: bool) -> Dictionary:
	var poses: Dictionary = {}
	# The resolved frame needs an accurate source reason even when the trace
	# recorder is off, particularly after an interactive A/B policy switch.
	_workbench_pose_trace_reasons = {}
	workbench_presentation_last = {"status":"inactive","safe_live":0,
		"blocked_material":0,"blocked_unknown":0,"blocked_other":0,
		"budget_vetoes":0,"cells_examined":0,"elapsed_usec":0}
	if shared_workbench == null or paused or physical_actor_session == null or image == null:
		return poses
	if OS.get_environment("CYBERSAND_DIAG_FLYER_POSE") == "mask":
		workbench_presentation_last.status = "mask_baseline"
		return poses
	if not _valid_workbench_mask_frame(frame):
		workbench_presentation_last.status = "invalid_frame"
		return poses
	var bridge: Variant = physical_actor_session.bridge
	# Original keeps its source-selection policy, but must certify against the
	# same frozen blend that this presentation frame will submit to the shader.
	# Re-reading time here could drop old material at a crossfade boundary.
	var started_usec: int = Time.get_ticks_usec()
	var deadline_usec: int = started_usec + PRESENTATION_FRAME_TIME_BUDGET_USEC
	var summary: Dictionary = {"safe_live":0,"blocked_material":0,
		"blocked_unknown":0,"blocked_other":0,"budget_vetoes":0,
		"cells_examined":0,"elapsed_usec":0}
	var instances: Dictionary = frame.get("instances",{})
	for slot: int in range(bridge._members.size()):
		var member: Dictionary = bridge._members[slot]
		var entry: Dictionary = instances.get(int(member.instance_id),{})
		if entry.get("generation",-1) != member.generation or not entry.get("pose") is Transform2D:
			_workbench_pose_trace_reasons[slot] = "actor_receipt_invalid"
			summary.blocked_other += 1
			continue
		var bound_pose: Transform2D = entry.pose
		var live_pose: Transform2D = bridge.body_transform(slot)
		if bound_pose.is_equal_approx(live_pose):
			_workbench_pose_trace_reasons[slot] = "same_pose"
			continue
		var remaining: int = PRESENTATION_FRAME_SCAN_BUDGET-int(summary.cells_examined)
		if remaining <= 0 or Time.get_ticks_usec() >= deadline_usec:
			_workbench_pose_trace_reasons[slot] = "shared_budget"
			summary.budget_vetoes += 1
			summary.blocked_other += 1
			continue
		var decision: Dictionary = WorkbenchPresentationCoherence.assess(
			bound_pose,live_pose,bridge._rects[slot],image,
			_presentation_previous_occupied,_presentation_previous_unknown,blend_active,
			mini(remaining,WorkbenchPresentationCoherence.MAX_SCAN_CELLS),deadline_usec,
			_presentation_previous_image)
		_workbench_pose_trace_reasons[slot] = str(decision.reason)
		summary.cells_examined += int(decision.scanned)
		if decision.safe:
			poses[slot] = live_pose
			summary.safe_live += 1
		elif decision.reason == "material_in_swept_mask":
			summary.blocked_material += 1
		elif decision.reason == "previous_texture_unbounded":
			summary.blocked_unknown += 1
		else:
			if decision.reason in ["scan_budget","time_budget"]:
				summary.budget_vetoes += 1
			summary.blocked_other += 1
	summary.elapsed_usec = Time.get_ticks_usec()-started_usec
	workbench_presentation_totals.frames += 1
	for key: String in summary:
		workbench_presentation_totals[key] = int(workbench_presentation_totals.get(key,0)) + int(summary[key])
	summary["status"] = "guarded"
	workbench_presentation_last = summary
	return poses


func workbench_display_frame() -> Dictionary:
	if shared_workbench == null or latest_snapshot == null: return {}
	# Static material bytes can span multiple native ticks. Prefer the most
	# recent completed mask bound to the exact uploaded material revision.
	var frame: Dictionary = latest_snapshot.lab_context.get("workbench_display",{})
	if frame.get("world_generation",-1) == last_uploaded_world_generation and frame.get("revision",-1) == last_uploaded_revision:
		return frame
	# While newer material is waiting for upload, display the pose bound to
	# the visible upload. No matching receipt at startup falls back to Rapier.
	return _uploaded_workbench_frame


func _material_deadline_identity(snapshot: CyberSimulationSnapshot) -> Array:
	if shared_workbench == null or snapshot == null or snapshot.simulation_failed \
			or not pending_microscenario_apply.is_empty() or _pending_physical_candidate != null \
			or _actor_reset_receipt != 0:
		return []
	var generation: int = snapshot.physics_world_generation
	if generation < 0 or snapshot.render_world_generation != generation:
		return []
	if physical_actor_session != null:
		var bridge: Variant = physical_actor_session.bridge
		if not bridge is WorkbenchBridge or snapshot.rigid_body_epoch != bridge._epoch:
			return []
		var frame: Dictionary = snapshot.render_context.get("workbench_display", {})
		if frame.get("session", -1) != bridge._session or frame.get("epoch", -1) != bridge._epoch \
				or frame.get("world_generation", -1) != generation:
			return []
		return [bridge._session, bridge._epoch, generation]
	return [0, _body_owner_epoch(), generation] if snapshot.rigid_body_epoch == _body_owner_epoch() else []


func _offer_material_snapshot(snapshot: CyberSimulationSnapshot, now_usec: int = -1) -> void:
	if _material_steps.enabled() and not _material_step_publisher_supported():
		_retire_material_step_policy("publisher_changed")
	if _material_steps.enabled() and shared_workbench != null:
		_offer_material_step_snapshot(snapshot, now_usec)
		return
	if not _material_deadline.enabled() or shared_workbench == null:
		consume_render_snapshot(snapshot)
		return
	if snapshot.simulation_failed or simulation_worker.has_failed():
		_material_deadline.cancel("native_failure")
		return
	var identity: Array = _material_deadline_identity(snapshot)
	if identity.is_empty():
		# Transition transactions retain their original immediate material path.
		# An old deferred offer never survives a physical owner replacement.
		_material_deadline.cancel("owner_transition")
		consume_render_snapshot(snapshot)
		return
	var offered: bool = _material_deadline.offer(snapshot, identity,
		Time.get_ticks_usec() if now_usec < 0 else now_usec,
		last_uploaded_world_generation, last_uploaded_render_snapshot_serial)
	if not offered:
		var reason: String = _material_deadline.status().last_offer_result
		if reason in ["new_world_requires_full", "world_mismatch", "invalid_offer"]:
			last_render_patch_validation_error = "material deadline refused: " + reason
			reject_render_snapshot(snapshot)


func _drain_material_deadline(now_usec: int = -1) -> void:
	if not _material_deadline.enabled():
		return
	var identity: Array = _material_deadline_identity(latest_snapshot)
	if identity.is_empty() or simulation_worker.has_failed():
		_material_deadline.cancel("owner_transition_or_failure")
		return
	var selected: CyberSimulationSnapshot = _material_deadline.take_due(identity,
		Time.get_ticks_usec() if now_usec < 0 else now_usec)
	if selected == null:
		return
	var before_serial: int = last_uploaded_render_snapshot_serial
	consume_render_snapshot(selected)
	var accepted: bool = selected.render_snapshot_serial > before_serial \
		and last_uploaded_render_snapshot_serial == selected.render_snapshot_serial \
		and last_uploaded_world_generation == selected.render_world_generation
	_material_deadline.complete(selected, accepted,
		Time.get_ticks_usec() if now_usec < 0 else now_usec)


func material_deadline_status() -> Dictionary:
	return _material_deadline.status()


func _configure_material_steps() -> void:
	var reason: String = ""
	if _material_deadline.enabled():
		reason = "material_deadline_selected"
	elif OS.get_environment("CYBERSAND_MATERIAL_PUBLICATION") != "full":
		reason = "full_publication_required"
	elif OS.get_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS") not in ["", "2"]:
		reason = "two_slot_publication_required"
	_material_steps.configure(_material_step_interval, reason)


func _material_step_publisher_supported() -> bool:
	return _material_publication_mode in ["", "full"] \
		and _material_blit_publisher == null and _material_full_ring == null \
		and OS.get_environment("CYBERSAND_MATERIAL_PUBLICATION") == "full" \
		and OS.get_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS") in ["", "2"]


func _retire_material_step_policy(reason: String) -> void:
	var pending: bool = _material_steps.status().pending_count > 0
	_material_steps.configure(_material_step_interval, reason)
	if pending:
		# No abandoned offer is acknowledged. A paused owner must still emit a
		# fresh cumulative/full packet for the restored immediate path.
		simulation_worker.request_render_full_refresh()


func material_edit_admitted() -> void:
	if shared_workbench != null:
		_material_steps.mark_edit_admitted()


func _material_step_identity(snapshot: CyberSimulationSnapshot) -> Array:
	var identity: Array = _material_deadline_identity(snapshot)
	if identity.is_empty():
		return []
	# Session/epoch values alone do not identify a recreated owner object.
	identity.append(physical_actor_session.bridge.get_instance_id() if physical_actor_session != null else 0)
	return identity


func _material_step_completed_witness(identity: Array) -> Dictionary:
	if identity.size() != 4 or physical_actor_session == null or not physical_actor_session.active():
		return {}
	var bridge: Variant = physical_actor_session.bridge
	if not bridge is WorkbenchBridge or bridge != rapier_bridge or not bridge.is_initialized() \
			or identity != [bridge._session, bridge._epoch, last_uploaded_world_generation, bridge.get_instance_id()] \
			or physical_actor_session.tick != _workbench_completed_step \
			or _workbench_completed_step <= 0 or _workbench_completed_step_usec <= 0 \
			or bridge.manual_step_count() <= 0:
		return {}
	# _workbench_completed_step is written only after the sole Main owner's
	# real Rapier step and complete_step transaction. This is a read-only gate.
	return {"session_step":_workbench_completed_step,
		"rapier_step":bridge.manual_step_count(), "completed_usec":_workbench_completed_step_usec}


func _offer_material_step_snapshot(snapshot: CyberSimulationSnapshot, now_usec: int = -1) -> void:
	if snapshot.simulation_failed or simulation_worker.has_failed():
		_material_steps.cancel("native_failure")
		return
	var identity: Array = _material_step_identity(snapshot)
	if identity.is_empty():
		_material_steps.cancel("owner_transition")
		consume_render_snapshot(snapshot)
		return
	var offered: bool = _material_steps.offer(snapshot, identity,
		Time.get_ticks_usec() if now_usec < 0 else now_usec,
		last_uploaded_world_generation, last_uploaded_render_snapshot_serial)
	if not offered:
		var reason: String = _material_steps.status().last_offer_result
		if reason in ["new_world_requires_full", "world_mismatch", "invalid_offer"]:
			last_render_patch_validation_error = "material step policy refused: " + reason
			reject_render_snapshot(snapshot)


func _drain_material_steps(now_usec: int = -1) -> void:
	if not _material_steps.enabled():
		return
	if not _material_step_publisher_supported():
		_retire_material_step_policy("publisher_changed")
		return
	var identity: Array = _material_step_identity(latest_snapshot)
	if identity.is_empty() or simulation_worker.has_failed():
		_material_steps.cancel("owner_transition_or_failure")
		return
	# The protected state includes queued AND inflight legacy edits. Precise
	# Paint and Art authoring busy states also bypass this presentation hold.
	var paint: Dictionary = simulation_worker.paint_state()
	var now: int = Time.get_ticks_usec() if now_usec < 0 else now_usec
	_material_steps.observe_paint_busy(bool(paint.get("legacy_busy", false)) \
		or bool(paint.get("busy", false)) or bool(paint.get("art_busy", false)), now)
	var witness: Dictionary = _material_step_completed_witness(identity)
	var selected: CyberSimulationSnapshot = _material_steps.take_due(identity, witness, now,
		"paused" if paused else "")
	if selected == null:
		return
	var before_serial: int = last_uploaded_render_snapshot_serial
	consume_render_snapshot(selected)
	var accepted: bool = selected.render_snapshot_serial > before_serial \
		and last_uploaded_render_snapshot_serial == selected.render_snapshot_serial \
		and last_uploaded_world_generation == selected.render_world_generation
	var counted: bool = _material_steps.complete(selected, accepted, _material_step_completed_witness(identity),
		Time.get_ticks_usec() if now_usec < 0 else now_usec)
	if accepted and not counted:
		# An accepted resize can recreate textures, deliberately cancelling the
		# selected policy transaction. Its real upload remains visible in the
		# normal serial/ACK trace and this explicit supplementary counter.
		_material_step_uploads_after_cancellation += 1


func material_step_status() -> Dictionary:
	var result: Dictionary = _material_steps.status()
	result.accepted_uploads_after_policy_cancellation = _material_step_uploads_after_cancellation
	return result


func consume_render_snapshot(snapshot: CyberSimulationSnapshot) -> void:
	# Shared production upload/ACK path, exercised by rendered qualification.
	if snapshot.render_snapshot_serial > last_uploaded_render_snapshot_serial:
		record_render_payload(snapshot)
		var upload_started_usec: int = Time.get_ticks_usec()
		var render_uploaded: bool = upload_texture_patches(
			snapshot.render_patch_rectangles,
			snapshot.render_patch_cells,
			snapshot.world_revision,
			snapshot.render_channels
		)
		if render_uploaded:
			var uploaded_usec: int = Time.get_ticks_usec()
			var native_completed_usec: int = int(snapshot.render_context.get("native_completed_usec",-1))
			if not material_presentation_timeline.accept_upload(snapshot.render_world_generation,
					snapshot.world_revision,snapshot.render_snapshot_serial,snapshot.render_tick_index,
					snapshot.render_generated_usec,native_completed_usec,uploaded_usec):
				# A malformed clock never authorizes stale texture contribution.
				# Upload/ACK validity remains controlled by the existing packet path.
				material_presentation_timeline.reset()
			_cadence_upload = {"event":"texture_upload","render_serial":snapshot.render_snapshot_serial,
				"start_usec":upload_started_usec,"completed_usec":uploaded_usec,
				"native_completed_usec":native_completed_usec,
				"generated_usec":snapshot.render_generated_usec,"native_tick":snapshot.render_tick_index,
				"revision":snapshot.world_revision,"world_generation":snapshot.render_world_generation,
				"full_refresh":snapshot.render_full_refresh,"patch_bytes":snapshot.render_patch_cells.size(),
				"material_publication":material_publication_status()}
			if _owner_gameplay != null: _owner_gameplay.upload(_cadence_upload)
			if workbench_pose_trace.active:
				workbench_pose_trace.observe_event(_cadence_upload.duplicate())
			# Only an accepted World replacement invalidates presentation history.
			# Full refreshes also occur during resync and every fallback frame.
			if snapshot.render_world_generation != last_uploaded_world_generation:
				_presentation_previous_occupied.clear()
				_presentation_previous_unknown = true
				reset_vapour_trail()
			last_uploaded_world_generation = snapshot.render_world_generation
			last_uploaded_render_snapshot_serial = snapshot.render_snapshot_serial
			if shared_workbench != null: _uploaded_workbench_frame = snapshot.render_context.get("workbench_display",{})
			_engine_lab_ack_uploaded_snapshot(snapshot.render_snapshot_serial)
		else:
			reject_render_snapshot(snapshot)


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


func _workbench_terrain_installed(snapshot: CyberSimulationSnapshot) -> bool:
	if _actor_reset_receipt != 0 or not pending_microscenario_apply.is_empty() or not rapier_bridge.is_initialized():
		return false
	var required: int = snapshot.lab_context.get("workbench_hard_surface_revision",-1)
	if required < 0 or not snapshot.hard_surface_chunk_rectangles_valid: return false
	# Finish the current bounded install before accepting a newer packet.
	# A worker publication without the latest geometry cannot release Rapier.
	if rapier_bridge.pending_hard_surface_chunks() == 0 and snapshot.hard_surface_revision == required and last_hard_surface_revision != required:
		sync_hard_surface_colliders(snapshot)
	# Pending terrain may progress at every actual physics callback. A slow
	# render frame must not make otherwise available callbacks idle behind this
	# independent native-feedback fence. Each call keeps the existing allowance.
	if rapier_bridge.pending_hard_surface_chunks() > 0:
		if _pubpres_trace_enabled:
			_pubpres_terrain_budget(WORKBENCH_HARD_SURFACE_CHUNKS_PER_FRAME, WORKBENCH_HARD_SURFACE_FRAME_BUDGET_USEC, "physics_callback", snapshot)
		else:
			rapier_bridge.process_hard_surface_collider_budget(WORKBENCH_HARD_SURFACE_CHUNKS_PER_FRAME,WORKBENCH_HARD_SURFACE_FRAME_BUDGET_USEC)
	if last_hard_surface_revision != required or rapier_bridge.pending_hard_surface_chunks() != 0: return false
	_physical_terrain_ready = true
	return true


func sync_hard_surface_colliders(snapshot: CyberSimulationSnapshot = null) -> void:
	var started_usec: int = Time.get_ticks_usec() if _pubpres_trace_enabled else 0
	if snapshot == null: snapshot = latest_snapshot
	if (
		snapshot == null
		or not rapier_bridge.is_initialized()
		or snapshot.hard_surface_revision == last_hard_surface_revision
	):
		return
	if shared_workbench != null and physical_actor_session != null:
		if snapshot.rigid_body_epoch != _body_owner_epoch(): return
		# A later physical completion may already have installed newer terrain
		# while the full graphical snapshot was being assembled. Direct callers
		# and the render callback must never roll that geometry backwards.
		var newest: CyberSimulationSnapshot = _pubpres_take_physics_snapshot("terrain_queue_guard") if _pubpres_trace_enabled \
			else simulation_worker.take_latest_physics_snapshot()
		if newest == null: return
		if newest.rigid_body_epoch == snapshot.rigid_body_epoch \
			and newest.serial > snapshot.serial and newest.hard_surface_revision != snapshot.hard_surface_revision:
			return
	if physical_actor_session != null and not _physical_terrain_ready \
		and (snapshot.rigid_body_epoch != _physical_epoch or _actor_reset_receipt != 0
			or not pending_microscenario_apply.is_empty()):
		return
	if snapshot.hard_surface_chunk_rectangles_valid:
		if not rapier_bridge.queue_hard_surface_chunk_snapshot(
			snapshot.hard_surface_chunk_rectangles
		):
			microscenario_error = "Terrain collider snapshot was refused"
			return
	elif snapshot.hard_surface_rectangles_valid:
		rapier_bridge.rebuild_hard_surface_colliders_from_rectangles_chunked(
			snapshot.hard_surface_rectangles,
			world_extent.x,
			world_extent.y
		)
	else:
		rapier_bridge.rebuild_hard_surface_colliders(
			snapshot.cells,
			world_extent.x,
			world_extent.y
		)
	last_hard_surface_revision = snapshot.hard_surface_revision
	hard_surface_rebuild_cooldown = HARD_SURFACE_REBUILD_INTERVAL
	if _pubpres_trace_enabled:
		_pubpres_packet_observed("terrain_install", started_usec, snapshot,
			{"operation":"queue", "pending_after":rapier_bridge.pending_hard_surface_chunks()})


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
	playable_course_overlay = PlayableCourseOverlay.new()
	playable_course_overlay.name = "PlayableCourseOverlay"
	$Layout/World.add_child(playable_course_overlay)
	playable_course_overlay.clear_course()
	physical_actor_overlay = PhysicalOverlay.new()
	physical_actor_overlay.name = "PhysicalActorOverlay"
	$Layout/World.add_child(physical_actor_overlay)


func setup_playable_session_panel() -> void:
	playable_session_panel = PlayableSessionPanel.new()
	playable_session_panel.name = "PlayableSessionPanel"
	add_child(playable_session_panel)
	playable_session_panel.setup(self)
	var launcher := Button.new()
	launcher.name = "PlayableSessionLauncher"
	launcher.text = "Play session"
	launcher.focus_mode = Control.FOCUS_NONE
	launcher.pressed.connect(playable_session_panel.show_selection)
	# Reuse the wrapping action bar: another full-height launcher row pushes
	# existing controls below the viewport and breaks real mouse entry.
	var controls_row: HFlowContainer = microscenario_panel.launch_button.get_parent()
	controls_row.add_child(launcher)
	controls_row.move_child(launcher, 0)


func actor_prototypes_allowed() -> bool:
	var exploratory: bool = (tower_context.get("micro_active", false)
		and CyberMicroScenarioCatalogue.exploratory_actor_map(microscenario_definition)
		and microscenario_mode != "Benchmark")
	return ((exploratory or (not tower_active and not tower_context.get("micro_active", false)))
		and not water_controlled_run_active()
		and pending_microscenario_apply.is_empty() and pending_water_apply.is_empty())


func toggle_actor_prototypes() -> void:
	if not actor_prototypes_allowed():
		return
	if actor_prototype_panel.visible:
		actor_prototype_panel.hide()
		return
	cancel_playable_course_input()
	_actor_input_rearm = true
	var selected_model: StringName = StringName("physical/" + physical_trial_arm) if not physical_trial_arm.is_empty() else actor_model_selection
	if physical_rig_id != &"": selected_model = StringName("rapier/" + str(physical_rig_id))
	actor_prototype_panel.restrict_prepared_default(_liquid_default_active)
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


func physical_actor_definitions(model_id: StringName, producer: StringName, demo_npcs: bool, spawn: Vector2,
		scenario_id: String = "") -> Array:
	if not PhysicalCatalog.has_rig(model_id):
		return []
	var models: Array[StringName] = [model_id]
	if demo_npcs:
		for candidate: StringName in PhysicalCatalog.rigs_in_set(PhysicalCatalog.set_for(model_id)):
			if candidate != model_id and models.size() < PhysicalSession.Capacity.DEFAULT_ACTORS:
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
		# Source-faithful actor origin for the authored player course. F5 and
		# all other exploratory/scientific maps retain their existing spawn rule.
		if scenario_id == CyberMicroScenarioCatalogue.PLAYER_COURSE_ID and index == 0:
			var authored_origin: Vector2 = PlayerCourse.mechanical_origin(models[index],
				float(data.spawn_floor_clearance))
			if authored_origin.is_finite():
				origin = authored_origin
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
	var trial_source: Dictionary=pending_microscenario_apply.get("trial_source",{})
	if not trial_source.is_empty() and trial_source!=_trial_source_binding():
		simulation_worker.complete_prepared_physical_liquid(publication,false,"captured trial source changed")
		_prepared_physical_ready_sent=true;return
	if _prepared_physical_identity.is_empty():
		_prepared_physical_identity = publication.duplicate(true)
		if publication.initial_bodies != _pending_physical_candidate.initial_body_states():
			simulation_worker.complete_prepared_physical_liquid(_prepared_physical_identity,false,"initial body identity changed")
			_prepared_physical_ready_sent = true
			return
		if not _pending_physical_candidate.install_terrain(publication.terrain):
			simulation_worker.complete_prepared_physical_liquid(_prepared_physical_identity,false,_pending_physical_candidate.last_error)
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
	if accepted.owner_kind() in ["reference_body","trial_body"]:
		_accepted_reference_candidate = accepted
		rapier_bridge = accepted.physics_bridge()
		rigid_bodies = accepted.bodies()
		_physical_terrain_ready = true
		rapier_start_error = OK
		last_hard_surface_revision = latest_snapshot.hard_surface_revision
		hard_surface_rebuild_cooldown = 0.0
		if accepted.owner_kind()=="trial_body":
			_physical_epoch=accepted.epoch
			simulation_worker.set_physical_actor_epoch(_physical_epoch)
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
	if _workbench_water_composition_enabled() and rapier_bridge is WorkbenchBridge:
		# Native preparation already admitted this exact frozen owner sample.
		# Preserve its presentation provenance BEFORE adoption retires the
		# provisional force ring. This records no new native publication, wait
		# target or completed physical step; the birth closure remains step zero.
		_record_workbench_presentation_sample(accepted.initial_workbench_sample())
	accepted.adopt()
	_prepared_physical_identity = {};_prepared_physical_ready_sent = false

func _close_prepared_reference_bodies() -> void:
	if _accepted_reference_candidate == null: return
	if _accepted_reference_candidate.owner_kind()=="trial_body": simulation_worker.set_physical_actor_epoch(0)
	_accepted_reference_candidate.close()
	_accepted_reference_candidate = null
	rigid_bodies.clear()
	last_hard_surface_revision = -1

func _activate_articulated_actor_rigs(spawn: Vector2) -> bool:
	var definitions: Array = physical_actor_definitions(physical_rig_id,
		actor_producer_selection, actor_demo_npcs, spawn,
		str(microscenario_definition.get("id", "")) if tower_context.get("micro_active", false) else "")
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
	_workbench_submission_notification_pending = false
	if _workbench_submission != null: _workbench_submission.retire("physical_owner_closed")
	_material_deadline.cancel("physical_owner_closed")
	_material_steps.cancel("physical_owner_closed")
	_workbench_presentation_state.clear()
	_workbench_presentation_identity.clear()
	_workbench_sample_steps.clear()
	_workbench_sample_identity.clear()
	_workbench_presentation_history.clear()
	_workbench_observation_identity.clear()
	_workbench_completed_step = -1
	_workbench_completed_step_usec = 0
	_workbench_water_dependencies.clear()
	_workbench_water_completion_context = {}
	_workbench_water_closure_cache.clear()
	_workbench_water_coverage_cache.clear()
	_workbench_follow_state.clear()
	workbench_presentation_frame = {}
	_workbench_mapping_locked = false
	_physical_terrain_ready = false
	_playable_course_observation_valid = false
	if playable_course_overlay != null:
		playable_course_overlay.clear_course()
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


func _record_workbench_presentation_sample(sample: Dictionary) -> void:
	if physical_actor_session == null or not physical_actor_session.bridge is WorkbenchBridge \
			or sample.is_empty() or not sample.get("states") is PackedFloat64Array or sample.states.size() <= 10:
		return
	var bridge: Variant = physical_actor_session.bridge
	if sample.get("session") != bridge._session or sample.get("epoch") != bridge._epoch: return
	var serial: int = int(sample.states[10])
	var sample_identity: Array = [sample.session,sample.epoch]
	if sample_identity != _workbench_sample_identity:
		_workbench_sample_steps.clear()
		_workbench_presentation_history.clear()
		_workbench_sample_identity = sample_identity
	_workbench_sample_steps[serial % PRESENTATION_SAMPLE_HISTORY] = {
		"serial":serial,"step":physical_actor_session.tick,
		"completed_usec":_workbench_completed_step_usec if _workbench_completed_step == physical_actor_session.tick else 0,
		"sampled_usec":Time.get_ticks_usec()}
	if _workbench_water_composition_enabled() and not bridge._history.is_empty():
		# This independent bounded copy never extends impulse eligibility in the
		# short native force ring. Both actual material images are still scanned.
		var source: Dictionary = bridge._history[serial % bridge._history.size()]
		if source.get("serial",-1) == serial and source.get("bodies",[]).size() == bridge._members.size():
			var poses: Array = []
			for body: Dictionary in source.bodies: poses.append(body.pose)
			poses.make_read_only()
			_workbench_sample_steps[serial % PRESENTATION_SAMPLE_HISTORY]["water_poses"] = poses
	for slot: int in range(bridge._members.size()):
		_observe_workbench_presentation(slot,serial)


func _publish_physical_body_state() -> void:
	if shared_workbench != null and microscenario_definition.get("id","") == CyberMicroScenarioContract.WORKBENCH_ID:
		if physical_actor_session != null:
			var sample: Dictionary = physical_actor_session.pack_workbench_sample()
			if not sample.is_empty() and not sample.states.is_empty():
				if _flight_pacing and not paused and Time.get_ticks_usec() - _last_flight_sample_hold_usec <= 100000:
					sample["held_physics_callback"] = true
				var admission: Dictionary = simulation_worker.set_workbench_sample(sample)
				if admission.get("accepted",false):
					_workbench_wait_sample = int(sample.states[10])
					_record_workbench_presentation_sample(sample)
				if str(admission.get("status","")) == "refused":
					physical_actor_session.reject_equipment_requests(sample.get("equipment_requests",[]),str(admission.get("reason","admission")))
				if not admission.get("accepted",false):
					_fault_workbench_frame(str(admission.get("reason","identity")))
			else:
				_fault_workbench_frame("missing_body_sample")
		return
	var effects: Array = physical_actor_session.drain_effects() if physical_actor_session != null else []
	var states: PackedFloat32Array = pack_rigid_body_states()
	if physical_actor_session != null:
		var requests: Array = physical_actor_session.drain_equipment_requests()
		var admission: Dictionary = simulation_worker.set_physical_usable_state(
			physical_actor_session.equipment_frame(), requests, states)
		if str(admission.get("status", "")) == "refused":
			physical_actor_session.reject_equipment_requests(requests, str(admission.get("reason", "admission")))
	simulation_worker.set_rigid_body_states(states,
		_body_owner_epoch(), effects)
	if lockstep_coupling_enabled:
		# Re-read: a refused publication leaves the counter (and the fence) unchanged.
		var publication: int = simulation_worker.rigid_body_publication()
		_lockstep_publication_refused = publication == _lockstep_published
		_lockstep_published = publication


func _fault_workbench_frame(reason: String) -> void:
	if shared_workbench == null or physical_actor_session == null or not _physical_terrain_ready \
			or not pending_microscenario_apply.is_empty() or _pending_physical_candidate != null: return
	# A completed old sample cannot authorize more Rapier steps after a missing
	# or refused replacement frame. Ordinary refused actions still admit their
	# coherent frame and never enter this physical-owner fault path.
	_workbench_frame_error = "Physical frame refused (%s). Reset the actor or Restore start before playing." % reason
	_workbench_wait_sample = -1
	paused = true
	shared_workbench.step_requested = false
	shared_workbench.step_pending = false
	physical_actor_session.set_suspended(true)
	microscenario_error = _workbench_frame_error
	shared_workbench.refuse(_workbench_frame_error)
	update_worker_frame_state()


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


# Native source-tick and main-thread actor-epoch fence for the course HUD.
# A stale pre-rebuild worker packet can never advance a newly selected actor.
func _playable_course_progress_identity() -> bool:
	return (_playable_course_controls_active() and playable_session_options.rules == "lap" and _physical_terrain_ready
		and _actor_reset_receipt == 0 and pending_microscenario_apply.is_empty()
		and latest_snapshot != null and not latest_snapshot.simulation_failed
		and int(latest_snapshot.rigid_body_epoch) == _physical_epoch
		and int(latest_snapshot.render_world_generation) >= 0)


# The real physical callback invokes this *only after* a successful
# complete_step(). This small seam permits a negative test with that one hook
# absent while using the exact same production native and Rapier owners.
func _record_completed_playable_course_step() -> void:
	_observe_playable_course_progress()


# Sample only copied native source ticks and the last completed Rapier pose.
# Both render and physics callbacks may call this: the lap model ignores
# duplicate physics ticks and counts each completed native delta once.
func _observe_playable_course_progress() -> void:
	_playable_course_observation_valid = false
	if not _playable_course_progress_identity():
		_playable_course_progress.clear_session()
		return
	var observed: Dictionary = physical_actor_session.observation(0)
	var position: Vector2 = observed.get("position", Vector2.INF)
	if int(observed.get("epoch",-1)) != _physical_epoch or not position.is_finite() \
		or not str(observed.get("fault", "")).is_empty():
		return
	var source_tick: int = int(latest_snapshot.tick_index)
	if not _playable_course_progress.bind(physical_rig_id, _physical_epoch,
		int(latest_snapshot.render_world_generation), source_tick):
		return
	_playable_course_observation_valid = _playable_course_progress.observe(
		source_tick, int(observed.get("tick",-1)), position, paused)


# HUD text/visibility are published only on the independent presentation
# callback, never by the Rapier step or native worker.
func _update_playable_course_progress() -> void:
	course_timing_label.visible = false
	_observe_playable_course_progress()
	if not _playable_course_observation_valid or not _playable_course_progress_identity() \
		or _playable_course_progress.rig_id != physical_rig_id:
		return
	course_timing_label.text = _playable_course_progress.display_text()
	course_timing_label.visible = not microscenario_hud_hidden


func _present_playable_course_targets() -> void:
	if playable_course_overlay == null:
		return
	if microscenario_hud_hidden or not _playable_course_observation_valid \
		or not _playable_course_progress_identity() or _playable_course_progress.rig_id != physical_rig_id \
		or _playable_course_progress.actor_epoch != _physical_epoch \
		or _playable_course_progress.world_generation != latest_snapshot.render_world_generation:
		playable_course_overlay.clear_course()
		return
	playable_course_overlay.present_course({"rig":str(physical_rig_id), "actor_epoch":_physical_epoch,
		"world_generation":int(latest_snapshot.render_world_generation),
		"source_tick":_playable_course_progress.last_source_tick,
		"physics_tick":_playable_course_progress.last_physics_tick,
		"target_index":_playable_course_progress.target_index},
		presentation_camera_origin(), current_view_size, view_content_rect())


# Only the authored PLAY course uses this copied controller adapter. All
# other F5, flight/scientific, equipment and NPC producer paths remain intact.
func _playable_course_controls_active() -> bool:
	return (tower_context.get("micro_active",false)
		and microscenario_definition.get("id","") == CyberMicroScenarioCatalogue.PLAYER_COURSE_ID
		and physical_actor_session != null
		and physical_rig_id in PlayerCourse.MECHANICAL_PRESETS
		and actor_producer_selection == &"human")


func _playable_course_gamepad_active() -> bool:
	return _playable_course_controls_active() and playable_session_options.controls == "keyboard_gamepad"


func _on_playable_course_gui_focus_changed(control: Control) -> void:
	if control != null and (shared_workbench == null or control is LineEdit or control is TextEdit):
		# Context polling alone can miss a brief UI focus owner.
		cancel_playable_course_input()


func cancel_playable_course_input() -> void:
	if shared_workbench != null:
		_actor_input_rearm = true
		shared_workbench.cancel_stroke()
		if physical_actor_session != null and shared_workbench.pilot_slot >= 0:
			physical_actor_session.cancel_input(shared_workbench.pilot_slot,_physical_epoch,&"human")
		simulation_worker.cancel_workbench_emission()
		return
	if not _playable_course_controls_active(): return
	_actor_input_rearm = true
	_actor_usable_pointer_rearm = true
	physical_actor_session.cancel_input(0, _physical_epoch, &"human")


func set_playable_course_paused(value: bool) -> bool:
	if not _playable_course_controls_active():
		return false
	if not value and (simulation_worker.has_failed() or not _physical_terrain_ready
		or _actor_reset_receipt != 0 or not pending_microscenario_apply.is_empty()
		or _pending_physical_candidate != null):
		return false
	if value == paused:
		return true
	# Revoke at the user transition, not the next physics callback. Otherwise
	# pause -> resume between callbacks retains queued edges and their authority.
	# The same owner handles native-effect cancellation and neutral rearming.
	cancel_playable_course_input()
	paused = value
	update_worker_frame_state()
	return true


func toggle_playable_course_pause() -> bool:
	# Paused is deliberately excluded from context ownership: an owned pause
	# key can resume, but a popup, another window or construction cannot do so.
	if not _playable_course_controls_active() or not _actor_keyboard_context_allowed():
		return false
	return set_playable_course_paused(not paused)


func _publish_physical_keyboard_input(trigger_override: Variant = null, alternate_override: Variant = null) -> void:
	if actor_producer_selection != &"human":
		return
	if not _actor_usable_input_allowed() or _actor_reset_receipt != 0 or simulation_worker.has_failed():
		_actor_input_rearm = true
		_actor_usable_pointer_rearm = true
		physical_actor_session.cancel_input(0, _physical_epoch, &"human")
		return
	# Sample only on the Godot main thread. The owned actor session receives
	# an ordinary copied action and keeps its existing edge, epoch and lease
	# authority; the cellular worker never sees Input or a gamepad object.
	var playable: bool = _playable_course_controls_active()
	var playable_action: Dictionary = CyberPlayerPlaygroundInput.sample(true,
		_playable_course_gamepad_active()) if playable else {}
	if _actor_input_rearm:
		for key: int in ACTOR_CONTROL_KEYS + PHYSICAL_TOOL_KEYS:
			if Input.is_key_pressed(key):
				return
		# Held gamepad or arrow keys must also be released after focus, F5,
		# pause and owner replacement; never resume their stale actuation.
		if playable and CyberPlayerPlaygroundInput.active(playable_action):
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
	if playable:
		# Movement/buttons/trim come from the same seven-preset input mapping
		# without overwriting desktop pointer aim, equipment authority, effort
		# tuning, reel or the separate specialist 4LY envelope.
		for field: String in ["move", "trim", "primary", "secondary", "auxiliary"]:
			action[field] = playable_action[field]
	if physical_actor_session.is_flight_actor(0):
		# The reserved 4LY interpretation has exactly two velocity outputs.
		action = {"move": action.move}
	var admitted_course_action: bool = physical_actor_session.submit_local(0, action, &"human", 6)
	if admitted_course_action and playable and CyberPlayerPlaygroundInput.active(playable_action) \
		and _playable_course_progress_identity():
		var source_tick: int = int(latest_snapshot.tick_index)
		if _playable_course_progress.bind(physical_rig_id, _physical_epoch,
			int(latest_snapshot.render_world_generation), source_tick):
			_playable_course_progress.admit_movement(source_tick)


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
	if articulated and not PhysicalSession.valid_definitions(physical_actor_definitions(
			bare_id, producer, demo_npcs, spawn,
			str(microscenario_definition.get("id", "")) if tower_context.get("micro_active", false) else "")):
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
	if _liquid_default_active:
		if not (trial or model_id==&"") or (not trial and (producer!=&"human" or demo_npcs)):
			actor_prototype_panel.set_error("Prepared native default supports the sampled baseline, barrel and Ripper; current owner retained.")
			return false
		var accepted: bool=_apply_prepared_liquid_default(microscenario_liquid_policy,
			microscenario_liquid_setup.get("normalization","")=="water-normalize-v1",
			int(microscenario_liquid_setup.get("maximum_rule_radius",2)),true,null,{},configuration,false)
		if not accepted: actor_prototype_panel.set_error(microscenario_error)
		return accepted
	if tower_context.get("micro_active", false):
		if trial and not microscenario_liquid_setup.is_empty():
			configuration.prepared_actor_effort=actor_prototype_panel.effort_slider.value
		else: _actor_effort = actor_prototype_panel.effort_slider.value
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
	# Workbench equipment uses the explicit pilot's M/Alt/gamepad action lane.
	# An equipped NPC (including slot zero) never claims the PAINT pointer.
	if shared_workbench != null: return false
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
	if shared_workbench != null: return
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
	if shared_workbench != null: return
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


func _actor_window_has_focus() -> bool:
	return get_window().has_focus()


func actor_keyboard_allowed() -> bool:
	return not paused and _actor_keyboard_context_allowed()


func _actor_keyboard_context_allowed() -> bool:
	if not _actor_window_has_focus() or not actor_prototypes_allowed():
		return false
	if physical_actor_session != null and not _physical_terrain_ready:
		return false
	if actor_prototype_panel.visible or player_environment_panel.visible:
		return false
	if playable_session_panel != null and playable_session_panel.visible:
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
	var world_point: Vector2 = world_position_from_local_point(pointer)
	if not world_point.is_finite(): return Vector2.ZERO
	return (world_point - character_centre()).normalized()


func _workbench_key(key: Key) -> bool:
	return Input.is_key_pressed(key) or Input.is_physical_key_pressed(key)

func _publish_workbench_keyboard() -> void:
	if physical_actor_session == null or shared_workbench.pilot_slot < 0: return
	# Tick-addressed Test It runs through the same ordinary admission path.
	if engine_lab_replay_active:
		_engine_lab_replay_workbench_input()
		return
	# Repeatable input follows completed Rapier steps, independent of FPS.
	if engine_lab_scripted_input:
		if paused: return
		var elapsed: int = maxi(0,physical_actor_session.tick-_engine_lab_scripted_start_tick)
		var phase: int = int(elapsed / 60) % 4
		var movement: Vector2 = [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN][phase]
		var action: Dictionary = {"move":movement,"aim":movement,
			"effort":1.0,"trim":0.0,"primary":false,
			"secondary":false,"auxiliary":false}
		var ports: Dictionary = {"q":false,"e":false,"s":false,"boost":false}
		physical_actor_session.submit_workbench_action(
			shared_workbench.pilot_id(),action,ports,false)
		return
	var gesture: bool = shared_workbench.actor_interaction != null \
		and shared_workbench.actor_interaction.actively_manipulating()
	if paused or simulation_worker.has_failed() or not pending_microscenario_apply.is_empty() or not _actor_window_has_focus() \
		or (shared_workbench.actor_interaction != null and shared_workbench.actor_interaction.blocks_human_input()) \
		or get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit:
		if not _actor_input_rearm:
			if gesture:
				# The generic cancel path also ends live grabs. Neutralize the
				# pilot once without revoking the grabbed body's ownership.
				_actor_input_rearm = true
				var slot: int = shared_workbench.pilot_slot
				if physical_actor_session.workbench_control(shared_workbench.pilot_id()).get("status","") != "physically grabbed":
					physical_actor_session.cancel_input(slot,_physical_epoch,&"human")
			else:
				cancel_playable_course_input()
		return
	var slot: int = shared_workbench.pilot_slot
	var observed: Dictionary = physical_actor_session._view(slot,false)
	var model: String = str(observed.get("model",""))
	var is_fleet: bool = shared_workbench.Fleet.index_for_id(model) >= 0
	var action := CyberPlayerPlaygroundInput.sample(true,true)
	var ports := {"q":_workbench_key(KEY_Q),"e":_workbench_key(KEY_E),
		"s":_workbench_key(KEY_S) or _workbench_key(KEY_DOWN),"boost":_workbench_key(KEY_SHIFT)}
	if is_fleet: action.secondary = _workbench_key(KEY_CTRL)
	var aim: Vector2 = Vector2(observed.get("aim",Vector2.RIGHT))
	var pointer := world_view.get_local_mouse_position()
	var frame := workbench_presentation_frame
	if world_cell_from_local_point(pointer,true).x >= 0 and shared_workbench._submitted_pick_frame_valid(frame):
		var root_body: int = physical_actor_session.bridge.actor_body_index(slot)
		var pose: Variant = frame.poses.get(root_body)
		if pose is Transform2D:
			aim = (world_position_from_local_point(pointer,true)-pose.origin).normalized()
	if aim.length_squared() < 0.0001: aim = Vector2.RIGHT
	action.aim = aim
	action.reel = float(_workbench_key(KEY_X))-float(_workbench_key(KEY_Z))
	var tool := _workbench_key(KEY_M)
	var alternate := _workbench_key(KEY_ALT)
	var drop := _workbench_key(KEY_N)
	var attach := _workbench_key(KEY_U)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var pad := pads[0]
		ports.q = ports.q or Input.is_joy_button_pressed(pad,JOY_BUTTON_LEFT_SHOULDER)
		ports.e = ports.e or Input.is_joy_button_pressed(pad,JOY_BUTTON_RIGHT_SHOULDER)
		ports.s = ports.s or Input.get_joy_axis(pad,JOY_AXIS_LEFT_Y) > 0.2
		if is_fleet: action.secondary = action.secondary or Input.is_joy_button_pressed(pad,JOY_BUTTON_B)
		tool = tool or Input.get_joy_axis(pad,JOY_AXIS_TRIGGER_RIGHT) > 0.3
		alternate = alternate or Input.get_joy_axis(pad,JOY_AXIS_TRIGGER_LEFT) > 0.3
	if model == "kestrel":
		action.move.y = -1.0 if _workbench_key(KEY_W) or _workbench_key(KEY_UP) else minf(0.0,action.move.y)
	if _actor_input_rearm:
		if CyberPlayerPlaygroundInput.active(action) or ports.q or ports.e or ports.s or ports.boost or tool or alternate or drop or attach or action.reel != 0.0: return
		_actor_input_rearm = false
	if not physical_actor_session.is_flight_actor(slot) and observed.get("equipment",{}).get("preparation","mounted") != "none":
		action["equipment"] = {"usable_index":int(observed.get("equipment",{}).get("usable_index",-1)),
			"aim":aim,"power":1.0,"trigger":tool,"alternate":alternate,"drop":drop,"attach":attach}
	physical_actor_session.submit_workbench_action(shared_workbench.pilot_id(),action,ports,shared_workbench.fire_enabled)

func publish_actor_keyboard_input() -> void:
	if shared_workbench != null:
		_publish_workbench_keyboard()
		return
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
	if shared_workbench != null and not actor_prototype_button.is_visible_in_tree(): return
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
	if shared_workbench != null:
		# Resolve follow before the parent publishes terrain, overlays and picking
		# for this frame. The child process used to move it after publication.
		shared_workbench.update_camera(workbench_presentation_frame)
		return
	if water_controlled_run_active(): return
	if _blacksite_keyboard_blocked(): return
	var pan_input: Vector2 = Vector2(
		(1.0 if Input.is_key_pressed(KEY_RIGHT) else 0.0) - (1.0 if Input.is_key_pressed(KEY_LEFT) else 0.0),
		(1.0 if Input.is_key_pressed(KEY_DOWN) else 0.0) - (1.0 if Input.is_key_pressed(KEY_UP) else 0.0)
	)

	# Course arrows are player controls, not implicit camera-pan requests.
	if _playable_course_controls_active():
		pan_input = Vector2.ZERO
	if pan_input.length_squared() > 0.0:
		camera_follow_enabled = false
		camera_origin += pan_input.normalized() * CAMERA_PAN_SPEED * delta
	elif camera_follow_enabled:
		var desired: Vector2 = character_centre() - Vector2(current_view_size) * 0.5
		var follow_weight: float = 1.0 - exp(-CAMERA_FOLLOW_RATE * delta)
		camera_origin = camera_origin.lerp(desired, follow_weight)

	camera_origin = clamped_camera_origin(camera_origin)


func character_centre() -> Vector2:
	if _playable_course_controls_active():
		# Main-thread Rapier produces the observed SetP pose. The ordinary
		# sampled character can remain elsewhere in this composable map.
		var view: Dictionary = physical_actor_session.observation(0)
		var observed: Vector2 = view.get("position",Vector2.INF)
		if int(view.get("epoch",-1)) == _physical_epoch and observed.is_finite():
			return observed
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
		clampf(candidate.x, 0.0, float(maxi(0, world_extent.x - current_view_size.x))),
		clampf(candidate.y, 0.0, float(maxi(0, world_extent.y - current_view_size.y)))
	)


func presentation_camera_origin() -> Vector2:
	if _workbench_mapping_locked: return workbench_presentation_frame.camera_origin
	if workbench_presentation_submission_enabled() and not _workbench_submission_preparing \
			and workbench_presentation_frame.has("camera_origin"):
		return workbench_presentation_frame.camera_origin
	var content := view_content_rect()
	if content.size.x <= 0.0 or content.size.y <= 0.0: return clamped_camera_origin(camera_origin)
	return PixelCamera.screen_to_world(_world_view_screen_transform() * content.position,
		presentation_camera_screen_transform())


func _world_view_screen_transform() -> Transform2D:
	if not world_view.is_inside_tree(): return Transform2D.IDENTITY
	# CanvasItem.get_screen_transform() omits the Window's final stretch when
	# embedded subwindows are enabled. Compose the renderer's viewport/canvas
	# transform with this item's global transform exactly once so translation
	# and picking address framebuffer pixels, including canvas_items stretch.
	return world_view.get_viewport_transform() * world_view.get_global_transform()


func presentation_camera_screen_transform() -> Transform2D:
	if _workbench_mapping_locked: return workbench_presentation_frame.camera_mapping
	if workbench_presentation_submission_enabled() and not _workbench_submission_preparing \
			and workbench_presentation_frame.has("camera_mapping"):
		return workbench_presentation_frame.camera_mapping
	return PixelCamera.presentation_screen_transform(camera_origin, current_view_size,
		view_content_rect(), _world_view_screen_transform(),
		Vector2(maxi(0, world_extent.x-current_view_size.x), maxi(0, world_extent.y-current_view_size.y)))


func configure_pixel_camera(material: ShaderMaterial) -> void:
	var content: Rect2 = workbench_presentation_frame.content_rect if _workbench_mapping_locked else view_content_rect()
	var screen: Transform2D = workbench_presentation_frame.screen_transform if _workbench_mapping_locked else _world_view_screen_transform()
	var mapping := presentation_camera_screen_transform()
	var enabled := content.size.x > 0.0 and content.size.y > 0.0 and PixelCamera.is_axis_aligned(mapping)
	material.set_shader_parameter("native_pixel_mapping_enabled", enabled)
	if not enabled: return
	material.set_shader_parameter("content_screen_origin", screen * content.position)
	material.set_shader_parameter("content_screen_size", Vector2(screen.x.x, screen.y.y) * content.size)
	material.set_shader_parameter("world_zero_screen", mapping.origin)
	material.set_shader_parameter("world_units_per_screen_pixel", PixelCamera.world_units_per_screen_pixel(mapping))


func world_position_from_local_point(local: Vector2, use_submitted_mapping: bool = false) -> Vector2:
	if not local.is_finite(): return Vector2.INF
	if use_submitted_mapping or workbench_presentation_submission_enabled():
		if not workbench_presentation_frame.has("camera_mapping"): return Vector2.INF
		# Input localization already used the CURRENT Control/viewport transform.
		# Recover its physical screen point with that same transform, then address
		# the LAST SUBMITTED camera. Reapplying the old transform to new-local
		# coordinates would mis-pick during an unsubmitted resize/rotation.
		return PixelCamera.screen_to_world(_world_view_screen_transform() * local,
			workbench_presentation_frame.camera_mapping)
	return PixelCamera.screen_to_world(_world_view_screen_transform() * local,
		presentation_camera_screen_transform())


func _world_view_pointer_screen_position(local: Vector2, screen: Transform2D) -> Vector2:
	var physical := screen * local
	# Godot localizes native mouse coordinates through float32 viewport and
	# Control inverses. Reprojection can put an integer pixel boundary a few
	# ULPs below itself, selecting the previous pixel (or the letterbox).
	# Restore only this float32 roundoff band; ordinary fractional positions
	# still address their containing pixel. Continuous zoom anchors do not use
	# this input-only reconstruction, and the shader's sample math is unchanged.
	var integer := physical.round()
	var magnitude := physical.abs().max(screen.origin.abs()).max(Vector2.ONE)
	var roundoff := magnitude * (2.0 * 1.1920928955078125e-7)
	if absf(physical.x - integer.x) <= roundoff.x: physical.x = integer.x
	if absf(physical.y - integer.y) <= roundoff.y: physical.y = integer.y
	return physical


func world_cell_from_local_point(local: Vector2, use_submitted_mapping: bool = false) -> Vector2i:
	if not local.is_finite(): return Vector2i(-1, -1)
	if workbench_presentation_submission_enabled() and not workbench_presentation_frame.has("camera_mapping"):
		return Vector2i(-1,-1)
	var content: Rect2 = view_content_rect()
	var input_screen: Transform2D = _world_view_screen_transform()
	var screen: Transform2D = input_screen
	var mapping: Transform2D = presentation_camera_screen_transform()
	if (use_submitted_mapping or workbench_presentation_submission_enabled()) \
			and workbench_presentation_frame.has("camera_mapping"):
		# Input can arrive between two submissions, after pan or zoom has
		# changed requested values. Use the terrain/pose mapping still on screen.
		content = workbench_presentation_frame.content_rect
		screen = workbench_presentation_frame.screen_transform
		mapping = workbench_presentation_frame.camera_mapping
	# The content bound belongs to the submitted image; event-local coordinates
	# belong to the current transform. Keep those two mappings distinct.
	var sample_position := _world_view_pointer_screen_position(local, input_screen).floor() + Vector2(0.5, 0.5)
	if not PixelCamera.content_contains_screen_sample(sample_position, content, screen): return Vector2i(-1, -1)
	var cell := Vector2i(PixelCamera.screen_to_world(sample_position, mapping).floor())
	return cell if Rect2i(Vector2i.ZERO, world_extent).has_point(cell) else Vector2i(-1, -1)


func update_worker_frame_state() -> void:
	if shared_workbench != null:
		# The bounded canvas remains active independently of pan/zoom. The
		# fixed region has one writer; LOD cadence never suspends remote piles.
		simulation_worker.set_frame_state(0.0,false,paused,world_extent/2,Vector2i.ZERO,
			world_extent,0,0,true,false,liquid_surface_adhesion_enabled)
		return
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


func brush_outline_points(world_cell: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	if world_cell.x < 0 or world_cell.y < 0:
		return points
	var content_rect: Rect2 = view_content_rect()
	if content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		return points
	var scale: Vector2 = content_rect.size / Vector2(current_view_size)
	var dimensions: Vector2i = brush_dimensions()
	var start: Vector2 = Vector2(
		world_cell.x - int((dimensions.x - 1) / 2),
		world_cell.y - int((dimensions.y - 1) / 2)
	) - presentation_camera_origin()
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
	var world_cell: Vector2i = world_cell_from_local_point(
		world_view.get_local_mouse_position()
	)
	var points: PackedVector2Array = brush_outline_points(world_cell)
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
	var admitted: bool = simulation_worker.queue_emit_disc(
		world_x,world_y,radius,material_id,emission_flags)
	if admitted:
		material_edit_admitted()
	return admitted


func queue_brush_footprint_mutation(
		world_x: int,
		world_y: int,
		material_id: int,
		emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
	) -> bool:
	if water_controlled_run_active() or not _microscenario_tool_allowed(material_id):
		return false
	if brush_shape == "circle" and (brush_size_px & 1) == 1:
		var admitted: bool = simulation_worker.queue_emit_disc(
			world_x,
			world_y,
			(brush_size_px - 1) / 2,
			material_id,
			emission_flags
		)
		if admitted:
			material_edit_admitted()
		return admitted
	var cells: PackedInt32Array = brush_footprint_cells(world_x, world_y)
	if cells.is_empty():
		return false
	var admitted: bool = simulation_worker.queue_emit_cells(cells, material_id, emission_flags)
	if admitted:
		material_edit_admitted()
	return admitted


func handle_painting() -> void:
	if shared_workbench != null: return
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
	var world_cell: Vector2i = world_cell_from_local_point(
		world_view.get_local_mouse_position()
	)
	if world_cell.x < 0:
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

	queue_brush_footprint_mutation(
		world_cell.x,
		world_cell.y,
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


# The palette projects growth, sparks and fumes into neighbouring Empty
# cells. These four IDs can never seed those effects. Classify the actual
# first channel of published bytes, independently of authored scene labels,
# native statistics, condition, and simulation revisions.
func _no_ambient_source(plane: Image) -> bool:
	if not _check_ambient_sources or shared_workbench == null or _workbench_submission_requested \
			or plane == null or plane.is_empty() or plane.has_mipmaps() \
			or plane.get_format() not in [Image.FORMAT_R8,Image.FORMAT_RG8]: return false
	var ids := plane
	if plane.get_format() == Image.FORMAT_RG8:
		ids = plane.duplicate()
		ids.convert(Image.FORMAT_R8)
	var bytes := ids.get_data()
	return bytes.count(0) + bytes.count(2) + bytes.count(3) + bytes.count(58) == bytes.size()


func create_render_textures() -> void:
	_ambient_sources_absent = _no_ambient_source(image)
	_material_deadline.cancel("textures_recreated")
	_material_steps.cancel("textures_recreated")
	material_presentation_timeline.reset()
	_create_material_texture_pair(image, image)
	_material_pending_rectangles.clear()
	_presentation_previous_image = null
	_presentation_previous_unknown = true
	_presentation_current_bytes = image.get_data()
	_presentation_previous_bytes = _presentation_current_bytes
	_presentation_content_serial += 1
	_presentation_current_content_id = _presentation_content_serial
	_presentation_previous_content_id = _presentation_current_content_id
	_presentation_current_content_shape = Vector3i(image.get_width(),image.get_height(),image.get_format())
	_presentation_previous_content_shape = _presentation_current_content_shape


func upload_texture(material_cells: PackedByteArray, world_revision: int) -> void:
	if image == null or texture == null or previous_texture == null:
		return
	var start_usec: int = Time.get_ticks_usec()
	_presentation_previous_occupied.clear()
	_presentation_previous_image = image.duplicate() if shared_workbench != null and not _legacy_render_cadence() else null
	_presentation_previous_unknown = _presentation_previous_image == null
	image.set_data(
		world_extent.x,
		world_extent.y,
		false,
		render_image_format,
		material_cells
	)
	_ambient_sources_absent = _no_ambient_source(image)
	_material_pending_rectangles = _full_material_rectangle()
	_material_image_patch_usec = Time.get_ticks_usec() - start_usec
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
	_material_pending_rectangles = patch_rectangles.duplicate()
	_material_image_patch_usec = Time.get_ticks_usec() - start_usec
	finish_texture_upload(world_revision, start_usec)
	return true


# Called against the old CPU image before its patches are applied. Outside
# these rectangles the old and new GPU textures contain the same material.
# Retain the exact image for Workbench. Legacy callers without an image keep
# the bounded map of old nonempty pixels.
func _capture_previous_presentation_occupancy(rectangles: PackedInt32Array) -> void:
	_presentation_previous_occupied.clear()
	_presentation_previous_unknown = false
	_presentation_previous_image = null
	if image == null or texture == null or previous_texture == null:
		_presentation_previous_unknown = true
		return
	if shared_workbench != null and not _legacy_render_cadence():
		# Bind precisely the image that becomes previous_world_texture when the
		# GPU slots swap. Preserve it through CPU patch mutation. Full refreshes
		# and delayed ACK accumulation no longer imply unknown local occupancy.
		_presentation_previous_image = image.duplicate()
		# Both production clearance policies use the exact previous Image (or
		# its immutable byte cache) whenever it exists. Building the legacy map
		# as well only repeats up to 16,384 GDScript pixel reads/dictionary writes.
		# If retention failed, continue through the conservative legacy fallback.
		if _presentation_previous_image != null: return
	var changed: int = 0
	for offset: int in range(0,rectangles.size(),RENDER_PATCH_METADATA_STRIDE):
		var cells: int = int(rectangles[offset+2])*int(rectangles[offset+3])
		if cells > PRESENTATION_PREVIOUS_PATCH_LIMIT-changed:
			_presentation_previous_unknown = _presentation_previous_image == null
			return
		changed += cells
	for offset: int in range(0,rectangles.size(),RENDER_PATCH_METADATA_STRIDE):
		var left: int = rectangles[offset]
		var top: int = rectangles[offset+1]
		for y: int in range(top,top+rectangles[offset+3]):
			for x: int in range(left,left+rectangles[offset+2]):
				if image.get_pixel(x,y).r8 != 0:
					_presentation_previous_occupied[y*world_extent.x+x] = true


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
	_capture_previous_presentation_occupancy(patch_rectangles)
	# A single exact whole-image payload already has the layout set_data needs.
	# The old CPU image was retained above, before replacing these bytes. Avoid
	# slicing another full array, constructing a patch Image and blitting it
	# back into an equally sized image. Partial, padded, trailing-data and
	# multiple-patch publications retain the existing compaction path below.
	if patch_rectangles.size() == RENDER_PATCH_METADATA_STRIDE \
			and patch_rectangles[0] == 0 and patch_rectangles[1] == 0 \
			and patch_rectangles[2] == world_extent.x and patch_rectangles[3] == world_extent.y \
			and patch_rectangles[4] == 0 and patch_rectangles[5] == world_extent.x * patch_channels \
			and patch_cells.size() == world_extent.x * world_extent.y * patch_channels \
			and image.get_width() == world_extent.x and image.get_height() == world_extent.y \
			and image.get_format() == render_image_format and not image.has_mipmaps():
		image.set_data(world_extent.x, world_extent.y, false, render_image_format, patch_cells)
		_ambient_sources_absent = _no_ambient_source(image)
		return true
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
		if _ambient_sources_absent: _ambient_sources_absent = _no_ambient_source(patch_image)
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
			or patch_x > world_extent.x - patch_width
			or patch_y > world_extent.y - patch_height
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
	_material_deadline.cancel("render_packet_rejected")
	_material_steps.cancel("render_packet_rejected")
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


# Validate a small area surrounding the piloted body before World-sized byte
# comparisons consume this upload's guard allowance. It certifies Empty pixels
# only; pose, generation, native mask and submission checks stay in the resolver.
func _prepare_workbench_dry_region(started_usec: int) -> Dictionary:
	_workbench_dry_region_status = "inactive"
	if paused or shared_workbench == null or not shared_workbench.has_method("pilot_id") or not _workbench_water_composition_enabled() \
			or physical_actor_session == null or not physical_actor_session.bridge is WorkbenchBridge \
			or _presentation_previous_unknown or _presentation_previous_image == null \
			or _pending_physical_candidate != null or not pending_microscenario_apply.is_empty():
		return {}
	var actor: int = physical_actor_session.slot_for_instance(shared_workbench.pilot_id())
	var bridge: WorkbenchBridge = physical_actor_session.bridge
	var slot: int = bridge.actor_body_index(actor)
	if slot < 0 or bridge != rapier_bridge or not bridge.is_initialized(): return {}
	var previous: Dictionary = _workbench_presentation_state.get(slot,{})
	if previous.get("water_composed",false):
		_workbench_dry_region_status = "water_composed"
		return {}
	var position: Vector2 = bridge.body_transform(slot).origin
	if not position.is_finite(): return {}
	var inherited: Dictionary = {}
	if not _workbench_dry_region.is_empty() and _workbench_dry_region.world == last_uploaded_world_generation \
			and _workbench_dry_region.session == bridge._session and _workbench_dry_region.epoch == bridge._epoch \
			and _workbench_dry_region.current == _presentation_current_content_id \
			and WorkbenchPresentationCoherence.patches_preserve_region(_workbench_dry_region.area,_material_pending_rectangles):
		# Only the old current image becomes previous. The complete validated
		# patch inventory proves that every pixel in this area stays unchanged
		# in the new current image. This charges no new material-cell reads.
		inherited = _workbench_dry_region.duplicate()
		_workbench_dry_region_status = "unchanged_patches"
		if Rect2i(inherited.area).grow(-12).has_point(Vector2i(position.floor())): return inherited
	var area := Rect2i(Vector2i(position.floor())-Vector2i(24,24),Vector2i(48,48))
	var cells := area.get_area()
	var deadline := started_usec+PRESENTATION_FRAME_TIME_BUDGET_USEC-_presentation_pending_cache_usec
	if _presentation_pending_clearance_cells+cells > PRESENTATION_FRAME_SCAN_BUDGET \
			or Time.get_ticks_usec() >= deadline:
		if inherited.is_empty(): _workbench_dry_region_status = "budget_before_scan"
		return inherited
	_presentation_pending_clearance_cells += cells
	if not WorkbenchPresentationCoherence.region_is_empty(image,area) or Time.get_ticks_usec() >= deadline \
			or not WorkbenchPresentationCoherence.region_is_empty(_presentation_previous_image,area) \
			or Time.get_ticks_usec() >= deadline:
		if inherited.is_empty(): _workbench_dry_region_status = "scan_incomplete_or_occupied"
		return inherited
	_workbench_dry_region_status = "scanned"
	return {"area":area,"world":last_uploaded_world_generation,"session":bridge._session,"epoch":bridge._epoch}


func finish_texture_upload(world_revision: int, start_usec: int) -> void:
	# Ping-pong two GPU textures. The shader blends movable occupancy from the
	# previous snapshot to the current one, masking the intentional two-cell
	# sparse-flight leap without changing authoritative physics or collisions.
	var old_current_texture: Texture2D = texture
	texture = previous_texture
	previous_texture = old_current_texture
	var cache_started_usec: int = Time.get_ticks_usec()
	var previous_dry: Dictionary = _workbench_dry_region
	_workbench_dry_region = _prepare_workbench_dry_region(cache_started_usec)
	var next_bytes: PackedByteArray = image.get_data()
	var next_shape := Vector3i(image.get_width(),image.get_height(),image.get_format())
	var next_content_id: int = 0
	# Exact equality is the proof. Revisions can change without material edits,
	# and slots swap on every upload; neither invalidates an unchanged footprint.
	if next_shape == _presentation_current_content_shape and next_bytes == _presentation_current_bytes:
		next_content_id = _presentation_current_content_id
	elif next_shape == _presentation_previous_content_shape and next_bytes == _presentation_previous_bytes:
		next_content_id = _presentation_previous_content_id
	if next_content_id <= 0:
		_presentation_content_serial += 1
		next_content_id = _presentation_content_serial
	_presentation_previous_bytes = _presentation_current_bytes
	_presentation_previous_content_id = _presentation_current_content_id
	_presentation_previous_content_shape = _presentation_current_content_shape
	_presentation_current_bytes = next_bytes
	_presentation_current_content_id = next_content_id
	_presentation_current_content_shape = next_shape
	if _workbench_dry_region.is_empty() and _workbench_dry_region_status == "budget_before_scan" \
			and not previous_dry.is_empty() and previous_dry.current == _presentation_previous_content_id \
			and (previous_dry.current == next_content_id or previous_dry.previous == next_content_id):
		# A full refresh can still install the identical two certified images.
		# Actual immutable bytes and dimensions established these content IDs.
		_workbench_dry_region = previous_dry.duplicate()
		_workbench_dry_region_status = "same_contents"
	if not _workbench_dry_region.is_empty():
		_workbench_dry_region["current"] = _presentation_current_content_id
		_workbench_dry_region["previous"] = _presentation_previous_content_id
	_presentation_upload_cache_usec = Time.get_ticks_usec()-cache_started_usec
	_presentation_pending_cache_usec += _presentation_upload_cache_usec
	update_render_texture()
	_bind_material_texture_consumers()
	snapshot_blend_start_usec = Time.get_ticks_usec()
	last_uploaded_revision = world_revision
	upload_time_ms = float(Time.get_ticks_usec() - start_usec) / 1000.0


func update_render_texture() -> void:
	if _material_full_ring != null:
		# finish_texture_upload has swapped Main's old pair. The third texture
		# was absent from that pair; upload there, then bind the exact new pair.
		if texture == _material_full_ring.previous and previous_texture == _material_full_ring.current \
				and _material_full_ring.publish(image):
			texture = _material_full_ring.current
			previous_texture = _material_full_ring.previous
			_material_publication_last = _material_full_ring.last_update.duplicate()
			return
		# Any structural refusal reconstructs both exact histories before ACK.
		# Do not continue with a partially rotated or foreign resource.
		_material_publication_fallback = "full image ring ownership or source refused"
		_material_full_ring = null
		var recovery_started: int = Time.get_ticks_usec()
		texture = ImageTexture.create_from_image(image.duplicate())
		previous_texture = ImageTexture.create_from_image(_material_previous_cpu_image())
		_material_publication_last = {"mode":"full", "submitted_bytes":image.get_width()*image.get_height()*render_channels*2,
			"tile_assembly_usec":0, "backend_submit_usec":Time.get_ticks_usec()-recovery_started,
			"recovery_rebuilt_pair":true}
		return
	if texture is MaterialPublisher.MaterialPlane:
		var regions: Array[Rect2i] = []
		for offset: int in range(0, _material_pending_rectangles.size(), 6):
			regions.append(Rect2i(_material_pending_rectangles[offset], _material_pending_rectangles[offset+1],
				_material_pending_rectangles[offset+2], _material_pending_rectangles[offset+3]))
		# finish_texture_upload has swapped Main's references already. The owner
		# installs every pending tile in the recycled slot, then advances its pair.
		if _material_blit_publisher != null and texture == _material_blit_publisher.previous \
				and previous_texture == _material_blit_publisher.current \
				and _material_blit_publisher.publish(image, regions):
			_material_publication_last = _material_blit_publisher.last_update.duplicate()
			return
		# A structural rejection publishes both exact CPU histories with the
		# verified full path before the revision is acknowledged.
		_material_publication_fallback = "blit update validation failed"
		var recovery_previous: Image = _material_previous_cpu_image()
		var recovery_started: int = Time.get_ticks_usec()
		texture = ImageTexture.create_from_image(image.duplicate())
		previous_texture = ImageTexture.create_from_image(recovery_previous)
		_material_blit_publisher = null
		_material_publication_last = {"mode":"full", "submitted_bytes":image.get_width() * image.get_height() * render_channels * 2,
			"tile_assembly_usec":0, "backend_submit_usec":Time.get_ticks_usec() - recovery_started,
			"recovery_rebuilt_pair":true}
		return
	var started: int = Time.get_ticks_usec()
	# RenderingServer may retain this Image until a separate render owner
	# executes the queued upload. Main mutates image on the next publication;
	# give the queue an immutable snapshot, just as the blit staging path does.
	(texture as ImageTexture).update(image.duplicate())
	_material_publication_last = {"mode":"full", "submitted_bytes":image.get_width() * image.get_height() * render_channels,
		"candidate_tiles":1, "updated_tiles":1, "tile_count":1,
		"tile_assembly_usec":0, "backend_submit_usec":Time.get_ticks_usec() - started}


func _full_material_rectangle() -> PackedInt32Array:
	return PackedInt32Array([0, 0, world_extent.x, world_extent.y, 0, world_extent.x * render_channels])


func _material_previous_cpu_image() -> Image:
	return Image.create_from_data(_presentation_previous_content_shape.x,
		_presentation_previous_content_shape.y, false,
		_presentation_previous_content_shape.z, _presentation_previous_bytes)


func _create_material_texture_pair(current: Image, previous: Image) -> void:
	if _material_publication_mode.is_empty():
		_material_publication_mode = OS.get_environment("CYBERSAND_MATERIAL_PUBLICATION").to_lower()
		if _material_publication_mode not in ["auto", "full", "blit"]: _material_publication_mode = "full"
	_material_publication_fallback = ""
	_material_full_ring = null
	var publisher: MaterialPublisher
	if _material_publication_mode != "full":
		if MaterialPublisher.supported_driver():
			publisher = MaterialPublisher.create_pair(current, previous)
			if publisher == null:
				_material_publication_fallback = "drawable pair creation or capacity refused"
		else:
			_material_publication_fallback = "platform or renderer not qualified for blit publication"
	if publisher != null:
		texture = publisher.current
		previous_texture = publisher.previous
		_material_publication_last = publisher.last_update.duplicate()
	elif _material_publication_mode == "full" and OS.get_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS") == "3":
		_material_full_ring = FullImageRingPublisher.create_pair(current, previous)
		if _material_full_ring != null:
			texture = _material_full_ring.current
			previous_texture = _material_full_ring.previous
			_material_publication_last = _material_full_ring.last_update.duplicate()
		else:
			_material_publication_fallback = "full image ring creation refused"
	if publisher == null and _material_full_ring == null:
		var setup_started: int = Time.get_ticks_usec()
		# Initial creation is queued too. These inputs may alias Main's mutable
		# image, including reset/mode-switch followed by another same-frame edit.
		texture = ImageTexture.create_from_image(current.duplicate())
		previous_texture = ImageTexture.create_from_image(previous.duplicate())
		_material_publication_last = {"mode":"full", "initialization":true,
			"initialization_usec":Time.get_ticks_usec()-setup_started,
			"submitted_bytes":(current.get_width()*current.get_height()+previous.get_width()*previous.get_height())*render_channels}
	_material_blit_publisher = publisher
	if _material_steps.enabled() and not _material_step_publisher_supported():
		_retire_material_step_policy("publisher_changed")


func _material_publication_rid(value: Texture2D) -> RID:
	return value.get_rid() if value != null else RID()


func configure_material_textures(shader: ShaderMaterial, single: bool = false) -> void:
	if shader == null: return
	if single:
		shader.set_shader_parameter("world_texture", texture)
	else:
		shader.set_shader_parameter("current_world_texture", texture)
		shader.set_shader_parameter("previous_world_texture", previous_texture)


func _bind_material_texture_consumers() -> void:
	if world_view != null: world_view.texture = texture
	configure_material_textures(world_shader)
	configure_material_textures(glow_source_shader, true)
	for shader: ShaderMaterial in vapour_trail_shaders:
		configure_material_textures(shader, true)


func material_publication_status() -> Dictionary:
	var result: Dictionary = _material_publication_last.duplicate()
	result["requested_mode"] = _material_publication_mode
	result["backend"] = "blit" if texture is MaterialPublisher.MaterialPlane else "full"
	result["full_image_slots_requested"] = OS.get_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS")
	result["full_image_slots"] = 3 if _material_full_ring != null else (0 if _material_blit_publisher != null else 2)
	result["fallback_reason"] = _material_publication_fallback
	result["policy"] = ""
	result["driver"] = RenderingServer.get_current_rendering_driver_name()
	result["logical_source_format"] = "R8" if render_channels == 1 else "RG8"
	result["gpu_storage_format"] = "RGBA8_LINEAR" if texture is MaterialPublisher.MaterialPlane else result.logical_source_format
	if not result.get("initialization", false):
		result["image_patch_usec"] = _material_image_patch_usec
		result["content_cache_usec"] = _presentation_upload_cache_usec
	result["timing_scope"] = "elapsed wall calls including possible waits/descheduling; not GPU completion"
	result["timing_aliases"] = "tile_assembly=atlas_assembly; backend_submit=staging_upload+gpu_blit_submit; do not add aliases twice"
	result["byte_scope"] = "submitted_bytes counts CPU staging uploads; target write bytes are estimates, not measured bandwidth"
	if _material_blit_publisher != null:
		result["tile_side"] = _material_blit_publisher.tile_side
		result["tile_count"] = _material_blit_publisher.columns * _material_blit_publisher.rows
		result["allocated_gpu_bytes"] = _material_blit_publisher.gpu_storage_bytes()
		result["current_texture_rid"] = _material_publication_rid(texture).get_id()
		result["previous_texture_rid"] = _material_publication_rid(previous_texture).get_id()
	return result


func set_material_publication_mode(mode: String) -> bool:
	if mode not in ["auto", "full", "blit"] or image == null: return false
	_material_publication_mode = mode
	_create_material_texture_pair(image, _material_previous_cpu_image())
	_bind_material_texture_consumers()
	return mode != "blit" or texture is MaterialPublisher.MaterialPlane


func update_shader_parameters() -> void:
	if world_shader == null:
		return
	world_shader.set_shader_parameter("ambient_sources_absent",_ambient_sources_absent)
	if glow_source_shader != null:
		glow_source_shader.set_shader_parameter("ambient_sources_absent",_ambient_sources_absent)
		_bind_glow_composite_proof()
	world_shader.set_shader_parameter(
		"world_size_px",
		Vector2(world_extent.x, world_extent.y)
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
		presentation_camera_origin()
	)
	configure_pixel_camera(world_shader)
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
	if _workbench_mapping_locked:
		snapshot_blend = workbench_presentation_frame.snapshot_blend
	else:
		snapshot_blend = _material_presentation_state(Time.get_ticks_usec()).snapshot_blend
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
	if shared_workbench == null and showcase_presentation != null:
		showcase_presentation.refresh()
	if shared_workbench == null and blacksite_nine_presentation != null:
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
	if shared_workbench != null: return
	var sampling_requested: bool = debug_stats_visible and debug_stats_expanded \
		and not microscenario_hud_hidden and _playable_course_controls_active()
	if sampling_requested != _participation_sampling_requested:
		_participation_sampling_requested = sampling_requested
		simulation_worker.set_worker_participation_sampling(sampling_requested)
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
		var request_text: String = "Auto" if latest_snapshot.native_worker_request <= 0 else str(latest_snapshot.native_worker_request)
		var thread_text: String = "%s requested %s / capacity %d" % [
			latest_snapshot.backend_name,
			request_text,
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
		var participation: Dictionary = latest_snapshot.native_worker_participation
		var participation_text: String = "task participants unavailable (sampling requires a running Play course)"
		if not participation.is_empty() and not latest_snapshot.simulation_failed \
			and int(participation.get("world_generation", -1)) == latest_snapshot.render_world_generation:
			participation_text = "%d task participants at native tick %d · sample age %.0fms" % [
				int(participation.workers_observed), int(participation.completed_tick),
				maxf(0.0, float(Time.get_ticks_usec()-int(participation.sampled_usec))/1000.0)]
		status_label.text += "\nWORK %s · owner publications %d consumed / %d coalesced / %d refused · render payloads %d refused" % [
			participation_text, worker_publication_counter.consumed, worker_publication_counter.coalesced,
			worker_publication_counter.rejected, rejected_render_snapshot_count]

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
	configure_material_textures(glow_source_shader, true)
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
		viewport.size = current_view_size + Vector2i.ONE
		add_child(viewport)
		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = trail_shader
		var source: ColorRect = ColorRect.new()
		source.name = "VapourTrailSource"
		source.color = Color.WHITE
		source.size = Vector2(viewport.size)
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
	_vapour_history_possible = false
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
	# A reset starts with exactly zero history. A gas-free publication
	# cannot add Steam or Smoke to those zero buffers. As soon as another
	# material is observed, resume normal history until the next real reset.
	if _ambient_sources_absent and not _vapour_history_possible: return
	_vapour_history_possible = true
	# Resize both generations together. Resizing only the alternating target
	# drops the first history frame and can revive a buffer after rapid resizes.
	# The fractional view can include one more cell on its right/bottom edges.
	var history_size := current_view_size + Vector2i.ONE
	if vapour_trail_viewports[0].size != history_size or vapour_trail_viewports[1].size != history_size:
		reset_vapour_trail()
		for resized: SubViewport in vapour_trail_viewports:
			resized.size = history_size
			var source: ColorRect = resized.get_child(0) as ColorRect
			source.size = Vector2(history_size)
	var frame: int = Engine.get_process_frames()
	if frame == vapour_trail_frame:
		return
	_vapour_history_possible = true
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
	# History remains on the integer world grid; only the final palette lookup
	# uses the fractional presentation origin. This is not camera quantization.
	var origin: Vector2 = presentation_camera_origin().floor()
	var shader_material: ShaderMaterial = vapour_trail_shaders[target]
	configure_material_textures(shader_material, true)
	shader_material.set_shader_parameter(
		"world_size_px", Vector2(world_extent.x, world_extent.y))
	shader_material.set_shader_parameter("view_size_px", Vector2(history_size))
	shader_material.set_shader_parameter("camera_origin_px", origin)
	shader_material.set_shader_parameter("history_origin_px", vapour_trail_origins[history])
	shader_material.set_shader_parameter(
		"delta_seconds",
		delta_seconds if vapour_trail_viewports[history].size == history_size else 0.0
	)
	shader_material.set_shader_parameter(
		"condition_projection_enabled", 1.0 if render_channels == 2 else 0.0)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	vapour_trail_origins[target] = origin
	vapour_trail_latest = target
	world_shader.set_shader_parameter("vapour_trail_texture", viewport.get_texture())
	world_shader.set_shader_parameter("vapour_trail_origin_px", origin)
	world_shader.set_shader_parameter("vapour_trail_size_px", Vector2(history_size))
	world_shader.set_shader_parameter("vapour_trail_strength", 1.0)


func _bind_glow_composite_proof() -> void:
	if glow_composite_shader == null: return
	# A live program can replace the emitter's LUT independently of the
	# catalogue default. The composite must inspect the same texture.
	var program: Variant = glow_source_shader.get_shader_parameter("material_program_lut")
	glow_composite_shader.set_shader_parameter("material_program_lut", program)
	glow_composite_shader.set_shader_parameter("ambient_sources_absent", _ambient_sources_absent
		and program is Texture2D and program.get_size() == Vector2(
			CyberMaterialAppearanceLut.PROGRAM_WIDTH, CyberMaterialAppearanceLut.PROGRAM_HEIGHT))


func update_glow_parameters(content_rect: Rect2) -> void:
	if glow_viewport == null or glow_source_shader == null or glow_overlay == null:
		return
	# Keep the source on a fixed two-world-cell grid. Odd view dimensions must
	# not stretch that grid. Five guard texels cover the composite's four-texel
	# halo plus filtering; the extra far texel covers a partial camera step.
	var source_cells := Vector2(2.0, 2.0)
	var guard := Vector2i(5, 5)
	var downsampled_size := Vector2i(maxi(80,ceili(current_view_size.x / 2.0)),
		maxi(45,ceili(current_view_size.y / 2.0))) + guard * 2 + Vector2i.ONE
	var origin := presentation_camera_origin()
	var source_origin := (origin / source_cells).floor() * source_cells - Vector2(guard) * source_cells
	var source_view := Vector2(downsampled_size) * source_cells
	if glow_viewport.size != downsampled_size:
		glow_viewport.size = downsampled_size
		glow_source.position = Vector2.ZERO
		glow_source.size = Vector2(downsampled_size)
	glow_overlay.position = content_rect.position
	glow_overlay.size = content_rect.size
	glow_source_shader.set_shader_parameter(
		"world_size_px",
		Vector2(world_extent.x, world_extent.y)
	)
	glow_source_shader.set_shader_parameter("view_size_px", source_view)
	glow_source_shader.set_shader_parameter("camera_origin_px", source_origin)
	glow_composite_shader.set_shader_parameter("source_uv_offset", (origin - source_origin) / source_view)
	glow_composite_shader.set_shader_parameter("source_uv_scale", Vector2(current_view_size) / source_view)
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
