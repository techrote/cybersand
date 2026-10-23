class_name CyberPhysicalFlightProfile
extends RefCounted

# 4LY-001's finite, JSON-safe schema. These are authored game units, not SI
# calibration. 4LY-002 authors the four handling candidates; actual Rapier measurements
# and owner-feel admission must qualify these values before training.
const VERSION: int = 1
const ACTION_PROFILE: String = "4ly_velocity_v1"
const CONTROLLER_ID: String = "4ly-velocity-controller/v1"
const FIXED_DELTA: float = 1.0 / 60.0
const IDS: Array[StringName] = [&"4ly_trainer", &"4ly_hauler", &"4ly_drifter", &"4ly_dart"]
const NAMES: Dictionary = {&"4ly_trainer": "Trainer", &"4ly_hauler": "Hauler",
	&"4ly_drifter": "Drifter", &"4ly_dart": "Dart"}
const KEYS: Array[String] = ["version", "id", "family", "topology", "action_profile",
	"fixed_delta", "collider_size", "mass", "inertia", "gravity", "friction", "bounce", "desired_speed",
	"acceleration", "braking", "max_force", "velocity_response_seconds",
	"thrust_response_seconds", "max_force_slew", "linear_drag", "angular_drag",
	"attitude_kp", "attitude_kd", "max_torque", "max_torque_slew", "resource_mode", "calibration"]
const NUMERIC_LIMITS: Dictionary = {
	"mass": [0.02, 20.0], "inertia": [0.0001, 14000.0], "gravity": [0.0, 500.0],
	"friction": [0.0, 1.0], "bounce": [0.0, 0.6],
	"acceleration": [0.1, 1200.0], "braking": [0.1, 1200.0], "max_force": [0.001, 24000.0],
	"velocity_response_seconds": [1.0 / 600.0, 5.0],
	"thrust_response_seconds": [1.0 / 600.0, 5.0], "max_force_slew": [0.001, 1000000.0],
	"linear_drag": [0.0, 3.0], "angular_drag": [0.0, 8.0],
	"attitude_kp": [0.0, 100.0], "attitude_kd": [0.0, 40.0],
	"max_torque": [0.001, 1400000.0], "max_torque_slew": [0.001, 10000000.0],
}


static func has_rig(id: StringName) -> bool:
	return id in IDS


static func name_for(id: StringName) -> String:
	return str(NAMES.get(id, ""))


static func entry(id: StringName) -> Dictionary:
	if not has_rig(id):
		return {}
	# 4LY-002 handling candidates. Every profile is a complete instance of the
	# same validated topology/actuator schema, never a branch in navigation code.
	# Calibration remains candidate until actual-host measurements are accepted.
	var value: Dictionary = {"version": VERSION, "id": str(id), "family": "4ly",
		"topology": "single_rectangle", "action_profile": ACTION_PROFILE,
		"fixed_delta": FIXED_DELTA, "collider_size": [10.0, 6.0],
		"mass": 1.2, "inertia": 13.6, "gravity": 156.0,
		"friction": 0.82, "bounce": 0.04, "desired_speed": [48.0, 36.0],
		"acceleration": 90.0, "braking": 135.0, "max_force": 360.0,
		"velocity_response_seconds": 0.25, "thrust_response_seconds": 0.06,
		"max_force_slew": 2400.0, "linear_drag": 0.05, "angular_drag": 0.25,
		"attitude_kp": 18.0, "attitude_kd": 8.0, "max_torque": 300.0,
		"max_torque_slew": 3600.0, "resource_mode": "continuous_authored_power",
		"calibration": "candidate_4ly002"}
	match id:
		&"4ly_hauler":
			value.merge({"collider_size": [16.0, 10.0], "mass": 3.6,
				"desired_speed": [27.0, 23.0], "acceleration": 38.0,
				"braking": 55.0, "max_force": 1100.0,
				"velocity_response_seconds": 0.60, "thrust_response_seconds": 0.18,
				"max_force_slew": 4800.0, "linear_drag": 0.035,
				"angular_drag": 0.30, "attitude_kp": 14.0, "attitude_kd": 7.0,
				"max_torque": 3000.0, "max_torque_slew": 16000.0}, true)
		&"4ly_drifter":
			value.merge({"collider_size": [12.0, 7.0], "mass": 1.55,
				"desired_speed": [50.0, 33.0], "acceleration": 64.0,
				"braking": 48.0, "max_force": 460.0,
				"velocity_response_seconds": 0.45, "thrust_response_seconds": 0.10,
				"max_force_slew": 2600.0, "linear_drag": 0.012,
				"angular_drag": 0.27, "attitude_kp": 20.0, "attitude_kd": 9.0,
				"max_torque": 470.0, "max_torque_slew": 3800.0}, true)
		&"4ly_dart":
			value.merge({"collider_size": [6.0, 4.0], "mass": 0.55,
				"desired_speed": [84.0, 58.0], "acceleration": 250.0,
				"braking": 320.0, "max_force": 235.0,
				"velocity_response_seconds": 0.135, "thrust_response_seconds": 0.035,
				"max_force_slew": 4600.0, "linear_drag": 0.09,
				"angular_drag": 0.32, "attitude_kp": 25.0, "attitude_kd": 9.0,
				"max_torque": 135.0, "max_torque_slew": 2400.0}, true)
	# A single rectangular body has the declared planar inertia; recalculating
	# it from data prevents accidental mismatch after changing the footprint.
	var width: float = float(value.collider_size[0])
	var height: float = float(value.collider_size[1])
	value.inertia = float(value.mass) * (width * width + height * height) / 12.0
	return value

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != KEYS.size():
		return "flight profile field set"
	for key: Variant in value:
		if not key is String or key not in KEYS:
			return "unknown flight profile field"
	for key: String in KEYS:
		if not value.has(key):
			return "missing flight profile field: " + key
	if not _number(value.version) or float(value.version) != VERSION:
		return "flight profile version"
	if not value.id is String or not has_rig(StringName(value.id)):
		return "flight profile id"
	for pair: Array in [["family", "4ly"], ["topology", "single_rectangle"],
		["action_profile", ACTION_PROFILE], ["resource_mode", "continuous_authored_power"]]:
		if not value[pair[0]] is String or value[pair[0]] != pair[1]:
			return "flight profile identity: " + str(pair[0])
	if not value.calibration is String or value.calibration not in ["conformance_only", "uncalibrated_placeholder", "candidate_4ly002", "measured_4ly002"]:
		return "flight profile calibration status"
	if not _number(value.fixed_delta) or absf(float(value.fixed_delta) - FIXED_DELTA) > 0.000000001:
		return "flight profile requires 60 Hz"
	for key: String in NUMERIC_LIMITS:
		var limits: Array = NUMERIC_LIMITS[key]
		if not _number(value[key]) or float(value[key]) < float(limits[0]) or float(value[key]) > float(limits[1]):
			return "flight profile range: " + key
	if not _pair(value.collider_size, 0.5, 64.0):
		return "flight collider size"
	if not _pair(value.desired_speed, 0.1, 240.0):
		return "flight desired speed"
	var width: float = float(value.collider_size[0])
	var height: float = float(value.collider_size[1])
	var inertia: float = float(value.mass) * (width * width + height * height) / 12.0
	if absf(float(value.inertia) - inertia) > maxf(0.000001, inertia * 0.000001):
		return "flight inertia must match rectangular chassis"
	if float(value.max_force) > float(value.mass) * 1200.0:
		return "flight force exceeds plant acceleration envelope"
	if float(value.max_torque) > float(value.inertia) * 100.0:
		return "flight torque exceeds plant angular envelope"
	return ""


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _pair(value: Variant, minimum: float, maximum: float) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for component: Variant in value:
		if not _number(component) or float(component) < minimum or float(component) > maximum:
			return false
	return true


