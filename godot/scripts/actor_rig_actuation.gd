class_name CyberActorRigActuation
extends RefCounted

# Pure owner-local actuator mapping. No World, input device, controller, target
# velocity/heading, scene tree, or model-service access belongs in this layer.
# Forces use authored game mass * cells/s^2; torque uses game inertia * rad/s^2.
# These parameters do not add Rapier mass or force feedback to a sampled actor.
const VERSION: int = 1
const OBSERVATION_SIZE: int = 32
const PROFILE_IDS: Array[StringName] = [&"ripper-metal-v1", &"copter-metal-v1", &"gemini-metal-v1"]
const ACTIVE: int = 1
const INPUT_CLAMPED: int = 2
const RESOURCE_LIMITED: int = 4
const CONTACT_LIMITED: int = 8
const MOTION_LIMITED: int = 16
const COLLISION_CONSTRAINED: int = 32
const DELTA_CLAMPED: int = 64
const BLOCKED: int = 128
const INVALID: int = 256
const UNSUPPORTED: int = 512
const GRAVITY: float = 156.0
const AIR_DRAG: float = 0.08
const ANGULAR_DRAG: float = 0.18
const RIPPER_MASS: float = 2.0
const RIPPER_INERTIA: float = 100.0 / 3.0
const RIPPER_DRIVE_FORCE: float = 600.0
const RIPPER_TORQUE: float = 800.0
const RIPPER_ROLLING_DRAG: float = 1.2
const RIPPER_CONTACT_ANGULAR_DRAG: float = 0.55
const RIPPER_BRAKE_DRAG: float = 18.0
const RIPPER_BRAKE_ANGULAR_DRAG: float = 8.0
const FLIGHT_MASS: float = 1.0
const FLIGHT_INERTIA: float = 52.0 / 3.0
const COPTER_COLLECTIVE_FORCE: float = 312.0
const COPTER_LATERAL_FORCE: float = 84.0
const COPTER_TORQUE: float = 416.0
const COPTER_BRAKE_DRAG: float = 10.0
const GEMINI_THRUSTER_FORCE: float = 156.0
const GEMINI_THRUSTER_ARM: float = 4.0

var model_id: StringName = &""
var profile_index: int = 0
var mass: float = 1.0
var inertia: float = 1.0
var requested_actuators: Vector4 = Vector4.ZERO
var applied_actuators: Vector4 = Vector4.ZERO
var requested_force: Vector2 = Vector2.ZERO
var requested_torque: float = 0.0
var applied_force: Vector2 = Vector2.ZERO
var applied_torque: float = 0.0
var passive_force: Vector2 = Vector2.ZERO
var passive_torque: float = 0.0
var delta_velocity: Vector2 = Vector2.ZERO
var delta_angular_velocity: float = 0.0
var delta_position: Vector2 = Vector2.ZERO
var delta_rotation: float = 0.0
var resource_scale: float = 0.0
var energy_used: float = 0.0
var contact_scale: float = 0.0
var consumed_delta: float = 0.0
var remaining_energy: float = 0.0
var flags: int = 0
var power_demand: bool = false


static func supports_model(candidate: StringName) -> bool:
	return candidate == &"ripper" or candidate == &"copter" or candidate == &"gemini"


static func profile_id_for(candidate: StringName) -> StringName:
	match candidate:
		&"ripper": return &"ripper-metal-v1"
		&"copter": return &"copter-metal-v1"
		&"gemini": return &"gemini-metal-v1"
	return &""


static func valid_command(candidate: StringName, command: Vector4) -> bool:
	if not supports_model(candidate) or not command.is_finite():
		return false
	if candidate == &"ripper":
		return command.w == 0.0
	if candidate == &"gemini":
		return command.z == 0.0 and command.w == 0.0
	return true


static func clamp_command(candidate: StringName, command: Vector4) -> Vector4:
	if not valid_command(candidate, command):
		return Vector4.ZERO
	match candidate:
		&"ripper":
			return Vector4(clampf(command.x, -1.0, 1.0), clampf(command.y, -1.0, 1.0),
				clampf(command.z, 0.0, 1.0), 0.0)
		&"copter":
			return Vector4(clampf(command.x, 0.0, 1.0), clampf(command.y, -1.0, 1.0),
				clampf(command.z, -1.0, 1.0), clampf(command.w, 0.0, 1.0))
		&"gemini":
			return Vector4(clampf(command.x, 0.0, 1.0), clampf(command.y, 0.0, 1.0), 0.0, 0.0)
	return Vector4.ZERO


