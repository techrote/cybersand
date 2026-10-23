class_name CyberPhysicalActorScript
extends RefCounted

# Deterministic local feedback demonstrations. This producer has exactly the
# human action vocabulary and consumes copied actor observations only. It never
# moves a body, reads World, fills energy or claims global pathfinding.
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const UsablePilot = preload("res://scripts/physical_usable_script.gd")
const Flight = preload("res://scripts/physical_flight_profile.gd")
const MAX_DELTA: float = 0.25
const PROGRESS_WINDOW: float = 0.65

var rig_id: StringName = &""
var home: Vector2 = Vector2.ZERO
var _profile: Dictionary = {}
var _style: Dictionary = {}
var _clock: float = 0.0
var _direction: float = 1.0
var _initial_direction: float = 1.0
var _phase_offset: float = 0.0
var _next_pulse: float = 0.0
var _pulse_until: float = -1.0
var _next_tool: float = 5.0
var _charge_holding: bool = false
var _charge_started: float = 0.0
var _turn_lock: float = 0.0
var _recovery_remaining: float = 0.0
var _recovery_count: int = 0
var _progress_anchor: Vector2 = Vector2.ZERO
var _progress_time: float = 0.0
var _still_time: float = 0.0
var _epoch: int = -1
var _last_centre: Vector2 = Vector2.ZERO
var _last_action: Dictionary = {}
var _last_grounded: bool = false
var _air_jump_used: bool = false
var _rope_age: float = 0.0
var _rope_takeoff_y: float = 0.0
var _rope_started_grounded: bool = false
var _mode_cooldown: float = 0.0
var _was_suspended: bool = false
var _saving_energy: bool = false
var _payload_swing: float = 0.0
var _payload_swing_speed: float = 0.0
var _payload_correction: float = 0.0
var _usable_pilot = UsablePilot.new()
var _actor_index: int = 0


func configure(selected_rig: StringName, origin: Vector2, actor_index: int = 0) -> bool:
	if not Catalog.has_rig(selected_rig) or not origin.is_finite() or actor_index < 0:
		return false
	rig_id = selected_rig
	home = origin
	var definition: Dictionary = Catalog.entry(rig_id)
	_profile = definition.profile
	_style = definition.script
	_phase_offset = float(actor_index % 17) * 0.37
	_initial_direction = 1.0 if actor_index % 2 == 0 else -1.0
	_actor_index = actor_index
	reset(origin)
	return true


func reset(origin: Vector2 = Vector2.INF) -> void:
	if origin.is_finite():
		home = origin
	_clock = 0.0
	_direction = _initial_direction
	_next_pulse = 0.18 + _phase_offset * 0.15
	_pulse_until = -1.0
	_next_tool = 5.0 + _phase_offset
	_charge_holding = false
	_charge_started = 0.0
	_turn_lock = 0.0
	_recovery_remaining = 0.0
	_recovery_count = 0
	_progress_anchor = home
	_progress_time = 0.0
	_still_time = 0.0
	_epoch = -1
	_last_centre = home
	_last_action = neutral_action()
	_last_grounded = false
	_air_jump_used = false
	_rope_age = 0.0
	_rope_takeoff_y = home.y
	_rope_started_grounded = false
	_mode_cooldown = 0.0
	_was_suspended = false
	_saving_energy = false
	_payload_swing = 0.0
	_payload_swing_speed = 0.0
	_payload_correction = 0.0
	if rig_id != &"":
		_usable_pilot.configure(rig_id, home, _actor_index)


func cancel() -> void:
	# The actor owner must cancel its charged action as well. Clearing this
	# producer alone must never be used as the owner's charge-release operation.
	_charge_holding = false
	_pulse_until = -1.0
	_next_pulse = _clock + 0.2
	_last_action = neutral_action()
	_was_suspended = true
	_usable_pilot.cancel()


static func neutral_action() -> Dictionary:
	return {"move": Vector2.ZERO, "aim": Vector2.RIGHT, "effort": 0.0,
		"trim": 0.0, "reel": 0.0, "primary": false, "secondary": false,
		"auxiliary": false, "tool": false}


