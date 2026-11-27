extends RefCounted

# Workbench admission over the existing physical catalogues. This registry owns
# copied authoring values only: no World, physics space, controller or live state.
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const Physical = preload("res://scripts/physical_actor_catalog.gd")
const Player = preload("res://scripts/player_actor_catalog.gd")
const Flight = preload("res://scripts/physical_flight_profile.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Loadouts = preload("res://scripts/physical_usable_loadouts.gd")
const Usables = preload("res://scripts/usable_catalog.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const AmbientProfile = preload("res://scripts/ambient/ambient_profile.gd")
const AmbientActuator = preload("res://scripts/ambient/ambient_actuator.gd")
const BARREL := "reference_barrel"
const VERSION := 1
const Capacity = preload("res://scripts/workbench_sandbox_capacity.gd")
const MAX_ACTORS := Capacity.MAX_ACTORS
# A temporarily piloted or paused AMBIENT actor keeps its policy slot for handback.
const MAX_AMBIENT_CONTROLLERS := 8
const AMBIENT_CAPACITY_ERROR := "A scene supports up to eight assigned AMBIENT controllers, including paused and piloted inhabitants."
const MAX_PARTS := Capacity.MAX_PARTS
const CONTROL_KEYS := ["version", "source", "enabled", "decision_ticks", "policy", "usable_index"]
const SOURCES := ["human", "scripted", "policy", "passive"]
const FAMILY_NAMES := {"setA":"Ground and hover", "setB":"Survey and excavation",
	"setF":"Flight and leaps", "setY":"Climbing and ropes", "setU":"Mechanical utilities",
	"setV":"Hybrid mechanisms", "setX":"Articulated machines", "setP":"Player movement",
	"set4LY":"4LY assisted flight"}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for index: int in Fleet.count(): result.append(Fleet.stable_id(index))
	result.append(BARREL)
	for model: StringName in Physical.RIG_IDS: result.append(str(model))
	for model: StringName in Flight.IDS: result.append(str(model))
	return result


static func has_model(model: String) -> bool:
	return Fleet.index_for_id(model) >= 0 or Physical.has_rig(StringName(model))


# Prepared topology includes the permanent equipment chassis. Released equipment
# keeps this same part and mask slot; admission never assumes dropping it frees a
# slot. The fleet's rectangle-union proxies are counted separately below.
static func definition(model: String) -> Dictionary:
	var index := Fleet.index_for_id(model)
	if index >= 0: return Equipment.definition(Fleet.definition(index))
	if not Physical.has_rig(StringName(model)): return {}
	return Equipment.definition(Physical.entry(StringName(model)), Loadouts.entry(StringName(model)))


static func _json_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[str(key)] = _json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_json_value(item))
		return result
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is Rect2 or value is Rect2i: return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Color: return [value.r, value.g, value.b, value.a]
	if value is StringName: return str(value)
	return value


static func definition_hash(model: String) -> String:
	var index := Fleet.index_for_id(model)
	if index >= 0: return Fleet.definition_hash(index)
	# Preserve exact old Setup-v2 definition identities.
	if model == BARREL: return "reference-barrel-v1"
	var data := definition(model)
	return "" if data.is_empty() else "wb-physical-v1:" + JSON.stringify(_json_value(data), "", true, true).sha256_text()


static func bounds(model: String) -> Rect2:
	return definition(model).get("bounds", Rect2())


static func part_count(model: String) -> int:
	return definition(model).get("parts", []).size()


static func proxy_count(model: String) -> int:
	var index := Fleet.index_for_id(model)
	return Fleet.collision_rects(index).size() if index >= 0 else part_count(model)


static func supports(model: String, source: String) -> bool:
	if not has_model(model) or source not in SOURCES: return false
	if model == BARREL: return source == "passive"
	return not definition(model).is_empty()


static func producer_for(source: String) -> String:
	return "demo" if source == "scripted" else source


static func supports_producer(model: String, producer: String) -> bool:
	return supports(model, "scripted" if producer == "demo" else producer)


static func default_control(model: String) -> Dictionary:
	var source := "scripted"
	if model == BARREL: source = "passive"
	elif Fleet.index_for_id(model) >= 0 or Player.has_rig(StringName(model)): source = "human"
	return {"version":VERSION, "source":source, "enabled":true, "decision_ticks":6,
		"policy":"fixture", "usable_index":int(Loadouts.entry(StringName(model)).get("usable_index", -1))}


static func control_for(actor: Dictionary) -> Dictionary:
	if actor.has("control"): return actor.control.duplicate(true)
	return default_control(str(actor.get("model", "")))


static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high


static func equipment_error(model: String, usable_index: Variant) -> String:
	if not _integer(usable_index, -1, Usables.count() - 1): return "Unknown equipment selection."
	var data := definition(model)
	if data.is_empty(): return "Unavailable physical actor: " + model
	if str(data.get("equipment_preparation", "mounted")) == "none" and int(usable_index) != -1:
		return "This actor has no physical equipment mount: " + model
	return ""


static func control_error(model: String, value: Variant) -> String:
	if not value is Dictionary or value.size() != CONTROL_KEYS.size() + (1 if value.has("ambient") else 0) or not value.has_all(CONTROL_KEYS):
		return "Missing or unknown actor control fields."
	if not _integer(value.version, VERSION, VERSION): return "Unsupported actor control version."
	if not value.source is String or not supports(model, value.source):
		return "Controller source is unsupported for " + model + "."
	if not value.enabled is bool: return "Controller enabled must be true or false."
	if not _integer(value.decision_ticks, 1, 12): return "Controller decisions must be spaced 1–12 physical ticks."
	if not value.policy is String or value.policy not in ["fixture", "external", "ambient"]:
		return "Unknown external-policy adapter."
	if value.policy == "ambient" and not value.has("ambient"):
		return "Procedural NPC control requires an authored behaviour profile."
	if value.has("ambient"):
		var caps := AmbientActuator.capabilities(model)
		if not bool(caps.supported): return "No supported procedural locomotion adapter for " + model + "."
		var profile_error := AmbientProfile.validate(value.ambient, [], caps)
		if not profile_error.is_empty(): return profile_error
	return equipment_error(model, value.usable_index)


# Count actual prepared topology, including permanent equipment. A one-body
# barrel consumes one body and one proxy; a compound flyer may consume more
# proxies than bodies. Repeated models share only copied count calculations.
static func resource_usage(actors: Array) -> Dictionary:
	var result := {"actors":actors.size(), "ambient_controllers":0, "bodies":0, "proxies":0, "joints":0, "authored_links":0, "error":""}
	var counts := {}
	for actor: Variant in actors:
		if not actor is Dictionary or not actor.get("model") is String:
			result.error = "Invalid actor definition."
			return result
		var control: Variant = actor.get("control", {})
		if control is Dictionary and control.get("policy") == "ambient": result.ambient_controllers += 1
		var model := str(actor.model)
		if not counts.has(model):
			var data := definition(model)
			if data.is_empty():
				result.error = "Unavailable physical actor definition: " + model
				return result
			var count: int = data.get("parts", []).size()
			if count < 1 or count > MAX_PARTS:
				result.error = "%s needs %d physical parts including equipment; each actor allows 1–%d." % [model, count, MAX_PARTS]
				return result
			var joints := 0
			for joint: Dictionary in data.get("joints", []):
				joints += 3 if joint.type == "spring" else (2 if joint.type == "slide" else 1)
			counts[model] = {"bodies":count, "proxies":proxy_count(model), "joints":joints,
				"authored_links":data.get("joints", []).size()}
		for key: String in ["bodies", "proxies", "joints", "authored_links"]:
			result[key] += int(counts[model][key])
	return result


static func capacity_error(actors: Array, capacity: Dictionary = {}) -> String:
	var limits := Capacity.defaults() if capacity.is_empty() else capacity
	var invalid := Capacity.error(limits)
	if not invalid.is_empty(): return invalid
	if actors.size() > int(limits.logical_limit):
		return "Composition needs %d actors; configured logical capacity is %d. Increase it in Sandbox Capacity." % [actors.size(), limits.logical_limit]
	var used := resource_usage(actors)
	if not str(used.error).is_empty(): return str(used.error)
	if used.ambient_controllers > MAX_AMBIENT_CONTROLLERS: return AMBIENT_CAPACITY_ERROR
	if int(used.bodies) > int(limits.body_limit) or int(used.proxies) > int(limits.proxy_limit):
		return "Composition needs %d physical bodies and %d native masks; configured budgets are %d and %d. Equipment retains its slot when released." % [used.bodies, used.proxies, limits.body_limit, limits.proxy_limit]
	return ""


static func entry(model: String) -> Dictionary:
	var data := definition(model)
	if data.is_empty(): return {}
	var index := Fleet.index_for_id(model)
	var family := "Workbench flyers" if index >= 0 else str(FAMILY_NAMES.get(str(Physical.set_for(StringName(model))), "Passive bodies"))
	if model == BARREL: family = "Passive bodies"
	var controllers: Array[String] = []
	for source: String in SOURCES:
		if supports(model, source): controllers.append(source)
	var capabilities: Array[String] = [str(data.get("profile", {}).get("movement", "passive"))]
	if not data.get("joints", []).is_empty(): capabilities.append("articulated")
	if bool(data.get("profile", {}).get("grip", false)): capabilities.append("contact grip")
	if bool(data.get("profile", {}).get("rope", false)): capabilities.append("rope")
	var equipped := str(data.get("equipment_preparation", "mounted")) != "none"
	if equipped: capabilities.append("physical equipment")
	return {"id":model, "name":str(data.get("name", model)), "family":family,
		"description":str(data.get("description", "Passive body; no drive or equipment.")),
		"representation":"physical", "controllers":controllers, "capabilities":capabilities,
		"parts":data.parts.size(), "proxy_count":proxy_count(model), "equipment":equipped,
		"default_controller":str(default_control(model).source),
		"default_usable":int(default_control(model).usable_index),
		"controls":Fleet.controls(index) if index >= 0 else str(data.get("controls", "Passive physical body.")),
		"limitations":data.get("limitations", []).duplicate(true)}
