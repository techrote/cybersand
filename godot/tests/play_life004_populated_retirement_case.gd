extends "res://tests/play_life002_solver_case.gd"

# PLAY-LIFE-004 / #269: populate the actual Main course lap and pending human
# controls immediately before reconstruction and reset. Fixture-only placement
# translates the whole Rapier assembly; only a completed real step credits a
# gate. This does not inject slow native ticks or hold native phase jobs.
const PhysicalSession = preload("res://scripts/physical_actor_session.gd")
const Lap = preload("res://scripts/playable_course_lap.gd")
const DELTA: float = 1.0 / 60.0

var populated_rows: Array[Dictionary] = []
var stale_commands_rejected: int = 0


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_LIFE004: " + message)


func source_advanced(previous: int) -> bool:
	return actor_ready(desktop, rig) and int(desktop.latest_snapshot.tick_index) > previous


func move_actual_assembly(target: Vector2, context: String) -> bool:
	# Translate every actual body together, retaining the articulated joints.
	# Never submit a synthetic pose or call the lap model's bind/observe APIs.
	var session = desktop.physical_actor_session
	var position: Vector2 = session.observation(0).get("position", Vector2.INF)
	var shift: Vector2 = target - position
	var bodies: Array[RigidBody2D] = session.bodies()
	var valid: bool = bodies.size() >= 2 and position.is_finite() and shift.is_finite()
	expect(valid, context + "fixture translates a finite actual articulated Rapier assembly")
	if not valid:
		return false
	for index: int in range(bodies.size()):
		var pose: Transform2D = desktop.rapier_bridge.body_transform(index)
		desktop.rapier_bridge.reset_body(index, pose.origin + shift, pose.get_rotation())
	return true


func populate_live_state(context: String) -> Dictionary:
	release_controls()
	desktop.paused = false
	desktop.set_process(true)
	desktop.set_physics_process(true)
	var session = desktop.physical_actor_session
	var running: bool = await wait_for(Callable(self, "clocks_advanced").bind(
		desktop, rig, session.tick, int(desktop.latest_snapshot.tick_index)))
	expect(running, context + "actual native and Rapier clocks advance with neutral rearm")
	if not running:
		return {}
	# Explicit main-thread callbacks make the gate/queue boundary deterministic.
	# The exclusive native owner continues independently throughout this fixture.
	desktop.set_process(false)
	desktop.set_physics_process(false)
	var tracker = desktop._playable_course_progress
	expect(tracker.target_index == 0, context + "new lap has no checkpoint credit before the fixture visit")
	var accepted_before: int = session.accepted_commands
	parse_key(KEY_D, true)
	desktop._physics_process(DELTA)
	parse_key(KEY_D, false)
	desktop._physics_process(DELTA)
	expect(tracker.started and session.accepted_commands > accepted_before,
		context + "production admitted human movement starts the real host lap")
	var source_tick: int = int(desktop.latest_snapshot.tick_index)
	desktop.set_process(true)
	var source_ok: bool = await wait_for(Callable(self, "source_advanced").bind(source_tick))
	desktop.set_process(false)
	expect(source_ok and tracker.elapsed_ticks > 0,
		context + "a completed native publication populates elapsed lap ticks")
	if not source_ok:
		return {}
	var gate: Vector2 = Course.checkpoints(rig)[0]
	if not move_actual_assembly(gate, context):
		return {}
	var before_tick: int = session.tick
	var before_step: int = desktop.rapier_bridge.manual_step_count()
	desktop._update_playable_course_progress()
	expect(session.tick == before_tick and desktop.rapier_bridge.manual_step_count() == before_step
		and tracker.target_index == 0,
		context + "rendering a fixture placement without a completed step cannot credit a checkpoint")
	desktop._physics_process(DELTA)
	var entered: Vector2 = session.observation(0).get("position", Vector2.INF)
	expect(session.tick == before_tick + 1
		and desktop.rapier_bridge.manual_step_count() == before_step + 1
		and entered.is_finite() and entered.distance_to(gate) <= Lap.GATE_RADIUS,
		context + "an actual completed Rapier step visits the first authored checkpoint")
	expect(tracker.target_index == 1,
		context + "completed-step callback credits the gate before another HUD update")
	desktop._update_playable_course_progress()
	expect(tracker.started and tracker.target_index == 1 and tracker.elapsed_ticks > 0
		and desktop.course_timing_label.text.begins_with("GATES 1 / 4"),
		context + "actual host lap and visible HUD are populated before replacement")

	# Retain a typed packet that the OLD owner genuinely admitted. The later
	# rejection must reach its run/epoch fence, not fail schema or producer first.
	parse_key(KEY_D, true)
	var view: Dictionary = session.observation(0)
	var stale: Dictionary = PhysicalSession.make_command(view,
		int(view.last_sequence) + 1, {"move":Vector2.RIGHT})
	expect(session.submit(stale, &"human"), context + "old owner admits the retained typed human command")
	parse_key(KEY_SPACE, true)
	parse_key(KEY_SPACE, false)
	var edges: Array = session._button_edges[0].duplicate(true)
	var pending: Dictionary = session.observation(0)
	expect(edges.size() == 2 and str(edges[0].button) == "primary" and bool(edges[0].pressed)
		and str(edges[1].button) == "primary" and not bool(edges[1].pressed)
		and int(pending.pending_input_edges) == 2
		and not session._commands[0].is_empty() and Input.is_key_pressed(KEY_D),
		context + "real input queues an unconsumed ordered tap and held movement")
	return {"before":identities(),"session":session,"stale":stale,
		"pending_edges":edges,"lap_gates":tracker.target_index,"lap_elapsed":tracker.elapsed_ticks,
		"old_run_id":str(view.run_id),"snapshot":desktop.latest_snapshot,
		"snapshot_tick":int(desktop.latest_snapshot.tick_index),
		"snapshot_policy":desktop.latest_snapshot.lab_context.get("liquid_solver_policy", {}).duplicate(true),
		"snapshot_receipt":desktop.latest_snapshot.lab_context.get("liquid_construction_receipt", {}).duplicate(true)}


