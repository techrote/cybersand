class_name CyberSimulationWorker
extends RefCounted

# This worker owns every mutable simulation object. The main thread sends only
# small commands and receives immutable snapshots, so rendering never reads a
# PackedByteArray while the cellular solver is modifying it.
const SIMULATION_HZ: float = 60.0
const FIXED_TIMESTEP: float = 1.0 / SIMULATION_HZ
const TICK_INTERVAL_USEC: int = 16667
const MAX_BACKLOG_TICKS: int = 3
const EMISSION_MATERIAL_MASK: int = 255
const EMISSION_FLAGS_SHIFT: int = 8
const DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC: int = 22222
const HARD_SURFACE_SNAPSHOT_INTERVAL_USEC: int = 250000
const RENDER_PATCH_METADATA_STRIDE: int = 6
const MAX_PENDING_RENDER_PATCHES: int = 256

var _thread: Thread = Thread.new()
var _mutex: Mutex = Mutex.new()
# The Linux test build uses the compiled native phased backend. Unsupported
# platforms retain the script world as a functional compatibility fallback.
var _world = _create_world()
var _character: CyberSampledCharacter = CyberSampledCharacter.new()

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
var _reset_requested: bool = false
var _reset_spawn: Vector2 = Vector2(150.0, 145.0)
var _lab_request: Dictionary = {} # One bounded pending control command; newest wins.
var _lab_active: bool = false
var _lab_floor: int = 0
var _lab_status: String = ""
var _lab_schedule: Array = [] # At most two floor-local release deadlines.
var _lab_inputs: Array = [] # Bounded observation input history.
var _lab_profile: Dictionary = CyberTransportProfiles.preset(0)
var _lab_profile_hash: String = ""
var _micro_host: CyberMicroScenarioHost = CyberMicroScenarioHost.new()
var _micro_active: bool = false
var _micro_definition: Dictionary = {}
var _micro_result: Dictionary = {}
var _micro_capture: Dictionary = {}
var _micro_owner_config: Dictionary = {}
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
	var request: Dictionary = command
	if command.has("micro_reset"):
		var checked: Dictionary = CyberMicroScenarioContract.validate(command.micro_reset)
		if not checked.get("ok", false):
			request = {"micro_rejection": str(checked.error), "request_id": command.get("request_id", 0)}
	_mutex.lock()
	_lab_request = request.duplicate(true)
	if command.has("step") or command.has("reset") or command.has("water_reset") or command.has("micro_reset") or command.has("floor"): _paused = true
	_mutex.unlock()

func _lab_release(index: int) -> void:
	if _water_lab_active: return
	var plugs: Array[Rect2i] = CyberExperimentTower.plugs(_lab_floor)
	if index < 0 or index >= plugs.size(): return
	var plug: Rect2i = plugs[index]
	for y: int in range(plug.position.y,plug.end.y):
		for x: int in range(plug.position.x,plug.end.x): _world.paint_disc(x,y,0,0,0)

func _water_observe(action: Dictionary = {}) -> Dictionary:
	return CyberMicroScenarioHost.observe(_world, action)

func _apply_due_water_actions() -> bool:
	var ok: bool = _micro_host.apply_due(_world)
	_water_action_index = _micro_host.event_index
	_water_action_history = _micro_host.history.duplicate(true)
	_water_observations = _micro_host.observations.duplicate(true)
	_water_explicit_source = _micro_host.explicit_source
	_water_explicit_sink = _micro_host.explicit_sink
	_water_current_integer = _micro_host.current_integer
	if not ok: _lab_status = "Water action rejected; " + _micro_host.last_error
	return ok

