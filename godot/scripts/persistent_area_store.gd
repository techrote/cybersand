extends RefCounted
## Three-area desktop continuation store. Native CYPS is authoritative; the
## Workbench envelope preserves authoring identity and camera state separately.
## One controller serializes this object's I/O calls on its private I/O thread.
## Strict publication retains the frozen owner fence. Deferred publication owns
## an immutable captured batch; its ACK describes durable state, never newer RAM.

const Clock = preload("res://scripts/persistent_area_clock.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const MANIFEST_MAGIC := "CYSPROF"
const AREA_MAGIC := "CYSAREA"
const VERSION := 1
const HEADER_BYTES := 52
const MAX_MANIFEST_BYTES := 262144
const MAX_METADATA_BYTES := 8 * 1024 * 1024
const MAX_NATIVE_BYTES := 32 * 1024 * 1024
const MAX_FILE_BYTES := 64 * 1024 * 1024
const MAX_VALUE_ITEMS := 262144
const CURRENT := "current.cypm"
const PREVIOUS := "previous.cypm"
const QUARANTINE := "quarantine.cypm"
const CAPTURE_KEYS := ["schema", "bytes", "sha256", "physical_hash", "physical_hash_version", "format_version",
	"completed_tick", "extent", "policy_sha256", "execution", "host_settings", "authored_source_sha256",
	"physics_profile_sha256", "native_chunks", "native_resident_cell_bytes"]
const RECORD_KEYS := ["area_id", "generation", "incarnation", "mutation_generation", "completed_tick", "blob",
	"sha256", "native_sha256", "authoring_sha256", "physical_hash", "policy_sha256", "authored_source_sha256",
	"physics_profile_sha256", "native_format_version", "physical_hash_version", "extent"]

var _io: Object
var _profile_id := ""
var _compatibility := ""
var _manifest: Dictionary = {}
var _current_bytes := PackedByteArray()
var _current_sha := ""
var _previous: Dictionary = {}
var _previous_sha := ""
var _pending: Dictionary = {}
var _last_commit: Dictionary = {}
var _quarantined := false
var _test_fault := ""
var _test_barrier_phase := ""
var _test_barrier_gate: Semaphore


static func new_nonce() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): hash.update(bytes)
	return hash.finish().hex_encode()


static func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true


static func _identifier(value: String) -> bool:
	if value.is_empty() or value.length() > 64: return false
	for character: String in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_-": return false
	return true


static func _keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key: Variant in expected:
		if not value.has(key): return false
	return true


static func _pure(value: Variant, budget: Array, depth: int = 0) -> bool:
	if depth > 24 or int(budget[0]) <= 0: return false
	budget[0] = int(budget[0]) - 1
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_STRING: return value.length() <= 65536
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4:
			return value.is_finite()
		TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I, TYPE_RECT2I: return true
		TYPE_RECT2: return value.position.is_finite() and value.size.is_finite()
		TYPE_COLOR: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
		TYPE_PACKED_BYTE_ARRAY: return value.size() <= MAX_METADATA_BYTES
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			budget[0] = int(budget[0]) - value.size()
			return int(budget[0]) >= 0
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			for item: Variant in value:
				if not _pure(item, budget, depth + 1): return false
			return true
		TYPE_ARRAY:
			for item: Variant in value:
				if not _pure(item, budget, depth + 1): return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String or not _pure(key, budget, depth + 1) or not _pure(value[key], budget, depth + 1): return false
			return true
	return false # Objects, Callable, RID and NodePath are never persisted.


static func metadata_size(value: Variant, limit_bytes: int = MAX_METADATA_BYTES,
		remaining_items: int = MAX_VALUE_ITEMS) -> Dictionary:
	## Admission without payload-sized allocation before Variant encoding. The returned
	## byte count is a conservative upper bound (including UTF-8, alignment and
	## typed builtin-container headers), not an encoded payload or an RSS value.
	## Repeated packed buffers are charged for every serialized occurrence even
	## when Godot currently shares their underlying storage.
	if limit_bytes<1 or limit_bytes>MAX_METADATA_BYTES or remaining_items<1 or remaining_items>MAX_VALUE_ITEMS:
		return _fail("Metadata admission requires finite byte and item bounds")
	var budget := [limit_bytes,remaining_items]
	if not _metadata_consume(value,budget,0):
		return _fail("Metadata contains unsupported values or exceeds its bounded encoding capacity",
			{"visited_items":remaining_items-int(budget[1])})
	return {"ok":true,"bytes":limit_bytes-int(budget[0]),"visited_items":remaining_items-int(budget[1])}


static func _metadata_charge(budget: Array, bytes: int, items: int = 0) -> bool:
	if bytes<0 or items<0 or bytes>int(budget[0]) or items>int(budget[1]): return false
	budget[0] = int(budget[0])-bytes
	budget[1] = int(budget[1])-items
	return true


