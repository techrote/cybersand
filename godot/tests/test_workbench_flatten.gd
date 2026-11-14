extends SceneTree

## GEN-008-FLAT-001 acceptance. Author and reopen run in separate OS processes.
## Every material witness comes from the native owner; render pixels only supply
## supplementary graphical evidence. The API gate was red on accepted main.
const Setup = preload("res://scripts/workbench_setup.gd")
const Generated = preload("res://scripts/workbench_generated_map.gd")
const SaveName := "gen008-flatten-acceptance"
const Expectation := "user://gen008-flatten-expectation.json"
const ExpectedPlane := "user://gen008-flatten-expected.u16le"
const AuthorRegion := Rect2i(16,16,368,288)
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true
class DetachedFailureHost extends Control:
	var simulation_worker: RefCounted
	var restarted := false
	func workbench_restart(_setup: Dictionary) -> bool:
		restarted = true
		return false

var host: Control
var bench: Control
var editor: Control
var panel: Window
var art: RefCounted
var worker: RefCounted
var dialog: ConfirmationDialog
var checks := 0
var failures: Array[String] = []
var side := 512
var workers := 1
var human_sequence := 0
var measurements: Dictionary = {}
var witnesses: Array = []
var completed := false
var phases: Dictionary = {}
var source_identity: Dictionary = {}
var process_instance := Crypto.new().generate_random_bytes(16).hex_encode()
var start_usec := 0
var previous_frame_usec := 0
var maximum_frame_gap_usec := 0

func _initialize() -> void:
	start_usec = Time.get_ticks_usec()
	var selected := OS.get_environment("FLATTEN_SIDE")
	if not selected.is_empty(): side = int(selected)
	selected = OS.get_environment("FLATTEN_WORKERS")
	if not selected.is_empty(): workers = int(selected)
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers)
	process_frame.connect(_frame)
	run.call_deferred()

func _frame() -> void:
	var now := Time.get_ticks_usec()
	if previous_frame_usec > 0: maximum_frame_gap_usec = maxi(maximum_frame_gap_usec,now-previous_frame_usec)
	previous_frame_usec = now

func check(ok: bool,label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("FLATTEN "+label)
	return ok

func phase(label: String) -> void:
	phases[label] = true
	print("FLATTEN_PHASE ",JSON.stringify({"phase":label,"elapsed_usec":Time.get_ticks_usec()-start_usec}))

func until(predicate: Callable,label: String,limit_ms: int = 90000) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if worker != null and worker.has_failed(): break
		await process_frame
	return check(false,label+" / "+str(bench.message if bench != null else "unmounted"))

func settled() -> bool:
	var paint: Dictionary = worker.paint_state()
	var agent: Dictionary = worker.art_state()
	return not editor.busy() and not art.active and not panel.log_draw \
		and not bool(paint.get("busy",false)) and not bool(paint.get("receipt_ready",false)) \
		and not bool(paint.get("legacy_busy",false)) and not agent.queued and not agent.executing \
		and not agent.receipt_ready and art.manual.is_empty()

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() \
		and host.pending_microscenario_apply.is_empty() and settled() and not bench.is_flatten_pending()

func identity() -> Dictionary:
	var result := {"godot":Engine.get_version_info().string,"os":OS.get_name(),"display":DisplayServer.get_name()}
	for filename: String in ["scripts/main.gd","scripts/shared_workbench.gd","scripts/simulation_worker.gd","scripts/microscenario_host.gd",
		"scripts/workbench_setup.gd","scripts/workbench_material_baseline.gd",
		"scripts/workbench_generated_map.gd","scripts/workbench_paint_editor_history.gd",
		"scripts/workbench_paint_editor_controller.gd","scripts/workbench_paint_editor_executor.gd","scripts/art_batch_executor.gd",
		"tests/test_workbench_flatten.gd","tests/test_workbench_material_baseline.gd",
		"tests/flatten_save_fault_child.gd"]:
		result[filename] = FileAccess.get_sha256("res://"+filename)
	var native_name := "cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so"
	result.native_sha256 = FileAccess.get_sha256("res://addons/cybersand_native/bin/"+native_name)
	return result

func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func screenshot(label: String) -> void:
	var directory := OS.get_environment("FLATTEN_SCREENSHOTS")
	if directory.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"actual graphical framebuffer "+label)

