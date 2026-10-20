class_name CyberDeepworksArchitecture
extends RefCounted

# Authored scenery for one continuous 1024-cell-square installation. The two
# apparatus windows are kept empty in the play plane; independent native rear
# sets and the frozen far rooms are visible through those real openings.
const Cell = preload("res://scripts/cell_world.gd")
const SIDE: int = 256
const EXTENT: int = 1024
const LAYERS: Array[String] = ["play", "scripted", "effects", "background"]
const FOREGROUND_APERTURE := Rect2i(30, 70, 97, 122)
const REAR_APERTURE := Rect2i(140, 60, 80, 131)

# Dominant housing, warm/cold accent, inset finish. These are real catalogue
# materials. Low rear-layer exposure is owned by the depth compositor.
const PALETTES: Array[Array] = [
	[Cell.REINFORCED_CONCRETE, Cell.NEON_AMBER, Cell.GABION],
	[Cell.BRASS_PANEL, Cell.NEON_CYAN, Cell.VERDIGRIS_COPPER],
	[Cell.ALUMINIUM_PANEL, Cell.LED_WHITE, Cell.FROSTED_GLASS],
	[Cell.LIMESTONE_BLOCK, Cell.NEON_AMBER, Cell.ROCK_SALT_BLOCK],
	[Cell.RUSTED_STEEL, Cell.NEON_AMBER, Cell.BARE_IRON],
	[Cell.MARBLE, Cell.NEON_MAGENTA, Cell.GOLD_LEAF],
	[Cell.ADOBE_BRICK, Cell.NEON_AMBER, Cell.RAW_CLAY],
	[Cell.OBSIDIAN, Cell.NEON_CYAN, Cell.URANIUM_GLASS],
	[Cell.HEAT_SHIELD_TILE, Cell.NEON_AMBER, Cell.FIREBRICK],
	[Cell.CHALK_BLOCK, Cell.LED_WHITE, Cell.TERRAZZO],
	[Cell.INDUSTRIAL_BRICK, Cell.NEON_MAGENTA, Cell.WALNUT_PANEL],
	[Cell.CHARRED_TIMBER, Cell.NEON_AMBER, Cell.FIREBRICK],
	[Cell.CARBON_FIBRE, Cell.NEON_CYAN, Cell.POLYMER_PANEL],
	[Cell.VERDIGRIS_COPPER, Cell.NEON_MAGENTA, Cell.BAMBOO],
	[Cell.MOSSY_COBBLESTONE, Cell.NEON_CYAN, Cell.MOSS_WALL],
	[Cell.BASALT_COLUMNS, Cell.NEON_CYAN, Cell.STEEL_PIPE],
]

# Shallow, isolated display niches preserve all 51 MAT-002 identities even
# after a consumable reaction specimen elsewhere in a room has been exhausted.
const SWATCHES: Array[Array] = [
	[Cell.CARDBOARD, Cell.SANDBAG, Cell.RAMMED_EARTH, Cell.GABION],
	[Cell.ZINC_SHEET, Cell.BARE_IRON, Cell.GOLD_LEAF, Cell.BRASS_PANEL],
	[Cell.PACKED_SNOW, Cell.FROSTED_GLASS, Cell.GYPSUM_BOARD, Cell.ALUMINIUM_PANEL],
	[Cell.ROCK_SALT_BLOCK, Cell.CHALK_BLOCK, Cell.TERRAZZO, Cell.SUGAR_GLASS],
	[Cell.BARE_IRON, Cell.ZINC_SHEET, Cell.BASALT_COLUMNS, Cell.CARBON_FIBRE],
	[Cell.MARBLE, Cell.GOLD_LEAF, Cell.GLASS_BLOCK, Cell.BRASS_PANEL],
	[Cell.ADOBE_BRICK, Cell.RAW_CLAY, Cell.FIREBRICK, Cell.RAMMED_EARTH],
	[Cell.OBSIDIAN, Cell.QUARTZ_CRYSTAL, Cell.URANIUM_GLASS, Cell.GLASS_BLOCK],
	[Cell.MAGNESIUM_PLATE, Cell.THERMITE_BRICK, Cell.HEAT_SHIELD_TILE, Cell.FIREBRICK],
	[Cell.QUICKLIME_BLOCK, Cell.CHALK_BLOCK, Cell.TERRAZZO, Cell.GYPSUM_BOARD],
	[Cell.PINE_PLANKS, Cell.WALNUT_PANEL, Cell.MAHOGANY_PANEL, Cell.PAPER_SCREEN, Cell.CEDAR_SHINGLES],
	[Cell.BIRCH_LOG, Cell.OAK_LOG, Cell.DRIFTWOOD, Cell.CHARRED_TIMBER, Cell.TAR_BLOCK],
	[Cell.ACRYLIC_SHEET, Cell.POLYMER_PANEL, Cell.SOLAR_PANEL, Cell.CARBON_FIBRE],
	[Cell.BAMBOO, Cell.CORK, Cell.WICKER, Cell.WAX_BLOCK, Cell.SULFUR_BLOCK],
	[Cell.MOSS_WALL, Cell.PLYWOOD, Cell.SUGAR_GLASS, Cell.PHOSPHOR_PANEL],
	[Cell.HEAT_SHIELD_TILE, Cell.ALUMINIUM_PANEL, Cell.POLYMER_PANEL, Cell.BASALT_COLUMNS],
]

