extends SceneTree

const Maps = preload("res://scripts/player_playground_cyberpunk.gd")
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Setup = preload("res://scripts/player_playground_world.gd")
const Catalogue = preload("res://scripts/usable_catalog.gd")
const Course = preload("res://scripts/player_playground_course.gd")
var assertions: int = 0
var failures: int = 0
var rasters: Dictionary = {}
var metrics: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("CYBERPUNK: "+message)


func raster(id: StringName) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(1024*768)
	for row: Dictionary in Maps.layout(id):
		for y: int in range(row.origin.y,row.origin.y+row.size.y):
			for x: int in range(row.origin.x,row.origin.x+row.size.x): result[y*1024+x] = row.material
	return result


func empty(cells: PackedByteArray, box: Rect2i) -> bool:
	if not Maps.VIEW.encloses(box): return false
	for y: int in range(box.position.y,box.end.y):
		for x: int in range(box.position.x,box.end.x):
			if cells[y*1024+x] != 0: return false
	return true


func largest_liquid_component(cells: PackedByteArray, box: Rect2i, material: int) -> int:
	var visited := PackedByteArray()
	visited.resize(box.get_area())
	var best: int = 0
	for local_y: int in range(box.size.y):
		for local_x: int in range(box.size.x):
			var first: int = local_y*box.size.x+local_x
			if visited[first] != 0: continue
			visited[first] = 1
			if cells[(box.position.y+local_y)*1024+box.position.x+local_x] != material: continue
			var queue := PackedInt32Array([first])
			var cursor: int = 0
			while cursor < queue.size():
				var index: int = queue[cursor]
				cursor += 1
				var x: int = index%box.size.x
				var y: int = index/box.size.x
				for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var adjacent := Vector2i(x,y)+delta
					if adjacent.x < 0 or adjacent.y < 0 or adjacent.x >= box.size.x or adjacent.y >= box.size.y: continue
					var next: int = adjacent.y*box.size.x+adjacent.x
					if visited[next] != 0: continue
					visited[next] = 1
					if cells[(box.position.y+adjacent.y)*1024+box.position.x+adjacent.x] == material: queue.append(next)
			best = maxi(best,queue.size())
	return best


