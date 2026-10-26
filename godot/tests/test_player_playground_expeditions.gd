extends SceneTree

const Maps = preload("res://scripts/player_playground_expeditions.gd")
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Setup = preload("res://scripts/player_playground_world.gd")
const Catalogue = preload("res://scripts/usable_catalog.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
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
		push_error("EXPEDITIONS: "+message)


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
	var water: int = 0
	var other: int = 0
	for row: Dictionary in rows:
		materials[row.material] = true
		if row.size.x >= 128 and row.size.y >= 96 and row.material in [3,16,24]:
			var box := Rect2i(row.origin,row.size)
			var actual: int = 0
			for y: int in range(box.position.y,box.end.y):
				for x: int in range(box.position.x,box.end.x):
					if cells[y*1024+x] == row.material: actual += 1
			expect(actual >= 16000 and actual >= int(box.get_area()*0.9),"final raster retains a genuinely deep store "+str(id)+str(box))
			expect(largest_liquid_component(cells,box,int(row.material)) >= int(actual*0.9),"deep liquid store remains connected after all architecture is painted "+str(id)+str(box))
			if row.material == 3: water += actual
			else: other += actual

	expect(rows.size() >= 250 and rows.size() <= 4096,"substantial authored detail within native layout budget "+str(id)+" rows"+str(rows.size()))
	expect(materials.size() >= 20,"coherent varied material palette "+str(id))
	expect(water >= 16000 and other >= 16000,"two truly deep liquid stores "+str(id))
	var start: Vector2 = Maps.spawn(id)
	expect(empty(cells,Rect2i(int(start.x)-32,Maps.floor_y(id)-112,232,112)),
		"all-player escape promenade is flat and unobstructed "+str(id))
	var road_clear: bool = true
	var supported: bool = true
	for x: int in range(48,1008):
		var floor: int = Maps.road_y(id,x)
		road_clear = road_clear and empty(cells,Rect2i(x,floor-28,1,28))
		supported = supported and cells[floor*1024+x] != 0
	expect(road_clear,"entire connected baseline keeps28-cell physical clearance "+str(id))
	expect(supported,"entire baseline has actual native road support "+str(id))
	for gate: Vector2 in Maps.checkpoints(id):
		expect(empty(cells,Rect2i(Vector2i(gate)-Vector2i(5,5),Vector2i(10,10))),"gate10Ã—10 clears terrain "+str(id)+str(gate))
		expect(int(gate.y)+12 == Maps.road_y(id,int(gate.x)),"gate matches actual graded road "+str(id))
	var props: Array = Maps.props(id)
	expect(props.size() == 3,"exactlythree purposeful Rapier objects "+str(id))
	for prop: Dictionary in props:
		var box := Rect2i(Vector2i(Vector2(prop.position)-Vector2(prop.size)*0.5),Vector2i(prop.size))
		expect(empty(cells,box),"complete physical prop stage clear "+str(id)+str(box))
		expect(prop.mass > 0 and prop.mass <= 20 and maxi(box.size.x,box.size.y) <= 64,"finite bounded prop mass/size "+str(id))
		for gate: Vector2 in Maps.checkpoints(id): expect(not box.grow(15).has_point(Vector2i(gate)),"prop does not block baseline gate "+str(id))
	for point: Vector2 in Maps.npc_spawns(id):
		expect(point.x >= 320 and empty(cells,Rect2i(Vector2i(point)-Vector2i(24,24),Vector2i(48,48))),
			"complete NPC stage is clear and beyond the first player lane "+str(id)+str(point))
	var outlet: Vector2i = Maps.reservoir_outlet(id)
	expect(cells[outlet.y*1024+outlet.x] == 35 and cells[(outlet.y-1)*1024+outlet.x] == 3,
		"marked glass valve connects actual stored Water to road "+str(id))
	expect(empty(cells,Rect2i(outlet+Vector2i(-5,27),Vector2i(10,10))),"clear actual tool approach below valve "+str(id))
	metrics[str(id)] = {"rectangles":rows.size(),"materials":materials.size(),"deep_water":water,
		"other_deep_liquid":other,"floor":Maps.floor_y(id),"road_end":Maps.road_y(id,1000)}


func test_distinct_volumes() -> void:
	var bins: Dictionary = {}
	for id: StringName in Maps.IDS:
		var cells: PackedByteArray = rasters[id]
		var occupied: Dictionary = {}
		for y: int in range(32,720,16):
			for x: int in range(16,1008,16):
				var count: int = 0
				for yy: int in range(y,y+16,4):
					for xx: int in range(x,x+16,4): count += int(cells[yy*1024+xx] != 0)
				if count > 1: occupied[Vector2i(x,y)] = true
		bins[id] = occupied
	for i: int in range(Maps.IDS.size()):
		for j: int in range(i+1,Maps.IDS.size()):
			var a: Dictionary = bins[Maps.IDS[i]]
			var b: Dictionary = bins[Maps.IDS[j]]
			var common: int = 0
			for key: Vector2i in a:
				if b.has(key): common += 1
			var overlap: float = float(common)/(a.size()+b.size()-common)
			expect(overlap < 0.70,"distinct road/architecture topology %s/%s %.3f" % [Maps.IDS[i],Maps.IDS[j],overlap])
	var archive: PackedByteArray = rasters[&"prism_archive"]
	expect(empty(archive,Rect2i(436,328,126,12)),"archive focus passage has twelve-cell clearance and open mouths")
	var archive_approach: Array[Vector2i] = [Vector2i(342,388),Vector2i(400,364),Vector2i(430,340)]
	for point: Vector2i in archive_approach:
		expect(archive[point.y*1024+point.x] != 0 and empty(archive,Rect2i(point-Vector2i(8,22),Vector2i(16,22))),
			"archive optional approach has physical intermediate landings and clear jump space "+str(point))
	expect(empty(archive,Rect2i(562,316,16,24)) and archive[340*1024+602] != 0,
		"archive passage has an open exit gap and broad reachable recovery shelf")
	var baths: PackedByteArray = rasters[&"buried_baths"]
	expect(baths[420*1024+650] == 87 and empty(baths,Rect2i(652,423,8,55)),
		"buried bath stopper feeds actual open grille into catch court")


func fire(tool, world: Object, index: int, origin: Vector2, aim: Vector2) -> void:
	tool.step(1.0/60.0,world,PackedVector2Array([origin]),[Rect2()],[{"usable_index":index,"aim":aim,"trigger":false}])
	tool.step(1.0/60.0,world,PackedVector2Array([origin]),[Rect2()],[{"usable_index":index,"aim":aim,"trigger":true,"trigger_pressed":true}])


func test_actual_valves() -> void:
	for id: StringName in Maps.IDS:
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(world.diagnostic_reset({"workers":1}),"native valve fixture starts "+str(id))
		var built: Dictionary = Setup.build(world,id,0)
		expect(built.accepted,"actual prepared expedition constructs "+str(id))
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
			"native liquid reaches local downstream row without quantity creation/loss "+str(id))
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