class Canvas:
	extends RefCounted
	var data := PackedInt32Array()
	var origin := Vector2i.ZERO

	func rect(x: int, y: int, width: int, height: int, material: int) -> void:
		# Clip locally as well as globally: a room may never paint its neighbour.
		var local: Rect2i = Rect2i(x, y, width, height).intersection(Rect2i(0, 0, 256, 256))
		if not local.has_area(): return
		var world: Rect2i = Rect2i(local.position + origin, local.size).intersection(Rect2i(0, 0, 1024, 1024))
		if world.has_area():
			data.append_array(PackedInt32Array([world.position.x, world.position.y, world.size.x, world.size.y, material]))

	func panel(x: int, y: int, width: int, height: int, rim: int, fill: int, inset: int = 2) -> void:
		rect(x, y, width, height, rim)
		rect(x + inset, y + inset, width - inset * 2, height - inset * 2, fill)

	func beam(a: Vector2i, b: Vector2i, width: int, material: int, step: int = 6) -> void:
		var length: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
		var count: int = maxi(1, ceili(float(length) / float(step)))
		for index: int in range(count + 1):
			var point := Vector2i(Vector2(a).lerp(Vector2(b), float(index) / float(count)).round())
			rect(point.x - width / 2, point.y - width / 2, width, width, material)

	func octagon(x: int, y: int, width: int, height: int, corner: int, material: int) -> void:
		rect(x + corner, y, width - corner * 2, height, material)
		rect(x, y + corner, width, height - corner * 2, material)
		# Four chunky stair strips provide recognisable chamfers within a budget.
		for index: int in range(3):
			var cut: int = (corner * (3 - index)) / 4
			var band: int = maxi(1, corner / 4)
			rect(x + cut, y + band * (index + 1), width - cut * 2, band, material)
			rect(x + cut, y + height - band * (index + 2), width - cut * 2, band, material)


static func build() -> Dictionary:
	var result: Dictionary = {}
	for layer: String in LAYERS:
		var canvas := Canvas.new()
		for index: int in range(16):
			canvas.origin = Vector2i(index % 4, index / 4) * SIDE
			match layer:
				"play": _play(canvas, index)
				"scripted": _scripted(canvas, index)
				"effects": _effects(canvas, index)
				"background": _background(canvas, index)
		result[layer] = canvas.data
	return result


static func _play(a: Canvas, index: int) -> void:
	var housing: int = PALETTES[index][0]
	var accent: int = PALETTES[index][1]
	var finish: int = PALETTES[index][2]
	# The shell is a heavy interrupted arch, never a solid pane over an exhibit.
	a.rect(3, 3, 223, 205, Cell.REINFORCED_CONCRETE)
	a.rect(8, 8, 213, 195, housing)
	a.rect(28, 37, 194, 157, Cell.EMPTY)
	a.rect(9, 36, 17, 160, Cell.STEEL_PLATE)
	a.rect(12, 39, 11, 151, finish)
	a.rect(25, 42, 3, 152, Cell.RUSTED_STEEL)
	a.rect(127, 62, 11, 133, housing)
	a.rect(129, 65, 2, 125, Cell.STEEL_PIPE)
	a.rect(136, 75, 2, 111, Cell.RUBBER)
	a.rect(222, 33, 4, 171, Cell.STEEL_PLATE)
	a.rect(8, 199, 215, 8, Cell.STEEL_GRATING)
	a.rect(9, 199, 214, 2, Cell.RUSTED_STEEL)
	a.rect(29, 194, 192, 4, housing)
	a.rect(33, 195, 185, 1, Cell.STEEL_PLATE)
	a.rect(7, 5, 219, 2, Cell.ASPHALT)
	# Recessed near-side instrument rail and very small maintenance flourishes.
	for y: int in [78, 116, 155]:
		_panel(a, 10, y, 16, 23, Cell.STEEL_PLATE, Cell.DARK_GLASS)
		a.rect(13, y + 4, 9, 1, accent)
		a.rect(13, y + 9, 2, 5, Cell.CABLE_BUNDLE)
		a.rect(18, y + 9, 4, 2, Cell.STEEL_PLATE)
	_lamp(a, 10, 55, 12, accent)
	_lamp(a, 130, 48, 5, accent)
	_lamp(a, 224, 196, 2, accent)
	_number(a, index + 1, Vector2i(11, 14), Cell.LED_WHITE)
	# Sixteen distinct overhead machines and architectural crowns.
	_header(a, index, housing, accent, finish)
	_swatches(a, index)
	# Pipe clamps, bolt pairs, tiny debris and a route-facing equipment shelf.
	for x: int in [18, 72, 133, 181, 216]:
		a.rect(x, 203, 2, 2, Cell.STEEL_PLATE)
		a.rect(x, 8, 2, 2, Cell.BARE_IRON)
	for item: int in range(4):
		var x: int = 39 + item * 41
		a.rect(x, 192, 9 + (index + item) % 5, 2, Cell.RUBBER)
		a.rect(x + 2, 191, 4, 2, finish)
	# Final aperture ownership is intentional even where a header protrudes.
	_clear(a, FOREGROUND_APERTURE)
	_clear(a, REAR_APERTURE)


