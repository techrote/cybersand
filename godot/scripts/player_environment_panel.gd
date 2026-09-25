extends PanelContainer

signal apply_requested(profile: Dictionary)

const FIELD_SPECS: Array[Dictionary] = [
	{"key":"effective_mass", "label":"Mass", "min":0.05, "max":20.0, "step":0.05},
	{"key":"gravity_acceleration", "label":"Gravity", "min":0.0, "max":2000.0, "step":1.0},
	{"key":"terminal_fall_speed", "label":"Terminal", "min":1.0, "max":2000.0, "step":1.0},
	{"key":"jetpack_acceleration", "label":"Jet accel", "min":0.0, "max":4000.0, "step":5.0},
	{"key":"jetpack_max_rise_speed", "label":"Jet rise", "min":0.0, "max":2000.0, "step":1.0},
	{"key":"granular_response_sensitivity", "label":"Granular sens", "min":0.0, "max":8.0, "step":0.05},
	{"key":"liquid_response_sensitivity", "label":"Liquid sens*", "min":0.0, "max":8.0, "step":0.05},
	{"key":"step_height", "label":"Step px", "min":0.0, "max":32.0, "step":1.0},
	{"key":"knee_height", "label":"Knee px", "min":0.0, "max":32.0, "step":1.0},
	{"key":"clamber_height", "label":"Clamber px", "min":0.0, "max":32.0, "step":1.0},
	{"key":"knee_slowdown", "label":"Knee speed", "min":0.05, "max":1.0, "step":0.05},
	{"key":"clamber_slowdown", "label":"Clamber speed", "min":0.05, "max":1.0, "step":0.05},
]

var _profiles
var _preset_selector: OptionButton
var _fields: Dictionary = {}
var _active_label: Label
var _status_label: Label
var _loading: bool = false


func configure(profile_source, active_profile: Dictionary) -> void:
	_profiles = profile_source
	if get_child_count() == 0:
		_build()
	_load_profile(active_profile, _preset_index_for(active_profile))
	set_active(active_profile)


func set_active(profile: Dictionary) -> void:
	if _active_label == null:
		return
	var id: String = str(profile.get("id", "unknown"))
	var hash: String = str(profile.get("hash", ""))
	_active_label.text = (
		"Active: %s  G %.1f  terminal %.1f  mass %.2f  step/knee/clamber %d/%d/%d  [%s]"
		% [
			id,
			float(profile.get("gravity_acceleration", 0.0)),
			float(profile.get("terminal_fall_speed", 0.0)),
			float(profile.get("effective_mass", 0.0)),
			int(profile.get("step_height", 0)),
			int(profile.get("knee_height", 0)),
			int(profile.get("clamber_height", 0)),
			hash.left(10),
		]
	)


func set_error(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _build() -> void:
	name = "PlayerEnvironmentTuning"
	custom_minimum_size = Vector2(610.0, 0.0)
	var root := VBoxContainer.new()
	add_child(root)

	var title := Label.new()
	title.text = "Player / environment tuning (PENV-001)"
	root.add_child(title)

	var preset_row := HBoxContainer.new()
	root.add_child(preset_row)
	var preset_label := Label.new()
	preset_label.text = "Preset"
	preset_row.add_child(preset_label)
	_preset_selector = OptionButton.new()
	for preset_name: String in _profiles.preset_names():
		_preset_selector.add_item(preset_name)
	_preset_selector.item_selected.connect(_on_preset_selected)
	preset_row.add_child(_preset_selector)

	var apply_button := Button.new()
	apply_button.text = "Apply + fresh reset"
	apply_button.focus_mode = Control.FOCUS_NONE
	apply_button.pressed.connect(_on_apply)
	preset_row.add_child(apply_button)

	_active_label = Label.new()
	_active_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_active_label)

	var grid := GridContainer.new()
	grid.columns = 4
	root.add_child(grid)
	for spec: Dictionary in FIELD_SPECS:
		var label := Label.new()
		label.text = str(spec.label)
		grid.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = float(spec.min)
		spin.max_value = float(spec.max)
		spin.step = float(spec.step)
		spin.allow_greater = false
		spin.allow_lesser = false
		spin.custom_minimum_size = Vector2(105.0, 0.0)
		spin.value_changed.connect(_on_field_changed)
		grid.add_child(spin)
		_fields[str(spec.key)] = spin

	var note := Label.new()
	note.text = "* Liquid sensitivity is exposed and captured only; PENV-001 adds no Water displacement/pressure semantics."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(note)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)


func _preset_index_for(profile: Dictionary) -> int:
	var id: String = str(profile.get("id", ""))
	if id == "current-baseline":
		return 0
	if id == "earth-feel-2x-gravity":
		return 1
	return 2


func _load_profile(profile: Dictionary, preset_index: int) -> void:
	_loading = true
	_preset_selector.select(preset_index)
	for spec: Dictionary in FIELD_SPECS:
		var key: String = str(spec.key)
		if _fields.has(key):
			(_fields[key] as SpinBox).value = float(profile.get(key, 0.0))
	_loading = false
	if _status_label != null:
		_status_label.text = ""


func _on_preset_selected(index: int) -> void:
	if _loading:
		return
	if index == 0 or index == 1:
		_load_profile(_profiles.preset(index), index)


func _on_field_changed(_value: float) -> void:
	if _loading:
		return
	if _preset_selector.selected != 2:
		_loading = true
		_preset_selector.select(2)
		_loading = false


func _on_apply() -> void:
	var base: Dictionary = (
		_profiles.preset(_preset_selector.selected)
		if _preset_selector.selected == 0 or _preset_selector.selected == 1
		else _profiles.preset(0)
	)
	var candidate: Dictionary = base.duplicate(true)
	if _preset_selector.selected == 2:
		candidate.id = "custom"
		candidate.label = "Custom"
	for spec: Dictionary in FIELD_SPECS:
		var key: String = str(spec.key)
		var value: float = (_fields[key] as SpinBox).value
		if key in ["step_height", "knee_height", "clamber_height"]:
			candidate[key] = int(round(value))
		else:
			candidate[key] = value
	var resolved: Dictionary = _profiles.resolve(candidate)
	if not resolved.get("ok", false):
		set_error("Rejected: " + str(resolved.get("error", "invalid profile")))
		return
	_status_label.text = "Queued; profile becomes authoritative with the fresh reset."
	apply_requested.emit(resolved.profile)
