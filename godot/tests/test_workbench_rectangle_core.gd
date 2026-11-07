extends "res://tests/test_workbench_freed.gd"

func material_census() -> Dictionary:
	ui.cut.panel=ui
	var sample: Dictionary={} if host.physical_actor_session==null else host.rapier_bridge.pack_held_sample()
	var begin: Dictionary=await ui.cut._rpc({"action":"begin","dabs":PackedInt32Array([350,350,2]),"sample":sample})
	if not check(begin.get("ok",false),"paused census owner hold"): return {}
	var result: Dictionary=await ui.cut._rpc({"action":"census","area":Rect2i(32,16,64,64)})
	check(result.get("ok",false),"copied authoritative census")
	var end: Dictionary=await ui.cut._end();check(end.get("ok",false),"census retires with fresh sample")
	var map: Dictionary={};var values: PackedInt32Array=result.get("pixels",PackedInt32Array())
	for i: int in range(0,values.size(),3): map[Vector2i(values[i],values[i+1])]=values[i+2]
	return map

func expected_source(building: bool) -> Dictionary:
	var recipe: Dictionary={"edits":[]};structure(recipe,0,building)
	var cells: Dictionary={}
	for r: Array in recipe.edits:
		for y: int in range(r[1],r[1]+r[3]):
			for x: int in range(r[0],r[0]+r[2]):
				if r[4]==43: cells[Vector2i(x,y)]=true
				else: cells.erase(Vector2i(x,y))
	for cx: int in range(50,54):
		for dy: int in range(-2,3):
			for dx: int in range(-2,3):
				if dx*dx+dy*dy<=4: cells.erase(Vector2i(cx+dx,67+dy))
	var found: Dictionary={Vector2i(51,34):true};var queue: Array[Vector2i]=[Vector2i(51,34)]
	var cursor: int=0
	while cursor<queue.size():
		var point: Vector2i=queue[cursor];cursor+=1
		for delta: Vector2i in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var next: Vector2i=point+delta
			if cells.has(next) and not found.has(next): found[next]=true;queue.append(next)
	return found

func fresh(building: bool, bed: bool) -> bool:
	var recipe: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	recipe.version=4;recipe.edits=[[0,72,512,4,58]]
	if bed: recipe.edits.append([32,68,64,4,2])
	structure(recipe,0,building)
	if building:
		recipe.actors=[Setup.instance(Setup.BARREL,1,Vector2(400,32))];recipe.next_id=2
	if ui.cut.capture_count>0:
		check(host.workbench_restart(recipe,true),"whole-owner fresh replacement");await scene_changed
		host=current_scene;ui=host.shared_workbench
	else: check(ui.apply(recipe),"ordinary source recipe")
	if not check(await until(installed),"source installed"): return false
	check(ui.cut.rectangle_core,"normal workbench selects new core rule")
	host.simulation_worker.set_worker_participation_sampling(true)
	check(ui.step_once(),"apply native region")
	return check(await until(func():return not ui.step_pending and host.latest_snapshot.tick_index>0),"native region applied")

