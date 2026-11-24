extends Node
## One host-owned bridge between proposal values, the finite task coordinator
## and the existing authoritative StageSession. No provider or World is created.
signal changed
signal terminal(record: Dictionary)
signal proposed(summary: Dictionary)
signal proposal_transport_requested(request: Dictionary)
signal proposal_cancel_requested(request_id: String)
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Campaign = preload("res://scripts/batch_lab/architecture_campaign.gd")
const Planning = preload("res://scripts/batch_lab/architecture_planning_adapter.gd")
const Delegation = preload("res://scripts/batch_lab/architecture_delegation.gd")
const Workshop = preload("res://scripts/batch_lab/architecture_hierarchy_demo.gd")
const FORMAT := "cybersand-architecture-workflow-history-v1"
const MAX_FILE_BYTES := 64*1024*1024
const MAX_PRIOR_CAMPAIGNS := 8
const MAX_PRIOR_BYTES := 24*1024*1024
var session: Node
var campaign:=Campaign.new()
var planning:=Planning.new()
var message:="Inspect the selected World region and describe the construction you want."
var _ticket: Dictionary={}
var _request_id:=""
var _planning_fence: Dictionary={}
var _action:=false
var _syncing:=false
var _selection_serial:=0
var _adopting_alternative:=false
var _prior_campaigns: Array=[]
var _prepared_jobs: Dictionary={}

func _ready() -> void:
	_wire_values()

func _wire_values() -> void:
	if not campaign.changed.is_connected(_campaign_changed): campaign.changed.connect(_campaign_changed)
	if not planning.changed.is_connected(_planning_changed): planning.changed.connect(_planning_changed)
	if not planning.proposed.is_connected(_proposed): planning.proposed.connect(_proposed)
	if not planning.transport_requested.is_connected(_transport_requested): planning.transport_requested.connect(_transport_requested)
	if not planning.planning_cancelled.is_connected(_planning_cancelled): planning.planning_cancelled.connect(_planning_cancelled)

func bind_session(value: Node) -> Dictionary:
	if busy(): return _answer(false,"Wait for the existing native session or local preparation before rebinding the workflow.")
	if not is_instance_valid(value) or not value.has_method("preview_selected") or not value.has_signal("terminal"):
		return _answer(false,"An installed host architecture session is required.")
	if is_instance_valid(session):
		if session!=value:
			var archive:=_archive_candidate()
			if not archive.ok: return _answer(false,archive.reason)
			_retain_prior(archive); _retire_planning()
			_ticket.clear(); _prepared_jobs.clear(); _selection_serial+=1
			campaign=Campaign.new(); _wire_values()
		if session.changed.is_connected(_session_changed): session.changed.disconnect(_session_changed)
		if session.terminal.is_connected(_native_terminal): session.terminal.disconnect(_native_terminal)
	session=value
	session.changed.connect(_session_changed)
	session.terminal.connect(_native_terminal)
	_wire_values()
	return _answer(true,"Architecture workflow attached to the existing native session.")

func busy() -> bool:
	return _action or (is_instance_valid(session) and session.busy())

func _answer(ok: bool, reason: String) -> Dictionary:
	message=reason
	changed.emit()
	return {"ok":ok,"reason":reason}

func _campaign_changed(_summary: Dictionary) -> void:
	changed.emit()

func _planning_changed(_summary: Dictionary) -> void:
	changed.emit()

func _proposed(value: Dictionary) -> void:
	_request_id=str(value.get("request_id",""))
	proposed.emit(planning.summary())
	changed.emit()

func _transport_requested(value: Dictionary) -> void:
	_request_id=str(value.get("request_id",""))
	proposal_transport_requested.emit(value.duplicate(true))

func _planning_cancelled(identity: String) -> void:
	proposal_cancel_requested.emit(identity)

func _sync_dependencies() -> void:
	if not is_instance_valid(session): return
	var stale: Array=[]
	for row: Dictionary in campaign.summary().get("nodes",[]):
		if row.kind!="group" and row.state=="completed" and session.states.get(row.id)!="completed": stale.append(row.id)
	if not stale.is_empty(): campaign.note_stale_dependencies(stale)

