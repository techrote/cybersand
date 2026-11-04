extends SceneTree

# Actual scene/input/layout controls. No material or contact law acceptance.
var checks: int = 0
var failures: Array[String] = []
var layouts: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)
		push_error(why)

func body(scene) -> RigidBody2D:
	return scene.runtime._arena.session.bodies()[0]

func position(scene) -> Vector2:
	return PhysicsServer2D.body_get_state(body(scene).get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM).origin

func key_event(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse_event(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	# get_global_rect() is in viewport coordinates. Input.parse_input_event()
	# accepts window pixels and applies content scaling again at resized hosts.
	root.push_input(event, true)

func mouse_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func _spawn_checks(scene) -> void:
	var initial: Vector2 = position(scene)
	var saved := Vector2(640.5, 120.25)
	check(scene.set_spawn_position(saved), "accept an explicit repeatable world spawn")
	check(scene.spawn_position == saved and position(scene) == initial, "saving spawn cannot teleport the live flyer")
	check(scene.spawn_fields.x.value == saved.x and scene.spawn_fields.y.value == saved.y, "saved position is visible in coordinate fields")
	for invalid: Vector2 in [Vector2.INF, Vector2(NAN, 120), Vector2(-20, 120), Vector2(2000, 2000)]:
		check(not scene.set_spawn_position(invalid) and scene.spawn_position == saved, "invalid spawn refuses without losing saved point")
	for index: int in range(7):
		check(scene.select_preset(index), "every flyer admits the same saved spawn")
		check(position(scene).is_equal_approx(saved) and scene.spawn_position == saved, "craft change retains exact saved centre")
		check(PhysicsServer2D.body_get_state(body(scene).get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY) == Vector2.ZERO, "fresh spawn resets velocity normally")
	key_event(KEY_R, true)
	key_event(KEY_R, false)
	check(position(scene).is_equal_approx(saved) and scene.spawn_position == saved, "R resets map and flyer at saved point")
	var before_edit: Vector2 = position(scene)
	scene.spawn_fields.x.value = 620.25
	scene.spawn_fields.y.value = 100.5
	check(position(scene) == before_edit, "editing spawn coordinate fields cannot teleport live craft")
	key_event(KEY_R, true)
	key_event(KEY_R, false)
	check(scene.spawn_position == Vector2(620.25, 100.5) and position(scene).is_equal_approx(scene.spawn_position), "R admits the explicitly edited X/Y fields as saved next spawn")
	check(scene.set_spawn_position(saved) and scene.select_preset(0), "restore cross-response spawn after direct field witness")
	var typed_x: LineEdit = scene.spawn_fields.x.get_line_edit()
	typed_x.grab_focus()
	typed_x.text = "610.75"
	check(position(scene).is_equal_approx(saved), "typing pending X text cannot teleport live craft")
	scene._restart()
	check(scene.spawn_position == Vector2(610.75, saved.y) and position(scene).is_equal_approx(scene.spawn_position), "Reset commits focused pending X text before reading spawn fields")
	var typed_y: LineEdit = scene.spawn_fields.y.get_line_edit()
	typed_y.grab_focus()
	typed_y.text = "110.5"
	check(scene.select_preset(1), "craft selection admits pending typed Y spawn")
	check(scene.spawn_position == Vector2(610.75, 110.5) and position(scene).is_equal_approx(scene.spawn_position), "craft selection commits focused Y text before reading spawn fields")
	check(scene.set_spawn_position(saved) and scene.select_preset(0), "restore shared comparison spawn after focused text witnesses")
	var old_owner: int = scene.runtime._arena.get_instance_id()
	check(not scene.set_spawn_position(Vector2(300, 256)), "hard-platform overlap refuses saved spawn")
	check(scene.runtime._arena.get_instance_id() == old_owner and scene.spawn_position == saved, "hard-overlap refusal preserves owner and saved point")
	check(scene.set_spawn_position(Vector2(25, 120)) and scene.select_preset(0), "small flyer can use a near-wall spawn with full hull clearance")
	old_owner = scene.runtime._arena.get_instance_id()
	check(not scene.select_preset(6), "wide Observatory refuses spawn where its hull intersects wall")
	check(scene.runtime._arena.get_instance_id() == old_owner and scene.selected == 0 and scene.spawn_position == Vector2(25, 120), "craft-specific spawn refusal retains prior owner, flyer and saved point")
	check(scene.set_spawn_position(saved) and scene.select_preset(0), "safe spawn recovers cleanly after wide-hull refusal")
	for selector: int in [0, 2, 3]:
		scene.response_select.select(selector)
		for budget: float in [20.0, 40.0, 80.0]:
			scene.control_fields.budget.value = budget
			check(scene.apply_controls(), "response and budget apply through ordinary reset")
			check(position(scene).is_equal_approx(saved) and scene.spawn_position == saved, "LA, events off and selective comparisons share spawn")
	var captured := Vector2(660.25, 140.5)
	PhysicsServer2D.body_set_state(body(scene).get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.35, captured))
	check(scene.capture_spawn_position() and scene.spawn_position.is_equal_approx(captured), "capture reads authoritative Rapier centre")
	check(position(scene).is_equal_approx(captured), "capture does not change live body")
	var fine_pose := Vector2(660.123, 140.456)
	PhysicsServer2D.body_set_state(body(scene).get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.35, fine_pose))
	captured = Vector2(660.12, 140.46)
	check(scene.capture_spawn_position() and scene.spawn_position.is_equal_approx(captured), "non-quarter capture canonicalizes saved centre to displayed hundredth-cell precision")
	check(position(scene).is_equal_approx(fine_pose), "canonicalizing saved coordinates cannot teleport the live body")
	scene._restart()
	check(scene.spawn_position.is_equal_approx(captured) and position(scene).is_equal_approx(captured), "reset uses exactly the canonical captured centre")
	scene._restart()
	check(scene.spawn_position.is_equal_approx(captured) and position(scene).is_equal_approx(captured), "subsequent reset cannot shift canonical captured centre")
	check(scene.start_powder_test("stream"), "canonical powder comparison remains admitted")
	check(position(scene) == Vector2(512, 256) and scene.spawn_position.is_equal_approx(captured), "isolated powder test uses canonical spawn without replacing saved point")
	scene._restart()
	check(position(scene) == Vector2(512, 256) and scene.spawn_position.is_equal_approx(captured), "powder fixture restart preserves both canonical and saved positions")
	check(scene.return_to_painting() and position(scene).is_equal_approx(captured), "return to normal painting restores saved spawn")
	check(is_equal_approx(scene.spawn_fields.x.value, captured.x) and is_equal_approx(scene.spawn_fields.y.value, captured.y), "capture fields survive fixture transition")
	var live_position: Vector2 = position(scene)
	scene.reset_spawn_position()
	check(scene.spawn_position == Vector2(178, 304) and position(scene) == live_position, "spawn default reset changes next spawn only")
	check(scene.select_preset(0) and position(scene) == Vector2(178, 304), "default spawn remains available")
	check(scene.set_spawn_position(saved) and scene.select_preset(0), "restore safe test spawn")
	scene.restore_controls()
	check(scene.spawn_position == saved and position(scene).is_equal_approx(saved), "restoring response defaults retains saved spawn")

