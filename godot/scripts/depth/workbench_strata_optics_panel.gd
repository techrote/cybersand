extends Node

## The Optics Lab edits presentation through the existing Strata mediator.
## It owns no World, renderer, camera, material texture or simulation callback.
const IDS := ["play", "scripted", "effects", "background"]
const NAMES := ["Play · always crisp", "Rear architecture", "Atmosphere / effects", "Distant background"]
const FOCUS_IDS := ["play", "manual", "plane", "authoring"]
const FOCUS_NAMES := ["Fixed Play focus", "Manual optical distance", "Selected focal plane", "Follow authoring plane"]
const EFFECTS := ["defocus", "tonal", "chromatic", "atmosphere", "illumination", "shadows", "detail"]
const EFFECT_NAMES := ["Defocus", "Tonal depth", "Chromatic depth", "Atmosphere", "Illumination", "Architectural shadows", "Detail suppression"]

var controller: Node
var _syncing := false
var _state: Dictionary = {}
var _profile_items: Array = []
var _profile_signature := ""
var _plane_id := "scripted"
var _page: ScrollContainer
var _rows: VBoxContainer
var _enabled := CheckButton.new()
var _profile := OptionButton.new()
var _profile_description := Label.new()
var _edit_target := Label.new()
var _status := Label.new()
var _bypass := CheckButton.new()
var _clarity := CheckButton.new()
var _focus_mode := OptionButton.new()
var _focal_plane := OptionButton.new()
var _inspection_focus := OptionButton.new()
var _quality := OptionButton.new()
var _plane_picker := OptionButton.new()
var _plane_participates := CheckBox.new()
var _plane_note := Label.new()
var _defocus_method := OptionButton.new()
var _tint := ColorPickerButton.new()
var _scattering := ColorPickerButton.new()
var _preset_name := LineEdit.new()
var _save_preset := Button.new()
var _delete_preset := Button.new()
var _advanced_toggle := CheckButton.new()
var _advanced: VBoxContainer
var _plane_advanced_toggle := CheckButton.new()
var _plane_advanced: VBoxContainer
var _global_controls: Dictionary = {}
var _plane_controls: Dictionary = {}
var _effects: Dictionary = {}
var _wipe: Dictionary = {}
var _shadow_xy: Array[SpinBox] = []