func diagnostics() -> Dictionary:
	return {"rig_id": rig_id, "time": _clock, "direction": _direction,
		"recovery_remaining": _recovery_remaining, "recovery_count": _recovery_count,
		"still_time": _still_time, "charge_holding": _charge_holding,
		"payload_swing": _payload_swing, "payload_swing_speed": _payload_swing_speed,
		"payload_correction": _payload_correction,
		"equipment": _usable_pilot.diagnostics(),
		"controller_id": "4ly-neutral-producer/v1" if rig_id in Flight.IDS else "local-feedback/" + str(rig_id) + "/v1"}


func next_action(observation: Dictionary, delta: float) -> Dictionary:
	if rig_id in Flight.IDS:
		# Conformance producer only. Goal-seeking flight teaching belongs to
		# 4LY-003; the neutral request traverses the same lease and actuator path.
		_last_action = {"move": Vector2.ZERO}
		return _last_action.duplicate(true)
	if _profile.is_empty() or not is_finite(delta) or delta <= 0.0 or delta > MAX_DELTA:
		return neutral_action()
	var centre: Vector2 = observation.get("centre", observation.get("position", Vector2.INF))
	var velocity: Vector2 = observation.get("velocity", Vector2.INF)
	var rotation: float = float(observation.get("rotation", INF))
	var angular_velocity: float = float(observation.get("angular_velocity", INF))
	if not centre.is_finite() or not velocity.is_finite() or not is_finite(rotation) \
			or not is_finite(angular_velocity) or StringName(observation.get("rig_id", rig_id)) != rig_id:
		return neutral_action()
	if bool(observation.get("suspended", false)):
		cancel()
		return neutral_action()
	var observed_epoch: int = int(observation.get("epoch", 0))
	if _epoch >= 0 and observed_epoch != _epoch:
		# A stale controller may not release a previous body's stored action.
		reset(home)
		_epoch = observed_epoch
		return neutral_action()
	_epoch = observed_epoch
	if _was_suspended:
		_charge_holding = false
		_pulse_until = -1.0
		_next_pulse = _clock + 0.2
		_was_suspended = false
	_clock += delta
	_turn_lock = maxf(0.0, _turn_lock - delta)
	_recovery_remaining = maxf(0.0, _recovery_remaining - delta)
	_mode_cooldown = maxf(0.0, _mode_cooldown - delta)
	var grounded: bool = bool(observation.get("grounded", false))
	var gripped: bool = bool(observation.get("gripped", false))
	var normal: Vector2 = observation.get("contact_normal", Vector2.ZERO)
	if not normal.is_finite():
		normal = Vector2.ZERO
	var left: bool = _near_wall(observation.get("wall_left", false))
	var right: bool = _near_wall(observation.get("wall_right", false))
	var blocked: bool = bool(observation.get("blocked", false)) \
		or (right and _direction > 0.0) or (left and _direction < 0.0)
	var attached: bool = bool(observation.get("rope_attached", false))
	if attached and _rope_age <= 0.0:
		_rope_takeoff_y = centre.y
		_rope_started_grounded = grounded
	_rope_age = _rope_age + delta if attached else 0.0
	if grounded:
		_air_jump_used = false
	_update_route(centre, velocity, grounded or gripped, blocked, left, right, delta, observation)
	if _profile.has("player_controller"):
		var player_action: Dictionary = _player_feedback(observation, centre, velocity,
			rotation, angular_velocity, grounded, blocked)
		_last_centre = centre
		_last_grounded = grounded
		_last_action = player_action.duplicate(true)
		return player_action
	var recovering: bool = _recovery_remaining > 0.0
	var energy: float = float(observation.get("energy", 1.0))
	if energy < 0.15:
		_saving_energy = true
	elif energy > 0.32:
		_saving_energy = false
	var action: Dictionary = neutral_action()
	var speed: float = float(_profile.speed) * float(_style.pace)
	var radius: float = float(_style.radius)
	var target_x: float = home.x + _direction * radius
	var remaining: float = target_x - centre.x
	var desired_x: float = clampf(remaining * 2.2, -speed, speed)
	var command_x: float = clampf((desired_x - velocity.x * 0.30) / maxf(speed * 0.72, 1.0), -1.0, 1.0)
	var altitude: float = float(_style.altitude)
	var target_y: float = home.y - altitude + sin((_clock + _phase_offset) * 0.72) * 3.5
	var desired_y: float = clampf((target_y - centre.y) * 2.0, -speed * 0.62, speed * 0.62)
	var command_y: float = clampf((desired_y - velocity.y * 0.50) / maxf(speed * 0.65, 1.0), -1.0, 1.0)
	var family: String = str(_profile.movement)
	var flight: bool = family == "flight" or (bool(_profile.get("flight_mode", false)) and _in_flight_mode(observation))
	var period: float = maxf(float(_style.period), 0.4)
	var phase: float = fmod(_clock + _phase_offset, period) / period
	var tilt: float = wrapf(rotation, -PI, PI)
	var severe_tilt: bool = absf(tilt) > 1.08 or absf(angular_velocity) > 4.0
	action.move = Vector2(command_x, command_y if flight or family in ["hover", "pulse"] else 0.0)
	action.aim = Vector2(_direction, -0.8).normalized()
	action.effort = 0.92 if recovering or blocked else 0.78
	action.trim = clampf(-tilt * 0.45 - angular_velocity * 0.18, -0.85, 0.85)
	if family in ["roll", "sail"]:
		# Let these machines lean into their intended motion; reserve strong
		# counterspin for a real recovery instead of erasing their character.
		action.trim = clampf(_direction * 0.2 - angular_velocity * 0.10, -0.7, 0.7)
	if recovering:
		action.move.x = _direction
		action.aim = Vector2(_direction, -1.2).normalized()
		if flight:
			action.move.y = -0.8
		if left and not right:
			action.aim.x = absf(action.aim.x)
		elif right and not left:
			action.aim.x = -absf(action.aim.x)
	if flight:
		_flight_feedback(action, observation, velocity, command_x, command_y, tilt, severe_tilt)
	elif family == "hover":
		action.move.y = clampf((float(_profile.ground_clearance) - float(observation.get("ground_distance", 12.0))) * -0.10, -0.7, 0.7)
		if float(observation.get("ground_distance", 99.0)) > 30.0:
			action.move.y = 0.0
	elif family == "drill":
		# Bore in the requested local route direction after entry. The operator
		# can turn through the whole plane; this is no longer downward-only.
		action.aim = Vector2(_direction * 0.8, 0.6 if _clock < 1.8 else sin(_clock * 0.55) * 0.45).normalized()
		action.move = action.aim
	elif bool(_profile.grip) and (gripped or left or right):
		action.move.y = -0.8
		action.aim = (normal + Vector2(_direction * 0.45, -1.1)).normalized()
		if action.aim.length_squared() < 0.1:
			action.aim = Vector2(_direction, -1).normalized()
	var supported: bool = grounded or gripped or normal.length_squared() > 0.25
	var ready: bool = float(observation.get("cooldown", 0.0)) <= 0.0
	var wants_leap: bool = supported and (blocked or recovering or _clock >= _next_pulse)
	_primary(action, observation, supported, ready, wants_leap, flight, phase, period, velocity)
	_secondary(action, observation, grounded, gripped, flight, phase, velocity, severe_tilt)
	_auxiliary(action, observation, grounded, blocked, recovering, severe_tilt, phase)
	if str(_profile.primary) == "left_thrust":
		# Binary buttons are pulse-width modulated, using the same held-input
		# authority as a human. Common phase keeps balanced thrust synchronized;
		# differential duty supplies attitude correction without a hidden motor.
		var gravity: float = float(observation.get("gravity", _profile.gravity))
		var desired_vertical: float = clampf(float(action.move.y) * speed * 0.5, -22.0, 22.0)
		var lift: float = maxf(0.0, gravity + (velocity.y - desired_vertical) * 2.0)
		var available: float = 2.0 * float(_profile.thrust) * 0.62 * maxf(0.45, cos(tilt))
		var collective: float = clampf(lift / maxf(available, 1.0), 0.0, 1.0)
		var desired_tilt: float = clampf(command_x * 0.22 - velocity.x * 0.005, -0.30, 0.30)
		var balance: float = clampf((desired_tilt - tilt) * 0.05 - angular_velocity * 0.025, -0.05, 0.05)
		if float(observation.get("ceiling_distance", 100.0)) < 5.0:
			collective = minf(collective, 0.2)
		# A period not aligned with the 10 Hz decision interval avoids six
		# repeated duty buckets swallowing small differential corrections.
		var pwm: float = fmod((_clock + _phase_offset) / 0.73, 1.0)
		action.primary = pwm < clampf(collective + balance, 0.0, 1.0)
		action.secondary = pwm < clampf(collective - balance, 0.0, 1.0)
		action.trim = clampf((desired_tilt - tilt) * 0.6 - angular_velocity * 0.16, -0.7, 0.7)
		action.auxiliary = action.auxiliary and action.move.y < -0.4 \
			and absf(tilt) < 0.35 and absf(angular_velocity) < 0.8 \
			and float(observation.get("ceiling_distance", 100.0)) > 14.0
		if absf(tilt) > 1.15:
			# Do not pin an inverted craft to the floor with downward thrust.
			# The same bounded trim/gyro authority rights it before relaunch.
			action.primary = false
			action.secondary = false
			action.auxiliary = false
			action.move.x = 0.0
			action.trim = clampf(-tilt * 0.8 - angular_velocity * 0.25, -1.0, 1.0)
	if family == "rope":
		_rope_feedback(action, observation, velocity, attached, recovering)
	if bool(_profile.get("double_jump", false)) and not grounded and not _air_jump_used \
			and velocity.y > 7.0 and blocked and ready and _clock > 0.5:
		action.primary = true
		_air_jump_used = true
	# Tool demonstrations are deliberate and infrequent. A cutter helps a
	# blocked route; idle patrol does not continuously destroy the showcase.
	if str(_profile.tool) == "cutter" and bool(observation.get("tool_ready", false)) \
			and blocked and _clock >= _next_tool:
		action.tool = true
		_next_tool = _clock + 1.2
	if severe_tilt and not flight and str(_profile.auxiliary) == "self_right":
		action.primary = false
		action.auxiliary = true
		action.trim = clampf(-tilt * 0.8 - angular_velocity * 0.25, -1.0, 1.0)
	if _saving_energy:
		# Preserve continuous local stabilization while the burst reserve
		# replenishes. Duet still needs both primary actuator buttons to fly.
		if str(_profile.primary) not in ["left_thrust", "charge_jump"]:
			action.primary = false
		if str(_profile.secondary) in ["pulse", "hop"]:
			action.secondary = false
		if str(_profile.auxiliary) in ["paired_burst", "dive"]:
			action.auxiliary = false
		action.tool = false
		if not _charge_holding:
			action.effort = minf(float(action.effort), 0.70)
	_last_centre = centre
	_last_grounded = grounded
	action = _usable_pilot.apply(observation, action, delta)
	_last_action = action.duplicate(true)
	return action


