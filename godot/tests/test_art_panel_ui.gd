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

func window_screen_rect(window: Window) -> Rect2:
	return window.get_screen_transform()*window.get_visible_rect()

func control_screen_rect(control: Control) -> Rect2:
	return control.get_viewport().get_screen_transform()*(control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size))

func button_with_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child: Node in node.get_children():
		var found := button_with_text(child,text)
		if found != null: return found
	return null

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
	for i: int in 2: await process_frame
	check(panel.last_visible_ui_usec > 0,"visible control projection exposes a bounded numerical timing receipt")
	panel.hide()
	for i: int in 2: await process_frame
	check(panel.last_visible_ui_usec == 0,"hidden Art reports no visible control projection work")
	panel.show()
	await process_frame
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
	# Owner regression #713: long Note content and notices must never move the
	# popup or its Apply/Cancel footer outside the actual root viewport. Art does
	# not embed its own subwindows, so this popup can be larger than small Art.
	var original_root_size: Vector2i = root.size
	var requested_root_size := Vector2i(1280,720)
	root.size = requested_root_size
	var conversation_dialog = panel.conversation_editor
	for art_size: Vector2i in [Vector2i(520,320),Vector2i(640,400)]:
		panel.size = art_size
		panel._open_conversation()
		for i: int in range(3): await process_frame
		conversation_dialog.draft.append({"role":"user","content":("long note content\n").repeat(400),"image_offset":0})
		conversation_dialog._rebuild(conversation_dialog.draft.size()-1)
		panel.conversation_error = ("A long validation notice must scroll, not resize the footer. ").repeat(70)
		panel._update_conversation_guard()
		for i: int in range(3): await process_frame
		# The screen transforms follow the real embedder and canvas scale. Adding
		# the Node parent's Art position would misplace this root-embedded popup.
		var root_rect := window_screen_rect(root)
		var popup_rect := window_screen_rect(conversation_dialog)
		var ok_button: Button = conversation_dialog.get_ok_button()
		var cancel_button: Button = conversation_dialog.get_cancel_button()
		var apply_rect := control_screen_rect(ok_button)
		var cancel_rect := control_screen_rect(cancel_button)
		print("ART_CONVERSATION_LAYOUT ",JSON.stringify({
			"requested_root_size":requested_root_size,"actual_root_size":root.size,
			"root_visible_rect":root.get_visible_rect(),"root_screen_rect":root_rect,
			"art_size":art_size,"art_screen_rect":window_screen_rect(panel),
			"root_embeds_subwindows":root.gui_embed_subwindows,
			"art_embeds_subwindows":panel.gui_embed_subwindows,"popup_embedded":conversation_dialog.is_embedded(),
			"popup_position":conversation_dialog.position,"popup_size":conversation_dialog.size,
			"popup_screen_rect":popup_rect,"apply_screen_rect":apply_rect,"cancel_screen_rect":cancel_rect,
			"apply_visible":ok_button.is_visible_in_tree(),"cancel_visible":cancel_button.is_visible_in_tree()}))
		check(root_rect.encloses(popup_rect),
			"Conversation stays within its actual root viewport beside small Art: "+str(art_size))
		check(root_rect.encloses(apply_rect) and root_rect.encloses(cancel_rect),
			"Apply and Cancel stay within the actual root viewport after long Note: "+str(art_size))
		check(ok_button.is_visible_in_tree() and popup_rect.encloses(apply_rect),
			"Apply footer remains clickable after long Note: "+str(art_size))
		check(cancel_button.is_visible_in_tree() and popup_rect.encloses(cancel_rect),
			"Cancel footer remains clickable after long Note: "+str(art_size))
		conversation_dialog.get_cancel_button().pressed.emit()
		# Closing a nested Window can be deferred to a later frame. Drain that
		# lifecycle before the next iteration opens it again; otherwise the
		# previous Cancel can hide the freshly opened dialog.
		for i: int in range(2): await process_frame
		conversation_dialog.hide()
		for i: int in range(2): await process_frame
		panel.conversation_error = ""
	root.size = original_root_size
	panel.size = Vector2i(640,400)

