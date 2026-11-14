extends ConfirmationDialog

# Focused authoring form. This owns a declarative project, never raster cells or
# the live World. Native admission and preview stay in the existing GEN-007 host.
const Project = preload("res://scripts/architectural_generator_project.gd")
const MAX_FILE_BYTES := 1024 * 1024
const DIMENSIONS := [
	["room_size", "Room / bay", 12, 256],
	["floor_height", "Floor", 16, 256],
	["wall_thickness", "Wall", 1, 5],
	["door_width", "Door", 2, 64],
	["shaft_width", "Shaft", 0, 64],
]

signal project_compiled(result: Dictionary)

var _project: Dictionary = {}
var _syncing := false
var _mounted := false
var _seed := SpinBox.new()
var _x := SpinBox.new()
var _y := SpinBox.new()
var _extent := OptionButton.new()
var _zone_scale := OptionButton.new()
var _corridor := SpinBox.new()
var _tunnels := CheckButton.new()
var _doors := CheckButton.new()
var _windows := CheckButton.new()
var _style_controls: Array[Dictionary] = []
var _style_strip := HBoxContainer.new()
var _summary := Label.new()
var _status := Label.new()
var _files := FileDialog.new()
var _file_action := ""
var _import_slot := OptionButton.new()

func _spin(minimum: float, maximum: float, initial: float, integral := true) -> SpinBox:
	var result := SpinBox.new()
	result.min_value = minimum
	result.max_value = maximum
	result.step = 1.0 if integral else 0.1
	result.rounded = integral
	result.value = initial
	result.custom_minimum_size.x = 112
	return result

func _field(parent: Container, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	parent.add_child(control)

func _row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	return row

func _note(parent: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func mount() -> void:
	if _mounted: return
	_mounted = true
	title = "Architectural Generator"
	ok_button_text = "Generate preview"
	cancel_button_text = "Close"
	dialog_hide_on_ok = false
	exclusive = true
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	scroll.add_child(body)

	var row := _row(body)
	for entry: Array in [["Seed", _seed, 0, 9007199254740991],
			["X", _x, -1000000, 1000000], ["Y", _y, -1000000, 1000000]]:
		var control: SpinBox = entry[1]
		control.min_value = entry[2]
		control.max_value = entry[3]
		control.rounded = true
		if control == _seed:
			control.step = 0
			control.rounded = false
			control.custom_arrow_step = 1.0
		control.custom_minimum_size.x = 120 if control == _seed else 85
		_field(row, entry[0], control)
	for side: int in [512, 1024]: _extent.add_item("%d²" % side, side)
	for side: int in [16, 32, 64, 128, 256, 512]: _zone_scale.add_item("%d" % side, side)
	_field(row, "Map", _extent)
	_field(row, "Zone", _zone_scale)
	_zone_scale.tooltip_text = "Style-zone planning block size in cells."
	_corridor.min_value = 2
	_corridor.max_value = 64
	_corridor.rounded = true
	_corridor.custom_minimum_size.x = 66
	_field(row, "Corridor", _corridor)

	row = _row(body)
	for toggle: CheckButton in [_tunnels, _doors, _windows]:
		row.add_child(toggle)
	_tunnels.text = "Tunnels"
	_doors.text = "Doors"
	_windows.text = "Windows"
	_tunnels.tooltip_text = "Automatic shared-network cuts; explicit paths remain."
	_doors.tooltip_text = "Automatic material openings, not interactive doors."
	_windows.tooltip_text = "Arcology façade glazing/openings."
	var equal := Button.new()
	equal.text = "Equal shares"
	equal.tooltip_text = "Split 100% evenly among enabled styles."
	equal.pressed.connect(_equalize_shares)
	row.add_child(equal)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_summary)

	_style_strip.add_theme_constant_override("separation", 6)
	_style_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_style_strip)
	for slot: int in Project.MAX_STYLES:
		var frame := PanelContainer.new()
		frame.custom_minimum_size.x = 184
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_strip.add_child(frame)
		var margin := MarginContainer.new()
		for edge: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 7)
		frame.add_child(margin)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 5)
		margin.add_child(card)
		var heading := _row(card)
		var enabled := CheckBox.new()
		enabled.text = "#%d" % (slot + 1)
		enabled.tooltip_text = "Include this style in the generated map."
		heading.add_child(enabled)
		var share := _spin(0, 100, 0, false)
		share.step = 0
		share.custom_arrow_step = 0.1
		share.suffix = "%"
		share.tooltip_text = "Assigned zone area, including Empty cells."
		share.custom_minimum_size.x = 78
		share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(share)
		var chooser := OptionButton.new()
		chooser.fit_to_longest_item = false
		chooser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chooser.clip_text = true
		chooser.custom_minimum_size.x = 135
		card.add_child(chooser)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 5)
		grid.add_theme_constant_override("v_separation", 3)
		card.add_child(grid)
		var dimensions := {}
		for spec: Array in DIMENSIONS:
			var knob := _spin(spec[2], spec[3], spec[2])
			knob.custom_minimum_size.x = 74
			knob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if spec[0] in ["floor_height", "shaft_width"]:
				knob.tooltip_text = "Arcology only. Shaft 0 disables the service shaft." if spec[0] == "shaft_width" else "Arcology only."
			_field(grid, spec[1], knob)
			dimensions[spec[0]] = knob
		var description := _note(card, "")
		description.add_theme_font_size_override("font_size", 11)
		description.clip_text = true
		_style_controls.append({"card": frame, "enabled": enabled, "chooser": chooser,
			"share": share, "geometry": dimensions, "description": description})
		chooser.item_selected.connect(_choose_style.bind(slot))
		enabled.toggled.connect(func(_value: bool) -> void: _update_summary())
		share.value_changed.connect(func(_value: float) -> void: _update_summary())

	row = _row(body)
	for action: Array in [["Save…", "save"], ["Load…", "load"], ["Import style…", "style"]]:
		var button := Button.new()
		button.text = action[0]
		button.pressed.connect(_choose_file.bind(action[1]))
		row.add_child(button)
	for slot: int in Project.MAX_STYLES: _import_slot.add_item("#%d" % (slot + 1), slot)
	_field(row, "Into", _import_slot)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	_files.access = FileDialog.ACCESS_FILESYSTEM
	_files.add_filter("*.json", "Architectural JSON")
	_files.file_selected.connect(_file_selected)
	add_child(_files)
	confirmed.connect(_apply)
	get_tree().root.size_changed.connect(func() -> void:
		if visible: _fit_bounds())
	_project = Project.default_project()
	_sync_controls()

