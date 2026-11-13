extends SceneTree
## Mounted Select gestures, compact controls and append-only conversation editing.
## Deterministic native Workbench; no provider/network request is made.
const Setup = preload("res://scripts/workbench_setup.gd")
const Provider = preload("res://scripts/art_provider.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true
var host: Control
var bench: Control
var editor: Control
var panel: Window
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("ART_PANEL_UI_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)
	return ok

func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+120000
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return check(false,label)

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() and not editor.busy() \
		and host.pending_microscenario_apply.is_empty() and not host.simulation_worker.paint_state().busy

func local(cell: Vector2i) -> Vector2:
	var view: Rect2 = host.view_content_rect()
	return view.position+(Vector2(cell)+Vector2(0.5,0.5)-Vector2(host.camera_origin.floor()))*view.size/Vector2(host.current_view_size)

func select_area(a: Vector2i,b: Vector2i) -> void:
	editor.select_tool("Select")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = local(a)
	bench._world_input(press)
	var move := InputEventMouseMotion.new()
	move.position = local(b)
	bench._world_input(move)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = local(b)
	bench._world_input(release)

func selection_checks() -> void:
	panel.show()
	await process_frame
	var native_before: Dictionary = host.simulation_worker.paint_state()
	var authored_before: Array = bench.applied.edits.duplicate(true)
	select_area(Vector2i(40,40),Vector2i(63,51))
	check(editor.selection == Rect2i(40,40,24,12),"real Select preserves inclusive endpoints")
	check(panel.rectangle(panel.fields) == editor.selection,"visible panel autofills X/Y/W/H")
	panel.fields[0].value = 111
	select_area(Vector2i(63,51),Vector2i(40,40))
	check(panel.rectangle(panel.fields) == Rect2i(40,40,24,12),"repeated reverse drag updates manually changed fields")
	select_area(Vector2i(44,44),Vector2i(44,44))
	check(panel.rectangle(panel.fields) == Rect2i(44,44,1,1),"single-cell selection is 1 by 1")
	panel.hide()
	select_area(Vector2i(70,70),Vector2i(80,80))
	check(panel.rectangle(panel.fields) == Rect2i(44,44,1,1),"hidden panel does not follow Select")
	panel.show()
	check(panel.rectangle(panel.fields) == Rect2i(44,44,1,1),"reveal does not replace custom bounds with stale selection")
	bench._set_view(Vector2(24,20),Vector2i(240,135))
	await process_frame
	select_area(Vector2i(90,75),Vector2i(100,80))
	check(panel.rectangle(panel.fields) == Rect2i(90,75,11,6),"pan and zoom use world-cell focus coordinates")
	panel.request_area = Rect2i(2,3,4,5)
	var old_guards: Array = panel.request_guards.duplicate(true)
	panel.focus_selection(Rect2i(-5,-6,10,12))
	check(panel.rectangle(panel.fields) == Rect2i(0,0,5,6),"focus is clipped to native bounds")
	check(panel.request_area == Rect2i(2,3,4,5) and panel.request_guards == old_guards,"new focus never retargets captured provider scope or guards")
	panel.focus_selection(Rect2i())
	check(panel.rectangle(panel.fields) == Rect2i(0,0,5,6),"empty selection leaves fields intact")
	check(bench.applied.edits == authored_before and host.simulation_worker.paint_state().revision == native_before.revision,"selection updates do not mutate native materials or authoring history")

func layout_checks() -> void:
	check(panel.size == Vector2i(640,400) and panel.min_size == Vector2i(520,320),"compact default and minimum window sizes")
	check(panel.draw.get_parent() == panel.undo_button.get_parent() and panel.stop.get_parent() == panel.redo_button.get_parent(),"send stop and shared history occupy one toolbar")
	check(not panel.protected_row.visible,"unused protected bounds do not consume a row")
	panel.protect.button_pressed = true
	check(panel.protected_row.visible,"protection bounds remain accessible")
	panel.protect.button_pressed = false
	for text: TextEdit in [panel.guidance,panel.stencil_guidance]:
		check(text.wrap_mode == TextEdit.LINE_WRAPPING_BOUNDARY and text.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,"both guidance editors word wrap")
	var dialog = panel.guidance.get_parent()
	dialog.popup_centered(Vector2i(380,240))
	await process_frame
	await process_frame
	check(panel.guidance.get_line_wrap_count(0)>0,"long guidance actually wraps at a narrow popup width")
	dialog.hide()
	for width: int in [640,520]:
		panel.size = Vector2i(width,400)
		for i: int in range(3): await process_frame
		for control: Control in [panel.draw,panel.stop,panel.undo_button,panel.redo_button,panel.endpoint,panel.tokens,panel.seconds,panel.conversation_button,panel.input,panel.paint_material]:
			var rect: Rect2 = control.get_global_rect()
			check(rect.position.x >= 0 and rect.end.x <= panel.size.x+1,"compact control fits window width: "+str(width)+" / "+control.get_class())
		check(panel.input.size.y >= 64 and panel.state.get_global_rect().end.y <= panel.size.y+1,"prompt and status fit compact window")
	panel.size = Vector2i(640,400)

func conversation_checks() -> void:
	panel.conversation.clear()
	panel.context_mode.select(0)
	panel.remember_turn("user","Original request")
	panel.remember_turn("assistant","[]")
	panel.last_result = "native-confirmed fixture result"
	var dialog = panel.conversation_editor
	panel.conversation_button.pressed.emit()
	check(dialog.visible and dialog.messages.item_count == 2,"Conversation button opens complete transcript")
	dialog.content.text = "Edited request"
	check(panel.conversation[0].content == "Original request","draft text does not mutate live history")
	dialog.get_cancel_button().pressed.emit()
	check(panel.conversation[0].content == "Original request","Cancel discards draft edits")
	panel._open_conversation()
	dialog.content.text = "Edited request"
	var disk_before := FileAccess.get_file_as_string(panel.provider.log_path)
	var native_before: Dictionary = host.simulation_worker.paint_state()
	var authored_before: Array = bench.applied.edits.duplicate(true)
	panel._apply_conversation_edits()
	check(not dialog.visible and panel.conversation[0].content == "Edited request","Apply replaces future conversation context")
	check(panel.model_context()[0].content == "Edited request","next Full context reads edited text")
	var disk_after := FileAccess.get_file_as_string(panel.provider.log_path)
	check(disk_after.begins_with(disk_before) and disk_after.contains('"kind":"conversation_edited"'),"edit appends one snapshot without rewriting raw audit")
	check(bench.applied.edits == authored_before and host.simulation_worker.paint_state().revision == native_before.revision,"history editing never draws or changes native receipts")
	var resumed := Provider.new()
	root.add_child(resumed)
	check(resumed.resume_traffic(panel.provider.log_path) == panel.conversation,"edited transcript survives reopening traffic")
	check(resumed.resumed_last_result == panel.last_result,"native feedback remains independent of editable transcript")
	var resume_path: String = resumed.log_path
	resumed.queue_free()
	if not resume_path.is_empty(): DirAccess.remove_absolute(resume_path)
	panel._open_conversation()
	dialog.content.text = "Must not overwrite a new turn"
	panel.remember_turn("assistant","new live turn")
	panel._apply_conversation_edits()
	check(dialog.visible and panel.conversation.size() == 3 and panel.conversation[0].content == "Edited request","stale editor cannot overwrite new conversation turns")
	panel._open_conversation()
	dialog.content.text = "Wait until stopped"
	panel.provider.active = true
	panel._apply_conversation_edits()
	check(dialog.visible and panel.conversation[0].content == "Edited request","active provider prevents applying draft")
	panel.provider.active = false
	panel.remaining_turns = 1
	panel._apply_conversation_edits()
	check(panel.conversation[0].content == "Edited request","scheduled turns also prevent history edits")
	panel.remaining_turns = 0
	panel._open_conversation()
	dialog.content.text = "Cannot save"
	var original_path: String = panel.provider.log_path
	panel.provider.log_path = "user://missing-art-ui-folder/no/log.jsonl"
	panel._apply_conversation_edits()
	check(dialog.visible and panel.conversation[0].content == "Edited request" and panel.conversation_error.contains("Could not save"),"disk failure refuses edit without losing live conversation")
	panel.provider.log_path = original_path
	panel.provider.log_warning = ""
	panel._open_conversation()
	panel.provider.secrets.append("art-ui-fixture-secret")
	dialog.content.text = "Remove art-ui-fixture-secret"
	panel._apply_conversation_edits()
	check(not panel.conversation[0].content.contains("art-ui-fixture-secret"),"edited conversation preserves credential redaction")
	panel.provider.secrets.clear()
	panel._open_conversation()
	dialog.draft.clear()
	panel._apply_conversation_edits()
	check(panel.conversation.is_empty() and panel.model_context().is_empty(),"Clear draft plus Apply clears future context")
	resumed = Provider.new()
	root.add_child(resumed)
	check(resumed.resume_traffic(panel.provider.log_path).is_empty(),"cleared transcript stays cleared after reopen")
	resume_path = resumed.log_path
	resumed.queue_free()
	if not resume_path.is_empty(): DirAccess.remove_absolute(resume_path)
	for invalid: Variant in [null,{},[{"role":"system","content":"not a conversation role"}],[{"role":"user","content":3}],[{"role":"user","content":"x","image_offset":-1}]]:
		check(Provider.checked_conversation(invalid) == null,"invalid transcript rejected without runtime errors")

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	bench = host.shared_workbench
	editor = bench.paint_editor
	panel = bench.art_batches
	if not await until(ready,"native Workbench ready"):
		quit(1)
		return
	var fresh: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	check(bench.apply(fresh),"fresh 512 map admitted")
	if await until(ready,"fresh map installed"):
		bench._set_view(Vector2.ZERO,Vector2i(480,270))
		await process_frame
		await selection_checks()
		await layout_checks()
		conversation_checks()
	host.queue_free()
	await process_frame
	await process_frame
	print("ART_PANEL_UI ",JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}))
	quit(0 if failures.is_empty() else 1)
