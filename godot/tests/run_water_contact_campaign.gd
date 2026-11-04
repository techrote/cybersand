extends SceneTree

# WATER-CONTACT #362 campaign runner for `water_contact.impact.v1`.
# Not auto-discovered by CI (no test_ prefix). Reproduce with
#   python tools/water_contact/run_campaign.py --godot <console exe> --out <dir> [--stage 1|2]
# or directly:
#   <godot> --headless --path godot --script res://tests/run_water_contact_campaign.gd -- \
#       --out=<absolute dir> --stage=1 --workers=1,4 [--cases=A,B] [--arms=IN3,PF3] [--probes]
# Each run writes one JSON record; a failed or refused run is written, not dropped.

const Apparatus = preload("res://tests/support/water_contact_impact.gd")
const MANIFEST: String = "res://tests/fixtures/water_contact/water_contact.impact.v1.json"

var options: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func parse_options() -> void:
	options = {"stage":2, "workers":"1,4", "cases":"", "arms":"", "out":"", "probes":false, "runs":true}
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--probes":
			options.probes = true
		elif argument == "--probes-only":
			options.probes = true
			options.runs = false
		elif argument.begins_with("--") and argument.contains("="):
			var key: String = argument.substr(2, argument.find("=") - 2)
			options[key] = argument.substr(argument.find("=") + 1)


func write_json(path: String, value: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("WATER_CONTACT: cannot write " + path)
		return false
	file.store_string(JSON.stringify(value, "  ", true) + "\n")
	file.close()
	return true


func run() -> void:
	parse_options()
	var manifest: Dictionary = Apparatus.load_manifest(MANIFEST)
	if not manifest.get("ok", false) or str(options.out).is_empty():
		push_error("WATER_CONTACT: manifest unavailable or --out missing")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(str(options.out))
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var stage: int = int(options.stage)
	var wanted_cases: PackedStringArray = str(options.cases).split(",", false)
	var wanted_arms: PackedStringArray = str(options.arms).split(",", false)
	var workers: Array[int] = []
	for value: String in str(options.workers).split(",", false):
		workers.append(int(value))
	var index: Array = []
	var failures: int = 0
	if bool(options.probes):
		var probes: Array = []
		for arm: Dictionary in manifest.arms:
			if not wanted_arms.is_empty() and not wanted_arms.has(str(arm.id)): continue
			for mode: Dictionary in manifest.kinematic_probe.modes:
				var velocity := Vector2(mode.body_velocity[0], mode.body_velocity[1])
				var probe: Dictionary = Apparatus.kinematic_probe(bridge, manifest, arm, velocity, str(mode.mode))
				probe["probe_id"] = mode.id
				probes.append(probe)
				if not bool(probe.get("ok", false)): failures += 1
				print("WATER_CONTACT_PROBE %s %s ok=%s displaced=%s up=%s carried=%s" % [arm.id, mode.id,
					probe.get("ok"), probe.get("results", {}).get("displaced"), probe.get("relocation_rows_up"),
					probe.get("state_carried_unchanged")])
		write_json(str(options.out).path_join("kinematic_probes.json"), {"schema":"water-contact-kinematic-probes-v1",
			"manifest_sha256":manifest._manifest_sha256, "runtime":Apparatus.runtime_identity(bridge), "probes":probes})
	if bool(options.runs):
		for case: Dictionary in manifest.cases:
			if int(case.get("stage", 2)) > stage: continue
			if not wanted_cases.is_empty() and not wanted_cases.has(str(case.id)): continue
			for arm: Dictionary in manifest.arms:
				if not wanted_arms.is_empty() and not wanted_arms.has(str(arm.id)): continue
				for count: int in workers:
					var started: int = Time.get_ticks_msec()
					var record: Dictionary = await Apparatus.run_case(root, bridge, manifest, case, arm, count)
					record["wall_ms"] = Time.get_ticks_msec() - started
					var name: String = "%s_%s_w%d.json" % [case.id, arm.id, count]
					write_json(str(options.out).path_join(name), record)
					index.append({"file":name, "case":case.id, "arm":arm.id, "workers":count, "ok":record.get("ok", false),
						"violations":(record.get("violations", []) as Array).size(), "error":record.get("error", "")})
					if not bool(record.get("ok", false)): failures += 1
					print("WATER_CONTACT_RUN %s %s w%d ok=%s violations=%d wall_ms=%d" % [case.id, arm.id, count,
						record.get("ok"), (record.get("violations", []) as Array).size(), int(record.wall_ms)])
	write_json(str(options.out).path_join("index.json"), {"schema":"water-contact-campaign-index-v1",
		"manifest_sha256":manifest._manifest_sha256, "stage":stage, "options":options, "runs":index, "failures":failures})
	print("WATER_CONTACT_CAMPAIGN: %d runs; %d failures" % [index.size(), failures])
	quit(1 if failures > 0 else 0)
