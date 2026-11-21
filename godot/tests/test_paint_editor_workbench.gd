extends SceneTree

# Mounted ordinary Workbench gestures, native ACK and a fresh-process save.
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	var startup_observer: Callable
	func _actor_window_has_focus() -> bool: return true
	func _process(delta: float) -> void:
		if startup_observer.is_valid(): startup_observer.call("main_enter")
		super._process(delta)
		if startup_observer.is_valid(): startup_observer.call("main_exit")
var host: Control
var bench: Control
var editor: Control
var checks := 0
var failures: Array[String] = []
var maximum_frame_gap_usec := 0
var last_frame_usec := 0
var frame_gaps_usec: Array[int] = []
const SAVE_NAME := "paint001-mounted-acceptance"
# Initial-readiness evidence only. These observations neither extend a deadline
# nor admit a late predicate. No image readback or additional worker API is used.
const STARTUP_EVENT_LIMIT := 256
const STARTUP_FIRST_EVENTS := 64
var startup_active := false
var startup_terminal_probe := false
var startup: Dictionary = {}
var startup_events: Array[Dictionary] = []
var startup_event_count := 0
var startup_await_begin: Dictionary = {}
var startup_main_begin: Dictionary = {}
var startup_draw_begin: Dictionary = {}

func _startup_main_state() -> Dictionary:
	var state := {"host_valid":is_instance_valid(host),"fresh_worker_state":"not additionally queried"}
	if not is_instance_valid(host): return state
	state.merge({"worker_start_error":host.worker_start_error,"rapier_start_error":host.rapier_start_error,
		"pending_apply":not host.pending_microscenario_apply.is_empty(),
		"pending_request_serial":int(host.pending_microscenario_apply.get("serial",0)),
		"prepared_owner":host._pending_physical_candidate != null,"prepared_ready_sent":host._prepared_physical_ready_sent,
		"owner_epoch":host._physical_epoch,"owner_present":host.physical_actor_session != null,
		"consumed_snapshot_serial":host.consumed_snapshot_serial,
		"uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"uploaded_generation":host.last_uploaded_world_generation,"uploaded_revision":host.last_uploaded_revision,
		"microscenario_error":host.microscenario_error})
	var mounted: Control = host.shared_workbench
	if is_instance_valid(mounted):
		state.merge({"applied":not mounted.applied.is_empty(),"step_pending":mounted.step_pending,
			"flatten_pending":mounted.is_flatten_pending(),"editor_busy":mounted.paint_editor != null and mounted.paint_editor.busy(),
			"bench_message":mounted.message,"authored_actors":mounted.applied.get("actors",[]).size()})
	var snapshot: RefCounted = host.latest_snapshot
	state["main_snapshot"] = {"available":snapshot != null,"scope":"last Main-consumed immutable publication"}
	if snapshot != null:
		state.main_snapshot.merge({"serial":snapshot.serial,"published_usec":snapshot.published_usec,
			"worker_handoff_usec":snapshot.worker_handoff_usec,"world_generation":snapshot.render_world_generation,
			"world_revision":snapshot.world_revision,"simulation_revision":snapshot.simulation_world_revision,
			"native_tick":snapshot.tick_index,"simulation_failed":snapshot.simulation_failed,"last_tick_error":snapshot.last_tick_error,
			"request_serial":int(snapshot.lab_context.get("scenario_request_serial",0)),
			"request_applied":bool(snapshot.lab_context.get("scenario_request_applied",false))})
	return state

