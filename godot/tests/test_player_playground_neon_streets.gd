extends SceneTree

const Maps = preload("res://scripts/player_playground_neon_streets.gd")
var assertions: int = 0
var failures: int = 0
var metrics: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool,message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("NEON_STREETS: "+message)


func raster(id: StringName) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(1024*768)
	for row: Dictionary in Maps.layout(id):
		for y: int in range(row.origin.y,row.origin.y+row.size.y):
			for x: int in range(row.origin.x,row.origin.x+row.size.x): result[y*1024+x] = row.material
	return result


func empty(cells: PackedByteArray,box: Rect2i) -> bool:
	if not Maps.VIEW.encloses(box): return false
	for y: int in range(box.position.y,box.end.y):
		for x: int in range(box.position.x,box.end.x):
			if cells[y*1024+x] != 0: return false
	return true


func test_static() -> void:
	for id: StringName in Maps.IDS:
		var cells: PackedByteArray = raster(id)
		expect(empty(cells,Rect2i(56,Maps.floor_y(id)-112,232,112)),"protected universal start "+str(id))
		var first_block := Vector2i(-1,-1)
		for x: int in range(48,1014):
			var floor: int = Maps.road_y(id,x)
			for y: int in range(floor-28,floor):
				if cells[y*1024+x] != 0 and first_block.x < 0: first_block = Vector2i(x,y)
		expect(first_block.x < 0,"full road28-clear "+str(id)+" first obstruction"+str(first_block))
		for prop: Dictionary in Maps.props(id):
			var box := Rect2i(Vector2i(prop.position-prop.size*0.5),Vector2i(prop.size))
			expect(empty(cells,box),"clear actual cargo stage "+str(id)+str(box))
			var supported: bool = false
			for y: int in range(box.end.y,box.end.y+13):
				if cells[y*1024+int(prop.position.x)] != 0: supported = true
			expect(supported,"heavy cargo has close real support off baseline "+str(id)+str(box))
		for point: Vector2 in Maps.npc_spawns(id):
			expect(empty(cells,Rect2i(Vector2i(point)-Vector2i(24,24),Vector2i(48,48))),"full NPC stage "+str(id)+str(point))
		var counts: Array[int] = []
		for store: Dictionary in Maps.reservoirs(id):
			var count: int = 0
			for y: int in range(store.bounds.position.y,store.bounds.end.y):
				for x: int in range(store.bounds.position.x,store.bounds.end.x): count += int(cells[y*1024+x] == store.material)
			expect(count >= 16000,"actual substantial reservoir "+str(id)+str(count))
			counts.append(count)
		var outlet: Vector2i = Maps.reservoir_outlet(id)
		expect(cells[outlet.y*1024+outlet.x] == 35 and cells[(outlet.y-1)*1024+outlet.x] == 3,"actual Water meets glass valve "+str(id))
		expect(empty(cells,Rect2i(outlet+Vector2i(-5,27),Vector2i(10,10))),"ordinary glass-scorer approach "+str(id))
		metrics[str(id)] = {"rectangles":Maps.layout(id).size(),"store_cells":counts}
	var arcade: PackedByteArray = raster(&"afterhours_arcade")
	expect(empty(arcade,Rect2i(476,546,90,12)) and empty(arcade,Rect2i(626,546,78,12)),"two real twelve-cell compact passages")
	expect(empty(arcade,Rect2i(566,514,60,44)),"standing repair bay links both compact passages")


func physical_extent(runtime) -> Rect2:
	var result := Rect2()
	var first: bool = true
	for part: Dictionary in runtime.render_parts():
		if int(part.get("actor_id",0)) != 0: continue
		var pose: Transform2D = part.transform
		var half: Vector2 = part.size*0.5
		for corner: Vector2 in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]:
			var point: Vector2 = pose*corner
			result = Rect2(point,Vector2.ZERO) if first else result.expand(point)
			first = false
	return result


