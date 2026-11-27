extends RefCounted
## GEN-006 game time is completed native work, never a wall-clock timestamp.
## Catch-up pays an existing interval once. Ahead first pays debt and then adds
## only completed future ticks to the global clock. Caller publishes this clock
## and the matching authoritative native checkpoint in one profile transaction.

const VERSION := 1
const AREA_IDS := ["a", "b", "c"]
const TICKS_PER_SECOND := 60
const MAX_INTEGER := 9007199254740991
const MAX_SLICE_TICKS := 600
const MAX_AHEAD_TICKS := 36000


static func fresh() -> Dictionary:
	var areas := {}
	for id: String in AREA_IDS:
		areas[id] = {"accounted_ticks":0, "native_ticks":0, "origin_game_tick":0}
	return {"version":VERSION, "game_ticks":0, "areas":areas}


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) >= 0.0 and float(value) <= float(MAX_INTEGER) and float(value) == floor(float(value))


static func _keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key: Variant in expected:
		if not value.has(key): return false
	return true


static func validate(value: Variant) -> String:
	if not value is Dictionary or not _keys(value, ["version", "game_ticks", "areas"]):
		return "Persistent game clock has an unsupported shape"
	if not _integer(value.version) or int(value.version) != VERSION or not _integer(value.game_ticks):
		return "Persistent game clock has an unsupported version or time"
	if not value.areas is Dictionary or not _keys(value.areas, AREA_IDS):
		return "Persistent game clock must identify exactly areas A, B and C"
	for id: String in AREA_IDS:
		var area: Variant = value.areas[id]
		if not area is Dictionary or not _keys(area, ["accounted_ticks", "native_ticks", "origin_game_tick"]):
			return "Persistent area clock has an unsupported shape: " + id
		for field: String in ["accounted_ticks", "native_ticks", "origin_game_tick"]:
			if not _integer(area[field]): return "Persistent area clock contains an invalid tick: " + id
		if int(area.accounted_ticks) > int(value.game_ticks) or int(area.origin_game_tick) > int(area.accounted_ticks) \
			or int(area.accounted_ticks) - int(area.origin_game_tick) != int(area.native_ticks):
			return "Persistent area native and accounted clocks disagree: " + id
	return ""


static func canonical(clock: Dictionary) -> Dictionary:
	if not validate(clock).is_empty(): return {}
	var result := fresh()
	result.game_ticks = int(clock.game_ticks)
	for id: String in AREA_IDS:
		for field: String in ["accounted_ticks", "native_ticks", "origin_game_tick"]:
			result.areas[id][field] = int(clock.areas[id][field])
	return result


static func identity(clock: Dictionary) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(JSON.stringify(canonical(clock)).to_utf8_buffer())
	return hash.finish().hex_encode()


static func debt(clock: Dictionary, area_id: String) -> int:
	if not validate(clock).is_empty() or not area_id in AREA_IDS: return -1
	return int(clock.game_ticks) - int(clock.areas[area_id].accounted_ticks)


static func active(clock: Dictionary, area_id: String, observed_native_tick: int) -> Dictionary:
	var error := validate(clock)
	if not error.is_empty(): return {"ok":false, "error":error}
	if not area_id in AREA_IDS or not _integer(observed_native_tick):
		return {"ok":false, "error":"Active tick observation has an invalid area or tick"}
	var previous: int = int(clock.areas[area_id].native_ticks)
	if observed_native_tick < previous:
		return {"ok":false, "error":"Native time moved backwards without an admitted area reset"}
	var completed: int = observed_native_tick - previous
	if int(clock.game_ticks) > MAX_INTEGER - completed:
		return {"ok":false, "error":"Persistent game-time capacity exhausted"}
	var result := canonical(clock)
	result.game_ticks += completed
	result.areas[area_id].accounted_ticks += completed
	result.areas[area_id].native_ticks = observed_native_tick
	return {"ok":true, "clock":result, "completed_ticks":completed, "game_advanced_ticks":completed}


