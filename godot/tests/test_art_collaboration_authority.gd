extends SceneTree
## Actual ordinary Workbench/native authority checks, not simulated mutations.
const Context = preload("res://scripts/art_world_context.gd")
var main: Control
var wb: Control
var panel: Window
var checks := 0
var failures: Array = []
var observations: Array = []
var capture_result: Dictionary = {}
var capture_callbacks := 0
var inject_manual := false
var manual_admitted := false

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	print("ART_COLLABORATION_AUTHORITY_CHECK ",label," ",value)
	if not value: failures.append(label); push_error(label)

func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	var ok: bool = predicate.call()
	check(ok,label)
	return ok

func ready_world() -> bool:
	return not wb.applied.is_empty() and not wb.busy() and main.pending_microscenario_apply.is_empty()

func observe(region: Rect2i) -> Dictionary:
	capture_result = {}
	var admission: Dictionary = wb.paint_editor.art_context_capture(region,func(receipt: Dictionary) -> void:
		capture_callbacks += 1
		capture_result = receipt)
	check(admission.get("ok",false),"native observation admitted through PAINT owner")
	if admission.get("ok",false): await until(func() -> bool: return not capture_result.is_empty(),"native observation completes")
	return capture_result

func source() -> Dictionary:
	return wb.paint_editor.art_context_state().source

func guarded(operations: Array, fence: Dictionary, destructive: bool = false, guards: Array = []) -> Dictionary:
	var reply: Dictionary = panel.executor.submit_guarded(operations,Rect2i(0,0,512,512),guards,[0,28,58],fence,destructive,262144)
	check(reply.get("status","") == "queued","guarded recipe admitted to existing Art executor")
	if reply.get("status","") == "queued": await until(func() -> bool: return not panel.executor.active,"guarded native execution retires")
	return panel.executor.result.duplicate(true)

func receipt_received(_receipt: Dictionary) -> void:
	if inject_manual:
		inject_manual = false
		manual_admitted = main.simulation_worker.queue_emit_disc(500,500,0,58)

func run() -> void:
	root.size = Vector2i(1280,800)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	wb = main.shared_workbench
	if not await until(ready_world,"ordinary native Workbench ready"): finish(); return
	panel = wb._ensure_art_batches()
	check(panel.provider.serial == 0 and not panel.provider.active,"opening Art dispatches no HTTP")
	var before := source()
	var observed: Dictionary = await observe(Rect2i(0,0,64,64))
	check(observed.get("status","") == "completed" and observed.get("backend","") == "CyberNativeCellWorld","actual native capture identified")
	check(source() == before and observed.get("materials",PackedInt32Array()).size() == 4096,"read-only observation writes no cells")
	var count := capture_callbacks
	var bad: Dictionary = wb.paint_editor.art_context_capture(Rect2i(0,0,1024,1024),func(_r: Dictionary) -> void: capture_callbacks += 1)
	check(not bad.get("ok",false) and capture_callbacks == count,"oversized capture refuses without callback or write")
	var callbacks: Array = []
	var pending: Dictionary = wb.paint_editor.art_context_capture(Rect2i(0,0,512,512),func(r: Dictionary) -> void: callbacks.append(r))
	check(pending.get("ok",false),"cancellable capture admitted")
	check(wb.paint_editor.art_context_cancel(int(pending.get("operation_id",-1))),"capture cancellation is scoped")
	await until(func() -> bool: return callbacks.size() == 1,"cancelled capture has one completion owner")
	check(callbacks[0].status != "completed" and source() == before,"cancelled capture cannot write or publish successful context")
	var result: Dictionary = await guarded([{"shape":"rectangle","x0":8,"y0":8,"x1":23,"y1":15,"material":58}],source())
	check(result.status == "completed" and result.changed == 128,"approved geometry uses real native executor")
	check(panel.executor.last_receipt.get("backend","") == "CyberNativeCellWorld","stage receipt has actual native backend")
	observations.append(result)
	observed = await observe(Rect2i(8,8,16,8))
	check(observed.materials.count(58) == 128,"complete native plane matches actual constructed rectangle")
	var occupied := source()
	result = await guarded([{"shape":"pixels","points":[[8,8]],"material":0}],occupied)
	check(result.status == "refused" and result.changed == 0 and source() == occupied,"native owner enforces no destructive replacement")
	result = await guarded([{"shape":"pixels","points":[[8,8]],"material":0}],occupied,true)
	check(result.status == "completed" and result.changed == 1,"explicit permission allows supported native carving")
	var stale_source := occupied
	var current := source()
	result = await guarded([{"shape":"pixels","points":[[30,30]],"material":58}],stale_source)
	check(result.status == "refused" and result.changed == 0 and source() == current,"stale approval refuses before native write")
	result = await guarded([{"shape":"pixels","points":[[31,31]],"material":58}],source(),false,[Rect2i(31,31,1,1)])
	check(result.changed == 0 and result.excluded == 1,"actual native protected-region enforcement remains in force")
	panel.executor.native_receipt.connect(receipt_received)
	inject_manual = true
	result = await guarded([{"shape":"rectangle","x0":100,"y0":100,"x1":299,"y1":199,"material":58}],source())
	check(manual_admitted,"ordinary native manual command interleaves after acknowledged chunk")
	check(result.status == "partial" and result.changed > 0 and result.changed < 20000,"manual edit invalidates later approved chunks and preserves real prefix")
	check(str(result.reason).contains("source"),"partial receipt explains stale source")
	observations.append(result)
	await observe(Rect2i(500,500,1,1))
	check(capture_result.materials[0] == 58,"manual edit remains native-authoritative")
	check(panel.provider.serial == 0,"native suite never sends a model request")
	finish()

func finish() -> void:
	print("ART_COLLABORATION_AUTHORITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"evidence_kind":"ordinary Workbench and real native operations","model_requests":0,"observations":observations}))
	if main != null: main.queue_free(); await process_frame
	quit(1 if not failures.is_empty() else 0)