func _fit_bounds() -> void:
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(get_tree().root.get_visible_rect().size)) if is_embedded() else DisplayServer.screen_get_usable_rect(get_tree().root.current_screen)
	max_size = Vector2i(maxi(1, bounds.size.x - 32), maxi(1, bounds.size.y - 64))
	if visible:
		size = size.min(max_size)
		position = position.clamp(bounds.position, bounds.end - size)

func open_project(value: Dictionary = {}) -> void:
	if not _mounted: mount()
	if not value.is_empty():
		set_project(value)
	else:
		_sync_controls()
	_fit_bounds()
	popup_centered_clamped(Vector2i(1190, 635), 0.96)

func _select_id(control: OptionButton, id: int) -> void:
	for index: int in control.item_count:
		if control.get_item_id(index) == id:
			control.select(index)
			return

func _sync_controls() -> void:
	_syncing = true
	_seed.set_value_no_signal(_project.seed)
	_x.set_value_no_signal(int(_project.origin[0]))
	_y.set_value_no_signal(int(_project.origin[1]))
	_select_id(_extent, int(_project.extent[0]))
	_select_id(_zone_scale, int(_project.zone_scale))
	_corridor.set_value_no_signal(int(_project.corridor_width))
	_tunnels.set_pressed_no_signal(bool(_project.automatic_tunnels))
	_doors.set_pressed_no_signal(bool(_project.automatic_doors))
	_windows.set_pressed_no_signal(bool(_project.automatic_windows))
	var presets: Array = Project.builtin_presets()
	for slot: int in _style_controls.size():
		var controls: Dictionary = _style_controls[slot]
		var fallback: Dictionary = presets[slot]
		var style: Dictionary = _project.styles[slot] if slot < _project.styles.size() else {
			"enabled": false, "share": 0.0, "preset": fallback}
		var preset: Dictionary = style.preset
		controls.enabled.set_pressed_no_signal(bool(style.enabled))
		controls.share.set_value_no_signal(float(style.share))
		controls.chooser.clear()
		var selected := -1
		for index: int in presets.size():
			var builtin: Dictionary = presets[index]
			controls.chooser.add_item(str(builtin.name))
			if str(builtin.id) == str(preset.id): selected = index
		if selected == -1:
			controls.chooser.add_item(str(preset.name) + " (custom)")
			selected = controls.chooser.item_count - 1
		controls.chooser.select(selected)
		controls.chooser.tooltip_text = str(preset.name)
		for spec: Array in DIMENSIONS:
			var control: SpinBox = controls.geometry[spec[0]]
			if spec[0] == "room_size":
				control.min_value = 12 if preset.module == "vault" else 16
				control.max_value = 128 if preset.module == "vault" else 256
			elif spec[0] == "wall_thickness":
				control.max_value = 4 if preset.module == "vault" else 5
			control.set_value_no_signal(int(preset.geometry[spec[0]]))
			control.editable = not (spec[0] in ["floor_height", "shaft_width"] and preset.module != "arcology")
		controls.description.text = "%s · %s" % [str(preset.module).capitalize(), str(preset.theme).replace("_", " ")]
		controls.description.tooltip_text = "Style: %s\nWall / floor / window materials: %s / %s / %s\nDoors: %s · Windows: %s · Deterioration: %.1f%%" % [
			str(preset.id), str(preset.materials.wall), str(preset.materials.floor),
			str(preset.materials.window), _aperture_label(preset,"automatic_doors"),
			_aperture_label(preset,"automatic_windows"), 100.0 * float(preset.deterioration)]
	_syncing = false
	_update_summary()

