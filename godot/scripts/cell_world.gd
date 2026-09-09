class_name CyberCellWorld
extends RefCounted

# The runnable reference keeps a finite backing array for now. All public
# positions are world-cell coordinates so this storage can later be replaced by
# the native sparse chunk world without changing the camera or entity APIs.
const WORLD_WIDTH: int = 1024
const WORLD_HEIGHT: int = 1024

const EMPTY: int = 0
const WALL: int = 1
const SAND: int = 2
const WATER: int = 3
const SMOKE: int = 4
const CLONER: int = 5
const FIRE: int = 6
const WOOD: int = 7
const LAVA: int = 8
const ICE: int = 9
const PLANT: int = 11
const ACID: int = 12
const STONE: int = 13
const DUST: int = 14
const MITE: int = 15
const OIL: int = 16
const ROCKET: int = 17
const FUNGUS: int = 18
const SEED: int = 19
# Prototype-only IDs 20 and 21 avoid colliding with the attributed Sandspiel
# catalogue at IDs 5 and 6. Input slots are presentation-layer mappings and
# never participate in material identity; the native catalogue remains unchanged.
const PASTE: int = 20
const SLUSH: int = 21
const STEAM: int = 22
const SALT: int = 23
const BRINE: int = 24
const SODIUM: int = 25
const GUNPOWDER: int = 26
const COAL: int = 27
const METAL: int = 28
const RUST: int = 29
const CEMENT: int = 30
const CONCRETE: int = 31
const TOXIC_SLUDGE: int = 32
const MERCURY: int = 33
const SPARK: int = 34
const GLASS: int = 35
const MOLTEN_GLASS: int = 36
const FOAM: int = 37
const LIMESTONE_BLOCK: int = 38
const SANDSTONE_BLOCK: int = 39
const GRANITE_BLOCK: int = 40
const COBBLESTONE: int = 41
const MOSSY_COBBLESTONE: int = 42
const RED_BRICK: int = 43
const LIME_PLASTER: int = 44
const WATTLE_AND_DAUB: int = 45
const OAK_TIMBER: int = 46
const THATCH: int = 47
const TERRACOTTA_TILE: int = 48
const SLATE: int = 49
const WROUGHT_IRON: int = 50
const LEAD_SHEET: int = 51
const BRONZE: int = 52
const COPPER: int = 53
const VERDIGRIS_COPPER: int = 54
const STAINED_GLASS: int = 55
const PACKED_EARTH: int = 56
const INDUSTRIAL_BRICK: int = 57
const REINFORCED_CONCRETE: int = 58
const ASPHALT: int = 59
const WET_ASPHALT: int = 60
const WET_COBBLESTONE: int = 61
const STEEL_PLATE: int = 62
const PAINTED_STEEL: int = 63
const CORRUGATED_STEEL: int = 64
const RUSTED_STEEL: int = 65
const STEEL_GRATING: int = 66
const CHAINLINK: int = 67
const STEEL_PIPE: int = 68
const COPPER_PIPE: int = 69
const CERAMIC_TILE: int = 70
const CHEMICAL_GLASS: int = 71
const DARK_GLASS: int = 72
const RUBBER: int = 73
const CABLE_BUNDLE: int = 74
const INSULATION: int = 75
const HAZARD_STRIPE: int = 76
const NEON_CYAN: int = 77
const NEON_MAGENTA: int = 78
const NEON_AMBER: int = 79
const LED_WHITE: int = 80

const EMISSION_FLAG_NONE: int = 0
const EMISSION_FLAG_COHERENT_LIQUID: int = 1

const ACTIVITY_BLOCK_SIZE: int = 16
const ACTIVITY_BLOCK_SHIFT: int = 4
const BLOCK_COLUMNS: int = (WORLD_WIDTH + ACTIVITY_BLOCK_SIZE - 1) >> ACTIVITY_BLOCK_SHIFT
const BLOCK_ROWS: int = (WORLD_HEIGHT + ACTIVITY_BLOCK_SIZE - 1) >> ACTIVITY_BLOCK_SHIFT
const BLOCK_COUNT: int = BLOCK_COLUMNS * BLOCK_ROWS
const CELL_SLEEP_TICKS: int = 8
const CELL_WAKE_RADIUS: int = 1
# Four 16×16 activity blocks form one 64×64 scheduling core. Cores of the
# same parity are separated by another core, leaving a 32-cell exclusive halo
# around every job. That is wider than every ordinary material write below and
# permits Noita-style phased in-place updates without locks or atomics.
const SCHEDULER_CORE_BLOCKS: int = 4
const SCHEDULER_CORE_SIZE: int = ACTIVITY_BLOCK_SIZE * SCHEDULER_CORE_BLOCKS
const SCHEDULER_CORE_SHIFT: int = 6
const SCHEDULER_CORE_COLUMNS: int = (WORLD_WIDTH + SCHEDULER_CORE_SIZE - 1) >> SCHEDULER_CORE_SHIFT
const SCHEDULER_CORE_ROWS: int = (WORLD_HEIGHT + SCHEDULER_CORE_SIZE - 1) >> SCHEDULER_CORE_SHIFT
const SCHEDULER_CORE_COUNT: int = SCHEDULER_CORE_COLUMNS * SCHEDULER_CORE_ROWS
const SCHEDULER_PHASE_COUNT: int = 4
const MIN_PARALLEL_CORES_PER_PHASE: int = 2
# Sparse, non-contiguous free-flight cells may advance two cells every other
# tick. Average falling speed remains one cell per simulation tick, while the
# expensive movement bookkeeping is halved for particle showers. Dense runs,
# surfaces, body contacts, and all density exchanges retain full-rate rules.
const SPARSE_FLIGHT_ACTIVE_BLOCK_THRESHOLD: int = 12
const SPARSE_FLIGHT_DISTANCE: int = 2
# Free Water keeps its lateral momentum until it reaches an obstruction. The
# old value of six now drives Slush; Paste uses a shorter finite budget.
const FREE_LIQUID_LATERAL_FLOW: int = 255
const YIELDING_LIQUID_LATERAL_BUDGET: int = 6
const YIELDING_LIQUID_PRESSURE_YIELD: int = 1
const PASTE_LIQUID_LATERAL_BUDGET: int = 3
const PASTE_LIQUID_PRESSURE_YIELD: int = 3
const LIQUID_PRESSURE_SAMPLE_DEPTH: int = 32
# Normalized gameplay viscosity: 0 is the fastest supported liquid and 255
# limits horizontal dispersion to one cell per update. This is deliberately
# separate from pressure yield: viscosity changes how quickly a liquid reaches
# equilibrium, while yield controls how much of a mound it may retain there.
const WATER_VISCOSITY: int = 0
const SLUSH_VISCOSITY: int = 192
const PASTE_VISCOSITY: int = 240
const WATER_SURFACE_ADHESION: bool = true
const SLUSH_SURFACE_ADHESION: bool = true
const PASTE_SURFACE_ADHESION: bool = true
const MAX_LIQUID_LATERAL_FLOW_RATE: int = 24
const COHERENT_LIQUID_LATERAL_FLOW_RATE: int = 1
const LIQUID_LEVEL_SEARCH_DISTANCE: int = 256

const MAX_BODY_PIXEL_EJECTION_DISTANCE: int = 8
const MAX_BODY_SWEEP_DISTANCE: float = 32.0
const MAX_BODY_SWEEP_STEPS: int = 24
const BODY_SWEEP_SAMPLE_SPACING: float = 1.0
const BODY_PIXEL_CONTACT_IMPULSE: float = 0.025
const BODY_DISPLACEMENT_REACTION_IMPULSE: float = 0.18
# One cell of Water beneath one body pixel contributes approximately one eighth
# of the per-tick impulse needed to support a one-kilogram test body. Side
# pressures cancel naturally; Sand is denser and Smoke is almost weightless.
const BODY_BOUNDARY_PRESSURE_IMPULSE: float = 0.19
# Matches the proof's 92 px/s² gravity at 60 Hz. It is distributed across the
# contacted rectangle face and exists only to make cellular Wall a usable
# prototype support plane without creating per-cell PhysicsServer colliders.
const BODY_GRAVITY_SUPPORT_IMPULSE_PER_MASS: float = 92.0 / 60.0
const MAX_BODY_IMPULSE_PER_TICK: float = 3.0
const BODY_STATIC_CORRECTION_PADDING: float = 0.55
const BODY_CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

const DENSITY_MOTION_NONE: int = 0
const DENSITY_MOTION_DOWN: int = 1
const DENSITY_MOTION_UP: int = 2
const FLOW_DIRECTION_NONE: int = 0
const FLOW_DIRECTION_LEFT: int = 1
const FLOW_DIRECTION_RIGHT: int = 2
const FLOW_DIRECTION_MASK: int = 3
const FLOW_FLAG_COHERENT_EMISSION: int = 4
const FLOW_STATE_FLAGS_MASK: int = 252

var cells: PackedByteArray = PackedByteArray()
var updated_at: PackedByteArray = PackedByteArray()
var quiet_ticks: PackedByteArray = PackedByteArray()
var flow_budget: PackedByteArray = PackedByteArray()
var flow_direction: PackedByteArray = PackedByteArray()
var active_blocks: PackedByteArray = PackedByteArray()
var next_active_blocks: PackedByteArray = PackedByteArray()
var block_movable_counts: PackedInt32Array = PackedInt32Array()
var phase_core_slots: PackedInt32Array = PackedInt32Array()
var job_moves: PackedInt32Array = PackedInt32Array()
var job_scanned: PackedInt32Array = PackedInt32Array()
var job_dormant: PackedInt32Array = PackedInt32Array()
var job_active_blocks: PackedInt32Array = PackedInt32Array()
var job_sparse_flight_moves: PackedInt32Array = PackedInt32Array()
var rigid_body_occupancy: PackedByteArray = PackedByteArray()
var rigid_body_occupied_indices: PackedInt32Array = PackedInt32Array()
var rigid_body_states: PackedFloat32Array = PackedFloat32Array()
var rigid_body_state_offsets: PackedInt32Array = PackedInt32Array()
var rigid_body_impulse_x: PackedFloat32Array = PackedFloat32Array()
var rigid_body_impulse_y: PackedFloat32Array = PackedFloat32Array()
var rigid_body_correction_x: PackedFloat32Array = PackedFloat32Array()
var rigid_body_correction_y: PackedFloat32Array = PackedFloat32Array()
var rigid_body_contact_counts: PackedInt32Array = PackedInt32Array()
var rigid_body_displaced_counts: PackedInt32Array = PackedInt32Array()
var rigid_body_unresolved_counts: PackedInt32Array = PackedInt32Array()

