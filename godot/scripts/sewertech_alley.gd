class_name CyberSewertechAlley
extends RefCounted

# A deliberately excessive utility ravine beneath the residential district.
# Every foreground surface and Water run is an ordinary native material cell;
# only deterministic setup rectangles are authored here.
const ID: String = "sewertech_alley"
const SCENARIO_ID: String = "showcase/sewertech-alley"
const TITLE: String = "Sewertech Alley"
const VERSION: int = 1
const Art = preload("res://scripts/neon_reliquary.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")

const EXTRA_GLYPHS: Dictionary = {
	"2": ["111", "001", "111", "100", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "111", "001", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"D": ["110", "101", "101", "101", "110"],
	"G": ["111", "100", "101", "101", "111"],
	"H": ["101", "101", "111", "101", "101"],
	"M": ["101", "111", "111", "101", "101"],
	"O": ["111", "101", "101", "101", "111"],
	"P": ["110", "101", "110", "100", "100"],
	"S": ["111", "100", "111", "001", "111"],
	"W": ["101", "101", "111", "111", "101"],
}


static func spawn() -> Vector2:
	return Vector2(88, 488)


static func viewpoints() -> Array[Dictionary]:
	return [
		{"name": "The sewer ravine", "origin": Vector2(32, 16), "size": Vector2i(960, 540)},
		{"name": "Pump stack 03", "origin": Vector2(272, 44), "size": Vector2i(480, 270)},
		{"name": "The descending sluice", "origin": Vector2(272, 246), "size": Vector2i(480, 270)},
		{"name": "West inspection quarter", "origin": Vector2(32, 238), "size": Vector2i(480, 270)},
		{"name": "The drowned service rooms", "origin": Vector2(512, 286), "size": Vector2i(480, 270)},
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
	out.interest = {"policy": "fixed", "region": [32, 16, 960, 540]}
	out["presentation"] = {
		"title": TITLE,
		"instructions": "A crowded techno-sewer beneath the residential quarter. "
			+ "Follow the descending sluice between ribbed pipes, inspection booths, "
			+ "mossy culverts and submerged service windows. Starts paused; P resumes "
			+ "ordinary materials, R restores the scene, arrows pan and F8 hides the HUD. "
			+ "Paint and erase are available. This ornamental scene has no objectives "
			+ "and makes no physics qualification claim.",
		"duration_ticks": 600,
		"baseline": "Current native materials / Baseline transport / Water8-coherence12",
		"profile": "Sewertech Alley / authored composition v1",
		"regions": [],
	}
	out.source_recipe = "CyberSewertechAlley/v1"
	out.source_recipe_hash = JSON.stringify(out.rectangles).sha256_text()
	return out


static func landmarks() -> Array[Dictionary]:
	return [
		{"point": Vector2i(530, 152), "material": Art.CYAN},
		{"point": Vector2i(410, 194), "material": Art.AMBER},
		{"point": Vector2i(548, 521), "material": Art.WATER},
		{"point": Vector2i(804, 291), "material": Art.MAGENTA},
		{"point": Vector2i(100, 512), "material": Art.WET_COBBLE},
	]


static func rectangles() -> PackedInt32Array:
	var out := PackedInt32Array()
	Art._rect(out, 0, 0, 1024, 1, Art.WALL)
	Art._rect(out, 0, 1, 1, 1023, Art.WALL)
	Art._rect(out, 1023, 1, 1, 1023, Art.WALL)
	Art._rect(out, 1, 1023, 1022, 1, Art.WALL)
	_undercity_masonry(out)
	_outer_pipe_racks(out)
	_inspection_quarter(out)
	_pump_stack(out)
	_descending_sluice(out)
	_service_catwalks(out)
	_hanging_services(out)
	_low_culverts(out)
	_final_fittings(out)
	# An open, supported west landing survives every overlapping decorative pass.
	Art._rect(out, 76, 462, 96, 48, Art.EMPTY)
	Art._rect(out, 70, 510, 110, 5, Art.WET_COBBLE)
	return out


static func _pipe_h(out: PackedInt32Array, x: int, y: int, length: int,
		width: int, material: int = Art.STEEL_PIPE, spacing: int = 24) -> void:
	Art._rect(out, x, y, length, width, Art.IRON)
	Art._rect(out, x, y + 2, length, width - 4, material)
	Art._rect(out, x + 1, y + 3, length - 2, 1, Art.LEAD)
	for offset: int in range(8, length - 5, spacing):
		Art._rect(out, x + offset, y - 2, 5, width + 4, Art.RUSTED_STEEL)
		Art._rect(out, x + offset + 1, y - 2, 1, width + 4, Art.LEAD)
		Art._rect(out, x + offset + 3, y + 1, 2, 2, Art.IRON)


static func _pipe_v(out: PackedInt32Array, x: int, y: int, length: int,
		width: int, material: int = Art.STEEL_PIPE, spacing: int = 24) -> void:
	Art._rect(out, x, y, width, length, Art.IRON)
	Art._rect(out, x + 2, y, width - 4, length, material)
	Art._rect(out, x + 3, y + 1, 1, length - 2, Art.LEAD)
	for offset: int in range(7, length - 5, spacing):
		Art._rect(out, x - 2, y + offset, width + 4, 5, Art.RUSTED_STEEL)
		Art._rect(out, x - 2, y + offset + 1, width + 4, 1, Art.LEAD)
		Art._rect(out, x + width - 4, y + offset + 3, 2, 2, Art.IRON)


static func _catwalk(out: PackedInt32Array, x: int, y: int, width: int,
		finish: int = Art.GRATING) -> void:
	Art._rect(out, x, y, width, 6, Art.IRON)
	Art._rect(out, x, y, width, 2, finish)
	Art._rect(out, x + 2, y + 5, width - 4, 2, Art.RUSTED_STEEL)
	Art._rect(out, x + 1, y - 14, width - 2, 1, Art.LEAD)
	for offset: int in range(2, width - 2, 21):
		Art._rect(out, x + offset, y - 14, 1, 14, Art.IRON)
		Art._rect(out, x + offset, y - 14, 2, 1, Art.STEEL)
	for offset: int in range(8, width - 20, 61):
		Art._beam(out, Vector2i(x + offset, y + 7),
			Vector2i(x + offset + 18, y + 21), 2, Art.IRON)
		Art._rect(out, x + offset + 18, y + 6, 2, 17, Art.IRON)


static func _ladder(out: PackedInt32Array, x: int, y: int, height: int) -> void:
	Art._rect(out, x, y, 2, height, Art.RUSTED_STEEL)
	Art._rect(out, x + 11, y, 2, height, Art.RUSTED_STEEL)
	for offset: int in range(4, height - 2, 8):
		Art._rect(out, x + 2, y + offset, 9, 1, Art.LEAD)
		Art._rect(out, x + 1, y + offset + 1, 11, 1, Art.IRON)


static func _lamp(out: PackedInt32Array, x: int, y: int,
		colour: int = Art.AMBER) -> void:
	Art._rect(out, x + 2, y - 7, 1, 8, Art.CABLE)
	Art._rect(out, x - 2, y - 1, 9, 2, Art.IRON)
	Art._rect(out, x - 1, y + 1, 7, 6, Art.STEEL)
	Art._rect(out, x, y + 1, 5, 4, colour)
	Art._rect(out, x + 2, y + 2, 1, 2, Art.WHITE)
	Art._rect(out, x - 2, y + 7, 9, 1, Art.IRON)


static func _text(out: PackedInt32Array, text: String, x: int, y: int,
		material: int, scale: int = 1) -> void:
	var cursor: int = x
	for character: String in text:
		var glyph: Array = Art.GLYPHS.get(character, EXTRA_GLYPHS.get(character, []))
		if glyph.is_empty():
			cursor += 4 * scale
			continue
		for row: int in range(5):
			var column: int = 0
			while column < 3:
				if glyph[row][column] == "0":
					column += 1
					continue
				var start: int = column
				while column < 3 and glyph[row][column] == "1":
					column += 1
				Art._rect(out, cursor + start * scale, y + row * scale,
					(column - start) * scale, scale, material)
		cursor += 4 * scale


static func _undercity_masonry(out: PackedInt32Array) -> void:
	# A heavy, layered soffit makes the scene read as infrastructure below a city.
	Art._rect(out, 42, 22, 938, 17, Art.CONCRETE)
	Art._rect(out, 50, 38, 922, 8, Art.INDUSTRIAL_BRICK)
	Art._rect(out, 46, 46, 930, 5, Art.IRON)
	for x: int in range(68, 958, 47):
		Art._rect(out, x, 33, 8, 30 + (x % 4) * 5, Art.CONCRETE)
		Art._rect(out, x + 2, 35, 3, 20, Art.SLATE)
		Art._rect(out, x - 2, 60, 13, 4, Art.STEEL)
		Art._rect(out, x + 4, 25, 13, 2, Art.ASPHALT)
	Art._rect(out, 45, 81, 125, 450, Art.INDUSTRIAL_BRICK)
	Art._rect(out, 170, 121, 76, 389, Art.SLATE)
	Art._rect(out, 54, 85, 102, 423, Art.MOSS_STONE)
	Art._rect(out, 829, 71, 149, 461, Art.GRANITE)
	Art._rect(out, 852, 91, 118, 411, Art.INDUSTRIAL_BRICK)
	Art._rect(out, 780, 196, 49, 314, Art.MOSS_STONE)
	for y: int in [112, 183, 265, 350, 434]:
		Art._rect(out, 45, y, 129, 5, Art.CONCRETE)
		Art._rect(out, 51, y + 5, 113, 2, Art.VERDIGRIS)
		Art._rect(out, 825, y - 20, 153, 6, Art.SLATE)
	for index: int in range(7):
		var x: int = 173 + (index % 2) * 9
		var y: int = 130 + index * 47
		Art._panel(out, x, y, 61, 35, Art.GRANITE, Art.IRON)
		Art._rect(out, x + 6, y + 7, 49, 19, Art.EMPTY)
		Art._rect(out, x + 9, y + 6, 2, 23, Art.GRATING)
		Art._rect(out, x + 48, y + 6, 2, 23, Art.GRATING)
		_lamp(out, x + 27, y + 3, Art.CYAN if index % 3 == 0 else Art.AMBER)
	# Jagged buttresses leave broad open shafts around the machinery.
	for index: int in range(8):
		Art._rect(out, 237 + (index % 3) * 6, 130 + index * 44,
			15, 34, Art.RUSTED_STEEL if index % 2 else Art.GRANITE)
		Art._rect(out, 756 - (index % 3) * 8, 160 + index * 41,
			24, 29, Art.MOSS_STONE)
	Art._arch(out, 201, 463, 134, 150, 12, Art.GRANITE)
	Art._arch(out, 201, 463, 120, 138, 3, Art.VERDIGRIS)
	Art._arch(out, 846, 480, 122, 134, 13, Art.MOSS_STONE)
	Art._arch(out, 846, 480, 107, 119, 3, Art.IRON)


static func _outer_pipe_racks(out: PackedInt32Array) -> void:
	_pipe_h(out, 68, 65, 793, 21, Art.COPPER_PIPE, 29)
	_pipe_v(out, 841, 72, 255, 21, Art.COPPER_PIPE, 29)
	_pipe_h(out, 782, 311, 78, 18, Art.COPPER_PIPE, 26)
	_pipe_v(out, 69, 126, 285, 13, Art.STEEL_PIPE, 20)
	_pipe_v(out, 91, 123, 301, 11, Art.VERDIGRIS, 18)
	_pipe_v(out, 116, 115, 329, 16, Art.COPPER_PIPE, 22)
	_pipe_h(out, 74, 405, 110, 14, Art.STEEL_PIPE, 24)
	_pipe_h(out, 119, 436, 148, 16, Art.COPPER_PIPE, 25)
	_pipe_v(out, 884, 122, 303, 17, Art.STEEL_PIPE, 24)
	_pipe_v(out, 918, 121, 280, 12, Art.COPPER_PIPE, 21)
	_pipe_v(out, 946, 106, 345, 11, Art.VERDIGRIS, 19)
	_pipe_h(out, 849, 418, 53, 15, Art.STEEL_PIPE, 20)
	_pipe_h(out, 794, 443, 164, 12, Art.VERDIGRIS, 23)
	_pipe_h(out, 258, 92, 208, 15, Art.STEEL_PIPE, 29)
	_pipe_v(out, 260, 102, 153, 15, Art.STEEL_PIPE, 27)
	_pipe_h(out, 612, 104, 187, 14, Art.COPPER_PIPE, 24)
	_pipe_v(out, 785, 112, 115, 14, Art.COPPER_PIPE, 23)
	# Squared expansion joints with exposed bolt plates break long pipe runs.
	for centre: Vector2i in [Vector2i(120, 73), Vector2i(469, 72), Vector2i(744, 72),
			Vector2i(266, 168), Vector2i(847, 245), Vector2i(950, 344)]:
		Art._panel(out, centre.x - 7, centre.y - 9, 18, 23, Art.LEAD, Art.IRON)
		Art._rect(out, centre.x - 4, centre.y - 5, 11, 15, Art.RUSTED_STEEL)
		Art._rect(out, centre.x - 7, centre.y - 7, 2, 2, Art.BRONZE)
		Art._rect(out, centre.x + 8, centre.y + 10, 2, 2, Art.BRONZE)


static func _inspection_quarter(out: PackedInt32Array) -> void:
	# The west booth is tucked into the utility cliff rather than a free-standing house.
	Art._panel(out, 183, 292, 145, 118, Art.CONCRETE, Art.INDUSTRIAL_BRICK)
	Art._rect(out, 178, 286, 155, 8, Art.MOSS_STONE)
	Art._rect(out, 185, 297, 136, 5, Art.VERDIGRIS)
	Art._panel(out, 198, 315, 111, 47, Art.STEEL, Art.DARK_GLASS)
	Art._rect(out, 201, 318, 105, 2, Art.CYAN)
	Art._rect(out, 237, 317, 3, 43, Art.IRON)
	Art._rect(out, 278, 317, 2, 43, Art.IRON)
	Art._rect(out, 201, 352, 105, 6, Art.RUBBER)
	for index: int in range(9):
		Art._rect(out, 204 + index * 11, 354, 6, 1,
			Art.CYAN if index % 3 != 1 else Art.AMBER)
	Art._vent(out, 199, 375, 55, 27)
	Art._panel(out, 268, 372, 42, 29, Art.IRON, Art.PAINTED_STEEL)
	_text(out, "DRAIN", 273, 379, Art.AMBER)
	Art._rect(out, 280, 390, 14, 2, Art.CYAN)
	_lamp(out, 211, 304)
	_lamp(out, 298, 304)
	# A narrow hanging sign bridges the booth roof and a conduit rack.
	Art._rect(out, 301, 243, 3, 40, Art.CABLE)
	Art._panel(out, 296, 249, 25, 56, Art.RUSTED_STEEL, Art.IRON)
	_text(out, "S", 304, 255, Art.CYAN, 2)
	_text(out, "03", 301, 271, Art.AMBER, 2)
	Art._rect(out, 300, 290, 16, 2, Art.CYAN)
	# East inspection room has a lowered floor and an elevated control shelf.
	Art._panel(out, 734, 338, 140, 140, Art.CONCRETE, Art.CORRUGATED)
	Art._rect(out, 730, 332, 149, 8, Art.RUSTED_STEEL)
	Art._panel(out, 748, 353, 111, 37, Art.IRON, Art.DARK_GLASS)
	Art._rect(out, 751, 356, 105, 2, Art.AMBER)
	Art._rect(out, 784, 355, 2, 33, Art.LEAD)
	Art._rect(out, 820, 355, 2, 33, Art.LEAD)
	Art._vent(out, 750, 402, 45, 26)
	Art._panel(out, 810, 401, 48, 27, Art.IRON, Art.PAINTED_STEEL)
	_text(out, "PUMP", 817, 407, Art.CYAN)
	Art._rect(out, 813, 419, 39, 2, Art.HAZARD)
	for x: int in [744, 779, 822, 864]:
		Art._rect(out, x, 339, 2, 5, Art.STEEL)
		Art._rect(out, x, 471, 2, 5, Art.STEEL)
	Art._rect(out, 881, 324, 4, 74, Art.IRON)
	Art._rect(out, 879, 343, 9, 24, Art.HAZARD)
	_lamp(out, 761, 342)
	_lamp(out, 846, 342, Art.CYAN)


static func _pump_stack(out: PackedInt32Array) -> void:
	# The main silhouette is a stepped piston block with offset motor cages,
	# not a circular centerpiece. Three unequal plungers carry the top rhythm.
	Art._rect(out, 455, 116, 155, 88, Art.IRON)
	Art._rect(out, 467, 108, 129, 106, Art.STEEL)
	Art._rect(out, 473, 116, 117, 88, Art.PAINTED_STEEL)
	Art._rect(out, 476, 119, 111, 4, Art.VERDIGRIS)
	Art._rect(out, 480, 191, 103, 8, Art.RUBBER)
	Art._rect(out, 446, 138, 18, 50, Art.CORRUGATED)
	Art._rect(out, 601, 128, 30, 72, Art.RUSTED_STEEL)
	Art._rect(out, 632, 139, 35, 51, Art.IRON)
	for y: int in range(140, 188, 5):
		Art._rect(out, 630, y, 39, 2, Art.STEEL)
	for index: int in range(3):
		var x: int = 480 + index * 43
		var top: int = 76 - (index % 2) * 13
		Art._rect(out, x, top, 17, 43 + (index % 2) * 13, Art.IRON)
		Art._rect(out, x + 4, top + 4, 9, 34 + (index % 2) * 13, Art.STEEL_PIPE)
		Art._rect(out, x - 4, top + 3, 25, 5, Art.BRONZE)
		Art._rect(out, x - 2, top + 10, 21, 3, Art.RUSTED_STEEL)
		Art._rect(out, x - 3, 106, 23, 6, Art.IRON)
		_lamp(out, x + 6, top - 5)
	Art._panel(out, 486, 134, 88, 46, Art.IRON, Art.DARK_GLASS)
	Art._rect(out, 490, 138, 80, 2, Art.CYAN)
	Art._rect(out, 490, 141, 2, 33, Art.VERDIGRIS)
	_text(out, "P-03", 498, 155, Art.CYAN, 2)
	Art._rect(out, 558, 146, 7, 5, Art.AMBER)
	for index: int in range(6):
		Art._rect(out, 491 + index * 13, 183, 6, 3,
			Art.AMBER if index % 2 else Art.CYAN)
	Art._rivet_row(out, 469, 111, 125, 14, Art.IRON)
	Art._rivet_row(out, 469, 205, 125, 14, Art.IRON)
	# Offset gearbox and small valve wheel give the left shoulder a different mass.
	Art._panel(out, 367, 145, 78, 79, Art.RUSTED_STEEL, Art.CORRUGATED)
	Art._rect(out, 371, 149, 71, 6, Art.IRON)
	Art._rect(out, 376, 160, 58, 8, Art.HAZARD)
	Art._rect(out, 380, 223, 50, 5, Art.MOSS_STONE)
	Art._ring(out, 410, 194, 20, 5, Art.BRONZE)
	Art._ring(out, 410, 194, 14, 2, Art.STEEL)
	Art._rect(out, 393, 192, 35, 3, Art.IRON)
	Art._rect(out, 408, 177, 3, 35, Art.IRON)
	Art._rect(out, 380, 182, 5, 25, Art.COPPER_PIPE)
	_pipe_v(out, 375, 226, 74, 17, Art.COPPER_PIPE, 22)
	_pipe_h(out, 380, 287, 68, 16, Art.COPPER_PIPE, 20)
	Art._panel(out, 590, 208, 49, 34, Art.IRON, Art.RUSTED_STEEL)
	Art._vent(out, 599, 214, 31, 21)
	Art._rect(out, 593, 208, 41, 3, Art.AMBER)


static func _descending_sluice(out: PackedInt32Array) -> void:
	# Framed Water channels form an asymmetric stepped path through the ravine.
	# They contain finite authored Water; there are no decorative emitters.
	Art._panel(out, 516, 212, 35, 72, Art.STEEL_PIPE, Art.CHEMICAL_GLASS)
	Art._rect(out, 523, 220, 21, 57, Art.EMPTY)
	Art._rect(out, 525, 235, 17, 42, Art.WATER)
	Art._rect(out, 519, 221, 1, 54, Art.CYAN)
	Art._rect(out, 512, 214, 43, 5, Art.BRONZE)
	Art._rect(out, 512, 276, 43, 6, Art.BRONZE)
	Art._panel(out, 515, 281, 142, 42, Art.RUSTED_STEEL, Art.IRON)
	Art._rect(out, 521, 286, 130, 31, Art.EMPTY)
	Art._rect(out, 523, 296, 126, 21, Art.WATER)
	Art._rect(out, 520, 283, 132, 2, Art.VERDIGRIS)
	for x: int in range(537, 646, 22):
		Art._rect(out, x, 286, 3, 18, Art.GRATING)
		Art._rect(out, x - 1, 286, 5, 2, Art.LEAD)
	Art._panel(out, 630, 321, 29, 47, Art.STEEL_PIPE, Art.CHEMICAL_GLASS)
	Art._rect(out, 636, 325, 17, 37, Art.WATER)
	Art._rect(out, 632, 327, 1, 30, Art.CYAN)
	Art._panel(out, 423, 364, 236, 39, Art.STEEL, Art.IRON)
	Art._rect(out, 429, 370, 224, 27, Art.EMPTY)
	Art._rect(out, 431, 378, 220, 19, Art.WATER)
	Art._rect(out, 427, 366, 227, 2, Art.VERDIGRIS)
	Art._rivet_row(out, 425, 400, 229, 18, Art.BRONZE)
	Art._panel(out, 424, 401, 33, 74, Art.RUSTED_STEEL, Art.CHEMICAL_GLASS)
	Art._rect(out, 431, 407, 19, 62, Art.WATER)
	Art._rect(out, 427, 409, 1, 53, Art.AMBER)
	Art._rect(out, 420, 401, 41, 6, Art.IRON)
	Art._rect(out, 420, 468, 41, 6, Art.IRON)
	Art._panel(out, 449, 462, 211, 30, Art.BRONZE, Art.IRON)
	Art._rect(out, 455, 467, 199, 19, Art.WATER)
	Art._rect(out, 453, 464, 204, 1, Art.CYAN)
	for x: int in [473, 543, 615]:
		Art._rect(out, x, 462, 5, 29, Art.STEEL)
		Art._rect(out, x + 1, 469, 2, 11, Art.CHEMICAL_GLASS)
	# Heavy bolted gate handles are off-centre and overlap only the closed shells.
	Art._panel(out, 573, 261, 43, 22, Art.IRON, Art.STEEL)
	Art._rect(out, 579, 265, 31, 4, Art.HAZARD)
	Art._rect(out, 591, 247, 4, 19, Art.STEEL_PIPE)
	Art._rect(out, 581, 247, 24, 3, Art.BRONZE)
	Art._panel(out, 474, 344, 51, 22, Art.IRON, Art.RUSTED_STEEL)
	_text(out, "GATE", 480, 351, Art.AMBER)
	Art._rect(out, 493, 334, 4, 14, Art.STEEL_PIPE)
	Art._rect(out, 482, 332, 26, 4, Art.BRONZE)
	# Exposed electrical cabinet and offset lower gear pack flank the final drop.
	Art._panel(out, 471, 415, 54, 36, Art.IRON, Art.PAINTED_STEEL)
	Art._rect(out, 477, 421, 40, 15, Art.DARK_GLASS)
	_text(out, "LOW", 480, 425, Art.CYAN)
	Art._rect(out, 477, 443, 8, 3, Art.AMBER)
	Art._rect(out, 511, 442, 4, 4, Art.MAGENTA)
	Art._panel(out, 585, 420, 63, 34, Art.IRON, Art.CORRUGATED)
	Art._rect(out, 589, 425, 55, 3, Art.RUSTED_STEEL)
	Art._ring(out, 615, 441, 12, 4, Art.BRONZE)
	Art._rect(out, 605, 440, 21, 2, Art.IRON)
	_pipe_h(out, 532, 433, 53, 11, Art.VERDIGRIS, 21)


static func _service_catwalks(out: PackedInt32Array) -> void:
	_catwalk(out, 160, 242, 237)
	_catwalk(out, 665, 271, 211, Art.STEEL)
	_catwalk(out, 190, 405, 224)
	_catwalk(out, 680, 430, 215)
	_catwalk(out, 328, 332, 91, Art.RUSTED_STEEL)
	_ladder(out, 278, 248, 154)
	_ladder(out, 690, 278, 146)
	_ladder(out, 914, 363, 139)
	# A half-width maintenance shelf crosses behind the central shaft.
	Art._rect(out, 543, 247, 144, 5, Art.IRON)
	Art._rect(out, 549, 248, 135, 2, Art.GRATING)
	Art._rect(out, 678, 252, 3, 18, Art.STEEL)
	for point: Vector2i in [Vector2i(178, 235), Vector2i(341, 235),
			Vector2i(716, 264), Vector2i(852, 264), Vector2i(214, 398),
			Vector2i(386, 398), Vector2i(713, 423), Vector2i(874, 423)]:
		_lamp(out, point.x, point.y)
	# Danger stripes remain local accents, with open walking gaps between decks.
	Art._rect(out, 332, 242, 41, 3, Art.HAZARD)
	Art._rect(out, 792, 271, 47, 3, Art.HAZARD)
	Art._rect(out, 192, 405, 32, 3, Art.HAZARD)
	Art._rect(out, 842, 430, 34, 3, Art.HAZARD)


static func _hanging_services(out: PackedInt32Array) -> void:
	Art._draped_cable(out, Vector2i(245, 115), Vector2i(441, 165), 24.0)
	Art._draped_cable(out, Vector2i(657, 192), Vector2i(781, 139), 30.0)
	Art._draped_cable(out, Vector2i(328, 305), Vector2i(443, 328), 20.0)
	# Loose vertical bundles curl into rectangular trays instead of forming a
	# second focal halo. Tiny ties give each bundle a manufactured scale.
	for index: int in range(4):
		var x: int = 725 + index * 8
		var length: int = 127 + index * 14
		Art._rect(out, x, 60, 3, length, Art.CABLE)
		Art._rect(out, x, 60 + length - 3, 16 + index * 2, 3, Art.CABLE)
		Art._rect(out, x + 13 + index * 2, 43 + length, 3, 18, Art.CABLE)
		for y: int in range(76, 58 + length, 27):
			Art._rect(out, x - 1, y, 5, 2, Art.VERDIGRIS)
	Art._rect(out, 717, 55, 51, 7, Art.IRON)
	Art._rect(out, 719, 57, 46, 2, Art.AMBER)
	_pipe_v(out, 331, 67, 114, 8, Art.COPPER_PIPE, 21)
	_pipe_h(out, 333, 175, 37, 8, Art.COPPER_PIPE, 16)
	# Service labels read as small objects suspended in the open shaft.
	Art._rect(out, 350, 202, 2, 36, Art.CABLE)
	Art._panel(out, 336, 208, 38, 19, Art.IRON, Art.RUSTED_STEEL)
	_text(out, "WEST", 341, 214, Art.AMBER)
	Art._rect(out, 802, 251, 3, 65, Art.CABLE)
	Art._panel(out, 781, 280, 47, 24, Art.RUSTED_STEEL, Art.IRON)
	_text(out, "S-09", 790, 295, Art.MAGENTA)
	Art._rect(out, 785, 283, 39, 2, Art.CYAN)


static func _low_culverts(out: PackedInt32Array) -> void:
	# Three stepped basins supply readable native Water, with closed floors and
	# walls. Small glass-faced service ports interrupt the submerged masonry.
	Art._panel(out, 181, 449, 119, 75, Art.CONCRETE, Art.IRON)
	Art._rect(out, 187, 455, 107, 63, Art.EMPTY)
	Art._rect(out, 189, 470, 103, 47, Art.WATER)
	Art._rect(out, 185, 451, 111, 2, Art.VERDIGRIS)
	Art._panel(out, 208, 484, 34, 25, Art.STEEL, Art.DARK_GLASS)
	Art._rect(out, 211, 487, 28, 2, Art.AMBER)
	Art._rect(out, 224, 486, 2, 20, Art.IRON)
	Art._panel(out, 309, 491, 434, 46, Art.CONCRETE, Art.IRON)
	Art._rect(out, 316, 495, 420, 36, Art.EMPTY)
	Art._rect(out, 319, 506, 414, 25, Art.WATER)
	Art._rect(out, 312, 493, 427, 2, Art.MOSS_STONE)
	Art._rect(out, 315, 533, 424, 3, Art.VERDIGRIS)
	for x: int in [365, 636]:
		Art._panel(out, x, 515, 39, 15, Art.IRON, Art.DARK_GLASS)
		Art._rect(out, x + 3, 518, 33, 2, Art.CYAN)
		Art._rect(out, x + 18, 517, 2, 11, Art.LEAD)
	Art._panel(out, 754, 465, 146, 65, Art.MOSS_STONE, Art.IRON)
	Art._rect(out, 760, 471, 134, 53, Art.EMPTY)
	Art._rect(out, 762, 482, 130, 42, Art.WATER)
	Art._panel(out, 797, 498, 51, 24, Art.STEEL, Art.CHEMICAL_GLASS)
	Art._rect(out, 802, 502, 41, 2, Art.AMBER)
	Art._rect(out, 821, 500, 2, 19, Art.IRON)
	Art._rect(out, 795, 526, 58, 3, Art.BRONZE)
	Art._rect(out, 45, 535, 933, 21, Art.MOSS_STONE)
	Art._rect(out, 50, 539, 922, 17, Art.INDUSTRIAL_BRICK)
	Art._rect(out, 46, 534, 933, 3, Art.WET_COBBLE)
	for index: int in range(12):
		var x: int = 64 + index * 76
		Art._panel(out, x, 542, 58, 11, Art.IRON, Art.EMPTY)
		Art._rect(out, x + 3, 550, 52, 2, Art.VERDIGRIS)
		Art._rect(out, x + 20, 544, 2, 7, Art.GRATING)
		Art._rect(out, x + 39, 544, 2, 7, Art.GRATING)


static func _final_fittings(out: PackedInt32Array) -> void:
	# Crust, short dangling drains and wall repairs add detail without filling
	# the dark central voids or becoming isolated loose simulation particles.
	for index: int in range(22):
		var x: int = 55 + index * 41
		var width: int = 8 + (index % 4) * 3
		Art._rect(out, x, 47, width, 2, Art.VERDIGRIS)
		Art._rect(out, x + 2, 48, 2, 3 + index % 5, Art.MOSS_STONE)
		Art._rect(out, x + 6, 538, width, 2, Art.RUSTED_STEEL)
	for y: int in range(143, 484, 37):
		Art._rect(out, 153, y, 12, 4, Art.CONCRETE)
		Art._rect(out, 154, y + 4, 7, 2, Art.VERDIGRIS)
		Art._rect(out, 856, y + 7, 15, 3, Art.MOSS_STONE)
	Art._panel(out, 344, 461, 43, 21, Art.IRON, Art.RUSTED_STEEL)
	_text(out, "SEWER", 348, 467, Art.AMBER)
	Art._panel(out, 684, 453, 41, 24, Art.IRON, Art.PAINTED_STEEL)
	_text(out, "DEEP", 689, 459, Art.CYAN)
	Art._rect(out, 693, 469, 21, 2, Art.MAGENTA)
	# Final indicator lenses are fixed landmarks within actual pump/sign bodies.
	Art._rect(out, 528, 151, 5, 3, Art.CYAN)
	Art._rect(out, 408, 192, 4, 4, Art.AMBER)
	Art._rect(out, 802, 289, 5, 4, Art.MAGENTA)
