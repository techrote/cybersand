class_name CyberIndustrialUnderswamp
extends RefCounted

# A flooded refinery reclaimed by mineral growth and rootlike conduits. Every
# visible feature is an ordinary native material cell; there are no emitters,
# animated construction scripts, special collision rules or generated bodies.
const ID: String = "industrial_underswamp"
const SCENARIO_ID: String = "showcase/industrial-underswamp"
const TITLE: String = "Industrial Underswamp"
const VERSION: int = 1
const Art = preload("res://scripts/neon_reliquary.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")


static func spawn() -> Vector2:
	return Vector2(88, 488)


static func viewpoints() -> Array[Dictionary]:
	return [
		{"name": "The whole underswamp", "origin": Vector2(32, 16), "size": Vector2i(960, 540)},
		{"name": "The leaning still", "origin": Vector2(80, 84), "size": Vector2i(480, 270)},
		{"name": "The suspended process vessel", "origin": Vector2(400, 100), "size": Vector2i(480, 270)},
		{"name": "Flooded root islands", "origin": Vector2(292, 286), "size": Vector2i(480, 270)},
		{"name": "The abandoned gantry", "origin": Vector2(496, 224), "size": Vector2i(480, 270)},
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
		"instructions": "An abandoned refinery beneath a mineral-encrusted cavern. "
			+ "Leaning stills, suspended process vessels and broken cargo routes stand above "
			+ "broad flooded pools, moss islands and submerged pipework. "
			+ "Starts paused; P animates the ordinary materials, R restores the authored scene, "
			+ "arrow keys pan and F8 gives a clean view. Paint and erase remain available. "
			+ "An aesthetic showcase with no objectives or physics qualification.",
		"duration_ticks": 600,
		"baseline": "Current native materials / Baseline transport / Water8-coherence12",
		"profile": "Industrial Underswamp / authored composition v1",
		"regions": [],
	}
	out.source_recipe = "CyberIndustrialUnderswamp/v1"
	out.source_recipe_hash = JSON.stringify(out.rectangles).sha256_text()
	return out


static func landmarks() -> Array[Dictionary]:
	return [
		{"point": Vector2i(88, 511), "material": Art.WET_COBBLE},
		{"point": Vector2i(546, 470), "material": Art.WATER},
		{"point": Vector2i(611, 240), "material": Art.AMBER},
		{"point": Vector2i(802, 364), "material": Art.CYAN},
		{"point": Vector2i(962, 550), "material": Art.GRANITE},
	]


static func rectangles() -> PackedInt32Array:
	var out := PackedInt32Array()
	Art._rect(out, 0, 0, 1024, 1, Art.WALL)
	Art._rect(out, 0, 1, 1, 1023, Art.WALL)
	Art._rect(out, 1023, 1, 1, 1023, Art.WALL)
	Art._rect(out, 1, 1023, 1022, 1, Art.WALL)
	_flooded_floor(out)
	_cavern_roof(out)
	_leaning_still(out)
	_suspended_vessel(out)
	_cargo_gantry(out)
	_reclaimed_islands(out)
	_small_scale_detail(out)
	# The west landing is a deliberate dry recess in the uneven shore.
	Art._rect(out, 76, 462, 96, 48, Art.EMPTY)
	Art._rect(out, 70, 510, 110, 5, Art.WET_COBBLE)
	Art._rect(out, 75, 515, 96, 9, Art.GRANITE)
	return out


static func _ellipse(out: PackedInt32Array, cx: int, cy: int, rx: int, ry: int,
		material: int) -> void:
	# Two-cell contour steps suit weathered organic shapes and bound setup cost.
	for dy: int in range(-ry, ry + 1, 2):
		var half: int = floori(float(rx) * sqrt(maxf(0.0, 1.0 - pow(float(dy) / float(ry), 2.0))))
		Art._rect(out, cx - half, cy + dy, 2 * half + 1, mini(2, ry - dy + 1), material)