func _player_feedback(observation: Dictionary, centre: Vector2, velocity: Vector2,
		rotation: float, angular_velocity: float, grounded: bool, blocked: bool) -> Dictionary:
	# Optional demonstrations use exactly the human channels. In particular,
	# vehicle Y is throttle and X is lean; it is not the older ground-rig mapping.
	var action: Dictionary = neutral_action()
	action.effort = 0.82
	action.aim = Vector2(_direction, -0.65).normalized()
	var target_x: float = home.x + _direction * float(_style.radius)
	var tilt: float = wrapf(rotation, -PI, PI)
	if rig_id in [&"stuntbuggy", &"trialsbike"]:
		var throttle: float = clampf((target_x - centre.x) * 0.08 - velocity.x * 0.012, -1.0, 1.0)
		var lean: float = clampf(-tilt * 0.7 - angular_velocity * 0.22, -0.8, 0.8)
		action.move = Vector2(lean, -throttle).limit_length(1.0)
		action.auxiliary = grounded and absf(tilt) > 1.1
		action.secondary = grounded and absf(target_x - centre.x) < 7.0 and absf(velocity.x) > 15.0
		if rig_id == &"stuntbuggy":
			if grounded and not action.auxiliary and (blocked or _clock >= _next_pulse):
				_start_pulse(1.8)
			action.primary = _clock < _pulse_until
		else:
			if _charge_holding and (not grounded or _clock - _charge_started >= 0.38):
				_charge_holding = false
				_next_pulse = _clock + 1.7
			elif not _charge_holding and grounded and not action.auxiliary and _clock >= _next_pulse:
				_charge_holding = true
				_charge_started = _clock
			action.primary = _charge_holding
	elif rig_id == &"acrobat":
		action.move = Vector2(clampf((target_x - centre.x) * 0.06 - velocity.x * 0.008, -1.0, 1.0), 0)
		if grounded and (blocked or _clock >= _next_pulse):
			_start_pulse(1.5)
		action.primary = _clock < _pulse_until
		action.secondary = grounded and fmod(_clock + _phase_offset, 3.4) < 0.35
		action.auxiliary = not grounded and velocity.y > 10.0 and absf(target_x - centre.x) > 14.0
	else:
		var target_y: float = home.y - float(_style.altitude)
		var gravity: float = float(observation.get("gravity", _profile.gravity))
		var desired: Vector2 = Vector2(clampf((target_x - centre.x) * 2.4 - velocity.x * 4.0, -140.0, 140.0),
			clampf((target_y - centre.y) * 3.2 - velocity.y * 4.0 - gravity, -260.0, 60.0))
		var target_angle: float = desired.angle() + PI * 0.5
		var lean: float = clampf(wrapf(target_angle - tilt, -PI, PI) * 0.9 - angular_velocity * 0.25, -1.0, 1.0)
		var throttle: float = clampf(desired.length() / (float(_profile.thrust) * float(action.effort)), 0.0, 0.85)
		if cos(wrapf(target_angle - tilt, -PI, PI)) < 0.3:
			throttle = 0.0
		action.move = Vector2(lean, -throttle).limit_length(1.0)
		action.auxiliary = rig_id == &"jetbarrel" and grounded and absf(tilt) > 1.2
	return action


