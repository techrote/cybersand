class_name CyberPhysicalFlightTeacher
extends RefCounted

# 4LY-003 scripted navigation reference. Only the public v1 task observation
# enters here. This cannot access arena, native World, scenario geometry,
# evaluator state, future disturbances, profile names or the actuator itself.
const OBSERVATION_VERSION: String = "4ly-observation/v1"
const EPSILON: float = 0.00001
# The owner allows only copied self/relative-goal data and 8 local terrain
# rays. A bounded reactive Bug-style wall follower may remember its *own*
# former decisions; it never knows obstacle coordinates or a global route.
const DECISION_DT: float = 0.1
const ACQUIRE: int = 1
const TRAVERSE: int = 2
const MAX_AVOIDANCE_DECISIONS: int = 300

var _previous: Vector2 = Vector2.ZERO
var _avoidance_mode: int = 0
var _bypass_side: float = 0.0
var _forward_sign: float = 1.0
var _cleared_side_distance: float = 0.0
var _side_wall_seen: bool = false
var _side_clear_decisions: int = 0
var _avoidance_decisions: int = 0


func reset() -> void:
	_previous = Vector2.ZERO
	_avoidance_mode = 0
	_bypass_side = 0.0
	_forward_sign = 1.0
	_cleared_side_distance = 0.0
	_side_wall_seen = false
	_side_clear_decisions = 0
	_avoidance_decisions = 0


func action(observation: Dictionary) -> Dictionary:
	if str(observation.get("version", "")) != OBSERVATION_VERSION:
		return {"move": Vector2.ZERO}
	var delta: Vector2 = observation.get("goal_delta_cells", Vector2.INF)
	var velocity: Vector2 = observation.get("velocity_cells_per_second", Vector2.INF)
	var cap: Dictionary = observation.get("capabilities", {})
	if not delta.is_finite() or not velocity.is_finite():
		return {"move": Vector2.ZERO}
	if not cap.has("desired_speed") or not cap.has("braking") or not cap.has("acceleration") \
		or not cap.has("velocity_response_seconds") or not cap.has("thrust_response_seconds"):
		return {"move": Vector2.ZERO}
	var speeds := Vector2(float(cap.desired_speed[0]), float(cap.desired_speed[1]))
	var braking: float = maxf(float(cap.braking), 0.1)
	var acceleration: float = maxf(float(cap.acceleration), 0.1)
	var latency: float = maxf(0.0, float(cap.velocity_response_seconds) + float(cap.thrust_response_seconds))
	var radius: float = maxf(float(observation.get("arrival_radius_cells", 12.0)), 1.0)
	if speeds.x <= EPSILON or speeds.y <= EPSILON:
		return {"move": Vector2.ZERO}

	# Position/velocity planning anticipates measured stopping distance and the
	# published actuator response. No teleports, force/torque or privileged route.
	var desired := Vector2(
		_axis(delta.x, velocity.x, speeds.x, braking, acceleration, latency, radius),
		_axis(delta.y, velocity.y, speeds.y, braking, acceleration, latency, radius))
	var sensors: Dictionary = observation.get("local_obstacles", {})
	if bool(sensors.get("available", false)):
		desired = _avoid_local_obstacles(desired, sensors, speeds, velocity, delta, cap, radius)
	else:
		# Unavailable sensing is not a free map: relinquish route memory and
		# return to the admitted proprioceptive, goal-relative planner only.
		_avoidance_mode = 0
		_avoidance_decisions = 0
	var normalized := Vector2(desired.x / speeds.x, desired.y / speeds.y).limit_length(1.0)
	# Bounded command-rate smoothing; plant response/slew remains owned by the
	# unchanged 4LY actuator, and this filter has no force authority.
	var next: Vector2 = _previous.lerp(normalized, 0.62).limit_length(1.0)
	_previous = next
	return {"move": next}


