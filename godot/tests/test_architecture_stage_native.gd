extends SceneTree
## Actual ordinary Workbench native construction, history, recovery and examples.
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Examples = preload("res://scripts/batch_lab/architecture_examples.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Session = preload("res://scripts/batch_lab/architecture_stage_session.gd")
class ExecutorProbe extends RefCounted:
	signal native_receipt(receipt: Dictionary)
	var batch_sequence := 2
	var active := false
class DependencyRaceSession extends Session:
	var after_dependency: Callable
	func _verify_dependencies(value: Dictionary, inspected: Dictionary) -> Dictionary:
		var answer: Dictionary = await super._verify_dependencies(value,inspected)
		if answer.get("ok",false) and answer.get("additional_inspection",false) and after_dependency.is_valid():
			await after_dependency.call()
		return answer
var main: Control
var wb: Control
var panel: Window
var session: Node
var checks := 0
var failures := 0
var evidence := ""
var example_results: Array = []

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print("ARCHITECTURE_NATIVE_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)
	return value

func until(test: Callable, label: String, timeout_ms := 90000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not test.call() and Time.get_ticks_msec()<deadline: await process_frame
	return check(test.call(),label)

func installed() -> bool:
	return not wb.applied.is_empty() and not wb.busy() and main.pending_microscenario_apply.is_empty()

func reset_world() -> bool:
	for field: SpinBox in wb._extent: field.value=512
	if not check(wb.new_canvas(),"new native 512-square authored World admitted"): return false
	return await until(func(): return installed() and Setup.extent_of(wb.applied)==Vector2i(512,512),"native 512-square World installed")

func simple(id := "first", region := Rect2i(16,16,64,64)) -> Dictionary:
	var item := Compiler.stage_defaults(id,region)
	item.materials = [0,58,28]
	item.operations = [{"shape":"rectangle","x0":region.position.x+4,"y0":region.position.y+40,"x1":region.position.x+59,"y1":region.position.y+43,"material":58}]
	item.budget.max_checked_cells=224
	return {"format":Compiler.FORMAT,"id":"native-stage-fixture","intent":"Qualify approved native geometry","stages":[item]}

func finish_stage(label: String) -> bool:
	if not await until(func(): return not session.busy(),label): return false
	return check(session.stage_state()=="completed",label+" has complete native evidence / "+session.message)

func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: check(false,"write evidence "+path); return
	file.store_string(Compiler.canonical(value))
	file.close()

func verify_session_fences(first: Dictionary) -> void:
	check(Session.receipt_accounting(first.native_receipts,first.budget).complete,"independent real native receipts satisfy exact completion accounting")
	var excluded: Array = first.native_receipts.duplicate(true)
	excluded[0].confirmed-=1
	excluded[0].readback.pop_back()
	excluded[0].excluded=1
	check(not Session.receipt_accounting(excluded,first.budget).complete,"excluded native write cannot complete even with matching final geometry")
	var unchanged: Array = first.native_receipts.duplicate(true)
	unchanged[0].changed-=1
	unchanged[0].unchanged=1
	check(not Session.receipt_accounting(unchanged,first.budget).complete,"another writer's matching cell cannot impersonate an approved native change")
	var partial_receipt: Array = first.native_receipts.duplicate(true)
	partial_receipt[0].status="partial"
	check(not Session.receipt_accounting(partial_receipt,first.budget).complete,"partial receipt status cannot complete a stage")
	var probe: Node=Session.new()
	root.add_child(probe)
	var probe_plan:=simple("retention-envelope")
	var fixture: Dictionary={"format":Session.FORMAT,"plan":probe_plan,"plan_sha256":Compiler.digest(Compiler.canonical(probe_plan).to_utf8_buffer()),
		"records":[{"kind":"historical-test","payload":"retained native evidence"}],"imported_history":[{"scope":"fixture","payload":"x".repeat(8192)}]}
	var path:=evidence.path_join("session-envelope-fixture.json")
	write_json(path,fixture)
	check(probe.open_session(path).ok,"historical evidence fixture reopens without claiming current completion")
	probe._retain({"kind":"decision-fixture","nested":{"values":[1,2,3]}})
	var actual_envelope_bytes:=Compiler.canonical(probe._envelope(probe.plan,probe.states,probe.records,probe.imported_history)).to_utf8_buffer().size()
	check(probe._envelope_bytes(probe.plan,probe.states)==actual_envelope_bytes,"bounded accounting equals independent full serialization including history and plan")
	check(probe._can_retain(Session.MAX_FILE_BYTES-actual_envelope_bytes-1,probe.plan,probe.states),"exact remaining evidence capacity is admitted")
	check(not probe._can_retain(Session.MAX_FILE_BYTES-actual_envelope_bytes,probe.plan,probe.states),"full envelope refuses the first byte beyond the bound")
	var events: Array=[]
	probe.terminal.connect(func(record: Dictionary) -> void: events.append(record))
	probe._executor=ExecutorProbe.new()
	probe._submission=1
	probe._execution={"kind":"native-stage","stage_id":probe.stage().id,"stage":probe.stage(),"started_usec":Time.get_ticks_usec(),"status":"queued"}
	probe._executing=true
	probe._process(0.0)
	check(not probe.busy() and events.size()==1 and events[0].status=="partial","unexpected executor replacement emits exactly one terminal native outcome")
	check(not events[0].final_readback_available,"replacement does not invent unavailable final native readback")
	probe._process(0.0)
	check(events.size()==1,"retired replacement cannot emit duplicate terminal outcomes")
	probe.queue_free()

func verify_dependency_source_race(first: Dictionary) -> void:
	var race: Node=DependencyRaceSession.new()
	race.wb=wb
	race.library=panel.library
	root.add_child(race)
	var dependent:=simple("dependency-race",Rect2i(200,16,64,64))
	dependent.stages[0].depends_on=[first.stage_id]
	dependent.stages.push_front(first.stage.duplicate(true))
	check(race.load_plan(dependent).ok,"separate-region dependency race fixture admitted")
	race._retain(first)
	race.states[first.stage_id]="completed"
	race.select(1)
	check((await race.preview_selected()).ok,"real completed dependency outside the stage is inspected before preview")
	race.after_dependency=func() -> void:
		wb.applied.brush=0
		check(wb.paint(Vector2i(204,56),58),"human source edit admitted during separate dependency inspection")
		await until(func(): return not wb.paint_editor.busy() and not main.simulation_worker.paint_state().get("legacy_busy",false) and main.image.get_pixel(204,56).r8==58,"intervening human source edit acknowledged")
	var answer: Dictionary=await race.approve()
	check(not answer.ok and answer.reason.contains("changed since preview") and not race.busy(),"final native recapture rejects source changed during dependency await")
	check(race.records.size()==1 and race.stage_state()=="proposed","race refusal queues no stage and retains only the original dependency evidence")
	race.queue_free()

func run() -> void:
	evidence=OS.get_environment("ARCHITECTURE_EVIDENCE_DIR")
	if evidence.is_empty(): evidence=ProjectSettings.globalize_path("user://architecture-native-evidence")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,900)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main=current_scene
	wb=main.shared_workbench
	if not await until(installed,"ordinary native Workbench ready"): finish(); return
	check(wb.art_batches==null,"architecture remains lazy at normal startup")
	if not await reset_world(): finish(); return
	wb.open_architecture_lab()
	panel=wb.architecture_lab
	session=panel.session
	panel.hide()
	check(wb.art_batches==null,"opening architecture creates no Art provider or request")
	check(session.load_plan(simple()).ok,"offline typed plan loaded")
	var before: Dictionary=await wb.capture_batch_source(Rect2i(16,16,64,64))
	var preview: Dictionary=await session.preview_selected()
	check(preview.ok and preview.preview.zero_writes,"actual native inspection produces a zero-write preview")
	var after_preview: Dictionary=await wb.capture_batch_source(Rect2i(16,16,64,64))
	check(before.config.source_cells==after_preview.config.source_cells,"whole inspected native material plane unchanged by preview")
	check(session.records.is_empty(),"preview does not invent completed native records")
	check((await session.approve()).ok and session.stage_state()=="queued","approval queues without claiming completion")
	if not await finish_stage("first approved native stage"): finish(); return
	var first: Dictionary=session.records.back()
	check(first.checked_cells==224 and first.changed_cells==224 and first.native_receipts.size()>0,"exact native completion and changed-cell counts")
	check(first.native_receipts[0].backend=="CyberNativeCellWorld" and first.result_sha256==first.expected_sha256,"retained native receipts and readback bind the actual result")
	verify_session_fences(first)
	check(not wb.art_batches.provider.active and wb.art_batches.conversation.is_empty(),"native staged construction dispatches no provider and adds no conversation turn")
	var actual: Dictionary=await wb.capture_batch_source(Rect2i(16,16,64,64))
	check(actual.config.source_cells==preview.preview.projected_cells,"full native plane matches host projection")
	check(wb.paint_editor.undo(),"stage is in ordinary authoring Undo history")
	await until(func(): return not wb.paint_editor.busy(),"ordinary Undo retires")
	var undone: Dictionary=await wb.capture_batch_source(Rect2i(16,16,64,64))
	check(undone.config.source_cells==before.config.source_cells,"ordinary Undo restores every native cell")
	check(wb.paint_editor.redo(),"ordinary Redo admitted")
	await until(func(): return not wb.paint_editor.busy(),"ordinary Redo retires")
	var redone: Dictionary=await wb.capture_batch_source(Rect2i(16,16,64,64))
	check(redone.config.source_cells==actual.config.source_cells,"ordinary Redo exactly restores native stage")
	await verify_dependency_source_race(first)
	var next:=simple("stale",Rect2i(100,16,64,64))
	check(session.load_plan(next).ok and (await session.preview_selected()).ok,"stale-source fixture previewed")
	wb.applied.brush=0
	check(wb.paint(Vector2i(104,56),58),"human edit admitted after preview")
	await until(func(): return not wb.paint_editor.busy() and not main.simulation_worker.paint_state().get("legacy_busy",false) and main.image.get_pixel(104,56).r8==58,"human edit acknowledged and visible")
	check(not (await session.approve()).ok and not session.busy() and session.preview.is_empty(),"changed native source refuses approval without stale construction")
	check((await session.preview_selected()).ok,"changed source can be previewed again")
	var cancel_done: Array=[false]
	var cancel_answer: Array=[{}]
	var start_approval:=func() -> void:
		cancel_answer[0]=await session.approve()
		cancel_done[0]=true
	start_approval.call()
	session.cancel()
	await until(func(): return cancel_done[0] and not session.busy(),"cancel during native approval inspection releases session lock")
	check(not cancel_answer[0].get("ok",true),"cancelled approval never queues native construction")
	check(session.load_plan(simple("skip")).ok and session.skip().ok and session.stage_state()=="skipped","owner can skip a proposal without native execution")
	# A large unique region creates a real, timing-dependent acknowledged prefix.
	var partial:=simple("partial",Rect2i(16,96,480,384))
	partial.stages[0].operations=[{"shape":"rectangle","x0":16,"y0":96,"x1":495,"y1":479,"material":58}]
	partial.stages[0].budget.max_checked_cells=262144
	check(session.load_plan(partial).ok and (await session.preview_selected()).ok and (await session.approve()).ok,"large native stage starts")
	await until(func(): return not session._receipts.is_empty() or not session.busy(),"large stage produces native prefix")
	session.cancel()
	await until(func(): return not session.busy(),"Stop drains native prefix and captures recovery state")
	var stopped: Dictionary=session.records.back()
	check(stopped.status=="partial" and stopped.checked_cells>0 and stopped.checked_cells<480*384,"Stop records partial native work, never proposed suffix")
	check(stopped.final_readback_available and stopped.native_receipts.size()>0,"partial recovery retains actual native material plane and exact receipts")
	check(wb.paint_editor.undo(),"partial native stage can be recovered with ordinary Undo")
	await until(func(): return not wb.paint_editor.busy(),"partial recovery Undo retires")
	# Every representative is independently constructed from a fresh real World.
	for family: String in Examples.families():
		if not await reset_world(): break
		var recipe:=Examples.plan(family)
		if not check(session.load_plan(recipe).ok,"load native representative "+family): break
		var all_complete:=true
		for i: int in recipe.stages.size():
			session.select(i)
			if not check((await session.preview_selected()).ok,"representative preview "+recipe.stages[i].id+" / "+session.message): all_complete=false; break
			if not check((await session.approve()).ok,"representative approve "+recipe.stages[i].id+" / "+session.message): all_complete=false; break
			if not await finish_stage("representative native "+recipe.stages[i].id): all_complete=false; break
		if not all_complete: continue
		var size:=Examples.extent(family)
		var capture: Dictionary=await wb.capture_batch_source(Rect2i(Vector2i(16,16),size))
		if not check(capture.get("ok",false),"representative native readback "+family): continue
		var id:String=recipe.family
		var cells: PackedByteArray=capture.config.source_cells
		var plane:=FileAccess.open(evidence.path_join(id+".u16le"),FileAccess.WRITE)
		plane.store_buffer(cells); plane.close()
		Controller.material_image(cells,size).save_png(evidence.path_join(id+"-material-id.png"))
		var record:Dictionary=session.records.back()
		var row:Dictionary={"id":id,"family":family,"extent":[size.x,size.y],"plane":id+".u16le","sha256":Compiler.digest(cells),
			"recipe":recipe,"native_records":session.records.filter(func(value: Dictionary) -> bool: return value.get("kind")=="native-stage" and str(value.get("stage_id","")).begins_with(id+"-")),
			"render_scope":"Diagnostic native material IDs; graphical script produces actual Godot shader evidence."}
		example_results.append(row)
		write_json(evidence.path_join(id+"-native.json"),row)
		write_json(evidence.path_join(id+"-plan.json"),recipe)
		wb._name.text="architecture-"+id
		if check(wb.save_setup(),"ordinary portable authored start saved "+family):
			var start_bytes:=FileAccess.get_file_as_bytes(Setup._path(wb._name.text))
			var start_file:=FileAccess.open(evidence.path_join(id+"-workbench-start.json"),FileAccess.WRITE)
			if start_file!=null: start_file.store_buffer(start_bytes); start_file.close()
			check(not start_bytes.is_empty() and FileAccess.get_sha256(evidence.path_join(id+"-workbench-start.json"))==Compiler.digest(start_bytes),"portable authored start bytes preserved "+family)
		var metadata:Dictionary={"id":id+"-native-composition","name":family,"tags":["native-example",id],"part_type":"unclassified","allowed_transforms":["identity","mirror_x"]}
		check(panel.library.harvest_capture(capture,metadata).ok,"native representative becomes reusable harvested module "+family)
		check(panel.library.export_module(metadata.id,evidence.path_join(id+"-module.json")).ok,"reusable module exported "+family)
	check(example_results.size()==6,"all six independently inspectable native representative constructions completed")
	check(panel.library.save(evidence.path_join("architecture-modules.json")).ok,"native examples module library saved")
	check(session.save_session(evidence.path_join("architecture-session.json")).ok,"session saved with exact material evidence")
	wb._name.text="architecture-stage-native-reopen"
	check(wb.save_setup(),"ordinary authored native geometry saved for fresh-process reopen")
	var last: Dictionary=example_results.back() if not example_results.is_empty() else {}
	write_json(evidence.path_join("reopen-identity.json"),{"workbench_name":wb._name.text,"last":last,"session":"architecture-session.json","library":"architecture-modules.json"})
	write_json(evidence.path_join("representatives.json"),{"examples":example_results,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"godot":Engine.get_version_info().string})
	finish()

func finish() -> void:
	print("ARCHITECTURE_STAGE_NATIVE: %d checks, %d failures" % [checks,failures])
	if is_instance_valid(main): main.queue_free(); await process_frame; await process_frame
	quit(1 if failures else 0)
