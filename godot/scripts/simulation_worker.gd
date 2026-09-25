class_name CyberSimulationWorker
extends RefCounted

# This worker owns every mutable simulation object. The main thread sends only
# small commands and receives immutable snapshots, so rendering never reads a
# PackedByteArray while the cellular solver is modifying it.
const MicroCatalogue = preload("res://scripts/microscenario_catalogue.gd")
const MicroHost = preload("res://scripts/microscenario_host.gd")
const PlayerEnvironmentProfiles = preload("res://scripts/player_environment_profiles.gd")
const SIMULATION_HZ: float = 60.0
const FIXED_TIMESTEP: float = 1.0 / SIMULATION_HZ
const TICK_INTERVAL_USEC: int = 16667
const MAX_BACKLOG_TICKS: int = 3
const EMISSION_MATERIAL_MASK: int = 255
const EMISSION_FLAGS_SHIFT: int = 8
const DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC: int = 16667
const HARD_SURFACE_SNAPSHOT_INTERVAL_USEC: int = 250000
const RENDER_PATCH_METADATA_STRIDE: int = 6
const MAX_PENDING_RENDER_PATCHES: int = 256
const MAX_BRUSH_FOOTPRINT_CELLS: int = 4096
const MAX_PENDING_BRUSH_COMMANDS: int = 8

var _thread: Thread = Thread.new()
var _mutex: Mutex = Mutex.new()
# The Linux test build uses the compiled native phased backend. Unsupported
# platforms retain the script world as a functional compatibility fallback.
var _world = _create_world()
var _character: CyberSampledCharacter = CyberSampledCharacter.new()
# Worker-exclusive representation state. Only one player owner is active at a
# time; PCHAR representation changes are applied through fresh reset.
var _sampled_character_enabled: bool = true
var _player_environment_profile: Dictionary = PlayerEnvironmentProfiles.preset(
	PlayerEnvironmentProfiles.PRESET_CURRENT
)
var _pending_player_environment_profile: Dictionary = {}

var _running: bool = false
var _paused: bool = false
var _simulation_failed: bool = false # Exclusive worker state; main reads status under mutex.
var _horizontal_input: float = 0.0
var _jetpack_active: bool = false
var _interest_center: Vector2i = Vector2i.ZERO
var _view_origin: Vector2i = Vector2i.ZERO
var _view_size: Vector2i = Vector2i(320, 180)
var _horizontal_buffer: int = 32
var _vertical_buffer: int = 36
var _simulation_window_enabled: bool = true
var _cadence_lod_enabled: bool = true
var _liquid_surface_adhesion_enabled: bool = true
var _render_snapshot_interval_usec: int = DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC
var _rigid_body_states: PackedFloat32Array = PackedFloat32Array()

var _pending_emissions: Array[Vector4i] = []
var _pending_cell_emissions: Array[Dictionary] = []
var _reset_requested: bool = false
var _reset_spawn: Vector2 = Vector2(150.0, 145.0)
var _reset_sampled_character_enabled: bool = true
var _reset_runtime_enclosure_recovery_enabled: bool = true
var _lab_request: Dictionary = {} # One bounded pending control command; newest wins.
var _lab_active: bool = false
var _lab_floor: int = 0
var _lab_status: String = ""
var _lab_schedule: Array = [] # At most two floor-local release deadlines.
var _lab_inputs: Array = [] # Bounded observation input history.
var _lab_profile: Dictionary = CyberTransportProfiles.preset(0)
var _lab_profile_hash: String = ""
var _scenario_host: CyberMicroScenarioHost = MicroHost.new()
var _micro_active: bool = false
var _micro_capture: Dictionary = {}
var _micro_capture_serial: int = 0
var _water_lab_active: bool = false
var _water_policy: Dictionary = {}
var _water_policy_hash: String = ""
var _water_policy_provenance: Dictionary = {}
var _water_recipe: Dictionary = {}
var _water_recipe_hash: String = ""
var _water_blind_label: String = ""
var _water_action_index: int = 0
var _water_action_history: Array = []
var _water_observations: Array = []
var _water_initial_integer: int = 0
var _water_initial_requested_numerator_255: int = 0
var _water_initial_quantization_error_numerator_255: int = 0
var _water_current_integer: int = 0
var _water_explicit_source: int = 0
var _water_explicit_sink: int = 0

func queue_lab(command: Dictionary) -> void:
	_mutex.lock()
	_lab_request = command.duplicate(true)
	if command.has("step") or command.has("reset") or command.has("water_reset") or command.has("scenario_reset") or command.has("floor"): _paused = true
	_mutex.unlock()

func _lab_release(index: int) -> void:
	if _water_lab_active or _micro_active: return
	var plugs: Array[Rect2i] = CyberExperimentTower.plugs(_lab_floor)
	if index < 0 or index >= plugs.size(): return
	var plug: Rect2i = plugs[index]
	for y: int in range(plug.position.y,plug.end.y):
		for x: int in range(plug.position.x,plug.end.x): _world.paint_disc(x,y,0,0,0)

func _water_observe(action: Dictionary = {}) -> Dictionary:
	if not _world.has_method(&"water_experiment_observation"):
		return {}
	var origin: Vector2i=Vector2i.ZERO
	var size: Vector2i=Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT)
	if not action.is_empty():
		origin=Vector2i(int(action.x),int(action.y))
		size=Vector2i(int(action.width),int(action.height))
	return _world.water_experiment_observation(origin,size)

func _sync_micro_water_state() -> void:
	var state: Dictionary = _scenario_host.legacy_water_state()
	_water_action_index = int(state.action_index)
	_water_action_history = state.actions
	_water_observations = state.observations
	_water_explicit_source = int(state.explicit_source)
	_water_explicit_sink = int(state.explicit_sink)
	_water_current_integer = int(state.current)

func _apply_due_water_actions() -> bool:
	var ok: bool = _scenario_host.before_tick()
	if _water_lab_active: _sync_micro_water_state()
	if not ok: _lab_status = _scenario_host.last_error
	return ok

