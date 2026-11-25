extends RefCounted

## Source-pinned native authored recipes. The ordinary Workbench remains the
## only Play host; this registry merely prepares the existing candidate pair.
const Setup = preload("res://scripts/workbench_setup.gd")
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const Profiles = preload("res://scripts/depth/strata_atmosphere_profiles.gd")
const IDS: Array[String] = ["orbital-terminal", "neon-rain-arcology", "industrial-underworks", "abyss-foundry", "vertical-transfer-spine"]
const ROOT_KEYS := ["format", "version", "id", "title", "description", "extent", "spawn", "presentation", "play_rectangles", "planes", "atmosphere", "route_probes", "detail_views", "provenance"]
const SOURCE_LIMIT := 2 * 1024 * 1024


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
	return make_source(raw, id, policy)


static func make_source(raw: Dictionary, id: String, policy: PackedInt32Array,
		admitted_ids: Array = IDS, generator_path: String = "tools/strata2_build_showcases.py",
		maximum_generator_version: int = 2) -> Dictionary:
	# Additional source-pinned catalogues reuse the exact same native admission
	# contract with explicit identities. Original catalogue defaults stay strict.
	var source_reason := validate_source(raw, id, admitted_ids, generator_path, maximum_generator_version)
	if not source_reason.is_empty(): return {"error":source_reason}
	var extent := Vector2i(int(raw.extent[0]), int(raw.extent[1]))
	var setup := Setup.fresh(policy, extent)
	setup.edits = raw.play_rectangles.duplicate(true)
	setup.material = Setup.WALL
	setup.brush = 4
	setup.actors = [Setup.instance(Setup.Fleet.stable_id(0), 1, Vector2(float(raw.spawn[0]), float(raw.spawn[1])))]
	setup.selected = 1
	setup.next_id = 2
	var reason := Setup.validate(setup)
	if not reason.is_empty(): return {"error":"Showcase Play layout refused: " + reason}
	var document := Document.default_document(extent)
	if not document.has("atmosphere"):
		return {"error":"This showcase requires the explicit Strata v2 atmosphere document."}
	document.presentation.enabled = true
	document.presentation.mode = "stack"
	document.presentation.fog_strength = float(raw.presentation.fog_strength)
	document.presentation.parallax_strength = float(raw.presentation.parallax_strength)
	document.atmosphere = Profiles.canonical(raw.atmosphere)
	for plane: Dictionary in document.planes:
		var plane_id := str(plane.id)
		if plane_id == "play": continue
		plane.rectangles = raw.planes[plane_id].rectangles.duplicate(true)
		plane.depth = float(raw.planes[plane_id].depth)
		plane.opacity = float(raw.planes[plane_id].opacity)
	reason = Document.validate(document)
	if not reason.is_empty(): return {"error":"Showcase layer layout refused: " + reason}
	return {"setup":setup, "document":document, "title":str(raw.title),
		"description":str(raw.description), "id":id,
		"source_metadata":{"id":id, "title":raw.title, "description":raw.description,
			"extent":raw.extent.duplicate(), "spawn":raw.spawn.duplicate(),
			"route_probes":raw.route_probes.duplicate(true), "detail_views":raw.detail_views.duplicate(true),
			"provenance":raw.provenance.duplicate(true)}}


static func _read(id: String) -> Dictionary:
	if id not in IDS: return {"error":"Unknown Strata showcase identity."}
	var path := "res://data/strata2/" + id + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 1 or file.get_length() > SOURCE_LIMIT:
		return {"error":"Could not read bounded Strata showcase: " + id}
	var raw: Variant = JSON.parse_string(file.get_as_text())
	var reason := validate_source(raw, id)
	if not reason.is_empty(): return {"error":reason}
	return raw


