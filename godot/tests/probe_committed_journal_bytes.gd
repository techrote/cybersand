extends SceneTree
const ArtPanel = preload("res://scripts/art_batch_panel.gd")
const Provider = preload("res://scripts/art_provider.gd")
const SOURCE := "user://art-traffic/independent-journal-bytes.jsonl"
var checks := 0
var failures: Array[String] = []
var host: Node
var panel: Window

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool,label: String) -> bool:
	checks += 1
	print("INDEPENDENT_COMMITTED_JOURNAL_CHECK ",label," ",ok)
	if not ok: failures.append(label)
	return ok

func write_bytes(path: String,bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if not check(file != null,"open real fixture for write"): return false
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file = null
	return check(error == OK,"flush real fixture bytes")

func pending_files() -> PackedStringArray:
	var files := PackedStringArray()
	for filename: String in DirAccess.get_files_at(ArtPanel.HISTORY_RECEIPT_DIR):
		if filename.ends_with(".json"): files.append(ArtPanel.HISTORY_RECEIPT_DIR.path_join(filename))
	files.sort()
	return files

func wait_restore() -> void:
	var deadline := Time.get_ticks_msec()+20000
	while panel.provider.resume_active and Time.get_ticks_msec()<deadline: await process_frame
	check(not panel.provider.resume_active,"bounded incremental restoration finishes")

func labels(turns: Array) -> Array[String]:
	var found: Array[String] = []
	for turn: Dictionary in turns:
		for label: String in ["first-valid","second-to-repair"]:
			if str(turn.get("content","")).contains('"label":"'+label+'"'): found.append(label)
	return found

func finish(mode: String,extra: Dictionary = {}) -> void:
	var result := {"case":mode,"checks":checks,"failures":failures,"passed":failures.is_empty()}
	result.merge(extra)
	print("INDEPENDENT_COMMITTED_JOURNAL_RESULT ",JSON.stringify(result))
	if is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	var mode := str(OS.get_cmdline_user_args()[0])
	set_meta("cybersand_feature","shared_workbench")
	check(DirAccess.make_dir_recursive_absolute("user://art-traffic") == OK,"isolated original traffic directory created")
	if not write_bytes(SOURCE,(JSON.stringify({"kind":"conversation","data":{"role":"user","content":"Immutable original"}})+"\n").to_utf8_buffer()):
		await finish(mode)
		return
	var source_hash := FileAccess.get_sha256(SOURCE)
	var cfg := ConfigFile.new()
	cfg.set_value("session","traffic_path",SOURCE)
	check(cfg.save("user://art-provider.cfg") == OK,"isolated saved source profile configured")
	var profile_bytes := FileAccess.get_file_as_bytes("user://art-provider.cfg")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	check(host.shared_workbench.art_batches == null,"callback fixture begins with Art unconstructed")
	for label: String in ["first-valid","second-to-repair"]:
		host.shared_workbench.paint_editor.history_action_finished.emit({"action":"undo","status":"completed","label":label,"applied":1})
	check(host.shared_workbench.art_batches == null,"two native-owner completion callbacks preserve lazy Art")
	var files := pending_files()
	if not check(files.size() == 2,"two independently published durable receipts exist"):
		await finish(mode)
		return
	var first := FileAccess.get_file_as_bytes(files[0])
	var target := FileAccess.get_file_as_bytes(files[1])
	var corrupted := PackedByteArray()
	if mode == "missing-newline": corrupted = target.slice(0,target.size()-1)
	elif mode == "invalid-utf8":
		corrupted = PackedByteArray([255])
		corrupted.append_array(target)
	elif mode == "incomplete-json": corrupted = "{\"schema\":2,\n".to_utf8_buffer()
	else:
		check(false,"known probe mode")
		await finish(mode)
		return
	if not write_bytes(files[1],corrupted):
		await finish(mode)
		return
	panel = host.shared_workbench._ensure_art_batches()
	panel.show()
	await wait_restore()
	var expected := "Malformed pending Art history record" if mode == "incomplete-json" else "Partial or invalid UTF-8 pending Art history record"
	var error: String = panel.input_error
	check(error.contains(expected),"specific byte/parser validation branch refuses committed receipt")
	check(not panel.conversation_loaded and labels(panel.conversation).is_empty(),"fail closed before appending either pending result")
	check(pending_files() == files,"both committed receipt files remain present")
	check(FileAccess.get_file_as_bytes(files[0]) == first,"untouched valid pending receipt remains byte-identical")
	check(FileAccess.get_file_as_bytes(files[1]) == corrupted,"refused partial or invalid pending receipt remains byte-identical")
	check(FileAccess.get_sha256(SOURCE) == source_hash,"original historical archive remains byte-identical during refusal")
	check(FileAccess.get_file_as_bytes("user://art-provider.cfg") == profile_bytes,"profile remains byte-identical during refusal")
	check(DirAccess.get_files_at("user://art-traffic").size() == 1,"refusal creates no new archive segment")
	if not write_bytes(files[1],target):
		await finish(mode)
		return
	panel._ensure_history_loaded()
	await wait_restore()
	panel._drain_pending_history_receipts()
	check(panel.conversation_loaded,"exact retained receipt bytes restore successfully after repair")
	check(labels(panel.conversation) == ["first-valid","second-to-repair"],"repaired recovery produces each visible result exactly once in order")
	check(pending_files().is_empty(),"journal deleted only after complete recovery")
	check(FileAccess.get_sha256(SOURCE) == source_hash,"original archive remains unchanged after complete recovery")
	check(cfg.load("user://art-provider.cfg") == OK,"committed profile remains readable")
	var reader := Provider.new()
	var restored: Array = reader.resume_traffic(str(cfg.get_value("session","traffic_path","")))
	check(reader.resume_ok and labels(restored) == ["first-valid","second-to-repair"],"independent provider replay preserves exactly-once ordered model context")
	reader.free()
	var raw_counts := {"first-valid":0,"second-to-repair":0}
	for name: String in DirAccess.get_files_at("user://art-traffic"):
		for line: String in FileAccess.get_file_as_string("user://art-traffic".path_join(name)).split("\n",false):
			var item: Variant = JSON.parse_string(line)
			if item is Dictionary and item.get("kind") == "history_result" and item.get("data") is Dictionary and raw_counts.has(str(item.data.get("label",""))):
				raw_counts[str(item.data.label)] += 1
	check(raw_counts["first-valid"] == 1 and raw_counts["second-to-repair"] == 1,"each recovered result has exactly one raw history event")
	await finish(mode,{"refusal":error,"original_sha256":source_hash,"raw_counts":raw_counts,"native_scope":"mounted native-backed Workbench completion signal, synthetic immutable receipt fixture"})
