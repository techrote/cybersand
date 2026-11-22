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
signal cache_configuration_requested(configuration: Dictionary)
signal prefetch_requested(area_id: String)
signal eviction_requested
signal diagnostics_requested
signal recoverable_save_requested
signal recovery_exit_requested(destination: String, expected_revision: int)

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
var _recoverable_save: Button
var _recovery_close: Button
var _recovery_exit_dialog := ConfirmationDialog.new()
var _recovery_exit_revision := 0
var _details := AcceptDialog.new()
var _details_text := RichTextLabel.new()
var _overlay_layer := CanvasLayer.new()
var _overlay := Control.new()
var _operation_label := Label.new()
var _operation_detail := Label.new()
var _operation_progress := ProgressBar.new()
var _cancel: Button
var _last_state: Dictionary = {}
var _cache_dialog := AcceptDialog.new()
var _cache_enabled := CheckButton.new()
var _cache_budget := OptionButton.new()
var _cache_custom := SpinBox.new()
var _deferred := CheckButton.new()
var _background := CheckButton.new()
var _prefetch := CheckButton.new()
var _cache_summary := Label.new()
var _cache_areas := RichTextLabel.new()
var _cache_prepare := OptionButton.new()
var _cache_apply: Button
var _cache_clear: Button
var _cache_save: Button
var _cache_notice := Label.new()
var _cache_controls_loaded := false


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
		button.mouse_entered.connect(func() -> void: prefetch_requested.emit(area_id))
		_area_buttons[area_id] = button
	_button(travel,"Details / limits",_open_details)
	_button(travel,"RAM cache…",_open_cache)
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
	_retry = _button(controls,"Retry safely",func() -> void: retry_requested.emit())
	_recovery = _button(controls,"Recover previous save",func() -> void: recovery_requested.emit())
	_recoverable_save = _button(controls,"Save recoverable areas",func() -> void: recoverable_save_requested.emit())
	_recoverable_save.tooltip_text = "Save only captured healthy inactive areas. The failed active World remains quarantined and is not claimed as durably saved."
	_recovery_close = _button(controls,"Close recovery profile…",_open_recovery_exit)
	_button(controls,"Save & Menu",func() -> void: exit_requested.emit())
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.max_lines_visible = 2
	_message.clip_text = true
	_message.text = "Opening isolated persistent-area profile…"
	add_child(_message)
	_build_details()
	_build_cache()
	_build_overlay()
	_recovery_exit_dialog.title = "Close using the recovery save?"
	_recovery_exit_dialog.ok_button_text = "Close recovery profile"
	_recovery_exit_dialog.confirmed.connect(func() -> void: recovery_exit_requested.emit("launcher",_recovery_exit_revision))
	add_child(_recovery_exit_dialog)
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


