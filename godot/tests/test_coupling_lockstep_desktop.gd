extends SceneTree

# Opt-in desktop lockstep (owner decision 2026-11-06; COUPLING-LOCKSTEP-001
# amendment_002). Runs the real main.tscn + CyberSimulationWorker + main-thread
# Rapier path. Default launch: lockstep and deterministic packing stay off.
# Opt-in launch: every Rapier step applies the native completion that consumed
# main's previous body publication, through play, pause and a world reset, with
# no counted stale step; packed rotations are double atan2 of the basis.

const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const STEPS_PER_PHASE: int = 90
const PAUSE_FRAMES: int = 20

var assertions: int = 0
var failures: int = 0


class LockstepDesktop:
	extends "res://scripts/main.gd"
	var request_lockstep: bool = true
	var observed_steps: int = 0
	var stale_steps: int = 0
	var fence_violations: Array[String] = []

	func lockstep_coupling_requested() -> bool:
		return request_lockstep

	func _physics_process(delta: float) -> void:
		var bridge_ready: bool = rapier_bridge.is_initialized()
		var steps_before: int = rapier_bridge.manual_step_count() if bridge_ready else 0
		var published_before: int = _lockstep_published
		var fenced_before: int = lockstep_main_fenced_steps
		var timeouts_before: int = lockstep_main_hold_timeouts
		super._physics_process(delta)
		if not bridge_ready or rapier_bridge.manual_step_count() == steps_before:
			return
		observed_steps += 1
		if lockstep_main_hold_timeouts > timeouts_before:
			stale_steps += 1
		elif lockstep_main_fenced_steps != fenced_before + 1 or _lockstep_applied_publication != published_before:
			if fence_violations.size() < 8:
				fence_violations.append("step applied publication %d after publishing %d" % [
					_lockstep_applied_publication, published_before])


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
	return desktop.observed_steps >= target or desktop.simulation_worker.has_failed()


func default_launch() -> void:
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	desktop.paused = false
	for _frame: int in 10:
		await physics_frame
	expect(not desktop.lockstep_coupling_enabled, "default launch leaves lockstep off")
	expect(not bool(desktop.simulation_worker.lockstep_metrics().enabled), "default worker is not fenced")
	expect(not desktop.rapier_bridge.deterministic_rotation_packing, "default packing is unchanged")
	expect(desktop.lockstep_main_held_frames == 0 and desktop.lockstep_main_fenced_steps == 0,
		"default physics frames never hold")
	desktop.free()
	await process_frame


func lockstep_launch() -> void:
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(LockstepDesktop)
	root.add_child(desktop)
	expect(desktop.lockstep_coupling_enabled, "opt-in launch enables lockstep before worker start")
	expect(bool(desktop.simulation_worker.lockstep_metrics().enabled), "opt-in worker is fenced")
	desktop.paused = false
	expect(await wait_for(steps_reached.bind(desktop, STEPS_PER_PHASE)), "fenced play advances")

	# Pause: no Rapier step, publications continue; unpause resumes the fence.
	desktop.paused = true
	await physics_frame
	var paused_steps: int = desktop.observed_steps
	for _frame: int in PAUSE_FRAMES:
		await physics_frame
	expect(desktop.observed_steps == paused_steps, "paused desktop did not step Rapier")
	desktop.paused = false
	expect(await wait_for(steps_reached.bind(desktop, paused_steps + STEPS_PER_PHASE)),
		"fenced play resumes after pause")

	# World reset: the fence keeps holding across the native replacement.
	var generation: int = int(desktop.latest_snapshot.render_world_generation)
	var reset_steps: int = desktop.observed_steps
	desktop.reset_world()
	expect(await wait_for(func() -> bool:
		return desktop.latest_snapshot != null and int(desktop.latest_snapshot.render_world_generation) > generation),
		"reset publishes a replacement world")
	desktop.paused = false
	expect(await wait_for(steps_reached.bind(desktop, reset_steps + STEPS_PER_PHASE)),
		"fenced play resumes after reset")

	var status: Dictionary = desktop.lockstep_coupling_status()
	expect(not desktop.simulation_worker.has_failed(), "native owner did not fail")
	expect(desktop.fence_violations.is_empty(), "fence violations " + str(desktop.fence_violations))
	expect(desktop.stale_steps == 0 and int(status.main_hold_timeouts) == 0,
		"no counted stale step " + JSON.stringify(status))
	expect(desktop.observed_steps == int(status.main_fenced_steps) + desktop.stale_steps,
		"every Rapier step is accounted " + JSON.stringify(status))
	expect(int(status.worker.ticks) >= int(status.main_fenced_steps), "worker ticked for every fenced step")

	expect(desktop.rapier_bridge.deterministic_rotation_packing, "opt-in packing uses the basis atan2")
	var states: PackedFloat32Array = desktop.pack_rigid_body_states()
	var stride: int = CyberRigidBodyCoupling.INPUT_STRIDE
	var bodies: int = states.size() / stride
	expect(bodies > 0, "packed states contain bodies")
	var packed_rotation := PackedFloat32Array()
	for index: int in bodies:
		var t: Transform2D = desktop.rapier_bridge.body_transform(index)
		packed_rotation.append(atan2(float(t.x.y), float(t.x.x)))
		expect(states[index * stride + CyberRigidBodyCoupling.INPUT_ROTATION] == packed_rotation[index],
			"body %d packed rotation equals float32(double atan2(basis))" % index)
	expect(bool(desktop.recording_runtime_identity().desktop_configuration.lockstep_coupling_enabled),
		"recording identity names the lockstep mode")
	print("COUPLING_LOCKSTEP_DESKTOP status ", JSON.stringify(status), " steps=", desktop.observed_steps)
	desktop.free()
	await process_frame


func run() -> void:
	await default_launch()
	await lockstep_launch()
	print("COUPLING_LOCKSTEP_DESKTOP_RESULT assertions=", assertions, " failures=", failures)
	quit(1 if failures else 0)
