extends SceneTree
## Controller/lifecycle fixtures only. Fake native terminals are explicitly
## copied test values; actual native hierarchy has a separate executable trial.
const Workflow=preload("res://scripts/batch_lab/architecture_workflow.gd")
const Session=preload("res://scripts/batch_lab/architecture_stage_session.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Campaign=preload("res://scripts/batch_lab/architecture_campaign.gd")
const Library=preload("res://scripts/batch_lab/native_module_library.gd")
const WorkerFixture=preload("res://tests/test_architecture_delegation.gd")
class FixtureSession extends Session:
	var fence:={"generation":5,"manual":0}
	var fixture_cells:=PackedByteArray()
	var fixture_region:=Rect2i(0,0,128,128)
	var worker_host: Dictionary={}
	var preparation_hook:=Callable()
	func _init() -> void:
		fixture_cells.resize(128*128*2)
		library=Library.new()
	func _observation_fence() -> Dictionary: return fence.duplicate(true)
	func _process(_delta: float) -> void: pass
	func inspection_view() -> Dictionary:
		return {"ok":true,"kind":"native-inspection-snapshot","stale":false,"region":[0,0,128,128],"cells":fixture_cells.duplicate(),
			"source_sha256":Compiler.digest(fixture_cells),"generation":5,"captured_revision":_revision,"provenance":{"kind":"copied-fixture"}}
	func preview_selected() -> Dictionary:
		if stage().get("depends_on",[]).any(func(id: String)->bool: return states.get(id)!="completed"):
			return _answer(false,"Fixture dependency is incomplete.")
		var result:=Compiler.compile(stage(),{"region":Compiler.rect_array(fixture_region),"world_region":Compiler.rect_array(fixture_region),"source_cells":fixture_cells,
			"source_sha256":Compiler.digest(fixture_cells),"generation":fence.generation,"paused":true,"allowed_materials":[0,7,28,58]},library,completed_ids())
		if not result.ok: return result
		preview=result; states[stage().id]="previewed"; changed.emit()
		return {"ok":true,"preview":preview.duplicate(true)}
	func detail_context(_region: Rect2i,_instance_id: String="") -> Dictionary:
		await get_tree().process_frame
		if preparation_hook.is_valid(): preparation_hook.call()
		var result:=worker_host.duplicate(true)
		if result.is_empty(): return {"ok":false,"reason":"No copied worker fixture."}
		result.context.source_cells=fixture_cells.duplicate()
		result.context.source_sha256=Compiler.digest(fixture_cells)
		result.context.generation=fence.generation
		return result
	func approve() -> Dictionary:
		if preview.is_empty(): return _answer(false,"Fixture preview missing.")
		_submission+=1; _executing=true; states[stage().id]="queued"; changed.emit()
		return {"ok":true,"queued":true}
	func finish_fixture() -> Dictionary:
		var count: int=preview.budget.checked_cells
		var receipts: Array=[]
		if count>0: receipts=[{"backend":"CyberNativeCellWorld","status":"completed","requested":count,"checked":count,"changed":count,"confirmed":count,
			"unchanged":0,"excluded":0,"refused":0,"readback":range(count)}]
		var record:={"kind":"native-stage","stage_id":stage().id,"plan_id":plan.id,"plan_sha256":Compiler.digest(Compiler.canonical(plan).to_utf8_buffer()),
			"stage_sha256":preview.stage_sha256,"preview_sha256":preview.preview_sha256,"generation":5,"source_sha256":preview.source_sha256,
			"expected_sha256":preview.projected_sha256,"native_submission":_submission,"status":"completed","native_receipts":receipts,
			"native_receipts_sha256":Compiler.digest(Compiler.canonical(receipts).to_utf8_buffer()),"checked_cells":count,"changed_cells":count,
			"result_sha256":preview.projected_sha256,"final_readback_available":true,"reason":"Copied fixture terminal"}
		fixture_cells=preview.projected_cells.duplicate(); preview.clear(); _executing=false; states[stage().id]="completed"
		changed.emit() # The actual session emits changed immediately BEFORE terminal.
		terminal.emit(record)
		return record

class RecoveryFixture extends FixtureSession:
	func inspection_view() -> Dictionary:
		return {"ok":true,"kind":"native-inspection-snapshot","stale":false,"region":Compiler.rect_array(fixture_region),
			"cells":fixture_cells.duplicate(),"source_sha256":Compiler.digest(fixture_cells),"generation":int(fence.generation),"provenance":{"kind":"copied-recovery-fixture"}}
	func inspect_region(region: Rect2i) -> Dictionary:
		await get_tree().process_frame
		if preparation_hook.is_valid(): preparation_hook.call()
		return inspection_view() if region==fixture_region else {"ok":false,"reason":"Fixture region differs."}

var checks:=0
var failures:=0
func check(value: bool,label: String) -> bool:
	checks+=1; print("ARCHITECTURE_WORKFLOW_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)
	return value

func graph() -> Dictionary:
	var a:=Compiler.stage_defaults("frame",Rect2i(0,0,128,128)); a.materials=[0,58]; a.budget.max_checked_cells=32
	a.operations=[{"shape":"rectangle","x0":8,"y0":100,"x1":11,"y1":100,"material":58}]
	var b:=a.duplicate(true); b.id="detail"; b.operations[0].y0=90; b.operations[0].y1=90
	return {"format":Campaign.FORMAT,"id":"workflow-fixture","title":"Two-phase authored fixture","intent":"Exercise lifecycle boundaries.","region":[0,0,128,128],
		"budget":{"native_checks":128,"raster_candidates":128,"max_retries_per_job":2},"nodes":[
		{"id":"primary","parent_id":"","title":"Primary","kind":"group","region":[0,0,128,128],"depends_on":[]},
		{"id":"finish","parent_id":"","title":"Finish","kind":"group","region":[0,0,128,128],"depends_on":["primary"]},
		{"id":"frame","parent_id":"primary","title":"Frame","kind":"structure","region":[0,0,128,128],"depends_on":[],"stage":a,"raster_candidates_limit":64},
		{"id":"detail","parent_id":"finish","title":"Detail","kind":"detail","region":[0,0,128,128],"depends_on":[],"stage":b,"raster_candidates_limit":64}]}

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var session:=FixtureSession.new(); root.add_child(session)
	var workflow:=Workflow.new(); root.add_child(workflow)
	check(workflow.bind_session(session).ok,"one host session bound")
	check(workflow.load_campaign(graph()).ok,"finite campaign adopted")
	check(session.plan.stages[1].depends_on==["frame"],"group dependency flattened into actual native plan")
	check(not (await workflow.approve()).ok,"no ticket means no approval")
	check((await workflow.preview_selected()).ok,"host fixture preview enters review")
	check(workflow.summary().has_review_ticket,"exact preview ticket visible")
	var admitted: Dictionary=await workflow.approve()
	check(admitted.ok and admitted.queued and not admitted.completed,"approval means queued, never completed")
	check(not (await workflow.approve()).ok,"duplicate approval refused while queued")
	var terminal:=session.finish_fixture()
	check(workflow.campaign.summary().nodes[2].state=="completed","changed-before-terminal ordering preserves real terminal ticket")
	check(not workflow.summary().has_review_ticket,"terminal consumes approval once")
	session.terminal.emit(terminal)
	check(workflow.campaign.summary().budget.used_native_checks==4,"duplicate terminal cannot charge or complete twice")
	check(workflow.select(1).ok,"dependent task selected")
	var revised:=session.stage().duplicate(true); revised.depends_on=[]; revised.intent="Revised useful detail"
	check(workflow.revise(revised).ok,"atomic stage revision admitted")
	check(session.stage().depends_on==["frame"],"revision retains inherited group dependencies in native stage")
	check(Compiler.canonical(session.plan)==Compiler.canonical(workflow.campaign.native_plan()),"coordinator and actual session share exact revised plan")
	check((await workflow.preview_selected()).ok,"revised dependent stage can be inspected")
	check((await workflow.approve()).ok,"revised task gets a fresh owner approval")
	session.finish_fixture()
	check(workflow.campaign.summary().state=="completed","two actual fixture terminals retire finite hierarchy")
	var history:=workflow.export_history()
	check(workflow.open_history(history).ok,"historical graph and planning records reopen")
	check(workflow.campaign.summary().historical_only and session.completed_ids().is_empty() and not workflow.summary().has_review_ticket,"reopen restores no approval, queue or current completion")
	check(workflow.skip().ok,"owner skip is recorded")
	check(workflow.select(1).ok and not (await workflow.preview_selected()).ok,"declined parent blocks later task")
	check(workflow.load_campaign(graph()).ok,"fresh independent campaign")
	check(workflow.summary().prior_campaigns>=1,"replacing a campaign preserves its earlier owner decisions in bounded history")
	var archived:=workflow.export_history()
	check(archived.prior_campaigns.any(func(entry: Dictionary)->bool:return entry.history.decisions.any(func(decision: Dictionary)->bool:return decision.kind=="owner-skip")),"declined proposals survive a fresh recovery campaign without becoming dependencies")
	var corrupted:=archived.duplicate(true); corrupted.prior_campaigns[0].sha256="bad"
	check(not workflow.open_history(corrupted).ok,"tampered historical campaign identity is rejected without replacing the live workflow")
	var options:=workflow.submit_intent("large industrial hangar",{"mode":"offline","max_alternatives":2})
	check(options.ok and options.alternatives.size()==2,"finite offline discussion produces named alternatives")
	check(session.stage_state()=="proposed" and session.preview.is_empty(),"planning never previews or writes automatically")
	check(workflow.select_alternative("option-1").ok,"owner can adopt a named finite option")
	check(session.plan.stages.size()==3 and not workflow.summary().has_review_ticket,"adopting option grants no native approval")
	var requests: Array=[]; workflow.proposal_transport_requested.connect(func(value: Dictionary)->void: requests.append(value))
	var pending:=workflow.submit_intent("industrial hangar",{"mode":"proposal_transport","max_alternatives":1})
	check(pending.ok and requests.size()==1,"explicit proposal-only transport emits one correlated request")
	check(not workflow.accept_response(pending.request_id,"unstructured text").ok,"unparseable result cannot become construction")
	check(session.preview.is_empty(),"failed parsing creates no native preview or queue")
	pending=workflow.submit_intent("industrial hangar",{"mode":"proposal_transport","max_alternatives":1})
	session.fence.manual=1
	check(not workflow.accept_response(pending.request_id,{}).ok,"intervening manual edit rejects response without a fresh request")
	check(not workflow.select_alternative("option-1").ok,"stale alternative cannot be adopted")
	check(workflow.submit_intent("unclassified poetic shape",{}).status=="needs-clarification","unknown intent asks a bounded clarification")
	pending=workflow.submit_intent("industrial hangar",{"mode":"proposal_transport","max_alternatives":1})
	check(workflow.load_campaign(graph()).ok,"unrelated owner campaign replaces current planning context")
	check(not workflow.accept_response(pending.request_id,{}).ok,"late response cannot enter a replacement owner campaign")
	workflow.campaign._history.resize(Campaign.MAX_HISTORY_RECORDS)
	var original_state:=session.stage_state()
	check(not workflow.skip().ok and session.stage_state()==original_state,"coordinator skip capacity refuses before mutating native session state")
	# Fresh fixture session: all worker authority must originate in this lifetime.
	workflow.queue_free(); session.queue_free(); await process_frame
	session=FixtureSession.new(); root.add_child(session)
	session.worker_host=WorkerFixture.host_for("contextual_ribs")
	session.fixture_cells=session.worker_host.context.source_cells.duplicate()
	session.fixture_region=Rect2i(0,0,64,64); session.fence.generation=1
	workflow=Workflow.new(); root.add_child(workflow); workflow.bind_session(session)
	var delegated:=WorkerFixture.campaign_for(WorkerFixture.node_for("contextual_ribs"))
	check(workflow.load_campaign(delegated).ok and workflow.summary().can_prepare_local_job,"ready delegated task exposes explicit preparation")
	check(not (await workflow.preview_selected()).ok,"empty delegation cannot silently preview a no-op task")
	var original_cells:=session.fixture_cells.duplicate()
	var prepared: Dictionary=await workflow.prepare_selected_job()
	check(prepared.ok and prepared.zero_writes and not prepared.queued and session.fixture_cells==original_cells,"worker preparation cannot mutate or queue native geometry")
	check(workflow.summary().prepared_local_job and not workflow.summary().has_review_ticket,"prepared proposal still needs exact preview and owner approval")
	check((await workflow.preview_selected()).ok,"live source-grounded worker proposal enters ordinary stage preview")
	var serialized: Dictionary=workflow.campaign.export_history().campaign
	check(workflow.load_campaign(serialized).ok and not (await workflow.preview_selected()).ok,"serialized prepared output loses runtime preparation authority on load")
	check((await workflow.prepare_selected_job()).ok and (await workflow.preview_selected()).ok,"reopened worker can be freshly prepared and inspected")
	session.fixture_cells.encode_u16(0,58)
	check(not (await workflow.preview_selected()).ok,"changed native source refuses a formerly prepared worker proposal")
	session.fixture_cells=original_cells.duplicate()
	check(workflow.load_campaign(delegated).ok,"new finite delegation replaces refused preparation")
	session.preparation_hook=func()->void: workflow.cancel()
	check(not (await workflow.prepare_selected_job()).ok and not workflow.summary().prepared_local_job,"Stop during source capture retires preparation without a stale result")
	session.preparation_hook=Callable()
	check(workflow.load_campaign(delegated).ok and (await workflow.prepare_selected_job()).ok,"new live preparation exists before host replacement")
	var replacement:=FixtureSession.new();root.add_child(replacement)
	replacement.fixture_region=session.fixture_region;replacement.fence=session.fence.duplicate()
	replacement.fixture_cells=session.fixture_cells.duplicate();replacement.worker_host=session.worker_host.duplicate(true)
	replacement.load_plan(session.plan)
	check(workflow.bind_session(replacement).ok and not workflow.summary().prepared_local_job and workflow.campaign.summary().campaign_id.is_empty(),"host replacement retires worker capabilities and old campaign completion authority")
	check(not (await workflow.preview_selected()).ok,"matching serialized stage in another host cannot reuse a prior preparation capability")
	replacement.queue_free()
	workflow.queue_free(); session.queue_free(); await process_frame
	await recovery_controls()
	print("ARCHITECTURE_WORKFLOW: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func recovery_controls() -> void:
	# Copied evidence tests convenience-control refusal, not native completion.
	var session:=RecoveryFixture.new(); root.add_child(session)
	var workflow:=Workflow.new(); root.add_child(workflow); workflow.bind_session(session)
	var area:=Rect2i(64,160,384,160)
	session.fixture_region=area; session.fixture_cells.resize(area.get_area()*2)
	var empty:=session.fixture_cells.duplicate()
	session.fixture_cells.encode_u16(0,58)
	var trial:=Compiler.stage_defaults("cladding-trial",area)
	trial.materials=[0,58];trial.budget.max_checked_cells=65536
	trial.operations=[{"shape":"rectangle","x0":64,"y0":160,"x1":447,"y1":319,"material":58}]
	var graph:={"format":Campaign.FORMAT,"id":"delegated-workshop","title":"Copied workshop recovery fixture","intent":"Exercise owner proposal guards only.",
		"region":[0,0,512,512],"budget":{"native_checks":65536,"raster_candidates":1048576,"max_retries_per_job":1},
		"nodes":[{"id":trial.id,"parent_id":"","title":"Copied trial","kind":"typed","executor":"authored-typed","region":trial.region,
			"depends_on":[],"stage":trial,"raster_candidates_limit":1048576}]}
	check(workflow.load_campaign(graph).ok,"recovery-control copied campaign loads without native execution")
	workflow.cancel()
	check(not (await workflow.propose_workshop_recovery()).ok,"no live partial record means no convenience recovery")
	var record:={"kind":"native-stage","stage_id":"cladding-trial","status":"partial","final_readback_available":true,"checked_cells":1,
		"plan_id":"delegated-workshop","plan_sha256":Compiler.digest(Compiler.canonical(session.plan).to_utf8_buffer()),"stage":session.stage().duplicate(true),
		"generation":5,"source_sha256":Compiler.digest(empty),"result_sha256":Compiler.digest(session.fixture_cells),"reason":"Copied non-native fixture"}
	session.records.append(record)
	record.source_sha256=record.result_sha256
	check(not (await workflow.propose_workshop_recovery()).ok,"a nonempty original trial cannot be erased by the convenience recovery")
	record.source_sha256=Compiler.digest(empty)
	session.fixture_cells.encode_u16(2,28)
	check(not (await workflow.propose_workshop_recovery()).ok and session.fixture_cells.decode_u16(2)==28,"later source edits refuse and remain untouched")
	session.fixture_cells.encode_u16(2,0)
	session.fence.generation=6
	check(not (await workflow.propose_workshop_recovery()).ok,"a replaced native generation cannot reuse a stopped receipt")
	session.fence.generation=5
	record.plan_sha256="outdated"
	check(not (await workflow.propose_workshop_recovery()).ok,"a changed plan cannot reuse the old stopped receipt")
	record.plan_sha256=Compiler.digest(Compiler.canonical(session.plan).to_utf8_buffer())
	session.preparation_hook=func()->void:workflow.cancel()
	check(not (await workflow.propose_workshop_recovery()).ok and workflow.campaign.summary().campaign_id=="delegated-workshop","Stop during inspection retires the recovery proposal")
	session.preparation_hook=Callable()
	var before:=session.fixture_cells.duplicate()
	var answer: Dictionary=await workflow.propose_workshop_recovery()
	check(answer.get("ok",false) and answer.get("zero_writes",false) and not answer.get("queued",true) and session.fixture_cells==before
		and session.preview.is_empty() and workflow.campaign.summary().campaign_id=="workshop-fresh-recovery"
		and session.plan.stages.size()==3 and not workflow.summary().has_review_ticket,"fresh recovery only adopts three finite owner-reviewable stages")
	workflow.queue_free();session.queue_free();await process_frame
