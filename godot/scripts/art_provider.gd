extends Node
## One cancellable inference request; native drawing remains the existing executor.
signal finished(id: int, text: String, response: Dictionary, error: String)
signal request_started(id: int, request_offset: int)
signal traffic_changed
var active := false
var serial := 0
var request: HTTPRequest
# Constant-size, credential-free timing of the last request only. Never audit raw
# timing into Art JSONL: a diagnostic probe must not add more disk traffic.
var last_request_timing: Dictionary = {}
# One bounded receipt for the most recent synchronous audit append. No content,
# URL or credential enters diagnostics, and timing never creates another log.
var last_audit_timing: Dictionary = {}
var _audit_sequence := 0
var secrets: Array[String] = []
const Redactor = preload("res://scripts/art_redaction.gd")
const ResponsePreparation = preload("res://scripts/art_response_preparation.gd")
const ASYNC_RESPONSE_BYTES := 262144
const ASYNC_REQUEST_CHARACTERS := 65536
var _redactor := Redactor.new()
var _preparation: RefCounted
var _dispatch_guard: Callable
# A non-direct request owns exactly one completion callable. Its response never
# enters the ordinary finished signal, whose panel consumer paints immediately.
# Keep the delivered serial separately: clearing the callable must not turn a
# duplicate owned completion into an ordinary direct-paint completion.
var _response_owner: Dictionary = {}
var _last_owned_outcome: Dictionary = {}
var _finished_serial := -1
const OWNED_MODES := ["discuss", "propose", "develop", "review", "architecture-proposal"]
const MAX_OWNED_REQUEST_BYTES := 2 * 1024 * 1024
const MAX_OWNED_IMAGE_BYTES := 2 * 1024 * 1024
var _prepared_assistant: Dictionary = {}
var response_preparation_jobs := 0
var peak_response_preparation_jobs := 0
var request_preparation_jobs := 0
var peak_request_preparation_jobs := 0
var _conversation_edit_serial := 0
var _conversation_edit_owner: Dictionary = {}
var _conversation_edit_preparation: RefCounted
var conversation_edit_preparation_jobs := 0
var peak_conversation_edit_preparation_jobs := 0
var last_conversation_edit_timing: Dictionary = {}
var traffic := ""
var readable := ""
var log_path := ""
var traffic_directory := "user://art-traffic"
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
var _export_hash: HashingContext
var _export_verifier: RefCounted
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
	return ResponsePreparation.decode(provider,data)

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
	if _matches_prepared_assistant(value): return value
	_redactor.secrets = secrets
	return _redactor.redact(value)

func _redacted_value(value: Variant, redact_keys: bool = true) -> Variant:
	_redactor.secrets = secrets
	return _redactor.redacted_value(value,redact_keys)

func _sanitized_event_data(kind: String, data: Variant) -> Variant:
	# Envelope IDs, roles, offsets and segment paths are structural, not free text.
	if kind == "response" and data is Dictionary:
		var clean: Dictionary = _redacted_value(data,false)
		if data.get("body") is String:
			# The HTTP body is already JSON-escaped text. Redact its decoded values
			# and untrusted keys so quotes/backslashes cannot hide a request secret.
			# Keep original wire spelling when no structured redaction is needed.
			var parser := JSON.new()
			if parser.parse(data.body)==OK:
				var body: Variant = _redacted_value(parser.data)
				if body!=parser.data: clean.body = JSON.stringify(body)
		return clean
	if kind == "history_result" and data is Dictionary:
		# Native history receipt keys are trusted protocol identifiers. Their
		# names must survive even if a user deliberately chooses a short key.
		var clean: Dictionary = _redacted_value(data, false)

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
	var folder := traffic_directory
	if not traffic_namespace_valid(): return ""
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return ""
	for _attempt in range(16):
		var candidate := folder + "/" + Crypto.new().generate_random_bytes(16).hex_encode() + ".jsonl"
		if not FileAccess.file_exists(candidate): return candidate
	return ""

static func valid_traffic_path(path: String) -> bool:
	# Ordinary Art profiles/receipts must never bind a Batch Lab transport trace.
	return Archive.valid_path(path) and path.get_base_dir()=="user://art-traffic"

func _valid_writer_path(path: String) -> bool:
	return Archive.bound_path(path) and path.get_base_dir()==traffic_directory

func traffic_namespace_valid() -> bool:
	return Archive.valid_directory(traffic_directory)

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
	if not previous.is_empty() and not _valid_writer_path(previous):
		resume_error = "Saved conversation belongs to another traffic namespace."
		log_warning = resume_error; resume_ok = false
		return
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
	if not _valid_writer_path(latest):
		log_warning = "Saved conversation belongs to another traffic namespace."
		return chain
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
	if not _valid_writer_path(latest):
		export_message = "Saved conversation belongs to another traffic namespace."
		export_error = ERR_FILE_CORRUPT
		return export_error
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
	_export_hash = HashingContext.new()
	_export_hash.start(HashingContext.HASH_SHA256)
	_export_verifier = null
	_reset_image_validation()
	export_active = true
	return OK

func _end_export(result: Error, message: String = "") -> void:
	_export_output = null
	if _export_verifier != null: _export_verifier.close()
	_export_verifier = null
	_export_hash = null
	export_active = false
	export_error = result
	export_message = message
	if result != OK and not _export_temporary.is_empty():
		if FileAccess.file_exists(_export_temporary) and DirAccess.remove_absolute(_export_temporary) != OK:
			export_message += " An uncommitted staging file remains at " + _export_temporary + "."
	_export_temporary = ""
	_export_archive = null
	_reset_image_validation()

func poll_export(max_bytes: int = 1048576) -> Dictionary:
	if not export_active: return {"done":true,"error":export_error,"bytes":_export_bytes,"total":_export_bytes}
	var archive: RefCounted = _export_archive
	var total: int = archive.total_bytes
	if _export_verifier != null:
		_export_verifier.step(clampi(max_bytes, 1, 1048576))
		if _export_verifier.done:
			if not str(_export_verifier.error).is_empty():
				_end_export(ERR_FILE_CANT_WRITE, "Export refused; this export did not replace the destination. " + str(_export_verifier.error))
			else:
				_commit_verified_export(archive)
		return {"done":not export_active,"error":export_error,"bytes":_export_bytes,"total":total,"phase":"verify"}
	var callback := func(event: Dictionary, source: String, offset: int, raw: PackedByteArray) -> String:
		var problem := _validate_conversation_event(event, source, offset, archive.segments, _queue_image)
		if not problem.is_empty(): return problem
		archive.paused = not _image_queue.is_empty()
		if not _export_output.store_buffer(raw) or _export_output.get_error() != OK: return "Traffic export disk write failed."
		if _export_hash.update(raw) != OK: return "Cannot verify the submitted export buffers."
		_export_bytes += raw.size()
		return ""
	if not _image_queue.is_empty():
		var problem := _poll_images(clampi(max_bytes, 1, 1048576))
		if not problem.is_empty(): archive.fail(problem)
	else:
		archive.paused = false
		archive.step(clampi(max_bytes, 1, 1048576), callback)
	if archive.done:
		if not archive.error.is_empty():
			_end_export(ERR_FILE_CORRUPT, archive.error)
		else:
			_export_output.flush()
			var write_error := _export_output.get_error()
			_export_output.close()
			_export_output = null
			if write_error != OK:
				_end_export(write_error, "Traffic export flush failed.")
			else:
				_export_verifier = Archive.ClosedFileVerification.new(_export_temporary, 0, _export_bytes, _export_hash.finish().hex_encode())
	return {"done":not export_active,"error":export_error,"bytes":_export_bytes,"total":total}

func _commit_verified_export(archive: RefCounted) -> void:
	# Same-directory native replacement is the sole commit point. Recheck aliases
	# after cooperative validation; a source archive must never be replaced.
	var canonical_destination := Archive.canonical_path(_export_destination)
	var safe := not canonical_destination.is_empty()
	for segment: Dictionary in archive.segments:
		if Archive.canonical_path(segment.path) == canonical_destination: safe = false
	if not safe:
		_end_export(ERR_INVALID_PARAMETER, "Export destination became an alias of a conversation source.")
	else:
		var replacement := Archive.atomic_replace(_export_temporary, _export_destination)
		_end_export(OK if replacement.get("ok", false) else ERR_FILE_CANT_WRITE, archive.warning if replacement.get("ok", false) else "Could not commit export; this export did not replace the destination: " + str(replacement.get("error", "")))

