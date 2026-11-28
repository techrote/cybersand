class_name CyberObjectShardPhysicsBridge
extends RefCounted

# A separate, revisioned material-body adapter. This does not relax the immutable
# Workbench roster contract. Only this main-thread owner creates or frees RIDs.
const RAPIER: StringName = &"RapierPhysicsServer2D"
const MAX_BODIES: int = 3
const MAX_SHAPES_PER_BODY: int = 512
const MAX_TERRAIN_CHUNKS: int = 64
const FIXED_DELTA: float = 1.0 / 60.0
const MAX_DIAGNOSTIC_EVENTS: int = 128
const MAX_MOTION_SUBSTEPS: int = 16
const BASE_MOTION_SUBSTEPS: int = 4
const MAX_SEGMENT_TRANSLATION: float = 4.0
const MAX_SEGMENT_ROTATION: float = 0.20
const MAX_SEGMENT_CORNER_MOTION: float = 8.0
const SMALL_BODY_ROTATION_ARC: float = MAX_SEGMENT_CORNER_MOTION - MAX_SEGMENT_TRANSLATION
const MAX_OBSERVED_ROTATION: float = PI / 2.0


# Mirror native contact::motion_envelope. Extra angular displacement on a small
# offcut costs at most four cells of conservative corner arc. The original
# translation/corner/sampling budgets and the large-body .20 ceiling remain.
static func segment_rotation_limit(bounds_diagonal: float) -> float:
	if not is_finite(bounds_diagonal) or bounds_diagonal <= 0.0: return 0.0
	return minf(MAX_OBSERVED_ROTATION,maxf(MAX_SEGMENT_ROTATION,SMALL_BODY_ROTATION_ARC/bounds_diagonal))

var session: int = 0
var body_capacity: int = MAX_BODIES
var terrain_capacity: int = MAX_TERRAIN_CHUNKS
# M4 may borrow the existing Main Rapier space; it must never create, step,
# destroy or pretend to own that space. M3 standalone retains its private mode.
var _adopted_main_space: bool = false
var _last_main_step_serial: int = 0
var space: RID
var bodies: Dictionary = {}
var terrain: Dictionary = {}
var pose_serial: int = 0
var steps: int = 0
var motion_refused: bool = false
var last_error: String = ""
var diagnostic_events: Array[Dictionary] = []
var last_motion: Dictionary = {}
# Main-thread handshake state. An actual solver segment cannot be cancelled or
# rolled back after it advances; its exact native application must be acknowledged.
var motion_phase: String = "Idle"
var motion_operation_sequence: int = 0
var motion_segment_sequence: int = 0
var _motion_expected_tick: int = -1
var _motion_last_completed_tick: int = -1
# Native sessions are monotonic. This retirement watermark deliberately survives
# shutdown, so reinitializing the same owner cannot reset its physics clock.
var _last_physics_session: int = 0
# Native Registry issues strictly increasing IDs within one session. A scalar
# watermark fences retired reservations without accumulating an unbounded map.
var _last_reserved_body_id: int = 0
var _motion_pending_poses: Array = []
var _motion_pending_delta: float = 0.0
var _motion_roster: Dictionary = {}
var timings: Dictionary = {"geometry_install_usec": 0, "terrain_install_usec": 0,
	"rapier_step_usec": 0, "rapier_flush_usec": 0, "pose_copy_usec": 0,
	"geometry_install_max_usec": 0, "terrain_install_max_usec": 0}


func begin_frame() -> void:
	if not _main_owner():
		return
	# Event costs belong to the frame that performed them. Several installations
	# may occur during one handoff; accumulate those, never repeat the last event.
	for key: String in ["geometry_install_usec", "terrain_install_usec", "rapier_step_usec", "rapier_flush_usec", "pose_copy_usec"]:
		timings[key] = 0


func initialize(incarnation: int, existing_main_space: RID = RID(), maximum_bodies: int = MAX_BODIES, maximum_terrain_chunks: int = MAX_TERRAIN_CHUNKS) -> Dictionary:
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if incarnation <= 0 or maximum_bodies < 1 or maximum_bodies > 16 or maximum_terrain_chunks < 1 or maximum_terrain_chunks > 256 \
		or (not existing_main_space.is_valid() and (maximum_bodies != MAX_BODIES or maximum_terrain_chunks != MAX_TERRAIN_CHUNKS)):
		return _motion_refusal("InvalidSessionOrCapacity")
	if incarnation <= _last_physics_session:
		return _motion_refusal("RetiredSession")
	shutdown()
	_last_physics_session = incarnation
	_motion_last_completed_tick = -1
	if not ClassDB.class_exists(RAPIER) or str(ProjectSettings.get_setting(
		"physics/2d/physics_engine", "")) != "Rapier2D":
		return _refuse("RapierUnavailable")
	if incarnation <= 0:
		return _refuse("InvalidSession")
	session = incarnation
	body_capacity = maximum_bodies
	terrain_capacity = maximum_terrain_chunks
	_adopted_main_space = existing_main_space.is_valid()
	_last_main_step_serial = 0
	space = existing_main_space if _adopted_main_space else PhysicsServer2D.space_create()
	if not space.is_valid():
		return _refuse("SpaceReservationFailed")
	if not _adopted_main_space:
		PhysicsServer2D.space_set_active(space, false)
	return {"ok": true, "session": session}


