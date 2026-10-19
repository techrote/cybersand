extends SceneTree

# Run with a rendered display: the production admission method includes the
# actual Window focus check. A headless false result is not modal evidence.
const MAPS: Array[String] = [CyberGreyArea51.SCENARIO_ID, CyberBlacksiteNine.SCENARIO_ID]
const HELD_KEYS: Array[Key] = [KEY_W, KEY_SPACE, KEY_SHIFT, KEY_E, KEY_X, KEY_C]
const TOOL_KEYS: Array[Key] = [KEY_M, KEY_N, KEY_U]
var assertions: int = 0
var failures: int = 0


class InputSink:
	extends CyberSimulationWorker
	var packets: Array[Dictionary] = []
	var usable_packets: Array[Dictionary] = []
	var cancellations: int = 0
	var usable_cancellations: int = 0

	func submit_actor_rig_action(_actor_id: int, _epoch: int, _sequence: int,
		_observed_tick: int, movement: Vector2, _aim: Vector2, _effort: float,
		trim: float, reel: float, primary: bool, secondary: bool, auxiliary: bool,
		_lease_ticks: int = 12, _producer: StringName = &"policy") -> bool:
		packets.append({"move": movement, "trim": trim, "reel": reel,
			"primary": primary, "secondary": secondary, "auxiliary": auxiliary})
		return true

	func submit_actor_usable_action(_actor_id: int, _epoch: int, _sequence: int,
		_observed_tick: int, _usable_index: int, _aim: Vector2, _power: float,
		trigger: bool, alternate: bool, _lease_ticks: int = 6,
		_producer: StringName = &"policy") -> bool:
		usable_packets.append({"trigger": trigger, "alternate": alternate})
		return true

	func cancel_actor_input(_actor_id: int, _epoch: int, _producer: StringName) -> bool:
		cancellations += 1
		return true

	func cancel_actor_usable_input(_actor_id: int, _epoch: int, _producer: StringName) -> bool:
		usable_cancellations += 1
		return true

	func has_failed() -> bool:
		return false


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("SHOWCASE_ACTOR_MAP_INPUT: " + message)


