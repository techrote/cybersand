class_name CyberBlacksiteNineSurface
extends RefCounted

# Surface art is tile-local. The complex owns the reciprocal seam structures
# and its final 28-cell circulation cut; none of these props owns simulation.
const Art = preload("res://scripts/blacksite_nine_art.gd")
const M = preload("res://scripts/neon_reliquary.gd")


static func tile(column: int) -> PackedInt32Array:
	var a: Variant = Art.new()
	match column:
		0: _slag_approach(a)
		1: _aster_research(a)
		2: _ashworks_breach(a)
	_service_fittings(a, column)
	return a.data


static func _strata(a: Variant) -> void:
	a.rect(0, 276, 320, 44, M.GRANITE)
	a.rect(0, 276, 320, 5, M.ASPHALT)
	a.rect(0, 282, 320, 3, M.CONCRETE)
	a.rect(0, 307, 320, 3, M.SLATE)
	for x: int in [8, 74, 182, 264]:
		a.rect(x, 294, 38, 2, M.LEAD)
		a.rect(x + 8, 297, 14, 1, M.RUSTED_STEEL)


static func _cable(a: Variant, points: Array[Vector2i]) -> void:
	# Short horizontal runs joined by vertical drops give a continuous sag with
	# two native rectangles per bend, without a costly one-pixel line raster.
	for index: int in range(points.size() - 1):
		var start: Vector2i = points[index]
		var end: Vector2i = points[index + 1]
		a.rect(start.x, start.y, end.x - start.x + 1, 2, M.RUBBER)
		a.rect(end.x - 1, mini(start.y, end.y), 2, absi(end.y - start.y) + 2, M.RUBBER)


