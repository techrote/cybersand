extends "res://tests/test_workbench_rectangle_core.gd"

var templates: Dictionary={}
var current_rows: Array=[]

func open_empty() -> bool:
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;ui=host.shared_workbench
	return check(await until(installed),"fresh authoritative World")

func rows_from_tuples(values: PackedInt32Array, material: int) -> Array:
	var result: Array=[];var i: int=0
	while i<values.size():
		var end: int=i+6
		while end<values.size() and values[end+1]==values[i+1] and values[end]==values[end-6]+1: end+=6
		result.append([values[i],values[i+1],(end-i)/6,1,material]);i=end
	return result

func derive(building: bool, bed: String) -> bool:
	if not await open_empty(): return false
	var recipe: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	recipe.version=4;recipe.edits=[[0,72,512,4,58],[32,68,64,4,2]]
	if bed=="mixed": recipe.edits.append([64,68,32,4,3])
	structure(recipe,0,building)
	check(ui.apply(recipe),"original native structural map")
	if not check(await until(installed),"source installed"): return false
	check(ui.step_once(),"explicit source-region Step before any body exists")
	if not check(await until(func():return not ui.step_pending and host.latest_snapshot.tick_index>0),"source eligible"): return false
	ui.applied.brush=2
	for x: int in range(50,54): check(ui.paint(Vector2i(x,67),0),"genuine stem erase")
	check(ui.cut.finish_stroke(ui),"genuine current native cut")
	if not check(await until(installed),"source cut completes"): return false
	var prepared: Dictionary={}
	for row: Dictionary in ui.cut.receipts:
		if row.get("ok",false) and row.get("phase")==2 and row.get("rectangle_core",false): prepared=row
	if not check(not prepared.is_empty(),"real native core/fringe witness"): return false
	check(prepared.source_member_count==(356 if building else 520) and prepared.member_count==(152 if building else 208),"original/full retained counts")
	var witness: Dictionary=await material_census()
	var key: String=("building" if building else "tree")+"/"+bed
	templates[key]={"recipe":ui.applied.duplicate(true),"prepared":prepared.duplicate(true),"source_map":witness,
		"receipts":ui.cut.receipts.duplicate(true),"source_tick":host.latest_snapshot.tick_index}
	return true

func arm_recipe(key: String, arm: String) -> Dictionary:
	var recipe: Dictionary=templates[key].recipe.duplicate(true)
	var prepared: Dictionary=templates[key].prepared
	if arm=="all_sand":
		recipe.actors=[];recipe.selected=0
		var rects: PackedInt32Array=prepared.rectangles
		for i: int in range(0,rects.size(),4): recipe.edits.append([rects[i],rects[i+1],rects[i+2],rects[i+3],2])
	elif arm=="core_only": recipe.edits.append_array(rows_from_tuples(prepared.fringe,0))
	return recipe

func state() -> Dictionary:
	var snapshot=host.latest_snapshot
	var result: Dictionary={"tick":snapshot.tick_index,"native_ms":snapshot.simulation_time_ms,"owner_ms":snapshot.worker_step_time_ms,
		"world_generation":snapshot.render_world_generation,"failed":host.simulation_worker.has_failed(),"body":null}
	if host.physical_actor_session!=null:
		var body: RigidBody2D=host.rigid_bodies[0];var rid: RID=body.get_rid()
		var pose: Transform2D=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
		var velocity: Vector2=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		var omega: float=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
		result.body={"pose":pose,"velocity":velocity,"omega":omega,"mass":body.mass,"inertia":body.inertia,
			"kinetic_proxy":.5*float(body.mass)*(float(velocity.x)*float(velocity.x)+float(velocity.y)*float(velocity.y))+.5*float(body.inertia)*omega*omega,
			"potential_proxy":-float(body.mass)*92.12*float(pose.origin.y),"session":host.rapier_bridge._session,"epoch":host._physical_epoch,
			"steps":host.rapier_bridge.manual_step_count(),"application":host.rapier_bridge.last_application.duplicate(true),
			"native_rows":host.tower_context.get("workbench_gcr",{}).get("rows",[]).duplicate(true)}
	return result