func _build_cache() -> void:
	_cache_dialog.name = "PersistentAreaCache"
	_cache_dialog.title = "RAM cache / persistence / destination preparation"
	_cache_dialog.dialog_text = ""
	_cache_dialog.ok_button_text = "Close"
	_cache_dialog.min_size = Vector2i(340,260)
	add_child(_cache_dialog)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 14
	scroll.offset_top = 10
	scroll.offset_right = -14
	scroll.offset_bottom = -52
	_cache_dialog.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	scroll.add_child(column)
	_cache_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_cache_summary)
	_cache_enabled.text = "Keep admitted native Worlds in RAM"
	column.add_child(_cache_enabled)
	var budget_row := HFlowContainer.new()
	column.add_child(budget_row)
	var budget_label := Label.new()
	budget_label.text = "Cache admission budget"
	budget_row.add_child(budget_label)
	for megabytes: int in [512,1024,2048,4096,8192]:
		_cache_budget.add_item("%d MiB" % megabytes,megabytes)
	_cache_budget.add_item("Custom MiB",0)
	budget_row.add_child(_cache_budget)
	_cache_custom.min_value = 1
	_cache_custom.max_value = 8192
	_cache_custom.step = 1
	_cache_custom.value = 512
	_cache_custom.suffix = "MiB"
	_cache_custom.custom_minimum_size.x = 120
	budget_row.add_child(_cache_custom)
	_cache_custom.visible = false
	_cache_budget.item_selected.connect(func(_index: int) -> void:
		_cache_custom.visible = _cache_budget.get_selected_id() == 0)
	_deferred.text = "Allow travel before disk saving finishes"
	_deferred.tooltip_text = "Changes stay authoritative in RAM. A crash can lose changes that have not reached a durable acknowledgement. Save all waits for durability."
	column.add_child(_deferred)
	_cache_notice.text = "Strict durability is the default. Deferred mode keeps unsaved changes in RAM; a process crash may lose them. Save all waits for an acknowledged durable checkpoint."
	_cache_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_cache_notice)
	_background.text = "Save dirty areas in the background"
	column.add_child(_background)
	_prefetch.text = "Prepare likely destinations before travel"
	column.add_child(_prefetch)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	_cache_apply = _button(actions,"Apply cache settings",func() -> void:
		var megabytes := int(_cache_custom.value) if _cache_budget.get_selected_id() == 0 else _cache_budget.get_selected_id()
		cache_configuration_requested.emit({"enabled":_cache_enabled.button_pressed,
			"budget_bytes":megabytes*1024*1024,"deferred":_deferred.button_pressed,
			"background":_background.button_pressed,"prefetch":_prefetch.button_pressed}))
	_cache_clear = _button(actions,"Evict inactive safely",func() -> void: eviction_requested.emit())
	_cache_save = _button(actions,"Save all areas",func() -> void: save_requested.emit())
	_button(actions,"Export diagnostics",func() -> void: diagnostics_requested.emit())
	var preparation := HFlowContainer.new()
	column.add_child(preparation)
	for area: Dictionary in Fixtures.AREAS:
		_cache_prepare.add_item("%s · %s" % [area.letter,area.label])
	preparation.add_child(_cache_prepare)
	_button(preparation,"Prepare destination",func() -> void:
		prefetch_requested.emit(str(Fixtures.AREAS[_cache_prepare.selected].id)))
	_cache_areas.bbcode_enabled = false
	_cache_areas.fit_content = true
	_cache_areas.scroll_active = false
	_cache_areas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cache_areas.custom_minimum_size.y = 100
	column.add_child(_cache_areas)


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
	_recoverable_save.visible = not busy and bool(state.get("recoverable_save_available",false))
	_recovery_close.visible = not busy and not state.get("recovery_close",{}).is_empty()
	_recovery_close.text = "Close recovery profile…" if state.get("recovery_close",{}).get("has_healthy_recovery",false) else "Close failed profile…"
	_message.text = str(state.get("message",lifecycle))
	_message.tooltip_text = _message.text
	_overlay.visible = busy
	if busy:
		# Keep the operation's essential Cancel reachable; a settings Window
		# must not remain modal above the live progress/cancellation controls.
		_cache_dialog.hide()
		_details.hide()
		var operation: Dictionary = state.get("operation",{})
		_operation_label.text = lifecycle
		var requested := maxi(1,int(operation.get("requested_ticks",1)))
		_operation_progress.max_value = requested
		_operation_progress.value = mini(requested,int(operation.get("completed_ticks",0)))
		_operation_detail.text = str(operation.get("detail",_message.text))
		_cancel.disabled = not bool(operation.get("cancellable",true)) or bool(operation.get("cancel_requested",false))
		_cancel.text = "Cancelling after the current safe boundary…" if bool(operation.get("cancel_requested",false)) else "Cancel safely"
	_refresh_details()
	_refresh_cache()


func _open_recovery_exit() -> void:
	var summary: Dictionary = _last_state.get("recovery_close",{})
	if summary.is_empty(): return
	_recovery_exit_revision = int(summary.durable_revision)
	var first_line := "Healthy areas %s have a durable recovery save." % ", ".join(summary.saved_areas) \
		if summary.get("has_healthy_recovery",false) else "The other areas already have acknowledged durable saves."
	_recovery_exit_dialog.dialog_text = first_line+"\nArea %s remains failed; only its last durable tick %d is saved.\nClosing discards that failed World's unsaved RAM state\nand %d unbacked game-time ticks. No failed World is reset.\nReopening restores the acknowledged recovery profile.\n\nClose this recovery profile and return to the menu?" % [
		str(summary.failed_area).to_upper(),int(summary.failed_area_durable_native_tick),
		int(summary.omitted_ram_game_ticks)]
	var extent := get_viewport_rect().size
	_recovery_exit_dialog.popup_centered(Vector2i(mini(640,int(extent.x)-32),mini(280,int(extent.y)-48)))


