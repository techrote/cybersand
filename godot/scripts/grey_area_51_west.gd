class_name CyberGreyArea51West
extends RefCounted

# The two western districts are relief carved into the composer's solid slab.
# Their dark hardware stays close to the concrete face; the shared final route
# carve owns the inspection pocket, transfer tunnel and archive security riser.
const Art = preload("res://scripts/grey_area_51_art.gd")
const M = preload("res://scripts/neon_reliquary.gd")


static func tile(index: int) -> PackedInt32Array:
	var a = Art.new()
	match index:
		0: _intake(a)
		1: _records(a)
	return a.data


static func _intake(a: Variant) -> void:
	# Huge, largely unbroken castings overhang a much smaller human entrance.
	_slab(a, 13, 34, 85, 45)
	_slab(a, 108, 34, 72, 10, false)
	_slab(a, 8, 83, 20, 43)
	_slab(a, 80, 82, 18, 44)
	_slab(a, 111, 47, 58, 66)
	a.rect(9, 31, 89, 1, M.LEAD)
	a.rect(10, 32, 20, 1, M.STEEL)
	a.rect(111, 30, 67, 1, M.LEAD)
	a.rect(150, 31, 28, 1, M.CONCRETE)
	# Recessed guard slit: a real air cut beneath an armoured brow, with only
	# two narrow panes left. Its fractured edge remains smaller than the slab.
	a.rect(23, 48, 62, 3, M.LEAD)
	a.rect(27, 51, 54, 12, M.RUBBER)
	a.rect(30, 53, 48, 7, M.EMPTY)
	a.rect(31, 54, 17, 4, M.DARK_GLASS)
	a.rect(55, 54, 20, 4, M.DARK_GLASS)
	a.rect(34, 54, 8, 1, M.WHITE)
	a.rect(63, 54, 4, 1, M.CYAN)
	a.rect(49, 51, 4, 12, M.CONCRETE)
	a.rect(49, 52, 1, 10, M.STEEL)
	a.rect(25, 62, 58, 3, M.CONCRETE)
	a.rect(25, 65, 58, 1, M.LEAD)
	a.rect(28, 66, 14, 1, M.CONCRETE)
	for x: int in [26, 43, 65, 80]:
		_tie(a, x, 45)
	for x: int in [29, 69]:
		a.rect(x, 68, 10, 1, M.LEAD)
		a.rect(x + 1, 69, 8, 1, M.STEEL)
	# An asymmetric stepped lintel and deep concrete cheeks bracket the x52
	# inspection pocket. Lamps and pipes sit outside its 24-cell clear band.
	_slab(a, 25, 80, 56, 7, false)
	_slab(a, 31, 87, 45, 6, false)
	a.rect(29, 91, 10, 37, M.LEAD)
	a.rect(31, 92, 8, 35, M.CONCRETE)
	a.rect(37, 95, 2, 30, M.STEEL)
	a.rect(65, 90, 10, 38, M.LEAD)
	a.rect(65, 92, 8, 34, M.CONCRETE)
	a.rect(65, 95, 1, 29, M.STEEL)
	a.rect(27, 125, 12, 3, M.RUBBER)
	a.rect(65, 125, 14, 3, M.RUBBER)
	for y: int in [97, 111, 123]:
		_tie(a, 32, y)
		_tie(a, 70, y)
	a.rect(43, 76, 19, 8, M.LEAD)
	a.rect(44, 77, 17, 6, M.CONCRETE)
	a.label("01", 48, 77, M.IRON)
	a.rect(67, 94, 5, 2, M.AMBER)
	a.rect(35, 94, 2, 2, M.WHITE)
	# A dead communications plinth: relay blades, screened signal window and
	# a tightly bundled cable. These are shallow fittings, not a large room.
	a.rect(119, 53, 34, 2, M.LEAD)
	a.rect(118, 58, 40, 1, M.STEEL)
	a.rect(119, 60, 17, 26, M.RUBBER)
	a.rect(122, 62, 12, 20, M.DARK_GLASS)
	a.rect(124, 64, 7, 1, M.CYAN)
	a.rect(124, 67, 3, 1, M.STEEL)
	a.rect(124, 71, 5, 1, M.STEEL)
	a.rect(129, 75, 2, 3, M.IRON)
	a.rect(118, 86, 19, 2, M.STEEL)
	for y: int in [61, 69, 77]:
		_relay(a, 141, y, 14)
	a.rect(119, 93, 36, 1, M.LEAD)
	a.rect(121, 95, 32, 9, M.CONCRETE)
	a.label("DEAD", 125, 97, M.LEAD)
	for x: int in [121, 151]:
		_tie(a, x, 107)
	_wire(a, [Vector2i(159, 64), Vector2i(163, 64), Vector2i(163, 118), Vector2i(106, 118)], false)
	_wire(a, [Vector2i(115, 67), Vector2i(105, 67), Vector2i(105, 104), Vector2i(99, 104)], false)
	a.rect(158, 92, 5, 7, M.LEAD)
	a.rect(159, 93, 3, 4, M.STEEL)
	a.rect(160, 94, 1, 1, M.AMBER)
	# A narrow intake stack, complete with shut louvers and pinched ductwork.
	a.rect(174, 49, 7, 63, M.LEAD)
	a.rect(176, 51, 3, 59, M.RUBBER)
	for y: int in range(54, 109, 5):
		a.rect(176, y, 3, 1, M.STEEL)
	for y: int in [47, 74, 113]:
		a.rect(171, y, 12, 2, M.CONCRETE)
		_tie(a, 173, y)
	a.rect(169, 120, 16, 5, M.LEAD)
	a.rect(172, 121, 10, 2, M.CONCRETE)
	a.rect(182, 121, 1, 2, M.AMBER)
	# Compression joints and tied returns make the small opening feel buried.
	for x: int in [12, 90, 185]:
		a.rect(x, 36, 1, 35, M.LEAD)
		a.rect(x, 83, 1, 41, M.LEAD)
	a.rect(13, 74, 12, 1, M.LEAD)
	a.rect(84, 75, 13, 1, M.LEAD)
	for point: Vector2i in [Vector2i(16, 14), Vector2i(39, 14), Vector2i(86, 14),
			Vector2i(118, 14), Vector2i(163, 14), Vector2i(179, 14),
			Vector2i(18, 115), Vector2i(88, 117), Vector2i(112, 124), Vector2i(152, 124)]:
		_tie(a, point.x, point.y)
	a.label("51", 56, 11, M.LEAD)
	a.label("INTAKE", 116, 37, M.IRON)
	# Buried service drawers below the transfer floor retain broad concrete
	# fronts. A few dark seams and a thin rail describe their pressure seals.
	for x: int in [14, 55, 96, 143]:
		_slab(a, x, 164, 33, 17)
		a.rect(x + 6, 169, 21, 1, M.LEAD)
		a.rect(x + 14, 172, 5, 2, M.RUBBER)
		a.rect(x + 15, 172, 3, 1, M.STEEL)
	a.rect(18, 182, 153, 1, M.LEAD)
	a.rect(21, 183, 29, 1, M.STEEL)
	a.rect(69, 183, 44, 1, M.STEEL)
	a.rect(130, 183, 36, 1, M.STEEL)
	_wire(a, [Vector2i(18, 163), Vector2i(75, 163)], true)
	_wire(a, [Vector2i(100, 161), Vector2i(174, 161)], false)
	# Local hardware at the blind west end sits outside the cleared spawn.
	a.rect(7, 131, 3, 25, M.LEAD)
	a.rect(8, 132, 1, 20, M.STEEL)
	a.rect(4, 137, 3, 8, M.RUBBER)
	a.rect(5, 139, 1, 3, M.WHITE)
	for y: int in [130, 154, 179]:
		_tie(a, 8, y)


