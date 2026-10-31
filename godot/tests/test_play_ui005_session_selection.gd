extends "res://tests/play_life001_shared_host_case.gd"

# Actual Main, existing worker/native construction and main-thread Rapier.
# Only OS focus and the connected-device enumeration are synthetic. No
# physical controller, framebuffer pacing or human playability claim follows.
const LiquidEditor = preload("res://scripts/liquid_comparison_panel.gd")
var desktop: Control
var accepted_sessions: int = 0
var native_refusals: int = 0
var rows: Array[Dictionary] = []


class FocusHarness:
	extends "res://scripts/main.gd"
	var test_window_focus: bool = true
	func _actor_window_has_focus() -> bool:
		return test_window_focus


class DeviceHarness:
	extends "res://scripts/playable_course_gamepad_events.gd"
	var test_selected: int = 31
	func _selected_joypad() -> int:
		return test_selected


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_UI005: " + message)


func request_finished() -> bool:
	return desktop.pending_microscenario_apply.is_empty()


func live_again(rig: StringName, tick: int, native_tick: int) -> bool:
	return clocks_advanced(desktop, rig, tick, native_tick)


func new_actor(rig: StringName, epoch: int) -> bool:
	return actor_ready(desktop, rig) and desktop._physical_epoch > epoch


func input_cancelled() -> bool:
	return desktop._actor_input_rearm and desktop.physical_actor_session._button_edges[0].is_empty()


func exercise_selection(index: int, worker: CyberSimulationWorker) -> bool:
	var rig: StringName = Course.MECHANICAL_PRESETS[index]
	var panel = desktop.playable_session_panel
	panel.show_selection()
	panel.actor_choice.select(index)
	panel.control_choice.select(index % 2)
	panel.rule_choice.select(index % 2)
	panel.camera_choice.select(index % 2)
	panel.policy_editor.select_preset(2 if index % 2 == 0 else 0)
	var selection: Dictionary = panel.selection()
	var previous_options: Dictionary = desktop.playable_session_options.duplicate(true)
	var previous_epoch: int = desktop._physical_epoch
	var previous_session = desktop.physical_actor_session
	var previous_serial: int = desktop._microscenario_request_serial
	var request: PackedInt32Array = panel.policy_editor.requested_policy.duplicate()
	expect(panel.build_selected(), str(rig) + ": integrated UI queues one composed request")
	expect(desktop._microscenario_request_serial == previous_serial + 1
		and desktop.playable_session_options == previous_options
		and desktop.physical_actor_session == previous_session,
		str(rig) + ": pending choice cannot relabel the old applied options/owner")
	if not await wait_for(Callable(self, "new_actor").bind(rig, previous_epoch), Watchdogs.milliseconds("main_ack_seconds")):
		expect(false, str(rig) + ": actual composed actor/World installation deadline")
		return false
	accepted_sessions += 1
	var context: Dictionary = desktop.tower_context
	var applied: Dictionary = context.get("liquid_solver_policy", {})
	var receipt: Dictionary = context.get("liquid_construction_receipt", {})
	var recipe: Dictionary = Catalogue.definition(Catalogue.PLAYER_COURSE_ID, 0)
	expect(desktop.simulation_worker == worker and worker._thread.is_started(),
		str(rig) + ": the same exclusive asynchronous worker owns every reconstruction")
	expect(previous_session == null or not is_instance_valid(previous_session),
		str(rig) + ": prior actual Rapier owner retires after acceptance")
	expect(desktop.microscenario_definition.rectangles == recipe.rectangles
		and desktop.microscenario_definition.source_recipe_hash == recipe.source_recipe_hash,
		str(rig) + ": original authored course and recipe identity remain exact")
	expect(applied.get("envelope", PackedInt32Array()) == request
		and receipt.get("kind", "") == "applied_run"
		and receipt.get("policy_hash", "") == applied.get("policy_hash", "missing"),
		str(rig) + ": requested envelope is matched by actual native applied receipt")
	expect(desktop.playable_session_options == {"controls":selection.controls,
		"rules":selection.rules, "camera":selection.camera}
		and desktop.paused and desktop.actor_producer_selection == &"human",
		str(rig) + ": acknowledged configuration is applied paused with human control")
	expect(desktop.camera_follow_enabled == (index % 2 == 0)
		and desktop.current_view_size == (Vector2i(256, 128) if index % 2 == 0 else Course.VIEW.size),
		str(rig) + ": selected initial camera is applied at the same transaction")
	panel.refresh()
	expect(panel.applied_label.text.contains(str(rig)) and panel.policy_label.text.contains("Applied")
		and not panel.policy_label.text.contains("unavailable"),
		str(rig) + ": integrated surface reads actual applied state and native variant")
	# The headless display reports a 1x1 usable popup area. Only a real
	# display can qualify window bounds; do not count a skipped check as pass.
	if DisplayServer.get_name() != "headless":
		expect(panel.size.y <= mini(740, root.size.y - 32)
			and panel.build_button.get_global_rect().end.y <= panel.size.y,
			str(rig) + ": wrapped labels cannot expand the popup or hide its action bar")
	expect(not desktop.actor_keyboard_allowed(), str(rig) + ": visible selector owns input")
	var tick: int = desktop.physical_actor_session.tick
	var native_tick: int = desktop.latest_snapshot.tick_index
	panel.resume_play()
	if not await wait_for(Callable(self, "live_again").bind(rig, tick, native_tick)):
		expect(false, str(rig) + ": original native/Rapier clocks must resume after neutral rearm")
		return false
	parse_key(KEY_W if rig != &"acrobat" else KEY_D, true)
	var target_tick: int = desktop.physical_actor_session.tick + 6
	var progressed: bool = await wait_for(func() -> bool: return desktop.physical_actor_session.tick >= target_tick)
	parse_key(KEY_W if rig != &"acrobat" else KEY_D, false)
	expect(progressed, str(rig) + ": real physical steps continue with admitted movement")
	expect(desktop._playable_course_progress.started == (index % 2 == 0),
		str(rig) + ": admitted human input obeys selected lap/free-play rule")
	if index % 2 == 1:
		expect(not desktop.course_timing_label.visible, str(rig) + ": free play hides the lap HUD")
	# Reset must retain the accepted composition, rather than the panel's
	# next unsubmitted selection or legacy default camera/rules.
	previous_epoch = desktop._physical_epoch
	panel.rule_choice.select(1 - index % 2)
	desktop.microscenario_reset()
	if not await wait_for(Callable(self, "new_actor").bind(rig, previous_epoch)):
		expect(false, str(rig) + ": reset retains actual course/actor")
		return false
	expect(desktop.playable_session_options.rules == selection.rules
		and desktop.playable_session_options.controls == selection.controls
		and desktop.camera_follow_enabled == (index % 2 == 0)
		and desktop.tower_context.liquid_solver_policy.envelope == request,
		str(rig) + ": reset retains accepted options and policy, ignoring pending UI edits")
	rows.append({"rig":str(rig), "selection":selection, "actor_epoch":desktop._physical_epoch,
		"world_generation":desktop.latest_snapshot.render_world_generation,
		"policy_hash":str(applied.policy_hash), "receipt_hash":str(receipt.receipt_hash)})
	return true


