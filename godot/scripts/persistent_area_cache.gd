extends RefCounted
## Main-thread residency/durability ledger. Native Worlds remain uniquely owned
## by the existing worker/bridge; this ledger holds fenced value receipts only.
## A cached byte buffer is WARM. Only an admitted native handle is HOT.

const Store = preload("res://scripts/persistent_area_store.gd")
const Clock = preload("res://scripts/persistent_area_clock.gd")
const MAX_BUDGET_BYTES := 8 * 1024 * 1024 * 1024
const DEFAULT_BUDGET_BYTES := 512 * 1024 * 1024
const MAX_RESERVATIONS := 4
const MAX_PINS_PER_AREA := 8
const MAX_PUBLICATION_HEADROOM_BYTES := 9 * (Store.MAX_NATIVE_BYTES + Store.MAX_METADATA_BYTES)

var enabled := true
var budget_bytes := DEFAULT_BUDGET_BYTES
var active_area := ""
var _opened_active_area := ""
var session_id := ""
var compatibility := ""
var runtime_sha256 := ""
var durable_revision := 0
var _entries: Dictionary = {}
var _reservations: Dictionary = {}
var _publication: Dictionary = {}
var _sequence := 0
var _counters := {"hot_hits":0,"warm_hits":0,"cold_misses":0,"reservation_refusals":0,
	"hot_admissions":0,"warm_admissions":0,"evictions":0,"stale_acks":0,"hot_refresh_encodes":0,
	"authoring_admission_encodes":0}


static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"error":reason}


func open(manifest: Dictionary, maximum_bytes: int = DEFAULT_BUDGET_BYTES) -> Dictionary:
	if not _entries.is_empty(): return _fail("A cache session is already open")
	if not Store._hex(manifest.get("session_id"),32) or not manifest.get("compatibility") is String \
		or not manifest.get("areas") is Dictionary or not Store._keys(manifest.areas,Clock.AREA_IDS) \
		or not manifest.get("active_area") in Clock.AREA_IDS \
		or not Clock._integer(manifest.get("revision")) or int(manifest.revision) < 1 \
		or not Clock.validate(manifest.get("clock")).is_empty():
		return _fail("Cache opening requires a complete admitted durable manifest")
	if maximum_bytes < 0 or maximum_bytes > MAX_BUDGET_BYTES: return _fail("Cache budget is outside its bounded range")
	for id: String in Clock.AREA_IDS:
		var record: Dictionary = manifest.areas[id]
		if record.get("area_id") != id or not Store._hex(record.get("incarnation"),32) \
			or not Store._hex(record.get("authored_source_sha256"),64) or not Store._hex(record.get("physics_profile_sha256"),64) \
			or not Clock._integer(record.get("mutation_generation")) or not Clock._integer(record.get("completed_tick")):
			return _fail("Cache opening found an invalid durable area identity")
	session_id = str(manifest.session_id)
	compatibility = str(manifest.compatibility)
	runtime_sha256 = compatibility.get_slice(":",compatibility.get_slice_count(":")-1)
	durable_revision = int(manifest.revision)
	_opened_active_area = str(manifest.active_area)
	budget_bytes = maximum_bytes
	enabled = maximum_bytes > 0
	for id: String in Clock.AREA_IDS:
		var record: Dictionary = manifest.areas[id]
		_entries[id] = {"area_id":id,"incarnation":str(record.incarnation),
			"authored_source_sha256":str(record.authored_source_sha256),"physics_profile_sha256":str(record.physics_profile_sha256),
			"resident_generation":0,"last_handle":0,"mutation_generation":int(record.mutation_generation),"completed_tick":int(record.completed_tick),
			"hot":{},"warm":{},"authoring":{},"native_bytes":0,"native_headroom_bytes":0,"warm_bytes":0,"authoring_bytes":0,
			"authoring_sha256":str(record.authoring_sha256),"warm_mutation_generation":-1,
			"durable":record.duplicate(true),"dirty":false,"pins":{},"last_use":0,"failure":""}
	return {"ok":true}


