class_name CyberBlacksiteNine
extends RefCounted

# Nine authored camera tiles in one native material world. The common routing
# pass owns both sides of every internal edge, after all tile detail is composed.
const ID: String = "blacksite_nine"
const SCENARIO_ID: String = "showcase/blacksite-nine"
const TITLE: String = "Blacksite Nine"
const VERSION: int = 1
const Layout = preload("res://scripts/blacksite_nine_layout.gd")
const M = preload("res://scripts/neon_reliquary.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const ROWS = [preload("res://scripts/blacksite_nine_surface.gd"),
	preload("res://scripts/blacksite_nine_midworks.gd"),
	preload("res://scripts/blacksite_nine_depths.gd")]

static func spawn() -> Vector2:
	return Layout.spawn()

static func viewpoints() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"name":"The complete complex",
		"origin":Vector2(Layout.ORIGIN), "size":Layout.EXTENT}]
	for index: int in range(9):
		result.append({"name":Layout.CODES[index] + " / " + Layout.TITLES[index],
			"origin":Vector2(Layout.tile_origin(index)), "size":Vector2i(320, 320)})
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
	# Camera changes keep the complete complex active under ordinary native rules.
	out.interest = {"policy":"fixed", "region":[32,32,960,960]}
	var regions: Array = []
	for index: int in range(9):
		var origin: Vector2i = Layout.tile_origin(index)
		regions.append({"id":Layout.IDS[index], "label":Layout.CODES[index] + " / " + Layout.TITLES[index],
			"region":[origin.x,origin.y,320,320]})
	out["presentation"] = {"title":TITLE,
		"instructions":"An industrial research blacksite above six buried machinery districts. "
			+ "One continuous 3×3 complex: all twelve neighbouring edges have traversable connections. "
			+ "Enter from Slag Approach, cross the lab, descend through Containment Choir and the warrens, "
			+ "then circle the lowest works and climb toward the eastern wasteland. "
			+ "A/D move; hold Space to rise, release to descend. F follows the player, arrows pan, "
			+ "P animates, F8 gives a clean view. Tile views preserve the whole world and your edits. "
			+ "R restores all nine tiles together. Starts paused.",
		"duration_ticks":600,
		"baseline":"Current native materials / Baseline transport / Water8-coherence12",
		"profile":"Blacksite Nine / connected 3×3 composition v1", "regions":regions}
	out.source_recipe = "CyberBlacksiteNine/v1"
	out.source_recipe_hash = JSON.stringify(out.rectangles).sha256_text()
	return out

static func rectangles() -> PackedInt32Array:
	var out := PackedInt32Array()
	_rect(out, 0, 0, 1024, 1, M.WALL)
	_rect(out, 0, 1, 1, 1023, M.WALL)
	_rect(out, 1023, 1, 1, 1023, M.WALL)
	_rect(out, 1, 1023, 1022, 1, M.WALL)
	for index: int in range(9):
		var origin: Vector2i = Layout.tile_origin(index)
		var local: PackedInt32Array = ROWS[index / 3].tile(index % 3)
		for offset: int in range(0, local.size(), 5):
			_rect(out, origin.x + local[offset], origin.y + local[offset + 1],
				local[offset + 2], local[offset + 3], local[offset + 4])
	# The lowest earth and outside retaining walls belong to the whole complex.
	_rect(out, 32, 984, 960, 8, M.GRANITE)
	_rect(out, 32, 352, 8, 632, M.SLATE)
	_rect(out, 984, 352, 8, 632, M.SLATE)
	for index: int in range(9):
		_route_frames(out, index)
	_shared_edges(out)
	# This final carve is authoritative for collision. No lamp, glass pane,
	# decorative cable or shaft rung can close the authored circulation volume.
	for index: int in range(9):
		for path: Array in Layout.paths(index):
			for segment: int in range(path.size() - 1):
				var a: Vector2i = path[segment]
				var b: Vector2i = path[segment + 1]
				var start := Vector2i(mini(a.x,b.x) - 14, mini(a.y,b.y) - 14)
				var size := Vector2i(absi(a.x-b.x) + 28, absi(a.y-b.y) + 28)
				_local(out, index, Rect2i(start, size), M.EMPTY)
	return out

static func _route_frames(out: PackedInt32Array, index: int) -> void:
	for path: Array in Layout.paths(index):
		for segment: int in range(path.size() - 1):
			var a: Vector2i = path[segment]
			var b: Vector2i = path[segment + 1]
			if a.y == b.y:
				var left: int = mini(a.x,b.x) - 14
				var width: int = absi(a.x-b.x) + 28
				_local(out, index, Rect2i(left,a.y+14,width,5), M.IRON)
				_local(out, index, Rect2i(left,a.y+14,width,1), M.WET_ASPHALT)
				if index >= 3 or a.y > 280:
					_local(out, index, Rect2i(left,a.y-18,width,4), M.RUSTED_STEEL)
			else:
				var top: int = mini(a.y,b.y) - 14
				var height: int = absi(a.y-b.y) + 28
				_local(out, index, Rect2i(a.x-18,top,4,height), M.IRON)
				_local(out, index, Rect2i(a.x+14,top,4,height), M.RUSTED_STEEL)
				# Recessed guide marks sit in the shaft wall, outside body clearance.
				for y: int in range(top + 10, top + height - 4, 44):
					_local(out, index, Rect2i(a.x-17,y,2,3), M.AMBER)

static func _shared_edges(out: PackedInt32Array) -> void:
	for edge: Dictionary in Layout.EDGES:
		var origin: Vector2i = Layout.tile_origin(int(edge.a))
		var offset: int = int(edge.offset)
		if edge.axis == "x":
			var x: int = origin.x + 320
			var top: int = origin.y
			if int(edge.a) < 3:
				# Continuous open surface air and the same strata at both cut edges.
				_rect(out, x-8,top,16,276,M.EMPTY)
				_rect(out, x-8,top+276,16,44,M.CONCRETE)
				_rect(out, x-8,top+280,16,3,M.RUSTED_STEEL)
				_rect(out, x-8,top+299,16,21,M.SLATE)
			else:
				_rect(out, x-8,top,16,320,M.SLATE)
				_rect(out, x-3,top,6,320,M.IRON)
				_rect(out, x-12,top+offset-20,24,6,M.RUSTED_STEEL)
				_rect(out, x-12,top+offset+14,24,6,M.IRON)
				_rect(out, x-10,top+offset-25,6,2,M.AMBER)
				_rect(out, x+4,top+offset-25,6,2,M.AMBER)
		else:
			var y: int = origin.y + 320
			_rect(out, origin.x,y-8,320,16,M.SLATE)
			_rect(out, origin.x,y-3,320,6,M.IRON)
			_rect(out, origin.x+offset-20,y-12,6,24,M.IRON)
			_rect(out, origin.x+offset+14,y-12,6,24,M.RUSTED_STEEL)
			_rect(out, origin.x+offset-25,y-10,2,6,M.AMBER)
			_rect(out, origin.x+offset-25,y+4,2,6,M.AMBER)

static func _local(out: PackedInt32Array, index: int, rect: Rect2i, material: int) -> void:
	var clipped: Rect2i = rect.intersection(Rect2i(0,0,320,320))
	if not clipped.has_area(): return
	var origin: Vector2i = Layout.tile_origin(index) + clipped.position
	_rect(out, origin.x,origin.y,clipped.size.x,clipped.size.y,material)

static func _rect(out: PackedInt32Array, x: int, y: int, width: int, height: int, material: int) -> void:
	if width > 0 and height > 0:
		out.append_array(PackedInt32Array([x,y,width,height,material]))
