extends RefCounted
## Explicit proposal-only owner seam. This object never subscribes to Provider.finished,
## constructs a Provider, stores credentials, selects plans, approves, or writes World.
## The Art owner must route one exclusively owned completion through the callback.
signal changed(summary: Dictionary)
signal outcome(record: Dictionary)

const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const FORMAT := "cybersand-architecture-proposal-bridge-history-v1"
const REQUEST_FORMAT := "cybersand-architecture-proposal-request-v1"
const MAX_REQUESTS := 32
const MAX_EVENTS := 128
const RESERVED_EVENTS := 4
const MAX_REQUEST_BYTES := 2*1024*1024
const MAX_RESPONSE_BYTES := 4*1024*1024
const MAX_RETAINED_CHARS := 4096

var _workflow: Object
var _dispatch := Callable()
var _cancel := Callable()
var _context_guard := Callable()
var _mode := "unbound"
var _active: Dictionary = {}
var _history: Array = []
var _requests := 0
var _dropped_events := 0
var _last_status := "unbound"
var _seam_mutating := false
var _seam_serial := 0

static func _answer(ok: bool, reason: String) -> Dictionary:
	return {"ok":ok,"reason":reason,"zero_writes":true}

static func _digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): hashing.update(bytes)
	return hashing.finish().hex_encode()

func bind_owner_seam(workflow: Object, dispatch: Callable, cancel: Callable,
		context_guard: Callable, evidence_mode := "owner-transport-unqualified") -> Dictionary:
	if _seam_mutating: return _answer(false,"Owner seam mutation is already in progress.")
	if not _active.is_empty(): return _answer(false,"Retire the current owned proposal before changing its transport seam.")
	if not is_instance_valid(workflow) or not workflow.has_method("accept_response") or not workflow.has_method("summary") or not workflow.has_signal("proposal_transport_requested") or not workflow.has_signal("proposal_cancel_requested"):
		return _answer(false,"A host architecture Workflow is required.")
	if not dispatch.is_valid() or not cancel.is_valid() or not context_guard.is_valid():
		return _answer(false,"The owner must supply dispatch, request-scoped cancellation and a live host context guard.")
	if evidence_mode not in ["fixture","owner-transport-unqualified"]:
		return _answer(false,"A caller-supplied label cannot certify genuine inference.")
	_seam_mutating=true; _seam_serial+=1
	_disconnect_owner()
	_workflow=workflow; _dispatch=dispatch; _cancel=cancel; _context_guard=context_guard; _mode=evidence_mode
	_workflow.connect("proposal_transport_requested",_on_request)
	_workflow.connect("proposal_cancel_requested",_on_cancel_requested)
	_last_status="bound"; _seam_mutating=false; changed.emit(summary())
	return _answer(true,"Explicit proposal-only owner seam bound; ordinary Art completions remain with their owner.")

func _disconnect_owner() -> void:
	if is_instance_valid(_workflow):
		if _workflow.is_connected("proposal_transport_requested",_on_request): _workflow.disconnect("proposal_transport_requested",_on_request)
		if _workflow.is_connected("proposal_cancel_requested",_on_cancel_requested): _workflow.disconnect("proposal_cancel_requested",_on_cancel_requested)
	# Mutation is guarded before owner callbacks. They cannot attach a new host
	# whose signal links would be left behind by the outer detach.
	_retire_active("cancelled","Proposal seam detached.",true)
	_workflow=null; _dispatch=Callable(); _cancel=Callable(); _context_guard=Callable(); _mode="unbound"
	_last_status="unbound"

func detach_owner_seam() -> Dictionary:
	if _seam_mutating: return _answer(false,"Owner seam mutation is already in progress.")
	_seam_mutating=true; _seam_serial+=1
	_disconnect_owner()
	_seam_mutating=false
	changed.emit(summary())
	return _answer(true,"Proposal seam detached; no provider listener, approval or execution remains.")

func dispatch_pending_request(request: Dictionary) -> Dictionary:
	# The ordinary host can disclose a pending copied request before attaching
	# transport. Explicit Send admits that same current request through the exact
	# signal-consumer path and all its existing identity, guard and budget checks.
	var identity := str(request.get("request_id",""))
	if _seam_mutating or _mode == "unbound" or not _active.is_empty() or not _pending(identity):
		return _answer(false,"No current undispatched Architecture request is available.")
	_on_request(request.duplicate(true))
	var state: String = str(summary().state)
	return _answer(state in ["awaiting-response","dispatching","proposed"],
		"The disclosed request was sent for proposal-only review." if state in ["awaiting-response","dispatching","proposed"] else "The proposal transport refused or retired this request.")

func _matches(identity: String, token: String) -> bool:
	return not _active.is_empty() and _active.request_id==identity and _active.token==token

func _pending_in(workflow: Object, identity: String) -> bool:
	if not is_instance_valid(workflow): return false
	var view: Variant=workflow.call("summary")
	if not view is Dictionary or not view.get("planning") is Dictionary: return false
	return view.planning.get("state")=="awaiting-proposal" and view.planning.get("request_id")==identity