func exercise_focus_and_devices() -> bool:
	var panel = desktop.playable_session_panel
	panel.resume_play()
	var rig: StringName = desktop.physical_rig_id
	if not await wait_for(Callable(self, "live_again").bind(rig,
		desktop.physical_actor_session.tick, desktop.latest_snapshot.tick_index)):
		expect(false, "device checks require resumed native and Rapier clocks")
		return false
	parse_key(KEY_SPACE, true)
	parse_key(KEY_SPACE, false)
	expect(desktop.physical_actor_session._button_edges[0].size() == 2,
		"real human input has populated pending edges before disconnect")
	parse_key(KEY_W, true)
	var bridge = desktop.get_node("CourseGamepadEvents")
	bridge.test_selected = -1
	Input.joy_connection_changed.emit(31, false)
	expect(input_cancelled(), "selected-device loss immediately revokes old edges and requests rearm")
	desktop.publish_actor_keyboard_input()
	expect(desktop._actor_input_rearm and desktop.physical_actor_session._button_edges[0].is_empty(),
		"held keyboard cannot automatically take over disconnected gamepad authority")
	parse_key(KEY_W, false)
	desktop.publish_actor_keyboard_input()
	expect(not desktop._actor_input_rearm, "neutral keyboard allows fresh input after disconnect")
	bridge.test_selected = 30
	Input.joy_connection_changed.emit(30, true)
	expect(input_cancelled(), "a new first gamepad also requires neutral rearm")
	desktop.publish_actor_keyboard_input()
	parse_key(KEY_SPACE, true)
	parse_key(KEY_SPACE, false)
	Input.joy_connection_changed.emit(31, true)
	expect(not desktop._actor_input_rearm and desktop.physical_actor_session._button_edges[0].size() == 2,
		"connecting an unselected secondary pad does not cancel the active controller")
	desktop.test_window_focus = false
	desktop.publish_actor_keyboard_input()
	expect(input_cancelled(), "actual Main focus predicate cancels queued actions")
	parse_key(KEY_W, true)
	desktop.test_window_focus = true
	desktop.publish_actor_keyboard_input()
	expect(desktop._actor_input_rearm, "regaining focus cannot rearm a held control")
	parse_key(KEY_W, false)
	desktop.publish_actor_keyboard_input()
	expect(not desktop._actor_input_rearm, "neutral release permits rearm after focus regain")
	return true


