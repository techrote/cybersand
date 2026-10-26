extends Control

const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const PlayerInput = preload("res://scripts/player_playground_input.gd")
const Surface = preload("res://scripts/depth/depth_layer_surface.gd")
const Overlay = preload("res://scripts/player_playground_overlay.gd")
const WorldSetup = preload("res://scripts/player_playground_world.gd")
const UsableCatalog = preload("res://scripts/usable_catalog.gd")
const PAINT_IDS: Array[int] = [2, 3, 16, 24, 4, 6, 8, 12, 1]
const PAINT_NAMES: Array[String] = ["Sand", "Water", "Oil", "Brine", "Smoke", "Fire", "Lava", "Acid", "Wall"]

var runtime: CyberPlayerPlaygroundRuntime
var selected: int = 0
var selected_map: int = 0
var selected_water: int = 0
var _map_picker: OptionButton
var _water_picker: OptionButton
var _water_readback: Label
var _paint_toggle: CheckBox
var _material_picker: OptionButton
var _brush_size: SpinBox
var _replace: CheckBox
var _authoring_status: Label
var _painting: bool = false
var _usable_picker: OptionButton
var _usable_status: Label
var _include_npcs: CheckBox
var _npc_picker: OptionButton
var _npc_paint: CheckBox
var _npc_status: Label
var _npc_stage: int = 0
var _focused: bool = true
var _rearm: bool = true
var _follow: bool = false
var _target: int = 0
var _lap_ticks: int = 0
var _lap_started: bool = false
var _best_times: Dictionary = {}
var _surface: CyberDepthLayerSurface
var _overlay: Control
var _canvas: Control
var _terrain: TextureRect
var _title: Label
var _map_title: Label
var _tagline: Label
var _controls: Label
var _status: Label
var _timing: Label
var _hint: Label
var _pause_button: Button
var _buttons: Array[Button] = []
var _view := Course.VIEW
var _last_draw_tick: int = -1
var _last_packet_epoch: int = -1


