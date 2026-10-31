extends RefCounted

# Test execution allowances only. Simulation ticks, control leases, sampling
# windows and gameplay responsiveness contracts must not consume this policy.
const POLICY_PATH: String = "res://tests/support/ci_execution_policy.json"
const SCALE_ENV: String = "CYBERSAND_CI_WATCHDOG_SCALE"
const REQUIRED_KEYS: Array[String] = [
	"main_ack_seconds", "graphical_case_seconds", "godot_import_seconds",
	"operation_seconds", "complex_fixture_seconds", "hosted_job_minutes",
	"diagnostic_capture_seconds", "terminate_grace_seconds",
]


static func validate_policy(document: Variant, scale_text: String = "") -> Dictionary:
	if not document is Dictionary:
		return {"ok":false, "error":"execution policy must be an object"}
	if typeof(document.get("schema_version")) not in [TYPE_INT, TYPE_FLOAT] \
		or document.schema_version != 1:
		return {"ok":false, "error":"unsupported execution policy schema"}
	if not document.get("watchdogs") is Dictionary:
		return {"ok":false, "error":"execution policy watchdogs must be an object"}
	var scale: float = 1.0
	if not scale_text.is_empty():
		if not scale_text.is_valid_float():
			return {"ok":false, "error":"watchdog scale must be a finite number >= 1"}
		scale = float(scale_text)
	if not is_finite(scale) or scale < 1.0:
		return {"ok":false, "error":"watchdog scale must be a finite number >= 1"}
	var effective: Dictionary = {}
	for key: String in REQUIRED_KEYS:
		var value: Variant = document.watchdogs.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) \
			or float(value) <= 0.0:
			return {"ok":false, "error":"missing or invalid positive watchdog: " + key}
		var scaled: float = float(value) * scale
		# Preserve exact integer microsecond conversion without overflow.
		if not is_finite(scaled) or scaled > 9000000000000.0:
			return {"ok":false, "error":"watchdog conversion would overflow: " + key}
		effective[key] = scaled
	if effective.main_ack_seconds > effective.complex_fixture_seconds \
		or effective.operation_seconds > effective.complex_fixture_seconds:
		return {"ok":false, "error":"fixture watchdog must include setup and operation allowances"}
	return {"ok":true, "schema_version":1, "scale":scale, "watchdogs":effective}


static func _read_policy() -> Dictionary:
	# These calls happen at fixture boundaries, never per simulation tick. Keep
	# the small read stateless: static script state retains a GDScript resource
	# through this project's default-host dependency graph at engine teardown.
	var parser := JSON.new()
	var bytes: String = FileAccess.get_file_as_string(POLICY_PATH)
	var result: Dictionary
	if parser.parse(bytes) != OK:
		result = {"ok":false, "error":"cannot parse execution policy: " + parser.get_error_message()}
	else:
		result = validate_policy(parser.data, OS.get_environment(SCALE_ENV))
	result["path"] = POLICY_PATH
	result["sha256"] = FileAccess.get_sha256(POLICY_PATH)
	if not result.ok:
		push_error("CI_EXECUTION_POLICY: " + str(result.error))
	else:
		result.watchdogs.make_read_only()
	result.make_read_only()
	return result


static func identity() -> Dictionary:
	return _read_policy().duplicate(true)


static func seconds(key: String) -> float:
	var policy: Dictionary = _read_policy()
	if not bool(policy.ok):
		return 0.0 # Fail closed: a missing policy cannot silently restore short limits.
	if not key.ends_with("_seconds") or not policy.watchdogs.has(key):
		push_error("CI_EXECUTION_POLICY: unknown seconds watchdog " + key)
		return 0.0
	return float(policy.watchdogs[key])


static func milliseconds(key: String) -> int:
	return ceili(seconds(key) * 1000.0)


static func microseconds(key: String) -> int:
	return ceili(seconds(key) * 1000000.0)