func _update_route(centre: Vector2, velocity: Vector2, supported: bool, blocked: bool,
		left: bool, right: bool, delta: float, observation: Dictionary) -> void:
	var radius: float = float(_style.radius)
	var predicted_x: float = centre.x + velocity.x * 0.20
	if _turn_lock <= 0.0 and (_direction > 0.0 and predicted_x >= home.x + radius - 2.0 \
			or _direction < 0.0 and predicted_x <= home.x - radius + 2.0):
		_direction = -_direction
		_turn_lock = 0.65
		_next_pulse = maxf(_next_pulse, _clock + 0.15)
		_progress_anchor = centre
		_progress_time = 0.0
		_still_time = 0.0
	_progress_time += delta
	if _progress_time >= PROGRESS_WINDOW:
		# Patrol progress is signed along the route. A rejected vault or a
		# sideways shove must not count as success just because the body moved.
		var displacement: Vector2 = centre - _progress_anchor
		var travel: float = displacement.x * _direction
		var forward_speed: float = velocity.x * _direction
		var family: String = str(_profile.movement)
		if family == "drill":
			var bore_axis: Vector2 = _last_action.get("aim", Vector2(_direction, 0.0))
			travel = displacement.dot(bore_axis)
			forward_speed = velocity.dot(bore_axis)
		elif (family == "rope" and bool(observation.get("rope_attached", false)) \
				and float(_last_action.get("reel", 0.0)) > 0.1) \
				or (bool(observation.get("gripped", false)) \
				and Vector2(_last_action.get("move", Vector2.ZERO)).y < -0.1):
			# Deliberate hauling and attached climbing can make useful upward
			# progress before translation resumes. Free hops cannot use this arm.
			travel = maxf(travel, -displacement.y)
			forward_speed = maxf(forward_speed, -velocity.y)
		if _clock > 0.5 and travel < 1.0 and forward_speed < 3.0 and (supported or blocked):
			_still_time += _progress_time
		else:
			_still_time = maxf(0.0, _still_time - _progress_time * 1.5)
		_progress_anchor = centre
		_progress_time = 0.0
	# Delay a reversal long enough for a planted leg, charge or winch to work.
	# This removes the old "velocity is zero, reverse every decision" twitch.
	if _still_time >= PROGRESS_WINDOW and _recovery_remaining <= 0.0 and _turn_lock <= 0.0:
		if left != right:
			_direction = 1.0 if left else -1.0
		else:
			_direction = -_direction
		_recovery_remaining = float(_style.recovery_seconds)
		_turn_lock = _recovery_remaining + 0.6
		_recovery_count += 1
		_still_time = 0.0
		_progress_anchor = centre
		_progress_time = 0.0
		_next_pulse = minf(_next_pulse, _clock)


