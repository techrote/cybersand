extends RefCounted

# Authored values only. Runtime module memory, RNG state, leases and physical
# state never enter a profile or an ordinary Workbench save.
const Modules = preload("res://scripts/ambient/ambient_modules.gd")
const VERSION := 1
const MAX_MODULES := 16
const MAX_MATERIALS := 8
const MAX_SEED := 2147483647
const PROFILE_KEYS := ["version", "id", "name", "description", "seed", "shared_seed", "modules"]
const MODULE_KEYS := ["id", "type", "enabled", "priority", "weight", "params"]
const PRESETS_PATH := "res://data/ambient/profiles.json"


static func _keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key: Variant in value:
		if not key is String or key not in expected: return false
	return value.has_all(expected)


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) >= low and float(value) <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))


static func _identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64: return false
	for code: int in value.length():
		var character: int = value.unicode_at(code)
		if not ((character >= 48 and character <= 57) or (character >= 65 and character <= 90) \
			or (character >= 97 and character <= 122) or character == 45 or character == 95):
			return false
	return true


static func _text(value: Variant, maximum: int, allow_empty: bool = true) -> bool:
	if not value is String or value.length() > maximum: return false
	if not allow_empty and value.strip_edges().is_empty(): return false
	for index: int in value.length():
		var character: int = value.unicode_at(index)
		if character < 32 and character not in [9, 10]: return false
	return true


static func module_types() -> Array:
	return Modules.module_specs().keys()


static func module_spec(type: String) -> Dictionary:
	return Modules.module_specs().get(type, {}).duplicate(true)


static func make_module(type: String, instance_id: String = "") -> Dictionary:
	var spec := module_spec(type)
	if spec.is_empty(): return {}
	var parameters := {}
	for key: String in spec.params:
		parameters[key] = spec.params[key].default
	return {"id": type if instance_id.is_empty() else instance_id, "type": type, "enabled": true,
		"priority": int(spec.get("priority", 0)), "weight": float(spec.get("weight", 1.0)),
		"params": parameters}


static func material_ids(profile: Dictionary) -> Array:
	var result: Array = []
	for module: Variant in profile.get("modules", []):
		if not module is Dictionary: continue
		var parameters: Variant = module.get("params", {})
		if not parameters is Dictionary or not parameters.has("material_id"): continue
		var value: Variant = parameters.material_id
		if (value is int or value is float) and int(value) not in result:
			result.append(int(value))
	result.sort()
	return result


static func _material(value: Variant, admitted: Array) -> bool:
	# Accepted native/include/cybersand/material.hpp: stable IDs 0..131, unused
	# slot 10. Empty (0) is not a material attraction target. The live editor
	# additionally supplies IDs from inspect_material_catalogue, never colours.
	return _integer(value, 1, 131) and int(value) != 10 \
		and (admitted.is_empty() or int(value) in admitted)


static func _parameter_error(key: String, value: Variant, spec: Dictionary, admitted: Array) -> String:
	var type := str(spec.get("type", "float"))
	if type in ["bool", "boolean"]:
		return "" if value is bool else key + " must be true or false."
	if type in ["int", "integer", "material"]:
		if not _integer(value, int(spec.get("min", 0)), int(spec.get("max", MAX_SEED))):
			return "%s must be an integer from %s to %s." % [key, spec.get("min", 0), spec.get("max", MAX_SEED)]
	elif type in ["float", "number"]:
		if not _number(value, float(spec.get("min", 0.0)), float(spec.get("max", 1.0))):
			return "%s must be finite and from %s to %s." % [key, spec.get("min", 0.0), spec.get("max", 1.0)]
	else:
		return "Unknown parameter schema: " + key
	if key == "material_id" and not _material(value, admitted):
		return "Unknown, reserved or unavailable material ID: " + str(value)
	return ""


static func _relations(module: Dictionary) -> String:
	var p: Dictionary = module.params
	match str(module.type):
		"seek_material":
			if float(p.standoff) + float(p.hysteresis) > float(p.radius):
				return "Approach distance plus hysteresis must fit inside the material radius."
		"avoid_material":
			if float(p.enter_distance) > float(p.exit_distance) or float(p.exit_distance) > float(p.radius):
				return "Material avoidance requires enter distance ≤ exit distance ≤ radius."
		"avoid_boundary":
			if float(p.margin) > float(p.release_margin):
				return "Boundary release margin must be at least the entry margin."
		"return_home":
			if float(p.release_radius) > float(p.radius):
				return "Home release radius must not exceed the entry radius."
		"follow_actor":
			if float(p.separation) + float(p.hysteresis) > float(p.radius):
				return "Preferred separation plus hysteresis must fit inside the observed actor radius."
	return ""