func test_real_features() -> void:
	# Runtime is loaded at use. There is no eager import of the base Usable owner
	# into the Arena/Runtime preload graph (the retained cleanup-diamond defect).
	var runtime = load("res://scripts/player_playground_runtime.gd").new()
	root.add_child(runtime)
	expect(runtime.configure(&"stuntbuggy",&"debtline_interchange"),"ordinary native Debtline owner constructs")
	var jumped: bool = false
	var airborne: bool = false
	var landed: bool = false
	var launch := Vector2.ZERO
	for tick: int in range(1600):
		var view: Dictionary = runtime.observation()
		var hop: bool = not jumped and view.position.x >= 710 and view.position.x < 724 and view.grounded
		if hop:
			jumped = true
			launch = view.position
		runtime.submit_action({"move":Vector2.UP,"primary":hop})
		runtime.step()
		view = runtime.observation()
		if jumped and not view.grounded: airborne = true
		if jumped and view.position.x >= 760 and view.position.x < 840 and view.grounded:
			landed = true
			break
	expect(not runtime.failed and jumped and airborne and landed,"ordinary-spawn buggy hop clears crest and recovers at striped road")
	metrics["debtline_hop"] = {"jumped":jumped,"airborne":airborne,"landed":landed,"launch":launch,"position":runtime.observation().position,"ticks":runtime.tick}
	expect(runtime.configure(&"trialsbike",&"patchbay_tenements"),"ordinary native Patchbay owner constructs")
	var charging: bool = false
	var charge_ticks: int = 0
	var released: bool = false
	airborne = false
	landed = false
	launch = Vector2.ZERO
	for tick: int in range(1600):
		var view: Dictionary = runtime.observation()
		if not charging and not released and view.position.x >= 604 and view.grounded: charging = true
		var hold: bool = charging and charge_ticks < 26
		if charging and not hold:
			released = true
			charging = false
			launch = view.position
		if hold: charge_ticks += 1
		runtime.submit_action({"move":Vector2.UP,"primary":hold})
		runtime.step()
		view = runtime.observation()
		if released and not view.grounded: airborne = true
		if released and view.position.x >= 700 and view.position.x < 752 and view.grounded:
			landed = true
			break
	expect(not runtime.failed and released and airborne and landed,"ordinary-spawn charged bike transfers across shallow court onto broad landing")
	metrics["patchbay_transfer"] = {"released":released,"charge_ticks":charge_ticks,"airborne":airborne,"landed":landed,"launch":launch,"position":runtime.observation().position,"ticks":runtime.tick}
	expect(runtime.configure(&"acrobat",&"afterhours_arcade"),"ordinary native Afterhours owner constructs")
	var jump_at: int = -1
	var entry: bool = false
	var first_duct: bool = false
	var standing_bay: bool = false
	var second_duct: bool = false
	var exited: bool = false
	var maximum_compact_height: float = 0.0
	var standing_height: float = 0.0
	var bay_pause_ticks: int = -1
	for tick: int in range(2200):
		var view: Dictionary = runtime.observation()
		if jump_at < 0 and view.position.x >= 388 and view.position.x < 400 and view.grounded: jump_at = tick
		var age: int = tick-jump_at if jump_at >= 0 else -1
		var primary: bool = age >= 0 and age != 25 and not entry
		if view.position.x > 458 and view.position.x < 476 and view.grounded and view.position.y < 558: entry = true
		if bay_pause_ticks < 0 and view.position.x >= 584 and view.position.x < 604 and entry: bay_pause_ticks = 0
		var pause: bool = bay_pause_ticks >= 0 and bay_pause_ticks < 90
		if bay_pause_ticks >= 0: bay_pause_ticks += 1
		# A real hop unloads the articulated feet after slide contact. This
		# records an explicit player action, not automatic neutral unfolding.
		if pause and bay_pause_ticks >= 30 and bay_pause_ticks < 72: primary = true
		var crouch: bool = entry and (view.position.x < 578 or view.position.x > 602)
		runtime.submit_action({"move":Vector2.ZERO if pause else Vector2.RIGHT,"primary":primary,"secondary":crouch,"auxiliary":pause and bay_pause_ticks < 30})
		runtime.step()
		view = runtime.observation()
		var bounds: Rect2 = physical_extent(runtime)
		if view.position.x > 490 and view.position.x < 552 and view.position.y < 558:
			first_duct = true
			maximum_compact_height = maxf(maximum_compact_height,bounds.size.y)
		if view.position.x > 584 and view.position.x < 600 and view.position.y < 558:
			standing_height = maxf(standing_height,bounds.size.y)
			if bounds.size.y > 12.5 and view.grounded: standing_bay = true
		if view.position.x > 640 and view.position.x < 692 and view.position.y < 558:
			second_duct = true
			maximum_compact_height = maxf(maximum_compact_height,bounds.size.y)
		if entry and bounds.position.x > 720 and view.position.y < 558:
			exited = true
			break
		if runtime.failed: break
	expect(not runtime.failed and entry and first_duct and standing_bay and second_duct and exited and maximum_compact_height <= 12.5,
		"ordinary-spawn running double jump traverses both ducts, with a real posture-reset hop and grounded standing in repair bay")
	metrics["afterhours_service"] = {"jump_at":jump_at,"entry":entry,"first_duct":first_duct,"standing_bay":standing_bay,"standing_height":standing_height,"second_duct":second_duct,"exited":exited,"compact_height":maximum_compact_height,"position":runtime.observation().position,"ticks":runtime.tick}
	runtime.close()
	runtime.free()


func run() -> void:
	var started: int = Time.get_ticks_msec()
	test_static()
	if "--static-only" not in OS.get_cmdline_user_args(): test_real_features()
	await process_frame
	print("NEON_STREET_METRICS ",JSON.stringify(metrics))
	print("NEON_STREET_SECONDS ",float(Time.get_ticks_msec()-started)/1000.0)
	print("NEON_STREETS: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
