extends Node
## One cancellable inference request; native drawing remains the existing executor.
signal finished(id: int, text: String, response: Dictionary, error: String)
signal traffic_changed
var active := false
var serial := 0
var request: HTTPRequest
var secrets: Array[String] = []
var traffic := ""
var readable := ""
var log_path := ""
var parent_log_path := "" # Previous immutable JSONL segment; never copied on reopen.
var log_warning := ""
var last_event_stored := false
var commit_segment: Callable
var resume_ok := true
var resume_active := false
var _resume_archive: RefCounted
var _resume_restored := {}
var _resumed_turns: Array = []
var _image_queue: Array[Dictionary] = []
var _image_pending := {}
var _image_cache := {}
var _image_file: FileAccess
var _image_parts: Array[PackedByteArray] = []
var _image_size := 0
var resume_error := ""
var resume_warning := ""
var export_active := false
var export_error: Error = OK
var export_message := ""
var _segment_id := ""
var _event_index := 0
var _written_size := -1
var _write_broken := false
# A first history event may reach disk before its profile checkpoint can be
# replaced. Retain exactly that bounded segment for checkpoint retry rather
# than leaking a new orphan on every pending-receipt timer tick.
var _pending_history_segment := {}
var _conversation_turns := 0
var _conversation_bytes := 0
var _validated_segments: Array[Dictionary] = []
# Track only journalled receipts, never every event in a potentially huge
# archive. Replay builds a provisional table and publishes it only after the
# entire linked conversation has passed validation.
const MAX_HISTORY_RECEIPTS := 4096
const MAX_HISTORY_RECEIPT_BYTES := 262144
const MAX_PENDING_HISTORY_SEGMENT_BYTES := 2 * 1024 * 1024 + MAX_HISTORY_RECEIPT_BYTES + 1024
static var _history_id_pattern := RegEx.create_from_string("^[0-9]{20}-[0-9a-f]{32}$")
var _history_receipts := {}
var _resume_history_receipts := {}
var _export_archive: RefCounted
var _export_output: FileAccess
var _export_temporary := ""
var _export_destination := ""
var _export_bytes := 0
const Archive = preload("res://scripts/art_traffic_archive.gd")
const MAX_CONVERSATION_TURNS := 16384
const MAX_CONVERSATION_BYTES := 16 * 1024 * 1024
var last_request_offset := -1
var resumed_last_result := ""
var usage: Dictionary = {}
var retry_after_seconds := 0.0
var requested_model := ""
var returned_model := ""
const INSTRUCTIONS := 'Create the user-requested subject as an original 2D pixel-art composition, filling the supplied work area. Build complex subjects from as many simple primitives as needed. Return ONLY a JSON array, no prose. Each object has shape and material. Literal shape values and required integer parameters: rectangle uses x0,y0,x1,y1 (inclusive endpoints); disc uses x,y,radius; line uses x0,y0,x1,y1; pixels uses points:[[x,y],...]. Choose your own coordinates and dimensions to depict the subject; these are field definitions, not a drawing to copy. Use the selected drawing material ID. Material 0 erases when enabled. Operations execute in order. Stay inside the supplied work area; keep every disc including its radius inside it. Existing other materials and protected regions cannot be overwritten. Do not call external tools.'

static func payload(provider: String, model: String, prompt: String, instructions: String, tokens: int, png: String = "", context: Array = []) -> Dictionary:
	if provider == "OpenAI":
		var content: Array = [{"type":"input_text","text":prompt}]
		if not png.is_empty(): content.append({"type":"input_image","image_url":"data:image/png;base64,"+png})
		return {"model":model,"instructions":instructions,"input":context + [{"role":"user","content":content}],"max_output_tokens":tokens,"store":false}
	var content: Variant = prompt
	if not png.is_empty(): content = [{"type":"text","text":prompt},{"type":"image_url","image_url":{"url":"data:image/png;base64,"+png}}]
	var packet := {"model":model,"messages":[{"role":"system","content":instructions}] + context + [{"role":"user","content":content}],"max_tokens":tokens,"stream":false}
	if provider == "NVIDIA" and model in ["nvidia/nemotron-3.5-lightning-30b-a3b","nvidia/nemotron-3.5-super-vl-120b-a12b"]:
		packet.chat_template_kwargs = {"enable_thinking":false}
	return packet

static func decode(provider: String, data: Dictionary) -> Dictionary:
	if data.has("error") and data.error != null: return {"text":"","error":JSON.stringify(data.error)}
	var text := ""
	var error := ""
	if provider == "OpenAI":
		var output: Variant = data.get("output",[])
		if not output is Array: return {"text":"","error":"Malformed Responses output; inspect Traffic."}
		for item: Variant in output:
			if not item is Dictionary or not item.get("content",[]) is Array: continue
			for block: Variant in item.get("content",[]):
				if not block is Dictionary: continue
				if block.get("type")=="output_text": text += str(block.get("text",""))
				elif block.get("type")=="refusal": error = str(block.get("refusal","Provider refused."))
		if data.get("status")=="incomplete": error = "Response incomplete: "+JSON.stringify(data.get("incomplete_details",{}))+". Increase Toks if output was truncated; nothing drawn."
	else:
		var choices: Variant = data.get("choices",[])
		if not choices is Array: return {"text":"","error":"Malformed Chat Completions choices; inspect Traffic."}
		if not choices.is_empty() and choices[0] is Dictionary:
			var message: Variant = choices[0].get("message",{})
			if not message is Dictionary: return {"text":"","error":"Malformed assistant message; inspect Traffic."}
			var content: Variant = message.get("content","")
			if content is String: text = content
			elif content is Array:
				for block: Variant in content:
					if block is Dictionary: text += str(block.get("text",""))
			if choices[0].get("finish_reason")=="length": error = "Response reached Toks limit; nothing drawn. Increase Toks and retry."
	if text.is_empty() and error.is_empty(): error = "Provider returned no text. Inspect Traffic for refusal, reasoning usage or provider details."
	return {"text":text,"error":error}

static func operations(text: String, default_material: int = 58) -> Variant:
	var clean := text.strip_edges()
	if clean.contains("</think>"): clean = clean.substr(clean.rfind("</think>")+8).strip_edges()
	if clean.begins_with("```"):
		var lines := clean.split("\n")
		if lines.size()>2: clean = "\n".join(lines.slice(1,lines.size()-1))
	var parser := JSON.new()
	if parser.parse(clean)!=OK:
		# Accept a complete array followed by stray wrapper/prose, never a truncated array.
		if not clean.begins_with("[") or parser.parse(clean.left(clean.rfind("]")+1))!=OK: return null
	var value: Variant = parser.data
	if value is Dictionary and value.has("operations"): value = value.operations
	if value is Dictionary and (value.has("shape") or value.has("type")): value = [value]
	if value is Array:
		for op: Variant in value:
			if not op is Dictionary: continue
			if not op.has("shape"): op.shape = op.get("type",op.get("operation",""))
			if op.shape is String:
				op.shape = op.shape.trim_prefix("draw_")
				op.shape = {"rect":"rectangle","circle":"disc","pixel":"pixels"}.get(op.shape,op.shape)
			if not op.has("material"): op.material = default_material
	return value