func cancel_export() -> void:
	if export_active: _end_export(ERR_SKIP, "Export cancelled; this export did not replace the destination.")

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
	if not previous.is_empty() and not _valid_writer_path(previous):
		resume_error = "Saved conversation belongs to another traffic namespace."
		log_warning = resume_error; resume_ok = false
		return ERR_FILE_CORRUPT
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
			if not _valid_writer_path(str(item.path)): return problem
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
	if offset < 0 or not _valid_writer_path(path): return ""
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

# Large conversation edits use a distinct finite value job, never provider.active.
# A ready handle authenticates the private prepared value; callers cannot supply
# a sanitized flag, encoded body or substitute turns at commit.
func conversation_edit_active() -> bool:
	return not _conversation_edit_owner.is_empty() or (_conversation_edit_preparation != null and not _conversation_edit_preparation.reaped)

func conversation_edit_state() -> Dictionary:
	var phase: String = str(_conversation_edit_owner.get("phase","idle"))
	if phase == "idle" and _conversation_edit_preparation != null and not _conversation_edit_preparation.reaped: phase="stopping"
	return {"active":conversation_edit_active(),"phase":phase,
		"handle":int(_conversation_edit_owner.get("handle",_conversation_edit_preparation.request_id if _conversation_edit_preparation != null else -1))}

func _conversation_edit_guard(guard: Callable) -> bool:
	if not guard.is_valid(): return false
	var allowed: Variant = guard.call()
	return allowed is bool and allowed

func _conversation_edit_matches(handle: int, identity: Dictionary, check_guard: bool = true) -> bool:
	if not is_inside_tree() or is_queued_for_deletion(): return false
	var owned := _conversation_edit_owner
	if owned.is_empty() or int(owned.handle) != handle or owned.identity != identity \
			or int(owned.provider_serial) != serial or str(owned.path) != log_path or int(owned.event_index) != _event_index \
			or _conversation_edit_preparation == null or _conversation_edit_preparation.is_cancelled() \
			or _conversation_edit_preparation.secrets_snapshot != secrets: return false
	if check_guard and not _conversation_edit_guard(owned.guard): return false
	return is_inside_tree() and not is_queued_for_deletion() and not _conversation_edit_owner.is_empty() and int(_conversation_edit_owner.handle) == handle \
		and _conversation_edit_preparation != null and not _conversation_edit_preparation.is_cancelled() \
		and _conversation_edit_preparation.secrets_snapshot == secrets and int(owned.provider_serial) == serial \
		and str(owned.path) == log_path and int(owned.event_index) == _event_index

func begin_conversation_edit(turns: Variant, last_result: String, identity: Dictionary,
		completion: Callable, guard: Callable) -> Dictionary:
	var began := Time.get_ticks_usec()
	if not is_inside_tree() or is_queued_for_deletion():
		return {"ok":false,"handle":-1,"error":"Conversation provider owner is closing or unavailable."}
	if active or request != null or _preparation_active() or export_active or resume_active:
		return {"ok":false,"handle":-1,"error":"Finish or Stop current provider work before applying conversation edits."}
	if identity.is_empty() or not bounded_json_values(identity,{"items":64,"bytes":8192}) \
			or not completion.is_valid() or not guard.is_valid():
		return {"ok":false,"handle":-1,"error":"Conversation preparation needs a bounded identity, completion and live owner guard."}
	if not turns is Array or turns.size() > MAX_CONVERSATION_TURNS or last_result.length() > MAX_CONVERSATION_BYTES:
		return {"ok":false,"handle":-1,"error":"Conversation edit exceeds its bounded turn or text capacity."}
	var checked: Variant = checked_conversation(turns)
	if checked == null: return {"ok":false,"handle":-1,"error":"Malformed conversation edit; nothing written."}
	var characters := 0
	for turn: Dictionary in checked:
		characters += str(turn.content).length()
		if characters > MAX_CONVERSATION_BYTES:
			return {"ok":false,"handle":-1,"error":"Conversation edit exceeds the 16 MiB character admission bound."}
	if not _conversation_edit_guard(guard) or not is_inside_tree() or is_queued_for_deletion() \
			or active or request != null or _preparation_active():
		return {"ok":false,"handle":-1,"error":"Conversation edit context changed before preparation."}
	_conversation_edit_serial += 1
	var handle := _conversation_edit_serial
	var job := ResponsePreparation.new()
	job.direction="conversation_edit"
	job.request_id=handle
	job.conversation_turns=checked
	job.conversation_last_result=last_result
	job.secrets_snapshot=secrets.duplicate()
	job.received_usec=Time.get_ticks_usec()
	job.timing={"handle":handle,"phase":"preparing","admission_usec":0,"worker_usec":0,
		"wait_usec":0,"commit_usec":0,"committed":false,"adopted":false}
	_conversation_edit_preparation=job
	_conversation_edit_owner={"handle":handle,"identity":identity.duplicate(true),"completion":completion,
		"guard":guard,"phase":"preparing","provider_serial":serial,"path":log_path,"event_index":_event_index}
	# Establish an owned journal before the worker runs. Later edited append
	# must not invoke a first-segment adoption callback between write/adoption.
	# This bounded metadata never contains the unpublished draft.
	if log_path.is_empty():
		var stored := log_event("conversation_edit_preparing",{"handle":handle,"turn_count":checked.size()})
		if not stored or _conversation_edit_owner.is_empty() or int(_conversation_edit_owner.get("handle",-1)) != handle:
			_retire_conversation_edit(handle,"Could not admit conversation preparation.",false)
			return {"ok":false,"handle":-1,"error":"Could not admit conversation preparation; live history is unchanged."}
		_conversation_edit_owner.path=log_path
		_conversation_edit_owner.event_index=_event_index
	if not _conversation_edit_matches(handle,identity):
		_retire_conversation_edit(handle,"Conversation context changed before preparation.",false)
		return {"ok":false,"handle":-1,"error":"Conversation context changed before preparation; live history is unchanged."}
	conversation_edit_preparation_jobs=1
	peak_conversation_edit_preparation_jobs=maxi(peak_conversation_edit_preparation_jobs,1)
	job.timing.admission_usec=Time.get_ticks_usec()-began
	last_conversation_edit_timing=job.timing
	job.start(self)
	return {"ok":true,"handle":handle,"error":""}

func _notify_conversation_edit(completion: Callable, handle: int, identity: Dictionary, error: String) -> void:
	if completion.is_valid(): completion.call(handle,identity,error)

func _retire_conversation_edit(handle: int, reason: String, notify_owner: bool = true) -> void:
	if _conversation_edit_owner.is_empty() or int(_conversation_edit_owner.handle) != handle: return
	var owned := _conversation_edit_owner
	_conversation_edit_owner={}
	if _conversation_edit_preparation != null and int(_conversation_edit_preparation.request_id) == handle:
		var job := _conversation_edit_preparation
		job.cancel()
		job.timing.phase="cancelled"
		last_conversation_edit_timing=job.timing
		if job.reaped or not job.asynchronous: _conversation_edit_preparation=null
	if notify_owner:
		var completion: Callable = owned.get("completion",Callable())
		var safe_reason := redact(reason) if reason.length() <= 512 else "Conversation preparation cancelled."
		_notify_conversation_edit.call_deferred(completion,handle,owned.identity.duplicate(true),safe_reason)

func cancel_conversation_edit(handle: int, identity: Dictionary, reason: String = "Owner cancelled conversation edit") -> bool:
	if _conversation_edit_owner.is_empty() or int(_conversation_edit_owner.handle) != handle \
			or _conversation_edit_owner.identity != identity: return false
	_retire_conversation_edit(handle,reason)
	return true

