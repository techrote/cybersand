class_name CyberWaterExperimentPanel
extends Control

const Contract = preload("res://scripts/water_experiment_contract.gd")
const Profiles = preload("res://scripts/water_experiment_profiles.gd")

signal apply_requested(result: Dictionary)

var profile_input: Variant = {}
var launch_input: Variant = PackedStringArray()
var draft: Dictionary = {}
var mass_bits: SpinBox
var coherence_ticks: SpinBox
var interface_mode: OptionButton
var scenario: OptionButton
var recipe_seed: SpinBox
var effective_text: Label
var status: Label


func _copy_input(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	if value is PackedStringArray:
		return value.duplicate()
	return value


func _button(parent: Node, text: String, action: Callable) -> void:
	var control: Button = Button.new()
	control.text = text
	control.pressed.connect(action)
	parent.add_child(control)


func setup(profile: Variant = {}, launch: Variant = PackedStringArray()) -> void:
	profile_input = _copy_input(profile)
	launch_input = _copy_input(launch)
	if mass_bits == null:
		_build_controls()
	var resolved: Dictionary = Profiles.resolve(
		profile_input, launch_input, {}
	)
	if not resolved.ok:
		status.text = str(resolved.error)
		return
	_load_policy(resolved.policy)
	_show_result(resolved, "Effective policy; no draft is applied yet")
	hide()


func configure_inputs(profile: Variant, launch: Variant) -> bool:
	var resolved: Dictionary = Profiles.resolve(profile, launch, {})
	if not resolved.ok:
		if status != null:
			status.text = str(resolved.error)
		return false
	if mass_bits == null:
		_build_controls()
	profile_input = _copy_input(profile)
	launch_input = _copy_input(launch)
	_load_policy(resolved.policy)
	_show_result(resolved, "Inputs resolved; running policy unchanged")
	return true


func set_draft(values: Dictionary) -> void:
	draft = values.duplicate(true)
	if mass_bits != null:
		var preview: Dictionary = Profiles.resolve(
			profile_input, launch_input, draft
		)
		if preview.ok:
			_load_policy(preview.policy)
			_show_result(preview, "Draft resolved; running policy unchanged")
		else:
			status.text = str(preview.error)


func popup_centered() -> void:
	show()


func submit_draft() -> bool:
	if mass_bits != null:
		draft = _controls_draft()
	var result: Dictionary = Profiles.resolve(
		profile_input, launch_input, draft
	)
	if not result.ok:
		if status != null:
			status.text = str(result.error) + "; running policy unchanged"
		return false
	if status != null:
		_show_result(result, "Validated; owner must Apply + Reset atomically")
	apply_requested.emit(result.duplicate(true))
	return true


func _build_controls() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 110
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.005, 0.01, 0.02, 0.92)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre: CenterContainer = CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = PanelContainer.new()
	centre.add_child(panel)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.048, 0.063, 1.0)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "WATER FEEL LAB / policy version 1 / semantic Apply + Reset"
	box.add_child(title)

	var semantic: GridContainer = GridContainer.new()
	semantic.columns = 2
	box.add_child(semantic)
	_add_label(semantic, "Mass bits (semantic lattice)")
	mass_bits = SpinBox.new()
	mass_bits.min_value = 3
	mass_bits.max_value = 8
	mass_bits.step = 1
	semantic.add_child(mass_bits)
	_add_label(semantic, "Coherence ticks")
	coherence_ticks = SpinBox.new()
	coherence_ticks.min_value = 0
	coherence_ticks.max_value = 12
	coherence_ticks.step = 1
	semantic.add_child(coherence_ticks)

	var references: HBoxContainer = HBoxContainer.new()
	box.add_child(references)
	for name: String in ["current", "three-bit", "short", "none"]:
		_button(references, "%s %d" % [name, Profiles.COHERENCE_NAMES[name]],
			func() -> void:
				coherence_ticks.value = Profiles.COHERENCE_NAMES[name]
		)

	var presentation: GridContainer = GridContainer.new()
	presentation.columns = 2
	box.add_child(presentation)
	_add_label(presentation, "Interface reconstruction")
	interface_mode = OptionButton.new()
	for mode: String in Contract.INTERFACE_MODES:
		interface_mode.add_item(mode)
	presentation.add_child(interface_mode)
	_add_label(presentation, "Scenario")
	scenario = OptionButton.new()
	for id: String in Contract.SCENARIO_IDS:
		scenario.add_item(id)
	presentation.add_child(scenario)
	_add_label(presentation, "Recipe seed")
	recipe_seed = SpinBox.new()
	recipe_seed.min_value = 0
	recipe_seed.max_value = Profiles.MAX_SEED
	recipe_seed.step = 1
	presentation.add_child(recipe_seed)

	var fixed: Label = Label.new()
	fixed.text = "Rest: current-normalized-v1 / render fill levels: 4"
	box.add_child(fixed)
	effective_text = Label.new()
	effective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(effective_text)
	var actions: HBoxContainer = HBoxContainer.new()
	box.add_child(actions)
	_button(actions, "Validate and request Apply + Reset", submit_draft)
	_button(actions, "Cancel / keep running policy", hide)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)


func _add_label(parent: Node, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	parent.add_child(label)


func _controls_draft() -> Dictionary:
	return {
		"mass_bits": int(mass_bits.value),
		"coherence_ticks": int(coherence_ticks.value),
		"interface_mode": interface_mode.get_item_text(interface_mode.selected),
		"scenario_id": scenario.get_item_text(scenario.selected),
		"seed": int(recipe_seed.value),
	}


func _load_policy(policy: Dictionary) -> void:
	draft = {}
	mass_bits.value = int(policy.mass_bits)
	coherence_ticks.value = int(policy.coherence_ticks)
	interface_mode.select(Contract.INTERFACE_MODES.find(policy.interface_mode))
	scenario.select(Contract.SCENARIO_IDS.find(policy.scenario_id))
	recipe_seed.value = int(policy.seed)


func _show_result(result: Dictionary, message: String) -> void:
	var origins: Dictionary = result.provenance.field_origins
	effective_text.text = (
		"SHA-256 %s\nEffective %s\nOrigins %s\nsource %s / mass %d [%s] / coherence %d [%s] / "
		+ "interface %s [%s] / scenario %s [%s] / seed %d [%s]"
	) % [
		str(result.hash), str(result.canonical_json), JSON.stringify(origins),
		str(result.source), int(result.policy.mass_bits),
		str(origins.mass_bits), int(result.policy.coherence_ticks),
		str(origins.coherence_ticks), str(result.policy.interface_mode),
		str(origins.interface_mode), str(result.policy.scenario_id),
		str(origins.scenario_id), int(result.policy.seed), str(origins.seed),
	]
	status.text = message
