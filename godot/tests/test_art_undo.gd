extends SceneTree

## Agent history through the mounted editor and actual native worker. Native
## captures are independent of render pixels; no model or network is used.
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var bench: Control
var editor: Control
var panel: Window
var art: RefCounted
var worker: RefCounted
var checks := 0
var failures: Array[String] = []
var workers := 1
var human_token := 0
var witnesses: Array = []
var measurements: Array = []
var source_identity := {}

func _initialize() -> void:
	var requested := int(OS.get_environment("ART_UNDO_WORKERS"))
	if requested in [1,4]: workers = requested
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers)
	run.call_deferred()

func check(ok: bool,label: String) -> bool:
	checks += 1
	print("ART_UNDO_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error("ART_UNDO "+label)
	return ok

func until(predicate: Callable,label: String,limit_ms: int = 90000) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if worker != null and worker.has_failed(): break
		await process_frame
	return check(false,label+" / "+str(bench.message if bench != null else "not mounted"))

func settled() -> bool:
	var state: Dictionary = worker.art_state()
	var paint: Dictionary = worker.paint_state()
	return not editor.busy() and not art.active and not panel.log_draw and not bool(paint.busy) \
		and not bool(paint.get("receipt_ready",false)) and not bool(paint.get("legacy_busy",false)) \
		and not state.queued and not state.executing and not state.receipt_ready

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() \
		and host.pending_microscenario_apply.is_empty() and settled()

func identity() -> Dictionary:
	var out := {"os":OS.get_name(),"godot":Engine.get_version_info().string,"display":DisplayServer.get_name()}
	for name: String in ["simulation_worker.gd","shared_workbench.gd","art_batch_executor.gd",
			"art_batch_panel.gd","workbench_paint_editor_controller.gd","workbench_paint_editor_executor.gd",
			"workbench_paint_editor_history.gd","workbench_setup.gd"]:
		out[name] = FileAccess.get_sha256("res://scripts/"+name)
	out.test_sha256 = FileAccess.get_sha256("res://tests/test_art_undo.gd")
	var binary := "cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so"
	out.native_sha256 = FileAccess.get_sha256("res://addons/cybersand_native/bin/"+binary)
	return out

func fresh(side: int = 512,edits: Array = []) -> bool:
	if not await until(ready,"previous operation settled before fresh start"): return false
	var generation: int = worker.paint_state().generation
	var data: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(side,side))
	data.edits = edits.duplicate(true)
	if not check(bench.apply(data),"fresh %d native start admitted" % side): return false
	if not await until(func() -> bool: return ready() and int(worker.paint_state().generation)>generation,
		"fresh native start acknowledged"): return false
	return check(host.paused and editor._undo_stack.is_empty() and editor._redo_stack.is_empty(),
		"fresh World clears both histories and starts paused")

func capture(region: Rect2i) -> PackedInt32Array:
	if not await until(settled,"native boundary settled before stored capture"): return PackedInt32Array()
	var state: Dictionary = worker.paint_state()
	var admitted: Dictionary = worker.paint_queue({"kind":"capture","region":region,
		"expected_generation":state.generation,"expected_revision":state.revision,"expected_tick":state.tick})
	if not check(admitted.status=="queued","independent stored capture admitted"): return PackedInt32Array()
	if not await until(func() -> bool: return worker.paint_state().receipt_ready,"stored capture receipt ready"):
		return PackedInt32Array()
	var receipt: Dictionary = worker.paint_take_result()
	if not check(receipt.get("operation_id")==admitted.operation_id and receipt.get("status")=="completed"
		and receipt.get("backend")=="CyberNativeCellWorld","stored capture owns a real native receipt"):
		return PackedInt32Array()
	var materials: PackedInt32Array = receipt.materials
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(materials.to_byte_array())
	witnesses.append({"region":[region.position.x,region.position.y,region.size.x,region.size.y],
		"sha256":hash.finish().hex_encode()})
	return materials

func capture_tiled(region: Rect2i) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(region.get_area())
	for y: int in range(0,region.size.y,512):
		for x: int in range(0,region.size.x,512):
			var tile := Rect2i(region.position+Vector2i(x,y),Vector2i(mini(512,region.size.x-x),mini(512,region.size.y-y)))
			var values := await capture(tile)
			if not check(values.size()==tile.get_area(),"complete tile for large native history comparison"):
				return PackedInt32Array()
			for dy: int in tile.size.y:
				for dx: int in tile.size.x: result[(y+dy)*region.size.x+x+dx] = values[dy*tile.size.x+dx]
	return result

