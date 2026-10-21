class_name CyberPlayerAcrobatController
extends RefCounted

# Human movement grammar for the articulated Acrobat. The calculation consumes
# copied physical observations; the adapter below applies only bounded impulses
# and bounded joint targets through the existing Rapier rig owner. Contact, not
# input cancellation or a timer alone, replenishes the airborne move inventory.
const DT_LIMIT: float = 1.0 / 30.0
const COYOTE_SECONDS: float = 0.11
const BUFFER_SECONDS: float = 0.14
const SUPPORT_CONFIRM_SECONDS: float = 0.05
const LAUNCH_LOCK_SECONDS: float = 0.14
const ROLL_SECONDS: float = 0.28
const ROLL_COOLDOWN_SECONDS: float = 0.32
const TAP_SECONDS: float = 0.15
const GLIDE_SECONDS: float = 1.6
const MAX_DELTA_SPEED: float = 96.0

var _previous_buttons := Vector3i.ZERO
var _facing: float = 1.0
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _buffer_bullet: bool = false
var _support_lock: float = 0.0
var _support_time: float = 0.0
var _ground_jump_available: bool = true
var _air_jump_available: bool = true
var _bullet_available: bool = true
var _air_roll_available: bool = true
var _glide_used: float = 0.0
var _roll_left: float = 0.0
var _roll_cooldown: float = 0.0
var _secondary_duration: float = 0.0
var _slide_suppressed: bool = false
var _sliding: bool = false
var _jump_cut_armed: bool = false
var _jump_cut_active: bool = false
var _last_move: String = "none"
var _last_move_age: float = 10.0
var _mode: String = "idle"
var _stance: String = "standing"
var _grounded: bool = false
var _last_delta_velocity := Vector2.ZERO


func advance(rig, action: Dictionary, dt: float, effort: float) -> void:
	var view: Dictionary = {"velocity": rig._velocities[0],
		"rotation": rig._transforms[0].get_rotation(), "gravity": rig._gravity,
		"grounded": not rig._support.is_empty(),
		"contact_normal": rig._support.get("normal", Vector2.ZERO)}
	var plan: Dictionary = calculate(view, action, dt, effort)
	var impulse: Vector2 = Vector2(plan.delta_velocity) * rig._total_mass
	rig._apply_rig_impulse(impulse)
	if bool(plan.react_support):
		rig._react_support(-impulse)
	if bool(plan.spin):
		rig._angular_target(float(plan.angular_speed), minf(dt, DT_LIMIT), 85.0)
	else:
		rig._gyro(float(plan.target_angle), minf(dt, DT_LIMIT), float(plan.gyro_gain))
	rig._player_joint_targets = plan.joint_targets.duplicate()
	rig.gait_phase = fmod(rig.gait_phase + minf(dt, DT_LIMIT) * 10.0
		* maxf(absf(Vector2(action.get("move", Vector2.ZERO)).x), 0.08), TAU)


