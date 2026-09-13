extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var recipe: PackedInt32Array = CyberExperimentTower.rectangles()
	assert(recipe == CyberDemoWorlds.rectangles("experiment_tower"))
	assert(bridge.build_world(world,recipe))
	var original: PackedByteArray = bridge.export_level(world)
	for y: int in range(20,980,8):
		assert(not world.character_box_collides(Vector2(45,y),Vector2(8,14),0))
	for f: int in range(5):
		var spawn: Vector2 = CyberExperimentTower.landing(f)
		assert(not world.character_box_collides(spawn,Vector2(8,14),0))
		for plug: Rect2i in CyberExperimentTower.plugs(f):
			assert(int(world.material_at(plug.position.x,plug.end.y-1)) == 79)
	# Closed Acid plugs survive actual chemistry, including adjacent-floor work.
	world.set_simulation_window(Vector2i(350,796),Vector2i(160,200),0,0)
	for tick: int in range(180): assert(world.simulation_tick())
	assert(int(world.material_at(400,CyberExperimentTower.floor_y(4)+109))==12)
	assert(int(world.material_at(400,CyberExperimentTower.floor_y(4)+110))==1)
	var acid_plug: Rect2i=CyberExperimentTower.plugs(4)[4]
	for y: int in range(acid_plug.position.y,acid_plug.end.y):
		for x: int in range(acid_plug.position.x,acid_plug.end.x): world.paint_disc(x,y,0,0,0)
	for tick: int in range(360): assert(world.simulation_tick())
	var remaining_metal: int=0
	for y: int in range(976,988):
		for x: int in range(390,456):
			if world.material_at(x,y)==28: remaining_metal+=1
	assert(remaining_metal<66*12,"released Acid must contact the prepared Metal bed")
	assert(bridge.build_world(world,recipe))
	assert(not bridge.build_world(world,PackedInt32Array([1024,0,1,1,2])))
	assert(bridge.export_level(world) == original)
	world.paint_disc(93,118,0,0,0)
	assert(bridge.build_world(world,recipe))
	assert(bridge.export_level(world) == original)
	var owner: CyberSimulationWorker = CyberSimulationWorker.new()
	owner._world = world
	owner.queue_lab({"reset":true,"floor":3})
	assert(owner.start_worker(spawn_for_test()) == OK)
	var deadline: int = Time.get_ticks_msec()+15000
	var snapshot: CyberSimulationSnapshot
	while Time.get_ticks_msec() < deadline:
		await process_frame
		snapshot = owner.take_latest_snapshot(-1)
		if snapshot.lab_context.get("active",false): break
	assert(snapshot.lab_context.get("active",false))
	assert(snapshot.tick_index == 0)
	owner.queue_lab({"step":true})
	await create_timer(0.2).timeout
	snapshot = owner.take_latest_snapshot(-1)
	owner.stop_worker()
	assert(snapshot.tick_index == 1)
	assert(not snapshot.simulation_failed)
	# Retained desktop acknowledgements must not discard a replacement whose
	# new native snapshot exchange starts serial numbering from one again.
	var previous_serial: int = snapshot.render_snapshot_serial
	owner._append_native_render_packet({"serial":1,"channels":2,"full_refresh":true,"cells":PackedByteArray([1,0]),"rectangles":PackedInt32Array([0,0,1,1,0,2])})
	assert(owner._pending_render_snapshot_serial>previous_serial)
	# Load both real controllers; catches script inheritance/scene errors.
	for path: String in ["res://main.tscn","res://web_main.tscn"]:
		var scene: PackedScene = load(path)
		assert(scene != null)
	print("EXPERIMENT_TOWER: deterministic recipe, safe landings, plugs, invalid replacement, exact reset and desktop single-step passed")
	quit()

func spawn_for_test() -> Vector2:
	return CyberExperimentTower.landing(3)
