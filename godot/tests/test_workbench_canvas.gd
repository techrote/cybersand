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

# The built-in "my-canvas" water evaluation start, while no user file of that
# name exists; a saved file always wins (never removed by this regression).
func builtin_water() -> bool:
	var recipe: Dictionary = Setup.water_evaluation(panel._liquids.bridge.default_liquid_policy())
	check(Setup.validate(recipe).is_empty() and not Setup.rectangles(recipe).has("error"),"built-in water start admits")
	check(recipe.edits.size() <= Setup.MAX_STAMPS/2,"built-in water start leaves paint capacity (%d stamps)" % recipe.edits.size())
	if FileAccess.file_exists(Setup._path(Setup.DEFAULT_LABEL)):
		print("WORKBENCH_CANVAS: user my-canvas exists; built-in load skipped")
		return true
	var test_name: String = panel._name.text
	panel._name.text = Setup.DEFAULT_LABEL
	var loaded: bool = check(panel.load_setup(),"built-in my-canvas load / "+panel.message)
	panel._name.text = test_name
	if not loaded or not await until(installed,"built-in my-canvas installed"): return false
	check(main.tower_context.workbench_gcr.extent == Vector2i(512,512) and panel.applied.actors.size() == 2,"built-in extent and barrels")
	check(main.physical_actor_session.bodies().size() == 2,"two physical barrels")
	var water := 0
	for y: int in range(100,262,2):
		for x: int in range(0,480,2):
			if main.image.get_pixel(x,y).r8 == Setup.WATER: water += 1
	check(water > 4000,"built-in Water painted (%d sampled cells)" % water)
	check(main.image.get_pixel(146,230).r8 == Setup.WALL and main.image.get_pixel(115,254).r8 == Setup.SAND,"weir and sand bank")
	# WCX-FR face tuning: the panel seeds explicit integer construction options;
	# the native adapter admits them only inside its bounds, with face release.
	for key: String in main.FACE_TUNING:
		check(main.workbench_water_options.get(key) is int,"panel seeds "+key)
	var seeded: Dictionary = main.workbench_water_options.duplicate()
	main.workbench_water_options.merge({"workbench_ballistic":true,"workbench_face_release":true,"workbench_face_budget":0},true)
	panel._name.text = Setup.DEFAULT_LABEL
	if panel.load_setup(): await until(func(): return main.pending_microscenario_apply.is_empty(),"out-of-bounds face tuning")
	check(not str(main.microscenario_error).is_empty(),"face rate 0 refused by the native adapter")
	main.workbench_water_options.workbench_face_budget = seeded.workbench_face_budget
	loaded = check(panel.load_setup(),"face release rebuild / "+panel.message)
	panel._name.text = test_name
	if not loaded or not await until(installed,"face release start installed"): return false
	panel.toggle_pause()
	await until(func(): return int(main.latest_snapshot.tick_index) >= 60,"face release ticks")
	panel.toggle_pause()
	var launched := int(main.tower_context.get("water_spray",{}).get("ledger",{}).get("launched_quantity",0))
	check(launched > 0,"tuned face release launches parcels (%d)" % launched)
	await until(installed,"paused after face release")
	# Fine scheduling cores: workbench-only boolean construction option.
	main.workbench_water_options = {"workbench_fine_cores":true}
	panel._name.text = Setup.DEFAULT_LABEL
	loaded = check(panel.load_setup(),"fine-core rebuild / "+panel.message)
	panel._name.text = test_name
	if not loaded or not await until(installed,"fine-core start installed"): return false
	var fine_tick: int = main.latest_snapshot.tick_index
	panel.toggle_pause()
	await until(func(): return int(main.latest_snapshot.tick_index) >= fine_tick+30,"fine-core ticks")
	panel.toggle_pause()
	check(not main.simulation_worker.has_failed() and int(main.latest_snapshot.tick_index) >= fine_tick+30,"fine-core World simulates")
	await until(installed,"paused after fine cores")
	main.workbench_water_options = seeded
	for axis: int in 2: panel._extent[axis].value = 2048
	if not check(panel.new_canvas(),"blank canvas after built-in start"): return false
	return await until(func(): return installed() and panel.applied.actors.is_empty() and main.image.get_width() == 2048,"blank 2048 canvas")

