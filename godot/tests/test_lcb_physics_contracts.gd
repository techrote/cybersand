extends SceneTree

# LCB physics prepass contracts that current native interfaces can exercise.
# Every check is a Current-family control or characterization; candidate
# families (pressure, inertial, whole-cell Water) are registered as BLOCKED in
# lcb-physics-contracts.json and are only checked for blocked-ness here.
# Pinned values were measured on 2026-10-23 (Windows, retained runtime) and
# must reproduce on any source-matched runtime.
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const M = preload("res://tests/lcb_physics_metrics.gd")
const CONTRACTS: String = "res://tests/fixtures/lcb/lcb-physics-contracts.json"
var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		push_error("Current native extension is required")
		quit(1)
		return
	var registry: Dictionary = JSON.parse_string(Runner.read_text(CONTRACTS).text)
	_registry(registry)
	_deep_release()
	_heads()
	_accounting()
	_ownership()
	_dormancy()
	_reseal()
	_split()
	_event_boundaries(registry)
	print("LCB physics contracts: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)

func _text(id: String) -> String:
	for folder: String in ["scenarios/", "acceptance/", ""]:
		var path: String = "res://tests/fixtures/lcb/" + folder + id + ".json"
		if FileAccess.file_exists(path): return Runner.read_text(path).text
	expect(false, "Missing fixture " + id)
	return ""

func _run(id: String, workers: int, ticks: int) -> Dictionary:
	var inst: Dictionary = Runner.install(_text(id), workers)
	expect(inst.ok, id + " install refused: " + str(inst.get("error", "")))
	if not inst.ok: return {}
	if not _advance(inst, id, ticks): return {}
	return inst

# Every controlled tick is checked; a fault or a failed capture fails closed and
# no measurement is taken from that run.
func _advance(inst: Dictionary, id: String, ticks: int) -> bool:
	for tick: int in range(ticks):
		if not inst.host.advance():
			expect(false, id + " faulted at tick %d: %s" % [tick, inst.host.last_error])
			return false
	var capture: Dictionary = inst.host.capture(CyberMicroScenarioIdentity.current("unavailable"))
	if bool(capture.get("failed", false)):
		expect(false, id + " capture reports a failed run: " + str(capture.get("error", "")))
		return false
	return true

# Blocked arms stay blocked; acceptance fixtures parse and match their
# Python-derived inventories.
func _registry(registry: Dictionary) -> void:
	expect(str(registry.get("schema", "")) == "lcb-physics-contracts-v1", "Unexpected contract schema")
	for contract: Dictionary in registry.contracts:
		for arm: Dictionary in contract.arms:
			expect(not arm.get("depends_on", []).is_empty(), contract.id + "/" + str(arm.arm) + " has no dependency")
			expect(not arm.has("result") and not arm.has("measured"), contract.id + "/" + str(arm.arm) + " claims a result")
	for fixture: Dictionary in registry.fixtures:
		var inst: Dictionary = Runner.install(Runner.read_text(str(fixture.definition_path)).text, 1)
		expect(inst.ok, fixture.id + " refused: " + str(inst.get("error", "")))
		if not inst.ok: continue
		var inventory: Dictionary = fixture.initial_inventory
		expect(M.water(inst.world, [0, 0, 1024, 1024]) == int(inventory.water_integer), fixture.id + " Water differs")
		var counts: Dictionary = Runner.material_counts(inst.world, inventory.material_region)
		if inventory.cells.has("oil"): expect(int(counts.get(16, 0)) == int(inventory.cells.oil), fixture.id + " Oil differs")

# Deep release versus depth: Current spreads diffusively with almost no depth
# response, so it must not satisfy the frozen candidate surge screens.
func _deep_release() -> void:
	var pins: Dictionary = {"lcb.dam.water.freemass.depth-48.v1":[67, 138.354, 2350080],
		"lcb.dam.water.freemass.depth-160.v1":[71, 139.195, 7833600]}
	var fronts: Dictionary = {}
	for id: String in pins:
		var observed: Array = []
		for workers: int in [1, 4]:
			var inst: Dictionary = _run(id, workers, 240)
			if inst.is_empty(): return
			var front: int = M.front_x(inst.world, 255, 240, 983) - 240
			var centroid: float = M.centroid_x(inst.world, [40, 64, 944, 192])
			expect(M.water(inst.world, [0, 0, 1024, 1024]) == int(pins[id][2]), id + " Water not conserved")
			expect(front == int(pins[id][0]), id + " Current front at t240 changed: %d" % front)
			expect(absf(centroid - float(pins[id][1])) < 0.001, id + " Current centroid changed: %.3f" % centroid)
			observed.append([front, M.world_hashes(inst.world)])
		expect(observed[0] == observed[1], id + " 1/4-worker deep-release results differ")
		fronts[id] = float(observed[0][0])
	var response: float = fronts["lcb.dam.water.freemass.depth-160.v1"] / fronts["lcb.dam.water.freemass.depth-48.v1"]
	expect(response < 1.25, "Current unexpectedly meets a candidate depth-response screen (%.2f)" % response)

# Vented and roofed limbs: Current moves nothing and cannot tell them apart.
# Content hash and Water total must not change; the state hash (which includes
# tick/scheduler state) must equal its measured t300 golden at 1 and 4 workers.
func _heads() -> void:
	var state_t300: Dictionary = {"lcb.head.vented-two-limb.v1":"15825c7a967f67c2",
		"lcb.head.sealed-two-limb.v1":"4462b7b202987cad"}
	var limbs: Array = []
	for id: String in state_t300:
		var per_worker: Array = []
		for workers: int in [1, 4]:
			var inst: Dictionary = _run(id, workers, 0)
			if inst.is_empty(): return
			var before: Array = M.world_hashes(inst.world)
			if not _advance(inst, id, 300): return
			var after: Array = M.world_hashes(inst.world)
			expect(before[0] == after[0] and before[2] == after[2], id + ": Current moved Water in a saturated two-limb")
			expect(after[1] == state_t300[id], id + ": t300 state hash changed: " + str(after[1]))
			per_worker.append(after)
			if workers == 1:
				limbs.append([M.water(inst.world, [100, 64, 48, 184]), M.water(inst.world, [300, 64, 48, 184])])
		expect(per_worker[0] == per_worker[1], id + ": 1/4-worker hashes differ")
	expect(limbs.size() == 2 and limbs[0] == [1860480, 391680] and limbs[0] == limbs[1],
		"Current vented and roofed limbs differ; a gas distinction would need W-PF")

# Signed per-species ledger: Water+Salt consumes one Water cell of any mass.
func _accounting() -> void:
	var inst: Dictionary = _run("lcb.granular.salt-dissolution.v1", 1, 0)
	if inst.is_empty(): return
	var region: Array = [40, 32, 944, 224]
	var salt0: int = int(Runner.material_counts(inst.world, [40, 64, 944, 192]).get(23, 0))
	var water0: int = M.water(inst.world, region)
	if not _advance(inst, "lcb.granular.salt-dissolution.v1", 120): return
	var counts: Dictionary = Runner.material_counts(inst.world, [40, 64, 944, 192])
	var consumed: int = salt0 - int(counts.get(23, 0))
	var delta_water: int = M.water(inst.world, region) - water0
	expect(consumed == 2048 and int(counts.get(24, 0)) == 2 * consumed, "Brine is not exactly two cells per Salt")
	expect(delta_water <= -consumed and delta_water >= -255 * consumed, "Water loss outside the per-reaction bounds")
	expect(delta_water == -514527, "Current partial-Water reaction deficit changed (#160 boundary): %d" % delta_water)
	var mixed: Dictionary = _run("lcb.mixed.water-oil-brine.v1", 1, 0)
	if mixed.is_empty(): return
	var basin: Array = [72, 96, 880, 160]
	var m0: Dictionary = Runner.material_counts(mixed.world, basin)
	var w0: int = M.water(mixed.world, basin)
	if not _advance(mixed, "lcb.mixed.water-oil-brine.v1", 30): return
	var m1: Dictionary = Runner.material_counts(mixed.world, basin)
	var s: int = int(m0.get(23, 0)) - int(m1.get(23, 0))
	expect(int(m1.get(24, 0)) - int(m0.get(24, 0)) == 2 * s, "M0 Brine delta is not +2 per Salt")
	expect(M.water(mixed.world, basin) - w0 == -255 * s, "M0 full-cell Water ledger does not close")
	expect(int(m1.get(16, 0)) == int(m0.get(16, 0)), "M0 Oil not conserved")

# Current cross-material ownership: a density swap moves whole state tuples.
func _ownership() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var results: Array = []
	for workers: int in [1, 4]:
		var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(world.diagnostic_reset({"workers":workers}), "Diagnostic reset failed")
		world.set_simulation_window_enabled(false)
		expect(world.diagnostic_fill_rect(Vector2i(99, 98), Vector2i(1, 5), 1, 0)
			and world.diagnostic_fill_rect(Vector2i(101, 98), Vector2i(1, 5), 1, 0)
			and world.diagnostic_fill_rect(Vector2i(100, 102), Vector2i(1, 1), 1, 0), "Column walls refused")
		expect(world.diagnostic_fill_rect(Vector2i(100, 100), Vector2i(1, 1), 24, 77), "Tagged Brine refused")
		expect(world.water_experiment_fill_rect(Vector2i(100, 101), Vector2i(1, 1), 200, 0), "Partial Water refused")
		for tick: int in range(8): expect(world.simulation_tick(), "Ownership tick failed")
		var top: Dictionary = bridge.inspect_cell(world, Vector2i(100, 100))
		var bottom: Dictionary = bridge.inspect_cell(world, Vector2i(100, 101))
		expect(int(bottom.material) == 24 and int(bottom.state_b) == 77, "Brine tuple did not travel with its cell")
		expect(int(top.material) == 3 and int(top.state_a) == 200, "Partial Water tuple did not travel with its cell")
		results.append([top.material, top.state_a, top.state_b, bottom.material, bottom.state_a, bottom.state_b])
	expect(results[0] == results[1], "Ownership swap differs between 1 and 4 workers")

# Non-pressure motion continues while a Water pool rests (NC-4 Current control).
func _dormancy() -> void:
	var observed: Array = []
	for workers: int in [1, 4]:
		var inst: Dictionary = _run("lcb.accept.dormant-water-active-oil.v1", workers, 600)
		if inst.is_empty(): return
		var oil: Dictionary = Runner.material_counts(inst.world, [488, 64, 496, 192])
		var low: Dictionary = Runner.material_counts(inst.world, [488, 224, 496, 32])
		expect(M.water(inst.world, [40, 64, 440, 192]) == 440 * 160 * 255, "Resting pool changed")
		expect(int(oil.get(16, 0)) == 4096 and int(low.get(16, 0)) == 4078, "Oil did not keep moving beside resting Water")
		observed.append(M.world_hashes(inst.world))
	expect(observed[0] == observed[1], "Dormancy control differs between 1 and 4 workers")

# Reseal v2 geometry control on Current (no gas): the closure opens, and the
# U-trap Water plug is supported and stationary from tick 10 to tick 30.
func _reseal() -> void:
	var id: String = "lcb.accept.gas.compress-vent-reseal.v2"
	var observed: Array = []
	for workers: int in [1, 4]:
		var inst: Dictionary = _run(id, workers, 10)
		if inst.is_empty(): return
		var trap10: int = M.water(inst.world, [23, 16, 3, 1])
		if not _advance(inst, id, 20): return
		var trap30: int = M.water(inst.world, [23, 16, 3, 1])
		expect(trap10 == 3 * 255 and trap30 == 3 * 255, id + ": trap seal Water moved (%d, %d)" % [trap10, trap30])
		expect(int(inst.world.material_at(19, 12)) == 0, id + ": closure cell not open after tick 5")
		expect(M.water(inst.world, [8, 8, 12, 13]) == 2550 + 50 * 255, id + ": room Water changed after compression")
		observed.append(M.world_hashes(inst.world))
	expect(observed[0] == observed[1], id + ": 1/4-worker results differ")

# Split v1 geometry control on Current (no gas): the trap closure plug is
# supported and stationary, and no other Water moves.
func _split() -> void:
	var id: String = "lcb.accept.gas.split.v1"
	var observed: Array = []
	for workers: int in [1, 4]:
		var inst: Dictionary = _run(id, workers, 5)
		if inst.is_empty(): return
		var trap5: int = M.water(inst.world, [23, 16, 3, 1])
		if not _advance(inst, id, 25): return
		var trap30: int = M.water(inst.world, [23, 16, 3, 1])
		expect(trap5 == 3 * 255 and trap30 == 3 * 255, id + ": trap closure Water moved (%d, %d)" % [trap5, trap30])
		expect(int(inst.world.material_at(19, 12)) == 0 and int(inst.world.material_at(32, 12)) == 0,
			id + ": room openings are not open")
		expect(M.water(inst.world, [8, 8, 36, 13]) == 2 * 2550 + 3 * 255, id + ": Water changed outside the closure fill")
		observed.append(M.world_hashes(inst.world))
	expect(observed[0] == observed[1], id + ": 1/4-worker results differ")

# Gas event phases: the host observes completed tick N before it applies the
# events indexed N (they run before native tick N+1). Each registered event
# rectangle must hold its pre-event material at completed N and its post-event
# material at completed N+1, at 1 and 4 workers; any fault fails closed.
func _event_boundaries(registry: Dictionary) -> void:
	var expected: Dictionary = {}
	for contract: Dictionary in registry.contracts:
		if str(contract.id) == "gas-topology": expected = contract.expected
	expect(not expected.is_empty(), "gas-topology contract missing")
	var checked: int = 0
	for id: String in expected:
		if not (expected[id] is Dictionary) or not expected[id].has("event_boundaries"): continue
		for workers: int in [1, 4]:
			var inst: Dictionary = _run(id, workers, 0)
			if inst.is_empty(): return
			var at: int = 0
			for boundary: Dictionary in expected[id].event_boundaries:
				for side: int in range(2):
					var tick: int = int(boundary.check_ticks[side])
					if not _advance(inst, id, tick - at): return
					at = tick
					var want: int = int((boundary.material_before if side == 0 else boundary.material_after)[0])
					var r: Array = boundary.rect
					var wrong: int = 0
					for y: int in range(int(r[1]), int(r[1]) + int(r[3])):
						for x: int in range(int(r[0]), int(r[0]) + int(r[2])):
							if int(inst.world.material_at(x, y)) != want: wrong += 1
					expect(wrong == 0, "%s w%d: %s at completed t%d has %d cells != material %d" % [
						id, workers, str(boundary.event), tick, wrong, want])
					checked += 1
	expect(checked == 2 * 2 * 5, "expected 5 gas events checked on both sides at 1/4 workers, got %d" % checked)
