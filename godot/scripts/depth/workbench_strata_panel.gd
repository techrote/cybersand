extends PanelContainer

# Presentation and authoring requests go through the Workbench mediator. This
# panel has no references to native Worlds, texture packets or physics bodies.
const IDS: Array[String] = ["play", "scripted", "effects", "background"]
const NAMES: Array[String] = ["Play · actors and collision", "Rear architecture", "Atmosphere / effects", "Background"]
const DEMOS: Array[String] = ["industrial-assembly", "arcology", "cavern"]
const AuthoringPanel = preload("res://scripts/depth/workbench_strata_authoring_panel.gd")
const OpticsPanel = preload("res://scripts/depth/workbench_strata_optics_panel.gd")
var controller: Node
var _syncing: bool = false
var _active := OptionButton.new()
var _enabled := CheckButton.new()
var _mode := OptionButton.new()
var _visible := CheckBox.new()
var _locked := CheckBox.new()
var _solo := CheckBox.new()
var _opacity := HSlider.new()
var _depth := HSlider.new()
var _parallax := HSlider.new()
var _fog := HSlider.new()
var _target := Label.new()
var _clock := Label.new()
var _status := Label.new()
var _demo := OptionButton.new()
var _values: Dictionary = {}
var _tabs := TabContainer.new()
var _authoring: Node
var _optics: Node
var _demo_ids: Array[String] = []
var _scene_description := Label.new()

func mount(mediator: Node) -> void:
	controller = mediator
	name = "StrataTheatrePanel"
	custom_minimum_size = Vector2(390, 0)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)
	var heading := Label.new()
	heading.text = "STRATA THEATRE"
	heading.add_theme_font_size_override("font_size", 19)
	outer.add_child(heading)
	_tabs.custom_minimum_size = Vector2(540, 420)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_tabs)
	var rows := _page("Layers")
	_enabled.text = "Layered presentation"
	_enabled.tooltip_text = "Switch the view without resetting the current play scene."
	_enabled.toggled.connect(func(value: bool) -> void: _presentation({"enabled":value}))
	rows.add_child(_enabled)
	_mode.add_item("Stack · all visible planes")
	_mode.add_item("Flat · selected plane")
	_mode.item_selected.connect(func(index: int) -> void: _presentation({"mode":"stack" if index == 0 else "flat"}))
	rows.add_child(_mode)
	_target.add_theme_color_override("font_color", Color("91f3d0"))
	_target.add_theme_font_size_override("font_size", 16)
	rows.add_child(_target)
	for title: String in NAMES: _active.add_item(title)
	_active.item_selected.connect(func(index: int) -> void: _presentation({"active":IDS[index]}))
	rows.add_child(_active)
	var visibility := HBoxContainer.new()
	rows.add_child(visibility)
	_visible.text = "Visible"
	_locked.text = "Locked"
	_solo.text = "Solo"
	visibility.add_child(_visible)
	visibility.add_child(_locked)
	visibility.add_child(_solo)
	_visible.toggled.connect(func(value: bool) -> void: _layer({"visible":value}))
	_locked.toggled.connect(func(value: bool) -> void: _layer({"locked":value}))
	_solo.toggled.connect(func(value: bool) -> void: _presentation({"solo":IDS[_active.selected] if value else ""}))
	_slider(rows, "Opacity", _opacity, 0.0, 1.0, 0.05, func(value: float) -> void: _layer({"opacity":value}))
	_slider(rows, "Relative depth", _depth, 0.0, 1.0, 0.05, func(value: float) -> void: _layer({"depth":value}))
	_slider(rows, "Parallax strength", _parallax, 0.0, 2.0, 0.05, func(value: float) -> void: _presentation({"parallax_strength":value}))
	_slider(rows, "Distance haze", _fog, 0.0, 1.0, 0.05, func(value: float) -> void: _presentation({"fog_strength":value}))
	_clock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_clock)
	var history := HBoxContainer.new()
	rows.add_child(history)
	_button(history, "Undo selected plane", "undo_layer")
	_button(history, "Redo selected plane", "redo_layer")
	var note := Label.new()
	note.text = "Use the ordinary brush or eraser on the selected plane. Hidden, solo-excluded and locked planes do not receive edits while layered presentation is enabled. Switching it off restores ordinary Play editing; stored layer settings apply when enabled again. Rear planes stay still; play remains live."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("b4c1cc"))
	rows.add_child(note)
	_button(rows, "Reset presentation settings", "reset_presentation")
	_button(rows, "Fit scene in the ordinary camera", "fit_scene")
	_authoring = AuthoringPanel.new()
	add_child(_authoring)
	_authoring.mount(controller, _tabs)
	var scene_rows := _page("Scenes")
	var demo_label := Label.new()
	demo_label.text = "Open a complete example scene"
	scene_rows.add_child(demo_label)
	var catalogue: Array = []
	if controller != null and controller.has_method("scene_catalogue"): catalogue = controller.call("scene_catalogue")
	if catalogue.is_empty():
		for i: int in DEMOS.size():
			catalogue.append({"id":DEMOS[i],"label":["Industrial assembly hall", "Science-fiction arcology", "Organic / industrial cavern"][i],"description":"Native four-plane reference scene, 1024 × 768."})
	for entry: Dictionary in catalogue:
		_demo_ids.append(str(entry.get("id", "")))
		_demo.add_item(str(entry.get("label", entry.get("name", entry.get("id", "Scene")))))
		_demo.set_item_metadata(_demo.item_count - 1, str(entry.get("description", "")))
	scene_rows.add_child(_demo)
	_scene_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_rows.add_child(_scene_description)
	_demo.item_selected.connect(func(index: int) -> void: _scene_description.text = str(_demo.get_item_metadata(index)))
	if _demo.item_count > 0: _scene_description.text = str(_demo.get_item_metadata(0))
	var demo_button := Button.new()
	demo_button.text = "Load selected example…"
	demo_button.tooltip_text = "Loads a new authored scene, including its play layout and actor. Save your current scene first."
	demo_button.pressed.connect(func() -> void:
		if controller != null and _demo.selected >= 0 and _demo.selected < _demo_ids.size(): controller.call("load_demo", _demo_ids[_demo.selected]))
	scene_rows.add_child(demo_button)
	_button(scene_rows, "Fit loaded scene", "fit_scene")
	var scene_note := Label.new()
	scene_note.text = "Loading replaces the authored scene through the ordinary Workbench. Save existing work first. Stack / Flat and atmosphere switches preserve the current Play World; a complete scene load deliberately installs a new authored start."
	scene_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_rows.add_child(scene_note)
	# Append to preserve established Layers/Import/Parts/Atmosphere/Scenes routes.
	_optics = OpticsPanel.new()
	add_child(_optics)
	_optics.mount(controller,_tabs)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("cad5e0"))
	outer.add_child(_status)
	if controller != null and controller.has_method("document"):
		refresh(controller.call("document"))

