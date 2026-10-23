extends Control

# One declarative hierarchy, four native worlds, one explicit admission point.
# Camera state belongs only to the compositor. Play actors arrive as copied
# owner snapshots; this viewer creates no bodies and infers no pixel events.
const Runtime = preload("res://scripts/depth/semantic_plane_runtime.gd")
const DepthCompositor = preload("res://scripts/depth/depth_compositor.gd")
const ActorOverlay = preload("res://scripts/actor_prototype_overlay.gd")
const EXAMPLES: Array[String] = ["semantic-refinery", "semantic-flooded-cavern"]
const TITLES: Array[String] = ["THE REFINERY / service galleries", "THE DROWNED VAULT / flooded caverns"]
const REGION_TITLES: Array = [
	["Intake Foundry", "Reactor Gallery", "Condensate Works", "Service Vaults"],
	["Basalt Threshold", "Drowned Archive", "Spillway Chamber", "Mineral Cathedral"],
]
const REGION_NOTES: Array = [
	["Cast platforms and copper trunks above the rear reactor. Vents lift the heat into a separate atmosphere.",
	 "Inspection windows frame distant towers. The rear reactor runs its own native chemistry.",
	 "Water falls into the service basin while an independently scheduled spray marks the same drop.",
	 "Pipe geometry and machinery footprints share their semantic owners through every plane."],
	["Dark basalt ribs shelter a flooded lower passage. Sparse fog is an intentional local layer.",
	 "Ruined masonry and rear conduits sit inside one cavern hierarchy, with a frozen mineral silhouette beyond.",
	 "A bounded spring feeds real Water. Its matching atmospheric spray is a separate source programme.",
	 "Broken windows reveal distant columns; cold stone, copper and quartz define the abandoned apparatus."],
]
const PLANE_IDS: Array[String] = ["play", "scripted", "effects", "background"]
const PLANE_NAMES: Array[String] = ["Play terrain", "Rear machinery", "Atmosphere", "Distant architecture"]
const ACCENT := Color(0.36, 0.88, 0.81)
const MUTED := Color(0.60, 0.70, 0.72)

var generator: Variant
var runtime: Variant
var compositor: CyberDepthCompositor
var recipe: Dictionary = {}
var bundle: Dictionary = {}
var example_index: int = 0
var selected_region: int = -1
var paused: bool = true
var faulted: bool = false
var hud_visible: bool = true
var presentation_time: float = 0.0
var last_error: String = ""
var _top: PanelContainer
var _side: PanelContainer
var _footer: Label
var _title: Label
var _region_title: Label
var _region_note: Label
var _status: Label
var _pause_button: Button
var _example_picker: OptionButton
var _layer_visibility := Vector4.ONE
var _visibility_buttons: Array[CheckBox] = []
var _actor_overlay: CyberActorPrototypeOverlay
var _dragging: bool = false
var _message: String = "Space runs the sources. Select a gallery to inspect its layers."
var _status_clock: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.018, 0.027, 0.034)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_actor_overlay = ActorOverlay.new()
	_actor_overlay.name = "PlayActors"
	add_child(_actor_overlay)
	_build_ui()
	resized.connect(_layout)
	var initial: int = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--semantic-example=cavern": initial = 1
	if not load_example(initial):
		faulted = true
		_message = last_error
	_layout()
	_update_status()