var tick_index: int = 0
var update_epoch: int = 1
var revision: int = 0
var hard_surface_revision: int = 0
var interest_cell: Vector2i = Vector2i(WORLD_WIDTH >> 1, WORLD_HEIGHT >> 1)
var cadence_lod_enabled: bool = true
# The script VM showed real multicore occupancy but only a 1.01x wall-time gain.
# Keep this compact serial fallback; production scheduling lives in native code.
var threaded_scheduler_enabled: bool = false
var simulation_window_enabled: bool = true
var liquid_surface_adhesion_enabled: bool = true
var simulation_bounds: Rect2i = Rect2i(0, 0, WORLD_WIDTH, WORLD_HEIGHT)

var moves_last_tick: int = 0
var scanned_last_tick: int = 0
var dormant_cells_skipped_last_tick: int = 0
var active_blocks_last_tick: int = 0
var eligible_blocks_last_tick: int = 0
var adaptive_block_stride_last_tick: int = 1
var deferred_blocks_last_tick: int = 0
var frozen_blocks_last_tick: int = 0
var scheduler_jobs_last_tick: int = 0
var scheduler_parallel_phases_last_tick: int = 0
var sparse_flight_moves_last_tick: int = 0
var rigid_body_contacts_last_tick: int = 0
var rigid_body_displaced_last_tick: int = 0
var rigid_body_unresolved_last_tick: int = 0
var simulation_time_ms: float = 0.0


func _init() -> void:
	var cell_count: int = WORLD_WIDTH * WORLD_HEIGHT
	cells.resize(cell_count)
	updated_at.resize(cell_count)
	quiet_ticks.resize(cell_count)
	flow_budget.resize(cell_count)
	flow_direction.resize(cell_count)
	active_blocks.resize(BLOCK_COUNT)
	next_active_blocks.resize(BLOCK_COUNT)
	block_movable_counts.resize(BLOCK_COUNT)
	job_moves.resize(SCHEDULER_CORE_COUNT)
	job_scanned.resize(SCHEDULER_CORE_COUNT)
	job_dormant.resize(SCHEDULER_CORE_COUNT)
	job_active_blocks.resize(SCHEDULER_CORE_COUNT)
	job_sparse_flight_moves.resize(SCHEDULER_CORE_COUNT)
	rigid_body_occupancy.resize(cell_count)
	var body_slot_count: int = CyberRigidBodyCoupling.MAX_BODIES + 1
	rigid_body_state_offsets.resize(body_slot_count)
	rigid_body_impulse_x.resize(body_slot_count)
	rigid_body_impulse_y.resize(body_slot_count)
	rigid_body_correction_x.resize(body_slot_count)
	rigid_body_correction_y.resize(body_slot_count)
	rigid_body_contact_counts.resize(body_slot_count)
	rigid_body_displaced_counts.resize(body_slot_count)
	rigid_body_unresolved_counts.resize(body_slot_count)
	reset_demo_world()


func reset_demo_world() -> void:
	cells.fill(EMPTY)
	updated_at.fill(0)
	quiet_ticks.fill(0)
	flow_budget.fill(0)
	flow_direction.fill(FLOW_DIRECTION_NONE)
	active_blocks.fill(0)
	next_active_blocks.fill(0)
	block_movable_counts.fill(0)
	rigid_body_occupancy.fill(0)
	rigid_body_occupied_indices.clear()
	rigid_body_states.clear()
	rigid_body_state_offsets.fill(-1)
	_reset_rigid_body_observations()
	tick_index = 0
	update_epoch = 1
	moves_last_tick = 0
	scanned_last_tick = 0
	dormant_cells_skipped_last_tick = 0
	active_blocks_last_tick = 0
	eligible_blocks_last_tick = 0
	adaptive_block_stride_last_tick = 1
	deferred_blocks_last_tick = 0
	frozen_blocks_last_tick = 0
	scheduler_jobs_last_tick = 0
	scheduler_parallel_phases_last_tick = 0
	sparse_flight_moves_last_tick = 0
	simulation_time_ms = 0.0

	# Permanent world boundary.
	for x: int in range(WORLD_WIDTH):
		_write_direct(x, WORLD_HEIGHT - 1, WALL)
	for y: int in range(WORLD_HEIGHT):
		_write_direct(0, y, WALL)
		_write_direct(WORLD_WIDTH - 1, y, WALL)

	# A broad lower cavern floor.
	for x: int in range(1, WORLD_WIDTH - 1):
		var floor_y: int = WORLD_HEIGHT - 79 + int(18.0 * sin(float(x) * 0.018))
		floor_y += int(7.0 * sin(float(x) * 0.071))
		for y: int in range(floor_y, WORLD_HEIGHT - 1):
			_write_direct(x, y, WALL)

	# Initial playable ledge and reservoirs.
	for x: int in range(18, 338):
		_write_direct(x, 172, WALL)
	for y: int in range(24, 112):
		for x: int in range(55, 108):
			if ((x * 17 + y * 31) % 7) < 4:
				_write_direct(x, y, SAND)
	for y: int in range(128, 172):
		for x: int in range(216, 300):
			if ((x + y) % 3) != 0:
				_write_direct(x, y, WATER)

	# Additional ledges make camera traversal visible without prescribing a
	# future procedural-generation format.
	for platform: int in range(5):
		var start_x: int = 360 + platform * 112
		var platform_y: int = 128 + ((platform * 67) % 260)
		var end_x: int = mini(WORLD_WIDTH - 18, start_x + 92)
		for x: int in range(start_x, end_x):
			_write_direct(x, platform_y, WALL)

	for y: int in range(380, 438):
		for x: int in range(430, 492):
			if ((x * 13 + y * 19) % 9) < 5:
				_write_direct(x, y, SMOKE)

	_rebuild_block_metadata()
	hard_surface_revision += 1
	revision += 1


func prepare_rigid_body_coupling(
	states: PackedFloat32Array,
	resolve_overlaps: bool = true
) -> void:
	# Wake the cells beneath the previous mask before replacing it. This lets
	# material flow into space vacated by a moving body without retaining entity
	# pixels in the authoritative material array.
	for previous_index: int in rigid_body_occupied_indices:
		quiet_ticks[previous_index] = 0
		var previous_x: int = previous_index % WORLD_WIDTH
		var previous_y: int = floori(float(previous_index) / float(WORLD_WIDTH))
		active_blocks[block_index(
			previous_x >> ACTIVITY_BLOCK_SHIFT,
			previous_y >> ACTIVITY_BLOCK_SHIFT
		)] = 1

	var previous_states: PackedFloat32Array = rigid_body_states
	var previous_state_offsets: PackedInt32Array = rigid_body_state_offsets.duplicate()
	rigid_body_occupancy.fill(0)
	rigid_body_occupied_indices.clear()
	rigid_body_states = states.duplicate()
	rigid_body_state_offsets.fill(-1)
	_reset_rigid_body_observations()

	var body_count: int = CyberRigidBodyCoupling.input_body_count(rigid_body_states)
	for body_index: int in range(body_count):
		var state_offset: int = body_index * CyberRigidBodyCoupling.INPUT_STRIDE
		var body_id: int = roundi(
			rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_BODY_ID]
		)
		if body_id <= 0 or body_id > CyberRigidBodyCoupling.MAX_BODIES:
			continue
		if rigid_body_state_offsets[body_id] >= 0:
			continue
		rigid_body_state_offsets[body_id] = state_offset
		var previous_state_offset: int = previous_state_offsets[body_id]
		if previous_state_offset >= 0:
			_rasterize_rigid_body_sweep(
				body_id,
				state_offset,
				previous_states,
				previous_state_offset
			)
		else:
			_rasterize_rigid_body(body_id, state_offset)

	if resolve_overlaps:
		# Reconcile the conservative swept mask first. This is what makes a
		# fast-moving body push material along its path instead of teleporting
		# through cells between two asynchronously sampled transforms.
		for occupied_index: int in rigid_body_occupied_indices:
			if cells[occupied_index] == EMPTY:
				continue
			_reconcile_rigid_body_overlap(
				occupied_index,
				previous_states,
				previous_state_offsets
			)

	# The cellular step sees only the body's newest authoritative transform.
	# The swept union above exists for displacement/reaction, while retaining it
	# here would exaggerate pressure and leave a body-length phantom obstacle.
	rigid_body_occupancy.fill(0)
	rigid_body_occupied_indices.clear()
	for body_index: int in range(body_count):
		var state_offset: int = body_index * CyberRigidBodyCoupling.INPUT_STRIDE
		var body_id: int = roundi(
			rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_BODY_ID]
		)
		if body_id <= 0 or body_id > CyberRigidBodyCoupling.MAX_BODIES:
			continue
		if rigid_body_state_offsets[body_id] != state_offset:
			continue
		_rasterize_rigid_body(body_id, state_offset)

	if resolve_overlaps:
		_accumulate_rigid_body_boundary_pressure()

	if rigid_body_displaced_last_tick > 0:
		revision += 1


