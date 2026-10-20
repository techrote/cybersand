extends Control

const Map = preload("res://scripts/exhibition/deepworks_map.gd")
const Runtime = preload("res://scripts/exhibition/deepworks_runtime.gd")
const DepthCompositor = preload("res://scripts/depth/depth_compositor.gd")
const Cell = preload("res://scripts/cell_world.gd")
const MODES: Array[String] = ["flat", "relief", "stack", "hybrid", "diorama"]
const MATERIALS: Array[int] = [Cell.WATER, Cell.SAND, Cell.ACID, Cell.SPARK, Cell.FIRE,
	Cell.LAVA, Cell.SALT, Cell.STEAM, Cell.BRINE, Cell.OIL, Cell.PACKED_SNOW,
	Cell.THERMITE_BRICK, Cell.MAGNESIUM_PLATE, Cell.QUICKLIME_BLOCK, Cell.WALL]
const MATERIAL_LABELS: Array[String] = ["Water", "Sand", "Acid", "Spark", "Fire", "Lava",
	"Salt", "Steam", "Brine", "Oil", "Packed snow", "Thermite brick", "Magnesium plate", "Quicklime block", "Wall"]
const ACCENT := Color(0.37, 0.86, 0.79)
const AMBER := Color(0.96, 0.64, 0.29)
const MUTED := Color(0.57, 0.67, 0.69)

var runtime: CyberDeepworksRuntime = Runtime.new()
var compositor: CyberDepthCompositor
var definition: Dictionary = {}
var paused: bool = true
var faulted: bool = false
var ui_ready: bool = false
var selected_district: int = 0
var presentation_time: float = 0.0
var mode_index: int = 3
var hud_visible: bool = true
var tour_enabled: bool = false

var _top: PanelContainer
var _side: PanelContainer
var _footer: Label
var _district_title: Label
var _district_description: Label
var _foreground_note: Label
var _rear_note: Label
var _status: Label
var _pause_button: Button
var _tour_button: Button
var _script_button: CheckBox
var _layer_picker: OptionButton
var _material_picker: OptionButton
var _mode_picker: OptionButton
var _district_buttons: Array[Button] = []
var _visibility_buttons: Array[CheckBox] = []
var _layer_visibility := Vector4.ONE
var _brush_radius: int = 2
var _dragging: bool = false
var _pointer_armed: bool = false
var _keys_armed: bool = false
var _tour_index: int = 0
var _tour_clock: float = 0.0
var _status_clock: float = 0.0
var _message: String = "P starts the exhibits. Choose a district to look closer."

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.018, 0.027, 0.032)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	compositor = DepthCompositor.new()
	compositor.name = "DepthCompositor"
	# Close parallax preserves district identity at all four world corners.
	compositor.layer_scale = Vector4.ONE
	compositor.layer_parallax = Vector4(1.0, 0.98, 0.965, 0.94)
	if not compositor.configure(Map.SIZE):
		faulted = true
		return
	add_child(compositor)
	compositor.mouse_filter = Control.MOUSE_FILTER_STOP
	compositor.gui_input.connect(_map_input)
	_build_ui()
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	resized.connect(_layout)
	ui_ready = true
	_layout()
	select_mode(3)
	reset_exhibition()
	show_overview()

func _process(delta: float) -> void:
	if not ui_ready or faulted:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_pointer_armed = not _modal_active()
		_dragging = false
	if not _pan_keys_down():
		_keys_armed = not _modal_active() and not _ui_has_focus()
	if _modal_active():
		_release_input()
	else:
		_pan(delta)
	if not paused:
		presentation_time += delta
		compositor.set_time(presentation_time)
		if tour_enabled:
			_tour_clock += delta
			if _tour_clock >= 14.0:
				_tour_clock = 0.0
				_tour_index = (_tour_index + 1) % Map.TOUR.size()
				select_district(Map.TOUR[_tour_index])
	var result: Dictionary = runtime.advance(delta, paused)
	if not bool(result.get("ok", false)):
		_fault(str(result.get("error", runtime.last_error)))
		return
	if not _publish_layers():
		return
	_status_clock += delta
	if _status_clock >= 0.25:
		_status_clock = 0.0
		_update_status()

