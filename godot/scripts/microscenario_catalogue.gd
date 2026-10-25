class_name CyberMicroScenarioCatalogue
extends RefCounted

const Contract = preload("res://scripts/microscenario_contract.gd")
const Water = preload("res://scripts/water_feel_scenarios.gd")
const Tower = preload("res://scripts/experiment_tower.gd")
const ReferencePack = preload("res://scripts/microscenario_reference_pack.gd")
const Showcase = preload("res://scripts/showcase_tiles.gd")
const BlacksiteNine = preload("res://scripts/blacksite_nine.gd")
const PhysicalTrial = preload("res://scripts/physical_actor_trial.gd")

static func ids() -> Array[String]:
	var result: Array[String] = ["experiment-tower"]
	for water_id: String in Water.ids(): result.append("water/" + water_id)
	result.append("fixtures/unequal-head")
	result.append("fixtures/sand-release")
	result.append_array(ReferencePack.ids())
	result.append_array(Showcase.scenario_ids())
	result.append(BlacksiteNine.SCENARIO_ID)
	for arm: String in PhysicalTrial.ARMS: result.append(PhysicalTrial.PREFIX + arm)
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

# A copied view for explicit policy preparation. Keep the original Tower/default
# route and its identity intact; selected floor is final construction input.
static func prepared_tower(profile: Dictionary, floor_index: int) -> Dictionary:
	var out: Dictionary = tower(profile)
	out.schema_version = 2
	var selected: int = clampi(floor_index,0,4)
	out.player_start = [20,int(Tower.landing(selected).y)]
	out.camera_origin = [0,int(Tower.floor_y(selected))]
	out["presentation"] = {"title":"Experiment Tower", "instructions":"Existing floor, release, schedule and manual tools remain exploratory.",
		"duration_ticks":Contract.MAX_TICK,"baseline":"Original Current Tower constructor",
		"profile":"Explicit solver policy with retained transport profile","regions":[]}
	return out

static func prepared_ordinary_demo(id: String) -> Dictionary:
	if id not in ["material_lab","waterworks","foundry","neon_works"]: return {}
	var out: Dictionary = Contract.base("ordinary-demo/"+id,1,0)
	out.schema_version = 2
	out.rectangles = Array(CyberDemoWorlds.rectangles(id))
	out.player_enabled = true;out.player_start = [24,222]
	out.tools = ["paint","erase","player"]
	out.source_recipe = "CyberDemoWorlds/"+id
	out.source_recipe_hash = JSON.stringify(out.rectangles).sha256_text()
	out["presentation"] = {"title":CyberDemoWorlds.title(id),
		"instructions":"Explicit Exploratory rebuild; ordinary demo controls remain active.",
		"duration_ticks":Contract.MAX_TICK,"baseline":"Original Current demo constructor",
		"profile":"Explicit solver policy with production Baseline and Current Water semantics","regions":[]}
	return out

static func prepared_physics_pit() -> Dictionary:
	var out: Dictionary = Contract.base("ordinary-demo/physics_pit",1,0)
	out.schema_version = 2;out.rectangles = Array(CyberDemoWorlds.rectangles("physics_pit"))
	out.player_enabled = true;out.body_enabled = true;out.player_start = [24,222]
	out.tools = ["paint","erase","player"];out.source_recipe = "CyberDemoWorlds/physics_pit"
	out.source_recipe_hash = JSON.stringify(out.rectangles).sha256_text()
	out["presentation"] = {"title":"Physics Pit","instructions":"Explicit Exploratory rebuild with the original three bodies.",
		"duration_ticks":Contract.MAX_TICK,"baseline":"Original Current Physics Pit constructor",
		"profile":"Explicit solver policy with staged original sampled and physical owners","regions":[]}
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

# Explicit family preparation retains Water Feel's sampled player, ordinary
# actions, semantic policy and recipe identity. The original schema1 is intact.
static func prepared_water(policy_result: Dictionary) -> Dictionary:
	var out: Dictionary = water(policy_result)
	if out.is_empty(): return {}
	out.schema_version = 2
	out["presentation"] = {"title":"Water Feel Lab","instructions":"Explicit Exploratory solver rebuild; ordinary Water Feel controls and scheduled actions remain active.",
		"duration_ticks":Contract.MAX_TICK,"baseline":"Original Current Water Feel constructor",
		"profile":"Explicit solver policy with retained Water semantic policy","regions":[]}
	return out

static func whole_cell_water_family(family: String) -> bool:
	return family == "cellular_yield_v1" or family == "inertial_cellular_v1"

static func prepared_water_source_refusal(policy_readback: Dictionary, recipe: Dictionary) -> String:
	var whole_cell_water: bool = false
	for assignment: Dictionary in policy_readback.get("assignments",[]):
		if int(assignment.material) == 3 and whole_cell_water_family(str(assignment.applied_family)): whole_cell_water = true
	if not whole_cell_water: return ""
	for action: Dictionary in recipe.actions:
		if action.kind == "fill" and int(action.normalized_mass) != 255:
			return "Prepared Water Feel refused: whole-cell Water fractional scheduled sources need separate qualification; initial normalization does not change actions"
	return ""

# Only authored exploratory play maps opt into actor replacement. Apparatus IDs
# and fixed execution never inherit this permission from maturity alone.
static func exploratory_actor_map(definition: Dictionary) -> bool:
	var id: String = str(definition.get("id", ""))
	return (definition.get("maturity", "") == "exploratory"
		and definition.get("execution", {}).get("policy", "") == "owner"
		and (id == BlacksiteNine.SCENARIO_ID or Showcase.contains(id) or PhysicalTrial.contains(id)))

static func player_configuration(scenario_id: String) -> Dictionary:
	if PhysicalTrial.contains(scenario_id): return PhysicalTrial.configuration(scenario_id)
	return ReferencePack.player_configuration(scenario_id)


static func definition(scenario_id: String, seed: int = 0) -> Dictionary:
	if PhysicalTrial.contains(scenario_id): return PhysicalTrial.definition(scenario_id, seed)
	if scenario_id == BlacksiteNine.SCENARIO_ID:
		return BlacksiteNine.definition(seed)
	if Showcase.contains(scenario_id):
		return Showcase.definition(scenario_id, seed)
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