static func _leaning_column(out: PackedInt32Array, top: Vector2i, bottom: Vector2i,
		top_half_width: int, bottom_half_width: int, material: int) -> void:
	var height: int = bottom.y - top.y
	for offset: int in range(0, height + 1, 4):
		var t: float = float(offset) / float(height)
		var centre_x: int = roundi(lerpf(float(top.x), float(bottom.x), t))
		var half_width: int = roundi(lerpf(float(top_half_width), float(bottom_half_width), t))
		Art._rect(out, centre_x - half_width, top.y + offset,
			2 * half_width + 1, mini(4, height - offset + 1), material)


static func _shore(out: PackedInt32Array, points: Array[Vector2i], material: int) -> void:
	for segment: int in range(points.size() - 1):
		var from: Vector2i = points[segment]
		var to: Vector2i = points[segment + 1]
		for x: int in range(from.x, to.x, 6):
			var t: float = float(x - from.x) / float(to.x - from.x)
			var y: int = roundi(lerpf(float(from.y), float(to.y), t))
			Art._rect(out, x, y, mini(6, to.x - x), 556 - y, material)


static func _curve(out: PackedInt32Array, from: Vector2i, bend: Vector2i,
		to: Vector2i, thickness: int, material: int) -> void:
	var previous: Vector2i = from
	for segment: int in range(1, 9):
		var t: float = float(segment) / 8.0
		var a: Vector2 = Vector2(from).lerp(Vector2(bend), t)
		var b: Vector2 = Vector2(bend).lerp(Vector2(to), t)
		var next: Vector2i = Vector2i(a.lerp(b, t).round())
		Art._beam(out, previous, next, thickness, material)
		previous = next


static func _moss(out: PackedInt32Array, x: int, y: int, width: int,
		depth: int = 10) -> void:
	for offset: int in range(0, width, 8):
		var drop: int = 3 + ((offset * 7 + x) % maxi(4, depth))
		Art._rect(out, x + offset, y, mini(9, width - offset), drop, Art.MOSS_STONE)
		if offset % 24 != 0:
			Art._rect(out, x + offset + 1, y, mini(6, width - offset), 3, Art.VERDIGRIS)


static func _lamp(out: PackedInt32Array, x: int, y: int, light: int) -> void:
	Art._rect(out, x - 2, y - 2, 9, 9, Art.IRON)
	Art._rect(out, x - 1, y - 1, 7, 7, Art.LEAD)
	Art._rect(out, x, y, 5, 3, light)
	Art._rect(out, x + 1, y + 4, 3, 1, Art.DARK_GLASS)


static func _flooded_floor(out: PackedInt32Array) -> void:
	# Separate authored levels and intervening solid banks make several readable
	# pools. Their Water is ordinary Water, without a decorative fluid substitute.
	Art._rect(out, 38, 535, 950, 21, Art.GRANITE)
	Art._rect(out, 39, 446, 137, 89, Art.SLATE)
	Art._rect(out, 974, 388, 14, 151, Art.GRANITE)
	Art._rect(out, 173, 452, 266, 87, Art.WATER)
	Art._rect(out, 432, 422, 376, 117, Art.WATER)
	Art._rect(out, 796, 453, 177, 86, Art.WATER)
	_shore(out, [Vector2i(38, 505), Vector2i(178, 520), Vector2i(234, 488),
		Vector2i(305, 522), Vector2i(372, 510), Vector2i(399, 460),
		Vector2i(458, 453), Vector2i(482, 509), Vector2i(575, 525),
		Vector2i(640, 506), Vector2i(675, 478), Vector2i(727, 499),
		Vector2i(776, 536), Vector2i(829, 521), Vector2i(897, 502),
		Vector2i(949, 493), Vector2i(988, 513)], Art.SLATE)
	_shore(out, [Vector2i(40, 527), Vector2i(186, 541), Vector2i(235, 512),
		Vector2i(306, 540), Vector2i(378, 533), Vector2i(419, 487),
		Vector2i(444, 490), Vector2i(482, 534), Vector2i(631, 540),
		Vector2i(677, 499), Vector2i(733, 527), Vector2i(834, 545),
		Vector2i(906, 523), Vector2i(972, 526)], Art.MOSS_STONE)
	# Low foreground pockets expose broken ducts below the irregular shore.
	for x: int in [191, 276, 520, 578, 809, 878]:
		Art._panel(out, x, 541, 38, 12, Art.IRON, Art.WET_ASPHALT)
		Art._rect(out, x + 3, 547, 31, 2, Art.COPPER_PIPE)
		Art._rect(out, x + 16, 541, 2, 11, Art.IRON)
	Art._rect(out, 49, 502, 25, 8, Art.CONCRETE)
	Art._rect(out, 53, 495, 19, 7, Art.GRANITE)
	Art._rect(out, 57, 488, 14, 7, Art.SLATE)
	Art._rect(out, 69, 451, 104, 8, Art.CONCRETE)
	Art._rect(out, 169, 456, 7, 55, Art.GRANITE)
	Art._rect(out, 82, 455, 60, 2, Art.VERDIGRIS)
	_lamp(out, 160, 443, Art.AMBER)


