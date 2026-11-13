extends SceneTree

# GEN-008 standalone material format contract. The first checkpoint deliberately
# fails on accepted main, which has no independent two-byte material baseline.
const MODULE := "res://scripts/workbench_material_baseline.gd"
const Setup = preload("res://scripts/workbench_setup.gd")
const Generated = preload("res://scripts/workbench_generated_map.gd")
const History = preload("res://scripts/workbench_paint_editor_history.gd")
const LABEL := "gen008-material-format"
var checks := 0
var failures := 0
var store: Script
var bridge: Object


func plane(extent: Vector2i) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(extent.x*extent.y*2)
	# Every currently supported native ID, Empty, row edges and the last cell.
	for material: int in 132:
		if material != 10: cells.encode_u16(material*2,material)
	cells.encode_u16((extent.x-1)*2,131)
	cells.encode_u16(extent.x*2,3)
	cells.encode_u16((extent.x*extent.y-1)*2,131)
	return cells


func capture(extent: Vector2i) -> Dictionary:
	var cells := plane(extent)
	return {"ok":true,"schema":1,"extent":extent,"cells":cells,"sha256":Generated.digest(cells)}


func file_bytes(label: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(Setup._path(label))


func write_bytes(label: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(Setup._path(label),FileAccess.WRITE)
	if not check(file != null,"create adversarial fixture "+label): return
	file.store_buffer(bytes)
	file.close()


func retag(bytes: PackedByteArray, metadata: Dictionary, cells: PackedByteArray) -> PackedByteArray:
	# Independent test-side encoder deliberately produces a checksum-valid bad
	# document, ensuring semantic admission is not hidden by the integrity gate.
	var manifest := JSON.stringify(metadata).to_utf8_buffer()
	var result := bytes.slice(0,52)
	result.encode_u32(12,manifest.size())
	result.encode_u32(16,cells.size())
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(manifest)
	hash.update(cells)
	var digest := hash.finish()
	for index: int in 32: result[20+index] = digest[index]
	result.append_array(manifest)
	result.append_array(cells)
	return result


func capture_refusals() -> void:
	var valid := capture(Vector2i(512,512))
	var staged: Dictionary = store.stage(valid,valid.extent)
	if not check(staged.has("baseline"),"complete native-value plane stages"): return
	check(staged.baseline.cells == valid.cells and staged.baseline.cells.size() == 512*512*2,
		"staging retains every uint16 byte, including Empty")
	for id: int in [10,132,256,65535]:
		var invalid := valid.duplicate(true)
		invalid.cells.encode_u16(0,id)
		invalid.sha256 = Generated.digest(invalid.cells)
		check(store.stage(invalid,valid.extent).has("error"),"unsupported native ID %d refuses without truncation" % id)
	var bad := valid.duplicate(true)
	bad.cells.resize(bad.cells.size()-1)
	check(store.stage(bad,valid.extent).has("error"),"odd truncated plane refuses")
	bad = valid.duplicate(true)
	bad.cells.append(0)
	check(store.stage(bad,valid.extent).has("error"),"trailing material byte refuses")
	bad = valid.duplicate(true)
	bad.sha256 = "0".repeat(64)
	check(store.stage(bad,valid.extent).has("error"),"changed captured plane refuses")
	bad = valid.duplicate(true)
	bad.schema = 2
	check(store.stage(bad,valid.extent).has("error"),"future baseline schema refuses")
	bad = valid.duplicate(true)
	bad.erase("cells")
	check(store.stage(bad,valid.extent).has("error"),"incomplete capture refuses")
	for extent: Vector2i in [Vector2i(0,0),Vector2i(511,512),Vector2i(513,512),Vector2i(2112,512)]:
		bad = valid.duplicate(true)
		bad.extent = extent
		check(store.stage(bad,extent).has("error"),"invalid dimensions refuse: "+str(extent))
	check(store.stage(valid,Vector2i(1024,1024)).has("error"),"capture cannot change the author's admitted canvas")
	check(staged.baseline.cells == valid.cells,"all failed staging leaves prior baseline bytes intact")
	var copied: PackedByteArray = valid.cells
	copied.encode_u16(0,58)
	check(staged.baseline.cells.decode_u16(0)==0,"staged baseline is detached from receipt buffer aliases")


func roundtrip_and_history() -> Dictionary:
	var extent := Vector2i(512,512)
	var baseline: Dictionary = store.stage(capture(extent),extent).baseline
	var setup := Setup.fresh(bridge.default_liquid_policy(),extent)
	# Two later edits overlap: the second must remain an explicit erasure.
	setup.edits = [[130,0,4,1,58],[131,0,1,1,0]]
	var saved: String = store.write_named(LABEL,setup,baseline)
	if not check(saved.is_empty(),"atomic material-baseline Save / "+saved): return {}
	var loaded: Dictionary = store.read_named(LABEL)
	if not check(loaded.get("flattened",false),"standalone file recognized before JSON formats"): return {}
	check(loaded.baseline.cells == baseline.cells and loaded.baseline.sha256 == baseline.sha256,
		"all cells survive exact binary Save/read")
	check(loaded.setup == setup and loaded.setup.edits == [[130,0,4,1,58],[131,0,1,1,0]],
		"supported setup and ordered erasure overlays survive")
	var packet: Dictionary = store.native_packet(loaded.baseline,loaded.setup.edits)
	check(packet.keys().size()==5 and packet.cells==baseline.cells and packet.edits==setup.edits,
		"prepared native packet reconstructs without generator recipe or earlier strokes")
	packet.cells.encode_u16(0,58)
	check(loaded.baseline.cells.decode_u16(0)==0,"prepared packet cannot mutate the retained baseline through a buffer alias")
	var add := PackedInt32Array([132,0,0,133,0,77])
	var prepared: Dictionary = History.prepare(setup,add,{},baseline)
	check(prepared.get("accepted",false) and prepared.setup.edits.slice(0,2)==setup.edits
		and prepared.setup.edits[-2]==[132,0,1,1,0] and prepared.setup.edits[-1]==[133,0,1,1,77],
		"acknowledged edit preflight preserves baseline-relative Empty and material edits")
	var bytes := file_bytes(LABEL)
	check(bytes.slice(0,8)==PackedByteArray([67,89,83,70,76,65,84,0]) and bytes.decode_u32(8)==1
		and bytes.decode_u32(16)==512*512*2,"portable container header and two-byte payload length")
	var offset := 52+int(bytes.decode_u32(12))
	check(bytes.slice(offset)==baseline.cells and bytes[offset+131*2]==131 and bytes[offset+131*2+1]==0,
		"file payload is raw little-endian uint16 with no palette/base64/rectangle substitution")
	check(bytes.size()==52+int(bytes.decode_u32(12))+512*512*2,"complete file has no hidden or trailing payload")
	return {"setup":setup,"baseline":baseline,"bytes":bytes}


func corrupt_files(fixture: Dictionary) -> void:
	var bytes: PackedByteArray = fixture.bytes
	var original_hash := FileAccess.get_sha256(Setup._path(LABEL))
	var damaged := LABEL+"-bad"
	var header_cuts := [8,20,51,52,100,bytes.size()-1]
	for cut: int in header_cuts:
		write_bytes(damaged,bytes.slice(0,cut))
		check(store.read_named(damaged).has("error"),"truncation at byte %d refuses" % cut)
	for position: int in [20,52,bytes.size()-1]:
		var altered := bytes.duplicate()
		altered[position] = altered[position]^1
		write_bytes(damaged,altered)
		check(store.read_named(damaged).has("error"),"corruption at byte %d refuses" % position)
	var altered := bytes.duplicate()
	altered.encode_u32(8,2)
	write_bytes(damaged,altered)
	check(store.read_named(damaged).has("error"),"unsupported container version refuses")
	for header_offset: int in [12,16]:
		altered = bytes.duplicate()
		altered.encode_u32(header_offset,0xFFFFFFFF)
		write_bytes(damaged,altered)
		check(store.read_named(damaged).has("error"),"oversized section refuses before allocation")
	altered = bytes.duplicate()
	altered.append(0)
	write_bytes(damaged,altered)
	check(store.read_named(damaged).has("error"),"extra trailing payload refuses")
	var metadata: Dictionary = JSON.parse_string(bytes.slice(52,52+int(bytes.decode_u32(12))).get_string_from_utf8())
	for field: String in ["version","width","height","byte_count","encoding","unknown"]:
		var bad_metadata := metadata.duplicate(true)
		bad_metadata[field] = "invalid" if field in ["encoding","unknown"] else -1
		write_bytes(damaged,retag(bytes,bad_metadata,fixture.baseline.cells))
		check(store.read_named(damaged).has("error"),"checksum-valid malformed "+field+" refuses")
	var bad_cells: PackedByteArray = fixture.baseline.cells.duplicate()
	bad_cells.encode_u16(512*2,256)
	metadata.sha256 = Generated.digest(bad_cells)
	write_bytes(damaged,retag(bytes,metadata,bad_cells))
	check(store.read_named(damaged).has("error"),"checksum-valid unsupported uint16 native ID refuses")
	var invalid: Dictionary = fixture.baseline.duplicate(true)
	invalid.cells.resize(4)
	check(not store.write_named(LABEL,fixture.setup,invalid).is_empty()
		and FileAccess.get_sha256(Setup._path(LABEL))==original_hash,"failed Save validation preserves previous valid named start")
	# Force the final filesystem replacement to fail after the complete temporary
	# file has been written. A destination directory cannot be replaced by a file.
	var blocked := LABEL+"-blocked"
	var blocked_path := ProjectSettings.globalize_path(Setup._path(blocked))
	DirAccess.make_dir_recursive_absolute(blocked_path)
	var sentinel := FileAccess.open(blocked_path.path_join("keep.txt"),FileAccess.WRITE)
	sentinel.store_string("existing destination")
	sentinel.close()
	check(not store.write_named(blocked,fixture.setup,fixture.baseline).is_empty()
		and FileAccess.get_file_as_string(blocked_path.path_join("keep.txt"))=="existing destination"
		and FileAccess.get_sha256(Setup._path(LABEL))==original_hash,
		"filesystem Save-write failure preserves existing destination and valid saves")
	var leftovers := 0
	for entry: String in DirAccess.get_files_at(Setup.DIRECTORY):
		if entry.begins_with("setup-"+blocked+".") and entry.ends_with(".tmp"): leftovers += 1
	check(leftovers==0,"failed replacement removes temporary file")
	DirAccess.remove_absolute(blocked_path.path_join("keep.txt"))
	DirAccess.remove_absolute(blocked_path)
	DirAccess.remove_absolute(Setup._path(damaged))


func atomic_replacement(fixture: Dictionary) -> void:
	var target := ProjectSettings.globalize_path(Setup._path(LABEL))
	var previous := FileAccess.get_sha256(target)
	var missing := target+".missing.tmp"
	DirAccess.remove_absolute(missing)
	var result: Dictionary = bridge.call(&"replace_material_baseline_file",missing,target)
	check(not result.get("ok",false) and not str(result.get("error","")).is_empty()
		and FileAccess.get_sha256(target)==previous,
		"missing staged source refuses without deleting the existing named start")
	result = bridge.call(&"replace_material_baseline_file","relative-staging.tmp",target)
	check(not result.get("ok",false) and FileAccess.get_sha256(target)==previous,
		"relative staging path refuses without changing the valid save")
	result = bridge.call(&"replace_material_baseline_file",target,target)
	check(not result.get("ok",false) and FileAccess.get_sha256(target)==previous,
		"source and target alias refuse without changing the valid save")
	var directory_source := target+".directory.tmp"
	if not check(DirAccess.make_dir_recursive_absolute(directory_source)==OK,"create directory-source refusal fixture"): return
	result = bridge.call(&"replace_material_baseline_file",directory_source,target)
	check(not result.get("ok",false) and DirAccess.dir_exists_absolute(directory_source)
		and FileAccess.get_sha256(target)==previous,"directory source refuses without deleting a valid target")
	DirAccess.remove_absolute(directory_source)
	# Save through the actual writer must replace an existing complete container.
	var next_setup: Dictionary = fixture.setup.duplicate(true)
	next_setup.edits.append([129,1,1,1,131])
	var error: String = store.write_named(LABEL,next_setup,fixture.baseline)
	var loaded: Dictionary = store.read_named(LABEL) if error.is_empty() else {}
	check(error.is_empty() and loaded.get("flattened",false) and loaded.get("setup",{})==next_setup
		and FileAccess.get_sha256(target)!=previous,"actual writer atomically overwrites an existing valid named start")
	error = store.write_named(LABEL,fixture.setup,fixture.baseline)
	check(error.is_empty() and file_bytes(LABEL)==fixture.bytes,"successful overwrite restores exact original container bytes")
	# Windows uses UTF-16 paths in the native primitive; these names also exercise
	# non-ASCII user-directory components without widening authored label syntax.
	var directory := ProjectSettings.globalize_path(Setup.DIRECTORY).path_join("gen008-Å水-atomic")
	for part: String in ["long-a-"+"a".repeat(80),"long-b-"+"b".repeat(80),"long-c-"+"c".repeat(80)]:
		directory = directory.path_join(part)
	check(directory.length()>260,"replacement fixture exceeds legacy Windows path length")
	if not check(DirAccess.make_dir_recursive_absolute(directory)==OK,"create Unicode replacement directory"): return
	var source := directory.path_join("étape-水.tmp")
	var unicode_target := directory.path_join("保存.json")
	var cells: PackedByteArray = fixture.baseline.cells.duplicate()
	cells.encode_u16(0,58)
	var metadata: Dictionary = JSON.parse_string(fixture.bytes.slice(52,52+int(fixture.bytes.decode_u32(12))).get_string_from_utf8())
	metadata.sha256 = Generated.digest(cells)
	var replacement := retag(fixture.bytes,metadata,cells)
	var output := FileAccess.open(source,FileAccess.WRITE)
	if not check(output!=null,"create complete Unicode staged file"): return
	output.store_buffer(replacement); output.close()
	result = bridge.call(&"replace_material_baseline_file",source,target)
	check(not result.get("ok",false) and FileAccess.get_sha256(target)==previous
		and FileAccess.get_file_as_bytes(source)==replacement,"different-directory replacement refuses and preserves both files")
	output = FileAccess.open(unicode_target,FileAccess.WRITE)
	if not check(output!=null,"create existing Unicode target"): return
	output.store_buffer(fixture.bytes); output.close()
	result = bridge.call(&"replace_material_baseline_file",source,unicode_target)
	check(result.get("ok",false) and not FileAccess.file_exists(source)
		and FileAccess.get_file_as_bytes(unicode_target)==replacement,
		"Unicode same-directory atomic replacement consumes the complete source and replaces existing target exactly")
	var first_target := directory.path_join("première-保存.json")
	DirAccess.remove_absolute(first_target)
	result = bridge.call(&"replace_material_baseline_file",unicode_target,first_target)
	check(result.get("ok",false) and not FileAccess.file_exists(unicode_target)
		and FileAccess.get_file_as_bytes(first_target)==replacement,"native atomic first publication creates exact new target")
	DirAccess.remove_absolute(source)
	DirAccess.remove_absolute(unicode_target)
	DirAccess.remove_absolute(first_target)
	for index: int in 4:
		DirAccess.remove_absolute(directory)
		directory = directory.get_base_dir()


func legacy_compatibility(fixture: Dictionary) -> void:
	var label := LABEL+"-legacy"
	check(Setup.write_named(label,fixture.setup).is_empty(),"unchanged legacy Setup-v2 writer works")
	check(store.read_named(label).get("legacy",false) and Setup.read_named(label).setup==fixture.setup,
		"binary sniff delegates legacy Setup-v2 without migration")
	var generated_text := JSON.stringify({"format":Generated.FORMAT,"version":1,"generation":{},"starting_setup":fixture.setup})
	write_bytes(label,generated_text.to_utf8_buffer())
	check(store.read_named(label).get("legacy",false),"binary sniff delegates generated-start-v1 bytes unchanged")
	# Its ordinary strict reader still owns invalid legacy provenance.
	check(Generated.read_named(label).has("error"),"legacy generated reader retains its validation")
	DirAccess.remove_absolute(Setup._path(label))


func scale() -> void:
	for side: int in [512,1024,2048]:
		var extent := Vector2i(side,side)
		var native_capture := capture(extent)
		var started := Time.get_ticks_usec()
		var result: Dictionary = store.stage(native_capture,extent)
		var stage_usec := Time.get_ticks_usec()-started
		if not check(result.has("baseline"),"stage actual %d-square canonical plane" % side): continue
		var setup := Setup.fresh(bridge.default_liquid_policy(),extent)
		started = Time.get_ticks_usec()
		var error: String = store.write_named(LABEL+"-scale",setup,result.baseline)
		var write_usec := Time.get_ticks_usec()-started
		if not check(error.is_empty(),"save %d-square / %s" % [side,error]): continue
		started = Time.get_ticks_usec()
		var loaded: Dictionary = store.read_named(LABEL+"-scale")
		var read_usec := Time.get_ticks_usec()-started
		check(loaded.get("flattened",false) and loaded.baseline.cells==native_capture.cells
			and loaded.baseline.cells.size()==side*side*2,"complete %d-square material format roundtrip" % side)
		print("MATERIAL_BASELINE_FORMAT_PERF ",JSON.stringify({"side":side,"raw_bytes":side*side*2,
			"stage_usec":stage_usec,"save_usec":write_usec,"read_usec":read_usec,
			"file_bytes":file_bytes(LABEL+"-scale").size()}))
	DirAccess.remove_absolute(Setup._path(LABEL+"-scale"))

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("WORKBENCH_MATERIAL_BASELINE: " + label)
	return ok

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not check(ResourceLoader.exists(MODULE), "standalone two-byte material baseline is implemented"):
		print("WORKBENCH_MATERIAL_BASELINE checks=%d failures=%d" % [checks, failures])
		quit(1)
		return
	store = load(MODULE)
	bridge = ClassDB.instantiate(&"CyberDemoBridge") if ClassDB.class_exists(&"CyberDemoBridge") else null
	if not check(bridge != null and bridge.has_method(&"validate_material_baseline"),"source-matched native material validator is available"):
		print("WORKBENCH_MATERIAL_BASELINE checks=%d failures=%d" % [checks, failures])
		quit(1)
		return
	if not check(bridge.has_method(&"replace_material_baseline_file"),"source-matched native atomic replacement is available"):
		print("WORKBENCH_MATERIAL_BASELINE checks=%d failures=%d" % [checks, failures])
		quit(1)
		return
	capture_refusals()
	var fixture := roundtrip_and_history()
	if not fixture.is_empty():
		atomic_replacement(fixture)
		corrupt_files(fixture)
		legacy_compatibility(fixture)
	scale()
	DirAccess.remove_absolute(Setup._path(LABEL))
	print("WORKBENCH_MATERIAL_BASELINE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
