extends SceneTree

# Actual mounted Workbench: ordinary authoring, read-only source capture and
# independent native Batch Lab owners. No provider completion is simulated.
const Setup = preload("res://scripts/workbench_setup.gd")
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Experiments = preload("res://scripts/batch_lab/batch_lab_experiments.gd")
const ArtPanel = preload("res://scripts/art_batch_panel.gd")
var main: Control
var bench: Control
var editor: Control
var worker: RefCounted
var checks := 0
var failures: Array[String] = []
var evidence := ""
var started := 0

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("BATCH_LAB_WORKBENCH "+label)
	return ok

func until(predicate: Callable, label: String, limit_ms := 90000) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if worker != null and worker.has_failed(): break
		await process_frame
	return check(false,label+" / "+str(bench.message if bench != null else "no Workbench"))

func settled() -> bool:
	if bench.applied.is_empty() or bench.busy() or not main.pending_microscenario_apply.is_empty(): return false
	var state: Dictionary = worker.paint_state()
	return not editor.busy() and not state.busy and not state.art_busy and not state.legacy_busy and not state.transition_busy

func paint(cells: PackedInt32Array, label: String) -> bool:
	var before: int = editor.completed_actions
	if not check(editor.commit_cells(cells,label),label+" admitted through ordinary manual editor"): return false
	if not await until(settled,label+" settled"): return false
	return check(editor.completed_actions==before+1 and editor.last_receipt.get("status")=="completed",
		label+" has confirmed native completion")

func capture(region: Rect2i) -> PackedInt32Array:
	if not await until(settled,"manual receipt retired before independent capture"): return PackedInt32Array()
	var state: Dictionary = worker.paint_state()
	var admission: Dictionary = worker.paint_queue({"kind":"capture","region":region,
		"expected_generation":state.generation,"expected_revision":state.revision,"expected_tick":state.tick})
	if not check(admission.get("status")=="queued","native material capture admitted"): return PackedInt32Array()
	if not await until(func() -> bool: return worker.paint_state().receipt_ready,"native material capture ready"): return PackedInt32Array()
	var result: Dictionary = worker.paint_take_result()
	check(result.get("status")=="completed" and result.get("operation_id")==admission.operation_id
		and result.get("backend")=="CyberNativeCellWorld","independent readback owns native receipt")
	return result.get("materials",PackedInt32Array())

func snapshot_state() -> Dictionary:
	var state: Dictionary = worker.paint_state()
	return {"generation":state.generation,"revision":state.revision,"tick":state.tick,
		"authoring":bench.art_authoring_state().duplicate(true),"applied":bench.applied.duplicate(true),
		"undo":editor._undo_stack.duplicate(true),"redo":editor._redo_stack.duplicate(true)}

func screenshot(label: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"graphical framebuffer "+label)

