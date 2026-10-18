extends SceneTree

const Scene = preload("res://scripts/blacksite_nine.gd")
const Layout = preload("res://scripts/blacksite_nine_layout.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const SEAM_POINT := Vector2i(352, 444)
const EDIT_MATERIAL: int = 63
const INTEREST := {"policy":"fixed", "region":[32,32,960,960]}
const LOCAL_PROBES: Array[Vector2i] = [
	Vector2i(184,262), Vector2i(29,262), Vector2i(33,262),
	Vector2i(96,24), Vector2i(38,92), Vector2i(144,27),
	Vector2i(248,29), Vector2i(38,228), Vector2i(36,100)]

var assertions: int = 0
var failures: int = 0
var expected_hash: String = ""
var evidence: Array[Dictionary] = []


class DesktopSpy:
	extends "res://scripts/main.gd"
	var accepted_installs: int = 0
	var captured: Dictionary = {}
	func microscenario_apply_definition(definition: Dictionary, mode: String = "Inspect") -> bool:
		var accepted: bool = super.microscenario_apply_definition(definition, mode)
		if accepted: accepted_installs += 1
		return accepted
	func _write_microscenario_capture(report: Dictionary) -> void:
		captured = report.duplicate(true)


class WebSpy:
	extends "res://scripts/web_demo_controller.gd"
	var accepted_installs: int = 0
	var captured: Dictionary = {}
	func microscenario_apply_definition(definition: Dictionary, mode: String = "Inspect") -> bool:
		var accepted: bool = super.microscenario_apply_definition(definition, mode)
		if accepted: accepted_installs += 1
		return accepted
	func _write_microscenario_capture(report: Dictionary) -> void:
		captured = report.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)