func redact(value: String) -> String:
	# Provider and panel both redact. Preserve existing markers on subsequent calls.
	var pieces := value.split("[redacted]")
	for index: int in range(pieces.size()):
		if not pieces[index].is_empty(): pieces[index] = _redact_unmarked(pieces[index])
	return "[redacted]".join(pieces)

func _redact_unmarked(value: String) -> String:
	var clean := value
	for secret: String in secrets:
		if not secret.is_empty():
			clean = clean.replace(secret, "[redacted]")
			if secret.uri_encode() != secret: clean = clean.replace(secret.uri_encode(), "[redacted]")
	for pattern: String in ['(?i)Bearer[ \t]+[A-Za-z0-9._~+/-]+=*','sk-[A-Za-z0-9_-]{12,}','nvapi-[A-Za-z0-9_-]+']:
		var regex := RegEx.new()
		regex.compile(pattern)
		clean = regex.sub(clean,"[redacted]",true)
	var fields := RegEx.new()
	fields.compile('(?i)(["?&](?:api[_-]?key|access_token|token|authorization|password)[" ]*[:=][ "]*)[^"&,}\n ]+')
	clean = fields.sub(clean,'$1[redacted]',true)
	var userinfo := RegEx.new()
	userinfo.compile('(https?://)[^/@\\s]+:[^/@\\s]+@')
	return userinfo.sub(clean,'$1[redacted]@',true)

func _redacted_value(value: Variant) -> Variant:
	if value is String: return redact(value)
	if value is Dictionary:
		var clean := {}
		for key: Variant in value:
			var item: Variant = value[key]
			var credential: bool = str(key).to_lower() in ["api_key", "apikey", "api-key", "access_token", "token", "authorization", "password"]
			clean[key] = "[redacted]" if credential and item is String else _redacted_value(item)
		return clean
	if value is Array:
		var clean: Array = []
		for item: Variant in value: clean.append(_redacted_value(item))
		return clean
	return value

func _sanitized_event_data(kind: String, data: Variant) -> Variant:
	# Envelope IDs, roles, offsets and segment paths are structural, not free text.
	if kind == "history_result" and data is Dictionary:
		var clean: Dictionary = _redacted_value(data)
		for field: String in ["_history_receipt_id","_history_world_epoch","_history_turn_sha256"]:
			if data.has(field): clean[field] = data[field]
		return clean
	if kind == "conversation" and data is Dictionary:
		var clean: Dictionary = data.duplicate(true)
		if clean.get("content") is String: clean.content = redact(clean.content)
		return clean
	if kind == "conversation_edited" and data is Dictionary:
		var clean: Dictionary = data.duplicate(true)
		if clean.get("turns") is Array:
			for index: int in range(clean.turns.size()): clean.turns[index] = _sanitized_event_data("conversation", clean.turns[index])
		if clean.get("last_result") is String: clean.last_result = redact(clean.last_result)
		return clean
	return _redacted_value(data)

func new_log_path() -> String:
	var folder := "user://art-traffic"
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return ""
	for _attempt in range(16):
		var candidate := folder + "/" + Crypto.new().generate_random_bytes(16).hex_encode() + ".jsonl"
		if not FileAccess.file_exists(candidate): return candidate
	return ""

static func valid_traffic_path(path: String) -> bool:
	return Archive.valid_path(path)

static func valid_history_receipt_id(identity: Variant) -> bool:
	return identity is String and _history_id_pattern.search(identity) != null

func watch_history_receipt(item: Dictionary) -> bool:
	var identity: Variant = item.get("id")
	var schema: Variant = item.get("schema",1)
	if not valid_history_receipt_id(identity) or not item.get("receipt") is Dictionary \
			or item.receipt.get("_history_receipt_id") != identity \
			or not item.get("source") is String or not valid_traffic_path(item.source) \
			or not Archive.integer(item.get("epoch")) or (schema != 1 and schema != 2):
		log_warning = "Invalid pending history receipt identity, session or epoch."
		return false
	# Schema 2 freezes the sanitized raw result and user-visible projection at
	# capture. Process-local secrets can change or disappear before recovery;
	# applying today's redactor would change the immutable transaction identity.
	var recorded: Dictionary = item.receipt.duplicate(true) if schema == 2 else _sanitized_event_data("history_result",item.receipt)
	var encoded := JSON.stringify(recorded)
	if encoded.to_utf8_buffer().size() > MAX_HISTORY_RECEIPT_BYTES:
		log_warning = "Pending history receipt exceeds its 256 KiB limit."
		return false
	var content := ""
	var turn_event_sha256 := ""
	if schema == 2:
		if not Archive.integer(recorded.get("_history_world_epoch")) or recorded._history_world_epoch != item.epoch \
				or not item.get("turn") is Dictionary or item.turn.size() != 3 \
				or item.turn.get("role") != "user" or not item.turn.get("content") is String \
				or item.turn.get("_history_receipt_id") != identity \
				or not recorded.get("_history_turn_sha256") is String:
			log_warning = "Invalid frozen history result projection or captured world epoch."
			return false
		content = item.turn.content
		if content.to_utf8_buffer().size() > MAX_HISTORY_RECEIPT_BYTES or content.sha256_text() != recorded._history_turn_sha256:
			log_warning = "Frozen history result projection differs from its native receipt digest."
			return false
		turn_event_sha256 = JSON.stringify(item.turn).sha256_text()
	else:
		content = redact("Canvas result (world epoch %d): Human %s: %s" % [int(item.epoch),str(recorded.get("action","undo")),encoded])
	var target := {"schema":int(schema),"source":item.source,"raw_sha256":encoded.sha256_text(),"turn_sha256":content.sha256_text(),"turn_event_sha256":turn_event_sha256,"raw":false,"turn":false}
	if _history_receipts.has(identity):
		var known: Dictionary = _history_receipts[identity]
		if known.schema != target.schema or known.source != target.source or known.raw_sha256 != target.raw_sha256 or known.turn_sha256 != target.turn_sha256:
			log_warning = "Pending history receipt identity was reused with different data or session."
			return false
		return true
	if _history_receipts.size() >= MAX_HISTORY_RECEIPTS:
		log_warning = "Pending history receipt tracking reached its 4096-entry limit."
		return false
	_history_receipts[identity] = target
	# A newly confirmed native result can arrive while an earlier archive is
	# restoring. It cannot already occur in the prefix read before it existed.
	if resume_active: _resume_history_receipts[identity] = target.duplicate(true)
	return true

