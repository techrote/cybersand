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

func run_definition(definition: Dictionary, workers: int = 1, mode: String = "Benchmark", instrumentation: bool = true) -> Dictionary:
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

func observed(report: Dictionary, id: String) -> Variant:
	for item: Dictionary in report.get("observations",[]):
		if item.id == id: return item.value
	return null

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var base: Dictionary = Pack.flood_control(0)
	var checked: Dictionary = Contract.validate(base)
	expect(checked.ok,"Flood-Control definition invalid")
	expect(base.conditions.size() == 2 and base.conditions[0].observation == "protected-water",
		"Flood objective is not the declared protected-zone world state")
	var untreated: Dictionary = run_definition(base,1,"Play",true)
	expect(str(untreated.get("error","")) == "","Untreated Flood run failed")
	expect(untreated.outcome == "fail","Untreated Flood control did not fail")
	var untreated_water: int = int(observed(untreated,"protected-water"))
	expect(untreated_water > 0,"Untreated Flood control never wetted the protected zone")
	expect(int(untreated.events_applied) == 1,"Flood release event did not execute exactly once")
	expect(untreated.definition_budget.events <= Contract.MAX_EVENTS and untreated.definition_budget.observations <= Contract.MAX_OBSERVATIONS,
		"Flood definition exceeded unchanged capacity budgets")

	var witness_hashes: Dictionary = {}
	for approach: String in ["containment","berm","diversion"]:
		var definition: Dictionary = Pack.flood_control_witness(approach,0)
		expect(Contract.validate(definition).ok,"Invalid Flood witness: " + approach)
		expect(definition.conditions == base.conditions,"Flood witness changed the objective: " + approach)
		var report: Dictionary = run_definition(definition,1,"Play",true)
		expect(str(report.get("error","")) == "","Flood witness failed to execute: " + approach)
		expect(report.outcome == "complete" and int(observed(report,"protected-water")) == 0,
			"Flood witness did not keep protected zone dry: " + approach)
		witness_hashes[approach] = str(report.native.content_hash)
	expect(witness_hashes.values().duplicate().size() == 3 and witness_hashes.containment != witness_hashes.berm
		and witness_hashes.containment != witness_hashes.diversion and witness_hashes.berm != witness_hashes.diversion,
		"Physically distinct Flood witnesses collapsed to one final world")

	var expected: Dictionary = {}
	for mode: String in Contract.MODES:
		var report: Dictionary = run_definition(base,1,mode,true)
		var state: Dictionary = semantic(report)
		if expected.is_empty(): expected = state
		expect(state == expected,"Flood Play/Inspect/Benchmark physics diverged: " + mode)
	var observer_off: Dictionary = run_definition(base,4,"Benchmark",false)
	expect(semantic(observer_off) == expected,"Flood worker/observer parity failed")
	expect(observer_off.observations.is_empty() and not observer_off.work_statistics.available,
		"Flood observers-off run retained optional instrumentation")

	print("MICROSCENARIO_FLOOD_CONTROL: %d assertions; %d failures; untreated protected water=%d" % [assertions,failures,untreated_water])
	quit(1 if failures else 0)
