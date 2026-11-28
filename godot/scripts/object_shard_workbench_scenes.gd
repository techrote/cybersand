extends RefCounted

# Ordinary authored Workbench starts. Every visible structure consists of native
# material cells; the controller never animates or pre-spawns a shard body.
const Setup = preload("res://scripts/workbench_setup.gd")
const IDS := ["tower", "viaduct", "timber", "mixed", "stress", "perforated", "weathered", "editing_yard", "owner_tower"]
const LABELS := ["Multi-storey tower", "Three-span viaduct", "Burning timber workshop", "Wood, brick and liquids", "Eight-body collapse", "Perforated brick wall", "Weathered timber shed", "Structural editing yard", "Owner's eroded tower start"]
const OWNER_TOWER_PATH := "res://data/objectshard_owner_tower2_authored_start.json"
const WALL: int = 1
const WOOD: int = 7
const BRICK: int = 43

static func manifest(id: String) -> Dictionary:
	var cuts: Array[Rect2i] = []
	var supports: Array[Rect2i] = []
	match id:
		"tower", "timber", "mixed":
			for x: int in [138,194]:
				supports.append(Rect2i(x,364,4,100))
				cuts.append(Rect2i(x-1,366,6,98))
		"viaduct":
			for x: int in [100,212,324]:
				supports.append(Rect2i(x,336,4,128))
				cuts.append(Rect2i(x-1,338,6,126))
		"stress":
			for x: int in range(61,454,56):
				supports.append(Rect2i(x,372,2,92))
				cuts.append(Rect2i(x-1,374,4,90))
		"perforated", "weathered":
			for x: int in [142,210]:
				supports.append(Rect2i(x,364,4,100))
				cuts.append(Rect2i(x-1,366,6,98))
		"editing_yard":
			for x: int in [142,210]:
				supports.append(Rect2i(x,344,4,120))
				cuts.append(Rect2i(x-1,346,6,118))
		"owner_tower":
			# The owner saved an authored-start sequence, including prior brush
			# marks. It contains no rigid-body checkpoint or replayed live poses.
			return {"id":id,"extent":Vector2i(512,512),"cut_rects":cuts,"support_rects":supports,
				"expected_min_bodies":0,"authored_start_only":true,
				"instructions":"The owner's saved construction and brush marks. Play discovers current disconnected material afresh; detached poses and sleeping state were not saved."}
		_: return {}
	return {"id":id, "extent":Vector2i(512,512), "cut_rects":cuts,"support_rects":supports,
		"expected_min_bodies":8 if id == "stress" else 3 if id == "viaduct" else 1,
		"instructions":"Erase the lower support stems for a full drop. Keep erasing as material falls and settles. Slice a beam, drill a hole, weather an edge or ignite Wood. Pause for deliberate cuts. Save start reopens the authored arrangement, not live body poses."}

