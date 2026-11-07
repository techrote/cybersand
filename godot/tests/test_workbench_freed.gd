extends SceneTree

const Setup=preload("res://scripts/workbench_setup.gd")
var host: Control
var ui
var checks: int=0
var failures: Array[String]=[]
var evidence: Dictionary={"cuts":[],"refused_strokes":[]}
var observed_workers: int=0

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",int(OS.get_environment("CYBERSAND_FREED_WORKERS")))
	run.call_deferred()

func check(ok: bool, why: String) -> bool:
	checks+=1
	if not ok: failures.append(why);push_error("WORKBENCH_FREED "+why)
	return ok

func until(predicate: Callable) -> bool:
	var deadline: int=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		if host!=null and host.latest_snapshot!=null:
			observed_workers=maxi(observed_workers,int(host.latest_snapshot.native_worker_participation.get("workers_observed",0)))
		if predicate.call(): return true
		if host!=null and host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func installed() -> bool:
	return ui!=null and not ui.applied.is_empty() and not ui.busy() and host.pending_microscenario_apply.is_empty()

func structure(recipe: Dictionary, offset: int, building: bool) -> void:
	var rectangles: Array=[[50,27,23,4],[50,31,4,13],[69,31,4,13],[50,44,23,4],[50,48,4,24]] if building else [[50,40,4,32],[44,27,29,13],[54,40,11,4]]
	for rect: Array in rectangles: recipe.edits.append([rect[0]+offset,rect[1],rect[2],rect[3],43])
	if not building: recipe.edits.append([60+offset,32,1,1,0])

func event_at(cell: Vector2, pressed: bool, motion: bool=false) -> void:
	var area: Rect2=host.view_content_rect()
	var point: Vector2=area.position+(cell-Vector2(host.camera_origin)+Vector2(0.5,0.5))*area.size/Vector2(host.current_view_size)
	if motion:
		var event:=InputEventMouseMotion.new();event.position=point
		ui._world_input(event)
	else:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=pressed
		ui._world_input(event)

func cut(offset: int, members: int, proxies: int) -> bool:
	var generation: int=host.latest_snapshot.render_world_generation
	var steps: int=host.rapier_bridge.manual_step_count()
	var old_rids: Array[RID]=[]
	var old_values: Array=[]
	for body: RigidBody2D in host.rigid_bodies if host.physical_actor_session!=null else []:
		old_rids.append(body.get_rid())
		old_values.append([PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM),PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY),PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY),body.mass,body.inertia])
	ui.applied.brush=2
	event_at(Vector2(50+offset,67),true)
	for x: int in range(51,54): event_at(Vector2(x+offset,67),true,true)
	event_at(Vector2(53+offset,67),false)
	if not check(await until(installed),"ordinary cut completes: "+ui.message): return false
	evidence.cuts.append({"receipts":ui.cut.receipts.duplicate(true),"message":ui.message})
	if not check(host.physical_actor_session!=null and not host.rigid_bodies.is_empty(),"cut creates an actual owner: "+ui.message): return false
	check(host.paused,"paused state retained")
	check(host.latest_snapshot.render_world_generation==generation,"same native World generation")
	check(host.rapier_bridge.manual_step_count()==(steps if old_rids.size()>0 else 0),"no hidden physical step")
	var prepared: Dictionary={};var committed: Dictionary={}
	for receipt: Dictionary in ui.cut.receipts:
		if receipt.get("member_count")==members and receipt.get("members",PackedInt32Array()).size()>0 and receipt.get("phase")==2: prepared=receipt
		if receipt.get("phase")==4 and receipt.get("ok",false): committed=receipt
	if not check(not prepared.is_empty() and prepared.get("shape_count")==proxies,"exact original member and proxy counts"): return false
	if not check(not committed.is_empty() and committed.get("native_source_members",-1)==0 and committed.get("aggregate_owned")==members,"single authoritative native retirement"): return false
	var body: RigidBody2D=host.rigid_bodies.back()
	check(body.mass==members and PhysicsServer2D.body_get_shape_count(body.get_rid())==proxies,"one real compound body")
	check(is_equal_approx(body.inertia,float(prepared.get("inertia",-1))),"actual native inertia retained")
	check(is_equal_approx(body.gravity_scale,.094) and is_equal_approx(body.linear_damp,.04) and is_equal_approx(body.angular_damp,.04),"unchanged gravity and damping")
	for slot: int in old_rids.size():
		var rid: RID=host.rigid_bodies[slot].get_rid()
		check(rid==old_rids[slot],"old RID retained")
		check(PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)==old_values[slot][0],"old pose retained")
		check(PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)==old_values[slot][1] and PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)==old_values[slot][2],"old motion retained")
		check(host.rigid_bodies[slot].mass==old_values[slot][3] and host.rigid_bodies[slot].inertia==old_values[slot][4],"old M/I retained")
	evidence.cuts.back().merge({"body_rid":str(body.get_rid().get_id()),"retained_rids":old_rids.map(func(rid: RID):return str(rid.get_id())),"retained_values":old_values,
		"mass":body.mass,"inertia":body.inertia,"world_generation":generation,"manual_steps":host.rapier_bridge.manual_step_count(),"proxy_count":proxies})
	return true

