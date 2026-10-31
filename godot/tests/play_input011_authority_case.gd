extends "res://tests/play_life001_shared_host_case.gd"

# INPUT011 drives actual production modal/button/focus admission paths before
# any callback can poll them. Main/native/Rapier callbacks remain automatic.
# Window focus and its notification are synthetic, not an OS-focus qualification.
const Session = preload("res://scripts/physical_actor_session.gd")
const MODES: Array[String] = ["actor_picker", "environment_tuning", "pause_button", "focused_pause_button", "gui_focus", "window_focus"]
const MAX_RECORDS: int = 512
var desktop: Control
var fixture_started_usec: int = 0
var row: Dictionary = {}


class ObservedMain:
	extends "res://scripts/main.gd"
	var test_window_focus: bool = true
	var bypass_cancel: bool = false
	var bypass_calls: int = 0
	var phase: String = "setup"
	var main_callbacks: int = 0
	var physics_callbacks: int = 0
	var first_main_usec: int = 0
	var in_physics: bool = false
	var prepared: Dictionary = {}
	var records: Array[Dictionary] = []
	var overflow: bool = false

	func _actor_window_has_focus() -> bool:
		return test_window_focus

	func cancel_playable_course_input() -> void:
		# Matched adverse control: omit only the existing authority revocation.
		# The actual production popup handler and automatic callbacks still run.
		if bypass_cancel:
			bypass_calls += 1
			return
		super.cancel_playable_course_input()

	func _process(delta: float) -> void:
		main_callbacks += 1
		super._process(delta)
		if first_main_usec == 0:
			first_main_usec = Time.get_ticks_usec()

	func _publish_physical_keyboard_input(trigger_override: Variant = null,
			alternate_override: Variant = null) -> void:
		var prior: int = physical_actor_session.accepted_commands if physical_actor_session != null else -1
		super._publish_physical_keyboard_input(trigger_override, alternate_override)
		if in_physics and physical_actor_session != null and physical_actor_session.accepted_commands > prior:
			var view: Dictionary = physical_actor_session.snapshot().actors[0]
			var command: Dictionary = physical_actor_session._commands[0]
			var move: Vector2 = command.get("move", Vector2.ZERO)
			prepared = {"sequence":int(view.last_sequence), "control_generation":int(view.control_generation),
				"admitted_tick":int(view.tick), "move":[move.x,move.y]}

	func state() -> Dictionary:
		if physical_actor_session == null or latest_snapshot == null:
			return {}
		# A copied non-issuing physical observation cannot mint input authority.
		var view: Dictionary = physical_actor_session.snapshot().actors[0]
		var action: Dictionary = view.get("action", {})
		var move: Vector2 = action.get("move", Vector2.ZERO)
		var position: Vector2 = view.get("position", Vector2.INF)
		return {"time_usec":Time.get_ticks_usec(), "worker":simulation_worker.get_instance_id(),
			"session":physical_actor_session.get_instance_id(), "bridge":rapier_bridge.get_instance_id(),
			"run_id":str(view.run_id), "epoch":int(view.epoch),
			"world_generation":int(latest_snapshot.render_world_generation),
			"physics_tick":int(view.tick), "bridge_step":rapier_bridge.manual_step_count(),
			"native_tick":int(latest_snapshot.tick_index), "snapshot_serial":int(latest_snapshot.serial),
			"native_backend":str(latest_snapshot.backend_name), "paused":paused,
			"suspended":bool(view.suspended), "rearm":_actor_input_rearm,
			"control_generation":int(view.control_generation), "sequence":int(view.last_sequence),
			"pending_edges":int(view.pending_input_edges), "move":[move.x,move.y],
			"primary":bool(action.get("primary",false)), "position":[position.x,position.y],
			"fault":str(view.get("fault","")), "main_callbacks":main_callbacks,
			"physics_callbacks":physics_callbacks, "accepted_commands":physical_actor_session.accepted_commands}

	func _physics_process(delta: float) -> void:
		physics_callbacks += 1
		var before: Dictionary = state()
		prepared = {}
		in_physics = true
		super._physics_process(delta)
		in_physics = false
		if phase == "setup" or before.is_empty() or physical_actor_session == null:
			return
		if records.size() >= 512:
			overflow = true
			return
		records.append({"phase":phase, "before":before, "after":state(),
			"prepared":prepared.duplicate(true)})


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_INPUT011: " + message)


