class_name CyberRapierPhysicsBridge
extends RefCounted

# Main-thread owner of the Rapier2D space used by the cellular/rigid-body
# prototype. Only packed value data produced here crosses to the cellular
# worker; RIDs and scene nodes never leave the Godot main thread.
const ENGINE_SETTING: StringName = &"physics/2d/physics_engine"
const EXPECTED_ENGINE: String = "Rapier2D"
const EXPECTED_SERVER_CLASS: StringName = &"RapierPhysicsServer2D"
const DEFAULT_TICK_RATE: float = 60.0
const SAMPLE_SERIAL_LIMIT: int = 1000000
const MOTION_EPSILON_SQUARED: float = 0.000001
const MAX_CELLULAR_RESULT_AGE_TICKS: int = 8
const MAX_POSITIONAL_CORRECTION_AGE_TICKS: int = 1
const HARD_SURFACE_FRICTION: float = 0.78
const HARD_SURFACE_BOUNCE: float = 0.0
const HARD_SURFACE_CHUNK_SIZE: int = 64

var _space: RID
var _bodies: Array[RigidBody2D] = []
var _body_rids: Array[RID] = []
var _body_sizes: PackedVector2Array = PackedVector2Array()
var _body_masses: PackedFloat32Array = PackedFloat32Array()
var _transforms: Array[Transform2D] = []
var _linear_velocities: PackedVector2Array = PackedVector2Array()
var _angular_velocities: PackedFloat32Array = PackedFloat32Array()
var _sleeping: Array[bool] = []
var _body_index_by_rid: Dictionary = {}
var _applied_sample_serials: PackedInt32Array = PackedInt32Array()
var _hard_surface_body: RID
var _hard_surface_shape_rids: Array[RID] = []
var _hard_surface_chunk_bodies: Array[RID] = []
var _hard_surface_chunk_shape_rids: Array = []
var _hard_surface_chunk_rectangles: Array = []
var _pending_hard_surface_chunk_snapshot: PackedInt32Array = PackedInt32Array()
var _pending_hard_surface_scan_cursor: int = 0
var _pending_hard_surface_chunks: int = 0

var _initialized: bool = false
var _sample_serial: int = 0
var _last_result_snapshot_serial: int = -1
var _manual_step_count: int = 0
var _last_active_body_count: int = 0
var _last_step_time_ms: float = 0.0
var _last_flush_time_ms: float = 0.0
var _last_results_applied: int = 0
var _last_stale_results_rejected: int = 0
var _hard_surface_shape_count: int = 0
var _last_hard_surface_build_time_ms: float = 0.0


func initialize(
	space: RID,
	bodies: Array[RigidBody2D],
	body_sizes: PackedVector2Array
) -> Error:
	if _initialized:
		return ERR_ALREADY_IN_USE
	if not ClassDB.class_exists(EXPECTED_SERVER_CLASS):
		return ERR_UNAVAILABLE
	if str(ProjectSettings.get_setting(ENGINE_SETTING, "")) != EXPECTED_ENGINE:
		return ERR_UNAVAILABLE
	if not space.is_valid() or bodies.is_empty() or bodies.size() != body_sizes.size():
		return ERR_INVALID_PARAMETER

	_space = space
	_bodies.assign(bodies)
	_body_sizes = body_sizes.duplicate()
	_body_rids.clear()
	_body_masses.resize(_bodies.size())
	_transforms.clear()
	_linear_velocities.resize(_bodies.size())
	_angular_velocities.resize(_bodies.size())
	_sleeping.clear()
	_body_index_by_rid.clear()
	_applied_sample_serials.resize(_bodies.size())
	_applied_sample_serials.fill(-1)

	for body_index: int in range(_bodies.size()):
		var body: RigidBody2D = _bodies[body_index]
		var body_rid: RID = body.get_rid()
		if not body_rid.is_valid():
			clear_state()
			return ERR_INVALID_DATA
		_body_rids.append(body_rid)
		_body_masses[body_index] = body.mass
		_body_index_by_rid[body_rid] = body_index
		_transforms.append(Transform2D.IDENTITY)
		_sleeping.append(false)
		PhysicsServer2D.body_set_param(
			body_rid,
			PhysicsServer2D.BODY_PARAM_FRICTION,
			HARD_SURFACE_FRICTION
		)
		PhysicsServer2D.body_set_param(
			body_rid,
			PhysicsServer2D.BODY_PARAM_BOUNCE,
			HARD_SURFACE_BOUNCE
		)
		PhysicsServer2D.body_set_continuous_collision_detection_mode(
			body_rid,
			PhysicsServer2D.CCD_MODE_CAST_SHAPE
		)

	_hard_surface_body = _create_hard_surface_body()
	if not _hard_surface_body.is_valid():
		clear_state()
		return ERR_CANT_CREATE

	# Manual stepping gives the coupling layer an explicit transaction order:
	# apply the newest cellular response, step Rapier once, flush callbacks once,
	# then publish authoritative physics-server state to the cellular worker.
	PhysicsServer2D.space_set_active(_space, false)
	_initialized = true
	refresh_all_states()
	return OK