func calculate(view: Dictionary, action: Dictionary, delta: float, effort: float = 1.0) -> Dictionary:
	var velocity: Variant = view.get("velocity", Vector2.ZERO)
	var movement: Variant = action.get("move", Vector2.ZERO)
	var aim: Variant = action.get("aim", Vector2.ZERO)
	var normal: Variant = view.get("contact_normal", Vector2.ZERO)
	if not velocity is Vector2 or not movement is Vector2 or not aim is Vector2 \
		or not normal is Vector2 or not velocity.is_finite() or not movement.is_finite() \
		or not aim.is_finite() or not normal.is_finite() or not is_finite(delta) \
		or not is_finite(effort) or delta <= 0.0:
		cancel()
		return _neutral_plan()
	var dt: float = minf(delta, DT_LIMIT)
	var power: float = clampf(effort, 0.15, 1.2)
	var move: Vector2 = Vector2(movement).limit_length(1.0)
	var speed: Vector2 = velocity
	var gravity: float = clampf(float(view.get("gravity", 156.0)), 0.0, 500.0)
	if not is_finite(gravity):
		cancel()
		return _neutral_plan()
	var buttons := Vector3i(int(bool(action.get("primary", false))),
		int(bool(action.get("secondary", false))), int(bool(action.get("auxiliary", false))))
	var pressed := Vector3i(int(buttons.x > _previous_buttons.x),
		int(buttons.y > _previous_buttons.y), int(buttons.z > _previous_buttons.z))
	var released := Vector3i(int(buttons.x < _previous_buttons.x),
		int(buttons.y < _previous_buttons.y), int(buttons.z < _previous_buttons.z))
	if absf(move.x) > 0.08:
		_facing = signf(move.x)
	_support_lock = maxf(0.0, _support_lock - dt)
	_roll_left = maxf(0.0, _roll_left - dt)
	_roll_cooldown = maxf(0.0, _roll_cooldown - dt)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - dt)
	_last_move_age += dt
	var physical_support: bool = bool(view.get("grounded", false)) and Vector2(normal).y < -0.35
	# The shared sensor includes a small foot-clearance tolerance. An upward
	# launch must leave that tolerance without repeatedly receiving a new jump.
	_grounded = physical_support and _support_lock <= 0.0 and speed.y >= -8.0
	if _grounded:
		_support_time += dt
		_coyote_left = COYOTE_SECONDS
		if _support_time + 0.000001 >= SUPPORT_CONFIRM_SECONDS:
			_ground_jump_available = true
			_air_jump_available = true
			_bullet_available = true
			_air_roll_available = true
			_glide_used = 0.0
	else:
		_support_time = 0.0
		_coyote_left = maxf(0.0, _coyote_left - dt)
	if buttons.y != 0:
		_secondary_duration += dt
	var tap_cancelled: bool = _slide_suppressed or pressed.z != 0
	if released.y != 0:
		_slide_suppressed = false
	if pressed.z != 0:
		# C can cancel a slide/roll without purchasing another airborne move.
		_roll_left = 0.0
		_sliding = false
		_slide_suppressed = true
	if buttons.y == 0 and move.y <= 0.4:
		_slide_suppressed = false
	var can_ground_jump: bool = _ground_jump_available and (_grounded or _coyote_left > 0.0)
	var dv := Vector2.ZERO
	var launched: bool = false
	if pressed.x != 0:
		_jump_buffer_left = BUFFER_SECONDS
		_buffer_bullet = buttons.y != 0 or move.y > 0.4
	if _jump_buffer_left > 0.0:
		if _buffer_bullet and _bullet_available:
			var direction: Vector2 = _bullet_direction(Vector2(aim), move, can_ground_jump)
			var target: Vector2 = direction * 128.0 * power
			dv = target - speed
			# Keep an already faster component when it points along the burst.
			if speed.x * target.x > 0.0 and absf(speed.x) > absf(target.x):
				dv.x = 0.0
			if speed.y * target.y > 0.0 and absf(speed.y) > absf(target.y):
				dv.y = 0.0
			dv = dv.limit_length(MAX_DELTA_SPEED)
			_bullet_available = false
			_begin_launch("bullet-jump")
			launched = true
		elif can_ground_jump:
			dv.y = clampf(-78.0 * power - speed.y, -MAX_DELTA_SPEED, 0.0)
			_begin_launch("jump")
			launched = true
		elif _air_jump_available and not _grounded:
			dv.y = clampf(-69.0 * power - speed.y, -MAX_DELTA_SPEED, 0.0)
			_air_jump_available = false
			_begin_launch("double-jump")
			launched = true
	if not launched:
		if pressed.y != 0 and not _grounded and _air_roll_available and _roll_cooldown <= 0.0:
			_air_roll_available = false
			_begin_roll("air-roll")
			dv.x += _facing * minf(30.0 * power, maxf(0.0, 112.0 * power - speed.x * _facing))
		elif released.y != 0 and _grounded and _secondary_duration <= TAP_SECONDS \
			and _roll_cooldown <= 0.0 and buttons.z == 0 and not tap_cancelled:
			_begin_roll("ground-roll")
			dv.x += _facing * minf(38.0 * power, maxf(0.0, 105.0 * power - speed.x * _facing))
	if released.y != 0:
		_secondary_duration = 0.0
	_sliding = _grounded and _roll_left <= 0.0 and not launched and not _slide_suppressed \
		and buttons.z == 0 and (buttons.y != 0 or move.y > 0.4)
	var gliding: bool = not _grounded and not launched and buttons.z != 0 \
		and speed.y >= -16.0 and _glide_used < GLIDE_SECONDS
	if gliding:
		_glide_used = minf(GLIDE_SECONDS, _glide_used + dt)
		_roll_left = 0.0
		# Gravity remains positive, and the landing-scoped reserve is finite.
		# Faster falls receive extra bounded drag, never a position correction.
		var lift: float = gravity * 0.82 + maxf(0.0, speed.y - 20.0) * 5.0
		dv.y -= minf(310.0, lift) * dt
	var braking: bool = _grounded and buttons.z != 0
	var max_speed: float = 108.0 * power
	var acceleration: float = (520.0 if _grounded else 215.0) * power
	if _sliding:
		acceleration = 140.0 * power
	elif _roll_left > 0.0:
		acceleration = 95.0 * power
	if braking:
		dv.x += clampf(-speed.x, -760.0 * dt, 760.0 * dt)
	elif absf(move.x) > 0.06:
		var target_speed: float = move.x * max_speed
		# Holding forward keeps externally gained speed. Reversing still applies
		# a bounded acceleration, so slide steering can be tweaked continuously.
		if speed.x * target_speed <= 0.0 or absf(speed.x) < absf(target_speed):
			dv.x += clampf(target_speed - speed.x, -acceleration * dt, acceleration * dt)
	elif _grounded and _roll_left <= 0.0:
		var drag: float = 19.0 if _sliding else 210.0
		dv.x += clampf(-speed.x, -drag * dt, drag * dt)
	if released.x != 0 and _jump_cut_armed:
		_jump_cut_active = true
	if _jump_cut_active and not launched and speed.y < -26.0:
		dv.y += minf(-26.0 - speed.y, 420.0 * dt)
	elif not launched and speed.y >= -26.0:
		_jump_cut_active = false
		_jump_cut_armed = false
	_mode = "run" if _grounded and absf(move.x) > 0.06 else ("idle" if _grounded else "fall")
	if _sliding:
		_mode = "slide"
	if _roll_left > 0.0:
		_mode = "roll"
	if gliding:
		_mode = "glide"
	if braking:
		_mode = "brake"
	if _last_move_age < 0.18 and _last_move in ["jump", "double-jump", "bullet-jump"]:
		_mode = _last_move
	# Keep the limbs folded while crouch is held even during a brief contact
	# loss as the chassis settles lower. Otherwise folding a foot away from the
	# floor would immediately unfold it and create a one-frame stance oscillation.
	var tuck_held: bool = not _slide_suppressed and buttons.z == 0 \
		and (buttons.y != 0 or move.y > 0.4)
	var tucked: bool = _sliding or _roll_left > 0.0 or _mode == "bullet-jump" or tuck_held
	_stance = "tucked" if tucked else "standing"
	var targets: Dictionary = {}
	if tucked:
		targets = {"hip_-1": 1.25, "hip_1": -1.25, "ankle_-1": -1.10, "ankle_1": 1.10}
	elif gliding:
		targets = {"hip_-1": 0.65, "hip_1": -0.65, "ankle_-1": -0.55, "ankle_1": 0.55}
	var target_angle: float = move.x * 0.10
	if _grounded:
		target_angle += clampf(Vector2(normal).angle() + PI * 0.5, -0.65, 0.65)
	var trim: float = clampf(float(action.get("trim", 0.0)), -1.0, 1.0)
	if not is_finite(trim):
		trim = 0.0
	if not _grounded:
		target_angle += trim * 0.65
	_previous_buttons = buttons
	_last_delta_velocity = dv.limit_length(MAX_DELTA_SPEED)
	return {"delta_velocity": _last_delta_velocity, "react_support": _grounded,
		"spin": _roll_left > 0.0, "angular_speed": _facing * 11.0,
		"target_angle": target_angle, "gyro_gain": 1.25 if gliding or braking else 0.95,
		"joint_targets": targets, "mode": _mode, "stance": _stance}


