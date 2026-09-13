class_name CyberWaterFeelScenarios
extends RefCounted

const Contract = preload("res://scripts/water_experiment_contract.gd")
const DemoWorlds = preload("res://scripts/demo_worlds.gd")

const VERSION: int = 1
const WORLD_SIDE: int = 1024
const RECTANGLE_STRIDE: int = 5
const WATER_FILL_STRIDE: int = 6
const MAX_ACTIONS: int = 24
const MAX_ACTION_TICK: int = 3600
const MAX_SEED: int = 0x7FFFFFFF

const EMPTY: int = 0
const WALL: int = 1
const SAND: int = 2
const WATER: int = 3
const MERCURY: int = 33


static func valid_id(scenario_id: String) -> bool:
	return Contract.valid_scenario(scenario_id)


static func ids() -> Array[String]:
	return Contract.SCENARIO_IDS.duplicate()


static func recipe(scenario_id: String, seed: int = 0) -> Dictionary:
	if not valid_id(scenario_id) or seed < 0 or seed > MAX_SEED:
		return {}

	var rectangles: PackedInt32Array = PackedInt32Array()
	var water_fills: PackedInt32Array = PackedInt32Array()
	var actions: Array[Dictionary] = []
	var camera_origin: Vector2i = Vector2i.ZERO
	var player_start: Vector2i = Vector2i(24, 222)
	var body_enabled: bool = false
	var focus_x: int = 64
	_add_world_bounds(rectangles)

	match scenario_id:
		"shallow-pool":
			_tank(rectangles, 60, 184, 300, 72)
			_water(water_fills, 64, 235, 292, 17, 128, 0)
			_sample(actions, 240, 60, 184, 300, 72)
		"deep-pool":
			_tank(rectangles, 72, 58, 190, 198)
			_water(water_fills, 76, 112, 182, 140, 255, 0)
			_sample(actions, 360, 72, 58, 190, 198)
		"calm-settling":
			_tank(rectangles, 40, 194, 390, 62)
			_water(water_fills, 44, 232, 382, 20, 255, 0)
			_water(water_fills, 154, 222, 162, 10, 96, 0)
			_sample(actions, 900, 40, 194, 390, 62)
		"connected-pools":
			_tank(rectangles, 42, 154, 382, 102)
			_rect(rectangles, 231, 154, 4, 98, WALL)
			_water(water_fills, 46, 209, 185, 43, 255, 0)
			_water(water_fills, 235, 233, 185, 19, 160, 0)
			_action(actions, 30, "erase", 231, 230, 4, 22, EMPTY, 0, 0)
		"tiny-quantities":
			_rect(rectangles, 48, 250, 384, 6, WALL)
			for index: int in range(8):
				_water(water_fills, 76 + index * 42, 249, 1, 1, 1 << index, 0)
			_sample(actions, 180, 48, 220, 384, 36)
		"residual-pockets":
			_rect(rectangles, 50, 248, 370, 8, WALL)
			for index: int in range(7):
				_rect(rectangles, 72 + index * 48, 236 - index % 3 * 5, 30, 12 + index % 3 * 5, WALL)
				_water(water_fills, 102 + index * 48, 244 - index % 3 * 5, 8, 4, 16 + index * 16, 0)
			_sample(actions, 720, 50, 205, 370, 51)
		"drips":
			_tank(rectangles, 116, 214, 220, 42)
			_water(water_fills, 224, 70, 2, 2, 64, 12)
			for tick: int in [0, 30, 60, 90, 120]:
				_action(actions, tick, "fill", 224, 70, 2, 2, WATER, 64, 12)
		"trickle":
			_rect(rectangles, 80, 250, 320, 6, WALL)
			_water(water_fills, 238, 48, 1, 2, 32, 7)
			for tick: int in range(0, 181, 15):
				_action(actions, tick, "fill", 238, 48, 1, 2, WATER, 32, 7)
		"fast-dump":
			_tank(rectangles, 54, 72, 148, 184)
			_water(water_fills, 58, 92, 140, 160, 255, 12)
			_action(actions, 0, "erase", 198, 210, 4, 42, EMPTY, 0, 0)
		"slow-release":
			_tank(rectangles, 54, 72, 148, 184)
			_water(water_fills, 58, 92, 140, 160, 255, 12)
			for index: int in range(4):
				_action(actions, index * 45, "erase", 198, 236 - index * 6, 4, 6, EMPTY, 0, 0)
		"fall":
			_rect(rectangles, 56, 250, 360, 6, WALL)
			_water(water_fills, 222, 42, 30, 24, 255, 12)
			_sample(actions, 240, 56, 34, 360, 222)
		"thin-stream":
			_rect(rectangles, 72, 250, 330, 6, WALL)
			_water(water_fills, 230, 44, 2, 154, 96, 12)
			_action(actions, 60, "fill", 230, 44, 2, 12, WATER, 96, 12)
		"shower-drizzle":
			_rect(rectangles, 42, 250, 390, 6, WALL)
			for index: int in range(12):
				_water(water_fills, 76 + index * 28, 54 + index % 3 * 8, 1, 2, 24 + index * 4, 7)
			_action(actions, 90, "fill", 76, 54, 309, 1, WATER, 16, 3)
		"ledge-sheet":
			_rect(rectangles, 78, 126, 218, 8, WALL)
			_rect(rectangles, 78, 250, 340, 6, WALL)
			_water(water_fills, 94, 119, 190, 7, 112, 7)
			_action(actions, 0, "erase", 280, 126, 16, 8, EMPTY, 0, 0)
		"narrow-channel":
			_rect(rectangles, 86, 245, 308, 11, WALL)
			_rect(rectangles, 86, 218, 308, 5, WALL)
			_water(water_fills, 90, 223, 300, 22, 144, 0)
			_action(actions, 60, "erase", 380, 218, 10, 5, EMPTY, 0, 0)
		"broad-channel":
			_rect(rectangles, 38, 250, 402, 6, WALL)
			_rect(rectangles, 38, 160, 6, 90, WALL)
			_water(water_fills, 44, 218, 390, 32, 192, 0)
			_sample(actions, 360, 38, 160, 402, 96)
		"steps":
			for index: int in range(7):
				_rect(rectangles, 80 + index * 45, 230 - index * 18, 45, 26 + index * 18, WALL)
			_water(water_fills, 82, 192, 42, 38, 255, 12)
			_action(actions, 0, "erase", 122, 192, 2, 38, EMPTY, 0, 0)
		"u-vessel":
			_rect(rectangles, 104, 80, 8, 176, WALL)
			_rect(rectangles, 104, 248, 270, 8, WALL)
			_rect(rectangles, 366, 80, 8, 176, WALL)
			_water(water_fills, 112, 202, 254, 46, 224, 0)
			_sample(actions, 480, 104, 80, 270, 176)
		"constriction":
			_tank(rectangles, 46, 88, 160, 168)
			_rect(rectangles, 202, 88, 8, 132, WALL)
			_rect(rectangles, 202, 238, 8, 18, WALL)
			_water(water_fills, 50, 112, 152, 140, 255, 12)
			_action(actions, 0, "erase", 202, 220, 8, 18, EMPTY, 0, 0)
		"irregular-bed":
			for index: int in range(18):
				_rect(rectangles, 44 + index * 22, 246 - (index * 17) % 31, 24, 10 + (index * 17) % 31, WALL)
			_water(water_fills, 54, 184, 92, 48, 176, 7)
			_sample(actions, 600, 40, 176, 408, 80)
		"direction-vertical":
			_rect(rectangles, 62, 250, 360, 6, WALL)
			_water(water_fills, 236, 44, 4, 156, 160, 12)
			_action(actions, 45, "fill", 236, 44, 4, 16, WATER, 160, 12)
		"direction-horizontal":
			_rect(rectangles, 62, 250, 360, 6, WALL)
			_water(water_fills, 92, 172, 128, 4, 160, 12)
			_action(actions, 45, "fill", 92, 172, 24, 4, WATER, 160, 12)
		"direction-diagonal":
			_rect(rectangles, 62, 250, 360, 6, WALL)
			for index: int in range(28):
				_water(water_fills, 92 + index * 4, 82 + index * 4, 4, 4, 160, 12)
			_sample(actions, 150, 88, 78, 124, 124)
		"excavation-refill":
			_rect(rectangles, 62, 190, 360, 66, SAND)
			_water(water_fills, 72, 166, 48, 24, 160, 7)
			_action(actions, 30, "erase", 210, 216, 64, 40, EMPTY, 0, 0)
			_action(actions, 60, "fill", 220, 170, 44, 30, WATER, 224, 12)
		"support-removal":
			_rect(rectangles, 62, 250, 360, 6, WALL)
			_rect(rectangles, 160, 176, 170, 8, WALL)
			_water(water_fills, 170, 150, 150, 26, 208, 7)
			_action(actions, 30, "erase", 224, 176, 42, 8, EMPTY, 0, 0)
		"cavity-fill-drain":
			_tank(rectangles, 78, 116, 310, 140)
			_rect(rectangles, 176, 176, 114, 76, WALL)
			_water(water_fills, 82, 160, 92, 92, 208, 7)
			_action(actions, 30, "erase", 176, 232, 12, 20, EMPTY, 0, 0)
		"real-void-barrier":
			_rect(rectangles, 48, 250, 390, 6, WALL)
			_rect(rectangles, 238, 120, 10, 130, WALL)
			_water(water_fills, 78, 208, 124, 42, 192, 7)
			_action(actions, 90, "erase", 238, 212, 10, 38, EMPTY, 0, 0)
		"film-boundaries":
			for index: int in range(13):
				_rect(rectangles, 70 + index * 26, 160 + index * 7, 28, 96 - index * 7, WALL)
				_water(water_fills, 70 + index * 26, 159 + index * 7, 26, 1, 48, 0)
			_sample(actions, 300, 66, 154, 348, 102)
		"storage-seam":
			focus_x = 256
			_rect(rectangles, 176, 250, 180, 6, WALL)
			_water(water_fills, 252, 126, 8, 124, 128, 7)
			_action(actions, 60, "fill", 252, 126, 8, 12, WATER, 128, 7)
		"activity-seam":
			focus_x = 64
			_rect(rectangles, 24, 250, 180, 6, WALL)
			_water(water_fills, 60, 142, 8, 108, 128, 7)
			_action(actions, 60, "fill", 60, 142, 8, 12, WATER, 128, 7)
		"core-seam":
			focus_x = 512
			camera_origin = Vector2i(320, 0)
			player_start = Vector2i(344, 222)
			_rect(rectangles, 430, 250, 180, 6, WALL)
			_water(water_fills, 508, 126, 8, 124, 128, 7)
			_action(actions, 60, "fill", 508, 126, 8, 12, WATER, 128, 7)
		"long-tail-settling":
			_tank(rectangles, 42, 194, 390, 62)
			for index: int in range(12):
				_water(water_fills, 84 + index * 24, 174 - index % 4 * 8, 6, 6, 8 + index * 4, 0)
			_sample(actions, 1800, 42, 150, 390, 106)
		"water-sand-baseline":
			_rect(rectangles, 44, 250, 390, 6, WALL)
			for index: int in range(70):
				_rect(rectangles, 154 + index * 3, 230 - index / 4, 4, 20 + index / 4, SAND)
			_water(water_fills, 72, 168, 68, 82, 255, 12)
			_action(actions, 0, "erase", 136, 214, 8, 36, EMPTY, 0, 0)
		"mercury-reference":
			_tank(rectangles, 92, 132, 286, 124)
			_rect(rectangles, 96, 184, 278, 68, MERCURY)
			_action(actions, 90, "sample", 92, 132, 286, 124, MERCURY, 0, 0)
		"supported-body-water":
			body_enabled = true
			_tank(rectangles, 68, 142, 340, 114)
			_water(water_fills, 72, 202, 332, 50, 224, 7)
			_sample(actions, 180, 68, 142, 340, 114)

	var metadata: Dictionary = {
		"transport_profile": "Baseline",
		"transport_locked": scenario_id == "water-sand-baseline",
		"water_semantics": scenario_id != "mercury-reference",
		"body_path": "supported-existing" if body_enabled else "none",
		"focus_x": focus_x,
	}
	return {
		"version": VERSION,
		"scenario_id": scenario_id,
		"seed": seed,
		"rectangles": rectangles,
		"partial_water_fills": water_fills,
		"actions": actions,
		"camera_origin": camera_origin,
		"player_start": player_start,
		"paused": true,
		"body_enabled": body_enabled,
		"metadata": metadata,
	}