func _input_checks(scene) -> void:
	scene.runtime.set_paused(false)
	scene._focused = true
	scene._release_edit_focus()
	scene.advance_frame(scene._sample_action(), scene._can_control())
	check(not scene._rearm, "neutral input rearms after ordinary reset")
	key_event(KEY_W, true)
	check(not scene._rearm and scene._can_control(), "held thrust is admitted before burst")
	key_event(KEY_B, true)
	check(scene.room_source.burst_queued and not scene._rearm and scene._can_control(), "B queues burst without cancelling held flight control")
	key_event(KEY_B, false)
	scene.advance_frame(scene._sample_action(), scene._can_control())
	check(scene.room_source.attempted == 96 and not scene.room_source.burst_queued, "one B press authors exactly one bounded burst on owner step")
	key_event(KEY_B, true, true)
	check(not scene.room_source.burst_queued, "keyboard repeat cannot create additional bursts")
	key_event(KEY_B, false)
	await process_frame
	var click: Vector2 = scene.room_source_buttons[1].get_global_rect().get_center()
	check(scene.room_source_buttons[1].is_visible_in_tree() and not scene.room_source_buttons[1].disabled, "Burst click targets an enabled visible control")
	mouse_motion(click)
	await process_frame
	mouse_event(click, true)
	await process_frame
	mouse_event(click, false)
	await process_frame
	check(scene.room_source.burst_queued, "actual Burst button click still queues a burst")
	check(not scene._rearm and scene._can_control(), "non-text Burst click preserves control while W remains held")
	scene.advance_frame(scene._sample_action(), scene._can_control())
	var editor: LineEdit = scene.control_fields.budget.get_line_edit()
	editor.grab_focus()
	check(not scene._can_control(), "numeric editor focus suppresses pilot input")
	scene.advance_frame(scene._sample_action(), scene._can_control())
	check(scene._rearm, "editing cancels and requires neutral rearm")
	key_event(KEY_B, true)
	key_event(KEY_B, false)
	check(not scene.room_source.burst_queued, "B typed while editing cannot author a burst")
	scene._release_edit_focus()
	scene.advance_frame(scene._sample_action(), scene._can_control())
	check(scene._rearm, "held thrust cannot rearm immediately after numeric editing")
	key_event(KEY_W, false)
	scene.advance_frame(scene._sample_action(), scene._can_control())
	check(not scene._rearm, "releasing thrust rearms after editing")
	scene.runtime.set_paused(true)
	var before_tick: int = scene.runtime.tick
	var before_attempted: int = scene.room_source.attempted
	key_event(KEY_B, true)
	key_event(KEY_B, false)
	check(scene.room_source.burst_queued, "explicit B can queue a burst while paused")
	scene.advance_frame(scene._sample_action(), false)
	check(scene.runtime.tick == before_tick and scene.room_source.attempted == before_attempted, "paused B cannot author material or advance clocks")
	scene.runtime.set_paused(false)
	scene.advance_frame(scene._sample_action(), scene._can_control())
	check(scene.room_source.attempted == before_attempted + 96, "queued paused burst emits once on resumed owner step")
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	key_event(KEY_B, true)
	key_event(KEY_B, false)
	check(not scene.room_source.armed and scene._rearm, "OS focus loss still cancels flight and refuses B")
	key_event(KEY_W, true)
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	scene.advance_frame(scene._sample_action(), scene._can_control())
	check(scene._rearm, "held W after OS focus gain cannot bypass rearm")
	key_event(KEY_W, false)
	scene.advance_frame(scene._sample_action(), scene._can_control())
	check(not scene._rearm, "normal neutral release rearms after OS focus change")
	check(scene.start_powder_test("stream"), "isolated source keyboard refusal witness")
	key_event(KEY_B, true)
	key_event(KEY_B, false)
	check(not scene.room_source.armed and scene.powder_test.attempted == 0, "B cannot modify the canonical loading fixture")
	check(scene.return_to_painting(), "normal painting remains reachable")

