class_name CyberBlacksiteNineDepths
extends RefCounted

# The deepest row is mostly rock and enclosed machinery. These are local
# material rectangles; the complex owns the final passages and shared seams.
const Art = preload("res://scripts/blacksite_nine_art.gd")
const M = preload("res://scripts/neon_reliquary.gd")


static func tile(column: int) -> PackedInt32Array:
	var art = Art.new()
	match column:
		0: _furnace_ossuary(art)
		1: _synapse_vault(art)
		2: _blackwater_terminus(art)
	return art.data


static func _strata(art, variant: int) -> void:
	art.rect(0, 0, 320, 320, M.SLATE)
	art.rect(0, 264, 320, 56, M.GRANITE)
	art.rect(0, 310, 320, 10, M.WET_ASPHALT)
	# Broken shelves and short mineral seams make the surrounding mass legible.
	for index: int in range(8):
		var x: int = 6 + (index * 47 + variant * 19) % 284
		var y: int = 17 + (index * 61 + variant * 13) % 281
		art.rect(x, y, 17 + index % 4 * 6, 3, M.GRANITE)
		art.rect(x + 3, y + 3, 11 + index % 3 * 5, 1, M.WET_ASPHALT)
	art.rect(0, 302, 320, 3, M.IRON)
	art.rect(0, 305, 320, 1, M.RUSTED_STEEL)


static func _chain(art, x: int, y: int, length: int) -> void:
	for offset: int in range(0, length, 8):
		art.rect(x, y + offset, 2, 6, M.IRON)
		art.rect(x + 4, y + offset, 2, 6, M.LEAD)
		art.rect(x + 1, y + offset + 5, 4, 2, M.RUSTED_STEEL)


