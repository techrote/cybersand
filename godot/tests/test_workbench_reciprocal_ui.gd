extends SceneTree

# Uses the actual Main scene, native worker, UI input dispatch and persistence.
# Two OS processes are required: create, then reopen the exact saved start.
const Setup=preload("res://scripts/workbench_setup.gd")
var host:Control
var bench:Control
var panel:Control
var checks:=0
var failures:Array[String]=[]
var completed:=false
var capture_index:=0
var evidence:=OS.get_environment("SWARM004_UI_EVIDENCE")
var mode:=OS.get_environment("SWARM004_UI_MODE")

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok:bool,label:String)->bool:
	checks+=1
	if not ok: failures.append(label);push_error("SWARM004_WORKBENCH "+label)
	return ok

func until(predicate:Callable,label:String,seconds:int=30)->bool:
	var deadline:=Time.get_ticks_msec()+seconds*1000
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return check(false,label)

func settled()->bool:
	return bench!=null and not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty()

func find_button(node:Node,text:String)->Button:
	if node is Button and node.text==text: return node
	for child:Node in node.get_children():
		var found:=find_button(child,text)
		if found!=null: return found
	return null

func click(control:Control)->void:
	var position:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=position;Input.parse_input_event(motion)
	await process_frame
	for down:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event);await process_frame

func capture()->Dictionary:
	var state:Dictionary=host.simulation_worker.paint_state()
	var admitted:Dictionary=host.simulation_worker.material_capture_request(int(state.generation),2048*2048*2)
	if not check(admitted.get("ok",false),"independent full native capture admitted"): return {}
	var result:Dictionary={}
	var deadline:=Time.get_ticks_msec()+15000
	while result.is_empty() and Time.get_ticks_msec()<deadline:
		result=host.simulation_worker.material_capture_poll(int(admitted.token))
		await process_frame
	var finished:Dictionary=host.simulation_worker.material_capture_finish(int(admitted.token),false)
	check(result.get("ok",false) and finished.get("ok",false),"independent capture completed and lease released")
	return result

func screenshot(name_value:String)->void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence+"/"+name_value+".png")==OK,"original interactive capture "+name_value)

func paint_activation(single_location:bool=false)->void:
	var content:Rect2=host.view_content_rect()
	var view:Control=host.world_view
	var a:=view.global_position+content.position+content.size*Vector2(0.38,0.52)
	var b:=view.global_position+content.position+content.size*Vector2(0.58,0.52)
	if single_location:
		# The preregistered known-seed transaction example uses one indicator
		# dab at local64,48. Dispatch actual canvas input; never inject masks.
		a=view.global_position+content.position+(Vector2(64.5,48.5)-Vector2(host.camera_origin).floor())/Vector2(host.current_view_size)*content.size
		b=a
	var event:=InputEventMouseButton.new();event.position=a;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	Input.parse_input_event(event);await process_frame
	for i:int in 8:
		var motion:=InputEventMouseMotion.new();motion.position=a.lerp(b,float(i)/7.0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion);await process_frame
	event=InputEventMouseButton.new();event.position=b;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false
	Input.parse_input_event(event);await process_frame
	check(not panel.activation.is_empty(),"actual canvas brush sets approximate native activation territory")

func known_transaction_recipe()->void:
	# Fixed before evaluation from the registered605 layout matrix. This is a
	# zero-joint authoring example, not a reciprocal-construction certificate.
	panel.controls.width.value=128;panel.controls.height.value=96
	panel.controls.profile.select(1);panel.controls.profile.item_selected.emit(1)
	panel.controls.layout.select(2);panel.controls.layout.item_selected.emit(2)
	panel.controls.border.value=4;panel.controls.shared_extent.value=13
	panel.controls.seed.value=605;panel.controls.rounds.value=2
	panel.controls.clutter.value=0.15;panel.controls.destruction.value=0
	panel.controls.orientation.select(0);panel.controls.optional.button_pressed=true