static func _header(a: Canvas, index: int, housing: int, accent: int, finish: int) -> void:
	match index:
		0: # Customs: shuttered weighbridge, stacked tags and a crooked lifting arm.
			_vent(a, 34, 39, 49, 22, Cell.ZINC_SHEET)
			a.rect(90, 42, 44, 8, Cell.HAZARD_STRIPE)
			a.rect(99, 50, 4, 17, Cell.STEEL_PIPE)
			a.rect(116, 50, 2, 13, Cell.STEEL_PIPE)
			a.beam(Vector2i(141, 38), Vector2i(174, 56), 5, Cell.STEEL_PLATE)
			a.rect(176, 40, 40, 11, Cell.GABION)
			a.rect(183, 52, 27, 4, Cell.SANDBAG)
		1: # Copper Choir: organ headers and little staggered resonator necks.
			for column: int in range(7):
				var x: int = 33 + column * 26
				var height: int = 14 + (column * 7) % 15
				a.rect(x, 35, 9, height, Cell.COPPER_PIPE)
				a.rect(x + 2, 38, 2, height - 4, Cell.VERDIGRIS_COPPER)
				a.rect(x - 1, 37, 11, 2, Cell.BRASS_PANEL)
				a.rect(x + 3, 35 + height, 3, 3, accent)
		2: # Frost Mortuary: stepped cold-store insulation and narrow gaskets.
			for column: int in range(5):
				var x: int = 31 + column * 37
				_panel(a, x, 36, 31, 20 + column % 2 * 7, Cell.ALUMINIUM_PANEL, Cell.FROSTED_GLASS)
				a.rect(x + 5, 39, 21, 2, Cell.PACKED_SNOW)
				a.rect(x + 4, 49, 3, 4, Cell.RUBBER)
		3: # Halite Exchange: market awning, boxed scales and specimen weights.
			a.rect(31, 39, 189, 4, Cell.WALNUT_PANEL)
			for column: int in range(8):
				var x: int = 34 + column * 23
				a.rect(x, 43, 14, 5 + column % 3, Cell.CORK)
				a.rect(x + 3, 50, 5, 7, Cell.ROCK_SALT_BLOCK)
				a.rect(x + 1, 57, 10, 2, Cell.BRASS_PANEL)
		4: # Oxide Records: different-depth sealed cabinets, numbered by bolts.
			for column: int in range(6):
				var x: int = 32 + column * 31
				_panel(a, x, 37, 25, 20 + column % 2 * 7, Cell.BARE_IRON, Cell.RUSTED_STEEL)
				a.rect(x + 4, 41, 15, 1, Cell.ZINC_SHEET)
				a.rect(x + 17, 45, 2, 2, accent)
		5: # Marble Reliquary: faceted hanging cornice and gilded chapel teeth.
			for step: int in range(6):
				a.rect(30 + step * 14, 39 + step * 3, 15, 7, Cell.MARBLE)
				a.rect(207 - step * 14, 39 + step * 3, 15, 7, Cell.MARBLE)
				a.rect(32 + step * 14, 45 + step * 3, 12, 1, Cell.GOLD_LEAF)
				a.rect(208 - step * 14, 45 + step * 3, 12, 1, Cell.GOLD_LEAF)
			a.rect(120, 43, 10, 16, Cell.STAINED_GLASS)
		6: # Clay Ossuary: stepped kiln flues and fired sample ledges.
			for column: int in range(5):
				var x: int = 34 + column * 37
				a.rect(x, 36, 28, 22, Cell.ADOBE_BRICK)
				a.rect(x + 4, 39, 20, 15, Cell.DARK_GLASS)
				a.rect(x + 8, 42, 12, 11, Cell.TERRACOTTA_TILE)
				a.rect(x - 1, 56, 30, 3, Cell.FIREBRICK)
		7: # Prism Foundry: angled light-box crown and isolated casting guides.
			for column: int in range(6):
				var x: int = 33 + column * 31
				a.beam(Vector2i(x, 40), Vector2i(x + 20, 55), 4, Cell.ALUMINIUM_PANEL, 4)
				a.rect(x + 8, 42, 4, 13, Cell.QUARTZ_CRYSTAL)
				a.rect(x + 4, 59, 19, 2, Cell.URANIUM_GLASS)
		8: # Thermite Chapel: hard refractory teeth under a low blast lintel.
			a.rect(31, 37, 189, 7, Cell.HEAT_SHIELD_TILE)
			for column: int in range(8):
				var x: int = 34 + column * 23
				a.rect(x, 44, 15, 17, Cell.FIREBRICK)
				a.rect(x + 4, 47, 6, 12, Cell.DARK_GLASS)
				a.rect(x + 1, 62, 12, 2, Cell.HAZARD_STRIPE)
		9: # Lime hall: overhead mould rail and staggered hanging mould halves.
			a.rect(30, 38, 190, 5, Cell.STEEL_PLATE)
			for column: int in range(7):
				var x: int = 35 + column * 26
				a.rect(x + 6, 43, 2, 10, Cell.CABLE_BUNDLE)
				_panel(a, x, 51, 19, 11, Cell.TERRAZZO, Cell.DARK_GLASS)
		10: # Rainward homes: crooked canopies, little laundry and two balconies.
			a.rect(31, 38, 77, 5, Cell.CEDAR_SHINGLES)
			a.rect(132, 43, 87, 5, Cell.CORRUGATED_STEEL)
			a.rect(42, 45, 159, 1, Cell.CABLE_BUNDLE)
			for column: int in range(7):
				var x: int = 44 + column * 22
				a.rect(x, 46, 9, 8 + column % 3 * 3, [Cell.PAPER_SCREEN, Cell.MAHOGANY_PANEL, Cell.ACRYLIC_SHEET][column % 3])
			_lamp(a, 113, 53, 8, accent)
		11: # Crematorium: exhaust sockets and shallow coal-black firing mouths.
			for column: int in range(4):
				var x: int = 33 + column * 47
				_panel(a, x, 37, 35, 25, Cell.FIREBRICK, Cell.CHARRED_TIMBER)
				a.rect(x + 7, 44, 21, 11, Cell.DARK_GLASS)
				a.rect(x + 10, 60, 15, 2, accent)
		12: # Polymer Reclaimer: compact robot rail and angular material bins.
			a.rect(31, 37, 188, 5, Cell.ALUMINIUM_PANEL)
			a.rect(57, 42, 5, 17, Cell.CARBON_FIBRE)
			a.rect(55, 57, 22, 4, Cell.STEEL_PLATE)
			a.rect(73, 53, 4, 9, Cell.STEEL_PLATE)
			for column: int in range(5):
				var x: int = 87 + column * 26
				_panel(a, x, 45, 21, 14, Cell.CARBON_FIBRE, Cell.POLYMER_PANEL)
				a.rect(x + 4, 48, 3, 2, accent)
		13: # Poison Garden: layered planters on an abandoned laboratory trellis.
			a.rect(31, 39, 188, 3, Cell.BAMBOO)
			for column: int in range(6):
				var x: int = 34 + column * 30
				a.rect(x + 6, 43, 2, 16, Cell.BAMBOO)
				a.rect(x, 51, 21, 8, Cell.WICKER)
				a.rect(x + 3, 48, 15, 5, Cell.MOSS_WALL)
		14: # Mycelium Crypt: unequal burial niches below an old pressure header.
			a.rect(32, 37, 188, 5, Cell.VERDIGRIS_COPPER)
			for column: int in range(6):
				var x: int = 33 + column * 31
				_panel(a, x, 45, 24, 17, Cell.MOSSY_COBBLESTONE, Cell.DARK_GLASS)
				a.rect(x + 4, 48, 16, 2, Cell.PHOSPHOR_PANEL)
				a.rect(x + 9, 54, 6, 6, Cell.WAX_BLOCK)
		15: # Sump: thick service pipes and a low offset pump gearbox.
			_pipe(a, Vector2i(32, 43), Vector2i(217, 43), 8, Cell.STEEL_PIPE)
			for column: int in range(5):
				var x: int = 38 + column * 38
				a.rect(x, 47, 7, 14, Cell.VERDIGRIS_COPPER)
				a.rect(x - 2, 58, 11, 4, Cell.BRASS_PANEL)
			a.rect(180, 53, 36, 7, Cell.HAZARD_STRIPE)
	# A broken-off tag and manual lever give every large head a human scale.
	a.rect(218, 18, 3, 16, Cell.BARE_IRON)
	a.rect(215, 32, 6, 2, accent)
	a.rect(26, 33, 9, 2, housing)
	a.rect(27, 34, 2, 4, finish)


