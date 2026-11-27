extends Window
## Optional Native Batch Lab. It owns isolated experiments, never the live canvas.
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Experiments = preload("res://scripts/batch_lab/batch_lab_experiments.gd")
const View = preload("res://scripts/batch_lab/batch_lab_view.gd")
const RenderRig = preload("res://tools/world_art_render_rig.gd")
const PROVIDERS := ["procedural", "random", "direct", "LM Studio", "OpenAI", "NVIDIA"]
const STATES := {
	"idle": Color("9aa9bd"), "queued": Color("a9a0ff"),
	"running": Color("61c9f2"), "completed": Color("8ed3a2"),
	"partial": Color("edc477"), "refused": Color("ee8b89"),
	"stopped": Color("d6a979"),
}

var wb: Node
var controller: Node
var selected := 0
var compare_indices: Array[int] = []
var blind := false
var cards: Array[Dictionary] = []
var rendered: Dictionary = {}
var render_count := 0
var render_elapsed_ms := 0.0
var presentation_refresh_usec := 0
var _render_queue: Array[int] = []
var _rendering := false
var _render_epoch := 0
var _source_epoch := 0
var _source_pending := false
var _last_refresh_ms := 0
var _dirty := true
var _view_stamp := ""
var _comparison_stamp := ""
var _form_config: Dictionary = {}
var _copy_config: Dictionary = {}
var _display_order: Array[int] = []
var _blind_codes: Dictionary = {}
var _render_rig: SubViewport
var _current_file_action := ""
var _pending_confirmation: Callable

var grid := GridContainer.new()
var family := OptionButton.new()
var grid_side := OptionButton.new()
var example_control := OptionButton.new()
var example_seed := SpinBox.new()
var state := Label.new()
var tile_title := Label.new()
var native_hover := Label.new()
var image_label := Label.new()
var details := TextEdit.new()
var result_history := OptionButton.new()
var _history_stamp := ""
var prompt := TextEdit.new()
var direct_json := TextEdit.new()
var variant := OptionButton.new()
var provider := OptionButton.new()
var model := LineEdit.new()
var endpoint := LineEdit.new()
var seed := SpinBox.new()
var width := SpinBox.new()
var height := SpinBox.new()
var budget := SpinBox.new()
var materials := LineEdit.new()
var protection := LineEdit.new()
var region_fields: Array[SpinBox] = []
var tokens := SpinBox.new()
var timeout_seconds := SpinBox.new()
var preview_text := Label.new()
var blind_toggle := CheckBox.new()
var render_toggle := CheckBox.new()
var config_tab := ScrollContainer.new()
var inspect_tab := VBoxContainer.new()
var tabs := TabContainer.new()
var main_view: Control
var compare_row := HBoxContainer.new()
var compare_scroll := ScrollContainer.new()
var compare_views: Array[Control] = []
var _config_controls: Array[Control] = []
var _setup_controls: Array[Control] = []
var _run_buttons: Array[Button] = []
var _stop_button: Button
var _confirm := ConfirmationDialog.new()
var _files := FileDialog.new()
var _key_dialog := ConfirmationDialog.new()
var _key := LineEdit.new()
var _key_provider := ""


func _ready() -> void:
	title = "Native Batch Lab"
	size = Vector2i(1180, 780)
	min_size = Vector2i(840, 580)
	transient = true
	exclusive = false
	close_requested.connect(_close_panel)
	var dense := Theme.new()
	dense.default_font_size = 14
	dense.set_constant("separation", "VBoxContainer", 4)
	dense.set_constant("separation", "HBoxContainer", 5)
	theme = dense
	controller = Controller.new()
	add_child(controller)
	controller.changed.connect(func() -> void: _dirty = true)
	controller.tile_changed.connect(_tile_changed)
	_build_ui()
	apply_example("architecture", 2, 19301, "procedural")


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable, tip := "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _spin(parent: Node, field: SpinBox, minimum: int, maximum: int, value: int, label: String) -> void:
	_label(parent, label)
	field.min_value = minimum
	field.max_value = maximum
	field.step = 1
	field.value = value
	field.custom_minimum_size.x = 74
	parent.add_child(field)


