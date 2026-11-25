extends RefCounted

## Strata's authored scene envelope. Play remains an unchanged Workbench start;
## three decorative layouts use existing native material IDs and rectangle
## semantics. This is never a four-World continuation or an implicit Flatten.
const Setup = preload("res://scripts/workbench_setup.gd")
const GeneratedMaps = preload("res://scripts/workbench_generated_map.gd")
const MaterialBaseline = preload("res://scripts/workbench_material_baseline.gd")
const Atmosphere = preload("res://scripts/depth/strata_atmosphere_profiles.gd")
const Provenance = preload("res://scripts/depth/strata_authoring_provenance.gd")
const Optics = preload("res://scripts/depth/strata_optics_configuration.gd")
const IDS := ["play", "scripted", "effects", "background"]
const FORMAT := "cybersand-strata-workbench"
const SCENE_FORMAT := "cybersand-strata-scene"
const VERSION := 2
const LEGACY_VERSION := 1
const OPTICAL_VERSION := 3
const MAGIC := [67, 89, 83, 83, 84, 82, 65, 84] # CYSSTRAT
const HEADER_SIZE := 52
const MANIFEST_LIMIT := 8 * 1024 * 1024
const PAYLOAD_LIMIT := 2048 * 2048 * 2
const FILE_LIMIT := HEADER_SIZE + MANIFEST_LIMIT + PAYLOAD_LIMIT
const MAX_RECTANGLES := 32768
const MAX_LAYOUT_WRITES := 16 * 1024 * 1024
const MAX_REVISION := 2147483647
const SCENE_KEYS := ["format", "version", "extent", "content_domain", "presentation", "planes"]
const EXTENSION_KEYS := ["atmosphere", "authoring"]
const PRESENTATION_KEYS := ["enabled", "mode", "active", "solo", "parallax_strength", "fog_strength"]
const PLANE_KEYS := ["id", "revision", "bounds", "visible", "locked", "opacity", "depth", "clock", "rectangles"]
const CLOCK_KEYS := ["mode", "rate_hz", "paused"]
const MANIFEST_KEYS := ["format", "version", "starting_setup", "scene", "play_source"]


static func default_document(extent: Vector2i) -> Dictionary:
	var planes: Array = []
	var depths := [0.0, 0.35, 0.15, 0.8]
	for index: int in IDS.size():
		planes.append({"id": IDS[index], "revision": 1,
			"bounds": [0, 0, extent.x, extent.y], "visible": true, "locked": false,
			"opacity": 1.0, "depth": depths[index],
			"clock": {"mode": "borrowed" if index == 0 else "static", "rate_hz": 0, "paused": true},
			"rectangles": []})
	return {"format": SCENE_FORMAT, "version": VERSION, "extent": [extent.x, extent.y],
		"content_domain": "authored-material-layout",
		"presentation": {"enabled": false, "mode": "stack", "active": "play", "solo": "",
			"parallax_strength": 0.75, "fog_strength": 0.20}, "planes": planes,
		"atmosphere": Atmosphere.default_configuration(), "authoring": Provenance.default_configuration()}


static func upgraded(document: Dictionary) -> Dictionary:
	# V1 retains its exact meaning and can still be read and written as V1.
	# Adding an extension is the explicit, lossless migration boundary.
	if not validate(document).is_empty(): return {}
	var result := canonical(document)
	if int(result.version) == LEGACY_VERSION:
		result.version = VERSION
		result.atmosphere = Atmosphere.default_configuration()
		result.authoring = Provenance.default_configuration()
	return result


static func with_optics(document: Dictionary, configuration: Dictionary) -> Dictionary:
	# Existing v1/v2 documents keep their version and exact Classic meaning until
	# an explicit optical edit. Version 3 adds only a checked presentation field.
	if not Optics.validate(configuration).is_empty(): return {}
	var result := upgraded(document)
	if result.is_empty(): return {}
	result.version = OPTICAL_VERSION
	result.optics = Optics.canonical(configuration)
	return result


static func extent_of(document: Dictionary) -> Vector2i:
	return Vector2i(int(document.extent[0]), int(document.extent[1]))


static func plane(document: Dictionary, id: String) -> Dictionary:
	var rows: Variant = document.get("planes", [])
	if not rows is Array: return {}
	for row: Variant in rows:
		if row is Dictionary and row.get("id") is String and row.id == id: return row
	return {}


