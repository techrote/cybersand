extends ConfirmationDialog
## A draft of future model context. The provider's native/HTTP audit stays append-only.
const HELP := "Edit future model context only. Apply saves the draft; Cancel discards it. Canvas state and original traffic are unchanged."
var baseline: Array = []
var draft: Array = []
var messages := ItemList.new()
var content := preload("res://scripts/art_conversation_text_edit.gd").new()
var role := Label.new()
var notice := Label.new()
var remove_button := Button.new()
var note_button := Button.new()
var clear_button := Button.new()
var apply_pending := false
var page_controls := HBoxContainer.new()
var previous_page := Button.new()
var next_page := Button.new()
var page_status := Label.new()
var page_jump := LineEdit.new()
# Bound text shaping as well as allocation, including dense Unicode text.
const PAGE_CHARACTERS := 4096
var _pages: Array[String] = []
var _page_index := 0
var _pages_dirty := false
var selected := -1
var loading := false
var list_loading := false
var _list_generation := 0
const LIST_ITEMS_PER_FRAME := 128
const LIST_BUDGET_USEC := 2000
# Last/current-build maximum GDScript population slice; deferred engine layout
# and rendering are outside these in-memory measurements.
var last_list_slice_usec := 0
var max_list_slice_usec := 0
var last_list_slice_items := 0

func _ready() -> void:
	title = "Conversation history"
	min_size = Vector2i(480,280)
	size_changed.connect(_sync_minimum)
	size = Vector2i(760,480)
	exclusive = false
	dialog_hide_on_ok = false
	get_ok_button().text = "Apply"
	close_requested.connect(hide)
	# Bound custom content so long notes/notices cannot push Apply/Cancel
	# outside the visible dialog. The standard ConfirmationDialog footer
	# remains outside this vertically scrollable content region.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 160
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	notice.text = HELP
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(notice)
	var actions := HBoxContainer.new()
	note_button.text = "+ Note"
	note_button.pressed.connect(func() -> void:
		if apply_pending: return
		flush_message()
		draft.append({"role":"user","content":""})
		_rebuild(draft.size()-1)
		content.grab_focus())
	actions.add_child(note_button)
	remove_button.text = "Remove"
	remove_button.pressed.connect(func() -> void:
		if apply_pending: return
		flush_message()
		if selected >= 0 and selected < draft.size():
			draft.remove_at(selected)
			_rebuild(mini(selected,draft.size()-1)))
	actions.add_child(remove_button)
	clear_button.text = "Clear draft"
	clear_button.tooltip_text = "Remove all messages from this draft. Cancel still preserves live history."
	clear_button.pressed.connect(func() -> void:
		if apply_pending: return
		draft.clear(); _rebuild(-1))
	actions.add_child(clear_button)
	box.add_child(actions)
	var split := HSplitContainer.new()
	split.custom_minimum_size.y = 150
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	messages.custom_minimum_size.x = 170
	messages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages.item_selected.connect(func(index: int) -> void: flush_message(); _select_message(index))
	split.add_child(messages)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(detail)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(role)
	previous_page.text = "Previous"
	previous_page.pressed.connect(_change_page.bind(-1))
	page_controls.add_child(previous_page)
	page_jump.custom_minimum_size.x = 56
	page_jump.max_length = 12
	page_jump.select_all_on_focus = true
	page_jump.placeholder_text = "Part"
	page_jump.tooltip_text = "Go to a part number and press Enter. Apply saves all parts."
	page_jump.text_submitted.connect(_jump_page)
	page_controls.add_child(page_jump)
	page_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_status.tooltip_text = "Previous, Next, or a part number retain your edits. Changing parts or pasting across parts resets this text editor's Undo history. Apply saves all parts; Cancel discards the draft."
	page_controls.add_child(page_status)
	next_page.text = "Next"
	next_page.pressed.connect(_change_page.bind(1))
	page_controls.add_child(next_page)
	detail.add_child(page_controls)
	content.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.intercept_paste = _intercept_paste
	content.text_changed.connect(_content_changed)
	detail.add_child(content)

func open_history(turns: Array) -> void:
	set_apply_pending(false)
	baseline = turns.duplicate(true)
	# Keep one immutable snapshot. Draft entries are copied only when edited;
	# an additional deep copy of every turn delays opening large transcripts.
	draft = baseline.duplicate()
	notice.text = HELP
	_rebuild(0 if not draft.is_empty() else -1)
	# Fit the popup's actual embedding viewport or native screen at this scale.
	popup_centered_clamped(Vector2i((Vector2(760,480)*content_scale_factor).ceil()),0.9)

func set_apply_pending(pending: bool, message: String = "") -> void:
	apply_pending = pending
	note_button.disabled = pending
	clear_button.disabled = pending
	remove_button.disabled = pending or selected < 0
	content.editable = not pending and selected >= 0
	get_ok_button().disabled = pending
	if not message.is_empty(): notice.text = message

