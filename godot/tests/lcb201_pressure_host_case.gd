extends "res://tests/play_pace001_shared_host_case.gd"

# LCB-002 #201 full-host cohort. The merged PACE-001 shared-host recorder (actual
# main.tscn + CyberSimulationWorker + main-thread Rapier) is reused unchanged.
# Instead of the player course, this case installs the #370 deep quiet pool
# through the ordinary controlled prepared-liquid route under one Water variant:
#   -- --variant reference|cached|cached_dormant|freemass [--settle N] [--measure N]
# It reports the same worker-step, cadence and snapshot-age distributions. It is
# not discovered as a CI regression (no test_ prefix) and asserts no threshold.
const Contract = preload("res://scripts/microscenario_contract.gd")
const POOL_FIXTURE: String = "res://tests/fixtures/lcb/scenarios/lcb.rest.deep-quiet-pool.v1.json"
const POOL_ID: String = "lcb.rest.deep-quiet-pool.v1"
const POOL_WATER: int = 38515200
var variant: String = "cached"
var settle_ticks: int = 64
var measure_ticks: int = 240


func _arguments() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		var key: String = args[index]
		if index + 1 >= args.size(): return false
		var value: String = args[index + 1]
		match key:
			"--variant": variant = value
			"--settle": settle_ticks = int(value)
			"--measure": measure_ticks = int(value)
			_: return false
		index += 2
	return variant in ["reference", "cached", "cached_dormant", "freemass"] \
		and settle_ticks >= 0 and measure_ticks >= 30


func _request(bridge: Variant) -> PackedInt32Array:
	var request: PackedInt32Array = bridge.default_liquid_policy()
	var family: String = "freemass_v1" if variant == "freemass" else "pressure_flow_v1"
	var wanted: String = "reference" if variant == "freemass" else variant
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(request, 3):
		if str(choice.get("family", "")) == family and str(choice.get("variant", "")) == wanted:
			return choice.request
	return PackedInt32Array()


func pool_installed(desktop: Control) -> bool:
	if not is_instance_valid(desktop) or desktop.latest_snapshot == null: return false
	if not desktop.pending_microscenario_apply.is_empty(): return false
	if desktop.microscenario_definition.get("id", "") != POOL_ID: return false
	var policy: Dictionary = desktop.latest_snapshot.lab_context.get("liquid_solver_policy", {})
	return not policy.is_empty()


func native_reached(desktop: Control, target: int) -> bool:
	return is_instance_valid(desktop) and desktop.latest_snapshot != null \
		and int(desktop.latest_snapshot.tick_index) >= target


