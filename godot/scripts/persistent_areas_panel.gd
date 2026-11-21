extends VBoxContainer

# This panel presents copied controller state. It owns no World, clock or save.
signal travel_requested(area_id: String)
signal ahead_requested(ticks: int)
signal catch_up_requested
signal save_requested
signal exit_requested
signal cancel_requested
signal retry_requested
signal recovery_requested

const Fixtures = preload("res://scripts/persistent_area_fixtures.gd")
const TICKS_PER_SECOND := 60
const AHEAD_SECONDS := [5,30,120]
var _area_buttons: Dictionary = {}
var _identity := Label.new()
var _clock := Label.new()
var _message := Label.new()
var _preset := OptionButton.new()
var _ahead: Button
var _catch_up: Button
var _save: Button
var _retry: Button
var _recovery: Button
var _details := AcceptDialog.new()
var _details_text := RichTextLabel.new()
var _overlay_layer := CanvasLayer.new()
var _overlay := Control.new()
var _operation_label := Label.new()
var _operation_detail := Label.new()
var _operation_progress := ProgressBar.new()
var _cancel: Button
var _last_state: Dictionary = {}


func _ready() -> void:
	name = "PersistentAreasPanel"
	add_theme_constant_override("separation",3)
	var panel_theme := Theme.new()
	panel_theme.default_font_size = 13
	theme = panel_theme
	var travel := HFlowContainer.new()
	travel.add_theme_constant_override("h_separation",6)
	add_child(travel)
	_identity.text = "PERSISTENT AREAS / experimental"
	_identity.add_theme_font_size_override("font_size",15)
	travel.add_child(_identity)
	for area: Dictionary in Fixtures.AREAS:
		var area_id: String = area.id
		var button := _button(travel,"%s · %s" % [area.letter,area.label],
			func() -> void: travel_requested.emit(area_id))
		button.name = "Travel_" + area_id
		button.tooltip_text = area.help
		_area_buttons[area_id] = button
	_button(travel,"Details / limits",_open_details)
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation",6)
	add_child(controls)
	_clock.text = "Game 0.00 s · Area 0.00 s · Debt 0.00 s"
	controls.add_child(_clock)
	for seconds: int in AHEAD_SECONDS:
		_preset.add_item("%d seconds" % seconds,seconds)
	_preset.tooltip_text = "Only completed native ticks count as game time. Existing debt is paid first."
	controls.add_child(_preset)
	_ahead = _button(controls,"Simulate Ahead",func() -> void:
		ahead_requested.emit(_preset.get_selected_id()*TICKS_PER_SECOND))
	_ahead.name = "SimulateAhead"
	_catch_up = _button(controls,"Pay catch-up debt",func() -> void: catch_up_requested.emit())
	_save = _button(controls,"Save all areas",func() -> void: save_requested.emit())
	_retry = _button(controls,"Retry saved profile",func() -> void: retry_requested.emit())
	_recovery = _button(controls,"Recover previous save",func() -> void: recovery_requested.emit())
	_button(controls,"Save & Menu",func() -> void: exit_requested.emit())
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.max_lines_visible = 2
	_message.clip_text = true
	_message.text = "Opening isolated persistent-area profile…"
	add_child(_message)
	_build_details()
	_build_overlay()
	if not _last_state.is_empty(): update_state(_last_state)


func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 28
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _build_details() -> void:
	_details.name = "PersistentAreaDetails"
	_details.title = "Persistent areas / state and supported domain"
	_details.dialog_text = ""
	_details.ok_button_text = "Close"
	_details.min_size = Vector2i(320,240)
	add_child(_details)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 14
	scroll.offset_top = 12
	scroll.offset_right = -14
	scroll.offset_bottom = -54
	_details.add_child(scroll)
	_details_text.bbcode_enabled = false
	_details_text.fit_content = true
	_details_text.scroll_active = false
	_details_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_text.custom_minimum_size.x = 280
	scroll.add_child(_details_text)


func _build_overlay() -> void:
	_overlay_layer.layer = 40
	add_child(_overlay_layer)
	_overlay.name = "PersistentAreaOperation"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.03,0.05,0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(centre)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(420,190)
	centre.add_child(box)
	var margin := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,18)
	box.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	margin.add_child(column)
	_operation_label.add_theme_font_size_override("font_size",19)
	column.add_child(_operation_label)
	_operation_progress.custom_minimum_size = Vector2(380,22)
	_operation_progress.show_percentage = false
	column.add_child(_operation_progress)
	_operation_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_operation_detail.custom_minimum_size = Vector2(380,48)
	_operation_detail.max_lines_visible = 4
	_operation_detail.clip_text = true
	column.add_child(_operation_detail)
	_cancel = _button(column,"Cancel safely",func() -> void: cancel_requested.emit())
	_cancel.name = "CancelPersistentOperation"
	_overlay.hide()


