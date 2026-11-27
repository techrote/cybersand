extends SceneTree
const Setup=preload("res://scripts/workbench_setup.gd")
const Protocol=preload("res://scripts/workbench_reciprocal_protocol.gd")
var host:Control
var bench:Control
var panel:Control
var observations:Dictionary={}
var failures:Array[String]=[]
var destination:String
var checks:=0
var planes:Dictionary={}
var native_records:Dictionary={}
var complete:=false

class ShortcutObserver:
	extends Node
	var key:Key
	var observe:Callable
	func _input(event:InputEvent)->void:
		if event is InputEventKey and event.keycode==key and event.ctrl_pressed and event.pressed and not event.echo:
			observe.call(event)

func _initialize()->void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	destination=OS.get_environment("SWARM004_UI_EVIDENCE")
	run.call_deferred()

func require(value:bool,label:String)->bool:
	checks+=1
	if not value:failures.append(label);push_error("SWARM006_INPUT_INTEGRITY "+label)
	return value

func until(predicate:Callable,label:String,seconds:int=40)->bool:
	var end:=Time.get_ticks_msec()+seconds*1000
	while Time.get_ticks_msec()<end:
		if predicate.call():return true
		await process_frame
	return require(false,label)

func settled()->bool:
	return bench!=null and not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty()

func dispatch_mouse(point:Vector2,down:bool)->void:
	var motion:=InputEventMouseMotion.new();motion.position=point;Input.parse_input_event(motion)
	var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	Input.parse_input_event(event)
	# Godot accumulates synthetic input. Deliver it before a frame can retire
	# the actual native child or preparation thread whose guard is under test.
	Input.flush_buffered_events()

func mouse(point:Vector2,down:bool)->void:
	dispatch_mouse(point,down);await process_frame

func input_dispatch_state()->Dictionary:
	return {"phase":panel.phase,"busy":panel.busy(),"visible":panel.visible,
		"territory_mode":panel._paint.button_pressed,"thread_pending":panel._thread!=null,
		"thread_started":panel._thread!=null and panel._thread.is_started(),
		"thread_alive":panel._thread!=null and panel._thread.is_alive(),"child_pid":panel._pid,
		"child_alive":panel._pid>0 and OS.is_process_running(panel._pid),
		"paint_dragging_at_dispatch":bench.paint_editor.dragging}

func click(button:Control)->void:
	var point:=button.get_global_rect().get_center()
	await mouse(point,true);await mouse(point,false)

func dispatch_click(button:Control)->void:
	var point:=button.get_global_rect().get_center()
	dispatch_mouse(point,true);dispatch_mouse(point,false)

func point_for(cell:Vector2i)->Vector2:
	var content:Rect2=host.view_content_rect()
	return host.world_view.global_position+content.position+(Vector2(cell)+Vector2(0.5,0.5)-Vector2(host.camera_origin).floor())/Vector2(host.current_view_size)*content.size

func capture(stage:String)->Dictionary:
	if not await until(func()->bool:return not host.simulation_worker.paint_state().get("legacy_busy",false),"legacy brush settles"):return {}
	var state:Dictionary=host.simulation_worker.paint_state()
	var admitted:Dictionary=host.simulation_worker.material_capture_request(int(state.generation),2048*2048*2)
	if not require(admitted.get("ok",false),"capture admitted: "+str(admitted)):return {}
	var result:Dictionary={}
	var end:=Time.get_ticks_msec()+20000
	while result.is_empty() and Time.get_ticks_msec()<end:
		result=host.simulation_worker.material_capture_poll(int(admitted.token));await process_frame
	var released:Dictionary=host.simulation_worker.material_capture_finish(int(admitted.token),false)
	if not require(result.get("ok",false) and released.get("ok",false),"capture complete"):return {}
	var file:=FileAccess.open(destination+"/"+stage+".le16",FileAccess.WRITE);file.store_buffer(result.cells);file.close()
	planes[stage]=Protocol.digest(result.cells)
	return result

