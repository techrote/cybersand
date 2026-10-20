extends SceneTree

const Map = preload("res://scripts/exhibition/deepworks_map.gd")
const Cell = preload("res://scripts/cell_world.gd")
var assertions: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://deepworks.tscn")
	var lab: Control = scene.instantiate()
	root.add_child(lab)
	lab.set_process(false)
	await process_frame
	_expect(lab.ui_ready and not lab.faulted, "Standalone exhibition opens a complete native map")
	_expect(lab.paused, "Pristine authored map starts paused")
	_expect(lab.compositor.world_size == Vector2(1024, 1024), "Host configures full authored world")
	_expect(lab.compositor.view_size == Vector2(1024, 1024), "Initial view covers the entire complex")
	var generation: int = lab.runtime.generation()
	for index: int in range(16):
		lab.select_district(index)
		_expect(lab.selected_district == index, "District selection " + str(index))
		_expect(lab.compositor.camera_origin == Vector2(Map.origin(index)), "District camera exactly matches full map coordinates")
		_expect(lab.runtime.generation() == generation and lab.runtime.layer_tick("play") == 0, "Camera selection preserves state")
		_expect(lab._district_title.text.contains(Map.TITLES[index]), "Guide follows selected district")
		for layer: String in ["play", "scripted"]:
			lab.focus_exhibit(layer)
			_expect(lab.compositor.view_size == Vector2(200, 200), "Detailed exhibit view uses intended extent")
			_expect(lab.runtime.generation() == generation, "Exhibit focus never reinstalls the world")
			for exhibit: Dictionary in lab.definition["exhibits"]:
				if exhibit["district"] == index and exhibit["layer"] == layer:
					var screen: Vector2 = lab.compositor.get_layer_screen_position(Vector2(exhibit["focus"]), Map.LAYERS.find(layer))
					_expect(lab.compositor.content_rect().has_point(screen), "Selected plane's actual exhibit remains in frame")
	for index: int in range(4):
		lab.set_layer_visible(index, false)
		_expect(lab.compositor.layer_visibility[index] == 0.0, "Layer isolate control")
		lab.set_layer_visible(index, true)
	for index: int in range(5):
		lab.select_mode(index)
		_expect(lab.mode_index == index, "All retained depth modes remain selectable")
	lab.select_mode(3)
	lab.select_district(0)
	var fore_probe := Vector2i(236, 223)
	var rear_before: int = lab.runtime.material_at("scripted", fore_probe)
	lab._layer_picker.select(0)
	lab._material_picker.select(0)
	lab._apply_pointer(lab.compositor.get_layer_screen_position(Vector2(fore_probe), 0), false)
	_expect(lab.runtime.material_at("play", fore_probe) == Cell.WATER, "Foreground pointer edit reaches native world")
	_expect(lab.runtime.material_at("scripted", fore_probe) == rear_before, "Foreground edit leaves background authority untouched")
	lab._layer_picker.select(1)
	var rear_probe := Vector2i(191, 105)
	var fore_before: int = lab.runtime.material_at("play", rear_probe)
	lab._apply_pointer(lab.compositor.get_layer_screen_position(Vector2(rear_probe), 1), false)
	_expect(lab.runtime.material_at("scripted", rear_probe) == Cell.WATER, "Rear edit uses inverse parallax transform")
	_expect(lab.runtime.material_at("play", rear_probe) == fore_before, "Rear edit does not leak into foreground")
	var before_view: Vector2 = lab.compositor.camera_origin
	lab.set_hud_visible(false)
	_expect(not lab._top.visible and not lab._side.visible and lab.compositor.position == Vector2.ZERO, "Clean view hides all guide controls")
	_expect(lab.compositor.camera_origin == before_view, "F8 preserves camera")
	lab.set_hud_visible(true)
	_expect(lab._side.visible and lab._top.visible, "Controls restore after clean view")
	lab.show_overview()
	_expect(lab.compositor.camera_origin == Vector2.ZERO and lab.compositor.view_size == Vector2(1024, 1024), "Overview restores complete view after detail zoom")
	lab.select_district(7)
	lab.step_once()
	_expect(lab.paused and lab.runtime.layer_tick("play") == 1 and lab.runtime.layer_tick("scripted") == 1, "Step pauses and advances both chemical planes once")
	var reset_view: Vector2 = lab.compositor.camera_origin
	_expect(lab.reset_exhibition(), "Fresh reset restores all layers and sources")
	_expect(lab.runtime.generation() == generation + 1, "Fresh reset installs exactly one new generation")
	_expect(lab.selected_district == 7 and lab.compositor.camera_origin == reset_view, "Reset keeps the selected viewpoint for replay")
	_expect(lab.runtime.event_stats()["applications"] == 0 and lab.paused, "Reset restarts paused source programme")
	lab.toggle_tour()
	_expect(lab.tour_enabled and not lab.paused, "Tour starts the exhibit clocks")
	var initial_tour_index: int = lab._tour_index
	lab._process(14.1)
	_expect(lab._tour_index == (initial_tour_index + 1) % 16, "Tour advances through the connected snake route")
	_expect(lab.runtime.generation() == generation + 1, "Tour changes camera without replacing evolving worlds")
	lab.toggle_pause()
	var stopped_tour_clock: float = lab._tour_clock
	var stopped_tick: int = lab.runtime.layer_tick("play")
	lab._process(20.0)
	_expect(lab._tour_clock == stopped_tour_clock and lab.runtime.layer_tick("play") == stopped_tick, "Pause stops tour and material/source clocks together")
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 1000)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await process_frame
		lab._layout()
		_expect(lab._side.get_rect().end.x <= lab.size.x and lab._side.get_rect().end.y <= lab.size.y, "Guide fits supported window size")
		_expect(lab._top.get_rect().end.x <= lab.size.x, "Header fits supported window width")
		_expect(lab._top.size.y <= 90, "Header cannot expand over the map through wrapped minimum sizes")
	await _check_ui_input(lab)
	lab.queue_free()
	await process_frame
	print("Deepworks controller: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)

func _check_ui_input(lab: Control) -> void:
	# Route real events through Input and the viewport's GUI focus owner. Calling
	# _pan or the control's callbacks directly would miss the shared-key defect.
	var sliders: Array[Node] = lab.find_children("*", "HSlider", true, false)
	_expect(sliders.size() == 1, "Exhibition provides one accessible brush slider")
	if sliders.size() != 1:
		return
	var brush: HSlider = sliders[0] as HSlider
	lab.select_district(5)
	lab._process(0.0)
	var initial_camera: Vector2 = lab.compositor.camera_origin
	await _key_event(KEY_D, true)
	lab._process(0.25)
	var panned_camera: Vector2 = lab.compositor.camera_origin
	_expect(panned_camera.x > initial_camera.x, "Fresh world key actually pans before the focus boundary")
	brush.grab_focus()
	_expect(root.gui_get_focus_owner() == brush, "Brush slider acquires real GUI keyboard focus")
	# Focus may enter and leave between two host frames. It must still cancel
	# the already-held world key, rather than reusing the old armed state.
	root.gui_release_focus()
	lab._process(0.25)
	_expect(lab.compositor.camera_origin == panned_camera,
		"A key held across UI focus cannot resume panning after focus leaves")
	brush.grab_focus()
	await _key_event(KEY_D, false)
	lab._process(0.0)
	var slider_camera: Vector2 = lab.compositor.camera_origin
	var brush_before: float = brush.value
	await _key_event(KEY_RIGHT, true)
	lab._process(0.25)
	_expect(brush.value > brush_before and lab._brush_radius == int(brush.value),
		"Focused slider retains real arrow-key brush adjustment")
	_expect(lab.compositor.camera_origin == slider_camera,
		"Slider arrow input does not also move the exhibition camera")
	# A map click explicitly returns keyboard ownership to the world, but an
	# arrow still held from the slider must be released before it may pan.
	var map_point: Vector2 = lab.compositor.global_position + lab.compositor.content_rect().get_center()
	var returning_camera: Vector2 = lab.compositor.camera_origin
	await _mouse_button(map_point, MOUSE_BUTTON_MIDDLE, true)
	await _mouse_button(map_point, MOUSE_BUTTON_MIDDLE, false)
	_expect(root.gui_get_focus_owner() == null, "Clicking the map relinquishes UI keyboard focus")
	lab._process(0.25)
	_expect(lab.compositor.camera_origin == returning_camera,
		"Returning to the map with the slider arrow held does not pan")
	await _key_event(KEY_RIGHT, false)
	lab._process(0.0)
	await _key_event(KEY_RIGHT, true)
	lab._process(0.25)
	_expect(lab.compositor.camera_origin.x > returning_camera.x,
		"Releasing and freshly pressing the world arrow restores panning")
	await _key_event(KEY_RIGHT, false)
	lab._process(0.0)
	# A closed picker is still a focused UI control; checking only its popup
	# visibility must not admit WASD into world movement.
	lab._material_picker.grab_focus()
	var picker_camera: Vector2 = lab.compositor.camera_origin
	await _key_event(KEY_D, true)
	lab._process(0.25)
	_expect(lab.compositor.camera_origin == picker_camera, "Focused closed picker blocks world WASD")
	await _key_event(KEY_D, false)
	root.gui_release_focus()
	lab._process(0.0)
	# The same focus boundary cancels an existing middle-drag, even before
	# another host frame could poll focus or the mouse's held-button state.
	var drag_camera: Vector2 = lab.compositor.camera_origin
	await _mouse_button(map_point, MOUSE_BUTTON_MIDDLE, true)
	await _mouse_motion(map_point + Vector2(20, 0), Vector2(20, 0))
	var dragged_camera: Vector2 = lab.compositor.camera_origin
	_expect(dragged_camera.x < drag_camera.x, "Fresh middle-drag actually pans before UI focus")
	brush.grab_focus()
	await _mouse_motion(map_point + Vector2(40, 0), Vector2(20, 0))
	_expect(lab.compositor.camera_origin == dragged_camera, "UI focus immediately releases a held middle-drag")
	await _mouse_button(map_point + Vector2(40, 0), MOUSE_BUTTON_MIDDLE, false)
	root.gui_release_focus()
	lab._process(0.0)

func _key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func _mouse_button(position: Vector2, button: MouseButton, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func _mouse_motion(position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)