func release(building: bool, refuse: bool=false) -> bool:
	var tick: int=host.latest_snapshot.tick_index
	var generation: int=host.latest_snapshot.render_world_generation
	var old: RigidBody2D=host.rigid_bodies[0] if building else null
	var rid: RID=old.get_rid() if old!=null else RID()
	var motion: Array=[old.transform,old.linear_velocity,old.angular_velocity] if old!=null else []
	ui.applied.brush=2
	for x: int in range(50,54): check(ui.paint(Vector2i(x,67),0),"ordinary support erase")
	if refuse:
		while ui.applied.edits.size()<Setup.MAX_STAMPS: ui.applied.edits.append([350,350,1,1,0])
	check(ui.cut.finish_stroke(ui),"ordinary cut completion")
	if not check(await until(installed),"cut transaction finishes"): return false
	var rows: Array=ui.cut.receipts.duplicate(true)
	check(host.latest_snapshot.tick_index==tick and host.latest_snapshot.render_world_generation==generation,"same World and no hidden tick")
	var source: Dictionary=expected_source(building)
	check(source.size()==(356 if building else 520),"independent brush/flood source reconstruction")
	var map: Dictionary=await material_census()
	if refuse:
		check(host.physical_actor_session==null and ui.cut.capture_count==0,"recipe capacity cancels before body activation")
		for point: Vector2i in source: check(map.get(point)==43,"precommit refusal preserves complete source")
		evidence.refused_strokes.append({"receipts":rows,"message":ui.message});return true
	var core:=Rect2i(50,27,4,38) if building else Rect2i(44,27,16,13)
	var expected: int=152 if building else 208
	var prepared: Dictionary={};var committed: Dictionary={}
	for row: Dictionary in rows:
		if row.get("phase")==2 and row.get("ok",false): prepared=row
		if row.get("phase")==4 and row.get("ok",false): committed=row
	if not check(prepared.get("rectangle_core",false),"native applied core mode"): return false
	check(prepared.source_member_count==source.size() and prepared.member_count==expected and prepared.fringe_count==source.size()-expected,"full/core/fringe receipt")
	check(prepared.rectangles==PackedInt32Array([core.position.x,core.position.y,core.size.x,core.size.y]),"independent maximal rectangle oracle")
	check(committed.get("aggregate_owned")==expected and committed.get("fringe_converted_count")==source.size()-expected and committed.get("native_fringe_sand")==source.size()-expected,"actual native custody and Sand ledger")
	for point: Vector2i in source: check(map.get(point)==(0 if core.has_point(point) else 2),"independent per-cell core/Sand authority")
	check(map.get(Vector2i(60,32) if not building else Vector2i(60,35))==0,"original hole stays Empty")
	var body: RigidBody2D=host.rigid_bodies.back()
	check(body.mass==expected and PhysicsServer2D.body_get_shape_count(body.get_rid())==1,"one core body and one collider")
	check(is_equal_approx(body.inertia,float(expected)*(core.size.x*core.size.x+core.size.y*core.size.y)/12),"retained-cell inertia")
	check(is_equal_approx(body.gravity_scale,.094) and is_equal_approx(body.linear_damp,.04) and is_equal_approx(body.angular_damp,.04),"unchanged gravity/damping")
	if old!=null:
		check(old.get_rid()==rid and [old.transform,old.linear_velocity,old.angular_velocity]==motion,"existing actor retains RID and motion")
	var before: Vector2=body.position
	if not await run_steps(120): return false
	check(body.position.distance_to(before)>.1 and body.position.is_finite() and body.linear_velocity.is_finite(),"unpowered core falls/collides with finite state")
	check(host.rapier_bridge.last_application.get("accepted",false) and host.tower_context.workbench_gcr.response=="LA-SELECTIVE","actual unchanged law and current-roster application")
	var rendered: Array=host.physical_actor_session.render_parts().filter(func(part: Dictionary):return part.actor_id==(1 if building else 0))
	check(rendered.size()==1 and rendered[0].shape=="material","one carried brick image per core")
	evidence.cuts.append({"building":building,"receipts":rows,"timings":ui.cut.timings.duplicate(true),"core":core,"source_count":source.size(),"core_count":expected,"fringe_count":source.size()-expected,"position_before":before,"position_after":body.position,"application":host.rapier_bridge.last_application.duplicate(true)})
	var name: String="rectangle-core-qualification-"+OS.get_environment("CYBERSAND_FREED_WORKERS")
	check(Setup.write_named(name,ui.applied).is_empty(),"ordinary Save")
	var saved: Dictionary=Setup.read_named(name)
	check(saved.has("setup") and saved.setup.actors.back().hash==ui.applied.actors.back().hash,"disk recipe authenticates core and material")
	check(ui.restore_start(),"ordinary Restore replaces complete owner");await scene_changed
	host=current_scene;ui=host.shared_workbench
	if not check(await until(installed),"fresh authored replay"): return false
	map=await material_census()
	for point: Vector2i in source: check(map.get(point)==(0 if core.has_point(point) else 2),"Restore has exactly core plus native Sand, no duplicate brick")
	check(host.rigid_bodies.back().mass==expected and host.rapier_bridge.manual_step_count()==0,"fresh body retains core mass without warm step")
	return true

func run() -> void:
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;ui=host.shared_workbench
	if not check(await until(installed),"normal workbench starts"): finish();return
	for building: bool in [false,true]:
		for bed: bool in [false,true]:
			if not await fresh(building,bed) or not await release(building): finish();return
	if await fresh(false,false): await release(false,true)
	evidence["maximum_observed_workers"]=observed_workers
	finish()
