extends RefCounted

# GEN-008: independently reconstructible material identities, never live physics.
# The single file uses a small checksummed manifest followed by the exact uint16
# little-endian row-major plane; existing Setup-v2 and generated-start files are
# untouched. A temporary file and one rename replace the complete document.
const Setup = preload("res://scripts/workbench_setup.gd")
const GeneratedMaps = preload("res://scripts/workbench_generated_map.gd")
const FORMAT := "cybersand-material-baseline-v1"
const ENCODING := "uint16-le-row-major"
const VERSION := 1
const MAGIC := [67,89,83,70,76,65,84,0] # CYSFLAT\0
const HEADER_SIZE := 52 # magic[8], version/u32, manifest/u32, plane/u32, SHA-256[32]
const MANIFEST_LIMIT := 1024*1024
const PLANE_LIMIT := 2048*2048*2
const FILE_LIMIT := HEADER_SIZE+MANIFEST_LIMIT+PLANE_LIMIT
const BASELINE_KEYS := ["schema","extent","cells","sha256"]
const MANIFEST_KEYS := ["format","version","encoding","width","height","byte_count","sha256","starting_setup"]


static func _error(message: String) -> Dictionary:
	return {"error":message}


static func _extent_error(extent: Vector2i) -> String:
	if extent.x < 512 or extent.y < 512 or extent.x > 2048 or extent.y > 2048 \
			or extent.x%64 != 0 or extent.y%64 != 0:
		return "Material baseline dimensions must be 512–2048 cells in multiples of 64."
	return ""


static func _shape_error(baseline: Variant, expected_extent: Vector2i) -> String:
	if not baseline is Dictionary or not Setup._keys(baseline,BASELINE_KEYS) \
			or not Setup._integer(baseline.schema,VERSION,VERSION):
		return "Unsupported material baseline version or metadata."
	if not baseline.extent is Vector2i or baseline.extent != expected_extent:
		return "Material baseline and starting canvas dimensions differ."
	var extent_error := _extent_error(expected_extent)
	if not extent_error.is_empty(): return extent_error
	if not baseline.cells is PackedByteArray or baseline.cells.size() != expected_extent.x*expected_extent.y*2 \
			or baseline.cells.size() > PLANE_LIMIT:
		return "Material baseline must contain exactly two bytes per cell."
	if not GeneratedMaps._hex(baseline.sha256,64):
		return "Material baseline SHA-256 is malformed."
	return ""


static func validate(baseline: Variant, expected_extent: Vector2i) -> String:
	var error := _shape_error(baseline,expected_extent)
	if not error.is_empty(): return error
	if not ClassDB.class_exists(&"CyberDemoBridge"):
		return "Material baselines require the native runtime."
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	if bridge == null or not bridge.has_method(&"validate_material_baseline"):
		return "This native runtime cannot validate material baselines; rebuild the GDExtension."
	# A single bounded native value call checks every actual supported material ID
	# and the exact bytes. No per-cell Godot/native calls or rendered samples.
	var result: Dictionary = bridge.call(&"validate_material_baseline",baseline.cells,expected_extent)
	if not result.get("ok",false):
		return "Material baseline refused: "+str(result.get("error","native validation failed"))
	if result.get("sha256","") != baseline.sha256 or int(result.get("byte_count",-1)) != baseline.cells.size():
		return "Material baseline integrity check failed."
	return ""


static func stage(capture: Dictionary, expected_extent: Vector2i) -> Dictionary:
	if not capture.get("ok",false) or not capture.has_all(BASELINE_KEYS):
		return _error("Complete native material capture was not supplied: "+str(capture.get("error","incomplete capture")))
	var baseline := {"schema":capture.schema,"extent":capture.extent,
		"cells":capture.cells,"sha256":capture.sha256}
	var error := validate(baseline,expected_extent)
	if not error.is_empty(): return _error(error)
	# Packed arrays are reference values in GDScript: explicitly detach from the
	# receipt before retaining an authored baseline. The underlying native World
	# was already copied by its owner; neither later edits nor a receipt consumer
	# can mutate this retained plane through an alias.
	baseline.cells = baseline.cells.duplicate()
	if baseline.cells.size() != expected_extent.x*expected_extent.y*2:
		return _error("Insufficient capacity to retain the complete material baseline.")
	return {"baseline":baseline}


static func native_packet(baseline: Dictionary, edits: Array) -> Dictionary:
	return {"schema":VERSION,"extent":baseline.extent,"cells":baseline.cells.duplicate(),
		"sha256":baseline.sha256,"edits":edits.duplicate(true)}


static func _manifest(setup: Dictionary, baseline: Dictionary) -> Dictionary:
	return {"format":FORMAT,"version":VERSION,"encoding":ENCODING,
		"width":baseline.extent.x,"height":baseline.extent.y,
		"byte_count":baseline.cells.size(),"sha256":baseline.sha256,"starting_setup":setup}


# Used by native-edit preflight as well as Save. Accepted overlays retain their
# order and Empty cells; they must never compact against an assumed blank plane.
static func validate_document(setup: Dictionary, baseline: Dictionary) -> String:
	var error := Setup.validate(setup)
	if not error.is_empty(): return error
	error = validate(baseline,Setup.extent_of(setup))
	if not error.is_empty(): return error
	if setup.edits.size() > Setup.native_rectangle_budget():
		return "Material-baseline overlays exceed the installed native rectangle budget."
	error = GeneratedMaps.edit_work_error(setup)
	if not error.is_empty(): return error
	if JSON.stringify(_manifest(setup,baseline)).to_utf8_buffer().size() > MANIFEST_LIMIT:
		return "Material-baseline setup metadata exceeds 1 MiB."
	return ""