func _pending(identity: String) -> bool:
	return _pending_in(_workflow,identity)

func _fresh(identity: String, token: String) -> bool:
	if not _matches(identity,token) or not _pending(identity) or not _context_guard.is_valid(): return false
	var valid: Variant=_context_guard.call(_active.request.duplicate(true))
	# The injected guard may emit a host change, cancel, or replace the request.
	return valid is bool and valid and _matches(identity,token) and _pending(identity)

func _pre_dispatch_guard(identity: String, token: String) -> bool:
	if not _matches(identity,token): return false
	_active.guard_called=true
	var valid:=_fresh(identity,token)
	if _matches(identity,token): _active.guard_passed=valid
	return valid

func _refuse_workflow(identity: String, workflow: Object) -> void:
	if _pending_in(workflow,identity):
		# Public typed admission retires this request. No private adapter mutation.
		workflow.call("accept_response",identity,{"format":"cybersand-architecture-transport-refusal-v1"})

func _cancel_owned(callback: Callable, provider_id: int, identity: String, reason: String) -> void:
	if callback.is_valid(): callback.call(provider_id,identity,reason.left(2048))

func _on_request(request: Dictionary) -> void:
	var request_host: Object=_workflow
	var request_seam:=_seam_serial
	var request_mode:=_mode
	var identity:=str(request.get("request_id",""))
	if request.get("format")!=REQUEST_FORMAT or identity.is_empty() or identity.length()>256 or request.get("mode")!="proposal_transport":
		_refuse_workflow(identity,_workflow); _record("refused",identity,-1,"Malformed proposal-only request."); return
	if _requests>=MAX_REQUESTS or _history.size()>MAX_EVENTS-RESERVED_EVENTS:
		_refuse_workflow(identity,_workflow); _record("refused",identity,-1,"Finite bridge request or history budget exhausted."); return
	if Compiler.canonical(request).to_utf8_buffer().size()>MAX_REQUEST_BYTES:
		_refuse_workflow(identity,_workflow); _record("refused",identity,-1,"Proposal request exceeds two MiB."); return
	if not _active.is_empty(): _retire_active("cancelled","A new host proposal replaced the previous owned request.",true)
	# Owner cancellation can bind another host and synchronously dispatch its
	# proposal. The outer signal must not overwrite that newer lifetime, even
	# if the replacement host deliberately reuses the same textual request ID.
	if _seam_serial!=request_seam or _workflow!=request_host or not _active.is_empty():
		_refuse_workflow(identity,request_host)
		_record("retired-request-signal",identity,-1,"A replacement owner lifetime superseded this request signal.","",false,request_mode)
		return
	if not _pending(identity) or not _dispatch.is_valid():
		_refuse_workflow(identity,_workflow); _record("refused",identity,-1,"No current exclusive owner dispatch is available."); return
	_requests+=1
	var token:=Crypto.new().generate_random_bytes(16).hex_encode()
	var owner_dispatch:=_dispatch
	var owner_cancel:=_cancel
	_active={"request_id":identity,"token":token,"request":request.duplicate(true),"provider_id":-1,
		"dispatching":true,"guard_called":false,"guard_passed":false,"early":{},"early_duplicate":false,
		"owner_cancel":owner_cancel,"evidence_mode":request_mode}
	_record("dispatching",identity,-1,"An owner-controlled proposal dispatch was requested.")
	if not _matches(identity,token): return
	var completion:=_on_finished.bind(identity,token,request_mode)
	var guard:=_pre_dispatch_guard.bind(identity,token)
	var admitted: Variant=owner_dispatch.call(request.duplicate(true),completion,guard)
	var returned_id: int=int(admitted.get("provider_id",-1)) if admitted is Dictionary and typeof(admitted.get("provider_id"))==TYPE_INT else -1
	if not _matches(identity,token):
		if returned_id>0: _cancel_owned(owner_cancel,returned_id,identity,"The request retired during owner dispatch.")
		_record("late-dispatch-return",identity,returned_id,"No retired request was reopened.","",false,request_mode); return
	if not admitted is Dictionary or admitted.get("ok")!=true or returned_id<1:
		_retire_active("refused","Owner transport did not admit one positive request identity.",true); return
	_active.provider_id=returned_id
	if not _active.guard_called or not _active.guard_passed:
		_retire_active("refused","Owner dispatch must check the supplied live guard before sending.",true); return
	if not _fresh(identity,token):
		if _matches(identity,token): _retire_active("context-invalid","Host proposal context changed during dispatch.",true)
		return
	_active.dispatching=false
	if _active.early_duplicate:
		_retire_active("refused","Multiple synchronous completions cannot identify one owner request.",true); return
	var early: Dictionary=_active.early
	_active.early={}
	if not early.is_empty():
		_on_finished(int(early.id),early.text,{},early.error,identity,token,request_mode)
	else:
		_record("awaiting-response",identity,returned_id,"Owner request admitted; no native operation was queued.")

