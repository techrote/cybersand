extends RefCounted
## Bounded, read-only linked JSONL walker. A newline commits a modern event;
## only an interrupted tail of the newest modern segment may be recovered.
const CHUNK_BYTES := 65536
const MAX_RECORD_BYTES := 32 * 1024 * 1024
const MAX_SEGMENTS := 4096
const MAX_HEADER_BYTES := 2 * 1024 * 1024
const MAX_CHAIN_HEADER_BYTES := 64 * 1024 * 1024
const TRAFFIC_DIRECTORIES := ["user://art-traffic","user://batch-lab-traffic"]
static var _high_bytes := RegEx.create_from_string("[\\x{0080}-\\x{00ff}]")
var error := ""
var warning := ""
var segments: Array[Dictionary] = []
var done := false
var paused := false
var bytes_read := 0
var total_bytes := 0
var _index := -1
var _input: FileAccess
var _parts: Array[PackedByteArray] = []
var _record_size := 0
var _record_start := 0
var _sequence := 0
var _hash: HashingContext
var _legacy_ids := {}

static func valid_path(path: String) -> bool:
	return path.get_base_dir() in TRAFFIC_DIRECTORIES and path.get_file() not in ["", ".", ".."] and path.get_file().ends_with(".jsonl") and not path.contains("\\") and not path.contains("/./") and not path.contains("/../")

static func valid_directory(directory: String) -> bool:
	if directory not in TRAFFIC_DIRECTORIES: return false
	var actual := canonical_path(directory)
	var expected := canonical_path("user://").path_join("batch-lab-traffic")
	if directory=="user://art-traffic":
		return not actual.is_empty() and actual!=expected and not actual.begins_with(expected+"/")
	var ordinary := canonical_path("user://art-traffic")
	return not actual.is_empty() and not ordinary.is_empty() and actual==expected \
		and actual!=ordinary and not actual.begins_with(ordinary+"/")

static func bound_path(path: String) -> bool:
	if not valid_path(path) or not valid_directory(path.get_base_dir()): return false
	var directory := canonical_path(path.get_base_dir())
	var actual := canonical_path(path)
	if actual.is_empty() or actual.get_base_dir()!=directory: return false
	# Batch transport files belong to individual attempts. They cannot alias
	# another leaf even within the Batch directory. Ordinary same-root reader
	# aliases retain their established canonical-chain checks.
	return path.get_base_dir()!="user://batch-lab-traffic" or actual==directory.path_join(path.get_file())

static func integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and float(value) == floor(float(value)) and float(value) < 9007199254740992.0

static func canonical_path(path: String) -> String:
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	# Resolve aliases before comparison, including symlinked parent directories.
	for _depth in range(40):
		var current := absolute
		var suffix := ""
		var changed := false
		while not current.is_empty() and current.get_base_dir() != current:
			var parent := current.get_base_dir()
			var directory := DirAccess.open(parent)
			if directory != null and directory.is_link(current.get_file()):
				var target := directory.read_link(current.get_file())
				if not target.is_absolute_path(): target = parent.path_join(target)
				absolute = target.path_join(suffix).simplify_path() if not suffix.is_empty() else target.simplify_path()
				changed = true
				break
			suffix = current.get_file().path_join(suffix) if not suffix.is_empty() else current.get_file()
			current = parent
		if not changed: return absolute.to_lower() if OS.has_feature("windows") else absolute
	return "" # Cyclic aliases are never valid archive/export destinations.

