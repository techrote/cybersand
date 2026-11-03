extends "res://tests/play_life001_shared_host_case.gd"

# INPUT010 uses normal automatic Main/native/Rapier callbacks and real Input
# dispatch. Only window focus and gamepad enumeration are synthetic. The
# toggle-only negative reproduces the old P handler in the same real host.
const Session = preload("res://scripts/physical_actor_session.gd")
const TEST_DEVICE: int = 31
const OTHER_DEVICE: int = 30
var desktop: Control
var fixture_started_usec: int = 0
var row: Dictionary = {}


class ObservedMain:
	extends "res://scripts/main.gd"
	var test_window_focus: bool = true
	var legacy_pause_only: bool = false
	var main_callbacks: int = 0
	var physics_callbacks: int = 0
	var phase: String = "setup"
	var records: Array[Dictionary] = []
	var overflow: bool = false

	func _actor_window_has_focus() -> bool:
		return test_window_focus

	func _unhandled_key_input(event: InputEvent) -> void:
		if legacy_pause_only and event is InputEventKey and event.keycode == KEY_P:
			if event.pressed and not event.echo:
				paused = not paused
			return
		super._unhandled_key_input(event)

	func _process(delta: float) -> void:
		main_callbacks += 1
		super._process(delta)

	func state() -> Dictionary:
		if physical_actor_session == null or latest_snapshot == null:
			return {}
		var view: Dictionary = physical_actor_session.snapshot().actors[0]
		var action: Dictionary = view.get("action", {})
		var move: Vector2 = action.get("move", Vector2.ZERO)
		return {"time_usec":Time.get_ticks_usec(), "worker":simulation_worker.get_instance_id(),
			"session":physical_actor_session.get_instance_id(), "bridge":rapier_bridge.get_instance_id(),
			"run_id":str(view.run_id), "epoch":int(view.epoch),
			"world_generation":int(latest_snapshot.render_world_generation),
			"physics_tick":int(view.tick), "bridge_step":rapier_bridge.manual_step_count(),
			"native_tick":int(latest_snapshot.tick_index), "snapshot_serial":int(latest_snapshot.serial),
			"native_backend":str(latest_snapshot.backend_name), "native_paused":bool(latest_snapshot.paused),
			"paused":paused, "suspended":bool(view.suspended), "rearm":_actor_input_rearm,
			"control_generation":int(view.control_generation), "sequence":int(view.last_sequence),
			"pending_edges":int(view.pending_input_edges), "move":[move.x,move.y],
			"primary":bool(action.get("primary", false)), "fault":str(view.get("fault", "")),
			"main_callbacks":main_callbacks, "physics_callbacks":physics_callbacks,
			"accepted_commands":physical_actor_session.accepted_commands}

	func _physics_process(delta: float) -> void:
		physics_callbacks += 1
		var before: Dictionary = state()
		super._physics_process(delta)
		if phase == "setup" or before.is_empty() or physical_actor_session == null:
			return
		if records.size() >= 512:
			overflow = true
			return
		records.append({"phase":phase, "before":before, "after":state()})


class SelectedPadBridge:
	extends "res://scripts/playable_course_gamepad_events.gd"
	func _selected_joypad() -> int:
		return 31


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_INPUT010: " + message)


func bounded(predicate: Callable, message: String) -> bool:
	var start: int = Time.get_ticks_usec()
	var deadline: int = mini(start + WAIT_TIMEOUT_MS * 1000, fixture_started_usec + Watchdogs.microseconds("complex_fixture_seconds"))
	var ok: bool = false
	while Time.get_ticks_usec() < deadline:
		if predicate.call():
			ok = Time.get_ticks_usec() <= deadline
			break
		await process_frame
	row.waits.append({"name":message, "started_usec":start, "deadline_usec":deadline,
		"ended_usec":Time.get_ticks_usec(), "passed":ok})
	expect(ok, message)
	return ok


