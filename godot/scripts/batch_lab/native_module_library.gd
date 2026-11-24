extends RefCounted
## Bounded module documents, separate from Art credentials and ordinary history.
const Module = preload("res://scripts/batch_lab/native_module.gd")
const FORMAT := "cybersand-native-module-library-v1"
const DEFAULT_PATH := "user://architecture/modules/library.json"
const MAX_MODULES := 128
const MAX_FILE_BYTES := 64*1024*1024
const METADATA_FIELDS := ["format","name","tags","part_type","anchor","allowed_transforms","roles",
	"attachments","clearances","protected_regions","variation_regions","fixed_regions","design_card_ids"]
var _modules: Dictionary = {}
var _native_verified: Dictionary = {}
var _summary_cache: Dictionary = {}
var last_path := ""

func count() -> int:
	return _modules.size()

func all() -> Array:
	var result: Array = []
	var ids: Array = _modules.keys()
	ids.sort()
	for identity: String in ids: result.append(_modules[identity].duplicate(true))
	return result

func get_module(identity: String) -> Dictionary:
	return _modules.get(identity,{}).duplicate(true)

func add(module: Dictionary, replace := false) -> Dictionary:
	var checked := Module.validate(module)
	if not checked.ok: return checked
	if _modules.has(module.id):
		if _modules[module.id].content_sha256==module.content_sha256: return {"ok":true,"id":module.id,"unchanged":true}
		if not replace: return Module.failure("A different module already uses this identifier. Rename it or explicitly replace it.")
	elif _modules.size()>=MAX_MODULES: return Module.failure("Module library is full (128 modules). Export or remove a module first.")
	var candidate := _modules.duplicate(true)
	candidate[module.id] = checked.module.duplicate(true)
	if Module.json_bytes(candidate.values()).size()>MAX_FILE_BYTES: return Module.failure("Module library exceeds 64 MiB.")
	_modules = candidate
	_summary_cache[module.id] = Module.summary(checked.module)
	# A changed manifest retires previous session qualification, even if its ID is retained.
	if _native_verified.get(module.id,"")!=module.content_sha256: _native_verified.erase(module.id)
	return {"ok":true,"id":module.id,"content_sha256":module.content_sha256}

func harvest_tile(tile: Dictionary, metadata: Dictionary, region: Rect2i = Rect2i()) -> Dictionary:
	var harvested := Module.harvest_tile(tile,metadata,region)
	if not harvested.ok: return harvested
	var admitted := add(harvested.module)
	if not admitted.ok: return admitted
	if tile.get("_native_readback_current_process",false) and not tile.provenance.get("reopened_record",false):
		_native_verified[harvested.module.id] = harvested.module.content_sha256
	return harvested

func harvest_capture(capture: Dictionary, metadata: Dictionary) -> Dictionary:
	# Accept the read-only Workbench capture adapter's successful value, never a
	# rendered image or an arbitrary imported qualification flag. This method is
	# called only by the live host completion callback, not document import.
	if not capture.get("ok",false) or not capture.get("config") is Dictionary:
		return Module.failure("Harvest requires a successful native Workbench region capture.")
	var config: Dictionary = capture.config
	if not config.get("source_cells") is PackedByteArray or not Module._pair(config.get("source_extent")) \
		or not config.get("source_provenance") is Dictionary:
		return Module.failure("Native capture is missing its exact material plane or provenance.")
	var provenance: Dictionary = config.source_provenance
	if provenance.get("kind")!="native-material-occupancy-crop-v1" \
		or provenance.get("crop_sha256")!=Module.digest(config.source_cells) \
		or not Module._hex(provenance.get("whole_plane_sha256")):
		return Module.failure("Native capture identity or readback checksum differs.")
	var details := metadata.duplicate(true)
	details["provenance"] = {"kind":"workbench-native-material-harvest","source":provenance.duplicate(true),
		"physical_owner_acceptance":"not-established"}
	var extent := Vector2i(int(config.source_extent[0]),int(config.source_extent[1]))
	var harvested := Module.harvest(config.source_cells,extent,Rect2i(Vector2i.ZERO,extent),details)
	if not harvested.ok: return harvested
	var admitted := add(harvested.module)
	if not admitted.ok: return admitted
	_native_verified[harvested.module.id] = harvested.module.content_sha256
	return harvested