func history_receipt_state(identity: String) -> Dictionary:
	var state: Dictionary = _history_receipts.get(identity,{})
	return {"raw":bool(state.get("raw",false)),"turn":bool(state.get("turn",false))}

func has_history_receipt(identity: String) -> bool:
	return _history_receipts.has(identity)

func forget_history_receipt(identity: String) -> void:
	_history_receipts.erase(identity)
	_resume_history_receipts.erase(identity)

func _history_event_identity(kind: String, data: Variant) -> String:
	if not data is Dictionary: return ""
	if kind == "history_result" or (kind == "conversation" and data.has("_history_receipt_id")):
		return str(data.get("_history_receipt_id",""))
	if kind != "conversation" or not data.get("content") is String: return ""
	# Earlier journal writers placed the ID in the exact Canvas-result text.
	# Recognize only a watched receipt whose complete expected content matches;
	# arbitrary user text containing an ID never establishes a commit.
	var marker := '"_history_receipt_id":"'
	var start: int = data.content.find(marker)
	if start < 0: return ""
	start += marker.length()
	var finish: int = data.content.find('"',start)
	return data.content.substr(start,finish-start) if finish > start else ""

func _observe_history_event(kind: String, data: Variant, source: String, segments: Array[Dictionary], tracked: Dictionary, commit: bool, require_watch: bool = false) -> Dictionary:
	var result := {"error":"","duplicate_turn":false}
	var identity := _history_event_identity(kind,data)
	if require_watch and kind in ["history_result","conversation"] and data is Dictionary \
			and data.has("_history_receipt_id") and not valid_history_receipt_id(data._history_receipt_id):
		result.error = "Invalid history receipt identity; nothing written."
		return result
	if identity.is_empty(): return result
	if not tracked.has(identity):
		if require_watch and data is Dictionary and data.has("_history_receipt_id"):
			result.error = "History receipt must be durably staged and registered before archive append."
		return result
	var target: Dictionary = tracked[identity]
	var target_index := -1
	var source_index := -1
	for index: int in range(segments.size()):
		if str(segments[index].path) == str(target.source): target_index = index
		if str(segments[index].path) == source: source_index = index
	if target_index < 0 or source_index < target_index:
		result.error = "History receipt does not belong to this conversation's validated source ancestry."
		return result
	if kind == "history_result":
		if JSON.stringify(data).sha256_text() != str(target.raw_sha256):
			result.error = "Archived history receipt differs from its durable pending record."
		elif commit: target.raw = true
	elif kind == "conversation":
		if data.get("role") != "user" or not data.get("content") is String \
				or data.content.sha256_text() != str(target.turn_sha256) \
				or data.has("image_offset") or data.has("image_log_path") \
				or (int(target.schema) == 2 and JSON.stringify(data).sha256_text() != str(target.turn_event_sha256)):
			result.error = "Archived history result has different text, role, image or world epoch."
		elif not bool(target.raw):
			result.error = "History conversation result has no preceding committed native receipt."
		else:
			result.duplicate_turn = bool(target.turn)
			if commit: target.turn = true
	return result

func _active_history_segments() -> Array[Dictionary]:
	var segments: Array[Dictionary] = _validated_segments.duplicate(true)
	if not log_path.is_empty() and _segment(log_path,segments).is_empty(): segments.append({"path":log_path})
	return segments

func prepare_resume(previous: String) -> void:
	# No existence check, open, scan or write at startup. Keep unavailable pointers.
	if not _pending_history_segment.is_empty() and previous != parent_log_path:
		resume_error = "Cannot rebind a conversation while its native history checkpoint is pending."
		resume_ok = false
		return
	if not log_path.is_empty():
		resume_error = "Cannot rebind a conversation while its writable segment is active."
		resume_ok = false
		return
	parent_log_path = previous
	resume_ok = previous.is_empty()
	resume_error = ""; resume_warning = ""
	_validated_segments.clear()
	_conversation_turns = 0; _conversation_bytes = 0

func traffic_chain(latest: String) -> Array[String]:
	var archive := Archive.new()
	var chain: Array[String] = []
	if not archive.resolve(latest):
		log_warning = archive.error
		return chain
	for segment: Dictionary in archive.segments: chain.append(segment.path)
	return chain

func _segment(path: String, segments: Array[Dictionary]) -> Dictionary:
	for segment: Dictionary in segments:
		if str(segment.path) == path: return segment
	return {}

func _known_sources_unchanged() -> bool:
	for segment: Dictionary in _validated_segments:
		if segment.path == log_path: continue
		var file := FileAccess.open(segment.path, FileAccess.READ)
		if file == null or file.get_length() != int(segment.file_bytes) or FileAccess.get_modified_time(segment.path) != int(segment.mtime):
			resume_ok = false
			resume_error = "Conversation predecessor changed or is unavailable: " + str(segment.path)
			log_warning = resume_error
			return false
	return true

func begin_export(destination: String) -> Error:
	if export_active or resume_active: return ERR_BUSY
	export_message = ""; export_error = OK; _export_bytes = 0
	var latest := log_path if not log_path.is_empty() else parent_log_path
	var archive := Archive.new()
	if not archive.resolve(latest):
		export_message = archive.error
		export_error = ERR_FILE_CORRUPT
		return export_error
	var absolute := Archive.canonical_path(destination)
	if absolute.is_empty():
		export_message = "Invalid export destination."
		export_error = ERR_INVALID_PARAMETER
		return export_error
	for segment: Dictionary in archive.segments:
		if Archive.canonical_path(segment.path) == absolute:
			export_message = "Export cannot replace a conversation source or its alias."
			export_error = ERR_INVALID_PARAMETER
			return export_error
		var validated := _segment(segment.path, _validated_segments)
		if not validated.is_empty() and segment.path != log_path:
			if int(validated.file_bytes) != int(segment.file_bytes) or int(validated.mtime) != int(segment.mtime):
				export_message = "Conversation changed since it was opened: " + str(segment.path)
				export_error = ERR_FILE_CORRUPT
				return export_error
			# A legacy root also gains a content identity after successful replay.
			segment.expected_sha256 = validated.sha256
			segment.limit = validated.limit
	_export_destination = ProjectSettings.globalize_path(destination).simplify_path()
	_export_temporary = _export_destination + ".partial-" + Crypto.new().generate_random_bytes(16).hex_encode()
	if FileAccess.file_exists(_export_temporary):
		export_error = ERR_ALREADY_EXISTS
		return export_error
	_export_output = FileAccess.open(_export_temporary, FileAccess.WRITE)
	if _export_output == null:
		export_error = FileAccess.get_open_error()
		export_message = "Cannot create export staging file."
		return export_error
	_export_archive = archive
	_reset_image_validation()
	export_active = true
	return OK