func mount(mediator: Node, tabs: TabContainer) -> void:
	controller = mediator
	name = "StrataOpticsLab"
	set_process(false)
	_page = ScrollContainer.new()
	_page.name = "Optics"
	_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(_page)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 9)
	_page.add_child(_rows)
	_heading(_rows, "STRATA OPTICS LAB")
	_note(_rows, "Depth, atmosphere and lens character for the existing four planes. Play remains physically authoritative and crisp.")
	_edit_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_edit_target.add_theme_color_override("font_color", Color("91f3d0"))
	_rows.add_child(_edit_target)
	_enabled.text = "Enable optical processing"
	_enabled.tooltip_text = "Presentation only. This never modifies native material, collision or actors. Classic performs no new optical processing."
	_enabled.toggled.connect(func(value: bool) -> void: _global_patch({"enabled":value}))
	_rows.add_child(_enabled)
	_profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile.item_selected.connect(_select_profile)
	_rows.add_child(_profile)
	_profile_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_description.add_theme_color_override("font_color", Color("b9c9d6"))
	_rows.add_child(_profile_description)
	var comparisons := HBoxContainer.new()
	_rows.add_child(comparisons)
	_button(comparisons, "Classic", "Reset the authored scene presentation to exact Strata 002 optics-disabled settings. Use Bypass for a temporary comparison that preserves your settings.", func() -> void: _invoke("reset_optics"))
	_bypass.text = "Bypass / before"
	_bypass.tooltip_text = "Temporary exact Classic view. Your authored optical settings remain available when released and are not overwritten."
	_bypass.toggled.connect(func(value: bool) -> void: _inspect({"bypass":value}))
	comparisons.add_child(_bypass)
	_clarity.text = "Show physical Play"
	_clarity.tooltip_text = "Temporary readability assistance through contrast and visibility. Suppress competing rear architecture and reduce authored atmosphere visibility; physical materials stay unchanged. Bypass restores Classic."
	_clarity.toggled.connect(func(value: bool) -> void: _inspect({"clarity":value}))
	_rows.add_child(_clarity)
	_wipe = _number(_rows, "Processed share", 0.0, 1.0, 0.01,
		"0 is Classic, 1 is fully processed. Processed architecture occupies the left side of the screen. During a split, authored atmosphere stays Classic across the view and parallax matches Classic; geometry and camera are shared.",
		func(value: float) -> void: _inspect({"wipe":value}))
	_add_global(_rows, "strength", "Overall strength", 0.0, 1.0, 0.01, "Blend optical treatment with the reference appearance; native colours are unchanged.")
	_heading(_rows, "Lens and focus")
	for title: String in FOCUS_NAMES: _focus_mode.add_item(title)
	_focus_mode.tooltip_text = "Fixed Play is stable during gameplay. Authoring focus follows the existing edit selection but never changes that selection."
	_focus_mode.item_selected.connect(func(index: int) -> void: _global_patch({"focus_mode":FOCUS_IDS[index]}))
	_rows.add_child(_focus_mode)
	for title: String in NAMES: _focal_plane.add_item(title)
	_focal_plane.tooltip_text = "Choose the lens focal plane. This does not select an editing target."
	_focal_plane.item_selected.connect(func(index: int) -> void: _global_patch({"focal_plane":IDS[index]}))
	_rows.add_child(_focal_plane)
	_add_global(_rows, "focus_distance", "Focus distance", -1.0, 2.0, 0.01, "Artistic optical-depth units. Active in manual focus mode; separate from native cell coordinates.")
	_add_global(_rows, "dof_width", "Sharp focus width", 0.0, 2.0, 0.01, "Optical-depth interval retained in focus. Wider values keep more architectural planes crisp.")
	_add_global(_rows, "defocus", "Defocus amount", 0.0, 3.0, 0.05, "Aperture-like artistic strength. Radius also depends on distance from focus and per-plane response. Limits: Low one source cell, Balanced three, High six. Play is never defocused.")
	_add_global(_rows, "transition_speed", "Focus response", 0.0, 12.0, 0.1, "Focus interpolation response per second. Zero switches immediately; larger values settle faster. No mouse-driven focus hunting.")
	_inspection_focus.add_item("Inspection focus · none")
	for title: String in NAMES: _inspection_focus.add_item("Inspect · " + title)
	_inspection_focus.tooltip_text = "Temporary focal-plane override. Leaving inspection restores the authored focus; native editing authority is unchanged."
	_inspection_focus.item_selected.connect(func(index: int) -> void: _inspect({"focus_override":"" if index == 0 else IDS[index - 1]}))
	_rows.add_child(_inspection_focus)
	_heading(_rows, "Depth and atmosphere")
	_add_global(_rows, "tonal", "Tonal separation", 0.0, 1.0, 0.01, "Compress distant contrast and preserve the physical silhouette hierarchy.")
	_add_global(_rows, "chromatic", "Colour separation", 0.0, 1.0, 0.01, "Depth-weighted saturation and tint treatment. Readability must remain useful without relying on colour alone.")
	_add_global(_rows, "atmosphere", "Atmospheric density", 0.0, 2.0, 0.01, "Blend architectural material colours toward the scattering colour. The Atmosphere tab separately controls authored steam, rain, light shafts and pools.")
	_add_global(_rows, "illumination", "Light diffusion", 0.0, 2.0, 0.01, "Bounded decorative highlight spread. Does not introduce native lighting or full-screen bloom.")
	_add_global(_rows, "clarity", "Play separation", 0.0, 1.0, 0.01, "Suppress competing rear architecture around Play features and actors. Fully processed views also reduce authored atmosphere visibility. Play materials stay unchanged.")
	_quality.add_item("Quality · low")
	_quality.add_item("Quality · balanced")
	_quality.add_item("Quality · high / experimental")
	_quality.tooltip_text = "Application performance preference, separate from the authored scene. Low: up to one source-cell radius and five samples. Balanced: three cells and thirteen samples. High: six cells and twenty-five samples."
	_quality.item_selected.connect(func(index: int) -> void:
		if not _syncing: _invoke("set_optics_quality", [["low","balanced","high"][index]]))
	_rows.add_child(_quality)
	_advanced_toggle.text = "Advanced optical experiments"
	_rows.add_child(_advanced_toggle)
	_advanced = VBoxContainer.new()
	_advanced.add_theme_constant_override("separation", 7)
	_advanced.visible = false
	_rows.add_child(_advanced)
	_advanced_toggle.toggled.connect(func(value: bool) -> void: _advanced.visible = value)
	_build_advanced()
	_heading(_rows, "Per-plane composition")
	for title: String in NAMES: _plane_picker.add_item(title)
	_plane_picker.select(1)
	_plane_picker.tooltip_text = "Select the optical parameter group to inspect. This is independent of the native edit target. Use Layers to change editing authority."
	_plane_picker.item_selected.connect(func(index: int) -> void:
		_plane_id = IDS[index]
		_refresh_plane())
	_rows.add_child(_plane_picker)
	_plane_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_plane_note)
	_plane_participates.text = "This plane participates in optics"
	_plane_participates.toggled.connect(func(value: bool) -> void: _plane_patch({"participates":value}))
	_rows.add_child(_plane_participates)
	_add_plane(_rows, "depth", "Optical depth", -1.0, 2.0, 0.01, "Independent lens distance; this never changes geometry, collision or native coordinates.")
	_add_plane(_rows, "contrast", "Contrast", 0.25, 1.5, 0.01, "Local tonal contrast contribution. Subordinate rear planes without losing their silhouette.")
	_add_plane(_rows, "saturation", "Saturation", 0.0, 1.5, 0.01, "Decorative colour intensity. Zero provides a useful non-colour comparison.")
	_add_plane(_rows, "brightness", "Brightness", 0.25, 2.0, 0.01, "Bounded decorative luminance multiplier; inspect clipping at extremes.")
	_add_plane(_rows, "defocus", "Defocus response", 0.0, 2.0, 0.01, "Plane-specific sensitivity to lens defocus; zero retains sharp edges.")
	_add_plane(_rows, "atmosphere", "Haze response", 0.0, 2.0, 0.01, "Plane-specific atmospheric attenuation.")
	_plane_advanced_toggle.text = "Advanced plane controls"
	_rows.add_child(_plane_advanced_toggle)
	_plane_advanced = VBoxContainer.new()
	_plane_advanced.add_theme_constant_override("separation", 7)
	_plane_advanced.visible = false
	_rows.add_child(_plane_advanced)
	_plane_advanced_toggle.toggled.connect(func(value: bool) -> void: _plane_advanced.visible = value)
	_add_plane(_plane_advanced, "glow", "Light response", 0.0, 2.0, 0.01, "Relative contribution to bounded decorative highlight spreading.")
	_add_plane(_plane_advanced, "opacity", "Optical opacity", 0.0, 1.0, 0.01, "Additional architectural visibility while optics is active. Fully processed views also apply this to authored atmosphere; split comparison keeps atmosphere at Classic visibility. Native editing permissions do not change.")
	_add_plane(_plane_advanced, "parallax", "Parallax response", 0.0, 2.0, 0.01, "Optical multiplier of this decorative plane's existing camera parallax. Play mapping remains exact.")
	var tint_row := HBoxContainer.new()
	_plane_advanced.add_child(tint_row)
	_note(tint_row, "Plane tint")
	_tint.custom_minimum_size = Vector2(100, 28)
	_tint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tint.edit_alpha = false
	_tint.tooltip_text = "RGB optical tint; reset to white for neutral. Native material colours remain unchanged."
	_tint.color_changed.connect(func(value: Color) -> void: _plane_patch({"tint":[value.r,value.g,value.b]}))
	tint_row.add_child(_tint)
	_heading(_rows, "Named custom presets")
	_note(_rows, "Save a copy of the current artistic settings. Inspection bypass, wipe, temporary focus and quality preference are not part of a preset.")
	_preset_name.placeholder_text = "Name for this optical composition"
	_preset_name.max_length = 48
	_preset_name.tooltip_text = "Choose a name for a new preset or an explicit replacement of your existing named preset. Built-in profiles remain available."
	_rows.add_child(_preset_name)
	var preset_actions := HBoxContainer.new()
	_rows.add_child(preset_actions)
	_save_preset.text = "Save / duplicate as named preset"
	_save_preset.pressed.connect(_save_named)
	preset_actions.add_child(_save_preset)
	_delete_preset.text = "Remove selected custom preset"
	_delete_preset.pressed.connect(_delete_selected)
	_rows.add_child(_delete_preset)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("cad5e0"))
	_rows.add_child(_status)
	refresh({}, "")