func _text_field(parent: Node, field: LineEdit, label: String, tip := "") -> void:
	_label(parent, label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.tooltip_text = tip
	parent.add_child(field)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 7)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var top := _row(column)
	for value: String in ["Architecture", "Pipework", "Greebles"]: family.add_item(value)
	top.add_child(family)
	grid_side.add_item("2 × 2", 2)
	grid_side.add_item("4 × 4", 4)
	top.add_child(grid_side)
	example_control.add_item("Procedural control", 0)
	example_control.add_item("Seeded-random control", 1)
	top.add_child(example_control)
	_spin(top, example_seed, 0, 2147483647, 19301, "Seed")
	_button(top, "New example", _new_example, "P0–P3 use matched seeds and budgets. Procedural controls do not measure model quality.")
	for child: Node in top.get_children():
		if child is Control: _setup_controls.append(child)
	_run_buttons.append(_button(top, "Run grid", start_grid))
	_stop_button = _button(top, "Stop", stop_grid, "Stop inference, queued tiles and native work at a confirmed chunk boundary.")
	var actions := HFlowContainer.new()
	column.add_child(actions)
	_run_buttons.append(_button(actions, "Run selected", start_selected))
	_run_buttons.append(_button(actions, "Repeat", repeat_selected, "Create another attempt with the selected configuration; retain the previous attempt."))
	_run_buttons.append(_button(actions, "Replay", replay_selected, "Reapply the recorded program and source through the native owner; no model request."))
	_run_buttons.append(_button(actions, "Undo", func() -> void: _outcome(controller.undo(selected)), "Restore this attempt's native source in its isolated World. Ordinary Workbench history is unchanged."))
	_run_buttons.append(_button(actions, "Redo", func() -> void: _outcome(controller.redo(selected)), "Restore this attempt's confirmed material result and verify native readback."))
	_button(actions, "Copy config", copy_configuration)
	_button(actions, "Paste config", paste_configuration)
	_button(actions, "Preview", preview_selected, "Compile without allocating or mutating a native World.")
	_button(actions, "Harvest module", harvest_selected_module, "Convert this completed native material result into a reusable architectural module.")
	_button(actions, "Save…", func() -> void: _open_file("save"))
	_button(actions, "Open…", func() -> void: _open_file("open"))
	_button(actions, "Export…", func() -> void: _open_file("export"))
	_button(actions, "Reset", _request_reset)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.max_lines_visible = 2
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(state)
	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 620
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 400
	body.add_child(left)
	var grid_controls := _row(left)
	blind_toggle.text = "Blind labels"
	blind_toggle.tooltip_text = "Hide prompt, provider and seed while comparing. Native outcomes and failures remain visible."
	blind_toggle.toggled.connect(set_blind)
	grid_controls.add_child(blind_toggle)
	render_toggle.text = "Godot material rendering"
	render_toggle.button_pressed = true
	render_toggle.toggled.connect(func(_on: bool) -> void:
		_view_stamp = ""
		_comparison_stamp = ""
		_dirty = true)
	grid_controls.add_child(render_toggle)
	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(grid_scroll)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(grid)
	var compare_controls := _row(left)
	_label(compare_controls, "Compare checked tiles")
	_button(compare_controls, "Fit all", _fit_comparison)
	_button(compare_controls, "Clear", func() -> void: set_compare([]))
	compare_scroll.custom_minimum_size.y = 180
	compare_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(compare_scroll)
	compare_scroll.add_child(compare_row)
	compare_scroll.hide()
	tabs.custom_minimum_size.x = 360
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	inspect_tab.name = "Inspect"
	tabs.add_child(inspect_tab)
	inspect_tab.add_child(tile_title)
	var history_row := _row(inspect_tab)
	_label(history_row, "Result history")
	result_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_history.fit_to_longest_item = false
	result_history.clip_text = true
	result_history.item_selected.connect(_select_history)
	history_row.add_child(result_history)
	main_view = View.new()
	main_view.custom_minimum_size = Vector2(300, 250)
	main_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_view.cell_hovered.connect(_hover_cell)
	inspect_tab.add_child(main_view)
	var view_controls := _row(inspect_tab)
	_button(view_controls, "Fit", func() -> void: main_view.fit())
	_button(view_controls, "1:1", func() -> void: main_view.native_scale())
	_button(view_controls, "−", func() -> void: main_view.set_framing(main_view.center, main_view.zoom * 0.8))
	_button(view_controls, "+", func() -> void: main_view.set_framing(main_view.center, main_view.zoom * 1.25))
	_label(view_controls, "Wheel: zoom · middle drag: pan")
	image_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	image_label.add_theme_font_size_override("font_size", 12)
	inspect_tab.add_child(image_label)
	inspect_tab.add_child(native_hover)
	details.editable = false
	details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	details.custom_minimum_size.y = 170
	inspect_tab.add_child(details)
	_build_configuration()
	preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_text.max_lines_visible = 3
	column.add_child(preview_text)
	_files.access = FileDialog.ACCESS_FILESYSTEM
	_files.size = Vector2i(780, 520)
	_files.file_selected.connect(_file_selected)
	_files.dir_selected.connect(_file_selected)
	add_child(_files)
	_confirm.confirmed.connect(func() -> void:
		if _pending_confirmation.is_valid(): _pending_confirmation.call())
	add_child(_confirm)
	_key_dialog.title = "Provider credential · memory only"
	_key.secret = true
	_key.placeholder_text = "Optional local token; never saved or exported"
	_key.custom_minimum_size.x = 380
	_key_dialog.add_child(_key)
	_key_dialog.confirmed.connect(func() -> void:
		controller.set_credential(_key_provider, _key.text)
		_key.clear()
		_note("Credential updated for " + _key_provider + ". It remains in this process only."))
	_key_dialog.canceled.connect(func() -> void: _key.clear())
	add_child(_key_dialog)