func rigid_body_results() -> PackedFloat32Array:
	var results: PackedFloat32Array = PackedFloat32Array()
	var body_count: int = CyberRigidBodyCoupling.input_body_count(rigid_body_states)
	for body_index: int in range(body_count):
		var state_offset: int = body_index * CyberRigidBodyCoupling.INPUT_STRIDE
		var body_id: int = roundi(
			rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_BODY_ID]
		)
		if body_id <= 0 or body_id > CyberRigidBodyCoupling.MAX_BODIES:
			continue
		results.append(float(body_id))
		results.append(rigid_body_impulse_x[body_id])
		results.append(rigid_body_impulse_y[body_id])
		results.append(rigid_body_correction_x[body_id])
		results.append(rigid_body_correction_y[body_id])
		results.append(float(rigid_body_contact_counts[body_id]))
		results.append(float(rigid_body_displaced_counts[body_id]))
		results.append(float(rigid_body_unresolved_counts[body_id]))
		results.append(
			rigid_body_states[
				state_offset + CyberRigidBodyCoupling.INPUT_SAMPLE_SERIAL
			]
		)
	return results


func _reset_rigid_body_observations() -> void:
	rigid_body_impulse_x.fill(0.0)
	rigid_body_impulse_y.fill(0.0)
	rigid_body_correction_x.fill(0.0)
	rigid_body_correction_y.fill(0.0)
	rigid_body_contact_counts.fill(0)
	rigid_body_displaced_counts.fill(0)
	rigid_body_unresolved_counts.fill(0)
	rigid_body_contacts_last_tick = 0
	rigid_body_displaced_last_tick = 0
	rigid_body_unresolved_last_tick = 0


func _rasterize_rigid_body(body_id: int, state_offset: int) -> void:
	var center: Vector2 = Vector2(
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_CENTER_X],
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_CENTER_Y]
	)
	var rotation: float = rigid_body_states[
		state_offset + CyberRigidBodyCoupling.INPUT_ROTATION
	]
	var half_size: Vector2 = Vector2(
		maxf(0.5, rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_SIZE_X] * 0.5),
		maxf(0.5, rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_SIZE_Y] * 0.5)
	)
	_rasterize_rigid_body_transform(body_id, center, rotation, half_size)


func _rasterize_rigid_body_sweep(
	body_id: int,
	state_offset: int,
	previous_states: PackedFloat32Array,
	previous_state_offset: int
) -> void:
	var center: Vector2 = Vector2(
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_CENTER_X],
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_CENTER_Y]
	)
	var previous_center: Vector2 = Vector2(
		previous_states[previous_state_offset + CyberRigidBodyCoupling.INPUT_CENTER_X],
		previous_states[previous_state_offset + CyberRigidBodyCoupling.INPUT_CENTER_Y]
	)
	var rotation: float = rigid_body_states[
		state_offset + CyberRigidBodyCoupling.INPUT_ROTATION
	]
	var previous_rotation: float = previous_states[
		previous_state_offset + CyberRigidBodyCoupling.INPUT_ROTATION
	]
	var half_size: Vector2 = Vector2(
		maxf(0.5, rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_SIZE_X] * 0.5),
		maxf(0.5, rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_SIZE_Y] * 0.5)
	)
	var previous_half_size: Vector2 = Vector2(
		maxf(
			0.5,
			previous_states[
				previous_state_offset + CyberRigidBodyCoupling.INPUT_SIZE_X
			] * 0.5
		),
		maxf(
			0.5,
			previous_states[
				previous_state_offset + CyberRigidBodyCoupling.INPUT_SIZE_Y
			] * 0.5
		)
	)
	var travel_distance: float = previous_center.distance_to(center)
	if travel_distance > MAX_BODY_SWEEP_DISTANCE:
		# Treat large jumps as teleports (reset/stream-in), not physical sweeps.
		_rasterize_rigid_body_transform(body_id, center, rotation, half_size)
		return
	var rotation_delta: float = wrapf(rotation - previous_rotation, -PI, PI)
	var rotational_travel: float = absf(rotation_delta) * maxf(
		half_size.length(),
		previous_half_size.length()
	)
	var sweep_extent: float = maxf(travel_distance, rotational_travel)
	if sweep_extent <= BODY_SWEEP_SAMPLE_SPACING:
		_rasterize_rigid_body_transform(body_id, center, rotation, half_size)
		return
	var sweep_steps: int = clampi(
		ceili(sweep_extent / BODY_SWEEP_SAMPLE_SPACING),
		1,
		MAX_BODY_SWEEP_STEPS
	)
	for sweep_step: int in range(sweep_steps + 1):
		var weight: float = float(sweep_step) / float(sweep_steps)
		_rasterize_rigid_body_transform(
			body_id,
			previous_center.lerp(center, weight),
			previous_rotation + rotation_delta * weight,
			previous_half_size.lerp(half_size, weight)
		)


func _rasterize_rigid_body_transform(
	body_id: int,
	center: Vector2,
	rotation: float,
	half_size: Vector2
) -> void:
	var cosine: float = cos(rotation)
	var sine: float = sin(rotation)
	var extent: Vector2 = Vector2(
		absf(cosine) * half_size.x + absf(sine) * half_size.y,
		absf(sine) * half_size.x + absf(cosine) * half_size.y
	)
	var first_x: int = clampi(floori(center.x - extent.x), 0, WORLD_WIDTH - 1)
	var last_x: int = clampi(ceili(center.x + extent.x) - 1, 0, WORLD_WIDTH - 1)
	var first_y: int = clampi(floori(center.y - extent.y), 0, WORLD_HEIGHT - 1)
	var last_y: int = clampi(ceili(center.y + extent.y) - 1, 0, WORLD_HEIGHT - 1)

	for y: int in range(first_y, last_y + 1):
		for x: int in range(first_x, last_x + 1):
			var delta: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) - center
			var local: Vector2 = Vector2(
				cosine * delta.x + sine * delta.y,
				-sine * delta.x + cosine * delta.y
			)
			if absf(local.x) > half_size.x or absf(local.y) > half_size.y:
				continue
			var index: int = cell_index(x, y)
			if rigid_body_occupancy[index] != 0:
				continue
			rigid_body_occupancy[index] = body_id
			rigid_body_occupied_indices.append(index)

	_wake_cell_area(first_x - 1, first_y - 1, last_x + 1, last_y + 1)
	mark_current_area(first_x - 1, first_y - 1, last_x + 1, last_y + 1)


func _reconcile_rigid_body_overlap(
	source_index: int,
	previous_states: PackedFloat32Array,
	previous_state_offsets: PackedInt32Array
) -> void:
	var body_id: int = rigid_body_occupancy[source_index]
	if body_id <= 0 or body_id > CyberRigidBodyCoupling.MAX_BODIES:
		return
	var state_offset: int = rigid_body_state_offsets[body_id]
	if state_offset < 0:
		return
	var source_x: int = source_index % WORLD_WIDTH
	var source_y: int = floori(float(source_index) / float(WORLD_WIDTH))
	var material_id: int = cells[source_index]
	var geometry: Vector3
	if _cell_center_inside_body(state_offset, source_x, source_y):
		geometry = _body_overlap_geometry(state_offset, source_x, source_y)
	else:
		var previous_state_offset: int = previous_state_offsets[body_id]
		var sweep_direction: Vector2 = Vector2.ZERO
		if previous_state_offset >= 0:
			var current_center: Vector2 = Vector2(
				rigid_body_states[
					state_offset + CyberRigidBodyCoupling.INPUT_CENTER_X
				],
				rigid_body_states[
					state_offset + CyberRigidBodyCoupling.INPUT_CENTER_Y
				]
			)
			var previous_center: Vector2 = Vector2(
				previous_states[
					previous_state_offset + CyberRigidBodyCoupling.INPUT_CENTER_X
				],
				previous_states[
					previous_state_offset + CyberRigidBodyCoupling.INPUT_CENTER_Y
				]
			)
			sweep_direction = current_center - previous_center
		if sweep_direction.length_squared() > 0.000001:
			# A cell covered only by the swept path is pushed in the body's travel
			# direction; the equal/opposite impulse is returned to Rapier.
			sweep_direction = sweep_direction.normalized()
			geometry = Vector3(sweep_direction.x, sweep_direction.y, 0.5)
		else:
			geometry = _body_overlap_geometry(state_offset, source_x, source_y)
	var outward_normal: Vector2 = Vector2(geometry.x, geometry.y)
	var penetration: float = geometry.z

	_record_body_contact(body_id)
	if _is_hard_surface_material(material_id):
		# Rapier owns hard-surface contacts through a pixel-derived static collider.
		# Applying a second, delayed raster correction here caused bounce and could
		# push a body through a one-pixel floor. The occupancy mask still exposes the
		# body to cellular material, but hard-surface/body depenetration is solved once.
		return

	if not is_movable(material_id):
		_record_body_unresolved(body_id)
		return

	var target: Vector2i = _find_body_ejection_target(
		source_x,
		source_y,
		outward_normal,
		penetration
	)
	if target.x < 0:
		_record_body_unresolved(body_id)
		_record_body_impulse(
			body_id,
			-outward_normal * BODY_DISPLACEMENT_REACTION_IMPULSE
		)
		return

	_move_material_for_body(source_x, source_y, target.x, target.y)
	rigid_body_displaced_counts[body_id] += 1
	rigid_body_displaced_last_tick += 1
	var density_scale: float = clampf(float(_material_density(material_id)) / 1000.0, 0.05, 1.6)
	_record_body_impulse(
		body_id,
		-outward_normal * BODY_DISPLACEMENT_REACTION_IMPULSE * density_scale
	)