static func recipe_hash(value: Dictionary) -> String:
	if value.is_empty():
		return ""
	var canonical: Dictionary = {
		"version": int(value.get("version", 0)),
		"scenario_id": str(value.get("scenario_id", "")),
		"seed": int(value.get("seed", -1)),
		"rectangles": _packed_to_array(value.get("rectangles", PackedInt32Array())),
		"partial_water_fills": _packed_to_array(
			value.get("partial_water_fills", PackedInt32Array())
		),
		"actions": value.get("actions", []),
		"camera_origin": _vector_to_array(value.get("camera_origin", Vector2i.ZERO)),
		"player_start": _vector_to_array(value.get("player_start", Vector2i.ZERO)),
		"paused": bool(value.get("paused", false)),
		"body_enabled": bool(value.get("body_enabled", false)),
		"metadata": value.get("metadata", {}),
	}
	return JSON.stringify(canonical).sha256_text()


static func catalogue_hash(seed: int = 0) -> String:
	if seed < 0 or seed > MAX_SEED:
		return ""
	var hashes: PackedStringArray = PackedStringArray()
	for scenario_id: String in Contract.SCENARIO_IDS:
		hashes.append(recipe_hash(recipe(scenario_id, seed)))
	return "\n".join(hashes).sha256_text()


