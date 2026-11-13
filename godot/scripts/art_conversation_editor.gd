extends ConfirmationDialog
## A draft of future model context. The provider's native/HTTP audit stays append-only.
const HELP := "Edit future model context only. Apply saves the draft; Cancel discards it. Canvas state and original traffic are unchanged."
var baseline: Array = []
var draft: Array = []
var messages := ItemList.new()
var content := TextEdit.new()
var role := Label.new()
var notice := Label.new()
var remove_button := Button.new()
var selected := -1
var loading := false

func _ready() -> void:
	title = "Conversation history"
	min_size = Vector2i(480,280)
	size = Vector2i(760,480)
	exclusive = false
	dialog_hide_on_ok = false
	get_ok_button().text = "Apply"
	close_requested.connect(hide)
	var box := VBoxContainer.new()
	add_child(box)
	notice.text = HELP
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(notice)
	var actions := HBoxContainer.new()
	var note := Button.new()
	note.text = "+ Note"
	note.pressed.connect(func() -> void:
		flush_message()
		draft.append({"role":"user","content":""})
		_rebuild(draft.size()-1)
		content.grab_focus())
	actions.add_child(note)
	remove_button.text = "Remove"
	remove_button.pressed.connect(func() -> void:
		flush_message()
		if selected >= 0 and selected < draft.size():
			draft.remove_at(selected)
			_rebuild(mini(selected,draft.size()-1)))
	actions.add_child(remove_button)
	var clear := Button.new()
	clear.text = "Clear draft"
	clear.tooltip_text = "Remove all messages from this draft. Cancel still preserves live history."
	clear.pressed.connect(func() -> void: draft.clear(); _rebuild(-1))
	actions.add_child(clear)
	box.add_child(actions)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	messages.custom_minimum_size.x = 170
	messages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages.item_selected.connect(func(index: int) -> void: flush_message(); _select_message(index))
	split.add_child(messages)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(detail)
	detail.add_child(role)
	content.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.text_changed.connect(_store_message)
	detail.add_child(content)

func open_history(turns: Array) -> void:
	baseline = turns.duplicate(true)
	draft = turns.duplicate(true)
	notice.text = HELP
	_rebuild(0 if not draft.is_empty() else -1)
	popup_centered()

func _caption(index: int) -> String:
	var turn: Dictionary = draft[index]
	var text := str(turn.get("content","")).replace("\n"," ").replace("\r"," ")
	return "%d · %s · %s" % [index+1,str(turn.get("role","user")),text.left(70)]

func _rebuild(next: int) -> void:
	messages.clear()
	for i: int in draft.size(): messages.add_item(_caption(i))
	_select_message(next)
	if selected >= 0:
		messages.select(selected)
		messages.ensure_current_is_visible()

func _select_message(index: int) -> void:
	loading = true
	selected = index if index >= 0 and index < draft.size() else -1
	content.editable = selected >= 0
	remove_button.disabled = selected < 0
	if selected >= 0:
		var turn: Dictionary = draft[selected]
		role.text = "%d / %d · %s%s" % [selected+1,draft.size(),str(turn.role).capitalize(),
			" · original image retained" if turn.has("image_offset") else ""]
		content.text = str(turn.content)
	else:
		role.text = "No messages · add a note or Cancel"
		content.text = ""
	content.clear_undo_history()
	loading = false

func _store_message() -> void:
	if loading or selected < 0 or selected >= draft.size(): return
	draft[selected].content = content.text
	messages.set_item_text(selected,_caption(selected))

func flush_message() -> void:
	_store_message()