static func _records(a: Variant) -> void:
	# A mortuary of sealed information: each small cassette is still a solid
	# concrete plug, with narrow dark lock seams and a numbered keeper plate.
	_slab(a, 10, 35, 88, 91)
	a.rect(14, 40, 80, 2, M.LEAD)
	a.rect(17, 41, 74, 1, M.STEEL)
	a.rect(15, 123, 78, 2, M.RUBBER)
	for column: int in range(3):
		for row: int in range(3):
			_cassette(a, 18 + column * 25, 47 + row * 24, column * 3 + row)
	# Gantry clamp for lifting the plugs, retracted above the route. Its
	# hanging teeth stop at y127, before the tunnel's final clearance begins.
	a.rect(22, 118, 65, 2, M.IRON)
	a.rect(23, 118, 63, 1, M.STEEL)
	a.rect(28, 120, 7, 5, M.RUBBER)
	a.rect(73, 120, 7, 5, M.RUBBER)
	a.rect(30, 120, 3, 4, M.STEEL)
	a.rect(75, 120, 3, 4, M.STEEL)
	a.rect(33, 124, 42, 2, M.LEAD)
	a.rect(35, 124, 38, 1, M.STEEL)
	for x: int in [37, 49, 61, 71]:
		a.rect(x, 126, 2, 2, M.IRON)
	_wire(a, [Vector2i(18, 116), Vector2i(14, 116), Vector2i(14, 72)], false)
	# A black shelving void exposes only the thickness of the stacked paper
	# laminations. It is a sealed cutaway alongside the worker circulation.
	a.rect(85, 47, 8, 45, M.RUBBER)
	a.rect(87, 49, 4, 41, M.EMPTY)
	for y: int in range(51, 89, 6):
		a.rect(87, y, 4, 2, M.CONCRETE)
		a.rect(88, y + 2, 3, 1, M.STEEL)
	a.rect(85, 95, 8, 17, M.CONCRETE)
	for y: int in [97, 103, 109]:
		a.rect(86, y, 6, 1, M.LEAD)
	# The riser has a narrow recessed service rail on its western return.
	a.rect(101, 79, 3, 45, M.RUBBER)
	a.rect(102, 81, 1, 40, M.STEEL)
	for y: int in [84, 95, 106, 117]:
		a.rect(99, y, 5, 2, M.LEAD)
		a.rect(100, y, 2, 1, M.STEEL)
	a.rect(100, 68, 4, 7, M.LEAD)
	a.rect(101, 69, 2, 4, M.WHITE)
	# Sparse console on the ceiling shoulder; its scale stays subordinate to
	# the archive bank and the deep mass surrounding the narrow right exit.
	_slab(a, 139, 33, 43, 13, false)
	a.rect(144, 37, 18, 4, M.DARK_GLASS)
	a.rect(146, 38, 6, 1, M.CYAN)
	a.rect(155, 38, 4, 1, M.STEEL)
	a.rect(168, 37, 8, 4, M.RUBBER)
	a.rect(170, 38, 2, 1, M.AMBER)
	for x: int in [142, 177]:
		_tie(a, x, 42)
	_wire(a, [Vector2i(111, 35), Vector2i(111, 44), Vector2i(132, 44)], false)
	# Heavy sealed counterweight plinth east of the riser. Two sliver recesses
	# reveal the tether straps; everything around them is unbroken concrete.
	_slab(a, 146, 88, 34, 62)
	a.rect(151, 93, 24, 1, M.LEAD)
	a.rect(153, 98, 5, 28, M.RUBBER)
	a.rect(168, 98, 5, 28, M.RUBBER)
	a.rect(154, 101, 3, 22, M.EMPTY)
	a.rect(169, 101, 3, 22, M.EMPTY)
	a.rect(155, 100, 1, 24, M.STEEL)
	a.rect(170, 100, 1, 24, M.STEEL)
	for y: int in [99, 111, 123]:
		a.rect(151, y, 9, 1, M.LEAD)
		a.rect(166, y, 9, 1, M.LEAD)
	a.rect(152, 129, 22, 7, M.CONCRETE)
	a.rect(152, 136, 22, 2, M.LEAD)
	a.rect(156, 133, 14, 1, M.LEAD)
	a.rect(160, 139, 7, 5, M.RUBBER)
	a.rect(162, 140, 3, 2, M.STEEL)
	_wire(a, [Vector2i(140, 83), Vector2i(140, 152), Vector2i(177, 152)], false)
	for y: int in [86, 147]:
		_tie(a, 184, y)
	# Floor crypts below the transfer passage and a much smaller terminal
	# drawer retain quiet gaps of concrete between the working mechanisms.
	for x: int in [13, 49, 85]:
		_slab(a, x, 165, 29, 16)
		a.rect(x + 5, 169, 19, 1, M.LEAD)
		a.rect(x + 12, 172, 6, 2, M.RUBBER)
		a.rect(x + 13, 172, 4, 1, M.STEEL)
	_slab(a, 143, 162, 38, 19)
	a.rect(149, 168, 25, 4, M.RUBBER)
	a.rect(151, 169, 21, 1, M.CONCRETE)
	a.rect(151, 171, 21, 1, M.STEEL)
	a.rect(177, 169, 1, 2, M.AMBER)
	_wire(a, [Vector2i(17, 162), Vector2i(93, 162)], true)
	a.rect(118, 164, 1, 17, M.LEAD)
	a.rect(128, 157, 1, 24, M.LEAD)
	for y: int in [164, 177]:
		_tie(a, 121, y)
	# Cast-in identification and deliberately few form-tie pairs punctuate
	# the solid upper beam; no repeated bright signage crosses the bunker.
	a.label("02", 9, 10, M.LEAD)
	a.label("RECORDS", 36, 10, M.LEAD)
	a.label("MORT", 57, 36, M.IRON)
	for point: Vector2i in [Vector2i(24, 14), Vector2i(82, 14), Vector2i(104, 14),
			Vector2i(139, 14), Vector2i(177, 14), Vector2i(5, 75),
			Vector2i(5, 114), Vector2i(136, 120), Vector2i(185, 174)]:
		_tie(a, point.x, point.y)
	a.rect(97, 31, 1, 18, M.LEAD)
	a.rect(133, 79, 1, 43, M.LEAD)
	a.rect(184, 81, 1, 59, M.LEAD)
	a.rect(135, 154, 49, 1, M.LEAD)