static func _furnace_ossuary(art) -> void:
	_strata(art, 0)
	# The freight well turns twice before approaching the machine from behind.
	# Its clear centreline is x248 -> y58 -> x196 -> y132, above the lower ram.
	art.rect(213, 0, 62, 41, M.IRON)
	art.rect(219, 0, 9, 37, M.RUSTED_STEEL)
	art.rect(271, 0, 6, 74, M.CORRUGATED)
	art.rect(218, 40, 13, 4, M.HAZARD)
	art.rect(263, 40, 17, 4, M.HAZARD)
	art.pipe(Vector2i(286, 9), Vector2i(286, 116), 13, M.RUSTED_STEEL)
	art.pipe(Vector2i(286, 116), Vector2i(222, 116), 11, M.STEEL_PIPE)
	art.lamp(269, 80, M.AMBER, 6)
	art.vent(222, 89, 35, 18)
	# A vast offset crusher is sunk into an irregular rock recess. The two jaws
	# are deliberately unequal, with the warm throat almost hidden beneath them.
	art.panel(15, 25, 164, 92, M.EMPTY, M.IRON, 5)
	art.rect(22, 30, 18, 79, M.RUSTED_STEEL)
	art.rect(43, 32, 118, 5, M.LEAD)
	art.rect(38, 104, 123, 8, M.RUSTED_STEEL)
	art.rect(44, 104, 101, 2, M.AMBER)
	art.rect(27, 43, 63, 58, M.STEEL)
	art.rect(31, 48, 55, 48, M.RUSTED_STEEL)
	art.rect(91, 58, 70, 41, M.IRON)
	art.rect(96, 62, 59, 29, M.RUSTED_STEEL)
	art.rect(35, 50, 45, 3, M.HAZARD)
	art.rect(105, 66, 43, 2, M.HAZARD)
	art.ribs(37, 57, 42, 35, 10, M.IRON)
	for x: int in [88, 96, 104, 112, 120, 128, 136, 144, 152]:
		art.rect(x, 95, 5, 9 if x % 16 == 8 else 6, M.LEAD)
	art.ellipse(55, 74, 14, 16, M.IRON)
	art.ellipse(54, 72, 8, 9, M.BRONZE)
	art.rect(52, 69, 4, 7, M.RUBBER)
	art.ellipse(125, 79, 18, 11, M.IRON)
	art.ellipse(125, 77, 11, 6, M.LEAD)
	art.rect(120, 75, 10, 3, M.RUBBER)
	art.bolts(22, 40, 72, 63)
	art.bolts(91, 58, 70, 41)
	# The wide diagonal feed duct is capped; its warm slit is a solid finish.
	art.beam(Vector2i(52, 3), Vector2i(97, 43), 22, M.IRON)
	art.beam(Vector2i(53, 3), Vector2i(98, 42), 15, M.RUSTED_STEEL)
	art.rect(39, 3, 35, 6, M.LEAD)
	art.rect(77, 33, 43, 7, M.IRON)
	art.rect(81, 33, 33, 2, M.COPPER_PIPE)
	art.rect(141, 7, 27, 9, M.STEEL)
	_chain(art, 147, 16, 34)
	_chain(art, 15, 2, 24)
	art.rect(140, 46, 23, 8, M.IRON)
	art.rect(144, 48, 15, 2, M.BRONZE)
	# A crushed geological shoulder presses inward from the western wall.
	for block: Array in [[0,107,47,30], [0,137,30,32], [0,169,17,42],
		[17,116,41,15], [8,142,37,17], [0,181,39,28]]:
		art.rect(block[0], block[1], block[2], block[3], M.GRANITE)
	art.rect(11, 120, 29, 4, M.WET_ASPHALT)
	art.rect(3, 150, 32, 3, M.WET_ASPHALT)
	art.rubble(22, 157, 50, 49, 3)
	art.pipe(Vector2i(56, 141), Vector2i(56, 191), 11, M.COPPER_PIPE)
	art.rect(46, 186, 23, 13, M.IRON)
	art.rect(50, 189, 15, 5, M.DARK_GLASS)
	# Lower compression bed and overhead piston bank leave only a narrow slot.
	art.panel(116, 150, 184, 60, M.EMPTY, M.IRON, 5)
	art.rect(127, 150, 158, 13, M.RUSTED_STEEL)
	art.rect(121, 192, 173, 17, M.STEEL)
	art.rect(124, 193, 165, 3, M.HAZARD)
	art.rect(131, 203, 148, 3, M.RUSTED_STEEL)
	for x: int in [133, 164, 195, 226, 257]:
		art.rect(x, 162, 11, 15, M.LEAD)
		art.rect(x - 3, 176, 18, 9, M.IRON)
		art.rect(x, 182, 12, 4, M.RUSTED_STEEL)
	art.rect(146, 187, 116, 3, M.AMBER)
	art.rect(183, 186, 14, 6, M.RUBBER)
	art.rect(238, 185, 10, 7, M.RUBBER)
	art.bolts(118, 150, 180, 59)
	art.console(273, 174, 18, 15, M.CYAN)
	# A sunken maintenance cabin provides a small human-scale counterpoint.
	art.panel(111, 255, 122, 43, M.EMPTY, M.CONCRETE, 5)
	art.rect(112, 253, 124, 5, M.CORRUGATED)
	art.panel(117, 263, 46, 24, M.DARK_GLASS, M.IRON, 2)
	art.rect(139, 265, 2, 20, M.LEAD)
	art.rect(121, 267, 16, 1, M.AMBER)
	art.console(174, 265, 24, 19, M.AMBER)
	art.rect(169, 286, 49, 4, M.RUSTED_STEEL)
	art.rect(202, 263, 16, 17, M.CORRUGATED)
	art.rect(215, 264, 2, 13, M.IRON)
	art.rect(119, 291, 105, 3, M.GRATING)
	art.lamp(166, 248, M.AMBER, 8)
	art.vent(247, 264, 51, 31)
	art.pipe(Vector2i(246, 252), Vector2i(298, 252), 7, M.COPPER_PIPE)
	art.pipe(Vector2i(297, 249), Vector2i(297, 306), 8, M.RUSTED_STEEL)
	art.panel(5, 247, 20, 37, M.WET_ASPHALT, M.IRON, 2)
	art.rect(10, 254, 9, 22, M.RUSTED_STEEL)
	art.lamp(61, 261, M.CYAN, 4)
	art.rect(264, 134, 32, 10, M.IRON)
	art.label("03", 271, 137, M.LEAD)
	# Local weathering stays attached to the machine faces and solid shelves.
	for index: int in range(15):
		art.rect(124 + index * 11, 205 + index % 2, 5, 2,
			M.RUSTED_STEEL if index % 3 else M.RUBBER)


