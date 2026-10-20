class_name CyberDeepworksExhibits
extends RefCounted

## Authored native apparatus for Deepworks. The scheduler supplies reactants;
## only the native kernels produce the observed conversions. Coordinates share
## the map's sixteen 256-cell districts and leave their route corridors clear.
const M = preload("res://scripts/cell_world.gd")
const DISTRICT_SIZE: int = 256
const DISTRICT_NAMES: Array[String] = [
	"Customs of Dust", "Copper Choir", "Frost Mortuary", "Halite Exchange",
	"Oxide Records", "Marble Reliquary", "Clay Ossuary", "Prism Foundry",
	"Thermite Chapel", "Lime Casting Hall", "Rainward Tenements", "Timber Crematorium",
	"Polymer Reclaimer", "Poison Garden", "Mycelium Crypt", "Abyssal Sump",
]
const SHELLS: Array[int] = [
	M.RUSTED_STEEL, M.BRASS_PANEL, M.ALUMINIUM_PANEL, M.TERRAZZO,
	M.CORRUGATED_STEEL, M.MARBLE, M.FIREBRICK, M.HEAT_SHIELD_TILE,
	M.FIREBRICK, M.REINFORCED_CONCRETE, M.CERAMIC_TILE, M.HEAT_SHIELD_TILE,
	M.STEEL_PLATE, M.CHEMICAL_GLASS, M.GABION, M.REINFORCED_CONCRETE,
]
const SIGNALS: Array[int] = [
	M.NEON_AMBER, M.NEON_CYAN, M.LED_WHITE, M.NEON_MAGENTA,
	M.NEON_AMBER, M.NEON_CYAN, M.NEON_AMBER, M.NEON_MAGENTA,
	M.NEON_AMBER, M.LED_WHITE, M.NEON_CYAN, M.NEON_AMBER,
	M.NEON_MAGENTA, M.NEON_CYAN, M.NEON_MAGENTA, M.NEON_CYAN,
]
const WEATHER: Array[int] = [
	M.DUST, M.SPARK, M.STEAM, M.WATER,
	M.WATER, M.SMOKE, M.SMOKE, M.STEAM,
	M.SPARK, M.STEAM, M.WATER, M.SMOKE,
	M.SMOKE, M.STEAM, M.STEAM, M.WATER,
]

static func build() -> Dictionary:
	var play := PackedInt32Array()
	var scripted := PackedInt32Array()
	var effects := PackedInt32Array()
	var events: Array[Dictionary] = []
	var exhibits: Array[Dictionary] = []
	for district: int in range(DISTRICT_NAMES.size()):
		var origin := Vector2i((district % 4) * DISTRICT_SIZE, (district >> 2) * DISTRICT_SIZE)
		_vessel(play, origin, Rect2i(34, 83, 90, 108), SHELLS[district], SIGNALS[district])
		_vessel(scripted, origin, Rect2i(142, 72, 76, 118), SHELLS[district], SIGNALS[district])
		# A distinct rear service plinth and paired status lamps sit below each
		# apparatus, without occupying the foreground aperture or walkway.
		_r(play, origin, 31, 191, 96, 6, M.STEEL_PLATE)
		_r(play, origin, 37, 197, 8, 5, M.STEEL_PIPE)
		_r(play, origin, 111, 197, 8, 5, M.STEEL_PIPE)
		_r(scripted, origin, 140, 188, 80, 2, M.STEEL_GRATING)
		match district:
			0: _aggregate(play, scripted, events, exhibits, origin, district)
			1: _charge(play, scripted, events, exhibits, origin, district)
			2: _snow(play, scripted, events, exhibits, origin, district)
			3: _salt(play, scripted, events, exhibits, origin, district)
			4: _corrosion(play, scripted, events, exhibits, origin, district)
			5: _effervescence(play, scripted, events, exhibits, origin, district)
			6: _kiln(play, scripted, events, exhibits, origin, district)
			7: _glass(play, scripted, events, exhibits, origin, district)
			8: _ignition(play, scripted, events, exhibits, origin, district)
			9: _casting(play, scripted, events, exhibits, origin, district)
			10: _erosion(play, scripted, events, exhibits, origin, district)
			11: _combustion(play, scripted, events, exhibits, origin, district)
			12: _reclamation(play, scripted, events, exhibits, origin, district)
			13: _purification(play, scripted, events, exhibits, origin, district)
			14: _growth(play, scripted, events, exhibits, origin, district)
			15: _sump(play, scripted, events, exhibits, origin, district)
		_atmosphere(effects, events, origin, district)
	return {"play": play, "scripted": scripted, "effects": effects, "events": events, "exhibits": exhibits}