func shutdown() -> void:
	if _initialized and _space.is_valid():
		PhysicsServer2D.space_set_active(_space, true)
	_destroy_hard_surface_collider()
	clear_state()


func is_initialized() -> bool:
	return _initialized


func fixed_delta() -> float:
	var tick_rate: float = float(
		ProjectSettings.get_setting(
			&"physics/common/physics_ticks_per_second",
			DEFAULT_TICK_RATE
		)
	)
	return 1.0 / maxf(tick_rate, 1.0)


func apply_cellular_results(
	snapshot_serial: int,
	results: PackedFloat32Array
) -> int:
	_last_results_applied = 0
	_last_stale_results_rejected = 0
	if not _initialized or snapshot_serial == _last_result_snapshot_serial:
		return 0
	_last_result_snapshot_serial = snapshot_serial

	for result_index: int in range(CyberRigidBodyCoupling.result_body_count(results)):
		var offset: int = result_index * CyberRigidBodyCoupling.RESULT_STRIDE
		var body_id: int = roundi(
			results[offset + CyberRigidBodyCoupling.RESULT_BODY_ID]
		)
		var body_index: int = body_id - 1
		if body_index < 0 or body_index >= _body_rids.size():
			continue
		var result_sample_serial: int = roundi(
			results[offset + CyberRigidBodyCoupling.RESULT_SAMPLE_SERIAL]
		)
		if _applied_sample_serials[body_index] == result_sample_serial:
			continue
		_applied_sample_serials[body_index] = result_sample_serial
		var sample_age: int = _sample_age(result_sample_serial)
		if sample_age > MAX_CELLULAR_RESULT_AGE_TICKS:
			_last_stale_results_rejected += 1
			continue

		var body_rid: RID = _body_rids[body_index]
		var correction: Vector2 = Vector2(
			results[offset + CyberRigidBodyCoupling.RESULT_CORRECTION_X],
			results[offset + CyberRigidBodyCoupling.RESULT_CORRECTION_Y]
		)
		var impulse: Vector2 = Vector2(
			results[offset + CyberRigidBodyCoupling.RESULT_IMPULSE_X],
			results[offset + CyberRigidBodyCoupling.RESULT_IMPULSE_Y]
		)
		if sample_age > MAX_POSITIONAL_CORRECTION_AGE_TICKS:
			correction = Vector2.ZERO

		if correction.length_squared() > MOTION_EPSILON_SQUARED:
			var transform: Transform2D = PhysicsServer2D.body_get_state(
				body_rid,
				PhysicsServer2D.BODY_STATE_TRANSFORM
			)
			transform.origin += correction
			PhysicsServer2D.body_set_state(
				body_rid,
				PhysicsServer2D.BODY_STATE_TRANSFORM,
				transform
			)
			_transforms[body_index] = transform

			var corrected_velocity: Vector2 = PhysicsServer2D.body_get_state(
				body_rid,
				PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY
			)
			if correction.x != 0.0 and corrected_velocity.x * correction.x < 0.0:
				corrected_velocity.x = 0.0
			if correction.y != 0.0 and corrected_velocity.y * correction.y < 0.0:
				corrected_velocity.y = 0.0
			PhysicsServer2D.body_set_state(
				body_rid,
				PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
				corrected_velocity
			)

		# A bounded age falloff preserves two-way fluid/particle coupling without
		# injecting a full-strength impulse computed from a several-frame-old pose.
		var impulse_age_scale: float = 1.0 / (1.0 + float(sample_age) * 0.25)
		impulse *= impulse_age_scale
		if impulse.length_squared() > MOTION_EPSILON_SQUARED:
			PhysicsServer2D.body_apply_central_impulse(body_rid, impulse)
		if (
			correction.length_squared() > MOTION_EPSILON_SQUARED
			or impulse.length_squared() > MOTION_EPSILON_SQUARED
		):
			PhysicsServer2D.body_set_state(
				body_rid,
				PhysicsServer2D.BODY_STATE_SLEEPING,
				false
			)
			_last_results_applied += 1

	return _last_results_applied


