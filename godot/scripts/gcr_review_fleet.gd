extends RefCounted

# Explicit room-only authoring candidates, not production actor calibration.
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Authoring = preload("res://scripts/gcr_flyer_authoring.gd")
const DEFAULT_MANIFEST: String="res://authoring/flyers/manifest.json"
# Godot 4.7 can retain static-variable scripts after a stepped Rapier session;
# @static_unload also faults on that exercised teardown path. Keep this facade
# stateless. The main loop owns only bounded authored values for its lifetime,
# so closing one session cannot invalidate another session's registry. Disposal
# belongs to the main loop, before script shutdown, rather than the Engine
# singleton (whose later Windows teardown faults after registry reload). No script,
# node, resource or callable is stored here. Authoring validates the value schema.
const CACHE_KEY: StringName = &"_cybersand_gcr_review_fleet_v1"

static func _state() -> Dictionary:
	if not Engine.get_main_loop().has_meta(CACHE_KEY):
		_install(Authoring.load_registry(DEFAULT_MANIFEST))
	return Engine.get_main_loop().get_meta(CACHE_KEY)

static func names() -> Array[String]: return _state().names.duplicate()
static func descriptions() -> Array[String]: return _state().descriptions.duplicate()
static func colors() -> Array[Color]: return _state().colors.duplicate()
# Retained fixture compatibility columns are copies, never mutable cache access.
static func rows() -> Array: return _state().rows.duplicate(true)

static func _text_column(registry: Dictionary, key: String) -> Array[String]:
	var result: Array[String]=[]
	for entry: Dictionary in registry.get("entries",[]): result.append(str(entry[key]))
	return result

static func _color_column(registry: Dictionary) -> Array[Color]:
	var result: Array[Color]=[]
	for entry: Dictionary in registry.get("entries",[]): result.append(Color(str(entry.color)))
	return result

static func _row_column(registry: Dictionary) -> Array:
	var result: Array=[]
	for entry: Dictionary in registry.get("entries",[]): result.append(_row(entry))
	return result

static func _row(entry: Dictionary) -> Array:
	var flight: Dictionary=entry.flight
	return [entry.resolved_bounds.size,float(entry.physics.mass),float(flight.acceleration),float(flight.speed),float(flight.turn_speed),float(flight.turn_acceleration),float(flight.throttle_slew),float(flight.linear_drag),float(flight.force_limit),float(flight.torque_limit)]

static func _install(registry: Dictionary) -> void:
	Engine.get_main_loop().set_meta(CACHE_KEY,{"schema":1,"registry":registry,"last_error":"",
		"names":_text_column(registry,"name"),"descriptions":_text_column(registry,"description"),
		"colors":_color_column(registry),"rows":_row_column(registry)})

static func reload_definitions(manifest_path: String = DEFAULT_MANIFEST) -> bool:
	var candidate: Dictionary=Authoring.load_registry(manifest_path)
	if not str(candidate.get("error","")).is_empty():
		_state().last_error=str(candidate.error)
		return false
	_install(candidate)
	return true

static func registry_snapshot() -> Dictionary:
	return {"records":_state().registry.get("records",[]).duplicate(true),"manifest":_state().registry.get("manifest",DEFAULT_MANIFEST)}

static func restore_registry(snapshot: Dictionary) -> bool:
	if not snapshot.get("records") is Array: return false
	var candidate: Dictionary=Authoring.registry_from_records(snapshot.records,str(snapshot.get("manifest",DEFAULT_MANIFEST)))
	if not str(candidate.get("error","")).is_empty(): return false
	_install(candidate)
	return true

static func last_error() -> String: return _state().last_error if not _state().last_error.is_empty() else str(_state().registry.get("error",""))
static func count() -> int: return _state().registry.get("entries",[]).size()
static func stable_id(index: int) -> String: return str(_state().registry.entries[index].id) if valid_index(index) else ""
static func index_for_id(id: String) -> int:
	for index: int in range(count()):
		if stable_id(index)==id: return index
	return -1