static func _synapse_vault(art) -> void:
	_strata(art, 1)
	# Flues and insulation press against the narrow northern utility throat.
	art.rect(3, 0, 73, 153, M.INDUSTRIAL_BRICK)
	art.pipe(Vector2i(24, 0), Vector2i(24, 151), 18, M.RUSTED_STEEL)
	art.pipe(Vector2i(55, 7), Vector2i(55, 147), 13, M.COPPER_PIPE)
	art.rect(37, 21, 7, 118, M.INSULATION)
	art.rect(12, 53, 56, 8, M.IRON)
	art.rect(12, 128, 56, 8, M.IRON)
	art.rect(15, 146, 51, 8, M.RUSTED_STEEL)
	art.rect(19, 150, 34, 3, M.AMBER)
	art.rect(18, 82, 14, 25, M.IRON)
	art.rect(22, 85, 6, 19, M.DARK_GLASS)
	art.rect(24, 89, 2, 7, M.AMBER)
	for y: int in [34, 79, 108, 139]:
		art.rect(12, y, 26, 4, M.IRON)
		art.rect(14, y + 1, 2, 2, M.STEEL)
		art.rect(35, y + 1, 7, 2, M.BRONZE)
	art.rect(47, 94, 16, 23, M.IRON)
	art.rect(50, 97, 10, 17, M.DARK_GLASS)
	art.rect(52, 99, 2, 11, M.CHEMICAL_GLASS)
	art.rect(55, 105, 3, 2, M.AMBER)
	art.rect(71, 0, 7, 31, M.RUBBER)
	art.rect(113, 4, 11, 29, M.CORRUGATED)
	art.lamp(115, 26, M.AMBER, 5)
	# A squat pressure organ occupies a pocket above the eastern gallery.
	art.panel(173, 10, 134, 70, M.EMPTY, M.IRON, 4)
	art.ellipse(249, 42, 39, 30, M.IRON)
	art.ellipse(247, 40, 33, 24, M.RUSTED_STEEL)
	art.ellipse(239, 39, 17, 18, M.BRONZE)
	art.ellipse(238, 38, 12, 13, M.DARK_GLASS)
	art.rect(237, 27, 2, 22, M.CHEMICAL_GLASS)
	art.rect(234, 39, 9, 2, M.AMBER)
	art.rect(216, 18, 68, 5, M.LEAD)
	art.rect(219, 59, 65, 6, M.IRON)
	for x: int in [214, 226, 269, 281]:
		art.rect(x, 27, 3, 28, M.LEAD)
		art.rect(x - 2, 39, 7, 4, M.IRON)
	art.pipe(Vector2i(288, 1), Vector2i(288, 78), 10, M.STEEL_PIPE)
	art.console(180, 25, 23, 19, M.CYAN)
	art.rect(180, 52, 23, 4, M.CORRUGATED)
	art.rect(185, 57, 4, 12, M.COPPER_PIPE)
	# A thin spine of services fills the strip between two turns of the path.
	art.rect(113, 72, 18, 79, M.IRON)
	art.rect(116, 75, 5, 73, M.RUBBER)
	art.rect(123, 78, 5, 65, M.RUSTED_STEEL)
	for y: int in [78, 99, 122, 145]:
		art.rect(111, y, 22, 4, M.LEAD)
	art.rect(118, 105, 8, 16, M.DARK_GLASS)
	art.rect(120, 108, 2, 10, M.CYAN)
	# The eastern vessel is longer and nearly buried behind close-set ribs.
	art.panel(230, 123, 71, 86, M.EMPTY, M.CONCRETE, 4)
	art.rect(246, 133, 39, 59, M.IRON)
	art.rect(250, 137, 31, 54, M.RUSTED_STEEL)
	art.ellipse(265, 135, 20, 10, M.LEAD)
	art.ellipse(265, 190, 20, 10, M.IRON)
	art.rect(254, 148, 23, 28, M.DARK_GLASS)
	art.rect(257, 151, 3, 20, M.CHEMICAL_GLASS)
	art.rect(248, 178, 35, 5, M.LEAD)
	art.pipe(Vector2i(290, 114), Vector2i(290, 209), 8, M.COPPER_PIPE)
	art.ribs(235, 130, 10, 66, 7, M.IRON)
	art.lamp(279, 201, M.AMBER, 5)
	# An operator shrine is cramped beneath the service gallery. Monitors flank
	# a heavy recording spine, with short umbilicals and a deep furnace slit.
	art.panel(99, 195, 132, 109, M.EMPTY, M.IRON, 5)
	art.rect(107, 201, 115, 8, M.RUSTED_STEEL)
	art.rect(153, 211, 22, 65, M.IRON)
	art.rect(158, 217, 12, 51, M.RUBBER)
	art.rect(162, 218, 3, 47, M.COPPER_PIPE)
	for row: int in range(3):
		var y: int = 214 + row * 21
		art.console(111, y, 30, 17, M.AMBER if row != 1 else M.CYAN)
		art.console(184, y + 3, 29, 17, M.AMBER)
		art.rect(143, y + 7, 9, 4, M.RUBBER)
		art.rect(175, y + 10, 7, 3, M.COPPER_PIPE)
	art.rect(112, 279, 106, 17, M.RUSTED_STEEL)
	art.rect(117, 283, 96, 9, M.RUBBER)
	art.rect(120, 286, 89, 3, M.AMBER)
	for x: int in range(127, 208, 13):
		art.rect(x, 282, 3, 13, M.IRON)
	art.rect(108, 298, 115, 3, M.GRATING)
	art.bolts(101, 197, 128, 105)
	art.lamp(147, 191, M.AMBER, 7)
	# Dense spent manifolds fill the otherwise dead southern shoulder.
	art.pipe(Vector2i(246, 223), Vector2i(246, 306), 14, M.RUSTED_STEEL)
	art.pipe(Vector2i(273, 215), Vector2i(273, 307), 12, M.STEEL_PIPE)
	art.pipe(Vector2i(303, 220), Vector2i(303, 307), 10, M.COPPER_PIPE)
	art.rect(237, 246, 76, 8, M.IRON)
	art.rect(238, 287, 75, 7, M.IRON)
	art.rect(278, 269, 17, 16, M.RUSTED_STEEL)
	art.rect(282, 272, 9, 8, M.DARK_GLASS)
	art.rect(28, 171, 24, 35, M.RUSTED_STEEL)
	art.rect(34, 177, 12, 23, M.RUBBER)
	art.rect(38, 181, 4, 16, M.AMBER)
	art.rect(13, 247, 40, 45, M.INDUSTRIAL_BRICK)
	art.vent(20, 252, 27, 31)
	art.rect(17, 287, 39, 6, M.RUSTED_STEEL)
	art.lamp(49, 197, M.AMBER, 5)
	art.rect(169, 67, 35, 11, M.IRON)
	art.label("IX", 180, 70, M.LEAD)
	for index: int in range(12):
		art.rect(238 + (index * 19) % 66, 310 + index % 4, 5, 2,
			M.RUSTED_STEEL if index % 3 else M.RUBBER)