func install_terrain(chunks: Array) -> Dictionary:
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if _motion_in_progress() or motion_refused:
		return _motion_refusal("MotionBarrierPending")
	var started: int = Time.get_ticks_usec()
	if not space.is_valid() or chunks.size() > terrain_capacity:
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
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if _motion_in_progress() or motion_refused:
		return _motion_refusal("MotionBarrierPending")
	if not space.is_valid() or int(shard.get("session", 0)) != session:
		return _refuse("RetiredSession")
	if not _valid_body_identity(shard):
		return _refuse("InvalidBodyIdentity")
	var id: int = int(shard.id)
	if bodies.has(id):
		var existing: Dictionary = bodies[id]
		if not _matching(shard).is_empty() and _same_installed_geometry(shard, existing):
			return _body_receipt(shard, existing)
		return _refuse("BodyIdentityConflict")
	if id <= _last_reserved_body_id:
		return _refuse("RetiredBodyIdentity")
	if bodies.size() >= body_capacity or not _valid_rectangles(shard.rectangles, MAX_SHAPES_PER_BODY):
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
	reserved["sampled_pose"] = pose
	reserved["com"] = Vector2(float(shard.com_x), float(shard.com_y))
	reserved["rectangles"] = PackedInt32Array(shard.rectangles)
	reserved["bounds_diagonal"] = _bounds_diagonal(shard)
	reserved["last_geometry_step"] = steps
	reserved["last_geometry_usec"] = 0
	reserved["last_sleeping"] = false
	if not _set_mass(reserved, shard):
		_destroy_compound(reserved)
		return _refuse("InvalidMass")
	if not _readback_shapes(reserved.rid, shard.rectangles):
		_destroy_compound(reserved)
		return _refuse("ShapeReadbackFailed")
	bodies[id] = reserved
	_last_reserved_body_id = id
	return _body_receipt(shard, reserved)


func activate(shard: Dictionary) -> Dictionary:
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if _motion_in_progress() or motion_refused:
		return _motion_refusal("MotionBarrierPending")
	var body: Dictionary = _matching(shard)
	if body.is_empty():
		return _refuse("StaleBody")
	# Native publications must confirm the completed debit, installed terrain
	# and occupancy barrier. Physics-only fixtures have no native lifecycle.
	if shard.has("lifecycle") and (str(shard.lifecycle) not in ["ReadyToActivate", "Active"] \
		or not bool(shard.get("owns_inventory", false))):
		return _refuse("NativeActivationBarrierPending")
	if not _same_installed_geometry(shard, body):
		return _refuse("StaleGeometry")
	var inherited_velocity := Vector2(float(shard.get("vx",0.0)),float(shard.get("vy",0.0)))
	var inherited_angular: float = float(shard.get("angular_velocity",0.0))
	if not inherited_velocity.is_finite() or not is_finite(inherited_angular):
		return _refuse("InvalidInitialVelocity")
	if bool(body.active):
		# A delayed duplicate activation is an observation of the installed body,
		# not another physics action. In particular it must not wake a sleeper,
		# refresh its contact graph or disturb its settled pose/velocity.
		var duplicate: Dictionary = _body_receipt(shard, body)
		duplicate["activated"] = PhysicsServer2D.body_get_mode(body.rid) == PhysicsServer2D.BODY_MODE_RIGID \
			and PhysicsServer2D.body_get_collision_layer(body.rid) == 1 \
			and PhysicsServer2D.body_get_collision_mask(body.rid) == 1
		duplicate["ok"] = duplicate.activated
		duplicate["duplicate"] = true
		return duplicate
	PhysicsServer2D.body_set_mode(body.rid, PhysicsServer2D.BODY_MODE_RIGID)
	PhysicsServer2D.body_set_collision_layer(body.rid, 1)
	PhysicsServer2D.body_set_collision_mask(body.rid, 1)
	PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,inherited_velocity)
	PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,inherited_angular)
	PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING, false)
	body["active"] = true
	PhysicsServer2D.body_set_max_contacts_reported(body.rid, 32)
	_event("BodyActivated", int(shard.id), {"geometry_revision": body.geometry_revision})
	var result: Dictionary = _body_receipt(shard, body)
	result["activated"] = PhysicsServer2D.body_get_mode(body.rid) == PhysicsServer2D.BODY_MODE_RIGID \
		and _readback_mass(body.rid, float(shard.mass), Vector2(float(shard.com_x), float(shard.com_y)), float(shard.inertia)) \
		and Vector2(PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)).is_equal_approx(inherited_velocity) \
		and is_equal_approx(float(PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)),inherited_angular)
	result["ok"] = result.activated
	return result


