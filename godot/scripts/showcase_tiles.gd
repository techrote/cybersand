class_name CyberShowcaseTiles
extends RefCounted

# Top-to-bottom district order. Each recipe installs one bounded native world;
# this catalogue does not stream or retain hidden worlds between selections.
const Neon = preload("res://scripts/neon_reliquary.gd")
const Middle = preload("res://scripts/middle_cyberberbia.gd")
const Sewer = preload("res://scripts/sewertech_alley.gd")
const Swamp = preload("res://scripts/industrial_underswamp.gd")
const RECIPES: Array = [Neon, Middle, Sewer, Swamp]

static func index_of(id: String) -> int:
	for index: int in range(RECIPES.size()):
		if id == RECIPES[index].ID or id == RECIPES[index].SCENARIO_ID:
			return index
	return -1

static func contains(id: String) -> bool:
	return index_of(id) >= 0

static func recipe(id: String) -> GDScript:
	var index: int = index_of(id)
	return RECIPES[index] if index >= 0 else null

static func scenario_ids() -> Array[String]:
	var result: Array[String] = []
	for source: GDScript in RECIPES:
		result.append(source.SCENARIO_ID)
	return result

static func title(id: String) -> String:
	var source: GDScript = recipe(id)
	return source.TITLE if source != null else ""

static func demo_id(id: String) -> String:
	var source: GDScript = recipe(id)
	return source.ID if source != null else ""

static func stack_position(id: String) -> Vector2i:
	var index: int = index_of(id)
	return Vector2i(0, index) if index >= 0 else Vector2i(-1, -1)

static func definition(id: String, seed: int = 0) -> Dictionary:
	var source: GDScript = recipe(id)
	return source.definition(seed) if source != null else {}

static func viewpoints(id: String) -> Array[Dictionary]:
	var source: GDScript = recipe(id)
	if source != null:
		return source.viewpoints()
	var empty: Array[Dictionary] = []
	return empty