func _cell_center_inside_body(state_offset: int, x: int, y: int) -> bool:
	var center: Vector2 = Vector2(
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_CENTER_X],
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_CENTER_Y]
	)
	var rotation: float = rigid_body_states[
		state_offset + CyberRigidBodyCoupling.INPUT_ROTATION
	]
	var half_size: Vector2 = Vector2(
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_SIZE_X] * 0.5,
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_SIZE_Y] * 0.5
	)
	var cosine: float = cos(rotation)
	var sine: float = sin(rotation)
	var delta: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) - center
	var local: Vector2 = Vector2(
		cosine * delta.x + sine * delta.y,
		-sine * delta.x + cosine * delta.y
	)
	return absf(local.x) <= half_size.x and absf(local.y) <= half_size.y


func _body_overlap_geometry(state_offset: int, x: int, y: int) -> Vector3:
	var center: Vector2 = Vector2(
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_CENTER_X],
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_CENTER_Y]
	)
	var rotation: float = rigid_body_states[
		state_offset + CyberRigidBodyCoupling.INPUT_ROTATION
	]
	var half_size: Vector2 = Vector2(
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_SIZE_X] * 0.5,
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_SIZE_Y] * 0.5
	)
	var cosine: float = cos(rotation)
	var sine: float = sin(rotation)
	var delta: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) - center
	var local: Vector2 = Vector2(
		cosine * delta.x + sine * delta.y,
		-sine * delta.x + cosine * delta.y
	)
	var x_penetration: float = half_size.x - absf(local.x) + 0.5
	var y_penetration: float = half_size.y - absf(local.y) + 0.5
	var local_normal: Vector2
	var penetration: float
	if x_penetration < y_penetration:
		local_normal = Vector2(1.0 if local.x >= 0.0 else -1.0, 0.0)
		penetration = x_penetration
	else:
		local_normal = Vector2(0.0, 1.0 if local.y >= 0.0 else -1.0)
		penetration = y_penetration
	var world_normal: Vector2 = Vector2(
		cosine * local_normal.x - sine * local_normal.y,
		sine * local_normal.x + cosine * local_normal.y
	)
	return Vector3(world_normal.x, world_normal.y, maxf(0.5, penetration))


func _find_body_ejection_target(
	source_x: int,
	source_y: int,
	outward_normal: Vector2,
	penetration: float
) -> Vector2i:
	var tangent: Vector2 = Vector2(-outward_normal.y, outward_normal.x)
	var source_center: Vector2 = Vector2(float(source_x) + 0.5, float(source_y) + 0.5)
	var first_distance: int = maxi(1, ceili(penetration))
	for distance: int in range(
		first_distance,
		first_distance + MAX_BODY_PIXEL_EJECTION_DISTANCE + 1
	):
		for tangent_probe: int in range(9):
			var tangent_offset: int = _symmetric_probe_offset(tangent_probe)
			var candidate_center: Vector2 = (
				source_center
				+ outward_normal * float(distance)
				+ tangent * float(tangent_offset)
			)
			var candidate_x: int = floori(candidate_center.x)
			var candidate_y: int = floori(candidate_center.y)
			if not in_bounds(candidate_x, candidate_y):
				continue
			var candidate_index: int = cell_index(candidate_x, candidate_y)
			if rigid_body_occupancy[candidate_index] != 0:
				continue
			if cells[candidate_index] != EMPTY:
				continue
			return Vector2i(candidate_x, candidate_y)
	return Vector2i(-1, -1)


func _symmetric_probe_offset(probe_index: int) -> int:
	if probe_index == 0:
		return 0
	var magnitude: int = ceili(float(probe_index) * 0.5)
	return magnitude if (probe_index & 1) == 1 else -magnitude


func _move_material_for_body(
	source_x: int,
	source_y: int,
	target_x: int,
	target_y: int
) -> void:
	var source_index: int = cell_index(source_x, source_y)
	var target_index: int = cell_index(target_x, target_y)
	var material_id: int = cells[source_index]
	cells[target_index] = material_id
	cells[source_index] = EMPTY
	flow_budget[target_index] = flow_budget[source_index]
	flow_budget[source_index] = 0
	flow_direction[target_index] = flow_direction[source_index]
	flow_direction[source_index] = FLOW_DIRECTION_NONE
	quiet_ticks[source_index] = 0
	quiet_ticks[target_index] = 0
	updated_at[source_index] = update_epoch
	updated_at[target_index] = update_epoch
	_adjust_movable_count(source_x, source_y, material_id, EMPTY)
	_adjust_movable_count(target_x, target_y, EMPTY, material_id)
	_wake_motion_endpoint(source_x, source_y)
	_wake_motion_endpoint(target_x, target_y)
	mark_current_area(source_x - 1, source_y - 1, source_x + 1, source_y + 1)
	mark_current_area(target_x - 1, target_y - 1, target_x + 1, target_y + 1)


func _record_pixel_body_contact(
	body_id: int,
	material_id: int,
	movement: Vector2
) -> void:
	if movement.length_squared() <= 0.0:
		return
	_record_body_contact(body_id)
	var density_scale: float = clampf(float(_material_density(material_id)) / 1000.0, 0.05, 1.6)
	_record_body_impulse(
		body_id,
		movement.normalized() * BODY_PIXEL_CONTACT_IMPULSE * density_scale
	)


func _accumulate_rigid_body_boundary_pressure() -> void:
	for occupied_index: int in rigid_body_occupied_indices:
		var body_id: int = rigid_body_occupancy[occupied_index]
		if body_id <= 0 or body_id > CyberRigidBodyCoupling.MAX_BODIES:
			continue
		var body_x: int = occupied_index % WORLD_WIDTH
		var body_y: int = floori(float(occupied_index) / float(WORLD_WIDTH))
		for direction: Vector2i in BODY_CARDINAL_DIRECTIONS:
			var material_x: int = body_x + direction.x
			var material_y: int = body_y + direction.y
			if not in_bounds(material_x, material_y):
				continue
			var material_index: int = cell_index(material_x, material_y)
			if rigid_body_occupancy[material_index] != 0:
				continue
			var material_id: int = cells[material_index]
			if material_id == WALL:
				# The matching Rapier static collider supplies friction, restitution,
				# support, and CCD. Do not double-apply a cellular support impulse.
				continue
			if not is_movable(material_id):
				continue
			var density_scale: float = clampf(
				float(_material_density(material_id)) / 1000.0,
				0.01,
				1.6
			)
			_record_body_contact(body_id)
			_record_body_impulse(
				body_id,
				-Vector2(float(direction.x), float(direction.y))
				* BODY_BOUNDARY_PRESSURE_IMPULSE
				* density_scale
			)


func _accumulate_rigid_body_wall_contact(body_id: int, direction: Vector2i) -> void:
	var state_offset: int = rigid_body_state_offsets[body_id]
	if state_offset < 0:
		return
	var direction_vector: Vector2 = Vector2(float(direction.x), float(direction.y))
	var velocity: Vector2 = Vector2(
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_VELOCITY_X],
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_VELOCITY_Y]
	)
	var mass: float = maxf(
		0.001,
		rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_MASS]
	)
	var face_span: float
	if direction.x == 0:
		face_span = maxf(
			1.0,
			rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_SIZE_X]
		)
	else:
		face_span = maxf(
			1.0,
			rigid_body_states[state_offset + CyberRigidBodyCoupling.INPUT_SIZE_Y]
		)
	var impulse_magnitude: float = maxf(0.0, velocity.dot(direction_vector)) * mass
	if direction.y > 0:
		impulse_magnitude += BODY_GRAVITY_SUPPORT_IMPULSE_PER_MASS * mass
	if impulse_magnitude <= 0.0:
		return
	_record_body_contact(body_id)
	_record_body_impulse(
		body_id,
		-direction_vector * (impulse_magnitude / face_span)
	)


func _record_body_contact(body_id: int) -> void:
	if body_id <= 0 or body_id > CyberRigidBodyCoupling.MAX_BODIES:
		return
	rigid_body_contact_counts[body_id] += 1
	rigid_body_contacts_last_tick += 1


func _record_body_unresolved(body_id: int) -> void:
	rigid_body_unresolved_counts[body_id] += 1
	rigid_body_unresolved_last_tick += 1


func _record_body_impulse(body_id: int, impulse: Vector2) -> void:
	if body_id <= 0 or body_id > CyberRigidBodyCoupling.MAX_BODIES:
		return
	var combined: Vector2 = Vector2(
		rigid_body_impulse_x[body_id],
		rigid_body_impulse_y[body_id]
	) + impulse
	if combined.length() > MAX_BODY_IMPULSE_PER_TICK:
		combined = combined.normalized() * MAX_BODY_IMPULSE_PER_TICK
	rigid_body_impulse_x[body_id] = combined.x
	rigid_body_impulse_y[body_id] = combined.y


func _record_body_correction(body_id: int, correction: Vector2) -> void:
	if body_id <= 0 or body_id > CyberRigidBodyCoupling.MAX_BODIES:
		return
	# Preserve the strongest deterministic correction on each axis. A body caught
	# in a terrain corner can therefore escape both planes instead of retaining
	# only whichever single contact had the longest vector.
	if absf(correction.x) > absf(rigid_body_correction_x[body_id]):
		rigid_body_correction_x[body_id] = correction.x
	if absf(correction.y) > absf(rigid_body_correction_y[body_id]):
		rigid_body_correction_y[body_id] = correction.y


