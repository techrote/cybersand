class_name CyberGreyArea51East
extends RefCounted

# Two buried machine rooms in the eastern end of the concrete installation.
# The composer supplies the Concrete slab and cuts the final 24-cell passages.
# Dark inspection pockets are sealed machine faces, not disconnected rooms.
# Every pipe, pane, cable and light is an ordinary solid native material.
const Art = preload("res://scripts/grey_area_51_art.gd")
const M = preload("res://scripts/neon_reliquary.gd")


static func tile(index: int) -> PackedInt32Array:
	var art = Art.new()
	match index:
		3: _isotope_engine(art)
		4: _disposal_lock(art)
	return art.data


static func _fasteners(art, x: int, y: int, length: int,
		vertical: bool = false, pitch: int = 11) -> void:
	for offset: int in range(3, length - 2, pitch):
		var xx: int = x if vertical else x + offset
		var yy: int = y + offset if vertical else y
		art.rect(xx, yy, 2, 2, M.STEEL)
		art.rect(xx + 1, yy + 1, 1, 1, M.RUBBER)


static func _gauge(art, x: int, y: int, light: int = M.WHITE) -> void:
	art.panel(x, y, 9, 11, M.DARK_GLASS, M.IRON, 2)
	art.rect(x + 3, y + 3, 1, 5, M.LEAD)
	art.rect(x + 4, y + 5, 2, 1, light)
	art.rect(x + 4, y + 8, 2, 1, M.RUSTED_STEEL)


static func _cast_rail(art, x: int, y: int, width: int, height: int) -> void:
	# The exposed edge is a narrow steel bracket; the bulk is cast shielding.
	art.rect(x, y, width, height, M.CONCRETE)
	if width > height:
		art.rect(x, y, width, 1, M.IRON)
	else:
		art.rect(x, y, 1, height, M.IRON)


