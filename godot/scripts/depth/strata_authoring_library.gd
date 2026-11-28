extends RefCounted

## Fixed shipped catalogue. Library data is a source proposal, never an owner
## receipt; the existing finite plan/session owns preview, fences and writes.
const Module = preload("res://scripts/depth/strata_native_module.gd")
const Plan = preload("res://scripts/depth/strata_construction_plan.gd")
const DIRECTORY := "res://data/strata2/"
const PARTS := [
	["rear-truss-bay", "Rear truss bay", 128, 80],
	["reactor-window", "Hollow reactor window", 128, 128],
	["service-pipe", "Service pipe elbow", 128, 96],
	["signal-panel", "Signal panel", 64, 96],
	["vent-stack", "Paired vent stack", 96, 128],
	["habitation-lattice", "Habitation light lattice", 128, 128],
	["cargo-cell", "Cargo cell", 128, 96],
	["distant-spire", "Distant service spire", 96, 128]
]
const COMPOSITIONS := [
	["factory-service-bay", "Factory service bay", "Rear truss, cargo, native vent and distant silhouette; four explicit stages."],
	["reactor-service-arch", "Reactor service arch", "Hollow rear reactor, pipe elbow, signal panel and distant truss; four explicit stages."],
	["inhabited-skybridge", "Inhabited skybridge", "Light lattice, two repeated bridge bays, sign and distant spire; five explicit stages."]
]


static func catalogue() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Array in PARTS:
		result.append({"id":item[0], "label":item[1], "extent":[item[2], item[3]],
			"path":DIRECTORY + "modules/" + item[0] + ".json",
			"description":"Exact native grid; transparent cells preserve the target; authored roles and clearances are validated."})
	return result


static func composition_catalogue() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Array in COMPOSITIONS:
		result.append({"id":item[0], "label":item[1], "description":item[2],
			"atmosphere_policy":"Preset atmosphere metadata is a separate proposal. Native stage approval does not apply it."})
	return result


static func module(id: String, admitted: PackedInt32Array) -> Dictionary:
	if not _listed(id, PARTS): return Module.failure("Unknown shipped native part identity.")
	var read := _read(DIRECTORY + "modules/" + id + ".json", Module.MAX_BYTES)
	if not read.ok: return read
	var checked := Module.read_json(read.bytes, admitted)
	if not checked.ok: return checked
	if checked.module.id != id: return Module.failure("Shipped part identity differs from its fixed catalogue entry.")
	return checked


static func composition(id: String, anchor: Vector2i, plane_states: Dictionary,
		admitted: PackedInt32Array) -> Dictionary:
	if not _listed(id, COMPOSITIONS): return Module.failure("Unknown shipped layered composition identity.")
	var read := _read(DIRECTORY + "compositions/" + id + ".json", 256 * 1024)
	if not read.ok: return read
	var raw: Variant = JSON.parse_string(read.bytes.get_string_from_utf8())
	if not Module.keys(raw, ["format", "id", "name", "modules", "stages", "metadata"]) \
			or raw.format != Plan.COMPOSITION_FORMAT or raw.id != id or not raw.modules is Array \
			or raw.modules.is_empty() or raw.modules.size() > PARTS.size() \
			or not raw.stages is Array or raw.stages.is_empty() or raw.stages.size() > Plan.MAX_STAGES:
		return Module.failure("Shipped composition fields, identity or resource bounds are invalid.")
	# JSON numbers are floats in Godot. Canonical integer-valued fields retain
	# their exact value before native ID membership and revision comparisons.
	raw = Module.canonical(raw)
	for stage: Variant in raw.stages:
		if not stage is Dictionary or stage.get("plane") not in ["scripted", "effects", "background"]:
			return Module.failure("Shipped layered presets may target only explicitly selected decorative planes.")
	var selected: Array = []
	var seen: Dictionary = {}
	for part_id: Variant in raw.modules:
		if not part_id is String or seen.has(part_id): return Module.failure("Composition part identities must be unique catalogue entries.")
		var checked := module(part_id, admitted)
		if not checked.ok: return checked
		selected.append(checked.module)
		seen[part_id] = true
	return Plan.from_composition(raw, anchor, selected, plane_states, admitted)


static func fixture_catalogue() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"id":"synthetic-alpha-cutout", "label":"Alpha cutout · synthetic exact-palette fixture",
			"path":DIRECTORY + "imports/alpha-cutout.png",
			"options":{"plane":"scripted", "crop":[0, 0, 64, 48], "origin":[32, 32], "scale":1,
				"transform":"identity", "alpha_mode":"overlay", "alpha_threshold":128,
				"color_distance":0, "unmapped":"refuse",
				"palette":[{"rgb":[64, 80, 96], "material":58, "role":"structure"},
					{"rgb":[32, 192, 224], "material":66, "role":"accent"}]}},
		{"id":"native-reactor-window", "label":"Native reactor window · exact IDs and hollow clearance",
			"path":DIRECTORY + "modules/reactor-window.json",
			"options":{"plane":"scripted", "crop":[0, 0, 128, 128], "origin":[32, 32], "scale":1,
				"transform":"identity", "alpha_mode":"overlay", "alpha_threshold":128,
				"color_distance":0, "unmapped":"refuse", "palette":[]}}
	]
	# Optional exact-source reference fixtures are fixed filenames too. They
	# remain ordinary proposed raster mappings, not accepted native geometry.
	for id: String in ["asteroid-service-gallery", "rocket-hangar-frame"]:
		var path := DIRECTORY + "reference-imports/" + id + ".fixture.json"
		if not FileAccess.file_exists(path): continue
		var read := _read(path, 65536)
		if not read.ok: continue
		var item: Variant = JSON.parse_string(read.bytes.get_string_from_utf8())
		if not Module.keys(item, ["id", "label", "path", "options"]) or item.id != id \
				or not item.label is String or item.label.length() > 160 \
				or not item.path is String or not item.path.begins_with(DIRECTORY + "reference-imports/") \
				or item.path.contains("..") or not item.options is Dictionary or not Module.safe_json(item.options):
			continue
		result.append(item)
	return result


static func _listed(id: String, entries: Array) -> bool:
	for entry: Array in entries:
		if entry[0] == id: return true
	return false


static func _read(path: String, limit: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return Module.failure("Shipped Strata source could not be opened: " + path.get_file())
	var length := file.get_length()
	if length < 1 or length > limit: return Module.failure("Shipped Strata source exceeds its explicit byte budget.")
	var bytes := file.get_buffer(length)
	if bytes.size() != length: return Module.failure("Shipped Strata source was truncated while reading.")
	return {"ok":true, "bytes":bytes, "error":""}
