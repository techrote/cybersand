extends RefCounted

# LCB-FEEL #360 versioned comparison scenario catalogue (presentation data).
# Every runnable entry is an existing or newly versioned schema-2 controlled
# fixture; original LCB fixture bytes are reused unchanged. Slot 7 has no
# actor-free controlled fixture and is explicitly unavailable here.
const VERSION: String = "lcb.feel.catalogue.v1"
const LCB: String = "res://tests/fixtures/lcb/scenarios/"
const FEEL: String = "res://tests/fixtures/lcb/feel/"
const SCENARIOS: Array[Dictionary] = [
	{"slot":"1", "id":"lcb.feel.leak-side.vented.v1", "title":"1 Side leak, vented lid", "fixture":FEEL + "lcb.feel.leak-side.vented.v1.json",
		"measure":"Leak continuity, lateral momentum, quantity and cessation; opens at tick 120"},
	{"slot":"1", "id":"lcb.feel.leak-side.sealed.v1", "title":"1 Side leak, sealed lid", "fixture":FEEL + "lcb.feel.leak-side.sealed.v1.json",
		"measure":"As vented; only PressureFlow tracks the closed headspace as gas"},
	{"slot":"2", "id":"lcb.feel.drain-bottom.vented.v1", "title":"2 Bottom drain, vented lid", "fixture":FEEL + "lcb.feel.drain-bottom.vented.v1.json",
		"measure":"Emptying, cavities and apparent bubbles, residual motion; opens at tick 120"},
	{"slot":"2", "id":"lcb.feel.drain-bottom.sealed.v1", "title":"2 Bottom drain, sealed lid", "fixture":FEEL + "lcb.feel.drain-bottom.sealed.v1.json",
		"measure":"Classify apparent bubbles by state: Empty cells, displaced liquid or PF gas"},
	{"slot":"2", "id":"lcb.feel.tank-closed.control.v1", "title":"2 Closed tank control", "fixture":FEEL + "lcb.feel.tank-closed.control.v1.json",
		"measure":"No opening: quantity, rest and idle work"},
	{"slot":"3", "id":"lcb.dam.water.freemass.depth-96.v1", "title":"3 Deep dam release, depth 96", "fixture":LCB + "lcb.dam.water.freemass.depth-96.v1.json",
		"measure":"Outward surge, front bands, retained reservoir"},
	{"slot":"4", "id":"lcb.head.narrow-passage.v1", "title":"4 Narrow passage", "fixture":LCB + "lcb.head.narrow-passage.v1.json",
		"measure":"Throughput and head response through a constriction"},
	{"slot":"4", "id":"lcb.head.vented-two-limb.v1", "title":"4 Communicating vessels, vented", "fixture":LCB + "lcb.head.vented-two-limb.v1.json",
		"measure":"Shared-atmosphere settling; equal levels are valid only because both limbs vent"},
	{"slot":"4", "id":"lcb.head.sealed-two-limb.v1", "title":"4 Communicating vessels, sealed", "fixture":LCB + "lcb.head.sealed-two-limb.v1.json",
		"measure":"Sealed-limb assumption; equal levels are not the target"},
	{"slot":"5", "id":"lcb.rest.deep-quiet-pool.v1", "title":"5 Quiet pool", "fixture":LCB + "lcb.rest.deep-quiet-pool.v1.json",
		"measure":"Dormancy, unwanted motion, idle work"},
	{"slot":"5", "id":"lcb.rest.remote-disturbance.v1", "title":"5 Quiet pool, remote wake", "fixture":LCB + "lcb.rest.remote-disturbance.v1.json",
		"measure":"Wake at tick 300 (source) and 900 (sink), then rest"},
	{"slot":"6", "id":"lcb.shallow.stream-steps.v1", "title":"6 Scheduled source stream", "fixture":LCB + "lcb.shallow.stream-steps.v1.json",
		"measure":"Whole-cell source every 30 ticks to 600, then stop tail. No directed momentum inlet exists (#361)"},
	{"slot":"7", "id":"", "title":"7 Rapier impact (Exploratory only)", "fixture":"",
		"measure":"Controlled comparison is actor-free. Use Exploratory with a supported body MicroScenario; contact analysis is #362",
		"unavailable":"No actor-free controlled fixture can carry a Rapier body; choose Exploratory with a body-bearing MicroScenario"},
	{"slot":"mixed", "id":"lcb.mixed.water-oil-brine.v1", "title":"Mixed Water / Oil / Brine", "fixture":"res://tests/fixtures/lcb/lcb.mixed.water-oil-brine.v1.json",
		"measure":"Per-material families in one World: e.g. Water PF or Current + Brine IN + Oil CY"},
	{"slot":"mixed", "id":"lcb.density.water-brine-lock-exchange.v1", "title":"Mixed Water / Brine lock exchange", "fixture":LCB + "lcb.density.water-brine-lock-exchange.v1.json",
		"measure":"Density exchange with Brine IN or CY"},
]

static func entry(index: int) -> Dictionary:
	return SCENARIOS[index] if index >= 0 and index < SCENARIOS.size() else {}

static func index_of(identifier: String) -> int:
	for index: int in SCENARIOS.size():
		if SCENARIOS[index].id == identifier: return index
	return -1