func _apply_lab(command: Dictionary) -> bool:
	if command.is_empty(): return false
	if command.has("reset"):
		if not ClassDB.class_exists(&"CyberDemoBridge") or not _world.has_method(&"has_failed"):
			_lab_status = "Experiment Tower requires the native backend"
			return false
		var resolved: Dictionary = command.profile if command.has("profile") else CyberTransportProfiles.resolve(_lab_profile)
		if not resolved.get("ok",false):
			_lab_status = "Profile rejected; running world preserved"
			return false
		var tower_definition: Dictionary = MicroCatalogue.tower(resolved.profile)
		if not _scenario_host.install(
			_world,
			tower_definition,
			str(command.get("scenario_mode", "Inspect"))
		):
			_lab_status = _scenario_host.last_error
			return false
		_activate_sampled_character(
			Vector2(
				tower_definition.player_start[0],
				tower_definition.player_start[1]
			),
			true
		)
		_lab_profile = resolved.profile.duplicate(true)
		_lab_profile_hash = str(resolved.hash)
		_lab_active = true
		_lab_schedule.clear();_lab_inputs.clear()
		_simulation_failed = false
		_lab_status = "%s / profile v1 %s / recipe v%d / seed 0" % [str(_lab_profile.name),_lab_profile_hash.left(12),CyberExperimentTower.VERSION]
		_water_lab_active=false
		_micro_active=false
		_micro_capture={}
	if command.has("water_reset"):
		if not ClassDB.class_exists(&"CyberDemoBridge") or not _world.has_method(&"get_water_experiment_policy"):
			_lab_status="Water Feel Lab requires the current native backend"
			return false
		var resolved: Dictionary=CyberWaterExperimentProfiles.resolve(
			{},{},command.get("water_policy",{}))
		if not resolved.get("ok",false) or (
			command.has("water_policy_hash") and str(command.water_policy_hash)!=str(resolved.hash)
		):
			_lab_status="Water policy rejected; running world preserved"
			return false
		var recipe: Dictionary=CyberWaterFeelScenarios.recipe(
			str(resolved.policy.scenario_id),int(resolved.policy.seed))
		if recipe.is_empty():
			_lab_status="Water scenario rejected; running world preserved"
			return false
		var profile_result: Dictionary=CyberTransportProfiles.resolve(
			CyberTransportProfiles.preset(0))
		if not _scenario_host.install(_world, MicroCatalogue.water(resolved), str(command.get("scenario_mode", "Inspect"))):
			_lab_status="Water Apply + Reset rejected; "+_scenario_host.last_error
			return false
		_lab_profile=profile_result.profile.duplicate(true)
		_lab_profile_hash=str(profile_result.hash)
		_lab_active=true
		_water_lab_active=true
		_micro_active=false
		_micro_capture={}
		_water_policy=resolved.policy.duplicate(true)
		_water_policy_hash=str(resolved.hash)
		_water_policy_provenance=command.get("water_policy_provenance",{}).duplicate(true)
		_water_recipe=recipe.duplicate(true)
		_water_recipe_hash=CyberWaterFeelScenarios.recipe_hash(recipe)
		_water_blind_label=str(command.get("blind_label",""))
		_water_action_index=0
		_water_action_history.clear()
		_water_observations.clear()
		_water_explicit_source=0
		_water_explicit_sink=0
		_water_initial_integer=int(_water_observe().get("water_integer",0))
		_water_current_integer=_water_initial_integer
		_water_initial_requested_numerator_255=0
		for offset: int in range(0,recipe.partial_water_fills.size(),6):
			_water_initial_requested_numerator_255+=(
				int(recipe.partial_water_fills[offset+2])
				*int(recipe.partial_water_fills[offset+3])
				*int(recipe.partial_water_fills[offset+4])
				*int(resolved.derived.maximum))
		_water_initial_quantization_error_numerator_255=(
			_water_initial_integer*255-_water_initial_requested_numerator_255)
		_lab_schedule.clear();_lab_inputs.clear()
		_simulation_failed=false
		_activate_sampled_character(Vector2(recipe.player_start), true)
		if _water_blind_label!="":
			_lab_status="Water Feel candidate %s / scenario %s / seed %d" % [
				_water_blind_label,str(_water_policy.scenario_id),int(_water_policy.seed)]
		else:
			_lab_status="Water Feel unblinded / policy %s / recipe %s / seed %d" % [
				_water_policy_hash.left(12),_water_recipe_hash.left(12),
				int(_water_policy.seed)]
	if command.has("scenario_reset"):
		if not _scenario_host.install(_world, command.scenario_reset, str(command.get("scenario_mode", "Inspect"))):
			_lab_status = "MicroScenario rejected; " + _scenario_host.last_error
			return false
		var definition: Dictionary = _scenario_host.definition()
		var transport: Dictionary = CyberTransportProfiles.resolve(definition.transport_profile)
		_lab_profile = transport.profile.duplicate(true)
		_lab_profile_hash = str(transport.hash)
		_lab_active = true
		_micro_active = true
		_water_lab_active = false
		_water_recipe.clear()
		_lab_schedule.clear()
		_lab_inputs.clear()
		_micro_capture = {}
		_simulation_failed = false
		_configure_sampled_character(
			Vector2(definition.player_start[0], definition.player_start[1]),
			bool(command.get("sampled_character_enabled", true)),
			bool(command.get("runtime_enclosure_recovery_enabled", true))
		)
		_lab_status = "MicroScenario " + str(definition.id)
	if not _lab_active: return false
	if command.has("scenario_capture") and _scenario_host.active():
		_micro_capture = _scenario_host.capture(command.get("identity", {}))
		_freeze_capture(_micro_capture)
		_micro_capture_serial += 1
	if (_water_lab_active or _micro_active) and (command.has("release") or command.has("schedule") or command.has("floor")):
		_lab_status="Water Feel uses only registered scenario actions; Tower releases are disabled"
		return false
	if command.has("floor"):
		_lab_schedule.clear() # Navigation abandons scheduled inputs; no catch-up.
		_lab_floor = clampi(int(command.floor),0,4)
		_activate_sampled_character(CyberExperimentTower.landing(_lab_floor), true)
	if command.has("release"):
		_lab_release(int(command.release))
		if command.get("adjacent",false): _lab_release(int(command.release)+1)
	if command.has("schedule"):
		var tick: int = int(_world.get_tick_index())
		_lab_schedule = [[tick+30,int(command.schedule),_lab_floor],[tick+90,int(command.schedule)+1,_lab_floor]]
	if _lab_inputs.size() < 256:
		var recorded: Dictionary = command.duplicate(true)
		recorded.erase("profile")
		recorded.erase("scenario_reset")
		recorded.erase("identity")
		recorded.erase("water_policy")
		recorded.erase("water_policy_hash")
		recorded.erase("water_policy_provenance")
		_lab_inputs.append({"tick":int(_world.get_tick_index()),"command":recorded,"profile_hash":_lab_profile_hash})
	return command.has("reset") or command.has("water_reset") or command.has("scenario_reset")

