extends SceneTree

# Real Rapier bodies, no cellular terrain: analytic wrench application and
# protocol/lifetime refusal are isolated from the native contact evaluator.
var failures: int = 0
var assertions: int = 0
var viewport: SubViewport
var bodies: Array[RigidBody2D] = []
var bridge: CyberRapierPhysicsBridge


func _init() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("GCR protocol: " + message)


func close_to(actual: float, expected: float, message: String) -> void:
	check(absf(actual - expected) <= 0.0001 * maxf(1.0, absf(expected)), message + " actual=" + str(actual) + " expected=" + str(expected))


func reset() -> void:
	for index: int in range(bodies.size()):
		bridge.reset_body(index, Vector2(100 + 40 * index, 100), 0.0)
	bridge.reset_result_tracking()
	bridge.refresh_all_states()


func response(states: PackedFloat64Array, impulse: Vector2 = Vector2(4, 2), angular: float = 3.0) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for index: int in range(bodies.size()):
		var offset: int = index * CyberRigidBodyCoupling.GCR_INPUT_STRIDE
		result.append_array(PackedFloat64Array([index + 1, impulse.x, impulse.y, 0, 0, 0, 0, 0,
			states[offset + CyberRigidBodyCoupling.INPUT_SAMPLE_SERIAL], angular,
			states[offset + CyberRigidBodyCoupling.GCR_INPUT_COM_X], states[offset + CyberRigidBodyCoupling.GCR_INPUT_COM_Y], 1, states[offset + CyberRigidBodyCoupling.GCR_INPUT_SESSION]]))
	return result


func velocity(index: int = 0) -> Vector2:
	return PhysicsServer2D.body_get_state(bodies[index].get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)


func omega(index: int = 0) -> float:
	return float(PhysicsServer2D.body_get_state(bodies[index].get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))


