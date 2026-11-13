extends SceneTree
## Pinned Linux pilot: actual mounted Workbench -> Art plan/executor -> native World.
## PNGs visualize independently captured stored materials; they are not screenshots.
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var bench: Control
var editor: Control
var panel: Window
var art: RefCounted
var worker: RefCounted
var checks: Array = []
var failures: Array = []
var results: Array = []
var output := ""
var current_id := "bootstrap"
var receipt_log: FileAccess
var source_identity := {}
var workers := 1
var history_themes := {}

func _initialize() -> void:
	workers = clampi(int(OS.get_environment("SB_NATIVE_WORKERS")),1,4)
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers)
	run.call_deferred()

func check(ok: bool,label: String) -> bool:
	checks.append({"case":current_id,"label":label,"passed":ok})
	if not ok:
		failures.append({"case":current_id,"label":label})
		push_error("SLM_NATIVE "+current_id+" "+label)
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
	for name: String in ["main.gd","simulation_worker.gd","shared_workbench.gd","art_batch_plan.gd",
			"art_batch_executor.gd","art_batch_panel.gd","workbench_paint_editor_controller.gd",
			"workbench_paint_editor_executor.gd","workbench_paint_editor_history.gd","workbench_setup.gd"]:
		out[name] = FileAccess.get_sha256("res://scripts/"+name)
	out.harness_sha256 = FileAccess.get_sha256(get_script().resource_path)
	out.native_sha256 = FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")
	out.rapier_sha256 = FileAccess.get_sha256("res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")
	return out

func hash_materials(values: PackedInt32Array) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(values.to_byte_array())
	return digest.finish().hex_encode()

func write_json(path: String,value: Variant) -> bool:
	var f := FileAccess.open(path,FileAccess.WRITE)
	if not check(f!=null,"output file opened "+path.get_file()): return false
	f.store_string(JSON.stringify(value,"\t"))
	f.close()
	return true

func log_receipt(receipt: Dictionary) -> void:
	receipt_log.store_line(JSON.stringify({"case":current_id,"receipt":receipt}))
	receipt_log.flush()
	check(receipt.get("backend")=="CyberNativeCellWorld","draw receipt names actual native World")
	check(receipt.get("status") in ["completed","partial"],"native chunk has explicit completion")

func fresh(edits: Array = []) -> bool:
	if not await until(ready,"previous operation settled before fresh start"): return false
	var generation: int = worker.paint_state().generation
	var data: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	data.edits = edits.duplicate(true)
	if not check(bench.apply(data),"fresh native start admitted"): return false
	if not await until(func() -> bool: return ready() and int(worker.paint_state().generation)>generation,
		"fresh native start acknowledged"): return false
	return check(host.paused and editor._undo_stack.is_empty() and editor._redo_stack.is_empty(),
		"fresh World clears histories and starts paused")

func capture(region: Rect2i) -> PackedInt32Array:
	if not await until(settled,"native boundary settled before independent capture"): return PackedInt32Array()
	var state: Dictionary = worker.paint_state()
	var admitted: Dictionary = worker.paint_queue({"kind":"capture","region":region,
		"expected_generation":state.generation,"expected_revision":state.revision,"expected_tick":state.tick})
	if not check(admitted.status=="queued","independent stored capture admitted"): return PackedInt32Array()
	if not await until(func() -> bool: return worker.paint_state().receipt_ready,"stored capture receipt ready"):
		return PackedInt32Array()
	var receipt: Dictionary = worker.paint_take_result()
	if not check(receipt.get("operation_id")==admitted.operation_id and receipt.get("status")=="completed"
		and receipt.get("backend")=="CyberNativeCellWorld","capture owns an actual native receipt"):
		return PackedInt32Array()
	var values: PackedInt32Array = receipt.materials
	check(values.size()==region.get_area(),"capture contains every requested cell")
	var witness: Dictionary = receipt.duplicate(true)
	witness.erase("materials")
	witness["materials_i32le_sha256"] = hash_materials(values)
	witness["region_xywh"] = [region.position.x,region.position.y,region.size.x,region.size.y]
	receipt_log.store_line(JSON.stringify({"case":current_id,"capture":witness}))
	receipt_log.flush()
	return values

func draw(operations: Array,scope: Rect2i,guards: Array = [],allowed: Array = [0,58]) -> bool:
	var admitted: Dictionary = art.submit(operations,scope,guards,allowed)
	if not check(admitted.status=="queued","Art planner accepts bounded operation list: "+str(admitted.get("reason",""))): return false
	if not await until(settled,"native receipts and shared history finalized",240000): return false
	return check(art.result.status=="completed","batch finishes after authoritative native receipts")

func reverse(action: String) -> bool:
	if not check(editor.history_available(action),action+" available at paused native boundary"): return false
	var admitted: bool = editor.undo() if action=="undo" else editor.redo()
	if not check(admitted,action+" admitted through shared PAINT history"): return false
	check(not bench.save_setup(),"Save refuses queued "+action)
	return await until(settled,action+" native completion",240000)