func lifecycle(baseline:Dictionary)->void:
	for action:String in ["cancel","hide","timeout"]:
		if not panel.visible:panel.open_panel()
		await click(panel._generate)
		if not await until(func()->bool:return panel.phase=="running" and panel._pid>0,"real bounded lifecycle child starts"):return
		var pid:int=panel._pid
		check(OS.is_process_running(pid),action+" fixture is an actual running OS child")
		if action=="cancel":await click(find_button(panel,"Cancel"))
		elif action=="hide":await click(find_button(panel,"Close"))
		if not await until(func()->bool:return panel.phase=="idle" and panel._pid<0 and panel._thread==null,
			"native child is reaped after "+action,35):return
		check(await until(func()->bool:return process_absent(pid),"independent native probe confirms child retirement",2),action+" leaves no child process")
		check((await capture()).cells==baseline.cells and bench.applied.edits.is_empty(),action+" preserves native World and authored history")
		if action=="timeout":check("30-second" in panel.status,"actual wall-clock timeout reports its bounded refusal")
	panel.open_panel();await click(panel._generate)
	if not await until(func()->bool:return panel.phase=="running" and panel._pid>0,"shutdown lifecycle child starts"):return
	var pid:int=panel._pid
	host.queue_free();await process_frame;await process_frame;host=null;panel=null
	check(await until(func()->bool:return process_absent(pid),"shutdown native child retirement",2),"actual Workbench tree teardown retires the running child")
	completed=true

func process_absent(pid:int)->bool:
	# OS.kill retires Godot's child bookkeeping. The test fixture independently
	# probes the OS so the assertion does not query an already reaped handle.
	return OS.execute(OS.get_environment("CYBERSAND_SWARM004_CLI"),PackedStringArray(["probe",str(pid)]))==0

func create_map()->void:
	if not check(bench.apply(Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))),"finite blank source admitted"): return
	if not await until(settled,"finite blank source installed"): return
	var baseline:=await capture()
	if baseline.is_empty(): return
	check(bench.reciprocal_panel==null,"experimental dock has no hidden startup instance or computation")
	var open:=find_button(bench,"Reciprocal assembly…")
	if not check(open!=null,"experimental composition entry is available"): return
	await click(open)
	panel=bench.reciprocal_panel
	if not check(panel!=null and panel.visible,"real button opens one lazy inline dock"): return
	check(panel._pid<0 and panel._thread==null,"opening the dock launches no generation")
	if mode=="create":known_transaction_recipe()
	await paint_activation(mode=="create")
	if mode=="lifecycle":await lifecycle(baseline);return
	if mode=="smoke":
		await screenshot("dock-open")
		await click(find_button(panel,"Close"))
		check(not panel.visible and panel._pid<0,"Close retires preview work")
		completed=true;return
	var request_seed:=OS.get_environment("SWARM004_UI_SEED")
	if not request_seed.is_empty(): panel.controls.seed.value=int(request_seed)
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase in ["ready","idle"],"native child generation reaches terminal result"):return
	if not check(panel.phase=="ready" and not panel.document.is_empty(),"source-matched native evidence produced: "+panel.status):return
	check(panel._pid<0 and panel._thread==null,"completed native child and parsing worker are reaped")
	var preview:=await capture()
	check(preview.cells==baseline.cells,"real native preview leaves all World cells unchanged")
	await screenshot("native-preview")
	if mode=="blocked":
		check(not panel.document.can_apply and panel._apply.disabled,"blocked native proposal cannot be installed")
		for i:int in panel._layer.item_count:
			panel._layer.select(i);panel._render();await process_frame
		check(panel.prepared.recipe.parameters.clutter==0 and panel.prepared.recipe.parameters.destruction==0,
			"independent native decoration and destruction defaults are explicit")
		await click(panel._apply)
		check((await capture()).cells==baseline.cells and bench.applied.edits.is_empty(),"disabled Apply preserves World and authored history")
		await click(find_button(panel,"Close"))
		check(panel._pid<0 and panel._thread==null and not panel.visible,"closing blocked preview leaves no computation")
		completed=true;return
	if not check(panel.document.can_apply,"native composition independently authorizes Apply: "+panel.status):return
	check(panel.prepared.recipe.origin==Vector2i.ZERO and panel.prepared.recipe.activation==[Vector2i(64,48)] \
		and panel.prepared.recipe.layout=="centered_frame_rectangle" and panel.prepared.recipe.border==4,
		"visible controls and actual brush reproduce the declared transaction territory")
	var expected:PackedByteArray=baseline.cells.duplicate()
	for at:int in range(0,panel.proposal.cells.size(),3):
		var cells:PackedInt32Array=panel.proposal.cells
		expected.encode_u16((cells[at+1]*512+cells[at])*2,cells[at+2])
	await click(panel._apply)
	if not await until(func()->bool:return panel.completed_applies==1,"actual Apply receives native acknowledgement"):return
	var applied:=await capture()
	check(applied.cells==expected,"Apply equals the exact complete native proposal and all retained source cells")
	await screenshot("native-applied")
	await click(panel._undo_button)
	if not await until(func()->bool:return panel.completed_undos==1,"actual Undo receives native acknowledgement"):return
	var undone:=await capture()
	check(undone.cells==baseline.cells and bench.applied.edits.is_empty(),"Undo restores all native cells and original authored history")
	await screenshot("native-undone")
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase=="ready","same-seed regeneration completes"):return
	await click(panel._apply)
	if not await until(func()->bool:return panel.completed_applies==2,"second actual Apply receives acknowledgement"):return
	check((await capture()).cells==expected,"same-seed regenerated native construction is exact")
	bench._name.text="swarm004-interactive-evaluation"
	var save:=find_button(bench,"Save start [Ctrl+S]")
	if not check(save!=null,"ordinary Save start button exists"):return
	await click(save)
	var saved:=Setup.read_named(bench._name.text)
	check(not saved.has("error") and saved.setup.edits==bench.applied.edits,"ordinary Save persists acknowledged composition history")
	check(FileAccess.file_exists(Setup._path(bench._name.text)+".swarm004.json"),"saved map has optional source/revision evidence receipt")
	var file:=FileAccess.open(evidence+"/expected-native.le16",FileAccess.WRITE)
	if not check(file!=null,"fresh-process expected plane can be recorded"):return
	file.store_buffer(expected);file.close()
	await screenshot("native-saved")
	completed=true