func install_geometry(shard: Dictionary) -> Dictionary:
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if _motion_in_progress() or motion_refused:
		return _motion_refusal("MotionBarrierPending")
	var started: int = Time.get_ticks_usec()
	var body: Dictionary = _matching(shard)
	if body.is_empty():
		return _refuse("StaleBody")
	var revision: int = int(shard.geometry_revision)
	if revision < int(body.geometry_revision):
		return _refuse("StaleGeometry")
	if revision == int(body.geometry_revision):
		if not _same_installed_geometry(shard, body):
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
	# Cargo can change mass without changing rigid occupancy. Keep existing shape
	# handles/contact manifolds when the exact rectangle publication is unchanged.
	var shapes_changed: bool = PackedInt32Array(shard.rectangles) != body.rectangles
	var mass_changed: bool = not _readback_mass(body.rid, float(shard.mass),
		Vector2(float(shard.com_x), float(shard.com_y)), float(shard.inertia))
	var fresh: Array[RID] = []
	if shapes_changed:
		fresh = _reserve_shapes(shard.rectangles)
		if fresh.size() != shard.rectangles.size() / 4:
			return _refuse("ShapeReservationFailed")
	var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var angular: float = float(PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
	var sleeping: bool = bool(PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING))
	var old_com: Vector2 = body.com
	var old_shapes: Array = body.shapes
	if shapes_changed:
		PhysicsServer2D.body_clear_shapes(body.rid)
		_add_shapes(body.rid, fresh, shard.rectangles)
		body["shapes"] = fresh
	if ((shapes_changed or mass_changed) and not _set_mass(body, shard)) or not _readback_shapes(body.rid, shard.rectangles):
		# Invalid native mass is an integration fault after backend mutation;
		# keep the material owner paused, never label this a harmless refusal.
		if shapes_changed:
			for shape: RID in old_shapes:
				PhysicsServer2D.free_rid(shape)
		return {"ok": false, "quarantine": true, "outcome": "MassInstallationFailed"}
	var new_com := Vector2(float(shard.com_x), float(shard.com_y))
	var shift: Vector2 = pose.basis_xform(new_com - old_com)
	if shapes_changed or mass_changed:
		PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM, pose)
		PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
			velocity + Vector2(-shift.y, shift.x) * angular)
		PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, angular)
		# Sleep belongs to the old contact graph. Reapplying it after replacing
		# colliders suppresses contact refresh in the selected Rapier runtime:
		# settled bodies free-fall into their support before violent correction.
		# Wake for the changed physics; Rapier decides when the new graph sleeps.
		PhysicsServer2D.body_set_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING, false)
	if shapes_changed:
		for shape: RID in old_shapes:
			PhysicsServer2D.free_rid(shape)
	body["geometry_revision"] = revision
	body["geometry_digest"] = str(shard.geometry_digest)
	body["com"] = new_com
	body["rectangles"] = PackedInt32Array(shard.rectangles)
	body["bounds_diagonal"] = _bounds_diagonal(shard)
	body["last_geometry_step"] = steps
	body["last_geometry_usec"] = Time.get_ticks_usec() - started
	_event("GeometryInstalled", int(shard.id), {"geometry_revision": revision,
		"shape_replacement": shapes_changed, "mass_changed": mass_changed,
		"was_sleeping": sleeping, "wake_for_changed_physics": shapes_changed or mass_changed,
		"install_usec": body.last_geometry_usec})
	_record("geometry_install", int(body.last_geometry_usec))
	return _body_receipt(shard, body)

