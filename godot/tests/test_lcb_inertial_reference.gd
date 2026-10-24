extends SceneTree

# LCB-005 (#212) inertial_cellular_v1/reference through the real GDExtension
# adapter and MicroScenario host, on the registered mixed-liquid fixture
# (Brine | Water + Salt | Oil lock exchange). M2 runs three families in ONE
# native World: Water freemass_v1, Oil cellular_yield_v1, Brine
# inertial_cellular_v1; M2b substitutes Water pressure_flow_v1. Sections are
# reported true only after their own checks ran and passed.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const MIXED: String = "res://tests/fixtures/lcb/lcb.mixed.water-oil-brine.v1.json"
const REGISTRY: String = "res://tests/fixtures/lcb/lcb-scenario-registry.json"
const ASSIGNMENTS_AT: int = 20
const LIQUIDS: Array[int] = [3, 8, 12, 16, 20, 21, 24, 30, 32, 33, 36]
const BRINE: int = 24
const OIL: int = 16
const WATER: int = 3
const REGION: Rect2i = Rect2i(48, 80, 928, 200)
const FRAME: Vector2i = Vector2i(1024, 1024)
const TICKS: int = 300
const SECTIONS: Array[String] = ["native_dispatch", "three_family_world", "pressure_substitution",
	"momentum_ledger", "lifecycle_state", "save_roundtrip", "refusal_isolation", "default_goldens",
	"worker_parity"]
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}
var bridge: Variant
var default_request: PackedInt32Array

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)
	return value

func _initialize() -> void:
	for section: String in SECTIONS: completed[section] = false
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		expect(false, "current native extension unavailable")
		_finish()
		return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	default_request = bridge.default_liquid_policy()
	var definition: Dictionary = _definition(MIXED)
	if not definition.is_empty():
		_three_families(definition)
		_refusals(definition)
		_default_goldens(definition)
	_finish()

func _finish() -> void:
	print("LCB_INERTIAL_REFERENCE: %d assertions; %d failures; completed=%s" % [
		assertions, failures, JSON.stringify(completed)])
	quit(1 if failures > 0 else 0)

func _with(request: PackedInt32Array, material: int, family: int, variant: int = 0) -> PackedInt32Array:
	var words: PackedInt32Array = request.duplicate()
	var row: int = LIQUIDS.find(material)
	words[ASSIGNMENTS_AT + row * 3 + 1] = family
	words[ASSIGNMENTS_AT + row * 3 + 2] = variant
	return words

func _definition(path: String) -> Dictionary:
	var source: Dictionary = Runner.read_text(path)
	if not expect(source.ok, "definition unavailable: " + path): return {}
	var checked: Dictionary = Contract.parse(source.text)
	if not expect(checked.get("ok", false), "definition rejected: " + path): return {}
	return checked.definition

func _install(workers: int, definition: Dictionary, policy: Variant) -> Dictionary:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":workers}), "native worker configuration rejected")
	world.set_simulation_window_enabled(false)
	var host: CyberMicroScenarioHost = Host.new()
	var ok: bool = host.install(world, definition, "Benchmark", true, policy)
	expect(ok, "install refused: " + host.last_error)
	return {"world":world, "host":host, "ok":ok}

func _advance(run: Dictionary, ticks: int) -> bool:
	for _tick: int in range(ticks):
		if not expect(run.host.advance(), "native run faulted: " + str(run.host.last_error)): return false
	return true

func _census(world: Variant) -> Dictionary:
	var counts: Dictionary = {BRINE:0, OIL:0, WATER:0}
	var depth: Dictionary = {BRINE:0.0, OIL:0.0, WATER:0.0}
	var vx: int = 0
	var vy: int = 0
	var speed: int = 0
	var stray: int = 0
	for y: int in range(REGION.position.y, REGION.end.y):
		for x: int in range(REGION.position.x, REGION.end.x):
			var material: int = world.material_at(x, y)
			if counts.has(material):
				counts[material] += 1
				depth[material] += y
			if material == BRINE or material == 0:
				var state: Dictionary = world.inspect_inertial_cell(Vector2i(x, y))
				if not state.available: continue
				if material == BRINE:
					vx += int(state.vx)
					vy += int(state.vy)
					speed += absi(int(state.vx)) + absi(int(state.vy))
				elif int(state.vx) != 0 or int(state.vy) != 0 or int(state.ax) != 0 or int(state.ay) != 0:
					stray += 1
	var mean: Dictionary = {}
	for key: int in counts: mean[key] = depth[key] / maxf(1.0, float(counts[key]))
	return {"counts":counts, "mean_y":mean, "vx":vx, "vy":vy, "speed":speed, "stray":stray}

func _layering(world: Variant, x0: int, x1: int) -> Dictionary:
	var brine: int = 0
	var oil: int = 0
	var brine_y: float = 0.0
	var oil_y: float = 0.0
	for y: int in range(96, 256):
		for x: int in range(x0, x1):
			var material: int = world.material_at(x, y)
			if material == BRINE:
				brine += 1
				brine_y += y
			elif material == OIL:
				oil += 1
				oil_y += y
	return {"brine":brine, "oil":oil, "brine_y":brine_y / maxf(1.0, float(brine)),
		"oil_y":oil_y / maxf(1.0, float(oil))}

