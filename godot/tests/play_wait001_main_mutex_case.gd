extends "res://tests/play_life001_shared_host_case.gd"

# PLAY-WAIT-001 / #268, #270: measure the isolated snapshot-handoff mutex
# acquisition in the actual Main.tscn + existing worker + Main-thread Rapier
# host, without changing production source, native code or solver defaults.
# A test-only worker subclass copies the exact existing take_latest_snapshot
# critical section and inserts monotonic clock reads. No slow-native barrier,
# overlapping native phase-claim observation or interactive FPS is implied.
const SnapshotProbe = preload("res://tests/play_wait001_snapshot_probe.gd")
const SAMPLE_NATIVE_TICKS: int = 120
var SAMPLE_TIMEOUT_MS: int = Watchdogs.milliseconds("operation_seconds")
const MIN_MAIN_SAMPLES: int = 30


class WaitHarness:
	extends "res://scripts/main.gd"
	const Probe = preload("res://tests/play_wait001_snapshot_probe.gd")

	var test_input_allowed: bool = true
	var sampling: bool = false
	var main_callback_usec: Array[float] = []
	var main_interval_usec: Array[float] = []
	var previous_process_usec: int = 0

	func _ready() -> void:
		# Replace only the unstarted, default-created owner before Main._ready()
		# starts any worker. Do not splice into a live worker or replace Rapier.
		simulation_worker = Probe.new()
		super._ready()

	func actor_keyboard_allowed() -> bool:
		return (test_input_allowed and not paused and actor_prototypes_allowed()
			and _physical_terrain_ready and _actor_reset_receipt == 0
			and not actor_prototype_panel.visible)

	func begin_sample() -> void:
		main_callback_usec.clear()
		main_interval_usec.clear()
		# First measured callback has no predecessor inside the sample window.
		# Do not report begin_sample-to-first-callback as an inter-callback interval.
		previous_process_usec = 0
		var probe: Probe = simulation_worker as Probe
		probe.begin_sample()
		sampling = true

	func end_sample() -> void:
		sampling = false
		var probe: Probe = simulation_worker as Probe
		probe.end_sample()

	func _process(delta: float) -> void:
		var entered_usec: int = Time.get_ticks_usec()
		if sampling and previous_process_usec > 0:
			main_interval_usec.append(float(entered_usec - previous_process_usec))
		previous_process_usec = entered_usec
		super._process(delta)
		if sampling:
			main_callback_usec.append(float(Time.get_ticks_usec() - entered_usec))


func controls_rearmed(desktop: Control, rig: StringName) -> bool:
	return actor_ready(desktop, rig) and not desktop._actor_input_rearm


func summarize(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"count":0,"mean":0.0,"p50":0.0,"p95":0.0,"p99":0.0,"max":0.0}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {
		"count":values.size(),
		"mean":total / float(values.size()),
		"p50":ordered[clampi(ceili(float(ordered.size()) * 0.50)-1, 0, ordered.size()-1)],
		"p95":ordered[clampi(ceili(float(ordered.size()) * 0.95)-1, 0, ordered.size()-1)],
		"p99":ordered[clampi(ceili(float(ordered.size()) * 0.99)-1, 0, ordered.size()-1)],
		"max":ordered[-1]
	}


