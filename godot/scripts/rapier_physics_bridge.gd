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
const GCR_MAX_RESULT_AGE_TICKS: int = 1
const GCR_MAX_CONTACT_DISPLACEMENT: float = 0.5
const GCR_SAMPLE_HISTORY: int = MAX_CELLULAR_RESULT_AGE_TICKS + 2
const GCR_SAMPLE_FIELDS: int = 5 # origin x/y, rotation, actual COM x/y

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
var diagnostic_applications: PackedFloat64Array = PackedFloat64Array()
var _gcr_sample_serials: PackedInt32Array = PackedInt32Array()
var _gcr_sample_poses: PackedFloat64Array = PackedFloat64Array()
var _gcr_application_diagnostics: Dictionary = {}
var _gcr_compound_centers := PackedVector2Array()
var _gcr_compound_sizes := PackedVector2Array()
static var _next_gcr_session_id: int = 0
var _gcr_session_id: int = 0


# Opt-in fixed storage: age, accepted x/y, duplicate, stale, received per body.
# Reset each apply call; callers copy/aggregate at their serialized boundary.
func enable_diagnostics() -> void:
	diagnostic_applications.resize(_body_rids.size() * 6)
	diagnostic_applications.fill(0.0)


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
	if bodies.size() > CyberRigidBodyCoupling.MAX_BODIES:
		return ERR_OUT_OF_MEMORY
	var unique_bodies: Dictionary = {}
	for index: int in range(bodies.size()):
		var candidate: RigidBody2D = bodies[index]
		if not is_instance_valid(candidate) or not candidate.is_inside_tree() \
			or not candidate.get_rid().is_valid() or unique_bodies.has(candidate.get_rid()) \
			or not body_sizes[index].is_finite() or body_sizes[index].x <= 0.0 or body_sizes[index].y <= 0.0 \
			or not is_finite(candidate.mass) or candidate.mass <= 0.0:
			return ERR_INVALID_DATA
		unique_bodies[candidate.get_rid()] = true

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
		# ACT-004 parts deliberately vary traction and rebound. Historical bodies
		# without a material override retain the original reference coefficients.
		var material: PhysicsMaterial = body.physics_material_override
		PhysicsServer2D.body_set_param(
			body_rid,
			PhysicsServer2D.BODY_PARAM_FRICTION,
			material.friction if material != null else HARD_SURFACE_FRICTION
		)
		PhysicsServer2D.body_set_param(
			body_rid,
			PhysicsServer2D.BODY_PARAM_BOUNCE,
			material.bounce if material != null else HARD_SURFACE_BOUNCE
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
	_reset_gcr_history()
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
	if not diagnostic_applications.is_empty():
		diagnostic_applications.fill(0.0)
	if not _initialized or snapshot_serial == _last_result_snapshot_serial:
		if _initialized and not diagnostic_applications.is_empty():
			diagnostic_applications[3] = 1.0
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
			if not diagnostic_applications.is_empty():
				diagnostic_applications[body_index * 6 + 3] = 1.0
			continue
		_applied_sample_serials[body_index] = result_sample_serial
		var sample_age: int = _sample_age(result_sample_serial)
		if not diagnostic_applications.is_empty():
			diagnostic_applications[body_index * 6] = sample_age
			diagnostic_applications[body_index * 6 + 5] = 1.0
		if sample_age > MAX_CELLULAR_RESULT_AGE_TICKS:
			if not diagnostic_applications.is_empty():
				diagnostic_applications[body_index * 6 + 4] = 1.0
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

		_apply_cellular_correction(body_index, correction)

		# A bounded age falloff preserves two-way fluid/particle coupling without
		# injecting a full-strength impulse computed from a several-frame-old pose.
		var impulse_age_scale: float = 1.0 / (1.0 + float(sample_age) * 0.25)
		impulse *= impulse_age_scale
		if impulse.length_squared() > MOTION_EPSILON_SQUARED:
			if not diagnostic_applications.is_empty():
				diagnostic_applications[body_index * 6 + 1] = impulse.x
				diagnostic_applications[body_index * 6 + 2] = impulse.y
			_apply_cellular_impulse(body_index, impulse)
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


# Current-main correction and impulse primitives are shared by ordinary bodies
# and one-body compound consumers. They do not calculate a second force law.
func _apply_cellular_correction(body_index: int, correction: Vector2) -> bool:
	if not correction.length_squared() > MOTION_EPSILON_SQUARED:
		return false
	var body_rid: RID = _body_rids[body_index]
	var transform: Transform2D = PhysicsServer2D.body_get_state(
		body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	transform.origin += correction
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, transform)
	_transforms[body_index] = transform
	var corrected_velocity: Vector2 = PhysicsServer2D.body_get_state(
		body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	if correction.x != 0.0 and corrected_velocity.x * correction.x < 0.0:
		corrected_velocity.x = 0.0
	if correction.y != 0.0 and corrected_velocity.y * correction.y < 0.0:
		corrected_velocity.y = 0.0
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
		corrected_velocity)
	return true


func _apply_cellular_impulse(body_index: int, impulse: Vector2,
		world_offset: Vector2 = Vector2.ZERO) -> bool:
	if not impulse.length_squared() > MOTION_EPSILON_SQUARED:
		return false
	if world_offset == Vector2.ZERO:
		PhysicsServer2D.body_apply_central_impulse(_body_rids[body_index], impulse)
	else:
		PhysicsServer2D.body_apply_impulse(_body_rids[body_index], impulse, world_offset)
	return true


func retire_held_cellular_sample(body_index: int, sample_serial: int) -> void:
	# The explicit lab can run native material ticks while Rapier is held. That
	# copied result is retired without applying it when the hold ends.
	if _initialized and body_index >= 0 and body_index < _body_rids.size() \
		and sample_serial >= 0 and sample_serial < SAMPLE_SERIAL_LIMIT:
		_applied_sample_serials[body_index] = sample_serial


func apply_compound_cellular_results(snapshot_serial: int, results: PackedFloat32Array,
		body_index: int, current_sample_serial: int, local_centers: PackedVector2Array,
		proxy_masses: PackedFloat32Array, impulse_cap: float, correction_cap: float) -> Dictionary:
	var refused := {"accepted":false, "outcome":"Invalid", "stale_records":0}
	if not _initialized or body_index < 0 or body_index >= _body_rids.size():
		return refused
	var count: int = local_centers.size()
	if count < 1 or count > CyberRigidBodyCoupling.MAX_BODIES or proxy_masses.size() != count \
		or results.size() != count * CyberRigidBodyCoupling.RESULT_STRIDE \
		or current_sample_serial < 0 or current_sample_serial >= SAMPLE_SERIAL_LIMIT \
		or not is_finite(impulse_cap) or impulse_cap < 0.0 \
		or not is_finite(correction_cap) or correction_cap < 0.0:
		return refused
	if snapshot_serial <= _last_result_snapshot_serial:
		refused.outcome = "DuplicateOrOldSnapshot"
		return refused
	var total_mass: float = 0.0
	for proxy: int in range(count):
		if not local_centers[proxy].is_finite() or not is_finite(proxy_masses[proxy]) \
			or proxy_masses[proxy] <= 0.0:
			return refused
		total_mass += proxy_masses[proxy]
	if not is_finite(total_mass) or total_mass <= 0.0:
		return refused
	var impulses := PackedVector2Array()
	impulses.resize(count)
	var seen := PackedByteArray()
	seen.resize(count)
	var correction := Vector2.ZERO
	var accepted_sample: int = -1
	var contacts: int = 0
	var displaced: int = 0
	var unresolved: int = 0
	# Validate the complete immutable record set before touching any Rapier state.
	# A duplicate/missing proxy or mixed sample cannot amplify force or torque.
	for record: int in range(count):
		var offset: int = record * CyberRigidBodyCoupling.RESULT_STRIDE
		for field: int in range(CyberRigidBodyCoupling.RESULT_STRIDE):
			if not is_finite(results[offset + field]):
				return refused
		var id_value: float = results[offset + CyberRigidBodyCoupling.RESULT_BODY_ID]
		var sample_value: float = results[offset + CyberRigidBodyCoupling.RESULT_SAMPLE_SERIAL]
		if floorf(id_value) != id_value or id_value < 1.0 or id_value > float(count) \
			or floorf(sample_value) != sample_value or sample_value < 0.0 \
			or sample_value >= float(SAMPLE_SERIAL_LIMIT):
			return refused
		var proxy: int = int(id_value) - 1
		var sample: int = int(sample_value)
		if seen[proxy] != 0 or (accepted_sample >= 0 and sample != accepted_sample):
			refused.outcome = "DuplicateProxyOrMixedSample"
			return refused
		seen[proxy] = 1
		accepted_sample = sample
		for field: int in [CyberRigidBodyCoupling.RESULT_CONTACT_COUNT,
			CyberRigidBodyCoupling.RESULT_DISPLACED_COUNT, CyberRigidBodyCoupling.RESULT_UNRESOLVED_COUNT]:
			var value: float = results[offset + field]
			if value < 0.0 or value != floorf(value):
				return refused
		impulses[proxy] = Vector2(results[offset + CyberRigidBodyCoupling.RESULT_IMPULSE_X],
			results[offset + CyberRigidBodyCoupling.RESULT_IMPULSE_Y])
		correction += Vector2(results[offset + CyberRigidBodyCoupling.RESULT_CORRECTION_X],
			results[offset + CyberRigidBodyCoupling.RESULT_CORRECTION_Y]) * (proxy_masses[proxy] / total_mass)
		contacts += int(results[offset + CyberRigidBodyCoupling.RESULT_CONTACT_COUNT])
		displaced += int(results[offset + CyberRigidBodyCoupling.RESULT_DISPLACED_COUNT])
		unresolved += int(results[offset + CyberRigidBodyCoupling.RESULT_UNRESOLVED_COUNT])
	var last_sample: int = _applied_sample_serials[body_index]
	if last_sample >= 0:
		var delta: int = (accepted_sample - last_sample + SAMPLE_SERIAL_LIMIT) % SAMPLE_SERIAL_LIMIT
		if delta == 0 or delta > SAMPLE_SERIAL_LIMIT / 2:
			refused.outcome = "DuplicateOrOldSample"
			return refused
	var age: int = (current_sample_serial - accepted_sample + SAMPLE_SERIAL_LIMIT) % SAMPLE_SERIAL_LIMIT
	if age > MAX_CELLULAR_RESULT_AGE_TICKS:
		refused.outcome = "StaleSample"
		refused.stale_records = count
		return refused
	if not correction.is_finite():
		return refused
	correction = correction.limit_length(correction_cap) \
		if age <= MAX_POSITIONAL_CORRECTION_AGE_TICKS else Vector2.ZERO
	if not correction.is_finite():
		return refused
	var impulse_scale: float = 1.0 / (1.0 + float(age) * 0.25)
	var budget: float = 0.0
	for impulse: Vector2 in impulses:
		budget += impulse.length() * impulse_scale
	if not is_finite(budget):
		return refused
	if budget > impulse_cap:
		impulse_scale *= impulse_cap / budget
	var transform: Transform2D = PhysicsServer2D.body_get_state(
		_body_rids[body_index], PhysicsServer2D.BODY_STATE_TRANSFORM)
	if not transform.is_finite() or not (transform.origin + correction).is_finite():
		return refused
	for center: Vector2 in local_centers:
		if not (transform * center - transform.origin).is_finite():
			return refused
	_last_result_snapshot_serial = snapshot_serial
	_applied_sample_serials[body_index] = accepted_sample
	var velocity_before: Vector2 = body_linear_velocity(body_index)
	var correction_applied: bool = _apply_cellular_correction(body_index, correction)
	var velocity_after_zeroing: Vector2 = body_linear_velocity(body_index)
	transform.origin += correction if correction_applied else Vector2.ZERO
	var total_impulse := Vector2.ZERO
	var actual_impulse := Vector2.ZERO
	var actual_angular_impulse: float = 0.
	var applications: int = 0
	for proxy: int in range(count):
		var impulse: Vector2 = impulses[proxy] * impulse_scale
		total_impulse += impulse
		# Offset is the rectangle's actual rotated centre, relative to the one
		# body's COM. Rapier derives off-centre torque; no scripted angular motion.
		var offset: Vector2 = transform * local_centers[proxy] - transform.origin
		if _apply_cellular_impulse(body_index, impulse, offset):
			applications += 1
			actual_impulse += impulse
			actual_angular_impulse += offset.cross(impulse)
	if correction_applied or applications > 0:
		PhysicsServer2D.body_set_state(_body_rids[body_index], PhysicsServer2D.BODY_STATE_SLEEPING, false)
		refresh_all_states()
	return {"accepted":true, "outcome":"Accepted", "sample_serial":accepted_sample,
		"records":count, "contacts":contacts, "displaced":displaced, "unresolved":unresolved,
		"impulse_applications":applications, "correction_applications":int(correction_applied),
		"impulse":total_impulse, "correction":correction, "stale_records":0,
		"actual_impulse":actual_impulse,"actual_angular_impulse":actual_angular_impulse,"age":age,
		"velocity_before_correction":velocity_before,"velocity_after_zeroing":velocity_after_zeroing}


func _sample_age(sample_serial: int) -> int:
	var age: int = _sample_serial - sample_serial
	if age < 0:
		age += SAMPLE_SERIAL_LIMIT
	return age


func _reset_gcr_history() -> void:
	# Process-scoped, exact Float64 integers, never wrap. Outer worker epochs
	# still fence mailbox lifetime; this additionally fences fresh bridge objects.
	if _next_gcr_session_id >= CyberRigidBodyCoupling.GCR_MAX_SESSION:
		_gcr_session_id = 0
	else:
		_next_gcr_session_id += 1
		_gcr_session_id = _next_gcr_session_id
	if _gcr_sample_serials.is_empty():
		_gcr_sample_serials.resize(GCR_SAMPLE_HISTORY)
		_gcr_sample_poses.resize(GCR_SAMPLE_HISTORY * CyberRigidBodyCoupling.MAX_BODIES * GCR_SAMPLE_FIELDS)
	_gcr_sample_serials.fill(-1)
	_gcr_application_diagnostics.clear()
	_gcr_compound_centers.clear()
	_gcr_compound_sizes.clear()


func pack_gcr_body_states() -> PackedFloat64Array:
	# This is the one sample boundary for a GCR step. Callers choose this OR
	# pack_body_states(), never both. All backend reads remain on the main thread.
	var states := PackedFloat64Array()
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or not _initialized or _gcr_session_id == 0:
		return states
	states.resize(_body_rids.size() * CyberRigidBodyCoupling.GCR_INPUT_STRIDE)
	var next_serial: int = (_sample_serial + 1) % SAMPLE_SERIAL_LIMIT
	for index: int in range(_body_rids.size()):
		var direct: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(_body_rids[index])
		var inertia: float = float(PhysicsServer2D.body_get_param(_body_rids[index], PhysicsServer2D.BODY_PARAM_INERTIA))
		# Rapier v0.35.2 stores actual inertia in BODY_PARAM_INERTIA. Its direct
		# inverse-inertia cache can remain zero when both inertia and COM are
		# authored (mass_properties_changed skips the derived-cache update).
		if direct == null or inertia <= 0.0 or direct.inverse_mass <= 0.0 \
			or PhysicsServer2D.body_get_mode(_body_rids[index]) != PhysicsServer2D.BODY_MODE_RIGID:
			return PackedFloat64Array() # Locked/unknown inertia is explicitly unsupported.
		var transform: Transform2D = direct.transform
		var com: Vector2 = transform * direct.center_of_mass_local
		var fields: Array = [float(index + 1), transform.origin.x, transform.origin.y,
			transform.get_rotation(), _body_sizes[index].x, _body_sizes[index].y,
			direct.linear_velocity.x, direct.linear_velocity.y, direct.angular_velocity,
			1.0 / direct.inverse_mass, float(next_serial), inertia,
			com.x, com.y, float(PhysicsServer2D.body_get_param(_body_rids[index], PhysicsServer2D.BODY_PARAM_FRICTION)), fixed_delta(), float(_gcr_session_id)]
		for field: int in range(CyberRigidBodyCoupling.GCR_INPUT_STRIDE):
			if not is_finite(float(fields[field])):
				return PackedFloat64Array()
			states[index * CyberRigidBodyCoupling.GCR_INPUT_STRIDE + field] = float(fields[field])
		if float(fields[CyberRigidBodyCoupling.GCR_INPUT_FRICTION]) < 0.0:
			return PackedFloat64Array()
	if _gcr_sample_serials.is_empty():
		_reset_gcr_history()
	_sample_serial = next_serial
	var slot: int = next_serial % GCR_SAMPLE_HISTORY
	_gcr_sample_serials[slot] = next_serial
	for index: int in range(_body_rids.size()):
		var offset: int = index * CyberRigidBodyCoupling.GCR_INPUT_STRIDE
		var history_offset: int = (slot * CyberRigidBodyCoupling.MAX_BODIES + index) * GCR_SAMPLE_FIELDS
		for field: int in range(3):
			_gcr_sample_poses[history_offset + field] = states[offset + 1 + field]
		_gcr_sample_poses[history_offset + 3] = states[offset + CyberRigidBodyCoupling.GCR_INPUT_COM_X]
		_gcr_sample_poses[history_offset + 4] = states[offset + CyberRigidBodyCoupling.GCR_INPUT_COM_Y]
	return states


func pack_gcr_compound_states(local_centers: PackedVector2Array, sizes: PackedVector2Array) -> PackedFloat64Array:
	if _body_rids.size()!=1 or local_centers.is_empty() or local_centers.size()>64 or sizes.size()!=local_centers.size(): return PackedFloat64Array()
	for i: int in range(sizes.size()):
		if not local_centers[i].is_finite() or not sizes[i].is_finite() or sizes[i].x<=0. or sizes[i].y<=0.: return PackedFloat64Array()
	if not _gcr_compound_centers.is_empty() and (local_centers!=_gcr_compound_centers or sizes!=_gcr_compound_sizes): return PackedFloat64Array()
	# Mask priming samples the finalized but still frozen body. Its authored
	# mass/inertia remain real; inverse_mass is zero while staging is static.
	if OS.get_thread_caller_id()!=OS.get_main_thread_id() or not _initialized or _gcr_session_id==0: return PackedFloat64Array()
	var rid: RID = _body_rids[0]
	var direct: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(rid)
	if direct==null: return PackedFloat64Array()
	var pose: Transform2D = direct.transform
	var com: Vector2 = pose*direct.center_of_mass_local
	var mass: float = PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_MASS)
	var inertia: float = PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_INERTIA)
	if mass<=0. or inertia<=0.: return PackedFloat64Array()
	_sample_serial=(_sample_serial+1)%SAMPLE_SERIAL_LIMIT
	var common := PackedFloat64Array([1.,pose.origin.x,pose.origin.y,pose.get_rotation(),1.,1.,
		direct.linear_velocity.x,direct.linear_velocity.y,direct.angular_velocity,mass,float(_sample_serial),inertia,
		com.x,com.y,PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_FRICTION),fixed_delta(),float(_gcr_session_id)])
	for value: float in common:
		if not is_finite(value): return PackedFloat64Array()
	var slot: int = _sample_serial%GCR_SAMPLE_HISTORY
	_gcr_sample_serials[slot]=_sample_serial
	var history: int = slot*CyberRigidBodyCoupling.MAX_BODIES*GCR_SAMPLE_FIELDS
	_gcr_sample_poses[history]=pose.origin.x
	_gcr_sample_poses[history+1]=pose.origin.y
	_gcr_sample_poses[history+2]=pose.get_rotation()
	_gcr_sample_poses[history+3]=com.x
	_gcr_sample_poses[history+4]=com.y
	_gcr_compound_centers = local_centers.duplicate()
	_gcr_compound_sizes = sizes.duplicate()
	var transform: Transform2D = pose
	var result := PackedFloat64Array()
	for i: int in range(sizes.size()):
		var row := common.duplicate()
		var centre: Vector2 = transform*local_centers[i]
		row[0]=i+1
		row[1]=centre.x
		row[2]=centre.y
		row[4]=sizes[i].x
		row[5]=sizes[i].y
		result.append_array(row)
	return result