static func _blackwater_terminus(art) -> void:
	_strata(art, 2)
	# A low serrated roof is packed with old conduits. The return well remains
	# a separate narrow service route at x224, turning toward x268 at y50.
	art.rect(0, 0, 206, 22, M.GRANITE)
	for index: int in range(9):
		art.rect(index * 23, 18, 24, 9 + (index * 7) % 19, M.GRANITE)
	art.pipe(Vector2i(5, 43), Vector2i(200, 43), 15, M.RUSTED_STEEL)
	art.pipe(Vector2i(9, 68), Vector2i(177, 68), 9, M.COPPER_PIPE)
	art.pipe(Vector2i(177, 68), Vector2i(177, 18), 9, M.COPPER_PIPE)
	art.rect(35, 38, 48, 11, M.IRON)
	art.rect(40, 40, 37, 5, M.CORRUGATED)
	art.rect(117, 34, 21, 19, M.IRON)
	art.rect(122, 38, 11, 11, M.BRONZE)
	art.rect(126, 41, 3, 5, M.RUBBER)
	for x: int in [23, 92, 158]:
		art.rect(x, 22, 3, 17, M.IRON)
		art.rect(x - 3, 21, 9, 4, M.RUSTED_STEEL)
		art.rect(x, 22, 2, 2, M.STEEL)
		art.rect(x - 2, 35, 8, 3, M.IRON)
	art.rect(192, 0, 12, 32, M.CORRUGATED)
	art.rect(243, 0, 9, 31, M.RUBBER)
	art.pipe(Vector2i(296, 4), Vector2i(296, 305), 15, M.RUSTED_STEEL)
	art.rect(307, 9, 7, 293, M.INSULATION)
	for y: int in [82, 144, 205, 286]:
		art.rect(286, y, 22, 5, M.IRON)
		art.rect(303, y + 1, 3, 2, M.BRONZE)
	art.rect(204, 14, 4, 20, M.HAZARD)
	art.rect(239, 14, 4, 20, M.HAZARD)
	art.lamp(244, 69, M.AMBER, 5)
	# The observation booth sits hard against the pump mass. Its glass and
	# cabling belong to the apparatus, away from both reserved passages.
	art.panel(101, 81, 135, 65, M.EMPTY, M.CONCRETE, 5)
	art.rect(96, 78, 143, 6, M.RUSTED_STEEL)
	art.panel(108, 89, 76, 34, M.DARK_GLASS, M.IRON, 3)
	art.rect(143, 92, 3, 29, M.LEAD)
	art.rect(112, 92, 26, 2, M.CHEMICAL_GLASS)
	art.rect(159, 94, 17, 1, M.AMBER)
	art.console(194, 94, 28, 18, M.CYAN)
	art.rect(192, 117, 32, 7, M.CORRUGATED)
	art.rect(108, 129, 115, 6, M.RUSTED_STEEL)
	art.rect(113, 130, 77, 2, M.HAZARD)
	art.rect(114, 136, 103, 5, M.GRATING)
	art.bolts(99, 80, 137, 66)
	art.lamp(187, 77, M.AMBER, 8)
	art.rect(106, 124, 38, 7, M.IRON)
	art.label("C3", 115, 125, M.LEAD)
	# Western pump heads crowd the downward turn; the passage is to their right.
	art.panel(5, 123, 43, 82, M.EMPTY, M.IRON, 4)
	art.ellipse(27, 147, 17, 19, M.IRON)
	art.ellipse(26, 146, 11, 13, M.RUSTED_STEEL)
	art.ellipse(26, 145, 6, 7, M.LEAD)
	art.rect(23, 143, 7, 3, M.RUBBER)
	art.pipe(Vector2i(24, 167), Vector2i(24, 203), 12, M.COPPER_PIPE)
	art.rect(13, 177, 23, 6, M.IRON)
	art.rect(31, 182, 12, 19, M.DARK_GLASS)
	art.rect(35, 185, 2, 12, M.CHEMICAL_GLASS)
	art.lamp(39, 133, M.AMBER, 4)
	# A sealed trench is tucked below a rock overhang, well left of the x156
	# service descent. Every Water cell is inside permanent walls and a floor.
	art.panel(13, 219, 122, 86, M.EMPTY, M.CONCRETE, 6)
	art.rect(19, 258, 110, 41, M.WATER)
	art.rect(17, 216, 114, 9, M.GRANITE)
	for block: Array in [[17,223,20,7], [37,223,26,12], [62,223,24,5],
		[85,223,24,9], [108,223,22,4]]:
		art.rect(block[0], block[1], block[2], block[3], M.GRANITE)
	art.rect(14, 294, 5, 10, M.RUSTED_STEEL)
	art.rect(129, 280, 7, 24, M.RUSTED_STEEL)
	art.rect(19, 299, 110, 5, M.WET_COBBLE)
	art.pipe(Vector2i(47, 193), Vector2i(120, 193), 12, M.RUSTED_STEEL)
	art.pipe(Vector2i(47, 193), Vector2i(47, 266), 10, M.COPPER_PIPE)
	art.pipe(Vector2i(116, 188), Vector2i(116, 278), 11, M.RUSTED_STEEL)
	art.rect(106, 244, 21, 6, M.IRON)
	art.rect(111, 250, 9, 22, M.DARK_GLASS)
	art.rect(113, 251, 2, 16, M.CHEMICAL_GLASS)
	art.rect(37, 263, 23, 8, M.IRON)
	art.rect(39, 270, 19, 3, M.COPPER_PIPE)
	art.lamp(92, 242, M.CYAN, 4)
	# A cramped pump station straddles the east gallery as two separate blocks;
	# the pipe ends stop at its lintel and sill rather than crossing the route.
	art.panel(181, 187, 64, 44, M.EMPTY, M.IRON, 4)
	art.ellipse(208, 208, 22, 17, M.RUSTED_STEEL)
	art.ellipse(207, 207, 15, 11, M.IRON)
	art.ellipse(207, 206, 9, 7, M.BRONZE)
	art.rect(204, 202, 7, 8, M.RUBBER)
	art.rect(232, 193, 8, 29, M.CORRUGATED)
	art.rect(234, 196, 3, 10, M.DARK_GLASS)
	art.lamp(226, 225, M.AMBER, 4)
	art.pipe(Vector2i(246, 126), Vector2i(246, 232), 9, M.COPPER_PIPE)
	art.rect(237, 229, 16, 5, M.IRON)
	art.panel(184, 271, 61, 31, M.WET_ASPHALT, M.RUSTED_STEEL, 3)
	art.console(190, 276, 22, 17, M.AMBER)
	art.vent(217, 276, 22, 20)
	art.rect(181, 266, 67, 5, M.GRATING)
	art.pipe(Vector2i(247, 269), Vector2i(247, 307), 9, M.COPPER_PIPE)
	art.rect(273, 276, 12, 26, M.RUBBER)
	art.rect(272, 301, 23, 6, M.IRON)
	# Short corrosion streaks belong to masonry and pipe jackets, never Water.
	for index: int in range(18):
		var x: int = 6 + (index * 31) % 124
		art.rect(x, 311 + index % 5, 5 + index % 4, 2,
			M.VERDIGRIS if index % 5 == 0 else M.RUSTED_STEEL)
	art.rubble(85, 189, 48, 24, 7)