func _session_changed() -> void:
	if _syncing: return
	_syncing=true
	if is_instance_valid(session) and not busy() and not _ticket.is_empty() and session.preview.is_empty() and campaign.summary().get("active_job_id","").is_empty():
		campaign.invalidate_regions([session.stage().get("region",[])],int(session._observation_fence().get("generation",-1)))
		_ticket.clear()
	if is_instance_valid(session) and not _planning_fence.is_empty() and _planning_fence!=session._observation_fence():
		planning.cancel_planning()
		_planning_fence.clear()
		message="The inspected World or authoring history changed. Inspect again before adopting a proposal."
	if not busy(): _sync_dependencies()
	_syncing=false
	changed.emit()

func _retire_planning() -> void:
	planning.cancel_planning()
	_planning_fence.clear(); _request_id=""

func _archive_candidate() -> Dictionary:
	if campaign.summary().get("campaign_id","").is_empty(): return {"ok":true,"entry":{}}
	var history:=campaign.export_history()
	if history.get("decisions",[]).is_empty() and history.get("historical",[]).is_empty(): return {"ok":true,"entry":{}}
	var entry:={"history":history,"sha256":Compiler.digest(Compiler.canonical(history).to_utf8_buffer()),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"scope":"Earlier campaign decisions; no current approval or native authority."}
	if _prior_campaigns.any(func(old: Dictionary)->bool:return old.sha256==entry.sha256): return {"ok":true,"entry":{}}
	var combined:=_prior_campaigns.duplicate(true); combined.append(entry)
	if combined.size()>MAX_PRIOR_CAMPAIGNS or Compiler.canonical(combined).to_utf8_buffer().size()>MAX_PRIOR_BYTES:
		return {"ok":false,"reason":"The workflow retains at most eight prior campaigns and 24 MiB of their decisions. Save this history and explicitly open a fresh workflow before replacing it."}
	return {"ok":true,"entry":entry}

func _retain_prior(candidate: Dictionary) -> void:
	if not candidate.get("entry",{}).is_empty(): _prior_campaigns.append(candidate.entry)

func load_campaign(value: Dictionary) -> Dictionary:
	if busy(): return _answer(false,"Wait for the current native stage before changing the campaign.")
	var checked:=Campaign.validate(value)
	if not checked.ok: return _answer(false,checked.reason)
	if not campaign.summary().get("active_job_id","").is_empty(): return _answer(false,"The earlier native task must retire before loading another campaign.")
	var archive:=_archive_candidate()
	if not archive.ok: return _answer(false,archive.reason)
	var loaded: Dictionary=session.load_plan(checked.native_plan)
	if not loaded.ok: return loaded
	_retain_prior(archive)
	if not _adopting_alternative: _retire_planning()
	var adopted:=campaign.load_campaign(value)
	_ticket.clear(); _prepared_jobs.clear(); _selection_serial+=1
	if not adopted.ok: return _answer(false,adopted.reason)
	return _answer(true,"Finite construction campaign loaded. Select a task, inspect its exact projection and approve each native stage.")

func load_plan(value: Dictionary) -> Dictionary:
	if busy(): return _answer(false,"Wait for the current native stage before changing the plan.")
	var archive:=_archive_candidate()
	if not archive.ok: return _answer(false,archive.reason)
	var loaded: Dictionary=session.load_plan(value)
	if not loaded.ok: return loaded
	_retain_prior(archive)
	_retire_planning()
	campaign=Campaign.new(); _wire_values(); _ticket.clear(); _prepared_jobs.clear(); _selection_serial+=1
	return _answer(true,"Typed plan loaded into the existing native session.")

func submit_intent(intent: Variant, options: Dictionary={}) -> Dictionary:
	if busy(): return _answer(false,"Wait for native execution before discussing a fresh inspected state.")
	var value: Dictionary={"text":intent} if intent is String else intent.duplicate(true) if intent is Dictionary else {}
	var observed: Dictionary=session.inspection_view()
	if not observed.get("ok",false) or observed.get("stale",true): return _answer(false,"Inspect the selected native World region before requesting construction options.")
	_planning_fence=session._observation_fence().duplicate(true)
	var summaries: Array=session.library.summaries() if session.library!=null else []
	var answer:=planning.submit_intent(value,observed,summaries,options)
	if answer.get("ok",false): _request_id=str(answer.get("request_id",_request_id))
	message=str(answer.get("reason","Review a finite proposal; no construction has been queued."))
	changed.emit()
	return answer

func propose_intent(intent: Variant, region: Rect2i, options: Dictionary={}) -> Dictionary:
	if busy(): return _answer(false,"Wait for the current native action.")
	var inspected: Dictionary=await session.inspect_region(region)
	if not inspected.get("ok",false): return inspected
	return submit_intent(intent,options)

