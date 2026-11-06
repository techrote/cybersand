extends SceneTree

# Opt-in desktop lockstep (owner decision 2026-11-06; COUPLING-LOCKSTEP-001
# amendment_002; PR #474 review repairs). Runs the real main.tscn +
# CyberSimulationWorker + main-thread Rapier path.
#
# - Default launch: lockstep and deterministic packing stay off.
# - Real CLI: a child process launched with --lockstep-coupling enables the
#   mode through lockstep_coupling_requested(), not an override.
# - Fenced play, pause, world reset and an articulated physical actor: every
#   physics callback publishes at most one body sample, every fenced Rapier
#   step applies the completion that consumed main's previous publication, and
#   in steady play each fenced step advances exactly one native tick.
# - Experiment Tower and the player-course MicroScenario (worker unfenced):
#   main steps asynchronously and never holds while the worker reports its
#   fence inactive; a world reset out of the lab restores the worker fence.
# - A deliberately slow native owner (600 ms per publication) triggers the
#   500 ms bounded hold: counted stale steps, no freeze; removing the delay
#   restores fenced steps with no further timeout.

const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const STEPS_PER_PHASE: int = 90
const PAUSE_FRAMES: int = 20
const SLOW_DELAY_USEC: int = 600000
const CLI_CHILD_ARGUMENT: String = "--lockstep-cli-child"

var assertions: int = 0
var failures: int = 0


class SlowWorker:
	extends CyberSimulationWorker
	# Test-only stall: the exclusive owner sleeps before each publication.
	var delay_usec: int = 0

	func _publish_snapshot(step_ms: float, paused: bool, interval: int, force_full: bool = false,
			rigid_body_states: PackedFloat32Array = PackedFloat32Array(), rigid_body_epoch: int = 0) -> void:
		var delay: int = delay_usec
		if delay > 0:
			OS.delay_usec(delay)
		super._publish_snapshot(step_ms, paused, interval, force_full, rigid_body_states, rigid_body_epoch)


class LockstepDesktop:
	extends "res://scripts/main.gd"
	var use_cli: bool = false
	var slow_worker: bool = false
	var observed_steps: int = 0
	var stale_steps: int = 0
	var fenced_observed: int = 0
	var unfenced_observed: int = 0
	var held_while_unfenced: int = 0
	var max_publications_per_callback: int = 0
	var transition: bool = true
	var previous_tick: int = -1
	var violations: Array[String] = []

	func _ready() -> void:
		if slow_worker:
			simulation_worker = SlowWorker.new()
		super._ready()

	func lockstep_coupling_requested() -> bool:
		return super.lockstep_coupling_requested() if use_cli else true

	func _violation(message: String) -> void:
		if violations.size() < 12:
			violations.append(message)

	func _publish_physical_body_state() -> void:
		var before: int = simulation_worker.rigid_body_publication()
		super._publish_physical_body_state()
		max_publications_per_callback = maxi(max_publications_per_callback,
			simulation_worker.rigid_body_publication() - before)

	func _physics_process(delta: float) -> void:
		var bridge_ready: bool = rapier_bridge.is_initialized()
		var steps_before: int = rapier_bridge.manual_step_count() if bridge_ready else 0
		var published_before: int = _lockstep_published
		var fenced_before: int = lockstep_main_fenced_steps
		var unfenced_before: int = lockstep_main_unfenced_steps
		var held_before: int = lockstep_main_held_frames
		var timeouts_before: int = lockstep_main_hold_timeouts
		var peek: CyberSimulationSnapshot = simulation_worker.take_latest_snapshot(0)
		super._physics_process(delta)
		if lockstep_main_held_frames > held_before and peek != null and not peek.lockstep_fence_active:
			held_while_unfenced += 1
		if not bridge_ready or rapier_bridge.manual_step_count() == steps_before:
			return
		observed_steps += 1
		if lockstep_main_hold_timeouts > timeouts_before:
			stale_steps += 1
			previous_tick = -1
		elif lockstep_main_unfenced_steps > unfenced_before:
			unfenced_observed += 1
			previous_tick = -1
		elif lockstep_main_fenced_steps == fenced_before + 1:
			fenced_observed += 1
			if _lockstep_applied_publication != published_before:
				_violation("applied publication %d after publishing %d" % [_lockstep_applied_publication, published_before])
			if previous_tick >= 0 and not transition and _lockstep_applied_tick != previous_tick + 1:
				_violation("native tick %d followed %d for one Rapier step" % [_lockstep_applied_tick, previous_tick])
			previous_tick = _lockstep_applied_tick
			transition = false
		else:
			_violation("Rapier stepped without a fenced, unfenced or stale decision")


