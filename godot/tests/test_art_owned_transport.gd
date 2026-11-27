extends SceneTree
## Real deterministic loopback HTTP plus the production Provider/owner adapter.
## No model inference, duplicate provider, native mutation or synthetic World.
const P = preload("res://scripts/art_provider.gd")
const Transport = preload("res://scripts/art_proposal_transport.gd")
const Capabilities = preload("res://scripts/art_provider_capabilities.gd")
const SECRET := "owned-fixture-key-not-a-real-credential-72903"
var checks := 0
var failures: Array[String] = []
var provider: Node
var ordinary: Array = []
var owned: Array = []
var observations: Array = []
var guard_state := {"live":true,"calls":0}
var configuration: Dictionary = {}
var configuration_calls := 0

func _initialize() -> void: run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	print("ART_OWNED_CHECK ",label," ",condition)
	if not condition:
		failures.append(label)
		push_error(label)

func until(predicate: Callable, timeout_ms: int = 10000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not bool(predicate.call()) and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())

func live() -> bool:
	guard_state.calls += 1
	return bool(guard_state.live)

func owner_live(_request: Dictionary) -> bool: return bool(guard_state.live)

func config() -> Dictionary:
	configuration_calls += 1
	return configuration.duplicate(true)

func completed(id: int, text: String, response: Dictionary, error: String) -> void:
	owned.append({"id":id,"text":text,"response":response.duplicate(true),"error":error})

func parameters(endpoint: String, identity: String, mode: String = "propose") -> Dictionary:
	return {"request_id":identity,"mode":mode,"provider":"LM Studio","endpoint":endpoint,
		"model":"owned-loopback-fixture","key":SECRET,"prompt":"Create a bounded proposal.",
		"instructions":"Propose only. Never execute or fabricate a native receipt.","tokens":4096,"seconds":5.0,"context":[]}

func reply(text: String) -> String:
	return JSON.stringify({"model":"fixture-deployment","private_echo":SECRET,
		"choices":[{"message":{"content":text},"finish_reason":"stop"}],
		"usage":{"prompt_tokens":111,"completion_tokens":27}})

func endpoint(listener: TCPServer) -> String:
	return "http://127.0.0.1:%d/v1" % listener.get_local_port()

func listener() -> TCPServer:
	var value := TCPServer.new()
	check(value.listen(0,"127.0.0.1")==OK,"real loopback listener binds")
	return value

func receive(server: TCPServer, receipt: Dictionary) -> StreamPeerTCP:
	if not await until(server.is_connection_available): return null
	var peer := server.take_connection()
	var bytes := PackedByteArray()
	var deadline := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		peer.poll()
		var available := peer.get_available_bytes()
		if available > 0:
			var incoming := peer.get_data(available)
			if incoming[0]==OK: bytes.append_array(incoming[1])
		var text := bytes.get_string_from_utf8()
		var boundary := text.find("\r\n\r\n")
		if boundary>=0:
			var headers := text.left(boundary)
			var length := 0
			for line: String in headers.split("\r\n"):
				if line.to_lower().begins_with("content-length:"): length=line.substr(15).strip_edges().to_int()
			if bytes.size()>=headers.to_utf8_buffer().size()+4+length:
				receipt.wire_headers=headers
				receipt.wire_body=text.substr(boundary+4)
				receipt.received=true
				return peer
		await process_frame
	return null

func serve(server: TCPServer, body: String, receipt: Dictionary, code: int = 200) -> void:
	var peer: StreamPeerTCP = await receive(server,receipt)
	if peer!=null:
		var header := "HTTP/1.1 %d Fixture\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [code,body.to_utf8_buffer().size()]
		receipt.sent=peer.put_data((header+body).to_utf8_buffer())==OK
		for _frame: int in range(6): await process_frame
		peer.disconnect_from_host()
	server.stop()
	receipt.finished=true