func run_steps(count: int) -> bool:
	var target: int=host.rapier_bridge.manual_step_count()+count
	var fresh: int=host._workbench_wait_sample
	var cut_wait: bool=host._workbench_cut_wait
	var first: int=host.rapier_bridge.manual_step_count()+1
	check(ui.toggle_pause(),"unpause existing controls")
	if not check(await until(func():return host.rapier_bridge.manual_step_count()>=first),"first physical step completes after fresh native result"): return false
	if cut_wait:
		check(host.rapier_bridge.last_application.get("accepted",false),"first post-cut step applies a current-roster response")
		for row: Dictionary in host.rapier_bridge.last_application.get("bodies",[]):
			check(row.get("sample")==fresh and not row.has("refusal"),"first post-cut application uses the fresh sample")
	if not check(await until(func():return host.rapier_bridge.manual_step_count()>=target),"native/Rapier completed-sample fence advances"): return false
	check(ui.toggle_pause(),"pause existing controls")
	return true

func run() -> void:
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;ui=host.shared_workbench
	host.simulation_worker.set_worker_participation_sampling(true)
	if not check(await until(installed),"normal workbench starts"): finish();return
	ui.cut.rectangle_core=false # Preserve original whole-tree/building control.
	var recipe: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	recipe.version=4
	recipe.edits=[[0,72,512,4,58],[32,68,64,4,2],[160,68,32,4,2],[192,68,32,4,3]]
	structure(recipe,0,false);structure(recipe,128,true)
	check(Setup.validate(recipe).is_empty(),"version4 exact native authoring recipe")
	check(ui.apply(recipe),"normal canvas apply")
	if not check(await until(installed),"canvas owner installed"): finish();return
	check(ui.step_once(),"ordinary initial Step applies live region eligibility")
	if not check(await until(func():return not ui.step_pending and host.latest_snapshot.tick_index>0),"source region is applied before cutting"): finish();return
	var menu_items: int=ui._model.item_count
	if not await cut(0,520,6): finish();return
	await create_timer(.1).timeout
	var before_step: int=host.rapier_bridge.manual_step_count()
	var before_native: int=host.latest_snapshot.tick_index
	check(ui.step_once(),"paused cut accepts ordinary Step")
	if not check(await until(func():return not ui.step_pending and host.rapier_bridge.manual_step_count()==before_step+1),"paused cut Step completes once"): finish();return
	check(host.latest_snapshot.tick_index==before_native+1,"one native tick for one requested Step")
	if not await run_steps(64): finish();return
	if not await cut(128,356,5): finish();return
	check(ui._model.item_count==menu_items,"no new model or test menu")
	check(ui.cut.capture_count==2 and host.rigid_bodies.size()==2,"two separate aggregate owners")
	check(not ui.apply(ui.applied,true),"retained replacement cannot drop native custody")
	if not await run_steps(120): finish();return
	var bodies: int=host.rigid_bodies.size()
	check(ui.paint(Vector2i(300,30),0) and ui.cut.finish_stroke(ui),"empty erase starts ordinary zero-release transaction")
	if not check(await until(installed),"zero-release handoff ends"): finish();return
	evidence.refused_strokes.append(ui.cut.receipts.duplicate(true))
	check(host.rigid_bodies.size()==bodies and ui.cut.capture_count==2,"zero release preserves custody")
	if not await run_steps(5): finish();return
	# An intentionally over-detailed ring refuses after lazy investigations.
	# Refused work remains counted and the old roster stays usable.
	for manual: bool in [false,true]:
		ui.applied.brush=24
		check(ui.paint(Vector2i(350,160),43),"author wide structural sheet")
		ui.applied.brush=16
		check(ui.paint(Vector2i(350,160),0) and ui.cut.finish_stroke(ui),"overflowing erase stroke")
		if not check(await until(installed),"capacity refusal releases the hold safely"): finish();return
		evidence.refused_strokes.append(ui.cut.receipts.duplicate(true))
		check(ui.cut.receipts.any(func(row: Dictionary):return row.get("frontier_limited",false)) and host.rigid_bodies.size()==2,"bounded frontier exhaustion is a refusal, not clearance")
		if manual:
			var count: int=host.rapier_bridge.manual_step_count()
			check(ui.step_once(),"Step after begin refusal")
			if not check(await until(func():return not ui.step_pending and host.rapier_bridge.manual_step_count()==count+1),"Step survives capacity refusal"): finish();return
		elif not await run_steps(3): finish();return
	check(host.tower_context.workbench_gcr.response=="LA-SELECTIVE" and host.tower_context.workbench_gcr.rows.size()==2,"applied native law and complete roster")
	evidence["states"]=[]
	for id: int in [1,2]:
		var state: Dictionary=host.physical_actor_session.workbench_actor_state(id)
		check(state.position.is_finite() and state.linear_velocity.is_finite() and is_finite(state.angular_velocity),"finite real falling/collision state")
		evidence.states.append(state)
	evidence["participation"]=host.latest_snapshot.native_worker_participation.duplicate(true)
	evidence["maximum_observed_workers"]=observed_workers
	check(evidence.participation.get("worker_capacity")==int(OS.get_environment("CYBERSAND_FREED_WORKERS")),"actual configured native worker capacity")
	var name: String="freed-qualification-"+OS.get_environment("CYBERSAND_FREED_WORKERS")
	check(Setup.write_named(name,ui.applied).is_empty(),"save exact source-removal/body recipe")
	var saved: Dictionary=Setup.read_named(name)
	check(saved.has("setup") and saved.setup.version==4 and saved.setup.actors.size()==2,"load recipe without duplicate representation")
	check(ui.restore_start(),"ordinary Restore retires complete live owner")
	await scene_changed
	host=current_scene;ui=host.shared_workbench
	if check(await until(installed),"Restore installs authored start"):
		check(ui.cut.capture_count==0 and host.rigid_bodies.size()==2 and host.rapier_bridge.manual_step_count()==0,"fresh replay has two bodies and no stale native archive")
	finish()

func json_values(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Transform2D: return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]
	if value is Dictionary:
		var result: Dictionary={}
		for key: Variant in value: result[key]=json_values(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item: Variant in value: result.append(json_values(item))
		return result
	return value

func finish() -> void:
	if host!=null: host.queue_free()
	await process_frame;await process_frame
	var output: String=OS.get_environment("CYBERSAND_FREED_REPORT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(json_values({"checks":checks,"failures":failures,"evidence":evidence}),"",true,true));file.close()
	print("WORKBENCH_FREED ",checks," checks / ",failures.size()," failures")
	quit(int(not failures.is_empty()))