func configure(cache_enabled: bool, maximum_bytes: int) -> Dictionary:
	if maximum_bytes < 0 or maximum_bytes > MAX_BUDGET_BYTES: return _fail("Cache budget is outside its bounded range")
	enabled = cache_enabled and maximum_bytes > 0
	budget_bytes = maximum_bytes
	# A lower budget blocks admissions immediately. Actual native releases are
	# explicit acknowledged operations; changing an enum never discards a World.
	return {"ok":true,"evictions":eviction_candidates(),"status":status()}


func entry(area_id: String) -> Dictionary:
	if not _entries.has(area_id): return {}
	var result: Dictionary = _entries[area_id].duplicate(true)
	result["residency"] = "HOT" if not result.hot.is_empty() else ("WARM" if not result.warm.is_empty() else "COLD")
	result["receipt"] = result.hot
	result["capture"] = result.warm
	return result


func _touch(area_id: String) -> void:
	_sequence += 1
	_entries[area_id].last_use = _sequence


func set_active(area_id: String) -> Dictionary:
	if not _entries.has(area_id) or _entries[area_id].hot.is_empty(): return _fail("Only an admitted hot native World can become cache-active")
	active_area = area_id
	_touch(area_id)
	return {"ok":true}


func pin(area_id: String, operation_id: String) -> Dictionary:
	if not _entries.has(area_id) or not Store._hex(operation_id,32): return _fail("Cache pin identity is invalid")
	var pins: Dictionary = _entries[area_id].pins
	if not pins.has(operation_id) and pins.size() >= MAX_PINS_PER_AREA: return _fail("Cache pin capacity exhausted")
	pins[operation_id] = true
	return {"ok":true}


func unpin(area_id: String, operation_id: String) -> void:
	if _entries.has(area_id): _entries[area_id].pins.erase(operation_id)


func _used_bytes() -> int:
	var total := 0
	for value: Dictionary in _entries.values(): total += int(value.native_bytes)+int(value.native_headroom_bytes)+int(value.warm_bytes)+int(value.authoring_bytes)
	return total


func _reserved_bytes(except_operation: String = "") -> int:
	var total := 0
	for key: String in _reservations:
		if key != except_operation: total += int(_reservations[key].bytes)
	return total


func reserve(operation_id: String, area_id: String, bytes: int, priority: int = 0) -> Dictionary:
	if not Store._hex(operation_id,32) or not _entries.has(area_id) or bytes < 0 or bytes > MAX_BUDGET_BYTES \
		or priority < 0 or priority > 3:
		return _fail("Cache reservation has invalid identity, size or priority")
	if _reservations.has(operation_id):
		var existing: Dictionary = _reservations[operation_id]
		if existing.area_id == area_id and int(existing.bytes) == bytes and int(existing.priority) == priority:
			return {"ok":true,"idempotent":true,"reservation":existing.duplicate(true)}
		return _fail("An existing cache reservation cannot change its identity or size")
	if not enabled or not _publication.is_empty() or _reservations.size() >= MAX_RESERVATIONS or _used_bytes()+_reserved_bytes()+bytes > budget_bytes:
		_counters.reservation_refusals += 1
		return {"ok":false,"error":"Cache admission exceeds the configured retained and reserved memory budget",
			"evictions":eviction_candidates(bytes),"used_bytes":_used_bytes(),"reserved_bytes":_reserved_bytes()}
	_reservations[operation_id] = {"operation_id":operation_id,"area_id":area_id,"bytes":bytes,"priority":priority}
	return {"ok":true,"reservation":_reservations[operation_id].duplicate(true)}


func release_reservation(operation_id: String) -> void:
	_reservations.erase(operation_id)


