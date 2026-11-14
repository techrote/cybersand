extends SceneTree

# Combined-source acceptance, deliberately separate from both original suites.
# Run twice with the same isolated user data: author, then WB_COMBINED_REOPEN=1.
# Provider completion is a deterministic protocol fixture, not HTTP/inference;
# tools/test_art_provider_transport.py qualifies transport independently.
const Setup = preload("res://scripts/workbench_setup.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
const SAVE_NAME := "wb-combined-generated-acceptance"
const EXPECTED_PATH := "user://wb-combined-native-expectation.json"
const AUTHOR_REGION := Rect2i(32,32,352,272)
const ACTOR_CLEARANCE := Rect2i(400,336,104,168)
const LARGE_FILL_REGION := Rect2i(560,64,386,386)
const FOLLOWUP_PROMPT := "Add a short wall line, then erase one previous wall cell."
const UNDONE_AGENT_REGION := Rect2i(350,250,3,1)
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var bench: Control
var editor: Control
var panel: Window
var art: RefCounted
var worker: RefCounted
var dialog: ConfirmationDialog
var checks := 0
var failures: Array[String] = []
var phases := {"discovery":false,"generation":false,"manual":false,"leases":false,
	"agent":false,"provider_fixture":false,"late_response":false,"human_after_agent":false,
	"stop":false,"agent_undo_saved":false,"simulation_equipment":false,"save":false,"reopen":false,"continued_authoring":false}
var author_complete := false
var reopen_complete := false
var profile_count := 0
var map_side := 512
var prepared_sha256 := ""
var stopped_prefix := 0
var simulation_evidence: Dictionary = {}
var source_identity: Dictionary = {}
var started_usec := 0
# Separate container invocations may reuse the same namespace-local PID.
# This in-memory witness is never restored from the saved expectation.
var process_instance := Crypto.new().generate_random_bytes(16).hex_encode()

func _initialize() -> void:
	started_usec = Time.get_ticks_usec()
	var workers := int(OS.get_environment("WB_COMBINED_WORKERS"))
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers if workers in [1,4] else 1)
	var selected_side := OS.get_environment("WB_COMBINED_SIDE")
	if not selected_side.is_empty(): map_side = int(selected_side)
	run.call_deferred()

func check(ok: bool,label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WB_COMBINED_AUTHORING "+label)
	return ok

func until(predicate: Callable,label: String,limit_ms: int = 60000) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if worker != null and worker.has_failed(): break
		await process_frame
	return check(false,label+" / "+str(bench.message)+" / "+str(dialog._status.text))

func settled() -> bool:
	var a: Dictionary = worker.art_state()
	return not editor.busy() and not worker.paint_state().busy and not art.active and not panel.log_draw \
		and not a.queued and not a.executing and not a.receipt_ready and art.manual.is_empty()

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() \
		and host.pending_microscenario_apply.is_empty() and settled()

func generator_ready() -> bool:
	return dialog._phase == "ready" or dialog._status.text.begins_with("Refused")

func json_equivalent(actual: Variant,expected: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected))

func identity() -> Dictionary:
	var result := {"godot":Engine.get_version_info().string,"os":OS.get_name(),
		"display":DisplayServer.get_name()}
	for path: String in ["scripts/simulation_worker.gd","scripts/shared_workbench.gd",
		"scripts/workbench_generator_dialog.gd","scripts/art_batch_executor.gd",
		"scripts/art_batch_panel.gd","scripts/art_provider.gd",
		"scripts/workbench_liquid_equipment.gd","scripts/workbench_liquid_equipment_panel.gd",
		"scripts/workbench_paint_editor_controller.gd","scripts/workbench_paint_editor_executor.gd",
		"scripts/workbench_paint_editor_history.gd","scripts/workbench_setup.gd",
		"scripts/workbench_generated_map.gd","tests/test_workbench_combined_authoring.gd"]:
		result[path] = FileAccess.get_sha256("res://"+path)
	var native_path := "res://addons/cybersand_native/bin/"+(
		"cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so")
	result.native_sha256 = FileAccess.get_sha256(native_path)
	return result

func screenshot(label: String) -> void:
	var directory := OS.get_environment("WB_COMBINED_SCREENSHOTS")
	if directory.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,
		"actual graphical framebuffer "+label)

func history_control(action: String,label: String) -> bool:
	panel.popup_centered()
	await process_frame
	var button: Button = panel.undo_button if action=="undo" else panel.redo_button
	if not check(not button.disabled,"Art panel "+action+" control enabled: "+label):
		panel.hide()
		return false
	var completed_before: int = editor.completed_actions
	button.pressed.emit()
	var finished := await until(settled,label+" native history completion")
	panel.hide()
	return finished and check(editor.completed_actions>completed_before,
		"Art panel "+action+" produced a confirmed native history operation: "+label)

func local(cell: Vector2i) -> Vector2:
	var bounds: Rect2 = host.view_content_rect()
	return bounds.position+(Vector2(cell)+Vector2(0.5,0.5)-Vector2(host.presentation_camera_origin())) \
		* bounds.size/Vector2(host.current_view_size)

func gesture(tool: String,from: Vector2i,to: Vector2i,material: int = 58,
		button: int = MOUSE_BUTTON_LEFT) -> bool:
	editor.select_tool(tool)
	editor.select_material(material)
	var completed_before: int = editor.completed_actions
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.position = local(from)
	bench._world_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = local(to)
	motion.relative = motion.position-press.position
	bench._world_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = button
	release.position = local(to)
	bench._world_input(release)
	if not await until(settled,tool+" native completion"): return false
	if tool=="Select": return check(editor.selection==Rect2i(from.min(to),from.max(to)-from.min(to)+Vector2i.ONE),"selection maps to native cells")
	return check(editor.completed_actions==completed_before+1 and editor.last_receipt.get("status")=="completed",
		tool+" produced a new confirmed native receipt")

