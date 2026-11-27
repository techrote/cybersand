extends RefCounted

# Authored values only. Runtime module memory, RNG state, leases and physical
# state never enter a profile or an ordinary Workbench save.
const Modules = preload("res://scripts/ambient/ambient_modules.gd")
const VERSION := 2
const LEGACY_VERSION := 1
const MAX_MODULES := 16
const MAX_MATERIALS := 8
const MAX_SEED := 2147483647
const PROFILE_KEYS := ["version", "id", "name", "description", "seed", "shared_seed", "modules"]
const V2_KEYS := PROFILE_KEYS + ["personality", "drives_enabled", "memory", "perception", "relations", "regions"]
const MAX_REGIONS := 12
const MAX_TAGS := 8
const MAX_ROUTE_POINTS := 16
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
		var value: Variant = spec.params[key].default
		parameters[key] = value.duplicate(true) if value is Array or value is Dictionary else value
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
	if type == "region":
		return "" if value is String and (value.is_empty() or _identifier(value)) else key + " must name an authored region or be empty."
	if type == "points":
		if not value is Array or value.size() < 2 or value.size() > MAX_ROUTE_POINTS:
			return key + " needs 2–16 home-relative waypoints."
		for point: Variant in value:
			if not point is Array or point.size() != 2 or not _number(point[0], -2048.0, 2048.0) or not _number(point[1], -2048.0, 2048.0):
				return key + " waypoints must be finite [x, y] offsets within ±2048 cells."
		return ""
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
		"seek_material", "investigate_material", "follow_material_boundary":
			if float(p.standoff) + float(p.get("hysteresis", 0.0)) > float(p.radius):
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
		"observe_actor", "regroup":
			if float(p.tolerance) >= float(p.radius):
				return "The peer tolerance must fit inside its observation radius."
		"rest_resource":
			if float(p.low_fraction) >= float(p.resume_fraction):
				return "Resource rest requires low fraction below resume fraction."
		"avoid_peer":
			if float(p.release_distance) < float(p.radius):
				return "Peer avoidance release distance must be at least its entry radius."
	return ""


static func validate(value: Variant, admitted_material_ids: Array = [], capabilities: Variant = []) -> String:
	if not value is Dictionary or not _integer(value.get("version"), LEGACY_VERSION, VERSION):
		return "Unsupported ambient profile version."
	var expected: Array = PROFILE_KEYS if int(value.version) == LEGACY_VERSION else V2_KEYS
	if not _keys(value, expected): return "Missing or unknown ambient profile fields."
	if int(value.version) == VERSION:
		var settings_error: String = _settings_error(value)
		if not settings_error.is_empty(): return settings_error
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
		if int(value.version) < int(specs[module.type].get("minimum_profile_version", LEGACY_VERSION)):
			return str(module.type) + " requires an explicit version-2 profile upgrade."
		if not module.enabled is bool: return "Module enabled must be true or false."
		if not _integer(module.priority, 0, 1000): return "Module priority must be an integer from 0 to 1000."
		if not _number(module.weight, 0.0, 10.0): return "Module weight must be finite and from 0 to 10."
		var parameters: Dictionary = specs[module.type].params
		if not module.params is Dictionary or not _keys(module.params, parameters.keys()):
			return "Missing or unknown parameters for " + str(module.type) + "."
		for key: String in parameters:
			var error := _parameter_error(key, module.params[key], parameters[key], admitted_material_ids)
			if not error.is_empty(): return str(module.id) + ": " + error
			if str(parameters[key].get("type", "")) == "region" and not str(module.params[key]).is_empty():
				var region_found: bool = false
				for region: Dictionary in value.get("regions", []):
					if str(region.id) == str(module.params[key]): region_found = true
				if not region_found: return str(module.id) + ": the selected authored region does not exist."
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
	if int(result.version) == VERSION:
		for key: String in personality_specs():
			if key != "enabled": result.personality[key] = int(result.personality[key]) if key == "failure_tolerance" else float(result.personality[key])
		for key: String in ["capacity", "interest_capacity", "obstruction_capacity"]: result.memory[key] = int(result.memory[key])
		for key: String in ["cell_size", "lifetime_seconds"]: result.memory[key] = float(result.memory[key])
		result.perception.spacing_cells = int(result.perception.spacing_cells)
		result.perception.near_radius_cells = int(result.perception.near_radius_cells)
		result.relations.peer_id = int(result.relations.peer_id)
		for region: Dictionary in result.regions:
			for key: String in ["x", "y", "width", "height"]: region[key] = float(region[key])
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