static func _slab(a: Variant, x: int, y: int, width: int, height: int,
		fasteners: bool = true) -> void:
	# Shadow the lower/right returns; short upper/left joints let the casting
	# merge back into its slab. Its large face remains native Concrete.
	a.rect(x, y, width, height, M.CONCRETE)
	a.rect(x + width - 1, y + 1, 1, height - 1, M.LEAD)
	a.rect(x + 2, y + height - 1, width - 2, 1, M.RUBBER)
	a.rect(x, y, mini(width / 2, 28), 1, M.LEAD)
	a.rect(x, y, 1, mini(height - 1, 10), M.LEAD)
	a.rect(x, y + height - mini(5, height), 1, mini(5, height), M.LEAD)
	a.rect(x + 2, y + 1, mini(5, width - 4), 1, M.STEEL)
	if fasteners:
		_tie(a, x + 3, y + 3)
		_tie(a, x + width - 6, y + height - 5)


static func _tie(a: Variant, x: int, y: int) -> void:
	a.rect(x, y, 3, 3, M.LEAD)
	a.rect(x + 1, y + 1, 1, 1, M.CONCRETE)
	a.rect(x, y, 1, 1, M.STEEL)


static func _relay(a: Variant, x: int, y: int, width: int) -> void:
	a.rect(x, y, width, 6, M.LEAD)
	a.rect(x + 1, y + 1, width - 2, 4, M.CONCRETE)
	a.rect(x + 3, y + 2, width - 6, 1, M.RUBBER)
	a.rect(x + width - 3, y + 2, 1, 1, M.WHITE)
	a.rect(x, y + 5, 2, 1, M.STEEL)


