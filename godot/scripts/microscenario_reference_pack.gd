class_name CyberMicroScenarioReferencePack
extends RefCounted

# Content only: ordinary setup rectangles, finite existing operations, declared
# read-only observations. No scenario-specific tick callback or material kernel.
const Contract = preload("res://scripts/microscenario_contract.gd")
const VERSION: int = 1
const BASELINE: String = "de332eaf8f4e70b25b097bed0c2e2a7b2aac0173 / Baseline transport / Water8-coherence12 / exploratory"
const MATERIAL_IDS: Array[String] = ["materials/contact-lab", "materials/salt-water", "materials/salt-water-dose-small", "materials/lava-water", "materials/sand-water-control", "materials/fire-gunpowder", "materials/acid-metal", "materials/spark-metal", "materials/cement-water"]
const FLOOD_ID: String = "ms001/flood-control"
const REM003_ID: String = "rem003/player-granular-review"
const REM003_EXPERIMENT_PREFIX: String = "rem003/player-granular-review/"
const REM003_SAMPLED_BASELINE_ID: String = REM003_EXPERIMENT_PREFIX + "sampled-baseline"
const REM003_BURIAL_SAFE_ID: String = REM003_EXPERIMENT_PREFIX + "sampled-burial-safe"
const REM003_BARREL_ID: String = REM003_EXPERIMENT_PREFIX + "barrel-rapier"
const REM003_EXPERIMENT_IDS: Array[String] = [
	REM003_SAMPLED_BASELINE_ID,
	REM003_BURIAL_SAFE_ID,
	REM003_BARREL_ID,
]
const STRESS_PREFIX: String = "ms001/stress/"
const STRESS_PROFILES: Array[String] = ["water-flow", "granular-collapse", "gas-column", "mixed"]

static func ids() -> Array[String]:
	var out: Array[String] = MATERIAL_IDS.duplicate()
	out.append(FLOOD_ID)
	out.append(REM003_ID)
	out.append_array(REM003_EXPERIMENT_IDS)
	for profile: String in STRESS_PROFILES: out.append(STRESS_PREFIX + profile)
	return out

static func definition(id: String, seed: int = 0) -> Dictionary:
	match id:
		"materials/contact-lab": return laboratory(seed)
		"materials/salt-water": return interaction_fixture("salt-water", seed, 32)
		"materials/salt-water-dose-small": return interaction_fixture("salt-water", seed, 16)
		"materials/lava-water": return interaction_fixture("lava-water", seed, 32)
		"materials/sand-water-control": return interaction_fixture("sand-water", seed, 32)
		"materials/fire-gunpowder": return mechanism_fixture("fire-gunpowder", seed)
		"materials/acid-metal": return mechanism_fixture("acid-metal", seed)
		"materials/spark-metal": return mechanism_fixture("spark-metal", seed)
		"materials/cement-water": return mechanism_fixture("cement-water", seed)
		FLOOD_ID: return flood_control(seed)
		REM003_ID: return player_granular_review(seed)
	if id in REM003_EXPERIMENT_IDS:
		return player_granular_experiment(id, seed)
	if id.begins_with(STRESS_PREFIX): return simulation_stress(id.trim_prefix(STRESS_PREFIX), seed)
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
	if not pair in ["salt-water", "lava-water", "sand-water"] or not dose in [16,32]: return {}
	var material: int = 23 if pair == "salt-water" else (8 if pair == "lava-water" else 2)
	var product: int = 24 if pair == "salt-water" else (13 if pair == "lava-water" else 2)
	var id: String = "materials/sand-water-control" if pair == "sand-water" else "materials/" + pair
	if dose == 16 and pair != "sand-water": id += "-dose-small"
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


