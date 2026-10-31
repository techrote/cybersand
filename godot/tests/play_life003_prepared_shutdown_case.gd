extends "res://tests/play_life001_shared_host_case.gd"

# PLAY-LIFE-003 / #269: actual Main/Rapier exit with a native-prepared
# reconstruction outstanding at the existing precommit boundary. The delay is
# after preparation, not a slow native tick or outstanding native phase jobs.
# Native/adapter inspection happens only after the exclusive Godot owner joins.
const MAIN_PROGRESS_FRAMES: int = 8

class ProgressHarness:
	extends DesktopHarness
	var completed_main_callbacks: int = 0

	func _process(delta: float) -> void:
		super._process(delta)
		completed_main_callbacks += 1


class PreparationBarrier extends RefCounted:
	var arrived := Semaphore.new()
	var resume := Semaphore.new()

	func enter() -> void:
		arrived.post()
		resume.wait()


class StopFenceRelease extends RefCounted:
	var worker: CyberSimulationWorker
	var barrier: PreparationBarrier
	var safety_timeout_ms: int = Watchdogs.milliseconds("operation_seconds")

	func wait_then_release() -> Dictionary:
		var started: int = Time.get_ticks_msec()
		var deadline: int = started + safety_timeout_ms
		var observed: bool = false
		while Time.get_ticks_msec() < deadline:
			if worker._mutex.try_lock():
				observed = not worker._running
				worker._mutex.unlock()
				if observed:
					break
			OS.delay_usec(1000)
		# Always release, including on a broken stop path. The timeout remains a
		# test failure, rather than stranding Main inside wait_to_finish().
		barrier.resume.post()
		return {"stop_observed":observed,"deadline_expired":not observed,
			"elapsed_ms":Time.get_ticks_msec()-started}


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_LIFE003: " + message)


func nodes_retired(nodes: Array) -> bool:
	for node: Variant in nodes:
		if is_instance_valid(node):
			return false
	return true


func exercise_contended_safety_release(worker: CyberSimulationWorker) -> Dictionary:
	# The real owner has joined. Hold its actual mutex on main so a blocking
	# acquisition in the helper cannot masquerade as an unconditional deadline.
	var safety_barrier := PreparationBarrier.new()
	var safety_release := StopFenceRelease.new()
	safety_release.worker = worker
	safety_release.barrier = safety_barrier
	safety_release.safety_timeout_ms = 25
	var safety_helper := Thread.new()
	worker._mutex.lock()
	var helper_error: Error = safety_helper.start(safety_release.wait_then_release)
	expect(helper_error == OK, "contended safety helper starts against the joined real worker mutex")
	var released_while_held: bool = false
	if helper_error == OK:
		released_while_held = await wait_for(func() -> bool: return safety_barrier.resume.try_wait())
	# Always unlock before joining, including when the predicate fails. A
	# blocking-acquisition regression becomes a bounded failure, not a deadlock.
	worker._mutex.unlock()
	var result: Dictionary = safety_helper.wait_to_finish() if helper_error == OK else {}
	expect(released_while_held,
		"safety semaphore releases while main still holds the contended worker mutex")
	expect(bool(result.get("deadline_expired", false))
		and not bool(result.get("stop_observed", true)),
		"contended helper reaches its deadline without reading the protected stop flag")
	safety_release.worker = null
	safety_release.barrier = null
	return {"safety_timeout_ms":25,"released_while_mutex_held":released_while_held,
		"deadline_expired":bool(result.get("deadline_expired", false)),
		"stop_observed":bool(result.get("stop_observed", true)),
		"elapsed_ms":int(result.get("elapsed_ms", -1))}