static func _freeze_capture(value: Variant) -> void:
	# One retained record may appear in several snapshots. Freeze nested values
	# once instead of copying a potentially large definition every frame.
	if value is Dictionary:
		for nested: Variant in value.values(): _freeze_capture(nested)
		value.make_read_only()
	elif value is Array:
		for nested: Variant in value: _freeze_capture(nested)
		value.make_read_only()

var _published_snapshot: CyberSimulationSnapshot
var _snapshot_serial: int = 0
var _snapshot_cells: PackedByteArray = PackedByteArray()
var _snapshot_world_revision: int = -1
var _last_render_snapshot_usec: int = -DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC
var _pending_render_snapshot_serial: int = 0
var _pending_render_channels: int = 1
var _pending_render_full_refresh: bool = false
var _pending_render_patch_rectangles: PackedInt32Array = PackedInt32Array()
var _pending_render_patch_cells: PackedByteArray = PackedByteArray()
var _pending_render_tick_index: int = 0
var _pending_render_generated_usec: int = 0
var _pending_render_character_position: Vector2 = Vector2.ZERO
var _pending_render_character_velocity: Vector2 = Vector2.ZERO
var _pending_render_character_grounded: bool = false
var _pending_render_rigid_body_states: PackedFloat32Array = PackedFloat32Array()
var _pending_render_simulation_time_ms: float = 0.0
var _pending_render_worker_step_time_ms: float = 0.0
var _pending_render_worker_overruns: int = 0
var _pending_render_context: Dictionary = {}
var _pending_render_payload_generation: int = 0
var _published_render_payload_generation: int = -1
var _published_render_patch_rectangles: PackedInt32Array = PackedInt32Array()
var _published_render_patch_cells: PackedByteArray = PackedByteArray()
var _acknowledged_render_snapshot_serial: int = 0
var _render_full_refresh_requested: bool = false
var _fallback_render_snapshot_serial: int = 0
var _snapshot_hard_surface_revision: int = -1
var _snapshot_hard_surface_rectangles: PackedInt32Array = PackedInt32Array()
var _snapshot_hard_surface_rectangles_valid: bool = false
var _snapshot_hard_surface_chunk_rectangles: PackedInt32Array = PackedInt32Array()
var _snapshot_hard_surface_chunk_rectangles_valid: bool = false
var _last_hard_surface_snapshot_usec: int = -HARD_SURFACE_SNAPSHOT_INTERVAL_USEC
var _worker_overruns: int = 0
var _scheduler_thread_capacity_hint: int = 1
var _backend_name: String = "gdscript-serial-fallback"


func _create_world():
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		var native_world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		if native_world != null:
			return native_world
	return CyberCellWorld.new()


func _configure_sampled_character(
	spawn_position: Vector2,
	enabled: bool,
	runtime_recovery_enabled: bool
) -> void:
	_sampled_character_enabled = enabled
	_character.configure_runtime_enclosure_recovery(runtime_recovery_enabled)
	_character.reset(spawn_position)
	if enabled:
		_character.recover_invalid_spawn(_world)


func _activate_sampled_character(
	spawn_position: Vector2,
	runtime_recovery_enabled: bool
) -> void:
	_configure_sampled_character(
		spawn_position,
		true,
		runtime_recovery_enabled
	)


func start_worker(spawn_position: Vector2) -> Error:
	if _thread.is_started():
		return OK
	if _world.has_method(&"get_worker_threads"):
		_scheduler_thread_capacity_hint = int(_world.get_worker_threads())
		_backend_name = str(_world.get_backend_name())
	else:
		_scheduler_thread_capacity_hint = 1
		_backend_name = "gdscript-serial-fallback"
	_character.configure_profile(_player_environment_profile)
	_activate_sampled_character(spawn_position, true)
	_publish_snapshot(0.0, false, _render_snapshot_interval_usec, true)
	_mutex.lock()
	_running = true
	_mutex.unlock()
	var start_error: Error = _thread.start(Callable(self, "_worker_loop"))
	if start_error != OK:
		_mutex.lock()
		_running = false
		_mutex.unlock()
	return start_error


func stop_worker() -> void:
	if not _thread.is_started():
		return
	_mutex.lock()
	_running = false
	_mutex.unlock()
	_thread.wait_to_finish()


