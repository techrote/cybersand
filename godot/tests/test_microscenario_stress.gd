extends SceneTree

const Pack = preload("res://scripts/microscenario_reference_pack.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func run_definition(definition: Dictionary, workers: int, mode: String, instrumentation: bool) -> Dictionary:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not world.diagnostic_reset({"workers":workers}): return {"error":"worker reset rejected"}
	var host: CyberMicroScenarioHost = Host.new()
	if not host.install(world,definition,mode,instrumentation): return {"error":host.last_error}
	for _tick: int in range(int(definition.presentation.duration_ticks)):
		if not host.advance(): return {"error":host.last_error}
	return host.capture()

func semantic(report: Dictionary) -> Dictionary:
	return {"tick":report.completed_tick,"content_hash":report.native.content_hash,
		"water_integer":report.native.water_integer,"water_cells":report.native.water_cells,"outcome":report.outcome}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var seen_hashes: Dictionary = {}
	for profile: String in Pack.STRESS_PROFILES:
		var definition: Dictionary = Pack.simulation_stress(profile,0)
		var checked: Dictionary = Contract.validate(definition)
		expect(checked.ok,"Invalid Stress profile: " + profile)
		expect(int(definition.presentation.duration_ticks) == 180,"Stress duration drift: " + profile)
		expect(definition.events.size() <= Contract.MAX_EVENTS and definition.observations.size() <= Contract.MAX_OBSERVATIONS,
			"Stress profile exceeded unchanged capacity: " + profile)
		var instrumented: Dictionary = run_definition(definition,1,"Benchmark",true)
		expect(str(instrumented.get("error","")) == "","Stress profile failed: " + profile)
		expect(instrumented.outcome == "complete" and instrumented.budget_outcome == "admitted",
			"Stress profile did not complete within budget: " + profile)
		expect(int(instrumented.work_statistics.sampled_ticks) == 180,"Stress work telemetry missed ticks: " + profile)
		expect(int(instrumented.work_statistics.totals.visited_cells) > 0,"Stress profile recorded no native work: " + profile)
		expect(instrumented.work_statistics.host_boundary_timing.count == 180 and instrumented.timing.count == 180,
			"Stress timing domains are incomplete: " + profile)
		expect(instrumented.work_statistics.latest.unavailable.has("per-worker utilization"),
			"Stress telemetry fabricated an unavailable utilization counter: " + profile)
		seen_hashes[profile] = str(instrumented.native.content_hash)

		var observer_off: Dictionary = run_definition(definition,4,"Play",false)
		expect(str(observer_off.get("error","")) == "","Observer-off Stress profile failed: " + profile)
		expect(semantic(observer_off) == semantic(instrumented),"Stress worker/observer parity failed: " + profile)
		expect(observer_off.observations.is_empty() and not observer_off.work_statistics.available and observer_off.timing.count == 0,
			"Observer-off Stress run retained optional telemetry: " + profile)

	expect(seen_hashes.size() == Pack.STRESS_PROFILES.size(),"Stress profile results missing")
	expect(seen_hashes.values().duplicate().size() == Pack.STRESS_PROFILES.size(),"Named Stress profiles collapsed to duplicate final worlds")
	print("MICROSCENARIO_STRESS: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
