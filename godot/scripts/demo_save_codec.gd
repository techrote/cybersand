class_name CyberDemoSaveCodec
extends RefCounted

# CYSD1 is a reconstructable level, not a mid-tick replay checkpoint.
# LE header: magic[5], version, compression, reserved, width:u16, height:u16,
# JSON length:u32, raw world length:u32, compressed length:u32, SHA-256[32].
# The digest covers header[0:24] followed by JSON and compressed world bytes.
const HEADER_SIZE: int = 56
const WORLD_BYTES: int = 1024 * 1024 * 5
const MAX_METADATA: int = 16384
const MAX_BINARY: int = 8 * 1024 * 1024
const MAX_TEXT: int = 12 * 1024 * 1024
const LOCAL_PATH: String = "user://web_demo_slot_1.cys"

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _digest(prefix: PackedByteArray, payload: PackedByteArray) -> PackedByteArray:
	var hasher: HashingContext = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(prefix)
	hasher.update(payload)
	return hasher.finish()

static func _number(value: Variant, low: float, high: float) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) >= low and float(value) <= high

static func validate_metadata(meta: Dictionary) -> String:
	if not meta.get("demo", null) is String or not CyberDemoWorlds.valid_id(str(meta.demo)):
		return "Unknown demonstration"
	var player: Variant = meta.get("player", null)
	if not player is Array or player.size() != 4:
		return "Invalid player state"
	if not _number(player[0], 0, 1016) or not _number(player[1], 0, 1010):
		return "Player position outside world"
	if not _number(player[2], -1000, 1000) or not _number(player[3], -1000, 1000):
		return "Invalid player velocity"
	var material: Variant = meta.get("material", null)
	if not _number(material, 1, 80):
		return "Invalid selected material"
	if float(material) != float(int(material)) or int(material) == 10:
		return "Invalid selected material"
	var quality: Variant = meta.get("quality", null)
	if not _number(quality, 0, 2) or float(quality) != float(int(quality)):
		return "Invalid quality profile"
	for key: String in ["coherent", "adhesion", "glow"]:
		if typeof(meta.get(key, null)) != TYPE_BOOL:
			return "Invalid option: " + key
	var bodies: Variant = meta.get("bodies", [])
	if not bodies is Array or bodies.size() > 3:
		return "Unsupported rigid-body count"
	if bodies.size() > 0 and str(meta.demo) != "physics_pit":
		return "Rigid bodies outside Physics Pit"
	for body: Variant in bodies:
		if not body is Array or body.size() != 7:
			return "Invalid rigid-body record"
		for i: int in range(6):
			if not _number(body[i], -100000, 100000):
				return "Invalid rigid-body state"
		if not _number(body[0], -32, 1056) or not _number(body[1], -32, 1056):
			return "Rigid body outside supported bounds"
		if typeof(body[6]) != TYPE_BOOL:
			return "Invalid rigid-body sleep state"
	return ""

static func encode(world: PackedByteArray, metadata: Dictionary) -> Dictionary:
	if world.size() != WORLD_BYTES:
		return _error("Wrong native snapshot length")
	var issue: String = validate_metadata(metadata)
	if not issue.is_empty():
		return _error(issue)
	var meta: PackedByteArray = JSON.stringify(metadata).to_utf8_buffer()
	if meta.size() > MAX_METADATA:
		return _error("Save metadata too large")
	var packed: PackedByteArray = world.compress(FileAccess.COMPRESSION_DEFLATE)
	if packed.is_empty():
		return _error("Snapshot compression failed")
	var header: PackedByteArray = "CYSD1".to_ascii_buffer()
	header.resize(24)
	header[5] = 1
	header[6] = 1
	header[7] = 0
	header.encode_u16(8, 1024)
	header.encode_u16(10, 1024)
	header.encode_u32(12, meta.size())
	header.encode_u32(16, WORLD_BYTES)
	header.encode_u32(20, packed.size())
	var payload: PackedByteArray = meta.duplicate()
	payload.append_array(packed)
	var binary: PackedByteArray = header.duplicate()
	binary.append_array(_digest(header, payload))
	binary.append_array(payload)
	if binary.size() > MAX_BINARY:
		return _error("Snapshot exceeds size limit")
	return {"ok": true, "binary": binary, "text": Marshalls.raw_to_base64(binary)}

static func decode_binary(binary: PackedByteArray) -> Dictionary:
	if binary.size() < HEADER_SIZE or binary.size() > MAX_BINARY:
		return _error("Invalid CYSD1 length")
	if binary.slice(0, 5).get_string_from_ascii() != "CYSD1":
		return _error("Not a CYSD1 save")
	if binary[5] != 1:
		return _error("Unsupported CYSD1 version")
	if binary[6] != 1 or binary[7] != 0:
		return _error("Unsupported CYSD1 encoding")
	if binary.decode_u16(8) != 1024 or binary.decode_u16(10) != 1024:
		return _error("Unsupported world dimensions")
	var meta_size: int = binary.decode_u32(12)
	var raw_size: int = binary.decode_u32(16)
	var packed_size: int = binary.decode_u32(20)
	if meta_size <= 0 or meta_size > MAX_METADATA or raw_size != WORLD_BYTES or packed_size <= 0:
		return _error("Invalid snapshot sizes")
	if HEADER_SIZE + meta_size + packed_size != binary.size():
		return _error("Truncated or trailing save data")
	var payload: PackedByteArray = binary.slice(HEADER_SIZE)
	if _digest(binary.slice(0, 24), payload) != binary.slice(24, HEADER_SIZE):
		return _error("Save checksum mismatch")
	var parsed: Variant = JSON.parse_string(payload.slice(0, meta_size).get_string_from_utf8())
	if not parsed is Dictionary:
		return _error("Invalid save metadata")
	var meta: Dictionary = parsed
	var issue: String = validate_metadata(meta)
	if not issue.is_empty():
		return _error(issue)
	var world: PackedByteArray = payload.slice(meta_size).decompress(WORLD_BYTES, FileAccess.COMPRESSION_DEFLATE)
	if world.size() != WORLD_BYTES:
		return _error("World decompression failed")
	# The native import adapter validates material IDs before committing.
	return {"ok": true, "metadata": meta, "world": world}

static func decode_text(text: String) -> Dictionary:
	if text.length() > MAX_TEXT:
		return _error("Portable save exceeds size limit")
	var normalized: String = text.replace(" ", "").replace("\t", "").replace("\r", "").replace("\n", "")
	if normalized.is_empty() or normalized.length() % 4 != 0:
		return _error("Malformed Base64")
	var pattern: RegEx = RegEx.new()
	pattern.compile("^[A-Za-z0-9+/]*={0,2}$")
	if pattern.search(normalized) == null:
		return _error("Malformed Base64")
	var binary: PackedByteArray = Marshalls.base64_to_raw(normalized)
	if Marshalls.raw_to_base64(binary) != normalized:
		return _error("Non-canonical Base64")
	return decode_binary(binary)