func simulation_tick() -> void:
	var start_usec: int = Time.get_ticks_usec()
	tick_index += 1
	update_epoch += 1
	if update_epoch > 255:
		updated_at.fill(0)
		update_epoch = 1

	next_active_blocks.fill(0)
	moves_last_tick = 0
	scanned_last_tick = 0
	dormant_cells_skipped_last_tick = 0
	active_blocks_last_tick = 0
	eligible_blocks_last_tick = _count_eligible_active_blocks()
	# Active cellular material now retains a 60 Hz rule cadence. The former
	# load-derived stride made gravity visibly slow whenever more than twelve
	# blocks woke at once. Sparse free flight is the only optional temporal LOD.
	adaptive_block_stride_last_tick = 1
	deferred_blocks_last_tick = 0
	frozen_blocks_last_tick = 0
	scheduler_jobs_last_tick = 0
	scheduler_parallel_phases_last_tick = 0
	sparse_flight_moves_last_tick = 0

	# A four-phase barrier schedule gives each job exclusive access to its 64×64
	# core plus the 32-cell cardinal halo needed by the longest local material
	# write. Jobs in one phase never touch the same array elements.
	for scheduler_phase: int in range(SCHEDULER_PHASE_COUNT):
		_collect_scheduler_phase(scheduler_phase)
		if phase_core_slots.is_empty():
			continue
		scheduler_jobs_last_tick += phase_core_slots.size()
		var requested_threads: int = mini(
			phase_core_slots.size(),
			maxi(1, OS.get_processor_count() - 2)
		)
		if (
			threaded_scheduler_enabled
			and
			phase_core_slots.size() >= MIN_PARALLEL_CORES_PER_PHASE
			and requested_threads > 1
		):
			var group_id: int = WorkerThreadPool.add_group_task(
				Callable(self, "_simulate_phase_core"),
				phase_core_slots.size(),
				requested_threads,
				true,
				"CyberSand phase %d" % scheduler_phase
			)
			WorkerThreadPool.wait_for_group_task_completion(group_id)
			scheduler_parallel_phases_last_tick += 1
		else:
			for phase_element: int in range(phase_core_slots.size()):
				_simulate_phase_core(phase_element)
		_accumulate_phase_metrics()

	var old_active: PackedByteArray = active_blocks
	active_blocks = next_active_blocks
	next_active_blocks = old_active

	if moves_last_tick > 0:
		revision += 1
	simulation_time_ms = float(Time.get_ticks_usec() - start_usec) / 1000.0


func _collect_scheduler_phase(scheduler_phase: int) -> void:
	phase_core_slots.clear()
	for core_y: int in range(SCHEDULER_CORE_ROWS):
		for core_x: int in range(SCHEDULER_CORE_COLUMNS):
			var core_phase: int = (core_x & 1) | ((core_y & 1) << 1)
			if core_phase != scheduler_phase:
				continue
			var has_runnable_block: bool = false
			var first_block_x: int = core_x * SCHEDULER_CORE_BLOCKS
			var first_block_y: int = core_y * SCHEDULER_CORE_BLOCKS
			var last_block_x: int = mini(
				BLOCK_COLUMNS,
				first_block_x + SCHEDULER_CORE_BLOCKS
			)
			var last_block_y: int = mini(
				BLOCK_ROWS,
				first_block_y + SCHEDULER_CORE_BLOCKS
			)
			for block_y: int in range(first_block_y, last_block_y):
				for block_x: int in range(first_block_x, last_block_x):
					var block_id: int = block_index(block_x, block_y)
					if active_blocks[block_id] == 0 or block_movable_counts[block_id] == 0:
						continue
					if (
						simulation_window_enabled
						and not _block_intersects_simulation_window(block_x, block_y)
					):
						# Frozen work retains its wake flag without consuming a pool task.
						next_active_blocks[block_id] = 1
						frozen_blocks_last_tick += 1
						continue
					has_runnable_block = true
			if has_runnable_block:
				phase_core_slots.append(core_y * SCHEDULER_CORE_COLUMNS + core_x)


func _simulate_phase_core(phase_element: int) -> void:
	var core_slot: int = phase_core_slots[phase_element]
	job_moves[core_slot] = 0
	job_scanned[core_slot] = 0
	job_dormant[core_slot] = 0
	job_active_blocks[core_slot] = 0
	job_sparse_flight_moves[core_slot] = 0

	var core_x: int = core_slot % SCHEDULER_CORE_COLUMNS
	var core_y: int = floori(float(core_slot) / float(SCHEDULER_CORE_COLUMNS))
	var first_block_x: int = core_x * SCHEDULER_CORE_BLOCKS
	var first_block_y: int = core_y * SCHEDULER_CORE_BLOCKS
	var last_block_x: int = mini(BLOCK_COLUMNS, first_block_x + SCHEDULER_CORE_BLOCKS)
	var last_block_y: int = mini(BLOCK_ROWS, first_block_y + SCHEDULER_CORE_BLOCKS)

	for block_y: int in range(last_block_y - 1, first_block_y - 1, -1):
		var left_to_right: bool = ((block_y + tick_index) & 1) == 0
		var block_span: int = last_block_x - first_block_x
		for block_offset: int in range(block_span):
			var block_x: int = (
				first_block_x + block_offset
				if left_to_right
				else last_block_x - 1 - block_offset
			)
			var block_id: int = block_index(block_x, block_y)
			if active_blocks[block_id] == 0 or block_movable_counts[block_id] == 0:
				continue
			job_active_blocks[core_slot] += 1
			_simulate_block(block_x, block_y, core_slot)


func _accumulate_phase_metrics() -> void:
	for core_slot: int in phase_core_slots:
		moves_last_tick += job_moves[core_slot]
		scanned_last_tick += job_scanned[core_slot]
		dormant_cells_skipped_last_tick += job_dormant[core_slot]
		active_blocks_last_tick += job_active_blocks[core_slot]
		sparse_flight_moves_last_tick += job_sparse_flight_moves[core_slot]


func _simulate_block(block_x: int, block_y: int, job_slot: int = -1) -> void:
	var current_block_id: int = block_index(block_x, block_y)
	var first_x: int = block_x << ACTIVITY_BLOCK_SHIFT
	var first_y: int = block_y << ACTIVITY_BLOCK_SHIFT
	var last_x: int = mini(WORLD_WIDTH, first_x + ACTIVITY_BLOCK_SIZE)
	var last_y: int = mini(WORLD_HEIGHT, first_y + ACTIVITY_BLOCK_SIZE)

	for y: int in range(last_y - 1, first_y - 1, -1):
		var left_to_right: bool = ((y + tick_index) & 1) == 0
		var span: int = last_x - first_x
		for offset: int in range(span):
			var x: int = first_x + offset if left_to_right else last_x - 1 - offset
			var index: int = cell_index(x, y)
			if updated_at[index] == update_epoch:
				continue
			var cell_material: int = cells[index]
			if not is_movable(cell_material):
				continue
			if quiet_ticks[index] >= CELL_SLEEP_TICKS:
				if job_slot >= 0:
					job_dormant[job_slot] += 1
				else:
					dormant_cells_skipped_last_tick += 1
				continue

			if job_slot >= 0:
				job_scanned[job_slot] += 1
			else:
				scanned_last_tick += 1
			var direction: int = -1 if ((x + y + tick_index) & 1) == 0 else 1
			var moved: bool = false
			if cell_material == SMOKE and _smoke_should_dissipate(x, y):
				cells[index] = EMPTY
				flow_budget[index] = 0
				flow_direction[index] = FLOW_DIRECTION_NONE
				updated_at[index] = update_epoch
				quiet_ticks[index] = 0
				_adjust_movable_count(x, y, SMOKE, EMPTY)
				_wake_motion_endpoint(x, y)
				if job_slot >= 0:
					job_moves[job_slot] += 1
				else:
					moves_last_tick += 1
				mark_next_area(x - 1, y - 1, x + 1, y + 1)
				continue
			if (
				cadence_lod_enabled
				and eligible_blocks_last_tick > SPARSE_FLIGHT_ACTIVE_BLOCK_THRESHOLD
				and _is_sparse_free_flight_cell(x, y, cell_material)
			):
				if ((x + y + tick_index) & 1) != 0:
					# Keep the sampled cell awake; it advances two cells on its next turn.
					quiet_ticks[index] = 0
					next_active_blocks[current_block_id] = 1
					continue
				moved = _try_sparse_ballistic_move(x, y, cell_material, job_slot)
				if moved:
					if job_slot >= 0:
						job_sparse_flight_moves[job_slot] += 1
					else:
						sparse_flight_moves_last_tick += 1
					continue

			if cell_material == SAND:
				moved = try_move(x, y, x, y + 1, true, job_slot)
				if not moved:
					moved = try_move(x, y, x + direction, y + 1, true, job_slot)
				if not moved:
					moved = try_move(x, y, x - direction, y + 1, true, job_slot)
			elif _is_cellular_liquid(cell_material):
				var allow_diagonal_flow: bool = (
					not _is_coherent_liquid_state(index)
					or _coherent_liquid_can_use_diagonal(x, y, cell_material)
				)
				moved = try_move(x, y, x, y + 1, true, job_slot)
				if moved:
					_configure_liquid_after_gravity_move(
						cell_index(x, y + 1),
						cell_material,
						0
					)
				if not moved and allow_diagonal_flow:
					moved = try_move(x, y, x + direction, y + 1, true, job_slot)
					if moved:
						_configure_liquid_after_gravity_move(
							cell_index(x + direction, y + 1),
							cell_material,
							direction
						)
				if not moved and allow_diagonal_flow:
					moved = try_move(x, y, x - direction, y + 1, true, job_slot)
					if moved:
						_configure_liquid_after_gravity_move(
							cell_index(x - direction, y + 1),
							cell_material,
							-direction
						)
				if not moved:
					var preferred_flow: int = _decode_flow_direction(flow_direction[index])
					if preferred_flow == 0:
						moved = _try_liquid_lateral(x, y, direction, false, job_slot)
						if not moved:
							moved = _try_liquid_lateral(x, y, -direction, false, job_slot)
					else:
						moved = _try_liquid_lateral(x, y, preferred_flow, false, job_slot)
						if not moved:
							# Do not rebound into the cell just vacated. Reversal is
							# allowed only when a genuine pressure gradient demands it.
							moved = _try_liquid_lateral(x, y, -preferred_flow, true, job_slot)
				if not moved:
					var retained_flags: int = _flow_state_flags(flow_direction[index])
					flow_budget[index] = 0
					flow_direction[index] = retained_flags
			elif cell_material == SMOKE:
				moved = try_move(x, y, x, y - 1, true, job_slot)
				if not moved:
					moved = try_move(x, y, x + direction, y - 1, true, job_slot)
				if not moved:
					moved = try_move(x, y, x - direction, y - 1, true, job_slot)
				if not moved:
					moved = try_move(x, y, x + direction, y, false, job_slot)
				if not moved:
					moved = try_move(x, y, x - direction, y, false, job_slot)

			if not moved:
				var age: int = mini(CELL_SLEEP_TICKS, int(quiet_ticks[index]) + 1)
				quiet_ticks[index] = age
				if age < CELL_SLEEP_TICKS:
					next_active_blocks[current_block_id] = 1


