class_name CyberBlacksiteNinePresentation
extends RefCounted

const Trial = preload("res://scripts/physical_actor_trial.gd")
# One presentation owner serves both continuous installations, so direct
# scene switches retain one minimum-size lease and one modal release gate.
const Scene = preload("res://scripts/blacksite_nine.gd")
const Grey = preload("res://scripts/grey_area_51.gd")
const GreyLayout = preload("res://scripts/grey_area_51_layout.gd")
const Layout = preload("res://scripts/blacksite_nine_layout.gd")
var host: Control
var controls: HBoxContainer
var launch_button: Button
var grey_launch_button: Button
var map_grid: GridContainer
var map_heading: Label
var _configured_grey: bool = false
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
	grey_launch_button = _button(launch_row, "Grey Area 51 / Ctrl+F11", launch_grey)
	launch_row.move_child(grey_launch_button, 2)
	grey_launch_button.name = "GreyArea51Launcher"
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
	map_heading = heading
	var grid := GridContainer.new()
	map_grid = grid
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
		or grey_active()
		or Trial.contains(str(host.tower_context.get("microscenario", {}).get("id", "")))))

func grey_active() -> bool:
	return (host.tower_context.get("micro_active",false)
		and str(host.tower_context.get("microscenario", {}).get("id", "")) == Grey.SCENARIO_ID)

func current_title() -> String:
	return Grey.TITLE if grey_active() else Scene.TITLE

func follow_view_size() -> Vector2i:
	return Vector2i(320,192) if grey_active() else Vector2i(480,270)

func _tile_count() -> int:
	return 5 if grey_active() else 9

func _layout() -> GDScript:
	return GreyLayout if grey_active() else Layout

func _views() -> Array[Dictionary]:
	return Grey.viewpoints() if grey_active() else Scene.viewpoints()

func _configure_scene() -> void:
	var grey: bool = grey_active()
	map_button.text = "5×1 tile map" if grey else "3×3 tile map"
	overview_button.text = "Whole bunker" if grey else "Whole complex"
	map_heading.text = current_title().to_upper() + " / TILE VIEWS"
	map_grid.columns = 5 if grey else 3
	for index: int in range(tile_buttons.size()):
		var button: Button = tile_buttons[index]
		button.visible = index < _tile_count()
		if not button.visible: continue
		button.text = _layout().CODES[index] + " · " + _layout().TITLES[index]
		button.custom_minimum_size = Vector2(170 if grey else 205,38)
		button.tooltip_text = _description(index)
	if grey != _configured_grey:
		var prefix: String = "grey_area_51" if grey else "blacksite_nine"
		shader.shader = load("res://shaders/" + prefix + "_backdrop.gdshader")
		grade_shader.shader = load("res://shaders/" + prefix + "_grade.gdshader")
		_configured_grey = grey

func _request_blocked() -> bool:
	# Both scene launchers obey the same existing owner/modal admission boundary.
	return host.showcase_presentation._request_blocked()

func launch() -> bool:
	if _request_blocked(): return false
	host.get_viewport().gui_release_focus()
	var accepted: bool = host.microscenario_launch(Scene.SCENARIO_ID, "Play", 0)
	if accepted: _release_pointer()
	return accepted

func launch_grey() -> bool:
	if _request_blocked(): return false
	host.get_viewport().gui_release_focus()
	var accepted: bool = host.microscenario_launch(Grey.SCENARIO_ID, "Play", 0)
	if accepted: _release_pointer()
	return accepted

func installed(definition: Dictionary) -> void:
	if str(definition.get("id", "")) not in [Scene.SCENARIO_ID,Grey.SCENARIO_ID] and not Trial.contains(str(definition.get("id", ""))): return
	_configure_scene()
	_apply_frame(0)
	host.get_node("Layout/Title").text = ("CYBERSAND / " + str(definition.presentation.title)
		if Trial.contains(str(definition.id)) else "CYBERSAND / " + current_title().to_upper())

