class_name CyberBlacksiteNineMidworks
extends RefCounted

# B1–B3: native, tile-local cutaways. The complex owns the final passage carves,
# support floors and reciprocal seams; these rooms never install another world.
const Art = preload("res://scripts/blacksite_nine_art.gd")
const M = preload("res://scripts/neon_reliquary.gd")


static func tile(column: int) -> PackedInt32Array:
	var art = Art.new()
	match column:
		0: _intake(art)
		1: _choir(art)
		2: _condensate(art)
	return art.data


static func _substrate(a, seed: int) -> void:
	# Heavy exposed sections carry the detail; the circulation remains a much
	# smaller, deliberately cut volume inside the structure.
	a.rect(0, 0, 320, 320, M.SLATE)
	a.rect(7, 7, 306, 306, M.CONCRETE)
	a.rect(13, 13, 294, 294, M.SLATE)
	a.rect(4, 4, 5, 312, M.IRON)
	a.rect(311, 4, 5, 312, M.IRON)
	for row: int in range(6):
		var y: int = 22 + row * 48
		a.rect(13, y, 294, 1, M.IRON)
		a.rect(18 + posmod(row * 53 + seed * 11, 206), y + 1, 40, 3, M.CONCRETE)
	for index: int in range(10):
		a.rect(18 + posmod(index * 43 + seed * 17, 286),
			28 + posmod(index * 37 + seed * 23, 266), 2, 11 + index % 9, M.WET_ASPHALT)


static func _worker_cell(a, x: int, y: int, width: int, height: int, variant: int) -> void:
	a.panel(x, y, width, height, M.EMPTY, M.INDUSTRIAL_BRICK, 4)
	a.rect(x + 4, y + height - 8, width - 8, 4, M.IRON)
	a.rect(x + 7, y + height - 17, width - 22, 3, M.RUSTED_STEEL)
	a.rect(x + 9, y + height - 19, width - 27, 2, M.PLASTER)
	a.rect(x + width - 14, y + 13, 7, height - 25, M.CORRUGATED)
	a.rect(x + width - 13, y + 19, 2, 2, M.AMBER)
	a.rect(x + 8, y + 14, width - 28, 2, M.IRON)
	a.rect(x + 10 + variant % 3, y + 10, 4, 4, M.PAINTED_STEEL)
	a.rect(x + 5, y + 5, 1, height - 18, M.RUBBER)
	a.lamp(x + 9, y + 6, M.AMBER, 4)
	a.rect(x + width - 23, y + 7, 7, 5, M.RUBBER)
	a.rect(x + width - 22, y + 9, 5, 1, M.STEEL)
	a.rect(x + 7, y + 25, width - 23, 3, M.IRON)
	a.rect(x + 9, y + 23, width - 28, 2, M.RUBBER)
	a.rect(x + 9, y + 20, 7, 3, M.PLASTER)
	a.rect(x + 7, y + 27, 2, height - 39, M.RUSTED_STEEL)
	a.rect(x + width - 20, y + 28, 1, height - 40, M.RUBBER)
	a.rect(x + 8, y + height - 7, width - 19, 1, M.COPPER_PIPE)


