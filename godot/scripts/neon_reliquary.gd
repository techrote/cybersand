class_name CyberNeonReliquary
extends RefCounted

# An authored scene made entirely from ordinary native material cells. The
# constructor has no timers, persistent emitters or special material behavior.
# Shape helpers emit bounded, deterministic setup rectangles; Empty is a real
# opening, and all decorative finishes retain their catalogue collision rules.
const ID: String = "neon_reliquary"
const SCENARIO_ID: String = "showcase/neon-reliquary"
const VERSION: int = 1
const TITLE: String = "Neon Reliquary"
const Contract = preload("res://scripts/microscenario_contract.gd")

const EMPTY: int = 0
const WALL: int = 1
const WATER: int = 3
const LIMESTONE: int = 38
const SANDSTONE: int = 39
const GRANITE: int = 40
const MOSS_STONE: int = 42
const BRICK: int = 43
const PLASTER: int = 44
const SLATE: int = 49
const IRON: int = 50
const LEAD: int = 51
const BRONZE: int = 52
const VERDIGRIS: int = 54
const STAINED_GLASS: int = 55
const INDUSTRIAL_BRICK: int = 57
const CONCRETE: int = 58
const ASPHALT: int = 59
const WET_ASPHALT: int = 60
const WET_COBBLE: int = 61
const STEEL: int = 62
const PAINTED_STEEL: int = 63
const CORRUGATED: int = 64
const RUSTED_STEEL: int = 65
const GRATING: int = 66
const CHAINLINK: int = 67
const STEEL_PIPE: int = 68
const COPPER_PIPE: int = 69
const TILE: int = 70
const CHEMICAL_GLASS: int = 71
const DARK_GLASS: int = 72
const RUBBER: int = 73
const CABLE: int = 74
const INSULATION: int = 75
const HAZARD: int = 76
const CYAN: int = 77
const MAGENTA: int = 78
const AMBER: int = 79
const WHITE: int = 80

const GLYPHS: Dictionary = {
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"3": ["111", "001", "111", "001", "111"],
	"9": ["111", "101", "111", "001", "111"],
	"A": ["010", "101", "111", "101", "101"],
	"C": ["111", "100", "100", "100", "111"],
	"E": ["111", "100", "110", "100", "111"],
	"I": ["111", "010", "010", "010", "111"],
	"L": ["100", "100", "100", "100", "111"],
	"N": ["101", "111", "111", "111", "101"],
	"Q": ["111", "101", "101", "111", "001"],
	"R": ["110", "101", "110", "101", "101"],
	"T": ["111", "010", "010", "010", "010"],
	"U": ["101", "101", "101", "101", "111"],
	"V": ["101", "101", "101", "101", "010"],
	"X": ["101", "101", "010", "101", "101"],
	"-": ["000", "000", "111", "000", "000"],
}


static func spawn() -> Vector2:
	return Vector2(88, 488)


static func viewpoints() -> Array[Dictionary]:
	return [
		{"name": "The whole reliquary", "origin": Vector2(32, 16), "size": Vector2i(960, 540)},
		{"name": "The suspended heart", "origin": Vector2(272, 96), "size": Vector2i(480, 270)},
		{"name": "The drowned nave", "origin": Vector2(272, 286), "size": Vector2i(480, 270)},
		{"name": "West service quarter", "origin": Vector2(32, 88), "size": Vector2i(480, 270)},
		{"name": "The broken crown", "origin": Vector2(272, 16), "size": Vector2i(480, 270)},
	]


static func definition(seed: int = 0) -> Dictionary:
	var out: Dictionary = Contract.base(SCENARIO_ID, VERSION, seed)
	out.schema_version = 2
	out.rectangles = Array(rectangles())
	out.player_start = [int(spawn().x), int(spawn().y)]
	out.camera_origin = [32, 16]
	out.player_enabled = true
	out.body_enabled = false
	out.tools = ["paint", "erase", "player"]
	# Fixed interest includes the entire composition when viewing one detail.
	# Existing Baseline transport, Water8/coherence12 and owner cadence remain.
	out.interest = {"policy": "fixed", "region": [32, 16, 960, 540]}
	out["presentation"] = {
		"title": TITLE,
		"instructions": "A suspended cyan engine inside a ruined industrial cathedral. "
			+ "Explore its service quarter, stained glass, carved crown and flooded undercroft. "
			+ "Starts paused; P resumes the ordinary materials, R restores the authored scene, "
			+ "arrow keys pan and F8 gives a clean view. Paint and erase are available. "
			+ "The scene is an aesthetic showcase, with no objectives or physics qualification.",
		"duration_ticks": 600,
		"baseline": "Current native materials / Baseline transport / Water8-coherence12",
		"profile": "Neon Reliquary / authored composition v1",
		"regions": [],
	}
	out.source_recipe = "CyberNeonReliquary/v1"
	out.source_recipe_hash = JSON.stringify(out.rectangles).sha256_text()
	return out


