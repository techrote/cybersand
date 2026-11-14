extends ConfirmationDialog

# Focused authoring form. This owns a declarative project, never raster cells or
# the live World. Native admission and preview stay in the existing GEN-007 host.
const Project = preload("res://scripts/architectural_generator_project.gd")
const MAX_FILE_BYTES := 1024 * 1024
const DIMENSIONS := [
	["room_size", "Typical room / bay size", 12, 256],
	["floor_height", "Floor height (Arcology)", 16, 256],
	["wall_thickness", "Wall thickness", 1, 5],
	["door_width", "Door aperture width", 2, 64],
	["shaft_width", "Service shaft width (Arcology; 0 = off)", 0, 64],
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
var _style_tabs := TabContainer.new()
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
	title = "Architectural Generator · Styles and dimensions"
	ok_button_text = "Generate native preview"
	cancel_button_text = "Keep previous settings"
	dialog_hide_on_ok = false
	exclusive = true
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	_note(body, "Configure a finite architectural starting map. Preview and installation use the existing native GEN-007 generator. Installing the preview replaces the current map after your confirmation.")
	var row := _row(body)
	for entry: Array in [["Seed", _seed, 0, 9007199254740991], ["World X", _x, -1000000, 1000000], ["World Y", _y, -1000000, 1000000]]:
		var control: SpinBox = entry[1]
		control.min_value = entry[2]
		control.max_value = entry[3]
		control.rounded = true
		if control == _seed:
			# Range's rounded/step snapping loses units near the largest exact
			# JSON integer. Preserve the exact value; the compiler rejects fractions.
			control.step = 0
			control.rounded = false
			control.custom_arrow_step = 1.0
		control.custom_minimum_size.x = 112
		_field(row, entry[0], control)
	row = _row(body)
	for side: int in [512, 1024]: _extent.add_item("%d × %d" % [side, side], side)
	for side: int in [16, 32, 64, 128, 256, 512]: _zone_scale.add_item("%d cells" % side, side)
	_field(row, "Map size", _extent)
	_field(row, "Zone planning block", _zone_scale)
	_corridor.min_value = 2
	_corridor.max_value = 64
	_corridor.rounded = true
	_corridor.custom_minimum_size.x = 96
	_field(row, "Corridor width (global)", _corridor)
	row = _row(body)
	_tunnels.text = "Automatic tunnels"
	_doors.text = "Automatic doors"
	_windows.text = "Automatic windows"
	for toggle: CheckButton in [_tunnels, _doors, _windows]: row.add_child(toggle)
	_note(body, "Tunnels carve the shared automatic network across districts. Turning them off preserves explicit authored routes. Doors are material apertures, not interactive actors. Windows affect Arcology façades; service shafts remain independent.")
	_note(body, "Choose up to three styles. Enabled shares must total 100%. Coverage measures assigned zone area, including empty space; it is not material occupancy. Geometry applies uniformly to every prepared module of that style.")
	_style_tabs.custom_minimum_size.y = 300
	_style_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_style_tabs)
	for slot: int in 3:
		var card := VBoxContainer.new()
		card.name = "Style %d" % (slot + 1)
		card.add_theme_constant_override("separation", 8)
		_style_tabs.add_child(card)
		row = _row(card)
		var enabled := CheckBox.new()
		enabled.text = "Include style"
		row.add_child(enabled)
		var chooser := OptionButton.new()
		chooser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chooser.fit_to_longest_item = false
		chooser.custom_minimum_size.x = 190
		chooser.clip_text = true
		_field(row, "Preset", chooser)
		var share := _spin(0, 100, 0, false)
		share.step = 0
		share.custom_arrow_step = 0.1
		share.suffix = "%"
		_field(row, "Target area", share)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		card.add_child(grid)
		var dimensions := {}
		for spec: Array in DIMENSIONS:
			var knob := _spin(spec[2], spec[3], spec[2])
			_field(grid, spec[1] + " (cells)", knob)
			dimensions[spec[0]] = knob
		var description := _note(card, "")
		_style_controls.append({"enabled": enabled, "chooser": chooser, "share": share,
			"geometry": dimensions, "description": description})
		chooser.item_selected.connect(_choose_style.bind(slot))
	row = _row(body)
	for action: Array in [["Save project…", "save"], ["Load project…", "load"], ["Import style JSON…", "style"]]:
		var button := Button.new()
		button.text = action[0]
		button.pressed.connect(_choose_file.bind(action[1]))
		row.add_child(button)
	for slot: int in 3: _import_slot.add_item("Style %d" % (slot + 1), slot)
	_field(row, "Import into", _import_slot)
	_note(body, "Project files embed all selected style definitions. Saved generated maps embed the resolved native recipe, so reopening never needs an external preset file. Expert recipes remain available through Choose profile file in the main generator dialog.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	_files.access = FileDialog.ACCESS_FILESYSTEM
	_files.add_filter("*.json", "Architectural project or style JSON")
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
	popup_centered_clamped(Vector2i(860, 720), 0.92)

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
	var defaults: Dictionary = Project.default_project()
	for slot: int in _style_controls.size():
		var controls: Dictionary = _style_controls[slot]
		var style: Dictionary = _project.styles[slot] if slot < _project.styles.size() else {"enabled": false, "share": 0.0, "preset": defaults.styles[slot].preset}
		var preset: Dictionary = style.preset
		controls.enabled.set_pressed_no_signal(bool(style.enabled))
		controls.share.set_value_no_signal(float(style.share))
		controls.chooser.clear()
		var selected := -1
		for index: int in defaults.styles.size():
			var builtin: Dictionary = defaults.styles[index].preset
			controls.chooser.add_item(str(builtin.name))
			if str(builtin.id) == str(preset.id): selected = index
		if selected == -1:
			controls.chooser.add_item(str(preset.name) + " (custom)")
			selected = controls.chooser.item_count - 1
		controls.chooser.select(selected)
		for spec: Array in DIMENSIONS:
			var control: SpinBox = controls.geometry[spec[0]]
			if spec[0] == "room_size":
				control.min_value = 12 if preset.module == "vault" else 16
				control.max_value = 128 if preset.module == "vault" else 256
			elif spec[0] == "wall_thickness":
				control.max_value = 4 if preset.module == "vault" else 5
			control.set_value_no_signal(int(preset.geometry[spec[0]]))
			control.editable = not (spec[0] in ["floor_height", "shaft_width"] and preset.module != "arcology")
		controls.description.text = "%s · %s v%d · theme %s\nWall / floor / window materials: %s / %s / %s.\nDoors: %s · Windows: %s · Deterioration: %.1f%%" % [
			str(preset.id), str(preset.module), int(preset.module_version), str(preset.theme),
			str(preset.materials.wall), str(preset.materials.floor), str(preset.materials.window),
			_aperture_label(preset,"automatic_doors"), _aperture_label(preset,"automatic_windows"), 100.0*float(preset.deterioration)]
	_syncing = false

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
	var defaults: Dictionary = Project.default_project()
	while value.styles.size() <= slot:
		var index: int = value.styles.size()
		value.styles.append({"enabled": false, "share": 0.0, "preset": defaults.styles[index].preset.duplicate(true)})

func _choose_style(index: int, slot: int) -> void:
	if _syncing: return
	var defaults: Dictionary = Project.default_project()
	if index >= defaults.styles.size(): return
	_project = project()
	_ensure_slot(_project, slot)
	_project.styles[slot].preset = defaults.styles[index].preset.duplicate(true)
	_sync_controls()
	_status.text = "Preset selected. Dimensions are fixed for this style; Generate validates the complete project."

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
	_status.text = "Project loaded. All preset definitions are embedded; native admission occurs when generating the preview."
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
		_status.text = "Refused · Select one of the three style slots."
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