static func _intake(a) -> void:
	_substrate(a, 3)
	# Six occupied-looking recesses: beds, lockers, shelves and warm service
	# bulbs, all on the massive sides of the north-west dogleg and freight shaft.
	_worker_cell(a, 126, 12, 54, 57, 0)
	_worker_cell(a, 187, 8, 58, 62, 1)
	_worker_cell(a, 253, 14, 57, 55, 2)
	_worker_cell(a, 9, 241, 60, 69, 3)
	_worker_cell(a, 77, 242, 61, 68, 4)
	_worker_cell(a, 147, 243, 73, 67, 5)

	# The main freight cage is packed into the solid island between the upper
	# inspection walk and the lower service dogleg, rather than across either.
	a.panel(140, 114, 169, 79, M.EMPTY, M.IRON, 5)
	a.rect(146, 119, 29, 67, M.CORRUGATED)
	a.console(150, 128, 20, 22, M.AMBER)
	a.panel(182, 120, 65, 67, M.EMPTY, M.STEEL, 3)
	a.rect(186, 179, 57, 5, M.RUSTED_STEEL)
	a.panel(189, 153, 22, 25, M.CORRUGATED, M.IRON, 2)
	a.panel(217, 160, 20, 18, M.RUBBER, M.RUSTED_STEEL, 2)
	for x: int in range(189, 243, 9):
		a.rect(x, 125, 1, 55, M.CHAINLINK)
	for y: int in range(130, 177, 11):
		a.rect(186, y, 57, 1, M.IRON)
	for index: int in range(6):
		a.rect(184 + index * 4, 122 + index * 4, 5, 2, M.RUSTED_STEEL)
		a.rect(239 - index * 4, 122 + index * 4, 5, 2, M.RUSTED_STEEL)
	a.lamp(201, 116, M.AMBER, 8)
	a.lamp(259, 180, M.AMBER, 4)
	a.ribs(271, 120, 31, 65, 9)
	a.pipe(Vector2i(257, 124), Vector2i(257, 172), 9, M.RUSTED_STEEL)
	a.pipe(Vector2i(250, 141), Vector2i(299, 141), 7, M.STEEL_PIPE)
	a.pipe(Vector2i(250, 164), Vector2i(299, 164), 7, M.COPPER_PIPE)
	a.bolts(140, 114, 169, 79)

	# A worker's service counter faces the narrow western circulation. Small
	# fittings make the recess inhabited without introducing actors or bodies.
	a.panel(8, 180, 89, 48, M.EMPTY, M.INDUSTRIAL_BRICK, 4)
	a.rect(15, 214, 72, 6, M.RUSTED_STEEL)
	a.console(18, 190, 22, 18, M.AMBER)
	a.rect(49, 201, 15, 12, M.RUBBER)
	a.rect(51, 199, 11, 2, M.PLASTER)
	a.rect(73, 186, 9, 26, M.CORRUGATED)
	a.lamp(48, 185, M.AMBER, 5)
	a.vent(12, 8, 57, 22)
	_column(a, 73, 7, 8, 30)
	_column(a, 112, 6, 9, 64)
	a.panel(65, 74, 33, 51, M.RUBBER, M.IRON, 3)
	a.vent(70, 80, 23, 22)
	a.lamp(76, 114, M.AMBER, 4)
	a.pipe(Vector2i(16, 115), Vector2i(16, 167), 9, M.RUSTED_STEEL)
	a.pipe(Vector2i(11, 173), Vector2i(94, 173), 7, M.RUSTED_STEEL)
	a.pipe(Vector2i(150, 232), Vector2i(217, 232), 7, M.COPPER_PIPE)

	# The far side of the freight shaft is a ribbed, almost inaccessible stack
	# of manifolds. It intentionally stops short of both reserved crosscuts.
	a.panel(275, 246, 34, 64, M.RUBBER, M.RUSTED_STEEL, 3)
	a.ribs(280, 250, 23, 53, 8)
	a.rect(282, 258, 20, 4, M.STEEL_PIPE)
	a.rect(282, 276, 20, 4, M.STEEL_PIPE)
	a.rect(282, 294, 20, 4, M.COPPER_PIPE)
	a.lamp(282, 240, M.AMBER, 5)
	a.rubble(13, 229, 77, 10, 13)
	for index: int in range(10):
		a.rect(144 + index * 16, 72, 3, 2, M.RUSTED_STEEL)
		a.rect(146 + index * 16, 110, 2, 2, M.STEEL)


static func _containment_cell(a, x: int, y: int, width: int, height: int, variant: int) -> void:
	a.panel(x, y, width, height, M.EMPTY, M.CONCRETE, 4)
	a.rect(x + 4, y + height - 8, width - 8, 4, M.IRON)
	a.rect(x + 8, y + 13, 7, height - 27, M.CHEMICAL_GLASS)
	a.rect(x + 10, y + 16, 2, height - 34, M.CYAN)
	a.rect(x + 20, y + height - 17, width - 29, 4, M.RUBBER)
	a.rect(x + 22, y + height - 20, width - 34, 3, M.PLASTER)
	a.rect(x + width - 10, y + 9, 2, height - 22, M.RUBBER)
	a.rect(x + width - 17, y + 9, 8, 2, M.RUBBER)
	a.lamp(x + 21, y + 7, M.AMBER, 3 + variant % 2)


