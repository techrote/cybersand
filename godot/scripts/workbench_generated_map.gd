extends RefCounted

# EXPLORE-001 generated start. This manifest is NOT a Workbench Setup v3/v4
# migration: it nests an unchanged validated v2 starting setup, and stores the
# native GEN-007 recipe instead of millions of material cells or brush records.
const Setup = preload("res://scripts/workbench_setup.gd")
const FORMAT := "cybersand-generated-start-v1"
const LIMIT := 1024 * 1024
# Native generation receipts are bounded in saved/reloaded authored-start maps.
const MAX_GENERATION_RECEIPTS := 1024

static func digest(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	if h.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if h.update(bytes) != OK:
		return ""
	return h.finish().hex_encode()

static func recipe_hash(recipe: Dictionary) -> String:
	# JSON round-trip canonicalization matters: Godot parses persisted JSON
	# integers as floats. A saved seed (19337) must hash identically after
	# fresh-process load (19337.0) without changing native sampling semantics.
	var encoded: String = JSON.stringify(recipe)
	var normalized: Variant = JSON.parse_string(encoded)
	if not normalized is Dictionary: return ""
	return digest(JSON.stringify(normalized).to_utf8_buffer())

static func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length:
		return false
	for c: String in value:
		if not c in "0123456789abcdef":
			return false
	return true

static func valid_provenance(prov: Variant, size: Vector2i) -> String:
	if not prov is Dictionary or not prov.has_all(["schema","recipe","origin","extent",
			"sha256","recipe_sha256","generator_fingerprint","plane_revision",
			"generator_revision","receipt_hashes"]):
		return "Generated-map provenance is incomplete."
	if prov.size() != 10 or prov.schema != 1 or not prov.recipe is Dictionary:
		return "Unsupported generated-map provenance."
	if not prov.origin is Array or prov.origin.size() != 2 or not prov.extent is Array or prov.extent.size() != 2:
		return "Generated map has no bounded source region."
	for number: Variant in prov.origin + prov.extent:
		if not number is int and not number is float:
			return "Generated-map coordinates must be numeric."
		if int(number) != number:
			return "Generated-map coordinates must be integers."
	if Vector2i(int(prov.extent[0]),int(prov.extent[1])) != size:
		return "Generated-map region/starting canvas mismatch."
	var origin := Vector2i(int(prov.origin[0]),int(prov.origin[1]))
	if origin.x < -1000000 or origin.y < -1000000 or origin.x > 1000000-size.x or origin.y > 1000000-size.y:
		return "Generated-map source region outside admission."
	if not _hex(prov.sha256,64) or not _hex(prov.recipe_sha256,64) or not _hex(prov.generator_fingerprint,16):
		return "Generated-map material/recipe fingerprint is malformed."
	if not (prov.plane_revision == "" or _hex(prov.plane_revision,16)):
		return "Invalid semantic-plane revision."
	if not prov.generator_revision is int and not prov.generator_revision is float:
		return "Invalid generator revision."
	if int(prov.generator_revision) < 1 or int(prov.generator_revision) != prov.generator_revision:
		return "Invalid generator revision."
	if not prov.receipt_hashes is Array or prov.receipt_hashes.size() > MAX_GENERATION_RECEIPTS:
		return "Invalid native generation receipt count."
	for receipt: Variant in prov.receipt_hashes:
		if not _hex(receipt,16): return "Malformed native receipt."
	if recipe_hash(prov.recipe) != prov.recipe_sha256:
		return "GEN-007 recipe bytes no longer match the saved identity."
	return ""

static func provenance(packet: Dictionary) -> Dictionary:
	return {
		"schema":1, "recipe":packet.recipe.duplicate(true),
		"origin":[packet.origin.x,packet.origin.y],
		"extent":[packet.extent.x,packet.extent.y],
		"sha256":packet.sha256, "recipe_sha256":packet.recipe_sha256,
		"generator_fingerprint":packet.generator_fingerprint,
		"plane_revision":packet.plane_revision,
		"generator_revision":packet.generator_revision,
		"receipt_hashes":packet.receipt_hashes.duplicate(true)
	}

static func native_packet(metadata: Dictionary, cells: PackedByteArray, edits: Array) -> Dictionary:
	return {
		"schema":1,
		"extent":Vector2i(int(metadata.extent[0]),int(metadata.extent[1])),
		"origin":Vector2i(int(metadata.origin[0]),int(metadata.origin[1])),
		"cells":cells,
		"sha256":metadata.sha256,
		"recipe_sha256":metadata.recipe_sha256,
		"generator_fingerprint":metadata.generator_fingerprint,
		"plane_revision":metadata.plane_revision,
		"generator_revision":int(metadata.generator_revision),
		"generator_seed":int(metadata.recipe.get("seed",0)),
		"receipt_hashes":metadata.receipt_hashes.duplicate(true),
		"edits":edits.duplicate(true)
	}

# Construction work is a separate bounded resource from JSON size or
# number of authored stamps. Use conservative clipped disc bounds, matching
# the compiled native prepared-world admission without duplicating physics.
static func edit_work_error(setup: Dictionary) -> String:
	var size: Vector2i = Setup.extent_of(setup)
	var limit: int = mini(64*size.x*size.y,32000000)
	var work := 0
	for stamp: Array in setup.edits:
		if stamp.size() == 5:
			work += int(stamp[2])*int(stamp[3])
		else:
			var radius: int = int(stamp[2])
			var left: int = maxi(0,int(stamp[0])-radius)
			var top: int = maxi(0,int(stamp[1])-radius)
			var right: int = mini(size.x,int(stamp[0])+radius+1)
			var bottom: int = mini(size.y,int(stamp[1])+radius+1)
			work += (right-left)*(bottom-top)
		if work > limit:
			return "Generated starting paint exceeds the bounded native replay budget."
	return ""


static func write_named(label: String, setup: Dictionary, packet: Dictionary) -> String:
	var path: String = Setup._path(label)
	if path.is_empty(): return "Invalid generated-map name."
	var error: String = Setup.validate(setup)
	if not error.is_empty(): return error
	error = edit_work_error(setup)
	if not error.is_empty(): return error
	var meta := provenance(packet)
	error = valid_provenance(meta,Setup.extent_of(setup))
	if not error.is_empty(): return error
	if not packet.cells is PackedByteArray or packet.cells.size() != int(setup.extent[0])*int(setup.extent[1]):
		return "Generated-map material size mismatch."
	if digest(packet.cells) != meta.sha256:
		return "Generated-map material bytes changed since generation."
	var body := JSON.stringify({"format":FORMAT,"version":1,"generation":meta,"starting_setup":setup})
	if body.to_utf8_buffer().size() > LIMIT: return "Generated-map manifest exceeds 1 MiB."
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Setup.DIRECTORY)) != OK:
		return "Could not create the map directory."
	var target := ProjectSettings.globalize_path(path)
	var temp := target + "." + Crypto.new().generate_random_bytes(8).hex_encode() + ".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null: return "Could not create the temporary generated-map file."
	file.store_string(body)
	file.flush()
	var state := file.get_error()
	file.close()
	if state == OK: state = DirAccess.rename_absolute(temp,target)
	if state != OK:
		DirAccess.remove_absolute(temp)
		return "Could not atomically replace the existing generated map."
	return ""

