extends SceneTree

# LCB negative contracts executable on current source (PR #215 NC matrix plus
# harness visibility). Each refused or faulted setup must surface as such and
# must never yield a "completed" physics result. Solver-family refusals
# (NC-1/2/3/10) need the #200 policy API and stay registered as blocked.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const BASE_PATH: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var source: Dictionary = Runner.read_text(BASE_PATH)
	expect(source.ok, "Protected base definition unavailable")
	if not source.ok:
		quit(1)
		return
	var base: Dictionary = JSON.parse_string(source.text)
	expect(Contract.validate(base).get("ok", false), "Unmodified base must validate")
	_refuses("malformed JSON", "{\"schema_version\": 2,")
	_refuses("definition over byte budget", JSON.stringify(base) + " ".repeat(Contract.MAX_JSON_BYTES + 1))
	for case: Array in _mutations(base):
		_refuses(case[0], JSON.stringify(case[1]))
	_runner_refuses_player(base)
	_capacity_fault(base)
	_skipped_tick_fault(base)
	_fail_condition(base)
	_ledger_closure(base)
	print("LCB negative contracts: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)

func _refuses(label: String, text: String) -> void:
	var checked: Dictionary = Contract.parse(text)
	expect(not checked.get("ok", false), label + ": contract admitted an invalid definition")
	var result: Dictionary = Runner.run_text(text, 1, 5)
	expect(result.status == "refused" and not result.has("capture"),
		label + ": refused setup produced a run result (" + str(result.status) + ")")
	expect(not str(result.get("error", "")).is_empty(), label + ": refusal has no visible reason")

func _mutations(base: Dictionary) -> Array:
	var out: Array = []
	var unknown: Dictionary = base.duplicate(true)
	unknown["solver_family"] = "pressure_flow_v1"
	out.append(["unknown root field (no silent family request)", unknown])
	var missing: Dictionary = base.duplicate(true)
	missing.erase("events")
	out.append(["missing root field", missing])
	var reserved: Dictionary = base.duplicate(true)
	reserved.rectangles = reserved.rectangles + [100, 100, 4, 4, 10]
	out.append(["reserved material 10", reserved])
	var beyond: Dictionary = base.duplicate(true)
	beyond.rectangles = beyond.rectangles + [100, 100, 4, 4, Contract.MATERIAL_COUNT]
	out.append(["material outside catalogue", beyond])
	var oil_fill: Dictionary = base.duplicate(true)
	oil_fill.events = [{"tick":0, "kind":"fill", "x":100, "y":100, "width":4, "height":4,
		"material":16, "normalized_mass":255, "coherence":0}]
	out.append(["fractional fill of a non-Water liquid", oil_fill])
	var zero_fill: Dictionary = base.duplicate(true)
	zero_fill.events = [{"tick":0, "kind":"fill", "x":100, "y":100, "width":4, "height":4,
		"material":3, "normalized_mass":0, "coherence":0}]
	out.append(["zero-mass scheduled fill", zero_fill])
	var erase_payload: Dictionary = base.duplicate(true)
	erase_payload.events = [{"tick":0, "kind":"erase", "x":100, "y":100, "width":4, "height":4,
		"material":3, "normalized_mass":0, "coherence":0}]
	out.append(["erase carrying a material payload", erase_payload])
	var bits: Dictionary = base.duplicate(true)
	bits.water_semantics = [1, 9, 12, 0]
	out.append(["Water mass bits above 8", bits])
	var coherence: Dictionary = base.duplicate(true)
	coherence.water_semantics = [1, 8, 13, 0]
	out.append(["Water coherence above 12", coherence])
	var fill_state: Dictionary = base.duplicate(true)
	fill_state.partial_water_fills = [40, 96, 192, 160, 256, 0]
	out.append(["fill mass outside 0..255", fill_state])
	var area: Dictionary = base.duplicate(true)
	area.observations = []
	for index: int in range(2):
		area.observations.append({"id":"all-%d" % index, "tick":index, "metric":"water_integer",
			"region":[0, 0, 1024, 1024], "material":3})
	out.append(["observation area budget", area])
	var too_many: Dictionary = base.duplicate(true)
	too_many.events = []
	for index: int in range(Contract.MAX_EVENTS + 1):
		too_many.events.append({"tick":index, "kind":"sample", "x":0, "y":0, "width":1, "height":1,
			"material":0, "normalized_mass":0, "coherence":0})
	out.append(["event capacity", too_many])
	var order: Dictionary = base.duplicate(true)
	order.events = [base.events[0].duplicate(), base.events[0].duplicate()]
	order.events[0].tick = 5
	order.events[1].tick = 1
	out.append(["events out of tick order", order])
	var horizon: Dictionary = base.duplicate(true)
	horizon.events = [base.events[0].duplicate()]
	horizon.events[0].tick = Contract.MAX_TICK
	out.append(["event beyond horizon", horizon])
	var masked: Dictionary = base.duplicate(true)
	masked.body_enabled = true
	masked.observations = [{"id":"cells", "tick":0, "metric":"material_cells", "region":[0, 0, 8, 8], "material":3}]
	masked.conditions = []
	out.append(["material counts under body masks", masked])
	var region: Dictionary = base.duplicate(true)
	region.rectangles = region.rectangles + [1020, 1020, 8, 8, 1]
	out.append(["rectangle outside the frame", region])
	var transport: Dictionary = base.duplicate(true)
	transport.transport_profile = {"version":99}
	out.append(["unsupported transport profile", transport])
	return out

# The contract admits player-enabled setups; the native-only controlled runner
# must refuse them instead of running without the live owner.
func _runner_refuses_player(base: Dictionary) -> void:
	var player: Dictionary = base.duplicate(true)
	player.player_enabled = true
	expect(Contract.validate(player).get("ok", false), "Player-enabled base should be contract-valid")
	var result: Dictionary = Runner.run_text(JSON.stringify(player), 1, 5)
	expect(result.status == "refused" and not result.has("capture"),
		"Native-only runner ran a player-enabled definition without its live owner")

# Capacity refusal: a World constructed with one active core quarantines the
# first multi-core tick. The host must report a fault, not a completed run.
func _capacity_fault(base: Dictionary) -> void:
	var checked: Dictionary = Contract.validate(base)
	var previous: Variant = ProjectSettings.get_setting("cybersand/native_active_core_capacity", null)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", 1)
	var limited: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", previous)
	limited.set_simulation_window_enabled(false)
	var host: CyberMicroScenarioHost = Host.new()
	expect(host.install(limited, checked.definition, "Benchmark", true), "Capacity fixture install failed")
	var advanced: bool = true
	for tick: int in range(4): advanced = advanced and host.advance()
	var capture: Dictionary = host.capture(CyberMicroScenarioIdentity.current("unavailable"))
	expect(not advanced and limited.has_failed(), "Active-core capacity exhaustion was not quarantined")
	expect(bool(capture.get("failed", false)) and str(capture.get("outcome", "")) != "complete",
		"Capacity fault reported as a completed physics result")

# Harness visibility: an owner that ticks outside the host boundary is a fault.
func _skipped_tick_fault(base: Dictionary) -> void:
	var checked: Dictionary = Contract.validate(base)
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1}), "Native reset failed")
	world.set_simulation_window_enabled(false)
	var host: CyberMicroScenarioHost = Host.new()
	expect(host.install(world, checked.definition, "Benchmark", true), "Host install failed")
	expect(host.advance(), "First controlled tick failed")
	expect(world.simulation_tick() and world.simulation_tick(), "Out-of-band native ticks failed")
	expect(not host.after_tick(), "Host accepted a skipped completed-tick boundary")
	var capture: Dictionary = host.capture(CyberMicroScenarioIdentity.current("unavailable"))
	expect(bool(capture.get("failed", false)) and str(capture.get("outcome", "")) != "complete",
		"Skipped tick boundary reported as a completed result")

