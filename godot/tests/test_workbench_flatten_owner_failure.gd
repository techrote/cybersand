extends SceneTree

## Actual mounted native-owner quarantine, followed by explicit authored Save.
## The companion invocation reopens in a separate, normal-capacity OS process.
## No failed World is captured, reset, recreated or read from the UI thread.
const Setup = preload("res://scripts/workbench_setup.gd")
const Baseline = preload("res://scripts/workbench_material_baseline.gd")
const CAPACITY_SETTING := "cybersand/native_active_core_capacity"
const SIDE := 512
const SaveName := "gen008-flatten-owner-failure"
const Expectation := "user://gen008-flatten-owner-failure-expectation.json"
const ExpectedPlane := "user://gen008-flatten-owner-failure-expected.u16le"

var host: Control
var bench: Control
var editor: Control
var panel: Window
var art: RefCounted
var worker: RefCounted
var checks := 0
var failures: Array[String] = []
var completed := false
var human_sequence := 0
var process_instance := Crypto.new().generate_random_bytes(16).hex_encode()
var source_identity: Dictionary = {}
var receipt: Dictionary = {}
var start_usec := 0
var fence_checks: Dictionary = {}
var timings: Dictionary = {}

func _initialize() -> void:
	start_usec = Time.get_ticks_usec()
	run.call_deferred()