static func resolved(value: Variant) -> Dictionary:
	if not validate(value).is_empty():
		return {}
	var result: Dictionary = value.duplicate(true)
	result.version = VERSION
	result.fixed_delta = FIXED_DELTA
	for key: String in NUMERIC_LIMITS:
		result[key] = float(result[key])
	for key: String in ["collider_size", "desired_speed"]:
		result[key] = [float(result[key][0]), float(result[key][1])]
	return result


static func profile_hash(value: Variant) -> String:
	var profile: Dictionary = resolved(value)
	if profile.is_empty():
		return ""
	# Sorted keys and round-trip float precision make input key order irrelevant
	# while preserving sub-display-precision tuning changes in the identity.
	return JSON.stringify(profile, "", true, true).sha256_text()


static func descriptor(value: Variant) -> Dictionary:
	var result: Dictionary = resolved(value)
	if result.is_empty():
		return {}
	result["profile_hash"] = profile_hash(result)
	result["controller_id"] = CONTROLLER_ID
	result["units"] = {"distance": "cell", "time": "second", "mass": "authored_mass",
		"velocity": "cell/second", "force": "authored_mass*cell/second^2",
		"torque": "authored_mass*cell^2/second^2", "angle": "radian"}
	result["axes"] = "world frame: +x right, +y down"
	result["speed_mapping"] = "unit-disk move multiplied componentwise by desired_speed"
	result["default_loadout"] = "none"
	result["fallback"] = "passive_unpowered"
	result["neutral"] = "zero desired velocity; bounded braking and gravity compensation; no position target"
	result["resource_behavior"] = "continuous authored supply; no fuel timer or reserve drain"
	# Policy-visible STATIC physical capabilities: no name, evaluator outcome,
	# route or privileged observation is embedded in this sub-descriptor.
	result["capabilities"] = {
		"collider_size": result.collider_size.duplicate(),
		"mass": result.mass, "inertia": result.inertia,
		"desired_speed": result.desired_speed.duplicate(),
		"acceleration": result.acceleration, "braking": result.braking,
		"velocity_response_seconds": result.velocity_response_seconds,
		"thrust_response_seconds": result.thrust_response_seconds,
		"max_force_slew": result.max_force_slew,
		"max_force": result.max_force, "gravity": result.gravity,
		"vertical_force_margin": result.max_force - result.mass * result.gravity,
		"linear_drag": result.linear_drag, "angular_drag": result.angular_drag,
		"attitude_kp": result.attitude_kp, "attitude_kd": result.attitude_kd,
		"max_torque": result.max_torque, "max_torque_slew": result.max_torque_slew}
	return result