func collaboration_layout_checks() -> void:
	var original_root_size := root.size
	var original_focus: Rect2i = panel.rectangle(panel.fields)
	var native_before: Dictionary = host.simulation_worker.paint_state()
	var serial_before: int = panel.provider.serial
	var requests_before: int = panel.provider.traffic.count('"kind":"request"')
	root.size = Vector2i(1280,900)
	panel.size = Vector2i(640,400)
	panel.hide()
	bench.open_art_batches()
	for frame: int in 3: await process_frame
	panel.show_collaboration(true)
	var view = panel.collaboration_workspace
	view.tabs.current_tab = 3
	panel.collaboration.select_region("bounded")
	panel.collaboration.inspect_context({"native":true,"knowledge":false,"recent":true,"image":false,"image_scope":"selected"})
	await until(func() -> bool: return not panel.collaboration.busy(),"integrated context observation finishes")
	for frame: int in 4: await process_frame
	check(not panel.collaboration.context.is_empty() and not view.context_text.text.is_empty(),
		"integrated Context displays actual bounded native observation")
	check(panel.size == Vector2i(820,620) and panel.min_size == Vector2i(520,320),
		"first explicit Collaborate expands a compact opening and preserves the minimum")
	var scroll: ScrollContainer = view.context_text.get_parent().get_parent()
	var popup_rect := window_screen_rect(panel)
	var text_rect := control_screen_rect(view.context_text)
	var scroll_rect := control_screen_rect(scroll)
	var visible_text := text_rect.intersection(scroll_rect).intersection(popup_rect)
	print("ART_COLLABORATION_INTEGRATED_LAYOUT ",JSON.stringify({"display":DisplayServer.get_name(),
		"window_size":panel.size,"window_screen":popup_rect,"context_reader_screen":text_rect,
		"context_scroll_screen":scroll_rect,"visible_context_text_screen":visible_text,
		"native_source":panel.collaboration.context.get("source",{}),"provider_serial":panel.provider.serial}))
	check(visible_text.size.y >= 160 and visible_text.size.x >= 400,
		"first integrated Context exposes at least 160 visible reader pixels inside its clipping viewport")
	check(window_screen_rect(root).encloses(popup_rect),
		"first integrated collaboration window is centered inside the actual Workbench viewport")
	for control: Control in [view.send_button,view.stop_button,view.authorize,panel.collaboration_button]:
		check(popup_rect.encloses(control_screen_rect(control)),
			"integrated default collaboration control is reachable: "+control.get_class())
	var evidence := OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if not evidence.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(evidence)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(evidence.path_join("art-integrated-context.png")) == OK,
			"ordinary Workbench integrated Context framebuffer retained")
	panel.size = Vector2i(600,420)
	panel.show_collaboration(false)
	panel.show_collaboration(true)
	for frame: int in 3: await process_frame
	check(panel.size == Vector2i(600,420),"later mode switches preserve the owner's manual window size")
	panel.size = Vector2i(520,320)
	for tab: int in 4:
		view.tabs.current_tab = tab
		for frame: int in 3: await process_frame
		var compact_rect := window_screen_rect(panel)
		for control: Control in [view.send_button,view.stop_button,panel.collaboration_button]:
			check(compact_rect.encloses(control_screen_rect(control)),
				"integrated minimum keeps shared actions reachable on tab "+str(tab))
		if tab == 1:
			check(compact_rect.encloses(control_screen_rect(view.brief_apply)) and compact_rect.encloses(control_screen_rect(view.brief_cancel)),
				"integrated minimum keeps brief Apply and Cancel reachable")
		elif tab == 2:
			for control: Control in [view.preview_button,view.approve_button,view.revise_button,view.skip_button,view.proposal_copy]:
				check(compact_rect.encloses(control_screen_rect(control)),
					"integrated minimum keeps proposal action reachable: "+control.name)
		elif tab == 3:
			var visible_scroll := control_screen_rect(scroll).intersection(compact_rect)
			check(visible_scroll.size.y > 0 and visible_scroll.size.x > 0,
				"integrated minimum retains a visible scroll viewport for Context controls and disclosure")
			check(view.request_state.max_lines_visible == 1 and view.notice.max_lines_visible == 1,
				"compact integrated status uses one line to preserve page space")
			check(not view.request_state.tooltip_text.is_empty() and not view.notice.tooltip_text.is_empty(),
				"compact status and notice retain their complete tooltip text")
	check(panel.provider.serial == serial_before and panel.provider.traffic.count('"kind":"request"') == requests_before,
		"opening, inspecting and resizing collaboration dispatches no HTTP or model request")
	check(host.simulation_worker.paint_state().revision == native_before.revision,
		"integrated layout and native context inspection perform no World mutation")
	panel.show_collaboration(false)
	panel.size = Vector2i(640,400)
	panel.focus_selection(original_focus)
	root.size = original_root_size

