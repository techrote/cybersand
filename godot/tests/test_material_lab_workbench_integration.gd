extends "res://tests/test_art_undo.gd"

# Cross-feature acceptance on the real shared native owner. Reuse the existing
# native capture/history helpers, but run only this Lab + Workbench campaign.
# Execute author and MAT_WB_REOPEN=1 in separate processes with one userdata root.
const SAVE_NAME := "mat-workbench-integration"
const EXPECTED_PATH := "user://mat-workbench-integration.json"
const REGION := Rect2i(64,64,48,24)
const HUMAN := Vector2i(70,70)
const AGENT := Rect2i(80,70,8,4)
var lab: Control
var popup: Window
var phase_complete := false
var lab_receipt: Dictionary = {}
var process_instance := Crypto.new().generate_random_bytes(16).hex_encode()

func identity() -> Dictionary:
	var out := super.identity()
	for name: String in ["material_lab_panel.gd","material_lab_service.gd",
		"material_lab_catalogue.gd","material_lab_world_panel.gd"]:
		out[name] = FileAccess.get_sha256("res://scripts/"+name)
	out.history_helper_sha256 = FileAccess.get_sha256("res://tests/test_art_undo.gd")
	out.test_sha256 = FileAccess.get_sha256("res://tests/test_material_lab_workbench_integration.gd")
	return out

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child: Node in node.get_children():
		var found := find_button(child,caption)
		if found != null: return found
	return null

func press_lab(caption: String) -> bool:
	var button := find_button(lab,caption)
	if not check(button != null and not button.disabled,"mounted Lab action: "+caption): return false
	button.pressed.emit()
	return true

func lab_job(caption: String) -> bool:
	if not press_lab(caption): return false
	if not await until(func() -> bool: return not lab.service.busy,"Lab job: "+caption,300000): return false
	return check(lab.last_backend_result.get("ok",false),
		"actual source authoring succeeds: "+caption+" / "+str(lab.last_backend_result.get("errors",[])))

func history_signature() -> Dictionary:
	return {"undo":editor._undo_stack.duplicate(true),"redo":editor._redo_stack.duplicate(true),
		"fence":editor._history_fence.duplicate(true),"edits":bench.applied.edits.duplicate(true),
		"source":editor._source(worker.paint_state())}

func open_lab() -> bool:
	var button := find_button(bench,"Materials Lab…")
	if not check(button != null,"Materials Lab mounted alongside full PAINT and Art"): return false
	button.pressed.emit()
	await process_frame
	lab = bench._materials_lab_panel
	popup = bench._materials_lab_window
	if not check(is_instance_valid(lab) and popup.visible,"same-session Materials Lab opens"): return false
	check(lab.catalogue.native_available and lab.catalogue.materials.size()==132,
		"combined native binary exposes the complete 132-slot Materials Lab inspector")
	check(lab.applied_policy==host.tower_context.liquid_solver_policy,
		"Lab receives the actual Workbench owner policy without replacing the World")
	return true

func screenshot(label: String) -> void:
	var directory := OS.get_environment("MAT_WB_SCREENSHOTS")
	if directory.is_empty() or DisplayServer.get_name()=="headless": return
	check(DirAccess.make_dir_recursive_absolute(directory)==OK,"framebuffer evidence directory exists")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label+"-workbench.png"))==OK,
		"actual shared Workbench framebuffer: "+label)
	if popup != null and popup.visible:
		check(popup.get_texture().get_image().save_png(directory.path_join(label+"-lab.png"))==OK,
			"actual separate Materials Lab framebuffer: "+label)

func lab_input_isolation() -> bool:
	var before := history_signature()
	var values := await capture(REGION)
	var tool: String = editor.tool_name()
	var radius: int = editor.radius()
	var camera: int = bench._camera.selected
	var tick: int = worker.paint_state().tick
	lab._search.grab_focus()
	var typing := InputEventKey.new()
	typing.pressed = true
	typing.keycode = KEY_F
	typing.unicode = "f".unicode_at(0)
	popup.push_input(typing)
	check(lab._search.text=="f","Lab text receives input in its own viewport")
	lab._search.release_focus()
	for key: Key in [KEY_Z,KEY_Y,KEY_G,KEY_V,KEY_BRACKETRIGHT,KEY_PERIOD,KEY_P,KEY_F]:
		var event := InputEventKey.new()
		event.keycode = key
		event.ctrl_pressed = key in [KEY_Z,KEY_Y]
		event.pressed = true
		popup.push_input(event)
		event = event.duplicate()
		event.pressed = false
		popup.push_input(event)
	for frame: int in range(3): await process_frame
	check(history_signature()==before and await capture(REGION)==values,
		"Lab Undo/Redo and drawing keys cannot mutate shared cells or either history stack")
	check(editor.tool_name()==tool and editor.radius()==radius and bench._camera.selected==camera,
		"Lab input preserves Workbench tool, brush and camera")
	check(host.paused and int(worker.paint_state().tick)==tick,
		"Lab shortcuts cannot resume or step the Workbench World")
	lab._search.text = ""
	lab._search.text_changed.emit("")
	return failures.is_empty()

