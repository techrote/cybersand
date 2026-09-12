extends Control

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
]
const MATERIAL_GROUP_FIRST_IDS: Array[int] = [
	CyberCellWorld.SAND,
	CyberCellWorld.LIMESTONE_BLOCK,
	CyberCellWorld.INDUSTRIAL_BRICK,
	CyberCellWorld.NEON_CYAN,
]

@onready var world_view: TextureRect = $Layout/World
@onready var status_label: Label = $Layout/Status
@onready var world_shader: ShaderMaterial = world_view.material as ShaderMaterial
@onready var test_rigid_body_1: RigidBody2D = $RigidBodies/TestBody1
@onready var test_rigid_body_2: RigidBody2D = $RigidBodies/TestBody2
@onready var test_rigid_body_3: RigidBody2D = $RigidBodies/TestBody3

var simulation_worker: CyberSimulationWorker = CyberSimulationWorker.new()
var tower_panel: CyberTowerPanel
var tower_active: bool = false
var tower_floor: int = 0
var tower_context: Dictionary = {}
var tower_profile_panel: CyberTransportProfilePanel
var tower_profile: Dictionary = CyberTransportProfiles.preset(0)
var water_experiment_panel: CyberWaterExperimentPanel
var water_policy_resolved: Dictionary = CyberWaterExperimentProfiles.resolve()
var water_blind_set: Dictionary = {}
var water_blind_index: int = 0
var water_active_blind_label: String = ""
var pending_water_apply: Dictionary = {}
var water_policy_available: bool = true

func setup_tower_panel() -> void:
	tower_panel = CyberTowerPanel.new()
	$Layout.add_child(tower_panel)
	$Layout.move_child(tower_panel,1)
	tower_panel.setup(self)
	tower_profile_panel = CyberTransportProfilePanel.new()
	add_child(tower_profile_panel)
	tower_profile_panel.setup(self)
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
	water_experiment_panel.popup_centered()

func water_lab_reset() -> void:
	if not water_policy_available: return
	water_lab_apply_result(water_policy_resolved,water_active_blind_label)

func water_lab_save_profile() -> bool:
	if (not water_policy_available or not water_policy_resolved.get("ok",false)
		or not water_active_blind_label.is_empty()): return false
	var file: FileAccess=FileAccess.open(WATER_POLICY_PATH,FileAccess.WRITE)
	if file==null: return false
	file.store_string(str(water_policy_resolved.canonical_json)+"\n")
	return true

func water_lab_apply_result(result: Dictionary, blind_label: String = "") -> void:
	if not result.get("ok",false): return
	var checked: Dictionary=CyberWaterExperimentProfiles.resolve({},{},result.policy)
	if not checked.get("ok",false) or str(checked.hash)!=str(result.hash): return
	var recipe: Dictionary=CyberWaterFeelScenarios.recipe(
		str(checked.policy.scenario_id),int(checked.policy.seed))
	if recipe.is_empty(): return
	paused=true
	pending_water_apply={"result":result.duplicate(true),"recipe":recipe.duplicate(true),
		"blind_label":blind_label,"hash":str(checked.hash)}
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
	var candidates: Array=[]
	var base: Dictionary=water_policy_resolved.policy.duplicate(true)
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
	if not active:
		for body: RigidBody2D in [test_rigid_body_1,test_rigid_body_2,test_rigid_body_3]:
			body.freeze=true
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
		if rapier_bridge.is_initialized():
			rapier_bridge.reset_body(i,Vector2(160+i*52,176),0.0)

func tower_command(command: Dictionary) -> void:
	if command.has("step"): paused = true
	simulation_worker.queue_lab(command)

func tower_floor_select(index: int) -> void:
	tower_floor = clampi(index,0,4)
	paused = true
	camera_follow_enabled = false
	camera_origin = Vector2(0,CyberExperimentTower.floor_y(tower_floor))
	tower_command({"floor":tower_floor})