static func _cavern_roof(out: PackedInt32Array) -> void:
	# A continuous ragged ceiling contrasts with the architecture above. Short
	# plateaus and mineral veins are authored contour detail, not noise at runtime.
	for x: int in range(32, 992, 8):
		var edge: int = 65 + roundi(18.0 * sin(float(x) * 0.017)
			+ 10.0 * sin(float(x) * 0.043) + 5.0 * sin(float(x) * 0.093))
		Art._rect(out, x, 16, 8, edge - 16, Art.SLATE)
		Art._rect(out, x, edge - 9, 8, 9, Art.GRANITE)
		if (x / 8) % 3 != 0:
			Art._rect(out, x, edge - 2, 8, 5 + x % 7, Art.MOSS_STONE)
		if (x / 8) % 7 == 0:
			Art._rect(out, x + 1, edge + 1, 5, 2, Art.VERDIGRIS)
	# Unequal teeth and shoulders leave a broad central void over the vessel.
	_leaning_column(out, Vector2i(74, 55), Vector2i(89, 218), 24, 4, Art.GRANITE)
	_leaning_column(out, Vector2i(394, 50), Vector2i(375, 132), 30, 5, Art.SLATE)
	_leaning_column(out, Vector2i(864, 59), Vector2i(895, 170), 26, 3, Art.GRANITE)
	Art._beam(out, Vector2i(82, 94), Vector2i(91, 199), 2, Art.VERDIGRIS)
	Art._beam(out, Vector2i(883, 85), Vector2i(897, 146), 2, Art.MOSS_STONE)
	_curve(out, Vector2i(156, 62), Vector2i(120, 146), Vector2i(179, 200), 4, Art.RUBBER)
	_curve(out, Vector2i(180, 66), Vector2i(159, 140), Vector2i(208, 189), 2, Art.MOSS_STONE)
	_curve(out, Vector2i(767, 63), Vector2i(810, 107), Vector2i(780, 159), 4, Art.RUBBER)
	_curve(out, Vector2i(780, 65), Vector2i(833, 113), Vector2i(803, 176), 2, Art.VERDIGRIS)
	Art._rect(out, 450, 56, 37, 8, Art.RUSTED_STEEL)
	Art._rect(out, 698, 80, 40, 8, Art.RUSTED_STEEL)
	_lamp(out, 460, 66, Art.CYAN)


