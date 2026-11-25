class_name CyberObjectShardPhysicsBridge
extends RefCounted

# A separate, revisioned material-body adapter. This does not relax the immutable
# Workbench roster contract. Only this main-thread owner creates or frees RIDs.
const RAPIER: StringName = &"RapierPhysicsServer2D"
const MAX_BODIES: int = 3
const MAX_SHAPES_PER_BODY: int = 512
const MAX_TERRAIN_CHUNKS: int = 64
const FIXED_DELTA: float = 1.0 / 60.0

var session: int = 0
var space: RID
var bodies: Dictionary = {}
var terrain: Dictionary = {}
var pose_serial: int = 0
var steps: int = 0
var motion_refused: bool = false
var last_error: String = ""
var timings: Dictionary = {"geometry_install_usec": 0, "terrain_install_usec": 0,
	"rapier_step_usec": 0, "rapier_flush_usec": 0, "pose_copy_usec": 0,
	"geometry_install_max_usec": 0, "terrain_install_max_usec": 0}


func begin_frame() -> void:
	# Event costs belong to the frame that performed them. Several installations
	# may occur during one handoff; accumulate those, never repeat the last event.
	for key: String in ["geometry_install_usec", "terrain_install_usec", "rapier_step_usec", "rapier_flush_usec", "pose_copy_usec"]:
		timings[key] = 0


func initialize(incarnation: int) -> Dictionary:
	shutdown()
	if not ClassDB.class_exists(RAPIER) or str(ProjectSettings.get_setting(
		"physics/2d/physics_engine", "")) != "Rapier2D":
		return _refuse("RapierUnavailable")
	if incarnation <= 0:
		return _refuse("InvalidSession")
	session = incarnation
	space = PhysicsServer2D.space_create()
	if not space.is_valid():
		return _refuse("SpaceReservationFailed")
	PhysicsServer2D.space_set_active(space, false)
	return {"ok": true, "session": session}


func install_terrain(chunks: Array) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not space.is_valid() or chunks.size() > MAX_TERRAIN_CHUNKS:
		return _refuse("TerrainCapacity")
	# Validate the complete publication before replacing any installed chunk.
	for chunk: Dictionary in chunks:
		if int(chunk.get("session", session)) != session or not _valid_rectangles(chunk.get("rectangles", []), 4096):
			return _refuse("InvalidTerrainPublication")
		var previous: Dictionary = terrain.get(int(chunk.id), {})
		if not previous.is_empty() and (int(chunk.revision) < int(previous.revision) or (
			int(chunk.revision) == int(previous.revision) and str(chunk.digest) != str(previous.digest))):
			return _refuse("StaleTerrainPublication")
	var receipts: Array = []
	for chunk: Dictionary in chunks:
		var id: int = int(chunk.id)
		var previous: Dictionary = terrain.get(id, {})
		if previous.is_empty() or int(previous.revision) != int(chunk.revision):
			var reserved: Dictionary = _new_compound(chunk.rectangles, Transform2D.IDENTITY, false)
			if not reserved.get("ok", false):
				return _refuse("TerrainInstallationFailed")
			reserved["revision"] = int(chunk.revision)
			reserved["digest"] = str(chunk.digest)
			terrain[id] = reserved
			if not previous.is_empty():
				_destroy_compound(previous)
		var installed: Dictionary = terrain[id]
		# Read actual backend shape count. Merely queuing the snapshot is never an ACK.
		if PhysicsServer2D.body_get_shape_count(installed.rid) != installed.shapes.size():
			return _refuse("TerrainReadbackFailed")
		if not _readback_shapes(installed.rid, chunk.rectangles):
			return _refuse("TerrainContentReadbackFailed")
		receipts.append({"id": id, "revision": installed.revision, "digest": installed.digest})
	_record("terrain_install", Time.get_ticks_usec() - started)
	return {"ok": true, "session": session, "chunks": receipts, "installed": true}