func _on_finished(provider_id: int, text: String, _response: Dictionary, error: String,
		identity: String, token: String, evidence_mode: String) -> void:
	if not _matches(identity,token):
		_record("late-or-duplicate",identity,provider_id,"Completion is historical; its request lifetime retired.",text,false,evidence_mode); return
	if _active.dispatching:
		if not _active.early.is_empty(): _active.early_duplicate=true
		else:
			# Never retain the provider response dictionary, images, usage or secrets.
			# Oversized early text is reduced to an explicit refusal and bounded prefix.
			var oversized:=text.length()>MAX_RESPONSE_BYTES or text.to_utf8_buffer().size()>MAX_RESPONSE_BYTES
			_active.early={"id":provider_id,"text":text.left(MAX_RETAINED_CHARS) if oversized else text,
				"error":"Proposal response exceeds four MiB." if oversized else error.left(2048)}
		return
	if provider_id!=int(_active.provider_id):
		_record("uncorrelated-provider-id",identity,provider_id,"A different provider request cannot retire the current proposal.",text,false,evidence_mode); return
	if not _fresh(identity,token):
		if _matches(identity,token): _retire_active("context-invalid","Live host inspection no longer matches the proposal.",true,text)
		return
	if not error.is_empty():
		_retire_active("transport-error",error.left(2048),false,text); return
	if text.length()>MAX_RESPONSE_BYTES or text.to_utf8_buffer().size()>MAX_RESPONSE_BYTES:
		_retire_active("refused","Proposal response exceeds four MiB.",false,text); return
	var workflow: Object=_workflow
	_active.clear()
	# The native host independently checks its observation fence before typed parsing.
	# Clearing first prevents reentrant cancellation from altering a newer request.
	var answer: Variant=workflow.call("accept_response",identity,text)
	var admitted: bool=answer is Dictionary and answer.get("ok")==true
	var parser:=JSON.new()
	var json_valid:=parser.parse(text)==OK
	var status:="proposed" if admitted else "ordinary-text" if not json_valid else "typed-response-refused"
	var reason:=str(answer.get("reason","Finite proposal admitted for review only.")) if answer is Dictionary else "Host proposal admission returned no typed result."
	_record(status,identity,provider_id,reason,text,true,evidence_mode)

func _on_cancel_requested(identity: String) -> void:
	if not _active.is_empty() and _active.request_id==identity:
		_retire_active("cancelled","Owner Stop or a replaced host context retired this proposal.",true)

func _retire_active(status: String, reason: String, cancel_owner: bool, text: String="") -> void:
	if _active.is_empty(): return
	var retired: Dictionary=_active
	var retired_workflow: Object=_workflow
	_active={}
	if cancel_owner: _cancel_owned(retired.owner_cancel,int(retired.provider_id),retired.request_id,reason)
	_refuse_workflow(retired.request_id,retired_workflow)
	_record(status,retired.request_id,int(retired.provider_id),reason,text,true,retired.evidence_mode)

func _record(status: String, identity: String, provider_id: int, reason: String,
		text: String="", terminal_event:=false, evidence_mode: String="") -> void:
	var limit:=MAX_EVENTS if terminal_event or _active.is_empty() else MAX_EVENTS-RESERVED_EVENTS
	if _history.size()>=limit:
		_dropped_events=mini(_dropped_events+1,1000000)
		return
	var mode: String=_mode if evidence_mode.is_empty() else evidence_mode
	var retained:=text.left(MAX_RETAINED_CHARS)
	var exact:=""; var bounded:=text.length()<=MAX_RESPONSE_BYTES
	if bounded:
		var bytes:=text.to_utf8_buffer()
		bounded=bytes.size()<=MAX_RESPONSE_BYTES
		if bounded: exact=_digest(bytes)
	var row:={"status":status,"request_id":identity.left(256),"provider_id":provider_id,"reason":reason.left(2048),
		"text_prefix":retained,"text_characters":text.length(),"text_truncated":retained.length()!=text.length(),
		"bounded_complete_text_sha256":exact,"retained_prefix_sha256":_digest(retained.to_utf8_buffer()),
		"evidence_mode":mode,"real_model_calls":0 if mode=="fixture" else null,"zero_writes":true}
	_history.append(row); _last_status=status
	outcome.emit(row.duplicate(true)); changed.emit(summary())

func summary() -> Dictionary:
	return {"bound":is_instance_valid(_workflow),"active":not _active.is_empty(),"state":("dispatching" if _active.dispatching else "awaiting-response") if not _active.is_empty() else _last_status,
		"request_id":_active.get("request_id",""),"provider_id":_active.get("provider_id",-1),
		"requests_used":_requests,"requests_limit":MAX_REQUESTS,"history_events":_history.size(),
		"history_limit":MAX_EVENTS,"dropped_diagnostic_events":_dropped_events,"evidence_mode":_mode,
		"real_model_calls":0 if _mode=="fixture" else null,"zero_writes":true,
		"scope":"Correlation fixture or unqualified owner seam only. Native preview, owner approval and real model evidence are separate."}

func export_history() -> Dictionary:
	return {"format":FORMAT,"events":_history.duplicate(true),"dropped_diagnostic_events":_dropped_events,
		"scope":"Bounded historical outcomes only. Reopen never rebinds transport, resumes a request, selects a plan or grants approval."}
