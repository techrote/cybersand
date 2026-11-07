extends SceneTree

# #201 region-flip regression. A fixed-interest MicroScenario owns the native
# simulation window; the worker must not first write the camera window and then
# let apply_interest() write the scenario region, because every selected-core
# change used to discard the derived pressure cache. The recording fake proves
# the exact call sequence; the actual native cached PressureFlow pool proves the
# consequence. Since #201's native narrowing (2026-11-05) a selected-core change
# no longer discards the cache, so the previous ordering is retained as a
# control that region flips alone cause no index rebuild.
const Worker = preload("res://scripts/simulation_worker.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const POOL: String = "res://tests/fixtures/lcb/scenarios/lcb.rest.deep-quiet-pool.v1.json"
var assertions: int = 0
var failures: int = 0


class RecordingWorld:
	extends RefCounted
	var calls: Array = []
	var simulation_window_enabled: bool = true:
		set(value):
			calls.append(["simulation_window_enabled", value])
			simulation_window_enabled = value
	var cadence_lod_enabled: bool = true:
		set(value):
			calls.append(["cadence_lod_enabled", value])
			cadence_lod_enabled = value

	func set_liquid_surface_adhesion_enabled(value: bool) -> void:
		calls.append(["set_liquid_surface_adhesion_enabled", value])

	func set_interest_center(value: Vector2i) -> void:
		calls.append(["set_interest_center", value])

	func set_simulation_window(origin: Vector2i, size: Vector2i, horizontal: int, vertical: int) -> void:
		calls.append(["set_simulation_window", origin, size, horizontal, vertical])


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("SIMULATION_WORKER_INTEREST_OWNERSHIP: " + message)


func _initialize() -> void:
	_recording_sequence()
	_native_pressure_cache()
	print("SIMULATION_WORKER_INTEREST_OWNERSHIP: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)


func _recording_sequence() -> void:
	var camera := [Vector2i(10, 20), Vector2i(640, 360), 64, 32]
	var free := RecordingWorld.new()
	Worker.apply_world_execution_settings(free, false, false, true, false, Vector2i(5, 6),
		camera[0], camera[1], camera[2], camera[3])
	expect(free.calls == [["simulation_window_enabled", false], ["cadence_lod_enabled", true],
		["set_liquid_surface_adhesion_enabled", false], ["set_interest_center", Vector2i(5, 6)],
		["set_simulation_window", camera[0], camera[1], camera[2], camera[3]]],
		"ordinary interest keeps the complete previous camera/window sequence")
	var owned := RecordingWorld.new()
	Worker.apply_world_execution_settings(owned, true, false, true, false, Vector2i(5, 6),
		camera[0], camera[1], camera[2], camera[3])
	expect(owned.calls == [["cadence_lod_enabled", true], ["set_liquid_surface_adhesion_enabled", false],
		["set_interest_center", Vector2i(5, 6)]],
		"a fixed-interest scenario receives no transient window flag or camera region")


func _cached_request(bridge: Variant) -> PackedInt32Array:
	var request: PackedInt32Array = bridge.default_liquid_policy()
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(request, 3):
		if str(choice.get("family", "")) == "pressure_flow_v1" and str(choice.get("variant", "")) == "cached":
			return choice.request
	return PackedInt32Array()


# Applies the worker's per-step sequence (owned or previous ordering), then one
# scenario tick, and returns the index rebuilds added over `ticks`.
func _rebuilds(world: Variant, host: Variant, owned: bool, ticks: int) -> int:
	var before: int = int(world.inspect_pressure_optimization().counters.index_rebuilds)
	for _tick: int in range(ticks):
		Worker.apply_world_execution_settings(world, owned, true, false, true, Vector2i(512, 128),
			Vector2i(0, 0), Vector2i(640, 360), 64, 64)
		host.apply_interest()
		expect(host.advance(), "scenario tick completes: " + str(host.last_error))
	return int(world.inspect_pressure_optimization().counters.index_rebuilds) - before


func _native_pressure_cache() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		expect(false, "current native extension unavailable")
		return
	var checked: Dictionary = Contract.parse(FileAccess.get_file_as_string(POOL))
	expect(checked.get("ok", false) and checked.definition.interest.policy == "fixed",
		"registered fixed-interest quiet pool parses")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var request: PackedInt32Array = _cached_request(bridge)
	expect(not request.is_empty(), "native catalogue offers cached PressureFlow Water")
	if failures > 0: return
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers": 1}), "native worker configuration accepted")
	var host: CyberMicroScenarioHost = Host.new()
	var installed: bool = host.install(world, checked.definition, "Benchmark", false, request,
		{"intent": "controlled", "normalization": "water-normalize-v1", "maximum_rule_radius": 2})
	expect(installed, "controlled cached PressureFlow quiet pool installs: " + host.last_error)
	if not installed: return
	expect(host.fixed_interest(), "installed scenario owns a fixed interest")
	# Settle: the pool's Water sleeps and the cache reaches its gas fixed point.
	var settle: int = _rebuilds(world, host, true, 12)
	expect(settle >= 0, "settle completed")
	var owned: int = _rebuilds(world, host, true, 16)
	expect(owned == 0, "owned interest keeps the derived pressure index across quiet ticks (rebuilds=%d)" % owned)
	# Control: the previous camera-then-scenario ordering flips the selected
	# cores every tick. Before #201's native narrowing it rebuilt the index on
	# every tick (16/16); World::set_simulation_region no longer discards the
	# derived cache, so the flips alone must rebuild nothing. The counter's
	# liveness is proved below by the initial build (index_rebuilds > 0).
	var flipped: int = _rebuilds(world, host, false, 16)
	expect(flipped == 0, "previous ordering's region flips keep the derived pressure index (rebuilds=%d)" % flipped)
	print("SIMULATION_WORKER_INTEREST_OWNERSHIP_REBUILDS: " + JSON.stringify({"owned_16_ticks": owned, "previous_ordering_16_ticks": flipped}))
	var region: Array = checked.definition.interest.region
	expect(owned == 0 and int(world.inspect_pressure_optimization().counters.index_rebuilds) > 0,
		"pressure inspection reports a real cached World")
	expect(region.size() == 4, "scenario region retained")
	expect(not world.has_failed(), "World remains outside failure quarantine")
