class_name CyberGreyArea51Layout
extends RefCounted

# Camera tiles share one native slab. All points below are passage centres in
# tile-local cells, including the four shared ports authored by the composer.
const ORIGIN := Vector2i(32, 32)
const SIDE: int = 192
const EXTENT := Vector2i(960, 192)
const CLEARANCE: int = 24
const HALF: int = 12
const CODES: Array[String] = ["01", "02", "03", "04", "05"]
const IDS: Array[String] = ["intake-bastion", "records-mortuary", "null-containment", "isotope-engine", "disposal-lock"]
const TITLES: Array[String] = ["Intake Bastion", "Records Mortuary", "Null Containment", "Isotope Engine", "Disposal Lock"]
const DESCRIPTIONS: Array[String] = [
	"A concrete inspection bastion, guard slits and a dead communications plinth above the intake tunnel.",
	"Sealed record cassettes and a handling cradle beside the security riser to containment.",
	"A suspended null specimen inside a circular shielding vault, observed from the narrow dogleg around it.",
	"A buried isotope engine with pressure manifolds, isolation drums and a maintenance riser.",
	"A disposal press and sealed terminal lock at the end of the low transfer corridor.",
]
const EDGES: Array[Dictionary] = [
	{"a":0, "b":1, "axis":"x", "offset":144, "name":"Intake transfer"},
	{"a":1, "b":2, "axis":"x", "offset":64, "name":"Records security throat"},
	{"a":2, "b":3, "axis":"x", "offset":144, "name":"Containment service return"},
	{"a":3, "b":4, "axis":"x", "offset":64, "name":"Engine isolation lock"},
]

static func tile_origin(index: int) -> Vector2i:
	return ORIGIN + Vector2i(index * SIDE, 0)

static func tile_at(point: Vector2) -> int:
	var local: Vector2 = point - Vector2(ORIGIN)
	if local.x < 0 or local.y < 0 or local.x >= EXTENT.x or local.y >= EXTENT.y: return -1
	return int(local.x) / SIDE

static func spawn() -> Vector2:
	return Vector2(ORIGIN + Vector2i(24, 144) - Vector2i(4, 7))

static func paths(index: int) -> Array:
	match index:
		0: return [[Vector2i(24,144), Vector2i(192,144)], [Vector2i(52,104), Vector2i(52,144)]]
		1: return [[Vector2i(0,144), Vector2i(120,144), Vector2i(120,64), Vector2i(192,64)]]
		2: return [[Vector2i(0,64), Vector2i(72,64), Vector2i(72,144), Vector2i(192,144)]]
		3: return [[Vector2i(0,144), Vector2i(120,144), Vector2i(120,64), Vector2i(192,64)]]
		4: return [[Vector2i(0,64), Vector2i(56,64), Vector2i(56,144), Vector2i(160,144)]]
	return []

static func edge_points(edge: Dictionary) -> Array[Vector2i]:
	var centre: Vector2i = tile_origin(int(edge.b)) + Vector2i(0, int(edge.offset))
	return [centre - Vector2i(20,0), centre + Vector2i(20,0)]

static func tour() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index: int in range(5):
		for point: Vector2i in paths(index)[0]:
			var global_point: Vector2i = tile_origin(index) + point
			if result.is_empty() or result[-1] != global_point: result.append(global_point)
	return result
