class_name CyberRigidBodyCoupling
extends RefCounted

# Prototype value-data bridge between scene-tree RigidBody2D nodes and the
# cellular worker. No Node, RID, PhysicsDirectBodyState2D, or other live Godot
# physics object crosses the thread boundary.
const MAX_BODIES: int = 16

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


static func result_body_count(results: PackedFloat32Array) -> int:
	return mini(
		MAX_BODIES,
		floori(float(results.size()) / float(RESULT_STRIDE))
	)