func _build_advanced() -> void:
	_defocus_method.add_item("Pixel kernel · alpha-weighted")
	_defocus_method.add_item("Diffusion · highlight spread")
	_defocus_method.add_item("Detail · suppress fine contrast")
	_defocus_method.tooltip_text = "Different optical mechanisms share the same bounded renderer. Compare architecture detail and silhouette retention."
	_defocus_method.item_selected.connect(func(index: int) -> void: _global_patch({"defocus_method":["pixel","diffusion","detail"][index]}))
	_advanced.add_child(_defocus_method)
	_add_global(_advanced, "detail", "Detail suppression", 0.0, 1.0, 0.01, "Suppress decorative high-frequency contrast while retaining major architecture silhouettes.")
	_add_global(_advanced, "shadow", "Architectural shadow", 0.0, 1.0, 0.01, "Presentation shadow derived from existing Play occupancy; no physical light transport.")
	_add_global(_advanced, "shadow_softness", "Shadow softness", 0.0, 4.0, 0.05, "Bounded shadow sampling width in source cells.")
	var offsets := HBoxContainer.new()
	_advanced.add_child(offsets)
	_note(offsets, "Shadow offset · cells")
	for axis: String in ["X", "Y"]:
		var spin := SpinBox.new()
		spin.min_value = -32.0
		spin.max_value = 32.0
		spin.step = 1.0
		spin.prefix = axis
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.tooltip_text = "Directional presentation shadow offset in native source cells."
		_shadow_xy.append(spin)
		offsets.add_child(spin)
		spin.value_changed.connect(func(_value: float) -> void:
			if not _syncing: _global_patch({"shadow_offset":[_shadow_xy[0].value,_shadow_xy[1].value]}))
	var scattering_row := HBoxContainer.new()
	_advanced.add_child(scattering_row)
	_note(scattering_row, "Atmosphere colour")
	_scattering.edit_alpha = false
	_scattering.custom_minimum_size = Vector2(100,28)
	_scattering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scattering.tooltip_text = "Scattering colour for this environment. Warm, lunar, subterranean and neutral treatments need not use blue."
	_scattering.color_changed.connect(func(value: Color) -> void: _global_patch({"scattering_color":[value.r,value.g,value.b]}))
	scattering_row.add_child(_scattering)
	for index: int in EFFECTS.size():
		var toggle := CheckBox.new()
		toggle.text = EFFECT_NAMES[index]
		toggle.tooltip_text = "Independently bypass this effect without changing its stored strength."
		var key: String = EFFECTS[index]
		_effects[key] = toggle
		toggle.toggled.connect(func(value: bool) -> void:
			if _syncing: return
			var effects: Dictionary = _state.get("configuration", {}).get("effects", {}).duplicate(true)
			effects[key] = value
			_global_patch({"effects":effects}))
		_advanced.add_child(toggle)