static func _slag_approach(a: Variant) -> void:
	_strata(a)
	# Compressed ash terraces terminate against the open intake road at y262.
	a.rect(0, 230, 24, 47, M.SANDSTONE)
	a.rect(14, 243, 34, 34, M.CONCRETE)
	a.rect(26, 246, 58, 8, M.SLATE)
	a.rect(88, 239, 27, 10, M.GRANITE)
	a.rect(112, 244, 53, 5, M.SANDSTONE)
	a.rect(165, 236, 22, 12, M.CONCRETE)
	a.rect(185, 240, 25, 8, M.RUSTED_STEEL)
	a.rect(218, 244, 36, 4, M.SLATE)
	a.rect(270, 238, 50, 10, M.GRANITE)
	for x: int in [2, 30, 101, 164, 272, 301]:
		a.rect(x, 244, 12, 3, M.RUBBER)
		a.rect(x + 2, 242, 7, 2, M.CONCRETE)

	# Broken viaduct: its descending slab segments and one missing pier create
	# a legible diagonal above the straight, sheltered road underneath.
	var slabs: Array[Vector3i] = [Vector3i(0, 161, 39), Vector3i(37, 170, 35),
		Vector3i(71, 179, 36), Vector3i(109, 190, 32), Vector3i(146, 203, 28)]
	for slab: Vector3i in slabs:
		a.rect(slab.x, slab.y, slab.z, 12, M.CONCRETE)
		a.rect(slab.x, slab.y, slab.z, 3, M.WET_ASPHALT)
		a.rect(slab.x + 4, slab.y + 9, slab.z - 7, 2, M.RUSTED_STEEL)
		a.rect(slab.x + 5, slab.y - 9, 3, 9, M.IRON)
		a.rect(slab.x + 4, slab.y - 10, slab.z - 8, 2, M.STEEL)
		a.rect(slab.x + slab.z - 8, slab.y + 12, 2, 7, M.STEEL)
	for pier: Vector3i in [Vector3i(26, 178, 61), Vector3i(98, 194, 43)]:
		a.rect(pier.x - 4, pier.y, 21, pier.z, M.CONCRETE)
		a.rect(pier.x, pier.y, 7, pier.z, M.SLATE)
		a.rect(pier.x - 7, pier.y + pier.z - 5, 27, 7, M.GRANITE)
		a.rect(pier.x - 3, pier.y + 7, 2, pier.z - 12, M.STEEL)
		a.rect(pier.x + 12, pier.y + 15, 3, 8, M.EMPTY)
	a.beam(Vector2i(58, 185), Vector2i(78, 229), 5, M.IRON, 5)
	a.beam(Vector2i(112, 205), Vector2i(140, 236), 5, M.RUSTED_STEEL, 5)
	a.rect(66, 213, 28, 4, M.CORRUGATED)
	a.rect(68, 216, 4, 21, M.STEEL)
	a.rect(84, 218, 3, 19, M.IRON)
	a.lamp(78, 211, M.AMBER, 5)

	# A leaning transmission frame carries the only tall silhouette on this side.
	a.beam(Vector2i(46, 74), Vector2i(68, 159), 7, M.IRON, 6)
	a.beam(Vector2i(49, 80), Vector2i(71, 157), 3, M.STEEL, 4)
	a.rect(35, 87, 44, 5, M.RUSTED_STEEL)
	a.rect(40, 116, 43, 4, M.IRON)
	a.rect(44, 138, 32, 4, M.STEEL)
	for x: int in [37, 52, 72]:
		a.rect(x, 78, 4, 10, M.INSULATION)
		a.rect(x - 1, 80, 6, 2, M.STEEL)
		a.rect(x - 1, 84, 6, 2, M.STEEL)
	a.rect(47, 65, 3, 14, M.STEEL)
	a.rect(46, 63, 5, 3, M.AMBER)
	_cable(a, [Vector2i(0, 104), Vector2i(12, 111), Vector2i(25, 114),
		Vector2i(37, 112), Vector2i(51, 102), Vector2i(72, 91)])
	_cable(a, [Vector2i(73, 90), Vector2i(99, 110), Vector2i(127, 124),
		Vector2i(157, 131), Vector2i(185, 128), Vector2i(212, 118), Vector2i(235, 101)])
	a.rect(233, 96, 5, 55, M.STEEL)
	a.rect(231, 146, 10, 4, M.RUSTED_STEEL)
	a.rect(236, 104, 3, 40, M.RUBBER)

	# Half-buried intake station: dense service detail remains above the road cut.
	a.rect(173, 191, 130, 56, M.CONCRETE)
	a.rect(179, 197, 118, 45, M.INDUSTRIAL_BRICK)
	a.rect(169, 189, 136, 5, M.ASPHALT)
	a.rect(177, 194, 125, 2, M.STEEL)
	a.panel(184, 204, 28, 37, M.EMPTY, M.IRON, 4)
	a.rect(187, 203, 23, 3, M.HAZARD)
	a.rect(183, 239, 29, 4, M.WET_COBBLE)
	a.vent(222, 204, 68, 29)
	a.ribs(224, 200, 64, 4, 13, M.RUSTED_STEEL)
	a.pipe(Vector2i(174, 218), Vector2i(174, 240), 7, M.STEEL_PIPE)
	a.pipe(Vector2i(179, 241), Vector2i(293, 241), 7, M.VERDIGRIS)
	a.console(216, 173, 31, 14, M.CYAN)
	a.rect(211, 180, 4, 9, M.IRON)
	a.rect(249, 181, 3, 10, M.IRON)
	a.panel(263, 169, 29, 20, M.CORRUGATED, M.IRON, 3)
	a.bolts(263, 169, 29, 20)
	a.lamp(186, 197, M.AMBER, 7)
	a.label("A1", 281, 194, M.AMBER)

	# The western well doglegs at x144/y302 to the shared x96 bottom opening.
	a.rect(124, 280, 6, 23, M.CONCRETE)
	a.rect(158, 279, 10, 40, M.IRON)
	a.rect(166, 282, 8, 35, M.CORRUGATED)
	a.rect(112, 277, 57, 6, M.HAZARD)
	a.rect(82, 283, 47, 5, M.IRON)
	a.rect(78, 286, 4, 34, M.STEEL_PIPE)
	a.rect(111, 316, 40, 4, M.STEEL)
	a.panel(183, 290, 33, 23, M.RUBBER, M.IRON, 3)
	a.console(225, 289, 24, 17, M.AMBER)
	a.vent(262, 288, 39, 26)
	a.lamp(114, 281, M.AMBER, 4)
	for y: int in [289, 302, 315]:
		a.rect(117, y, 6, 2, M.STEEL)
		a.rect(169, y, 3, 2, M.AMBER)
	a.rubble(180, 248, 130, 26, 3)
	for x: int in range(50, 316, 29):
		a.rect(x, 277, 13, 2, M.CONCRETE)