func conversation_resize_checks() -> void:
	# A normal short Note should use new vertical space when the owner resizes
	# the dialog. The separate footer must remain reachable at both sizes.
	var original_root_size := root.size
	var original_panel_size := panel.size
	var original_history: Array = panel.conversation.duplicate(true)
	var original_error: String = panel.conversation_error
	var dialog = panel.conversation_editor
	var original_dialog_size: Vector2i = dialog.size
	var original_dialog_scale: float = dialog.content_scale_factor
	root.size = Vector2i(1280,720)
	panel.size = Vector2i(640,400)
	dialog.content_scale_factor = 1.0
	panel._open_conversation()
	var note := button_with_text(dialog,"+ Note")
	var text_heights: Array[float] = []
	if check(note != null,"normal Conversation exposes the ordinary + Note control for resize qualification"):
		note.pressed.emit()
		dialog.content.text = "A short editable note should use the available dialog height."
		dialog.content.text_changed.emit()
		for height: int in [360,560]:
			dialog.size = Vector2i(760,height)
			for i: int in 3: await process_frame
			var popup_rect := window_screen_rect(dialog)
			var root_rect := window_screen_rect(root)
			var text_rect := control_screen_rect(dialog.content)
			var apply_rect := control_screen_rect(dialog.get_ok_button())
			var cancel_rect := control_screen_rect(dialog.get_cancel_button())
			text_heights.append(dialog.content.size.y)
			print("ART_CONVERSATION_RESIZE_LAYOUT ",JSON.stringify({"requested_popup_height":height,
				"actual_popup_size":dialog.size,"root_size":root.size,"root_screen_rect":root_rect,
				"popup_screen_rect":popup_rect,"text_screen_rect":text_rect,"text_logical_height":dialog.content.size.y,
				"apply_screen_rect":apply_rect,"cancel_screen_rect":cancel_rect,"display":DisplayServer.get_name()}))
			check(root_rect.encloses(popup_rect) and popup_rect.encloses(text_rect),
				"resized normal Note and its text pane remain within the root viewport: "+str(height))
			check(dialog.get_ok_button().is_visible_in_tree() and dialog.get_cancel_button().is_visible_in_tree() \
				and popup_rect.encloses(apply_rect) and popup_rect.encloses(cancel_rect) \
				and root_rect.encloses(apply_rect) and root_rect.encloses(cancel_rect),
				"resized normal Note keeps Apply and Cancel reachable: "+str(height))
	check(text_heights.size()==2 and text_heights[1]-text_heights[0]>=190.0,
		"normal Note text pane uses at least 190 of 200 added logical pixels")
	dialog.get_cancel_button().pressed.emit()
	for i: int in 3: await process_frame
	check(not dialog.visible and panel.conversation==original_history,
		"Cancel after normal Note resizing discards the draft and preserves live conversation")
	dialog.content_scale_factor = original_dialog_scale
	dialog.size = original_dialog_size
	panel.conversation_error = original_error
	panel.size = original_panel_size
	root.size = original_root_size