func _flight_feedback(action: Dictionary, observation: Dictionary, velocity: Vector2,
		command_x: float, command_y: float, tilt: float, severe_tilt: bool) -> void:
	# Translation target and body attitude remain separate. A helicopter leans
	# deliberately, then countersteers before a route endpoint.
	if bool(_profile.body_thrust):
		var desired_tilt: float = command_x * 0.36
		action.trim = clampf((desired_tilt - tilt) * 0.8 - float(observation.angular_velocity) * 0.20, -0.85, 0.85)
	else:
		action.trim = clampf(-tilt * 0.6 - float(observation.angular_velocity) * 0.15, -0.75, 0.75)
	var correction: Vector2 = Vector2(command_x, command_y - 0.25)
	if correction.length_squared() > 0.08:
		action.aim = correction.normalized()
	if float(observation.get("ceiling_distance", 100.0)) < 5.0:
		action.move.y = maxf(action.move.y, 0.65)
		action.aim.y = maxf(action.aim.y, 0.25)
	if severe_tilt:
		action.move.x *= 0.35
		action.effort = 0.85
	if rig_id == &"heavylift":
		_heavylift_feedback(action, observation, command_x, velocity)


func _heavylift_feedback(action: Dictionary, observation: Dictionary,
		command_x: float, velocity: Vector2) -> void:
	var cruise: float = command_x * 0.72 - velocity.x * 0.012
	action.move.x = clampf(cruise, -0.8, 0.8)
	action.effort = 0.88
	_payload_swing = 0.0
	_payload_swing_speed = 0.0
	_payload_correction = 0.0
	var parts: Variant = observation.get("parts", [])
	var joints: Variant = observation.get("joints", [])
	if not parts is Array or not joints is Array \
			or parts.size() > Catalog.MAX_PARTS or joints.size() > Catalog.MAX_PARTS:
		return
	var payload: Dictionary = {}
	for candidate: Variant in parts:
		if candidate is Dictionary and str(candidate.get("id", "")) == "payload":
			payload = candidate
			break
	if payload.is_empty() or bool(payload.get("detached", false)):
		return
	# Both connections must still be live. Released cargo must not steer its
	# former carrier just because a copied part remains in the coupled roster.
	var sling_connected: bool = false
	var load_connected: bool = false
	for joint: Variant in joints:
		if not joint is Dictionary or not bool(joint.get("enabled", false)):
			continue
		if str(joint.get("id", "")) == "sling_pivot":
			sling_connected = true
		elif str(joint.get("id", "")) == "payload_pin":
			load_connected = true
	if not sling_connected or not load_connected:
		return
	var position: Variant = payload.get("position")
	var payload_velocity: Variant = payload.get("velocity")
	if not position is Vector2 or not payload_velocity is Vector2 \
			or not position.is_finite() or not payload_velocity.is_finite():
		return
	var centre: Vector2 = observation.get("centre", observation.get("position", home))
	var radial: Vector2 = position - centre
	if radial.y <= 2.0 or radial.length_squared() > 1600.0:
		return # Let normal attitude recovery handle a tumble or invalid linkage.
	var relative_velocity: Vector2 = payload_velocity - velocity
	_payload_swing = atan2(radial.x, radial.y)
	_payload_swing_speed = clampf(Vector2(radial.y, -radial.x).dot(relative_velocity)
		/ radial.length_squared(), -4.0, 4.0)
	# Ease starts while the load swings, then move the carrier beneath the
	# load's outward motion. This damps the pendulum through ordinary flight
	# input; no payload force or transform is applied by the producer.
	var settling: float = clampf(absf(_payload_swing) * 0.6
		+ absf(_payload_swing_speed) * 0.06, 0.0, 0.35)
	_payload_correction = clampf(_payload_swing * 0.22 + _payload_swing_speed * 0.085, -0.24, 0.24)
	action.move.x = clampf(cruise * (1.0 - settling) + _payload_correction, -0.8, 0.8)


