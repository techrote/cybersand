extends "res://tests/test_workbench_freed.gd"

var maximum_frame_usec: int=0
var last_frame_usec: int=0
var measuring: bool=false

func watch_frame() -> void:
	var now: int=Time.get_ticks_usec()
	if measuring and last_frame_usec>0: maximum_frame_usec=maxi(maximum_frame_usec,now-last_frame_usec)
	last_frame_usec=now

func history() -> void:
	var setup: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(2048,2048))
	setup.version=4
	for i: int in range(24):
		setup.edits.append([0,0,2048,2048,43]);setup.edits.append([0,0,2048,2048,0])
	setup.edits.append([17,19,6,3,43])
	check(Setup.validate(setup).is_empty(),"long history is valid within unchanged budgets")
	var values: Array=[]
	for repeat: int in range(5):
		var started: int=Time.get_ticks_usec()
		var result: Dictionary=Setup.rectangles(setup)
		values.append(Time.get_ticks_usec()-started)
		check(result.get("runs")==[17,19,6,1,43,17,20,6,1,43,17,21,6,1,43],"long history exact final cells")
	evidence["history_usec"]=values

func fresh_case(kind: String) -> bool:
	var recipe: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	recipe.version=4;recipe.edits=[[0,72,512,4,58]]
	if kind=="first-tree-core" or kind=="anchored-refusal": structure(recipe,0,false)
	elif kind=="appended-building-core":
		structure(recipe,0,true)
		recipe.actors=[Setup.instance(Setup.BARREL,1,Vector2(400,32))];recipe.next_id=2
	else: recipe.edits.append([50,54,1,18,43])
	check(host.workbench_restart(recipe,true),"fresh authoritative owner for each repeat");await scene_changed
	host=current_scene;ui=host.shared_workbench
	if not check(await until(installed),"fresh canvas installed"): return false
	check(ui.cut.rectangle_core,"unchanged normal rectangle-core route")
	host.simulation_worker.set_worker_participation_sampling(true)
	check(ui.step_once(),"apply native region")
	return check(await until(func():return not ui.step_pending and host.latest_snapshot.tick_index>0),"region applied")

func one(kind: String, repeat: int, fps: int) -> bool:
	if not await fresh_case(kind): return false
	var tick: int=host.latest_snapshot.tick_index
	var generation: int=host.latest_snapshot.render_world_generation
	var old_steps: int=host.rapier_bridge.manual_step_count()
	var old: RigidBody2D=host.rigid_bodies[0] if kind=="appended-building-core" else null
	var old_state: Array=[] if old==null else [old.get_rid(),old.transform,old.linear_velocity,old.angular_velocity,old.mass,old.inertia]
	ui.applied.brush=2
	maximum_frame_usec=0;last_frame_usec=Time.get_ticks_usec();measuring=true
	var started: int=Time.get_ticks_usec()
	if kind=="small-debris": check(ui.paint(Vector2i(50,72),0),"small cut")
	elif kind=="anchored-refusal": check(ui.paint(Vector2i(44,30),0),"non-severing edge erase")
	else:
		for x: int in range(50,54): check(ui.paint(Vector2i(x,67),0),"complete stem cut")
	check(ui.cut.finish_stroke(ui),"ordinary stroke")
	if not check(await until(installed),"cut ends"): return false
	# Freeze before any observer RPC or first lazy material construction.
	var timing: Dictionary=ui.cut.timings.duplicate(true)
	var receipts: Array=ui.cut.receipts.duplicate(true)
	var total: int=Time.get_ticks_usec()-started
	var visual_started: int=Time.get_ticks_usec()
	if host.physical_actor_session!=null: host.physical_actor_session.render_parts()
	var visual_usec: int=Time.get_ticks_usec()-visual_started
	await process_frame
	measuring=false
	check(host.latest_snapshot.tick_index==tick and host.latest_snapshot.render_world_generation==generation,"same World and no hidden native step")
	check(host.rapier_bridge.manual_step_count()==(old_steps if old!=null else 0),"no hidden Rapier step")
	var expected_bodies: int=2 if old!=null else (1 if kind=="first-tree-core" else 0)
	check(host.rigid_bodies.size()==expected_bodies,"unchanged body route")
	if old!=null: check([old.get_rid(),old.transform,old.linear_velocity,old.angular_velocity,old.mass,old.inertia]==old_state,"existing owner unchanged")
	if kind in ["first-tree-core","appended-building-core"]:
		var body: RigidBody2D=host.rigid_bodies.back()
		check(body.mass==(208 if kind=="first-tree-core" else 152) and PhysicsServer2D.body_get_shape_count(body.get_rid())==1,"unchanged retained mass/proxy")
		check(is_equal_approx(body.gravity_scale,.094) and is_equal_approx(body.linear_damp,.04),"unchanged physics values")
	var outcomes: Array=[]
	for receipt: Dictionary in receipts:
		outcomes.append({"outcome":receipt.get("outcome"),"phase":receipt.get("phase"),"ok":receipt.get("ok"),"done":receipt.get("done",false),"members":receipt.get("member_count",0),"fringe":receipt.get("fringe_count",0)})
	evidence.cuts.append({"kind":kind,"repeat":repeat,"fps":fps,"total_usec":total,"timings":timing,"maximum_frame_usec":maximum_frame_usec,"first_visual_usec":visual_usec,"outcomes":outcomes,"receipts":receipts})
	return true

func run() -> void:
	process_frame.connect(watch_frame)
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;ui=host.shared_workbench
	if not check(await until(installed),"ordinary workbench"): finish();return
	history()
	for fps: int in [60,30]:
		Engine.max_fps=fps
		for kind: String in ["first-tree-core","appended-building-core","small-debris","anchored-refusal"]:
			for repeat: int in range(5):
				print("CUT_HITCH ",fps," ",kind," ",repeat)
				if not await one(kind,repeat,fps): finish();return
	evidence["maximum_observed_workers"]=observed_workers
	finish()