func test_layout(id: StringName) -> void:
	var cells: PackedByteArray = raster(id)
	rasters[id] = cells
	var rows: Array = Maps.layout(id)
	var materials: Dictionary = {}
	var bounded: bool = true
	for row: Dictionary in rows:
		bounded = bounded and Maps.VIEW.encloses(Rect2i(row.origin,row.size)) and row.size.x > 0 and row.size.y > 0
		materials[row.material] = true
	expect(bounded,"every returned native rectangle is bounded "+str(id))
	expect(rows.size() >= 200 and rows.size() <= 4096,"authored architecture stays within prepared rectangle capacity "+str(id))
	expect(materials.size() >= 18,"varied coherent existing material palette "+str(id))
	expect(not materials.has(117),"comparison map avoids the preserved fractional Water/bare-iron refill interaction "+str(id))
	var start: Vector2 = Maps.spawn(id)
	expect(empty(cells,Rect2i(int(start.x)-32,Maps.floor_y(id)-112,232,112)),"all-player start promenade remains clear "+str(id))
	var clear_road: bool = true
	var supported: bool = true
	for x: int in range(48,1014):
		var floor: int = Maps.road_y(id,x)
		clear_road = clear_road and empty(cells,Rect2i(x,floor-28,1,28))
		supported = supported and cells[floor*1024+x] != 0
	expect(clear_road and supported,"whole shared road has native support and full physical clearance "+str(id))
	var gates: PackedVector2Array = Maps.checkpoints(id)
	expect(gates.size() == 4,"four ordered baseline gates "+str(id))
	for gate: Vector2 in gates:
		expect(empty(cells,Rect2i(Vector2i(gate)-Vector2i(5,5),Vector2i(10,10))),"gate is a clear actual road target "+str(id))
		expect(int(gate.y)+12 == Maps.road_y(id,int(gate.x)),"gate matches road raster "+str(id))
	var props: Array = Maps.props(id)
	expect(props.size() == 3,"three real movable props "+str(id))
	for prop: Dictionary in props:
		var box := Rect2i(Vector2i(Vector2(prop.position)-Vector2(prop.size)*0.5),Vector2i(prop.size))
		expect(empty(cells,box),"complete prop footprint stages in empty space "+str(id)+str(box))
		expect(prop.mass > 0 and prop.mass <= 20 and maxi(box.size.x,box.size.y) <= 64,"finite bounded prop inputs")
		for gate: Vector2 in gates: expect(not box.grow(15).has_point(Vector2i(gate)),"heavy cargo leaves baseline gate open")
	var stages: PackedVector2Array = Maps.npc_spawns(id)
	expect(stages.size() == 2,"two independent NPC stages")
	for stage: Vector2 in stages:
		expect(stage.x >= 320 and empty(cells,Rect2i(Vector2i(stage)-Vector2i(24,24),Vector2i(48,48))),"full NPC bounds clear terrain and liquid "+str(id)+str(stage))
	var stores: Array = Maps.reservoirs(id)
	expect(stores.size() == 2,"two independently authored large stores "+str(id))
	var counts: Dictionary = {}
	for store: Dictionary in stores:
		var box: Rect2i = store.bounds
		var actual: int = 0
		expect(Maps.VIEW.encloses(box),"store census is bounded")
		for y: int in range(box.position.y,box.end.y):
			for x: int in range(box.position.x,box.end.x):
				if cells[y*1024+x] == int(store.material): actual += 1
		var connected: int = largest_liquid_component(cells,box,int(store.material))
		expect(actual >= 16000 and connected >= int(actual*0.9),"final shaped liquid store is substantial and connected "+str(id)+str(store.material)+str(actual))
		counts[int(store.material)] = actual
	expect(counts.has(3) and (counts.has(16) or counts.has(24)),"real Water and other liquid both retained")
	var outlet: Vector2i = Maps.reservoir_outlet(id)
	expect(cells[outlet.y*1024+outlet.x] == 35 and cells[(outlet.y-1)*1024+outlet.x] == 3,"marked glass outlet touches stored Water "+str(id))
	expect(empty(cells,Rect2i(outlet+Vector2i(-5,27),Vector2i(10,10))),"ordinary tool origin is unobstructed below glass plate "+str(id))
	metrics[str(id)] = {"rectangles":rows.size(),"materials":materials.size(),"liquid_cells":counts}


func test_distinct_architecture() -> void:
	var occupied: Dictionary = {}
	for id: StringName in Maps.IDS:
		var bins: Dictionary = {}
		for y: int in range(32,720,16):
			for x: int in range(320,992,16):
				if rasters[id][y*1024+x] != 0: bins[Vector2i(x,y)] = true
		occupied[id] = bins
	for i: int in range(Maps.IDS.size()):
		for j: int in range(i+1,Maps.IDS.size()):
			var a: Dictionary = occupied[Maps.IDS[i]]
			var b: Dictionary = occupied[Maps.IDS[j]]
			var common: int = 0
			for key: Vector2i in a:
				if b.has(key): common += 1
			var overlap: float = float(common)/maxi(1,a.size()+b.size()-common)
			expect(overlap < 0.80,"independent spatial composition "+str(Maps.IDS[i])+"/"+str(Maps.IDS[j])+" overlap"+str(overlap))


func fire(tool, world: Object, index: int, origin: Vector2, aim: Vector2) -> void:
	tool.step(1.0/60.0,world,PackedVector2Array([origin]),[Rect2()],[{"usable_index":index,"aim":aim,"trigger":false}])
	tool.step(1.0/60.0,world,PackedVector2Array([origin]),[Rect2()],[{"usable_index":index,"aim":aim,"trigger":true,"trigger_pressed":true}])