func reset_exhibition() -> bool:
	if not ui_ready:
		return false
	_release_input()
	definition = Map.build()
	if not runtime.install(definition["layers"], definition["events"]):
		_fault(runtime.last_error)
		return false
	faulted = false
	paused = true
	presentation_time = 0.0
	_tour_clock = 0.0
	runtime.configure_rates({"play": 30.0, "scripted": 20.0, "effects": 15.0, "background": 0.0})
	_script_button.set_pressed_no_signal(true)
	compositor.set_time(0.0)
	compositor.set_options({"freeze_material_animation": true})
	if not _publish_layers(true):
		return false
	_refresh_district_notes()
	_message = "Fresh specimens installed in all sixteen districts. P starts the sources."
	_update_status()
	return true

func toggle_pause() -> void:
	if faulted:
		return
	paused = not paused
	compositor.set_options({"freeze_material_animation": paused})
	_message = "All exhibit clocks are paused." if paused else "Foreground, rear and atmosphere are running."
	_release_input()
	_update_status()

func step_once() -> void:
	if faulted:
		return
	paused = true
	compositor.set_options({"freeze_material_animation": true})
	var result: Dictionary = runtime.step_once()
	if not bool(result.get("ok", false)):
		_fault(runtime.last_error)
		return
	if not _publish_layers():
		return
	_message = "Advanced each active material plane by one native tick."
	_update_status()

func show_overview() -> void:
	if compositor == null:
		return
	compositor.set_view(Vector2.ZERO, Vector2(Map.SIZE))
	_release_input()
	_update_status()

func select_district(index: int) -> void:
	if index < 0 or index >= 16 or not ui_ready:
		return
	selected_district = index
	compositor.set_view(Vector2(Map.origin(index)), Vector2(256, 256))
	_refresh_district_notes()
	_release_input()
	_update_status()

func focus_exhibit(layer: String) -> void:
	for exhibit: Dictionary in definition.get("exhibits", []):
		if int(exhibit["district"]) != selected_district or exhibit["layer"] != layer:
			continue
		var focus: Vector2 = Vector2(exhibit["focus"])
		# Invert the layer's world-centred parallax for the new camera centre.
		var layer_index: int = Map.LAYERS.find(layer)
		var factor: float = 1.0 + (compositor.layer_parallax[layer_index] - 1.0) * 0.8
		var camera_centre: Vector2 = Vector2(Map.SIZE) * 0.5 + (focus - Vector2(Map.SIZE) * 0.5) / factor
		compositor.set_view(camera_centre - Vector2(100, 100), Vector2(200, 200))
		_message = str(exhibit["title"])
		_release_input()
		_update_status()
		return

func select_mode(index: int) -> void:
	if index < 0 or index >= MODES.size() or compositor == null:
		return
	mode_index = index
	compositor.set_options({"mode": MODES[index], "parallax_strength": 0.8,
		"relief_depth": 5.0, "relief_slices": 4, "relief_quantization": 1.0,
		"fog_strength": 0.46, "reflection_strength": 0.12,
		"occluder_strength": 0.30, "cutaway": true,
		"cutaway_radius": 100.0, "layer_visibility": _layer_visibility})
	if _mode_picker != null:
		_mode_picker.select(index)

func set_hud_visible(enabled: bool) -> void:
	hud_visible = enabled
	_top.visible = enabled
	_side.visible = enabled
	_footer.visible = enabled
	_release_input()
	_layout()

func set_layer_visible(index: int, enabled: bool) -> void:
	if index < 0 or index >= 4:
		return
	_layer_visibility[index] = 1.0 if enabled else 0.0
	_visibility_buttons[index].set_pressed_no_signal(enabled)
	compositor.set_options({"layer_visibility": _layer_visibility})