static func _add_world_bounds(out: PackedInt32Array) -> void:
	_rect(out, 0, 0, WORLD_SIDE, 1, WALL)
	_rect(out, 0, 0, 1, WORLD_SIDE, WALL)
	_rect(out, WORLD_SIDE - 1, 0, 1, WORLD_SIDE, WALL)
	_rect(out, 0, WORLD_SIDE - 1, WORLD_SIDE, 1, WALL)


static func _rect(
	out: PackedInt32Array, x: int, y: int, width: int, height: int, material: int
) -> void:
	DemoWorlds._rect(out, x, y, width, height, material)


static func _tank(out: PackedInt32Array, x: int, y: int, width: int, height: int) -> void:
	_rect(out, x, y, 4, height, WALL)
	_rect(out, x + width - 4, y, 4, height, WALL)
	_rect(out, x, y + height - 4, width, 4, WALL)


static func _water(
	out: PackedInt32Array,
	x: int,
	y: int,
	width: int,
	height: int,
	normalized_mass: int,
	coherence: int
) -> void:
	out.append_array(PackedInt32Array([
		x, y, width, height, normalized_mass, coherence,
	]))


static func _action(
	out: Array[Dictionary],
	tick: int,
	kind: String,
	x: int,
	y: int,
	width: int,
	height: int,
	material: int,
	normalized_mass: int,
	coherence: int
) -> void:
	assert(out.size() < MAX_ACTIONS)
	out.append({
		"tick": tick,
		"kind": kind,
		"x": x,
		"y": y,
		"width": width,
		"height": height,
		"material": material,
		"normalized_mass": normalized_mass,
		"coherence": coherence,
	})


static func _sample(
	out: Array[Dictionary], tick: int, x: int, y: int, width: int, height: int
) -> void:
	_action(out, tick, "sample", x, y, width, height, EMPTY, 0, 0)


static func _packed_to_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	for entry: int in PackedInt32Array(value):
		result.append(entry)
	return result


static func _vector_to_array(value: Variant) -> Array[int]:
	var vector: Vector2i = Vector2i(value)
	return [vector.x, vector.y]
