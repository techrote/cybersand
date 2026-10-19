extends Control

# Thunderbowl v2 is a physical manoeuvre/usable lab. The full arena display is
# an evaluator view; policy producers receive only their actor-local view.
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Overlay = preload("res://scripts/physical_actor_overlay.gd")
const Palette = preload("res://scripts/material_appearance_lut.gd")
const Usables = preload("res://scripts/usable_catalog.gd")
const UsableOverlay = preload("res://scripts/usable_overlay.gd")
var _arena: CyberPhysicalActorArena
var _model: OptionButton
var _count: SpinBox
var _producer: OptionButton
var _seed: SpinBox
var _camera: OptionButton
var _follow: OptionButton
var _pause: Button
var _effort: HSlider
var _status: Label
var _controls: Label
var _canvas: Control
var _terrain: TextureRect
var _overlay: CyberPhysicalActorOverlay
var _labels: Array[Label] = []
var _texture: ImageTexture
var _view := Arena.ARENA_RECT
var _last_visual_tick: int = -6
var _last_visual_view := Rect2i()
var _focused: bool = true
var _rearm: bool = true
var _sequence: int = 0
var _course: OptionButton
var _equipment: OptionButton
var _equipment_power: HSlider
var _usable_overlay: CyberUsableOverlay
var _section_labels: Array[Label] = []


func _ready() -> void:
	Engine.physics_ticks_per_second = Arena.PHYSICS_HZ
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_arena = Arena.new()
	add_child(_arena)
	if str(get_tree().get_meta("cybersand_feature", "")) == "physical_usables":
		_course.select(1)
		_count.value = 8
		_model.select(Catalog.RIG_IDS.find(&"digger"))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rig="):
			var index: int = Catalog.RIG_IDS.find(StringName(argument.trim_prefix("--rig=")))
			if index >= 0:
				_model.select(index)
		elif argument.begins_with("--actors=") and argument.trim_prefix("--actors=").is_valid_int():
			_count.value = clampi(int(argument.trim_prefix("--actors=")), 1, 8)
		elif argument == "--course=usables-v1":
			_course.select(1)
	_restart()