static func _isotope_engine(art) -> void:
	# The visitor passes below the engine at y144, then climbs at x120. The
	# vessel and its clamp beds stop short of that entire reservation.
	art.rect(20, 17, 77, 1, M.LEAD)
	art.rect(12, 26, 5, 93, M.CONCRETE)
	art.rect(101, 18, 5, 108, M.CONCRETE)
	art.rect(20, 21, 77, 1, M.LEAD)
	art.rect(20, 128, 77, 1, M.RUSTED_STEEL)
	art.rect(22, 29, 1, 89, M.STEEL)
	art.rect(95, 28, 1, 92, M.LEAD)
	_fasteners(art, 18, 19, 83)
	_fasteners(art, 99, 24, 100, true, 17)
	# An unequal cylindrical pressure body is built into a close concrete cut.
	# Its cap, long jacket and lower sump read as one heavy mechanical object.
	art.ellipse(60, 40, 31, 20, M.IRON, 2)
	art.ellipse(60, 39, 30, 19, M.CONCRETE, 2)
	art.rect(29, 39, 63, 62, M.IRON)
	art.rect(31, 39, 59, 60, M.CONCRETE)
	art.ellipse(60, 100, 31, 19, M.IRON, 2)
	art.ellipse(60, 99, 30, 18, M.CONCRETE, 2)
	art.rect(39, 38, 43, 61, M.CONCRETE)
	art.rect(35, 41, 2, 55, M.STEEL)
	art.rect(85, 43, 1, 52, M.RUSTED_STEEL)
	art.rect(75, 42, 2, 56, M.IRON)
	art.rect(43, 42, 2, 55, M.RUBBER)
	# Shielding collars have separate clamp ears, threaded ends and worn edges.
	for y: int in [34, 72, 101]:
		_cast_rail(art, 25, y, 71, 7)
		art.rect(35, y + 5, 12, 1, M.RUSTED_STEEL)
		art.rect(23, y + 1, 5, 5, M.LEAD)
		art.rect(90, y - 1, 7, 9, M.LEAD)
		art.rect(24, y + 2, 2, 2, M.RUBBER)
		art.rect(92, y + 2, 2, 2, M.RUBBER)
	# The isotope is only a narrow solid sight-glass slit, behind a braced cover.
	art.panel(49, 46, 20, 49, M.CONCRETE, M.IRON, 1)
	art.rect(53, 50, 12, 39, M.DARK_GLASS)
	art.rect(53, 50, 2, 39, M.CHEMICAL_GLASS)
	art.rect(58, 51, 3, 36, M.RUBBER)
	art.rect(59, 55, 1, 10, M.WHITE)
	art.rect(59, 69, 1, 12, M.CYAN)
	art.rect(64, 50, 1, 39, M.LEAD)
	for y: int in [52, 62, 82, 90]:
		art.rect(47, y, 24, 2, M.IRON)
		art.rect(48, y, 2, 1, M.STEEL)
		art.rect(68, y, 2, 1, M.STEEL)
	art.rect(48, 70, 22, 5, M.LEAD)
	art.rect(51, 71, 16, 1, M.RUSTED_STEEL)
	# Feed neck and insulation sleeves disappear into the roof mass.
	_cast_rail(art, 44, 10, 31, 14)
	art.rect(47, 12, 25, 8, M.CONCRETE)
	_cast_rail(art, 40, 20, 40, 5)
	art.pipe(Vector2i(48, 3), Vector2i(48, 17), 5, M.STEEL_PIPE)
	art.pipe(Vector2i(64, 0), Vector2i(64, 15), 5, M.STEEL_PIPE)
	art.rect(67, 4, 4, 10, M.INSULATION)
	_cast_rail(art, 38, 16, 6, 14)
	_cast_rail(art, 76, 17, 6, 13)
	art.panel(45, 109, 28, 12, M.CONCRETE, M.IRON, 1)
	art.rect(52, 114, 14, 5, M.RUSTED_STEEL)
	_cast_rail(art, 47, 121, 25, 6)
	art.rect(37, 129, 45, 1, M.IRON)
	# Short external measuring lines cling to the vessel instead of crossing
	# its illuminated window or the adjacent circulation shaft.
	art.pipe(Vector2i(14, 45), Vector2i(14, 113), 3, M.STEEL_PIPE)
	art.pipe(Vector2i(14, 45), Vector2i(29, 45), 3, M.STEEL_PIPE)
	art.pipe(Vector2i(14, 113), Vector2i(40, 113), 3, M.STEEL_PIPE)
	art.rect(12, 75, 7, 15, M.IRON)
	_gauge(art, 9, 76)
	art.rect(89, 49, 5, 18, M.RUBBER)
	art.rect(90, 51, 2, 12, M.LEAD)
	art.rect(90, 85, 4, 10, M.RUSTED_STEEL)
	art.lamp(95, 121, M.WHITE, 5)
	# Quiet roof concrete separates the main vessel from this upper manifold.
	art.pipe(Vector2i(90, 10), Vector2i(180, 10), 3, M.STEEL_PIPE)
	art.pipe(Vector2i(180, 10), Vector2i(180, 39), 3, M.STEEL_PIPE)
	art.pipe(Vector2i(111, 22), Vector2i(171, 22), 3, M.LEAD)
	_cast_rail(art, 108, 4, 8, 25)
	art.rect(110, 5, 2, 22, M.RUSTED_STEEL)
	_cast_rail(art, 163, 6, 7, 22)
	art.rect(165, 8, 2, 19, M.LEAD)
	art.panel(136, 29, 35, 17, M.CONCRETE, M.IRON, 1)
	art.rect(141, 33, 14, 2, M.DARK_GLASS)
	art.rect(141, 34, 8, 1, M.WHITE)
	art.rect(141, 39, 8, 2, M.LEAD)
	art.rect(160, 34, 4, 7, M.STEEL)
	art.rect(162, 36, 1, 3, M.AMBER)
	art.lamp(145, 47, M.WHITE, 8)
	# Two unequal isolation drums occupy a sealed recess below the exit gallery.
	art.panel(139, 84, 43, 43, M.CONCRETE, M.LEAD, 1)
	_cast_rail(art, 143, 94, 16, 24)
	art.ellipse(151, 94, 8, 6, M.LEAD, 2)
	art.ellipse(151, 117, 8, 5, M.IRON, 2)
	art.rect(147, 96, 3, 19, M.RUSTED_STEEL)
	art.rect(143, 105, 16, 3, M.IRON)
	_cast_rail(art, 164, 99, 12, 21)
	art.ellipse(170, 99, 6, 5, M.STEEL, 2)
	art.ellipse(170, 119, 6, 4, M.IRON, 2)
	art.rect(165, 110, 11, 3, M.IRON)
	art.rect(167, 101, 2, 7, M.CHEMICAL_GLASS)
	art.rect(154, 85, 5, 9, M.STEEL_PIPE)
	art.rect(166, 86, 5, 10, M.RUSTED_STEEL)
	art.rect(144, 123, 32, 2, M.GRATING)
	art.bolts(139, 84, 43, 43)
	# Recessed service panels punctuate the otherwise unpainted bottom slab.
	art.panel(20, 166, 77, 17, M.CONCRETE, M.LEAD, 1)
	art.rect(24, 170, 12, 8, M.RUBBER)
	art.rect(27, 172, 6, 1, M.AMBER)
	art.label("04", 42, 172, M.LEAD)
	art.rect(57, 171, 32, 1, M.RUBBER)
	art.rect(57, 175, 22, 1, M.RUBBER)
	art.bolts(20, 166, 77, 17)
	_cast_rail(art, 147, 161, 32, 20)
	for y: int in [166, 171, 176]:
		art.rect(151, y, 24, 1, M.RUBBER)
	art.pipe(Vector2i(163, 128), Vector2i(163, 157), 3, M.STEEL_PIPE)
	_cast_rail(art, 154, 151, 18, 5)
	art.rect(158, 152, 10, 1, M.RUSTED_STEEL)