# A preregistered fail condition must surface as failed_condition.
func _fail_condition(base: Dictionary) -> void:
	var failing: Dictionary = base.duplicate(true)
	failing.observations = [{"id":"total-t0", "tick":0, "metric":"water_integer",
		"region":[40, 32, 944, 224], "material":3}]
	failing.conditions = [{"observation":"total-t0", "comparison":"ge", "value":1, "outcome":"fail"}]
	var result: Dictionary = Runner.run_text(JSON.stringify(failing), 1, 2)
	expect(result.status == "failed_condition", "Fail condition not surfaced (" + str(result.status) + ")")

# Explicit source/sink accounting: scheduled fill and erase are ledgered exactly.
func _ledger_closure(base: Dictionary) -> void:
	var ledgered: Dictionary = base.duplicate(true)
	ledgered.events = [
		{"tick":0, "kind":"fill", "x":600, "y":100, "width":4, "height":4, "material":3, "normalized_mass":255, "coherence":0},
		{"tick":2, "kind":"erase", "x":40, "y":240, "width":4, "height":4, "material":0, "normalized_mass":0, "coherence":0}]
	ledgered.observations = []
	ledgered.conditions = []
	var result: Dictionary = Runner.run_text(JSON.stringify(ledgered), 1, 4)
	expect(result.status == "completed", "Ledger fixture did not complete")
	if result.status != "completed": return
	var ledger: Dictionary = result.capture.water_ledger
	expect(int(ledger.explicit_source) == 16 * 255 and int(ledger.explicit_sink) == 16 * 255,
		"Scheduled source/sink not ledgered exactly")
	expect(int(ledger.observed_current_integer) == int(ledger.initial_integer) + int(ledger.explicit_source)
		- int(ledger.explicit_sink), "Water ledger does not close")