func _button(text: String, callback: Callable, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("111823")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18
	column.offset_right = -18
	column.offset_top = 12
	column.offset_bottom = -12
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.text = "THUNDERBOWL v2  ·  Physical manoeuvre / usable lab"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var note := Label.new()
	note.text = "41 articulated Rapier rigs · native material interactions · scripted local feedback · full evaluator camera"
	note.add_theme_font_size_override("font_size", 13)
	column.add_child(note)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	column.add_child(bar)
	_course = OptionButton.new()
	_course.add_item("Manoeuvre lab")
	_course.add_item("Usable integration course")
	_course.item_selected.connect(func(_index: int) -> void: _restart())
	bar.add_child(_course)
	_model = OptionButton.new()
	_model.custom_minimum_size.x = 208
	for id: StringName in Catalog.RIG_IDS:
		_model.add_item("%s · %d parts" % [Catalog.name_for(id), Equipment.definition(Catalog.entry(id)).part_count])
	_model.select(Catalog.RIG_IDS.find(&"ripper"))
	_model.item_selected.connect(func(_index: int) -> void: _restart())
	bar.add_child(_model)
	_count = SpinBox.new()
	_count.min_value = 1
	_count.max_value = 8
	_count.value = 4
	_count.prefix = "Actors "
	_count.custom_minimum_size.x = 115
	bar.add_child(_count)
	_producer = OptionButton.new()
	_producer.add_item("Scripted demos")
	_producer.add_item("Human actor 0 + demos")
	_producer.add_item("Policy actor 0 + demos")
	_producer.item_selected.connect(func(_index: int) -> void: _restart())
	bar.add_child(_producer)
	_seed = SpinBox.new()
	_seed.min_value = 0
	_seed.max_value = 2147483647
	_seed.prefix = "Seed "
	_seed.custom_minimum_size.x = 125
	bar.add_child(_seed)
	_button("Reset", _restart, bar)
	_pause = _button("Pause", _toggle_pause, bar)
	_button("Cancel input", _cancel_input, bar)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	column.add_child(tools)
	_camera = OptionButton.new()
	_camera.add_item("Whole lab")
	_camera.add_item("Follow actor")
	tools.add_child(_camera)
	_follow = OptionButton.new()
	_follow.custom_minimum_size.x = 165
	tools.add_child(_follow)
	var outlines := CheckButton.new()
	outlines.text = "Collider outlines"
	outlines.button_pressed = true
	outlines.toggled.connect(func(value: bool) -> void: _overlay.outlines = value)
	tools.add_child(outlines)
	var power := Label.new()
	power.text = "Effort"
	tools.add_child(power)
	_effort = HSlider.new()
	_effort.min_value = 0.0
	_effort.max_value = 1.0
	_effort.step = 0.01
	_effort.value = 0.7
	_effort.custom_minimum_size.x = 105
	tools.add_child(_effort)
	_button("Sampled v1", func() -> void: get_tree().change_scene_to_file("res://examples/thunderbowl/thunderbowl.tscn"), tools)
	_button("Feature menu (F2)", func() -> void: get_tree().change_scene_to_file("res://feature_launcher.tscn"), tools)
	var equipment_row := HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 8)
	column.add_child(equipment_row)
	_equipment = OptionButton.new()
	_equipment.custom_minimum_size.x = 235
	_equipment.add_item("None")
	for index: int in range(Usables.count()):
		_equipment.add_item("U%02d · %s" % [index + 1, Usables.name_for(index)])
	equipment_row.add_child(_equipment)
	var equipment_power_label := Label.new()
	equipment_power_label.text = "Equipment power"
	equipment_row.add_child(equipment_power_label)
	_equipment_power = HSlider.new()
	_equipment_power.min_value = 0.0
	_equipment_power.max_value = 1.0
	_equipment_power.step = 0.05
	_equipment_power.value = 0.8
	_equipment_power.custom_minimum_size.x = 80
	_equipment_power.tooltip_text = "Equipment power; independent from movement effort"
	equipment_row.add_child(_equipment_power)
	_button("Equip actor 0", _equip, equipment_row)
	_button("Feed processor", func() -> void: _processor_fixture("feed"), equipment_row)
	_button("Jam output", func() -> void: _processor_fixture("jam"), equipment_row)
	_button("Clear output", func() -> void: _processor_fixture("clear"), equipment_row)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	column.add_child(_status)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(512, 256)
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_usable_overlay = UsableOverlay.new()
	_canvas.add_child(_usable_overlay)
	for _index: int in range(8):
		var section := Label.new()
		section.add_theme_font_size_override("font_size", 10)
		section.modulate = Color(0.45, 0.78, 0.8, 0.9)
		section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(section)
		_section_labels.append(section)
	for _index: int in range(8):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(label)
		_labels.append(label)
	_controls = Label.new()
	_controls.add_theme_font_size_override("font_size", 13)
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_controls)
	var help := Label.new()
	help.text = "WASD / mouse aim · Space primary · Shift secondary · C auxiliary · Q/E trim · Z/X reel · [ / ] movement effort\nLeft or M uses equipment · right alternate · N drops · U picks up nearby. Release controls after focus changes. Processor fixture buttons affect the selected follow actor in the usable course."
	help.add_theme_font_size_override("font_size", 12)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)


func _restart() -> void:
	if _arena == null:
		return
	var config: Dictionary = Arena.usable_course_config(Catalog.RIG_IDS[_model.selected], int(_count.value)) if _course.selected == 1 \
		else Arena.default_config(Catalog.RIG_IDS[_model.selected], int(_count.value))
	config.seed = int(_seed.value)
	if _producer.selected != 0:
		config.actors[0].producer = "human" if _producer.selected == 1 else "policy"
	if not _arena.configure(config):
		_status.text = "Cannot start: " + _arena.last_error
		return
	_follow.clear()
	for index: int in range(config.actors.size()):
		_follow.add_item("%d · %s" % [index, Catalog.name_for(StringName(config.actors[index].model))])
	_sequence = 0
	_rearm = true
	_pause.text = "Pause"
	_last_visual_tick = -6
	_controls.text = Catalog.controls_text(Catalog.RIG_IDS[_model.selected])
	var equipment: Dictionary = _arena.observation(0).get("equipment", {})
	_equipment.select(int(equipment.get("usable_index", -1)) + 1)
	_equipment.disabled = _producer.selected != 1
	_present(_arena.snapshot())


func _equip() -> void:
	if _arena == null or _arena.session == null or _producer.selected != 1:
		_status.text = "Choose Human actor 0 to change its equipment. Scripted actors use their authored loadouts."
		return
	var view: Dictionary = _arena.observation(0)
	var command: Dictionary = Session.make_command(view, int(view.last_sequence) + 1,
		{"equipment": {"usable_index": _equipment.selected - 1, "power": _equipment_power.value}}, 6)
	if not _arena.submit(command, &"human"):
		_status.text = "Equipment refused: " + _arena.last_error
		return
	_sequence = int(view.last_sequence) + 2
	_rearm = true
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	# Apply the admitted selection before a normal keyboard sample can replace
	# it. This is one ordinary complete native/Rapier step, not a direct edit.
	_present(_arena.step())


