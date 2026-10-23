extends SceneTree

# 4LY-003 DEV/CONFORMANCE only. All physics are actual CyberNativeCellWorld
# and Rapier2D through CyberPhysicalActorArena; NOT the sealed final score.
const Episode = preload("res://scripts/physical_flight_episode.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Course = preload("res://scripts/physical_flight_course.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
const Controller = preload("res://scripts/physical_flight_controller.gd")
const REGISTRATION: String = "res://tests/fixtures/4ly003_qualification_registration.json"
const EXPECTED: Dictionary = {
	"4ly_trainer": "f1f9286a27b929c96caca5aaf2be70cbd82e0fd933f29968c1aaaa43ac8f1704",
	"4ly_hauler": "e9979ed9e437d2fcdf5c4c52fb4385e788d4ccd6f40c7494308c60c26c11e10d",
	"4ly_drifter": "c195dd35677dcbdb76c85c798d0c1fbc103dcc40182932be7d70c755b1dbac24",
	"4ly_dart": "a48a58c388fb0826f5b5b29005a7469d2cd081dd2c0ed3bfe6c028d88cd04084"
}

var assertions: int = 0
var failures: int = 0
var episode: CyberPhysicalFlightEpisode
var results: Array = []


func _init() -> void:
	_run.call_deferred()


func check(condition: bool, reason: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("4LY003_DEV: " + reason)


func _run_episode(model: StringName, scenario_id: String, source: StringName = &"teacher",
		max_ticks: int = 0) -> Dictionary:
	var ok: bool = episode.reset(model, scenario_id, 101, "development", source)
	check(ok, "actual-host reset " + str(model) + "/" + scenario_id + ": " + episode.last_error)
	if not ok:
		return {}
	var first: Dictionary = episode.observe()
	check(first.version == Episode.OBS_VERSION and first.action_version == Episode.ACTION_VERSION,
		"versioned copied policy observation")
	for forbidden: String in ["model", "rig_id", "absolute_goal", "centre", "position",
		"scenario", "split", "seed", "terminal", "reward", "future_disturbances",
		"course_geometry", "contact_count"]:
		check(not first.has(forbidden), "policy observation forbids evaluator key: " + forbidden)
	check(not first.has("navigation_credit"), "evaluator navigation credit not policy input")
	check(bool(first.local_obstacles.available) and first.local_obstacles.valid.size() == 8,
		"owner ray sensing provides eight admitted validity masks")
	check(bool(first.capabilities.has("desired_speed")) and not first.capabilities.has("id"),
		"copy of STATIC physical capabilities does not contain name/identity")
	var snapshot_capability: float = float(first.capabilities.desired_speed[0])
	first.capabilities.desired_speed[0] = -99.0
	check(float(episode.observe().capabilities.desired_speed[0]) == snapshot_capability,
		"mutating a copied observation does not modify the authoritative descriptor")
	var flat: Dictionary = episode.flat_observation()
	check(str(flat.get("version", "")) == "4ly-flat-observation/v1"
		and int(flat.get("field_count", 0)) == 54 and flat.get("values", []).size() == 54,
		"fixed-order normalized 54-channel policy tensor is available")
	if flat.has("values"):
		for item: Variant in flat.values:
			check(item is float and is_finite(float(item)), "flat feature finite and bounded")
	var initial_tick: int = int(first.observed_tick)
	var budget: int = int(episode.scenario.max_ticks)
	if max_ticks > 0:
		budget = mini(budget, max_ticks)
	while not bool(episode.transition(0).episode_done) and int(episode.transition(0).physical_ticks_total) < budget:
		var state: Dictionary = episode.transition(0)
		var action: Variant = null
		var observation_id: String = ""
		if int(state.physical_ticks_total) % Episode.DECISION_TICKS == 0:
			observation_id = str(episode.observe().observation_id)
			if scenario_id == "power_off" or scenario_id == "neutral_control":
				action = {"move": Vector2.ZERO}
			elif scenario_id == "constant_control":
				action = {"move": Vector2.RIGHT}
			else:
				action = episode.reference_action() if source == &"teacher" else {"move": Vector2.RIGHT}
		var output: Dictionary = episode.tick(action, observation_id, 1)
		check(int(output.ticks_consumed) == 1 or bool(output.failed),
			"accepted input consumes exactly one physical tick before terminal")
		if bool(output.failed):
			break
	var latest: Dictionary = episode.observe()
	var metrics: Dictionary = episode.metrics()
	check(metrics.physical_ticks <= budget and int(latest.observed_tick) == initial_tick + int(metrics.physical_ticks),
		"every reported physics step has exactly one advancing session tick")
	check(metrics.invalid_actions == 0 and not bool(metrics.failed),
		"no failed physical authority or physics in valid scenario: " + str(model) + "/" + scenario_id)
	if bool(episode.transition(0).episode_done):
		check(int(episode.tick().ticks_consumed) == 0, "no post-terminal training transition")
	var evidence: Dictionary = episode.record()
	check(evidence.trace.size() == int(metrics.physical_ticks),
		"full per-tick physical receipt trace retained")
	check(str(evidence.manifest.profile_hash) == str(EXPECTED[str(model)]),
		"profile digest bound into every episode manifest")
	if not evidence.trace.is_empty():
		check(evidence.trace[0].has("physical_receipt") and evidence.trace[0].has("world_tick"),
			"owner receipt with native world tick is preserved, not only counters")
	print("4LY003_DEV_EPISODE ", JSON.stringify(Arena.json_value({
		"manifest": evidence.manifest, "metrics": metrics})))
	results.append({"manifest": evidence.manifest, "metrics": metrics, "trace": evidence.trace})
	return {"metrics": metrics, "initial_position": Vector2(episode.scenario.start),
		"final_position": episode.active_goal() - Vector2(latest.goal_delta_cells),
		"terminal": episode.transition(0), "trace": evidence.trace}


func _run() -> void:
	var started: int = Time.get_ticks_usec()
	check(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"RapierPhysicsServer2D"),
		"real native and Rapier backends required; mocks must NOT pass")
	var registration: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRATION))
	check(registration is Dictionary and int(registration.get("schema_version", 0)) == 1,
		"prospective admission registration present")
	check(Controller.controller_hash() == str(registration.plant_sources.controller_sha256),
		"controller source exactly equals frozen physical identity")
	for model: StringName in Profile.IDS:
		check(Profile.profile_hash(Profile.entry(model)) == str(EXPECTED[str(model)]),
			"measured 4LY-002 immutable profile hash: " + str(model))
	if failures > 0:
		print("4LY003_DEV_RESULT rejected preflight", assertions, failures)
		quit(1)
		return
	var owner := Node2D.new()
	root.add_child(owner)
	episode = Episode.new()
	owner.add_child(episode)
	check(Course.scenario("offset_gates", 0, "development") != Course.scenario("offset_gates", 0, "final"),
		"geometry/start/goal split differs, not a seed-only rename")
	for model: StringName in Profile.IDS:
		var nominal: Dictionary = Course.feasible_clearance(model, "wide_corridor")
		check(bool(nominal.feasible_nominal) and not bool(nominal.clearance_measured),
			"nominal clearance is reported but not mislabeled empirical")
		var row: Dictionary = _run_episode(model, "horizontal_reach", &"teacher")
		if row.is_empty():
			continue
		var hover: Dictionary = _run_episode(model, "unsupported_hover", &"teacher", 300)
		if not hover.is_empty() and bool(hover.terminal.episode_done):
			check(not bool(hover.terminal.navigation_credit), "powered hover cannot earn navigation credit")
	var power: Dictionary = _run_episode(&"4ly_trainer", "power_off", &"teacher", 120)
	if not power.is_empty():
		check(float(power.final_position.y) > float(power.initial_position.y) + 12.0,
			"without propulsion actual gravity makes unsupported chassis descend")
		check(not bool(power.terminal.navigation_credit), "power-off failure is not navigation")
	var neutral: Dictionary = _run_episode(&"4ly_trainer", "neutral_control", &"teacher", 240)
	if not neutral.is_empty():
		check(not bool(neutral.terminal.navigation_credit), "neutral cannot earn distant-target success")
	# A stale issued observation after cancellation must never produce a step.
	check(episode.reset(&"4ly_trainer", "horizontal_reach", 0, "development", &"policy"),
		"fresh owner for action-fencing negative fixture")
	var stale: Dictionary = episode.observe()
	check(episode.arena.cancel(0, &"policy"), "real owner cancels lease and bumps generation")
	var rejected: Dictionary = episode.tick({"move": Vector2.RIGHT}, str(stale.observation_id), 1)
	check(bool(rejected.failed) and int(rejected.ticks_consumed) == 0
		and int(episode.arena.session.tick) == 0 and str(rejected.reason) == "owner_observation_fenced",
		"revoked-observation action cannot move physical body")
	# A malformed two-output command is rejected before any physical step.
	check(episode.reset(&"4ly_trainer", "horizontal_reach"), "fresh owner for schema rejection")
	var invalid: Dictionary = episode.tick({"move": [1.0, INF]}, str(episode.observe().observation_id))
	check(bool(invalid.failed) and int(invalid.ticks_consumed) == 0
		and int(episode.arena.session.tick) == 0,
		"nonfinite action fails closed without consuming a native/Rapier step")
	var stored := FileAccess.open("user://4ly003_development_evidence.json", FileAccess.WRITE)
	if stored != null:
		stored.store_string(JSON.stringify(Arena.json_value({"source":"4ly-003-development-not-final",
			"registration": registration, "results": results}), "\t"))
		stored.close()
	episode.close()
	owner.free()
	await process_frame
	print("4LY003_DEV_RESULT ", JSON.stringify({"assertions": assertions,
		"failures": failures, "elapsed_wall_milliseconds":
		float(Time.get_ticks_usec() - started) / 1000.0,
		"episodes": results.size(), "final_scoring_performed": false}))
	quit(0 if failures == 0 else 1)
