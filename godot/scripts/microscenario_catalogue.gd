class_name CyberMicroScenarioCatalogue
extends RefCounted

const Contract = preload("res://scripts/microscenario_contract.gd")
const Water = preload("res://scripts/water_feel_scenarios.gd")
const Tower = preload("res://scripts/experiment_tower.gd")
const ReferencePack = preload("res://scripts/microscenario_reference_pack.gd")

static func ids() -> Array[String]:
	var result: Array[String] = ["experiment-tower"]
	for water_id: String in Water.ids(): result.append("water/" + water_id)
	result.append("fixtures/unequal-head")
	result.append("fixtures/sand-release")
	result.append_array(ReferencePack.ids())
	return result

static func tower(profile: Dictionary = {}) -> Dictionary:
	var out: Dictionary = Contract.base("experiment-tower", Tower.VERSION, 0)
	out.maturity = "reference"
	out.rectangles = Array(Tower.rectangles())
	out.transport_profile = profile.duplicate(true) if not profile.is_empty() else CyberTransportProfiles.preset(0)
	out.player_start = [20, int(Tower.landing(0).y)]
	out.player_enabled = true
	out.tools = ["paint", "erase", "player"]
	out.source_recipe = "CyberExperimentTower/v4"
	out.source_recipe_hash = JSON.stringify(out.rectangles).sha256_text()
	return out

static func water(policy_result: Dictionary) -> Dictionary:
	if not policy_result.get("ok", false): return {}
	var policy: Dictionary = policy_result.policy
	var recipe: Dictionary = Water.recipe(str(policy.scenario_id), int(policy.seed))
	if recipe.is_empty(): return {}
	var out: Dictionary = Contract.base("water/" + str(policy.scenario_id), Water.VERSION, int(policy.seed))
	out.maturity = "reference"
	out.rectangles = Array(recipe.rectangles)
	out.partial_water_fills = Array(recipe.partial_water_fills)
	out.water_semantics = Array(policy_result.semantic)
	out.player_start = [recipe.player_start.x, recipe.player_start.y]
	out.camera_origin = [recipe.camera_origin.x, recipe.camera_origin.y]
	out.player_enabled = true
	out.body_enabled = bool(recipe.body_enabled)
	out.tools = ["player"]
	out.events = recipe.actions.duplicate(true)
	out.source_recipe = "CyberWaterFeelScenarios/v1/" + str(policy.scenario_id)
	out.source_recipe_hash = Water.recipe_hash(recipe)
	return out

static func definition(scenario_id: String, seed: int = 0) -> Dictionary:
	if scenario_id == "experiment-tower":
		return tower() if seed == 0 else {} # Legacy Tower never had a seed control.
	if scenario_id.begins_with("water/"):
		return water(CyberWaterExperimentProfiles.resolve({}, {}, {
			"scenario_id":scenario_id.trim_prefix("water/"), "seed":seed}))
	if scenario_id == "fixtures/unequal-head": return unequal_head(seed)
	if scenario_id == "fixtures/sand-release": return sand_release(seed)
	return ReferencePack.definition(scenario_id, seed)

static func unequal_head(seed: int = 0) -> Dictionary:
	# New reduced #26-style apparatus, NOT a registered #26 candidate or result.
	# Two unequal-height reservoirs connect through the bottom of an inert divider.
	var out: Dictionary = Contract.base("fixtures/unequal-head", 1, seed)
	var shift: int = seed % 5
	out.rectangles = [48+shift,80,4,180,1, 304+shift,80,4,180,1,
		48+shift,256,260,4,1, 176+shift,80,4,176,1]
	out.partial_water_fills = [52+shift,148,124,108,255,0, 180+shift,220,124,36,255,0]
	out.events = [{"tick":30, "kind":"erase", "x":176+shift, "y":244,
		"width":4, "height":12, "material":0, "normalized_mass":0, "coherence":0}]
	out.execution = {"policy":"fixed", "cadence_lod_enabled":false, "liquid_surface_adhesion_enabled":true}
	out.interest = {"policy":"fixed", "region":[32,64,320,224]}
	out.observations = [
		{"id":"initial-water", "tick":0, "metric":"water_integer", "region":[48+shift,80,260,180], "material":3},
		{"id":"final-water", "tick":120, "metric":"water_integer", "region":[48+shift,80,260,180], "material":3}]
	out.conditions = [{"observation":"final-water", "comparison":"eq",
		"value":124*144*255, "outcome":"complete"}]
	out.source_recipe = "MS-000 reduced unequal-head apparatus v1; no physics acceptance"
	return out

static func sand_release(seed: int = 0) -> Dictionary:
	var out: Dictionary = Contract.base("fixtures/sand-release", 1, seed)
	var shift: int = seed % 5
	out.rectangles = [48+shift,96,4,164,1, 176+shift,96,4,164,1,
		48+shift,256,132,4,1, 72+shift,120,64,24,2, 60+shift,160,96,4,1]
	out.events = [{"tick":10, "kind":"erase", "x":60+shift, "y":160,
		"width":96, "height":4, "material":0, "normalized_mass":0, "coherence":0}]
	out.execution = {"policy":"fixed", "cadence_lod_enabled":false, "liquid_surface_adhesion_enabled":true}
	out.interest = {"policy":"fixed", "region":[32,80,176,192]}
	out.observations = [{"id":"sand-retained", "tick":120, "metric":"material_cells",
		"region":[48+shift,96,132,164], "material":2}]
	out.conditions = [{"observation":"sand-retained", "comparison":"eq", "value":1536, "outcome":"complete"}]
	out.source_recipe = "MS-000 non-Water generic proving fixture v1"
	return out
