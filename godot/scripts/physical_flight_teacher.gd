class_name CyberPhysicalFlightTeacher
extends RefCounted

# 4LY-003 scripted navigation reference. Only the public v1 task observation
# enters here. This cannot access arena, native World, scenario geometry,
# evaluator state, future disturbances, profile names or the actuator itself.
const OBSERVATION_VERSION: String = "4ly-observation/v1"
const EPSILON: float = 0.00001
var _previous: Vector2 = Vector2.ZERO


func reset() -> void:
	_previous = Vector2.ZERO


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
		desired = _avoid_local_obstacles(desired, sensors, speeds, velocity)
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


static func _avoid_local_obstacles(target: Vector2, rays: Dictionary,
		speeds: Vector2, velocity: Vector2) -> Vector2:
	var distances: Array = rays.get("distances", [])
	var valid: Array = rays.get("valid", [])
	if distances.size() != 8 or valid.size() != 8:
		return target
	for index: int in range(8):
		if not bool(valid[index]) or not is_finite(float(distances[index])):
			return target
	# World-fixed directions R, NE, N, NW, L, SW, S, SE. A local-only
	# potential-field correction is deterministic and has no global plan.
	var forward: int = 0 if target.x >= 0.0 else 4
	var oblique_a: int = 1 if forward == 0 else 3
	var oblique_b: int = 7 if forward == 0 else 5
	var front: float = float(distances[forward])
	if absf(target.x) > 1.0 and front < 0.55:
		var clearance_up: float = float(distances[oblique_a]) + float(distances[2])
		var clearance_down: float = float(distances[oblique_b]) + float(distances[6])
		var side: float = -1.0 if clearance_up >= clearance_down else 1.0
		var risk: float = clampf((0.55 - front) / 0.45, 0.0, 1.0)
		target.x *= 1.0 - risk * 0.90
		target.y += side * speeds.y * 0.66 * risk
	var vertical: int = 6 if target.y >= 0.0 else 2
	if absf(target.y) > 1.0 and float(distances[vertical]) < 0.28:
		target.y *= clampf(float(distances[vertical]) / 0.28, 0.0, 1.0)
	if front < 0.20 and absf(velocity.x) > 1.0:
		target.x = -velocity.x * 0.25
	return Vector2(clampf(target.x, -speeds.x, speeds.x),
		clampf(target.y, -speeds.y, speeds.y))