func freeze_for_reabsorption(shard: Dictionary, transaction: int) -> Dictionary:
	if not _main_owner() or _motion_in_progress() or motion_refused:
		return _motion_refusal("MotionBarrierPending")
	var body: Dictionary = _matching(shard)
	if body.is_empty() or transaction <= 0: return _refuse("StaleBody")
	if body.has("reabsorption_transaction"):
		return {"ok":int(body.reabsorption_transaction)==transaction \
			and PhysicsServer2D.body_get_mode(body.rid)==PhysicsServer2D.BODY_MODE_STATIC \
			and PhysicsServer2D.body_get_collision_layer(body.rid)==0 \
			and PhysicsServer2D.body_get_collision_mask(body.rid)==0,"transaction":transaction}
	var actual: Transform2D = PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var source := Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y)))
	if not actual.is_equal_approx(source) or not _same_installed_geometry(shard,body):
		return _refuse("ReabsorptionSourcePoseChanged")
	PhysicsServer2D.body_set_mode(body.rid,PhysicsServer2D.BODY_MODE_STATIC)
	PhysicsServer2D.body_set_collision_layer(body.rid,0)
	PhysicsServer2D.body_set_collision_mask(body.rid,0)
	body["active"] = false
	body["reabsorption_transaction"] = transaction
	var frozen: bool = PhysicsServer2D.body_get_mode(body.rid)==PhysicsServer2D.BODY_MODE_STATIC \
		and PhysicsServer2D.body_get_collision_layer(body.rid)==0 and PhysicsServer2D.body_get_collision_mask(body.rid)==0
	_event("ReabsorptionFrozen",int(shard.id),{"transaction":transaction,"frozen":frozen})
	return {"ok":frozen,"transaction":transaction,"id":int(shard.id),"frozen":frozen}


# Called ONLY by ordinary Main after its existing rapier_bridge.step()
# completed. A monotonic Main serial cannot replace the native applied-pose
# receipt, but rejects duplicate/stale sampling. This function does not step.
func capture_completed_main_step(main_step_serial: int, completed_delta: float = FIXED_DELTA) -> Dictionary:
	if not _main_owner() or not _adopted_main_space or not space.is_valid():
		return {"ok":false,"outcome":"MainRapierSpaceRequired"}
	if main_step_serial <= _last_main_step_serial or main_step_serial <= 0:
		return {"ok":false,"outcome":"StaleMainPhysicsStep"}
	if motion_refused or _motion_in_progress():
		return {"ok":false,"outcome":"PendingUnacknowledgedMotion"}
	if not is_finite(completed_delta) or completed_delta<=0.0 or completed_delta>FIXED_DELTA:
		return {"ok":false,"outcome":"InvalidMainStepDelta"}
	var observed: Dictionary = {}
	for id: int in bodies:
		var body: Dictionary = bodies[id]
		if not body.active: continue
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
		var previous: Transform2D = body.sampled_pose
		var angular: float = float(PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
		var angle: float = wrapf(pose.get_rotation()-float(body.wrapped_rotation),-PI,PI)
		var distance: float = pose.origin.distance_to(previous.origin)
		var corner_motion: float = distance+float(body.bounds_diagonal)*absf(angle)
		var evidence := {"id":id,"delta":completed_delta,"translation":distance,"rotation":angle,"corner_motion":corner_motion}
		if not pose.is_finite() or not is_finite(angular) or absf(angular)*completed_delta>=PI:
			return _motion_hold("UnresolvedCompleteRotation",evidence)
		if distance>MAX_SEGMENT_TRANSLATION or absf(angle)>segment_rotation_limit(float(body.bounds_diagonal)) or corner_motion>MAX_SEGMENT_CORNER_MOTION:
			return _motion_hold("SegmentMotionEnvelopeExceeded",evidence)
		observed[id] = {"pose":pose,"rotation":float(body.rotation)+angle,
			"sleeping":bool(PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_SLEEPING))}
	# Read and validate every body before advancing any published continuous
	# angle. This is the same physical motion contract as the standalone path.
	for id: int in observed:
		var body: Dictionary = bodies[id]
		var actual: Dictionary = observed[id]
		body.rotation = actual.rotation
		body.wrapped_rotation = actual.pose.get_rotation()
		body.sampled_pose = actual.pose
		if actual.sleeping != body.last_sleeping:
			_event("Sleeping" if actual.sleeping else "Waking",id,{"geometry_revision":body.geometry_revision})
		body.last_sleeping = actual.sleeping
	var poses: Array = _sample_poses_unfenced()
	if motion_refused:
		return {"ok":false,"outcome":last_error}
	_last_main_step_serial = main_step_serial
	steps += 1
	return {"ok":true,"outcome":"RealMainSpacePoseReadback",
		"main_step_serial":main_step_serial,"poses":poses,
		"body_count":poses.size(),"session":session}

func sample_poses() -> Array:
	if not _main_owner() or _motion_in_progress():
		return []
	return _sample_poses_unfenced()


