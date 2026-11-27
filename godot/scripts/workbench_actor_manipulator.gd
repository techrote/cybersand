class_name CyberWorkbenchActorManipulator
extends RefCounted

# Main-thread, temporary physical interaction. The session owns the body graph
# and invokes advance immediately before its one existing Rapier step. This
# object retains only value identities and a weak session reference, never a RID
# or ownership of a rigid body/joint. No property setter teleports a live body.
const DEFAULT_SETTINGS := {"stiffness":160.0, "damping":24.0, "max_force":24000.0}
const MAX_DELTA := 1.0 / 30.0
const MAX_IMPULSE_PER_MASS := 100.0
const MAX_ANGULAR_IMPULSE_PER_INERTIA := 20.0

var _owner: WeakRef
var _grab: Dictionary = {}
var _settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var _target := Vector2.ZERO
var _anchor := Vector2.ZERO
var _force := Vector2.ZERO
var _reason := "idle"


func bind(session: Node) -> void:
	end_grab("session_changed")
	_owner = weakref(session) if is_instance_valid(session) else null


func settings() -> Dictionary:
	return _settings.duplicate()


func configure_settings(value: Dictionary) -> bool:
	if value.size() != 3 or not value.has_all(["stiffness", "damping", "max_force"]): return false
	for key: String in ["stiffness", "damping", "max_force"]:
		if not (value[key] is int or value[key] is float) or not is_finite(float(value[key])): return false
	if float(value.stiffness) < 5.0 or float(value.stiffness) > 2400.0 \
		or float(value.damping) < 0.0 or float(value.damping) > 160.0 \
		or float(value.max_force) < 10.0 or float(value.max_force) > 1000000.0: return false
	_settings = value.duplicate()
	return true


func _session() -> Node:
	if _owner == null: return null
	var value: Variant = _owner.get_ref()
	return value if is_instance_valid(value) and value is Node else null


func hit_test(point: Vector2) -> Dictionary:
	var session := _session()
	return session.pick_workbench_part(point) if session != null and point.is_finite() else {}


func capture_actor(instance_id: int) -> Dictionary:
	var session := _session()
	return session.capture_workbench_assembly(instance_id) if session != null else {}


func begin_grab(point: Vector2) -> Dictionary:
	return begin_grab_hit(point, hit_test(point))


func begin_grab_hit(point: Vector2, hit: Dictionary) -> Dictionary:
	end_grab("replaced_grab")
	var session := _session()
	if session == null or hit.is_empty() or not session.claim_workbench_grab(hit):
		_reason = "no_available_physical_part"
		return {}
	_grab = hit.duplicate(true)
	_target = point
	_anchor = point
	_force = Vector2.ZERO
	_reason = "grabbing"
	return state()


func update_target(point: Vector2) -> bool:
	if _grab.is_empty(): return false
	if not point.is_finite():
		end_grab("nonfinite_target")
		return false
	var extent: Vector2i = _grab.extent
	# Pointer movement beyond the viewport remains a bounded physical pull at
	# its edge. Releasing anywhere is handled by the host's global input route.
	_target = point.clamp(Vector2.ZERO, Vector2(extent))
	return true


func active() -> bool:
	return not _grab.is_empty()


func grabs_part(slot: int, part: int) -> bool:
	return not _grab.is_empty() and int(_grab.actor_slot) == slot and int(_grab.part_index) == part


func advance(delta: float) -> void:
	if _grab.is_empty(): return
	var session := _session()
	if session == null or not is_finite(delta) or delta <= 0.0 or delta > MAX_DELTA:
		end_grab("invalid_physics_step")
		return
	var body: RigidBody2D = session.workbench_grab_body(_grab)
	if body == null or session._suspended or int(session._manipulated_actor) != int(_grab.actor_slot):
		end_grab("body_unavailable")
		return
	var rid := body.get_rid()
	var pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var linear: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var angular: float = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	var offset: Vector2 = pose.basis_xform(Vector2(_grab.local_anchor))
	_anchor = pose.origin + offset
	var velocity: Vector2 = linear + Vector2(-offset.y, offset.x) * angular
	if not _anchor.is_finite() or not velocity.is_finite() or not is_finite(body.mass) \
		or body.mass <= 0.0 or not is_finite(body.inertia) or body.inertia <= 0.0:
		end_grab("nonfinite_body_state")
		return
	var stiffness: float = float(_settings.stiffness)
	var damping: float = float(_settings.damping)
	# Solve the two-dimensional implicit point spring, including rotational
	# effective mass. A scalar centre-of-mass damper becomes unstable when a
	# light limb is grabbed at its tip. This solve damps that actual point.
	var inverse_mass := 1.0 / body.mass
	var inverse_inertia := 1.0 / body.inertia
	var gain := delta * (damping + stiffness * delta) * body.mass
	var a := 1.0 + gain * (inverse_mass + offset.y * offset.y * inverse_inertia)
	var b := -gain * offset.x * offset.y * inverse_inertia
	var d := 1.0 + gain * (inverse_mass + offset.x * offset.x * inverse_inertia)
	var determinant := a * d - b * b
	var rhs: Vector2 = ((_target - _anchor) * stiffness - velocity * (damping + stiffness * delta)) * body.mass * delta
	if not is_finite(determinant) or determinant <= 0.0 or not rhs.is_finite():
		end_grab("nonfinite_spring_solve")
		return
	var impulse := Vector2(d * rhs.x - b * rhs.y, a * rhs.y - b * rhs.x) / determinant
	impulse = impulse.limit_length(minf(float(_settings.max_force) * delta, body.mass * MAX_IMPULSE_PER_MASS))
	var torque: float = offset.cross(impulse)
	var torque_limit: float = body.inertia * MAX_ANGULAR_IMPULSE_PER_INERTIA
	if absf(torque) > torque_limit: impulse *= torque_limit / absf(torque)
	_force = impulse / delta
	if not _force.is_finite():
		end_grab("nonfinite_force")
		return
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, false)
	PhysicsServer2D.body_apply_impulse(rid, _force * delta, offset)


