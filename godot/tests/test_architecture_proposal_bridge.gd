extends SceneTree
## Actual accepted Provider signature + inherited signal; all successful dispatches
## below are controlled overrides with zero HTTP, credentials or native execution.
const Bridge=preload("res://scripts/batch_lab/architecture_proposal_bridge.gd")
const Workflow=preload("res://scripts/batch_lab/architecture_workflow.gd")
const WorkflowFixture=preload("res://tests/test_architecture_workflow.gd")
const Provider=preload("res://scripts/art_provider.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Recipes=preload("res://scripts/batch_lab/architecture_intent_recipes.gd")
const Adapter=preload("res://scripts/batch_lab/architecture_planning_adapter.gd")

class AcceptedProviderFixture extends Provider:
	var fixture_calls:=0
	var fixture_cancels: Array=[]
	func send(_provider: String,_endpoint: String,_model: String,_key: String,_prompt: String,_instructions: String,
			_tokens: int,_seconds: float,_png: String="",_context: Array=[],_pre_dispatch_guard: Callable=Callable()) -> String:
		fixture_calls+=1; serial+=1; active=true
		return ""
	func cancel(reason: String="Human Stop") -> void:
		fixture_cancels.append(reason); active=false

class OwnerFixture extends RefCounted:
	var provider:=AcceptedProviderFixture.new()
	var completion:=Callable()
	var current_request: Dictionary={}
	var captured: Array=[]
	var before_guard:=Callable()
	var use_guard:=true
	var immediate:=""
	var reused_provider_id:=-1
	var cancellations: Array=[]
	var cancellation_hook:=Callable()
	func _init() -> void:
		# The owner is the only listener. The bridge receives its explicit callback.
		provider.finished.connect(_owned_finished)
	func dispatch(request: Dictionary,callback: Callable,guard: Callable) -> Dictionary:
		current_request=request.duplicate(true); completion=callback
		if before_guard.is_valid(): before_guard.call()
		if use_guard and not guard.call(): return {"ok":false,"reason":"Live owner pre-dispatch guard refused."}
		var problem:=provider.send("LM Studio","fixture://never-network","signature-fixture","",
			Compiler.canonical(request),"Return a typed architecture proposal only.",128,1.0,"",[])
		if not problem.is_empty(): return {"ok":false,"reason":problem}
		if reused_provider_id>0: provider.serial=reused_provider_id
		captured.append({"provider_id":provider.serial,"request":request.duplicate(true),"callback":callback})
		if immediate=="valid" or immediate=="duplicate":
			_owned_finished(provider.serial,typed_text(request),{},"")
			if immediate=="duplicate": _owned_finished(provider.serial,typed_text(request),{},"")
		elif immediate=="invalid": _owned_finished(provider.serial,"ordinary response",{},"")
		return {"ok":true,"provider_id":provider.serial}
	func cancel_owned(provider_id: int,identity: String,reason: String) -> void:
		cancellations.append({"provider_id":provider_id,"request_id":identity,"reason":reason})
		if current_request.get("request_id")==identity and (provider_id<0 or provider_id==provider.serial): provider.cancel(reason)
		if cancellation_hook.is_valid(): cancellation_hook.call()
	func _owned_finished(id: int,text: String,response: Dictionary,error: String) -> void:
		if completion.is_valid(): completion.call(id,text,response,error)
	func deliver(text: String,error: String="",provider_id: int=-1,response: Dictionary={}) -> void:
		provider.active=false
		provider.finished.emit(provider.serial if provider_id<0 else provider_id,text,response,error)
	static func typed_object(request: Dictionary) -> Dictionary:
		var built:=Recipes.build(str(request.request_id)+"-fixture","industrial_hangar",0,Compiler.rect(request.inspection.region),
			int(request.seed),request.materials)
		return {"format":Adapter.FORMAT,"request_id":request.request_id,"inspection_sha256":request.inspection.source_sha256,
			"generation":request.inspection.generation,"alternatives":[{"id":"owner-option","title":"Owner fixture option",
			"summary":"Finite typed structure; no stage has been previewed or approved.","campaign":built.campaign}],"uncertainty":[]}
	static func typed_text(request: Dictionary) -> String: return Compiler.canonical(typed_object(request))

class CorrelationHost extends RefCounted:
	signal proposal_transport_requested(request: Dictionary)
	signal proposal_cancel_requested(request_id: String)
	var state:="idle"
	var refusals:=0
	func summary() -> Dictionary:
		return {"planning":{"state":state,"request_id":"same-host-fixture-id"}}
	func accept_response(_identity: String,_response: Variant) -> Dictionary:
		refusals+=1; state="refused"
		return {"ok":false,"reason":"Synthetic correlation host refusal."}
	func begin() -> void:
		state="awaiting-proposal"
		proposal_transport_requested.emit({"format":Bridge.REQUEST_FORMAT,"request_id":"same-host-fixture-id","mode":"proposal_transport"})
	func stop() -> void:
		state="cancelled"; proposal_cancel_requested.emit("same-host-fixture-id")

var checks:=0
var failures:=0
var workflow: Variant
var session: Variant
var owner: Variant
var bridge: Variant
var host_live:=true

func check(condition: bool,label: String) -> void:
	checks+=1; print("ARCHITECTURE_PROPOSAL_BRIDGE_CHECK ",label," ",condition)
	if not condition: failures+=1; push_error(label)

func live_context(_request: Dictionary) -> bool: return host_live

func request(options: Dictionary={}) -> Dictionary:
	var merged:={"mode":"proposal_transport","max_alternatives":1}
	merged.merge(options,true)
	return workflow.submit_intent("industrial hangar",merged)

func last_status() -> String:
	var events: Array=bridge.export_history().events
	return str(events[-1].status) if not events.is_empty() else ""

func _initialize() -> void: run.call_deferred()
func run() -> void:
	session=WorkflowFixture.FixtureSession.new(); root.add_child(session)
	workflow=Workflow.new(); root.add_child(workflow); workflow.bind_session(session)
	owner=OwnerFixture.new(); bridge=Bridge.new()
	check(not bridge.bind_owner_seam(workflow,Callable(),Callable(),Callable(),"fixture").ok,"an explicit complete owner seam is required")
	check(bridge.bind_owner_seam(workflow,owner.dispatch,owner.cancel_owned,live_context,"fixture").ok,"explicit fixture seam binds")
	check(owner.provider.get_signal_connection_list("finished").size()==1,"bridge never installs a second ordinary Provider completion listener")
	var original_plan:=Compiler.canonical(session.plan)
	var pending:=request()
	check(pending.ok and pending.status=="awaiting-proposal" and owner.provider.fixture_calls==1,"accepted send signature dispatches one correlated fixture request")
	check(bridge.summary().active and bridge.summary().provider_id==owner.provider.serial,"positive provider identity belongs to one live request")
	owner.deliver(OwnerFixture.typed_text(owner.current_request),"",-1,{"private_test_marker":"provider-metadata-not-retained"})
	check(workflow.planning.summary().state=="proposed" and last_status()=="proposed","real JSON roundtrip admits a finite proposal")
	check(Compiler.canonical(session.plan)==original_plan and session.preview.is_empty() and session.records.is_empty() and session._submission==-1,"typed proposal creates no native plan, preview, queue or completion")
	check(not Compiler.canonical(bridge.export_history()).contains("provider-metadata-not-retained"),"provider response dictionaries are not duplicated into bridge history")
	var prior: Dictionary=owner.captured[-1]
	prior.callback.call(prior.provider_id,OwnerFixture.typed_text(prior.request),{},"")
	check(last_status()=="late-or-duplicate" and workflow.planning.summary().state=="proposed","duplicate completion cannot create a second proposal")
	request(); owner.deliver("Please clarify the hangar height.")
	check(last_status()=="ordinary-text" and bridge.export_history().events[-1].text_prefix=="Please clarify the hangar height.","ordinary text remains bounded historical evidence")
	request(); owner.deliver("{ invalid")
	check(last_status()=="ordinary-text" and workflow.planning.summary().state=="refused","invalid JSON refuses without the error-printing parse_string API")
	request(); owner.deliver('[{"shape":"rectangle","x0":0,"y0":0,"x1":20,"y1":20,"material":58}]')
	check(last_status()=="typed-response-refused" and session._submission==-1,"ordinary Art operation arrays cannot bypass stage approval")
	request(); owner.deliver(OwnerFixture.typed_text(owner.current_request),"fixture transport failure")
	check(last_status()=="transport-error" and workflow.planning.summary().state=="refused","transport failure wins over valid-looking proposal text")
	request()
	var mutated:=OwnerFixture.typed_object(owner.current_request)
	mutated.alternatives[0].campaign.region[2]+=1
	owner.deliver(Compiler.canonical(mutated))
	check(last_status()=="typed-response-refused","integer normalization cannot widen the inspected region")
	request(); mutated=OwnerFixture.typed_object(owner.current_request)
	for node: Dictionary in mutated.alternatives[0].campaign.nodes:
		if node.kind!="group": node.stage.materials.append(58.5)
	owner.deliver(Compiler.canonical(mutated))
	check(last_status()=="typed-response-refused","fractional material identities remain invalid")
	request(); mutated=OwnerFixture.typed_object(owner.current_request)
	for node: Dictionary in mutated.alternatives[0].campaign.nodes:
		if node.kind!="group": node.stage.materials.append(13)
	owner.deliver(Compiler.canonical(mutated))
	check(last_status()=="typed-response-refused","valid integer palette expansion remains forbidden")
	request({"materials":[58.0,28.0]}); owner.deliver(OwnerFixture.typed_text(owner.current_request))
	check(last_status()=="proposed","exact integral JSON options normalize without weakening scope")
	request(); var current_id: int=owner.provider.serial
	owner.deliver(OwnerFixture.typed_text(owner.current_request),"",current_id+999)
	check(bridge.summary().active and last_status()=="uncorrelated-provider-id","wrong provider identity cannot retire the correct request")
	owner.deliver(OwnerFixture.typed_text(owner.current_request))
	check(last_status()=="proposed","correct identity still completes after unrelated traffic")
	pending=request(); prior=owner.captured[-1]; workflow.cancel()
	check(not bridge.summary().active and not owner.cancellations.is_empty(),"Stop retires the bridge before owner cancellation")
	prior.callback.call(prior.provider_id,OwnerFixture.typed_text(prior.request),{},"")
	check(last_status()=="late-or-duplicate" and workflow.planning.summary().state!="proposed","late cancelled completion never resumes construction")
	request(); host_live=false; owner.deliver(OwnerFixture.typed_text(owner.current_request)); host_live=true
	check(last_status()=="context-invalid" and not bridge.summary().active,"live host guard retires stale responses")
	request(); session.fence.manual+=1; owner.deliver(OwnerFixture.typed_text(owner.current_request))
	check(last_status()=="typed-response-refused" and workflow.planning.summary().state!="proposed","Workflow independently rejects an obsolete native observation fence")
	owner.immediate="valid"; pending=request(); owner.immediate=""
	check(pending.get("status")=="proposed" and last_status()=="proposed","synchronous owner completion waits for provider identity then returns the correct result")
	owner.immediate="invalid"; pending=request(); owner.immediate=""
	check(not pending.ok and workflow.planning.summary().state=="refused","synchronous refusal is not reported as awaiting a response")
	owner.immediate="duplicate"; pending=request(); owner.immediate=""
	check(not pending.ok and last_status()=="refused","multiple synchronous completions cannot self-certify one dispatch")
	owner.use_guard=false; pending=request(); owner.use_guard=true
	check(not pending.ok and last_status()=="refused","owner must invoke the live pre-dispatch guard")
	owner.before_guard=func()->void: workflow.cancel()
	var calls: int=owner.provider.fixture_calls
	pending=request(); owner.before_guard=Callable()
	check(not pending.ok and owner.provider.fixture_calls==calls,"Stop during dispatch prevents the fixture send")
	request(); prior=owner.captured[-1]; workflow.cancel()
	owner.reused_provider_id=prior.provider_id
	request(); owner.reused_provider_id=-1
	prior.callback.call(prior.provider_id,OwnerFixture.typed_text(prior.request),{},"")
	check(bridge.summary().active and last_status()=="late-or-duplicate","lifetime token defeats numerical provider ID reuse")
	owner.deliver(OwnerFixture.typed_text(owner.current_request))
	check(last_status()=="proposed","new lifetime with reused numeric ID admits only its own callback")
	request(); owner.deliver("x".repeat(Bridge.MAX_RESPONSE_BYTES+1))
	var row: Dictionary=bridge.export_history().events[-1]
	check(row.status=="refused" and row.text_prefix.length()==Bridge.MAX_RETAINED_CHARS and row.text_truncated and row.bounded_complete_text_sha256.is_empty(),"oversized text is refused with an explicit bounded retained prefix")
	request()
	for index: int in 140: prior.callback.call(prior.provider_id,"late-"+str(index),{},"")
	check(bridge.summary().active and bridge.summary().dropped_diagnostic_events>0,"late diagnostic flood cannot consume active terminal capacity")
	owner.deliver(OwnerFixture.typed_text(owner.current_request))
	check(last_status()=="proposed" and bridge.export_history().events.size()<=Bridge.MAX_EVENTS,"active terminal outcome survives bounded history pressure")
	calls=owner.provider.fixture_calls; pending=request()
	check(not pending.ok and owner.provider.fixture_calls==calls,"history capacity refusal dispatches no extra request")
	check(bridge.summary().real_model_calls==0 and owner.provider.secrets.is_empty() and owner.provider.request==null,"accepted interface fixtures make zero HTTP calls and store no credentials")
	bridge.detach_owner_seam()
	check(owner.provider.get_signal_connection_list("finished").size()==1 and not bridge.summary().bound,"detach leaves the owner's ordinary completion connection intact")
	var seam:=Bridge.new()
	var first_host:=CorrelationHost.new(); var next_host:=CorrelationHost.new()
	var local_owner:=OwnerFixture.new(); var rebindings: Array=[]
	seam.bind_owner_seam(first_host,local_owner.dispatch,local_owner.cancel_owned,live_context,"fixture")
	first_host.begin()
	local_owner.cancellation_hook=func()->void:
		rebindings.append(seam.bind_owner_seam(next_host,local_owner.dispatch,local_owner.cancel_owned,live_context,"fixture"))
	seam.detach_owner_seam()
	check(not rebindings[0].ok and not seam.summary().bound and first_host.get_signal_connection_list("proposal_transport_requested").is_empty() and next_host.get_signal_connection_list("proposal_transport_requested").is_empty(),"reentrant cancellation cannot attach an orphan host during detach")
	local_owner.cancellation_hook=Callable()
	seam.bind_owner_seam(first_host,local_owner.dispatch,local_owner.cancel_owned,live_context,"fixture")
	first_host.begin()
	local_owner.cancellation_hook=func()->void:
		rebindings.append(seam.bind_owner_seam(next_host,local_owner.dispatch,local_owner.cancel_owned,live_context,"fixture"))
		next_host.begin()
	first_host.stop()
	check(rebindings[-1].ok and seam.summary().active and next_host.refusals==0 and first_host.get_signal_connection_list("proposal_transport_requested").is_empty(),"retiring an old host cannot refuse a replacement host with the same request ID")
	local_owner.cancellation_hook=Callable(); seam.detach_owner_seam()
	first_host=CorrelationHost.new(); next_host=CorrelationHost.new()
	seam.bind_owner_seam(first_host,local_owner.dispatch,local_owner.cancel_owned,live_context,"fixture")
	first_host.begin()
	var earlier_calls: int=local_owner.provider.fixture_calls
	local_owner.cancellation_hook=func()->void:
		seam.bind_owner_seam(next_host,local_owner.dispatch,local_owner.cancel_owned,live_context,"fixture")
		next_host.begin()
	# A second signal while the first dispatch is active causes cancellation.
	# Its callback synchronously binds a new host with the identical request ID.
	first_host.begin()
	check(seam.summary().active and seam._workflow==next_host and next_host.refusals==0 and local_owner.provider.fixture_calls==earlier_calls+1,"outer request signal cannot overwrite a nested replacement dispatch")
	local_owner.cancellation_hook=Callable(); seam.detach_owner_seam(); local_owner.provider.free()
	var accepted:=Provider.new()
	var error:=accepted.send("LM Studio","fixture://never-network","","","typed fixture","typed fixture",128,1.0,"",[])
	check(not error.is_empty() and accepted.request==null and not accepted.active,"actual accepted Provider rejects an empty model before HTTP")
	accepted.cancel("fixture idle cancel")
	check(accepted.request==null and not accepted.active,"actual accepted cancellation signature is callable without transport")
	accepted.free(); owner.provider.free(); workflow.queue_free(); session.queue_free()
	await process_frame
	print("ARCHITECTURE_PROPOSAL_BRIDGE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