func apply_gcr_compound_results(snapshot_serial: int, results: PackedFloat64Array) -> int:
	return _apply_gcr_results(snapshot_serial,results,true)

func gcr_application_diagnostics() -> Dictionary:
	return _gcr_application_diagnostics.duplicate(true)


func _refuse_gcr(reason: String, received: int) -> int:
	_last_stale_results_rejected = received
	_gcr_application_diagnostics["accepted"] = false
	_gcr_application_diagnostics["refusal"] = reason
	if not diagnostic_applications.is_empty():
		for index: int in range(_body_rids.size()):
			diagnostic_applications[index * 6 + (3 if reason == "duplicate" else 4)] = 1.0
	return 0


func apply_gcr_results(snapshot_serial: int, results: PackedFloat64Array) -> int:
	return _apply_gcr_results(snapshot_serial,results,false)

func _apply_gcr_results(snapshot_serial: int, results: PackedFloat64Array, compound: bool) -> int:
	_last_results_applied = 0
	_last_stale_results_rejected = 0
	_gcr_application_diagnostics = {"accepted": false, "refusal": "", "snapshot": snapshot_serial, "bodies": []}
	if not diagnostic_applications.is_empty():
		diagnostic_applications.fill(0.0)
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or not _initialized:
		return _refuse_gcr("owner", 0)
	if snapshot_serial < 0 or snapshot_serial <= _last_result_snapshot_serial:
		return _refuse_gcr("duplicate", 0)
	var stride: int = CyberRigidBodyCoupling.GCR_RESULT_STRIDE
	if results.is_empty() or results.size() % stride != 0 or results.size() > CyberRigidBodyCoupling.MAX_BODIES * stride:
		return _refuse_gcr("layout", 0)
	var count: int = results.size() / stride
	if compound:
		if count!=1 or _body_rids.size()!=1 or _gcr_compound_centers.is_empty() or results[0]!=1. or results[12]!=2.: return _refuse_gcr("compound_layout",count)
		# Version2 is accepted only by this explicit physical-owner route.
		results = results.duplicate()
		results[12] = 1.
	var seen: Dictionary = {}
	var applications: Array[Dictionary] = []
	# Prevalidate the complete batch before correction, velocity changes, impulse,
	# wake or serial tracking. A malformed last row cannot partially apply it.
	for record: int in range(count):
		var offset: int = record * stride
		if not CyberRigidBodyCoupling.gcr_result_record_valid(results, offset):
			return _refuse_gcr("record", count)
		if _gcr_session_id == 0 or int(results[offset + CyberRigidBodyCoupling.GCR_RESULT_SESSION]) != _gcr_session_id:
			return _refuse_gcr("session", count)
		var index: int = int(results[offset + CyberRigidBodyCoupling.RESULT_BODY_ID]) - 1
		if index >= _body_rids.size() or seen.has(index):
			return _refuse_gcr("body", count)
		seen[index] = true
		var serial: int = int(results[offset + CyberRigidBodyCoupling.RESULT_SAMPLE_SERIAL])
		if serial >= SAMPLE_SERIAL_LIMIT:
			return _refuse_gcr("sample", count)
		var previous: int = _applied_sample_serials[index]
		var forward: int = (serial - previous + SAMPLE_SERIAL_LIMIT) % SAMPLE_SERIAL_LIMIT
		if previous >= 0 and (forward == 0 or forward > SAMPLE_SERIAL_LIMIT / 2):
			return _refuse_gcr("duplicate", count)
		var age: int = _sample_age(serial)
		var observation: Dictionary = {"index":index, "sample":serial, "session":_gcr_session_id, "age":age}
		_gcr_application_diagnostics.bodies.append(observation)
		if not diagnostic_applications.is_empty():
			diagnostic_applications[index * 6] = age
			diagnostic_applications[index * 6 + 5] = 1.0
		if age > MAX_CELLULAR_RESULT_AGE_TICKS:
			return _refuse_gcr("age", count)
		var slot: int = serial % GCR_SAMPLE_HISTORY
		if _gcr_sample_serials.is_empty() or _gcr_sample_serials[slot] != serial:
			return _refuse_gcr("sample", count)
		var history_offset: int = (slot * CyberRigidBodyCoupling.MAX_BODIES + index) * GCR_SAMPLE_FIELDS
		var sampled_origin := Vector2(_gcr_sample_poses[history_offset], _gcr_sample_poses[history_offset + 1])
		var sampled_rotation: float = _gcr_sample_poses[history_offset + 2]
		var sampled_com := Vector2(_gcr_sample_poses[history_offset + 3], _gcr_sample_poses[history_offset + 4])
		var echoed_com := Vector2(results[offset + CyberRigidBodyCoupling.GCR_RESULT_COM_X], results[offset + CyberRigidBodyCoupling.GCR_RESULT_COM_Y])
		if sampled_com != echoed_com:
			return _refuse_gcr("com", count)
		var direct: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(_body_rids[index])
		if direct == null:
			return _refuse_gcr("body", count)
		var current: Transform2D = direct.transform
		var current_com: Vector2 = current * direct.center_of_mass_local
		if not current.origin.is_finite() or not current_com.is_finite() or not is_finite(current.get_rotation()):
			return _refuse_gcr("body", count)
		observation.merge({"sampled_com":sampled_com, "current_com":current_com,
			"sampled_origin":sampled_origin, "sampled_rotation":sampled_rotation,
			"current_origin":current.origin, "current_rotation":current.get_rotation()})
		# Maximum displacement of the actual rectangle's four corners includes
		# rotation and COM offsets. Convexity bounds every face contact between them.
		var contact_displacement: float = 0.0
		for proxy: int in range(_gcr_compound_centers.size() if compound else 1):
			var centre: Vector2 = _gcr_compound_centers[proxy] if compound else Vector2.ZERO
			var size: Vector2 = _gcr_compound_sizes[proxy] if compound else _body_sizes[index]
			for sign_x: float in [-1.0,1.0]:
				for sign_y: float in [-1.0,1.0]:
					var corner: Vector2 = centre+size*Vector2(sign_x,sign_y)*.5
					contact_displacement=maxf(contact_displacement,(current*corner).distance_to(sampled_origin+corner.rotated(sampled_rotation)))
		observation["contact_displacement"] = contact_displacement
		if age > GCR_MAX_RESULT_AGE_TICKS:
			return _refuse_gcr("age", count)
		if contact_displacement > GCR_MAX_CONTACT_DISPLACEMENT:
			return _refuse_gcr("geometry", count)
		var correction := Vector2(results[offset + CyberRigidBodyCoupling.RESULT_CORRECTION_X], results[offset + CyberRigidBodyCoupling.RESULT_CORRECTION_Y])
		if age > MAX_POSITIONAL_CORRECTION_AGE_TICKS:
			correction = Vector2.ZERO
		if correction.length_squared() <= MOTION_EPSILON_SQUARED:
			correction = Vector2.ZERO
		var impulse := Vector2(results[offset + CyberRigidBodyCoupling.RESULT_IMPULSE_X], results[offset + CyberRigidBodyCoupling.RESULT_IMPULSE_Y])
		var angular_sample: float = results[offset + CyberRigidBodyCoupling.GCR_RESULT_ANGULAR_IMPULSE]
		# Translate the world-space wrench to the COM at application, including
		# separate positional correction; then apply one common age scale to J/L.
		var angular_current: float = angular_sample + (sampled_com - current_com - correction).cross(impulse)
		var scale: float = 1.0 / (1.0 + float(age) * 0.25)
		if not is_finite(angular_current) or not (impulse * scale).is_finite():
			return _refuse_gcr("wrench", count)
		observation.merge({"correction":correction, "impulse":impulse * scale, "sampled_angular_impulse":angular_sample,
			"translated_angular_impulse":angular_current, "angular_impulse":angular_current * scale})
		applications.append(observation)
	_last_result_snapshot_serial = snapshot_serial
	for application: Dictionary in applications:
		var index: int = application.index
		var rid: RID = _body_rids[index]
		_applied_sample_serials[index] = int(application.sample)
		var correction: Vector2 = application.correction
		var impulse: Vector2 = application.impulse
		var angular: float = application.angular_impulse
		var velocity_before: Vector2 = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		if correction.length_squared() > MOTION_EPSILON_SQUARED:
			var transform: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
			transform.origin += correction
			PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, transform)
			_transforms[index] = transform
			var velocity: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			if correction.x != 0.0 and velocity.x * correction.x < 0.0: velocity.x = 0.0
			if correction.y != 0.0 and velocity.y * correction.y < 0.0: velocity.y = 0.0
			PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)
		if compound:
			application["velocity_before_correction"] = velocity_before
			application["velocity_after_zeroing"] = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			application["correction_applied"] = correction!=Vector2.ZERO
			application["physical_wrench_applications"] = 1 if impulse!=Vector2.ZERO or angular!=0. else 0
		# One J/L pair. No second application through the central-only legacy law.
		if impulse != Vector2.ZERO:
			PhysicsServer2D.body_apply_central_impulse(rid, impulse)
		if angular != 0.0:
			PhysicsServer2D.body_apply_torque_impulse(rid, angular)
		if correction != Vector2.ZERO or impulse != Vector2.ZERO or angular != 0.0:
			PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, false)
			_last_results_applied += 1
		if not diagnostic_applications.is_empty():
			diagnostic_applications[index * 6 + 1] = impulse.x
			diagnostic_applications[index * 6 + 2] = impulse.y
	_gcr_application_diagnostics["accepted"] = true
	_gcr_application_diagnostics["bodies"] = applications
	return _last_results_applied


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
	if material_id >= CyberCellWorld.LIMESTONE_BLOCK and material_id <= CyberCellWorld.LAST_MATERIAL:
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
	ClassDB.class_call_static(EXPECTED_SERVER_CLASS, &"space_step", _space, fixed_delta())
	_last_step_time_ms = float(Time.get_ticks_usec() - step_start_usec) / 1000.0
	_manual_step_count += 1

	# Rapier exposes an active-body batch path, avoiding stale scene-node caches
	# and preparing the bridge for a larger dynamic-body count.
	var active_body_rids: Array = ClassDB.class_call_static(EXPECTED_SERVER_CLASS, &"space_get_active_bodies", _space)
	var active_transforms: Array = ClassDB.class_call_static(
		EXPECTED_SERVER_CLASS, &"space_get_bodies_transform",
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
	ClassDB.class_call_static(EXPECTED_SERVER_CLASS, &"space_flush_queries", _space)
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


func body_linear_velocity(body_index: int) -> Vector2:
	if not _initialized or body_index < 0 or body_index >= _body_rids.size():
		return Vector2.ZERO
	return PhysicsServer2D.body_get_state(
		_body_rids[body_index],
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY
	)


func apply_horizontal_control(
	body_index: int,
	horizontal_input: float,
	target_speed: float,
	acceleration: float,
	maximum_impulse: float,
	delta: float
) -> float:
	if (
		not _initialized
		or body_index < 0
		or body_index >= _body_rids.size()
		or not is_finite(horizontal_input)
		or not is_finite(target_speed)
		or not is_finite(acceleration)
		or not is_finite(maximum_impulse)
		or not is_finite(delta)
		or target_speed < 0.0
		or acceleration < 0.0
		or maximum_impulse < 0.0
		or delta < 0.0
	):
		return 0.0

	# PCHAR-001 deliberately does not brake a body when there is no movement
	# input. Existing Rapier damping and cellular reaction remain observable.
	var bounded_input: float = clampf(horizontal_input, -1.0, 1.0)
	if absf(bounded_input) < 0.001:
		return 0.0

	# Read live server state after any cellular result application. This avoids
	# assigning a cached target velocity over incoming displacement/contact
	# impulses. Only a bounded horizontal central impulse is added.
	var current_velocity: Vector2 = body_linear_velocity(body_index)
	var requested_velocity_x: float = bounded_input * target_speed
	var max_delta_velocity: float = acceleration * delta
	var delta_velocity_x: float = clampf(
		requested_velocity_x - current_velocity.x,
		-max_delta_velocity,
		max_delta_velocity
	)
	var impulse_x: float = clampf(
		delta_velocity_x * _body_masses[body_index],
		-maximum_impulse,
		maximum_impulse
	)
	if absf(impulse_x) <= 0.000001:
		return 0.0

	PhysicsServer2D.body_apply_central_impulse(
		_body_rids[body_index],
		Vector2(impulse_x, 0.0)
	)
	PhysicsServer2D.body_set_state(
		_body_rids[body_index],
		PhysicsServer2D.BODY_STATE_SLEEPING,
		false
	)
	return impulse_x


func apply_trial_impulses(body_index: int, impulse: Vector2, angular_impulse: float) -> bool:
	# Experimental player actuation; same live body and main-thread owner as
	# ordinary coupling. Never overwrite transforms or incoming contact velocity.
	if not _initialized or body_index < 0 or body_index >= _body_rids.size(): return false
	if not impulse.is_finite() or not is_finite(angular_impulse): return false
	var rid: RID = _body_rids[body_index]
	PhysicsServer2D.body_apply_central_impulse(rid, impulse.limit_length(24.0))
	PhysicsServer2D.body_apply_torque_impulse(rid, clampf(angular_impulse, -0.2, 0.2))
	if impulse.length_squared() > 0.0 or angular_impulse != 0.0:
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, false)
	return true


func reset_body(
	body_index: int,
	position: Vector2,
	rotation: float
) -> void:
	if not _initialized or body_index < 0 or body_index >= _body_rids.size():
		return
	_reset_gcr_history()
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
	_reset_gcr_history()


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
	_reset_gcr_history()
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
