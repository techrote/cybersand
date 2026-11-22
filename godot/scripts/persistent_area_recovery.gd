extends RefCounted
## Explicit recovery planning after a fatal active World failure. This never
## resets, unbinds, replaces, or captures the failed owner. Healthy inactive
## capsules remain native authority; Store performs complete byte/source checks
## and publication. A plan is not a durable acknowledgement or Save-all result.

const Store = preload("res://scripts/persistent_area_store.gd")
const Clock = preload("res://scripts/persistent_area_clock.gd")


static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"error":reason}


static func plan(manifest: Dictionary, resident_clock: Dictionary, failed_area: String,
		healthy_updates: Dictionary, operation_id: String) -> Dictionary:
	if not Store._keys(manifest,["version","profile_id","session_id","compatibility","revision",
			"operation_nonce","active_area","clock","areas"]) \
		or manifest.get("version")!=Store.VERSION or not Store._hex(manifest.get("session_id"),32) \
		or not Store._hex(manifest.get("operation_nonce"),32) or not Store._hex(operation_id,32) \
		or operation_id==manifest.operation_nonce or not Clock._integer(manifest.get("revision")) \
		or int(manifest.revision)<1 or not manifest.get("areas") is Dictionary \
		or not Store._keys(manifest.areas,Clock.AREA_IDS) or not failed_area in Clock.AREA_IDS \
		or not manifest.get("active_area") in Clock.AREA_IDS \
		or not Store._pure(manifest,[Store.MAX_VALUE_ITEMS]):
		return _fail("Recovery requires the exact acknowledged session and a fresh operation identity")
	if not Clock.validate(manifest.get("clock")).is_empty() or not Clock.validate(resident_clock).is_empty():
		return _fail("Recovery requires valid durable and resident game-time frontiers")
	if int(resident_clock.game_ticks)<int(manifest.clock.game_ticks):
		return _fail("Recovery cannot move acknowledged global game time backwards")
	for id: String in Clock.AREA_IDS:
		var prior: Variant=manifest.areas[id]
		if not prior is Dictionary or not Store._keys(prior,Store.RECORD_KEYS) \
			or prior.area_id!=id or not Store._hex(prior.incarnation,32):
			return _fail("Recovery found a malformed acknowledged area identity")
		for field: String in ["generation","mutation_generation","completed_tick"]:
			if not Clock._integer(prior[field]): return _fail("Recovery found an invalid durable generation or native tick")
		for field: String in ["native_sha256","authoring_sha256","authored_source_sha256","physics_profile_sha256","policy_sha256"]:
			if not Store._hex(prior[field],64): return _fail("Recovery found an invalid durable source/state identity")
		var before: Dictionary=manifest.clock.areas[id]
		var current: Dictionary=resident_clock.areas[id]
		if int(prior.completed_tick)!=int(before.native_ticks) \
			or int(current.native_ticks)<int(before.native_ticks) \
			or int(current.accounted_ticks)<int(before.accounted_ticks) \
			or int(current.origin_game_tick)!=int(before.origin_game_tick):
			return _fail("Recovery cannot rebase an area or rewind acknowledged native/accounted time")
	for id: Variant in healthy_updates:
		if not id is String or not id in Clock.AREA_IDS or id==failed_area:
			return _fail("Recovery may publish only explicitly captured healthy inactive areas")
	if healthy_updates.is_empty(): return _fail("No healthy inactive area capture is available to preserve")
	var recovery_clock: Dictionary=Clock.canonical(manifest.clock)
	var captured_native_delta:=0
	var saved_areas: Array[String]=[]
	for id: String in Clock.AREA_IDS:
		if not healthy_updates.has(id): continue
		var update: Variant=healthy_updates[id]
		if not update is Dictionary or not Store._keys(update,["capture","authoring","mutation_generation","incarnation"]) \
			or not update.capture is Dictionary or not Store._keys(update.capture,Store.CAPTURE_KEYS) \
			or not update.authoring is Dictionary or not Clock._integer(update.mutation_generation):
			return _fail("Recovery capture has an unsupported native/authoring update shape")
		var capsule: Dictionary=update.capture
		var prior: Dictionary=manifest.areas[id]
		if update.incarnation!=prior.incarnation or int(update.mutation_generation)<int(prior.mutation_generation) \
			or not Clock._integer(capsule.completed_tick) \
			or int(capsule.completed_tick)!=int(resident_clock.areas[id].native_ticks) \
			or capsule.authored_source_sha256!=prior.authored_source_sha256 \
			or capsule.physics_profile_sha256!=prior.physics_profile_sha256 \
			or capsule.policy_sha256!=prior.policy_sha256:
			return _fail("Recovery capture differs from the exact healthy incarnation/source/native frontier")
		if not capsule.bytes is PackedByteArray or capsule.bytes.is_empty() \
			or capsule.bytes.size()>Store.MAX_NATIVE_BYTES or not Store._hex(capsule.sha256,64):
			return _fail("Recovery capture has an invalid bounded native payload")
		var metadata: Dictionary=capsule.duplicate()
		metadata.erase("bytes")
		if not Store._pure(metadata,[Store.MAX_VALUE_ITEMS]) or not Store._pure(update.authoring,[Store.MAX_VALUE_ITEMS]):
			return _fail("Recovery accepts pure immutable native metadata and authoring values only")
		# Store checks the complete native hash, authoring definition and mutation
		# fence again before publishing. The planner never credits unverified time.
		captured_native_delta+=int(capsule.completed_tick)-int(prior.completed_tick)
		recovery_clock.areas[id]=resident_clock.areas[id].duplicate(true)
		saved_areas.append(id)
	# Native deltas include catch-up; they are NOT newly elapsed gameplay time.
	# This is an upper bound on how much ALREADY OBSERVED RAM G may be retained
	# in an explicit recovery snapshot. It never increases the observed G.
	var durable_game_tick:=int(manifest.clock.game_ticks)
	var recovered_game_tick:=mini(int(resident_clock.game_ticks),durable_game_tick+captured_native_delta)
	var minimum_game_tick:=durable_game_tick
	for id: String in Clock.AREA_IDS:
		minimum_game_tick=maxi(minimum_game_tick,int(recovery_clock.areas[id].accounted_ticks))
	if recovered_game_tick<minimum_game_tick:
		return _fail("Recovery cannot reconcile captured accounted frontiers with backed global time")
	recovery_clock.game_ticks=recovered_game_tick
	if not Clock.validate(recovery_clock).is_empty(): return _fail("Recovery produced an inconsistent game-time frontier")
	var summary: Dictionary={"schema":1,"operation_id":operation_id,"session_id":manifest.session_id,
		"durable_revision":int(manifest.revision),"failed_area":failed_area,"saved_areas":saved_areas,
		"failed_area_durable_native_tick":int(manifest.areas[failed_area].completed_tick),
		"durable_game_ticks_before":durable_game_tick,"observed_resident_game_ticks":int(resident_clock.game_ticks),
		"recovered_game_ticks":recovered_game_tick,"omitted_ram_game_ticks":int(resident_clock.game_ticks)-recovered_game_tick,
		"captured_native_delta_bound":captured_native_delta,"ordinary_save_all":false,
		"failed_world_reset":false,"failed_world_discarded":false,
		"clock_policy":"explicit-recovery-retains-backed-observed-frontier-v1"}
	return {"ok":true,"state":{"active_area":failed_area,"clock":recovery_clock},
		"updates":healthy_updates.duplicate(true),"summary":summary}
