class_name CyberBlacksiteNineLayout
extends RefCounted

const ORIGIN := Vector2i(32, 32)
const TILE_SIZE: int = 320
const EXTENT := Vector2i(960, 960)
const CLEAR_HALF: int = 14
const IDS: Array[String] = ["slag_approach", "aster_research", "ashworks_breach",
	"intake_warrens", "containment_choir", "condensate_works",
	"furnace_ossuary", "synapse_vault", "blackwater_terminus"]
const TITLES: Array[String] = ["Slag Approach", "Aster Research", "Ashworks Breach",
	"The Intake Warrens", "Containment Choir", "Condensate Works",
	"Furnace Ossuary", "The Synapse Vault", "Blackwater Terminus"]
const CODES: Array[String] = ["A1", "A2", "A3", "B1", "B2", "B3", "C1", "C2", "C3"]
# Every orthogonal neighbour pair has exactly one owned, reciprocal opening.
# offset is the local centreline y (east/west) or x (north/south).
const EDGES: Array[Dictionary] = [
	{"a":0, "b":1, "axis":"x", "offset":262, "name":"Laboratory intake road"},
	{"a":1, "b":2, "axis":"x", "offset":262, "name":"Decontamination exit"},
	{"a":3, "b":4, "axis":"x", "offset":92, "name":"Worker inspection gallery"},
	{"a":4, "b":5, "axis":"x", "offset":224, "name":"Condensate service artery"},
	{"a":6, "b":7, "axis":"x", "offset":228, "name":"Furnace transfer tunnel"},
	{"a":7, "b":8, "axis":"x", "offset":100, "name":"Sump control gallery"},
	{"a":0, "b":3, "axis":"y", "offset":96, "name":"Western maintenance well"},
	{"a":1, "b":4, "axis":"y", "offset":224, "name":"Laboratory containment throat"},
	{"a":2, "b":5, "axis":"y", "offset":144, "name":"Eastern service descent"},
	{"a":3, "b":6, "axis":"y", "offset":248, "name":"Ossuary freight shaft"},
	{"a":4, "b":7, "axis":"y", "offset":96, "name":"Synapse utility throat"},
	{"a":5, "b":8, "axis":"y", "offset":224, "name":"Blackwater return well"},
]
const TOUR: Array[int] = [0, 1, 4, 3, 6, 7, 8, 5, 2]

static func tile_origin(index: int) -> Vector2i:
	return ORIGIN + Vector2i(index % 3, index / 3) * TILE_SIZE

static func tile_rect(index: int) -> Rect2i:
	return Rect2i(tile_origin(index), Vector2i(TILE_SIZE, TILE_SIZE))

static func tile_at(point: Vector2) -> int:
	var relative: Vector2i = Vector2i(point.floor()) - ORIGIN
	if relative.x < 0 or relative.y < 0 or relative.x >= EXTENT.x or relative.y >= EXTENT.y:
		return -1
	return (relative.y / TILE_SIZE) * 3 + relative.x / TILE_SIZE

static func spawn() -> Vector2:
	return Vector2(76, 294)

static func paths(index: int) -> Array:
	# Orthogonal centre lines. The last construction pass clears a 28-cell body
	# corridor around each. Authors keep hero machinery outside this reservation.
	match index:
		0: return [
			[Vector2i(48,262),Vector2i(320,262)],
			[Vector2i(144,262),Vector2i(144,302),Vector2i(96,302),Vector2i(96,320)]]
		1: return [
			[Vector2i(0,262),Vector2i(58,262),Vector2i(58,204),Vector2i(122,204),Vector2i(122,238),Vector2i(250,238),Vector2i(250,262),Vector2i(320,262)],
			[Vector2i(224,238),Vector2i(224,320)]]
		2: return [
			[Vector2i(0,262),Vector2i(66,262),Vector2i(66,238),Vector2i(172,238),Vector2i(172,274),Vector2i(288,274)],
			[Vector2i(172,274),Vector2i(144,274),Vector2i(144,320)]]
		3: return [
			[Vector2i(96,0),Vector2i(96,48),Vector2i(46,48),Vector2i(46,152),Vector2i(120,152),Vector2i(120,92),Vector2i(320,92)],
			[Vector2i(120,152),Vector2i(120,212),Vector2i(248,212),Vector2i(248,320)]]
		4: return [
			[Vector2i(0,92),Vector2i(76,92),Vector2i(76,164),Vector2i(176,164),Vector2i(176,224),Vector2i(320,224)],
			[Vector2i(224,0),Vector2i(224,44),Vector2i(176,44),Vector2i(176,164)],
			[Vector2i(96,320),Vector2i(96,276),Vector2i(176,276),Vector2i(176,224)]]
		5: return [
			[Vector2i(144,0),Vector2i(144,54),Vector2i(246,54),Vector2i(246,138),Vector2i(190,138),Vector2i(190,224),Vector2i(0,224)],
			[Vector2i(224,320),Vector2i(224,276),Vector2i(190,276),Vector2i(190,224)]]
		6: return [
			[Vector2i(248,0),Vector2i(248,58),Vector2i(196,58),Vector2i(196,132),Vector2i(92,132),Vector2i(92,228),Vector2i(320,228)],
			[Vector2i(92,228),Vector2i(46,228),Vector2i(46,280)]]
		7: return [
			[Vector2i(0,228),Vector2i(76,228),Vector2i(76,172),Vector2i(208,172),Vector2i(208,100),Vector2i(320,100)],
			[Vector2i(96,0),Vector2i(96,52),Vector2i(148,52),Vector2i(148,172)]]
		8: return [
			[Vector2i(0,100),Vector2i(72,100),Vector2i(72,168),Vector2i(156,168),Vector2i(156,250),Vector2i(268,250)],
			[Vector2i(224,0),Vector2i(224,50),Vector2i(268,50),Vector2i(268,250)]]
	return []

static func edge_points(edge: Dictionary) -> Array[Vector2i]:
	var origin: Vector2i = tile_origin(int(edge.a))
	var seam: Vector2i = (origin + Vector2i(TILE_SIZE, int(edge.offset))
		if edge.axis == "x" else origin + Vector2i(int(edge.offset), TILE_SIZE))
	var direction := Vector2i.RIGHT if edge.axis == "x" else Vector2i.DOWN
	return [seam - direction * 20, seam + direction * 20]