func exchange(mode: String, text: String) -> Dictionary:
	var server := listener()
	var fixture := {"sent":false,"finished":false,"received":false}
	serve.call_deferred(server,reply(text),fixture)
	var before := owned.size()
	var direct_before := ordinary.size()
	var guard_before := int(guard_state.calls)
	var admitted: Dictionary = provider.send_owned(parameters(endpoint(server),"owned-"+mode,mode),completed,live)
	check(admitted.ok and admitted.provider_id>0,mode+" admits one positive provider identity")
	check(await until(func()->bool:return fixture.finished and not provider.active),mode+" real socket completes")
	check(fixture.received and fixture.sent,mode+" has an actual HTTP request and response")
	check(owned.size()==before+1 and owned.back().id==admitted.provider_id,mode+" has exactly one correlated completion")
	check(ordinary.size()==direct_before,mode+" never reaches ordinary completion-to-paint signal")
	check(guard_state.calls>=guard_before+3,mode+" checks live context at preparation, admission and completion")
	check(owned.back().text==provider.redact(text),mode+" keeps complete redacted response text")
	check(not JSON.stringify(owned.back()).contains(SECRET) and not owned.back().response.has("private_echo"),mode+" keeps credentials and raw response outside the consumer")
	check(provider.owned_request().state=="success",mode+" publishes a host terminal status")
	var wire: Variant = JSON.parse_string(fixture.wire_body)
	check(wire is Dictionary and wire.model=="owned-loopback-fixture" and wire.max_tokens==4096,mode+" preserves explicit transport settings")
	check(str(fixture.wire_headers).contains("Authorization: Bearer "+SECRET),mode+" uses the configured key only on transport")
	observations.append({"mode":mode,"provider_id":admitted.provider_id,"received":true,"ordinary_completions":ordinary.size()-direct_before,
		"owned_completions":owned.size()-before,"request_bytes":str(fixture.wire_body).to_utf8_buffer().size(),
		"response_text_sha256":str(owned.back().text).sha256_text()})
	return admitted

func event_count(kind: String) -> int:
	return FileAccess.get_file_as_string(provider.log_path).count('"kind":"'+kind+'"') if not provider.log_path.is_empty() else 0

func refused_guard_and_no_listener() -> void:
	var server := listener()
	var settings := parameters(endpoint(server),"immediate-stale")
	var before := owned.size()
	var direct_before := ordinary.size()
	guard_state.live=false
	var admitted: Dictionary=provider.send_owned(settings,completed,live)
	check(not admitted.ok and not server.is_connection_available() and not provider.active,"immediate false guard refuses before any HTTP admission")
	check(owned.size()==before+1 and not owned.back().error.is_empty(),"preparation admission cancellation reports its captured consumer once")
	guard_state.live=true
	admitted=provider.send_owned(parameters(endpoint(server),"invalid-guard-value"),completed,func()->String:return "true")
	check(not admitted.ok and not server.is_connection_available(),"truthy non-Boolean values cannot authorize transport")
	var absent_endpoint:=endpoint(server)
	server.stop()
	before=owned.size()
	admitted=provider.send_owned(parameters(absent_endpoint,"absent-listener"),completed,live)
	check(admitted.ok,"absent-listener request is distinguished from invalid admission")
	check(await until(func()->bool:return not provider.active),"real absent-listener request reaches transport failure")
	check(owned.size()==before+1 and owned.back().error.contains("Connection") and not owned.back().error.contains("HTTP 404"),"absent listener has one truthful connection error, not a mock HTTP failure")
	check(ordinary.size()==direct_before,"failed owned requests never enter ordinary completion")

func malformed_and_http_failure() -> void:
	for condition: Dictionary in [{"code":200,"body":"{ incomplete response","name":"malformed"},
			{"code":404,"body":JSON.stringify({"error":{"message":"invalid model "+SECRET}}),"name":"invalid-model"}]:
		var server:=listener()
		var fixture:={"sent":false,"finished":false,"received":false}
		serve.call_deferred(server,condition.body,fixture,int(condition.code))
		var before:=owned.size()
		var direct_before:=ordinary.size()
		provider.send_owned(parameters(endpoint(server),condition.name),completed,live)
		check(await until(func()->bool:return fixture.finished and not provider.active),condition.name+" real HTTP failure finishes")
		check(owned.size()==before+1 and owned.back().text.is_empty() and not owned.back().error.is_empty(),condition.name+" gives one error with no invented successful text")
		check(not owned.back().error.contains(SECRET) and ordinary.size()==direct_before,condition.name+" is credential-safe and never ordinary paint")

