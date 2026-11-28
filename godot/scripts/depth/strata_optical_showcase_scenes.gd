extends RefCounted

## Original optical-composition research scenes. They use the same four native
## owners and strict authored recipe admission as the retained Strata 002 corpus.
const Recipes = preload("res://scripts/depth/strata_showcase_scenes.gd")
const IDS: Array[String] = ["sunward-freight-megastructure", "xeno-resonance-grotto", "lunar-terminator-observatory"]
const GENERATOR := "tools/strata3_build_showcases.py"


static func ids() -> Array[String]:
	return IDS.duplicate()


static func metadata(id: String) -> Dictionary:
	var raw := _read(id)
	if raw.has("error"): return raw
	return {"id":id, "title":raw.title, "description":raw.description,
		"extent":raw.extent.duplicate(), "spawn":raw.spawn.duplicate(),
		"route_probes":raw.route_probes.duplicate(true), "detail_views":raw.detail_views.duplicate(true),
		"provenance":raw.provenance.duplicate(true)}


static func make(id: String, policy: PackedInt32Array) -> Dictionary:
	var raw := _read(id)
	if raw.has("error"): return raw
	# Classic remains the safe authored optical default. The owner selects an
	# optical profile explicitly in the integrated Lab after scene admission.
	return Recipes.make_source(raw, id, policy, IDS, GENERATOR, 1)


static func validate_source(raw: Variant, expected_id: String) -> String:
	return Recipes.validate_source(raw, expected_id, IDS, GENERATOR, 1)


static func _read(id: String) -> Dictionary:
	if id not in IDS: return {"error":"Unknown Strata optical showcase identity."}
	var file := FileAccess.open("res://data/strata3/" + id + ".json", FileAccess.READ)
	if file == null or file.get_length() < 1 or file.get_length() > Recipes.SOURCE_LIMIT:
		return {"error":"Could not read bounded optical showcase: " + id}
	var raw: Variant = JSON.parse_string(file.get_as_text())
	var reason := validate_source(raw, id)
	if not reason.is_empty(): return {"error":reason}
	return raw