static func _axis(offset: float, velocity: float, maximum: float, braking: float,
		acceleration: float, latency: float, radius: float) -> float:
	var remaining: float = absf(offset)
	var sign_value: float = signf(offset)
	# Braking starts before the nominal target: predicted coasting/response
	# distance must fit in the remaining space to the arrival region.
	var stop_distance: float = velocity * velocity / (2.0 * braking) + absf(velocity) * latency
	var usable: float = maxf(0.0, remaining - radius * 0.30)
	var speed_by_distance: float = sqrt(2.0 * braking * usable * 0.64)
	var speed_by_response: float = usable / maxf(latency * 1.75, 0.20)
	var target: float = sign_value * minf(maximum, minf(speed_by_distance, speed_by_response))
	if remaining < radius * 1.5:
		target = clampf(offset * 1.25, -maximum * 0.45, maximum * 0.45)
	# In the braking region command a smaller desired velocity than the body's
	# existing speed; the low-level physical controller supplies bounded brake.
	if stop_distance > remaining and velocity * offset > 0.0:
		target = minf(absf(target), maxf(0.0, absf(velocity) - acceleration * 0.18)) * sign_value
	if remaining < radius and absf(velocity) > 2.0:
		target = -velocity * 0.15
	return clampf(target, -maximum, maximum)


