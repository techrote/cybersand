class_name CyberGreyArea51
extends RefCounted

# One predominantly solid native concrete slab, authored as five camera tiles.
# Shared services and the final circulation carve own both sides of every seam.
const ID: String = "grey_area_51"
const SCENARIO_ID: String = "showcase/grey-area-51"
const TITLE: String = "Grey Area 51"
const VERSION: int = 1
const Layout = preload("res://scripts/grey_area_51_layout.gd")
const Art = preload("res://scripts/grey_area_51_art.gd")
const M = preload("res://scripts/neon_reliquary.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const West = preload("res://scripts/grey_area_51_west.gd")
const East = preload("res://scripts/grey_area_51_east.gd")

static func spawn() -> Vector2:
	return Layout.spawn()

static func viewpoints() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"name":"The complete bunker", "origin":Vector2(Layout.ORIGIN), "size":Layout.EXTENT}]
	for index: int in range(5):
		result.append({"name":Layout.CODES[index] + " / " + Layout.TITLES[index],
			"origin":Vector2(Layout.tile_origin(index)), "size":Vector2i(Layout.SIDE, Layout.SIDE)})
	return result

static func definition(seed: int = 0) -> Dictionary:
	var out: Dictionary = Contract.base(SCENARIO_ID, VERSION, seed)
	out.schema_version = 2
	out.rectangles = Array(rectangles())
	out.player_start = [int(spawn().x), int(spawn().y)]
	out.camera_origin = [32, 32]
	out.player_enabled = true
	out.body_enabled = false
	out.tools = ["paint", "erase", "player"]
	out.interest = {"policy":"fixed", "region":[32,32,960,192]}
	var regions: Array = []
	for index: int in range(5):
		var origin: Vector2i = Layout.tile_origin(index)
		regions.append({"id":Layout.IDS[index], "label":Layout.CODES[index] + " / " + Layout.TITLES[index],
			"region":[origin.x,origin.y,192,192]})
	out["presentation"] = {"title":TITLE,
		"instructions":"Five connected tiles cut into one massive concrete bunker. "
			+ "Follow the low intake tunnel through Records Mortuary, rise into the security throat, "
			+ "pass around Null Containment, then climb through the isotope works to the disposal lock. "
			+ "A/D move; hold Space to rise, release to descend. P animates, F follows, "
			+ "arrows pan and F8 gives a clean view. Tile views preserve the world and your edits. "
			+ "R restores the whole five-tile slab. Starts paused.",
		"duration_ticks":600,
		"baseline":"Current native materials / Baseline transport / Water8-coherence12",
		"profile":"Grey Area 51 / connected concrete 5×1 composition v1", "regions":regions}
	out.source_recipe = "CyberGreyArea51/v1"
	out.source_recipe_hash = JSON.stringify(out.rectangles).sha256_text()
	return out

static func rectangles() -> PackedInt32Array:
	var out := PackedInt32Array()
	_rect(out,0,0,1024,1,M.WALL)
	_rect(out,0,1,1,1023,M.WALL)
	_rect(out,1023,1,1,1023,M.WALL)
	_rect(out,1,1023,1022,1,M.WALL)
	_rect(out,32,32,960,192,M.CONCRETE)
	for index: int in range(5):
		var origin: Vector2i = Layout.tile_origin(index)
		var local: PackedInt32Array = West.tile(index) if index < 2 else (East.tile(index) if index > 2 else _containment())
		for offset: int in range(0,local.size(),5):
			_rect(out,origin.x+local[offset],origin.y+local[offset+1],local[offset+2],local[offset+3],local[offset+4])
	# Unbroken roof, foundation and recessed service trunk; there are no borders
	# between camera tiles. Formwork and material noise use absolute world cells.
	_rect(out,32,32,960,1,M.SLATE)
	_rect(out,32,33,960,1,M.CONCRETE)
	_rect(out,32,223,960,1,M.SLATE)
	_rect(out,32,221,960,2,M.CONCRETE)
	_rect(out,32,54,960,4,M.CONCRETE)
	_rect(out,32,55,960,1,M.STEEL_PIPE)
	_rect(out,32,57,960,1,M.LEAD)
	for x: int in range(46,982,32):
		_rect(out,x,53,2,8,M.IRON)
		_rect(out,x,54,2,1,M.STEEL)
	for index: int in range(5): _route_frames(out,index)
	for edge: Dictionary in Layout.EDGES:
		var port: Vector2i = Layout.tile_origin(int(edge.b)) + Vector2i(0,int(edge.offset))
		_rect(out,port.x-9,port.y-19,18,7,M.LEAD)
		_rect(out,port.x-6,port.y-16,12,4,M.STEEL)
		_rect(out,port.x-9,port.y+12,18,7,M.LEAD)
		_rect(out,port.x-6,port.y+12,12,1,M.STEEL)
		_rect(out,port.x-2,port.y-19,4,2,M.WHITE)
	# The final carve is authoritative: embedded instruments and portal framing
	# can never occlude the complete 24-cell circulation volume.
	for index: int in range(5):
		for path: Array in Layout.paths(index):
			for segment: int in range(path.size()-1):
				var a: Vector2i = path[segment]
				var b: Vector2i = path[segment+1]
				_local(out,index,Rect2i(mini(a.x,b.x)-12,mini(a.y,b.y)-12,absi(a.x-b.x)+24,absi(a.y-b.y)+24),M.EMPTY)
	return out

