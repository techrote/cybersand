extends PopupPanel

# UI composition only. Main owns the existing reconstruction transaction;
# this panel never owns, steps or reads a mutable simulation World.
const Course = preload("res://scripts/player_playground_course.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const LiquidEditor = preload("res://scripts/liquid_comparison_panel.gd")
const CONTROLS: Array[String] = ["keyboard_gamepad", "keyboard"]
const RULES: Array[String] = ["lap", "freeplay"]
const CAMERAS: Array[String] = ["follow", "overview"]

var host: Control
var map_choice: OptionButton
var actor_choice: OptionButton
var control_choice: OptionButton
var rule_choice: OptionButton
var camera_choice: OptionButton
var policy_editor: CyberLiquidComparisonPanel
var build_button: Button
var resume_button: Button
var reset_button: Button
var applied_label: Label
var policy_label: Label
var status_label: Label
var controls_label: Label
var _refresh_elapsed: float = 0.0


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	# Seed a real wrapping width before container minimum-size calculation.
	# A zero-width wrapped Label otherwise requests thousands of pixels high.
	label.size.x = 640
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _choice(parent: Node, title: String, labels: Array[String]) -> OptionButton:
	_label(parent, title)
	var choice := OptionButton.new()
	for label: String in labels: choice.add_item(label)
	parent.add_child(choice)
	return choice


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func setup(controller: Control) -> void:
	host = controller
	# Autowrapped labels have no useful width before their first layout.
	# Keep the popup bounded; only the selection form scrolls.
	wrap_controls = false
	size = Vector2i(680, 740)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var title: Label = _label(layout, "PLAY SESSION")
	title.add_theme_font_size_override("font_size", 24)
	_label(layout, "Choose your course, player and rules, then build. The new session starts paused; release movement controls before resuming.")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	map_choice = _choice(column, "Map", ["Player Playground — authored course"])
	var names: Array[String] = []
	for rig: StringName in Course.MECHANICAL_PRESETS:
		names.append(Course.NAMES[Course.PRESETS.find(rig)] + " / " + str(rig))
	actor_choice = _choice(column, "Player", names)
	actor_choice.select(Course.MECHANICAL_PRESETS.find(&"acrobat"))
	actor_choice.item_selected.connect(func(_index: int) -> void: _refresh_controls())
	control_choice = _choice(column, "Controls", ["Keyboard + standard gamepad", "Keyboard only"])
	control_choice.item_selected.connect(func(_index: int) -> void: _refresh_controls())
	rule_choice = _choice(column, "Rules", ["Four-checkpoint lap", "Free play — no lap timer"])
	camera_choice = _choice(column, "Starting camera", ["Close follow", "Course overview"])
	policy_editor = LiquidEditor.new()
	column.add_child(policy_editor)
	policy_editor.setup(host, true)
	policy_editor.select_preset(0)
	policy_label = _label(column, "")
	controls_label = _label(column, "")
	status_label = _label(layout, "")
	applied_label = _label(layout, "")
	var actions := HFlowContainer.new()
	layout.add_child(actions)
	build_button = _button(actions, "Build selected session", build_selected)
	resume_button = _button(actions, "Play / resume", resume_play)
	reset_button = _button(actions, "Restart applied session", restart_applied)
	_button(actions, "Close", hide)
	_refresh_controls()
	refresh()


func _refresh_controls() -> void:
	if controls_label == null: return
	controls_label.text = Course.controls(Course.MECHANICAL_PRESETS[actor_choice.selected]) + "\nArrows also move."
	if CONTROLS[control_choice.selected] == "keyboard_gamepad":
		controls_label.text += " Gamepad: left stick, A primary, B secondary, X auxiliary, shoulders trim."
	controls_label.text += "\nP pauses · R restarts · F changes camera · F2 returns to the launcher."


func show_selection() -> void:
	host.cancel_playable_course_input()
	if host._playable_course_controls_active():
		actor_choice.select(Course.MECHANICAL_PRESETS.find(host.physical_rig_id))
		control_choice.select(CONTROLS.find(str(host.playable_session_options.controls)))
		rule_choice.select(RULES.find(str(host.playable_session_options.rules)))
		camera_choice.select(CAMERAS.find(str(host.playable_session_options.camera)))
		policy_editor._dirty = false
		policy_editor._sync_applied(host.tower_context)
	_refresh_controls()
	refresh()
	popup_centered(Vector2i(680, 740).min(Vector2i(get_tree().root.size) - Vector2i(32, 32)))


func selection() -> Dictionary:
	return {"map":Catalogue.PLAYER_COURSE_ID,
		"actor":str(Course.MECHANICAL_PRESETS[actor_choice.selected]),
		"controls":CONTROLS[control_choice.selected], "rules":RULES[rule_choice.selected],
		"camera":CAMERAS[camera_choice.selected]}


func build_selected() -> bool:
	var queued: bool = host.apply_playable_session(selection(), policy_editor.requested_policy.duplicate(),
		policy_editor.normalize_water.button_pressed, policy_editor.geometry_picker.get_selected_id())
	if queued:
		policy_editor._waiting_serial = int(host.pending_microscenario_apply.serial)
	refresh()
	return queued


func resume_play() -> void:
	if not host._playable_course_controls_active() or not host.pending_microscenario_apply.is_empty() \
		or host.simulation_worker.has_failed() or not host._physical_terrain_ready:
		return
	host.cancel_playable_course_input()
	hide()
	host.paused = false
	host.update_worker_frame_state()


func restart_applied() -> void:
	if not host._playable_course_controls_active(): return
	host.microscenario_reset()
	refresh()


func _policy_assignment(policy: Dictionary, material: int, applied: bool) -> String:
	for assignment: Dictionary in policy.get("assignments", []):
		if int(assignment.material) == material:
			return "%s / %s" % [str(assignment.get("applied_family" if applied else "requested_family", "unavailable")),
				str(assignment.get("applied_variant", "unavailable"))]
	return "unavailable"


func refresh() -> void:
	if host == null: return
	policy_editor.refresh(host.tower_context)
	var reason: String = host.playable_session_unavailable_reason()
	for choice: OptionButton in [map_choice, actor_choice, control_choice, rule_choice, camera_choice]:
		choice.disabled = not reason.is_empty()
	build_button.disabled = not reason.is_empty() or policy_editor.bridge == null
	var pending: bool = not host.pending_microscenario_apply.is_empty()
	var active: bool = host._playable_course_controls_active()
	resume_button.disabled = not active or pending or host.simulation_worker.has_failed() or not host._physical_terrain_ready
	reset_button.disabled = not active or not reason.is_empty()
	if pending:
		status_label.text = "Building selected session… The previous session remains applied until the rebuild is accepted."
	elif not host.microscenario_error.is_empty():
		status_label.text = "Refused: " + str(host.microscenario_error)
	elif not reason.is_empty():
		status_label.text = reason
	else:
		status_label.text = "Selection changes take effect on Build. Use Play / resume to continue the applied session."
	applied_label.text = "No shared playable course is applied." if not active else \
		"Applied: Player Playground / %s · %s · %s · %s" % [str(host.physical_rig_id),
			"keyboard + gamepad" if host.playable_session_options.controls == "keyboard_gamepad" else "keyboard only",
			"four-checkpoint lap" if host.playable_session_options.rules == "lap" else "free play",
			"paused" if host.paused else "running"]
	var material: int = policy_editor.material_picker.get_selected_id()
	var name: String = policy_editor.material_picker.get_item_text(policy_editor.material_picker.selected) \
		if policy_editor.material_picker.item_count > 0 else "Liquid"
	policy_label.text = "Requested %s: %s\nApplied %s: %s" % [name,
		_policy_assignment(policy_editor._validation.get("receipt", {}), material, false), name,
		_policy_assignment(host.tower_context.get("liquid_solver_policy", {}), material, true)]
	policy_label.tooltip_text = "Applied native policy: " + str(host.tower_context.get("liquid_solver_policy", {}).get("policy_hash", "unavailable")) \
		+ "\nConstruction receipt: " + str(host.tower_context.get("liquid_construction_receipt", {}).get("receipt_hash", "unavailable"))


func _process(delta: float) -> void:
	if not visible: return
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.2:
		_refresh_elapsed = 0.0
		refresh()