func _initialize() -> void:
	print("CYBERSAND_CI_POLICY ", JSON.stringify(Watchdogs.identity()))
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("COUPLING_LOCKSTEP_DESKTOP: " + message)


func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await physics_frame
	return false


func steps_reached(desktop: LockstepDesktop, target: int) -> bool:
	return desktop.fenced_observed >= target or desktop.simulation_worker.has_failed()


func fence_reported(desktop: LockstepDesktop, active: bool) -> bool:
	var snapshot: CyberSimulationSnapshot = desktop.simulation_worker.take_latest_snapshot(0)
	return snapshot != null and snapshot.lockstep_fence_active == active


func settle(frames: int) -> void:
	for _frame: int in frames:
		await physics_frame


func make_desktop(cli: bool = false, slow: bool = false) -> LockstepDesktop:
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(LockstepDesktop)
	desktop.use_cli = cli
	desktop.slow_worker = slow
	root.add_child(desktop)
	return desktop


func check_clean(desktop: LockstepDesktop, phase: String) -> void:
	var status: Dictionary = desktop.lockstep_coupling_status()
	expect(not desktop.simulation_worker.has_failed(), phase + ": native owner did not fail")
	expect(desktop.violations.is_empty(), phase + ": violations " + str(desktop.violations))
	expect(desktop.max_publications_per_callback <= 1,
		phase + ": %d body publications in one physics callback" % desktop.max_publications_per_callback)
	expect(desktop.stale_steps == 0 and int(status.main_hold_timeouts) == 0,
		phase + ": no counted stale step " + JSON.stringify(status))
	expect(desktop.held_while_unfenced == 0, phase + ": main held while the worker was unfenced")
	expect(int(status.worker.timeouts) == 0, phase + ": no worker hold timeout")


func default_launch() -> void:
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	desktop.paused = false
	await settle(10)
	expect(not desktop.lockstep_coupling_requested(), "no launch argument requests lockstep")
	expect(not desktop.lockstep_coupling_enabled, "default launch leaves lockstep off")
	expect(not bool(desktop.simulation_worker.lockstep_metrics().enabled), "default worker is not fenced")
	expect(not desktop.rapier_bridge.deterministic_rotation_packing, "default packing is unchanged")
	expect(desktop.lockstep_main_held_frames == 0 and desktop.lockstep_main_fenced_steps == 0
		and desktop.lockstep_main_unfenced_steps == 0, "default physics frames never consult the fence")
	desktop.free()
	await process_frame