static func _leaning_still(out: PackedInt32Array) -> void:
	# A visibly tilted refinery stack: long seams lean with the shell while its
	# collar plates, access cage and broken service arm follow their own damage.
	_leaning_column(out, Vector2i(236, 128), Vector2i(312, 408), 28, 42, Art.IRON)
	_leaning_column(out, Vector2i(238, 132), Vector2i(310, 407), 24, 34, Art.RUSTED_STEEL)
	_leaning_column(out, Vector2i(237, 154), Vector2i(294, 367), 10, 12, Art.DARK_GLASS)
	Art._beam(out, Vector2i(215, 146), Vector2i(280, 396), 3, Art.COPPER_PIPE)
	Art._beam(out, Vector2i(257, 139), Vector2i(333, 395), 4, Art.VERDIGRIS)
	_ellipse(out, 235, 132, 37, 18, Art.IRON)
	_ellipse(out, 235, 128, 31, 12, Art.BRONZE)
	_ellipse(out, 233, 125, 24, 7, Art.WET_ASPHALT)
	Art._beam(out, Vector2i(233, 126), Vector2i(219, 88), 12, Art.RUSTED_STEEL)
	Art._beam(out, Vector2i(235, 126), Vector2i(221, 88), 3, Art.LEAD)
	Art._rect(out, 212, 85, 24, 6, Art.IRON)
	Art._rect(out, 215, 82, 16, 3, Art.MOSS_STONE)
	for index: int in range(7):
		var y: int = 164 + index * 31
		var x: int = 245 + index * 8
		Art._beam(out, Vector2i(x - 27, y + 5), Vector2i(x + 31, y - 9), 4, Art.LEAD)
		Art._rect(out, x - 19, y + 5, 4, 3, Art.IRON)
		Art._rect(out, x + 20, y - 5, 4, 3, Art.IRON)
		if index % 2 == 0:
			Art._rect(out, x - 1, y - 10, 3, 8, Art.CHEMICAL_GLASS)
	_ellipse(out, 283, 295, 20, 22, Art.IRON)
	_ellipse(out, 282, 294, 15, 16, Art.CHEMICAL_GLASS)
	Art._rect(out, 280, 291, 3, 8, Art.CYAN)
	Art._rect(out, 271, 281, 7, 2, Art.LEAD)
	Art._rect(out, 292, 306, 7, 3, Art.BRONZE)
	# The cage is open geometry with an interrupted ladder, not another wall.
	Art._beam(out, Vector2i(270, 188), Vector2i(330, 393), 2, Art.IRON)
	Art._beam(out, Vector2i(278, 185), Vector2i(340, 394), 2, Art.IRON)
	for index: int in range(12):
		var y: int = 191 + index * 17
		var x: int = 273 + index * 5
		if index == 7: continue
		Art._rect(out, x, y, 11, 2, Art.GRATING)
	Art._rect(out, 273, 405, 82, 11, Art.STEEL)
	Art._rect(out, 281, 416, 12, 36, Art.CONCRETE)
	Art._rect(out, 336, 416, 12, 51, Art.CONCRETE)
	Art._beam(out, Vector2i(290, 425), Vector2i(343, 459), 4, Art.IRON)
	_moss(out, 274, 408, 78, 16)
	# A sliced-off transfer duct reaches into the void above the west pool.
	Art._rect(out, 318, 269, 79, 9, Art.RUSTED_STEEL)
	Art._rect(out, 325, 270, 68, 2, Art.LEAD)
	Art._rect(out, 320, 259, 67, 2, Art.IRON)
	for x: int in [323, 342, 361, 385]:
		Art._rect(out, x, 261, 2, 8, Art.LEAD)
	Art._beam(out, Vector2i(343, 279), Vector2i(376, 309), 5, Art.IRON)
	Art._rect(out, 392, 271, 6, 3, Art.MOSS_STONE)
	Art._rect(out, 398, 280, 10, 2, Art.IRON)
	_lamp(out, 326, 253, Art.AMBER)


