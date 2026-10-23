extends Control

const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const PlayerInput = preload("res://scripts/player_playground_input.gd")
const Surface = preload("res://scripts/depth/depth_layer_surface.gd")
const Overlay = preload("res://scripts/player_playground_overlay.gd")

var runtime: CyberPlayerPlaygroundRuntime
var selected: int = 0
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
	_surface.configure("player-playground", false, Course.VIEW.size)
	_terrain.texture = _surface.get_texture()
	select_preset(0)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--player="):
			var id := StringName(argument.trim_prefix("--player="))
			if id in Course.PRESETS:
				select_preset(Course.PRESETS.find(id))


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
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 300
	side.add_theme_constant_override("separation", 8)
	row.add_child(side)
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
	_label(side, "Left stick = WASD\nA / B / X = Space / Shift / C\nShoulders = Q / E   ·   Start = pause", 14, Color("adc0ce"))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
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
	_label(column, "RAMP / PRELOAD     ·     LOW TUNNEL / TUCK     ·     SLALOM / AIR CONTROL     ·     SIEVE / MATERIAL FLOW", 13, Color("698597"))


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
	if not runtime.configure(Course.PRESETS[index]):
		_status.text = "Could not start: " + runtime.last_error
		return false
	selected = index
	_target = 0
	_lap_ticks = 0
	_lap_started = false
	_last_draw_tick = -1
	_last_packet_epoch = -1
	_title.text = Course.NAMES[index]
	_title.add_theme_color_override("font_color", Course.COLORS[index])
	_tagline.text = Course.TAGLINES[index]
	_controls.text = Course.controls(Course.PRESETS[index])
	_pause_button.text = "Pause  ·  P"
	_surface.set_render_enabled(true)
	for button_index: int in range(_buttons.size()):
		_buttons[button_index].modulate = Course.COLORS[index] if button_index == selected else Color.WHITE
	_present(runtime.snapshot(), true)
	return true


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
		and _focused and get_viewport().gui_get_focus_owner() == null


func _sample_action() -> Dictionary:
	var action: Dictionary = PlayerInput.sample()
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
		if _lap_started and _target < Course.checkpoints(Course.PRESETS[selected]).size():
			_lap_ticks += runtime.tick - before
		_check_targets(state)
	_present(state)


func _check_targets(state: Dictionary) -> void:
	var points: PackedVector2Array = Course.checkpoints(Course.PRESETS[selected])
	if _target >= points.size() or state.actor.is_empty():
		return
	if Vector2(state.actor.position).distance_to(points[_target]) <= 15.0:
		_target += 1
		if _target == points.size():
			var id: StringName = Course.PRESETS[selected]
			_best_times[id] = mini(_lap_ticks, int(_best_times.get(id, 2147483647)))


func _content_rect() -> Rect2:
	var fit: float = minf(_canvas.size.x / float(Course.VIEW.size.x), _canvas.size.y / float(Course.VIEW.size.y))
	var dimensions: Vector2 = Vector2(Course.VIEW.size) * maxf(0.0, fit)
	return Rect2((_canvas.size - dimensions) * 0.5, dimensions)


func _present(state: Dictionary, force: bool = false) -> void:
	if _surface == null or state.actor.is_empty():
		return
	var actor: Dictionary = state.actor
	var position: Vector2 = actor.get("position", Vector2(178, 310))
	_view = Course.VIEW
	if _follow:
		_view = Rect2i(clampi(floori(position.x) - 128, 128, 384), clampi(floori(position.y) - 64, 128, 256), 256, 128)
	_surface._material.set_shader_parameter("camera_origin_px", Vector2(_view.position))
	_surface._material.set_shader_parameter("view_size_px", Vector2(_view.size))
	var presentation_error: String = ""
	if force or _last_packet_epoch != runtime.epoch or _last_draw_tick != runtime.tick:
		var packet: Dictionary = runtime.take_render_packet(force or _last_packet_epoch != runtime.epoch)
		if not packet.is_empty() and not _surface.apply_packet(packet):
			presentation_error = "Presentation refused: " + _surface.last_rejection
		_last_packet_epoch = runtime.epoch
		_last_draw_tick = runtime.tick
	_overlay.targets = Course.checkpoints(Course.PRESETS[selected])
	_overlay.target_index = _target
	_overlay.accent = Course.COLORS[selected]
	_overlay.actor_position = position
	_overlay.material_field = bool(state.material_mode)
	_overlay.movement = actor.get("player_movement", {})
	_overlay.preset = Course.PRESETS[selected]
	_overlay.present(runtime.render_parts(), Vector2(_view.position), _view.size, _content_rect())
	_overlay.visible = true
	_overlay.queue_redraw()
	var complete: bool = _target >= _overlay.targets.size()
	_timing.text = ("COURSE CLEAR" if complete else "GATES  %d / %d" % [_target, _overlay.targets.size()]) + "    %05.2f s" % (float(_lap_ticks) / 60.0)
	if _best_times.has(Course.PRESETS[selected]):
		_timing.text += "    BEST  %.2f s" % (float(_best_times[Course.PRESETS[selected]]) / 60.0)
	if not presentation_error.is_empty():
		_status.text = presentation_error
	elif runtime.failed:
		_status.text = "Stopped: " + runtime.last_error
	elif runtime.paused:
		_status.text = "Ten-minute run complete — press R or P for a fresh run." if runtime.last_error == "tick_limit" else "PAUSED — press P to resume."
	elif _rearm:
		_status.text = "Release movement buttons to take control."
	elif state.material_mode:
		var field: Dictionary = actor.get("field", {})
		_status.text = "%s   ·   %d local parcels   ·   %d moved this tick" % ["SAND CLOUD" if selected == 4 else "WATER BLOB", int(field.get("controlled_cells", 0)), int(field.get("moved_cells", 0))]
	else:
		var movement: Dictionary = actor.get("player_movement", {})
		var mode: String = str(movement.get("movement_mode", movement.get("mode", "ready"))).replace("_", " ").to_upper()
		_status.text = "%s   ·   SPEED %.1f cells/s   ·   %s" % [mode, Vector2(actor.get("velocity", Vector2.ZERO)).length(), "SUPPORTED" if bool(actor.get("grounded", false)) else "AIRBORNE"]
	if state.material_mode:
		_hint.text = "The faint ring shows your local control field. Nearby matching material can join it. Solid walls block the parcels; try the narrow sieve on the right."
	elif selected == 2:
		_hint.text = "Try: build speed → hold Shift → aim the mouse → Space for a bullet jump → C to glide. Tuck early for the low tunnel; releasing a short slide starts a roll."
	elif selected in [0, 1]:
		_hint.text = "Use the ramp to clear the tunnel roof. Lean before landing, then brake to settle. The empty equipment mount can be equipped later from F5 in the actor sandbox."
	else:
		_hint.text = "Thread the numbered flight gates. Main thrust follows your body's orientation; use rotation and airbraking to turn the next corner."


func _exit_tree() -> void:
	if runtime != null:
		runtime.close()