func refresh(document: Dictionary, status: String = "") -> void:
	_state = _dict_call("optics_state")
	var configuration: Dictionary = _state.get("configuration", {})
	if configuration.is_empty():
		_status.text = "Optics configuration is unavailable until the ordinary Workbench is ready."
		return
	_syncing = true
	_refresh_profiles()
	_enabled.set_pressed_no_signal(bool(configuration.get("enabled", false)))
	var inspection: Dictionary = _state.get("inspection", {})
	_bypass.set_pressed_no_signal(bool(inspection.get("bypass", false)))
	_clarity.set_pressed_no_signal(bool(inspection.get("clarity", false)))
	_set_number(_wipe, float(inspection.get("wipe", 1.0)))
	for key: String in _global_controls:
		_set_number(_global_controls[key], float(configuration.get(key, 0.0)))
	_focus_mode.select(maxi(0, FOCUS_IDS.find(str(configuration.get("focus_mode", "play")))))
	_focal_plane.select(maxi(0, IDS.find(str(configuration.get("focal_plane", "play")))))
	_focal_plane.disabled = str(configuration.get("focus_mode", "play")) != "plane"
	_set_number_editable(_global_controls.focus_distance, str(configuration.get("focus_mode", "play")) == "manual")
	_inspection_focus.select(IDS.find(str(inspection.get("focus_override", ""))) + 1)
	_quality.select(maxi(0, ["low","balanced","high"].find(str(_state.get("quality", "balanced")))))
	_defocus_method.select(maxi(0, ["pixel","diffusion","detail"].find(str(configuration.get("defocus_method", "pixel")))))
	for key: String in _effects:
		(_effects[key] as CheckBox).set_pressed_no_signal(bool(configuration.get("effects", {}).get(key, true)))
	var offsets: Array = configuration.get("shadow_offset", [4.0, 4.0])
	for i: int in 2:
		if not _shadow_xy[i].get_line_edit().has_focus(): _shadow_xy[i].set_value_no_signal(float(offsets[i]))
	_scattering.color = _colour(configuration.get("scattering_color", [0.15,0.18,0.22]))
	var edit_id := str(document.get("presentation", {}).get("active", "play"))
	if not bool(document.get("presentation", {}).get("enabled", false)): edit_id = "play"
	_edit_target.text = "NATIVE EDIT TARGET: " + edit_id.to_upper() + " · optical selection is independent"
	if not bool(document.get("presentation", {}).get("enabled",false)):
		_edit_target.text += " · layered presentation is off; enable it in Layers to see optics"
	var edited_plane: Dictionary = configuration.get("planes", {}).get(edit_id, {})
	if edit_id != "play" and bool(configuration.get("enabled", false)) and float(configuration.get("strength",0.0)) > 0.0 \
			and bool(edited_plane.get("participates",false)) and float(edited_plane.get("opacity",1.0)) <= 0.0 \
			and not bool(inspection.get("bypass",false)):
		_edit_target.text += " · OPTICALLY HIDDEN: use Bypass or Layers Solo to inspect before painting"
	_status.text = status
	if str(_state.get("status", "")) != "": _status.text = str(_state.status)
	_syncing = false
	_refresh_plane()