func cancelled_preparation(use_stop: bool) -> void:
	var server := listener()
	var before := owned.size()
	var direct_before := ordinary.size()
	var settings := parameters(endpoint(server),"preparation-stop" if use_stop else "preparation-stale")
	settings.context=[{"role":"user","content":"frozen context ".repeat(12000)}]
	var admitted: Dictionary = provider.send_owned(settings,completed,live)
	check(admitted.ok and provider.request_preparation_active(),"large outgoing request is asynchronously prepared")
	if use_stop:
		check(provider.cancel_owned(admitted.provider_id,settings.request_id,"Owner Stop during preparation"),"scoped Stop owns pending preparation")
	else: guard_state.live=false
	check(await until(func()->bool:return not provider.request_preparation_active() and not provider.active),"cancelled/stale preparation drains without blocking")
	check(not server.is_connection_available(),"invalidated asynchronous preparation makes no HTTP connection")
	check(owned.size()==before+1 and not owned.back().error.is_empty(),"cancelled/stale preparation has one truthful terminal callback")
	check(ordinary.size()==direct_before,"cancelled preparation never falls through to ordinary painting")
	guard_state.live=true
	server.stop()

func stalled_cancel() -> void:
	var server := listener()
	var fixture := {"received":false}
	var before := owned.size()
	var direct_before := ordinary.size()
	var admitted: Dictionary = provider.send_owned(parameters(endpoint(server),"scoped-stall"),completed,live)
	var peer: StreamPeerTCP = await receive(server,fixture)
	check(peer!=null and fixture.received,"scoped cancellation uses accepted socket without response headers")
	check(not provider.cancel_owned(admitted.provider_id+1,"scoped-stall","wrong id"),"wrong numeric identity cannot cancel another request")
	check(not provider.cancel_owned(admitted.provider_id,"different-owner","wrong owner"),"wrong textual identity cannot cancel another request")
	check(not provider.cancel_owned(-2,"scoped-stall","invalid wildcard"),"only bridge sentinel minus one has synchronous-dispatch meaning")
	check(provider.active,"refused scoped cancellation leaves the owned request active")
	var began := Time.get_ticks_usec()
	check(provider.cancel_owned(-1,"scoped-stall","Owner Stop"),"exact textual identity cancels a dispatch whose ID has not returned")
	check(Time.get_ticks_usec()-began<2000000,"accepted-socket cancellation stays below unchanged two-second lifecycle gate")
	check(owned.size()==before+1 and ordinary.size()==direct_before,"scoped Stop emits one owned error and no ordinary response")
	if peer!=null: peer.disconnect_from_host()
	server.stop()

func incoming_stale() -> void:
	var server := listener()
	var fixture := {"sent":false,"finished":false,"received":false}
	var text := "complete bounded proposal context ".repeat(12000)
	serve.call_deferred(server,reply(text),fixture)
	var before := owned.size()
	var direct_before := ordinary.size()
	provider.send_owned(parameters(endpoint(server),"incoming-stale"),completed,live)
	check(await until(func()->bool:return provider.response_preparation_active()),"large successful incoming body enters asynchronous response preparation")
	guard_state.live=false
	check(await until(func()->bool:return fixture.finished and not provider.active and not provider.response_preparation_active()),"stale incoming preparation retires")
	check(owned.size()==before+1 and owned.back().text.is_empty() and not owned.back().error.is_empty(),"stale completed body grants no proposal publication")
	check(ordinary.size()==direct_before,"stale incoming proposal is never ordinary paint")
	guard_state.live=true