func reserve_body(shard: Dictionary) -> Dictionary:
	if not space.is_valid() or int(shard.get("session", session)) != session:
		return _refuse("RetiredSession")
	var id: int = int(shard.id)
	if bodies.has(id):
		var existing: Dictionary = bodies[id]
		if int(existing.generation) == int(shard.generation) and str(existing.geometry_digest) == str(shard.geometry_digest):
			return _body_receipt(shard, existing)
		return _refuse("BodyIdentityConflict")
	if bodies.size() >= MAX_BODIES or not _valid_rectangles(shard.rectangles, MAX_SHAPES_PER_BODY):
		return _refuse("ShapeCapacity")
	var pose := Transform2D(float(shard.get("rotation", 0.0)), Vector2(
		float(shard.get("position_x", shard.origin_x)), float(shard.get("position_y", shard.origin_y))))
	var reserved: Dictionary = _new_compound(shard.rectangles, pose, true)
	if not reserved.get("ok", false):
		return reserved
	reserved["generation"] = int(shard.generation)
	reserved["body_generation"] = int(shard.get("body_generation", shard.generation))
	reserved["geometry_revision"] = int(shard.geometry_revision)
	reserved["geometry_digest"] = str(shard.geometry_digest)
	reserved["transaction"] = int(shard.transaction)
	reserved["active"] = false
	reserved["rotation"] = float(shard.get("rotation", 0.0))
	reserved["wrapped_rotation"] = pose.get_rotation()
	reserved["com"] = Vector2(float(shard.com_x), float(shard.com_y))
	if not _set_mass(reserved, shard):
		_destroy_compound(reserved)
		return _refuse("InvalidMass")
	if not _readback_shapes(reserved.rid, shard.rectangles):
		_destroy_compound(reserved)
		return _refuse("ShapeReadbackFailed")
	bodies[id] = reserved
	return _body_receipt(shard, reserved)


func activate(shard: Dictionary) -> Dictionary:
	var body: Dictionary = _matching(shard)
	if body.is_empty():
		return _refuse("StaleBody")
	if str(body.geometry_digest) != str(shard.geometry_digest):
		return _refuse("StaleGeometry")
	PhysicsServer2D.body_set_mode(body.rid, PhysicsServer2D.BODY_MODE_RIGID)
	PhysicsServer2D.body_set_collision_layer(body.rid, 1)
	PhysicsServer2D.body_set_collision_mask(body.rid, 1)
	PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING, false)
	body["active"] = true
	var result: Dictionary = _body_receipt(shard, body)
	result["activated"] = PhysicsServer2D.body_get_mode(body.rid) == PhysicsServer2D.BODY_MODE_RIGID \
		and _readback_mass(body.rid, float(shard.mass), Vector2(float(shard.com_x), float(shard.com_y)), float(shard.inertia))
	result["ok"] = result.activated
	return result


func install_geometry(shard: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var body: Dictionary = _matching(shard)
	if body.is_empty():
		return _refuse("StaleBody")
	var revision: int = int(shard.geometry_revision)
	if revision < int(body.geometry_revision):
		return _refuse("StaleGeometry")
	if revision == int(body.geometry_revision):
		if str(shard.geometry_digest) != str(body.geometry_digest):
			return _refuse("GeometryDigestConflict")
		return _body_receipt(shard, body)
	if not _valid_rectangles(shard.rectangles, MAX_SHAPES_PER_BODY):
		return _refuse("ShapeCapacity")
	if shard.rectangles.is_empty():
		# Inventory remains native-owned in Draining. A zero-mass rigid body is
		# neither constructed nor used as a material-lifetime handle.
		_destroy_compound(body)
		bodies.erase(int(shard.id))
		return {"ok": true, "retired_body": true, "session": session,
			"id": int(shard.id), "generation": int(shard.generation), "geometry_revision": revision}
	var fresh: Array[RID] = _reserve_shapes(shard.rectangles)
	if fresh.size() != shard.rectangles.size() / 4:
		return _refuse("ShapeReservationFailed")
	var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var angular: float = float(PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
	var sleeping: bool = bool(PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING))
	var old_com: Vector2 = body.com
	var old_shapes: Array = body.shapes
	PhysicsServer2D.body_clear_shapes(body.rid)
	_add_shapes(body.rid, fresh, shard.rectangles)
	body["shapes"] = fresh
	if not _set_mass(body, shard) or not _readback_shapes(body.rid, shard.rectangles):
		# Invalid native mass is an integration fault after backend mutation;
		# keep the material owner paused, never label this a harmless refusal.
		for shape: RID in old_shapes:
			PhysicsServer2D.free_rid(shape)
		return {"ok": false, "quarantine": true, "outcome": "MassInstallationFailed"}
	var new_com := Vector2(float(shard.com_x), float(shard.com_y))
	var shift: Vector2 = pose.basis_xform(new_com - old_com)
	PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM, pose)
	PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
		velocity + Vector2(-shift.y, shift.x) * angular)
	PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, angular)
	PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING, sleeping)
	for shape: RID in old_shapes:
		PhysicsServer2D.free_rid(shape)
	body["geometry_revision"] = revision
	body["geometry_digest"] = str(shard.geometry_digest)
	body["com"] = new_com
	_record("geometry_install", Time.get_ticks_usec() - started)
	return _body_receipt(shard, body)