static func mechanism_fixture(mechanism: String, seed: int = 0) -> Dictionary:
	# Mechanism-led generated definitions. They use only ordinary material setup
	# and declared observations; no fixture-specific physics or callbacks.
	if not mechanism in ["fire-gunpowder", "acid-metal", "spark-metal", "cement-water"]: return {}
	var duration: int = 240 if mechanism == "cement-water" else 120
	var out: Dictionary = base("materials/" + mechanism, seed,
		"Materials Laboratory / " + mechanism, mechanism + "/bounded-v1", duration,
		"Generated INT-000 mechanism fixture using ordinary material setup and the shared schema-2 host. Read native interaction provenance in Identities / all results. Declared observations are evidence, not a tuning verdict.")
	var shift: int = seed % 5
	out.camera_origin = [152,48]
	out.interest = {"policy":"fixed", "region":[152,48,176,216]}
	out.rectangles = [176,64,4,184,1, 304,64,4,184,1, 176,244,132,4,1, 176,64,132,4,1]
	match mechanism:
		"fire-gunpowder":
			out.rectangles.append_array([220+shift,184,40,12,26, 220+shift,180,40,4,6])
			out.presentation.regions = [region("contact","FIRE + GUNPOWDER / COMBUSTION",[180,68,124,176])]
			out.observations = [observe("gunpowder-initial",0,"material_cells",[180,68,124,176],26),
				observe("fire-8",8,"material_cells",[180,68,124,176],6),
				observe("gunpowder-final",duration,"material_cells",[180,68,124,176],26)]
		"acid-metal":
			out.rectangles.append_array([220+shift,184,40,8,28, 220+shift,168,40,16,12])
			out.presentation.regions = [region("contact","ACID + METAL / CORROSION",[180,68,124,176])]
			out.observations = [observe("metal-initial",0,"material_cells",[180,68,124,176],28),
				observe("rust-60",60,"material_cells",[180,68,124,176],29),
				observe("rust-final",duration,"material_cells",[180,68,124,176],29)]
		"spark-metal":
			out.rectangles.append_array([220+shift,184,40,8,28, 220+shift,180,40,4,34])
			out.presentation.regions = [region("contact","SPARK + METAL / ELECTRICAL",[180,68,124,176])]
			out.observations = [observe("metal-charge",1,"cell_state",[224+shift,184,1,1],28),
				observe("spark-4",4,"material_cells",[180,68,124,176],34),
				observe("metal-final",duration,"material_cells",[180,68,124,176],28)]
		"cement-water":
			out.rectangles.append_array([216+shift,180,48,24,30])
			out.partial_water_fills = [216+shift,156,48,24,255,0]
			out.presentation.regions = [region("contact","CEMENT + WATER / CURE",[180,68,124,176])]
			out.observations = [observe("cement-initial",0,"material_cells",[180,68,124,176],30),
				observe("concrete-120",120,"material_cells",[180,68,124,176],31),
				observe("concrete-final",duration,"material_cells",[180,68,124,176],31)]
	out.observations.append(observe("end",duration,"tick",[0,0,1,1]))
	match mechanism:
		"fire-gunpowder":
			out.conditions = [
				{"observation":"gunpowder-final","comparison":"le","value":479,"outcome":"complete"},
				{"observation":"gunpowder-final","comparison":"ge","value":480,"outcome":"fail"}]
		"acid-metal":
			out.conditions = [
				{"observation":"rust-60","comparison":"ge","value":1,"outcome":"complete"},
				{"observation":"rust-60","comparison":"eq","value":0,"outcome":"fail"}]
		"spark-metal":
			out.conditions = [
				{"observation":"spark-4","comparison":"le","value":159,"outcome":"complete"},
				{"observation":"spark-4","comparison":"ge","value":160,"outcome":"fail"}]
		"cement-water":
			out.conditions = [
				{"observation":"concrete-120","comparison":"ge","value":1,"outcome":"complete"},
				{"observation":"concrete-120","comparison":"eq","value":0,"outcome":"fail"}]
	out.conditions.append({"observation":"end","comparison":"eq","value":duration,"outcome":"complete"})
	out.source_recipe = "INT-000 generated mechanism fixture v1 / " + mechanism
	return finish(out)