static func rectangles() -> PackedInt32Array:
	var out := PackedInt32Array()
	_rect(out, 0, 0, 1024, 1, WALL)
	_rect(out, 0, 1, 1, 1023, WALL)
	_rect(out, 1023, 1, 1, 1023, WALL)
	_rect(out, 1, 1023, 1022, 1, WALL)
	_foundation(out)
	_west_quarter(out)
	_east_quarter(out)
	_cathedral(out)
	_nave_services(out)
	_halo(out)
	_foreground(out)
	# Keep the initial actor entirely clear even where facade layers overlap.
	_rect(out, 76, 462, 96, 48, EMPTY)
	_rect(out, 70, 510, 110, 5, WET_COBBLE)
	return out


static func _rect(out: PackedInt32Array, x: int, y: int, w: int, h: int, material: int) -> void:
	if w > 0 and h > 0:
		out.append_array(PackedInt32Array([x, y, w, h, material]))


static func _panel(out: PackedInt32Array, x: int, y: int, w: int, h: int,
		shell: int, face: int) -> void:
	_rect(out, x, y, w, h, shell)
	_rect(out, x + 2, y + 2, w - 4, h - 4, face)


static func _rivet_row(out: PackedInt32Array, x: int, y: int, length: int,
		spacing: int = 12, material: int = LEAD) -> void:
	for offset: int in range(3, length - 2, spacing):
		_rect(out, x + offset, y, 2, 2, material)


static func _vent(out: PackedInt32Array, x: int, y: int, w: int, h: int) -> void:
	_panel(out, x, y, w, h, STEEL, RUBBER)
	for row: int in range(y + 4, y + h - 2, 4):
		_rect(out, x + 3, row, w - 6, 1, LEAD)


static func _window(out: PackedInt32Array, x: int, y: int, w: int, h: int,
		light: int = AMBER) -> void:
	_panel(out, x, y, w, h, IRON, DARK_GLASS)
	_rect(out, x + 3, y + 3, w - 6, 1, light)
	_rect(out, x + w / 2, y + 2, 1, h - 4, IRON)
	_rect(out, x + 2, y + h - 4, w - 4, 2, SLATE)


static func _lancet(out: PackedInt32Array, x: int, y: int, w: int, h: int) -> void:
	var half: int = w / 2
	_rect(out, x, y + half, w, h - half, GRANITE)
	_rect(out, x + 3, y + half, w - 6, h - half - 3, STAINED_GLASS)
	for step: int in range(half):
		_rect(out, x + half - step, y + step, 2 * step + 1, 1, GRANITE)
		if step > 4:
			_rect(out, x + half - step + 3, y + step, 2 * step - 5, 1, STAINED_GLASS)
	_rect(out, x + half, y + 6, 1, h - 9, IRON)
	for row: int in range(y + half + 9, y + h - 4, 13):
		_rect(out, x + 3, row, w - 6, 1, IRON)
	_rect(out, x + 2, y + h - 1, w - 4, 3, SANDSTONE)


static func _beam(out: PackedInt32Array, from: Vector2i, to: Vector2i,
		thickness: int, material: int) -> void:
	# Runs along the major axis keep diagonal edges pixel precise without
	# emitting a separate construction command for every pixel in the beam.
	var delta: Vector2i = to - from
	var horizontal: bool = absi(delta.x) >= absi(delta.y)
	var count: int = absi(delta.x) if horizontal else absi(delta.y)
	if count == 0:
		_rect(out, from.x, from.y, thickness, thickness, material)
		return
	var run_start: Vector2i = from
	var previous: Vector2i = from
	var run_length: int = 1
	for index: int in range(1, count + 1):
		var point: Vector2i = Vector2i(Vector2(from).lerp(Vector2(to), float(index) / float(count)).round())
		if (point.y == previous.y if horizontal else point.x == previous.x):
			run_length += 1
		else:
			_rect(out, mini(run_start.x, previous.x), mini(run_start.y, previous.y),
				run_length if horizontal else thickness,
				thickness if horizontal else run_length, material)
			run_start = point
			run_length = 1
		previous = point
	_rect(out, mini(run_start.x, previous.x), mini(run_start.y, previous.y),
		run_length if horizontal else thickness,
		thickness if horizontal else run_length, material)


