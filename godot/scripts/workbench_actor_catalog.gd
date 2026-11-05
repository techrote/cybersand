extends RefCounted

# Copied-value admission for the shared host; owns no scene, controller or World.
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const Physical = preload("res://scripts/physical_actor_catalog.gd")
const Player = preload("res://scripts/player_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Loadouts = preload("res://scripts/physical_usable_loadouts.gd")
const BARREL := "reference_barrel"
const MATERIAL_IDS: Array[String] = ["dryswarm","liquidswarm"]
const MATERIAL_NAMES := {"dryswarm":"Dust Devil · Sand cloud","liquidswarm":"Undertow · Water blob"}

static func ids() -> Array[String]:
	var result: Array[String] = []
	for i: int in Fleet.count(): result.append(Fleet.stable_id(i))
	result.append(BARREL)
	for id: StringName in Player.IDS: result.append(str(id))
	result.append_array(MATERIAL_IDS)
	return result

static func pilot_ids() -> Array[String]:
	var result := ids()
	result.erase(BARREL)
	return result

static func index_for_id(id: String) -> int: return ids().find(id)
static func has(id: String) -> bool: return kind(id) != ""

static func kind(id: String) -> String:
	if Fleet.index_for_id(id) >= 0: return "flyer"
	if id == BARREL: return "passive"
	if StringName(id) in Player.IDS: return "mechanical"
	if id in MATERIAL_IDS: return "material"
	return ""

static func name_for(id: String) -> String:
	var fleet := Fleet.index_for_id(id)
	if fleet >= 0: return Fleet.names()[fleet]
	if id == BARREL: return "Passive barrel"
	if StringName(id) in Player.IDS: return Player.name_for(StringName(id))
	return str(MATERIAL_NAMES.get(id,id))

static func names() -> Array[String]:
	var result: Array[String] = []
	for id: String in ids(): result.append(name_for(id))
	return result

static func definition(id: String) -> Dictionary:
	var fleet := Fleet.index_for_id(id)
	if fleet >= 0: return Equipment.definition(Fleet.definition(fleet))
	if kind(id) in ["mechanical","passive"]:
		return Equipment.definition(Physical.entry(StringName(id)),Loadouts.entry(StringName(id)))
	return {}

static func bounds(id: String) -> Rect2:
	var fleet := Fleet.index_for_id(id)
	if fleet >= 0: return Fleet.bounds(fleet)
	if kind(id) == "material": return Rect2(-8,-8,16,16)
	var data := definition(id)
	var result := Rect2()
	var first := true
	for part: Dictionary in data.get("parts",[]):
		var rect := Rect2(Vector2(part.offset)-Vector2(part.size)*0.5,part.size)
		result = rect if first else result.merge(rect)
		first = false
	return result

static func definition_hash(id: String) -> String:
	var fleet := Fleet.index_for_id(id)
	if fleet >= 0: return Fleet.definition_hash(fleet)
	if id == BARREL: return "reference-barrel-v1"
	if kind(id) == "material": return ("workbench-material-player-v1:"+id).sha256_text()
	if kind(id) != "mechanical": return ""
	var text := id
	for source: String in ["player_actor_catalog.gd","physical_actor_catalog.gd","physical_usable_loadouts.gd","physical_usable_equipment.gd"]:
		text += ":"+normalized_source_hash(FileAccess.get_file_as_string("res://scripts/"+source))
	return text.sha256_text()

static func normalized_source_hash(text: String) -> String:
	return text.replace("\r\n","\n").sha256_text()

static func proxy_count(id: String) -> int:
	if kind(id) == "material": return 0
	var fleet := Fleet.index_for_id(id)
	return Fleet.collision_rects(fleet).size() if fleet >= 0 else definition(id).get("parts",[]).size()

static func capabilities(id: String) -> Dictionary:
	var fleet := Fleet.index_for_id(id)
	var result: Dictionary = Fleet.authoring_record(fleet).capabilities if fleet >= 0 else {
		"side_thrusters":false,"reverse_thrust":true,"dispenser_q":0,"dispenser_e":0,"dispenser_s":0}
	result["kind"] = kind(id)
	result["model"] = id
	result["legacy_secondary"] = kind(id) in ["mechanical","material"]
	result["usables"] = kind(id) == "mechanical"
	return result

static func controls(id: String) -> String:
	if kind(id) == "mechanical": return Player.controls(StringName(id))
	if kind(id) == "material":
		return "WASD guides native cells · Space surges · Shift spreads/squeezes · C gathers\nFields act in Play. Paused Step advances cells without field input. Reset does not create another cloud."
	return ""