func verify_replacement(populated: Dictionary, requested: PackedInt32Array, context: String) -> bool:
	desktop.set_process(true)
	var installed: bool = await wait_for(Callable(self, "installed_after").bind(populated.before))
	expect(installed, context + "new native World/session and actor generations install")
	if not installed:
		return false
	expect(not is_instance_valid(populated.session), context + "populated old Rapier session is retired")
	verify_applied(requested, "pressure_flow_v1", context)
	var session = desktop.physical_actor_session
	var tracker = desktop._playable_course_progress
	expect(session._button_edges[0].is_empty() and session._commands[0].is_empty()
		and not tracker.started and tracker.target_index == 0 and tracker.elapsed_ticks == 0,
		context + "new owner has no prior command, pending tap, elapsed time or checkpoint credit")
	# Held D crosses installation. Unsuspend with a real main-thread step while
	# preserving the production release-to-rearm fence before attempting replay.
	desktop.paused = false
	var accepted_before: int = session.accepted_commands
	desktop._physics_process(DELTA)
	var before: Dictionary = session.observation(0)
	expect(not bool(before.suspended) and desktop._actor_input_rearm
		and Input.is_key_pressed(KEY_D) and session.accepted_commands == accepted_before
		and session._commands[0].is_empty() and session._button_edges[0].is_empty(),
		context + "held old movement cannot admit a command before neutral rearm")
	var rejected_before: int = session.rejected_commands
	var stale_accepted: bool = session.submit(populated.stale, &"human")
	var stale_refusal: String = session.last_error
	var after: Dictionary = session.observation(0)
	expect(not stale_accepted and stale_refusal == "run_or_epoch"
		and session.rejected_commands == rejected_before + 1
		and session.accepted_commands == accepted_before
		and int(after.last_sequence) == int(before.last_sequence)
		and int(after.control_generation) == int(before.control_generation)
		and session._commands[0].is_empty() and session._button_edges[0].is_empty(),
		context + "old typed packet reaches run/epoch refusal without changing new control state")
	if not stale_accepted and stale_refusal == "run_or_epoch":
		stale_commands_rejected += 1

	# Inject a retained REAL prior packet only into Main's copied presentation
	# slot. Its old epoch cannot start/advance the replacement lap. No mutable
	# World, worker adapter or synthetic model observation is used.
	var current_snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
	desktop.latest_snapshot = populated.snapshot
	desktop._update_playable_course_progress()
	expect(not desktop._playable_course_progress_identity()
		and not tracker.started and tracker.target_index == 0 and tracker.elapsed_ticks == 0,
		context + "retired actual snapshot cannot resurrect the populated old lap")
	desktop.latest_snapshot = current_snapshot
	desktop._update_playable_course_progress()
	expect(desktop._playable_course_progress_identity()
		and tracker.actor_epoch == desktop._physical_epoch and not tracker.started,
		context + "current copied snapshot rebinds only the fresh empty lap")

	release_controls()
	desktop.publish_actor_keyboard_input()
	expect(not desktop._actor_input_rearm, context + "full release neutrally rearms the new control lifetime")
	var fresh_before: int = session.accepted_commands
	parse_key(KEY_SPACE, true)
	parse_key(KEY_SPACE, false)
	var fresh_edges: Array = session._button_edges[0]
	expect(session.accepted_commands >= fresh_before + 2 and fresh_edges.size() == 2
		and bool(fresh_edges[0].pressed) and not bool(fresh_edges[1].pressed)
		and tracker.started,
		context + "fresh production tap is admitted in order and starts only the new lap")
	var retained: CyberSimulationSnapshot = populated.snapshot
	expect(retained.tick_index == int(populated.snapshot_tick)
		and retained.render_world_generation == int(populated.before.world_generation)
		and retained.lab_context.get("liquid_solver_policy", {}) == populated.snapshot_policy
		and retained.lab_context.get("liquid_construction_receipt", {}) == populated.snapshot_receipt,
		context + "old snapshot, policy and native receipt stay immutable")
	populated_rows.append({"operation":context,"before":populated.before,"after":identities(),
		"old_run_id":populated.old_run_id,"new_run_id":str(after.run_id),
		"old_pending_edges":populated.pending_edges,"old_lap_gates":populated.lap_gates,
		"old_lap_elapsed_ticks":populated.lap_elapsed,"stale_refusal":stale_refusal,
		"policy_hash":str(policy_values().policy_hash),
		"receipt_hash":str(receipt_values().get("receipt_hash", ""))})
	# Drain only through actual main-thread physics before the next independent
	# population arm; no test clears the production command or edge containers.
	if not move_actual_assembly(Vector2(275.0, 280.0), context + "fresh control drain: "):
		return false
	desktop._physics_process(DELTA)
	desktop._physics_process(DELTA)
	return true


