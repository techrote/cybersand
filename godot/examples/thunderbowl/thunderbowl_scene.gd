extends Control

# A separate optional desktop scene. It owns no ordinary desktop worker and
# deliberately displays the full evaluator arena, including hidden bot state.
const Driver = preload("res://examples/thunderbowl/thunderbowl_driver.gd")
const Contract = preload("res://scripts/thunderbowl_contract.gd")
const Devices = preload("res://examples/thunderbowl/human_devices.gd")
const Overlay = preload("res://scripts/actor_prototype_overlay.gd")
const Palette = preload("res://scripts/material_appearance_lut.gd")
var _driver: RefCounted
var _match: OptionButton
var _device: OptionButton
var _human: OptionButton
var _effort: HSlider
var _status: Label
var _canvas: Control
var _terrain: TextureRect
var _overlay: CyberActorPrototypeOverlay
var _labels: Array[Label] = []
var _texture: ImageTexture
var _last_visual_tick: int = -6
var _focused: bool = true
var _rearm: bool = true
var _pad_id: int = -1
var _match_paths: Array[String] = []


func _ready() -> void:
	Engine.physics_ticks_per_second = 60
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	var files: PackedStringArray = DirAccess.get_files_at("res://examples/thunderbowl/matches")
	files.sort()
	for filename: String in files:
		if filename.ends_with(".json"):
			_match.add_item(filename.trim_suffix(".json").replace("_", " "))
			_match_paths.append("res://examples/thunderbowl/matches/" + filename)
	var selected: int = _match_paths.find("res://examples/thunderbowl/matches/mixed.json")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--match="):
			var path: String = argument.trim_prefix("--match=")
			var found: int = _match_paths.find(path)
			if found >= 0: selected = found
	_match.select(maxi(0, selected))
	_restart()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("111823")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 20
	column.offset_right = -20
	column.offset_top = 16
	column.offset_bottom = -16
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var title := Label.new()
	title.text = "THUNDERBOWL  ·  full evaluator view"
	title.add_theme_font_size_override("font_size", 25)
	column.add_child(title)
	var note := Label.new()
	note.text = "Real rigs and terrain · virtual tags: 3 HP · human play is asymmetric with bot-local sensing"
	column.add_child(note)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	column.add_child(bar)
	_match = OptionButton.new()
	_match.custom_minimum_size.x = 200
	bar.add_child(_match)
	var restart := Button.new()
	restart.text = "Start / restart"
	restart.pressed.connect(_restart)
	bar.add_child(restart)
	var physical := Button.new()
	physical.text = "Physical v2 lab"
	physical.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://examples/thunderbowl/physical_thunderbowl.tscn"))
	bar.add_child(physical)
	_device = OptionButton.new()
	_device.add_item("Keyboard + mouse")
	_device.add_item("Gamepad 1")
	_device.item_selected.connect(func(_index: int) -> void: _rearm = true)
	bar.add_child(_device)
	_human = OptionButton.new()
	_human.custom_minimum_size.x = 130
	_human.item_selected.connect(func(_index: int) -> void: _rearm = true)
	bar.add_child(_human)
	var power := Label.new()
	power.text = "Power"
	bar.add_child(power)
	_effort = HSlider.new()
	_effort.min_value = 0.0
	_effort.max_value = 1.0
	_effort.step = 0.01
	_effort.value = 0.7
	_effort.custom_minimum_size.x = 100
	bar.add_child(_effort)
	_status = Label.new()
	_status.text = "Preparing arena…"
	column.add_child(_status)
	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(512, 288)
	_canvas.gui_input.connect(_canvas_input)
	column.add_child(_canvas)
	_terrain = TextureRect.new()
	_terrain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_terrain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_terrain)
	_overlay = Overlay.new()
	_canvas.add_child(_overlay)
	for _index: int in range(8):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(label)
		_labels.append(label)
	var help := Label.new()
	help.text = "Click arena to arm · WASD move · mouse aim / click tag · Space primary · Shift secondary · C auxiliary · Q/E trim · Z/X reel\nMetal: Ripper A/D + Q/E; Copter W collective + A/D cyclic; Gemini Space/Shift independent engines. Release controls after focus change."
	help.add_theme_font_size_override("font_size", 13)
	column.add_child(help)


func _restart() -> void:
	if _match_paths.is_empty():
		_status.text = "No Thunderbowl match files are available"
		return
	var config: Dictionary = Contract.load_json(_match_paths[_match.selected])
	if _driver == null:
		_driver = Driver.new()
	if not _driver.configure(config):
		_status.text = _driver.last_error
		return
	_human.clear()
	for index: int in range(config.actors.size()):
		if str(config.actors[index].controller).begins_with("human_"):
			_human.add_item("Actor %d: %s" % [index, config.actors[index].model], index)
	if _human.item_count == 0:
		_human.add_item("Scripted match", -1)
	_human.disabled = _human.item_count == 1 and _human.get_item_id(0) < 0
	_rearm = true
	_pad_id = -1
	_last_visual_tick = -6
	_present(_driver.snapshot())


