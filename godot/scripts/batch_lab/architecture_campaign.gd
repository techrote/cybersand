extends RefCounted
## Finite, proposal-only task hierarchy. The workflow facade alone forwards
## authentic StageSession previews, admissions and terminal native records.
## This value coordinator never owns a World, executor, provider or credential.
signal changed(summary: Dictionary)

const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Delegation = preload("res://scripts/batch_lab/architecture_delegation.gd")
const FORMAT := "cybersand-architecture-campaign-v1"
const HISTORY_FORMAT := "cybersand-architecture-campaign-history-v1"
const MAX_NODES := 64
const MAX_DEPTH := 4
const MAX_LEAVES := 32
const MAX_INPUT_BYTES := 4*1024*1024
const MAX_HISTORY_BYTES := 64*1024*1024
const MAX_HISTORY_RECORDS := 256
const MAX_HISTORY_SNAPSHOTS := 16
const MAX_HISTORY_EVENT_BYTES := 16384
const HISTORY_WORKING_RESERVE := MAX_INPUT_BYTES+MAX_HISTORY_RECORDS*MAX_HISTORY_EVENT_BYTES+2*1024*1024
const MAX_NATIVE_CHECKS := 4194304
const MAX_RASTER_CANDIDATES := 16777216
const MAX_SCOPE_RECTS := 128
const MAX_REVISIONS := 16
const MAX_RETRIES := 2
const MAX_ALTERNATIVES := 3
const MAX_WORLD_SIDE := 4096
const LEAF_KINDS := ["structure","modules","services","detail","connection","typed"]

var _campaign: Dictionary = {}
var _flat: Dictionary = {}
var _nodes: Dictionary = {}
var _states: Dictionary = {}
var _reasons: Dictionary = {}
var _attempts: Dictionary = {}
var _previews: Dictionary = {}
var _evidence: Dictionary = {}
var _history: Array = []
var _historical: Array = []
var _active: Dictionary = {}
var _used_native := 0
var _used_raster := 0
var _revision := 0
var _serial := 0
var _cancelled := false
var _historical_only := false
var _lifetime := Crypto.new().generate_random_bytes(16).hex_encode()

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"zero_writes":true}

static func _text(value: Variant, maximum := 256, allow_empty := false) -> bool:
	return value is String and value.length()<=maximum and (allow_empty or not value.strip_edges().is_empty())

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high

static func _rect(value: Variant) -> Rect2i:
	var region := Compiler.rect(value)
	if region.position.x<0 or region.position.y<0 or region.size.x<1 or region.size.y<1: return Rect2i()
	if region.end.x>MAX_WORLD_SIDE or region.end.y>MAX_WORLD_SIDE: return Rect2i()
	return region

static func _hash(value: Variant) -> bool:
	if not value is String or value.length()!=64: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true

static func _strings(value: Variant, maximum := 64) -> bool:
	if not value is Array or value.size()>maximum: return false
	for item: Variant in value:
		if not _text(item,128): return false
	return true

