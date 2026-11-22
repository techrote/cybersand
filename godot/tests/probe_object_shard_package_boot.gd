extends SceneTree

# Executed by the *shipped* Windows launcher, including its GUI executable and
# argument parsing. This is a short real-World/Rapier smoke test, not a claim of
# owner playability or a substitute for the complete native/host qualification.
const Session = preload("res://scripts/object_shard_lab_session.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)


func _run() -> void:
	var source: String = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	var manifest_path: String = OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	_expect(manifest is Dictionary and str(manifest.get("source_commit", "")) == source and source.length() == 40,
		"Launcher supplies the verified package source identity")
	_expect(ClassDB.class_exists(&"CyberObjectShardLab"), "Bundled native extension loads")
	var session = Session.new()
	if ClassDB.class_exists(&"CyberObjectShardLab"):
		_expect(session.open(1, 12).get("ok", false), "Bundled Lab and Rapier initialize")
		if not session.failed:
			var width: int = int(session.frame.width)
			var materials: PackedByteArray = session.frame.world_materials
			var lowest: int = -1
			for i: int in range(materials.size()):
				if int(materials[i]) == 7:
					lowest = maxi(lowest, i / width)
			var edits: int = 0
			if lowest >= 0:
				for y: int in range(maxi(0, lowest - 11), lowest + 1):
					for x: int in range(width):
						if int(materials[y * width + x]) == 7:
							if session.edit(Vector2i(x, y), 0).get("ok", false):
								edits += 1
			_expect(edits > 0, "Ordinary native support mutation executes")
			for tick: int in range(40):
				session.advance(true)
				if session.failed:
					break
			_expect(not session.failed and session.bridge.bodies.size() > 0,
				"Real native promotion activates a Rapier body")
			_expect(int(session.frame.get("tick", 0)) >= 40, "Bundled Lab advances both clocks")
	var receipt: Dictionary = {"schema": "objectshard-package-launch-v1", "source_commit": source,
		"manifest_path": manifest_path, "engine": Engine.get_version_info(),
		"checks": checks, "failures": failures, "tick": session.frame.get("tick", 0),
		"physics": session.bridge.timings if session.bridge != null else {},
		"physical_owner_acceptance": "not established by launch qualification"}
	var receipt_path: String = OS.get_environment("OBJECTSHARD_LAUNCH_RECEIPT")
	var stream: FileAccess = FileAccess.open(receipt_path, FileAccess.WRITE)
	if stream == null:
		failures += 1
		push_error("Unable to retain package launch receipt")
	else:
		stream.store_string(JSON.stringify(receipt, "\t") + "\n")
		stream.close()
	session.close()
	quit(0 if failures == 0 else 1)