static func _draped_cable(out: PackedInt32Array, from: Vector2i, to: Vector2i,
		sag: float) -> void:
	var previous: Vector2i = from
	for segment: int in range(1, 9):
		var t: float = float(segment) / 8.0
		var point: Vector2 = Vector2(from).lerp(Vector2(to), t)
		point.y += 4.0 * t * (1.0 - t) * sag
		var next: Vector2i = Vector2i(point.round())
		_beam(out, previous, next, 1, CABLE)
		previous = next
	_rect(out, from.x - 2, from.y - 2, 5, 4, IRON)
	_rect(out, to.x - 2, to.y - 2, 5, 4, IRON)


static func _ring(out: PackedInt32Array, cx: int, cy: int, radius: int,
		thickness: int, material: int) -> void:
	var inner: int = maxi(0, radius - thickness)
	for y: int in range(-radius, radius + 1):
		var outer_x: int = floori(sqrt(float(radius * radius - y * y)))
		if absi(y) >= inner:
			_rect(out, cx - outer_x, cy + y, 2 * outer_x + 1, 1, material)
		else:
			var inner_x: int = floori(sqrt(float(inner * inner - y * y)))
			_rect(out, cx - outer_x, cy + y, outer_x - inner_x, 1, material)
			_rect(out, cx + inner_x + 1, cy + y, outer_x - inner_x, 1, material)


static func _disc(out: PackedInt32Array, cx: int, cy: int, radius: int, material: int) -> void:
	for y: int in range(-radius, radius + 1):
		var half: int = floori(sqrt(float(radius * radius - y * y)))
		_rect(out, cx - half, cy + y, 2 * half + 1, 1, material)


static func _arch(out: PackedInt32Array, cx: int, spring_y: int,
		radius: int, height: int, thickness: int, material: int) -> void:
	var inner_radius: int = radius - thickness
	var inner_height: int = height - thickness
	for y: int in range(-height, 1):
		var outer_x: int = floori(float(radius) * sqrt(maxf(0.0, 1.0 - pow(float(y) / float(height), 2.0))))
		if y <= -inner_height:
			_rect(out, cx - outer_x, spring_y + y, 2 * outer_x + 1, 1, material)
		else:
			var inner_x: int = floori(float(inner_radius) * sqrt(maxf(0.0, 1.0 - pow(float(y) / float(inner_height), 2.0))))
			_rect(out, cx - outer_x, spring_y + y, outer_x - inner_x, 1, material)
			_rect(out, cx + inner_x + 1, spring_y + y, outer_x - inner_x, 1, material)


static func _text(out: PackedInt32Array, text: String, x: int, y: int,
		material: int, scale: int = 1) -> void:
	var cursor: int = x
	for character: String in text:
		if not GLYPHS.has(character):
			cursor += 4 * scale
			continue
		var glyph: Array = GLYPHS[character]
		for row: int in range(5):
			var column: int = 0
			while column < 3:
				if glyph[row][column] == "0":
					column += 1
					continue
				var start: int = column
				while column < 3 and glyph[row][column] == "1":
					column += 1
				_rect(out, cursor + start * scale, y + row * scale,
					(column - start) * scale, scale, material)
		cursor += 4 * scale


static func _foundation(out: PackedInt32Array) -> void:
	_rect(out, 46, 510, 930, 12, WET_COBBLE)
	_rect(out, 42, 522, 938, 34, GRANITE)
	_rect(out, 50, 529, 922, 27, INDUSTRIAL_BRICK)
	_rect(out, 50, 550, 922, 6, WET_ASPHALT)
	# Recessed service vaults create a cutaway foreground and a dark bottom edge.
	for index: int in range(11):
		var x: int = 65 + index * 83
		_panel(out, x, 533, 62, 18, SLATE, EMPTY)
		_rect(out, x + 3, 546, 55, 3, STEEL_PIPE)
		_rect(out, x + 13, 535, 2, 11, IRON)
		_rect(out, x + 46, 535, 2, 11, IRON)
	_rect(out, 51, 521, 919, 2, LEAD)
	_rivet_row(out, 48, 518, 923, 31, IRON)
	# The lower basin is a real contained Water volume, with an empty headspace.
	_rect(out, 332, 440, 360, 70, GRANITE)
	_rect(out, 338, 445, 348, 61, CONCRETE)
	_rect(out, 342, 447, 340, 57, EMPTY)
	_rect(out, 342, 462, 340, 42, WATER)
	_rect(out, 334, 440, 356, 3, VERDIGRIS)
	_rect(out, 340, 505, 344, 3, CONCRETE)
	_rect(out, 350, 508, 324, 2, MOSS_STONE)