func _end_export(result: Error, message: String = "") -> void:
	_export_output = null
	export_active = false
	export_error = result
	export_message = message
	if result != OK and not _export_temporary.is_empty():
		DirAccess.remove_absolute(_export_temporary)
	_export_temporary = ""
	_export_archive = null
	_reset_image_validation()

func poll_export(max_bytes: int = 1048576) -> Dictionary:
	if not export_active: return {"done":true,"error":export_error,"bytes":_export_bytes,"total":_export_bytes}
	var archive: RefCounted = _export_archive
	var callback := func(event: Dictionary, source: String, offset: int, raw: PackedByteArray) -> String:
		var problem := _validate_conversation_event(event, source, offset, archive.segments, _queue_image)
		if not problem.is_empty(): return problem
		archive.paused = not _image_queue.is_empty()
		_export_output.store_buffer(raw)
		if _export_output.get_error() != OK: return "Traffic export disk write failed."
		_export_bytes += raw.size()
		return ""
	if not _image_queue.is_empty():
		var problem := _poll_images(clampi(max_bytes, 1, 1048576))
		if not problem.is_empty(): archive.fail(problem)
	else:
		archive.paused = false
		archive.step(clampi(max_bytes, 1, 1048576), callback)
	var total: int = archive.total_bytes
	if archive.done:
		if not archive.error.is_empty():
			_end_export(ERR_FILE_CORRUPT, archive.error)
		else:
			_export_output.flush()
			var write_error := _export_output.get_error()
			_export_output = null
			if write_error != OK:
				_end_export(write_error, "Traffic export flush failed.")
			else:
				# Rename is the sole commit point. The final filename never contains a
				# partially validated export; replacing a symlink does not follow it.
				var canonical_destination := Archive.canonical_path(_export_destination)
				var safe := not canonical_destination.is_empty()
				for segment: Dictionary in archive.segments:
					if Archive.canonical_path(segment.path) == canonical_destination: safe = false
				if not safe:
					_end_export(ERR_INVALID_PARAMETER, "Export destination became an alias of a conversation source.")
				else:
					var replacement := Archive.atomic_replace(_export_temporary, _export_destination)
					_end_export(OK if replacement.get("ok", false) else ERR_FILE_CANT_WRITE, archive.warning if replacement.get("ok", false) else "Could not commit export; previous destination preserved: " + str(replacement.get("error", "")))
	return {"done":not export_active,"error":export_error,"bytes":_export_bytes,"total":total}

func cancel_export() -> void:
	if export_active: _end_export(ERR_SKIP, "Export cancelled; previous destination preserved.")

func export_traffic(destination: String) -> Error:
	var result := begin_export(destination)
	if result != OK: return result
	while export_active: poll_export()
	return export_error

static func checked_conversation(value: Variant) -> Variant:
	if not value is Array: return null
	var turns: Array = []
	for raw: Variant in value:
		if not raw is Dictionary or raw.get("role") not in ["user","assistant"] or not raw.get("content") is String:
			return null
		var turn := {"role":raw.role,"content":raw.content}
		if raw.has("_history_receipt_id"):
			if not valid_history_receipt_id(raw._history_receipt_id): return null
			turn._history_receipt_id = raw._history_receipt_id
		if raw.has("image_offset"):
			var offset: Variant = raw.image_offset
			# JSON numbers must be exact, representable byte offsets before int().
			if not Archive.integer(offset): return null
			turn.image_offset = int(offset)
		if raw.has("image_log_path"):
			if not raw.has("image_offset") or not raw.image_log_path is String or not valid_traffic_path(raw.image_log_path): return null
			turn.image_log_path = raw.image_log_path
		turns.append(turn)
	return turns

func _validate_turns(turns: Array, source: String, offset: int, segments: Array[Dictionary], deferred_image: Callable = Callable()) -> String:
	var current_index := -1
	var checked_images := {}
	for index: int in range(segments.size()):
		if segments[index].path == source: current_index = index
	for turn: Dictionary in turns:
		if not turn.has("image_offset"): continue
		var image_path: String = turn.get("image_log_path", source)
		var image_index := -1
		for index: int in range(segments.size()):
			if segments[index].path == image_path: image_index = index
		if image_index < 0 or image_index > current_index or (image_path == source and int(turn.image_offset) >= offset):
			return "Conversation image references an unrelated or future segment."
		if deferred_image.is_valid():
			deferred_image.call(image_path, int(turn.image_offset), int(segments[image_index].limit))
		else:
			var key := image_path + "@" + str(turn.image_offset)
			if not checked_images.has(key):
				if _read_historical_image(int(turn.image_offset), image_path, int(segments[image_index].limit)).is_empty():
					return "Conversation image reference is corrupt at %s:%d." % [image_path, int(turn.image_offset)]
				checked_images[key] = true
		turn.image_log_path = image_path
	return ""

func _validate_conversation_event(event: Dictionary, source: String, offset: int, segments: Array[Dictionary], deferred_image: Callable = Callable()) -> String:
	if event.kind == "conversation":
		var turns: Variant = checked_conversation([event.data])
		if turns == null: return "Malformed conversation turn: " + source
		return _validate_turns(turns, source, offset, segments, deferred_image)
	if event.kind == "conversation_edited":
		if not event.data is Dictionary or not event.data.get("last_result") is String: return "Malformed conversation edit: " + source
		var turns: Variant = checked_conversation(event.data.get("turns"))
		if turns == null: return "Malformed conversation edit turns: " + source
		return _validate_turns(turns, source, offset, segments, deferred_image)
	return ""

func begin_resume(previous: String) -> Error:
	if resume_active or export_active: return ERR_BUSY
	if not _pending_history_segment.is_empty() and previous != parent_log_path:
		resume_error = "Cannot restore another conversation while its native history checkpoint is pending."
		log_warning = resume_error
		return ERR_BUSY
	# Reading the active writer is allowed; rebinding it to another history is not.
	var own_writer := not log_path.is_empty() and previous == log_path
	if not log_path.is_empty() and not own_writer:
		resume_ok = false
		resume_error = "Cannot restore another history while a writable traffic segment is active."
		log_warning = resume_error
		return ERR_BUSY
	if own_writer:
		resume_ok = false; resume_error = ""; resume_warning = ""
	else: prepare_resume(previous)
	resumed_last_result = ""
	_resumed_turns = []
	_resume_restored = {"turns":[],"last_result":"","bytes":0}
	_resume_history_receipts = _history_receipts.duplicate(true)
	for target: Dictionary in _resume_history_receipts.values():
		target.raw = false; target.turn = false
	if previous.is_empty(): return OK
	var archive := Archive.new()
	if not archive.resolve(previous):
		resume_error = archive.error; log_warning = resume_error
		return ERR_FILE_CORRUPT
	if own_writer and (archive.segments.back().id != _segment_id or int(archive.segments.back().file_bytes) != _written_size):
		resume_error = "Writable traffic segment changed before replay; prior binding preserved."
		log_warning = resume_error
		return ERR_FILE_CORRUPT
	_resume_archive = archive
	_reset_image_validation()
	resume_active = true
	return OK