func _applied(receipt: Dictionary, material: int) -> String:
	for entry: Dictionary in receipt.assignments:
		if int(entry.material) == material: return str(entry.applied_family)
	return ""

func _three_families(definition: Dictionary) -> void:
	var m2_request: PackedInt32Array = _with(default_request, BRINE, 4)
	var m2b_request: PackedInt32Array = _with(m2_request, WATER, 3)
	var m2: Dictionary = _install(1, definition, m2_request)
	var m2_four: Dictionary = _install(4, definition, m2_request)
	var current: Dictionary = _install(1, definition, null)
	var m2b: Dictionary = _install(1, definition, m2b_request)
	var m2b_four: Dictionary = _install(4, definition, m2b_request)
	if not (m2.ok and m2_four.ok and current.ok and m2b.ok and m2b_four.ok): return
	var receipt: Dictionary = m2.host.liquid_solver_policy()
	var dispatch_ok: bool = expect(_applied(receipt, WATER) == "freemass_v1" and _applied(receipt, OIL) == "cellular_yield_v1"
		and _applied(receipt, BRINE) == "inertial_cellular_v1" and receipt.admission == "qualified_candidate"
		and receipt.family_parameters.has("inertial_cellular_v1")
		and int(receipt.family_parameters.inertial_cellular_v1.vmax) == 32,
		"M2 receipt must apply three distinct families: " + str(receipt.assignments))
	var receipt_b: Dictionary = m2b.host.liquid_solver_policy()
	dispatch_ok = expect(_applied(receipt_b, WATER) == "pressure_flow_v1" and _applied(receipt_b, BRINE)
		== "inertial_cellular_v1" and _applied(receipt_b, OIL) == "cellular_yield_v1",
		"M2b receipt must substitute pressure Water") and dispatch_ok
	var start: Dictionary = _census(m2.world)
	var water_start: int = int(m2.world.water_experiment_observation(Vector2i.ZERO, FRAME).water_integer)
	var parity_ok: bool = true
	for tick: int in range(1, TICKS + 1):
		for run: Dictionary in [m2, m2_four, current, m2b, m2b_four]:
			if not _advance(run, 1): return
		if tick % 30 == 0:
			parity_ok = expect(m2.world.get_physical_state_hash() == m2_four.world.get_physical_state_hash()
				and m2b.world.get_physical_state_hash() == m2b_four.world.get_physical_state_hash(),
				"1/4-worker divergence at t%d" % tick) and parity_ok
	completed["worker_parity"] = parity_ok
	var end: Dictionary = _census(m2.world)
	var base: Dictionary = _census(current.world)
	# Real native inertial dispatch: the same fixture under Current (Brine on
	# cellular_yield_v1) evolves differently, and Brine carries velocity state.
	dispatch_ok = expect(m2.world.get_physical_state_hash() != current.world.get_physical_state_hash()
		and str(m2.world.water_experiment_observation(Vector2i.ZERO, FRAME).content_hash)
		!= str(current.world.water_experiment_observation(Vector2i.ZERO, FRAME).content_hash),
		"inertial Brine reproduced the Current CellularYield World") and dispatch_ok
	var ledger: Dictionary = m2.world.get_inertial_ledger()
	dispatch_ok = expect(ledger.available and int(ledger.updates) > 0 and int(ledger.unit_moves) > 0,
		"inertial kernel did not run: " + str(ledger)) and dispatch_ok
	completed["native_dispatch"] = dispatch_ok
	# Three families interacting: Oil whole cells are conserved; Brine only grows
	# by the registered Water+Salt reaction; Water quantity only falls by it;
	# density ordering emerges from real cross-family exchanges.
	var family_ok: bool = expect(int(end.counts[OIL]) == int(start.counts[OIL]),
		"Oil whole-cell count drifted %d -> %d" % [start.counts[OIL], end.counts[OIL]])
	# The fixture's only Brine reaction creates Brine (Water + Salt).
	family_ok = expect(int(end.counts[BRINE]) >= int(start.counts[BRINE]) and int(base.counts[BRINE]) >= int(start.counts[BRINE]),
		"Brine count fell without a reaction") and family_ok
	var water_end: int = int(m2.world.water_experiment_observation(Vector2i.ZERO, FRAME).water_integer)
	family_ok = expect(water_end <= water_start, "Water quantity grew without a source") and family_ok
	# Lock exchange inside the middle (Water) compartment: Brine undercuts the
	# Water along the floor while Oil rides over it.
	var middle: Dictionary = _layering(m2.world, 304, 528)
	family_ok = expect(int(middle.brine) > 0 and int(middle.oil) > 0
		and float(middle.brine_y) > float(middle.oil_y),
		"Brine must undercut and Oil ride over the Water compartment: %s" % str(middle)) and family_ok
	family_ok = expect(int(ledger.density_swaps) > 0, "inertial Brine never exchanged with a lighter liquid") and family_ok
	completed["three_family_world"] = family_ok
	# Momentum: the signed per-component identity closes for every Brine cell.
	var momentum_ok: bool = expect(int(end.vx) - int(start.vx) == int(ledger.impulse_x) + int(ledger.external_x)
		- int(ledger.retired_x) and int(end.vy) - int(start.vy) == int(ledger.gravity_y) + int(ledger.impulse_y)
		+ int(ledger.external_y) - int(ledger.retired_y),
		"inertial momentum ledger does not close: %s %s" % [str(end), str(ledger)])
	momentum_ok = expect(int(end.speed) - int(start.speed) == int(ledger.gravity_y) - int(ledger.loss)
		- int(ledger.velocity_retired) and int(ledger.loss) >= 0, "inertial speed-loss ledger does not close") and momentum_ok
	completed["momentum_ledger"] = momentum_ok
	completed["lifecycle_state"] = expect(int(end.stray) == 0 and int(_census(m2b.world).stray) == 0,
		"inertial state left on a vacancy")
	# Pressure substitution: Water on pressure_flow_v1 meets inertial Brine and
	# cellular_yield Oil in the same World.
	var sub_end: Dictionary = _census(m2b.world)
	var substitution_ok: bool = expect(int(sub_end.counts[OIL]) == int(start.counts[OIL])
		and m2b.world.inspect_gas_compartments().available and int(m2b.world.get_inertial_ledger().updates) > 0,
		"pressure substitution World did not run both candidate families")
	substitution_ok = expect(m2b.world.get_physical_state_hash() != m2.world.get_physical_state_hash(),
		"pressure Water reproduced FreeMass Water") and substitution_ok
	var observation: Dictionary = m2b.world.water_experiment_observation(Vector2i.ZERO, FRAME)
	substitution_ok = expect(int(observation.water_integer) == int(observation.water_visible)
		+ int(observation.water_overfill), "pressure quantity observation inconsistent") and substitution_ok
	completed["pressure_substitution"] = substitution_ok
	# Persistence: both sidecars and the inertial ledger survive exactly.
	var bytes: PackedByteArray = bridge.export_physical_state(m2b.world)
	var restored: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var save_ok: bool = expect(bytes.size() > 64 and bridge.import_physical_state(restored, bytes),
		"physical state round trip failed: " + str(bridge.get_last_error()))
	save_ok = expect(restored.get_physical_state_hash() == m2b.world.get_physical_state_hash(),
		"restored three-family World differs") and save_ok
	for tick: int in range(30):
		expect(m2b.world.simulation_tick(), "original continuation faulted")
		expect(restored.simulation_tick(), "restored continuation faulted")
	save_ok = expect(restored.get_physical_state_hash() == m2b.world.get_physical_state_hash(),
		"three-family exact continuation diverged") and save_ok
	completed["save_roundtrip"] = save_ok