static func _containment() -> PackedInt32Array:
	var a = Art.new()
	# Dense shielding rings occupy real solid cells. Only the narrow dogleg and
	# a handful of instrument recesses are air; the specimen is sealed in glass.
	a.panel(93,48,78,83,M.CONCRETE,M.LEAD,1)
	a.rect(95,49,74,1,M.STEEL)
	a.ellipse(132,91,35,36,M.IRON,2)
	a.ellipse(132,91,34,35,M.CONCRETE,2)
	a.ellipse(132,91,25,27,M.CONCRETE,2)
	a.ellipse(132,91,21,23,M.LEAD,2)
	a.ellipse(132,91,17,20,M.RUBBER,2)
	a.ellipse(132,91,14,17,M.DARK_GLASS,2)
	for side: int in [-1,1]:
		a.rect(132+side*20-2,76,4,31,M.IRON)
		a.rect(132+side*19,78,1,27,M.STEEL)
		a.rect(132+side*11,87,2,8,M.CHEMICAL_GLASS)
	a.ellipse(132,90,6,10,M.INSULATION,2)
	a.ellipse(132,89,4,7,M.WHITE,2)
	a.rect(131,94,3,7,M.CABLE)
	a.rect(129,99,2,4,M.LEAD)
	a.rect(134,99,2,4,M.LEAD)
	a.rect(128,87,2,2,M.RUBBER)
	a.rect(135,87,2,2,M.RUBBER)
	for point: Vector2i in [Vector2i(110,68),Vector2i(152,68),Vector2i(107,109),Vector2i(155,109)]:
		a.panel(point.x-3,point.y-3,7,7,M.STEEL,M.IRON,2)
	a.pipe(Vector2i(169,77),Vector2i(184,77),5,M.STEEL_PIPE)
	a.pipe(Vector2i(180,77),Vector2i(180,114),5,M.STEEL_PIPE)
	a.vent(171,119,16,9)
	a.rect(124,44,16,4,M.LEAD)
	a.lamp(128,45,M.WHITE,8)
	a.label("NULL",122,116,M.STEEL)
	# Observation slits and thin shielding laminations beside the ascent.
	a.panel(14,82,39,39,M.CONCRETE,M.LEAD,1)
	a.panel(18,86,31,15,M.DARK_GLASS,M.IRON,2)
	a.rect(22,89,20,1,M.CYAN)
	a.rect(23,92,3,5,M.CABLE)
	a.rect(30,92,1,5,M.CABLE)
	a.rect(37,92,5,5,M.CABLE)
	a.console(18,104,14,10,M.WHITE)
	a.vent(35,104,13,10)
	a.label("51",25,74,M.LEAD)
	a.pipe(Vector2i(12,122),Vector2i(50,122),4,M.LEAD)
	a.pipe(Vector2i(17,121),Vector2i(17,157),4,M.LEAD)
	a.panel(11,159,40,17,M.CONCRETE,M.LEAD,1)
	a.label("SEALED",17,165,M.IRON)
	a.panel(91,166,56,12,M.RUBBER,M.IRON,2)
	for x: int in range(95,145,6):
		a.rect(x,169,2,5,M.STEEL)
	a.pipe(Vector2i(155,171),Vector2i(186,171),5,M.LEAD)
	a.label("03",8,8,M.LEAD)
	a.label("GREY AREA 51",65,8,M.LEAD)
	return a.data

static func _route_frames(out: PackedInt32Array,index: int) -> void:
	for path: Array in Layout.paths(index):
		for segment: int in range(path.size()-1):
			var a: Vector2i = path[segment]
			var b: Vector2i = path[segment+1]
			if a.y == b.y:
				var left: int = mini(a.x,b.x)-12
				var width: int = absi(a.x-b.x)+24
				_local(out,index,Rect2i(left,a.y-13,width,1),M.LEAD)
				_local(out,index,Rect2i(left,a.y-13,width,1),M.STEEL)
				_local(out,index,Rect2i(left,a.y+12,width,1),M.IRON)
				_local(out,index,Rect2i(left,a.y+12,width,1),M.STEEL)
				for x: int in range(left+18,left+width-5,52):
					_local(out,index,Rect2i(x,a.y-15,7,2),M.WHITE)
			else:
				var top: int = mini(a.y,b.y)-12
				var height: int = absi(a.y-b.y)+24
				_local(out,index,Rect2i(a.x-13,top,1,height),M.LEAD)
				_local(out,index,Rect2i(a.x+12,top,1,height),M.IRON)
				for y: int in range(top+14,top+height-5,22):
					_local(out,index,Rect2i(a.x-13,y,1,3),M.STEEL)

static func _local(out: PackedInt32Array,index: int,rect: Rect2i,material: int) -> void:
	var clipped: Rect2i = rect.intersection(Rect2i(0,0,192,192))
	if not clipped.has_area(): return
	var origin: Vector2i = Layout.tile_origin(index)+clipped.position
	_rect(out,origin.x,origin.y,clipped.size.x,clipped.size.y,material)

static func _rect(out: PackedInt32Array,x: int,y: int,width: int,height: int,material: int) -> void:
	if width > 0 and height > 0: out.append_array(PackedInt32Array([x,y,width,height,material]))