func mark_native_replay_verified(identity: String, readback: PackedByteArray, extent: Vector2i, receipt: Dictionary) -> Dictionary:
	if not _modules.has(identity): return Module.failure("Unknown module.")
	var checked := Module.validate(_modules[identity])
	if not checked.ok: return checked
	if receipt.get("backend")!="CyberNativeCellWorld" or receipt.get("status")!="completed" or not receipt.get("ok",false) \
		or not Module.integer(receipt.get("generation")) or int(receipt.generation)<1 or not receipt.get("capture_sha256") is String \
		or receipt.capture_sha256!=Module.digest(readback) or extent!=checked.extent or readback!=checked.cells:
		return Module.failure("Native replay qualification needs exact original geometry and a matching native readback receipt.")
	_native_verified[identity] = _modules[identity].content_sha256
	return {"ok":true,"id":identity}

func remove(identity: String) -> Dictionary:
	if not _modules.has(identity): return Module.failure("Unknown module.")
	_modules.erase(identity)
	_native_verified.erase(identity)
	_summary_cache.erase(identity)
	return {"ok":true}

func annotate(identity: String, name: String, tags: Array) -> Dictionary:
	if not _modules.has(identity): return Module.failure("Unknown module.")
	var module: Dictionary = _modules[identity].duplicate(true)
	module.name = name
	module.tags = tags.duplicate()
	module.content_sha256 = Module.content_digest(module)
	return add(module,true)

func draft_metadata(identity: String, expected_content_sha256: String, patch: Dictionary) -> Dictionary:
	if not _modules.has(identity): return Module.failure("Unknown module.")
	var original: Dictionary = _modules[identity]
	if original.content_sha256!=expected_content_sha256: return Module.failure("Module metadata changed; inspect the current revision before editing.")
	for field: Variant in patch:
		if field not in METADATA_FIELDS: return Module.failure("Metadata editing cannot change observed geometry, identity, recipe or provenance.")
	var candidate := original.duplicate(true)
	for field: Variant in patch: candidate[field] = patch[field].duplicate(true) if patch[field] is Array or patch[field] is Dictionary else patch[field]
	if original.format==Module.FORMAT_V2 and candidate.format!=Module.FORMAT_V2: return Module.failure("A V2 module cannot silently discard its connection contracts by downgrading.")
	if candidate.format==Module.FORMAT_V2 and not candidate.has("fixed_regions"): candidate["fixed_regions"] = []
	candidate.content_sha256 = Module.content_digest(candidate)
	var checked := Module.validate(candidate)
	if not checked.ok: return checked
	return {"ok":true,"zero_writes":true,"module":checked.module,"content_sha256":checked.module.content_sha256,
		"expected_content_sha256":expected_content_sha256,"diagnostics":[],
		"scope":"Authored metadata draft only. Geometry and retained provenance are unchanged; native qualification is not transferred to a changed manifest."}

func commit_metadata(identity: String, expected_content_sha256: String, candidate: Dictionary) -> Dictionary:
	if not _modules.has(identity): return Module.failure("Unknown module.")
	var original: Dictionary = _modules[identity]
	if original.content_sha256!=expected_content_sha256: return Module.failure("Module metadata changed; this draft is stale.")
	var checked := Module.validate(candidate)
	if not checked.ok: return checked
	for field: String in ["id","extent","geometry","provenance","recipe"]:
		if Module.json_bytes(candidate[field])!=Module.json_bytes(original[field]): return Module.failure("A metadata commit cannot replace observed geometry, identity, recipe or provenance.")
	if original.format==Module.FORMAT_V2 and candidate.format!=Module.FORMAT_V2: return Module.failure("A metadata commit cannot discard V2 connection contracts.")
	return add(checked.module,true)

func _summary(identity: String) -> Dictionary:
	# Summaries are computed only on validated adoption. Search and UI refresh do
	# not repeatedly decode or hash every module's exact material plane.
	if not _summary_cache.has(identity): _summary_cache[identity] = Module.summary(_modules[identity])
	var item: Dictionary = _summary_cache[identity].duplicate(true)
	item.native_readback_verified = _native_verified.get(identity,"")==_modules[identity].content_sha256
	if item.native_readback_verified: item.native_qualification_scope = "Current-session exact native material observation/replay; no physical owner acceptance."
	return item

func summaries() -> Array:
	var result: Array = []
	var ids: Array = _modules.keys()
	ids.sort()
	for identity: String in ids: result.append(_summary(identity))
	return result