func set_frame_state(
		horizontal_input: float,
		jetpack_active: bool,
		paused: bool,
		interest_center: Vector2i,
		view_origin: Vector2i,
		view_size: Vector2i,
		horizontal_buffer: int,
		vertical_buffer: int,
		simulation_window_enabled: bool,
		cadence_lod_enabled: bool,
		liquid_surface_adhesion_enabled: bool
) -> void:
	_mutex.lock()
	_horizontal_input = horizontal_input
	_jetpack_active = jetpack_active
	_paused = paused
	_interest_center = interest_center
	_view_origin = view_origin
	_view_size = view_size
	_horizontal_buffer = horizontal_buffer
	_vertical_buffer = vertical_buffer
	_simulation_window_enabled = simulation_window_enabled
	_cadence_lod_enabled = cadence_lod_enabled
	_liquid_surface_adhesion_enabled = liquid_surface_adhesion_enabled
	_mutex.unlock()


func set_rigid_body_states(states: PackedFloat32Array) -> void:
	# Packed value data is copied at the bridge; scene-tree nodes and Physics RIDs
	# remain exclusively on the main/physics thread.
	_mutex.lock()
	_rigid_body_states = states.duplicate()
	_mutex.unlock()


func set_render_snapshot_hz(render_hz: int) -> void:
	_mutex.lock()
	_render_snapshot_interval_usec = maxi(1, roundi(1000000.0 / maxf(float(render_hz), 1.0)))
	_mutex.unlock()


func queue_emit_disc(
	world_x: int,
	world_y: int,
	radius: int,
	material_id: int,
	emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
) -> bool:
	# Material and emission flags share the fourth integer so the command stays a
	# compact value type. UI/tool slots never enter this simulation-facing command.
	var packed_flags: int = emission_flags << EMISSION_FLAGS_SHIFT
	var packed_material: int = (material_id & EMISSION_MATERIAL_MASK) | packed_flags
	var emission_command: Vector4i = Vector4i(world_x, world_y, radius, packed_material)
	_mutex.lock()
	if _published_snapshot != null and _published_snapshot.simulation_failed:
		_mutex.unlock()
		return false
	if (_published_snapshot != null
		and _published_snapshot.lab_context.get("water_active",false)):
		_mutex.unlock()
		return false
	if _pending_emissions.is_empty() or _pending_emissions.back() != emission_command:
		_pending_emissions.append(emission_command)
	_mutex.unlock()
	return true


func queue_emit_cells(
	points: PackedInt32Array,
	material_id: int,
	emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
) -> bool:
	if points.is_empty() or (points.size() & 1) != 0:
		return false
	if points.size() / 2 > MAX_BRUSH_FOOTPRINT_CELLS:
		return false
	var packed_flags: int = emission_flags << EMISSION_FLAGS_SHIFT
	var packed_material: int = (material_id & EMISSION_MATERIAL_MASK) | packed_flags
	var command: Dictionary = {
		"points": points.duplicate(),
		"packed_material": packed_material,
	}
	_mutex.lock()
	if _published_snapshot != null and _published_snapshot.simulation_failed:
		_mutex.unlock()
		return false
	if (_published_snapshot != null
		and _published_snapshot.lab_context.get("water_active",false)):
		_mutex.unlock()
		return false
	if not _pending_cell_emissions.is_empty():
		var last_command: Dictionary = _pending_cell_emissions.back()
		if (
			int(last_command.get("packed_material", -1)) == packed_material
			and last_command.get("points", PackedInt32Array()) == points
		):
			_mutex.unlock()
			return true
	if _pending_cell_emissions.size() >= MAX_PENDING_BRUSH_COMMANDS:
		_mutex.unlock()
		return false
	_pending_cell_emissions.append(command)
	_mutex.unlock()
	return true


func queue_paint(
	world_x: int,
	world_y: int,
	radius: int,
	material_id: int,
	emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
) -> void:
	# Retain the prototype paint interface while equipment, enemies, and world
	# spawners can target the generic emission command directly.
	queue_emit_disc(world_x, world_y, radius, material_id, emission_flags)


func queue_reset(
	spawn_position: Vector2,
	sampled_character_enabled: bool = true,
	runtime_enclosure_recovery_enabled: bool = true
) -> void:
	_mutex.lock()
	_reset_requested = true
	_reset_spawn = spawn_position
	_reset_sampled_character_enabled = sampled_character_enabled
	_reset_runtime_enclosure_recovery_enabled = runtime_enclosure_recovery_enabled
	_pending_emissions.clear()
	_pending_cell_emissions.clear()
	_mutex.unlock()


func queue_player_environment_profile(profile: Dictionary) -> bool:
	var resolved: Dictionary = PlayerEnvironmentProfiles.resolve(profile)
	if not resolved.get("ok", false):
		return false
	_mutex.lock()
	_pending_player_environment_profile = resolved.profile.duplicate(true)
	# PENV tuning remains fresh-reset only. The presentation owner follows this
	# with the current TEST-UX/PCHAR-aware reset path so tool state and player
	# representation/recovery selection remain separate.
	_paused = true
	_mutex.unlock()
	return true


func take_latest_snapshot(after_serial: int) -> CyberSimulationSnapshot:
	_mutex.lock()
	var result: CyberSimulationSnapshot = _published_snapshot
	if result != null and result.serial <= after_serial:
		result = null
	_mutex.unlock()
	return result


func acknowledge_render_snapshot(render_snapshot_serial: int) -> void:
	if render_snapshot_serial <= 0:
		return
	_mutex.lock()
	_acknowledged_render_snapshot_serial = maxi(
		_acknowledged_render_snapshot_serial,
		render_snapshot_serial
	)
	_mutex.unlock()


func request_render_full_refresh() -> void:
	_mutex.lock()
	_render_full_refresh_requested = true
	_mutex.unlock()


