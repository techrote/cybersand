extends "res://tests/test_object_shard_worker_scene.gd"

# The exact delivered GUI launcher runs the same real owner scene smoke case.
# Its receipt additionally binds the sealed package and the advertised host.
func _finish(report: Dictionary) -> void:
	var source: String = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	var manifest_path: String = OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	_expect(manifest is Dictionary and manifest.get("source_commit") == source and source.length() == 40,
		"Preflight launcher supplies its verified exact package source")
	_expect(manifest is Dictionary and manifest.get("preflight", {}).get("host") == "standalone-exclusive-worker-rehearsal"
		and manifest.get("preflight", {}).get("production_workbench") == false,
		"Delivered manifest identifies the standalone host without claiming production Workbench integration")
	var receipt: Dictionary = {"schema": "objectshard-worker-package-launch-v1", "source_commit": source,
		"checks": checks, "failures": failures, "manifest_path": manifest_path, "engine": Engine.get_version_info(),
		"host": "standalone-exclusive-worker-rehearsal", "production_workbench": false,
		"tick": report.get("tick", 0), "completed_ticks": report.get("completed_ticks", 0),
		"physical_owner_acceptance": "not established by automated GUI launch qualification"}
	var output: FileAccess = FileAccess.open(OS.get_environment("OBJECTSHARD_LAUNCH_RECEIPT"), FileAccess.WRITE)
	if output == null:
		failures += 1
		push_error("Unable to retain M3 package launch receipt")
	else:
		output.store_string(JSON.stringify(receipt, "  ") + "\n")
		output.close()
	print(JSON.stringify(receipt))
	quit(0 if failures == 0 else 1)