func _startup_material_state() -> Dictionary:
	var started := Time.get_ticks_usec()
	if not is_instance_valid(host) or not host.has_method("material_publication_status"):
		return {"available":false,"observation_started_usec":started,"observation_finished_usec":Time.get_ticks_usec()}
	# This getter returns local counters, formats and existing Resource RIDs.
	# It performs no texture readback, fence, update or worker query.
	var result: Dictionary = host.material_publication_status()
	result["available"] = true
	result["current_texture_rid"] = host.texture.get_rid().get_id() if host.texture != null else 0
	result["previous_texture_rid"] = host.previous_texture.get_rid().get_id() if host.previous_texture != null else 0
	result["world_extent"] = [host.world_extent.x,host.world_extent.y]
	result["render_channels"] = host.render_channels
	result["paused"] = host.paused
	result["uploaded_world_generation"] = host.last_uploaded_world_generation
	result["uploaded_revision"] = host.last_uploaded_revision
	result["uploaded_render_serial"] = host.last_uploaded_render_snapshot_serial
	var snapshot: RefCounted = host.latest_snapshot
	result["startup_snapshot"] = {"available":snapshot != null}
	if snapshot != null:
		result.startup_snapshot.merge({"serial":snapshot.serial,"world_generation":snapshot.render_world_generation,
			"native_tick":snapshot.tick_index,"render_serial":snapshot.render_snapshot_serial,
			"render_tick":snapshot.render_tick_index,"simulation_revision":snapshot.simulation_world_revision,
			"backend_name":snapshot.backend_name,"native_worker_request":snapshot.native_worker_request,
			"scheduler_thread_capacity_hint":snapshot.scheduler_thread_capacity_hint})
	result["observation_scope"] = "local material publication metadata; no GPU completion or readback"
	result["observation_started_usec"] = started
	result["observation_finished_usec"] = Time.get_ticks_usec()
	return result

