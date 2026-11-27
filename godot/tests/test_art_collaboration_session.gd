extends SceneTree
## Complete ordinary Workbench collaboration, real loopback HTTP, native writes.
## Responses are deterministic fixtures. No inference or synthetic World writes.
const Context = preload("res://scripts/art_world_context.gd")
const Proposal = preload("res://scripts/art_authoring_proposal.gd")
var main: Control
var wb: Control
var panel: Window
var session: RefCounted
var checks := 0
var failures: Array[String] = []
var ordinary_completions := 0
var http_requests := 0
var outcomes: Array = []
var options := {"native":true,"knowledge":true,"recent":true,"image":false,"image_scope":"selected"}
var stop_after_receipt := false
var stop_before_readback := false

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("ART_COLLAB_SESSION_CHECK ",label," ",ok)
	if not ok: failures.append(label); push_error(label)
	return ok

func until(predicate: Callable, label: String, milliseconds: int = 90000) -> bool:
	var deadline := Time.get_ticks_msec()+milliseconds
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return check(bool(predicate.call()),label)

func source() -> Dictionary: return wb.paint_editor.art_context_state().source

func settled() -> bool:
	var state: Dictionary = main.simulation_worker.paint_state()
	var agent: Dictionary = main.simulation_worker.art_state()
	return not wb.busy() and not panel.executor.active and not session.busy() \
		and not wb.paint_editor.busy() and not panel.log_draw and not bool(state.busy) \
		and not bool(state.get("receipt_ready",false)) and not bool(state.get("legacy_busy",false)) \
		and not agent.queued and not agent.executing and not agent.receipt_ready

func observe(region: Rect2i) -> Dictionary:
	var box := [{}]
	var admitted: Dictionary = wb.paint_editor.art_context_capture(region,func(value: Dictionary) -> void: box[0]=value)
	if not check(admitted.get("ok",false),"actual native readback admitted"): return {}
	await until(func() -> bool: return not box[0].is_empty(),"actual native readback finishes")
	return box[0]

func inspect() -> bool:
	var workspace: Control=panel.collaboration_workspace
	workspace.native_context.button_pressed=bool(options.native)
	workspace.knowledge_context.button_pressed=bool(options.knowledge)
	workspace.recent_context.button_pressed=bool(options.recent)
	workspace.image_context.button_pressed=bool(options.image)
	workspace.image_scope.select(1 if options.image_scope=="viewport" else 0)
	session.inspect_context(options)
	if not await until(func() -> bool: return not session.busy(),"context observation finishes"): return false
	return check(not session.context.is_empty() and session.context.has("disclosure_digest") \
		and session.context.source==source(),"inspector holds exact fresh native source")

func packet(operations: Array, title: String = "Collaborative room") -> Dictionary:
	return {"schema":Proposal.SCHEMA,"title":title,"summary":"A finite owner-reviewed material composition.",
		"stages":[{"id":"structure","title":"Structural frame","depends_on":[],"operations":operations}]}

func block(x: int,y: int,width: int,height: int,material: int = 58) -> Dictionary:
	return {"shape":"rectangle","x0":x,"y0":y,"x1":x+width-1,"y1":y+height-1,"material":material}

func listener() -> TCPServer:
	var server := TCPServer.new()
	check(server.listen(0,"127.0.0.1")==OK,"real loopback fixture binds")
	panel.endpoint.text="http://127.0.0.1:%d/v1" % server.get_local_port()
	panel.model.text="collaborative-test-fixture"
	return server

func serve(server: TCPServer, text: String, result: Dictionary) -> void:
	if not await until(server.is_connection_available,"actual fixture HTTP connection",15000): server.stop(); result.finished=true; return
	var peer := server.take_connection()
	var bytes := PackedByteArray()
	var deadline := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline:
		peer.poll()
		var count := peer.get_available_bytes()
		if count>0:
			var incoming := peer.get_data(count)
			if incoming[0]==OK: bytes.append_array(incoming[1])
		var wire := bytes.get_string_from_utf8()
		var split := wire.find("\r\n\r\n")
		if split>=0:
			var length := 0
			for line: String in wire.left(split).split("\r\n"):
				if line.to_lower().begins_with("content-length:"): length=line.substr(15).strip_edges().to_int()
			if bytes.size()>=wire.left(split).to_utf8_buffer().size()+4+length:
				http_requests += 1
				result.request=JSON.parse_string(wire.substr(split+4))
				var body := JSON.stringify({"choices":[{"message":{"content":text},"finish_reason":"stop"}],"usage":{"prompt_tokens":80,"completion_tokens":50}})
				var headers := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.to_utf8_buffer().size()
				check(peer.put_data((headers+body).to_utf8_buffer())==OK,"actual deterministic HTTP response delivered")
				for _frame: int in 6: await process_frame
				peer.disconnect_from_host()
				server.stop()
				result.finished=true
				return
		await process_frame
	server.stop()
	result.finished=true
	check(false,"fixture receives complete actual request body")

