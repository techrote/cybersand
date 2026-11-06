extends SceneTree

# IN-TOOLS #361 successor: exact native source/aperture semantics, controller
# accounting and configured 1/4-worker continuation. This deliberately proves
# ordinary IN whole-cell transport; no ballistic-water API is invoked.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Controller = preload("res://scripts/in_tools_liquid_controller.gd")
const WATER: int = 3
const WALL: int = 1
const EMPTY: int = 0
var checks: int = 0
var failures: int = 0
var bridge: Object
var transport: PackedInt32Array
var semantics := PackedInt32Array([1, 8, 12, 0])


func _initialize() -> void:
	run.call_deferred()


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("IN_TOOLS_361_ADAPTER: " + message)


func _policy() -> PackedInt32Array:
	var policy: PackedInt32Array = bridge.default_liquid_policy()
	# Water is the first assignment in the frozen policy wire layout.
	policy[21] = 4 # inertial_cellular_v1
	policy[22] = 0 # reference
	return policy


func _rectangles() -> PackedInt32Array:
	# 64x64 closed room plus two independent authored aperture wall cells.
	return PackedInt32Array([
		0, 0, 64, 1, WALL,
		0, 63, 64, 1, WALL,
		0, 0, 1, 64, WALL,
		63, 0, 1, 64, WALL,
		20, 20, 2, 1, WALL,
	])


func _build(workers: int) -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world != null and world.diagnostic_reset({"workers": workers}),
		"fresh configured native world admits workers=" + str(workers))
	var rectangles: PackedInt32Array = _rectangles()
	var request: PackedInt32Array = _policy()
	var claim: String = JSON.stringify({
		"version": 1, "workers": workers, "rectangles": rectangles,
		"semantics": semantics, "policy": request
	}).sha256_text()
	var token: int = bridge.prepare_liquid_world(
		world, rectangles, transport, semantics, PackedInt32Array(), request,
		{"definition_hash": claim, "region": PackedInt32Array([0, 0, 64, 64]),
		 "simulation_window_enabled": false, "intent": "exploratory",
		 "maximum_rule_radius": 3, "cadence_lod_enabled": false,
		 "liquid_surface_adhesion_enabled": false})
	var installed: bool = token > 0 and bridge.commit_liquid_world(world, token)
	expect(installed, "actual Water-IN world installs: " + str(bridge.get_last_error()))
	if installed:
		var applied: Dictionary = world.get_liquid_solver_policy()
		var found: bool = false
		for row: Dictionary in applied.assignments:
			if int(row.material) == WATER:
				found = row.applied_family == "inertial_cellular_v1" and row.applied_variant == "reference"
		expect(found and int(applied.maximum_rule_radius) == 3,
			"Water runs ordinary inertial_cellular_v1/reference with explicit radius3")
	return world


func _quantity(world: Object) -> int:
	return int(world.water_experiment_observation(Vector2i.ZERO, Vector2i(64, 64)).water_integer)


func _request(controller: Object, world: Object, profile: String, material: int) -> Dictionary:
	var readback: Dictionary = controller.refresh(world)
	return {
		"request_id": profile + "-fixture",
		"profile": profile,
		"material": material,
		"world_instance_id": readback.world_instance_id,
		"native_generation": readback.native_generation,
		"policy_hash": readback.policy_hash,
		"quantity_budget": int(readback.get("water_units_remaining", 0)) if profile == Controller.PROFILE_NOZZLE else 0,
	}


func _direct_native() -> void:
	var world: Object = _build(1)
	var maximum: int = int(world.get_water_experiment_policy().maximum)
	var before: int = _quantity(world)
	var source: Dictionary = world.in_tools_inject_water_source(Vector2i(16, 16), Vector2i(12, 0))
	expect(source.accepted and source.changed and source.transport_mode == "inertial_cellular_source_v1"
		and not bool(source.ballistic_transport) and int(source.quantity_added) == maximum,
		"native source inserts exactly one ordinary IN whole Water cell with explicit non-ballistic identity")
	expect(world.material_at(16, 16) == WATER and world.inspect_inertial_cell(Vector2i(16, 16)).vx == 12
		and _quantity(world) == before + maximum,
		"native source quantity and signed IN velocity are authoritative readback")
	var unchanged: int = _quantity(world)
	var duplicate: Dictionary = world.in_tools_inject_water_source(Vector2i(16, 16), Vector2i(8, 0))
	expect(not duplicate.accepted and duplicate.reason == "destination_occupied"
		and int(duplicate.quantity_added) == 0 and _quantity(world) == unchanged,
		"occupied destination refuses without hidden replacement or quantity change")
	var zero: Dictionary = world.in_tools_inject_water_source(Vector2i(17, 16), Vector2i.ZERO)
	expect(not zero.accepted and zero.reason == "velocity_range" and _quantity(world) == unchanged,
		"zero-direction source refuses before quantity admission")

	var opened: Dictionary = world.in_tools_set_aperture(Vector2i(20, 20), true)
	expect(opened.accepted and opened.changed and world.material_at(20, 20) == EMPTY
		and int(opened.quantity_delta) == 0, "authored Wall opens as a zero-quantity aperture mutation")
	var closed: Dictionary = world.in_tools_set_aperture(Vector2i(20, 20), false)
	expect(closed.accepted and closed.changed and world.material_at(20, 20) == WALL
		and _quantity(world) == unchanged, "empty aperture closes reversibly without changing Water quantity")
	expect(world.in_tools_set_aperture(Vector2i(20, 20), true).accepted, "aperture reopens")
	var filled: Dictionary = world.in_tools_inject_water_source(Vector2i(20, 20), Vector2i(8, 0))
	var occupied_quantity: int = _quantity(world)
	var refused_close: Dictionary = world.in_tools_set_aperture(Vector2i(20, 20), false)
	expect(filled.accepted and not refused_close.accepted and refused_close.reason == "occupied_aperture"
		and world.material_at(20, 20) == WATER and _quantity(world) == occupied_quantity,
		"occupied closure fails closed and preserves the admitted Water cell exactly")

	var current: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(current.diagnostic_reset({"workers": 1}), "Current control world constructs")
	var non_in: Dictionary = current.in_tools_inject_water_source(Vector2i(12, 12), Vector2i(8, 0))
	expect(not non_in.accepted and non_in.reason == "water_not_inertial"
		and not bool(non_in.ballistic_transport),
		"default Water cannot silently route through ballistic transport or another source family")