static func plan(clock: Dictionary, area_id: String, mode: String, requested_future_ticks: int, max_work_ticks: int) -> Dictionary:
	var error := validate(clock)
	if not error.is_empty(): return {"ok":false, "error":error}
	if not area_id in AREA_IDS or not mode in ["catch_up", "ahead"]:
		return {"ok":false, "error":"Unknown persistent area or advancement mode"}
	if requested_future_ticks < 0 or requested_future_ticks > MAX_AHEAD_TICKS \
		or max_work_ticks < 1 or max_work_ticks > MAX_SLICE_TICKS \
		or (mode == "catch_up" and requested_future_ticks != 0):
		return {"ok":false, "error":"Persistent advancement exceeds the bounded request or slice capacity"}
	var owed := debt(clock, area_id)
	var paid: int = mini(owed, max_work_ticks)
	var future: int = mini(requested_future_ticks, max_work_ticks - paid) if mode == "ahead" else 0
	future = mini(future, MAX_INTEGER - int(clock.game_ticks))
	var result := {"version":VERSION, "area_id":area_id, "mode":mode, "source_clock_sha256":identity(clock),
		"source_native_tick":int(clock.areas[area_id].native_ticks), "source_debt_ticks":owed,
		"requested_future_ticks":requested_future_ticks, "max_work_ticks":max_work_ticks,
		"work_ticks":paid + future, "debt_work_ticks":paid, "future_work_ticks":future}
	return {"ok":true, "plan":result}


static func complete(clock: Dictionary, proposal: Dictionary, actual_ticks: int) -> Dictionary:
	var error := validate(clock)
	if not error.is_empty(): return {"ok":false, "error":error}
	if not _keys(proposal, ["version", "area_id", "mode", "source_clock_sha256", "source_native_tick",
		"source_debt_ticks", "requested_future_ticks", "max_work_ticks", "work_ticks", "debt_work_ticks", "future_work_ticks"]):
		return {"ok":false, "error":"Persistent completion has an invalid plan"}
	for key: String in ["version", "source_native_tick", "source_debt_ticks", "requested_future_ticks", "max_work_ticks", "work_ticks", "debt_work_ticks", "future_work_ticks"]:
		if not _integer(proposal[key]): return {"ok":false, "error":"Persistent completion has an invalid numeric plan"}
	if not proposal.area_id is String or not proposal.mode is String or not proposal.source_clock_sha256 is String:
		return {"ok":false, "error":"Persistent completion has an invalid source identity"}
	var rebuilt := plan(clock, proposal.area_id, proposal.mode, int(proposal.requested_future_ticks), int(proposal.max_work_ticks))
	if not rebuilt.get("ok", false) or rebuilt.plan != proposal:
		return {"ok":false, "error":"Persistent completion is stale or its work plan changed"}
	if actual_ticks < 0 or actual_ticks > int(proposal.work_ticks):
		return {"ok":false, "error":"Native completion exceeds the admitted work slice"}
	var area_id: String = proposal.area_id
	var paid: int = mini(actual_ticks, int(proposal.debt_work_ticks))
	var future: int = actual_ticks - paid
	var result := canonical(clock)
	result.game_ticks += future
	result.areas[area_id].accounted_ticks += actual_ticks
	result.areas[area_id].native_ticks += actual_ticks
	return {"ok":true, "clock":result, "completed_ticks":actual_ticks, "paid_debt_ticks":paid,
		"game_advanced_ticks":future, "remaining_future_ticks":int(proposal.requested_future_ticks) - future,
		"debt_ticks":debt(result, area_id)}


static func rebase(clock: Dictionary, area_id: String) -> Dictionary:
	## Only an explicit admitted authored-start replacement may reset native time.
	## Store requires a new incarnation and forbids mutation/generation rollback.
	var error := validate(clock)
	if not error.is_empty() or not area_id in AREA_IDS:
		return {"ok":false, "error":error if not error.is_empty() else "Unknown persistent area"}
	var result := canonical(clock)
	result.areas[area_id] = {"accounted_ticks":int(clock.game_ticks), "native_ticks":0, "origin_game_tick":int(clock.game_ticks)}
	return {"ok":true, "clock":result}


