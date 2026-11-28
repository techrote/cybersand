extends SceneTree

# Isolated subprocess only. The parent applies an actual OS write limit or
# destination lock after valid disposable fixtures exist, then releases us.
const Provider = preload("res://scripts/art_provider.gd")
const Archive = preload("res://scripts/art_traffic_archive.gd")
const Batch = preload("res://scripts/art_batch_panel.gd")

func _initialize() -> void:
	_run.call_deferred()

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if not path.is_empty() and FileAccess.file_exists(path) else PackedByteArray()

func _digest(bytes: PackedByteArray) -> String:
	return "".sha256_text() if bytes.is_empty() else Archive.digest(bytes)

func _run() -> void:
	var operation := OS.get_environment("ART_STORAGE_OPERATION")
	if operation in ["settings", "pending-history"]:
		await _run_panel_storage(operation)
		return
	var marker := OS.get_environment("ART_STORAGE_CONTINUE")
	DirAccess.make_dir_recursive_absolute("user://art-traffic")
	var provider := Provider.new()
	root.add_child(provider)
	var source := "user://art-traffic/source.jsonl"
	var target := "user://export.jsonl"
	var content := "synthetic-storage-fixture-".repeat(100)
	var expected := ""
	if operation == "export":
		expected = JSON.stringify({"kind":"conversation","data":{"role":"user","content":content}}) + "\n"
		_write(source, expected)
		_write(target, JSON.stringify({"kind":"conversation","data":{"role":"user","content":"previous complete export"}}) + "\n")
		provider.prepare_resume(source)
	elif operation == "append":
		if not provider.log_event("conversation", {"role":"user","content":"previous complete event"}):
			printerr("ART_STORAGE_SETUP_REFUSED ", provider.log_warning)
			quit(2)
			return
		target = provider.log_path
	elif operation == "new-event":
		target = ""
	else:
		quit(2)
		return
	var before := _bytes(target)
	var source_hash := FileAccess.get_sha256(source) if operation == "export" else ""
	print("ART_STORAGE_READY ", JSON.stringify({"operation":operation,
		"target":ProjectSettings.globalize_path(target) if not target.is_empty() else "",
		"old_bytes":before.size(),"old_sha256":_digest(before)}))
	var deadline := Time.get_ticks_msec() + 15000
	while not FileAccess.file_exists(marker) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not FileAccess.file_exists(marker):
		quit(2)
		return
	var success := false
	var error_text := ""
	if operation == "export":
		success = provider.export_traffic(target) == OK
		error_text = provider.export_message
	else:
		success = provider.log_event("conversation", {"role":"user","content":content})
		error_text = provider.log_warning
		if operation == "new-event": target = provider.log_path
	var after := _bytes(target)
	var replay := Provider.new()
	root.add_child(replay)
	var recovered_count := -1
	var replay_ok := false
	if not target.is_empty() and FileAccess.file_exists(target):
		if operation == "export":
			# Export may be anywhere; copy only our fixture into the archive route.
			_write("user://art-traffic/replay-copy.jsonl", after.get_string_from_utf8())
			recovered_count = replay.resume_traffic("user://art-traffic/replay-copy.jsonl").size()
		else:
			recovered_count = replay.resume_traffic(target).size()
		replay_ok = replay.resume_ok
	var files := DirAccess.get_files_at("user://art-traffic")
	var partials: Array[String] = []
	for name: String in files:
		if name.contains(".partial-"): partials.append(name)
	for name: String in DirAccess.get_files_at("user://"):
		if name.contains(".partial-"): partials.append(name)
	print("ART_STORAGE_RESULT ", JSON.stringify({"operation":operation,"success":success,
		"message":error_text,"bytes":after.size(),"old_preserved":after == before,
		"old_prefix_preserved":after.size() >= before.size() and after.slice(0,before.size()) == before,
		"sha256":_digest(after),"expected_export_equal":after == expected.to_utf8_buffer() if operation == "export" else false,
		"source_unchanged":FileAccess.get_sha256(source) == source_hash if operation == "export" else true,
		"log_path_empty":provider.log_path.is_empty(),"last_event_stored":provider.last_event_stored,
		"recovered_count":recovered_count,"replay_ok":replay_ok,"partial_files":partials}))
	provider.free()
	replay.free()
	quit()

