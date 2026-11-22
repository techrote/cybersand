class_name CyberObjectShardCapture
extends RefCounted

# Prospective action evidence. A bounded JSONL stream retains the action order
# from session start; the older observation ring cannot reconstruct that order.
# Replay reissues named operations and manual steps. Cross-platform Rapier bit
# identity, wall-clock mouse timing and unrecorded historic input are not claimed.
const SCHEMA: String = "objectshard-action-trace-v1"
const MAX_BYTES: int = 32 * 1024 * 1024
const MAX_RECORDS: int = 100000
const MAX_ACTIONS: int = 8192
const REPLAY_ACTIONS: Array[String] = ["edit", "ignite", "inspect", "pause", "burner", "erase_shard"]

var path: String = ""
var stream: FileAccess
var header: Dictionary = {}
var actions: Array[Dictionary] = []
var records: int = 0
var bytes_written: int = 0
var dropped_actions: int = 0
var complete: bool = false
var reason: String = "Capture not started"
var io_usec: int = 0


static func json_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[str(key)] = json_value(value[key])
		return result
	if value is Array or value is PackedByteArray or value is PackedInt32Array or value is PackedFloat32Array:
		var result: Array = []
		for item: Variant in value:
			result.append(json_value(item))
		return result
	if value is Vector2 or value is Vector2i:
		return [value.x, value.y]
	if value is Transform2D:
		return {"x": value.origin.x, "y": value.origin.y, "rotation": value.get_rotation()}
	if value is Rect2i or value is Rect2:
		return {"x": value.position.x, "y": value.position.y, "width": value.size.x, "height": value.size.y}
	return value


func begin(identity: Dictionary, output_path: String = "") -> Dictionary:
	close()
	header = json_value(identity)
	header["schema"] = SCHEMA
	header["replay_limits"] = "Named material actions and manual-step order; Rapier cross-platform bit identity and wall-clock input timing are not promised."
	path = output_path
	actions.clear()
	records = 0
	bytes_written = 0
	dropped_actions = 0
	io_usec = 0
	complete = not output_path.is_empty()
	reason = "Recording from session start" if complete else "Memory action window only; no full trace"
	if complete:
		stream = FileAccess.open(output_path, FileAccess.WRITE)
		if stream == null:
			complete = false
			reason = "Capture file unavailable: " + error_string(FileAccess.get_open_error())
	write("header", 0, header)
	return metadata()


func action(tick: int, name: String, parameters: Dictionary, result: Dictionary) -> void:
	var row: Dictionary = {"action": name, "parameters": json_value(parameters), "result": json_value(result), "tick": tick}
	if actions.size() >= MAX_ACTIONS:
		actions.pop_front()
		dropped_actions += 1
	actions.append(row)
	write("action", tick, row)


func write(kind: String, tick: int, detail: Dictionary) -> void:
	if stream == null:
		return
	var started: int = Time.get_ticks_usec()
	var row: Dictionary = {"sequence": records, "kind": kind, "tick": tick, "detail": json_value(detail)}
	var line: String = JSON.stringify(row) + "\n"
	var size: int = line.to_utf8_buffer().size()
	if records >= MAX_RECORDS or bytes_written + size > MAX_BYTES:
		complete = false
		reason = "Trace limit reached; simulation continues and the retained prefix is explicitly incomplete"
		stream.close()
		stream = null
		return
	stream.store_string(line)
	bytes_written += size
	records += 1
	if records % 60 == 0 or kind == "failure" or kind == "footer":
		stream.flush()
	io_usec += Time.get_ticks_usec() - started
	if stream.get_error() != OK:
		complete = false
		reason = "Trace write failed; retained prefix is incomplete"
		stream.close()
		stream = null


func checkpoint(tick: int, summary: Dictionary) -> void:
	write("checkpoint", tick, summary)
	if stream != null:
		stream.flush()


func metadata() -> Dictionary:
	return {"schema": SCHEMA, "path": path, "complete_prefix": complete, "reason": reason,
		"records": records, "bytes": bytes_written, "max_bytes": MAX_BYTES, "max_records": MAX_RECORDS,
		"action_window": actions.size(), "dropped_action_records": dropped_actions, "io_usec": io_usec}