func poll_resume(max_bytes: int = 1048576) -> Dictionary:
	if not resume_active: return {"done":true,"ok":resume_ok,"bytes":0,"total":0,"turns":_resumed_turns}
	var archive: RefCounted = _resume_archive
	var restored: Dictionary = _resume_restored
	var callback := func(event: Dictionary, source: String, offset: int, _raw: PackedByteArray) -> String:
		var problem := _validate_conversation_event(event, source, offset, archive.segments, _queue_image)
		if not problem.is_empty(): return problem
		var observed := _observe_history_event(str(event.kind),event.data,source,archive.segments,_resume_history_receipts,true)
		if not str(observed.error).is_empty(): return str(observed.error)
		archive.paused = not _image_queue.is_empty()
		if event.kind == "conversation_cleared":
			restored.turns = []; restored.last_result = ""; restored.bytes = 0
		elif event.kind == "conversation_edited":
			var turns: Array = checked_conversation(event.data.turns)
			for turn: Dictionary in turns:
				if turn.has("image_offset") and not turn.has("image_log_path"): turn.image_log_path = source
			restored.turns = turns; restored.last_result = event.data.last_result; restored.bytes = 0
			for turn: Dictionary in turns: restored.bytes += str(turn.content).to_utf8_buffer().size()
		elif event.kind == "conversation":
			if bool(observed.duplicate_turn): return ""
			var turn: Dictionary = checked_conversation([event.data])[0]
			if turn.has("image_offset") and not turn.has("image_log_path"): turn.image_log_path = source
			restored.turns.append(turn)
			restored.bytes += str(turn.content).to_utf8_buffer().size()
			if str(turn.content).begins_with("Canvas result (") or turn.has("_history_receipt_id"): restored.last_result = turn.content
		if restored.turns.size() > MAX_CONVERSATION_TURNS or int(restored.bytes) > MAX_CONVERSATION_BYTES:
			return "Saved transcript exceeds the 16384-turn / 16 MiB replay limit; original archives preserved."
		return ""
	if not _image_queue.is_empty():
		var problem := _poll_images(clampi(max_bytes, 1, 1048576))
		if not problem.is_empty(): archive.fail(problem)
	else:
		archive.paused = false
		archive.step(clampi(max_bytes, 1, 1048576), callback)
	var progress := {"done":false,"ok":false,"bytes":archive.bytes_read,"total":archive.total_bytes,"turns":[]}
	if archive.done:
		resume_active = false
		progress.done = true
		if not archive.error.is_empty():
			resume_error = archive.error; log_warning = resume_error
		else:
			_validated_segments = archive.segments
			resume_ok = true; resume_warning = archive.warning; log_warning = resume_warning
			resumed_last_result = restored.last_result
			_conversation_turns = restored.turns.size(); _conversation_bytes = int(restored.bytes)
			_resumed_turns = restored.turns
			_history_receipts = _resume_history_receipts
			traffic = "[Earlier conversation traffic retained in the export]\n"
			readable = traffic
			progress.ok = true; progress.turns = _resumed_turns
		_resume_archive = null; _resume_restored = {}; _resume_history_receipts = {}
		_reset_image_validation()
	return progress

func cancel_resume() -> void:
	if not resume_active: return
	resume_active = false; resume_ok = false
	resume_error = "Conversation restoration cancelled; original files remain unchanged."
	log_warning = resume_error
	_resume_archive = null; _resume_restored = {}; _resumed_turns = []; _resume_history_receipts = {}
	_reset_image_validation()

func resume_traffic(previous: String) -> Array:
	if begin_resume(previous) != OK: return []
	while resume_active: poll_resume()
	return _resumed_turns if resume_ok else []

func _reset_image_validation() -> void:
	_image_file = null; _image_parts.clear(); _image_size = 0
	_image_queue.clear(); _image_pending.clear(); _image_cache.clear()

func _queue_image(path: String, offset: int, limit: int) -> void:
	var key := path + "@" + str(offset)
	if _image_cache.has(key) or _image_pending.has(key): return
	_image_pending[key] = true
	_image_queue.append({"path":path,"offset":offset,"limit":limit,"key":key})

func _poll_images(budget: int) -> String:
	# A shared incremental verifier serves restore and export. Repeated snapshot
	# references are deduplicated; only metadata is cached, never image payloads.
	var remaining := budget
	var completed := 0
	while not _image_queue.is_empty() and remaining > 0 and completed < 64:
		var item := _image_queue[0]
		var problem := "Conversation image reference is corrupt at %s:%d." % [item.path, int(item.offset)]
		# Defend the queued reader too: a negative seek must never fall back to0.
		if int(item.offset) < 0 or int(item.limit) <= 0 or int(item.offset) >= int(item.limit): return problem
		if _image_file == null:
			_image_file = FileAccess.open(item.path, FileAccess.READ)
			if _image_file == null or int(item.offset) >= mini(int(item.limit), _image_file.get_length()): return problem
			if int(item.offset) > 0:
				_image_file.seek(int(item.offset) - 1)
				if _image_file.get_8() != 10: return problem
			_image_file.seek(int(item.offset))
			_image_parts.clear(); _image_size = 0
		var left := int(item.limit) - _image_file.get_position()
		if left <= 0: return problem
		var block := _image_file.get_buffer(mini(Archive.CHUNK_BYTES, mini(left, remaining)))
		if block.is_empty(): return problem
		remaining -= block.size()
		var newline := block.find(10)
		var part := block if newline < 0 else block.slice(0, newline + 1)
		_image_parts.append(part); _image_size += part.size()
		if _image_size > Archive.MAX_RECORD_BYTES: return problem
		if newline >= 0:
			var raw := PackedByteArray()
			for piece: PackedByteArray in _image_parts: raw.append_array(piece)
			var decoded := Archive.decode_record(raw, true)
			if _image_from_event(decoded.get("event")).is_empty(): return problem
			if _image_cache.size() >= 4096: _image_cache.clear()
			_image_cache[item.key] = true; _image_pending.erase(item.key)
			_image_queue.pop_front(); _image_file = null; _image_parts.clear(); _image_size = 0
			completed += 1
	return ""