func sample_poses() -> Array:
	var started: int = Time.get_ticks_usec()
	var result: Array = []
	if motion_refused:
		return result
	pose_serial += 1
	var ids: Array = bodies.keys()
	ids.sort()
	for id: int in ids:
		var body: Dictionary = bodies[id]
		if not body.active:
			continue
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var velocity: Vector2 = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		result.append({"session": session, "id": id, "generation": body.generation,
			"body_generation": body.body_generation, "geometry_revision": body.geometry_revision,
			"geometry_digest": body.geometry_digest, "pose_serial": pose_serial,
			"x": pose.origin.x, "y": pose.origin.y, "rotation": body.rotation,
			"vx": velocity.x, "vy": velocity.y,
			"angular_velocity": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY),
			"sleeping": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING)})
	timings.pose_copy_usec = int(timings.pose_copy_usec) + Time.get_ticks_usec() - started
	return result


func step() -> Dictionary:
	if not space.is_valid() or motion_refused:
		return _refuse("MotionHeld")
	# Refuse a full-turn ambiguity before a known out-of-envelope manual step.
	# The continuous angle is then updated at every step, not at render cadence.
	for body: Dictionary in bodies.values():
		if body.active and absf(float(PhysicsServer2D.body_get_state(
			body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))) * FIXED_DELTA >= PI:
			motion_refused = true
			return _refuse("UnresolvedCompleteRotation")
	var started: int = Time.get_ticks_usec()
	ClassDB.class_call_static(RAPIER, &"space_step", space, FIXED_DELTA)
	timings.rapier_step_usec = int(timings.rapier_step_usec) + Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	ClassDB.class_call_static(RAPIER, &"space_flush_queries", space)
	timings.rapier_flush_usec = int(timings.rapier_flush_usec) + Time.get_ticks_usec() - started
	steps += 1
	for body: Dictionary in bodies.values():
		if not body.active:
			continue
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var wrapped: float = pose.get_rotation()
		var angular: float = float(PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
		if not is_finite(angular) or absf(angular) * FIXED_DELTA >= PI:
			motion_refused = true
			return _refuse("UnresolvedCompleteRotation")
		var delta: float = wrapf(wrapped - float(body.wrapped_rotation), -PI, PI)
		if absf(delta) > 0.20 + 0.00001:
			motion_refused = true
			return _refuse("RotationEnvelopeExceeded")
		body["rotation"] = float(body.rotation) + delta
		body["wrapped_rotation"] = wrapped
	return {"ok": true}


func remove_body(id: int) -> void:
	if bodies.has(id):
		_destroy_compound(bodies[id])
		bodies.erase(id)


func shutdown() -> void:
	for row: Dictionary in bodies.values():
		_destroy_compound(row)
	for row: Dictionary in terrain.values():
		_destroy_compound(row)
	bodies.clear()
	terrain.clear()
	if space.is_valid():
		PhysicsServer2D.free_rid(space)
	space = RID()
	session = 0
	pose_serial = 0
	steps = 0
	motion_refused = false


func _matching(shard: Dictionary) -> Dictionary:
	var body: Dictionary = bodies.get(int(shard.id), {})
	if int(shard.get("session", session)) != session or body.is_empty() or int(body.generation) != int(shard.generation):
		return {}
	return body


func _body_receipt(shard: Dictionary, body: Dictionary) -> Dictionary:
	return {"ok": true, "session": session, "id": int(shard.id),
		"generation": int(shard.generation), "transaction": int(shard.transaction),
		"body_generation": body.body_generation, "geometry_revision": body.geometry_revision,
		"geometry_digest": body.geometry_digest, "shape_count": body.shapes.size(),
		"shape_count_readback": PhysicsServer2D.body_get_shape_count(body.rid),
		"reserved": true}


func _new_compound(rectangles: Variant, pose: Transform2D, reserved: bool) -> Dictionary:
	var shapes: Array[RID] = _reserve_shapes(rectangles)
	if shapes.size() != rectangles.size() / 4:
		return _refuse("ShapeReservationFailed")
	var body: RID = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_mode(body, PhysicsServer2D.BODY_MODE_STATIC)
	PhysicsServer2D.body_set_collision_layer(body, 0 if reserved else 1)
	PhysicsServer2D.body_set_collision_mask(body, 0 if reserved else 1)
	PhysicsServer2D.body_set_state(body, PhysicsServer2D.BODY_STATE_TRANSFORM, pose)
	PhysicsServer2D.body_set_param(body, PhysicsServer2D.BODY_PARAM_FRICTION, 0.78)
	PhysicsServer2D.body_set_param(body, PhysicsServer2D.BODY_PARAM_BOUNCE, 0.0)
	PhysicsServer2D.body_set_param(body, PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE,
		156.0 / maxf(1.0, float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))))
	PhysicsServer2D.body_set_continuous_collision_detection_mode(body, PhysicsServer2D.CCD_MODE_CAST_SHAPE)
	_add_shapes(body, shapes, rectangles)
	PhysicsServer2D.body_set_space(body, space)
	return {"ok": true, "rid": body, "shapes": shapes}


