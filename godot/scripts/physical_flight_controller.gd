class_name CyberPhysicalFlightController
extends RefCounted

# This local actuator has no body, position, goal, terrain, route, observation
# dictionary or evaluator access. Its entire physical input is own motion.
# The owner applies the returned bounded force/torque to the one real chassis.
const Profile = preload("res://scripts/physical_flight_profile.gd")
const SOURCE_SHA256: String = "fb86190c68c6a87e7d2ef7e845b1fb97305f188723a326f67f07caa6971cc8ae"
const SOURCE_HASH_RULE: String = "sha256-utf8-source-with-SOURCE_SHA256-value-replaced-by-<CONTROLLER_HASH>"

var last_error: String = ""
var _profile: Dictionary = {}
var _profile_hash: String = ""
var _force: Vector2 = Vector2.ZERO
var _torque: float = 0.0
var _receipt: Dictionary = {}


static func controller_hash() -> String:
	# Embedded normalized-source digest survives exports which strip .gd files.
	# The source conformance test verifies this value against the checked-in code.
	return SOURCE_SHA256


func configure(profile: Dictionary) -> bool:
	last_error = Profile.validate(profile)
	_profile = {} if not last_error.is_empty() else Profile.resolved(profile)
	_profile_hash = Profile.profile_hash(_profile) if not _profile.is_empty() else ""
	reset()
	return last_error.is_empty()


func reset() -> void:
	_force = Vector2.ZERO
	_torque = 0.0
	_receipt = _empty("reset", false, not _profile.is_empty())


func cancel() -> void:
	reset()
	_receipt.reason = "cancelled"


func observation() -> Dictionary:
	return _receipt.duplicate(true)