func invalidate(reason: String) -> void:
	# Session-driven cancellation has already revoked the lease. Clear value
	# identity before any further event can observe or reuse the retired body.
	_grab.clear()
	_force = Vector2.ZERO
	_reason = reason


func end_grab(reason: String = "released") -> void:
	var previous := _grab.duplicate(true)
	invalidate(reason)
	var session := _session()
	if session != null and not previous.is_empty(): session.release_workbench_grab(previous, reason)


func state() -> Dictionary:
	var result := {"active":not _grab.is_empty(), "instance_id":0, "actor_slot":-1,
		"part_index":-1, "part_id":"", "target":_target, "anchor":_anchor,
		"force":_force, "reason":_reason, "run_id":"", "epoch":0}
	for key: String in ["instance_id", "actor_slot", "part_index", "part_id", "run_id", "epoch"]:
		if _grab.has(key): result[key] = _grab[key]
	return result


static func transformed_parts(parts: Array, from_origin: Vector2, to_origin: Vector2,
		angle_delta: float, retain_velocity: bool = false) -> Array:
	if parts.is_empty() or not from_origin.is_finite() or not to_origin.is_finite() \
		or not is_finite(angle_delta): return []
	var result: Array = []
	for value: Variant in parts:
		if not value is Dictionary or not value.has_all(["position", "rotation", "linear_velocity", "angular_velocity"]): return []
		if not value.position is Vector2 or not value.position.is_finite() or not _finite_number(value.rotation) \
			or not value.linear_velocity is Vector2 or not value.linear_velocity.is_finite() or not _finite_number(value.angular_velocity): return []
		result.append({"position":to_origin + (Vector2(value.position) - from_origin).rotated(angle_delta),
			"rotation":wrapf(float(value.rotation) + angle_delta, -PI, PI),
			"linear_velocity":Vector2(value.linear_velocity).rotated(angle_delta) if retain_velocity else Vector2.ZERO,
			"angular_velocity":float(value.angular_velocity) if retain_velocity else 0.0})
	return result


static func placement_preview(snapshot: Dictionary, position: Vector2, rotation: float) -> Dictionary:
	# Rotation is the proposed absolute assembly heading, in radians. Every
	# polygon comes from the current physical pose, including bent articulation.
	# This is value-only preview; the host commits once through prepared owners.
	if not snapshot.has_all(["position", "rotation", "parts", "geometry", "extent"]) \
		or not position.is_finite() or not is_finite(rotation): return {}
	var parts := transformed_parts(snapshot.parts, snapshot.position, position, rotation - float(snapshot.rotation))
	if parts.is_empty() or parts.size() != snapshot.geometry.size(): return {}
	var polygons: Array = []
	var pose_error := str(snapshot.get("pose_error", ""))
	var inside := pose_error.is_empty()
	var extent: Vector2i = snapshot.extent
	for index: int in range(parts.size()):
		var part: Dictionary = parts[index]
		var geometry: Dictionary = snapshot.geometry[index]
		var pose := Transform2D(float(part.rotation), part.position)
		# Native circular occupancy is conservatively rectangular, so bounds
		# validation deliberately includes that square even for round rendering.
		for rectangle: Dictionary in geometry.rectangles:
			var half: Vector2 = Vector2(rectangle.size) * 0.5
			var polygon := PackedVector2Array()
			for corner: Vector2 in [Vector2(-half.x,-half.y), Vector2(half.x,-half.y), half, Vector2(-half.x,half.y)]:
				var point: Vector2 = pose * (Vector2(rectangle.center) + corner)
				polygon.append(point)
				if point.x < 0.0 or point.y < 0.0 or point.x > extent.x or point.y > extent.y: inside = false
			polygons.append({"part_index":index, "part_id":geometry.part_id, "polygon":polygon})
	return {"instance_id":snapshot.get("instance_id", 0), "position":position,
		"rotation":wrapf(rotation, -PI, PI), "parts":parts, "polygons":polygons,
		"valid":inside, "reason":pose_error if not pose_error.is_empty() else ("" if inside else "Actor extends beyond the canvas")}


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
