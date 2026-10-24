class_name CyberPhysicalFlightObservationAdapter
extends RefCounted

# Stable flat numeric interface for future 4LY-004 policies. Evaluator-only
# state never reaches this adapter. Reject wrong versions/nonfinite values.
const VERSION: String = "4ly-flat-observation/v1"
const SOURCE_VERSION: String = "4ly-observation/v1"
const MODE_ORDER: Array[String] = [
	"velocity", "neutral", "passive_no_lease", "power_off", "other"
]
const CAPABILITY_ORDER: Array[String] = [
	"collider_width", "collider_height", "mass", "inertia",
	"speed_x", "speed_y", "acceleration", "braking",
	"thrust_response_seconds", "velocity_response_seconds", "max_force",
	"gravity", "vertical_force_margin", "angular_drag"
]
const LENGTH: int = 54


static func _bounded(value: Variant, scale: float, limit: float = 4.0) -> float:
	if not (value is int or value is float) or not is_finite(float(value)) or scale <= 0.0:
		return NAN
	return clampf(float(value) / scale, -limit, limit)


static func flatten(observation: Dictionary) -> Dictionary:
	if str(observation.get("version", "")) != SOURCE_VERSION:
		return {}
	var goal: Variant = observation.get("goal_delta_cells")
	var velocity: Variant = observation.get("velocity_cells_per_second")
	var cap: Dictionary = observation.get("capabilities", {})
	if not goal is Vector2 or not velocity is Vector2 or not Vector2(goal).is_finite() \
		or not Vector2(velocity).is_finite() or not cap.has("collider_size") \
		or not cap.has("desired_speed") or not cap.has("inertia"):
		return {}
	var sizes: Variant = cap.collider_size
	var speeds: Variant = cap.desired_speed
	if not sizes is Array or sizes.size() != 2 or not speeds is Array or speeds.size() != 2:
		return {}
	var output: Array[float] = []
	for v: float in [_bounded(goal.x, 512.0, 1.0), _bounded(goal.y, 512.0, 1.0),
		_bounded(velocity.x, float(speeds[0])), _bounded(velocity.y, float(speeds[1])),
		_bounded(observation.get("orientation_sin", NAN), 1.0, 1.0),
		_bounded(observation.get("orientation_cos", NAN), 1.0, 1.0),
		_bounded(observation.get("angular_velocity_rad_per_second", NAN), 8.0)]:
		output.append(v)
	var mode: String = str(observation.get("actuator_mode", "other"))
	if mode not in MODE_ORDER:
		mode = "other"
	for item: String in MODE_ORDER:
		output.append(1.0 if item == mode else 0.0)
	output.append(_bounded(observation.get("command_age_ticks", -1), 18.0, 1.0))
	output.append(1.0 if bool(observation.get("command_live", false)) else 0.0)
	output.append(_bounded(observation.get("lease_remaining_ticks", -1), 18.0, 1.0))
	var resource: Dictionary = observation.get("resources", {})
	output.append(1.0 if bool(resource.get("powered", false)) else 0.0)
	var cap_values: Array = [
		sizes[0], sizes[1], cap.get("mass", NAN), cap.get("inertia", NAN),
		speeds[0], speeds[1], cap.get("acceleration", NAN),
		cap.get("braking", NAN), cap.get("thrust_response_seconds", NAN),
		cap.get("velocity_response_seconds", NAN), cap.get("max_force", NAN),
		cap.get("gravity", NAN), cap.get("vertical_force_margin", NAN),
		cap.get("angular_drag", NAN)]
	var normalizers: Array[float] = [
		64.0, 64.0, 20.0, 14000.0, 240.0, 240.0, 1200.0, 1200.0,
		5.0, 5.0, 24000.0, 500.0, 24000.0, 8.0]
	for index: int in range(cap_values.size()):
		output.append(_bounded(cap_values[index], normalizers[index], 1.0))
	var sensing: Dictionary = observation.get("local_obstacles", {})
	var distances: Array = sensing.get("distances", [])
	var hits: Array = sensing.get("hits", [])
	var masks: Array = sensing.get("valid", [])
	var sensed: bool = bool(sensing.get("available", false)) \
		and distances.size() == 8 and hits.size() == 8 and masks.size() == 8
	for index: int in range(8):
		output.append(_bounded(distances[index], 1.0, 1.0) if sensed and bool(masks[index]) else 0.0)
	for index: int in range(8):
		output.append(1.0 if sensed and bool(masks[index]) and bool(hits[index]) else 0.0)
	for index: int in range(8):
		output.append(1.0 if sensed and bool(masks[index]) else 0.0)
	if output.size() != LENGTH:
		return {}
	for v: float in output:
		if not is_finite(v):
			return {}
	return {"version": VERSION, "field_count": LENGTH, "values": output}