static func _descendants(identity: String, nodes: Dictionary) -> Array:
	var leaves: Array = []
	for key: String in nodes:
		if nodes[key].kind=="group": continue
		var cursor: String = key
		var seen: Array = []
		while not cursor.is_empty():
			if cursor in seen or not nodes.has(cursor): break
			seen.append(cursor)
			if cursor==identity: leaves.append(key); break
			cursor = str(nodes[cursor].get("parent_id",""))
	return leaves

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("format")!=FORMAT: return _fail("Unsupported architecture campaign format.")
	if Compiler.canonical(value).to_utf8_buffer().size()>MAX_INPUT_BYTES: return _fail("Campaign exceeds its 4 MiB input limit.")
	if not _text(value.get("id"),128) or not _text(value.get("intent"),8192): return _fail("Campaign needs a bounded identity and architectural intent.")
	if not _text(value.get("title",value.get("intent")),256): return _fail("Campaign needs a short title.")
	var area := _rect(value.get("region"))
	if area.size==Vector2i.ZERO: return _fail("Campaign region is invalid or exceeds the bounded World extent.")
	var budget: Variant = value.get("budget")
	if not budget is Dictionary or not _integer(budget.get("native_checks"),0,MAX_NATIVE_CHECKS) or not _integer(budget.get("raster_candidates"),0,MAX_RASTER_CANDIDATES):
		return _fail("Campaign must declare finite aggregate native and raster ceilings.")
	if not _integer(budget.get("max_retries_per_job",MAX_RETRIES),0,MAX_RETRIES): return _fail("Job retry bound is invalid.")
	if not value.get("nodes") is Array or value.nodes.is_empty() or value.nodes.size()>MAX_NODES: return _fail("Campaign needs 1–64 bounded group/task nodes.")
	var nodes := {}
	var leaves: Array = []
	var declared_native := 0
	var declared_raster := 0
	for item: Variant in value.nodes:
		if not item is Dictionary or not _text(item.get("id"),128) or nodes.has(item.id): return _fail("Campaign node identities must be unique bounded strings.")
		if not _text(item.get("title"),256) or not _text(item.get("parent_id",""),128,true): return _fail("Campaign node title or parent identity is invalid.")
		if not _strings(item.get("depends_on",[])): return _fail("Campaign dependencies must be bounded identities.")
		var bounds := _rect(item.get("region"))
		if bounds.size==Vector2i.ZERO or not area.encloses(bounds): return _fail("Every node must remain inside the campaign region.")
		if item.get("kind")!="group" and item.get("kind") not in LEAF_KINDS: return _fail("Unknown campaign executor kind.")
		var node: Dictionary = item.duplicate(true)
		node["parent_id"] = str(item.get("parent_id",""))
		node["depends_on"] = item.get("depends_on",[]).duplicate()
		if node.kind!="group":
			if not _text(item.get("executor","typed"),64): return _fail("Task executor label must be a bounded string; it grants no execution authority.")
			if not item.get("stage") is Dictionary: return _fail("Each executable task needs a typed native stage.")
			var stage: Dictionary = item.stage
			if stage.get("id")!=item.id or Compiler.rect(stage.get("region"))!=bounds: return _fail("Task and native stage identity/region must agree.")
			if bounds.size.x>Compiler.MAX_SIDE or bounds.size.y>Compiler.MAX_SIDE: return _fail("A leaf stage exceeds the existing 512-cell side bound.")
			if not _strings(stage.get("depends_on",[])): return _fail("Native stage dependency list is invalid.")
			if not stage.get("budget") is Dictionary or not _integer(stage.budget.get("max_checked_cells"),1,Compiler.MAX_CHECKED_CELLS): return _fail("Every stage needs its existing native check ceiling.")
			for field: String in ["modules","operations","materials","protected","clearances","connections","uncertainty","refusal_conditions"]:
				if not stage.get(field,[]) is Array: return _fail("Task stage arrays are malformed: "+field)
			for field: String in ["protected","clearances"]:
				if stage.get(field,[]).size()>MAX_SCOPE_RECTS: return _fail("Task stage scope exceeds reservation capacity.")
				for rectangle: Variant in stage.get(field,[]):
					var guarded := _rect(rectangle)
					if guarded.size==Vector2i.ZERO or not area.encloses(guarded): return _fail("A stage protection or clearance escapes the campaign region.")
			if not _integer(item.get("raster_candidates_limit"),0,Compiler.MAX_RASTER_CANDIDATES): return _fail("Each task needs an explicit raster ceiling within the existing compiler limit.")
			if item.has("delegation"):
				var delegation:=Delegation.validate(item)
				if not delegation.ok:return delegation
			declared_native += int(stage.budget.max_checked_cells)
			declared_raster += int(item.raster_candidates_limit)
			if declared_native>int(budget.native_checks) or declared_raster>int(budget.raster_candidates): return _fail("Sum of declared task ceilings exceeds the campaign budget.")
			var scopes: Variant = item.get("scopes",{})
			if not scopes is Dictionary: return _fail("Task scope declarations must be an object.")
			var total_scopes := 0
			for field: String in ["write","guards","clearances","connectors"]:
				var rectangles: Variant = scopes.get(field,[])
				if not rectangles is Array: return _fail("Task scope must contain rectangle arrays.")
				total_scopes += rectangles.size()
				if total_scopes>MAX_SCOPE_RECTS: return _fail("Task reservation scope exceeds its bounded rectangle count.")
				for rectangle: Variant in rectangles:
					var scoped := _rect(rectangle)
					if scoped.size==Vector2i.ZERO or not area.encloses(scoped): return _fail("Task guard or interface escapes the campaign region.")
					if field=="write" and not bounds.encloses(scoped): return _fail("A declared write scope escapes its native stage.")
			leaves.append(item.id)
		nodes[item.id] = node
	if leaves.is_empty() or leaves.size()>MAX_LEAVES: return _fail("Campaign must retain 1–32 executable stages; no hidden limit relaxation.")
	for identity: String in nodes:
		var cursor: String = identity
		var ancestry: Array = []
		while not cursor.is_empty():
			if cursor in ancestry: return _fail("Campaign parent cycle refused.")
			if not nodes.has(cursor): return _fail("Campaign parent does not exist.")
			if cursor!=identity and nodes[cursor].kind!="group": return _fail("A native leaf cannot contain child tasks.")
			ancestry.append(cursor)
			if ancestry.size()>MAX_DEPTH: return _fail("Campaign hierarchy exceeds depth four.")
			cursor = str(nodes[cursor].parent_id)
		var parent: String = nodes[identity].parent_id
		if not parent.is_empty() and not _rect(nodes[parent].region).encloses(_rect(nodes[identity].region)):
			return _fail("A child write region escapes its parent composition.")
		if nodes[identity].kind=="group" and _descendants(identity,nodes).is_empty(): return _fail("Empty group has no executable interpretation.")
	var dependencies := {}
	for identity: String in leaves:
		var requested: Array = nodes[identity].stage.get("depends_on",[]).duplicate()
		var cursor: String = identity
		while not cursor.is_empty():
			requested.append_array(nodes[cursor].depends_on)
			cursor = nodes[cursor].parent_id
		var resolved: Array = []
		for dependency: String in requested:
			if not nodes.has(dependency): return _fail("Task depends on an unknown node: "+dependency)
			for leaf: String in _descendants(dependency,nodes):
				if leaf not in resolved: resolved.append(leaf)
		if identity in resolved: return _fail("A task cannot depend on itself or a group containing itself.")
		dependencies[identity] = resolved
	var order: Array = []
	while order.size()<leaves.size():
		var before := order.size()
		for identity: String in leaves:
			if identity in order: continue
			if dependencies[identity].all(func(dependency: String) -> bool: return dependency in order): order.append(identity)
		if before==order.size(): return _fail("Task dependency cycle refused.")
	var stages: Array = []
	for identity: String in order:
		var stage: Dictionary = nodes[identity].stage.duplicate(true)
		stage.depends_on = dependencies[identity].duplicate()
		stages.append(stage)
	var flat := {"format":Compiler.FORMAT,"id":value.id,"intent":value.intent,"stages":stages}
	var checked := Compiler.validate_plan(flat)
	if not checked.ok: return checked
	return {"ok":true,"campaign":value.duplicate(true),"nodes":nodes,"native_plan":checked.plan,"dependencies":dependencies,"order":order,
		"declared_native_checks":declared_native,"declared_raster_candidates":declared_raster,"zero_writes":true}

