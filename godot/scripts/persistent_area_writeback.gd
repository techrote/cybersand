extends RefCounted
## One immutable save batch on one private I/O thread. While it runs, requests
## coalesce into one metadata-only request for a *fresh* capture, not more copies
## of full Worlds. The caller serializes every other access to the same Store.

const Store = preload("res://scripts/persistent_area_store.gd")
const Clock = preload("res://scripts/persistent_area_clock.gd")
const MAX_BATCH_BYTES := 3 * (Store.MAX_NATIVE_BYTES + Store.MAX_METADATA_BYTES)

var _thread: Thread
var _store: RefCounted
var _batch: Dictionary = {}
var _queued: Dictionary = {}
var _last_result: Dictionary = {}
var _sequence := 0
var _metrics := {"started":0,"completed":0,"failed":0,"coalesced":0,"cancelled_requests":0,
	"peak_batch_bytes":0,"metadata_encodes":0,"completed_batches":[]}


func busy() -> bool:
	return _thread != null


func request(priority: int = 0, reason: String = "background") -> Dictionary:
	if priority < 0 or priority > 3 or reason.is_empty() or reason.length() > 128:
		return {"ok":false,"error":"Write-behind request priority or reason is invalid"}
	_sequence += 1
	if not _queued.is_empty(): _metrics.coalesced += 1
	_queued = {"request_id":_sequence,"priority":maxi(priority,int(_queued.get("priority",0))),"reason":reason}
	return {"ok":true,"request":_queued.duplicate(true)}


func take_request() -> Dictionary:
	if busy(): return {}
	var result := _queued.duplicate(true)
	_queued = {}
	return result


func cancel_request(request_id: int) -> bool:
	if _queued.is_empty() or int(_queued.request_id) != request_id: return false
	_queued = {}
	_metrics.cancelled_requests += 1
	return true


func start(store: RefCounted, next_state: Dictionary, updates: Dictionary, expected_revision: int,
		immutable_fence: Dictionary = {}) -> Dictionary:
	if busy(): return {"ok":false,"error":"One immutable write-behind batch is already in flight"}
	var build_fence := immutable_fence.is_empty()
	if build_fence: immutable_fence = {"snapshot_id":Store.new_nonce()}
	if store == null or expected_revision < 1 or updates.size() > 3 \
		or not Store._keys(next_state,["active_area","clock"]) or not Clock.validate(next_state.clock).is_empty() \
		or not next_state.active_area is String or not next_state.active_area in Clock.AREA_IDS \
		or not Store.metadata_size(immutable_fence,16384,1024).get("ok",false) \
		or not Store._hex(immutable_fence.get("snapshot_id"),32):
		return {"ok":false,"error":"Write-behind batch has an invalid store, revision, clock or immutable fence"}
	var started := Time.get_ticks_usec()
	# Deep-duplicated containers isolate GDScript edits. Packed arrays are copied
	# on mutation by Godot; no native/scene/Rapier object enters this value batch.
	# Bounded metadata traversal admits a conservative aggregate byte
	# bound before any full encoding. The subsequent bounded metadata encoding
	# measures exact admission size and belongs to detach_us. Complete checkpoint
	# encoding, hashing, semantic validation
	# and filesystem publication run on the I/O thread below. Native capture
	# itself remains a separate measured exclusive-owner boundary.
	var bytes := 0
	for id: Variant in updates:
		if not id is String or not id in Clock.AREA_IDS or not updates[id] is Dictionary \
			or not Store._keys(updates[id],["capture","authoring","mutation_generation","incarnation"]) \
			or not updates[id].get("capture") is Dictionary or not updates[id].capture.get("bytes") is PackedByteArray \
			or not Store._keys(updates[id].capture,Store.CAPTURE_KEYS) \
			or updates[id].capture.bytes.is_empty() or updates[id].capture.bytes.size()>Store.MAX_NATIVE_BYTES \
			or not updates[id].get("authoring") is Dictionary \
			or not Store._hex(updates[id].get("incarnation"),32) or not Clock._integer(updates[id].get("mutation_generation")):
			return {"ok":false,"error":"Write-behind received an unsupported capture update"}
		var metadata: Dictionary = updates[id].capture.duplicate()
		metadata.erase("bytes")
		if not Store.metadata_size([metadata,updates[id].authoring],Store.MAX_METADATA_BYTES-4096).get("ok",false):
			return {"ok":false,"error":"Live objects or oversized aggregate metadata cannot enter the immutable I/O batch"}
		_metrics.metadata_encodes += 2
		var metadata_bytes := var_to_bytes(metadata).size()
		var authoring_bytes := var_to_bytes(updates[id].authoring).size()
		if metadata_bytes+authoring_bytes+4096>Store.MAX_METADATA_BYTES:
			return {"ok":false,"error":"Write-behind area metadata exceeds its bounded encoding capacity"}
		bytes += updates[id].capture.bytes.size()+metadata_bytes+authoring_bytes+4096
	if bytes > MAX_BATCH_BYTES: return {"ok":false,"error":"Write-behind batch exceeds its bounded immutable-buffer capacity"}
	_batch = {"next_state":next_state.duplicate(true),"updates":updates.duplicate(true),"expected_revision":expected_revision,
		"fence":immutable_fence.duplicate(true),"build_fence":build_fence,
		"bytes":bytes,"started_usec":started,"detach_us":Time.get_ticks_usec()-started}
	_store = store
	_thread = Thread.new()
	var error := _thread.start(_run)
	if error != OK:
		_thread = null
		_store = null
		_batch = {}
		return {"ok":false,"error":"Could not start the write-behind I/O owner: " + str(error)}
	_metrics.started += 1
	_metrics.peak_batch_bytes = maxi(int(_metrics.peak_batch_bytes),bytes)
	return {"ok":true,"snapshot_id":immutable_fence.snapshot_id,"batch_bytes":bytes,"detach_us":_batch.detach_us}