static func _metadata_consume(value: Variant, budget: Array, depth: int) -> bool:
	if depth>24 or not _metadata_charge(budget,0,1): return false
	match typeof(value):
		TYPE_NIL: return _metadata_charge(budget,4)
		TYPE_BOOL: return _metadata_charge(budget,8)
		TYPE_INT: return _metadata_charge(budget,12)
		TYPE_FLOAT: return is_finite(value) and _metadata_charge(budget,12)
		TYPE_STRING:
			# UTF-8 needs at most four bytes per Unicode scalar. Counting the
			# existing string avoids allocating a large temporary UTF-8 buffer.
			return value.length()<=65536 and _metadata_charge(budget,16+4*value.length())
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4:
			return value.is_finite() and _metadata_charge(budget,36)
		TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I, TYPE_RECT2I:
			return _metadata_charge(budget,20)
		TYPE_RECT2:
			return value.position.is_finite() and value.size.is_finite() and _metadata_charge(budget,36)
		TYPE_COLOR:
			return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a) \
				and _metadata_charge(budget,20)
		TYPE_PACKED_BYTE_ARRAY:
			return _metadata_charge(budget,16+value.size())
		TYPE_PACKED_INT32_ARRAY:
			return _metadata_charge(budget,16+4*value.size(),value.size())
		TYPE_PACKED_INT64_ARRAY:
			return _metadata_charge(budget,16+8*value.size(),value.size())
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			if not _metadata_charge(budget,16+8*value.size(),value.size()): return false
			for item: float in value:
				if not is_finite(item): return false
			return true
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			if not _metadata_charge(budget,16+24*value.size(),value.size()): return false
			for item: Variant in value:
				if not item.is_finite(): return false
			return true
		TYPE_PACKED_COLOR_ARRAY:
			if not _metadata_charge(budget,16+16*value.size(),value.size()): return false
			for item: Color in value:
				if not is_finite(item.r) or not is_finite(item.g) or not is_finite(item.b) or not is_finite(item.a): return false
			return true
		TYPE_PACKED_STRING_ARRAY:
			if value.size()>int(budget[1]) or not _metadata_charge(budget,16): return false
			for item: String in value:
				if not _metadata_consume(item,budget,depth+1): return false
			return true
		TYPE_ARRAY:
			# Empty typed Object arrays still carry class/script metadata. They
			# must not transfer a hidden live type through a value-only interface.
			if value.get_typed_builtin()==TYPE_OBJECT or value.get_typed_class_name()!=&"" \
					or value.get_typed_script()!=null or value.size()>int(budget[1]) \
					or not _metadata_charge(budget,32): return false
			for item: Variant in value:
				if not _metadata_consume(item,budget,depth+1): return false
			return true
		TYPE_DICTIONARY:
			if value.get_typed_key_builtin()==TYPE_OBJECT or value.get_typed_value_builtin()==TYPE_OBJECT \
					or value.get_typed_key_class_name()!=&"" or value.get_typed_value_class_name()!=&"" \
					or value.get_typed_key_script()!=null or value.get_typed_value_script()!=null \
					or value.size()>int(budget[1])/2 or not _metadata_charge(budget,48): return false
			for key: Variant in value:
				if not key is String or not _metadata_consume(key,budget,depth+1) \
						or not _metadata_consume(value[key],budget,depth+1): return false
			return true
	return false


static func _detached(value: Variant) -> Variant:
	# Object serialization stays disabled. This also detaches packed-array aliases.
	return bytes_to_var(var_to_bytes(value))


static func _fail(message: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"ok":false, "error":message}
	result.merge(extra)
	return result


func current_manifest() -> Dictionary:
	return _detached(_manifest)


func io_telemetry() -> Dictionary:
	## Read through the same serialized I/O owner as all other Store methods.
	if _io == null: return {"available":false,"error":"Persistent storage is closed"}
	if not _io.has_method("telemetry"): return {"available":false,"error":"Runtime has no profile I/O instrumentation"}
	var result: Dictionary = _io.call("telemetry")
	result["available"] = true
	return result


func open_profile(absolute_path: String, profile_id: String, compatibility: String) -> Dictionary:
	if _io != null: return _fail("This persistent profile owner is already open")
	if not _identifier(profile_id) or compatibility.is_empty() or compatibility.length() > 256:
		return _fail("Persistent profile identity or runtime compatibility is invalid")
	if not ClassDB.class_exists("CyberPersistentAreaStorage"):
		return _fail("This native runtime does not provide persistent-area storage")
	_io = ClassDB.instantiate("CyberPersistentAreaStorage")
	var locked: Dictionary = _io.call("acquire", absolute_path)
	if not locked.get("ok", false):
		_io = null
		return locked
	_profile_id = profile_id
	_compatibility = compatibility
	for file: Dictionary in locked.files:
		if not _recognized(file.name):
			_quarantined = true
			return _fail("Persistent profile contains an unknown file; inspect it before continuing: " + str(file.name), {"quarantined":true})
	var current: Dictionary = _io.call("read_file", CURRENT, MAX_MANIFEST_BYTES)
	var previous: Dictionary = _io.call("read_file", PREVIOUS, MAX_MANIFEST_BYTES)
	if not current.get("ok", false) or not previous.get("ok", false):
		_quarantined = true
		return _fail("Persistent manifest is unavailable: " + str(current.get("error", previous.get("error", ""))), {"quarantined":true})
	if previous.exists:
		_previous_sha = previous.sha256
		var validated_previous := _decode_manifest(previous.bytes, true)
		if validated_previous.get("ok", false): _previous = validated_previous.manifest
	if current.exists:
		_current_bytes = current.bytes
		_current_sha = current.sha256
		var decoded := _decode_manifest(current.bytes, true)
		if not decoded.get("ok", false):
			_quarantined = true
			return _fail("Current persistent profile refused: " + str(decoded.error),
				{"quarantined":true, "recovery_available":not _previous.is_empty()})
		_manifest = decoded.manifest
		# A corrupt previous generation is retained for inspection. It is not
		# silently overwritten or used as a seed/recovery source.
		if previous.exists and _previous.is_empty():
			_quarantined = true
			return _fail("Current profile is valid, but the retained previous manifest is corrupt or incompatible",
				{"quarantined":true, "manifest":current_manifest(), "recovery_available":false})
		var collected := _collect_garbage()
		if not collected.get("ok", false): return collected
		return {"ok":true, "fresh":false, "manifest":current_manifest(), "recovery_available":not _previous.is_empty()}
	if not locked.files.is_empty():
		_quarantined = true
		return _fail("Persistent profile has retained files but no current manifest; seed regeneration is refused",
			{"quarantined":true, "recovery_available":not _previous.is_empty()})
	_manifest = {"version":VERSION, "profile_id":profile_id, "session_id":new_nonce(), "compatibility":compatibility,
		"revision":0, "operation_nonce":"", "active_area":"a", "clock":Clock.fresh(), "areas":{}}
	return {"ok":true, "fresh":true, "manifest":current_manifest(), "recovery_available":false}