func _layout_checks(scene) -> void:
	for dimensions: Vector2i in [Vector2i(2560, 1440), Vector2i(1280, 720)]:
		root.size = dimensions
		scene.size = Vector2(dimensions)
		await process_frame
		await process_frame
		var canvas: Rect2 = scene._canvas.get_global_rect()
		var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
		check(canvas.position.x >= -0.5 and canvas.end.x <= viewport.end.x + 0.5, "render canvas fits viewport width")
		check(canvas.position.y >= -0.5 and canvas.end.y <= viewport.end.y + 0.5, "render canvas fits viewport height")
		check(canvas.size.x >= dimensions.x - 32, "compact layout preserves full-width rendered game")
		check(canvas.size.y >= dimensions.y * 0.65, "default controls leave at least 65 percent viewport height to game")
		for control: Control in [scene.response_select, scene.control_fields.budget, scene.control_fields.mass_multiplier,
				scene.control_fields.inertia_multiplier, scene.room_source_buttons[0], scene.room_source_buttons[1],
				scene.room_stream, scene.spawn_fields.x, scene.spawn_fields.y]:
			check(control.is_visible_in_tree() and viewport.encloses(control.get_global_rect()), "primary comparison controls stay visible and inside viewport")
			check(not canvas.intersects(control.get_global_rect()), "primary comparison controls do not cover the rendered game")
		layouts.append({"viewport":dimensions,"canvas":canvas})

func _run() -> void:
	root.size = Vector2i(2560, 1440)
	var scene = load("res://gcr_fleet_playground.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	await process_frame
	_spawn_checks(scene)
	await _input_checks(scene)
	await _layout_checks(scene)
	scene.queue_free()
	await process_frame
	print("GCR_FLEET_REPEATABLE_UI ", JSON.stringify({"checks":checks,"failures":failures,"layouts":layouts}))
	quit(0 if failures.is_empty() else 1)