func load_example(index: int) -> bool:
	if index < 0 or index >= EXAMPLES.size():
		last_error = "Unknown semantic-depth example"
		return false
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		last_error = "Semantic depth requires the current native generator"
		return false
	var path: String = ProjectSettings.globalize_path("res://../examples/worldgen/%s.json" % EXAMPLES[index])
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary:
		last_error = "Could not read " + EXAMPLES[index]
		return false
	var candidate_generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var configured: Dictionary = candidate_generator.configure(raw)
	if not bool(configured.get("ok", false)):
		last_error = str(configured.get("error", "Semantic recipe was rejected"))
		return false
	var candidate_bundle: Dictionary = candidate_generator.generate_plane_bundle()
	if not bool(candidate_bundle.get("ok", false)):
		last_error = str(candidate_bundle.get("error", "Semantic bundle was rejected"))
		return false
	var candidate_runtime: Variant = Runtime.new()
	if not candidate_runtime.install_bundle(candidate_bundle):
		last_error = candidate_runtime.last_error
		return false
	var candidate_compositor: CyberDepthCompositor = _prepare_compositor(candidate_runtime)
	if candidate_compositor == null:
		return false
	# No await/draw occurs between owner admission and all four presentation
	# packets. A failed candidate leaves the visible accepted scene untouched.
	var previous: CyberDepthCompositor = compositor
	generator = candidate_generator
	runtime = candidate_runtime
	recipe = raw.duplicate(true)
	bundle = candidate_bundle.duplicate(true)
	example_index = index
	compositor = candidate_compositor
	add_child(compositor)
	move_child(compositor, 1)
	compositor.gui_input.connect(_map_input)
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	paused = true
	faulted = false
	presentation_time = 0.0
	selected_region = -1
	_layer_visibility = Vector4.ONE
	for box: CheckBox in _visibility_buttons: box.set_pressed_no_signal(true)
	_example_picker.select(index)
	_title.text = TITLES[index]
	_message = "Four related material planes are ready. Space starts their independent clocks."
	show_overview()
	_layout()
	_update_status()
	last_error = ""
	return true

func _prepare_compositor(owner: Variant) -> CyberDepthCompositor:
	var candidate := DepthCompositor.new()
	candidate.name = "DepthCompositor"
	candidate.layer_scale = Vector4.ONE
	candidate.layer_parallax = Vector4(1.0, 0.97, 0.95, 0.91)
	if not candidate.configure(owner.world_size):
		last_error = candidate.last_error
		candidate.free()
		return null
	candidate.set_view(Vector2.ZERO, Vector2(owner.world_size))
	candidate.set_options({"mode": "hybrid", "parallax_strength": 0.75,
		"relief_depth": 2.0, "relief_slices": 3, "fog_strength": 0.33,
		"reflection_strength": 0.12, "freeze_material_animation": true,
		"layer_visibility": Vector4.ONE})
	for plane: String in PLANE_IDS:
		var packet: Dictionary = owner.snapshot_layer(plane, true)
		if bool(packet.get("failed", false)) or not candidate.apply_layer_packet(plane, packet):
			last_error = "A complete %s publication was not admitted" % plane
			candidate.free()
			return null
	return candidate

func _process(delta: float) -> void:
	if faulted or runtime == null or compositor == null: return
	if not _input_blocked():
		var axis := Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
		if not axis.is_zero_approx(): compositor.set_camera(compositor.camera_origin + axis.normalized() * 100.0 * delta)
	if not paused:
		presentation_time += delta
		compositor.set_time(presentation_time)
	var result: Dictionary = runtime.advance(delta, paused)
	if not bool(result.get("ok", false)):
		_fault(str(result.get("error", runtime.last_error)))
		return
	if not publish_layers(): return
	_present_actors()
	_status_clock += delta
	if _status_clock >= 0.25:
		_status_clock = 0.0
		_update_status()

func publish_layers(force: bool = false) -> bool:
	for plane: String in PLANE_IDS:
		var packet: Dictionary = runtime.snapshot_layer(plane, force)
		if bool(packet.get("failed", false)):
			_fault(str(packet.get("error", "Native publication failed")))
			return false
		if bool(packet.get("unchanged", false)): continue
		if not compositor.apply_layer_packet(plane, packet):
			_fault("Presentation rejected the %s publication" % plane)
			return false
	return true

func reset_example() -> bool:
	if runtime == null: return false
	var result: Dictionary = runtime.reset_bundle(runtime.generation(), str(bundle.get("revision", "")))
	if not bool(result.get("accepted", result.get("ok", false))):
		last_error = str(result.get("error", runtime.last_error))
		_message = last_error
		_update_status()
		return false
	paused = true
	presentation_time = 0.0
	compositor.set_time(0.0)
	compositor.set_options({"freeze_material_animation": true})
	if not publish_layers(true): return false
	_message = "All four planes reset together. Previous event observations have expired."
	_update_status()
	_present_actors()
	return true

func toggle_pause() -> void:
	if faulted or runtime == null: return
	paused = not paused
	compositor.set_options({"freeze_material_animation": paused})
	_message = "Sources and material clocks paused." if paused else "Sources feed ordinary materials; native reactions make the products."
	_update_status()