static func definition_hash(index: int) -> String: return str(_state().registry.entries[index].definition_hash) if valid_index(index) else ""
static func registry_hash() -> String: return str(_state().registry.get("registry_hash",""))
static func authoring_record(index: int) -> Dictionary: return _state().registry.records[index].duplicate(true) if valid_index(index) else {}
static func bounds(index: int) -> Rect2: return _state().registry.entries[index].resolved_bounds if valid_index(index) else Rect2()
static func collision_rects(index: int) -> Array: return _state().registry.entries[index].resolved_rects.duplicate(true) if valid_index(index) else []
static func uses_compound(index: int) -> bool: return valid_index(index) and _state().registry.entries[index].hull.kind=="rect_union"
static func is_hoverboard(index: int) -> bool: return valid_index(index) and _state().registry.entries[index].control_mode=="hoverboard"
static func capabilities(index: int) -> Dictionary: return _state().registry.entries[index].capabilities.duplicate(true) if valid_index(index) else {}
static func markings(index: int) -> String: return str(_state().registry.entries[index].markings) if valid_index(index) else ""

static func valid_index(index: int) -> bool: return index >= 0 and index < count()

static func definition(index: int) -> Dictionary:
	if not valid_index(index): return {}
	var entry: Dictionary=_state().registry.entries[index]
	var row: Array = _row(entry)
	var data: Dictionary = Catalog.entry(&"arcadelander")
	data.name = str(entry.name)
	data.description = str(entry.description)
	data.color = Color(str(entry.color))
	data.equipment_preparation = "none"
	data.joints = []
	data.mounts = []
	data.parts = [{"id":"chassis","offset":Vector2.ZERO,"size":row[0],"mass":row[1],
		"angle":0.,"shape":"rectangle","friction":float(entry.physics.friction),"bounce":float(entry.physics.bounce),"role":"hull","color":data.color}]
	data.profile.merge({"player_controller":"gcr_review_fleet","fleet_index":index,
		"fleet_markings":entry.markings,"fleet_control_mode":entry.control_mode,"fleet_side_thrusters":entry.capabilities.side_thrusters,
		"fleet_reverse_thrust":entry.capabilities.reverse_thrust,"fleet_definition_hash":definition_hash(index),
		"fleet_dispenser_q":int(entry.capabilities.dispenser_q),"fleet_dispenser_e":int(entry.capabilities.dispenser_e),"fleet_dispenser_s":int(entry.capabilities.dispenser_s),
		"fleet_proxy_count":collision_rects(index).size(),"fleet_emitter_origin":Vector2(collision_rects(index)[0].center),
		"fleet_attitude_gain":float(entry.flight.attitude_gain),"fleet_attitude_damping":float(entry.flight.attitude_damping),"fleet_trim_angle":float(entry.flight.trim_angle),
		"fleet_boost_multiplier":2.0,
		"gravity":float(entry.physics.gravity),"air_drag":0.,"angular_drag":float(entry.physics.angular_drag),"fleet_accel":row[2],
		"speed":row[3],"fleet_turn_speed":row[4],"fleet_turn_accel":row[5],
		"fleet_slew":row[6],"fleet_drag":row[7],"fleet_force":row[8],"fleet_torque":row[9]},true)
	if uses_compound(index):
		data.parts[0].shape="rectangle_union"
		data.parts[0]["native_mask"]="matching_rectangle_union"
		data.parts[0]["collision_rects"]=collision_rects(index)
		data.parts[0]["inertia"]=float(entry.resolved_inertia)
	data.bounds = bounds(index)
	data.body_size = row[0]
	data.spawn_floor_clearance = data.bounds.end.y+2.
	data.spawn_radius = maxf(data.bounds.position.length(),data.bounds.end.length())+2.
	data.part_count = 1
	return data

static func controls(index: int) -> String:
	if not valid_index(index): return ""
	if is_hoverboard(index): return "W / S   Rise / descend\nA / D   Strafe\nSPACE   Lift burst\nQ / E   Tilt deck%s\nSHIFT   Thrust multiplier · CTRL   Brake\nC   Level assistance" % [" · ±%.0f°" % rad_to_deg(float(_state().registry.entries[index].flight.trim_angle)) if uses_compound(index) else ""]
	var utility: String = ""
	var ports: Dictionary=capabilities(index)
	if ports.side_thrusters: utility="Q / E   Left / right side thrust"
	elif ports.dispenser_q==12: utility="Q   Acid · E   Lava dispenser"
	elif ports.dispenser_q==3: utility="Q / E   Left / right water dispenser"
	elif ports.dispenser_q==8: utility="Q / E   Left / right lava dispenser"
	return "W / SPACE   Body-axis thrust\nA / D   Rotate\n%s\n%s\nSHIFT   Thrust multiplier · CTRL   Brake\nC   Upright assistance" % [utility,"S   Gunpowder dispenser" if ports.dispenser_s==26 else "S   Reverse thrust"]
