extends RefCounted

# Main-thread actuator through the existing leased rig owner. Every combined
# linear/angular request is bounded; never sets pose/velocity or edits cells.
var _throttle: float = 0.
var _mode: String = "coast"
var _force := Vector2.ZERO
var _torque: float = 0.

func advance(rig, action: Dictionary, dt: float, effort: float) -> void:
	var profile: Dictionary = rig._profile
	var board: bool = int(profile.fleet_index) == 3
	var move: Vector2 = action.get("move",Vector2.ZERO)
	var brake: bool = bool(action.get("secondary",false))
	var assist: bool = bool(action.get("auxiliary",false))
	var primary: bool = bool(action.get("primary",false))
	var angle: float = rig._transforms[0].get_rotation()
	var velocity: Vector2 = rig._velocities[0]
	var wanted: float = maxf(-move.y,1. if primary else 0.)
	if move.y > 0. and not primary: wanted = -move.y*.4
	_throttle = move_toward(_throttle,wanted,float(profile.fleet_slew)*dt)
	var acceleration: Vector2
	if board:
		# Antigravity is a bounded actuator, not a contact or position constraint.
		acceleration = Vector2(move.x*float(profile.fleet_accel),move.y*float(profile.fleet_accel)*.65-38.)
		if primary: acceleration.y -= float(profile.fleet_accel)*.7
	else:
		acceleration = Vector2.UP.rotated(angle)*float(profile.fleet_accel)*_throttle
	var drag: float = 4.5 if brake else float(profile.fleet_drag)
	acceleration -= velocity*drag
	var excess: float = maxf(0.,velocity.length()-float(profile.speed))
	acceleration -= velocity.normalized()*minf(excess*4.,100.)
	_force = (acceleration*rig._total_mass*clampf(effort,0.,1.)).limit_length(float(profile.fleet_force))
	rig._apply_rig_impulse(_force*dt)
	var lean: float = clampf(move.x+float(action.get("trim",0.)),-1.,1.)
	var alpha: float = 0.
	var omega: float = rig._angular_velocities[0]
	if board or assist:
		var target: float = float(action.get("trim",0.))*.4 if board else 0.
		alpha = wrapf(target-angle,-PI,PI)*10.-omega*4.
	elif absf(lean)>.01:
		alpha = (lean*float(profile.fleet_turn_speed)-omega)*4.
	elif brake:
		alpha = -omega*4.
	alpha = clampf(alpha,-float(profile.fleet_turn_accel),float(profile.fleet_turn_accel))
	_torque = clampf(alpha*rig._inertias[0]*clampf(effort,0.,1.),-float(profile.fleet_torque),float(profile.fleet_torque))
	rig._apply_angular_impulse(0,_torque*dt)
	_mode = "brake" if brake else "hoverboard" if board else "thrust" if absf(_throttle)>.01 else "coast"

func cancel() -> void:
	_throttle = 0.
	_force = Vector2.ZERO
	_torque = 0.
	_mode = "cancelled"

func observation() -> Dictionary:
	return {"controller":"gcr-review-fleet/v1","movement_mode":_mode,"thrust":_throttle,
		"applied_force":_force,"applied_torque":_torque}
