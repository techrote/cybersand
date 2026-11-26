extends VBoxContainer
## Presentation only. The owning Art panel supplies copied context/proposals and
## consumes explicit actions. No transport, credentials, World or executor lives here.
signal request_submitted(mode: String, prompt: String, brief: Dictionary, context_options: Dictionary)
signal preview_requested
signal approve_requested
signal skip_requested
signal cancel_requested
signal brief_applied(brief: Dictionary)
signal context_refresh_requested(options: Dictionary)
signal conversation_requested
signal example_requested(example_id: String)
signal selection_requested(kind: String)

const PAGE_CHARACTERS := 4096
const MAX_PROMPT_CHARACTERS := 4096
const MAX_BRIEF_CHARACTERS := 4096
const MAX_CONTEXT_CHARACTERS := 131072
const MAX_PROPOSAL_CHARACTERS := 262144
const MAX_MESSAGE_MATCHES := 128
const SEARCH_CHARACTERS_PER_SLICE := 8192
const SEARCH_BUDGET_USEC := 2000
const MODES := ["discuss", "propose", "develop", "review"]
const MODE_LABELS := ["Discuss", "Propose", "Develop", "Review"]
const BoundedEdit = preload("res://scripts/art_conversation_text_edit.gd")

var mode := OptionButton.new()
var request_state := Label.new()
var provider_status := Label.new()
var tabs := TabContainer.new()
var prompt := BoundedEdit.new()
var send_button := Button.new()
var stop_button := Button.new()
var notice := Label.new()
var search := LineEdit.new()
var messages := ItemList.new()
var message_text := TextEdit.new()
var message_page := Label.new()
var message_previous := Button.new()
var message_next := Button.new()
var search_notice := Label.new()
var objective := BoundedEdit.new()
var style := LineEdit.new()
var complexity := OptionButton.new()
var variation := SpinBox.new()
var destructive := CheckBox.new()
var pinned := BoundedEdit.new()
var palette := LineEdit.new()
var palette_picker := OptionButton.new()
var preserve := ItemList.new()
var focus_bounded := Button.new()
var brief_notice := Label.new()
var brief_apply := Button.new()
var brief_cancel := Button.new()
var proposal_title := Label.new()
var proposal_summary := TextEdit.new()
var stages := ItemList.new()
var proposal_page := Label.new()
var proposal_previous := Button.new()
var proposal_next := Button.new()
var approve_button := Button.new()
var revise_button := Button.new()
var skip_button := Button.new()
var preview_button := Button.new()
var proposal_copy := Button.new()
var revision_history := OptionButton.new()
var context_text := TextEdit.new()
var visual_context := TextureRect.new()
var visual_caption := Label.new()
var context_page := Label.new()
var context_previous := Button.new()
var context_next := Button.new()
var native_context := CheckBox.new()
var knowledge_context := CheckBox.new()
var recent_context := CheckBox.new()
var image_context := CheckBox.new()
var image_scope := OptionButton.new()
var authorize := CheckBox.new()
var examples := OptionButton.new()

var _ready_done := false
var _busy := false
var _can_approve := false
var _can_skip := false
var _brief: Dictionary = {}
var _brief_loading := false
var _preserve: Array = []
var _proposal: Dictionary = {}
var _proposal_text := ""
var _proposal_page_index := 0
var _proposal_json := ""
var _context: Dictionary = {}
var _context_full_text := ""
var _context_json := ""
var _context_page_index := 0
var _turns: Array = []
var _conversation_revision := -1
var _message_indices: Array[int] = []
var _message_index := -1
var _message_page_index := 0
var _search_generation := 0
var _search_cursor := -1
var _search_offset := 0
var _search_query := ""
var _search_loading := false
var _revision_values: Array = []
var last_search_slice_usec := 0
var max_search_slice_usec := 0

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	for label: String in MODE_LABELS: mode.add_item(label)
	mode.item_selected.connect(_mode_changed)
	header.add_child(mode)
	provider_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	provider_status.clip_text = true
	provider_status.text = "Uses Art's configured provider"
	header.add_child(provider_status)
	add_child(header)
	request_state.text = "Idle · no request sent"
	request_state.max_lines_visible = 2
	request_state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	request_state.tooltip_text = request_state.text
	request_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(request_state)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_build_conversation()
	_build_brief()
	_build_proposal()
	_build_context()
	prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	prompt.custom_minimum_size.y = 48
	prompt.placeholder_text = "Discuss this World, propose a change, or refine the current proposal…"
	_bound_edit(prompt, MAX_PROMPT_CHARACTERS)
	add_child(prompt)
	var actions := HBoxContainer.new()
	send_button.text = "Send discussion"
	send_button.pressed.connect(_send)
	actions.add_child(send_button)
	stop_button.text = "Stop"
	stop_button.disabled = true
	stop_button.pressed.connect(func() -> void: cancel_requested.emit())
	actions.add_child(stop_button)
	var originals := Button.new()
	originals.text = "Conversation…"
	originals.tooltip_text = "Open complete original messages in Art's existing editable, paged conversation."
	originals.pressed.connect(func() -> void: conversation_requested.emit())
	actions.add_child(originals)
	examples.add_item("Offline examples…")
	examples.fit_to_longest_item = false
	examples.clip_text = true
	examples.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	examples.item_selected.connect(func(index: int) -> void:
		if index > 0: example_requested.emit(str(examples.get_item_metadata(index)))
		examples.select(0))
	actions.add_child(examples)
	add_child(actions)
	notice.max_lines_visible = 2
	notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.text = "Discuss and preview never draw. Every construction stage needs its own approval."
	notice.tooltip_text = notice.text
	add_child(notice)
	_ready_done = true
	set_brief(_brief)
	_mode_changed(0)
	resized.connect(_sync_compact_layout)
	_sync_compact_layout()

