extends SceneTree

const Scenes = preload("res://scripts/depth/strata_optical_showcase_scenes.gd")
const Existing = preload("res://scripts/depth/strata_showcase_scenes.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	check(Scenes.ids().size() == 3, "three substantial native compositions are available")
	for id: String in Scenes.ids():
		var path := "res://data/strata3/" + id + ".json"
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(Scenes.validate_source(raw, id).is_empty(), id + " native source validates")
		check(not Scenes.metadata(id).has("error"), id + " metadata is inspectable")
		check(raw.extent[0] >= 1024 and raw.extent[1] >= 768, id + " substantial ordinary canvas extent")
		check(raw.provenance.source_art == "none" and raw.provenance.generator == Scenes.GENERATOR, id + " provenance is explicit original native construction")
		var built := Scenes.make(id, PackedInt32Array([1]))
		check(not built.has("error"), id + " prepares the existing Setup/document pair: " + str(built.get("error", "")))
		if not built.has("error"):
			check(built.setup.actors.size() == 1, id + " contains one ordinary Play actor declaration")
			check(built.document.planes.size() == 4, id + " retains exactly four existing planes")
			check(built.source_metadata.provenance == raw.provenance, id + " builder preserves true source provenance")
		check(not Existing.validate_source(raw, id).is_empty(), id + " cannot impersonate the retained five-scene catalogue")
		for field: String in ["id", "generator", "generator_version", "geometry"]:
			var bad := raw.duplicate(true)
			match field:
				"id": bad.id = "orbital-terminal"
				"generator": bad.provenance.generator = "tools/strata2_build_showcases.py"
				"generator_version": bad.provenance.generator_version = 2
				"geometry": bad.play_rectangles[0][2] += 1
			check(not Scenes.validate_source(bad, id).is_empty(), id + " refuses changed " + field + " identity")
	check(Scenes.make("../escape", PackedInt32Array([1])).has("error"), "unknown identities cannot read arbitrary files")
	print("STRATA_OPTICAL_SHOWCASES ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