static func _swatches(a: Canvas, index: int) -> void:
	var list: Array = SWATCHES[index]
	for item: int in range(list.size()):
		var x: int = 32 + item * 35
		_panel(a, x, 11, 29, 23, Cell.STEEL_PLATE, Cell.DARK_GLASS)
		a.rect(x + 4, 15, 21, 13, int(list[item]))
		a.rect(x + 5, 30, 8, 1, Cell.ALUMINIUM_PANEL)
		a.rect(x + 22, 30, 2, 1, PALETTES[index][1])


static func _scripted(a: Canvas, index: int) -> void:
	var finish: int = PALETTES[index][2]
	var accent: int = PALETTES[index][1]
	# Rear industrial gantries wrap the reserved reaction window; they are not
	# collider surrogates for the foreground architecture.
	a.rect(7, 199, 219, 5, Cell.STEEL_GRATING)
	a.rect(17, 46, 208, 4, Cell.RUSTED_STEEL)
	a.rect(17, 47, 208, 1, finish)
	a.rect(133, 50, 6, 145, Cell.STEEL_PLATE)
	a.rect(136, 53, 1, 139, finish)
	a.rect(220, 50, 6, 145, Cell.STEEL_PLATE)
	a.rect(221, 51, 2, 141, finish)
	a.rect(141, 52, 78, 4, finish)
	a.rect(141, 55, 78, 2, Cell.STEEL_PLATE)
	a.rect(141, 193, 78, 3, Cell.STEEL_GRATING)
	for y: int in [68, 101, 139, 174]:
		a.rect(130, y, 8, 2, Cell.BARE_IRON)
		a.rect(223, y, 5, 3, Cell.BARE_IRON)
		a.rect(130, y, 2, 1, accent)
	# The left rear half is a unique workshop vignette behind the front exhibit.
	_side_workshop(a, index, finish, accent)
	# One cross-district service line continues through every view; vertical
	# ducts occupy the separate rear plane behind the clear circulation shafts.
	_pipe(a, Vector2i(0, 244), Vector2i(255, 244), 5, Cell.STEEL_PIPE)
	_pipe(a, Vector2i(254, 0), Vector2i(254, 255), 4, Cell.COPPER_PIPE)
	for y: int in [20, 82, 142, 202]:
		a.rect(251, y, 5, 2, Cell.BARE_IRON)
	_clear(a, REAR_APERTURE)


static func _side_workshop(a: Canvas, index: int, finish: int, accent: int) -> void:
	# Cabinets, chairs, hanging tools and side set pieces stay at a shallow
	# exposure in the rear plane, giving foreground reaction cells clear contrast.
	var x: int = 38 + index % 3 * 9
	var y: int = 129 - index % 2 * 13
	_panel(a, x, y, 56, 42, Cell.BARE_IRON, Cell.DARK_GLASS)
	for shelf: int in range(3):
		a.rect(x + 3, y + 12 + shelf * 11, 50, 2, Cell.STEEL_PLATE)
		for jar: int in range(3):
			var material: int = SWATCHES[index][(shelf + jar) % SWATCHES[index].size()]
			a.rect(x + 7 + jar * 15, y + 5 + shelf * 11, 7 + jar % 2, 7, material)
			a.rect(x + 8 + jar * 15, y + 4 + shelf * 11, 5, 1, Cell.ALUMINIUM_PANEL)
	a.rect(x - 5, y + 42, 69, 4, finish)
	a.rect(x - 1, y + 46, 3, 19, Cell.STEEL_PIPE)
	a.rect(x + 55, y + 46, 3, 19, Cell.STEEL_PIPE)
	# Small chair, cup and two spanners in the narrow maintenance strip.
	a.rect(x + 22, y + 54, 17, 3, Cell.WALNUT_PANEL)
	a.rect(x + 22, y + 43, 3, 12, Cell.WALNUT_PANEL)
	a.rect(x + 24, y + 57, 2, 7, Cell.STEEL_PIPE)
	a.rect(x + 36, y + 57, 2, 7, Cell.STEEL_PIPE)
	a.rect(x + 44, y + 36, 5, 5, Cell.CERAMIC_TILE)
	a.rect(x + 45, y + 35, 3, 1, Cell.DARK_GLASS)
	for tool: int in range(2):
		a.rect(112 + tool * 9, 74, 2, 17, Cell.ALUMINIUM_PANEL)
		a.rect(110 + tool * 9, 73, 6, 3, Cell.ALUMINIUM_PANEL)
		a.rect(112 + tool * 9, 72, 2, 3, Cell.EMPTY)
	_lamp(a, x + 8, y - 8, 36, accent)
	# Different tall silhouettes avoid sixteen instances of the same shelf.
	match index % 4:
		0:
			_vent(a, 38, 59, 37, 43, finish)
			a.beam(Vector2i(78, 60), Vector2i(108, 108), 4, Cell.STEEL_PIPE)
		1:
			_pipe(a, Vector2i(37, 56), Vector2i(37, 119), 7, finish)
			_pipe(a, Vector2i(38, 62), Vector2i(91, 62), 5, finish)
			_valve(a, 85, 72, accent)
		2:
			for tray: int in range(3):
				_panel(a, 36 + tray * 25, 62 + tray * 9, 20, 24, Cell.STEEL_PLATE, finish)
				a.rect(41 + tray * 25, 67 + tray * 9, 9, 1, accent)
		3:
			a.octagon(42, 59, 47, 50, 10, Cell.STEEL_PLATE)
			a.octagon(47, 64, 37, 40, 8, finish)
			a.rect(53, 87, 26, 3, Cell.DARK_GLASS)
			a.rect(55, 88, 11, 1, accent)


