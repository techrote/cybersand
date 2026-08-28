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
var _acknowledged_render_snapshot_serial: int = 0
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
) -> void:
	# Material and emission flags share the fourth integer so the command stays a
	# compact value type. UI/tool slots never enter this simulation-facing command.
	var packed_flags: int = emission_flags << EMISSION_FLAGS_SHIFT
	var packed_material: int = (material_id & EMISSION_MATERIAL_MASK) | packed_flags
	var emission_command: Vector4i = Vector4i(world_x, world_y, radius, packed_material)
	_mutex.lock()
	if _pending_emissions.is_empty() or _pending_emissions.back() != emission_command:
		_pending_emissions.append(emission_command)
	_mutex.unlock()


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
	elif result != null:
		_acknowledged_render_snapshot_serial = maxi(
			_acknowledged_render_snapshot_serial,
			result.render_snapshot_serial
		)
	_mutex.unlock()
	return result


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
		_mutex.unlock()

		if not local_running:
			return

		var step_start_usec: int = Time.get_ticks_usec()
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

		if local_reset_requested:
			_world.reset_demo_world()
			_character.reset(local_reset_spawn)
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
			_character.simulate(
				FIXED_TIMESTEP,
				local_horizontal_input,
				local_jetpack_active,
				_world
			)
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
	var copy_start_usec: int = Time.get_ticks_usec()
	var now_usec: int = Time.get_ticks_usec()
	var acknowledged_render_serial: int = 0
	_mutex.lock()
	acknowledged_render_serial = _acknowledged_render_snapshot_serial
	_mutex.unlock()
	if (
		_pending_render_snapshot_serial > 0
		and acknowledged_render_serial >= _pending_render_snapshot_serial
	):
		_clear_pending_render_patches()
	if (
		(force_render_full_refresh or _world.revision != _snapshot_world_revision)
		and now_usec - _last_render_snapshot_usec >= render_snapshot_interval_usec
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
				_snapshot_cells = _pending_render_patch_cells
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
	snapshot.render_patch_rectangles = _pending_render_patch_rectangles
	snapshot.render_patch_cells = _pending_render_patch_cells
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

	_mutex.lock()
	_published_snapshot = snapshot
	_mutex.unlock()


func _clear_pending_render_patches() -> void:
	_pending_render_full_refresh = false
	_pending_render_patch_rectangles = PackedInt32Array()
	_pending_render_patch_cells = PackedByteArray()


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

	_pending_render_snapshot_serial = packet_serial
	_pending_render_channels = packet_channels