func isolated_world_and_cancel() -> bool:
	var before := history_signature()
	var values := await capture(REGION)
	lab.select_material(2)
	var native_sand: Dictionary = lab.catalogue.materials[2].duplicate(true)
	if not await lab_job("Make editable copy"): return false
	check(int(lab.candidate.target_id)==2,"Lab duplicates an existing stable material ID")
	lab._fields.density.value = 500
	lab._colour.color = Color8(17,91,203,255)
	lab._colour.color_changed.emit(lab._colour.color)
	var view: Control = lab.world_panel
	if not check(view.set_scenario({"first":2,"second":3,"seed":2,"ticks":120,"workers":workers}),
		"candidate World scenario retains existing IDs and requested workers"): return false
	lab._tabs.current_tab = 4
	if not await lab_job("Build + run comparison"): return false
	lab_receipt = lab.last_backend_result.receipt.duplicate(true)
	check(lab_receipt.schema_id=="cybersand.material-lab.world-receipt" and not lab_receipt.runtime_active,
		"mounted Lab comparison is executed native evidence without production activation")
	check(lab_receipt.candidate.world_simulation and int(lab_receipt.candidate.descriptor_readback.density)==500,
		"density edit is consumed by the isolated native candidate World")
	for backend: String in ["reference","candidate"]:
		for gate: String in ["deterministic_repeat","worker_1_4_equal","persistence_checkpoint","persistence_replay","quantity_balanced"]:
			check(bool(lab_receipt[backend].checks[gate]),"isolated "+backend+" "+gate)
	check(lab_receipt.candidate.final.target_below_reservoir<lab_receipt.reference.final.target_below_reservoir,
		"edited density changes actual candidate penetration while reference behavior is retained")
	var inspected := CyberMaterialLabCatalogue.new()
	check(inspected.reload() and inspected.materials[2]==native_sand,
		"independent fresh native inspection retains the production Sand definition")
	check(lab.catalogue.materials[2]==native_sand and history_signature()==before and await capture(REGION)==values,
		"native candidate simulation cannot mutate Workbench material definitions, cells, source or Undo/Redo")
	await screenshot("mat-workbench-isolated-comparison")
	# Cancel an actual newly admitted subprocess while retaining shared history.
	if not press_lab("Build + run comparison"): return false
	if not check(lab.service.busy and lab.service.process_id()>0,"second comparison owns a real authoring process"): return false
	if not press_lab("Cancel comparison"): return false
	if not await until(func() -> bool: return not lab.service.busy,"cancelled comparison retires its process",15000): return false
	check(lab.last_backend_result.get("cancelled",false) and not lab.last_backend_result.get("ok",true),
		"Lab cancellation returns a terminal non-qualification result")
	check(history_signature()==before and await capture(REGION)==values,
		"Lab cancellation preserves the unrelated shared native World and valid Redo")
	return failures.is_empty()

func author() -> bool:
	if not await fresh(): return false
	if not await human(HUMAN,28): return false
	if not await draw([{"shape":"rectangle","x0":AGENT.position.x,"y0":AGENT.position.y,
		"x1":AGENT.end.x-1,"y1":AGENT.end.y-1,"material":58}],AGENT): return false
	check(editor._undo_stack.size()==2,"human and agent edits share chronological native-backed history")
	var drawn := await capture(REGION)
	if not await reverse("undo"): return false
	check(uniform(await capture(AGENT),AGENT.get_area(),0) and await capture(Rect2i(HUMAN,Vector2i.ONE))==PackedInt32Array([28]),
		"agent Undo preserves the preceding manual Metal cell")
	var before := history_signature()
	# Opening the Lab retires an unfinished preview but retains confirmed history.
	editor.dragging = true
	editor.stroke.clear()
	editor.stroke.append(Vector2i(10,10))
	if not await open_lab(): return false
	check(not editor.dragging and editor.stroke.is_empty() and history_signature()==before,
		"opening Lab cancels the drawing preview without retiring confirmed Undo/Redo")
	if not await lab_input_isolation(): return false
	if not await isolated_world_and_cancel(): return false
	var panel_id := lab.get_instance_id()
	if not press_lab("Close"): return false
	await process_frame
	check(not popup.visible,"Lab Close returns to the existing Workbench")
	if not await reverse("redo"): return false
	check(await capture(REGION)==drawn,"shared agent Redo remains exact after Lab execution and cancellation")
	if not await open_lab(): return false
	check(lab.get_instance_id()==panel_id and int(lab.candidate.descriptor.density)==500,
		"reopening reuses the Lab candidate without reconstructing the Workbench")
	popup.close_requested.emit()
	if not await reverse("undo"): return false
	if not await reverse("undo"): return false
	check(uniform(await capture(REGION),REGION.get_area(),0),"shared Undo can still reach the original pre-Lab blank cells")
	if not await reverse("redo"): return false
	# Persist the human cell with the agent rectangle intentionally undone.
	bench._name.text = SAVE_NAME
	if not check(bench.save_setup(),"ordinary Setup-v2 save accepts settled shared state after Lab use"): return false
	var file := FileAccess.open(EXPECTED_PATH,FileAccess.WRITE)
	if not check(file!=null,"cross-process native expectation can be saved"): return false
	file.store_string(JSON.stringify({"author_instance":process_instance,
		"materials":Array(await capture(REGION)),"edits":bench.applied.edits,
		"policy":Array(bench.applied.liquid_policy),"candidate_digest":lab_receipt.candidate_digest,
		"source_identity":source_identity}))
	file.close()
	await screenshot("mat-workbench-saved")
	return failures.is_empty()

