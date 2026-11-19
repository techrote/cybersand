extends RefCounted

# Ordinary authored starts for interactive Water comparisons. These contain
# only existing terrain stamps and real Workbench actors: no fixture runner,
# decorative Water, automatic solver selection or private simulation owner.
const Setup = preload("res://scripts/workbench_setup.gd")
const SCENES := [
	{"id":"interference","label":"Two crests · 512²","help":"Watch the raised patches spread and meet. Paint Water or erase a patch to make new disturbances."},
	{"id":"impacts","label":"Repeated impacts · 512²","help":"Four real barrels hit the pool at different times. Select a barrel and press R to drop it again into the evolving Water."},
	{"id":"sparse","label":"Sparse basins · 1024²","help":"Separated pools expose wake/sleep and sparse cost. Paint Water into one basin and inspect native solved chunks and tasks."},
	{"id":"cascade","label":"Cascades and reservoirs · 2048×1024","help":"A larger active canvas with reservoirs, spillways and real falling barrels. Pan, zoom, paint channels or switch solver, then reload for a matched start."},
]

static func description(id: String) -> Dictionary:
	for scene: Dictionary in SCENES:
		if scene.id == id: return scene
	return {}

static func create(id: String, policy: PackedInt32Array) -> Dictionary:
	if description(id).is_empty(): return {}
	var size := Vector2i(512,512)
	if id == "sparse": size = Vector2i(1024,1024)
	elif id == "cascade": size = Vector2i(2048,1024)
	var data := Setup.fresh(policy,size)
	data.material = Setup.WATER
	var e: Array = data.edits
	match id:
		"interference":
			_box(e,20,304,492,412,Setup.WATER)
			_box(e,100,280,140,304,Setup.WATER)
			_box(e,372,280,412,304,Setup.WATER)
			_basin(e,16,232,496,420,6)
		"impacts":
			_box(e,20,336,492,436,Setup.WATER)
			_basin(e,14,260,498,444,6)
			for spot: Array in [[108,288],[208,208],[308,128],[408,48]]:
				data.actors.append(Setup.instance(Setup.BARREL,data.actors.size()+1,Vector2(spot[0],spot[1])))
			data.next_id = 5
			data.selected = 1
		"sparse":
			for origin: Vector2i in [Vector2i(24,80),Vector2i(720,144),Vector2i(280,480),Vector2i(720,784)]:
				_box(e,origin.x+6,origin.y+52,origin.x+210,origin.y+110,Setup.WATER)
				_box(e,origin.x+24,origin.y+28,origin.x+56,origin.y+52,Setup.WATER)
				_basin(e,origin.x,origin.y,origin.x+216,origin.y+116,6)
		"cascade":
			# Upper reservoirs have finite Water and open spillways. Lower
			# terraces catch and redirect it before the broad shared basin.
			_box(e,24,80,372,288,Setup.WATER)
			_box(e,24,288,430,296,Setup.WALL)
			_box(e,18,24,24,296,Setup.WALL)
			_box(e,890,60,1150,244,Setup.WATER)
			_box(e,850,244,1160,252,Setup.WALL)
			_box(e,1148,32,1160,252,Setup.WALL)
			_box(e,1620,112,2024,304,Setup.WATER)
			_box(e,1608,304,2030,312,Setup.WALL)
			_box(e,2024,56,2030,312,Setup.WALL)
			_box(e,340,484,812,492,Setup.WALL)
			_box(e,720,440,732,492,Setup.WALL)
			_box(e,1120,536,1640,544,Setup.WALL)
			_box(e,1120,500,1132,544,Setup.WALL)
			_box(e,150,720,650,728,Setup.WALL)
			_box(e,1430,752,1910,760,Setup.WALL)
			_box(e,20,892,2028,998,Setup.WATER)
			_box(e,580,840,760,892,Setup.WATER)
			_box(e,1330,860,1510,892,Setup.WATER)
			_basin(e,12,780,2036,1008,8)
			for spot: Array in [[180,40],[520,240],[1000,32],[1500,320],[1830,52],[960,740]]:
				data.actors.append(Setup.instance(Setup.BARREL,data.actors.size()+1,Vector2(spot[0],spot[1])))
			data.next_id = 7
			data.selected = 1
	return data

static func _box(edits: Array, x0: int, y0: int, x1: int, y1: int, material: int) -> void:
	edits.append([x0,y0,x1-x0,y1-y0,material])

static func _basin(edits: Array, x0: int, y0: int, x1: int, y1: int, thickness: int) -> void:
	_box(edits,x0,y0,x0+thickness,y1,Setup.WALL)
	_box(edits,x1-thickness,y0,x1,y1,Setup.WALL)
	_box(edits,x0,y1-thickness,x1,y1,Setup.WALL)