func _conversation_edit_preparation_finished(job: RefCounted) -> void:
	if _conversation_edit_preparation != job: return
	conversation_edit_preparation_jobs=0
	job.timing.worker_usec=int(job.metrics.get("total_usec",0))
	job.timing.wait_usec=Time.get_ticks_usec()-job.received_usec
	if _conversation_edit_owner.is_empty() or job.is_cancelled():
		_conversation_edit_preparation=null
		return
	var handle: int = job.request_id
	var identity: Dictionary = _conversation_edit_owner.identity
	if not _conversation_edit_matches(handle,identity):
		_retire_conversation_edit(handle,"Conversation, World or credential context changed; Apply again.")
		return
	if not str(job.preparation_error).is_empty():
		_retire_conversation_edit(handle,str(job.preparation_error))
		return
	_conversation_edit_owner.phase="ready"
	job.timing.phase="ready"
	last_conversation_edit_timing=job.timing
	var completion: Callable = _conversation_edit_owner.completion
	_conversation_edit_owner.completion=Callable()
	# Even a very short job reports readiness on a later main-thread boundary.
	_notify_conversation_edit.call_deferred(completion,handle,identity.duplicate(true),"")

func prepared_conversation_edit_turns(handle: int, identity: Dictionary) -> Variant:
	if not _conversation_edit_matches(handle,identity) or _conversation_edit_owner.get("phase") != "ready": return null
	return _conversation_edit_preparation.sanitized.turns.duplicate(true)

func _conversation_edit_commit_valid(job: RefCounted, check_guard: bool = false) -> bool:
	if job == null or job != _conversation_edit_preparation or not job.reaped \
			or _conversation_edit_owner.get("phase") != "committing": return false
	var handle: int = job.request_id
	var identity: Dictionary = _conversation_edit_owner.identity
	if not _conversation_edit_matches(handle,identity,check_guard): return false
	if check_guard and not _conversation_edit_guard(_conversation_edit_owner.commit_guard): return false
	return job == _conversation_edit_preparation and not _conversation_edit_owner.is_empty() \
		and int(_conversation_edit_owner.handle) == handle and job.secrets_snapshot == secrets and not job.is_cancelled() \
		and _conversation_edit_matches(handle,identity,false)

func commit_conversation_edit(handle: int, identity: Dictionary, adopt: Callable, guard: Callable) -> Dictionary:
	var refusal := {"ok":false,"committed":false,"adopted":false,"error":"Conversation preparation is stale or unavailable; Apply again."}
	if not adopt.is_valid() or not guard.is_valid() or not _conversation_edit_matches(handle,identity) \
			or _conversation_edit_owner.get("phase") != "ready":
		if not _conversation_edit_owner.is_empty() and int(_conversation_edit_owner.handle) == handle and _conversation_edit_owner.identity == identity:
			_retire_conversation_edit(handle,"Conversation preparation is stale or unavailable.",false)
		return refusal
	var job := _conversation_edit_preparation
	_conversation_edit_owner.phase="committing"
	_conversation_edit_owner.adopt=adopt
	_conversation_edit_owner.commit_guard=guard
	job.timing.phase="committing"
	var began := Time.get_ticks_usec()
	var stored := _record_event("conversation_edited",job.sanitized,null,null,"",PackedByteArray(),job)
	job.timing.commit_usec=Time.get_ticks_usec()-began
	job.timing.committed=stored
	var adopted := bool(job.timing.get("adopted",false))
	job.timing.phase="committed" if stored and adopted else "refused"
	if _conversation_edit_serial == handle: last_conversation_edit_timing=job.timing
	if not _conversation_edit_owner.is_empty() and int(_conversation_edit_owner.handle) == handle:
		_retire_conversation_edit(handle,"Conversation edit was not committed.",false)
	return {"ok":stored and adopted,"committed":stored,"adopted":adopted,
		"error":"" if stored and adopted else (log_warning if not log_warning.is_empty() else "Conversation edit was not adopted; complete audit custody is retained.")}

func _adopt_prepared_conversation_edit(job: RefCounted) -> void:
	# _store_event has completed and set the durable journal identity. This
	# main-thread callback commits live ownership before any traffic observer.
	var handle: int = job.request_id
	if _conversation_edit_owner.is_empty() or int(_conversation_edit_owner.handle) != handle: return
	var adopt: Callable = _conversation_edit_owner.get("adopt",Callable())
	var adopted: Variant = adopt.call(job.sanitized.turns.duplicate(true)) if adopt.is_valid() else false
	job.timing.adopted=adopted is bool and adopted
	if not bool(job.timing.adopted): log_warning="Edited audit snapshot committed, but its live owner could not adopt it."
	if not _conversation_edit_owner.is_empty() and int(_conversation_edit_owner.handle) == handle: _conversation_edit_owner={}
	if _conversation_edit_preparation == job: _conversation_edit_preparation=null

func log_event(kind: String, data: Variant, sanitized_projection: Variant = null, audit_projection: Variant = null) -> bool:
	# These are exact pre-encoded values from the current response job, not a
	# general journal bypass. Native admission and durable append stay here.
	if kind in ["assistant","message"] and data is String and _matches_prepared_assistant(data):
		return _record_event(kind,data,sanitized_projection,audit_projection,_prepared_assistant.encoded_text,_prepared_assistant.encoded_text_bytes)
	if kind == "conversation" and data is Dictionary and data.size() == 2 and data.get("role") == "assistant" and data.get("content") is String and _matches_prepared_assistant(data.content):
		return _record_event(kind,data,sanitized_projection,audit_projection,_prepared_assistant.encoded_conversation,_prepared_assistant.encoded_conversation_bytes)
	return _record_event(kind,data,sanitized_projection,audit_projection)

func _matches_prepared_assistant(value: String) -> bool:
	return not _prepared_assistant.is_empty() and int(_prepared_assistant.serial) == serial \
		and _prepared_assistant.secrets == secrets and value == _prepared_assistant.text

func _record_event(kind: String, data: Variant, sanitized_projection: Variant = null, audit_projection: Variant = null, prepared_encoding: String = "", prepared_bytes: PackedByteArray = PackedByteArray(), prepared_edit: RefCounted = null) -> bool:
	var began_usec := Time.get_ticks_usec()
	_audit_sequence += 1
	var timing := {"schema":1,"sequence":_audit_sequence,"kind":kind,
		"sanitize_usec":0,"format_usec":0,"write_usec":0,"signal_usec":0,
		"total_usec":0,"stored":false}
	var stored := _append_event(kind,data,timing,sanitized_projection,prepared_encoding,prepared_bytes,prepared_edit)
	timing.total_usec = Time.get_ticks_usec() - began_usec
	timing.stored = stored
	# Signal observers may append another event. Do not replace the newer receipt.
	if int(timing.sequence) == _audit_sequence: last_audit_timing = timing
	if audit_projection is Dictionary: audit_projection.merge(timing,true)
	return stored

