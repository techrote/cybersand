extends SceneTree

const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const Session = preload("res://scripts/solid_detachment_session.gd")

class ReadbackFaultBridge:
	extends Bridge
	# Inject only the copied readback AFTER real, finite Rapier impulses. This
	# exercises failure handling, not a claim that Rapier produces these faults.
	var fault_field: String = ""
	var fault_value: Variant = null
	var readback_calls: int = 0
	func _read_solid_contact_result(body_rid: RID, velocity: Vector2, omega: float,
			mass: float, inertia: float) -> Dictionary:
		readback_calls += 1
		var result: Dictionary = super._read_solid_contact_result(body_rid, velocity, omega, mass, inertia)
		if not fault_field.is_empty():
			result[fault_field] = fault_value
		return result

var checks: int = 0
var failures: Array[String] = []
var bridge: CyberRapierPhysicsBridge
var body: RigidBody2D
var readback_cases: Array[String] = []

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

func _failed_session(response: Dictionary, label: String) -> void:
	# Exercise the real session latch and physics_step entry, while the existing
	# test remains owner of this actual body/bridge. No native World is replaced.
	var session = Session.new()
	session.active = true
	session.physics_paused = false
	session.body = body
	session.bridge = bridge
	session._contact_metrics = {"response_accepts":0, "response_refusals":{},
		"response_failures":{}, "energy_violations":0}
	session._record_contact_response(response)
	check(session._failed and session.physics_paused and not session.last_error.is_empty(),
		label + ": post-application failure latches the actual session pause")
	check(session._contact_metrics.response_accepts == 0 and session._contact_metrics.response_refusals.is_empty()
		and session._contact_metrics.response_failures.get(response.outcome, 0) == 1
		and session._contact_metrics.energy_violations == 1,
		label + ": failed application is neither accepted nor a harmless refusal")
	var steps: int = bridge.manual_step_count()
	var state: Array = _state()
	session.set_paused(false)
	session.physics_step()
	check(session.physics_paused and bridge.manual_step_count() == steps and _state() == state,
		label + ": unpause cannot bypass the latch or advance Rapier")
	session.bridge = null
	session.body = null
	session.active = false

func _readback_failures() -> void:
	var injected: ReadbackFaultBridge = bridge as ReadbackFaultBridge
	var faults: Array[Dictionary] = [
		{"id":"velocity_x_nan", "field":"actual_velocity_after", "value":Vector2(NAN, 0)},
		{"id":"velocity_y_inf", "field":"actual_velocity_after", "value":Vector2(0, INF)},
		{"id":"velocity_negative_inf", "field":"actual_velocity_after", "value":Vector2(-INF, 0)},
		{"id":"omega_nan", "field":"actual_omega_after", "value":NAN},
		{"id":"omega_inf", "field":"actual_omega_after", "value":INF},
		{"id":"omega_negative_inf", "field":"actual_omega_after", "value":-INF},
		{"id":"energy_nan", "field":"actual_energy_after", "value":NAN},
		{"id":"energy_inf", "field":"actual_energy_after", "value":INF},
		{"id":"energy_negative_inf", "field":"actual_energy_after", "value":-INF},
		{"id":"momentum_nan", "field":"actual_momentum_change", "value":Vector2(NAN, 0)},
		{"id":"angular_momentum_inf", "field":"actual_angular_momentum_change", "value":INF},
		{"id":"finite_energy_increase", "field":"actual_energy_after", "value":37450.0},
	]
	for index: int in range(faults.size()):
		var fault: Dictionary = faults[index]
		var label: String = str(fault.id)
		injected.fault_field = fault.field
		injected.fault_value = fault.value
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM,
			Transform2D(0.0, Vector2(20.5, 20.25)))
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(0, 12))
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
		var serial: int = 10 + index
		var tick: int = 30 + index
		var result: Dictionary = _apply(_capsule(serial, serial, tick), serial, serial, serial, tick)
		var expected: String = "NonDissipativeContactReadback" if label == "finite_energy_increase" else "NonFiniteContactReadback"
		check(not result.get("accepted", true) and result.get("failed", false)
			and result.get("outcome") == expected and not result.get("readback_valid", true),
			label + ": invalid backend readback fails after application")
		check(result.get("mutation_may_have_occurred", false) and int(result.get("impulse_applications", 0)) > 0,
			label + ": failure retains possible-mutation semantics")
		var actual_velocity: Vector2 = _state()[1]
		check(actual_velocity.is_finite() and actual_velocity != Vector2(0, 12),
			label + ": actual Rapier impulse executed before copied readback injection")
		var state_before_retry: Array = _state()
		var reads_before_retry: int = injected.readback_calls
		var retry: Dictionary = _apply(_capsule(serial, serial, tick), serial, serial, serial, tick)
		check(not retry.get("accepted", true) and retry.get("outcome") == "DuplicateOrOldContact"
			and not retry.get("failed", false), label + ": consumed sample is rejected before reapplication")
		check(_state() == state_before_retry and injected.readback_calls == reads_before_retry,
			label + ": duplicate neither mutates Rapier nor reaches backend readback")
		_failed_session(result, label)
		readback_cases.append(label)
	injected.fault_field = ""
	injected.fault_value = null
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(0, 12))
	var finite: Dictionary = _apply(_capsule(30, 30, 50), 30, 30, 30, 50)
	check(finite.get("accepted", false) and finite.get("readback_valid", false)
		and not finite.get("failed", false), "finite real readback remains accepted after injection is disabled")

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
	bridge = ReadbackFaultBridge.new()
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
	_readback_failures()
	bridge.shutdown()
	viewport.queue_free()
	await process_frame
	var report := {"schema":"cybersand.sol281.contact-fences.v1", "platform":OS.get_name(),
		"checks":checks, "failures":failures, "readback_failure_cases":readback_cases,
		"readback_failure_scope":"copied readback injection after finite real Rapier impulses; actual session fail-stop, not backend fault generation"}
	print("SOL281_CONTACT_FENCES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
