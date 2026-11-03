extends SceneTree

const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var assertions: int = 0
var failures: int = 0


func expect(passed: bool, message: String) -> void:
	assertions += 1
	if not passed:
		failures += 1
		push_error("CI_EXECUTION_POLICY_TEST: " + message)


func _initialize() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(Watchdogs.POLICY_PATH))
	var original: Dictionary = Watchdogs.validate_policy(source)
	expect(original.ok, "committed policy parses and supplies every named workload")
	if not original.ok:
		quit(1)
		return
	var runtime: Dictionary = Watchdogs.identity()
	print("CYBERSAND_CI_POLICY ", JSON.stringify(runtime))
	expect(runtime.ok and runtime.schema_version == 1 and runtime.sha256.length() == 64,
		"effective policy identifies its schema and exact committed bytes")
	var scale_text: String = OS.get_environment(Watchdogs.SCALE_ENV)
	var requested_scale: float = 1.0 if scale_text.is_empty() else float(scale_text)
	expect(runtime.scale == requested_scale, "runtime policy observes the requested environment scale")
	for key: String in Watchdogs.REQUIRED_KEYS:
		expect(runtime.watchdogs[key] == original.watchdogs[key] * requested_scale,
			key + " applies the environment scale exactly once")
		if key.ends_with("_seconds"):
			expect(Watchdogs.milliseconds(key) == ceili(float(runtime.watchdogs[key]) * 1000.0)
				and Watchdogs.microseconds(key) == ceili(float(runtime.watchdogs[key]) * 1000000.0),
				key + " uses one policy in every time unit")
	var doubled: Dictionary = Watchdogs.validate_policy(source, "2")
	expect(doubled.ok, "a larger explicit execution allowance is admitted")
	for key: String in Watchdogs.REQUIRED_KEYS:
		expect(doubled.watchdogs[key] == original.watchdogs[key] * 2.0,
			key + " is scaled once without a shorter hidden default")
	for text: String in ["0", "0.5", "-1", "nan", "inf", "not-a-number", "1e300"]:
		expect(not Watchdogs.validate_policy(source, text).ok,
			"invalid or shortening environment scale is rejected: " + text)
	for invalid: Variant in [null, [], "policy"]:
		expect(not Watchdogs.validate_policy(invalid).ok,
			"non-object input cannot become a default policy")
	var changed: Dictionary = source.duplicate(true)
	changed.schema_version = 2
	expect(not Watchdogs.validate_policy(changed).ok, "unknown schema cannot silently change semantics")
	changed = source.duplicate(true)
	changed.schema_version = true
	expect(not Watchdogs.validate_policy(changed).ok, "boolean schema is not an integer version")
	for key: String in Watchdogs.REQUIRED_KEYS:
		changed = source.duplicate(true)
		changed.watchdogs.erase(key)
		expect(not Watchdogs.validate_policy(changed).ok, "missing required workload fails closed: " + key)
		for invalid: Variant in [0, -1, true, "300", INF, NAN]:
			changed = source.duplicate(true)
			changed.watchdogs[key] = invalid
			expect(not Watchdogs.validate_policy(changed).ok,
				"invalid watchdog cannot masquerade as a positive duration: " + key)
	changed = source.duplicate(true)
	changed.watchdogs.complex_fixture_seconds = 1
	expect(not Watchdogs.validate_policy(changed).ok, "fixture allowance cannot undercut setup or operations")
	runtime.watchdogs.operation_seconds = 0
	expect(Watchdogs.seconds("operation_seconds") > 0,
		"mutating an evidence copy cannot change the running policy")
	print("CI_EXECUTION_POLICY_TEST: %d assertions; %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
