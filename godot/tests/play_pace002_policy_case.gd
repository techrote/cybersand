extends "res://tests/play_life002_solver_case.gd"

# PLAY-PACE-002: longer, positive-receipt gameplay windows after the accepted
# LIFE002 reconstruction/reset/refusal routes. No production owner is replaced.
# This helper deliberately depends only on accepted main, not PRs #296/#297.
const WINDOW_USEC: int = 10000000
const WINDOW_TIMEOUT_MS: int = 30000
var policy_windows: Array[Dictionary] = []


class PolicyPacingHarness:
	extends "res://scripts/main.gd"

	var pace2_sampling: bool = false
	var pace2_intervals_usec: Array[float] = []
	var pace2_callback_usec: Array[float] = []
	var pace2_snapshot_age_usec: Array[float] = []
	var pace2_render_age_usec: Array[float] = []
	var pace2_snapshot_serials: Array[int] = []
	var pace2_native_ticks: Array[int] = []
	var pace2_previous_callback_usec: int = 0
	var pace2_expected_epoch: int = 0
	var pace2_expected_generation: int = 0
	var pace2_expected_policy_hash: String = ""
	var pace2_expected_receipt_hash: String = ""
	var pace2_identity_drift: bool = false

	func actor_keyboard_allowed() -> bool:
		return (not paused and actor_prototypes_allowed() and _physical_terrain_ready
			and _actor_reset_receipt == 0 and not actor_prototype_panel.visible)

	func begin_window() -> void:
		pace2_intervals_usec.clear()
		pace2_callback_usec.clear()
		pace2_snapshot_age_usec.clear()
		pace2_render_age_usec.clear()
		pace2_snapshot_serials.clear()
		pace2_native_ticks.clear()
		pace2_previous_callback_usec = 0
		pace2_identity_drift = false
		pace2_expected_epoch = _physical_epoch
		pace2_expected_generation = int(latest_snapshot.render_world_generation)
		pace2_expected_policy_hash = str(tower_context.get(
			"liquid_solver_policy", {}).get("policy_hash", ""))
		pace2_expected_receipt_hash = str(tower_context.get(
			"liquid_construction_receipt", {}).get("receipt_hash", ""))
		pace2_sampling = true

	func _process(delta: float) -> void:
		var entered: int = Time.get_ticks_usec()
		if pace2_sampling and pace2_previous_callback_usec > 0:
			pace2_intervals_usec.append(float(entered - pace2_previous_callback_usec))
		pace2_previous_callback_usec = entered
		super._process(delta)
		var completed: int = Time.get_ticks_usec()
		if not pace2_sampling:
			return
		pace2_callback_usec.append(float(completed - entered))
		if latest_snapshot == null:
			pace2_identity_drift = true
			return
		pace2_snapshot_age_usec.append(float(completed - latest_snapshot.published_usec))
		pace2_render_age_usec.append(float(completed - latest_snapshot.render_generated_usec)
			if latest_snapshot.render_generated_usec > 0 else -1.0)
		pace2_snapshot_serials.append(int(latest_snapshot.serial))
		pace2_native_ticks.append(int(latest_snapshot.tick_index))
		var policy: Dictionary = latest_snapshot.lab_context.get("liquid_solver_policy", {})
		var receipt: Dictionary = latest_snapshot.lab_context.get("liquid_construction_receipt", {})
		pace2_identity_drift = pace2_identity_drift or _physical_epoch != pace2_expected_epoch \
			or int(latest_snapshot.render_world_generation) != pace2_expected_generation \
			or str(policy.get("policy_hash", "")) != pace2_expected_policy_hash \
			or str(receipt.get("receipt_hash", "")) != pace2_expected_receipt_hash


func summary(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"count":0, "mean":0.0, "p50":0.0, "p95":0.0, "p99":0.0, "max":0.0}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {"count":values.size(), "mean":total / float(values.size()),
		"p50":ordered[ceili(float(values.size()) * 0.50) - 1],
		"p95":ordered[ceili(float(values.size()) * 0.95) - 1],
		"p99":ordered[ceili(float(values.size()) * 0.99) - 1], "max":ordered[-1]}


