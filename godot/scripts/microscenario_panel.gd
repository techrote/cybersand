class_name CyberMicroScenarioPanel
extends VBoxContainer

const Workbench = preload("res://scripts/microscenario_workbench.gd")
var workbench: CyberMicroScenarioWorkbench
var host: Control
var picker: OptionButton
var mode: OptionButton
var seed_input: SpinBox
var launch_button: Button
var reset_button: Button
var pause_button: Button
var step_button: Button
var definition_button: Button
var definition_dialog: AcceptDialog
var definition_text: TextEdit
var definition_error: Label
var capture_button: Button
var status: Label
var shown_identity: String = ""

func _button(row: Node, text: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = text
	control.focus_mode = Control.FOCUS_NONE
	control.pressed.connect(action)
	row.add_child(control)
	return control

func setup(controller: Control) -> void:
	host = controller
	name = "MicroScenarioControls"
	var row := HFlowContainer.new()
	add_child(row)
	picker = OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	for scenario_id: String in CyberMicroScenarioCatalogue.ids(): picker.add_item(scenario_id)
	row.add_child(picker)
	mode = OptionButton.new()
	mode.focus_mode = Control.FOCUS_NONE
	for value: String in CyberMicroScenarioContract.MODES: mode.add_item(value)
	mode.select(1)
	row.add_child(mode)
	seed_input = SpinBox.new()
	seed_input.min_value = 0
	seed_input.max_value = 0x7FFFFFFF
	seed_input.step = 1
	seed_input.prefix = "Seed "
	seed_input.custom_minimum_size.x = 125
	seed_input.get_line_edit().text_submitted.connect(func(_text: String) -> void: seed_input.get_line_edit().release_focus())
	row.add_child(seed_input)
	launch_button = _button(row, "Load selected", _launch)
	reset_button = _button(row, "Fresh reset", func() -> void: host.microscenario_reset())
	pause_button = _button(row, "Pause / resume", func() -> void: host.paused = not host.paused)
	step_button = _button(row, "Single step", func() -> void: host.tower_command({"step":true}))
	definition_button = _button(row, "Definition JSON", _open_definition)
	capture_button = _button(row, "Capture", func() -> void: host.microscenario_capture())
	_button(row, "Hide HUD / F8", func() -> void: host.microscenario_toggle_hud())
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	add_child(status)
	definition_dialog = AcceptDialog.new()
	definition_dialog.title = "MicroScenario definition / fresh reset"
	definition_dialog.dialog_hide_on_ok = false
	definition_dialog.get_ok_button().text = "Validate + apply"
	definition_dialog.confirmed.connect(_apply_definition)
	add_child(definition_dialog)
	var form := VBoxContainer.new()
	definition_dialog.add_child(form)
	definition_error = Label.new()
	definition_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(definition_error)
	definition_text = TextEdit.new()
	definition_text.custom_minimum_size = Vector2(800, 460)
	definition_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(definition_text)
	workbench = Workbench.new()
	add_child(workbench)
	workbench.setup(host)

func modal_open() -> bool:
	return definition_dialog.visible or workbench.modal_open()

func _launch() -> void:
	get_viewport().gui_release_focus()
	if not host.microscenario_launch(picker.get_item_text(picker.selected),
		mode.get_item_text(mode.selected), int(seed_input.value)):
		status.text = "Scenario rejected; active world preserved. " + str(host.microscenario_error)

func refresh(context: Dictionary) -> void:
	workbench.refresh(context)
	if host.microscenario_hud_hidden: definition_dialog.hide()
	var blind: bool = not host.water_blind_set.is_empty() or not host.water_active_blind_label.is_empty()
	var pending: bool = not host.pending_microscenario_apply.is_empty() or not host.pending_water_apply.is_empty()
	picker.disabled = blind or pending
	mode.disabled = blind or pending
	seed_input.editable = not blind and not pending
	definition_button.disabled = blind or pending
	launch_button.disabled = blind or pending
	reset_button.disabled = pending
	pause_button.disabled = pending
	step_button.disabled = pending or context.get("microscenario", {}).is_empty()
	capture_button.disabled = blind or pending or context.get("microscenario", {}).is_empty()
	if blind:
		status.text = "Water blind session active: use its existing reveal/export workflow."
		return
	var data: Dictionary = context.get("microscenario", {})
	var identity: String = str(data.get("definition_hash", "")) + "/" + str(data.get("mode", ""))
	if not data.is_empty() and identity != shown_identity:
		shown_identity = identity
		var index: int = CyberMicroScenarioCatalogue.ids().find(str(data.id))
		picker.select(index)
		mode.select(CyberMicroScenarioContract.MODES.find(str(data.mode)))
		seed_input.value = int(data.seed)
	launch_button.disabled = launch_button.disabled or picker.selected < 0
	if data.is_empty():
		status.text = "MicroScenarios: shared Play / Inspect / Benchmark definitions. F8 restores the HUD."
		return
	status.text = "%s / %s / %s / tick %s / %s / player %s" % [
		str(data.id),
		str(data.mode),
		str(data.maturity),
		str(context.get("tick", 0)),
		str(data.get("outcome", "running")),
		str(host.player_representation_identity()),
	]
	if data.mode != "Play":
		for observation: Dictionary in data.get("observations", []).slice(-3):
			var value: Variant = observation.value
			if value is Dictionary:
				value = "material=%s a=%s b=%s T=%s" % [value.get("material","?"),value.get("state_a","?"),value.get("state_b","?"),value.get("temperature_raw","unavailable")]
			status.text += " / %s=%s (%s)" % [observation.id, value, observation.metric]
	if not str(data.get("error", "")).is_empty(): status.text += " / " + str(data.error)

func _open_definition() -> void:
	if (not host.water_blind_set.is_empty() or not host.water_active_blind_label.is_empty()
		or not host.pending_water_apply.is_empty() or not host.pending_microscenario_apply.is_empty()): return
	workbench.cancel_declared_window()
	host.paused = true
	var definition: Dictionary = host.microscenario_definition.duplicate(true)
	if not context_is_generic():
		definition = CyberMicroScenarioCatalogue.definition(picker.get_item_text(picker.selected), int(seed_input.value))
	var checked: Dictionary = CyberMicroScenarioContract.validate(definition)
	definition_text.text = JSON.stringify(checked.definition, "  ") if checked.get("ok", false) else ""
	definition_error.text = "Paste a complete versioned definition; Apply creates a fresh paused world. This is not a saved runtime state."
	definition_dialog.popup_centered(Vector2i(850, 580))
	definition_text.grab_focus()

func context_is_generic() -> bool:
	return host.tower_context.get("micro_active", false)

func _apply_definition() -> void:
	var checked: Dictionary = CyberMicroScenarioContract.parse(definition_text.text)
	if not checked.get("ok", false):
		definition_error.text = str(checked.error)
		return
	if not host.microscenario_apply_definition(checked.definition, mode.get_item_text(mode.selected)):
		definition_error.text = "Rejected; prior world preserved. " + str(host.microscenario_error)
		return
	definition_dialog.hide()
	get_viewport().gui_release_focus()
