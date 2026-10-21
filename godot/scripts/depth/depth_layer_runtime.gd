class_name CyberDepthLayerRuntime
extends RefCounted

# Depth-lab-only owner. Every native adapter call is serialized here; render
# clients receive copied RG8 packets and never observe mutable World storage.
const Cell = preload("res://scripts/cell_world.gd")
const IDS: Array[String] = ["play", "scripted", "effects", "background"]
const WORLD_SIZE: Vector2i = Vector2i(640, 360)
const STORAGE_SIZE: Vector2i = Vector2i(1024, 1024)
const MIN_WORLD_SIDE: int = 8
const DEFAULT_RATES: Dictionary = {"play": 60.0, "scripted": 20.0, "effects": 30.0, "background": 0.0}
const MAX_RATE_HZ: float = 60.0
const MAX_STEPS_PER_ADVANCE: int = 2
const MAX_PENDING_COMMANDS: int = 32
const MAX_RADIUS: int = 32
const MAX_RECTANGLES_PER_LAYER: int = 4096
const MAX_AUTHORING_CELL_WRITES: int = 4194304
const WEATHER_MODES: Array[String] = ["off", "rain", "snow", "fog", "energy"]
const WEATHER_LABELS: Dictionary = {
	"off": "Off",
	"rain": "Rain / Water",
	"snow": "Snow / Dust visual stand-in",
	"fog": "Fog / Steam",
	"energy": "Energy / Spark",
}
const EFFECT_MATERIALS: Array[int] = [
	Cell.EMPTY, Cell.WATER, Cell.DUST, Cell.STEAM, Cell.SPARK, Cell.SMOKE
]
var last_error: String = ""
var world_size: Vector2i = WORLD_SIZE
var _worlds: Dictionary = {}
var _layers: Dictionary = {}
var _commands: Array[Dictionary] = []
var _background_cache: Dictionary = {}
var _effect_sink_rectangles: Array[Rect2i] = []
var _generation: int = 0
var _command_serial: int = 0
var _weather: String = "off"
var _accepted_commands: int = 0
var _rejected_commands: int = 0
var _applied_commands: int = 0
var _discarded_commands: int = 0
var _weather_emissions: int = 0
var _weather_sink_cells_visited: int = 0

func reset(definitions: Dictionary, authored_size: Vector2i = WORLD_SIZE) -> bool:
	# Validate the complete candidate before changing dimensions, worlds, clocks,
	# cached publication or queued commands from the current generation.
	last_error = _validate_definitions(definitions, authored_size)
	if not last_error.is_empty():
		return false
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		last_error = "Depth lab requires the current native CyberNativeCellWorld extension"
		return false
	var candidates: Dictionary = {}
	for id: String in IDS:
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		if world == null or not world.has_method(&"diagnostic_reset"):
			last_error = "Depth lab requires the native isolated-fixture adapter"
			return false
		if not world.diagnostic_reset({"workers": 1, "telemetry": false}):
			last_error = "Could not construct native %s plane" % id
			return false
		world.set_simulation_window(Vector2i.ZERO, authored_size, 16, 16)
		world.set_simulation_window_enabled(true)
		world.set_cadence_lod_enabled(false)
		var rectangles: PackedInt32Array = definitions[id]
		for offset: int in range(0, rectangles.size(), 5):
			if not world.diagnostic_fill_rect(
				Vector2i(rectangles[offset], rectangles[offset + 1]),
				Vector2i(rectangles[offset + 2], rectangles[offset + 3]),
				rectangles[offset + 4]
			):
				last_error = "Native authoring rejected %s rectangle %d" % [id, offset / 5]
				return false
		if id != "background" and not _install_guard(world, authored_size):
			last_error = "Native authoring rejected the %s plane boundary" % id
			return false
		candidates[id] = world
	var next_layers: Dictionary = {}
	for id: String in IDS:
		var previous: Dictionary = _layers.get(id, {})
		next_layers[id] = {
			"tick": 0,
			"rate_hz": previous.get("rate_hz", DEFAULT_RATES[id]),
			"paused": previous.get("paused", false),
			"accumulator": 0.0,
			"dropped_wall_time": 0.0,
			"dropped_steps": 0,
			"native_snapshot_calls": 0,
			"cache_hits": 0,
			"failed": false,
			"error": "",
		}
	# Optional specialized owners prepare against private candidates before any
	# live generation is replaced. The default depth host adds no extra owner.
	last_error = _prepare_candidate_owners(candidates, authored_size)
	if not last_error.is_empty():
		return false
	_discarded_commands += _commands.size()
	_commands.clear()
	_worlds = candidates
	world_size = authored_size
	_effect_sink_rectangles = _build_effect_sinks(authored_size)
	_layers = next_layers
	_background_cache = {}
	_generation += 1
	last_error = ""
	return true