static func _effects(a: Canvas, index: int) -> void:
	# Sparse native material wisps in every area. The host's bounded emitters
	# supply ongoing activity; these are just the initial suspended atmosphere.
	var material: int = Cell.DUST
	if index in [2, 9, 10, 15]: material = Cell.STEAM
	elif index in [8, 11, 12]: material = Cell.SMOKE
	for wisp: int in range(4):
		var x: int = 41 + (index * 19 + wisp * 37) % 157
		var y: int = 64 + (index * 13 + wisp * 29) % 127
		a.rect(x, y, 1 + wisp % 2, 3 + wisp % 3, material)
	# An additional isolated glint in cold or wet rooms is actual native Water.
	if index in [2, 3, 9, 10, 13, 15]:
		a.rect(206, 67, 1, 3, Cell.WATER)


static func _background(a: Canvas, index: int) -> void:
	var housing: int = PALETTES[index][0]
	var accent: int = PALETTES[index][1]
	var finish: int = PALETTES[index][2]
	var shadow: int = _far_shadow(index)
	# Full far-plane coverage includes walls behind every room and route. It
	# is never simulated, so material swatches here cannot become hidden fires.
	# Matte rear walls keep speculative glass streaks out of apparent air; real
	# display windows and tiny instrument screens retain their authored glazing.
	a.rect(0, 0, 256, 256, shadow)
	a.rect(0, 0, 256, 8, Cell.HEAT_SHIELD_TILE)
	a.rect(0, 249, 256, 7, Cell.BASALT_COLUMNS)
	a.rect(4, 6, 222, 203, Cell.BASALT_COLUMNS if index > 11 else Cell.PAINTED_STEEL)
	a.rect(13, 15, 204, 181, shadow)
	# Structural ribs extend behind the service passages and are intentionally
	# discontinuous in depth, while world coordinates remain continuous.
	for x: int in [7, 123, 226, 252]:
		a.rect(x, 8, 3, 241, Cell.RUSTED_STEEL)
		a.rect(x + 1, 9, 1, 239, Cell.BARE_IRON)
	for y: int in [24, 205, 247]:
		a.rect(0, y, 256, 2, Cell.STEEL_GRATING)
	_background_hero(a, index, housing, finish, accent, shadow)
	# Tiny far-room service furniture makes the quiet margins feel inhabited.
	for alcove: int in range(3):
		var x: int = 22 + alcove * 72
		_panel(a, x, 214, 41, 26, Cell.BASALT_COLUMNS, Cell.DARK_GLASS)
		a.rect(x + 4, 230, 32, 2, finish)
		a.rect(x + 7, 221, 6, 9, housing)
		a.rect(x + 19, 222, 11, 7, Cell.CABLE_BUNDLE)
		a.rect(x + 20, 225, 5, 1, accent)
		a.rect(x + 5, 217, 4, 1, Cell.LED_WHITE)
	for indicator: int in range(4):
		a.rect(235, 32 + indicator * 47, 8, 2, accent)
		a.rect(239, 35 + indicator * 47, 2, 12, Cell.CABLE_BUNDLE)