func _sample_age(sample_serial: int) -> int:
	var age: int = _sample_serial - sample_serial
	if age < 0:
		age += SAMPLE_SERIAL_LIMIT
	return age


func rebuild_hard_surface_colliders(
	material_cells: PackedByteArray,
	world_width: int,
	world_height: int
) -> int:
	if (
		not _initialized
		or not _hard_surface_body.is_valid()
		or world_width <= 0
		or world_height <= 0
		or material_cells.size() < world_width * world_height
	):
		return 0
	var build_start_usec: int = Time.get_ticks_usec()
	var rectangles: Array[Rect2i] = _merge_hard_surface_rectangles(
		material_cells,
		world_width,
		world_height
	)
	return _replace_hard_surface_colliders(rectangles, build_start_usec)


func rebuild_hard_surface_colliders_from_rectangles(
	packed_rectangles: PackedInt32Array
) -> int:
	if (
		not _initialized
		or not _hard_surface_body.is_valid()
		or packed_rectangles.size() % 4 != 0
	):
		return 0
	var build_start_usec: int = Time.get_ticks_usec()
	var rectangles: Array[Rect2i] = []
	rectangles.resize(packed_rectangles.size() / 4)
	for rectangle_index: int in range(rectangles.size()):
		var offset: int = rectangle_index * 4
		rectangles[rectangle_index] = Rect2i(
			packed_rectangles[offset],
			packed_rectangles[offset + 1],
			packed_rectangles[offset + 2],
			packed_rectangles[offset + 3]
		)
	return _replace_hard_surface_colliders(rectangles, build_start_usec)


# The native worker still publishes one compact rectangle list, but collision
# ownership is split into 64x64 collision chunks here. A Fire/Wood change can
# therefore replace one small static body instead of clearing and recreating
# every Rapier terrain shape in the 1024x1024 prototype world.
func rebuild_hard_surface_colliders_from_rectangles_chunked(
	packed_rectangles: PackedInt32Array,
	world_width: int,
	world_height: int,
	chunk_size: int = HARD_SURFACE_CHUNK_SIZE
) -> int:
	if (
		not _initialized
		or packed_rectangles.size() % 4 != 0
		or world_width <= 0
		or world_height <= 0
		or chunk_size <= 0
	):
		return 0
	var build_start_usec: int = Time.get_ticks_usec()
	var chunk_columns: int = ceili(float(world_width) / float(chunk_size))
	var chunk_rows: int = ceili(float(world_height) / float(chunk_size))
	var chunk_count: int = chunk_columns * chunk_rows
	var next_chunk_rectangles: Array = []
	next_chunk_rectangles.resize(chunk_count)
	for chunk_index: int in range(chunk_count):
		next_chunk_rectangles[chunk_index] = PackedInt32Array()

	for rectangle_index: int in range(packed_rectangles.size() / 4):
		var offset: int = rectangle_index * 4
		var rectangle: Rect2i = Rect2i(
			packed_rectangles[offset],
			packed_rectangles[offset + 1],
			packed_rectangles[offset + 2],
			packed_rectangles[offset + 3]
		).intersection(Rect2i(0, 0, world_width, world_height))
		if rectangle.size.x <= 0 or rectangle.size.y <= 0:
			continue
		var first_chunk_x: int = rectangle.position.x / chunk_size
		var last_chunk_x: int = (rectangle.end.x - 1) / chunk_size
		var first_chunk_y: int = rectangle.position.y / chunk_size
		var last_chunk_y: int = (rectangle.end.y - 1) / chunk_size
		for chunk_y: int in range(first_chunk_y, last_chunk_y + 1):
			for chunk_x: int in range(first_chunk_x, last_chunk_x + 1):
				var chunk_rect: Rect2i = Rect2i(
					chunk_x * chunk_size,
					chunk_y * chunk_size,
					mini(chunk_size, world_width - chunk_x * chunk_size),
					mini(chunk_size, world_height - chunk_y * chunk_size)
				)
				var clipped: Rect2i = rectangle.intersection(chunk_rect)
				if clipped.size.x <= 0 or clipped.size.y <= 0:
					continue
				var chunk_index: int = chunk_y * chunk_columns + chunk_x
				var chunk_data: PackedInt32Array = next_chunk_rectangles[chunk_index]
				chunk_data.append_array(PackedInt32Array([
					clipped.position.x,
					clipped.position.y,
					clipped.size.x,
					clipped.size.y,
				]))
				next_chunk_rectangles[chunk_index] = chunk_data

	_ensure_hard_surface_chunk_bodies(chunk_count)
	_clear_full_hard_surface_shapes()
	for chunk_index: int in range(chunk_count):
		var next_rectangles: PackedInt32Array = next_chunk_rectangles[chunk_index]
		var previous_rectangles: PackedInt32Array = _hard_surface_chunk_rectangles[chunk_index]
		if next_rectangles == previous_rectangles:
			continue
		_replace_hard_surface_chunk_shapes(chunk_index, next_rectangles)
		_hard_surface_chunk_rectangles[chunk_index] = next_rectangles

	_hard_surface_shape_count = 0
	for chunk_shapes: Array in _hard_surface_chunk_shape_rids:
		_hard_surface_shape_count += chunk_shapes.size()
	_last_hard_surface_build_time_ms = (
		float(Time.get_ticks_usec() - build_start_usec) / 1000.0
	)
	return _hard_surface_shape_count