func configure_rates(rates: Dictionary) -> bool:
	if _worlds.is_empty():
		last_error = "Depth lab has not been initialized"
		return false
	for key: Variant in rates:
		if not key in IDS:
			last_error = "Unknown depth plane"
			return false
		var value: Variant = rates[key]
		if not (value is float or value is int) or not is_finite(float(value)):
			last_error = "Layer rates must be finite numbers"
			return false
		if float(value) < 0.0 or float(value) > MAX_RATE_HZ:
			last_error = "Dynamic rates must be within 0..60 Hz"
			return false
		if key == "background" and float(value) != 0.0:
			last_error = "Background is always frozen"
			return false
	for key: Variant in rates:
		_layers[key]["rate_hz"] = float(rates[key])
		_layers[key]["accumulator"] = 0.0
	last_error = ""
	return true

func set_layer_paused(id: String, paused: bool) -> bool:
	if not _layers.has(id) or id == "background":
		last_error = "Only an initialized dynamic plane can be paused"
		return false
	_layers[id]["paused"] = paused
	_layers[id]["accumulator"] = 0.0
	last_error = ""
	return true

func set_weather(mode: String) -> bool:
	if not mode in WEATHER_MODES:
		last_error = "Unknown weather mode"
		return false
	_weather = mode
	last_error = ""
	return true

func paint_disc(id: String, cell: Vector2i, radius: int, material: int) -> Dictionary:
	var error: String = _validate_command(id, cell, radius, material)
	if not error.is_empty():
		return _reject(error)
	if id == "background":
		return _reject("background_frozen")
	if id == "effects" and not material in EFFECT_MATERIALS:
		return _reject("effects_material_not_allowed")
	return _enqueue({
		"kind": "paint", "target": id, "cell": cell,
		"radius": radius, "material": material,
	})

func route_event(source: String, target: String, kind: String, cell: Vector2i,
		radius: int, material: int = Cell.FIRE, generation: int = -1) -> Dictionary:
	if generation != -1 and generation != _generation:
		return _reject("stale_generation")
	if not _worlds.has(source):
		return _reject("unknown_source")
	var blast: bool = source == "play" and target == "scripted" and kind == "blast"
	var burst: bool = source == "scripted" and target == "effects" and kind == "burst"
	if not blast and not burst:
		return _reject("route_not_allowed")
	if bool(_layers[source]["failed"]):
		return _reject("source_failed")
	var error: String = _validate_command(target, cell, radius, material)
	if not error.is_empty():
		return _reject(error)
	if blast and material != Cell.FIRE:
		return _reject("blast_material_must_be_fire")
	if blast and radius < 4:
		return _reject("blast_radius_out_of_budget")
	if burst and not material in EFFECT_MATERIALS:
		return _reject("effects_material_not_allowed")
	return _enqueue({
		"kind": kind, "source": source, "target": target, "cell": cell,
		"radius": radius, "material": material,
	})

func scripted_blast(cell: Vector2i, radius: int, generation: int = -1) -> Dictionary:
	if generation != -1 and generation != _generation:
		return _reject("stale_generation")
	var error: String = _validate_command("scripted", cell, radius, Cell.FIRE)
	if not error.is_empty():
		return _reject(error)
	if radius < 4:
		return _reject("blast_radius_out_of_budget")
	return _enqueue({
		"kind": "blast", "target": "scripted", "cell": cell,
		"radius": radius, "material": Cell.FIRE,
	})