static func validate(value: Variant, admitted_material_ids: Array = [], capabilities: Variant = []) -> String:
	if not value is Dictionary or not _keys(value, PROFILE_KEYS):
		return "Missing or unknown ambient profile fields."
	if not _integer(value.version, VERSION, VERSION): return "Unsupported ambient profile version."
	if not _identifier(value.id): return "Profile ID needs 1–64 ASCII letters, digits, underscores or hyphens."
	if not _text(value.name, 80, false): return "Profile name needs 1–80 printable characters."
	if not _text(value.description, 1024): return "Profile description is too long or contains control characters."
	if not _integer(value.seed, 0, MAX_SEED): return "Profile seed must be an integer from 0 to 2147483647."
	if not value.shared_seed is bool: return "Shared seed must be true or false."
	if not value.modules is Array or value.modules.size() > MAX_MODULES:
		return "A profile supports at most sixteen modules."
	var seen := {}
	var specs := Modules.module_specs()
	for module: Variant in value.modules:
		if not module is Dictionary or not _keys(module, MODULE_KEYS):
			return "Missing or unknown behaviour module fields."
		if not _identifier(module.id) or seen.has(module.id): return "Module IDs must be valid and unique within the profile."
		seen[module.id] = true
		if not module.type is String or not specs.has(module.type): return "Unknown behaviour module: " + str(module.type)
		if not module.enabled is bool: return "Module enabled must be true or false."
		if not _integer(module.priority, 0, 1000): return "Module priority must be an integer from 0 to 1000."
		if not _number(module.weight, 0.0, 10.0): return "Module weight must be finite and from 0 to 10."
		var parameters: Dictionary = specs[module.type].params
		if not module.params is Dictionary or not _keys(module.params, parameters.keys()):
			return "Missing or unknown parameters for " + str(module.type) + "."
		for key: String in parameters:
			var error := _parameter_error(key, module.params[key], parameters[key], admitted_material_ids)
			if not error.is_empty(): return str(module.id) + ": " + error
		var relation_error := _relations(module)
		if not relation_error.is_empty(): return str(module.id) + ": " + relation_error
	if material_ids(value).size() > MAX_MATERIALS: return "A profile can request at most eight distinct material IDs."
	if (capabilities is Dictionary or capabilities is Array) and not capabilities.is_empty():
		var diagnostics := capability_diagnostics(value, capabilities)
		if not diagnostics.is_empty(): return diagnostics[0]
	return ""


static func _has_capability(capabilities: Variant, name: String) -> bool:
	if capabilities is Dictionary: return bool(capabilities.get(name, false))
	return capabilities is Array and name in capabilities


static func capability_diagnostics(profile: Dictionary, capabilities: Variant) -> Array[String]:
	var diagnostics: Array[String] = []
	for module: Dictionary in profile.get("modules", []):
		if not bool(module.get("enabled", false)): continue
		var spec := module_spec(str(module.get("type", "")))
		for capability: String in spec.get("capabilities", []):
			if not _has_capability(capabilities, capability):
				diagnostics.append("%s requires %s locomotion; disable it or choose a compatible actor." % [module.id, capability])
		if str(module.get("type", "")) == "escape_obstruction" and bool(module.get("params", {}).get("jump", false)) \
			and not _has_capability(capabilities, "jump"):
			diagnostics.append("%s requests jump recovery but this actor has no compatible jump action." % module.id)
	return diagnostics


static func canonicalize(value: Dictionary) -> Dictionary:
	# Call only after validate(). JSON loads represent integers as floating point;
	# this returns a new authored value and never repairs an invalid profile.
	if not validate(value).is_empty(): return {}
	var result := value.duplicate(true)
	result.version = int(result.version)
	result.seed = int(result.seed)
	for module: Dictionary in result.modules:
		module.priority = int(module.priority)
		module.weight = float(module.weight)
		var spec := module_spec(str(module.type))
		for key: String in spec.params:
			match str(spec.params[key].get("type", "float")):
				"int", "integer", "material": module.params[key] = int(module.params[key])
				"float", "number": module.params[key] = float(module.params[key])
	return result


static func presets() -> Array:
	if not FileAccess.file_exists(PRESETS_PATH): return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESETS_PATH))
	if not data is Array: return []
	var result: Array = []
	var seen := {}
	for profile: Variant in data:
		if not validate(profile).is_empty() or seen.has(profile.id): return []
		seen[profile.id] = true
		result.append(canonicalize(profile))
	return result


static func preset(id: String) -> Dictionary:
	for profile: Dictionary in presets():
		if str(profile.id) == id: return profile.duplicate(true)
	return {}


static func blank(id: String = "custom") -> Dictionary:
	return {"version": VERSION, "id": id, "name": "Custom profile", "description": "",
		"seed": 1, "shared_seed": false, "modules": []}