func scaled_layout_checks() -> void:
	var original_root_size := root.size
	var dialog = panel.conversation_editor
	for root_size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = root_size
		for scale: float in [1.0,1.25,1.5]:
			panel.content_scale_factor = scale
			dialog.content_scale_factor = scale
			for logical_size: Vector2i in [Vector2i(520,320),Vector2i(640,400)]:
				panel.size = Vector2i((Vector2(logical_size)*scale).ceil())
				panel._open_conversation()
				var note := button_with_text(dialog,"+ Note")
				check(note != null,"ordinary + Note control is available")
				note.pressed.emit()
				dialog.content.text = ("Long note content\n").repeat(400)
				panel.conversation_error = ("Long validation notice must scroll. ").repeat(70)
				panel._update_conversation_guard()
				for i: int in 3: await process_frame
				var label := "%s / %.2f / %s" % [root_size,scale,logical_size]
				var popup_rect := window_screen_rect(dialog)
				var apply_rect := control_screen_rect(dialog.get_ok_button())
				var cancel_rect := control_screen_rect(dialog.get_cancel_button())
				check(popup_rect.encloses(apply_rect) and popup_rect.encloses(cancel_rect),
					"scaled Apply and Cancel remain within actual popup content: "+label)
				check(window_screen_rect(root).encloses(apply_rect) and window_screen_rect(root).encloses(cancel_rect),
					"scaled Apply and Cancel remain within desktop viewport: "+label)
				for control: Control in [panel.draw,panel.stop,panel.endpoint,panel.conversation_button,panel.input,panel.state]:
					check(window_screen_rect(panel).encloses(control_screen_rect(control)),
						"scaled ordinary Art control remains reachable: "+label+" / "+control.get_class())
				print("ART_CONVERSATION_SCALED_LAYOUT ",JSON.stringify({"root":root_size,"scale":scale,
					"logical_art_size":logical_size,"art_size":panel.size,"popup_screen":popup_rect,
					"apply_screen":apply_rect,"cancel_screen":cancel_rect,"display":DisplayServer.get_name()}))
				dialog.get_cancel_button().pressed.emit()
				for i: int in 2: await process_frame
				panel.conversation_error = ""
			# Traffic and guidance are independent windows. Long status/path text
			# must not push the traffic editor below the visible content area.
			panel.traffic_window.content_scale_factor = scale
			panel._show_scaled_window(panel.traffic_window,Vector2i(900,600))
			panel._set_traffic_path(("Long diagnostic path / export status ").repeat(200))
			var guidance_window: Window = panel.guidance.get_parent()
			guidance_window.content_scale_factor = scale
			panel._show_scaled_window(guidance_window,Vector2i(700,400))
			for i: int in 3: await process_frame
			print("ART_AUXILIARY_SCALED_LAYOUT ",JSON.stringify({"root":root_size,"root_viewport":root.get_visible_rect(),
				"scale":scale,"traffic_size":panel.traffic_window.size,"guidance_size":guidance_window.size,
				"art_embeds_subwindows":panel.gui_embed_subwindows,"root_embeds_subwindows":root.gui_embed_subwindows,
				"native_usable_screen":DisplayServer.screen_get_usable_rect(panel.traffic_window.current_screen),
				"traffic_screen":window_screen_rect(panel.traffic_window),"guidance_screen":window_screen_rect(guidance_window)}))
			for control: Control in [panel.export_button,panel.export_cancel,panel.traffic_text]:
				check(window_screen_rect(panel.traffic_window).encloses(control_screen_rect(control)),
					"traffic control remains visible with long status at scale %.2f / %s" % [scale,control.get_class()])
				check(window_screen_rect(root).encloses(control_screen_rect(control)),
					"traffic control stays on the root viewport at scale %.2f / %s" % [scale,control.get_class()])
			if scale == 1.0:
				# Godot 4.7 Window::_popup_base clamps even embedded popups to
				# DisplayServer's usable screen. The headless dummy reports zero;
				# preferred popup size therefore needs the real display-backed run.
				# All control/root reachability assertions above still run headless.
				var usable_screen := DisplayServer.screen_get_usable_rect(panel.traffic_window.current_screen).size
				if usable_screen.x >= 900 and usable_screen.y >= 600:
					check(panel.traffic_window.size == Vector2i(900,600),
						"Traffic preserves its preferred 900x600 size when the root has room")
					check(guidance_window.size == Vector2i(700,400),
						"Guidance preserves its preferred 700x400 size when the root has room")
				else:
					print("ART_AUXILIARY_PREFERRED_SIZE_UNQUALIFIED ",JSON.stringify({"display":DisplayServer.get_name(),
						"usable_screen":usable_screen,"root":root_size}))
			check(panel.traffic_text.size.y > 100 and panel.traffic_path.tooltip_text.length() > 1000,
				"long traffic status is bounded with its full value available in tooltip")
			check(window_screen_rect(guidance_window).encloses(control_screen_rect(panel.guidance)),
				"guidance editor remains inside its scaled window")
			check(window_screen_rect(root).encloses(control_screen_rect(panel.guidance)),
				"scaled guidance remains inside the root viewport")
			panel.traffic_window.hide()
			guidance_window.hide()
	panel.content_scale_factor = 1.0
	dialog.content_scale_factor = 1.0
	panel.traffic_window.content_scale_factor = 1.0
	panel.guidance.get_parent().content_scale_factor = 1.0
	panel.size = Vector2i(640,400)
	root.size = original_root_size
	panel._set_traffic_path("")

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
	check(resumed.log_path.is_empty() and resumed.parent_log_path == panel.provider.log_path,"read-only transcript replay does not copy traffic")
	var resume_path: String = resumed.log_path
	resumed.queue_free()
	if not resume_path.is_empty(): DirAccess.remove_absolute(resume_path)
	panel._open_conversation()
	dialog.content.text = "Must not overwrite a new turn"
	panel.remember_turn("assistant","new live turn")
	panel._update_conversation_guard()
	check(dialog.get_ok_button().disabled,"new live turns invalidate the editor without repeatedly comparing transcript content")
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
	dialog.content.text = "Must not overwrite an in-place change"
	panel.conversation[0].content = "out-of-band changed turn"
	panel._apply_conversation_edits()
	check(dialog.visible and panel.conversation[0].content == "out-of-band changed turn",
		"Apply performs full snapshot validation even for an unexpected in-place mutation")
	panel.conversation[0].content = "Edited request"
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
	check(resumed.log_path.is_empty(),"cleared transcript replay creates no duplicate archive")
	resume_path = resumed.log_path
	resumed.queue_free()
	if not resume_path.is_empty(): DirAccess.remove_absolute(resume_path)
	for invalid: Variant in [null,{},[{"role":"system","content":"not a conversation role"}],[{"role":"user","content":3}],[{"role":"user","content":"x","image_offset":-1}]]:
		check(Provider.checked_conversation(invalid) == null,"invalid transcript rejected without runtime errors")