static func validate(document: Variant) -> String:
	if not document is Dictionary or not Setup._integer(document.get("version"), LEGACY_VERSION, OPTICAL_VERSION):
		return "Unsupported Strata scene version."
	var keys: Array = SCENE_KEYS + EXTENSION_KEYS if int(document.version) >= VERSION else SCENE_KEYS
	if int(document.version) == OPTICAL_VERSION: keys = keys + ["optics"]
	if not Setup._keys(document, keys) or not document.format is String \
			or document.format != SCENE_FORMAT \
			or not document.content_domain is String \
			or document.content_domain != "authored-material-layout":
		return "Unsupported Strata scene fields, version or state domain."
	if not document.extent is Array or document.extent.size() != 2:
		return "Strata requires one explicit rectangular canvas extent."
	for side: Variant in document.extent:
		if not Setup._integer(side, 512, 2048) or int(side) % 64 != 0:
			return "Strata canvas sides must be 512–2048 cells in multiples of 64."
	var extent := extent_of(document)
	if int(document.version) >= VERSION:
		var extension_error: String = Atmosphere.validate(document.atmosphere, extent)
		if not extension_error.is_empty(): return extension_error
		extension_error = Provenance.validate(document.authoring)
		if not extension_error.is_empty(): return extension_error
	if int(document.version) == OPTICAL_VERSION:
		var optical_error: String = Optics.validate(document.optics)
		if not optical_error.is_empty(): return optical_error
	var presentation: Variant = document.presentation
	if not Setup._keys(presentation, PRESENTATION_KEYS) \
			or not presentation.enabled is bool or not presentation.mode is String \
			or presentation.mode not in ["flat", "stack"] \
			or not presentation.active is String or presentation.active not in IDS \
			or not presentation.solo is String or presentation.solo not in IDS + [""] \
			or not Setup._number(presentation.parallax_strength, 0.0, 2.0) \
			or not Setup._number(presentation.fog_strength, 0.0, 1.0):
		return "Unsupported Strata presentation settings."
	if not document.planes is Array or document.planes.size() != IDS.size():
		return "A Strata scene must declare exactly four planes."
	for index: int in IDS.size():
		var row: Variant = document.planes[index]
		if not Setup._keys(row, PLANE_KEYS) or not row.id is String or row.id != IDS[index] \
				or not Setup._integer(row.revision, 1, MAX_REVISION):
			return "Strata plane identities, order or revision are invalid."
		if not row.bounds is Array or row.bounds.size() != 4:
			return "Strata plane bounds must describe the complete local canvas."
		for i: int in 4:
			if not Setup._integer(row.bounds[i], 0, 2048): return "Invalid Strata plane bounds."
		if int(row.bounds[0]) != 0 or int(row.bounds[1]) != 0 \
				or int(row.bounds[2]) != extent.x or int(row.bounds[3]) != extent.y:
			return "Strata plane bounds differ from the declared scene extent."
		if not row.visible is bool or not row.locked is bool \
				or not Setup._number(row.opacity, 0.0, 1.0) or not Setup._number(row.depth, 0.0, 1.0):
			return "Strata visibility, lock, opacity or relative depth is invalid."
		if index == 0 and row.depth != 0.0:
			return "The play plane retains its authoritative camera depth."
		if not Setup._keys(row.clock, CLOCK_KEYS) \
				or not row.clock.mode is String \
				or row.clock.mode != ("borrowed" if index == 0 else "static") \
				or not Setup._integer(row.clock.rate_hz, 0, 0) \
				or not row.clock.paused is bool or row.clock.paused != true:
			return "This milestone supports static decorative planes; the existing owner controls the play clock."
		if not row.rectangles is Array or row.rectangles.size() > MAX_RECTANGLES:
			return "Strata authored rectangle capacity exceeded."
		if index == 0 and not row.rectangles.is_empty():
			return "Play terrain must use the existing Workbench authored start, never a second layer layout."
		var writes := 0
		for rectangle: Variant in row.rectangles:
			if not rectangle is Array or rectangle.size() != 5 or not Setup._stamp_valid(rectangle, extent):
				return "Strata contains an invalid material rectangle or out-of-bounds layout."
			writes += int(rectangle[2]) * int(rectangle[3])
			if writes > MAX_LAYOUT_WRITES:
				return "Strata plane construction exceeds the bounded native write budget."
	return ""


static func canonical(document: Dictionary) -> Dictionary:
	var result := document.duplicate(true)
	result.version = int(result.version)
	result.extent = Array(PackedInt32Array(result.extent))
	for row: Dictionary in result.planes:
		row.revision = int(row.revision)
		row.bounds = Array(PackedInt32Array(row.bounds))
		row.clock.rate_hz = 0
		for index: int in row.rectangles.size():
			row.rectangles[index] = Array(PackedInt32Array(row.rectangles[index]))
	if int(result.version) >= VERSION:
		result.atmosphere = Atmosphere.canonical(result.atmosphere)
		result.authoring = Provenance.canonical(result.authoring)
	if int(result.version) == OPTICAL_VERSION:
		result.optics = Optics.canonical(result.optics)
	return result


static func _refuse(message: String) -> Dictionary:
	return {"error": message}