func _apply_lab(command: Dictionary) -> bool:
	if command.is_empty(): return false
	if command.has("micro_rejection"):
		_micro_result = {"request_id": int(command.get("request_id", 0)), "ok": false, "error": str(command.micro_rejection)}
		return false
	if command.has("micro_capture"):
		_micro_capture = _micro_host.capture(_world, _micro_owner_config)
		_micro_capture["request_id"] = int(command.micro_capture)
		return false
	if command.has("micro_reset"):
		var ok: bool = _micro_host.reset(_world, command.micro_reset,
			str(command.get("micro_mode", "inspect")), bool(command.get("micro_observers", true)))
		_micro_result = {"request_id": int(command.get("request_id", 0)), "ok": ok,
			"error": _micro_host.last_error}
		if not ok:
			_lab_status = "MicroScenario rejected; " + _micro_host.last_error
			return false
		_micro_definition = _micro_host.definition()
		_micro_active = true
		_micro_capture.clear()
		_lab_active = true
		_water_lab_active = false
		_lab_schedule.clear(); _lab_inputs.clear()
		_simulation_failed = false
		_lab_status = "MicroScenario / " + str(_micro_definition.id)
		if _micro_definition.player_start != null:
			_character.reset(Vector2(_micro_definition.player_start[0], _micro_definition.player_start[1]))
		return true
	if _micro_active and not command.has("reset") and (command.has("floor") or command.has("release") or command.has("schedule")):
		_lab_status = "MicroScenario rejects Tower-local controls"
		return false
	if command.has("reset"):
		if not ClassDB.class_exists(&"CyberDemoBridge") or not _world.has_method(&"has_failed"):
			_lab_status = "Experiment Tower requires the native backend"
			return false
		var resolved: Dictionary = command.profile if command.has("profile") else CyberTransportProfiles.resolve(_lab_profile)
		if not resolved.get("ok",false):
			_lab_status = "Profile rejected; running world preserved"
			return false
		if not _micro_host.reset(_world, CyberMicroScenarioCatalogue.tower(resolved.profile),
			str(command.get("micro_mode", "inspect")), bool(command.get("micro_observers", true))):
			_lab_status = _micro_host.last_error
			return false
		_lab_profile = resolved.profile.duplicate(true)
		_lab_profile_hash = str(resolved.hash)
		_lab_active = true
		_lab_schedule.clear();_lab_inputs.clear()
		_simulation_failed = false
		_lab_status = "%s / profile v1 %s / recipe v%d / seed 0" % [str(_lab_profile.name),_lab_profile_hash.left(12),CyberExperimentTower.VERSION]
		_water_lab_active=false
		_micro_active=false
		_micro_capture.clear()
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
		if not _micro_host.reset(_world, CyberMicroScenarioCatalogue.water(resolved.policy),
			str(command.get("micro_mode", "inspect")), bool(command.get("micro_observers", true))):
			_lab_status="Water Apply + Reset rejected; "+_micro_host.last_error
			return false
		_lab_profile=profile_result.profile.duplicate(true)
		_lab_profile_hash=str(profile_result.hash)
		_lab_active=true
		_water_lab_active=true
		_micro_active=false
		_micro_capture.clear()
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
		_water_initial_integer = _micro_host.initial_integer
		_water_current_integer = _micro_host.current_integer
		_water_initial_requested_numerator_255 = _micro_host.initial_requested_numerator_255
		_water_initial_quantization_error_numerator_255 = _micro_host.initial_quantization_error_numerator_255
		_lab_schedule.clear();_lab_inputs.clear()
		_simulation_failed=false
		_character.reset(Vector2(recipe.player_start))
		if _water_blind_label!="":
			_lab_status="Water Feel candidate %s / scenario %s / seed %d" % [
				_water_blind_label,str(_water_policy.scenario_id),int(_water_policy.seed)]
		else:
			_lab_status="Water Feel unblinded / policy %s / recipe %s / seed %d" % [
				_water_policy_hash.left(12),_water_recipe_hash.left(12),
				int(_water_policy.seed)]
	if not _lab_active: return false
	if _water_lab_active and (command.has("release") or command.has("schedule")):
		_lab_status="Water Feel uses only registered scenario actions; Tower releases are disabled"
		return false
	if command.has("floor"):
		_lab_schedule.clear() # Navigation abandons scheduled inputs; no catch-up.
		_lab_floor = clampi(int(command.floor),0,4)
		_character.reset(CyberExperimentTower.landing(_lab_floor))
	if command.has("release"):
		_lab_release(int(command.release))
		if command.get("adjacent",false): _lab_release(int(command.release)+1)
	if command.has("schedule"):
		var tick: int = int(_world.get_tick_index())
		_lab_schedule = [[tick+30,int(command.schedule),_lab_floor],[tick+90,int(command.schedule)+1,_lab_floor]]
	if _lab_inputs.size() < 256:
		var recorded: Dictionary = command.duplicate(true)
		recorded.erase("profile")
		recorded.erase("water_policy")
		recorded.erase("water_policy_hash")
		recorded.erase("water_policy_provenance")
		_lab_inputs.append({"tick":int(_world.get_tick_index()),"command":recorded,"profile_hash":_lab_profile_hash})
	return command.has("reset") or command.has("water_reset")

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


func start_worker(spawn_position: Vector2) -> Error:
	if _thread.is_started():
		return OK
	if _world.has_method(&"get_worker_threads"):
		_scheduler_thread_capacity_hint = int(_world.get_worker_threads())
		_backend_name = str(_world.get_backend_name())
	else:
		_scheduler_thread_capacity_hint = 1
		_backend_name = "gdscript-serial-fallback"
	_character.reset(spawn_position)
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
	if _published_snapshot != null and _published_snapshot.lab_context.get("micro_active", false):
		var tools: Array = _published_snapshot.lab_context.get("micro", {}).get("tools", [])
		if not ("erase" if material_id == 0 else "paint") in tools:
			_mutex.unlock()
			return false
	if _pending_emissions.is_empty() or _pending_emissions.back() != emission_command:
		_pending_emissions.append(emission_command)
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


