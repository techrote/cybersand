extends "res://tests/play_life001_shared_host_case.gd"

# PLAY-BUSY-001B / #269/#270: controlled hold inside the REAL phased World
# dispatch used by main.tscn. Main sees only the separate copied-value test gate;
# it never calls the live World while the simulation owner is running.
const RIG: StringName = &"jetbarrel"
const HOLD_TIMEOUT_MS: int = 10000
const MAIN_HOLD_FRAMES: int = 12
const HELPER_TIMEOUT_MS: int = 8000

var desktop: Control
var result: Dictionary = {}


class ProgressHarness:
	extends DesktopHarness
	var completed_main_callbacks: int = 0
	var completed_physics_callbacks: int = 0
	var completed_input_callbacks: int = 0

	func _process(delta: float) -> void:
		super._process(delta)
		completed_main_callbacks += 1

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		completed_physics_callbacks += 1

	func _unhandled_key_input(event: InputEvent) -> void:
		super._unhandled_key_input(event)
		if event is InputEventKey and not event.echo:
			completed_input_callbacks += 1


class StopObserver extends RefCounted:
	var gate: Variant
	var generation: int = 0
	var worker: CyberSimulationWorker
	var rapier: CyberRapierPhysicsBridge
	var requested := Semaphore.new()
	var stages: Array[String] = []
	var stop_marked: bool = false
	var requested_thread_started: bool = false
	var joined_thread_started: bool = true
	var rapier_at_requested: bool = false
	var rapier_at_joined: bool = false
	var requested_status: Dictionary = {}
	var joined_status: Dictionary = {}

	func observe(stage: StringName) -> void:
		stages.append(str(stage))
		if stage == &"requested":
			requested_thread_started = worker._thread.is_started()
			rapier_at_requested = rapier.is_initialized()
			stop_marked = bool(gate.mark_stop(generation))
			requested_status = gate.status()
			requested.post()
		elif stage == &"joined":
			joined_thread_started = worker._thread.is_started()
			rapier_at_joined = rapier.is_initialized()
			joined_status = gate.status()


class ReleaseHelper extends RefCounted:
	var gate: Variant
	var generation: int = 0
	var requested: Semaphore
	var timeout_ms: int = HELPER_TIMEOUT_MS

	func wait_then_release() -> Dictionary:
		var started: int = Time.get_ticks_msec()
		var deadline: int = started + timeout_ms
		var stop_observed: bool = false
		while Time.get_ticks_msec() < deadline:
			if requested.try_wait():
				stop_observed = true
				break
			OS.delay_usec(1000)
		# Always attempt release so a broken stop path becomes a bounded failure,
		# not a permanently stranded engine process.
		var released: bool = bool(gate.release(generation))
		return {
			"stop_observed": stop_observed,
			"released": released,
			"deadline_expired": not stop_observed,
			"elapsed_ms": Time.get_ticks_msec() - started,
		}


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_BUSY001B: " + message)


func parallel_host_ready() -> bool:
	return (actor_ready(desktop, RIG) and not desktop.paused
		and desktop.latest_snapshot != null
		and int(desktop.latest_snapshot.scheduler_thread_capacity_hint) >= 2
		and int(desktop.latest_snapshot.scheduler_parallel_phases_last_tick) > 0)


func gate_held(gate: Variant, generation: int) -> bool:
	var status: Dictionary = gate.status()
	return (int(status.get("generation", 0)) == generation
		and bool(status.get("selected", false))
		and not bool(status.get("released", true))
		and not bool(status.get("timed_out", true))
		and int(status.get("waiting", 0)) >= 2
		and int(status.get("active", 0)) >= 2
		and int(status.get("distinct_threads", 0)) >= 2
		and int(status.get("dispatch_return_sequence", 0)) == 0)


func nodes_retired(nodes: Array) -> bool:
	for node: Variant in nodes:
		if is_instance_valid(node):
			return false
	return true