func reopen() -> bool:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED_PATH))
	if not check(expected is Dictionary and str(expected.get("author_instance","")).length()==32 \
		and expected.author_instance!=process_instance,"fresh process consumes prior authored expectation"): return false
	if not check(expected.get("source_identity",{})==source_identity,
		"reopen source and native runtime match the author process"): return false
	var generation: int = worker.paint_state().generation
	bench._name.text = SAVE_NAME
	if not check(bench.load_setup(),"unchanged starting-setup reader admits the authored layout"): return false
	if not await until(func() -> bool: return ready() and int(worker.paint_state().generation)>generation,
		"new process installs its native saved start"): return false
	check(await capture(REGION)==PackedInt32Array(expected.materials),
		"fresh process native cells exactly match the saved human edit and undone agent region")
	check(JSON.parse_string(JSON.stringify(bench.applied.edits))==expected.edits \
		and PackedInt32Array(bench.applied.liquid_policy)==PackedInt32Array(expected.policy),
		"save preserves ordered edits and native policy format")
	check(editor._undo_stack.is_empty() and editor._redo_stack.is_empty(),"session-local Undo stacks are honestly empty after restart")
	if not await open_lab(): return false
	check(lab.candidate.is_empty(),"isolated candidate is not silently installed or restored into production")
	popup.close_requested.emit()
	if not await draw([{"shape":"pixels","points":[[90,80]],"material":58}],Rect2i(90,80,1,1)): return false
	if not await reverse("undo"): return false
	check(await capture(Rect2i(90,80,1,1))==PackedInt32Array([0]),"new-session agent Undo works after reopened Lab")
	if not await human(Vector2i(91,80),28): return false
	if not await reverse("undo"): return false
	check(await capture(REGION)==PackedInt32Array(expected.materials),"continued manual authoring and Undo restore the reopened baseline")
	await screenshot("mat-workbench-reopened")
	return failures.is_empty()

func run() -> void:
	source_identity = identity()
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	root.size = Vector2i(1440,1000)
	bench = host.shared_workbench
	worker = host.simulation_worker
	if bench != null:
		editor = bench.paint_editor
		panel = bench.art_batches
		art = panel.executor
	var reopening := OS.get_environment("MAT_WB_REOPEN")=="1"
	if check(bench!=null and editor!=null,"combined source mounts full Workbench") \
		and await until(ready,"combined native Workbench initial readiness",180000):
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		check(snapshot!=null and snapshot.scheduler_thread_capacity_hint==workers,"native capacity matches the requested 1/4-worker fixture")
		if reopening: phase_complete = await reopen()
		else: phase_complete = await author()
	check(phase_complete,"complete mandatory Lab/Workbench "+("reopen" if reopening else "author")+" flow")
	if lab!=null: lab.experiment.close()
	host.queue_free()
	await process_frame
	await process_frame
	check(identity()==source_identity,"tested scripts and native runtime remain unchanged")
	print("MAT_WB_EVIDENCE ",JSON.stringify({"checks":checks,"failures":failures.size(),"errors":failures,
		"workers":workers,"phase":"reopen" if reopening else "author","complete":phase_complete,
		"source_identity":source_identity,"native_material_witnesses":witnesses,
		"candidate_world_receipt":lab_receipt,"provider":"native deterministic packet; no model inference"}))
	print("MAT_WB_INTEGRATION checks=%d failures=%d complete=%s" % [checks,failures.size(),str(phase_complete)])
	quit(1 if not failures.is_empty() else 0)