func _primary(action: Dictionary, observation: Dictionary, supported: bool, ready: bool,
		wants_leap: bool, flight: bool, phase: float, period: float, velocity: Vector2) -> void:
	var ability: String = str(_profile.primary)
	match ability:
		"charge_jump":
			if not _charge_holding and wants_leap and ready and not _saving_energy:
				_charge_holding = true
				_charge_started = _clock
			if _charge_holding:
				action.primary = true
				if _clock - _charge_started >= float(_profile.charge_seconds):
					action.primary = false
					_charge_holding = false
					_next_pulse = _clock + period * 0.65
		"pogo":
			action.primary = phase > 0.13
		"spin":
			action.primary = phase < 0.75
		"boost":
			if flight:
				if bool(_profile.body_thrust):
					action.primary = action.move.y < -0.3 and float(observation.get("ceiling_distance", 100.0)) > 8.0 \
						and absf(wrapf(float(observation.rotation), -PI, PI)) < 1.0
				else:
					action.primary = action.move.y < -0.3 or absf(action.move.x) > 0.65
			else:
				action.primary = supported and (wants_leap or str(_profile.movement) == "hover")
		"pulse":
			var need_pulse: bool = wants_leap or (flight and _clock >= _next_pulse \
				and (absf(action.move.x) > 0.45 or action.move.y < -0.3))
			if str(_profile.movement) == "pulse":
				need_pulse = _clock >= _next_pulse and float(observation.get("charge", 1.0)) > 0.35
				if supported:
					action.aim = Vector2(_direction, -1.0).normalized()
			if need_pulse and ready:
				_start_pulse(period * 0.65)
			action.primary = _clock < _pulse_until
		"rope":
			if not bool(observation.get("rope_attached", false)) and ready and _clock >= _next_pulse:
				_start_pulse(0.8)
			action.primary = _clock < _pulse_until
		"drill":
			action.primary = phase < 0.82
		"cut":
			action.primary = bool(observation.get("blocked", false)) or phase < 0.32
		"blast":
			action.aim = Vector2(-_direction * 0.55, 1.0).normalized()
			if supported and wants_leap and ready:
				_start_pulse(period * 0.8)
			action.primary = _clock < _pulse_until
		"left_thrust":
			pass # Paired feedback is computed after shared ability handling.
		_:
			if wants_leap and ready:
				_start_pulse(period * 0.8)
			action.primary = _clock < _pulse_until
	if ability == "jump" and velocity.y > 4.0 and not supported:
		action.primary = false