func _processor_fixture(operation: String) -> void:
	if _arena == null or _arena.session == null:
		return
	var result: Dictionary = _arena.course_processor_fixture(maxi(0, _follow.selected), operation)
	_status.text = "%s: %s" % [operation, str(result.reason)]
	_last_visual_tick = -6


func _toggle_pause() -> void:
	if _arena == null or _arena.session == null:
		return
	_arena.set_paused(not bool(_arena.snapshot().paused))
	_pause.text = "Resume" if bool(_arena.snapshot().paused) else "Pause"
	_rearm = true


func _cancel_input() -> void:
	if _arena != null and _arena.session != null:
		var state: Dictionary = _arena.snapshot()
		for actor: Dictionary in state.actors:
			_arena.cancel(int(actor.actor_id), StringName(actor.producer))
	_rearm = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focused = false
		_cancel_input()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_focused = true
		_rearm = true


func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus != null:
			focus.release_focus()
			_rearm = true


func _any_control_held() -> bool:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return true
	for key: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT, KEY_C,
		KEY_Q, KEY_E, KEY_Z, KEY_X, KEY_M, KEY_N, KEY_U, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
		if Input.is_physical_key_pressed(key):
			return true
	return false


func _physics_process(delta: float) -> void:
	if _arena == null or _arena.session == null:
		return
	if _producer.selected == 1:
		var allowed: bool = _focused and get_viewport().gui_get_focus_owner() == null
		if not allowed:
			if not _rearm:
				_arena.cancel(0, &"human")
			_rearm = true
		elif _rearm and not _any_control_held():
			_rearm = false
		if allowed and not _rearm and not bool(_arena.snapshot().paused):
			var view: Dictionary = _arena.observation(0)
			if not view.is_empty():
				var pointer_in_world: bool = _content_rect().has_point(_canvas.get_local_mouse_position())
				_effort.value += float(int(Input.is_physical_key_pressed(KEY_BRACKETRIGHT))
					- int(Input.is_physical_key_pressed(KEY_BRACKETLEFT))) * delta * 0.7
				var action: Dictionary = {
					"move": Vector2(int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
						int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))),
					"aim": _pointer_aim(view.position), "effort": _effort.value,
					"trim": float(int(Input.is_physical_key_pressed(KEY_E)) - int(Input.is_physical_key_pressed(KEY_Q))),
					"reel": float(int(Input.is_physical_key_pressed(KEY_X)) - int(Input.is_physical_key_pressed(KEY_Z))),
					"primary": Input.is_physical_key_pressed(KEY_SPACE), "secondary": Input.is_physical_key_pressed(KEY_SHIFT),
					"auxiliary": Input.is_physical_key_pressed(KEY_C),
					"equipment": {"usable_index": int(view.get("equipment", {}).get("usable_index", -1)),
						"aim": _pointer_aim(view.position), "power": _equipment_power.value,
						"trigger": Input.is_physical_key_pressed(KEY_M) or (pointer_in_world and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)),
						"alternate": pointer_in_world and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT),
						"drop": Input.is_physical_key_pressed(KEY_N), "attach": Input.is_physical_key_pressed(KEY_U)}}
				_sequence = int(view.last_sequence) + 1
				_arena.submit(Session.make_command(view, _sequence, action, 6), &"human")
	_present(_arena.step())


func _content_rect() -> Rect2:
	var scale: float = minf(_canvas.size.x / _view.size.x, _canvas.size.y / _view.size.y)
	var size: Vector2 = Vector2(_view.size) * scale
	return Rect2((_canvas.size - size) * 0.5, size)


func _pointer_aim(actor_position: Vector2) -> Vector2:
	var content: Rect2 = _content_rect()
	if content.size.x <= 0.0 or content.size.y <= 0.0:
		return Vector2.RIGHT
	var pointer: Vector2 = Vector2(_view.position) + (_canvas.get_local_mouse_position() - content.position) / content.size * Vector2(_view.size)
	return (pointer - actor_position).normalized()


