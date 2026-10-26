extends SceneTree

# A map signature alone missed the former shared layout and blocked starts.
# Check the resulting native-cell raster, deep stores, collision-sized stages
# and initial wheel route, with no pose/velocity assignment or tool shortcut.
const Districts = preload("res://scripts/player_playground_districts.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Setup = preload("res://scripts/player_playground_world.gd")
const Usables = preload("res://scripts/usable_catalog.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
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
		push_error("DISTRICT_ROUTES: " + message)


func raster(id: StringName) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(1024*768)
	for item: Dictionary in Districts.layout(id):
		for y: int in range(item.origin.y,item.origin.y+item.size.y):
			for x: int in range(item.origin.x,item.origin.x+item.size.x):
				cells[y*1024+x] = item.material
	return cells


func clear(cells: PackedByteArray, area: Rect2i) -> bool:
	if not Districts.VIEW.encloses(area): return false
	for y: int in range(area.position.y,area.end.y):
		for x: int in range(area.position.x,area.end.x):
			if cells[y*1024+x] != 0: return false
	return true


func test_layout(id: StringName) -> void:
	var cells: PackedByteArray = raster(id)
	rasters[id] = cells
	var geometry: Array = Districts.layout(id)
	var materials: Dictionary = {}
	var deep_water: int = 0
	var deep_other: int = 0
	for item: Dictionary in geometry:
		materials[item.material] = true
		if item.material in [3,16,24] and item.size.y >= 96 and item.size.x >= 128:
			if item.material == 3: deep_water += item.size.x*item.size.y
			else: deep_other += item.size.x*item.size.y
	expect(geometry.size() >= 100 and geometry.size() <= 4096 and materials.size() >= 15,
		"bounded detailed authored structures/materials "+str(id))
	expect(deep_water >= 16000 and deep_other >= 16000,
		"two substantial independent liquid stores, not decorative strips "+str(id))
	var start: Vector2 = Districts.spawn(id)
	var floor: int = Districts.floor_y(id)
	expect(clear(cells,Rect2i(int(start.x)-32,floor-112,232,112)),
		"all-player spawn and first 200 cells have 112-cell clear headroom "+str(id))
	var supported: bool = true
	for x: int in range(int(start.x)-32,int(start.x)+200):
		supported = supported and cells[floor*1024+x] != 0
	expect(supported,"unbroken ground support to first refuge "+str(id))
	if id not in [&"cannon_run",&"rat_steps"]:
		expect(clear(cells,Rect2i(280,floor-30,734,30)),
			"lower bypass continues beneath the district, with no second spawn cage "+str(id))
	for point: Vector2 in Districts.checkpoints(id):
		expect(clear(cells,Rect2i(Vector2i(point)-Vector2i(5,5),Vector2i(10,10))),
			"checkpoint has actual clearance "+str(id)+str(point))
		expect(cells[(int(point.y)+12)*1024+int(point.x)] != 0,
			"universal baseline gate stands over the actual drivable road "+str(id)+str(point))
	for prop: Dictionary in Districts.props(id):
		var box := Rect2i(Vector2i(Vector2(prop.position)-Vector2(prop.size)*0.5),Vector2i(prop.size))
		expect(clear(cells,box),"complete movable Rapier prop stage clears terrain "+str(id)+str(box))
		expect(prop.mass > 0 and box.size.x >= 16 and box.size.y >= 16,"finite substantial physical prop "+str(id))
		for target: Vector2 in Districts.checkpoints(id):
			expect(not box.grow(15).has_point(Vector2i(target)),"props do not initially block baseline gate approaches "+str(id))
	for point: Vector2 in Districts.npc_spawns(id):
		expect(clear(cells,Rect2i(Vector2i(point)-Vector2i(24,24),Vector2i(48,48))),
			"complete NPC stage clears terrain "+str(id)+str(point))
	metrics[str(id)] = {"rectangles":geometry.size(),"materials":materials.size(),
		"deep_water_cells":deep_water,"deep_other_liquid_cells":deep_other,"spawn":start,"floor":floor}


func test_challenge_geometry() -> void:
	var mill: PackedByteArray = rasters[&"afterimage_works"]
	expect(clear(mill,Rect2i(334,618,118,12)),"mill slide vent has two open mouths and continuous twelve-cell passage")
	expect(mill[617*1024+392] != 0 and mill[630*1024+392] != 0,
		"slide passage retains actual roof and floor")
	var quarry: PackedByteArray = rasters[&"cannon_run"]
	expect(clear(quarry,Rect2i(708,656,44,80)),"quarry launch and landing have a true44-cell air gap")
	expect(quarry[684*1024+780] != 0 and quarry[736*1024+736] != 0,
		"quarry has both physical landing deck and lower recovery road")
	var foundry: PackedByteArray = rasters[&"dust_foundry"]
	expect(foundry[304*1024+428] == 87 and clear(foundry,Rect2i(426,307,8,143)),
		"breakable plywood throat feeds an actual open grate slot through the first comb")
	expect(foundry[397*1024+420] == 66 and foundry[397*1024+428] == 0,
		"foundry grate has material bars and open apertures rather than a solid cap")
	for id: StringName in Districts.IDS:
		var point: Vector2i = Districts.reservoir_outlet(id)
		var cells: PackedByteArray = rasters[id]
		expect(cells[point.y*1024+point.x] == 35 and cells[(point.y-1)*1024+point.x] == 3,
			"visible glass valve is connected to actual reservoir Water "+str(id))
		expect(clear(cells,Rect2i(point+Vector2i(-5,27),Vector2i(10,10))),
			"valve has a clear tool approach from the universal road "+str(id))
	var market: PackedByteArray = rasters[&"mixed"]
	for tread: Vector2i in [Vector2i(984,662),Vector2i(946,654),Vector2i(982,628),
		Vector2i(934,602),Vector2i(978,576),Vector2i(914,550),Vector2i(866,526)]:
		expect(market[tread.y*1024+tread.x+12] != 0 and clear(market,Rect2i(tread+Vector2i(1,-16),Vector2i(28,16))),
			"market service stairs have actual treads and body-sized headroom "+str(tread))
	expect(clear(quarry,Rect2i(752,660,80,24)) and Districts.props(&"cannon_run")[0].position.x >= 846,
		"quarry retains a clear landing before the optional loose-load braking bay")
	var aqueduct: PackedByteArray = rasters[&"rat_steps"]
	expect(clear(aqueduct,Rect2i(928,500,10,80)) and aqueduct[530*1024+888] != 0,
		"aqueduct upper balance branch has a refuge and an open descent through its pier")
	expect(mill[656*1024+310] != 0 and mill[640*1024+290] != 0 \
		and clear(mill,Rect2i(304,640,14,16)) and Districts.props(&"afterimage_works")[0].mass < 2.0,
		"mill has a pushable entry step and overhead staging shelves with launch headroom")
	var port: PackedByteArray = rasters[&"vector_port"]
	expect(clear(port,Rect2i(876,568,68,62)) and port[630*1024+910] != 0,
		"port has a sixty-eight-cell clear touchdown volume over its actual landing deck")
	expect(foundry[468*1024+428] != 0 and foundry[612*1024+690] != 0,
		"foundry combs have separate actual receiving trays")
	var cathedral: PackedByteArray = rasters[&"undertow_lab"]
	expect(cathedral[337*1024+508] == 3 and cathedral[338*1024+508] == 35 \
		and clear(cathedral,Rect2i(508,345,8,37)) and cathedral[382*1024+510] != 0,
		"cathedral upper store feeds its glass outlet, open filter slot and catch terrace")
	expect(cathedral[570*1024+318] != 0 and cathedral[622*1024+302] != 0,
		"cathedral optional apparatus has distinct retreat ledges above the street")
	expect(clear(rasters[&"rocket_yard"],Rect2i(526,314,18,96)),
		"silo inner slalom has a real mid-height opening toward its exterior pad")


func fire_tool(tool, world: Object, index: int, origin: Vector2, aim: Vector2) -> void:
	tool.step(1.0/60.0,world,PackedVector2Array([origin]),[Rect2()],
		[{"usable_index":index,"aim":aim,"trigger":false}])
	tool.step(1.0/60.0,world,PackedVector2Array([origin]),[Rect2()],
		[{"usable_index":index,"aim":aim,"trigger":true,"trigger_pressed":true}])


func test_reservoir_mechanics() -> void:
	for id: StringName in Districts.IDS:
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(world.diagnostic_reset({"workers":1}),"fresh valve apparatus "+str(id))
		var setup: Dictionary = Setup.build(world,id,0)
		expect(setup.accepted,"actual native district constructs for valve test "+str(id))
		if not setup.accepted: continue
		var point: Vector2i = Districts.reservoir_outlet(id)
		var initial: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,768))
		var tool = load("res://scripts/usable_runtime.gd").new()
		tool.configure(1)
		fire_tool(tool,world,Usables.index_for(&"glass_scorer"),Vector2(point)+Vector2(0,32),Vector2.UP)
		expect(tool.write_count_last >= 7 and world.material_at(point.x,point.y) == 0,
			"actual Glass Scorer opens the full seven-cell glass valve without painting "+str(id))
		var released: int = 0
		for tick: int in range(70):
			expect(world.simulation_tick(),"opened reservoir ordinary native gravity tick")
			for x: int in range(point.x-12,point.x+13):
				if world.material_at(x,point.y+16) == 3: released += 1
		var final: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,768))
		expect(released > 0 and final.water_integer == initial.water_integer,
			"glass valve releases real reservoir Water onto the road with exact quantity "+str(id))
		metrics[str(id)].valve_water_samples = released
	# A real tool opens the foundry's throat; existing native powders must then
	# pass through the grate/comb instead of accumulating on an invisible cap.
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	world.diagnostic_reset({"workers":1})
	expect(Setup.build(world,&"dust_foundry",0).accepted,"actual foundry powder apparatus constructs")
	var cutter = load("res://scripts/usable_runtime.gd").new()
	cutter.configure(1)
	fire_tool(cutter,world,Usables.index_for(&"line_cutter"),Vector2(428,320),Vector2.UP)
	expect(cutter.write_count_last > 0 and world.material_at(428,304) == 0,"actual cutter opens hopper throat")
	var fed: int = 0
	for tick: int in range(320):
		expect(world.simulation_tick(),"released hopper runs actual native material simulation")
		for x: int in range(280,610):
			if world.material_at(x,452) in [2,14,23]: fed += 1
	expect(fed > 0,"authored hopper powder actually passes the first grate and hanging comb")
	metrics["foundry_feed_samples"] = fed