func blank()->bool:
	if panel!=null:
		panel.cancel("isolated repro case reset")
		if not await until(func()->bool:return not panel.busy(),"previous panel settles"):return false
		var focus:=root.gui_get_focus_owner()
		if focus!=null:focus.release_focus()
	if not require(bench.apply(Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))),"blank fixture admitted"):return false
	if not await until(settled,"blank fixture installed"):return false
	bench.open_reciprocal();panel=bench.reciprocal_panel
	panel.protected_points.clear();panel.activation.assign([Vector2i(64,48)])
	panel.gentek_controls.frame.enabled.button_pressed=false;panel.gentek_controls.mosaic.enabled.button_pressed=false
	panel._paint.button_pressed=false
	panel.controls.profile.select(0);panel._select_expression(0)
	panel.controls.width.value=192;panel.controls.height.value=112;panel.controls.layout.select(0);panel.controls.border.value=4
	panel.controls.seed.value=605;panel.controls.rounds.value=2;panel.controls.shared_extent.value=13
	panel.controls.shared_ownership.button_pressed=true;panel.controls.clutter.value=0;panel.controls.destruction.value=0
	panel.controls.compact_native_termination.button_pressed=true;panel.controls.supported_native_receptors.button_pressed=true
	panel.controls.negotiated_recovery.button_pressed=true
	await process_frame
	return true

func retain_native(label:String)->void:
	var hashes:Dictionary={}
	for name:String in ["request.txt","result.json"]:
		var target:=destination+"/"+label+"-"+name
		var file:=FileAccess.open(target,FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(panel._job_dir+"/"+name));file.close()
		hashes[label+"-"+name]=FileAccess.get_sha256(target)
	native_records[label]=hashes

func generated(label:String,positive:bool=true)->bool:
	if not await until(func()->bool:return not panel.busy(),label+" native generation settles"):return false
	if not require(panel.phase=="ready" and not panel.document.is_empty() and (not positive or panel.document.get("can_apply",false)),label+" native result: "+panel.status):return false
	retain_native(label)
	return true

func generate(label:String)->bool:
	return require(panel.generate(),label+" generation admitted") and await generated(label)

