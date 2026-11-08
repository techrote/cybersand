extends Window
## Read-only diagnostic viewer. Never dispatches agent or World commands.

const MAX_VISIBLE_RECORDS := 256
const TrafficProjection = preload("res://scripts/workbench_agent_traffic_projection.gd")
var exporter: Callable
var _metadata := {}
var _records: Array = []
var _events := ItemList.new()
var _details := TextEdit.new()
var _body := TextEdit.new()
var _tabs := TabContainer.new()
var _path := Label.new()
var _save := FileDialog.new()
var _conversation := TextEdit.new()
var _filters := {}
var _visible_indices: Array[int] = []
var _shown_record_id := ""

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
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation",8)
	for category: String in TrafficProjection.FILTERS:
		var toggle := CheckBox.new()
		toggle.text = category
		toggle.button_pressed = TrafficProjection.DEFAULT_FILTERS[category]
		toggle.tooltip_text = "Show " + category.to_lower() + " records. Categories can overlap; Raw includes every retained event."
		toggle.toggled.connect(func(_enabled: bool) -> void: _filters_changed())
		_filters[category] = toggle
		filters.add_child(toggle)
	column.add_child(filters)
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
	for editor: TextEdit in [_conversation,_body,_details]:
		editor.editable = false
		editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		editor.placeholder_text = "No traffic yet. Start an agent task to record requests, responses and native acknowledgements."
		editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conversation.name = "Conversation"
	_conversation.placeholder_text = "No messages match these filters. Conversation contains only recorded text and summaries, never hidden model reasoning."
	_tabs.add_child(_conversation)
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
	var selected_id := _selected_id()
	var selected := _events.get_selected_items()
	var following := selected.is_empty() or selected[0] == _visible_indices.size()-1
	# Keep the original bounded snapshot intact; filtering only changes indices.
	_records = records.slice(maxi(0,records.size()-MAX_VISIBLE_RECORDS))
	_metadata = metadata.duplicate(true)
	_metadata["diagnostic_export"] = true
	_metadata["retained_events"] = _records.size()
	_metadata["local_log_directory"] = directory
	_metadata["image_retention"] = "last32 PNGs; older links may expire"
	_rebuild_view(selected_id,following)

func _enabled_filters() -> Dictionary:
	var enabled := {}
	for category: String in _filters:
		enabled[category] = _filters[category].button_pressed
	return enabled

func _selected_id() -> String:
	var selected := _events.get_selected_items()
	if not selected.is_empty() and selected[0] < _visible_indices.size():
		return TrafficProjection.stable_id(_records[_visible_indices[selected[0]]])
	return ""

func _filters_changed() -> void:
	_rebuild_view(_selected_id(),false)

func _rebuild_view(selected_id: String, following: bool) -> void:
	var enabled := _enabled_filters()
	_events.clear()
	_visible_indices.clear()
	var next_selection := -1
	for i: int in range(_records.size()):
		if not TrafficProjection.matches(_records[i],enabled):
			continue
		_visible_indices.append(i)
		_events.add_item(_caption(_records[i]))
		if not following and TrafficProjection.stable_id(_records[i]) == selected_id:
			next_selection = _visible_indices.size()-1
	var dropped: int = int(_metadata.get("dropped_events",0))
	_path.text = "%d shown / %d retained / %d older events dropped. Categories overlap. Live log: %s" % [
		_visible_indices.size(),_records.size(),dropped,str(_metadata.get("local_log_directory",""))]
	if not str(_metadata.get("log_error","")).is_empty():
		_path.text += " Log error: " + str(_metadata.log_error)
	_conversation.text = TrafficProjection.conversation(_records,enabled)
	if not _visible_indices.is_empty():
		if next_selection < 0:
			next_selection = _visible_indices.size()-1
		_events.select(next_selection)
		if TrafficProjection.stable_id(_records[_visible_indices[next_selection]]) != _shown_record_id:
			_select_record(next_selection)
	else:
		_shown_record_id = ""
		_details.text = ""
		_body.text = ""

func _caption(record: Dictionary) -> String:
	var time: String = str(record.get("utc",record.get("timestamp",record.get("time",""))))
	var kind: String = str(record.get("kind",record.get("event","event")))
	return "#%s  %s  %s" % [str(record.get("sequence","")),time,kind]

func _select_record(index: int) -> void:
	if index >= 0 and index < _visible_indices.size():
		var record: Dictionary = _records[_visible_indices[index]]
		_shown_record_id = TrafficProjection.stable_id(record)
		_details.text = JSON.stringify(record,"  ",false)
		_details.set_caret_line(0)
		_body.text = _content(record)
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
	if not selected.is_empty() and selected[0] < _visible_indices.size():
		# Preserve the exact original text, regardless of pretty JSON display.
		DisplayServer.clipboard_set(_content(_records[_visible_indices[selected[0]]]))

func _copy_selected() -> void:
	if _tabs.current_tab == 0:
		DisplayServer.clipboard_set(_conversation.text)
	elif _tabs.current_tab == 1:
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