static func _west_quarter(out: PackedInt32Array) -> void:
	# High asymmetrical service stack, cut into several readable masses.
	_rect(out, 72, 168, 94, 287, INDUSTRIAL_BRICK)
	_rect(out, 94, 105, 70, 63, CORRUGATED)
	_rect(out, 111, 72, 45, 35, RUSTED_STEEL)
	_rect(out, 117, 63, 33, 9, SLATE)
	_rect(out, 126, 40, 6, 23, STEEL_PIPE)
	_rect(out, 139, 53, 4, 14, COPPER_PIPE)
	_rect(out, 94, 104, 73, 4, STEEL)
	_rect(out, 68, 165, 107, 7, SLATE)
	_rect(out, 69, 172, 4, 283, IRON)
	_rect(out, 156, 174, 9, 260, RUSTED_STEEL)
	_rect(out, 73, 297, 90, 7, STEEL)
	_rect(out, 73, 375, 90, 8, SLATE)
	_rect(out, 74, 439, 103, 8, CONCRETE)
	_vent(out, 119, 80, 28, 21)
	_vent(out, 103, 121, 43, 30)
	for level: int in range(4):
		var y: int = 186 + level * 47
		_window(out, 84, y, 28, 29, AMBER if level % 2 == 0 else CYAN)
		_window(out, 120, y, 24, 29, CYAN)
		_rect(out, 80, y + 32, 69, 3, LEAD)
	_rect(out, 92, 400, 51, 34, CORRUGATED)
	_rect(out, 97, 407, 3, 20, HAZARD)
	_rect(out, 138, 405, 2, 28, IRON)
	# The smaller shop hangs in front of the stack, with an open arcade below.
	_rect(out, 170, 245, 113, 156, BRICK)
	_rect(out, 179, 226, 78, 19, VERDIGRIS)
	_rect(out, 191, 214, 50, 13, SLATE)
	_rect(out, 174, 248, 104, 5, SANDSTONE)
	_rect(out, 174, 310, 104, 6, STEEL)
	_rect(out, 174, 364, 104, 6, CONCRETE)
	_window(out, 183, 262, 37, 36, AMBER)
	_window(out, 232, 262, 37, 36, AMBER)
	_panel(out, 185, 326, 82, 29, IRON, DARK_GLASS)
	_text(out, "LUX", 196, 333, AMBER, 3)
	_rect(out, 181, 376, 88, 17, GRATING)
	_rect(out, 171, 399, 113, 9, RUSTED_STEEL)
	_rect(out, 174, 408, 10, 102, GRANITE)
	_rect(out, 270, 408, 12, 102, GRANITE)
	_rect(out, 184, 408, 85, 5, LEAD)
	_rect(out, 185, 444, 82, 5, STEEL)
	_panel(out, 202, 416, 39, 20, STEEL, RUBBER)
	_text(out, "09", 211, 422, CYAN)
	_rect(out, 191, 458, 60, 49, STEEL)
	_rect(out, 195, 462, 52, 42, CHEMICAL_GLASS)
	_rect(out, 200, 473, 42, 28, WATER)
	_rect(out, 196, 465, 2, 37, CYAN)
	_rect(out, 224, 460, 3, 43, IRON)
	# Conduits turn at authored joints, distinct from decorative window grids.
	_rect(out, 59, 189, 6, 242, STEEL_PIPE)
	_rect(out, 59, 427, 34, 6, STEEL_PIPE)
	_rect(out, 89, 427, 4, 29, COPPER_PIPE)
	_rect(out, 167, 120, 5, 195, COPPER_PIPE)
	_rect(out, 166, 119, 58, 5, COPPER_PIPE)
	_rect(out, 220, 119, 5, 104, COPPER_PIPE)
	for y: int in [195, 248, 303, 360, 414]:
		_rect(out, 57, y, 10, 4, LEAD)
	_rect(out, 178, 124, 16, 20, PAINTED_STEEL)
	_rect(out, 181, 129, 10, 2, CYAN)
	_rect(out, 181, 135, 7, 2, WHITE)
	# West landing is intentionally dry and leaves generous actor headroom.
	_rect(out, 68, 450, 111, 9, CONCRETE)
	_rect(out, 68, 459, 7, 51, GRANITE)
	_rect(out, 171, 459, 8, 51, GRANITE)
	_rect(out, 77, 452, 83, 2, CYAN)
	_rect(out, 46, 504, 27, 6, SLATE)
	_rect(out, 48, 498, 23, 6, SLATE)
	_rect(out, 51, 492, 19, 6, SLATE)


