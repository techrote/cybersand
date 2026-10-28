extends SceneTree

# PLAY-LIFE-001 / #269 shared helper. Each automatically discovered wrapper
# runs ten complete lifetimes for exactly one mechanical SetP rig. This is the
# accepted main.tscn + CyberSimulationWorker + main-thread Rapier path; no
# synthetic World, second owner, cross-thread live inspection, retries or skips.
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const CYCLES_PER_RIG: int = 10
const WAIT_TIMEOUT_MS: int = 15000

var assertions: int = 0
var failures: int = 0
var completed_cycles: int = 0
var joined_workers: int = 0
var retired_sessions: int = 0
var cycle_durations_ms: Array[int] = []


class DesktopHarness:
	extends "res://scripts/main.gd"
	var test_input_allowed: bool = true

	func actor_keyboard_allowed() -> bool:
		return (test_input_allowed and not paused and actor_prototypes_allowed()
			and _physical_terrain_ready and _actor_reset_receipt == 0
			and not actor_prototype_panel.visible)


func target_rig() -> StringName:
	return &""


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_LIFE001: " + message)


func wait_for(predicate: Callable, timeout_ms: int = WAIT_TIMEOUT_MS) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return false


func course_installed(desktop: Control) -> bool:
	return (is_instance_valid(desktop)
		and desktop.pending_microscenario_apply.is_empty()
		and desktop.tower_context.get("micro_active", false)
		and desktop.microscenario_definition.get("id", "") == Catalogue.PLAYER_COURSE_ID)


func actor_ready(desktop: Control, rig: StringName) -> bool:
	return (course_installed(desktop) and desktop._actor_reset_receipt == 0
		and desktop.physical_actor_session != null
		and desktop.physical_rig_id == rig
		and desktop._physical_terrain_ready and desktop.latest_snapshot != null
		and int(desktop.latest_snapshot.rigid_body_epoch) == desktop._physical_epoch)


# Named, bound predicates keep the asynchronous call boundary unambiguous.
# The source thresholds/guards are unchanged from the original closures.
func clocks_advanced(desktop: Control, rig: StringName,
	initial_physics_tick: int, initial_native_tick: int) -> bool:
	return (actor_ready(desktop, rig) and not desktop._actor_input_rearm
		and desktop.physical_actor_session.tick >= initial_physics_tick + 3
		and int(desktop.latest_snapshot.tick_index) > initial_native_tick)


func physics_resumed(desktop: Control, paused_tick: int) -> bool:
	return (desktop.physical_actor_session != null
		and desktop.physical_actor_session.tick > paused_tick)


func reset_installed(desktop: Control, rig: StringName,
	old_epoch: int, old_world_generation: int) -> bool:
	return (actor_ready(desktop, rig) and desktop._physical_epoch > old_epoch
		and int(desktop.latest_snapshot.render_world_generation) > old_world_generation)


func parse_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func release_controls() -> void:
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT,
		KEY_Q, KEY_E, KEY_Z, KEY_X, KEY_C, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
		parse_key(code, false)


func close_cycle(desktop: Control, worker: CyberSimulationWorker,
	physical_session: Variant, context: String) -> void:
	release_controls()
	if is_instance_valid(desktop):
		desktop.queue_free()
	await process_frame
	await process_frame
	await process_frame
	var joined: bool = worker != null and not worker._thread.is_started()
	expect(joined, context + "scene exit joined the exclusive simulation worker")
	if joined:
		joined_workers += 1
	var retired: bool = physical_session == null or not is_instance_valid(physical_session)
	expect(retired, context + "scene exit retired the main-thread Rapier session")
	if retired:
		retired_sessions += 1
	expect(not is_instance_valid(desktop), context + "scene tree owner was actually freed")


