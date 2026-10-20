class_name CyberPlayerVehicleController
extends RefCounted

# A local actuator owned by the rig, reached only after the normal session's
# observation/lease admission. It never sets a transform or velocity directly.
var _previous_primary: bool = false
var _previous_auxiliary: bool = false
var _preload: float = 0.0
var _preload_armed: bool = false
var _drift: bool = false
var _mode: String = "idle"
var _throttle: float = 0.0
var _lean: float = 0.0
var _thrust: float = 0.0


func advance(rig, action: Dictionary, dt: float, effort: float) -> void:
	var move: Vector2 = action.get("move", Vector2.ZERO)
	var primary: bool = bool(action.get("primary", false))
	var auxiliary: bool = bool(action.get("auxiliary", false))
	_throttle = clampf(-move.y, -1.0, 1.0)
	_lean = clampf(move.x + float(action.get("trim", 0.0)), -1.0, 1.0)
	_thrust = 0.0
	if rig.rig_id in [&"stuntbuggy", &"trialsbike"]:
		_ground_vehicle(rig, action, dt, effort, primary, auxiliary)
	else:
		_flight(rig, action, dt, effort, primary, auxiliary)
	_previous_primary = primary
	_previous_auxiliary = auxiliary


func _ground_vehicle(rig, action: Dictionary, dt: float, effort: float,
		primary: bool, auxiliary: bool) -> void:
	var bike: bool = rig.rig_id == &"trialsbike"
	var brake: bool = bool(action.get("secondary", false))
	var grounded: bool = not rig._support.is_empty()
	var velocity: Vector2 = rig._velocities[0]
	var effective: float = 0.0 if brake else _throttle
	_mode = "brake" if brake else "ride" if grounded else "air"
	# Real axle motors carry traction; a bounded ground-only assist makes the
	# small game-scale wheels climb pixel stairs without requiring simulation fidelity.
	for joint: Dictionary in rig._joints:
		if str(joint.get("role", "")) == "wheel":
			var rear: bool = str(joint.id).ends_with("-1")
			rig._player_wheel_speeds[str(joint.id)] = effective * (27.0 if bike else 23.0) if rear or not bike else 0.0
			# A free front axle must roll, not act as a second brake.
			if bike and not rear and not brake:
				rig._player_free_joints[str(joint.id)] = true
	rig._player_joint_targets["rider_lean"] = _lean * 0.70
	if grounded:
		var normal: Vector2 = rig._support.get("normal", Vector2.UP)
		var tangent: Vector2 = Vector2(-normal.y, normal.x)
		if tangent.x < 0.0:
			tangent = -tangent
		var target: float = effective * float(rig._profile.speed) * effort
		var acceleration: float = 420.0 if brake else 100.0 if bike else 135.0
		var change: float = clampf(target - velocity.dot(tangent), -acceleration * dt, acceleration * dt)
		if absf(effective) > 0.01 or brake:
			var impulse: Vector2 = tangent * change * rig._total_mass
			rig._apply_rig_impulse(impulse)
			rig._react_support(-impulse)
	# Neutral steering leaves natural rotation; explicit lean remains strong in air.
	if absf(_lean) > 0.01:
		rig._angular_target(_lean * (6.5 if bike else 5.0), dt, 34.0 if bike else 24.0)
	elif brake:
		rig._angular_target(0.0, dt, 30.0)
	elif grounded:
		var slope: float = Vector2(rig._support.get("normal", Vector2.UP)).angle() + PI * 0.5
		rig._gyro(clampf(slope, -0.75, 0.75), dt, 0.18)
	if auxiliary:
		_mode = "recover"
		rig._gyro(0.0, dt, 1.5)
		if not _previous_auxiliary and grounded and absf(wrapf(rig._transforms[0].get_rotation(), -PI, PI)) > 1.0 and rig.cooldown <= 0.0:
			rig._apply_rig_impulse(Vector2.UP * 26.0 * rig._total_mass)
			rig.cooldown = 0.65
	if bike:
		if primary and grounded and rig.cooldown <= 0.0:
			_preload_armed = true
			_preload = minf(1.0, _preload + dt / 0.42)
			_mode = "preload"
		elif not primary and _previous_primary and _preload_armed:
			if grounded and rig.cooldown <= 0.0:
				var lift: float = (28.0 + _preload * 38.0) * effort
				rig._apply_rig_impulse(Vector2(effective * 13.0, -lift) * rig._total_mass)
				rig.cooldown = 0.5
			_preload = 0.0
			_preload_armed = false
		elif not grounded:
			# Unsupported charge cannot become a delayed launch after landing.
			_preload = 0.0
			_preload_armed = false
	else:
		if primary and not _previous_primary and grounded and rig.cooldown <= 0.0:
			rig._apply_rig_impulse(Vector2(effective * 11.0, -43.0 * effort) * rig._total_mass)
			rig.cooldown = 0.50
			_mode = "hop"
	if _preload_armed:
		for joint: Dictionary in rig._joints:
			if str(joint.get("role", "")) == "suspension":
				rig._player_joint_targets[str(joint.id)] = -_preload * 1.2


func _flight(rig, action: Dictionary, dt: float, effort: float,
		primary: bool, auxiliary: bool) -> void:
	var barrel: bool = rig.rig_id == &"jetbarrel"
	var brake: bool = bool(action.get("secondary", false))
	if not barrel and auxiliary and not _previous_auxiliary:
		_drift = not _drift
	var velocity: Vector2 = rig._velocities[0]
	var angle: float = rig._transforms[0].get_rotation()
	var rotation_speed: float = 10.0 if barrel else 6.8
	var rotation_accel: float = 85.0 if barrel else 65.0
	if absf(_lean) > 0.01:
		rig._angular_target(_lean * rotation_speed, dt, rotation_accel)
	elif brake or not _drift:
		rig._angular_target(0.0, dt, rotation_accel)
	if barrel and auxiliary:
		rig._gyro(0.0, dt, 1.2)
	var throttle: float = maxf(_throttle, 1.0 if primary else 0.0)
	if _throttle < 0.0 and not primary:
		throttle = _throttle * 0.40
	_thrust = throttle
	if absf(throttle) > 0.001:
		var force: float = float(rig._profile.thrust) * throttle * effort
		rig._apply_rig_impulse(Vector2.UP.rotated(angle) * force * dt * rig._total_mass)
	var damping: float = 8.5 if brake else 0.32 if barrel else 0.08 if _drift else 1.4
	var drag: Vector2 = (-velocity * minf(1.0, damping * dt)).limit_length((650.0 if brake else 220.0) * dt)
	rig._apply_rig_impulse(drag * rig._total_mass)
	var excess: float = velocity.length() - float(rig._profile.speed)
	if excess > 0.0:
		rig._apply_rig_impulse(-velocity.normalized() * minf(excess, 700.0 * dt) * rig._total_mass)
	_mode = "airbrake" if brake else "jet" if barrel else "drift" if _drift else "damped"


func cancel() -> void:
	_previous_primary = false
	_previous_auxiliary = false
	_preload = 0.0
	_preload_armed = false
	_drift = false
	_mode = "idle"
	_throttle = 0.0
	_lean = 0.0
	_thrust = 0.0


func observation() -> Dictionary:
	return {"controller": "player-vehicle/v1", "movement_mode": _mode,
		"preload": _preload, "preload_armed": _preload_armed, "drift": _drift,
		"throttle": _throttle, "lean": _lean, "thrust": _thrust}