func toggle_tour() -> void:
	tour_enabled = not tour_enabled
	_tour_clock = 0.0
	if tour_enabled:
		_tour_index = maxi(0, Map.TOUR.find(selected_district))
		select_district(Map.TOUR[_tour_index])
		if paused:
			toggle_pause()
	_tour_button.text = "Stop tour  /  T" if tour_enabled else "Guided tour  /  T"
	_update_status()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _modal_active():
		return
	match event.keycode:
		KEY_P, KEY_SPACE: toggle_pause()
		KEY_R: reset_exhibition()
		KEY_N: step_once()
		KEY_O, KEY_HOME: show_overview()
		KEY_T: toggle_tour()
		KEY_F8, KEY_TAB: set_hud_visible(not hud_visible)
		KEY_BRACKETLEFT: select_district(posmod(selected_district - 1, 16))
		KEY_BRACKETRIGHT: select_district((selected_district + 1) % 16)
		KEY_1: select_mode(0)
		KEY_2: select_mode(1)
		KEY_3: select_mode(2)
		KEY_4: select_mode(3)
		KEY_5: select_mode(4)
		KEY_ESCAPE: get_tree().change_scene_to_file("res://feature_launcher.tscn")
		_: return
	get_viewport().set_input_as_handled()

func _map_input(event: InputEvent) -> void:
	if faulted or not ui_ready or _modal_active():
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] and _ui_has_focus():
			# A fresh map click returns keyboard ownership to the world. Keys
			# held from the UI remain disarmed until their release is observed.
			get_viewport().gui_release_focus()
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed and _pointer_armed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom(event.position, 0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25)
		elif event.pressed and _pointer_armed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_apply_pointer(event.position, event.button_index == MOUSE_BUTTON_RIGHT)
	elif event is InputEventMouseMotion:
		var point: Vector2 = compositor.screen_to_layer(event.position, 0)
		compositor.set_options({"focus_position": point})
		if _dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var rect: Rect2 = compositor.content_rect()
			compositor.set_camera(compositor.camera_origin - event.relative / rect.size * compositor.view_size)
		elif _pointer_armed:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_apply_pointer(event.position, true)
			elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_apply_pointer(event.position, false)

func _apply_pointer(local_position: Vector2, erase: bool) -> void:
	var layer_index: int = _layer_picker.selected
	var position_in_world: Vector2 = compositor.screen_to_layer(local_position, layer_index)
	if position_in_world.x < 0.0:
		return
	var material: int = Cell.EMPTY if erase else MATERIALS[_material_picker.selected]
	var receipt: Dictionary = runtime.paint_disc(Map.LAYERS[layer_index], Vector2i(position_in_world.floor()), _brush_radius, material)
	if bool(receipt.get("accepted", false)):
		var advanced: Dictionary = runtime.advance(0.0, true)
		if not bool(advanced.get("ok", false)):
			_fault(runtime.last_error)
			return
		if not _publish_layers():
			return
		_message = "%s on %s." % ["Erased" if erase else MATERIAL_LABELS[_material_picker.selected], "foreground" if layer_index == 0 else "rear apparatus"]
	else:
		_message = "Edit: " + str(receipt.get("error", "refused"))

func _zoom(local_position: Vector2, multiplier: float) -> void:
	var rect: Rect2 = compositor.content_rect()
	if not rect.has_point(local_position):
		return
	var uv: Vector2 = (local_position - rect.position) / rect.size
	var point: Vector2 = compositor.camera_origin + uv * compositor.view_size
	var next_size: float = clampf(compositor.view_size.x * multiplier, 128.0, 1024.0)
	compositor.set_view(point - uv * next_size, Vector2.ONE * next_size)
	tour_enabled = false
	_tour_button.text = "Guided tour  /  T"

func _pan(delta: float) -> void:
	if not _keys_armed or _ui_has_focus():
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1
	if direction != Vector2.ZERO:
		compositor.set_camera(compositor.camera_origin + direction.normalized() * delta * compositor.view_size.x * 0.55)

func _pan_keys_down() -> bool:
	for key: int in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		if Input.is_key_pressed(key): return true
	return false

func _modal_active() -> bool:
	for picker: OptionButton in [_layer_picker, _material_picker, _mode_picker]:
		if picker != null and picker.get_popup().visible: return true
	return false

