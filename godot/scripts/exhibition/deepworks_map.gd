class_name CyberDeepworksMap
extends RefCounted

const Architecture = preload("res://scripts/exhibition/deepworks_architecture.gd")
const Exhibits = preload("res://scripts/exhibition/deepworks_exhibits.gd")
const Cell = preload("res://scripts/cell_world.gd")
const SIZE := Vector2i(1024, 1024)
const DISTRICT_SIZE: int = 256
const TITLE: String = "DEEPWORKS"
const SUBTITLE: String = "The exhibition below"
const VERSION: int = 1
const LAYERS: Array[String] = ["play", "scripted", "effects", "background"]
const TITLES: Array[String] = [
	"Customs of Dust", "Copper Choir", "Frost Mortuary", "Halite Exchange",
	"Oxide Records", "Marble Reliquary", "Clay Ossuary", "Prism Foundry",
	"Thermite Chapel", "Lime Casting Hall", "Rainward Tenements", "Timber Crematorium",
	"Polymer Reclaimer", "Poison Garden", "Mycelium Crypt", "Abyssal Sump",
]
const SHORT_TITLES: Array[String] = [
	"CUSTOMS", "COPPER CHOIR", "FROST", "HALITE",
	"OXIDE", "RELIQUARY", "CLAY OSSUARY", "PRISM",
	"THERMITE", "LIME CASTING", "RAINWARD", "TIMBER",
	"POLYMER", "POISON GARDEN", "MYCELIUM", "ABYSSAL SUMP",
]
const DESCRIPTIONS: Array[String] = [
	"A border checkpoint that weighs the dust arriving from the surface. Baffled hoppers, battered cargo and a remote sorting line.",
	"A municipal switching hall kept alive by a choir of tired relays. Charge travels through the exposed Metal rails.",
	"Cold records and numbered specimen drawers. Salt thawing and hot snow sit beneath the frozen observation windows.",
	"An exchange for pale mineral ingots. Water dissolves the halite into brine below a forest of brass pipes.",
	"A records office that files its own corrosion. Wet iron ages beside a separate rear etching line.",
	"A gilded industrial shrine with sacrificial stone tablets. Reagents eat into marble and chalk behind the viewing gallery.",
	"Kilns occupy the old municipal ossuary. Raw clay and adobe are fired among heat shields, brick teeth and loading shelves.",
	"An optical foundry with stained windows, molten glass and a cooling line. Watch the rear pour through the foreground opening.",
	"A heavily buttressed heat chapel. Small sparks start thermite and magnesium specimens over contained collection trays.",
	"White mineral feeds descend into casting pockets. Quicklime and water produce steam and cement beneath a long gantry.",
	"Leaking homes built over a forgotten test floor. Water erodes soft panels while domestic clutter survives in dry niches.",
	"A timber exchange repurposed as a burn gallery. Small wood samples face controlled heat beside the charred service hall.",
	"Wax and plastic are reclaimed in a low furnace room. Hot coupons yield oil beneath insulated black tilework.",
	"A green reclamation ward below the factories. The purification channel shares a view with an isolated rear treatment line.",
	"An old service crypt reclaimed by living material. Seeds root in sand and fungus meets its actual timber substrate.",
	"The final pump hall. Layered fluids and independent rear drainage collect beneath drowned consoles and immense pipe silhouettes.",
]
const TOUR: Array[int] = [0, 1, 2, 3, 7, 6, 5, 4, 8, 9, 10, 11, 15, 14, 13, 12]

static func origin(index: int) -> Vector2i:
	return Vector2i(index % 4, index / 4) * DISTRICT_SIZE

static func district_code(index: int) -> String:
	return "%s%d" % ["ABCD"[index / 4], index % 4 + 1]

static func district_at(cell: Vector2i) -> int:
	if not Rect2i(Vector2i.ZERO, SIZE).has_point(cell):
		return -1
	return cell.x / DISTRICT_SIZE + (cell.y / DISTRICT_SIZE) * 4

static func build() -> Dictionary:
	var architecture: Dictionary = Architecture.build()
	var apparatus: Dictionary = Exhibits.build()
	var layers: Dictionary = {}
	for id: String in LAYERS:
		var rectangles: PackedInt32Array = architecture[id].duplicate()
		if apparatus.has(id):
			rectangles.append_array(apparatus[id])
		layers[id] = rectangles
	# Carve circulation LAST so every seam is an actual connected native opening.
	# Exhibition apparatus is authored outside these reserved passages.
	var play: PackedInt32Array = layers["play"]
	for row: int in range(4):
		play.append_array(PackedInt32Array([1, row * 256 + 211, 1022, 29, Cell.EMPTY]))
	for column: int in range(4):
		play.append_array(PackedInt32Array([column * 256 + 228, 1, 24, 1022, Cell.EMPTY]))
	layers["play"] = play
	return {"layers": layers, "events": apparatus["events"], "exhibits": apparatus["exhibits"]}

static func passages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: int in range(4):
		for column: int in range(3):
			result.append({"a": row * 4 + column, "b": row * 4 + column + 1,
				"rect": Rect2i((column + 1) * 256 - 12, row * 256 + 211, 24, 29)})
	for row: int in range(3):
		for column: int in range(4):
			result.append({"a": row * 4 + column, "b": (row + 1) * 4 + column,
				"rect": Rect2i(column * 256 + 228, (row + 1) * 256 - 12, 24, 24)})
	return result

static func recipe_hash(definition: Dictionary) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(("deepworks-v%d-1024x1024\n" % VERSION).to_utf8_buffer())
	for id: String in LAYERS:
		hashing.update(id.to_utf8_buffer())
		hashing.update((definition["layers"][id] as PackedInt32Array).to_byte_array())
	# Explicit wire representation avoids Variant/Rect2i pretty-print dependence.
	for event: Dictionary in definition["events"]:
		var rect: Rect2i = event["rect"]
		var wire: Array = [event["id"], event["district"], event["layer"], rect.position.x,
			rect.position.y, rect.size.x, rect.size.y, event["material"],
			event["first_tick"], event["period"], event["repeat"]]
		hashing.update(JSON.stringify(wire).to_utf8_buffer())
	return hashing.finish().hex_encode()