func uniform(values: PackedInt32Array,count: int,material: int) -> bool:
	if values.size()!=count: return false
	for value: int in values:
		if value!=material: return false
	return true

func draw(operations: Array,scope: Rect2i,allowed: Array = [0,58]) -> bool:
	var admitted: Dictionary = art.submit(operations,scope,[],allowed)
	if not check(admitted.status=="queued","agent batch accepted at shared boundary"): return false
	if not await until(settled,"agent native receipts and history finalized",240000): return false
	return check(art.result.status=="completed","agent batch completes with authoritative native feedback")

func reverse(action: String) -> bool:
	if not check(editor.history_available(action),action+" is available at the paused native boundary"): return false
	var admitted: bool = editor.undo() if action=="undo" else editor.redo()
	if not check(admitted,action+" admitted through the shared PAINT owner"): return false
	check(not bench.save_setup(),"Save refuses queued "+action+" before native acknowledgement")
	return await until(settled,action+" native group completion",240000)

func human(point: Vector2i,material: int) -> bool:
	human_token += 1
	if not check(editor.begin_deferred_brush(point,material,0,human_token),"human stroke admitted through PAINT"): return false
	if not await until(settled,"human stroke and history confirmed"): return false
	return check(await capture(Rect2i(point,Vector2i.ONE))==PackedInt32Array([material]),"human stored material confirmed")

func grouped_overlap_and_noops() -> bool:
	if not await fresh(512,[[34,34,1,1,58]]): return false
	var region := Rect2i(20,20,128,96)
	var before := await capture(region)
	var initial_edits: Array = bench.applied.edits.duplicate(true)
	var receipt_count := [0]
	var count_receipt := func(_receipt: Dictionary) -> void: receipt_count[0] += 1
	art.native_receipt.connect(count_receipt)
	var ok := await draw([
		{"shape":"rectangle","x0":20,"y0":20,"x1":147,"y1":115,"material":58},
		{"shape":"rectangle","x0":30,"y0":30,"x1":39,"y1":39,"material":0},
		{"shape":"pixels","points":[[35,35]],"material":58},
		{"shape":"pixels","points":[[36,35]],"material":0}],region)
	art.native_receipt.disconnect(count_receipt)
	if not ok: return false
	var after := await capture(region)
	var exact := after.size()==region.get_area()
	for index: int in after.size():
		var point := region.position+Vector2i(index%region.size.x,index/region.size.x)
		var expected := 0 if Rect2i(30,30,10,10).has_point(point) and point!=Vector2i(35,35) else 58
		if after[index]!=expected: exact=false
	check(exact,"multiple agent commands preserve exact ordered overlap")
	check(receipt_count[0]>1 and editor._undo_stack.size()==1,"multiple native chunks form one ordinary agent Undo step")
	if not await reverse("undo"): return false
	check(await capture(region)==before and bench.applied.edits==initial_edits,
		"agent Undo restores first before-materials and the original authored record")
	if not await reverse("redo"): return false
	check(await capture(region)==after,"agent Redo restores final materials after repeated writes")
	var depth: int = editor._undo_stack.size()
	if not await draw([{"shape":"pixels","points":[[20,20]],"material":58}],region): return false
	check(art.result.changed==0 and editor._undo_stack.size()==depth,"unchanged agent receipt adds no history step")
	if not await reverse("undo"): return false
	check(await capture(region)==before,"native no-op preserves the preceding agent Undo")
	if not await draw([{"shape":"pixels","points":[[400,400]],"material":0}],Rect2i(400,400,1,1)): return false
	check(art.result.changed==0 and editor.history_available("redo"),"no-op agent batch preserves valid Redo")
	if not await reverse("redo"): return false
	depth = editor._undo_stack.size()
	if not await draw([
		{"shape":"pixels","points":[[250,250]],"material":58},
		{"shape":"pixels","points":[[250,250]],"material":0}],Rect2i(250,250,1,1)): return false
	check(await capture(Rect2i(250,250,1,1))==PackedInt32Array([0]) and editor._undo_stack.size()==depth,
		"net-zero ordered batch adds no empty history record")
	if not await reverse("undo"): return false
	check(await capture(region)==before,"net-zero batch advances the fence without invalidating earlier Undo")
	if not await draw([
		{"shape":"pixels","points":[[250,250]],"material":58},
		{"shape":"pixels","points":[[250,250]],"material":0}],Rect2i(250,250,1,1)): return false
	check(editor.history_available("redo") and bench.applied.edits==initial_edits,
		"net-zero agent batch preserves a valid Redo branch and the authored baseline")
	if not await reverse("redo"): return false
	check(await capture(region)==after,"Redo remains exact after a native paint-erase round trip")
	return true

