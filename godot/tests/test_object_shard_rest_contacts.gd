extends SceneTree

# Actual Rapier negative controls for the sleep repair: changed support must
# still cause a fall, and a new off-centre collision must still wake a body.
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
var checks: int = 0
var failures: int = 0
var bridge: CyberObjectShardPhysicsBridge


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	bridge = Bridge.new()
	_expect(bridge.initialize(901).get("ok", false), "actual Rapier space")
	_expect(bridge.install_terrain([{"id": 0, "session": 901, "revision": 1, "digest": "floor",
		"rectangles": PackedInt32Array([0, 110, 192, 4])}]).get("ok", false), "real static floor")
	var shard: Dictionary = _box(1, 20, 12, Vector2(60, 50))
	_expect(bridge.reserve_body(shard).get("ok", false), "real rigid box reserved")
	_expect(bridge.activate(shard).get("ok", false), "real rigid box activated")
	var rid: RID = bridge.bodies[1].rid
	_expect(_steps(600), "box falls and settles without motion refusal")
	_expect(_sleeping(rid), "rest comes from the solver, never a forced freeze")
	var settled: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(absf(settled.origin.y - 98.0) < 0.1, "exact shape rests on the floor")
	var shape: RID = PhysicsServer2D.body_get_shape(rid, 0)
	shard.geometry_revision = 2
	shard.geometry_digest = "identical-shape-2"
	_expect(bridge.install_geometry(shard).get("ok", false), "identical higher revision accepted")
	_expect(PhysicsServer2D.body_get_shape(rid, 0) == shape, "unchanged occupancy keeps exact collider identity")
	_expect(_sleeping(rid), "identical physics publication does not needlessly wake")
	_expect(_steps(1), "unchanged publication remains operational")
	var unchanged: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(unchanged.is_equal_approx(settled), "unchanged publication preserves sustained rest")
	shard.geometry_revision = 3
	shard.geometry_digest = "mass-only-3"
	_add_unit_cargo(shard, Vector2(1.5, 1.5))
	_expect(bridge.install_geometry(shard).get("ok", false), "independent mass-only publication accepted")
	_expect(PhysicsServer2D.body_get_shape(rid, 0) == shape, "mass-only publication does not reconstruct contacts")
	_expect(not _sleeping(rid), "changed mass wakes for real physical resolution")
	_expect(_steps(600) and _sleeping(rid), "mass update naturally returns to rest")
	var before_erosion: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	shard = _box(1, 20, 8, Vector2(60, 50))
	_add_unit_cargo(shard, Vector2(1.5, 1.5))
	shard.geometry_revision = 4
	shard.geometry_digest = "shorter-contact-4"
	_expect(bridge.install_geometry(shard).get("ok", false), "real support-face geometry shrinks")
	_expect(is_equal_approx(float(bridge.bodies[1].bounds_diagonal),Vector2(20,8).length()),
		"changed geometry refreshes the conservative motion radius without moving its lattice origin")
	_expect(not _sleeping(rid), "changed contact graph must be awake")
	_expect(PhysicsServer2D.body_get_shape(rid, 0) != shape, "changed collider replaces obsolete occupied geometry")
	var after_install: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(after_install.is_equal_approx(before_erosion), "new geometry preserves the material lattice pose")
	_expect(_steps(600), "eroded shape falls through the newly empty volume")
	var after_fall: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(absf(after_fall.origin.y - before_erosion.origin.y - 4.0) < 0.2,
		"obsolete bottom cells do not leave a hidden supporting collider")
	_expect(_sleeping(rid), "real fall after erosion settles naturally")
	var striker: Dictionary = _box(2, 20, 12, Vector2(75, 45))
	_expect(bridge.reserve_body(striker).get("ok", false) and bridge.activate(striker).get("ok", false),
		"new off-centre falling body is physically activated")
	var maximum_motion: float = 0.0
	var maximum_rotation: float = 0.0
	var contact_seen: bool = false
	var woke: bool = false
	var healthy: bool = true
	for tick: int in range(1200):
		if not bridge.step().get("ok", false):
			healthy = false
			break
		var actual: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		maximum_motion = maxf(maximum_motion, actual.origin.distance_to(after_fall.origin))
		maximum_rotation = maxf(maximum_rotation, absf(wrapf(actual.get_rotation() - after_fall.get_rotation(), -PI, PI)))
		woke = woke or not _sleeping(rid)
		var state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(rid)
		contact_seen = contact_seen or (state != null and state.get_contact_count() > 0)
		if tick % 120 == 0:
			await process_frame
	_expect(healthy, "real off-centre collision remains operational")
	_expect(woke, "sleep repair does not freeze the body against future impacts")
	_expect(contact_seen, "actual Rapier contact reporting observes the collision")
	_expect(maximum_motion > 0.05 or maximum_rotation > 0.01, "real collision produces visible physical response")
	_expect(_sleeping(rid) and _sleeping(bridge.bodies[2].rid), "both physical owners return to sustained rest")
	var old_floor_pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(bridge.install_terrain([{"id": 0, "session": 901, "revision": 2, "digest": "lower-floor",
		"rectangles": PackedInt32Array([0, 114, 192, 4])}]).get("ok", false), "changed static terrain installs between steps")
	_expect(_steps(600), "static support removal permits continued real dynamics")
	var lower_floor_pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(absf(lower_floor_pose.origin.y - old_floor_pose.origin.y - 4.0) < 0.3,
		"sleeping object does not retain the obsolete static support")
	_expect(_sleeping(rid), "new static contact eventually rests without forced sleep")
	_expect(bridge.diagnostic_events.size() <= Bridge.MAX_DIAGNOSTIC_EVENTS, "physics event history stays bounded")
	bridge.shutdown()
	print(JSON.stringify({"schema": "objectshard-rest-contact-test-v1", "engine": Engine.get_version_info(),
		"platform": OS.get_name(), "checks": checks, "failures": failures,
		"impact_maximum_translation": maximum_motion, "impact_maximum_rotation": maximum_rotation,
		"actual_contact_seen": contact_seen, "natural_wake_seen": woke}))
	quit(failures)


func _box(id: int, width: int, height: int, position: Vector2) -> Dictionary:
	var mass: float = float(width * height)
	return {"session": 901, "id": id, "generation": 1, "body_generation": 1,
		"transaction": id, "geometry_revision": 1, "geometry_digest": "box-" + str(id),
		"rectangles": PackedInt32Array([0, 0, width, height]), "width": width, "height": height,
		"origin_x": int(position.x), "origin_y": int(position.y), "position_x": position.x, "position_y": position.y,
		"rotation": 0.0, "mass": mass, "com_x": float(width) * 0.5, "com_y": float(height) * 0.5,
		"inertia": mass * float(width * width + height * height) / 12.0}


func _add_unit_cargo(shard: Dictionary, local: Vector2) -> void:
	var old_mass: float = float(shard.mass)
	var old_center := Vector2(float(shard.com_x), float(shard.com_y))
	var new_center: Vector2 = (old_center * old_mass + local) / (old_mass + 1.0)
	shard.inertia = float(shard.inertia) + old_mass * old_center.distance_squared_to(new_center) \
		+ local.distance_squared_to(new_center) + 1.0 / 6.0
	shard.mass = old_mass + 1.0
	shard.com_x = new_center.x
	shard.com_y = new_center.y


func _steps(count: int) -> bool:
	for tick: int in range(count):
		if not bridge.step().get("ok", false):
			return false
	return true


func _sleeping(rid: RID) -> bool:
	return bool(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING))


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