func _build_configuration() -> void:
	config_tab.name = "Next attempt"
	config_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(config_tab)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_tab.add_child(form)
	var row := _row(form)
	_label(row, "Variant")
	for value: String in ["P0", "P1", "P2", "P3"]: variant.add_item(value)
	variant.item_selected.connect(_choose_variant)
	row.add_child(variant)
	_spin(row, seed, 0, 2147483647, 19301, "Seed")
	row = _row(form)
	_label(row, "Provider")
	for value: String in PROVIDERS: provider.add_item(value)
	provider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(provider)
	_button(row, "Key…", _open_key)
	_text_field(_row(form), model, "Model")
	_text_field(_row(form), endpoint, "Endpoint", "Uses the existing Art provider transport. Cloud calls remain refused without separate spending authority.")
	row = _row(form)
	_spin(row, tokens, 128, 8192, 4096, "Tokens")
	_spin(row, timeout_seconds, 1, 120, 60, "Seconds")
	row = _row(form)
	_spin(row, width, 64, 512, 128, "Width")
	_spin(row, height, 64, 512, 128, "Height")
	_spin(_row(form), budget, 1, 262144, 65536, "Checked-cell budget")
	_text_field(_row(form), materials, "Materials", "Comma-separated supported destination material IDs. Existing protected source-material semantics remain enforced.")
	_text_field(_row(form), protection, "Protect", "JSON rectangles [x,y,width,height], in tile-local coordinates; example [[0,0,8,128]].")
	_label(form, "Workbench source region · x / y / width / height")
	row = _row(form)
	for value: int in [0, 0, 128, 128]:
		var field := SpinBox.new()
		field.min_value = 0
		field.max_value = 8192
		field.step = 1
		field.value = value
		field.custom_minimum_size.x = 76
		row.add_child(field)
		region_fields.append(field)
	_button(form, "Capture Workbench source", capture_source, "Copy a native-confirmed source region. Batch attempts never write back to the ordinary Workbench.")
	_label(form, "Prompt · editable for this tile")
	prompt.custom_minimum_size.y = 130
	prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	form.add_child(prompt)
	_label(form, "Program · native Art JSON (Direct / procedural replay)")
	_button(form, "Rebuild example from seed / size", _regenerate_example,
		"Replace the next attempt's program and initial source with this family's example at the chosen seed and size. Existing results remain immutable.")
	direct_json.custom_minimum_size.y = 130
	direct_json.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	form.add_child(direct_json)
	_button(form, "Apply configuration", _commit_selected)
	for node: Control in [variant, provider, model, endpoint, seed, width, height, budget, materials, protection, tokens, timeout_seconds, prompt, direct_json]:
		_config_controls.append(node)
	_config_controls.append_array(region_fields)


func _selected_tile() -> Dictionary:
	if controller == null or selected < 0 or selected >= controller.tiles.size(): return {}
	return controller.tiles[selected]


func _result_config(tile: Dictionary) -> Dictionary:
	return tile.get("_frozen_config", tile.config) if not str(tile.get("attempt_id", "")).is_empty() else tile.config


func _active() -> bool:
	if controller == null: return false
	for tile: Dictionary in controller.tiles:
		if str(tile.get("state", "")) in ["queued", "running"]: return true
	return false


func _note(value: String) -> void:
	preview_text.text = value
	preview_text.tooltip_text = value


func _outcome(value: Dictionary) -> bool:
	var ok := bool(value.get("ok", false))
	_note(str(value.get("reason", "Accepted." if ok else "Request refused.")))
	_dirty = true
	return ok


func apply_example(value_family: String, side: int, host_seed: int, control := "procedural") -> Dictionary:
	var configs: Array = Experiments.make_grid(value_family.to_lower(), side, host_seed, control)
	if configs.is_empty(): return {"ok":false, "reason":"Choose a registered family and 2×2 or 4×4 layout."}
	for config: Dictionary in configs:
		if config.has("error"): return {"ok":false, "reason":str(config.error)}
	var configured: Dictionary = controller.configure_grid(side, side)
	if not bool(configured.get("ok", false)): return configured
	for index: int in configs.size():
		var outcome: Dictionary = controller.configure_tile(index, configs[index])
		if not bool(outcome.get("ok", false)): return outcome
	selected = 0
	for index: int in family.item_count:
		if family.get_item_text(index).to_lower() == value_family.to_lower(): family.select(index)
	grid_side.select(grid_side.get_item_index(side))
	example_seed.value = host_seed
	example_control.select(1 if control == "seeded_random" else 0)
	_grid_replaced()
	_dirty = true
	return {"ok":true, "reason":"%d independent %s attempts configured. No model inference has run." % [configs.size(), value_family]}


func _new_example() -> void:
	var action := func() -> void:
		_outcome(apply_example(family.get_item_text(family.selected).to_lower(),
			grid_side.get_selected_id(), int(example_seed.value),
			"procedural" if example_control.selected == 0 else "seeded_random"))
	if _has_results(): _ask("Start a new example? Save valuable results first. Existing attempts in this grid will be replaced.", action)
	else: action.call()


func _has_results() -> bool:
	for tile: Dictionary in controller.tiles:
		if not tile.get("attempts", []).is_empty() or not str(tile.get("attempt_id", "")).is_empty(): return true
	return false


func _ask(message: String, action: Callable) -> void:
	if _active():
		_note("Stop or wait for the current grid before replacing it.")
		return
	_pending_confirmation = action
	_confirm.dialog_text = message
	_confirm.popup_centered(Vector2i(430, 160))


func _request_reset() -> void:
	_ask("Reset this grid? Save valuable attempts first. Ordinary Workbench state is unaffected.", func() -> void:
		if _outcome(controller.reset()):
			_grid_replaced())


func _grid_replaced() -> void:
	# A successful session/grid replacement retires all prior asynchronous UI
	# work, even when the new grid has the same number of tiles or attempts.
	_source_epoch += 1
	_source_pending = false
	_render_epoch += 1
	_render_queue.clear()
	rendered.clear()
	compare_indices.clear()
	_history_stamp = ""
	_view_stamp = ""
	_comparison_stamp = ""
	selected = 0
	set_blind(blind)
	_load_form()
	_dirty = true


