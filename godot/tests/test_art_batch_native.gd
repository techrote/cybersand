extends SceneTree
var main: Control
var wb
var art
var failures := 0
var checks := 0
func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_CHECK ",label," ",ok)
	if not ok: failures += 1; push_error(label)
func until(test: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while not test.call() and Time.get_ticks_msec()<deadline: await process_frame
	var ok: bool = test.call()
	check(ok,label+(" / "+main.microscenario_error if main!=null and not ok else ""))
	return ok
func installed() -> bool:
	return not wb.applied.is_empty() and not wb.busy() and main.pending_microscenario_apply.is_empty()
func cell(x: int,y: int) -> int: return main.image.get_pixel(x,y).r8
func submit(ops: Array, guards: Array = []) -> bool:
	var r: Dictionary = art.submit(ops,Rect2i(0,0,2048,2048),guards)
	check(r.status=="queued","batch admitted as queued")
	return r.status=="queued"
func finish() -> void:
	await until(func(): return not art.active,"native batch completes")
	check(art.result.status=="completed","completion is authoritative")
	check(art.last_receipt.get("backend")=="CyberNativeCellWorld","compiled native World receipt")
func run() -> void:
	root.size = Vector2i(1920,1080)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	wb = main.shared_workbench
	if not await until(installed,"blank native workbench ready"): quit(1); return
	art = wb.art_batches.executor
	var panel = wb.art_batches
	panel.provider.log_event("fixture","hidden traffic should stay off the UI")
	check(panel.traffic_dirty and panel.traffic_text.text.is_empty(),"hidden traffic does not rebuild text")
	panel.traffic_window.show()
	panel.refresh_traffic()
	check(panel.traffic_text.text.contains("hidden traffic should stay off the UI"),"opened traffic shows retained content")
	panel.traffic_window.hide()
	panel.provider.requested_model = "fixture"
	panel.provider.usage = {"prompt_tokens":275,"completion_tokens":170}
	panel.input_error = "Previous provider error"
	await process_frame
	await process_frame
	panel.input_mode.select(0)
	panel.input_mode.item_selected.emit(0)
	for i: int in range(5): await process_frame
	check(panel.state.text == "Idle" and panel.draw.text == "Draw","Direct JSON clears provider status without growing")
	panel.input.text = '[{"shape":"pixels","points":[[5,5]],"material":58}]'
	panel.draw.pressed.emit()
	await until(func(): return not art.active and main.image.get_pixel(5,5).r8 == 58,"Direct JSON Draw applies a native pixel")
	panel.paint_material.select(panel.paint_material.get_item_index(28))
	panel.input.text = '[{"shape":"pixels","points":[[6,5]]}]'
	panel.draw.pressed.emit()
	await until(func(): return not art.active and main.image.get_pixel(6,5).r8==28,"material picker draws Metal through native readback")
	panel.input.text = '[{"shape":"pixels","points":[[6,5]],"material":0}]'
	panel.draw.pressed.emit()
	await until(func(): return not art.active,"erase attempt completed")
	check(art.result.excluded==1 and main.image.get_pixel(6,5).r8==28,"material picker preserves source protection")
	panel.paint_material.select(panel.paint_material.get_item_index(58))
	panel.tool_checks.line.button_pressed = false
	panel.input.text = '[{"shape":"line","x0":1440,"y0":1440,"x1":1448,"y1":1440,"width":4}]'
	panel.draw.pressed.emit()
	check(not art.active and panel.input_error.contains("disabled"),"Tools toggle refuses a disabled line")
	panel.tool_checks.line.button_pressed = true
	panel.draw.pressed.emit()
	await until(func(): return not art.active and cell(1444,1439)==58 and cell(1444,1442)==58,"width four draws four native rows")
	check(cell(1444,1438)==0 and cell(1444,1443)==0 and cell(1439,1442)==58 and cell(1438,1442)==0,"wide line has rounded ends")
	panel.pixel_limit.value = 1
	panel.input.text = '[{"shape":"pixels","points":[[1455,1455],[1456,1455]]}]'
	panel.draw.pressed.emit()
	check(not art.active and panel.input_error.contains("limit"),"pixel limit refuses excess points")
	panel.pixel_limit.value = 0
	panel.draw.pressed.emit()
	await until(func(): return not art.active and cell(1455,1455)==58 and cell(1456,1455)==58,"zero pixel limit allows the batch")
	panel.request_area = Rect2i(1500,1500,64,64)
	panel.request_materials = [0,58]
	var stroke: Array = panel.local_operations([{"shape":"polyline","width":3,"points":[[3,3],[13,3],[13,13]],"material":58}])
	art.submit(stroke,panel.request_area,[],panel.request_materials)
	await until(func(): return not art.active and cell(1508,1504)==58 and cell(1514,1510)==58,"local rounded polyline draws both legs")
	panel.input.text = '[{"shape":"polygon","points":[[1540,1500],[1550,1500],[1550,1504],[1544,1504],[1544,1510],[1540,1510]]},{"shape":"airbrush","x":1570,"y":1507,"radius":7,"hardness":0.35,"seed":123},{"shape":"airbrush","x":1590,"y":1507,"radius":7,"hardness":0.35,"seed":123}]'
	panel.draw.pressed.emit()
	await until(func(): return not art.active and cell(1542,1507)==58 and cell(1590,1507)==58,"filled polygon and airbrush reach native readback")
	check(cell(1548,1507)==0,"concave polygon preserves its cutout")
	var same_pattern := true
	var stipples := 0
	for dy: int in range(-7,8):
		for dx: int in range(-7,8):
			if cell(1570+dx,1507+dy)!=cell(1590+dx,1507+dy): same_pattern = false
			if cell(1570+dx,1507+dy)==58: stipples += 1
	check(same_pattern and stipples>1 and stipples<149,"seeded airbrush repeats a partial disc at another position")
	var sparse := preload("res://scripts/art_batch_plan.gd").new()
	check(sparse.configure([{"shape":"polygon","points":[[0,0],[2047,2046],[2047,2047]],"material":58}],Rect2i(0,0,2048,2048)),"sparse diagonal polygon admitted")
	var slice_start := Time.get_ticks_usec()
	var first_slice: Dictionary = sparse.next_chunk()
	var slice_us := Time.get_ticks_usec()-slice_start
	print("ART_RASTER_SLICE_US ",slice_us)
	check(first_slice.is_empty() and not sparse.exhausted() and slice_us<100000,"sparse polygon yields before filling a native chunk")
	submit([{"shape":"polygon","points":[[0,0],[2047,2046],[2047,2047]],"material":58}])
	await until(func(): return art.result.status=="rasterizing","native executor stays active while raster yields")
	art.stop()
	await until(func(): return not art.active,"Stop cancels pending raster work")
	check(art.result.checked==0,"Stop does not submit buffered raster cells")
	var progress_before := Time.get_ticks_msec()
	submit([{"shape":"polygon","points":[[0,1100],[900,1999],[900,2000]],"material":58}])
	await until(func(): return art.result.changed>0,"sparse polygon publishes an early native receipt")
	await until(func(): return cell(0,1100)==58,"first sparse pixels reach the display image")
	var first_progress_ms := Time.get_ticks_msec()-progress_before
	print("ART_FIRST_PROGRESS_MS ",first_progress_ms)
	check(art.active and first_progress_ms<2000,"sparse polygon makes visible progress before raster completes")
	art.stop()
	await until(func(): return not art.active,"Stop retires sparse polygon after partial progress")
	panel.provider.requested_model = ""
	for i: int in range(16): panel.conversation.append({"role":"user","content":"turn %d" % i})
	panel.context_mode.select(0)
	check(panel.model_context().size()==16,"Full supplies all text turns")
	panel.context_mode.select(1)
	var compacted: Array = panel.model_context()
	check(compacted.size()==13 and compacted[0].content.contains("omitted"),"Compacted discloses omitted turns")
	panel.context_mode.select(2)
	check(panel.model_context()==compacted,"Custom starts with Compacted behavior")
	panel.context_mode.select(3)
	check(panel.model_context().is_empty() and panel.conversation.size()==16,"None omits context while retaining transcript")
	panel.conversation.clear()
	panel.context_mode.select(1)

	panel.request_area = Rect2i(160,160,32,32)
	panel.request_materials = [0,58]
	var stencil: Array = panel.stencil_operations([
		{"y":3,"repeat":2,"scale":2,"spans":[[5,1,58],[6,2,58],[6,1,0]]}
	])
	var receipts := [0]
	var count_receipt := func(_receipt: Dictionary) -> void: receipts[0] += 1
	art.native_receipt.connect(count_receipt)
	art.submit(panel.local_operations(stencil),panel.request_area,[],panel.request_materials)
	await until(func(): return not art.active and main.image.get_pixel(170,169).r8==58,"scaled scanline reaches native canvas")
	await until(func(): return main.image.get_pixel(172,169).r8==0 and main.image.get_pixel(175,169).r8==58 and main.image.get_pixel(176,169).r8==0,"ordered erase and blank preservation")
	art.native_receipt.disconnect(count_receipt)
	check(receipts[0]==2,"adjacent same-material scanline spans share a native batch")


	art.wb = wb
	check(main.paused,"drawing begins paused")
	var viewport_size: Vector2 = main.get_node("Layout").size
	wb.art_batches.popup_centered()
	await process_frame
	check(main.get_node("Layout").size==viewport_size,"floating panel preserves viewport layout")
	wb.art_batches.hide()
	# A large rectangle followed by erase, a diagonal and >32 individual pixels.
	var points: Array = []
	for x: int in range(120,184): points.append([x,150])
	submit([{"shape":"rectangle","x0":20,"y0":20,"x1":119,"y1":119,"material":58},
	{"shape":"rectangle","x0":40,"y0":40,"x1":59,"y1":59,"material":0},
	{"shape":"line","x0":130,"y0":20,"x1":170,"y1":60,"material":58},
	{"shape":"pixels","points":points,"material":58}])
	check(not wb.save_setup(),"save refuses unexecuted queued artwork")
	await finish()
	await until(func(): return cell(20,20)==58 and cell(59,59)==0 and cell(183,150)==58,"native published pixels")
	var exact := true
	for y: int in range(20,120):
		for x: int in range(20,120):
			var expected := 0 if x>=40 and x<=59 and y>=40 and y<=59 else 58
			if cell(x,y)!=expected: exact = false
	check(exact,"all 10000 rectangle cells and ordered erase exact")
	for x: int in range(130,171): check(cell(x,x-110)==58,"line pixel "+str(x))
	check(art.result.checked==10505 and art.result.changed==10505,"large batch counts span multiple chunks")
	# Ordinary human Sand is protected from art, as is a selected rectangle.
	wb.applied.brush = 2
	check(wb.paint(Vector2i(200,200),2),"ordinary human Sand paint")
	await until(func(): return cell(200,200)==2,"human Sand visible")
	var excluded := 0
	for y: int in range(198,203):
		for x: int in range(198,203):
			if cell(x,y)==2 or x>=201: excluded += 1
	submit([{"shape":"rectangle","x0":198,"y0":198,"x1":202,"y1":202,"material":58}],[Rect2i(201,198,2,5)])
	await finish()
	await until(func(): return cell(198,198)==58,"protected batch published")
	check(cell(200,200)==2 and cell(201,198)==0 and art.result.excluded==excluded,"source and rectangle protection executed")
	# Stop before first chunk, then Stop an admitted large batch at a chunk boundary.
	submit([{"shape":"rectangle","x0":300,"y0":300,"x1":700,"y1":700,"material":58}])
	art.stop()
	await until(func(): return not art.active,"Stop retires before queue")
	check(art.result.checked==0 and cell(300,300)==0,"stopped unstarted batch writes nothing")
	submit([{"shape":"rectangle","x0":300,"y0":300,"x1":700,"y1":700,"material":58}])
	wb.art_batches.set_process(false)
	await until(func():
		if not art.waiting: art.poll()
		return art.waiting,"one native chunk queued")
	await until(func(): return main.simulation_worker.art_state().receipt_ready,"one native chunk actually executed")
	art.stop()
	wb.art_batches.set_process(true)
	await until(func(): return not art.active,"Stop native acknowledgement")
	var prefix: int = art.result.checked
	# The bounded raster may flush a timed partial chunk before reaching capacity.
	check(prefix>0 and prefix<=4096 and art.result.status in ["partial","cancelled"],"Stop preserves at most executing native chunk")
	var stopped_receipt: Dictionary = art.last_receipt
	var stopped_readback: Array = stopped_receipt.get("readback",[])
	check(stopped_receipt.get("status")=="completed" and int(stopped_receipt.get("requested",-1))==prefix
		and int(stopped_receipt.get("checked",-1))==prefix and int(stopped_receipt.get("changed",-1))==prefix
		and int(stopped_receipt.get("confirmed",-1))==prefix and stopped_readback.size()==prefix
		and int(stopped_receipt.get("unchanged",-1))==0 and int(stopped_receipt.get("excluded",-1))==0
		and int(stopped_receipt.get("refused",-1))==0 and int(art.result.changed)==prefix
		and int(art.result.unchanged)==0 and int(art.result.excluded)==0 and int(art.result.refused)==0,
		"Stop accounting exactly matches the consumed native receipt")
	var exact_stop_readback := stopped_readback.size()==prefix
	for index: int in stopped_readback.size():
		if stopped_readback[index] != [300+index%401,300+index/401,0,58]: exact_stop_readback=false
	check(exact_stop_readback,"Stop receipt contains the exact ordered stored Empty-to-Wall prefix")
	for i: int in range(20): await process_frame
	check(art.result.checked==prefix and cell(700,700)==0,"no stale painting after Stop")
	var late: Dictionary = main.simulation_worker.art_queue(PackedInt32Array([700,700]),58,Rect2i(0,0,2048,2048),[],art.epoch)
	check(late.status=="refused","late old-epoch submission fenced")
	# Saved recipe includes the confirmed prefix; never the remainder.
	wb._name.text = "art-stage1-regression"
	check(wb.save_setup(),"save confirmed native artwork / "+wb.message)
	check(wb.load_setup(),"load saved artwork")
	await until(installed,"saved recipe installed")
	await until(func(): return cell(20,20)==58 and cell(200,200)==2,"saved native artwork reproduced")
	check(cell(700,700)==0,"save excludes unexecuted remainder")
	# Replacement invalidates pending art and cannot paint the new World.
	submit([{"shape":"rectangle","x0":900,"y0":900,"x1":1200,"y1":1200,"material":58}])
	wb.art_batches.set_process(false)
	await until(func():
		if not art.waiting: art.poll()
		return art.waiting,"one native chunk queued")
	await until(func(): return main.simulation_worker.art_state().receipt_ready,"old native chunk ready before replacement")
	check(wb.new_canvas(),"replace canvas with pending completion")
	wb.art_batches.set_process(true)
	await until(installed,"replacement native owner ready")
	await until(func(): return not art.active,"old batch retired")
	check(cell(900,900)==0 and wb.applied.edits.is_empty(),"new World excludes old callbacks and recipe")
	# Disc raster uses an independent exact membership check.
	submit([{"shape":"disc","x":60,"y":60,"radius":9,"material":58}])
	await finish()
	await until(func(): return cell(60,60)==58,"disc published")
	exact = true
	for y: int in range(50,71):
		for x: int in range(50,71):
			if cell(x,y)!=(58 if (x-60)*(x-60)+(y-60)*(y-60)<=81 else 0): exact=false
	check(exact,"exact disc raster")
	# Invalid input remains recoverable; local scope and material controls are enforced.
	var refused: Dictionary = art.submit([{"shape":"pixels","points":[[1,1]],"material":58}],Rect2i(0,0,2048,2048),[],[0])
	check(refused.status=="refused" and not art.active,"disabled material refused before native admission")
	refused = art.submit([{"shape":"pixels","points":[[2048,1]],"material":58}],Rect2i(0,0,2048,2048),[])
	check(refused.status=="refused","out of canvas rejected without ending future drawing")
	refused = art.submit([{"shape":"rectangle","x0":220,"y0":220,"x1":229,"y1":229,"material":58}],Rect2i(220,220,3,2),[])
	check(refused.status=="queued","limited work area accepted")
	await finish()
	await until(func(): return cell(220,220)==58,"scoped cells published")
	check(art.result.changed==6 and art.result.excluded==94 and cell(223,220)==0,"selected area checked on native owner")
	# Manual paint between chunks uses the same ordered recipe and survives reopen.
	wb.art_batches.set_process(false)
	submit([{"shape":"rectangle","x0":500,"y0":500,"x1":599,"y1":599,"material":58}])
	await until(func():
		if not art.waiting: art.poll()
		return art.waiting,"one native chunk queued")
	await until(func(): return main.simulation_worker.art_state().receipt_ready,"chunk ready for manual intervention")
	check(wb.paint(Vector2i(510,510),0),"human erase admitted alongside active batch")
	wb.art_batches.set_process(true)
	await finish()
	await until(func(): return cell(510,510)==0 and cell(599,599)==58,"human erase ordered between chunks")
	check(wb.save_setup(),"save mixed human and batch edits")
	check(wb.load_setup(),"reopen mixed human and batch edits")
	await until(installed,"mixed authored recipe installed")
	await until(func(): return cell(510,510)==0 and cell(599,599)==58,"mixed recipe reproduces native order")
	var evidence := OS.get_environment("WB_ART_EVIDENCE_DIR")
	if evidence.is_empty(): evidence = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if not evidence.is_empty() and DisplayServer.get_name()!="headless":
		DirAccess.make_dir_recursive_absolute(evidence)
		main.image.save_png(evidence+"/native-material-readback.png")
		wb._set_view(Vector2(0,0),Vector2i(960,540))
		wb.art_batches.popup_centered()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(evidence+"/stage1.png")==OK,"original post-draw PNG")
		root.size = Vector2i(1280,800)
		wb.art_batches.popup_centered()
		for i: int in range(3): await process_frame
		check(Rect2i(Vector2i.ZERO,Vector2i(root.get_visible_rect().size)).encloses(Rect2i(wb.art_batches.position,wb.art_batches.size)),"panel fits 1280x800")
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(evidence+"/stage1-1280.png")==OK,"smaller-window original PNG")
	print("ART_STAGE1_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"stop_prefix":prefix,"last_native_backend":art.last_receipt.get("backend"),"last_chunk_changed":art.last_receipt.get("changed"),"base":"d4b18e7f06839b35c8f6a66195206da0f33c5fa3"}))
	main.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