func capture(label: String) -> Dictionary:
	if not await until(settled,"authoring receipts retired before "+label): return {}
	var started := Time.get_ticks_usec()
	var state: Dictionary = worker.paint_state()
	var admitted: Dictionary = worker.material_capture_request(int(state.generation))
	if not check(bool(admitted.get("ok",false)),"independent native bulk capture admitted: "+label): return {}
	var token := int(admitted.token)
	var packet: Dictionary = {}
	var deadline := Time.get_ticks_msec()+90000
	while packet.is_empty() and Time.get_ticks_msec()<deadline:
		packet = worker.material_capture_poll(token)
		if packet.is_empty(): await process_frame
	if not check(bool(packet.get("ok",false)),"independent complete native capture: "+label):
		worker.material_capture_cancel(token)
		return {}
	var released: Dictionary = worker.material_capture_finish(token,false)
	check(bool(released.get("ok",false)),"read-only native capture lease released: "+label)
	var bytes: PackedByteArray = packet.get("cells",PackedByteArray())
	check(bytes.size()==side*side*2 and packet.get("extent")==Vector2i(side,side),"complete two-byte row-major plane: "+label)
	check(packet.get("sha256")==digest(bytes),"independent native plane integrity: "+label)
	witnesses.append({"label":label,"sha256":digest(bytes),"bytes":bytes.size(),
		"generation":packet.get("generation"),"native_generation":packet.get("native_generation"),
		"tick":packet.get("tick"),"revision":packet.get("revision"),
		"native_capture_usec":packet.get("capture_usec"),"native_boundary_usec":packet.get("native_boundary_usec"),
		"owner_roundtrip_usec":Time.get_ticks_usec()-started})
	return packet

func small_capture(region: Rect2i) -> PackedInt32Array:
	if not await until(settled,"independent PAINT readback boundary"): return PackedInt32Array()
	var state: Dictionary = worker.paint_state()
	var admitted: Dictionary = worker.paint_queue({"kind":"capture","region":region,
		"expected_generation":state.generation,"expected_revision":state.revision,"expected_tick":state.tick,
		"expected_authoring_generation":state.get("authoring_generation",1)})
	if not check(admitted.get("status")=="queued","independent stored-cell readback admitted"): return PackedInt32Array()
	if not await until(func() -> bool: return worker.paint_state().receipt_ready,"stored-cell receipt ready"): return PackedInt32Array()
	var receipt: Dictionary = worker.paint_take_result()
	check(receipt.get("operation_id")==admitted.operation_id and receipt.get("status")=="completed" \
		and receipt.get("backend")=="CyberNativeCellWorld","readback is native-confirmed and owns its receipt")
	return receipt.get("materials",PackedInt32Array())

func human(point: Vector2i,material: int) -> bool:
	human_sequence += 1
	if not check(editor.begin_deferred_brush(point,material,0,human_sequence),"manual brush admitted"): return false
	return await until(settled,"manual brush and history acknowledged") \
		and check(editor.last_receipt.get("status")=="completed","manual brush natively completed")

func rectangle(region: Rect2i,material: int) -> bool:
	var cells := PackedInt32Array()
	cells.resize(region.get_area()*3)
	var cursor := 0
	for y: int in range(region.position.y,region.end.y):
		for x: int in range(region.position.x,region.end.x):
			cells[cursor]=x; cells[cursor+1]=y; cells[cursor+2]=material; cursor+=3
	if not check(editor.commit_cells(cells,"Flatten fixture rectangle"),"manual rectangular edit admitted"): return false
	return await until(settled,"manual rectangular native receipt",240000) \
		and check(editor.last_receipt.get("status")=="completed","manual rectangular edit confirmed")

func draw(points: Array,material: int = 58) -> bool:
	var admitted: Dictionary = art.submit([{"shape":"pixels","points":points,"material":material}],AuthorRegion,[],[0,58])
	if not check(admitted.get("status")=="queued","agent batch admitted"): return false
	return await until(settled,"agent receipts and chronological history settled") \
		and check(art.result.get("status")=="completed","agent batch natively completed")

func reverse(action: String) -> bool:
	if not check(editor.history_available(action),"post-baseline chronological "+action+" available"): return false
	if not check(editor.undo() if action=="undo" else editor.redo(),"native history "+action+" admitted"): return false
	return await until(settled,"native history "+action+" acknowledged")

func physical_identity() -> Dictionary:
	var result := {"session":0,"bodies":[]}
	if host.physical_actor_session==null: return result
	result.session = host.physical_actor_session.get_instance_id()
	for rig: Node2D in host.physical_actor_session._rigs:
		for body: RigidBody2D in rig.bodies():
			result.bodies.append([body.get_instance_id(),body.get_rid().get_id()])
	return result