func capture_request(region: Rect2i) -> Dictionary:
	var state: Dictionary = worker.paint_state()
	return {"kind":"capture","region":region,"expected_generation":int(state.generation),
		"expected_revision":int(state.revision),"expected_tick":int(state.tick)}

func capture(region: Rect2i) -> PackedInt32Array:
	if not await until(settled,"edit receipts retired before independent readback"): return PackedInt32Array()
	var admission: Dictionary = worker.paint_queue(capture_request(region))
	if not check(admission.status=="queued","independent native capture admitted"): return PackedInt32Array()
	if not await until(func() -> bool: return worker.paint_state().receipt_ready,"independent native capture ready"): return PackedInt32Array()
	var receipt: Dictionary = worker.paint_take_result()
	check(receipt.get("operation_id")==admission.operation_id and receipt.get("status")=="completed"
		and receipt.get("backend")=="CyberNativeCellWorld","independent capture owns its native receipt")
	return receipt.get("materials",PackedInt32Array())

func apply_region(bytes: PackedByteArray,region: Rect2i,values: PackedInt32Array) -> void:
	for y: int in region.size.y:
		for x: int in region.size.x:
			bytes[(region.position.y+y)*map_side+region.position.x+x] = values[y*region.size.x+x]

func complete_native_materials() -> PackedByteArray:
	# Read the whole installed World before actor masks are added. Tile within
	# PAINT's existing capture budget instead of raising that product capacity.
	var bytes := PackedByteArray()
	bytes.resize(map_side*map_side)
	for y: int in range(0,map_side,512):
		for x: int in range(0,map_side,512):
			var region := Rect2i(x,y,mini(512,map_side-x),mini(512,map_side-y))
			var values := await capture(region)
			if not check(values.size()==region.get_area(),"complete native material tile readback"): return PackedByteArray()
			apply_region(bytes,region,values)
	return bytes

func large_adaptive_fill() -> bool:
	if map_side<1024: return true
	var previous_origin: Vector2 = host.camera_origin
	var previous_size: Vector2i = host.current_view_size
	var overview := large_fill_view_geometry()
	# A minified overview may omit a particular native cell from the physical
	# pixel grid. Inspect this exact enclosure at more than one pixel per cell
	# before sending the same real Rectangle/Outline gestures to PAINT.
	bench._set_view(Vector2(LARGE_FILL_REGION.position-Vector2i(7,7)),Vector2i(400,400))
	await process_frame
	await process_frame
	var inspected := large_fill_view_geometry()
	var selectable := check(float(inspected.physical_pixels_per_cell[0])>=1.0
		and float(inspected.physical_pixels_per_cell[1])>=1.0,
		"large Fill inspection exposes every native cell at physical scale at least one")
	selectable = check(inspected.first_pick==[560,64] and inspected.last_pick==[945,449],
		"large Fill real gesture endpoints pick the exact required native enclosure") and selectable
	print("WB_COMBINED_LARGE_FILL_VIEW ",JSON.stringify({"overview":overview,"inspection":inspected}))
	var completed := false
	if selectable: completed = await large_adaptive_fill_inspected()
	bench._set_view(previous_origin,previous_size)
	await process_frame
	var restored := check(host.camera_origin==previous_origin and host.current_view_size==previous_size,
		"large Fill inspection restores the previous camera for subsequent authoring")
	return completed and restored

func large_fill_view_geometry() -> Dictionary:
	var view: Control = host.world_view
	var content: Rect2 = host.view_content_rect()
	# Compose the renderer's physical transform independently of Main's helper.
	var screen := view.get_viewport().get_final_transform()*view.get_global_transform_with_canvas()
	var basis := Vector2(screen.x.x,screen.y.y)*content.size/Vector2(host.current_view_size)
	var first: Vector2i = host.world_cell_from_local_point(local(LARGE_FILL_REGION.position))
	var last: Vector2i = host.world_cell_from_local_point(local(LARGE_FILL_REGION.end-Vector2i.ONE))
	return {"root_size":[root.size.x,root.size.y],"world_view_size":[view.size.x,view.size.y],
		"view_size":[host.current_view_size.x,host.current_view_size.y],
		"requested_origin":[host.camera_origin.x,host.camera_origin.y],
		"physical_pixels_per_cell":[basis.x,basis.y],"first_pick":[first.x,first.y],"last_pick":[last.x,last.y]}

func large_adaptive_fill_inspected() -> bool:
	if not await gesture("Rectangle",LARGE_FILL_REGION.position,LARGE_FILL_REGION.end-Vector2i.ONE,0): return false
	if not await gesture("Outline",LARGE_FILL_REGION.position,LARGE_FILL_REGION.end-Vector2i.ONE,58): return false
	var enclosure := await capture(LARGE_FILL_REGION)
	var enclosure_exact := enclosure.size()==LARGE_FILL_REGION.get_area()
	for index: int in enclosure.size():
		var x: int = index%LARGE_FILL_REGION.size.x
		var y: int = index/LARGE_FILL_REGION.size.x
		if enclosure[index]!=(58 if x in [0,385] or y in [0,385] else 0): enclosure_exact=false
	if not check(enclosure_exact,"large Fill begins with the exact native Empty interior and enclosing boundary"): return false
	# No selection: this enclosed 384-square interior exceeds the initial
	# 256-square capture and must trigger the bounded adaptive Fill path.
	editor.selection = Rect2i()
	editor.select_material(2)
	if not check(editor.fill_at(LARGE_FILL_REGION.get_center()),"large watertight adaptive Fill admitted"): return false
	if not await until(settled,"large watertight adaptive Fill native completion"): return false
	print("WB_COMBINED_LARGE_FILL ",JSON.stringify({"status":editor.last_receipt.get("status"),
		"applied":editor.last_receipt.get("applied"),"changed":editor.last_receipt.get("changed"),
		"kind":editor.last_receipt.get("kind"),"message":editor._message,"source":worker.paint_state()}))
	if not check(editor.last_receipt.get("status")=="completed" and int(editor.last_receipt.get("applied",0))==384*384,
		"adaptive Fill confirms all 147456 interior cells"): return false
	var values := await capture(LARGE_FILL_REGION)
	var exact := values.size()==LARGE_FILL_REGION.get_area()
	for index: int in values.size():
		var x: int = index%LARGE_FILL_REGION.size.x
		var y: int = index/LARGE_FILL_REGION.size.x
		var expected := 58 if x in [0,385] or y in [0,385] else 2
		if values[index]!=expected: exact=false
	return check(exact,"every large Fill cell and enclosing boundary has its exact stored material")