func exercise_live_owner(context: String) -> bool:
	# LIFE002 calls this after construction, then again after reset and both
	# explicit refusals. Reuse those exact transactions; do not fake a receipt.
	var initial_failures: int = failures
	var initial_native: int = int(desktop.latest_snapshot.tick_index)
	var initial_rapier: int = int(desktop.physical_actor_session.tick)
	desktop.paused = false
	var advanced: bool = await wait_for(Callable(self, "clocks_advanced").bind(
		desktop, rig, initial_rapier, initial_native))
	expect(advanced, context + "actual clocks and neutral-input rearm are ready")
	if not advanced:
		return false

	var policy: Dictionary = policy_values().duplicate(true)
	var receipt: Dictionary = receipt_values().duplicate(true)
	var owner_ids: Dictionary = identities()
	var session = desktop.physical_actor_session
	var water: Dictionary = water_assignment(policy)
	var family: String = str(water.get("applied_family", ""))
	var policy_hash: String = str(policy.get("policy_hash", ""))
	var receipt_hash: String = str(receipt.get("receipt_hash", ""))
	var positive_receipt: bool = (not policy_hash.is_empty() and not receipt_hash.is_empty()
		and receipt.get("kind", "") == "applied_run"
		and receipt.get("run_intent", "") == "exploratory"
		and receipt.get("policy_hash", "") == policy_hash
		and not bool(receipt.get("eligible_for_full_matched_evidence", true))
		and family in ["pressure_flow_v1", "freemass_v1"]
		and water.get("requested_family", "") == family
		and water.get("applied_variant", "") == "reference")
	expect(positive_receipt, context + "nonempty native applied_run receipt binds selected Water policy")
	if not positive_receipt:
		desktop.paused = true
		return false

	# Retain the accepted quick-edge check before the longer measurement.
	parse_key(KEY_SPACE, true)
	parse_key(KEY_SPACE, false)
	var edges: Array = session._button_edges[0]
	expect(edges.size() == 2 and bool(edges[0].pressed) and not bool(edges[1].pressed),
		context + "ordinary input preserves both primary tap edges")
	var input_sequence_before: int = int(session.observation(0).last_sequence)
	var native_before: int = int(desktop.latest_snapshot.tick_index)
	var rapier_before: int = int(session.tick)
	var started: int = Time.get_ticks_usec()
	desktop.begin_window()
	var last_phase: int = -1
	var last_lift: bool = false
	var next_tap_tick: int = 60
	var input_tape: Array[Dictionary] = []
	var owner_lost: bool = false
	var deadline: int = Time.get_ticks_msec() + WINDOW_TIMEOUT_MS
	while Time.get_ticks_usec() - started < WINDOW_USEC \
			and Time.get_ticks_msec() < deadline:
		if not is_instance_valid(session) or desktop.physical_actor_session != session:
			owner_lost = true
			break
		var tick: int = int(session.tick) - rapier_before
		var phase: int = floori(float(tick) / 120.0)
		var lift: bool = tick % 120 < 30
		if phase != last_phase:
			parse_key(KEY_D, phase % 2 == 0)
			parse_key(KEY_A, phase % 2 != 0)
			input_tape.append({"kind":"direction", "rapier_tick":tick,
				"right":phase % 2 == 0, "elapsed_usec":Time.get_ticks_usec() - started})
			last_phase = phase
		if lift != last_lift:
			parse_key(KEY_W, lift)
			input_tape.append({"kind":"lift", "rapier_tick":tick, "pressed":lift})
			last_lift = lift
		if tick >= next_tap_tick:
			parse_key(KEY_SPACE, true)
			parse_key(KEY_SPACE, false)
			input_tape.append({"kind":"primary_tap", "rapier_tick":tick})
			next_tap_tick = (floori(float(tick) / 60.0) + 1) * 60
		await process_frame
	desktop.pace2_sampling = false
	var elapsed: int = Time.get_ticks_usec() - started
	var native_delta: int = int(desktop.latest_snapshot.tick_index) - native_before
	var rapier_delta: int = int(session.tick) - rapier_before if is_instance_valid(session) else 0
	var calls: int = desktop.pace2_callback_usec.size()
	expect(not owner_lost and elapsed >= WINDOW_USEC
		and elapsed < WINDOW_TIMEOUT_MS * 1000,
		context + "same actual owner completes the fixed ten-second window")
	expect(native_delta > 0 and rapier_delta > 0 and calls > 1,
		context + "both completed clocks and Main callbacks advance; no rate threshold")
	expect(desktop.pace2_intervals_usec.size() == calls - 1
		and desktop.pace2_snapshot_age_usec.size() == calls and desktop.pace2_render_age_usec.size() == calls
		and desktop.pace2_snapshot_serials.size() == calls and desktop.pace2_native_ticks.size() == calls,
		context + "raw arrays cover every callback and only complete inter-callback intervals")
	expect(not desktop.pace2_identity_drift and identities() == owner_ids
		and policy_values() == policy and receipt_values() == receipt,
		context + "World/actor and positive native policy/receipt identities remain fixed")
	expect(desktop.microscenario_definition.rectangles == recipe.rectangles
		and desktop.microscenario_definition.source_recipe_hash == recipe.source_recipe_hash,
		context + "authored course recipe is unchanged")
	expect(is_instance_valid(session)
		and int(session.observation(0).last_sequence) > input_sequence_before,
		context + "ordinary controller receives new commands during the sample")
	expect(not desktop.simulation_worker.has_failed(), context + "no native quarantine")
	var row: Dictionary = {"rig":str(rig), "context":context, "family":family,
		"stage":"post_construction" if policy_windows.size() % 2 == 0 else "post_reset_and_refusals",
		"requested_wall_usec":WINDOW_USEC, "elapsed_wall_usec":elapsed,
		"native_ticks":native_delta, "rapier_ticks":rapier_delta, "main_callbacks":calls,
		"native_hz":float(native_delta) * 1000000.0 / float(maxi(1, elapsed)),
		"rapier_hz":float(rapier_delta) * 1000000.0 / float(maxi(1, elapsed)),
		"owner_identity":owner_ids, "native_policy":policy, "construction_receipt":receipt,
		"course_recipe_hash":str(recipe.source_recipe_hash), "input_tape":input_tape,
		"assertion_failures_in_window":failures - initial_failures,
		"process_interval_usec":summary(desktop.pace2_intervals_usec),
		"process_callback_usec":summary(desktop.pace2_callback_usec),
		"retained_snapshot_age_usec":summary(desktop.pace2_snapshot_age_usec),
		"raw":{"process_interval_usec":desktop.pace2_intervals_usec.duplicate(),
			"process_callback_usec":desktop.pace2_callback_usec.duplicate(),
			"retained_snapshot_age_usec":desktop.pace2_snapshot_age_usec.duplicate(),
			"retained_render_age_usec":desktop.pace2_render_age_usec.duplicate(),
			"snapshot_serials":desktop.pace2_snapshot_serials.duplicate(),
			"native_ticks":desktop.pace2_native_ticks.duplicate()}}
	policy_windows.append(row)
	# Raw data is printed before teardown, retaining measured failure cases too.
	print("PLAY_PACE002_WINDOW ", JSON.stringify(row))
	release_controls()
	desktop.paused = true
	await physics_frame
	return failures == initial_failures