func generate() -> bool:
	phase("generate")
	dialog.open_new()
	# Deepworks is an authored 1024-square semantic plan. Use the installed
	# coordinate-based native profile for the independently supported 2048 plane.
	var profile := "strata-natural" if side==2048 else "gen007-deepworks"
	var selected := -1
	for index: int in dialog._profile.item_count:
		if dialog._profile.get_item_text(index)==profile: selected=index
	if not check(selected>=0,"real installed native profile is discoverable: "+profile): return false
	dialog._profile.select(selected)
	dialog._profile.item_selected.emit(selected)
	for index: int in dialog._extent.item_count:
		if dialog._extent.get_item_id(index)==side: dialog._extent.select(index)
	dialog._preview_button.pressed.emit()
	if not await until(func() -> bool: return dialog._phase=="ready" or dialog._status.text.begins_with("Refused"),"native generator preview",300000): return false
	if not check(dialog._phase=="ready","native generator accepted selected extent: "+dialog._status.text): return false
	measurements.generator_profile=profile
	dialog.confirmed.emit()
	dialog.hide()
	if not await until(ready,"native generated start installation",240000): return false
	return check(not bench._generated_active.is_empty() and Setup.extent_of(bench.applied)==Vector2i(side,side),"generated terrain uses existing Shared Workbench owner")

func inject_bad_capture(kind: String) -> bool:
	# Hold only the main-thread consumer; the real native owner captures its
	# complete immutable packet first. Corrupt its published value under the
	# same mutex to exercise the actual production validation/failure path.
	var before: Dictionary = bench.applied.duplicate(true)
	var generated: Dictionary = bench._generated_active.duplicate(true)
	var history_depth: int = editor._undo_stack.size()
	bench.set_process(false)
	var admitted: Dictionary = bench.request_flatten()
	if not check(bool(admitted.get("ok",false)),"failure injection capture admitted: "+kind):
		bench.set_process(true)
		return false
	var token := int(admitted.token)
	if not await until(func() -> bool: return not worker.material_capture_poll(token).is_empty(),"native packet ready for "+kind):
		bench.cancel_flatten(); bench.set_process(true)
		return false
	var packet: Dictionary = worker.material_capture_poll(token).duplicate(true)
	if not check(bool(packet.get("ok",false)),"real complete packet precedes injected "+kind):
		bench.cancel_flatten(); bench.set_process(true)
		return false
	match kind:
		"truncated": packet.cells.resize(packet.cells.size()-2)
		"dimensions": packet.extent=Vector2i(511,side)
		"unsupported_id":
			packet.cells.encode_u16(0,65535)
			packet.sha256=digest(packet.cells)
		"integrity": packet.sha256="0".repeat(64)
		"stale_token": packet.request_token=token+1
		"native_owner_failure": packet={"ok":false,"error":"Injected native owner failure after capture"}
		"owner_shutdown": packet={"ok":false,"error":"Native owner stopped during material capture"}
	worker._mutex.lock()
	if kind=="deadline": worker._material_capture_request.deadline=Time.get_ticks_usec()-1
	if kind=="stale_session": worker._material_capture_request.generation=int(worker._world_generation)-1
	worker._material_capture_result=packet
	worker._mutex.unlock()
	bench.set_process(true)
	if not await until(func() -> bool: return not bench.is_flatten_pending(),"injected "+kind+" settles"): return false
	check(bench.get_flatten_status().status=="failed","injected "+kind+" reports explicit failure")
	return check(bench.applied==before and bench._generated_active==generated and bench._material_baseline.is_empty() \
		and editor._undo_stack.size()==history_depth,"injected "+kind+" preserves baseline, recipe and supported history")