func run_cycle(rig: StringName, cycle: int) -> bool:
	var cycle_started: int = Time.get_ticks_msec()
	var context: String = "%s cycle %02d: " % [rig, cycle]
	release_controls()
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopHarness)
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	expect(desktop.worker_start_error == OK and worker._thread.is_started(),
		context + "existing asynchronous worker started")
	if desktop.worker_start_error != OK or not worker._thread.is_started():
		await close_cycle(desktop, worker, null, context)
		return false

	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
		context + "authored course admitted through the normal selector")
	var course_ok: bool = await wait_for(Callable(self, "course_installed").bind(desktop))
	expect(course_ok, context + "authored course installation acknowledged")
	if not course_ok:
		await close_cycle(desktop, worker, desktop.physical_actor_session, context)
		return false

	expect(desktop.apply_actor_prototype_configuration(
		StringName("rapier/" + str(rig)), &"human", false),
		context + "F5 SetP construction admitted")
	var actor_ok: bool = await wait_for(Callable(self, "actor_ready").bind(desktop, rig))
	expect(actor_ok, context + "actor, native epoch and hard terrain acknowledged")
	if not actor_ok:
		await close_cycle(desktop, worker, desktop.physical_actor_session, context)
		return false

	var first_session = desktop.physical_actor_session
	var initial_epoch: int = desktop._physical_epoch
	var initial_world_generation: int = int(desktop.latest_snapshot.render_world_generation)
	var initial_native_tick: int = int(desktop.latest_snapshot.tick_index)
	var initial_physics_tick: int = first_session.tick
	var retained_snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
	var retained_tick: int = retained_snapshot.tick_index
	var retained_generation: int = retained_snapshot.render_world_generation
	expect(initial_epoch > 0 and initial_world_generation >= 0,
		context + "installed host exposes bounded actor/World identities")

	desktop.paused = false
	var advanced: bool = await wait_for(Callable(self, "clocks_advanced").bind(
		desktop, rig, initial_physics_tick, initial_native_tick))
	expect(advanced, context + "native and Rapier clocks advance independently")
	if not advanced:
		await close_cycle(desktop, worker, desktop.physical_actor_session, context)
		return false

	# Exercise a real button transition, not merely two changing movement
	# commands. Input.parse_input_event reaches the production Viewport handler;
	# there is deliberately no direct test submission to mask a lost edge.
	var session = desktop.physical_actor_session
	expect(session._button_edges[0].is_empty(),
		context + "button edge queue starts empty after neutral rearm")
	var sequence_before: int = int(session.observation(0).last_sequence)
	parse_key(KEY_SPACE, true)
	parse_key(KEY_SPACE, false)
	var queued_edges: Array = session._button_edges[0].duplicate(true)
	var after_edges: Dictionary = session.observation(0)
	expect(queued_edges.size() == 2
		and str(queued_edges[0].button) == "primary" and bool(queued_edges[0].pressed)
		and str(queued_edges[1].button) == "primary" and not bool(queued_edges[1].pressed)
		and int(after_edges.last_sequence) >= sequence_before + 2,
		context + "production handler preserves ordered primary press/release edges")

	# Focus refusal revokes the live lease and clears those still-unconsumed
	# edges before requiring release-to-rearm. No policy/NPC owner is introduced.
	var generation_before: int = int(after_edges.control_generation)
	desktop.set("test_input_allowed", false)
	desktop.publish_actor_keyboard_input()
	var cancelled: Dictionary = session.observation(0)
	expect(desktop._actor_input_rearm
		and int(cancelled.control_generation) > generation_before
		and int(cancelled.pending_input_edges) == 0
		and session._button_edges[0].is_empty(),
		context + "focus loss cancels the input generation and queued edges")
	desktop.set("test_input_allowed", true)
	release_controls()
	desktop.publish_actor_keyboard_input()
	expect(not desktop._actor_input_rearm,
		context + "fully neutral controls rearm the replacement generation")

	# Pause is a main-thread physics boundary. One already-admitted native tick
	# is tolerated elsewhere, but no Rapier step may complete while paused.
	desktop.paused = true
	await physics_frame
	var paused_tick: int = desktop.physical_actor_session.tick
	for _frame: int in range(3):
		await physics_frame
	expect(desktop.physical_actor_session.tick == paused_tick,
		context + "pause prevents completed Rapier ticks")
	desktop.paused = false
	var resumed: bool = await wait_for(Callable(self, "physics_resumed").bind(desktop, paused_tick))
	expect(resumed, context + "resume produces a fresh completed Rapier tick")

	# R constructs a new native World and actor incarnation while retaining the
	# chosen authored course and rig. Old immutable snapshots remain unchanged.
	var old_session = desktop.physical_actor_session
	var old_epoch: int = desktop._physical_epoch
	var old_world_generation: int = int(desktop.latest_snapshot.render_world_generation)
	desktop.microscenario_reset()
	var reset_ok: bool = await wait_for(Callable(self, "reset_installed").bind(
		desktop, rig, old_epoch, old_world_generation))
	expect(reset_ok, context + "reset advances actor and native World lifetimes")
	var reset_epoch: int = desktop._physical_epoch if reset_ok else -1
	var reset_world_generation: int = int(desktop.latest_snapshot.render_world_generation) if reset_ok else -1
	if reset_ok:
		expect(not is_instance_valid(old_session),
			context + "reset retires the prior Rapier owner")
		expect(desktop.microscenario_definition.get("id", "") == Catalogue.PLAYER_COURSE_ID
			and desktop.physical_rig_id == rig,
			context + "reset retains authored map and selected mechanical rig")
		expect(not desktop._playable_course_progress.started
			and desktop._playable_course_progress.target_index == 0
			and desktop._playable_course_progress.elapsed_ticks == 0,
			context + "new actor/World lifetime cannot retain an old lap")
		expect(retained_snapshot.tick_index == retained_tick
			and retained_snapshot.render_world_generation == retained_generation,
			context + "later reset cannot mutate an earlier immutable snapshot")
		expect(reset_epoch > initial_epoch
			and reset_world_generation > initial_world_generation,
			context + "replacement identities are strictly newer")

	var final_session = desktop.physical_actor_session
	expect(not worker.has_failed(), context + "worker remained outside failure quarantine")
	await close_cycle(desktop, worker, final_session, context)
	var duration: int = Time.get_ticks_msec() - cycle_started
	cycle_durations_ms.append(duration)
	completed_cycles += 1
	print("PLAY_LIFE001_CYCLE ", JSON.stringify({
		"rig":str(rig), "cycle":cycle, "elapsed_ms":duration,
		"initial_actor_epoch":initial_epoch,
		"reset_actor_epoch":reset_epoch,
		"initial_world_generation":initial_world_generation,
		"reset_world_generation":reset_world_generation,
		"worker_joined":not worker._thread.is_started(),
		"reset_ok":reset_ok
	}))
	return reset_ok