func sandbox_and_actor() -> void:
	var desktop: LockstepDesktop = make_desktop()
	expect(desktop.lockstep_coupling_enabled, "opt-in launch enables lockstep before worker start")
	expect(bool(desktop.simulation_worker.lockstep_metrics().enabled), "opt-in worker is fenced")
	desktop.paused = false
	expect(await wait_for(steps_reached.bind(desktop, STEPS_PER_PHASE)), "fenced play advances")

	# Pause: no Rapier step; unpause resumes the fence.
	desktop.paused = true
	await physics_frame
	var paused_steps: int = desktop.observed_steps
	await settle(PAUSE_FRAMES)
	expect(desktop.observed_steps == paused_steps, "paused desktop did not step Rapier")
	desktop.transition = true
	desktop.paused = false
	var target: int = desktop.fenced_observed + STEPS_PER_PHASE
	expect(await wait_for(steps_reached.bind(desktop, target)), "fenced play resumes after pause")

	# World reset: the fence keeps holding across the native replacement.
	var generation: int = int(desktop.latest_snapshot.render_world_generation)
	desktop.transition = true
	desktop.reset_world()
	expect(await wait_for(func() -> bool:
		return desktop.latest_snapshot != null and int(desktop.latest_snapshot.render_world_generation) > generation),
		"reset publishes a replacement world")
	desktop.paused = false
	target = desktop.fenced_observed + STEPS_PER_PHASE
	expect(await wait_for(steps_reached.bind(desktop, target)), "fenced play resumes after reset")
	check_clean(desktop, "sandbox")

	expect(desktop.rapier_bridge.deterministic_rotation_packing, "opt-in packing uses the basis atan2")
	var states: PackedFloat32Array = desktop.pack_rigid_body_states()
	var stride: int = CyberRigidBodyCoupling.INPUT_STRIDE
	var bodies: int = states.size() / stride
	expect(bodies > 0, "packed states contain bodies")
	var expected := PackedFloat32Array()
	for index: int in bodies:
		var t: Transform2D = desktop.rapier_bridge.body_transform(index)
		expected.append(atan2(float(t.x.y), float(t.x.x)))
		expect(states[index * stride + CyberRigidBodyCoupling.INPUT_ROTATION] == expected[index],
			"body %d packed rotation equals float32(double atan2(basis))" % index)
	expect(bool(desktop.recording_runtime_identity().desktop_configuration.lockstep_coupling_enabled),
		"recording identity names the lockstep mode")

	# Articulated physical actor: equipment admission and body publication share
	# one physics callback and must still publish exactly one body sample.
	desktop.transition = true
	expect(desktop.apply_actor_prototype_configuration(&"rapier/runner", &"human", false),
		"articulated human actor accepted")
	expect(await wait_for(func() -> bool:
		return desktop.physical_actor_session != null and desktop._actor_reset_receipt == 0 \
			and desktop._physical_terrain_ready), "actor installed")
	desktop.paused = false
	target = desktop.fenced_observed + STEPS_PER_PHASE
	expect(await wait_for(steps_reached.bind(desktop, target)), "fenced actor play advances")
	expect(desktop.physical_actor_session != null and desktop.physical_actor_session.tick >= 45,
		"actor session advanced under the fence")
	check_clean(desktop, "actor")
	var status: Dictionary = desktop.lockstep_coupling_status()
	expect(desktop.observed_steps == int(status.main_fenced_steps) + desktop.stale_steps + desktop.unfenced_observed,
		"every Rapier step is accounted " + JSON.stringify(status))
	print("COUPLING_LOCKSTEP_DESKTOP sandbox+actor ", JSON.stringify(status), " steps=", desktop.observed_steps)
	desktop.free()
	await process_frame


func actor_ready(desktop: LockstepDesktop) -> bool:
	return (desktop.physical_actor_session != null and desktop._actor_reset_receipt == 0
		and desktop._physical_terrain_ready and desktop.pending_microscenario_apply.is_empty())


