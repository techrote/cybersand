extends SceneTree

# LCB-001 (#200) pressure_flow_v1/reference candidate regression through the
# real GDExtension adapter, CyberDemoBridge and MicroScenario host. Every
# section below is demonstrated by native behaviour on registered fixtures;
# a section is reported true only after all of its own checks ran and passed.
# The runtime publisher requires exactly one positive summary line.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const LCB: String = "res://tests/fixtures/lcb/"
const ACCEPT: String = LCB + "acceptance/"
const SCENARIOS: String = LCB + "scenarios/"
const ASSIGNMENTS_AT: int = 20
const LIQUIDS: Array[int] = [3, 8, 12, 16, 20, 21, 24, 30, 32, 33, 36]
const FULL: int = 255
# CYPS/hash v2 includes the shared exact quantity-ledger continuation state.
const PHYSICAL_STATE_VERSION: int = 2
const FRAME: Vector2i = Vector2i(1024, 1024)
const SECTIONS: Array[String] = ["native_dispatch", "no_fallback", "gas_identity", "gas_merge_split",
	"vent_reseal", "empty_only_gas", "quantity_ledger", "physical_state_hash", "save_roundtrip",
	"refusal_isolation", "default_goldens", "worker_parity"]
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}
var bridge: Variant
var default_request: PackedInt32Array
var pressure_request: PackedInt32Array

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
	pressure_request = _with(default_request, 3, 3)
	_native_dispatch_and_no_fallback()
	_gas_identity()
	_gas_merge_split()
	_vent_reseal()
	_empty_only_gas()
	_quantity_ledger_and_parity()
	_hash_and_save_roundtrip()
	_refusal_isolation()
	_default_goldens()
	_finish()