func refuse_and_cancel() -> bool:
	phase("failure_atomicity")
	var saved: Dictionary = bench.applied.duplicate(true)
	var undo_depth: int = editor._undo_stack.size()
	var packet: Dictionary = await capture("before-refusals")
	if packet.is_empty(): return false
	var refused: Dictionary = bench.request_flatten(1)
	check(not bool(refused.get("ok",false)),"insufficient staging capacity is explicitly refused")
	check(bench.applied==saved and editor._undo_stack.size()==undo_depth,"capacity refusal retains authored start and Undo history")
	refused = worker.material_capture_request(int(worker.paint_state().generation)-1)
	check(not bool(refused.get("ok",false)),"stale owner generation is refused before capture")
	var admitted: Dictionary = bench.request_flatten()
	if not check(bool(admitted.get("ok",false)),"cancellable Flatten admitted"): return false
	bench.cancel_flatten("Qualification cancellation before adoption")
	if not await until(func() -> bool: return not bench.is_flatten_pending(),"cancelled preparation settles"): return false
	for frame: int in 8: await process_frame
	check(bench.applied==saved and bench._material_baseline.is_empty(),"cancelled Flatten never adopts a partial baseline or loses history")
	check(editor._undo_stack.size()==undo_depth,"cancelled Flatten retains supported Undo entries")
	var after: Dictionary = await capture("after-refusals")
	if not check(not after.is_empty() and after.cells==packet.cells,"refusals and cancellation leave every native material unchanged"): return false
	for kind: String in ["truncated","dimensions","unsupported_id","integrity","stale_token","native_owner_failure","owner_shutdown","deadline","stale_session"]:
		if not await inject_bad_capture(kind): return false
	after=await capture("after-injected-failures")
	if not check(not after.is_empty() and after.cells==packet.cells,"all injected native receipt failures preserve the complete live material plane"): return false
	# Planning occupies the real editor path before its native acknowledgement.
	human_sequence+=1
	if not check(editor.begin_deferred_brush(Vector2i(72,72),58,0,human_sequence),"pending human edit admitted"): return false
	refused = bench.request_flatten()
	check(not bool(refused.get("ok",false)),"Flatten refuses queued or planning human work")
	if not await until(settled,"pending human edit still completes after refusal"): return false
	panel.set_process(false)
	admitted = art.submit([{"shape":"rectangle","x0":180,"y0":180,"x1":307,"y1":275,"material":58}],AuthorRegion,[],[0,58])
	if not check(admitted.get("status")=="queued","pending agent batch admitted"):
		panel.set_process(true)
		return false
	refused = bench.request_flatten()
	check(not bool(refused.get("ok",false)),"Flatten refuses queued agent operation")
	if not await until(func() -> bool:
		if not art.waiting: art.poll()
		return art.waiting,"agent operation reaches native queue"):
		panel.set_process(true)
		return false
	refused = bench.request_flatten()
	check(not bool(refused.get("ok",false)),"Flatten refuses executing or unconsumed agent operation")
	art.stop("Flatten qualification bounded stopped prefix")
	panel.set_process(true)
	if not await until(settled,"stopped agent acknowledged prefix retires"): return false
	check(not art.active and int(art.result.get("checked",0))<128*96,"stopped agent retains only its confirmed prefix")
	refused = art.submit([{"shape":"pixels","points":[[90,90]],"material":999}],AuthorRegion,[],[0,58])
	check(refused.get("status")=="refused" and not art.active,"failed agent validation leaves edit fence recoverable")
	return await human(Vector2i(74,72),58)

func simulate(ticks: int) -> bool:
	var before := int(worker.paint_state().tick)
	if not check(bench.toggle_pause() and not host.paused,"live native simulation resumed"): return false
	if not await until(func() -> bool: return int(worker.paint_state().tick)>=before+ticks,"native simulation progressed",180000): return false
	if not check(bench.toggle_pause() and host.paused,"simulation paused at owner boundary"): return false
	return await until(func() -> bool: return ready() and bool(worker.paint_state().paused),"paused native owner settled")

func detached_failure_fences() -> bool:
	# No live worker-exclusive flag is changed. A detached production worker
	# exercises the actual failure fence, independently of injected receipts.
	var detached := CyberSimulationWorker.new()
	detached._running=true
	detached._workbench_extent=Vector2i(512,512)
	detached._world_generation=9
	var admitted: Dictionary = detached.material_capture_request(9)
	if not check(bool(admitted.get("ok",false)),"detached production owner admits pending capture"): return false
	var authoring_generation := int(detached._authoring_generation)
	detached._simulation_failed=true
	var polled: Dictionary = detached.material_capture_poll(int(admitted.token))
	check(not bool(polled.get("ok",false)) and str(polled.get("error","")).contains("failed"),
		"actual detached owner failure flag rejects pending capture")
	var committed: Dictionary = detached.material_capture_finish(int(admitted.token),true)
	check(not bool(committed.get("ok",false)) and detached._authoring_generation==authoring_generation,
		"actual detached owner failure cannot retire authoring generation")
	var failed_snapshot := CyberSimulationSnapshot.new()
	failed_snapshot.simulation_failed=true
	detached._published_snapshot=failed_snapshot
	var detached_host := DetachedFailureHost.new()
	detached_host.simulation_worker=detached
	var before: Dictionary = bench.applied.duplicate(true)
	var baseline: Dictionary = bench._material_baseline.duplicate(true)
	var history: Array = editor._undo_stack.duplicate(true)
	var mounted_host: Control = bench.host
	# The temporary host binding lasts only for these synchronous refusal calls.
	bench.host=detached_host
	var reset_refused: bool = not bench.reset_selected()
	var restore_refused: bool = not bench.restore_start()
	bench.host=mounted_host
	check(reset_refused and restore_refused and not detached_host.restarted,
		"failed-owner Reset and Restore cannot replace a standalone baseline with bare Setup edits")
	check(bench.applied==before and bench._material_baseline==baseline and editor._undo_stack==history,
		"failed-owner Reset and Restore preserve complete baseline and chronological history")
	detached_host.free()
	detached._simulation_failed=false
	detached._published_snapshot=null
	admitted=detached.material_capture_request(9)
	check(bool(admitted.get("ok",false)),"detached failure releases capture lease for subsequent valid admission")
	if admitted.get("ok",false): detached.material_capture_cancel(int(admitted.token))
	detached._running=false
	measurements.detached_failure_fence={"mode":"detached-production-worker","native_failure_covered_separately":true,
		"reset_refused":reset_refused,"restore_refused":restore_refused,"retry_admitted":admitted.get("ok",false)}
	return failures.is_empty()