static func plan_background(clock: Dictionary, area_id: String, max_work_ticks: int, operation_id: String) -> Dictionary:
	## Background work owns a fixed interval of one inactive area. Other areas
	## may keep advancing G while this interval executes; that is not staleness.
	var error := validate(clock)
	if not error.is_empty(): return {"ok":false, "error":error}
	if not area_id in AREA_IDS or max_work_ticks < 1 or max_work_ticks > MAX_SLICE_TICKS \
		or operation_id.length() != 32:
		return {"ok":false, "error":"Background catch-up has an invalid area, operation or work bound"}
	for character: String in operation_id:
		if not character in "0123456789abcdef": return {"ok":false, "error":"Background catch-up operation identity is malformed"}
	var source: Dictionary = canonical(clock).areas[area_id]
	return {"ok":true, "plan":{"version":VERSION, "protocol":"area-debt-interval-v1", "area_id":area_id,
		"operation_id":operation_id, "source_game_tick":int(clock.game_ticks), "source_area_clock":source,
		"max_work_ticks":max_work_ticks, "work_ticks":mini(debt(clock,area_id),max_work_ticks)}}


static func complete_background(clock: Dictionary, proposal: Dictionary, actual_ticks: int) -> Dictionary:
	var error := validate(clock)
	if not error.is_empty(): return {"ok":false, "error":error}
	if not _keys(proposal,["version","protocol","area_id","operation_id","source_game_tick","source_area_clock","max_work_ticks","work_ticks"]) \
		or proposal.get("protocol") != "area-debt-interval-v1" or proposal.get("version") != VERSION \
		or not proposal.get("area_id") is String or not proposal.area_id in AREA_IDS \
		or not proposal.get("operation_id") is String or proposal.operation_id.length() != 32 \
		or not proposal.get("source_area_clock") is Dictionary:
		return {"ok":false,"error":"Background completion has an unsupported interval identity"}
	for character: String in proposal.operation_id:
		if not character in "0123456789abcdef": return {"ok":false,"error":"Background completion operation identity is malformed"}
	for key: String in ["source_game_tick","max_work_ticks","work_ticks"]:
		if not _integer(proposal[key]): return {"ok":false,"error":"Background completion contains an invalid work bound"}
	var source: Dictionary = proposal.source_area_clock
	if not _keys(source,["accounted_ticks","native_ticks","origin_game_tick"]):
		return {"ok":false,"error":"Background completion area clock is malformed"}
	for key: String in ["accounted_ticks","native_ticks","origin_game_tick"]:
		if not _integer(source[key]): return {"ok":false,"error":"Background completion area tick is invalid"}
	if int(source.accounted_ticks) > int(proposal.source_game_tick) \
		or int(source.accounted_ticks) - int(source.origin_game_tick) != int(source.native_ticks) \
		or int(proposal.max_work_ticks) < 1 or int(proposal.max_work_ticks) > MAX_SLICE_TICKS \
		or int(proposal.work_ticks) != mini(int(proposal.source_game_tick)-int(source.accounted_ticks),int(proposal.max_work_ticks)) \
		or actual_ticks < 0 or actual_ticks > int(proposal.work_ticks):
		return {"ok":false,"error":"Background completion exceeds its admitted debt interval"}
	var area_id: String = proposal.area_id
	if clock.areas[area_id] != source or int(clock.game_ticks) < int(proposal.source_game_tick):
		return {"ok":false,"error":"Background completion is stale for this area's native/accounted frontier"}
	var result := canonical(clock)
	result.areas[area_id].native_ticks += actual_ticks
	result.areas[area_id].accounted_ticks += actual_ticks
	return {"ok":true,"clock":result,"completed_ticks":actual_ticks,"paid_debt_ticks":actual_ticks,
		"game_advanced_ticks":0,"debt_ticks":debt(result,area_id),"operation_id":proposal.operation_id}