func advance(move: Vector2, velocity: Vector2, angle: float, angular_velocity: float,
		dt: float, powered: bool = true) -> Dictionary:
	if _profile.is_empty():
		return _refuse("unconfigured")
	if not is_finite(dt) or absf(dt - Profile.FIXED_DELTA) > 0.000000001:
		return _refuse("fixed_step_required")
	if not move.is_finite() or absf(move.x) > 1.0 or absf(move.y) > 1.0:
		return _refuse("invalid_action")
	if not velocity.is_finite() or not is_finite(angle) or not is_finite(angular_velocity):
		return _refuse("invalid_motion")
	var admitted: Vector2 = _limited(move, 1.0)
	var desired: Vector2 = admitted * Vector2(float(_profile.desired_speed[0]), float(_profile.desired_speed[1]))
	if not powered:
		_force = Vector2.ZERO
		_torque = 0.0
		_receipt = _empty("propulsion_disabled", false, true)
		_receipt.requested_move = move
		_receipt.admitted_move = admitted
		_receipt.desired_velocity = desired
		return observation()
	# Velocity error alone supplies feedback. Braking is the component opposed
	# to current motion; the rest is drive/turning acceleration. Their normalized
	# efforts share one ellipse, so mixed demand cannot add two full envelopes.
	# Scalar intermediates retain double precision even for large finite motion.
	var response: float = float(_profile.velocity_response_seconds)
	var ax: float = (float(desired.x) - float(velocity.x)) / response
	var ay: float = (float(desired.y) - float(velocity.y)) / response
	var speed: float = _length(velocity)
	var braking_x: float = 0.0
	var braking_y: float = 0.0
	if speed > 0.000001:
		var direction_x: float = float(velocity.x) / speed
		var direction_y: float = float(velocity.y) / speed
		var opposed: float = minf(0.0, ax * direction_x + ay * direction_y)
		braking_x = opposed * direction_x
		braking_y = opposed * direction_y
	var drive_x: float = ax - braking_x
	var drive_y: float = ay - braking_y
	var drive_limit: float = float(_profile.acceleration)
	var brake_limit: float = float(_profile.braking)
	var demand: float = sqrt((braking_x * braking_x + braking_y * braking_y) / (brake_limit * brake_limit)
		+ (drive_x * drive_x + drive_y * drive_y) / (drive_limit * drive_limit))
	var acceleration_scale: float = 1.0 / maxf(1.0, demand)
	var bounded_acceleration := Vector2(ax * acceleration_scale, ay * acceleration_scale)
	var compensation := Vector2(0.0, -float(_profile.mass) * float(_profile.gravity))
	var requested_force: Vector2 = bounded_acceleration * float(_profile.mass) + compensation
	var maximum: float = float(_profile.max_force)
	var target_force: Vector2 = _limited(requested_force, maximum)
	# Saturate before filtering. There is no accumulated velocity/position error
	# and no unsaturated force state to wind up while thrust is unavailable.
	var alpha: float = 1.0 - exp(-dt / float(_profile.thrust_response_seconds))
	var response_force: Vector2 = _force.lerp(target_force, alpha)
	var force_change: Vector2 = response_force - _force
	var force_step: float = float(_profile.max_force_slew) * dt
	var slew_limited: bool = _length(force_change) > force_step
	_force = _limited(_force + _limited(force_change, force_step), maximum)
	var error_angle: float = wrapf(angle, -PI, PI)
	var requested_torque: float = float(_profile.inertia) * (-float(_profile.attitude_kp) * error_angle
		- float(_profile.attitude_kd) * angular_velocity)
	if not is_finite(requested_torque):
		return _refuse("invalid_motion")
	var maximum_torque: float = float(_profile.max_torque)
	var target_torque: float = clampf(requested_torque, -maximum_torque, maximum_torque)
	var torque_step: float = float(_profile.max_torque_slew) * dt
	var torque_slew_limited: bool = absf(target_torque - _torque) > torque_step
	_torque = move_toward(_torque, target_torque, torque_step)
	_receipt = _empty("tracking", true, true)
	_receipt.merge({"requested_move": move, "admitted_move": admitted, "desired_velocity": desired,
		"requested_acceleration": [ax, ay], "bounded_acceleration": bounded_acceleration,
		"gravity_compensation": compensation, "requested_force": requested_force,
		"target_force": target_force, "applied_force": _force,
		"requested_torque": requested_torque, "target_torque": target_torque, "applied_torque": _torque,
		"thrust_saturated": _length(requested_force) > maximum,
		"acceleration_limited": demand > 1.0, "force_slew_limited": slew_limited,
		"torque_limited": absf(requested_torque) > maximum_torque,
		"torque_slew_limited": torque_slew_limited}, true)
	return observation()


func _refuse(reason: String) -> Dictionary:
	_force = Vector2.ZERO
	_torque = 0.0
	_receipt = _empty(reason, false, false)
	return observation()


func _empty(reason: String, powered: bool, valid: bool) -> Dictionary:
	return {"valid": valid, "reason": reason, "powered": powered,
		"controller_id": Profile.CONTROLLER_ID, "controller_hash": controller_hash(),
		"profile_hash": _profile_hash, "fixed_delta": Profile.FIXED_DELTA,
		"requested_move": Vector2.ZERO, "admitted_move": Vector2.ZERO,
		"desired_velocity": Vector2.ZERO, "requested_acceleration": [0.0, 0.0],
		"bounded_acceleration": Vector2.ZERO, "gravity_compensation": Vector2.ZERO,
		"requested_force": Vector2.ZERO, "target_force": Vector2.ZERO, "applied_force": Vector2.ZERO,
		"requested_torque": 0.0, "target_torque": 0.0, "applied_torque": 0.0,
		"thrust_saturated": false, "acceleration_limited": false, "force_slew_limited": false,
		"torque_limited": false, "torque_slew_limited": false}


static func _length(value: Vector2) -> float:
	# Vector2.length_squared uses the engine's single-precision vector scalar;
	# double intermediates avoid overflow for otherwise finite observations.
	return sqrt(float(value.x) * float(value.x) + float(value.y) * float(value.y))


static func _limited(value: Vector2, maximum: float) -> Vector2:
	var magnitude: float = _length(value)
	return value * (maximum / magnitude) if magnitude > maximum else value