func reserve_publication(operation_id: String, maximum_bytes: int) -> Dictionary:
	## Essential capture/publication has a separately bounded working reserve.
	## It cannot deadlock Save-all when the only dirty authorities fill cache RAM.
	## Speculative preparations yield while this reserve is held. This is not a
	## claim that the retained-cache setting strictly caps total process RSS.
	if not Store._hex(operation_id,32) or maximum_bytes < 1 or maximum_bytes > MAX_PUBLICATION_HEADROOM_BYTES:
		return _fail("Essential publication headroom exceeds its fixed bounded capacity")
	if not _publication.is_empty():
		if _publication.operation_id == operation_id and int(_publication.bytes)==maximum_bytes:
			return {"ok":true,"idempotent":true,"reservation":_publication.duplicate(true)}
		return _fail("One essential publication working reservation is already outstanding")
	for reserved_id: String in _reservations:
		if reserved_id != operation_id: return _fail("Essential publication waits for other speculative preparation reservations to retire")
	_publication = {"operation_id":operation_id,"bytes":maximum_bytes,"kind":"essential-capture-and-publication"}
	return {"ok":true,"reservation":_publication.duplicate(true)}


func resize_publication(operation_id: String, bytes: int) -> Dictionary:
	if _publication.is_empty() or _publication.operation_id != operation_id or bytes < 1 or bytes > int(_publication.bytes):
		return _fail("Publication headroom can only shrink its exact outstanding reservation")
	_publication.bytes = bytes
	return {"ok":true,"reservation":_publication.duplicate(true)}


func release_publication(operation_id: String) -> Dictionary:
	if _publication.is_empty(): return {"ok":true,"idempotent":true}
	if _publication.operation_id != operation_id: return _fail("A stale operation cannot release another publication's headroom")
	_publication = {}
	return {"ok":true}


func _admission(area_id: String, additional_bytes: int, reservation_id: String, admitted_active_owner: bool = false) -> String:
	if not reservation_id.is_empty():
		if not _reservations.has(reservation_id) or _reservations[reservation_id].area_id != area_id:
			return "Cache admission has no matching resource reservation"
		if additional_bytes > int(_reservations[reservation_id].bytes): return "Native/cache result exceeded its reserved resource bound"
	# The existing active owner remains usable even if the user lowers the budget
	# below it. This exception cannot admit an additional inactive candidate.
	if admitted_active_owner: return ""
	if not enabled or _used_bytes()+_reserved_bytes(reservation_id)+additional_bytes > budget_bytes:
		return "Cache admission exceeds the configured retained and reserved memory budget"
	return ""


static func _normalized_definition_value(value: Variant) -> bool:
	# Contract.validate returns this exact JSON value domain. Packed arrays can
	# stringify to the same JSON as Array while failing the source contract, so
	# the digest alone cannot establish that the supplied host value is admitted.
	# The caller first bounds recursion, items and aggregate bytes with metadata_size.
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_STRING: return true
		TYPE_ARRAY:
			for entry: Variant in value:
				if not _normalized_definition_value(entry): return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String or not _normalized_definition_value(value[key]): return false
			return true
	return false


func _admitted_authoring(authoring: Dictionary, source_sha256: String) -> Dictionary:
	# This is a cache reuse check against the original definition already fully
	# validated by Store/native admission, never a new construction validator.
	# Preserve all source fields in the canonical identity; no projection,
	# coercion, geometry truncation or transport-table reconstruction occurs here.
	if not Store._keys(authoring,["setup","definition","generated_packet","material_baseline","camera"]) \
		or not authoring.setup is Dictionary or not authoring.definition is Dictionary \
		or not authoring.generated_packet is Dictionary or not authoring.material_baseline is Dictionary \
		or not authoring.camera is Dictionary:
		return _fail("Persistent authoring envelope is unsupported")
	if not Store.metadata_size(authoring).get("ok",false):
		return _fail("Persistent authoring envelope exceeds its bounded metadata capacity")
	if not _normalized_definition_value(authoring.definition):
		return _fail("Persistent original source is not the admitted normalized definition")
	var canonical := JSON.stringify(authoring.definition,"",true)
	if canonical.to_utf8_buffer().size()>Store.Contract.MAX_JSON_BYTES or canonical.sha256_text()!=source_sha256:
		return _fail("Persistent original definition differs from its complete admitted source identity")
	_counters.authoring_admission_encodes += 1
	var encoded := var_to_bytes(authoring)
	if encoded.size()>Store.MAX_METADATA_BYTES:
		return _fail("Persistent authoring envelope exceeds its encoded metadata capacity")
	return {"ok":true,"bytes":encoded.size(),"sha256":Store.digest(encoded)}


