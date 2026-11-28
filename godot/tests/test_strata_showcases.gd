extends SceneTree

const Scenes = preload("res://scripts/depth/strata_showcase_scenes.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var source_only := "--source-only" in OS.get_cmdline_user_args()
	for id: String in Scenes.ids():
		var path := "res://data/strata2/" + id + ".json"
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(Scenes.validate_source(raw, id).is_empty(), id + " source validates")
		check(not Scenes.metadata(id).has("error"), id + " inspected metadata validates")
		check(raw.provenance.source_art == "none", id + " has honest original native provenance")
		check(raw.route_probes.size() >= 1 and raw.detail_views.size() >= 1, id + " includes route and actual-capture viewpoints")
		var bad := raw.duplicate(true)
		bad.unrecognized_layer = []
		check(not Scenes.validate_source(bad, id).is_empty(), id + " unknown root refused")
		bad = raw.duplicate(true)
		bad.extent[0] = 2049
		check(not Scenes.validate_source(bad, id).is_empty(), id + " unsupported extent refused")
		bad = raw.duplicate(true)
		bad.planes.scripted.rectangles[0][4] = 255
		check(not Scenes.validate_source(bad, id).is_empty(), id + " unadmitted native material refused")
		bad = raw.duplicate(true)
		bad.planes.scripted.rectangles[0][0] = 0
		check(not Scenes.validate_source(bad, id).is_empty(), id + " protected boundary refused")
		bad = raw.duplicate(true)
		bad.provenance.plane_geometry_sha256.play = "wrong"
		check(not Scenes.validate_source(bad, id).is_empty(), id + " stale recipe digest refused")
		bad = raw.duplicate(true)
		bad.provenance.generator_version = 3
		check(not Scenes.validate_source(bad, id).is_empty(), id + " unknown future recipe generator refused")
		bad = raw.duplicate(true)
		bad.provenance.generator_version = 1
		check(Scenes.validate_source(bad, id).is_empty(), id + " previous generator provenance remains readable")
		bad = raw.duplicate(true)
		bad.atmosphere.effects[0].plane = "play"
		check(not Scenes.validate_source(bad, id).is_empty(), id + " Play visual target refused")
		if not source_only:
			var prepared := Scenes.make(id, PackedInt32Array([1]))
			check(not prepared.has("error"), id + " ordinary Setup and v2 document pair validates: " + str(prepared.get("error", "")))
			if not prepared.has("error"):
				check(prepared.setup.actors.size() == 1 and prepared.setup.actors[0].id == 1, id + " has one ordinary actor declaration")
	check(Scenes.metadata("../escape").has("error"), "catalogue identity prevents arbitrary source access")
	print("STRATA_SHOWCASES ", JSON.stringify({"checks":checks,"failures":failures,"source_only":source_only}))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