func search(query: String, filters: Dictionary = {}) -> Array:
	var result: Array = []
	var terms := query.to_lower().split(" ",false)
	var ids: Array = _modules.keys()
	ids.sort()
	for identity: String in ids:
		var module: Dictionary = _modules[identity]
		if filters.has("part_type") and filters.part_type!=module.part_type: continue
		if filters.has("tag") and filters.tag not in module.tags: continue
		if filters.has("max_extent"):
			var size: Variant = filters.max_extent
			if not Module._pair(size) or module.extent[0]>size[0] or module.extent[1]>size[1]: continue
		var text := " ".join([module.id,module.name,module.part_type," ".join(module.tags)," ".join(module.design_card_ids)]).to_lower()
		var match_all := true
		for term: String in terms:
			if not text.contains(term): match_all = false; break
		if match_all:
			result.append(_summary(identity))
	return result

static func _read_json(path: String, maximum: int) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return Module.failure("Cannot open module document.")
	if file.get_length()<2 or file.get_length()>maximum: return Module.failure("Module document exceeds its bounded size.")
	var parser := JSON.new()
	if parser.parse(file.get_as_text())!=OK or not parser.data is Dictionary: return Module.failure("Module document is not valid JSON.")
	return {"ok":true,"value":parser.data}

static func _atomic_write(path: String, value: Dictionary, maximum: int) -> Dictionary:
	var bytes := Module.json_bytes(value)
	if bytes.size()>maximum: return Module.failure("Document exceeds the bounded file size.")
	var target := ProjectSettings.globalize_path(path)
	if target.get_file().is_empty(): return Module.failure("Choose a module document filename.")
	var directory := target.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory)!=OK: return Module.failure("Cannot create module document directory.")
	# Reuse the accepted native atomic replacement primitive on Windows as well
	# as Linux; Godot's overwrite rename alone can remove the previous document.
	if not ClassDB.class_exists(&"CyberDemoBridge"): return Module.failure("Saving modules requires the native atomic-file runtime.")
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	if bridge==null or not bridge.has_method(&"replace_material_baseline_file"):
		return Module.failure("The native runtime cannot atomically save module documents.")
	var temporary := target+"."+Crypto.new().generate_random_bytes(8).hex_encode()+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return Module.failure("Cannot create temporary module document.")
	file.store_buffer(bytes)
	file.flush()
	var complete: bool = file.get_error()==OK and file.get_position()==bytes.size()
	file.close()
	if not complete:
		DirAccess.remove_absolute(temporary)
		return Module.failure("Could not complete the temporary module document; previous file is retained.")
	var replaced: Dictionary = bridge.call(&"replace_material_baseline_file",temporary,target)
	if not replaced.get("ok",false):
		DirAccess.remove_absolute(temporary)
		return Module.failure("Could not atomically replace module document: "+str(replaced.get("error","native refusal")))
	return {"ok":true,"path":path,"sha256":Module.digest(bytes),"bytes":bytes.size()}

func save(path: String = DEFAULT_PATH) -> Dictionary:
	var payload := {"format":FORMAT,"modules":all()}
	payload["content_sha256"] = Module.digest(Module.json_bytes(payload.modules))
	var written := _atomic_write(path,payload,MAX_FILE_BYTES)
	if written.ok: last_path = path
	return written

func load_library(path: String = DEFAULT_PATH) -> Dictionary:
	var read := _read_json(path,MAX_FILE_BYTES)
	if not read.ok: return read
	var document: Dictionary = read.value
	if not Module._keys(document,["format","modules","content_sha256"]) or document.format!=FORMAT \
		or not document.modules is Array or document.modules.size()>MAX_MODULES:
		return Module.failure("Unsupported module library format or capacity.")
	if not Module._hex(document.content_sha256) or Module.digest(Module.json_bytes(document.modules))!=document.content_sha256:
		return Module.failure("Module library checksum differs.")
	var candidate := {}
	var summaries := {}
	for raw: Variant in document.modules:
		var checked := Module.validate(raw)
		if not checked.ok: return checked
		if candidate.has(checked.module.id): return Module.failure("Duplicate module identity in library.")
		candidate[checked.module.id] = checked.module.duplicate(true)
		summaries[checked.module.id] = Module.summary(checked.module)
	# All-or-nothing adoption; bad imports never discard the existing library.
	_modules = candidate
	_summary_cache = summaries
	_native_verified.clear()
	last_path = path
	return {"ok":true,"count":count(),"path":path,
		"scope":"Retained module documents; fresh native placement remains separately admitted."}

func import_module(path: String, replace := false) -> Dictionary:
	var read := _read_json(path,Module.MAX_BYTES)
	if not read.ok: return read
	return add(read.value,replace)

func export_module(identity: String, path: String) -> Dictionary:
	if not _modules.has(identity): return Module.failure("Unknown module.")
	return _atomic_write(path,_modules[identity],Module.MAX_BYTES)
