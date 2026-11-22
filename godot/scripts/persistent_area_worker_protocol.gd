extends RefCounted

# Bounded pure values are checked before they cross a native-owner thread.
const Store = preload("res://scripts/persistent_area_store.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const MAX_RESERVATION_BYTES := 8*1024*1024*1024
const EXECUTION_KEYS := ["worker_threads","chunk_size","activity_block_size","scheduling_core_size",
	"maximum_rule_radius","initial_chunk_reserve","parallel_job_threshold","active_core_capacity",
	"active_chunk_capacity","maximum_chunk_count","deferred_event_capacity","maximum_explosion_radius","backend"]
const HOST_KEYS := ["response","simulation_window_enabled","cadence_lod_enabled","liquid_surface_adhesion_enabled","region"]

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
	if not Store.metadata_size([metadata,value.authoring],Store.MAX_METADATA_BYTES-4096).get("ok",false):
		return "Prefetch can transfer only bounded pure authoring and checkpoint metadata."
	# Check fields dereferenced by the private owner before a Thread is launched.
	# Complete source/capsule validation and hashing stay on that private owner.
	var setup: Variant = value.authoring.get("setup")
	if not setup is Dictionary or not Store._keys(setup,Setup.ROOT_KEYS + \
			([Setup.EQUIPMENT_KEY] if setup.has(Setup.EQUIPMENT_KEY) else [])) \
			or not setup.rule_radius is int or not setup.response is String or not setup.liquid_policy is Array:
		return "Prefetch requires a complete typed Workbench setup."
	var execution: Variant = value.capture.get("execution")
	if not execution is Dictionary or not Store._keys(execution,EXECUTION_KEYS) or not execution.get("worker_threads") is int \
			or execution.worker_threads<1 or execution.worker_threads>32 \
			or not value.capture.get("host_settings") is Dictionary:
		return "Prefetch native execution metadata is malformed."
	for key: String in EXECUTION_KEYS:
		if key=="backend":
			if not execution[key] is String or execution[key]!="phased_in_place": return "Prefetch native backend is unsupported."
		elif not execution[key] is int: return "Prefetch execution fields must be exact integers."
	var host: Dictionary = value.capture.host_settings
	if not Store._keys(host,HOST_KEYS) or not host.response is String or not host.response in Setup.RESPONSES \
			or not host.simulation_window_enabled is bool or not host.cadence_lod_enabled is bool \
			or not host.liquid_surface_adhesion_enabled is bool or not host.region is PackedInt32Array or host.region.size()!=4:
		return "Prefetch native host metadata is malformed."
	for key: String in ["schema","format_version","physical_hash_version","completed_tick","native_chunks","native_resident_cell_bytes"]:
		if not value.capture[key] is int: return "Prefetch native capture integers are malformed."
	for key: String in ["sha256","policy_sha256","authored_source_sha256","physics_profile_sha256"]:
		if not Store._hex(value.capture[key],64): return "Prefetch native capture digest is malformed."
	if not Store._hex(value.capture.physical_hash,16) or not value.capture.extent is Vector2i:
		return "Prefetch native physical identity or extent is malformed."
	var native_bytes := int(value.get("max_native_bytes",0))
	var reserved := int(value.get("reservation_bytes",0))
	if native_bytes<1 or native_bytes>MAX_RESERVATION_BYTES or reserved<native_bytes or reserved>MAX_RESERVATION_BYTES:
		return "Prefetch requires an explicit bounded native and transient memory reservation."
	return ""