static func _aster_research(a: Variant) -> void:
	_strata(a)
	# Fortified mass, with a readable upper chamber and a deliberately compressed
	# service gallery following the frozen x58 / x122 / x250 dogleg below it.
	a.rect(31, 73, 274, 244, M.CONCRETE)
	a.rect(40, 84, 254, 224, M.INDUSTRIAL_BRICK)
	a.rect(75, 94, 191, 94, M.EMPTY)
	a.rect(81, 101, 179, 6, M.LEAD)
	a.rect(76, 182, 191, 8, M.IRON)
	a.rect(83, 180, 176, 2, M.STEEL)
	a.rect(23, 70, 289, 7, M.ASPHALT)
	a.rect(34, 63, 267, 7, M.CONCRETE)
	a.rect(72, 55, 98, 9, M.CORRUGATED)
	a.rect(179, 54, 111, 10, M.IRON)
	a.rect(181, 52, 109, 2, M.RUSTED_STEEL)
	for x: int in [30, 65, 270, 295]:
		a.rect(x, 79, 11, 149, M.CONCRETE)
		a.rect(x + 3, 82, 3, 139, M.PAINTED_STEEL)
		a.rect(x - 2, 128, 15, 6, M.IRON)
		a.rect(x - 2, 176, 15, 6, M.IRON)
		a.rect(x + 2, 227, 6, 12, M.HAZARD)
	a.rect(74, 91, 193, 3, M.STEEL)
	a.rect(78, 108, 3, 71, M.STEEL_PIPE)
	a.rect(259, 107, 4, 72, M.COPPER_PIPE)
	a.ribs(88, 96, 166, 8, 19, M.PAINTED_STEEL)

	# Three layered containment cassettes; their narrow windows carry most of the
	# clinical light without turning the whole building into an emissive panel.
	for x: int in [145, 184, 223]:
		a.rect(x, 113, 26, 62, M.IRON)
		a.rect(x + 3, 117, 20, 52, M.PAINTED_STEEL)
		a.rect(x + 5, 121, 16, 43, M.CHEMICAL_GLASS)
		a.rect(x + 8, 126, 2, 31, M.CYAN)
		a.rect(x + 12, 128, 5, 22, M.DARK_GLASS)
		a.rect(x - 2, 112, 30, 5, M.STEEL)
		a.rect(x - 3, 169, 32, 7, M.RUSTED_STEEL)
		a.rect(x + 8, 107, 10, 5, M.COPPER_PIPE)
		a.rect(x + 3, 154, 21, 3, M.IRON)
		a.rect(x + 18, 123, 2, 4, M.WHITE)
		a.rect(x + 18, 135, 2, 3, M.STEEL)
		a.rect(x + 18, 145, 2, 3, M.STEEL)
		a.rect(x + 11, 177, 7, 5, M.RUBBER)
	a.pipe(Vector2i(142, 108), Vector2i(250, 108), 6, M.STEEL_PIPE)
	a.panel(87, 112, 44, 49, M.DARK_GLASS, M.IRON, 3)
	for y: int in [119, 134]:
		a.console(92, y, 32, 12, M.CYAN)
	a.rect(87, 163, 42, 5, M.PAINTED_STEEL)
	a.rect(90, 169, 6, 11, M.IRON)
	a.rect(120, 169, 6, 11, M.IRON)
	a.rect(102, 164, 8, 1, M.AMBER)

	# Roof plant and a cramped antenna crown remain subordinate to the chamber.
	a.vent(87, 59, 72, 13)
	a.panel(181, 30, 31, 22, M.CORRUGATED, M.IRON, 3)
	a.rect(186, 24, 4, 6, M.STEEL_PIPE)
	a.rect(202, 19, 3, 11, M.STEEL_PIPE)
	a.rect(228, 34, 50, 18, M.CORRUGATED)
	a.rect(232, 31, 46, 3, M.IRON)
	a.rect(248, 21, 4, 13, M.STEEL)
	a.rect(237, 20, 30, 2, M.STEEL)
	a.rect(263, 18, 3, 5, M.AMBER)
	a.pipe(Vector2i(281, 91), Vector2i(281, 162), 7, M.VERDIGRIS)
	a.pipe(Vector2i(273, 190), Vector2i(296, 190), 7, M.COPPER_PIPE)
	a.vent(11, 149, 19, 59)
	a.rect(6, 139, 25, 10, M.CONCRETE)
	a.rect(13, 207, 18, 35, M.IRON)
	a.pipe(Vector2i(20, 210), Vector2i(20, 239), 7, M.VERDIGRIS)
	a.label("A", 45, 83, M.AMBER)
	a.label("1", 49, 94, M.STEEL)
	a.lamp(243, 84, M.CYAN, 9)

	# Intake riser and switchback gallery: equipment is recessed outside the
	# protected route, so final carving exposes intentional sills and bulkheads.
	a.rect(0, 237, 43, 10, M.CONCRETE)
	a.rect(8, 245, 36, 3, M.HAZARD)
	a.rect(40, 187, 6, 53, M.IRON)
	a.rect(73, 190, 6, 89, M.IRON)
	a.rect(42, 183, 97, 7, M.CONCRETE)
	a.rect(72, 218, 36, 6, M.STEEL)
	a.rect(77, 222, 28, 29, M.CORRUGATED)
	a.console(82, 229, 21, 15, M.AMBER)
	a.lamp(84, 182, M.AMBER, 6)
	a.rect(139, 194, 67, 29, M.IRON)
	a.rect(144, 198, 57, 20, M.CORRUGATED)
	a.vent(150, 199, 44, 18)
	a.rect(141, 221, 61, 3, M.HAZARD)
	a.rect(208, 194, 57, 29, M.PAINTED_STEEL)
	a.console(213, 198, 46, 19, M.CYAN)
	a.rect(135, 252, 73, 6, M.STEEL)
	a.rect(135, 258, 72, 21, M.RUSTED_STEEL)
	a.vent(147, 262, 49, 14)
	a.rect(268, 230, 44, 17, M.CONCRETE)
	a.rect(273, 239, 35, 7, M.HAZARD)
	a.lamp(282, 233, M.AMBER, 5)
	for x: int in [83, 148, 182, 276]:
		a.rect(x, 280, 19, 5, M.IRON)
		a.rect(x + 2, 278, 13, 2, M.RUSTED_STEEL)

	# The x224 containment throat descends between two instrument cabinets.
	a.rect(201, 277, 9, 43, M.IRON)
	a.rect(238, 277, 9, 43, M.IRON)
	a.rect(202, 279, 7, 5, M.HAZARD)
	a.rect(239, 279, 7, 5, M.HAZARD)
	a.pipe(Vector2i(195, 289), Vector2i(195, 316), 6, M.COPPER_PIPE)
	a.pipe(Vector2i(251, 287), Vector2i(251, 315), 6, M.STEEL_PIPE)
	a.panel(142, 287, 39, 28, M.DARK_GLASS, M.IRON, 3)
	a.console(147, 292, 29, 17, M.CYAN)
	a.panel(267, 286, 35, 30, M.CORRUGATED, M.IRON, 3)
	a.bolts(267, 286, 35, 30)
	a.lamp(187, 283, M.AMBER, 4)
	a.lamp(251, 279, M.CYAN, 4)
	for y: int in [291, 303, 314]:
		a.rect(201, y, 3, 2, M.STEEL)
		a.rect(244, y, 3, 2, M.STEEL)