static func _aggregate(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	# Two powder streams thread an offset rack, leaving visible grain heaps.
	for tier: int in range(4):
		_r(p, o, 40 if tier % 2 == 0 else 75, 113 + tier * 16, 38, 3, M.STEEL_PLATE)
		_r(p, o, 42 if tier % 2 == 0 else 78, 112 + tier * 16, 32, 1, M.HAZARD_STRIPE)
	_r(p, o, 76, 173, 3, 14, M.WALL)
	_feed(e, d, "play", "sand-ration", o, Rect2i(47, 96, 4, 3), M.SAND, 15, 16, 80)
	_feed(e, d, "play", "dust-ration", o, Rect2i(102, 96, 3, 2), M.DUST, 23, 23, 64)
	# Stone has its own falling/brace kernel; the neighbouring sand slips
	# around a central tooth instead of being assigned invented density swaps.
	_r(s, o, 175, 105, 4, 64, M.GABION)
	_r(s, o, 149, 141, 20, 3, M.STEEL_GRATING)
	_r(s, o, 186, 157, 23, 3, M.STEEL_GRATING)
	# Stone does not flow sideways off a shelf. Feed the open chute between
	# the left grating and the Gabion so it reaches the lower collection bay.
	_feed(e, d, "scripted", "stone-ration", o, Rect2i(170, 88, 3, 3), M.STONE, 20, 31, 40)
	_feed(e, d, "scripted", "sand-ration", o, Rect2i(195, 88, 3, 3), M.SAND, 32, 24, 50)
	_exhibit(x, d, "play", "Offset grain customs", o, "Sand and Dust fall through alternate baffles and form native granular heaps.", [], "flow")
	_exhibit(x, d, "scripted", "Rear ballast classifier", o, "Stone falls under its own kernel while the neighbouring Sand works around the rack.", [], "flow")


static func _charge(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	_r(p, o, 44, 135, 70, 49, M.WATER)
	for column: int in range(3):
		var cx: int = 52 + column * 25
		_r(p, o, cx, 122, 3, 37, M.METAL)
		_r(p, o, cx - 3, 159, 9, 3, M.CARBON_FIBRE)
		_r(p, o, cx - 2, 112, 7, 5, M.BRASS_PANEL)
	_feed(e, d, "play", "electrode-water", o, Rect2i(73, 132, 3, 4), M.WATER, 5, 47, 40)
	_feed(e, d, "play", "rail-charge", o, Rect2i(80, 135, 1, 7), M.SPARK, 12, 19, 70)
	_r(s, o, 150, 132, 59, 48, M.WATER)
	_r(s, o, 177, 108, 3, 49, M.METAL)
	_r(s, o, 162, 146, 31, 3, M.METAL)
	_r(s, o, 158, 117, 5, 8, M.SOLAR_PANEL)
	_r(s, o, 194, 117, 5, 8, M.SOLAR_PANEL)
	_feed(e, d, "scripted", "rear-electrode", o, Rect2i(180, 136, 1, 7), M.SPARK, 21, 17, 75)
	_exhibit(x, d, "play", "The charged choir", o, "Spark charges actual Metal electrodes; native charge can turn neighbouring Water into Steam. Brass is the decorative casing.", [M.STEAM], "charge")
	_exhibit(x, d, "scripted", "Remote boiler relay", o, "A separate rear Metal rail carries charge into its Water bath, with no connection to foreground cells.", [M.STEAM], "charge")


static func _snow(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	_r(p, o, 45, 130, 66, 37, M.PACKED_SNOW)
	_r(p, o, 46, 170, 64, 3, M.FROSTED_GLASS)
	_r(p, o, 39, 180, 80, 6, M.DARK_GLASS)
	_feed(e, d, "play", "thermal-lance", o, Rect2i(67, 127, 20, 3), M.FIRE, 24, 29, 30)
	_r(s, o, 151, 121, 57, 32, M.PACKED_SNOW)
	_r(s, o, 151, 174, 57, 3, M.FROSTED_GLASS)
	_feed(e, d, "scripted", "salt-thaw", o, Rect2i(174, 91, 6, 4), M.SALT, 27, 27, 48)
	_exhibit(x, d, "play", "Thermal autopsy", o, "Fire contacting Packed Snow becomes Steam while the snow becomes Water; meltwater collects under the cold slab.", [M.WATER, M.STEAM])
	_exhibit(x, d, "scripted", "Salt-thaw mortuary", o, "Salt falls onto Packed Snow and makes Brine plus Slush in the independent rear chamber.", [M.BRINE, M.SLUSH])


static func _salt(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	for index: int in range(4):
		_r(p, o, 47 + index * 17, 121 + (index % 2) * 11, 10, 42, M.ROCK_SALT_BLOCK)
	_r(p, o, 42, 175, 74, 3, M.CHEMICAL_GLASS)
	_feed(e, d, "play", "halite-rain", o, Rect2i(49, 118, 56, 1), M.WATER, 8, 34, 35)
	_r(s, o, 151, 150, 57, 30, M.BRINE)
	_r(s, o, 148, 183, 64, 2, M.TERRAZZO)
	_r(s, o, 174, 174, 12, 5, M.HEAT_SHIELD_TILE)
	# Inject below the settled Brine surface: a nozzle above its authored
	# initial surface would lose contact as the whole-cell liquid settles.
	_feed(e, d, "scripted", "evaporator-flame", o, Rect2i(158, 166, 44, 3), M.FIRE, 23, 25, 38)
	_exhibit(x, d, "play", "Halite percolator", o, "Water dissolves pink Rock Salt Block into Brine and Salt; loose Salt can dissolve again.", [M.BRINE])
	_exhibit(x, d, "scripted", "Rear salt evaporator", o, "Fire contacting Brine produces Steam and granular Salt; the tray retains the solid residue.", [M.STEAM, M.SALT])


static func _corrosion(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	_r(p, o, 78, 108, 2, 77, M.WALL)
	_r(p, o, 47, 123, 20, 40, M.BARE_IRON)
	_r(p, o, 91, 123, 20, 40, M.BARE_IRON)
	_r(p, o, 43, 114, 28, 9, M.WATER)
	_r(p, o, 87, 114, 28, 9, M.BRINE)
	_feed(e, d, "play", "freshwater-weathering", o, Rect2i(51, 110, 5, 4), M.WATER, 10, 53, 20)
	_feed(e, d, "play", "brine-weathering", o, Rect2i(97, 110, 5, 4), M.BRINE, 10, 53, 20)
	for index: int in range(4):
		_r(s, o, 151 + index * 14, 125 + (index % 2) * 8, 8, 30, M.ZINC_SHEET)
	_feed(e, d, "scripted", "zinc-etch", o, Rect2i(165, 101, 23, 2), M.ACID, 25, 41, 28)
	_exhibit(x, d, "play", "Twin weathering records", o, "Water and Brine weather Bare Iron into static Rusted Steel; the authored Brine contact threshold is higher.", [M.RUSTED_STEEL])
	_exhibit(x, d, "scripted", "Zinc archive etcher", o, "Acid can convert Zinc Sheet to Salt and Smoke; its broad corrosion can also remove a coupon. Wall lines the tank.", [M.SALT, M.SMOKE])


static func _effervescence(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	for index: int in range(5):
		_r(p, o, 44 + index * 14, 124 + absi(2 - index) * 6, 10, 30, M.MARBLE)
	_r(p, o, 45, 170, 67, 3, M.GOLD_LEAF)
	_feed(e, d, "play", "marble-etch", o, Rect2i(49, 120, 57, 1), M.ACID, 21, 47, 28)
	for index: int in range(4):
		_r(s, o, 153 + index * 14, 117, 9, 35, M.CHALK_BLOCK)
	_r(s, o, 155, 163, 49, 2, M.URANIUM_GLASS)
	_feed(e, d, "scripted", "chalk-etch", o, Rect2i(156, 109, 42, 2), M.ACID, 29, 44, 26)
	_exhibit(x, d, "play", "Effervescent reliquary", o, "Acid attacks Marble specimens, with native Foam and Salt when the pair rule wins over broad corrosion.", [M.FOAM, M.SALT])
	_exhibit(x, d, "scripted", "Chalk ossification theatre", o, "Acid on Chalk Block can release Foam and Dust. Repeated small feeds reveal the competing corrosion paths.", [M.FOAM, M.DUST])


static func _kiln(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	for index: int in range(4):
		_r(p, o, 47 + index * 17, 130, 12, 15, M.RAW_CLAY)
	_r(p, o, 43, 145, 72, 4, M.FIREBRICK)
	_r(p, o, 43, 156, 72, 4, M.HEAT_SHIELD_TILE)
	_feed(e, d, "play", "kiln-lava", o, Rect2i(48, 127, 62, 2), M.LAVA, 28, 71, 14)
	for index: int in range(3):
		_r(s, o, 153 + index * 18, 124, 13, 15, M.ADOBE_BRICK)
	_r(s, o, 150, 139, 58, 4, M.FIREBRICK)
	_r(s, o, 151, 159, 58, 3, M.HEAT_SHIELD_TILE)
	_feed(e, d, "scripted", "rear-kiln-lava", o, Rect2i(155, 121, 46, 2), M.LAVA, 33, 67, 15)
	_exhibit(x, d, "play", "Terracotta firing shelves", o, "Lava contacts Raw Clay and converts it to Terracotta Tile on refractory shelves.", [M.TERRACOTTA_TILE])
	_exhibit(x, d, "scripted", "Adobe memory kiln", o, "Lava fires Adobe Brick into Red Brick in an independently simulated rear kiln.", [M.RED_BRICK])


static func _glass(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	var glass_types: Array[int] = [M.GLASS_BLOCK, M.FROSTED_GLASS, M.URANIUM_GLASS]
	for index: int in range(3):
		_r(p, o, 47 + index * 24, 124, 15, 30, glass_types[index])
	_r(p, o, 44, 176, 69, 3, M.HEAT_SHIELD_TILE)
	_feed(e, d, "play", "glass-furnace", o, Rect2i(48, 121, 63, 2), M.LAVA, 35, 61, 18)
	_r(s, o, 151, 133, 57, 22, M.PACKED_SNOW)
	_r(s, o, 153, 171, 52, 3, M.CARBON_FIBRE)
	_feed(e, d, "scripted", "molten-quench", o, Rect2i(173, 101, 8, 4), M.MOLTEN_GLASS, 37, 39, 32)
	_exhibit(x, d, "play", "Three-glass furnace", o, "Lava melts Glass Block, Frosted Glass and Uranium Glass into actual flowing Molten Glass.", [M.MOLTEN_GLASS])
	_exhibit(x, d, "scripted", "Snow quench prism", o, "Molten Glass dropped on Packed Snow becomes Glass and emits Steam. The emerging solid is produced by native chemistry.", [M.GLASS, M.STEAM])


static func _ignition(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	_r(p, o, 48, 134, 22, 13, M.THERMITE_BRICK)
	_r(p, o, 87, 134, 22, 13, M.THERMITE_BRICK)
	_r(p, o, 48, 147, 22, 3, M.FIREBRICK)
	_r(p, o, 87, 147, 22, 3, M.FIREBRICK)
	_r(p, o, 76, 128, 6, 47, M.HEAT_SHIELD_TILE)
	_feed(e, d, "play", "thermite-pilot", o, Rect2i(51, 131, 15, 3), M.SPARK, 44, 13, 50)
	_feed(e, d, "play", "delayed-thermite-pilot", o, Rect2i(91, 131, 14, 3), M.SPARK, 144, 17, 35)
	for index: int in range(3):
		_r(s, o, 154 + index * 18, 129, 10, 18, M.MAGNESIUM_PLATE)
		_r(s, o, 154 + index * 18, 148, 10, 3, M.FIREBRICK)
	_feed(e, d, "scripted", "magnesium-pilot", o, Rect2i(157, 126, 42, 3), M.SPARK, 49, 17, 45)
	_exhibit(x, d, "play", "Twin thermite censers", o, "Two timed Spark pilots turn Thermite Brick into Lava. These are native conversions, without a pressure-blast claim.", [M.LAVA])
	_exhibit(x, d, "scripted", "Magnesium vigil", o, "Spark is consumed when it turns a Magnesium Plate cell into Fire; the isolated rear chamber retains the sequence.", [M.FIRE])


static func _casting(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	for index: int in range(4):
		_r(p, o, 47 + index * 17, 124, 11, 17, M.QUICKLIME_BLOCK)
	_r(p, o, 45, 165, 68, 3, M.FIREBRICK)
	for index: int in range(3):
		_r(p, o, 60 + index * 17, 168, 2, 17, M.WALL)
	_feed(e, d, "play", "lime-water", o, Rect2i(51, 111, 53, 2), M.WATER, 18, 41, 30)
	# Two moulds: Cement remains the native feedstock. The water-side mould
	# cures under the existing environment-dependent Cement kernel.
	_r(s, o, 179, 108, 2, 77, M.WALL)
	_r(s, o, 149, 159, 28, 24, M.CEMENT)
	_r(s, o, 183, 159, 28, 24, M.CEMENT)
	_r(s, o, 183, 151, 28, 8, M.WATER)
	_feed(e, d, "scripted", "wet-mould", o, Rect2i(191, 144, 5, 4), M.WATER, 25, 59, 18)
	_exhibit(x, d, "play", "Lime slaking cascade", o, "Water and Quicklime Block become Steam and Cement; the mobile Cement then cures in the lower mould pockets.", [M.CEMENT, M.CONCRETE, M.STEAM])
	_exhibit(x, d, "scripted", "Paired curing moulds", o, "Native Cement cures with exposed air, Water or Concrete contacts. The right mould receives Water; neither mould is scripted into Concrete.", [M.CONCRETE], "curing")


static func _erosion(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	_r(p, o, 78, 106, 2, 79, M.WALL)
	_r(p, o, 45, 127, 24, 26, M.GYPSUM_BOARD)
	_r(p, o, 90, 127, 24, 26, M.SUGAR_GLASS)
	_r(p, o, 43, 163, 28, 3, M.CERAMIC_TILE)
	_r(p, o, 88, 163, 28, 3, M.CERAMIC_TILE)
	_feed(e, d, "play", "gypsum-leak", o, Rect2i(54, 104, 4, 4), M.WATER, 16, 29, 38)
	_feed(e, d, "play", "sugar-glass-leak", o, Rect2i(99, 104, 4, 4), M.WATER, 21, 29, 38)
	_r(s, o, 151, 130, 56, 22, M.RAMMED_EARTH)
	_r(s, o, 151, 153, 18, 3, M.GABION)
	_r(s, o, 189, 153, 18, 3, M.GABION)
	_feed(e, d, "scripted", "earth-rain", o, Rect2i(157, 126, 45, 2), M.WATER, 25, 31, 42)
	_exhibit(x, d, "play", "Leaking wall samples", o, "Water softens Gypsum Board and Sugar Glass into Paste; the two samples drain into separate gutters.", [M.PASTE])
	_exhibit(x, d, "scripted", "Rear earthwash", o, "Persistent Water contacts erode Rammed Earth into Sand, which falls between the remaining gabion supports.", [M.SAND])


static func _combustion(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	var timbers: Array[int] = [M.PINE_PLANKS, M.CARDBOARD, M.BAMBOO, M.PLYWOOD]
	for index: int in range(4):
		_r(p, o, 46 + index * 18, 120, 11, 28, timbers[index])
		_r(p, o, 45 + index * 18, 149, 13, 3, M.FIREBRICK)
	_r(p, o, 44, 165, 69, 4, M.HEAT_SHIELD_TILE)
	# Lava's four-tick ignition sample gives reliable bounded ignition, unlike
	# a passing Fire cell's much slower ambient ignition sample.
	_feed(e, d, "play", "wood-lava-pilot", o, Rect2i(46, 117, 65, 2), M.LAVA, 35, 83, 12)
	for index: int in range(3):
		_r(s, o, 154 + index * 17, 131, 11, 14, M.SANDBAG)
		_r(s, o, 154 + index * 17, 148, 11, 2, M.STEEL_GRATING)
	_feed(e, d, "scripted", "sandbag-flame", o, Rect2i(156, 128, 42, 3), M.FIRE, 41, 23, 40)
	_exhibit(x, d, "play", "Four-fibre crematorium", o, "A Lava pilot ignites Pine Planks, Cardboard, Bamboo and Plywood. Their native burn state advances, emits Fire and eventually removes the material.", [M.FIRE], "combustion")
	_exhibit(x, d, "scripted", "Sandbag unseaming", o, "Fire changes Sandbag into ordinary falling Sand, exposing the empty space that the rigid bag occupied.", [M.SAND])


static func _reclamation(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	for index: int in range(4):
		_r(p, o, 47 + index * 17, 126, 11, 22, M.WAX_BLOCK)
	_r(p, o, 45, 166, 28, 3, M.HEAT_SHIELD_TILE)
	_r(p, o, 89, 166, 25, 3, M.HEAT_SHIELD_TILE)
	_feed(e, d, "play", "wax-heat", o, Rect2i(47, 123, 63, 2), M.LAVA, 32, 67, 15)
	for index: int in range(3):
		_r(s, o, 152 + index * 18, 128, 12, 22, M.POLYMER_PANEL)
	_r(s, o, 152, 167, 21, 3, M.STEEL_PLATE)
	_r(s, o, 187, 167, 21, 3, M.STEEL_PLATE)
	_feed(e, d, "scripted", "polymer-flame", o, Rect2i(155, 125, 43, 3), M.FIRE, 37, 19, 48)
	_exhibit(x, d, "play", "Wax reclaim still", o, "Lava turns Wax Block into Oil; the native Oil can flow, ignite and drain around the catch baffles.", [M.OIL])
	_exhibit(x, d, "scripted", "Polymer recovery retort", o, "Fire and Polymer Panel can become Smoke and Oil. Products remain native and may undergo later combustion.", [M.OIL, M.SMOKE])


static func _purification(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	_r(p, o, 43, 151, 73, 32, M.TOXIC_SLUDGE)
	_r(p, o, 61, 120, 3, 20, M.CERAMIC_TILE)
	_r(p, o, 96, 136, 3, 18, M.CERAMIC_TILE)
	_feed(e, d, "play", "purification-water", o, Rect2i(72, 114, 7, 4), M.WATER, 16, 23, 55)
	# A finite sodium bed reacts with incoming water rather than an authored
	# Fire/Steam cue. Isolated Wall lining prevents unrelated scene damage.
	_r(s, o, 151, 166, 57, 12, M.SODIUM)
	_r(s, o, 150, 179, 59, 4, M.CERAMIC_TILE)
	_feed(e, d, "scripted", "sodium-water", o, Rect2i(174, 127, 7, 3), M.WATER, 33, 29, 38)
	_exhibit(x, d, "play", "Poison-to-water cascade", o, "Water converts Toxic Sludge into more Water. Read the disappearing green sludge as well as the blue inflow.", [M.WATER], "purification", [M.TOXIC_SLUDGE])
	_exhibit(x, d, "scripted", "Sodium caution garden", o, "Water droplets reaching Sodium produce Steam and Fire in a separate rear vessel.", [M.STEAM, M.FIRE])


static func _growth(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	_r(p, o, 43, 172, 73, 13, M.SAND)
	_r(p, o, 45, 152, 22, 3, M.CERAMIC_TILE)
	_r(p, o, 91, 143, 24, 3, M.CERAMIC_TILE)
	_r(p, o, 46, 148, 19, 4, M.SAND)
	_r(p, o, 92, 139, 21, 4, M.SAND)
	_feed(e, d, "play", "seed-fall", o, Rect2i(74, 107, 5, 2), M.SEED, 19, 53, 16)
	_feed(e, d, "play", "high-seeds", o, Rect2i(96, 115, 3, 2), M.SEED, 31, 59, 12)
	_r(s, o, 154, 124, 13, 53, M.WOOD)
	_r(s, o, 182, 133, 18, 43, M.OAK_TIMBER)
	_r(s, o, 155, 122, 5, 2, M.FUNGUS)
	_r(s, o, 192, 130, 5, 3, M.FUNGUS)
	# New woods and Moss Wall are scenic here; only old Wood/Oak Timber are
	# deliberately used as the actual native Fungus substrate.
	_feed(e, d, "scripted", "fungal-inoculation", o, Rect2i(179, 149, 3, 4), M.FUNGUS, 45, 173, 5)
	_exhibit(x, d, "play", "Seed reliquaries", o, "Seeds fall onto Sand, germinate and create native Plant growth; no Plant cells are injected by the sequence.", [M.PLANT], "growth")
	_exhibit(x, d, "scripted", "Timber mycelium crypt", o, "Fungus expands with bounded native growth energy into old Wood and Oak Timber. Moss Wall and newer woods are decorative, not assumed substrates.", [], "growth", [M.WOOD, M.OAK_TIMBER])


static func _sump(p: PackedInt32Array, s: PackedInt32Array, e: Array[Dictionary],
		x: Array[Dictionary], o: Vector2i, d: int) -> void:
	_r(p, o, 43, 139, 72, 44, M.WATER)
	_r(p, o, 43, 126, 72, 12, M.OIL)
	_r(p, o, 56, 154, 45, 2, M.STEEL_GRATING)
	_feed(e, d, "play", "heavy-droplets", o, Rect2i(70, 105, 6, 3), M.MERCURY, 35, 61, 18)
	_feed(e, d, "play", "oil-droplets", o, Rect2i(102, 109, 4, 3), M.OIL, 48, 73, 15)
	_r(s, o, 151, 163, 57, 20, M.LAVA)
	_r(s, o, 158, 145, 20, 3, M.FIREBRICK)
	_r(s, o, 187, 129, 20, 3, M.FIREBRICK)
	_feed(e, d, "scripted", "geothermal-rain", o, Rect2i(174, 99, 6, 3), M.WATER, 29, 31, 42)
	_exhibit(x, d, "play", "Density well", o, "Mercury drops through lighter liquids while Oil and Water retain their distinct native transport rules. The baffle interrupts the descent.", [], "flow")
	_exhibit(x, d, "scripted", "Geothermal drain", o, "Water falling into Lava produces Stone and Steam in the rear sump. This shows contact quenching, not a pressure solver.", [M.STONE, M.STEAM])


static func _atmosphere(data: PackedInt32Array, e: Array[Dictionary], o: Vector2i, d: int) -> void:
	var material: int = WEATHER[d]
	var rising: bool = material == M.SMOKE or material == M.STEAM or material == M.SPARK
	var emission := Rect2i(235 + (d % 3) * 3, 162 if rising else 88, 2, 3)
	_r(data, o, emission.position.x, emission.position.y, emission.size.x, emission.size.y, material)
	_feed(e, d, "effects", "local-atmosphere", o, emission, material, 9 + d * 3, 39 + (d % 4) * 7, 0)
	# The right corridor gives this effects-only service riser an unobstructed
	# view. Its containment and cleanup never write into foreground authority.
	_r(data, o, 231, 76, 1, 116, M.WALL)
	_r(data, o, 247, 76, 1, 116, M.WALL)
	_r(data, o, 231, 76, 17, 1, M.WALL)
	_r(data, o, 231, 191, 17, 1, M.WALL)
	_feed(e, d, "effects", "riser-sink", o, Rect2i(232, 77 if rising else 185, 15, 6), M.EMPTY, 19 + d, 17, 0)
	if material == M.STEAM:
		_feed(e, d, "effects", "condensate-drain", o, Rect2i(232, 185, 15, 6), M.EMPTY, 31 + d, 23, 0)


static func _vessel(data: PackedInt32Array, o: Vector2i, bounds: Rect2i, shell: int, light_material: int) -> void:
	var x: int = bounds.position.x
	var y: int = bounds.position.y
	var w: int = bounds.size.x
	var h: int = bounds.size.y
	_r(data, o, x, y, w, h, shell)
	_r(data, o, x + 3, y + 5, w - 6, h - 9, M.EMPTY)
	# Wall, not the pretty shell, is the native acid/heat containment surface.
	_r(data, o, x + 2, y + 4, w - 4, 1, M.WALL)
	_r(data, o, x + 2, y + h - 4, w - 4, 1, M.WALL)
	_r(data, o, x + 2, y + 5, 1, h - 9, M.WALL)
	_r(data, o, x + w - 3, y + 5, 1, h - 9, M.WALL)
	_r(data, o, x + 4, y + 1, w - 8, 1, light_material)
	_r(data, o, x + 5, y + h - 2, 12, 1, M.HAZARD_STRIPE)
	_r(data, o, x + w - 18, y + h - 2, 12, 1, M.HAZARD_STRIPE)
	# A short feeder, collar and instrument bezel give the mechanism scale.
	var centre: int = x + (w >> 1)
	_r(data, o, centre - 2, y - 10, 4, 14, M.STEEL_PIPE)
	_r(data, o, centre - 5, y - 5, 10, 3, M.PAINTED_STEEL)
	_r(data, o, x + 7, y + 7, 12, 5, M.CARBON_FIBRE)
	_r(data, o, x + 9, y + 8, 3, 2, light_material)
	_r(data, o, x + 14, y + 8, 2, 2, M.LED_WHITE)
	for offset: int in [14, 41, 68, 95]:
		if offset < h - 5:
			_r(data, o, x, y + offset, 2, 2, M.BARE_IRON)
			_r(data, o, x + w - 2, y + offset, 2, 2, M.BARE_IRON)


static func _r(data: PackedInt32Array, o: Vector2i, x: int, y: int, w: int, h: int, material: int) -> void:
	data.append_array(PackedInt32Array([o.x + x, o.y + y, w, h, material]))


static func _feed(events: Array[Dictionary], district: int, layer: String, name: String,
		o: Vector2i, rect: Rect2i, material: int, first_tick: int, period: int, repeat: int) -> void:
	events.append({
		"id": "deepworks-%02d-%s-%s" % [district, layer, name],
		"district": district,
		"layer": layer,
		"rect": Rect2i(o + rect.position, rect.size),
		"material": material,
		"first_tick": first_tick,
		"period": period,
		"repeat": repeat,
	})


static func _exhibit(exhibits: Array[Dictionary], district: int, layer: String, title: String,
		o: Vector2i, description: String, products: Array, mechanism: String = "reaction", consumed: Array = []) -> void:
	var rect := Rect2i(38, 97, 82, 89) if layer == "play" else Rect2i(146, 86, 68, 100)
	var expected: Array[int] = []
	for product: int in products:
		expected.append(product)
	var consumed_ids: Array[int] = []
	for material: int in consumed:
		consumed_ids.append(material)
	exhibits.append({
		"id": "deepworks-%02d-%s" % [district, layer],
		"title": title,
		"district": district,
		"district_title": DISTRICT_NAMES[district],
		"layer": layer,
		"focus": o + rect.position + Vector2i(rect.size.x >> 1, rect.size.y >> 1),
		"description": description,
		"expected_products": expected,
		"consumed_materials": consumed_ids,
		"observation": Rect2i(o + rect.position, rect.size),
		"mechanism": mechanism,
	})