func _finish() -> void:
	print("LCB_PRESSURE_REFERENCE: %d assertions; %d failures; completed=%s" % [
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
	if not expect(checked.get("ok", false), "definition rejected: " + path + " " + str(checked.get("error", ""))):
		return {}
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

func _quantity(world: Variant, origin: Vector2i = Vector2i.ZERO, size: Vector2i = FRAME) -> int:
	return int(world.water_experiment_observation(origin, size).water_integer)

func _gas(world: Variant) -> Dictionary:
	return world.inspect_gas_compartments()

func _by_anchor(gas: Dictionary, anchor: Vector2i) -> Dictionary:
	for compartment: Dictionary in gas.compartments:
		if compartment.anchor == anchor: return compartment
	return {}

# Real native dispatch: the applied receipt names pressure_flow_v1 and the
# vented two-limb fixture, where Current moves zero cells in 2400 ticks,
# transmits head through saturated Water within 300 ticks.
func _native_dispatch_and_no_fallback() -> void:
	var definition: Dictionary = _definition(SCENARIOS + "lcb.head.vented-two-limb.v1.json")
	if definition.is_empty(): return
	var pressure: Dictionary = _install(1, definition, pressure_request)
	var current: Dictionary = _install(1, definition, null)
	if not pressure.ok or not current.ok: return
	var receipt: Dictionary = pressure.host.liquid_solver_policy()
	var water: Dictionary = {}
	for entry: Dictionary in receipt.assignments:
		if int(entry.material) == 3: water = entry
	var dispatch_ok: bool = expect(water.get("applied_family", "") == "pressure_flow_v1"
		and water.get("applied_variant", "") == "reference" and receipt.admission == "qualified_candidate",
		"receipt does not report applied pressure_flow_v1/reference: " + str(water))
	var parameters: Dictionary = receipt.family_parameters.get("pressure_flow_v1", {})
	dispatch_ok = expect(parameters.get("gas_enabled", false) and int(parameters.get("atmospheric_head_rows", 0)) == 32
		and int(receipt.physical_state_hash_version) == PHYSICAL_STATE_VERSION, "pressure family parameters missing from receipt") and dispatch_ok
	# Interest rectangles determine which cells run. Equal window flags alone
	# must never make different selected regions look like matched executions.
	pressure.world.set_simulation_window_enabled(true)
	pressure.world.set_simulation_window(Vector2i.ZERO, Vector2i(128, 128), 0, 0)
	var first_run: Dictionary = pressure.world.get_liquid_run_receipt({})
	pressure.world.set_simulation_window(Vector2i(512, 512), Vector2i(128, 128), 0, 0)
	var second_run: Dictionary = pressure.world.get_liquid_run_receipt({})
	dispatch_ok = expect(first_run.receipt_hash != second_run.receipt_hash
		and first_run.components.simulation_region == "0:0:128:128"
		and second_run.components.simulation_region == "512:512:128:128",
		"run receipt omitted the selected simulation region") and dispatch_ok
	pressure.world.set_simulation_window_enabled(false)
	dispatch_ok = expect(_gas(pressure.world).available and not _gas(current.world).available
		and pressure.world.inspect_pressure_cell(Vector2i(120, 200)).available,
		"pressure sidecar/gas inspection must exist only in the pressure World") and dispatch_ok
	var left_origin: Vector2i = Vector2i(100, 64)
	var limb: Vector2i = Vector2i(48, 184)
	var left_before: int = _quantity(pressure.world, left_origin, limb)
	var right_before: int = _quantity(pressure.world, Vector2i(300, 64), limb)
	var total_before: int = _quantity(pressure.world)
	var current_hash: String = str(current.world.water_experiment_observation(Vector2i.ZERO, FRAME).content_hash)
	if not _advance(pressure, 300) or not _advance(current, 300): return
	var left_after: int = _quantity(pressure.world, left_origin, limb)
	var right_after: int = _quantity(pressure.world, Vector2i(300, 64), limb)
	dispatch_ok = expect(left_after < left_before - 40 * FULL and right_after > right_before + 20 * FULL,
		"pressure head did not cross the saturated passage: left %d->%d right %d->%d" % [
			left_before, left_after, right_before, right_after]) and dispatch_ok
	dispatch_ok = expect(_quantity(pressure.world) == total_before, "pressure two-limb quantity drifted") and dispatch_ok
	var moving: int = 0
	for x: int in range(148, 300, 8):
		if int(pressure.world.inspect_pressure_cell(Vector2i(x, 252)).flow) != 0: moving += 1
	dispatch_ok = expect(moving > 0 or right_after > right_before + 40 * FULL,
		"retained velocity state is not exercised in the passage") and dispatch_ok
	completed["native_dispatch"] = dispatch_ok
	# No fallback: the same fixture under Current stays exactly static, so the
	# motion above cannot be a Current/FreeMass or GDScript path.
	var fallback_ok: bool = expect(str(current.world.water_experiment_observation(Vector2i.ZERO, FRAME).content_hash)
		== current_hash and _quantity(current.world, left_origin, limb) == left_before,
		"Current two-limb control moved")
	fallback_ok = expect(str(pressure.world.water_experiment_observation(Vector2i.ZERO, FRAME).content_hash)
		!= current_hash, "pressure World reproduced Current content") and fallback_ok
	for variant: int in [1, 2]:
		var validation: Dictionary = bridge.validate_liquid_policy(_with(default_request, 3, 3, variant))
		var applied: Dictionary = {}
		if validation.accepted:
			for row: Dictionary in validation.receipt.assignments:
				if int(row.material) == 3: applied = row
		fallback_ok = expect(validation.accepted and validation.refusal == null
			and applied.get("applied_family", "") == "pressure_flow_v1"
			and applied.get("applied_variant", "") == ("cached" if variant == 1 else "cached_dormant"),
			"pressure variant %d must be admitted distinctly without substitution" % variant) and fallback_ok
	completed["no_fallback"] = fallback_ok

func _run_fixture(file: String, workers: int, checks: Callable) -> bool:
	var definition: Dictionary = _definition(ACCEPT + file)
	if definition.is_empty(): return false
	var run: Dictionary = _install(workers, definition, pressure_request)
	if not run.ok: return false
	var horizon: int = Runner.horizon_of(definition)
	var ok: bool = true
	for tick: int in range(1, horizon + 1):
		if not expect(run.host.advance(), file + ": native run faulted at %d" % tick): return false
		ok = bool(checks.call(run.world, tick)) and ok
	return ok

func _gas_identity() -> void:
	var section: bool = true
	for workers: int in [1, 4]:
		var first: Array = [0]
		section = _run_fixture("lcb.accept.gas.single-pocket.v1.json", workers, func(world: Variant, tick: int) -> bool:
			var gas: Dictionary = _gas(world)
			var pocket: Dictionary = _by_anchor(gas, Vector2i(9, 9))
			if not expect(gas.compartments.size() == 1 and int(pocket.get("amount", -1)) == 100
				and int(pocket.get("volume", -1)) == 100, "single pocket at t%d: %s" % [tick, str(gas.compartments)]):
				return false
			if first[0] == 0: first[0] = int(pocket.id)
			return expect(int(pocket.id) == first[0] and int(pocket.generation) == 0 and gas.ledger.closes,
				"single pocket identity changed at t%d" % tick)) and section
		var ids: Array = []
		section = _run_fixture("lcb.accept.gas.twin-pockets.v1.json", workers, func(world: Variant, tick: int) -> bool:
			var gas: Dictionary = _gas(world)
			var a: Dictionary = _by_anchor(gas, Vector2i(9, 9))
			var b: Dictionary = _by_anchor(gas, Vector2i(33, 9))
			if not expect(gas.compartments.size() == 2 and int(a.get("amount", -1)) == 100
				and int(b.get("amount", -1)) == 100, "twin pockets at t%d: %s" % [tick, str(gas.compartments)]):
				return false
			var now: Array = [int(a.id), int(b.id)]
			if ids.is_empty(): ids.append_array(now)
			return expect(now == ids and now[0] != now[1], "twin pocket identities cycled at t%d" % tick)) and section
	completed["gas_identity"] = section

func _gas_merge_split() -> void:
	var section: bool = true
	for workers: int in [1, 4]:
		var parents: Array = []
		section = _run_fixture("lcb.accept.gas.unequal-merge.v1.json", workers, func(world: Variant, tick: int) -> bool:
			var gas: Dictionary = _gas(world)
			if tick <= 1:
				var a: Dictionary = _by_anchor(gas, Vector2i(9, 9))
				var b: Dictionary = _by_anchor(gas, Vector2i(20, 9))
				parents.clear()
				parents.append_array([int(a.get("id", -1)), int(b.get("id", -1))])
				return expect(int(a.get("amount", -1)) == 100 and int(b.get("amount", -1)) == 120,
					"merge inputs at t%d: %s" % [tick, str(gas.compartments)])
			var merged: Dictionary = _by_anchor(gas, Vector2i(9, 9))
			return expect(gas.compartments.size() == 1 and int(merged.get("amount", -1)) == 220
				and int(merged.get("generation", -1)) == 1 and merged.get("ancestry", []) == parents
				and int(merged.id) == parents.min() and int(gas.ledger.merges) == 1 and gas.ledger.closes,
				"unequal merge at t%d: %s" % [tick, str(gas)])) and section
		var parent: Array = [0]
		section = _run_fixture("lcb.accept.gas.split.v1.json", workers, func(world: Variant, tick: int) -> bool:
			var gas: Dictionary = _gas(world)
			if tick <= 3:
				if gas.compartments.size() == 1: parent[0] = int(gas.compartments[0].id)
				return expect(gas.compartments.size() == 1 and int(gas.compartments[0].amount) == 222
					and int(gas.compartments[0].volume) == 222, "split parent at t%d: %s" % [tick, str(gas.compartments)])
			var a: Dictionary = _by_anchor(gas, Vector2i(9, 9))
			var b: Dictionary = _by_anchor(gas, Vector2i(33, 9))
			return expect(gas.compartments.size() == 2 and int(a.get("volume", -1)) == 108
				and int(b.get("volume", -1)) == 111 and int(a.get("amount", -1)) == 110
				and int(b.get("amount", -1)) == 112 and a.get("ancestry", []) == [parent[0]]
				and b.get("ancestry", []) == [parent[0]] and int(a.id) != parent[0] and int(b.id) != parent[0]
				and int(gas.ledger.splits) == 1 and int(gas.ledger.amount_live) == 222
				and _quantity(world, Vector2i(23, 16), Vector2i(3, 1)) == 3 * FULL,
				"split at t%d: %s" % [tick, str(gas)])) and section
	completed["gas_merge_split"] = section

func _vent_reseal() -> void:
	var section: bool = true
	for workers: int in [1, 4]:
		var ids: Array = [0, 0]
		section = _run_fixture("lcb.accept.gas.compress-vent-reseal.v2.json", workers,
			func(world: Variant, tick: int) -> bool:
				var gas: Dictionary = _gas(world)
				if tick == 1:
					ids[0] = int(gas.compartments[0].id) if gas.compartments.size() == 1 else -1
					return expect(gas.compartments.size() == 1 and int(gas.compartments[0].volume) == 100
						and int(gas.compartments[0].amount) == 100, "reseal t1: %s" % str(gas.compartments))
				if tick <= 5:
					return expect(gas.compartments.size() == 1 and int(gas.compartments[0].id) == ids[0]
						and int(gas.compartments[0].volume) == 50 and int(gas.compartments[0].amount) == 100
						and int(gas.compartments[0].gauge_mass) > 0, "compression at t%d: %s" % [tick, str(gas)])
				if tick <= 9:
					var vented: bool = false
					for record: Dictionary in gas.history:
						vented = vented or (int(record.id) == ids[0] and record.vent_state == "vented")
					return expect(gas.compartments.is_empty() and vented and int(gas.ledger.vented) == 100
						and gas.ledger.closes, "vent exchange at t%d: %s" % [tick, str(gas)])
				var resealed: Dictionary = gas.compartments[0] if gas.compartments.size() == 1 else {}
				if ids[1] == 0: ids[1] = int(resealed.get("id", -1))
				return expect(int(resealed.get("volume", -1)) == 58 and int(resealed.get("amount", -1)) == 58
					and int(resealed.get("id", -1)) == ids[1] and ids[1] != ids[0] and int(resealed.generation) == 0
					and _quantity(world, Vector2i(23, 16), Vector2i(3, 1)) == 3 * FULL,
					"reseal at t%d: %s" % [tick, str(gas)])) and section
	completed["vent_reseal"] = section

# Gas stays authoritative when its interior is represented entirely by Empty
# cells: erase the single pocket's Water floor, leaving no Water adjacent.
func _empty_only_gas() -> void:
	var definition: Dictionary = _definition(ACCEPT + "lcb.accept.gas.single-pocket.v1.json")
	if definition.is_empty(): return
	var run: Dictionary = _install(1, definition, pressure_request)
	if not run.ok or not _advance(run, 2): return
	var before: Dictionary = _gas(run.world).compartments[0]
	expect(run.world.water_experiment_erase_rect(Vector2i(9, 19), Vector2i(10, 1)), "floor erase rejected")
	var ok: bool = expect(_quantity(run.world, Vector2i(8, 8), Vector2i(12, 13)) == 0, "pocket floor not erased")
	if not _advance(run, 12): return
	var gas: Dictionary = _gas(run.world)
	var after: Dictionary = gas.compartments[0] if gas.compartments.size() == 1 else {}
	ok = expect(int(after.get("id", -1)) == int(before.id) and int(after.get("amount", -1)) == 100
		and int(after.get("volume", -1)) == 110 and gas.ledger.closes,
		"Empty-only pocket lost its gas: before %s after %s" % [str(before), str(gas)]) and ok
	var cell: Dictionary = run.world.inspect_pressure_cell(Vector2i(12, 12))
	ok = expect(cell.gas == "compartment" and int(cell.gas_compartment) == int(before.id),
		"Empty cell does not carry its compartment label: " + str(cell)) and ok
	completed["empty_only_gas"] = ok

# Exact visible+overfill quantity, closed host ledger and identical 1/4-worker
# physical state on the registered depth-48 dam release.
func _quantity_ledger_and_parity() -> void:
	var definition: Dictionary = _definition(SCENARIOS + "lcb.dam.water.freemass.depth-48.v1.json")
	if definition.is_empty(): return
	var one: Dictionary = _install(1, definition, pressure_request)
	var four: Dictionary = _install(4, definition, pressure_request)
	if not one.ok or not four.ok: return
	var initial: int = _quantity(one.world)
	var ledger_ok: bool = true
	var parity_ok: bool = expect(int(four.world.get_worker_threads()) == 4, "four-worker World not constructed")
	var overfill_seen: int = 0
	for tick: int in range(1, 121):
		if not _advance(one, 1) or not _advance(four, 1): return
		var observation: Dictionary = one.world.water_experiment_observation(Vector2i.ZERO, FRAME)
		overfill_seen = maxi(overfill_seen, int(observation.water_overfill))
		ledger_ok = expect(int(observation.water_integer) == initial
			and int(observation.water_integer) == int(observation.water_visible) + int(observation.water_overfill),
			"visible+overfill quantity drifted at t%d" % tick) and ledger_ok
		if tick % 10 == 0:
			parity_ok = expect(one.world.get_physical_state_hash() == four.world.get_physical_state_hash()
				and str(one.world.water_experiment_observation(Vector2i.ZERO, FRAME).state_hash)
				== str(four.world.water_experiment_observation(Vector2i.ZERO, FRAME).state_hash)
				and _gas(one.world).compartments == _gas(four.world).compartments,
				"1/4-worker divergence at t%d" % tick) and parity_ok
	var capture: Dictionary = one.host.capture()
	var host_ledger: Dictionary = capture.water_ledger
	ledger_ok = expect(host_ledger.available and int(host_ledger.observed_current_integer)
		== int(host_ledger.initial_integer) + int(host_ledger.explicit_source) - int(host_ledger.explicit_sink),
		"MicroScenario Water ledger does not close: " + str(host_ledger)) and ledger_ok
	var front: int = 0
	for x: int in range(983, 239, -1):
		if one.world.material_at(x, 255) == 3:
			front = x - 240
			break
	ledger_ok = expect(front > 40, "dam release did not advance under pressure (front %d)" % front) and ledger_ok
	var flow: Dictionary = one.world.get_pressure_flow_ledger()
	ledger_ok = expect(flow.available and int(flow.last_tick.head_cells) > 0, "pressure ledger unavailable") and ledger_ok
	completed["quantity_ledger"] = ledger_ok
	completed["worker_parity"] = parity_ok

func _hash_and_save_roundtrip() -> void:
	var definition: Dictionary = _definition(SCENARIOS + "lcb.head.vented-two-limb.v1.json")
	if definition.is_empty(): return
	var original: Dictionary = _install(1, definition, pressure_request)
	var current: Dictionary = _install(1, definition, null)
	if not original.ok or not current.ok or not _advance(original, 20) or not _advance(current, 20): return
	var hash_ok: bool = expect(int(original.world.get_physical_state_hash_version()) == PHYSICAL_STATE_VERSION
		and str(original.world.get_physical_state_hash()).length() == 16, "physical-state hash identity")
	hash_ok = expect(original.world.get_physical_state_hash() != current.world.get_physical_state_hash(),
		"physical hash does not distinguish pressure from Current") and hash_ok
	var before_tick: String = original.world.get_physical_state_hash()
	if not _advance(original, 1): return
	hash_ok = expect(original.world.get_physical_state_hash() != before_tick, "physical hash ignored a tick") and hash_ok
	# Gas-bearing state enters the hash: a merge changes it, and the merged
	# table reproduces it after persistence.
	var merge: Dictionary = _install(1, _definition(ACCEPT + "lcb.accept.gas.unequal-merge.v1.json"), pressure_request)
	if not merge.ok or not _advance(merge, 1): return
	var merge_t1: String = merge.world.get_physical_state_hash()
	if not _advance(merge, 1): return
	hash_ok = expect(merge.world.get_physical_state_hash() != merge_t1, "gas merge did not change the physical hash") and hash_ok
	completed["physical_state_hash"] = hash_ok
	# Save at tick 21, restore into a separate adapter, continue both 40 ticks.
	var bytes: PackedByteArray = bridge.export_physical_state(original.world)
	var save_ok: bool = expect(bytes.size() > 64, "physical state export failed: " + str(bridge.get_last_error()))
	save_ok = expect(bytes.size() > 8 and bytes.decode_u32(4) == PHYSICAL_STATE_VERSION,
		"pressure quantity ledger must be encoded as CYPS2") and save_ok
	var restored: Dictionary = _install(1, definition, pressure_request)
	if not restored.ok: return
	save_ok = expect(bridge.import_physical_state(restored.world, bytes),
		"physical state import failed: " + str(bridge.get_last_error())) and save_ok
	save_ok = expect(restored.world.get_physical_state_hash() == original.world.get_physical_state_hash()
		and _gas(restored.world).compartments == _gas(original.world).compartments,
		"restored state differs from the saved World") and save_ok
	for tick: int in range(40):
		expect(original.world.simulation_tick(), "original continuation faulted")
		expect(restored.world.simulation_tick(), "restored continuation faulted")
		save_ok = expect(restored.world.get_physical_state_hash() == original.world.get_physical_state_hash(),
			"exact continuation diverged at +%d" % (tick + 1)) and save_ok
	var merged_bytes: PackedByteArray = bridge.export_physical_state(merge.world)
	var merged_copy: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	save_ok = expect(bridge.import_physical_state(merged_copy, merged_bytes)
		and merged_copy.get_physical_state_hash() == merge.world.get_physical_state_hash()
		and _gas(merged_copy).compartments == _gas(merge.world).compartments,
		"gas table did not survive persistence") and save_ok
	completed["save_roundtrip"] = save_ok

func _snapshot(run: Dictionary) -> Dictionary:
	var observation: Dictionary = run.world.water_experiment_observation(Vector2i.ZERO, FRAME)
	return {"tick":int(run.world.get_tick_index()), "physical":run.world.get_physical_state_hash(),
		"content_hash":observation.content_hash, "water_integer":int(observation.water_integer),
		"policy":run.world.get_liquid_solver_policy(), "gas":_gas(run.world)}

func _refusal_isolation() -> void:
	var definition: Dictionary = _definition(ACCEPT + "lcb.accept.gas.twin-pockets.v1.json")
	if definition.is_empty(): return
	var run: Dictionary = _install(1, definition, pressure_request)
	if not run.ok or not _advance(run, 3): return
	var before: Dictionary = _snapshot(run)
	var bad_block: PackedInt32Array = pressure_request.duplicate()
	bad_block[bad_block.size() - 2] = 1
	bad_block.resize(bad_block.size() + 5)
	var at: int = bad_block.size() - 6
	for word: int in [3, 1, 2, 1, 8]:
		bad_block[at] = word
		at += 1
	bad_block[bad_block.size() - 1] = 0
	var cases: Array = [
		["Oil pressure cached", _with(default_request, 16, 3, 1), "combination_rejected"],
		["Oil pressure cached_dormant", _with(default_request, 16, 3, 2), "combination_rejected"],
		["Water inertial cached", _with(default_request, 3, 4, 1), "variant_unsupported"],
		["Oil pressure", _with(default_request, 16, 3), "combination_rejected"],
		["pressure atmosphere below range", bad_block, "malformed_policy"],
	]
	var ok: bool = true
	for item: Array in cases:
		var refused: bool = not run.host.install(run.world, definition, "Benchmark", true, item[1])
		var refusal: Dictionary = run.host.last_liquid_policy_refusal
		ok = expect(refused and refusal.get("code", "") == item[2], item[0] + ": " + str(refusal)) and ok
		ok = expect(_snapshot(run) == before, item[0] + ": refusal changed the live pressure session") and ok
	var corrupt: PackedByteArray = bridge.export_physical_state(run.world)
	corrupt[corrupt.size() / 2] = corrupt[corrupt.size() / 2] ^ 1
	ok = expect(not bridge.import_physical_state(run.world, corrupt)
		and str(bridge.get_last_error()).contains("running world preserved"),
		"corrupted physical state was not refused visibly") and ok
	ok = expect(_snapshot(run) == before, "refused import changed the live session") and ok
	ok = expect(run.host.active() and run.host.advance() and int(run.world.get_tick_index()) == int(before.tick) + 1,
		"live pressure session does not continue after refusals") and ok
	completed["refusal_isolation"] = ok

# Default policy runs exactly Current: registry tick-30 goldens at 1 and 4
# workers, through this binary, for the protected Dam Break and two-limb fixtures.
func _default_goldens() -> void:
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LCB + "lcb-scenario-registry.json"))
	var ok: bool = expect(registry != null and registry.has("scenarios"), "scenario registry unavailable")
	if not ok: return
	var checked: int = 0
	for entry: Dictionary in registry.scenarios:
		var id: String = entry.id
		if id != "lcb.dam.water.freemass.reference.v1" and id != "lcb.head.vented-two-limb.v1": continue
		var path: String = (LCB if id == "lcb.dam.water.freemass.reference.v1" else SCENARIOS) + id + ".json"
		var definition: Dictionary = _definition(path)
		if definition.is_empty(): return
		for workers: int in [1, 4]:
			for policy: Variant in [null, default_request]:
				var run: Dictionary = _install(workers, definition, policy)
				if not run.ok or not _advance(run, 30): return
				var observation: Dictionary = run.world.water_experiment_observation(Vector2i.ZERO, FRAME)
				ok = expect(str(observation.content_hash) == str(entry.goldens.tick30.content_hash)
					and str(observation.state_hash) == str(entry.goldens.tick30.state_hash)
					and int(observation.water_integer) == int(entry.goldens.tick30.water_integer)
					and int(observation.water_overfill) == 0 and not _gas(run.world).available,
					"%s default golden changed (workers %d)" % [id, workers]) and ok
				checked += 1
	completed["default_goldens"] = ok and checked == 8