static func create(id: String, policy: PackedInt32Array) -> Dictionary:
	if id not in IDS: return {}
	if id == "owner_tower":
		var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string(OWNER_TOWER_PATH))
		if not authored is Dictionary or not Setup.validate(authored).is_empty(): return {}
		return authored.duplicate(true)
	var data: Dictionary = Setup.fresh(policy, Vector2i(512,512))
	var e: Array = data.edits
	_box(e, 0, 464, 512, 48, WALL)
	_box(e, 0, 0, 3, 512, WALL)
	_box(e, 509, 0, 3, 512, WALL)
	data.actors = [Setup.instance(Setup.BARREL, 1, Vector2(408,432))]
	data.next_id = 2
	data.selected = 1
	data.material = WOOD
	data.brush = 2
	match id:
		"tower", "timber", "mixed":
			# 96×120 connected facade. Windows are actual Empty, floors and
			# bracing are connected cell material inside the bounded capture.
			var beam: int = BRICK if id in ["tower","mixed"] else WOOD
			_box(e,120,244,96,8,beam)
			_box(e,120,252,8,112,WOOD)
			_box(e,208,252,8,112,WOOD)
			for y: int in [276,308,340,360]: _box(e,120,y,96,4,beam)
			_box(e,164,252,6,108,WOOD)
			if id == "mixed":
				# Both carriers are directly below the facade's real fall path.
				# A flame touches a wooden pillar before and during release;
				# native chemistry, gravity and displaced water decide its fate.
				# Fill eight extra columns, then restore the eight support
				# columns below. Depths and exact total Water/Sand populations
				# remain 2992/1632 while real foundations stay connected.
				_box(e,108,452,144,12,Setup.SAND)
				_box(e,108,430,144,22,Setup.WATER)
				_box(e,104,430,4,34,WALL)
				_box(e,252,430,4,34,WALL)
				_box(e,128,316,4,20,Setup.FIRE)
			else:
				# The fixed raised footing gives a falling coherent facade a
				# physical asymmetric contact that can turn it into a topple.
				_box(e,200,454,44,10,WALL)
			if id == "timber":
				_box(e,136,312,24,24,WOOD)
				_box(e,180,280,20,24,WOOD)
			# Fluids occupy the free space around the foundations, never
			# overwrite their bottom cells before the owner cuts them.
			for x: int in [138,194]: _box(e,x,364,4,100,WALL)
		"viaduct":
			for x: int in [54,166,278]:
				_box(e,x,300,96,6,BRICK)
				for s: int in range(6):
					_box(e,x+s*8,306+s*4,8,8,WOOD)
					_box(e,x+88-s*8,306+s*4,8,8,WOOD)
				_box(e,x+40,326,16,10,WOOD)
			# Twelve extra fill columns compensate the three four-cell
			# foundations, retaining the original 5120 Water carriers.
			_box(e,54,448,332,16,Setup.WATER)
			for x: int in [54,166,278]: _box(e,x+46,336,4,128,WALL)
		"stress":
			for i: int in range(8):
				var x: int = 40+i*56
				_box(e,x,300,44,4,BRICK if i%2==0 else WOOD)
				_box(e,x,304,4,68,WOOD)
				_box(e,x+40,304,4,68,WOOD)
				_box(e,x,332,44,4,WOOD)
				_box(e,x,364,44,8,WOOD)
				_box(e,x+21,372,2,92,WALL)
		"perforated":
			# A single connected load-bearing wall with real circular openings.
			# The small lower holes also give drilling a visible starting route.
			_box(e,128,268,96,96,BRICK)
			for y: int in [288,316,344]:
				for x: int in [148,176,204]: _hole(e,Vector2i(x,y),7)
			_box(e,128,360,96,4,WOOD)
			for x: int in [142,210]: _box(e,x,364,4,100,WALL)
		"weathered":
			# A connected, hollow timber shed. Its pitting is ordinary authored
			# Empty material, so every opening affects later physical geometry.
			_box(e,128,268,96,8,WOOD)
			_box(e,128,276,8,88,WOOD)
			_box(e,216,276,8,88,WOOD)
			_box(e,172,276,8,88,WOOD)
			for y: int in [300,328,356]: _box(e,128,y,96,8,WOOD)
			for y: int in [282,310,338]:
				for x: int in [129,173,217]: _hole(e,Vector2i(x+2,y),1)
			for x: int in [146,161,190,205]: _hole(e,Vector2i(x,302),1)
			for x: int in [142,210]: _box(e,x,364,4,100,WALL)
		"editing_yard":
			# A supported movable panel beside a rooted ordinary wall. Cutting
			# only the panel's feet produces both ownership domains together.
			_box(e,128,276,96,68,WOOD)
			_hole(e,Vector2i(152,300),8)
			_hole(e,Vector2i(200,300),8)
			for x: int in [142,210]: _box(e,x,344,4,120,WALL)
			_box(e,256,332,56,8,BRICK)
			_box(e,256,340,8,124,WOOD)
			_box(e,304,340,8,124,WOOD)
			_box(e,256,420,56,8,BRICK)
	return data

static func _box(edits: Array, x: int, y: int, w: int, h: int, material: int) -> void:
	edits.append([x,y,w,h,material])

static func _hole(edits: Array, center: Vector2i, radius: int) -> void:
	for dy: int in range(-radius,radius+1):
		var dx: int = floori(sqrt(float(radius*radius-dy*dy)))
		_box(edits,center.x-dx,center.y+dy,dx*2+1,1,0)
