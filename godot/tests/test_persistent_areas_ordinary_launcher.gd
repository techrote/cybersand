extends SceneTree

# Ordinary opt-in isolation regression. Enter through the actual launcher's
# --workbench route, then require an acknowledged native installation and real
# material progression. The launcher's early READY print is not acceptance.
const Setup = preload("res://scripts/workbench_setup.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
var host: Control
var bench: Control
var worker: RefCounted
var checks := 0
var failures: Array[String] = []
var output := ""
var report: Dictionary = {}


func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--persistent-evidence="):
			output = argument.trim_prefix("--persistent-evidence=")
	run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("GEN006_ORDINARY_WORKBENCH: "+label)
	return ok


func until(predicate: Callable, label: String, timeout_msec: int = 60000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_msec
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return check(predicate.call(),label+(" / "+str(host.microscenario_error) if is_instance_valid(host) else ""))


func installed() -> bool:
	return is_instance_valid(host) and bench!=null and not bench.applied.is_empty() \
		and not bench.busy() and host.pending_microscenario_apply.is_empty() \
		and host.latest_snapshot!=null and int(host.latest_snapshot.render_world_generation)>0 \
		and host.tower_context.get("liquid_construction_receipt",{}).get("kind","")=="applied_run" \
		and host.tower_context.get("workbench_gcr",{}).get("response","")=="LA-SELECTIVE"


func settled() -> bool:
	return installed() and not worker.paint_state().get("busy",false) \
		and not worker.paint_state().get("legacy_busy",false) and bool(worker.paint_state().get("paused",false))


func run() -> void:
	if not check("--workbench" in OS.get_cmdline_user_args(),"real --workbench launcher argument supplied") \
		or not check(not "--persistent-areas" in OS.get_cmdline_user_args(),"persistent-area route is not selected"):
		await finish()
		return
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	if not check(change_scene_to_file("res://feature_launcher.tscn")==OK,"actual feature launcher scene opens"):
		await finish()
		return
	if not await until(func() -> bool: return current_scene!=null and current_scene.scene_file_path=="res://main.tscn",
		"actual launcher argument reaches ordinary Main"):
		await finish()
		return
	host = current_scene
	bench = host.shared_workbench
	worker = host.simulation_worker
	if not await until(installed,"ordinary Workbench receives actual native constructor and Main acknowledgement",120000):
		await finish()
		return
	await exercise()
	await finish()


func exercise() -> void:
	check(get_meta("cybersand_feature","")=="shared_workbench","launcher records ordinary Workbench feature identity")
	check(not host.has_method("request_persistent_exit") and host.find_child("PersistentAreasController",true,false)==null,
		"ordinary Main has no persistent-area lifecycle owner")
	check(host.find_child("PersistentAreasPanel",true,false)==null,"experimental area controls do not appear in ordinary Workbench")
	check(host.paused and host.world_extent==Vector2i(2048,2048),"ordinary paused 2048 by 2048 default is preserved")
	check(not worker.has_failed() and str(host.microscenario_error).is_empty(),"acknowledged ordinary native World is healthy")
	var checked: Dictionary = Contract.validate(host.microscenario_definition)
	if not check(checked.get("ok",false) and host.microscenario_definition.get("id","")==Contract.WORKBENCH_ID,
		"ordinary full construction source validates as Workbench"): return
	check(host.tower_context.get("microscenario",{}).get("definition_hash","")==checked.hash,
		"installed native-host observation binds the complete ordinary construction identity")
	var receipt: Dictionary = host.tower_context.liquid_construction_receipt
	check(str(receipt.get("receipt_hash","")).length()==64 and int(receipt.get("session_generation",0))>0,
		"native preparation has a real applied-run receipt and positive generation")
	var defaults: Dictionary = ClassDB.class_call_static(&"CyberNativeCellWorld",&"gameplay_water_options")
	for key: String in defaults:
		check(host.workbench_water_options.has(key) and host.workbench_water_options[key]==defaults[key],
			"ordinary Main preserves accepted gameplay Water option "+key)
	var wave: Dictionary = host.tower_context.get("wave_flow",{})
	check(bool(defaults.get("workbench_wave_flow",false)) and bool(wave.get("enabled",false)),
		"actual ordinary native World retains accepted Wave gameplay Water")
	check(int(wave.get("substeps",-1))==int(defaults.get("workbench_wave_substeps",-2)) \
		and int(wave.get("parameters",{}).get("gain",-1))==int(defaults.get("workbench_wave_gain",-2)),
		"native Wave readback matches accepted gameplay substeps and gain")
	check(not bench._roster.disabled and not bench._model.disabled and not bench._instances.disabled \
		and not bench._response.disabled and not bench._stream.disabled and not bench._fire.disabled,
		"ordinary actor, source, response and thruster controls remain enabled")
	for index: int in range(bench._tool.item_count):
		check(not bench._tool.is_item_disabled(index),"ordinary cursor tool remains available: "+bench._tool.get_item_text(index))
	var configuration: Button
	for caption: String in ["New blank","New from generator…","Water Lab…","Configuration…","Place at X/Y","Source at X/Y","Apply settings"]:
		var found := false
		for button: Node in bench.find_children("*","Button",true,false):
			if str(button.text)==caption:
				found = true
				check(not button.disabled,"ordinary control enabled: "+caption)
				if caption == "Configuration…": configuration = button as Button
		check(found,"ordinary control is mounted: "+caption)
	if not is_instance_valid(configuration) or configuration.disabled: return
	configuration.pressed.emit()
	var panel: Variant = bench._actor_panel
	if not check(is_instance_valid(panel) and panel.visible and panel.wb == bench,
		"ordinary Configuration opens the mounted Workbench actor panel"): return
	var actor_page: Control = panel.tabs.get_current_tab_control()
	check(is_instance_valid(actor_page) and actor_page.name == &"Actors" and actor_page.is_ancestor_of(panel.model)
		and panel.model.item_count > 0 and not panel.model.disabled,
		"the active Actors tab offers the composed actor catalogue")
	panel.close_requested.emit()
	check(not panel.visible,"closing Configuration returns to ordinary authoring")
	if not await until(settled,"ordinary native authoring owner is idle"): return
	var mark := Vector2i(96,96)
	var falling := Vector2i(160,96)
	bench._brush.value = 2
	if not check(bench.paint(mark,Setup.WALL),"ordinary paint admits a small material edit"): return
	if not await until(settled,"ordinary Wall edit reaches native cells"): return
	var painted: bool = await native_cell(mark)==Setup.WALL
	check(painted,"ordinary paint installs the actual native Wall material")
	if not check(bench.paint(mark,0),"ordinary erase admits an explicit Empty edit"): return
	if not await until(settled,"ordinary Empty edit reaches native cells"): return
	var erased: bool = await native_cell(mark)==0
	check(erased,"ordinary erase removes the actual native material")
	if not check(bench.paint(falling,Setup.SAND),"ordinary dynamic Sand edit admitted"): return
	if not await until(settled,"ordinary Sand edit reaches native cells"): return
	check(await native_cell(falling)==Setup.SAND,"ordinary dynamic material exists before native stepping")
	var before_tick := int(worker.paint_state().tick)
	if not check(bench.toggle_pause(),"ordinary Play starts the native owner"): return
	if not await until(func() -> bool: return int(host.latest_snapshot.tick_index)>=before_tick+12,
		"ordinary native simulation completes at least twelve ticks"): return
	if not check(bench.toggle_pause(),"ordinary Pause stops further requested progression"): return
	if not await until(settled,"ordinary native owner reaches a paused readback boundary"): return
	var after_tick := int(worker.paint_state().tick)
	check(after_tick>=before_tick+12 and not worker.has_failed(),"ordinary World reports actual positive completed native ticks")
	check(await native_cell(falling)==0,"ordinary Sand actually moves under native simulation")
	# The source capability is exercised too, without replacing the World or
	# changing the accepted default solver merely to fit the persistent profile.
	bench.paint_editor.select_material(Setup.SAND)
	if check(bench.place_source(Vector2i(320,64)),"ordinary host source configuration remains admitted"):
		await until(func() -> bool: return bool(host.tower_context.get("workbench_source",{}).get("armed",false)),
			"ordinary host source receives native acknowledgement")
	check(int(worker.paint_state().generation)==int(host.latest_snapshot.render_world_generation),
		"ordinary material edits and source keep the same native World generation")
	report.merge({"native_generation":int(worker.paint_state().generation),"native_session_generation":receipt.session_generation,
		"definition_sha256":checked.hash,"constructor_receipt_sha256":receipt.receipt_hash,
		"completed_native_ticks":after_tick-before_tick,"tick_before":before_tick,"tick_after":after_tick,
		"extent":[host.world_extent.x,host.world_extent.y],"gameplay_options":defaults,
		"wave_enabled":bool(wave.get("enabled",false)),"paint_erase_native_readback":painted and erased},true)
	if DisplayServer.get_name()!="headless" and not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("ordinary-workbench.png"))==OK,
			"ordinary Workbench actual graphical framebuffer captured")