func load_campaign(value: Variant) -> Dictionary:
	if not _active.is_empty(): return _fail("Wait for the active native task's terminal acknowledgement.")
	var checked := validate(value)
	if not checked.ok: return checked
	_campaign = checked.campaign
	_nodes = checked.nodes
	_flat = checked.native_plan
	_states.clear(); _reasons.clear(); _attempts.clear(); _previews.clear(); _evidence.clear()
	_history.clear(); _historical.clear(); _used_native=0; _used_raster=0; _cancelled=false; _historical_only=false
	_revision = 1
	_lifetime = Crypto.new().generate_random_bytes(16).hex_encode()
	for identity: String in checked.order: _states[identity]="planned"; _attempts[identity]=0
	_emit()
	return {"ok":true,"native_plan":native_plan(),"zero_writes":true}

func native_plan() -> Dictionary:
	return _flat.duplicate(true)

func job(identity: String) -> Dictionary:
	return _nodes.get(identity,{}).duplicate(true)

func _stage(identity: String) -> Dictionary:
	for stage: Dictionary in _flat.get("stages",[]):
		if stage.id==identity: return stage
	return {}

func ready_jobs() -> Array:
	var output: Array = []
	if _cancelled: return output
	for stage: Dictionary in _flat.get("stages",[]):
		if _states.get(stage.id) not in ["planned","review","refused","partial","stale"]: continue
		if int(_attempts.get(stage.id,0))>int(_campaign.budget.get("max_retries_per_job",MAX_RETRIES)): continue
		if stage.depends_on.all(func(identity: String) -> bool: return _states.get(identity)=="completed"): output.append(stage.id)
	return output

