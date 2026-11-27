extends SceneTree
## Isolated exact-source handoff probe. Production Provider, Art adapter,
## Architecture Bridge, Workflow and typed planning parser; deterministic local
## HTTP replies and explicitly copied inspection fixture. No native writes.
const Provider = preload("res://scripts/art_provider.gd")
const OwnerTransport = preload("res://scripts/art_proposal_transport.gd")
const Bridge = preload("res://scripts/batch_lab/architecture_proposal_bridge.gd")
const Workflow = preload("res://scripts/batch_lab/architecture_workflow.gd")
const Fixture = preload("res://tests/test_architecture_workflow.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Recipes = preload("res://scripts/batch_lab/architecture_intent_recipes.gd")
const Planning = preload("res://scripts/batch_lab/architecture_planning_adapter.gd")
var checks := 0
var failures: Array[String] = []
var provider: Node
var transport: RefCounted
var bridge: RefCounted
var workflow: Node
var session: Node
var settings: Dictionary = {}
var ordinary_completions := 0
var sockets := 0
var fixture_records: Array = []
var live := true

func _initialize() -> void: run.call_deferred()
func check(condition: bool, label: String) -> void:
	checks += 1
	print("ART_ARCHITECTURE_HANDOFF_CHECK ",label," ",condition)
	if not condition:
		failures.append(label)
		push_error(label)

func until(predicate: Callable, timeout_ms: int = 10000) -> bool:
	var deadline:=Time.get_ticks_msec()+timeout_ms
	while not bool(predicate.call()) and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())

func configuration() -> Dictionary: return settings.duplicate(true)

func current_context(request: Dictionary) -> bool:
	if not live or not is_instance_valid(session): return false
	var current: Dictionary=session.inspection_view()
	return request.get("inspection") is Dictionary and current.get("ok")==true \
		and request.inspection.get("source_sha256")==current.get("source_sha256") \
		and request.inspection.get("generation")==current.get("generation")

func listen() -> TCPServer:
	var server:=TCPServer.new()
	check(server.listen(0,"127.0.0.1")==OK,"real local server binds")
	settings.endpoint="http://127.0.0.1:%d/v1"%server.get_local_port()
	return server

func receive(server: TCPServer, receipt: Dictionary) -> StreamPeerTCP:
	if not await until(server.is_connection_available): return null
	sockets += 1
	var peer:=server.take_connection()
	var text:=""
	var deadline:=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		peer.poll()
		var available:=peer.get_available_bytes()
		if available>0:
			var data:=peer.get_data(available)
			if data[0]==OK: text+=(data[1] as PackedByteArray).get_string_from_utf8()
		if text.contains("\r\n\r\n"):
			var header:=text.get_slice("\r\n\r\n",0)
			var length:=0
			for line: String in header.split("\r\n"):
				if line.to_lower().begins_with("content-length:"): length=line.substr(15).strip_edges().to_int()
			if text.to_utf8_buffer().size()>=header.to_utf8_buffer().size()+4+length:
				var body: Variant=JSON.parse_string(text.substr(header.length()+4))
				if body is Dictionary and body.get("messages") is Array:
					var prompt: String=body.messages[-1].content
					receipt.request=JSON.parse_string(prompt.substr(prompt.find("\n")+1))
					receipt.received=true
				return peer
		await process_frame
	return null

func serve(server: TCPServer, receipt: Dictionary, mode: String="proposal") -> void:
	var peer: StreamPeerTCP=await receive(server,receipt)
	if peer!=null and receipt.get("request") is Dictionary:
		var request: Dictionary=receipt.request
		var built:=Recipes.build(request.request_id+"-owned-fixture","industrial_hangar",0,
			Compiler.rect(request.inspection.region),int(request.seed),request.materials)
		check(built.ok,"actual Architecture recipe supplies a valid typed fixture proposal")
		var proposal:={"format":Planning.FORMAT,"request_id":request.request_id,
			"inspection_sha256":request.inspection.source_sha256,"generation":request.inspection.generation,
			"alternatives":[{"id":"transport-option","title":"Industrial gallery proposal","summary":"Deterministic fixture, awaiting owner review.","campaign":built.campaign}],
			"uncertainty":["A loopback fixture is not genuine model inference."]}
		var result:=Compiler.canonical(proposal) if mode=="proposal" else '[{"shape":"rectangle","x0":0,"y0":0,"x1":10,"y1":10,"material":58}]'
		var body:=JSON.stringify({"choices":[{"message":{"content":result},"finish_reason":"stop"}]})
		var reply:="HTTP/1.1 200 Fixture\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"%[body.to_utf8_buffer().size(),body]
		receipt.sent=peer.put_data(reply.to_utf8_buffer())==OK
		for _i: int in range(6): await process_frame
		peer.disconnect_from_host()
	server.stop(); receipt.finished=true

func propose() -> Dictionary:
	return workflow.submit_intent("industrial hangar with an upper maintenance gallery",{"mode":"proposal_transport","max_alternatives":1})

func native_fixture_unchanged(original_plan: String, original_cells: String) -> bool:
	return Compiler.canonical(session.plan)==original_plan and Compiler.digest(session.fixture_cells)==original_cells \
		and session.preview.is_empty() and session.records.is_empty() and session._submission==-1