func move(index: int, delta: Vector2, rotation: float = 0.0) -> void:
	var transform: Transform2D = PhysicsServer2D.body_get_state(bodies[index].get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
	transform.origin += delta
	transform = Transform2D(transform.get_rotation() + rotation, transform.origin)
	PhysicsServer2D.body_set_state(bodies[index].get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, transform)


func unchanged(message: String) -> void:
	for index: int in range(bodies.size()):
		check(velocity(index) == Vector2.ZERO and omega(index) == 0.0, message + " body=" + str(index))


func refused(result: PackedFloat64Array, reason: String, snapshot: int = 1) -> void:
	check(bridge.apply_gcr_results(snapshot, result) == 0, "refused " + reason)
	check(not bool(bridge.gcr_application_diagnostics().accepted), "refusal receipt " + reason)
	unchanged("atomic " + reason)


func analytic() -> void:
	reset()
	var states: PackedFloat64Array = bridge.pack_gcr_body_states()
	check(states.size() == 2 * CyberRigidBodyCoupling.GCR_INPUT_STRIDE, "Float64 input stride")
	var direct: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(bodies[0].get_rid())
	close_to(states[11], 13.0, "actual authored inertia")
	check(absf(states[11] - bodies[0].mass * (8.0 * 8.0 + 14.0 * 14.0) / 12.0) > 1.0, "inertia is not AABB-derived")
	var expected_com: Vector2 = direct.transform * direct.center_of_mass_local
	check(Vector2(states[12], states[13]) == expected_com, "actual offset world COM")
	check(expected_com != direct.transform.origin, "authored part COM offset exercised")
	close_to(states[14], 0.37, "existing server friction")
	close_to(states[15], bridge.fixed_delta(), "fixed dt")
	var serial: int = int(states[10])
	var next: PackedFloat64Array = bridge.pack_gcr_body_states()
	check(int(next[10]) == (serial + 1) % bridge.SAMPLE_SERIAL_LIMIT, "one serial increment per GCR sample")
	# Age one applies the same .8 scale to both parts of a wrench.
	check(bridge.apply_gcr_results(1, response(states)) == 2, "analytic accepted pair")
	close_to(velocity().x, 4.0 * 0.8 * direct.inverse_mass, "linear J/m")
	close_to(velocity().y, 2.0 * 0.8 * direct.inverse_mass, "linear y J/m")
	close_to(omega(), 3.0 * 0.8 * (1.0 / 13.0), "angular L/I")
	var before: Vector2 = velocity()
	var before_omega: float = omega()
	check(bridge.apply_gcr_results(2, response(states)) == 0, "duplicate sample")
	check(velocity() == before and omega() == before_omega, "duplicate cannot mint impulse")
	var legacy := PackedFloat32Array([1, 4, 2, 0, 0, 0, 0, 0, serial])
	check(bridge.apply_cellular_results(3, legacy) == 0, "legacy cannot reapply accepted GCR sample")
	check(velocity() == before and omega() == before_omega, "no mixed-path double impulse")
	for mirror: float in [-1.0, 1.0]:
		reset()
		states = bridge.pack_gcr_body_states()
		check(bridge.apply_gcr_results(1, response(states, Vector2(4 * mirror, 2), 3 * mirror)) == 2, "mirror application")
		close_to(omega(), 3.0 * mirror * (1.0 / 13.0), "mirrored torque sign")
		close_to(velocity().x, 4.0 * mirror * direct.inverse_mass, "mirrored linear sign")
	reset()
	states = bridge.pack_gcr_body_states()
	check(bridge.apply_gcr_results(1, response(states, Vector2.ZERO, 0)) == 0, "zero no-contact wrench")
	check(bool(bridge.gcr_application_diagnostics().accepted), "zero wrench still consumes sample")
	unchanged("no-contact")


func translation() -> void:
	reset()
	var states: PackedFloat64Array = bridge.pack_gcr_body_states()
	move(0, Vector2(0.25, 0))
	var results: PackedFloat64Array = response(states, Vector2(0, 4), 2)
	results[4] = -0.125 # Separately accounted correction also changes final COM.
	var direct: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(bodies[0].get_rid())
	check(bridge.apply_gcr_results(1, results) == 2, "translated wrench accepted")
	# L(newCOM)=2 + (-.25,+.125) cross (0,4) = 1.
	close_to(omega(), (1.0 / 13.0), "moment translated to final current COM")
	close_to(velocity().y, 4 * direct.inverse_mass, "translation leaves J unchanged")
	var diagnostic: Dictionary = bridge.gcr_application_diagnostics()
	close_to(float(diagnostic.bodies[0].translated_angular_impulse), 1.0, "translated angular ledger")
	var copy: Dictionary = bridge.gcr_application_diagnostics()
	copy.bodies[0].angular_impulse = 999
	check(float(bridge.gcr_application_diagnostics().bodies[0].angular_impulse) == 1.0, "diagnostic copy owns its values")


func invalid_batches() -> void:
	for malformed: String in ["nan", "infinite", "fractional-id", "fractional-sample", "version", "count", "body", "duplicate-body", "com", "layout", "future", "session", "fractional-session"]:
		reset()
		var states: PackedFloat64Array = bridge.pack_gcr_body_states()
		var result: PackedFloat64Array = response(states)
		# Corrupt the second row: the first row must never be partially applied.
		match malformed:
			"nan": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE + 1] = NAN
			"infinite": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE + 9] = INF
			"fractional-id": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE] = 1.5
			"fractional-sample": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE + 8] += 0.5
			"version": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE + 12] = 2
			"count": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE + 5] = -1
			"body": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE] = 3
			"duplicate-body": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE] = 1
			"com": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE + 10] += 0.125
			"layout": result.resize(result.size() - 1)
			"session": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE + 13] += 1
			"fractional-session": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE + 13] += 0.5
			"future": result[CyberRigidBodyCoupling.GCR_RESULT_STRIDE + 8] += 1
		refused(result, malformed)
		check(bridge.apply_gcr_results(1, response(states)) == 2, "refusal retains retriable serial " + malformed)
	reset()
	var states: PackedFloat64Array = bridge.pack_gcr_body_states()
	var result: PackedFloat64Array = response(states)
	bridge.pack_gcr_body_states()
	bridge.pack_gcr_body_states()
	refused(result, "age-two")
	for motion: String in ["translation", "rotation"]:
		reset()
		states = bridge.pack_gcr_body_states()
		if motion == "translation": move(1, Vector2(0.501, 0))
		else: move(1, Vector2.ZERO, 0.1)
		refused(response(states), "geometry " + motion)
	reset()
	states = bridge.pack_gcr_body_states()
	bridge.reset_result_tracking()
	refused(response(states), "reset tracking")
	reset()
	states = bridge.pack_gcr_body_states()
	bridge.reset_body(1, Vector2(140, 100), 0)
	refused(response(states), "reset body/exclusion epoch")
	reset()
	states = bridge.pack_gcr_body_states()
	var legacy := PackedFloat32Array([1, 4, 2, 0, 0, 0, 0, 0, states[10]])
	check(bridge.apply_cellular_results(1, legacy) == 1, "legacy first accepted")
	var before: Vector2 = velocity()
	check(bridge.apply_gcr_results(2, response(states)) == 0, "GCR cannot reapply legacy sample")
	check(velocity() == before and velocity(1) == Vector2.ZERO and omega() == 0, "mixed-path refusal is atomic")