func step_once() -> bool:
	if faulted or runtime == null: return false
	paused = true
	compositor.set_options({"freeze_material_animation": true})
	var result: Dictionary = runtime.step_once()
	if not bool(result.get("ok", false)):
		_fault(str(result.get("error", runtime.last_error)))
		return false
	if not publish_layers(): return false
	_message = "Advanced each active plane by one native tick. The distant plane stays frozen."
	_update_status()
	_present_actors()
	return true

func show_overview() -> void:
	if compositor == null: return
	selected_region = -1
	compositor.set_view(Vector2.ZERO, compositor.world_size)
	_region_title.text = "One place / four views"
	_region_note.text = "Choose a region below. Floors, pipes, vents and distant silhouettes all refer to the same authored features."
	_present_actors()
	_update_status()

func select_region(index: int) -> void:
	if compositor == null or index < 0 or index >= 4: return
	selected_region = index
	var extent: Vector2 = compositor.world_size * 0.5
	compositor.set_view(Vector2(index % 2, index / 2) * extent, extent)
	_region_title.text = REGION_TITLES[example_index][index]
	_region_note.text = REGION_NOTES[example_index][index]
	_present_actors()
	_update_status()

func set_hud_visible(enabled: bool) -> void:
	hud_visible = enabled
	_top.visible = enabled
	_side.visible = enabled
	_footer.visible = enabled
	_layout()

func set_layer_visible(index: int, enabled: bool) -> void:
	if index < 0 or index >= 4 or compositor == null: return
	_layer_visibility[index] = 1.0 if enabled else 0.0
	_visibility_buttons[index].set_pressed_no_signal(enabled)
	compositor.set_options({"layer_visibility": _layer_visibility})
	_present_actors()

func fire_event(kind: String) -> Dictionary:
	if runtime == null: return {"accepted": false, "error": "no_bundle"}
	for link: Dictionary in bundle.get("links", []):
		if str(link.get("effect", link.get("permitted_effect", ""))) != kind: continue
		if str(link.get("classification", "")) != "runtime": continue
		if selected_region >= 0:
			var window: Array = recipe.grammar.region_window
			if int(link.owner_x) != int(window[0]) + selected_region % 2: continue
			if int(link.owner_y) != int(window[1]) + selected_region / 2: continue
		var observation: Dictionary = runtime.event_observation(str(link["id"]))
		if not bool(observation.get("accepted", false)): return observation
		var result: Dictionary = runtime.submit_event(observation)
		_message = ("Rear damage admitted for one bounded feature." if kind == "blast" else "A bounded vent event was admitted into the atmosphere.") if bool(result.get("accepted", false)) else str(result.get("error", "Event rejected"))
		_update_status()
		return result
	return {"accepted": false, "error": "no_matching_runtime_link"}

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _input_blocked(): return
	match event.keycode:
		KEY_SPACE, KEY_P: toggle_pause()
		KEY_N: step_once()
		KEY_R: reset_example()
		KEY_O: show_overview()
		KEY_TAB: set_hud_visible(not hud_visible)
		KEY_E: fire_event("blast")
		KEY_V: fire_event("burst")
		KEY_1, KEY_2, KEY_3, KEY_4: select_region(int(event.keycode) - KEY_1)
		KEY_ESCAPE: get_tree().change_scene_to_file("res://feature_launcher.tscn")
		_: return
	get_viewport().set_input_as_handled()

func _map_input(event: InputEvent) -> void:
	if compositor == null: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE: _dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor: float = 0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25
			var extent: Vector2 = (compositor.view_size * factor).clamp(Vector2(32, 32), compositor.world_size)
			var centre: Vector2 = compositor.camera_origin + compositor.view_size * 0.5
			compositor.set_view(centre - extent * 0.5, extent)
			accept_event()
	elif event is InputEventMouseMotion and _dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		compositor.set_camera(compositor.camera_origin - event.relative / compositor.content_rect().size * compositor.view_size)
		accept_event()

func _input_blocked() -> bool:
	return not get_window().has_focus() or get_viewport().gui_get_focus_owner() != null

func _present_actors() -> void:
	if _actor_overlay == null or compositor == null or runtime == null: return
	var rect: Rect2 = compositor.content_rect()
	rect.position += compositor.position
	_actor_overlay.present(runtime.actor_snapshot(), compositor.camera_origin, Vector2i(compositor.view_size), rect)
	_actor_overlay.visible = _actor_overlay.visible and _layer_visibility.x > 0.0

