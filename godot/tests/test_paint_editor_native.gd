extends SceneTree

# Actual existing worker/native World. No RG8 render samples are material identity.
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true
var host: Control
var wb: Control
var worker: RefCounted
var failures: Array[String] = []
var checks := 0
var measurements: Array = []
var witnesses: Array = []
var source_identity: Dictionary = {}
func sources() -> Dictionary:
	var out := {}
	for name: String in ["main.gd","simulation_worker.gd","shared_workbench.gd","workbench_setup.gd","workbench_paint_editor_executor.gd","workbench_paint_editor_controller.gd","workbench_paint_editor_history.gd","workbench_paint_editor_shapes.gd","workbench_paint_editor_overlay.gd"]:
		out[name]=FileAccess.get_sha256("res://scripts/"+name)
	out["test_paint_editor_native.gd"]=FileAccess.get_sha256("res://tests/test_paint_editor_native.gd")
	out["native_linux"]=FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")
	return out
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("PAINT_EDITOR_NATIVE " + label)
	return value
func wait_for(predicate: Callable, milliseconds: int = 30000) -> bool:
	var until := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await process_frame
	return false
func request(values: Dictionary) -> Dictionary:
	var state: Dictionary = worker.paint_state()
	var out := values.duplicate(true)
	out.expected_generation = int(state.generation)
	out.expected_revision = int(state.revision)
	out.expected_tick = int(state.tick)
	return out
func result() -> Dictionary:
	if not check(await wait_for(func() -> bool: return worker.paint_state().receipt_ready),"native acknowledgement arrives"): return {}
	return worker.paint_take_result()
func submit(values: Dictionary) -> Dictionary:
	var admission: Dictionary = worker.paint_queue(request(values))
	if not check(admission.status == "queued", "native request admitted: " + str(admission)): return admission
	var receipt: Dictionary = await result()
	if receipt.get("kind")=="capture" and receipt.get("status")=="completed":
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(receipt.materials.to_byte_array())
		var area: Rect2i = receipt.region
		witnesses.append({"region":[area.position.x,area.position.y,area.size.x,area.size.y],"sha256":hash.finish().hex_encode()})
	return receipt
func rectangle(area: Rect2i, material: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	for y: int in range(area.position.y,area.end.y):
		for x: int in range(area.position.x,area.end.x): cells.append_array([x,y,material])
	return cells
func install(size: int) -> bool:
	var generation: int = worker.paint_state().generation
	var data := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(size,size))
	if not check(wb.apply(data),"install %d admitted" % size): return false
	return check(await wait_for(func() -> bool: return not wb.busy() and worker.paint_state().generation > generation and worker.paint_state().paused),"install %d confirmed" % size)