static func validate_source(raw: Variant, expected_id: String, admitted_ids: Array = IDS,
		generator_path: String = "tools/strata2_build_showcases.py", maximum_generator_version: int = 2) -> String:
	if not _keys(raw, ROOT_KEYS) or raw.format != "cybersand-strata-showcase" \
			or not Setup._integer(raw.version, 1, 1) or raw.id != expected_id or expected_id not in admitted_ids:
		return "Unsupported showcase fields, version or identity."
	if not raw.title is String or raw.title.is_empty() or raw.title.length() > 128 \
			or not raw.description is String or raw.description.length() > 2048:
		return "Showcase title or description is invalid."
	if not raw.extent is Array or raw.extent.size() != 2:
		return "Showcase extent requires two admitted dimensions."
	for side: Variant in raw.extent:
		if not Setup._integer(side, 512, 2048) or int(side) % 64 != 0:
			return "Showcase extent must remain within ordinary Workbench bounds."
	var extent := Vector2i(int(raw.extent[0]), int(raw.extent[1]))
	if not _point(raw.spawn, extent): return "Showcase spawn must remain inside its native extent."
	if not _keys(raw.presentation, ["fog_strength", "parallax_strength"]) \
			or not Setup._number(raw.presentation.fog_strength, 0.0, 1.0) \
			or not Setup._number(raw.presentation.parallax_strength, 0.0, 1.0):
		return "Showcase presentation settings are invalid."
	if not _keys(raw.planes, ["scripted", "effects", "background"]):
		return "Showcase requires exactly three explicit decorative planes."
	var reason := _rectangles(raw.play_rectangles, extent)
	if not reason.is_empty(): return "Showcase Play recipe: " + reason
	for plane_id: String in ["scripted", "effects", "background"]:
		var plane: Variant = raw.planes[plane_id]
		if not _keys(plane, ["depth", "opacity", "rectangles"]) \
				or not Setup._number(plane.depth, -1.0, 1.0) or not Setup._number(plane.opacity, 0.0, 1.0):
			return "Showcase plane fields or presentation limits are invalid."
		reason = _rectangles(plane.rectangles, extent)
		if not reason.is_empty(): return "Showcase " + plane_id + " recipe: " + reason
	reason = Profiles.validate(raw.atmosphere, extent)
	if not reason.is_empty(): return reason
	if not raw.route_probes is Array or raw.route_probes.size() > 8:
		return "Showcase has too many route proposals."
	for probe: Variant in raw.route_probes:
		if not _keys(probe, ["id", "from", "to", "clearance_radius", "claim", "generator_clearance_check"]) \
				or not probe.id is String or probe.id.length() > 80 \
				or not _point(probe.from, extent) or not _point(probe.to, extent) \
				or not Setup._integer(probe.clearance_radius, 1, 96) \
				or not probe.claim is String or probe.claim.length() > 512 \
				or not probe.generator_clearance_check is String or probe.generator_clearance_check.length() > 512:
			return "Showcase route metadata is invalid."
	if not raw.detail_views is Array or raw.detail_views.size() > 8:
		return "Showcase has too many detail viewpoints."
	for view: Variant in raw.detail_views:
		if not _keys(view, ["id", "center", "zoom"]) or not view.id is String or view.id.length() > 80 \
				or not _point(view.center, extent) or not Setup._number(view.zoom, 0.1, 8.0):
			return "Showcase detail viewpoint is invalid."
	if not _keys(raw.provenance, ["kind", "generator", "generator_version", "seed", "source_art", "geometry_semantics", "physical_claim", "plane_roles", "plane_geometry_sha256", "ordered_rectangles", "authored_write_cells"]):
		return "Showcase provenance fields are unsupported."
	if raw.provenance.kind != "original-native-material-construction" \
			or raw.provenance.generator != generator_path \
			or not Setup._integer(raw.provenance.generator_version, 1, maximum_generator_version) \
			or not Setup._integer(raw.provenance.seed, 0, 2147483647) \
			or raw.provenance.source_art != "none":
		return "Showcase provenance identity is invalid."
	for key: String in ["geometry_semantics", "physical_claim"]:
		if not raw.provenance[key] is String or raw.provenance[key].length() > 512:
			return "Showcase provenance statement is invalid."
	for key: String in ["plane_roles", "plane_geometry_sha256", "ordered_rectangles", "authored_write_cells"]:
		if not _keys(raw.provenance[key], ["play", "scripted", "effects", "background"]):
			return "Showcase provenance must identify every plane."
	for plane_id: String in ["play", "scripted", "effects", "background"]:
		var rows: Array = raw.play_rectangles if plane_id == "play" else raw.planes[plane_id].rectangles
		var canonical: Array = []
		var cells := 0
		for row: Array in rows:
			canonical.append(Array(PackedInt32Array(row)))
			cells += int(row[2]) * int(row[3])
		if not raw.provenance.plane_roles[plane_id] is String or raw.provenance.plane_roles[plane_id].length() > 256 \
				or raw.provenance.plane_geometry_sha256[plane_id] != JSON.stringify(canonical).sha256_text() \
				or not Setup._integer(raw.provenance.ordered_rectangles[plane_id], rows.size(), rows.size()) \
				or not Setup._integer(raw.provenance.authored_write_cells[plane_id], cells, cells):
			return "Showcase recipe provenance does not match the authored rows."
	return ""


static func _rectangles(value: Variant, extent: Vector2i) -> String:
	if not value is Array or value.size() > Document.MAX_RECTANGLES: return "Rectangle budget exceeded."
	var writes := 0
	for row: Variant in value:
		if not row is Array or row.size() != 5 or not Setup._stamp_valid(row, extent):
			return "Unsupported native material rectangle."
		if int(row[0]) < 1 or int(row[1]) < 1 or int(row[0]) + int(row[2]) >= extent.x \
				or int(row[1]) + int(row[3]) >= extent.y:
			return "Showcase rectangle reaches the protected native boundary."
		writes += int(row[2]) * int(row[3])
		if writes > Document.MAX_LAYOUT_WRITES: return "Authored write-cell budget exceeded."
	return ""


static func _point(value: Variant, extent: Vector2i) -> bool:
	return value is Array and value.size() == 2 and Setup._number(value[0], 1, extent.x - 2) \
		and Setup._number(value[1], 1, extent.y - 2)


static func _keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key: Variant in value:
		if not key is String or key not in keys: return false
	return value.has_all(keys)