func accept_response(identity: String, response: Variant) -> Dictionary:
	if _planning_fence.is_empty() or _planning_fence!=session._observation_fence():
		planning.cancel_planning()
		return _answer(false,"Late response is bound to an outdated native inspection; no new request or native work was created.")
	return planning.accept_response(identity,response)

func select_alternative(identity: String) -> Dictionary:
	if busy(): return _answer(false,"Wait for the current native action before adopting another option.")
	if _planning_fence.is_empty() or _planning_fence!=session._observation_fence(): return _answer(false,"The proposal's inspected context changed. Inspect and propose again.")
	var alternative:=planning.alternative(identity)
	if alternative.is_empty(): return _answer(false,"Select a current named construction option.")
	_adopting_alternative=true
	var answer:=load_campaign(alternative.campaign)
	_adopting_alternative=false
	if answer.ok: message="Selected "+str(alternative.title)+". This adopts a plan, not native geometry."; changed.emit()
	return answer

func select(index: int) -> Dictionary:
	if busy(): return _answer(false,"Wait for the native stage before changing selection.")
	var answer: Dictionary=session.select(index)
	if answer.ok: _retire_planning(); _ticket.clear(); _selection_serial+=1
	return answer

func preview_selected() -> Dictionary:
	if busy(): return _answer(false,"Wait for the current native action.")
	var selected_id:=str(session.stage().get("id",""))
	if (campaign.job(selected_id).has("delegation") or session.stage().has("delegation_descriptor_sha256")) and not _prepared_matches(selected_id):
		return _answer(false,"Prepare this local job from the current inspected World before previewing it. Imported worker outputs grant no current authority.")
	_ticket.clear(); _action=true
	var answer: Dictionary=await session.preview_selected()
	_action=false
	var identity:=str(session.stage().get("id",""))
	if not answer.get("ok",false):
		_sync_dependencies()
		if campaign.has_method("note_preview_refusal") and not campaign.job(identity).is_empty(): campaign.note_preview_refusal(identity,str(answer.get("reason","Native preview refused.")))
		return answer
	if not campaign.summary().get("campaign_id","").is_empty():
		var bound:=campaign.bind_preview(identity,session.preview)
		if not bound.ok: session.preview.clear(); return _answer(false,bound.reason)
		_ticket=bound.ticket
	message="Exact zero-write projection is ready for this stage. Approval does not authorize later tasks."
	changed.emit()
	return answer

func _prepared_matches(identity: String) -> bool:
	return _prepared_jobs.has(identity) and _prepared_jobs[identity].stage_sha256==Compiler.digest(Compiler.canonical(session.stage()).to_utf8_buffer())

func prepare_selected_job() -> Dictionary:
	if busy(): return _answer(false,"Wait for the native action before preparing local work.")
	var identity:=str(session.stage().get("id",""))
	var node:=campaign.job(identity)
	if not node.has("delegation") or identity not in campaign.ready_jobs():
		return _answer(false,"Select a ready delegated task whose predecessors have verified native completion.")
	var checked:=Delegation.validate(node)
	if not checked.ok: return _answer(false,checked.reason)
	var serial:=_selection_serial
	var source_stage:=Compiler.digest(Compiler.canonical(session.stage()).to_utf8_buffer())
	_prepared_jobs.erase(identity); _ticket.clear(); session.preview.clear(); _action=true
	var context: Dictionary=await session.detail_context(Compiler.rect(node.region),str(node.delegation.get("instance_id","")))
	_action=false
	if serial!=_selection_serial or str(session.stage().get("id",""))!=identity \
		or source_stage!=Compiler.digest(Compiler.canonical(session.stage()).to_utf8_buffer()) or identity not in campaign.ready_jobs():
		return _answer(false,"Local preparation was retired by a changed task, Stop or campaign. No native work was queued.")
	var prepared:=Delegation.compile(node,context)
	if not prepared.ok: return _answer(false,prepared.reason)
	var adopted:=revise(prepared.stage)
	if not adopted.ok: return adopted
	_prepared_jobs[identity]={"stage_sha256":Compiler.digest(Compiler.canonical(session.stage()).to_utf8_buffer()),
		"descriptor_sha256":prepared.descriptor_sha256,"source_sha256":prepared.source_sha256,
		"worker_proposal_sha256":prepared.proposal.proposal_sha256,"native_cells":prepared.native_cells,"scan_cells":prepared.worker_scan_cells}
	message="Local worker prepared a finite source-bound proposal. Preview the exact geometry, then approve this stage to build."
	changed.emit()
	return {"ok":true,"zero_writes":true,"queued":false,"completed":false,"stage_id":identity,"worker":_prepared_jobs[identity].duplicate(true)}

