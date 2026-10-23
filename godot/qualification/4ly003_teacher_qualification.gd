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
const MAX_EPISODE_EVIDENCE_BYTES: int = 8 * 1024 * 1024
const MAX_TOTAL_EVIDENCE_BYTES: int = 512 * 1024 * 1024

var episode: CyberPhysicalFlightEpisode
var evidence_inventory: Array = []
var evidence_bytes: int = 0
var evidence_directory: String = ""
var pass_counts: Dictionary = {}
var faults: Array = []


func _recovery_witness(record: Dictionary) -> bool:
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


func _init() -> void:
	_run.call_deferred()


func _save_episode(record: Dictionary, filename: String) -> Dictionary:
	# Write each complete trace immediately. Never aggregate hundreds of
	# real-physics transitions into an unbounded in-memory JSON list.
	var full: String = evidence_directory.path_join(filename)
	var serialized: String = JSON.stringify(Arena.json_value(record))
	var size: int = serialized.to_utf8_buffer().size()
	if size > MAX_EPISODE_EVIDENCE_BYTES or evidence_bytes + size > MAX_TOTAL_EVIDENCE_BYTES:
		return {"ok": false, "reason": "retained_evidence_capacity"}
	var file: FileAccess = FileAccess.open(full, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "retained_episode_write"}
	file.store_string(serialized)
	file.close()
	if FileAccess.get_file_as_string(full) != serialized:
		return {"ok": false, "reason": "retained_episode_self_readback"}
	evidence_bytes += size
	return {"ok": true, "name": filename, "sha256": serialized.sha256_text(),
		"bytes": size}




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
			or str(admission.get("version", "")) != "4ly003-final-admission/v1" \
			or str(admission.get("reviewer", "")).is_empty() \
			or str(admission.get("source_git_sha", "")) != OS.get_environment("GITHUB_SHA") \
			or OS.get_environment("GITHUB_SHA").is_empty() \
			or str(admission.get("suite_sha256", "")).length() != 64 \
			or not FileAccess.file_exists("user://4ly003_sealed_final_suite.json") \
			or FileAccess.get_file_as_string("user://4ly003_sealed_final_suite.json").sha256_text() != str(admission.get("suite_sha256", "")):
			push_error("4LY003_QUALIFICATION: final sealed; no independently admitted frozen source")
			quit(1)
			return
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"RapierPhysicsServer2D"):
		push_error("4LY003_QUALIFICATION: actual native/Rapier host unavailable")
		quit(1)
		return
	var output_root: String = OS.get_environment("CYBERSAND_PRESENTATION_EVIDENCE")
	if output_root.is_empty():
		output_root = ProjectSettings.globalize_path("user://")
	evidence_directory = output_root.path_join("4ly003-qualified-" + split)
	if DirAccess.make_dir_recursive_absolute(evidence_directory) != OK:
		push_error("4LY003_QUALIFICATION: cannot retain full physical evidence")
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
				var recovery_witness: bool = true
				if str(episode.scenario.family) == "recovery":
					recovery_witness = _recovery_witness(record)
				var qualification_credit: bool = credited and recovery_witness
				var group: String = str(model) + ":" + str(episode.scenario.family)
				var row: Dictionary = pass_counts.get(group, {"trials": 0, "successes": 0,
					"physics_faults": 0, "invalid_actions": 0})
				row.trials += 1
				row.successes += int(qualification_credit)
				row.physics_faults += int(bool(metrics.failed))
				row.invalid_actions += int(metrics.invalid_actions)
				pass_counts[group] = row
				if str(episode.scenario.family) == "recovery" and not recovery_witness:
					faults.append("recovery_without_post_disturbance_contact: "
						+ str(model) + "/" + id + "/" + str(seed))
				if id in Course.NEGATIVE_IDS and credited:
					faults.append("negative_control_navigation_credit: " + str(model) + "/" + id)
				if not no_authority_violation:
					faults.append("failed_step_did_not_complete: " + str(model) + "/" + id)
				var filename: String = str(model) + "_" + id + "_" + str(seed) + ".json"
				var receipt: Dictionary = _save_episode(record, filename)
				if not bool(receipt.get("ok", false)):
					faults.append("retention:" + str(model) + "/" + id + "/" + str(seed)
						+ ":" + str(receipt.get("reason", "unknown")))
				else:
					evidence_inventory.append({"model": str(model), "scenario": id,
						"seed": int(seed), "metrics": metrics.duplicate(true),
						"navigation_credit": credited, "qualification_credit": qualification_credit,
						"recovery_witness": recovery_witness, "artifact": receipt})
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
		"retained_episode_count": evidence_inventory.size(),
		"evidence_bytes": evidence_bytes,
		"prospective_limits": {"max_episodes": MAX_EPISODES,
			"max_per_episode_bytes": MAX_EPISODE_EVIDENCE_BYTES,
			"max_total_bytes": MAX_TOTAL_EVIDENCE_BYTES},
		"sealed_suite_sha256": FileAccess.get_file_as_string("user://4ly003_sealed_final_suite.json").sha256_text() if split == "final" else null,
		"counts": pass_counts, "faults": faults, "godot":
		str(Engine.get_version_info().get("string", "")), "os": OS.get_name(),
		"processor": OS.get_processor_name(), "github_sha": OS.get_environment("GITHUB_SHA"),
		"elapsed_wall_seconds": float(Time.get_ticks_usec() - start_usec) / 1000000.0}
	var evidence: Dictionary = {"summary": summary,
		"complete_episode_sha256_inventory": evidence_inventory}
	var serialized_summary: String = JSON.stringify(Arena.json_value(evidence))
	var path: String = evidence_directory.path_join("summary.json")
	var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		faults.append("summary_artifact_write")
	else:
		out.store_string(serialized_summary)
		out.close()
		if FileAccess.get_file_as_string(path) != serialized_summary:
			faults.append("summary_artifact_self_readback")
	if not faults.is_empty():
		summary["disposition"] = "failed" if split == "final" else "developer_split_physical_failure"
		summary["faults"] = faults.duplicate(true)
		serialized_summary = JSON.stringify(Arena.json_value({"summary": summary,
			"complete_episode_sha256_inventory": evidence_inventory}))
		var corrected: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if corrected != null:
			corrected.store_string(serialized_summary)
			corrected.close()

	print("4LY003_QUALIFICATION ", JSON.stringify(Arena.json_value(summary)))
	episode.close()
	parent.free()
	await process_frame
	quit(1 if not faults.is_empty() or split == "final" and disposition != "qualified" else 0)
