extends SceneTree
## Real finite WorkerThreadPool values and complete native atomic audit writes.
## This mechanism test uses host guards, not a mock native World or inference.
const P = preload("res://scripts/art_provider.gd")
const Preparation = preload("res://scripts/art_response_preparation.gd")
const Redactor = preload("res://scripts/art_redaction.gd")
const SECRET := "conversation-edit-fixture-secret-72903"
const LATE_SECRET := "conversation-key-added-after-admission-73101"
var provider: Node
var checks := 0
var failures: Array[String] = []
var callbacks: Array = []
var ordinary_completions := 0
var state := {"live":true}
var live_turns: Array = []
var observations: Array = []

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> bool:
	checks+=1
	print("ART_CONVERSATION_PREPARATION_CHECK ",label," ",value)
	if not value: failures.append(label);push_error(label)
	return value
func until(predicate: Callable, timeout_ms := 15000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not bool(predicate.call()) and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func guard() -> bool: return bool(state.live)
func complete(handle: int, identity: Dictionary, error: String) -> void:
	callbacks.append({"handle":handle,"identity":identity.duplicate(true),"error":error})
func identity(value: int) -> Dictionary:
	return {"apply_generation":value,"conversation_revision":value,"editor_revision":value,"world_epoch":7,"provider_serial":provider.serial}
func begin(text: String, id: Dictionary) -> Dictionary:
	return provider.begin_conversation_edit([{"role":"user","content":text}],"unchanged native result",id,complete,guard)
func edited_count() -> int:
	var count := 0
	if provider.log_path.is_empty(): return count
	for line: String in FileAccess.get_file_as_string(provider.log_path).split("\n",false):
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and row.get("kind")=="conversation_edited": count+=1
	return count
func adopt(turns: Array) -> bool:
	check(provider.last_event_stored and not provider.log_path.is_empty(),"live adoption follows a complete durable audit identity")
	live_turns=turns
	return true
func wait_ready(handle: int) -> bool:
	return await until(func()->bool:
		return not callbacks.is_empty() and int(callbacks.back().handle)==handle)

func run() -> void:
	provider=P.new();root.add_child(provider)
	provider.finished.connect(func(_id:int,_text:String,_response:Dictionary,_error:String)->void:ordinary_completions+=1)
	provider.secrets.append(SECRET)
	var original := "x".repeat(1024*1024)+SECRET+" Bearer fixture-token-12345 "+LATE_SECRET
	var redactor := Redactor.new();redactor.secrets=[SECRET]
	var expected: String = redactor.redact(original)
	check(provider.log_path.is_empty() and not provider.active and not provider.conversation_edit_active(),"opening a provider creates no edit, HTTP or audit")
	check(not provider.begin_conversation_edit("bad","",identity(0),complete,guard).ok,"malformed turns refuse before worker admission")
	check(not provider.begin_conversation_edit([], "",{},complete,guard).ok,"empty identity refuses")
	var invalid_identity := {"node":provider}
	check(not provider.begin_conversation_edit([], "",invalid_identity,complete,guard).ok,"live objects cannot enter value identity")
	state.live=false
	check(not begin(original,identity(0)).ok and provider.log_path.is_empty(),"false initial context guard writes no draft or metadata")
	state.live=true
	var id := identity(1)
	var source: Array = [{"role":"user","content":original}]
	var began := Time.get_ticks_usec()
	var answer: Dictionary = provider.begin_conversation_edit(source,"unchanged native result",id,complete,guard)
	observations.append({"admission_usec":Time.get_ticks_usec()-began,"characters":original.length()})
	check(answer.ok and callbacks.is_empty(),"large edit is admitted with no synchronous completion")
	var handle: int = answer.handle
	check(not provider.active and provider.conversation_edit_state().phase=="preparing","pure-value preparation is distinct from HTTP active")
	check(provider.conversation_edit_preparation_jobs==1 and Preparation.pending_count()==1,"one actual worker is retained")
	source[0].content="caller mutated after admission"
	var changed_identity := id.duplicate();changed_identity.apply_generation=999
	check(not provider.cancel_conversation_edit(handle+1,id),"wrong handle cannot cancel owner job")
	check(not provider.cancel_conversation_edit(handle,changed_identity),"wrong host identity cannot cancel owner job")
	var listener := TCPServer.new()
	check(listener.listen(0,"127.0.0.1")==OK,"real no-dispatch observer binds")
	var endpoint := "http://127.0.0.1:%d/v1" % listener.get_local_port()
	check(not provider.send("LM Studio",endpoint,"fixture","","[]","rules",32,1.0).is_empty(),"new HTTP dispatch refuses during pure-value edit")
	check(await wait_ready(handle),"finite background preparation reaches its sole completion")
	check(callbacks.size()==1 and callbacks[0].error.is_empty() and callbacks[0].identity==id,"ready completion retains exact host identity")
	check(not listener.is_connection_available() and ordinary_completions==0,"conversation preparation makes zero HTTP and zero ordinary completions")
	listener.stop()
	var peek: Variant = provider.prepared_conversation_edit_turns(handle,id)
	check(peek is Array and peek[0].content==expected,"prepared complete text matches current credential redaction and immutable input")
	peek[0].content="untrusted caller replacement"
	check(provider.prepared_conversation_edit_turns(handle,id)[0].content==expected,"returned preview cannot mutate private executable audit values")
	var forged := Preparation.new()
	check(not provider._record_event("conversation_edited",{"turns":[{"role":"user","content":SECRET}],"last_result":""},
		null,null,"",PackedByteArray(),forged),"unregistered prepared object cannot bypass redaction or audit authority")
	check(edited_count()==0,"preview and forged object write no edited conversation")
	check(not provider.commit_conversation_edit(handle+1,id,adopt,guard).ok and provider.conversation_edit_active(),"wrong commit handle cannot consume another owner")
	var observed := {"armed":true,"saw_adopted":false,"successor":{}}
	var observer := func()->void:
		if not observed.armed: return
		observed.armed=false
		observed.saw_adopted=live_turns.size()==1 and live_turns[0].content==expected
		provider.cancel("Stop after the edit commit point")
		observed.successor=begin("successor stays owned",identity(2))
	provider.traffic_changed.connect(observer)
	var committed: Dictionary = provider.commit_conversation_edit(handle,id,adopt,guard)
	provider.traffic_changed.disconnect(observer)
	check(committed.ok and committed.committed and committed.adopted,"exact prepared edit commits and adopts once")
	check(observed.saw_adopted,"reentrant audit observers see the already committed live conversation")
	check(observed.successor.get("ok",false) and provider.conversation_edit_state().handle==observed.successor.handle,"old commit cannot retire the reentrant successor")
	check(edited_count()==1 and not FileAccess.get_file_as_string(provider.log_path).contains(SECRET),"complete edited audit is stored once and redacts credential")
	check(not provider.commit_conversation_edit(handle,id,adopt,guard).ok,"consumed handle cannot append twice")
	check(await wait_ready(int(observed.successor.handle)),"reentrant successor finishes independently")
	var successor_id: Dictionary = callbacks.back().identity
	check(provider.cancel_conversation_edit(int(observed.successor.handle),successor_id,"No conversation changes"),"ready no-op can be retired without an edit")
	check(edited_count()==1 and not provider.conversation_edit_active(),"no-op retirement leaves audit and live history untouched")
	# Cancellation really overlaps the finite value task and never admits its draft.
	var baseline_count := edited_count()
	var baseline_callbacks := callbacks.size()
	id=identity(3);answer=begin(original,id);handle=answer.handle
	check(answer.ok and not provider._conversation_edit_preparation.reaped,"Stop fixture has actual outstanding worker")
	provider.cancel("Owner Stop during conversation preparation")
	check(not provider.conversation_edit_state().phase in ["preparing","ready"],"Stop invalidates edit identity immediately")
	for retry: int in 4:
		check(not begin(original,identity(40+retry)).ok,"rapid retry cannot accumulate cancelled jobs")
	check(await until(func()->bool:return Preparation.pending_count()==0 and callbacks.size()>baseline_callbacks),"cancelled worker reaps and reports only retirement")
	check(not callbacks.back().error.is_empty() and edited_count()==baseline_count,"cancelled draft never becomes an edited audit event")
	check(provider.peak_conversation_edit_preparation_jobs==1,"one retained conversation preparation slot")
	# Applicable owner context, credentials and journal admissions all fence publication.
	id=identity(4);answer=begin(original,id);handle=answer.handle;state.live=false
	check(await wait_ready(handle),"stale context retires actual background job")
	check(not callbacks.back().error.is_empty() and edited_count()==baseline_count,"stale context cannot publish")
	state.live=true
	id=identity(5);answer=begin(original,id);handle=answer.handle;provider.secrets.append(LATE_SECRET)
	check(await wait_ready(handle),"changed credential set retires preparation")
	check(not callbacks.back().error.is_empty() and edited_count()==baseline_count,"old-secret prepared value cannot append")
	id=identity(6);answer=begin(original,id);handle=answer.handle
	check(await wait_ready(handle) and callbacks.back().error.is_empty(),"fresh explicit Apply admits updated credential snapshot")
	peek=provider.prepared_conversation_edit_turns(handle,id)
	check(peek is Array and not str(peek[0].content).contains(LATE_SECRET),"new credential is redacted in the new prepared value")
	provider.secrets.append("credential-added-after-ready")
	check(provider.prepared_conversation_edit_turns(handle,id)==null,"ready preview refuses after secret change")
	check(not provider.commit_conversation_edit(handle,id,adopt,guard).ok and edited_count()==baseline_count,"late secret change refuses final commit")
	# Guard reentrancy can append a new live turn immediately before final append.
	id=identity(7);answer=begin(original,id);handle=answer.handle
	check(await wait_ready(handle) and callbacks.back().error.is_empty(),"final-guard control is prepared")
	var final_guard := func()->bool:
		provider.log_event("conversation",{"role":"assistant","content":"newer admitted owner turn"})
		return true
	check(not provider.commit_conversation_edit(handle,id,adopt,final_guard).ok,"reentrant final guard journal change refuses old edited append")
	check(edited_count()==baseline_count and FileAccess.get_file_as_string(provider.log_path).contains("newer admitted owner turn"),"newer audit action survives refused stale Apply")
	# The last admission callback must fence both the archive and live projections.
	var unpublished := "draft-refused-at-actual-append-18491"
	var next_secret := "credential-registered-by-final-guard-83917"
	id=identity(70);answer=begin("z".repeat(1024*1024)+unpublished+next_secret,id);handle=answer.handle
	check(await wait_ready(handle) and callbacks.back().error.is_empty(),"unpublished draft reaches ready before final credential rotation")
	var original_traffic: String = provider.traffic
	var original_readable: String = provider.readable
	var original_audit_hash := FileAccess.get_sha256(provider.log_path)
	var rotate_and_refuse := func()->bool:
		provider.secrets.append(next_secret)
		return false
	check(not provider.commit_conversation_edit(handle,id,adopt,rotate_and_refuse).ok,"credential-changing final guard refuses at actual append")
	check(edited_count()==baseline_count and FileAccess.get_sha256(provider.log_path)==original_audit_hash,"final credential refusal leaves archive byte-identical")
	check(provider.traffic==original_traffic and provider.readable==original_readable,"final credential refusal leaves both live traffic projections byte-identical")
	check(not provider.traffic.contains(unpublished) and not provider.readable.contains(next_secret),"unpublished draft and newly registered credential never enter live traffic")
	# Character admission and actual UTF-8 replay budgets are separate.
	id=identity(8);answer=begin("€".repeat(6*1024*1024),id);handle=answer.handle
	check(answer.ok and await wait_ready(handle),"bounded Unicode job reaches explicit byte-cap result")
	check(not callbacks.back().error.is_empty() and edited_count()==baseline_count,"UTF-8 over-cap content cannot enter conversation audit")
	# Ordinary owner teardown cancels without worker filesystem ownership.
	id=identity(9);answer=begin(original,id)
	var audit_path: String = provider.log_path
	var before_hash := FileAccess.get_sha256(audit_path)
	var callback_count := callbacks.size()
	provider.queue_free();await process_frame
	check(await until(func()->bool:return Preparation.pending_count()==0),"orphaned edit value job is reaped after provider destruction")
	check(FileAccess.get_sha256(audit_path)==before_hash and callbacks.size()==callback_count,"owner destruction permits no late append or owner callback")
	# Queued teardown is already stale, before the SceneTree delete flush runs.
	provider=P.new()
	check(not begin(original,identity(90)).ok and provider.log_path.is_empty(),"detached provider cannot admit a conversation value worker")
	root.add_child(provider)
	id=identity(91);answer=begin(original,id);handle=answer.handle
	check(await wait_ready(handle) and callbacks.back().error.is_empty(),"provider teardown fixture has an actual ready immutable job")
	audit_path=provider.log_path
	before_hash=FileAccess.get_sha256(audit_path)
	var queued_traffic: String = provider.traffic
	var queued_readable: String = provider.readable
	provider.queue_free()
	check(not begin(original,identity(92)).ok,"queued provider refuses fresh admission before delete flush")
	check(provider.prepared_conversation_edit_turns(handle,id)==null,"queued provider refuses ready-value access before delete flush")
	check(not provider.commit_conversation_edit(handle,id,adopt,guard).ok,"queued provider refuses ready commit before delete flush")
	check(FileAccess.get_sha256(audit_path)==before_hash and provider.traffic==queued_traffic and provider.readable==queued_readable,
		"queued provider publishes no edited archive or live projections")
	await process_frame
	check(await until(func()->bool:return Preparation.pending_count()==0),"queued ready provider leaves no unreaped value work")
	# First-journal adoption is completed before worker start, including reentrancy.
	provider=P.new();root.add_child(provider)
	provider.commit_segment=func(_path:String)->bool:
		provider.cancel("Reentrant first-journal cancellation")
		return false
	answer=begin(original,identity(10))
	check(not answer.ok and not provider.conversation_edit_active() and Preparation.pending_count()==0,"reentrant journal refusal leaves no unstarted worker in the stopping slot")
	provider.queue_free();await process_frame
	print("ART_CONVERSATION_PREPARATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"model_calls":0,"actual_http_exchanges":0,"ordinary_completions":ordinary_completions,
		"observations":observations,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"Actual finite worker values and native atomic audit owner; host guard fixtures, no native World mutation."}))
	quit(0 if failures.is_empty() else 1)