func close() -> void:
	if stream != null:
		write("footer", 0, {"complete_prefix": complete, "reason": reason})
		if stream != null:
			stream.close()
	stream = null


static func read_trace(input_path: String, expected_source: String) -> Dictionary:
	var input: FileAccess = FileAccess.open(input_path, FileAccess.READ)
	if input == null or input.get_length() > MAX_BYTES:
		return {"ok": false, "outcome": "UnavailableOrOversize"}
	var rows: Array[Dictionary] = []
	while not input.eof_reached():
		var line: String = input.get_line()
		if line.is_empty():
			continue
		var parser := JSON.new()
		if parser.parse(line) != OK:
			return {"ok": false, "outcome": "MalformedOrTruncatedTrace"}
		var parsed: Variant = parser.data
		if not parsed is Dictionary or rows.size() >= MAX_RECORDS or not _integer(parsed.get("sequence"), 0, MAX_RECORDS) or int(parsed.sequence) != rows.size():
			return {"ok": false, "outcome": "MalformedOrTruncatedTrace"}
		if not parsed.get("detail") is Dictionary or not _integer(parsed.get("tick"), 0, 9007199254740991):
			return {"ok": false, "outcome": "MalformedRecord"}
		if str(parsed.get("kind", "")) not in ["header", "action", "event", "step_requested", "step_completed", "checkpoint", "footer", "failure"]:
			return {"ok": false, "outcome": "UnsupportedRecord"}
		if str(parsed.get("kind", "")) == "action" and not _valid_action(parsed.detail):
			return {"ok": false, "outcome": "UnsupportedOrMalformedAction"}
		rows.append(parsed)
	input.close()
	if rows.is_empty() or str(rows[0].get("kind", "")) != "header":
		return {"ok": false, "outcome": "MissingHeader"}
	var identity: Dictionary = rows[0].get("detail", {})
	if str(identity.get("schema", "")) != SCHEMA or expected_source.length() != 40 or str(identity.get("source_revision", "")) != expected_source:
		return {"ok": false, "outcome": "SourceMismatch"}
	if not _integer(identity.get("scenario"), 0, 6) or not _integer(identity.get("seed"), 0, 9007199254740991) or not _integer(identity.get("width", 192), 64, 512) or not _integer(identity.get("height", 128), 64, 512):
		return {"ok": false, "outcome": "MalformedHeader"}
	# A flushed checkpoint is an explicit bounded prefix suitable for reproducing
	# an exported incident. An arbitrary truncated final line is never accepted.
	if str(rows[-1].get("kind", "")) not in ["checkpoint", "footer", "failure"]:
		return {"ok": false, "outcome": "UnsealedPrefix"}
	return {"ok": true, "header": identity, "rows": rows,
		"replay_limits": identity.get("replay_limits", "")}


static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high


static func _position(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _integer(value[0], -262144, 262144) and _integer(value[1], -262144, 262144)


static func _valid_action(detail: Dictionary) -> bool:
	var name: String = str(detail.get("action", ""))
	if name not in REPLAY_ACTIONS or not detail.get("parameters") is Dictionary or not detail.get("result") is Dictionary:
		return false
	var parameters: Dictionary = detail.parameters
	if name in ["edit", "ignite", "inspect", "erase_shard"] and not _position(parameters.get("position")):
		return false
	if name == "edit":
		return _integer(parameters.get("material"), 0, 255) and _integer(parameters.get("state_a"), 0, 65535) and _integer(parameters.get("state_b"), 0, 255) and _integer(parameters.get("temperature"), -32768, 32767)
	if name == "pause":
		return parameters.get("paused") is bool
	if name == "burner":
		var cells: Variant = parameters.get("cells")
		if not cells is Array or cells.size() > 64 or not parameters.get("enabled") is bool:
			return false
		for point: Variant in cells:
			if not _position(point):
				return false
	return true
