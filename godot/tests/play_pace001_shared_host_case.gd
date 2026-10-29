extends "res://tests/play_life001_shared_host_case.gd"

# PLAY-PACE-001 / #266/#270: source-bound shared-host pacing measurement.
# This is an actual main.tscn + CyberSimulationWorker + main-thread Rapier
# campaign. It reports callback/tick/snapshot distributions without asserting
# performance thresholds or claiming rendered desktop FPS, physical-device
# latency, native-job shutdown ordering, or human feel.
const SAMPLE_NATIVE_TICKS: int = 120
const MIN_PROCESS_SAMPLES: int = 30
const SAMPLE_TIMEOUT_MS: int = 30000


class PacingHarness:
	extends DesktopHarness

	var measurement_active: bool = false
	var process_intervals_ms: Array[float] = []
	var physics_intervals_ms: Array[float] = []
	var process_callback_ms: Array[float] = []
	var physics_callback_ms: Array[float] = []
	var snapshot_consume_callback_ms: Array[float] = []
	var snapshot_age_ms: Array[float] = []
	var render_snapshot_age_ms: Array[float] = []
	var worker_step_ms: Array[float] = []
	var snapshot_copy_ms: Array[float] = []
	var native_tick_deltas: Array[int] = []
	var snapshot_serial_deltas: Array[int] = []
	var render_serials: Array[int] = []
	var rapier_ticks: Array[int] = []
	var maximum_scheduler_jobs: int = 0
	var maximum_parallel_phases: int = 0
	var maximum_worker_overruns: int = 0
	var _last_process_usec: int = 0
	var _last_physics_usec: int = 0
	var _last_snapshot_serial: int = 0
	var _last_native_tick: int = 0
	var _last_render_serial: int = 0

	func begin_measurement() -> void:
		process_intervals_ms.clear()
		physics_intervals_ms.clear()
		process_callback_ms.clear()
		physics_callback_ms.clear()
		snapshot_consume_callback_ms.clear()
		snapshot_age_ms.clear()
		render_snapshot_age_ms.clear()
		worker_step_ms.clear()
		snapshot_copy_ms.clear()
		native_tick_deltas.clear()
		snapshot_serial_deltas.clear()
		render_serials.clear()
		rapier_ticks.clear()
		maximum_scheduler_jobs = 0
		maximum_parallel_phases = 0
		maximum_worker_overruns = 0
		_last_process_usec = Time.get_ticks_usec()
		_last_physics_usec = _last_process_usec
		_last_snapshot_serial = latest_snapshot.serial if latest_snapshot != null else 0
		_last_native_tick = latest_snapshot.tick_index if latest_snapshot != null else 0
		_last_render_serial = latest_snapshot.render_snapshot_serial if latest_snapshot != null else 0
		measurement_active = true

	func end_measurement() -> void:
		measurement_active = false

	func _process(delta: float) -> void:
		var entered_usec: int = Time.get_ticks_usec()
		if measurement_active and _last_process_usec > 0:
			process_intervals_ms.append(float(entered_usec - _last_process_usec) / 1000.0)
		_last_process_usec = entered_usec
		super._process(delta)
		var completed_usec: int = Time.get_ticks_usec()
		if measurement_active:
			process_callback_ms.append(float(completed_usec - entered_usec) / 1000.0)
			_sample_snapshot(completed_usec)

	func _physics_process(delta: float) -> void:
		var entered_usec: int = Time.get_ticks_usec()
		if measurement_active and _last_physics_usec > 0:
			physics_intervals_ms.append(float(entered_usec - _last_physics_usec) / 1000.0)
		_last_physics_usec = entered_usec
		super._physics_process(delta)
		var completed_usec: int = Time.get_ticks_usec()
		if measurement_active:
			physics_callback_ms.append(float(completed_usec - entered_usec) / 1000.0)
			if physical_actor_session != null and is_instance_valid(physical_actor_session):
				rapier_ticks.append(int(physical_actor_session.tick))

	func consume_worker_snapshot() -> void:
		var started_usec: int = Time.get_ticks_usec()
		super.consume_worker_snapshot()
		if measurement_active:
			snapshot_consume_callback_ms.append(
				float(Time.get_ticks_usec() - started_usec) / 1000.0
			)

	func _sample_snapshot(now_usec: int) -> void:
		if latest_snapshot == null or latest_snapshot.serial == _last_snapshot_serial:
			return
		snapshot_serial_deltas.append(int(latest_snapshot.serial - _last_snapshot_serial))
		native_tick_deltas.append(int(latest_snapshot.tick_index - _last_native_tick))
		_last_snapshot_serial = int(latest_snapshot.serial)
		_last_native_tick = int(latest_snapshot.tick_index)
		snapshot_age_ms.append(maxf(
			0.0, float(now_usec - latest_snapshot.published_usec) / 1000.0
		))
		if latest_snapshot.render_generated_usec > 0:
			render_snapshot_age_ms.append(maxf(
				0.0, float(now_usec - latest_snapshot.render_generated_usec) / 1000.0
			))
		worker_step_ms.append(float(latest_snapshot.worker_step_time_ms))
		snapshot_copy_ms.append(float(latest_snapshot.snapshot_copy_time_ms))
		maximum_scheduler_jobs = maxi(
			maximum_scheduler_jobs, int(latest_snapshot.scheduler_jobs_last_tick)
		)
		maximum_parallel_phases = maxi(
			maximum_parallel_phases,
			int(latest_snapshot.scheduler_parallel_phases_last_tick)
		)
		maximum_worker_overruns = maxi(
			maximum_worker_overruns, int(latest_snapshot.worker_overruns)
		)
		if latest_snapshot.render_snapshot_serial != _last_render_serial:
			_last_render_serial = int(latest_snapshot.render_snapshot_serial)
			render_serials.append(_last_render_serial)