func _refusals(definition: Dictionary) -> void:
	var run: Dictionary = _install(1, definition, _with(default_request, BRINE, 4))
	if not run.ok or not _advance(run, 5): return
	var before: String = run.world.get_physical_state_hash()
	var generation: int = int(run.world.get_liquid_policy_session_generation())
	var ok: bool = true
	for item: Array in [
			["Water inertial", _with(default_request, WATER, 4), "family_unavailable"],
			["Oil inertial", _with(default_request, OIL, 4), "combination_rejected"],
			["Toxic Sludge alternate", _with(default_request, 32, 4), "not_selectable"],
			["Brine pressure", _with(default_request, BRINE, 3), "combination_rejected"]]:
		var refused: bool = not run.host.install(run.world, definition, "Benchmark", true, item[1])
		ok = expect(refused and run.host.last_liquid_policy_refusal.get("code", "") == item[2],
			item[0] + ": " + str(run.host.last_liquid_policy_refusal)) and ok
		ok = expect(run.world.get_physical_state_hash() == before
			and int(run.world.get_liquid_policy_session_generation()) == generation,
			item[0] + ": refusal changed the live session") and ok
	completed["refusal_isolation"] = ok

func _default_goldens(definition: Dictionary) -> void:
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	if not expect(registry is Dictionary and registry.has("scenarios"), "registry unavailable"): return
	var golden: Dictionary = {}
	for entry: Dictionary in registry.scenarios:
		if entry.id == "lcb.mixed.water-oil-brine.v1": golden = entry.goldens.tick30
	var ok: bool = expect(not golden.is_empty(), "mixed fixture golden missing")
	for workers: int in [1, 4]:
		for policy: Variant in [null, default_request]:
			var run: Dictionary = _install(workers, definition, policy)
			if not run.ok or not _advance(run, 30): return
			var observation: Dictionary = run.world.water_experiment_observation(Vector2i.ZERO, FRAME)
			ok = expect(str(observation.content_hash) == str(golden.content_hash)
				and str(observation.state_hash) == str(golden.state_hash)
				and int(observation.water_integer) == int(golden.water_integer)
				and not run.world.get_inertial_ledger().available,
				"default mixed-fixture golden changed (workers %d)" % workers) and ok
	completed["default_goldens"] = ok
