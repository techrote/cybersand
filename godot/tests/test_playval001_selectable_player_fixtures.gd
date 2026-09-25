extends SceneTree

const Pack = preload("res://scripts/microscenario_reference_pack.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")

var assertions: int = 0
var failures: int = 0


func expect(value: bool, message: String) -> void:
	assertions += 1
	if value:
		return
	failures += 1
	push_error("PLAY-VAL-001: " + message)


func wait_for(predicate: Callable, timeout_ms: int = 60000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call():
			return true
	return false


func load_fixture(desktop: Control, scenario_id: String) -> bool:
	expect(
		desktop.microscenario_launch(scenario_id, "Play", 0),
		scenario_id + " was rejected by the desktop launcher"
	)
	var installed: bool = await wait_for(func() -> bool:
		return (
			desktop.pending_microscenario_apply.is_empty()
			and desktop.tower_context.get("micro_active", false)
			and str(
				desktop.tower_context.get("microscenario", {}).get("id", "")
			) == scenario_id
		)
	)
	expect(installed, scenario_id + " did not reach the acknowledged fresh-reset boundary")
	if installed:
		desktop._refresh_microscenario_controls()
	return installed


func assert_matched_definitions() -> void:
	var baseline: Dictionary = Pack.player_granular_experiment(
		Pack.REM003_SAMPLED_BASELINE_ID,
		0
	)
	var burial: Dictionary = Pack.player_granular_experiment(
		Pack.REM003_BURIAL_SAFE_ID,
		0
	)
	var barrel: Dictionary = Pack.player_granular_experiment(
		Pack.REM003_BARREL_ID,
		0
	)
	var original: Dictionary = Pack.player_granular_review(0)

	for scenario_id: String in Pack.REM003_EXPERIMENT_IDS:
		expect(
			scenario_id in Catalogue.ids(),
			scenario_id + " is not selectable from the shared catalogue"
		)
		var checked: Dictionary = CyberMicroScenarioContract.validate(
			Catalogue.definition(scenario_id, 0)
		)
		expect(
			checked.get("ok", false),
			scenario_id + " does not validate through the shared contract"
		)

	for candidate: Dictionary in [baseline, burial, barrel]:
		expect(
			candidate.rectangles == original.rectangles,
			str(candidate.id) + " changed matched REM-003 geometry"
		)
		expect(
			candidate.events == original.events,
			str(candidate.id) + " changed matched REM-003 events"
		)
		expect(
			candidate.player_start == original.player_start,
			str(candidate.id) + " changed matched player start"
		)
		expect(
			candidate.camera_origin == original.camera_origin,
			str(candidate.id) + " changed matched camera origin"
		)
		expect(
			candidate.tools == original.tools,
			str(candidate.id) + " changed matched owner tools"
		)
		expect(
			str(candidate.source_recipe_hash) == str(original.source_recipe_hash),
			str(candidate.id) + " changed geometry/action ancestry"
		)
		expect(
			str(candidate.maturity) == "exploratory",
			str(candidate.id) + " was not labelled exploratory"
		)

	expect(
		bool(baseline.player_enabled) and not bool(baseline.body_enabled),
		"sampled baseline ownership fields are wrong"
	)
	expect(
		bool(burial.player_enabled) and not bool(burial.body_enabled),
		"burial-safe ownership fields are wrong"
	)
	expect(
		not bool(barrel.player_enabled) and bool(barrel.body_enabled),
		"barrel ownership fields are wrong"
	)
	expect(
		barrel.observations.size() == 1
			and str(barrel.observations[0].id) == "end"
			and str(barrel.observations[0].metric) == "tick",
		"barrel fixture retained masked material-cell census observations"
	)


func assert_active_arm(
	desktop: Control,
	expected_identity: String,
	sampled_enabled: bool,
	recovery_enabled: bool
) -> void:
	expect(
		desktop.player_representation_identity() == expected_identity,
		"active identity is not " + expected_identity
	)
	expect(
		bool(desktop.tower_context.get("sampled_character_enabled", true))
			== sampled_enabled,
		expected_identity + " worker sampled-owner state is wrong"
	)
	expect(
		bool(desktop.tower_context.get(
			"sampled_runtime_recovery_enabled",
			true
		)) == recovery_enabled,
		expected_identity + " worker recovery state is wrong"
	)
	expect(
		desktop.microscenario_panel.picker.get_item_text(
			desktop.microscenario_panel.picker.selected
		) == str(desktop.tower_context.microscenario.id),
		expected_identity + " was not reflected by the selectable picker"
	)
	expect(
		desktop.microscenario_panel.status.text.contains(
			"player " + expected_identity
		),
		expected_identity + " is absent from MicroScenario status"
	)


func assert_reset_retains_arm(
	desktop: Control,
	scenario_id: String,
	expected_identity: String
) -> void:
	desktop.microscenario_reset()
	expect(
		await wait_for(func() -> bool:
			return (
				desktop.pending_microscenario_apply.is_empty()
				and str(
					desktop.tower_context.get("microscenario", {}).get("id", "")
				) == scenario_id
			)
		),
		scenario_id + " fresh reset did not acknowledge"
	)
	expect(
		desktop.player_representation_identity() == expected_identity,
		scenario_id + " fresh reset changed representation"
	)


func _init() -> void:
	call_deferred("run")


func run() -> void:
	assert_matched_definitions()

	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	root.size = Vector2i(1600, 1200)
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame

	if await load_fixture(desktop, Pack.REM003_SAMPLED_BASELINE_ID):
		assert_active_arm(desktop, "sampled-baseline", true, true)
		var before_identity: String = desktop.player_representation_identity()
		expect(
			not desktop.cycle_player_representation(),
			"F6-equivalent representation switch escaped the controlled fixture"
		)
		expect(
			not desktop.toggle_sampled_runtime_recovery(),
			"F7-equivalent recovery switch escaped the controlled fixture"
		)
		expect(
			desktop.player_representation_identity() == before_identity,
			"blocked fixture switches still mutated sampled baseline"
		)
		var mismatched_barrel: Dictionary = Pack.player_granular_experiment(
			Pack.REM003_BARREL_ID,
			0
		)
		mismatched_barrel.player_enabled = true
		var baseline_definition_hash: String = str(
			desktop.tower_context.microscenario.definition_hash
		)
		expect(
			not desktop.microscenario_apply_definition(
				mismatched_barrel,
				"Play"
			),
			"mismatched experimental body/player ownership was accepted"
		)
		expect(
			desktop.player_representation_identity() == before_identity
				and str(desktop.tower_context.microscenario.definition_hash)
					== baseline_definition_hash,
			"rejected experimental reset mutated the installed player arm"
		)
		await assert_reset_retains_arm(
			desktop,
			Pack.REM003_SAMPLED_BASELINE_ID,
			"sampled-baseline"
		)

	if await load_fixture(desktop, Pack.REM003_BURIAL_SAFE_ID):
		assert_active_arm(desktop, "sampled-burial-safe", true, false)
		await assert_reset_retains_arm(
			desktop,
			Pack.REM003_BURIAL_SAFE_ID,
			"sampled-burial-safe"
		)

	if await load_fixture(desktop, Pack.REM003_BARREL_ID):
		assert_active_arm(desktop, "barrel-rapier", false, false)
		expect(
			desktop.rigid_bodies.size() == 1,
			"barrel fixture activated extra generic reference bodies"
		)
		desktop.update_status()
		expect(
			desktop.status_label.text.contains("barrel-rapier")
				and not desktop.status_label.text.contains(
					"player disabled / barrel-rapier"
				),
			"compact HUD labelled the active barrel player as disabled"
		)
		expect(
			desktop.rapier_bridge.is_initialized(),
			"barrel fixture did not initialize the Rapier bridge"
		)
		if desktop.rapier_bridge.is_initialized():
			var expected_centre := Vector2(
				desktop.microscenario_definition.player_start[0],
				desktop.microscenario_definition.player_start[1]
			) + CyberSampledCharacter.BODY_SIZE * 0.5
			expect(
				desktop.rapier_bridge.body_transform(
					CyberPlayerRepresentation.BARREL_BODY_INDEX
				).origin.is_equal_approx(expected_centre),
				"barrel fixture did not place body 0 at the matched player start"
			)
		await assert_reset_retains_arm(
			desktop,
			Pack.REM003_BARREL_ID,
			"barrel-rapier"
		)

	# Crossing back from barrel to sampled must tear down the temporary one-body
	# player bridge rather than leaving a hidden generic body owner in the fixture.
	if await load_fixture(desktop, Pack.REM003_SAMPLED_BASELINE_ID):
		assert_active_arm(desktop, "sampled-baseline", true, true)
		expect(
			desktop.rigid_bodies.is_empty(),
			"sampled fixture retained the barrel body owner"
		)

	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	desktop.queue_free()
	await process_frame
	print(
		"PLAYVAL001_SELECTABLE_PLAYER_FIXTURES: %d assertions; %d failures"
		% [assertions, failures]
	)
	quit(1 if failures else 0)
