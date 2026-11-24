extends SceneTree
## Source-bound ordinary Workbench construction of large finite campaigns.
## Owner approvals below are explicit harness decisions, never inferred from
## intent text. The shipped UI requires the corresponding owner button.
const Flagships=preload("res://scripts/batch_lab/architecture_flagships.gd")
const Catalogue=preload("res://scripts/batch_lab/native_module_catalogue.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Session=preload("res://scripts/batch_lab/architecture_stage_session.gd")
const Workflow=preload("res://scripts/batch_lab/architecture_workflow.gd")
const Setup=preload("res://scripts/workbench_setup.gd")
var main: Control
var wb: Control
var session: Node
var workflow: Node
var checks:=0
var failures:=0
var evidence:=""
var results: Array=[]
var core_capacity:=1024

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	var development:=OS.get_environment("ARCHITECTURE_DEVELOPMENT_CORE_CAPACITY")
	if not development.is_empty():
		core_capacity=int(development)
		if core_capacity<1 or core_capacity>256: push_error("Invalid explicit development core capacity."); quit(2); return
		ProjectSettings.set_setting("cybersand/native_active_core_capacity",core_capacity)
	run.call_deferred()

func check(value: bool,label: String) -> bool:
	checks+=1; print("FLAGSHIP_NATIVE_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)
	return value

func until(predicate: Callable,label: String,timeout_ms:=120000) -> bool:
	var limit:=Time.get_ticks_msec()+timeout_ms
	while not predicate.call() and Time.get_ticks_msec()<limit: await process_frame
	return check(predicate.call(),label)

func installed() -> bool:
	return is_instance_valid(wb) and not wb.applied.is_empty() and not wb.busy() and main.pending_microscenario_apply.is_empty()

func write_json(path: String,value: Variant) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if not check(file!=null,"open evidence "+path.get_file()): return false
	file.store_string(Compiler.canonical(value)); file.close(); return true

func capture_world(size: Vector2i) -> Dictionary:
	var plane:=PackedByteArray(); plane.resize(size.x*size.y*2)
	var captures: Array=[]
	for y: int in range(0,size.y,512):
		for x: int in range(0,size.x,512):
			var region:=Rect2i(x,y,mini(512,size.x-x),mini(512,size.y-y))
			var observed: Dictionary=await wb.capture_batch_source(region)
			if not observed.get("ok",false): return observed
			var cells: PackedByteArray=observed.config.source_cells
			for row: int in region.size.y:
				for col: int in region.size.x: plane.encode_u16(((y+row)*size.x+x+col)*2,cells.decode_u16((row*region.size.x+col)*2))
			captures.append(observed.config.source_provenance)
	return {"ok":true,"cells":plane,"sha256":Compiler.digest(plane),"captures":captures}

func run() -> void:
	evidence=OS.get_environment("ARCHITECTURE_FLAGSHIP_DIR")
	if evidence.is_empty(): evidence=ProjectSettings.globalize_path("user://architecture-flagships")
	DirAccess.make_dir_recursive_absolute(evidence)
	print("FLAGSHIP_RUNTIME ",Compiler.canonical({"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"core_capacity":core_capacity,
		"scope":"Explicit low-memory development run" if core_capacity!=1024 else "Normal production-default native allocation"}))
	var templates:=Catalogue.template_library()
	if not check(templates.ok,"source-pinned forty-part template library"): finish(); return
	var bridge: Object=ClassDB.instantiate(&"CyberDemoBridge")
	var policy: PackedInt32Array=bridge.default_liquid_policy()
	set_meta("cybersand_feature","shared_workbench")
	set_meta("cybersand_playable_recovery",{"workbench":Setup.fresh(policy,Vector2i(1024,1024))})
	change_scene_to_file("res://main.tscn"); await scene_changed
	main=current_scene; wb=main.shared_workbench
	if not await until(installed,"ordinary native Workbench installed"): finish(); return
	var requested:=OS.get_environment("ARCHITECTURE_FLAGSHIP_FAMILY")
	for family: String in Flagships.families():
		if not requested.is_empty() and family!=requested: continue
		var built:=Flagships.build(family,templates.library)
		if not check(built.ok,"finite source campaign "+family+" / "+str(built.get("reason",""))): continue
		var size:=Flagships.extent(family)
		if not check(wb.apply(Setup.fresh(policy,size)),"fresh actual native extent admitted "+family): continue
		if not await until(func()->bool: return installed() and Setup.extent_of(wb.applied)==size,"actual native extent installed "+str(size)): break
		if is_instance_valid(workflow): workflow.queue_free()
		if is_instance_valid(session): session.queue_free()
		await process_frame
		session=Session.new(); session.wb=wb; session.library=templates.library; root.add_child(session)
		workflow=Workflow.new(); root.add_child(workflow); workflow.bind_session(session)
		if not check(workflow.load_campaign(built.campaign).ok,"hierarchical campaign adopted "+family): continue
		var complete:=true; var chunks:=0; var writes:=0; var preview_rows: Array=[]
		for index: int in session.plan.stages.size():
			if not check(workflow.select(index).ok,"select finite task "+str(index+1)): complete=false; break
			var inspected: Dictionary=await workflow.preview_selected()
			if not check(inspected.get("ok",false),"exact zero-write task preview "+session.stage().id+" / "+str(inspected.get("reason",""))): complete=false; break
			var before: Dictionary=await wb.capture_batch_source(Compiler.rect(session.stage().region))
			if not check(before.get("ok",false) and before.config.source_provenance.crop_sha256==session.preview.source_sha256,"independent preview-zero-write native witness"): complete=false; break
			preview_rows.append({"stage_id":session.stage().id,"preview_sha256":session.preview.preview_sha256,"source_sha256":session.preview.source_sha256,
				"projected_sha256":session.preview.projected_sha256,"budget":session.preview.budget.duplicate(),"module_contacts":session.preview.module_contact_result})
			var admitted: Dictionary=await workflow.approve()
			if not check(admitted.get("queued",false) and not admitted.get("completed",true),"explicit harness owner approval queues this exact task"): complete=false; break
			if not await until(func()->bool:return not session.busy(),"native task retired "+session.stage().id): complete=false; break
			if not check(session.stage_state()=="completed","verified terminal task "+session.stage().id+" / "+session.message): complete=false; break
			var record: Dictionary=session.records.back()
			if not check(record.result_sha256==record.expected_sha256 and Session.receipt_accounting(record.native_receipts,record.budget).complete,"independent exact native receipts and projected/readback agreement"): complete=false; break
			chunks+=record.native_receipts.size(); writes+=int(record.changed_cells)
		if not complete:
			session.save_session(evidence.path_join(family+"-failed-session.json"))
			continue
		check(workflow.campaign.summary().state=="completed","entire native hierarchy complete "+family)
		var observed: Dictionary=await capture_world(size)
		if not check(observed.get("ok",false),"independently inspect full actual native World "+family): continue
		var path:=evidence.path_join(family+".u16le")
		var output:=FileAccess.open(path,FileAccess.WRITE); output.store_buffer(observed.cells); output.close()
		var clearances_ok:=true
		for raw: Array in Flagships.clearances(family):
			var area:=Compiler.rect(raw)
			for y: int in range(area.position.y,area.end.y):
				for x: int in range(area.position.x,area.end.x):
					if observed.cells.decode_u16((y*size.x+x)*2)!=0: clearances_ok=false
		check(clearances_ok,"independent native macro void and intended route occupancy "+family)
		wb._name.text="m67-"+family
		if not check(wb.save_setup(),"ordinary authored Save start "+family): continue
		var start_bytes:=FileAccess.get_file_as_bytes(Setup._path(wb._name.text))
		output=FileAccess.open(evidence.path_join(family+"-workbench-start.json"),FileAccess.WRITE); output.store_buffer(start_bytes); output.close()
		check(not start_bytes.is_empty(),"portable authored start bytes retained "+family)
		check(session.save_session(evidence.path_join(family+"-session.json")).ok,"exact native session retained "+family)
		write_json(evidence.path_join(family+"-campaign.json"),built.campaign)
		write_json(evidence.path_join(family+"-workflow.json"),workflow.export_history())
		write_json(evidence.path_join(family+"-previews.json"),preview_rows)
		var witness: Dictionary=built.witness
		witness["start_path"]=family+"-workbench-start.json"
		var row:={"id":family,"title":Flagships.TITLES[family],"extent":[size.x,size.y],"plane":family+".u16le","sha256":observed.sha256,
			"module_placements":built.module_count,"stages":session.plan.stages.size(),"native_receipt_chunks":chunks,"changed_cells":writes,
			"captures":observed.captures,"start_path":witness.start_path,"start_sha256":Compiler.digest(start_bytes),"witness":witness,
			"all_tasks_completed":true,"clearance_occupancy_verified":clearances_ok,"actor_traversal":"not-established-by-this-static-campaign"}
		results.append(row)
		write_json(evidence.path_join(family+"-native.json"),row)
	check(results.size()==(1 if not requested.is_empty() else Flagships.families().size()),"every requested native flagship completed")
	check(templates.library.save(evidence.path_join("flagship-modules.json")).ok,"reusable modules and separate native observations retained")
	finish()

func finish() -> void:
	if not evidence.is_empty(): write_json(evidence.path_join("flagships-native.json"),{"format":"cybersand-native-flagship-campaign-v1","examples":results,"checks":checks+1,"failures":failures,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"godot":Engine.get_version_info().string,"platform":OS.get_name(),"core_capacity":core_capacity,
		"real_model_calls":0,"scope":"Actual native material construction through finite hierarchy and ordinary Workbench authority; no actor traversal or physical owner acceptance inferred."})
	print("ARCHITECTURE_FLAGSHIPS_NATIVE: %d checks, %d failures"%[checks,failures])
	if is_instance_valid(workflow): workflow.queue_free()
	if is_instance_valid(session): session.queue_free()
	if is_instance_valid(main): main.queue_free()
	await process_frame; await process_frame
	quit(1 if failures else 0)