func stop_during_capture() -> bool:
	phase("owner_shutdown")
	var before: Dictionary = bench.applied.duplicate(true)
	var baseline: Dictionary = bench._material_baseline.duplicate(true)
	var history: Array = editor._undo_stack.duplicate(true)
	var saved_hash := FileAccess.get_sha256(Setup._path(SaveName))
	bench.set_process(false)
	var admitted: Dictionary = bench.request_flatten()
	if not check(bool(admitted.get("ok",false)),"real owner shutdown fixture admits Flatten"):
		bench.set_process(true)
		return false
	var token := int(admitted.token)
	if not await until(func() -> bool: return not worker.material_capture_poll(token).is_empty(),"complete native packet before actual owner shutdown"):
		bench.cancel_flatten(); bench.set_process(true)
		return false
	check(bool(worker.material_capture_poll(token).get("ok",false)),"real shutdown happens after complete native capture, before adoption")
	worker.stop_worker()
	bench._poll_flatten()
	bench.set_process(true)
	check(not worker._thread.is_started() and not bool(worker._running),"actual native owner thread terminated during pending preparation")
	check(not bench.is_flatten_pending() and bench.get_flatten_status().status=="failed",
		"actual owner shutdown explicitly cancels pending baseline adoption")
	return check(bench.applied==before and bench._material_baseline==baseline and editor._undo_stack==history \
		and FileAccess.get_sha256(Setup._path(SaveName))==saved_hash,
		"actual owner shutdown preserves authored history, baseline and existing saved bytes")

func flatten_checked(label: String,playing: bool = false) -> bool:
	phase(label)
	var state: Dictionary = worker.paint_state().duplicate(true)
	var physical := physical_identity()
	var actor: Dictionary = bench.body_state(1).duplicate(true)
	var started := Time.get_ticks_usec()
	maximum_frame_gap_usec=0
	var admitted: Dictionary
	if label=="flatten_paused":
		check(not bench._flatten_button.disabled,"actual Flatten control is enabled")
		bench._flatten_button.pressed.emit()
		await process_frame
		if not check(bench._flatten_confirmation.visible,"actual history-destructive confirmation is displayed"): return false
		bench._flatten_confirmation.confirmed.emit()
		bench._flatten_confirmation.hide()
		admitted={"ok":bench.is_flatten_pending()}
	else:
		admitted=bench.request_flatten()
	if not check(bool(admitted.get("ok",false)),"Flatten admitted at coherent native boundary"): return false
	if not await until(func() -> bool: return not bench.is_flatten_pending(),"complete Flatten adoption",90000): return false
	var status: Dictionary = bench.get_flatten_status()
	measurements[label] = {"elapsed_usec":Time.get_ticks_usec()-started,"maximum_frame_gap_usec":maximum_frame_gap_usec,
		"status":status,"static_memory_bytes":OS.get_static_memory_usage(),"static_peak_bytes":OS.get_static_memory_peak_usage()}
	if not check(str(status.get("status","")) in ["complete","completed"],"Flatten reports committed success"): return false
	check(physical_identity()==physical,"Flatten preserves the same physical session and every Rapier body")
	check(worker.paint_state().generation==state.generation,"Flatten preserves live World generation")
	check(int(worker.paint_state().tick)>=int(state.tick) and (not playing or not host.paused),"Flatten neither resets tick nor stops live play")
	if playing:
		if not await until(func() -> bool: return int(worker.paint_state().tick)>int(state.tick),"same World keeps ticking after Flatten without a resume action"): return false
		check(not bool(worker.paint_state().paused),"native owner remains unpaused after live Flatten")
	if not playing:
		var actor_after: Dictionary = bench.body_state(1)
		measurements[label].actor_before=actor.duplicate(true)
		measurements[label].actor_after=actor_after.duplicate(true)
		# Opening the ordinary modal confirmation advances the existing input
		# cancellation fence. Compare every physical/configuration value exactly.
		actor.erase("control_generation")
		actor_after.erase("control_generation")
		check(worker.paint_state().tick==state.tick and actor_after==actor,"paused Flatten preserves tick, actor pose, velocity and state exactly")
	check(bench.applied.edits.is_empty() and bench._generated_active.is_empty(),"old construction and generator reconstruction inputs are discarded")
	check(editor._undo_stack.is_empty() and editor._redo_stack.is_empty(),"all pre-Flatten Undo/Redo entries retire together")
	var baseline: Dictionary = bench._material_baseline
	return check(baseline.get("schema")==1 and baseline.get("extent")==Vector2i(side,side) \
		and baseline.cells.size()==side*side*2 and baseline.sha256==digest(baseline.cells),"adopted standalone canonical uint16LE plane is complete and integral")