func _scopes(identity: String, host_scopes: Dictionary = {}) -> Array:
	var output: Array = [_stage(identity).region.duplicate()]
	var stage := _stage(identity)
	output.append_array(stage.get("protected",[]).duplicate(true))
	output.append_array(stage.get("clearances",[]).duplicate(true))
	for source: Dictionary in [_nodes[identity].get("scopes",{}),host_scopes]:
		for field: String in ["write","guards","clearances","connectors"]:
			output.append_array(source.get(field,[]).duplicate(true))
	return output

func bind_preview(identity: String, preview: Dictionary, host_scopes: Dictionary = {}) -> Dictionary:
	if not _active.is_empty() or identity not in ready_jobs(): return _fail("Task is blocked, retired, cancelled or another native task is reserved.")
	if preview.get("kind")!="zero-write-compilation" or preview.get("zero_writes")!=true: return _fail("Only a host zero-write compilation can enter review.")
	for field: String in ["preview_sha256","source_sha256","stage_sha256","projected_sha256"]:
		if not _hash(preview.get(field)): return _fail("Preview identity is missing or malformed.")
	if preview.stage_sha256!=Compiler.digest(Compiler.canonical(_stage(identity)).to_utf8_buffer()): return _fail("Preview does not describe this exact flattened stage.")
	if Compiler.rect(preview.get("region"))!=Compiler.rect(_stage(identity).region) or not _integer(preview.get("generation"),0,9223372036854775807): return _fail("Preview World scope is invalid.")
	var budget: Variant = preview.get("budget")
	if not budget is Dictionary or not _integer(budget.get("checked_cells"),0,Compiler.MAX_CHECKED_CELLS) or not _integer(budget.get("conservative_scan_bound"),0,Compiler.MAX_RASTER_CANDIDATES): return _fail("Host preview lacks finite actual resource counts.")
	if int(budget.checked_cells)>int(_stage(identity).budget.max_checked_cells) or int(budget.conservative_scan_bound)>int(_nodes[identity].raster_candidates_limit): return _fail("Host actual cost exceeds the task's declared ceiling.")
	if _used_native+int(budget.checked_cells)>int(_campaign.budget.native_checks) or _used_raster+int(budget.conservative_scan_bound)>int(_campaign.budget.raster_candidates): return _fail("Remaining aggregate campaign resource budget is exhausted.")
	for field: String in host_scopes:
		if field not in ["write","guards","clearances","connectors"] or not host_scopes[field] is Array: return _fail("Unsupported host reservation scope.")
	var scopes := _scopes(identity,host_scopes)
	if scopes.size()>MAX_SCOPE_RECTS: return _fail("Combined native/guard/interface scope exceeds reservation capacity.")
	for rectangle: Variant in scopes:
		var scope := _rect(rectangle)
		if scope.size==Vector2i.ZERO or not _rect(_campaign.region).encloses(scope): return _fail("Host reservation escapes the campaign.")
	var counted_budget := {}
	for field: String in ["checked_cells","conservative_scan_bound","emitted_input_points","unique_cells","changed_cells","limit"]:
		if not _integer(budget.get(field),0,Compiler.MAX_RASTER_CANDIDATES): return _fail("Host preview resource field is invalid: "+field)
		counted_budget[field]=int(budget[field])
	_serial += 1
	var ticket := {"campaign_id":_campaign.id,"revision":_revision,"job_id":identity,"serial":_serial,"lifetime":_lifetime,
		"plan_sha256":Compiler.digest(Compiler.canonical(_flat).to_utf8_buffer()),
		"preview_sha256":preview.preview_sha256,"stage_sha256":preview.stage_sha256,"source_sha256":preview.source_sha256,
		"projected_sha256":preview.projected_sha256,"generation":preview.generation,
		"module_identity_sha256":Compiler.digest(Compiler.canonical(preview.get("resolved_modules",[])).to_utf8_buffer()),
		"host_budget":counted_budget,"scopes":scopes}
	_previews[identity]=ticket
	_states[identity]="review"; _reasons.erase(identity)
	_emit()
	return {"ok":true,"ticket":ticket.duplicate(true),"zero_writes":true}

func _matches(ticket: Dictionary) -> bool:
	return _previews.has(ticket.get("job_id")) and Compiler.canonical(_previews[ticket.job_id])==Compiler.canonical(ticket) and ticket.get("lifetime")==_lifetime and ticket.get("revision")==_revision