func run() -> void:
	started = Time.get_ticks_msec()
	evidence = OS.get_environment("BATCH_LAB_EVIDENCE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1920,1080)
	set_meta("cybersand_feature","shared_workbench")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	bench = main.shared_workbench
	editor = bench.paint_editor
	worker = main.simulation_worker
	if not await until(settled,"mounted native Workbench installed",180000): await finish(); return
	if not check(ArtPanel.read_history_session().get("state")!="error",
		"preceding Batch provider traffic preserves a readable ordinary Art history namespace"):
		await finish(); return
	check(bench.batch_lab==null,"Batch Lab is OFF and uninstantiated in ordinary Workbench")
	if not main.paused: check(bench.toggle_pause(),"pause ordinary Workbench")
	var blank := Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	if not check(bench.apply(blank),"ordinary fresh native canvas admitted"): await finish(); return
	if not await until(settled,"fresh 512-square source installed"): await finish(); return
	if not await paint(PackedInt32Array([32,32,58,33,32,28,34,32,3]),"Batch disabled manual stroke"):
		await finish(); return
	check(await capture(Rect2i(32,32,3,1))==PackedInt32Array([58,28,3]),"manual paint with Batch disabled reaches actual native materials")
	var before := snapshot_state()
	var source: Dictionary = await bench.capture_batch_source(Rect2i(0,0,64,64))
	if not check(source.get("ok",false),"Workbench source crop captured through worker ownership boundary"):
		await finish(); return
	check(snapshot_state()==before,"read-only source capture preserves World fence, ordinary state and both history stacks")
	var cells: PackedByteArray = source.config.source_cells
	check(source.config.source_rectangles.is_empty(),"native capture explicitly replaces example source geometry")
	check(cells.size()==64*64*2 and cells.decode_u16((32*64+32)*2)==58
		and cells.decode_u16((32*64+33)*2)==28 and cells.decode_u16((32*64+34)*2)==3,
		"source crop retains authoritative uint16 materials including dynamic Water")
	check(source.config.source_provenance.original_region==[0,0,64,64]
		and str(source.config.source_provenance.crop_sha256).length()==64,"source provenance binds original region and material bytes")
	var bad: Dictionary = await bench.capture_batch_source(Rect2i(500,500,64,64))
	check(not bad.get("ok",false) and snapshot_state()==before,"out-of-bounds source capture refused without writes")
	check(editor.history_available("undo"),"manual Undo remains available after source capture")
	check(editor.undo(),"ordinary Undo is admitted after source capture")
	await until(settled,"ordinary Undo after source capture")
	check(await capture(Rect2i(32,32,3,1))==PackedInt32Array([0,0,0]),"ordinary Undo restores exact pre-stroke materials")
	check(editor.redo(),"ordinary Redo is admitted after source capture: "+bench.art_history_guard())
	await until(settled,"ordinary Redo after source capture")
	check(await capture(Rect2i(32,32,3,1))==PackedInt32Array([58,28,3]),"ordinary Redo reapplies confirmed stroke")
	bench.open_batch_lab()
	await process_frame
	if not check(is_instance_valid(bench.batch_lab) and bench.batch_lab.visible,"Batch Lab opens inside existing Workbench"):
		await finish(); return
	var panel: Window = bench.batch_lab
	var lab: Node = panel.controller
	check(not lab.is_running() and lab.attempts.is_empty(),"opening Batch Lab performs no automatic construction or inference")
	var config: Dictionary = Experiments.make_attempt("architecture","P0",19301,64,64)
	check(not config.source_rectangles.is_empty(),"example begins with a real deterministic source recipe")
	config.merge(source.config,true)
	check(config.source_rectangles.is_empty(),"captured Workbench source removes the prior example overlay")
	config.extent = [64,64]
	config.materials = [0,58]
	config.protection = [[32,32,3,1]]
	config.operations = [{"shape":"rectangle","x0":8,"y0":8,"x1":55,"y1":55,"material":58}]
	for i: int in 4:
		check(lab.configure_tile(i,config).get("ok",false),"independent source-config tile %d admitted" % i)
	panel.select_tile(0)
	check(lab.start().get("ok",false),"mounted 2x2 native source experiment starts")
	check(lab.is_running(),"batch work is genuinely queued while manual Workbench is independent")
	if not await paint(PackedInt32Array([400,400,58]),"Manual stroke while Batch is active"):
		await finish(); return
	if not await until(func() -> bool: return not lab.is_running(),"mounted native 2x2 completion"):
		await finish(); return
	for i: int in 4:
		var tile: Dictionary = lab.tiles[i]
		check(tile.state=="completed" and tile.metrics.get("outside_unchanged",false),"mounted tile %d completes with isolated native padding" % i)
		check(tile.source_materials==cells and tile.material_cells.decode_u16((32*64+33)*2)==28
			and tile.material_cells.decode_u16((32*64+34)*2)==3,"mounted tile %d retains protected source identities" % i)
	check(await capture(Rect2i(8,8,1,1))==PackedInt32Array([0]),"native Batch edit never leaks into the ordinary Workbench")
	check(await capture(Rect2i(400,400,1,1))==PackedInt32Array([58]),"ordinary native painting still succeeds during independent Batch execution")
	check(await capture(Rect2i(32,32,3,1))==PackedInt32Array([58,28,3]),"ordinary source materials survive all tile execution")
	panel.set_compare([0,1])
	await screenshot("mounted-source-comparison")
	panel.hide()
	check(editor.history_available("undo"),"ordinary manual history survives Batch opening and execution")
	check(editor.undo(),"ordinary Undo is admitted after Batch: "+bench.art_history_guard())
	await until(settled,"ordinary Undo after Batch")
	check(await capture(Rect2i(400,400,1,1))==PackedInt32Array([0]),"post-Batch Undo targets ordinary manual stroke")
	check(editor.redo(),"ordinary Redo is admitted after Batch: "+bench.art_history_guard())
	await until(settled,"ordinary Redo after Batch")
	check(await capture(Rect2i(400,400,1,1))==PackedInt32Array([58]),"post-Batch Redo remains native and accurate")
	await screenshot("ordinary-workbench-after-batch")
	await finish()

func finish() -> void:
	if main != null:
		main.queue_free()
		await process_frame
		await process_frame
	var result := {"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started,
		"godot":Engine.get_version_info().string,"os":OS.get_name(),"display":DisplayServer.get_name(),
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"provider_calls":0}
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("workbench.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result,"\t")); file.close()
	print("BATCH_LAB_WORKBENCH ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