func run() -> void:
	rig = target_rig()
	var started: int = Time.get_ticks_msec()
	expect(rig in Course.MECHANICAL_PRESETS, "wrapper selects a supported mechanical rig")
	if rig not in Course.MECHANICAL_PRESETS:
		quit(1)
		return
	release_controls()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(PolicyPacingHarness)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var ready: bool = desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "exclusive existing worker starts")
	if ready:
		var launched: bool = desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0)
		expect(launched, "ordinary selector admits the authored course")
		ready = launched
		if ready:
			ready = await wait_for(Callable(self, "course_installed").bind(desktop))
		expect(ready, "worker acknowledges the authored course")
	if ready:
		recipe = desktop.microscenario_definition.duplicate(true)
		var admitted: bool = desktop.apply_actor_prototype_configuration(
			StringName("rapier/" + str(rig)), &"human", false)
		expect(admitted, "F5 admits the actual human SetP rig")
		ready = admitted
		if ready:
			ready = await wait_for(Callable(self, "actor_ready").bind(desktop, rig))
		expect(ready, "actor, epoch and terrain are acknowledged")
	if ready:
		ready = await reconstruct(2, "pressure_flow_v1")
	if ready:
		ready = await reconstruct(0, "freemass_v1")
	expect(ready and policy_windows.size() == 4 and accepted_rebuilds == 2
		and accepted_resets == 2 and controlled_refusals == 2 and native_refusals == 2,
		"both positive policies complete all four gameplay windows and retained refusal routes")
	var final_session = desktop.physical_actor_session
	await close_cycle(desktop, worker, final_session, str(rig) + ": ")
	print("PLAY_PACE002_RESULT ", JSON.stringify({"schema":"play-pace002-constructed-policy-v1",
		"rig":str(rig), "assertions":assertions, "failures":failures,
		"windows":policy_windows.size(), "requested_window_usec":WINDOW_USEC,
		"policy_reconstructions":accepted_rebuilds, "policy_retaining_resets":accepted_resets,
		"controlled_refusals":controlled_refusals, "native_refusals":native_refusals,
		"workers_joined":joined_workers, "rapier_sessions_retired":retired_sessions,
		"elapsed_ms":Time.get_ticks_msec() - started, "platform":OS.get_name(),
		"godot":Engine.get_version_info().string, "display_server":DisplayServer.get_name(),
		"helper_sha256":FileAccess.get_sha256("res://tests/play_pace002_policy_case.gd"),
		"inherited_life002_sha256":FileAccess.get_sha256("res://tests/play_life002_solver_case.gd"),
		"construction_rows":construction_rows,
		"scope":{"actual_shared_host":true, "positive_applied_receipts_required":true,
			"native_jobs_held":false, "busy_shutdown_qualified":false,
			"rendered_fps_measured":false, "physical_devices_qualified":false,
			"human_feel_qualified":false, "all_Main_waits_attributed":false}, "retries":0}))
	quit(0 if failures == 0 else 1)