static func profile(candidate: StringName) -> Dictionary:
	if not supports_model(candidate):
		return {}
	var result: Dictionary = {
		"version": VERSION, "profile_id": str(profile_id_for(candidate)),
		"rig_id": str(candidate), "command_size": 4, "observation_size": OBSERVATION_SIZE,
		"force_units": "game-mass*cell/s^2", "torque_units": "game-inertia*rad/s^2",
		"force_frame": "world", "integration": "delta-v=force/mass*dt; delta-omega=torque/inertia*dt",
		"applied_semantics": "actuator wrench after resource/contact limits, before collision/caps",
		"motion_semantics": "actual post-collision delta-v, delta-omega and centre/angle displacement",
		"resource_semantics": "proportional power scaling; held powered demand does not recharge at zero energy",
		"brake_semantics": "commanded dissipative drag; no heading or velocity target; no energy cost",
		"idle_recharge_ground": 0.30, "idle_recharge_air": 0.14,
		"gravity": GRAVITY, "air_drag_per_second": AIR_DRAG,
		"angular_drag_per_second": ANGULAR_DRAG,
		"rigid_body_force_feedback": false, "terrain_tools": false,
		"observation_fields": [
			"requested_u0", "requested_u1", "requested_u2", "requested_u3",
			"applied_u0", "applied_u1", "applied_u2", "applied_u3",
			"requested_fx", "requested_fy", "requested_torque",
			"applied_fx", "applied_fy", "applied_torque",
			"passive_fx", "passive_fy", "passive_torque",
			"delta_vx", "delta_vy", "delta_omega", "mass", "inertia",
			"resource_scale", "energy_used", "contact_scale", "consumed_dt",
			"centre_delta_x", "centre_delta_y", "rotation_delta", "flags", "profile_index", "energy",
		],
		"flags": {"active": ACTIVE, "input_clamped": INPUT_CLAMPED,
			"resource_limited": RESOURCE_LIMITED, "contact_limited": CONTACT_LIMITED,
			"motion_limited": MOTION_LIMITED, "collision_constrained": COLLISION_CONSTRAINED,
			"delta_clamped": DELTA_CLAMPED, "blocked": BLOCKED,
			"invalid": INVALID, "unsupported": UNSUPPORTED},
	}
	match candidate:
		&"ripper":
			result.merge({"profile_index": 1, "channels": ["track_drive", "chassis_torque", "track_brake", "reserved"],
				"minimum": [-1.0, -1.0, 0.0, 0.0], "maximum": [1.0, 1.0, 1.0, 0.0],
				"mass": RIPPER_MASS, "inertia": RIPPER_INERTIA,
				"drive_force": RIPPER_DRIVE_FORCE, "torque_gain": RIPPER_TORQUE,
				"rolling_drag_per_second": RIPPER_ROLLING_DRAG,
				"contact_angular_drag_per_second": RIPPER_CONTACT_ANGULAR_DRAG,
				"brake_drag_per_second": RIPPER_BRAKE_DRAG,
				"brake_angular_drag_per_second": RIPPER_BRAKE_ANGULAR_DRAG,
				"energy_rate": [0.14, 0.09, 0.0, 0.0],
				"contact_law": "supported*max(cos(rotation),0); drive projects onto horizontal floor tangent; no air traction",
				"reserved_zero_required": [3]})
		&"copter":
			result.merge({"profile_index": 2, "channels": ["collective", "lateral_cyclic", "rotor_torque", "rotor_brake"],
				"minimum": [0.0, -1.0, -1.0, 0.0], "maximum": [1.0, 1.0, 1.0, 1.0],
				"mass": FLIGHT_MASS, "inertia": FLIGHT_INERTIA,
				"collective_force": COPTER_COLLECTIVE_FORCE, "lateral_force": COPTER_LATERAL_FORCE,
				"torque_gain": COPTER_TORQUE, "brake_angular_drag_per_second": COPTER_BRAKE_DRAG,
				"energy_rate": [0.24, 0.08, 0.07, 0.0], "reserved_zero_required": []})
		&"gemini":
			result.merge({"profile_index": 3, "channels": ["left_thruster", "right_thruster", "reserved", "reserved"],
				"minimum": [0.0, 0.0, 0.0, 0.0], "maximum": [1.0, 1.0, 0.0, 0.0],
				"mass": FLIGHT_MASS, "inertia": FLIGHT_INERTIA,
				"thruster_force": GEMINI_THRUSTER_FORCE, "thruster_arm": GEMINI_THRUSTER_ARM,
				"energy_rate": [0.14, 0.14, 0.0, 0.0], "reserved_zero_required": [2, 3]})
	return result


func configure_model(candidate: StringName) -> bool:
	model_id = candidate if supports_model(candidate) else &""
	profile_index = 0
	mass = 1.0
	inertia = 1.0
	match model_id:
		&"ripper":
			profile_index = 1
			mass = RIPPER_MASS
			inertia = RIPPER_INERTIA
		&"copter":
			profile_index = 2
			mass = FLIGHT_MASS
			inertia = FLIGHT_INERTIA
		&"gemini":
			profile_index = 3
			mass = FLIGHT_MASS
			inertia = FLIGHT_INERTIA
	clear_output()
	return profile_index != 0


