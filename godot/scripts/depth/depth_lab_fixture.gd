class_name CyberDepthLabFixture
extends RefCounted

const M = preload("res://scripts/cell_world.gd")
const WIDTH: int = 640
const HEIGHT: int = 360
const SIZE: Vector2i = Vector2i(WIDTH, HEIGHT)
const LAYER_IDS: Array[String] = ["play", "scripted", "effects", "background"]
const TITLE: String = "STRATA THEATRE"

const GLYPHS: Dictionary = {
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"],
	"3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"A": ["010", "101", "111", "101", "101"],
	"D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"],
	"H": ["101", "101", "111", "101", "101"],
	"I": ["111", "010", "010", "010", "111"],
	"L": ["100", "100", "100", "100", "111"],
	"P": ["110", "101", "110", "100", "100"],
	"R": ["110", "101", "110", "101", "101"],
	"S": ["111", "100", "111", "001", "111"],
	"T": ["111", "010", "010", "010", "010"],
	"Y": ["101", "101", "010", "010", "010"],
	" ": ["000", "000", "000", "000", "000"],
}

static func build() -> Dictionary:
	var out: Dictionary = {}
	for layer_id: String in LAYER_IDS:
		out[layer_id] = rectangles(layer_id)
	return out

static func definitions() -> Dictionary:
	return build()

static func layer_ids() -> Array[String]:
	return LAYER_IDS.duplicate()