func reserve_approval(ticket: Dictionary) -> Dictionary:
	if not _active.is_empty(): return _fail("Native mutation is serialized; another task is reserved or queued.")
	if not _matches(ticket) or _states.get(ticket.job_id)!="review" or ticket.job_id not in ready_jobs(): return _fail("Approval ticket is stale, altered or not backed by the current review.")
	if _used_native+int(ticket.host_budget.checked_cells)>int(_campaign.budget.native_checks) or _used_raster+int(ticket.host_budget.conservative_scan_bound)>int(_campaign.budget.raster_candidates):
		return _fail("Earlier attempts consumed the remaining aggregate budget; this preview can no longer be reserved.")
	if _history.size()+2>MAX_HISTORY_RECORDS: return _fail("Campaign decision capacity is exhausted; save the complete history before another native attempt.")
	_active = {"ticket":ticket.duplicate(true),"submission":{},"cancel_requested":false}
	_states[ticket.job_id]="admitting"
	_emit()
	return {"ok":true,"queued":false,"reason":"Reserved for the owner's exact approval; native submission has not occurred."}

func mark_queued(ticket: Dictionary, submission: Dictionary) -> Dictionary:
	if _active.is_empty() or not _matches(ticket) or _states.get(ticket.job_id)!="admitting": return _fail("No matching reserved native admission.")
	if not _integer(submission.get("sequence"),0,9223372036854775807) or not _text(submission.get("request_id"),256): return _fail("Native submission needs its actual sequence and request identity.")
	var actual_submission := {"sequence":int(submission.sequence),"request_id":str(submission.request_id)}
	_active.submission=actual_submission
	_states[ticket.job_id]="queued"
	_attempts[ticket.job_id]=int(_attempts.get(ticket.job_id,0))+1
	_used_raster += int(ticket.host_budget.conservative_scan_bound)
	_history.append({"kind":"owner-approved-native-admission","job_id":ticket.job_id,"preview_sha256":ticket.preview_sha256,"revision":_revision,"submission":actual_submission.duplicate()})
	_emit()
	return {"ok":true,"queued":true,"completed":false}

func reject_admission(ticket: Dictionary, reason: String) -> Dictionary:
	if _active.is_empty() or not _matches(ticket) or _states.get(ticket.job_id)!="admitting": return _fail("Only an unqueued reserved admission can be refused without a native terminal.")
	_active.clear(); _previews.erase(ticket.job_id)
	_states[ticket.job_id]="refused"; _reasons[ticket.job_id]=reason.left(2048)
	_emit()
	return {"ok":true,"zero_writes":true}

