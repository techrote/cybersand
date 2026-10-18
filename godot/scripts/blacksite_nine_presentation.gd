class_name CyberBlacksiteNinePresentation
extends RefCounted

const Trial = preload("res://scripts/physical_actor_trial.gd")
const Scene = preload("res://scripts/blacksite_nine.gd")
const Layout = preload("res://scripts/blacksite_nine_layout.gd")
var host: Control
var controls: HBoxContainer
var launch_button: Button
var map_button: Button
var overview_button: Button
var follow_button: Button
var atmosphere_button: CheckButton
var current_label: Label
var map_popup: PopupPanel
var tile_buttons: Array[Button] = []
var overlay: ColorRect
var shader: ShaderMaterial
var grade_overlay: ColorRect
var grade_shader: ShaderMaterial
var atmosphere_enabled: bool = true
var selected_view: int = 0
var _wait_for_pointer_release: bool = false
var _wait_for_keyboard_release: bool = false
var _world_minimum_before_active: Vector2 = Vector2.ZERO
var _world_minimum_relaxed: bool = false

func setup(controller: Control) -> void:
	host = controller
	controls = HBoxContainer.new()
	controls.name = "BlacksiteNineControls"
	controls.add_theme_constant_override("separation", 12)
	var layout: VBoxContainer = host.get_node("Layout")
	layout.add_child(controls)
	layout.move_child(controls, host.showcase_presentation.controls.get_index() + 1)
	var launch_row: HBoxContainer = host.showcase_presentation.launch_button.get_parent()
	launch_button = _button(launch_row, "Blacksite Nine / Shift+F11", launch)
	launch_row.move_child(launch_button, 1)
	launch_button.name = "BlacksiteNineLauncher"
	map_button = _button(controls, "3×3 tile map", show_map)
	overview_button = _button(controls, "Whole complex", func() -> void: frame_view(0))
	follow_button = _button(controls, "Follow player / F", follow_player)
	atmosphere_button = CheckButton.new()
	atmosphere_button.text = "Depth & haze"
	atmosphere_button.focus_mode = Control.FOCUS_NONE
	atmosphere_button.button_pressed = true
	atmosphere_button.toggled.connect(func(enabled: bool) -> void: atmosphere_enabled = enabled)
	controls.add_child(atmosphere_button)
	current_label = Label.new()
	current_label.add_theme_font_size_override("font_size", 14)
	current_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_label.clip_text = true
	controls.add_child(current_label)

	map_popup = PopupPanel.new()
	map_popup.name = "BlacksiteNineMap"
	host.add_child(map_popup)
	map_popup.popup_hide.connect(_release_pointer)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	map_popup.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var heading := Label.new()
	heading.text = "BLACKSITE NINE / TILE VIEWS"
	content.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for index: int in range(9):
		var button: Button = _button(grid, Layout.CODES[index] + " · " + Layout.TITLES[index],
			func() -> void:
				frame_tile(index)
				map_popup.hide())
		button.custom_minimum_size = Vector2(205, 38)
		button.tooltip_text = _description(index)
		tile_buttons.append(button)
	var help := Label.new()
	help.text = "A / D move · hold Space to rise · P animate · F8 clean view\nTile views move the camera. R restores the entire complex."
	help.add_theme_font_size_override("font_size", 14)
	content.add_child(help)

	shader = ShaderMaterial.new()
	shader.shader = load("res://shaders/blacksite_nine_backdrop.gdshader")
	overlay = ColorRect.new()
	overlay.name = "BlacksiteNineBackdrop"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = shader
	overlay.visible = false
	host.world_view.add_child(overlay)
	host.world_view.move_child(overlay, 0)
	grade_shader = ShaderMaterial.new()
	grade_shader.shader = load("res://shaders/blacksite_nine_grade.gdshader")
	grade_overlay = ColorRect.new()
	grade_overlay.name = "BlacksiteNineExposure"
	grade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_overlay.material = grade_shader
	grade_overlay.visible = false
	host.world_view.add_child(grade_overlay)
	refresh()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func active() -> bool:
	return (host.tower_context.get("micro_active", false)
		and (str(host.tower_context.get("microscenario", {}).get("id", "")) == Scene.SCENARIO_ID
		or Trial.contains(str(host.tower_context.get("microscenario", {}).get("id", "")))))

func _request_blocked() -> bool:
	# Both scene launchers obey the same existing owner/modal admission boundary.
	return host.showcase_presentation._request_blocked()

func launch() -> bool:
	if _request_blocked(): return false
	host.get_viewport().gui_release_focus()
	var accepted: bool = host.microscenario_launch(Scene.SCENARIO_ID, "Play", 0)
	if accepted: _release_pointer()
	return accepted

func installed(definition: Dictionary) -> void:
	if str(definition.get("id", "")) != Scene.SCENARIO_ID and not Trial.contains(str(definition.get("id", ""))): return
	_apply_frame(0)
	host.get_node("Layout/Title").text = ("CYBERSAND / " + str(definition.presentation.title)
		if Trial.contains(str(definition.id)) else "CYBERSAND / BLACKSITE NINE")

func show_map() -> void:
	if not active() or _request_blocked(): return
	_release_pointer()
	map_popup.popup_centered(Vector2i(700, 236))

func frame_tile(index: int) -> bool:
	if index < 0 or index >= 9: return false
	return frame_view(index + 1)