static func digest(raw: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(raw)
	return context.finish().hex_encode()

static func utf8_text(raw: PackedByteArray) -> Variant:
	# Validate before Godot decodes: its permissive UTF-8 conversion substitutes
	# invalid bytes. Native regexp skips ASCII runs; only multibyte sequences need
	# the small scalar checks below, without a GDScript loop over image base64.
	if raw.has(0): return null
	var latin := raw.get_string_from_ascii()
	var found := _high_bytes.search(latin)
	if found == null: return latin
	while found != null:
		var position := found.get_start()
		var first := int(raw[position])
		var length := 0
		if first >= 194 and first <= 223: length = 2
		elif first >= 224 and first <= 239: length = 3
		elif first >= 240 and first <= 244: length = 4
		else: return null
		if position + length > raw.size(): return null
		for index: int in range(1, length):
			if raw[position + index] < 128 or raw[position + index] > 191: return null
		var second := int(raw[position + 1])
		if (first == 224 and second < 160) or (first == 237 and second > 159) or (first == 240 and second < 144) or (first == 244 and second > 143): return null
		found = _high_bytes.search(latin, position + length)
	return raw.get_string_from_utf8()

static func decode_record(raw: PackedByteArray, allow_legacy_redaction: bool = false) -> Dictionary:
	var decoded_text: Variant = utf8_text(raw)
	if decoded_text == null: return {"event":null,"error":"Invalid UTF-8 in conversation archive."}
	var text: String = decoded_text
	var parser := JSON.new()
	if parser.parse(text) == OK: return {"event":parser.data,"legacy_redaction":false}
	if not allow_legacy_redaction or not text.contains("[redacted]"): return {"event":null}
	# Historical writers applied a credential regexp to serialized JSON. A
	# numeric credential-like field (including native receipt token) could become
	# an unquoted [redacted]. Interpret only that exact writer artifact, outside
	# strings and immediately after an allowlisted field; raw bytes stay intact.
	var matcher := RegEx.new()
	matcher.compile('(?i)"(api[_-]?key|access_token|token|authorization|password)"[ \t]*:[ \t]*\\[redacted\\]')
	var candidates := matcher.search_all(text)
	if candidates.is_empty(): return {"event":null}
	var replacements := {}
	for candidate: RegExMatch in candidates:
		var marker: int = text.find("[redacted]", candidate.get_start())
		replacements[marker] = true
	var in_string := false
	var escaped := false
	var start := 0
	var pieces: Array[String] = []
	var index := 0
	while index < text.length():
		var character := text.unicode_at(index)
		if not in_string and replacements.has(index):
			pieces.append(text.substr(start, index - start)); pieces.append('"[redacted]"')
			index += 10; start = index
			continue
		if in_string:
			if escaped: escaped = false
			elif character == 92: escaped = true
			elif character == 34: in_string = false
		elif character == 34: in_string = true
		index += 1
	if pieces.is_empty(): return {"event":null}
	pieces.append(text.substr(start))
	if parser.parse("".join(pieces)) != OK: return {"event":null}
	return {"event":parser.data,"legacy_redaction":true}

static func atomic_replace(temporary: String, destination: String) -> Dictionary:
	# The existing native primitive uses one MoveFileExW replacement on Windows;
	# Godot's DirAccess.rename_absolute removes an existing target first there.
	if not ClassDB.class_exists(&"CyberDemoBridge"):
		return {"ok":false,"error":"Atomic file replacement requires the CyberSand native runtime."}
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	if bridge == null or not bridge.has_method(&"replace_material_baseline_file"):
		return {"ok":false,"error":"Native runtime lacks atomic file replacement; rebuild the GDExtension."}
	return bridge.call(&"replace_material_baseline_file", ProjectSettings.globalize_path(temporary).simplify_path(), ProjectSettings.globalize_path(destination).simplify_path())

class ClosedFileVerification extends RefCounted:
	# The expected digest comes from the buffers actually submitted by the writer.
	# Verify only after it closes: Godot get_error() misses some buffered failures.
	# Export callers advance this bounded reader cooperatively and can cancel it.
	var done := false
	var error := ""
	var _file: FileAccess
	var _hash: HashingContext
	var _remaining := 0
	var _expected := ""
	var _expected_length := 0

	func _init(path: String, offset: int, expected_length: int, expected_sha256: String) -> void:
		if offset < 0 or expected_length < offset or expected_sha256.length() != 64 or not expected_sha256.is_valid_hex_number(false):
			_fail("Invalid closed-file verification bounds.")
			return
		_file = FileAccess.open(path, FileAccess.READ)
		if _file == null:
			_fail("Cannot reopen the closed output for verification.")
			return
		if _file.get_length() != expected_length:
			_fail("The closed output is incomplete; check free space and write permissions.")
			return
		_file.seek(offset)
		if _file.get_position() != offset:
			_fail("Cannot seek to the submitted output region.")
			return
		_remaining = expected_length - offset
		_expected = expected_sha256
		_expected_length = expected_length
		_hash = HashingContext.new()
		_hash.start(HashingContext.HASH_SHA256)

	func close() -> void:
		if _file != null: _file.close()
		_file = null

	func _fail(message: String) -> void:
		error = message
		done = true
		close()

	func step(max_bytes: int = 65536) -> void:
		if done: return
		var budget := clampi(max_bytes, 1, 1048576)
		while budget > 0 and _remaining > 0:
			var amount := mini(mini(budget, _remaining), 65536)
			var raw := _file.get_buffer(amount)
			var state := _file.get_error()
			if raw.size() != amount or (state != OK and state != ERR_FILE_EOF) or _hash.update(raw) != OK:
				_fail("Cannot verify the complete closed output.")
				return
			budget -= amount
			_remaining -= amount
		if _remaining == 0:
			if _file.get_length() != _expected_length:
				_fail("The closed output length changed during verification.")
				return
			var observed := _hash.finish().hex_encode()
			close()
			done = true
			if observed != _expected: error = "The closed output bytes differ from the submitted data."

static func read_record(file: FileAccess, limit: int = -1) -> Dictionary:
	var start := file.get_position()
	var end := file.get_length() if limit < 0 else mini(limit, file.get_length())
	var parts: Array[PackedByteArray] = []
	var count := 0
	while file.get_position() < end:
		var block := file.get_buffer(mini(CHUNK_BYTES, end - file.get_position()))
		if block.is_empty(): return {"error":"Cannot read archive record."}
		var newline := block.find(10)
		var used := block.size() if newline < 0 else newline + 1
		count += used
		if count > MAX_RECORD_BYTES: return {"error":"Archive record exceeds the 32 MiB safety limit."}
		parts.append(block.slice(0, used))
		if newline >= 0:
			file.seek(start + count)
			var raw := PackedByteArray()
			for part: PackedByteArray in parts: raw.append_array(part)
			var decoded := decode_record(raw, true)
			decoded.merge({"raw":raw,"start":start,"end":start+count,"tail":false})
			return decoded
	return {"tail":true,"start":start,"end":end}

func fail(message: String) -> bool:
	error = message
	done = true
	_input = null
	_parts.clear()
	return false

func resolve(latest: String) -> bool:
	error = ""; warning = ""; segments.clear(); done = false; paused = false; bytes_read = 0; total_bytes = 0
	_index = -1; _input = null; _parts.clear(); _record_size = 0; _legacy_ids.clear()
	var current := latest
	var directory := latest.get_base_dir()
	if not valid_directory(directory): return fail("Invalid or aliased traffic namespace.")
	var expected_id := ""
	var expected_hash := ""
	var committed_bytes := -1
	var visited := {}
	var identities := {}
	var ancestor_seals := {}
	var sealed_chain := false
	var header_bytes := 0
	for _depth in range(MAX_SEGMENTS):
		if not bound_path(current) or current.get_base_dir()!=directory: return fail("Invalid or cross-namespace saved traffic path: " + current)
		if ancestor_seals.has(current):
			var seal: Dictionary = ancestor_seals[current]
			if (not expected_id.is_empty() and expected_id != seal.id) or (not expected_hash.is_empty() and expected_hash != seal.sha256) or (committed_bytes >= 0 and committed_bytes != int(seal.bytes)):
				return fail("Conflicting conversation ancestor seals: " + current)
			expected_id = seal.id; expected_hash = seal.sha256; committed_bytes = int(seal.bytes)
			ancestor_seals.erase(current)
		elif sealed_chain and expected_hash.is_empty():
			return fail("Modern continuation has an unsealed legacy ancestor: " + current)
		var identity_path := canonical_path(current)
		if identity_path.is_empty() or visited.has(identity_path): return fail("Cyclic or aliased conversation parent chain: " + current)
		visited[identity_path] = true
		var file := FileAccess.open(current, FileAccess.READ)
		if file == null: return fail("Saved conversation segment is unavailable: " + current)
		var length := file.get_length()
		if committed_bytes > length or committed_bytes == 0: return fail("Conversation parent is shorter than its committed length: " + current)
		var limit := committed_bytes if committed_bytes >= 0 else length
		if header_bytes >= MAX_CHAIN_HEADER_BYTES: return fail("Conversation header chain exceeds the 64 MiB safety limit.")
		var first := read_record(file, mini(limit, MAX_CHAIN_HEADER_BYTES - header_bytes))
		if first.has("error") or first.get("tail", false): return fail("Malformed or truncated conversation header: " + current)
		header_bytes += int(first.end)
		var header: Variant = first.get("event")
		if not header is Dictionary or not header.get("kind") is String or not header.has("data"):
			return fail("Malformed conversation record: " + current)
		var modern: bool = header.has("schema") or header.has("segment_id")
		var id := "legacy:" + current.sha256_text()
		if modern:
			if int(first.end) > MAX_HEADER_BYTES: return fail("Conversation metadata exceeds the 2 MiB safety limit.")
			if header.get("schema") != 2 or header.get("kind") not in ["session_start", "session_parent"] or not header.get("segment_id") is String:
				return fail("Unsupported conversation segment header: " + current)
			id = header.segment_id
			if id.length() != 32 or not id.is_valid_hex_number(false) or not header.get("data") is Dictionary:
				return fail("Malformed conversation segment identity: " + current)
		if not expected_id.is_empty() and id != expected_id: return fail("Conversation parent identity changed: " + current)
		if identities.has(id): return fail("Duplicate conversation segment identifier: " + id)
		identities[id] = true
		segments.push_front({"path":current,"id":id,"modern":modern,"limit":limit,"file_bytes":length,"mtime":FileAccess.get_modified_time(current),"expected_sha256":expected_hash,"recover_tail":segments.is_empty() and modern and committed_bytes < 0,"header_end":int(first.end),"header_sha256":digest(first.raw)})
		total_bytes += limit
		if header.kind != "session_parent":
			if not ancestor_seals.is_empty(): return fail("Conversation seals reference unrelated ancestors.")
			if modern and not header.data.is_empty(): return fail("Malformed root segment metadata: " + current)
			return true
		var data: Variant = header.data
		if not data is Dictionary or not data.get("path") is String: return fail("Malformed conversation parent reference: " + current)
		expected_id = ""; expected_hash = ""; committed_bytes = -1
		if modern:
			sealed_chain = true
			var seals: Variant = data.get("legacy_ancestors", [])
			if not seals is Array or seals.size() > MAX_SEGMENTS: return fail("Malformed legacy ancestor seals: " + current)
			var local_seals := {}
			for seal: Variant in seals:
				if not seal is Dictionary or not seal.get("path") is String or not bound_path(seal.path) or seal.path.get_base_dir()!=directory or not seal.get("id") is String or seal.id.is_empty() or not integer(seal.get("bytes"), 1) or not seal.get("sha256") is String or seal.sha256.length() != 64 or not seal.sha256.is_valid_hex_number(false):
					return fail("Malformed legacy ancestor identity: " + current)
				if local_seals.has(seal.path) or visited.has(canonical_path(seal.path)): return fail("Duplicate or cyclic legacy ancestor seal: " + current)
				local_seals[seal.path] = true
				if ancestor_seals.has(seal.path) and ancestor_seals[seal.path] != seal: return fail("Conflicting legacy ancestor identities: " + current)
				ancestor_seals[seal.path] = seal
			if not data.get("parent_id") is String or not integer(data.get("parent_bytes"), 1) or not data.get("parent_sha256") is String:
				return fail("Missing conversation parent identity or committed boundary: " + current)
			expected_id = data.parent_id; expected_hash = data.parent_sha256; committed_bytes = int(data.parent_bytes)
			if expected_id.is_empty() or expected_hash.length() != 64 or not expected_hash.is_valid_hex_number(false): return fail("Malformed conversation parent digest: " + current)
		current = data.path
	return fail("Conversation exceeds the 4096-segment safety limit.")

func _open_next() -> bool:
	_index += 1
	if _index >= segments.size():
		done = true
		return true
	var segment := segments[_index]
	if not bound_path(str(segment.path)): return fail("Conversation source crossed its traffic namespace during reading.")
	_input = FileAccess.open(segment.path, FileAccess.READ)
	if _input == null or _input.get_length() != int(segment.file_bytes) or FileAccess.get_modified_time(segment.path) != int(segment.mtime):
		return fail("Conversation changed or disappeared during reading: " + str(segment.path))
	_hash = HashingContext.new()
	_hash.start(HashingContext.HASH_SHA256)
	_parts.clear(); _record_size = 0; _record_start = 0; _sequence = 0
	return true

func _complete_record(raw: PackedByteArray, consumer: Callable) -> bool:
	var segment := segments[_index]
	var decoded := decode_record(raw, not bool(segment.modern))
	var event: Variant = decoded.get("event")
	if decoded.has("error"): return fail(str(decoded.error) + " " + str(segment.path))
	if decoded.get("legacy_redaction", false):
		_add_warning("Read historical credential-redaction placeholders without changing the original archive bytes.")
	if not event is Dictionary or not event.get("kind") is String or not event.has("data"):
		return fail("Malformed JSONL record at %s:%d." % [segment.path, _record_start])
	if _record_start == 0 and digest(raw) != str(segment.header_sha256): return fail("Conversation header changed during reading: " + str(segment.path))
	var header: bool = event.kind in ["session_start", "session_parent"]
	if header and _record_start != 0: return fail("Unexpected duplicate segment header at " + str(segment.path))
	if bool(segment.modern) and not header:
		_sequence += 1
		if event.get("segment_id") != segment.id or not integer(event.get("event_index"), 1) or int(event.event_index) != _sequence or event.get("event_id") != str(segment.id) + ":" + str(_sequence):
			return fail("Duplicate, missing or inconsistent conversation event identifier at %s:%d." % [segment.path, _record_start])
	elif not bool(segment.modern) and event.has("event_id"):
		if not event.event_id is String or event.event_id.is_empty(): return fail("Malformed legacy event identifier: " + str(segment.path))
		# Legacy IDs are arbitrary strings. Retain a fixed-size digest, not up to
		# 32 MiB of identifier text per entry in the bounded duplicate set.
		var identity_hash: String = event.event_id.sha256_text()
		if _legacy_ids.has(identity_hash): return fail("Duplicate legacy event identifier: " + str(segment.path))
		if _legacy_ids.size() >= 65536: return fail("Legacy event identifiers exceed the 65536-entry validation limit.")
		_legacy_ids[identity_hash] = true
	if consumer.is_valid():
		var result: String = consumer.call(event, str(segment.path), _record_start, raw)
		if not result.is_empty(): return fail(result)
	_hash.update(raw)
	_record_start += raw.size()
	return true

func _add_warning(message: String) -> void:
	if not warning.contains(message): warning += (" " if not warning.is_empty() else "") + message

func step(budget: int, consumer: Callable) -> void:
	if done: return
	var remaining := maxi(1, budget)
	while remaining > 0 and not done:
		if _input == null:
			if not _open_next() or done: return
		var segment := segments[_index]
		var left := int(segment.limit) - _input.get_position()
		if left <= 0:
			if _record_size > 0:
				if not bool(segment.recover_tail) or _sequence < 1: fail("Truncated JSONL record at " + str(segment.path)); return
				_add_warning("Recovered complete events before an interrupted final record; original tail preserved in " + str(segment.path))
				segment.limit = _record_start
				_parts.clear(); _record_size = 0
			var digest := _hash.finish().hex_encode()
			if not str(segment.expected_sha256).is_empty() and segment.expected_sha256 != digest:
				fail("Conversation parent content digest changed: " + str(segment.path)); return
			segment.sha256 = digest
			if _input.get_length() != int(segment.file_bytes) or FileAccess.get_modified_time(segment.path) != int(segment.mtime):
				fail("Conversation changed during reading: " + str(segment.path)); return
			_input = null
			continue
		var block := _input.get_buffer(mini(CHUNK_BYTES, mini(left, remaining)))
		if block.is_empty(): fail("Cannot read conversation segment: " + str(segment.path)); return
		remaining -= block.size(); bytes_read += block.size()
		var start := 0
		while start < block.size():
			var newline := block.find(10, start)
			var end := block.size() if newline < 0 else newline + 1
			var part := block.slice(start, end)
			_parts.append(part); _record_size += part.size()
			if _record_size > MAX_RECORD_BYTES: fail("Archive record exceeds the 32 MiB safety limit: " + str(segment.path)); return
			if newline >= 0:
				var raw := PackedByteArray()
				# Packed-array append_array performs the copy in native code.
				for piece: PackedByteArray in _parts: raw.append_array(piece)
				_parts.clear(); _record_size = 0
				if not _complete_record(raw, consumer): return
				if paused:
					var unused := block.size() - end
					_input.seek(_input.get_position() - unused)
					bytes_read -= unused
					return
			start = end