func reciprocal_lease_checks() -> bool:
	# Capture changes no cells, so the test cannot introduce an unrecorded edit.
	# Keep each receipt deliberately unconsumed to exercise both ownership slots.
	var admission: Dictionary = worker.paint_queue(capture_request(Rect2i(0,0,512,512)))
	if not check(admission.status=="queued","manual capture lease admitted"): return false
	var epoch: int = worker.art_state().epoch
	var refused: Dictionary = worker.art_queue(PackedInt32Array([40,40]),58,AUTHOR_REGION,[],epoch)
	check(refused.status=="refused","agent cannot interleave with queued manual capture")
	check(not worker.queue_emit_cells(PackedInt32Array([41,40]),58),"legacy brush cannot interleave with manual lease")
	if not await until(func() -> bool: return worker.paint_state().executing or worker.paint_state().receipt_ready,
		"manual capture reaches native execution"): return false
	refused = worker.art_queue(PackedInt32Array([40,40]),58,AUTHOR_REGION,[],epoch)
	check(refused.status=="refused","agent cannot take executing manual lease")
	if not await until(func() -> bool: return worker.paint_state().receipt_ready,"manual result held for consumption"): return false
	refused = worker.art_queue(PackedInt32Array([40,40]),58,AUTHOR_REGION,[],epoch)
	check(refused.status=="refused","unconsumed manual receipt blocks agent admission")
	var manual: Dictionary = worker.paint_take_result()
	check(manual.get("operation_id")==admission.operation_id and manual.get("status")=="completed",
		"manual receipt survives competing agent admissions")
	# The selected cell is already Wall; direct worker qualification does not
	# bypass authoring history with an unrecorded material change.
	panel.set_process(false)
	admission = worker.art_queue(PackedInt32Array([40,40]),58,AUTHOR_REGION,[],epoch)
	if not check(admission.status=="queued","agent no-op lease admitted after manual receipt"):
		panel.set_process(true)
		return false
	check(worker.paint_queue(capture_request(Rect2i(40,40,1,1))).status=="refused",
		"manual cannot interleave with queued agent lease")
	check(not worker.queue_emit_cells(PackedInt32Array([41,40]),58),"legacy brush cannot interleave with agent lease")
	if not await until(func() -> bool: return worker.art_state().receipt_ready,"agent result held for consumption"):
		panel.set_process(true)
		return false
	check(worker.paint_queue(capture_request(Rect2i(40,40,1,1))).status=="refused",
		"unconsumed agent receipt blocks manual admission")
	var agent: Dictionary = worker.art_take_result()
	check(agent.get("status")=="completed" and int(agent.get("changed",-1))==0
		and agent.get("readback")==[[40,40,58,58]],"agent receipt proves unchanged native stored Wall")
	panel.set_process(true)
	phases.leases = true
	return true

func manual_tools() -> bool:
	if not await gesture("Rectangle",AUTHOR_REGION.position,AUTHOR_REGION.end-Vector2i.ONE,0): return false
	if not await gesture("Rectangle",ACTOR_CLEARANCE.position,ACTOR_CLEARANCE.end-Vector2i.ONE,0): return false
	if not await gesture("Rectangle",Vector2i(40,40),Vector2i(47,47),58): return false
	if not await gesture("Rectangle",Vector2i(44,40),Vector2i(47,43),3): return false
	if not await gesture("Brush",Vector2i(42,42),Vector2i(42,42),58,MOUSE_BUTTON_RIGHT): return false
	if not await gesture("Line",Vector2i(80,45),Vector2i(95,52),77): return false
	if not await gesture("Outline",Vector2i(110,60),Vector2i(140,90),58): return false
	var source: PackedInt32Array = await capture(Rect2i(40,40,8,8))
	if not check(source.size()==64 and source[0]==58 and source[4]==3 and source[18]==0,
		"mixed native selection contains Wall, Water and Empty"): return false
	if not await gesture("Select",Vector2i(40,40),Vector2i(47,47)): return false
	if not check(editor.copy_selection(),"native Copy admitted"): return false
	if not await until(settled,"native Copy complete"): return false
	check(editor.clipboard.get("materials")==source,"clipboard preserves source material IDs")
	var previous: PackedInt32Array = await capture(Rect2i(44,44,8,8))
	if not check(editor.paste_at(Vector2i(44,44)),"overlapping Paste admitted"): return false
	if not await until(settled,"mixed Paste complete"): return false
	check(await capture(Rect2i(44,44,8,8))==source,"overlapping Paste uses immutable native source")
	if not check(editor.undo(),"paused Undo admitted"): return false
	if not await until(settled,"Undo complete"): return false
	check(await capture(Rect2i(44,44,8,8))==previous,"Undo restores exact prior IDs")
	if not check(editor.redo(),"paused Redo admitted"): return false
	if not await until(settled,"Redo complete"): return false
	check(await capture(Rect2i(44,44,8,8))==source,"Redo restores exact copied IDs")
	editor.selection = Rect2i(110,60,31,31)
	editor.select_material(2)
	if not check(editor.fill_at(Vector2i(120,70)),"bounded native Fill admitted"): return false
	if not await until(settled,"Fill complete"): return false
	var filled: PackedInt32Array = await capture(Rect2i(110,60,31,31))
	check(filled.size()==961 and filled[0]==58 and filled[32]==2 and filled[480]==2,"Fill preserves watertight boundary")
	if not await gesture("Brush",Vector2i(184,44),Vector2i(184,44),28): return false
	phases.manual = true
	return await reciprocal_lease_checks()