func exercise_refusals() -> bool:
	var panel = desktop.playable_session_panel
	panel.show_selection()
	var prior_options: Dictionary = desktop.playable_session_options.duplicate(true)
	var prior_policy: Dictionary = desktop.tower_context.liquid_solver_policy.duplicate(true)
	var prior_receipt: Dictionary = desktop.tower_context.liquid_construction_receipt.duplicate(true)
	var old_session = desktop.physical_actor_session
	var old_generation: int = desktop.latest_snapshot.render_world_generation
	var bad: PackedInt32Array = prior_policy.envelope.duplicate()
	# Same registered negative as LIFE002: Oil has no pressure-flow admission.
	bad[20 + 3 * 3 + 1] = 3
	bad[20 + 3 * 3 + 2] = 1
	panel.actor_choice.select(0)
	panel.rule_choice.select(1)
	panel.camera_choice.select(1)
	expect(desktop.apply_playable_session(panel.selection(), bad),
		"unsupported native material/family reaches the original transactional refusal")
	var candidate = desktop._pending_physical_candidate
	var candidate_session = candidate.session if candidate != null else null
	if not await wait_for(Callable(self, "request_finished")):
		expect(false, "native refusal must finish within the existing deadline")
		return false
	native_refusals += 1
	expect(desktop.microscenario_error.contains("combination_rejected")
		and desktop.physical_actor_session == old_session and not is_instance_valid(candidate_session)
		and desktop.latest_snapshot.render_world_generation == old_generation,
		"actual native refusal retires candidate and preserves accepted World/actor")
	expect(desktop.playable_session_options == prior_options
		and desktop.tower_context.liquid_solver_policy == prior_policy
		and desktop.tower_context.liquid_construction_receipt == prior_receipt,
		"refused actor/rules/camera/policy cannot become Applied")
	panel.refresh()
	expect(panel.status_label.text.begins_with("Refused:") and panel.applied_label.text.contains("jetbarrel"),
		"UI shows refusal alongside truthful retained applied actor")
	var unsupported: Dictionary = panel.selection()
	unsupported.actor = "dryswarm"
	var serial: int = desktop._microscenario_request_serial
	expect(not desktop.apply_playable_session(unsupported, prior_policy.envelope)
		and desktop._microscenario_request_serial == serial and desktop.physical_actor_session == old_session,
		"deferred swarm refuses before any owner transaction")
	panel.hide()
	var protected_definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LiquidEditor.DAM_PATH))
	expect(desktop.microscenario_apply_definition(protected_definition, "Inspect"), "original protected Dam Break loads normally")
	if not await wait_for(Callable(self, "request_finished")): return false
	serial = desktop._microscenario_request_serial
	expect(not desktop.apply_playable_session(panel.selection(), prior_policy.envelope)
		and desktop.microscenario_error.contains("protected experiment")
		and desktop._microscenario_request_serial == serial,
		"playable selector cannot reconfigure a protected specialist fixture")
	return true


func run() -> void:
	release_controls()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(FocusHarness)
	desktop.get_node("CourseGamepadEvents").set_script(DeviceHarness)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var ready: bool = desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "actual existing desktop worker starts")
	var launcher: Button = desktop.microscenario_panel.launch_button.get_parent().get_node("PlayableSessionLauncher")
	expect(root.get_visible_rect().encloses(launcher.get_global_rect()),
		"shared Play launcher remains inside the actual host viewport")
	for pressed: bool in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = launcher.get_global_rect().get_center()
		mouse.global_position = mouse.position
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		root.push_input(mouse, true)
		await process_frame
	expect(desktop.playable_session_panel.visible,
		"real viewport mouse entry opens the integrated selector")
	desktop.playable_session_panel.hide()
	for index: int in Course.MECHANICAL_PRESETS.size():
		if not ready: break
		ready = await exercise_selection(index, worker)
	if ready: ready = await exercise_focus_and_devices()
	if ready: ready = await exercise_refusals()
	expect(ready and accepted_sessions == 5 and native_refusals == 1,
		"all five composed real sessions plus actual refusal complete")
	var final_session = desktop.physical_actor_session
	await close_cycle(desktop, worker, final_session, "UI005: ")
	print("PLAY_UI005_RESULT ", JSON.stringify({"assertions":assertions, "failures":failures,
		"accepted_sessions":accepted_sessions, "policy_retaining_resets":accepted_sessions,
		"native_refusals":native_refusals, "rows":rows, "retries":0,
		"real_host":"main.tscn+CyberSimulationWorker+main-thread-Rapier",
		"synthetic_focus_and_device_enumeration":true, "physical_gamepad_qualified":false,
		"window_layout_checked":DisplayServer.get_name() != "headless",
		"rendered_pacing_measured":false, "human_feel_qualified":false}))
	quit(0 if failures == 0 else 1)
