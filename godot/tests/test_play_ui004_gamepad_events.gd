extends SceneTree

# Focused event-bridge contract, NOT hardware-gamepad or full-desktop acceptance.
# Only the connected-device selection and host sampling boundary are test seams.
# InputEvent dispatch, global button state, production bridge, bounded physical
# session FIFO and Rapier complete_step are real. No native World is required.
const Session = preload("res://scripts/physical_actor_session.gd")
const Bridge = preload("res://scripts/playable_course_gamepad_events.gd")
const TEST_DEVICE: int = 31
const OTHER_DEVICE: int = 30
const DT: float = 1.0 / 60.0
var assertions: int = 0
var failures: int = 0
var host: InputHost
var adapter: Node


class SelectedPadBridge:
	extends "res://scripts/playable_course_gamepad_events.gd"

	func _selected_joypad() -> int:
		return 31


class PollOnlyBridge:
	extends "res://scripts/playable_course_gamepad_events.gd"

	func _selected_joypad() -> int:
		return 31

	# Matched negative: retain the same event routing and physical session, but
	# omit forwarding both transient events. Subsequent polling sees neutral.
	func _unhandled_input(_event: InputEvent) -> void:
		pass


class InputHost:
	extends Node2D
	const Sampler = preload("res://scripts/player_playground_input.gd")
	var session: CyberPhysicalActorSession
	var course_active: bool = true
	var input_allowed: bool = true
	var paused: bool = false
	var rearm: bool = false
	var publications: int = 0

	func _playable_course_controls_active() -> bool:
		return course_active and session != null and session.active()

	func publish_actor_keyboard_input() -> void:
		publications += 1
		if paused or not input_allowed:
			rearm = true
			session.cancel_input(0, session.epoch, &"human")
			return
		# Deliberately substitute only hardware enumeration for this fixture.
		# This reads REAL Input state set by parse_input_event and uses the
		# production mapper and actual physical-session command admission.
		var buttons := Vector3i(int(Input.is_joy_button_pressed(31, JOY_BUTTON_A)),
			int(Input.is_joy_button_pressed(31, JOY_BUTTON_B)),
			int(Input.is_joy_button_pressed(31, JOY_BUTTON_X)))
		var action: Dictionary = Sampler.from_state({}, Vector2.ZERO, buttons)
		if rearm:
			if Sampler.active(action):
				return
			rearm = false
		session.submit_local(0, action, &"human", 6)


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_UI004: " + message)