func wait_for(predicate: Callable, timeout_ms: int = 20000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	root.size = Vector2i(1600, 900)
	if not CyberWebCapabilities.native_available():
		expect(false, "Blacksite controller integration requires native demo classes")
		_finish()
		return
	var checked: Dictionary = Contract.validate(Scene.definition())
	expect(checked.get("ok", false), "Blacksite integration requires a valid complete recipe")
	if checked.get("ok", false):
		expected_hash = str(checked.hash)
		await _desktop()
		await _web()
	_finish()


func _finish() -> void:
	print("BLACKSITE_NINE_INTEGRATION_IDENTITY: " + JSON.stringify(evidence))
	print("BLACKSITE_NINE_INTEGRATION: %d assertions; %d failures; desktop asynchronous and synchronous Web-controller camera/edit/interest/lifecycle coverage" % [assertions, failures])
	quit(1 if failures else 0)


func _key(code: Key, pressed: bool = true, echo: bool = false, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	event.shift_pressed = shift
	return event


func _desktop() -> void:
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopSpy)
	root.add_child(desktop)
	await process_frame
	var p = desktop.blacksite_nine_presentation
	var original_minimum: Vector2 = desktop.world_view.custom_minimum_size
	expect(await wait_for(func() -> bool: return desktop.latest_snapshot != null),
		"Desktop did not publish its initial owner snapshot")
	desktop.toggle_actor_prototypes()
	expect(desktop.actor_prototype_panel.visible and not p.launch()
		and desktop.accepted_installs == 0 and desktop.pending_microscenario_apply.is_empty(),
		"Blacksite launch replaced the actor selector's modal ownership")
	desktop.actor_prototype_panel.hide()
	var before: Dictionary = _frame_state(desktop, p)
	desktop._unhandled_key_input(_key(KEY_F11, true, false, true))
	expect(desktop.accepted_installs == 1
		and desktop.pending_microscenario_apply.get("hash", "") == expected_hash,
		"Desktop Shift+F11 did not queue exactly the Blacksite definition")
	expect(_frame_state(desktop, p) == before,
		"Desktop advertised Blacksite framing before owner acceptance")
	var pending: Dictionary = desktop.pending_microscenario_apply.duplicate(true)
	desktop._unhandled_key_input(_key(KEY_F11, true, true, true))
	desktop._unhandled_key_input(_key(KEY_F11, false, false, true))
	expect(not p.launch() and not p.frame_tile(4)
		and desktop.accepted_installs == 1 and desktop.pending_microscenario_apply == pending,
		"A pending install or key echo was replaced by another Blacksite request")
	var installed: bool = await _wait_installed(desktop, p, false)
	expect(installed, "Desktop did not accept Blacksite at tick zero")
	if installed:
		await _exercise(desktop, p, false, original_minimum)
		p.show_map()
		desktop.tower_reset()
		expect(not p.launch(), "Blacksite launch replaced the pending Tower exit")
		expect(await wait_for(func() -> bool:
			return desktop.pending_water_exit.is_empty() and not p.active()),
			"Desktop could not leave the shared complex for Experiment Tower")
		p.refresh()
		_check_left(desktop, p, "desktop", original_minimum)
	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	desktop.queue_free()
	await process_frame


func _web() -> void:
	var web: Control = load("res://web_main.tscn").instantiate()
	web.set_script(WebSpy)
	root.add_child(web)
	await process_frame
	# Only this synchronous owner is stepped explicitly. The desktop fixture
	# above always uses its worker queue and accepted immutable publications.
	web.set_physics_process(false)
	web.focused = true
	web.ui.close_menu()
	var p = web.blacksite_nine_presentation
	expect(web.ready_to_play and web.set_quality(2), "Web controller did not initialize high quality")
	var original_minimum: Vector2 = web.world_view.custom_minimum_size
	web.select_demo(Scene.ID)
	expect(p.active() and web.demo_id == Scene.ID and web.accepted_installs == 1
		and web.micro_host.summary().definition_hash == expected_hash,
		"Web menu did not synchronously install the single Blacksite complex")
	web._unhandled_key_input(_key(KEY_F11, true, true, true))
	web._unhandled_key_input(_key(KEY_F11, false, false, true))
	expect(web.accepted_installs == 1, "Web Shift+F11 echo/release reset the complex")
	if p.active():
		await _exercise(web, p, true, original_minimum)
		p.show_map()
		web.select_demo("neon_works")
		p.refresh()
		_check_left(web, p, "Web", original_minimum)
		expect(web.demo_id == "neon_works" and web.quality == 2
			and web.current_view_size == Vector2i(640,360)
			and web.simulation_margin == Vector2i(64,72) and web.render_snapshot_hz == 60
			and web.camera_origin == Vector2.ZERO and not web.paused,
			"Leaving Blacksite did not restore the ordinary Web quality/camera/run state")
	web.rapier_bridge.shutdown()
	web.queue_free()
	await process_frame


func _wait_installed(controller: Control, p, web: bool) -> bool:
	return await wait_for(func() -> bool:
		return (controller.pending_microscenario_apply.is_empty() and p.active()
			and _tick(controller, web) == 0 and controller.paused))


func _frame_state(controller: Control, p) -> Dictionary:
	return {"active":p.active(), "view":p.selected_view,
		"origin":controller.camera_origin, "size":controller.current_view_size,
		"follow":controller.camera_follow_enabled,
		"title":controller.get_node("Layout/Title").text}


func _cells(controller: Control, web: bool) -> PackedByteArray:
	if web: return controller.demo_bridge.export_level(controller.native_world)
	# CPU Image is assembled from accepted, owned render patches; never inspect
	# the desktop worker's mutable World or dummy ImageTexture readback.
	return controller.image.get_data()


func _material(controller: Control, web: bool, point: Vector2i) -> int:
	if web: return int(controller.native_world.material_at(point.x, point.y))
	return roundi(controller.image.get_pixel(point.x, point.y).r * 255.0)


func _tick(controller: Control, web: bool) -> int:
	return int(controller.native_world.get_tick_index()) if web else int(controller.latest_snapshot.tick_index)


func _probe_point(index: int) -> Vector2i:
	return Layout.tile_origin(index) + LOCAL_PROBES[index]


func _exercise(controller: Control, p, web: bool, original_minimum: Vector2) -> void:
	var owner: String = "Web" if web else "desktop"
	p.refresh()
	expect(p.launch_button.get_parent() == controller.showcase_presentation.launch_button.get_parent(),
		owner + " scene launchers did not share the existing launch row")
	expect(controller.world_view.custom_minimum_size == Vector2(original_minimum.x, 0),
		owner + " active complex did not release the world minimum height for its navigation")
	expect(controller.current_view_size == Vector2i(960,960)
		and controller.camera_origin == Vector2(32,32) and p.selected_view == 0
		and not controller.camera_follow_enabled
		and controller.get_node("Layout/Title").text == "CYBERSAND / BLACKSITE NINE",
		owner + " accepted scene title/overview/camera disagree")
	expect(controller.paused and _tick(controller, web) == 0 and controller.rigid_bodies.is_empty()
		and controller.character_position == Scene.spawn() and p.tile_buttons.size() == 9,
		owner + " did not start the single paused, sampled-player complex")
	expect(p.grade_overlay.visible and p.overlay.visible
		and p.grade_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and p.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and p.grade_overlay.position == p.overlay.position and p.grade_overlay.size == p.overlay.size,
		owner + " grading and empty-space layers do not share the passive scene frame")
	var baseline: PackedByteArray = _cells(controller, web)
	var original_position: Vector2 = controller.character_position
	var installs: int = int(controller.accepted_installs)
	expect(not p.move_tile(Vector2i.RIGHT), owner + " allowed a relative tile move from the overview")

	controller.microscenario_panel._open_definition()
	expect(controller.microscenario_panel.modal_open() and not p.launch() and not p.frame_tile(4)
		and controller.accepted_installs == installs and _cells(controller, web) == baseline,
		owner + " Blacksite controls bypassed the definition modal")
	controller.microscenario_panel.definition_dialog.hide()

	# One real brush disc crosses a shared edge; it is not two independent tile
	# edits. Additional falling probes cover all nine regions, outside later views.
	expect(_material(controller, web, SEAM_POINT) == 0
		and controller.queue_brush_mutation(SEAM_POINT.x, SEAM_POINT.y, 4, EDIT_MATERIAL),
		owner + " refused the seam-straddling paint control")
	var probes_admitted: bool = true
	for index: int in range(9):
		var point: Vector2i = _probe_point(index)
		probes_admitted = (_material(controller, web, point) == 0
			and controller.queue_brush_mutation(point.x, point.y, 0, 2)) and probes_admitted
	expect(probes_admitted, owner + " did not admit one ordinary Sand probe in each room")
	expect(await wait_for(func() -> bool:
		return (_material(controller, web, SEAM_POINT + Vector2i(-3,0)) == EDIT_MATERIAL
			and _material(controller, web, SEAM_POINT + Vector2i(3,0)) == EDIT_MATERIAL
			and _all_probes(controller, web, 2))),
		owner + " did not publish the shared-edge paint and all nine probes")
	var edited: PackedByteArray = _cells(controller, web)
	expect(edited != baseline and _tick(controller, web) == 0,
		owner + " paused editing did not change cells independently of native ticks")

	for index: int in range(9):
		p.show_map()
		expect(p.map_popup.visible and p.input_blocked(), owner + " tile map did not own pointer input")
		p.tile_buttons[index].pressed.emit()
		await process_frame
		expect(p.selected_view == index + 1 and not p.map_popup.visible
			and controller.current_view_size == Vector2i(320,320)
			and controller.camera_origin == Vector2(Layout.tile_origin(index))
			and not controller.camera_follow_enabled,
			owner + " map button selected the wrong room: " + Layout.CODES[index])
		expect(_cells(controller, web) == edited and _tick(controller, web) == 0
			and controller.character_position == original_position
			and controller.accepted_installs == installs and controller.pending_microscenario_apply.is_empty(),
			owner + " tile camera move reset, repainted, moved the player or advanced the world")

	var retained: Dictionary = _frame_state(controller, p)
	expect(not p.frame_tile(-1) and not p.frame_tile(9) and not p.frame_view(-1)
		and not p.frame_view(10) and not p.move_tile(Vector2i.ZERO)
		and not p.move_tile(Vector2i(1,1)) and not p.move_tile(Vector2i.RIGHT)
		and not p.move_tile(Vector2i.DOWN) and _frame_state(controller, p) == retained,
		owner + " invalid room/view/direction changed accepted framing")
	expect(p.frame_tile(0) and not p.move_tile(Vector2i.LEFT) and not p.move_tile(Vector2i.UP),
		owner + " top-left room navigation wrapped across the outer boundary")
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		p.frame_tile(4)
		var destination: int = 4 + direction.x + direction.y * 3
		expect(p.move_tile(direction) and p.selected_view == destination + 1,
			owner + " cardinal room navigation selected the wrong neighbor")
	expect(p.follow_player() and controller.camera_follow_enabled
		and controller.current_view_size == Vector2i(480,270),
		owner + " follow did not use the traversal camera")
	expect(p.frame_view(0) and not controller.camera_follow_enabled
		and controller.current_view_size == Vector2i(960,960),
		owner + " whole-complex view did not release camera follow")
	p.atmosphere_button.button_pressed = false
	p.refresh()
	expect(not p.overlay.visible and not p.grade_overlay.visible,
		owner + " depth toggle did not hide both backdrop and grading")
	p.atmosphere_button.button_pressed = true
	p.refresh()
	expect(p.overlay.visible and p.grade_overlay.visible,
		owner + " depth toggle did not restore both backdrop and grading")
	p.show_map()
	controller._unhandled_key_input(_key(KEY_F8))
	p.refresh()
	expect(not p.controls.visible and not p.map_popup.visible and p.grade_overlay.visible,
		owner + " clean view left the Blacksite controls/map visible")
	controller._unhandled_key_input(_key(KEY_F8))
	p.refresh()
	expect(p.controls.visible, owner + " F8 did not restore the Blacksite controls")
	expect(_cells(controller, web) == edited and controller.accepted_installs == installs
		and _tick(controller, web) == 0,
		owner + " camera/atmosphere/HUD controls changed the world")

	await _pointer_guard(controller, p, web)
	# Frame only A1. Actual Sand motion in every other tile demonstrates that
	# camera forwarding did not replace the full fixed interest rectangle.
	p.frame_tile(0)
	# Execution remains owner-controlled. A normal window preference must not
	# override this scenario's independently fixed native interest rectangle.
	expect(controller.set_simulation_window(false),
		owner + " incorrectly rejected an owner-controlled window preference")
	if web:
		var before_quality: PackedByteArray = _cells(controller, web)
		expect(controller.set_quality(0) and controller.current_view_size == Vector2i(320,180)
			and controller.accepted_installs == installs and _cells(controller, web) == before_quality,
			"Web quality preference reset or changed the shared complex")
		expect(controller.set_quality(2) and p.frame_tile(0),
			"Web did not restore its quality preference and the A1 inspection frame")
	for step: int in range(4):
		expect(controller.tower_command({"step":true}), owner + " refused a bounded native step")
		if web: controller._physics_process(1.0 / 60.0)
		expect(await wait_for(func() -> bool: return _tick(controller, web) == step + 1),
			owner + " did not acknowledge exactly one native step")
	expect(await wait_for(func() -> bool: return _all_probes(controller, web, 0)),
		owner + " kept an off-camera room's Sand probe frozen despite full fixed interest")
	controller.captured.clear()
	controller.microscenario_capture()
	expect(await wait_for(func() -> bool: return not controller.captured.is_empty()),
		owner + " capture did not cross the simulation ownership boundary")
	var capture: Dictionary = controller.captured
	expect(capture.get("definition_hash", "") == expected_hash
		and capture.get("completed_tick", -1) == 4
		and capture.get("execution_settings", {}).get("interest", {}) == INTEREST
		and capture.get("execution_settings", {}).get("simulation_window_enabled", false)
		and capture.get("worker_count", 0) == 1 and not capture.get("failed", true),
		owner + " capture lost full-complex interest, identity or native completion")
	evidence.append({"owner":owner, "definition_sha256":expected_hash,
		"camera_tiles":9, "paint_crosses_seam":[SEAM_POINT.x,SEAM_POINT.y],
		"regions_advanced":9, "off_camera_regions_advanced":8, "completed_tick":4,
		"worker_count":capture.get("worker_count",0),
		"backend":capture.get("backend","unavailable"),
		"platform":capture.get("platform","unavailable"),
		"godot":capture.get("godot","unavailable")})
	await _keyboard_guard(controller, p, web)

	controller._unhandled_key_input(_key(KEY_R))
	expect(await wait_for(func() -> bool:
		return (controller.pending_microscenario_apply.is_empty() and p.active()
			and _tick(controller, web) == 0 and _cells(controller, web) == baseline)),
		owner + " R did not restore exact cells across all nine rooms and the shared seam")
	expect(controller.accepted_installs == installs + 1 and controller.character_position == Scene.spawn()
		and controller.paused and p.selected_view == 0
		and controller.camera_origin == Vector2(32,32) and controller.current_view_size == Vector2i(960,960),
		owner + " whole-complex reset changed the camera/player contract or installed more than once")


func _all_probes(controller: Control, web: bool, material: int) -> bool:
	for index: int in range(9):
		if _material(controller, web, _probe_point(index)) != material: return false
	return true


func _movement_keys(pressed: bool) -> void:
	for code: Key in [KEY_D, KEY_SPACE, KEY_RIGHT]:
		Input.parse_input_event(_key(code, pressed))
	Input.flush_buffered_events()


func _owner_steps(controller: Control, web: bool, count: int) -> bool:
	var start: int = _tick(controller, web)
	for index: int in range(count):
		var admitted: bool = controller.tower_command({"step":true})
		expect(admitted, "Keyboard fixture owner step was refused")
		if not admitted: return false
		if web:
			# The Linux headless PopupPanel emits application focus-out. Pin a
			# focused, previously armed host so the map's own keyboard guard is
			# tested independently of that inherited focus/rearm protection.
			controller.focused = true
			controller.input_armed = true
			controller._physics_process(1.0 / 60.0)
		var completed: bool = await wait_for(func() -> bool:
			return _tick(controller, web) == start + index + 1, 5000)
		expect(completed,
			"Keyboard fixture owner step was not acknowledged exactly once")
		if not completed: return false
	return true


func _keyboard_guard(controller: Control, p, web: bool) -> void:
	var owner: String = "Web" if web else "desktop"
	p.frame_tile(4)
	p.show_map()
	var camera: Vector2 = controller.camera_origin
	var player: Vector2 = controller.character_position
	_movement_keys(true)
	expect(p.map_popup.visible and p.keyboard_blocked()
		and Input.is_physical_key_pressed(KEY_D) and Input.is_physical_key_pressed(KEY_SPACE)
		and Input.is_physical_key_pressed(KEY_RIGHT) and controller.get_horizontal_input() == 0.0,
		owner + " map did not suppress actual held movement/jetpack/pan keys")
	controller.update_camera(0.1)
	if not web: controller.update_worker_frame_state()
	if not await _owner_steps(controller, web, 6):
		_movement_keys(false)
		p.map_popup.hide()
		return
	expect(controller.camera_origin == camera and is_equal_approx(controller.character_position.x, player.x)
		and controller.character_position.y >= player.y,
		owner + " player or camera followed held keys through the open map")
	p.map_popup.hide()
	player = controller.character_position
	expect(p.keyboard_blocked() and controller.get_horizontal_input() == 0.0,
		owner + " closing the map rearmed keys which were still held")
	controller.update_camera(0.1)
	if not web: controller.update_worker_frame_state()
	if not await _owner_steps(controller, web, 3):
		_movement_keys(false)
		return
	expect(controller.camera_origin == camera and is_equal_approx(controller.character_position.x, player.x)
		and controller.character_position.y >= player.y,
		owner + " map close admitted held movement, jetpack or pan before release")
	_movement_keys(false)
	await process_frame
	expect(not p.keyboard_blocked(), owner + " map keyboard latch did not rearm after release")
	player = controller.character_position
	_movement_keys(true)
	expect(not p.keyboard_blocked() and controller.get_horizontal_input() == 1.0,
		owner + " keyboard latch rejected a fresh movement gesture")
	controller.update_camera(0.1)
	if not web: controller.update_worker_frame_state()
	if not await _owner_steps(controller, web, 8):
		_movement_keys(false)
		return
	_movement_keys(false)
	await process_frame
	expect(controller.camera_origin.x > camera.x and controller.character_position.x > player.x
		and controller.character_position.y < player.y,
		owner + " fresh movement/jetpack/pan positive control did not move the actual player and camera")
	evidence.append({"owner":owner, "map_keyboard_guard":"open + closed-held + fresh gesture",
		"native_steps":17, "physical_keys":["D","Space","Right"],
		"completed_tick":_tick(controller, web)})


func _mouse_at(controller: Control, point: Vector2i, pressed: bool) -> void:
	var content: Rect2 = controller.view_content_rect()
	var local: Vector2 = content.position + (Vector2(point) + Vector2(0.5,0.5)
		- controller.camera_origin) / Vector2(controller.current_view_size) * content.size
	var position: Vector2 = controller.get_viewport().get_screen_transform() \
		* controller.world_view.get_global_transform_with_canvas() * local
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_RIGHT
	button.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	button.position = position
	button.global_position = position
	button.pressed = pressed
	Input.parse_input_event(button)
	Input.flush_buffered_events()


func _paint(controller: Control, web: bool) -> void:
	if web: controller._paint_pointer()
	else: controller.handle_painting()


func _pointer_guard(controller: Control, p, web: bool) -> void:
	var owner: String = "Web" if web else "desktop"
	p.frame_view(0)
	controller.set_brush_size(1)
	await process_frame
	var edited: PackedByteArray = _cells(controller, web)
	p.show_map()
	expect(p.map_popup.visible and p.input_blocked(), owner + " map popup did not block painting")
	_mouse_at(controller, SEAM_POINT, true)
	expect(Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and p.input_blocked(),
		owner + " map admitted a held erase gesture")
	_paint(controller, web)
	await create_timer(0.05).timeout
	expect(_cells(controller, web) == edited, owner + " open map changed native cells through the pointer")
	p.map_popup.hide()
	expect(p.input_blocked(), owner + " closing the map rearmed a still-held erase gesture")
	_paint(controller, web)
	await create_timer(0.05).timeout
	expect(_cells(controller, web) == edited, owner + " map close painted before release")
	_mouse_at(controller, SEAM_POINT, false)
	expect(not p.input_blocked(), owner + " map did not rearm after pointer release")
	# Positive control uses the same world point and the real pointer mapping.
	_mouse_at(controller, SEAM_POINT, true)
	_paint(controller, web)
	_mouse_at(controller, SEAM_POINT, false)
	expect(await wait_for(func() -> bool: return _material(controller, web, SEAM_POINT) == 0),
		owner + " released map did not admit a fresh erase at the painted seam")
	expect(_material(controller, web, SEAM_POINT + Vector2i(-3,0)) == EDIT_MATERIAL
		and _material(controller, web, SEAM_POINT + Vector2i(3,0)) == EDIT_MATERIAL
		and controller.paused and _tick(controller, web) == 0,
		owner + " positive erase changed neighboring seam marks or simulation time")


func _check_left(controller: Control, p, owner: String, original_minimum: Vector2) -> void:
	expect(controller.world_view.custom_minimum_size == original_minimum,
		owner + " leaving the complex did not restore the exact prior world minimum")
	expect(not p.active() and not p.map_popup.visible and not p.overlay.visible and not p.grade_overlay.visible
		and not p.map_button.visible and not p.overview_button.visible
		and not p.follow_button.visible and not p.atmosphere_button.visible
		and not p.current_label.visible,
		owner + " Blacksite navigation or atmosphere leaked into the next scene")
	var state: Dictionary = _frame_state(controller, p)
	expect(not p.frame_tile(0) and not p.follow_player() and _frame_state(controller, p) == state,
		owner + " inactive complex controls moved the next scene's camera")
