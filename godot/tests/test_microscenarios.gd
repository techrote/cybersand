extends SceneTree

const Contract = preload("res://scripts/microscenario_contract.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Host = preload("res://scripts/microscenario_host.gd")
var failures: int = 0
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition: return
	failures += 1
	push_error(message)

func observe(world: Variant) -> Dictionary:
	return world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024,1024))

func new_world(workers: int = 1) -> Variant:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":workers}), "worker configuration rejected")
	world.set_simulation_window_enabled(false)
	return world

func _run() -> void:
	for scenario_id: String in Catalogue.ids():
		var value: Dictionary = Catalogue.definition(scenario_id, 0)
		var checked: Dictionary = Contract.validate(value)
		expect(checked.get("ok", false), scenario_id + ": " + str(checked))
		if not checked.get("ok", false): continue
		var round_trip: Dictionary = Contract.parse(checked.canonical_json)
		expect(round_trip.get("ok", false) and round_trip.get("hash", "") == checked.hash,
			scenario_id + " did not survive canonical JSON round trip")
		var copy: Dictionary = Contract.validate(value.duplicate(true))
		expect(copy.hash == checked.hash, "same definition produced a different hash")
	_schema_rejections()
	_interaction_provenance_tests()
	var control: Variant = new_world()
	var migrated: Variant = new_world()
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var host: CyberMicroScenarioHost = Host.new()
	var transport: Dictionary = CyberTransportProfiles.resolve(CyberTransportProfiles.preset(0))
	expect(bridge.build_tuned_world(control, CyberExperimentTower.rectangles(), transport.packed), "legacy Tower setup failed")
	expect(host.install(migrated, Catalogue.tower()), host.last_error)
	expect(observe(control) == observe(migrated), "Tower generic setup changed native state")
	# Every existing Water recipe retains the old native builder and tick semantics.
	for scenario_id: String in CyberWaterFeelScenarios.ids():
		for bits: int in [3,8]:
			var policy: Dictionary = CyberWaterExperimentProfiles.resolve({}, {}, {
				"scenario_id":scenario_id, "seed":31, "mass_bits":bits,
				"coherence_ticks":7 if bits == 3 else 12})
			var recipe: Dictionary = CyberWaterFeelScenarios.recipe(scenario_id, 31)
			expect(bridge.build_water_feel_world(control, recipe.rectangles, transport.packed,
				policy.semantic, recipe.partial_water_fills), "legacy Water build failed")
			expect(host.install(migrated, Catalogue.water(policy)), host.last_error)
			expect(observe(control) == observe(migrated), "setup drift: " + scenario_id)
			var index: int = 0
			for tick: int in range(92 if scenario_id in ["drips", "trickle", "mercury-reference", "connected-pools"] else 4):
				while index < recipe.actions.size() and int(recipe.actions[index].tick) == tick:
					var action: Dictionary = recipe.actions[index]
					if action.kind == "fill":
						var coherence: int = int((2 * int(action.coherence) * int(policy.policy.coherence_ticks) + 12) / 24)
						expect(control.water_experiment_fill_rect(Vector2i(action.x,action.y),
							Vector2i(action.width,action.height), action.normalized_mass, coherence), "legacy fill failed")
					elif action.kind == "erase":
						expect(control.water_experiment_erase_rect(Vector2i(action.x,action.y),
							Vector2i(action.width,action.height)), "legacy erase failed")
					index += 1
				expect(control.simulation_tick(), "legacy tick failed")
				expect(host.advance(), host.last_error)
				expect(observe(control) == observe(migrated), "tick drift: " + scenario_id + " mass" + str(bits))
	# Closed Water and non-Water fixtures cross the event deadlines and finish
	# identically in all modes, repeats, and one/four workers with observers off.
	for fixture: String in ["fixtures/unequal-head", "fixtures/sand-release"]:
		var expected: Dictionary = {}
		for workers: int in [1,4]:
			var exact: Dictionary = {}
			for mode: String in Contract.MODES:
				for observers: bool in [true,false]:
					var world: Variant = new_world(workers)
					var runner: CyberMicroScenarioHost = Host.new()
					var definition: Dictionary = Catalogue.definition(fixture, 2)
					expect(runner.install(world, definition, mode, observers), runner.last_error)
					for tick: int in range(120): expect(runner.advance(), runner.last_error)
					var actual: Dictionary = observe(world)
					if exact.is_empty(): exact = actual
					expect(actual == exact, "same-worker exact mode/observer drift: " + fixture)
					# WorldConfig's worker count participates in state_hash; normalize
					# that metadata deliberately and compare content plus exact mass.
					var semantic: Dictionary = {"tick":actual.tick, "content_hash":actual.content_hash,
						"water_integer":actual.water_integer, "water_cells":actual.water_cells}
					if expected.is_empty(): expected = semantic
					expect(semantic == expected, "mode/worker/observer semantic drift: " + fixture)
					expect(runner.summary().outcome == "complete", "objective did not observe final state: " + fixture)
					var report: Dictionary = runner.capture({"source_revision":"test-only"})
					expect(not report.replay_complete, "capture falsely claims replay")
					expect(report.definition.id == fixture, "capture lost fixture identity")
					expect(Contract.validate(report.definition).hash == report.definition_hash, "capture definition/hash mismatch")
	_transaction_and_ownership_tests()
	_native_failure_test()
	print("MICROSCENARIOS: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)


func _interaction_provenance_tests() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	expect(bridge.has_method(&"inspect_interaction_profile") and bridge.has_method(&"inspect_interaction"),
		"INT-000 native provenance methods are unavailable")
	var profile: Dictionary = bridge.inspect_interaction_profile()
	expect(profile.get("schema_id","") == "cybersand.interactions" and int(profile.get("schema_version",0)) == 1,
		"INT-000 native schema identity is missing")
	expect(profile.get("pair_rules",[]).size() == 14 and profile.get("channels",[]).size() == 7
		and profile.get("specialized_rules",[]).size() == 19 and profile.get("layer_kinds",[]).size() == 5,
		"INT-000 profile catalogue is incomplete")
	expect(profile.get("authored_layers",[]).is_empty(),
		"Current profile unexpectedly gained authored default/adjustment/modifier semantics")
	var validation: Dictionary = profile.get("catalogue_validation",{})
	expect(validation.get("ok",false) and int(validation.get("duplicate_rule_ids",-1)) == 0
		and int(validation.get("conflicting_pair_overrides",-1)) == 0
		and int(validation.get("invalid_family_memberships",-1)) == 0
		and int(validation.get("unresolved_layer_conflicts",-1)) == 0
		and int(validation.get("invalid_supersession_links",-1)) == 0,
		"INT-000 catalogue conflict validation is not clean")
	var salt: Dictionary = bridge.inspect_interaction(3,23,255)
	expect(salt.get("matched",false) and salt.get("selected",false)
		and int(salt.get("source_product",-1)) == 24 and int(salt.get("target_product",-1)) == 24,
		"Water/Salt provenance does not expose the effective compact rule")
	expect(salt.get("tuning_pass_id","") == "int.pass.current-oracle"
		and salt.get("tuning_pass_disposition","") == "characterized-baseline"
		and salt.get("tuning_pass_changed_rules","missing") == "none"
		and not salt.get("revalidation_tags",[]).is_empty(),
		"effective rule did not expose selected-pass changes/revalidation provenance")
	var acid_reverse: Dictionary = bridge.inspect_interaction(28,12,96)
	expect(acid_reverse.get("selected",false) and int(acid_reverse.get("source_product",-1)) == 29
		and int(acid_reverse.get("target_product",-1)) == 4 and acid_reverse.get("reversed",false),
		"role-preserving reverse provenance changed")
	var themed: Dictionary = bridge.inspect_interaction(53,34,0)
	expect(not themed.get("matched",true) and not "int.family.conductive-base-metal" in themed.get("source_families",[]),
		"themed metal inherited base-Metal electrical semantics")

	var fixtures: Array[String] = ["materials/salt-water", "materials/sand-water-control",
		"materials/lava-water", "materials/fire-gunpowder", "materials/acid-metal",
		"materials/spark-metal", "materials/cement-water"]
	for fixture: String in fixtures:
		var expected: Dictionary = {}
		for workers: int in [1,4]:
			var world: Variant = new_world(workers)
			var host: CyberMicroScenarioHost = Host.new()
			var definition: Dictionary = Catalogue.definition(fixture, 3)
			expect(Contract.validate(definition).get("ok",false), "invalid generated INT fixture: " + fixture)
			expect(host.install(world,definition,"Inspect",true), host.last_error)
			var summary: Dictionary = host.summary()
			expect(summary.get("interaction_profile",{}).get("schema_id","") == "cybersand.interactions",
				"generated fixture lacks native INT profile: " + fixture)
			expect(not summary.get("interaction_inspection",[]).is_empty(),
				"generated fixture lacks bounded INT provenance inspection: " + fixture)
			var duration: int = int(definition.presentation.duration_ticks)
			for tick: int in range(duration): expect(host.advance(), fixture + ": " + host.last_error)
			var report: Dictionary = host.capture({"source_revision":"test-only"})
			expect(report.get("outcome","") == "complete", "generated fixture did not complete: " + fixture)
			expect(report.get("interaction_profile_full",{}).get("pair_rules",[]).size() == 14,
				"capture lost full INT profile: " + fixture)
			var baseline: Dictionary = report.get("kinetic_contact_baseline",{})
			expect(baseline.get("transport_hash","") == report.get("transport_hash","")
				and baseline.get("source_runtime_identity",{}).get("source_revision","") == "test-only"
				and int(baseline.get("worker_count",0)) == workers,
				"capture lost rolling kinetic/contact baseline identity: " + fixture)
			var semantic: Dictionary = {"observations":report.get("observations",[]),
				"interaction_inspection":report.get("interaction_inspection",[])}
			if expected.is_empty(): expected = semantic
			expect(semantic == expected, "one/four-worker INT fixture evidence diverged: " + fixture)

	# Deterministic repeat of the first generated interaction fixture under the same
	# seed/worker/runtime identity. This is intentionally bounded rather than repeating
	# every mechanism and extending the regression shard unnecessarily.
	var repeat_definition: Dictionary = Catalogue.definition("materials/salt-water",3)
	var first_repeat: Dictionary = {}
	for repeat_index: int in range(2):
		var repeat_world: Variant = new_world(1)
		var repeat_host: CyberMicroScenarioHost = Host.new()
		expect(repeat_host.install(repeat_world,repeat_definition,"Inspect",true), repeat_host.last_error)
		for tick: int in range(int(repeat_definition.presentation.duration_ticks)):
			expect(repeat_host.advance(), repeat_host.last_error)
		var repeat_report: Dictionary = repeat_host.capture({"source_revision":"test-only"})
		var repeat_semantic: Dictionary = {"observations":repeat_report.get("observations",[]),
			"interaction_inspection":repeat_report.get("interaction_inspection",[])}
		if repeat_index == 0: first_repeat = repeat_semantic
		else: expect(repeat_semantic == first_repeat, "deterministic repeated INT fixture diverged")


func _schema_rejections() -> void:
	var invalid: Dictionary = Catalogue.unequal_head()
	invalid["script"] = "write cells"
	expect(not Contract.validate(invalid).ok, "unknown scripting escape accepted")
	for seed: Variant in [-1, 2147483648, 0.5, true, "12", INF, NAN]:
		invalid = Catalogue.unequal_head()
		invalid.seed = seed
		expect(not Contract.validate(invalid).ok, "invalid seed accepted: " + str(seed))
	invalid = Catalogue.unequal_head()
	invalid.rectangles[0] = 1024
	expect(not Contract.validate(invalid).ok, "out-of-world setup accepted")
	invalid = Catalogue.unequal_head()
	invalid.events[0].kind = "script"
	expect(not Contract.validate(invalid).ok, "unknown event accepted")
	invalid = Catalogue.unequal_head()
	invalid.events[0].tick = Contract.MAX_TICK + 1
	expect(not Contract.validate(invalid).ok, "unbounded event horizon accepted")
	invalid = Catalogue.unequal_head()
	while invalid.events.size() <= Contract.MAX_EVENTS: invalid.events.append(invalid.events[0].duplicate(true))
	expect(not Contract.validate(invalid).ok, "event capacity overflow accepted")
	invalid = Catalogue.unequal_head()
	invalid.events.append(invalid.events[0].duplicate(true))
	invalid.events[1].tick = 0
	expect(not Contract.validate(invalid).ok, "unsorted events accepted")
	invalid = Catalogue.unequal_head()
	invalid.observations[1].id = invalid.observations[0].id
	expect(not Contract.validate(invalid).ok, "duplicate observation accepted")
	invalid = Catalogue.unequal_head()
	invalid.conditions[0].observation = "missing"
	expect(not Contract.validate(invalid).ok, "missing condition dependency accepted")
	invalid = Catalogue.sand_release()
	invalid.body_enabled = true
	expect(not Contract.validate(invalid).ok, "masked material count accepted as authoritative")
	invalid = Catalogue.unequal_head()
	invalid.rectangles[4] = 10
	expect(not Contract.validate(invalid).ok, "reserved material accepted")
	expect(not Contract.parse("{}").ok, "empty schema accepted")
	expect(not Contract.parse("{broken").ok, "broken JSON accepted")

func _transaction_and_ownership_tests() -> void:
	var world: Variant = new_world()
	var host: CyberMicroScenarioHost = Host.new()
	var definition: Dictionary = Catalogue.unequal_head()
	expect(host.install(world, definition), host.last_error)
	for tick: int in range(31): expect(host.advance(), host.last_error)
	var before: Dictionary = observe(world)
	var summary: Dictionary = host.summary()
	var invalid: Dictionary = definition.duplicate(true)
	invalid.rectangles[0] = -1
	expect(not host.install(world, invalid), "invalid reset accepted")
	expect(observe(world) == before, "invalid reset mutated World")
	expect(host.summary().events_applied == summary.events_applied, "invalid reset changed event cursor")
	expect(not host.install(world, definition, "unknown"), "invalid mode accepted")
	expect(observe(world) == before, "invalid mode changed World")
	var retained: Dictionary = host.capture()
	var exported: Dictionary = host.definition()
	exported.rectangles[0] = -99
	definition.events.clear()
	expect(host.definition().events.size() == 1 and host.definition().rectangles[0] != -99,
		"caller mutation changed installed definition")
	expect(host.install(world, Catalogue.sand_release()), host.last_error)
	expect(retained.id == "fixtures/unequal-head" and retained.completed_tick == 31,
		"reset mutated retained capture")
	# A missed boundary is a visible host failure, not a late event or replay.
	for tick: int in range(12): expect(world.simulation_tick(), "test tick failed")
	expect(not host.before_tick(), "missed event silently caught up")
	var failed_hash: Dictionary = observe(world)
	expect(not host.before_tick() and observe(world) == failed_hash, "failed host retried/mutated")
	expect(host.install(world, Catalogue.sand_release()), "fresh reset did not recover host")
	expect(host.advance(), host.last_error)

func _native_failure_test() -> void:
	var previous: Variant = ProjectSettings.get_setting("cybersand/native_active_core_capacity", null)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", 1)
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", previous)
	world.set_simulation_window_enabled(false)
	var definition: Dictionary = Contract.base("fixtures/capacity-failure")
	definition.rectangles = [20,20,1,1,2, 160,20,1,1,2]
	var host: CyberMicroScenarioHost = Host.new()
	expect(host.install(world, definition), host.last_error)
	expect(not host.advance() and world.has_failed(), "native capacity failure was not quarantined")
	var attempted: int = int(world.get_attempted_tick_index())
	expect(not host.advance() and int(world.get_attempted_tick_index()) == attempted,
		"failed scenario automatically retried a native tick")
	var report: Dictionary = host.capture()
	expect(report.failed and report.native.is_empty(), "failed native state exported as a successful observation")
	definition.rectangles = [20,20,1,1,2]
	expect(host.install(world, definition) and not world.has_failed(), "explicit fresh reset did not recover quarantine")
	expect(host.advance(), "recovered single-core fixture did not advance")