func run() -> void:
	var rig: StringName = target_rig()
	expect(rig in Course.MECHANICAL_PRESETS,
		"wrapper selected one supported mechanical SetP rig")
	if rig not in Course.MECHANICAL_PRESETS:
		quit(1)
		return
	var test_started: int = Time.get_ticks_msec()
	for cycle: int in range(CYCLES_PER_RIG):
		var complete: bool = await run_cycle(rig, cycle)
		if not complete:
			break
	var total_ms: int = Time.get_ticks_msec() - test_started
	var maximum_ms: int = 0
	for value: int in cycle_durations_ms:
		maximum_ms = maxi(maximum_ms, value)
	expect(completed_cycles == CYCLES_PER_RIG,
		"all ten actual scene lifetimes completed for " + str(rig))
	expect(joined_workers == completed_cycles and retired_sessions == completed_cycles,
		"every completed lifecycle joined its worker and retired Rapier")
	print("PLAY_LIFE001_RESULT ", JSON.stringify({
		"rig":str(rig), "cycles_requested":CYCLES_PER_RIG,
		"cycles_completed":completed_cycles,
		"workers_joined":joined_workers,
		"rapier_sessions_retired":retired_sessions,
		"assertions":assertions, "failures":failures,
		"elapsed_ms":total_ms, "maximum_cycle_ms":maximum_ms,
		"host":"main.tscn+CyberSimulationWorker+main-thread-Rapier",
		"real_host":true, "retries":0,
		"liquid_policy_reconstruction_cycles":0,
		"slow_native_injection":false,
		"rendered_fps_measured":false,
		"physical_gamepad_qualified":false
	}))
	quit(0 if failures == 0 else 1)
