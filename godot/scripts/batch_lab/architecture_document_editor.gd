extends VBoxContainer
## Optional typed document editing. Only one bounded page enters TextEdit;
## the complete draft is retained and validated when the owner applies it.
signal draft_changed

const PAGE_CHARACTERS := 4096
const MAX_BYTES := 2*1024*1024
var editor := TextEdit.new()
var page_number := SpinBox.new()
var page_label := Label.new()
var warning := Label.new()
var _document := ""
var _page := 0
var _page_start := 0
var _page_length := 0
var _updating := false
var _dirty := false
var _last_accepted_page := ""
var text: String:
	get: return complete_text()
	set(value): set_document(value)

func _ready() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var previous := Button.new()
	previous.text = "Previous page"
	previous.pressed.connect(func() -> void: show_page(_page-1))
	row.add_child(previous)
	page_number.min_value = 1
	page_number.max_value = 1
	page_number.custom_minimum_size.x = 76
	page_number.value_changed.connect(func(value: float) -> void:
		if not _updating: show_page(int(value)-1))
	row.add_child(page_number)
	row.add_child(page_label)
	var next := Button.new()
	next.text = "Next page"
	next.pressed.connect(func() -> void: show_page(_page+1))
	row.add_child(next)
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.custom_minimum_size.y = 150
	editor.text_changed.connect(_page_edited)
	add_child(editor)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.text = "Advanced typed draft. Page boundaries may split a JSON field; Apply validates the complete document. No native writes."
	add_child(warning)
	show_page(0)

func set_document(value: String) -> bool:
	if value.to_utf8_buffer().size()>MAX_BYTES:
		warning.text = "Typed draft exceeds 2 MiB. The previous draft is retained."
		return false
	_document = value
	_dirty = false
	_page = 0
	_page_start = 0
	_page_length = 0
	if is_node_ready(): show_page(0)
	return true

func complete_text() -> String:
	_flush_page()
	return _document

func parsed() -> Dictionary:
	var value := complete_text()
	if value.to_utf8_buffer().size()>MAX_BYTES:
		return {"ok":false,"reason":"Typed draft exceeds 2 MiB."}
	var parser := JSON.new()
	if parser.parse(value)!=OK:
		return {"ok":false,"reason":"Typed draft JSON line %d: %s" % [parser.get_error_line(),parser.get_error_message()]}
	if not parser.data is Dictionary: return {"ok":false,"reason":"A typed stage must be a JSON object."}
	return {"ok":true,"value":parser.data}

func show_page(index: int) -> void:
	_flush_page()
	var pages := maxi(1,ceili(float(_document.length())/PAGE_CHARACTERS))
	_page = clampi(index,0,pages-1)
	_page_start = _page*PAGE_CHARACTERS
	_page_length = mini(PAGE_CHARACTERS,maxi(0,_document.length()-_page_start))
	_updating = true
	editor.text = _document.substr(_page_start,_page_length)
	_last_accepted_page = editor.text
	page_number.max_value = pages
	page_number.value = _page+1
	page_label.text = "of %d · %d characters in complete draft" % [pages,_document.length()]
	_updating = false
	_dirty = false

func _page_edited() -> void:
	if _updating: return
	# Paste is bounded too: reject this page edit without losing the complete draft.
	var proposed_size := _document.to_utf8_buffer().size()-_document.substr(_page_start,_page_length).to_utf8_buffer().size()+editor.text.to_utf8_buffer().size()
	if editor.text.length()>PAGE_CHARACTERS*2 or proposed_size>MAX_BYTES:
		_updating = true
		editor.text = _last_accepted_page
		_updating = false
		warning.text = "This page accepts at most 8,192 characters and the complete draft at most 2 MiB. The previous page is retained."
		return
	_last_accepted_page = editor.text
	_dirty = true
	draft_changed.emit()

func _flush_page() -> void:
	if not _dirty or _updating: return
	_document = _document.left(_page_start)+editor.text+_document.substr(_page_start+_page_length)
	_page_length = editor.text.length()
	_dirty = false