static func _digest(manifest: PackedByteArray, payload: PackedByteArray) -> PackedByteArray:
	var digest := HashingContext.new()
	if digest.start(HashingContext.HASH_SHA256) != OK or digest.update(manifest) != OK:
		return PackedByteArray()
	if not payload.is_empty() and digest.update(payload) != OK: return PackedByteArray()
	return digest.finish()


static func _generated_error(metadata: Variant, extent: Vector2i) -> String:
	# Guard Variant scalar comparisons before calling the existing provenance
	# reader. A GDScript type error in a String-returning validator must never be
	# mistaken for its default empty-string success result.
	if not metadata is Dictionary or not metadata.has_all(["schema", "plane_revision", "generator_revision"]) \
			or not Setup._integer(metadata.schema, 1, 1) or not metadata.plane_revision is String \
			or not Setup._integer(metadata.generator_revision, 1, MAX_REVISION):
		return "Unsupported generated play provenance scalar types."
	return GeneratedMaps.valid_provenance(metadata, extent)


static func _source(setup: Dictionary, generated: Dictionary, baseline: Dictionary) -> Dictionary:
	if not generated.is_empty() and not baseline.is_empty():
		return _refuse("Strata play terrain cannot require both generated and flattened baselines.")
	var error := Setup.validate(setup)
	if not error.is_empty(): return _refuse(error)
	error = GeneratedMaps.edit_work_error(setup)
	if not error.is_empty(): return _refuse(error)
	if not baseline.is_empty():
		error = MaterialBaseline.validate_document(setup, baseline)
		if not error.is_empty(): return _refuse(error)
		return {"metadata": {"kind": "material-baseline", "byte_count": baseline.cells.size(),
			"sha256": baseline.sha256}, "payload": baseline.cells.duplicate()}
	if not generated.is_empty():
		if not generated.has_all(["recipe", "origin", "extent", "cells", "sha256", "recipe_sha256",
				"generator_fingerprint", "plane_revision", "generator_revision", "receipt_hashes"]) \
				or not generated.recipe is Dictionary or not generated.origin is Vector2i \
				or not generated.extent is Vector2i or not generated.cells is PackedByteArray \
				or not generated.receipt_hashes is Array:
			return _refuse("Strata generated play source is incomplete.")
		var metadata := GeneratedMaps.provenance(generated)
		error = _generated_error(metadata, Setup.extent_of(setup))
		if not error.is_empty(): return _refuse(error)
		if generated.cells.size() != generated.extent.x * generated.extent.y \
				or GeneratedMaps.digest(generated.cells) != generated.sha256:
			return _refuse("Generated authored play bytes differ from their source identity.")
		return {"metadata": {"kind": "generated", "byte_count": generated.cells.size(),
			"provenance": metadata}, "payload": generated.cells.duplicate()}
	return {"metadata": {"kind": "setup", "byte_count": 0}, "payload": PackedByteArray()}


static func write_named(label: String, setup: Dictionary, generated: Dictionary,
		baseline: Dictionary, document: Dictionary) -> String:
	var path := Setup._path(label)
	if path.is_empty(): return "Use 1–48 letters, digits, underscores or hyphens for the scene name."
	var error := validate(document)
	if not error.is_empty(): return error
	var source := _source(setup, generated, baseline)
	if source.has("error"): return str(source.error)
	if extent_of(document) != Setup.extent_of(setup): return "Play and Strata canvas dimensions differ."
	var version := int(document.version)
	var manifest := JSON.stringify({"format": FORMAT, "version": version,
		"starting_setup": setup, "scene": document, "play_source": source.metadata}, "", true, version >= VERSION).to_utf8_buffer()
	var payload: PackedByteArray = source.payload
	if manifest.is_empty() or manifest.size() > MANIFEST_LIMIT or payload.size() > PAYLOAD_LIMIT:
		return "The complete Strata scene exceeds its bounded save capacity."
	var checksum := _digest(manifest, payload)
	if checksum.size() != 32: return "Could not checksum the complete Strata scene."
	if not ClassDB.class_exists(&"CyberDemoBridge"): return "Saving Strata requires the current native runtime."
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	if bridge == null or not bridge.has_method(&"replace_material_baseline_file"):
		return "The native atomic file replacement service is unavailable."
	var header := PackedByteArray(MAGIC)
	if header.resize(HEADER_SIZE) != OK: return "Insufficient capacity for the Strata header."
	header.encode_u32(8, version)
	header.encode_u32(12, manifest.size())
	header.encode_u32(16, payload.size())
	for index: int in 32: header[20 + index] = checksum[index]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Setup.DIRECTORY)) != OK:
		return "Could not create the Workbench scene directory."
	var target := ProjectSettings.globalize_path(path)
	var temporary := target + "." + Crypto.new().generate_random_bytes(8).hex_encode() + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return "Could not create the temporary Strata scene."
	file.store_buffer(header)
	file.store_buffer(manifest)
	file.store_buffer(payload)
	file.flush()
	var complete: bool = file.get_error() == OK and file.get_position() == HEADER_SIZE + manifest.size() + payload.size()
	file.close()
	if not complete:
		DirAccess.remove_absolute(temporary)
		return "Strata Save failed; the previous named scene is unchanged."
	var replaced: Dictionary = bridge.call(&"replace_material_baseline_file", temporary, target)
	if not replaced.get("ok", false):
		DirAccess.remove_absolute(temporary)
		return "Strata Save could not atomically replace the previous scene: " + str(replaced.get("error", "replacement refused"))
	return ""


