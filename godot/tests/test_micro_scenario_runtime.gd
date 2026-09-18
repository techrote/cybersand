extends SceneTree

const Catalogue = preload("res://scripts/micro_scenario_catalogue.gd")
const Host = preload("res://scripts/micro_scenario_host.gd")
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	if ok: return
	failures += 1
	push_error(message)

func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		expect(false, "Native backend unavailable"); quit(failures); return
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var host: CyberMicroScenarioHost = Host.new()
	var transport: Dictionary = CyberTransportProfiles.resolve(CyberTransportProfiles.preset(0))
	# Independent old construction path is the oracle, not a second call through
	# the extraction. Covers Tower and every registered Water recipe at extremes.
	expect(bridge.build_tuned_world(world, CyberExperimentTower.rectangles(), transport.packed), "legacy Tower failed")
	var reference: Dictionary = Host.observe(world)
	expect(host.reset(world, Catalogue.tower()), "Tower host reset failed")
	expect(reference == Host.observe(world), "Tower setup changed authoritative initial state")
	for id: String in CyberWaterFeelScenarios.ids():
		for bits: int in [3,8]:
			var policy: Dictionary = CyberWaterExperimentProfiles.resolve({}, {}, {
				"scenario_id": id, "seed": 17, "mass_bits": bits, "coherence_ticks": 7})
			var recipe: Dictionary = CyberWaterFeelScenarios.recipe(id, 17)
			expect(bridge.build_water_feel_world(world, recipe.rectangles, transport.packed,
				policy.semantic, recipe.partial_water_fills), "legacy Water reset failed")
			var before: Dictionary = Host.observe(world)
			expect(host.reset(world, Catalogue.water(policy.policy)), "host rejected Water " + id)
			expect(before == Host.observe(world), "Water initial-state parity failed: " + id)
	var fixture: Dictionary = Catalogue.definition("communicating-reservoirs", 17)
	var baseline: Dictionary = {}
	for workers: int in [1,4]:
		ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
		for mode: String in ["play", "inspect", "benchmark"]:
			for observers: bool in [false, true]:
				var run_world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
				var run: CyberMicroScenarioHost = Host.new()
				expect(run.reset(run_world, fixture, mode, observers), "generic reset failed")
				run_world.simulation_window_enabled = false
				run_world.cadence_lod_enabled = false
				for tick: int in range(121):
					expect(run.apply_due(run_world), "event rejected")
					expect(run_world.simulation_tick(), "native tick failed")
				var final: Dictionary = Host.observe(run_world)
				if baseline.is_empty(): baseline = final
				expect(final == baseline, "mode/observers/workers changed physical result")
				expect(run.event_index == 3 and run.history.size() == 3, "event count/order not bounded")
				expect(run.observations.size() == (2 if observers else 0), "observer disable ineffective")
				expect(run.objectives.get("right-column-retains-water") == "success", "objective depends on observer mode")
				expect(final.water_integer == run.initial_integer, "closed fixture lost/gained Water")
				var captured: Dictionary = run.capture(run_world)
				expect(captured.persistence.contains("not exact replay"), "capture overclaims replay")
				expect(captured.runtime.native_artifact_sha256.length() == 64, "actual native artifact identity missing")
				captured.definition.events.clear()
				expect(run.definition().events.size() == 3, "capture exposes mutable definition")
				var prior_cursor: int = run.event_index
				var prior_hash: String = run.definition_hash
				var invalid: Dictionary = fixture.duplicate(true)
				invalid.rectangles = [0,0,1,1,999]
				expect(not run.reset(run_world, invalid), "invalid reset accepted")
				expect(run.event_index == prior_cursor and run.definition_hash == prior_hash \
					and Host.observe(run_world) == final, "invalid reset mutated live run/world")
				expect(run.reset(run_world, fixture, mode, observers) and run.event_index == 0 \
					and run.history.is_empty() and run.objectives.values() == ["pending"], "reset leaked run state")
	# Genuine native failed-tick quarantine, then invalid reset, then fresh reset.
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", 1)
	var failed_world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", null)
	var failed_run: CyberMicroScenarioHost = Host.new()
	expect(failed_run.reset(failed_world, fixture), "limited-capacity setup failed")
	failed_world.simulation_window_enabled = false
	expect(not failed_world.simulation_tick() and failed_world.has_failed(), "quarantine fixture did not fail")
	var failed_tick: int = failed_world.get_attempted_tick_index()
	expect(not failed_run.apply_due(failed_world), "host advanced quarantined run")
	expect(failed_run.capture(failed_world).state_status == "failed-diagnostic-only", "failed capture claimed completed state")
	expect(not failed_run.reset(failed_world, {}), "invalid failed-world reset accepted")
	expect(failed_world.has_failed() and failed_world.get_attempted_tick_index() == failed_tick, "invalid reset recovered/retried failure")
	expect(failed_run.reset(failed_world, fixture) and not failed_world.has_failed(), "explicit replacement did not clear quarantine")
	print("MS-000 runtime: ", "PASS" if failures == 0 else "FAIL", " / final=", JSON.stringify(baseline))
	quit(failures)
