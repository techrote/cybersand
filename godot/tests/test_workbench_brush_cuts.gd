extends "res://tests/test_workbench_freed.gd"

func fresh(edits: Array) -> bool:
	var recipe: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	recipe.version=4;recipe.edits=edits
	if ui.cut.capture_count>0:
		if not check(host.workbench_restart(recipe,true),"explicit complete owner replacement"): return false
		await scene_changed
		host=current_scene;ui=host.shared_workbench
	else:
		if not check(ui.apply(recipe),"ordinary canvas replacement without live custody"): return false
	host.simulation_worker.set_worker_participation_sampling(true)
	if not check(await until(installed),"fresh ordinary canvas"): return false
	check(ui.step_once(),"ordinary initial Step")
	return check(await until(func():return not ui.step_pending and host.latest_snapshot.tick_index>0),"applied native region")

func erase(point: Vector2i, radius: int, repeated: bool=false) -> bool:
	ui.applied.brush=radius
	check(ui.paint(point,0),"actual erase")
	if repeated: check(ui.paint(point,0),"repeated overlapping dab")
	check(ui.cut.finish_stroke(ui),"normal cut coordinator")
	if not check(await until(installed),"cut finishes: "+ui.message): return false
	evidence.cuts.append({"receipts":ui.cut.receipts.duplicate(true),"message":ui.message})
	return true

func verify_piece(members: int=-1, proxies: int=-1) -> bool:
	if not check(host.rigid_bodies.size()==1,"one aggregate, not cell splinters"): return false
	var prepared: Dictionary={}
	for row: Dictionary in ui.cut.receipts:
		if row.get("phase")==2 and row.get("ok",false): prepared=row
	if not check(not prepared.is_empty(),"copied native ownership payload"): return false
	var body: RigidBody2D=host.rigid_bodies[0]
	check(int(prepared.shape_count)>8,"regression exceeds old eight-shape limit")
	if members>=0: check(int(prepared.member_count)==members,"independent cell-count oracle")
	if proxies>=0: check(int(prepared.shape_count)==proxies,"independent rectangle-count oracle")
	check(body.mass==float(prepared.mass) and is_equal_approx(body.inertia,float(prepared.inertia)),"native M/I retained")
	check(PhysicsServer2D.body_get_shape_count(body.get_rid())==int(prepared.shape_count),"actual exact Rapier collider union")
	check(is_equal_approx(body.gravity_scale,.094) and is_equal_approx(body.linear_damp,.04) and is_equal_approx(body.angular_damp,.04),"gravity and damping unchanged")
	var last: Dictionary=ui.cut.receipts.back()
	check(last.frontier_complete and not last.frontier_limited and (last.discovery_attempts==1 if proxies==64 else last.discovery_attempts>=1),"complete bounded frontier after capture")
	var before: Vector2=body.position
	if not await run_steps(96): return false
	check(body.position.distance_to(before)>.1,"actual unsupported object falls on Play")
	check(host.tower_context.workbench_gcr.response=="LA-SELECTIVE","actual native mode")
	check(host.rapier_bridge.last_application.get("accepted",false),"actual current-roster native/Rapier application")
	evidence.cuts.back().merge({"native":prepared,"position_before":before,"position_after":body.position,"mass":body.mass,"inertia":body.inertia,"application":host.rapier_bridge.last_application.duplicate(true)})
	return true

func run() -> void:
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;ui=host.shared_workbench
	if not check(await until(installed),"normal workbench starts"): finish();return
	if not await fresh([[0,190,512,4,58],[64,74,64,4,58]]): finish();return
	ui.applied.brush=8;check(ui.paint(Vector2i(80,48),43),"default circular crown")
	ui.applied.brush=2
	for y: int in range(56,75):
		check(ui.paint(Vector2i(80,y),43),"paint stem");await create_timer(.025).timeout
	if not await erase(Vector2i(80,66),2) or not await verify_piece(): finish();return
	var last: String=ui.cut.last_disposition
	ui.message="Selection changed"
	check(await until(func():return ui._status.text.begins_with(last)),"cut disposition survives other status messages")
	if not await fresh([[0,190,512,4,58],[64,74,64,4,58]]): finish();return
	ui.applied.brush=6
	for x: int in range(70,91):
		check(ui.paint(Vector2i(x,40+(x-70)/2),43),"sloped brush stroke");await create_timer(.025).timeout
	ui.applied.brush=2
	for y: int in range(56,76):
		check(ui.paint(Vector2i(90,y),43),"paint sloped stem");await create_timer(.025).timeout
	if not await erase(Vector2i(90,68),2) or not await verify_piece(): finish();return
	# Maximum brush: 136 distinct frontier cells, 808 members, 64 exact shapes.
	if not await fresh([[90,90,51,51,43],[0,190,512,4,58],[64,175,128,10,2]]): finish();return
	if not await erase(Vector2i(115,115),24,true) or not await verify_piece(808,64): finish();return
	ui.applied.brush=2;ui.paint(Vector2i(240,80),43)
	if not await erase(Vector2i(240,84),2): finish();return
	check(host.rigid_bodies.size()==1 and ui.cut.capture_count==1,"shared 65th proxy refuses with original owner retained")
	check(ui.cut.last_disposition.contains("64"),"shared proxy capacity is explained")
	if not await run_steps(3): finish();return
	if not await fresh([[40,40,70,3,43],[0,190,512,4,58]]): finish();return
	if not await erase(Vector2i(70,44),2): finish();return
	check(host.rigid_bodies.is_empty() and ui.cut.last_disposition.contains("62-cell"),"oversize connected object retained with visible reason")
	if not await fresh([[90,90,51,51,43],[89,90,1,51,58],[0,190,512,4,58]]): finish();return
	if not await erase(Vector2i(115,115),24): finish();return
	var end: Dictionary=ui.cut.receipts.back()
	check(host.rigid_bodies.is_empty() and end.frontier_limited and not end.frontier_complete and end.discovery_attempts==64,"anchored ring refuses with complete capacity accounting")
	check(ui.cut.last_disposition.contains("discovery incomplete"),"incomplete investigation is not clearance")
	var native_tick: int=host.latest_snapshot.tick_index
	check(ui.step_once(),"ordinary Step after empty-roster refusal")
	check(await until(func():return not ui.step_pending and host.latest_snapshot.tick_index==native_tick+1),"native clock survives bounded refusal")
	evidence["participation"]=host.latest_snapshot.native_worker_participation.duplicate(true)
	evidence["maximum_observed_workers"]=observed_workers
	finish()