static func _background_hero(a: Canvas, index: int, housing: int, finish: int, accent: int, shadow: int) -> void:
	match index:
		0: # Monumental customs gate, stopped cargo train and crane cross-brace.
			a.rect(31, 39, 169, 142, Cell.REINFORCED_CONCRETE)
			a.rect(43, 52, 145, 119, shadow)
			a.rect(44, 53, 143, 6, Cell.STEEL_PLATE)
			for pier: int in [51, 111, 178]:
				a.rect(pier, 59, 5, 111, Cell.GABION)
			for cargo: int in range(4):
				_panel(a, 40 + cargo * 39, 128 - cargo % 2 * 12, 33, 38, Cell.BARE_IRON, Cell.SANDBAG if cargo % 2 else Cell.RAMMED_EARTH)
				a.rect(43 + cargo * 39, 138 - cargo % 2 * 12, 9, 2, Cell.ALUMINIUM_PANEL)
			a.beam(Vector2i(54, 63), Vector2i(109, 112), 6, Cell.BARE_IRON, 5)
			a.rect(105, 109, 8, 11, accent)
			a.rect(34, 172, 171, 4, Cell.HAZARD_STRIPE)
		1: # A grand, asymmetric copper organ and suspended tuning wheel.
			for pipe: int in range(9):
				var x: int = 28 + pipe * 21
				var y: int = 47 + absi(pipe - 4) * 7
				_pipe(a, Vector2i(x, y), Vector2i(x, 183), 10, Cell.COPPER_PIPE)
				a.rect(x - 5, y - 3, 10, 3, Cell.BRASS_PANEL)
				a.rect(x - 1, y + 7, 2, 13, accent)
			a.octagon(68, 71, 95, 101, 21, Cell.BRASS_PANEL)
			a.octagon(73, 76, 85, 91, 19, shadow)
			a.rect(113, 90, 5, 61, Cell.VERDIGRIS_COPPER)
			a.rect(98, 116, 37, 4, Cell.GOLD_LEAF)
		2: # Deep morgue drawers, offset observation booth and freezer louvres.
			for row: int in range(5):
				for column: int in range(3):
					var x: int = 24 + column * 44
					var y: int = 40 + row * 29
					_panel(a, x, y, 36, 23, Cell.ALUMINIUM_PANEL, Cell.FROSTED_GLASS)
					a.rect(x + 5, y + 10, 14, 2, Cell.STEEL_PLATE)
					a.rect(x + 27, y + 6, 2, 3, accent)
			_panel(a, 162, 74, 46, 92, Cell.REINFORCED_CONCRETE, Cell.DARK_GLASS)
			_vent(a, 168, 121, 33, 35, Cell.ALUMINIUM_PANEL)
		3: # Stepped trading stalls under an old halite sorting arch.
			for stall: int in range(4):
				var x: int = 25 + stall * 47
				var y: int = 90 - stall % 2 * 18
				_panel(a, x, y, 40, 77, Cell.LIMESTONE_BLOCK, shadow)
				a.rect(x - 2, y - 5, 44, 7, Cell.WALNUT_PANEL)
				a.rect(x + 3, y + 37, 34, 4, Cell.BRASS_PANEL)
				for item: int in range(3):
					a.rect(x + 6 + item * 9, y + 26 - item % 2 * 5, 7, 11 + item % 2 * 5, Cell.ROCK_SALT_BLOCK)
				a.rect(x + 9, y + 62, 21, 2, accent)
			a.beam(Vector2i(28, 72), Vector2i(115, 38), 7, Cell.LIMESTONE_BLOCK)
			a.beam(Vector2i(115, 38), Vector2i(205, 69), 7, Cell.LIMESTONE_BLOCK)
		4: # Endless filing shelves with an abandoned travelling retrieval cage.
			for row: int in range(6):
				for column: int in range(6):
					var x: int = 26 + column * 29
					var y: int = 37 + row * 25
					a.rect(x, y, 22, 18, Cell.BARE_IRON if (row + column) % 3 else Cell.RUSTED_STEEL)
					a.rect(x + 5, y + 7, 12, 2, Cell.ZINC_SHEET)
					a.rect(x + 2, y + 3, 1, 1, accent)
			a.rect(108, 31, 5, 157, Cell.CARBON_FIBRE)
			_panel(a, 87, 94, 46, 53, Cell.STEEL_PLATE, shadow)
			a.rect(92, 97, 35, 2, accent)
		5: # Gilded marble reliquary: large stepped arch and floating sarcophagus.
			for step: int in range(7):
				a.rect(25 + step * 10, 104 - step * 10, 12, 83 + step * 10, Cell.SLATE)
				a.rect(196 - step * 10, 104 - step * 10, 12, 83 + step * 10, Cell.SLATE)
				a.rect(36 + step * 10, 104 - step * 10, 2, 74 + step * 10, Cell.MARBLE)
			a.rect(94, 40, 45, 10, Cell.MARBLE)
			a.rect(100, 51, 3, 24, Cell.BRONZE)
			a.rect(132, 51, 3, 24, Cell.BRONZE)
			a.octagon(88, 74, 58, 86, 12, Cell.GOLD_LEAF)
			a.octagon(93, 79, 48, 76, 10, Cell.STAINED_GLASS)
			a.rect(112, 91, 8, 47, Cell.QUARTZ_CRYSTAL)
			a.rect(111, 141, 11, 2, accent)
		6: # Tiered ovens, long firing throat and uneven clay specimen alcoves.
			a.rect(24, 37, 183, 151, Cell.ADOBE_BRICK)
			for row: int in range(3):
				for column: int in range(4):
					var x: int = 32 + column * 43
					var y: int = 45 + row * 44
					_panel(a, x, y, 35, 35, Cell.FIREBRICK, shadow)
					a.rect(x + 9, y + 18, 16, 12, Cell.RAW_CLAY if row % 2 else Cell.TERRACOTTA_TILE)
					a.rect(x + 5, y + 4, 24, 2, accent)
			a.rect(23, 179, 186, 5, Cell.STEEL_GRATING)
		7: # Prism fan: non-repeating crystalline casting shafts and glints.
			for prism: int in range(7):
				var x: int = 27 + prism * 26
				var y: int = 61 + (prism * 13) % 37
				a.octagon(x, y, 20, 182 - y, 6, [Cell.GLASS_BLOCK, Cell.QUARTZ_CRYSTAL, Cell.URANIUM_GLASS][prism % 3])
				a.rect(x + 5, y + 10, 2, 161 - y, Cell.FROSTED_GLASS)
				a.rect(x - 2, 174, 24, 8, Cell.OBSIDIAN)
				a.rect(x + 9, y - 5, 2, 4, accent)
			a.beam(Vector2i(24, 51), Vector2i(209, 70), 5, Cell.ALUMINIUM_PANEL)
		8: # Brutalist reactor chapel with an octagonal black mouth and clamps.
			a.octagon(33, 39, 174, 153, 33, Cell.FIREBRICK)
			a.octagon(41, 47, 158, 137, 29, Cell.HEAT_SHIELD_TILE)
			a.octagon(60, 64, 119, 101, 24, shadow)
			for side: int in [-1, 1]:
				for y: int in [77, 107, 137]:
					a.rect(116 + side * 57, y, 18, 11, Cell.MAGNESIUM_PLATE)
					a.rect(119 + side * 57, y + 4, 11, 2, Cell.THERMITE_BRICK)
			a.rect(108, 88, 20, 62, Cell.THERMITE_BRICK)
			a.rect(115, 97, 5, 43, accent)
			a.rect(88, 177, 63, 5, Cell.HAZARD_STRIPE)
		9: # Lime casting hall: staggered press moulds above a broad casting bed.
			a.rect(25, 163, 183, 23, Cell.TERRAZZO)
			a.rect(29, 157, 177, 5, Cell.STEEL_GRATING)
			for press: int in range(5):
				var x: int = 29 + press * 37
				a.rect(x + 7, 39, 9, 67 + press % 2 * 13, Cell.STEEL_PIPE)
				_panel(a, x, 98 + press % 2 * 13, 28, 42, Cell.ALUMINIUM_PANEL, Cell.QUICKLIME_BLOCK)
				a.rect(x + 5, 133 + press % 2 * 13, 18, 3, Cell.CHALK_BLOCK)
				a.rect(x + 4, 106 + press % 2 * 13, 20, 2, accent)
		10: # Rainward Tenements: inhabited three-storey cross-section and garden.
			for floor: int in range(3):
				for home: int in range(4):
					var x: int = 26 + home * 46
					var y: int = 40 + floor * 48
					_panel(a, x, y, 40, 39, Cell.INDUSTRIAL_BRICK, Cell.PAPER_SCREEN if home % 2 else Cell.WALNUT_PANEL)
					a.rect(x + 4, y + 5, 29, 25, shadow)
					a.rect(x + 8, y + 23, 18, 5, Cell.PINE_PLANKS)
					a.rect(x + 11, y + 18, 4, 5, Cell.CERAMIC_TILE)
					a.rect(x + 29, y + 9, 2, 11, accent)
					a.rect(x - 2, y + 37, 44, 3, Cell.STEEL_GRATING)
			for planter: int in range(5):
				a.rect(30 + planter * 36, 186, 24, 6, Cell.WICKER)
				a.rect(33 + planter * 36, 180, 18, 6, Cell.MOSS_WALL)
		11: # Timber Crematorium: three great kiln mouths and broken flue lattice.
			for kiln: int in range(3):
				var x: int = 29 + kiln * 59
				a.rect(x + 12, 38, 27, 56, Cell.CHARRED_TIMBER)
				a.octagon(x, 87, 50, 94, 12, Cell.FIREBRICK)
				a.octagon(x + 6, 93, 38, 81, 9, shadow)
				for log: int in range(4):
					a.rect(x + 10, 155 - log * 9, 28, 6, Cell.BIRCH_LOG if log % 2 else Cell.OAK_LOG)
				a.rect(x + 7, 170, 34, 2, accent)
			a.rect(23, 50, 185, 7, Cell.RUSTED_STEEL)
			a.rect(84, 55, 3, 39, Cell.CABLE_BUNDLE)
		12: # Polygonal reclamation carousel, saw-tooth mould bins and rack arms.
			a.octagon(54, 50, 119, 121, 27, Cell.CARBON_FIBRE)
			a.octagon(64, 60, 99, 101, 21, Cell.POLYMER_PANEL)
			a.octagon(84, 80, 59, 61, 13, shadow)
			a.rect(101, 95, 23, 29, Cell.SOLAR_PANEL)
			for bin: int in range(5):
				_panel(a, 25 + bin * 38, 172, 30, 20, Cell.ALUMINIUM_PANEL, Cell.ACRYLIC_SHEET)
				a.rect(29 + bin * 38, 176, 4, 8, accent)
			a.beam(Vector2i(31, 49), Vector2i(74, 89), 6, Cell.ALUMINIUM_PANEL)
			a.beam(Vector2i(201, 51), Vector2i(160, 99), 6, Cell.ALUMINIUM_PANEL)
		13: # Poison Garden: uneven tall trellis, glasshouse fragments and roots.
			for stem: int in range(8):
				var x: int = 28 + stem * 25
				var y: int = 44 + stem % 3 * 17
				a.rect(x, y, 5, 139 - stem % 3 * 17, Cell.BAMBOO)
				a.rect(x - 4, y + 20, 15, 3, Cell.VERDIGRIS_COPPER)
				a.rect(x + 5, y + 28, 11, 6, Cell.MOSS_WALL)
				a.rect(x - 8, y + 62, 13, 5, Cell.MOSS_WALL)
				a.rect(x - 4, 179, 18, 12, Cell.CORK)
			a.beam(Vector2i(24, 61), Vector2i(116, 33), 6, Cell.VERDIGRIS_COPPER)
			a.beam(Vector2i(116, 33), Vector2i(207, 57), 6, Cell.VERDIGRIS_COPPER)
			a.rect(109, 42, 9, 10, Cell.URANIUM_GLASS)
		14: # Mycelium Crypt: lower vaults under a sprawling stepped fungal crown.
			for crypt: int in range(4):
				var x: int = 27 + crypt * 47
				_panel(a, x, 103 + crypt % 2 * 12, 39, 70, Cell.MOSSY_COBBLESTONE, shadow)
				a.rect(x + 11, 152 + crypt % 2 * 12, 16, 19, Cell.DRIFTWOOD)
				a.rect(x + 8, 137 + crypt % 2 * 12, 23, 3, Cell.PHOSPHOR_PANEL)
			for branch: int in range(7):
				var x: int = 30 + branch * 26
				var y: int = 52 + absi(branch - 3) * 7
				a.rect(x + 5, y + 8, 6, 61, Cell.MOSS_WALL)
				a.rect(x - 4, y + 5, 24, 6, Cell.PHOSPHOR_PANEL)
				a.rect(x, y, 16, 6, Cell.MOSS_WALL)
		15: # Abyssal Sump: staggered pump wheels above a frozen far-water horizon.
			a.rect(18, 177, 201, 23, Cell.WATER)
			a.rect(20, 173, 197, 4, Cell.STEEL_GRATING)
			for pump: int in range(3):
				var x: int = 28 + pump * 62
				var y: int = 68 + pump % 2 * 25
				_pipe(a, Vector2i(x + 22, 30), Vector2i(x + 22, y), 9, Cell.STEEL_PIPE)
				a.octagon(x, y, 53, 64, 12, Cell.BRASS_PANEL)
				a.octagon(x + 5, y + 5, 43, 54, 10, Cell.VERDIGRIS_COPPER)
				a.rect(x + 11, y + 29, 30, 4, Cell.DARK_GLASS)
				a.rect(x + 23, y + 15, 4, 33, Cell.DARK_GLASS)
				a.rect(x + 23, y + 28, 4, 4, accent)
				a.rect(x + 19, y + 64, 13, 39 - pump % 2 * 25, Cell.STEEL_PIPE)
	# Individual off-centre meters, cable hooks and tiny glowing witness marks.
	_panel(a, 16, 188, 31, 10, Cell.BARE_IRON, Cell.DARK_GLASS)
	a.rect(20, 192, 14, 1, accent)
	a.rect(207, 39, 3, 145, Cell.CABLE_BUNDLE)
	for y: int in [45, 95, 148]:
		a.rect(204, y, 8, 2, finish)
	a.rect(197, 189, 13, 5, housing)