func _worker_loop() -> void:
	var next_tick_usec: int = Time.get_ticks_usec()
	while true:
		var local_running: bool = false
		var local_paused: bool = false
		var local_horizontal_input: float = 0.0
		var local_jetpack_active: bool = false
		var local_interest_center: Vector2i = Vector2i.ZERO
		var local_view_origin: Vector2i = Vector2i.ZERO
		var local_view_size: Vector2i = Vector2i.ZERO
		var local_horizontal_buffer: int = 0
		var local_vertical_buffer: int = 0
		var local_window_enabled: bool = true
		var local_cadence_enabled: bool = true
		var local_liquid_adhesion_enabled: bool = true
		var local_render_snapshot_interval_usec: int = DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC
		var local_rigid_body_states: PackedFloat32Array = PackedFloat32Array()
		var local_emissions: Array[Vector4i] = []
		var local_cell_emissions: Array[Dictionary] = []
		var local_reset_requested: bool = false
		var local_reset_spawn: Vector2 = Vector2.ZERO
		var local_reset_sampled_character_enabled: bool = true
		var local_reset_runtime_recovery_enabled: bool = true
		var local_player_environment_profile: Dictionary = {}
		var local_lab: Dictionary = {}

		_mutex.lock()
		local_running = _running
		local_paused = _paused
		local_horizontal_input = _horizontal_input
		local_jetpack_active = _jetpack_active
		local_interest_center = _interest_center
		local_view_origin = _view_origin
		local_view_size = _view_size
		local_horizontal_buffer = _horizontal_buffer
		local_vertical_buffer = _vertical_buffer
		local_window_enabled = _simulation_window_enabled
		local_cadence_enabled = _cadence_lod_enabled
		local_liquid_adhesion_enabled = _liquid_surface_adhesion_enabled
		local_render_snapshot_interval_usec = _render_snapshot_interval_usec
		local_rigid_body_states = _rigid_body_states
		local_emissions = _pending_emissions
		_pending_emissions = []
		local_cell_emissions = _pending_cell_emissions
		_pending_cell_emissions = []
		local_reset_requested = _reset_requested
		local_reset_spawn = _reset_spawn
		local_reset_sampled_character_enabled = _reset_sampled_character_enabled
		local_reset_runtime_recovery_enabled = _reset_runtime_enclosure_recovery_enabled
		_reset_requested = false
		local_player_environment_profile = _pending_player_environment_profile
		_pending_player_environment_profile = {}
		local_lab = _lab_request
		_lab_request = {}
		_mutex.unlock()

		if not local_running:
			return

		var step_start_usec: int = Time.get_ticks_usec()
		if _apply_lab(local_lab):
			local_reset_requested = false
			local_paused = true
			_last_render_snapshot_usec = -DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC
		if not local_player_environment_profile.is_empty():
			_player_environment_profile = local_player_environment_profile.duplicate(true)
			_character.configure_profile(_player_environment_profile)
			_last_render_snapshot_usec = -DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC
		if _water_lab_active:
			local_emissions.clear()
			local_cell_emissions.clear()
		if _micro_active:
			for i: int in range(local_emissions.size() - 1, -1, -1):
				var tool: String = "erase" if (local_emissions[i].w & EMISSION_MATERIAL_MASK) == 0 else "paint"
				if not _scenario_host.allows_tool(tool): local_emissions.remove_at(i)
			for i: int in range(local_cell_emissions.size() - 1, -1, -1):
				var packed_material: int = int(local_cell_emissions[i].get("packed_material", 0))
				var tool: String = "erase" if (packed_material & EMISSION_MATERIAL_MASK) == 0 else "paint"
				if not _scenario_host.allows_tool(tool): local_cell_emissions.remove_at(i)
		if _lab_active:
			if not ((_water_lab_active and bool(_water_recipe.get("body_enabled",false))) or (_micro_active and _scenario_host.body_enabled())):
				local_rigid_body_states = PackedFloat32Array()
			if local_lab.get("step",false): local_paused = false
			if not local_paused:
				if _scenario_host.active() and not _apply_due_water_actions():
					local_paused=true
					_mutex.lock()
					_paused=true
					_mutex.unlock()
				for release: Array in _lab_schedule.duplicate():
					if int(release[2]) == _lab_floor and int(_world.get_tick_index())+1 >= int(release[0]):
						_lab_release(int(release[1]))
						_lab_schedule.erase(release)
		if _micro_active and _scenario_host.fixed_execution():
			local_cadence_enabled = _scenario_host.cadence_enabled()
			local_liquid_adhesion_enabled = _scenario_host.adhesion_enabled()
		_world.simulation_window_enabled = local_window_enabled
		_world.cadence_lod_enabled = local_cadence_enabled
		_world.set_liquid_surface_adhesion_enabled(local_liquid_adhesion_enabled)
		_world.set_interest_center(local_interest_center)
		_world.set_simulation_window(
			local_view_origin,
			local_view_size,
			local_horizontal_buffer,
			local_vertical_buffer
		)

		if _micro_active: _scenario_host.apply_interest()

		if local_reset_requested:
			var recovered: bool = true
			if _world.has_method(&"has_failed"):
				recovered = bool(_world.reset_demo_world())
			else:
				_world.reset_demo_world()
			if recovered:
				_scenario_host.clear()
				_lab_active = false
				_micro_active = false
				_water_lab_active = false
				_micro_capture = {}
				_simulation_failed = false
				_sampled_character_enabled = local_reset_sampled_character_enabled
				_character.configure_runtime_enclosure_recovery(
					local_reset_runtime_recovery_enabled
				)
				_character.reset(local_reset_spawn)
				if _sampled_character_enabled:
					_character.recover_invalid_spawn(_world)
				# Publish the replacement before any attempted continuation.
				local_paused = true
		if not _simulation_failed:
			_world.prepare_rigid_body_coupling(local_rigid_body_states, not local_paused)
			for emission_command: Vector4i in local_emissions:
				_world.emit_disc(
					emission_command.x,
					emission_command.y,
					emission_command.z,
					emission_command.w & EMISSION_MATERIAL_MASK,
					emission_command.w >> EMISSION_FLAGS_SHIFT
				)
			for emission_batch: Dictionary in local_cell_emissions:
				var points: PackedInt32Array = emission_batch.get("points", PackedInt32Array())
				var packed_material: int = int(emission_batch.get("packed_material", 0))
				for point_index: int in range(0, points.size(), 2):
					_world.emit_disc(
						points[point_index],
						points[point_index + 1],
						0,
						packed_material & EMISSION_MATERIAL_MASK,
						packed_material >> EMISSION_FLAGS_SHIFT
					)

			if not local_paused:
				if (
					_sampled_character_enabled
					and (not _micro_active or _scenario_host.player_enabled())
				):
					_character.simulate(
						FIXED_TIMESTEP,
						local_horizontal_input,
						local_jetpack_active,
						_world
					)
				if _world.has_method(&"has_failed"):
					_simulation_failed = not bool(_world.simulation_tick())
				else:
					_world.simulation_tick()
				if _lab_active and _scenario_host.active() and not _scenario_host.after_tick():
					_lab_status = _scenario_host.last_error
					local_paused = true
					_mutex.lock()
					_paused = true
					_mutex.unlock()

		var worker_step_time_ms: float = float(Time.get_ticks_usec() - step_start_usec) / 1000.0
		_publish_snapshot(
			worker_step_time_ms,
			local_paused,
			local_render_snapshot_interval_usec,
			local_reset_requested,
			local_rigid_body_states
		)

		next_tick_usec += TICK_INTERVAL_USEC
		var now_usec: int = Time.get_ticks_usec()
		var wait_usec: int = next_tick_usec - now_usec
		if wait_usec > 0:
			OS.delay_usec(wait_usec)
		elif -wait_usec > TICK_INTERVAL_USEC * MAX_BACKLOG_TICKS:
			_worker_overruns += 1
			next_tick_usec = now_usec