func final_map() -> Dictionary:
	ui.cut.panel=ui
	var sample: Dictionary={} if host.physical_actor_session==null else host.rapier_bridge.pack_held_sample()
	check((await ui.cut._rpc({"action":"begin","dabs":PackedInt32Array([350,350,2]),"sample":sample})).get("ok",false),"paused material observer hold")
	var map: Dictionary={}
	for by: int in [0,64]:
		for bx: int in [0,64]:
			var census: Dictionary=await ui.cut._rpc({"action":"census","area":Rect2i(bx,by,64,64)})
			check(census.get("ok",false),"authoritative material window")
			var values: PackedInt32Array=census.get("pixels",PackedInt32Array())
			for i: int in range(0,values.size(),3): map[Vector2i(values[i],values[i+1])]=values[i+2]
	check((await ui.cut._end()).get("ok",false),"material observer closes")
	return map

func one(key: String, arm: String, repeat: int) -> bool:
	if not await open_empty(): return false
	var recipe: Dictionary=arm_recipe(key,arm);var prepared: Dictionary=templates[key].prepared
	check(Setup.validate(recipe).is_empty(),"ordinary authored representation admitted")
	check(ui.apply(recipe),"fresh post-cut reconstruction")
	if not check(await until(installed),"fresh actor/material state ready"): return false
	host.simulation_worker.set_worker_participation_sampling(true)
	var initial_map: Dictionary=await replay_image_census()
	var source: Dictionary=expected_source(key.begins_with("building"))
	var rect: PackedInt32Array=prepared.rectangles;var core:=Rect2i(rect[0],rect[1],rect[2],rect[3])
	for point: Vector2i in source:
		check(initial_map.get(point)==(2 if arm=="all_sand" or (arm=="core_sand" and not core.has_point(point)) else 0),"exact initial core/fringe/source material")
	for y: int in [70,71]:
		for x: int in range(50,54): check(initial_map.get(Vector2i(x,y))==43,"original anchored stump preserved")
	check(host.rigid_bodies.size()==(0 if arm=="all_sand" else 1),"one core or no rigid body")
	if arm!="all_sand":
		var body: RigidBody2D=host.rigid_bodies[0]
		check(body.mass==prepared.mass and is_equal_approx(body.inertia,float(prepared.inertia)),"same native-derived core mass/inertia")
		check(is_equal_approx(body.gravity_scale,.094) and is_equal_approx(body.linear_damp,.04) and PhysicsServer2D.body_get_shape_count(body.get_rid())==1,"unchanged core physics and one collider")
	var initial: Dictionary=state();var trace: Array=[]
	for step: int in range(120):
		var tick: int=host.latest_snapshot.tick_index
		var steps: int=0 if host.physical_actor_session==null else host.rapier_bridge.manual_step_count()
		check(ui.step_once(),"single common1/60 native quantum")
		if not check(await until(func():return not ui.step_pending and host.latest_snapshot.tick_index>tick),"completed simulation step"): return false
		check(host.latest_snapshot.tick_index==tick+1,"exact native observation coverage")
		if arm!="all_sand": check(host.rapier_bridge.manual_step_count()==steps+1,"one real Rapier step per native quantum")
		trace.append(state())
	var result: Dictionary={"key":key,"arm":arm,"repeat":repeat,"initial":initial,"trace":trace,"final":state(),
		"initial_map":initial_map,"final_map":await final_map(),"recipe":recipe,"core_rect":Array(rect),
		"source_cells":int(prepared.source_member_count),"rigid_cells":0 if arm=="all_sand" else int(prepared.member_count),
		"converted_sand":int(prepared.source_member_count) if arm=="all_sand" else (int(prepared.fringe_count) if arm=="core_sand" else 0),
		"discarded":int(prepared.fringe_count) if arm=="core_only" else 0,"native_archive":false}
	evidence.cuts.append(result)
	return true

func run() -> void:
	Engine.max_fps=120
	var spot: bool=OS.get_environment("CYBERSAND_OUTCOMES_SPOT")=="1"
	var beds: Array=["packed_sand"] if spot else ["packed_sand","mixed"]
	for building: bool in [false,true]:
		for bed: String in beds:
			if not await derive(building,bed): finish();return
	for key: String in templates:
		for arm: String in ["core_sand","all_sand","core_only"]:
			for repeat: int in range(1 if spot else 5):
				print("CUT_OUTCOME ",key," ",arm," ",repeat)
				if not await one(key,arm,repeat): finish();return
	evidence["templates"]=templates;evidence["maximum_observed_workers"]=observed_workers
	finish()
