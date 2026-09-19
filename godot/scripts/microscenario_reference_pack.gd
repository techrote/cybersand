class_name CyberMicroScenarioReferencePack
extends RefCounted

# Content only: ordinary setup rectangles, finite existing operations, declared
# read-only observations. No scenario-specific tick callback or material kernel.
const Contract = preload("res://scripts/microscenario_contract.gd")
const VERSION: int = 1
const BASELINE: String = "de332eaf8f4e70b25b097bed0c2e2a7b2aac0173 / Baseline transport / Water8-coherence12 / exploratory"

static func ids() -> Array[String]:
	return ["materials/contact-lab", "materials/salt-water", "materials/salt-water-dose-small", "materials/lava-water"]

static func definition(id: String, seed: int = 0) -> Dictionary:
	match id:
		"materials/contact-lab": return laboratory(seed)
		"materials/salt-water": return interaction_fixture("salt-water", seed, 32)
		"materials/salt-water-dose-small": return interaction_fixture("salt-water", seed, 16)
		"materials/lava-water": return interaction_fixture("lava-water", seed, 32)
	return {}

static func base(id: String, seed: int, title: String, profile: String, duration: int, instructions: String) -> Dictionary:
	var out: Dictionary = Contract.base(id, VERSION, seed)
	out.schema_version = 2
	out.execution = {"policy":"fixed", "cadence_lod_enabled":false, "liquid_surface_adhesion_enabled":true}
	out.interest = {"policy":"fixed", "region":[0,0,512,320]}
	out["presentation"] = {"title":title, "instructions":instructions, "duration_ticks":duration,
		"baseline":BASELINE, "profile":profile, "regions":[]}
	out.source_recipe = "MS-001 reference-pack/v1/" + id
	return out

static func region(id: String, label: String, rect: Array) -> Dictionary:
	return {"id":id, "label":label, "region":rect.duplicate()}

static func observe(id: String, tick: int, metric: String, rect: Array, material: int = 0) -> Dictionary:
	return {"id":id, "tick":tick, "metric":metric, "region":rect.duplicate(), "material":material}

static func erase(tick: int, x: int, y: int, width: int, height: int) -> Dictionary:
	return {"tick":tick, "kind":"erase", "x":x, "y":y, "width":width, "height":height,
		"material":0, "normalized_mass":0, "coherence":0}

static func fill(tick: int, x: int, y: int, width: int, height: int) -> Dictionary:
	return {"tick":tick, "kind":"fill", "x":x, "y":y, "width":width, "height":height,
		"material":3, "normalized_mass":255, "coherence":0}

static func finish(out: Dictionary) -> Dictionary:
	# Ancestral geometry/action identity, distinct from the complete definition's
	# canonical hash and the actually executing native/script fingerprints.
	out.source_recipe_hash = JSON.stringify({"rectangles":out.rectangles,
		"partial_water_fills":out.partial_water_fills, "events":out.events}, "", true).sha256_text()
	return out

static func _bay(out: Dictionary, x: int, material: int, dose: int, seed: int) -> void:
	var shift: int = seed % 5
	out.rectangles.append_array([x,64,4,184,1, x+128,64,4,184,1, x,244,132,4,1,
		x,64,132,4,1, x+38,140,56,3,1, x+48+shift,128,dose,12,material])
	out.partial_water_fills.append_array([x+4,192,124,52,255,0])
	out.events.append(erase(12,x+38,140,56,3))

static func laboratory(seed: int = 0) -> Dictionary:
	var out: Dictionary = base("materials/contact-lab", seed, "Materials Laboratory", "three-bay/contact-v1", 240,
		"Three sealed bays share the same Water reservoir recipe. At tick 12 the ordinary shelves are erased: Salt dissolves, Lava quenches, Sand supplies a non-reacting transport control. Pause, inspect the declared probes, reset with R, and compare complete definitions using A/B. Paint/erase is available for exploration; organic brush input is not replayed or included in reaction ledgers. F8 hides labels and HUD.")
	out.tools = ["paint", "erase"]
	_bay(out,24,23,32,seed)
	_bay(out,176,8,32,seed)
	_bay(out,328,2,32,seed)
	out.presentation.regions = [region("dissolution","SALT + WATER / BRINE",[24,64,132,184]),
		region("quench","LAVA + WATER / STONE + STEAM",[176,64,132,184]),
		region("control","SAND + WATER / TRANSPORT CONTROL",[328,64,132,184])]
	out.observations = [observe("salt-initial",0,"material_cells",[28,68,124,176],23),
		observe("water-initial",0,"water_integer",[24,64,436,184],3),
		observe("dose-state",0,"cell_state",[72+seed%5,134,1,1],23),
		observe("brine-120",120,"material_cells",[28,68,124,176],24),
		observe("stone-120",120,"material_cells",[180,68,124,176],13),
		observe("steam-120",120,"material_cells",[180,68,124,176],22),
		observe("salt-final",240,"material_cells",[28,68,124,176],23),
		observe("brine-final",240,"material_cells",[28,68,124,176],24),
		observe("sand-retained",240,"material_cells",[332,68,124,176],2),
		observe("water-final",240,"water_integer",[24,64,436,184],3),
		observe("reservoir-state",240,"cell_state",[30,238,1,1],24),
		observe("end",240,"tick",[0,0,1,1])]
	out.conditions = [{"observation":"end","comparison":"eq","value":240,"outcome":"complete"}]
	return finish(out)

static func interaction_fixture(pair: String = "salt-water", seed: int = 0, dose: int = 32) -> Dictionary:
	# Deliberately generated complete data, not an INT-000 implementation. This
	# function returns independent values; GUI paste and CLI --definition use them unchanged.
	if not pair in ["salt-water", "lava-water"] or not dose in [16,32]: return {}
	var material: int = 23 if pair == "salt-water" else 8
	var product: int = 24 if pair == "salt-water" else 13
	var id: String = "materials/" + pair
	if dose == 16: id += "-dose-small"
	var out: Dictionary = base(id, seed, "Materials Laboratory / " + pair, "%s/dose-%d/v1" % [pair,dose], 120,
		"Generated controlled interaction fixture. The complete definition fixes the dose, reservoir, shelf release at tick 12, observations and current engine profiles. Use the normal-dose and small-dose Salt presets as a fresh-reset A/B example, not a tuning verdict. No player/body owner or live brush is omitted by the headless run. The unused bays remain empty inspection space; edit a complete JSON definition to reuse them.")
	_bay(out,176,material,dose,seed)
	out.presentation.regions = [region("contact",pair.to_upper()+" / DOSE %d" % dose,[176,64,132,184])]
	out.observations = [observe("dose-initial",0,"material_cells",[180,68,124,176],material),
		observe("water-initial",0,"water_integer",[180,68,124,176],3),
		observe("dose-state",0,"cell_state",[224+seed%5,134,1,1],material),
		observe("product-60",60,"material_cells",[180,68,124,176],product),
		observe("dose-final",120,"material_cells",[180,68,124,176],material),
		observe("product-final",120,"material_cells",[180,68,124,176],product),
		observe("water-final",120,"water_integer",[180,68,124,176],3),
		observe("reservoir-state",120,"cell_state",[182,238,1,1],product)]
	out.conditions = [{"observation":"product-final","comparison":"ge","value":1,"outcome":"complete"},
		{"observation":"product-final","comparison":"eq","value":0,"outcome":"fail"}]
	return finish(out)