static func read_named(label: String) -> Dictionary:
	var path: String = Setup._path(label)
	if path.is_empty(): return {"error":"Invalid map name."}
	if not FileAccess.file_exists(path): return {"legacy":true}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error":"Cannot open the saved map."}
	if file.get_length() > LIMIT: return {"error":"Map manifest exceeds 1 MiB."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"error":"Invalid map JSON at line %d." % parser.get_error_line()}
	var entry: Variant = parser.data
	if not entry is Dictionary or entry.get("format","") != FORMAT:
		return {"legacy":true}
	if entry.size() != 4 or entry.get("version",-1) != 1 or not entry.has_all(["format","version","generation","starting_setup"]):
		return {"error":"Unsupported generated-map manifest."}
	var setup: Variant = entry.starting_setup
	var error: String = Setup.validate(setup)
	if not error.is_empty(): return {"error":error}
	error = edit_work_error(setup)
	if not error.is_empty(): return {"error":error}
	error = valid_provenance(entry.generation,Setup.extent_of(setup))
	if not error.is_empty(): return {"error":error}
	# JSON decodes integral coordinate/revision values as floating numbers.
	# They have been strictly checked for integer value and bounded range
	# above; canonicalize their *types* before the exact-provenance comparison.
	# No hash, native material or recipe identity is reconstructed/waived.
	var generation: Dictionary = entry.generation
	for key: String in ["origin","extent"]:
		generation[key] = Array(PackedInt32Array(generation[key]))
	for key: String in ["schema","generator_revision"]:
		generation[key] = int(generation[key])
	# Exact numerical typing for the native owner. JSON numeric conversion is
	# admitted only after the original v2 validator has checked every field.
	for key: String in ["version","next_id","selected","rule_radius","material","brush"]:
		setup[key] = int(setup[key])
	for key: String in ["extent","source","liquid_policy"]:
		setup[key] = Array(PackedInt32Array(setup[key]))
	for index: int in setup.edits.size():
		setup.edits[index] = Array(PackedInt32Array(setup.edits[index]))
	for actor: Dictionary in setup.actors:
		actor.id = int(actor.id)
	return {"generated":true,"setup":setup,"generation":generation}