func export_cells(case: Dictionary,values: PackedInt32Array) -> Dictionary:
	var width: int = case.width
	var height: int = case.height
	var crop := PackedInt32Array()
	crop.resize(width*height)
	var picture := Image.create(width,height,false,Image.FORMAT_RGB8)
	var raw := Image.create(width,height,false,Image.FORMAT_L8)
	var filled := 0
	var outside := 0
	var unexpected := 0
	for index: int in values.size():
		var x := index % 512
		var y := index / 512
		var material: int = values[index]
		if material not in [0,58]: unexpected += 1
		if x>=width or y>=height:
			if material!=0: outside += 1
			continue
		crop[y*width+x]=material
		if material!=0: filled += 1
		picture.set_pixel(x,y,Color8(232,226,205) if material==58 else Color8(13,21,28))
		raw.set_pixel(x,y,Color(float(material)/255.0,0,0))
	var stem: String = output+"/"+str(case.id)
	check(picture.save_png(stem+".png")==OK,"Godot saves stored-material visualization PNG")
	check(raw.save_png(stem+".materials.png")==OK,"Godot saves exact material-ID PNG")
	var binary := FileAccess.open(stem+".materials.i32le",FileAccess.WRITE)
	if check(binary!=null,"raw readback file opened"):
		binary.store_buffer(crop.to_byte_array())
		binary.close()
	check(outside==0,"no changed stored cells outside requested area")
	check(unexpected==0,"only admitted material IDs reach stored cells")
	check(filled>0,"nonempty native output")
	return {"filled_cells":filled,"outside_area_cells":outside,"unexpected_material_cells":unexpected,
		"crop_i32le_sha256":hash_materials(crop),"whole_world_i32le_sha256":hash_materials(values),
		"png":str(case.id)+".png","material_png":str(case.id)+".materials.png",
		"raw_materials":str(case.id)+".materials.i32le"}

func replay_case(case: Dictionary) -> bool:
	current_id = str(case.id)
	var start := Time.get_ticks_usec()
	var before_failures := failures.size()
	if not await fresh(): return false
	var area := Rect2i(0,0,int(case.width),int(case.height))
	if not await draw(case.operations,area): return false
	var terminal: Dictionary = art.result.duplicate(true)
	var values := await capture(Rect2i(0,0,512,512))
	if values.size()!=512*512: return false
	var report := export_cells(case,values)
	var history_checked: bool = OS.get_environment("SB_NATIVE_HISTORY")=="each" or not history_themes.has(str(case.get("theme","")))
	if history_checked:
		history_themes[str(case.get("theme",""))]=true
		# Representative per-theme probe through the same shared owner used by humans.
		if not await reverse("undo"): return false
		var undone := await capture(Rect2i(0,0,512,512))
		var empty := PackedInt32Array(); empty.resize(512*512)
		check(undone==empty,"Undo restores every native cell to the blank start")
		if not await reverse("redo"): return false
		check(await capture(Rect2i(0,0,512,512))==values,"Redo restores exact full native readback")
		# Save authored construction, then reconstruct a genuinely new World.
		bench._name.text = "slm-pilot-"+current_id
		check(bench.save_setup(),"settled authored start saved")
		var saved_path: String = Setup._path(bench._name.text)
		if FileAccess.file_exists(saved_path):
			var saved_bytes := FileAccess.get_file_as_bytes(saved_path)
			var saved_copy := FileAccess.open(output+"/"+current_id+".setup.json",FileAccess.WRITE)
			if check(saved_copy!=null,"saved construction copied to evidence"):
				saved_copy.store_buffer(saved_bytes)
				saved_copy.close()
		var generation: int = worker.paint_state().generation
		check(bench.load_setup(),"saved authored start read and admitted")
		if not await until(func() -> bool: return ready() and int(worker.paint_state().generation)>generation,
			"saved construction installed into new native World"): return false
		check(await capture(Rect2i(0,0,512,512))==values,"save/reopen reproduces every stored native material")
	report.merge({"id":case.id,"theme":case.get("theme",""),"seed":case.get("seed",0),
		"width":case.width,"height":case.height,"terminal":terminal,"operation_count":case.operations.size(),
		"elapsed_usec":Time.get_ticks_usec()-start,"passed":failures.size()==before_failures,
		"history_and_reopen_checked":history_checked,
		"operations_sha256":case.get("operations_sha256",""),"program_sha256":case.get("program_sha256","")})
	results.append(report)
	write_json(output+"/"+current_id+".receipt.json",report)
	print("SLM_NATIVE_CASE ",JSON.stringify(report))
	return failures.size()==before_failures