func run() -> void:
	var started: int = Time.get_ticks_msec()
	expect(ClassDB.class_exists(&"CyberNativeCellWorld"),
		"actual native desktop adapter is available")
	expect(ClassDB.class_exists(&"CyberPlayBusyTestGate"),
		"special source-matched test runtime exposes the copied-value phase gate")
	if not ClassDB.class_exists(&"CyberPlayBusyTestGate"):
		quit(1)
		return

	release_controls()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(ProgressHarness)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	expect(desktop.worker_start_error == OK and worker._thread.is_started(),
		"existing asynchronous simulation owner starts")
	if desktop.worker_start_error != OK or not worker._thread.is_started():
		await close_cycle(desktop, worker, null, "busy001b: ")
		quit(1)
		return

	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
		"actual authored Player Playground course admits through normal Main route")
	var ready: bool = await wait_for(Callable(self, "course_installed").bind(desktop))
	expect(ready, "native worker acknowledges the authored course")
	if ready:
		expect(desktop.apply_actor_prototype_configuration(
			StringName("rapier/" + str(RIG)), &"human", false),
			"ordinary SetP route constructs the real Jet Barrel")
		ready = await wait_for(Callable(self, "actor_ready").bind(desktop, RIG))
		expect(ready, "actual actor, native epoch and hard terrain are ready")
	if not ready:
		await close_cycle(desktop, worker, desktop.physical_actor_session, "busy001b: ")
		quit(1)
		return

	desktop.paused = false
	release_controls()
	desktop.publish_actor_keyboard_input()
	ready = await wait_for(Callable(self, "parallel_host_ready"))
	expect(ready, "ordinary gameplay produced a completed real parallel native phase")
	if not ready:
		await close_cycle(desktop, worker, desktop.physical_actor_session, "busy001b: ")
		quit(1)
		return

	var gate: Variant = ClassDB.instantiate(&"CyberPlayBusyTestGate")
	expect(gate != null, "test-only native gate instantiates independently of World")
	var generation: int = int(gate.arm(2, HOLD_TIMEOUT_MS))
	expect(generation > 0, "bounded gate arms for the next complete real pool dispatch")
	if generation <= 0:
		await close_cycle(desktop, worker, desktop.physical_actor_session, "busy001b: ")
		quit(1)
		return

	var held: bool = await wait_for(Callable(self, "gate_held").bind(gate, generation), 5000)
	expect(held, "at least two distinct actual World phase jobs are claimed and held")
	if not held:
		gate.release(generation)
		await close_cycle(desktop, worker, desktop.physical_actor_session, "busy001b: ")
		quit(1)
		return
	var held_status: Dictionary = gate.status()
	expect(int(held_status.expected_tasks) >= 2
		and int(held_status.entered) >= 2
		and int(held_status.completed) == 0
		and int(held_status.dispatch_started_sequence) > 0
		and int(held_status.first_arrival_sequence) > int(held_status.dispatch_started_sequence),
		"copied gate receipt identifies a genuine outstanding dispatch before any held task completes")
	expect(not bool(held_status.thread_identity_overflow),
		"bounded actual worker identity observation does not overflow")

	# Freeze the last committed immutable packet. A blocked native phase may not
	# partially publish a newer World state while Main keeps presenting it.
	var retained_snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
	var retained_serial: int = retained_snapshot.serial
	var retained_tick: int = retained_snapshot.tick_index
	var retained_generation: int = retained_snapshot.render_world_generation
	var main_before: int = desktop.completed_main_callbacks
	var physics_before: int = desktop.completed_physics_callbacks
	var input_before: int = desktop.completed_input_callbacks
	var rapier_before: int = desktop.rapier_bridge.manual_step_count()
	var accepted_before: int = desktop.physical_actor_session.accepted_commands

	parse_key(KEY_D, true)
	parse_key(KEY_D, false)
	for _frame: int in range(MAIN_HOLD_FRAMES):
		await process_frame
	for _frame: int in range(3):
		await physics_frame

	var main_during_hold: int = desktop.completed_main_callbacks - main_before
	var physics_during_hold: int = desktop.completed_physics_callbacks - physics_before
	var input_during_hold: int = desktop.completed_input_callbacks - input_before
	var rapier_during_hold: int = desktop.rapier_bridge.manual_step_count() - rapier_before
	expect(main_during_hold >= MAIN_HOLD_FRAMES - 1,
		"actual Main presentation callbacks progress while real native phase jobs stay held")
	expect(physics_during_hold >= 2 and rapier_during_hold >= 2,
		"actual main-thread physics/Rapier continues independently during the native hold")
	expect(input_during_hold >= 2
		and desktop.physical_actor_session.accepted_commands > accepted_before,
		"real Viewport key edges reach the existing Main input/session path during the native hold")
	expect(desktop.latest_snapshot.serial == retained_serial
		and desktop.latest_snapshot.tick_index == retained_tick
		and desktop.latest_snapshot.render_world_generation == retained_generation,
		"held phase cannot leak a partial newer snapshot while Main remains responsive")
	expect(desktop.latest_snapshot == retained_snapshot,
		"Main retains the exact immutable committed packet throughout the held native phase")
	var still_held: Dictionary = gate.status()
	expect(int(still_held.waiting) >= 2 and int(still_held.dispatch_return_sequence) == 0
		and not bool(still_held.released) and not bool(still_held.timed_out),
		"responsiveness observations finish before any gate release or dispatch return")

	var session: CyberPhysicalActorSession = desktop.physical_actor_session
	var bodies: Array = session.bodies()
	var rapier: CyberRapierPhysicsBridge = desktop.rapier_bridge
	var observer := StopObserver.new()
	observer.gate = gate
	observer.generation = generation
	observer.worker = worker
	observer.rapier = rapier
	worker._play_busy_stop_observer = observer.observe

	var release := ReleaseHelper.new()
	release.gate = gate
	release.generation = generation
	release.requested = observer.requested
	var helper := Thread.new()
	var helper_error: Error = helper.start(release.wait_then_release)
	expect(helper_error == OK, "bounded release helper starts before the production stop fence")
	if helper_error != OK:
		gate.release(generation)

	release_controls()
	desktop.queue_free()
	for _frame: int in range(4):
		await process_frame
	var release_result: Dictionary = helper.wait_to_finish() if helper_error == OK else {}
	var final_status: Dictionary = gate.status()

	expect(bool(observer.stop_marked)
		and observer.stages.size() == 2
		and observer.stages[0] == "requested" and observer.stages[1] == "joined",
		"actual stop_worker fence records requested then joined around wait_to_finish")
	expect(bool(release_result.get("stop_observed", false))
		and bool(release_result.get("released", false))
		and not bool(release_result.get("deadline_expired", true)),
		"helper releases held native jobs only after the production stop request, without safety timeout")
	expect(observer.requested_thread_started and not observer.joined_thread_started,
		"simulation Thread is live at the stop request and stopped at the joined observation")
	expect(not observer.rapier_at_requested and not observer.rapier_at_joined,
		"accepted SetP Rapier owner is already retired before the simulation-worker stop fence")
	expect(not rapier.is_initialized(),
		"retained accepted SetP bridge stays shut down across worker stop and join")
	expect(not worker._thread.is_started(),
		"production scene exit joined the exclusive simulation owner")
	expect(not is_instance_valid(session) and nodes_retired(bodies),
		"actual SetP session and main-thread Rapier body nodes retire during scene exit")
	expect(not is_instance_valid(desktop), "actual Main scene owner is freed")

	expect(bool(final_status.released) and not bool(final_status.timed_out)
		and int(final_status.entered) == int(final_status.expected_tasks)
		and int(final_status.completed) == int(final_status.expected_tasks)
		and int(final_status.waiting) == 0 and int(final_status.active) == 0,
		"every real task in the selected phase drains exactly once after manual release")
	expect(int(final_status.dispatch_started_sequence) < int(final_status.first_arrival_sequence)
		and int(final_status.first_arrival_sequence) < int(final_status.stop_sequence)
		and int(final_status.stop_sequence) < int(final_status.release_sequence)
		and int(final_status.release_sequence) < int(final_status.drained_sequence)
		and int(final_status.drained_sequence) < int(final_status.dispatch_return_sequence),
		"native receipt orders dispatch, claimed jobs, production stop, release, drain and pool return")
	expect(int(observer.requested_status.stop_waiting) >= 2
		and int(observer.requested_status.stop_active) >= 2
		and int(observer.requested_status.dispatch_return_sequence) == 0,
		"production stop request is observed while multiple real native jobs remain outstanding")
	expect(int(observer.joined_status.dispatch_return_sequence) > 0
		and int(observer.joined_status.completed) == int(observer.joined_status.expected_tasks),
		"joined observation occurs only after selected phase drained and real dispatch returned")

	# Only after join is Main/test allowed to inspect the worker-owned adapter.
	var world: Variant = worker._world
	var world_weak: WeakRef = weakref(world)
	expect(world != null and not worker.has_failed(),
		"joined exclusive owner leaves the accepted native adapter healthy")
	var stop_fence_observed: bool = observer.stop_marked \
		and observer.stages == ["requested", "joined"]
	var setp_rapier_retired_before_worker_stop: bool = \
		not observer.rapier_at_requested and not observer.rapier_at_joined \
		and not rapier.is_initialized()
	var worker_weak: WeakRef = weakref(worker)
	worker._play_busy_stop_observer = Callable()
	observer.worker = null
	observer.rapier = null
	world = null
	worker = null
	desktop = null
	session = null
	observer = null
	release = null
	helper = null
	gate = null
	for _frame: int in range(3):
		await process_frame
	expect(worker_weak.get_ref() == null,
		"retained worker object destroys only after its thread has joined")
	expect(world_weak.get_ref() == null,
		"native adapter destroys after joined worker and completed Main/Rapier shutdown")

	result = {
		"assertions": assertions,
		"failures": failures,
		"elapsed_ms": Time.get_ticks_msec() - started,
		"rig": str(RIG),
		"host": "main.tscn+CyberSimulationWorker+real-World-phase-pool+main-thread-Rapier",
		"native_phase_jobs_held": int(held_status.waiting),
		"native_phase_tasks": int(final_status.expected_tasks),
		"native_phase_tick": int(final_status.tick),
		"native_phase": int(final_status.phase),
		"main_callbacks_during_hold": main_during_hold,
		"physics_callbacks_during_hold": physics_during_hold,
		"input_callbacks_during_hold": input_during_hold,
		"rapier_steps_during_hold": rapier_during_hold,
		"production_stop_fence_observed": stop_fence_observed,
		"workers_joined": 1 if worker_weak.get_ref() == null else 0,
		"native_adapter_destroyed": world_weak.get_ref() == null,
		"setp_rapier_retired_before_worker_stop": setp_rapier_retired_before_worker_stop,
		"gate_receipt": final_status,
		"retries": 0,
		"test_only_controlled_native_phase_hold": true,
		"rendered_fps_measured": false,
		"physical_gamepad_qualified": false,
		"human_feel_qualified": false,
	}
	print("PLAY_BUSY001B_RESULT ", JSON.stringify(result))
	quit(0 if failures == 0 else 1)
