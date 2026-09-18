class_name CyberMicroScenarioCatalogue
extends RefCounted

const Contract = preload("res://scripts/micro_scenario_contract.gd")
const FIXTURE_PATH: String = "res://scenarios/communicating-reservoirs-v1.json"

static func ids() -> Array[String]:
	var out: Array[String] = ["experiment-tower", "communicating-reservoirs"]
	for id: String in CyberWaterFeelScenarios.ids(): out.append("water/" + id)
	return out

static func wrap_recipe(id: String, recipe: Dictionary, transport: Dictionary, water: Dictionary,
		family: String, legacy_hash: String) -> Dictionary:
	return {"schema_version": Contract.VERSION, "id": id,
		"recipe_version": int(recipe.version), "seed": int(recipe.seed),
		"maturity": "reference", "seed_scope": "recipe-identity",
		"rectangles": Array(recipe.rectangles),
		"partial_water_fills": Array(recipe.partial_water_fills),
		"events": recipe.actions.duplicate(true), "conditions": [],
		"transport": transport.duplicate(true), "water_policy": water.duplicate(true),
		"player_start": [int(recipe.player_start.x), int(recipe.player_start.y)],
		"camera_origin": [int(recipe.camera_origin.x), int(recipe.camera_origin.y)],
		"body_enabled": bool(recipe.body_enabled),
		"tools": ["jetpack"] if family == "water" else ["paint", "erase", "jetpack"],
		"legacy": {"family": family, "recipe_hash": legacy_hash}}

static func tower(profile: Dictionary = {}) -> Dictionary:
	var selected: Dictionary = CyberTransportProfiles.preset(0) if profile.is_empty() else profile
	var rectangles: PackedInt32Array = CyberExperimentTower.rectangles()
	return wrap_recipe("experiment-tower", {"version": CyberExperimentTower.VERSION, "seed": 0,
		"rectangles": rectangles, "partial_water_fills": PackedInt32Array(), "actions": [],
		"player_start": Vector2i(CyberExperimentTower.landing(0)), "camera_origin": Vector2i(0,8),
		"body_enabled": false}, selected, {}, "tower", JSON.stringify(Array(rectangles)).sha256_text())

static func water(policy: Dictionary) -> Dictionary:
	var checked: Dictionary = CyberWaterExperimentProfiles.resolve({}, {}, policy)
	if not checked.get("ok", false): return {}
	var recipe: Dictionary = CyberWaterFeelScenarios.recipe(str(checked.policy.scenario_id), int(checked.policy.seed))
	return wrap_recipe("water/" + str(checked.policy.scenario_id), recipe, CyberTransportProfiles.preset(0),
		checked.policy, "water", CyberWaterFeelScenarios.recipe_hash(recipe))

static func definition(id: String, seed: int = 0) -> Dictionary:
	if not Contract.integer(seed, 0, Contract.MAX_SEED): return {}
	if id == "experiment-tower": return tower() if seed == 0 else {}
	if id.begins_with("water/"):
		return water({"scenario_id": id.trim_prefix("water/"), "seed": seed})
	if id != "communicating-reservoirs": return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	if not parsed is Dictionary: return {}
	# The fixture seed is a recipe identity, as in the legacy Water apparatus.
	# It deliberately does not introduce or reseed a different physics RNG.
	parsed.seed = seed
	parsed.water_policy.seed = seed
	return parsed