func _fault(message: String) -> void:
	faulted = true
	paused = true
	last_error = message
	_message = message
	push_error("SEMANTIC_DEPTH: " + message)
	_update_status()

func _build_ui() -> void:
	_top = PanelContainer.new()
	add_child(_top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	_top.add_child(bar)
	_title = Label.new()
	_title.add_theme_color_override("font_color", ACCENT)
	_title.add_theme_font_size_override("font_size", 20)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	_example_picker = OptionButton.new()
	_example_picker.focus_mode = Control.FOCUS_NONE
	_example_picker.add_item("Refinery galleries")
	_example_picker.add_item("Flooded cavern")
	_example_picker.item_selected.connect(func(index: int):
		if not load_example(index):
			_message = last_error
			_example_picker.select(example_index)
			_update_status())
	bar.add_child(_example_picker)
	_pause_button = _button("Run / Space", toggle_pause)
	bar.add_child(_pause_button)
	bar.add_child(_button("Step", step_once))
	bar.add_child(_button("Reset", reset_example))
	_side = PanelContainer.new()
	add_child(_side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_side.add_child(column)
	_region_title = Label.new()
	_region_title.add_theme_font_size_override("font_size", 19)
	_region_title.add_theme_color_override("font_color", ACCENT)
	column.add_child(_region_title)
	_region_note = Label.new()
	_region_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_region_note.add_theme_color_override("font_color", MUTED)
	column.add_child(_region_note)
	column.add_child(_button("Overview / O", show_overview))
	for index: int in range(4):
		var button: Button = _button("%d  /  Region %d" % [index + 1, index + 1], select_region.bind(index))
		button.name = "Region%d" % index
		column.add_child(button)
	column.add_child(HSeparator.new())
	var layers := Label.new()
	layers.text = "MATERIAL PLANES"
	layers.add_theme_color_override("font_color", MUTED)
	column.add_child(layers)
	for index: int in range(4):
		var box := CheckBox.new()
		box.text = PLANE_NAMES[index]
		box.button_pressed = true
		box.focus_mode = Control.FOCUS_NONE
		box.toggled.connect(func(enabled: bool): set_layer_visible(index, enabled))
		_visibility_buttons.append(box)
		column.add_child(box)
	column.add_child(HSeparator.new())
	column.add_child(_button("Rear breach / E", fire_event.bind("blast")))
	column.add_child(_button("Vent burst / V", fire_event.bind("burst")))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", MUTED)
	column.add_child(_status)
	var help := Label.new()
	help.text = "WASD / arrows pan\nWheel zooms · middle drag\n1–4 region · Tab hides controls\nF2 returns to the launcher"
	help.add_theme_color_override("font_color", MUTED)
	column.add_child(help)
	_footer = Label.new()
	_footer.add_theme_color_override("font_color", MUTED)
	_footer.clip_text = true
	add_child(_footer)

func _button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button

func _layout() -> void:
	if _top == null: return
	var side_width: float = 274.0
	_top.position = Vector2(14, 12)
	_top.size = Vector2(maxf(600, size.x - 28), 48)
	_side.position = Vector2(maxf(620, size.x - side_width - 14), 74)
	_side.size = Vector2(side_width, maxf(500, size.y - 112))
	_footer.position = Vector2(16, size.y - 29)
	_footer.size = Vector2(size.x - 32, 24)
	if compositor != null:
		compositor.position = Vector2(12, 74) if hud_visible else Vector2.ZERO
		compositor.size = Vector2(maxf(300, size.x - side_width - 42), maxf(300, size.y - 116)) if hud_visible else size
		_present_actors()

func _update_status() -> void:
	if _status == null: return
	_pause_button.text = "Run / Space" if paused else "Pause / Space"
	_status.text = _message
	if runtime == null:
		_footer.text = last_error
		return
	var ticks: Array[String] = []
	for plane: String in PLANE_IDS: ticks.append("%s %d" % [plane, runtime.layer_tick(plane)])
	_footer.text = "%s  ·  %s  ·  %d shared features / %d links / %d sources" % ["PAUSED" if paused else "RUNNING", " / ".join(ticks), bundle.get("features", []).size(), bundle.get("links", []).size(), bundle.get("fixtures", []).size()]
	for index: int in range(4):
		var button: Button = _side.find_child("Region%d" % index, true, false)
		if button != null: button.text = "%d  /  %s" % [index + 1, REGION_TITLES[example_index][index]]
