extends SceneTree

# Real desktop input adapter, real Input press/release events and the actual
# articulated Session command/edge queues. The fixture only bypasses OS focus
# and application startup; it does not replace command admission with a sink.
const Session = preload("res://scripts/physical_actor_session.gd")
var assertions: int = 0
var failures: int = 0


class KeyboardHarness:
	extends "res://scripts/main.gd"
	var allowed: bool = true
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_key_input(false)
	func actor_keyboard_allowed() -> bool: return allowed
	func actor_pointer_aim() -> Vector2: return Vector2.RIGHT


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("AFTERIMAGE_HOST_INPUT: "+message)


func event(code: Key, pressed: bool) -> InputEventKey:
	var result := InputEventKey.new()
	result.keycode = code
	result.physical_keycode = code
	result.pressed = pressed
	Input.parse_input_event(result)
	Input.flush_buffered_events()
	return result


func harness() -> KeyboardHarness:
	var desktop := KeyboardHarness.new()
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	desktop.add_child(layout)
	var view := TextureRect.new()
	view.name = "World"
	view.material = ShaderMaterial.new()
	layout.add_child(view)
	var label := Label.new()
	label.name = "Status"
	layout.add_child(label)
	var bodies := Node2D.new()
	bodies.name = "RigidBodies"
	desktop.add_child(bodies)
	for index: int in range(1,4):
		var body := RigidBody2D.new()
		body.name = "TestBody%d" % index
		body.freeze = true
		bodies.add_child(body)
	root.add_child(desktop)
	desktop.actor_producer_selection = &"human"
	desktop._physical_epoch = 1
	desktop.physical_actor_session = Session.new()
	desktop.add_child(desktop.physical_actor_session)
	return desktop


func install(desktop: KeyboardHarness, model: StringName) -> void:
	desktop.physical_rig_id = model
	desktop._actor_input_rearm = true
	desktop._physical_epoch += 1
	desktop.physical_actor_session.close()
	expect(desktop.physical_actor_session.configure([{ "model":model,"producer":&"human",
		"position":Vector2(120,90)}],desktop.get_world_2d().space,desktop._physical_epoch),
		"actual physical model configures "+str(model))
	desktop._publish_physical_keyboard_input()
	expect(not desktop._actor_input_rearm,"released keyboard arms actual desktop adapter "+str(model))


func run() -> void:
	var desktop: KeyboardHarness = harness()
	install(desktop,&"acrobat")
	desktop._unhandled_key_input(event(KEY_CTRL,true))
	expect(bool(desktop.physical_actor_session._commands[0].auxiliary),"Ctrl press reaches actual F5 Afterimage command")
	desktop._unhandled_key_input(event(KEY_CTRL,false))
	expect(not bool(desktop.physical_actor_session._commands[0].auxiliary),"Ctrl release reaches actual command before a physics sample")
	var edges: Array = desktop.physical_actor_session._button_edges[0]
	expect(edges.size() == 2 and edges[0].button == "auxiliary" and edges[0].pressed \
		and edges[1].button == "auxiliary" and not edges[1].pressed,
		"quick Ctrl press/release retains both admitted Session edges")
	# Revocation must retain the held-key fence rather than replaying an action
	# when the window/menu becomes controllable again.
	event(KEY_CTRL,true)
	desktop.allowed = false
	desktop._publish_physical_keyboard_input()
	expect(desktop._actor_input_rearm and desktop.physical_actor_session._commands[0].is_empty(),
		"focus/menu rejection cancels command and requires release")
	desktop.allowed = true
	desktop._publish_physical_keyboard_input()
	expect(desktop._actor_input_rearm and desktop.physical_actor_session._commands[0].is_empty(),
		"held Ctrl cannot rearm Afterimage when focus returns")
	desktop._unhandled_key_input(event(KEY_CTRL,false))
	expect(not desktop._actor_input_rearm and not desktop.physical_actor_session._commands[0].auxiliary,
		"Ctrl release itself rearms neutrally through the actual event handler")
	event(KEY_C,true)
	desktop._publish_physical_keyboard_input()
	expect(not desktop.physical_actor_session._commands[0].auxiliary,"C no longer controls F5 Afterimage auxiliary")
	event(KEY_C,false)
	for model: StringName in [&"stuntbuggy",&"trialsbike",&"arcadelander",&"jetbarrel",&"runner"]:
		install(desktop,model)
		desktop._unhandled_key_input(event(KEY_C,true))
		expect(desktop.physical_actor_session._commands[0].auxiliary,"other physical actors retain C press "+str(model))
		desktop._unhandled_key_input(event(KEY_C,false))
		expect(not desktop.physical_actor_session._commands[0].auxiliary,"other physical actors retain C release "+str(model))
		event(KEY_CTRL,true)
		desktop._publish_physical_keyboard_input()
		expect(not desktop.physical_actor_session._commands[0].auxiliary,"Ctrl does not change other actor controls "+str(model))
		desktop._actor_input_rearm = true
		desktop._publish_physical_keyboard_input()
		expect(not desktop._actor_input_rearm,"unmapped Ctrl does not block another actor rearm "+str(model))
		event(KEY_CTRL,false)
	desktop.physical_actor_session.close()
	desktop.free()
	await process_frame
	print("AFTERIMAGE_HOST_INPUT: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