func _append_event(kind: String, data: Variant, timing: Dictionary, sanitized_projection: Variant, prepared_encoding: String = "", prepared_bytes: PackedByteArray = PackedByteArray(), prepared_edit: RefCounted = null) -> bool:
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
	var sanitize_begin_usec := Time.get_ticks_usec()
	# Only the private response-preparation path supplies this encoding, after
	# its immutable secret snapshot was checked against the owner on this thread.
	var prepared_response := kind in ["request","response","assistant","message","conversation"] and not prepared_encoding.is_empty()
	var prepared_conversation := prepared_edit != null and kind == "conversation_edited" and _conversation_edit_commit_valid(prepared_edit)
	if prepared_edit != null and not prepared_conversation:
		log_warning="Conversation prepared-value authority changed before append."
		return false
	var sanitized: Variant = prepared_edit.sanitized if prepared_conversation else (data if prepared_response else (data.duplicate(true) if frozen_history else _sanitized_event_data(kind,data)))
	timing.sanitize_usec = Time.get_ticks_usec() - sanitize_begin_usec
	# A response caller can reuse its already-redacted body for a short error
	# preview. This is not retained globally and never skips sanitization.
	if sanitized_projection is Dictionary and sanitized is Dictionary:
		sanitized_projection.merge(sanitized,true)
	var admission := _admit_conversation_event(kind, sanitized,prepared_edit if prepared_conversation else null)
	if not admission.ok:
		log_warning = admission.error; traffic_changed.emit()
		return false
	var history_source := log_path if not log_path.is_empty() else parent_log_path
	var observed := _observe_history_event(kind,sanitized,history_source,_active_history_segments(),_history_receipts,false,true)
	if not str(observed.error).is_empty():
		log_warning = str(observed.error); traffic_changed.emit()
		return false
	var format_begin_usec := Time.get_ticks_usec()
	# Encode the (potentially multi-megabyte) payload exactly once. Envelope
	# metadata is small; the same complete payload reaches the live and disk
	# forms without serializing it independently three times on the UI thread.
	var encoded_data: String = prepared_edit.encoded_data if prepared_conversation else (prepared_encoding if prepared_response else JSON.stringify(sanitized))
	# Keep refused prepared drafts out of the live projections. Ordinary events
	# retain their existing failure-preview behavior; prepared edits publish only
	# after their final guard and complete durable append succeed.
	var next_traffic := traffic
	var next_readable := readable
	var live_metadata := {"utc":Time.get_datetime_string_from_system(true),"ms":Time.get_ticks_msec(),"request":serial,"kind":kind}
	if encoded_data.length() > 2000000:
		# The live tail was already bounded; do not first allocate a full giant
		# envelope and append it to the previous buffer merely to discard it.
		# Keep the complete small suffix, including kind/request/time identity.
		var suffix := ","+JSON.stringify(live_metadata).trim_prefix("{")+"\n"
		next_traffic = "[Earlier traffic retained on disk]\n"+encoded_data.right(1500000-suffix.length())+suffix
	else:
		var line := _encoded_event(live_metadata,encoded_data)
		next_traffic += line + "\n"
	next_readable += "\n" + Time.get_datetime_string_from_system(true) + " #" + str(serial) + " " + kind + "\n"
	if encoded_data.length() > 262144:
		# A readable preview is not a second giant pretty-printed archive. The
		# session log/export retain the complete payload; Raw JSONL is a tail.
		next_readable += "[Large event; full redacted content in session log/export. Last 65536 characters:]\n"+encoded_data.right(65536)+"\n"
	elif kind == "request" and sanitized is Dictionary and sanitized.get("body") is Dictionary:
		var body: Dictionary = sanitized.body
		next_readable += "Model: " + str(body.get("model", "")) + "\n"
		if body.has("instructions"): next_readable += "Instructions:\n" + str(body.instructions) + "\n"
		for message: Variant in body.get("messages", body.get("input", [])):
			if not message is Dictionary: continue
			next_readable += str(message.get("role", "message")) + ":\n"
			var content: Variant = message.get("content", "")
			if content is String: next_readable += content + "\n"
			elif content is Array:
				for block: Variant in content:
					next_readable += str(block.text) + "\n" if block is Dictionary and block.has("text") else "[Image attached; exact bytes in Raw JSONL]\n"
	elif sanitized is String: next_readable += sanitized + "\n"
	else: next_readable += JSON.stringify(sanitized, "  ") + "\n"
	if next_readable.length() > 2000000: next_readable = "[Earlier traffic retained on disk]\n" + next_readable.right(1500000)
	if next_traffic.length() > 2000000: next_traffic = "[Earlier traffic retained on disk]\n" + next_traffic.right(1500000)
	timing.format_usec = Time.get_ticks_usec() - format_begin_usec
	if not prepared_conversation:
		traffic = next_traffic
		readable = next_readable
	if prepared_conversation and not _conversation_edit_commit_valid(prepared_edit,true):
		log_warning="Conversation, World or credentials changed before the actual edited append."
		return false
	var write_begin_usec := Time.get_ticks_usec()
	var stored := _store_event(kind, sanitized, admission, encoded_data,prepared_edit.encoded_data_bytes if prepared_conversation else prepared_bytes)
	timing.write_usec = Time.get_ticks_usec() - write_begin_usec
	if stored:
		observed = _observe_history_event(kind,sanitized,log_path,_active_history_segments(),_history_receipts,true,true)
		if not str(observed.error).is_empty():
			_write_broken = true
			log_warning = str(observed.error)+" Restart Workbench to validate the committed archive."
			stored = false
	last_event_stored = stored
	if stored and prepared_conversation:
		traffic = next_traffic
		readable = next_readable
		_adopt_prepared_conversation_edit(prepared_edit)
	var signal_begin_usec := Time.get_ticks_usec()
	traffic_changed.emit()
	timing.signal_usec = Time.get_ticks_usec() - signal_begin_usec
	return stored

func _encoded_event(metadata: Dictionary, encoded_data: String) -> String:
	# data is encoded by JSON.stringify above, never interpolated unescaped.
	# This preserves the ordinary sorted JSON object shape without reparsing it.
	return "".join(['{"data":',encoded_data,',',JSON.stringify(metadata).trim_prefix('{')])

static func usage_projection(reported: Variant) -> Dictionary:
	# Provider counters are untrusted JSON. The status/spend projection accepts
	# finite nonnegative integer counts only; the complete envelope remains in
	# the redacted response archive, including malformed or extra usage fields.
	var projected := {}
	if not reported is Dictionary: return projected
	for field: String in ["input_tokens","prompt_tokens","output_tokens","completion_tokens","total_tokens"]:
		var count: Variant = reported.get(field)
		if Archive.integer(count) and count >= 0: projected[field] = count
	return projected

func _model_projection(reported: Variant) -> String:
	# Metadata is not a second unbounded provider body. Preserve its complete
	# original in the response receipt, but expose only a short redacted ID.
	if not reported is String or reported.is_empty(): return "unknown (invalid model metadata; see response)"
	if reported.length() > 512: return "unknown (oversized model metadata; see response)"
	return redact(reported)

func _admit_conversation_event(kind: String, data: Variant, prepared_edit: RefCounted = null) -> Dictionary:
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
	if prepared_edit != null and kind == "conversation_edited" and _conversation_edit_commit_valid(prepared_edit):
		result.bytes=int(prepared_edit.conversation_bytes)
	else:
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
	if not _valid_writer_path(destination):
		log_warning = "Pending traffic checkpoint belongs to another namespace."
		return false
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

func _store_event(kind: String, data: Variant, admission: Dictionary, encoded_data: String, prepared_bytes: PackedByteArray = PackedByteArray()) -> bool:
	if not traffic_namespace_valid() or (not parent_log_path.is_empty() and not _valid_writer_path(parent_log_path)):
		log_warning = "Traffic namespace is invalid or differs from its parent."
		return false
	for ancestor: Dictionary in _validated_segments:
		if not _valid_writer_path(str(ancestor.path)):
			log_warning = "Traffic namespace differs from its validated ancestor."
			return false
	if kind in ["session_start", "session_parent"]:
		log_warning = "Segment metadata cannot be appended as a conversation event."
		return false
	if _write_broken:
		log_warning = "Traffic append was interrupted; this session log is read-only. Retain or export its complete events."
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
	if destination.is_empty() or not _valid_writer_path(destination):
		log_warning = "Cannot create traffic archive; live traffic remains available."
		return false
	var id := Crypto.new().generate_random_bytes(16).hex_encode() if new_segment else _segment_id
	if id.is_empty():
		log_warning = "Refusing to append to an archive not created by this provider."
		return false
	var index := 1 if new_segment else _event_index + 1
	var event := {"utc":Time.get_datetime_string_from_system(true),"ms":Time.get_ticks_msec(),"request":serial,"kind":kind,"segment_id":id,"event_index":index,"event_id":id + ":" + str(index)}
	# Build the identical JSONL envelope in bytes. Avoid allocating two full
	# UTF32 envelopes around a giant value only to convert them back to UTF8.
	# Prepared jobs can also reuse their owned UTF8 value; the final ordered
	# append remains one buffer with the existing flush/error/receipt protocol.
	var encoded := '{"data":'.to_utf8_buffer()
	encoded.append_array(prepared_bytes if not prepared_bytes.is_empty() else encoded_data.to_utf8_buffer())
	encoded.append_array((","+JSON.stringify(event).trim_prefix("{")+"\n").to_utf8_buffer())
	if encoded.size() > Archive.MAX_RECORD_BYTES:
		log_warning = "Traffic event exceeds the 32 MiB record limit; nothing written."
		return false
	var temporary := destination + ".partial-" + id if new_segment else destination
	var file := FileAccess.open(temporary, FileAccess.WRITE if new_segment else FileAccess.READ_WRITE)
	if file == null:
		log_warning = "Cannot write traffic log; live traffic remains available."
		return false
	var write_hash := HashingContext.new()
	write_hash.start(HashingContext.HASH_SHA256)
	var stored := true
	var verify_offset := 0 if new_segment else _written_size
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
		stored = file.store_buffer(header_line)
		write_hash.update(header_line)
		if retain_history_segment: history_segment_hash.update(header_line)
	else:
		if file.get_length() != _written_size:
			file = null
			log_warning = "Traffic archive changed externally; refusing to append."
			return false
		file.seek_end()
	var offset := file.get_position()
	var event_stored := file.store_buffer(encoded)
	stored = stored and event_stored
	write_hash.update(encoded)
	if retain_history_segment: history_segment_hash.update(encoded)
	file.flush()
	var error := file.get_error()
	var length := offset + encoded.size()
	file.close()
	file = null # Close and verify before signalling a stored pointer to the panel.
	if not stored: error = ERR_FILE_CANT_WRITE
	if error == OK:
		var verification := Archive.ClosedFileVerification.new(temporary, verify_offset, length, write_hash.finish().hex_encode())
		while not verification.done: verification.step()
		if not verification.error.is_empty(): error = ERR_FILE_CANT_WRITE
	if error == OK and new_segment:
		var replacement := Archive.atomic_replace(temporary, destination)
		if not replacement.get("ok", false): error = ERR_FILE_CANT_WRITE
	if error != OK:
		log_warning = "Traffic write failed; the new event was not confirmed. Prior complete events remain in the session log."
		if new_segment:
			if FileAccess.file_exists(temporary) and DirAccess.remove_absolute(temporary) != OK:
				log_warning += " An uncommitted staging file remains at " + temporary + "."
		else: _write_broken = true
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
	# The panel normally stops first, but provider ownership must also be safe
	# when removed directly or when scene teardown has no next process tick.
	if active or request != null: cancel("Workbench closed")
	if not _conversation_edit_owner.is_empty(): _retire_conversation_edit(int(_conversation_edit_owner.handle),"Workbench closed",false)
	cancel_export()
	cancel_resume()