func _set_mass(body: Dictionary, shard: Dictionary) -> bool:
	var mass: float = float(shard.mass)
	var inertia: float = float(shard.inertia)
	var com := Vector2(float(shard.com_x), float(shard.com_y))
	if not is_finite(mass) or mass <= 0.0 or not is_finite(inertia) or inertia <= 0.0 or not com.is_finite():
		return false
	PhysicsServer2D.body_set_param(body.rid, PhysicsServer2D.BODY_PARAM_MASS, mass)
	PhysicsServer2D.body_set_param(body.rid, PhysicsServer2D.BODY_PARAM_INERTIA, inertia)
	PhysicsServer2D.body_set_param(body.rid, PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS, com)
	return _readback_mass(body.rid, mass, com, inertia)


func _readback_mass(body: RID, mass: float, com: Vector2, inertia: float) -> bool:
	var actual_com: Vector2 = PhysicsServer2D.body_get_param(body, PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
	return is_equal_approx(float(PhysicsServer2D.body_get_param(body, PhysicsServer2D.BODY_PARAM_MASS)), mass) \
		and is_equal_approx(float(PhysicsServer2D.body_get_param(body, PhysicsServer2D.BODY_PARAM_INERTIA)), inertia) \
		and actual_com.is_equal_approx(com)


func _valid_rectangles(rectangles: Variant, limit: int) -> bool:
	if not (rectangles is Array or rectangles is PackedInt32Array) or rectangles.size() % 4 != 0 or rectangles.size() / 4 > limit:
		return false
	for offset: int in range(0, rectangles.size(), 4):
		if int(rectangles[offset + 2]) <= 0 or int(rectangles[offset + 3]) <= 0:
			return false
	return true


func _reserve_shapes(rectangles: Variant) -> Array[RID]:
	var result: Array[RID] = []
	for offset: int in range(0, rectangles.size(), 4):
		var shape: RID = PhysicsServer2D.rectangle_shape_create()
		if not shape.is_valid():
			for reserved: RID in result:
				PhysicsServer2D.free_rid(reserved)
			return []
		PhysicsServer2D.shape_set_data(shape, Vector2(float(rectangles[offset + 2]), float(rectangles[offset + 3])) * 0.5)
		result.append(shape)
	return result


func _add_shapes(body: RID, shapes: Array[RID], rectangles: Variant) -> void:
	for index: int in range(shapes.size()):
		var offset: int = index * 4
		var center := Vector2(float(rectangles[offset]) + float(rectangles[offset + 2]) * 0.5,
			float(rectangles[offset + 1]) + float(rectangles[offset + 3]) * 0.5)
		PhysicsServer2D.body_add_shape(body, shapes[index], Transform2D(0.0, center))


func _readback_shapes(body: RID, rectangles: Variant) -> bool:
	if PhysicsServer2D.body_get_shape_count(body) != rectangles.size() / 4:
		return false
	for index: int in range(rectangles.size() / 4):
		var offset: int = index * 4
		var half := Vector2(float(rectangles[offset + 2]), float(rectangles[offset + 3])) * 0.5
		var center := Vector2(float(rectangles[offset]), float(rectangles[offset + 1])) + half
		var shape: RID = PhysicsServer2D.body_get_shape(body, index)
		var actual_half: Vector2 = PhysicsServer2D.shape_get_data(shape)
		var actual_pose: Transform2D = PhysicsServer2D.body_get_shape_transform(body, index)
		if not actual_half.is_equal_approx(half) or not actual_pose.is_equal_approx(Transform2D(0.0, center)):
			return false
	return true


func _destroy_compound(compound: Dictionary) -> void:
	if compound.get("rid", RID()).is_valid():
		PhysicsServer2D.free_rid(compound.rid)
	for shape: RID in compound.get("shapes", []):
		if shape.is_valid():
			PhysicsServer2D.free_rid(shape)


func _record(stage: String, usec: int) -> void:
	timings[stage + "_usec"] = int(timings[stage + "_usec"]) + usec
	timings[stage + "_max_usec"] = maxi(usec, int(timings[stage + "_max_usec"]))


func _refuse(reason: String) -> Dictionary:
	last_error = reason
	return {"ok": false, "outcome": reason, "session": session}