func audit_reentrant_successor() -> void:
	var original := listener()
	var successor := listener()
	var old_fixture := {"sent":false,"finished":false,"received":false}
	var new_fixture := {"sent":false,"finished":false,"received":false}
	serve.call_deferred(original,reply("old proposed response"),old_fixture)
	serve.call_deferred(successor,reply("fresh successor response"),new_fixture)
	var baseline := event_count("response")
	var armed := {"value":true,"successor_id":-1}
	var before := owned.size()
	var direct_before := ordinary.size()
	var observer := func()->void:
		if not armed.value or event_count("response")<=baseline: return
		armed.value=false
		provider.cancel("World replacement during response audit")
		var next: Dictionary=provider.send_owned(parameters(endpoint(successor),"audit-successor"),completed,live)
		armed.successor_id=next.provider_id
	provider.traffic_changed.connect(observer)
	var old: Dictionary=provider.send_owned(parameters(endpoint(original),"audit-original"),completed,live)
	check(await until(func()->bool:return old_fixture.finished and new_fixture.finished and not provider.active),"response audit reentrancy completes real original and successor transports")
	provider.traffic_changed.disconnect(observer)
	check(not armed.value and owned.size()==before+2,"response-audit replacement retires old callback exactly once")
	check(owned[before].id==old.provider_id and not owned[before].error.is_empty(),"old response is a cancellation, never the new request")
	check(owned.back().id==armed.successor_id and owned.back().text=="fresh successor response", "audit reentrancy preserves the successor's captured consumer")
	check(ordinary.size()==direct_before,"neither reentrant owned completion enters ordinary paint")

func cancellation_audit_successor() -> void:
	var original := listener()
	var successor := listener()
	var new_fixture := {"sent":false,"finished":false,"received":false}
	serve.call_deferred(successor,reply("successor survived old cancellation"),new_fixture)
	var before := owned.size()
	var old: Dictionary=provider.send_owned(parameters(endpoint(original),"cancel-audit-original"),completed,live)
	var baseline := event_count("cancelled")
	var armed := {"value":true,"successor_id":-1}
	var observer := func()->void:
		if not armed.value or event_count("cancelled")<=baseline: return
		armed.value=false
		var next: Dictionary=provider.send_owned(parameters(endpoint(successor),"cancel-audit-successor"),completed,live)
		armed.successor_id=next.provider_id
	provider.traffic_changed.connect(observer)
	provider.cancel_owned(old.provider_id,"cancel-audit-original","Human Stop")
	provider.traffic_changed.disconnect(observer)
	check(owned.size()==before+1 and owned.back().id==old.provider_id,"cancel retires old consumer before its audit can open a new one")
	check(provider.active and provider.owned_request().request_id=="cancel-audit-successor","old cancellation callback cannot clear successor ownership")
	check(await until(func()->bool:return new_fixture.finished and not provider.active),"cancellation-audit successor finishes over real loopback")
	check(owned.size()==before+2 and owned.back().id==armed.successor_id and owned.back().error.is_empty(),"successor survives old cancellation completion")
	original.stop()