static func player_granular_review(seed: int = 0) -> Dictionary:
	# Seed is retained as definition identity for the shared reference-pack
	# contract. This owner-review surface has no seed-dependent randomization.
	var out: Dictionary = base(
		REM003_ID, seed, "REM-003 Player / Granular Review", "candidate-c1/owner-review-v1", 600,
		"Owner gameplay review for REM-003 candidate C1. Use A/D and Space. Walk, accelerate, brake and reverse on the flat Sand lane; cross the one-cell step and rising shoulder; traverse Dust/Salt support; use the jetpack for ordinary and harder landings onto Sand; RMB erase the marked shelf or supporting bed to trigger loose/falling grains and collapse. Reset with R between comparisons. Judge support, yield, slopes/edges, loose-versus-packed discrimination, transitions and any remaining sticky/rigid/jittery behavior. Automated counters do not decide acceptance."
	)
	out.player_enabled = true
	out.tools = ["player", "erase"]
	out.player_start = [48, 202]
	out.camera_origin = [24, 48]
	out.interest = {"policy":"fixed", "region":[24,48,488,224]}

	# Shared hard floor/walls and separated packed review lanes.
	out.rectangles = [
		32,64,4,200,1, 508,64,4,200,1, 32,260,480,4,1,
		40,216,104,44,2,
		152,216,104,44,2,
		264,216,52,44,14,
		316,216,52,44,23,
		376,216,124,44,2,
		112,215,24,1,2,
		56,132,56,28,2,
		52,160,64,4,1,
		392,154,92,4,1,
	]
	# Rising Sand shoulder/crest. Each column remains ordinary authored material.
	for x: int in range(168, 236):
		var rise: int = mini(14, (x - 168) / 4)
		if rise > 0:
			out.rectangles.append_array([x,216-rise,1,rise,2])

	out.presentation.regions = [
		region("flat","FLAT SAND / WALK + REVERSE",[40,176,104,84]),
		region("shoulder","STEP + SHOULDER / EDGE TRANSITIONS",[144,176,112,84]),
		region("powders","DUST / SALT / MATERIAL BOUNDARY",[264,176,104,84]),
		region("landing","SAND LANDING ZONE / JETPACK DROP",[376,150,124,110]),
		region("collapse","ERASE SHELF / FALLING + COLLAPSE",[48,120,72,76]),
	]
	out.observations = [
		observe("sand-initial",0,"material_cells",[32,120,480,140],2),
		observe("dust-initial",0,"material_cells",[264,176,52,84],14),
		observe("salt-initial",0,"material_cells",[316,176,52,84],23),
		observe("end",600,"tick",[0,0,1,1]),
	]
	out.conditions = [{"observation":"end","comparison":"eq","value":600,"outcome":"complete"}]
	out.source_recipe = "REM-003 candidate C1 playable owner-review surface v1"
	return finish(out)


static func player_configuration(id: String) -> Dictionary:
	match id:
		REM003_SAMPLED_BASELINE_ID:
			return {
				"representation": "sampled",
				"runtime_recovery_enabled": true,
			}
		REM003_BURIAL_SAFE_ID:
			return {
				"representation": "sampled",
				"runtime_recovery_enabled": false,
			}
		REM003_BARREL_ID:
			return {
				"representation": "barrel-rapier",
				"runtime_recovery_enabled": false,
			}
	return {}