func lifetime_and_owner() -> void:
	reset()
	var states: PackedFloat64Array = bridge.pack_gcr_body_states()
	var prior_session: float = states[CyberRigidBodyCoupling.GCR_INPUT_SESSION]
	var independent := CyberRapierPhysicsBridge.new()
	check(independent.initialize(viewport.world_2d.space, bodies, PackedVector2Array([Vector2(8, 14), Vector2(8, 14)])) == OK, "fresh bridge initializes")
	var independent_states: PackedFloat64Array = independent.pack_gcr_body_states()
	check(independent_states[CyberRigidBodyCoupling.GCR_INPUT_SESSION] > prior_session, "fresh bridge has distinct process session")
	check(independent.apply_gcr_results(1, response(states)) == 0 and independent.gcr_application_diagnostics().refusal == "session", "fresh bridge refuses predecessor result")
	independent.shutdown()
	PhysicsServer2D.space_set_active(viewport.world_2d.space, false)
	var old_result: PackedFloat64Array = response(states)
	bridge.reset_result_tracking()
	var fresh: PackedFloat64Array = bridge.pack_gcr_body_states()
	check(fresh[CyberRigidBodyCoupling.GCR_INPUT_SESSION] > prior_session, "reset advances exact session identity")
	# Reuse the current sample/pose deliberately: only the session fence can
	# distinguish this reset response from a freshly generated valid result.
	for index: int in range(bodies.size()):
		old_result[index * CyberRigidBodyCoupling.GCR_RESULT_STRIDE + CyberRigidBodyCoupling.RESULT_SAMPLE_SERIAL] = fresh[CyberRigidBodyCoupling.INPUT_SAMPLE_SERIAL]
	refused(old_result, "cross-session identical pose")
	check(bridge.gcr_application_diagnostics().refusal == "session", "explicit cross-session refusal")
	var thread := Thread.new()
	check(thread.start(bridge.pack_gcr_body_states) == OK, "off-main probe starts")
	var off_main: Variant = thread.wait_to_finish()
	check(off_main is PackedFloat64Array and off_main.is_empty(), "off-main pack refuses before live backend reads")
	reset()
	# The old age arithmetic's wrap remains a serial concern, separate from the
	# new nonwrapping lifecycle identity.
	bridge._sample_serial = bridge.SAMPLE_SERIAL_LIMIT - 2
	states = bridge.pack_gcr_body_states()
	fresh = bridge.pack_gcr_body_states()
	check(int(states[10]) == bridge.SAMPLE_SERIAL_LIMIT - 1 and int(fresh[10]) == 0, "sample wraps once")
	check(bridge.apply_gcr_results(1, response(states)) == 2, "age-one wrench valid across sample wrap")
	reset()
	bridge.reset_body(0, Vector2(100, 100), PI / 2)
	states = bridge.pack_gcr_body_states()
	close_to(states[12], 100.5, "rotated offset COM world x")
	close_to(states[13], 101.25, "rotated offset COM world y")
	reset()
	bodies[0].inertia = 0.0
	bridge.step()
	states = bridge.pack_gcr_body_states()
	var backend_inertia: float = float(PhysicsServer2D.body_get_param(bodies[0].get_rid(), PhysicsServer2D.BODY_PARAM_INERTIA))
	check(backend_inertia > 0.0 and not states.is_empty(), "backend automatic inertia is available after mass update")
	close_to(states[11], backend_inertia, "automatic inertia is copied from server")
	PhysicsServer2D.body_apply_torque_impulse(bodies[0].get_rid(), backend_inertia)
	close_to(omega(), 1.0, "automatic actual inertia has correct torque units")
	bodies[0].inertia = 13.0
	reset()
	states = bridge.pack_gcr_body_states()
	# Locked rotation has zero effective inverse inertia and is explicitly
	# outside this initial finite-inertia evaluator; it cannot be relabelled.
	bodies[0].lock_rotation = true
	check(bridge.pack_gcr_body_states().is_empty(), "locked body refuses GCR input")
	bodies[0].lock_rotation = false
	# Exhaustion refuses instead of aliasing an earlier process session.
	CyberRapierPhysicsBridge._next_gcr_session_id = CyberRigidBodyCoupling.GCR_MAX_SESSION
	bridge.reset_result_tracking()
	check(bridge.pack_gcr_body_states().is_empty(), "session exhaustion refuses without wrapping")


func _run() -> void:
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(320, 240)
	root.add_child(viewport)
	for index: int in range(2):
		var body := RigidBody2D.new()
		body.mass = 2.0
		body.inertia = 13.0
		body.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
		body.center_of_mass = Vector2(1.25, -0.5)
		body.gravity_scale = 0.0
		body.linear_damp = 0.0
		body.angular_damp = 0.0
		body.position = Vector2(100 + 40 * index, 100)
		var material := PhysicsMaterial.new()
		material.friction = 0.37
		body.physics_material_override = material
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(8, 14)
		collision.shape = rectangle
		body.add_child(collision)
		viewport.add_child(body)
		bodies.append(body)
	await process_frame
	bridge = CyberRapierPhysicsBridge.new()
	check(bridge.initialize(viewport.world_2d.space, bodies, PackedVector2Array([Vector2(8, 14), Vector2(8, 14)])) == OK, "real Rapier bridge initializes")
	if bridge.is_initialized():
		bridge.enable_diagnostics()
		bridge.step()
		analytic()
		translation()
		invalid_batches()
		lifetime_and_owner()
		bridge.shutdown()
	viewport.queue_free()
	await process_frame
	print("GCR_PROTOCOL assertions=", assertions, " failures=", failures)
	quit(1 if failures else 0)