func agent_authoring() -> bool:
	panel.popup_centered()
	await process_frame
	check(panel.visible and editor.is_visible_in_tree(),"agent panel and full human editor coexist")
	await screenshot("combined-agent-and-paint")
	panel.hide()
	var before := await capture(Rect2i(180,40,25,24))
	var operations := [{"shape":"rectangle","x0":180,"y0":40,"x1":203,"y1":63,"material":58},
		{"shape":"pixels","points":[[204,40]],"material":58}]
	var admission: Dictionary = art.submit(operations,Rect2i(180,40,24,24),[Rect2i(186,44,2,2)],[0,58])
	if not check(admission.status=="queued","bounded direct agent operation admitted"): return false
	check(not bench.save_setup(),"queue admission does not permit premature Save")
	if not await until(settled,"direct agent native completion"): return false
	check(art.result.status=="completed" and art.result.checked==577 and art.result.changed==571
		and art.result.excluded==6,"agent counts separate changed cells, protected source, explicit guard and outside scope")
	check(art.last_receipt.get("backend")=="CyberNativeCellWorld","agent completion came from native owner")
	var observed: PackedInt32Array = await capture(Rect2i(180,40,25,24))
	if not check(observed.size()==600,"bounded agent result captured natively"): return false
	var exact := true
	for y: int in 24:
		for x: int in 25:
			var expected := 58
			if x==24 or (x in [6,7] and y in [4,5]): expected=0
			if x==4 and y==4: expected=28
			if observed[y*25+x]!=expected: exact=false
	check(exact,"native agent result retains human Metal, guard and outside-scope cells")
	if not await history_control("undo","whole direct agent batch"): return false
	check(await capture(Rect2i(180,40,25,24))==before,
		"agent Undo restores every native before-material and retains the protected human Metal")
	if not await history_control("redo","whole direct agent batch"): return false
	check(await capture(Rect2i(180,40,25,24))==observed,
		"agent Redo restores the exact bounded native result")
	phases.agent = true
	return true

func provider_completion_fixture() -> bool:
	# Exercise the real decoder, signal, panel, executor and native boundary.
	# The companion transport suite covers HTTP, timeout and provider wire forms.
	panel.source.select(0)
	panel.change_provider(0)
	panel.model.text = "wb-combined-deterministic-fixture"
	panel.context_mode.select(1)
	panel.save_profile()
	panel.remember_turn("user",FOLLOWUP_PROMPT)
	panel.request_epoch = worker.art_state().epoch
	panel.request_area = Rect2i(176,32,80,64)
	panel.request_guards = [Rect2i(186,44,2,2)]
	panel.request_materials = [0,58]
	panel.request_material = 58
	panel.request_shapes = panel.enabled_shapes()
	panel.request_pixel_limit = 0
	panel.request_local = false
	panel.request_scanline = false
	panel.remaining_turns = 0
	var text := '[{"shape":"line","x0":220,"y0":70,"x1":230,"y1":70,"material":58},{"shape":"pixels","points":[[181,41]],"material":0}]'
	var response := {"model":"deterministic-fixture","status":"completed",
		"output":[{"content":[{"type":"output_text","text":text}]}],
		"usage":{"input_tokens":24,"output_tokens":48}}
	var adapter: Script = load("res://scripts/art_provider.gd")
	var decoded: Dictionary = adapter.decode("OpenAI",response)
	if not check(decoded.error.is_empty(),"deterministic Responses completion decoded"): return false
	panel.provider.usage = response.usage
	panel.provider.finished.emit(1,decoded.text,response,decoded.error)
	if not await until(func() -> bool: return settled() and not panel.log_draw,"fixture provider-to-native completion"): return false
	check(art.result.status=="completed" and art.result.changed==12,"follow-up fixture confirms eleven wall cells and one erasure")
	check(await capture(Rect2i(220,70,11,1))==PackedInt32Array([58,58,58,58,58,58,58,58,58,58,58]),
		"provider fixture line exists in native grid")
	check(await capture(Rect2i(181,41,1,1))==PackedInt32Array([0]),"provider fixture erased the requested stored Wall")
	check(panel.conversation.size()>=3,"follow-up conversation contains instruction, response and native feedback")
	phases.provider_fixture = true
	# Keep the captured request epoch, then Stop before its delayed completion.
	panel.request_epoch = worker.art_state().epoch
	panel.stop_all("Combined fixture late-response fence")
	var recorded: Array = bench.applied.edits.duplicate(true)
	panel.provider.finished.emit(2,'[{"shape":"pixels","points":[[232,70]],"material":58}]',response,"")
	for i: int in 4: await process_frame
	check(not art.active and bench.applied.edits==recorded,"late provider completion after Stop cannot enter authored history")
	check(await capture(Rect2i(232,70,1,1))==PackedInt32Array([0]),"late provider completion performs no native write")
	phases.late_response = true
	return true

func human_after_agent() -> bool:
	if not await gesture("Rectangle",Vector2i(80,180),Vector2i(84,184),131): return false
	check(await capture(Rect2i(80,180,1,1))==PackedInt32Array([131]),"manual full-palette material works after agent turn")
	if not check(editor.undo(),"new manual edit has valid Undo after the agent turn"): return false
	if not await until(settled,"new manual Undo complete"): return false
	check(await capture(Rect2i(80,180,1,1))==PackedInt32Array([0]),"new manual Undo restores current source")
	if not check(editor.redo(),"new manual Redo admitted"): return false
	if not await until(settled,"new manual Redo complete"): return false
	phases.human_after_agent = true
	return true

