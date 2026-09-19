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

func world_for(workers: int) -> Variant:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":workers}),"Requested native worker count rejected")
	return world

func observation(world: Variant) -> Dictionary:
	return world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024))

func semantic(value: Dictionary) -> Dictionary:
	# Worker count is intentionally in state_hash. Only that metadata is excluded;
	# compare authoritative content plus exact Water quantity and completed tick.
	return {"tick":value.tick,"content_hash":value.content_hash,"water_integer":value.water_integer,"water_cells":value.water_cells}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var definition: Dictionary = Pack.interaction_fixture("salt-water",2,32)
	var checked: Dictionary = Contract.validate(definition)
	expect(checked.ok,"Generated interaction definition invalid")
	var parsed: Dictionary = Contract.parse(checked.canonical_json)
	expect(parsed.ok and parsed.hash == checked.hash,"Headless/GUI input is not the same complete JSON")
	var expected_semantic: Dictionary = {}
	var expected_results: Array = []
	for workers: int in [1,4]:
		var exact: Dictionary = {}
		for mode: String in Contract.MODES:
			for observers: bool in [true,false]:
				var world: Variant = world_for(workers)
				var host: CyberMicroScenarioHost = Host.new()
				if not host.install(world,parsed.definition,mode,observers):
					expect(false,host.last_error)
					continue
				var initial: Dictionary = observation(world)
				var successful: bool = true
				for tick: int in range(120):
					if not host.advance():
						successful = false
						break
				expect(successful,host.last_error)
				var actual: Dictionary = observation(world)
				if exact.is_empty(): exact = actual
				if expected_semantic.is_empty(): expected_semantic = semantic(actual)
				expect(actual == exact,"Same-worker mode/observer behavior diverged")
				expect(semantic(actual) == expected_semantic,"Worker-count content/quantity parity failed")
				var report: Dictionary = host.capture(CyberMicroScenarioIdentity.current())
				expect(report.completed_tick == 120 and report.outcome == "complete" and not report.failed,"Existing Salt/Water interaction did not complete")
				expect(report.definition_hash == checked.hash and report.definition == parsed.definition,"Capture lost complete definition identity")
				expect(report.material_ids.has(23) and report.material_ids.has(24) and report.material_ids.has(3),"Material/product identity missing")
				expect(not report.replay_complete and not report.runtime_identity.native_sha256 == "unavailable","Capture provenance or persistence scope wrong")
				if observers:
					if expected_results.is_empty(): expected_results = report.observations
					expect(report.observations == expected_results,"Declared observations changed across modes/workers")
					expect(report.work_statistics.sampled_ticks == 120,"Native work telemetry missed successful ticks")
					expect(report.work_statistics.host_boundary_timing.count == 120 and report.timing.count == 120,"Host/native timing domains not separately measured")
					expect(report.water_ledger.explicit_source == 0 and report.water_ledger.explicit_sink == 0,"Shelf erase fabricated a Water source or sink")
					expect(report.water_ledger.initial_integer == initial.water_integer,"Initial exact Water accounting wrong")
				else:
					expect(report.observations.is_empty() and not report.work_statistics.available and report.timing.count == 0,"Observers-off retained optional work")
				expect(host.install(world,parsed.definition,mode,observers),"Fresh reset rejected complete generated input")
				expect(observation(world) == initial and host.summary().events_applied == 0,"Fresh reset did not reproduce complete initial state")
	for id: String in Pack.MATERIAL_IDS:
		var source: Dictionary = Pack.definition(id,2)
		var world: Variant = world_for(1)
		var host: CyberMicroScenarioHost = Host.new()
		if not host.install(world,source):
			expect(false,host.last_error)
			continue
		for tick: int in range(source.presentation.duration_ticks):
			if not host.advance():
				expect(false,host.last_error)
				break
		var report: Dictionary = host.capture()
		expect(report.outcome == "complete" and not report.failed,"Materials Laboratory preset failed: " + id)
		expect(report.observations.size() == source.observations.size(),"Declared results were omitted: " + id)
		var retained: Dictionary = report.duplicate(true)
		var before: Dictionary = observation(world)
		var invalid: Dictionary = source.duplicate(true)
		# Older Lab presets all carried a scheduled shelf release; INT-000 mechanism
		# fixtures may legitimately have no events. Corrupt whichever bounded setup
		# surface is present so every preset still proves transactional rejection.
		if not invalid.events.is_empty():
			invalid.events[0].width = 1025
		else:
			invalid.rectangles[0] = -1
		expect(not Contract.validate(invalid).get("ok",false),
			"Materials Lab rejection probe did not construct an invalid definition: " + id)
		expect(not host.install(world,invalid),"Invalid generated replacement accepted")
		expect(observation(world) == before,"Rejected replacement changed authority")
		expect(host.install(world,source),"Valid recovery reset rejected")
		expect(retained.completed_tick == int(source.presentation.duration_ticks),"Fresh reset mutated retained observations")
		if id == "materials/contact-lab":
			var values: Dictionary = {}
			for item: Dictionary in retained.observations: values[item.id] = item.value
			expect(values["sand-retained"] == 384,"Non-reacting granular control lost cells")
			expect(values["salt-final"] == 0 and values["brine-final"] == 768,"Declared Salt/Brine species quantities changed")
			expect(values["stone-120"] == 384 and values["steam-120"] == 384,"Quench did not expose current products")
	print("MICROSCENARIO_MATERIALS_LAB: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