func architecture_route() -> void:
	var adapter := Transport.new()
	var server := listener()
	configuration={"provider":"LM Studio","endpoint":endpoint(server),"model":"captured-model","key":SECRET,
		"tokens":4096,"seconds":5.0,"context":[{"role":"user","content":"captured-context ".repeat(6000)}]}
	var baseline_serial: int=provider.serial
	var count := configuration_calls
	check(adapter.bind_owner(provider,config,owner_live).ok,"Architecture handoff binds the existing Art provider")
	check(provider.serial==baseline_serial and configuration_calls==count and not server.is_connection_available(),"binding/opening handoff does not request settings or dispatch HTTP")
	var request := {"format":Transport.FORMAT,"request_id":"architecture-fixture-1","mode":"proposal_transport",
		"intent":"Repair the industrial upper gallery; preserve the lower passage.",
		"inspection":{"source_sha256":"host-inspection-fixture","generation":17,"material_counts":{0:24,58:32}}}
	var original := request.duplicate(true)
	var fixture := {"sent":false,"finished":false,"received":false}
	var typed := JSON.stringify({"format":"cybersand-architecture-proposal-v1","request_id":request.request_id,
		"inspection_sha256":"host-inspection-fixture","generation":17,"alternatives":[],"uncertainty":["fixture only"]})
	serve.call_deferred(server,reply(typed),fixture)
	var before := owned.size()
	var direct_before := ordinary.size()
	var admitted := adapter.dispatch(request,completed,live)
	check(admitted.ok and provider.request_preparation_active(),"owner injection starts actual asynchronous Provider preparation")
	configuration.model="changed-after-admission"; configuration.key="different-key-after-admission"
	configuration.endpoint="http://127.0.0.1:1/v1"
	request.intent="mutated request after admission"
	check(not adapter.cancel(admitted.provider_id,"unrelated-request","wrong owner"),"Architecture cancellation is scoped to its captured host identity")
	check(await until(func()->bool:return fixture.finished and not provider.active),"Architecture owned route completes through real loopback")
	check(owned.size()==before+1 and owned.back().text==typed and ordinary.size()==direct_before,"Architecture receives its exclusive typed completion without ordinary painting")
	var wire: Variant = JSON.parse_string(fixture.wire_body)
	check(wire is Dictionary and wire.model=="captured-model", "request preparation keeps the original model configuration")
	check(str(fixture.wire_headers).contains(SECRET) and not str(fixture.wire_headers).contains("different-key-after-admission"),"request preparation keeps original endpoint and credential snapshot")
	check(str(wire.messages[-1].content).contains(original.intent) and not str(wire.messages[-1].content).contains(request.intent),"model context uses an immutable request snapshot")
	check(not adapter.summary().active and not JSON.stringify(adapter.summary()).contains(SECRET),"handoff releases completed ownership and exposes no credentials")
	var forbidden := original.duplicate(true)
	forbidden.endpoint="http://example.invalid"
	check(not adapter.dispatch(forbidden,completed,live).ok,"untrusted proposal cannot override configured transport destination")
	forbidden=original.duplicate(true); forbidden.key="malicious-config"
	check(not adapter.dispatch(forbidden,completed,live).ok,"untrusted proposal cannot inject a provider credential")
	check(adapter.detach_owner().ok and not adapter.summary().bound,"explicit detach releases owner hook without touching ordinary listener")
	check(provider.get_signal_connection_list("finished").size()==1,"handoff never attaches a second ordinary response consumer")

func rejected_parameters() -> void:
	var before_serial: int=provider.serial
	var settings := parameters("http://127.0.0.1:1/v1","parameter-refusal")
	var invalid: Array=[]
	var copy:=settings.duplicate(true); copy.mode="direct"; invalid.append(copy)
	copy=settings.duplicate(true); copy.tokens=4.5; invalid.append(copy)
	copy=settings.duplicate(true); copy.seconds=INF; invalid.append(copy)
	copy=settings.duplicate(true); copy.context=Object.new(); invalid.append(copy)
	copy=settings.duplicate(true); copy.prompt="x".repeat(P.MAX_OWNED_REQUEST_BYTES+1); invalid.append(copy)
	copy=settings.duplicate(true); copy.context=[{"role":"user","content":"\n".repeat(1100000)}]; invalid.append(copy)
	for index: int in invalid.size():
		var answer: Dictionary=provider.send_owned(invalid[index],completed,live)
		check(not answer.ok and provider.request==null,"malformed/oversized owned request %d refuses before HTTP"%index)
	invalid[3].context.free()
	check(not provider.send_owned(settings,Callable(),live).ok,"owned request requires one live response consumer")
	check(not provider.send_owned(settings,completed,Callable()).ok,"owned request requires a live dispatch guard")
	check(provider.serial==before_serial,"pre-admission validation does not manufacture provider identities")