static func _suspended_vessel(out: PackedInt32Array) -> void:
	# One off-centre hanging ovoid is the dominant machine. Matte weathering and
	# a small inspection eye carry the focal light, without a second giant halo.
	Art._beam(out, Vector2i(470, 64), Vector2i(552, 180), 5, Art.IRON)
	Art._beam(out, Vector2i(715, 89), Vector2i(680, 180), 5, Art.IRON)
	Art._beam(out, Vector2i(472, 65), Vector2i(553, 179), 1, Art.LEAD)
	Art._beam(out, Vector2i(717, 90), Vector2i(682, 177), 1, Art.LEAD)
	_ellipse(out, 615, 236, 86, 65, Art.IRON)
	_ellipse(out, 615, 234, 80, 58, Art.RUSTED_STEEL)
	_ellipse(out, 598, 229, 51, 45, Art.PAINTED_STEEL)
	_ellipse(out, 611, 236, 28, 31, Art.BRONZE)
	_ellipse(out, 611, 236, 23, 26, Art.DARK_GLASS)
	_ellipse(out, 607, 232, 15, 19, Art.CHEMICAL_GLASS)
	Art._rect(out, 608, 216, 3, 44, Art.IRON)
	Art._rect(out, 590, 235, 37, 3, Art.IRON)
	Art._rect(out, 610, 239, 4, 4, Art.AMBER)
	Art._rect(out, 598, 219, 2, 12, Art.CYAN)
	_ellipse(out, 615, 182, 81, 13, Art.IRON)
	_ellipse(out, 615, 179, 74, 7, Art.VERDIGRIS)
	Art._rect(out, 557, 169, 116, 6, Art.LEAD)
	Art._rect(out, 571, 165, 86, 4, Art.RUSTED_STEEL)
	_moss(out, 542, 183, 145, 15)
	for x: int in [552, 569, 652, 677]:
		Art._rect(out, x, 201, 5, 52, Art.LEAD)
		Art._rect(out, x + 1, 203, 2, 48, Art.IRON)
		Art._rect(out, x - 2, 218, 9, 5, Art.BRONZE)
	for index: int in range(9):
		var x: int = 555 + index * 15
		var y: int = 265 + absi(4 - index) * -4
		Art._rect(out, x, y, 3, 3, Art.LEAD)
	Art._rect(out, 601, 294, 28, 15, Art.RUSTED_STEEL)
	Art._rect(out, 596, 306, 37, 7, Art.BRONZE)
	Art._rect(out, 608, 313, 15, 34, Art.STEEL_PIPE)
	Art._rect(out, 611, 314, 3, 33, Art.VERDIGRIS)
	Art._rect(out, 602, 337, 27, 7, Art.IRON)
	_curve(out, Vector2i(614, 346), Vector2i(612, 394), Vector2i(665, 427), 9, Art.COPPER_PIPE)
	_curve(out, Vector2i(617, 348), Vector2i(617, 393), Vector2i(669, 426), 2, Art.VERDIGRIS)
	Art._rect(out, 651, 407, 27, 7, Art.LEAD)
	# The smaller dead condenser hangs at a different level from thin strops.
	Art._rect(out, 440, 175, 2, 136, Art.IRON)
	Art._rect(out, 485, 183, 2, 127, Art.IRON)
	_ellipse(out, 464, 331, 30, 35, Art.IRON)
	_ellipse(out, 464, 328, 25, 29, Art.VERDIGRIS)
	Art._rect(out, 438, 312, 54, 5, Art.LEAD)
	Art._rect(out, 444, 344, 40, 5, Art.RUSTED_STEEL)
	Art._rect(out, 451, 319, 25, 18, Art.DARK_GLASS)
	Art._rect(out, 455, 322, 3, 11, Art.CHEMICAL_GLASS)
	Art._rect(out, 460, 366, 9, 32, Art.COPPER_PIPE)
	Art._rect(out, 456, 387, 17, 5, Art.LEAD)
	_moss(out, 438, 316, 52, 11)
	_lamp(out, 478, 355, Art.AMBER)