func run() -> void:
	var started_msec: int = Time.get_ticks_msec()
	var rig: StringName = target_rig()
	expect(rig in Course.MECHANICAL_PRESETS,
		"wrapper selects an accepted mechanical SetP actor")
	if rig not in Course.MECHANICAL_PRESETS:
		quit(1)
		return
	release_controls()
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(WaitHarness)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var probe: SnapshotProbe = worker as SnapshotProbe
	var ready: bool = desktop.worker_start_error == OK and worker._thread.is_started()
	expect(ready and probe != null, "actual Main starts test-instrumented existing worker")
	if ready:
		expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
			"normal selector admits the authored Player Playground course")
		ready = await wait_for(Callable(self, "course_installed").bind(desktop))
		expect(ready, "actual native course installation acknowledged")
	if ready:
		expect(desktop.apply_actor_prototype_configuration(
			StringName("rapier/" + str(rig)), &"human", false),
			"normal F5 route constructs the real selected SetP actor")
		ready = await wait_for(Callable(self, "actor_ready").bind(desktop, rig))
		expect(ready, "actor and main-thread Rapier are ready")
	if not ready:
		await close_cycle(desktop, worker, desktop.physical_actor_session,
			str(rig) + ": failed setup: ")
		quit(1)
		return

	desktop.paused = false
	release_controls()
	desktop.publish_actor_keyboard_input()
	var rearmed: bool = await wait_for(
		Callable(self, "controls_rearmed").bind(desktop, rig))
	expect(rearmed, "neutral controls rearm the admitted human actor")
	if not rearmed:
		await close_cycle(desktop, worker, desktop.physical_actor_session,
			str(rig) + ": no rearm: ")
		quit(1)
		return

	var initial_native_tick: int = int(desktop.latest_snapshot.tick_index)
	var initial_rapier_tick: int = int(desktop.physical_actor_session.tick)
	var initial_epoch: int = int(desktop._physical_epoch)
	var initial_world_generation: int = int(desktop.latest_snapshot.render_world_generation)
	var course_recipe_sha: String = str(
		desktop.microscenario_definition.get("source_recipe_hash", ""))
	desktop.begin_sample()
	var measured_started_usec: int = Time.get_ticks_usec()
	parse_key(KEY_W, true)
	parse_key(KEY_D, true)
	var frames: int = 0
	var deadline_msec: int = Time.get_ticks_msec() + SAMPLE_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline_msec:
		if desktop.latest_snapshot != null and desktop.physical_actor_session != null:
			if int(desktop.latest_snapshot.tick_index) >= initial_native_tick + SAMPLE_NATIVE_TICKS \
					and int(desktop.physical_actor_session.tick) >= initial_rapier_tick + SAMPLE_NATIVE_TICKS:
				break
		if frames == 60:
			parse_key(KEY_D, false)
			parse_key(KEY_A, true)
		if frames > 0 and frames % 30 == 0:
			parse_key(KEY_SPACE, true)
			parse_key(KEY_SPACE, false)
		await process_frame
		frames += 1
	release_controls()
	desktop.publish_actor_keyboard_input()
	var measured_end_usec: int = Time.get_ticks_usec()
	desktop.end_sample()

	var native_ticks: int = int(desktop.latest_snapshot.tick_index) - initial_native_tick
	var rapier_ticks: int = int(desktop.physical_actor_session.tick) - initial_rapier_tick
	var sample_count: int = probe.mutex_acquire_wait_usec.size()
	var callback_count: int = desktop.main_callback_usec.size()
	expect(native_ticks >= SAMPLE_NATIVE_TICKS and rapier_ticks >= SAMPLE_NATIVE_TICKS,
		"bounded window finishes 120 real native and Rapier ticks")
	expect(callback_count >= MIN_MAIN_SAMPLES,
		"actual Main process callbacks continue through the measured window")
	expect(sample_count == callback_count
		and probe.mutex_critical_section_usec.size() == callback_count
		and desktop.main_interval_usec.size() == maxi(callback_count - 1, 0),
		"one handoff per Main callback and one fewer complete inter-callback interval")
	expect(probe.returned_new_snapshots > 0 and probe.returned_no_new_snapshot > 0
		and probe.returned_new_snapshots + probe.returned_no_new_snapshot == sample_count,
		"both new and retained/no-new immutable snapshot paths are sampled")
	expect(desktop._physical_epoch == initial_epoch
		and int(desktop.latest_snapshot.render_world_generation) == initial_world_generation
		and desktop.physical_rig_id == rig
		and desktop.microscenario_definition.get("id", "") == Catalogue.PLAYER_COURSE_ID,
		"real course, actor and World identities persist during acquisition timing")
	expect(not worker.has_failed(), "native worker is not quarantined")

	var result: Dictionary = {
		"schema":"play-wait001-snapshot-mutex-v1",
		"rig":str(rig),
		"host":"main.tscn+CyberSimulationWorker(test-only snapshot probe)+main-thread-Rapier",
		"real_host":true,
		"platform":OS.get_name(),
		"display_server":DisplayServer.get_name(),
		"headless":DisplayServer.get_name() == "headless",
		"godot":str(Engine.get_version_info().get("string", "")),
		"requested_native_workers":int(ProjectSettings.get_setting(
			"cybersand/native_worker_threads", 0)),
		"actual_worker_capacity":int(desktop.latest_snapshot.scheduler_thread_capacity_hint),
		"backend":str(desktop.latest_snapshot.backend_name),
		"course_recipe_sha256":course_recipe_sha,
		"actor_epoch":initial_epoch,
		"world_generation":initial_world_generation,
		"sample_target_native_ticks":SAMPLE_NATIVE_TICKS,
		"completed_native_ticks":native_ticks,
		"completed_rapier_ticks":rapier_ticks,
		"elapsed_wall_ms":float(measured_end_usec - measured_started_usec)/1000.0,
		"main_callbacks":callback_count,
		"snapshot_handoff_calls":sample_count,
		"new_snapshots":probe.returned_new_snapshots,
		"no_new_snapshot_calls":probe.returned_no_new_snapshot,
		"snapshot_mutex_acquire_wait_usec":summarize(probe.mutex_acquire_wait_usec),
		"snapshot_mutex_critical_section_usec":summarize(probe.mutex_critical_section_usec),
		"main_process_interval_usec":summarize(desktop.main_interval_usec),
		"main_process_callback_usec":summarize(desktop.main_callback_usec),
		"raw":{
			"snapshot_mutex_acquire_wait_usec":probe.mutex_acquire_wait_usec.duplicate(),
			"snapshot_mutex_critical_section_usec":probe.mutex_critical_section_usec.duplicate(),
			"main_process_interval_usec":desktop.main_interval_usec.duplicate(),
			"main_process_callback_usec":desktop.main_callback_usec.duplicate()
		},
		"scope":{
			"snapshot_handoff_probe":"test-only timed copy of production take_latest_snapshot mutex and serial fence",
			"isolated_main_wait":"only take_latest_snapshot mutex acquisition, not all Main/worker locks",
			"slow_native_injection":false,
			"native_phase_jobs_held":false,
			"native_busy_shutdown_qualified":false,
			"rendered_fps_measured":false,
			"physical_device_qualified":false,
			"human_feel_qualified":false,
			"test_only_worker_replaced_before_start":true
		},
		"retries":0
	}
	var final_session: CyberPhysicalActorSession = desktop.physical_actor_session
	await close_cycle(desktop, worker, final_session, str(rig) + ": ")
	result["worker_joined"] = not worker._thread.is_started()
	result["rapier_session_retired"] = not is_instance_valid(final_session)
	result["assertions"] = assertions
	result["failures"] = failures
	result["total_elapsed_ms"] = Time.get_ticks_msec() - started_msec
	print("PLAY_WAIT001_RESULT ", JSON.stringify(result))
	quit(0 if failures == 0 else 1)