static func _disposal_lock(art) -> void:
	# The upper throat at y64 turns down x56 and approaches the sealed terminal
	# at y144. All three sides of the press remain thick native Concrete.
	art.rect(84, 17, 94, 1, M.LEAD)
	_cast_rail(art, 83, 20, 9, 105)
	art.rect(85, 25, 1, 92, M.STEEL)
	_cast_rail(art, 173, 20, 6, 104)
	art.rect(177, 25, 1, 91, M.RUSTED_STEEL)
	art.rect(88, 20, 87, 10, M.CONCRETE)
	art.rect(92, 23, 77, 1, M.STEEL)
	art.rect(87, 120, 87, 6, M.CONCRETE)
	art.rect(93, 120, 75, 1, M.RUSTED_STEEL)
	_fasteners(art, 81, 19, 99)
	_fasteners(art, 80, 38, 86, true, 15)
	_fasteners(art, 178, 36, 87, true, 15)
	# A capped diagonal chute disappears into an overhanging concrete shoulder.
	art.beam(Vector2i(158, 0), Vector2i(137, 26), 17, M.IRON, 3)
	art.beam(Vector2i(158, 0), Vector2i(138, 25), 15, M.CONCRETE, 3)
	art.rect(145, 1, 26, 4, M.RUSTED_STEEL)
	_cast_rail(art, 124, 22, 31, 7)
	art.rect(128, 23, 23, 2, M.RUBBER)
	# The upper ram has unequal pistons, retaining straps and a crushing plate.
	art.panel(100, 31, 58, 18, M.CONCRETE, M.IRON, 1)
	art.rect(104, 34, 49, 10, M.CONCRETE)
	art.rect(106, 35, 44, 2, M.LEAD)
	art.rect(111, 48, 9, 19, M.STEEL)
	art.rect(143, 47, 7, 20, M.LEAD)
	art.rect(113, 49, 2, 17, M.RUBBER)
	art.rect(145, 49, 1, 16, M.RUSTED_STEEL)
	art.rect(105, 48, 20, 5, M.IRON)
	art.rect(137, 48, 20, 5, M.IRON)
	_cast_rail(art, 97, 64, 69, 9)
	art.rect(102, 71, 58, 1, M.RUSTED_STEEL)
	for x: int in [106, 118, 130, 142, 154]:
		art.rect(x, 73, 4, 5, M.LEAD)
		art.rect(x, 77, 4, 1, M.STEEL)
	art.bolts(101, 31, 56, 18)
	# A round shield cask sits almost against the jaw: an iris, offset seams,
	# bolt ring and narrow sodium sightline suggest sealed machinery, not fire.
	art.ellipse(131, 98, 29, 23, M.IRON, 2)
	art.ellipse(131, 97, 27, 22, M.CONCRETE, 2)
	art.ellipse(131, 97, 16, 12, M.RUBBER, 2)
	for point: Vector2i in [Vector2i(113,85), Vector2i(129,79), Vector2i(147,86),
		Vector2i(154,98), Vector2i(148,111), Vector2i(131,116),
		Vector2i(113,110), Vector2i(107,98)]:
		art.rect(point.x, point.y, 2, 2, M.IRON)
		art.rect(point.x, point.y, 1, 1, M.STEEL)
	art.beam(Vector2i(119,89), Vector2i(137,91), 3, M.LEAD, 3)
	art.beam(Vector2i(141,90), Vector2i(138,102), 3, M.LEAD, 3)
	art.beam(Vector2i(140,105), Vector2i(124,102), 3, M.LEAD, 3)
	art.beam(Vector2i(120,101), Vector2i(126,91), 3, M.LEAD, 3)
	art.rect(126, 93, 9, 8, M.IRON)
	art.rect(129, 95, 4, 4, M.DARK_GLASS)
	art.rect(130, 96, 1, 2, M.AMBER)
	art.rect(96, 113, 16, 8, M.IRON)
	art.rect(153, 111, 17, 10, M.IRON)
	art.rect(99, 112, 10, 3, M.LEAD)
	art.rect(157, 110, 9, 3, M.LEAD)
	# Close machinery on the left shoulder gives the narrow downshaft scale.
	art.panel(8, 84, 28, 44, M.CONCRETE, M.IRON, 1)
	art.pipe(Vector2i(15, 88), Vector2i(15, 122), 5, M.STEEL_PIPE)
	art.pipe(Vector2i(28, 91), Vector2i(28, 119), 3, M.LEAD)
	art.rect(11, 100, 21, 5, M.IRON)
	art.rect(12, 102, 18, 1, M.RUSTED_STEEL)
	_gauge(art, 23, 108, M.CYAN)
	art.rect(10, 122, 22, 3, M.GRATING)
	art.lamp(33, 125, M.WHITE, 5)
	# Control wires and hydraulic returns terminate inside solid service boxes.
	art.pipe(Vector2i(187, 36), Vector2i(187, 119), 3, M.STEEL_PIPE)
	art.pipe(Vector2i(157, 41), Vector2i(171, 41), 3, M.STEEL_PIPE)
	art.pipe(Vector2i(169, 41), Vector2i(169, 61), 3, M.STEEL_PIPE)
	art.rect(163, 52, 10, 10, M.IRON)
	art.rect(165, 54, 5, 6, M.RUSTED_STEEL)
	art.rect(92, 35, 3, 24, M.RUBBER)
	art.rect(92, 58, 9, 3, M.RUBBER)
	art.rect(96, 41, 3, 20, M.LEAD)
	art.rect(99, 52, 5, 2, M.RUBBER)
	_gauge(art, 92, 81)
	art.console(74, 111, 22, 17, M.WHITE)
	art.rect(79, 122, 8, 2, M.RUBBER)
	art.rect(86, 123, 3, 1, M.AMBER)
	# The actual end wall is an unequal, recessed lock; the player's final
	# centre at x160 retains a clear approach through x171 before its seal.
	art.rect(173, 129, 13, 33, M.IRON)
	art.rect(175, 132, 9, 27, M.STEEL)
	art.rect(178, 133, 2, 24, M.RUBBER)
	art.rect(181, 135, 2, 21, M.LEAD)
	art.rect(172, 130, 14, 3, M.LEAD)
	art.rect(172, 158, 14, 4, M.LEAD)
	art.rect(183, 141, 4, 8, M.RUSTED_STEEL)
	art.rect(175, 136, 2, 2, M.WHITE)
	art.rect(175, 153, 2, 2, M.AMBER)
	art.rect(174, 163, 11, 8, M.IRON)
	art.rect(177, 165, 5, 4, M.RUBBER)
	art.panel(150, 160, 19, 11, M.CONCRETE, M.IRON, 1)
	art.rect(153, 163, 13, 5, M.RUBBER)
	art.rect(155, 164, 9, 1, M.RUSTED_STEEL)
	art.rect(168, 164, 9, 3, M.STEEL_PIPE)
	art.bolts(173, 129, 13, 33)
	# Sparse roof labels and a buried drain leave the broad concrete slab quiet.
	_cast_rail(art, 17, 17, 35, 20)
	art.rect(22, 22, 5, 9, M.RUBBER)
	art.rect(23, 24, 1, 3, M.WHITE)
	art.label("05", 33, 24, M.LEAD)
	art.rect(20, 34, 26, 1, M.RUSTED_STEEL)
	art.lamp(18, 46, M.WHITE, 6)
	_cast_rail(art, 84, 168, 50, 11)
	for x: int in range(89, 130, 7):
		art.rect(x, 171, 1, 5, M.RUBBER)
	art.rect(89, 177, 40, 1, M.RUSTED_STEEL)
	_cast_rail(art, 33, 159, 8, 18)
	art.rect(35, 162, 3, 11, M.RUSTED_STEEL)