func observe_terminal(ticket: Dictionary, record: Dictionary) -> Dictionary:
	# The workflow facade invokes this only from its live StageSession terminal.
	# Untrusted model/proposal JSON has no route to this method or native status.
	if _active.is_empty() or not _matches(ticket) or _states.get(ticket.job_id) not in ["queued","running"]: return _fail("Late, duplicate or uncorrelated native terminal refused.")
	if record.get("kind")!="native-stage" or record.get("stage_id")!=ticket.job_id or record.get("preview_sha256")!=ticket.preview_sha256 or record.get("generation")!=ticket.generation \
		or record.get("plan_id")!=ticket.campaign_id or record.get("plan_sha256")!=ticket.plan_sha256 or record.get("stage_sha256")!=ticket.stage_sha256 \
		or record.get("source_sha256")!=ticket.source_sha256 or record.get("expected_sha256")!=ticket.projected_sha256 or record.get("native_submission")!=_active.submission.sequence:
		return _fail("Terminal identity does not match the actual queued stage.")
	if record.get("status") not in ["completed","partial","refused","cancelled","stopped"] or not record.get("native_receipts") is Array: return _quarantine_terminal(ticket,"Queued task lacks a valid native terminal outcome.")
	if record.native_receipts.size()>Compiler.MAX_CHECKED_CELLS or record.get("native_receipts_sha256")!=Compiler.digest(Compiler.canonical(record.native_receipts).to_utf8_buffer()): return _quarantine_terminal(ticket,"Native receipt identity is invalid.")
	var spent := 0
	var changed_cells := 0
	var exact := true
	for receipt: Variant in record.native_receipts:
		if not receipt is Dictionary or receipt.get("backend")!="CyberNativeCellWorld" or not _integer(receipt.get("checked"),0,Compiler.MAX_CHECKED_CELLS) or not _integer(receipt.get("changed"),0,Compiler.MAX_CHECKED_CELLS): return _quarantine_terminal(ticket,"Terminal contains invalid native resource evidence.")
		for field: String in ["checked","changed","confirmed","requested","unchanged","excluded","refused"]:
			if not _integer(receipt.get(field),0,4096): return _quarantine_terminal(ticket,"Native receipt is missing its bounded integer counter: "+field)
		if int(receipt.requested)!=int(receipt.checked) or int(receipt.checked)!=int(receipt.changed)+int(receipt.unchanged)+int(receipt.excluded)+int(receipt.refused) \
			or int(receipt.confirmed)!=int(receipt.changed)+int(receipt.unchanged) or not receipt.get("readback") is Array or receipt.readback.size()!=int(receipt.confirmed): return _quarantine_terminal(ticket,"Native receipt counter algebra or readback length is invalid.")
		spent += int(receipt.checked)
		changed_cells += int(receipt.changed)
		if receipt.get("status")!="completed" or int(receipt.get("excluded",0))!=0 or int(receipt.get("refused",0))!=0 or int(receipt.get("confirmed",-1))!=int(receipt.changed): exact=false
	if spent>int(ticket.host_budget.checked_cells): return _quarantine_terminal(ticket,"Terminal native work exceeds its reserved host budget.")
	if record.status=="completed" and (not exact or spent!=int(ticket.host_budget.checked_cells) or changed_cells!=int(ticket.host_budget.changed_cells) or record.get("result_sha256")!=ticket.projected_sha256 or record.get("final_readback_available")!=true): return _quarantine_terminal(ticket,"Completion lacks exact authoritative accounting and projected/readback identity.")
	_used_native += spent
	var identity: String = ticket.job_id
	var status: String = record.status
	if status in ["cancelled","stopped"]: status="partial" if spent>0 else "cancelled"
	_states[identity]=status
	_reasons[identity]=str(record.get("reason","" )).left(2048)
	_evidence[identity]={"status":status,"generation":record.generation,"preview_sha256":ticket.preview_sha256,
		"source_sha256":ticket.source_sha256,"result_sha256":record.get("result_sha256",""),"native_checked_cells":spent,
		"native_receipt_chunks":record.native_receipts.size(),"native_receipts_sha256":Compiler.digest(Compiler.canonical(record.native_receipts).to_utf8_buffer()),
		"submission":_active.submission.duplicate(true)}
	_history.append({"kind":"native-terminal","job_id":identity,"evidence":_evidence[identity].duplicate(true)})
	_active.clear(); _previews.erase(identity)
	_emit()
	return {"ok":true,"completed":status=="completed","status":status,"spent_native_checks":spent}

func _quarantine_terminal(ticket: Dictionary, reason: String) -> Dictionary:
	# A correlated native terminal with invalid evidence is retired observably.
	# Reserve the whole admitted budget conservatively and stop later work. Never
	# promote malformed receipts or an unverified result to completed geometry.
	var spent := int(ticket.host_budget.checked_cells)
	_used_native += spent
	_states[ticket.job_id]="partial"
	_reasons[ticket.job_id]=reason.left(2048)
	_evidence[ticket.job_id]={"status":"unverified-terminal","preview_sha256":ticket.preview_sha256,"native_checked_cells_upper_bound":spent,"submission":_active.submission.duplicate(true)}
	_history.append({"kind":"unverified-native-terminal","job_id":ticket.job_id,"reason":reason.left(2048),"evidence":_evidence[ticket.job_id].duplicate(true)})
	_active.clear(); _previews.erase(ticket.job_id)
	_cancelled=true
	_emit()
	return {"ok":false,"reason":reason,"retired":true,"completed":false,"status":"unverified-terminal","requires_fresh_campaign":true}

func invalidate_regions(rectangles: Array, generation: int) -> Dictionary:
	var invalidated: Array = []
	for identity: String in _previews.keys():
		if not _active.is_empty() and identity==_active.ticket.job_id: continue
		var ticket: Dictionary = _previews[identity]
		var stale := int(ticket.generation)!=generation
		for changed_rect: Variant in rectangles:
			for scope: Array in ticket.scopes:
				if Compiler.rect(changed_rect).intersects(Compiler.rect(scope)): stale=true
		if stale:
			_states[identity]="stale"; _reasons[identity]="The inspected write/guard/interface scope changed; obtain a fresh native preview."
			_previews.erase(identity); invalidated.append(identity)
	if not invalidated.is_empty(): _emit()
	return {"ok":true,"invalidated":invalidated,"zero_writes":true}