func check(ok: bool,label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("FLATTEN_OWNER_FAILURE "+label)
	return ok

func until(predicate: Callable,label: String,limit_ms: int = 90000) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return check(false,label+" / "+str(bench.message if bench != null else "unmounted"))

func settled() -> bool:
	var paint: Dictionary = worker.paint_state()
	var agent: Dictionary = worker.art_state()
	return not editor.busy() and not art.active and not art.waiting and not panel.log_draw \
		and art.manual.is_empty() and art.manual_inflight.is_empty() \
		and not bool(paint.get("busy",false)) and not bool(paint.get("art_busy",false)) \
		and not bool(paint.get("legacy_busy",false)) and not bool(paint.get("transition_busy",false)) \
		and not bool(paint.get("flatten_busy",false)) and not agent.receipt_ready \
		and host.pending_microscenario_apply.is_empty() and not bench.step_pending and not bench.is_flatten_pending()

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() and settled()

func identity() -> Dictionary:
	var value := {"godot":Engine.get_version_info().string,"os":OS.get_name(),"display":DisplayServer.get_name()}
	for filename: String in ["scripts/main.gd","scripts/shared_workbench.gd","scripts/simulation_worker.gd","scripts/microscenario_host.gd",
		"scripts/workbench_setup.gd","scripts/workbench_material_baseline.gd","scripts/workbench_generated_map.gd",
		"scripts/workbench_paint_editor_controller.gd","scripts/workbench_paint_editor_executor.gd",
		"scripts/workbench_paint_editor_history.gd","scripts/art_batch_executor.gd",
		"tests/test_workbench_flatten.gd","tests/test_workbench_material_baseline.gd","tests/flatten_save_fault_child.gd",
		"tests/test_workbench_flatten_owner_failure.gd"]:
		value[filename] = FileAccess.get_sha256("res://"+filename)
	var native_name := "cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so"
	value.native_sha256 = FileAccess.get_sha256("res://addons/cybersand_native/bin/"+native_name)
	return value

func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func save_refused(label: String) -> bool:
	var absent := not FileAccess.file_exists(Setup._path(SaveName))
	var refused: bool = not bench.save_setup()
	fence_checks[label] = refused and absent and not FileAccess.file_exists(Setup._path(SaveName))
	return check(bool(fence_checks[label]),"Save preserves its "+label+" fence without creating a named start")

func capture(label: String,check_save_fence: bool = false) -> Dictionary:
	if not await until(settled,"native receipts settle before "+label): return {}
	if not check(not worker.has_failed(),"only a healthy native owner is captured: "+label): return {}
	var started := Time.get_ticks_usec()
	var admitted: Dictionary = worker.material_capture_request(int(worker.paint_state().generation))
	if not check(admitted.get("ok",false),"native material capture admitted: "+label): return {}
	var token := int(admitted.token)
	var packet: Dictionary = {}
	var deadline := Time.get_ticks_msec()+90000
	while packet.is_empty() and Time.get_ticks_msec()<deadline:
		packet = worker.material_capture_poll(token)
		if packet.is_empty(): await process_frame
	if not check(packet.get("ok",false),"complete native material packet: "+label):
		worker.material_capture_cancel(token)
		return {}
	if check_save_fence: save_refused("native_capture_lease")
	check(worker.material_capture_finish(token,false).get("ok",false),"read-only capture lease released: "+label)
	check(packet.get("extent")==Vector2i(SIDE,SIDE) and packet.cells.size()==SIDE*SIDE*2 \
		and packet.sha256==digest(packet.cells),"complete canonical native material plane: "+label)
	timings[label+"_capture_usec"] = Time.get_ticks_usec()-started
	return packet

func human(point: Vector2i,material: int,check_save_fence: bool = false) -> bool:
	human_sequence += 1
	if not check(editor.begin_deferred_brush(point,material,0,human_sequence),"manual brush admitted"): return false
	if check_save_fence: save_refused("pending_manual_edit")
	return await until(settled,"manual edit acknowledged") \
		and check(editor.last_receipt.get("status")=="completed","manual edit natively confirmed")

func draw(points: Array,check_save_fence: bool = false) -> bool:
	var admitted: Dictionary = art.submit([{"shape":"pixels","points":points,"material":58}],Rect2i(0,0,SIDE,SIDE),[],[0,58])
	if not check(admitted.get("status")=="queued","agent drawing admitted"): return false
	if check_save_fence: save_refused("pending_agent_edit")
	return await until(settled,"agent edit and history acknowledged") \
		and check(art.result.get("status")=="completed","agent edit natively confirmed")

func reverse(action: String) -> bool:
	if not check(editor.history_available(action),"chronological "+action+" is available"): return false
	if not check(editor.undo() if action=="undo" else editor.redo(),"chronological "+action+" admitted"): return false
	return await until(settled,"chronological "+action+" acknowledged")

func physical_identity() -> Dictionary:
	var value := {"session":0,"bodies":[]}
	if host.physical_actor_session==null: return value
	value.session = host.physical_actor_session.get_instance_id()
	for rig: Node2D in host.physical_actor_session._rigs:
		for body: RigidBody2D in rig.bodies():
			value.bodies.append([body.get_instance_id(),body.get_rid().get_id()])
	return value

func failure_snapshot() -> Dictionary:
	var snapshot = host.latest_snapshot
	return {"simulation_failed":snapshot.simulation_failed,"tick_failure_count":snapshot.tick_failure_count,
		"failed_tick_index":snapshot.failed_tick_index,"last_tick_error":snapshot.last_tick_error}

func retained_identity() -> Dictionary:
	var state: Dictionary = worker.paint_state()
	var history := {"undo":editor._undo_stack,"redo":editor._redo_stack,
		"fence":editor._history_fence,"agent":editor._agent_history}
	return {"host_instance":host.get_instance_id(),"worker_instance":worker.get_instance_id(),
		"physical":physical_identity(),"generation":int(state.generation),
		"authoring_generation":int(state.authoring_generation),"paint_epoch":int(state.epoch),
		"agent_epoch":int(worker.art_state().epoch),"tick":int(state.tick),"revision":int(state.revision),
		"failure_snapshot":failure_snapshot(),"has_failed":worker.has_failed(),
		"setup_sha256":digest(var_to_bytes(bench.applied)),"baseline_sha256":digest(bench._material_baseline.cells),
		"baseline_bytes":bench._material_baseline.cells.size(),"history_sha256":digest(var_to_bytes(history)),
		"undo_entries":editor._undo_stack.size(),"redo_entries":editor._redo_stack.size()}

func apply_rectangles(bytes: PackedByteArray,rectangles: Array) -> bool:
	for box: Array in rectangles:
		if not check(box.size()==5,"fixture and saved overlays retain exact material rectangles"): return false
		for y: int in range(int(box[1]),int(box[1])+int(box[3])):
			for x: int in range(int(box[0]),int(box[0])+int(box[2])):
				bytes.encode_u16((y*SIDE+x)*2,int(box[4]))
	return true

func author() -> void:
	bench._name.text = SaveName
	if not check(not FileAccess.file_exists(Setup._path(SaveName)),"author begins with no prior named recovery save"): return
	var candidate: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(SIDE,SIDE))
	candidate.actors = [Setup.instance("midge",1,Vector2(240,120))]
	candidate.next_id = 2
	candidate.selected = 1
	candidate.edits = [[36,36,9,9,2],[436,36,9,9,14],[300,400,20,4,58]]
	var initial := PackedByteArray()
	initial.resize(SIDE*SIDE*2)
	if not apply_rectangles(initial,candidate.edits): return
	if not check(bench.apply(candidate),"prepare actual capacity-one native World with an actor and separated active piles"): return
	save_refused("prepared_transaction")
	if not await until(ready,"prepared physical owner installs",180000): return
	var original := await capture("before_flatten",true)
	if not check(not original.is_empty() and original.cells==initial,"all native IDs equal the independently authored construction"): return
	var started := Time.get_ticks_usec()
	if not check(bench.request_flatten().get("ok",false),"healthy Flatten admitted"): return
	save_refused("pending_flatten")
	if not await until(ready,"healthy Flatten completes"): return
	timings.flatten_usec = Time.get_ticks_usec()-started
	if not check(bench.get_flatten_status().status=="complete" and bench._material_baseline.cells==initial \
		and bench.applied.edits.is_empty() and bench._generated_active.is_empty(),"healthy Flatten replaces only earlier construction history"): return
	if not await human(Vector2i(100,100),131,true): return
	if not await human(Vector2i(300,400),0): return
	if not await draw([[200,100],[201,100]],true): return
	var expected := initial.duplicate()
	for value: Array in [[100,100,131],[300,400,0],[200,100,58],[201,100,58]]:
		expected.encode_u16((int(value[1])*SIDE+int(value[0]))*2,int(value[2]))
	var before_fault := await capture("before_fault")
	if not check(not before_fault.is_empty() and before_fault.cells==expected,"complete pre-fault native plane equals baseline plus independently acknowledged manual and agent edits"): return
	check(editor._undo_stack.size()>=3,"post-Flatten manual and agent operations entered chronological history")
	receipt.expected_plane_sha256 = digest(expected)
	receipt.pre_fault_native_plane_sha256 = digest(before_fault.cells)
	receipt.saved_baseline_sha256 = digest(initial)
	receipt.history_entries_before_fault = editor._undo_stack.size()
	started = Time.get_ticks_usec()
	if not check(bench.step_once(),"request one real native simulation tick"): return
	save_refused("pending_step")
	if not await until(func() -> bool: return worker.has_failed() and host.latest_snapshot.simulation_failed,
		"actual capacity exhaustion publishes failed-owner quarantine"): return
	if not await until(settled,"failed owner settles all edit and step fences"): return
	timings.native_failure_usec = Time.get_ticks_usec()-started
	var failed := failure_snapshot()
	if not check(failed.simulation_failed and int(failed.tick_failure_count)==1 and int(failed.failed_tick_index)>0 \
		and str(failed.last_tick_error).contains("active scheduling-core capacity exhausted"),"actual native capacity fault records the exact failure class and single failure count"): return
	receipt.failure_snapshot = failed
	receipt.failure_reason = failed.last_tick_error
	receipt.failure_count = failed.tick_failure_count
	# Running simulation can invalidate session-local Undo, as before Flatten.
	# Preserve the settled post-fault history across every recovery action below.
	for frame: int in 3: await process_frame
	var retained := retained_identity()
	var refused: Dictionary = bench.request_flatten()
	fence_checks.failed_flatten = not bool(refused.get("ok",false)) \
		and str(refused.get("reason","")).contains("Native owner failed") \
		and str(refused.get("reason","")).contains("Save the settled authored start")
	check(bool(fence_checks.failed_flatten),"failed Flatten explains Save, restart and Load rather than asking for an endless wait")
	fence_checks.failed_reset = not bench.reset_selected() and bench.message.contains("Save the settled authored start")
	fence_checks.failed_restore = not bench.restore_start() and bench.message.contains("Save the settled authored start")
	check(bool(fence_checks.failed_reset) and bool(fence_checks.failed_restore) \
		and not host._playable_recovery_queued,"failed-owner Reset and Restore refuse destructive incomplete reconstruction")
	check(retained_identity()==retained,"failed Flatten, Reset and Restore preserve owner, baseline, acknowledged edits and supported history")
	# Fixture-only intended legacy recipe, deliberately never sent to native.
	# A settled legacy slot cannot prove this four-field instruction executed.
	bench.applied.edits.append([310,110,0,58])
	var uncertain := retained_identity()
	save_refused("unconfirmed_legacy_recipe")
	check(bench.message.contains("Legacy brush execution cannot be confirmed") and retained_identity()==uncertain,
		"uncertain legacy recipe refusal preserves its complete document and explains the missing acknowledgement")
	bench.applied.edits.pop_back()
	check(retained_identity()==retained,"removing only the fixture entry restores the acknowledged authored document")
	receipt.owner_before_save = retained_identity()
	started = Time.get_ticks_usec()
	if not check(bench.save_setup(),"explicit Save persists settled authored data after actual native quarantine"): return
	timings.save_usec = Time.get_ticks_usec()-started
	receipt.owner_after_save = retained_identity()
	receipt.owner_preserved = receipt.owner_before_save==receipt.owner_after_save
	check(receipt.owner_preserved and not host._playable_recovery_queued,"Save preserves the same failed native owner, generation, physical session, failure counters and authored history")
	check(bench.message.contains("Native owner remains failed") and bench.message.contains("runtime state was not captured"),
		"Save clearly distinguishes authored recovery from a runtime checkpoint")
	var saved: Dictionary = Baseline.read_named(SaveName)
	if not check(saved.get("flattened",false) and saved.baseline.cells==initial \
		and saved.setup==bench.applied and not saved.has("generation"),"saved standalone baseline and acknowledged edits require no retired construction recipe"): return
	var saved_plane: PackedByteArray = saved.baseline.cells.duplicate()
	if not apply_rectangles(saved_plane,saved.setup.edits): return
	receipt.saved_plane_sha256 = digest(saved_plane)
	if not check(saved_plane==expected,"independently decoded saved material plane equals every pre-fault native ID"): return
	receipt.saved_file_sha256 = FileAccess.get_sha256(Setup._path(SaveName))
	var bytes_file := FileAccess.open(ExpectedPlane,FileAccess.WRITE)
	if not check(bytes_file!=null,"create independent complete expected-plane witness"): return
	bytes_file.store_buffer(expected)
	bytes_file.close()
	var expectation := receipt.duplicate(true)
	expectation.author_instance = process_instance
	expectation.author_pid = OS.get_process_id()
	expectation.source_identity = source_identity
	expectation.setup = JSON.parse_string(JSON.stringify(bench.applied))
	var metadata := FileAccess.open(Expectation,FileAccess.WRITE)
	if not check(metadata!=null,"create fresh-process recovery expectation"): return
	metadata.store_string(JSON.stringify(expectation))
	metadata.close()
	completed = failures.is_empty()