func test_storm_hop() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	expect(runtime.configure(&"stuntbuggy",&"stormbreak_viaduct"),"Storm hop starts from the ordinary map spawn")
	var jumped: bool = false
	var airborne: bool = false
	var landed: bool = false
	var launch := Vector2.ZERO
	var minimum_y: float = INF
	for tick: int in range(1600):
		var before: Dictionary = runtime.observation()
		var hop: bool = not jumped and before.position.x >= 676 and before.position.x < 698 and before.grounded
		if hop:
			jumped = true
			launch = before.position
		runtime.submit_action({"move":Vector2.UP,"primary":hop})
		runtime.step()
		var view: Dictionary = runtime.observation()
		if jumped and view.position.x < 760:
			minimum_y = minf(minimum_y,view.position.y)
			airborne = airborne or not view.grounded
		if jumped and view.position.x >= 770 and view.position.x < 840 and view.grounded:
			landed = true
			break
		if runtime.failed: break
	expect(not runtime.failed and jumped and airborne and landed,"actual single supported hop over Storm crest lands on the connected road")
	expect(minimum_y < launch.y-4,"Storm optional hop measurably lifts the physical chassis")
	metrics["storm_ordinary_hop"] = {"launch":launch,"minimum_y":minimum_y,"landed":landed,
		"position":runtime.observation().position,"ticks":runtime.tick}
	runtime.close()
	runtime.free()