static func _column(a, x: int, y: int, width: int, height: int) -> void:
	a.rect(x, y, width, height, M.IRON)
	a.rect(x + 3, y + 4, width - 6, height - 8, M.CORRUGATED)
	a.rect(x + 4, y + 5, 2, height - 10, M.RUSTED_STEEL)
	for yy: int in range(y + 8, y + height - 4, 11):
		a.rect(x - 2, yy, width + 4, 3, M.IRON)
		a.rect(x + 2, yy, 3, 1, M.STEEL)


static func _instrument(a, x: int, y: int, width: int, height: int, phase: int) -> void:
	a.console(x, y, width, height, M.CYAN if phase % 3 != 0 else M.AMBER)
	a.rect(x + 4, y + 6, maxi(2, width - 11), 1, M.CHEMICAL_GLASS)
	a.rect(x + width - 7, y + 5, 1, maxi(2, height - 11), M.CYAN)
	a.rect(x + 4 + phase % 4, y + height - 2, 3, 3, M.RUBBER)


static func _choir(a) -> void:
	_substrate(a, 4)
	# The theatre lives east of the circulation spine. Repeated screens have
	# deliberately unequal heights and offsets, with dense descending tendons.
	a.panel(196, 65, 116, 139, M.EMPTY, M.IRON, 5)
	a.beam(Vector2i(199, 82), Vector2i(218, 62), 4, M.IRON, 5)
	a.beam(Vector2i(299, 73), Vector2i(283, 62), 4, M.IRON, 5)
	a.rect(218, 60, 66, 5, M.IRON)
	a.rect(224, 59, 48, 1, M.RUSTED_STEEL)
	for index: int in range(5):
		var height: int = 22 + posmod(index * 11, 23)
		a.rect(249 + index * 12, 10, 8, height, M.IRON)
		a.rect(251 + index * 12, 13, 4, height - 6, M.RUBBER)
		a.rect(249 + index * 12, 10 + height, 8, 2, M.RUSTED_STEEL)
	a.rect(245, 7, 66, 3, M.IRON)
	a.rect(247, 6, 62, 1, M.RUSTED_STEEL)
	_column(a, 141, 8, 15, 136)
	_column(a, 301, 66, 13, 138)
	_column(a, 200, 252, 16, 58)
	a.rect(249, 77, 13, 117, M.RUBBER)
	a.rect(250, 82, 4, 110, M.RUBBER)
	a.rect(201, 187, 99, 10, M.RUSTED_STEEL)
	a.rect(208, 181, 82, 6, M.IRON)
	a.rect(229, 175, 48, 6, M.CORRUGATED)
	for index: int in range(7):
		var x: int = 205 + index * 12
		var y: int = 93 + posmod(index * 19, 76)
		a.rect(x, y, 2, 188 - y, M.RUBBER)
		a.rect(x, y, 17, 2, M.RUBBER)
	_instrument(a, 205, 75, 30, 22, 0)
	_instrument(a, 241, 71, 31, 27, 1)
	_instrument(a, 276, 83, 22, 26, 2)
	_instrument(a, 202, 108, 38, 23, 3)
	_instrument(a, 248, 106, 43, 28, 4)
	_instrument(a, 213, 139, 29, 24, 5)
	_instrument(a, 250, 143, 25, 31, 6)
	_instrument(a, 278, 141, 20, 22, 7)
	a.rect(242, 182, 23, 2, M.AMBER)
	a.rect(247, 178, 13, 3, M.COPPER_PIPE)

	# Institutional cells are small, low and visibly embedded in the wall.
	_containment_cell(a, 10, 9, 58, 59, 0)
	_containment_cell(a, 77, 10, 57, 57, 1)
	_containment_cell(a, 11, 187, 63, 59, 2)
	_containment_cell(a, 83, 188, 65, 58, 3)
	a.panel(13, 259, 59, 51, M.EMPTY, M.IRON, 4)
	a.vent(20, 266, 19, 30)
	a.console(43, 280, 23, 21, M.AMBER)
	a.lamp(44, 265, M.AMBER, 5)

	# A secondary bank is cut into the right side below the service artery;
	# separate buttresses leave the central north/south passage unmistakable.
	a.panel(222, 251, 88, 59, M.EMPTY, M.IRON, 4)
	a.console(229, 259, 31, 23, M.CYAN)
	a.console(266, 264, 34, 18, M.AMBER)
	a.rect(228, 290, 73, 8, M.CORRUGATED)
	for x: int in range(232, 299, 10):
		a.rect(x, 288, 3, 2, M.AMBER)
	a.pipe(Vector2i(285, 287), Vector2i(285, 306), 7, M.COPPER_PIPE)
	a.pipe(Vector2i(123, 109), Vector2i(123, 143), 9, M.RUSTED_STEEL)
	a.vent(13, 117, 38, 49)
	for index: int in range(9):
		a.rect(18 + index * 14, 73, 2, 2, M.STEEL)
		a.rect(193 + index * 12, 242, 2, 3, M.RUSTED_STEEL)
	a.rubble(15, 250, 58, 7, 29)


