extends SceneTree
## Production mount over one ordinary native Workbench. All HTTP is deterministic
## numeric loopback; no real model, cloud call or physical acceptance is claimed.
const Setup = preload("res://scripts/workbench_setup.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Planning = preload("res://scripts/batch_lab/architecture_planning_adapter.gd")
const Recipes = preload("res://scripts/batch_lab/architecture_intent_recipes.gd")
const Session = preload("res://scripts/batch_lab/architecture_stage_session.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const REGION := Rect2i(16,16,256,256)
const KEY := "architecture-mount-synthetic-key-not-a-provider-credential"
var host: Control
var wb: Control
var architecture: Window
var art: Window
var mount: Node
var session: Node
var workflow: Node
var checks := 0
var failures: Array[String] = []
var ordinary_completions := 0
var sockets := 0
var stages: Array = []

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	set_meta("cybersand_feature","shared_workbench")
	var adapter: Object = ClassDB.instantiate(&"CyberDemoBridge")
	set_meta("cybersand_playable_recovery",{"workbench":Setup.fresh(adapter.call(&"default_liquid_policy"),Vector2i(512,512))})
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print("ART_ARCHITECTURE_WORKBENCH_CHECK ",label," ",value)
	if not value: failures.append(label); push_error(label)
	return value

func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	var progress := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker.has_failed(): break
		if Time.get_ticks_msec()>=progress:
			print("ART_ARCHITECTURE_WORKBENCH_WAIT ",label); progress=Time.get_ticks_msec()+10000
		await process_frame
	return check(false,label+" exceeded the established operation watchdog")

func installed() -> bool:
	return wb != null and not wb.applied.is_empty() and not wb.busy() and host.pending_microscenario_apply.is_empty()

func capture() -> PackedByteArray:
	var value: Dictionary = await wb.capture_batch_source(REGION)
	check(value.get("ok",false),"actual native material capture completes")
	return value.get("config",{}).get("source_cells",PackedByteArray())

func listen() -> TCPServer:
	var server := TCPServer.new()
	check(server.listen(0,"127.0.0.1")==OK,"fixture binds a real numeric loopback listener")
	art.endpoint.text = "http://127.0.0.1:%d/v1" % server.get_local_port()
	return server

func receive(server: TCPServer, result: Dictionary) -> StreamPeerTCP:
	if not await until(server.is_connection_available,"explicit Send reaches loopback"): return null
	sockets += 1
	var peer := server.take_connection()
	var bytes := PackedByteArray()
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec()<deadline:
		peer.poll()
		var count := peer.get_available_bytes()
		if count>0:
			var received := peer.get_data(count)
			if received[0]==OK: bytes.append_array(received[1])
		var text := bytes.get_string_from_utf8()
		var boundary := text.find("\r\n\r\n")
		if boundary>=0:
			var headers := text.left(boundary)
			var length := 0
			for line: String in headers.split("\r\n"):
				if line.to_lower().begins_with("content-length:"): length=line.substr(15).strip_edges().to_int()
			if bytes.size()>=headers.to_utf8_buffer().size()+4+length:
				var packet: Variant = JSON.parse_string(text.substr(boundary+4))
				if packet is Dictionary and packet.get("messages") is Array:
					var prompt: String = packet.messages[-1].content
					result.request = JSON.parse_string(prompt.substr(prompt.find("\n")+1))
					result.credentials_match = headers.contains("Authorization: Bearer "+KEY)
					result.message_count = packet.messages.size()
					result.received = true
				return peer
		await process_frame
	check(false,"complete loopback request body arrives")
	return null

func serve(server: TCPServer, result: Dictionary) -> void:
	var peer: StreamPeerTCP = await receive(server,result)
	if peer != null and result.get("request") is Dictionary:
		var request: Dictionary = result.request
		var built := Recipes.build(request.request_id+"-fixture","industrial_hangar",0,
			Compiler.rect(request.inspection.region),int(request.seed),request.materials)
		check(built.ok,"deterministic typed proposal uses the real Architecture validator")
		var proposal := {"format":Planning.FORMAT,"request_id":request.request_id,
			"inspection_sha256":request.inspection.source_sha256,"generation":request.inspection.generation,
			"alternatives":[{"id":"mount-option","title":"Industrial hall","summary":"Three separately approved native stages.","campaign":built.campaign}],
			"uncertainty":["Deterministic fixture, not genuine inference."]}
		var body := JSON.stringify({"choices":[{"message":{"content":Compiler.canonical(proposal)},"finish_reason":"stop"}]})
		var response := "HTTP/1.1 200 Fixture\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [body.to_utf8_buffer().size(),body]
		result.sent = peer.put_data(response.to_utf8_buffer())==OK
		for _frame: int in 6: await process_frame
		peer.disconnect_from_host()
	server.stop(); result.finished=true

func prepare() -> bool:
	var value: Dictionary = await architecture.prepare_art_proposal()
	mount = architecture.art_proposal_mount
	return check(value.get("ok",false),"actual visible Prepare captures a source-bound disclosure / "+str(value.get("reason","")))

func run() -> void:
	host = load("res://main.tscn").instantiate(); root.add_child(host); wb=host.shared_workbench
	if not await until(installed,"ordinary native Workbench initializes"): await finish(); return
	check(wb.art_batches == null and wb.architecture_lab == null,"ordinary startup creates neither optional authoring panel")
	var worker_id: int = host.simulation_worker.get_instance_id()
	var world_generation: int = host.simulation_worker.paint_state().generation
	wb.open_architecture_lab(); architecture=wb.architecture_lab
	session=architecture.session; workflow=architecture.workflow
	check(wb.art_batches == null and architecture.art_proposal_mount == null,"opening Architecture creates no Art provider or proposal mount")
	art=wb._ensure_art_batches(); art.hide()
	art.current_provider="LM Studio"; art.model.text="production-mount-loopback-fixture"
	art.tokens.value=8192; art.seconds.value=20; art.keys["LM Studio"]=KEY
	var provider_id: int = art.provider.get_instance_id()
	art.provider.finished.connect(func(_id: int,_text: String,_data: Dictionary,_error: String) -> void: ordinary_completions+=1)
	var finished_listeners: int = art.provider.finished.get_connections().size()
	var pane: Control = architecture.workflow_panel
	pane.intent.text="Build an industrial hall with a clear lower passage and roof-mounted maintenance services."
	for index: int in pane.family.item_count:
		if pane.family.get_item_metadata(index)=="industrial_hangar": pane.family.select(index)
	for index: int in 4: pane.region_fields[index].value=[16,16,256,256][index]
	var before := await capture()
	var original_plan := Compiler.canonical(session.plan)
	var server := listen()
	if not await prepare(): server.stop(); await finish(); return
	var disclosure: Dictionary = mount.disclosure()
	check(not disclosure.is_empty() and architecture.art_proposal_dialog.visible,"Prepare presents the production disclosure dialog")
	check(not server.is_connection_available() and not art.provider.active and art.provider.serial==0 and art.provider.log_path.is_empty(),"preparing and reviewing sends no network request or provider audit")
	check(disclosure.endpoint==art.endpoint.text and disclosure.model==art.model.text and disclosure.request_text.contains(Compiler.digest(before)),"disclosure names exact destination, model and inspected native identity")
	check(not disclosure.request_text.contains(KEY) and disclosure.scope.contains("No image or earlier Art conversation"),"disclosure excludes credentials and unrelated Art session context")
	check(not mount.send_disclosed("wrong-disclosure").ok and not server.is_connection_available(),"an unrelated disclosure token cannot authorize sending")
	if not await prepare(): server.stop(); await finish(); return
	art.model.text="changed-after-disclosure"
	check(not architecture.send_art_proposal().ok and art.provider.serial==0 and not server.is_connection_available(),"changing the configured model invalidates the unsent disclosure")
	art.model.text="production-mount-loopback-fixture"
	if not await prepare(): server.stop(); await finish(); return
	var exchange := {"finished":false,"received":false,"sent":false}
	serve.call_deferred(server,exchange)
	if not check(architecture.send_art_proposal().ok,"explicit production Send admits one proposal request"): server.stop(); await finish(); return
	if not await until(func()->bool:return exchange.finished and not art.provider.active,"proposal-only response completes"): await finish(); return
	check(exchange.received and exchange.sent and exchange.credentials_match and exchange.message_count==2,"one actual HTTP exchange uses Art configuration and excludes prior conversation")
	check(workflow.planning.summary().state=="proposed" and ordinary_completions==0,"one Architecture consumer receives the typed response without ordinary painting")
	check(art.provider.finished.get_connections().size()==finished_listeners,"production mount adds no listener to ordinary Art completion")
	check((await capture())==before and Compiler.canonical(session.plan)==original_plan and session.records.is_empty(),"receiving a proposal neither writes native cells nor selects a plan")
	check(workflow.select_alternative("mount-option").ok and (await capture())==before,"explicit option adoption still performs zero native writes")
	for index: int in session.plan.stages.size():
		if not check(workflow.select(index).ok,"owner selects native stage "+str(index)): break
		check(not (await workflow.approve()).get("ok",true),"unpreviewed stage refuses execution")
		var stage_before := await capture()
		if not check((await workflow.preview_selected()).get("ok",false),"fresh native stage preview succeeds"): break
		var projection: PackedByteArray = session.preview.projected_cells.duplicate()
		check((await capture())==stage_before,"stage preview leaves the complete native plane unchanged")
		var approval: Dictionary = await workflow.approve()
		if not check(approval.get("ok",false) and approval.get("queued",false) and not approval.get("completed",true),"fresh approval queues without inventing completion"): break
		if not await until(func()->bool:return not session.busy(),"approved native stage retires"): break
		if not check(session.stage_state()=="completed","native stage returns a completed readback"): break
		var record: Dictionary = session.records.back()
		check(Session.receipt_accounting(record.native_receipts,record.budget).complete,"native receipt accounting matches approved work")
		check(record.native_receipts[0].backend=="CyberNativeCellWorld" and record.result_sha256==record.expected_sha256 and (await capture())==projection,"actual native authority and full plane match the approved projection")
		stages.append({"stage":record.stage_id,"changed":record.changed_cells,"checked":record.checked_cells,"result_sha256":record.result_sha256})
	check(stages.size()==3 and (await capture())!=before,"all three independently approved stages change the actual World")
	for _index: int in stages.size():
		if not check(wb.paint_editor.undo(),"ordinary native Undo admits a completed stage"): break
		await until(func()->bool:return not wb.paint_editor.busy(),"ordinary native Undo retires")
	check((await capture())==before,"ordinary Undo exactly restores the full pre-proposal material plane")
	check(host.simulation_worker.get_instance_id()==worker_id and host.simulation_worker.paint_state().generation==world_generation and art.provider.get_instance_id()==provider_id,"proposal and construction preserve one existing worker, World and Art provider")
	# Settings and world/session changes must revoke previously disclosed work.
	server=listen()
	if not await prepare(): server.stop(); await finish(); return
	art.key_dialog_provider="LM Studio"; art.key_field.text=KEY+"-replacement"; art._apply_provider_key()
	check(not architecture.send_art_proposal().ok and not server.is_connection_available(),"changing the Art credential through its real control invalidates permission")
	art.key_field.text=KEY; art._apply_provider_key()
	if not await prepare(): server.stop(); await finish(); return
	var replacement := Session.new(); replacement.wb=wb; replacement.library=architecture.library; architecture.add_child(replacement)
	check(workflow.bind_session(replacement).ok,"public workflow session replacement is admitted while idle")
	check(not architecture.send_art_proposal().ok and not server.is_connection_available(),"a replaced StageSession cannot inherit the old disclosure")
	check(workflow.bind_session(session).ok,"original Architecture session can be rebound explicitly")
	replacement.queue_free(); await process_frame
	if not await prepare(): server.stop(); await finish(); return
	check(wb.new_canvas(),"ordinary owner World replacement is admitted before sending")
	await until(installed,"replacement native World initializes")
	check(not architecture.send_art_proposal().ok and not server.is_connection_available(),"a replacement native World refuses the old proposal before HTTP")
	server.stop()
	# Hide remains ordinary Art presentation. Scoped Architecture Stop retires
	# only its owned request; direct Art work keeps its existing lifecycle.
	server=listen()
	if not await prepare(): server.stop(); await finish(); return
	if not check(architecture.send_art_proposal().ok,"fresh owner context admits the no-headers request"): server.stop(); await finish(); return
	var stalled := {}
	var peer: StreamPeerTCP = await receive(server,stalled)
	check(peer!=null and stalled.get("received",false),"actual provider socket is accepted without response headers")
	var altered: Dictionary = mount._pending.duplicate(true)
	altered.intent = "Undisclosed replacement under the same request and inspection identity"
	check(mount._live_guard(mount._pending) and not mount._live_guard(altered),"live disclosure authority covers every request value, not only its identity and inspection")
	art._close_art_window()
	for _frame: int in 3: await process_frame
	check(art.provider.active and mount.bridge.summary().active,"ordinary Art Hide preserves the current owned request")
	architecture.stop_all()
	check(not art.provider.active and not mount.bridge.summary().active and not mount.transport.summary().active,"Architecture Stop retires its single provider request and callback")
	if peer!=null: peer.disconnect_from_host()
	server.stop()
	server=listen()
	art.request_epoch=host.simulation_worker.art_state().epoch
	var ordinary_error: String = art.provider.send("LM Studio",art.endpoint.text,"ordinary-direct-fixture",KEY,"Wait for owner Stop","No native operation",128,20)
	var ordinary_serial: int = art.provider.serial
	check(ordinary_error.is_empty() and art.provider.active,"ordinary Art request remains independently admissible")
	var refused: Dictionary = await architecture.prepare_art_proposal()
	check(not refused.ok and art.provider.active and art.provider.serial==ordinary_serial,"Architecture refuses an occupied provider without cancelling ordinary Art")
	art.stop_all("Fixture teardown"); server.stop()
	check(ordinary_completions==0 and sockets==2,"only the two explicitly sent fixture requests reached a socket")
	check(not FileAccess.get_file_as_string(art.provider.log_path).contains(KEY),"the complete shared Art audit excludes its synthetic credential")
	await finish()

func finish() -> void:
	var result := {"checks":checks,"failures":failures,"native_stages":stages,"actual_http_exchanges":sockets,
		"ordinary_completions":ordinary_completions,"model_calls":0,"godot":Engine.get_version_info().string,
		"platform":OS.get_name(),"display":DisplayServer.get_name(),
		"scope":"Actual production host mount, deterministic HTTP and native stage/Undo evidence; physical and creative owner acceptance remain outstanding."}
	print("ART_ARCHITECTURE_WORKBENCH_RESULT ",JSON.stringify(result))
	if is_instance_valid(host): host.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