static func _east_quarter(out: PackedInt32Array) -> void:
	# A taller glass chapel contrasts with the brick west. The broken roof and
	# offset balcony deliberately avoid a mirrored composition.
	_rect(out, 772, 139, 81, 274, GRANITE)
	_rect(out, 763, 128, 99, 12, SLATE)
	_rect(out, 783, 94, 59, 34, PAINTED_STEEL)
	_rect(out, 797, 78, 23, 18, STEEL)
	_rect(out, 805, 48, 5, 34, IRON)
	_rect(out, 796, 69, 23, 3, CYAN)
	_rect(out, 787, 94, 50, 4, LEAD)
	_vent(out, 790, 102, 40, 19)
	_lancet(out, 784, 153, 27, 83)
	_lancet(out, 817, 153, 25, 83)
	_rect(out, 771, 244, 84, 7, STEEL)
	_rect(out, 778, 253, 68, 5, CYAN)
	_panel(out, 784, 271, 54, 69, RUSTED_STEEL, DARK_GLASS)
	_rect(out, 792, 281, 4, 44, MAGENTA)
	_rect(out, 800, 281, 28, 2, MAGENTA)
	_text(out, "NIX", 802, 294, MAGENTA, 2)
	_rect(out, 800, 318, 27, 1, WHITE)
	_rect(out, 765, 347, 99, 9, LEAD)
	_rect(out, 769, 356, 88, 4, GRATING)
	_rect(out, 776, 373, 70, 25, INDUSTRIAL_BRICK)
	_window(out, 786, 376, 18, 18, CYAN)
	_window(out, 815, 376, 21, 18, AMBER)
	# Broad low annex with several nested roofs and deep, dark machinery bays.
	_rect(out, 858, 232, 91, 214, CORRUGATED)
	_rect(out, 869, 215, 66, 17, SLATE)
	_rect(out, 881, 177, 11, 38, RUSTED_STEEL)
	_rect(out, 880, 174, 13, 5, STEEL)
	_rect(out, 922, 194, 6, 21, STEEL_PIPE)
	_rect(out, 858, 232, 91, 6, STEEL)
	_panel(out, 872, 249, 65, 60, IRON, WET_ASPHALT)
	_vent(out, 881, 259, 48, 37)
	_rect(out, 863, 321, 80, 6, STEEL)
	_window(out, 872, 338, 25, 31, AMBER)
	_window(out, 909, 338, 25, 31, CYAN)
	_rect(out, 862, 382, 84, 8, SLATE)
	_panel(out, 872, 401, 57, 34, STEEL, GRATING)
	_rect(out, 894, 403, 5, 29, IRON)
	_rect(out, 854, 446, 101, 10, RUSTED_STEEL)
	_rect(out, 859, 456, 10, 54, CONCRETE)
	_rect(out, 937, 456, 12, 54, CONCRETE)
	_rect(out, 867, 470, 67, 40, DARK_GLASS)
	_rect(out, 874, 477, 53, 3, COPPER_PIPE)
	_rect(out, 903, 480, 4, 30, COPPER_PIPE)
	_rect(out, 944, 299, 6, 145, COPPER_PIPE)
	_rect(out, 907, 297, 43, 6, COPPER_PIPE)
	_rect(out, 955, 369, 5, 138, CABLE)
	_rect(out, 842, 145, 5, 179, CABLE)
	for y: int in [155, 204, 266, 313]:
		_rect(out, 840, y, 9, 4, LEAD)
	_rect(out, 764, 405, 91, 10, CONCRETE)
	_rect(out, 771, 415, 11, 95, GRANITE)
	_rect(out, 842, 415, 12, 95, GRANITE)
	_panel(out, 796, 428, 35, 68, STEEL, CHEMICAL_GLASS)
	_rect(out, 800, 436, 3, 47, CYAN)
	_rect(out, 809, 441, 13, 39, DARK_GLASS)
	_rect(out, 807, 460, 17, 2, WHITE)
	_rect(out, 794, 497, 39, 8, HAZARD)
	# Skinny suspended utility sign, subordinate to the central halo.
	_rect(out, 743, 182, 18, 95, IRON)
	_rect(out, 746, 186, 12, 85, PAINTED_STEEL)
	_text(out, "I", 749, 194, MAGENTA, 2)
	_text(out, "I", 749, 215, MAGENTA, 2)
	_text(out, "I", 749, 236, MAGENTA, 2)
	_rect(out, 752, 174, 2, 8, CABLE)
	_rect(out, 756, 273, 2, 17, CABLE)