func stopped_agent_prefix() -> bool:
	var before := await capture(Rect2i(210,120,128,128))
	panel.set_process(false)
	var admission: Dictionary = art.submit([{"shape":"rectangle","x0":210,"y0":120,"x1":337,"y1":247,"material":58}],
		Rect2i(210,120,128,128),[],[0,58])
	if not check(admission.status=="queued","large agent operation admitted before Stop"):
		panel.set_process(true)
		return false
	if not await until(func() -> bool:
		if not art.waiting: art.poll()
		return art.waiting,"one bounded agent chunk admitted"):
		panel.set_process(true)
		return false
	if not await until(func() -> bool: return worker.art_state().receipt_ready,"first agent chunk actually completed"):
		panel.set_process(true)
		return false
	var receipts: Array = []
	var receive_chunk := func(receipt: Dictionary) -> void: receipts.append(receipt.duplicate(true))
	art.native_receipt.connect(receive_chunk)
	# The rasterizer has a 2.5 ms time budget and may flush fewer than 4096
	# points after 33 ms. Erase in its first row, which always reaches native
	# execution before that timed flush; the retained receipt defines the prefix.
	var erased_point := Vector2i(218,120)
	bench.applied.brush = 2
	bench._brush.value = 2
	check(bench.paint(erased_point,0),"human erasure accepted while agent completion awaits consumption")
	art.stop("Combined fixture completed-prefix Stop")
	panel.set_process(true)
	var retired := await until(settled,"agent Stop and accepted human stroke both retire")
	art.native_receipt.disconnect(receive_chunk)
	if not retired: return false
	stopped_prefix = int(art.result.checked)
	if not check(receipts.size()==1,"Stop consumes exactly one completed native chunk receipt"): return false
	var completed_chunk: Dictionary = receipts.front()
	check(stopped_prefix>0 and stopped_prefix<=worker.MAX_BRUSH_FOOTPRINT_CELLS and art.result.status=="partial",
		"Stop reports a nonempty bounded completed prefix")
	check(stopped_prefix>8,"deferred human erasure targets a confirmed Wall in the first native row")
	check(completed_chunk.get("status")=="completed" and int(completed_chunk.get("requested",-1))==stopped_prefix
		and int(completed_chunk.get("checked",-1))==stopped_prefix and int(completed_chunk.get("changed",-1))==stopped_prefix
		and int(completed_chunk.get("confirmed",-1))==stopped_prefix and completed_chunk.readback.size()==stopped_prefix
		and int(completed_chunk.get("excluded",-1))==0 and int(completed_chunk.get("refused",-1))==0
		and int(completed_chunk.get("unchanged",-1))==0
		and int(art.result.changed)==stopped_prefix and int(art.result.excluded)==0 and int(art.result.refused)==0,
		"Stop totals exactly equal its consumed native receipt, not the raster capacity")
	var exact_receipt := true
	for index: int in stopped_prefix:
		if completed_chunk.readback[index] != [210+index%128,120+index/128,0,58]: exact_receipt=false
	check(exact_receipt,"completed receipt contains the exact ordered stored Empty-to-Wall prefix")
	check(art.manual.is_empty(),"accepted deferred human stroke has no orphaned pending entry")
	check(int(art.result.get("human_applied",-1))==1 and int(art.result.get("human_refused",-1))==0
		and int(art.result.get("human_pending",-1))==0,"Stop truthfully reports one applied human stroke and no refused or pending strokes")
	check(await capture(Rect2i(erased_point,Vector2i.ONE))==PackedInt32Array([0]),"accepted human erasure was applied after agent chunk")
	check(await capture(Rect2i(210,120,1,1))==PackedInt32Array([58]),"completed prefix remains in native World")
	check(await capture(Rect2i(337,247,1,1))==PackedInt32Array([0]),"unexecuted agent suffix is absent")
	var stored: PackedInt32Array = await capture(Rect2i(210,120,128,128))
	var exact_grid := stored.size()==128*128
	for index: int in stored.size():
		var point := Vector2i(210+index%128,120+index/128)
		var expected := 58 if index<stopped_prefix and point.distance_squared_to(erased_point)>4 else 0
		if stored[index]!=expected: exact_grid=false
	check(exact_grid,"every native cell matches the completed prefix, deferred human disc and untouched suffix")
	var late: Dictionary = worker.art_queue(PackedInt32Array([337,247]),58,AUTHOR_REGION,[],art.epoch)
	check(late.status=="refused","old agent epoch remains fenced after Stop")
	if not await history_control("undo","human stroke after stopped agent prefix"): return false
	var prefix_only := before.duplicate()
	for index: int in stopped_prefix: prefix_only[index]=58
	check(await capture(Rect2i(210,120,128,128))==prefix_only,
		"first Undo reverses the later human erasure without losing the stopped agent prefix")
	if not await history_control("undo","confirmed stopped agent prefix"): return false
	check(await capture(Rect2i(210,120,128,128))==before,
		"second Undo restores the complete pre-agent native region including its untouched suffix")
	if not await history_control("redo","confirmed stopped agent prefix"): return false
	check(await capture(Rect2i(210,120,128,128))==prefix_only,
		"first Redo restores only the natively confirmed agent prefix")
	if not await history_control("redo","human stroke after stopped agent prefix"): return false
	check(await capture(Rect2i(210,120,128,128))==stored,
		"second Redo exactly restores the agent-prefix and later human ordering")
	phases.stop = true
	return true

func undo_before_save() -> bool:
	var before := await capture(UNDONE_AGENT_REGION)
	if not check(before==PackedInt32Array([0,0,0]),"persistence Undo fixture begins with exact native Empty cells"): return false
	var admitted: Dictionary = art.submit([{"shape":"pixels","points":[[350,250],[351,250],[352,250]],"material":58}],
		UNDONE_AGENT_REGION,[],[0,58])
	if not check(admitted.status=="queued","agent mark admitted for Undo-before-Save"): return false
	if not await until(settled,"agent mark confirmed before Undo-before-Save"): return false
	check(await capture(UNDONE_AGENT_REGION)==PackedInt32Array([58,58,58]),"persistence fixture really changes native cells")
	if not await history_control("undo","agent mark deliberately left undone before Save"): return false
	check(await capture(UNDONE_AGENT_REGION)==before,"native agent mark is absent before authored-start Save")
	phases.agent_undo_saved = true
	return true

