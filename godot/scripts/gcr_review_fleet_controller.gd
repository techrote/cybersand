extends RefCounted

# Main-thread actuator through the existing leased rig owner. Every combined
# linear/angular request is bounded; never sets pose/velocity or edits cells.
const SIDE_THRUST_FACTOR: float = 0.65
var _throttle: float = 0.
var _side_throttle: float = 0.
var _mode: String = "coast"
var _force := Vector2.ZERO
var _torque: float = 0.
var _boost: float = 1.0
var _force_cap: float = 0.0

func advance(rig, action: Dictionary, dt: float, effort: float) -> void:
	var profile: Dictionary = rig._profile
	var fleet_index: int = int(profile.fleet_index)
	# Current definitions copy these capabilities into the owner. Index fallbacks
	# retain the original controller ABI for archived seven-flyer fixtures.
	var board: bool = str(profile.get("fleet_control_mode","hoverboard" if fleet_index==3 else "body_thrust"))=="hoverboard"
	var move: Vector2 = action.get("move",Vector2.ZERO)
	var brake: bool = bool(action.get("secondary",false))
	var assist: bool = bool(action.get("auxiliary",false))
	var primary: bool = bool(action.get("primary",false))
	var angle: float = rig._transforms[0].get_rotation()
	var velocity: Vector2 = rig._velocities[0]
	var wanted: float = maxf(-move.y,1. if primary else 0.)
	# Kestrel's S is a dispenser action, so it does not also reverse thrust.
	if bool(profile.get("fleet_reverse_thrust",fleet_index!=2)) and move.y > 0. and not primary: wanted = -move.y*.4
	_throttle = move_toward(_throttle,wanted,float(profile.fleet_slew)*dt)
	_side_throttle = clampf(float(action.get("trim",0.)),-1.,1.) if bool(profile.get("fleet_side_thrusters",fleet_index in [1,2,4])) else 0.
	var acceleration: Vector2
	if board:
		# Antigravity is a bounded actuator, not a contact or position constraint.
		acceleration = Vector2(move.x*float(profile.fleet_accel),move.y*float(profile.fleet_accel)*.65-38.)
		if primary: acceleration.y -= float(profile.fleet_accel)*.7
	else:
		acceleration = Vector2.UP.rotated(angle)*float(profile.fleet_accel)*_throttle
		acceleration += Vector2.RIGHT.rotated(angle)*float(profile.fleet_accel)*SIDE_THRUST_FACTOR*_side_throttle
	# The leased review-room modifier scales propulsion, never hover compensation,
	# drag, the brake or angular commands. Preserve the old unboosted expressions.
	var propulsion: Vector2 = acceleration + Vector2(0,38.0) if board else acceleration
	_boost = float(profile.get("fleet_boost_multiplier",2.0)) if rig.review_boost_held() and not brake and propulsion.length_squared()>0.000001 else 1.0
	if _boost!=1.0:
		acceleration = propulsion*_boost
		if board: acceleration.y-=38.0
	var drag: float = 4.5 if brake else float(profile.fleet_drag)
	acceleration -= velocity*drag
	var excess: float = maxf(0.,velocity.length()-float(profile.speed))
	acceleration -= velocity.normalized()*minf(excess*4.,100.)
	_force_cap = float(profile.fleet_force)*_boost
	_force = (acceleration*rig._total_mass*clampf(effort,0.,1.)).limit_length(_force_cap)
	rig._apply_rig_impulse(_force*dt)
	# Q/E is now reserved for the craft-specific side jets or dispensers.
	# Only the hoverboard retains trim as an angular command below.
	var lean: float = clampf(move.x,-1.,1.)
	var alpha: float = 0.
	var omega: float = rig._angular_velocities[0]
	if board or assist:
		var target: float = float(action.get("trim",0.))*float(profile.get("fleet_trim_angle",.4)) if board else 0.
		alpha = wrapf(target-angle,-PI,PI)*float(profile.get("fleet_attitude_gain",10.))-omega*float(profile.get("fleet_attitude_damping",4.))
	elif absf(lean)>.01:
		alpha = (lean*float(profile.fleet_turn_speed)-omega)*4.
	elif brake:
		alpha = -omega*4.
	alpha = clampf(alpha,-float(profile.fleet_turn_accel),float(profile.fleet_turn_accel))
	_torque = clampf(alpha*rig._inertias[0]*clampf(effort,0.,1.),-float(profile.fleet_torque),float(profile.fleet_torque))
	rig._apply_angular_impulse(0,_torque*dt)
	_mode = "brake" if brake else "boost" if _boost>1.0 else "hoverboard" if board else "thrust" if absf(_throttle)>.01 else "side-thrust" if absf(_side_throttle)>.01 else "coast"

func cancel() -> void:
	_throttle = 0.
	_side_throttle = 0.
	_force = Vector2.ZERO
	_torque = 0.
	_boost = 1.0
	_force_cap = 0.0
	_mode = "cancelled"

func observation() -> Dictionary:
	return {"controller":"gcr-review-fleet/v1","movement_mode":_mode,"thrust":_throttle,
		"side_thrust":_side_throttle,"applied_force":_force,"applied_torque":_torque,
		"boost_multiplier":_boost,"force_cap":_force_cap}