static func _pressure_stack(a, x: int, y: int, width: int, height: int, count: int) -> void:
	a.panel(x, y, width, height, M.EMPTY, M.IRON, 4)
	a.rect(x + 6, y + 5, width - 12, height - 10, M.RUBBER)
	a.rect(x + 10, y + 8, width - 20, height - 16, M.RUSTED_STEEL)
	a.rect(x + 13, y + 8, 3, height - 16, M.VERDIGRIS)
	a.rect(x + width - 11, y + 8, 2, height - 16, M.WET_ASPHALT)
	for index: int in range(count):
		var yy: int = y + 17 + index * ((height - 30) / count)
		a.rect(x + 3, yy, width - 6, 5, M.IRON)
		a.rect(x + 7, yy, width - 14, 1, M.COPPER_PIPE)
		a.rect(x + 4, yy + 5, width - 8, 1, M.VERDIGRIS)
		a.rect(x + width - 9, yy - 2, 2, 2, M.STEEL)
		if index % 2 == 0:
			a.panel(x + 20, yy + 7, width - 30, 14, M.CHEMICAL_GLASS, M.IRON, 2)
			a.rect(x + 24, yy + 10, 2, 7, M.CYAN)
	a.rect(x - 3, y + 8, 4, height - 16, M.STEEL_PIPE)
	a.rect(x + width - 1, y + 15, 4, height - 30, M.COPPER_PIPE)
	a.rect(x + 6, y - 5, width - 12, 5, M.IRON)
	a.rect(x + 12, y - 9, width - 24, 4, M.RUSTED_STEEL)
	a.lamp(x + 17, y + 3, M.AMBER, 4)
	a.bolts(x, y, width, height)