func run() -> void:
	var started: int = Time.get_ticks_msec()
	var rig: StringName = target_rig()
	expect(rig in Course.MECHANICAL_PRESETS, "wrapper selects a supported SetP rig")
	if rig not in Course.MECHANICAL_PRESETS:
		quit(1)
		return
	release_controls()
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(ProgressHarness)
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

	var accepted_session: CyberPhysicalActorSession = desktop.physical_actor_session
	var accepted_bodies: Array = accepted_session.bodies()
	var previous: CyberSimulationSnapshot = desktop.latest_snapshot
	var applied_policy: Dictionary = previous.lab_context.liquid_solver_policy.duplicate(true)
	var applied_receipt: Dictionary = previous.lab_context.liquid_construction_receipt.duplicate(true)
	var applied_generation: int = int(applied_policy.session_generation)
	var world_generation: int = previous.render_world_generation
	var actor_epoch: int = desktop._physical_epoch
	expect(not accepted_bodies.is_empty() and not applied_policy.is_empty(),
		"accepted owner has actual Rapier bodies and applied native policy")

	var barrier := PreparationBarrier.new()
	worker._controlled_liquid_prepare_barrier = barrier.enter
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.session_picker.select(1)
	panel.select_preset(2)
	panel.refresh(desktop.tower_context)
	expect(bool(panel._validation.get("accepted", false)) and not panel.apply_button.disabled,
		"existing panel validates pressure/reference reconstruction")
	var queued: bool = panel.apply_active()
	expect(queued, "ordinary host queues the prepared supported reconstruction")
	var arrived: bool = false
	if queued:
		arrived = await wait_for(func() -> bool: return barrier.arrived.try_wait())
	expect(arrived, "native-prepared physical-ready operation reaches precommit barrier")
	if not arrived:
		# A late arrival must never strand teardown on the failure path.
		barrier.resume.post()
		await close_cycle(desktop, worker, accepted_session, str(rig) + ": ")
		if not worker._thread.is_started():
			worker._controlled_liquid_prepare_barrier = Callable()
		quit(1)
		return

	var staged: RefCounted = desktop._pending_physical_candidate
	expect(staged != null and is_instance_valid(staged.session),
		"pending physical owner still holds its staged Rapier session at the barrier")
	if staged == null or not is_instance_valid(staged.session):
		barrier.resume.post()
		await close_cycle(desktop, worker, accepted_session, str(rig) + ": ")
		if not worker._thread.is_started():
			worker._controlled_liquid_prepare_barrier = Callable()
		quit(1)
		return
	var staged_session: CyberPhysicalActorSession = staged.session
	var staged_bodies: Array = staged_session.bodies()
	var prepared: Dictionary = worker.prepared_physical_liquid_values()
	var token: int = int(prepared.get("token", 0))
	expect(staged != null and staged_session != accepted_session and not staged_bodies.is_empty(),
		"main thread retains distinct real accepted and staged Rapier graphs")
	expect(desktop._prepared_physical_ready_sent and staged.ready()
		and token > 0 and int(prepared.get("instance_id", 0)) == staged.get_instance_id(),
		"main-thread physical readiness and copied native token bind the pending operation")

	var callbacks_before: int = desktop.completed_main_callbacks
	for frame: int in range(MAIN_PROGRESS_FRAMES):
		await process_frame
	var callbacks_during_delay: int = desktop.completed_main_callbacks - callbacks_before
	expect(callbacks_during_delay >= MAIN_PROGRESS_FRAMES - 1,
		"actual Main callbacks progress while the exclusive owner waits before commit")
	expect(desktop.physical_actor_session == accepted_session
		and desktop._pending_physical_candidate == staged
		and not desktop.pending_microscenario_apply.is_empty()
		and desktop._physical_epoch == actor_epoch
		and desktop.latest_snapshot.render_world_generation == world_generation
		and desktop.tower_context.liquid_solver_policy == applied_policy
		and desktop.tower_context.liquid_construction_receipt == applied_receipt,
		"delayed preparation preserves accepted owner, generation and applied receipt")

	var release := StopFenceRelease.new()
	release.worker = worker
	release.barrier = barrier
	var helper := Thread.new()
	var helper_error: Error = helper.start(release.wait_then_release)
	expect(helper_error == OK, "bounded synchronization-only stop-fence helper starts")
	if helper_error != OK:
		barrier.resume.post()
	release_controls()
	desktop.queue_free()
	await process_frame
	await process_frame
	await process_frame
	var release_result: Dictionary = helper.wait_to_finish() if helper_error == OK else {}
	release.worker = null
	release.barrier = null
	expect(bool(release_result.get("stop_observed", false))
		and not bool(release_result.get("deadline_expired", true)),
		"helper releases only after owner stop fence without using safety deadline")
	expect(not is_instance_valid(desktop), "actual Main scene owner is freed")
	var joined: bool = not worker._thread.is_started()
	expect(joined, "scene exit joined the exclusive GDScript simulation owner")
	expect(not is_instance_valid(accepted_session) and nodes_retired(accepted_bodies),
		"accepted main-thread Rapier session and actual bodies retired")
	expect(not is_instance_valid(staged_session) and nodes_retired(staged_bodies)
		and staged.session == null and staged.viewport == null,
		"pending main-thread Rapier session, bodies and private viewport retired")

	# The owner has joined, so these adapter calls now have exclusive access.
	if not joined:
		quit(1)
		return
	var world: Variant = worker._world
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	expect(joined and world.get_liquid_policy_session_generation() == applied_generation
		and world.get_liquid_solver_policy() == applied_policy
		and world.get_applied_liquid_construction_receipt() == applied_receipt,
		"stop fence refused commit and retained applied native generation/policy/receipt")
	expect(worker._pending_physical_liquid.is_empty()
		and worker.prepared_physical_liquid_values().is_empty()
		and worker._prepared_physical_ready.is_empty()
		and bridge.prepared_liquid_run_capture(world, token).is_empty(),
		"joined owner retired pending publication/readiness and native preparation token")
	expect(not worker.has_failed(), "ordinary cancellation did not quarantine accepted World")
	expect(previous.render_world_generation == world_generation
		and previous.lab_context.liquid_solver_policy == applied_policy
		and previous.lab_context.liquid_construction_receipt == applied_receipt,
		"retained immutable snapshot survives pending teardown unchanged")

	var contended_safety: Dictionary = await exercise_contended_safety_release(worker)
	var worker_weak: WeakRef = weakref(worker)
	var world_weak: WeakRef = weakref(world)
	worker._controlled_liquid_prepare_barrier = Callable()
	world = null
	worker = null
	bridge = null
	helper = null
	release = null
	barrier = null
	staged = null
	for frame: int in range(3):
		await process_frame
	expect(worker_weak.get_ref() == null,
		"dropping retained owner references destroys the worker object")
	expect(world_weak.get_ref() == null,
		"dropping retained owner references destroys the native adapter object")

	print("PLAY_LIFE003_RESULT ", JSON.stringify({
		"rig":str(rig),"real_host":true,
		"host":"main.tscn+CyberSimulationWorker+main-thread-Rapier",
		"assertions":assertions,"failures":failures,
		"elapsed_ms":Time.get_ticks_msec()-started,
		"prepared_operations":1,"stop_fences_observed":1 if release_result.get("stop_observed",false) else 0,
		"main_callbacks_during_delay":callbacks_during_delay,
		"workers_joined":1 if joined else 0,
		"worker_destroyed":worker_weak.get_ref() == null,
		"native_adapter_destroyed":world_weak.get_ref() == null,
		"contended_safety_probe":contended_safety,
		"prepared_token":token,"applied_session_generation":applied_generation,
		"world_generation":world_generation,"actor_epoch":actor_epoch,
		"retries":0,"slow_native_injection":false,"native_phase_jobs_held":false,
		"native_thread_join_trace":false,"rendered_fps_measured":false}))
	quit(0 if failures == 0 else 1)