func advance(delta: float, paused: bool = false) -> Dictionary:
	if not is_finite(delta) or delta < 0.0 or delta > 3600.0:
		last_error = "Frame delta must be finite and within 0..3600 seconds"
		return {"ok": false, "error": last_error}
	if _worlds.is_empty():
		return {"ok": false, "error": "Depth lab has not been initialized"}
	_flush_pending()
	var result: Dictionary = {"ok": true, "steps": {}}
	for id: String in IDS:
		result.steps[id] = 0
		var state: Dictionary = _layers[id]
		var rate: float = float(state["rate_hz"])
		if paused or bool(state["paused"]) or rate <= 0.0 or bool(state["failed"]):
			continue
		var interval: float = 1.0 / rate
		var accumulated: float = float(state["accumulator"]) + delta
		var due: int = floori((accumulated + 1.0e-10) / interval)
		var steps: int = mini(due, MAX_STEPS_PER_ADVANCE)
		state["accumulator"] = maxf(0.0, accumulated - float(due) * interval)
		if due > steps:
			state["dropped_steps"] += due - steps
			state["dropped_wall_time"] += float(due - steps) * interval
		for _step: int in range(steps):
			if not _step_layer(id):
				result.ok = false
				break
			result.steps[id] += 1
	return result

func step_once() -> Dictionary:
	if _worlds.is_empty():
		return {"ok": false, "error": "Depth lab has not been initialized"}
	_flush_pending()
	var result: Dictionary = {"ok": true, "steps": {}}
	for id: String in IDS:
		var state: Dictionary = _layers[id]
		result.steps[id] = 0
		if id == "background" or bool(state["paused"]) or float(state["rate_hz"]) <= 0.0 or bool(state["failed"]):
			continue
		if _step_layer(id):
			result.steps[id] = 1
		else:
			result.ok = false
	return result

func snapshot_layer(id: String, force: bool = false) -> Dictionary:
	if not _worlds.has(id):
		return {"failed": true, "error": "Unknown depth plane"}
	if bool(_layers[id]["failed"]):
		return {
			"failed": true, "error": _layers[id]["error"],
			"layer_id": id, "generation": _generation,
		}
	if id == "background" and not _background_cache.is_empty():
		_layers[id]["cache_hits"] += 1
		if force:
			return _background_cache.duplicate(true)
		return _unchanged_packet(id)
	var world: Object = _worlds[id]
	var packet: Dictionary = world.take_render_snapshot(force)
	_layers[id]["native_snapshot_calls"] += 1
	if bool(packet.get("failed", false)):
		_fail_layer(id, str(packet.get("error", "Native publication failed")))
		return packet
	packet["layer_id"] = id
	packet["generation"] = _generation
	packet["reset_generation"] = _generation
	packet["layer_tick"] = int(_layers[id]["tick"])
	packet["unchanged"] = PackedByteArray(packet.get("cells", PackedByteArray())).is_empty()
	if id == "background":
		_background_cache = packet.duplicate(true)
	return packet

func material_at(id: String, cell: Vector2i) -> int:
	if not _worlds.has(id) or not _inside(cell):
		return -1
	return int(_worlds[id].material_at(cell.x, cell.y))

func layer_tick(id: String) -> int:
	if not _layers.has(id):
		return -1
	return int(_layers[id]["tick"])

func generation() -> int:
	return _generation

func weather() -> String:
	return _weather

func stats() -> Dictionary:
	var layer_stats: Dictionary = {}
	for id: String in IDS:
		var state: Dictionary = _layers.get(id, {}).duplicate(true)
		state["resident"] = _worlds.has(id)
		if _worlds.has(id):
			state["native_tick"] = int(_worlds[id].get_tick_index())
		layer_stats[id] = state
	return {
		"generation": _generation,
		"world_size": world_size,
		"weather": _weather,
		"pending_commands": _commands.size(),
		"accepted_commands": _accepted_commands,
		"rejected_commands": _rejected_commands,
		"applied_commands": _applied_commands,
		"discarded_commands": _discarded_commands,
		"weather_emissions": _weather_emissions,
		"weather_sink_cells_visited": _weather_sink_cells_visited,
		"background_cached": not _background_cache.is_empty(),
		"layers": layer_stats,
	}