func admit_hot(area_id: String, receipt: Dictionary, authoring: Dictionary, mutation_generation: int,
		reservation_id: String = "", mandatory_active: bool = false) -> Dictionary:
	if not _entries.has(area_id): return _fail("Unknown cache area")
	var item: Dictionary = _entries[area_id]
	var identity: Variant = receipt.get("identity")
	if receipt.get("schema") != 1 or not Clock._integer(receipt.get("handle")) or int(receipt.handle) < 1 \
		or not identity is Dictionary or identity.get("session_id") != session_id or identity.get("area_id") != area_id \
		or identity.get("incarnation") != item.incarnation or identity.get("authored_source_sha256") != item.authored_source_sha256 \
		or identity.get("runtime_sha256") != runtime_sha256 or receipt.get("physics_profile_sha256") != item.physics_profile_sha256 \
		or not receipt.get("active") is bool:
		return _fail("Hot native receipt differs from the admitted session, area, incarnation, source or runtime")
	# Only the already authoritative native owner may survive a user lowering
	# the retention budget below its existing allocation. A caller's convenience
	# flag cannot grant an inactive candidate this exception.
	if mandatory_active and (not bool(receipt.active) \
		or area_id != (active_area if not active_area.is_empty() else _opened_active_area)):
		return _fail("The cache budget exception requires the exact already-active native owner")
	for key: String in ["resident_generation","mutation_generation","completed_tick","native_bytes"]:
		if not Clock._integer(receipt.get(key)): return _fail("Hot native receipt contains an invalid numeric fence")
	var native_reservation: Variant = receipt.get("native_reservation_bytes",receipt.native_bytes)
	if not Clock._integer(native_reservation) or int(native_reservation) < int(receipt.native_bytes):
		return _fail("Hot native allocation exceeds its admitted growth reservation")
	if mutation_generation < int(item.mutation_generation) or int(receipt.completed_tick) < int(item.completed_tick):
		return _fail("Hot admission cannot roll back resident edits or completed time")
	if not item.hot.is_empty() and int(receipt.resident_generation) < int(item.resident_generation):
		return _fail("Hot admission cannot roll back the existing native handle generation")
	if item.hot.is_empty() and int(receipt.handle) <= int(item.last_handle):
		return _fail("A released native handle cannot be readmitted by a stale receipt")
	if not item.hot.is_empty() and int(receipt.handle) != int(item.hot.handle):
		return _fail("A native resident handle must be released before another replaces it")
	var admitted := _admitted_authoring(authoring,str(item.authored_source_sha256))
	if not admitted.get("ok",false): return admitted
	var authoring_bytes := int(admitted.bytes)
	var additional := int(native_reservation)-int(item.native_bytes)-int(item.native_headroom_bytes)+authoring_bytes-int(item.authoring_bytes)
	var error := _admission(area_id,additional,reservation_id,mandatory_active)
	if not error.is_empty(): return _fail(error)
	item.hot = receipt.duplicate(true)
	item.last_handle = int(receipt.handle)
	item.native_bytes = int(receipt.native_bytes)
	item.native_headroom_bytes = int(native_reservation)-int(receipt.native_bytes)
	item.resident_generation = int(receipt.resident_generation)
	item.mutation_generation = mutation_generation
	item.completed_tick = int(receipt.completed_tick)
	item.authoring = authoring.duplicate(true)
	item.authoring_bytes = authoring_bytes
	item.authoring_sha256 = admitted.sha256
	if not item.warm.is_empty() and (int(item.warm.completed_tick) != int(item.completed_tick) \
		or int(item.warm_mutation_generation) != mutation_generation):
		item.warm = {}
		item.warm_bytes = 0
	item.dirty = _is_dirty(item)
	item.failure = ""
	_touch(area_id)
	if not reservation_id.is_empty(): release_reservation(reservation_id)
	_counters.hot_admissions += 1
	return {"ok":true,"dirty":item.dirty}