# Format: [chunk_count, absolute_offset_0 ... absolute_offset_N, rectangle data].
# The native worker performs the million-cell scan and rectangle merge. This
# main-thread bridge touches only a bounded number of chunks per rendered frame.
func queue_hard_surface_chunk_snapshot(packed_chunks: PackedInt32Array) -> bool:
	if not _initialized or packed_chunks.size() < 3:
		return false
	var chunk_count: int = packed_chunks[0]
	var header_size: int = chunk_count + 2
	if chunk_count <= 0 or header_size > packed_chunks.size():
		return false
	var previous_offset: int = packed_chunks[1]
	if previous_offset != header_size:
		return false
	for chunk_index: int in range(chunk_count):
		var next_offset: int = packed_chunks[chunk_index + 2]
		if (
			next_offset < previous_offset
			or next_offset > packed_chunks.size()
			or (next_offset - previous_offset) % 4 != 0
		):
			return false
		previous_offset = next_offset
	if previous_offset != packed_chunks.size():
		return false

	_pending_hard_surface_chunk_snapshot = packed_chunks.duplicate()
	_pending_hard_surface_scan_cursor %= chunk_count
	_pending_hard_surface_chunks = chunk_count
	return true


func process_hard_surface_collider_budget(
	maximum_chunks: int,
	maximum_usec: int
) -> int:
	if (
		not _initialized
		or _pending_hard_surface_chunks <= 0
		or _pending_hard_surface_chunk_snapshot.is_empty()
		or maximum_chunks <= 0
	):
		_last_hard_surface_build_time_ms = 0.0
		return 0
	var start_usec: int = Time.get_ticks_usec()
	var chunk_count: int = _pending_hard_surface_chunk_snapshot[0]
	var processed: int = 0
	_clear_full_hard_surface_shapes()
	while processed < maximum_chunks and _pending_hard_surface_chunks > 0:
		var chunk_index: int = _pending_hard_surface_scan_cursor
		var rectangle_start: int = _pending_hard_surface_chunk_snapshot[chunk_index + 1]
		var rectangle_end: int = _pending_hard_surface_chunk_snapshot[chunk_index + 2]
		var next_rectangles: PackedInt32Array = (
			_pending_hard_surface_chunk_snapshot.slice(rectangle_start, rectangle_end)
		)
		_ensure_hard_surface_chunk_bodies(chunk_index + 1)
		var previous_rectangles: PackedInt32Array = (
			_hard_surface_chunk_rectangles[chunk_index]
		)
		if next_rectangles != previous_rectangles:
			var previous_shape_count: int = (
				_hard_surface_chunk_shape_rids[chunk_index] as Array
			).size()
			_replace_hard_surface_chunk_shapes(chunk_index, next_rectangles)
			_hard_surface_chunk_rectangles[chunk_index] = next_rectangles
			_hard_surface_shape_count += (
				next_rectangles.size() / 4 - previous_shape_count
			)

		_pending_hard_surface_scan_cursor = (chunk_index + 1) % chunk_count
		_pending_hard_surface_chunks -= 1
		processed += 1
		if (
			maximum_usec > 0
			and Time.get_ticks_usec() - start_usec >= maximum_usec
		):
			break

	_last_hard_surface_build_time_ms = (
		float(Time.get_ticks_usec() - start_usec) / 1000.0
	)
	if _pending_hard_surface_chunks <= 0:
		_pending_hard_surface_chunk_snapshot = PackedInt32Array()
	return processed