func tower_reset() -> void:
	water_active_blind_label=""
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
	tower_command({"reset":true,"floor":tower_floor,"profile":resolved})
	camera_follow_enabled = false
	camera_origin = Vector2(0,CyberExperimentTower.floor_y(tower_floor))

func tower_tuning() -> void:
	paused = true
	tower_profile_panel.popup_centered()

func tower_focus_tube(index: int) -> void:
	var tubes: Array=CyberExperimentTower.tubes(tower_floor)
	if index < 0 or index >= tubes.size(): return
	paused=true
	camera_follow_enabled=false
	camera_origin=Vector2(clampf(float(tubes[index][0])-100.0,0.0,1024.0-current_view_size.x),CyberExperimentTower.floor_y(tower_floor))

func tower_apply_profile(resolved: Dictionary) -> void:
	paused = true
	tower_command({"reset":true,"floor":tower_floor,"profile":resolved})

func tower_observation() -> void:
	var report: Dictionary = {"recipe_version":CyberExperimentTower.VERSION,"seed":0,"floor":tower_floor,"context":tower_context,"platform":OS.get_name(),"utc":Time.get_datetime_string_from_system(true)}
	if tower_context.get("water_active",false):
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
var last_render_patch_count: int = 0
var last_render_patch_bytes: int = 0
var last_render_was_full_refresh: bool = false
var rejected_render_snapshot_count: int = 0
var last_rejected_render_snapshot_serial: int = -1
var last_render_patch_validation_error: String = ""
var snapshot_blend_start_usec: int = 0
var glow_enabled: bool = true
var debug_stats_visible: bool = true
var glow_viewport: SubViewport
var glow_source: ColorRect
var glow_source_shader: ShaderMaterial
var glow_overlay: TextureRect
var glow_composite_shader: ShaderMaterial
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
var render_snapshot_hz_index: int = 1
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
var rigid_bodies: Array[RigidBody2D] = []
var rapier_bridge: CyberRapierPhysicsBridge = CyberRapierPhysicsBridge.new()
var rapier_start_error: Error = OK
var fallback_rigid_body_sample_serial: int = 0
var last_hard_surface_revision: int = -1
var hard_surface_rebuild_cooldown: float = 0.0


func _ready() -> void:
	setup_tower_panel()
	var tower_button: Button = Button.new()
	tower_button.text = "Experiment Tower / F9"
	tower_button.pressed.connect(tower_reset)
	$Layout.add_child(tower_button)
	if OS.get_processor_count() < 4:
		var warning: Label = Label.new()
		warning.text = "4 physical CPU cores are the recommended minimum. Fewer than 4 logical threads reported."
		warning.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
		$Layout.add_child(warning)
	status_label.visible = debug_stats_visible
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
	simulation_worker.set_rigid_body_states(pack_rigid_body_states())
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
		last_uploaded_revision = latest_snapshot.world_revision
		simulation_worker.acknowledge_render_snapshot(
			latest_snapshot.render_snapshot_serial
		)
	elif latest_snapshot != null:
		reject_render_snapshot(latest_snapshot)
	update_shader_parameters()
	update_status()


func _exit_tree() -> void:
	simulation_worker.stop_worker()
	rapier_bridge.shutdown()


func _process(delta: float) -> void:
	tower_panel.refresh(tower_active,tower_floor,tower_context)
	frame_time_ms = delta * 1000.0
	maximum_frame_time_ms = maxf(maximum_frame_time_ms, frame_time_ms)
	consume_worker_snapshot()
	hard_surface_rebuild_cooldown = maxf(0.0, hard_surface_rebuild_cooldown - delta)
	if hard_surface_rebuild_cooldown <= 0.0:
		sync_hard_surface_colliders()
	rapier_bridge.process_hard_surface_collider_budget(
		HARD_SURFACE_CHUNKS_PER_FRAME,
		HARD_SURFACE_FRAME_BUDGET_USEC
	)
	maximum_collider_time_ms = maxf(
		maximum_collider_time_ms,
		rapier_bridge.last_hard_surface_build_time_ms()
	)
	handle_painting()
	update_camera(delta)
	update_worker_frame_state()
	update_shader_parameters()

	status_accumulator += delta
	if status_accumulator >= STATUS_INTERVAL:
		status_accumulator = 0.0
		update_status()
		maximum_frame_time_ms = frame_time_ms
		maximum_collider_time_ms = 0.0