func author() -> void:
	# This reserved fixture is the only named file removed by the test. The
	# production action must still prove it does not recreate a saved file.
	if FileAccess.file_exists(Setup._path(SaveName)):
		check(DirAccess.remove_absolute(Setup._path(SaveName))==OK,"remove prior reserved acceptance fixture before author run")
	if not await generate(): return
	bench._set_view(Vector2.ZERO,Vector2i(960,540))
	phase("construction")
	if not await rectangle(AuthorRegion,0): return
	if not await rectangle(Rect2i(400,32,104,200),0): return
	if not await draw([[80,80],[81,80],[82,80]]): return
	if not await human(Vector2i(81,80),0): return
	if not await reverse("undo"): return
	check(await small_capture(Rect2i(80,80,3,1))==PackedInt32Array([58,58,58]),"manual Undo restores previous chronological agent result")
	if not await reverse("redo"): return
	if not await human(Vector2i(side-1,side-4),131): return
	if not await human(Vector2i(0,side-3),0): return
	if side==512 and not await refuse_and_cancel(): return
	if not await rectangle(Rect2i(110,36,24,12),2): return
	if not await rectangle(Rect2i(150,36,16,12),3): return
	if not check(bench.place("midge",Vector2(448,100)),"real Rapier actor installation admitted"): return
	if not await until(ready,"real actor installation acknowledged"): return
	var static_plane := await capture("before-simulation")
	phase("simulation")
	if not await simulate(12): return
	var evolved := await capture("simulation-derived-materials")
	if not check(not evolved.is_empty() and evolved.cells!=static_plane.cells,"simulation genuinely changes stored native material identities"): return
	check(int(evolved.tick)>0 and not bench.body_state(1).is_empty(),"nonzero native tick and live actor before Flatten")
	var old_epoch := int(worker.art_state().epoch)
	var old_state: Dictionary = worker.paint_state().duplicate(true)
	if not await flatten_checked("flatten_paused"): return
	var after := await capture("after-flatten")
	if not check(not after.is_empty() and after.cells==evolved.cells and bench._material_baseline.cells==evolved.cells,
		"every native material ID before/after Flatten and the adopted baseline is identical"): return
	check(not FileAccess.file_exists(Setup._path(SaveName)),"Flatten itself does not Save")
	check(after.cells.decode_u16(((side-4)*side+side-1)*2)==131 \
		and after.cells.decode_u16((side-3)*side*2)==0,"maximum supported material and Empty preserve row-boundary LE16 encoding")
	var late: Dictionary = worker.art_queue(PackedInt32Array([76,72]),58,AuthorRegion,[],old_epoch)
	check(late.get("status")=="refused","pre-Flatten agent generation cannot replay after baseline adoption")
	late=worker.paint_queue({"kind":"capture","region":Rect2i(76,72,1,1),
		"expected_generation":old_state.generation,"expected_revision":old_state.revision,"expected_tick":old_state.tick,
		"expected_authoring_generation":old_state.get("authoring_generation",1)})
	check(late.get("status")=="refused","pre-Flatten human request cannot replay even when native tick and revision are unchanged")
	var recorded: Array = bench.applied.edits.duplicate(true)
	panel.request_epoch=old_epoch
	panel.provider.finished.emit(1001,'[{"shape":"pixels","points":[[76,72]],"material":58}]',{},"")
	for frame: int in 4: await process_frame
	check(bench.applied.edits==recorded and not art.active,"late provider response cannot add retired history")
	await screenshot("flatten-identical-live-world")
	# A second explicit Flatten while playing establishes that the action does
	# not pause/restart simulation and captures a coherent later native plane.
	if not check(bench.toggle_pause() and not host.paused,"playing Flatten fixture starts live"): return
	if not await flatten_checked("flatten_playing",true): return
	if not check(bench.toggle_pause() and host.paused,"owner explicitly pauses after live Flatten"): return
	if not await until(func() -> bool: return ready() and bool(worker.paint_state().paused),"post-Flatten play settles"): return
	phase("post_flatten_history")
	if not await human(Vector2i(90,90),131): return
	if not await draw([[96,90],[97,90]]): return
	if not await reverse("undo"): return
	check(await small_capture(Rect2i(90,90,1,1))==PackedInt32Array([131]),"agent Undo preserves the earlier post-Flatten human edit")
	if not await reverse("undo"): return
	check(await small_capture(Rect2i(90,90,1,1))==PackedInt32Array([int(bench._material_baseline.cells.decode_u16((90*side+90)*2))]),"manual Undo returns to flattened baseline")
	if not await reverse("redo") or not await reverse("redo"): return
	if not await human(Vector2i(80,80),0): return
	if side==512 and not detached_failure_fences(): return
	var expected: PackedByteArray = bench._material_baseline.cells.duplicate()
	# The expected saved plane is independently composed only from the explicit
	# operations just acknowledged; later simulation is deliberately excluded.
	for value: Array in [[90,90,131],[96,90,58],[97,90,58],[80,80,0]]:
		expected.encode_u16((int(value[1])*side+int(value[0]))*2,int(value[2]))
	var live_before := await capture("post-flatten-edits-before-later-simulation")
	if not await simulate(8): return
	var live_after := await capture("later-simulation-excluded-from-save")
	check(not live_before.is_empty() and not live_after.is_empty() and live_before.cells!=live_after.cells,
		"post-Flatten simulation changes native layout without silently changing authored baseline")
	phase("save")
	bench._name.text=SaveName
	var save_started := Time.get_ticks_usec()
	if not check(bench.save_setup(),"explicit Save named start persists flattened baseline and acknowledged edits"): return
	measurements.save_usec=Time.get_ticks_usec()-save_started
	var Baseline: Script = load("res://scripts/workbench_material_baseline.gd")
	var saved: Dictionary = Baseline.read_named(SaveName)
	if not check(saved.get("flattened",false) and not saved.has("generation"),"saved standalone baseline requires no generator recipe"): return
	check(saved.baseline.cells==bench._material_baseline.cells,"Save retains exact flattened plane rather than recapturing current simulation")
	var file := FileAccess.open(ExpectedPlane,FileAccess.WRITE)
	if not check(file!=null,"independent expected native plane file opened"): return
	file.store_buffer(expected); file.close()
	var expectation := {"author_instance":process_instance,"author_pid":OS.get_process_id(),"side":side,"workers":workers,
		"material_sha256":digest(expected),"baseline_sha256":bench._material_baseline.sha256,
		"setup":bench.applied,"source_identity":source_identity,"saved_file_sha256":FileAccess.get_sha256(Setup._path(SaveName))}
	file=FileAccess.open(Expectation,FileAccess.WRITE)
	if not check(file!=null,"independent fresh-process expectation opened"): return
	file.store_string(JSON.stringify(expectation)); file.close()
	await screenshot("flatten-explicitly-saved")
	completed=true
	phase("complete")