static func _wire(a: Variant, path: Array[Vector2i], insulated: bool) -> void:
	var material: int = M.RUBBER if insulated else M.LEAD
	for index: int in range(path.size() - 1):
		var start: Vector2i = path[index]
		var end: Vector2i = path[index + 1]
		assert(start.x == end.x or start.y == end.y)
		if start.y == end.y:
			var left: int = mini(start.x, end.x)
			var length: int = absi(start.x - end.x) + 1
			a.rect(left, start.y, length, 1, material)
			for x: int in range(left + 5, left + length - 2, 15):
				a.rect(x, start.y - 1, 2, 4, M.CONCRETE)
				a.rect(x, start.y, 1, 2, M.STEEL)
		else:
			var top: int = mini(start.y, end.y)
			var length: int = absi(start.y - end.y) + 1
			a.rect(start.x, top, 1, length, material)
			for y: int in range(top + 5, top + length - 2, 15):
				a.rect(start.x - 1, y, 4, 2, M.CONCRETE)
				a.rect(start.x, y, 2, 1, M.STEEL)


static func _cassette(a: Variant, x: int, y: int, number: int) -> void:
	a.rect(x, y, 19, 20, M.LEAD)
	a.rect(x, y + 1, 18, 18, M.CONCRETE)
	a.rect(x + 7, y, 12, 1, M.CONCRETE)
	a.rect(x + 4, y + 4, 11, 12, M.RUBBER)
	a.rect(x + 5, y + 5, 9, 10, M.CONCRETE)
	a.rect(x + 8, y + 5, 1, 9, M.LEAD)
	a.rect(x + 6, y + 5, 1, 8, M.STEEL)
	a.rect(x + 10, y + 9, 3, 2, M.LEAD)
	a.rect(x + 11, y + 9, 1, 1, M.STEEL)
	a.rect(x + 3, y + 1, 4, 1, M.STEEL)
	a.rect(x + 3, y + 17, 13, 1, M.LEAD)
	a.rect(x + 2, y + 7, 1, 5, M.CONCRETE)
	a.rect(x + 16, y + 7, 1, 5, M.CONCRETE)
	a.rect(x + 15, y + 2, 1, 1, M.WHITE if number == 4 else M.STEEL)
	# One- to three-notch registry marks are engraved in the plugs themselves.
	for notch: int in range(1 + number % 3):
		a.rect(x + 3 + notch * 2, y + 18, 1, 1, M.IRON)