func _secondary(action: Dictionary, observation: Dictionary, grounded: bool, gripped: bool,
		flight: bool, phase: float, velocity: Vector2, severe_tilt: bool) -> void:
	match str(_profile.secondary):
		"grip":
			action.secondary = not action.primary and (grounded or gripped \
				or _near_wall(observation.get("wall_left", false)) or _near_wall(observation.get("wall_right", false)))
		"glide", "sail":
			action.secondary = not grounded and velocity.y > -8.0 and absf(velocity.x) > 9.0
		"stabilize":
			action.secondary = severe_tilt or absf(float(observation.angular_velocity)) > 1.6 \
				or (flight and absf(action.move.x) < 0.45)
		"brake":
			var braking: bool = velocity.x * action.move.x < -5.0
			action.secondary = braking and not action.primary
			if rig_id == &"luna":
				action.secondary = action.secondary or (not action.primary and phase > 0.72)
		"preload":
			action.secondary = grounded and phase < 0.13
			if action.secondary:
				action.primary = false
		"hop":
			action.secondary = grounded and phase >= 0.76 and phase < 0.87 \
				and float(observation.get("charge", 1.0)) > 0.25
		"inhale":
			action.secondary = not action.primary and (phase > 0.45 or float(observation.get("charge", 1.0)) < 0.5)
		"rebound":
			action.secondary = not grounded or bool(observation.get("blocked", false))
		"pulse":
			action.secondary = grounded and phase > 0.6 and phase < 0.69 \
				and velocity.x * _direction > 4.0