func _present(state: Dictionary) -> void:
	_view = Arena.ARENA_RECT
	if _camera.selected == 1 and not state.actors.is_empty():
		var actor: Dictionary = state.actors[clampi(_follow.selected, 0, state.actors.size() - 1)]
		var center: Vector2 = actor.position
		_view = Rect2i(clampi(floori(center.x) - 128, 0, 768), clampi(floori(center.y) - 80, 0, 864), 256, 160)
	if _texture == null or int(state.tick) - _last_visual_tick >= 6 or _last_visual_view != _view:
		var cells: PackedByteArray = _arena.presentation_cells(_view)
		if cells.size() == _view.size.x * _view.size.y:
			var bytes := PackedByteArray()
			bytes.resize(cells.size() * 4)
			for index: int in range(cells.size()):
				var color: int = Palette.BASE_RGBA8[mini(int(cells[index]), 80)]
				bytes[index * 4] = (color >> 24) & 255
				bytes[index * 4 + 1] = (color >> 16) & 255
				bytes[index * 4 + 2] = (color >> 8) & 255
				bytes[index * 4 + 3] = 255
			var image: Image = Image.create_from_data(_view.size.x, _view.size.y, false, Image.FORMAT_RGBA8, bytes)
			if _texture == null or _texture.get_size() != Vector2(_view.size):
				_texture = ImageTexture.create_from_image(image)
				_terrain.texture = _texture
			else:
				_texture.update(image)
		_last_visual_tick = int(state.tick)
		_last_visual_view = _view
	var content: Rect2 = _content_rect()
	_overlay.present(_arena.render_parts(), Vector2(_view.position), _view.size, content)
	_usable_overlay.present(state.get("physical_usables", {}), Vector2(_view.position), _view.size, content)
	var sections: Array = state.get("course_sections", [])
	for index: int in range(_section_labels.size()):
		var section: Label = _section_labels[index]
		section.visible = index < sections.size() and _camera.selected == 0
		if section.visible:
			section.text = str(sections[index].name)
			section.position = content.position + (Vector2(sections[index].position) - Vector2(_view.position)) / Vector2(_view.size) * content.size
	var occupied_labels: Array[Rect2] = []
	for index: int in range(_labels.size()):
		var label: Label = _labels[index]
		label.visible = index < state.actors.size()
		if not label.visible:
			continue
		var actor: Dictionary = state.actors[index]
		var local: Vector2 = (Vector2(actor.position) - Vector2(_view.position)) / Vector2(_view.size) * content.size
		label.visible = Rect2(Vector2.ZERO, content.size).has_point(local)
		label.text = "%d %s · %d%%" % [index, Catalog.name_for(StringName(actor.model)), roundi(float(actor.energy) * 100.0)]
		var equipment: Dictionary = actor.get("equipment", {})
		label.text += "\n%s · %s" % [str(equipment.get("name", "")), str(equipment.get("last_result", ""))]
		if label.visible:
			label.reset_size()
			var label_size: Vector2 = label.get_combined_minimum_size()
			var position: Vector2 = content.position + local + Vector2(8, -label_size.y - 4)
			position.x = clampf(position.x, content.position.x + 4,
				maxf(content.position.x + 4, content.end.x - label_size.x - 4))
			position.y = clampf(position.y, content.position.y + 4,
				maxf(content.position.y + 4, content.end.y - label_size.y - 4))
			var bounds := Rect2(position, label_size + Vector2(4, 4))
			for attempt: int in range(8):
				var overlap: bool = false
				for occupied: Rect2 in occupied_labels:
					overlap = overlap or bounds.intersects(occupied)
				if not overlap:
					break
				bounds.position.y = maxf(content.position.y + 4, bounds.position.y - label_size.y - 5)
			label.position = bounds.position
			occupied_labels.append(bounds)
	var source: String = "scripted feedback" if _producer.selected == 0 else ("human: release keys to arm" if _rearm and _producer.selected == 1 else "human active" if _producer.selected == 1 else "policy slot waiting for commands")
	_status.text = "Tick %d / %d · %d actors / %d parts · %s · %s" % [
		int(state.tick), int(state.max_ticks), int(state.actor_count), int(state.body_count), source,
		"PAUSED" if bool(state.paused) else str(state.reason)]
	var usable_totals: Dictionary = state.get("usable_totals", {})
	_status.text += " · equipment %d/%d uses, %d cell edits" % [int(usable_totals.get("accepted", 0)),
		int(usable_totals.get("requests", 0)), int(usable_totals.get("changed_cells", 0)) + int(state.effect_totals.changed_cells)]


func _exit_tree() -> void:
	if is_instance_valid(_arena):
		_arena.close()