func try_move(
	x: int,
	y: int,
	target_x: int,
	target_y: int,
	allow_swap: bool,
	job_slot: int = -1
) -> bool:
	if not in_bounds(target_x, target_y):
		return false
	var source_index: int = cell_index(x, y)
	var target_index: int = cell_index(target_x, target_y)
	var source_material: int = cells[source_index]
	var target_material: int = cells[target_index]
	var source_flow_budget: int = flow_budget[source_index]
	var target_flow_budget: int = flow_budget[target_index]
	var source_flow_direction: int = flow_direction[source_index]
	var target_flow_direction: int = flow_direction[target_index]
	var occupying_body_id: int = rigid_body_occupancy[target_index]
	if occupying_body_id != 0:
		_record_pixel_body_contact(
			occupying_body_id,
			source_material,
			Vector2(target_x - x, target_y - y)
		)
		return false
	# A destination already written this tick must not be reused. Without this
	# guard, a lateral liquid move can cascade through vacated cells and produce
	# a checkerboard surface that reverses on the following tick.
	if updated_at[target_index] == update_epoch:
		return false
	var can_swap: bool = allow_swap and _can_density_exchange(
		source_material,
		target_material,
		target_y - y
	)
	if target_material != EMPTY and not can_swap:
		return false

	var replacement: int = target_material if can_swap else EMPTY
	cells[target_index] = source_material
	cells[source_index] = replacement
	flow_budget[target_index] = source_flow_budget
	flow_budget[source_index] = target_flow_budget if can_swap else 0
	flow_direction[target_index] = source_flow_direction
	flow_direction[source_index] = target_flow_direction if can_swap else FLOW_DIRECTION_NONE
	# A vertically vacated Empty cell may be filled by the cell above later in
	# this bottom-up pass. Marking both ends used to manufacture alternating empty
	# rows. Lateral vacancies and density-swap replacements remain stamped to
	# prevent same-row cascades and double-updating a displaced material.
	if can_swap or target_y == y:
		updated_at[source_index] = update_epoch
	updated_at[target_index] = update_epoch
	_wake_motion_endpoint(x, y)
	_wake_motion_endpoint(target_x, target_y)
	_adjust_movable_count(x, y, source_material, replacement)
	_adjust_movable_count(target_x, target_y, target_material, source_material)
	if job_slot >= 0:
		job_moves[job_slot] += 1
	else:
		moves_last_tick += 1
	mark_next_area(x - 1, y - 1, x + 1, y + 1)
	mark_next_area(target_x - 1, target_y - 1, target_x + 1, target_y + 1)
	return true


func _configure_liquid_after_gravity_move(
	index: int,
	material_id: int,
	direction: int
) -> void:
	var state_flags: int = _flow_state_flags(flow_direction[index])
	if (state_flags & FLOW_FLAG_COHERENT_EMISSION) != 0:
		# Coherent emission is a source-selected flow state, not a viscosity
		# adjustment. Falling and density exchange retain it and do not inject
		# ordinary sideways momentum into the moved cell.
		flow_budget[index] = 0
		flow_direction[index] = state_flags
		return
	flow_budget[index] = _initial_lateral_flow(material_id)
	flow_direction[index] = (
		FLOW_DIRECTION_NONE if direction == 0 else _encode_flow_direction(direction)
	)


func set_cell(
	x: int,
	y: int,
	material_id: int,
	emission_flags: int = EMISSION_FLAG_NONE
) -> void:
	if _set_cell_internal(x, y, material_id, emission_flags):
		revision += 1


func emit_disc(
	cx: int,
	cy: int,
	radius: int,
	material_id: int,
	emission_flags: int = EMISSION_FLAG_NONE
) -> void:
	var radius_squared: int = radius * radius
	var changed: bool = false
	for offset_y: int in range(-radius, radius + 1):
		for offset_x: int in range(-radius, radius + 1):
			if offset_x * offset_x + offset_y * offset_y <= radius_squared:
				if _set_cell_internal(
					cx + offset_x,
					cy + offset_y,
					material_id,
					emission_flags
				):
					changed = true
	if changed:
		revision += 1


func paint_disc(
	cx: int,
	cy: int,
	radius: int,
	material_id: int,
	emission_flags: int = EMISSION_FLAG_NONE
) -> void:
	# Painting is retained as a prototype/gameplay front end. Simulation-facing
	# equipment, enemies, and spawners use the same material-emission operation.
	emit_disc(cx, cy, radius, material_id, emission_flags)


func _set_cell_internal(
	x: int,
	y: int,
	material_id: int,
	emission_flags: int = EMISSION_FLAG_NONE
) -> bool:
	if not in_bounds(x, y):
		return false
	var index: int = cell_index(x, y)
	if material_id != EMPTY and rigid_body_occupancy[index] != 0:
		return false
	var previous_material: int = cells[index]
	if previous_material == material_id:
		return false
	cells[index] = material_id
	if _is_hard_surface_material(previous_material) != _is_hard_surface_material(material_id):
		hard_surface_revision += 1
	flow_budget[index] = _initial_lateral_flow(material_id)
	flow_direction[index] = FLOW_DIRECTION_NONE
	if (
		_is_cellular_liquid(material_id)
		and (emission_flags & EMISSION_FLAG_COHERENT_LIQUID) != 0
	):
		flow_budget[index] = 0
		flow_direction[index] = FLOW_FLAG_COHERENT_EMISSION
	updated_at[index] = update_epoch
	_wake_cell_area(
		x - CELL_WAKE_RADIUS,
		y - CELL_WAKE_RADIUS,
		x + CELL_WAKE_RADIUS,
		y + CELL_WAKE_RADIUS
	)
	_adjust_movable_count(x, y, previous_material, material_id)
	mark_current_area(x - 1, y - 1, x + 1, y + 1)
	return true


func material_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return WALL
	var index: int = cell_index(x, y)
	if rigid_body_occupancy[index] != 0:
		return WALL
	return cells[index]


func get_cells() -> PackedByteArray:
	return cells


func box_collides(origin: Vector2, size: Vector2) -> bool:
	return character_box_collides(origin, size, 0)


func character_box_collides(origin: Vector2, size: Vector2, mode: int) -> bool:
	if not origin.is_finite() or not size.is_finite() or size.x <= 0 or size.y <= 0 or size.x > 32 or size.y > 32 or mode < 0 or mode > 3 or origin.x < 0 or origin.y < 0 or origin.x + size.x > WORLD_WIDTH or origin.y + size.y > WORLD_HEIGHT:
		return true
	var first_x: int = floori(origin.x + 0.001)
	var first_y: int = floori(origin.y + 0.001)
	var last_x: int = ceili(origin.x + size.x - 0.001) - 1
	var last_y: int = ceili(origin.y + size.y - 0.001) - 1

	for y: int in range(first_y, last_y + 1):
		for x: int in range(first_x, last_x + 1):
			if _is_hard_surface_material(material_at(x, y)):
				return true
			if (mode == 1 and y != last_y) or (mode == 2 and x != first_x and x != last_x) or (mode == 3 and y != first_y):
				continue
			if CyberInteractionPolicy.supports_at(self, x, y, mode >= 2):
				return true
	return false


func set_interest_center(world_cell: Vector2i) -> void:
	interest_cell.x = clampi(world_cell.x, 0, WORLD_WIDTH - 1)
	interest_cell.y = clampi(world_cell.y, 0, WORLD_HEIGHT - 1)


func set_liquid_surface_adhesion_enabled(enabled: bool) -> void:
	if liquid_surface_adhesion_enabled == enabled:
		return
	liquid_surface_adhesion_enabled = enabled
	# The comparison toggle is rare and must affect already-settled liquid, not
	# just subsequently painted cells. Wake existing movable blocks once; normal
	# ticks remain allocation-free and retain their fine activity filtering.
	quiet_ticks.fill(0)
	for block_id: int in range(BLOCK_COUNT):
		if block_movable_counts[block_id] > 0:
			active_blocks[block_id] = 1


func set_simulation_window(
		view_origin: Vector2i,
		view_size: Vector2i,
		horizontal_buffer: int,
		vertical_buffer: int
) -> void:
	var first_x: int = clampi(view_origin.x - horizontal_buffer, 0, WORLD_WIDTH)
	var first_y: int = clampi(view_origin.y - vertical_buffer, 0, WORLD_HEIGHT)
	var last_x: int = clampi(view_origin.x + view_size.x + horizontal_buffer, 0, WORLD_WIDTH)
	var last_y: int = clampi(view_origin.y + view_size.y + vertical_buffer, 0, WORLD_HEIGHT)
	simulation_bounds = Rect2i(first_x, first_y, last_x - first_x, last_y - first_y)