func run() -> void:
	provider=Provider.new(); root.add_child(provider)
	provider.finished.connect(func(_id: int,_text: String,_response: Dictionary,_error: String)->void: ordinary_completions+=1)
	session=Fixture.FixtureSession.new(); root.add_child(session)
	workflow=Workflow.new(); root.add_child(workflow)
	check(workflow.bind_session(session).ok,"actual Architecture Workflow binds its copied-inspection fixture")
	transport=OwnerTransport.new(); bridge=Bridge.new()
	settings={"provider":"LM Studio","endpoint":"http://127.0.0.1:1/v1","model":"architecture-loopback-fixture","key":"","tokens":8192,"seconds":5.0,"context":[]}
	check(transport.bind_owner(provider,configuration,current_context).ok,"production Art transport binds the one existing provider")
	check(bridge.bind_owner_seam(workflow,transport.dispatch,transport.cancel,current_context,"fixture").ok,"unchanged source-pinned Architecture bridge accepts Art owner contract")
	check(provider.serial==0 and provider.request==null and provider.log_path.is_empty(),"opening/binding complete handoff sends no HTTP and creates no audit")
	check(provider.get_signal_connection_list("finished").size()==1,"bridge and Art adapter add no ordinary completion listener")
	var original_plan:=Compiler.canonical(session.plan)
	var original_cells:=Compiler.digest(session.fixture_cells)
	var server:=listen()
	var receipt:={"finished":false,"received":false,"sent":false}
	serve.call_deferred(server,receipt)
	var answer:=propose()
	check(answer.ok and answer.status=="awaiting-proposal" and provider.active,"actual Workflow dispatch reaches production provider with pending proposal")
	check(await until(func()->bool:return receipt.finished and not provider.active),"actual complete handoff receives real loopback HTTP")
	check(receipt.received and receipt.sent and sockets==1,"one real transport exchange belongs to one request")
	check(workflow.planning.summary().state=="proposed" and bridge.export_history().events[-1].status=="proposed","unchanged Architecture typed parser accepts the completed proposal")
	check(native_fixture_unchanged(original_plan,original_cells),"a valid proposal does not select a plan, preview, approve or change fixture geometry")
	check(ordinary_completions==0,"typed architecture proposal never reaches ordinary Art auto-paint completion")
	fixture_records.append({"kind":"valid-proposal","request_id":receipt.request.request_id,"provider_id":provider.serial,"state":workflow.planning.summary().state})
	server=listen(); receipt={"finished":false,"received":false,"sent":false}
	serve.call_deferred(server,receipt,"direct-array")
	answer=propose()
	check(await until(func()->bool:return receipt.finished and not provider.active),"direct-shaped response traverses the real proposal-only path")
	check(workflow.planning.summary().state=="refused" and bridge.export_history().events[-1].status=="typed-response-refused","ordinary Art shape array is refused by Architecture's actual schema")
	check(native_fixture_unchanged(original_plan,original_cells) and ordinary_completions==0,"direct-shaped response cannot obtain paint or construction authority")
	server=listen()
	settings.context=[{"role":"user","content":"admitted copied context ".repeat(7000)}]
	answer=propose()
	check(answer.ok and provider.request_preparation_active(),"actual bridge hands off asynchronous request preparation")
	live=false
	check(await until(func()->bool:return not provider.active and not provider.request_preparation_active()),"live-context invalidation retires async preparation through the owner")
	check(not server.is_connection_available() and sockets==2,"bridge guard reaches eventual transport admission: stale async request sends zero HTTP")
	check(not bridge.summary().active and not transport.summary().active,"stale async request retires both correlated consumers")
	check(native_fixture_unchanged(original_plan,original_cells) and ordinary_completions==0,"stale preparation preserves all pre-native authorities")
	server.stop(); live=true
	server=listen(); answer=propose()
	check(answer.ok and provider.request_preparation_active(),"scoped Stop fixture has actual preparation pending")
	workflow.cancel()
	check(await until(func()->bool:return not provider.active and not provider.request_preparation_active()),"Workflow Stop reaches scoped provider cancellation")
	check(not server.is_connection_available() and not bridge.summary().active and not transport.summary().active,"Stop cannot leave a hidden request or consumer")
	server.stop()
	settings.context=[]
	server=listen(); answer=propose()
	var stalled:={"received":false}
	var peer: StreamPeerTCP=await receive(server,stalled)
	check(peer!=null and stalled.received,"native-owner replacement case has a real accepted request without headers")
	provider.cancel("World replacement")
	check(not bridge.summary().active and not transport.summary().active and not provider.active,"Art World replacement retires correlated Architecture proposal")
	check(native_fixture_unchanged(original_plan,original_cells) and ordinary_completions==0,"all handoff cases retain zero plan/preview/approval/native writes")
	if peer!=null: peer.disconnect_from_host()
	server.stop()
	bridge.detach_owner_seam(); transport.detach_owner()
	print("ART_ARCHITECTURE_HANDOFF_RESULT ",JSON.stringify({"format":"cybersand-art-architecture-handoff-probe-v1",
		"checks":checks,"failures":failures,"actual_http_exchanges":sockets,"ordinary_completions":ordinary_completions,
		"native_writes":0,"model_calls":0,"inspection_source":"explicit copied fixture; no native World claims",
		"fixture_records":fixture_records,"provider_sha256":FileAccess.get_sha256("res://scripts/art_provider.gd"),
		"adapter_sha256":FileAccess.get_sha256("res://scripts/art_proposal_transport.gd"),
		"architecture_bridge_sha256":FileAccess.get_sha256("res://scripts/batch_lab/architecture_proposal_bridge.gd"),
		"godot":Engine.get_version_info().string,"platform":OS.get_name()}))
	provider.queue_free(); workflow.queue_free(); session.queue_free(); await process_frame
	quit(1 if not failures.is_empty() else 0)
