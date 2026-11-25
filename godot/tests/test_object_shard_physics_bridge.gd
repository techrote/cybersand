extends SceneTree

const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
var failures: int = 0
var checks: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var bridge = Bridge.new()
	_expect(bridge.initialize(601).get("ok", false), "private Rapier space initialized")
	if not bridge.space.is_valid():
		_finish(bridge)
		return
	var floor: Dictionary = {"id": 0, "session": 601, "revision": 1, "digest": "17",
		"rectangles": PackedInt32Array([0, 90, 192, 3])}
	var terrain: Dictionary = bridge.install_terrain([floor])
	_expect(terrain.get("ok", false) and terrain.get("installed", false), "terrain ACK follows actual installation")
	_expect(terrain.chunks[0].digest == "17", "terrain receipt names installed content")
	var stale: Dictionary = floor.duplicate(true)
	stale.digest = "18"
	_expect(not bridge.install_terrain([stale]).get("ok", false), "same revision cannot change terrain content")
	var rectangles := PackedInt32Array()
	for x: int in range(9):
		rectangles.append_array(PackedInt32Array([x * 2, 0, 1, 2]))
	var shard: Dictionary = {"id": 1, "session": 601, "generation": 1, "body_generation": 1,
		"transaction": 9, "geometry_revision": 1, "geometry_digest": "1001", "rectangles": rectangles,
		"origin_x": 30, "origin_y": 12, "position_x": 30.0, "position_y": 12.0,
		"rotation": 0.0, "mass": 18.0, "com_x": 8.5, "com_y": 1.0, "inertia": 487.5}
	var reserved: Dictionary = bridge.reserve_body(shard)
	_expect(reserved.get("ok", false) and int(reserved.shape_count) == 9, "nine shapes admitted independently of old eight-shape cap")
	var rid: RID = bridge.bodies[1].rid
	_expect(_mass_matches(rid, shard), "reserved static body retains explicit unit-cell mass, COM and inertia")
	_expect(PhysicsServer2D.body_get_collision_layer(rid) == 0 and PhysicsServer2D.body_get_collision_mask(rid) == 0,
		"reserved body is noncolliding")
	var initial: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	for tick: int in range(6):
		bridge.step()
	var held: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(initial.is_equal_approx(held), "reservation does not fall before activation")
	_expect(bridge.activate(shard).get("ok", false), "specific reserved body activated")
	_expect(_mass_matches(rid, shard), "activation preserves declared unit-cell mass, COM and inertia")
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.2)
	for tick: int in range(20):
		bridge.step()
	var moving: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(moving.origin.y > initial.origin.y + 0.5, "actual Rapier moves the body")
	_expect(absf(moving.get_rotation()) > 0.01, "actual Rapier rotates the body")
	var pose_before: Transform2D = moving
	var angular_before: float = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	var velocity_before: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	shard.geometry_revision = 2
	shard.geometry_digest = "1002"
	shard.rectangles = PackedInt32Array([0, 0, 1, 2, 16, 0, 2, 2])
	shard.mass = 6.0
	shard.com_x = 11.5
	shard.inertia = 366.5
	_expect(bridge.install_geometry(shard).get("ok", false), "mutable exact islands installed between steps")
	var pose_after: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(pose_before.is_equal_approx(pose_after), "geometry update preserves stable lattice pose")
	_expect(_mass_matches(rid, shard), "changed-COM geometry installs exact updated unit-cell mass properties")
	var world_com_shift: Vector2 = pose_before.basis_xform(Vector2(3.0, 0.0))
	var expected_velocity: Vector2 = velocity_before + Vector2(-world_com_shift.y, world_com_shift.x) * angular_before
	_expect(expected_velocity.is_equal_approx(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)),
		"COM change preserves co-moving lattice velocity without an extra impulse")
	_expect(is_equal_approx(angular_before, float(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))),
		"geometry update does not duplicate an angular impulse")
	_expect(PhysicsServer2D.body_get_shape_count(rid) == 2, "hole remains an exact empty space")
	for tick: int in range(180):
		bridge.step()
	var landed: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(landed.origin.y < 92.0, "shape CCD prevents catastrophic floor penetration")
	var poses: Array = bridge.sample_poses()
	_expect(poses.size() == 1 and int(poses[0].geometry_revision) == 2 and int(poses[0].session) == 601,
		"pose carries exact current generation and geometry")
	shard.geometry_revision = 3
	shard.geometry_digest = "1003"
	shard.rectangles = PackedInt32Array()
	shard.mass = 0.0
	var retired: Dictionary = bridge.install_geometry(shard)
	_expect(retired.get("ok", false) and retired.get("retired_body", false) and bridge.bodies.is_empty(),
		"last skeleton retires RID without creating zero-mass body")
	_expect(bridge.initialize(602).get("ok", false), "controlled session reset creates independent space")
	_expect(not bridge.reserve_body(shard).get("ok", false), "obsolete session cannot acquire a new body")
	var crossing: Dictionary = {"id": 2, "session": 602, "generation": 1, "body_generation": 1,
		"transaction": 10, "geometry_revision": 1, "geometry_digest": "2001",
		"rectangles": PackedInt32Array([0, 0, 2, 2]), "origin_x": 64, "origin_y": 32,
		"position_x": 64.0, "position_y": 32.0, "rotation": PI - 0.01,
		"mass": 4.0, "com_x": 1.0, "com_y": 1.0, "inertia": 8.0 / 3.0}
	_expect(bridge.reserve_body(crossing).get("ok", false) and bridge.activate(crossing).get("ok", false),
		"actual Rapier body reserved immediately before rotation wrap")
	var crossing_rid: RID = bridge.bodies[2].rid
	PhysicsServer2D.body_set_param(crossing_rid, PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE, 0.0)
	PhysicsServer2D.body_set_state(crossing_rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 1.2)
	var before_wrap: float = float(bridge.sample_poses()[0].rotation)
	_expect(bridge.step().get("ok", false), "small legitimate step through positive pi stays admitted")
	var after_wrap: Array = bridge.sample_poses()
	var wrapped_pose: Transform2D = PhysicsServer2D.body_get_state(crossing_rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(wrapped_pose.get_rotation() < 0.0 and after_wrap.size() == 1 and float(after_wrap[0].rotation) > PI
		and absf(float(after_wrap[0].rotation) - before_wrap) < 0.03,
		"pose publication unwraps the actual backend angle at each manual step")
	PhysicsServer2D.body_set_state(crossing_rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, -1.2)
	_expect(bridge.step().get("ok", false) and float(bridge.sample_poses()[0].rotation) < PI,
		"reverse small step through negative pi retains continuous history")
	var steps_before_refusal: int = bridge.steps
	PhysicsServer2D.body_set_state(crossing_rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 250.0)
	var ambiguous: Dictionary = bridge.step()
	_expect(not ambiguous.get("ok", false) and str(ambiguous.get("outcome", "")) == "UnresolvedCompleteRotation"
		and bridge.steps == steps_before_refusal and bridge.sample_poses().is_empty(),
		"unresolved high-speed rotation is held before stepping and cannot publish an aliased pose")
	_finish(bridge)


func _mass_matches(rid: RID, expected: Dictionary) -> bool:
	var com: Vector2 = PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
	return is_equal_approx(float(PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_MASS)), float(expected.mass)) \
		and is_equal_approx(float(PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_INERTIA)), float(expected.inertia)) \
		and com.is_equal_approx(Vector2(float(expected.com_x), float(expected.com_y)))


func _finish(bridge: CyberObjectShardPhysicsBridge) -> void:
	bridge.shutdown()
	print(JSON.stringify({"schema": "objectshard-physics-bridge-test-v1", "checks": checks,
		"failures": failures, "engine": Engine.get_version_info(), "platform": OS.get_name()}))
	quit(failures)
