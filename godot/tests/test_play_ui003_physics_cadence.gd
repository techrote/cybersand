extends SceneTree

# PLAY-UI-003 / #268: actual native+Rapier shared-course regression. A real
# Rapier body assembly visits AND leaves the first authored checkpoint during
# completed manual physics steps with the desktop render callback disabled.
# One test-only hook override is the negative control (old render-only path).
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const Lap = preload("res://scripts/playable_course_lap.gd")
const RIG: StringName = &"jetbarrel"
const DELTA: float = 1.0 / 60.0
const EXIT_POSE: Vector2 = Vector2(275.0, 280.0)

var desktop: Control
var assertions: int = 0
var failures: int = 0
var real_host_stepped_visits: int = 0
var negative_control_runs: int = 0
var reset_epoch_floor: int = -1


class CadenceHarness:
	extends "res://scripts/main.gd"

	# Same headless-only keyboard focus seam as the accepted five-rig fixture.
	func actor_keyboard_allowed() -> bool:
		return (not paused and actor_prototypes_allowed()
			and _physical_terrain_ready and _actor_reset_receipt == 0
			and not actor_prototype_panel.visible)


class RenderOnlyHarness:
	extends "res://scripts/main.gd"

	func actor_keyboard_allowed() -> bool:
		return (not paused and actor_prototypes_allowed()
			and _physical_terrain_ready and _actor_reset_receipt == 0
			and not actor_prototype_panel.visible)

	# Remove only the NEW completed-physics callback. Retain the exact
	# production _process HUD/native-clock path, Rapier bodies and native worker.
	func _record_completed_playable_course_step() -> void:
		pass


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_UI003_PHYSICS: " + message)


