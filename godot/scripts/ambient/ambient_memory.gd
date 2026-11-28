extends RefCounted

# AMBIENT-002 private, bounded memory of COPIED observations. This object has no
# World/scene/physics reference. It is never serialized in an authored profile.
const VERSION := "ambient-memory/v2"
const MAX_MATERIALS := 8
const MAX_DIRECTIONS := 8

var _config: Dictionary = {}
var _visits: Dictionary = {}
var _interests: Dictionary = {}
var _obstructions: Dictionary = {}
var _identity: Dictionary = {}
var _last_cell: String = ""
var _last_position := Vector2.ZERO
var _has_position: bool = false
var _stalled: float = 0.0
var _last_failure_time: float = -1000.0
var _visit_admissions: int = 0
var _reentries: int = 0
var _failures: int = 0
var _evictions: int = 0
var _forgotten: int = 0
var _reason: String = "unconfigured"


func configure(config: Dictionary) -> void:
	_config = config.duplicate(true)
	reset("profile applied")


func reset(reason: String) -> void:
	_visits.clear()
	_interests.clear()
	_obstructions.clear()
	_identity.clear()
	_last_cell = ""
	_has_position = false
	_stalled = 0.0
	_last_failure_time = -1000.0
	_visit_admissions = 0
	_reentries = 0
	_failures = 0
	_evictions = 0
	_forgotten = 0
	_reason = reason


static func cell_key(position: Vector2, cell_size: float) -> String:
	return "%d:%d" % [int(floorf(position.x / cell_size)),int(floorf(position.y / cell_size))]


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _trim(table: Dictionary, capacity: int) -> void:
	# At most eight new material records, one visit and one failure arrive per
	# admitted decision. Eviction is deterministic, including timestamp ties.
	while table.size() > capacity:
		var selected: String = ""
		var oldest: float = INF
		for key: String in table:
			var stamp: float = float(table[key].get("last_seen",0.0))
			if stamp < oldest or (stamp == oldest and (selected.is_empty() or key < selected)):
				selected = key
				oldest = stamp
		table.erase(selected)
		_evictions += 1


func _expire(table: Dictionary, now: float, lifetime: float) -> void:
	var expired: Array[String] = []
	for key: String in table:
		if now - float(table[key].get("last_seen",now)) >= lifetime:
			expired.append(key)
	for key: String in expired:
		table.erase(key)
		_forgotten += 1


func _remember_visit(position: Vector2, now: float, delta: float) -> void:
	var size: float = float(_config.cell_size)
	var key: String = cell_key(position,size)
	if not _visits.has(key):
		_visits[key] = {"key":key,"position":Vector2((floorf(position.x / size) + 0.5) * size,
			(floorf(position.y / size) + 0.5) * size),"first_seen":now,"last_seen":now,
			"entries":1,"dwell_seconds":0.0}
		_visit_admissions += 1
	elif key != _last_cell:
		_visits[key].entries = int(_visits[key].entries) + 1
		_reentries += 1
	_visits[key].last_seen = now
	_visits[key].dwell_seconds = float(_visits[key].dwell_seconds) + delta
	_last_cell = key
	_trim(_visits,int(_config.capacity))


func _remember_interests(observation: Dictionary, now: float, delta: float) -> void:
	var materials: Dictionary = observation.get("materials",{})
	if not bool(materials.get("available",false)): return
	var targets: Variant = materials.get("targets",{})
	if not targets is Dictionary: return
	var count: int = 0
	for id: Variant in targets:
		if count >= MAX_MATERIALS: break
		count += 1
		var target: Variant = targets[id]
		if not target is Dictionary or not bool(target.get("available",false)) or not bool(target.get("present",false)): continue
		var material_id: int = -1
		if id is String and (id as String).is_valid_int(): material_id = int(id)
		elif _finite_number(id) and float(id) == floorf(float(id)): material_id = int(id)
		if material_id < 1 or material_id > 131 or material_id == 10: continue
		var point: Variant = target.get("nearest")
		var distance: Variant = target.get("distance")
		var radius: Variant = target.get("radius_cells")
		if not point is Vector2 or not point.is_finite() or not _finite_number(distance) \
			or not _finite_number(radius) or float(distance) < 0.0 or float(radius) <= 0.0 \
			or float(radius) > 96.0 or float(distance) > float(radius): continue
		if absf((observation.position as Vector2).distance_to(point) - float(distance)) > 0.01: continue
		var key: String = str(material_id) + ":" + cell_key(point,float(_config.cell_size))
		if not _interests.has(key):
			_interests[key] = {"key":key,"material_id":material_id,"position":point,
				"first_seen":now,"last_seen":now,"exposure_seconds":0.0,"visits":0,
				"last_visit":-1000.0,"near":false,"revision":int(target.get("revision",-1))}
		var entry: Dictionary = _interests[key]
		entry.position = point
		entry.last_seen = now
		entry.exposure_seconds = minf(600.0,float(entry.exposure_seconds) + delta)
		entry.revision = int(target.get("revision",-1))
		var near: bool = (observation.position as Vector2).distance_to(point) <= 12.0
		if near and not bool(entry.near):
			entry.visits = int(entry.visits) + 1
			entry.last_visit = now
		entry.near = near
	_trim(_interests,int(_config.interest_capacity))