static func _condensate(a) -> void:
	_substrate(a, 5)
	# Stacked rectangular pressure bodies and stepped crowns give this tile an
	# Art Deco silhouette. All cyan windows remain solid ordinary materials.
	a.panel(10, 8, 113, 194, M.EMPTY, M.CONCRETE, 5)
	_pressure_stack(a, 21, 28, 86, 137, 7)
	a.rect(34, 16, 60, 3, M.COPPER_PIPE)
	a.rect(41, 11, 46, 4, M.IRON)
	a.pipe(Vector2i(17, 72), Vector2i(17, 172), 7, M.RUSTED_STEEL)
	a.pipe(Vector2i(112, 74), Vector2i(112, 194), 7, M.RUSTED_STEEL)
	a.panel(23, 175, 76, 23, M.RUBBER, M.IRON, 3)
	for x: int in range(29, 95, 11):
		a.rect(x, 180, 4, 11, M.STEEL_PIPE)
	_pressure_stack(a, 273, 103, 35, 136, 6)

	# Two tiny service booths sit above the pressure island and to the far east
	# of the upper dogleg; their doors do not occupy the frozen route envelope.
	a.panel(271, 10, 41, 73, M.EMPTY, M.CONCRETE, 4)
	a.console(279, 23, 25, 22, M.CYAN)
	a.rect(278, 57, 24, 7, M.CORRUGATED)
	a.rect(296, 48, 6, 9, M.RUBBER)
	a.lamp(282, 17, M.AMBER, 4)
	a.rect(278, 68, 25, 6, M.RUBBER)
	for index: int in range(5):
		a.rect(279 + index * 5, 69, 2, 1, M.STEEL)
		a.rect(280 + index * 5, 70, 1, 3, M.COPPER_PIPE)
	a.panel(165, 79, 58, 34, M.EMPTY, M.IRON, 4)
	a.console(173, 86, 29, 20, M.CYAN)
	a.rect(207, 86, 8, 19, M.CORRUGATED)
	a.lamp(209, 80, M.AMBER, 4)
	a.panel(124, 82, 43, 33, M.EMPTY, M.IRON, 4)
	a.console(132, 89, 28, 18, M.CYAN)
	for index: int in range(3):
		a.rect(132 + index * 8, 109, 3, 1, M.AMBER)
	a.pipe(Vector2i(146, 113), Vector2i(146, 126), 9, M.COPPER_PIPE)
	a.pipe(Vector2i(150, 122), Vector2i(150, 194), 11, M.RUSTED_STEEL)
	a.pipe(Vector2i(129, 184), Vector2i(168, 184), 9, M.COPPER_PIPE)
	a.pipe(Vector2i(127, 198), Vector2i(169, 198), 9, M.STEEL_PIPE)
	a.vent(18, 204, 133, 9)

	# A truly contained native Water basin occupies the off-route south-west
	# pocket. The masonry perimeter is uninterrupted by the final shared cuts.
	a.panel(12, 250, 146, 61, M.EMPTY, M.CONCRETE, 5)
	a.rect(17, 300, 136, 6, M.IRON)
	a.rect(18, 284, 134, 16, M.WATER)
	a.rect(18, 283, 134, 1, M.WATER)
	a.rect(18, 256, 134, 4, M.RUSTED_STEEL)
	a.rect(27, 259, 4, 41, M.IRON)
	a.rect(135, 259, 4, 41, M.IRON)
	a.panel(43, 290, 34, 10, M.DARK_GLASS, M.STEEL, 2)
	a.rect(47, 293, 25, 1, M.CYAN)
	a.pipe(Vector2i(91, 269), Vector2i(125, 269), 7, M.RUSTED_STEEL)
	a.pipe(Vector2i(122, 269), Vector2i(122, 300), 7, M.COPPER_PIPE)
	a.lamp(46, 263, M.AMBER, 4)
	a.lamp(83, 263, M.AMBER, 4)
	for x: int in range(22, 149, 14):
		a.rect(x, 307, 4, 2, M.RUSTED_STEEL)

	# The final maintenance pod is tucked beyond the return shaft. Dense fins
	# and offset gauges differentiate it from the larger western pressure body.
	a.panel(250, 254, 59, 56, M.EMPTY, M.IRON, 4)
	a.console(257, 262, 22, 23, M.CYAN)
	a.vent(285, 261, 17, 37)
	a.rect(256, 294, 23, 8, M.CORRUGATED)
	a.lamp(261, 251, M.AMBER, 4)
	a.pipe(Vector2i(268, 287), Vector2i(268, 307), 7, M.COPPER_PIPE)
	a.ribs(10, 107, 11, 83, 8)
	a.ribs(161, 145, 11, 48, 8)
	for index: int in range(10):
		a.rect(17 + index * 14, 241, 2, 3, M.RUSTED_STEEL)
		a.rect(265, 115 + index * 11, 3, 2, M.STEEL)
	a.rubble(19, 315, 133, 5, 41)