func _ui_has_focus() -> bool:
	var control: Control = get_viewport().gui_get_focus_owner()
	return control != null and is_ancestor_of(control)

func _on_gui_focus_changed(control: Control) -> void:
	# Focus can enter and leave between host frames. Cancel held input at the
	# signal boundary as well as checking focus while polling movement keys.
	if control != null and is_ancestor_of(control):
		_release_input()

func _release_input() -> void:
	_pointer_armed = false
	_keys_armed = false
	_dragging = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_input()

func _publish_layers(force: bool = false) -> bool:
	for id: String in Map.LAYERS:
		var packet: Dictionary = runtime.snapshot_layer(id, force)
		if bool(packet.get("failed", false)):
			_fault(str(packet.get("error", "Native publication failed")))
			return false
		if force or not PackedByteArray(packet.get("cells", PackedByteArray())).is_empty():
			if not compositor.apply_layer_packet(id, packet):
				_fault("Material surface refused " + id)
				return false
	return true

func _fault(message: String) -> void:
	faulted = true
	paused = true
	if compositor != null:
		compositor.set_options({"freeze_material_animation": true})
	_message = "Exhibition stopped: " + message
	push_error(_message)
	_update_status()

func _refresh_district_notes() -> void:
	_district_title.text = "%s / %s" % [Map.district_code(selected_district), Map.TITLES[selected_district]]
	_district_description.text = Map.DESCRIPTIONS[selected_district]
	for i: int in range(16):
		_district_buttons[i].set_pressed_no_signal(i == selected_district)
	for exhibit: Dictionary in definition.get("exhibits", []):
		if int(exhibit["district"]) == selected_district:
			var label: Label = _foreground_note if exhibit["layer"] == "play" else _rear_note
			label.text = str(exhibit["title"]) + "\n" + str(exhibit["description"])