func refresh_hot(area_id: String, receipt: Dictionary, mutation_generation: int, authoring: Dictionary = {}) -> Dictionary:
	## The complete definition/continuation was admitted before this native
	## handle entered the ledger. Re-entry validates its small native receipt;
	## it neither reconstructs nor revalidates that unchanged original geometry.
	if not _entries.has(area_id) or _entries[area_id].hot.is_empty(): return _fail("Hot refresh requires an already admitted resident World")
	var item: Dictionary = _entries[area_id]
	if receipt.get("schema") != 1 or receipt.get("identity") != item.hot.identity \
		or receipt.get("handle") != item.hot.handle or receipt.get("physics_profile_sha256") != item.physics_profile_sha256 \
		or not receipt.get("active") is bool:
		return _fail("Hot refresh cannot replace a native handle or its admitted identity")
	for key: String in ["resident_generation","mutation_generation","completed_tick","native_bytes"]:
		if not Clock._integer(receipt.get(key)): return _fail("Hot refresh has an invalid numeric native fence")
	var native_reservation: Variant = receipt.get("native_reservation_bytes",receipt.native_bytes)
	if not Clock._integer(native_reservation) or int(native_reservation) < int(receipt.native_bytes):
		return _fail("Hot native allocation exceeds its admitted growth reservation")
	if int(receipt.resident_generation) < int(item.resident_generation) or int(receipt.completed_tick) < int(item.completed_tick) \
		or mutation_generation < int(item.mutation_generation): return _fail("Hot refresh cannot roll back resident authority")
	var authoring_changed: bool = not authoring.is_empty() and authoring != item.authoring
	var authoring_bytes := int(item.authoring_bytes)
	var encoded_authoring := PackedByteArray()
	if authoring_changed:
		if not Store._keys(authoring,["setup","definition","generated_packet","material_baseline","camera"]) \
			or not authoring.setup is Dictionary or not authoring.generated_packet is Dictionary \
			or not authoring.material_baseline is Dictionary or not authoring.camera is Dictionary \
			or authoring.definition != item.authoring.definition:
			return _fail("Hot authoring update cannot replace its original admitted construction")
		# A packed buffer is charged for every serialized occurrence. The item
		# budget alone cannot bound aliased payload expansion before encoding.
		if not Store.metadata_size(authoring).get("ok",false): return _fail("Hot authoring changes exceed their bounded metadata boundary")
		_counters.hot_refresh_encodes += 1
		encoded_authoring = var_to_bytes(authoring)
		authoring_bytes = encoded_authoring.size()
		if authoring_bytes > Store.MAX_METADATA_BYTES: return _fail("Hot authoring envelope exceeds its metadata bound")
	var additional := int(native_reservation)-int(item.native_bytes)-int(item.native_headroom_bytes) \
		+authoring_bytes-int(item.authoring_bytes)
	if additional>0:
		var error := _admission(area_id,additional,"",area_id==active_area and bool(receipt.active))
		if not error.is_empty(): return _fail(error)
	if authoring_changed:
		item.authoring = authoring.duplicate(true)
		item.authoring_bytes = authoring_bytes
		item.authoring_sha256 = Store.digest(encoded_authoring)
	item.hot = receipt.duplicate(true)
	item.native_bytes = int(receipt.native_bytes)
	item.native_headroom_bytes = int(native_reservation)-int(receipt.native_bytes)
	item.resident_generation = int(receipt.resident_generation)
	item.mutation_generation = mutation_generation
	item.completed_tick = int(receipt.completed_tick)
	if not item.warm.is_empty() and (int(item.warm.completed_tick) != int(item.completed_tick) \
		or int(item.warm_mutation_generation) != mutation_generation):
		item.warm = {}
		item.warm_bytes = 0
	item.dirty = _is_dirty(item)
	_touch(area_id)
	return {"ok":true,"dirty":item.dirty,"over_budget":_used_bytes()+_reserved_bytes()>budget_bytes}


