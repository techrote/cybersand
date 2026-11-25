extends SceneTree

# Isolated subprocess only. The parent applies an actual OS write limit or
# destination lock after valid disposable fixtures exist, then releases us.
const Provider = preload("res://scripts/art_provider.gd")
const Archive = preload("res://scripts/art_traffic_archive.gd")

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
