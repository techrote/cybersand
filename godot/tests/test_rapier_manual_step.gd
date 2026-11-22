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

	# Isolate the bridge's alternate install API after the ordinary physics
	# checks. No Main callback may replace terrain during this direct sequence.
	sandbox.set_process(false)
	sandbox.set_physics_process(false)
	_check_interleaved_terrain_install(bridge)
	await _finish(sandbox)


func _server_chunk_geometry(bridge: CyberRapierPhysicsBridge) -> Array:
	var result: Array = []
	for body: RID in bridge._hard_surface_chunk_bodies:
		var rectangles: Dictionary = {}
		var body_pose: Transform2D = PhysicsServer2D.body_get_state(body,PhysicsServer2D.BODY_STATE_TRANSFORM)
		for index: int in range(PhysicsServer2D.body_get_shape_count(body)):
			var shape: RID = PhysicsServer2D.body_get_shape(body,index)
			_expect(PhysicsServer2D.shape_get_type(shape)==PhysicsServer2D.SHAPE_RECTANGLE,
				"chunk install attached a non-rectangle shape")
			var half: Vector2 = PhysicsServer2D.shape_get_data(shape)
			var pose: Transform2D = body_pose*PhysicsServer2D.body_get_shape_transform(body,index)
			var low: Vector2 = pose.origin-half
			var size: Vector2 = half*2.0
			_expect(pose.x.is_equal_approx(Vector2.RIGHT) and pose.y.is_equal_approx(Vector2.DOWN) \
				and low.is_equal_approx(low.round()) and size.is_equal_approx(size.round()),
				"chunk install changed exact axis-aligned native geometry")
			var key: String = str([roundi(low.x),roundi(low.y),roundi(size.x),roundi(size.y)])
			rectangles[key] = int(rectangles.get(key,0))+1
		result.append(rectangles)
	return result


func _check_interleaved_terrain_install(bridge: CyberRapierPhysicsBridge) -> void:
	bridge.rebuild_hard_surface_colliders_from_rectangles(PackedInt32Array())
	var packet := PackedInt32Array([2,4,8,12,8,8,1,1,72,8,1,1])
	_expect(bridge.queue_hard_surface_chunk_snapshot(packet),"two-chunk terrain packet was refused")
	bridge.process_hard_surface_collider_budget(1,0)
	var pending: int = bridge.pending_hard_surface_chunks()
	var cursor: int = bridge._pending_hard_surface_scan_cursor
	var partial: Array = _server_chunk_geometry(bridge)
	_expect(pending==1,"partial terrain install did not retain one pending chunk")
	_expect(bridge.queue_hard_surface_chunk_snapshot(packet),"identical pending terrain packet was refused")
	_expect(bridge.pending_hard_surface_chunks()==pending and bridge._pending_hard_surface_scan_cursor==cursor,
		"identical pending terrain packet restarted completed chunk progress")
	_expect(_server_chunk_geometry(bridge)==partial,"identical pending packet changed actual server geometry")
	# A synchronous alternate-format install supersedes the partial packet.
	# Requeueing that packet must now restore both chunks, including the chunk
	# already visited before the alternate install replaced its server shapes.
	bridge.rebuild_hard_surface_colliders_from_rectangles_chunked(
		PackedInt32Array([16,8,1,1,80,8,1,1]),128,64)
	var synchronous: Array = _server_chunk_geometry(bridge)
	_expect(synchronous==[{"[16, 8, 1, 1]":1},{"[80, 8, 1, 1]":1}],
		"synchronous terrain replacement did not reach actual server shapes")
	var pending_after_synchronous: int = bridge.pending_hard_surface_chunks()
	_expect(bridge.queue_hard_surface_chunk_snapshot(packet),"terrain packet requeue after synchronous install was refused")
	for _call: int in range(2):
		if bridge.pending_hard_surface_chunks()==0: break
		bridge.process_hard_surface_collider_budget(1,0)
	var installed: Array = _server_chunk_geometry(bridge)
	_expect(bridge.pending_hard_surface_chunks()==0,"requeued two-chunk install did not finish within two chunk budgets")
	_expect(installed==[{"[8, 8, 1, 1]":1},{"[72, 8, 1, 1]":1}],
		"partial packet then synchronous replacement caused requeue to certify stale server geometry")
	print("RAPIER_TERRAIN_INTERLEAVE ",JSON.stringify({
		"bridge_sha256":FileAccess.get_sha256("res://scripts/rapier_physics_bridge.gd"),
		"test_sha256":FileAccess.get_sha256("res://tests/test_rapier_manual_step.gd"),
		"pending_before_duplicate":pending,"cursor_before_duplicate":cursor,
		"partial_server_geometry":partial,"synchronous_server_geometry":synchronous,
		"pending_after_synchronous":pending_after_synchronous,"final_server_geometry":installed,
		"installed_packet_certificate_matches":bridge._installed_hard_surface_chunk_snapshot==packet}))


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
