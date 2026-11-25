extends SceneTree
## Separate combined experiment: qualified Architecture 17c plus Art provider closure.
## Real ordinary Workbench, existing Art panel/provider, native StageSession and
## deterministic HTTP proposals. No genuine inference or principal qualification.
const OwnerTransport = preload("res://scripts/art_proposal_transport.gd")
const Bridge = preload("res://scripts/batch_lab/architecture_proposal_bridge.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Recipes = preload("res://scripts/batch_lab/architecture_intent_recipes.gd")
const Planning = preload("res://scripts/batch_lab/architecture_planning_adapter.gd")
const StageSession = preload("res://scripts/batch_lab/architecture_stage_session.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const REGION := Rect2i(16,16,256,256)
const FIXTURE_KEY := "synthetic-native-handoff-key-never-a-real-provider-credential"
var main: Control
var wb: Control
var architecture: Window
var art: Window
var session: Node
var workflow: Node
var transport: RefCounted
var bridge: RefCounted
var checks := 0
var failures: Array[String] = []
var ordinary_completions := 0
var sockets := 0
var extra_context: Array = []
var evidence := ""
var phases: Array = []
var native_records: Array = []
var undo_evidence: Dictionary = {}

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print("ART_ARCHITECTURE_NATIVE_CHECK ",label," ",value)
	if not value: failures.append(label); push_error(label)
	return value

func until(predicate: Callable, label: String, timeout_ms := 90000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return check(bool(predicate.call()),label)

func installed() -> bool:
	return is_instance_valid(wb) and not wb.applied.is_empty() and not wb.busy() and main.pending_microscenario_apply.is_empty()

func configuration() -> Dictionary:
	# This is explicit experiment host mounting, not a new production UI API.
	# Credentials and transport settings come from the one actual Art panel.
	art.request_epoch=int(main.simulation_worker.art_state().epoch)
	art._register_provider_keys_for_redaction()
	return {"provider":art.current_provider,"endpoint":art.endpoint.text,
		"model":art.model.text,"key":str(art.keys.get(art.current_provider,"")),
		"tokens":int(art.tokens.value),"seconds":float(art.seconds.value),
		"context":extra_context.duplicate(true)}

func current_context(request: Dictionary) -> bool:
	if not installed() or not is_instance_valid(session) or not bool(main.paused): return false
	var current: Dictionary = session.inspection_view()
	return request.get("inspection") is Dictionary and current.get("ok")==true and current.get("stale")==false \
		and request.inspection.get("source_sha256")==current.get("source_sha256") \
		and request.inspection.get("generation")==current.get("generation")

func listen() -> TCPServer:
	var server := TCPServer.new()
	check(server.listen(0,"127.0.0.1")==OK,"real loopback server binds")
	art.endpoint.text="http://127.0.0.1:%d/v1" % server.get_local_port()
	return server

func receive(server: TCPServer, receipt: Dictionary) -> StreamPeerTCP:
	if not await until(server.is_connection_available,"explicit owner request reaches a real accepted socket",10000): return null
	sockets+=1
	var peer := server.take_connection()
	var text := ""
	var deadline := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		peer.poll()
		var available := peer.get_available_bytes()
		if available>0:
			var data := peer.get_data(available)
			if data[0]==OK: text+=(data[1] as PackedByteArray).get_string_from_utf8()
		if text.contains("\r\n\r\n"):
			var header := text.get_slice("\r\n\r\n",0)
			var length := 0
			for line: String in header.split("\r\n"):
				if line.to_lower().begins_with("content-length:"): length=line.substr(15).strip_edges().to_int()
			if text.to_utf8_buffer().size()>=header.to_utf8_buffer().size()+4+length:
				var packet: Variant = JSON.parse_string(text.substr(header.length()+4))
				if packet is Dictionary and packet.get("messages") is Array:
					var prompt: String = packet.messages[-1].content
					receipt.request=JSON.parse_string(prompt.substr(prompt.find("\n")+1))
					receipt.authorization_matches=header.contains("Authorization: Bearer "+FIXTURE_KEY)
					receipt.received=true
				return peer
		await process_frame
	return null

func serve(server: TCPServer, receipt: Dictionary) -> void:
	var peer: StreamPeerTCP = await receive(server,receipt)
	if peer!=null and receipt.get("request") is Dictionary:
		var request: Dictionary = receipt.request
		var built := Recipes.build(request.request_id+"-native-fixture","industrial_hangar",0,
			Compiler.rect(request.inspection.region),int(request.seed),request.materials)
		check(built.ok,"unchanged qualified Architecture recipe validates the deterministic proposal")
		var proposal := {"format":Planning.FORMAT,"request_id":request.request_id,
			"inspection_sha256":request.inspection.source_sha256,"generation":request.inspection.generation,
			"alternatives":[{"id":"transport-option","title":"Industrial hall with maintenance services",
				"summary":"Three finite stages; each needs fresh native preview and approval.","campaign":built.campaign}],
			"uncertainty":["Deterministic loopback fixture; no genuine model inference or actor traversal evidence."]}
		var body := JSON.stringify({"choices":[{"message":{"content":Compiler.canonical(proposal)},"finish_reason":"stop"}]})
		var reply := "HTTP/1.1 200 Fixture\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [body.to_utf8_buffer().size(),body]
		receipt.sent=peer.put_data(reply.to_utf8_buffer())==OK
		receipt.proposal=proposal
		for _i: int in range(6): await process_frame
		peer.disconnect_from_host()
	server.stop(); receipt.finished=true

func propose() -> Dictionary:
	return workflow.submit_intent({"text":"Build a believable industrial hall with a clear lower passage and roof-mounted maintenance services.",
		"family":"industrial_hangar","seed":37901},{"mode":"proposal_transport","max_alternatives":1,"materials":[58,28]})

func capture(region: Rect2i = REGION) -> Dictionary:
	var result: Dictionary = await wb.capture_batch_source(region)
	check(result.get("ok",false),"actual native material capture completes")
	return result

func write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(evidence.path_join(name),FileAccess.WRITE)
	if not check(file!=null,"write evidence "+name): return
	file.store_string(Compiler.canonical(value)); file.close()

func write_plane(label: String, result: Dictionary, size: Vector2i) -> void:
	var bytes: PackedByteArray = result.config.source_cells
	var file := FileAccess.open(evidence.path_join(label+".u16le"),FileAccess.WRITE)
	if not check(file!=null,"save complete native material plane "+label): return
	file.store_buffer(bytes); file.close()
	check(Controller.material_image(bytes,size).save_png(evidence.path_join(label+"-material-ids.png"))==OK,"save material-ID diagnostic "+label)

func simple(identity: String, region: Rect2i) -> Dictionary:
	var stage := Compiler.stage_defaults(identity,region)
	stage.materials=[0,58]
	stage.operations=[{"shape":"rectangle","x0":region.position.x+4,"y0":region.position.y+40,
		"x1":region.position.x+59,"y1":region.position.y+43,"material":58}]
	stage.budget.max_checked_cells=224
	return {"format":Compiler.FORMAT,"id":"native-handoff-negative-controls",
		"intent":"Owner-supplied native stale-source and Stop controls","stages":[stage]}

func clearances_empty(cells: PackedByteArray, clearances: Array) -> bool:
	for area: Array in clearances:
		var rect := Compiler.rect(area)
		for y: int in range(rect.position.y,rect.end.y):
			for x: int in range(rect.position.x,rect.end.x):
				if cells.decode_u16(((y-REGION.position.y)*REGION.size.x+x-REGION.position.x)*2)!=0: return false
	return true

func last_undo_receipt() -> Dictionary:
	var answer: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(art.provider.log_path).split("\n",false):
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and row.get("kind")=="native_history_action" and row.get("data") is Dictionary and row.data.get("action")=="undo":
			answer=row.data
	return answer

func run() -> void:
	evidence=OS.get_environment("ART_ARCHITECTURE_NATIVE_EVIDENCE")
	if evidence.is_empty(): evidence=ProjectSettings.globalize_path("user://native-handoff-evidence")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,900)
	change_scene_to_file("res://feature_launcher.tscn"); await scene_changed
	current_scene.launch("shared_workbench"); await scene_changed
	main=current_scene; wb=main.shared_workbench
	if not await until(installed,"ordinary unchanged Workbench initializes"): finish(); return
	for field: SpinBox in wb._extent: field.value=512
	if not check(wb.new_canvas(),"ordinary New blank admits bounded 512-square World"): finish(); return
	if not await until(func()->bool:return installed() and Setup.extent_of(wb.applied)==Vector2i(512,512),"actual native 512-square World is installed"): finish(); return
	check(wb.art_batches==null,"ordinary startup has no Art provider instance")
	wb.open_architecture_lab(); architecture=wb.architecture_lab; architecture.hide()
	session=architecture.session; workflow=architecture.workflow
	check(wb.art_batches==null,"opening Architecture creates no hidden Art provider")
	art=wb._ensure_art_batches(); art.hide()
	var provider_identity: int = art.provider.get_instance_id()
	art.current_provider="LM Studio"; art.model.text="native-handoff-loopback-fixture"
	art.tokens.value=8192; art.seconds.value=20; art.keys["LM Studio"]=FIXTURE_KEY
	art.provider.finished.connect(func(_id: int,_text: String,_response: Dictionary,_error: String)->void:ordinary_completions+=1)
	transport=OwnerTransport.new(); bridge=Bridge.new()
	check(transport.bind_owner(art.provider,configuration,current_context).ok,"Art-owned seam binds the existing ordinary panel provider")
	check(bridge.bind_owner_seam(workflow,transport.dispatch,transport.cancel,current_context,"fixture").ok,"unchanged qualified Architecture bridge binds the explicit host mount")
	check(art.provider.serial==0 and sockets==0 and art.provider.log_path.is_empty(),"opening both panels and binding sends no HTTP or audit event")
	var inspected: Dictionary = await session.inspect_region(REGION)
	check(inspected.get("ok",false) and not inspected.get("stale",true),"actual native inspection supplies source-bound proposal context")
	var before: Dictionary = await capture()
	write_plane("before",before,REGION.size)
	var original_plan := Compiler.canonical(session.plan)
	var server := listen()
	var exchange := {"finished":false,"received":false,"sent":false}
	serve.call_deferred(server,exchange)
	var answer: Dictionary = propose()
	check(answer.get("ok",false) and answer.get("status")=="awaiting-proposal","explicit owner proposal reaches the one real Art transport")
	if not await until(func()->bool:return exchange.finished and not art.provider.active,"proposal-only HTTP response completes"): finish(); return
	check(exchange.received and exchange.sent and exchange.authorization_matches,"real request uses the actual Art-owned configuration snapshot")
	check(workflow.planning.summary().state=="proposed" and ordinary_completions==0,"typed response has one Architecture consumer and no ordinary paint completion")
	var proposed: Dictionary = await capture()
	check(proposed.config.source_cells==before.config.source_cells and Compiler.canonical(session.plan)==original_plan and session.records.is_empty(),"proposal receipt has zero native writes and does not adopt a plan")
	check(workflow.select_alternative("transport-option").ok,"owner explicitly adopts the finite typed campaign")
	var adopted: Dictionary = await capture()
	check(adopted.config.source_cells==before.config.source_cells,"adopting a proposal still has zero native writes")
	check(session.plan.stages.size()==3,"selected finite campaign has three independently approved stages")
	for index: int in range(session.plan.stages.size()):
		if not check(workflow.select(index).ok,"owner selects stage "+str(index+1)): break
		check(not (await workflow.approve()).get("ok",true),"stage cannot execute without its own current preview")
		var pre: Dictionary = await capture()
		var preview: Dictionary = await workflow.preview_selected()
		if not check(preview.get("ok",false),"real StageSession preview succeeds / "+session.message): break
		var projected: PackedByteArray = session.preview.projected_cells.duplicate()
		var unchanged: Dictionary = await capture()
		check(unchanged.config.source_cells==pre.config.source_cells,"full native plane unchanged by this stage preview")
		answer=await workflow.approve()
		if not check(answer.get("ok",false) and answer.get("queued",false) and not answer.get("completed",true),"fresh owner approval queues without claiming native completion"): break
		if not await until(func()->bool:return not session.busy(),"real native stage retires with readback"): break
		if not check(session.stage_state()=="completed","native stage completes / "+session.message): break
		var record: Dictionary = session.records.back().duplicate(true)
		native_records.append(record)
		check(StageSession.receipt_accounting(record.native_receipts,record.budget).complete,"native receipt accounting matches exact approved stage work")
		check(not record.native_receipts.is_empty() and record.native_receipts[0].backend=="CyberNativeCellWorld" and record.result_sha256==record.expected_sha256,"real native owner and full readback bind actual construction")
		var after_stage: Dictionary = await capture()
		check(after_stage.config.source_cells==projected,"actual full material plane equals this separately approved projection")
		phases.append({"stage":record.stage_id,"checked":record.checked_cells,"changed":record.changed_cells,
			"result_sha256":record.result_sha256,"native_receipts":record.native_receipts.size()})
	check(native_records.size()==3,"all three finite native stages completed with separate approvals")
	var after: Dictionary = await capture()
	write_plane("after",after,REGION.size)
	check(after.config.source_cells!=before.config.source_cells,"actual native construction changed the material World")
	check(clearances_empty(after.config.source_cells,session.plan.stages[0].clearances),"approved lower-passage material clearances remain empty; no actor traversal claim")
	check(art.provider.get_instance_id()==provider_identity and art.provider.serial==1 and ordinary_completions==0,"native stages reuse the one provider owner and dispatch no extra model request")
	write_json("approved-proposal.json",exchange.proposal)
	write_json("native-stage-records.json",native_records)
	write_json("workflow-history.json",workflow.export_history())
	check(session.save_session(evidence.path_join("construction-session.json")).ok,"exact native construction session saved")
	wb._name.text="art-architecture-native-handoff"
	if check(wb.save_setup(),"ordinary editable authored start saved"):
		var data := FileAccess.get_file_as_bytes(Setup._path(wb._name.text))
		var file := FileAccess.open(evidence.path_join("editable-workbench-start.json"),FileAccess.WRITE)
		if check(file!=null and not data.is_empty(),"editable start bytes captured"): file.store_buffer(data); file.close()
	# Actual manual edit invalidates a fresh native preview before its approval.
	var control := simple("stale-source",Rect2i(320,16,64,64))
	check(workflow.load_plan(control).ok and (await workflow.preview_selected()).get("ok",false),"negative-control plan receives real native preview")
	# Keep the ordinary Setup document valid: UI radius zero preserves its
	# stored brush>=2. A previous probe directly assigned brush=0 and correctly
	# caused later Setup validation/Undo to refuse; that failed fixture is retained.
	check(wb.paint_editor.commit_cells(PackedInt32Array([324,56,58]),"Owner fixture manual edit"),"ordinary PAINT owner admits a manual cell edit while Art remains open")
	await until(func()->bool:return not wb.paint_editor.busy() and not main.simulation_worker.paint_state().get("legacy_busy",false) and main.image.get_pixel(324,56).r8==58,"manual edit is acknowledged by native authority")
	var records_before: int = session.records.size()
	check(not (await workflow.approve()).get("ok",true) and session.records.size()==records_before and not session.busy(),"stale preview approval refuses without native stage work")
	# Real native prefix and ordinary Undo; no atomic multi-stage claim.
	var partial := simple("stopped-prefix",Rect2i(16,320,480,160))
	partial.stages[0].operations=[{"shape":"rectangle","x0":16,"y0":320,"x1":495,"y1":479,"material":58}]
	partial.stages[0].budget.max_checked_cells=262144
	var prefix_before: Dictionary = await capture(Rect2i(16,320,480,160))
	check(Setup.validate(wb.applied).is_empty(),"manual fixture preserves the ordinary valid Setup invariant")
	if check(workflow.load_plan(partial).ok and (await workflow.preview_selected()).get("ok",false) and (await workflow.approve()).get("ok",false),"large real native stage is separately previewed and approved"):
		await until(func()->bool:return not session._receipts.is_empty() or not session.busy(),"actual native prefix acknowledgement arrives")
		workflow.cancel()
		await until(func()->bool:return not session.busy(),"Architecture Stop drains actual prefix and final native readback")
		var stopped: Dictionary = session.records.back()
		check(stopped.status=="partial" and stopped.checked_cells>0 and stopped.checked_cells<480*160 and stopped.final_readback_available,"Stop retains actual acknowledged prefix without inventing its unexecuted suffix")
		write_json("stopped-native-prefix.json",stopped)
		check(wb.paint_editor.undo(),"ordinary native Undo admits recovery of the stopped prefix")
		await until(func()->bool:return not wb.paint_editor.busy(),"ordinary prefix Undo retires")
		var restored: Dictionary = await capture(Rect2i(16,320,480,160))
		var undo_receipt := last_undo_receipt()
		check(undo_receipt.get("status")=="completed" and int(undo_receipt.get("applied",-1))==int(stopped.changed_cells),"actual ordinary Undo receipt confirms every acknowledged prefix cell was applied")
		check(restored.config.source_cells==prefix_before.config.source_cells,"whole native material plane is exactly restored after stopped-prefix Undo")
		undo_evidence={"before_sha256":Compiler.digest(prefix_before.config.source_cells),
			"after_sha256":Compiler.digest(restored.config.source_cells),"native_receipt":undo_receipt,
			"restored_cells":stopped.changed_cells,"full_plane_bytes":restored.config.source_cells.size()}
		write_json("native-undo-restoration.json",undo_evidence)
	# Preparation cancellation goes through the actual existing Art owner.
	check((await session.inspect_region(REGION)).get("ok",false),"fresh native context is captured for cancellation probes")
	extra_context=[{"role":"user","content":"Explicitly admitted synthetic preparation context. ".repeat(7000)}]
	server=listen(); answer=propose()
	check(answer.get("ok",false) and art.provider.request_preparation_active(),"actual Architecture dispatch enters asynchronous Art preparation")
	check(not transport.cancel(int(art.provider.serial)+1,str(answer.get("request_id","")),"Wrong request"),"unrelated scoped cancellation cannot retire the actual owner request")
	workflow.cancel()
	await until(func()->bool:return not art.provider.active and not art.provider.request_preparation_active(),"Architecture Stop retires actual asynchronous provider preparation")
	check(not server.is_connection_available() and not transport.summary().active and not bridge.summary().active,"preparation Stop sends zero HTTP and leaves no hidden consumer")
	server.stop(); extra_context=[]
	check((await session.inspect_region(REGION)).get("ok",false),"fresh native inspection precedes a real no-headers request")
	server=listen(); answer=propose()
	var stalled := {"received":false}
	var peer: StreamPeerTCP = await receive(server,stalled)
	check(peer!=null and stalled.received,"actual Art request is accepted without response headers")
	var stop_began := Time.get_ticks_usec()
	art.stop_all("Owner Stop from ordinary Art")
	var owner_stop_ms := float(Time.get_ticks_usec()-stop_began)/1000.0
	check(not art.provider.active and not transport.summary().active and not bridge.summary().active and owner_stop_ms<2000.0,"ordinary Art Stop retires the exclusive Architecture request within two seconds")
	if peer!=null: peer.disconnect_from_host()
	server.stop()
	# Actual World replacement invalidates asynchronous eventual admission.
	check((await session.inspect_region(REGION)).get("ok",false),"native context re-inspected before World replacement")
	extra_context=[{"role":"user","content":"Explicitly admitted replacement preparation context. ".repeat(7000)}]
	server=listen(); answer=propose()
	check(answer.get("ok",false) and art.provider.request_preparation_active(),"World replacement begins with an actual preparation job")
	check(wb.new_canvas(),"owner replaces the actual Workbench World")
	await until(func()->bool:return installed() and not art.provider.active and not art.provider.request_preparation_active(),"new native World installs and old provider job retires")
	check(not server.is_connection_available() and not bridge.summary().active and not transport.summary().active,"eventual dispatch guard refuses replaced native context before any HTTP")
	server.stop(); extra_context=[]
	check(ordinary_completions==0 and sockets==2 and art.provider.get_instance_id()==provider_identity,"all combined paths keep one provider and one response owner per request")
	check(not FileAccess.get_file_as_string(art.provider.log_path).contains(FIXTURE_KEY),"complete shared Art audit excludes its credential")
	write_json("bridge-history.json",bridge.export_history())
	write_json("probe-observations.json",{"phases":phases,"owner_stop_ms":owner_stop_ms,
		"native_undo_restoration":undo_evidence,
		"actual_http_exchanges":sockets,"ordinary_completions":ordinary_completions,
		"provider_audit_sha256":FileAccess.get_sha256(art.provider.log_path),
		"provider_audit_path":ProjectSettings.globalize_path(art.provider.log_path)})
	finish()

func finish() -> void:
	var result := {"format":"cybersand-art-architecture-native-handoff-v1","checks":checks,"failures":failures,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"architecture_application_source":"17c6b5b35049b7b2541c2deeea23c02fd1e2fc5d",
		"art_overlay_source":"2743f89a0df6f6afcf7484e859c10790d521e74b","native_stages_completed":native_records.size(),
		"actual_http_exchanges":sockets,"ordinary_completions":ordinary_completions,"model_calls":0,
		"display":DisplayServer.get_name(),"godot":Engine.get_version_info().string,"platform":OS.get_name(),
		"scope":"Separate combined native Workbench fixture experiment; not principal Art or Architecture evaluator qualification.",
		"provider_sha256":FileAccess.get_sha256("res://scripts/art_provider.gd"),
		"adapter_sha256":FileAccess.get_sha256("res://scripts/art_proposal_transport.gd"),
		"architecture_bridge_sha256":FileAccess.get_sha256("res://scripts/batch_lab/architecture_proposal_bridge.gd"),
		"stage_session_sha256":FileAccess.get_sha256("res://scripts/batch_lab/architecture_stage_session.gd")}
	write_json("result.json",result)
	print("ART_ARCHITECTURE_NATIVE_RESULT ",JSON.stringify(result))
	if bridge!=null: bridge.detach_owner_seam()
	if transport!=null: transport.detach_owner()
	if is_instance_valid(main): main.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