func screenshot(label:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	require(root.get_texture().get_image().save_png(destination+"/"+label+".png")==OK,"retain actual input screenshot: "+label)

func type_number(field:SpinBox,text:String)->void:
	var line:=field.get_line_edit();line.grab_focus();line.select_all()
	for character:String in text:
		for down:bool in [true,false]:
			var event:=InputEventKey.new();event.pressed=down;event.unicode=character.unicode_at(0);event.keycode=character.unicode_at(0)
			Input.parse_input_event(event);await process_frame

func shortcut(code:Key)->void:
	var focus:=root.gui_get_focus_owner()
	if focus!=null:focus.release_focus()
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.ctrl_pressed=true;event.pressed=down
		Input.parse_input_event(event);await process_frame

func dispatch_shortcut(code:Key)->void:
	var focus:=root.gui_get_focus_owner()
	if focus!=null:focus.release_focus()
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.ctrl_pressed=true;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events()

func numeric_case(independent:bool)->void:
	var label:="independent" if independent else "shared"
	if not await blank():return
	if independent:panel.gentek_controls.frame.enabled.button_pressed=true
	if not await generate(label+"-initial"):return
	var before:=await capture(label+"-before")
	var field:SpinBox=panel.gentek_controls.frame.values.cohesion if independent else panel.controls.seed
	var previous:float=field.value
	var typed:="0.2" if independent else "606"
	var applies:int=panel.completed_applies;var edits:Array=bench.applied.edits.duplicate(true)
	await type_number(field,typed)
	var item:Dictionary={"typed_text":field.get_line_edit().text,"old_value":previous,"pending_value":field.value,
		"retired_before_apply":panel.document.is_empty() and panel._apply.disabled and panel.phase=="idle"}
	require(item.typed_text==typed and item.pending_value==previous,"real keys leave pending visible "+label+" text")
	require(item.retired_before_apply,"pending "+label+" text retires native Apply before another action")
	await screenshot(label+"-pending")
	await click(panel._apply);await process_frame
	item["apply_delta"]=panel.completed_applies-applies
	require(item.apply_delta==0 and bench.applied.edits==edits,"old Apply cannot install after "+label+" text edits")
	await click(panel._generate)
	if not await generated(label+"-typed",false):return
	var native_value:float=panel.document.input.frame.profile.cohesion if independent else panel.document.input.frame.seed
	item["committed_value"]=field.value;item["native_value"]=native_value
	item["typed_generate_matches"]=is_equal_approx(field.value,float(typed)) and is_equal_approx(native_value,float(typed))
	require(item.typed_generate_matches,"actual Generate commits and transports the typed "+label+" value")
	var after:=await capture(label+"-after")
	item["world_unchanged"]=before.cells==after.cells;item["history_unchanged"]=bench.applied.edits==edits
	require(item.world_unchanged and item.history_unchanged,"numeric preview/regeneration preserves World and history")
	observations[label]=item

func gesture_case()->void:
	if not await blank() or not await generate("gesture-initial"):return
	var before:=await capture("gesture-before")
	var applies:int=panel.completed_applies;var edits:Array=bench.applied.edits.duplicate(true)
	panel._paint.button_pressed=true;panel._tool.select(1)
	await mouse(point_for(Vector2i(70,50)),true)
	var item:Dictionary={"new_protected_count":panel.protected_points.size(),"retired_on_press":panel.document.is_empty() and panel._apply.disabled and panel.phase=="idle","dragging_on_press":panel._dragging}
	require(item.new_protected_count>0 and item.dragging_on_press,"actual Protect press starts a native territory edit")
	require(item.retired_on_press,"initial territory press retires old native authority before release")
	await screenshot("territory-pressed")
	await mouse(panel._apply.get_global_rect().get_center(),false);await click(panel._apply)
	var after:=await capture("gesture-after")
	item["apply_delta"]=panel.completed_applies-applies;item["world_unchanged"]=before.cells==after.cells;item["history_unchanged"]=bench.applied.edits==edits
	require(item.apply_delta==0 and item.world_unchanged and item.history_unchanged,"territory edit cannot install the previous proposal")
	observations["gesture"]=item

func busy_case(kind:String)->void:
	if not await blank():return
	var label:="busy-"+kind
	var before:=await capture(label+"-before")
	var applies:int=panel.completed_applies;var edits:Array=bench.applied.edits.duplicate(true)
	panel._paint.button_pressed=kind!="off";panel._tool.select(0)
	bench._tool.select(0);bench.paint_editor.select_tool("Brush");bench.paint_editor.select_material(2)
	if not require(panel.generate(),label+" generation admitted"):return
	var item:Dictionary={}
	if kind=="hidden":
		if not await until(func()->bool:return panel.phase=="preparing" and panel._thread!=null,"actual preparing thread observed"):return
		item["thread_pending_before_hide"]=panel._thread!=null;panel.hide()
		item["job_observed"]=panel.busy() and not panel.visible and panel._thread!=null
	else:
		if not await until(func()->bool:return panel.phase=="running" and OS.is_process_running(panel._pid),"actual native child observed"):return
		item["child_pid"]=panel._pid;item["child_alive_before_input"]=OS.is_process_running(panel._pid)
		item["job_observed"]=panel.phase=="running" and item.child_alive_before_input
	item["phase_before_input"]=panel.phase;item["visible_before_input"]=panel.visible;item["territory_mode_before_input"]=panel._paint.button_pressed
	require(item.job_observed,label+" uses real pending work rather than a fabricated phase")
	var dispatch:Dictionary={"press_count":0}
	var observe:Callable=func(event:InputEvent)->void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			dispatch["press_count"]+=1
			dispatch.merge(input_dispatch_state(),true)
	# Read the actual canvas signal without consuming the event or changing
	# production state. No frame is yielded before the dispatch witness closes.
	host.world_view.gui_input.connect(observe)
	dispatch_mouse(point_for(Vector2i(300,250)),true)
	host.world_view.gui_input.disconnect(observe)
	dispatch["paint_dragging_after_dispatch"]=bench.paint_editor.dragging
	item["input_dispatch"]=dispatch
	var live_work:bool=dispatch.get("thread_pending",false) and dispatch.get("thread_started",false) \
		if kind=="hidden" else dispatch.get("child_alive",false) and int(dispatch.get("child_pid",-1))>0
	require(dispatch.press_count==1 and dispatch.get("busy",false) and live_work
		and dispatch.get("phase","")==("cancelling" if kind=="hidden" else "running")
		and dispatch.get("visible",null)==(kind!="hidden") and dispatch.get("territory_mode",null)==(kind!="off"),
		label+" actual canvas press observes the required busy owner")
	require(dispatch.get("paint_dragging_at_dispatch",true)==false and not dispatch.paint_dragging_after_dispatch,
		label+" synchronous input dispatch cannot enter Paint")
	await process_frame
	item["paint_dragging_after_press"]=bench.paint_editor.dragging
	require(not item.paint_dragging_after_press,label+" input cannot enter Paint")
	await mouse(point_for(Vector2i(300,250)),false)
	if not await until(settled,label+" work settles"):return
	var after:=await capture(label+"-after")
	item["apply_delta"]=panel.completed_applies-applies;item["world_unchanged"]=before.cells==after.cells;item["history_unchanged"]=bench.applied.edits==edits
	require(item.apply_delta==0 and item.world_unchanged and item.history_unchanged,label+" leaves every native cell and authored row unchanged")
	observations[label]=item;panel.show()

func keyboard_case()->void:
	if not await blank():return
	panel._paint.button_pressed=false;bench._tool.select(0);bench.paint_editor.select_tool("Brush");bench.paint_editor.select_material(2)
	var baseline:=await capture("idle-baseline")
	await mouse(point_for(Vector2i(300,250)),true);await mouse(point_for(Vector2i(300,250)),false)
	if not await until(settled,"ordinary idle Paint completes"):return
	var painted:=await capture("idle-painted")
	var item:Dictionary={"idle_paint_changes_world":baseline.cells!=painted.cells,"idle_paint_history":bench.paint_editor._undo_stack.size()>0}
	observations["keyboard"]=item
	require(item.idle_paint_changes_world and item.idle_paint_history,"ordinary idle Paint remains admitted and undoable")
	for code:Key in [KEY_Z,KEY_Y]:
		var label:="undo" if code==KEY_Z else "redo"
		var before:=await capture("keyboard-"+label+"-before")
		var edits:Array=bench.applied.edits.duplicate(true)
		var history:Array=[bench.paint_editor._undo_stack.size(),bench.paint_editor._redo_stack.size()]
		var applies:int=panel.completed_applies
		if not require(panel.generate(),"keyboard "+label+" real generation admitted"):return
		if not await until(func()->bool:return panel.phase=="running" and OS.is_process_running(panel._pid),"keyboard "+label+" actual live child observed"):return
		item[label+"_child_pid"]=panel._pid;item[label+"_child_live"]=OS.is_process_running(panel._pid)
		item[label+"_callback_refused"]=not (bench.paint_editor.undo() if code==KEY_Z else bench.paint_editor.redo())
		var button:Button=bench.paint_editor._undo_button if code==KEY_Z else bench.paint_editor._redo_button
		item[label+"_button_disabled"]=button.disabled
		require(item[label+"_callback_refused"] and item[label+"_button_disabled"],"busy "+label+" refuses its direct history callback and disables its button")
		var button_dispatch:Dictionary={"press_count":0}
		var observe_button:Callable=func(event:InputEvent)->void:
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
				button_dispatch["press_count"]+=1;button_dispatch.merge(input_dispatch_state(),true)
				button_dispatch["button_disabled"]=button.disabled
		button.gui_input.connect(observe_button)
		dispatch_click(button)
		button.gui_input.disconnect(observe_button)
		button_dispatch["paint_dragging_after_dispatch"]=bench.paint_editor.dragging
		item[label+"_button_dispatch"]=button_dispatch
		require(button_dispatch.press_count==1 and button_dispatch.get("button_disabled",false)
			and button_dispatch.get("busy",false) and button_dispatch.get("phase","")=="running"
			and button_dispatch.get("child_alive",false) and button_dispatch.get("child_pid",-1)==item[label+"_child_pid"],
			"busy "+label+" button dispatch observes the same live native child")
		item[label+"_child_live_before_shortcut"]=panel._pid>0 and OS.is_process_running(panel._pid)
		if not require(item[label+"_child_live_before_shortcut"],"actual child remains live immediately before "+label+" shortcut"):return
		var key_dispatch:Dictionary={"press_count":0}
		var observer:=ShortcutObserver.new();observer.key=code
		observer.observe=func(event:InputEventKey)->void:
			key_dispatch["press_count"]+=1;key_dispatch.merge(input_dispatch_state(),true)
			key_dispatch.merge({"keycode":int(event.keycode),"ctrl_pressed":event.ctrl_pressed,"pressed":event.pressed,"echo":event.echo})
		# This last-added, read-only observer sees the actual key before the
		# Workbench handles it. Button and key delivery never yield ownership.
		root.add_child(observer)
		dispatch_shortcut(code)
		root.remove_child(observer);observer.free()
		key_dispatch["paint_dragging_after_dispatch"]=bench.paint_editor.dragging
		key_dispatch["history_unchanged_after_dispatch"]=bench.applied.edits==edits \
			and history==[bench.paint_editor._undo_stack.size(),bench.paint_editor._redo_stack.size()]
		key_dispatch["apply_delta_after_dispatch"]=panel.completed_applies-applies
		item[label+"_shortcut_dispatch"]=key_dispatch
		require(key_dispatch.press_count==1 and key_dispatch.get("busy",false) and key_dispatch.get("phase","")=="running"
			and key_dispatch.get("child_alive",false) and key_dispatch.get("child_pid",-1)==item[label+"_child_pid"],
			"busy "+label+" shortcut dispatch observes the same live native child")
		require(not button_dispatch.get("paint_dragging_at_dispatch",true) and not button_dispatch.paint_dragging_after_dispatch
			and not key_dispatch.get("paint_dragging_at_dispatch",true) and not key_dispatch.paint_dragging_after_dispatch
			and key_dispatch.history_unchanged_after_dispatch and key_dispatch.apply_delta_after_dispatch==0,
			"busy "+label+" button and shortcut preserve history and Apply authority before yielding")
		if not await until(settled,"keyboard "+label+" work settles"):return
		var after:=await capture("keyboard-"+label+"-after")
		item[label+"_blocked"]=before.cells==after.cells and bench.applied.edits==edits and history==[bench.paint_editor._undo_stack.size(),bench.paint_editor._redo_stack.size()]
		require(item[label+"_child_live"] and item[label+"_blocked"],"real busy "+label+" shortcut preserves native World and history")
		await shortcut(code)
		if not await until(settled,"ordinary idle "+label+" completes"):return
		var restored:=await capture("idle-"+label)
		item["idle_"+label+"_works"]=restored.cells==(baseline.cells if code==KEY_Z else painted.cells)
		require(item["idle_"+label+"_works"],"ordinary idle Paint "+label+" remains functional")

func run()->void:
	root.size=Vector2i(1920,1080);set_meta("cybersand_feature","shared_workbench")
	if not require(not destination.is_empty(),"explicit evidence destination"):quit(1);return
	DirAccess.make_dir_recursive_absolute(destination)
	host=load("res://main.tscn").instantiate();root.add_child(host);bench=host.shared_workbench
	if await until(settled,"native Workbench startup",120):
		await numeric_case(false);await numeric_case(true);await gesture_case()
		for kind:String in ["active","off","hidden"]:await busy_case(kind)
		await keyboard_case()
	complete=observations.size()==7 and failures.is_empty()
	require(complete,"all actual input integrity cases completed")
	var report:Dictionary={"schema":1,"completed":complete,"checks":checks,"failures":failures,"cases":observations,
		"native_planes_sha256":planes,"native_records_sha256":native_records,"native_source":panel._runtime if panel!=null else {},"engine":Engine.get_version_info().string,
		"platform":OS.get_name(),"display":DisplayServer.get_name(),"test_sha256":FileAccess.get_sha256("res://tests/swarm006_reciprocal_input.gd"),
		"scope":"actual keyboard/mouse native source integrity and preserved idle Paint; no research or owner acceptance"}
	var file:=FileAccess.open(destination+"/input-integrity.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	if host!=null:host.queue_free();await process_frame;await process_frame
	print("SWARM006_INPUT_INTEGRITY ",JSON.stringify(report))
	quit(0 if complete else 1)