func native_cell(point: Vector2i) -> int:
	if not await until(settled,"ordinary native stored-cell readback boundary"): return -1
	var state: Dictionary = worker.paint_state()
	var admitted: Dictionary = worker.paint_queue({"kind":"capture","region":Rect2i(point,Vector2i.ONE),
		"expected_generation":int(state.generation),"expected_revision":int(state.revision),"expected_tick":int(state.tick)})
	if not check(admitted.get("status","")=="queued","ordinary actual stored-cell readback admitted"): return -1
	if not await until(func() -> bool: return worker.paint_state().get("receipt_ready",false),"ordinary native readback completes"): return -1
	var captured: Dictionary = worker.paint_take_result()
	if not check(captured.get("status","")=="completed" and captured.get("materials",PackedInt32Array()).size()==1,
		"ordinary native readback returns the actual material identity: "+str(captured)): return -1
	return int(captured.materials[0])


func finish() -> void:
	if is_instance_valid(host) and current_scene==host:
		var navigation := root.get_node_or_null("FeatureNavigation")
		if check(navigation!=null,"ordinary feature navigation autoload is present"):
			navigation.return_to_launcher()
			await until(func() -> bool: return current_scene!=null and current_scene.scene_file_path=="res://feature_launcher.tscn",
				"ordinary immediate menu navigation remains functional",30000)
	report.merge({"schema":1,"checks":checks,"failures":failures.size(),"errors":failures,
		"graphical":DisplayServer.get_name()!="headless","process_id":OS.get_process_id(),
		"godot":Engine.get_version_info(),"display":DisplayServer.get_name()},true)
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("ordinary-workbench.json"),FileAccess.WRITE)
		if file!=null:
			file.store_string(JSON.stringify(report,"  "))
			file.close()
		else: check(false,"ordinary qualification evidence can be written")
	print("GEN006_ORDINARY_WORKBENCH ",JSON.stringify({"checks":checks,"failures":failures.size(),
		"graphical":DisplayServer.get_name()!="headless","process_id":OS.get_process_id(),
		"native_generation":report.get("native_generation",-1),"completed_native_ticks":report.get("completed_native_ticks",0)}))
	quit(0 if failures.is_empty() else 1)