static func _far_shadow(index: int) -> int:
	if index in [10, 11, 13, 14]:
		return Cell.CHARRED_TIMBER
	if index in [1, 2, 7, 12]:
		return Cell.CARBON_FIBRE
	return Cell.HEAT_SHIELD_TILE


static func _panel(a: Canvas, x: int, y: int, width: int, height: int, rim: int, fill: int) -> void:
	a.panel(x, y, width, height, rim, fill)
	for xx: int in [x + 1, x + width - 2]:
		a.rect(xx, y + 1, 1, 1, Cell.ALUMINIUM_PANEL)
		a.rect(xx, y + height - 2, 1, 1, Cell.ALUMINIUM_PANEL)


static func _lamp(a: Canvas, x: int, y: int, width: int, material: int) -> void:
	a.rect(x - 1, y - 1, width + 2, 4, Cell.BARE_IRON)
	a.rect(x, y, width, 1, material)


static func _vent(a: Canvas, x: int, y: int, width: int, height: int, material: int) -> void:
	a.panel(x, y, width, height, material, Cell.DARK_GLASS)
	for yy: int in range(y + 4, y + height - 2, 5):
		a.rect(x + 3, yy, width - 6, 1, Cell.STEEL_PLATE)


static func _pipe(a: Canvas, start: Vector2i, end: Vector2i, width: int, material: int) -> void:
	assert(start.x == end.x or start.y == end.y)
	if start.y == end.y:
		var x: int = mini(start.x, end.x)
		var length: int = absi(start.x - end.x) + 1
		a.rect(x, start.y - width / 2, length, width, Cell.RUBBER)
		a.rect(x, start.y - width / 2 + 1, length, maxi(1, width - 2), material)
		for clamp: int in range(x + 9, x + length - 3, 43):
			a.rect(clamp, start.y - width / 2 - 1, 2, width + 2, Cell.STEEL_PLATE)
	else:
		var y: int = mini(start.y, end.y)
		var length: int = absi(start.y - end.y) + 1
		a.rect(start.x - width / 2, y, width, length, Cell.RUBBER)
		a.rect(start.x - width / 2 + 1, y, maxi(1, width - 2), length, material)
		for clamp: int in range(y + 8, y + length - 3, 37):
			a.rect(start.x - width / 2 - 1, clamp, width + 2, 2, Cell.STEEL_PLATE)