func _sample_poses_unfenced() -> Array:
	if pose_serial == 9223372036854775807:
		_motion_hold("PoseSequenceExhausted", {})
		return []
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
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if _motion_in_progress():
		return _motion_refusal("MotionBarrierPending")
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
		if absf(delta) > segment_rotation_limit(float(body.bounds_diagonal)) + 0.00001:
			motion_refused = true
			return _refuse("RotationEnvelopeExceeded")
		body["rotation"] = float(body.rotation) + delta
		body["wrapped_rotation"] = wrapped
		var sleeping: bool = bool(PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING))
		if sleeping != bool(body.last_sleeping):
			_event("Sleeping" if sleeping else "Waking", _body_id(body.rid),
				{"geometry_revision": body.geometry_revision, "angular_velocity": angular})
		body["last_sleeping"] = sleeping
	return {"ok": true}


func step_motion(accept_segment: Callable, expected_semantic_tick: int = -1) -> Dictionary:
	# Synchronous reference adapter over the same incremental implementation used
	# by the exclusive-worker host. It has no separate stepping/receipt logic.
	if not accept_segment.is_valid():
		return _motion_refusal("InvalidMotionConsumer")
	var result: Dictionary = begin_motion_tick(expected_semantic_tick)
	if not result.get("ok", false):
		return result
	while not result.get("finished", false):
		result = advance_motion_segment()
		if not result.get("ok", false) or result.get("finished", false):
			return result
		var receipt: Variant = accept_segment.call(result.poses)
		result = acknowledge_motion_segment(receipt)
		if not result.get("ok", false):
			return result
	return result


func begin_motion_tick(expected_semantic_tick: int = -1) -> Dictionary:
	if _adopted_main_space:
		return {"ok":false,"outcome":"MainOwnsRapierStep"}
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if not space.is_valid() or motion_refused:
		return _motion_refusal("MotionHeld")
	if _motion_in_progress():
		return _motion_refusal("MotionTickAlreadyPending")
	if expected_semantic_tick < 0:
		return _motion_refusal("InvalidSemanticTick")
	if expected_semantic_tick <= _motion_last_completed_tick:
		return _motion_refusal("StaleSemanticTick")
	if motion_operation_sequence == 9223372036854775807:
		return _motion_hold("MotionOperationSequenceExhausted", {})
	motion_operation_sequence += 1
	_motion_expected_tick = expected_semantic_tick
	_motion_pending_poses.clear()
	_motion_pending_delta = 0.0
	_motion_roster = _current_motion_roster()
	last_motion = {"requested_delta": FIXED_DELTA, "completed_delta": 0.0,
		"applied_delta": 0.0, "substeps": 0, "maximum_substeps": MAX_MOTION_SUBSTEPS,
		"applied_segments": 0, "operation_sequence": motion_operation_sequence}
	if bodies.is_empty():
		var empty_step: Dictionary = step()
		if not empty_step.get("ok", false):
			return _motion_hold(str(empty_step.get("outcome", "EmptySpaceStepFailed")), empty_step)
		last_motion.completed_delta = FIXED_DELTA
		last_motion.applied_delta = FIXED_DELTA
		last_motion.substeps = 1
		motion_phase = "Completed"
		_motion_last_completed_tick = expected_semantic_tick
		return _motion_progress(true)
	motion_phase = "Ready"
	return _motion_progress(false)


