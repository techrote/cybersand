extends SceneTree

# Focused migration fixture. It proves that the sandbox owns Rapier's step and
# that pausing the cellular sandbox also stops rigid-body integration.
const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const POSITION_EPSILON: float = 0.0001
const RUNNING_PHYSICS_FRAMES: int = 12
const PAUSED_PHYSICS_FRAMES: int = 4
const THIN_FLOOR_TEST_FRAMES: int = 18

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox: Control = MAIN_SCENE.instantiate() as Control
	root.add_child(sandbox)
	await process_frame

	var bridge: CyberRapierPhysicsBridge = sandbox.rapier_bridge
	_expect(bridge != null and bridge.is_initialized(), "manual Rapier bridge did not initialize")
	if bridge == null or not bridge.is_initialized():
		await _finish(sandbox)
		return

	var start_position: Vector2 = bridge.body_transform(0).origin
	for _frame: int in range(RUNNING_PHYSICS_FRAMES):
		await physics_frame
	var falling_position: Vector2 = bridge.body_transform(0).origin
	_expect(
		falling_position.y > start_position.y + POSITION_EPSILON,
		"manual Rapier stepping did not advance the falling body"
	)
	_expect(
		bridge.manual_step_count() >= RUNNING_PHYSICS_FRAMES,
		"manual Rapier step counter did not advance once per physics frame"
	)
	_expect(
		bridge.pack_body_states().size()
		== 3 * CyberRigidBodyCoupling.INPUT_STRIDE,
		"bridge did not publish all three packed rigid-body samples"
	)
	_expect(
		bridge.hard_surface_shape_count() > 0,
		"pixel-derived Rapier hard-surface collider was not built"
	)

	# The spawn ledge is only one cellular pixel deep. Shape CCD must keep a fast
	# barrel above y=172 without relying on delayed cellular corrections.
	bridge.reset_body(0, Vector2(124.0, 150.0), 0.0)
	PhysicsServer2D.body_set_state(
		sandbox.test_rigid_body_1.get_rid(),
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
		Vector2(0.0, 240.0)
	)
	for _frame: int in range(THIN_FLOOR_TEST_FRAMES):
		await physics_frame
	var landed_position: Vector2 = bridge.body_transform(0).origin
	var landed_velocity: Vector2 = PhysicsServer2D.body_get_state(
		sandbox.test_rigid_body_1.get_rid(),
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY
	)
	_expect(
		landed_position.y <= 166.0,
		"shape-CCD barrel crossed the one-pixel spawn floor"
	)
	_expect(
		absf(landed_velocity.y) < 4.0,
		"zero-bounce hard-surface contact retained excessive vertical velocity"
	)

	sandbox.paused = true
	var paused_position: Vector2 = bridge.body_transform(0).origin
	var paused_step_count: int = bridge.manual_step_count()
	for _frame: int in range(PAUSED_PHYSICS_FRAMES):
		await physics_frame
	var after_pause_position: Vector2 = bridge.body_transform(0).origin
	_expect(
		after_pause_position.distance_squared_to(paused_position)
		<= POSITION_EPSILON * POSITION_EPSILON,
		"paused sandbox still advanced the Rapier body"
	)
	_expect(
		bridge.manual_step_count() == paused_step_count,
		"paused sandbox still called Rapier space_step"
	)

	await _finish(sandbox)


func _finish(sandbox: Control) -> void:
	sandbox.queue_free()
	await process_frame
	if _failures == 0:
		print("Rapier2D manual-step coupling fixture passed")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