func _physics_process(_delta: float) -> void:
	if simulation_worker.has_failed():
		return
	if (
		rapier_bridge.is_initialized()
		and not paused
		and worker_start_error == OK
	):
		apply_latest_rigid_body_results()
		rapier_bridge.step()
	simulation_worker.set_rigid_body_states(pack_rigid_body_states())


func _unhandled_key_input(event: InputEvent) -> void:
	if tower_profile_panel != null and tower_profile_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: tower_profile_panel.hide()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		tower_reset()
		return
	if tower_active and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			selected_material_id = CyberExperimentTower.QUICK[tower_floor][int(event.keycode)-KEY_1]
			return
		if event.keycode == KEY_R:
			tower_reset()
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
			liquid_surface_adhesion_enabled = not liquid_surface_adhesion_enabled
		KEY_R:
			reset_world()
		KEY_P:
			paused = not paused
		KEY_F:
			camera_follow_enabled = not camera_follow_enabled
		KEY_L:
			simulation_window_enabled = not simulation_window_enabled
		KEY_K:
			cadence_lod_enabled = not cadence_lod_enabled
		KEY_H:
			cycle_render_snapshot_hz()
		KEY_G:
			glow_enabled = not glow_enabled
			if glow_overlay != null:
				glow_overlay.visible = glow_enabled
			if glow_viewport != null:
				glow_viewport.render_target_update_mode = (
					SubViewport.UPDATE_ALWAYS
					if glow_enabled
					else SubViewport.UPDATE_DISABLED
				)
		KEY_F3:
			debug_stats_visible = not debug_stats_visible
			status_label.visible = debug_stats_visible
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


func cycle_view_size() -> void:
	var previous_centre: Vector2 = camera_origin + Vector2(current_view_size) * 0.5
	view_size_index = (view_size_index + 1) % VIEW_SIZE_PRESETS.size()
	current_view_size = VIEW_SIZE_PRESETS[view_size_index]
	camera_origin = clamped_camera_origin(previous_centre - Vector2(current_view_size) * 0.5)
	update_worker_frame_state()
	update_shader_parameters()


func cycle_simulation_margin() -> void:
	simulation_margin_index = (simulation_margin_index + 1) % SIMULATION_MARGIN_PRESETS.size()
	simulation_margin = SIMULATION_MARGIN_PRESETS[simulation_margin_index]
	update_worker_frame_state()


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


func reset_world() -> void:
	reset_test_rigid_bodies()
	simulation_worker.queue_reset(CHARACTER_SPAWN)
	character_position = CHARACTER_SPAWN
	camera_follow_enabled = true
	camera_origin = clamped_camera_origin(character_centre() - Vector2(current_view_size) * 0.5)
	update_worker_frame_state()
	simulation_worker.set_rigid_body_states(pack_rigid_body_states())


func reset_test_rigid_bodies() -> void:
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
			return Vector2(124.0, 92.0)
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
	rapier_bridge.apply_cellular_results(
		latest_snapshot.serial,
		latest_snapshot.rigid_body_results
	)