func _update_summary() -> void:
	if _syncing: return
	var total := 0.0
	var selected := 0
	for controls: Dictionary in _style_controls:
		if controls.enabled.button_pressed:
			selected += 1
			total += controls.share.value
	_summary.text = "%d styles · %.1f%% / 100%%" % [selected, total]
	_summary.tooltip_text = "Enabled style shares must total 100%. Inactive styles are ignored."

func _equalize_shares() -> void:
	var enabled: Array[Dictionary] = []
	for controls: Dictionary in _style_controls:
		if controls.enabled.button_pressed: enabled.append(controls)
	if enabled.is_empty(): return
	var each := 100.0 / enabled.size()
	for index: int in enabled.size():
		enabled[index].share.value = each if index < enabled.size() - 1 else 100.0 - each * index
	_update_summary()

func _aperture_label(preset: Dictionary, key: String) -> String:
	if not preset.apertures.has(key): return "inherit global switch"
	return "preset On" if bool(preset.apertures[key]) else "preset Off"

func project() -> Dictionary:
	var value: Dictionary = _project.duplicate(true)
	value.seed = _seed.value
	if _seed.value == floor(_seed.value): value.seed = int(_seed.value)
	value.origin = [int(_x.value), int(_y.value)]
	value.extent = [_extent.get_selected_id(), _extent.get_selected_id()]
	value.zone_scale = _zone_scale.get_selected_id()
	value.corridor_width = int(_corridor.value)
	value.automatic_tunnels = _tunnels.button_pressed
	value.automatic_doors = _doors.button_pressed
	value.automatic_windows = _windows.button_pressed
	for slot: int in _style_controls.size():
		var controls: Dictionary = _style_controls[slot]
		if slot >= value.styles.size():
			if not controls.enabled.button_pressed: continue
			_ensure_slot(value, slot)
		value.styles[slot].enabled = controls.enabled.button_pressed
		value.styles[slot].share = controls.share.value
		for spec: Array in DIMENSIONS:
			value.styles[slot].preset.geometry[spec[0]] = int(controls.geometry[spec[0]].value)
	return value

func _ensure_slot(value: Dictionary, slot: int) -> void:
	var presets: Array = Project.builtin_presets()
	while value.styles.size() <= slot:
		var index: int = value.styles.size()
		value.styles.append({"enabled": false, "share": 0.0, "preset": presets[index].duplicate(true)})