func _startup_mark(stage: String, values: Dictionary = {}) -> void:
	if not startup_active: return
	var row := {"event":stage,"sequence":startup_event_count,"time_usec":Time.get_ticks_usec(),
		"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames()}
	row.merge(values)
	if stage in ["main_enter","main_exit"]: row["state"] = _startup_main_state()
	startup_event_count += 1
	if startup_events.size() < STARTUP_EVENT_LIMIT: startup_events.append(row)
	else:
		var slot := STARTUP_FIRST_EVENTS+(startup_event_count-1-STARTUP_EVENT_LIMIT) % (STARTUP_EVENT_LIMIT-STARTUP_FIRST_EVENTS)
		startup_events[slot] = row
	var first: Dictionary = startup.first
	if not first.has(stage):
		if stage in ["host_add_end","main_enter","main_exit","frame_pre_draw"]:
			row["material_publication"] = _startup_material_state()
			if not startup.has("first_material_publications"): startup["first_material_publications"] = {}
			# Four fixed entries survive any later first/tail event-ring rollover.
			startup.first_material_publications[stage] = {"event":stage,"sequence":row.sequence,
				"time_usec":row.time_usec,"process_frame":row.process_frame,"physics_frame":row.physics_frame,
				"material_publication":row.material_publication}
		first[stage] = row.time_usec
		# A hung first callback/read still leaves its preceding boundary in the
		# subprocess log. Later boundaries remain in the bounded in-memory tail.
		if stage in ["host_add_begin","host_add_end","wait_begin","main_enter","main_exit","frame_pre_draw","frame_post_draw","timeout_before_diagnostic"]:
			print("PAINT_STARTUP_CHECKPOINT ",JSON.stringify(row))
	if stage == "await_begin": startup_await_begin = row
	elif stage == "await_end" and not startup_await_begin.is_empty():
		_startup_span("largest_await",startup_await_begin,row)
	elif stage == "main_enter": startup_main_begin = row
	elif stage == "main_exit" and not startup_main_begin.is_empty():
		_startup_span("largest_main_callback",startup_main_begin,row)
	elif stage == "frame_pre_draw": startup_draw_begin = row
	elif stage == "frame_post_draw" and not startup_draw_begin.is_empty():
		_startup_span("largest_draw_span",startup_draw_begin,row)

func _startup_span(key: String, begin: Dictionary, end: Dictionary) -> void:
	var duration: int = int(end.time_usec)-int(begin.time_usec)
	if duration > int(startup.get(key,{}).get("duration_usec",-1)):
		startup[key] = {"duration_usec":duration,"begin":begin,"end":end,
			"scope":"wall span including observer and first-checkpoint output" if key=="largest_main_callback"
				else ("pre/post-draw signal-delivery span; not GPU-exclusive" if key=="largest_draw_span" else "await wall span") }

func _startup_process_frame() -> void: _startup_mark("process_frame")
func _startup_pre_draw() -> void: _startup_mark("frame_pre_draw")
func _startup_post_draw() -> void: _startup_mark("frame_post_draw")

func _startup_ready_result(value: bool, observation: Dictionary) -> bool:
	observation["ready"] = value
	observation["finished_usec"] = Time.get_ticks_usec()
	startup["last_ready_observation"] = observation
	_startup_mark("ready_true" if value else "ready_false",{"observation":observation})
	return value

func _finish_startup(passed: bool) -> void:
	_startup_mark("finished",{"passed":passed,"state":_startup_main_state()})
	startup_active = false
	if is_instance_valid(host): host.startup_observer = Callable()
	process_frame.disconnect(_startup_process_frame)
	RenderingServer.frame_pre_draw.disconnect(_startup_pre_draw)
	RenderingServer.frame_post_draw.disconnect(_startup_post_draw)
	startup_events.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.sequence)<int(b.sequence))
	startup.merge({"passed":passed,"finished_usec":Time.get_ticks_usec(),"events":startup_events,
		"event_count":startup_event_count,"retained_event_count":startup_events.size(),
		"discarded_event_count":startup_event_count-startup_events.size(),
		"test_sha256":FileAccess.get_sha256(get_script().resource_path)})
	var output := OS.get_environment("PAINT_STARTUP_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(startup)+"\n"); file.close()
		else: push_error("PAINT startup receipt could not be written: "+output)
	print("PAINT_STARTUP_LIFECYCLE ",JSON.stringify(startup))

func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if last_frame_usec>0:
		var gap_usec: int = now-last_frame_usec
		maximum_frame_gap_usec=maxi(maximum_frame_gap_usec,gap_usec)
		if frame_gaps_usec.size()<200000: frame_gaps_usec.append(gap_usec)
	last_frame_usec=now
	_startup_mark("scene_tree_process")
	return false
func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:
		failures.append(label)
		push_error("PAINT_EDITOR_WORKBENCH "+label)
	return ok
func until(predicate: Callable,label: String,limit_ms: int=30000) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	var observing: bool = startup_active and label == "ordinary Workbench installed"
	if observing:
		startup.merge({"limit_ms":limit_ms,"wait_started_usec":Time.get_ticks_usec(),"deadline_msec":deadline})
		_startup_mark("wait_begin",{"state":_startup_main_state()})
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if observing: _startup_mark("await_begin")
		await process_frame
		if observing: _startup_mark("await_end")
	if observing:
		startup["timed_out"] = true
		_startup_mark("timeout_before_diagnostic",{"state":_startup_main_state()})
		startup_terminal_probe = true
		startup["terminal_ready"] = bool(predicate.call())
		startup_terminal_probe = false
		_startup_mark("timeout_after_diagnostic",{"terminal_ready":startup.terminal_ready})
	# A true late observation does not establish when readiness became true.
	# It must never turn the unchanged deadline-first failure into success.
	return check(false,label+" / "+str(bench.message))
func ready() -> bool:
	if not startup_active:
		return not bench.applied.is_empty() and not bench.busy() and not host.simulation_worker.paint_state().busy
	var observation := {"started_usec":Time.get_ticks_usec(),"terminal_diagnostic":startup_terminal_probe,
		"main_state":_startup_main_state(),"bench_busy":"not reached","paint_state":"not reached"}
	_startup_mark("ready_begin",{"terminal_diagnostic":startup_terminal_probe})
	# Preserve the original short-circuit order and exactly its worker reads.
	if bench.applied.is_empty(): return _startup_ready_result(false,observation)
	_startup_mark("bench_busy_begin")
	var bench_busy: bool = bench.busy()
	observation.bench_busy = bench_busy
	_startup_mark("bench_busy_end",{"busy":bench_busy})
	if bench_busy: return _startup_ready_result(false,observation)
	_startup_mark("paint_state_begin")
	var state: Dictionary = host.simulation_worker.paint_state()
	var compact := {}
	for key: String in ["busy","generation","revision","tick","epoch","authoring_generation","paused","error",
			"executing","queued","receipt_ready","art_busy","legacy_busy","transition_busy","flatten_busy"]:
		if state.has(key): compact[key] = state[key]
	observation.paint_state = compact
	_startup_mark("paint_state_end",{"paint_state":compact})
	return _startup_ready_result(not bool(state.busy),observation)
func settled() -> bool:
	return not editor.busy() and not host.simulation_worker.paint_state().busy
func local(cell: Vector2i) -> Vector2:
	var area: Rect2=host.view_content_rect()
	return area.position+(Vector2(cell)+Vector2(0.5,0.5)-Vector2(host.presentation_camera_origin()))*area.size/Vector2(host.current_view_size)
func gesture(tool: String,from: Vector2i,to: Vector2i,id: int=58,button: int=MOUSE_BUTTON_LEFT) -> void:
	editor.tools.select(editor.TOOLS.find(tool))
	bench._tool.select(0)
	editor.select_material(id)
	var press := InputEventMouseButton.new()
	press.button_index=button; press.pressed=true; press.position=local(from)
	bench._world_input(press)
	var move := InputEventMouseMotion.new()
	move.position=local(to); move.relative=move.position-press.position
	bench._world_input(move)
	var release := InputEventMouseButton.new()
	release.button_index=button; release.pressed=false; release.position=local(to)
	bench._world_input(release)
	await until(settled,tool+" completes")
func capture(region: Rect2i) -> PackedInt32Array:
	var worker: RefCounted=host.simulation_worker
	var state: Dictionary=worker.paint_state()
	var admission: Dictionary=worker.paint_queue({"kind":"capture","region":region,
		"expected_generation":int(state.generation),"expected_revision":int(state.revision),"expected_tick":int(state.tick)})
	if not check(admission.status=="queued","independent native capture queued"): return PackedInt32Array()
	if not await until(func()->bool:return worker.paint_state().receipt_ready,"independent capture receipt"): return PackedInt32Array()
	var receipt: Dictionary=worker.paint_take_result()
	check(receipt.status=="completed","independent native capture complete")
	return receipt.get("materials",PackedInt32Array())
func frame(label: String) -> void:
	var folder := OS.get_environment("PAINT_CAPTURE_DIR")
	if folder.is_empty(): return
	DirAccess.make_dir_recursive_absolute(folder)
	await until(func()->bool:return host.last_uploaded_revision==int(host.simulation_worker.paint_state().revision),"render matches native edit")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(label+".png"))==OK,"graphical framebuffer "+label)