func _sync_compact_layout() -> void:
	# At the ordinary Art minimum, keep a usable scrolling page between the
	# fixed actions. Complete request/notice values remain in their tooltips.
	var visible_lines := 1 if size.y < 400.0 else 2
	for label: Label in [request_state, notice]:
		if label.max_lines_visible != visible_lines: label.max_lines_visible = visible_lines

func _tab(title_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = title_text
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(box)
	return box

func _scroll(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func _label(parent: Control, text: String) -> Label:
	var value := Label.new()
	value.text = text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(value)
	return value

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _reader(parent: Control, editor: TextEdit) -> void:
	editor.editable = false
	editor.add_theme_color_override("font_readonly_color", Color(0.88,0.92,0.96))
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(editor)

func _pages(parent: Control, previous: Button, current: Label, next: Button, callback: Callable) -> void:
	var row := HBoxContainer.new()
	previous.text = "Previous part"
	previous.pressed.connect(callback.bind(-1))
	row.add_child(previous)
	current.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current.clip_text = true
	row.add_child(current)
	next.text = "Next part"
	next.pressed.connect(callback.bind(1))
	row.add_child(next)
	parent.add_child(row)

func _build_conversation() -> void:
	var box := _tab("Conversation")
	search.placeholder_text = "Search this session's complete messages"
	search.max_length = 256
	search.text_changed.connect(func(_value: String) -> void: _rebuild_messages())
	box.add_child(search)
	search_notice.clip_text = true
	box.add_child(search_notice)
	var body := _scroll(box)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages.custom_minimum_size.y = 64
	messages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages.item_selected.connect(_message_selected)
	body.add_child(messages)
	message_text.custom_minimum_size.y = 64
	_reader(body, message_text)
	_pages(box, message_previous, message_page, message_next, _message_change_page)

func _build_brief() -> void:
	var box := _tab("Creative brief")
	var body := _scroll(box)
	_label(body, "Session brief · Apply pins the next request's creative constraints.")
	_label(body, "Objective")
	objective.custom_minimum_size.y = 64
	objective.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_bound_edit(objective, MAX_BRIEF_CHARACTERS)
	body.add_child(objective)
	var row := HBoxContainer.new()
	_label(row, "Style")
	style.max_length = 128
	style.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style.placeholder_text = "e.g. industrial, monumental, organic"
	row.add_child(style)
	body.add_child(row)
	row = HBoxContainer.new()
	_label(row, "Complexity")
	for label: String in ["Sparse", "Balanced", "Dense"]: complexity.add_item(label)
	row.add_child(complexity)
	_label(row, "Variation")
	variation.min_value = 0
	variation.max_value = 1
	variation.step = 0.05
	variation.value = 0.25
	row.add_child(variation)
	destructive.text = "Allow destructive edits"
	destructive.tooltip_text = "Permission is still limited by the native authoring owner. Unavailable overwrite operations refuse."
	row.add_child(destructive)
	body.add_child(row)
	_label(body, "Allowed palette · material IDs separated by commas; empty uses current Art material.")
	palette.max_length = 256
	palette.placeholder_text = "58, 59"
	body.add_child(palette)
	var palette_row := HBoxContainer.new()
	palette_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_picker.fit_to_longest_item = false
	palette_picker.clip_text = true
	palette_picker.add_item("Choose a material…")
	palette_row.add_child(palette_picker)
	_button(palette_row, "Add material", func() -> void:
		if palette_picker.selected > 0:
			var id := str(palette_picker.get_item_id(palette_picker.selected))
			palette.text = id if palette.text.strip_edges().is_empty() else palette.text + ", " + id)
	body.add_child(palette_row)
	_label(body, "Pinned constraints · one per line, up to 16; preserved across proposal revisions.")
	pinned.custom_minimum_size.y = 64
	pinned.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_bound_edit(pinned, 8192)
	body.add_child(pinned)
	_label(body, "Preserve these native rectangles")
	preserve.custom_minimum_size.y = 56
	body.add_child(preserve)
	var selection_actions := HFlowContainer.new()
	focus_bounded.text = "Focus 256 × 256"
	focus_bounded.tooltip_text = "Ask the Workbench owner for a bounded native region centred in the current view. The reported bounds are clipped to the World; no native write occurs."
	focus_bounded.pressed.connect(func() -> void: selection_requested.emit("bounded"))
	selection_actions.add_child(focus_bounded)
	_button(selection_actions, "Focus viewport", func() -> void: selection_requested.emit("viewport"))
	_button(selection_actions, "Use selection", func() -> void: selection_requested.emit("focus"))
	_button(selection_actions, "Protect selection", func() -> void: selection_requested.emit("preserve"))
	_button(selection_actions, "Remove protection", _remove_preserve)
	body.add_child(selection_actions)
	brief_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_notice.max_lines_visible = 2
	box.add_child(brief_notice)
	row = HBoxContainer.new()
	brief_apply.text = "Apply brief"
	brief_apply.pressed.connect(_apply_brief)
	row.add_child(brief_apply)
	brief_cancel.text = "Cancel edits"
	brief_cancel.pressed.connect(func() -> void: set_brief(_brief); brief_notice.text = "Unapplied edits discarded.")
	row.add_child(brief_cancel)
	box.add_child(row)

func _build_proposal() -> void:
	var box := _tab("Proposal")
	proposal_title.text = "No proposal yet"
	proposal_title.clip_text = true
	box.add_child(proposal_title)
	var body := _scroll(box)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	revision_history.fit_to_longest_item = false
	revision_history.clip_text = true
	revision_history.item_selected.connect(_show_revision)
	body.add_child(revision_history)
	stages.custom_minimum_size.y = 40
	stages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stages.item_selected.connect(_show_stage)
	body.add_child(stages)
	proposal_summary.custom_minimum_size.y = 96
	_reader(body, proposal_summary)
	_pages(body, proposal_previous, proposal_page, proposal_next, _proposal_change_page)
	var row := HBoxContainer.new()
	preview_button.text = "Refresh preview"
	preview_button.pressed.connect(func() -> void: preview_requested.emit())
	row.add_child(preview_button)
	approve_button.text = "Approve next stage"
	approve_button.disabled = true
	approve_button.pressed.connect(func() -> void:
		if not _busy and _can_approve and revision_history.selected == 0: approve_requested.emit())
	row.add_child(approve_button)
	revise_button.text = "Revise"
	revise_button.pressed.connect(func() -> void:
		mode.select(2)
		_mode_changed(2)
		prompt.grab_focus())
	row.add_child(revise_button)
	skip_button.text = "Skip"
	skip_button.disabled = true
	skip_button.pressed.connect(func() -> void:
		if not _busy and _can_skip and revision_history.selected == 0: skip_requested.emit())
	row.add_child(skip_button)
	proposal_copy.text = "Copy"
	proposal_copy.tooltip_text = "Copy the complete structured proposal. This does not approve or execute it."
	proposal_copy.pressed.connect(func() -> void:
		if not _proposal_json.is_empty(): DisplayServer.clipboard_set(_proposal_json))
	row.add_child(proposal_copy)
	box.add_child(row)

func _build_context() -> void:
	var box := _tab("Context")
	var body := _scroll(box)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var options := HFlowContainer.new()
	native_context.text = "Native cells"
	native_context.button_pressed = true
	options.add_child(native_context)
	knowledge_context.text = "Approved knowledge"
	options.add_child(knowledge_context)
	recent_context.text = "Session decisions"
	recent_context.button_pressed = true
	options.add_child(recent_context)
	image_context.text = "Rendered image"
	options.add_child(image_context)
	image_scope.add_item("Selected region")
	image_scope.add_item("Current viewport")
	options.add_child(image_scope)
	for toggle: CheckBox in [native_context, knowledge_context, recent_context, image_context]:
		toggle.toggled.connect(func(_on: bool) -> void: _invalidate_disclosure())
	image_scope.item_selected.connect(func(_index: int) -> void: _invalidate_disclosure())
	body.add_child(options)
	visual_context.custom_minimum_size.y = 128
	visual_context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_context.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual_context.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual_context.hide()
	body.add_child(visual_context)
	visual_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visual_caption.max_lines_visible = 3
	visual_caption.hide()
	body.add_child(visual_caption)
	# This reader scrolls inside the Context page; image/options must not
	# collapse its own content surface to a single heading.
	context_text.custom_minimum_size.y = 160
	_reader(body, context_text)
	_pages(body, context_previous, context_page, context_next, _context_change_page)
	authorize.text = "I reviewed this context and allow it to be sent"
	authorize.tooltip_text = "Applies to the next explicit Send only. Native observations and rendered appearance are identified separately."
	box.add_child(authorize)
	var row := HBoxContainer.new()
	_button(row, "Inspect next context", func() -> void: context_refresh_requested.emit(context_options()))
	_button(row, "Copy context", func() -> void:
		if not _context_json.is_empty(): DisplayServer.clipboard_set(_context_json))
	box.add_child(row)

func _bound_edit(edit: Variant, limit: int) -> void:
	edit.set_meta("accepted_text", "")
	edit.intercept_paste = func(value: String, caret_index: int, _whole_line: bool, _one_line_each: bool) -> bool:
		var replaced: int = edit.get_selected_text(caret_index).length() if edit.has_selection(caret_index) else 0
		if edit.text.length() - replaced + value.length() > limit:
			_set_notice("This field admits %d characters. Paste was refused; existing text is unchanged." % limit)
			return true
		return false
	edit.text_changed.connect(func() -> void:
		if edit.text.length() > limit:
			var prior: String = str(edit.get_meta("accepted_text", ""))
			edit.text = prior
			_set_notice("This field admits %d characters; excess input was refused." % limit)
		else:
			edit.set_meta("accepted_text", edit.text))

func _mode_changed(index: int) -> void:
	var captions := ["Send discussion", "Request proposal", "Develop proposal", "Review result"]
	send_button.text = captions[clampi(index, 0, 3)]
	match MODES[clampi(index, 0, 3)]:
		"discuss": prompt.placeholder_text = "Ask about the admitted World context or discuss an idea…"
		"propose": prompt.placeholder_text = "Describe a construction. The proposal will need your review…"
		"develop": prompt.placeholder_text = "Refine the current proposal: taller, simpler, a different material…"
		"review": prompt.placeholder_text = "Review completed native work and suggest the next improvement…"

func _send() -> void:
	if _busy: return
	if prompt.text.strip_edges().is_empty():
		_set_notice("Write a request first.")
		return
	if prompt.text.length() > MAX_PROMPT_CHARACTERS:
		_set_notice("The request is too long.")
		return
	if _brief_dirty():
		_set_notice("Apply or cancel the creative brief edits before sending.")
		tabs.current_tab = 1
		return
	var options := context_options()
	request_submitted.emit(MODES[mode.selected], prompt.text, _brief.duplicate(true), options)
	authorize.button_pressed = false

func context_options() -> Dictionary:
	return {"native": native_context.button_pressed, "knowledge": knowledge_context.button_pressed,
		"recent": recent_context.button_pressed, "image": image_context.button_pressed,
		"image_scope": "selected" if image_scope.selected == 0 else "viewport",
		"external_authorized": authorize.button_pressed,
		"inspected_digest": str(_context.get("digest", ""))}

func _invalidate_disclosure() -> void:
	authorize.button_pressed = false
	_set_notice("Context selection changed. Inspect it before authorizing external transmission.")

func set_provider_capabilities(value: Dictionary) -> void:
	var label := str(value.get("label", "Art provider"))
	var category := str(value.get("endpoint_category", value.get("category", "unverified endpoint")))
	provider_status.text = label + " · " + category
	provider_status.tooltip_text = "Uses the existing Art provider and credentials.\n" + JSON.stringify(value, "\t")

func set_request_state(value: Variant, busy: bool = false) -> void:
	var state: Dictionary = value if value is Dictionary else {"message": str(value), "busy": busy}
	_busy = bool(state.get("busy", busy))
	request_state.text = str(state.get("message", state.get("status", "Idle"))).left(512)
	request_state.tooltip_text = str(state.get("message", state.get("status", "Idle")))
	send_button.disabled = _busy
	stop_button.disabled = not _busy and not bool(state.get("can_stop", false))
	approve_button.disabled = _busy or not _can_approve or revision_history.selected > 0
	skip_button.disabled = _busy or not _can_skip or revision_history.selected > 0
	examples.disabled = _busy

func set_brief(value: Dictionary) -> void:
	_brief = value.duplicate(true)
	if not _ready_done: return
	_brief_loading = true
	objective.text = str(_brief.get("objective", ""))
	style.text = str(_brief.get("style", ""))
	complexity.select(maxi(0, ["sparse", "balanced", "dense"].find(str(_brief.get("complexity", "balanced")))))
	variation.value = float(_brief.get("variation", 0.25))
	destructive.button_pressed = bool(_brief.get("allow_destructive", false))
	var pins: Array[String] = []
	for item: Variant in _brief.get("pinned_constraints", []): pins.append(str(item))
	pinned.text = "\n".join(pins)
	var ids: Array[String] = []
	for item: Variant in _brief.get("palette", []): ids.append(str(item))
	palette.text = ", ".join(ids)
	_preserve = _brief.get("preserve", []).duplicate(true)
	_rebuild_preserve()
	brief_notice.text = "Brief applies within this game session. A new session begins without execution approvals."
	_brief_loading = false

func _draft_brief() -> Dictionary:
	var answer := _brief.duplicate(true)
	answer.objective = objective.text
	answer.style = style.text
	answer.complexity = ["sparse", "balanced", "dense"][complexity.selected]
	answer.variation = variation.value
	answer.allow_destructive = destructive.button_pressed
	answer.pinned_constraints = []
	for line: String in pinned.text.split("\n"):
		if not line.strip_edges().is_empty(): answer.pinned_constraints.append(line.strip_edges())
	answer.palette = []
	if not palette.text.strip_edges().is_empty():
		for token: String in palette.text.split(","):
			var id_text := token.strip_edges()
			if not id_text.is_valid_int(): return {"ui_error": "Palette entries must be material IDs separated by commas."}
			var id := int(id_text)
			if id < 0 or id > 65535: return {"ui_error": "Material IDs must be within 0–65535; the host checks actual availability."}
			if not answer.palette.has(id): answer.palette.append(id)
	answer.preserve = _preserve.duplicate(true)
	return answer

func _brief_dirty() -> bool:
	if _brief_loading: return false
	var draft := _draft_brief()
	var canonical := _brief.duplicate(true)
	for entry: Array in [["objective", ""], ["style", ""], ["complexity", "balanced"], ["variation", 0.25],
		["allow_destructive", false], ["pinned_constraints", []], ["palette", []], ["preserve", []]]:
		if not canonical.has(entry[0]): canonical[entry[0]] = entry[1]
	return draft != canonical

func _apply_brief() -> void:
	var draft := _draft_brief()
	if draft.has("ui_error"):
		brief_notice.text = str(draft.ui_error)
		return
	if draft.objective.length() > MAX_BRIEF_CHARACTERS or draft.pinned_constraints.size() > 16 or draft.palette.size() > 32 or draft.preserve.size() > 32:
		brief_notice.text = "Brief capacity exceeded: objective 4096 characters, 16 pins, 32 materials and 32 protected rectangles."
		return
	for constraint: String in draft.pinned_constraints:
		if constraint.length() > 512:
			brief_notice.text = "Each pinned constraint admits at most 512 characters."
			return
	set_brief(draft)
	authorize.button_pressed = false
	brief_applied.emit(draft.duplicate(true))
	brief_notice.text = "Brief applied. Earlier proposal approvals must be checked against these constraints."

func add_preserved_region(region: Variant) -> void:
	var rect: Array = []
	if region is Rect2i: rect = [region.position.x, region.position.y, region.size.x, region.size.y]
	elif region is Array and region.size() == 4: rect = region.duplicate()
	if rect.size() != 4 or int(rect[2]) <= 0 or int(rect[3]) <= 0:
		_set_notice("Select a nonempty native rectangle first.")
		return
	if _preserve.size() >= 32:
		_set_notice("The brief already has 32 protected rectangles.")
		return
	if not _preserve.has(rect): _preserve.append(rect)
	_rebuild_preserve()
	brief_notice.text = "Protection added to the brief draft. Apply it to pin the constraint."

func _rebuild_preserve() -> void:
	preserve.clear()
	for rect: Array in _preserve:
		if rect.size() == 4: preserve.add_item("x %s · y %s · %s × %s cells" % rect)

func _remove_preserve() -> void:
	var selected := preserve.get_selected_items()
	if selected.is_empty(): return
	_preserve.remove_at(int(selected[0]))
	_rebuild_preserve()

func set_context_inspection(value: Dictionary) -> void:
	_context = value.duplicate(true)
	authorize.button_pressed = false
	var inspector: Variant = value.get("inspector", value)
	_context_json = JSON.stringify(inspector, "\t")
	_context_full_text = "Readable summary. Copy context retains the complete admitted JSON, including nested detail.\n\n" + _readable(inspector)
	if _context_json.length() > MAX_CONTEXT_CHARACTERS or _context_full_text.length() > MAX_CONTEXT_CHARACTERS:
		_context_full_text = "Context inspector exceeded its display contract. No disclosure authorization is available."
		_context_json = ""
		_context = {}
	_context_page_index = 0
	_render_page(_context_full_text, _context_page_index, context_text, context_page, context_previous, context_next)

func set_proposal(value: Dictionary, lineage: Array = []) -> void:
	_proposal = value.duplicate(true)
	_proposal_json = JSON.stringify(value.get("proposal", value), "\t")
	if _proposal_json.length() > MAX_PROPOSAL_CHARACTERS:
		_proposal = {}
		_proposal_json = ""
		_can_approve = false
		_can_skip = false
		approve_button.disabled = true
		skip_button.disabled = true
		_set_notice("Proposal exceeds the UI contract; the original message remains in Conversation.")
		return
	_can_approve = bool(value.get("can_approve", false))
	_can_skip = bool(value.get("can_skip", false))
	_revision_values = lineage.slice(maxi(0, lineage.size() - 64)).duplicate(true)
	revision_history.clear()
	revision_history.add_item("Current proposal")
	for item: Dictionary in _revision_values:
		revision_history.add_item(str(item.get("label", item.get("id", "Earlier revision"))).left(128))
	_show_proposal(value)
	set_request_state({"message": request_state.text, "busy": _busy})

func _show_proposal(value: Dictionary) -> void:
	var actual: Dictionary = value.get("proposal", value)
	# Copy follows the displayed revision and contains its reusable typed payload.
	# Host budgets, preview estimates and receipts remain inspection data.
	_proposal_json = JSON.stringify(actual, "\t")
	if _proposal_json.length() > MAX_PROPOSAL_CHARACTERS: _proposal_json = ""
	proposal_copy.disabled = _proposal_json.is_empty()
	proposal_title.text = str(actual.get("title", "Authoring proposal")).left(256)
	proposal_title.tooltip_text = str(actual.get("title", "Authoring proposal"))
	stages.clear()
	var list: Array = value.get("stages", actual.get("stages", []))
	for stage: Dictionary in list:
		stages.add_item("%s · %s" % [str(stage.get("id", "")), str(stage.get("title", "Stage")).left(100)])
		stages.set_item_metadata(stages.item_count - 1, stage)
	_proposal_text = str(actual.get("summary", "Review the proposed native changes."))
	_proposal_text += "\n\n%d finite stage%s · %s" % [list.size(), "" if list.size() == 1 else "s", str(value.get("status", "awaiting review"))]
	_proposal_text += "\n\nHost-computed scope\n" + _readable(value.get("budget", {}))
	if not value.get("diff", {}).is_empty():
		_proposal_text += "\n\nChanges from the previous proposal\n" + _readable(value.get("diff", {}))
	if not value.get("warnings", []).is_empty():
		_proposal_text += "\n\nReview before approval\n" + _readable(value.get("warnings", []))
	if not str(value.get("error", "")).is_empty():
		_proposal_text += "\n\nRefused\n" + str(value.error)
	_proposal_text += "\n\nPreview estimates are not completed work. Each stage needs fresh approval; confirmed native receipts report what actually changed."
	if value.has("preview"): _proposal_text += "\n\nNative preview\n" + _readable(value.preview)
	_proposal_page_index = 0
	_render_page(_proposal_text, 0, proposal_summary, proposal_page, proposal_previous, proposal_next)

func _show_revision(index: int) -> void:
	if index <= 0:
		_show_proposal(_proposal)
		approve_button.disabled = _busy or not _can_approve
		skip_button.disabled = _busy or not _can_skip
		return
	var item: Dictionary = _revision_values[index - 1]
	_show_proposal(item.get("snapshot", item))
	approve_button.disabled = true
	skip_button.disabled = true
	_set_notice("Viewing an earlier proposal. Historical revisions do not carry execution approval.")

func _show_stage(index: int) -> void:
	if index < 0 or index >= stages.item_count: return
	var stage: Dictionary = stages.get_item_metadata(index)
	_proposal_text = str(stage.get("title", "Construction stage")) + "\n"
	_proposal_text += "Stage " + str(stage.get("id", "")) + "\n"
	if not stage.get("depends_on", []).is_empty():
		_proposal_text += "After: " + _readable(stage.depends_on) + "\n"
	_proposal_text += "\nHost budget\n" + _readable(stage.get("budget", {}))
	for key: String in ["scope", "bounds", "materials", "protected_conflicts", "requested", "predicted_changed", "predicted_unchanged", "conflicts", "introduced", "removed"]:
		if stage.has(key): _proposal_text += "\n\n" + key.replace("_", " ").capitalize() + "\n" + _readable(stage[key])
	var geometry: Array = stage.get("operations", [])
	if not geometry.is_empty():
		_proposal_text += "\n\n%d native geometry operation%s" % [geometry.size(), "" if geometry.size() == 1 else "s"]
		for operation: Dictionary in geometry.slice(0, 16):
			_proposal_text += "\n• " + str(operation.get("shape", "operation")).capitalize() + " · material " + str(operation.get("material", "?"))
		if geometry.size() > 16: _proposal_text += "\nAdditional operations remain in the complete copied proposal."
	_proposal_text += "\n\nThese are proposed changes. Only the native owner can confirm completion."
	_proposal_page_index = 0
	_render_page(_proposal_text, 0, proposal_summary, proposal_page, proposal_previous, proposal_next)

func set_receipt(value: Dictionary) -> void:
	_set_notice("Native result · %s · %s changed · %s" % [str(value.get("status", "unknown")),
		str(value.get("changed", "?")), str(value.get("reason", "")).left(240)])
	set_request_state({"message": notice.text, "busy": bool(value.get("active", false))})

func set_examples(values: Array) -> void:
	examples.clear()
	examples.add_item("Offline examples…")
	for value: Dictionary in values:
		examples.add_item(str(value.get("title", value.get("id", "Example"))).left(96))
		examples.set_item_metadata(examples.item_count - 1, str(value.get("id", "")))

func set_conversation(turns: Array, revision: int = -1) -> void:
	if revision >= 0 and revision == _conversation_revision and turns.size() == _turns.size(): return
	_conversation_revision = revision
	# Read-only shallow snapshot: never deep-copy multi-megabyte strings for a view.
	_turns = turns.duplicate()
	_rebuild_messages()

func _rebuild_messages() -> void:
	if not _ready_done: return
	_search_generation += 1
	_search_cursor = _turns.size() - 1
	_search_offset = 0
	_search_query = search.text.strip_edges()
	_message_indices.clear()
	messages.clear()
	_message_index = -1
	message_text.text = ""
	_search_loading = true
	_search_slice.call_deferred(_search_generation)

func _search_slice(generation: int) -> void:
	if generation != _search_generation or not is_inside_tree(): return
	var began := Time.get_ticks_usec()
	var scanned := 0
	while _search_cursor >= 0 and _message_indices.size() < MAX_MESSAGE_MATCHES:
		var turn: Dictionary = _turns[_search_cursor]
		var content: String = str(turn.get("content", ""))
		var match_found := _search_query.is_empty()
		var finished_entry := match_found
		if not match_found:
			# Overlap by query length preserves matches crossing page boundaries.
			var length := mini(4096, maxi(0, content.length() - _search_offset))
			var part := content.substr(_search_offset, length + _search_query.length())
			match_found = part.containsn(_search_query) or str(turn.get("role", "")).containsn(_search_query)
			_search_offset += length
			scanned += maxi(1, length)
			finished_entry = match_found or _search_offset >= content.length()
		if match_found:
			_message_indices.append(_search_cursor)
			messages.add_item("%d · %s · %s" % [_search_cursor + 1, str(turn.get("role", "message")),
				content.left(96).replace("\n", " ").replace("\r", " ")])
		if finished_entry:
			_search_cursor -= 1
			_search_offset = 0
		if Time.get_ticks_usec() - began >= SEARCH_BUDGET_USEC or scanned >= SEARCH_CHARACTERS_PER_SLICE or messages.item_count % 32 == 0 and messages.item_count > 0:
			break
	last_search_slice_usec = Time.get_ticks_usec() - began
	max_search_slice_usec = maxi(max_search_slice_usec, last_search_slice_usec)
	_search_loading = _search_cursor >= 0 and _message_indices.size() < MAX_MESSAGE_MATCHES
	search_notice.text = "%d matching messages%s" % [_message_indices.size(),
		" · searching complete text…" if _search_loading else (" · newest 128; refine search" if _search_cursor >= 0 else " · complete")]
	if _search_loading:
		await get_tree().process_frame
		if generation == _search_generation: _search_slice(generation)
	elif not _message_indices.is_empty():
		messages.select(0)
		_message_selected(0)

func _message_selected(index: int) -> void:
	if index < 0 or index >= _message_indices.size(): return
	_message_index = _message_indices[index]
	_message_page_index = 0
	_show_message()

func _show_message() -> void:
	if _message_index < 0 or _message_index >= _turns.size(): return
	var text := str(_turns[_message_index].get("content", ""))
	_render_page(text, _message_page_index, message_text, message_page, message_previous, message_next)

func _message_change_page(direction: int) -> void:
	if _message_index < 0 or _message_index >= _turns.size(): return
	var text := str(_turns[_message_index].get("content", ""))
	_message_page_index = clampi(_message_page_index + direction, 0, maxi(0, ceili(float(text.length()) / PAGE_CHARACTERS) - 1))
	_show_message()

func _proposal_change_page(direction: int) -> void:
	_proposal_page_index = clampi(_proposal_page_index + direction, 0, maxi(0, ceili(float(_proposal_text.length()) / PAGE_CHARACTERS) - 1))
	_render_page(_proposal_text, _proposal_page_index, proposal_summary, proposal_page, proposal_previous, proposal_next)

func _context_change_page(direction: int) -> void:
	_context_page_index = clampi(_context_page_index + direction, 0, maxi(0, ceili(float(_context_full_text.length()) / PAGE_CHARACTERS) - 1))
	_render_page(_context_full_text, _context_page_index, context_text, context_page, context_previous, context_next)

func _render_page(text: String, index: int, editor: TextEdit, label: Label, previous: Button, next: Button) -> void:
	var count := maxi(1, ceili(float(text.length()) / PAGE_CHARACTERS))
	editor.text = text.substr(index * PAGE_CHARACTERS, PAGE_CHARACTERS)
	label.text = "Part %d / %d" % [index + 1, count]
	previous.disabled = index <= 0
	next.disabled = index + 1 >= count

func _set_notice(value: String) -> void:
	notice.text = value.left(512)
	notice.tooltip_text = value

func set_material_options(values: Array) -> void:
	palette_picker.clear()
	palette_picker.add_item("Choose a material…", -1)
	for value: Dictionary in values:
		var id := int(value.get("id", -1))
		if id >= 0: palette_picker.add_item("%s (%d)" % [str(value.get("name", "Material")), id], id)
	palette_picker.select(0)

func _readable(value: Variant, depth: int = 0) -> String:
	if depth >= 5: return "More detail is retained in the complete structured copy."
	if value is Dictionary:
		var lines: Array[String] = []
		for key: Variant in value:
			lines.append(str(key).replace("_", " ").capitalize() + ": " + _readable(value[key], depth + 1))
		return "\n".join(lines) if not lines.is_empty() else "None"
	if value is Array or value is PackedStringArray:
		var lines: Array[String] = []
		for item: Variant in value: lines.append("• " + _readable(item, depth + 1))
		return "\n".join(lines) if not lines.is_empty() else "None"
	if value is bool: return "Yes" if value else "No"
	return str(value)

func set_visual_context(capture: Image, caption: String) -> void:
	authorize.button_pressed = false
	visual_context.texture = null
	visual_context.hide()
	visual_caption.hide()
	if capture == null or capture.is_empty(): return
	if capture.get_width() > 1024 or capture.get_height() > 1024:
		_set_notice("Visual context exceeds the bounded preview contract.")
		return
	visual_context.texture = ImageTexture.create_from_image(capture)
	visual_context.show()
	visual_caption.text = caption.left(256) + "\nRendered appearance; native material observations remain separate."
	visual_caption.tooltip_text = caption
	visual_caption.show()