func test_actual_valves() -> void:
	for id: StringName in Maps.IDS:
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(world.diagnostic_reset({"workers":1}),"native valve fixture starts "+str(id))
		var built: Dictionary = Setup.build(world,id,0)
		expect(built.accepted,"actual prepared cyberpunk constructs "+str(id))
		if not built.accepted: continue
		var initial: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,768))
		var outlet: Vector2i = Maps.reservoir_outlet(id)
		var tool: Variant = load("res://scripts/usable_runtime.gd").new()
		tool.configure(1)
		fire(tool,world,Catalogue.index_for(&"glass_scorer"),Vector2(outlet)+Vector2(0,32),Vector2.UP)
		expect(tool.write_count_last >= 7,"real scored-glass use opens whole valve "+str(id))
		var released: int = 0
		for tick: int in range(60):
			expect(world.simulation_tick(),"opened reservoir native tick")
			for x: int in range(outlet.x-12,outlet.x+13):
				if world.material_at(x,outlet.y+16) == 3: released += 1
		var final: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,768))
		expect(released > 0 and final.water_integer == initial.water_integer,
			"native liquid reaches the local downstream sample without quantity creation/loss "+str(id))
		metrics[str(id)].valve_release_samples = released


func test_wheel_routes() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	for id: StringName in Maps.IDS:
		for player: StringName in [&"stuntbuggy",&"trialsbike"]:
			expect(runtime.configure(player,id),"actual expedition wheel owner configures "+str(id)+str(player))
			var start: float = runtime.observation().position.x
			for tick: int in range(300):
				runtime.submit_action({"move":Vector2.UP})
				runtime.step()
				if runtime.observation().position.x > start+174: break
			expect(not runtime.failed and runtime.observation().position.x > start+174,
				"ordinary wheel drive exits every new start "+str(id)+str(player))
			# Every complete road is exercised with both wheel rigs. No transform,
			# velocity or tool assignment can hide a later obstruction.
			expect(runtime.configure(player,id),"full graded route fixture configures")
			var gates: PackedVector2Array = Maps.checkpoints(id)
			var next: int = 0
			for tick: int in range(1500):
				runtime.submit_action({"move":Vector2.UP})
				runtime.step()
				if next < gates.size() and Vector2(runtime.observation().position).distance_to(gates[next]) <= 15.0: next += 1
				if next == gates.size() or runtime.failed: break
			expect(not runtime.failed and next == gates.size(),"actual entire baseline completes "+str(id)+str(player)+" gates"+str(next))
			var bounds: Rect2 = physical_extent(runtime)
			expect(Rect2(Maps.VIEW).encloses(bounds),"complete finished vehicle remains inside the map "+str(id)+str(player))
			expect(absf(float(runtime.observation().rotation)) < 0.8,"vehicle finishes upright "+str(id)+str(player))
			metrics[str(id)][str(player)+"_baseline"] = {"gates":next,"ticks":runtime.tick,"position":runtime.observation().position}

	runtime.close()
	runtime.free()


func physical_extent(runtime) -> Rect2:
	var bounds := Rect2()
	var first: bool = true
	for part: Dictionary in runtime.render_parts():
		if int(part.get("actor_id",0)) != 0: continue
		var pose: Transform2D = part.transform
		var half: Vector2 = Vector2(part.size)*0.5
		for corner: Vector2 in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),
			Vector2(half.x,half.y),Vector2(-half.x,half.y)]:
			var point: Vector2 = pose*corner
			bounds = Rect2(point,Vector2.ZERO) if first else bounds.expand(point)
			first = false
	return bounds


func run() -> void:
	var started: int = Time.get_ticks_msec()
	expect(Maps.IDS.size() == 7 and Maps.NAMES.size() == 7 and Maps.HINTS.size() == 7 and Maps.SUGGESTED.size() == 7,"aligned seven-map metadata")
	var unique: Dictionary = {}
	var suggested: Dictionary = {}
	for player: StringName in Maps.SUGGESTED:
		expect(player in Course.PRESETS and not suggested.has(player),"one distinct suggested map for every player type")
		suggested[player] = true
	for id: StringName in Maps.IDS:
		expect(id in Course.MAP_IDS and not unique.has(id),"unique registered map available to every player")
		unique[id] = true
		test_layout(id)
	test_distinct_architecture()
	if "--static-only" not in OS.get_cmdline_user_args():
		test_actual_valves()
		test_wheel_routes()
	await process_frame
	print("CYBERPUNK_METRICS ",JSON.stringify(metrics))
	print("CYBERPUNK_ELAPSED_SECONDS ",float(Time.get_ticks_msec()-started)/1000.0)
	print("CYBERPUNK: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
