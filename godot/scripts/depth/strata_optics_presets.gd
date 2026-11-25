extends RefCounted

## User-owned reusable optics. Scene-authored values are always embedded in
## CYSSTRAT and never depend on this catalogue. A malformed catalogue is refused,
## retained on disk and never replaced implicitly by empty defaults.
const Configuration = preload("res://scripts/depth/strata_optics_configuration.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const DIRECTORY := "user://strata-optics"
const PATH := DIRECTORY + "/presets.json"
const PREFERENCES_PATH := DIRECTORY + "/preferences.json"
const FORMAT := "cybersand-strata-optical-presets"
const VERSION := 1
const MAX_PRESETS := 32
const MAX_BYTES := 256 * 1024


static func empty_catalogue() -> Dictionary:
	return {"format":FORMAT,"version":VERSION,"presets":[]}


static func validate(catalogue: Variant) -> String:
	if not Setup._keys(catalogue,["format","version","presets"]) \
			or not catalogue.format is String or catalogue.format != FORMAT \
			or not Setup._integer(catalogue.version,VERSION,VERSION) \
			or not catalogue.presets is Array or catalogue.presets.size() > MAX_PRESETS:
		return "Unsupported optical preset catalogue or capacity."
	var seen := {}
	for row: Variant in catalogue.presets:
		if not Setup._keys(row,["id","name","configuration"]) or not row.name is String \
				or not valid_name(row.name) \
				or not row.id is String or row.id != preset_id(row.name) or seen.has(row.id):
			return "Optical presets require unique bounded names and matching identities."
		var error := Configuration.validate(row.configuration)
		if not error.is_empty(): return error
		if row.configuration.profile != row.id: return "Optical preset identity differs from its configuration."
		seen[row.id] = true
	return ""


static func preset_id(label: String) -> String:
	return "custom-" + label.strip_edges().sha256_text().substr(0,24)


static func valid_name(label: String) -> bool:
	if label.is_empty() or label.length() > 48 or label.strip_edges() != label: return false
	for index: int in label.length():
		var code := label.unicode_at(index)
		if code < 32 or code == 127: return false
	return true


static func _read(path: String, limit: int) -> Dictionary:
	if not FileAccess.file_exists(path): return {"missing":true}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error":"Could not read optical settings; the existing file is retained."}
	var length := file.get_length()
	if length <= 0 or length > limit:
		file.close()
		return {"error":"Optical settings exceed the supported bounded size or are empty."}
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() != length: return {"error":"Optical settings read was incomplete."}
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK: return {"error":"Optical settings contain invalid JSON."}
	return {"value":parser.data}


static func read_catalogue() -> Dictionary:
	var read := _read(PATH,MAX_BYTES)
	if read.has("error"): return read
	if read.get("missing",false): return {"catalogue":empty_catalogue()}
	var error := validate(read.value)
	if not error.is_empty(): return {"error":error}
	var catalogue: Dictionary = read.value.duplicate(true)
	catalogue.version = VERSION
	for row: Dictionary in catalogue.presets:
		row.configuration = Configuration.canonical(row.configuration)
	return {"catalogue":catalogue}


static func _atomic_write(path: String, value: Dictionary) -> String:
	var bytes := JSON.stringify(value,"\t",true,true).to_utf8_buffer()
	if bytes.is_empty() or bytes.size() > MAX_BYTES: return "Optical settings exceed the bounded save capacity."
	if not ClassDB.class_exists(&"CyberDemoBridge"): return "Saving optical presets requires the native atomic file service."
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	if bridge == null or not bridge.has_method(&"replace_material_baseline_file"):
		return "The native atomic file replacement service is unavailable."
	var target := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
		return "Could not create the optical settings directory."
	var temporary := target + "." + Crypto.new().generate_random_bytes(8).hex_encode() + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return "Could not create staged optical settings."
	file.store_buffer(bytes)
	file.flush()
	var complete := file.get_error() == OK and file.get_position() == bytes.size()
	file.close()
	# Reopen actual staged bytes before replacing the last valid named preset.
	var written := FileAccess.get_file_as_bytes(temporary)
	if not complete or written != bytes:
		DirAccess.remove_absolute(temporary)
		return "Optical save failed verification; previous settings are unchanged."
	var replaced: Dictionary = bridge.call(&"replace_material_baseline_file",temporary,target)
	if not replaced.get("ok",false):
		DirAccess.remove_absolute(temporary)
		return "Optical save replacement failed; previous settings are unchanged."
	return ""


static func write_catalogue(catalogue: Dictionary) -> String:
	var error := validate(catalogue)
	if not error.is_empty(): return error
	return _atomic_write(PATH,catalogue)


static func save(label: String, configuration: Dictionary) -> Dictionary:
	label = label.strip_edges()
	if not valid_name(label): return {"error":"Use a one-line preset name containing 1–48 characters."}
	var error := Configuration.validate(configuration)
	if not error.is_empty(): return {"error":error}
	var read := read_catalogue()
	if read.has("error"): return read
	var catalogue: Dictionary = read.catalogue
	var id := preset_id(label)
	var config := Configuration.canonical(configuration)
	config.profile = id
	var item := {"id":id,"name":label,"configuration":config}
	var found := false
	for index: int in catalogue.presets.size():
		if catalogue.presets[index].id == id:
			catalogue.presets[index] = item
			found = true
			break
	if not found:
		if catalogue.presets.size() >= MAX_PRESETS: return {"error":"Optical preset capacity is 32; remove a named preset first."}
		catalogue.presets.append(item)
	error = write_catalogue(catalogue)
	return {"id":id,"catalogue":catalogue} if error.is_empty() else {"error":error}


static func remove(id: String) -> Dictionary:
	var read := read_catalogue()
	if read.has("error"): return read
	var catalogue: Dictionary = read.catalogue
	var found := false
	for index: int in catalogue.presets.size():
		if catalogue.presets[index].id == id:
			catalogue.presets.remove_at(index)
			found = true
			break
	if not found: return {"error":"Unknown custom optical preset."}
	var error := write_catalogue(catalogue)
	return {"catalogue":catalogue} if error.is_empty() else {"error":error}


static func read_quality() -> String:
	var read := _read(PREFERENCES_PATH,4096)
	if not read.has("value"): return "balanced"
	var value: Variant = read.value
	if not Setup._keys(value,["version","quality"]) or not Setup._integer(value.version,1,1) \
			or not value.quality is String or value.quality not in Configuration.QUALITIES:
		return "balanced"
	return value.quality


static func write_quality(quality: String) -> String:
	if quality not in Configuration.QUALITIES: return "Unsupported optical quality preference."
	return _atomic_write(PREFERENCES_PATH,{"version":1,"quality":quality})