func _controller_accounting() -> void:
	var world: Object = _build(1)
	var controller = Controller.new()
	var initial: Dictionary = controller.refresh(world)
	var maximum: int = int(initial.maximum)
	var req: Dictionary = _request(controller, world, Controller.PROFILE_NOZZLE, WATER)
	var pose: Dictionary = {"muzzle": Vector2(30, 30)}
	var result: Dictionary = controller.apply_nozzle(world, pose, req, Vector2.RIGHT, 1.0, 7)
	var after: Dictionary = controller.observation(0)
	expect(result.status == "applied" and result.kind == "directed_in_nozzle"
		and result.transport_mode == "inertial_cellular_source_v1" and not bool(result.ballistic_transport),
		"controller labels the #361 nozzle as IN transport, never ballistic")
	expect(int(result.source_credit) == maximum and int(result.sink_debit) == 0
		and int(result.water_units_added) == maximum
		and int(after.water_units_remaining) + int(after.water_units_admitted) == int(after.water_units_initial)
		and int(after.water_units_admitted) == maximum,
		"source ledger closes exactly after an accepted nozzle pulse")
	var stale: Dictionary = req.duplicate(true)
	stale.quantity_budget = int(req.quantity_budget) - 1
	var q_before: int = _quantity(world)
	var refused: Dictionary = controller.apply_nozzle(world, {"muzzle": Vector2(34, 30)}, stale, Vector2.RIGHT, 1.0, 8)
	expect(refused.status == "refused" and refused.reason == "quantity_budget" and _quantity(world) == q_before,
		"stale copied source budget refuses without quantity mutation")

	var leak_request: Dictionary = _request(controller, world, Controller.PROFILE_LEAK, 0)
	var leak: Dictionary = controller.apply_leak(world, 0, leak_request, Vector2i(21, 20), true, 9)
	expect(leak.status == "applied" and bool(controller.observation(0).aperture_open)
		and int(leak.source_credit) == 0 and int(leak.sink_debit) == 0 and int(leak.quantity_delta) == 0,
		"controller owns a reversible zero-quantity leak aperture")
	var close_request: Dictionary = _request(controller, world, Controller.PROFILE_LEAK, 0)
	var close: Dictionary = controller.apply_leak(world, 0, close_request, Vector2i.ZERO, false, 10)
	expect(close.status == "applied" and not bool(controller.observation(0).aperture_open)
		and world.material_at(21, 20) == WALL, "alternate closes the same owned aperture")


func _worker_parity() -> void:
	var worlds: Array = [_build(1), _build(4)]
	for world: Object in worlds:
		expect(world.in_tools_set_aperture(Vector2i(20, 20), true).accepted, "parity aperture opens")
		expect(world.in_tools_inject_water_source(Vector2i(16, 16), Vector2i(12, 0)).accepted,
			"parity horizontal source admits")
		expect(world.in_tools_inject_water_source(Vector2i(31, 31), Vector2i(0, 12)).accepted,
			"parity chunk-boundary source admits")
	expect(worlds[0].get_physical_state_hash() == worlds[1].get_physical_state_hash(),
		"1/4-worker initial source/aperture state is exact")
	var parallel_seen: bool = false
	for _tick: int in range(20):
		for world: Object in worlds:
			expect(world.simulation_tick(), "parity native tick succeeds")
		parallel_seen = parallel_seen or worlds[1].get_scheduler_parallel_phases_last_tick() > 0
		expect(worlds[0].get_physical_state_hash() == worlds[1].get_physical_state_hash(),
			"complete 1/4-worker continuation remains exact")
	expect(parallel_seen, "configured four-worker world performs real parallel dispatch")


func run() -> void:
	if not ClassDB.class_exists(&"CyberDemoBridge") or not ClassDB.class_exists(&"CyberNativeCellWorld"):
		expect(false, "source-matched native extension is required")
		_finish()
		return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	var definition: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"))
	var checked: Dictionary = Contract.validate(definition)
	if not expect(bool(checked.get("ok", false)), "registered Current transport fixture validates"):
		_finish()
		return
	transport = checked.transport.packed
	_direct_native()
	_controller_accounting()
	_worker_parity()
	_finish()


func _finish() -> void:
	print("IN_TOOLS_361_ADAPTER: %d assertions; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
