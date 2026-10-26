extends SceneTree

# A map signature alone missed the former shared layout and blocked starts.
# Check the resulting native-cell raster, deep stores, collision-sized stages
# and initial wheel route, with no pose/velocity assignment or tool shortcut.
const Districts = preload("res://scripts/player_playground_districts.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Setup = preload("res://scripts/player_playground_world.gd")
const Usable = preload("res://scripts/usable_runtime.gd")
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
		expect(clear(cells,Rect2i(300,floor-28,680,28)),
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
	for id: StringName in Course.MAP_IDS:
		var point: Vector2i = Districts.reservoir_outlet(id)
		var cells: PackedByteArray = rasters[id]
		expect(cells[point.y*1024+point.x] == 35 and cells[(point.y-1)*1024+point.x] == 3,
			"visible glass valve is connected to actual reservoir Water "+str(id))
		expect(clear(cells,Rect2i(point+Vector2i(-5,27),Vector2i(10,10))),
			"valve has a clear tool approach from the universal road "+str(id))


func fire_tool(tool, world: Object, index: int, origin: Vector2, aim: Vector2) -> void:
	tool.step(1.0/60.0,world,PackedVector2Array([origin]),[Rect2()],
		[{"usable_index":index,"aim":aim,"trigger":false}])
	tool.step(1.0/60.0,world,PackedVector2Array([origin]),[Rect2()],
		[{"usable_index":index,"aim":aim,"trigger":true,"trigger_pressed":true}])


func test_reservoir_mechanics() -> void:
	for id: StringName in Course.MAP_IDS:
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(world.diagnostic_reset({"workers":1}),"fresh valve apparatus "+str(id))
		var setup: Dictionary = Setup.build(world,id,0)
		expect(setup.accepted,"actual native district constructs for valve test "+str(id))
		if not setup.accepted: continue
		var point: Vector2i = Districts.reservoir_outlet(id)
		var initial: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,768))
		var tool = Usable.new()
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
	var cutter = Usable.new()
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
	for id: StringName in [&"cannon_run",&"rat_steps"]:
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
			metrics[str(id)+"/"+str(player)+"/baseline"] = {"gates":next,"ticks":runtime.tick,
				"position":runtime.observation().position}
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
	runtime.close()
	runtime.free()


func test_distinct_topology() -> void:
	# Exclude the entire ground/start lane and outer boundary. At least 30% of
	# occupied 16-cell architectural bins must differ between every map pair.
	var occupancy: Dictionary = {}
	for id: StringName in Course.MAP_IDS:
		var cells: PackedByteArray = rasters[id]
		var bins: Dictionary = {}
		for y: int in range(32,608,16):
			for x: int in range(16,1008,16):
				var count: int = 0
				for yy: int in range(y,y+16,4):
					for xx: int in range(x,x+16,4): count += int(cells[yy*1024+xx] != 0)
				if count > 1: bins[Vector2i(x,y)] = true
		occupancy[id] = bins
	for i: int in range(Course.MAP_IDS.size()):
		for j: int in range(i+1,Course.MAP_IDS.size()):
			var a: Dictionary = occupancy[Course.MAP_IDS[i]]
			var b: Dictionary = occupancy[Course.MAP_IDS[j]]
			var common: int = 0
			for key: Vector2i in a:
				if b.has(key): common += 1
			var union_count: int = a.size()+b.size()-common
			expect(float(common)/float(union_count) < 0.70,
				"architecture materially differs beyond floors/start: %s/%s overlap %.3f" %
				[Course.MAP_IDS[i],Course.MAP_IDS[j],float(common)/float(union_count)])


func test_native_first_exit() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	# Prove ordinary wheel exits from all eight starts. The complete 336 setup
	# matrix separately covers every player and all six native Water policies.
	for id: StringName in Course.MAP_IDS:
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
	for id: StringName in Course.MAP_IDS: test_layout(id)
	test_distinct_topology()
	test_challenge_geometry()
	test_native_first_exit()
	test_reservoir_mechanics()
	test_long_vehicle_progress()
	test_optional_motion()
	await process_frame
	print("DISTRICT_ROUTE_METRICS ",JSON.stringify(metrics))
	print("DISTRICT_ROUTES: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