func _run() -> Dictionary:
	var started := Time.get_ticks_usec()
	var io_before: Dictionary = _store.io_telemetry()
	var fence: Dictionary = _batch.fence
	if _batch.build_fence:
		var manifest: Dictionary = _store.current_manifest()
		if int(manifest.get("revision",-1)) != int(_batch.expected_revision):
			return {"ok":false,"error":"Background capture batch refers to a superseded durable revision"}
		var built := Store.snapshot_fence(manifest,_batch.next_state,_batch.updates,str(fence.snapshot_id))
		if not built.get("ok",false): return built
		fence = built.fence
	var result: Dictionary = _store.publish_snapshot(_batch.next_state,_batch.updates,int(_batch.expected_revision),
		str(fence.snapshot_id),fence)
	result["publication_us"] = Time.get_ticks_usec()-started
	result["io_before"] = io_before
	result["io_after"] = _store.io_telemetry()
	return result


func poll() -> Dictionary:
	if _thread == null: return {"status":"idle"}
	if _thread.is_alive(): return {"status":"running","snapshot_id":_batch.fence.snapshot_id,"batch_bytes":int(_batch.bytes)}
	var value: Variant = _thread.wait_to_finish()
	_thread = null
	var result: Dictionary
	if value is Dictionary:
		result = value
	else:
		result = {"ok":false,"publication_uncertain":true,"quarantined":true,
			"error":"Background publication returned no valid durable acknowledgement"}
	var observation := {"snapshot_id":_batch.fence.snapshot_id,"batch_bytes":int(_batch.bytes),
		"elapsed_us":Time.get_ticks_usec()-int(_batch.started_usec),"detach_us":int(_batch.detach_us),
		"publication_us":int(result.get("publication_us",0)),"ok":bool(result.get("ok",false))}
	_metrics.completed_batches.append(observation)
	if _metrics.completed_batches.size() > 256: _metrics.completed_batches.pop_front()
	if result.get("ok",false): _metrics.completed += 1
	else: _metrics.failed += 1
	_last_result = result.duplicate(true)
	_batch = {}
	_store = null
	return {"status":"complete","result":result,"observation":observation}


func status() -> Dictionary:
	return {"busy":busy(),"pending_requests":0 if _queued.is_empty() else 1,
		"batch_bytes":int(_batch.get("bytes",0)),"snapshot_id":_batch.get("fence",{}).get("snapshot_id",""),
		"request":_queued.duplicate(true),"metrics":_metrics.duplicate(true),
		"last_error":str(_last_result.get("error",""))}