func approve() -> Dictionary:
	if busy(): return _answer(false,"Wait for the current native action.")
	var coordinated: bool=not campaign.summary().get("campaign_id","").is_empty()
	if coordinated:
		if _ticket.is_empty() or session.preview.get("preview_sha256")!=_ticket.get("preview_sha256"):
			return _answer(false,"A current task ticket and exact native preview are required for approval.")
		var reserved:=campaign.reserve_approval(_ticket)
		if not reserved.ok: return _answer(false,reserved.reason)
	_action=true
	var answer: Dictionary=await session.approve()
	_action=false
	if not answer.get("ok",false):
		if coordinated: campaign.reject_admission(_ticket,str(answer.get("reason","Native admission refused."))); _ticket.clear()
		_sync_dependencies()
		return answer
	if coordinated:
		var queued:=campaign.mark_queued(_ticket,{"sequence":session._submission,"request_id":_request_id if not _request_id.is_empty() else "owner-typed-"+str(_selection_serial)})
		if not queued.ok:
			session.cancel()
			return _answer(false,"Native work was stopped because its hierarchy admission could not be correlated: "+str(queued.reason))
	message="Stage queued through ordinary native authoring. Completion requires its terminal receipts and readback."
	changed.emit()
	return {"ok":true,"queued":true,"completed":false,"stage_id":session.stage().id,"native_submission":session._submission}

func _native_terminal(record: Dictionary) -> void:
	# This signal is connected only to our existing host session. Proposal JSON
	# never reaches the coordinator's native evidence methods.
	if not _ticket.is_empty():
		if record.get("native_submission")!=session._submission:
			message="An unrelated late native terminal was ignored; the current task keeps its own identity."
			changed.emit(); return
		var observed:=campaign.observe_terminal(_ticket,record)
		if not observed.ok:
			message="Native terminal needs review: "+str(observed.reason)
			if not observed.get("retired",false): campaign._quarantine_terminal(_ticket,message)
		else: message=str(record.get("reason","Native stage retired."))
		_ticket.clear()
	terminal.emit(record.duplicate(true))
	changed.emit()

func revise(value: Dictionary) -> Dictionary:
	if busy(): return _answer(false,"Stop and wait for the actual terminal before revising.")
	var coordinated: bool=not campaign.summary().get("campaign_id","").is_empty()
	var flattened:=value
	if coordinated:
		if not campaign.has_method("validate_revision"): return _answer(false,"This coordinator has no atomic revision preflight.")
		var checked: Dictionary=campaign.validate_revision(str(session.stage().id),value)
		if not checked.ok: return _answer(false,checked.reason)
		for stage: Dictionary in checked.native_plan.stages:
			if stage.id==value.get("id"): flattened=stage; break
	var answer: Dictionary=session.revise(flattened)
	if not answer.ok: return answer
	if coordinated:
		var revised:=campaign.revise_job(str(value.id),value)
		if not revised.ok: return _answer(false,revised.reason)
	_ticket.clear(); _selection_serial+=1
	_prepared_jobs.erase(str(value.get("id","")))
	return _answer(true,"Revision retained. Completed geometry remains in native history; preview this changed stage again.")

func revise_workshop_gallery() -> Dictionary:
	if busy() or not is_instance_valid(session): return _answer(false,"Wait for the actual native terminal before revising the workshop gallery.")
	var view:=campaign.summary()
	if view.get("campaign_id")!="delegated-workshop" or view.get("historical_only",false) or view.get("state")=="cancelled" or session.stage().get("id")!="access-gallery":
		return _answer(false,"Select the access-gallery task in the current delegated workshop.")
	var answer:=revise(Workshop.repaired_gallery())
	if answer.ok:
		answer["zero_writes"]=true; answer["queued"]=false
		message="Side-gallery repair proposed. Inspect its new native projection and approve this stage explicitly."
		changed.emit()
	return answer