func close_profile() -> void:
	if _io != null: _io.call("close_profile")
	_io = null
	_manifest = {}
	_previous = {}
	_current_bytes = PackedByteArray()
	_current_sha = ""
	_previous_sha = ""
	_pending = {}
	_last_commit = {}
	_quarantined = false


func set_test_fault(phase: String) -> void:
	## Qualification-only injection. Never configured by ordinary area controls.
	_test_fault = phase if phase in ["", "after_checkpoint", "after_stage", "after_previous", "before_publish", "after_publish"] else ""


func set_test_barrier(phase: String, gate: Semaphore) -> void:
	## Process-death qualification only. No interactive setting enables this.
	## The external harness waits for the marker then terminates the process;
	## callers may instead post the gate to let this exact boundary continue.
	_test_barrier_phase = phase if phase in ["before_snapshot","after_checkpoint","after_stage","after_previous","before_publish","after_publish"] else ""
	_test_barrier_gate = gate if not _test_barrier_phase.is_empty() else null


func _test_barrier(phase: String) -> void:
	if phase != _test_barrier_phase or _test_barrier_gate == null: return
	print("GEN006_RAMCACHE_BARRIER ",JSON.stringify({"phase":phase,"session_id":_manifest.get("session_id",""),
		"revision":_manifest.get("revision",0),"pid":OS.get_process_id()}))
	_test_barrier_gate.wait()
	_test_barrier_phase = ""
	_test_barrier_gate = null


func _fault(phase: String) -> bool:
	_test_barrier(phase)
	if _test_fault != phase: return false
	_test_fault = ""
	return true