func _build_ui() -> void:
	_top = PanelContainer.new()
	_top.name = "ExhibitionHeader"
	_top.add_theme_stylebox_override("panel", _panel(Color(0.035, 0.058, 0.065)))
	add_child(_top)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 24)
	_top.add_child(heading)
	var name_box := VBoxContainer.new()
	name_box.custom_minimum_size = Vector2(260, 50)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(name_box)
	var title: Label = _label(name_box, "DEEPWORKS", 28, ACCENT)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var subtitle: Label = _label(name_box, "THE EXHIBITION BELOW / 1024 × 1024", 12, MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pause_button = _button(heading, "Run exhibits  /  P", toggle_pause)
	_button(heading, "Step  /  N", step_once)
	_button(heading, "Fresh reset  /  R", reset_exhibition)
	_button(heading, "Hide  /  F8", func(): set_hud_visible(false))
	for control: Control in heading.get_children():
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_side = PanelContainer.new()
	_side.name = "ExhibitionGuide"
	_side.add_theme_stylebox_override("panel", _panel(Color(0.030, 0.048, 0.054)))
	add_child(_side)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	_label(column, "16 DISTRICTS / ONE COMPLEX", 13, AMBER)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	column.add_child(grid)
	for index: int in range(16):
		var button: Button = _button(grid, Map.district_code(index), select_district.bind(index))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(55, 34)
		button.tooltip_text = Map.TITLES[index]
		_district_buttons.append(button)
	var navigation := HBoxContainer.new()
	column.add_child(navigation)
	_button(navigation, "Overview / O", show_overview)
	_tour_button = _button(navigation, "Guided tour / T", toggle_tour)
	_district_title = _label(column, "", 20, ACCENT)
	_district_description = _label(column, "", 13, Color(0.79, 0.83, 0.79))
	column.add_child(HSeparator.new())
	_label(column, "FOREGROUND EXHIBIT", 12, AMBER)
	_foreground_note = _label(column, "", 13, Color(0.84, 0.85, 0.80))
	_button(column, "Inspect foreground setup", focus_exhibit.bind("play"))
	_label(column, "BEHIND THE GALLERY", 12, ACCENT)
	_rear_note = _label(column, "", 13, Color(0.70, 0.78, 0.78))
	_button(column, "Inspect rear setup", focus_exhibit.bind("scripted"))
	column.add_child(HSeparator.new())
	_script_button = CheckBox.new()
	_script_button.text = "Automatic material sources"
	_script_button.button_pressed = true
	_script_button.focus_mode = Control.FOCUS_NONE
	_script_button.toggled.connect(func(enabled: bool): runtime.scripts_enabled = enabled)
	column.add_child(_script_button)
	_label(column, "LAYER VISIBILITY", 12, AMBER)
	var layer_labels: Array[String] = ["Foreground", "Rear reactions & machinery", "Atmosphere", "Distant architecture"]
	for index: int in range(4):
		var check := CheckBox.new()
		check.text = layer_labels[index]
		check.button_pressed = true
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(func(enabled: bool): set_layer_visible(index, enabled))
		column.add_child(check)
		_visibility_buttons.append(check)
	_mode_picker = OptionButton.new()
	for label: String in ["1 · Foreground only", "2 · Quantized relief", "3 · Four material layers", "4 · Hybrid depth", "5 · Diorama cutaway"]:
		_mode_picker.add_item(label)
	_mode_picker.item_selected.connect(select_mode)
	column.add_child(_mode_picker)
	_label(column, "TRY YOUR OWN REACTION", 12, AMBER)
	_layer_picker = OptionButton.new()
	_layer_picker.add_item("Paint foreground")
	_layer_picker.add_item("Paint rear apparatus")
	column.add_child(_layer_picker)
	_material_picker = OptionButton.new()
	for label: String in MATERIAL_LABELS: _material_picker.add_item(label)
	column.add_child(_material_picker)
	var brush := HSlider.new()
	brush.min_value = 1
	brush.max_value = 8
	brush.step = 1
	brush.value = _brush_radius
	brush.value_changed.connect(func(value: float): _brush_radius = int(value))
	column.add_child(brush)
	_label(column, "Left: add material · Right: erase\nMiddle-drag / WASD: pan · Wheel: zoom\n[ / ]: previous / next district · F2: launcher", 12, MUTED)
	_status = _label(column, "", 12, ACCENT)
	_footer = Label.new()
	_footer.text = "4 MATERIAL WORLDS   /   32 WORKING EXHIBITS   /   P TO RUN   ·   F8 CLEAN VIEW"
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.modulate = MUTED
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_footer)
	# Containers settle their text minimums after entering the tree. Size the
	# fixed header again once that happens, without an autowrap feedback loop.
	_layout.call_deferred()

func _panel(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = Color(0.14, 0.24, 0.25)
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _label(parent: Node, text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 32
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _layout() -> void:
	if not ui_ready:
		return
	if not hud_visible:
		compositor.position = Vector2.ZERO
		compositor.size = size
		return
	var sidebar_width: float = 290.0 if size.x < 1300.0 else 320.0
	_top.position = Vector2(12, 10)
	_top.size = Vector2(maxf(640.0, size.x - 24.0), 78)
	_side.position = Vector2(size.x - sidebar_width - 12, 98)
	_side.size = Vector2(sidebar_width, maxf(180.0, size.y - 110))
	compositor.position = Vector2(12, 98)
	compositor.size = Vector2(maxf(320.0, size.x - sidebar_width - 36), maxf(180.0, size.y - 130))
	_footer.position = Vector2(16, size.y - 26)
	_footer.size = Vector2(maxf(320.0, size.x - sidebar_width - 36), 20)

func _update_status() -> void:
	if _status == null:
		return
	_pause_button.text = "Run exhibits / P" if paused else "Pause / P"
	var events: Dictionary = runtime.event_stats()
	_status.text = "%s\n%s · %d source pulses\nFore %d  /  Rear %d  /  Air %d" % [
		_message, "PAUSED" if paused else "RUNNING", int(events["applications"]),
		runtime.layer_tick("play"), runtime.layer_tick("scripted"), runtime.layer_tick("effects")]
