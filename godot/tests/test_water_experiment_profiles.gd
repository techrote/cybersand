extends SceneTree

const CyberWaterExperimentContract = preload("res://scripts/water_experiment_contract.gd")
const CyberWaterExperimentProfiles = preload("res://scripts/water_experiment_profiles.gd")
const CyberWaterExperimentBlind = preload("res://scripts/water_experiment_blind.gd")
const CyberWaterExperimentPanel = preload("res://scripts/water_experiment_panel.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var defaults: Dictionary = CyberWaterExperimentProfiles.resolve()
	assert(defaults.ok)
	assert(defaults.policy == CyberWaterExperimentContract.default_policy())
	assert(defaults.semantic == PackedInt32Array([1, 8, 12, 0]))
	assert(defaults.source == "default")
	assert(defaults.canonical_json == (
		'{"version":1,"mass_bits":8,"coherence_ticks":12,'
		+ '"rest_policy":"current-normalized-v1","render_fill_levels":4,'
		+ '"interface_mode":"coverage","scenario_id":"shallow-pool","seed":0}'
	))
	assert(defaults.hash.length() == 64)
	assert(defaults.derived == {"maximum": 255, "film": 48, "tolerance": 1})

	var profile: Dictionary = {
		"version": 1,
		"mass_bits": 4,
		"coherence_ticks": 3,
		"scenario_id": "drips",
		"seed": 1,
	}
	var launch: PackedStringArray = PackedStringArray([
		"--unrelated-option=yes",
		"--water-mass-bits=5",
		"--water-coherence", "three-bit",
		"--experiment=thin-stream",
		"--seed=2",
	])
	var panel_layer: Dictionary = {
		"mass_bits": 6,
		"coherence_ticks": "none",
		"interface_mode": "oriented",
		"seed": 3,
	}
	var resolved: Dictionary = CyberWaterExperimentProfiles.resolve(
		profile, launch, panel_layer
	)
	assert(resolved.ok)
	assert(resolved.policy.mass_bits == 6)
	assert(resolved.policy.coherence_ticks == 0)
	assert(resolved.policy.interface_mode == "oriented")
	assert(resolved.policy.scenario_id == "thin-stream")
	assert(resolved.policy.seed == 3)
	assert(resolved.semantic == PackedInt32Array([1, 6, 0, 0]))
	assert(resolved.derived == {"maximum": 63, "film": 12, "tolerance": 0})
	assert(resolved.source == "panel")
	assert(resolved.provenance.applied_layers == ["profile", "launch", "panel"])
	assert(resolved.provenance.field_origins.version == "profile")
	assert(resolved.provenance.field_origins.mass_bits == "panel")
	assert(resolved.provenance.field_origins.coherence_ticks == "panel")
	assert(resolved.provenance.field_origins.interface_mode == "panel")
	assert(resolved.provenance.field_origins.scenario_id == "launch")
	assert(resolved.provenance.field_origins.rest_policy == "default")

	for named: String in ["current", "three-bit", "short", "none"]:
		var named_result: Dictionary = CyberWaterExperimentProfiles.resolve(
			{}, PackedStringArray(["--water-coherence=" + named]), {}
		)
		assert(named_result.ok)
		assert(named_result.policy.coherence_ticks == CyberWaterExperimentProfiles.COHERENCE_NAMES[named])
	for bits: int in range(3, 9):
		assert(CyberWaterExperimentProfiles.resolve({}, {}, {"mass_bits": bits}).ok)
	for ticks: int in range(13):
		assert(CyberWaterExperimentProfiles.resolve({}, {}, {"coherence_ticks": ticks}).ok)
	for mode: String in CyberWaterExperimentContract.INTERFACE_MODES:
		assert(CyberWaterExperimentProfiles.resolve({}, {}, {"interface_mode": mode}).ok)
	for scenario_id: String in CyberWaterExperimentContract.SCENARIO_IDS:
		assert(CyberWaterExperimentProfiles.resolve({}, {}, {"scenario_id": scenario_id}).ok)
	for boundary_seed: int in [0, CyberWaterExperimentProfiles.MAX_SEED]:
		assert(CyberWaterExperimentProfiles.resolve({}, {}, {"seed": boundary_seed}).ok)
	assert(CyberWaterExperimentProfiles.parse_config(
		'{"version":1,"mass_bits":3}'
	).ok)

	var equivalent: Dictionary = CyberWaterExperimentContract.default_policy()
	equivalent.mass_bits = 5
	equivalent.coherence_ticks = 7
	equivalent.interface_mode = "oriented"
	equivalent.scenario_id = "u-vessel"
	equivalent.seed = 18_472
	var profile_result: Dictionary = CyberWaterExperimentProfiles.resolve(
		CyberWaterExperimentProfiles.canonical_json(equivalent), {}, {}
	)
	var launch_result: Dictionary = CyberWaterExperimentProfiles.resolve({}, PackedStringArray([
		"--water-policy-version=1",
		"--water-mass-bits=5",
		"--water-coherence=7",
		"--water-rest-policy=current-normalized-v1",
		"--water-render-levels=4",
		"--water-interface=oriented",
		"--experiment=u-vessel",
		"--seed=18472",
	]), {})
	var panel_result: Dictionary = CyberWaterExperimentProfiles.resolve({}, {}, equivalent)
	assert(profile_result.ok and launch_result.ok and panel_result.ok)
	assert(profile_result.hash == launch_result.hash)
	assert(profile_result.hash == panel_result.hash)
	assert(profile_result.canonical_json == launch_result.canonical_json)
	assert(profile_result.source == "profile")
	assert(launch_result.source == "launch")
	assert(panel_result.source == "panel")

	var profile_before: Dictionary = profile.duplicate(true)
	var launch_before: PackedStringArray = launch.duplicate()
	var panel_before: Dictionary = panel_layer.duplicate(true)
	var active_hash: String = resolved.hash
	assert(not CyberWaterExperimentProfiles.resolve(profile, launch, {"mass_bits": 9}).ok)
	assert(not CyberWaterExperimentProfiles.resolve({"mass_bits": 4}, {}, {}).ok)
	assert(not CyberWaterExperimentProfiles.resolve("[]", {}, {}).ok)
	assert(not CyberWaterExperimentProfiles.resolve(17, {}, {}).ok)
	assert(not CyberWaterExperimentProfiles.resolve({}, 17, {}).ok)
	assert(not CyberWaterExperimentProfiles.resolve({}, {}, {"unexpected": 1}).ok)
	assert(not CyberWaterExperimentProfiles.resolve({}, {}, {"scenario_id": "unknown"}).ok)
	assert(not CyberWaterExperimentProfiles.resolve({}, {}, {"seed": 2_147_483_648}).ok)
	assert(not CyberWaterExperimentProfiles.resolve(
		{}, PackedStringArray(["--water-mass-bits=4", "--water-mass-bits=5"]), {}
	).ok)
	assert(profile == profile_before and launch == launch_before and panel_layer == panel_before)
	assert(active_hash == resolved.hash)

	var candidates: Array = []
	for bits: int in [3, 5, 8]:
		var candidate: Dictionary = equivalent.duplicate(true)
		candidate.mass_bits = bits
		candidates.append(
			CyberWaterExperimentProfiles.resolve(
				CyberWaterExperimentProfiles.canonical_json(candidate), {}, {}
			) if bits == 3 else candidate
		)
	seed(994_201)
	var expected_random: int = randi()
	seed(994_201)
	var blind: Dictionary = CyberWaterExperimentBlind.create(candidates, 90_021)
	var actual_random: int = randi()
	var blind_repeat: Dictionary = CyberWaterExperimentBlind.create(candidates, 90_021)
	assert(blind.ok and blind_repeat.ok)
	assert(expected_random == actual_random)
	assert(blind.labels == ["A", "B", "C"])
	assert(blind.hidden_mapping == blind_repeat.hidden_mapping)
	assert(not CyberWaterExperimentBlind.create([candidates[0]], 1).ok)
	assert(not CyberWaterExperimentBlind.create(candidates, -1).ok)
	assert(not CyberWaterExperimentBlind.create(
		[candidates[0], candidates[0].duplicate(true)], 1
	).ok)
	var retained_profile_source: bool = false
	for label: String in blind.labels:
		var hidden: Dictionary = blind.hidden_mapping[label]
		retained_profile_source = retained_profile_source or hidden.source == "profile"
		var reconstructed: Dictionary = CyberWaterExperimentProfiles.resolve({}, {}, hidden.policy)
		assert(reconstructed.ok and reconstructed.hash == hidden.hash)
		var visible: Dictionary = CyberWaterExperimentBlind.visible_record(
			blind, label, {"paused": true, "single_steps": 0}
		)
		assert(visible.ok and visible.label == label and not visible.revealed)
		assert(not visible.has("hash") and not visible.has("policy"))
		assert(visible.run_controls.paused)
	assert(retained_profile_source)
	var exported: Dictionary = CyberWaterExperimentBlind.export_metadata(blind, {
		"recipe_version": 1,
		"source": "test",
		"artifact": "focused",
		"platform": "headless",
		"worker_count": 1,
		"action_history": [],
	})
	assert(exported.ok)
	assert(exported.metadata.hidden_mapping == blind.hidden_mapping)
	assert(exported.metadata.context.recipe_version == 1)
	var corrupted: Dictionary = blind.duplicate(true)
	corrupted.hidden_mapping.A.hash = "bad"
	assert(not CyberWaterExperimentBlind.export_metadata(corrupted).ok)
	var bogus_source: Dictionary=profile_result.duplicate(true)
	bogus_source.source="bogus"
	assert(not CyberWaterExperimentBlind.create([bogus_source,launch_result],17).ok)
	var bogus_origin: Dictionary=profile_result.duplicate(true)
	bogus_origin.provenance.field_origins.mass_bits="bogus"
	assert(not CyberWaterExperimentBlind.create([bogus_origin,launch_result],17).ok)
	var corrupted_provenance: Dictionary=blind.duplicate(true)
	corrupted_provenance.hidden_mapping.A.source="bogus"
	assert(not CyberWaterExperimentBlind.export_metadata(corrupted_provenance).ok)

	var emitted: Array[Dictionary] = []
	var developer_panel: CyberWaterExperimentPanel = CyberWaterExperimentPanel.new()
	root.add_child(developer_panel)
	developer_panel.setup(profile, launch)
	developer_panel.apply_requested.connect(func(result: Dictionary) -> void:
		emitted.append(result)
	)
	developer_panel.set_draft(panel_layer)
	assert(developer_panel.submit_draft())
	assert(emitted.size() == 1)
	assert(emitted[0].hash == resolved.hash)
	assert(emitted[0].semantic == PackedInt32Array([1, 6, 0, 0]))
	developer_panel.queue_free()

	print("WATER_EXPERIMENT_PROFILES: canonical/surfaces/precedence/provenance/invalid/blind/panel passed ", resolved.hash)
	quit()