func button(device: int, index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func release_buttons() -> void:
	for device: int in [TEST_DEVICE, OTHER_DEVICE]:
		for index: int in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
			button(device, index, false)


func queued() -> Array:
	return host.session._button_edges[0].duplicate(true)


func step() -> void:
	host.session.advance(DT)
	host.session.bridge.step()
	host.session.complete_step()


func scene_wiring() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var state: SceneState = scene.get_state()
	var count: int = 0
	for index: int in range(state.get_node_count()):
		if state.get_node_name(index) != &"CourseGamepadEvents":
			continue
		for property: int in range(state.get_node_property_count(index)):
			if state.get_node_property_name(index, property) == &"script" \
				and state.get_node_property_value(index, property) == Bridge:
				count += 1
	expect(count == 1, "normal desktop scene installs exactly one production event bridge")


func run() -> void:
	expect(ClassDB.class_exists(&"RapierPhysicsServer2D"), "actual Rapier backend is required")
	expect(not Input.get_connected_joypads().has(TEST_DEVICE)
		and not Input.get_connected_joypads().has(OTHER_DEVICE),
		"synthetic device indices must not collide with attached physical hardware")
	if failures != 0:
		quit(1)
		return
	scene_wiring()
	host = InputHost.new()
	root.add_child(host)
	host.session = Session.new()
	host.add_child(host.session)
	var configured: bool = host.session.configure([
		{"model":&"acrobat", "producer":&"human", "position":Vector2(178,200)}
	], host.get_world_2d().space, 1)
	expect(configured and host.session.active(), "real human mechanical session constructed")
	if not configured:
		host.free()
		quit(1)
		return
	adapter = SelectedPadBridge.new()
	host.add_child(adapter)
	release_buttons()
	host.session.cancel_input(0, host.session.epoch, &"human")
	expect(queued().is_empty(), "initial neutral session has no fabricated edge")

	# All three mapped buttons traverse the Viewport and preserve two ordered
	# transitions before a single physics callback. No direct publisher call.
	var action_names: Array[String] = ["primary", "secondary", "auxiliary"]
	var indices: Array[int] = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X]
	for index: int in range(indices.size()):
		var tick_before: int = host.session.tick
		button(TEST_DEVICE, indices[index], true)
		expect(Input.is_joy_button_pressed(TEST_DEVICE, indices[index]),
			"parsed press is present in actual Input state")
		button(TEST_DEVICE, indices[index], false)
		expect(not Input.is_joy_button_pressed(TEST_DEVICE, indices[index]),
			"parsed release is present in actual Input state")
		var expected: Array = [{"button":action_names[index],"pressed":true},
			{"button":action_names[index],"pressed":false}]
		expect(queued() == expected and host.session.tick == tick_before,
			"same-physics-tick event pair is queued in order: " + action_names[index])
		step()
		expect(bool(host.session._applied_buttons[0].get(action_names[index], false))
			and queued() == [expected[1]], "first real physical step consumes the press only")
		step()
		expect(not bool(host.session._applied_buttons[0].get(action_names[index], true))
			and queued().is_empty(), "second real physical step consumes the release")

	var before: int = host.publications
	button(OTHER_DEVICE, JOY_BUTTON_A, true)
	button(OTHER_DEVICE, JOY_BUTTON_A, false)
	button(TEST_DEVICE, JOY_BUTTON_Y, true)
	button(TEST_DEVICE, JOY_BUTTON_Y, false)
	expect(host.publications == before and queued().is_empty(),
		"another pad and unmapped button cannot publish commands")
	host.course_active = false
	button(TEST_DEVICE, JOY_BUTTON_A, true)
	button(TEST_DEVICE, JOY_BUTTON_A, false)
	expect(host.publications == before and queued().is_empty(),
		"non-course and specialist host selection stays untouched")
	host.course_active = true

	button(TEST_DEVICE, JOY_BUTTON_A, true)
	button(TEST_DEVICE, JOY_BUTTON_A, false)
	expect(queued().size() == 2, "focus test begins with genuinely unconsumed edges")
	var generation: int = int(host.session.observation(0).control_generation)
	host.input_allowed = false
	button(TEST_DEVICE, JOY_BUTTON_B, true)
	button(TEST_DEVICE, JOY_BUTTON_B, false)
	expect(queued().is_empty() and host.rearm
		and int(host.session.observation(0).control_generation) > generation,
		"host refusal cancels the real pending edges and generation")
	host.input_allowed = true
	button(TEST_DEVICE, JOY_BUTTON_A, true)
	expect(queued().is_empty() and host.rearm, "held button cannot bypass neutral rearm")
	button(TEST_DEVICE, JOY_BUTTON_A, false)
	expect(not host.rearm and queued().is_empty(), "neutral release rearms without replaying held press")
	button(TEST_DEVICE, JOY_BUTTON_A, true)
	button(TEST_DEVICE, JOY_BUTTON_A, false)
	expect(queued().size() == 2, "fresh post-rearm press and release are admitted")
	host.paused = true
	button(TEST_DEVICE, JOY_BUTTON_X, true)
	button(TEST_DEVICE, JOY_BUTTON_X, false)
	expect(queued().is_empty() and host.rearm, "pause refusal clears still-unconsumed input")
	host.paused = false
	button(TEST_DEVICE, JOY_BUTTON_X, false)
	expect(not host.rearm, "neutral state can rearm after pause")

	# Remove only the event bridge's forwarding. Poll the SAME mapper/session
	# after the transient pair: latest button state is neutral, so no edge.
	adapter.free()
	adapter = PollOnlyBridge.new()
	host.add_child(adapter)
	before = host.publications
	button(TEST_DEVICE, JOY_BUTTON_A, true)
	button(TEST_DEVICE, JOY_BUTTON_A, false)
	expect(host.publications == before, "negative control removes event forwarding only")
	host.publish_actor_keyboard_input()
	expect(queued().is_empty(), "poll-only negative control loses the transient button pair")

	release_buttons()
	host.session.close()
	expect(not host.session.active() and host.session.bodies().is_empty(),
		"fixture closes every real physical body")
	host.free()
	await process_frame
	print("PLAY_UI004_RESULT ", JSON.stringify({
		"assertions":assertions,"failures":failures,
		"real_input_event_dispatch":true,"real_rapier_session":true,
		"synthetic_device_selection":true,"test_host_publisher":true,
		"poll_only_negative_control":true,
		"full_desktop_gamepad_qualified":false,
		"physical_gamepad_qualified":false,"rendered_fps_measured":false
	}))
	quit(0 if failures == 0 else 1)