func refresh(document: Dictionary, status: String = "") -> void:
	if document.is_empty():
		_status.text = status
		return
	_syncing = true
	var settings: Dictionary = document.get("presentation", {})
	var active: String = str(settings.get("active", "play"))
	var index: int = maxi(0, IDS.find(active))
	_active.select(index)
	_enabled.set_pressed_no_signal(bool(settings.get("enabled", false)))
	_mode.select(0 if str(settings.get("mode", "stack")) == "stack" else 1)
	var plane := {}
	for entry: Dictionary in document.get("planes", []):
		if str(entry.get("id", "")) == active: plane = entry
	_visible.set_pressed_no_signal(bool(plane.get("visible", true)))
	_locked.set_pressed_no_signal(bool(plane.get("locked", false)))
	_solo.set_pressed_no_signal(str(settings.get("solo", "")) == active)
	_opacity.set_value_no_signal(float(plane.get("opacity", 1.0)))
	_depth.set_value_no_signal(float(plane.get("depth", 0.0)))
	_parallax.set_value_no_signal(float(settings.get("parallax_strength", 0.75)))
	_fog.set_value_no_signal(float(settings.get("fog_strength", 0.20)))
	_depth.editable = active != "play"
	_depth.tooltip_text = "Play stays aligned with actors and collision." if active == "play" else "Changes parallax and distance haze; material pixels keep their size."
	for slider: HSlider in [_opacity, _depth, _parallax, _fog]:
		(_values[slider] as Label).text = "%.2f" % slider.value
	var effective_name: String = active if _enabled.button_pressed else "play"
	_target.text = "EDIT TARGET: " + effective_name.to_upper()
	if not _enabled.button_pressed: _target.text += "  ·  layered view off"
	elif _locked.button_pressed: _target.text += "  ·  LOCKED"
	elif not _visible.button_pressed or _opacity.value <= 0.0: _target.text += "  ·  HIDDEN"
	elif not str(settings.get("solo", "")).is_empty() and str(settings.solo) != active: _target.text += "  ·  EXCLUDED BY SOLO"
	_clock.text = "Clock: ordinary play simulation. Actors and collision live on this plane." if effective_name == "play" else "Clock: static · 0 Hz · paused. Painting changes this plane; it has no actors or cross-plane collisions."
	_status.text = status
	_syncing = false
	if is_instance_valid(_authoring): _authoring.refresh(document, status)
	if is_instance_valid(_optics): _optics.refresh(document,status)

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	return rows


func refresh_optics(document: Dictionary, status: String = "") -> void:
	_status.text = status
	if is_instance_valid(_optics): _optics.refresh(document,status)

func _slider(parent: Control, caption: String, slider: HSlider, low: float, high: float,
		step: float, action: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 130
	row.add_child(label)
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size.x = 38
	row.add_child(value)
	_values[slider] = value
	slider.value_changed.connect(func(number: float) -> void:
		value.text = "%.2f" % number
		if not _syncing: action.call(number))

func _button(parent: Control, caption: String, method: String) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		if controller != null: controller.call(method))
	parent.add_child(button)

func _presentation(patch: Dictionary) -> void:
	if not _syncing and controller != null: controller.call("set_presentation", patch)

func _layer(patch: Dictionary) -> void:
	if not _syncing and controller != null: controller.call("set_layer_settings", IDS[_active.selected], patch)