static func _ashworks_breach(a: Variant) -> void:
	_strata(a)
	# The tram platform gives way to a deep scrapyard trench, distinguishing this
	# side from the west's diagonal viaduct and flatter intake road.
	a.rect(0, 241, 49, 36, M.CONCRETE)
	a.rect(4, 237, 39, 5, M.ASPHALT)
	a.rect(52, 252, 106, 68, M.CONCRETE)
	a.rect(58, 252, 98, 4, M.STEEL)
	a.rect(159, 288, 147, 32, M.SLATE)
	a.rect(160, 288, 146, 4, M.WET_COBBLE)
	a.rect(305, 254, 15, 66, M.GRANITE)
	a.rect(298, 250, 22, 6, M.CONCRETE)
	a.rect(15, 227, 30, 10, M.RUSTED_STEEL)
	a.rect(83, 213, 56, 10, M.SLATE)
	a.rect(104, 220, 39, 4, M.CONCRETE)

	# Buried cargo tram: capped windows, a ribbed goods bay and broken running gear.
	a.rect(10, 171, 116, 46, M.IRON)
	a.rect(15, 176, 106, 35, M.PAINTED_STEEL)
	a.rect(21, 166, 94, 5, M.RUSTED_STEEL)
	a.rect(16, 211, 101, 6, M.STEEL)
	a.panel(20, 179, 30, 20, M.DARK_GLASS, M.IRON, 3)
	a.rect(25, 183, 3, 11, M.CHEMICAL_GLASS)
	a.rect(35, 182, 9, 2, M.CYAN)
	a.panel(54, 176, 25, 34, M.CORRUGATED, M.IRON, 3)
	a.rect(71, 187, 2, 8, M.BRONZE)
	a.panel(84, 177, 31, 32, M.CORRUGATED, M.IRON, 3)
	a.ribs(88, 182, 21, 22, 7, M.RUSTED_STEEL)
	for x: int in [27, 93]:
		a.ellipse(x, 220, 13, 7, M.RUBBER, 3)
		a.rect(x - 5, 216, 10, 6, M.IRON)
		a.rect(x - 2, 218, 4, 3, M.STEEL)
	a.rect(12, 226, 117, 4, M.STEEL)
	a.rect(18, 230, 12, 3, M.RUSTED_STEEL)
	a.rect(88, 229, 21, 4, M.RUSTED_STEEL)
	a.lamp(15, 201, M.AMBER, 4)
	a.rect(112, 204, 5, 2, M.AMBER)
	a.label("3", 103, 166, M.STEEL)

	# Broken receiver dish: one thick crescent and a short feed arm keep the
	# silhouette economical. The missing upper-left rim is actual Empty space.
	a.ellipse(171, 107, 62, 33, M.IRON, 4)
	a.ellipse(168, 99, 56, 30, M.EMPTY, 4)
	a.rect(106, 70, 33, 39, M.EMPTY)
	a.beam(Vector2i(140, 109), Vector2i(171, 131), 4, M.STEEL, 4)
	a.rect(138, 104, 9, 8, M.DARK_GLASS)
	a.rect(139, 106, 4, 2, M.CYAN)
	a.beam(Vector2i(172, 139), Vector2i(198, 208), 9, M.IRON, 8)
	a.beam(Vector2i(177, 143), Vector2i(202, 209), 3, M.RUSTED_STEEL, 5)
	a.rect(183, 206, 34, 14, M.CONCRETE)
	a.rect(180, 219, 40, 5, M.STEEL)
	a.rect(185, 205, 31, 4, M.HAZARD)
	a.pipe(Vector2i(211, 164), Vector2i(211, 205), 6, M.VERDIGRIS)
	a.rect(190, 153, 21, 10, M.CORRUGATED)
	a.rect(188, 149, 22, 4, M.RUSTED_STEEL)

	# Abandoned lifting crane wraps the dish, with the hook over a stacked load.
	a.rect(255, 78, 10, 144, M.IRON)
	a.rect(258, 81, 3, 138, M.STEEL)
	a.rect(250, 213, 23, 13, M.CONCRETE)
	a.rect(248, 224, 28, 6, M.RUSTED_STEEL)
	for y: int in [92, 123, 154, 185]:
		a.rect(253, y, 14, 3, M.RUSTED_STEEL)
		a.rect(259, y + 5, 2, 4, M.AMBER)
	a.beam(Vector2i(262, 81), Vector2i(313, 113), 7, M.IRON, 6)
	a.beam(Vector2i(225, 102), Vector2i(263, 82), 6, M.RUSTED_STEEL, 6)
	a.rect(219, 98, 15, 15, M.LEAD)
	a.rect(218, 111, 17, 5, M.IRON)
	a.rect(305, 113, 2, 64, M.RUBBER)
	a.rect(301, 176, 10, 8, M.IRON)
	a.rect(303, 183, 3, 7, M.RUSTED_STEEL)
	a.rect(303, 189, 8, 3, M.IRON)
	a.rect(309, 184, 3, 8, M.IRON)
	a.panel(275, 201, 39, 25, M.CORRUGATED, M.IRON, 3)
	a.panel(274, 227, 39, 20, M.RUSTED_STEEL, M.IRON, 3)
	a.bolts(275, 201, 39, 25)
	a.rect(280, 200, 13, 2, M.HAZARD)
	_cable(a, [Vector2i(24, 136), Vector2i(58, 150), Vector2i(90, 157),
		Vector2i(119, 153), Vector2i(145, 144)])
	a.rect(21, 125, 4, 40, M.STEEL)
	a.rect(19, 123, 9, 4, M.IRON)

	# The service descent meets the x144 bottom portal. Small cabinets and a
	# corroded pipe turn give the cut below the raised platform an authored edge.
	a.rect(124, 262, 6, 58, M.IRON)
	a.rect(158, 290, 7, 30, M.IRON)
	a.rect(118, 256, 11, 6, M.HAZARD)
	a.rect(159, 290, 8, 6, M.HAZARD)
	a.panel(64, 280, 47, 35, M.CORRUGATED, M.IRON, 3)
	a.console(71, 286, 32, 19, M.CYAN)
	a.lamp(112, 276, M.AMBER, 4)
	a.pipe(Vector2i(54, 281), Vector2i(54, 315), 7, M.COPPER_PIPE)
	a.pipe(Vector2i(178, 304), Vector2i(289, 304), 8, M.VERDIGRIS)
	a.vent(200, 290, 53, 12)
	a.rect(282, 290, 9, 10, M.STEEL_PIPE)
	for y: int in [274, 289, 307]:
		a.rect(126, y, 3, 3, M.STEEL)
	a.rubble(174, 232, 122, 26, 8)
	a.rubble(5, 277, 36, 34, 13)
	for x: int in [172, 215, 267]:
		a.rect(x, 288, 17, 2, M.RUSTED_STEEL)