func retain_warm(area_id: String, capture: Dictionary, authoring: Dictionary, mutation_generation: int,
		incarnation: String, reservation_id: String = "", mandatory_active: bool = false,
		preserve_reservation: bool = false) -> Dictionary:
	if not _entries.has(area_id): return _fail("Unknown cache area")
	if mandatory_active: return _fail("Warm checkpoint bytes cannot use the active native owner's budget exception")
	if preserve_reservation and reservation_id.is_empty(): return _fail("A prepared warm admission must retain its matching resource reservation")
	var item: Dictionary = _entries[area_id]
	var error := Store._capture_error(capture)
	if not error.is_empty(): return _fail(error)
	if incarnation != item.incarnation or capture.authored_source_sha256 != item.authored_source_sha256 \
		or capture.physics_profile_sha256 != item.physics_profile_sha256:
		return _fail("Warm state differs from the admitted source or area incarnation")
	if mutation_generation < int(item.mutation_generation) or int(capture.completed_tick) < int(item.completed_tick):
		return _fail("Warm state cannot supersede newer resident edits or native time")
	var admitted := _admitted_authoring(authoring,str(item.authored_source_sha256))
	if not admitted.get("ok",false): return admitted
	var warm_bytes := var_to_bytes(capture).size()
	var authoring_bytes := int(admitted.bytes)
	var additional := warm_bytes-int(item.warm_bytes)+authoring_bytes-int(item.authoring_bytes)
	error = _admission(area_id,additional,reservation_id)
	if not error.is_empty(): return _fail(error)
	item.warm = capture.duplicate(true)
	item.warm_bytes = warm_bytes
	item.warm_mutation_generation = mutation_generation
	item.authoring = authoring.duplicate(true)
	item.authoring_bytes = authoring_bytes
	item.authoring_sha256 = admitted.sha256
	item.mutation_generation = mutation_generation
	item.completed_tick = int(capture.completed_tick)
	item.dirty = _is_dirty(item)
	_touch(area_id)
	if not reservation_id.is_empty():
		if preserve_reservation:
			# Transfer materialized checkpoint bytes into retained accounting while
			# preserving the remaining native preparation allocation. Keeping the
			# original full reservation would double-charge the same warm buffer.
			_reservations[reservation_id].bytes -= maxi(0,additional)
		else: release_reservation(reservation_id)
	_counters.warm_admissions += 1
	return {"ok":true,"dirty":item.dirty}


func mark_dirty(area_id: String, native_tick: int, mutation_generation: int, authoring: Dictionary = {}) -> Dictionary:
	if not _entries.has(area_id): return _fail("Unknown cache area")
	var item: Dictionary = _entries[area_id]
	if native_tick < int(item.completed_tick) or mutation_generation < int(item.mutation_generation):
		return _fail("Resident mutation/time cannot move backwards")
	if item.hot.is_empty(): return _fail("Only a retained native owner may mutate resident authority")
	if not authoring.is_empty():
		var admitted := _admitted_authoring(authoring,str(item.authored_source_sha256))
		if not admitted.get("ok",false): return admitted
		var additional := int(admitted.bytes)-int(item.authoring_bytes)
		if additional>0:
			var error := _admission(area_id,additional,"",area_id==active_area and bool(item.hot.get("active",false)))
			if not error.is_empty(): return _fail(error)
		item.authoring = authoring.duplicate(true)
		item.authoring_bytes = admitted.bytes
		item.authoring_sha256 = admitted.sha256
	item.completed_tick = native_tick
	item.mutation_generation = mutation_generation
	item.dirty = _is_dirty(item)
	# A previous capture is no longer an eligible authority for demotion.
	if not item.warm.is_empty() and (int(item.warm.completed_tick) != native_tick or item.dirty):
		item.warm = {}
		item.warm_bytes = 0
	return {"ok":true,"dirty":item.dirty}