func _wait_for(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < deadline:
		await process_frame
	return FileAccess.file_exists(path)

func _receipt(value: int, frozen: bool) -> Dictionary:
	var identity := str(value).pad_zeros(20) + "-" + str(value).pad_zeros(32)
	var receipt := {"_history_receipt_id":identity,"action":"undo","status":"completed",
		"applied":1,"token":value,"label":"Nonsecret receipt-shaped storage fixture; no native edit executed. ".repeat(30)}
	var item := {"id":identity,"source":"user://art-traffic/fixture.jsonl","epoch":7,"receipt":receipt}
	if frozen:
		var content := "Frozen receipt projection fixture · " + str(value)
		item["schema"] = 2
		item["turn"] = {"role":"user","content":content,"_history_receipt_id":identity}
		receipt["_history_world_epoch"] = 7
		receipt["_history_turn_sha256"] = content.sha256_text()
	return item

func _panel_snapshot(panel: Window, operation: String, item: Dictionary) -> Dictionary:
	if operation == "settings":
		var path := "user://art-provider.cfg"
		var config := ConfigFile.new()
		var readable := config.load(path) == OK
		return {"loadable":readable,"value":config.get_value("fixture","value",-1) if readable else -1,
			"bytes":_bytes(path).size(),"sha256":_digest(_bytes(path)),
			"roundtrip":readable and config.get_value("fixture","shape",[]) == [true,3,"quoted \"text\" · 雪"]}
	var read: Dictionary = panel._read_pending_history_receipts()
	var values: Array[int] = []
	var schema := 0
	var projection := false
	for row: Dictionary in read.rows:
		values.append(int(row.receipt.token))
		if row.id == item.id:
			schema = int(row.schema)
			projection = schema == 2 and row.turn == item.get("turn",{}) and row.order == item.get("order","")
	values.sort()
	return {"loadable":bool(read.ok),"values":values,"schema":schema,"frozen_projection":projection,
		"item_has_file":item.has("file"),"item_has_order":item.has("order")}

func _run_panel_storage(operation: String) -> void:
	# Mount the actual panel lifecycle so its owned controls are released cleanly.
	# No provider request or native editing command is made by this storage probe.
	var panel := Batch.new()
	root.add_child(panel)
	panel.set_process(false)
	var marker := OS.get_environment("ART_STORAGE_CONTINUE")
	var fault := OS.get_environment("ART_STORAGE_FAULT")
	var previous := _receipt(7,false)
	var candidate := _receipt(7,false) if fault == "existing-receipt" else _receipt(8,true)
	var target := "user://art-provider.cfg"
	var setup_ok := false
	var saved_settings_text := ""
	if operation == "settings":
		panel.settings.set_value("fixture","value",7)
		panel.settings.set_value("fixture","notes","Nonsecret preference storage fixture. ".repeat(50))
		panel.settings.set_value("fixture","shape",[true,3,"quoted \"text\" · 雪"])
		setup_ok = panel._save_settings() == OK
		saved_settings_text = panel.settings.encode_to_text()
		panel.settings.set_value("fixture","value",8)
	else:
		setup_ok = Batch._persist_history_receipt(previous)
		target = str(previous.get("file",""))
	if not setup_ok:
		push_error("Art panel storage fixture could not establish its old complete file")
		panel.queue_free()
		await process_frame
		quit(2)
		return
	var before := _bytes(target)
	var stale := target + ".tmp" if operation == "settings" else Batch.HISTORY_RECEIPT_DIR.path_join("pending-stale.partial")
	_write(stale,"Unrelated stale staging fixture; retain byte-for-byte.\n")
	var stale_bytes := _bytes(stale)
	var clock_before: int = Batch._history_receipt_clock_us
	print("ART_STORAGE_READY ",JSON.stringify({"operation":operation,"target":ProjectSettings.globalize_path(target),
		"old_bytes":before.size(),"old_sha256":_digest(before)}))
	if not await _wait_for(marker):
		quit(2)
		return
	var success := panel._save_settings() == OK if operation == "settings" else Batch._persist_history_receipt(candidate)
	var first := _panel_snapshot(panel,operation,candidate)
	first["success"] = success
	first["message"] = panel.input_error if operation == "settings" else "" if success else "Pending receipt was not admitted; keep its in-memory item for retry."
	first["old_preserved"] = _bytes(target) == before
	first["clock_unchanged"] = Batch._history_receipt_clock_us == clock_before
	var cache_guard := true
	if operation == "settings":
		cache_guard = panel._settings_were_saved and panel._saved_settings_text == \
			(panel.settings.encode_to_text() if success else saved_settings_text)
		if not success:
			# The actual OS fault is still installed. Reverting to the committed
			# configuration must use the current cache, not attempt another write.
			panel.settings.set_value("fixture","value",7)
			var reverted := panel._save_settings() == OK
			first["cached_revert_success"] = reverted
			first["cached_revert_cleared_owned_error"] = panel.input_error.is_empty()
			cache_guard = cache_guard and reverted and panel.input_error.is_empty() \
				and _bytes(target) == before and panel._saved_settings_text == saved_settings_text
			panel.input_error = "Unrelated authoring refusal must survive a settings no-op"
			var unrelated := panel.input_error
			cache_guard = panel._save_settings() == OK and panel.input_error == unrelated and cache_guard
			panel.settings.set_value("fixture","value",8)
			panel.input_error = first.message
	print("ART_STORAGE_PANEL_PHASE ",JSON.stringify(first))
	if not await _wait_for(marker + ".retry"):
		quit(2)
		return
	var retried := success
	if not success:
		candidate = _receipt(8,true)
		retried = panel._save_settings() == OK if operation == "settings" else Batch._persist_history_receipt(candidate)
	var final := _panel_snapshot(panel,operation,candidate)
	final["success"] = retried
	final["old_preserved"] = _bytes(target) == before
	final["message"] = panel.input_error if operation == "settings" else ""
	if operation == "settings":
		cache_guard = cache_guard and panel._settings_were_saved \
			and panel._saved_settings_text == panel.settings.encode_to_text()
	var guards_preserved := true
	if operation == "settings":
		var committed := _bytes(target)
		panel.settings.set_value("fixture","notes","x".repeat(Batch.MAX_PROFILE_BYTES))
		guards_preserved = panel._save_settings() != OK and _bytes(target) == committed
		panel._profile_session_error = "Unrelated retained profile admission refusal"
		guards_preserved = panel._save_settings() == ERR_FILE_CANT_READ and _bytes(target) == committed and guards_preserved
	else:
		var bad := _receipt(9,true)
		bad.turn.content += " untrusted mutation"
		guards_preserved = not Batch._persist_history_receipt(bad) and not bad.has("file")
		var duplicate := _receipt(7,false)
		guards_preserved = not Batch._persist_history_receipt(duplicate) and _bytes(target) == before and guards_preserved
	var partials: Array[String] = []
	for directory: String in ["user://",Batch.HISTORY_RECEIPT_DIR]:
		if not DirAccess.dir_exists_absolute(directory): continue
		for name: String in DirAccess.get_files_at(directory):
			var path := directory.path_join(name)
			if path != stale and (name.ends_with(".tmp") or name.ends_with(".partial")): partials.append(name)
	print("ART_STORAGE_RESULT ",JSON.stringify({"operation":operation,"first":first,"retry":final,
		"guards_preserved":guards_preserved,"stale_preserved":_bytes(stale) == stale_bytes,"partial_files":partials,
		"settings_cache_guard":cache_guard,
		"scope":"Mounted panel private storage methods; nonsecret fixtures, no provider request or native edit"}))
	panel.queue_free()
	await process_frame
	await process_frame
	quit()