func select_tile(index: int) -> void:
	if index < 0 or index >= controller.tiles.size(): return
	_source_epoch += 1
	_source_pending = false
	selected = index
	_load_form()
	_view_stamp = ""
	_dirty = true


func _load_form() -> void:
	var tile := _selected_tile()
	if tile.is_empty(): return
	_form_config = tile.config.duplicate(true)
	var config := _form_config
	variant.select(clampi(int(str(config.get("variant", "P0")).trim_prefix("P")), 0, 3))
	provider.select(maxi(0, PROVIDERS.find(str(config.get("provider", "procedural")))))
	model.text = str(config.get("model", "deterministic-v1"))
	endpoint.text = str(config.get("endpoint", "http://127.0.0.1:1234/v1"))
	seed.value = int(config.get("seed", 19301))
	var extent: Array = config.get("extent", [128, 128])
	width.value = int(extent[0])
	height.value = int(extent[1])
	budget.value = int(config.get("budget_cells", 65536))
	tokens.value = int(config.get("max_output_tokens", 4096))
	timeout_seconds.value = float(config.get("timeout_seconds", 60))
	var names := PackedStringArray()
	for material: Variant in config.get("materials", [0, 58]): names.append(str(int(material)))
	materials.text = ",".join(names)
	protection.text = JSON.stringify(config.get("protection", []))
	var source: Array = config.get("source_region", [0, 0, extent[0], extent[1]])
	for i: int in 4: region_fields[i].value = int(source[i])
	prompt.text = str(config.get("prompt", ""))
	direct_json.text = JSON.stringify(config.get("operations", []), "  ")


func _commit_selected() -> bool:
	if blind:
		_note("Unblind before changing attempt configuration.")
		return false
	var tile := _selected_tile()
	if tile.is_empty(): return false
	var ids: Array = []
	for value: String in materials.text.split(",", false):
		if not value.strip_edges().is_valid_int():
			_note("Materials must be integer IDs separated by commas.")
			return false
		ids.append(value.strip_edges().to_int())
	var guards: Variant = JSON.parse_string(protection.text)
	var operations: Variant = JSON.parse_string(direct_json.text)
	if not guards is Array or not operations is Array:
		_note("Protection and program must each be a JSON array; no configuration changed.")
		return false
	var config := _form_config.duplicate(true)
	config.merge({"variant":variant.get_item_text(variant.selected),
		"provider":PROVIDERS[provider.selected], "model":model.text.strip_edges(),
		"endpoint":endpoint.text.strip_edges(), "seed":int(seed.value),
		"extent":[int(width.value), int(height.value)], "budget_cells":int(budget.value),
		"max_output_tokens":int(tokens.value), "timeout_seconds":float(timeout_seconds.value),
		"materials":ids, "protection":guards, "prompt":prompt.text,
		"operations":operations, "source_region":[int(region_fields[0].value),
		int(region_fields[1].value), int(region_fields[2].value), int(region_fields[3].value)]}, true)
	if prompt.text != str(_form_config.get("prompt", "")):
		config.prompt_version = "custom:" + prompt.text.sha256_text()
		config.prompt_origin = "custom"
		config.parent_prompt_sha256 = str(_form_config.get("prompt_sha256", ""))
		config.parent_prompt_template_sha256 = str(_form_config.get("prompt_template_sha256", ""))
		config.prompt_template_sha256 = ""
		config.reference_delivery = "custom-unverified"
	config.prompt_sha256 = prompt.text.sha256_text()
	var outcome: Dictionary = controller.configure_tile(selected, config)
	if _outcome(outcome):
		_source_epoch += 1
		_source_pending = false
		_form_config = config
		return true
	return false


func _choose_variant(index: int) -> void:
	if _form_config.is_empty(): return
	var choice: Dictionary = Experiments.make_attempt(str(_form_config.get("family", "architecture")),
		"P" + str(index), int(seed.value), int(width.value), int(height.value),
		str(_form_config.get("control", "procedural")))
	if choice.has("error"):
		_note(str(choice.error))
		_load_form()
		return
	for key: String in ["prompt", "prompt_version", "prompt_sha256", "prompt_template_sha256",
		"reference_card_id", "reference_delivery", "tool_contract", "experiment_manifest_sha256",
		"reference_manifest_sha256", "variant", "group_id", "cohort", "metrics_targets"]:
		if choice.has(key): _form_config[key] = choice[key]
	_form_config.prompt_origin = "versioned-development-template"
	_form_config.erase("parent_prompt_sha256")
	_form_config.erase("parent_prompt_template_sha256")
	prompt.text = str(choice.get("prompt", ""))


func _regenerate_example() -> void:
	if blind or not _commit_selected(): return
	var next: Dictionary = Experiments.make_attempt(str(_form_config.get("family", "architecture")),
		variant.get_item_text(variant.selected), int(seed.value), int(width.value), int(height.value),
		str(_form_config.get("control", "procedural")))
	if next.has("error"):
		_note(str(next.error))
		return
	for key: String in ["provider", "model", "endpoint", "max_output_tokens", "timeout_seconds"]:
		if _form_config.has(key): next[key] = _form_config[key]
	if _outcome(controller.configure_tile(selected, next)):
		_load_form()
		_note("Next program and source rebuilt from seed / size. Previous native results are unchanged.")


func start_grid() -> void:
	if not blind and not _commit_selected(): return
	_outcome(controller.start())