func mark_current_area(first_x: int, first_y: int, last_x: int, last_y: int) -> void:
	var min_block_x: int = clampi(first_x, 0, WORLD_WIDTH - 1) >> ACTIVITY_BLOCK_SHIFT
	var max_block_x: int = clampi(last_x, 0, WORLD_WIDTH - 1) >> ACTIVITY_BLOCK_SHIFT
	var min_block_y: int = clampi(first_y, 0, WORLD_HEIGHT - 1) >> ACTIVITY_BLOCK_SHIFT
	var max_block_y: int = clampi(last_y, 0, WORLD_HEIGHT - 1) >> ACTIVITY_BLOCK_SHIFT
	for block_y: int in range(min_block_y, max_block_y + 1):
		for block_x: int in range(min_block_x, max_block_x + 1):
			active_blocks[block_index(block_x, block_y)] = 1


func mark_next_area(first_x: int, first_y: int, last_x: int, last_y: int) -> void:
	var min_block_x: int = clampi(first_x, 0, WORLD_WIDTH - 1) >> ACTIVITY_BLOCK_SHIFT
	var max_block_x: int = clampi(last_x, 0, WORLD_WIDTH - 1) >> ACTIVITY_BLOCK_SHIFT
	var min_block_y: int = clampi(first_y, 0, WORLD_HEIGHT - 1) >> ACTIVITY_BLOCK_SHIFT
	var max_block_y: int = clampi(last_y, 0, WORLD_HEIGHT - 1) >> ACTIVITY_BLOCK_SHIFT
	for block_y: int in range(min_block_y, max_block_y + 1):
		for block_x: int in range(min_block_x, max_block_x + 1):
			next_active_blocks[block_index(block_x, block_y)] = 1


func _is_sparse_free_flight_cell(x: int, y: int, material_id: int) -> bool:
	var vertical_direction: int = -1 if material_id == SMOKE else 1
	var first_y: int = y + vertical_direction
	var second_y: int = y + vertical_direction * SPARSE_FLIGHT_DISTANCE
	if not in_bounds(x, first_y) or not in_bounds(x, second_y):
		return false
	var first_index: int = cell_index(x, first_y)
	var second_index: int = cell_index(x, second_y)
	if (
		cells[first_index] != EMPTY
		or cells[second_index] != EMPTY
		or rigid_body_occupancy[first_index] != 0
		or rigid_body_occupancy[second_index] != 0
		or updated_at[first_index] == update_epoch
		or updated_at[second_index] == update_epoch
	):
		return false

	# Dense streams and sheets remain on the exact full-rate path. Only an
	# isolated cell with no same-material upstream/side neighbour is sampled.
	var upstream_y: int = y - vertical_direction
	if in_bounds(x, upstream_y) and cells[cell_index(x, upstream_y)] == material_id:
		return false
	for side: int in range(-1, 2, 2):
		var side_x: int = x + side
		if not in_bounds(side_x, y):
			continue
		if cells[cell_index(side_x, y)] == material_id:
			return false
		if cells[cell_index(side_x, first_y)] == material_id:
			return false
	return true


func _smoke_should_dissipate(x: int, y: int) -> bool:
	# The portable fallback has no spare authoritative state byte. A cheap
	# spatially staggered hazard therefore approximates the native long lifetime
	# without allocating a 1024x1024 age field. Dense clouds receive twice the
	# removal probability, producing the same gradual hollowing/thinning intent.
	# The warm-up protects newborn puffs and short displacement interactions;
	# native mode instead tracks an exact per-cell lifetime from birth.
	if tick_index < 64 or ((x * 17 + y * 31 + tick_index) & 31) != 0:
		return false
	var neighbours: int = 0
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var sample_x: int = x + offset_x
			var sample_y: int = y + offset_y
			if in_bounds(sample_x, sample_y) and cells[cell_index(sample_x, sample_y)] == SMOKE:
				neighbours += 1
	var roll: int = (
		(x * 73856093) ^ (y * 19349663) ^ (tick_index * 83492791)
	) & 255
	return roll < (2 if neighbours >= 5 else 1)


func _try_sparse_ballistic_move(
	x: int,
	y: int,
	material_id: int,
	job_slot: int
) -> bool:
	var vertical_direction: int = -1 if material_id == SMOKE else 1
	var target_y: int = y + vertical_direction * SPARSE_FLIGHT_DISTANCE
	if not try_move(x, y, x, target_y, false, job_slot):
		return false
	if _is_cellular_liquid(material_id):
		_configure_liquid_after_gravity_move(
			cell_index(x, target_y),
			material_id,
			0
		)
	return true


func _try_liquid_lateral(
	x: int,
	y: int,
	direction: int,
	require_pressure: bool = false,
	job_slot: int = -1
) -> bool:
	var adjacent_x: int = x + direction
	if not in_bounds(adjacent_x, y):
		return false
	var source_index: int = cell_index(x, y)
	var source_material: int = cells[source_index]
	if material_at(adjacent_x, y) != EMPTY:
		return false
	var initial_flow: int = _initial_lateral_flow(source_material)
	if initial_flow <= 0:
		return false

	var source_flow_flags: int = _flow_state_flags(flow_direction[source_index])
	var coherent_emission: bool = (
		(source_flow_flags & FLOW_FLAG_COHERENT_EMISSION) != 0
	)
	if coherent_emission and not _liquid_column_is_grounded(source_material, x, y):
		return false
	var remaining_budget: int = 0 if coherent_emission else flow_budget[source_index]
	var pressure_driven: bool = false
	if remaining_budget <= 0 or require_pressure:
		pressure_driven = _liquid_has_pressure_advantage(source_material, x, y, adjacent_x)
	if require_pressure and not pressure_driven:
		return false
	if remaining_budget <= 0 and not pressure_driven:
		return false

	# Dispersion is an atomic move through a contiguous empty row. It never
	# tunnels through another material, and the write-once epoch still prevents
	# two cells from claiming the same destination. Adhesive materials may cross
	# unsupported columns to preserve Water's spray/capillary behavior; opted-out
	# materials stop at support instead. Coherent emissions reached this point
	# only after gaining support, so emission state and material adhesion remain
	# independent controls.
	var target_x: int = x
	var flow_rate: int = _liquid_lateral_flow_rate(source_material)
	if coherent_emission:
		flow_rate = mini(flow_rate, COHERENT_LIQUID_LATERAL_FLOW_RATE)
	var surface_adhesion: bool = _liquid_has_surface_adhesion(source_material)
	for distance: int in range(1, flow_rate + 1):
		var sample_x: int = x + direction * distance
		if not in_bounds(sample_x, y) or material_at(sample_x, y) != EMPTY:
			break
		if not surface_adhesion and not _liquid_destination_is_supported(source_material, sample_x, y):
			# Non-adhering liquids cannot bridge an unsupported span. They reach
			# the lip and then use the normal gravity/diagonal path on a later
			# update instead of leaving a connected film across the surface.
			break
		if updated_at[cell_index(sample_x, y)] != update_epoch:
			target_x = sample_x
	if target_x == x:
		return false
	var target_index: int = cell_index(target_x, y)
	if not try_move(x, y, target_x, y, false, job_slot):
		return false

	# Coherent emission stays pressure-driven and directionless. Ordinary Water
	# carries lateral momentum until obstructed; Slush/Paste retain their finite
	# budgets. Viscosity remains a material rate, independent of emission state.
	if coherent_emission:
		flow_budget[target_index] = 0
		flow_direction[target_index] = source_flow_flags
	elif initial_flow == FREE_LIQUID_LATERAL_FLOW:
		flow_budget[target_index] = FREE_LIQUID_LATERAL_FLOW
		flow_direction[target_index] = _encode_flow_direction(direction) | source_flow_flags
	else:
		flow_budget[target_index] = maxi(0, remaining_budget - 1)
		flow_direction[target_index] = _encode_flow_direction(direction) | source_flow_flags
	return true


func _initial_lateral_flow(material_id: int) -> int:
	match material_id:
		WATER:
			return FREE_LIQUID_LATERAL_FLOW
		SLUSH:
			return YIELDING_LIQUID_LATERAL_BUDGET
		PASTE:
			return PASTE_LIQUID_LATERAL_BUDGET
		_:
			return 0


func _liquid_pressure_yield(material_id: int) -> int:
	match material_id:
		WATER:
			return 0
		SLUSH:
			return YIELDING_LIQUID_PRESSURE_YIELD
		PASTE:
			return PASTE_LIQUID_PRESSURE_YIELD
		_:
			return 0


func _liquid_viscosity(material_id: int) -> int:
	match material_id:
		WATER:
			return WATER_VISCOSITY
		SLUSH:
			return SLUSH_VISCOSITY
		PASTE:
			return PASTE_VISCOSITY
		_:
			return 255


func _liquid_lateral_flow_rate(material_id: int) -> int:
	if _initial_lateral_flow(material_id) <= 0:
		return 0
	var viscosity: int = clampi(_liquid_viscosity(material_id), 0, 255)
	var mobility: int = 255 - viscosity
	return 1 + int(roundi(
		float(mobility * (MAX_LIQUID_LATERAL_FLOW_RATE - 1)) / 255.0
	))


func _encode_flow_direction(direction: int) -> int:
	return FLOW_DIRECTION_LEFT if direction < 0 else FLOW_DIRECTION_RIGHT


func _decode_flow_direction(encoded: int) -> int:
	var direction: int = encoded & FLOW_DIRECTION_MASK
	if direction == FLOW_DIRECTION_LEFT:
		return -1
	if direction == FLOW_DIRECTION_RIGHT:
		return 1
	return 0


func _flow_state_flags(encoded: int) -> int:
	return encoded & FLOW_STATE_FLAGS_MASK


func _is_coherent_liquid_state(index: int) -> bool:
	return (
		(_flow_state_flags(flow_direction[index]) & FLOW_FLAG_COHERENT_EMISSION) != 0
	)