static func _valve(a: Canvas, x: int, y: int, accent: int) -> void:
	a.octagon(x, y, 22, 22, 5, Cell.BRASS_PANEL)
	a.octagon(x + 3, y + 3, 16, 16, 4, Cell.DARK_GLASS)
	a.rect(x + 9, y + 4, 3, 14, Cell.STEEL_PLATE)
	a.rect(x + 4, y + 10, 14, 2, Cell.STEEL_PLATE)
	a.rect(x + 10, y + 10, 2, 2, accent)


static func _clear(a: Canvas, box: Rect2i) -> void:
	a.rect(box.position.x, box.position.y, box.size.x, box.size.y, Cell.EMPTY)


static func _number(a: Canvas, value: int, origin: Vector2i, material: int) -> void:
	# Seven-segment stencil: a whole segment is one rectangle, not one per pixel.
	const SEGMENTS: Array[String] = ["1111110", "0110000", "1101101", "1111001", "0110011", "1011011", "1011111", "1110000", "1111111", "1111011"]
	var x: int = origin.x
	for character: String in "%02d" % value:
		var bits: String = SEGMENTS[int(character)]
		var parts: Array[Rect2i] = [Rect2i(x, origin.y, 3, 1), Rect2i(x + 2, origin.y, 1, 3),
			Rect2i(x + 2, origin.y + 3, 1, 3), Rect2i(x, origin.y + 5, 3, 1),
			Rect2i(x, origin.y + 3, 1, 3), Rect2i(x, origin.y, 1, 3), Rect2i(x, origin.y + 2, 3, 1)]
		for segment: int in range(7):
			if bits[segment] == "1":
				var part: Rect2i = parts[segment]
				a.rect(part.position.x, part.position.y, part.size.x, part.size.y, material)
		x += 5