static func _setting(value: float, minimum: float, maximum: float, unit: String, description: String, integer: bool = false) -> Dictionary:
	return {"type":"integer" if integer else "number", "default":int(value) if integer else value,
		"min":minimum, "max":maximum, "unit":unit, "description":description}


static func personality_specs() -> Dictionary:
	return {
		"enabled":{"type":"boolean", "default":true, "description":"Apply the trait mechanisms below. Off uses neutral traits, permitting a matched personality ablation."},
		"curiosity":_setting(0.5,0.0,1.0,"fraction","Raises utility for novel material and unfamiliar space; habituated discoveries lose their appeal."),
		"persistence":_setting(0.5,0.0,1.0,"fraction","Extends finite goal commitments and approach deadlines, without renewing them every decision."),
		"caution":_setting(0.5,0.0,1.0,"fraction","Increases material avoidance entry distance and obstacle clearance; never grants immunity or knowledge."),
		"sociability":_setting(0.5,0.0,1.0,"fraction","Raises copied-peer observation, regrouping and alignment utility and the rate of accumulating social drive."),
		"activity":_setting(0.5,0.0,1.0,"fraction","Scales ordinary/goal pace from 0.6 to 1.4 of module pace; urgent reflex pace stays authored. Also changes drive depletion and wander idle probability."),
		"territoriality":_setting(0.5,0.0,1.0,"fraction","Raises preference for authored regions and starts drive-based homeward journeys sooner."),
		"preferred_distance":_setting(24.0,4.0,64.0,"cells","Comfort distance used by peer observation and regrouping; ordinary following/crowding retain their module-specific distances."),
		"failure_tolerance":_setting(3,1,10,"attempts","Remembered failed approaches required before the repeated-obstruction withdrawal module commits to retreat.",true),
	}


static func memory_specs() -> Dictionary:
	return {
		"enabled":{"type":"boolean","default":true,"description":"Retain bounded visits, material interests and obstruction outcomes. Off disables memory-dependent goals."},
		"capacity":_setting(64,8,128,"cells","Maximum retained visited grid cells; least recently seen entries are evicted.",true),
		"interest_capacity":_setting(16,1,32,"patches","Maximum remembered material patch observations.",true),
		"obstruction_capacity":_setting(16,1,32,"approaches","Maximum recent failed position-and-direction approaches.",true),
		"cell_size":_setting(24.0,8.0,96.0,"cells","Sparse memory grid width; does not alter physics or material sampling."),
		"lifetime_seconds":_setting(90.0,5.0,600.0,"s","Maximum simulation-time age before a retained observation is forgotten."),
	}


static func perception_specs() -> Dictionary:
	return {
		"spacing_cells":_setting(4,1,4,"cells","Requested material resolution; sampling may coarsen to respect the published per-decision budget.",true),
		"near_radius_cells":_setting(8,0,16,"cells","Dense bounded near-field radius; zero disables near-field refinement.",true),
		"refine_boundaries":{"type":"boolean","default":true,"description":"Request bounded local material-boundary refinement; absent coverage remains unknown."},
	}