func _begin_launch(kind: String) -> void:
	_last_move = kind
	_last_move_age = 0.0
	_jump_buffer_left = 0.0
	_buffer_bullet = false
	_ground_jump_available = false
	_coyote_left = 0.0
	_support_time = 0.0
	_support_lock = LAUNCH_LOCK_SECONDS
	_roll_left = 0.0
	_sliding = false
	_jump_cut_armed = kind != "bullet-jump"
	_jump_cut_active = false


func _begin_roll(kind: String) -> void:
	_last_move = kind
	_last_move_age = 0.0
	_roll_left = ROLL_SECONDS
	_roll_cooldown = ROLL_COOLDOWN_SECONDS
	_sliding = false


func _bullet_direction(aim: Vector2, movement: Vector2, from_ground: bool) -> Vector2:
	var direction: Vector2 = aim
	if direction.length_squared() < 0.001:
		direction = movement if movement.y < -0.2 else Vector2(_facing, -0.8)
	if direction.length_squared() < 0.001:
		direction = Vector2(_facing, -0.8)
	direction = direction.normalized()
	if from_ground:
		direction.y = minf(-0.35, direction.y)
	return direction.normalized()


func _neutral_plan() -> Dictionary:
	return {"delta_velocity": Vector2.ZERO, "react_support": false,
		"spin": false, "angular_speed": 0.0, "target_angle": 0.0,
		"gyro_gain": 0.0, "joint_targets": {}, "mode": "cancelled", "stance": "standing"}


func cancel() -> void:
	# Authority changes do not reload jumps, rolls, bullet jumps or glide time.
	_previous_buttons = Vector3i.ZERO
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_buffer_bullet = false
	_support_time = 0.0
	_roll_left = 0.0
	_secondary_duration = 0.0
	_slide_suppressed = false
	_sliding = false
	_jump_cut_armed = false
	_jump_cut_active = false
	_last_delta_velocity = Vector2.ZERO
	_mode = "cancelled"
	_stance = "standing"


func observation() -> Dictionary:
	return {"controller": "player-acrobat/v1", "mode": _mode, "stance": _stance,
		"grounded": _grounded, "coyote_remaining": _coyote_left,
		"jump_buffer_remaining": _jump_buffer_left, "ground_jump_available": _ground_jump_available,
		"air_jump_available": _air_jump_available, "bullet_jump_available": _bullet_available,
		"air_roll_available": _air_roll_available, "glide_remaining": maxf(0.0, GLIDE_SECONDS - _glide_used),
		"roll_remaining": _roll_left, "last_move": _last_move, "last_move_age": _last_move_age,
		"delta_velocity": _last_delta_velocity}