static func read_named(label: String) -> Dictionary:
	var path := Setup._path(label)
	if path.is_empty(): return _refuse("Invalid Strata scene name.")
	if not FileAccess.file_exists(path): return {"legacy": true}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _refuse("Could not open the saved Strata scene.")
	var length := file.get_length()
	if file.get_buffer(mini(8, length)) != PackedByteArray(MAGIC): return {"legacy": true}
	if length < HEADER_SIZE or length > FILE_LIMIT:
		return _refuse("Strata scene is truncated or exceeds its bounded capacity.")
	file.seek(0)
	var header := file.get_buffer(HEADER_SIZE)
	if header.size() != HEADER_SIZE or int(header.decode_u32(8)) not in [LEGACY_VERSION, VERSION, OPTICAL_VERSION]:
		return _refuse("Unsupported or truncated Strata envelope version.")
	var manifest_size := int(header.decode_u32(12))
	var payload_size := int(header.decode_u32(16))
	if manifest_size <= 0 or manifest_size > MANIFEST_LIMIT or payload_size > PAYLOAD_LIMIT \
			or length != HEADER_SIZE + manifest_size + payload_size:
		return _refuse("Strata section lengths are invalid or incomplete.")
	var manifest_bytes := file.get_buffer(manifest_size)
	var payload := file.get_buffer(payload_size)
	if manifest_bytes.size() != manifest_size or payload.size() != payload_size \
			or _digest(manifest_bytes, payload) != header.slice(20, HEADER_SIZE):
		return _refuse("Strata scene integrity check failed.")
	var parser := JSON.new()
	if parser.parse(manifest_bytes.get_string_from_utf8()) != OK:
		return _refuse("Strata scene manifest is not valid JSON.")
	var manifest: Variant = parser.data
	if not Setup._keys(manifest, MANIFEST_KEYS) or not manifest.format is String or manifest.format != FORMAT \
			or not Setup._integer(manifest.version, int(header.decode_u32(8)), int(header.decode_u32(8))):
		return _refuse("Unsupported Strata manifest fields or version.")
	var error := validate(manifest.scene)
	if not error.is_empty(): return _refuse(error)
	if int(manifest.scene.version) != int(manifest.version): return _refuse("Strata envelope and scene versions disagree.")
	error = Setup.validate(manifest.starting_setup)
	if not error.is_empty(): return _refuse(error)
	var setup: Dictionary = MaterialBaseline._canonical_setup(manifest.starting_setup)
	var extent := Setup.extent_of(setup)
	if extent != extent_of(manifest.scene): return _refuse("Saved play and Strata extents differ.")
	var source: Variant = manifest.play_source
	if not source is Dictionary or not source.get("kind") is String \
			or not Setup._integer(source.get("byte_count"), 0, PAYLOAD_LIMIT) \
			or int(source.byte_count) != payload_size:
		return _refuse("Strata play source identity or payload size is invalid.")
	var generated: Dictionary = {}
	var baseline: Dictionary = {}
	match source.get("kind", ""):
		"setup":
			if not Setup._keys(source, ["kind", "byte_count"]) or payload_size != 0:
				return _refuse("Ordinary play source has unsupported fields or bytes.")
		"material-baseline":
			if not Setup._keys(source, ["kind", "byte_count", "sha256"]):
				return _refuse("Unsupported flattened play source fields.")
			baseline = {"schema": 1, "extent": extent, "cells": payload, "sha256": source.sha256}
		"generated":
			if not Setup._keys(source, ["kind", "byte_count", "provenance"]):
				return _refuse("Unsupported generated play source fields.")
			error = _generated_error(source.provenance, extent)
			if not error.is_empty(): return _refuse(error)
			generated = GeneratedMaps.native_packet(source.provenance, payload, setup.edits)
			generated.recipe = source.provenance.recipe.duplicate(true)
		_:
			return _refuse("Unsupported Strata play source kind.")
	var checked := _source(setup, generated, baseline)
	if checked.has("error"): return checked
	return {"layered": true, "setup": setup, "generated": generated,
		"baseline": baseline, "document": canonical(manifest.scene)}