func run() -> void:
	rig = target_rig()
	var started: int = Time.get_ticks_msec()
	expect(rig in Course.MECHANICAL_PRESETS, "wrapper selects a supported mechanical SetP rig")
	if rig not in Course.MECHANICAL_PRESETS:
		quit(1)
		return
	release_controls()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopHarness)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var ready: bool = desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "existing exclusive desktop owner starts")
	if ready:
		expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0), "actual authored course admits")
		ready = await wait_for(Callable(self, "course_installed").bind(desktop))
		expect(ready, "native worker acknowledges the actual course")
	if ready:
		recipe = desktop.microscenario_definition.duplicate(true)
		expect(desktop.apply_actor_prototype_configuration(
			StringName("rapier/" + str(rig)), &"human", false), "F5 admits the selected actual rig")
		ready = await wait_for(Callable(self, "actor_ready").bind(desktop, rig))
		expect(ready, "selected actor, native epoch and terrain are ready")
	var requested := PackedInt32Array()
	if ready:
		var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
		panel.session_picker.select(1)
		panel.select_preset(2)
		panel.refresh(desktop.tower_context)
		requested = panel.requested_policy.duplicate()
		expect(bool(panel._validation.get("accepted", false)) and not panel.apply_button.disabled,
			"supported pressure/reference reconstruction is admitted by the existing panel")
		var populated: Dictionary = await populate_live_state(str(rig) + " reconstruction: ")
		ready = not populated.is_empty()
		if ready:
			# No await separates the populated pending controls from this request.
			ready = panel.apply_active()
			expect(ready, "panel queues supported reconstruction while the old tap/lap are populated")
			if ready:
				ready = await verify_replacement(populated, requested, str(rig) + " reconstruction: ")
				if ready:
					accepted_rebuilds += 1
	if ready:
		# A fresh independent population precedes R/reset of the accepted policy.
		var populated: Dictionary = await populate_live_state(str(rig) + " reset: ")
		ready = not populated.is_empty()
		if ready:
			var accepted_hash: String = str(policy_values().policy_hash)
			desktop.microscenario_reset()
			expect(not desktop.pending_microscenario_apply.is_empty(),
				"R/reset queues retained policy while the old tap/lap are populated")
			ready = await verify_replacement(populated, requested, str(rig) + " reset: ")
			expect(str(policy_values().policy_hash) == accepted_hash, "R/reset retains the accepted policy hash")
			if ready:
				accepted_resets += 1
	expect(ready and accepted_rebuilds == 1 and accepted_resets == 1 and stale_commands_rejected == 2,
		"both independently populated transactions and old-command refusals complete")
	expect(not worker.has_failed(), "exclusive native owner stays outside failure quarantine")
	await close_cycle(desktop, worker, desktop.physical_actor_session, str(rig) + ": ")
	print("PLAY_LIFE004_RESULT ", JSON.stringify({
		"rig":str(rig),"real_host":true,"host":"main.tscn+CyberSimulationWorker+main-thread-Rapier",
		"assertions":assertions,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started,
		"populated_policy_reconstructions":accepted_rebuilds,"populated_policy_retaining_resets":accepted_resets,
		"stale_commands_rejected":stale_commands_rejected,"workers_joined":joined_workers,
		"rapier_sessions_retired":retired_sessions,"populated_rows":populated_rows,
		"test_only_rapier_assembly_placement":true,"retained_actual_snapshot_injection":true,
		"retries":0,"slow_native_injection":false,"native_phase_jobs_held":false,
		"rendered_fps_measured":false,"physical_gamepad_qualified":false}))
	quit(0 if failures == 0 else 1)