func _is_dirty(item: Dictionary) -> bool:
	var record: Dictionary = item.durable
	if item.incarnation != record.incarnation or int(item.mutation_generation) != int(record.mutation_generation) \
		or int(item.completed_tick) != int(record.completed_tick): return true
	if item.authoring_sha256 != record.authoring_sha256: return true
	if not item.warm.is_empty() and item.warm.sha256 != record.native_sha256: return true
	return false


func durable_ack(manifest: Dictionary) -> Dictionary:
	if manifest.get("session_id") != session_id or manifest.get("compatibility") != compatibility \
		or not Clock._integer(manifest.get("revision")) or not manifest.get("areas") is Dictionary \
		or not Store._keys(manifest.areas,Clock.AREA_IDS): return _fail("Durable ACK belongs to another cache session or runtime")
	if int(manifest.revision) < durable_revision:
		_counters.stale_acks += 1
		return _fail("Durable ACK is older than the acknowledged profile revision")
	for id: String in Clock.AREA_IDS:
		var item: Dictionary = _entries[id]
		var record: Dictionary = manifest.areas[id]
		if record.get("incarnation") != item.incarnation or record.get("authored_source_sha256") != item.authored_source_sha256 \
			or record.get("physics_profile_sha256") != item.physics_profile_sha256:
			return _fail("Durable ACK cannot attach to another resident incarnation/source/physics configuration")
		if not Clock._integer(record.get("mutation_generation")) or not Clock._integer(record.get("completed_tick")) \
			or int(record.mutation_generation) > int(item.mutation_generation) or int(record.completed_tick) > int(item.completed_tick) \
			or int(record.mutation_generation) < int(item.durable.mutation_generation) or int(record.completed_tick) < int(item.durable.completed_tick):
			return _fail("Durable ACK is ahead of resident authority or behind an earlier durable ACK")
		if int(manifest.revision) == durable_revision and record != item.durable:
			return _fail("A repeated durable revision changed its area identity")
	for id: String in Clock.AREA_IDS:
		_entries[id].durable = manifest.areas[id].duplicate(true)
		_entries[id].dirty = _is_dirty(_entries[id])
	durable_revision = int(manifest.revision)
	return {"ok":true}


func eviction_candidates(required_bytes: int = 0) -> Array:
	var candidates: Array = []
	var allowed := budget_bytes if enabled else 0
	var needed := maxi(0,_used_bytes()+_reserved_bytes()+required_bytes-allowed)
	if needed == 0: return candidates
	# Once pressure occurs, aim below the hard ceiling so the next small
	# allocation does not immediately promote/evict the same destination again.
	var low_watermark: int = allowed*9/10
	needed = maxi(needed,_used_bytes()+_reserved_bytes()+required_bytes-low_watermark)
	var ids: Array = _entries.keys()
	ids.sort_custom(func(a: String,b: String) -> bool: return int(_entries[a].last_use)<int(_entries[b].last_use))
	for id: String in ids:
		var item: Dictionary = _entries[id]
		if id == active_area or not item.pins.is_empty() or (item.hot.is_empty() and item.warm.is_empty()): continue
		var reserved := false
		for value: Dictionary in _reservations.values():
			if value.area_id == id: reserved = true
		if reserved: continue
		var reclaimable := int(item.native_bytes)+int(item.native_headroom_bytes)+int(item.warm_bytes)+int(item.authoring_bytes)
		candidates.append({"area_id":id,"resident_generation":int(item.resident_generation),
			"handle":int(item.hot.get("handle",0)),"bytes":reclaimable,"dirty":bool(item.dirty),
			"requires_capture":not item.hot.is_empty() and item.warm.is_empty(),"requires_durable_ack":bool(item.dirty)})
		needed -= reclaimable
		if needed <= 0: break
	return candidates