func _refresh_details() -> void:
	var state := _last_state
	var lines := PackedStringArray([
		"GEN-006 / persistent authored areas — experimental, Draft/HOLD",
		"",
		"One 512 × 512 native area is active. The optional RAM cache retains admitted native Worlds. A hot return transfers an existing World; warm and cold returns reconstruct its validated native continuation. Remaining game-time debt stays visible.",
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


func _refresh_cache() -> void:
	var state := _last_state
	var cache: Dictionary = state.get("cache",{})
	var configuration: Dictionary = state.get("cache_configuration",{})
	if not _cache_controls_loaded and not configuration.is_empty():
		_cache_controls_loaded = true
		_cache_enabled.set_pressed_no_signal(bool(configuration.get("enabled",true)))
		_deferred.set_pressed_no_signal(bool(configuration.get("deferred",false)))
		_background.set_pressed_no_signal(bool(configuration.get("background",true)))
		_prefetch.set_pressed_no_signal(bool(configuration.get("prefetch",false)))
		var megabytes := int(configuration.get("budget_bytes",512*1024*1024))/1024/1024
		var index := _cache_budget.get_item_index(megabytes)
		_cache_budget.select(index if index>=0 else _cache_budget.item_count-1)
		_cache_custom.value = megabytes
		_cache_custom.visible = index<0
	var accounting: Dictionary = cache.get("accounting",{})
	var retained := int(accounting.get("retained_bytes",cache.get("used_bytes",0)))
	var reserved := int(accounting.get("reserved_bytes",cache.get("reserved_bytes",0)))
	var counters: Dictionary = cache.get("counters",{})
	_cache_summary.text = "\n".join(PackedStringArray([
		"HOT %d · WARM %d · COLD %d" % [int(cache.get("hot_count",0)),int(cache.get("warm_count",0)),int(cache.get("cold_count",3))],
		"Cache lookups: %d HOT hits · %d WARM hits · %d COLD misses" % [int(counters.get("hot_hits",0)),int(counters.get("warm_hits",0)),int(counters.get("cold_misses",0))],
		"Accounted %.2f MiB; preparation reserved %.2f MiB; publication %.2f / %.0f MiB." % [
			float(retained)/1048576.0,float(reserved)/1048576.0,
			float(cache.get("essential_publication_reserved_bytes",0))/1048576.0,float(cache.get("essential_publication_cap_bytes",0))/1048576.0],
		"Native capacity estimate %.2f MiB (last observed); growth reserve %.2f MiB." % [
			float(cache.get("native_bytes",0))/1048576.0,float(cache.get("native_headroom_bytes",0))/1048576.0],
		"Measured encoded payloads: WARM %.2f MiB; authoring %.2f MiB." % [
			float(cache.get("warm_bytes",0))/1048576.0,float(cache.get("authoring_bytes",0))/1048576.0],
		"These values are not process RSS. The external evaluator measures working set / RSS.",
	]))
	_cache_summary.tooltip_text = "Cache lookups count admitted tier selections, including Ahead/catch-up and operations later cancelled or refused; they are not successful arrival counts. Native capacity is the last observed owned-container estimate, excluding allocator and external host/renderer overhead. Encoded payload sizes count bytes, not all host allocations. Growth, preparation and essential publication reservations are admitted headroom; they are not measured resident memory."
	var lines := PackedStringArray()
	for area: Dictionary in Fixtures.AREAS:
		var record: Dictionary = state.get("areas",{}).get(area.id,{})
		lines.append("%s · %s: %s\n  Behind game time %.2f s; %s" % [area.letter,area.label,
			str(record.get("residency","COLD")),float(record.get("debt_ticks",0))/TICKS_PER_SECOND,
			str(record.get("durability","durably saved"))])
	var saving: Dictionary = state.get("writeback",{})
	lines.append("Background publication: "+str(saving.get("status","idle")))
	lines.append("Destination preparation: "+str(state.get("prefetch",{}).get("message","idle")))
	_cache_areas.text = "\n".join(lines)
	var busy := bool(state.get("busy",false))
	_cache_apply.disabled = busy
	_cache_clear.disabled = busy or not bool(state.get("ready",false))
	_cache_save.disabled = busy or not bool(state.get("ready",false))


func _open_cache() -> void:
	_cache_controls_loaded = false
	_refresh_cache()
	var usable := get_viewport_rect().size
	_cache_dialog.popup_centered(Vector2i(mini(760,int(usable.x)-32),mini(580,int(usable.y)-48)))


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