func pending_hard_surface_chunks() -> int:
	return _pending_hard_surface_chunks


func _create_hard_surface_body() -> RID:
	var body: RID = PhysicsServer2D.body_create()
	if not body.is_valid():
		return RID()
	PhysicsServer2D.body_set_mode(body, PhysicsServer2D.BODY_MODE_STATIC)
	PhysicsServer2D.body_set_param(
		body,
		PhysicsServer2D.BODY_PARAM_FRICTION,
		HARD_SURFACE_FRICTION
	)
	PhysicsServer2D.body_set_param(
		body,
		PhysicsServer2D.BODY_PARAM_BOUNCE,
		HARD_SURFACE_BOUNCE
	)
	PhysicsServer2D.body_set_collision_layer(body, 1)
	PhysicsServer2D.body_set_collision_mask(body, 1)
	PhysicsServer2D.body_set_space(body, _space)
	return body


func _ensure_hard_surface_chunk_bodies(chunk_count: int) -> void:
	while _hard_surface_chunk_bodies.size() < chunk_count:
		_hard_surface_chunk_bodies.append(_create_hard_surface_body())
		_hard_surface_chunk_shape_rids.append([])
		_hard_surface_chunk_rectangles.append(PackedInt32Array())


func _replace_hard_surface_chunk_shapes(
	chunk_index: int,
	packed_rectangles: PackedInt32Array
) -> void:
	var body: RID = _hard_surface_chunk_bodies[chunk_index]
	if not body.is_valid():
		return
	PhysicsServer2D.body_clear_shapes(body)
	var previous_shapes: Array = _hard_surface_chunk_shape_rids[chunk_index]
	for shape_rid: RID in previous_shapes:
		if shape_rid.is_valid():
			PhysicsServer2D.free_rid(shape_rid)
	var next_shapes: Array[RID] = []
	for rectangle_index: int in range(packed_rectangles.size() / 4):
		var offset: int = rectangle_index * 4
		var rectangle: Rect2i = Rect2i(
			packed_rectangles[offset],
			packed_rectangles[offset + 1],
			packed_rectangles[offset + 2],
			packed_rectangles[offset + 3]
		)
		var shape_rid: RID = PhysicsServer2D.rectangle_shape_create()
		PhysicsServer2D.shape_set_data(shape_rid, Vector2(rectangle.size) * 0.5)
		var center: Vector2 = Vector2(rectangle.position) + Vector2(rectangle.size) * 0.5
		PhysicsServer2D.body_add_shape(body, shape_rid, Transform2D(0.0, center))
		next_shapes.append(shape_rid)
	_hard_surface_chunk_shape_rids[chunk_index] = next_shapes


func _replace_hard_surface_colliders(
	rectangles: Array[Rect2i],
	build_start_usec: int
) -> int:
	_destroy_chunk_hard_surface_colliders()
	_clear_full_hard_surface_shapes()

	for rectangle: Rect2i in rectangles:
		if rectangle.size.x <= 0 or rectangle.size.y <= 0:
			continue
		var shape_rid: RID = PhysicsServer2D.rectangle_shape_create()
		PhysicsServer2D.shape_set_data(
			shape_rid,
			Vector2(rectangle.size) * 0.5
		)
		var center: Vector2 = (
			Vector2(rectangle.position) + Vector2(rectangle.size) * 0.5
		)
		PhysicsServer2D.body_add_shape(
			_hard_surface_body,
			shape_rid,
			Transform2D(0.0, center)
		)
		_hard_surface_shape_rids.append(shape_rid)
	_hard_surface_shape_count = _hard_surface_shape_rids.size()
	_last_hard_surface_build_time_ms = (
		float(Time.get_ticks_usec() - build_start_usec) / 1000.0
	)
	return _hard_surface_shape_count


