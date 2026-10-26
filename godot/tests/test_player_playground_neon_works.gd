extends SceneTree

const Works = preload("res://scripts/player_playground_neon_works.gd")
const Setup = preload("res://scripts/player_playground_world.gd")
const Catalogue = preload("res://scripts/usable_catalog.gd")
const Field = preload("res://scripts/player_playground_material_field.gd")
var assertions: int = 0
var failures: int = 0
var metrics: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("NEON_WORKS: "+message)


func fire(tool, world: Object, origin: Vector2, aim: Vector2) -> void:
	var index: int = Catalogue.index_for(&"glass_scorer")
	tool.step(1.0/60.0,world,PackedVector2Array([origin]),[Rect2()],
		[{"usable_index":index,"aim":aim,"trigger":false}])
	tool.step(1.0/60.0,world,PackedVector2Array([origin]),[Rect2()],
		[{"usable_index":index,"aim":aim,"trigger":true,"trigger_pressed":true}])


func count(world: Object, box: Rect2i, material: int) -> int:
	var total: int = 0
	for y: int in range(box.position.y,box.end.y):
		for x: int in range(box.position.x,box.end.x):
			if world.material_at(x,y) == material: total += 1
	return total


func test_lateral_reclamation() -> void:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1}),"lateral fixture native owner")
	expect(Setup.build(world,&"last_byte_reclamation",0).accepted,"complete prepared Reclamation layout")
	var initial: int = count(world,Rect2i(6,6,1012,756),2)
	var catch_box := Rect2i(464,344,176,38)
	for tick: int in range(60): expect(world.simulation_tick(),"closed side seal settles")
	expect(count(world,catch_box,2) == 0,"side glass retains Sand before actual use")
	var tool = load("res://scripts/usable_runtime.gd").new()
	tool.configure(1)
	# A player sweeps the one-cell cutting ray across a useful opening. Waiting
	# the real cooldown preserves one actor's charge and activation semantics.
	for y: int in range(324,344):
		for tick: int in range(8):
			tool.step(1.0/60.0,world,PackedVector2Array([Vector2(300,y)]),[Rect2()],
				[{"usable_index":Catalogue.index_for(&"glass_scorer"),"aim":Vector2.LEFT,"trigger":false}])
		fire(tool,world,Vector2(300,y),Vector2.LEFT)
	expect(tool.write_count_last >= 8 and world.material_at(268,332) == 0,
		"real side-directed Glass Scorer opens the entire eight-cell wall")
	var first_crossed: int = 0
	var second_crossed: int = 0
	for tick: int in range(720):
		var anchor := Vector2(minf(500.0,248.0+tick*0.45),minf(366.0,330.0+tick*0.067))
		var field: Dictionary = Field.apply(world,anchor,Vector2.RIGHT,2,1,tick)
		expect(field.accepted,"real Sand player field guides grains through optional side route")
		expect(world.simulation_tick(),"native grains traverse side sorting arcade")
		for y: int in range(318,356):
			if world.material_at(284,y) == 2: first_crossed += 1
		for y: int in range(350,378):
			if world.material_at(460,y) == 2: second_crossed += 1
	var caught: int = count(world,catch_box,2)
	var final: int = count(world,Rect2i(6,6,1012,756),2)
	expect(first_crossed > 0 and second_crossed > 0 and caught > 0,
		"actual finite Sand crosses both lateral apertures and reaches the real catch")
	expect(final == initial,"the side challenge transports its exact original Sand inventory")
	metrics.reclamation = {"original_sand":initial,"after_first":count(world,Rect2i(272,300,54,78),2),
		"after_middle":count(world,Rect2i(338,300,112,90),2),"first_aperture_samples":first_crossed,
		"second_aperture_samples":second_crossed,"caught_sand":caught,"final_sand":final}


func test_vented_exchange() -> void:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1}),"exchange fixture native owner")
	expect(Setup.build(world,&"rain_ledger_exchange",0).accepted,"complete prepared Exchange layout")
	var catch_box := Rect2i(441,440,246,136)
	var initial: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,768))
	expect(count(world,catch_box,3) == 0,"registered catch starts visibly empty")
	var tool = load("res://scripts/usable_runtime.gd").new()
	tool.configure(1)
	fire(tool,world,Vector2(542,354),Vector2.UP)
	expect(tool.write_count_last >= 7 and world.material_at(542,324) == 0,
		"actual optional branch valve opens independently of the road valve")
	var upper_branch: int = 0
	var lower_branch: int = 0
	for tick: int in range(1500):
		expect(world.simulation_tick(),"vented step channels run actual Current Water")
		for x: int in range(524,676):
			if world.material_at(x,372) == 3: upper_branch += 1
		for x: int in range(596,726):
			if world.material_at(x,408) == 3: lower_branch += 1
	var caught: int = count(world,catch_box,3)
	var final: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,768))
	expect(upper_branch > 0 and lower_branch > 0 and caught > 0,
		"source-matched native Water traverses both open steps into the shared catch")
	expect(final.water_integer == initial.water_integer,"vented branches preserve exact native Water quantity")
	metrics.exchange = {"upper_branch_samples":upper_branch,"lower_branch_samples":lower_branch,
		"branch_below":count(world,Rect2i(520,332,220,105),3),
		"caught_water_cells":caught,"initial_water_integer":initial.water_integer,"water_integer":final.water_integer}


func test_customs_cargo_route() -> void:
	var runtime = load("res://scripts/player_playground_runtime.gd").new()
	root.add_child(runtime)
	for player: StringName in [&"stuntbuggy",&"trialsbike"]:
		expect(runtime.configure(player,&"zero_stamp_customs"),"complete Customs rig and three real props construct")
		var gates: PackedVector2Array = Works.checkpoints(&"zero_stamp_customs")
		var next: int = 0
		for tick: int in range(1500):
			runtime.submit_action({"move":Vector2.UP})
			runtime.step()
			if next < gates.size() and Vector2(runtime.observation().position).distance_to(gates[next]) <= 15.0: next += 1
			if next == gates.size() or runtime.failed: break
		expect(not runtime.failed and next == gates.size(),
			"real mounted wheel rig completes every Customs gate while all three loose props simulate "+str(player))
		expect(absf(float(runtime.observation().rotation)) < 0.8,"Customs vehicle finishes upright")
		metrics["customs/"+str(player)] = {"gates":next,"ticks":runtime.tick,"position":runtime.observation().position}
	runtime.close()
	runtime.free()


func run() -> void:
	test_lateral_reclamation()
	test_vented_exchange()
	test_customs_cargo_route()
	await process_frame
	print("NEON_WORKS_METRICS ",JSON.stringify(metrics))
	print("NEON_WORKS: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
