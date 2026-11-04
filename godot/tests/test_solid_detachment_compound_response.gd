extends SceneTree

const C = preload("res://scripts/rigid_body_coupling.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL SOL281 RESPONSE ", message)

func _init() -> void:
	call_deferred("_run")

func _body(parent: Node, x: float) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.position = Vector2(x, 40.0)
	body.mass = 2.0
	body.inertia = 2.0
	body.gravity_scale = 0.0
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2, 2)
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body

func _state(body: RigidBody2D) -> Array:
	return [PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM),
		PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY),
		PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)]

func _with_sample(records: PackedFloat32Array, serial: int) -> PackedFloat32Array:
	var result: PackedFloat32Array = records.duplicate()
	for offset: int in range(0, result.size(), C.RESULT_STRIDE):
		result[offset + C.RESULT_SAMPLE_SERIAL] = serial
	return result

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var ordinary := _body(viewport, 30.0)
	var compound := _body(viewport, 80.0)
	await process_frame
	var bridge := CyberRapierPhysicsBridge.new()
	var bodies: Array[RigidBody2D] = [ordinary, compound]
	check(bridge.initialize(viewport.world_2d.space, bodies, PackedVector2Array([Vector2(2, 2), Vector2(2, 2)])) == OK,
		"actual Rapier owner initializes two equivalent bodies")
	for body: RigidBody2D in bodies:
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(1, 4))
	bridge.pack_body_states()
	var result := PackedFloat32Array([1, 0.5, 0.25, -0.1, -0.2, 1, 0, 1, 1])
	check(bridge.apply_cellular_results(1, result) == 1, "ordinary current-main response accepted")
	var one_center := PackedVector2Array([Vector2.ZERO])
	var one_mass := PackedFloat32Array([2.0])
	var compound_result: Dictionary = bridge.apply_compound_cellular_results(2, result, 1, 1, one_center, one_mass, 3.0, 0.5)
	check(compound_result.get("accepted", false), "one-proxy shared response accepted")
	var a: Array = _state(ordinary)
	var b: Array = _state(compound)
	check((a[0] as Transform2D).origin.is_equal_approx((b[0] as Transform2D).origin - Vector2(50, 0)),
		"common correction gives equivalent translated poses")
	check((a[1] as Vector2).is_equal_approx(b[1]) and float(a[2]) == float(b[2]),
		"common opposing-velocity zeroing and impulse preserve ordinary response")
	check((b[1] as Vector2).x < 1.0 and (b[1] as Vector2).y < 4.0,
		"correction removes opposing velocity before applying impulse")
	var pair := PackedFloat32Array([1, 0, -0.5, 0, 0, 1, 1, 0, 2,
		2, 0, 0.5, 0, 0, 1, 1, 0, 2])
	var centers := PackedVector2Array([Vector2(-1, 0), Vector2(1, 0)])
	var masses := PackedFloat32Array([1, 1])
	var old_state: Array = _state(compound)
	var mixed: PackedFloat32Array = pair.duplicate()
	mixed[C.RESULT_STRIDE + C.RESULT_SAMPLE_SERIAL] = 3
	check(not bridge.apply_compound_cellular_results(3, mixed, 1, 3, centers, masses, 3.0, 0.5).get("accepted", true),
		"mixed proxy samples refused atomically")
	check(_state(compound) == old_state, "mixed sample refuses without motion or force")
	var duplicate: PackedFloat32Array = pair.duplicate()
	duplicate[C.RESULT_STRIDE + C.RESULT_BODY_ID] = 1
	check(not bridge.apply_compound_cellular_results(3, duplicate, 1, 2, centers, masses, 3.0, 0.5).get("accepted", true),
		"duplicate proxy cannot multiply impulse")
	check(_state(compound) == old_state, "duplicate proxy refusal has no Rapier write")
	check(not bridge.apply_compound_cellular_results(3, pair, 1, 12, centers, masses, 3.0, 0.5).get("accepted", true),
		"stale complete proxy sample refused")
	check(_state(compound) == old_state, "stale refusal has no Rapier write")
	var angular: Dictionary = bridge.apply_compound_cellular_results(3, pair, 1, 2, centers, masses, 3.0, 0.5)
	check(angular.get("accepted", false) and int(angular.get("impulse_applications", 0)) == 2,
		"two distinct proxy impulses reach their actual offsets")
	var rotated: Array = _state(compound)
	check((rotated[1] as Vector2).is_equal_approx(old_state[1]), "opposing proxy forces have zero net linear impulse")
	check(float(rotated[2]) > float(old_state[2]) + 0.1, "Rapier computes nonzero torque from off-centre impulses")
	check(not bridge.apply_compound_cellular_results(4, pair, 1, 2, centers, masses, 3.0, 0.5).get("accepted", true),
		"sample is applied only once across different snapshots")
	check(_state(compound) == rotated, "duplicate sample never repeats torque")
	check(not bridge.apply_compound_cellular_results(2, pair, 1, 2, centers, masses, 3.0, 0.5).get("accepted", true),
		"old publication refused")
	var bad: PackedFloat32Array = pair.duplicate()
	bad[1] = NAN
	check(not bridge.apply_compound_cellular_results(5, bad, 1, 3, centers, masses, 3.0, 0.5).get("accepted", true),
		"nonfinite copied response refused")
	check(_state(compound) == rotated, "all malformed/refused packets retain real body state")
	# The same geometry is now rotated: proxy impulses must follow the real
	# rotated rectangle centres, not their unrotated local coordinates.
	var turned: Transform2D = rotated[0]
	turned = Transform2D(PI * 0.5, turned.origin)
	PhysicsServer2D.body_set_state(compound.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, turned)
	var rotated_pair := PackedFloat32Array([1, 0.5, 0, 0, 0, 1, 1, 0, 3,
		2, -0.5, 0, 0, 0, 1, 1, 0, 3])
	var turned_before: Array = _state(compound)
	check(bridge.apply_compound_cellular_results(6, rotated_pair, 1, 3, centers, masses, 3.0, 0.5).get("accepted", false),
		"rotated offset response admitted")
	check(float(_state(compound)[2]) > float(turned_before[2]) + 0.1,
		"rotated proxy locations generate the correct nonzero torque")
	var aged := PackedFloat32Array([1, 0, 0, 1, 1, 1, 0, 1, 4,
		2, 0, 0, 1, 1, 1, 0, 1, 4])
	var age_before: Array = _state(compound)
	var age_result: Dictionary = bridge.apply_compound_cellular_results(7, aged, 1, 6, centers, masses, 3.0, 0.5)
	check(age_result.get("accepted", false) and age_result.get("correction") == Vector2.ZERO,
		"compound uses the current-main one-tick correction age limit")
	check(_state(compound) == age_before, "old correction does not move or zero velocity")
	check(not bridge.apply_compound_cellular_results(8, rotated_pair, 1, 6, centers, masses, 3.0, 0.5).get("accepted", true),
		"new publication cannot replay an older still-recent sample")
	check(_state(compound) == age_before, "older sample refusal does not reapply torque")
	check(not bridge.apply_compound_cellular_results(9, aged, 1, 6, centers, masses, 3.0, 0.5).get("accepted", true),
		"N N-minus-one N sequence cannot replay sample N")
	check(bridge.apply_compound_cellular_results(10, _with_sample(rotated_pair, 5), 1, 6, centers, masses, 3.0, 0.5).get("accepted", false),
		"next forward sample remains admissible after a replay refusal")
	bridge.reset_result_tracking()
	check(bridge.apply_compound_cellular_results(11, _with_sample(rotated_pair, 999999), 1, 999999, centers, masses, 3.0, 0.5).get("accepted", false),
		"last pre-wrap sample admitted after explicit owner reset")
	check(bridge.apply_compound_cellular_results(12, _with_sample(rotated_pair, 0), 1, 0, centers, masses, 3.0, 0.5).get("accepted", false),
		"serial wrap advances forward exactly once")
	var wrap_state: Array = _state(compound)
	check(not bridge.apply_compound_cellular_results(13, _with_sample(rotated_pair, 999999), 1, 0, centers, masses, 3.0, 0.5).get("accepted", true),
		"pre-wrap sample cannot move authority backwards")
	check(not bridge.apply_compound_cellular_results(14, _with_sample(rotated_pair, 0), 1, 0, centers, masses, 3.0, 0.5).get("accepted", true),
		"duplicate wrapped sample refused after stale packet")
	check(_state(compound) == wrap_state, "both wrap refusals preserve exact actual Rapier state")
	bridge.shutdown()
	viewport.queue_free()
	await process_frame
	print("SOL281_COMPOUND_RESPONSE ", JSON.stringify({"checks":checks,"failures":failures,"platform":OS.get_name()}))
	quit(0 if failures.is_empty() else 1)