func author() -> void:
	var fresh: Dictionary=Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	check(bench.apply(fresh),"512 blank request")
	if not await until(ready,"512 blank installed"): return
	bench._set_view(Vector2.ZERO,Vector2i(480,270))
	await process_frame
	check(editor.get_parent()==bench and editor._overlay.get_parent()==host.world_view,"toolbar and overlay mounted")
	check(bench._material.item_count==131,"complete native palette without reserved10")
	bench._brush.value=0
	await gesture("Rectangle",Vector2i(40,40),Vector2i(47,47),58)
	check(editor.last_receipt.get("status")=="completed","native completion")
	check(editor.last_receipt.get("applied")==64,"one gesture is one64-cell action")
	await gesture("Rectangle",Vector2i(44,40),Vector2i(47,43),3)
	await gesture("Brush",Vector2i(40,40),Vector2i(40,40),58,MOUSE_BUTTON_RIGHT)
	await gesture("Line",Vector2i(50,55),Vector2i(70,63),77)
	await gesture("Outline",Vector2i(80,40),Vector2i(90,50),81)
	var outline: PackedInt32Array=await capture(Rect2i(80,40,11,11))
	check(outline.size()==121 and outline[0]==81 and outline[60]==0,"outline preserves interior")
	var source: PackedInt32Array=await capture(Rect2i(40,40,8,8))
	check(source.size()==64 and source[0]==0 and source[4]==3 and source[63]==58,"mixed native source")
	await gesture("Select",Vector2i(40,40),Vector2i(47,47))
	check(editor.selection==Rect2i(40,40,8,8),"selection rectangle")
	check(editor.copy_selection(),"Copy accepted")
	await until(settled,"native copy completes")
	check(editor.clipboard.get("materials")==source,"exact clipboard IDs")
	editor.select_tool("Paste")
	check(editor.tool_name()=="Paste","Paste selected")
	var previous: PackedInt32Array=await capture(Rect2i(44,44,8,8))
	check(editor.paste_at(Vector2i(44,44)),"overlapping paste accepted")
	await until(settled,"paste completes")
	check(await capture(Rect2i(44,44,8,8))==source,"overlap uses immutable capture")
	check(editor.undo(),"Undo accepted")
	await until(settled,"Undo completes")
	check(await capture(Rect2i(44,44,8,8))==previous,"Undo exact prior materials")
	check(editor.redo(),"Redo accepted")
	await until(settled,"Redo completes")
	check(await capture(Rect2i(44,44,8,8))==source,"Redo exact mixed paste")
	await gesture("Outline",Vector2i(100,80),Vector2i(130,110),58)
	editor.selection=Rect2i()
	editor.select_material(2)
	# Cancel after a capture has completed, before its receipt is consumed.
	# Stop must retire the Fill continuation as well as the native capture;
	# an already-published successful read must never launch new writes later.
	editor.set_process(false)
	check(editor.fill_at(Vector2i(110,90)),"cancellable fill capture accepted")
	if not await until(func()->bool:return host.simulation_worker.paint_state().receipt_ready,
			"fill capture completed before Cancel"):
		editor.set_process(true)
		return
	var edits_before_cancel: Array=bench.applied.edits.duplicate(true)
	var history_before_cancel: int=editor._undo_stack.size()
	editor.cancel()
	editor.set_process(true)
	if not await until(settled,"cancelled fill receipt retires"): return
	check(await capture(Rect2i(101,81,29,29))==_empty_materials(29*29),
		"Cancel after capture receipt prevents every later Fill write")
	check(bench.applied.edits==edits_before_cancel and editor._undo_stack.size()==history_before_cancel,
		"cancelled Fill retains exact authored history")
	check(editor.fill_at(Vector2i(110,90)),"bounded fill capture accepted")
	await until(settled,"bounded fill completes")
	var filled: PackedInt32Array=await capture(Rect2i(100,80,31,31))
	check(filled.size()==961 and filled[0]==58 and filled[32]==2 and filled[480]==2,"fill leaves boundary intact")
	# The 309-cell-wide pocket exceeds the default 256-wide source capture.
	# Automatic expansion must find both walls before any native write.
	await gesture("Outline",Vector2i(160,218),Vector2i(468,260),58)
	editor.selection=Rect2i()
	editor.select_material(2)
	check(editor.fill_at(Vector2i(300,239)),"large watertight fill capture accepted")
	await until(settled,"adaptive native fill completes",120000)
	var expanded_fill: PackedInt32Array=await capture(Rect2i(165,235,3,3))
	check(expanded_fill==PackedInt32Array([2,2,2,2,2,2,2,2,2]),
		"large watertight fill extends beyond first 256-cell capture")
	bench._set_view(Vector2(24,20),Vector2i(240,135))
	await process_frame
	check(editor.local_to_cell(local(Vector2i(160,90)))==Vector2i(160,90),"pan/zoom pointer mapping exact")
	await gesture("Rectangle",Vector2i(160,90),Vector2i(162,92),131)
	var mapped: PackedInt32Array=await capture(Rect2i(160,90,3,3))
	check(mapped.size()==9 and mapped.count(131)==9,"pan/zoom edits intended native cells")
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=local(Vector2i(190,100))
	bench._world_input(press)
	var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	bench._input(escape)
	check(not editor.dragging and host.paused,"Escape cancels without unpausing")
	check(await capture(Rect2i(190,100,1,1))==PackedInt32Array([0]),"cancelled preview never writes")
	bench._set_view(Vector2.ZERO,Vector2i(480,270))
	await process_frame
	# Useful map-scale features exceed the original4096 single-command cap.
	await gesture("Rectangle",Vector2i(230,180),Vector2i(439,183),58)
	await gesture("Rectangle",Vector2i(230,60),Vector2i(233,179),58)
	await gesture("Rectangle",Vector2i(330,60),Vector2i(333,179),58)
	await gesture("Rectangle",Vector2i(234,134),Vector2i(329,179),3)
	check(editor.last_receipt.get("applied")==4416,"large water rectangle uses acknowledged chunks")
	await gesture("Rectangle",Vector2i(240,95),Vector2i(275,133),2)
	await gesture("Rectangle",Vector2i(320,60),Vector2i(323,133),28)
	await gesture("Select",Vector2i(230,90),Vector2i(333,183))
	check(editor.copy_selection(),"map-scale structure copied")
	await until(settled,"large copy complete")
	editor.select_tool("Paste")
	editor.cursor=Vector2i(350,90)
	await frame("paint001-mixed-stamp-preview")
	check(editor.paste_at(Vector2i(350,90)),"map-scale mixed paste")
	await until(settled,"large paste complete")
	editor.select_tool("Select")
	editor.selection=Rect2i(350,90,104,94)
	await frame("paint001-mounted-editor")
	bench._name.text=SAVE_NAME
	check(bench.save_setup(),"acknowledged edits saved")
	check(bench.applied.edits.size()<Setup.MAX_STAMPS,"construction capacity explicit")
	check(bench.toggle_pause(),"play after edits")
	await until(func()->bool:return int(host.simulation_worker.paint_state().tick)>0,"native tick advanced")
	check(bench.toggle_pause(),"pause again")
	await process_frame
	check(not editor.undo(),"simulation invalidates undo")
	# A partial, unsavable suffix must not become saveable by changing settings
	# or placing an actor through the retained-World installation path.
	var held_generation: int=int(host.simulation_worker.paint_state().generation)
	editor._save_hold=true
	check(not bench.apply(bench.applied.duplicate(true),true),"retained installation refuses unsaved partial paint")
	check(editor.recovery_required() and int(host.simulation_worker.paint_state().generation)==held_generation,
		"retained refusal preserves recovery hold and native generation")
	check(not bench.save_setup(),"recovery hold still blocks saving")
	check(bench.apply(bench.applied.duplicate(true),false),"authored-start restore remains available")
	await until(ready,"recovery restore installed")
	check(not editor.recovery_required(),"complete authored-start replacement releases recovery hold")