static func _cathedral(out: PackedInt32Array) -> void:
	# One monumental elliptical arch, with individual voussoirs and a broken
	# crown. Its generous empty nave gives the circular machinery breathing room.
	_arch(out, 512, 247, 204, 211, 14, GRANITE)
	_arch(out, 512, 247, 181, 189, 3, BRONZE)
	for index: int in range(13):
		var angle: float = PI + float(index) * PI / 12.0
		var x: int = roundi(512.0 + 197.0 * cos(angle))
		var y: int = roundi(247.0 + 204.0 * sin(angle))
		_rect(out, x - 3, y - 3, 6, 6, SANDSTONE)
	# The heavy base and pilasters have contiguous occupancy despite many finishes.
	for x: int in [300, 696]:
		_rect(out, x, 242, 28, 190, GRANITE)
		_rect(out, x + 5, 251, 17, 171, INDUSTRIAL_BRICK)
		_rect(out, x + 4, 250, 3, 176, LEAD)
		_rect(out, x + 22, 250, 3, 176, IRON)
		_rect(out, x - 5, 239, 38, 10, SANDSTONE)
		_rect(out, x - 2, 289, 32, 7, SLATE)
		_rect(out, x - 2, 358, 32, 7, SLATE)
		_rect(out, x - 8, 422, 44, 15, CONCRETE)
		_rect(out, x - 12, 437, 52, 6, VERDIGRIS)
		_rect(out, x + 10, 308, 2, 26, CYAN)
		_rivet_row(out, x - 7, 430, 40, 11, IRON)
	# Shoulder chapels and flying buttresses anchor the circular visual weight.
	for x: int in [339, 654]:
		_rect(out, x - 6, 299, 40, 109, SLATE)
		_lancet(out, x, 303, 28, 69)
		_rect(out, x - 9, 399, 46, 9, GRANITE)
		_rect(out, x + 7, 379, 13, 13, BRONZE)
	_beam(out, Vector2i(258, 289), Vector2i(307, 354), 10, GRANITE)
	_beam(out, Vector2i(270, 289), Vector2i(308, 339), 3, SANDSTONE)
	_beam(out, Vector2i(713, 347), Vector2i(765, 272), 10, GRANITE)
	_beam(out, Vector2i(721, 335), Vector2i(759, 280), 3, LEAD)
	_rect(out, 247, 285, 22, 18, SLATE)
	_rect(out, 755, 268, 23, 18, SLATE)
	# Short ribs and keystones have deliberately different damage on each side.
	_rect(out, 484, 31, 18, 27, GRANITE)
	_rect(out, 490, 26, 7, 5, SANDSTONE)
	_rect(out, 512, 24, 14, 34, SLATE)
	_rect(out, 527, 36, 12, 20, GRANITE)
	_rect(out, 493, 49, 40, 4, BRONZE)
	_rect(out, 508, 46, 5, 13, CYAN)
	_rect(out, 503, 36, 9, 8, EMPTY)
	_rect(out, 538, 45, 8, 6, EMPTY)
	_rect(out, 394, 78, 13, 7, EMPTY)
	_rect(out, 644, 101, 13, 5, EMPTY)
	_rect(out, 656, 105, 7, 6, EMPTY)
	# Lost trim and staggered chipped stone reveal an asymmetric fracture line.
	_rect(out, 616, 70, 7, 4, EMPTY)
	_rect(out, 620, 74, 5, 7, EMPTY)
	_rect(out, 624, 78, 5, 5, EMPTY)
	_rect(out, 618, 93, 9, 6, EMPTY)
	_rect(out, 627, 98, 6, 3, EMPTY)
	_rect(out, 607, 75, 4, 2, LIMESTONE)
	_rect(out, 630, 83, 5, 3, SANDSTONE)
	# The suspended heart hangs from narrow steel lines rather than a filled wall.
	_rect(out, 472, 94, 3, 44, CABLE)
	_rect(out, 551, 94, 3, 43, CABLE)
	_rect(out, 498, 75, 29, 10, IRON)
	_rect(out, 509, 84, 6, 34, STEEL_PIPE)
	_rect(out, 502, 103, 20, 7, BRONZE)
	_beam(out, Vector2i(366, 193), Vector2i(424, 197), 4, IRON)
	_beam(out, Vector2i(600, 197), Vector2i(658, 183), 4, IRON)
	_rect(out, 363, 188, 8, 14, STEEL)
	_rect(out, 653, 177, 8, 14, STEEL)
	_draped_cable(out, Vector2i(172, 146), Vector2i(338, 143), 20.0)
	_draped_cable(out, Vector2i(655, 262), Vector2i(773, 240), 18.0)
	_draped_cable(out, Vector2i(366, 306), Vector2i(448, 309), 12.0)