func _sync_minimum() -> void:
	var scaled := Vector2i((Vector2(480,280)*content_scale_factor).ceil())
	if min_size != scaled: min_size = scaled

func _caption(index: int) -> String:
	var turn: Dictionary = draft[index]
	# Captions never need to scan/copy the rest of a multi-megabyte message.
	var text := str(turn.get("content","")).left(70).replace("\n"," ").replace("\r"," ")
	return "%d · %s · %s" % [index+1,str(turn.get("role","user")),text]

func _rebuild(next: int) -> void:
	_list_generation += 1
	last_list_slice_usec = 0
	max_list_slice_usec = 0
	last_list_slice_items = 0
	messages.clear()
	_select_message(next)
	_append_message_items(_list_generation)

func _append_message_items(generation: int) -> void:
	if generation != _list_generation: return
	var began := Time.get_ticks_usec()
	var first := messages.item_count
	var last := mini(draft.size(),messages.item_count+LIST_ITEMS_PER_FRAME)
	while messages.item_count < last:
		var index := messages.item_count
		messages.add_item(_caption(index))
		if index == selected:
			_update_selected_caption()
			messages.select(selected)
			messages.ensure_current_is_visible()
		if Time.get_ticks_usec()-began >= LIST_BUDGET_USEC: break
	list_loading = messages.item_count < draft.size()
	var next_title := "Conversation history · loading messages…" if list_loading else "Conversation history"
	if title != next_title: title = next_title
	last_list_slice_items = messages.item_count-first
	last_list_slice_usec = Time.get_ticks_usec()-began
	max_list_slice_usec = maxi(max_list_slice_usec,last_list_slice_usec)
	if list_loading:
		# Rendering an ItemList of 16,384 turns in one call visibly stalls the
		# editor. Let X/Cancel, typing and Apply run between small list slices.
		await get_tree().process_frame
		if not is_inside_tree() or generation != _list_generation: return
		if not visible:
			list_loading = false
			title = "Conversation history"
			return
		_append_message_items(generation)

func _select_message(index: int) -> void:
	loading = true
	selected = index if index >= 0 and index < draft.size() else -1
	content.editable = selected >= 0 and not apply_pending
	remove_button.disabled = selected < 0 or apply_pending
	if selected >= 0:
		var turn: Dictionary = draft[selected]
		role.text = "%d / %d · %s%s" % [selected+1,draft.size(),str(turn.role).capitalize(),
			" · original image retained" if turn.has("image_offset") else ""]
		_load_pages(str(turn.content))
	else:
		role.text = "No messages · add a note or Cancel"
		_load_pages("")
	content.clear_undo_history()
	loading = false

func _load_pages(text: String) -> void:
	# TextEdit shapes its complete assigned text. Never assign a multi-megabyte
	# message to the visible widget merely to select it. Strings in the draft
	# and the immutable baseline retain the full content until Apply/Cancel.
	_pages.clear()
	for offset: int in range(0,text.length(),PAGE_CHARACTERS):
		_pages.append(text.substr(offset,PAGE_CHARACTERS))
	if _pages.is_empty(): _pages.append("")
	_page_index = 0
	_pages_dirty = false
	_show_page(0)

func _show_page(index: int, caret_offset: int = 0) -> void:
	var was_loading := loading
	loading = true
	_page_index = clampi(index,0,_pages.size()-1)
	content.text = _pages[_page_index]
	content.clear_undo_history()
	var prefix := content.text.left(caret_offset)
	var line := prefix.count("\n")
	var last_newline := prefix.rfind("\n")
	content.set_caret_line(line)
	content.set_caret_column(prefix.length()-last_newline-1)
	page_controls.visible = _pages.size() > 1
	previous_page.disabled = _page_index == 0
	next_page.disabled = _page_index == _pages.size()-1
	page_jump.text = str(_page_index+1)
	page_status.text = "of %d · Apply saves all parts" % _pages.size()
	loading = was_loading

func _change_page(direction: int) -> void:
	if loading or selected < 0: return
	_content_changed()
	_show_page(_page_index+direction)
	content.grab_focus()

func _jump_page(value: String) -> void:
	if loading or selected < 0: return
	if not value.strip_edges().is_valid_int():
		page_jump.text = str(_page_index+1)
		page_jump.select_all()
		return
	_content_changed()
	_show_page(int(value)-1)
	content.grab_focus()