func _ready() -> void:
	runtime = Runtime.new()
	add_child(runtime)
	_build_ui()
	_surface = Surface.new()
	add_child(_surface)
	_surface.configure("player-playground", false, Course.map_view(&"mixed").size)
	_terrain.texture = _surface.get_texture()
	select_preset(0)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--player="):
			var id := StringName(argument.trim_prefix("--player="))
			if id in Course.PRESETS:
				select_preset(Course.PRESETS.find(id))
		elif argument.begins_with("--playground-map="):
			var map_id := StringName(argument.trim_prefix("--playground-map="))
			if map_id in Course.MAP_IDS: select_map(Course.MAP_IDS.find(map_id))


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0a101a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_label(heading, "CYBERSAND  /  PLAYER PLAYGROUND", 29, Color("e8f3fa"))
	_label(heading, "Seven ways to get somewhere. Some of them sensible.", 16, Color("91a8ba"))
	_button(header, "Reset  ·  R", _restart)
	_pause_button = _button(header, "Pause  ·  P", _toggle_pause)
	_button(header, "Camera  ·  F", _toggle_camera)
	_button(header, "Menu  ·  F2", func() -> void: get_tree().change_scene_to_file("res://feature_launcher.tscn"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 330
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 305
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	scroll.add_child(side)
	_label(side, "MAP · every player can use every map", 13, Color("7895a9"))
	_map_picker = OptionButton.new()
	_map_picker.focus_mode = Control.FOCUS_NONE
	for index: int in range(Course.MAP_NAMES.size()):
		_map_picker.add_item(Course.MAP_NAMES[index])
		_map_picker.set_item_tooltip(index, Course.MAP_HINTS[index])
	_map_picker.item_selected.connect(select_map)
	side.add_child(_map_picker)
	_label(side, "WATER · changing solver restarts the map", 13, Color("7895a9"))
	_water_picker = OptionButton.new()
	_water_picker.focus_mode = Control.FOCUS_NONE
	for water_name: String in WorldSetup.WATER_NAMES: _water_picker.add_item(water_name)
	_water_picker.item_selected.connect(select_water)
	side.add_child(_water_picker)
	_water_readback = _label(side, "", 13, Color("91a8ba"))
	_water_readback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(side, "ACTORS · share the world and physics", 13, Color("7895a9"))
	_include_npcs = CheckBox.new()
	_include_npcs.focus_mode = Control.FOCUS_NONE
	_include_npcs.text = "Start with an NPC · restarts map"
	_include_npcs.toggled.connect(func(_value: bool) -> void:
		if not select_preset(selected): _include_npcs.set_pressed_no_signal(runtime.include_npcs))
	side.add_child(_include_npcs)
	_npc_picker = OptionButton.new()
	_npc_picker.focus_mode = Control.FOCUS_NONE
	for npc_name: String in ["Runner · walking actor", "Skimmer · hovering actor", "Crawler · tracked actor"]:
		_npc_picker.add_item(npc_name)
	_npc_picker.item_selected.connect(func(_index: int) -> void: _cancel_input())
	side.add_child(_npc_picker)
	_button(side, "Spawn NPC at a clear starting stage", _spawn_npc_at_stage)
	_npc_paint = CheckBox.new()
	_npc_paint.focus_mode = Control.FOCUS_NONE
	_npc_paint.text = "Place NPC · click map"
	_npc_paint.toggled.connect(func(value: bool) -> void:
		_cancel_input()
		if value: _paint_toggle.set_pressed_no_signal(false))
	side.add_child(_npc_paint)
	_npc_status = _label(side, "NPCs use local demo controls. Spawning marks a practice lap.\nReset clears added actors and restores loose props.", 13, Color("91a8ba"))
	_npc_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(side,"USABLES · aim with mouse, M use / B alternate",13,Color("7895a9"))
	_usable_picker=OptionButton.new()
	_usable_picker.focus_mode=Control.FOCUS_NONE
	_usable_picker.add_item("None",-1)
	for index: int in range(UsableCatalog.count()): _usable_picker.add_item(UsableCatalog.name_for(index),index)
	_usable_picker.item_selected.connect(func(index: int) -> void:
		_cancel_input()
		runtime.select_usable(_usable_picker.get_item_id(index)))
	side.add_child(_usable_picker)
	_usable_status=_label(side,"All players: tools, projectiles, processors.\nMechanical players: N drop / U reattach.",13,Color("91a8ba"))
	_usable_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_label(side, "MATERIALS", 13, Color("7895a9"))
	_material_picker = OptionButton.new()
	_material_picker.focus_mode = Control.FOCUS_NONE
	for material_name: String in PAINT_NAMES: _material_picker.add_item(material_name)
	side.add_child(_material_picker)
	var brush_row := HBoxContainer.new()
	side.add_child(brush_row)
	_label(brush_row, "Brush radius", 14, Color("adc0ce"))
	_brush_size = SpinBox.new()
	_brush_size.min_value = 1
	_brush_size.max_value = 12
	_brush_size.value = 4
	brush_row.add_child(_brush_size)
	_paint_toggle = CheckBox.new()
	_paint_toggle.focus_mode = Control.FOCUS_NONE
	_paint_toggle.text = "Paint tool · left draw / right erase"
	_paint_toggle.toggled.connect(func(value: bool) -> void:
		_cancel_input()
		if value: _npc_paint.set_pressed_no_signal(false))
	side.add_child(_paint_toggle)
	_replace = CheckBox.new()
	_replace.focus_mode = Control.FOCUS_NONE
	_replace.text = "Replace existing material / terrain"
	side.add_child(_replace)
	_button(side, "Spawn a burst above player", _spawn_material)
	_authoring_status = _label(side, "Paint while running or paused. Reset clears edits.", 13, Color("91a8ba"))
	_authoring_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(side, "PICK YOUR BAD IDEA", 13, Color("7895a9"))
	for index: int in range(Course.PRESETS.size()):
		var button: Button = _button(side, "%d   %s" % [index + 1, Course.NAMES[index]], func() -> void: select_preset(index))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 44
		_buttons.append(button)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	side.add_child(spacer)
	_title = _label(side, "", 24, Color.WHITE)
	_tagline = _label(side, "", 15, Color("adc0ce"))
	_tagline.custom_minimum_size.x = 285
	_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls = _label(side, "", 16, Color("e0e8ed"))
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls.custom_minimum_size.y = 176
	_label(side, "GAMEPAD", 12, Color("7895a9"))
	_label(side, "Left stick = WASD\nA / B / X = jump / brake / auxiliary\nX = Ctrl for Afterimage, C for others\nShoulders = Q / E   ·   Start = pause", 14, Color("adc0ce"))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_map_title = _label(right, "", 19, Color("b9d7e7"))
	var progress := HBoxContainer.new()
	right.add_child(progress)
	_timing = _label(progress, "", 19, Color("a3e8f4"))
	_timing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(progress, "1–7 select   ·   TAB next   ·   F zoom", 14, Color("91a8ba"))
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(512, 256)
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.clip_contents = true
	_canvas.gui_input.connect(_canvas_input)
	right.add_child(_canvas)
	_terrain = TextureRect.new()
	_terrain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_terrain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_terrain)
	_overlay = Overlay.new()
	_canvas.add_child(_overlay)
	_status = _label(right, "", 16, Color("e0e8ed"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = _label(right, "", 15, Color("9bb0bf"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.y = 52
	_label(column, "MAP + WATER CHANGES RESTART     ·     PAINTING = PRACTICE LAP     ·     ALL MAPS OPEN TO ALL PLAYERS", 13, Color("698597"))


func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("142231")
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("243b4d")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(pressed)
	parent.add_child(button)
	return button


func select_preset(index: int) -> bool:
	if runtime == null or index < 0 or index >= Course.PRESETS.size():
		return false
	_cancel_input()
	if not runtime.configure(Course.PRESETS[index], Course.MAP_IDS[selected_map], selected_water,
		_include_npcs.button_pressed, Runtime.NPC_IDS[_npc_picker.selected]):
		_status.text = "Could not start: " + runtime.last_error
		_authoring_status.text = "Setup refused: " + runtime.last_error
		return false
	selected = index
	_target = 0
	_lap_ticks = 0
	_lap_started = false
	_last_draw_tick = -1
	_last_packet_epoch = -1
	_npc_stage = 0
	_npc_status.text = "Three loose objects restored. %s\nNPCs roam on their own. If a stage is occupied, click the map to choose a clear spot." % \
		("An NPC is included · practice lap." if _include_npcs.button_pressed else "No starting NPC.")
	_title.text = Course.NAMES[index]
	_map_title.text = Course.MAP_NAMES[selected_map]
	_title.add_theme_color_override("font_color", Course.COLORS[index])
	_tagline.text = Course.TAGLINES[index]
	_controls.text = Course.controls(Course.PRESETS[index])
	_pause_button.text = "Pause  ·  P"
	var readback: Dictionary = runtime.liquid_readback()
	for assignment: Dictionary in readback.policy.assignments:
		if int(assignment.material) == 3:
			_water_readback.text = "Applied: %s / %s · radius %d" % [assignment.applied_family, assignment.applied_variant, int(readback.policy.maximum_rule_radius)]
	_authoring_status.text = "Paint while running or paused. Reset clears edits."
	_surface.set_render_enabled(true)
	for button_index: int in range(_buttons.size()):
		_buttons[button_index].modulate = Course.COLORS[index] if button_index == selected else Color.WHITE
	_present(runtime.snapshot(), true)
	return true


func select_map(index: int) -> bool:
	if index < 0 or index >= Course.MAP_IDS.size(): return false
	var previous: int = selected_map
	selected_map = index
	var accepted: bool = select_preset(selected)
	if not accepted: selected_map = previous
	_map_picker.select(selected_map)
	return accepted


func select_water(index: int) -> bool:
	if index < 0 or index >= WorldSetup.WATER_NAMES.size(): return false
	var previous: int = selected_water
	selected_water = index
	var accepted: bool = select_preset(selected)
	if not accepted: selected_water = previous
	_water_picker.select(selected_water)
	return accepted


func _lap_key() -> String:
	return "%s:%s:%d" % [Course.PRESETS[selected], Course.MAP_IDS[selected_map], selected_water]


func _spawn_material() -> void:
	_cancel_input()
	var position: Vector2 = runtime.snapshot().actor.get("position", Vector2(178, 304))
	var bounds: Rect2i=Course.editable(runtime.map_id)
	_author(Vector2i(clampi(roundi(position.x)+32,bounds.position.x+12,bounds.end.x-13),clampi(roundi(position.y)-32,bounds.position.y+12,bounds.end.y-13)),false)


func _spawn_npc(position: Vector2) -> bool:
	_cancel_input()
	var receipt: Dictionary = runtime.spawn_npc(Runtime.NPC_IDS[_npc_picker.selected], position)
	_npc_status.text = ("NPC added · actor %d · practice lap.\nExisting player, terrain and liquid state retained." % int(receipt.actor_id)) \
		if receipt.get("accepted", false) else "Placement refused: " + _npc_refusal(str(receipt.get("reason", "")))
	if receipt.get("accepted", false): _present(runtime.snapshot(), true)
	return bool(receipt.get("accepted", false))


func _npc_refusal(reason: String) -> String:
	match reason:
		"npc_spawn_body_overlap": return "Choose a spot clear of the player, NPCs and loose objects."
		"npc_spawn_occupied_cells": return "Choose an empty space clear of terrain and liquid."
		"npc_spawn_outside_map": return "Keep the whole actor inside the map."
		"actor_append_configuration_or_capacity", "actor_append_body_capacity":
			return "This run has reached its actor limit. Reset to clear added NPCs."
	return "Try a clear location, or reset the map to restore the starting setup."


func _spawn_npc_at_stage() -> void:
	var stages: PackedVector2Array = Course.npc_spawns(Course.MAP_IDS[selected_map])
	for offset: int in range(stages.size()):
		var stage: int = (_npc_stage + offset) % stages.size()
		if _spawn_npc(stages[stage]):
			_npc_stage = (stage + 1) % stages.size()
			return


func _author(cell: Vector2i, erase: bool) -> void:
	var receipt: Dictionary = runtime.paint(cell, int(_brush_size.value), 0 if erase else PAINT_IDS[_material_picker.selected], _replace.button_pressed)
	_authoring_status.text = ("%d cells changed · practice lap" % int(receipt.changed)) if receipt.accepted else str(receipt.reason)
	if receipt.accepted and int(receipt.changed) > 0:
		_present(runtime.snapshot(), true)


func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus != null: focus.release_focus()
		if event.pressed and _npc_paint.button_pressed and _focused:
			var content: Rect2 = _content_rect()
			if event.button_index == MOUSE_BUTTON_LEFT and content.has_point(event.position):
				_spawn_npc(Vector2(_view.position) + (event.position - content.position) / content.size * Vector2(_view.size))
			_canvas.accept_event()
			return
		if event.pressed and _paint_toggle.button_pressed and _focused:
			_cancel_input()
			_painting = true
			_paint_at_view_position(event.position, event.button_index == MOUSE_BUTTON_RIGHT)
			_canvas.accept_event()


func _paint_at_pointer() -> void:
	_paint_at_view_position(_canvas.get_local_mouse_position(), Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))


func _paint_at_view_position(pointer: Vector2, erase: bool) -> void:
	var content: Rect2 = _content_rect()
	if content.size.x <= 0.0 or not content.has_point(pointer): return
	var cell := Vector2i((Vector2(_view.position) + (pointer - content.position) / content.size * Vector2(_view.size)).floor())
	_author(cell, erase)


func _restart() -> void:
	select_preset(selected)


func _toggle_pause() -> void:
	if runtime == null or not runtime.active():
		return
	_cancel_input()
	if runtime.paused and runtime.last_error == "tick_limit":
		_restart()
		return
	runtime.set_paused(not runtime.paused)
	_pause_button.text = "Resume  ·  P" if runtime.paused else "Pause  ·  P"
	_surface.set_render_enabled(not runtime.paused)
	_present(runtime.snapshot())


func _toggle_camera() -> void:
	_follow = not _follow
	# A paused SubViewport needs one new bake after its camera uniforms move.
	_surface.set_render_enabled(not runtime.paused)
	_present(runtime.snapshot())


func _cancel_input() -> void:
	_rearm = true
	_painting = false
	if runtime != null:
		runtime.cancel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focused = false
		_cancel_input()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focused = true
		_rearm = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_painting = false
	if _ui_captures_input():
		_cancel_input()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key >= KEY_1 and key <= KEY_7:
			select_preset(int(key - KEY_1))
			get_viewport().set_input_as_handled()
			return
		match key:
			KEY_TAB:
				select_preset(posmod(selected + (-1 if event.shift_pressed else 1), Course.PRESETS.size()))
				get_viewport().set_input_as_handled()
				return
			KEY_R:
				_restart()
				get_viewport().set_input_as_handled()
				return
			KEY_P, KEY_ESCAPE:
				_toggle_pause()
				get_viewport().set_input_as_handled()
				return
			KEY_F:
				_toggle_camera()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		_toggle_pause()
		return
	if event is InputEventMouseButton and event.pressed:
		_cancel_input()
		return
	# Submit every button edge as well as the fixed-tick sample. The shared
	# Session retains a quick press+release even when both precede a physics tick.
	if (event is InputEventKey or event is InputEventJoypadButton) and _can_control() and not _rearm:
		_submit_action(_sample_action())


func _can_control() -> bool:
	return runtime != null and runtime.active() and not runtime.paused and not runtime.failed \
		and _focused and not _ui_captures_input() and not _paint_toggle.button_pressed and not _npc_paint.button_pressed


func _ui_captures_input() -> bool:
	return get_viewport().gui_get_focus_owner() != null or _map_picker.get_popup().visible \
		or _water_picker.get_popup().visible or _material_picker.get_popup().visible or _usable_picker.get_popup().visible \
		or _npc_picker.get_popup().visible


func _sample_action() -> Dictionary:
	var action: Dictionary = PlayerInput.sample(Course.PRESETS[selected])
	var state: Dictionary = runtime.snapshot()
	var content: Rect2 = _content_rect()
	var pointer: Vector2 = _canvas.get_local_mouse_position()
	if content.size.x > 0.0 and content.has_point(pointer):
		var world: Vector2 = Vector2(_view.position) + (pointer - content.position) / content.size * Vector2(_view.size)
		action.aim = (world - Vector2(state.actor.get("position", Vector2.ZERO))).normalized()
	elif Vector2(action.aim).length_squared() < 0.001:
		action.aim = Vector2(0.7, -0.7)
	return action


func _physics_process(_delta: float) -> void:
	if runtime == null or not runtime.active():
		return
	if _painting and _paint_toggle.button_pressed and _focused \
		and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_paint_at_pointer()
	advance_frame(_sample_action(), _can_control())


func _submit_action(action: Dictionary) -> bool:
	if not runtime.submit_action(action):
		return false
	# A complete press/release can precede the fixed-tick sample. Start timing
	# when that movement is admitted, even if the next sample is neutral.
	if PlayerInput.active(action):
		_lap_started = true
	return true


func advance_frame(action: Dictionary, allowed: bool) -> void:
	if not allowed:
		if not _rearm:
			_cancel_input()
	elif _rearm and not PlayerInput.active(action):
		_rearm = false
	if allowed and not _rearm:
		_submit_action(action)
	var before: int = runtime.tick
	var state: Dictionary = runtime.step()
	if runtime.tick > before:
		if _lap_started and _target < Course.checkpoints(Course.PRESETS[selected], Course.MAP_IDS[selected_map]).size():
			_lap_ticks += runtime.tick - before
		_check_targets(state)
	_present(state)


func _check_targets(state: Dictionary) -> void:
	var points: PackedVector2Array = Course.checkpoints(Course.PRESETS[selected], Course.MAP_IDS[selected_map])
	if _target >= points.size() or state.actor.is_empty():
		return
	if Vector2(state.actor.position).distance_to(points[_target]) <= 15.0:
		_target += 1
		if _target == points.size() and runtime.authoring_revision == 0:
			_best_times[_lap_key()] = mini(_lap_ticks, int(_best_times.get(_lap_key(), 2147483647)))


func _content_rect() -> Rect2:
	var extent: Vector2i=Course.map_view(Course.MAP_IDS[selected_map]).size
	var fit: float = minf(_canvas.size.x / float(extent.x), _canvas.size.y / float(extent.y))
	var dimensions: Vector2 = Vector2(extent) * maxf(0.0, fit)
	return Rect2((_canvas.size - dimensions) * 0.5, dimensions)


func _present(state: Dictionary, force: bool = false) -> void:
	if _surface == null or state.actor.is_empty():
		return
	var actor: Dictionary = state.actor
	var position: Vector2 = actor.get("position", Vector2(178, 310))
	_view = Course.map_view(Course.MAP_IDS[selected_map])
	if _follow:
		_view = Rect2i(clampi(floori(position.x)-192,0,640),clampi(floori(position.y)-144,0,480),384,288)
	_surface._material.set_shader_parameter("camera_origin_px", Vector2(_view.position))
	_surface._material.set_shader_parameter("view_size_px", Vector2(_view.size))
	var presentation_error: String = ""
	if force or _last_packet_epoch != runtime.epoch or _last_draw_tick != runtime.tick:
		var packet: Dictionary = runtime.take_render_packet(force or _last_packet_epoch != runtime.epoch)
		if not packet.is_empty() and not _surface.apply_packet(packet):
			presentation_error = "Presentation refused: " + _surface.last_rejection
		_last_packet_epoch = runtime.epoch
		_last_draw_tick = runtime.tick
	_overlay.targets = Course.checkpoints(Course.PRESETS[selected], Course.MAP_IDS[selected_map])
	_overlay.target_index = _target
	_overlay.accent = Course.COLORS[selected]
	_overlay.actor_position = position
	_overlay.material_field = bool(state.material_mode)
	_overlay.field_radius = 60.0
	_overlay.usables = runtime.usable_snapshot()
	_overlay.movement = actor.get("player_movement", {})
	_overlay.preset = Course.PRESETS[selected]
	_overlay.present(runtime.render_parts(), Vector2(_view.position), _view.size, _content_rect())
	_overlay.visible = true
	_overlay.queue_redraw()
	var complete: bool = _target >= _overlay.targets.size()
	_timing.text = ("COURSE CLEAR" if complete else "GATES  %d / %d" % [_target, _overlay.targets.size()]) + "    %05.2f s" % (float(_lap_ticks) / 60.0)
	if runtime.authoring_revision > 0: _timing.text += "    PRACTICE"
	elif _best_times.has(_lap_key()):
		_timing.text += "    BEST  %.2f s" % (float(_best_times[_lap_key()]) / 60.0)
	if not presentation_error.is_empty():
		_status.text = presentation_error
	elif runtime.failed:
		_status.text = "Stopped: " + runtime.last_error
	elif runtime.paused:
		_status.text = "Ten-minute run complete — press R or P for a fresh run." if runtime.last_error == "tick_limit" else "PAUSED — press P to resume."
	elif _paint_toggle.button_pressed:
		_status.text = "PAINT TOOL — left draw / right erase. Turn the tool off to control the player."
	elif _rearm:
		_status.text = "Release movement buttons to take control."
	elif state.material_mode:
		var field: Dictionary = actor.get("field", {})
		_status.text = "%s   ·   %d local samples   ·   %d moves this tick" % ["SAND CLOUD" if selected == 4 else "WATER BLOB", int(field.get("controlled_cells", 0)), int(field.get("moved_cells", 0))]
	else:
		var movement: Dictionary = actor.get("player_movement", {})
		var mode: String = str(movement.get("movement_mode", movement.get("mode", "ready"))).replace("_", " ").to_upper()
		_status.text = "%s   ·   SPEED %.1f cells/s   ·   %s" % [mode, Vector2(actor.get("velocity", Vector2.ZERO)).length(), "SUPPORTED" if bool(actor.get("grounded", false)) else "AIRBORNE"]
	_hint.text = Course.MAP_HINTS[selected_map]
	if selected == 2:
		_hint.text += "  Afterimage: Shift/S + Space bullet jump; hold Ctrl in air to glide."
	elif state.material_mode:
		_hint.text += "  The ring marks your control area. Idle motion stays around its fixed centre; nearby matching material can join."
	var equipment: Dictionary=actor.get("equipment",actor.get("usable",{}))
	_usable_status.text="%s · %s\nCharge %.0f · cooldown %.2fs\nM use / B alternate · N drop / U attach (mechanical)" % [UsableCatalog.name_for(runtime.usable_index),equipment.get("last_result","selection applies on next admitted tick"),float(equipment.get("charge",100.0)),float(equipment.get("cooldown",0.0))]


func _exit_tree() -> void:
	if runtime != null:
		runtime.close()