func _merge_hard_surface_rectangles(
	material_cells: PackedByteArray,
	world_width: int,
	world_height: int
) -> Array[Rect2i]:
	var completed: Array[Rect2i] = []
	var active: Dictionary = {}
	for y: int in range(world_height):
		var next_active: Dictionary = {}
		var x: int = 0
		while x < world_width:
			while (
				x < world_width
				and not _is_hard_surface_material(material_cells[y * world_width + x])
			):
				x += 1
			if x >= world_width:
				break
			var first_x: int = x
			while (
				x < world_width
				and _is_hard_surface_material(material_cells[y * world_width + x])
			):
				x += 1
			var run_width: int = x - first_x
			var run_key: Vector2i = Vector2i(first_x, run_width)
			var rectangle: Rect2i
			if active.has(run_key):
				rectangle = active[run_key]
				rectangle.size.y += 1
			else:
				rectangle = Rect2i(first_x, y, run_width, 1)
			next_active[run_key] = rectangle
		for run_key: Vector2i in active:
			if not next_active.has(run_key):
				completed.append(active[run_key])
		active = next_active
	for rectangle: Rect2i in active.values():
		completed.append(rectangle)
	return completed


func _is_hard_surface_material(material_id: int) -> bool:
	if material_id >= CyberCellWorld.LIMESTONE_BLOCK and material_id <= CyberCellWorld.LED_WHITE:
		return true
	match material_id:
		CyberCellWorld.WALL, CyberCellWorld.CLONER, CyberCellWorld.WOOD, CyberCellWorld.ICE, CyberCellWorld.METAL, CyberCellWorld.CONCRETE, CyberCellWorld.GLASS:
			return true
		_:
			return false


func _destroy_hard_surface_collider() -> void:
	_destroy_chunk_hard_surface_colliders()
	_clear_full_hard_surface_shapes()
	if _hard_surface_body.is_valid():
		PhysicsServer2D.free_rid(_hard_surface_body)
	_hard_surface_body = RID()
	_hard_surface_shape_count = 0


func _clear_full_hard_surface_shapes() -> void:
	if _hard_surface_body.is_valid():
		PhysicsServer2D.body_clear_shapes(_hard_surface_body)
	for shape_rid: RID in _hard_surface_shape_rids:
		if shape_rid.is_valid():
			PhysicsServer2D.free_rid(shape_rid)
	_hard_surface_shape_rids.clear()


func _destroy_chunk_hard_surface_colliders() -> void:
	for chunk_index: int in range(_hard_surface_chunk_bodies.size()):
		var body: RID = _hard_surface_chunk_bodies[chunk_index]
		if body.is_valid():
			PhysicsServer2D.body_clear_shapes(body)
		var shapes: Array = _hard_surface_chunk_shape_rids[chunk_index]
		for shape_rid: RID in shapes:
			if shape_rid.is_valid():
				PhysicsServer2D.free_rid(shape_rid)
		if body.is_valid():
			PhysicsServer2D.free_rid(body)
	_hard_surface_chunk_bodies.clear()
	_hard_surface_chunk_shape_rids.clear()
	_hard_surface_chunk_rectangles.clear()
	_pending_hard_surface_chunk_snapshot = PackedInt32Array()
	_pending_hard_surface_scan_cursor = 0
	_pending_hard_surface_chunks = 0


func step() -> void:
	if not _initialized:
		return
	var step_start_usec: int = Time.get_ticks_usec()
	RapierPhysicsServer2D.space_step(_space, fixed_delta())
	_last_step_time_ms = float(Time.get_ticks_usec() - step_start_usec) / 1000.0
	_manual_step_count += 1

	# Rapier exposes an active-body batch path, avoiding stale scene-node caches
	# and preparing the bridge for a larger dynamic-body count.
	var active_body_rids: Array = RapierPhysicsServer2D.space_get_active_bodies(_space)
	var active_transforms: Array = RapierPhysicsServer2D.space_get_bodies_transform(
		_space,
		active_body_rids
	)
	_last_active_body_count = active_body_rids.size()
	var active_count: int = mini(active_body_rids.size(), active_transforms.size())
	for active_index: int in range(active_count):
		var body_rid: RID = active_body_rids[active_index]
		if not _body_index_by_rid.has(body_rid):
			continue
		var body_index: int = int(_body_index_by_rid[body_rid])
		_transforms[body_index] = active_transforms[active_index]

	var flush_start_usec: int = Time.get_ticks_usec()
	RapierPhysicsServer2D.space_flush_queries(_space)
	_last_flush_time_ms = float(Time.get_ticks_usec() - flush_start_usec) / 1000.0
	refresh_dynamic_states()


