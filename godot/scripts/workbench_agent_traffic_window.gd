extends Window
## Read-only diagnostic viewer. Never dispatches agent or World commands.

const MAX_VISIBLE_RECORDS := 256
var exporter: Callable
var _metadata := {}
var _records: Array = []
var _events := ItemList.new()
var _details := TextEdit.new()
var _body := TextEdit.new()
var _tabs := TabContainer.new()
var _path := Label.new()
var _save := FileDialog.new()

func _ready() -> void:
	title = "Agent traffic"
	size = Vector2i(1000,650)
	min_size = Vector2i(640,400)
	transient = true
	exclusive = false
	visible = false
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["margin_left","margin_top","margin_right","margin_bottom"]:
		margin.add_theme_constant_override(edge,10)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var actions := HBoxContainer.new()
	for spec: Array in [["Copy",_copy_selected],["Copy all",_copy_all],["Save JSONL…",_save_dialog]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		actions.add_child(button)
	var close := Button.new()
	close.text = "Hide"
	close.pressed.connect(hide)
	actions.add_child(close)
	column.add_child(actions)
	_path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path.text = "Select a call to inspect its full recorded content. Authorization credentials are excluded."
	column.add_child(_path)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 300
	column.add_child(split)
	_events.custom_minimum_size.x = 230
	_events.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_events.item_selected.connect(_select_record)
	split.add_child(_events)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_tabs)
	for editor: TextEdit in [_body,_details]:
		editor.editable = false
		editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		editor.placeholder_text = "No traffic yet. Start an agent task to record requests, responses and native acknowledgements."
		editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.name = "Content"
	_details.name = "Event"
	_tabs.add_child(_body)
	_tabs.add_child(_details)
	_save.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save.access = FileDialog.ACCESS_FILESYSTEM
	_save.filters = PackedStringArray(["*.jsonl ; JSON Lines diagnostic log"])
	_save.file_selected.connect(_export_to)
	add_child(_save)

func set_records(records: Array, directory: String = "", metadata: Dictionary = {}) -> void:
	var selected_sequence: int = -1
	var selected := _events.get_selected_items()
	var following := selected.is_empty() or selected[0] == _records.size()-1
	if not selected.is_empty() and selected[0] < _records.size():
		selected_sequence = int(_records[selected[0]].get("sequence",-1))
	# The client's bounded immutable snapshot is the only retained history.
	# Do not accumulate a second unbounded copy of its emitted event stream.
	_records = records.slice(maxi(0,records.size()-MAX_VISIBLE_RECORDS))
	_metadata = metadata.duplicate(true)
	_metadata["diagnostic_export"] = true
	_metadata["retained_events"] = _records.size()
	_metadata["local_log_directory"] = directory
	_metadata["image_retention"] = "last32 PNGs; older links may expire"
	_events.clear()
	var next_selection := _records.size()-1
	for i: int in range(_records.size()):
		_events.add_item(_caption(_records[i]))
		if not following and int(_records[i].get("sequence",-1)) == selected_sequence:
			next_selection = i
	var dropped: int = int(metadata.get("dropped_events",0))
	_path.text = "Live log: " + directory + " · %d retained / %d older events dropped. Image bytes are separate PNGs." % [_records.size(),dropped]
	if not str(metadata.get("log_error","")).is_empty():
		_path.text += " Log error: " + str(metadata.log_error)
	if not _records.is_empty():
		_events.select(next_selection)
		if int(_records[next_selection].get("sequence",-2)) != selected_sequence:
			_select_record(next_selection)
	else:
		_details.text = ""
		_body.text = ""

func _caption(record: Dictionary) -> String:
	var time: String = str(record.get("utc",record.get("timestamp",record.get("time",""))))
	var kind: String = str(record.get("kind",record.get("event","event")))
	return "#%s  %s  %s" % [str(record.get("sequence","")),time,kind]

func _select_record(index: int) -> void:
	if index >= 0 and index < _records.size():
		_details.text = JSON.stringify(_records[index],"  ",false)
		_details.set_caret_line(0)
		var content: String = _content(_records[index])
		_body.text = content
		_body.set_caret_line(0)

func _content(record: Dictionary) -> String:
	var payload: Variant = record.get("payload",record)
	if payload is Dictionary and payload.has("body"):
		payload = payload.body
	elif payload is Dictionary and payload.has("receipt"):
		payload = payload.receipt
	return payload if payload is String else JSON.stringify(payload,"  ",false)

func _copy_content() -> void:
	var selected := _events.get_selected_items()
	if not selected.is_empty() and selected[0] < _records.size():
		# Preserve the exact original text, regardless of pretty JSON display.
		DisplayServer.clipboard_set(_content(_records[selected[0]]))

func _copy_selected() -> void:
	if _tabs.current_tab == 0:
		_copy_content()
	else:
		DisplayServer.clipboard_set(_details.text)

func _jsonl() -> String:
	var lines := PackedStringArray([JSON.stringify(_metadata)])
	for record: Dictionary in _records:
		lines.append(JSON.stringify(record))
	return "\n".join(lines) + ("\n" if not lines.is_empty() else "")

func _copy_all() -> void:
	DisplayServer.clipboard_set(_jsonl())

func _save_dialog() -> void:
	_save.current_file = "cybersand-agent-traffic.jsonl"
	_save.popup_centered_ratio(0.8)

func _export_to(path: String) -> void:
	if exporter.is_valid():
		var result: int = exporter.call(path)
		_path.text = "Saved retained traffic and retention metadata to " + path if result == OK else "Could not save log: " + error_string(result)
		return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		_path.text = "Could not save log: " + error_string(FileAccess.get_open_error())
		return
	file.store_string(_jsonl())
	_path.text = "Saved " + str(_records.size()) + " events to " + path