func reopen() -> void:
	phase("reopen")
	var file := FileAccess.open(Expectation,FileAccess.READ)
	if not check(file!=null,"prior process expectation is available"): return
	var expected: Dictionary = JSON.parse_string(file.get_as_text()); file.close()
	if not check(expected.author_instance!=process_instance and int(expected.side)==side,"fresh process and exact expected extent"): return
	if not check(expected.source_identity==source_identity,"author and reopen use identical tested source and native runtime"): return
	var bytes := FileAccess.get_file_as_bytes(ExpectedPlane)
	if not check(bytes.size()==side*side*2 and digest(bytes)==expected.material_sha256,"independent expectation has complete canonical material bytes"): return
	var started := Time.get_ticks_usec()
	bench._name.text=SaveName
	if not check(bench.load_setup(),"normal Load accepts standalone material baseline"): return
	if not await until(ready,"fresh-process baseline preparation and installation",240000): return
	measurements.load_usec=Time.get_ticks_usec()-started
	check(bench._generated_active.is_empty() and not dialog.visible,"fresh-process Load needs no discarded generation recipe or confirmation")
	var actual := await capture("fresh-process-reconstructed-plane")
	if not actual.is_empty() and actual.cells!=bytes:
		var differences: Array = []
		var count := 0
		for index: int in side*side:
			var expected_id := int(bytes.decode_u16(index*2))
			var actual_id := int(actual.cells.decode_u16(index*2))
			if actual_id!=expected_id:
				count+=1
				if differences.size()<32: differences.append([index%side,index/side,expected_id,actual_id])
		var observed := FileAccess.open("user://gen008-flatten-observed.u16le",FileAccess.WRITE)
		observed.store_buffer(actual.cells); observed.close()
		measurements.reopen_mismatch={"count":count,"first_expected_actual":differences,"expected_sha256":digest(bytes),"actual_sha256":digest(actual.cells)}
	if not check(not actual.is_empty() and actual.cells==bytes,"entire fresh-process native material plane equals saved baseline plus acknowledged edits"): return
	check(JSON.parse_string(JSON.stringify(bench.applied))==expected.setup,"actor, equipment and authoring configuration survive standalone Load")
	check(int(worker.paint_state().tick)==0 and not bench.body_state(1).is_empty(),"fresh Load uses normal initial physical state and reconstructed actor")
	check(editor._undo_stack.is_empty() and editor._redo_stack.is_empty(),"session-local history is not resurrected from discarded construction")
	phase("continued_authoring")
	if not await human(Vector2i(100,100),131): return
	if not await draw([[102,100]]): return
	if not await reverse("undo") or not await reverse("redo"): return
	check(await small_capture(Rect2i(102,100,1,1))==PackedInt32Array([58]),"native agent Undo/Redo continues after fresh-process Load")
	if not check(bench.restore_start(),"Restore start reconstructs flattened baseline plus current acknowledged edits"): return
	if not await until(ready,"Restore start after continued authoring",240000): return
	check(await small_capture(Rect2i(100,100,1,1))==PackedInt32Array([131]),"Restore preserves post-load authored edit")
	bench._set_view(Vector2.ZERO,Vector2i(960,540))
	await screenshot("flatten-reopened-and-continued")
	if not await stop_during_capture(): return
	completed=true
	phase("complete")