func _empty_materials(count: int) -> PackedInt32Array:
	var values := PackedInt32Array()
	values.resize(count)
	values.fill(0)
	return values

func reopen() -> void:
	bench._name.text=SAVE_NAME
	check(bench.load_setup(),"fresh-process named load")
	if not await until(ready,"saved start installed"): return
	var mapped: PackedInt32Array=await capture(Rect2i(160,90,3,3))
	check(mapped.size()==9 and mapped.count(131)==9,"fresh-process extended material persists")
	var pasted: PackedInt32Array=await capture(Rect2i(44,44,8,8))
	check(pasted.size()==64 and pasted[0]==0 and pasted[4]==3 and pasted[63]==58,"fresh-process mixed paste and Empty persist")
	var fill: PackedInt32Array=await capture(Rect2i(110,90,2,2))
	check(fill==PackedInt32Array([2,2,2,2]),"fresh-process fill persists")
	bench._set_view(Vector2.ZERO,Vector2i(480,270))
	await process_frame
	await gesture("Line",Vector2i(200,100),Vector2i(215,105),7)
	check(editor.last_receipt.get("status")=="completed","continued editing after reopen")

func run() -> void:
	startup = {"schema":"paint-startup-lifecycle-v1","source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"reopen":OS.get_environment("PAINT_REOPEN"),"started_usec":Time.get_ticks_usec(),
		"default_limit_ms":30000,"timed_out":false,"terminal_ready":null,"first":{}}
	startup_active = true
	process_frame.connect(_startup_process_frame)
	RenderingServer.frame_pre_draw.connect(_startup_pre_draw)
	RenderingServer.frame_post_draw.connect(_startup_post_draw)
	_startup_mark("run_enter")
	set_meta("cybersand_feature","shared_workbench")
	_startup_mark("host_instantiate_begin")
	host=load("res://main.tscn").instantiate()
	_startup_mark("host_instantiate_end")
	host.set_script(FocusHost)
	host.startup_observer = _startup_mark
	_startup_mark("host_add_begin")
	root.add_child(host)
	_startup_mark("host_add_end")
	root.size=Vector2i(1440,1000)
	_startup_mark("root_resized")
	bench=host.shared_workbench
	editor=bench.paint_editor
	var initial_ready: bool = await until(ready,"ordinary Workbench installed",60000)
	_finish_startup(initial_ready)
	if check(initial_ready,"ordinary Workbench ready"):
		last_frame_usec=Time.get_ticks_usec(); maximum_frame_gap_usec=0; frame_gaps_usec.clear()
		if OS.get_environment("PAINT_REOPEN")=="1": await reopen()
		else: await author()
	host.queue_free()
	await process_frame
	await process_frame
	var sorted_gaps: Array[int] = frame_gaps_usec.duplicate()
	sorted_gaps.sort()
	var p95_usec := 0
	var p99_usec := 0
	if not sorted_gaps.is_empty():
		p95_usec=sorted_gaps[ceili(float(sorted_gaps.size())*0.95)-1]
		p99_usec=sorted_gaps[ceili(float(sorted_gaps.size())*0.99)-1]
	print("PAINT_EDITOR_WORKBENCH ",JSON.stringify({"checks":checks,"failures":failures,
		"maximum_frame_gap_usec":maximum_frame_gap_usec,"frame_gap_p95_usec":p95_usec,
		"frame_gap_p99_usec":p99_usec,"frame_samples":sorted_gaps.size(),
		"reopen":OS.get_environment("PAINT_REOPEN")}))
	quit(int(not failures.is_empty()))