func lab_transition() -> void:
	# Entry, active operation and exit of worker-unfenced modes. Leaving a lab
	# with a world reset restores the sandbox without bodies (and the Tower keeps
	# actors disabled), so exit is checked through the worker's reported fence.
	var desktop: LockstepDesktop = make_desktop()
	desktop.paused = false
	expect(await wait_for(steps_reached.bind(desktop, 30)), "fenced play before the lab")

	# Player-course MicroScenario with an actor: Rapier steps while the worker is
	# unfenced, so main must step asynchronously and never hold.
	desktop.transition = true
	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0), "player course accepted")
	expect(await wait_for(func() -> bool:
		return desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.get("micro_active", false)),
		"player course installed")
	expect(desktop.apply_actor_prototype_configuration(&"rapier/runner", &"human", false),
		"course actor accepted")
	expect(await wait_for(actor_ready.bind(desktop)), "course actor installed")
	expect(await wait_for(fence_reported.bind(desktop, false)), "worker reports its fence inactive in the MicroScenario")
	desktop.paused = false
	expect(await wait_for(func() -> bool: return desktop.unfenced_observed >= 60),
		"MicroScenario Rapier steps run unfenced")

	# Experiment Tower, then a world reset back to the sandbox.
	expect(desktop.microscenario_launch("experiment-tower"), "Experiment Tower launch accepted")
	expect(await wait_for(func() -> bool:
		return fence_reported(desktop, false) and not desktop.tower_context.get("micro_active", false)),
		"worker reports its fence inactive in the Tower")
	desktop.paused = false
	await settle(30)
	desktop.reset_world()
	expect(await wait_for(fence_reported.bind(desktop, true)), "fence resumes after leaving the lab")
	desktop.paused = false
	await settle(30)
	check_clean(desktop, "lab")
	print("COUPLING_LOCKSTEP_DESKTOP lab ", JSON.stringify(desktop.lockstep_coupling_status()),
		" unfenced_observed=", desktop.unfenced_observed)
	desktop.free()
	await process_frame


func slow_owner() -> void:
	var desktop: LockstepDesktop = make_desktop(false, true)
	var worker: SlowWorker = desktop.simulation_worker
	expect(desktop.lockstep_coupling_enabled, "slow-owner desktop enabled lockstep")
	worker.delay_usec = SLOW_DELAY_USEC
	desktop.paused = false
	expect(await wait_for(func() -> bool: return desktop.stale_steps >= 3), "stalled owner yields counted stale steps")
	expect(desktop.observed_steps >= 3, "stalled owner never froze Rapier")
	expect(desktop.lockstep_main_hold_timeouts == desktop.stale_steps, "each stale step is one counted timeout")
	var timeouts: int = desktop.lockstep_main_hold_timeouts
	worker.delay_usec = 0
	desktop.transition = true
	await settle(30)
	timeouts = desktop.lockstep_main_hold_timeouts
	var target: int = desktop.fenced_observed + STEPS_PER_PHASE
	expect(await wait_for(steps_reached.bind(desktop, target)), "fence recovers after the stall")
	expect(desktop.lockstep_main_hold_timeouts == timeouts, "no timeout after the stall ended")
	expect(desktop.violations.is_empty(), "slow owner: violations " + str(desktop.violations))
	print("COUPLING_LOCKSTEP_DESKTOP slow ", JSON.stringify(desktop.lockstep_coupling_status()))
	desktop.free()
	await process_frame


func cli_child() -> void:
	var desktop: LockstepDesktop = make_desktop(true)
	expect(desktop.lockstep_coupling_requested(), "--lockstep-coupling requests lockstep")
	expect(desktop.lockstep_coupling_enabled, "real CLI enables lockstep before worker start")
	desktop.paused = false
	expect(await wait_for(steps_reached.bind(desktop, STEPS_PER_PHASE)), "CLI fenced play advances")
	check_clean(desktop, "cli")
	desktop.free()
	await process_frame


func cli_parent() -> void:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://tests/test_coupling_lockstep_desktop.gd",
		"--", "--lockstep-coupling", CLI_CHILD_ARGUMENT], output, true)
	var text: String = "".join(output)
	expect(code == 0 and text.contains("COUPLING_LOCKSTEP_DESKTOP_RESULT") and text.contains("failures=0"),
		"real --lockstep-coupling child passed (exit %d): %s" % [code, text.right(600)])


func run() -> void:
	if CLI_CHILD_ARGUMENT in OS.get_cmdline_user_args():
		await cli_child()
	else:
		await default_launch()
		await sandbox_and_actor()
		await lab_transition()
		await slow_owner()
		cli_parent()
	print("COUPLING_LOCKSTEP_DESKTOP_RESULT assertions=", assertions, " failures=", failures)
	quit(1 if failures else 0)
