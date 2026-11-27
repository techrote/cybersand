extends SceneTree
## Actual Control behavior and bounded projections, without provider or World.
const Workspace = preload("res://scripts/art_collaboration_workspace.gd")
var view
var window: Window
var checks := 0
var failures: Array[String] = []
var requests: Array = []
var briefs: Array = []
var approvals := 0
var cancellations := 0
var previews := 0
var selections: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("ART_COLLABORATION_UI: " + label)

func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	var result := bool(predicate.call())
	check(result, label)
	return result

func run() -> void:
	root.size = Vector2i(1280,900)
	root.gui_embed_subwindows = true
	window = Window.new()
	window.title = "Art collaboration — fixture view"
	window.size = Vector2i(820,620)
	window.transient = true
	window.exclusive = false
	root.add_child(window)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,6)
	window.add_child(margin)
	view = Workspace.new()
	margin.add_child(view)
	view.request_submitted.connect(func(mode: String, text: String, brief: Dictionary, context: Dictionary) -> void:
		requests.append({"mode":mode,"prompt":text,"brief":brief,"context":context}))
	view.brief_applied.connect(func(brief: Dictionary) -> void: briefs.append(brief))
	view.approve_requested.connect(func() -> void: approvals += 1)
	view.cancel_requested.connect(func() -> void: cancellations += 1)
	view.preview_requested.connect(func() -> void: previews += 1)
	view.selection_requested.connect(func(kind: String) -> void: selections.append(kind))
	window.popup_centered()
	for i: int in 3: await process_frame
	check(requests.is_empty() and approvals == 0, "opening collaboration is inert")
	check(view.mode.item_count == 4, "four conversational intents share one prompt")
	check(view.tabs.get_tab_count() == 4, "one workspace has conversation, brief, proposal and context")
	check(view.stop_button.disabled, "idle Stop is disabled")
	view.focus_bounded.pressed.emit()
	check(selections == ["bounded"] and requests.is_empty() and approvals == 0, "bounded focus asks its host once without model or native execution")
	view.set_provider_capabilities({"label":"Fixture","endpoint_category":"loopback","text":true,
		"image_model":"unverified","streaming":false})
	check(view.provider_status.text.contains("loopback"), "provider category is explicit")
	check(view.provider_status.tooltip_text.contains("unverified"), "unverified image capability is retained")
	check(requests.is_empty(), "capability display never dispatches")

	view.objective.text = "Preserve the lower passage and repair the roof."
	view.style.text = "Industrial"
	view.pinned.text = "Keep the lower passage open.\nDo not touch the actor."
	view.palette.text = "58, 59, 58"
	view.add_preserved_region(Rect2i(8,40,80,8))
	view.prompt.text = "Suggest a repair."
	view.send_button.pressed.emit()
	check(requests.is_empty(), "unapplied brief edits block Send")
	view.brief_apply.pressed.emit()
	check(briefs.size() == 1, "explicit Apply emits one brief")
	check(briefs[0].palette == [58,59], "palette IDs deduplicate without inventing materials")
	check(briefs[0].preserve == [[8,40,80,8]], "protection uses native rectangle values")
	check(briefs[0].pinned_constraints.size() == 2, "pinned constraints remain structured")
	var accepted: Dictionary = briefs[0].duplicate(true)
	view.objective.text = "Discard this draft."
	view.brief_cancel.pressed.emit()
	check(view.objective.text == accepted.objective, "Cancel restores accepted brief")
	check(briefs.size() == 1, "Cancel emits no approval or brief change")
	check(view.prompt.intercept_paste.call("x".repeat(5000),0,false,false),
		"large prompt paste is refused before widget shaping")
	check(view.prompt.text == "Suggest a repair.", "refused paste keeps complete earlier prompt")
	view.set_context_inspection({"digest":"fixture-context-a","inspector":{"included":["native 128x128"],
		"omitted":["image"],"provenance":"actual native material capture","bytes":1234}})
	view.authorize.button_pressed = true
	view.send_button.pressed.emit()
	check(requests.size() == 1 and requests[0].mode == "discuss", "one explicit Discuss dispatch")
	check(requests[0].context.external_authorized, "request captures explicit disclosure authorization")
	check(requests[0].context.inspected_digest == "fixture-context-a", "authorization binds inspected digest")
	check(not view.authorize.button_pressed, "authorization is consumed after Send")
	check(approvals == 0, "discussion does not request native approval")
	check(accepted == briefs[0], "rendering and sending do not mutate accepted brief")

	view.set_request_state({"message":"Preparing request · Stop available","busy":true})
	check(view.send_button.disabled and not view.stop_button.disabled, "pending request exposes Stop and prevents another Send")
	view.send_button.pressed.emit()
	check(requests.size() == 1, "pending Send handler refuses duplicate")
	view.stop_button.pressed.emit()
	check(cancellations == 1, "Stop emits exactly one owner cancellation")
	view.set_request_state({"message":"Stopped","busy":false})
	check(not view.send_button.disabled, "terminal state restores Send")
	view.authorize.button_pressed = true
	view.image_context.button_pressed = true
	check(not view.authorize.button_pressed, "changing image inclusion invalidates old disclosure")
	check(requests.size() == 1, "changing context controls is inert")
	var visual := Image.create(4,4,false,Image.FORMAT_RGBA8)
	visual.fill(Color(0.2,0.4,0.6))
	view.authorize.button_pressed = true
	view.set_visual_context(visual,"UI-only synthetic preview · selected native region")
	check(view.visual_context.visible and not view.authorize.button_pressed, "new visual preview requires fresh disclosure")
	check(requests.size() == 1, "visual preview never dispatches")
	view.set_visual_context(null,"")
	check(not view.visual_context.visible, "removed image leaves no stale preview")
	var nested_context := {"level_one":{"level_two":{"level_three":{"level_four":{"level_five":{"native_cell":[17,31,58],"sentinel":"complete-admitted-context"}}}}}}
	view.set_context_inspection({"digest":"nested-context","inspector":nested_context})
	# JSON numbers decode as floats; compare complete JSON-domain values, not GDScript integer Variant types.
	var copied_context: Variant = JSON.parse_string(view._context_json)
	var expected_context: Variant = JSON.parse_string(JSON.stringify(nested_context))
	check(copied_context == expected_context, "Copy context preserves every nested admitted value without readable-summary truncation")
	var copied_cells: Array = copied_context.level_one.level_two.level_three.level_four.level_five.native_cell if copied_context == expected_context else []
	check(copied_cells == [17.0,31.0,58.0], "complete context copy retains exact native cell coordinates and material values")
	check(view._context_full_text.contains("Copy context") and not view._context_full_text.contains("complete-admitted-context"), "bounded readable summary accurately discloses omitted nested detail")
	var full_context := "native-context ".repeat(1000)
	view.set_context_inspection({"digest":"fixture-context-b","inspector":{"detail":full_context}})
	check(view.context_text.text.length() <= 4096, "context view shapes at most 4096 characters")
	var first_context: String = view.context_text.text
	view.context_next.pressed.emit()
	check(view.context_text.text.length() <= 4096 and view.context_text.text != first_context,
		"context next part shows remaining admitted information")

	var proposal := {"ok":true,"can_approve":true,"can_skip":true,"proposal":{"schema":"art-proposal-v1",
		"title":"Repair the room","summary":"Add a supported roof while retaining the passage."},
		"stages":[{"id":"roof","title":"Roof supports","operations":[{"shape":"rectangle","material":58}],
			"budget":{"cells_upper_bound":512},"protected_conflicts":[]},
			{"id":"detail","title":"Surface detail","depends_on":["roof"],"budget":{"cells_upper_bound":256}}],
		"budget":{"cells_upper_bound":768},"warnings":["Existing material overwrite is subject to native authority."]}
	var earlier := proposal.duplicate(true)
	earlier.proposal.title = "Earlier room proposal"
	view.set_proposal(proposal,[{"label":"Revision 1","snapshot":earlier}])
	check(JSON.parse_string(view._proposal_json) == proposal.proposal, "Copy contains only the reusable typed proposal payload")
	check(view.stages.item_count == 2, "proposal displays finite stages")
	check(not view.approve_button.disabled, "fresh applicable approval control is offered")
	check(approvals == 0, "proposal display is zero-write")
	view.preview_button.pressed.emit()
	check(previews == 1 and approvals == 0, "preview action is distinct from approval")
	view.revision_history.select(1)
	view.revision_history.item_selected.emit(1)
	check(JSON.parse_string(view._proposal_json) == earlier.proposal, "Copy follows the displayed historical revision")
	view.set_request_state({"message":"Idle","busy":false})
	check(view.approve_button.disabled, "historical revision remains unapprovable after status refresh")
	view.approve_button.pressed.emit()
	check(approvals == 0, "historical approval handler is fenced")
	view.revision_history.select(0)
	view.revision_history.item_selected.emit(0)
	check(JSON.parse_string(view._proposal_json) == proposal.proposal, "returning to current revision restores its typed Copy payload")
	view.approve_button.pressed.emit()
	check(approvals == 1, "current stage approval is explicit")
	view.revise_button.pressed.emit()
	check(view.mode.selected == 2 and view.send_button.text == "Develop proposal", "Revise uses same conversational prompt")
	check(requests.size() == 1, "Revise never automatically dispatches")
	view.set_receipt({"status":"partial","changed":4096,"reason":"Human Stop"})
	check(view.notice.text.contains("partial") and view.notice.text.contains("4096"), "partial receipt reports observed prefix")
	check(requests.size() == 1 and approvals == 1, "receipt rendering never schedules continuation")

	var long_text := "a".repeat(4093) + "bridge-boundary-marker" + "b".repeat(9000)
	view.set_conversation([{"role":"user","content":"First brief"},
		{"role":"assistant","content":long_text},
		{"role":"user","content":"Revise the upper floor"}],1)
	await until(func() -> bool: return not view._search_loading, "initial bounded transcript population finishes")
	check(view.messages.item_count == 3, "all three complete turns are retained")
	view.search.text = "bridge-boundary-marker"
	view.search.text_changed.emit(view.search.text)
	await until(func() -> bool: return not view._search_loading, "complete-message search finishes")
	check(view.messages.item_count == 1 and view._message_indices[0] == 1,
		"search matches text across the 4096-character boundary")
	check(view.message_text.text.length() == 4096, "message view preserves 4096-character parts")
	view.message_next.pressed.emit()
	check(view.message_text.text.length() == 4096 and view.message_text.text.begins_with("dge-boundary"),
		"next message part preserves exact content")
	check(view._turns[1].content == long_text, "view paging never changes complete message")
	view.search.text = "not found"
	view.search.text_changed.emit(view.search.text)
	view.search.text = "upper floor"
	view.search.text_changed.emit(view.search.text)
	await until(func() -> bool: return not view._search_loading, "superseded search is cancelled")
	check(view.messages.item_count == 1 and view._message_indices[0] == 2, "only latest search publishes")
	var many: Array = []
	for index: int in 300: many.append({"role":"user","content":"Message %d" % index})
	view.search.text = ""
	view.search.text_changed.emit(view.search.text)
	view.set_conversation(many,2)
	await until(func() -> bool: return not view._search_loading, "large list remains bounded")
	check(view.messages.item_count == 128, "live transcript list caps to newest 128 matches")
	check(view._turns.size() == 300 and view.search_notice.text.contains("newest 128"),
		"list capacity is disclosed without dropping transcript")

	for size: Vector2i in [Vector2i(520,320),Vector2i(560,400),Vector2i(820,620)]:
		window.size = size
		for tab: int in 4:
			view.tabs.current_tab = tab
			for frame: int in 3: await process_frame
			var body := Rect2(Vector2.ZERO, Vector2(window.get_visible_rect().size))
			for button: Button in [view.send_button,view.stop_button]:
				check(body.encloses(button.get_global_rect()), "shared request footer reachable at %s tab %d" % [size,tab])
			if tab == 1:
				check(body.encloses(view.brief_apply.get_global_rect()) and body.encloses(view.brief_cancel.get_global_rect()),
					"brief Apply/Cancel remains reachable at %s" % size)
			if tab == 2:
				check(body.encloses(view.approve_button.get_global_rect()), "stage approval reachable at %s" % size)
	window.size = Vector2i(820,620)
	view.tabs.current_tab = 2
	for frame: int in 3: await process_frame
	var evidence := OS.get_environment("WB_ART_COLLAB_UI_EVIDENCE")
	if not evidence.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(evidence)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(evidence.path_join("art-collaborative-ui.png")) == OK,
			"displayed workspace framebuffer retained")
	window.queue_free()
	await process_frame
	print("ART_COLLABORATION_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"display":DisplayServer.get_name(),"requests":requests.size(),"approvals":approvals}))
	quit(0 if failures.is_empty() else 1)