func exchange(mode: String, reply: String, prompt: String) -> Dictionary:
	var server := listener()
	if not await inspect(): server.stop(); return {}
	var result := {"finished":false}
	serve.call_deferred(server,reply,result)
	var before := source()
	var workspace: Control=panel.collaboration_workspace
	var mode_index: int=workspace.MODES.find(mode)
	workspace.mode.select(mode_index)
	workspace.mode.item_selected.emit(mode_index)
	workspace.prompt.text=prompt
	check(not workspace.send_button.disabled,"explicit "+mode+" request is available in the ordinary Art workspace")
	workspace.send_button.pressed.emit()
	await until(func() -> bool: return result.finished and not session.busy() and not panel.provider.active,mode+" one complete transport/preview lifecycle",20000)
	check(ordinary_completions==0,mode+" never enters legacy completion-to-paint")
	check(source()==before,mode+" reply and preview have zero native writes")
	return result

func wait_preview() -> bool:
	if not await until(func() -> bool: return not session.preview.active,"finite collaboration preview finishes"): return false
	return check(bool(session.preview_result.get("ok",false)),"exact native preview is ready")

func approve() -> bool:
	var before: int = session.receipts.size()
	panel.collaboration_workspace.tabs.current_tab=2
	check(not panel.collaboration_workspace.approve_button.disabled,"the applicable next-stage approval is available in the ordinary Art workspace")
	panel.collaboration_workspace.approve_button.pressed.emit()
	if not check(session.running_batch>=0,"explicit owner approval queues exactly one finite stage"): return false
	if not await until(settled,"approved stage and native readback retire"): return false
	return check(session.receipts.size()==before+1 and session.receipts.back().get("verified",false),"actual receipt and complete native plane match prediction")

func native_receipt(_receipt: Dictionary) -> void:
	if stop_after_receipt:
		stop_after_receipt=false
		panel.stop_all("Owner Stop after acknowledged native prefix")

func save_workbench_frame(name: String, tab: int) -> void:
	var directory := OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless": return
	panel.show_collaboration(true)
	panel.collaboration_workspace.tabs.current_tab=tab
	panel.show()
	for frame: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory+"/"+name)==OK,"actual ordinary Workbench collaboration framebuffer "+name)

