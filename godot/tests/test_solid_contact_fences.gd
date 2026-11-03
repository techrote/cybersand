extends SceneTree

const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
var checks: int = 0
var failures: Array[String] = []
var bridge: CyberRapierPhysicsBridge
var body: RigidBody2D

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL SOL281 CONTACT FENCES ", message)

func _init() -> void:
	call_deferred("_run")

func _state() -> Array:
	return [PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM),
		PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY),
		PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)]

func _capsule(serial: int = 1, sample: int = 1, tick: int = 19) -> Dictionary:
	var contacts: Array = []
	for x: int in [19, 20, 21]:
		contacts.append({"proxy":1, "face":2, "cell":Vector2i(x, 21),
			"point":Vector2(float(x) + 0.5, 21.25), "normal":Vector2.DOWN,
			"a":Vector2(x + 1.0, 21.25), "b":Vector2(x, 21.25),
			"depth":0.25, "area":0.25, "weight":1.0})
	return {"schema":"cybersand.sol281.sand-contact.v1", "ok":true, "complete":true,
		"token":"23:1", "body_generation":"7", "revision":"31", "sample_serial":sample,
		"tick":tick, "snapshot_serial":serial, "physics_epoch":2,
		"published_usec":Time.get_ticks_usec(), "source_transform":Transform2D(0.0, Vector2(20.5, 20.25)),
		"contacts":contacts}

func _apply(observation: Dictionary, snapshot: int = 1, sample: int = 1,
		current: int = 1, tick: int = 19) -> Dictionary:
	return bridge.apply_solid_sand_contact(observation, 0, snapshot, tick, 31, 2, "23:1", 7,
		sample, current, PackedVector2Array([Vector2.ZERO]), PackedVector2Array([Vector2(4, 2)]))

func _refusal(observation: Dictionary, label: String, snapshot: int = 1,
		sample: int = 1, current: int = 1, tick: int = 19) -> void:
	var before: Array = _state()
	var result: Dictionary = _apply(observation, snapshot, sample, current, tick)
	check(not result.get("accepted", true), label + ": refused")
	check(_state() == before, label + ": zero RID mutation")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	body = RigidBody2D.new()
	body.position = Vector2(20.5, 20.25)
	body.mass = 520.0
	body.inertia = 520.0 * 20.0 / 12.0
	body.gravity_scale = 0.0
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4, 2)
	shape.shape = rectangle
	body.add_child(shape)
	viewport.add_child(body)
	await process_frame
	bridge = Bridge.new()
	var bodies: Array[RigidBody2D] = [body]
	check(bridge.initialize(viewport.world_2d.space, bodies, PackedVector2Array([Vector2(4, 2)])) == OK,
		"real Rapier owner initialized")
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(0, 12))
	for field: String in ["token", "body_generation", "revision", "physics_epoch", "snapshot_serial", "sample_serial", "tick", "complete"]:
		var bad: Dictionary = _capsule()
		bad[field] = "wrong" if field in ["token", "body_generation", "revision"] else (false if field == "complete" else 99)
		_refusal(bad, "wrong " + field)
	var missing: Dictionary = _capsule()
	missing.erase("tick")
	_refusal(missing, "incomplete publication")
	var future: Dictionary = _capsule()
	future.published_usec = Time.get_ticks_usec() + 10000000
	_refusal(future, "future timestamp")
	_refusal(_capsule(), "old source sample", 1, 1, 4)
	var malformed: Dictionary = _capsule()
	malformed.contacts.append({"proxy":1})
	_refusal(malformed, "malformed final contact")
	var first: Dictionary = _apply(_capsule())
	check(first.get("accepted", false), "complete current publication accepted")
	check(float(first.get("actual_energy_after", INF)) <= float(first.get("energy_before", -1.0)) * 1.0001,
		"actual Rapier energy bound")
	_refusal(_capsule(), "duplicate snapshot and sample")
	_refusal(_capsule(2), "new snapshot repeats sample", 2)
	var second: Dictionary = _apply(_capsule(3, 2, 20), 3, 2, 2, 20)
	check(second.get("accepted", false), "forward source sample accepted")
	_refusal(_capsule(4, 1, 21), "nonconsecutive old sample", 4, 1, 2, 21)
	_refusal(_capsule(5, 3, 18), "tick regression", 5, 3, 3, 18)
	var pose := Transform2D(0.0, Vector2(24, 20.25))
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, pose)
	_refusal(_capsule(6, 3, 21), "current geometry moved away", 6, 3, 3, 21)
	bridge.shutdown()
	viewport.queue_free()
	await process_frame
	var report := {"schema":"cybersand.sol281.contact-fences.v1", "platform":OS.get_name(),
		"checks":checks, "failures":failures}
	print("SOL281_CONTACT_FENCES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