func validate_revision(identity: String, new_stage: Dictionary) -> Dictionary:
	if not _active.is_empty(): return _fail("Wait for the actual native terminal before revising the hierarchy.")
	if not _states.has(identity) or _states[identity]=="completed": return _fail("Completed geometry is never overwritten by a task revision; author a new explicit stage.")
	if _revision>=MAX_REVISIONS: return _fail("Campaign revision budget exhausted.")
	if _history.size()>=MAX_HISTORY_RECORDS: return _fail("Campaign decision history is full.")
	var candidate: Dictionary = _campaign.duplicate(true)
	for node: Dictionary in candidate.nodes:
		if node.id==identity: node.stage=new_stage.duplicate(true); node.region=new_stage.get("region",[]).duplicate()
	var checked := validate(candidate)
	if not checked.ok: return checked
	return checked

func revise_job(identity: String, new_stage: Dictionary) -> Dictionary:
	var checked:=validate_revision(identity,new_stage)
	if not checked.ok: return checked
	_campaign=checked.campaign; _nodes=checked.nodes; _flat=checked.native_plan
	_revision+=1; _previews.clear(); _historical_only=false
	for key: String in _states:
		if _states[key] not in ["completed","skipped","cancelled"]: _states[key]="planned"
	_history.append({"kind":"owner-revision","job_id":identity,"revision":_revision,"stage_sha256":Compiler.digest(Compiler.canonical(_stage(identity)).to_utf8_buffer())})
	_emit()
	return {"ok":true,"native_plan":native_plan(),"zero_writes":true}

func note_preview_refusal(identity: String, reason: String) -> Dictionary:
	if not _active.is_empty() or not _states.has(identity) or _states[identity] in ["completed","skipped","cancelled"]: return _fail("Only an idle incomplete task can record a host preview refusal.")
	if _history.size()>=MAX_HISTORY_RECORDS: return _fail("Campaign decision history is full.")
	_states[identity]="refused"; _previews.erase(identity); _reasons[identity]=reason.left(2048)
	_history.append({"kind":"host-preview-refusal","job_id":identity,"reason":reason.left(2048),"revision":_revision})
	_emit()
	return {"ok":true,"zero_writes":true}

func note_stale_dependencies(identities: Array) -> Dictionary:
	if not _active.is_empty(): return _fail("Wait for the queued native terminal before changing dependency state.")
	if not _strings(identities,MAX_LEAVES): return _fail("Stale dependencies need bounded task identities.")
	var stale: Array=[]
	for identity: String in identities:
		if not _states.has(identity): return _fail("Unknown stale dependency: "+identity)
		if identity not in stale: stale.append(identity)
	for stage: Dictionary in _flat.get("stages",[]):
		if stage.depends_on.any(func(identity: String) -> bool: return identity in stale) and stage.id not in stale: stale.append(stage.id)
	for identity: String in stale:
		if _states[identity] in ["skipped","cancelled"]: continue
		_states[identity]="stale"; _previews.erase(identity)
		_reasons[identity]="A host-rechecked native prerequisite changed. Historical receipts are retained; fresh inspection and owner approval are required."
	if not stale.is_empty():
		if _history.size()<MAX_HISTORY_RECORDS: _history.append({"kind":"host-dependency-invalidated","job_ids":stale.duplicate(),"revision":_revision})
		else: _cancelled=true
		_emit()
	return {"ok":true,"invalidated":stale,"zero_writes":true}

func can_skip(identity: String) -> Dictionary:
	if not _active.is_empty() or not _states.has(identity) or _states[identity] in ["completed","skipped","cancelled"]: return _fail("Only an idle, incomplete task can be skipped once.")
	if _history.size()>=MAX_HISTORY_RECORDS: return _fail("Campaign decision history is full.")
	return {"ok":true,"zero_writes":true}

func skip(identity: String) -> Dictionary:
	var checked:=can_skip(identity)
	if not checked.ok:return checked
	_states[identity]="skipped"; _previews.erase(identity)
	_history.append({"kind":"owner-skip","job_id":identity})
	_emit()
	return {"ok":true,"zero_writes":true}

func request_cancel() -> Dictionary:
	_cancelled=true
	for identity: String in _states:
		if not _active.is_empty() and identity==_active.ticket.job_id: continue
		if _states[identity]!="completed": _states[identity]="cancelled"
	_previews = {_active.ticket.job_id:_active.ticket.duplicate(true)} if not _active.is_empty() else {}
	if not _active.is_empty(): _active.cancel_requested=true
	_emit()
	return {"ok":true,"await_native_terminal":not _active.is_empty(),"cancel_native":not _active.is_empty()}