func test_featured_mechanics() -> void:
	test_storm_hop()
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1}),"bath powder fixture starts")
	expect(Setup.build(world,&"buried_baths",0).accepted,"actual buried bath apparatus constructs")
	var tool: Variant = load("res://scripts/usable_runtime.gd").new()
	tool.configure(1)
	fire(tool,world,Catalogue.index_for(&"line_cutter"),Vector2(656,438),Vector2.UP)
	expect(tool.write_count_last >= 5 and world.material_at(656,420) == 0,
		"real Line Cutter opens plywood bath stopper above the eight-cell grille slot")
	var fed: int = 0
	for tick: int in range(320):
		expect(world.simulation_tick(),"ordinary native released-bath tick")
		for x: int in range(582,718):
			if world.material_at(x,486) == 2: fed += 1
	expect(fed > 0,"stored native Sand passes the authored grille into its catch trough")
	metrics["bath_feed_samples"] = fed
	var runtime = Runtime.new()
	root.add_child(runtime)
	expect(runtime.configure(&"acrobat",&"prism_archive"),"actual archive optional owner configures")
	# Fresh owner construction at the connected approach isolates compact
	# traversal. This is not a claim of automatic whole-map expert completion.
	expect(runtime._arena.configure({"version":Arena.VERSION,"seed":0,"max_ticks":Arena.MAX_TICKS,
		"local_patch_radius":0,"course":Course.ID,"playground_map":&"prism_archive","playground_water":0,
		"actors":[{"model":"acrobat","producer":"human","position":Vector2(430,329)}]}),
		"fresh physical rig stages on the archive vent approach")
	for tick: int in range(60):
		runtime.submit_action({})
		runtime.step()
	var tucked: bool = false
	var inside_height: float = 0.0
	var exited: bool = false
	for tick: int in range(1000):
		runtime.submit_action({"move":Vector2.RIGHT,"secondary":true})
		runtime.step()
		var observation: Dictionary = runtime.observation()
		var bounds: Rect2 = physical_extent(runtime)
		if observation.position.x > 456 and observation.position.x < 548:
			tucked = tucked or observation.player_movement.stance == "tucked"
			inside_height = maxf(inside_height,bounds.size.y)
		if bounds.position.x > 562:
			exited = true
			break
	expect(not runtime.failed and exited and tucked and inside_height <= 12.5,
		"complete mounted agile rig enters and exits real twelve-cell archive passage")
	metrics["archive_slide"] = {"exited":exited,"tucked":tucked,"inside_height":inside_height,
		"ticks":runtime.tick,"position":runtime.observation().position,"velocity":runtime.observation().velocity,
		"bounds":physical_extent(runtime)}
	runtime.close()
	runtime.free()


func run() -> void:
	var started: int = Time.get_ticks_msec()
	if "--feature-only" in OS.get_cmdline_user_args():
		test_featured_mechanics()
	else:
		for id: StringName in Maps.IDS: test_layout(id)
		test_distinct_volumes()
	# Static-only explicitly scopes the first authoring pass before root wires
	# selectors. The normal invocation requires actual constructors and motion.
	if "--static-only" not in OS.get_cmdline_user_args() and "--feature-only" not in OS.get_cmdline_user_args():
		test_actual_valves()
		test_wheel_routes()
		test_featured_mechanics()
	await process_frame
	print("EXPEDITION_METRICS ",JSON.stringify(metrics))
	print("EXPEDITION_ELAPSED_SECONDS ",float(Time.get_ticks_msec()-started)/1000.0)
	print("EXPEDITIONS: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