func bounded(predicate: Callable, name: String, allowance_usec: int = -1) -> bool:
	if allowance_usec < 0:
		allowance_usec = Watchdogs.microseconds("operation_seconds")
	var started: int = Time.get_ticks_usec()
	var deadline: int = mini(started + allowance_usec, fixture_started_usec + Watchdogs.microseconds("complex_fixture_seconds"))
	var passed: bool = false
	while Time.get_ticks_usec() < deadline:
		if predicate.call():
			passed = Time.get_ticks_usec() <= deadline
			break
		await process_frame
	var ended: int = Time.get_ticks_usec()
	row.waits.append({"name":name, "started_usec":started, "deadline_usec":deadline,
		"ended_usec":ended, "passed":passed})
	expect(passed and ended <= deadline, name)
	return passed and ended <= deadline


func same_owner(left: Dictionary, right: Dictionary) -> bool:
	for key: String in ["worker", "session", "bridge", "run_id", "epoch", "world_generation"]:
		if left.get(key) != right.get(key):
			return false
	return true


func completed(phase: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in desktop.records:
		if record.phase == phase and record.after.physics_tick == record.before.physics_tick + 1 \
			and record.after.bridge_step == record.before.bridge_step + 1:
			result.append(record)
	return result


func phase_completed(phase: String, count: int = 3) -> bool:
	return completed(phase).size() >= count


func input_rearmed() -> bool:
	return not desktop._actor_input_rearm


func neutral_step(phase: String) -> bool:
	var values: Array[Dictionary] = completed(phase)
	return not values.is_empty() and values[-1].after.move == [0.0,0.0] \
		and not values[-1].after.primary and values[-1].after.pending_edges == 0


func first_main_completed() -> bool:
	return desktop.first_main_usec != 0


func rapid_transition(mode: String) -> Dictionary:
	var opened: bool = false
	var blocked: bool = false
	var closed: bool = false
	var opened_state: Dictionary = {}
	var focused_button: Dictionary = {}
	match mode:
		"actor_picker":
			desktop.toggle_actor_prototypes()
			opened = desktop.actor_prototype_panel.visible
			blocked = not desktop.actor_keyboard_allowed()
			opened_state = desktop.state()
			desktop.toggle_actor_prototypes()
			closed = not desktop.actor_prototype_panel.visible
		"environment_tuning":
			desktop.toggle_player_environment_tuning()
			opened = desktop.player_environment_panel.visible
			blocked = not desktop.actor_keyboard_allowed()
			opened_state = desktop.state()
			desktop.toggle_player_environment_tuning()
			closed = not desktop.player_environment_panel.visible
		"pause_button":
			# Emit the existing Button's signal; its production callback decides
			# admission. No fixture writes Main.paused or steps the worker.
			desktop.microscenario_panel.pause_button.pressed.emit()
			opened = desktop.paused
			blocked = not desktop.actor_keyboard_allowed()
			opened_state = desktop.state()
			desktop.microscenario_panel.pause_button.pressed.emit()
			closed = not desktop.paused
		"focused_pause_button":
			var edit: LineEdit = desktop.microscenario_panel.seed_input.get_line_edit()
			edit.grab_focus()
			focused_button = {"focus_before":edit.has_focus(), "before":desktop.state(),
				"keyboard_context_allowed":desktop._actor_keyboard_context_allowed()}
			desktop.microscenario_panel.pause_button.pressed.emit()
			opened = desktop.paused
			blocked = not desktop.actor_keyboard_allowed()
			opened_state = desktop.state()
			# A text owner still refuses the keyboard/gamepad toggle. The visible
			# UI button has its own explicit action through the same pause setter.
			focused_button["keyboard_toggle_admitted"] = desktop.toggle_playable_course_pause()
			focused_button["after_keyboard_toggle"] = desktop.state()
			desktop.microscenario_panel.pause_button.pressed.emit()
			closed = not desktop.paused
			focused_button["focus_after"] = edit.has_focus()
			edit.release_focus()
		"gui_focus":
			var edit: LineEdit = desktop.microscenario_panel.seed_input.get_line_edit()
			edit.grab_focus()
			opened = edit.has_focus()
			blocked = not desktop.actor_keyboard_allowed()
			opened_state = desktop.state()
			edit.release_focus()
			closed = desktop.get_viewport().gui_get_focus_owner() == null
		"window_focus":
			# Production Node notification dispatch, deliberately injected.
			# This cannot establish delivery by a real OS window manager.
			desktop.test_window_focus = false
			desktop.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
			opened = not desktop._actor_window_has_focus()
			blocked = not desktop.actor_keyboard_allowed()
			opened_state = desktop.state()
			desktop.test_window_focus = true
			desktop.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
			closed = desktop._actor_window_has_focus()
	return {"mode":mode, "opened":opened, "blocked":blocked, "closed":closed,
		"opened_state":opened_state, "focused_button":focused_button}


func exercise(mode: String, rig: StringName, negative: bool = false) -> bool:
	var label: String = "bypass_negative" if negative else mode
	var code: Key = KEY_D if rig == &"acrobat" else KEY_W
	var expected_move: Array = [1.0,0.0] if rig == &"acrobat" else [0.0,-1.0]
	desktop.phase = label + "_neutral"
	release_controls()
	if not await bounded(Callable(self, "neutral_step").bind(desktop.phase), label + ": initial completed neutral step"):
		return false
	desktop.phase = "setup"
	parse_key(KEY_SPACE, true)
	parse_key(KEY_SPACE, false)
	parse_key(code, true)
	var view: Dictionary = desktop.physical_actor_session.observation(0)
	var old_command: Dictionary = Session.make_command(view, int(view.last_sequence) + 100000,
		{"move":Vector2(expected_move[0],expected_move[1])}, Session.MAX_LEASE)
	var before: Dictionary = desktop.state()
	expect(before.pending_edges == 2 and not before.rearm and not before.paused,
		label + ": two admitted quick-tap edges and held movement precede transition")
	var old_bypass_count: int = desktop.bypass_calls
	desktop.bypass_cancel = negative
	var transition: Dictionary = rapid_transition(mode)
	desktop.bypass_cancel = false
	var after: Dictionary = desktop.state()
	transition["label"] = label
	transition["negative"] = negative
	transition["before"] = before
	transition["after"] = after
	transition["bypass_calls"] = desktop.bypass_calls - old_bypass_count
	expect(transition.opened and transition.blocked and transition.closed,
		label + ": actual production UI/focus transition owns then releases input")
	expect(after.main_callbacks == before.main_callbacks and after.physics_callbacks == before.physics_callbacks
		and after.physics_tick == before.physics_tick and after.bridge_step == before.bridge_step,
		label + ": open and close occur before any callback can poll the blocked context")
	expect(same_owner(before, after) and not after.paused,
		label + ": rapid transition retains the same running native and Rapier owners")
	if mode == "focused_pause_button":
		var focus: Dictionary = transition.focused_button
		expect(focus.focus_before and focus.focus_after and not focus.keyboard_context_allowed,
			"focused pause: the existing Seed LineEdit keeps keyboard ownership across both button actions")
		expect(not focus.keyboard_toggle_admitted and focus.after_keyboard_toggle.paused == transition.opened_state.paused
			and focus.after_keyboard_toggle.control_generation == transition.opened_state.control_generation,
			"focused pause: keyboard/gamepad toggle remains context-gated")
		expect(transition.opened_state.paused and same_owner(before,focus.before)
			and transition.opened_state.control_generation > focus.before.control_generation
			and after.control_generation > transition.opened_state.control_generation,
			"focused pause: each explicit button action reaches the central pause setter while text focus remains")
	var revoked: bool = after.pending_edges == 0 and after.rearm \
		and after.control_generation > before.control_generation
	transition["revoked"] = revoked
	if negative:
		expect(not revoked and after.pending_edges == 2
			and after.control_generation == before.control_generation and transition.bypass_calls > 0,
			label + ": bypassing only cancellation retains the original authority and edges")
	else:
		expect(revoked, label + ": immediate control-generation cancellation clears pending edges")
	# Observe actual later physical work even when the old production fails the
	# immediate assertion. Do not inject the retained command into that failure.
	desktop.phase = label + "_held"
	if not await bounded(Callable(self, "phase_completed").bind(desktop.phase), label + ": automatic held-input steps"):
		return false
	var held: Array[Dictionary] = completed(desktop.phase)
	transition["held"] = held.duplicate(true)
	var stale_applied: bool = false
	for record: Dictionary in held:
		stale_applied = stale_applied or record.after.primary or record.after.move != [0.0,0.0]
		expect(same_owner(before,record.after) and record.after.fault.is_empty(),
			label + ": completed physical step belongs to the same healthy owner")
		if not negative:
			expect(record.after.rearm and record.prepared.is_empty()
				and record.after.pending_edges == 0 and record.after.move == [0.0,0.0]
				and not record.after.primary and record.after.control_generation > before.control_generation,
				label + ": retired edge and held command cannot actuate a later completed Rapier step")
	transition["stale_applied"] = stale_applied
	if negative:
		expect(stale_applied and held[0].after.primary,
			"bypass negative detects stale_input_applied on the first completed Rapier step")
		transition["negative_reason"] = "stale_input_applied" if stale_applied else "not_reproduced"
	else:
		# The source observation still has lease range; refusal must be its
		# invalidated generation, not a timeout. Do not disturb a failed baseline.
		var stale_receipt: Dictionary = {"tested":false}
		if revoked:
			var current_tick: int = desktop.physical_actor_session.tick
			var before_rejected: int = desktop.physical_actor_session.rejected_commands
			var admitted: bool = desktop.physical_actor_session.submit(old_command,&"human")
			stale_receipt = {"tested":true, "admitted":admitted,
				"reason":desktop.physical_actor_session.last_error, "tick":current_tick,
				"observed_tick":int(old_command.observed_tick), "lease_ticks":int(old_command.lease_ticks),
				"rejected_delta":desktop.physical_actor_session.rejected_commands-before_rejected}
			expect(current_tick < int(old_command.observed_tick)+int(old_command.lease_ticks)
				and not admitted and stale_receipt.reason == "observation_not_issued"
				and stale_receipt.rejected_delta == 1,
				label + ": old still-in-lease authority refuses for generation revocation")
		transition["stale_receipt"] = stale_receipt
	desktop.phase = "setup"
	if negative or not revoked:
		desktop.cancel_playable_course_input() # Deliberate negative/failing-baseline cleanup only.
	parse_key(code,false)
	if not await bounded(Callable(self,"input_rearmed"),label + ": neutral release rearms"):
		return false
	parse_key(code,true)
	desktop.phase = label + "_fresh"
	if not await bounded(Callable(self,"phase_completed").bind(desktop.phase),label + ": fresh admitted physical steps"):
		return false
	var fresh: Array[Dictionary] = completed(desktop.phase)
	for record: Dictionary in fresh:
		expect(same_owner(before,record.after) and not record.prepared.is_empty()
			and record.prepared.move == expected_move and record.after.move == expected_move
			and record.prepared.sequence == record.after.sequence
			and record.prepared.control_generation == record.after.control_generation
			and record.after.control_generation > before.control_generation
			and not record.after.rearm and not record.after.primary,
			label + ": fresh generation input is admitted and applied in an actual completed step")
		if not negative and revoked:
			expect(record.after.control_generation == after.control_generation,
				label + ": recovery uses the production transition generation without test cancellation")
	transition["fresh"] = fresh.duplicate(true)
	transition["expected_move"] = expected_move
	desktop.phase = "setup"
	parse_key(code,false)
	if not await bounded(func() -> bool: return int(desktop.latest_snapshot.tick_index) > int(before.native_tick),
		label + ": genuine native progress"):
		return false
	transition["end"] = desktop.state()
	row.transitions.append(transition)
	return true


func test_sequence(rig: StringName) -> bool:
	var panel = desktop.playable_session_panel
	panel.show_selection()
	panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(rig))
	panel.control_choice.select(1)
	panel.rule_choice.select(0)
	panel.camera_choice.select(0)
	panel.policy_editor.select_preset(0)
	expect(panel.build_selected(),"normal integrated selection admits the selected real rig")
	if not await bounded(Callable(self,"actor_ready").bind(desktop,rig),"actual composed actor/native terrain acknowledgement"):
		return false
	row.identity = desktop.state()
	row.recipe_hash = str(desktop.microscenario_definition.source_recipe_hash)
	panel.resume_play()
	if not await bounded(Callable(self,"clocks_advanced").bind(desktop,rig,
		int(row.identity.physics_tick),int(row.identity.native_tick)),"automatic native and physical start"):
		return false
	for mode: String in MODES:
		if not await exercise(mode,rig):
			return false
	if not await exercise("actor_picker",rig,true):
		return false
	expect(not desktop.overflow and not desktop.simulation_worker.has_failed(),
		"bounded observer and actual native worker remain healthy")
	return true


