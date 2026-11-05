extends SceneTree

# Set CYBERSAND_WORKBENCH_REOPEN=1 in a second process for the file readback.
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var main: Control
var panel
var checks := 0
var failures := 0
var start_ms: int
const DISTANT := Vector2i(1500,1400)

func _initialize() -> void:
	start_ms = Time.get_ticks_msec()
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("WORKBENCH_CANVAS: " + label)
	return ok

func until(test: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while not test.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return check(test.call(),label+" / "+main.microscenario_error)

func installed() -> bool:
	return not panel.applied.is_empty() and not panel.busy() and main.pending_microscenario_apply.is_empty()

func pixels() -> bool:
	return main.image.get_width() == 2048 and main.image.get_height() == 2048 \
		and main.image.get_pixelv(DISTANT).r8 == 58 and main.image.get_pixelv(DISTANT+Vector2i(4,0)).r8 == 0

func author() -> void:
	panel._brush.value = 3
	check(panel.paint(DISTANT,58),"paint beyond 1024")
	check(panel.paint(DISTANT+Vector2i(40,0),3),"Water brush")
	if not await until(pixels,"actual distant painted image"): return
	for spec: Array in [["scooper",Vector2(1420,1360)],["midge",Vector2(620,560)],[Setup.BARREL,Vector2(1480,1360)]]:
		if not check(panel.place(spec[0],spec[1]),"request "+str(spec)): return
		if not await until(installed,"placement acknowledgement"): return
	check(panel.select_instance(2),"select second flyer")
	panel._fields.mass_multiplier.value = 3
	panel._fields.inertia_multiplier.value = 4
	panel._fields.budget.value = 40
	if not check(panel.apply_settings(),"apply independent settings"): return
	if not await until(installed,"settings installed"): return
	panel._material.select(1)
	panel.applied.material = 14
	panel._source_material.select(1)
	check(panel.place_source(DISTANT+Vector2i(25,-30)),"distant Dust source")
	var original: Dictionary = panel.applied.duplicate(true)
	var invalid := original.duplicate(true)
	invalid.liquid_policy = [1]
	var old_epoch: int = main._physical_epoch
	var queued: bool = panel.apply(invalid,true)
	if queued: await until(func(): return main.pending_microscenario_apply.is_empty(),"native policy refusal")
	check(panel.applied == original and main._physical_epoch == old_epoch,"invalid policy retained live session")
	for choice: Array in [[3,"cellular_yield_v1","reference"],[3,"pressure_flow_v1","reference"],
		[3,"pressure_flow_v1","cached"],[3,"pressure_flow_v1","cached_dormant"],[3,"freemass_v1","reference"],
		[3,"inertial_cellular_v1","reference"],[24,"inertial_cellular_v1","reference"],[24,"cellular_yield_v1","reference"]]:
		var bridge: Object = panel._liquids.bridge
		var request: PackedInt32Array = PackedInt32Array(panel.applied.liquid_policy)
		var found := false
		for option: Dictionary in bridge.liquid_policy_assignment_choices(request,choice[0]):
			if option.family == choice[1] and option.variant == choice[2] and option.accepted:
				panel._liquids.requested_policy = option.request
				found = true
				break
		if not check(found,"native choice "+str(choice)): return
		if str(choice[1])=="inertial_cellular_v1": panel._liquids.geometry_picker.select(1)
		if not check(panel.apply_liquids(),"request policy "+str(choice)): return
		if not await until(installed,"policy acknowledgement "+str(choice)): return
		var actual: Dictionary = {}
		for a: Dictionary in main.tower_context.liquid_solver_policy.assignments:
			if a.material == choice[0]: actual = a
		check(actual.get("applied_family") == choice[1] and actual.get("applied_variant") == choice[2],"native policy readback "+str(choice)+" got "+str(actual)+" / "+main.microscenario_error)
	panel._requested_response = "RFT"
	check(not panel.apply_settings(),"real RFT refuses a body budget of 40")
	panel._fields.budget.value = 20
	for mode: String in ["RFT","LA","LA-EVENT-OFF","LA-SELECTIVE"]:
		if mode == "LA-SELECTIVE": panel._fields.budget.value = 40
		panel._requested_response = mode
		if not check(panel.apply_settings(),"request "+mode): return
		if not await until(installed,"response acknowledgement "+mode): return
		check(main.tower_context.workbench_gcr.response == mode,"native response "+mode)
	var saved: Dictionary = panel.applied.duplicate(true)
	var old_name := str(panel._name.text)
	var damaged_name := old_name+"-corrupt"
	var file := FileAccess.open(Setup._path(damaged_name),FileAccess.WRITE)
	if file != null:
		file.store_string("{")
		file.close()
	panel._name.text = damaged_name
	check(not panel.load_setup() and panel.applied == saved and main.pending_microscenario_apply.is_empty(),
		"corrupt file refused before owner replacement")
	panel._name.text = old_name
	check(panel.save_setup(),"atomic named save")
	await inspect()

func inspect() -> void:
	var gcr: Dictionary = main.tower_context.workbench_gcr
	check(gcr.extent == Vector2i(2048,2048) and gcr.response == "LA-SELECTIVE","actual extent and selected response")
	if not await until(pixels,"saved distant paint readback"): return
	if not check(panel.applied.actors.size()==3,"all three instances restored"): return
	var actor_session = main.physical_actor_session
	var a: Dictionary = actor_session.workbench_actor_state(1)
	var b: Dictionary = actor_session.workbench_actor_state(2)
	var c: Dictionary = actor_session.workbench_actor_state(3)
	check(a.model == "scooper" and a.position.is_equal_approx(Vector2(1420,1360)),"actual distant U body")
	check(b.model == "midge" and b.budget == 40 and b.position.is_equal_approx(Vector2(620,560)),"separate configured flyer")
	check(c.model == Setup.BARREL and c.position.is_equal_approx(Vector2(1480,1360)),"actual distant barrel")
	check(actor_session.bodies().size() == 3 and main.rigid_bodies == actor_session.bodies(),"one physical owner graph")
	var common_space := PhysicsServer2D.body_get_space(main.rigid_bodies[0].get_rid())
	for body: RigidBody2D in main.rigid_bodies:
		check(common_space == PhysicsServer2D.body_get_space(body.get_rid()),"same actual Rapier space")
	check(panel.pilot_slot == 1 and panel.applied.source == [1525,1370,14],"selection and source reproduced")
	for row: Dictionary in main.tower_context.liquid_solver_policy.assignments:
		if row.material == 3: check(row.applied_family == "inertial_cellular_v1","Water IN readback")
	check(main.paused and not panel._stream.button_pressed,"load is paused with neutral source")
	check(await until(func(): return main.tower_context.workbench_source.armed,"source configuration restored"),"armed source")
	var screenshot := OS.get_environment("CYBERSAND_WORKBENCH_CAPTURE")
	if not screenshot.is_empty():
		panel.select_instance(1)
		panel._set_view(Vector2(1220,1240),Vector2i(480,270))
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(screenshot) == OK,"graphical owner-review capture")
	var tick: int = main.latest_snapshot.tick_index
	check(panel.step_once(),"request acknowledged step")
	if not await until(installed,"single step complete"): return
	check(main.latest_snapshot.tick_index == tick+1,"one native tick")
	print("WORKBENCH_CANVAS_READBACK ",JSON.stringify({"extent":str(gcr.extent),"response":gcr.response,
		"arrival_bytes":gcr.arrival_storage_bytes,"bodies":3,"source":main.tower_context.workbench_source,
		"tick_ms":main.latest_snapshot.simulation_time_ms,"elapsed_ms":Time.get_ticks_msec()-start_ms}))

func run() -> void:
	root.size = Vector2i(1920,1080)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	if "--workbench" not in OS.get_cmdline_user_args():
		current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	panel = main.shared_workbench
	if panel != null and await until(installed,"initial empty owner"):
		panel._name.text = OS.get_environment("CYBERSAND_WORKBENCH_TEST_NAME")
		if panel._name.text.is_empty(): panel._name.text = "canvas-regression"
		check(panel.applied.actors.is_empty() and main.paused and not panel._details.visible,"paused blank canvas")
		check(main.tower_context.workbench_gcr.response == "LA-SELECTIVE","fresh native default")
		if OS.get_environment("CYBERSAND_WORKBENCH_REOPEN") == "1":
			if check(panel.load_setup(),"load from separate process / "+panel.message+" / "+main.microscenario_error) and await until(installed,"reload acknowledged"):
				await inspect()
		else: await author()
	else: check(false,"workbench launch")
	main.queue_free()
	await process_frame
	await process_frame
	print("WORKBENCH_CANVAS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