static func _service_fittings(a: Variant, column: int) -> void:
	match column:
		0:
			# A stranded transformer and exposed reinforcing rods explain the
			# failed viaduct, while hand controls mark the maintenance well.
			a.panel(112, 145, 49, 25, M.CORRUGATED, M.IRON, 3)
			a.bolts(112, 145, 49, 25)
			a.vent(119, 151, 34, 16)
			a.pipe(Vector2i(116, 141), Vector2i(153, 141), 5, M.COPPER_PIPE)
			a.rect(150, 129, 7, 10, M.STEEL_PIPE)
			a.rect(148, 128, 11, 3, M.IRON)
			a.rect(150, 127, 7, 1, M.RUSTED_STEEL)
			for x: int in [145, 153, 161]:
				a.rect(x, 214, 1, 12, M.STEEL)
				a.rect(x - 2, 225, 3, 1, M.STEEL)
			a.rect(192, 296, 3, 9, M.STEEL)
			a.rect(189, 299, 9, 2, M.STEEL)
			a.rect(202, 297, 3, 2, M.AMBER)
			a.rect(188, 308, 21, 1, M.RUSTED_STEEL)
			a.pipe(Vector2i(296, 150), Vector2i(296, 183), 6, M.STEEL_PIPE)
			a.rect(290, 148, 8, 5, M.IRON)
			a.lamp(301, 199, M.AMBER, 4)
			a.ribs(0, 153, 27, 5, 9, M.RUSTED_STEEL)
		1:
			# A narrow observation slit and the dense recorder rack contrast the
			# larger containment shapes; all sit outside the reserved body route.
			a.panel(44, 111, 17, 62, M.CHEMICAL_GLASS, M.IRON, 3)
			for y: int in [119, 132, 145, 158]:
				a.rect(48, y, 7, 1, M.CYAN)
				a.rect(46, y + 4, 13, 2, M.IRON)
			a.panel(274, 97, 15, 25, M.DARK_GLASS, M.IRON, 2)
			a.rect(278, 102, 6, 1, M.AMBER)
			a.rect(278, 108, 3, 2, M.CYAN)
			a.panel(99, 35, 62, 18, M.CORRUGATED, M.IRON, 3)
			a.vent(109, 39, 44, 11)
			a.rect(99, 34, 62, 1, M.RUSTED_STEEL)
			for x: int in [145, 184, 223]:
				a.bolts(x, 113, 26, 62)
			a.pipe(Vector2i(139, 186), Vector2i(252, 186), 5, M.COPPER_PIPE)
			a.panel(30, 285, 87, 29, M.DARK_GLASS, M.IRON, 3)
			a.console(37, 290, 25, 18, M.CYAN)
			a.console(67, 290, 25, 18, M.AMBER)
			a.pipe(Vector2i(106, 291), Vector2i(106, 308), 5, M.STEEL_PIPE)
			a.rect(97, 289, 4, 2, M.AMBER)
			a.rect(96, 299, 4, 5, M.CORRUGATED)
			a.lamp(12, 279, M.AMBER, 4)
		2:
			# The pulley, load guide and roof equipment give the two abandoned
			# vehicles distinct mechanisms instead of adding scattered debris.
			a.ellipse(260, 87, 12, 13, M.RUSTED_STEEL, 3)
			a.ellipse(260, 87, 7, 8, M.RUBBER, 3)
			a.rect(257, 84, 6, 6, M.STEEL)
			a.rect(259, 85, 2, 4, M.IRON)
			a.rect(270, 135, 5, 60, M.STEEL_PIPE)
			a.rect(269, 145, 8, 4, M.IRON)
			a.rect(269, 183, 8, 4, M.IRON)
			a.panel(276, 134, 19, 28, M.CORRUGATED, M.IRON, 3)
			a.bolts(276, 134, 19, 28)
			a.panel(33, 150, 27, 14, M.DARK_GLASS, M.IRON, 2)
			a.bolts(33, 150, 27, 14)
			a.rect(38, 154, 13, 1, M.STEEL)
			a.rect(50, 158, 4, 2, M.AMBER)
			_cable(a, [Vector2i(58, 162), Vector2i(73, 167), Vector2i(85, 163)])
			a.panel(178, 291, 18, 25, M.CHEMICAL_GLASS, M.IRON, 2)
			a.rect(183, 296, 2, 13, M.CYAN)
			a.rect(182, 312, 10, 2, M.STEEL)
			a.panel(3, 285, 39, 30, M.CORRUGATED, M.IRON, 3)
			a.vent(8, 290, 29, 16)
			a.lamp(14, 280, M.AMBER, 5)
			a.rect(164, 303, 5, 2, M.AMBER)
			a.rect(164, 308, 3, 1, M.STEEL)