func pack_body_states() -> PackedFloat32Array:
	var states: PackedFloat32Array = PackedFloat32Array()
	if not _initialized:
		return states
	_sample_serial = (_sample_serial + 1) % SAMPLE_SERIAL_LIMIT
	for body_index: int in range(_body_rids.size()):
		var transform: Transform2D = _transforms[body_index]
		CyberRigidBodyCoupling.append_input(
			states,
			body_index + 1,
			transform.origin,
			transform.get_rotation(),
			_body_sizes[body_index],
			_linear_velocities[body_index],
			_angular_velocities[body_index],
			_body_masses[body_index],
			_sample_serial
		)
	return states


func reset_body(
	body_index: int,
	position: Vector2,
	rotation: float
) -> void:
	if not _initialized or body_index < 0 or body_index >= _body_rids.size():
		return
	var body_rid: RID = _body_rids[body_index]
	var transform: Transform2D = Transform2D(rotation, position)
	PhysicsServer2D.body_set_state(
		body_rid,
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		transform
	)
	PhysicsServer2D.body_set_state(
		body_rid,
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
		Vector2.ZERO
	)
	PhysicsServer2D.body_set_state(
		body_rid,
		PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,
		0.0
	)
	PhysicsServer2D.body_set_state(
		body_rid,
		PhysicsServer2D.BODY_STATE_SLEEPING,
		false
	)
	_transforms[body_index] = transform
	_linear_velocities[body_index] = Vector2.ZERO
	_angular_velocities[body_index] = 0.0
	_sleeping[body_index] = false


func reset_result_tracking() -> void:
	_last_result_snapshot_serial = -1
	_applied_sample_serials.fill(-1)


func body_transform(body_index: int) -> Transform2D:
	if body_index < 0 or body_index >= _transforms.size():
		return Transform2D.IDENTITY
	return _transforms[body_index]


func manual_step_count() -> int:
	return _manual_step_count


func last_active_body_count() -> int:
	return _last_active_body_count


func last_step_time_ms() -> float:
	return _last_step_time_ms


func last_flush_time_ms() -> float:
	return _last_flush_time_ms


func last_results_applied() -> int:
	return _last_results_applied


func last_stale_results_rejected() -> int:
	return _last_stale_results_rejected


func hard_surface_shape_count() -> int:
	return _hard_surface_shape_count


func last_hard_surface_build_time_ms() -> float:
	return _last_hard_surface_build_time_ms


func refresh_all_states() -> void:
	if not _initialized:
		return
	for body_index: int in range(_body_rids.size()):
		var body_rid: RID = _body_rids[body_index]
		_transforms[body_index] = PhysicsServer2D.body_get_state(
			body_rid,
			PhysicsServer2D.BODY_STATE_TRANSFORM
		)
	refresh_dynamic_states()


func refresh_dynamic_states() -> void:
	if not _initialized:
		return
	for body_index: int in range(_body_rids.size()):
		var body_rid: RID = _body_rids[body_index]
		_linear_velocities[body_index] = PhysicsServer2D.body_get_state(
			body_rid,
			PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY
		)
		_angular_velocities[body_index] = float(
			PhysicsServer2D.body_get_state(
				body_rid,
				PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY
			)
		)
		_sleeping[body_index] = bool(
			PhysicsServer2D.body_get_state(
				body_rid,
				PhysicsServer2D.BODY_STATE_SLEEPING
			)
		)


func clear_state() -> void:
	_initialized = false
	_space = RID()
	_bodies.clear()
	_body_rids.clear()
	_body_sizes = PackedVector2Array()
	_body_masses = PackedFloat32Array()
	_transforms.clear()
	_linear_velocities = PackedVector2Array()
	_angular_velocities = PackedFloat32Array()
	_sleeping.clear()
	_body_index_by_rid.clear()
	_applied_sample_serials = PackedInt32Array()
	_hard_surface_body = RID()
	_hard_surface_shape_rids.clear()
	_hard_surface_chunk_bodies.clear()
	_hard_surface_chunk_shape_rids.clear()
	_hard_surface_chunk_rectangles.clear()
	_pending_hard_surface_chunk_snapshot = PackedInt32Array()
	_pending_hard_surface_scan_cursor = 0
	_pending_hard_surface_chunks = 0
	_hard_surface_shape_count = 0