func _content_changed() -> void:
	if apply_pending: return
	if loading or selected < 0 or selected >= draft.size() or _pages.is_empty(): return
	# A normal edit reads at most the current 4 Ki-character part. Clipboard
	# growth is intercepted before insertion; this also handles other edits
	# that cross the part boundary.
	var text := content.text
	if text == _pages[_page_index]: return
	_pages_dirty = true
	if text.length() <= PAGE_CHARACTERS:
		_pages[_page_index] = text
	else:
		var caret_offset := content.get_caret_column()
		for line: int in range(content.get_caret_line()):
			caret_offset += content.get_line(line).length()+1
		var first := _page_index
		_pages[first] = text.left(PAGE_CHARACTERS)
		var added := 0
		for offset: int in range(PAGE_CHARACTERS,text.length(),PAGE_CHARACTERS):
			added += 1
			_pages.insert(first+added,text.substr(offset,PAGE_CHARACTERS))
		var relative_page := mini(caret_offset/PAGE_CHARACTERS,added)
		_show_page(first+relative_page,caret_offset-relative_page*PAGE_CHARACTERS)
	_update_selected_caption()

func _text_offset(line: int, column: int) -> int:
	var offset := column
	for prior: int in range(line):
		offset += content.get_line(prior).length()+1
	return offset

func _append_page_text(pages: Array[String], value: String) -> void:
	var offset := 0
	while offset < value.length():
		if pages.is_empty() or pages[-1].length() == PAGE_CHARACTERS: pages.append("")
		var count := mini(PAGE_CHARACTERS-pages[-1].length(),value.length()-offset)
		pages[-1] += value.substr(offset,count)
		offset += count

func _intercept_paste(value: String, caret_index: int, whole_line: bool, one_line_each: bool) -> bool:
	if apply_pending: return true
	if loading or selected < 0 or selected >= draft.size() or _pages.is_empty(): return true
	var current := content.text
	var caret_count := content.get_caret_count() if caret_index == -1 else 1
	if current.length()+value.length()*caret_count <= PAGE_CHARACTERS: return false
	# Native TextEdit insertion removes CR. Normalize before measuring/splitting
	# so Windows clipboard line endings produce the same content and caret.
	var normalized := value.replace("\r","")
	var lines := normalized.split("\n") if one_line_each else PackedStringArray()
	var changes: Array[Dictionary] = []
	var projected_length := current.length()
	var carets := content.get_sorted_carets()
	for position: int in range(carets.size()):
		var index := carets[position]
		if caret_index != -1 and index != caret_index: continue
		var start := _text_offset(content.get_selection_from_line(index),content.get_selection_from_column(index))
		var end := _text_offset(content.get_selection_to_line(index),content.get_selection_to_column(index))
		if whole_line:
			start = _text_offset(content.get_caret_line(index),0)
			end = start
		var inserted: String = lines[position] if one_line_each else normalized
		changes.append({"from":start,"to":end,"text":inserted,"caret":index})
		projected_length += inserted.length()-(end-start)
	if projected_length <= PAGE_CHARACTERS: return false
	# Build bounded strings directly. The complete clipboard is never assigned
	# to TextEdit, including Paste from its native context menu or middle click.
	var replacement: Array[String] = []
	var consumed := 0
	var written := 0
	var focus_caret := maxi(caret_index,0)
	var new_caret := 0
	for change: Dictionary in changes:
		var prefix := current.substr(consumed,int(change.from)-consumed)
		_append_page_text(replacement,prefix)
		var inserted: String = change.text
		_append_page_text(replacement,inserted)
		written += prefix.length()+inserted.length()
		if int(change.caret) == focus_caret:
			new_caret = written
			if whole_line: new_caret += content.get_caret_column(focus_caret)
		consumed = int(change.to)
	_append_page_text(replacement,current.substr(consumed))
	if replacement.is_empty(): replacement.append("")
	var first := _page_index
	var updated: Array[String] = []
	updated.append_array(_pages.slice(0,first))
	updated.append_array(replacement)
	updated.append_array(_pages.slice(first+1))
	_pages = updated
	_pages_dirty = true
	# Part navigation can display only one part. All caret insertions are kept;
	# show the primary insertion endpoint in that bounded part.
	content.remove_secondary_carets()
	var relative_page := mini(new_caret/PAGE_CHARACTERS,replacement.size()-1)
	_show_page(first+relative_page,new_caret-relative_page*PAGE_CHARACTERS)
	_update_selected_caption()
	return true

func _update_selected_caption() -> void:
	if loading or selected < 0 or selected >= draft.size(): return
	if selected >= messages.item_count: return
	# A later part must not replace the message's first-line caption.
	var preview := ""
	for page: String in _pages:
		preview += page.left(70-preview.length())
		if preview.length() >= 70: break
	preview = preview.replace("\n"," ").replace("\r"," ")
	messages.set_item_text(selected,"%d · %s · %s" % [selected+1,str(draft[selected].get("role","user")),preview])

func flush_message() -> void:
	if apply_pending: return
	if loading or selected < 0 or selected >= draft.size(): return
	_content_changed()
	if not _pages_dirty: return
	var text := "".join(_pages)
	_pages_dirty = false
	if text == str(draft[selected].get("content","")): return
	var entry: Dictionary = draft[selected].duplicate()
	entry.content = text
	draft[selected] = entry
	_update_selected_caption()