func _physics_process(_delta: float) -> void:
	if _driver == null or _driver.arena == null:
		return
	var frames: Dictionary = {}
	var chosen: int = _human.get_selected_id()
	if chosen >= 0:
		var view: Dictionary = _driver.arena.observation(chosen)
		var pads: Array = _connected_pads()
		var device: int = int(pads[0]) if not pads.is_empty() else -1
		if _device.selected == 1 and device != _pad_id:
			_pad_id = device
			_rearm = true
		var allowed: bool = _focused and get_viewport().gui_get_focus_owner() == null
		if not allowed:
			_rearm = true
		elif _rearm and (_device.selected != 1 or _pad_id >= 0) and not _any_control_held():
			_rearm = false
		var live: bool = allowed and not _rearm and not view.is_empty() and bool(view.alive)
		var aim: Vector2 = _pointer_aim(view)
		if _device.selected == 1:
			if view.get("control_mode", "wire") == "metal":
				frames[chosen] = Devices.metal_gamepad(device, live, str(view.model))
			else:
				frames[chosen] = Devices.gamepad(device, live, _effort.value)
		else:
			frames[chosen] = Devices.keyboard_mouse(aim, live, _effort.value)
	_present(_driver.step(frames))


func _any_control_held() -> bool:
	for key: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT, KEY_C, KEY_Q, KEY_E, KEY_Z, KEY_X]:
		if _key_held(key): return true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): return true
	# This prototype intentionally requires every attached pad to be released
	# after a focus/device change, even though the first pad supplies gameplay.
	if _device.selected == 1:
		for device: int in _connected_pads():
			for axis: int in range(JOY_AXIS_MAX):
				if absf(_joy_axis(device, axis)) > 0.18: return true
			for button: int in range(JOY_BUTTON_MAX):
				if _joy_button(device, button): return true
	return false


func _key_held(key: int) -> bool:
	return Input.is_physical_key_pressed(key)


func _connected_pads() -> Array:
	return Input.get_connected_joypads()


func _joy_axis(device: int, axis: int) -> float:
	return Input.get_joy_axis(device, axis)


func _joy_button(device: int, button: int) -> bool:
	return Input.is_joy_button_pressed(device, button)


func _content_rect() -> Rect2:
	var scale: float = minf(_canvas.size.x / 256.0, _canvas.size.y / 144.0)
	var dimensions := Vector2(256.0, 144.0) * scale
	return Rect2((_canvas.size - dimensions) * 0.5, dimensions)


func _pointer_aim(view: Dictionary) -> Vector2:
	return _pointer_aim_at(view, _canvas.get_local_mouse_position())


func _pointer_aim_at(view: Dictionary, point: Vector2) -> Vector2:
	if view.is_empty() or not point.is_finite(): return Vector2.ZERO
	var content: Rect2 = _content_rect()
	if content.size.x <= 0.0 or content.size.y <= 0.0 or not content.has_point(point): return Vector2.ZERO
	var world: Vector2 = Vector2(96, 96) + (point - content.position) * Vector2(256, 144) / content.size
	var center := Vector2(view.self_state[0] + view.self_state[35] * 0.5,
		view.self_state[1] + view.self_state[36] * 0.5)
	return (world - center).normalized()


func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus != null: focus.release_focus()


func _present(value: Dictionary) -> void:
	var tick: int = int(value.tick)
	if tick - _last_visual_tick >= 6:
		var cells: PackedByteArray = _driver.arena.presentation_cells()
		var bytes := PackedByteArray()
		bytes.resize(cells.size() * 4)
		for index: int in range(cells.size()):
			var color: int = Palette.BASE_RGBA8[mini(int(cells[index]), 80)]
			bytes[index * 4] = (color >> 24) & 255
			bytes[index * 4 + 1] = (color >> 16) & 255
			bytes[index * 4 + 2] = (color >> 8) & 255
			bytes[index * 4 + 3] = 255
		var image: Image = Image.create_from_data(256, 144, false, Image.FORMAT_RGBA8, bytes)
		if _texture == null:
			_texture = ImageTexture.create_from_image(image)
			_terrain.texture = _texture
		else:
			_texture.update(image)
		_last_visual_tick = tick
	_overlay.present(value.actor_prototypes, Vector2(96, 96), Vector2i(256, 144), _content_rect())
	for index: int in range(8):
		_labels[index].visible = index < value.hp.size()
		if index >= value.hp.size(): continue
		var state: PackedFloat32Array = value.actor_prototypes.rig_states.slice(index * 40, (index + 1) * 40)
		_labels[index].position = _overlay.position + _overlay.world_to_overlay(Vector2(state[0], state[1])) - Vector2(0, 24)
		_labels[index].text = "%d  HP %d  %.1f" % [index, value.hp[index], value.rewards[index]]
		_labels[index].modulate = Color.WHITE if value.alive[index] != 0 else Color("ef7373")
	_status.text = "Tick %d / %d  ·  %s  ·  virtual tag hits %s  ·  %s" % [tick,
		_driver.config.max_ticks, value.reason, str(value.tags_dealt),
		"release controls / click arena to arm" if _rearm else "controls armed"]


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_rearm = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _exit_tree() -> void:
	if _driver != null: _driver.close()
