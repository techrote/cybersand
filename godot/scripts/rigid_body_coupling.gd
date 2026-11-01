class_name CyberRigidBodyCoupling
extends RefCounted

# Prototype value-data bridge between scene-tree RigidBody2D nodes and the
# cellular worker. No Node, RID, PhysicsDirectBodyState2D, or other live Godot
# physics object crosses the thread boundary.
# Eight actors with up to eight rectangular Rapier parts; the float ABI stays
# compatible with the original barrel fixtures.
const MAX_BODIES: int = 64
const MAX_SAMPLE_SERIAL: int = 16777215

const INPUT_BODY_ID: int = 0
const INPUT_CENTER_X: int = 1
const INPUT_CENTER_Y: int = 2
const INPUT_ROTATION: int = 3
const INPUT_SIZE_X: int = 4
const INPUT_SIZE_Y: int = 5
const INPUT_VELOCITY_X: int = 6
const INPUT_VELOCITY_Y: int = 7
const INPUT_ANGULAR_VELOCITY: int = 8
const INPUT_MASS: int = 9
const INPUT_SAMPLE_SERIAL: int = 10
const INPUT_STRIDE: int = 11

const RESULT_BODY_ID: int = 0
const RESULT_IMPULSE_X: int = 1
const RESULT_IMPULSE_Y: int = 2
const RESULT_CORRECTION_X: int = 3
const RESULT_CORRECTION_Y: int = 4
const RESULT_CONTACT_COUNT: int = 5
const RESULT_DISPLACED_COUNT: int = 6
const RESULT_UNRESOLVED_COUNT: int = 7
const RESULT_SAMPLE_SERIAL: int = 8
const RESULT_STRIDE: int = 9

# GCR-001 is an opt-in versioned Float64 protocol. The old 11/9 Float32
# records above retain their original meanings and consumer path.
const GCR_POLICY_VERSION: int = 1
const GCR_INPUT_INERTIA: int = 11
const GCR_INPUT_COM_X: int = 12
const GCR_INPUT_COM_Y: int = 13
const GCR_INPUT_FRICTION: int = 14
const GCR_INPUT_DELTA: int = 15
const GCR_INPUT_SESSION: int = 16
const GCR_INPUT_STRIDE: int = 17
const GCR_RESULT_ANGULAR_IMPULSE: int = 9
const GCR_RESULT_COM_X: int = 10
const GCR_RESULT_COM_Y: int = 11
const GCR_RESULT_VERSION: int = 12
const GCR_RESULT_SESSION: int = 13
const GCR_RESULT_STRIDE: int = 14
const GCR_MAX_SESSION: int = 9007199254740991


static func gcr_result_record_valid(results: PackedFloat64Array, offset: int) -> bool:
	if offset < 0 or offset + GCR_RESULT_STRIDE > results.size():
		return false
	for field: int in range(GCR_RESULT_STRIDE):
		if not is_finite(results[offset + field]):
			return false
	var body_id: float = results[offset + RESULT_BODY_ID]
	var serial: float = results[offset + RESULT_SAMPLE_SERIAL]
	var session: float = results[offset + GCR_RESULT_SESSION]
	if body_id < 1.0 or body_id > MAX_BODIES or floorf(body_id) != body_id \
		or serial < 0.0 or serial > MAX_SAMPLE_SERIAL or floorf(serial) != serial \
		or results[offset + GCR_RESULT_VERSION] != GCR_POLICY_VERSION:
		return false
	if session < 1.0 or session > float(GCR_MAX_SESSION) or floorf(session) != session:
		return false
	for field: int in [RESULT_CONTACT_COUNT, RESULT_DISPLACED_COUNT, RESULT_UNRESOLVED_COUNT]:
		var count: float = results[offset + field]
		if count < 0.0 or floorf(count) != count:
			return false
	return true


static func append_input(
	states: PackedFloat32Array,
	body_id: int,
	center: Vector2,
	rotation: float,
	size: Vector2,
	linear_velocity: Vector2,
	angular_velocity: float,
	mass: float,
	sample_serial: int
) -> void:
	states.append(float(body_id))
	states.append(center.x)
	states.append(center.y)
	states.append(rotation)
	states.append(size.x)
	states.append(size.y)
	states.append(linear_velocity.x)
	states.append(linear_velocity.y)
	states.append(angular_velocity)
	states.append(mass)
	states.append(float(sample_serial))


static func input_body_count(states: PackedFloat32Array) -> int:
	return mini(
		MAX_BODIES,
		floori(float(states.size()) / float(INPUT_STRIDE))
	)


static func input_record_valid(states: PackedFloat32Array, offset: int) -> bool:
	if offset < 0 or offset + INPUT_STRIDE > states.size():
		return false
	for field: int in range(INPUT_STRIDE):
		if not is_finite(states[offset + field]):
			return false
	var body_id: float = states[offset + INPUT_BODY_ID]
	var serial: float = states[offset + INPUT_SAMPLE_SERIAL]
	return (
		body_id >= 1.0 and body_id <= float(MAX_BODIES)
		and floorf(body_id) == body_id
		and serial >= 0.0 and serial <= float(MAX_SAMPLE_SERIAL)
		and floorf(serial) == serial
		and states[offset + INPUT_SIZE_X] > 0.0
		and states[offset + INPUT_SIZE_Y] > 0.0
		and states[offset + INPUT_MASS] > 0.0
	)


static func result_body_count(results: PackedFloat32Array) -> int:
	return mini(
		MAX_BODIES,
		floori(float(results.size()) / float(RESULT_STRIDE))
	)