func reopen() -> void:
	var file := FileAccess.open(Expectation,FileAccess.READ)
	if not check(file!=null,"terminated author process left a recovery expectation"): return
	var expected: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	if not check(expected.author_instance!=process_instance and int(expected.author_pid)!=OS.get_process_id(),
		"recovery runs in a distinct fresh OS process"): return
	if not check(expected.source_identity==source_identity,"fresh recovery uses the same source and native binary"): return
	var bytes := FileAccess.get_file_as_bytes(ExpectedPlane)
	if not check(bytes.size()==SIDE*SIDE*2 and digest(bytes)==expected.expected_plane_sha256 \
		and expected.expected_plane_sha256==expected.pre_fault_native_plane_sha256 \
		and expected.expected_plane_sha256==expected.saved_plane_sha256,"complete expectation agrees with native truth and decoded authored save"): return
	for key: String in ["expected_plane_sha256","pre_fault_native_plane_sha256","saved_baseline_sha256","saved_plane_sha256",
		"saved_file_sha256","failure_snapshot","failure_reason","failure_count"]:
		receipt[key] = expected[key]
	check(FileAccess.get_sha256(Setup._path(SaveName))==expected.saved_file_sha256,"fresh process reads exactly the save written after quarantine")
	bench._name.text = SaveName
	var started := Time.get_ticks_usec()
	if not check(bench.load_setup(),"normal explicit Load admits the material-only authored recovery save"): return
	if not await until(ready,"normal-capacity fresh native owner loads the saved baseline",180000): return
	timings.load_usec = Time.get_ticks_usec()-started
	var actual := await capture("fresh_reconstruction")
	if not check(not actual.is_empty() and actual.cells==bytes,"every reconstructed native material ID equals the saved baseline plus acknowledged edits"): return
	receipt.reconstructed_plane_sha256 = digest(actual.cells)
	check(bench._material_baseline.sha256==expected.saved_baseline_sha256 and bench._generated_active.is_empty(),
		"fresh Load reconstructs independently of discarded generation or construction history")
	check(JSON.parse_string(JSON.stringify(bench.applied))==expected.setup and not bench.body_state(1).is_empty(),
		"actor identity, spawn and supported configuration survive authored recovery")
	check(not worker.has_failed() and int(worker.paint_state().tick)==0 and host.paused,
		"fresh Load uses healthy initial runtime state, not the failed simulation checkpoint")
	check(editor._undo_stack.is_empty() and editor._redo_stack.is_empty(),"fresh Load does not resurrect retired session-local Undo")
	if not await human(Vector2i(110,110),131): return
	if not await draw([[210,110]]): return
	if not await reverse("undo") or not await reverse("undo"): return
	var undone := await capture("continued_undo")
	if not check(not undone.is_empty() and undone.cells==bytes,"chronological agent and manual Undo return exactly to the saved recovery plane"): return
	if not await reverse("redo") or not await reverse("redo"): return
	var after := bytes.duplicate()
	after.encode_u16((110*SIDE+110)*2,131)
	after.encode_u16((110*SIDE+210)*2,58)
	var continued := await capture("continued_redo")
	receipt.continued_authoring = not continued.is_empty() and continued.cells==after
	check(receipt.continued_authoring,"manual/agent editing and chronological Redo continue on the new healthy owner")
	check(FileAccess.get_sha256(Setup._path(SaveName))==expected.saved_file_sha256,"continued authoring never automatically overwrites the recovery save")
	completed = failures.is_empty()