static func _body_digest(manifest: PackedByteArray, cells: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK \
			or hash.update(manifest) != OK or hash.update(cells) != OK:
		return PackedByteArray()
	return hash.finish()


static func write_named(label: String, setup: Dictionary, baseline: Dictionary) -> String:
	var path := Setup._path(label)
	if path.is_empty(): return "Use 1–48 letters, digits, underscores or hyphens for the setup name."
	var error := validate_document(setup,baseline)
	if not error.is_empty(): return error
	var manifest := JSON.stringify(_manifest(setup,baseline)).to_utf8_buffer()
	var checksum := _body_digest(manifest,baseline.cells)
	if checksum.size() != 32: return "Could not checksum the complete material baseline."
	var header := PackedByteArray(MAGIC)
	if header.resize(HEADER_SIZE) != OK: return "Insufficient capacity for the material-baseline header."
	header.encode_u32(8,VERSION)
	header.encode_u32(12,manifest.size())
	header.encode_u32(16,baseline.cells.size())
	for index: int in 32: header[20+index] = checksum[index]
	var directory := ProjectSettings.globalize_path(Setup.DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return "Cannot create the material-baseline directory."
	var target := ProjectSettings.globalize_path(path)
	var temporary := target+"."+Crypto.new().generate_random_bytes(8).hex_encode()+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return "Cannot create temporary material-baseline file."
	# Store the plane directly, without base64 or a concatenated full-file copy.
	file.store_buffer(header)
	file.store_buffer(manifest)
	file.store_buffer(baseline.cells)
	file.flush()
	var state := file.get_error()
	var complete: bool = file.get_position() == HEADER_SIZE+manifest.size()+baseline.cells.size()
	file.close()
	if state == OK and complete: state = DirAccess.rename_absolute(temporary,target)
	if state != OK or not complete:
		DirAccess.remove_absolute(temporary)
		return "Could not atomically replace the material baseline; previous named start is unchanged."
	return ""


static func _canonical_setup(setup: Dictionary) -> Dictionary:
	# JSON number types are normalized only after Setup's strict validation.
	for key: String in ["version","next_id","selected","rule_radius","material","brush"]:
		setup[key] = int(setup[key])
	for key: String in ["extent","source","liquid_policy"]:
		setup[key] = Array(PackedInt32Array(setup[key]))
	for index: int in setup.edits.size():
		setup.edits[index] = Array(PackedInt32Array(setup.edits[index]))
	for actor: Dictionary in setup.actors: actor.id = int(actor.id)
	if setup.has(Setup.EQUIPMENT_KEY):
		setup[Setup.EQUIPMENT_KEY] = Setup.Equipment.canonical(setup[Setup.EQUIPMENT_KEY])
	return setup


static func read_named(label: String) -> Dictionary:
	var path := Setup._path(label)
	if path.is_empty(): return _error("Invalid material-baseline name.")
	if not FileAccess.file_exists(path): return {"legacy":true}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return _error("Cannot open the saved material baseline.")
	var length := file.get_length()
	# Sniff only eight bytes. Legacy readers keep their original file-size gates.
	if file.get_buffer(mini(8,length)) != PackedByteArray(MAGIC): return {"legacy":true}
	if length < HEADER_SIZE or length > FILE_LIMIT:
		return _error("Material-baseline file is truncated or exceeds its bounded capacity.")
	file.seek(0)
	var header := file.get_buffer(HEADER_SIZE)
	if header.size() != HEADER_SIZE: return _error("Material-baseline header is truncated.")
	if header.decode_u32(8) != VERSION: return _error("Unsupported material-baseline container version.")
	var manifest_size := int(header.decode_u32(12))
	var plane_size := int(header.decode_u32(16))
	if manifest_size <= 0 or manifest_size > MANIFEST_LIMIT or plane_size <= 0 or plane_size > PLANE_LIMIT \
			or length != HEADER_SIZE+manifest_size+plane_size:
		return _error("Material-baseline section lengths are invalid or incomplete.")
	var manifest_bytes := file.get_buffer(manifest_size)
	var cells := file.get_buffer(plane_size)
	if manifest_bytes.size() != manifest_size or cells.size() != plane_size:
		return _error("Material-baseline payload is truncated.")
	if _body_digest(manifest_bytes,cells) != header.slice(20,52):
		return _error("Material-baseline file integrity check failed.")
	var parser := JSON.new()
	if parser.parse(manifest_bytes.get_string_from_utf8()) != OK:
		return _error("Material-baseline metadata is not valid JSON.")
	var metadata: Variant = parser.data
	if not Setup._keys(metadata,MANIFEST_KEYS) or metadata.format != FORMAT \
			or not Setup._integer(metadata.version,VERSION,VERSION) or metadata.encoding != ENCODING:
		return _error("Unsupported material-baseline metadata or encoding.")
	if not Setup._integer(metadata.width,512,2048) or not Setup._integer(metadata.height,512,2048) \
			or not Setup._integer(metadata.byte_count,1,PLANE_LIMIT) or int(metadata.byte_count) != plane_size:
		return _error("Material-baseline dimensions or byte count are invalid.")
	var extent := Vector2i(int(metadata.width),int(metadata.height))
	var baseline := {"schema":VERSION,"extent":extent,"cells":cells,"sha256":metadata.sha256}
	var error := Setup.validate(metadata.starting_setup)
	if not error.is_empty(): return _error(error)
	var setup: Dictionary = metadata.starting_setup
	error = validate_document(setup,baseline)
	if not error.is_empty(): return _error(error)
	return {"flattened":true,"setup":_canonical_setup(setup),"baseline":baseline}
