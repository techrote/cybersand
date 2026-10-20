class_name CyberDeepworksRuntime
extends "res://scripts/depth/depth_layer_runtime.gd"

# Scripted sources are applied immediately before their target world's native
# tick. Products are owned by the native rules, never painted by observations.
const MAP_SIZE := Vector2i(1024, 1024)
const MAX_EVENTS: int = 192
const MAX_EVENT_AREA: int = 512
const MAX_LAYER_EVENT_WRITES: int = 8192
const MAX_SCHEDULE_TICK: int = 36000
const MAX_REPEAT: int = 10000
const EVENT_KEYS: Array[String] = ["id", "district", "layer", "rect", "material", "first_tick", "period", "repeat"]

var scripts_enabled: bool = true
var _programme: Array[Dictionary] = []
var _fired: Dictionary = {}
var _event_applications: int = 0
var _event_cell_writes: int = 0

func install(definitions: Dictionary, programme: Array) -> bool:
	var error: String = _validate_programme(programme)
	if not error.is_empty():
		last_error = error
		return false
	if not reset(definitions, MAP_SIZE):
		return false
	for raw: Variant in programme:
		var event: Dictionary = raw.duplicate(true)
		_programme.append(event)
		_fired[event["id"]] = 0
	return true

func reset(definitions: Dictionary, authored_size: Vector2i = MAP_SIZE) -> bool:
	if not super.reset(definitions, authored_size):
		return false
	_programme.clear()
	_fired.clear()
	_event_applications = 0
	_event_cell_writes = 0
	scripts_enabled = true
	return true

func event_stats() -> Dictionary:
	return {"generation": generation(), "enabled": scripts_enabled,
		"registered": _programme.size(), "applications": _event_applications,
		"cell_writes": _event_cell_writes, "fired": _fired.duplicate(true)}

func _step_layer(id: String) -> bool:
	if scripts_enabled:
		var tick: int = layer_tick(id)
		for event: Dictionary in _programme:
			if event["layer"] != id:
				continue
			var first: int = int(event["first_tick"])
			if tick < first or (tick - first) % int(event["period"]) != 0:
				continue
			var count: int = int(_fired[event["id"]])
			var repeat_count: int = int(event["repeat"])
			if repeat_count > 0 and count >= repeat_count:
				continue
			var rect: Rect2i = event["rect"]
			if not _worlds[id].diagnostic_fill_rect(rect.position, rect.size, int(event["material"])):
				_fail_layer(id, "Exhibition source rejected: " + str(event["id"]))
				return false
			_fired[event["id"]] = count + 1
			_event_applications += 1
			_event_cell_writes += rect.size.x * rect.size.y
	return super._step_layer(id)

func _validate_programme(programme: Array) -> String:
	if programme.size() > MAX_EVENTS:
		return "exhibition_event_capacity"
	var names: Dictionary = {}
	var layer_writes: Dictionary = {"play": 0, "scripted": 0, "effects": 0}
	for raw: Variant in programme:
		if not raw is Dictionary:
			return "exhibition_event_type"
		var event: Dictionary = raw
		for key: String in EVENT_KEYS:
			if not event.has(key):
				return "exhibition_event_missing_" + key
		for key: Variant in event:
			if not key in EVENT_KEYS:
				return "exhibition_event_unknown_field"
		if not event["id"] is String or event["id"].is_empty() or event["id"].length() > 80:
			return "exhibition_event_identity"
		if names.has(event["id"]):
			return "exhibition_event_duplicate"
		names[event["id"]] = true
		if not event["layer"] is String or not layer_writes.has(event["layer"]):
			return "exhibition_event_layer"
		for key: String in ["district", "material", "first_tick", "period", "repeat"]:
			if typeof(event[key]) != TYPE_INT:
				return "exhibition_event_integer_" + key
		var district: int = event["district"]
		if district < 0 or district >= 16:
			return "exhibition_event_district"
		var material: int = event["material"]
		if material < 0 or material > Cell.LAST_MATERIAL or material == 10:
			return "exhibition_event_material"
		if event["layer"] == "effects" and not material in EFFECT_MATERIALS:
			return "exhibition_event_effects_material"
		if not event["rect"] is Rect2i:
			return "exhibition_event_rectangle"
		var rect: Rect2i = event["rect"]
		if rect.size.x <= 0 or rect.size.y <= 0 or rect.size.x * rect.size.y > MAX_EVENT_AREA:
			return "exhibition_event_area"
		# Rect2i.end/encloses use signed32 arithmetic. Validate widened scalar
		# components first so hostile near-INT32_MAX coordinates cannot wrap.
		var x: int = rect.position.x
		var y: int = rect.position.y
		var width: int = rect.size.x
		var height: int = rect.size.y
		if x < 1 or y < 1 or width > 1022 or height > 1022 or x > 1023 - width or y > 1023 - height:
			return "exhibition_event_bounds"
		var district_x: int = (district % 4) * 256
		var district_y: int = (district / 4) * 256
		if x < district_x or y < district_y or width > district_x + 256 - x or height > district_y + 256 - y:
			return "exhibition_event_bounds"
		if event["first_tick"] < 0 or event["first_tick"] > MAX_SCHEDULE_TICK:
			return "exhibition_event_first_tick"
		if event["period"] < 1 or event["period"] > MAX_SCHEDULE_TICK:
			return "exhibition_event_period"
		if event["repeat"] < 0 or event["repeat"] > MAX_REPEAT:
			return "exhibition_event_repeat"
		layer_writes[event["layer"]] += rect.size.x * rect.size.y
		# Conservative bound assumes every source is due on the same native tick.
		if layer_writes[event["layer"]] > MAX_LAYER_EVENT_WRITES:
			return "exhibition_layer_event_write_budget"
	return ""