static func _wrap(magic: String, metadata: PackedByteArray, native_bytes: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(HEADER_BYTES)
	var encoded_magic := magic.to_utf8_buffer()
	for index: int in 7: bytes[index] = encoded_magic[index]
	bytes[7] = 0
	bytes.encode_u32(8, VERSION)
	bytes.encode_u32(12, metadata.size())
	bytes.encode_u32(16, native_bytes.size())
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(metadata)
	if not native_bytes.is_empty(): hash.update(native_bytes)
	var checksum := hash.finish()
	for index: int in 32: bytes[20 + index] = checksum[index]
	bytes.append_array(metadata)
	bytes.append_array(native_bytes)
	return bytes


static func _unwrap(bytes: PackedByteArray, magic: String, metadata_limit: int, native_limit: int) -> Dictionary:
	if bytes.size() < HEADER_BYTES or bytes.size() > MAX_FILE_BYTES \
		or bytes.slice(0, 7) != magic.to_utf8_buffer() or bytes[7] != 0 or bytes.decode_u32(8) != VERSION:
		return _fail("Unsupported or truncated persistent container")
	var metadata_size := int(bytes.decode_u32(12))
	var native_size := int(bytes.decode_u32(16))
	if metadata_size < 1 or metadata_size > metadata_limit or native_size > native_limit \
		or HEADER_BYTES + metadata_size + native_size != bytes.size():
		return _fail("Persistent container has invalid bounded section lengths")
	var metadata := bytes.slice(HEADER_BYTES, HEADER_BYTES + metadata_size)
	var native_bytes := bytes.slice(HEADER_BYTES + metadata_size)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(metadata)
	if not native_bytes.is_empty(): hash.update(native_bytes)
	if hash.finish() != bytes.slice(20, 52): return _fail("Persistent container integrity check failed")
	return {"ok":true, "metadata":metadata, "native_bytes":native_bytes}


static func _capture_error(capture: Variant) -> String:
	if not capture is Dictionary or not _keys(capture, CAPTURE_KEYS): return "Native continuation capture has an unsupported shape"
	for key: String in ["schema", "format_version", "physical_hash_version", "completed_tick", "native_chunks", "native_resident_cell_bytes"]:
		if not capture[key] is int: return "Native continuation integer field has an invalid type"
	if capture.schema != 1 or capture.format_version != 2 or capture.physical_hash_version != 2:
		return "Native continuation version is unsupported"
	if not capture.bytes is PackedByteArray or capture.bytes.is_empty() or capture.bytes.size() > MAX_NATIVE_BYTES:
		return "Native continuation bytes exceed the admitted capacity"
	if not _hex(capture.sha256, 64) or digest(capture.bytes) != capture.sha256 or not _hex(capture.physical_hash, 16):
		return "Native continuation capture identity does not match its complete bytes"
	for key: String in ["policy_sha256", "authored_source_sha256", "physics_profile_sha256"]:
		if not _hex(capture[key], 64): return "Native continuation source or policy identity is invalid"
	if not Clock._integer(capture.completed_tick) or not Clock._integer(capture.native_chunks) \
		or int(capture.native_chunks) > 128 or not Clock._integer(capture.native_resident_cell_bytes):
		return "Native continuation tick or capacity receipt is invalid"
	if not capture.extent is Vector2i or capture.extent != Vector2i(512, 512) \
		or not capture.execution is Dictionary or not capture.host_settings is Dictionary:
		return "Persistent area requires the admitted 512 by 512 native domain"
	var metadata: Dictionary = capture.duplicate()
	metadata.erase("bytes")
	if not metadata_size(metadata).get("ok",false): return "Native continuation metadata is not bounded pure values"
	return ""


static func _authoring_error(authoring: Variant) -> String:
	if not authoring is Dictionary or not _keys(authoring, ["setup", "definition", "generated_packet", "material_baseline", "camera"]) \
		or not authoring.setup is Dictionary or not authoring.generated_packet is Dictionary \
		or not authoring.material_baseline is Dictionary or not authoring.camera is Dictionary or not authoring.definition is Dictionary:
		return "Persistent authoring envelope is unsupported"
	if not metadata_size(authoring).get("ok",false) or var_to_bytes(authoring).size() > MAX_METADATA_BYTES:
		return "Persistent authoring envelope exceeds the supported pure-value capacity"
	var checked := Contract.validate(authoring.definition)
	if not checked.get("ok", false): return "Persistent original native definition is invalid: " + str(checked.get("error", ""))
	return ""


func _encode_area(id: String, update: Dictionary, generation: int) -> Dictionary:
	if not _keys(update, ["capture", "authoring", "mutation_generation", "incarnation"]): return _fail("Persistent capture update has invalid fields")
	var error := _capture_error(update.capture)
	if error.is_empty(): error = _authoring_error(update.authoring)
	if not error.is_empty(): return _fail(error)
	if Contract.validate(update.authoring.definition).hash != update.capture.authored_source_sha256:
		return _fail("Persistent original definition differs from the native captured source identity")
	if not Clock._integer(update.mutation_generation) or not _hex(update.incarnation, 32):
		return _fail("Persistent capture mutation/incarnation fence is invalid")
	var capture: Dictionary = update.capture.duplicate()
	var native_bytes: PackedByteArray = capture.bytes
	capture.erase("bytes")
	var metadata := {"version":VERSION, "profile_id":_profile_id, "session_id":_manifest.session_id,
		"area_id":id, "generation":generation, "mutation_generation":int(update.mutation_generation),
		"incarnation":update.incarnation, "capture":capture, "authoring":update.authoring}
	if not metadata_size(metadata).get("ok",false): return _fail("Combined persistent metadata exceeds its bounded capacity")
	var encoded := var_to_bytes(metadata)
	if encoded.size() > MAX_METADATA_BYTES: return _fail("Combined persistent metadata exceeds its bounded capacity")
	var bytes := _wrap(AREA_MAGIC, encoded, native_bytes)
	var record := {"area_id":id, "generation":generation, "incarnation":update.incarnation,
		"mutation_generation":int(update.mutation_generation), "completed_tick":int(capture.completed_tick),
		"blob":"area-" + id + "-" + new_nonce() + ".cypa", "sha256":digest(bytes),
		"native_sha256":capture.sha256, "authoring_sha256":digest(var_to_bytes(update.authoring)),
		"physical_hash":capture.physical_hash, "policy_sha256":capture.policy_sha256,
		"authored_source_sha256":capture.authored_source_sha256, "physics_profile_sha256":capture.physics_profile_sha256,
		"native_format_version":int(capture.format_version), "physical_hash_version":int(capture.physical_hash_version), "extent":[512, 512]}
	return {"ok":true, "bytes":bytes, "record":record}


func _decode_area(bytes: PackedByteArray, record: Dictionary, session_id: String) -> Dictionary:
	if digest(bytes) != record.sha256: return _fail("Persistent area blob identity differs from its manifest")
	var container := _unwrap(bytes, AREA_MAGIC, MAX_METADATA_BYTES, MAX_NATIVE_BYTES)
	if not container.get("ok", false): return container
	# bytes_to_var cannot instantiate objects. Validate the admitted value domain
	# before any metadata is used as a World, scene or authoring instruction.
	var metadata: Variant = bytes_to_var(container.metadata)
	if not metadata is Dictionary or not _keys(metadata, ["version", "profile_id", "session_id", "area_id", "generation", "mutation_generation", "incarnation", "capture", "authoring"]) \
		or not _pure(metadata, [MAX_VALUE_ITEMS]): return _fail("Persistent area metadata is malformed")
	if metadata.version != VERSION or metadata.profile_id != _profile_id or metadata.session_id != session_id \
		or metadata.area_id != record.area_id or metadata.generation != record.generation \
		or metadata.mutation_generation != record.mutation_generation or metadata.incarnation != record.incarnation:
		return _fail("Persistent area/session/generation identity differs from its manifest")
	if not metadata.capture is Dictionary: return _fail("Persistent native capture metadata is malformed")
	var capture: Dictionary = metadata.capture
	capture.bytes = container.native_bytes
	var error := _capture_error(capture)
	if error.is_empty(): error = _authoring_error(metadata.authoring)
	if not error.is_empty(): return _fail(error)
	if Contract.validate(metadata.authoring.definition).hash != capture.authored_source_sha256:
		return _fail("Persistent original definition differs from the native captured source identity")
	if capture.completed_tick != record.completed_tick or capture.sha256 != record.native_sha256 \
		or capture.physical_hash != record.physical_hash or capture.policy_sha256 != record.policy_sha256 \
		or capture.authored_source_sha256 != record.authored_source_sha256 or capture.physics_profile_sha256 != record.physics_profile_sha256 \
		or capture.format_version != record.native_format_version or capture.physical_hash_version != record.physical_hash_version \
		or digest(var_to_bytes(metadata.authoring)) != record.authoring_sha256:
		return _fail("Persistent native or authoring identity differs from its manifest")
	return {"ok":true, "capture":capture, "authoring":metadata.authoring, "record":record.duplicate(true)}


func _record_error(record: Variant, id: String) -> String:
	if not record is Dictionary or not _keys(record, RECORD_KEYS) or record.area_id != id:
		return "Persistent area record has invalid identity or shape"
	for key: String in ["generation", "mutation_generation", "completed_tick", "native_format_version", "physical_hash_version"]:
		if not Clock._integer(record[key]): return "Persistent area record has an invalid numeric fence"
	if int(record.generation) < 1 or record.native_format_version != 2 or record.physical_hash_version != 2 \
		or not _hex(record.incarnation, 32) or not record.extent is Array or record.extent.size() != 2 \
		or not Clock._integer(record.extent[0]) or not Clock._integer(record.extent[1]) \
		or int(record.extent[0]) != 512 or int(record.extent[1]) != 512:
		return "Persistent area record has unsupported version, incarnation or extent"
	for key: String in ["sha256", "native_sha256", "authoring_sha256", "policy_sha256", "authored_source_sha256", "physics_profile_sha256"]:
		if not _hex(record[key], 64): return "Persistent area record has an invalid complete identity"
	if not _hex(record.physical_hash, 16) or not record.blob is String \
		or record.blob != "area-" + id + "-" + record.blob.substr(7, 32) + ".cypa" or not _hex(record.blob.substr(7, 32), 32):
		return "Persistent area record has an invalid immutable blob name"
	return ""


func _manifest_error(manifest: Variant) -> String:
	if not manifest is Dictionary or not _keys(manifest, ["version", "profile_id", "session_id", "compatibility", "revision", "operation_nonce", "active_area", "clock", "areas"]):
		return "Persistent manifest has an unsupported schema"
	if not Clock._integer(manifest.version) or manifest.version != VERSION or manifest.profile_id != _profile_id or manifest.compatibility != _compatibility \
		or not _hex(manifest.session_id, 32) or not _hex(manifest.operation_nonce, 32) \
		or not Clock._integer(manifest.revision) or int(manifest.revision) < 1:
		return "Persistent manifest version, profile, runtime or transaction identity is incompatible"
	if not manifest.active_area is String or not manifest.active_area in Clock.AREA_IDS \
		or not manifest.areas is Dictionary or not _keys(manifest.areas, Clock.AREA_IDS):
		return "Persistent manifest must identify three independent areas and one active area"
	var error := Clock.validate(manifest.clock)
	if not error.is_empty(): return error
	for id: String in Clock.AREA_IDS:
		error = _record_error(manifest.areas[id], id)
		if not error.is_empty(): return error
		if int(manifest.areas[id].completed_tick) != int(manifest.clock.areas[id].native_ticks):
			return "Persistent area native time does not match the transaction clock"
	return ""


func _decode_manifest(bytes: PackedByteArray, verify_areas: bool) -> Dictionary:
	if bytes.size() > MAX_MANIFEST_BYTES: return _fail("Persistent manifest exceeds its capacity")
	var container := _unwrap(bytes, MANIFEST_MAGIC, MAX_MANIFEST_BYTES - HEADER_BYTES, 0)
	if not container.get("ok", false): return container
	var text: String = container.metadata.get_string_from_utf8()
	if text.to_utf8_buffer() != container.metadata: return _fail("Persistent manifest contains invalid UTF-8")
	var parsed: Variant = JSON.parse_string(text)
	var error := _manifest_error(parsed)
	if not error.is_empty(): return _fail(error)
	var manifest: Dictionary = parsed
	manifest.version = int(manifest.version)
	manifest.revision = int(manifest.revision)
	manifest.clock = Clock.canonical(manifest.clock)
	for id: String in Clock.AREA_IDS:
		for key: String in ["generation", "mutation_generation", "completed_tick", "native_format_version", "physical_hash_version"]:
			manifest.areas[id][key] = int(manifest.areas[id][key])
		manifest.areas[id].extent = [512, 512]
		if verify_areas:
			var file: Dictionary = _io.call("read_file", manifest.areas[id].blob, MAX_FILE_BYTES)
			if not file.get("ok", false) or not file.get("exists", false): return _fail("Persistent area checkpoint is unavailable: " + id)
			var area := _decode_area(file.bytes, manifest.areas[id], manifest.session_id)
			if not area.get("ok", false): return _fail("Persistent area " + id + " refused: " + str(area.error))
	return {"ok":true, "manifest":manifest}


func read_area(area_id: String) -> Dictionary:
	if _io == null or _quarantined or not _manifest.get("areas", {}).has(area_id): return _fail("Persistent area is unavailable or quarantined")
	var record: Dictionary = _manifest.areas[area_id]
	var file: Dictionary = _io.call("read_file", record.blob, MAX_FILE_BYTES)
	if not file.get("ok", false): return _fail("Persistent area checkpoint is unavailable: " + str(file.get("error", "")))
	if not file.get("exists", false):
		_quarantined = true
		return _fail("Persistent manifest references a missing checkpoint; reopen for explicit recovery", {"quarantined":true})
	var decoded := _decode_area(file.bytes, record, _manifest.session_id)
	if not decoded.get("ok", false):
		_quarantined = true
		return _fail("Persistent area integrity failed; reopen for explicit recovery: " + str(decoded.error), {"quarantined":true})
	return decoded


func prepare_commit(next_state: Dictionary, updates: Dictionary, expected_revision: int, operation_nonce: String, owner_fence: Dictionary) -> Dictionary:
	if _io == null or _quarantined: return _fail("Persistent profile is unavailable or quarantined")
	if not _pending.is_empty(): return _fail("A persistent publication is already prepared")
	if expected_revision != int(_manifest.revision) or not _hex(operation_nonce, 32) \
		or operation_nonce == _manifest.operation_nonce or not metadata_size(owner_fence,16384,1024).get("ok",false) \
		or var_to_bytes(owner_fence).size() > 16384:
		return _fail("Persistent prepare rejected a stale revision or invalid operation/owner fence")
	if not _keys(next_state, ["active_area", "clock"]) or not next_state.active_area in Clock.AREA_IDS:
		return _fail("Persistent next-state selection is invalid")
	var error := Clock.validate(next_state.clock)
	if not error.is_empty(): return _fail(error)
	for key: Variant in updates:
		if not key is String or not key in Clock.AREA_IDS or not updates[key] is Dictionary: return _fail("Persistent update has an unknown area")
	if int(_manifest.revision) == 0 and not _keys(updates, Clock.AREA_IDS): return _fail("Initial durable profile requires all three native area captures")
	if int(_manifest.revision) >= Clock.MAX_INTEGER: return _fail("Persistent transaction revision capacity exhausted")
	var collected := _collect_garbage()
	if not collected.get("ok", false): return collected
	if int(next_state.clock.game_ticks) < int(_manifest.clock.game_ticks): return _fail("Persistent global game time cannot move backwards")
	var candidate: Dictionary = _detached(_manifest)
	candidate.revision = int(_manifest.revision) + 1
	candidate.operation_nonce = operation_nonce
	candidate.active_area = next_state.active_area
	candidate.clock = Clock.canonical(next_state.clock)
	var staged_files := []
	var encoded_updates := {}
	var completed_advancement := 0
	for id: String in Clock.AREA_IDS:
		var before: Dictionary = _manifest.clock.areas[id]
		var after: Dictionary = candidate.clock.areas[id]
		if after.accounted_ticks < before.accounted_ticks: return _fail("Persistent accounted time cannot move backwards")
		if not updates.has(id):
			if after != before: return _fail("Persistent time changed without an authoritative captured area")
			continue
		var prior: Dictionary = _manifest.areas.get(id, {})
		var encoded := _encode_area(id, updates[id], int(prior.get("generation", 0)) + 1)
		if not encoded.get("ok", false): return encoded
		var record: Dictionary = encoded.record
		if record.completed_tick != after.native_ticks: return _fail("Captured native tick differs from proposed accounted time")
		if not prior.is_empty():
			if record.mutation_generation < prior.mutation_generation: return _fail("Persistent mutation generation moved backwards")
			if (record.native_sha256 != prior.native_sha256 or record.authoring_sha256 != prior.authoring_sha256 \
				or record.incarnation != prior.incarnation) and record.mutation_generation <= prior.mutation_generation:
				return _fail("Changed persistent authority requires a newer mutation generation")
			if record.incarnation == prior.incarnation:
				if record.authored_source_sha256 != prior.authored_source_sha256 or record.physics_profile_sha256 != prior.physics_profile_sha256 \
					or record.policy_sha256 != prior.policy_sha256:
					return _fail("Persistent area incarnation cannot adopt another original source or physics profile")
				if record.completed_tick < prior.completed_tick or after.origin_game_tick != before.origin_game_tick:
					return _fail("Persistent native time reset without a new admitted incarnation")
			else:
				if record.completed_tick != 0 or after.origin_game_tick != candidate.clock.game_ticks or after.accounted_ticks != candidate.clock.game_ticks:
					return _fail("Persistent reset must start a fresh native clock at the current game-time frontier")
		completed_advancement += maxi(0, int(record.completed_tick) - int(before.native_ticks))
		candidate.areas[id] = record
		encoded_updates[id] = encoded
	if int(candidate.clock.game_ticks) - int(_manifest.clock.game_ticks) > completed_advancement:
		return _fail("Persistent game time advanced beyond completed native work")
	error = _manifest_error(candidate)
	if not error.is_empty(): return _fail(error)
	# Validate everything before writing any immutable file. A failed write leaves
	# the old current manifest authoritative and the frozen source World intact.
	for id: String in encoded_updates:
		var encoded: Dictionary = encoded_updates[id]
		var written: Dictionary = _io.call("write_new", encoded.record.blob, encoded.bytes)
		if not written.get("ok", false):
			_cleanup(staged_files)
			return written
		staged_files.append(encoded.record.blob)
		if _fault("after_checkpoint"):
			_cleanup(staged_files)
			return _fail("Injected failure after immutable checkpoint publication")
	var manifest_bytes := _wrap(MANIFEST_MAGIC, JSON.stringify(candidate).to_utf8_buffer())
	if manifest_bytes.size() > MAX_MANIFEST_BYTES:
		_cleanup(staged_files)
		return _fail("Persistent manifest exceeded its fixed capacity")
	var stage := "manifest-" + operation_nonce + ".tmp"
	var written: Dictionary = _io.call("write_new", stage, manifest_bytes)
	if not written.get("ok", false):
		_cleanup(staged_files)
		return written
	staged_files.append(stage)
	var receipt := {"session_id":_manifest.session_id, "revision":candidate.revision, "operation_nonce":operation_nonce,
		"prior_sha256":_current_sha, "manifest_sha256":digest(manifest_bytes), "owner_fence_sha256":digest(var_to_bytes(owner_fence))}
	_pending = {"receipt":receipt, "manifest":candidate, "bytes":manifest_bytes, "stage":stage,
		"files":staged_files, "owner_fence":_detached(owner_fence)}
	if _fault("after_stage"):
		abort_prepared(receipt)
		return _fail("Injected failure after staged manifest flush")
	return {"ok":true, "receipt":_detached(receipt), "manifest":_detached(candidate)}


func commit_prepared(receipt: Dictionary, current_owner_fence: Dictionary) -> Dictionary:
	if _io == null or _quarantined: return _fail("Persistent profile is unavailable or quarantined")
	if not _last_commit.is_empty() and receipt == _last_commit.receipt and current_owner_fence == _last_commit.owner_fence \
		and _current_sha == str(receipt.get("manifest_sha256", "")):
		return {"ok":true, "idempotent":true, "manifest":current_manifest()}
	if _pending.is_empty() or receipt != _pending.receipt or current_owner_fence != _pending.owner_fence \
		or _current_sha != receipt.get("prior_sha256", ""):
		return _fail("Persistent commit rejected a stale operation, generation or owner fence")
	var current: Dictionary = _io.call("read_file", CURRENT, MAX_MANIFEST_BYTES)
	if not current.get("ok", false) or str(current.get("sha256", "")) != _current_sha:
		return _fail("Persistent current manifest changed after prepare; publication refused")
	var checked := _decode_manifest(_pending.bytes, true)
	if not checked.get("ok", false):
		_quarantined = true
		return _fail("Prepared checkpoint integrity changed before commit: " + str(checked.error), {"quarantined":true})
	if not _current_bytes.is_empty():
		var previous_stage := "previous-" + str(receipt.operation_nonce) + ".tmp"
		var written: Dictionary = _io.call("write_new", previous_stage, _current_bytes)
		if not written.get("ok", false): return written
		var replaced: Dictionary = _io.call("publish", previous_stage, PREVIOUS, _previous_sha, _current_sha)
		if not replaced.get("ok", false):
			if replaced.get("published", false): _quarantined = true
			return replaced
		_previous = _detached(_manifest)
		_previous_sha = _current_sha
	if _fault("after_previous") or _fault("before_publish"):
		return _fail("Injected failure before current manifest publication; old current remains authoritative")
	var publication: Dictionary = _io.call("publish", _pending.stage, CURRENT, _current_sha, receipt.manifest_sha256)
	if not publication.get("ok", false):
		if publication.get("published", false): _quarantined = true
		return publication
	_manifest = _pending.manifest
	_current_bytes = _pending.bytes
	_current_sha = receipt.manifest_sha256
	_last_commit = {"receipt":_detached(receipt), "owner_fence":_detached(current_owner_fence)}
	_pending = {}
	if _fault("after_publish"):
		_quarantined = true
		return _fail("Injected lost acknowledgement after atomic manifest publication; reopen this profile", {"published":true, "quarantined":true})
	var collected := _collect_garbage()
	return {"ok":true, "idempotent":false, "manifest":current_manifest(),
		"cleanup_warning":"" if collected.get("ok", false) else str(collected.error)}


static func snapshot_fence(manifest: Dictionary, next_state: Dictionary, updates: Dictionary, snapshot_id: String) -> Dictionary:
	## The caller has acquired capture authority and detached the complete batch.
	## A later active edit does not revoke ownership of these immutable bytes. It
	## makes RAM newer than this durable snapshot and must remain visibly dirty.
	if not _hex(snapshot_id,32) or not _hex(manifest.get("session_id"),32) \
		or not manifest.get("compatibility") is String or not manifest.get("areas") is Dictionary \
		or not _keys(manifest.areas,Clock.AREA_IDS) or not _keys(next_state,["active_area","clock"]) \
		or not next_state.active_area in Clock.AREA_IDS or not Clock.validate(next_state.clock).is_empty():
		return _fail("Immutable capture batch has an invalid session, clock or snapshot identity")
	var areas := {}
	for id: String in Clock.AREA_IDS:
		var record: Dictionary = manifest.areas[id]
		if updates.has(id):
			var value: Variant = updates[id]
			if not value is Dictionary or not _keys(value,["capture","authoring","mutation_generation","incarnation"]):
				return _fail("Immutable capture batch has an unsupported area update")
			var error := _capture_error(value.capture)
			if error.is_empty(): error = _authoring_error(value.authoring)
			if not error.is_empty(): return _fail(error)
			if not _hex(value.incarnation,32) or not Clock._integer(value.mutation_generation):
				return _fail("Immutable capture batch has an invalid area mutation/incarnation")
			areas[id] = {"area_id":id,"incarnation":value.incarnation,"mutation_generation":int(value.mutation_generation),
				"completed_tick":int(value.capture.completed_tick),"native_sha256":value.capture.sha256,
				"authoring_sha256":digest(var_to_bytes(value.authoring)),"authored_source_sha256":value.capture.authored_source_sha256,
				"physics_profile_sha256":value.capture.physics_profile_sha256,"policy_sha256":value.capture.policy_sha256}
		else:
			areas[id] = {}
			for key: String in ["area_id","incarnation","mutation_generation","completed_tick","native_sha256",
				"authoring_sha256","authored_source_sha256","physics_profile_sha256","policy_sha256"]:
				if not record.has(key): return _fail("Immutable capture batch has an incomplete unchanged durable area")
				areas[id][key] = record[key]
		if int(areas[id].completed_tick) != int(next_state.clock.areas[id].native_ticks):
			return _fail("Immutable snapshot clock requires a matching capture for every changed area")
	for key: Variant in updates:
		if not key is String or not key in Clock.AREA_IDS: return _fail("Immutable capture batch identifies an unknown area")
	return {"ok":true,"fence":{"schema":"gen006-immutable-capture-v1","session_id":manifest.session_id,
		"compatibility":manifest.compatibility,"snapshot_id":snapshot_id,"clock_sha256":Clock.identity(next_state.clock),
		"active_area":next_state.active_area,"areas":areas}}


func publish_snapshot(next_state: Dictionary, updates: Dictionary, expected_revision: int,
		operation_nonce: String, immutable_fence: Dictionary) -> Dictionary:
	## Single store-owner thread only. The immutable batch is the authority for
	## this publication; it does not assert equality with a subsequently edited
	## live World. Existing revision/CAS/generation/full-byte checks remain intact.
	if _io == null or _quarantined: return _fail("Persistent profile is unavailable or quarantined")
	_test_barrier("before_snapshot")
	if expected_revision != int(_manifest.revision): return _fail("Immutable publication rejected a stale durable revision")
	var rebuilt := snapshot_fence(_manifest,next_state,updates,operation_nonce)
	if not rebuilt.get("ok",false): return rebuilt
	if rebuilt.fence != immutable_fence: return _fail("Immutable publication rejected a changed capture/session/clock fence")
	var prepared := prepare_commit(next_state,updates,expected_revision,operation_nonce,immutable_fence)
	if not prepared.get("ok",false): return prepared
	var committed := commit_prepared(prepared.receipt,immutable_fence)
	if not committed.get("ok",false):
		if not _quarantined and not bool(committed.get("published",false)):
			var aborted := abort_prepared(prepared.receipt)
			if not aborted.get("ok",false): committed["cleanup_warning"] = str(aborted.get("error",""))
		return committed
	committed["snapshot_fence"] = _detached(immutable_fence)
	return committed


func abort_prepared(receipt: Dictionary) -> Dictionary:
	if _quarantined: return _fail("Ambiguous publication is quarantined; reopen before retiring any checkpoint")
	if _pending.is_empty(): return {"ok":true}
	if receipt != _pending.receipt: return _fail("Cannot cancel a different persistent operation")
	var files: Array = _pending.files
	_pending = {}
	return _cleanup(files)


func _cleanup(files: Array) -> Dictionary:
	for name: String in files:
		var removed: Dictionary = _io.call("remove_file", name)
		if not removed.get("ok", false): return removed
	return {"ok":true}


static func _recognized(name: String) -> bool:
	if name in [CURRENT, PREVIOUS, QUARANTINE]: return true
	if name.begins_with("area-") and name.length() == 44 and name.substr(5, 1) in Clock.AREA_IDS \
		and name.substr(6, 1) == "-" and _hex(name.substr(7, 32), 32) and name.ends_with(".cypa"): return true
	for prefix: String in ["manifest-", "previous-", "recover-"]:
		if name.begins_with(prefix) and name.length() == prefix.length() + 36 and name.ends_with(".tmp") \
			and _hex(name.substr(prefix.length(), 32), 32): return true
	return false


func _collect_garbage() -> Dictionary:
	var keep := {CURRENT:true, PREVIOUS:true, QUARANTINE:true}
	for manifest: Dictionary in [_manifest, _previous]:
		for area: Dictionary in manifest.get("areas", {}).values(): keep[area.blob] = true
	for name: String in _pending.get("files", []): keep[name] = true
	var inventory: Dictionary = _io.call("list_files")
	if not inventory.get("ok", false): return inventory
	for file: Dictionary in inventory.files:
		if not _recognized(file.name): return _fail("Unknown file prevents bounded persistent cleanup")
		if not keep.has(file.name):
			var removed: Dictionary = _io.call("remove_file", file.name)
			if not removed.get("ok", false): return removed
	return {"ok":true, "prior_file_count":inventory.files.size(), "prior_bytes":inventory.bytes}


func recover_previous() -> Dictionary:
	## Explicit operator recovery only. The corrupt current bytes are retained
	## once for inspection; no generator/recipe is ever an automatic fallback.
	if _io == null or not _quarantined or _previous.is_empty(): return _fail("No validated previous profile is available for explicit recovery")
	if not _current_bytes.is_empty():
		var kept: Dictionary = _io.call("write_new", QUARANTINE, _current_bytes)
		if not kept.get("ok", false): return _fail("Cannot retain corrupt current manifest before recovery: " + str(kept.error))
	var candidate: Dictionary = _detached(_previous)
	candidate.revision = int(candidate.revision) + 1
	candidate.operation_nonce = new_nonce()
	var bytes := _wrap(MANIFEST_MAGIC, JSON.stringify(candidate).to_utf8_buffer())
	var stage := "recover-" + str(candidate.operation_nonce) + ".tmp"
	var written: Dictionary = _io.call("write_new", stage, bytes)
	if not written.get("ok", false): return written
	var replaced: Dictionary = _io.call("publish", stage, CURRENT, _current_sha, digest(bytes))
	if not replaced.get("ok", false): return replaced
	_manifest = candidate
	_current_bytes = bytes
	_current_sha = digest(bytes)
	_pending = {}
	_last_commit = {}
	_quarantined = false
	var collected := _collect_garbage()
	return {"ok":true, "manifest":current_manifest(), "recovered":true,
		"cleanup_warning":"" if collected.get("ok", false) else str(collected.error)}
