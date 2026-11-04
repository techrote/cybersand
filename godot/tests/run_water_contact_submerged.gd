extends SceneTree

# WATER-CONTACT #362 follow-up runner for `water_contact.submerged.v1`.
# Not auto-discovered by CI. Usage:
#   <godot> --headless --path godot --script res://tests/run_water_contact_submerged.gd -- --out=<abs dir> --stage=1|2
# Every row is written, including failures.

const Apparatus = preload("res://tests/support/water_contact_impact.gd")
const Submerged = preload("res://tests/support/water_contact_submerged.gd")
const MANIFEST: String = "res://tests/fixtures/water_contact/water_contact.submerged.v1.json"


func _initialize() -> void:
	run.call_deferred()


func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "", true) + "\n")
	file.close()


func run() -> void:
	var options: Dictionary = {"stage":2, "out":""}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			options[argument.substr(2, argument.find("=") - 2)] = argument.substr(argument.find("=") + 1)
	var manifest: Dictionary = Apparatus.load_manifest(MANIFEST)
	if not manifest.get("ok", false) or str(options.out).is_empty():
		push_error("WATER_CONTACT_SUBMERGED: manifest unavailable or --out missing")
		quit(2)
		return
	var stage: int = int(options.stage)
	DirAccess.make_dir_recursive_absolute(str(options.out))
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var index: Array = []
	var failures: int = 0
	for arm: Dictionary in manifest.arms:
		var control: Dictionary = Submerged.positive_control(bridge, manifest, arm)
		index.append({"file":"positive_controls.json", "kind":"positive_control", "arm":arm.id, "ok":control.get("ok", false), "detail":control})
		if not bool(control.get("ok", false)): failures += 1
		print("WATER_CONTACT_POSITIVE %s ok=%s predicted=%s actual=%s" % [arm.id, control.get("ok"), control.get("predicted", {}).get("target"), control.get("actual")])
	for case: Dictionary in manifest.dynamic_cases:
		if int(case.stage) > stage: continue
		var spec: Dictionary = case.duplicate()
		var worker_set: Array = manifest.workers
		if (manifest.parity_cases.cases as Array).has(case.id): worker_set = manifest.parity_cases.workers
		for arm_id: String in case.arms:
			var arm: Dictionary = Apparatus.find_by_id(manifest.arms, arm_id)
			for workers: int in worker_set:
				var observer: Variant = Submerged.new(int(manifest.observation.classifier_stride))
				var started: int = Time.get_ticks_msec()
				var record: Dictionary = await Apparatus.run_case(root, bridge, manifest, spec, arm, int(workers), observer)
				record["wall_ms"] = Time.get_ticks_msec() - started
				var ok: bool = bool(record.get("ok", false)) and int(record.get("observer", {}).get("oracle_admissible", 1)) == 0
				record["study_ok"] = ok
				var name: String = "%s_%s_w%d.json" % [case.id, arm_id, int(workers)]
				write_json(str(options.out).path_join(name), record)
				index.append({"file":name, "kind":"dynamic", "ok":ok})
				if not ok: failures += 1
				var obs: Dictionary = record.get("observer", {})
				print("WATER_CONTACT_SUBMERGED %s %s w%d ok=%s residual_max=%s admissible=%s wall_ms=%d" % [case.id, arm_id,
					int(workers), ok, obs.get("max_residual"), obs.get("oracle_admissible"), int(record.wall_ms)])
	for descent: Dictionary in manifest.kinematic_descents:
		if int(descent.stage) > stage: continue
		var size: Array = descent.get("body_size", manifest.body.size)
		for arm_id: String in descent.arms:
			var arm: Dictionary = Apparatus.find_by_id(manifest.arms, arm_id)
			var result: Dictionary = Submerged.kinematic_descent(bridge, manifest, arm, int(descent.depth), float(descent.rate),
				bool(descent.tick_liquid), Vector2(size[0], size[1]))
			result["descent_id"] = descent.id
			result["manifest_sha256"] = manifest._manifest_sha256
			result["runtime"] = Apparatus.runtime_identity(bridge)
			var name: String = "%s_%s.json" % [descent.id, arm_id]
			write_json(str(options.out).path_join(name), result)
			index.append({"file":name, "kind":"kinematic", "ok":result.get("ok", false)})
			if not bool(result.get("ok", false)): failures += 1
			print("WATER_CONTACT_DESCENT %s %s ok=%s deepest_relocating_top=%s admissible=%s" % [descent.id, arm_id,
				result.get("ok"), result.get("deepest_relocating_body_top"), result.get("observer", {}).get("oracle_admissible")])
	write_json(str(options.out).path_join("index.json"), {"schema":"water-contact-submerged-index-v1",
		"manifest_sha256":manifest._manifest_sha256, "stage":stage, "rows":index, "failures":failures})
	print("WATER_CONTACT_SUBMERGED_CAMPAIGN: %d rows; %d failures" % [index.size(), failures])
	quit(1 if failures > 0 else 0)