func _choose_style(index: int, slot: int) -> void:
	if _syncing: return
	var presets: Array = Project.builtin_presets()
	if index >= presets.size(): return
	_project = project()
	_ensure_slot(_project, slot)
	_project.styles[slot].preset = presets[index].duplicate(true)
	_sync_controls()
	_status.text = ""

func set_project(value: Dictionary) -> bool:
	var result: Dictionary = Project.compile(value)
	if not result.get("ok", false):
		_status.text = "Refused · " + str(result.get("error", "Invalid architectural project."))
		return false
	if int(result.project.extent[0]) not in [512, 1024]:
		_status.text = "Refused · Shared Workbench architectural previews support 512 or 1024 cells per side. The 256-cell project size is available to native qualification tools."
		return false
	_project = result.project.duplicate(true)
	_sync_controls()
	_status.text = "Project loaded."
	return true

func _apply() -> void:
	var result: Dictionary = Project.compile(project())
	if not result.get("ok", false):
		_status.text = "Refused · " + str(result.get("error", "Invalid architectural project."))
		return
	_project = result.project.duplicate(true)
	project_compiled.emit(result)
	hide()

func _choose_file(action: String) -> void:
	_file_action = action
	_files.file_mode = FileDialog.FILE_MODE_SAVE_FILE if action == "save" else FileDialog.FILE_MODE_OPEN_FILE
	_files.title = {"save": "Save embedded architectural project", "load": "Load architectural project", "style": "Import declarative architectural style"}[action]
	if action == "save": _files.current_file = "architectural-project.json"
	_files.popup_centered_clamped(Vector2i(800, 560), 0.85)

func _file_selected(path: String) -> void:
	match _file_action:
		"save": save_project(path)
		"load": load_project(path)
		"style": import_style(path, _import_slot.get_selected_id())

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false, "error": "Cannot read " + path}
	if file.get_length() > MAX_FILE_BYTES: return {"ok": false, "error": "JSON exceeds the bounded 1 MiB project limit."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "Expected an architectural JSON object in " + path}
	return {"ok": true, "value": parser.data}

func load_project(path: String) -> bool:
	var parsed := _read_json(path)
	if not parsed.ok:
		_status.text = "Refused · " + str(parsed.error)
		return false
	return set_project(parsed.value)

func import_style(path: String, slot: int) -> bool:
	var parsed := _read_json(path)
	if not parsed.ok:
		_status.text = "Refused · " + str(parsed.error)
		return false
	if slot < 0 or slot >= _style_controls.size():
		_status.text = "Refused · Select one of the five style slots."
		return false
	var candidate: Dictionary = project()
	_ensure_slot(candidate, slot)
	var result: Dictionary = Project.import_preset(candidate, parsed.value, slot)
	if not result.get("ok", false):
		_status.text = "Refused · " + str(result.get("error", "Invalid architectural style."))
		return false
	_project = result.project.duplicate(true)
	_sync_controls()
	_status.text = "Imported %s into Style %d. The project now contains the complete preset." % [str(parsed.value.get("name", "custom style")), slot + 1]
	return true

func save_project(path: String) -> bool:
	var result: Dictionary = Project.compile(project())
	if not result.get("ok", false):
		_status.text = "Refused · " + str(result.get("error", "Invalid architectural project."))
		return false
	var body := JSON.stringify(result.project, "\t") + "\n"
	if body.to_utf8_buffer().size() > MAX_FILE_BYTES:
		_status.text = "Refused · Project exceeds the bounded 1 MiB file limit."
		return false
	var target := ProjectSettings.globalize_path(path)
	var temporary := target + "." + Crypto.new().generate_random_bytes(8).hex_encode() + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_status.text = "Refused · Cannot write the selected project file."
		return false
	file.store_string(body)
	file.flush()
	var state := file.get_error()
	file.close()
	if state == OK: state = DirAccess.rename_absolute(temporary, target)
	if state != OK:
		DirAccess.remove_absolute(temporary)
		_status.text = "Refused · Could not atomically replace the project file; previous file preserved."
		return false
	_project = result.project.duplicate(true)
	_status.text = "Saved complete architectural project: " + path
	return true
