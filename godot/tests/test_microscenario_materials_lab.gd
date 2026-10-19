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

func quench_snapshot(world: Variant, bridge: Variant) -> Dictionary:
	# Decode an owned CYSD1 cell payload in the sealed quench bay. The ordinary
	# Water observer excludes Steam/Ice and cannot establish this closed ledger.
	var payload: PackedByteArray = bridge.export_level(world)
	expect(payload.size() == 1024 * 1024 * 5,"Quench snapshot has the wrong cell layout")
	if payload.size() != 1024 * 1024 * 5: return {}
	var value: Dictionary = {"water_integer":0, "steam_integer":0, "ice_integer":0,
		"stone_cells":0, "lava_cells":0, "steam_cells":0, "steam_quantities":{},
		"lava_progress_integer":0, "invalid_water":0}
	for y: int in range(68,244):
		for x: int in range(180,304):
			var index: int = (y * 1024 + x) * 5
			var material: int = payload[index]
			var a: int = payload[index + 1]
			var b: int = payload[index + 2]
			match material:
				3:
					value.water_integer += a
					if a == 0: value.invalid_water += 1
				8:
					value.lava_cells += 1
					value.lava_progress_integer += b
				9:
					value.ice_integer += 255 if b == 0 else b
				13:
					value.stone_cells += 1
				22:
					var quantity: int = 255 if b == 0 else b
					value.steam_cells += 1
					value.steam_integer += quantity
					value.steam_quantities[quantity] = int(value.steam_quantities.get(quantity,0)) + 1
	value.aqueous_integer = value.water_integer + value.steam_integer + value.ice_integer
	var observed: Dictionary = world.water_experiment_observation(Vector2i(180,68),Vector2i(124,176))
	expect(value.water_integer == int(observed.water_integer),"Owned quench snapshot disagrees with native Water quantity")
	value.content_hash = observed.content_hash
	return value

func check_quench_trace(source: Dictionary, samples: Dictionary) -> void:
	var id: String = str(source.id)
	var small: bool = id == "materials/lava-water-dose-small"
	var dose: int = 192 if small else 384
	expect(samples.has(0) and samples.has(120),"Quench quantity observation boundary was missed: " + id)
	if not samples.has(0) or not samples.has(120): return
	var initial: Dictionary = samples[0]
	expect(initial.water_integer == 1644240 and initial.steam_integer == 0 and initial.ice_integer == 0,
		"Quench reservoir/phase setup changed: " + id)
	expect(initial.lava_cells == dose and initial.stone_cells == 0,"Quench dose setup changed: " + id)
	for tick: int in samples:
		var sample: Dictionary = samples[tick]
		expect(sample.aqueous_integer == initial.aqueous_integer,
			"Closed Water/Steam/Ice quantity changed at tick %d: %s" % [tick,id])
		expect(sample.lava_cells + sample.stone_cells == dose,
			"Lava/Stone cell inventory changed at tick %d: %s" % [tick,id])
		expect(sample.invalid_water == 0,"Quench retained a zero-quantity Water cell: " + id)
	var current: Dictionary = samples[120]
	# Fixed seed-2 traces are registered against int.current-behaviour v2. Keep
	# exact counts AND quantities: treating every Steam parcel as full would add
	# 131 units to the full-dose case despite its correct 386-parcel count.
	var expected_histogram: Dictionary = {48:1,208:1,255:192} if small else {171:1,208:1,255:384}
	expect(current.stone_cells == dose and current.lava_cells == 0,"Quench did not complete the registered Stone dose: " + id)
	expect(current.steam_cells == dose + 2,"Quench Steam parcel count changed: " + id)
	expect(current.steam_quantities == expected_histogram,"Quench changed retained partial Steam quantities: " + id)
	expect(current.steam_integer == (49216 if small else 98299),"Quench Steam inventory changed: " + id)
	expect(current.water_integer == (1595024 if small else 1545941),"Quench remaining Water inventory changed: " + id)
	expect(current.ice_integer == 0 and current.lava_progress_integer == 0,"Quench retained an unexpected phase or unfinished budget: " + id)
	if not small:
		expect(samples[73].lava_progress_integer == 208 and samples[74].lava_progress_integer == 208,
			"Partial coolant progress was discarded before solidification: " + id)

func check_material_fixture(source: Dictionary, workers: int) -> Dictionary:
	var id: String = str(source.id)
	var quench: bool = id == "materials/contact-lab" or id.begins_with("materials/lava-water")
	var checked: Dictionary = Contract.validate(source)
	expect(checked.ok,"Generated Materials Laboratory definition invalid: " + id)
	if not checked.ok: return {}
	var parsed: Dictionary = Contract.parse(checked.canonical_json)
	expect(parsed.ok and parsed.hash == checked.hash,"Versioned Materials Laboratory definition lost JSON identity: " + id)
	expect(int(source.recipe_version) == (2 if quench else 1),"Affected/unaffected recipe version changed: " + id)
	if quench:
		expect(str(source.presentation.profile).ends_with("v2-phase-quantity")
			and str(source.presentation.baseline).contains("int.current-behaviour v2")
			and str(source.source_recipe).begins_with("MAT-002 reference-pack/v2/"),
			"Quench recipe did not identify the changed phase/contact baseline: " + id)
	var world: Variant = world_for(workers)
	var host: CyberMicroScenarioHost = Host.new()
	if not host.install(world,source):
		expect(false,host.last_error)
		return {}
	var samples: Dictionary = {}
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge") if quench else null
	if quench:
		expect(int(bridge.inspect_interaction_profile().profile_version) == 2,
			"Quench trace requires its registered MAT-002 interaction profile")
		samples[0] = quench_snapshot(world,bridge)
	for tick: int in range(source.presentation.duration_ticks):
		if not host.advance():
			expect(false,host.last_error)
			break
		if quench and tick + 1 in [64,73,74,75,89,120,240]:
			samples[tick + 1] = quench_snapshot(world,bridge)
	if quench: check_quench_trace(source,samples)
	var report: Dictionary = host.capture()
	expect(report.outcome == "complete" and not report.failed,"Materials Laboratory preset failed: " + id)
	expect(report.observations.size() == source.observations.size(),"Declared results were omitted: " + id)
	expect(report.definition == parsed.definition and report.definition_hash == checked.hash,
		"Capture lost versioned Materials Laboratory recipe identity: " + id)
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
		expect(values["stone-120"] == 384,"Registered quench trace did not expose 384 Stone cells")
		expect(values["steam-120"] == 386,"Registered quench trace did not expose 386 quantity-bearing Steam parcels")
	return {"samples":samples, "observations":retained.observations, "content":semantic(before)}

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
		var first: Dictionary = check_material_fixture(source,1)
		if id in ["materials/contact-lab", "materials/lava-water"]:
			var parallel: Dictionary = check_material_fixture(source,4)
			expect(first == parallel,"Quench trace/content/quantity changed across worker configurations: " + id)
	# The generated half-dose Lava fixture is public even though only the full
	# dose is a catalogue entry. Its versioned phase trace needs the same check.
	var small: Dictionary = Pack.interaction_fixture("lava-water",2,16)
	expect(check_material_fixture(small,1) == check_material_fixture(small,4),
		"Half-dose quench trace/content/quantity changed across worker configurations")
	print("MICROSCENARIO_MATERIALS_LAB: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