func start_selected() -> void:
	if not _commit_selected(): return
	_outcome(controller.start([selected]))


func stop_grid() -> void:
	_source_epoch += 1
	_source_pending = false
	_render_epoch += 1
	_render_queue.clear()
	controller.stop()
	_note("Stop requested. An executing native chunk may finish; only its confirmed prefix is retained.")
	_dirty = true


func repeat_selected() -> void:
	if not _commit_selected(): return
	_outcome(controller.repeat(selected))


func replay_selected() -> void:
	_outcome(controller.replay(selected))


func preview_selected() -> void:
	if not _commit_selected(): return
	var result: Dictionary = controller.compile_preview(selected)
	_note("Zero-write compilation preview: " + JSON.stringify(result))


func copy_configuration() -> void:
	if blind: return
	if _commit_selected():
		_copy_config = _selected_tile().config.duplicate(true)
		_note("Configuration copied. Select another tile and Paste config.")


func paste_configuration() -> void:
	if blind or _copy_config.is_empty(): return
	if _outcome(controller.configure_tile(selected, _copy_config.duplicate(true))):
		_source_epoch += 1
		_source_pending = false
		_load_form()


func _form_values() -> Array:
	var values: Array = [variant.selected, provider.selected, model.text, endpoint.text,
		seed.value, width.value, height.value, budget.value, tokens.value, timeout_seconds.value,
		materials.text, protection.text, prompt.text, direct_json.text]
	for field: SpinBox in region_fields: values.append(field.value)
	return values


func capture_source() -> void:
	if blind or not _commit_selected(): return
	if wb == null or not wb.has_method("capture_batch_source"):
		_note("Source capture is available when Batch Lab is opened from Shared Workbench.")
		return
	var index := selected
	_source_epoch += 1
	var epoch := _source_epoch
	_source_pending = true
	_dirty = true
	var form_before := _form_values()
	var config := _form_config.duplicate(true)
	var region := Rect2i(int(region_fields[0].value), int(region_fields[1].value),
		int(region_fields[2].value), int(region_fields[3].value))
	_note("Capturing authoritative Workbench source…")
	var result: Dictionary = await wb.capture_batch_source(region)
	if epoch == _source_epoch:
		_source_pending = false
		_dirty = true
	if epoch != _source_epoch or index != selected or form_before != _form_values():
		_note("Source capture retired after Stop, grid, selection or configuration change; no tile changed.")
		return
	if not bool(result.get("ok", false)):
		_outcome(result)
		return
	config.merge(result.get("config", {}), true)
	if _outcome(controller.configure_tile(index, config)):
		_load_form()
		_note("Native source captured for this tile. The ordinary Workbench remains unchanged.")


func harvest_selected_module() -> void:
	if blind:
		_note("Leave blinded comparison before harvesting a named native module.")
		return
	if not is_instance_valid(wb):
		_note("Open the Native Batch Lab from an installed Workbench to harvest reusable modules.")
		return
	wb.open_architecture_lab()
	_outcome(wb.architecture_lab.harvest_tile(_selected_tile()))


func _open_key() -> void:
	_key_provider = PROVIDERS[provider.selected]
	_key.clear()
	_key_dialog.popup_centered(Vector2i(430, 130))


func set_blind(enabled: bool) -> void:
	blind = enabled
	for control: Control in _setup_controls: control.visible = not enabled
	_display_order.clear()
	_blind_codes.clear()
	for index: int in controller.tiles.size(): _display_order.append(index)
	if enabled:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for offset: int in range(_display_order.size() - 1, 0, -1):
			var other := rng.randi_range(0, offset)
			var previous := _display_order[offset]
			_display_order[offset] = _display_order[other]
			_display_order[other] = previous
		for position: int in _display_order.size(): _blind_codes[_display_order[position]] = String.chr(65 + position)
	blind_toggle.set_pressed_no_signal(enabled)
	tabs.set_tab_hidden(1, enabled)
	if enabled:
		tabs.current_tab = 0
		_note("Blind comparison: prompt, provider and seed are hidden. Include failed and stopped attempts in your judgement.")
	_view_stamp = ""
	_comparison_stamp = ""
	_rebuild_grid()
	_dirty = true


func set_compare(indices: Array) -> void:
	compare_indices.clear()
	for value: Variant in indices:
		var index := int(value)
		if index >= 0 and index < controller.tiles.size() and not compare_indices.has(index):
			compare_indices.append(index)
	_comparison_stamp = ""
	_dirty = true


func _compare_toggle(enabled: bool, index: int) -> void:
	if enabled and not compare_indices.has(index): compare_indices.append(index)
	elif not enabled: compare_indices.erase(index)
	_comparison_stamp = ""
	_dirty = true


func _tile_name(index: int) -> String:
	return "Attempt " + str(_blind_codes.get(index, "?")) if blind else "Tile %02d" % [index + 1]