func discover() -> bool:
	dialog.open_new()
	profile_count = dialog._profile.item_count
	if not check(profile_count>=2,"installed generator dropdown contains real profiles"): return false
	var selected := -1
	for index: int in profile_count:
		if dialog._profile.get_item_text(index)=="gen007-deepworks": selected=index
	if not check(selected>=0,"actual gen007-deepworks profile is available"): return false
	dialog._profile.select(selected)
	dialog._profile.item_selected.emit(selected)
	check(FileAccess.file_exists(str(dialog._profile.get_item_metadata(selected))),"selected installed recipe resolves to readable file")
	check(dialog._saved_recipe.is_empty(),"initial generation uses discovered file, not injected recipe")
	await screenshot("combined-generator-profiles")
	phases.discovery = true
	return true

func equipment_receipt() -> Dictionary:
	return host.tower_context.get("workbench_equipment",{})

func equipment_current() -> bool:
	var receipt := equipment_receipt()
	return bool(receipt.get("configured",false)) and int(receipt.get("serial",-1))==bench.equipment.serial

func exercise_simulation_equipment() -> bool:
	# Native layout expectations above describe the authored start. Running the
	# real simulation here must not silently turn Save into a physics snapshot.
	var edits_before: Array = bench.applied.edits.duplicate(true)
	var before_tick := int(worker.paint_state().tick)
	worker.set_worker_participation_sampling(true)
	bench._position[0].value = 320
	bench._position[1].value = 80
	bench.equipment._supply.value = 32
	bench.equipment._rate.value = 1
	bench.equipment._speed.value = 2
	if not check(bench.equipment.place("nozzle"),"existing equipment control places a finite-supply nozzle"): return false
	if not await until(equipment_current,"native worker acknowledges authored nozzle configuration"): return false
	if not check(bench.equipment.nudge_aim(10.0),"existing equipment aim control admitted"): return false
	var expected_angle: float = bench.applied.equipment.nozzle[2]
	if not await until(func() -> bool: return is_equal_approx(float(equipment_receipt().nozzle.angle),expected_angle),
		"native nozzle aim receipt matches authored setting"): return false
	if not check(bench.equipment.toggle("nozzle"),"existing nozzle control starts finite Water emission"): return false
	if not await until(func() -> bool: return bool(equipment_receipt().nozzle.on),"native owner confirms nozzle on"): return false
	if not check(bench.toggle_pause() and not host.paused,"combined Workbench enters physical simulation"): return false
	if not await until(func() -> bool:
		if host.latest_snapshot==null: return false
		var participation: Dictionary = host.latest_snapshot.native_worker_participation
		return int(worker.paint_state().tick)>=before_tick+8 and int(equipment_receipt().nozzle.emitted)>0 \
			and int(participation.get("workers_observed",0))>0,"native ticks, nozzle effects and worker participation observed"): return false
	var active: Dictionary = equipment_receipt().duplicate(true)
	var participation: Dictionary = host.latest_snapshot.native_worker_participation.duplicate(true)
	if not check(bench.equipment.stop_all(),"existing equipment Stop admitted"): return false
	if not await until(func() -> bool: return not bool(equipment_receipt().nozzle.on),"native owner confirms equipment Stop"): return false
	if not check(bench.toggle_pause() and host.paused,"combined Workbench pauses again before Save"): return false
	if not await until(func() -> bool: return ready() and bool(worker.paint_state().paused),"paused native boundary settled after physical simulation"): return false
	check(int(active.nozzle.injected_water)>0 and int(active.nozzle.emitted)>0,
		"equipment feedback confirms actual native Water emission")
	check(not bench.body_state(1).is_empty(),"same real Rapier actor remains available after simulation")
	check(bench.applied.edits==edits_before,"physical simulation and equipment do not rewrite authored edit history")
	check(editor._undo_stack.is_empty(),"simulation invalidates unsafe paused Undo history")
	simulation_evidence = {"tick_before":before_tick,"tick_after":worker.paint_state().tick,
		"nozzle_emitted":active.nozzle.emitted,"nozzle_injected_water":active.nozzle.injected_water,
		"participation":participation,"equipment_config":bench.applied.equipment.duplicate(true)}
	await screenshot("combined-equipment-simulation")
	phases.simulation_equipment = true
	return true