func _publish_snapshot(
	worker_step_time_ms: float,
	paused: bool,
	render_snapshot_interval_usec: int,
	force_render_full_refresh: bool = false,
	rigid_body_states: PackedFloat32Array = PackedFloat32Array()
) -> void:
	if _simulation_failed:
		_publish_failure_snapshot()
		return
	var copy_start_usec: int = Time.get_ticks_usec()
	var now_usec: int = Time.get_ticks_usec()
	var render_serial_before: int = _pending_render_snapshot_serial
	var render_generation_advanced: bool = false
	var acknowledged_render_serial: int = 0
	var render_full_refresh_requested: bool = false
	_mutex.lock()
	acknowledged_render_serial = _acknowledged_render_snapshot_serial
	render_full_refresh_requested = _render_full_refresh_requested
	_render_full_refresh_requested = false
	_mutex.unlock()
	force_render_full_refresh = (
		force_render_full_refresh or render_full_refresh_requested
	)
	if (
		_pending_render_snapshot_serial > 0
		and acknowledged_render_serial >= _pending_render_snapshot_serial
	):
		_clear_pending_render_patches()
	if (
		force_render_full_refresh
		or (
			_world.revision != _snapshot_world_revision
			and now_usec - _last_render_snapshot_usec >= render_snapshot_interval_usec
		)
	):
		if _world.has_method(&"take_render_snapshot"):
			var render_packet: Dictionary = _world.take_render_snapshot(
				force_render_full_refresh
			)
			_append_native_render_packet(render_packet)
			if (
				_pending_render_patch_cells.size()
				> CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2
				or _pending_render_patch_rectangles.size()
				> MAX_PENDING_RENDER_PATCHES * RENDER_PATCH_METADATA_STRIDE
			):
				_append_native_render_packet(_world.take_render_snapshot(true))
			if _pending_render_full_refresh:
				_snapshot_cells = _pending_render_patch_cells.duplicate()
		else:
			_snapshot_cells = PackedByteArray(_world.get_cells())
			_fallback_render_snapshot_serial += 1
			_pending_render_snapshot_serial = _fallback_render_snapshot_serial
			_pending_render_channels = 1
			_pending_render_full_refresh = true
			_pending_render_patch_rectangles = PackedInt32Array([
				0,
				0,
				CyberCellWorld.WORLD_WIDTH,
				CyberCellWorld.WORLD_HEIGHT,
				0,
				CyberCellWorld.WORLD_WIDTH,
			])
			_pending_render_patch_cells = _snapshot_cells
			_pending_render_payload_generation += 1
		_snapshot_world_revision = _world.revision
		_last_render_snapshot_usec = now_usec
		if _pending_render_snapshot_serial > render_serial_before:
			_pending_render_tick_index = int(_world.tick_index)
			_pending_render_generated_usec = now_usec
			_pending_render_character_position = _character.position
			_pending_render_character_velocity = _character.velocity
			_pending_render_character_grounded = _character.grounded
			_pending_render_rigid_body_states = rigid_body_states.duplicate()
			_pending_render_simulation_time_ms = _world.simulation_time_ms
			_pending_render_worker_step_time_ms = worker_step_time_ms
			_pending_render_worker_overruns = _worker_overruns
			render_generation_advanced = true
	var current_hard_surface_revision: int = int(_world.hard_surface_revision)
	if (
		current_hard_surface_revision != _snapshot_hard_surface_revision
		and now_usec - _last_hard_surface_snapshot_usec >= HARD_SURFACE_SNAPSHOT_INTERVAL_USEC
	):
		if _world.has_method(&"get_hard_surface_chunk_rectangles"):
			_snapshot_hard_surface_chunk_rectangles = PackedInt32Array(
				_world.get_hard_surface_chunk_rectangles()
			)
			_snapshot_hard_surface_chunk_rectangles_valid = true
		elif _world.has_method(&"get_hard_surface_rectangles"):
			_snapshot_hard_surface_rectangles = PackedInt32Array(
				_world.get_hard_surface_rectangles()
			)
			_snapshot_hard_surface_rectangles_valid = true
		_snapshot_hard_surface_revision = current_hard_surface_revision
		_last_hard_surface_snapshot_usec = now_usec
	var copy_time_ms: float = float(Time.get_ticks_usec() - copy_start_usec) / 1000.0

	var snapshot: CyberSimulationSnapshot = CyberSimulationSnapshot.new()
	_snapshot_serial += 1
	snapshot.serial = _snapshot_serial
	snapshot.published_usec = Time.get_ticks_usec()
	snapshot.world_revision = _snapshot_world_revision
	snapshot.simulation_world_revision = int(_world.revision)
	snapshot.hard_surface_revision = _snapshot_hard_surface_revision
	snapshot.cells = _snapshot_cells
	snapshot.render_snapshot_serial = _pending_render_snapshot_serial
	snapshot.render_channels = _pending_render_channels
	snapshot.render_full_refresh = _pending_render_full_refresh
	snapshot.render_tick_index = _pending_render_tick_index
	snapshot.render_generated_usec = _pending_render_generated_usec
	snapshot.render_character_position = _pending_render_character_position
	snapshot.render_character_velocity = _pending_render_character_velocity
	snapshot.render_character_grounded = _pending_render_character_grounded
	snapshot.render_rigid_body_states = _pending_render_rigid_body_states
	snapshot.render_simulation_time_ms = _pending_render_simulation_time_ms
	snapshot.render_worker_step_time_ms = _pending_render_worker_step_time_ms
	snapshot.render_worker_overruns = _pending_render_worker_overruns
	_refresh_published_render_payload()
	snapshot.render_patch_rectangles = _published_render_patch_rectangles
	snapshot.render_patch_cells = _published_render_patch_cells
	snapshot.hard_surface_rectangles = _snapshot_hard_surface_rectangles
	snapshot.hard_surface_rectangles_valid = _snapshot_hard_surface_rectangles_valid
	snapshot.hard_surface_chunk_rectangles = _snapshot_hard_surface_chunk_rectangles
	snapshot.hard_surface_chunk_rectangles_valid = (
		_snapshot_hard_surface_chunk_rectangles_valid
	)
	snapshot.character_position = _character.position
	snapshot.character_velocity = _character.velocity
	snapshot.character_grounded = _character.grounded
	snapshot.current_rigid_body_states = rigid_body_states.duplicate()
	snapshot.character_runtime_recovery_enabled = (
		_character.runtime_enclosure_recovery_enabled
	)
	snapshot.character_runtime_enclosed = _character.runtime_enclosed
	snapshot.character_runtime_recovery_attempts = _character.runtime_recovery_attempts
	snapshot.character_runtime_recovery_successes = _character.runtime_recovery_successes
	snapshot.character_runtime_recovery_upward_cells = _character.runtime_recovery_upward_cells
	snapshot.character_invalid_spawn_recovery_attempts = (
		_character.invalid_spawn_recovery_attempts
	)
	snapshot.character_invalid_spawn_recovery_successes = (
		_character.invalid_spawn_recovery_successes
	)
	snapshot.character_last_recovery_kind = _character.last_recovery_kind
	snapshot.character_last_recovery_offset = _character.last_recovery_offset
	snapshot.tick_index = _world.tick_index
	snapshot.moves_last_tick = _world.moves_last_tick
	snapshot.scanned_last_tick = _world.scanned_last_tick
	snapshot.dormant_cells_skipped_last_tick = _world.dormant_cells_skipped_last_tick
	snapshot.active_blocks_last_tick = _world.active_blocks_last_tick
	snapshot.eligible_blocks_last_tick = _world.eligible_blocks_last_tick
	snapshot.adaptive_block_stride_last_tick = _world.adaptive_block_stride_last_tick
	snapshot.deferred_blocks_last_tick = _world.deferred_blocks_last_tick
	snapshot.frozen_blocks_last_tick = _world.frozen_blocks_last_tick
	snapshot.scheduler_jobs_last_tick = _world.scheduler_jobs_last_tick
	snapshot.scheduler_parallel_phases_last_tick = _world.scheduler_parallel_phases_last_tick
	snapshot.scheduler_thread_capacity_hint = _scheduler_thread_capacity_hint
	snapshot.backend_name = _backend_name
	snapshot.sparse_flight_moves_last_tick = _world.sparse_flight_moves_last_tick
	snapshot.rigid_body_results = _world.rigid_body_results()
	snapshot.rigid_body_contacts_last_tick = _world.rigid_body_contacts_last_tick
	snapshot.rigid_body_displaced_last_tick = _world.rigid_body_displaced_last_tick
	snapshot.rigid_body_unresolved_last_tick = _world.rigid_body_unresolved_last_tick
	snapshot.simulation_time_ms = _world.simulation_time_ms
	snapshot.worker_step_time_ms = worker_step_time_ms
	snapshot.snapshot_copy_time_ms = copy_time_ms
	snapshot.worker_overruns = _worker_overruns
	if _world.has_method(&"get_tick_failure_count"):
		snapshot.tick_failure_count = int(_world.get_tick_failure_count())
		snapshot.last_tick_error = str(_world.get_last_tick_error())
	snapshot.paused = paused
	snapshot.lab_context = {
		"tick":snapshot.tick_index,
		"paused":paused,
		"visited_cells":snapshot.scanned_last_tick,
		"active_blocks":snapshot.active_blocks_last_tick,
		"moves":snapshot.moves_last_tick,
		"active":_lab_active,
		"floor":_lab_floor,
		"status":_lab_status,
		"inputs":_lab_inputs.duplicate(true),
		"input_limit":256,
		"profile":_lab_profile.duplicate(true),
		"profile_hash":_lab_profile_hash,
		"player_environment_profile":_player_environment_profile.duplicate(true),
		"sampled_character_enabled":_sampled_character_enabled,
		"sampled_runtime_recovery_enabled":(
			_character.runtime_enclosure_recovery_enabled
		),
		"micro_active":_micro_active,
		"microscenario":_scenario_host.summary() if _lab_active else {},
		"micro_capture_serial":_micro_capture_serial,
		"micro_capture":_micro_capture, # Immutable one-slot result; replaced, never mutated.
		"water_active":_water_lab_active,
		"water_policy":_water_policy.duplicate(true),
		"water_policy_hash":_water_policy_hash,
		"water_policy_provenance":_water_policy_provenance.duplicate(true),
		"water_recipe_hash":_water_recipe_hash,
		"water_blind_label":_water_blind_label,
		"water_actions":_water_action_history.duplicate(true),
		"water_observations":_water_observations.duplicate(true),
		"water_accounting":{
			"initial_integer":_water_initial_integer,
			"initial_requested_numerator_255":_water_initial_requested_numerator_255,
			"initial_quantization_error_numerator_255":_water_initial_quantization_error_numerator_255,
			"explicit_source":_water_explicit_source,
			"explicit_sink":_water_explicit_sink,
			"outflow":0,
			"current":_water_current_integer if _water_lab_active else 0,
		},
	}
	if render_generation_advanced:
		var render_micro: Dictionary = snapshot.lab_context.get("microscenario", {})
		var render_presentation: Dictionary = render_micro.get("presentation", {})
		var render_profile: Dictionary = snapshot.lab_context.get("profile", {})
		_pending_render_context = {
			"micro_active": bool(snapshot.lab_context.get("micro_active", false)),
			"profile": {"name": str(render_profile.get("name", ""))},
			"profile_hash": str(snapshot.lab_context.get("profile_hash", "")),
			"water_policy_hash": str(snapshot.lab_context.get("water_policy_hash", "")),
			"player_environment_profile": snapshot.lab_context.get(
				"player_environment_profile",
				{}
			).duplicate(true),
			"microscenario": {
				"id": str(render_micro.get("id", "")),
				"definition_hash": str(render_micro.get("definition_hash", "")),
				"source_recipe": str(render_micro.get("source_recipe", "")),
				"source_recipe_hash": str(render_micro.get("source_recipe_hash", "")),
				"seed": int(render_micro.get("seed", 0)),
				"mode": str(render_micro.get("mode", "")),
				"presentation": {
					"profile": str(render_presentation.get("profile", "")),
				},
			},
		}
		_freeze_capture(_pending_render_context)
	snapshot.render_context = _pending_render_context

	_mutex.lock()
	_published_snapshot = snapshot
	_mutex.unlock()