func response_preparation_active() -> bool:
	return _preparation != null and _preparation.direction == "response" and not _preparation.reaped

func request_preparation_active() -> bool:
	return _preparation != null and _preparation.direction == "request" and not _preparation.reaped

func _preparation_active() -> bool:
	return (_preparation != null and not _preparation.reaped) or conversation_edit_active()

func cancel(reason: String = "Human Stop") -> void:
	var begin_usec := Time.get_ticks_usec()
	if not _conversation_edit_owner.is_empty(): _retire_conversation_edit(int(_conversation_edit_owner.handle),reason)
	var was_active := active or request != null
	var timing := last_request_timing
	var retired := _response_owner
	_response_owner = {}
	if not retired.is_empty():
		_finished_serial = int(retired.id)
		_last_owned_outcome = _owned_projection(retired,"cancelled")
	# A completed value task can be reaped just before a queued owner deletion.
	# Until its owner consumes it, it is still an unpublished preparation.
	var preparing := _preparation != null
	serial += 1
	active = false
	_prepared_assistant = {}
	_dispatch_guard = Callable()
	if preparing: _preparation.cancel()
	if request != null:
		request.cancel_request(); request.queue_free(); request = null
	if was_active:
		if preparing:
			# A complete transport body may have arrived, but no response receipt
			# was committed. Cancellation discards this unpublished value job.
			var receipt := {"reason":reason,"phase":_preparation.direction+"_preparation",
				"request_id":int(_preparation.request_id)}
			if _preparation.direction == "response":
				receipt.response_bytes = int(timing.get("response_bytes",0))
				receipt.response_receipt_committed = false
			else: receipt.request_receipt_committed = false
			log_event("cancelled",receipt)
		else: log_event("cancelled",reason)
	if was_active and not timing.is_empty():
		timing["status"] = "cancelled"
		timing["cancel_usec"] = Time.get_ticks_usec() - begin_usec
	# Retire before audit/callback reentrancy. This callback belongs to the old
	# request even if an audit observer has already dispatched its successor.
	if not retired.is_empty():
		var callback: Callable = retired.completion
		if callback.is_valid():
			var cancelled_reason := reason if not reason.strip_edges().is_empty() else "Owned request cancelled."
			callback.call(int(retired.id),"",_owned_projection(retired,"cancelled"),redact(cancelled_reason).left(512))

func cancel_owned(provider_id: int, request_id: String, reason: String = "Owner Stop") -> bool:
	# -1 is the Architecture bridge's synchronous-dispatch cancellation token.
	# It still requires the exact textual identity. It is never a wildcard for
	# cancelling an ordinary Art request or an unrelated owner's successor.
	if _response_owner.is_empty() or _response_owner.request_id != request_id: return false
	if provider_id != -1 and provider_id != int(_response_owner.id): return false
	if int(_response_owner.id) != serial: return false
	cancel(reason)
	return true

static func _owned_projection(owner: Dictionary, state: String) -> Dictionary:
	return {"format":"cybersand-art-owned-completion-v1", "provider_id":int(owner.id),
		"request_id":str(owner.request_id), "mode":str(owner.mode), "state":state}

func owned_request() -> Dictionary:
	# No credentials, endpoint, prompt, context, image or callable escapes here.
	if _response_owner.is_empty(): return _last_owned_outcome.duplicate(true)
	return _owned_projection(_response_owner,str(last_request_timing.get("status","preparing")))

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