func _validate_definitions(definitions: Dictionary, authored_size: Vector2i = WORLD_SIZE) -> String:
	if (authored_size.x < MIN_WORLD_SIDE or authored_size.y < MIN_WORLD_SIDE
			or authored_size.x > STORAGE_SIZE.x or authored_size.y > STORAGE_SIZE.y):
		return "Depth dimensions must be within 8..1024 cells on each axis"
	for id: String in IDS:
		if not definitions.has(id):
			return "Missing %s depth plane" % id
		if not definitions[id] is PackedInt32Array:
			return "%s authoring payload must be PackedInt32Array" % id
		var rectangles: PackedInt32Array = definitions[id]
		if rectangles.size() % 5 != 0:
			return "%s authoring payload has invalid stride" % id
		if rectangles.size() / 5 > MAX_RECTANGLES_PER_LAYER:
			return "%s authoring rectangle capacity exceeded" % id
		var writes: int = 0
		for offset: int in range(0, rectangles.size(), 5):
			var x: int = rectangles[offset]
			var y: int = rectangles[offset + 1]
			var width: int = rectangles[offset + 2]
			var height: int = rectangles[offset + 3]
			var material: int = rectangles[offset + 4]
			if width <= 0 or height <= 0 or x < 0 or y < 0 or x + width > authored_size.x or y + height > authored_size.y:
				return "%s contains an out-of-bounds rectangle" % id
			if material < 0 or material == 10 or material > Cell.LAST_MATERIAL:
				return "%s contains an invalid material ID" % id
			writes += width * height
			if writes > MAX_AUTHORING_CELL_WRITES:
				return "%s authoring cell-write capacity exceeded" % id
	for key: Variant in definitions:
		if not key in IDS:
			return "Unknown depth plane in authoring payload"
	return ""

func _validate_command(id: String, cell: Vector2i, radius: int, material: int) -> String:
	if not _worlds.has(id):
		return "unknown_target"
	if bool(_layers[id]["failed"]):
		return "target_failed"
	if radius < 0 or radius > MAX_RADIUS:
		return "radius_out_of_budget"
	if material < 0 or material == 10 or material > Cell.LAST_MATERIAL:
		return "invalid_material"
	if not _inside(cell):
		return "cell_out_of_bounds"
	if cell.x - radius < 1 or cell.y - radius < 1 or cell.x + radius >= world_size.x - 1 or cell.y + radius >= world_size.y - 1:
		return "disc_crosses_plane_guard"
	return ""

func _enqueue(command: Dictionary) -> Dictionary:
	if _commands.size() >= MAX_PENDING_COMMANDS:
		return _reject("command_capacity_exhausted")
	_command_serial += 1
	var record: Dictionary = command.duplicate(true)
	record["serial"] = _command_serial
	record["generation"] = _generation
	_commands.append(record)
	_accepted_commands += 1
	return {"accepted": true, "serial": _command_serial, "generation": _generation}

func _reject(error: String) -> Dictionary:
	_rejected_commands += 1
	return {"accepted": false, "error": error, "generation": _generation}

func _flush_pending() -> void:
	while not _commands.is_empty():
		var command: Dictionary = _commands.pop_front()
		if int(command.get("generation", -1)) != _generation:
			_discarded_commands += 1
			continue
		var target: String = str(command["target"])
		if not _worlds.has(target) or bool(_layers[target]["failed"]):
			_discarded_commands += 1
			continue
		var world: Object = _worlds[target]
		var cell: Vector2i = command["cell"]
		var radius: int = int(command["radius"])
		var material: int = int(command["material"])
		match str(command["kind"]):
			"blast":
				world.emit_disc(cell.x, cell.y, radius, Cell.EMPTY)
				world.emit_disc(cell.x, cell.y, maxi(2, radius / 4), Cell.FIRE)
			"burst", "paint":
				world.emit_disc(cell.x, cell.y, radius, material)
			_:
				_discarded_commands += 1
				continue
		_applied_commands += 1