func queue_reset(spawn_position: Vector2) -> void:
	_mutex.lock()
	_reset_requested = true
	_reset_spawn = spawn_position
	_pending_emissions.clear()
	_mutex.unlock()


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
		var local_reset_requested: bool = false
		var local_reset_spawn: Vector2 = Vector2.ZERO
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
		local_reset_requested = _reset_requested
		local_reset_spawn = _reset_spawn
		_reset_requested = false
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
		if _water_lab_active:
			local_emissions.clear()
		elif _micro_active:
			var allowed: Array = _micro_definition.tools
			for i: int in range(local_emissions.size()-1, -1, -1):
				var material: int = local_emissions[i].w & EMISSION_MATERIAL_MASK
				if not ("erase" if material == 0 else "paint") in allowed: local_emissions.remove_at(i)
		if _lab_active:
			if not ((_water_lab_active and bool(_water_recipe.get("body_enabled",false)))
				or (_micro_active and bool(_micro_definition.get("body_enabled", false)))):
				local_rigid_body_states = PackedFloat32Array()
			if local_lab.get("step",false): local_paused = false
			if not local_paused:
				if ((_water_lab_active and not _apply_due_water_actions())
					or (_micro_active and not _micro_host.apply_due(_world))):
					local_paused=true
					_mutex.lock()
					_paused=true
					_mutex.unlock()
				for release: Array in _lab_schedule.duplicate():
					if int(release[2]) == _lab_floor and int(_world.get_tick_index())+1 >= int(release[0]):
						_lab_release(int(release[1]))
						_lab_schedule.erase(release)
		_world.simulation_window_enabled = local_window_enabled
		_world.cadence_lod_enabled = local_cadence_enabled
		_world.set_liquid_surface_adhesion_enabled(local_liquid_adhesion_enabled)
		if _micro_active:
			# Generic fixtures use a fixed full-world domain on all three modes.
			# Legacy Tower/Water owners retain their registered interest behavior.
			_world.simulation_window_enabled = false
			_world.cadence_lod_enabled = false
			_world.set_liquid_surface_adhesion_enabled(true)
		_world.set_interest_center(local_interest_center)
		_world.set_simulation_window(
			local_view_origin,
			local_view_size,
			local_horizontal_buffer,
			local_vertical_buffer
		)

		_micro_owner_config = {"owner": "desktop-owner-thread-character-before-cells",
			"interest_center": [local_interest_center.x, local_interest_center.y],
			"view_origin": [local_view_origin.x, local_view_origin.y],
			"view_size": [local_view_size.x, local_view_size.y],
			"margins": [local_horizontal_buffer, local_vertical_buffer],
			"domain": "whole-world" if _micro_active else "legacy-owner-view-and-interest",
			"body_state_values": local_rigid_body_states.size()}

		if local_reset_requested:
			var recovered: bool = true
			if _world.has_method(&"has_failed"):
				recovered = bool(_world.reset_demo_world())
			else:
				_world.reset_demo_world()
			if recovered:
				_micro_active = false
				_lab_active = false
				_water_lab_active = false
				_micro_host = CyberMicroScenarioHost.new()
				_micro_capture.clear()
				_simulation_failed = false
				_character.reset(local_reset_spawn)
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

			if not local_paused:
				if not _micro_active or _micro_definition.player_start != null:
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

		var worker_step_time_ms: float = float(Time.get_ticks_usec() - step_start_usec) / 1000.0
		_publish_snapshot(
			worker_step_time_ms,
			local_paused,
			local_render_snapshot_interval_usec,
			local_reset_requested
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
	force_render_full_refresh: bool = false
) -> void:
	if _simulation_failed:
		_publish_failure_snapshot()
		return
	var copy_start_usec: int = Time.get_ticks_usec()
	var now_usec: int = Time.get_ticks_usec()
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
	snapshot.hard_surface_revision = _snapshot_hard_surface_revision
	snapshot.cells = _snapshot_cells
	snapshot.render_snapshot_serial = _pending_render_snapshot_serial
	snapshot.render_channels = _pending_render_channels
	snapshot.render_full_refresh = _pending_render_full_refresh
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
		"micro_active": _micro_active,
		"micro": _micro_host.summary(),
		"micro_result": _micro_result.duplicate(true),
		"micro_capture": _micro_capture.duplicate(true),
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
	if previous != null and previous.simulation_failed 		and previous.lab_context.get("micro_capture", {}).get("request_id", 0) == _micro_capture.get("request_id", 0) 		and previous.lab_context.get("micro_result", {}).get("request_id", 0) == _micro_result.get("request_id", 0):
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
	# Publish new diagnostic acknowledgements only; retain all physical payloads
	# from the last completed snapshot, including when already quarantined.
	snapshot.lab_context = snapshot.lab_context.duplicate(true)
	snapshot.lab_context["micro_capture"] = _micro_capture.duplicate(true)
	snapshot.lab_context["micro_result"] = _micro_result.duplicate(true)
	snapshot.lab_context["micro"] = _micro_host.summary()
	snapshot.lab_context["paused"] = true
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