func _workshop_partial() -> Dictionary:
	if not is_instance_valid(session): return {}
	var view:=campaign.summary()
	if view.get("campaign_id")!="delegated-workshop" or view.get("historical_only",false) or view.get("state")!="cancelled" or not str(view.get("active_job_id","")).is_empty(): return {}
	for index: int in range(session.records.size()-1,-1,-1):
		var record: Dictionary=session.records[index]
		if record.get("kind")!="native-stage" or record.get("stage_id")!="cladding-trial": continue
		if record.get("status")!="partial" or not record.get("final_readback_available",false) or int(record.get("checked_cells",0))<=0 or int(record.get("checked_cells",61440))>=61440: return {}
		if record.get("plan_id")!="delegated-workshop" or Compiler.rect(record.get("stage",{}).get("region"))!=Workshop.RECOVERY_AREA: return {}
		if int(record.get("generation",-2))!=int(session._observation_fence().get("generation",-1)): return {}
		return record
	return {}

func propose_workshop_recovery() -> Dictionary:
	if busy(): return _answer(false,"Wait for the acknowledged partial native terminal before proposing recovery.")
	var partial:=_workshop_partial()
	if partial.is_empty(): return _answer(false,"Recovery requires this live workshop's verified stopped cladding prefix; imported history grants no recovery authority.")
	if partial.get("plan_sha256")!=Compiler.digest(Compiler.canonical(session.plan).to_utf8_buffer()):
		return _answer(false,"The stopped trial belongs to another plan revision. Inspect and author a new recovery explicitly.")
	var empty:=PackedByteArray(); empty.resize(Workshop.RECOVERY_AREA.get_area()*2)
	if partial.get("source_sha256")!=Compiler.digest(empty):
		return _answer(false,"This convenience recovery supports the demo's originally Empty trial region only. Preserve the earlier authored geometry with a separately revised plan.")
	var serial:=_selection_serial
	var bound_session:=session
	_action=true
	var inspected: Dictionary=await session.inspect_region(Workshop.RECOVERY_AREA)
	_action=false
	if serial!=_selection_serial or session!=bound_session or not is_instance_valid(session):
		return _answer(false,"Stop or a changed host retired recovery inspection; no proposal was adopted.")
	if not inspected.get("ok",false) or inspected.get("stale",true) or session.inspection_view().get("stale",true):
		return _answer(false,"Recovery needs a current, successful native inspection.")
	if inspected.get("source_sha256")!=partial.get("result_sha256") or int(inspected.get("generation",-1))!=int(partial.generation):
		return _answer(false,"The stopped region has changed since its native receipt. A new explicit recovery must preserve those later edits.")
	var recovered:=Workshop.recovery(inspected)
	if not recovered.ok: return _answer(false,recovered.reason)
	var answer:=load_campaign(recovered.campaign)
	if answer.ok:
		answer["zero_writes"]=true; answer["queued"]=false; answer["completed"]=false
		message="Fresh recovery proposed with separate clearing, open-bay and attachment stages. Review and approve each stage; no geometry has changed."
		changed.emit()
	return answer

func skip() -> Dictionary:
	if busy(): return _answer(false,"Wait for the native terminal before skipping another task.")
	var identity:=str(session.stage().get("id",""))
	if not campaign.job(identity).is_empty():
		var permitted:=campaign.can_skip(identity)
		if not permitted.ok: return _answer(false,permitted.reason)
	var answer: Dictionary=session.skip()
	if not answer.ok: return answer
	if not campaign.job(identity).is_empty():
		var skipped:=campaign.skip(identity)
		if not skipped.ok: return _answer(false,skipped.reason)
	_ticket.clear()
	return _answer(true,"Stage skipped. A skipped predecessor does not satisfy later dependencies.")

func cancel() -> Dictionary:
	_selection_serial+=1; _prepared_jobs.clear()
	planning.cancel_planning(); _planning_fence.clear()
	if not campaign.summary().get("campaign_id","").is_empty(): campaign.request_cancel()
	var answer: Dictionary=session.cancel()
	if not session.busy(): _ticket.clear()
	message=str(answer.get("reason","Stop requested."))
	changed.emit()
	return answer