func run() -> void:
	fixture_started_usec = Time.get_ticks_usec()
	var rig: StringName = target_rig()
	row = {"rig":str(rig),"waits":[],"transitions":[],"records":[]}
	release_controls()
	expect(ClassDB.class_exists("CyberNativeCellWorld") and ClassDB.class_exists("RapierPhysicsServer2D"),
		"actual native and Rapier backends are available")
	expect(rig in Course.MECHANICAL_PRESETS,"wrapper selects one supported mechanical rig")
	# This clock precedes scene load/ready and is not reset after a late callback.
	var main_started_usec: int = Time.get_ticks_usec()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(ObservedMain)
	root.add_child(desktop)
	await process_frame
	var first_ok: bool = await bounded(Callable(self,"first_main_completed"),
		"first actual Main callback returns", Watchdogs.microseconds("main_ack_seconds"))
	var main_ended_usec: int = int(desktop.first_main_usec)
	expect(first_ok and main_ended_usec >= main_started_usec
		and main_ended_usec-main_started_usec <= Watchdogs.microseconds("main_ack_seconds"),
		"first Main acknowledgement respects its configured Main acknowledgement watchdog")
	row.first_main = {"started_usec":main_started_usec,"acknowledged_usec":main_ended_usec,"limit_usec":Watchdogs.microseconds("main_ack_seconds")}
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var success: bool = false
	if failures == 0 and worker != null and desktop.worker_start_error == OK and worker._thread.is_started():
		success = await test_sequence(rig)
	else:
		expect(false,"original native worker and Main startup succeed")
	row.records = desktop.records.duplicate(true)
	row.capture_overflow = desktop.overflow
	desktop.phase = "setup"
	desktop.bypass_cancel = false
	desktop.test_window_focus = true
	var session: Variant = desktop.physical_actor_session
	var teardown_started_usec: int = Time.get_ticks_usec()
	await close_cycle(desktop,worker,session,"INPUT011: ")
	var teardown_usec: int = Time.get_ticks_usec()-teardown_started_usec
	expect(teardown_usec <= WAIT_TIMEOUT_MS*1000,"teardown respects its configured operation watchdog")
	var elapsed_usec: int = Time.get_ticks_usec()-fixture_started_usec
	expect(elapsed_usec <= Watchdogs.microseconds("complex_fixture_seconds"),"fixture respects its configured fixture watchdog")
	row.completed = success and failures == 0
	print("PLAY_INPUT011_RESULT ",JSON.stringify({"schema":"play-input011-v2",
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"rig":str(rig),
		"fixture_sha256":FileAccess.get_sha256("res://tests/play_input011_authority_case.gd"),
		"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"panel_sha256":FileAccess.get_sha256("res://scripts/microscenario_panel.gd"),
		"display_server":DisplayServer.get_name(),"physics_engine":ProjectSettings.get_setting("physics/2d/physics_engine"),
		"assertions":assertions,"failures":failures,"row":row,
		"elapsed_usec":elapsed_usec,"teardown_usec":teardown_usec,
		"worker_joined":joined_workers == 1,"session_retired":retired_sessions == 1,
		"real_host":true,"automatic_callbacks":true,"manual_physics_calls":0,
		"window_focus_seam":true,"synthetic_window_notifications":true,
		"actual_gui_focus_signals":true,"cancellation_bypass_negative":true,
		"retries":0,"rendered_fps_measured":false,"physical_devices_qualified":false,
		"human_feel_qualified":false,"shader_startup_qualified":false}))
	quit(0 if row.completed and failures == 0 else 1)
