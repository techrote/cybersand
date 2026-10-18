extends Control

const Runtime = preload("res://scripts/depth/depth_layer_runtime.gd")
const DepthCompositor = preload("res://scripts/depth/depth_compositor.gd")
const Fixture = preload("res://scripts/depth/depth_lab_fixture.gd")
const Cell = preload("res://scripts/cell_world.gd")

const MODES: Array[String] = ["flat", "relief", "stack", "hybrid", "diorama"]
const MODE_LABELS: Array[String] = ["1  Flat", "2  Quantized relief", "3  Four layers", "4  Hybrid", "5  Diorama"]
const MODE_NOTES: Array[String] = [
	"Foreground-only control.",
	"Foreground-derived quantized pseudo-Z; no extra simulation authority.",
	"Play + rear set + weather + frozen far city.",
	"Independent worlds plus relief, haze and liquid-masked rear reflection.",
	"Hybrid plus a faster near-camera silhouette and pointer cutaway.",
]
const LAYERS: Array[String] = ["play", "scripted", "effects", "background"]
const PAINT_MATERIALS: Array[int] = [
	Cell.SAND, Cell.WATER, Cell.WALL, Cell.SMOKE, Cell.FIRE, Cell.LAVA,
	Cell.STEAM, Cell.DUST, Cell.SPARK, Cell.NEON_CYAN, Cell.NEON_MAGENTA,
]
const PAINT_LABELS: Array[String] = [
	"Sand", "Water", "Wall", "Smoke", "Fire", "Lava",
	"Steam", "Dust", "Spark", "Neon cyan", "Neon magenta",
]

var runtime: CyberDepthLayerRuntime = Runtime.new()
var compositor: CyberDepthCompositor
var paused: bool = false
var camera_origin: Vector2 = Vector2(80, 45)
var presentation_time: float = 0.0
var mode_index: int = 3
var ui_ready: bool = false
var faulted: bool = false

var _auto_pan: bool = false
var _labels_enabled: bool = true
var _left_held: bool = false
var _right_held: bool = false
var _sequence_phase: int = -1
var _sequence_elapsed: float = 0.0
var _active_layer: int = 0
var _active_material: int = 0
var _brush_radius: int = 5
var _last_receipt: String = "Ready."
var _mode_buttons: Array[Button] = []
var _layer_buttons: Array[CheckBox] = []
var _layer_paused: Array[bool] = [false, false, false]
var _layer_visibility: Vector4 = Vector4.ONE
var _sliders: Dictionary = {}
var _status: Label
var _mode_note: Label
var _side_panel: PanelContainer
var _pause_button: Button
var _weather_select: OptionButton
var _layer_select: OptionButton
var _material_select: OptionButton
var _labels: Control

func _ready() -> void:
	set_process_unhandled_key_input(true)
	set_process_input(true)
	_build_ui()
	compositor = DepthCompositor.new()
	compositor.name = "DepthCompositor"
	compositor.position = Vector2(12, 72)
	compositor.size = Vector2(maxf(640.0, size.x - 346.0), maxf(360.0, size.y - 88.0))
	compositor.configure()
	add_child(compositor)
	move_child(compositor, 0)
	resized.connect(_layout)
	ui_ready = true
	_layout()
	select_mode(mode_index)
	reset_lab()

