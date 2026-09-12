class_name CyberWaterExperimentProfiles
extends RefCounted

const Contract = preload("res://scripts/water_experiment_contract.gd")
const MAX_PROFILE_BYTES: int = 65_536
const MAX_SEED: int = 2_147_483_647
const SOURCES: Array[String] = ["default", "profile", "launch", "panel"]
const COHERENCE_NAMES: Dictionary = {
	"current": 12,
	"three-bit": 7,
	"short": 3,
	"none": 0,
}
const LAUNCH_KEYS: Dictionary = {
	"--water-policy-version": "version",
	"--water-mass-bits": "mass_bits",
	"--water-coherence": "coherence_ticks",
	"--water-rest-policy": "rest_policy",
	"--water-render-levels": "render_fill_levels",
	"--water-interface": "interface_mode",
	"--experiment": "scenario_id",
	"--seed": "seed",
}


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func _integer(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	if value is String and value.is_valid_int() and str(int(value)) == value:
		return int(value)
	return null


static func _normalize_value(key: String, value: Variant) -> Dictionary:
	if key == "coherence_ticks" and value is String and COHERENCE_NAMES.has(value):
		value = COHERENCE_NAMES[value]
	if key in ["version", "mass_bits", "coherence_ticks", "render_fill_levels", "seed"]:
		var number: Variant = _integer(value)
		if number == null:
			return _failure("%s must be an integer" % key)
		var valid: bool = (
			(key == "version" and number == Contract.VERSION)
			or (key == "mass_bits" and number >= 3 and number <= 8)
			or (key == "coherence_ticks" and number >= 0 and number <= 12)
			or (key == "render_fill_levels" and number == 4)
			or (key == "seed" and number >= 0 and number <= MAX_SEED)
		)
		return {"ok": true, "value": int(number)} if valid else _failure("%s is outside its registered domain" % key)
	if not value is String:
		return _failure("%s must be a string" % key)
	if key == "rest_policy" and value != Contract.REST_POLICY:
		return _failure("unsupported Water rest policy")
	if key == "interface_mode" and not value in Contract.INTERFACE_MODES:
		return _failure("unsupported Water interface mode")
	if key == "scenario_id" and not Contract.valid_scenario(value):
		return _failure("unknown Water Feel scenario")
	return {"ok": true, "value": value}


static func _normalize_layer(input: Variant, source: String, require_version: bool) -> Dictionary:
	if not source in SOURCES:
		return _failure("unknown policy source")
	if not input is Dictionary:
		return _failure("%s policy layer must be an object" % source)
	if input.is_empty():
		return {"ok": true, "values": {}}
	if require_version and not input.has("version"):
		return _failure("profile policy requires version 1")
	var values: Dictionary = {}
	for raw_key: Variant in input:
		if not raw_key is String or not raw_key in Contract.POLICY_KEYS:
			return _failure("unknown %s policy field" % source)
		var parsed: Dictionary = _normalize_value(raw_key, input[raw_key])
		if not parsed.ok:
			return parsed
		values[raw_key] = parsed.value
	return {"ok": true, "values": values}


static func parse_profile(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_PROFILE_BYTES:
		return _failure("Water policy profile exceeds 64 KiB")
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return _failure(parser.get_error_message())
	return _normalize_layer(parser.data, "profile", true)


static func parse_config(text: String) -> Dictionary:
	return parse_profile(text)


static func parse_launch(arguments: PackedStringArray) -> Dictionary:
	var raw: Dictionary = {}
	var index: int = 0
	while index < arguments.size():
		var argument: String = arguments[index]
		var option: String = argument
		var value: String = ""
		if "=" in argument:
			option = argument.get_slice("=", 0)
			value = argument.substr(option.length() + 1)
		elif LAUNCH_KEYS.has(option):
			index += 1
			if index >= arguments.size():
				return _failure("missing value for %s" % option)
			value = arguments[index]
		if LAUNCH_KEYS.has(option):
			var key: String = LAUNCH_KEYS[option]
			if raw.has(key):
				return _failure("duplicate launch field %s" % key)
			if value.is_empty():
				return _failure("missing value for %s" % option)
			raw[key] = value
		index += 1
	return _normalize_layer(raw, "launch", false)


static func canonical_json(policy: Dictionary) -> String:
	return (
		'{"version":%d,"mass_bits":%d,"coherence_ticks":%d,"rest_policy":%s,'
		+ '"render_fill_levels":%d,"interface_mode":%s,"scenario_id":%s,"seed":%d}'
	) % [
		int(policy.version),
		int(policy.mass_bits),
		int(policy.coherence_ticks),
		JSON.stringify(str(policy.rest_policy)),
		int(policy.render_fill_levels),
		JSON.stringify(str(policy.interface_mode)),
		JSON.stringify(str(policy.scenario_id)),
		int(policy.seed),
	]


static func validate(policy: Variant) -> Dictionary:
	var normalized: Dictionary = _normalize_layer(policy, "panel", true)
	if not normalized.ok:
		return normalized
	if normalized.values.size() != Contract.POLICY_KEYS.size():
		return _failure("effective Water policy must contain every registered field")
	var ordered: Dictionary = {}
	for key: String in Contract.POLICY_KEYS:
		if not normalized.values.has(key):
			return _failure("effective Water policy is missing %s" % key)
		ordered[key] = normalized.values[key]
	return {"ok": true, "policy": ordered}


static func resolve(
	profile_input: Variant = {}, launch_input: Variant = {}, panel_input: Variant = {}
) -> Dictionary:
	var profile: Dictionary
	if profile_input is String:
		profile = parse_profile(profile_input)
	elif profile_input is Dictionary:
		profile = _normalize_layer(profile_input, "profile", not profile_input.is_empty())
	else:
		profile = _normalize_layer(profile_input, "profile", false)
	if not profile.ok:
		return profile
	var launch: Dictionary = (
		parse_launch(launch_input)
		if launch_input is PackedStringArray
		else _normalize_layer(launch_input, "launch", false)
	)
	if not launch.ok:
		return launch
	var panel: Dictionary = _normalize_layer(panel_input, "panel", false)
	if not panel.ok:
		return panel

	var policy: Dictionary = Contract.default_policy().duplicate(true)
	var origins: Dictionary = {}
	for key: String in Contract.POLICY_KEYS:
		origins[key] = "default"
	var effective_source: String = "default"
	var applied_layers: Array[String] = []
	for layer: Dictionary in [
		{"source": "profile", "values": profile.values},
		{"source": "launch", "values": launch.values},
		{"source": "panel", "values": panel.values},
	]:
		if layer.values.is_empty():
			continue
		effective_source = layer.source
		applied_layers.append(layer.source)
		for key: String in Contract.POLICY_KEYS:
			if layer.values.has(key):
				policy[key] = layer.values[key]
				origins[key] = layer.source

	var checked: Dictionary = validate(policy)
	if not checked.ok:
		return checked
	policy = checked.policy
	var canonical: String = canonical_json(policy)
	var maximum: int = (1 << int(policy.mass_bits)) - 1
	var quantize: Callable = func(numerator: int) -> int:
		return int((2 * numerator * maximum + 255) / (2 * 255))
	return {
		"ok": true,
		"policy": policy.duplicate(true),
		"canonical_json": canonical,
		"hash": canonical.sha256_text(),
		"semantic": PackedInt32Array([
			Contract.VERSION,
			int(policy.mass_bits),
			int(policy.coherence_ticks),
			0,
		]),
		"derived": {
			"maximum": maximum,
			"film": quantize.call(48),
			"tolerance": quantize.call(1),
		},
		"source": effective_source,
		"provenance": {
			"effective_source": effective_source,
			"field_origins": origins.duplicate(true),
			"applied_layers": applied_layers.duplicate(),
		},
	}


static func resolve_profile_text(
	profile_text: String, launch_arguments: PackedStringArray, panel_input: Dictionary = {}
) -> Dictionary:
	var profile: Dictionary = parse_profile(profile_text)
	if not profile.ok:
		return profile
	return resolve(profile.values, launch_arguments, panel_input)
