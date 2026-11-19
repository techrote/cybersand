extends SceneTree

# Mounted ordinary Workbench gestures, native ACK and a fresh-process save.
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true
var host: Control
var bench: Control
var editor: Control
var checks := 0
var failures: Array[String] = []
var maximum_frame_gap_usec := 0
var last_frame_usec := 0
const SAVE_NAME := "paint001-mounted-acceptance"

func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if last_frame_usec>0: maximum_frame_gap_usec=maxi(maximum_frame_gap_usec,now-last_frame_usec)
	last_frame_usec=now
	return false
func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:
		failures.append(label)
		push_error("PAINT_EDITOR_WORKBENCH "+label)
	return ok
func until(predicate: Callable,label: String,limit_ms: int=30000) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return check(false,label+" / "+str(bench.message))
func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() and not host.simulation_worker.paint_state().busy
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
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	root.size=Vector2i(1440,1000)
	bench=host.shared_workbench
	editor=bench.paint_editor
	if check(await until(ready,"ordinary Workbench installed",60000),"ordinary Workbench ready"):
		last_frame_usec=Time.get_ticks_usec(); maximum_frame_gap_usec=0
		if OS.get_environment("PAINT_REOPEN")=="1": await reopen()
		else: await author()
	host.queue_free()
	await process_frame
	await process_frame
	print("PAINT_EDITOR_WORKBENCH ",JSON.stringify({"checks":checks,"failures":failures,"maximum_frame_gap_usec":maximum_frame_gap_usec,"reopen":OS.get_environment("PAINT_REOPEN")}))
	quit(int(not failures.is_empty()))