static func _nave_services(out: PackedInt32Array) -> void:
	# An interrupted upper service route sits behind the central machinery.
	_rect(out, 185, 183, 137, 7, STEEL)
	_rect(out, 187, 172, 133, 2, LEAD)
	for x: int in range(190, 319, 22):
		_rect(out, x, 173, 2, 10, IRON)
	_rect(out, 687, 321, 85, 7, GRATING)
	_rect(out, 689, 310, 80, 2, LEAD)
	for x: int in range(694, 768, 18):
		_rect(out, x, 312, 2, 9, IRON)
	_rect(out, 367, 397, 290, 8, IRON)
	_rect(out, 373, 397, 278, 2, LEAD)
	_rect(out, 376, 404, 10, 36, GRANITE)
	_rect(out, 638, 404, 10, 36, GRANITE)
	_rect(out, 380, 436, 73, 7, GRATING)
	_rect(out, 574, 436, 67, 7, GRATING)
	_rect(out, 449, 428, 129, 8, STEEL)
	_rect(out, 461, 435, 106, 7, SLATE)
	_rect(out, 488, 442, 48, 14, GRANITE)
	_rect(out, 492, 451, 40, 4, BRONZE)
	_rect(out, 502, 452, 20, 8, CHEMICAL_GLASS)
	# Under-altar support and dim engraved nameplate; the cyan core stays dominant.
	_rect(out, 478, 317, 68, 62, IRON)
	_rect(out, 486, 316, 52, 62, PAINTED_STEEL)
	_rect(out, 497, 321, 30, 51, DARK_GLASS)
	_rect(out, 508, 323, 8, 49, CHEMICAL_GLASS)
	_rect(out, 511, 326, 2, 40, CYAN)
	_rect(out, 472, 370, 80, 12, BRONZE)
	_rect(out, 480, 373, 65, 8, IRON)
	_text(out, "RELIQUARY", 484, 375, SANDSTONE)
	_rect(out, 484, 382, 56, 16, STEEL)
	_rect(out, 490, 385, 44, 8, GRATING)
	# Two sealed vertical Water cells serve as process gauges, without emitters.
	for x: int in [324, 680]:
		_rect(out, x, 362, 19, 67, STEEL)
		_rect(out, x + 3, 366, 13, 58, CHEMICAL_GLASS)
		_rect(out, x + 5, 388, 9, 34, WATER)
		_rect(out, x + 2, 366, 1, 53, CYAN)
		_rect(out, x - 3, 361, 25, 5, LEAD)
		_rect(out, x - 3, 424, 25, 6, RUSTED_STEEL)
	_rect(out, 287, 390, 6, 113, COPPER_PIPE)
	_rect(out, 289, 497, 44, 6, COPPER_PIPE)
	_rect(out, 730, 360, 7, 145, STEEL_PIPE)
	_rect(out, 696, 499, 39, 6, STEEL_PIPE)
	_rect(out, 281, 460, 18, 15, PAINTED_STEEL)
	_rect(out, 285, 464, 10, 2, AMBER)
	_rect(out, 725, 453, 17, 14, RUSTED_STEEL)
	_rect(out, 729, 457, 9, 2, CYAN)
	# Fine steps descend to each side of the cistern and are actual empty access.
	for step: int in range(7):
		_rect(out, 288 + step * 6, 510 - step * 8, 6, step * 8 + 1, SLATE)
		_rect(out, 692 + step * 6, 462 + step * 8, 6, 49 - step * 8, SLATE)


