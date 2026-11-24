extends RefCounted

# Three small explicit native-material examples. They do not import a research
# generator, texture corpus or unaccepted nomination. All geometry is ordinary
# axis-aligned material rectangles; the same native palette draws every plane.
const Setup = preload("res://scripts/workbench_setup.gd")
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const Showcase = preload("res://scripts/depth/strata_showcase_scenes.gd")
const IDS: Array[String] = ["industrial-assembly", "arcology", "cavern"]

static func ids() -> Array[String]:
	var result := IDS.duplicate()
	result.append_array(Showcase.ids())
	return result

static func make(id: String, policy: PackedInt32Array) -> Dictionary:
	if id in Showcase.IDS: return Showcase.make(id, policy)
	if id not in IDS: return {"error":"Unknown Strata example"}
	var path: String = "res://data/strata/" + id + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return {"error":"Could not read Strata example: " + id}
	if parsed.get("format") != "cybersand-strata-example" or parsed.get("version") != 1 or parsed.get("id") != id:
		return {"error":"Unsupported Strata example identity"}
	var extent := Vector2i(int(parsed.extent[0]), int(parsed.extent[1]))
	var setup: Dictionary = Setup.fresh(policy, extent)
	setup.edits = _rectangles(parsed.play_rectangles)
	setup.material = Setup.WALL
	setup.brush = 4
	setup.actors = [Setup.instance(Setup.Fleet.stable_id(0), 1, Vector2(parsed.spawn[0], parsed.spawn[1]))]
	setup.selected = 1
	setup.next_id = 2
	var document: Dictionary = Document.default_document(extent)
	document.presentation.enabled = true
	document.presentation.mode = "stack"
	document.presentation.fog_strength = float(parsed.presentation.fog_strength)
	document.presentation.parallax_strength = float(parsed.presentation.parallax_strength)
	for plane: Dictionary in document.planes:
		var plane_id: String = str(plane.id)
		if plane_id == "play": continue
		plane.rectangles = _rectangles(parsed.planes[plane_id].rectangles)
		plane.depth = float(parsed.planes[plane_id].depth)
		plane.opacity = float(parsed.planes[plane_id].opacity)
	var reason: String = Setup.validate(setup)
	if not reason.is_empty(): return {"error":"Strata play layout refused: " + reason}
	reason = Document.validate(document)
	if not reason.is_empty(): return {"error":"Strata layer layout refused: " + reason}
	return {"setup":setup, "document":document, "title":str(parsed.title),
		"description":str(parsed.description), "id":id}

static func _rectangles(raw: Array) -> Array:
	var result: Array = []
	for row: Array in raw:
		result.append([int(row[0]), int(row[1]), int(row[2]), int(row[3]), int(row[4])])
	return result
