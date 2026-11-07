extends SceneTree

const Setup=preload("res://scripts/workbench_setup.gd")
const Body=Setup.CanvasBody
const Session=preload("res://scripts/physical_actor_session.gd")
const Rig=preload("res://scripts/physical_actor_rig.gd")
const Equipment=preload("res://scripts/physical_usable_equipment.gd")
var host: Control
var panel
var failures: Array[String]=[]
var checks: int=0
var evidence: Dictionary={}

func check(ok: bool,reason: String) -> bool:
	checks+=1
	if not ok:failures.append(reason);push_error("CANVAS_BODY "+reason)
	return ok

func wait_for(predicate: Callable) -> bool:
	var end: int=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<end:
		if predicate.call():return true
		if host!=null and host.simulation_worker.has_failed():break
		await process_frame
	return false

func installed() -> bool:
	return panel!=null and not panel.applied.is_empty() and not panel.busy() and host.pending_microscenario_apply.is_empty()

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://canvases/sol-fresh-structures.json"))
	check(Setup.validate(data).is_empty(),"source canvas validation")
	var old: Dictionary=data.duplicate(true);old.version=2
	check(not Setup.validate(old).is_empty(),"old format cannot smuggle canvas geometry")
	var bad: Dictionary=data.duplicate(true);bad.actors[0].hash="foreign"
	check(not Setup.validate(bad).is_empty(),"geometry hash admission")
	bad=data.actors[0].body.duplicate(true);bad.rectangles.append(bad.rectangles[0])
	check(not Body.error(bad).is_empty(),"overlapping shape refusal")
	bad={"name":"too detailed","rectangles":[]}
	for x: int in range(65): bad.rectangles.append([x,0,1,1])
	check(not Body.error(bad).is_empty(),"proxy capacity refusal")
	bad.rectangles.pop_back()
	check(Body.error(bad).is_empty(),"64 exact canvas rectangles")
	var detailed: Dictionary=Equipment.definition(Body.definition(bad))
	check(Rig.validate_definition(detailed,bad).is_empty(),"canvas-only 64-shape rig admission")
	check(not Rig.validate_definition(detailed).is_empty(),"authored rig eight-shape guard retained")
	bad=data.actors[0].body.duplicate(true);bad["mass"]=1
	check(not Body.error(bad).is_empty(),"no hidden mass override")
	for index: int in data.actors.size():
		var actor: Dictionary=data.actors[index];var derived: Dictionary=Body.definition(actor.body)
		check(derived.parts[0].mass==(520 if index%2==0 else 356),"unit rectangle mass")
		check(Body.digest(actor.body)==actor.hash,"JSON roundtrip hash")
		var resolved: Dictionary=Equipment.definition(derived)
		check(Rig.validate_definition(resolved,actor.body).is_empty(),"scoped passive rig admission")
		check(not Rig.validate_definition(resolved).is_empty(),"ordinary rig mass admission remains closed")
		resolved.parts[0].mass+=1
		check(not Rig.validate_definition(resolved,actor.body).is_empty(),"forged resolved mass refusal")
	var definitions: Array=Setup.physical_definitions(data)
	check(Session.valid_definitions(definitions),"normal workbench accepts passive definitions")
	definitions[0].producer="human"
	check(not Session.valid_definitions(definitions),"passive body cannot gain drive authority")
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;panel=host.shared_workbench
	if not check(await wait_for(installed),"ordinary workbench opens"):finish();return
	check(PackedInt32Array(data.liquid_policy)==PackedInt32Array(panel.applied.liquid_policy),"source-qualified default liquid policy")
	var name: String=OS.get_environment("CYBERSAND_CANVAS_NAME")
	if name.is_empty():name="sol-fresh-structures-20261106"
	var path: String=Setup._path(name)
	if FileAccess.file_exists(path):
		var prior: Dictionary=Setup.read_named(name)
		if not check(prior.has("setup") and JSON.parse_string(JSON.stringify(prior.setup))==JSON.parse_string(JSON.stringify(data)),"preserve existing named canvas"):finish();return
	else:
		if not check(Setup.write_named(name,data).is_empty(),"install uniquely named ordinary canvas"):finish();return
	panel._name.text=name
	if not check(panel.load_setup(),"existing Load start accepts canvas"):finish();return
	if not check(await wait_for(installed),"fresh canvas preparation finishes: "+host.microscenario_error):finish();return
	check(host.paused and panel.pilot_slot==-1,"starts paused with observer controls")
	var capture: String=OS.get_environment("CYBERSAND_CANVAS_CAPTURE")
	if not capture.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture)==OK,"actual workbench rendered capture")
	check(panel._model.item_count==Setup.Fleet.count()+1,"no extra model picker entries")
	check(host.rigid_bodies.size()==4 and host.physical_actor_session.bodies()==host.rigid_bodies,"four real bodies, one owner graph")
	var initial: Array=[]
	var bridge=host.physical_actor_session.bridge
	check(bridge.manual_step_count()==0,"no artificial warm step")
	for index: int in host.rigid_bodies.size():
		var body: RigidBody2D=host.rigid_bodies[index];var state: Dictionary=host.physical_actor_session.workbench_actor_state(index+1)
		initial.append(state.position)
		check(PhysicsServer2D.body_get_shape_count(body.get_rid())==(6 if index%2==0 else 5),"actual compound collider count")
		check(body.mass==(520 if index%2==0 else 356) and body.center_of_mass_mode==RigidBody2D.CENTER_OF_MASS_MODE_AUTO,"actual mass and AUTO COM")
		check(is_equal_approx(body.inertia,Body.definition(data.actors[index].body).parts[0].inertia),"actual derived native-unit inertia")
		check(is_equal_approx(body.gravity_scale,0.094) and is_equal_approx(body.linear_damp,0.04) and is_equal_approx(body.angular_damp,0.04),"fixed gravity and authored damping")
		check(body.linear_damp_mode==RigidBody2D.DAMP_MODE_COMBINE and body.angular_damp_mode==RigidBody2D.DAMP_MODE_COMBINE,"combined damping")
		check(not host.physical_actor_session.takeover(index,host._physical_epoch,&"human"),"reject passive takeover")
		check(is_equal_approx(PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_FRICTION),0.78),"reference contact friction")
	check(panel.select_instance(1) and panel.pilot_slot==-1,"select shape without piloting")
	check(panel.select_instance(0),"return to observer")
	check(host.tower_context.workbench_gcr.response=="LA-SELECTIVE" and host.tower_context.workbench_gcr.rows.size()==4,"actual native response and roster")
	check(panel.toggle_pause(),"existing P/unpause action")
	if not check(await wait_for(func():return bridge.manual_step_count()>0),"live session starts"):finish();return
	for index: int in 4:
		var owner=host.physical_actor_session
		check(not owner.submit_local(index,{"move":Vector2.RIGHT},&"passive") and owner.last_error=="passive_prop","reject direct passive command before actuation")
	if not check(await wait_for(func():return bridge.manual_step_count()>=64),"live native/Rapier advances"):finish();return
	check(panel.toggle_pause(),"existing pause action")
	var states: Array=[]
	for index: int in 4:
		var state: Dictionary=host.physical_actor_session.workbench_actor_state(index+1)
		check(state.position.is_finite() and state.position.distance_to(initial[index])>0.01,"fresh passive structure moves under real simulation")
		states.append({"position":[state.position.x,state.position.y],"mass":state.mass,"inertia":state.inertia,"omega":state.angular_velocity})
	var before: int=bridge.manual_step_count()
	check(panel.step_once(),"existing single-step request")
	if check(await wait_for(installed),"single step completes"):check(bridge.manual_step_count()==before+1,"one actual physical step")
	evidence={"name":name,"user_path":ProjectSettings.globalize_path(path),"states":states,"physical_steps":bridge.manual_step_count(),"response":host.tower_context.workbench_gcr.response,"native_tick":host.latest_snapshot.tick_index}
	check(panel.restore_start(),"existing Restore start")
	if check(await wait_for(installed),"restore preparation finishes"):
		check(host.paused and host.rigid_bodies.size()==4,"restore is paused with four fresh bodies")
		check(host.physical_actor_session.bridge.manual_step_count()==0,"restore starts a new physical session")
		for index: int in 4:check(host.physical_actor_session.workbench_actor_state(index+1).position.is_equal_approx(initial[index]),"saved spawn restored")
	finish()

func finish() -> void:
	if host!=null:host.queue_free()
	await process_frame;await process_frame
	var output: String=OS.get_environment("CYBERSAND_CANVAS_REPORT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"",true,true));file.close()
	print("CANVAS_BODY ",checks," checks / ",failures.size()," failures")
	quit(int(not failures.is_empty()))