static func _halo(out: PackedInt32Array) -> void:
	# Successive fine rings, staggered tabs and radial marks form a readable
	# engraved machine at overview scale and resolve into detail close up.
	_ring(out, 512, 216, 96, 10, GRANITE)
	_ring(out, 512, 216, 90, 4, BRONZE)
	_ring(out, 512, 216, 82, 2, CYAN)
	_ring(out, 512, 216, 76, 5, IRON)
	_ring(out, 512, 216, 69, 2, VERDIGRIS)
	_disc(out, 512, 216, 63, DARK_GLASS)
	_disc(out, 512, 216, 46, CHEMICAL_GLASS)
	for index: int in range(12):
		var angle: float = float(index) * TAU / 12.0
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var outer: Vector2i = Vector2i((Vector2(512, 216) + direction * 99.0).round())
		_rect(out, outer.x - 4, outer.y - 4, 9, 9, IRON)
		_rect(out, outer.x - 2, outer.y - 2, 5, 5, STEEL)
		_rect(out, outer.x - 1, outer.y - 1, 2, 2, CYAN if index % 3 != 0 else AMBER)
		var inner: Vector2i = Vector2i((Vector2(512, 216) + direction * 72.0).round())
		var rim: Vector2i = Vector2i((Vector2(512, 216) + direction * 79.0).round())
		_beam(out, inner, rim, 2, LEAD)
	# Indexing marks are unequal to avoid a featureless concentric target.
	for index: int in range(24):
		var angle: float = (float(index) + 0.35) * TAU / 24.0
		var point: Vector2i = Vector2i((Vector2(512, 216) + Vector2(cos(angle), sin(angle)) * 87.0).round())
		_rect(out, point.x, point.y, 2, 2, IRON if index % 4 else LIMESTONE)
	# Deliberate interruptions expose the dark mechanical race behind the halo.
	_rect(out, 505, 133, 15, 3, IRON)
	_rect(out, 429, 208, 3, 15, IRON)
	_rect(out, 569, 269, 7, 6, IRON)
	_rect(out, 455, 154, 6, 5, BRONZE)
	# Vertical refractor, small bright tip, dark shoulders and visible open slots.
	_rect(out, 491, 184, 43, 65, IRON)
	_rect(out, 495, 187, 35, 57, CHEMICAL_GLASS)
	_rect(out, 501, 172, 23, 88, PAINTED_STEEL)
	_rect(out, 505, 169, 15, 94, CHEMICAL_GLASS)
	_rect(out, 509, 180, 7, 73, CYAN)
	_rect(out, 511, 202, 3, 28, WHITE)
	_rect(out, 508, 166, 9, 6, WHITE)
	_rect(out, 508, 263, 9, 4, CYAN)
	_rect(out, 491, 200, 8, 3, EMPTY)
	_rect(out, 525, 229, 9, 3, EMPTY)
	_rect(out, 477, 211, 15, 3, BRONZE)
	_rect(out, 534, 217, 15, 3, BRONZE)
	_rect(out, 470, 208, 4, 9, CYAN)
	_rect(out, 551, 214, 4, 9, CYAN)
	_rect(out, 480, 245, 10, 2, WHITE)
	_rect(out, 534, 184, 10, 2, CYAN)
	_rect(out, 489, 283, 47, 12, IRON)
	_text(out, "N-09", 498, 287, CYAN)
	# Six fine bus spokes, contact plates and two wound coils supply a smaller
	# mechanical scale inside the glass without obscuring the vertical refractor.
	for index: int in range(6):
		var angle: float = (float(index) + 0.5) * TAU / 6.0
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var inner: Vector2i = Vector2i((Vector2(512, 216) + direction * 46.0).round())
		var outer: Vector2i = Vector2i((Vector2(512, 216) + direction * 61.0).round())
		_beam(out, inner, outer, 1, BRONZE)
		_rect(out, outer.x - 2, outer.y - 2, 5, 5, IRON)
		_rect(out, outer.x - 1, outer.y - 1, 3, 2, LEAD)
		_rect(out, inner.x - 1, inner.y - 1, 2, 2, CYAN)
	for x: int in [474, 543]:
		_rect(out, x, 199, 9, 36, IRON)
		_rect(out, x + 2, 198, 5, 38, BRONZE)
		for y: int in range(201, 234, 5):
			_rect(out, x + 1, y, 7, 2, COPPER_PIPE)
		_rect(out, x + 3, 194, 3, 4, LEAD)
		_rect(out, x + 3, 236, 3, 4, LEAD)
	# Short paired etch marks break up the inner race; most remain matte.
	for index: int in range(8):
		var angle: float = (float(index) + 0.3) * TAU / 8.0
		var point: Vector2i = Vector2i((Vector2(512, 216) + Vector2(cos(angle), sin(angle)) * 66.0).round())
		_rect(out, point.x, point.y, 3, 1, LEAD)
		_rect(out, point.x, point.y + 2, 2, 1, BRONZE)


static func _foreground(out: PackedInt32Array) -> void:
	# Short gantry fragments frame the pool without drawing a screen-wide line
	# through its surface. Each railing has real gaps between its uprights.
	for origin: int in [347, 599]:
		_rect(out, origin, 451, 80, 2, LEAD)
		for offset: int in [0, 26, 53, 78]:
			_rect(out, origin + offset, 452, 2, 10, IRON)
		_rect(out, origin + 8, 452, 11, 1, CYAN)
	# Asymmetrical weathered parapets and blocks give the ground a strong edge.
	_rect(out, 49, 508, 17, 10, GRANITE)
	_rect(out, 180, 508, 102, 5, WET_ASPHALT)
	_rect(out, 745, 503, 29, 9, CONCRETE)
	_rect(out, 751, 499, 14, 4, GRANITE)
	_rect(out, 910, 506, 44, 8, WET_COBBLE)
	_rect(out, 956, 504, 16, 13, GRANITE)
	_rect(out, 58, 519, 209, 2, VERDIGRIS)
	_rect(out, 748, 519, 213, 2, RUSTED_STEEL)
	# Low cable loops and feet sit on existing hard surfaces, avoiding a spray
	# of isolated collision fragments simply to suggest grime.
	_rect(out, 111, 519, 54, 3, RUBBER)
	_rect(out, 116, 522, 4, 8, CABLE)
	_rect(out, 155, 522, 4, 6, CABLE)
	_rect(out, 867, 520, 49, 4, RUBBER)
	_rect(out, 872, 524, 3, 8, CABLE)
	_rect(out, 908, 524, 3, 5, CABLE)
	_rect(out, 356, 512, 57, 7, IRON)
	_text(out, "VAULT", 364, 513, LEAD)
	_rect(out, 627, 512, 31, 7, IRON)
	_text(out, "03", 638, 513, CYAN)