func clear_output() -> void:
	requested_actuators = Vector4.ZERO
	applied_actuators = Vector4.ZERO
	requested_force = Vector2.ZERO
	requested_torque = 0.0
	applied_force = Vector2.ZERO
	applied_torque = 0.0
	passive_force = Vector2.ZERO
	passive_torque = 0.0
	delta_velocity = Vector2.ZERO
	delta_angular_velocity = 0.0
	delta_position = Vector2.ZERO
	delta_rotation = 0.0
	resource_scale = 0.0
	energy_used = 0.0
	contact_scale = 0.0
	consumed_delta = 0.0
	remaining_energy = 0.0
	flags = 0
	power_demand = false


func solve(command: Vector4, delta: float, angle: float, velocity: Vector2,
		angular_velocity: float, supported: bool, available_energy: float) -> void:
	# Inputs have been validated and current state bounded by the motor. Every
	# operation is scalar/value arithmetic; the helper performs no allocations
	# proportional to world size and makes no collision/material queries.
	requested_actuators = clamp_command(model_id, command)
	flags |= ACTIVE
	if requested_actuators != command:
		flags |= INPUT_CLAMPED
	consumed_delta = delta
	contact_scale = 1.0
	var rate: float = 0.0
	match model_id:
		&"ripper": rate = absf(requested_actuators.x) * 0.14 + absf(requested_actuators.y) * 0.09
		&"copter": rate = requested_actuators.x * 0.24 + absf(requested_actuators.y) * 0.08 + absf(requested_actuators.z) * 0.07
		&"gemini": rate = (requested_actuators.x + requested_actuators.y) * 0.14
	power_demand = rate > 0.0
	var requested_energy: float = rate * delta
	resource_scale = minf(1.0, available_energy / requested_energy) if requested_energy > 0.0 else 1.0
	energy_used = requested_energy * resource_scale
	remaining_energy = maxf(0.0, available_energy - energy_used)
	if resource_scale < 1.0:
		flags |= RESOURCE_LIMITED
	applied_actuators = requested_actuators * resource_scale
	passive_force = Vector2(-velocity.x * mass * AIR_DRAG, mass * GRAVITY - velocity.y * mass * AIR_DRAG)
	passive_torque = -angular_velocity * inertia * ANGULAR_DRAG
	match model_id:
		&"ripper":
			contact_scale = maxf(0.0, cos(angle)) if supported else 0.0
			var drive: Vector2 = Vector2(requested_actuators.x * RIPPER_DRIVE_FORCE, 0.0).rotated(angle)
			var brake_force: float = -velocity.x * mass * RIPPER_BRAKE_DRAG * requested_actuators.z
			var brake_torque: float = -angular_velocity * inertia * RIPPER_BRAKE_ANGULAR_DRAG * requested_actuators.z
			requested_force = drive + Vector2(brake_force, 0.0)
			requested_torque = requested_actuators.y * RIPPER_TORQUE + brake_torque
			applied_actuators.x *= contact_scale
			applied_actuators.z = requested_actuators.z * contact_scale
			applied_force = Vector2((drive.x * resource_scale + brake_force) * contact_scale, 0.0)
			applied_torque = requested_actuators.y * RIPPER_TORQUE * resource_scale + brake_torque * contact_scale
			if contact_scale < 1.0 and (requested_actuators.x != 0.0 or requested_actuators.z != 0.0):
				flags |= CONTACT_LIMITED
			if supported:
				passive_force.x -= velocity.x * mass * RIPPER_ROLLING_DRAG
				passive_torque -= angular_velocity * inertia * RIPPER_CONTACT_ANGULAR_DRAG
		&"copter":
			requested_force = Vector2(requested_actuators.y * COPTER_LATERAL_FORCE,
				-requested_actuators.x * COPTER_COLLECTIVE_FORCE).rotated(angle)
			var brake_torque: float = -angular_velocity * inertia * COPTER_BRAKE_DRAG * requested_actuators.w
			requested_torque = requested_actuators.z * COPTER_TORQUE + brake_torque
			applied_actuators.w = requested_actuators.w
			applied_force = requested_force * resource_scale
			applied_torque = requested_actuators.z * COPTER_TORQUE * resource_scale + brake_torque
		&"gemini":
			requested_force = Vector2(0.0, -(requested_actuators.x + requested_actuators.y) * GEMINI_THRUSTER_FORCE).rotated(angle)
			requested_torque = (requested_actuators.x - requested_actuators.y) * GEMINI_THRUSTER_FORCE * GEMINI_THRUSTER_ARM
			applied_force = requested_force * resource_scale
			applied_torque = requested_torque * resource_scale


func observation() -> PackedFloat32Array:
	return PackedFloat32Array([
		requested_actuators.x, requested_actuators.y, requested_actuators.z, requested_actuators.w,
		applied_actuators.x, applied_actuators.y, applied_actuators.z, applied_actuators.w,
		requested_force.x, requested_force.y, requested_torque,
		applied_force.x, applied_force.y, applied_torque,
		passive_force.x, passive_force.y, passive_torque,
		delta_velocity.x, delta_velocity.y, delta_angular_velocity, mass, inertia,
		resource_scale, energy_used, contact_scale, consumed_delta,
		delta_position.x, delta_position.y, delta_rotation, float(flags), float(profile_index), remaining_energy,
	])