static func transport_error(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Connection failed: no reachable server at the configured endpoint. Start the local server or check its address and port; inspect Traffic."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Connection failed: endpoint hostname could not be resolved. Check its address; inspect Traffic."
		HTTPRequest.RESULT_TIMEOUT:
			return "Connection timeout: the server did not finish within Secs. Check the endpoint/server or increase Secs; inspect Traffic."
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Provider response exceeded the 16 MiB transport limit. Nothing drawn; inspect Traffic for the transport receipt."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "Connection failed: TLS handshake was not accepted. Check the endpoint and its certificate; inspect Traffic."
	return "Connection/timeout failure (%d). Check endpoint/server; inspect Traffic." % result

static func request_url(provider: String, endpoint: String) -> String:
	var url := endpoint.trim_suffix("/")+("/responses" if provider=="OpenAI" else "/chat/completions")
	# Godot 4.7 HTTPClientTCP rejects the valid three-character IPv6 literal
	# ::1 through HOST_MIN_LEN. Expand only that exact loopback authority; its
	# destination is identical and saved/custom configuration is not rewritten.
	for scheme: String in ["http://","https://"]:
		var short := scheme+"[::1]"
		if url.begins_with(short):
			var suffix := url.substr(short.length())
			if suffix.begins_with(":") or suffix.begins_with("/"):
				return scheme+"[0:0:0:0:0:0:0:1]"+suffix
	return url

func _finish_request(id: int, text: String, data: Dictionary, error: String,
		timing: Dictionary, callback_begin_usec: int) -> void:
	if id != serial or id == _finished_serial: return
	if not _response_owner.is_empty():
		# Context can change while HTTP or response preparation is running too.
		# A refusal retires the owned callback; it never falls through to paint.
		if not _dispatch_allowed(id): return
		if not (_response_owner.get("completion",Callable()) as Callable).is_valid():
			cancel("The proposal response owner is no longer available")
			return
	var redact_begin_usec := Time.get_ticks_usec()
	var safe_text := redact(text)
	var safe_error := redact(error)
	# HTTP200 error/refusal envelopes may be just as large as HTTP failures.
	# Keep the complete response in the audit; bound every UI/context error.
	if safe_error.length() > 512:
		safe_error = safe_error.left(512)+" … (full response in Traffic)"
	timing.projection_redact_usec = Time.get_ticks_usec() - redact_begin_usec
	timing.status = "completed"
	timing.outcome = "success" if safe_error.is_empty() else "failure"
	active = false
	_finished_serial = id
	var completed_owner := _response_owner
	_response_owner = {}
	_dispatch_guard = Callable()
	var signal_begin_usec := Time.get_ticks_usec()
	if completed_owner.is_empty():
		finished.emit(id,safe_text,data,safe_error)
	else:
		_last_owned_outcome = _owned_projection(completed_owner,timing.outcome)
		# The full admitted redacted envelope stays in this provider's audit.
		# Consumers receive redacted text plus a small host-generated receipt,
		# never raw echoed credentials or an invented native execution receipt.
		var receipt := _last_owned_outcome.duplicate(true)
		receipt.usage = usage.duplicate(true)
		var callback: Callable = completed_owner.completion
		callback.call(id,safe_text,receipt,safe_error)
	# Only the synchronous completion/panel audit chain needs these full JSON
	# encodings. Release them now, without clearing a successor's own cache.
	if int(_prepared_assistant.get("serial",-1)) == id: _prepared_assistant = {}
	# finished can synchronously call the panel's JSON/native/UI path, cancel,
	# or even start a successor. Keep the old receipt separate from its successor.
	timing.signal_usec = Time.get_ticks_usec() - signal_begin_usec
	timing.callback_usec = Time.get_ticks_usec() - callback_begin_usec

func _request_completed(result: int, code: int, headers: PackedStringArray, bytes: PackedByteArray,
		id: int, provider: String, began_usec: int, timing: Dictionary, current: HTTPRequest) -> void:
	var callback_begin_usec := Time.get_ticks_usec()
	current.queue_free()
	if id != serial: return
	request = null
	timing.status = "completing"
	timing.http_code = code
	timing.transport_result = result
	timing.response_bytes = bytes.size()
	timing.response_wait_usec = callback_begin_usec - began_usec
	timing.transport_wait_usec = callback_begin_usec - int(timing.dispatch_completed_usec)
	var prepared := ResponsePreparation.new()
	prepared.request_id = id
	prepared.provider_name = provider
	prepared.transport_result = result
	prepared.http_code = code
	prepared.headers = headers.duplicate()
	# Packed arrays alias when assigned; later signal observers must not mutate
	# the body snapshot while a worker reads it. Copy exactly once at handoff.
	prepared.bytes = bytes.duplicate() if bytes.size() >= ASYNC_RESPONSE_BYTES else bytes
	prepared.secrets_snapshot = secrets.duplicate()
	prepared.timing = timing
	prepared.received_usec = callback_begin_usec
	if bytes.size() >= ASYNC_RESPONSE_BYTES:
		_preparation = prepared
		response_preparation_jobs = 1
		peak_response_preparation_jobs = maxi(peak_response_preparation_jobs,1)
		timing.status = "preparing_response"
		timing.response_preparation_async = true
		prepared.start(self)
		timing.callback_setup_usec = Time.get_ticks_usec()-callback_begin_usec
		return
	prepared.prepare_inline()
	_publish_response(prepared,callback_begin_usec)

func _preparation_finished(prepared: RefCounted) -> void:
	if prepared.direction == "conversation_edit":
		_conversation_edit_preparation_finished(prepared)
		return
	if _preparation != prepared: return
	_preparation = null
	if prepared.direction == "request": request_preparation_jobs = 0
	else: response_preparation_jobs = 0
	var timing: Dictionary = prepared.timing
	var prefix: String = prepared.direction+"_preparation_"
	timing[prefix+"reaped"] = true
	timing[prefix+"cancelled"] = prepared.is_cancelled()
	timing[prefix+"usec"] = int(timing.get(prefix+"usec",0))+int(prepared.metrics.get("total_usec",0))
	timing[prefix+"wait_usec"] = Time.get_ticks_usec()-prepared.received_usec
	if prepared.request_id != serial or prepared.is_cancelled(): return
	# Key changes are possible while a worker runs. Repeat from the SAME owned
	# values with a fresh credential snapshot; there is no additional HTTP call
	# and no overlapping task/body copy.
	if secrets != prepared.secrets_snapshot:
		_restart_preparation(prepared)
		return
	if prepared.direction == "request": _dispatch_prepared_request(prepared,true)
	else: _publish_response(prepared,Time.get_ticks_usec())

func _restart_preparation(prepared: RefCounted) -> void:
	var replacement := ResponsePreparation.new()
	replacement.request_id = prepared.request_id
	replacement.direction = prepared.direction
	replacement.provider_name = prepared.provider_name
	replacement.transport_result = prepared.transport_result
	replacement.http_code = prepared.http_code
	replacement.headers = prepared.headers
	replacement.bytes = prepared.bytes
	replacement.request_body = prepared.request_body
	replacement.request_url = prepared.request_url
	replacement.request_key = prepared.request_key
	replacement.request_seconds = prepared.request_seconds
	replacement.secrets_snapshot = secrets.duplicate()
	replacement.timing = prepared.timing
	replacement.received_usec = prepared.received_usec
	_preparation = replacement
	if replacement.direction == "request": request_preparation_jobs = 1
	else: response_preparation_jobs = 1
	var prefix: String = replacement.direction+"_preparation_"
	replacement.timing[prefix+"restarts"] = int(replacement.timing.get(prefix+"restarts",0))+1
	replacement.timing[prefix+"reaped"] = false
	replacement.start(self)

func _publish_response(prepared: RefCounted, callback_begin_usec: int) -> void:
	var id: int = prepared.request_id
	if id != serial: return
	var result: int = prepared.transport_result
	var code: int = prepared.http_code
	var headers: PackedStringArray = prepared.headers
	var provider: String = prepared.provider_name
	var timing: Dictionary = prepared.timing
	timing.status = "completing"
	for stage: String in ["utf8_decode_usec","json_parse_usec"]:
		timing[stage] = int(prepared.metrics.get(stage,0))
	timing.response_sanitize_usec = int(prepared.metrics.get("sanitize_usec",0))
	timing.response_encode_usec = int(prepared.metrics.get("encode_usec",0))
	timing.response_utf8_encode_usec = int(prepared.metrics.get("utf8_encode_usec",0))
	if code == 429:
		for header: String in headers:
			if header.get_slice(":",0).to_lower() == "retry-after":
				var value := header.substr(header.find(":")+1).strip_edges()
				if value.is_valid_float() and is_finite(value.to_float()):
					retry_after_seconds = maxf(0.0,value.to_float())
	# Durable append and signal/native ordering stay on the main thread. This
	# is one prepared response receipt, not a general asynchronous journal.
	var response_log_begin_usec := Time.get_ticks_usec()
	var response_audit := {}
	_record_event("response",prepared.sanitized,null,response_audit,prepared.encoded_data,prepared.encoded_data_bytes)
	timing.response_log_usec = Time.get_ticks_usec() - response_log_begin_usec
	for stage: String in ["format_usec","write_usec"]:
		timing["response_"+stage] = int(response_audit.get(stage,0))
	# Each audit append emits traffic_changed synchronously. A Stop/teardown
	# observer must fence this callback before any subsequent assistant work.
	if id != serial: return
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish_request(id,"",{},transport_error(result),timing,callback_begin_usec)
		return
	if code < 200 or code >= 300:
		# Keep the existing OpenAI quota refusal/pacing contract. This bounded
		# parser is not used for a refused connection with no HTTP response.
		if provider == "OpenAI" and code == 429:
			var failure_data: Dictionary = prepared.data
			var detail: Variant = failure_data.get("error",{})
			var kind := str(detail.get("code","")) if detail is Dictionary else ""
			if kind in ["insufficient_quota","credit_balance_exhausted","organization_spend_limit_exceeded","project_spend_limit_exceeded"]:
				retry_after_seconds = 0.0
			else:
				retry_after_seconds = maxf(retry_after_seconds,quota_reset_seconds(headers))
		# Redact BEFORE shortening: cutting through an echoed credential first
		# leaves a non-matching partial key that cannot subsequently be redacted.
		var safe_raw: String = prepared.sanitized_body
		var excerpt := safe_raw.left(512).replace("\r"," ").replace("\n"," ")
		var suffix := " … (full response in Traffic)" if safe_raw.length() > 512 else ""
		_finish_request(id,"",{},"HTTP %d: %s%s" % [code,excerpt,suffix],timing,callback_begin_usec)
		return
	if not prepared.valid_object:
		_finish_request(id,"",{},"Malformed JSON response: expected a provider response object. Nothing drawn; inspect Traffic.",timing,callback_begin_usec)
		return
	var data: Dictionary = prepared.data
	if provider == "OpenAI":
		var details: Variant = data.get("error",{})
		var error_code := str(details.get("code","")) if details is Dictionary else ""
		if error_code in ["insufficient_quota","credit_balance_exhausted","organization_spend_limit_exceeded","project_spend_limit_exceeded"]:
			retry_after_seconds = 0
		else:
			retry_after_seconds = maxf(retry_after_seconds,quota_reset_seconds(headers))
	var decoded: Dictionary = prepared.decoded
	timing.envelope_decode_usec = int(prepared.metrics.get("envelope_decode_usec",0))
	timing.assistant_redact_usec = int(prepared.metrics.get("assistant_redact_usec",0))
	timing.assistant_encode_usec = int(prepared.metrics.get("assistant_encode_usec",0))
	timing.assistant_utf8_encode_usec = int(prepared.metrics.get("assistant_utf8_encode_usec",0))
	_prepared_assistant = {"serial":id,"secrets":prepared.secrets_snapshot,
		"text":str(decoded.text),"encoded_text":prepared.encoded_assistant,
		"encoded_conversation":prepared.encoded_conversation,
		"encoded_text_bytes":prepared.encoded_assistant_bytes,
		"encoded_conversation_bytes":prepared.encoded_conversation_bytes}
	usage = usage_projection(data.get("usage"))
	returned_model = _model_projection(data.get("model","unknown"))
	var other_log_begin_usec := Time.get_ticks_usec()
	# A syntactically valid error/refusal envelope can contain real reported
	# usage. Retain it, while avoiding invented usage or empty assistant replies.
	if not str(decoded.text).is_empty() or not usage.is_empty():
		log_event("usage",{"requested_model":requested_model,"returned_model":returned_model,"usage":usage,"cost":null})
	if id != serial: return
	if not str(decoded.text).is_empty(): log_event("assistant",decoded.text)
	timing.other_log_usec = Time.get_ticks_usec() - other_log_begin_usec
	_finish_request(id,str(decoded.text),data,str(decoded.error),timing,callback_begin_usec)

static func _request_value_weight(value: Variant, depth: int = 0) -> int:
	# Only immutable JSON values enter a worker. Reject cycles/objects before
	# handing off a deep container snapshot; strings remain reference-counted.
	if depth > 32: return -1
	if value is String: return mini(value.length(),ASYNC_REQUEST_CHARACTERS)
	if value == null or value is bool or value is int or value is float: return 0
	var weight := 0
	if value is Dictionary:
		for key: Variant in value:
			if not key is String: return -1
			var item := _request_value_weight(value[key],depth+1)
			if item < 0: return -1
			weight = mini(ASYNC_REQUEST_CHARACTERS,weight+item+key.length())
		return weight
	if value is Array or value is PackedStringArray:
		for entry: Variant in value:
			var item := _request_value_weight(entry,depth+1)
			if item < 0: return -1
			weight = mini(ASYNC_REQUEST_CHARACTERS,weight+item)
		return weight
	return -1

func send(provider: String, endpoint: String, model: String, key: String, prompt: String, instructions: String, tokens: int, seconds: float, png: String = "", context: Array = [], pre_dispatch_guard: Callable = Callable()) -> String:
	return _send(provider,endpoint,model,key,prompt,instructions,tokens,seconds,png,context,pre_dispatch_guard,{})

func send_owned(parameters: Dictionary, completion: Callable, pre_dispatch_guard: Callable) -> Dictionary:
	# Only the Art owner supplies these transport settings. Model/Architecture
	# requests go through art_proposal_transport, which obtains a fresh settings
	# snapshot without accepting credential or endpoint overrides from the model.
	if active: return {"ok":false,"provider_id":-1,"reason":"A model request is already active."}
	if _preparation_active(): return {"ok":false,"provider_id":-1,"reason":"Previous provider preparation is stopping. Retry Send shortly."}
	var problem := _owned_parameters_error(parameters)
	if not completion.is_valid(): problem = "One live response consumer is required."
	if not pre_dispatch_guard.is_valid(): problem = "A live owner context guard is required."
	if not problem.is_empty(): return {"ok":false,"provider_id":-1,"reason":problem}
	var expected_id := serial + 1
	var owner := {"id":expected_id,"request_id":parameters.request_id,"mode":parameters.mode,"completion":completion}
	problem = _send(parameters.provider,parameters.endpoint,parameters.model,parameters.get("key",""),
		parameters.prompt,parameters.instructions,int(parameters.tokens),float(parameters.seconds),
		parameters.get("png",""),parameters.get("context",[]),pre_dispatch_guard,owner)
	# A synchronous audit/guard observer may cancel and start a newer request.
	# Return the captured identity, never the successor's current serial.
	if problem.is_empty() and serial != expected_id: problem = "Owned request retired during dispatch."
	return {"ok":problem.is_empty(),"provider_id":expected_id if problem.is_empty() else -1,
		"request_id":parameters.request_id,"mode":parameters.mode,"reason":problem}

static func _owned_parameters_error(parameters: Dictionary) -> String:
	for field: String in ["request_id","mode","provider","endpoint","model","prompt","instructions"]:
		if not parameters.get(field) is String: return "Owned request field '%s' must be text." % field
	if parameters.mode not in OWNED_MODES: return "Unknown owned request mode."
	if parameters.request_id.is_empty() or parameters.request_id.length() > 256:
		return "Owned requests need a nonempty identity of at most 256 characters."
	if parameters.provider not in ["OpenAI","NVIDIA","LM Studio"]: return "Unknown provider protocol."
	if parameters.endpoint.length() > 2048 or parameters.model.length() > 512:
		return "Owned provider endpoint or model identifier exceeds its bounded setting length."
	if not parameters.get("tokens") is int or int(parameters.tokens) < 1 or int(parameters.tokens) > 65536:
		return "Owned requests need a finite output allowance from 1 to 65536 tokens."
	if not (parameters.get("seconds") is int or parameters.get("seconds") is float):
		return "Owned requests need a numeric timeout."
	if not parameters.get("key","") is String or not parameters.get("png","") is String or not parameters.get("context",[]) is Array:
		return "Owned request credentials, image or conversation have invalid value types."
	if str(parameters.get("key","")).length() > 4096: return "Provider credential exceeds 4096 characters."
	if parameters.get("context",[]).size() > 128: return "Owned context exceeds 128 admitted messages."
	var image_text: String = parameters.get("png","")
	if image_text.length() > MAX_OWNED_IMAGE_BYTES or image_text.to_utf8_buffer().size() > MAX_OWNED_IMAGE_BYTES:
		return "Owned image exceeds the two MiB encoded-image budget."
	var values := {"prompt":parameters.prompt,"instructions":parameters.instructions,"context":parameters.get("context",[])}
	var budget := {"bytes":MAX_OWNED_REQUEST_BYTES,"items":32768}
	if not bounded_json_values(values,budget): return "Owned context exceeds its two MiB, depth or finite-value budget."
	return ""

static func bounded_json_values(value: Variant, budget: Dictionary, depth: int = 0) -> bool:
	# Bound traversal as well as bytes. Large hostile arrays and cyclic containers
	# cannot keep validation busy or enter a value preparation worker unexamined.
	if depth > 24 or int(budget.get("items",0)) <= 0: return false
	budget.items = int(budget.items)-1
	budget.bytes = int(budget.bytes)-1 # Separator/colon allowance per value.
	if value is String:
		if value.length() > int(budget.bytes): return false
		budget.bytes = int(budget.bytes)-value.json_escape().to_utf8_buffer().size()-2
	elif value is Dictionary:
		if value.size() > int(budget.items): return false
		budget.bytes = int(budget.bytes)-2
		for field: Variant in value:
			if not (field is String or field is int) or not bounded_json_values(str(field),budget,depth+1) or not bounded_json_values(value[field],budget,depth+1): return false
	elif value is Array:
		if value.size() > int(budget.items): return false
		budget.bytes = int(budget.bytes)-2
		for item: Variant in value:
			if not bounded_json_values(item,budget,depth+1): return false
	elif value is float:
		if not is_finite(value): return false
		budget.bytes = int(budget.bytes)-24
	elif value == null or value is bool or value is int:
		budget.bytes = int(budget.bytes)-24
	else: return false
	return int(budget.bytes) >= 0

func _send(provider: String, endpoint: String, model: String, key: String, prompt: String, instructions: String, tokens: int, seconds: float, png: String, context: Array, pre_dispatch_guard: Callable, response_owner: Dictionary) -> String:
	if active: return "A model request is already active."
	if _preparation_active(): return "Previous provider preparation is stopping. Retry Send shortly."
	if model.strip_edges().is_empty(): return "Enter a model ID (discovery is optional)."
	if not is_finite(seconds) or seconds <= 0.0 or seconds > 3600.0:
		return "Set a finite request timeout above zero and at most 3600 seconds."
	if not key.is_empty() and not secrets.has(key): secrets.append(key)
	if provider != "LM Studio" and key.is_empty(): return "Enter your "+provider+" key in Key."
	var snapshot_began_usec := Time.get_ticks_usec()
	var body := payload(provider,model,prompt,instructions,tokens,png,context)
	var weight := _request_value_weight(body)
	if weight < 0: return "Request context contains unsupported or excessively nested values."
	serial += 1
	var id := serial
	var began_usec := Time.get_ticks_usec()
	var timing := {"schema":2,"serial":id,"provider":provider,
		"status":"preparing","response_bytes":0,"http_code":0,
		"request_log_usec":0,"dispatch_usec":0,"response_wait_usec":0,
		"transport_wait_usec":0,"dispatch_completed_usec":0,"payload_encode_usec":0,
		"request_call_usec":0,"utf8_decode_usec":0,"response_log_usec":0,
		"json_parse_usec":0,"envelope_decode_usec":0,"other_log_usec":0,
		"projection_redact_usec":0,"signal_usec":0,"callback_usec":0,"cancel_usec":0}
	last_request_timing = timing
	requested_model = model
	last_request_offset = -1
	_prepared_assistant = {}
	_dispatch_guard = pre_dispatch_guard
	_response_owner = response_owner
	usage = {}; returned_model = ""
	retry_after_seconds = 0.0
	active = true
	if not _dispatch_allowed(id): return "Request was cancelled before preparation."
	if not response_owner.is_empty():
		log_event("owned_request",_owned_projection(response_owner,"preparing"))
		if not _dispatch_allowed(id): return "Owned request was cancelled before preparation."
	var prepared := ResponsePreparation.new()
	prepared.direction = "request"
	prepared.request_id = id
	prepared.provider_name = provider
	prepared.request_url = request_url(provider,endpoint)
	prepared.request_key = key
	prepared.request_seconds = seconds
	prepared.request_body = body.duplicate(true) if weight >= ASYNC_REQUEST_CHARACTERS else body
	prepared.secrets_snapshot = secrets.duplicate()
	prepared.timing = timing
	prepared.received_usec = began_usec
	timing.request_snapshot_usec = Time.get_ticks_usec()-snapshot_began_usec
	if weight >= ASYNC_REQUEST_CHARACTERS:
		_preparation = prepared
		request_preparation_jobs = 1
		peak_request_preparation_jobs = maxi(peak_request_preparation_jobs,1)
		timing.status = "preparing_request"
		timing.request_preparation_async = true
		prepared.start(self)
		return ""
	prepared.prepare_inline()
	return _dispatch_prepared_request(prepared,false)

func _dispatch_allowed(id: int) -> bool:
	if id != serial: return false
	if not _dispatch_guard.is_null():
		if not _dispatch_guard.is_valid():
			cancel("Request context became unavailable before dispatch")
			return false
		var allowed: Variant = _dispatch_guard.call()
		if not (allowed is bool and allowed):
			if id == serial: cancel("Request context changed before dispatch")
			return false
	return id == serial

static func _has_http_endpoint(url: String) -> bool:
	# HTTPRequest emits an engine ERROR before returning for malformed authority
	# values. Reject those user-input errors through our normal terminal receipt,
	# including requests prepared asynchronously; this is not a DNS/network probe.
	if not (url.begins_with("http://") or url.begins_with("https://")): return false
	var authority := url.substr(url.find("://")+3).get_slice("/",0).get_slice("?",0).get_slice("#",0)
	for forbidden: String in [" ","\t","\r","\n"]:
		if authority.contains(forbidden): return false
	if authority.contains("@"):
		if authority.count("@") != 1: return false
		authority = authority.get_slice("@",1)
	if authority.is_empty(): return false
	var port := ""
	if authority.begins_with("["):
		var closing := authority.find("]")
		if closing < 0: return false
		var address := authority.substr(1,closing-1)
		if not address.contains(":") or not address.is_valid_ip_address(): return false
		var suffix := authority.substr(closing+1)
		if suffix.is_empty(): return true
		if not suffix.begins_with(":"): return false
		port = suffix.substr(1)
	else:
		if authority.contains("[") or authority.contains("]") or authority.count(":") > 1: return false
		if authority.get_slice(":",0).is_empty(): return false
		if not authority.contains(":"): return true
		port = authority.get_slice(":",1)
	if port.is_empty() or port.length() > 5: return false
	for character: String in port:
		if character < "0" or character > "9": return false
	if port.to_int() < 1 or port.to_int() > 65535: return false
	return true

func _dispatch_prepared_request(prepared: RefCounted, asynchronous: bool) -> String:
	var id: int = prepared.request_id
	var timing: Dictionary = prepared.timing
	if not _dispatch_allowed(id): return "Request was cancelled before dispatch."
	if secrets != prepared.secrets_snapshot:
		_restart_preparation(prepared)
		return ""
	timing.payload_encode_usec = int(prepared.metrics.get("payload_encode_usec",0))
	timing.request_sanitize_usec = int(prepared.metrics.get("sanitize_usec",0))
	timing.request_encode_usec = int(prepared.metrics.get("encode_usec",0))
	timing.request_utf8_encode_usec = int(prepared.metrics.get("utf8_encode_usec",0))
	timing.payload_utf8_encode_usec = int(prepared.metrics.get("payload_utf8_encode_usec",0))
	var request_log_begin_usec := Time.get_ticks_usec()
	_record_event("request",prepared.sanitized,null,null,prepared.encoded_data,prepared.encoded_data_bytes)
	timing.request_log_usec = Time.get_ticks_usec()-request_log_begin_usec
	if not _dispatch_allowed(id): return "Request was cancelled before dispatch."
	request = HTTPRequest.new()
	# Godot4.7's threaded client joins a blocking read before closing its socket.
	# The bounded, nonblocking poll path keeps Stop/timeout/teardown responsive.
	request.use_threads = false
	request.download_chunk_size = 256*1024
	request.timeout = prepared.request_seconds
	request.body_size_limit = 16*1024*1024
	request.max_redirects = 0
	add_child(request)
	request.request_completed.connect(_request_completed.bind(id,prepared.provider_name,prepared.received_usec,timing,request))
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not prepared.request_key.is_empty(): headers.append("Authorization: Bearer "+prepared.request_key)
	var request_begin_usec := Time.get_ticks_usec()
	var err: Error
	if not _has_http_endpoint(prepared.request_url):
		err = ERR_INVALID_PARAMETER
	elif not prepared.encoded_payload_bytes.is_empty():
		err = request.request_raw(prepared.request_url,headers,HTTPClient.METHOD_POST,prepared.encoded_payload_bytes)
	else:
		err = request.request(prepared.request_url,headers,HTTPClient.METHOD_POST,prepared.encoded_payload)
	timing.request_call_usec = Time.get_ticks_usec()-request_begin_usec
	timing.dispatch_completed_usec = Time.get_ticks_usec()
	timing.dispatch_usec = int(timing.dispatch_completed_usec)-prepared.received_usec
	if err != OK:
		var problem := "Could not start HTTP request (%d). Check the endpoint URL." % err
		if asynchronous:
			request.queue_free(); request = null
			log_event("request_start_failed",{"request_id":id,"error_code":err})
			_finish_request(id,"",{},problem,timing,Time.get_ticks_usec())
		else: cancel("Request start failed")
		timing.status = "start_failed"
		return problem
	active = true
	timing.status = "in_flight"
	request_started.emit(id,last_request_offset)
	return ""