func large_conversation_checks() -> void:
	# Exercise the actual dialog at its admitted turn capacity. UI list filling
	# yields between slices; a complete immutable draft exists before Apply.
	var original: Array = panel.conversation
	panel.conversation = []
	for i: int in Provider.MAX_CONVERSATION_TURNS:
		panel.conversation.append({"role":"user","content":"A short editable message %d" % i})
	var started := Time.get_ticks_usec()
	panel._open_conversation()
	var opening_usec := Time.get_ticks_usec()-started
	var dialog = panel.conversation_editor
	check(dialog.list_loading and dialog.messages.item_count < panel.conversation.size(),
		"large message list yields instead of adding every row in one UI callback")
	check(dialog.last_list_slice_items > 0 and dialog.last_list_slice_items <= dialog.LIST_ITEMS_PER_FRAME
		and dialog.last_list_slice_usec > 0 and dialog.max_list_slice_usec >= dialog.last_list_slice_usec,
		"list population records its bounded item count and script work timing")
	check(dialog.draft.size() == Provider.MAX_CONVERSATION_TURNS,
		"yielding list population retains the complete editable draft")
	var note := button_with_text(dialog,"+ Note")
	note.pressed.emit()
	check(dialog.list_loading and dialog.draft.size() == Provider.MAX_CONVERSATION_TURNS+1,
		"+ Note remains responsive while the long message list is populating")
	dialog.remove_button.pressed.emit()
	check(dialog.list_loading and dialog.draft.size() == Provider.MAX_CONVERSATION_TURNS,
		"Remove remains responsive while the long message list is populating")
	dialog.messages.select(0)
	dialog.messages.item_selected.emit(0)
	dialog.content.text = "Updated while list is filling"
	dialog.content.text_changed.emit()
	check(dialog.draft[0].content == "A short editable message 0",
		"typing updates its caption without serializing the entire message into the draft each key")
	dialog.flush_message()
	check(dialog.draft[0].content == "Updated while list is filling"
		and dialog.baseline[0].content == "A short editable message 0"
		and panel.conversation[0].content == "A short editable message 0",
		"message flush owns its changed entry without mutating the baseline or live context")
	started = Time.get_ticks_usec()
	for i: int in 100: panel._update_conversation_guard()
	var guard_usec := Time.get_ticks_usec()-started
	# Closing during list population must not reopen the editor or continue
	# building a hidden list. Reopening creates a fresh independent generation.
	dialog.get_cancel_button().pressed.emit()
	for i: int in 3: await process_frame
	check(not dialog.visible and not dialog.list_loading,
		"Cancel during large list population stops hidden layout work")
	panel.conversation = [{"role":"user","content":"fresh short conversation"}]
	panel._open_conversation()
	for i: int in 3: await process_frame
	check(dialog.messages.item_count == 1 and dialog.content.text == "fresh short conversation",
		"reopen cannot receive rows from a cancelled older list generation")
	var long_note := ("long note line\n").repeat(2000)
	dialog.content.text = long_note
	dialog.content.text_changed.emit()
	dialog.flush_message()
	var caption: String = dialog.messages.get_item_text(0)
	check(dialog.draft[0].content == long_note and "".join(dialog._pages) == long_note
		and dialog.content.text == dialog._pages[dialog._page_index]
		and dialog.content.text.length() <= dialog.PAGE_CHARACTERS
		and caption.length() < 100 and caption.contains("long note line"),
		"long note keeps complete text across bounded visible parts with a readable caption")
	dialog.hide()
	panel.conversation = []
	for i: int in Provider.MAX_CONVERSATION_TURNS:
		panel.conversation.append({"role":"user","content":"List completion message %d" % i})
	var fill_started := Time.get_ticks_usec()
	panel._open_conversation()
	var initial_items: int = dialog.messages.item_count
	var previous_items := initial_items
	var fill_frames := 0
	var idle_frames := 0
	var max_item_delta := 0
	var min_item_delta: int = dialog.LIST_ITEMS_PER_FRAME
	var progress_valid := true
	var last_frame_usec := fill_started
	var max_frame_gap_usec := 0
	# This is a frame-paced algorithm, not a minimum-FPS promise. Each active
	# slice adds 1..128 rows with a 2ms script budget. Allow two observer-order
	# idle frames, then require monotonic progress. The remaining row count gives
	# a finite frame watchdog; the existing 240s suite ceiling remains in force.
	# Responsiveness is checked separately using every actual adjacent-frame gap.
	var completion_frame_limit := Provider.MAX_CONVERSATION_TURNS-initial_items+2
	while dialog.list_loading and fill_frames < completion_frame_limit:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		max_frame_gap_usec = maxi(max_frame_gap_usec,now_usec-last_frame_usec)
		last_frame_usec = now_usec
		fill_frames += 1
		var item_count: int = dialog.messages.item_count
		var item_delta := item_count-previous_items
		previous_items = item_count
		max_item_delta = maxi(max_item_delta,item_delta)
		if item_delta > 0: min_item_delta = mini(min_item_delta,item_delta)
		if item_delta == 0 and dialog.list_loading: idle_frames += 1
		if item_delta < 0 or item_delta > dialog.LIST_ITEMS_PER_FRAME \
			or item_count > Provider.MAX_CONVERSATION_TURNS or idle_frames > 2:
			progress_valid = false
		if fill_frames % 16 == 0 or not dialog.list_loading:
			print("ART_CONVERSATION_LIST_PROGRESS ",JSON.stringify({"frames":fill_frames,
				"items":item_count,"elapsed_usec":now_usec-fill_started,
				"max_frame_gap_usec":max_frame_gap_usec,"max_list_slice_usec":dialog.max_list_slice_usec}))
		if not progress_valid or max_frame_gap_usec > 2000000: break
	var list_complete: bool = not dialog.list_loading and dialog.messages.item_count == Provider.MAX_CONVERSATION_TURNS
	var final_settle_frames := 0
	if list_complete:
		# The final slice requests deferred ItemList layout. Include the next
		# frame so its cost cannot escape when list_loading becomes false.
		await process_frame
		var settled_usec := Time.get_ticks_usec()
		max_frame_gap_usec = maxi(max_frame_gap_usec,settled_usec-last_frame_usec)
		final_settle_frames = 1
	print("ART_CONVERSATION_LIST_COMPLETION ",JSON.stringify({"items":dialog.messages.item_count,
		"expected_items":Provider.MAX_CONVERSATION_TURNS,"complete":list_complete,
		"initial_items":initial_items,"fill_frames":fill_frames,"idle_frames":idle_frames,
		"completion_frame_limit":completion_frame_limit,"suite_completion_ceiling_seconds":240,
		"elapsed_usec":Time.get_ticks_usec()-fill_started,"final_settle_frames":final_settle_frames,
		"min_item_delta":min_item_delta,"max_item_delta":max_item_delta,"progress_valid":progress_valid,
		"max_frame_gap_usec":max_frame_gap_usec,"frame_gap_limit_usec":2000000,
		"script_items_per_slice":dialog.LIST_ITEMS_PER_FRAME,"script_budget_usec":dialog.LIST_BUDGET_USEC,
		"last_list_slice_usec":dialog.last_list_slice_usec,"max_list_slice_usec":dialog.max_list_slice_usec,
		"display":DisplayServer.get_name()}))
	check(progress_valid and fill_frames <= completion_frame_limit,
		"incremental population makes bounded monotonic progress between frames")
	check(max_frame_gap_usec <= 2000000,
		"large message list including final deferred layout keeps adjacent frames within two seconds")
	check(list_complete,
		"incremental population exposes every admitted conversation turn")
	if list_complete:
		dialog.messages.select(Provider.MAX_CONVERSATION_TURNS-1)
		dialog.messages.item_selected.emit(Provider.MAX_CONVERSATION_TURNS-1)
		check(dialog.content.text == "List completion message 16383",
			"last conversation turn remains selectable and editable after full population")
	else:
		check(false,"last conversation turn selection is unqualified because list population did not complete")
	dialog.hide()
	var closing_dialog = panel.ConversationEditor.new()
	panel.add_child(closing_dialog)
	closing_dialog.open_history(panel.conversation)
	closing_dialog.queue_free()
	for i: int in 3: await process_frame
	check(not is_instance_valid(closing_dialog),
		"dialog destruction during list population does not retain a live continuation")
	panel.conversation = original
	print("ART_CONVERSATION_RESPONSIVENESS ",JSON.stringify({"turns":Provider.MAX_CONVERSATION_TURNS,
		"open_usec":opening_usec,"100_guard_usec":guard_usec,"last_list_slice_usec":dialog.last_list_slice_usec,
		"max_list_slice_usec":dialog.max_list_slice_usec,"display":DisplayServer.get_name()}))