func _process(delta: float) -> void:
	if faulted or not ui_ready:
		return
	presentation_time += delta
	compositor.set_time(presentation_time)
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if pan.length_squared() > 0.0:
		set_camera_origin(camera_origin + pan.normalized() * delta * 130.0)
	elif _auto_pan:
		set_camera_origin(Vector2(80.0 + sin(presentation_time * 0.42) * 68.0, 45.0 + cos(presentation_time * 0.31) * 16.0))
	if _sequence_phase >= 0:
		_advance_sequence(delta)
	var result: Dictionary = runtime.advance(delta, paused)
	if not bool(result.get("ok", false)):
		faulted = true
		_last_receipt = str(result.get("error", runtime.last_error))
	_publish_layers()
	_update_status()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_KP_1: select_mode(0)
		KEY_2, KEY_KP_2: select_mode(1)
		KEY_3, KEY_KP_3: select_mode(2)
		KEY_4, KEY_KP_4: select_mode(3)
		KEY_5, KEY_KP_5: select_mode(4)
		KEY_SPACE: toggle_pause()
		KEY_E: run_reactor_sequence()
		KEY_R: reset_lab()
		KEY_TAB:
			_side_panel.visible = not _side_panel.visible
			_layout()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://main.tscn")
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not ui_ready or compositor == null:
		return
	if event is InputEventMouseMotion:
		compositor.set_options({"focus_position": camera_origin + _screen_to_logical(event.position)})
		if _left_held or _right_held:
			_apply_pointer(event.position, _right_held)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_left_held = event.pressed
			if event.pressed:
				_apply_pointer(event.position, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_right_held = event.pressed
			if event.pressed:
				_apply_pointer(event.position, true)
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			_auto_pan = not _auto_pan

func reset_lab() -> bool:
	if not ui_ready:
		return false
	_sequence_phase = -1
	_left_held = false
	_right_held = false
	faulted = not runtime.reset(Fixture.build())
	if faulted:
		_last_receipt = "Native lab could not start: " + str(runtime.last_error)
		_update_status()
		return false
	for index: int in range(3):
		runtime.set_layer_paused(LAYERS[index], _layer_paused[index])
	_select_weather(_weather_select.selected)
	presentation_time = 0.0
	compositor.set_time(presentation_time)
	_publish_layers(true)
	_last_receipt = "Theatre reset. Far city baked; nearer worlds can evolve."
	_update_status()
	return true

func select_mode(index: int) -> void:
	if index < 0 or index >= MODES.size():
		return
	mode_index = index
	if not ui_ready:
		return
	var options: Dictionary = {"mode": MODES[index], "layer_visibility": _layer_visibility}
	for key: String in _sliders:
		options[key] = (_sliders[key] as HSlider).value
	compositor.set_options(options)
	_mode_note.text = MODE_NOTES[index]
	for current: int in range(_mode_buttons.size()):
		_mode_buttons[current].set_pressed_no_signal(current == index)

func toggle_pause() -> void:
	paused = not paused
	compositor.set_options({"freeze_material_animation": paused})
	_pause_button.text = "Resume  /  Space" if paused else "Pause  /  Space"
	_last_receipt = "Simulation paused." if paused else "Simulation resumed."

func run_reactor_sequence() -> void:
	if faulted:
		return
	_sequence_phase = 0
	_sequence_elapsed = 0.0
	_last_receipt = "Rear reactor sequence armed. Play-plane authority remains separate."

func set_camera_origin(value: Vector2) -> void:
	camera_origin = value
	compositor.set_camera(camera_origin)
	camera_origin = compositor.camera_origin

func _set_auto_pan(enabled: bool) -> void:
	_auto_pan = enabled

func _set_labels(enabled: bool) -> void:
	_labels_enabled = enabled
	if _labels != null:
		_labels.visible = enabled

func _publish_layers(force: bool = false) -> void:
	if compositor == null:
		return
	for id: String in LAYERS:
		var packet: Dictionary = runtime.snapshot_layer(id, force)
		var cells: PackedByteArray = packet.get("cells", PackedByteArray())
		if force or not cells.is_empty():
			if not compositor.apply_layer_packet(id, packet):
				_last_receipt = "%s render packet refused." % id

func _advance_sequence(delta: float) -> void:
	_sequence_elapsed += delta
	var target: Vector2i = Fixture.features()["reactor_target"]
	var radius: int = int(Fixture.features()["reactor_radius"])
	if _sequence_phase == 0:
		runtime.scripted_blast(target + Vector2i(-13, 0), radius / 2)
		_sequence_phase = 1
	elif _sequence_phase == 1 and _sequence_elapsed >= 0.34:
		runtime.scripted_blast(target + Vector2i(10, -8), radius * 2 / 3)
		_sequence_phase = 2
	elif _sequence_phase == 2 and _sequence_elapsed >= 0.68:
		runtime.scripted_blast(target + Vector2i(2, 12), radius)
		_sequence_phase = 3
	elif _sequence_phase == 3 and _sequence_elapsed >= 0.92:
		runtime.route_event("scripted", "effects", "burst", target, 10, Cell.SPARK, runtime.generation())
		_sequence_phase = -1
		_last_receipt = "Rear set breached; effects burst routed. Play plane untouched."

func _apply_pointer(screen_position: Vector2, erase: bool) -> void:
	if _side_panel != null and _side_panel.get_global_rect().has_point(screen_position):
		return
	var local_position: Vector2 = screen_position - compositor.position
	var world_position: Vector2 = compositor.screen_to_layer(local_position, _active_layer)
	if world_position.x < 0.0:
		return
	var material: int = Cell.EMPTY if erase else PAINT_MATERIALS[_active_material]
	var receipt: Dictionary = runtime.paint_disc(LAYERS[_active_layer], Vector2i(floori(world_position.x), floori(world_position.y)), _brush_radius, material)
	if not bool(receipt.get("accepted", false)):
		_last_receipt = "Edit refused: " + str(receipt.get("error", "unknown"))
	else:
		runtime.advance(0.0, true)
		_publish_layers()
		_last_receipt = "%s edit queued on %s." % ["Erase" if erase else PAINT_LABELS[_active_material], LAYERS[_active_layer]]

func _screen_to_logical(screen_position: Vector2) -> Vector2:
	var local_position: Vector2 = screen_position - compositor.position
	var rect: Rect2 = compositor.content_rect()
	if not rect.has_point(local_position):
		return compositor.view_size * 0.5
	return (local_position - rect.position) / rect.size * compositor.view_size

func _build_ui() -> void:
	var title := Label.new()
	title.text = "STRATA THEATRE  ·  depth / layering prototype"
	title.position = Vector2(14, 10)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Four native material worlds + foreground-derived relief.  F4 opens from sandbox · Esc returns."
	subtitle.position = Vector2(15, 42)
	subtitle.modulate = Color(0.70, 0.82, 0.90)
	add_child(subtitle)

	_side_panel = PanelContainer.new()
	_side_panel.name = "Controls"
	add_child(_side_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	scroll.add_child(box)

	var modes_title := Label.new()
	modes_title.text = "COMPARISON MODES"
	box.add_child(modes_title)
	for index: int in range(MODES.size()):
		var button := Button.new()
		button.text = MODE_LABELS[index]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(select_mode.bind(index))
		box.add_child(button)
		_mode_buttons.append(button)
	_mode_note = Label.new()
	_mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_note.custom_minimum_size.y = 52
	box.add_child(_mode_note)

	_add_slider(box, "parallax_strength", "Parallax", 0.0, 2.0, 1.0, 0.05)
	_add_slider(box, "relief_depth", "Relief reach", 0.0, 32.0, 12.0, 1.0)
	_add_slider(box, "relief_slices", "Relief samples", 1.0, 8.0, 8.0, 1.0)
	_add_slider(box, "relief_quantization", "Relief quantization", 1.0, 8.0, 2.0, 1.0)
	_add_slider(box, "fog_strength", "Depth haze", 0.0, 1.0, 0.32, 0.02)
	_add_slider(box, "reflection_strength", "Liquid reflection", 0.0, 0.6, 0.18, 0.02)
	_add_slider(box, "occluder_strength", "Near-frame opacity", 0.0, 1.0, 0.8, 0.02)

	var separator := HSeparator.new()
	box.add_child(separator)
	var layer_title := Label.new()
	layer_title.text = "PLANES / TOOLS"
	box.add_child(layer_title)
	for index: int in range(LAYERS.size()):
		var check := CheckBox.new()
		check.text = "%s visible" % LAYERS[index].capitalize()
		check.button_pressed = true
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(_set_layer_visible.bind(index))
		box.add_child(check)
		_layer_buttons.append(check)

	_layer_select = OptionButton.new()
	for id: String in LAYERS:
		_layer_select.add_item("Paint: " + id)
	_layer_select.item_selected.connect(func(index: int): _active_layer = index)
	box.add_child(_layer_select)

	_material_select = OptionButton.new()
	for label: String in PAINT_LABELS:
		_material_select.add_item(label)
	_material_select.item_selected.connect(func(index: int): _active_material = index)
	box.add_child(_material_select)

	var radius_slider := HSlider.new()
	radius_slider.min_value = 1
	radius_slider.max_value = 24
	radius_slider.step = 1
	radius_slider.value = _brush_radius
	radius_slider.value_changed.connect(func(value: float): _brush_radius = int(value))
	box.add_child(_labeled("Brush radius", radius_slider))

	_weather_select = OptionButton.new()
	for mode: String in Runtime.WEATHER_MODES:
		_weather_select.add_item(Runtime.WEATHER_LABELS[mode])
	_weather_select.item_selected.connect(_select_weather)
	box.add_child(_weather_select)

	var sequence := Button.new()
	sequence.text = "Rear reactor sequence  /  E"
	sequence.focus_mode = Control.FOCUS_NONE
	sequence.pressed.connect(run_reactor_sequence)
	box.add_child(sequence)

	var forbidden := Button.new()
	forbidden.text = "Negative control: rear → play"
	forbidden.focus_mode = Control.FOCUS_NONE
	forbidden.pressed.connect(_attempt_forbidden_route)
	box.add_child(forbidden)

	var row := HBoxContainer.new()
	_pause_button = Button.new()
	_pause_button.text = "Pause  /  Space"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(toggle_pause)
	row.add_child(_pause_button)
	var step := Button.new()
	step.text = "Step"
	step.focus_mode = Control.FOCUS_NONE
	step.pressed.connect(_step_once)
	row.add_child(step)
	box.add_child(row)

	var reset := Button.new()
	reset.text = "Reset theatre  /  R"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(reset_lab)
	box.add_child(reset)
	var back := Button.new()
	back.text = "Return to sandbox  /  Esc"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	box.add_child(back)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 125
	box.add_child(_status)

	_labels = Control.new()
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels)
	var badge := Label.new()
	badge.text = "PLAY 01  ·  REAR SET 02  ·  WEATHER 03  ·  FAR CITY 04"
	badge.position = Vector2(20, 74)
	badge.modulate = Color(0.55, 0.95, 0.92)
	_labels.add_child(badge)

func _add_slider(parent: VBoxContainer, key: String, label_text: String, minimum: float, maximum: float, value: float, step: float) -> void:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(_value: float): select_mode(mode_index))
	_sliders[key] = slider
	parent.add_child(_labeled(label_text, slider))

