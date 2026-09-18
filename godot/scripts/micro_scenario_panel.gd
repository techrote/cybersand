class_name CyberMicroScenarioPanel
extends VBoxContainer

var host: Control
var picker: OptionButton
var mode_picker: OptionButton
var seed_input: SpinBox
var info: Label
var editor: Window
var text: TextEdit
var launch_button: Button
var capture_button: Button
var definition_button: Button

func button(row: Node, caption: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = caption
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	row.add_child(b)
	return b

func setup(controller: Control) -> void:
	host = controller
	name = "MicroScenarios"
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	picker = OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	picker.custom_minimum_size.x = 320
	for id: String in CyberMicroScenarioCatalogue.ids(): picker.add_item(id)
	picker.select(1)
	row.add_child(picker)
	mode_picker = OptionButton.new()
	mode_picker.focus_mode = Control.FOCUS_NONE
	for mode: String in CyberMicroScenarioContract.MODES: mode_picker.add_item(mode.capitalize())
	mode_picker.select(1)
	row.add_child(mode_picker)
	seed_input = SpinBox.new()
	seed_input.min_value = 0
	seed_input.max_value = CyberMicroScenarioContract.MAX_SEED
	seed_input.step = 1
	seed_input.prefix = "Seed "
	seed_input.custom_minimum_size.x = 160
	row.add_child(seed_input)
	launch_button = button(row, "Load / reset selection", func() -> void:
		host.micro_launch(picker.get_item_text(picker.selected), selected_mode(), int(seed_input.value)))
	button(row, "Reset current", func() -> void: host.micro_reset_current())
	var controls: HBoxContainer = HBoxContainer.new()
	add_child(controls)
	button(controls, "Pause / resume", func() -> void: host.paused = not host.paused)
	button(controls, "Single step", func() -> void: host.tower_command({"step": true}))
	capture_button = button(controls, "Capture observation", func() -> void: host.micro_capture_observation())
	definition_button = button(controls, "Definition JSON…", open_definition)
	button(controls, "Hide HUD / F4", func() -> void: host.micro_toggle_hud())
	info = Label.new()
	info.add_theme_font_size_override("font_size", 14)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info)
	editor = Window.new()
	editor.title = "MicroScenario definition — data only, not replay"
	editor.size = Vector2i(850, 560)
	editor.close_requested.connect(editor.hide)
	editor.visible = false
	add_child(editor)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.add_child(box)
	text = TextEdit.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text)
	var edit_row: HBoxContainer = HBoxContainer.new()
	box.add_child(edit_row)
	button(edit_row, "Validate + apply JSON", apply_json)
	button(edit_row, "Copy JSON", func() -> void:
		if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD): DisplayServer.clipboard_set(text.text))
	button(edit_row, "Close", editor.hide)

func selected_mode() -> String:
	return CyberMicroScenarioContract.MODES[mode_picker.selected]

func text_entry_active() -> bool:
	return editor.visible or seed_input.get_line_edit().has_focus()

func open_definition() -> void:
	if host.micro_blind_active(): return
	var definition: Dictionary = host.micro_current_definition
	if definition.is_empty():
		definition = CyberMicroScenarioCatalogue.definition(picker.get_item_text(picker.selected), int(seed_input.value))
	var checked: Dictionary = CyberMicroScenarioContract.validate(definition)
	text.text = JSON.stringify(checked.get("definition", definition), "  ")
	editor.popup_centered()

func apply_json() -> void:
	if text.text.to_utf8_buffer().size() > CyberMicroScenarioContract.MAX_BYTES:
		host.micro_notice = "Definition exceeds 2 MiB budget"; return
	var parsed: Variant = JSON.parse_string(text.text)
	if host.micro_apply_definition(parsed, selected_mode()): editor.hide()

func refresh() -> void:
	var blind: bool = host.micro_blind_active()
	launch_button.disabled = blind
	capture_button.disabled = blind
	definition_button.disabled = blind
	var state: Dictionary = host.tower_context.get("micro", {})
	if blind:
		info.text = "Registered Water blind session: use the existing reveal/export controls."
		return
	info.text = host.micro_notice
	if not str(state.get("id", "")).is_empty():
		info.text += "  %s / %s / events %s / objectives %s" % [
			state.id, state.get("mode", "inspect"), state.get("event_index", 0),
			JSON.stringify(state.get("objectives", {}))]