func has_failed() -> bool:
	_mutex.lock()
	var failed: bool = _published_snapshot != null and _published_snapshot.simulation_failed
	_mutex.unlock()
	return failed


func _publish_failure_snapshot() -> void:
	# Copy the last valid publication, never partial cells/character/body results.
	# The previous snapshot and its packed payloads remain immutable.
	var previous: CyberSimulationSnapshot = _published_snapshot
	if previous != null and previous.simulation_failed:
		return
	var snapshot: CyberSimulationSnapshot = CyberSimulationSnapshot.new()
	if previous != null:
		for property: Dictionary in previous.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				snapshot.set(property.name, previous.get(property.name))
	_snapshot_serial += 1
	snapshot.serial = _snapshot_serial
	snapshot.published_usec = Time.get_ticks_usec()
	snapshot.simulation_failed = true
	snapshot.paused = true
	snapshot.rigid_body_results = PackedFloat32Array()
	snapshot.failed_tick_index = int(_world.get_attempted_tick_index())
	snapshot.tick_failure_count = int(_world.get_tick_failure_count())
	snapshot.last_tick_error = str(_world.get_last_tick_error())
	_mutex.lock()
	_pending_emissions.clear()
	_published_snapshot = snapshot
	_mutex.unlock()


func _clear_pending_render_patches() -> void:
	_pending_render_full_refresh = false
	_pending_render_patch_rectangles = PackedInt32Array()
	_pending_render_patch_cells = PackedByteArray()
	_pending_render_payload_generation += 1


