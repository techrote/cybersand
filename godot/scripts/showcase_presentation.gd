class_name CyberShowcasePresentation
extends RefCounted

# Scene-specific art direction consumes only the existing immutable render
# textures. Native materials, the player and their edits remain authoritative.
const Tiles = preload("res://scripts/showcase_tiles.gd")

var host: Control
var controls: VBoxContainer
var launch_button: Button
var tile_picker: OptionButton
var up_button: Button
var down_button: Button
var view_row: HBoxContainer
var view_picker: OptionButton
var atmosphere_button: CheckButton
var hint: Label
var overlay: ColorRect
var shader: ShaderMaterial
var atmosphere_enabled: bool = true
var selected_view: int = 0
var _wait_for_pointer_release: bool = false

func setup(controller: Control) -> void:
	host = controller
	controls = VBoxContainer.new()
	controls.name = "ShowcaseControls"
	controls.add_theme_constant_override("separation", 4)
	var layout: VBoxContainer = host.get_node("Layout")
	layout.add_child(controls)
	layout.move_child(controls, 1)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	controls.add_child(navigation)
	launch_button = Button.new()
	launch_button.name = "NeonReliquaryLauncher"
	launch_button.text = "Neon Reliquary / F11"
	launch_button.focus_mode = Control.FOCUS_NONE
	launch_button.pressed.connect(launch)
	navigation.add_child(launch_button)
	tile_picker = OptionButton.new()
	tile_picker.name = "ShowcaseDistricts"
	tile_picker.focus_mode = Control.FOCUS_NONE
	tile_picker.tooltip_text = "Choose a district. Changing district loads its original layout."
	for index: int in range(Tiles.RECIPES.size()):
		tile_picker.add_item("%02d / %s" % [index + 1, Tiles.RECIPES[index].TITLE])
	tile_picker.item_selected.connect(_select_tile)
	tile_picker.get_popup().about_to_popup.connect(_release_pointer)
	tile_picker.get_popup().popup_hide.connect(_release_pointer)
	navigation.add_child(tile_picker)
	up_button = Button.new()
	up_button.text = "↑ Above"
	up_button.focus_mode = Control.FOCUS_NONE
	up_button.tooltip_text = "Load the original layout of the district above."
	up_button.pressed.connect(func() -> void: move_tile(-1))
	navigation.add_child(up_button)
	down_button = Button.new()
	down_button.text = "Below ↓"
	down_button.focus_mode = Control.FOCUS_NONE
	down_button.tooltip_text = "Load the original layout of the district below."
	down_button.pressed.connect(func() -> void: move_tile(1))
	navigation.add_child(down_button)
	view_row = HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 12)
	controls.add_child(view_row)
	view_picker = OptionButton.new()
	view_picker.name = "ShowcaseViewpoints"
	view_picker.focus_mode = Control.FOCUS_NONE
	view_picker.item_selected.connect(frame_view)
	view_picker.get_popup().about_to_popup.connect(_release_pointer)
	view_picker.get_popup().popup_hide.connect(_release_pointer)
	view_row.add_child(view_picker)
	atmosphere_button = CheckButton.new()
	atmosphere_button.text = "Distant city"
	atmosphere_button.focus_mode = Control.FOCUS_NONE
	atmosphere_button.button_pressed = atmosphere_enabled
	atmosphere_button.toggled.connect(func(enabled: bool) -> void:
		atmosphere_enabled = enabled
	)
	view_row.add_child(atmosphere_button)
	hint = Label.new()
	hint.text = "P animate · arrows explore · F8 clean view"
	hint.add_theme_font_size_override("font_size", 14)
	view_row.add_child(hint)

	shader = ShaderMaterial.new()
	shader.shader = load("res://shaders/neon_reliquary_backdrop.gdshader")
	overlay = ColorRect.new()
	overlay.name = "NeonReliquaryBackdrop"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = shader
	overlay.visible = false
	host.world_view.add_child(overlay)
	# The ordinary material glow stays above this empty-space backdrop.
	host.world_view.move_child(overlay, 0)
	refresh()

func current_scenario_id() -> String:
	if not host.tower_context.get("micro_active", false):
		return ""
	return str(host.tower_context.get("microscenario", {}).get("id", ""))

func active() -> bool:
	return Tiles.contains(current_scenario_id())

func _request_blocked() -> bool:
	return (not host.pending_microscenario_apply.is_empty()
		or not host.pending_water_apply.is_empty()
		or not host.pending_water_exit.is_empty()
		or not host.pending_player_environment_profile.is_empty()
		or not host.water_blind_set.is_empty()
		or not host.water_active_blind_label.is_empty()
		or (host.has_method("showcase_launch_blocked") and host.showcase_launch_blocked())
		or (host.microscenario_panel != null and host.microscenario_panel.modal_open())
		or (host.tower_profile_panel != null and host.tower_profile_panel.visible)
		or (host.water_experiment_panel != null and host.water_experiment_panel.visible))