func _rebuild_grid() -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	cards.clear()
	cards.resize(controller.tiles.size())
	grid.columns = int(controller.columns)
	if _display_order.size() != controller.tiles.size():
		_display_order.clear()
		for index: int in controller.tiles.size(): _display_order.append(index)
	for index: int in _display_order:
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 126
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var header := _row(card)
		var button := Button.new()
		button.custom_minimum_size.y = 26
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 12)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_tile.bind(index))
		header.add_child(button)
		var check := CheckBox.new()
		check.tooltip_text = "Include this attempt in side-by-side comparison"
		check.toggled.connect(_compare_toggle.bind(index))
		header.add_child(check)
		var image := TextureRect.new()
		image.custom_minimum_size = Vector2(110, 48 if int(controller.columns) == 4 else 96)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.mouse_filter = Control.MOUSE_FILTER_STOP
		image.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				select_tile(index))
		card.add_child(image)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 12)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.max_lines_visible = 3
		card.add_child(label)
		cards[index] = {"button":button, "image":image, "label":label, "check":check}
	_comparison_stamp = ""


func _extent(tile: Dictionary) -> Vector2i:
	var value: Array = tile.get("result_extent", tile.config.get("extent", [128, 128]))
	if value.size() != 2: value = tile.config.get("extent", [128, 128])
	return Vector2i(int(value[0]), int(value[1])).max(Vector2i.ONE)


func _texture(index: int) -> Texture2D:
	var tile: Dictionary = controller.tiles[index]
	var cached: Dictionary = rendered.get(index, {})
	var previous_image: Image = tile.get("render_image")
	if not cached.has("texture") and previous_image != null and not previous_image.is_empty():
		cached.texture = ImageTexture.create_from_image(previous_image)
		cached.attempt_id = str(tile.get("attempt_id", ""))
		cached.identity = tile.provenance.get("renderer", {})
		rendered[index] = cached
	if render_toggle.button_pressed and str(cached.get("attempt_id", "")) == str(tile.get("attempt_id", "")):
		if cached.has("texture"): return cached.texture
	var image: Image = tile.get("image")
	if image == null or image.is_empty(): return null
	var key := str(tile.get("attempt_id", "")) + ":" + str(tile.get("material_sha256", ""))
	if str(cached.get("id_key", "")) != key:
		cached.id_texture = ImageTexture.create_from_image(image)
		cached.id_key = key
		rendered[index] = cached
	return cached.get("id_texture")


func _render_label(index: int) -> String:
	var tile: Dictionary = controller.tiles[index]
	var cached: Dictionary = rendered.get(index, {})
	if render_toggle.button_pressed and cached.has("texture") and str(cached.get("attempt_id", "")) == str(tile.get("attempt_id", "")):
		return "Godot-rendered native material plane · condition channel 0 · static presentation"
	return "Native material-ID capture · diagnostic colours · not a Godot framebuffer"


func _tile_changed(index: int) -> void:
	_dirty = true
	if index >= 0 and index < controller.tiles.size():
		var tile: Dictionary = controller.tiles[index]
		if not tile.get("material_cells", PackedByteArray()).is_empty() and not _render_queue.has(index):
			_render_queue.append(index)


func refresh() -> void:
	var refresh_started := Time.get_ticks_usec()
	if cards.size() != controller.tiles.size(): _rebuild_grid()
	var counts := {}
	for index: int in controller.tiles.size():
		var tile: Dictionary = controller.tiles[index]
		var status := str(tile.get("state", "idle"))
		counts[status] = int(counts.get(status, 0)) + 1
		var config: Dictionary = _result_config(tile)
		var metrics: Dictionary = tile.get("metrics", {})
		cards[index].button.text = (str(_blind_codes.get(index, "?")) if blind else "%02d" % [index + 1]) + " · " + status
		cards[index].button.modulate = Color(1.0, 1.0, 1.0) if index == selected else Color(0.86, 0.86, 0.86)
		cards[index].button.tooltip_text = cards[index].button.text
		cards[index].button.add_theme_color_override("font_color", STATES.get(status, Color.WHITE))
		cards[index].image.texture = _texture(index)
		cards[index].image.tooltip_text = _render_label(index)
		var changed := int(metrics.get("changed", metrics.get("changed_cells", 0)))
		cards[index].label.text = "%d changed cells" % changed if blind else "%s · seed %s\n%s\n%d changed cells" % [config.get("variant", "P0"), config.get("seed", 0), config.get("model", config.get("provider", "")), changed]
		cards[index].label.tooltip_text = "" if blind else str(tile.get("reason", ""))
		cards[index].check.set_pressed_no_signal(compare_indices.has(index))
	var parts := PackedStringArray()
	for status: String in ["idle", "queued", "running", "completed", "partial", "refused", "stopped"]:
		if counts.has(status): parts.append("%d %s" % [counts[status], status])
	state.text = "%d native attempts · %s · up to %d isolated workers" % [controller.tiles.size(), " · ".join(parts), int(controller.max_parallel)]
	state.tooltip_text = state.text
	_stop_button.disabled = not _active() and not _rendering and not _source_pending
	for button: Button in _run_buttons: button.disabled = _active()
	_update_inspector()
	_update_comparison()
	_dirty = false
	presentation_refresh_usec += Time.get_ticks_usec() - refresh_started