func export_history() -> Dictionary:
	return {"format":HISTORY_FORMAT,"campaign":_campaign.duplicate(true),"decisions":_history.duplicate(true),"historical":_historical.duplicate(true),
		"states_at_save":_states.duplicate(true),"evidence_at_save":_evidence.duplicate(true),"used_native_checks":_used_native,"used_raster_candidates":_used_raster,
		"scope":"Historical decisions and evidence only. Reopen restores no queue, provider request, approval ticket or current-World completion."}

func open_history(value: Variant) -> Dictionary:
	if not _active.is_empty(): return _fail("Cannot reopen history while native work is pending.")
	if not value is Dictionary or value.get("format")!=HISTORY_FORMAT or Compiler.canonical(value).to_utf8_buffer().size()>MAX_HISTORY_BYTES-HISTORY_WORKING_RESERVE: return _fail("Unsupported or oversized history; retaining all imported evidence and a bounded new campaign would exceed 64 MiB.")
	if not value.get("decisions") is Array or value.decisions.size()>MAX_HISTORY_RECORDS or not value.get("historical",[]) is Array: return _fail("Historical campaign decision envelope is invalid.")
	var history: Array=value.get("historical",[]).duplicate(true)
	if history.size()>=MAX_HISTORY_SNAPSHOTS: return _fail("Historical snapshot capacity is exhausted; existing evidence remains intact.")
	for snapshot: Variant in history:
		if not snapshot is Dictionary or snapshot.has("historical"): return _fail("Imported histories must be a flat collection of retained snapshots.")
	var previous: Dictionary=value.duplicate(true)
	previous.erase("historical")
	previous["imported_payload_sha256"]=Compiler.digest(Compiler.canonical(value).to_utf8_buffer())
	history.append(previous)
	var loaded := load_campaign(value.get("campaign"))
	if not loaded.ok: return loaded
	_historical=history; _historical_only=true
	_emit()
	return {"ok":true,"historical_only":true,"zero_writes":true}

func summary() -> Dictionary:
	if _campaign.is_empty(): return {"format":FORMAT,"campaign_id":"","nodes":[],"state":"empty","historical_only":false}
	var rows: Array = []
	var ready := ready_jobs()
	var complete := 0
	var declared_native := 0
	var declared_raster := 0
	for node: Dictionary in _campaign.nodes:
		var identity: String=node.id
		var state: String = _states.get(identity,"planned")
		if node.kind=="group":
			var descendants := _descendants(identity,_nodes)
			state="completed" if descendants.all(func(key: String) -> bool: return _states.get(key)=="completed") else "planned"
		else:
			declared_native+=int(node.stage.budget.max_checked_cells)
			declared_raster+=int(node.raster_candidates_limit)
			if state=="completed": complete+=1
		rows.append({"id":identity,"parent_id":node.get("parent_id",""),"title":node.title,"kind":node.kind,"executor":node.get("executor","typed"),"state":state,
			"region":node.region.duplicate(),"depends_on":_stage(identity).get("depends_on",[]).duplicate(),"ready":identity in ready,"reason":_reasons.get(identity,""),
			"attempts":_attempts.get(identity,0),"host_budget":_previews.get(identity,{}).get("host_budget",{}).duplicate(true),
			"preview_sha256":_previews.get(identity,{}).get("preview_sha256",""),"evidence_summary":_evidence.get(identity,{}).duplicate(true)})
	return {"format":FORMAT,"campaign_id":_campaign.id,"revision":_revision,"title":_campaign.get("title",_campaign.intent),"intent":_campaign.intent,
		"state":"completed" if complete==_states.size() else ("cancelled" if _cancelled and _active.is_empty() else "active"),
		"active_job_id":_active.get("ticket",{}).get("job_id",""),"nodes":rows,"historical_only":_historical_only,
		"budget":{"declared_native_checks":declared_native,"declared_raster_candidates":declared_raster,"native_limit":_campaign.budget.native_checks,
			"raster_limit":_campaign.budget.raster_candidates,"used_native_checks":_used_native,"used_raster_candidates":_used_raster,
			"reserved_native_checks":_active.get("ticket",{}).get("host_budget",{}).get("checked_cells",0)}}

func _emit() -> void:
	changed.emit(summary())