func run() -> void:
	var reopening := OS.get_environment("FLATTEN_OWNER_FAILURE_REOPEN")=="1"
	source_identity = identity()
	set_meta("cybersand_feature","shared_workbench")
	var previous: Variant = ProjectSettings.get_setting(CAPACITY_SETTING,null)
	if not reopening: ProjectSettings.set_setting(CAPACITY_SETTING,1)
	host = load("res://main.tscn").instantiate()
	ProjectSettings.set_setting(CAPACITY_SETTING,previous)
	root.add_child(host)
	current_scene = host
	root.size = Vector2i(1440,1000)
	bench = host.shared_workbench
	editor = bench.paint_editor
	panel = bench.art_batches
	art = panel.executor
	worker = host.simulation_worker
	var graphics_ok := OS.get_environment("FLATTEN_REQUIRE_GRAPHICS")!="1" or DisplayServer.get_name()!="headless"
	if check(graphics_ok,"required graphical backend is active") and await until(ready,"real Shared Workbench installed",180000):
		if reopening: await reopen()
		else: await author()
	check(completed,"all mandatory "+("reopen" if reopening else "author")+" recovery phases completed")
	check(source_identity==identity(),"tested scripts and native runtime remain source matched")
	receipt.merge({"schema":"gen008-flatten-owner-failure-v1","phase":"reopen" if reopening else "author",
		"completed":completed,"checks":checks,"failures":failures,"process_instance":process_instance,
		"pid":OS.get_process_id(),"source_identity":source_identity,"side":SIDE,"canonical_bytes":SIDE*SIDE*2,
		"fence_checks":fence_checks,"timings":timings,"elapsed_usec":Time.get_ticks_usec()-start_usec})
	current_scene = null
	host.queue_free()
	await process_frame
	await process_frame
	print("FLATTEN_OWNER_FAILURE_RESULT ",JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