func test_long_vehicle_progress() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	for id: StringName in Districts.IDS:
		for player: StringName in [&"stuntbuggy",&"trialsbike"]:
			expect(runtime.configure(player,id),"long route actually constructs "+str(id)+str(player))
			var next: int = 0
			var gates: PackedVector2Array = Districts.checkpoints(id)
			for tick: int in range(1400):
				runtime.submit_action({"move":Vector2.UP})
				runtime.step()
				if next < gates.size() and Vector2(runtime.observation().position).distance_to(gates[next]) <= 15.0:
					next += 1
				if next == gates.size() or runtime.failed: break
			expect(not runtime.failed and next == gates.size(),
				"ordinary physical throttle completes every universal gate "+str(id)+str(player)+" reached"+str(next))
			var final_view: Dictionary = runtime.observation()
			var bounds: Rect2 = physical_extent(runtime)
			expect(Rect2(Districts.VIEW).encloses(bounds) and absf(float(final_view.rotation)) < 0.8,
				"complete copied vehicle bounds finish upright inside the map "+str(id)+str(player))
			metrics[str(id)+"/"+str(player)+"/baseline"] = {"gates":next,"ticks":runtime.tick,
				"position":final_view.position,"rotation":final_view.rotation,"bounds":bounds}
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


func test_optional_motion() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	expect(runtime.configure(&"acrobat",&"afterimage_works"),"actual mill slide owner constructs")
	# Ordinary initial staging on the vent's approach pad isolates the optional
	# challenge. It is a fresh prepared native/physical owner, never a pose edit.
	expect(runtime._arena.configure({"version":Arena.VERSION,"seed":0,"max_ticks":Arena.MAX_TICKS,
		"local_patch_radius":0,"course":Course.ID,"playground_map":&"afterimage_works","playground_water":0,
		"actors":[{"model":"acrobat","producer":"human","position":Vector2(324,619)}]}),
		"fresh mounted rig stages at authored vent approach")
	for tick: int in range(60):
		runtime.submit_action({})
		runtime.step()
	var tucked: bool = false
	var inside_height: float = 0.0
	var exited: bool = false
	for tick: int in range(240):
		runtime.submit_action({"move":Vector2.RIGHT,"secondary":true})
		runtime.step()
		var view: Dictionary = runtime.observation()
		var bounds: Rect2 = physical_extent(runtime)
		if view.position.x > 350 and view.position.x < 430:
			tucked = tucked or view.player_movement.stance == "tucked"
			inside_height = maxf(inside_height,bounds.size.y)
		if bounds.position.x > 452:
			exited = true
			break
	expect(not runtime.failed and exited and tucked and inside_height <= 12.5,
		"complete mounted Afterimage enters and exits actual twelve-cell mill vent in compact stance")
	metrics["mill_slide"] = {"exit":exited,"tucked":tucked,"inside_height":inside_height,"ticks":runtime.tick}
	expect(runtime.configure(&"stuntbuggy",&"cannon_run"),"actual quarry jump owner constructs")
	var jumped: bool = false
	var crossed: bool = false
	var landed: bool = false
	for tick: int in range(1000):
		var view: Dictionary = runtime.observation()
		var hop: bool = not jumped and view.position.x >= 688 and view.position.x < 708 and view.grounded
		if hop: jumped = true
		runtime.submit_action({"move":Vector2.UP,"primary":hop})
		runtime.step()
		view = runtime.observation()
		if view.position.x > 708 and view.position.x < 752 and view.position.y < 694: crossed = true
		if view.position.x > 768 and view.position.x < 828 and view.position.y < 690:
			landed = true
			break
	expect(not runtime.failed and jumped and crossed and landed,
		"ordinary drive plus one admitted hop clears real quarry gap and reaches landing road")
	metrics["quarry_hop"] = {"jumped":jumped,"crossed":crossed,"landed":landed,
		"position":runtime.observation().position,"ticks":runtime.tick}
	# A fresh candidate begins above the actual port deck. Let its complete
	# mounted body fall and settle; an empty pixel interval alone is insufficient.
	expect(runtime.configure(&"arcadelander",&"vector_port"),"port landing owner constructs")
	expect(runtime._arena.configure({"version":Arena.VERSION,"seed":0,"max_ticks":Arena.MAX_TICKS,
		"local_patch_radius":0,"course":Course.ID,"playground_map":&"vector_port","playground_water":0,
		"actors":[{"model":"arcadelander","producer":"human","position":Vector2(910,588)}]}),
		"fresh complete lander stages over the cleared port landing deck")
	for tick: int in range(180):
		runtime.submit_action({})
		runtime.step()
	var landed_bounds: Rect2 = physical_extent(runtime)
	expect(not runtime.failed and runtime.observation().grounded \
		and Rect2(876,568,68,64).encloses(landed_bounds),
		"actual complete mounted lander lands inside the clear touchdown volume")
	metrics["port_landing"] = {"bounds":landed_bounds,"grounded":runtime.observation().grounded}
	runtime.close()
	runtime.free()