func _refresh_published_render_payload() -> void:
	if _published_render_payload_generation == _pending_render_payload_generation:
		return
	# Packed arrays are reference types. These copies are the ownership boundary
	# between the worker's mutable accumulation buffers and immutable snapshots
	# consumed by the main thread.
	_published_render_patch_rectangles = _pending_render_patch_rectangles.duplicate()
	_published_render_patch_cells = _pending_render_patch_cells.duplicate()
	_published_render_payload_generation = _pending_render_payload_generation


func _append_native_render_packet(packet: Dictionary) -> void:
	var packet_cells: PackedByteArray = packet.get("cells", PackedByteArray())
	var packet_rectangles: PackedInt32Array = packet.get(
		"rectangles",
		PackedInt32Array()
	)
	if packet_cells.is_empty() or packet_rectangles.is_empty():
		return

	var packet_serial: int = int(packet.get("serial", 0))
	var packet_channels: int = int(packet.get("channels", 2))
	var packet_full_refresh: bool = bool(packet.get("full_refresh", false))
	if packet_full_refresh:
		_pending_render_patch_rectangles = packet_rectangles
		_pending_render_patch_cells = packet_cells
		_pending_render_full_refresh = true
	else:
		var data_offset_base: int = _pending_render_patch_cells.size()
		_pending_render_patch_cells.append_array(packet_cells)
		for metadata_offset: int in range(
			0,
			packet_rectangles.size(),
			RENDER_PATCH_METADATA_STRIDE
		):
			_pending_render_patch_rectangles.append(packet_rectangles[metadata_offset])
			_pending_render_patch_rectangles.append(packet_rectangles[metadata_offset + 1])
			_pending_render_patch_rectangles.append(packet_rectangles[metadata_offset + 2])
			_pending_render_patch_rectangles.append(packet_rectangles[metadata_offset + 3])
			_pending_render_patch_rectangles.append(
				packet_rectangles[metadata_offset + 4] + data_offset_base
			)
			_pending_render_patch_rectangles.append(packet_rectangles[metadata_offset + 5])

	# Native exchange serials restart on validated World replacement. Desktop
	# acknowledgements belong to the worker lifetime and must remain monotonic.
	_pending_render_snapshot_serial = maxi(_pending_render_snapshot_serial+1,packet_serial)
	_pending_render_channels = packet_channels
	_pending_render_payload_generation += 1