func show_map() -> void:
	if not active() or _request_blocked(): return
	_release_pointer()
	map_popup.popup_centered(Vector2i(940,160) if grey_active() else Vector2i(700,236))

func frame_tile(index: int) -> bool:
	if index < 0 or index >= _tile_count(): return false
	return frame_view(index + 1)

func frame_view(index: int) -> bool:
	if not active() or _request_blocked() or index < 0 or index > _tile_count(): return false
	_apply_frame(index)
	return true

func _apply_frame(index: int) -> void:
	selected_view = index
	_release_pointer()
	var view: Dictionary = _views()[index]
	host.current_view_size = view.size
	host.camera_origin = view.origin
	host.camera_follow_enabled = false
	# No native calls, reset commands, player movement or simulation policy edits.

func move_tile(direction: Vector2i) -> bool:
	if selected_view <= 0 or absi(direction.x) + absi(direction.y) != 1: return false
	var columns: int = 5 if grey_active() else 3
	var rows: int = 1 if grey_active() else 3
	var current := Vector2i((selected_view - 1) % columns, (selected_view - 1) / columns)
	var target: Vector2i = current + direction
	if target.x < 0 or target.y < 0 or target.x >= columns or target.y >= rows: return false
	return frame_tile(target.y * columns + target.x)

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
	# Actor trim, vertical movement and usable keys must also be released;
	# a held non-horizontal command cannot leak out of the tile map.
	var keys: Array = host.ACTOR_CONTROL_KEYS + host.PHYSICAL_TOOL_KEYS + [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]
	for key: Key in keys:
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
	grey_launch_button.disabled = blocked
	for button: Button in [map_button, overview_button, follow_button]:
		button.visible = showing
		button.disabled = blocked
	atmosphere_button.visible = showing
	current_label.visible = showing
	if not showing or host.microscenario_hud_hidden:
		map_popup.hide()
	if showing:
		var player_tile: int = _layout().tile_at(host.character_centre())
		current_label.text = ("Player: " + _layout().CODES[player_tile] + " / " + _layout().TITLES[player_tile]
			if player_tile >= 0 else "Player outside the complex")
		for index: int in range(_tile_count()):
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
	# Material colour and glow are below this grade. Sampled rig hulls, energy
	# bars, ropes, usables and brush cursors remain foreground presentation.
	var foreground: Array[Node] = []
	var reorder: bool = host.glow_overlay != null and host.glow_overlay.get_index() > grade_overlay.get_index()
	for name: String in ["ActorPrototypeOverlay","UsableOverlay","PhysicalActorOverlay","BrushPreview"]:
		var node: Node = host.world_view.get_node_or_null(name)
		if node == null: continue
		foreground.append(node)
		reorder = reorder or node.get_index() < grade_overlay.get_index()
	if reorder:
		host.world_view.move_child(grade_overlay,-1)
		for node: Node in foreground: host.world_view.move_child(node,-1)
	for parameter: String in ["current_world_texture", "previous_world_texture", "view_size_px",
		"camera_origin_px", "snapshot_blend", "player_origin_px", "player_size_px"]:
		grade_shader.set_shader_parameter(parameter, shader.get_shader_parameter(parameter))

func _description(index: int) -> String:
	if grey_active(): return GreyLayout.DESCRIPTIONS[index]
	return ["Collapsed viaduct, buried intake bunker and the western maintenance well.",
		"Fortified research laboratories above the main containment throat.",
		"Ashworks salvage trenches, a wrecked cargo tram and the eastern service descent.",
		"Worker cells around the freight cage and the route to the furnace.",
		"A monitor theatre and containment galleries at the heart of the blacksite.",
		"Pressure columns and condensate machinery above the blackwater return well.",
		"Buried crushing machinery and a low transfer tunnel into the instrument vault.",
		"Pressure vessels, cable shrines and the utility shaft to containment.",
		"A flooded pump terminus with a dry route back to the eastern surface."][index]