static func _cargo_gantry(out: PackedInt32Array) -> void:
	# An incomplete cantilever and collapsed cargo cage make the east end open,
	# low and diagonal rather than a reflected version of the refinery stack.
	Art._rect(out, 847, 298, 13, 157, Art.RUSTED_STEEL)
	Art._rect(out, 850, 298, 3, 153, Art.LEAD)
	Art._beam(out, Vector2i(852, 302), Vector2i(743, 236), 9, Art.IRON)
	Art._beam(out, Vector2i(852, 317), Vector2i(757, 259), 4, Art.LEAD)
	Art._beam(out, Vector2i(783, 260), Vector2i(784, 276), 3, Art.RUSTED_STEEL)
	Art._beam(out, Vector2i(810, 277), Vector2i(811, 293), 3, Art.RUSTED_STEEL)
	Art._beam(out, Vector2i(839, 294), Vector2i(840, 310), 3, Art.RUSTED_STEEL)
	Art._rect(out, 731, 233, 16, 8, Art.RUSTED_STEEL)
	Art._rect(out, 727, 231, 8, 3, Art.MOSS_STONE)
	Art._rect(out, 757, 264, 2, 72, Art.IRON)
	Art._rect(out, 752, 333, 10, 3, Art.LEAD)
	Art._rect(out, 752, 335, 3, 9, Art.IRON)
	Art._rect(out, 755, 342, 10, 3, Art.IRON)
	Art._rect(out, 763, 336, 3, 8, Art.IRON)
	Art._rect(out, 783, 375, 132, 9, Art.GRATING)
	Art._rect(out, 790, 363, 115, 2, Art.IRON)
	for x: int in [790, 814, 842, 869, 903]:
		Art._rect(out, x, 365, 2, 10, Art.LEAD)
	Art._rect(out, 791, 384, 9, 69, Art.CONCRETE)
	Art._rect(out, 904, 384, 9, 95, Art.CONCRETE)
	Art._beam(out, Vector2i(801, 391), Vector2i(880, 449), 4, Art.IRON)
	Art._rect(out, 800, 347, 40, 24, Art.RUSTED_STEEL)
	Art._rect(out, 804, 351, 32, 15, Art.DARK_GLASS)
	Art._rect(out, 819, 350, 2, 17, Art.IRON)
	Art._rect(out, 801, 363, 6, 3, Art.CYAN)
	Art._rect(out, 868, 344, 31, 29, Art.CORRUGATED)
	Art._rect(out, 869, 342, 30, 3, Art.VERDIGRIS)
	Art._rect(out, 877, 349, 11, 14, Art.IRON)
	Art._rect(out, 878, 351, 8, 3, Art.AMBER)
	# The far tower leans outward and dissolves into the cavern shoulder.
	_leaning_column(out, Vector2i(925, 227), Vector2i(898, 335), 16, 24, Art.IRON)
	_leaning_column(out, Vector2i(925, 229), Vector2i(900, 334), 11, 18, Art.RUSTED_STEEL)
	Art._beam(out, Vector2i(925, 205), Vector2i(935, 181), 10, Art.STEEL_PIPE)
	Art._rect(out, 928, 178, 18, 5, Art.IRON)
	_ellipse(out, 925, 221, 25, 14, Art.IRON)
	_ellipse(out, 925, 219, 19, 9, Art.COPPER_PIPE)
	Art._rect(out, 920, 214, 10, 10, Art.WET_ASPHALT)
	Art._rect(out, 912, 260, 27, 4, Art.LEAD)
	Art._rect(out, 904, 299, 31, 4, Art.LEAD)
	Art._rect(out, 903, 316, 24, 3, Art.VERDIGRIS)
	Art._rect(out, 944, 333, 7, 104, Art.COPPER_PIPE)
	Art._rect(out, 916, 333, 29, 7, Art.COPPER_PIPE)
	Art._rect(out, 940, 373, 15, 5, Art.IRON)
	Art._rect(out, 939, 430, 17, 7, Art.LEAD)
	_moss(out, 787, 377, 126, 11)
	_moss(out, 899, 264, 45, 16)
	_lamp(out, 837, 304, Art.AMBER)