static func _defaults(specs: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in specs: result[key] = specs[key].default
	return result


static func personality_defaults() -> Dictionary:
	return _defaults(personality_specs())


static func memory_defaults() -> Dictionary:
	return _defaults(memory_specs())


static func perception_defaults() -> Dictionary:
	return _defaults(perception_specs())


static func _settings_error(value: Dictionary) -> String:
	for group: String in ["personality", "memory", "perception"]:
		var specs: Dictionary = personality_specs() if group == "personality" else (memory_specs() if group == "memory" else perception_specs())
		if not value[group] is Dictionary or not _keys(value[group],specs.keys()):
			return "Missing or unknown " + group + " settings."
		for key: String in specs:
			var error: String = _parameter_error(key,value[group][key],specs[key],[])
			if not error.is_empty(): return group + ": " + error
	if not value.drives_enabled is bool: return "Drives enabled must be true or false."
	if not value.relations is Dictionary or not _keys(value.relations,["tags","prefer_tags","avoid_tags","peer_id"]):
		return "Missing or unknown relationship settings."
	for key: String in ["tags","prefer_tags","avoid_tags"]:
		var tags: Variant = value.relations[key]
		if not tags is Array or tags.size() > MAX_TAGS: return key + " supports at most eight tags."
		var seen_tags: Dictionary = {}
		for tag: Variant in tags:
			if not _identifier(tag) or seen_tags.has(tag): return key + " requires distinct identifier tags."
			seen_tags[tag] = true
	if not _integer(value.relations.peer_id,-1,2147483647): return "Preferred peer must be -1 (any) or a nonnegative authored actor ID."
	if not value.regions is Array or value.regions.size() > MAX_REGIONS: return "A profile supports at most twelve authored regions."
	var seen: Dictionary = {}
	var home_count: int = 0
	for region: Variant in value.regions:
		if not region is Dictionary or not _keys(region,["id","name","kind","x","y","width","height"]):
			return "Each region needs exactly id, name, kind, x, y, width and height."
		if not _identifier(region.id) or seen.has(region.id): return "Region IDs must be valid and unique."
		seen[region.id] = true
		if not _text(region.name,80,false): return "Region names need 1–80 printable characters."
		if not region.kind is String or region.kind not in ["home","interest","avoid"]: return "Region kind must be home, interest or avoid."
		if region.kind == "home": home_count += 1
		for key: String in ["x","y","width","height"]:
			if not _number(region[key],1.0 if key in ["width","height"] else 0.0,2048.0):
				return "Region coordinates and size must be finite and within the supported 2048-cell extent."
		if float(region.x) + float(region.width) > 2048.0 or float(region.y) + float(region.height) > 2048.0:
			return "Region rectangle exceeds the supported 2048-cell extent."
	if home_count > 1: return "A profile may have only one authored home region."
	return ""


static func upgrade(value: Dictionary) -> Dictionary:
	# Explicit authored migration; old saves and six predecessor presets remain v1.
	if not validate(value).is_empty(): return {}
	if int(value.version) == VERSION: return canonicalize(value)
	var result: Dictionary = value.duplicate(true)
	result.version = VERSION
	# New authored keys must be String. Godot's dot assignment creates StringName
	# keys for absent entries, which the strict portable JSON schema rejects.
	result["personality"] = personality_defaults()
	result["drives_enabled"] = true
	result["memory"] = memory_defaults()
	result["perception"] = perception_defaults()
	result["relations"] = {"tags":[],"prefer_tags":[],"avoid_tags":[],"peer_id":-1}
	result["regions"] = []
	return canonicalize(result)


static func blank(id: String = "custom") -> Dictionary:
	return {"version": VERSION, "id": id, "name": "Custom profile", "description": "",
		"seed": 1, "shared_seed": false, "modules": [], "personality":personality_defaults(),
		"drives_enabled":true,"memory":memory_defaults(),"perception":perception_defaults(),
		"relations":{"tags":[],"prefer_tags":[],"avoid_tags":[],"peer_id":-1},"regions":[]}