func trusted_inverse_policy() -> bool:
	if not await fresh(): return false
	var region := Rect2i(60,60,2,1)
	if not await draw([{"shape":"pixels","points":[[60,60],[61,60]],"material":28}],region,[0,58,28]): return false
	check(await capture(region)==PackedInt32Array([28,28]),"human-enabled agent Metal destination reaches native cells")
	if not await reverse("undo"): return false
	check(await capture(region)==PackedInt32Array([0,0]),"trusted agent inverse may restore its own Metal to Empty")
	if not await reverse("redo"): return false
	if not await draw([{"shape":"pixels","points":[[60,60]],"material":0}],region): return false
	check(art.result.changed==0 and art.result.excluded==1 and await capture(region)==PackedInt32Array([28,28]),
		"ordinary agent erase still cannot acquire the trusted inverse's material permission")
	if not await reverse("undo"): return false
	check(await capture(region)==PackedInt32Array([0,0]),"excluded attempt preserves the previous legitimate agent Undo")
	return true

func stopped_prefix() -> bool:
	if not await fresh(): return false
	var region := Rect2i(50,50,401,401)
	var before := await capture(region)
	panel.set_process(false)
	var admitted: Dictionary = art.submit([{"shape":"rectangle","x0":50,"y0":50,"x1":450,"y1":450,"material":58}],region,[],[0,58])
	if not check(admitted.status=="queued","large Stop fixture admitted"):
		panel.set_process(true)
		return false
	check(not editor.undo(),"Undo cannot race an active agent operation")
	var queued := await until(func() -> bool:
		if not art.waiting: art.poll()
		return art.waiting,"one bounded native agent chunk admitted")
	var received := queued and await until(func() -> bool: return worker.art_state().receipt_ready,"one agent native receipt awaits consumption")
	if not received:
		panel.set_process(true)
		return false
	check(not editor.undo(),"Undo cannot steal an unconsumed agent receipt")
	art.stop("Undo fixture confirmed-prefix Stop")
	panel.set_process(true)
	if not await until(settled,"stopped prefix recorded before Undo"): return false
	var prefix: int = art.result.checked
	var receipt: Dictionary = art.last_receipt.duplicate(true)
	check(prefix>0 and prefix<=worker.MAX_BRUSH_FOOTPRINT_CELLS and receipt.readback.size()==prefix,
		"Stop history derives from the exact consumed native prefix")
	var after := await capture(region)
	var exact := after.size()==region.get_area()
	for index: int in after.size():
		if after[index]!=(58 if index<prefix else 0): exact=false
	check(exact,"native Stop prefix and untouched suffix independently match")
	if not await reverse("undo"): return false
	check(await capture(region)==before,"Undo reverses the complete stopped prefix")
	for frame: int in 10: await process_frame
	check(await capture(region)==before,"no delayed agent writes return after Undo")
	var late: Dictionary = worker.art_queue(PackedInt32Array([450,450]),58,region,[],art.epoch)
	check(late.status=="refused","retired agent epoch cannot reapply undone work")
	if not await reverse("redo"): return false
	check(await capture(region)==after,"Redo restores only the confirmed Stop prefix")
	return await draw([{"shape":"pixels","points":[[480,480]],"material":58}],Rect2i(480,480,1,1))

func interleaved_manual_history() -> bool:
	if not await fresh(): return false
	var region := Rect2i(20,20,128,128)
	var receipts: Array = []
	var receive := func(receipt: Dictionary) -> void: receipts.append(receipt.duplicate(true))
	art.native_receipt.connect(receive)
	panel.set_process(false)
	var admitted: Dictionary = art.submit([{"shape":"rectangle","x0":20,"y0":20,"x1":147,"y1":147,"material":58}],region,[],[0,58])
	if not check(admitted.status=="queued","interleaved agent batch admitted"):
		panel.set_process(true)
		art.native_receipt.disconnect(receive)
		return false
	var queued := await until(func() -> bool:
		if not art.waiting: art.poll()
		return art.waiting,"first interleaved native chunk queued")
	var received := queued and await until(func() -> bool: return worker.art_state().receipt_ready,"first interleaved native receipt ready")
	if received:
		bench.applied.brush = 2
		bench._brush.value = 2
		check(bench.paint(region.position,0),"human erase accepted between agent chunks")
	panel.set_process(true)
	var finished := received and await until(settled,"agent and deferred human work both finish")
	art.native_receipt.disconnect(receive)
	if not finished: return false
	var prefix: int = receipts[0].changed if not receipts.is_empty() else 0
	check(prefix>0 and prefix<region.get_area() and art.result.get("human_applied",0)==1,
		"native first segment precedes one confirmed human stroke and a later segment")
	var final := await capture(region)
	var expected := PackedInt32Array(); expected.resize(region.get_area())
	for index: int in expected.size():
		var offset := Vector2i(index%region.size.x,index/region.size.x)
		expected[index]=0 if offset.length_squared()<=4 else 58
	check(final==expected,"manual erase remains visible after the agent completes")
	if not await reverse("undo"): return false
	for index: int in expected.size():
		var offset := Vector2i(index%region.size.x,index/region.size.x)
		expected[index]=58 if index<prefix and offset.length_squared()>4 else 0
	check(await capture(region)==expected,"first Undo removes later agent work without overwriting the human erase")
	if not await reverse("undo"): return false
	for index: int in expected.size(): expected[index]=58 if index<prefix else 0
	check(await capture(region)==expected,"second Undo reverses only the intervening human stroke")
	if not await reverse("undo"): return false
	check(uniform(await capture(region),region.get_area(),0),"third Undo reverses the earlier agent segment")
	for turn: int in 3:
		if not await reverse("redo"): return false
	check(await capture(region)==final,"chronological Redo exactly restores agent-human-agent ordering")
	return true