func statistics(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {
			"count": 0, "mean": 0.0, "p50": 0.0,
			"p95": 0.0, "p99": 0.0, "max": 0.0
		}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {
		"count": values.size(),
		"mean": total / float(values.size()),
		"p50": ordered[clampi(ceili(values.size() * 0.50) - 1, 0, ordered.size() - 1)],
		"p95": ordered[clampi(ceili(values.size() * 0.95) - 1, 0, ordered.size() - 1)],
		"p99": ordered[clampi(ceili(values.size() * 0.99) - 1, 0, ordered.size() - 1)],
		"max": ordered[-1],
	}


func integer_statistics(values: Array[int]) -> Dictionary:
	var converted: Array[float] = []
	for value: int in values:
		converted.append(float(value))
	return statistics(converted)


func count_positive_skips(deltas: Array[int]) -> int:
	var skipped: int = 0
	for delta: int in deltas:
		skipped += maxi(0, delta - 1)
	return skipped


func controls_rearmed(desktop: Control, rig: StringName) -> bool:
	return actor_ready(desktop, rig) and not desktop._actor_input_rearm


func sample_complete(desktop: Control, initial_native_tick: int, initial_rapier_tick: int) -> bool:
	return (is_instance_valid(desktop) and desktop.latest_snapshot != null
		and desktop.physical_actor_session != null
		and int(desktop.latest_snapshot.tick_index) >= initial_native_tick + SAMPLE_NATIVE_TICKS
		and int(desktop.physical_actor_session.tick) >= initial_rapier_tick + SAMPLE_NATIVE_TICKS)


func run() -> void:
	var started_msec: int = Time.get_ticks_msec()
	var rig: StringName = target_rig()
	expect(rig in Course.MECHANICAL_PRESETS, "wrapper selects a supported SetP rig")
	if rig not in Course.MECHANICAL_PRESETS:
		quit(1)
		return

	release_controls()
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(PacingHarness)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	expect(desktop.worker_start_error == OK and worker._thread.is_started(),
		"existing asynchronous owner starts")
	var ready: bool = desktop.worker_start_error == OK and worker._thread.is_started()
	if ready:
		expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
			"authored course admits through its ordinary selector")
		ready = await wait_for(Callable(self, "course_installed").bind(desktop))
		expect(ready, "actual native course is acknowledged")
	if ready:
		expect(desktop.apply_actor_prototype_configuration(
			StringName("rapier/" + str(rig)), &"human", false),
			"ordinary F5 route constructs selected real SetP rig")
		ready = await wait_for(Callable(self, "actor_ready").bind(desktop, rig))
		expect(ready, "accepted actor, native epoch and terrain are ready")
	if not ready:
		await close_cycle(desktop, worker, desktop.physical_actor_session, str(rig) + ": ")
		quit(1)
		return

	desktop.paused = false
	release_controls()
	desktop.publish_actor_keyboard_input()
	var rearmed: bool = await wait_for(
		Callable(self, "controls_rearmed").bind(desktop, rig)
	)
	expect(rearmed, "neutral controls rearm the admitted human session")
	if not rearmed:
		await close_cycle(desktop, worker, desktop.physical_actor_session, str(rig) + ": ")
		quit(1)
		return

	var initial_snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
	var initial_native_tick: int = int(initial_snapshot.tick_index)
	var initial_rapier_tick: int = int(desktop.physical_actor_session.tick)
	var actor_epoch: int = int(desktop._physical_epoch)
	var world_generation: int = int(initial_snapshot.render_world_generation)
	var course_hash: String = str(
		desktop.microscenario_definition.get("source_recipe_hash", "")
	)
	var policy: Dictionary = initial_snapshot.lab_context.get(
		"liquid_solver_policy", {}
	).duplicate(true)
	var receipt: Dictionary = initial_snapshot.lab_context.get(
		"liquid_construction_receipt", {}
	).duplicate(true)

	desktop.begin_measurement()
	var measured_started_usec: int = Time.get_ticks_usec()
	parse_key(KEY_W, true)
	parse_key(KEY_D, true)
	var process_steps: int = 0
	var deadline_msec: int = Time.get_ticks_msec() + SAMPLE_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline_msec:
		if sample_complete(desktop, initial_native_tick, initial_rapier_tick):
			break
		if process_steps > 0 and process_steps % 30 == 0:
			parse_key(KEY_SPACE, true)
			parse_key(KEY_SPACE, false)
		if process_steps == 60:
			parse_key(KEY_D, false)
			parse_key(KEY_A, true)
		await process_frame
		process_steps += 1
	release_controls()
	desktop.publish_actor_keyboard_input()
	var measured_ended_usec: int = Time.get_ticks_usec()
	desktop.end_measurement()

	var final_snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
	var final_native_tick: int = int(final_snapshot.tick_index)
	var final_rapier_tick: int = int(desktop.physical_actor_session.tick)
	var elapsed_ms: float = maxf(
		0.001, float(measured_ended_usec - measured_started_usec) / 1000.0
	)
	var native_ticks: int = final_native_tick - initial_native_tick
	var rapier_ticks: int = final_rapier_tick - initial_rapier_tick
	var completed: bool = (
		native_ticks >= SAMPLE_NATIVE_TICKS and rapier_ticks >= SAMPLE_NATIVE_TICKS
	)
	expect(completed, "bounded sample completes requested native and Rapier ticks")
	expect(desktop.process_intervals_ms.size() >= MIN_PROCESS_SAMPLES
		and desktop.physics_intervals_ms.size() >= MIN_PROCESS_SAMPLES,
		"actual Main process and physics callbacks produce reportable samples")
	expect(not desktop.snapshot_age_ms.is_empty()
		and not desktop.worker_step_ms.is_empty()
		and not desktop.snapshot_consume_callback_ms.is_empty(),
		"copied snapshot age, worker-step and Main consume distributions are populated")
	expect(desktop._physical_epoch == actor_epoch
		and int(final_snapshot.render_world_generation) == world_generation
		and desktop.physical_rig_id == rig
		and desktop.microscenario_definition.get("id", "") == Catalogue.PLAYER_COURSE_ID,
		"measurement retains the selected actor, World and authored course identities")
	expect(final_snapshot.lab_context.get("liquid_solver_policy", {}) == policy
		and final_snapshot.lab_context.get("liquid_construction_receipt", {}) == receipt,
		"measurement retains the applied per-material policy and receipt")
	expect(not worker.has_failed(), "worker remains outside failure quarantine")

	var result: Dictionary = {
		"schema": "play-pace001-shared-host-v1",
		"rig": str(rig),
		"real_host": true,
		"host": "main.tscn+CyberSimulationWorker+main-thread-Rapier",
		"platform": OS.get_name(),
		"display_server": DisplayServer.get_name(),
		"headless": DisplayServer.get_name() == "headless",
		"godot": str(Engine.get_version_info().get("string", "")),
		"requested_workers": int(ProjectSettings.get_setting(
			"cybersand/native_worker_threads", 0
		)),
		"actual_worker_capacity": int(final_snapshot.scheduler_thread_capacity_hint),
		"backend": str(final_snapshot.backend_name),
		"course_id": Catalogue.PLAYER_COURSE_ID,
		"course_recipe_hash": course_hash,
		"actor_epoch": actor_epoch,
		"world_generation": world_generation,
		"liquid_policy_sha256": JSON.stringify(policy).sha256_text(),
		"liquid_receipt_sha256": JSON.stringify(receipt).sha256_text(),
		"sample_target_native_ticks": SAMPLE_NATIVE_TICKS,
		"completed_native_ticks": native_ticks,
		"completed_rapier_ticks": rapier_ticks,
		"elapsed_wall_ms": elapsed_ms,
		"completed_native_hz": float(native_ticks) * 1000.0 / elapsed_ms,
		"completed_rapier_hz": float(rapier_ticks) * 1000.0 / elapsed_ms,
		"process_steps": process_steps,
		"snapshot_publications": desktop.snapshot_age_ms.size(),
		"render_publications": desktop.render_serials.size(),
		"coalesced_native_ticks": count_positive_skips(desktop.native_tick_deltas),
		"maximum_scheduler_jobs": desktop.maximum_scheduler_jobs,
		"maximum_parallel_phases": desktop.maximum_parallel_phases,
		"maximum_worker_overruns": desktop.maximum_worker_overruns,
		"process_interval_ms": statistics(desktop.process_intervals_ms),
		"physics_interval_ms": statistics(desktop.physics_intervals_ms),
		"process_callback_ms": statistics(desktop.process_callback_ms),
		"physics_callback_ms": statistics(desktop.physics_callback_ms),
		"snapshot_consume_callback_ms": statistics(
			desktop.snapshot_consume_callback_ms
		),
		"snapshot_age_ms": statistics(desktop.snapshot_age_ms),
		"render_snapshot_age_ms": statistics(desktop.render_snapshot_age_ms),
		"worker_step_ms": statistics(desktop.worker_step_ms),
		"snapshot_copy_ms": statistics(desktop.snapshot_copy_ms),
		"native_tick_delta": integer_statistics(desktop.native_tick_deltas),
		"snapshot_serial_delta": integer_statistics(desktop.snapshot_serial_deltas),
		"raw": {
			"process_interval_ms": desktop.process_intervals_ms.duplicate(),
			"physics_interval_ms": desktop.physics_intervals_ms.duplicate(),
			"process_callback_ms": desktop.process_callback_ms.duplicate(),
			"physics_callback_ms": desktop.physics_callback_ms.duplicate(),
			"snapshot_consume_callback_ms":
				desktop.snapshot_consume_callback_ms.duplicate(),
			"snapshot_age_ms": desktop.snapshot_age_ms.duplicate(),
			"render_snapshot_age_ms": desktop.render_snapshot_age_ms.duplicate(),
			"worker_step_ms": desktop.worker_step_ms.duplicate(),
			"snapshot_copy_ms": desktop.snapshot_copy_ms.duplicate(),
			"native_tick_deltas": desktop.native_tick_deltas.duplicate(),
			"snapshot_serial_deltas": desktop.snapshot_serial_deltas.duplicate(),
			"rapier_ticks": desktop.rapier_ticks.duplicate(),
			"render_serials": desktop.render_serials.duplicate(),
		},
		"scope": {
			"rendered_fps_measured": false,
			"interactive_latency_measured": false,
			"physical_gamepad_qualified": false,
			"human_feel_qualified": false,
			"attributed_main_wait_measured": false,
			"native_busy_shutdown_qualified": false,
			"snapshot_consume_callback":
				"full Main consume callback, not isolated mutex wait",
		},
		"assertions": assertions,
		"failures": failures,
		"retries": 0,
	}

	var final_session: CyberPhysicalActorSession = desktop.physical_actor_session
	await close_cycle(desktop, worker, final_session, str(rig) + ": ")
	result["worker_joined"] = not worker._thread.is_started()
	result["rapier_session_retired"] = not is_instance_valid(final_session)
	result["assertions"] = assertions
	result["failures"] = failures
	result["total_elapsed_ms"] = Time.get_ticks_msec() - started_msec
	print("PLAY_PACE001_RESULT ", JSON.stringify(result))
	quit(0 if failures == 0 else 1)