func _refresh_profiles() -> void:
	var items := _array_call("optics_profiles")
	var signature := JSON.stringify(items)
	if signature != _profile_signature:
		_profile_items = items.duplicate(true)
		_profile_signature = signature
		_profile.clear()
		for item: Dictionary in _profile_items:
			_profile.add_item(str(item.get("label", item.get("id", "Profile"))))
			_profile.set_item_metadata(_profile.item_count - 1, str(item.get("id", "")))
	var selected := str(_state.get("configuration", {}).get("profile", "classic"))
	_profile_description.text = "Edited optical settings. Save a named copy to revisit this composition."
	_profile.select(-1)
	for index: int in _profile_items.size():
		if str(_profile_items[index].get("id", "")) == selected:
			_profile.select(index)
			_profile_description.text = str(_profile_items[index].get("description", ""))
			break
	_delete_preset.disabled = not _is_custom(selected)
	_delete_preset.tooltip_text = "Only a selected custom preset can be removed. The current scene's optical settings remain in the scene."


func _refresh_plane() -> void:
	if _state.is_empty(): return
	var prior := _syncing
	_syncing = true
	var plane: Dictionary = _state.get("configuration", {}).get("planes", {}).get(_plane_id, {})
	var is_play := _plane_id == "play"
	_plane_participates.set_pressed_no_signal(bool(plane.get("participates", false)))
	_plane_participates.disabled = is_play
	_plane_note.text = "Play remains crisp and unprocessed. Its optical depth only locates the lens focus; it cannot alter the physical camera or edit coordinates." if is_play else "These settings affect only this decorative plane's presentation. Native material, collision, history and edit target are unchanged."
	if not is_play and float(plane.get("opacity",1.0)) <= 0.0:
		_plane_note.text += " Optical opacity is zero. Native editing permissions are unchanged; use Bypass before authoring invisible content."
	for key: String in _plane_controls:
		_set_number(_plane_controls[key], float(plane.get(key, 1.0)))
		_set_number_editable(_plane_controls[key], not is_play or key == "depth")
	_tint.color = _colour(plane.get("tint", [1.0,1.0,1.0]))
	_tint.disabled = is_play
	_syncing = prior


