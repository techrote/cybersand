extends SceneTree

# Ordinary Shared Workbench, real mouse/menu events, native ticks and submitted
# pixels. No standalone Wave evaluator and no headless graphical PASS.
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Scenes = preload("res://scripts/workbench_water_comparison_scenes.gd")
var host: Control
var bench: Control
var assertions := 0
var failures := 0
var captures: Array[Dictionary] = []
var output := ""

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, reason: String) -> bool:
	assertions += 1
	if not ok:
		failures += 1
		push_error("WORKBENCH_WAVE_RENDER: " + reason)
	return ok

func until(predicate: Callable, reason: String) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("graphical_case_seconds")
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return expect(predicate.call(),reason+" / "+str(host.microscenario_error))

func native() -> Dictionary:
	return host.tower_context.get("wave_flow",{})

func installed() -> bool:
	return bench != null and not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty()

func button(label: String, scope: Node = null) -> Button:
	if scope == null: scope = bench
	for node: Node in scope.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and node.text == label: return node
	return null

func click(control: Button) -> bool:
	if not expect(control != null and control.is_visible_in_tree(),"visible real control"): return false
	var window := control.get_window()
	# The toolbar can reflow when native status arrives. Move to its current
	# centre and wait for the same routed hover and layout across one frame.
	var point := Vector2.ZERO
	var ready := false
	var hovered: Control
	var deadline := Time.get_ticks_msec()+5000
	while Time.get_ticks_msec() < deadline:
		var bounds := control.get_global_rect()
		point = bounds.get_center()
		if window != root: point += Vector2(window.position)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion,true)
		await process_frame
		hovered = window.gui_get_hovered_control()
		if not control.disabled and bounds == control.get_global_rect() and (hovered == control or (hovered != null and control.is_ancestor_of(hovered))):
			ready = true
			break
	if not expect(ready,"pointer over "+control.text+" (hit "+str(hovered)+")"): return false
	var pressed := [false]
	control.pressed.connect(func() -> void: pressed[0] = true,CONNECT_ONE_SHOT)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
	await process_frame
	return expect(pressed[0],"real pointer event reaches "+control.text)

func pick(picker: OptionButton, index: int) -> bool:
	if not await click(picker): return false
	var popup := picker.get_popup()
	if not expect(popup.visible,"actual comparison menu opens"): return false
	popup.set_item_accelerator(index,KEY_F19)
	var event := InputEventKey.new()
	event.keycode = KEY_F19
	event.pressed = true
	var accepted := popup.activate_item_by_event(event)
	popup.set_item_accelerator(index,KEY_NONE)
	popup.hide()
	await process_frame
	return expect(accepted and picker.selected == index,"actual comparison menu selection")

func lab() -> Window:
	return bench.water_lab.window

func open_lab(tab: int) -> bool:
	if not lab().visible:
		if not await click(button("Water Lab…")): return false
		for frame: int in 3: await process_frame
	bench.water_lab.select_tab(tab)
	await process_frame
	return expect(lab().visible,"Water Lab window opens from the toolbar")

func close_lab() -> bool:
	if not lab().visible: return true
	if not await click(button("Close Water Lab",lab())): return false
	return expect(not lab().visible,"Water Lab closes")

func layout(label: String) -> void:
	var bounds := Rect2(Vector2.ZERO,Vector2(root.size))
	for caption: String in ["Play / Pause [P]","Water Lab…"]:
		var control := button(caption)
		expect(control != null and bounds.encloses(control.get_global_rect()),label+" main control fits: "+caption)
	expect(bounds.encloses(host.world_view.get_global_rect()) and host.world_view.size.y >= 180,
		label+" usable native canvas remains inside the window")

func save_capture(name_text: String, check_water: bool = true) -> void:
	for frame: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	if not expect(pixels != null and not pixels.is_empty(),"actual framebuffer "+name_text): return
	var blue := 0
	var content: Rect2 = host.view_content_rect()
	content.position += host.world_view.get_global_rect().position
	if check_water:
		for y: int in range(1,40):
			for x: int in range(1,64):
				var point := Vector2i(content.position+content.size*Vector2(x/64.0,y/40.0))
				if point.x < 0 or point.y < 0 or point.x >= pixels.get_width() or point.y >= pixels.get_height(): continue
				var color := pixels.get_pixelv(point)
				if color.b-color.r > 0.25 and color.g > 0.2: blue += 1
		expect(blue > 5,"submitted native Water pixels "+name_text)
	var file_name := "workbench-wave-"+name_text+".png"
	expect(pixels.save_png(output.path_join(file_name)) == OK,"retain raw screenshot "+name_text)
	captures.append({"name":name_text,"screenshot":file_name,"native":native().duplicate(true),
		"water_samples":blue,"window":str(root.size),"canvas":str(content),
		"active_label":bench.water_spray._wave_status.text})

func load_scene(index: int, wave: bool) -> bool:
	if not await open_lab(0): return false
	if not await pick(bench.water_spray._scene_picker,index): return false
	var before := int(native().get("session_generation",-1))
	if not await click(button("Load / reset scene",lab())): return false
	if not await until(func() -> bool: return installed() and int(native().get("session_generation",-1)) > before,
		"new native comparison World "+str(Scenes.SCENES[index].id)): return false
	if not await close_lab(): return false
	return expect(bool(native().get("enabled",false)) == wave and host.paused,
		"fresh scene keeps requested solver and starts paused")

