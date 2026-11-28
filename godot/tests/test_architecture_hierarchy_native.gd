extends SceneTree
## Actual Workbench delegation, explicit rejection/revision, acknowledged Stop,
## and fresh-source recovery. Harness decisions stand in for owner buttons only.
const Demo=preload("res://scripts/batch_lab/architecture_hierarchy_demo.gd")
const Catalogue=preload("res://scripts/batch_lab/native_module_catalogue.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Session=preload("res://scripts/batch_lab/architecture_stage_session.gd")
const Workflow=preload("res://scripts/batch_lab/architecture_workflow.gd")
const Setup=preload("res://scripts/workbench_setup.gd")
var main: Control
var wb: Control
var session: Node
var workflow: Node
var evidence:=""
var checks:=0
var failures:=0
var core_capacity:=1024
var decisions: Array=[]
var workers: Array=[]
var initial_records: Array=[]
var result: Dictionary={}

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	var development:=OS.get_environment("ARCHITECTURE_DEVELOPMENT_CORE_CAPACITY")
	if not development.is_empty():
		core_capacity=int(development)
		if core_capacity<1 or core_capacity>256:quit(2);return
		ProjectSettings.set_setting("cybersand/native_active_core_capacity",core_capacity)
	run.call_deferred()

func check(value: bool,label: String) -> bool:
	checks+=1;print("HIERARCHY_NATIVE_CHECK ",label," ",value)
	if not value:failures+=1;push_error(label)
	return value

func until(predicate: Callable,label: String,timeout_ms:=120000) -> bool:
	var deadline:=Time.get_ticks_msec()+timeout_ms
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	return check(predicate.call(),label)

func write_json(name_text: String,value: Variant) -> void:
	var file:=FileAccess.open(evidence.path_join(name_text),FileAccess.WRITE)
	if check(file!=null,"retain "+name_text):file.store_string(Compiler.canonical(value));file.close()

func choose(identity: String) -> bool:
	for index: int in session.plan.stages.size():
		if session.plan.stages[index].id==identity:return check(workflow.select(index).ok,"select "+identity)
	return check(false,"missing stage "+identity)

func apply_selected() -> bool:
	var preview: Dictionary=await workflow.preview_selected()
	if not check(preview.get("ok",false),"exact task projection "+session.stage().id+" / "+str(preview.get("reason",""))):return false
	var observed: Dictionary=await wb.capture_batch_source(Compiler.rect(session.stage().region))
	if not check(observed.get("ok",false) and observed.config.source_provenance.crop_sha256==session.preview.source_sha256,"preview independent zero-write native witness"):return false
	decisions.append({"kind":"harness-owner-approve","stage_id":session.stage().id,"preview_sha256":session.preview.preview_sha256})
	var admitted: Dictionary=await workflow.approve()
	if not check(admitted.get("queued",false) and not admitted.get("completed",true),"fresh approval queues only selected stage"):return false
	if not await until(func()->bool:return not session.busy(),"native terminal "+session.stage().id):return false
	var record: Dictionary=session.records.back()
	return check(record.status=="completed" and record.final_readback_available and record.result_sha256==record.expected_sha256 \
		and Session.receipt_accounting(record.native_receipts,record.budget).complete,"verified actual native completion "+session.stage().id+" / "+session.message)

func run() -> void:
	evidence=OS.get_environment("ARCHITECTURE_HIERARCHY_DIR")
	if evidence.is_empty():evidence=ProjectSettings.globalize_path("user://architecture/hierarchy")
	DirAccess.make_dir_recursive_absolute(evidence)
	var bridge: Object=ClassDB.instantiate(&"CyberDemoBridge")
	set_meta("cybersand_feature","shared_workbench")
	set_meta("cybersand_playable_recovery",{"workbench":Setup.fresh(bridge.default_liquid_policy(),Vector2i(512,512))})
	change_scene_to_file("res://main.tscn");await scene_changed
	main=current_scene;wb=main.shared_workbench
	if not await until(func()->bool:return not wb.applied.is_empty() and not wb.busy() and main.pending_microscenario_apply.is_empty(),"ordinary512 native World installed"):await finish();return
	var templates:=Catalogue.template_library()
	if not check(templates.ok,"typed catalogue available"):await finish();return
	session=Session.new();session.wb=wb;session.library=templates.library;root.add_child(session)
	workflow=Workflow.new();root.add_child(workflow);workflow.bind_session(session)
	var built:=Demo.build(templates.library)
	if not check(built.ok,"finite high-level composition validates / "+str(built.get("reason",""))):await finish();return
	write_json("original-campaign.json",built.campaign)
	if not check(workflow.load_campaign(built.campaign).ok,"composition loaded without native execution"):await finish();return
	for identity: String in ["workshop-frame","service-parts"]:
		if not choose(identity) or not await apply_selected():await finish();return
	choose("optional-screen")
	if not check((await workflow.preview_selected()).ok and workflow.skip().ok,"owner rejects an otherwise valid optional proposal without writes"):await finish();return
	decisions.append({"kind":"harness-owner-skip","stage_id":"optional-screen","reason":"Keep the central workshop visually open."})
	choose("access-gallery")
	var refused: Dictionary=await workflow.preview_selected()
	if not check(not refused.get("ok",true),"conflicting gallery is refused before native admission"):await finish();return
	decisions.append({"kind":"native-preview-refusal","stage_id":"access-gallery","reason":refused.reason})
	if not check(workflow.revise_workshop_gallery().ok,"owner revises the proposal around the protected passage") or not await apply_selected():await finish();return
	for identity: String in ["mounted-ribs","service-connection","controlled-wear"]:
		if not choose(identity):await finish();return
		var before: Dictionary=await wb.capture_batch_source(Compiler.rect(session.stage().region))
		var prepared: Dictionary=await workflow.prepare_selected_job()
		if not check(prepared.get("ok",false) and prepared.get("zero_writes",false),"bounded worker prepares from actual native context "+identity+" / "+str(prepared.get("reason",""))):await finish();return
		var after: Dictionary=await wb.capture_batch_source(Compiler.rect(session.stage().region))
		if not check(before.config.source_cells==after.config.source_cells,"worker proposal leaves actual source unchanged"):await finish();return
		workers.append(prepared.worker.duplicate(true))
		if not await apply_selected():await finish();return
	choose("cladding-trial")
	if not check((await workflow.preview_selected()).ok and (await workflow.approve()).get("queued",false),"owner begins bounded cladding trial"):await finish();return
	if not await until(func()->bool:return not session._receipts.is_empty() or not session.busy(),"actual cladding receipt prefix witnessed"):await finish();return
	workflow.cancel()
	if not await until(func()->bool:return not session.busy(),"Stop drains admitted prefix and verifies terminal"):await finish();return
	var partial: Dictionary=session.records.back()
	if not check(partial.status=="partial" and partial.checked_cells>0 and partial.checked_cells<61440 and partial.final_readback_available,"acknowledged partial prefix is retained without claiming the unbuilt suffix"):await finish();return
	decisions.append({"kind":"harness-owner-stop","stage_id":"cladding-trial","checked_cells":partial.checked_cells,"result_sha256":partial.result_sha256})
	initial_records=session.records.duplicate(true)
	write_json("stopped-session.json",{"records":initial_records,"workflow":workflow.export_history()})
	var before_recovery: Dictionary=await wb.capture_batch_source(Demo.AREA)
	if not check(before_recovery.get("ok",false),"full stopped prefix captured before recovery"):await finish();return
	var stopped_file:=FileAccess.open(evidence.path_join("stopped-workshop.u16le"),FileAccess.WRITE)
	stopped_file.store_buffer(before_recovery.config.source_cells);stopped_file.close()
	var proposed_recovery: Dictionary=await workflow.propose_workshop_recovery()
	if not check(proposed_recovery.get("ok",false) and proposed_recovery.get("zero_writes",false),"owner recovery control inspects the actual stopped region and proposes finite tasks / "+str(proposed_recovery.get("reason",""))):await finish();return
	var recovery: Dictionary=workflow.campaign.export_history()
	var after_proposal: Dictionary=await wb.capture_batch_source(Demo.AREA)
	if not check(after_proposal.get("ok",false) and after_proposal.config.source_cells==before_recovery.config.source_cells,"recovery proposal leaves every actual native cell unchanged"):await finish();return
	check(workflow.summary().prior_campaigns==1,"rejection revision and stopped decisions remain in bounded prior history")
	write_json("recovery-campaign.json",recovery.campaign)
	for identity: String in ["clear-stopped-prefix","open-workshop-bays","attach-workshop-bays"]:
		if not choose(identity) or not await apply_selected():await finish();return
	if not check(workflow.campaign.summary().state=="completed","fresh recovery campaign reaches verified native completion"):await finish();return
	var final_plane: Dictionary=await wb.capture_batch_source(Demo.AREA)
	if not check(final_plane.get("ok",false),"independent final native material readback"):await finish();return
	var cells: PackedByteArray=final_plane.config.source_cells
	var unchanged:=true;var passage_clear:=true;var attachment_cells:=0
	for y: int in 512:
		for x: int in 512:
			var offset:=(y*512+x)*2
			var allowed_attachment: bool=(Rect2i(64,144,8,16).has_point(Vector2i(x,y)) or Rect2i(440,144,8,16).has_point(Vector2i(x,y)))
			if allowed_attachment:
				if before_recovery.config.source_cells.decode_u16(offset)!=0 or cells.decode_u16(offset)!=58:unchanged=false
				else:attachment_cells+=1
			elif not Demo.RECOVERY_AREA.has_point(Vector2i(x,y)) and cells.decode_u16(offset)!=before_recovery.config.source_cells.decode_u16(offset):unchanged=false
			if Compiler.rect(Demo.PASSAGE).has_point(Vector2i(x,y)) and cells.decode_u16(offset)!=0:passage_clear=false
	check(unchanged and attachment_cells==256 and passage_clear,"recovery preserves completed geometry except its exact separately approved Empty-only hangers")
	var attached: Dictionary=session.records.back()
	check(attached.stage_id=="attach-workshop-bays" and attached.checked_cells==1024 and attached.changed_cells==1024 and attached.stage.connections.size()==128,"all128 declared face contacts belong to the1024-cell independently approved attachment stage")
	var file:=FileAccess.open(evidence.path_join("workshop.u16le"),FileAccess.WRITE);file.store_buffer(cells);file.close()
	wb._name.text="m67-delegated-workshop"
	if not check(wb.save_setup(),"ordinary authored Save start retains final actual World"):await finish();return
	var bytes:=FileAccess.get_file_as_bytes(Setup._path(wb._name.text))
	file=FileAccess.open(evidence.path_join("workshop-start.json"),FileAccess.WRITE);file.store_buffer(bytes);file.close()
	check(session.save_session(evidence.path_join("workshop-session.json")).ok,"native receipts and recovery stages saved separately")
	write_json("workshop-workflow.json",workflow.export_history())
	check(templates.library.save(evidence.path_join("workshop-modules.json")).ok,"reusable observed module library retained")
	result={"plane":"workshop.u16le","plane_sha256":Compiler.digest(cells),"start":"workshop-start.json","start_sha256":Compiler.digest(bytes),
		"stopped_plane":"stopped-workshop.u16le","stopped_plane_sha256":Compiler.digest(before_recovery.config.source_cells),
		"extent":[512,512],"delegated_workers":workers,"owner_decisions":decisions,"partial_checked_cells":partial.checked_cells,
		"final_campaign_state":workflow.campaign.summary().state,"prior_campaigns":workflow.summary().prior_campaigns,
		"preserved_outside_recovery_except_declared_attachments":unchanged,"approved_outside_recovery_cells":attachment_cells,"protected_passage_empty":passage_clear,"original_records":initial_records.size(),"all_records":session.records.size()}
	await finish()

func finish() -> void:
	if not evidence.is_empty():write_json("hierarchy-native.json",{"format":"cybersand-native-hierarchy-witness-v1","checks":checks+1,"failures":failures,"result":result,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"godot":Engine.get_version_info().string,"platform":OS.get_name(),"core_capacity":core_capacity,
		"real_model_calls":0,"scope":"Actual native geometry and acknowledged recovery through authored and procedural tasks. Harness owner decisions; no multi-model inference or owner acceptance."})
	print("ARCHITECTURE_HIERARCHY_NATIVE: %d checks, %d failures"%[checks,failures])
	if is_instance_valid(workflow):workflow.queue_free()
	if is_instance_valid(session):session.queue_free()
	if is_instance_valid(main):main.queue_free()
	await process_frame;await process_frame
	quit(1 if failures else 0)