func _avoid_local_obstacles(target: Vector2, rays: Dictionary,
		speeds: Vector2, velocity: Vector2, goal_delta: Vector2,
		capabilities: Dictionary, radius: float) -> Vector2:
	var distances: Array = rays.get("distances", [])
	var valid: Array = rays.get("valid", [])
	var hits: Array = rays.get("hits", [])
	if distances.size() != 8 or valid.size() != 8 or hits.size() != 8:
		_avoidance_mode = 0
		return target
	for index: int in range(8):
		if not bool(valid[index]) or not is_finite(float(distances[index])):
			_avoidance_mode = 0
			return target
	var sensor_range: float = float(rays.get("maximum_distance_cells", 0.0))
	if not is_finite(sensor_range) or sensor_range < 8.0 or sensor_range > 96.0:
		_avoidance_mode = 0
		return target
	var footprint: Variant = capabilities.get("collider_size", [])
	if not footprint is Array or footprint.size() != 2:
		_avoidance_mode = 0
		return target
	var body_half_width: float = 0.5 * float(footprint[0])
	var body_half_height: float = 0.5 * float(footprint[1])
	if not is_finite(body_half_width) or not is_finite(body_half_height):
		_avoidance_mode = 0
		return target
	# Sensor directions are the *published* world-fixed R, NE, N, NW, L,
	# SW, S, SE. All navigation below consumes these same values as any
	# future learned policy; no hidden world, profile ID, scenario or route.
	var desired_sign: float = signf(goal_delta.x)
	var front_idx: int = 0 if desired_sign >= 0.0 else 4
	var ahead: float = float(distances[front_idx]) * sensor_range if bool(hits[front_idx]) else INF
	if _avoidance_mode == 0 and desired_sign != 0.0 \
		and absf(goal_delta.x) > radius + body_half_width * 2.0 \
		and ahead < sensor_range * 0.72:
		_bypass_side = _choose_bypass_side(distances, desired_sign, goal_delta.y)
		_forward_sign = desired_sign
		_avoidance_mode = ACQUIRE
		_cleared_side_distance = 0.0
		_side_wall_seen = false
		_side_clear_decisions = 0
		_avoidance_decisions = 0
	if _avoidance_mode == 0:
		return target

	_avoidance_decisions += 1
	# A short finite memory can bridge local sensor occlusions, but must not
	# turn into an unbounded privileged route-planning oracle.
	if _avoidance_decisions > MAX_AVOIDANCE_DECISIONS:
		_avoidance_mode = 0
		_avoidance_decisions = 0
		return target
	front_idx = 0 if _forward_sign > 0.0 else 4
	ahead = float(distances[front_idx]) * sensor_range if bool(hits[front_idx]) else INF
	var to_wall: float = velocity.x * _forward_sign
	if _avoidance_mode == ACQUIRE:
		# Slow before contact using *own velocity* and observed distance.
		# The physical 4LY controller, not this planner, chooses bounded
		# force/torque/braking and stays fully authoritative.
		var braking: float = maxf(float(capabilities.get("braking", 1.0)), 1.0)
		var latency: float = maxf(0.0, float(capabilities.get("velocity_response_seconds", 0.0))
			+ float(capabilities.get("thrust_response_seconds", 0.0)))
		var stopping: float = to_wall * to_wall / (2.0 * braking) + maxf(0.0, to_wall) * latency
		if is_finite(ahead):
			var margin: float = body_half_width + 9.0
			var remaining: float = ahead - margin - maxf(0.0, stopping)
			var forward_velocity: float = clampf(remaining * 1.25, -speeds.x * 0.35, speeds.x * 0.7)
			target.x = _forward_sign * minf(target.x * _forward_sign, forward_velocity)
			_cleared_side_distance = 0.0
		else:
			# First obtain extra physical body clearance, not merely a clear
			# centre-point ray. This matters for the heavy Hauler in gates.
			_cleared_side_distance += absf(velocity.y) * DECISION_DT
			target.x = _forward_sign * minf(target.x * _forward_sign, speeds.x * 0.34)
		target.y = _bypass_side * speeds.y * 0.78
		var travel_ray: int = 6 if _bypass_side > 0.0 else 2
		var clearance: float = float(distances[travel_ray]) * sensor_range
		if clearance < body_half_height + 11.0 and bool(hits[travel_ray]):
			target.y = 0.0
		if not is_finite(ahead) and _cleared_side_distance > body_half_height + 11.0:
			_avoidance_mode = TRAVERSE
			_side_clear_decisions = 0
			_side_wall_seen = false
	elif _avoidance_mode == TRAVERSE:
		# Hold the bypass lane against vertical momentum until the obstacle
		# has moved off the *side* ray. Pure target-seeking here steers back
		# through a wall (observed in previous actual-host failed episodes).
		target.y = clampf(-velocity.y * 0.85, -speeds.y * 0.65, speeds.y * 0.65)
		target.x = _forward_sign * minf(maxf(0.0, target.x * _forward_sign), speeds.x * 0.83)
		var side_idx: int = 2 if _bypass_side > 0.0 else 6
		if bool(hits[side_idx]) and float(distances[side_idx]) < 0.95:
			_side_wall_seen = true
			_side_clear_decisions = 0
		elif _side_wall_seen:
			_side_clear_decisions += 1
			if _side_clear_decisions >= 3:
				_avoidance_mode = 0
		# A newly blocked forward ray means a later wall/gate (potentially
		# the alternate leg of a slalom). Replan using *current local rays*.
		if ahead < sensor_range * 0.52 and _side_wall_seen:
			_avoidance_mode = 0
			_avoidance_decisions = 0
			return _avoid_local_obstacles(target, rays, speeds, velocity,
				goal_delta, capabilities, radius)
		# Guard against featureless passages where a side ray never struck;
		# without a sensed barrier, return to normal goal pursuit shortly.
		if not _side_wall_seen and _avoidance_decisions > 36:
			_avoidance_mode = 0

	return Vector2(clampf(target.x, -speeds.x, speeds.x),
		clampf(target.y, -speeds.y, speeds.y))


static func _choose_bypass_side(distances: Array, desired_sign: float,
		relative_goal_y: float) -> float:
	# Prefer the locally open diagonal/vertical directions. On a strict
	# tie use the goal-relative side, not a profile-specific/global route.
	var above_diag: int = 1 if desired_sign > 0.0 else 3
	var below_diag: int = 7 if desired_sign > 0.0 else 5
	var above: float = float(distances[above_diag]) * 0.8 + float(distances[2]) * 0.2
	var below: float = float(distances[below_diag]) * 0.8 + float(distances[6]) * 0.2
	if absf(above - below) < 0.07:
		return 1.0 if relative_goal_y >= 0.0 else -1.0
	return -1.0 if above > below else 1.0