func test_mill_from_ordinary_spawn() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	expect(runtime.configure(&"acrobat",&"afterimage_works"),"mill ordinary-spawn access fixture constructs")
	for tick: int in range(50):
		runtime.submit_action({})
		runtime.step()
	for tick: int in range(150):
		if runtime.observation().position.x >= 238: break
		runtime.submit_action({"move":Vector2.RIGHT})
		runtime.step()
	# Two distinct ordinary jump edges lift from the loading street to the
	# intermediate ledge; there is no prepared challenge pose or velocity edit.
	var landed_ledge: bool = false
	var trace: Array = []
	for tick: int in range(110):
		var view: Dictionary = runtime.observation()
		var target: float = 266.0 if tick < 31 else 294.0
		var steer: float = clampf((target-float(view.position.x))*0.15-float(view.velocity.x)*0.015,-1.0,1.0)
		runtime.submit_action({"move":Vector2(steer,0),"primary":tick < 25 or (tick >= 26 and tick < 70)})
		runtime.step()
		view = runtime.observation()
		if tick%10 == 0: trace.append({"tick":tick,"position":view.position,"velocity":view.velocity,"move":view.player_movement.last_move})
		if view.grounded and view.position.y < 678 and view.position.x > 282 and view.position.x < 304:
			landed_ledge = true
			break
	expect(not runtime.failed and landed_ledge,"ordinary spawned Afterimage reaches the authored mill staging ledge using two real jumps")
	metrics["mill_spawn_access"] = {"ledge":landed_ledge,"position":runtime.observation().position,"ticks":runtime.tick,"trace":trace}
	var stages: Array = []
	if landed_ledge:
		for destination: Vector2 in [Vector2(310,654),Vector2(290,634),Vector2(325,624)]:
			for settle_tick: int in range(16):
				runtime.submit_action({})
				runtime.step()
			var arrived: bool = false
			for jump_tick: int in range(120):
				var current: Dictionary = runtime.observation()
				var steer: float = clampf((destination.x-float(current.position.x))*0.15-float(current.velocity.x)*0.015,-1.0,1.0)
				runtime.submit_action({"move":Vector2(steer,0),"primary":jump_tick < 25 or (jump_tick >= 26 and jump_tick < 70)})
				runtime.step()
				current = runtime.observation()
				if current.grounded and current.position.y < destination.y+4 and absf(current.position.x-destination.x) < 13:
					arrived = true
					break
			stages.append({"destination":destination,"arrived":arrived,"position":runtime.observation().position})
			if not arrived: break
	metrics["mill_spawn_access"].upper_stages = stages
	runtime.close()
	runtime.free()