func run_ticks(count: int) -> bool:
	var before := int(native().get("completed_tick",0))
	if not await click(button("Play / Pause [P]")): return false
	if not await until(func() -> bool: return int(native().get("completed_tick",0)) >= before+count,
		"real native simulation advances"): return false
	if not await click(button("Play / Pause [P]")): return false
	return await until(func() -> bool: return host.paused and installed(),"paused healthy native World")

func run() -> void:
	if not expect(DisplayServer.get_name() != "headless","real display required; headless is not graphical qualification"):
		quit(1)
		return
	output = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if output.is_empty(): output = OS.get_environment("CYBERSAND_PRESENTATION_EVIDENCE")
	if output.is_empty(): output = ProjectSettings.globalize_path("user://workbench-wave-render")
	expect(DirAccess.make_dir_recursive_absolute(output) == OK,"capture directory")
	root.content_scale_size = Vector2i.ZERO
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280,800)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	if "--workbench" not in OS.get_cmdline_user_args(): current_scene.launch("shared_workbench")
	await scene_changed
	host = current_scene
	bench = host.shared_workbench
	if not await until(installed,"ordinary Workbench starts"): await finish(); return
	layout("1280×800 first open")
	if not await open_lab(0): await finish(); return
	if not await pick(bench.water_spray._studio_solver,1): await finish(); return
	var tuning: Window = lab()
	expect(tuning.visible and bool(native().get("enabled",false)) and native().spill.parcels,"fresh Workbench displays its active gameplay Wave selection")
	bench.water_lab.select_tab(1)
	await process_frame
	var rounds: SpinBox = bench.water_spray._wave_fields.workbench_wave_substeps
	rounds.get_line_edit().text = "2"
	rounds.apply()
	var gain: SpinBox = bench.water_spray._wave_fields.workbench_wave_gain
	gain.get_line_edit().text = "48"
	gain.apply()
	var floor_gain: SpinBox = bench.water_spray._wave_fields.workbench_wave_floor_gain
	floor_gain.get_line_edit().text = "960"
	floor_gain.apply()
	var initial_generation := int(native().session_generation)
	if not await click(button("Apply solver / tuning",tuning)): await finish(); return
	if not await until(func() -> bool: return installed() and int(native().session_generation) > initial_generation and bool(native().get("enabled",false)),"actual UI retunes native Wave"):
		await finish(); return
	expect(int(native().get("substeps",0)) == 2 and int(native().get("parameters",{}).get("gain",0)) == 48
		and native().parameters.floor_gain == 960, "entered gain, rounds and floor gain match authoritative native readback")
	if not await close_lab(): await finish(); return
	for index: int in Scenes.SCENES.size():
		if not await load_scene(index,true): break
		if not await run_ticks(180 if index == 1 else 30): break
		layout(str(Scenes.SCENES[index].id))
		expect(int(native().get("ticks",0)) > 0 and int(native().get("rounds",0)) > 0,
			"rendered scene has actual Wave work")
		if index == 1:
			expect(host.physical_actor_session != null and host.physical_actor_session.bodies().size() == 4,
				"repeated impact scene owns four real Rapier bodies")
		await save_capture(str(Scenes.SCENES[index].id))
		if index == 0:
			if not await open_lab(1): break
			for frame: int in 3: await process_frame
			var popup_bounds := Rect2(Vector2.ZERO,Vector2(tuning.size))
			for caption: String in ["Reset Wave defaults","Revert to native","Apply solver / tuning","Close Water Lab"]:
				var control := button(caption,tuning)
				expect(control != null and popup_bounds.encloses(control.get_global_rect()),"tuning action fits: "+caption)
			expect(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(tuning.position),Vector2(tuning.size))),
				"Workbench tuning dialog fits desktop")
			expect(str(bench.water_spray._wave_applied_fields.workbench_wave_gain.text).contains("48"),"visible native gain readback")
			await save_capture("tuning",false)
			if not await close_lab(): break
		if failures > 0: break
	if failures == 0:
		if await open_lab(0): await pick(bench.water_spray._studio_solver,3)
		if await load_scene(0,false) and await run_ticks(30):
			expect(str(bench._water_identity(host.tower_context)) == "pressure_flow/cached","actual PressureFlow comparison active")
			for size: Vector2i in [Vector2i(1024,768),Vector2i(1280,720)]:
				root.size = size
				for frame: int in 4: await process_frame
				layout(str(size))
			await save_capture("pressure-1280x720")
	await finish()

func finish() -> void:
	var binary := "cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"
	var receipt := {"source_commit":OS.get_environment("GITHUB_SHA"),"schema":"workbench-wave-render-v1",
		"kind":"ordinary Shared Workbench, actual UI/native/Rapier/submitted pixels; no physical GPU or owner acceptance",
		"godot":Engine.get_version_info().string,"display":DisplayServer.get_name(),
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/"+binary),
		"assertions":assertions,"failures":failures,"captures":captures}
	var file := FileAccess.open(output.path_join("workbench-wave-render.json"),FileAccess.WRITE)
	expect(file != null,"write graphical receipt")
	if file != null:
		file.store_string(JSON.stringify(receipt,"\t")+"\n")
		file.close()
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await process_frame
	print("WORKBENCH_WAVE_RENDER ",JSON.stringify({"assertions":assertions,"failures":failures,"captures":captures.size()}))
	quit(int(failures > 0 or captures.size() != 6))
