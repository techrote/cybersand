extends RefCounted

# Bounded pure values are checked before they cross a native-owner thread.
const Store = preload("res://scripts/persistent_area_store.gd")
const MAX_RESERVATION_BYTES := 8*1024*1024*1024

static func prefetch_error(value: Dictionary) -> String:
	for key: Variant in value:
		if not key is String or not key in ["authoring","capture","identity","receipt","advance_only",
			"operation_id","generation","max_ticks","max_us","reservation_bytes","max_native_bytes"]:
			return "Prefetch request has an unsupported field."
	if not value.get("identity") is Dictionary: return "Prefetch area identity is absent."
	var identity: Dictionary = value.identity
	if not Store._keys(identity,["session_id","area_id","incarnation","runtime_sha256","authored_source_sha256"]) \
			or not identity.get("area_id") is String or not identity.area_id in ["a","b","c"] \
			or not Store._hex(identity.get("session_id"),32) or not Store._hex(identity.get("incarnation"),32) \
			or not Store._hex(identity.get("runtime_sha256"),64) or not Store._hex(identity.get("authored_source_sha256"),64):
		return "Prefetch area, session, incarnation or source/runtime digest is malformed."
	for key: String in ["generation","max_ticks","max_us","reservation_bytes","max_native_bytes"]:
		if value.has(key) and not value[key] is int: return "Prefetch bounds must be exact integers."
	if value.has("operation_id") and not Store._hex(value.operation_id,32): return "Prefetch operation identity is malformed."
	if value.has("advance_only") and not value.advance_only is bool: return "Prefetch mode is malformed."
	var advance_only := bool(value.get("advance_only",false))
	var forbidden := ["authoring","capture","generation","reservation_bytes","max_native_bytes"] \
		if advance_only else ["receipt"]
	for key: String in forbidden:
		if value.has(key): return "Prefetch request contains a field belonging to another operation mode."
	var ticks := int(value.get("max_ticks",1 if advance_only else 0))
	var usec := int(value.get("max_us",5000))
	if ticks<(1 if advance_only else 0) or ticks>(2 if advance_only else 32) \
			or usec<1 or usec>(5000 if advance_only else 100000) or int(value.get("generation",1))<1:
		return "Prefetch work exceeds its admitted native tick/time bounds."
	if advance_only:
		if not value.get("receipt") is Dictionary or not Store._pure(value.receipt,[1024]) \
				or value.receipt.get("identity")!=identity or bool(value.receipt.get("active",true)):
			return "Background stepping requires a pure inactive resident receipt."
	else:
		return checkpoint_error(value)
	return ""

static func handoff_error(value: Dictionary) -> String:
	if not Store._keys(value,["serial","expected_generation","operation_id","target_receipt"]) \
			or not Store._pure(value,[2048]):
		return "Resident handoff accepts only its exact bounded pure-value admission."
	return ""

static func checkpoint_error(value: Dictionary) -> String:
	if not value.get("authoring") is Dictionary or not value.get("capture") is Dictionary \
			or not Store._keys(value.capture,Store.CAPTURE_KEYS) or not value.capture.get("bytes") is PackedByteArray \
			or value.capture.bytes.is_empty() or value.capture.bytes.size()>Store.MAX_NATIVE_BYTES:
		return "Prefetch checkpoint or authoring exceeds its bounded value contract."
	var metadata: Dictionary = value.capture.duplicate(false)
	metadata.erase("bytes")
	if not Store._pure(metadata,[4096]) or not Store._pure(value.authoring,[Store.MAX_VALUE_ITEMS]) \
			or var_to_bytes(value.authoring).size()>Store.MAX_METADATA_BYTES:
		return "Prefetch can transfer only bounded pure authoring and checkpoint metadata."
	var native_bytes := int(value.get("max_native_bytes",0))
	var reserved := int(value.get("reservation_bytes",0))
	if native_bytes<1 or native_bytes>MAX_RESERVATION_BYTES or reserved<native_bytes or reserved>MAX_RESERVATION_BYTES:
		return "Prefetch requires an explicit bounded native and transient memory reservation."
	return ""