func _update_inspector() -> void:
	var tile := _selected_tile()
	if tile.is_empty(): return
	tile_title.text = _tile_name(selected) + " · " + str(tile.get("state", "idle"))
	_update_history()
	var stamp := "%d/%s/%s/%s/%s" % [selected, tile.get("attempt_id", ""), tile.get("state", "idle"), render_toggle.button_pressed, blind]
	stamp += "/" + str(rendered.get(selected, {}).get("attempt_id", ""))
	if stamp == _view_stamp: return
	_view_stamp = stamp
	main_view.set_result(_texture(selected), _extent(tile), tile.get("material_cells", PackedByteArray()), "No confirmed native result")
	main_view.fit()
	image_label.text = _render_label(selected)
	var report := {"state":tile.get("state"), "metrics":tile.get("metrics", {}),
		"confirmed_receipts":tile.get("receipts", []).size(), "retained_attempts":tile.get("attempts", []).size()}
	if not blind:
		report.timings_ms = tile.get("timings", {})
		report.usage = tile.get("usage", {})
		report.reason = tile.get("reason", "")
		report.provenance = tile.get("provenance", {})
		report.material_sha256 = tile.get("material_sha256", "")
		var evidence_config := _result_config(tile)
		# Full original records remain in exports. Avoid copying large programs or
		# source planes into the live text inspector on every native receipt.
		report.config = {}
		for key: String in evidence_config:
			if key not in ["source_cells", "operations", "source_rectangles"]: report.config[key] = evidence_config[key]
		var receipts: Array = tile.get("receipts", [])
		report.latest_receipts = []
		for receipt: Variant in receipts.slice(maxi(0, receipts.size() - 3)):
			if not receipt is Dictionary: continue
			var summary := {}
			for key: String in ["status", "checked", "changed", "unchanged", "excluded", "refused", "confirmed", "epoch", "generation", "revision", "tick", "reason"]:
				if receipt.has(key): summary[key] = receipt[key]
			report.latest_receipts.append(summary)
	details.text = JSON.stringify(report, "  ").left(32768)


func _update_history() -> void:
	result_history.visible = not blind
	if blind: return
	var stamp := str(controller.attempts.size())
	if stamp != _history_stamp:
		_history_stamp = stamp
		result_history.clear()
		for record: Dictionary in controller.attempts:
			var config: Dictionary = record.config
			result_history.add_item("%s · %s · %s · %s" % [record.attempt_id,
				config.get("family", "attempt"), config.get("variant", ""), record.state])
			result_history.set_item_metadata(result_history.item_count - 1, str(record.attempt_id))
	for index: int in result_history.item_count:
		if str(result_history.get_item_metadata(index)) == str(_selected_tile().get("attempt_id", "")):
			result_history.select(index)
			break


func _select_history(item: int) -> void:
	if blind or item < 0 or item >= result_history.item_count: return
	if _outcome(controller.select_attempt(selected, str(result_history.get_item_metadata(item)))):
		rendered.erase(selected)
		_view_stamp = ""
		_comparison_stamp = ""
		_dirty = true


func _update_comparison() -> void:
	for position: int in range(compare_indices.size() - 1, -1, -1):
		if compare_indices[position] < 0 or compare_indices[position] >= controller.tiles.size():
			compare_indices.remove_at(position)
	var stamp := str(compare_indices) + str(blind) + str(render_toggle.button_pressed)
	for index: int in compare_indices:
		stamp += str(controller.tiles[index].get("attempt_id", "")) + str(rendered.get(index, {}).get("attempt_id", ""))
	if stamp == _comparison_stamp: return
	_comparison_stamp = stamp
	for child: Node in compare_row.get_children():
		compare_row.remove_child(child)
		child.queue_free()
	compare_views.clear()
	compare_scroll.visible = not compare_indices.is_empty()
	var common := Vector2i.ONE
	for index: int in compare_indices: common = common.max(_extent(controller.tiles[index]))
	for index: int in compare_indices:
		var box := VBoxContainer.new()
		box.custom_minimum_size.x = 180
		compare_row.add_child(box)
		_label(box, _tile_name(index) + " · " + str(controller.tiles[index].get("state", "idle")))
		var view := View.new()
		view.custom_minimum_size = Vector2(180, 140)
		box.add_child(view)
		view.set_result(_texture(index), _extent(controller.tiles[index]), controller.tiles[index].get("material_cells", PackedByteArray()), "No confirmed result", common)
		view.framing_changed.connect(_sync_comparison)
		compare_views.append(view)
	_fit_comparison()


func _fit_comparison() -> void:
	if compare_views.is_empty(): return
	_sync_comparison(Vector2(compare_views[0].reference_extent) * 0.5, 1.0)


func _sync_comparison(center: Vector2, zoom: float) -> void:
	for view: Control in compare_views: view.set_framing(center, zoom)


func _hover_cell(point: Vector2i, material: int) -> void:
	native_hover.text = "Cell (%d, %d) · native material %d" % [point.x, point.y, material] if material >= 0 else "Outside confirmed native plane"


func _process(_delta: float) -> void:
	if _dirty and Time.get_ticks_msec() >= _last_refresh_ms + 100:
		_last_refresh_ms = Time.get_ticks_msec()
		refresh()
	if visible and render_toggle.button_pressed and not _rendering and not _render_queue.is_empty() and DisplayServer.get_name() != "headless":
		_render_one(_render_queue.pop_front())


