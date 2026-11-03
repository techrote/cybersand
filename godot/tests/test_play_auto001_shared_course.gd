extends SceneTree

const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

# PLAY-AUTO-001 / #266: actual composable desktop course, not a standalone
# benchmark or a new World owner. Verify the construction-time native Auto
# policy through the immutable snapshot published by CyberSimulationWorker.
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Course = preload("res://scripts/player_playground_course.gd")

var desktop: Control
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("PLAY_AUTO001: " + message)


func wait_for(predicate: Callable, timeout_ms: int = -1) -> bool:
	if timeout_ms < 0:
		timeout_ms = Watchdogs.milliseconds("operation_seconds")
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return false


func course_ready() -> bool:
	return (desktop.pending_microscenario_apply.is_empty()
		and desktop.tower_context.get("micro_active", false)
		and desktop.microscenario_definition.get("id", "") == Catalogue.PLAYER_COURSE_ID)


func rig_ready() -> bool:
	return (course_ready() and desktop.physical_actor_session != null
		and desktop.physical_rig_id == &"acrobat"
		and desktop._actor_reset_receipt == 0
		and desktop._physical_terrain_ready)


func ticks_ready() -> bool:
	return (rig_ready() and desktop.latest_snapshot != null
		and desktop.latest_snapshot.tick_index >= 30
		and desktop.physical_actor_session.tick >= 20)


func finish(evidence: Dictionary = {}) -> void:
	if is_instance_valid(desktop):
		desktop.queue_free()
	await process_frame
	await process_frame
	evidence["assertions"] = assertions
	evidence["failures"] = failures
	evidence["native_auto_source"] = "CyberNativeCellWorld::create_world"
	evidence["route"] = "existing-CyberSimulationWorker+main-Rapier"
	evidence["parallel_speedup_proven"] = false
	evidence["rendered_fps_measured"] = false
	evidence["gamepad_qualified"] = false
	print("PLAY_AUTO001_RESULT ", JSON.stringify(evidence))
	quit(0 if failures == 0 else 1)


func run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		expect(false, "native GDExtension is required; serial fallback cannot qualify Auto")
		await finish()
		return

	# The project's regular desktop selection is Auto. Do not mutate a
	# global setting to retune the live simulation or test a second owner.
	var requested: int = int(ProjectSettings.get_setting("cybersand/native_worker_threads", -1))
	var logical: int = int(ClassDB.class_call_static(
		&"CyberNativeCellWorld", &"logical_processor_count"))
	var expected_auto: int = int(ClassDB.class_call_static(
		&"CyberNativeCellWorld", &"auto_worker_threads", logical))
	expect(requested == 0, "ordinary desktop native workers must default to Auto (0)")
	expect(logical >= 1 and expected_auto in [2, 4, 6],
		"native Auto policy must report a supported construction count")
	if requested != 0 or logical < 1:
		await finish({"requested_setting":requested, "logical_processors":logical})
		return

	desktop = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	expect(desktop.worker_start_error == OK and desktop.simulation_worker._thread.is_started(),
		"existing desktop simulation Thread started, without a second owner")

	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
		"real desktop accepts the original course through the normal picker route")
	var installed: bool = await wait_for(Callable(self, "course_ready"))
	if not installed:
		expect(false, "normal course install did not acknowledge")
		await finish()
		return

	expect(desktop.microscenario_definition.source_recipe == "CyberPlayerPlaygroundCourse/v1",
		"Auto host retains the exact authored source recipe")
	expect(desktop.microscenario_definition.rectangles.size() == Course.layout().size() * 5,
		"native course contains the complete authored five-field rectangles")

	expect(desktop.apply_actor_prototype_configuration(&"rapier/acrobat", &"human", false),
		"same real F5 SetP actor construction is available")
	var prepared: bool = await wait_for(Callable(self, "rig_ready"))
	if not prepared:
		expect(false, "real Rapier actor or physical terrain was not ready")
		await finish()
		return

	desktop.paused = false
	var advanced: bool = await wait_for(Callable(self, "ticks_ready"))
	if not advanced:
		expect(false, "independently paced native and Rapier sessions did not advance")
		await finish()
		return

	# Main reads copied snapshot values only. Never inspect or configure
	# simulation_worker's live native World across its thread boundary.
	var first = desktop.latest_snapshot
	var reported: int = int(first.scheduler_thread_capacity_hint)
	expect(reported == expected_auto,
		"actual native World worker capacity differs from startup Auto selection")
	expect(str(first.backend_name) != "" and str(first.backend_name) != "gdscript-serial-fallback",
		"composable desktop must use the production native backend")
	expect(not desktop.simulation_worker.has_failed(),
		"native worker reported a fault after real course admission")
	expect(first.tick_index > 0 and desktop.physical_actor_session.tick > 0,
		"both native and Rapier owners advanced")
	expect(desktop._physical_terrain_ready,
		"live Rapier terrain gate was not acknowledged")

	var last_tick: int = -1
	var unique_ticks: int = 0
	var maximum_jobs: int = 0
	var maximum_parallel_phases: int = 0
	var valid_metrics: bool = true
	for _frame: int in range(90):
		await process_frame
		var sample = desktop.latest_snapshot
		if sample == null or int(sample.tick_index) <= last_tick:
			continue
		last_tick = int(sample.tick_index)
		unique_ticks += 1
		maximum_jobs = maxi(maximum_jobs, int(sample.scheduler_jobs_last_tick))
		maximum_parallel_phases = maxi(maximum_parallel_phases,
			int(sample.scheduler_parallel_phases_last_tick))
		valid_metrics = valid_metrics and (
			int(sample.scheduler_thread_capacity_hint) == expected_auto
			and int(sample.scheduler_jobs_last_tick) >= 0
			and int(sample.scheduler_parallel_phases_last_tick) >= 0
			and is_finite(float(sample.simulation_time_ms))
			and is_finite(float(sample.worker_step_time_ms))
			and not desktop.simulation_worker.has_failed())
	expect(unique_ticks >= 3 and last_tick > int(first.tick_index),
		"worker must publish independently advancing native tick receipts")
	expect(valid_metrics, "copied native scheduler/timing values must be valid and stable")
	expect(ProjectSettings.get_setting("cybersand/native_worker_threads", -1) == 0,
		"gameplay route must not rewrite construction-time worker configuration")

	# No parallel speedup or visual frame-pacing claim: native phases may be
	# zero under sparse gameplay load even when the persistent pool exists.
	var report: Dictionary = {
		"requested_setting":requested,
		"logical_processors":logical,
		"auto_policy_workers":expected_auto,
		"actual_worker_capacity":reported,
		"native_ticks_observed":unique_ticks,
		"last_native_tick":last_tick,
		"rapier_tick":desktop.physical_actor_session.tick,
		"maximum_scheduler_jobs":maximum_jobs,
		"maximum_parallel_phases":maximum_parallel_phases,
		"backend":str(first.backend_name),
		"terrain_ready":desktop._physical_terrain_ready
	}
	desktop.paused = true
	await finish(report)