func launch(tile_id: String = "showcase/neon-reliquary") -> bool:
	var source: GDScript = Tiles.recipe(tile_id)
	if source == null or _request_blocked():
		return false
	host.get_viewport().gui_release_focus()
	var accepted: bool = host.microscenario_launch(source.SCENARIO_ID, "Play", 0)
	if accepted:
		_release_pointer()
	return accepted

func _select_tile(index: int) -> void:
	if index >= 0 and index < Tiles.RECIPES.size():
		launch(Tiles.RECIPES[index].SCENARIO_ID)
	# Queued or refused requests never advertise an unacknowledged district.
	var installed_index: int = Tiles.index_of(current_scenario_id())
	if installed_index >= 0:
		tile_picker.select(installed_index)

func move_tile(direction: int) -> bool:
	if not active() or not direction in [-1, 1]:
		return false
	var destination: int = Tiles.index_of(current_scenario_id()) + direction
	if destination < 0 or destination >= Tiles.RECIPES.size():
		return false
	return launch(Tiles.RECIPES[destination].SCENARIO_ID)

func installed(definition: Dictionary) -> void:
	var id: String = str(definition.get("id", ""))
	if not Tiles.contains(id):
		return
	view_picker.clear()
	for view: Dictionary in Tiles.viewpoints(id):
		view_picker.add_item(str(view.name))
	tile_picker.select(Tiles.index_of(id))
	frame_view(0)
	host.get_node("Layout/Title").text = "CYBERSAND / " + Tiles.title(id).to_upper()

func frame_view(index: int) -> bool:
	var views: Array[Dictionary] = Tiles.viewpoints(current_scenario_id())
	if not active() or index < 0 or index >= views.size():
		return false
	selected_view = index
	_release_pointer()
	view_picker.select(index)
	host.current_view_size = views[index].size
	host.camera_origin = views[index].origin
	host.camera_follow_enabled = false
	# Each existing controller forwards its normal camera interest on the next
	# frame. Framing neither resets nor advances the installed material world.
	return true

func _release_pointer() -> void:
	_wait_for_pointer_release = true
	if host.has_method("release_game_input"):
		host.release_game_input()

func input_blocked() -> bool:
	if ((view_picker != null and view_picker.get_popup().visible)
		or (tile_picker != null and tile_picker.get_popup().visible)):
		return true
	if not _wait_for_pointer_release:
		return false
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		return true
	_wait_for_pointer_release = false
	return false

func refresh() -> void:
	var showing: bool = active()
	var tile_index: int = Tiles.index_of(current_scenario_id())
	var blocked: bool = _request_blocked()
	controls.visible = not host.microscenario_hud_hidden
	launch_button.disabled = blocked
	tile_picker.visible = showing
	tile_picker.disabled = blocked
	up_button.visible = showing
	down_button.visible = showing
	up_button.disabled = blocked or tile_index <= 0
	down_button.disabled = blocked or tile_index >= Tiles.RECIPES.size() - 1
	if showing:
		tile_picker.select(tile_index)
	view_row.visible = showing
	view_picker.visible = showing
	view_picker.disabled = blocked
	atmosphere_button.visible = showing
	hint.visible = showing
	if showing and host.microscenario_hud_hidden and host.brush_preview != null:
		host.brush_preview.visible = false
	# Edited definitions can retain this scene ID while admitting bodies. Such a
	# variant has no backdrop body mask, so retain the ordinary renderer there.
	overlay.visible = (showing and atmosphere_enabled and host.texture != null
		and host.rigid_bodies.is_empty())
	if not overlay.visible:
		return
	var content: Rect2 = host.view_content_rect()
	overlay.position = content.position
	overlay.size = content.size
	shader.set_shader_parameter("current_world_texture", host.texture)
	shader.set_shader_parameter("previous_world_texture", host.previous_texture)
	shader.set_shader_parameter("view_size_px", Vector2(host.current_view_size))
	shader.set_shader_parameter("camera_origin_px", host.camera_origin.floor())
	shader.set_shader_parameter("district_index", tile_index)
	shader.set_shader_parameter("snapshot_blend",
		host.world_shader.get_shader_parameter("snapshot_blend"))
	shader.set_shader_parameter("player_origin_px",
		host.world_shader.get_shader_parameter("player_origin_px"))
	shader.set_shader_parameter("player_size_px", CyberSampledCharacter.BODY_SIZE)