func author() -> void:
	if not await discover(): return
	dialog._extent.select(0 if map_side==512 else 1)
	dialog._preview_button.pressed.emit()
	if not await until(generator_ready,"actual Deepworks native preview",240000): return
	if not check(dialog._phase=="ready","actual Deepworks native preview accepted"): return
	var source: Dictionary = dialog._ready_packet.duplicate(true)
	if not check(source.cells.size()==map_side*map_side and source.extent==Vector2i(map_side,map_side)
		and not source.receipt_hashes.is_empty(),"complete native generated source and receipts"): return
	await screenshot("combined-generator-preview")
	dialog.confirmed.emit()
	dialog.hide()
	if not await until(ready,"generated map installed into the existing native Workbench"): return
	check(bench._generated_active.sha256==source.sha256 and host.latest_snapshot.backend_name=="native-phased",
		"same native Workbench owns the generated source")
	phases.generation = true
	bench._set_view(Vector2.ZERO,Vector2i(960,540))
	bench._brush.value = 0
	await process_frame
	var tick: int = worker.paint_state().tick
	if not await manual_tools(): return
	if not await large_adaptive_fill(): return
	if not await agent_authoring(): return
	if not await provider_completion_fixture(): return
	if not await human_after_agent(): return
	if not await stopped_agent_prefix(): return
	if not await undo_before_save(): return
	var actual: PackedInt32Array = await capture(AUTHOR_REGION)
	var actor_clear: PackedInt32Array = await capture(ACTOR_CLEARANCE)
	if not check(actual.size()==AUTHOR_REGION.get_area() and actor_clear.size()==ACTOR_CLEARANCE.get_area(),
		"complete affected regions captured independently from native owner"): return
	var expected_start: PackedByteArray = source.cells.duplicate()
	apply_region(expected_start,AUTHOR_REGION,actual)
	apply_region(expected_start,ACTOR_CLEARANCE,actor_clear)
	if map_side>=1024:
		var large_fill: PackedInt32Array = await capture(LARGE_FILL_REGION)
		if not check(large_fill.size()==LARGE_FILL_REGION.get_area(),"large Fill region captured for persistence expectation"): return
		apply_region(expected_start,LARGE_FILL_REGION,large_fill)
	var whole_native := await complete_native_materials()
	if not check(whole_native==expected_start,"every stored material in the complete generated World matches source plus confirmed edits"): return
	prepared_sha256 = Store.digest(expected_start)
	if not check(bench.place("midge",Vector2(448,400)),"real Midge actor placement admitted"): return
	if not await until(ready,"real actor and retained generated World installed"): return
	check(bench.select_instance(1) and not bench.body_state(1).is_empty(),"real Rapier actor selected")
	check(host.paused and int(worker.paint_state().tick)==tick,"save covers paused authored state without simulation evolution")
	check(Store.digest(bench._generated_active.cells)==source.sha256,"original generated source and provenance remain unchanged")
	if not await exercise_simulation_equipment(): return
	bench._name.text = SAVE_NAME
	if not check(bench.save_setup(),"named generated start saves both confirmed editors"): return
	var saved: Dictionary = Store.read_named(SAVE_NAME)
	if not check(saved.get("generated",false) and saved.setup.edits==bench.applied.edits,"existing generated format contains exact common edit record"): return
	var expectation := {"author_pid":OS.get_process_id(),"author_instance":process_instance,"generation":saved.generation,"edits":saved.setup.edits,
		"actors":saved.setup.actors,"selected":saved.setup.selected,"liquid_policy":saved.setup.liquid_policy,
		"response":saved.setup.response,"rule_radius":saved.setup.rule_radius,"brush":saved.setup.brush,
		"equipment":saved.setup.get("equipment",{}),
		"prepared_sha256":prepared_sha256,"native_region":Marshalls.raw_to_base64(PackedByteArray(Array(actual))),
		"provider_model":panel.model.text,"provider_context":panel.context_mode.selected,
		"source_identity":source_identity,"stop_prefix":stopped_prefix,"map_side":map_side,
		"agent_undo_saved":phases.agent_undo_saved}
	var file := FileAccess.open(EXPECTED_PATH,FileAccess.WRITE)
	if not check(file!=null,"independent native expectation file opened"): return
	file.store_string(JSON.stringify(expectation))
	file.close()
	phases.save = true
	bench._set_view(Vector2.ZERO,Vector2i(960,540))
	await screenshot("combined-authored-saved")
	author_complete = true