static func player_granular_experiment(id: String, seed: int = 0) -> Dictionary:
	if not id in REM003_EXPERIMENT_IDS:
		return {}
	var out: Dictionary = player_granular_review(seed)
	if out.is_empty():
		return out
	var configuration: Dictionary = player_configuration(id)
	var identity: String = str(configuration.get("representation", "sampled"))
	if identity == "sampled" and not bool(
		configuration.get("runtime_recovery_enabled", true)
	):
		identity = "sampled-burial-safe"
	elif identity == "sampled":
		identity = "sampled-baseline"

	out.id = id
	out.maturity = "exploratory"
	out.player_enabled = identity != "barrel-rapier"
	out.body_enabled = identity == "barrel-rapier"
	if out.body_enabled:
		# Schema 2 refuses material-cell census while a body mask is active.
		# Retain only the neutral bounded-horizon observation/objective; visual
		# material-state recording supplies the PLAY-VAL comparison evidence.
		out.observations = [observe("end",600,"tick",[0,0,1,1])]
		out.conditions = [
			{"observation":"end","comparison":"eq","value":600,"outcome":"complete"}
		]
	out.presentation.title = "PLAY-VAL-001 / " + identity
	out.presentation.profile = "play-val-001/" + identity + "/v1"
	out.presentation.instructions = (
		"PLAY-VAL-001 fresh-reset experimental fixture. Geometry, materials, "
		+ "tools, camera and review regions match the REM-003 owner-review "
		+ "surface; only the explicitly named player representation/recovery "
		+ "arm differs. Use A/D for locomotion. Space is sampled-player jetpack "
		+ "only; the barrel arm intentionally retains horizontal impulse control "
		+ "only. RMB erase remains available. Reset with R before comparisons. "
		+ "F6/F7 representation toggles are intentionally disabled while a "
		+ "controlled MicroScenario is active: choose another fixture instead."
	)
	out.source_recipe = (
		"PLAY-VAL-001 selectable REM-003 representation fixture v1 / " + identity
	)
	# Geometry/action ancestry intentionally matches REM003_ID. The canonical
	# complete-definition hash still differs because id/presentation/player/body
	# participation are part of the validated definition.
	return out


static func flood_control(seed: int = 0) -> Dictionary:
	# Compact hydraulic puzzle. The objective is only observed Water in the protected
	# zone after the finite reservoir release; successful witness definitions below
	# change ordinary material geometry, never an objective flag or solver setting.
	var out: Dictionary = base(FLOOD_ID, seed, "Flood-Control Puzzle", "protected-zone/v1", 180,
		"A finite upstream reservoir opens at tick 20. Ensure the marked generator zone is dry at tick 180 using ordinary barriers, berms or diversion geometry. Paint/erase is available for exploration. The objective reads only Water quantity in the protected zone at tick 180; no solution branch changes physics. F8 hides the HUD for a clean view.")
	var shift: int = seed % 3
	out.tools = ["paint", "erase"]
	out.camera_origin = [24,48]
	out.interest = {"policy":"fixed", "region":[24,48,568,304]}
	out.rectangles = [
		32,64,4,280,1, 588,64,4,280,1, 32,340,560,4,1,
		48,244,160,4,1, 204+shift,112,4,136,1,
		208,244,364,4,1, 268,216,92,28,1,
		360,200,4,44,1]
	out.partial_water_fills = [64,144,124,96,255,0]
	out.events = [erase(20,204+shift,216,4,28)]
	out.presentation.regions = [
		region("reservoir","UPSTREAM RESERVOIR",[48,112,160,136]),
		region("protected","KEEP GENERATOR DRY",[244,176,52,68]),
		region("channel","FLOOD CHANNEL",[208,176,164,68])]
	out.observations = [
		observe("initial-reservoir",0,"water_integer",[48,112,160,136],3),
		observe("protected-water",180,"water_integer",[244,176,52,68],3),
		observe("end",180,"tick",[0,0,1,1])]
	out.conditions = [
		{"observation":"protected-water","comparison":"eq","value":0,"outcome":"complete"},
		{"observation":"protected-water","comparison":"ge","value":1,"outcome":"fail"}]
	out.source_recipe = "MS-001 flood-control puzzle v1 / untreated control"
	return finish(out)

