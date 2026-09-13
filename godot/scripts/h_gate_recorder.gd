class_name CyberHGateRecorder
extends RefCounted

const SCHEMA_VERSION: int = 1
const ROOT: String = "user://h-gate"

var session_id: String = ""
var session_root: String = ""
var timeline_path: String = ""
var observation_index: int = 0
var run_index: int = 0
var current_run_id: String = ""
var last_feedback: String = ""

func _utc_stamp() -> String:
	return Time.get_datetime_string_from_system(true).replace("-", "").replace(":", "").replace("T", "-")

func _ensure_dir(path: String) -> bool:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)) == OK

func _write_json(path: String, value: Variant) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	return true

func _append_jsonl(path: String, value: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	file.store_line(JSON.stringify(value))
	return true

func start_session(runtime_identity: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not session_id.is_empty():
		return {"ok": true, "session_id": session_id, "root": session_root}
	session_id = "H-%s" % _utc_stamp()
	session_root = "%s/%s" % [ROOT, session_id]
	if not _ensure_dir(session_root + "/observations") or not _ensure_dir(session_root + "/reveal"):
		return {"ok": false, "error": "could not create H-gate session directory"}
	timeline_path = session_root + "/timeline.jsonl"
	var session: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"session_id": session_id,
		"started_utc": Time.get_datetime_string_from_system(true),
		"platform": OS.get_name(),
		"godot": Engine.get_version_info().get("string", "unknown"),
		"runtime_identity": runtime_identity.duplicate(true),
		"context": context.duplicate(true),
	}
	if not _write_json(session_root + "/session.json", session):
		return {"ok": false, "error": "could not write H-gate session metadata"}
	record_event("session-start", {"context": context.duplicate(true)})
	last_feedback = "Started %s" % session_id
	return {"ok": true, "session_id": session_id, "root": session_root}

func begin_run(context: Dictionary) -> String:
	if session_id.is_empty():
		return ""
	run_index += 1
	current_run_id = "R%03d" % run_index
	record_event("run-start", {"run_id": current_run_id, "context": context.duplicate(true)})
	return current_run_id

func record_event(kind: String, data: Dictionary = {}) -> bool:
	if session_id.is_empty():
		return false
	return _append_jsonl(timeline_path, {
		"schema_version": SCHEMA_VERSION,
		"session_id": session_id,
		"run_id": current_run_id,
		"utc": Time.get_datetime_string_from_system(true),
		"event": kind,
		"data": data.duplicate(true),
	})