func _read_historical_image(offset: int, path: String, limit: int) -> String:
	if offset < 0 or not valid_traffic_path(path): return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or offset >= mini(limit, file.get_length()): return ""
	if offset > 0:
		file.seek(offset - 1)
		if file.get_8() != 10: return ""
	file.seek(offset)
	var record := Archive.read_record(file, limit)
	return _image_from_event(record.get("event"))

func _image_from_event(event: Variant) -> String:
	if not event is Dictionary or event.get("kind") != "request" or not event.get("data") is Dictionary or not event.data.get("body") is Dictionary: return ""
	var body: Dictionary = event.data.body
	var messages: Variant = body.get("input", body.get("messages", []))
	if not messages is Array or messages.is_empty() or not messages.back() is Dictionary or not messages.back().get("content") is Array: return ""
	for block: Variant in messages.back().content:
		if not block is Dictionary: continue
		var url: Variant = null
		if block.get("type") == "input_image": url = block.get("image_url")
		elif block.get("type") == "image_url" and block.get("image_url") is Dictionary: url = block.image_url.get("url")
		if not url is String or not url.begins_with("data:image/png;base64,"): continue
		var encoded: String = url.trim_prefix("data:image/png;base64,")
		if encoded.is_empty() or encoded.length() % 4 != 0: continue
		var bytes := Marshalls.base64_to_raw(encoded)
		if bytes.size() < 33 or Marshalls.raw_to_base64(bytes) != encoded: continue
		if bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]) or bytes.slice(12, 16).get_string_from_ascii() != "IHDR": continue
		var width: int = (int(bytes[16]) << 24) | (int(bytes[17]) << 16) | (int(bytes[18]) << 8) | int(bytes[19])
		var height: int = (int(bytes[20]) << 24) | (int(bytes[21]) << 16) | (int(bytes[22]) << 8) | int(bytes[23])
		if width < 1 or height < 1 or width > 16777216 or height > 16777216 or width * height > 16777216: continue
		# A pixel budget, not an aspect-ratio restriction, bounds decoded storage to64MiB.
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK: continue
		return url
	return ""

func historical_image(offset: int, source_path: String = "") -> String:
	var path := source_path if not source_path.is_empty() else log_path
	if path.is_empty(): return ""
	if path == log_path and _written_size >= 0: return _read_historical_image(offset, path, _written_size)
	var segment := _segment(path, _validated_segments)
	if segment.is_empty(): return ""
	return _read_historical_image(offset, path, int(segment.limit))

func log_event(kind: String, data: Variant) -> bool:
	last_event_stored = false
	if kind == "request": last_request_offset = -1
	if export_active or resume_active:
		log_warning = "Wait for or cancel the archive operation before adding traffic."
		traffic_changed.emit()
		return false
	if not parent_log_path.is_empty() and not resume_ok:
		if resume_error.is_empty(): resume_traffic(parent_log_path)
		if not resume_ok:
			log_warning = resume_error; traffic_changed.emit()
			return false
	if not _known_sources_unchanged():
		traffic_changed.emit()
		return false
	var history_identity := _history_event_identity(kind,data)
	var frozen_history: bool = kind in ["history_result","conversation"] and data is Dictionary \
		and data.has("_history_receipt_id") and _history_receipts.has(history_identity) \
		and int(_history_receipts[history_identity].schema) == 2
	# Exact digest checks below authenticate this registered, previously sanitized
	# projection before it reaches either live traffic or the archive writer.
	var sanitized: Variant = data.duplicate(true) if frozen_history else _sanitized_event_data(kind,data)
	var admission := _admit_conversation_event(kind, sanitized)
	if not admission.ok:
		log_warning = admission.error; traffic_changed.emit()
		return false
	var history_source := log_path if not log_path.is_empty() else parent_log_path
	var observed := _observe_history_event(kind,sanitized,history_source,_active_history_segments(),_history_receipts,false,true)
	if not str(observed.error).is_empty():
		log_warning = str(observed.error); traffic_changed.emit()
		return false
	var line := JSON.stringify({"utc":Time.get_datetime_string_from_system(true),"ms":Time.get_ticks_msec(),"request":serial,"kind":kind,"data":sanitized})
	traffic += line + "\n"
	readable += "\n" + Time.get_datetime_string_from_system(true) + " #" + str(serial) + " " + kind + "\n"
	if kind == "request" and sanitized is Dictionary and sanitized.get("body") is Dictionary:
		var body: Dictionary = sanitized.body
		readable += "Model: " + str(body.get("model", "")) + "\n"
		if body.has("instructions"): readable += "Instructions:\n" + str(body.instructions) + "\n"
		for message: Variant in body.get("messages", body.get("input", [])):
			if not message is Dictionary: continue
			readable += str(message.get("role", "message")) + ":\n"
			var content: Variant = message.get("content", "")
			if content is String: readable += content + "\n"
			elif content is Array:
				for block: Variant in content:
					readable += str(block.text) + "\n" if block is Dictionary and block.has("text") else "[Image attached; exact bytes in Raw JSONL]\n"
	elif sanitized is String: readable += sanitized + "\n"
	else: readable += JSON.stringify(sanitized, "  ") + "\n"
	if readable.length() > 2000000: readable = "[Earlier traffic retained on disk]\n" + readable.right(1500000)
	if traffic.length() > 2000000: traffic = "[Earlier traffic retained on disk]\n" + traffic.right(1500000)
	var stored := _store_event(kind, sanitized, admission)
	if stored:
		observed = _observe_history_event(kind,sanitized,log_path,_active_history_segments(),_history_receipts,true,true)
		if not str(observed.error).is_empty():
			_write_broken = true
			log_warning = str(observed.error)+" Restart Workbench to validate the committed archive."
			stored = false
	last_event_stored = stored
	traffic_changed.emit()
	return stored

func _admit_conversation_event(kind: String, data: Variant) -> Dictionary:
	var result := {"ok":true,"turns":_conversation_turns,"bytes":_conversation_bytes,"error":""}
	var turns: Variant = []
	if kind == "conversation":
		turns = checked_conversation([data])
	elif kind == "conversation_edited":
		if not data is Dictionary or not data.get("last_result") is String:
			return {"ok":false,"error":"Malformed conversation edit; nothing written."}
		turns = checked_conversation(data.get("turns"))
		result.turns = 0; result.bytes = 0
	elif kind == "conversation_cleared":
		result.turns = 0; result.bytes = 0
		return result
	else: return result
	if turns == null: return {"ok":false,"error":"Malformed conversation turn; nothing written."}
	result.turns += turns.size()
	for turn: Dictionary in turns: result.bytes += str(turn.content).to_utf8_buffer().size()
	if int(result.turns) > MAX_CONVERSATION_TURNS or int(result.bytes) > MAX_CONVERSATION_BYTES:
		return {"ok":false,"error":"Conversation exceeds the 16384-turn / 16 MiB replay limit; nothing written."}
	var segments := _validated_segments.duplicate(true)
	var current := _segment(log_path, segments)
	if current.is_empty(): segments.append({"path":log_path,"limit":maxi(0, _written_size)})
	else: current.limit = maxi(0, _written_size)
	var problem := _validate_turns(turns, log_path, maxi(0, _written_size), segments)
	if not problem.is_empty(): return {"ok":false,"error":problem + " Nothing written."}
	return result

