extends RefCounted

# 4LY-003 prospectively bounded DEVELOPMENT split exercise, not final scoring.
# These cases execute the real CyberPhysicalActorArena native/Rapier engine.
# The complete per-tick trace of every failed and successful case is written
# separately, avoiding unbounded aggregation in the runner's memory.
const Episode = preload("res://scripts/physical_flight_episode.gd")
const Course = preload("res://scripts/physical_flight_course.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
const Controller = preload("res://scripts/physical_flight_controller.gd")
const REG = "res://tests/fixtures/4ly003_qualification_registration.json"
const SPLIT: String = "development"
const SEED: int = 101
const MAX_EPISODES: int = 40
const MAX_TOTAL_TICKS: int = 80000
const FREE_CASES: Array[String] = [
	"unsupported_hover", "horizontal_reach", "vertical_reach",
	"diagonal_reach", "reverse", "arrival_braking", "neutral_control",
	"constant_control", "power_off"
]
const OBSTACLE_CASES: Array[String] = [
	"wide_corridor", "offset_gates", "corner", "slalom", "wall_recovery"
]


static func _archive_dir(group: String) -> String:
	var base: String = OS.get_environment("CYBERSAND_PRESENTATION_EVIDENCE")
	if base.is_empty():
		base = ProjectSettings.globalize_path("user://")
	var destination: String = base.path_join("4ly003-dev-" + group)
	return destination if DirAccess.make_dir_recursive_absolute(destination) == OK else ""


static func _save(directory: String, filename: String, value: Dictionary) -> Dictionary:
	var destination: String = directory.path_join(filename)
	var serialized: String = JSON.stringify(Arena.json_value(value))
	var handle: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if handle == null:
		return {"ok": false, "error": "write: " + filename}
	handle.store_string(serialized)
	handle.close()
	# Self-readback is a local integrity check only; independent CI admission
	# review must read retained uploaded artifacts separately.
	var received: String = FileAccess.get_file_as_string(destination)
	if received != serialized:
		return {"ok": false, "error": "write_readback_mismatch: " + filename}
	return {"ok": true, "name": filename, "sha256": serialized.sha256_text(),
		"bytes": serialized.to_utf8_buffer().size()}


static func _recovery_witness(record: Dictionary) -> bool:
	var disturbance_tick: int = -1
	for sample: Variant in record.get("trace", []):
		if not sample is Dictionary:
			continue
		var receipt: Variant = sample.get("host_disturbance", {})
		if receipt is Dictionary and bool(receipt.get("accepted", false)):
			disturbance_tick = int(sample.get("tick", -1))
			break
	if disturbance_tick < 0:
		return false
	for sample: Variant in record.get("trace", []):
		if sample is Dictionary and int(sample.get("tick", -1)) >= disturbance_tick \
			and bool(sample.get("contact", false)):
			return true
	return false


static func run(root_node: Node, group: String) -> Dictionary:
	var scenario_ids: Array[String] = FREE_CASES if group == "free" else OBSTACLE_CASES
	var failed: Array[String] = []
	if group not in ["free", "obstacle"]:
		return {"ok": false, "errors": ["unknown_group"]}
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"RapierPhysicsServer2D"):
		return {"ok": false, "errors": ["actual_native_or_rapier_unavailable"]}
	var registration: Variant = JSON.parse_string(FileAccess.get_file_as_string(REG))
	if not registration is Dictionary:
		return {"ok": false, "errors": ["registration_unreadable"]}
	if int(registration.get("schema_version", -1)) != 1 \
		or not registration.has("plant_sources") or not registration.has("splits"):
		return {"ok": false, "errors": ["registration_schema"]}
	if Controller.controller_hash() != str(registration.plant_sources.controller_sha256):
		return {"ok": false, "errors": ["controller_hash_changed"]}
	for model: StringName in Profile.IDS:
		var actual_hash: String = Profile.profile_hash(Profile.entry(model))
		if actual_hash != str(registration.plant_sources.profiles.get(str(model), "")):
			failed.append("profile_identity:" + str(model))
	for scenario_id: String in scenario_ids:
		if Course.scenario(scenario_id, SEED, SPLIT).is_empty():
			failed.append("unregistered_scenario:" + scenario_id)
	if not failed.is_empty():
		return {"ok": false, "errors": failed}
	var dir: String = _archive_dir(group)
	if dir.is_empty():
		return {"ok": false, "errors": ["retained_evidence_directory_unavailable"]}
	var env := Episode.new()
	root_node.add_child(env)
	var results: Array = []
	var digest_inventory: Array = []
	var family_counts: Dictionary = {}
	var episodes: int = 0
	var consumed: int = 0
	var pass_count: int = 0
	var failures: int = 0
	var start_us: int = Time.get_ticks_usec()
	for model: StringName in Profile.IDS:
		for scenario_id: String in scenario_ids:
			if episodes >= MAX_EPISODES or consumed >= MAX_TOTAL_TICKS:
				failed.append("prospective_budget_exhaustion")
				break
			var scenario: Dictionary = Course.scenario(scenario_id, SEED, SPLIT)
			var max_ticks: int = int(scenario.max_ticks)
			if consumed + max_ticks > MAX_TOTAL_TICKS:
				failed.append("maximum_declared_tick_budget")
				break
			if not env.reset(model, scenario_id, SEED, SPLIT, &"teacher"):
				failed.append("reset:" + str(model) + ":" + scenario_id + ":" + env.last_error)
				break
			while not bool(env.transition(0).episode_done):
				var current: Dictionary = env.transition(0)
				var requested: Variant = null
				var observation_id: String = ""
				if int(current.physical_ticks_total) % Episode.DECISION_TICKS == 0:
					observation_id = str(env.observe().observation_id)
					if scenario_id in ["neutral_control", "power_off"]:
						requested = {"move": Vector2.ZERO}
					elif scenario_id == "constant_control":
						requested = {"move": Vector2.RIGHT}
					else:
						requested = env.reference_action()
				var next: Dictionary = env.tick(requested, observation_id, 1)
				consumed += int(next.ticks_consumed)
				if int(next.ticks_consumed) != 1 and not bool(next.episode_done):
					failed.append("nonterminal_zero_tick:" + str(model) + ":" + scenario_id)
					break
				if bool(next.failed):
					failed.append("physics_or_authority:" + str(model) + ":" + scenario_id + ":" + str(next.reason))
					break
				if consumed > MAX_TOTAL_TICKS:
					failed.append("absolute_tick_budget")
					break
			var record: Dictionary = env.record()
			var metrics: Dictionary = record.metrics
			var credit: bool = bool(env.transition(0).navigation_credit)
			var recovery_witness: bool = true
			if str(scenario.family) == "recovery":
				recovery_witness = _recovery_witness(record)
			var qualification_credit: bool = credit and recovery_witness
			var category: String = str(model) + ":" + str(scenario.family)
			var counter: Dictionary = family_counts.get(category,
				{"attempted": 0, "successful": 0, "failed_physics": 0, "invalid_actions": 0})
			counter.attempted += 1
			counter.successful += int(qualification_credit)
			counter.failed_physics += int(bool(metrics.failed))
			counter.invalid_actions += int(metrics.invalid_actions)
			family_counts[category] = counter
			if str(scenario.family) == "recovery" and not recovery_witness:
				failed.append("recovery_without_post_disturbance_contact:" + str(model))
			if scenario_id in Course.NEGATIVE_IDS and credit:
				failed.append("negative_control_received_navigation_credit:" + str(model))
			if not bool(metrics.failed):
				pass_count += int(qualification_credit)
			else:
				failures += 1
			var filename: String = str(model) + "_" + scenario_id + "_" + str(SEED) + ".json"
			var inventory: Dictionary = _save(dir, filename, record)
			if not bool(inventory.get("ok", false)):
				failed.append(str(inventory.get("error", "unknown_evidence_io")))
			else:
				digest_inventory.append(inventory)
			results.append({"model": str(model), "scenario": scenario_id,
				"family": str(scenario.family), "seed": SEED,
				"navigation_credit": credit, "qualification_credit": qualification_credit,
				"recovery_witness": recovery_witness, "metrics": metrics,
				"trace_sha256": inventory.get("sha256", null),
				"trace_filename": inventory.get("name", "")})
			episodes += 1
		if not failed.is_empty():
			break
	var summary: Dictionary = {
		"schema": "4ly003-development-family-pilot/v1",
		"claim": "real native/Rapier source-bound development split; not sealed final qualification",
		"split": SPLIT, "seed": SEED, "group": group,
		"registration_path": REG,
		"teacher_source_sha256": FileAccess.get_file_as_string("res://scripts/physical_flight_teacher.gd").sha256_text(),
		"godot": str(Engine.get_version_info().get("string", "")),
		"os": OS.get_name(), "cpu": OS.get_processor_name(),
		"github_sha": OS.get_environment("GITHUB_SHA"),
		"physics_hz": 60, "decision_ticks": Episode.DECISION_TICKS,
		"episodes": episodes, "prospective_episode_limit": MAX_EPISODES,
		"prospective_physics_tick_limit": MAX_TOTAL_TICKS,
		"physical_ticks": consumed, "navigation_successes": pass_count,
		"physics_failures": failures, "family_counts": family_counts,
		"results": results, "digest_inventory": digest_inventory,
		"errors": failed, "final_split_opened": false,
		"elapsed_wall_seconds": float(Time.get_ticks_usec() - start_us) / 1000000.0
	}
	var manifest: Dictionary = _save(dir, "summary.json", summary)
	if not bool(manifest.get("ok", false)):
		failed.append("summary_readback_failed")
	env.close()
	env.free()
	return {"ok": failed.is_empty(), "summary": summary, "errors": failed,
		"evidence_directory": dir, "summary_sha256": manifest.get("sha256", "")}
