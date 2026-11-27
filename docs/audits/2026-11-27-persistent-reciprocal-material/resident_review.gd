extends "res://tests/test_persistent_areas_workbench.gd"

# Mounted native Current/FreeMass travel and durability with an adversarial
# programmatic call through the otherwise disabled reciprocal UI entry.
var panel: Variant
var sampled := {}
var details := {}

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	host = PersistentScene.instantiate()
	root.add_child(host)
	current_scene = host
	controller = host.persistent_areas
	bench = host.shared_workbench
	worker = host.simulation_worker
	if await until(settled,"source-matched resident profile active",180000):
		check(host.paused and controller.active_area=="a","frozen active A")
		if mode=="write": await write_case()
		else: await reopen_case()
	if controller != null and not controller.busy:
		if check(controller.request_exit("launcher"),"durable quit through owner"):
			await until(func() -> bool: return current_scene==null or current_scene.scene_file_path=="res://feature_launcher.tscn","durable exit")
	var result := {"checks":checks,"failures":failures,"pid":OS.get_process_id(),"display":DisplayServer.get_name(),"mode":mode,"state":sampled,"details":details}
	write_json(output.path_join("review-"+mode+".json"),result)
	print("AREAS_RECIPROCAL_REVIEW ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func record(label:String) -> String:
	var captured:Dictionary=await native_materials(Rect2i(0,0,512,512))
	if captured.is_empty(): return ""
	var cells:PackedInt32Array=captured.materials
	var digest:=material_digest(cells)
	sampled[label]={"area":controller.active_area,"digest":digest,"history":JSON.stringify(bench.applied.edits).sha256_text(),"generation":worker.paint_state().generation,"revision":worker.paint_state().revision,"authoring_generation":worker.paint_state().authoring_generation,"occupied":262144-cells.count(0)}
	return digest

func same_state(before:String,after:String,check_generation:bool=true) -> void:
	var keys:=["area","digest","history","occupied"]
	if check_generation: keys.append_array(["generation","revision","authoring_generation"])
	for field in keys: check(sampled[before][field]==sampled[after][field],before+" matches "+after+" for "+field)

func material_refusal(label:String) -> void:
	bench.open_materials_lab()
	var owner:Variant=bench.material_audition
	var state:Dictionary=owner.material_audition_state()
	var request:Dictionary=owner.request_material_audition({"session_id":state.session_id,"world_id":state.get("world_id","0"),"expected_revision":0,"profile":{"schema_version":1,"profile_id":"resident-density-negative","materials":[{"material_id":2,"density":500}],"reactions":[]}})
	check(not state.ok and request.get("code")=="owner_unavailable" and "default material laws" in str(request.get("error","")),label+" explicitly refuses nondefault material law")
	var demo:Dictionary=owner.request_material_audition_demo("density-sorter")
	check(not demo.ok and "ordinary Workbench" in str(demo.get("error","")),label+" explicitly refuses fresh demo replacement")
	check(bench._pending_material_demo.is_empty() and host.pending_microscenario_apply.is_empty(),label+" leaves no pending demo or replacement")
	details[label]={"request":request,"demo":demo}
	bench._materials_lab_window.hide()

func request_travel(id:String) -> bool:
	if not check(controller.request_travel(id),"travel "+id+" admitted"):return false
	if not await operation_finished("handoff "+id):return false
	return check(controller.active_area==id and await until(settled,"settled active "+id),"selected durable area "+id)

func write_case() -> void:
	if (await record("pristine")).is_empty():return
	check(sampled.pristine.occupied>0 and sampled.pristine.occupied<262144,"actual occupied World has empty and solid native materials")
	if not check(bench.paint(Vector2i(475,44),Setup.WALL),"real ordinary edit on occupied A"):return
	if not await until(func() -> bool: return not worker.paint_state().get("legacy_busy",false) and controller.status().areas.a.dirty,"A dirty frontier visible after native paint"):return
	if (await record("dirty")).is_empty():return
	check(sampled.pristine.digest!=sampled.dirty.digest and sampled.pristine.history!=sampled.dirty.history,"ordinary sentinel changes actual material and one authored history")
	var frontier:Dictionary=controller._cache.entry("a").duplicate(true)
	material_refusal("A material before")
	var routes:=bench.find_children("*","Button",true,false).filter(func(button:Node)->bool:return button.text=="Reciprocal assembly\u2026")
	if not check(routes.size()==1 and routes[0].disabled and "ordinary Workbench" in routes[0].tooltip_text,"ordinary Areas UI disables reciprocal construction with its scope"):return
	details["button"]={"disabled":routes[0].disabled,"tooltip":routes[0].tooltip_text}
	bench.open_reciprocal()
	panel=bench.reciprocal_panel
	if not check(panel!=null and panel.visible,"real reciprocal dock mounted"):return
	panel.controls.width.value=128
	panel.controls.height.value=96
	panel.controls.profile.select(1);panel.controls.profile.item_selected.emit(1)
	panel.controls.layout.select(2);panel.controls.layout.item_selected.emit(2)
	panel.controls.border.value=4;panel.controls.shared_extent.value=13
	panel.controls.seed.value=4099;panel.controls.rounds.value=2
	panel.controls.clutter.value=0;panel.controls.destruction.value=0
	panel.controls.orientation.select(0);panel.controls.optional.button_pressed=true
	panel.controls.shared_ownership.button_pressed=false
	var target:=Vector2i(215,64)
	host.camera_origin=Vector2.ZERO
	host.update_worker_frame_state()
	var bounds:Rect2=host.view_content_rect()
	var p:Vector2=bounds.position+(Vector2(target)+Vector2(0.5,0.5)-host.camera_origin.floor())/Vector2(host.current_view_size)*bounds.size
	var ev:=InputEventMouseButton.new();ev.position=p;ev.button_index=MOUSE_BUTTON_LEFT;ev.pressed=true
	check(panel.world_input(ev),"official territory input handles mouse down")
	ev.pressed=false;check(panel.world_input(ev),"official territory input commits one indicator")
	if not check(panel.activation.size()==1 and panel.activation[0]==target,"seeded activation entered at requested World coordinate: "+str(panel.activation)):return
	if not check(panel.generate(),"real native generator admission: "+panel.status):return
	if not await until(func() -> bool: return panel.phase in ["idle","ready"],"source-bound native proposal completed",120000):return
	details["preview"]={"phase":panel.phase,"status":panel.status,"seed":panel.controls.seed.value,"can_apply":panel.document.get("can_apply",false),"generator":panel._runtime,"count":panel.proposal.get("cells",PackedInt32Array()).size()/3}
	if not check(panel.phase=="ready" and panel.document.can_apply and panel.proposal.cells.size()>0 and panel._thread==null and panel._pid<0,"genuine nonempty reciprocal proposal from occupied A: "+panel.status):return
	if not check(not panel.apply_construction() and "ordinary Workbench" in panel.status,"retained construction replacement explicitly refused: "+panel.status):return
	details["apply_refusal"]=panel.status
	check(panel._capture_token==0 and panel._thread==null and panel._pid<0,"native capture and generator process released")
	check(panel.completed_applies==0 and panel.completed_undos==0 and panel._pending_patch.is_empty() and panel._pending_setup.is_empty() and not panel.busy() and not bench.busy(),"failed proposal has no submitted patch, history or running lease")
	check(not panel.undo_construction(),"no partial or phantom Undo available")
	if (await record("after_refused")).is_empty():return
	same_state("dirty","after_refused")
	check(controller.status().areas.a.dirty and controller._cache.entry("a").mutation_generation>=frontier.mutation_generation,"refused actions preserve dirty resident edits")
	if not await request_travel("b"):return
	if (await record("b")).is_empty():return
	check(sampled.b.digest!=sampled.dirty.digest,"actual resident B material plane differs from A")
	check(not panel.apply_construction(),"old A proposal refused after switching to different resident World")
	material_refusal("B material after travel")
	if (await record("b_refused")).is_empty():return
	same_state("b","b_refused")
	if not await request_travel("a"):return
	if (await record("returned_a")).is_empty():return
	same_state("dirty","returned_a",false)
	details["hot_handoffs"]=controller.evidence().cache_io.hot_handoffs
	check(int(details.hot_handoffs)>0,"resident HOT handoff observed")
	if not await save_current("Save all native areas"):return
	if (await record("saved")).is_empty():return
	same_state("dirty","saved",false)
	write_json(output.path_join("expected.json"),{"a":sampled.saved,"b":sampled.b})

func reopen_case() -> void:
	var previous:Variant=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("expected.json")))
	if not check(previous is Dictionary and "a" in previous and "b" in previous,"prior complete durable profile"):return
	if (await record("reopened_a")).is_empty():return
	for key in ["digest","history","occupied"]:check(sampled.reopened_a[key]==previous.a[key],"fresh A matches saved "+key)
	material_refusal("fresh A")
	if not await request_travel("b"):return
	if (await record("reopened_b")).is_empty():return
	for key in ["digest","history","occupied"]:check(sampled.reopened_b[key]==previous.b[key],"fresh B matches saved "+key)