func _labeled(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 125
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _set_layer_visible(enabled: bool, index: int) -> void:
	_layer_visibility[index] = 1.0 if enabled else 0.0
	select_mode(mode_index)

func _select_weather(index: int) -> void:
	if _weather_select == null or index < 0 or index >= Runtime.WEATHER_MODES.size():
		return
	runtime.set_weather(Runtime.WEATHER_MODES[index])
	_last_receipt = "Weather: " + Runtime.WEATHER_LABELS[Runtime.WEATHER_MODES[index]]

func _attempt_forbidden_route() -> void:
	var receipt: Dictionary = runtime.route_event(
		"scripted", "play", "blast",
		Fixture.features()["reactor_target"], 12, Cell.FIRE, runtime.generation()
	)
	_last_receipt = "Negative control: " + str(receipt.get("error", "unexpectedly accepted"))

func _step_once() -> void:
	var result: Dictionary = runtime.step_once()
	_last_receipt = "Single-step: " + str(result.get("steps", {}))
	_publish_layers()

func _layout() -> void:
	if _side_panel == null:
		return
	var side_width: float = 320.0 if _side_panel.visible else 0.0
	_side_panel.position = Vector2(size.x - side_width - 10.0, 10.0)
	_side_panel.size = Vector2(side_width, maxf(120.0, size.y - 20.0))
	if compositor != null:
		compositor.position = Vector2(12, 72)
		compositor.size = Vector2(maxf(320.0, size.x - side_width - 34.0), maxf(180.0, size.y - 88.0))

func _update_status() -> void:
	if _status == null:
		return
	var info: Dictionary = runtime.stats()
	var layers: Dictionary = info.get("layers", {})
	_status.text = "%s\nmode=%s  camera=(%.0f,%.0f)  weather=%s\nplay/rear/fx/far ticks = %d / %d / %d / %d\ncommands accepted/rejected/applied = %d / %d / %d" % [
		_last_receipt,
		MODES[mode_index],
		camera_origin.x, camera_origin.y,
		str(info.get("weather", "off")),
		int(layers.get("play", {}).get("tick", 0)),
		int(layers.get("scripted", {}).get("tick", 0)),
		int(layers.get("effects", {}).get("tick", 0)),
		int(layers.get("background", {}).get("tick", 0)),
		int(info.get("accepted_commands", 0)),
		int(info.get("rejected_commands", 0)),
		int(info.get("applied_commands", 0)),
	]