static func flood_control_witness(approach: String, seed: int = 0) -> Dictionary:
	# Acceptance witnesses are complete ordinary-geometry definitions evaluated by
	# the exact same objective as the untreated puzzle. They are not selectable
	# solution flags and introduce no scenario-specific host behavior.
	var out: Dictionary = flood_control(seed)
	if out.is_empty(): return out
	match approach:
		"containment":
			# Reinforce the reservoir aperture before its scheduled gate removal.
			out.rectangles.append_array([196 + seed % 3,188,12,56,1])
		"berm":
			# Freestanding upstream barrier across the main channel.
			out.rectangles.append_array([236,140,8,104,1])
		"diversion":
			# Deflector plus a bounded side sump diverts the release below the target.
			out.rectangles.append_array([228,244,24,4,0, 252,140,8,104,1,
				220,244,4,88,1, 252,244,4,88,1, 220,328,36,4,1])
		_:
			return {}
	out.id = "%s/witness-%s" % [FLOOD_ID,approach]
	out.source_recipe = "MS-001 flood-control puzzle v1 / witness " + approach
	return finish(out)

static func simulation_stress(profile: String, seed: int = 0) -> Dictionary:
	if not profile in STRESS_PROFILES: return {}
	var out: Dictionary = base(STRESS_PREFIX + profile, seed, "Simulation Stress Test / " + profile,
		profile + "/bounded-v1", 180,
		"Deterministic bounded workload using existing setup/events only. Benchmark exposes native tick, host-observer and available work counters separately. This is a workload comparison, not target-PC acceptance; unavailable counters remain unavailable.")
	var shift: int = seed % 5
	out.camera_origin = [24,48]
	out.interest = {"policy":"fixed", "region":[24,48,616,360]}
	out.rectangles = [32,64,4,336,1, 636,64,4,336,1, 32,396,608,4,1]
	match profile:
		"water-flow":
			out.presentation.regions = [region("source","SUSTAINED WATER SOURCE",[48,72,156,96]), region("basin","FLOW BASIN",[40,168,588,212])]
			out.rectangles.append_array([48,164,156,4,1])
			out.partial_water_fills = [56+shift,88,136,72,255,0]
			for tick: int in [0,12,24,36,48,60,72,84,96,108,120,132,144,156]:
				out.events.append(fill(tick,72+shift,72,72,8))
			out.observations = [observe("water-final",180,"water_integer",[40,72,588,316],3)]
		"granular-collapse":
			out.presentation.regions = [region("mass","GRANULAR MASS",[88,104,445,128]), region("runout","COLLAPSE / RUNOUT",[48,232,560,148])]
			out.rectangles.append_array([88+shift,104,440,128,2, 72,232,472,6,1])
			out.events = [erase(12,72,232,472,6)]
			out.observations = [observe("sand-final",180,"material_cells",[48,88,560,300],2)]
		"gas-column":
			out.presentation.regions = [region("column","LONG-LIVED SMOKE COLUMN",[96,72,477,284])]
			out.rectangles.append_array([56,88,560,4,1, 96+shift,284,472,72,4])
			out.observations = [observe("smoke-final",180,"material_cells",[48,72,576,316],4)]
		"mixed":
			out.presentation.regions = [region("granular","SAND",[96,88,230,140]), region("water","WATER INPUT",[280,72,88,176]), region("gas","SMOKE",[356,260,228,100])]
			out.rectangles.append_array([72,220,500,6,1, 100+shift,96,220,76,2, 360,284,220,72,4])
			out.partial_water_fills = [96,228,184,104,255,0]
			out.events = [erase(10,72,220,500,6)]
			for tick: int in [30,60,90,120,150]: out.events.append(fill(tick,300,80,48,8))
			out.observations = [
				observe("mixed-water",180,"water_integer",[48,72,576,104],3),
				observe("mixed-sand",180,"material_cells",[48,176,576,104],2),
				observe("mixed-smoke",180,"material_cells",[48,72,576,316],4)]
	out.observations.append(observe("end",180,"tick",[0,0,1,1]))
	out.conditions = [{"observation":"end","comparison":"eq","value":180,"outcome":"complete"}]
	out.source_recipe = "MS-001 bounded Simulation Stress Test v1 / " + profile
	return finish(out)