func run() -> void:
	var implementation: Script = load("res://scripts/shared_workbench.gd")
	var names: Array[String] = []
	for method: Dictionary in implementation.get_script_method_list(): names.append(str(method.name))
	for method: String in ["request_flatten","is_flatten_pending","get_flatten_status"]:
		check(method in names,"Shared Workbench exposes "+method)
	if not failures.is_empty():
		print("FLATTEN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"phase":"contract"}))
		quit(1)
		return
	if not check(side in [512,1024,2048] and workers in [1,4],"supported finite extent and worker count"):
		quit(1); return
	source_identity=identity()
	phase("startup")
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	root.size=Vector2i(1440,1000)
	bench=host.shared_workbench
	editor=bench.paint_editor
	panel=bench.art_batches
	art=panel.executor
	worker=host.simulation_worker
	dialog=bench._generated_dialog
	var graphics_ok := OS.get_environment("FLATTEN_REQUIRE_GRAPHICS")!="1" or DisplayServer.get_name()!="headless"
	var reopening := OS.get_environment("FLATTEN_REOPEN")=="1"
	if check(graphics_ok,"required graphical backend is active") and await until(ready,"real native Shared Workbench ready",180000):
		if reopening: await reopen()
		else: await author()
	check(completed,"all mandatory "+("reopen" if reopening else "author")+" phases completed")
	check(source_identity==identity(),"tested scripts and native runtime stayed unchanged")
	host.queue_free()
	await process_frame
	await process_frame
	print("FLATTEN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"phase":"reopen" if reopening else "author",
		"completed":completed,"side":side,"workers":workers,"canonical_bytes":side*side*2,"measurements":measurements,
		"phases":phases,"native_material_witnesses":witnesses,"source_identity":source_identity,
		"process_instance":process_instance,"pid":OS.get_process_id(),"elapsed_usec":Time.get_ticks_usec()-start_usec}))
	quit(0 if failures.is_empty() else 1)
