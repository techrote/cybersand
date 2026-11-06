extends SceneTree

# Deterministic #361 leak-flow fixture. Cavity and motion observations describe
# authoritative material/IN state only; they are not evidence of gas pressure.
const Contract = preload("res://scripts/microscenario_contract.gd")
const FIXTURE := "res://tests/fixtures/in-tools-361-leak-flow.v1.json"
const WALL: int = 1
const WATER: int = 3
var assertions: int = 0
var failures: int = 0
var bridge: Object
var transport: PackedInt32Array
var fixture: Dictionary


func _initialize() -> void:
	run.call_deferred()


func expect(ok: bool, message: String) -> bool:
	assertions += 1
	if not ok:
		failures += 1
		push_error("IN_TOOLS_361_LEAK_FLOW: " + message)
	return ok


func _policy() -> PackedInt32Array:
	var p: PackedInt32Array = bridge.default_liquid_policy()
	p[21] = 4
	p[22] = 0
	return p


func _world(workers: int) -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers": workers}), "diagnostic worker selection admits")
	var rectangles := PackedInt32Array(fixture.wall_rectangles)
	rectangles.append_array(PackedInt32Array(fixture.water_rectangle))
	var semantics := PackedInt32Array(fixture.water_semantics)
	var policy := _policy()
	var claim: String = JSON.stringify({
		"fixture": fixture.id, "workers": workers, "rectangles": rectangles,
		"semantics": semantics, "policy": policy,
	}).sha256_text()
	var token: int = bridge.prepare_liquid_world(
		world, rectangles, transport, semantics, PackedInt32Array(), policy,
		{"definition_hash": claim, "region": PackedInt32Array(fixture.domain),
		 "simulation_window_enabled": false, "intent": "exploratory",
		 "maximum_rule_radius": int(fixture.maximum_rule_radius),
		 "cadence_lod_enabled": false, "liquid_surface_adhesion_enabled": false})
	expect(token > 0 and bridge.commit_liquid_world(world, token),
		"source-qualified Water-IN tank constructs")
	return world


func _snapshot(world: Object, region: Array) -> Dictionary:
	return world.diagnostic_snapshot(
		Vector2i(int(region[0]), int(region[1])),
		Vector2i(int(region[2]), int(region[3])), false)


func _quantity(world: Object) -> int:
	return int(world.water_experiment_observation(Vector2i.ZERO, Vector2i(64, 64)).water_integer)


func _released_motion(world: Object) -> Dictionary:
	var r: Array = fixture.released_region
	var water_cells: int = 0
	var moving: int = 0
	var lateral: int = 0
	var maximum_abs_vx: int = 0
	var maximum_abs_vy: int = 0
	for y: int in range(int(r[1]), int(r[1]) + int(r[3])):
		for x: int in range(int(r[0]), int(r[0]) + int(r[2])):
			if world.material_at(x, y) != WATER:
				continue
			water_cells += 1
			var state: Dictionary = world.inspect_inertial_cell(Vector2i(x, y))
			var vx: int = int(state.get("vx", 0))
			var vy: int = int(state.get("vy", 0))
			maximum_abs_vx = maxi(maximum_abs_vx, absi(vx))
			maximum_abs_vy = maxi(maximum_abs_vy, absi(vy))
			if vx != 0 or vy != 0:
				moving += 1
			if vx != 0:
				lateral += 1
	return {"water_cells": water_cells, "moving_cells": moving,
		"lateral_cells": lateral, "maximum_abs_vx": maximum_abs_vx,
		"maximum_abs_vy": maximum_abs_vy}