func protection_probe() -> bool:
	current_id = "invariant-protection"
	if not await fresh([[48,48,1,1,28]]): return false
	var area := Rect2i(8,8,80,80)
	var guard := Rect2i(20,20,16,16)
	if not await draw([{"shape":"rectangle","x0":0,"y0":0,"x1":95,"y1":95,"material":58}],area,[guard]): return false
	var values := await capture(Rect2i(0,0,512,512))
	var exact := values.size()==512*512
	var expected_changed := area.get_area()-guard.get_area()-1
	for index: int in values.size():
		var point := Vector2i(index%512,index/512)
		var expected := 58 if area.has_point(point) and not guard.has_point(point) else 0
		if point==Vector2i(48,48): expected=28
		if values[index]!=expected: exact=false
	check(exact,"scope, protected rectangle and protected source material survive exact whole-World comparison")
	check(art.result.changed==expected_changed,"native changed count closes against eligible cells")
	return exact

func stop_probe() -> bool:
	current_id = "invariant-stop"
	if not await fresh(): return false
	var region := Rect2i(20,20,128,128)
	panel.set_process(false)
	var admitted: Dictionary = art.submit([{"shape":"rectangle","x0":20,"y0":20,"x1":147,"y1":147,"material":58}],region,[],[0,58])
	if not check(admitted.status=="queued","Stop fixture admitted"):
		panel.set_process(true); return false
	check(not editor.undo(),"Undo refuses active agent batch")
	var queued := await until(func() -> bool:
		if not art.waiting: art.poll()
		return art.waiting,"one bounded native chunk queued")
	var received := queued and await until(func() -> bool: return worker.art_state().receipt_ready,
		"one native receipt waits unconsumed")
	if not received:
		panel.set_process(true); return false
	check(not editor.undo(),"Undo refuses unconsumed native receipt")
	art.stop("SLM pilot deterministic receipt-boundary Stop")
	panel.set_process(true)
	if not await until(settled,"Stop preserves and records confirmed native prefix"): return false
	var prefix: int = art.result.checked
	check(prefix>0 and prefix<=worker.MAX_BRUSH_FOOTPRINT_CELLS and prefix<region.get_area(),
		"Stop exposes bounded positive partial completion")
	var values := await capture(region)
	var exact := values.size()==region.get_area()
	for index: int in values.size():
		if values[index]!=(58 if index<prefix else 0): exact=false
	check(exact,"Stop readback matches exact prefix and untouched suffix")
	for frame: int in 10: await process_frame
	check(await capture(region)==values,"no delayed writes after Stop")
	if not await reverse("undo"): return false
	var empty := PackedInt32Array(); empty.resize(region.get_area())
	check(await capture(region)==empty,"Undo reverses confirmed stopped prefix")
	if not await reverse("redo"): return false
	check(await capture(region)==values,"Redo restores only confirmed stopped prefix")
	return exact

func run() -> void:
	output = OS.get_environment("SB_NATIVE_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	receipt_log = FileAccess.open(output+"/native-receipts.jsonl",FileAccess.WRITE)
	if receipt_log==null: push_error("Cannot open evidence output"); quit(2); return
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SB_NATIVE_CASES")))
	var cases: Array = document.cases if document is Dictionary else document
	source_identity=identity()
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	bench=host.shared_workbench
	worker=host.simulation_worker
	if bench!=null:
		editor=bench.paint_editor
		panel=bench.art_batches
		art=panel.executor
	var mounted := check(bench!=null and editor!=null,"actual Workbench and shared PAINT owner mounted")
	if mounted and await until(ready,"initial actual native Workbench ready",180000):
		art.native_receipt.connect(log_receipt)
		var snapshot: CyberSimulationSnapshot=worker.take_latest_snapshot(-1)
		check(snapshot!=null and snapshot.scheduler_thread_capacity_hint==workers,"actual native worker capacity matches fixture")
		var ok := await protection_probe()
		if ok: ok=await stop_probe()
		if ok:
			for case: Dictionary in cases:
				if not await replay_case(case): break
	check(results.size()==cases.size(),"every requested case executed")
	host.queue_free()
	await process_frame
	await process_frame
	check(identity()==source_identity,"consumed source and native bytes unchanged during run")
	var summary := {"schema_version":1,"qualification":"pinned Linux headless native-material pilot",
		"claim_limits":["No graphical framebuffer or human visual acceptance","No Windows qualification",
			"Does not qualify current accepted main","Only paused 512-square Hard Wall/Empty authoring"],
		"source_identity":source_identity,"workers":workers,"cases_requested":cases.size(),
		"cases_completed":results.size(),"cases":results,"checks":checks,"failures":failures,
		"passed":failures.is_empty() and results.size()==cases.size(),
		"png_encoding":"Godot Image visualization of native stored-material readback: Empty dark; Hard Wall ivory"}
	write_json(output+"/native-summary.json",summary)
	receipt_log.close()
	print("SLM_NATIVE_RESULT ",JSON.stringify({"checks":checks.size(),"failures":failures,
		"cases_requested":cases.size(),"cases_completed":results.size(),"passed":summary.passed}))
	quit(0 if summary.passed else 1)