func callback_stop_checks() -> void:
	# Direct drawing shares the same Stop boundary as model-assisted drawing.
	# Its append-only program intent must not admit native work after Stop.
	var manual_native_before: Dictionary = host.simulation_worker.paint_state()
	var manual_authored_before: Array = bench.applied.edits.duplicate(true)
	var manual_sequence_before: int = panel.executor.batch_sequence
	var manual_admissions_before: int = panel.provider.traffic.count('"kind":"manual_admission"')
	var manual_old_length: int = panel.provider.traffic.length()
	panel.input_mode.select(0)
	panel.input.text = '[{"shape":"rectangle","x0":8,"y0":8,"x1":9,"y1":9,"material":58}]'
	panel.paint_material.select(panel.paint_material.get_item_index(58))
	for i: int in 4: panel.fields[i].value = [0,0,512,512][i]
	var manual_stopped := {"value":false}
	var manual_observer := func() -> void:
		if not manual_stopped.value and panel.provider.traffic.substr(manual_old_length).contains('"kind":"manual_program"'):
			manual_stopped.value = true
			panel.stop_all("Fixture Stop from manual program audit")
	panel.provider.traffic_changed.connect(manual_observer)
	panel.submit_text()
	panel.provider.traffic_changed.disconnect(manual_observer)
	check(manual_stopped.value,"Stop occurs during real Direct JSON program audit")
	check(panel.executor.batch_sequence == manual_sequence_before and not panel.executor.active,
		"Stop during manual program audit prevents native drawing admission")
	check(panel.provider.traffic.count('"kind":"manual_admission"') == manual_admissions_before,
		"cancelled manual program records no later native admission")
	panel.stop_all("Fixture cleanup")
	for i: int in 3: await process_frame
	check(host.simulation_worker.paint_state().revision == manual_native_before.revision and bench.applied.edits == manual_authored_before,
		"cancelled manual program leaves real native and authored cells unchanged")
	# Stop may also be requested while the panel is auditing parameters, before
	# Provider.send has created its active request generation.
	panel.current_provider = "LM Studio"
	panel.source.select(0)
	panel.endpoint.text = "http://127.0.0.1:1/v1"
	panel.model.text = "cancel-before-dispatch-fixture"
	panel.input_mode.select(1)
	panel.input.text = "Return []"
	panel.turn_limit.value = 1
	panel.image_input.button_pressed = false
	var old_length: int = panel.provider.traffic.length()
	var requests_before: int = panel.provider.traffic.count('"kind":"request"')
	var parameter_stop := {"value":false}
	var parameter_observer := func() -> void:
		if not parameter_stop.value and panel.provider.traffic.substr(old_length).contains('"kind":"request_parameters"'):
			parameter_stop.value = true
			panel.stop_all("Fixture Stop from request parameter audit")
	panel.provider.traffic_changed.connect(parameter_observer)
	panel.send_prompt()
	panel.provider.traffic_changed.disconnect(parameter_observer)
	check(parameter_stop.value,"Stop occurs during the real Send parameter audit")
	check(not panel.provider.active and panel.provider.request == null,
		"Stop during parameter audit prevents HTTP dispatch")
	check(panel.provider.traffic.count('"kind":"request"') == requests_before,
		"cancelled Send parameters produce no later provider request event")
	panel.stop_all("Fixture cleanup")
	for target: String in ["message","local_geometry"]:
		var native_before: Dictionary = host.simulation_worker.paint_state()
		var authored_before: Array = bench.applied.edits.duplicate(true)
		var sequence_before: int = panel.executor.batch_sequence
		var admission_before: int = panel.provider.traffic.count('"kind":"drawing_admission"')
		panel.provider.serial += 1
		panel.request_epoch = host.simulation_worker.art_state().epoch
		panel.request_area = Rect2i(0,0,512,512)
		panel.request_guards = []
		panel.request_materials = [0,58]
		panel.request_shapes = panel.SHAPES
		panel.request_material = 58
		panel.request_pixel_limit = 0
		panel.request_local = true
		panel.request_scanline = false
		panel.remaining_turns = 1
		old_length = panel.provider.traffic.length()
		var interrupted := {"value":false}
		var observer := func() -> void:
			if not interrupted.value and panel.provider.traffic.substr(old_length).contains('"kind":"'+target+'"'):
				interrupted.value = true
				panel.stop_all("Fixture Stop from "+target+" audit")
		panel.provider.traffic_changed.connect(observer)
		panel.provider_finished(panel.provider.serial,'[{"shape":"rectangle","x0":8,"y0":8,"x1":9,"y1":9,"material":58}]',{},"")
		panel.provider.traffic_changed.disconnect(observer)
		check(interrupted.value,"Stop occurs synchronously during "+target+" audit callback")
		check(panel.executor.batch_sequence == sequence_before and not panel.executor.active,
			"Stop during "+target+" cannot admit the old response to native drawing")
		check(panel.provider.traffic.count('"kind":"drawing_admission"') == admission_before,
			"cancelled "+target+" callback records no later drawing admission")
		panel.stop_all("Fixture cleanup")
		for i: int in 3: await process_frame
		check(host.simulation_worker.paint_state().revision == native_before.revision and bench.applied.edits == authored_before,
			"Stop during "+target+" leaves real native and authored cells unchanged")

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	bench = host.shared_workbench
	editor = bench.paint_editor
	panel = bench._ensure_art_batches()
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
		await collaboration_layout_checks()
		await conversation_resize_checks()
		await scaled_layout_checks()
		conversation_checks()
		await large_conversation_checks()
		await callback_stop_checks()
	host.queue_free()
	await process_frame
	await process_frame
	print("ART_PANEL_UI ",JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}))
	quit(0 if failures.is_empty() else 1)