func run() -> void:
	provider=P.new(); root.add_child(provider)
	provider.finished.connect(func(id: int,text: String,response: Dictionary,error: String)->void:
		ordinary.append({"id":id,"text":text,"response":response,"error":error}))
	check(provider.request==null and provider.serial==0 and provider.log_path.is_empty(),"constructing Provider sends nothing and creates no audit")
	var capabilities:=Capabilities.summary("LM Studio","http://127.0.0.1:1234/v1")
	check(capabilities.endpoint_category=="loopback-address" and capabilities.text_wire and capabilities.image_model=="unverified", "adapter capability display does not invent model image support")
	check(not capabilities.streaming and capabilities.model_context_tokens==null and capabilities.model_availability=="unverified", "streaming, context and availability stay truthful")
	check(Capabilities.endpoint_category("https://127.0.0.1@example.invalid/v1")=="external-or-custom", "userinfo cannot masquerade as a local provider")
	check(Capabilities.endpoint_category("http://[::1]:1234/v1")=="loopback-address", "literal IPv6 loopback is classified without a network probe")
	check(Capabilities.endpoint_category("http://localhost:1234/v1")=="local-hostname-unverified", "localhost resolution is not asserted from its spelling")
	await rejected_parameters()
	var geometry := '[{"shape":"rectangle","x0":0,"y0":0,"x1":30,"y1":30,"material":58}]'
	for mode: String in P.OWNED_MODES:
		await exchange(mode,geometry+" "+SECRET)
	var before := owned.size()
	var direct_before := ordinary.size()
	provider._finish_request(provider.serial,"duplicate response",{},"",{},Time.get_ticks_usec())
	provider._finish_request(provider.serial-1,"late response",{},"",{},Time.get_ticks_usec())
	check(owned.size()==before and ordinary.size()==direct_before,"duplicate/late owned completion cannot fall through after callback retirement")
	var server := listener()
	var fixture := {"sent":false,"finished":false,"received":false}
	serve.call_deferred(server,reply(geometry),fixture)
	check(provider.send("LM Studio",endpoint(server),"direct-fixture",SECRET,"draw","rules",4096,5.0,"",[],live).is_empty(),"legacy eleven-argument direct send remains available")
	check(not provider.cancel_owned(-1,"owned-propose","unrelated cancellation"),"owned cancellation never cancels ordinary direct Art")
	check(await until(func()->bool:return fixture.finished and not provider.active),"legacy direct transport completes")
	check(ordinary.size()==direct_before+1 and owned.size()==before and ordinary.back().text==geometry,"legacy direct response reaches its ordinary consumer exactly once")
	await refused_guard_and_no_listener()
	await malformed_and_http_failure()
	await cancelled_preparation(false)
	await cancelled_preparation(true)
	await stalled_cancel()
	await incoming_stale()
	await audit_reentrant_successor()
	await cancellation_audit_successor()
	await architecture_route()
	var audit := FileAccess.get_file_as_string(provider.log_path)
	check(not audit.is_empty() and audit.contains('"kind":"response"') and audit.contains('"kind":"owned_request"'),"complete owned transport stays in the existing session audit")
	check(not audit.contains(SECRET) and audit.contains("[redacted]"),"complete request/response audit redacts the configured key")
	check(provider.parent_log_path.is_empty(),"owned collaboration never attaches a previous-session archive")
	var evidence := {"format":"cybersand-art-owned-transport-evidence-v1","checks":checks,"failures":failures,
		"model_calls":0,"transport":"actual deterministic loopback HTTP","observations":observations,
		"ordinary_completions":ordinary.size(),"owned_completions":owned.size(),"audit_sha256":audit.sha256_text(),
		"provider_sha256":FileAccess.get_sha256("res://scripts/art_provider.gd"),"adapter_sha256":FileAccess.get_sha256("res://scripts/art_proposal_transport.gd"),
		"godot":Engine.get_version_info().string,"platform":OS.get_name()}
	print("ART_OWNED_TRANSPORT_RESULT ",JSON.stringify(evidence))
	provider.queue_free(); await process_frame
	quit(1 if not failures.is_empty() else 0)