func run() -> void:
	var started_msec: int = Time.get_ticks_msec()
	expect(_arguments(), "registered variant/settle/measure arguments")
	var text: String = FileAccess.get_file_as_string(POOL_FIXTURE)
	var checked: Dictionary = Contract.parse(text)
	expect(checked.get("ok", false) and checked.definition.id == POOL_ID, "registered quiet-pool fixture parses")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var request: PackedInt32Array = _request(bridge)
	expect(not request.is_empty(), "native catalogue offers the requested Water variant")
	if failures > 0:
		quit(1)
		return

	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(PacingHarness)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var ready: bool = desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready, "existing asynchronous owner starts")
	if ready:
		expect(desktop.microscenario_apply_controlled_liquid(checked.definition, request, true, "Benchmark", 2),
			"ordinary controlled prepared-liquid route admits the quiet pool")
		ready = await wait_for(Callable(self, "pool_installed").bind(desktop))
		expect(ready, "actual native quiet pool is acknowledged")
	if not ready:
		await close_cycle(desktop, worker, null, "lcb201: ")
		quit(1)
		return
	desktop.paused = false
	var installed_tick: int = int(desktop.latest_snapshot.tick_index)
	expect(await wait_for(Callable(self, "native_reached").bind(desktop, installed_tick + settle_ticks)),
		"registered settle ticks complete")
	var policy: Dictionary = desktop.latest_snapshot.lab_context.get("liquid_solver_policy", {}).duplicate(true)
	var initial_native_tick: int = int(desktop.latest_snapshot.tick_index)

	desktop.begin_measurement()
	var measured_started_usec: int = Time.get_ticks_usec()
	var completed: bool = await wait_for(
		Callable(self, "native_reached").bind(desktop, initial_native_tick + measure_ticks), SAMPLE_TIMEOUT_MS)
	var measured_ended_usec: int = Time.get_ticks_usec()
	desktop.end_measurement()
	expect(completed, "bounded sample completes the requested native ticks")
	var final_snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
	var native_ticks: int = int(final_snapshot.tick_index) - initial_native_tick
	var elapsed_ms: float = maxf(0.001, float(measured_ended_usec - measured_started_usec) / 1000.0)
	expect(desktop.process_intervals_ms.size() >= MIN_PROCESS_SAMPLES and not desktop.worker_step_ms.is_empty(),
		"actual Main callbacks and worker steps produce reportable samples")
	expect(final_snapshot.lab_context.get("liquid_solver_policy", {}) == policy,
		"measurement retains the applied Water policy")
	expect(not worker.has_failed(), "worker remains outside failure quarantine")

	var result: Dictionary = {
		"schema": "lcb201-pressure-host-v1",
		"variant": variant,
		"fixture": POOL_ID,
		"real_host": true,
		"host": "main.tscn+CyberSimulationWorker+main-thread-Rapier",
		"platform": OS.get_name(),
		"display_server": DisplayServer.get_name(),
		"headless": DisplayServer.get_name() == "headless",
		"godot": str(Engine.get_version_info().get("string", "")),
		"requested_workers": int(ProjectSettings.get_setting("cybersand/native_worker_threads", 0)),
		"actual_worker_capacity": int(final_snapshot.scheduler_thread_capacity_hint),
		"backend": str(final_snapshot.backend_name),
		"liquid_policy_native_hash": str(policy.get("policy_hash", "")),
		"liquid_policy_assignments": policy.get("assignments", []),
		"settle_ticks": settle_ticks,
		"sample_target_native_ticks": measure_ticks,
		"completed_native_ticks": native_ticks,
		"elapsed_wall_ms": elapsed_ms,
		"completed_native_hz": float(native_ticks) * 1000.0 / elapsed_ms,
		"snapshot_publications": desktop.snapshot_serial_deltas.size(),
		"coalesced_native_ticks": count_positive_skips(desktop.native_tick_deltas),
		"maximum_scheduler_jobs": desktop.maximum_scheduler_jobs,
		"maximum_worker_overruns": desktop.maximum_worker_overruns,
		"worker_step_ms": statistics(desktop.worker_step_ms),
		"process_interval_ms": statistics(desktop.process_intervals_ms),
		"physics_interval_ms": statistics(desktop.physics_intervals_ms),
		"process_callback_ms": statistics(desktop.process_callback_ms),
		"snapshot_consume_callback_ms": statistics(desktop.snapshot_consume_callback_ms),
		"snapshot_age_ms": statistics(desktop.snapshot_age_ms),
		"retained_snapshot_age_ms": statistics(desktop.retained_snapshot_age_ms),
		"snapshot_copy_ms": statistics(desktop.snapshot_copy_ms),
		"native_tick_delta": integer_statistics(desktop.native_tick_deltas),
		"scope": {
			"rendered_fps_measured": false,
			"moving_body": false,
			"worker_step_ms": "CyberSimulationSnapshot.worker_step_time_ms of first-observed publications",
			"note": "Native-tick cost in the real owner; physical displayed FPS is not measured headless",
		},
		"assertions": assertions,
		"failures": failures,
		"retries": 0,
	}
	await close_cycle(desktop, worker, null, "lcb201: ")
	result["worker_joined"] = not worker._thread.is_started()
	result["assertions"] = assertions
	result["failures"] = failures
	result["total_elapsed_ms"] = Time.get_ticks_msec() - started_msec
	print("LCB201_PRESSURE_HOST_RESULT ", JSON.stringify(result))
	quit(0 if failures == 0 else 1)