func summary() -> Dictionary:
	var selected_id:=str(session.stage().get("id","")) if is_instance_valid(session) else ""
	var can_prepare: bool=not busy() and campaign.job(selected_id).has("delegation") and selected_id in campaign.ready_jobs()
	return {"busy":busy(),"message":message,"request_id":_request_id,"session":session.summary() if is_instance_valid(session) else {},
		"campaign":campaign.summary(),"planning":planning.summary(),"has_review_ticket":not _ticket.is_empty(),"prior_campaigns":_prior_campaigns.size(),
		"can_prepare_local_job":can_prepare,"prepared_local_job":_prepared_matches(selected_id) if not selected_id.is_empty() else false,
		"can_revise_workshop_gallery":not busy() and campaign.summary().get("campaign_id")=="delegated-workshop" and campaign.summary().get("state")!="cancelled" and selected_id=="access-gallery",
		"can_propose_workshop_recovery":not busy() and not _workshop_partial().is_empty()}

func open_session(path: String) -> Dictionary:
	if busy(): return _answer(false,"Wait for native work before opening another session.")
	var archive:=_archive_candidate()
	if not archive.ok: return _answer(false,archive.reason)
	var opened: Dictionary=session.open_session(path)
	if not opened.ok: return opened
	_retain_prior(archive)
	_retire_planning(); campaign=Campaign.new(); _wire_values(); _ticket.clear(); _prepared_jobs.clear(); _selection_serial+=1
	return _answer(true,"Construction history reopened for inspection. Earlier campaign approval and proposal requests were retired.")

func export_history() -> Dictionary:
	return {"format":FORMAT,"campaign":campaign.export_history(),"planning":planning.export_history(),"prior_campaigns":_prior_campaigns.duplicate(true),
		"scope":"Decision history only. Save World geometry with ordinary Save start and exact native receipts with the separate construction session."}

func open_history(value: Variant) -> Dictionary:
	if busy(): return _answer(false,"Wait for native work before opening historical decisions.")
	if not value is Dictionary or value.get("format")!=FORMAT or Compiler.canonical(value).to_utf8_buffer().size()>MAX_FILE_BYTES:
		return _answer(false,"Unsupported or oversized workflow history.")
	var incoming: Variant=value.get("prior_campaigns",[])
	if not incoming is Array or incoming.size()>MAX_PRIOR_CAMPAIGNS or Compiler.canonical(incoming).to_utf8_buffer().size()>MAX_PRIOR_BYTES:
		return _answer(false,"Imported prior-campaign history exceeds the bounded workflow envelope.")
	for entry: Variant in incoming:
		if not entry is Dictionary or not entry.get("history") is Dictionary or entry.history.get("format")!=Campaign.HISTORY_FORMAT \
			or entry.get("sha256")!=Compiler.digest(Compiler.canonical(entry.history).to_utf8_buffer()) or not Campaign.validate(entry.history.get("campaign")).ok:
			return _answer(false,"Prior campaign history has an invalid source envelope or content identity.")
	var archive:=_archive_candidate()
	if not archive.ok: return _answer(false,archive.reason)
	var retained:=_prior_campaigns.duplicate(true)
	for entry: Dictionary in incoming:
		if not retained.any(func(old: Dictionary)->bool:return old.sha256==entry.sha256): retained.append(entry.duplicate(true))
	if not archive.entry.is_empty() and not retained.any(func(old: Dictionary)->bool:return old.sha256==archive.entry.sha256): retained.append(archive.entry)
	if retained.size()>MAX_PRIOR_CAMPAIGNS or Compiler.canonical(retained).to_utf8_buffer().size()>MAX_PRIOR_BYTES:
		return _answer(false,"Combining the current and imported histories would exceed the prior-campaign limit; save and open a separate workflow.")
	var next_campaign:=Campaign.new(); var next_planning:=Planning.new()
	var graph:=next_campaign.open_history(value.get("campaign",{}))
	if not graph.ok: return _answer(false,graph.reason)
	var proposals:=next_planning.open_history(value.get("planning",{}))
	if not proposals.ok: return _answer(false,proposals.reason)
	var loaded: Dictionary=session.load_plan(next_campaign.native_plan())
	if not loaded.ok: return loaded
	planning.cancel_planning()
	campaign=next_campaign; planning=next_planning; _wire_values()
	_prior_campaigns=retained
	_ticket.clear(); _prepared_jobs.clear(); _selection_serial+=1; _planning_fence.clear(); _request_id=""
	return _answer(true,"Historical decisions reopened. No approval, provider request, native queue or current completion was restored.")

func _exit_tree() -> void:
	planning.cancel_planning()
	if is_instance_valid(session):
		if session.changed.is_connected(_session_changed): session.changed.disconnect(_session_changed)
		if session.terminal.is_connected(_native_terminal): session.terminal.disconnect(_native_terminal)