func complete_eviction(area_id: String, expected_generation: int, expected_handle: int, keep_warm: bool) -> Dictionary:
	if not _entries.has(area_id): return _fail("Unknown eviction area")
	var item: Dictionary = _entries[area_id]
	if area_id == active_area or not item.pins.is_empty() or int(item.resident_generation) != expected_generation \
		or int(item.hot.get("handle",0)) != expected_handle:
		return _fail("Eviction refused an active, pinned or stale native owner")
	for value: Dictionary in _reservations.values():
		if value.area_id == area_id: return _fail("Eviction refused an area with an in-flight resource reservation")
	if keep_warm:
		if item.warm.is_empty() or int(item.warm.completed_tick) != int(item.completed_tick) \
			or int(item.warm_mutation_generation) != int(item.mutation_generation):
			return _fail("Hot demotion requires a complete current warm continuation")
	else:
		if item.dirty: return _fail("Dirty resident authority cannot be discarded before durable acknowledgement")
		item.warm = {}
		item.warm_bytes = 0
		item.authoring = {}
		item.authoring_bytes = 0
	item.hot = {}
	item.native_bytes = 0
	item.native_headroom_bytes = 0
	_counters.evictions += 1
	return {"ok":true,"residency":"WARM" if keep_warm else "COLD"}


func record_hit(kind: String) -> void:
	if kind == "HOT": _counters.hot_hits += 1
	elif kind == "WARM": _counters.warm_hits += 1
	elif kind == "COLD": _counters.cold_misses += 1


func status(clock: Dictionary = {}) -> Dictionary:
	var areas := {}
	var counts := {"HOT":0,"WARM":0,"COLD":0}
	var dirty_count := 0
	var native_bytes := 0
	var native_headroom_bytes := 0
	var warm_bytes := 0
	var authoring_bytes := 0
	for id: String in _entries:
		var item: Dictionary = _entries[id]
		var tier := "HOT" if not item.hot.is_empty() else ("WARM" if not item.warm.is_empty() else "COLD")
		counts[tier] += 1
		if item.dirty: dirty_count += 1
		native_bytes += int(item.native_bytes)
		native_headroom_bytes += int(item.native_headroom_bytes)
		warm_bytes += int(item.warm_bytes)
		authoring_bytes += int(item.authoring_bytes)
		areas[id] = {"residency":tier,"active":id == active_area,"dirty":bool(item.dirty),
			"durability":"Changes not yet saved" if item.dirty else "Durably saved",
			"completed_tick":int(item.completed_tick),"durable_tick":int(item.durable.completed_tick),
			"mutation_generation":int(item.mutation_generation),"durable_mutation_generation":int(item.durable.mutation_generation),
			"native_bytes":int(item.native_bytes),"native_headroom_bytes":int(item.native_headroom_bytes),
			"warm_bytes":int(item.warm_bytes),"pins":item.pins.size(),
			"debt_ticks":Clock.debt(clock,id) if not clock.is_empty() else -1,"failure":str(item.failure)}
	return {"enabled":enabled,"budget_bytes":budget_bytes,"used_bytes":_used_bytes(),"reserved_bytes":_reserved_bytes(),
		"essential_publication_reserved_bytes":int(_publication.get("bytes",0)),
		"essential_publication_cap_bytes":MAX_PUBLICATION_HEADROOM_BYTES,
		"total_accounted_and_reserved_bytes":_used_bytes()+_reserved_bytes()+int(_publication.get("bytes",0)),
		"publication_reservation":_publication.duplicate(true),
		"eviction_low_watermark_bytes":budget_bytes*9/10,
		"over_budget":_used_bytes()+_reserved_bytes() > (budget_bytes if enabled else 0),
		"native_bytes":native_bytes,"native_headroom_bytes":native_headroom_bytes,"warm_bytes":warm_bytes,"authoring_bytes":authoring_bytes,
		"hot_count":int(counts.HOT),"warm_count":int(counts.WARM),"cold_count":int(counts.COLD),
		"dirty_count":dirty_count,"pending_reservations":_reservations.size(),"durable_revision":durable_revision,
		"areas":areas,"counters":_counters.duplicate(true),
		"memory_contract":"Retained cache budget: native allocation estimate + growth headroom + warm/authoring + speculative reservations. Essential capture/encoding/readback has separate bounded temporary headroom. Process RSS/allocator/renderer overhead measured separately"}