func outside_changes_and_provider_boundary() -> bool:
	if not await fresh(): return false
	if not await draw([{"shape":"pixels","points":[[80,80]],"material":58}],Rect2i(80,80,1,1)): return false
	# Explicit controlled provider states; no request is sent to any endpoint.
	panel.set_process(false)
	panel.provider.active = true
	check(not editor.undo(),"Undo refuses an in-flight provider turn")
	panel.provider.active = false
	panel.remaining_turns = 1
	check(not editor.undo(),"Undo refuses a scheduled follow-up turn")
	panel.remaining_turns = 0
	panel.capturing = true
	check(not editor.undo(),"Undo refuses pending provider image capture")
	panel.capturing = false
	panel.set_process(true)
	check(editor.history_available("undo"),"provider boundary refusal preserves history for recovery")
	var revision: int = worker.paint_state().revision
	check(worker.queue_emit_cells(PackedInt32Array([80,80]),2),"real outside mutation admitted at idle boundary")
	if not await until(func() -> bool: return int(worker.paint_state().revision)>revision and settled(),"outside native mutation published"): return false
	check(not editor.undo() and not editor.history_available("undo"),"genuine outside mutation invalidates agent Undo")
	check(await capture(Rect2i(80,80,1,1))==PackedInt32Array([2]),"refused stale Undo preserves the outside material")
	if not await fresh(): return false
	if not await draw([{"shape":"pixels","points":[[90,90]],"material":58}],Rect2i(90,90,1,1)): return false
	var tick: int = worker.paint_state().tick
	if not check(bench.toggle_pause(),"simulation starts after agent edit"): return false
	if not await until(func() -> bool: return int(worker.paint_state().tick)>tick,"real native simulation tick advances"): return false
	if not check(bench.toggle_pause(),"simulation pauses again"): return false
	if not await until(func() -> bool: return settled() and bool(worker.paint_state().paused),"paused source published"): return false
	check(not editor.undo() and not editor.history_available("redo"),"simulation invalidates unsafe agent history")
	if not await draw([{"shape":"pixels","points":[[91,90]],"material":58}],Rect2i(91,90,1,1)): return false
	if not await fresh(): return false
	check(not editor.undo() and not editor.redo() and await capture(Rect2i(90,90,2,1))==PackedInt32Array([0,0]),
		"World replacement retires old agent history without touching the replacement")
	return true