static func _near_contact(observation: Dictionary, requested: Vector2) -> bool:
	var navigation: Dictionary = observation.get("navigation",{})
	if bool(navigation.get("available",false)):
		var directions: Variant = navigation.get("directions",[])
		if directions is Array:
			for index: int in mini(MAX_DIRECTIONS,directions.size()):
				var ray: Variant = directions[index]
				if not ray is Dictionary or not bool(ray.get("available",false)) or not bool(ray.get("hit",false)): continue
				var direction: Variant = ray.get("direction")
				var clearance: Variant = ray.get("clearance_cells")
				var maximum: Variant = ray.get("maximum_distance_cells")
				if direction is Vector2 and direction.is_finite() and _finite_number(clearance) and _finite_number(maximum) \
					and float(clearance) >= 0.0 and float(clearance) < float(maximum) \
					and float(clearance) <= 10.0 and direction.normalized().dot(requested) > 0.9:
					return true
	if absf(requested.x) < 0.5: return false
	var obstacles: Dictionary = observation.get("obstacles",{})
	if not bool(obstacles.get("available",false)): return false
	var distance: Variant = obstacles.get("right_distance" if requested.x > 0.0 else "left_distance")
	var maximum: Variant = obstacles.get("maximum_distance_cells",30.0)
	return _finite_number(distance) and _finite_number(maximum) and float(distance) >= 0.0 \
		and float(distance) < float(maximum) and float(distance) <= 10.0


func _remember_obstruction(observation: Dictionary, now: float, delta: float, last_intent: Dictionary) -> void:
	var position: Vector2 = observation.position
	var direction: Variant = last_intent.get("direction",Vector2.ZERO)
	var wants: bool = direction is Vector2 and direction.is_finite() and direction.length_squared() > 0.01 \
		and float(last_intent.get("pace",0.0)) > 0.05
	if not _has_position or delta <= 0.0 or not wants:
		_stalled = 0.0
	else:
		var requested: Vector2 = direction.normalized()
		var progress: float = maxf(0.0,(position - _last_position).dot(requested)) / delta
		if progress < 1.0 and _near_contact(observation,requested):
			_stalled += delta
		else:
			_stalled = 0.0
		if _stalled >= 0.8 and now - _last_failure_time >= 1.0:
			var sector: int = posmod(int(roundf(requested.angle() / (PI / 4.0))),8)
			var key: String = cell_key(position,float(_config.cell_size)) + ":" + str(sector)
			if not _obstructions.has(key):
				_obstructions[key] = {"key":key,"position":position,"direction":requested,
					"last_seen":now,"attempts":0}
			_obstructions[key].attempts = mini(255,int(_obstructions[key].attempts) + 1)
			_obstructions[key].last_seen = now
			_obstructions[key].position = position
			_failures += 1
			_last_failure_time = now
			_stalled = 0.0
			_trim(_obstructions,int(_config.obstruction_capacity))
	_last_position = position
	_has_position = true


func advance(observation: Dictionary, now: float, delta: float, last_intent: Dictionary) -> void:
	if _config.is_empty() or not bool(_config.get("enabled",false)):
		_reason = "spatial memory disabled"
		return
	var generation: Variant = observation.get("world_generation")
	if not _finite_number(generation) or float(generation) != floorf(float(generation)) or int(generation) < 0:
		_reason = "World generation unavailable; memory learning and use suspended"
		_has_position = false
		_stalled = 0.0
		return
	var identity: Dictionary = {"run_id":observation.run_id,"epoch":observation.epoch,
		"actor_id":observation.actor_id,"world_generation":int(generation)}
	if not _identity.is_empty() and identity != _identity: reset("World identity changed")
	_identity = identity
	_reason = ""
	var lifetime: float = float(_config.lifetime_seconds)
	_expire(_visits,now,lifetime)
	_expire(_interests,now,lifetime)
	_expire(_obstructions,now,minf(30.0,lifetime))
	# A missed-decision interval does not establish continuous dwelling/contact.
	var continuous: float = delta if delta <= 0.25 else 0.0
	_remember_visit(observation.position,now,continuous)
	_remember_interests(observation,now,continuous)
	_remember_obstruction(observation,now,continuous,last_intent)


func snapshot() -> Dictionary:
	return {"version":VERSION,"enabled":bool(_config.get("enabled",false)),
		"available":_reason.is_empty(),"reason":_reason,"identity":_identity.duplicate(true),
		"cell_size":float(_config.get("cell_size",24.0)),
		"lifetime_seconds":float(_config.get("lifetime_seconds",90.0)),
		"visited":_visits.values().duplicate(true),"interests":_interests.values().duplicate(true),
		"obstructions":_obstructions.values().duplicate(true),
		"visit_admissions":_visit_admissions,"reentries":_reentries,"failure_events":_failures,
		"evictions":_evictions,"forgotten":_forgotten,
		"capacity":int(_config.get("capacity",0)),"interest_capacity":int(_config.get("interest_capacity",0)),
		"obstruction_capacity":int(_config.get("obstruction_capacity",0))}