# The built-in "bench-canvas" whole-engine benchmark: admitted within the paint
# and run budgets, eight barrels, every zone's materials, and it simulates.
func builtin_bench() -> bool:
	var recipe: Dictionary = Setup.engine_benchmark(panel._liquids.bridge.default_liquid_policy())
	var runs: Dictionary = Setup.rectangles(recipe)
	check(Setup.validate(recipe).is_empty() and not runs.has("error"),"built-in bench start admits")
	check(recipe.edits.size() <= Setup.MAX_STAMPS and runs.get("runs",[]).size() / 5 <= Setup.MAX_RUNS,"bench start inside paint/run budgets")
	if FileAccess.file_exists(Setup._path(Setup.BENCH_LABEL)):
		print("WORKBENCH_CANVAS: user bench-canvas exists; built-in load skipped")
		return true
	var test_name: String = panel._name.text
	panel._name.text = Setup.BENCH_LABEL
	var loaded: bool = check(panel.load_setup(),"built-in bench-canvas load / "+panel.message)
	panel._name.text = test_name
	if not loaded or not await until(installed,"built-in bench-canvas installed"): return false
	check(main.tower_context.workbench_gcr.extent == Vector2i(1024,512) and main.physical_actor_session.bodies().size() == 8,"bench extent and eight barrels")
	var seen := {}
	var data: PackedByteArray = main.image.get_data()
	var channels: int = 2 if main.image.get_format() == Image.FORMAT_RG8 else 1
	for i: int in range(0,data.size(),channels): seen[int(data[i])] = true
	for material: int in [Setup.WATER,Setup.SAND,Setup.LAVA,Setup.OIL,Setup.ACID,Setup.WOOD,Setup.ICE,Setup.METAL,Setup.SALT,Setup.SODIUM,Setup.GUNPOWDER,Setup.COAL]:
		check(seen.has(material),"bench material painted: %d" % material)
	var tick: int = main.latest_snapshot.tick_index
	panel.toggle_pause()
	await until(func(): return int(main.latest_snapshot.tick_index) >= tick+90,"bench ticks")
	panel.toggle_pause()
	check(not main.simulation_worker.has_failed() and int(main.latest_snapshot.tick_index) >= tick+90,"bench World simulates with reactions and bodies")
	await until(installed,"paused after bench")
	for axis: int in 2: panel._extent[axis].value = 2048
	if not check(panel.new_canvas(),"blank canvas after bench start"): return false
	return await until(func(): return installed() and panel.applied.actors.is_empty() and main.image.get_width() == 2048,"blank 2048 canvas after bench")

# Independent reference raster of a recipe's stamps (discs and boxes, in order).
func _reference_cells(recipe: Dictionary) -> PackedByteArray:
	var size := Setup.extent_of(recipe)
	var cells := PackedByteArray()
	cells.resize(size.x*size.y)
	for stamp: Array in recipe.edits:
		if stamp.size() == 5:
			for y: int in range(stamp[1],stamp[1]+stamp[3]):
				for x: int in range(stamp[0],stamp[0]+stamp[2]): cells[y*size.x+x] = stamp[4]
			continue
		var r: int = stamp[2]
		for y: int in range(maxi(0,stamp[1]-r),mini(size.y,stamp[1]+r+1)):
			for x: int in range(maxi(0,stamp[0]-r),mini(size.x,stamp[0]+r+1)):
				if (x-stamp[0])*(x-stamp[0])+(y-stamp[1])*(y-stamp[1]) <= r*r: cells[y*size.x+x] = stamp[3]
	return cells

# Merged rectangles never overlap and cover exactly the stamped cells.
func _rectangles_exact(recipe: Dictionary, label: String) -> int:
	var size := Setup.extent_of(recipe)
	var result: Dictionary = Setup.rectangles(recipe)
	if not check(not result.has("error"),label+" rectangles admitted"): return 0
	var runs: Array = result.runs
	var cells := PackedByteArray()
	cells.resize(size.x*size.y)
	var overlap := false
	for i: int in range(0,runs.size(),5):
		for y: int in range(runs[i+1],runs[i+1]+runs[i+3]):
			for x: int in range(runs[i],runs[i]+runs[i+2]):
				if cells[y*size.x+x] != 0: overlap = true
				cells[y*size.x+x] = runs[i+4]
	check(not overlap and cells == _reference_cells(recipe),label+" rectangles reproduce every stamped cell (%d rectangles)" % (runs.size()/5))
	return runs.size()/5