static func _reclaimed_islands(out: PackedInt32Array) -> void:
	# Unequal rooted mineral islands rise through the water and partially bury
	# the old infrastructure. Solid finishes imply growth without live Plant rules.
	_shore(out, [Vector2i(391, 473), Vector2i(405, 426), Vector2i(421, 408),
		Vector2i(447, 410), Vector2i(466, 437), Vector2i(480, 494)], Art.GRANITE)
	_shore(out, [Vector2i(644, 502), Vector2i(651, 457), Vector2i(666, 438),
		Vector2i(685, 441), Vector2i(702, 462), Vector2i(716, 502)], Art.GRANITE)
	_shore(out, [Vector2i(889, 504), Vector2i(907, 462), Vector2i(924, 437),
		Vector2i(952, 449), Vector2i(975, 500)], Art.GRANITE)
	# A narrow mineral shoulder buries the gantry's lower footing and separates
	# the two pool levels with an irregular shore rather than an exposed Water edge.
	_shore(out, [Vector2i(788, 518), Vector2i(792, 478), Vector2i(796, 440),
		Vector2i(800, 414), Vector2i(804, 413), Vector2i(808, 417),
		Vector2i(812, 434), Vector2i(816, 449), Vector2i(820, 476),
		Vector2i(824, 512), Vector2i(828, 535)], Art.GRANITE)
	_shore(out, [Vector2i(799, 490), Vector2i(803, 441), Vector2i(807, 435),
		Vector2i(811, 464), Vector2i(815, 501), Vector2i(819, 532)], Art.SLATE)
	_ellipse(out, 803, 417, 12, 5, Art.MOSS_STONE)
	_ellipse(out, 805, 414, 8, 3, Art.VERDIGRIS)
	_moss(out, 797, 421, 14, 17)
	Art._rect(out, 807, 438, 3, 11, Art.MOSS_STONE)
	Art._rect(out, 811, 469, 3, 6, Art.VERDIGRIS)
	_ellipse(out, 433, 408, 35, 11, Art.MOSS_STONE)
	_ellipse(out, 429, 403, 24, 6, Art.VERDIGRIS)
	_ellipse(out, 675, 438, 31, 10, Art.MOSS_STONE)
	_ellipse(out, 672, 434, 22, 5, Art.VERDIGRIS)
	_ellipse(out, 934, 435, 29, 10, Art.MOSS_STONE)
	_ellipse(out, 931, 431, 20, 6, Art.VERDIGRIS)
	_moss(out, 402, 414, 62, 23)
	_moss(out, 650, 443, 48, 19)
	_moss(out, 906, 443, 59, 19)
	# Root conduits hook around exposed rock, forming large asymmetric loops.
	_curve(out, Vector2i(427, 413), Vector2i(403, 449), Vector2i(385, 478), 6, Art.RUBBER)
	_curve(out, Vector2i(438, 412), Vector2i(419, 470), Vector2i(454, 501), 7, Art.VERDIGRIS)
	_curve(out, Vector2i(673, 441), Vector2i(695, 475), Vector2i(743, 479), 5, Art.RUBBER)
	_curve(out, Vector2i(671, 442), Vector2i(653, 493), Vector2i(613, 508), 5, Art.COPPER_PIPE)
	_curve(out, Vector2i(676, 444), Vector2i(670, 491), Vector2i(691, 501), 3, Art.VERDIGRIS)
	_curve(out, Vector2i(931, 441), Vector2i(910, 491), Vector2i(864, 492), 6, Art.RUBBER)
	# Small branching crowns grow from dead valves; the lights remain pinpoints.
	Art._beam(out, Vector2i(432, 400), Vector2i(421, 366), 5, Art.MOSS_STONE)
	Art._beam(out, Vector2i(424, 379), Vector2i(403, 365), 4, Art.VERDIGRIS)
	Art._beam(out, Vector2i(424, 382), Vector2i(448, 369), 3, Art.VERDIGRIS)
	_ellipse(out, 402, 363, 12, 5, Art.MOSS_STONE)
	_ellipse(out, 420, 363, 10, 6, Art.VERDIGRIS)
	_ellipse(out, 449, 366, 14, 5, Art.MOSS_STONE)
	Art._rect(out, 418, 360, 3, 2, Art.CYAN)
	Art._rect(out, 449, 363, 2, 2, Art.AMBER)
	Art._beam(out, Vector2i(687, 434), Vector2i(707, 394), 5, Art.MOSS_STONE)
	Art._beam(out, Vector2i(699, 410), Vector2i(722, 399), 3, Art.VERDIGRIS)
	_ellipse(out, 706, 391, 18, 7, Art.VERDIGRIS)
	_ellipse(out, 723, 397, 14, 5, Art.MOSS_STONE)
	Art._rect(out, 704, 387, 3, 2, Art.CYAN)
	Art._rect(out, 724, 394, 2, 2, Art.AMBER)
	Art._beam(out, Vector2i(941, 428), Vector2i(964, 393), 5, Art.MOSS_STONE)
	_ellipse(out, 964, 390, 17, 7, Art.VERDIGRIS)
	Art._rect(out, 960, 386, 4, 2, Art.CYAN)