func _step_layer(id: String) -> bool:
	var world: Object = _worlds[id]
	if id == "effects":
		_clear_effect_edges(world)
		_emit_weather(world, int(_layers[id]["tick"]))
	if not world.simulation_tick():
		_fail_layer(id, "Native %s plane tick failed" % id)
		return false
	_layers[id]["tick"] = int(world.get_tick_index())
	if world.has_failed():
		_fail_layer(id, "Native %s plane entered failed-world quarantine" % id)
		return false
	return true

func _emit_weather(world: Object, tick: int) -> void:
	if _weather == "off":
		return
	var material: int = Cell.WATER
	var count: int = 10
	var y: int = mini(22, world_size.y - 3)
	match _weather:
		"rain":
			material = Cell.WATER
			count = 10
		"snow":
			material = Cell.DUST
			count = 7
		"fog":
			material = Cell.STEAM
			count = 5
			y = clampi(roundi(float(world_size.y) * 0.7), 3, world_size.y - 4)
		"energy":
			material = Cell.SPARK
			count = 4
	for index: int in range(count):
		var margin: int = mini(24, maxi(3, (world_size.x - 1) / 2))
		var x: int = margin + posmod(tick * 47 + index * 61 + index * index * 7, world_size.x - margin * 2)
		var fog_span: int = mini(34, world_size.y - 3 - y)
		var py: int = y + posmod(index * 23 + tick * 3, fog_span) if _weather == "fog" else y
		world.emit_disc(x, py, 1 if material != Cell.STEAM else 2, material)
		_weather_emissions += 1

func _clear_effect_edges(world: Object) -> void:
	for rect: Rect2i in _effect_sink_rectangles:
		if world.diagnostic_fill_rect(rect.position, rect.size, Cell.EMPTY):
			_weather_sink_cells_visited += rect.size.x * rect.size.y

func _build_effect_sinks(authored_size: Vector2i) -> Array[Rect2i]:
	# All sinks stay strictly inside the guard, including the right-hand edge.
	# At small admitted sizes the top/bottom bands consume the interior safely.
	# Prepare the fixed rectangles during reset rather than allocating per tick.
	var top: int = mini(3, (authored_size.y - 2) / 2)
	var bottom: int = mini(7, authored_size.y - 2 - top)
	var middle: int = authored_size.y - 2 - top - bottom
	var sides: int = mini(3, (authored_size.x - 2) / 2)
	var sinks: Array[Rect2i] = [
		Rect2i(1, 1, authored_size.x - 2, top),
		Rect2i(1, authored_size.y - 1 - bottom, authored_size.x - 2, bottom),
	]
	if middle > 0:
		sinks.append(Rect2i(1, 1 + top, sides, middle))
		sinks.append(Rect2i(authored_size.x - 1 - sides, 1 + top, sides, middle))
	return sinks

func _install_guard(world: Object, authored_size: Vector2i) -> bool:
	return (
		world.diagnostic_fill_rect(Vector2i(0, 0), Vector2i(authored_size.x, 1), Cell.WALL)
		and world.diagnostic_fill_rect(Vector2i(0, authored_size.y - 1), Vector2i(authored_size.x, 1), Cell.WALL)
		and world.diagnostic_fill_rect(Vector2i(0, 1), Vector2i(1, authored_size.y - 2), Cell.WALL)
		and world.diagnostic_fill_rect(Vector2i(authored_size.x - 1, 1), Vector2i(1, authored_size.y - 2), Cell.WALL)
	)

func _unchanged_packet(id: String) -> Dictionary:
	return {
		"failed": false,
		"serial": 0,
		"channels": 2,
		"full_refresh": false,
		"rectangles": PackedInt32Array(),
		"cells": PackedByteArray(),
		"layer_id": id,
		"generation": _generation,
		"reset_generation": _generation,
		"layer_tick": int(_layers[id]["tick"]),
		"unchanged": true,
	}

func _fail_layer(id: String, error: String) -> void:
	_layers[id]["failed"] = true
	_layers[id]["error"] = error
	last_error = error

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < world_size.x and cell.y < world_size.y

func _prepare_candidate_owners(_candidates: Dictionary, _authored_size: Vector2i) -> String:
	return ""
