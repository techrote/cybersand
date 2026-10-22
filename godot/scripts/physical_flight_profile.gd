class_name CyberPhysicalFlightProfile
extends RefCounted

# 4LY-001's finite, JSON-safe schema. These are authored game units, not SI
# calibration. Only Trainer's conformance defaults are supplied here. The other
# reserved IDs deliberately share those values until 4LY-002 measures handling.
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
	return {"version": VERSION, "id": str(id), "family": "4ly", "topology": "single_rectangle",
		"action_profile": ACTION_PROFILE, "fixed_delta": FIXED_DELTA,
		"collider_size": [10.0, 6.0], "mass": 1.2, "inertia": 13.6, "gravity": 156.0,
		"friction": 0.82, "bounce": 0.04,
		"desired_speed": [48.0, 36.0], "acceleration": 90.0, "braking": 135.0,
		"max_force": 360.0, "velocity_response_seconds": 0.25,
		"thrust_response_seconds": 0.06, "max_force_slew": 2400.0,
		"linear_drag": 0.05, "angular_drag": 0.25,
		"attitude_kp": 18.0, "attitude_kd": 8.0, "max_torque": 300.0,
		"max_torque_slew": 3600.0, "resource_mode": "continuous_authored_power",
		"calibration": "conformance_only" if id == &"4ly_trainer" else "uncalibrated_placeholder"}


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
	if not value.calibration is String or value.calibration not in ["conformance_only", "uncalibrated_placeholder"]:
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
	return result