func start_button(device: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_START
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func toggle_control(control: String) -> void:
	if control == "start":
		start_button(TEST_DEVICE, true)
		start_button(TEST_DEVICE, false)
	else:
		var code: Key = KEY_P if control == "p" else KEY_ESCAPE
		parse_key(code, true)
		parse_key(code, false)


func input_rearmed() -> bool:
	return not desktop._actor_input_rearm


func completed_records(phase: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in desktop.records:
		if record.phase == phase and record.after.physics_tick == record.before.physics_tick + 1 \
			and record.after.bridge_step == record.before.bridge_step + 1:
			result.append(record)
	return result


func phase_completed(phase: String, count: int = 3) -> bool:
	return completed_records(phase).size() >= count


func paused_acknowledged(serial: int) -> bool:
	var value: Dictionary = desktop.state()
	return value.paused and value.native_paused and value.suspended and value.snapshot_serial > serial


func new_keyboard_session(epoch: int, rig: StringName) -> bool:
	return actor_ready(desktop, rig) and desktop._physical_epoch > epoch \
		and desktop.playable_session_options.controls == "keyboard"


func same_owner(left: Dictionary, right: Dictionary) -> bool:
	for key: String in ["worker", "session", "bridge", "run_id", "epoch", "world_generation"]:
		if left.get(key) != right.get(key):
			return false
	return true


func test_sequence(rig: StringName) -> bool:
	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
		"normal authored course admission")
	if not await bounded(Callable(self, "course_installed").bind(desktop), "course installation"):
		return false
	expect(desktop.apply_actor_prototype_configuration(StringName("rapier/" + str(rig)), &"human", false),
		"normal mechanical rig admission")
	if not await bounded(Callable(self, "actor_ready").bind(desktop, rig), "actor and native terrain installation"):
		return false
	row.identity = desktop.state()
	row.recipe_hash = str(desktop.microscenario_definition.source_recipe_hash)
	toggle_control("p")
	if not await bounded(Callable(self, "clocks_advanced").bind(desktop, rig,
		int(row.identity.physics_tick), int(row.identity.native_tick)), "automatic native and Rapier start"):
		return false

	# Matched negative: remove only immediate cancellation by restoring the
	# original P event handler. Both transitions occur before any callback.
	desktop.legacy_pause_only = true
	parse_key(KEY_SPACE, true)
	parse_key(KEY_SPACE, false)
	var negative_before: Dictionary = desktop.state()
	expect(negative_before.pending_edges == 2, "negative begins with two real unconsumed edges")
	toggle_control("p")
	toggle_control("p")
	var negative_after: Dictionary = desktop.state()
	expect(not negative_after.paused and negative_after.pending_edges == 2
		and negative_after.control_generation == negative_before.control_generation
		and negative_after.physics_tick == negative_before.physics_tick
		and negative_after.main_callbacks == negative_before.main_callbacks,
		"toggle-only negative retains stale edges and authority across the callback gap")
	row.toggle_only_negative = {"before":negative_before, "after":negative_after,
		"stale_edges_retained":negative_after.pending_edges == 2}
	desktop.legacy_pause_only = false
	desktop.cancel_playable_course_input() # Negative-control cleanup only.
	if not await bounded(Callable(self, "input_rearmed"), "neutral rearm after negative cleanup"):
		return false

	var code: Key = KEY_D if rig == &"acrobat" else KEY_W
	var expected_move: Array = [1.0,0.0] if rig == &"acrobat" else [0.0,-1.0]
	row.expected_move = expected_move
	for control: String in ["p", "escape", "start"]:
		parse_key(KEY_SPACE, true)
		parse_key(KEY_SPACE, false)
		parse_key(code, true)
		var old_view: Dictionary = desktop.physical_actor_session.observation(0)
		var stale: Dictionary = Session.make_command(old_view, int(old_view.last_sequence) + 1,
			{"move":Vector2(expected_move[0],expected_move[1])}, 6)
		var before: Dictionary = desktop.state()
		expect(before.pending_edges == 2, control + ": real input is pending before pause")
		toggle_control(control)
		var pause_transition: Dictionary = desktop.state()
		var immediately_revoked: bool = (pause_transition.paused and pause_transition.pending_edges == 0
			and pause_transition.rearm and pause_transition.control_generation > before.control_generation
			and pause_transition.physics_tick == before.physics_tick
			and pause_transition.main_callbacks == before.main_callbacks)
		expect(immediately_revoked,
			control + ": pause immediately revokes authority before any callback")
		if not immediately_revoked:
			row.transitions.append({"control":control, "before":before, "paused":pause_transition,
				"immediate_revocation_failed":true})
			return false
		toggle_control(control)
		var after: Dictionary = desktop.state()
		expect(not after.paused and after.pending_edges == 0 and after.rearm
			and after.control_generation > pause_transition.control_generation
			and after.physics_tick == before.physics_tick and same_owner(before, after),
			control + ": rapid resume retains the owner but requires fresh authority")
		var rejected_before: int = desktop.physical_actor_session.rejected_commands
		var admitted: bool = desktop.physical_actor_session.submit(stale, &"human")
		var stale_reason: String = desktop.physical_actor_session.last_error
		expect(not admitted and stale_reason == "observation_not_issued"
			and desktop.physical_actor_session.rejected_commands == rejected_before + 1,
			control + ": still-in-lease old authority refuses for revocation, not expiry")
		row.transitions.append({"control":control, "before":before, "paused":pause_transition, "after":after,
			"stale_admitted":admitted, "stale_reason":stale_reason})

		desktop.phase = control + "_held"
		if not await bounded(Callable(self, "phase_completed").bind(desktop.phase, 3),
			control + ": automatic completed steps with held pre-pause input"):
			return false
		for record: Dictionary in completed_records(desktop.phase):
			expect(record.after.rearm and record.after.move == [0.0,0.0] and not record.after.primary
				and record.after.pending_edges == 0,
				control + ": held input and retired quick tap cannot actuate completed Rapier steps")
		desktop.phase = "setup"
		parse_key(code, false)
		if not await bounded(Callable(self, "input_rearmed"), control + ": release rearms"):
			return false
		parse_key(code, true)
		desktop.phase = control + "_fresh"
		if not await bounded(Callable(self, "phase_completed").bind(desktop.phase, 3),
			control + ": fresh input reaches completed Rapier steps"):
			return false
		for record: Dictionary in completed_records(desktop.phase):
			expect(record.after.move == expected_move and not record.after.rearm
				and record.after.accepted_commands > record.before.accepted_commands
				and record.after.control_generation > before.control_generation,
				control + ": fresh admitted movement is applied in a completed step")
		desktop.phase = "setup"
		parse_key(code, false)
		if not await bounded(Callable(self, "input_rearmed"), control + ": neutral ending"):
			return false

	var prior: Dictionary = desktop.state()
	start_button(OTHER_DEVICE, true)
	start_button(OTHER_DEVICE, false)
	expect(desktop.paused == prior.paused and desktop.state().control_generation == prior.control_generation,
		"unselected controller Start cannot change pause or revoke active authority")
	desktop.test_window_focus = false
	for control: String in ["p", "escape", "start"]:
		toggle_control(control)
	expect(desktop.paused == prior.paused, "unfocused pause inputs cannot change session state")
	desktop.test_window_focus = true

	toggle_control("p")
	if not await bounded(Callable(self, "paused_acknowledged").bind(int(prior.snapshot_serial)),
		"ordinary pause is acknowledged by the actual native owner"):
		return false
	var acknowledged: Dictionary = desktop.state()
	desktop.phase = "paused"
	for _frame: int in range(6):
		await physics_frame
	desktop.phase = "setup"
	var quiescent: Dictionary = desktop.state()
	expect(quiescent.physics_tick == acknowledged.physics_tick
		and quiescent.bridge_step == acknowledged.bridge_step and quiescent.native_tick == acknowledged.native_tick
		and quiescent.main_callbacks > acknowledged.main_callbacks and same_owner(acknowledged, quiescent),
		"acknowledged pause is quiescent while Main callbacks continue")

	desktop.playable_session_panel.show_selection()
	toggle_control("start")
	expect(desktop.paused and not desktop.toggle_playable_course_pause(),
		"visible selector owns pause/resume input")
	parse_key(code, true)
	desktop.playable_session_panel.resume_play()
	expect(not desktop.paused and desktop._actor_input_rearm and not desktop.playable_session_panel.visible,
		"explicit Resume button uses the same immediate cancellation/rearm path")
	desktop.phase = "panel_held"
	if not await bounded(Callable(self, "phase_completed").bind(desktop.phase, 3),
		"panel resume produces completed neutral steps with held input"):
		return false
	for record: Dictionary in completed_records(desktop.phase):
		expect(record.after.rearm and record.after.move == [0.0,0.0] and not record.after.primary,
			"panel resume does not replay held movement")
	desktop.phase = "setup"
	parse_key(code, false)
	if not await bounded(Callable(self, "input_rearmed"), "panel release rearms"):
		return false
	for record: Dictionary in desktop.records:
		expect(same_owner(row.identity, record.after) and record.after.fault.is_empty(),
			"all pause/input observations preserve the same healthy owner")
	row.before_keyboard_rebuild = desktop.state()

	# Keyboard-only refusal uses a real accepted composition, not a flag
	# relabelled around an old applied session.
	var panel = desktop.playable_session_panel
	panel.show_selection()
	panel.control_choice.select(1)
	var old_epoch: int = desktop._physical_epoch
	expect(panel.build_selected(), "keyboard-only selection enters normal reconstruction")
	expect(not desktop.set_playable_course_paused(false),
		"resume refuses while a real replacement transaction is pending")
	if not await bounded(Callable(self, "new_keyboard_session").bind(old_epoch, rig),
		"keyboard-only native and physical replacement is acknowledged"):
		return false
	panel.resume_play()
	var keyboard_initial: Dictionary = desktop.state()
	if not await bounded(Callable(self, "clocks_advanced").bind(desktop, rig,
		int(keyboard_initial.physics_tick), int(keyboard_initial.native_tick)), "keyboard-only session runs"):
		return false
	var keyboard_before: Dictionary = desktop.state()
	toggle_control("start")
	expect(not desktop.paused and desktop.state().control_generation == keyboard_before.control_generation,
		"keyboard-only accepted session ignores gamepad Start")
	toggle_control("escape")
	expect(desktop.paused and desktop._actor_input_rearm, "keyboard-only Escape still pauses immediately")
	row.keyboard_session = desktop.state()
	expect(row.keyboard_session.epoch > row.identity.epoch
		and row.keyboard_session.world_generation > row.identity.world_generation
		and row.keyboard_session.worker == row.identity.worker,
		"keyboard-only reconstruction uses a new actor/World on the same existing worker")
	expect(not desktop.overflow and not desktop.simulation_worker.has_failed(),
		"bounded recording and healthy native worker")
	return true


func run() -> void:
	fixture_started_usec = Time.get_ticks_usec()
	var rig: StringName = target_rig()
	row = {"rig":str(rig), "waits":[], "transitions":[], "records":[]}
	release_controls()
	expect(ClassDB.class_exists("CyberNativeCellWorld") and ClassDB.class_exists("RapierPhysicsServer2D"),
		"actual native and Rapier backends are available")
	expect(rig in Course.MECHANICAL_PRESETS, "wrapper selects one supported mechanical rig")
	expect(Input.get_connected_joypads().is_empty(), "synthetic pad selection cannot collide with physical hardware")
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(ObservedMain)
	desktop.get_node("CourseGamepadEvents").set_script(SelectedPadBridge)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var success: bool = false
	if failures == 0 and worker != null and desktop.worker_start_error == OK and worker._thread.is_started():
		success = await test_sequence(rig)
	else:
		expect(false, "original native worker starts")
	row.records = desktop.records.duplicate(true)
	row.capture_overflow = desktop.overflow
	row.completed = success and failures == 0
	desktop.phase = "setup"
	start_button(TEST_DEVICE, false)
	start_button(OTHER_DEVICE, false)
	var session: Variant = desktop.physical_actor_session
	var teardown_started_usec: int = Time.get_ticks_usec()
	await close_cycle(desktop, worker, session, "INPUT010: ")
	var teardown_usec: int = Time.get_ticks_usec() - teardown_started_usec
	expect(teardown_usec <= WAIT_TIMEOUT_MS * 1000, "teardown respects the configured operation watchdog")
	expect(Time.get_ticks_usec() - fixture_started_usec <= Watchdogs.microseconds("complex_fixture_seconds"), "fixture respects its configured fixture watchdog")
	print("PLAY_INPUT010_RESULT ", JSON.stringify({"schema":"play-input010-v1",
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"), "rig":str(rig),
		"display_server":DisplayServer.get_name(), "physics_engine":ProjectSettings.get_setting("physics/2d/physics_engine"),
		"assertions":assertions, "failures":failures, "row":row,
		"elapsed_usec":Time.get_ticks_usec()-fixture_started_usec,
		"teardown_usec":teardown_usec,
		"worker_joined":joined_workers == 1, "session_retired":retired_sessions == 1,
		"real_host":true, "automatic_callbacks":true, "manual_physics_calls":0,
		"window_focus_seam":true, "device_enumeration_seam":true, "toggle_only_negative":true,
		"retries":0, "rendered_fps_measured":false, "physical_devices_qualified":false,
		"human_feel_qualified":false, "shader_startup_qualified":false}))
	quit(0 if row.completed and failures == 0 else 1)