func advance_motion_segment() -> Dictionary:
	if _adopted_main_space:
		return {"ok":false,"outcome":"MainOwnsRapierStep"}
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if motion_phase == "AwaitingNative":
		return _motion_refusal("AwaitingNativeReceipt")
	if motion_refused or not space.is_valid():
		return _motion_refusal("MotionHeld")
	if motion_phase == "Completed":
		return _motion_progress(true)
	if motion_phase != "Ready":
		return _motion_refusal("MotionTickNotStarted")
	if _current_motion_roster() != _motion_roster:
		return _motion_hold("MotionOwnerRosterChanged", {})
	if motion_segment_sequence == 9223372036854775807 or pose_serial == 9223372036854775807:
		return _motion_hold("MotionSegmentSequenceExhausted", {})
	var remaining: float = maxf(0.0, FIXED_DELTA - float(last_motion.completed_delta))
	var delta: float = minf(remaining, FIXED_DELTA / float(BASE_MOTION_SUBSTEPS))
	for body: Dictionary in bodies.values():
		if not body.active:
			continue
		var velocity: Vector2 = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		var angular: float = absf(float(PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)))
		if not velocity.is_finite() or not is_finite(angular):
			return _motion_hold("InvalidVelocity", {"id": _body_id(body.rid)})
		# Half-envelope prediction leaves room for collision impulses. Actual
		# displacement is checked independently after every solver invocation.
		var speed: float = velocity.length()
		if speed > 0.0:
			delta = minf(delta, 0.5 * MAX_SEGMENT_TRANSLATION / speed)
		if angular > 0.0:
			delta = minf(delta, 0.5 * segment_rotation_limit(float(body.bounds_diagonal)) / angular)
		var corner_speed: float = speed + float(body.bounds_diagonal) * angular
		if corner_speed > 0.0:
			delta = minf(delta, 0.5 * MAX_SEGMENT_CORNER_MOTION / corner_speed)
	var available: int = MAX_MOTION_SUBSTEPS - int(last_motion.substeps)
	if not is_finite(delta) or delta <= 0.0 or remaining / delta > float(available) + 0.0000001:
		return _motion_hold("MotionSubstepCapacity", {"remaining_delta": remaining,
			"proposed_delta": delta, "available_substeps": available})
	var previous: Dictionary = {}
	for id: int in bodies:
		if bodies[id].active:
			previous[id] = PhysicsServer2D.body_get_state(bodies[id].rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var started: int = Time.get_ticks_usec()
	ClassDB.class_call_static(RAPIER, &"space_step", space, delta)
	timings.rapier_step_usec = int(timings.rapier_step_usec) + Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	ClassDB.class_call_static(RAPIER, &"space_flush_queries", space)
	timings.rapier_flush_usec = int(timings.rapier_flush_usec) + Time.get_ticks_usec() - started
	steps += 1
	last_motion.substeps = int(last_motion.substeps) + 1
	last_motion.completed_delta = float(last_motion.completed_delta) + delta
	var next_angles: Dictionary = {}
	for id: int in previous:
		var body: Dictionary = bodies[id]
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var angular: float = float(PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
		var angle: float = wrapf(pose.get_rotation() - float(body.wrapped_rotation), -PI, PI)
		var distance: float = pose.origin.distance_to(previous[id].origin)
		var corner_motion: float = distance + float(body.bounds_diagonal) * absf(angle)
		var evidence: Dictionary = {"id": id, "delta": delta, "translation": distance,
			"rotation": angle, "corner_motion": corner_motion, "angular_velocity": angular,
			"before_x": previous[id].origin.x, "before_y": previous[id].origin.y,
			"after_x": pose.origin.x, "after_y": pose.origin.y}
		if not pose.origin.is_finite() or not is_finite(angle) or not is_finite(angular) or absf(angular) * delta >= PI:
			return _motion_hold("UnresolvedCompleteRotation", evidence)
		if distance > MAX_SEGMENT_TRANSLATION or absf(angle) > segment_rotation_limit(float(body.bounds_diagonal)) or corner_motion > MAX_SEGMENT_CORNER_MOTION:
			return _motion_hold("SegmentMotionEnvelopeExceeded", evidence)
		next_angles[id] = {"rotation": float(body.rotation) + angle, "wrapped": pose.get_rotation()}
	# All body segments passed before any new angle is published.
	for id: int in next_angles:
		bodies[id].rotation = next_angles[id].rotation
		bodies[id].wrapped_rotation = next_angles[id].wrapped
		var sleeping: bool = bool(PhysicsServer2D.body_get_state(bodies[id].rid, PhysicsServer2D.BODY_STATE_SLEEPING))
		if sleeping != bool(bodies[id].last_sleeping):
			_event("Sleeping" if sleeping else "Waking", id, {"geometry_revision": bodies[id].geometry_revision})
		bodies[id].last_sleeping = sleeping
	_motion_pending_poses = _sample_poses_unfenced().duplicate(true)
	_motion_pending_delta = delta
	motion_segment_sequence += 1
	motion_phase = "AwaitingNative"
	var result: Dictionary = _motion_progress(false)
	result["segment_sequence"] = motion_segment_sequence
	result["poses"] = _motion_pending_poses.duplicate(true)
	result["delta"] = delta
	return result


func acknowledge_motion_segment(receipt: Variant) -> Dictionary:
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if motion_phase != "AwaitingNative":
		return _motion_refusal("MotionAckNotPending")
	if _current_motion_roster() != _motion_roster:
		return _motion_hold("MotionOwnerRosterChanged", {})
	if not _valid_motion_receipt(receipt, _motion_pending_poses, _motion_expected_tick):
		return _motion_hold("NativeSegmentRefused", {"receipt": receipt,
			"segment_sequence": motion_segment_sequence})
	last_motion.applied_segments = int(last_motion.applied_segments) + 1
	last_motion.applied_delta = float(last_motion.applied_delta) + _motion_pending_delta
	_motion_pending_poses.clear()
	_motion_pending_delta = 0.0
	var finished: bool = FIXED_DELTA - float(last_motion.completed_delta) <= 0.000000001
	motion_phase = "Completed" if finished else "Ready"
	if finished:
		_motion_last_completed_tick = _motion_expected_tick
	return _motion_progress(finished)


func _main_owner() -> bool:
	return OS.get_thread_caller_id() == OS.get_main_thread_id()


func _motion_in_progress() -> bool:
	return motion_phase == "Ready" or motion_phase == "AwaitingNative"


func _current_motion_roster() -> Dictionary:
	var roster: Dictionary = {}
	for id: int in bodies:
		var body: Dictionary = bodies[id]
		roster[id] = {"rid": body.rid, "active": body.active, "generation": body.generation,
			"body_generation": body.body_generation, "geometry_revision": body.geometry_revision,
			"geometry_digest": body.geometry_digest}
	return roster


func _motion_progress(finished: bool) -> Dictionary:
	return {"ok": true, "finished": finished, "session": session,
		"operation_sequence": motion_operation_sequence, "phase": motion_phase,
		"motion": last_motion.duplicate(true)}


func _motion_refusal(reason: String) -> Dictionary:
	# Expected stale/duplicate/busy protocol calls do not advance physics, mint
	# a pose serial, overwrite evidence or discard the outstanding acknowledgement.
	return {"ok": false, "outcome": reason, "session": session,
		"operation_sequence": motion_operation_sequence, "phase": motion_phase,
		"motion": last_motion.duplicate(true)}


func _valid_motion_receipt(receipt: Variant, poses: Array, semantic_tick: int) -> bool:
	if not receipt is Dictionary or not receipt.get("ok", false) or not receipt.get("applied", false):
		return false
	if not receipt.get("semantic_tick") is int or int(receipt.semantic_tick) < 0 or (
		semantic_tick >= 0 and int(receipt.semantic_tick) != semantic_tick):
		return false
	var accepted: Variant = receipt.get("accepted_pose_serials")
	if not accepted is Array or accepted.size() != poses.size():
		return false
	var remaining: Dictionary = {}
	for pose: Dictionary in poses:
		remaining[int(pose.id)] = pose
	for row: Variant in accepted:
		if not row is Dictionary or not row.get("id") is int or not remaining.has(int(row.id)):
			return false
		var expected: Dictionary = remaining[int(row.id)]
		for key: String in ["session", "id", "generation", "body_generation", "geometry_revision", "pose_serial"]:
			if not row.get(key) is int or int(row[key]) != int(expected[key]):
				return false
		remaining.erase(int(row.id))
	return remaining.is_empty()


func _motion_hold(reason: String, detail: Dictionary) -> Dictionary:
	motion_phase = "Held"
	motion_refused = true
	last_error = reason
	last_motion["reason"] = reason
	last_motion["detail"] = detail
	_event("MotionHeld", int(detail.get("id", 0)), last_motion.duplicate(true))
	return {"ok": false, "outcome": reason, "session": session, "motion": last_motion.duplicate(true)}


func _bounds_diagonal(shard: Dictionary) -> float:
	if int(shard.get("width", 0)) > 0 and int(shard.get("height", 0)) > 0:
		return Vector2(float(shard.width), float(shard.height)).length()
	# Isolated physics fixtures have no native storage publication. Conservatively
	# enclose their exact rectangle union around the stable lattice origin.
	var extent := Vector2.ZERO
	for offset: int in range(0, shard.rectangles.size(), 4):
		extent.x = maxf(extent.x, absf(float(shard.rectangles[offset])) + float(shard.rectangles[offset + 2]))
		extent.y = maxf(extent.y, absf(float(shard.rectangles[offset + 1])) + float(shard.rectangles[offset + 3]))
	return extent.length()


func remove_body(id: int) -> Dictionary:
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	if _motion_in_progress() or motion_refused:
		return _motion_refusal("MotionBarrierPending")
	if bodies.has(id):
		_destroy_compound(bodies[id])
		bodies.erase(id)
	return {"ok": true}


func shutdown() -> void:
	if not _main_owner():
		return
	for row: Dictionary in bodies.values():
		_destroy_compound(row)
	for row: Dictionary in terrain.values():
		_destroy_compound(row)
	bodies.clear()
	terrain.clear()
	if space.is_valid() and not _adopted_main_space:
		PhysicsServer2D.free_rid(space)
	space = RID()
	_adopted_main_space = false
	_last_main_step_serial = 0
	session = 0
	_last_reserved_body_id = 0
	# Serials are monotonic for the bridge object's lifetime. Explicit session
	# disposal drops pending poses but cannot make an old ACK match new work.
	steps = 0
	motion_refused = false
	last_error = ""
	diagnostic_events.clear()
	last_motion.clear()
	motion_phase = "Idle"
	_motion_expected_tick = -1
	_motion_pending_poses.clear()
	_motion_pending_delta = 0.0
	_motion_roster.clear()


func diagnostics() -> Dictionary:
	if not _main_owner():
		return {"ok": false, "outcome": "MainPhysicsOwnerRequired"}
	# Inspection must not create a pose serial or an admission receipt. The last
	# native-accepted serial remains the coordinator/session's separate authority.
	var result: Array[Dictionary] = []
	var ids: Array = bodies.keys()
	ids.sort()
	for id: int in ids:
		var body: Dictionary = bodies[id]
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var velocity: Vector2 = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		var angular: float = float(PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
		var center: Vector2 = PhysicsServer2D.body_get_param(body.rid, PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
		var state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(body.rid)
		result.append({"id": id, "generation": body.generation, "body_generation": body.body_generation,
			"active": body.active, "geometry_revision": body.geometry_revision,
			"geometry_digest": body.geometry_digest, "x": pose.origin.x, "y": pose.origin.y,
			"rotation": body.rotation, "backend_rotation": pose.get_rotation(),
			"vx": velocity.x, "vy": velocity.y, "angular_velocity": angular,
			"sleeping": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING),
			"mass": PhysicsServer2D.body_get_param(body.rid, PhysicsServer2D.BODY_PARAM_MASS),
			"com_x": center.x, "com_y": center.y,
			"inertia": PhysicsServer2D.body_get_param(body.rid, PhysicsServer2D.BODY_PARAM_INERTIA),
			"reported_contacts": state.get_contact_count() if state != null else -1,
			"shape_count": PhysicsServer2D.body_get_shape_count(body.rid),
			"last_geometry_step": body.last_geometry_step, "last_geometry_usec": body.last_geometry_usec,
			"segment_rotation_limit": segment_rotation_limit(float(body.bounds_diagonal)),
			"nominal_rotation_headroom": segment_rotation_limit(float(body.bounds_diagonal)) - absf(angular) * FIXED_DELTA,
			"nominal_translation_headroom": 4.0 - velocity.length() * FIXED_DELTA})
	return {"session": session, "physics_steps": steps, "last_sampled_pose_serial": pose_serial,
		"motion_refused": motion_refused, "last_error": last_error,
		"motion_phase": motion_phase, "operation_sequence": motion_operation_sequence,
		"segment_sequence": motion_segment_sequence, "awaiting_native": motion_phase == "AwaitingNative",
		"last_completed_semantic_tick": _motion_last_completed_tick, "last_physics_session": _last_physics_session,
		"bodies": result, "events": diagnostic_events.duplicate(true), "motion": last_motion.duplicate(true)}


func _body_id(rid: RID) -> int:
	for id: int in bodies:
		if bodies[id].rid == rid:
			return id
	return 0


func _event(kind: String, id: int, detail: Dictionary) -> void:
	if diagnostic_events.size() == MAX_DIAGNOSTIC_EVENTS:
		diagnostic_events.pop_front()
	diagnostic_events.append({"kind": kind, "id": id, "physics_step": steps, "detail": detail})


func _matching(shard: Dictionary) -> Dictionary:
	if not _valid_body_identity(shard):
		return {}
	var body: Dictionary = bodies.get(int(shard.id), {})
	if int(shard.session) != session or body.is_empty() \
		or int(body.generation) != int(shard.generation) \
		or int(body.body_generation) != int(shard.body_generation) \
		or int(body.transaction) != int(shard.transaction):
		return {}
	return body


func _valid_body_identity(shard: Dictionary) -> bool:
	for key: String in ["session", "id", "generation", "body_generation", "transaction", "geometry_revision"]:
		if not shard.get(key) is int or int(shard[key]) <= 0:
			return false
	return shard.get("geometry_digest") is String


func _same_installed_geometry(shard: Dictionary, body: Dictionary) -> bool:
	# Equal revisions/digests alone cannot turn changed shape or mass data into
	# an installed receipt. Read back the real backend before an idempotent ACK.
	if int(shard.geometry_revision) != int(body.geometry_revision) \
		or str(shard.geometry_digest) != str(body.geometry_digest) \
		or not _valid_rectangles(shard.get("rectangles", []), MAX_SHAPES_PER_BODY) \
		or PackedInt32Array(shard.rectangles) != body.rectangles:
		return false
	for key: String in ["mass", "com_x", "com_y", "inertia"]:
		if not (shard.get(key) is float or shard.get(key) is int) or not is_finite(float(shard[key])):
			return false
	return _readback_shapes(body.rid, shard.rectangles) and _readback_mass(body.rid,
		float(shard.mass), Vector2(float(shard.com_x), float(shard.com_y)), float(shard.inertia))


func _body_receipt(shard: Dictionary, body: Dictionary) -> Dictionary:
	return {"ok": true, "session": session, "id": int(shard.id),
		"generation": int(body.generation), "transaction": int(body.transaction),
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