func test_native() -> void:
	var palette: PackedInt32Array = worker.paint_materials()
	check(palette.size()==131 and 0 in palette and 131 in palette and 10 not in palette,"full compiled native roster")
	if not await install(512): return
	var mixed := PackedInt32Array([40,40,2,41,40,3,42,40,58,40,41,0,41,41,16,42,41,81,40,42,13,41,42,131,42,42,1])
	var edit: Dictionary = await submit({"kind":"edit","cells":mixed})
	check(edit.get("status")=="completed" and edit.get("cells")==mixed and edit.get("backend")=="CyberNativeCellWorld","multi-material native completion")
	var capture: Dictionary = await submit({"kind":"capture","region":Rect2i(40,40,3,3)})
	var wanted := PackedInt32Array([2,3,58,0,16,81,13,131,1])
	check(capture.get("materials")==wanted,"selection captures exact source identities including Empty")
	var paste := mixed.duplicate()
	for i: int in range(0,paste.size(),3): paste[i]+=1
	var pasted: Dictionary = await submit({"kind":"edit","cells":paste})
	capture=await submit({"kind":"capture","region":Rect2i(41,40,3,3)})
	check(capture.get("materials")==wanted,"overlapping paste preserves immutable source")
	var undo := paste.duplicate()
	for i: int in range(undo.size()/3): undo[i*3+2]=pasted.before[i]
	var inverse: Dictionary = await submit({"kind":"edit","cells":undo,"expected_before":pasted.after})
	check(inverse.get("status")=="completed" and inverse.get("after")==pasted.get("before"),"native undo exact prior IDs")
	inverse=await submit({"kind":"edit","cells":paste,"expected_before":pasted.before})
	check(inverse.get("status")=="completed" and inverse.get("after")==pasted.get("after"),"native redo exact mixed IDs")
	edit=await submit({"kind":"edit","cells":PackedInt32Array([41,40,0])})
	check(edit.get("after")==PackedInt32Array([0]),"Empty erases natively")
	for invalid: Dictionary in [
		{"kind":"edit","cells":PackedInt32Array([100,100,58,101,100,10])},
		{"kind":"edit","cells":PackedInt32Array([100,100,58,101,100,58]),"protected":[Rect2i(101,100,1,1)]},
		{"kind":"edit","cells":PackedInt32Array([100,100,58]),"expected_before":PackedInt32Array([3])},
		{"kind":"edit","cells":PackedInt32Array([42,40,58]),"source_allowed":PackedInt32Array([0,58])}]:
		edit=await submit(invalid)
		check(edit.get("status")=="refused" and edit.get("applied")==0,"whole-operation refusal: "+str(edit.get("reason")))
	capture=await submit({"kind":"capture","region":Rect2i(100,100,2,1)})
	check(capture.get("materials")==PackedInt32Array([0,0]),"refused operations leave no hidden prefix")
	capture=await submit({"kind":"capture","region":Rect2i(511,511,2,2)})
	check(capture.get("status")=="refused" and capture.get("materials").is_empty(),"incomplete cropped capture refused")
	capture=await submit({"kind":"capture","region":Rect2i(510,510,2,2)})
	check(capture.get("materials").size()==4,"native border captured")
	for field: String in ["expected_generation","expected_revision"]:
		var stale := request({"kind":"edit","cells":PackedInt32Array([100,100,58])})
		stale[field]-=1
		check(worker.paint_queue(stale).status=="refused","stale "+field+" refused")
	var large := rectangle(Rect2i(120,120,128,128),2)
	check(worker.paint_queue(request({"kind":"edit","cells":large})).status=="queued","large shape admitted")
	check(not worker.queue_emit_cells(PackedInt32Array([2,2]),58),"legacy brush cannot interleave")
	check(worker.paint_queue(request({"kind":"edit","cells":large})).status=="refused","single bounded operation slot")
	worker.paint_stop()
	edit=await result()
	check(edit.get("status")=="cancelled" and edit.get("applied")==0,"Stop during preflight writes nothing")
	check(worker.paint_queue(request({"kind":"edit","cells":large})).status=="queued","large shape retry admitted")
	check(await wait_for(func()->bool:return int(worker.paint_state().get("applied",0))>=4096),"native application prefix observed")
	worker.paint_stop()
	edit=await result()
	check(edit.get("status")=="partial" and edit.get("applied",0)>=4096 and edit.get("applied",0)<16384,"Stop reports truthful partial prefix")
	var recovery: PackedInt32Array = edit.cells.duplicate()
	for i: int in range(recovery.size()/3): recovery[i*3+2]=edit.before[i]
	inverse=await submit({"kind":"edit","cells":recovery,"expected_before":edit.after})
	check(inverse.get("status")=="completed","partial prefix can be reversed safely")
	capture=await submit({"kind":"capture","region":Rect2i(120,120,128,128)})
	var empty := PackedInt32Array(); empty.resize(16384); empty.fill(0)
	check(capture.get("materials")==empty,"recovered cancellation has no hidden tail")
	for size: int in [512,1024,2048]:
		if not await install(size): return
		var area := Rect2i(size-256,size-256,256,256)
		edit=await submit({"kind":"edit","cells":rectangle(area,2)})
		check(edit.get("status")=="completed" and edit.get("applied")==65536,"65536-cell edit on %d world" % size)
		measurements.append({"extent":size,"cells":65536,"slices":edit.get("slices"),"elapsed_usec":edit.get("elapsed_usec"),"maximum_slice_usec":edit.get("maximum_slice_usec")})
		capture=await submit({"kind":"capture","region":area})
		wanted.resize(65536); wanted.fill(2)
		check(capture.get("materials")==wanted,"complete stored readback on %d world" % size)
	if not await install(512): return
	var maximum := rectangle(Rect2i(0,0,512,512),2)
	edit=await submit({"kind":"edit","cells":maximum})
	check(edit.get("status")=="completed" and edit.get("applied")==262144,"maximum operation completes")
	measurements.append({"extent":512,"cells":262144,"slices":edit.get("slices"),"elapsed_usec":edit.get("elapsed_usec"),"maximum_slice_usec":edit.get("maximum_slice_usec")})
	maximum.append_array([0,512,2])
	check(worker.paint_queue(request({"kind":"edit","cells":maximum})).status=="refused","maximum plus one refuses at admission")
	check(worker.paint_queue(request({"kind":"capture","region":Rect2i(0,0,513,512)})).status=="refused","sample memory cap refuses")
	var data := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))
	data.actors=[Setup.instance(Setup.BARREL,1,Vector2(250,250))]
	data.next_id=2
	var old_generation: int = worker.paint_state().generation
	check(wb.apply(data) and await wait_for(func()->bool:return not wb.busy() and worker.paint_state().generation>old_generation),"protected body installed")
	edit=await submit({"kind":"edit","cells":PackedInt32Array([200,250,58,250,250,58])})
	check(edit.get("status")=="refused" and edit.get("applied")==0,"body mask refuses whole edit before unprotected prefix")
	capture=await submit({"kind":"capture","region":Rect2i(250,250,1,1)})
	check(capture.get("status")=="refused" and capture.get("materials").is_empty(),"body mask never masquerades as copied stored Wall")
	if not await install(512): return
	check(worker.paint_queue(request({"kind":"edit","cells":rectangle(Rect2i(10,10,256,256),58)})).status=="queued","replacement race queued")
	var stale_source := request({"kind":"edit","cells":PackedInt32Array([100,100,58])})
	var replacement := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))
	var started: bool = wb.apply(replacement)
	if not started: worker.paint_stop()
	edit=await result()
	check(edit.get("status") in ["cancelled","invalidated"] and edit.get("applied")==0,"World replacement retires stale edit")
	if not started: check(wb.apply(replacement),"replacement admitted after Stop")
	check(await wait_for(func()->bool:return not wb.busy() and worker.paint_state().generation>int(stale_source.expected_generation)),"new native World installed")
	check(worker.paint_queue(stale_source).status=="refused","old source remains invalid after replacement")
func run() -> void:
	source_identity=sources()
	var configured := int(OS.get_environment("PAINT_TEST_WORKERS"))
	if configured in [1,4]: ProjectSettings.set_setting("cybersand/native_worker_threads",configured)
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	wb=host.shared_workbench
	worker=host.simulation_worker
	if wb == null:
		check(false,"Workbench mount failed")
		host.queue_free()
		await process_frame
		quit(1)
		return
	if check(await wait_for(func()->bool:return not wb.applied.is_empty() and worker.paint_state().generation>=0,60000),"ordinary native Workbench installed"):
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		check(snapshot != null and (configured not in [1,4] or snapshot.scheduler_thread_capacity_hint==configured),"actual native worker capacity matches requested run")
		await test_native()
	host.queue_free()
	await process_frame
	await process_frame
	check(source_identity==sources(),"tested source and native bytes unchanged during execution")
	print("PAINT_EDITOR_NATIVE ",JSON.stringify({"checks":checks,"failures":failures,"workers":configured,"measurements":measurements,"native_material_witnesses":witnesses,"witness_sha256":JSON.stringify(witnesses).sha256_text(),"source_identity":source_identity}))
	quit(int(not failures.is_empty()))