func reopen_map()->void:
	bench._name.text="swarm004-interactive-evaluation"
	await click(find_button(bench,"Load start"))
	if not await until(settled,"saved map installs in a fresh OS process"):return
	var actual:=await capture()
	var expected:=FileAccess.get_file_as_bytes(evidence+"/expected-native.le16")
	check(actual.get("cells")==expected and expected.size()==512*512*2,"fresh-process native World exactly matches saved composition plane")
	check(not bench.applied.edits.is_empty(),"fresh-process authored history includes construction stamps")
	await click(find_button(bench,"Reciprocal assembly…"));panel=bench.reciprocal_panel
	await click(find_button(panel,"Inspect saved evidence"))
	if not await until(func()->bool:return panel.phase=="historical","saved native evidence opens in the fresh process"):return
	check(panel._apply.disabled and panel._pid<0 and panel.prepared.recipe.layout=="centered_frame_rectangle" \
		and panel.prepared.recipe.border==4,"saved ownership and revision evidence is inspection-only without child generation")
	await screenshot("native-reopened")
	completed=true

func run()->void:
	root.size=Vector2i(1920,1080)
	if not evidence.is_empty():DirAccess.make_dir_recursive_absolute(evidence)
	if OS.get_environment("SWARM004_REQUIRE_GRAPHICS")=="1" and not check(DisplayServer.get_name()!="headless","graphical qualification has a real display"):
		quit(1);return
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate();root.add_child(host)
	bench=host.shared_workbench
	if await until(settled,"real Shared Workbench startup completed",60):
		if mode=="reopen":await reopen_map()
		else:await create_map()
	check(completed,"complete interactive test sequence reached its final assertion")
	var report:Dictionary={"schema":1,"mode":mode,"checks":checks,"failures":failures,"completed":completed,
		"engine":Engine.get_version_info().string,"platform":OS.get_name(),"process_id":OS.get_process_id(),
		"display":DisplayServer.get_name(),
		"test_sha256":FileAccess.get_sha256("res://tests/test_workbench_reciprocal_ui.gd")}
	if panel!=null:
		report["native_receipt"]=panel.last_receipt;report["native_source"]=panel._runtime
		report["native_status"]=panel.document.get("status","");report["native_reason"]=panel.document.get("reason","")
		report["joint_count"]=panel.document.get("joints",[]).size();report["obligation_count"]=panel.document.get("obligations",[]).size()
		report["scope"]="actual native authoring transaction and persistence; reciprocal research acceptance remains separate"
		report["reciprocal_acceptance"]=false
	if host!=null:host.queue_free();await process_frame;await process_frame
	if not evidence.is_empty():
		var file:=FileAccess.open(evidence+"/"+mode+".json",FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SWARM004_WORKBENCH ",JSON.stringify(report))
	quit(1 if not failures.is_empty() else 0)