func update_state(state: Dictionary) -> void:
	_last_state = state.duplicate(true)
	if not is_node_ready(): return
	var area_id := str(state.get("active_area",""))
	var area := Fixtures.description(area_id)
	var busy := bool(state.get("busy",false))
	var ready := bool(state.get("ready",false))
	var lifecycle := str(state.get("state","Loading"))
	_identity.text = "PERSISTENT / %s" % ("%s · %s" % [area.letter,area.label] if not area.is_empty() else lifecycle)
	for id: String in _area_buttons:
		_area_buttons[id].disabled = busy or not ready or id == area_id
	_clock.text = "Game %.2f s · Area %.2f s · Debt %.2f s" % [
		float(state.get("game_tick",0))/TICKS_PER_SECOND,
		float(state.get("accounted_tick",0))/TICKS_PER_SECOND,
		float(state.get("debt_ticks",0))/TICKS_PER_SECOND]
	_ahead.disabled = busy or not ready
	_preset.disabled = busy or not ready
	_catch_up.disabled = busy or not ready or int(state.get("debt_ticks",0)) == 0
	_save.disabled = busy or not ready
	_retry.visible = not ready and not busy
	_recovery.visible = not ready and not busy and bool(state.get("recovery_available",false))
	_message.text = str(state.get("message",lifecycle))
	_message.tooltip_text = _message.text
	_overlay.visible = busy
	if busy:
		var operation: Dictionary = state.get("operation",{})
		_operation_label.text = lifecycle
		var requested := maxi(1,int(operation.get("requested_ticks",1)))
		_operation_progress.max_value = requested
		_operation_progress.value = mini(requested,int(operation.get("completed_ticks",0)))
		_operation_detail.text = str(operation.get("detail",_message.text))
		_cancel.disabled = not bool(operation.get("cancellable",true)) or bool(operation.get("cancel_requested",false))
		_cancel.text = "Cancelling after the current safe boundary…" if bool(operation.get("cancel_requested",false)) else "Cancel safely"
	_refresh_details()


func _refresh_details() -> void:
	var state := _last_state
	var lines := PackedStringArray([
		"GEN-006 / persistent authored areas — experimental, Draft/HOLD",
		"",
		"One 512 × 512 native area is active. Travel saves its full admitted native continuation, loads the selected area's retained state and runs bounded real native catch-up.",
		"",
		"Game time advances only with completed native ticks. Catch-up pays an area's existing debt. Simulate Ahead pays that debt first, then completed future ticks advance global time. Cancel preserves committed work and shows any remainder.",
		"",
		"Supported: ordinary material painting and erasing, native Current/FreeMass Water, Sand settling and supported native fire/reactions. Editor/camera travel; no actor transfer.",
		"Unsupported live actors/controllers, host emitters/equipment and pending edits pin the area. Wave, PressureFlow, inertial and ballistic Water are outside this profile. A refusal keeps the existing World. Ordinary authored Save and Flatten retain their existing meanings.",
		"",
		"Area Undo history is visit-scoped. Native material and dynamic state, including explicit Empty edits, remain persistent.",
		"",
		"Profile: " + str(state.get("profile","opening")),
		"Session: " + str(state.get("session_id","pending")),
		"Lifecycle: " + str(state.get("state","Loading")),
		"Durable manifest generation: " + str(state.get("durable_generation",0)),
		"Message: " + str(state.get("message","")),
	])
	var areas: Dictionary = state.get("areas",{})
	for area: Dictionary in Fixtures.AREAS:
		var record: Dictionary = areas.get(area.id,{})
		lines.append("%s · %s: accounted %.2f s, debt %.2f s, %s" % [area.letter,area.label,
			float(record.get("accounted_tick",0))/TICKS_PER_SECOND,
			float(record.get("debt_ticks",0))/TICKS_PER_SECOND,str(record.get("state","not initialized"))])
	_details_text.text = "\n".join(lines)


func _open_details() -> void:
	_refresh_details()
	# Essential Close remains the dialog's fixed footer; only details scroll.
	var usable := get_viewport_rect().size
	_details.popup_centered(Vector2i(mini(720,int(usable.x)-32),mini(480,int(usable.y)-48)))


func controls_visible_in_viewport() -> bool:
	# Graphical qualification can inspect real layout, including the busy footer.
	var bounds := get_viewport_rect()
	for button: Button in _area_buttons.values():
		if not bounds.encloses(button.get_global_rect()): return false
	for button: Button in [_ahead,_catch_up,_save]:
		if not bounds.encloses(button.get_global_rect()): return false
	return not _overlay.visible or bounds.encloses(_cancel.get_global_rect())