func test_distinct_topology() -> void:
	# Exclude the entire ground/start lane and outer boundary. At least 30% of
	# occupied 16-cell architectural bins must differ between every map pair.
	var occupancy: Dictionary = {}
	for id: StringName in Districts.IDS:
		var cells: PackedByteArray = rasters[id]
		var bins: Dictionary = {}
		for y: int in range(32,608,16):
			for x: int in range(16,1008,16):
				var count: int = 0
				for yy: int in range(y,y+16,4):
					for xx: int in range(x,x+16,4): count += int(cells[yy*1024+xx] != 0)
				if count > 1: bins[Vector2i(x,y)] = true
		occupancy[id] = bins
	for i: int in range(Districts.IDS.size()):
		for j: int in range(i+1,Districts.IDS.size()):
			var a: Dictionary = occupancy[Districts.IDS[i]]
			var b: Dictionary = occupancy[Districts.IDS[j]]
			var common: int = 0
			for key: Vector2i in a:
				if b.has(key): common += 1
			var union_count: int = a.size()+b.size()-common
			expect(float(common)/float(union_count) < 0.70,
				"architecture materially differs beyond floors/start: %s/%s overlap %.3f" %
				[Districts.IDS[i],Districts.IDS[j],float(common)/float(union_count)])


func test_native_first_exit() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	# Prove ordinary wheel exits from all eight starts. The complete 336 setup
	# matrix separately covers every player and all six native Water policies.
	for id: StringName in Districts.IDS:
		for player: StringName in [&"stuntbuggy",&"trialsbike"]:
			expect(runtime.configure(player,id),"actual first-route fixture constructs "+str(id)+str(player))
			if runtime.failed: continue
			var initial: float = runtime.observation().position.x
			var furthest: float = initial
			# Includes initial settling and bounded motor acceleration; the buggy
			# needs about 200 ticks to cover174 cells under its actual speed law.
			for tick: int in range(300):
				expect(runtime.submit_action({"move":Vector2.UP}),"ordinary throttle admitted")
				runtime.step()
				furthest = maxf(furthest,float(runtime.observation().position.x))
				if furthest > initial+174: break
			expect(not runtime.failed and furthest > initial+174,
				"unmodified throttle exits start without tools, teleport or jump "+str(id)+str(player)+str(furthest-initial))
			metrics[str(id)+"/"+str(player)] = {"initial_x":initial,"furthest_x":furthest,"ticks":runtime.tick}
	runtime.close()
	runtime.free()


func run() -> void:
	if "--long-routes-only" in OS.get_cmdline_user_args():
		test_long_vehicle_progress()
		print("LONG_DISTRICT_ROUTES ",JSON.stringify(metrics)," assertions=",assertions," failures=",failures)
		quit(0 if failures == 0 else 1)
		return
	if "--mill-access-only" in OS.get_cmdline_user_args():
		test_mill_from_ordinary_spawn()
		print("MILL_SPAWN_ACCESS ",JSON.stringify(metrics)," assertions=",assertions," failures=",failures)
		quit(0 if failures == 0 else 1)
		return
	for id: StringName in Districts.IDS: test_layout(id)
	test_distinct_topology()
	test_challenge_geometry()
	test_native_first_exit()
	test_reservoir_mechanics()
	test_long_vehicle_progress()
	test_optional_motion()
	test_mill_from_ordinary_spawn()
	await process_frame
	print("DISTRICT_ROUTE_METRICS ",JSON.stringify(metrics))
	print("DISTRICT_ROUTES: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
