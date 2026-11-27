extends "res://tests/test_persistent_areas_workbench.gd"

var trace: Array = []
var a_cells := ""
var a_history := ""

func keypress(key: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.physical_keycode = key
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await process_frame

func launcher_ready() -> bool:
	return current_scene != null and current_scene.scene_file_path=="res://feature_launcher.tscn"

func open_area() -> bool:
	if not check(launcher_ready(),"launcher owns the active scene before Areas"):return false
	current_scene.launch("persistent_areas")
	if not await until(func():return current_scene!=null and current_scene.scene_file_path=="res://persistent_areas.tscn","persistent production scene selected"):return false
	host=current_scene
	controller=host.persistent_areas
	worker=host.simulation_worker
	bench=host.shared_workbench
	return await until(settled,"full persistent source acknowledgement",180000)

func exit_area() -> bool:
	var old:WeakRef=weakref(host)
	if not check(controller.request_exit("launcher"),"durable exit to launcher"):return false
	if not await until(launcher_ready,"durable Areas save and scene teardown"):return false
	host=null
	worker=null
	bench=null
	controller=null
	await process_frame
	return check(old.get_ref()==null,"old resident host destroyed")

func ordinary_sandbox() -> bool:
	current_scene.launch("sandbox")
	if not await until(func():return current_scene!=null and current_scene.scene_file_path=="res://main.tscn","ordinary desktop scene selected"):return false
	var desktop:Variant=current_scene
	desktop.paused=true
	desktop.update_worker_frame_state()
	if not await until(func():return not desktop.tower_context.get("native_default_demo",{}).is_empty(),"default constructor authority bootstrap"):return false
	var bridge:Variant=ClassDB.instantiate(&"CyberDemoBridge")
	var chosen:=PackedInt32Array()
	for choice:Dictionary in bridge.liquid_policy_assignment_choices(bridge.default_liquid_policy(),3):
		if choice.accepted and choice.family=="cellular_yield_v1" and choice.variant=="reference":
			chosen=choice.request
			break
	var panel:Variant=desktop.microscenario_panel.liquid_panel
	panel.refresh(desktop.tower_context)
	panel.requested_policy=chosen
	panel.session_picker.select(1)
	panel.geometry_picker.select(0)
	panel.normalize_water.set_pressed_no_signal(false)
	panel.refresh(desktop.tower_context)
	var admitted:bool=panel.apply_active()
	print("F5_PREP ",JSON.stringify({"policy_len":chosen.size(),"definition":desktop.microscenario_definition.get("id",""),"origin":desktop.tower_context.get("native_default_demo",{}),"active":desktop.tower_context.get("active",false),"can":desktop.liquid_comparison_can_apply_active(true),"model":str(desktop.actor_model_selection),"rig":str(desktop.physical_rig_id),"reason":desktop.microscenario_error,"refusal":panel._refusal,"admitted":admitted,"player_representation":str(desktop.player_representation)}))
	if not check(not chosen.is_empty() and desktop.microscenario_definition.is_empty() and admitted,"ordinary active Water fallback accepts with empty definition"):return false
	if not await until(func():return desktop._liquid_default_active and desktop.pending_microscenario_apply.is_empty(),"ordinary native Water/physical ownership committed"):return false
	for model:StringName in [&"physical/barrel",&"",&"physical/ripper",&""]:
		var frame_before:int=desktop.simulation_worker.paint_state().generation
		await keypress(KEY_F5)
		var actors:Variant=desktop.actor_prototype_panel
		if not await until(func():return actors.visible,"actual F5 opens model chooser"):return false
		actors.configure_selection(model,&"human",false)
		var buttons=actors.find_children("*","Button",true,false).filter(func(b):return b.text=="Apply + restore this map")
		if not check(buttons.size()==1 and not buttons[0].disabled,"real restore button available"):return false
		buttons[0].pressed.emit()
		var expected:=str(model).trim_prefix("physical/")
		if not await until(func():return desktop.pending_microscenario_apply.is_empty() and str(desktop.physical_trial_arm)==expected and int(desktop.simulation_worker.paint_state().generation)>frame_before,"F5 "+str(model)+" commits new no-definition World/owner",60000):return false
		check(desktop.microscenario_definition.is_empty() and desktop._liquid_default_active,"no-definition desktop retained")
		trace.append({"event":"F5","model":str(model),"owner":str(desktop.physical_trial_arm),"generation":desktop.simulation_worker.paint_state().generation,"receipt":desktop.tower_context.get("liquid_construction_receipt",{}).get("receipt_hash","")})
		if actors.visible: actors.hide()
	var old:WeakRef=weakref(desktop)
	await keypress(KEY_F2)
	if not await until(launcher_ready,"F2 leaves ordinary desktop"):return false
	await process_frame
	return check(old.get_ref()==null,"ordinary desktop and physical owner retired")

func ordinary_blank(cycle:int) -> bool:
	current_scene.launch("shared_workbench")
	if not await until(func():return current_scene!=null and current_scene.get("shared_workbench")!=null and not current_scene.shared_workbench.applied.is_empty(),"ordinary blank Workbench ready"):return false
	var ordinary:Variant=current_scene
	var shared:Variant=ordinary.shared_workbench
	if not check(not ordinary.has_method("persistent_operation_allowed") and shared.applied.actors.is_empty(),"blank session has independent owner"):return false
	if not check(shared.paint(Vector2i(82+cycle,66),Setup.METAL),"blank Workbench admits distinct native edit"):return false
	if not await until(func():return not ordinary.simulation_worker.paint_state().get("legacy_busy",false),"blank owner edit settled"):return false
	trace.append({"event":"ordinary-blank","cycle":cycle,"history":JSON.stringify(shared.applied.edits).sha256_text(),"worker":ordinary.simulation_worker.get_instance_id()})
	var old:WeakRef=weakref(ordinary)
	await keypress(KEY_F2)
	if not await until(launcher_ready,"F2 closes ordinary blank"):return false
	await process_frame
	return check(old.get_ref()==null,"ordinary blank owner retired before reopened Areas")

func cases() -> void:
	if change_scene_to_file("res://feature_launcher.tscn")!=OK:return
	if not await until(launcher_ready,"launcher mounted"):return
	if not await open_area():return
	var initial:Dictionary=await native_materials(Rect2i(0,0,512,512))
	if not check(initial.has("materials") and initial.materials.count(0)<262144,"occupied active resident A"):return
	if not check(bench.paint(Vector2i(453,62),Setup.WALL),"resident sentinel admitted"):return
	if not await until(func():return not worker.paint_state().get("legacy_busy",false) and controller.status().areas.a.dirty,"A native sentinel dirtied"):return
	var source:Dictionary=await native_materials(Rect2i(0,0,512,512))
	a_cells=material_digest(source.materials)
	a_history=JSON.stringify(bench.applied.edits).sha256_text()
	if not check(a_cells!=material_digest(initial.materials),"sentinel visibly changed native A"):return
	if not await exit_area():return
	if not await ordinary_sandbox():return
	for i:int in 2:
		if not await ordinary_blank(i):return
		if not await open_area():return
		var reopened:Dictionary=await native_materials(Rect2i(0,0,512,512))
		check(controller.active_area=="a" and material_digest(reopened.materials)==a_cells and JSON.stringify(bench.applied.edits).sha256_text()==a_history,"durable A survives independent blank and normal teardown")
		trace.append({"event":"reopened-A","cycle":i,"revision":controller.manifest.revision,"digest":material_digest(reopened.materials),"history":JSON.stringify(bench.applied.edits).sha256_text(),"worker":worker.get_instance_id()})
		if not await exit_area():return

func run() -> void:
	root.size=Vector2i(1280,720)
	await cases()
	check(trace.size()==8,"four F5 transitions, two distinct blanks, two recovered Areas")
	var receipt:Dictionary={"checks":checks,"failures":failures,"pid":OS.get_process_id(),"display":DisplayServer.get_name(),"trace":trace,"area_digest":a_cells,"area_history":a_history}
	write_json(output.path_join("areas-f5.json"),receipt)
	print("PERSISTENT_F5_ISOLATION ",JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