func _execute(workers: int) -> Dictionary:
	var world: Object = _world(workers)
	var aperture := Vector2i(int(fixture.aperture[0]), int(fixture.aperture[1]))
	var initial_quantity: int = _quantity(world)
	var initial_tank: Dictionary = _snapshot(world, fixture.tank_interior)
	var initial_hash: String = world.get_physical_state_hash()
	var opened: Dictionary = world.in_tools_set_aperture(aperture, true)
	expect(opened.get("accepted", false) and opened.get("changed", false)
		and int(opened.get("quantity_delta", -1)) == 0,
		"1x1 puncture opens without source/sink quantity")
	expect(_quantity(world) == initial_quantity and world.get_physical_state_hash() != initial_hash,
		"opening changes geometry but not stored Water quantity")

	var escaped: bool = false
	var occupied_refusal: bool = false
	var close_tick: int = -1
	var motion_at_close: Dictionary = {}
	var maximum_outside: int = 0
	var maximum_empty_in_original_water: int = 0
	var wr: Array = fixture.water_rectangle
	var water_region: Array = [wr[0], wr[1], wr[2], wr[3]]
	for tick: int in range(int(fixture.open_ticks_max)):
		expect(world.simulation_tick(), "open leak native tick succeeds")
		var outside: Dictionary = _snapshot(world, fixture.released_region)
		var outside_cells: int = int(outside.counts[WATER])
		maximum_outside = maxi(maximum_outside, outside_cells)
		escaped = escaped or outside_cells > 0
		var original: Dictionary = _snapshot(world, water_region)
		maximum_empty_in_original_water = maxi(maximum_empty_in_original_water, int(original.counts[0]))
		if escaped and world.material_at(aperture.x, aperture.y) == WATER and not occupied_refusal:
			var q_before: int = _quantity(world)
			var hash_before: String = world.get_physical_state_hash()
			var blocked: Dictionary = world.in_tools_set_aperture(aperture, false)
			expect(not blocked.get("accepted", true) and blocked.get("reason") == "occupied_aperture"
				and _quantity(world) == q_before and world.get_physical_state_hash() == hash_before,
				"occupied closure refuses with exact world preservation")
			occupied_refusal = true
		if escaped and world.material_at(aperture.x, aperture.y) == 0:
			var closed: Dictionary = world.in_tools_set_aperture(aperture, false)
			if closed.get("accepted", false):
				close_tick = tick + 1
				motion_at_close = _released_motion(world)
				break

	expect(escaped and maximum_outside > 0, "actual Water escapes through the authored bottom puncture")
	expect(close_tick > 0 and world.material_at(aperture.x, aperture.y) == WALL,
		"aperture later clears and closes reversibly")
	expect(_quantity(world) == initial_quantity,
		"leak period closes exact source/sink ledger: zero source + zero sink = invariant Water quantity")
	expect(maximum_empty_in_original_water > 0,
		"original Water region develops authoritative Empty cells while liquid relocates")
	var tank_after: Dictionary = _snapshot(world, fixture.tank_interior)
	expect(int(tank_after.counts[WATER]) < int(initial_tank.counts[WATER]),
		"tank Water population decreases only by relocation into the released region")

	var q_closed: int = _quantity(world)
	for _tick: int in range(int(fixture.post_close_ticks)):
		expect(world.simulation_tick(), "post-close native tick succeeds")
	expect(_quantity(world) == q_closed and world.material_at(aperture.x, aperture.y) == WALL,
		"closed valve remains a hard boundary and post-close tail creates/destroys no Water")
	var motion_after: Dictionary = _released_motion(world)
	expect(int(motion_at_close.get("water_cells", 0)) > 0 and int(motion_after.water_cells) > 0,
		"already released liquid remains below the closed aperture for tail observation")
	return {
		"workers": workers,
		"initial_quantity": initial_quantity,
		"final_quantity": _quantity(world),
		"close_tick": close_tick,
		"occupied_closure_refusal_observed": occupied_refusal,
		"maximum_released_cells": maximum_outside,
		"maximum_empty_cells_in_original_water_region": maximum_empty_in_original_water,
		"motion_at_close": motion_at_close,
		"motion_after_tail": motion_after,
		"final_hash": world.get_physical_state_hash(),
		"cavity_claim": "Empty material-state relocation only; no gas-pressure claim",
		"tail_claim": "IN velocity readback below a closed aperture; lateral component recorded if present",
	}


func run() -> void:
	fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	var definition: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"))
	var checked: Dictionary = Contract.validate(definition)
	if not expect(bool(checked.get("ok", false)), "registered transport fixture validates"):
		_finish([])
		return
	transport = checked.transport.packed
	var reports: Array = []
	for workers: int in fixture.workers:
		reports.append(_execute(workers))
	if reports.size() == 2:
		expect(reports[0].close_tick == reports[1].close_tick,
			"1/4-worker leak closure tick is deterministic")
		expect(reports[0].final_hash == reports[1].final_hash,
			"1/4-worker complete post-close physical continuation is exact")
	_finish(reports)


func _finish(reports: Array) -> void:
	print("IN_TOOLS_361_LEAK_FLOW_PACKET: " + JSON.stringify({
		"schema": "in-tools-361-leak-flow-result-v1",
		"assertions": assertions,
		"failures": failures,
		"reports": reports,
	}))
	print("IN_TOOLS_361_LEAK_FLOW: %d assertions; %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