static func _small_scale_detail(out: PackedInt32Array) -> void:
	# Frayed services and battered instruments provide a second, finer scale.
	Art._rect(out, 114, 353, 68, 65, Art.RUSTED_STEEL)
	Art._rect(out, 118, 357, 60, 53, Art.PAINTED_STEEL)
	Art._vent(out, 125, 366, 43, 32)
	Art._rect(out, 109, 416, 78, 8, Art.CONCRETE)
	_moss(out, 111, 354, 72, 13)
	Art._rect(out, 136, 329, 12, 25, Art.STEEL_PIPE)
	Art._rect(out, 125, 327, 38, 5, Art.LEAD)
	Art._rect(out, 128, 323, 30, 4, Art.MOSS_STONE)
	Art._rect(out, 117, 424, 8, 27, Art.CONCRETE)
	Art._rect(out, 170, 424, 7, 27, Art.CONCRETE)
	_curve(out, Vector2i(190, 203), Vector2i(156, 254), Vector2i(190, 324), 5, Art.RUBBER)
	Art._rect(out, 183, 319, 14, 12, Art.IRON)
	Art._rect(out, 184, 321, 12, 3, Art.COPPER_PIPE)
	Art._rect(out, 190, 330, 4, 89, Art.STEEL_PIPE)
	Art._rect(out, 190, 414, 44, 6, Art.STEEL_PIPE)
	Art._rect(out, 229, 418, 5, 30, Art.COPPER_PIPE)
	for y: int in [350, 381, 409]:
		Art._rect(out, 187, y, 10, 4, Art.LEAD)
	_lamp(out, 118, 430, Art.CYAN)
	_lamp(out, 364, 437, Art.AMBER)
	_lamp(out, 503, 365, Art.CYAN)
	_lamp(out, 870, 425, Art.CYAN)
	Art._rect(out, 344, 426, 42, 8, Art.IRON)
	Art._text(out, "03", 357, 428, Art.LEAD)
	Art._rect(out, 487, 351, 33, 10, Art.RUSTED_STEEL)
	Art._text(out, "IX", 497, 354, Art.VERDIGRIS)
	Art._rect(out, 840, 455, 45, 10, Art.IRON)
	Art._text(out, "C-9", 849, 458, Art.LEAD)
	# Inlaid mineral flecks stay attached to the shoreline and machine shoulders.
	for index: int in range(36):
		var x: int = 191 + (index * 47) % 752
		var y: int = 530 + (index * 7) % 14
		Art._rect(out, x, y, 3 + index % 4, 2, Art.VERDIGRIS if index % 3 == 0 else Art.IRON)
	for index: int in range(17):
		var x: int = 545 + (index * 23) % 137
		var y: int = 196 + (index * 13) % 77
		if x > 580 and x < 642: continue
		Art._rect(out, x, y, 4 + index % 6, 3, Art.MOSS_STONE)