func _select_profile(index: int) -> void:
	if _syncing or index < 0 or index >= _profile_items.size(): return
	_commit_field()
	_invoke("select_optics_profile", [str(_profile_items[index].get("id", ""))])


func _save_named() -> void:
	_commit_field()
	var value := _preset_name.text.strip_edges()
	if value.is_empty():
		_status.text = "Enter a name before saving a copy of these optical settings."
		_preset_name.grab_focus()
		return
	_invoke("save_optics_preset", [value])


func _delete_selected() -> void:
	var id := str(_state.get("configuration", {}).get("profile", ""))
	if not _is_custom(id): return
	_invoke("delete_optics_preset", [id])


func _is_custom(id: String) -> bool:
	var presets: Variant = _state.get("custom_presets", [])
	if presets is Dictionary: return presets.has(id)
	if presets is Array:
		for item: Variant in presets:
			if item is Dictionary and str(item.get("id", "")) == id: return true
			if item is String and item == id: return true
	return false


func _global_patch(patch: Dictionary) -> void:
	if not _syncing: _invoke("set_optics", [patch])


func _plane_patch(patch: Dictionary) -> void:
	if _syncing: return
	# The backend is authoritative, but the UI must not offer a bypass either.
	if _plane_id == "play" and (patch.size() != 1 or not patch.has("depth")): return
	_invoke("set_plane_optics", [_plane_id, patch])


func _inspect(patch: Dictionary) -> void:
	if not _syncing: _invoke("set_optics_inspection", [patch])


func _add_global(parent: Control, key: String, title: String, low: float, high: float, step: float, hint: String) -> void:
	_global_controls[key] = _number(parent, title, low, high, step, hint,
		func(value: float) -> void: _global_patch({key:value}))


func _add_plane(parent: Control, key: String, title: String, low: float, high: float, step: float, hint: String) -> void:
	_plane_controls[key] = _number(parent, title, low, high, step, hint,
		func(value: float) -> void: _plane_patch({key:value}))


func _number(parent: Control, title: String, low: float, high: float, step: float, hint: String, action: Callable) -> Dictionary:
	var column := VBoxContainer.new()
	parent.add_child(column)
	var caption := Label.new()
	caption.text = title
	caption.tooltip_text = hint
	column.add_child(caption)
	var row := HBoxContainer.new()
	column.add_child(row)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = hint
	row.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.custom_minimum_size.x = 105
	spin.tooltip_text = hint
	row.add_child(spin)
	slider.value_changed.connect(func(value: float) -> void:
		spin.set_value_no_signal(value)
		if not _syncing: action.call(value))
	spin.value_changed.connect(func(value: float) -> void:
		slider.set_value_no_signal(value)
		if not _syncing: action.call(value))
	return {"slider":slider,"spin":spin,"label":caption}


func _set_number(control: Dictionary, value: float) -> void:
	var spin: SpinBox = control.spin
	if spin.get_line_edit().has_focus(): return
	spin.set_value_no_signal(value)
	(control.slider as HSlider).set_value_no_signal(value)


func _set_number_editable(control: Dictionary, value: bool) -> void:
	(control.spin as SpinBox).editable = value
	(control.slider as HSlider).editable = value


func _commit_field() -> void:
	if not is_inside_tree(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit and focus.get_parent() is SpinBox: focus.get_parent().apply()


func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	parent.add_child(label)


func _note(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)


func _button(parent: Control, title: String, hint: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _colour(value: Variant) -> Color:
	if value is Array and value.size() >= 3: return Color(float(value[0]),float(value[1]),float(value[2]),1.0)
	return Color.WHITE


func _invoke(method: String, args: Array = []) -> Variant:
	if controller == null or not controller.has_method(method):
		_status.text = "This optical action is unavailable: " + method
		return null
	return controller.callv(method, args)


func _dict_call(method: String) -> Dictionary:
	var result: Variant = _invoke(method)
	return result if result is Dictionary else {}


func _array_call(method: String) -> Array:
	var result: Variant = _invoke(method)
	return result if result is Array else []