func wait_for(predicate: Callable, timeout_ms: int = 30000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return false


func course_installed() -> bool:
	return (desktop != null
		and desktop.pending_microscenario_apply.is_empty()
		and desktop.tower_context.get("micro_active", false)
		and desktop.microscenario_definition.get("id", "") == Catalogue.PLAYER_COURSE_ID)


func actor_installed() -> bool:
	return (course_installed() and desktop._actor_reset_receipt == 0
		and desktop.physical_actor_session != null
		and desktop.physical_rig_id == RIG
		and desktop._physical_terrain_ready and desktop.latest_snapshot != null
		and int(desktop.latest_snapshot.rigid_body_epoch) == desktop._physical_epoch)


func playable() -> bool:
	return (actor_installed() and not desktop._actor_input_rearm
		and desktop.physical_actor_session.tick >= 3
		and desktop._playable_course_progress.rig_id == RIG)


func replacement_ready() -> bool:
	return (actor_installed() and desktop._physical_epoch > reset_epoch_floor
		and desktop._playable_course_progress.rig_id == RIG
		and not desktop._playable_course_progress.started)


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func move_actual_rapier_assembly(target: Vector2) -> void:
	# Fixture-only placement via the production Rapier bridge. Translate ALL
	# articulated parts together, preserving existing joints and their offsets.
	# The subsequent pose is accepted only if a real space_step+complete_step
	# produced it; never feed a synthetic actor observation to the lap tracker.
	var current: Vector2 = desktop.physical_actor_session.observation(0).get("position", Vector2.INF)
	var shift: Vector2 = target - current
	var physical_bodies: Array[RigidBody2D] = desktop.physical_actor_session.bodies()
	expect(physical_bodies.size() >= 2 and current.is_finite() and shift.is_finite(),
		"test-only Rapier body assembly is finite and genuinely articulated")
	if not shift.is_finite():
		return
	for index: int in range(physical_bodies.size()):
		var pose: Transform2D = desktop.rapier_bridge.body_transform(index)
		desktop.rapier_bridge.reset_body(index, pose.origin + shift, pose.get_rotation())


func retire_desktop() -> void:
	key(KEY_D, false)
	if is_instance_valid(desktop):
		desktop.queue_free()
	await process_frame
	await process_frame
	desktop = null


func exercise(negative: bool) -> void:
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(RenderOnlyHarness if negative else CadenceHarness)
	root.add_child(desktop)
	await process_frame
	expect(desktop.worker_start_error == OK and desktop.simulation_worker._thread.is_started(),
		"real shared native owner started")
	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
		"actual authored course admitted through normal desktop selector")
	var installed: bool = await wait_for(Callable(self, "course_installed"), 60000)
	expect(installed, "authored native course was acknowledged")
	if not installed:
		await retire_desktop()
		return

	expect(desktop.apply_actor_prototype_configuration(&"rapier/jetbarrel", &"human", false),
		"real F5 SetP Jet Barrel admitted without a second World")
	var actor_ready: bool = await wait_for(Callable(self, "actor_installed"))
	expect(actor_ready, "actual actor, native epoch and hard terrain are ready")
	if not actor_ready:
		await retire_desktop()
		return

	desktop.paused = false
	var running: bool = await wait_for(Callable(self, "playable"))
	expect(running, "native/Rapier host advances and input is neutrally rearmed")
	if not running:
		await retire_desktop()
		return

	# Disallow both automatic callbacks. Only explicit invocations below may
	# run actual main-thread Rapier steps. There are NO render callbacks between
	# visiting and leaving the first checkpoint.
	desktop.set_process(false)
	desktop.set_physics_process(false)
	var session = desktop.physical_actor_session
	var tracker = desktop._playable_course_progress
	var gate: Vector2 = Course.checkpoints(RIG)[0]
	var initial_text: String = desktop.course_timing_label.text
	expect(tracker.target_index == 0 and initial_text.begins_with("GATES 0 / 4"),
		"starting HUD is rendered once, but no gate was visited")

	# Use the production local keyboard/lease path to begin the clock.
	var commands_before: int = session.accepted_commands
	key(KEY_D, true)
	desktop._publish_physical_keyboard_input()
	desktop._physics_process(DELTA)
	key(KEY_D, false)
	desktop._physics_process(DELTA)
	expect(tracker.started and session.accepted_commands > commands_before,
		"real admitted human input starts native-tick lap timing")
	var before_visit_tick: int = session.tick
	var before_visit_step: int = desktop.rapier_bridge.manual_step_count()

	move_actual_rapier_assembly(gate)
	desktop._physics_process(DELTA)
	var entered: Vector2 = session.observation(0).get("position", Vector2.INF)
	var entered_real: bool = (entered.is_finite()
		and entered.distance_to(gate) <= Lap.GATE_RADIUS)
	expect(entered_real and session.tick == before_visit_tick + 1
		and desktop.rapier_bridge.manual_step_count() == before_visit_step + 1,
		"real completed Rapier space step, not a synthetic pose, visits the authored gate")
	expect(tracker.target_index == (0 if negative else 1),
		"physics-only visit is credited only when the completed-step hook exists")

	move_actual_rapier_assembly(EXIT_POSE)
	desktop._physics_process(DELTA)
	var exited: Vector2 = session.observation(0).get("position", Vector2.INF)
	expect(exited.is_finite() and exited.distance_to(gate) > 2.0 * Lap.GATE_RADIUS,
		"next real completed Rapier step leaves the checkpoint entirely")
	expect(desktop.course_timing_label.text == initial_text,
		"no render callback occurred during the physical gate visit and exit")
	expect(tracker.target_index == (0 if negative else 1),
		"leaving the gate does not repeat or erase physical checkpoint credit")

	# A single delayed HUD callback sees only the EXIT pose. The negative
	# control cannot recover the missed gate; the fixed route already has it.
	desktop._update_playable_course_progress()
	expect(tracker.target_index == (0 if negative else 1),
		"late rendering never invents a transient gate crossing")
	expect(desktop.course_timing_label.text.begins_with(
		"GATES 0 / 4" if negative else "GATES 1 / 4"),
		"HUD consumes existing physics progress without updating it twice")
	var credited: int = tracker.target_index
	var prior_elapsed: int = tracker.elapsed_ticks
	desktop._update_playable_course_progress()
	expect(tracker.target_index == credited and tracker.elapsed_ticks == prior_elapsed,
		"duplicate render/native source tick does not double-count progress or time")

	if negative:
		negative_control_runs += 1
	else:
		real_host_stepped_visits += 1
		var prior_tick: int = session.tick
		desktop.paused = true
		move_actual_rapier_assembly(Course.checkpoints(RIG)[1])
		desktop._physics_process(DELTA)
		expect(session.tick == prior_tick and tracker.target_index == 1,
			"pause cannot complete a Rapier step or credit a new gate")
		desktop._update_playable_course_progress()
		expect(tracker.target_index == 1,
			"paused HUD refresh never turns a moved fixture into an admitted step")
		var old_epoch: int = desktop._physical_epoch
		reset_epoch_floor = old_epoch
		desktop.set_process(true)
		desktop.set_physics_process(true)
		desktop.microscenario_reset()
		var reset_ok: bool = await wait_for(Callable(self, "replacement_ready"))
		reset_epoch_floor = -1
		expect(reset_ok and tracker.target_index == 0 and tracker.elapsed_ticks == 0,
			"real native+Rapier reset invalidates the prior session and lap")
		if reset_ok:
			expect(not tracker.bind(RIG, old_epoch,
				int(desktop.latest_snapshot.render_world_generation),
				int(desktop.latest_snapshot.tick_index)),
				"older real actor epoch cannot resurrect progress after reset")

	await retire_desktop()


func run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		expect(false, "native engine is required for this actual-host test")
		print("PLAY_UI003_PHYSICS_RESULT ", JSON.stringify({"assertions":assertions,"failures":failures}))
		quit(1)
		return
	await exercise(false)
	await exercise(true)
	print("PLAY_UI003_PHYSICS_RESULT ", JSON.stringify({
		"assertions": assertions, "failures":failures,
		"real_host_completed_step_visits":real_host_stepped_visits,
		"negative_control_render_only":negative_control_runs,
		"model_only":false,
		"test_only_rapier_fixture_reposition":true,
		"source":"original-course+existing-native-worker+real-rapier",
		"rendered_fps_measured":false,
		"physical_gamepad_qualified":false,
		"lifecycle_soak_cycles":0
	}))
	quit(0 if failures == 0 else 1)