func large_group() -> bool:
	if not await fresh(1024): return false
	var region := Rect2i(20,20,512,513)
	var start := Time.get_ticks_usec()
	if not await draw([{"shape":"rectangle","x0":20,"y0":20,"x1":531,"y1":532,"material":58}],region): return false
	check(region.get_area()>editor.MAX_CELLS and editor._undo_stack.size()>1,
		"large agent drawing keeps bounded history segments without reducing drawing capacity")
	check(uniform(await capture_tiled(region),region.get_area(),58),"every cell of the larger-than-PAINT agent batch is stored")
	var cancelled: Array = []
	var receive_cancelled := func(receipt: Dictionary) -> void: cancelled.append(receipt.duplicate(true))
	editor.history_action_finished.connect(receive_cancelled)
	var admitted: bool = editor.undo()
	check(admitted,"history planning starts before deterministic human Stop")
	panel.stop_all("Test Stop before any history native admission")
	var finished := await until(settled,"history planning Stop publishes its terminal outcome")
	editor.history_action_finished.disconnect(receive_cancelled)
	if not admitted or not finished: return false
	check(cancelled.size()==1 and cancelled[0].action=="undo" and cancelled[0].status=="cancelled"
		and cancelled[0].applied==0 and cancelled[0].changed==0 and not cancelled[0].remaining_group,
		"cancelled history planning emits one truthful terminal feedback receipt")
	check(uniform(await capture_tiled(region),region.get_area(),58) and editor._undo_stack.size()==2
		and editor._redo_stack.is_empty(),"planning Stop leaves exact native cells and reversible history untouched")
	if not await reverse("undo"): return false
	check(editor._undo_stack.is_empty() and uniform(await capture_tiled(region),region.get_area(),0)
		and bench.applied.edits.is_empty(),"one Undo drains every contiguous bounded segment and restores the authored baseline")
	if not await reverse("redo"): return false
	check(editor._redo_stack.is_empty() and uniform(await capture_tiled(region),region.get_area(),58),
		"one Redo restores the complete large grouped operation")
	var stopped: Array = []
	var stop_between_parts := func(receipt: Dictionary) -> void:
		stopped.append(receipt.duplicate(true))
		if receipt.action=="undo" and receipt.remaining_group:
			panel.stop_all("Test Stop between confirmed history parts")
	editor.history_action_finished.connect(stop_between_parts)
	admitted = editor.undo()
	check(admitted,"grouped Undo starts before receipt-boundary Stop")
	finished = await until(settled,"grouped Undo stops before queuing its remaining part")
	editor.history_action_finished.disconnect(stop_between_parts)
	if not admitted or not finished: return false
	# Timed native raster flushes can seal the earlier part just before the
	# hard cell cap. The actual applied receipt defines the stopped tail.
	var tail := int(stopped[0].get("applied",0)) if not stopped.is_empty() else 0
	check(stopped.size()==2 and stopped[0].action=="undo" and stopped[0].status=="completed"
		and tail>0 and tail<=editor.MAX_CELLS and stopped[0].remaining_group
		and stopped[1].status=="cancelled" and stopped[1].applied==0 and stopped[1].changed==0
		and not stopped[1].remaining_group,"Stop reports the confirmed history part and an unapplied cancelled continuation")
	var partial := await capture_tiled(region)
	var exact := partial.size()==region.get_area()
	for index: int in partial.size():
		if partial[index]!=(58 if index<region.get_area()-tail else 0): exact=false
	check(exact and editor._undo_stack.size()==1 and editor._redo_stack.size()==1,
		"receipt-boundary Stop leaves the earlier large segment natively untouched")
	for frame: int in 10: await process_frame
	check(await capture_tiled(region)==partial,"no delayed history continuation writes after Art Stop")
	if not await reverse("undo"): return false
	check(uniform(await capture_tiled(region),region.get_area(),0) and bench.applied.edits.is_empty(),
		"next Undo safely reverses the still-applied group remainder after Stop")
	if not await reverse("redo"): return false
	check(uniform(await capture_tiled(region),region.get_area(),58) and editor._redo_stack.is_empty(),
		"one later Redo exactly restores both retained parts after stopped Undo recovery")
	measurements.append({"cells":region.get_area(),"history_segments":editor._undo_stack.size(),
		"elapsed_usec":Time.get_ticks_usec()-start})
	return true

func run() -> void:
	source_identity = identity()
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	bench = host.shared_workbench
	worker = host.simulation_worker
	if bench != null:
		editor = bench.paint_editor
		panel = bench.art_batches
		art = panel.executor
	if check(bench != null and editor != null,"shared Workbench and PAINT history mounted") \
		and await until(ready,"initial actual native Workbench ready",180000):
		check(editor.has_method("history_available"),"agent-aware shared history API exists")
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		check(snapshot != null and snapshot.scheduler_thread_capacity_hint==workers,"actual native worker capacity matches requested fixture")
		if editor.has_method("history_available"):
			var ok := await grouped_overlap_and_noops()
			if ok: ok = await trusted_inverse_policy()
			if ok: ok = await stopped_prefix()
			if ok: ok = await interleaved_manual_history()
			if ok: ok = await outside_changes_and_provider_boundary()
			if ok: ok = await large_group()
			check(ok,"all mandatory agent Undo scenarios completed")
	host.queue_free()
	await process_frame
	await process_frame
	check(identity()==source_identity,"tested scripts and native bytes remained unchanged")
	print("ART_UNDO_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"workers":workers,
		"measurements":measurements,"native_material_witnesses":witnesses,"source_identity":source_identity,
		"provider_boundary_fixture":"controlled states; no HTTP request"}))
	quit(1 if not failures.is_empty() else 0)