func consume_worker_snapshot() -> void:
	var snapshot: CyberSimulationSnapshot = simulation_worker.take_latest_snapshot(consumed_snapshot_serial)
	if snapshot == null:
		return
	latest_snapshot = snapshot
	tower_context = snapshot.lab_context
	if not pending_water_apply.is_empty():
		if tower_context.get("water_active",false) and str(
			tower_context.get("water_policy_hash",""))==str(pending_water_apply.hash):
			var applied: Dictionary=pending_water_apply
			var recipe: Dictionary=applied.recipe
			water_policy_resolved=applied.result.duplicate(true)
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
		elif "rejected" in str(tower_context.get("status","")).to_lower():
			pending_water_apply.clear()
	if tower_context.has("profile"): tower_profile = tower_context.profile
	consumed_snapshot_serial = snapshot.serial
	if snapshot.simulation_failed:
		paused = true
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
			last_uploaded_render_snapshot_serial = snapshot.render_snapshot_serial
			simulation_worker.acknowledge_render_snapshot(
				snapshot.render_snapshot_serial
			)
		else:
			reject_render_snapshot(snapshot)


func record_render_payload(snapshot: CyberSimulationSnapshot) -> void:
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
	if latest_snapshot.hard_surface_chunk_rectangles_valid:
		rapier_bridge.queue_hard_surface_chunk_snapshot(
			latest_snapshot.hard_surface_chunk_rectangles
		)
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


func get_horizontal_input() -> float:
	var move_left: float = 1.0 if Input.is_key_pressed(KEY_A) else 0.0
	var move_right: float = 1.0 if Input.is_key_pressed(KEY_D) else 0.0
	return move_right - move_left


func update_camera(delta: float) -> void:
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
		Input.is_key_pressed(KEY_SPACE),
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


func handle_painting() -> void:
	if tower_profile_panel != null and tower_profile_panel.visible: return
	var mouse: Vector2 = world_view.get_local_mouse_position()
	var content_rect: Rect2 = view_content_rect()
	if content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		return
	if not content_rect.has_point(mouse):
		return
	var normalized_position: Vector2 = (mouse - content_rect.position) / content_rect.size
	var view_pixel: Vector2i = Vector2i(normalized_position * Vector2(current_view_size))
	if (
		view_pixel.x < 0
		or view_pixel.x >= current_view_size.x
		or view_pixel.y < 0
		or view_pixel.y >= current_view_size.y
	):
		return

	var emitted_material_id: int = selected_material_id
	var emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		emitted_material_id = CyberCellWorld.EMPTY
	elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	elif coherent_liquid_emission:
		emission_flags = CyberCellWorld.EMISSION_FLAG_COHERENT_LIQUID

	var world_x: int = floori(camera_origin.x) + view_pixel.x
	var world_y: int = floori(camera_origin.y) + view_pixel.y
	simulation_worker.queue_paint(
		world_x,
		world_y,
		4,
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
	world_shader.set_shader_parameter("player_origin_px", character_position)
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
	for body_index: int in range(rigid_bodies.size()):
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
				TEST_RIGID_BODY_SIZE.x,
				TEST_RIGID_BODY_SIZE.y
			)
		)
		world_shader.set_shader_parameter(
			"rigid_body_rotation_%d" % body_index,
			body_transform.get_rotation()
		)