func rectangle_merge() -> void:
	var policy: PackedInt32Array = panel._liquids.bridge.default_liquid_policy()
	_rectangles_exact(Setup.water_evaluation(policy),"my-canvas")
	var bench := _rectangles_exact(Setup.engine_benchmark(policy),"bench-canvas")
	check(bench > 0 and bench < 3931,"vertical merge reduces bench-canvas below its 3,931 row runs")
	var mixed := Setup.fresh(policy,Vector2i(512,512))
	mixed.edits = [[10,10,40,30,Setup.WATER],[30,20,6,Setup.SAND],[0,0,512,4,Setup.WALL],[45,25,3,Setup.STONE],
		[511,511,5,Setup.LAVA],[200,100,1,300,Setup.WALL],[198,150,8,Setup.OIL],[0,508,512,4,0]]
	check(Setup.validate(mixed).is_empty(),"mixed disc and box stamps admit")
	_rectangles_exact(mixed,"mixed stamps")
	for bad: Array in [[500,0,13,4,Setup.WATER],[0,0,0,4,Setup.WATER],[0,500,4,13,Setup.WATER],[0,0,4,4,10],
			[0,0,4],[0,0,4,4,Setup.WATER,1],[0,0,30,Setup.FIRE]]:
		mixed.edits = [bad]
		check(not Setup.validate(mixed).is_empty(),"invalid stamp refused: "+str(bad))
	# Compaction keeps every stamped cell and drops erased strokes.
	mixed.edits = [[10,10,40,30,Setup.WATER],[30,20,6,Setup.SAND],[200,100,1,300,Setup.WALL],[30,20,6,0],[0,0,512,4,Setup.WALL]]
	for i: int in 200: mixed.edits.append([100+i%50,300,8,0])
	var compact: Dictionary = Setup.compact_edits(mixed)
	var before := _reference_cells(mixed)
	var squeezed := mixed.duplicate(true)
	squeezed.edits = compact.get("edits",[])
	check(not compact.has("error") and squeezed.edits.size() < 40 and Setup.validate(squeezed).is_empty()
		and _reference_cells(squeezed) == before,"compaction reproduces the cells without erase history (%d stamps)" % squeezed.edits.size())
	mixed.edits = [[0,0,4,4,Setup.FIRE]]
	mixed.material = Setup.FIRE
	check(not Setup.validate(mixed).is_empty(),"staged materials stay out of the brush palette")
	check(not panel.paint(Vector2i(4,4),Setup.FIRE),"brush refuses a staged-only material")

# A full paint history (mostly erasing) compacts instead of refusing the stroke.
func paint_compaction() -> bool:
	if not check(installed(),"installed before paint compaction"): return false
	var saved: Array = panel.applied.edits.duplicate(true)
	var full := []
	# Repeated strokes and erasing over one area, as a long paint session records.
	for i: int in Setup.MAX_STAMPS: full.append([100+(i%40)*2,120+(i/1024)*3,6,Setup.WATER if i%3 != 0 else 0])
	panel.applied.edits = full
	var before := _reference_cells(panel.applied)
	var painted: bool = panel.paint(Vector2i(1900,1900),Setup.SAND)
	check(painted and panel.applied.edits.size() < Setup.MAX_STAMPS,"full history compacts and accepts the stroke (%d records) / %s busy=%s" % [panel.applied.edits.size(),panel.message,str(panel.busy())])
	var after: Dictionary = panel.applied.duplicate(true)
	after.edits = after.edits.slice(0,after.edits.size()-1)
	check(_reference_cells(after) == before,"compacted history keeps every stamped cell")
	panel.applied.edits = saved
	return true

# The built-in "stress-canvas": admitted, eight barrels, most staged materials
# present, and it simulates.
func builtin_stress() -> bool:
	var recipe: Dictionary = Setup.stress_canvas(panel._liquids.bridge.default_liquid_policy())
	check(Setup.validate(recipe).is_empty(),"built-in stress start admits / "+Setup.validate(recipe))
	_rectangles_exact(recipe,"stress-canvas")
	if FileAccess.file_exists(Setup._path(Setup.STRESS_LABEL)):
		print("WORKBENCH_CANVAS: user stress-canvas exists; built-in load skipped")
		return true
	var test_name: String = panel._name.text
	panel._name.text = Setup.STRESS_LABEL
	var loaded: bool = check(panel.load_setup(),"built-in stress-canvas load / "+panel.message)
	panel._name.text = test_name
	if not loaded or not await until(installed,"built-in stress-canvas installed"): return false
	check(main.tower_context.workbench_gcr.extent == Vector2i(2048,1024) and main.physical_actor_session.bodies().size() == 8,"stress extent and eight barrels")
	var seen := {}
	var data: PackedByteArray = main.image.get_data()
	var channels: int = 2 if main.image.get_format() == Image.FORMAT_RG8 else 1
	for i: int in range(0,data.size(),channels): seen[int(data[i])] = true
	var painted := {}
	for stamp: Array in recipe.edits: painted[int(stamp[stamp.size()-1])] = true
	var missing := []
	for material: int in painted:
		if not seen.has(material): missing.append(material)
	check(missing.is_empty() and painted.size() >= 50,"every stress material painted (%d; missing %s)" % [painted.size(),str(missing)])
	var tick: int = main.latest_snapshot.tick_index
	panel.toggle_pause()
	await until(func(): return int(main.latest_snapshot.tick_index) >= tick+90,"stress ticks")
	panel.toggle_pause()
	check(not main.simulation_worker.has_failed() and int(main.latest_snapshot.tick_index) >= tick+90,"stress World simulates")
	await until(installed,"paused after stress")
	for axis: int in 2: panel._extent[axis].value = 2048
	if not check(panel.new_canvas(),"blank canvas after stress start"): return false
	return await until(func(): return installed() and panel.applied.actors.is_empty() and main.image.get_width() == 2048,"blank 2048 canvas after stress")

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
		else:
			rectangle_merge()
			if await builtin_water() and await builtin_bench() and await builtin_stress() and paint_compaction(): await author()
	else: check(false,"workbench launch")
	main.queue_free()
	await process_frame
	await process_frame
	print("WORKBENCH_CANVAS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