func _retry_history_segment_checkpoint(kind: String, data: Variant, admission: Dictionary) -> bool:
	var pending: Dictionary = _pending_history_segment
	if kind != "history_result" or not data is Dictionary \
			or not _history_receipts.has(str(data.get("_history_receipt_id",""))) \
			or JSON.stringify(data).sha256_text() != str(pending.data_sha256) \
			or int(admission.turns) != int(pending.turns) or int(admission.bytes) != int(pending.bytes) \
			or parent_log_path != str(pending.parent):
		log_warning = "The original native history checkpoint is pending; retry that same receipt before adding different traffic."
		return false
	var parent := _segment(parent_log_path,_validated_segments)
	if not parent_log_path.is_empty() and (parent.is_empty() or str(parent.id) != str(pending.parent_id) \
			or int(parent.limit) != int(pending.parent_bytes) or str(parent.sha256) != str(pending.parent_sha256)):
		log_warning = "Pending history segment's validated parent changed; original archive and receipt preserved."
		return false
	var destination: String = pending.destination
	var directory := DirAccess.open(destination.get_base_dir())
	if directory == null or directory.is_link(destination.get_file()) \
			or str(pending.canonical).is_empty() or Archive.canonical_path(destination) != str(pending.canonical):
		log_warning = "Pending history segment is unavailable or aliased; restore its original file before retrying."
		return false
	var file := FileAccess.open(destination,FileAccess.READ)
	if file == null or file.get_length() != int(pending.length) \
			or int(pending.length) > MAX_PENDING_HISTORY_SEGMENT_BYTES:
		log_warning = "Pending history segment changed or cannot be read; original receipt remains pending."
		return false
	# This is our one new header+receipt file, never an inherited transcript.
	var raw := file.get_buffer(int(pending.length))
	file = null
	if raw.size() != int(pending.length) or Archive.digest(raw) != str(pending.sha256):
		log_warning = "Pending history segment content changed; refusing checkpoint adoption."
		return false
	if not commit_segment.is_valid() or not bool(commit_segment.call(destination)):
		log_warning = "Conversation pointer could not be committed. The same bounded history segment remains pending at "+destination
		return false
	log_path = destination; _segment_id = str(pending.id); _event_index = int(pending.index); _written_size = int(pending.length)
	_conversation_turns = int(pending.turns); _conversation_bytes = int(pending.bytes)
	_pending_history_segment = {}
	log_warning = resume_warning
	return true

func _store_event(kind: String, data: Variant, admission: Dictionary) -> bool:
	if kind in ["session_start", "session_parent"]:
		log_warning = "Segment metadata cannot be appended as a conversation event."
		return false
	if _write_broken:
		log_warning = "Traffic append was interrupted; restart Workbench to recover its complete events."
		return false
	if not _pending_history_segment.is_empty(): return _retry_history_segment_checkpoint(kind,data,admission)
	var new_segment := log_path.is_empty()
	var retain_history_segment: bool = new_segment and kind == "history_result" and data is Dictionary \
		and _history_receipts.has(str(data.get("_history_receipt_id",""))) and commit_segment.is_valid()
	var history_segment_hash: HashingContext
	if retain_history_segment:
		history_segment_hash = HashingContext.new()
		history_segment_hash.start(HashingContext.HASH_SHA256)
	if new_segment and _validated_segments.size() >= Archive.MAX_SEGMENTS:
		log_warning = "Conversation reached the 4096-segment limit; prior history preserved and nothing written."
		return false
	var destination := new_log_path() if new_segment else log_path
	if destination.is_empty() or not valid_traffic_path(destination):
		log_warning = "Cannot create traffic archive; live traffic remains available."
		return false
	var id := Crypto.new().generate_random_bytes(16).hex_encode() if new_segment else _segment_id
	if id.is_empty():
		log_warning = "Refusing to append to an archive not created by this provider."
		return false
	var index := 1 if new_segment else _event_index + 1
	var event := {"utc":Time.get_datetime_string_from_system(true),"ms":Time.get_ticks_msec(),"request":serial,"kind":kind,"data":data,"segment_id":id,"event_index":index,"event_id":id + ":" + str(index)}
	var encoded := (JSON.stringify(event) + "\n").to_utf8_buffer()
	if encoded.size() > Archive.MAX_RECORD_BYTES:
		log_warning = "Traffic event exceeds the 32 MiB record limit; nothing written."
		return false
	var temporary := destination + ".partial-" + id if new_segment else destination
	var file := FileAccess.open(temporary, FileAccess.WRITE if new_segment else FileAccess.READ_WRITE)
	if file == null:
		log_warning = "Cannot write traffic log; live traffic remains available."
		return false
	if new_segment:
		var header := {"kind":"session_start","schema":2,"segment_id":id,"data":{}}
		if not parent_log_path.is_empty():
			var parent := _segment(parent_log_path, _validated_segments)
			if parent.is_empty():
				file = null; DirAccess.remove_absolute(temporary)
				log_warning = "Saved conversation has no validated parent identity."
				return false
			header.kind = "session_parent"
			header.data = {"path":parent_log_path,"parent_id":parent.id,"parent_bytes":parent.limit,"parent_sha256":parent.sha256}
			if not bool(parent.modern):
				# Seal inherited path-only links once, at their first modern child.
				# Later modern children pin this header's bytes through its digest.
				var seals: Array = []
				for ancestor: Dictionary in _validated_segments:
					if ancestor.path != parent_log_path:
						seals.append({"path":ancestor.path,"id":ancestor.id,"bytes":ancestor.limit,"sha256":ancestor.sha256})
				header.data.legacy_ancestors = seals
		var header_line := (JSON.stringify(header) + "\n").to_utf8_buffer()
		var header_total := header_line.size()
		for ancestor: Dictionary in _validated_segments: header_total += int(ancestor.header_end)
		if header_line.size() > Archive.MAX_HEADER_BYTES or header_total > Archive.MAX_CHAIN_HEADER_BYTES:
			file = null; DirAccess.remove_absolute(temporary)
			log_warning = "Conversation metadata reached its bounded replay capacity; nothing written."
			return false
		file.store_buffer(header_line)
		if retain_history_segment: history_segment_hash.update(header_line)
	else:
		if file.get_length() != _written_size:
			file = null
			log_warning = "Traffic archive changed externally; refusing to append."
			return false
		file.seek_end()
	var offset := file.get_position()
	file.store_buffer(encoded)
	if retain_history_segment: history_segment_hash.update(encoded)
	file.flush()
	var error := file.get_error()
	var length := file.get_position()
	file = null # Close before signalling a durable pointer to the panel.
	if error == OK and new_segment:
		var replacement := Archive.atomic_replace(temporary, destination)
		if not replacement.get("ok", false): error = ERR_FILE_CANT_WRITE
	if error != OK:
		if new_segment: DirAccess.remove_absolute(temporary)
		else: _write_broken = true
		log_warning = "Traffic write failed; prior conversation remains preserved."
		return false
	if retain_history_segment:
		var parent := _segment(parent_log_path,_validated_segments)
		_pending_history_segment = {"destination":destination,"canonical":Archive.canonical_path(destination),
			"id":id,"index":index,"length":length,"sha256":history_segment_hash.finish().hex_encode(),
			"data_sha256":JSON.stringify(data).sha256_text(),"turns":int(admission.turns),"bytes":int(admission.bytes),
			"parent":parent_log_path,"parent_id":str(parent.get("id","")),"parent_bytes":int(parent.get("limit",0)),"parent_sha256":str(parent.get("sha256",""))}
		return _retry_history_segment_checkpoint(kind,data,admission)
	if new_segment and commit_segment.is_valid() and not bool(commit_segment.call(destination)):
		log_warning = "Conversation pointer could not be committed. Prior history is unchanged; unreferenced complete segment preserved at " + destination
		return false
	log_path = destination; _segment_id = id; _event_index = index; _written_size = length
	_conversation_turns = int(admission.turns); _conversation_bytes = int(admission.bytes)
	if kind == "request": last_request_offset = offset
	log_warning = resume_warning
	return true

