extends RefCounted
## Local diagnostic copy only; never consumed as native authority or API input.
const MAX_MEMORY_BYTES := 16 * 1024 * 1024
const MAX_RECORD_BYTES := 10 * 1024 * 1024
const MAX_FILE_BYTES := 32 * 1024 * 1024
const MAX_RECORDS := 256
const MAX_IMAGES := 32
var records: Array[Dictionary] = []
var dropped := 0
var disk_error := ""
var _bytes := 0
var _sequence := 0
var _session := str(OS.get_process_id()) + "-" + str(Time.get_unix_time_from_system()) + "-" + str(Time.get_ticks_usec())
var _images: Array[String] = []
var _loaded_images := false
var directory := "user://agent-traffic"
var secret_environment_names: Array[String] = ["OPENAI_API_KEY", "NVIDIA_API_KEY"]

func _redact(text: String) -> String:
	var clean := text
	for name: String in secret_environment_names:
		var key := OS.get_environment(name)
		if not key.is_empty():
			clean = clean.replace(key, "[REDACTED API KEY]")
	return clean

func _clean(value: Variant, persist: bool) -> Variant:
	if value is String:
		var text: String = value
		if text.begins_with("data:image/png;base64,"):
			var png := Marshalls.base64_to_raw(text.substr(22))
			var context := HashingContext.new()
			context.start(HashingContext.HASH_SHA256)
			context.update(png)
			var hash_value := context.finish().hex_encode()
			var path := directory + "/" + hash_value + ".png"
			if persist and not _images.has(path):
				DirAccess.make_dir_recursive_absolute(directory)
				if not _loaded_images:
					_loaded_images = true
					for name: String in DirAccess.get_files_at(directory):
						if name.ends_with(".png"):
							_images.append(directory + "/" + name)
				var image_file := FileAccess.open(path, FileAccess.WRITE)
				if image_file != null:
					image_file.store_buffer(png)
					image_file.close()
					if not _images.has(path):
						_images.append(path)
					while _images.size() > MAX_IMAGES:
						DirAccess.remove_absolute(_images.pop_front())
				else:
					disk_error = "Cannot retain PNG: " + error_string(FileAccess.get_open_error())
			return {"image_payload": "original PNG stored separately" if persist else "fake transport; not persisted",
				"sha256": hash_value, "bytes": png.size(), "file": ProjectSettings.globalize_path(path) if persist else ""}
		return _redact(text)
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			var name := str(key)
			result[_redact(name)] = "[REDACTED]" if name.to_lower() in ["authorization", "api_key", "api-key"] else _clean(value[key], persist)
		return result
	if value is Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedStringArray:
		var result: Array = []
		for item: Variant in value:
			result.append(_clean(item, persist))
		return result
	return value

func append(kind: String, payload: Variant, identity: Dictionary, persist: bool) -> Dictionary:
	_sequence += 1
	var record := {"session": _session, "sequence": _sequence, "utc": Time.get_datetime_string_from_system(true) + "Z",
		"monotonic_ms": Time.get_ticks_msec(), "kind": kind, "identity": identity.duplicate(true),
		"payload": _clean(payload, persist)}
	var raw := JSON.stringify(record)
	if raw.to_utf8_buffer().size() > MAX_RECORD_BYTES:
		record.payload = {"omitted": "diagnostic record exceeds explicit 10 MiB bound", "original_bytes": raw.to_utf8_buffer().size(), "sha256": raw.sha256_text()}
		raw = JSON.stringify(record)
	while not records.is_empty() and (records.size() >= MAX_RECORDS or _bytes + raw.to_utf8_buffer().size() > MAX_MEMORY_BYTES):
		_bytes -= JSON.stringify(records.pop_front()).to_utf8_buffer().size()
		dropped += 1
	records.append(record)
	_bytes += raw.to_utf8_buffer().size()
	if persist:
		_store(raw)
	return record.duplicate(true)

func _store(raw: String) -> void:
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		disk_error = "Cannot create local traffic directory"
		return
	var path := directory + "/events.jsonl"
	var existing := FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null
	var existing_size: int = existing.get_length() if existing != null else 0
	if existing != null:
		existing.close()
	if existing_size + raw.to_utf8_buffer().size() + 1 > MAX_FILE_BYTES:
		var previous := directory + "/events.previous.jsonl"
		if FileAccess.file_exists(previous):
			DirAccess.remove_absolute(previous)
		if DirAccess.rename_absolute(path, previous) != OK:
			disk_error = "Cannot rotate local traffic log"
			return
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file := FileAccess.open(path, mode)
	if file == null:
		disk_error = "Cannot open local traffic log: " + error_string(FileAccess.get_open_error())
		return
	file.seek_end()
	file.store_line(raw)
	file.close()

func export_jsonl(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_line(JSON.stringify({"diagnostic_export": true, "retained_events": records.size(),
		"dropped_events": dropped, "disk_error": disk_error, "image_retention": "last32 PNGs; older links may expire",
		"local_log_directory": ProjectSettings.globalize_path(directory), "redaction": "authorization fields and configured API key; image bytes in separate PNGs"}))
	for record: Dictionary in records:
		file.store_line(JSON.stringify(record))
	file.close()
	return OK