static func rectangles(layer_id: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	match layer_id:
		"play": _play(out)
		"scripted": _scripted(out)
		"effects": _effects(out)
		"background": _background(out)
	return out

static func features() -> Dictionary:
	return {
		"title": TITLE,
		"world_size": SIZE,
		"camera_origin": Vector2(80, 45),
		"view_size": Vector2i(480, 270),
		"camera_bounds": Rect2(Vector2.ZERO, Vector2(SIZE)),
		"spawn": Vector2(199, 279),
		"reactor_target": Vector2i(366, 218),
		"reactor_radius": 28,
		"foreground_water": Vector2i(144, 274),
		"foreground_sand": Vector2i(485, 290),
		"rear_waterfall": Vector2i(272, 185),
		"landmarks": [
			{"id":"halo","label":"04 / Arcology halo","layer":"background","cell":Vector2i(346,119)},
			{"id":"reactor","label":"02 / Rear reactor","layer":"scripted","cell":Vector2i(366,218)},
			{"id":"rain_shaft","label":"03 / Rain shaft","layer":"effects","cell":Vector2i(240,128)},
			{"id":"front_coolant","label":"01 / Play coolant","layer":"play","cell":Vector2i(144,274)},
			{"id":"aggregate_hopper","label":"01 / Play aggregate","layer":"play","cell":Vector2i(485,290)},
		],
		"emitters": [
			{"layer":"effects","material":M.WATER,"cell":Vector2i(241,35),"radius":1},
			{"layer":"effects","material":M.STEAM,"cell":Vector2i(416,285),"radius":2},
			{"layer":"scripted","material":M.WATER,"cell":Vector2i(272,185),"radius":1},
		],
	}

static func _play(out: PackedInt32Array) -> void:
	_rect(out, 0, 0, WIDTH, 9, M.ASPHALT)
	_rect(out, 0, 9, WIDTH, 7, M.CORRUGATED_STEEL)
	_rect(out, 0, 16, WIDTH, 3, M.STEEL_PLATE)
	_rect(out, 0, 0, 19, HEIGHT, M.REINFORCED_CONCRETE)
	_rect(out, 621, 0, 19, HEIGHT, M.REINFORCED_CONCRETE)
	_rect(out, 19, 0, 5, HEIGHT, M.RUSTED_STEEL)
	_rect(out, 616, 0, 5, HEIGHT, M.PAINTED_STEEL)
	for index: int in range(16):
		var x: int = 26 + index * 39
		_rect(out, x, 19, 19, 5, M.STEEL_PLATE)
		_rect(out, x + 4, 24, 11, 5, M.PAINTED_STEEL)
		_rect(out, x + 8, 29, 3, 6, M.STEEL_PIPE)
		_rect(out, x + 1, 20, 1, 1, M.LED_WHITE)
	_line(out, Vector2i(35, 35), Vector2i(96, 96), 7, M.STEEL_PLATE)
	_line(out, Vector2i(605, 35), Vector2i(539, 104), 7, M.STEEL_PLATE)
	_line(out, Vector2i(36, 32), Vector2i(96, 92), 2, M.NEON_CYAN)
	_line(out, Vector2i(602, 34), Vector2i(537, 101), 2, M.NEON_MAGENTA)
	_rect(out, 92, 93, 7, 114, M.PAINTED_STEEL)
	_rect(out, 533, 101, 8, 130, M.RUSTED_STEEL)
	_rect(out, 98, 93, 2, 111, M.STEEL_PIPE)
	_rect(out, 532, 109, 1, 112, M.NEON_CYAN)
	_rect(out, 44, 44, 184, 6, M.COPPER_PIPE)
	_rect(out, 44, 44, 6, 217, M.COPPER_PIPE)
	_rect(out, 48, 259, 44, 6, M.VERDIGRIS_COPPER)
	_box(out, Rect2i(119, 71, 112, 35), 3, M.STEEL_PLATE, M.DARK_GLASS)
	_rect(out, 122, 74, 106, 1, M.NEON_CYAN)
	_text(out, "STRATA", Vector2i(132, 81), 2, M.NEON_CYAN)
	_text(out, "01", Vector2i(196, 93), 1, M.NEON_AMBER)
	# Foreground gantries, coolant reservoir, aggregate hopper and floor.
	_rect(out, 24, 303, 592, 12, M.STEEL_GRATING)
	_rect(out, 24, 315, 592, 45, M.REINFORCED_CONCRETE)
	for x: int in range(46, 612, 64):
		_rect(out, x, 214, 7, 89, M.RUSTED_STEEL)
		_rect(out, x - 5, 212, 17, 5, M.STEEL_PLATE)
	_rect(out, 86, 265, 126, 38, M.STEEL_PLATE)
	_rect(out, 92, 270, 114, 29, M.WATER)
	_rect(out, 94, 268, 110, 2, M.CHEMICAL_GLASS)
	_rect(out, 425, 250, 132, 53, M.STEEL_PLATE)
	_rect(out, 434, 259, 114, 40, M.SAND)
	_line(out, Vector2i(425,250), Vector2i(484,210), 5, M.HAZARD_STRIPE)
	_line(out, Vector2i(557,250), Vector2i(500,210), 5, M.HAZARD_STRIPE)
	_rect(out, 274, 221, 93, 6, M.STEEL_GRATING)
	_rect(out, 280, 227, 5, 76, M.STEEL_PIPE)
	_rect(out, 354, 227, 5, 76, M.STEEL_PIPE)
	_rect(out, 308, 186, 16, 35, M.CABLE_BUNDLE)
	_rect(out, 314, 180, 4, 42, M.NEON_AMBER)

static func _scripted(out: PackedInt32Array) -> void:
	# Rear service hall and reactor: destructible, separate authority.
	_rect(out, 30, 292, 580, 8, M.INDUSTRIAL_BRICK)
	for x: int in range(55, 606, 55):
		_rect(out, x, 96, 5, 196, M.STEEL_PIPE)
	_rect(out, 50, 116, 540, 6, M.CORRUGATED_STEEL)
	_rect(out, 50, 204, 540, 5, M.STEEL_GRATING)
	_box(out, Rect2i(327, 154, 80, 111), 5, M.PAINTED_STEEL, M.DARK_GLASS)
	_rect(out, 337, 166, 60, 77, M.MOLTEN_GLASS)
	_rect(out, 342, 170, 50, 68, M.LAVA)
	_rect(out, 331, 158, 72, 3, M.NEON_MAGENTA)
	_text(out, "02", Vector2i(352, 249), 2, M.NEON_AMBER)
	_rect(out, 264, 136, 16, 140, M.COPPER_PIPE)
	_rect(out, 268, 174, 8, 102, M.WATER)
	_rect(out, 218, 251, 81, 6, M.RUSTED_STEEL)
	_rect(out, 420, 250, 112, 5, M.RUSTED_STEEL)
	_line(out, Vector2i(91,122), Vector2i(166,204), 3, M.CHAINLINK)
	_line(out, Vector2i(166,122), Vector2i(91,204), 3, M.CHAINLINK)

static func _effects(out: PackedInt32Array) -> void:
	# Sparse authored wisps. Runtime weather adds native Water/Dust/Steam/Spark.
	_rect(out, 403, 268, 4, 18, M.STEAM)
	_rect(out, 410, 260, 3, 22, M.STEAM)
	_rect(out, 418, 275, 5, 13, M.SMOKE)
	_rect(out, 237, 72, 2, 16, M.WATER)
	_rect(out, 243, 87, 1, 10, M.WATER)

static func _background(out: PackedInt32Array) -> void:
	# Frozen authored city; rendered by the same material palette.
	_rect(out, 0, 310, WIDTH, 50, M.DARK_GLASS)
	for index: int in range(18):
		var x: int = 18 + index * 35
		var height: int = 54 + (index * 31) % 128
		var y: int = 310 - height
		var material: int = M.INDUSTRIAL_BRICK if index % 3 == 0 else M.PAINTED_STEEL
		_rect(out, x, y, 23 + (index % 4) * 4, height, material)
		for wy: int in range(y + 9, 304, 14):
			for wx: int in range(x + 5, mini(x + 25, 630), 9):
				_rect(out, wx, wy, 2, 2, M.LED_WHITE if (wx + wy) % 3 else M.NEON_CYAN)
	# Arcology halo / bridge gives camera motion an unmistakable far-depth cue.
	_box(out, Rect2i(276, 70, 144, 96), 4, M.STEEL_PLATE, M.DARK_GLASS)
	_box(out, Rect2i(298, 86, 100, 66), 3, M.NEON_CYAN, M.DARK_GLASS)
	_rect(out, 321, 102, 54, 34, M.STAINED_GLASS)
	_text(out, "04", Vector2i(339, 112), 2, M.LED_WHITE)
	_line(out, Vector2i(24,210), Vector2i(280,140), 4, M.STEEL_PIPE)
	_line(out, Vector2i(416,140), Vector2i(616,206), 4, M.STEEL_PIPE)

static func _rect(out: PackedInt32Array, x: int, y: int, width: int, height: int, material: int) -> void:
	if width <= 0 or height <= 0:
		return
	out.append_array(PackedInt32Array([x, y, width, height, material]))

static func _box(out: PackedInt32Array, rect: Rect2i, edge: int, frame: int, fill: int) -> void:
	_rect(out, rect.position.x, rect.position.y, rect.size.x, rect.size.y, fill)
	_rect(out, rect.position.x, rect.position.y, rect.size.x, edge, frame)
	_rect(out, rect.position.x, rect.end.y - edge, rect.size.x, edge, frame)
	_rect(out, rect.position.x, rect.position.y, edge, rect.size.y, frame)
	_rect(out, rect.end.x - edge, rect.position.y, edge, rect.size.y, frame)

static func _line(out: PackedInt32Array, a: Vector2i, b: Vector2i, width: int, material: int) -> void:
	var delta := b - a
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	if steps <= 0:
		_rect(out, a.x, a.y, width, width, material)
		return
	for i: int in range(steps + 1):
		var p := Vector2(a).lerp(Vector2(b), float(i) / float(steps))
		_rect(out, roundi(p.x) - width / 2, roundi(p.y) - width / 2, width, width, material)

static func _text(out: PackedInt32Array, value: String, origin: Vector2i, scale: int, material: int) -> void:
	var cursor: int = origin.x
	for character: String in value:
		var rows: Array = GLYPHS.get(character, GLYPHS[" "])
		for row: int in range(5):
			var bits: String = rows[row]
			for column: int in range(3):
				if bits[column] == "1":
					_rect(out, cursor + column * scale, origin.y + row * scale, scale, scale, material)
		cursor += 4 * scale