func _exit_tree() -> void:
	cancel_export()
	cancel_resume()

func cancel(reason: String = "Human Stop") -> void:
	serial += 1
	if request != null:
		request.cancel_request(); request.queue_free(); request = null
	if active: log_event("cancelled",reason)
	active = false

static func quota_reset_seconds(headers: PackedStringArray) -> float:
	var values: Dictionary = {}
	for header: String in headers:
		var separator := header.find(":")
		if separator > 0:
			values[header.left(separator).to_lower()] = header.substr(separator+1).strip_edges()
	var duration := RegEx.new()
	duration.compile("([0-9]+(?:[.][0-9]+)?)(ms|s|m|h|d)")
	var wait := 0.0
	for bucket: String in ["requests","tokens","project-tokens"]:
		var remaining: String = values.get("x-ratelimit-remaining-"+bucket,"")
		if not remaining.is_valid_int() or remaining.to_int() > 0: continue
		var reset: String = values.get("x-ratelimit-reset-"+bucket,"")
		var end := 0
		var seconds := 0.0
		for part: RegExMatch in duration.search_all(reset):
			if part.get_start() != end: break
			end = part.get_end()
			seconds += part.get_string(1).to_float()*float({"ms":0.001,"s":1,"m":60,"h":3600,"d":86400}[part.get_string(2)])
		if end == reset.length() and is_finite(seconds): wait = maxf(wait,seconds)
	return wait

func send(provider: String, endpoint: String, model: String, key: String, prompt: String, instructions: String, tokens: int, seconds: float, png: String = "", context: Array = []) -> String:
	if active: return "A model request is already active."
	if model.strip_edges().is_empty(): return "Enter a model ID (discovery is optional)."
	if not key.is_empty() and not secrets.has(key): secrets.append(key)
	if provider != "LM Studio" and key.is_empty(): return "Enter your "+provider+" key in Key."
	serial += 1
	var id := serial
	requested_model = model
	usage = {}; returned_model = ""
	retry_after_seconds = 0.0
	var url := endpoint.trim_suffix("/")+ ("/responses" if provider=="OpenAI" else "/chat/completions")
	var body := payload(provider,model,prompt,instructions,tokens,png,context)
	log_event("request",{"url":url,"provider":provider,"body":body})
	request = HTTPRequest.new()
	request.use_threads = true
	request.timeout = seconds
	request.body_size_limit = 16*1024*1024
	request.max_redirects = 0
	add_child(request)
	var current := request
	request.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, bytes: PackedByteArray) -> void:
		current.queue_free()
		if id != serial: return
		request = null; active = false
		if code == 429:
			for header: String in headers:
				if header.get_slice(":",0).to_lower() == "retry-after":
					var value := header.substr(header.find(":")+1).strip_edges()
					if value.is_valid_float() and is_finite(value.to_float()):
						retry_after_seconds = maxf(0.0,value.to_float())
		var raw := bytes.get_string_from_utf8()
		log_event("response",{"transport":result,"http":code,"headers":headers,"body":raw})
		var parser := JSON.new()
		var valid_json := parser.parse(raw)==OK
		var data: Dictionary = parser.data if valid_json and parser.data is Dictionary else {}
		if provider == "OpenAI" and (code == 429 or (code >= 200 and code < 300)):
			var details: Variant = data.get("error",{})
			var error_code := str(details.get("code","")) if details is Dictionary else ""
			if error_code in ["insufficient_quota","credit_balance_exhausted","organization_spend_limit_exceeded","project_spend_limit_exceeded"]:
				retry_after_seconds = 0
			else:
				retry_after_seconds = maxf(retry_after_seconds,quota_reset_seconds(headers))
		usage = data.get("usage",{}) if data.get("usage") is Dictionary else {}
		returned_model = str(data.get("model","unknown"))
		log_event("usage",{"requested_model":requested_model,"returned_model":returned_model,"usage":usage,"cost":null})
		var decoded := decode(provider,data)
		log_event("assistant",decoded.text)
		var error: String = decoded.error
		if result != HTTPRequest.RESULT_SUCCESS: error = "Connection/timeout failure (%d). Check endpoint/server; inspect Traffic." % result
		elif code < 200 or code >= 300: error = "HTTP %d: %s" % [code,raw]
		finished.emit(id,redact(decoded.text),data,redact(error)))
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not key.is_empty(): headers.append("Authorization: Bearer "+key)
	var err := request.request(url,headers,HTTPClient.METHOD_POST,JSON.stringify(body))
	if err != OK:
		cancel("Request start failed")
		return "Could not start HTTP request (%d). Check the endpoint URL." % err
	active = true
	return ""