func _auxiliary(action: Dictionary, observation: Dictionary, grounded: bool, blocked: bool,
		recovering: bool, severe_tilt: bool, phase: float) -> void:
	match str(_profile.auxiliary):
		"self_right":
			action.auxiliary = severe_tilt or recovering
		"stabilize":
			action.auxiliary = not grounded and (float(observation.velocity.y) > 10.0 or severe_tilt)
		"tuck":
			action.auxiliary = blocked and not action.primary
		"dive":
			var height: float = float(observation.get("ground_distance", 0.0))
			action.auxiliary = not grounded and height > 16.0 and height < 45.0 \
				and phase > 0.72 and phase < 0.79 and not recovering
		"grip_release":
			action.auxiliary = recovering and bool(observation.get("gripped", false))
		"toggle_power":
			action.auxiliary = not bool(observation.get("powered", true)) and _mode_cooldown <= 0.0
			if action.auxiliary:
				_mode_cooldown = 0.6
		"mode":
			if bool(_profile.get("flight_mode", false)) and _mode_cooldown <= 0.0:
				var flying: bool = _in_flight_mode(observation)
				action.auxiliary = (not flying and (blocked or recovering)) \
					or (flying and grounded and _clock > 1.0 and not blocked)
				if action.auxiliary:
					_mode_cooldown = 1.1
		"paired_burst":
			action.auxiliary = phase < 0.08 and _clock > 0.5 and not severe_tilt
		"brake":
			action.auxiliary = grounded and float(observation.velocity.x) * _direction < -5.0


func _rope_feedback(action: Dictionary, observation: Dictionary, velocity: Vector2,
		attached: bool, recovering: bool) -> void:
	if not attached:
		var steepness: float = -1.7 if _recovery_count % 2 == 0 else -0.9
		action.aim = Vector2(_direction, steepness).normalized()
		action.reel = 0.0
		return
	var centre: Vector2 = observation.get("centre", observation.get("position", home))
	var anchor: Vector2 = observation.get("anchor", centre + Vector2(0, -20))
	var radial: Vector2 = centre - anchor
	var tangent: Vector2 = Vector2(-radial.y, radial.x).normalized()
	if tangent.x * _direction < 0.0:
		tangent = -tangent
	# Pump with the current swing when useful; reel on ascent, relax on descent.
	action.move.x = _direction if absf(velocity.x) < 3.0 else signf(velocity.dot(tangent)) * tangent.x
	action.reel = 0.7 if velocity.y < 0.0 else -0.15
	var acquired_lift: bool = not _rope_started_grounded or _rope_takeoff_y - centre.y >= 8.0
	if not acquired_lift:
		# Take up slack and leave the floor before trying to pump a swing.
		# Paying line out from rest never establishes the upward half-cycle.
		action.reel = 0.85
	var tension: float = float(observation.get("tension", 0.0))
	var launch_window: bool = _rope_age > 0.45 and velocity.x * _direction > 13.0 \
		and velocity.y < -2.0 and acquired_lift
	var should_release: bool = launch_window or recovering or _rope_age > 2.7
	if rig_id == &"winchbug":
		action.reel = 0.85
		action.secondary = absf(velocity.x) > 25.0 or tension > 0.85
		should_release = recovering or _rope_age > 3.2 or centre.distance_to(anchor) < 12.0
	if should_release:
		if str(_profile.secondary) == "rope_release":
			action.secondary = true
		else:
			action.auxiliary = true
		_next_pulse = _clock + 0.55
	else:
		action.auxiliary = false
		action.primary = false
	if rig_id == &"lineshank":
		action.secondary = absf(velocity.x) > 12.0
		action.aim = Vector2(_direction, -0.15).normalized()


func _start_pulse(interval: float) -> void:
	if _clock < _next_pulse:
		return
	_pulse_until = _clock + 0.11
	_next_pulse = _clock + maxf(interval, float(_profile.cooldown) + 0.1)


static func _near_wall(value: Variant) -> bool:
	if value is bool:
		return bool(value)
	if value is float or value is int:
		return is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 4.0
	return false


static func _in_flight_mode(observation: Dictionary) -> bool:
	var mode: Variant = observation.get("mode", observation.get("flight_mode", false))
	if mode is String or mode is StringName:
		return str(mode) == "flight"
	return bool(mode)
