class_name CyberMiddleCyberberbia
extends RefCounted

# A residential cutaway built from ordinary native materials. Gardens, fabric,
# furniture and satellite dishes are authored silhouettes, not new mechanics.
const ID: String = "middle_cyberberbia"
const SCENARIO_ID: String = "showcase/middle-cyberberbia"
const TITLE: String = "Middle Cyberberbia"
const VERSION: int = 1
const Art = preload("res://scripts/neon_reliquary.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")

const EXTRA_GLYPHS: Dictionary = {
	"B": ["110", "101", "110", "101", "110"],
	"D": ["110", "101", "101", "101", "110"],
	"G": ["111", "100", "101", "101", "111"],
	"H": ["101", "101", "111", "101", "101"],
	"M": ["101", "111", "111", "101", "101"],
	"O": ["111", "101", "101", "101", "111"],
	"P": ["110", "101", "110", "100", "100"],
	"S": ["111", "100", "111", "001", "111"],
	"Y": ["101", "101", "010", "010", "010"],
	"2": ["111", "001", "111", "100", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
}


static func spawn() -> Vector2:
	return Vector2(88, 488)


static func viewpoints() -> Array[Dictionary]:
	return [
		{"name": "Middle Cyberberbia", "origin": Vector2(32, 16), "size": Vector2i(960, 540)},
		{"name": "The hanging garden court", "origin": Vector2(272, 150), "size": Vector2i(480, 270)},
		{"name": "West terrace homes", "origin": Vector2(32, 80), "size": Vector2i(480, 270)},
		{"name": "The rose apartments", "origin": Vector2(512, 112), "size": Vector2i(480, 270)},
		{"name": "Lanterns and the lower court", "origin": Vector2(272, 286), "size": Vector2i(480, 270)},
	]


static func landmarks() -> Array[Dictionary]:
	return [
		{"point": Vector2i(88, 488), "material": Art.EMPTY},
		{"point": Vector2i(88, 510), "material": Art.WET_COBBLE},
		{"point": Vector2i(513, 377), "material": Art.AMBER},
		{"point": Vector2i(516, 491), "material": Art.WATER},
		{"point": Vector2i(520, 504), "material": Art.VERDIGRIS},
	]


static func definition(seed: int = 0) -> Dictionary:
	var out: Dictionary = Contract.base(SCENARIO_ID, VERSION, seed)
	out.schema_version = 2
	out.rectangles = Array(rectangles())
	out.player_start = [88, 488]
	out.camera_origin = [32, 16]
	out.player_enabled = true
	out.body_enabled = false
	out.tools = ["paint", "erase", "player"]
	out.interest = {"policy": "fixed", "region": [32, 16, 960, 540]}
	out["presentation"] = {
		"title": TITLE,
		"instructions": "A dense residential district beneath the reliquary: warm apartments, "
			+ "roof gardens, laundry, small shops and an inhabited bridge above a lantern court. "
			+ "Starts paused. P resumes ordinary materials, R restores the scene, arrow keys pan "
			+ "and F8 gives a clean view. Paint, erase and the player are available. "
			+ "This is an aesthetic example level with no objectives or physics qualification.",
		"duration_ticks": 600,
		"baseline": "Current native materials / Baseline transport / Water8-coherence12",
		"profile": "Middle Cyberberbia / authored residential district v1",
		"regions": [],
	}
	out.source_recipe = "CyberMiddleCyberberbia/v1"
	out.source_recipe_hash = JSON.stringify(out.rectangles).sha256_text()
	return out


static func rectangles() -> PackedInt32Array:
	var out := PackedInt32Array()
	_r(out, 0, 0, 1024, 1, Art.WALL)
	_r(out, 0, 1, 1, 1023, Art.WALL)
	_r(out, 1023, 1, 1, 1023, Art.WALL)
	_r(out, 1, 1023, 1022, 1, Art.WALL)
	_street_foundation(out)
	_west_homes(out)
	_east_homes(out)
	_high_walkways(out)
	_garden_bridge(out)
	_lower_shops(out)
	_courtyard(out)
	_residential_services(out)
	# A clear doorway and dry landing survive all facade and service layers.
	_r(out, 76, 462, 96, 48, Art.EMPTY)
	_r(out, 70, 510, 110, 5, Art.WET_COBBLE)
	return out


static func _r(out: PackedInt32Array, x: int, y: int, w: int, h: int, material: int) -> void:
	Art._rect(out, x, y, w, h, material)


static func _text(out: PackedInt32Array, text: String, x: int, y: int,
		material: int, scale: int = 1) -> void:
	var cursor: int = x
	for character: String in text:
		var glyph: Array = EXTRA_GLYPHS.get(character, Art.GLYPHS.get(character, []))
		for row: int in range(glyph.size()):
			var column: int = 0
			while column < 3:
				if glyph[row][column] == "0":
					column += 1
					continue
				var first: int = column
				while column < 3 and glyph[row][column] == "1":
					column += 1
				_r(out, cursor + first * scale, y + row * scale,
					(column - first) * scale, scale, material)
		cursor += 4 * scale


static func _facade(out: PackedInt32Array, x: int, y: int, w: int, h: int, material: int) -> void:
	_r(out, x, y, w, h, material)
	_r(out, x + 2, y + 5, 3, h - 5, Art.SLATE)
	_r(out, x + w - 6, y + 4, 4, h - 4, Art.IRON)
	_r(out, x - 4, y - 3, w + 8, 7, Art.CONCRETE)
	_r(out, x - 2, y - 3, w + 4, 2, Art.VERDIGRIS)
	_r(out, x - 3, y + h - 3, w + 6, 6, Art.SLATE)
	Art._rivet_row(out, x + 3, y, w - 6, 17, Art.IRON)


static func _room(out: PackedInt32Array, x: int, y: int, w: int, h: int, variant: int) -> void:
	# Light sits in the room, while small furniture makes the residential scale
	# legible even without a character standing next to every window.
	Art._panel(out, x, y, w, h, Art.IRON, Art.DARK_GLASS)
	_r(out, x + 3, y + h - 5, w - 6, 3, Art.SANDSTONE)
	_r(out, x + 3, y + 3, w - 6, 1, Art.AMBER if variant % 5 else Art.CYAN)
	_r(out, x + 3, y + 5, 3, h - 12, Art.INSULATION if variant % 2 else Art.PAINTED_STEEL)
	_r(out, x + w - 7, y + 5, 3, h - 12, Art.RUSTED_STEEL if variant % 3 else Art.PLASTER)
	var centre: int = x + w / 2
	if variant % 3 == 0:
		# Bed, quilt edge, pillow and a shaded bedside lamp.
		_r(out, x + 8, y + h - 11, w - 17, 6, Art.RUBBER)
		_r(out, x + 9, y + h - 12, w - 19, 3, Art.PLASTER)
		_r(out, x + 10, y + h - 13, 4, 2, Art.TILE)
		_r(out, x + w - 11, y + h - 14, 4, 2, Art.BRONZE)
		_r(out, x + w - 10, y + h - 18, 1, 4, Art.LEAD)
		_r(out, x + w - 12, y + h - 19, 5, 2, Art.AMBER)
	elif variant % 3 == 1:
		# Kitchen counter, cupboard doors and a small illuminated display.
		_r(out, x + 8, y + h - 13, w - 16, 8, Art.PAINTED_STEEL)
		_r(out, x + 8, y + h - 14, w - 16, 2, Art.PLASTER)
		_r(out, centre, y + h - 11, 1, 5, Art.IRON)
		_r(out, centre + 3, y + h - 10, 2, 1, Art.LEAD)
		_r(out, x + 9, y + 8, 9, 6, Art.IRON)
		_r(out, x + 11, y + 10, 5, 2, Art.CYAN)
	else:
		# Table, chair and shelf of deliberately different silhouettes.
		_r(out, x + 9, y + h - 15, w - 19, 2, Art.BRONZE)
		_r(out, x + 11, y + h - 13, 2, 8, Art.IRON)
		_r(out, x + w - 14, y + h - 13, 2, 8, Art.IRON)
		_r(out, centre, y + h - 10, 6, 2, Art.PAINTED_STEEL)
		_r(out, centre + 5, y + h - 17, 2, 9, Art.PAINTED_STEEL)
		_r(out, x + 8, y + 9, w - 16, 2, Art.LEAD)
		for item: int in range(3):
			_r(out, x + 10 + item * 5, y + 5 + item % 2, 3, 4 - item % 2,
				Art.PLASTER if item % 2 else Art.VERDIGRIS)
	_r(out, centre, y + 2, 1, h - 7, Art.IRON)
	_r(out, x - 2, y + h, w + 4, 3, Art.LEAD)
	_r(out, x + 2, y + h + 2, w - 4, 1, Art.SLATE)
	_r(out, x + 2, y + 1, 2, 1, Art.PLASTER)


static func _balcony(out: PackedInt32Array, x: int, y: int, w: int, lit: bool = false) -> void:
	_r(out, x - 3, y + 10, w + 6, 5, Art.SLATE)
	_r(out, x - 3, y + 10, w + 6, 1, Art.LEAD)
	_r(out, x, y, w, 1, Art.BRONZE)
	for offset: int in range(0, w, 8):
		_r(out, x + offset, y + 1, 1, 9, Art.IRON)
	if lit:
		_r(out, x + 5, y + 14, w - 10, 1, Art.CYAN)
	_r(out, x + 3, y + 15, 3, 5, Art.IRON)
	_r(out, x + w - 6, y + 15, 3, 5, Art.IRON)


static func _garden(out: PackedInt32Array, x: int, y: int, w: int, high: int = 8) -> void:
	_r(out, x, y, w, 7, Art.RUSTED_STEEL)
	_r(out, x - 1, y - 1, w + 2, 3, Art.VERDIGRIS)
	_r(out, x + 3, y + 3, w - 6, 2, Art.IRON)
	for index: int in range(maxi(1, w / 14)):
		var bx: int = x + 3 + index * 14
		var height: int = high + (index * 3) % 7
		_r(out, bx + 4, y - height, 2, height, Art.BRONZE)
		_r(out, bx, y - height + 3, 11, height - 2, Art.MOSS_STONE)
		_r(out, bx + 2, y - height, 7, 4, Art.VERDIGRIS)
		_r(out, bx + 9, y - 6, 3, 6, Art.VERDIGRIS)
		_r(out, bx + 1, y - height + 3, 2, 2, Art.MOSS_STONE)


static func _laundry(out: PackedInt32Array, from: Vector2i, to: Vector2i, garments: int = 6) -> void:
	Art._draped_cable(out, from, to, 9.0)
	var colours: Array[int] = [Art.PLASTER, Art.PAINTED_STEEL, Art.INSULATION, Art.RUSTED_STEEL]
	for index: int in range(garments):
		var t: float = float(index + 1) / float(garments + 1)
		var point: Vector2 = Vector2(from).lerp(Vector2(to), t)
		point.y += 36.0 * t * (1.0 - t)
		var x: int = roundi(point.x)
		var y: int = roundi(point.y)
		_r(out, x - 1, y + 1, 6, 10 + index % 3, colours[index % colours.size()])
		_r(out, x - 2, y + 1, 2, 4, colours[index % colours.size()])
		_r(out, x + 4, y + 1, 2, 4, colours[index % colours.size()])
		_r(out, x, y, 1, 2, Art.IRON)
		if index % 2:
			_r(out, x + 1, y + 8, 2, 5, Art.EMPTY)
		else:
			_r(out, x, y + 6, 4, 1, Art.LEAD)


static func _dish(out: PackedInt32Array, cx: int, y: int, facing: int = 1) -> void:
	_r(out, cx - 2, y + 7, 4, 17, Art.STEEL_PIPE)
	_r(out, cx - 9, y + 22, 18, 3, Art.SLATE)
	for offset: int in range(-13, 14):
		var curve: int = roundi(6.0 * pow(float(offset) / 13.0, 2.0))
		_r(out, cx + offset, y + 6 - curve, 1, 2, Art.LEAD)
	Art._beam(out, Vector2i(cx, y + 7), Vector2i(cx + 12 * facing, y - 10), 1, Art.IRON)
	_r(out, cx + 12 * facing - 2, y - 12, 5, 4, Art.PAINTED_STEEL)
	_r(out, cx + 12 * facing, y - 12, 1, 1, Art.CYAN)


static func _awning(out: PackedInt32Array, x: int, y: int, w: int, colour: int) -> void:
	_r(out, x, y, w, 7, colour)
	_r(out, x - 2, y + 7, w + 4, 2, Art.IRON)
	for offset: int in range(0, w - 3, 10):
		_r(out, x + offset, y, 4, 7, Art.PLASTER)
		_r(out, x + offset, y + 8, 4, 3, colour)
	Art._beam(out, Vector2i(x, y + 10), Vector2i(x + 6, y + 20), 1, Art.IRON)
	Art._beam(out, Vector2i(x + w - 1, y + 10), Vector2i(x + w - 7, y + 20), 1, Art.IRON)


static func _street_foundation(out: PackedInt32Array) -> void:
	_r(out, 42, 510, 938, 11, Art.WET_COBBLE)
	_r(out, 46, 521, 930, 35, Art.GRANITE)
	_r(out, 53, 528, 916, 28, Art.INDUSTRIAL_BRICK)
	_r(out, 48, 521, 923, 2, Art.VERDIGRIS)
	_r(out, 49, 550, 920, 6, Art.WET_ASPHALT)
	for index: int in range(9):
		var x: int = 61 + index * 102
		Art._panel(out, x, 533, 80, 18, Art.SLATE, Art.EMPTY)
		_r(out, x + 7, 545, 64, 3, Art.COPPER_PIPE)
		_r(out, x + 15, 535, 2, 10, Art.IRON)
		_r(out, x + 57, 535, 2, 10, Art.IRON)
		_r(out, x + 5, 534, 7, 1, Art.AMBER if index % 3 == 0 else Art.LEAD)
	for x: int in range(61, 971, 29):
		_r(out, x, 516, 4, 2, Art.SLATE)
	_r(out, 445, 514, 24, 3, Art.GRATING)
	_r(out, 594, 514, 28, 3, Art.GRATING)


static func _west_homes(out: PackedInt32Array) -> void:
	_facade(out, 62, 221, 120, 230, Art.INDUSTRIAL_BRICK)
	_facade(out, 91, 182, 75, 40, Art.CORRUGATED)
	_r(out, 104, 159, 52, 23, Art.PAINTED_STEEL)
	Art._vent(out, 114, 164, 31, 15)
	_dish(out, 105, 139, -1)
	_garden(out, 137, 181, 27, 9)
	for floor: int in range(4):
		var y: int = 235 + floor * 51
		_room(out, 73, y, 43, 35, floor * 2)
		_room(out, 126, y, 43, 35, floor * 2 + 1)
		_balcony(out, 69, y + 36, 104, floor == 2)
		if floor % 2 == 0:
			_garden(out, 72, y + 46, 29, 6)
	_facade(out, 203, 126, 151, 267, Art.PLASTER)
	_r(out, 208, 134, 10, 251, Art.RUSTED_STEEL)
	_r(out, 335, 130, 13, 260, Art.BRICK)
	_r(out, 204, 216, 149, 6, Art.PAINTED_STEEL)
	_r(out, 204, 305, 149, 6, Art.PAINTED_STEEL)
	for floor: int in range(5):
		var y: int = 141 + floor * 47
		for column: int in range(3):
			_room(out, 221 + column * 40, y, 33, 32, floor + column * 2)
		_balcony(out, 215, y + 31, 129, floor == 1)
	_facade(out, 232, 94, 104, 31, Art.PAINTED_STEEL)
	Art._vent(out, 246, 99, 27, 18)
	Art._window(out, 284, 100, 39, 17, Art.AMBER)
	_garden(out, 224, 92, 117, 9)
	_r(out, 242, 72, 54, 15, Art.CHEMICAL_GLASS)
	_r(out, 245, 74, 2, 12, Art.LEAD)
	_r(out, 266, 74, 2, 12, Art.LEAD)
	_r(out, 289, 74, 2, 12, Art.LEAD)
	_r(out, 242, 70, 54, 3, Art.VERDIGRIS)
	_dish(out, 314, 56)
	_facade(out, 366, 60, 88, 159, Art.BRICK)
	_r(out, 369, 117, 82, 4, Art.SLATE)
	_r(out, 369, 169, 82, 4, Art.SLATE)
	for floor: int in range(3):
		_room(out, 377, 72 + floor * 49, 30, 32, floor + 2)
		_room(out, 415, 72 + floor * 49, 29, 32, floor + 3)
		_balcony(out, 374, 105 + floor * 49, 73)
	_garden(out, 362, 58, 94, 13)
	_r(out, 382, 26, 42, 20, Art.SLATE)
	Art._vent(out, 389, 31, 28, 13)
	_r(out, 424, 23, 4, 29, Art.STEEL_PIPE)
	_r(out, 435, 31, 2, 26, Art.CABLE)
	_laundry(out, Vector2i(177, 208), Vector2i(214, 194), 3)
	_laundry(out, Vector2i(346, 136), Vector2i(372, 126), 2)
	# Offset air conditioners and service labels prevent uniformly tiled facades.
	for location: Vector2i in [Vector2i(175, 251), Vector2i(190, 324), Vector2i(340, 252), Vector2i(441, 148)]:
		Art._vent(out, location.x, location.y, 17, 14)
		_r(out, location.x + 3, location.y + 13, 11, 2, Art.RUSTED_STEEL)
	_r(out, 185, 263, 3, 52, Art.STEEL_PIPE)
	_r(out, 190, 339, 3, 57, Art.COPPER_PIPE)
	_text(out, "24", 65, 217, Art.AMBER)
	_text(out, "HOME", 257, 121, Art.CYAN)


static func _east_homes(out: PackedInt32Array) -> void:
	_facade(out, 720, 130, 130, 265, Art.INDUSTRIAL_BRICK)
	_facade(out, 742, 101, 89, 28, Art.SLATE)
	_garden(out, 737, 98, 98, 10)
	_dish(out, 768, 69, -1)
	_r(out, 806, 58, 5, 33, Art.STEEL_PIPE)
	_r(out, 800, 57, 16, 3, Art.LEAD)
	_r(out, 819, 68, 3, 29, Art.CABLE)
	for floor: int in range(5):
		var y: int = 145 + floor * 47
		_room(out, 731, y, 46, 32, floor + 3)
		_room(out, 789, y, 48, 32, floor + 5)
		_balcony(out, 726, y + 33, 116, floor == 2)
		if floor in [1, 3]:
			_garden(out, 801, y + 43, 30, 6)
	_r(out, 718, 188, 5, 191, Art.COPPER_PIPE)
	_r(out, 847, 154, 5, 215, Art.CABLE)
	_facade(out, 873, 272, 85, 181, Art.PAINTED_STEEL)
	_facade(out, 886, 235, 66, 37, Art.CORRUGATED)
	Art._vent(out, 896, 245, 43, 18)
	_garden(out, 881, 232, 73, 9)
	for floor: int in range(3):
		_room(out, 884, 287 + floor * 51, 29, 32, floor)
		_room(out, 920, 287 + floor * 51, 28, 32, floor + 1)
		_balcony(out, 881, 322 + floor * 51, 69, floor == 1)
	_facade(out, 647, 170, 59, 144, Art.PLASTER)
	_r(out, 651, 178, 6, 130, Art.PAINTED_STEEL)
	for floor: int in range(3):
		_room(out, 662, 183 + floor * 40, 34, 28, floor + 4)
	_garden(out, 642, 169, 69, 9)
	_dish(out, 677, 136)
	# A slender rose sign is part of a home facade rather than a machine tower.
	Art._panel(out, 855, 174, 17, 82, Art.IRON, Art.PAINTED_STEEL)
	for index: int in range(4):
		_text(out, "HOME"[index], 860, 182 + index * 17, Art.MAGENTA, 2)
	_r(out, 849, 187, 6, 2, Art.IRON)
	_r(out, 849, 240, 6, 2, Art.IRON)
	_laundry(out, Vector2i(846, 219), Vector2i(881, 231), 3)
	_laundry(out, Vector2i(697, 140), Vector2i(738, 120), 4)
	for location: Vector2i in [Vector2i(710, 216), Vector2i(836, 266), Vector2i(862, 357), Vector2i(945, 310)]:
		Art._vent(out, location.x, location.y, 17, 13)
		_r(out, location.x + 3, location.y + 13, 11, 2, Art.RUSTED_STEEL)
	_r(out, 960, 329, 3, 147, Art.STEEL_PIPE)
	_r(out, 943, 475, 20, 4, Art.STEEL_PIPE)
	_text(out, "33", 887, 267, Art.AMBER)


static func _high_walkways(out: PackedInt32Array) -> void:
	# Two offset crossings frame open air above and alongside the garden bridge.
	Art._beam(out, Vector2i(447, 187), Vector2i(650, 171), 4, Art.STEEL)
	Art._beam(out, Vector2i(448, 175), Vector2i(649, 159), 1, Art.BRONZE)
	for index: int in range(12):
		var x: int = 448 + index * 18
		var y: int = 175 - roundi(float(index) * 16.0 / 11.0)
		_r(out, x, y, 1, 12, Art.IRON)
		if index % 3 == 0:
			_r(out, x + 4, y + 15, 11, 1, Art.CYAN)
	_r(out, 460, 191, 6, 17, Art.IRON)
	_r(out, 628, 175, 6, 19, Art.IRON)
	_garden(out, 495, 181, 43, 8)
	_garden(out, 574, 174, 43, 10)
	_laundry(out, Vector2i(454, 91), Vector2i(645, 147), 8)
	Art._draped_cable(out, Vector2i(450, 216), Vector2i(648, 205), 15.0)
	# Small lamps hang at different heights; sparse amber leaves the sky dark.
	for item: Vector2i in [Vector2i(483, 239), Vector2i(557, 244), Vector2i(613, 233)]:
		_r(out, item.x, item.y - 9, 1, 10, Art.CABLE)
		_r(out, item.x - 3, item.y, 7, 2, Art.IRON)
		_r(out, item.x - 2, item.y + 2, 5, 5, Art.AMBER)
		_r(out, item.x - 3, item.y + 7, 7, 1, Art.BRONZE)
	_r(out, 175, 397, 198, 5, Art.GRATING)
	_r(out, 179, 385, 190, 1, Art.LEAD)
	for x: int in range(180, 371, 17):
		_r(out, x, 386, 1, 11, Art.IRON)
	_r(out, 183, 402, 5, 13, Art.IRON)
	_r(out, 357, 402, 5, 13, Art.IRON)


static func _garden_bridge(out: PackedInt32Array) -> void:
	# The principal landmark is a warm inhabited bridge with a planted roof,
	# overhanging balconies and stepped asymmetrical ends above the open court.
	_facade(out, 354, 269, 331, 70, Art.PAINTED_STEEL)
	_r(out, 360, 275, 318, 5, Art.VERDIGRIS)
	_r(out, 361, 327, 316, 6, Art.RUSTED_STEEL)
	for index: int in range(6):
		_room(out, 366 + index * 51, 282, 42, 36, index + 1)
		if index in [0, 2, 5]:
			_garden(out, 369 + index * 51, 334, 29, 7)
	_balcony(out, 348, 334, 343, true)
	_r(out, 372, 349, 11, 21, Art.IRON)
	_r(out, 661, 349, 11, 22, Art.IRON)
	Art._beam(out, Vector2i(378, 368), Vector2i(414, 349), 3, Art.STEEL)
	Art._beam(out, Vector2i(625, 349), Vector2i(665, 370), 3, Art.STEEL)
	_r(out, 367, 369, 28, 6, Art.SLATE)
	_r(out, 649, 370, 29, 6, Art.SLATE)
	# Roof garden: distinct raised beds, a shaded pergola, benches and a small
	# greenhouse. It is all native solid catalogue material, with no plant growth.
	_r(out, 359, 262, 324, 7, Art.CONCRETE)
	_r(out, 360, 260, 322, 3, Art.VERDIGRIS)
	_garden(out, 366, 258, 68, 14)
	_garden(out, 601, 258, 70, 17)
	_garden(out, 503, 258, 60, 8)
	_r(out, 440, 236, 53, 24, Art.CHEMICAL_GLASS)
	_r(out, 441, 234, 52, 3, Art.LEAD)
	_r(out, 443, 236, 2, 24, Art.IRON)
	_r(out, 465, 236, 2, 24, Art.IRON)
	_r(out, 489, 236, 2, 24, Art.IRON)
	_r(out, 446, 248, 40, 2, Art.LEAD)
	_garden(out, 447, 258, 34, 5)
	_r(out, 558, 220, 48, 4, Art.SLATE)
	_r(out, 561, 224, 3, 36, Art.IRON)
	_r(out, 600, 224, 3, 36, Art.IRON)
	for x: int in range(555, 610, 8):
		_r(out, x, 217, 3, 9, Art.VERDIGRIS)
	_r(out, 571, 252, 22, 3, Art.BRONZE)
	_r(out, 572, 255, 2, 5, Art.IRON)
	_r(out, 590, 255, 2, 5, Art.IRON)
	_r(out, 571, 245, 23, 2, Art.BRONZE)
	_r(out, 572, 247, 2, 5, Art.IRON)
	_r(out, 590, 247, 2, 5, Art.IRON)
	Art._panel(out, 492, 349, 61, 14, Art.BRONZE, Art.IRON)
	_text(out, "GARDEN", 499, 353, Art.AMBER)
	# Laundry is gathered near one end, leaving the central garden readable.
	_laundry(out, Vector2i(348, 230), Vector2i(429, 219), 6)
	_r(out, 354, 347, 3, 36, Art.COPPER_PIPE)
	_r(out, 681, 347, 3, 38, Art.CABLE)


static func _shop(out: PackedInt32Array, x: int, y: int, w: int, label: String,
		colour: int, variant: int) -> void:
	_facade(out, x, y, w, 103, Art.BRICK if variant % 2 else Art.PLASTER)
	Art._panel(out, x + 6, y + 6, w - 12, 19, Art.IRON, Art.PAINTED_STEEL)
	_text(out, label, x + 11, y + 12, colour, 2)
	_awning(out, x - 3, y + 29, w + 6, Art.RUSTED_STEEL if variant % 2 else Art.PAINTED_STEEL)
	Art._panel(out, x + 7, y + 47, w - 14, 50, Art.IRON, Art.DARK_GLASS)
	_r(out, x + 10, y + 51, w - 20, 1, colour)
	_r(out, x + 10, y + 81, w - 20, 10, Art.PAINTED_STEEL)
	_r(out, x + 10, y + 80, w - 20, 2, Art.PLASTER)
	for index: int in range(maxi(1, (w - 20) / 12)):
		var sx: int = x + 13 + index * 12
		_r(out, sx, y + 74 - index % 2, 7, 6 + index % 2,
			Art.INSULATION if index % 2 else Art.VERDIGRIS)
		_r(out, sx + 1, y + 71 - index % 2, 5, 3, Art.PLASTER)
		_r(out, sx + 1, y + 85, 2, 1, Art.LEAD)
	_r(out, x + w - 25, y + 48, 2, 47, Art.IRON)
	_r(out, x + w - 23, y + 71, 3, 1, Art.AMBER)
	_r(out, x + 7, y + 95, w - 14, 2, Art.SANDSTONE)
	_r(out, x + 4, y + 101, w - 8, 3, Art.SLATE)


static func _lower_shops(out: PackedInt32Array) -> void:
	# Shopfronts and occupied alcoves frame the court, with short doors beneath
	# taller homes rather than a continuous wall across the whole lower level.
	_shop(out, 204, 407, 90, "TEA", Art.AMBER, 1)
	_shop(out, 308, 407, 79, "RAMEN", Art.MAGENTA, 0)
	_shop(out, 686, 407, 82, "ARCADE", Art.CYAN, 1)
	_shop(out, 785, 407, 78, "BREAD", Art.AMBER, 0)
	# Small porch beneath the west apartments surrounds the safe spawn arcade.
	_r(out, 65, 452, 115, 8, Art.CONCRETE)
	_r(out, 67, 460, 8, 50, Art.BRICK)
	_r(out, 173, 460, 8, 50, Art.BRICK)
	_r(out, 79, 453, 86, 2, Art.AMBER)
	_r(out, 61, 505, 20, 5, Art.SLATE)
	_r(out, 54, 501, 17, 9, Art.SLATE)
	# The narrow east kiosk has a roll-up shutter and a planter roof.
	_facade(out, 886, 461, 69, 49, Art.CORRUGATED)
	Art._panel(out, 896, 469, 46, 37, Art.IRON, Art.GRATING)
	_r(out, 901, 474, 37, 2, Art.AMBER)
	_garden(out, 881, 459, 78, 11)
	_text(out, "09", 913, 496, Art.WHITE)
	for item: Vector2i in [Vector2i(194, 490), Vector2i(392, 493), Vector2i(872, 491)]:
		_r(out, item.x, item.y, 8, 19, Art.PAINTED_STEEL)
		_r(out, item.x - 1, item.y, 10, 2, Art.LEAD)
		_r(out, item.x + 2, item.y + 5, 4, 2, Art.RUBBER)


static func _courtyard(out: PackedInt32Array) -> void:
	# Open stairs, benches and a shallow watering basin keep the focal court
	# materially interesting while preserving substantial dark open air.
	_r(out, 406, 502, 257, 8, Art.WET_COBBLE)
	_r(out, 423, 496, 220, 6, Art.SANDSTONE)
	for step: int in range(6):
		_r(out, 391 + step * 5, 496 - step * 9, 6, 6, Art.SLATE)
		_r(out, 641 + step * 5, 451 + step * 9, 6, 6, Art.SLATE)
	Art._beam(out, Vector2i(392, 492), Vector2i(421, 439), 1, Art.BRONZE)
	Art._beam(out, Vector2i(642, 439), Vector2i(671, 492), 1, Art.BRONZE)
	_r(out, 419, 438, 20, 5, Art.STEEL)
	_r(out, 627, 438, 20, 5, Art.STEEL)
	_r(out, 427, 379, 6, 60, Art.IRON)
	_r(out, 634, 379, 5, 60, Art.IRON)
	_r(out, 420, 378, 21, 4, Art.LEAD)
	_r(out, 627, 378, 19, 4, Art.LEAD)
	_garden(out, 414, 424, 31, 12)
	_garden(out, 623, 424, 33, 9)
	# Central shallow native Water, contained by a weathered stone trough.
	_r(out, 477, 480, 102, 26, Art.GRANITE)
	_r(out, 481, 483, 94, 20, Art.CHEMICAL_GLASS)
	_r(out, 485, 487, 86, 15, Art.WATER)
	_r(out, 478, 504, 100, 4, Art.VERDIGRIS)
	_r(out, 477, 478, 102, 3, Art.SANDSTONE)
	_r(out, 478, 474, 9, 5, Art.MOSS_STONE)
	_r(out, 568, 472, 11, 7, Art.MOSS_STONE)
	_r(out, 481, 481, 3, 22, Art.SLATE)
	_r(out, 573, 481, 3, 22, Art.SLATE)
	# Benches, small circular stools and precisely placed warm pendant lights.
	for x: int in [436, 591]:
		_r(out, x, 480, 28, 3, Art.BRONZE)
		_r(out, x + 2, 483, 3, 13, Art.IRON)
		_r(out, x + 22, 483, 3, 13, Art.IRON)
		_r(out, x, 468, 28, 3, Art.BRONZE)
		_r(out, x + 2, 471, 2, 9, Art.IRON)
		_r(out, x + 23, 471, 2, 9, Art.IRON)
	_garden(out, 446, 465, 27, 13)
	_garden(out, 590, 461, 31, 14)
	Art._draped_cable(out, Vector2i(388, 374), Vector2i(672, 368), 27.0)
	for item: Vector2i in [Vector2i(452, 399), Vector2i(578, 399), Vector2i(630, 389)]:
		_r(out, item.x, item.y - 7, 1, 8, Art.CABLE)
		_r(out, item.x - 3, item.y, 7, 2, Art.BRONZE)
		_r(out, item.x - 2, item.y + 2, 5, 5, Art.AMBER)
		_r(out, item.x - 3, item.y + 7, 7, 1, Art.IRON)
	# A single asymmetric pendant is an independent, stable scene landmark.
	_r(out, 513, 364, 1, 10, Art.CABLE)
	_r(out, 509, 373, 9, 2, Art.IRON)
	_r(out, 512, 375, 3, 6, Art.AMBER)
	_r(out, 509, 381, 9, 1, Art.BRONZE)


static func _residential_services(out: PackedInt32Array) -> void:
	# Visible exterior services follow buildings, rather than filling the sky
	# with arbitrary detail. Their routes turn and terminate at actual facades.
	_r(out, 49, 280, 5, 214, Art.STEEL_PIPE)
	_r(out, 50, 492, 18, 4, Art.STEEL_PIPE)
	for y: int in range(297, 491, 38):
		_r(out, 47, y, 9, 3, Art.LEAD)
	_r(out, 197, 151, 4, 228, Art.COPPER_PIPE)
	_r(out, 183, 376, 18, 4, Art.COPPER_PIPE)
	_r(out, 354, 153, 3, 192, Art.CABLE)
	_r(out, 707, 229, 4, 166, Art.COPPER_PIPE)
	_r(out, 697, 392, 16, 4, Art.COPPER_PIPE)
	_r(out, 865, 281, 4, 119, Art.STEEL_PIPE)
	_r(out, 864, 398, 23, 4, Art.STEEL_PIPE)
	for x: int in [62, 211, 315, 698, 796, 900]:
		_r(out, x, 522, 24, 5, Art.RUBBER)
		_r(out, x + 2, 527, 3, 6, Art.CABLE)
		_r(out, x + 19, 527, 3, 4, Art.CABLE)
	# House numbers and doorbells are sparse finishing details on existing mass.
	for index: int in range(5):
		var y: int = 153 + index * 47
		_text(out, str(index + 1), 210, y, Art.BRONZE)
		_r(out, 214, y + 8, 2, 3, Art.AMBER)
		_text(out, str(index + 5), 840, y, Art.BRONZE)
		_r(out, 840, y + 8, 2, 3, Art.MAGENTA if index == 1 else Art.LEAD)
	# A small row of utility cabinets sits beside the lower court, with no new
	# electrical behavior implied by their labels or lights.
	for index: int in range(3):
		var x: int = 393 + index * 13
		Art._panel(out, x, 452, 11, 29, Art.IRON, Art.PAINTED_STEEL)
		_r(out, x + 3, 456, 5, 2, Art.CYAN if index == 1 else Art.AMBER)
		_r(out, x + 3, 464, 5, 1, Art.LEAD)
		_r(out, x + 3, 469, 5, 1, Art.LEAD)
		_r(out, x + 8, 476, 1, 2, Art.BRONZE)