func wait_for(predicate: Callable, timeout_ms: int = 20000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false


func key(code: Key, pressed: bool, physical_only: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_NONE if physical_only else code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func release_keys(host: Control) -> void:
	for code: Key in host.ACTOR_CONTROL_KEYS + host.PHYSICAL_TOOL_KEYS + [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		key(code, false)
		key(code, false, true)


func regain_focus(host: Control) -> bool:
	host.get_viewport().gui_release_focus()
	root.grab_focus()
	return await wait_for(func() -> bool: return root.has_focus(), 3000)


func installed(host: Control) -> bool:
	return await wait_for(func() -> bool:
		return host.latest_snapshot != null and host.pending_microscenario_apply.is_empty() and host._actor_reset_receipt == 0)


func fresh_packet(host: Control, sink: InputSink, physical: bool, label: String) -> void:
	for code: Key in HELD_KEYS: key(code, true)
	if physical:
		for code: Key in TOOL_KEYS: key(code, true)
	var before: int = sink.packets.size()
	host.publish_actor_keyboard_input()
	var packet: Dictionary = host.physical_actor_session._commands[0] if physical else (
		sink.packets.back() if sink.packets.size() > before else {})
	expect(not packet.is_empty(), label + ": fresh held actor packet is admitted")
	if not packet.is_empty():
		expect(packet.move.y == -1.0 and packet.trim == 1.0 and packet.reel == 1.0,
			label + ": vertical movement, trim and reel survive after release")
		expect(packet.primary and packet.secondary and packet.auxiliary,
			label + ": primary, secondary and auxiliary survive after release")
		if physical:
			expect(packet.equipment.trigger and packet.equipment.drop and packet.equipment.attach,
				label + ": M/N/U equipment channels survive after release")
	if not physical:
		var usable_before: int = sink.usable_packets.size()
		host._publish_actor_usable_buttons(true, true)
		expect(sink.usable_packets.size() == usable_before + 1 and sink.usable_packets.back().trigger
			and sink.usable_packets.back().alternate, label + ": fresh sampled usable buttons are admitted")


func fixture(scene_id: String, physical: bool) -> void:
	var label: String = scene_id + (" / articulated" if physical else " / sampled")
	var host: Control = load("res://main.tscn").instantiate()
	root.add_child(host)
	expect(await installed(host), label + ": initial owner is ready")
	var p = host.blacksite_nine_presentation
	expect(p.launch_grey() if scene_id == CyberGreyArea51.SCENARIO_ID else p.launch(), label + ": map launcher accepts")
	expect(await installed(host), label + ": native owner accepts map")
	var model: StringName = &"rapier/pouncer" if physical else &"gemini"
	expect(host.apply_actor_prototype_configuration(model, &"human", false), label + ": real F5 receiver accepts actor")
	expect(await installed(host), label + ": native owner acknowledges F5 actor replacement")
	if physical:
		expect(await wait_for(func() -> bool: return host._physical_terrain_ready), label + ": articulated terrain fence opens")
	else:
		expect(not host.latest_snapshot.actor_prototypes.is_empty()
			and host.latest_snapshot.actor_prototypes.models[0] == &"gemini", label + ": sampled actor identity is published")
	host.paused = false
	host.update_worker_frame_state()
	expect(await wait_for(func() -> bool: return not host.latest_snapshot.paused), label + ": owner is unpaused")

	# Preserve the accepted immutable snapshot, stop its owner, and inspect only
	# the public publisher's outgoing packets / main-owned Rapier input queue.
	# No test reads or edits a live worker's native World.
	host.set_process(false)
	host.set_physics_process(false)
	host.set_process_input(false)
	host.set_process_unhandled_input(false)
	host.set_process_unhandled_key_input(false)
	host.simulation_worker.stop_worker()
	var sink := InputSink.new()
	host.simulation_worker = sink
	if not physical:
		# A valid selected slot exercises usable packet admission. Native usable
		# equipment/effect acknowledgement has its own integration fixtures.
		host.actor_usable_index = 0
	release_keys(host)
	expect(await regain_focus(host), label + ": rendered window has actual OS focus")
	expect(host.actor_keyboard_allowed(), label + ": neutral focused actor admission is positive")
	host.publish_actor_keyboard_input()
	host._publish_actor_usable_buttons(false, false)
	fresh_packet(host, sink, physical, label + " before map")

	p.show_map()
	expect(p.map_popup.visible, label + ": actual tile popup opens")
	var count: int = sink.packets.size()
	var cancel_count: int = sink.cancellations
	var usable_count: int = sink.usable_packets.size()
	var usable_cancel_count: int = sink.usable_cancellations
	expect(not host.actor_keyboard_allowed(), label + ": open map refuses actor admission")
	host.publish_actor_keyboard_input()
	host._publish_actor_usable_buttons(true, true)
	if physical:
		expect(host.physical_actor_session._commands[0].is_empty(), label + ": open map revokes physical movement and equipment")
	else:
		expect(sink.packets.size() == count and sink.cancellations > cancel_count, label + ": open map cancels sampled command")
		expect(sink.usable_packets.size() == usable_count and sink.usable_cancellations > usable_cancel_count,
			label + ": open map cancels sampled usable command")
	p.map_popup.hide()
	expect(await regain_focus(host), label + ": focused window returns after map close")
	# Inject the retained held state after native focus settles; this isolates
	# the map release fence from operating-system key clearing on focus changes.
	for code: Key in HELD_KEYS: key(code, true)
	if physical:
		for code: Key in TOOL_KEYS: key(code, true)
	expect(not host.actor_keyboard_allowed(), label + ": closed map still refuses held actor keys")
	host.publish_actor_keyboard_input()
	host._publish_actor_usable_buttons(true, true)
	if physical:
		expect(host.physical_actor_session._commands[0].is_empty(), label + ": closed-held map keeps physical packet cancelled")
	else:
		expect(sink.packets.size() == count and sink.usable_packets.size() == usable_count,
			label + ": closed-held map keeps both sampled channels cancelled")
	release_keys(host)
	expect(host.actor_keyboard_allowed(), label + ": fully released map rearms admission")
	host.publish_actor_keyboard_input()
	host._publish_actor_usable_buttons(false, false)
	fresh_packet(host, sink, physical, label + " after map")
	release_keys(host)
	host.publish_actor_keyboard_input()
	host._publish_actor_usable_buttons(false, false)

	# A popup can open and close between two input publications. Check every
	# logical and physical key independently with no intervening cancellation
	# to conceal a missing presenter latch in the shared actor admission method.
	p.show_map()
	p.map_popup.hide()
	expect(await regain_focus(host), label + ": focus is real for the inter-publication map boundary")
	for physical_only: bool in [false, true]:
		for code: Key in host.ACTOR_CONTROL_KEYS + host.PHYSICAL_TOOL_KEYS + [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			p._release_pointer()
			key(code, true, physical_only)
			expect(Input.is_physical_key_pressed(code) if physical_only else Input.is_key_pressed(code),
				label + ": test holds " + OS.get_keycode_string(code))
			expect(not host.actor_keyboard_allowed(), label + ": map release gate blocks " +
				("physical " if physical_only else "logical ") + OS.get_keycode_string(code))
			key(code, false, physical_only)
			expect(host.actor_keyboard_allowed(), label + ": releasing isolated key restores admission")
	print("SHOWCASE_ACTOR_MAP_INPUT_CASE: " + label)
	release_keys(host)
	host.queue_free()
	await process_frame
	await process_frame


func run() -> void:
	if DisplayServer.get_name() == "headless":
		expect(false, "use a rendered display so the real Window focus check is exercised")
	else:
		ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
		root.size = Vector2i(1600, 900)
		for scene_id: String in MAPS:
			for physical: bool in [false, true]:
				await fixture(scene_id, physical)
	print("SHOWCASE_ACTOR_MAP_INPUT: %d assertions; %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