func update_status() -> void:
	if latest_snapshot != null and latest_snapshot.simulation_failed:
		status_label.visible = true
		status_label.text = "Simulation stopped. Press R to reset. " + latest_snapshot.last_tick_error
		return
	status_label.visible = debug_stats_visible
	if not debug_stats_visible:
		return
	if latest_snapshot == null:
		status_label.text = "Simulation worker did not publish an initial snapshot."
		return
	var follow_text: String = "follow" if camera_follow_enabled else "free"
	var window_text: String = "windowed" if simulation_window_enabled else "whole-world"
	var cadence_text: String = "smooth" if cadence_lod_enabled else "raw"
	var emission_text: String = (
		"calm-emission" if coherent_liquid_emission else "spray-emission"
	)
	var selection_text: String = "material %s [id %d]" % [
		material_name(selected_material_id),
		selected_material_id,
	]
	if selected_paint_slot > 0:
		selection_text = "slot %d %s [id %d]" % [
			selected_paint_slot,
			material_name(selected_material_id),
			selected_material_id,
		]
	var region_text: String = "view %dx%d margin %dx%d" % [
		current_view_size.x,
		current_view_size.y,
		simulation_margin.x,
		simulation_margin.y,
	]
	var adhesion_text: String = "adhesion-on" if liquid_surface_adhesion_enabled else "adhesion-off"
	var glow_text: String = "glow-on" if glow_enabled else "glow-off"
	var snapshot_age_ms: float = maxf(
		0.0,
		float(Time.get_ticks_usec() - latest_snapshot.published_usec) / 1000.0
	)
	var thread_text: String = "%s/%d threads" % [
		latest_snapshot.backend_name,
		latest_snapshot.scheduler_thread_capacity_hint,
	]
	if worker_start_error != OK:
		thread_text = "thread-error-%d" % int(worker_start_error)
	var physics_text: String = "rapier-error-%d" % int(rapier_start_error)
	if rapier_bridge.is_initialized():
		physics_text = "Rapier %.2f+%.2f ms | hard %d | collider peak %.2f ms | pending %d" % [
			rapier_bridge.last_step_time_ms(),
			rapier_bridge.last_flush_time_ms(),
			rapier_bridge.hard_surface_shape_count(),
			maximum_collider_time_ms,
			rapier_bridge.pending_hard_surface_chunks(),
		]
	status_label.text = "FPS %d | frame %.2f ms peak %.2f | render %d Hz %s %s | step %.2f ms | upload %.2f ms | %s\n%s | tick %d age %.1f ms | bridge %d patches %.1f KiB%s | cells %d + %d dormant | moved %d (%d ballistic) | blocks %d/%d + %d frozen | sched %d jobs/%d phases cap~%d\n%s | %s | %s %s | bodies %d contact + %d displaced + %d unresolved | player %.0f,%.0f | camera %.0f,%.0f %s | %s | overruns %d | %s" % [
		int(Engine.get_frames_per_second()),
		frame_time_ms,
		maximum_frame_time_ms,
		render_snapshot_hz,
		cadence_text,
		glow_text,
		latest_snapshot.worker_step_time_ms,
		upload_time_ms,
		physics_text,
		thread_text,
		latest_snapshot.tick_index,
		snapshot_age_ms,
		last_render_patch_count,
		float(last_render_patch_bytes) / 1024.0,
		" full" if last_render_was_full_refresh else "",
		latest_snapshot.scanned_last_tick,
		latest_snapshot.dormant_cells_skipped_last_tick,
		latest_snapshot.moves_last_tick,
		latest_snapshot.sparse_flight_moves_last_tick,
		latest_snapshot.active_blocks_last_tick,
		latest_snapshot.eligible_blocks_last_tick,
		latest_snapshot.frozen_blocks_last_tick,
		latest_snapshot.scheduler_jobs_last_tick,
		latest_snapshot.scheduler_parallel_phases_last_tick,
		latest_snapshot.scheduler_thread_capacity_hint,
		selection_text,
		region_text,
		emission_text,
		adhesion_text,
		latest_snapshot.rigid_body_contacts_last_tick,
		latest_snapshot.rigid_body_displaced_last_tick,
		latest_snapshot.rigid_body_unresolved_last_tick,
		character_position.x,
		character_position.y,
		camera_origin.x,
		camera_origin.y,
		follow_text,
		window_text,
		latest_snapshot.worker_overruns,
		"PAUSED" if paused else "RUNNING",
	]
	if latest_snapshot.tick_failure_count > 0:
		status_label.text += " // STOPPED — R to reset. Fault %d: %s" % [
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
	glow_overlay.visible = glow_enabled
	world_view.add_child(glow_overlay)
	glow_source_shader.set_shader_parameter("world_texture", texture)
	glow_source_shader.set_shader_parameter(
		"material_program_lut",
		material_appearance_program
	)


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
			return "material-%d" % material_id