func _coherent_liquid_can_use_diagonal(x: int, y: int, material_id: int) -> bool:
	# A coherent column waits behind its own falling cells and behind a cell that
	# another rule already touched this tick. It may still flow diagonally around
	# a real, non-displaceable obstacle or over an actual ledge.
	if not in_bounds(x, y + 1):
		return false
	var below_index: int = cell_index(x, y + 1)
	if updated_at[below_index] == update_epoch:
		return false
	var below_material: int = material_at(x, y + 1)
	if below_material == EMPTY or below_material == material_id:
		return false
	return not _can_density_exchange(material_id, below_material, 1)


func _is_cellular_liquid(material_id: int) -> bool:
	return material_id == WATER or material_id == SLUSH or material_id == PASTE


func _liquid_has_surface_adhesion(material_id: int) -> bool:
	if not liquid_surface_adhesion_enabled:
		return false
	# This material trait intentionally remains independent of viscosity and
	# pressure yield. Future active/corrosive liquids can opt out without losing
	# their gravity or density behavior.
	match material_id:
		WATER:
			return WATER_SURFACE_ADHESION
		SLUSH:
			return SLUSH_SURFACE_ADHESION
		PASTE:
			return PASTE_SURFACE_ADHESION
		_:
			return false


func _liquid_destination_is_supported(material_id: int, x: int, y: int) -> bool:
	if not in_bounds(x, y + 1):
		return true
	var supporting_material: int = material_at(x, y + 1)
	return (
		supporting_material != EMPTY
		and not _can_density_exchange(material_id, supporting_material, 1)
	)


func _liquid_column_is_grounded(material_id: int, x: int, y: int) -> bool:
	# Coherent emission may level once its vertical run reaches stable support,
	# but not while the entire run is falling through Empty. The bounded scan is
	# paid only by coherent cells attempting lateral pressure flow.
	for depth: int in range(1, LIQUID_PRESSURE_SAMPLE_DEPTH + 1):
		var sample_y: int = y + depth
		if not in_bounds(x, sample_y):
			return true
		var sample_material: int = material_at(x, sample_y)
		if sample_material == material_id:
			continue
		return (
			sample_material != EMPTY
			and not _can_density_exchange(material_id, sample_material, 1)
		)
	# A run at least as deep as the pressure sample bound is treated as supported;
	# this keeps the coherent-path cost bounded in unusually deep reservoirs.
	return true


func _material_density(material_id: int) -> int:
	match material_id:
		SAND:
			return 1600
		WATER:
			return 1000
		SLUSH:
			return 1100
		PASTE:
			return 1300
		SMOKE:
			return 20
		WALL:
			return 65535
		_:
			return 0


func _density_motion(material_id: int) -> int:
	match material_id:
		SAND, WATER, SLUSH, PASTE:
			return DENSITY_MOTION_DOWN
		SMOKE:
			return DENSITY_MOTION_UP
		_:
			return DENSITY_MOTION_NONE


func _accepts_density_exchange(material_id: int) -> bool:
	# This explicit target-side trait is what lets future gels, foams, trapped
	# gases, and load-bearing granular materials opt out while remaining movable.
	return (
		material_id == SAND
		or material_id == WATER
		or material_id == SMOKE
		or material_id == SLUSH
		or material_id == PASTE
	)


func _can_density_exchange(source_material: int, target_material: int, delta_y: int) -> bool:
	if delta_y == 0 or not _accepts_density_exchange(target_material):
		return false
	var source_motion: int = _density_motion(source_material)
	if delta_y > 0:
		return (
			source_motion == DENSITY_MOTION_DOWN
			and _material_density(source_material) > _material_density(target_material)
		)
	return (
		source_motion == DENSITY_MOTION_UP
		and _material_density(source_material) < _material_density(target_material)
	)


func _liquid_has_pressure_advantage(
	material_id: int,
	source_x: int,
	y: int,
	target_x: int
) -> bool:
	var source_depth: int = _liquid_depth_below(material_id, source_x, y)
	var target_depth: int = _liquid_depth_below(material_id, target_x, y)
	var yield_depth: int = _liquid_pressure_yield(material_id)
	if source_depth > target_depth + yield_depth:
		return true

	# A one-cell-at-a-time comparison can incorrectly accept a long staircase as
	# equilibrium. Inspect the bounded contiguous surface run so a lower column
	# cannot be missed before the cell reaches its sleep threshold. This fallback
	# is serial; the preferred native solver keeps its phased bounded-write rules.
	var direction: int = -1 if target_x < source_x else 1
	for distance: int in range(2, LIQUID_LEVEL_SEARCH_DISTANCE + 1):
		var sample_x: int = source_x + direction * distance
		if not in_bounds(sample_x, y) or material_at(sample_x, y) != EMPTY:
			break
		if (
			not _liquid_has_surface_adhesion(material_id)
			and not _liquid_destination_is_supported(material_id, sample_x, y)
		):
			break
		if source_depth > _liquid_depth_below(material_id, sample_x, y) + yield_depth:
			return true
	return false


func _liquid_depth_below(material_id: int, x: int, y: int) -> int:
	var depth_count: int = 0
	for depth: int in range(1, LIQUID_PRESSURE_SAMPLE_DEPTH + 1):
		if material_at(x, y + depth) != material_id:
			break
		depth_count += 1
	return depth_count


func _wake_cell_area(first_x: int, first_y: int, last_x: int, last_y: int) -> void:
	var clamped_first_x: int = clampi(first_x, 0, WORLD_WIDTH - 1)
	var clamped_first_y: int = clampi(first_y, 0, WORLD_HEIGHT - 1)
	var clamped_last_x: int = clampi(last_x, 0, WORLD_WIDTH - 1)
	var clamped_last_y: int = clampi(last_y, 0, WORLD_HEIGHT - 1)
	for wake_y: int in range(clamped_first_y, clamped_last_y + 1):
		var row_index: int = wake_y * WORLD_WIDTH
		for wake_x: int in range(clamped_first_x, clamped_last_x + 1):
			quiet_ticks[row_index + wake_x] = 0


func _wake_motion_endpoint(x: int, y: int) -> void:
	_wake_cell_area(
		x - CELL_WAKE_RADIUS,
		y - CELL_WAKE_RADIUS,
		x + CELL_WAKE_RADIUS,
		y + CELL_WAKE_RADIUS
	)


func _count_eligible_active_blocks() -> int:
	var count: int = 0
	for block_y: int in range(BLOCK_ROWS):
		for block_x: int in range(BLOCK_COLUMNS):
			var block_id: int = block_index(block_x, block_y)
			if active_blocks[block_id] == 0 or block_movable_counts[block_id] == 0:
				continue
			if simulation_window_enabled and not _block_intersects_simulation_window(block_x, block_y):
				continue
			count += 1
	return count


func _block_intersects_simulation_window(block_x: int, block_y: int) -> bool:
	var first_x: int = block_x << ACTIVITY_BLOCK_SHIFT
	var first_y: int = block_y << ACTIVITY_BLOCK_SHIFT
	var last_x: int = mini(WORLD_WIDTH, first_x + ACTIVITY_BLOCK_SIZE)
	var last_y: int = mini(WORLD_HEIGHT, first_y + ACTIVITY_BLOCK_SIZE)
	var window_last_x: int = simulation_bounds.position.x + simulation_bounds.size.x
	var window_last_y: int = simulation_bounds.position.y + simulation_bounds.size.y
	return (
		first_x < window_last_x
		and last_x > simulation_bounds.position.x
		and first_y < window_last_y
		and last_y > simulation_bounds.position.y
	)


func _rebuild_block_metadata() -> void:
	active_blocks.fill(0)
	next_active_blocks.fill(0)
	block_movable_counts.fill(0)
	for y: int in range(WORLD_HEIGHT):
		for x: int in range(WORLD_WIDTH):
			var cell_material: int = cells[cell_index(x, y)]
			if is_movable(cell_material):
				var block_id: int = block_index(x >> ACTIVITY_BLOCK_SHIFT, y >> ACTIVITY_BLOCK_SHIFT)
				block_movable_counts[block_id] += 1
				active_blocks[block_id] = 1


func _adjust_movable_count(x: int, y: int, old_material: int, new_material: int) -> void:
	var old_movable: bool = is_movable(old_material)
	var new_movable: bool = is_movable(new_material)
	if old_movable == new_movable:
		return
	var block_id: int = block_index(x >> ACTIVITY_BLOCK_SHIFT, y >> ACTIVITY_BLOCK_SHIFT)
	block_movable_counts[block_id] += 1 if new_movable else -1


func _write_direct(x: int, y: int, material_id: int) -> void:
	var index: int = cell_index(x, y)
	cells[index] = material_id
	flow_budget[index] = _initial_lateral_flow(material_id)
	flow_direction[index] = FLOW_DIRECTION_NONE


func cell_index(x: int, y: int) -> int:
	return y * WORLD_WIDTH + x


func block_index(block_x: int, block_y: int) -> int:
	return block_y * BLOCK_COLUMNS + block_x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < WORLD_WIDTH and y >= 0 and y < WORLD_HEIGHT


func _is_hard_surface_material(material_id: int) -> bool:
	if material_id >= LIMESTONE_BLOCK and material_id <= LED_WHITE:
		return true
	match material_id:
		WALL, CLONER, WOOD, ICE, METAL, CONCRETE, GLASS:
			return true
		_:
			return false


func is_movable(material_id: int) -> bool:
	return (
		material_id == SAND
		or material_id == WATER
		or material_id == SMOKE
		or material_id == SLUSH
		or material_id == PASTE
	)


var downward_support_cells: int = CyberInteractionPolicy.DOWNWARD_CELLS

func is_character_solid(material_id: int) -> bool:
	# Compatibility capability query. Powders require coordinates/packing.
	return _is_hard_surface_material(material_id)