func _render_one(index: int) -> void:
	if index < 0 or index >= controller.tiles.size(): return
	var tile: Dictionary = controller.tiles[index]
	var attempt_id := str(tile.get("attempt_id", ""))
	var cached: Dictionary = rendered.get(index, {})
	if cached.has("texture") and str(cached.get("attempt_id", "")) == attempt_id: return
	var previous_image: Image = tile.get("render_image")
	if previous_image != null and not previous_image.is_empty():
		_texture(index)
		return
	var cells: PackedByteArray = tile.get("material_cells", PackedByteArray())
	var extent := _extent(tile)
	if cells.size() != extent.x * extent.y * 2: return
	_rendering = true
	var render_started := Time.get_ticks_usec()
	var epoch := _render_epoch
	var pixels := PackedByteArray()
	pixels.resize(cells.size())
	for offset: int in range(0, cells.size(), 2):
		var id := int(cells.decode_u16(offset))
		if id > 255:
			_rendering = false
			_note("Godot rendering refused an unsupported material ID; native result retained.")
			return
		pixels[offset] = id
		pixels[offset + 1] = 0
	var image := Image.create_from_data(extent.x, extent.y, false, Image.FORMAT_RG8, pixels)
	if not is_instance_valid(_render_rig):
		_render_rig = RenderRig.new()
		add_child(_render_rig)
		_render_rig.setup(image, extent)
	else:
		_render_rig.replace_input(image)
		_render_rig.set_resolution(extent)
	_render_rig.set_view(Vector2.ZERO, Vector2(extent))
	_render_rig.set_presentation(1.37, false, true)
	_render_rig.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(_render_rig):
		_rendering = false
		return
	_render_rig.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if epoch != _render_epoch or index >= controller.tiles.size() or str(controller.tiles[index].get("attempt_id", "")) != attempt_id:
		_rendering = false
		return
	var result := _render_rig.get_texture().get_image()
	if result != null and not result.is_empty():
		var identity: Dictionary = _render_rig.renderer_identity()
		identity.kind = "godot-rendered-native-material-plane"
		identity.condition_channel = 0
		identity.presentation_time = 1.37
		identity.glow = false
		identity.material_sha256 = tile.get("material_sha256", "")
		identity.capture_ms = float(Time.get_ticks_usec() - render_started) / 1000.0
		var accepted: Dictionary = controller.record_render(index, attempt_id, result, identity)
		if bool(accepted.get("ok", false)):
			render_count += 1
			render_elapsed_ms += float(identity.capture_ms)
			cached.texture = ImageTexture.create_from_image(result)
			cached.attempt_id = attempt_id
			cached.identity = identity
			rendered[index] = cached
	_rendering = false
	_dirty = true


func _open_file(action: String) -> void:
	_current_file_action = action
	_files.clear_filters()
	_files.current_dir = ProjectSettings.globalize_path("user://")
	if action == "export":
		_files.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_files.title = "Choose parent folder for a new Batch Lab export"
	else:
		_files.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action == "open" else FileDialog.FILE_MODE_SAVE_FILE
		_files.title = "Open Batch Lab session" if action == "open" else "Save Batch Lab session"
		_files.add_filter("*.json", "Batch Lab session")
		_files.current_file = "batch-lab-session.json"
	_files.popup_centered_clamped(Vector2i(780, 520), 0.9)


func _file_selected(path: String) -> void:
	match _current_file_action:
		"save": _outcome(controller.save_session(path))
		"open":
			if _outcome(controller.load_session(path)):
				_grid_replaced()
				for index: int in controller.tiles.size(): _tile_changed(index)
		"export":
			var destination := path.path_join("batch-lab-" + str(Time.get_unix_time_from_system()).replace(".", "-"))
			_outcome(export_grid(destination))


func export_grid(destination: String) -> Dictionary:
	if _active(): return {"ok":false, "reason":"Stop or wait before exporting a settled grid."}
	if DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination):
		return {"ok":false, "reason":"Export destination already exists; choose a new folder."}
	var error := DirAccess.make_dir_recursive_absolute(destination)
	if error != OK: return {"ok":false, "reason":"Cannot create export folder: " + error_string(error)}
	var summary: Array = []
	for index: int in controller.tiles.size():
		var tile: Dictionary = controller.tiles[index]
		if str(tile.get("attempt_id", "")).is_empty():
			# A partial grid is useful too. Unexecuted configurations remain in
			# session.json; do not invent an attempt or drop the settled neighbours.
			summary.append({"tile":index, "state":"idle", "executed":false})
			continue
		var prefix := destination.path_join("attempt-%02d" % [index + 1])
		var result: Dictionary = controller.export_result(index, prefix + ".json")
		summary.append({"tile":index, "outcome":result})
		if not bool(result.get("ok", false)):
			return {"ok":false, "reason":"Export incomplete; retained earlier results at %s. Tile %d: %s" % [destination, index + 1, result.get("reason", "refused")]}
		var diagnostic: Image = tile.get("image")
		if diagnostic != null and not diagnostic.is_empty():
			if diagnostic.save_png(prefix + "-native-material-ids.png") != OK:
				return {"ok":false, "reason":"Cannot write native material-ID PNG; partial export retained at " + destination}
		var cached: Dictionary = rendered.get(index, {})
		if cached.has("texture") and str(cached.get("attempt_id", "")) == str(tile.get("attempt_id", "")):
			if cached.texture.get_image().save_png(prefix + "-godot-material-plane.png") != OK:
				return {"ok":false, "reason":"Cannot write Godot material-plane PNG; partial export retained at " + destination}
	var saved: Dictionary = controller.save_session(destination.path_join("session.json"))
	if not bool(saved.get("ok", false)): return saved
	return {"ok":true, "reason":"Exported all attempts, including unsuccessful results, to " + destination, "results":summary}


func _close_panel() -> void:
	stop_grid()
	hide()


func _exit_tree() -> void:
	_render_epoch += 1
	_source_epoch += 1
	if is_instance_valid(controller): controller.stop()