func reopen() -> void:
	if not await discover(): return
	dialog.hide()
	var file := FileAccess.open(EXPECTED_PATH,FileAccess.READ)
	if not check(file!=null,"prior-process native expectation exists"): return
	var expected: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not check(expected is Dictionary and str(expected.get("author_instance","")).length()==32 \
		and expected.author_instance!=process_instance,"reopen uses a fresh in-memory application instance"): return
	if not check(int(expected.get("map_side",512))==map_side,"fresh process uses the qualified map extent"): return
	var saved: Dictionary = Store.read_named(SAVE_NAME)
	if not check(saved.get("generated",false),"fresh process reads existing generated-start format"): return
	check(json_equivalent(saved.generation,expected.generation) and json_equivalent(saved.setup.edits,expected.edits),
		"fresh-process provenance and common authored record match")
	bench._name.text = SAVE_NAME
	if not check(bench.load_setup(),"ordinary Load start begins source regeneration"): return
	if not await until(generator_ready,"fresh-process native regeneration",240000): return
	if not check(dialog._phase=="ready","saved generation source and receipts verified"): return
	check(dialog._ready_packet.sha256==expected.generation.sha256
		and json_equivalent(dialog._ready_packet.receipt_hashes,expected.generation.receipt_hashes),"same native generator source receipts recovered")
	dialog.confirmed.emit()
	dialog.hide()
	if not await until(ready,"fresh-process combined start installed"): return
	if not await until(equipment_current,"fresh-process equipment configuration acknowledged"): return
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt",{})
	prepared_sha256 = str(receipt.get("generated_prepared_material_sha256",""))
	check(prepared_sha256==expected.prepared_sha256,"entire reconstructed native stored-material digest matches previous process")
	check(receipt.get("generated_source_sha256")==expected.generation.sha256,"original generator identity survives combined edits")
	var actual: PackedInt32Array = await capture(AUTHOR_REGION)
	check(PackedByteArray(Array(actual))==Marshalls.base64_to_raw(expected.native_region),
		"every human, agent, provider-fixture and stopped-prefix material cell survives restart")
	check(bool(expected.get("agent_undo_saved",false)) and await capture(UNDONE_AGENT_REGION)==PackedInt32Array([0,0,0]),
		"agent edit left undone before Save stays absent after complete process exit and reopening")
	if map_side>=1024:
		var filled := await capture(LARGE_FILL_REGION)
		var exact := filled.size()==LARGE_FILL_REGION.get_area()
		for index: int in filled.size():
			var x: int = index%LARGE_FILL_REGION.size.x
			var y: int = index/LARGE_FILL_REGION.size.x
			if filled[index]!=(58 if x in [0,385] or y in [0,385] else 2): exact=false
		check(exact,"all large-area Fill materials survive fresh-process reconstruction")
	check(json_equivalent(bench.applied.actors,expected.actors) and bench.applied.selected==expected.selected
		and not bench.body_state(1).is_empty(),"actor configuration and selected real Rapier actor survive restart")
	check(json_equivalent(bench.applied.liquid_policy,expected.liquid_policy) and bench.applied.response==expected.response
		and bench.applied.rule_radius==expected.rule_radius and bench.applied.brush==expected.brush,
		"solver, response and brush settings survive restart")
	var equipment := equipment_receipt()
	check(json_equivalent(bench.applied.get("equipment",{}),expected.equipment)
		and json_equivalent(equipment.config,expected.equipment),"authored equipment geometry, supply and tuning survive restart")
	check(not bool(equipment.nozzle.on) and int(equipment.nozzle.emitted)==0
		and int(equipment.pipe.stock)==int(expected.equipment.supply)*int(equipment.water_unit),
		"reopened equipment starts stopped with authored supply, without saved transient effects")
	check(panel.model.text==expected.provider_model and panel.context_mode.selected==expected.provider_context,
		"provider model and context settings survive restart")
	var resumed_prompt := false
	for turn: Dictionary in panel.conversation:
		if str(turn.get("content",""))==FOLLOWUP_PROMPT: resumed_prompt=true
	check(resumed_prompt,"persistent provider conversation resumes the prior fixture instruction")
	phases.reopen = true
	bench._set_view(Vector2.ZERO,Vector2i(960,540))
	bench._brush.value = 0
	await process_frame
	if not await gesture("Line",Vector2i(100,280),Vector2i(120,285),131): return
	check(await capture(Rect2i(100,280,1,1))==PackedInt32Array([131]),"human full-palette editing continues after reopen")
	var admission: Dictionary = art.submit([{"shape":"pixels","points":[[360,280]],"material":58}],AUTHOR_REGION,[],[0,58])
	if not check(admission.status=="queued","agent authoring continues after reopen"): return
	if not await until(settled,"new-process agent native completion"): return
	check(await capture(Rect2i(360,280,1,1))==PackedInt32Array([58]),"new-process agent edit reaches native stored grid")
	if not await history_control("undo","agent edit in the fresh process"): return
	check(await capture(Rect2i(360,280,1,1))==PackedInt32Array([0]),"agent Undo continues after reopening")
	if not await history_control("redo","agent edit in the fresh process"): return
	check(await capture(Rect2i(360,280,1,1))==PackedInt32Array([58]),"agent Redo continues after reopening")
	phases.continued_authoring = true
	await screenshot("combined-reopened-and-continued")
	reopen_complete = true

func run() -> void:
	if not check(map_side in [512,1024],"combined fixture map size is a qualified 512 or 1024"):
		quit(1)
		return
	source_identity = identity()
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	root.size = Vector2i(1440,1000)
	bench = host.shared_workbench
	editor = bench.paint_editor
	panel = bench.art_batches
	art = panel.executor
	worker = host.simulation_worker
	dialog = bench._generated_dialog
	var reopening := OS.get_environment("WB_COMBINED_REOPEN")=="1"
	var graphics_ok := OS.get_environment("WB_COMBINED_REQUIRE_GRAPHICS")!="1" or DisplayServer.get_name()!="headless"
	var initial_wait_started := Time.get_ticks_msec()
	# Allow cold graphical/native startup without extending authoring deadlines.
	var initial_ready := check(graphics_ok,"requested graphical backend is active") and await until(ready,"full native Shared Workbench installed",180000)
	print("WB_COMBINED_INITIAL_READY ",JSON.stringify({"ready":initial_ready,"budget_ms":180000,
		"wait_ms":Time.get_ticks_msec()-initial_wait_started,"startup_ms":(Time.get_ticks_usec()-started_usec)/1000,
		"applied":not bench.applied.is_empty(),"pending_install":not host.pending_microscenario_apply.is_empty(),
		"paint_editor_busy":editor.busy(),"worker_failed":worker.has_failed(),
		"paint":worker.paint_state(),"art":worker.art_state(),"workbench_message":bench.message,"host_error":host.microscenario_error}))
	if initial_ready:
		check(bench._material.item_count==131 and editor.get_parent()==bench,"complete PAINT palette and toolbar mounted with art panel")
		if reopening: await reopen()
		else: await author()
	if reopening:
		check(reopen_complete and phases.discovery and phases.reopen and phases.continued_authoring,
			"all mandatory fresh-process reopen and continued-authoring phases executed")
	else:
		for phase: String in ["discovery","generation","manual","leases","agent","provider_fixture",
			"late_response","human_after_agent","stop","agent_undo_saved","simulation_equipment","save"]:
			check(bool(phases[phase]),"mandatory combined author phase executed: "+phase)
		check(author_complete,"complete combined authoring flow reached Save")
	check(source_identity==identity(),"tested source and native runtime bytes did not change during execution")
	host.queue_free()
	await process_frame
	await process_frame
	print("WB_COMBINED_EVIDENCE ",JSON.stringify({"checks":checks,"failures":failures,"phases":phases,
		"author_complete":author_complete,"reopen_complete":reopen_complete,"profile_count":profile_count,
		"prepared_sha256":prepared_sha256,"stop_prefix":stopped_prefix,"map_side":map_side,"source_identity":source_identity,
		"simulation_equipment":simulation_evidence,
		"provider_qualification":"deterministic completion fixture; separate transport suite; no inference",
		"elapsed_usec":Time.get_ticks_usec()-started_usec}))
	print("WB_COMBINED_AUTHORING checks=%d failures=%d author_complete=%s reopen_complete=%s" % [
		checks,failures.size(),str(author_complete),str(reopen_complete)])
	quit(1 if not failures.is_empty() else 0)