func frame_view(index: int) -> bool:
	if not active() or _request_blocked() or index < 0 or index >= 10: return false
	_apply_frame(index)
	return true

func _apply_frame(index: int) -> void:
	selected_view = index
	_release_pointer()
	var view: Dictionary = Scene.viewpoints()[index]
	host.current_view_size = view.size
	host.camera_origin = view.origin
	host.camera_follow_enabled = false
	# No native calls, reset commands, player movement or simulation policy edits.

func move_tile(direction: Vector2i) -> bool:
	if selected_view <= 0 or absi(direction.x) + absi(direction.y) != 1: return false
	var current := Vector2i((selected_view - 1) % 3, (selected_view - 1) / 3)
	var target: Vector2i = current + direction
	if target.x < 0 or target.y < 0 or target.x >= 3 or target.y >= 3: return false
	return frame_tile(target.y * 3 + target.x)

func follow_player() -> bool:
	if not active() or _request_blocked(): return false
	_release_pointer()
	return host.set_camera_follow(true)

func _release_pointer() -> void:
	_wait_for_pointer_release = true
	_wait_for_keyboard_release = true
	if host.has_method("release_game_input"): host.release_game_input()

func keyboard_blocked() -> bool:
	if map_popup != null and map_popup.visible:
		_wait_for_keyboard_release = true
		return true
	if not _wait_for_keyboard_release: return false
	for key: Key in [KEY_A,KEY_D,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
		if Input.is_key_pressed(key) or Input.is_physical_key_pressed(key): return true
	_wait_for_keyboard_release = false
	return false

func input_blocked() -> bool:
	if map_popup != null and map_popup.visible: return true
	if not _wait_for_pointer_release: return false
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)): return true
	_wait_for_pointer_release = false
	return false

func refresh() -> void:
	var showing: bool = active()
	var blocked: bool = _request_blocked()
	controls.visible = showing and not host.microscenario_hud_hidden
	# Let the world share the available height with district navigation. Restore
	# the caller's original minimum when leaving this scene.
	if showing and not _world_minimum_relaxed:
		_world_minimum_before_active = host.world_view.custom_minimum_size
		host.world_view.custom_minimum_size = Vector2(_world_minimum_before_active.x, 0)
		_world_minimum_relaxed = true
	elif not showing and _world_minimum_relaxed:
		host.world_view.custom_minimum_size = _world_minimum_before_active
		_world_minimum_relaxed = false
	launch_button.disabled = blocked
	for button: Button in [map_button, overview_button, follow_button]:
		button.visible = showing
		button.disabled = blocked
	atmosphere_button.visible = showing
	current_label.visible = showing
	if not showing or host.microscenario_hud_hidden:
		map_popup.hide()
	if showing:
		var player_tile: int = Layout.tile_at(host.character_position + Vector2(4,7))
		current_label.text = ("Player: " + Layout.CODES[player_tile] + " / " + Layout.TITLES[player_tile]
			if player_tile >= 0 else "Player outside the complex")
		for index: int in range(9):
			tile_buttons[index].modulate = Color(0.75, 0.94, 0.92) if index == player_tile else Color.WHITE
		if host.microscenario_hud_hidden and host.brush_preview != null:
			host.brush_preview.visible = false
	overlay.visible = showing and atmosphere_enabled and host.texture != null and host.rigid_bodies.is_empty()
	grade_overlay.visible = overlay.visible
	if not overlay.visible: return
	var content: Rect2 = host.view_content_rect()
	overlay.position = content.position
	overlay.size = content.size
	shader.set_shader_parameter("current_world_texture", host.texture)
	shader.set_shader_parameter("previous_world_texture", host.previous_texture)
	shader.set_shader_parameter("view_size_px", Vector2(host.current_view_size))
	shader.set_shader_parameter("camera_origin_px", host.camera_origin.floor())
	shader.set_shader_parameter("snapshot_blend", host.world_shader.get_shader_parameter("snapshot_blend"))
	shader.set_shader_parameter("player_origin_px", host.world_shader.get_shader_parameter("player_origin_px"))
	shader.set_shader_parameter("player_size_px", CyberSampledCharacter.BODY_SIZE)
	grade_overlay.position = content.position
	grade_overlay.size = content.size
	if grade_overlay.get_index() != host.world_view.get_child_count() - 1:
		host.world_view.move_child(grade_overlay, -1)
	for parameter: String in ["current_world_texture", "previous_world_texture", "view_size_px",
		"camera_origin_px", "snapshot_blend", "player_origin_px", "player_size_px"]:
		grade_shader.set_shader_parameter(parameter, shader.get_shader_parameter(parameter))

func _description(index: int) -> String:
	return ["Collapsed viaduct, buried intake bunker and the western maintenance well.",
		"Fortified research laboratories above the main containment throat.",
		"Ashworks salvage trenches, a wrecked cargo tram and the eastern service descent.",
		"Worker cells around the freight cage and the route to the furnace.",
		"A monitor theatre and containment galleries at the heart of the blacksite.",
		"Pressure columns and condensate machinery above the blackwater return well.",
		"Buried crushing machinery and a low transfer tunnel into the instrument vault.",
		"Pressure vessels, cable shrines and the utility shaft to containment.",
		"A flooded pump terminus with a dry route back to the eastern surface."][index]
