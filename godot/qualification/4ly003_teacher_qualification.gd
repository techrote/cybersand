extends SceneTree

# Explicit-only score runner, intentionally OUTSIDE tests/test_*.gd discovery:
# final geometry is sealed until teacher source hash is independently frozen.
# Usage: --headless --path godot --script res://qualification/4ly003_teacher_qualification.gd -- --split=development
# Final additionally requires --admit-final and a source-bound signed/manual
# teacher-frozen registration in user://4ly003_final_admission.json.
const Episode = preload("res://scripts/physical_flight_episode.gd")
const Course = preload("res://scripts/physical_flight_course.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
const REG = "res://tests/fixtures/4ly003_qualification_registration.json"
const TEACHER_SOURCE = "res://scripts/physical_flight_teacher.gd"
const FINAL_ADMISSION = "user://4ly003_final_admission.json"
const MAX_EPISODES: int = 240

var episode: CyberPhysicalFlightEpisode
var records: Array = []
var pass_counts: Dictionary = {}
var faults: Array = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var split: String = "development"
	for arg: String in args:
		if arg.begins_with("--split="):
			split = arg.trim_prefix("--split=")
	var registration: Variant = JSON.parse_string(FileAccess.get_file_as_string(REG))
	if not registration is Dictionary or not registration.has("splits") or not registration.splits.has(split):
		push_error("4LY003_QUALIFICATION: unknown split or absent preregistration")
		quit(1)
		return
	var frozen_teacher: String = FileAccess.get_file_as_string(TEACHER_SOURCE).sha256_text()
	if split == "final":
		var admission: Variant = JSON.parse_string(FileAccess.get_file_as_string(FINAL_ADMISSION))
		if "--admit-final" not in args or not admission is Dictionary \
			or str(admission.get("teacher_sha256", "")) != frozen_teacher \
			or not bool(admission.get("independent_preflight_accepted", false)) \
			or str(admission.get("source_git_sha", "")).is_empty():
			push_error("4LY003_QUALIFICATION: final sealed; no independently admitted frozen source")
			quit(1)
			return
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"RapierPhysicsServer2D"):
		push_error("4LY003_QUALIFICATION: actual native/Rapier host unavailable")
		quit(1)
		return
	var parent := Node2D.new()
	root.add_child(parent)
	episode = Episode.new()
	parent.add_child(episode)
	var start_usec: int = Time.get_ticks_usec()
	var trials: int = 0
	var ids: Array = registration.splits[split].get("scenario_ids",
		Course.IDS) if split == "development" else Course.IDS
	var seeds: Array = registration.splits[split].seeds
	for model: StringName in Profile.IDS:
		for id: String in ids:
			for seed: Variant in seeds:
				if trials >= MAX_EPISODES:
					faults.append("prospective_episode_budget_exceeded")
					break
				if not episode.reset(model, id, int(seed), split, &"teacher"):
					faults.append("reset: " + str(model) + "/" + id + ": " + episode.last_error)
					continue
				var no_authority_violation: bool = true
				while not bool(episode.transition(0).episode_done):
					var result: Dictionary = episode.transition(0)
					var action: Variant = null
					var issued: String = ""
					if int(result.physical_ticks_total) % Episode.DECISION_TICKS == 0:
						issued = str(episode.observe().observation_id)
						if id in ["neutral_control", "power_off"]:
							action = {"move": Vector2.ZERO}
						elif id == "constant_control":
							action = {"move": Vector2.RIGHT}
						else:
							action = episode.reference_action()
					var stepped: Dictionary = episode.tick(action, issued, 1)
					if bool(stepped.failed) or int(stepped.ticks_consumed) != 1:
						no_authority_violation = false
						faults.append("authority_or_host: " + str(model) + "/" + id
							+ "/" + str(seed) + ": " + str(stepped.reason))
						break
				var record: Dictionary = episode.record()
				var metrics: Dictionary = record.metrics
				var credited: bool = bool(episode.transition(0).navigation_credit)
				var group: String = str(model) + ":" + str(episode.scenario.family)
				var row: Dictionary = pass_counts.get(group, {"trials": 0, "successes": 0,
					"physics_faults": 0, "invalid_actions": 0})
				row.trials += 1
				row.successes += int(credited)
				row.physics_faults += int(bool(metrics.failed))
				row.invalid_actions += int(metrics.invalid_actions)
				pass_counts[group] = row
				if id in Course.NEGATIVE_IDS and credited:
					faults.append("negative_control_navigation_credit: " + str(model) + "/" + id)
				if not no_authority_violation:
					faults.append("failed_step_did_not_complete: " + str(model) + "/" + id)
				records.append(record)
				trials += 1
			if trials >= MAX_EPISODES:
				break
		if trials >= MAX_EPISODES:
			break
	var gates: Dictionary = registration.teacher_gate.per_profile_family_success_rate
	var disposition: String = "developer_split_not_final"
	if split == "final":
		disposition = "qualified" if faults.is_empty() else "failed"
		for model: StringName in Profile.IDS:
			for family: String in gates:
				var row: Dictionary = pass_counts.get(str(model) + ":" + family, {})
				if int(row.get("trials", 0)) < int(registration.teacher_gate.minimum_trials_per_profile_and_family) \
					or float(row.get("successes", 0)) / maxf(1.0, float(row.get("trials", 0))) < float(gates[family]) \
					or int(row.get("invalid_actions", 0)) > 0 or int(row.get("physics_faults", 0)) > 0:
					disposition = "failed"
					faults.append("gate: " + str(model) + "/" + family)
		for model: StringName in Profile.IDS:
			if int(pass_counts.get(str(model) + ":negative", {}).get("successes", 0)) > 0:
				disposition = "failed"
	var summary: Dictionary = {"version": "4ly-teacher-qualification/v1",
		"split": split, "disposition": disposition, "profile_count": Profile.IDS.size(),
		"teacher_sha256": frozen_teacher,
		"registered_gate": registration.teacher_gate, "trials": trials,
		"counts": pass_counts, "faults": faults, "godot":
		str(Engine.get_version_info().get("string", "")), "os": OS.get_name(),
		"processor": OS.get_processor_name(), "github_sha": OS.get_environment("GITHUB_SHA"),
		"elapsed_wall_seconds": float(Time.get_ticks_usec() - start_usec) / 1000000.0}
	var evidence: Dictionary = {"summary": summary,
		"full_physical_episode_records": records}
	var path: String = "user://4ly003_qualification_" + split + ".json"
	var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(Arena.json_value(evidence)))
		out.close()
	var retained_dir: String = OS.get_environment("CYBERSAND_PRESENTATION_EVIDENCE")
	if not retained_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(retained_dir)
		var archive: FileAccess = FileAccess.open(retained_dir.path_join("4ly003_qualification_" + split + ".json"), FileAccess.WRITE)
		if archive != null:
			archive.store_string(JSON.stringify(Arena.json_value(evidence)))
			archive.close()
	print("4LY003_QUALIFICATION ", JSON.stringify(Arena.json_value(summary)))
	episode.close()
	parent.free()
	await process_frame
	quit(1 if not faults.is_empty() or split == "final" and disposition != "qualified" else 0)