func run() -> void:
	root.size=Vector2i(1280,800)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main=current_scene
	wb=main.shared_workbench
	if not await until(func() -> bool: return not wb.applied.is_empty() and not wb.busy() and main.pending_microscenario_apply.is_empty(),"ordinary Workbench ready"): finish(); return
	panel=wb._ensure_art_batches()
	session=panel.collaboration
	panel.provider.finished.connect(func(_id: int,_text: String,_response: Dictionary,_error: String) -> void: ordinary_completions+=1)
	panel.executor.native_receipt.connect(native_receipt)
	panel.provider.traffic_changed.connect(func() -> void:
		if stop_before_readback and not session.pending_stage_receipt.is_empty() and session.running_batch<0:
			stop_before_readback=false
			panel.stop_all("Owner Stop before native verification capture"))
	wb.open_art_batches()
	panel.show_collaboration(true)
	panel.focus_selection(Rect2i(0,0,256,192))
	var brief: Dictionary=session.brief.duplicate(true)
	brief.palette=[58,28]
	brief.pinned_constraints=["Keep the lower passage open."]
	brief.preserve=[[0,170,256,22]]
	check(session.apply_brief(brief),"explicit owner brief applies")
	check(panel.provider.serial==0 and http_requests==0,"opening collaborative Art makes no model or HTTP request")
	var original:=source()
	if not await inspect(): finish(); return
	check(source()==original and session.context.inspector.captured_cells==49152,"native inspection is bounded and read-only")
	await save_workbench_frame("00-art-ordinary-context.png",3)
	var direct_serial: int=panel.provider.serial
	panel.remaining_turns=1
	panel.waiting_until_ms=Time.get_ticks_msec()+60000
	session.request("discuss","This must wait for the retained direct run.",session.brief,options)
	check(panel.provider.serial==direct_serial and not session.busy(),"paced direct interval owns transport admission even while its provider is idle")
	session.inspect_context(options)
	session.load_example("industrial_repair")
	check(session.capture_id<0 and session.compiled.is_empty() and source()==original,"pending direct run also excludes collaborative capture and offline admission")
	panel.stop_all("Owner explicitly stopped the paced direct fixture")
	check(panel.remaining_turns==0 and not session._direct_pending(),"ordinary Stop releases the direct-run admission fence")
	var bad_brief:=brief.duplicate(true)
	bad_brief.palette=[255]
	check(not session.apply_brief(bad_brief) and session.brief==brief,"unavailable palette refuses without replacing owner brief")

	var discussion: Dictionary=await exchange("discuss","Preserve the lower passage and strengthen the frame. No construction has occurred.","What could make this room more legible?")
	check(not discussion.is_empty() and session.compiled.is_empty(),"discussion remains ordinary prose and has no executable proposal")
	check(panel.conversation.size()>=2,"admitted discussion retains complete user and assistant messages")
	var already_disclosed_reply:=false
	for turn: Dictionary in session._wire_context:
		if turn.get("role","")=="assistant" and str(turn.get("content","")).contains("Preserve the lower passage and strengthen the frame."): already_disclosed_reply=true
	check(already_disclosed_reply,"completed discussion refreshes disclosed memory before any new capture or request")
	check(int(session.context.conversation_revision)==int(panel.conversation_revision),"completed discussion disclosure owns the current Conversation revision")
	var followup: Dictionary=await exchange("discuss","Yes, a taller frame can keep that lower passage unchanged.","Can it be taller while retaining that passage?")
	var includes_first_reply:=false
	for turn: Dictionary in followup.get("request",{}).get("messages",[]):
		if turn.get("role","")=="assistant" and str(turn.get("content","")).contains("Preserve the lower passage and strengthen the frame."): includes_first_reply=true
	check(includes_first_reply,"second discussion sends the first acknowledged exchange in bounded session memory")
	var raw:=packet([block(8,8,12,4)])
	raw.stages.append({"id":"detail","title":"Distinct upper accent","depends_on":["structure"],"operations":[block(32,8,8,3,28)]})
	await exchange("propose",JSON.stringify(raw),"Propose two bounded stages, preserving my passage.")
	if not check(not session.compiled.is_empty() and session.preview_result.get("ok",false),"provider proposal produces one zero-write preview"): finish(); return
	check(session.compiled.stages.size()==2 and session.stage_index==0,"stage count is host compiled; no automatic execution")
	await save_workbench_frame("01-art-ordinary-proposal.png",2)
	panel.remaining_turns=1
	panel.waiting_until_ms=Time.get_ticks_msec()+60000
	session.approve_next()
	check(session.running_batch<0,"collaborative approval refuses during a retained direct timer")
	panel.remaining_turns=0
	panel.waiting_until_ms=0
	check(session.context.disclosure.proposal_for_develop==session.compiled.proposal,"context inspector discloses the normalized proposal supplied to Develop")
	if not await approve(): finish(); return
	check(session.stage_index==1 and session.stage_status.structure=="verified" and not panel.executor.active,"first approval stops at stage boundary")
	var first:=await observe(Rect2i(32,8,8,3))
	check(first.materials.count(0)==24,"unapproved second stage remains unbuilt")
	if not await approve(): finish(); return
	check(session.stage_index==2 and session.stage_status.detail=="verified","second independent approval completes native composition")
	check(session.receipts[0].changed==48 and session.receipts[1].changed==24,"execution reports actual completed geometry")
	outcomes.append({"kind":"two-stage construction","receipts":session.receipts.duplicate(true)})
	await save_workbench_frame("02-art-ordinary-completed.png",0)
	await exchange("review","The verified frame and upper accent are present; the lower passage remains unchanged.","Review the completed room.")
	check(session.context.disclosure.acknowledged_results_for_review.size()==2,"review context contains actual acknowledged native receipts")
	if DisplayServer.get_name()!="headless":
		wb._set_view(Vector2.ZERO,Vector2i(256,192))
		for frame: int in 4: await process_frame
		options.image=true
		var visual: Dictionary=await exchange("discuss","The rendered frame agrees with the admitted material context.","Discuss this explicitly selected canvas image.")
		check(not session._png.is_empty() and session._image_mapping.get("world_xywh",[])==[0.0,0.0,256.0,192.0],"displayed image admits only the selected native canvas mapping")
		check(session._image_mapping.pixels[0]<=768 and session._image_mapping.pixels[1]<=768,"rendered image obeys its bounded pixel envelope")
		check(JSON.stringify(visual.get("request",{})).contains("data:image/png;base64,"),"explicitly admitted canvas image reaches the actual loopback transport")
		var image_turn: Dictionary=panel.conversation[panel.conversation.size()-2]
		check(int(image_turn.get("image_offset",-1))>=0,"admitted image retains its original session audit reference")
		options.image=false
		await inspect()
		check(session._png.is_empty() and panel.collaboration_workspace.visual_context.texture==null,"new image-free disclosure clears both transport bytes and prior thumbnail")
	var revised:=packet([block(8,8,12,7)],"Taller frame, existing accent preserved")
	await exchange("develop",JSON.stringify(revised),"Make the frame taller, keep the lower passage and accent.")
	check(session.lineage.size()==1 and not session.compiled.diff.parent_digest.is_empty(),"Develop retains revision lineage")
	check(session.brief==brief and session.policy.protected.has(Rect2i(0,170,256,22)),"Develop cannot discard explicit owner constraints")
	if not await approve(): finish(); return
	check(session.receipts.back().changed==36,"revision adds only actual new cells")
	check(wb.paint_editor.history_available("undo"),"native Undo is available after verified stage")
	check(wb.paint_editor.undo(),"Undo uses existing PAINT history authority")
	await until(settled,"native Undo completes")
	var undone:=await observe(Rect2i(8,12,12,3))
	check(undone.materials.count(0)==36 and session.stale,"Undo restores cells and invalidates pending proposal")
	check(wb.paint_editor.redo(),"Redo uses existing native history authority")
	await until(settled,"native Redo completes")
	var redone:=await observe(Rect2i(8,12,12,3))
	check(redone.materials.count(58)==36,"Redo restores the verified authored result")

	await inspect()
	var conflict:=packet([block(10,175,8,3)],"Forbidden lower passage detail")
	check(session.admit_proposal(conflict,"deliberate owner-style contradiction").ok,"conflicting proposal remains inspectable")
	await until(func() -> bool: return not session.preview.active,"conflicting preview completes")
	check(not session.preview_result.ok and session.preview_result.conflict_count==24,"protected native cells refuse exact preview")
	var conflict_source:=source()
	session.approve_next()
	check(session.running_batch<0 and source()==conflict_source,"conflicted preview cannot acquire native execution")
	check(session.admit_proposal(packet([block(70,20,8,3)]),"manual collaboration candidate").ok,"fresh unexecuted revision admitted")
	await wait_preview()
	var old_source:=source()
	check(main.simulation_worker.queue_emit_disc(180,120,0,58),"ordinary manual native drawing remains possible with Art open")
	await until(func() -> bool: return source()!=old_source and session.stale,"relevant manual source edit marks proposal stale")
	var manual_source:=source()
	session.approve_next()
	check(session.running_batch<0 and source()==manual_source,"obsolete plan refuses after manual edit")

	await inspect()
	check(session.admit_proposal(packet([block(20,30,200,100)]),"finite Stop continuation").ok,"large finite construction admits")
	if not await wait_preview(): finish(); return
	stop_after_receipt=true
	session.approve_next()
	await until(settled,"Stop retains and retires acknowledged native prefix")
	check(session.receipts.back().changed>0 and session.receipts.back().changed<20000 and not session.receipts.back().get("verified",true),"Stop reports partial actual work without claiming whole stage")
	await save_workbench_frame("03-art-ordinary-stopped-prefix.png",2)
	outcomes.append({"kind":"stopped prefix","receipt":session.receipts.back().duplicate(true)})
	await inspect()
	check(session.admit_proposal(packet([block(20,30,200,100)]),"owner-approved continuation from new context").ok,"continuation recompiles against fresh complete native plane")
	if await wait_preview():
		check(session.preview_result.predicted_changed<20000,"continuation accounts for the acknowledged prefix")
		await approve()
	var completed:=await observe(Rect2i(20,30,200,100))
	check(completed.materials.count(58)==20000,"freshly approved continuation completes actual native region")
	await inspect()
	check(session.admit_proposal(packet([block(230,135,5,5)]),"completed result awaiting readback").ok,"finite readback-cancellation case admits")
	await wait_preview()
	var receipts_before_cancel: int=session.receipts.size()
	stop_before_readback=true
	session.approve_next()
	await until(settled,"Stop before verification retires native result")
	check(session.receipts.size()==receipts_before_cancel+1 and session.pending_stage_receipt.is_empty(),"completed-but-unverified receipt is retained exactly once")
	check(session.receipts.back().status=="completed" and session.receipts.back().changed==25 \
		and not session.receipts.back().verified and session.receipts.back().verification_error.contains("Stop"),"unverified readback preserves actual completed work and its cancellation reason")
	await inspect()
	check(session.admit_proposal(packet([block(230,150,2,1)],"Superseded approval candidate")).ok,"reentrant approval fixture admits")
	await wait_preview()
	var replacement:=packet([block(235,150,2,1)],"Owner replacement during audit")
	var approval_count:=FileAccess.get_file_as_string(panel.provider.log_path).count('"kind":"collaboration_stage_approval"')
	var armed:={"value":true,"admitted":false}
	var replace_during_audit:=func() -> void:
		if armed.value and FileAccess.get_file_as_string(panel.provider.log_path).count('"kind":"collaboration_stage_approval"')>approval_count:
			armed.value=false
			armed.admitted=session.admit_proposal(replacement,"explicit reentrant owner revision").get("ok",false)
	panel.provider.traffic_changed.connect(replace_during_audit)
	var source_before_reentry:=source()
	session.approve_next()
	panel.provider.traffic_changed.disconnect(replace_during_audit)
	check(armed.admitted and session.running_batch<0 and source()==source_before_reentry,"proposal replacement during approval audit invalidates the old approval before native admission")
	await wait_preview()
	check(session.compiled.proposal.title==replacement.title,"replacement proposal retains its own identity after reentry")
	await approve()
	var superseded:=await observe(Rect2i(230,150,2,1))
	check(superseded.materials.count(0)==2,"superseded geometry never entered the native World")

	var current_digest: String=session.compiled.proposal_digest
	await exchange("propose","{ this is malformed","Please return a proposal.")
	check(session.compiled.proposal_digest==current_digest and session.status.contains("JSON"),"malformed response preserves existing proposal and original reply")
	var external_before: int=panel.provider.serial
	panel.endpoint.text="https://example.invalid/v1"
	await inspect()
	session.request("discuss","Discuss without my external authorization.",session.brief,options)
	check(panel.provider.serial==external_before and not panel.provider.active,"external context is never sent without exact owner authorization")
	var disabled:=options.duplicate(true)
	disabled.knowledge=false
	disabled.native=false
	session.inspect_context(disabled)
	await until(func() -> bool: return not session.busy(),"owner context exclusions rebuild disclosure")
	check(not session.context.wire_model.has("material_distribution") and not session.context.wire_model.has("knowledge"),"disabled native details and knowledge are absent from admitted model context")
	var guarded_policy: String=session.context.policy_digest
	check(session._live_request_guard(session.generation,source(),guarded_policy),"eventual request guard admits current native source and policy")
	panel.focus_selection(Rect2i(0,0,128,128))
	check(not session._live_request_guard(session.generation,source(),guarded_policy),"eventual request guard refuses changed focus even without World mutation")
	panel.focus_selection(Rect2i(0,0,256,192))
	var long_history: Array=panel.conversation.duplicate(true)
	for index: int in 8: panel.remember_turn("user","bounded memory ".repeat(1000))
	var memory: Array=session._recent_messages()
	var total:=0
	for turn: Dictionary in memory:
		total+=str(turn.content).length()
		check(str(turn.content).length()<=4096,"each summarized turn respects its complete bound including omission marker")
	check(total<=16384 and memory.size()<=8,"reviewable conversation memory has a finite total budget")
	check(panel.conversation.size()==long_history.size()+8,"bounded request memory never truncates admitted originals")
	check(ordinary_completions==0 and http_requests==(6 if DisplayServer.get_name()=="headless" else 7),"all deterministic actual HTTP exchanges have one exclusive consumer each")
	check(FileAccess.get_file_as_string(panel.provider.log_path).contains("collaboration_stage_approval"),"redacted audit retains explicit stage approval records")
	var saved_conversation_size: int=panel.conversation.size()
	var generation_before: int=source().generation
	check(wb.apply(wb.Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))),"World replacement admitted through ordinary Workbench")
	await until(func() -> bool: return source().generation>generation_before and main.pending_microscenario_apply.is_empty() and not wb.busy(),"replacement native World acknowledged")
	check(session.stale and panel.conversation.size()==saved_conversation_size,"World replacement invalidates proposals while preserving current-session conversation")
	session.approve_next()
	check(session.running_batch<0,"retired World proposal cannot execute in replacement World")
	finish()

func finish() -> void:
	print("ART_COLLABORATION_SESSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"evidence_kind":"ordinary Workbench, deterministic real loopback HTTP and actual native material operations",
		"model_calls":0,"http_requests":http_requests,"ordinary_completions":ordinary_completions,"outcomes":outcomes}))
	if main!=null: main.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
