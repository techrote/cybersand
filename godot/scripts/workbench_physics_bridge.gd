extends "res://scripts/rapier_physics_bridge.gd"

# Admitted workbench assemblies contain one rigid body per stable instance.
# Proxies own no inertia, drive, history, application fence or impulse.
const MAX_AGE: int = 1
const MAX_CORNER_TRAVEL: float = 0.5
const MAX_SESSION: int = 9007199254740991
# Godot 4.7's static-variable script lifetime can retain unrelated preloaded
# scripts or fault while retiring a stepped Rapier session. The main loop owns
# this scalar counter instead. It survives bridge/scene replacement without
# retaining any script, callable, node, resource or physics owner.
const SESSION_META: StringName = &"_cybersand_workbench_session_serial_v1"
var _session: int = 0
var _epoch: int = 0
var _response: String = ""
var _serial: int = 0
var _geometry := PackedFloat64Array()
var _members: Array[Dictionary] = []
var _rects: Array = []
var _history: Array[Dictionary] = []
var _accepted_samples := PackedInt64Array()
var _last_snapshot: int = -1
var last_application: Dictionary = {}


func configure_instances(definitions: Array, rigs: Array, epoch: int) -> Error:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return ERR_INVALID_DATA
	var owner: MainLoop = Engine.get_main_loop()
	if owner == null: return ERR_INVALID_DATA
	var previous_session: int = int(owner.get_meta(SESSION_META,0))
	if not _initialized or rigs.size() != _body_rids.size() or _session != 0 or previous_session < 0 or previous_session >= MAX_SESSION: return ERR_INVALID_DATA
	var first: int = 1
	for slot: int in range(rigs.size()):
		var rectangles: Array = rigs[slot].collision_rects()
		if rigs[slot].bodies().size() != 1 or rectangles.is_empty() or first + rectangles.size() - 1 > 64: return ERR_INVALID_DATA
		var definition: Dictionary = definitions[slot]
		_members.append({"id":slot + 1, "instance_id":int(definition.instance_id), "generation":epoch,
			"first_proxy":first, "count":rectangles.size(), "budget":float(definition.workbench_options.budget)})
		_rects.append(rectangles)
		for rect: Dictionary in rectangles:
			_geometry.append_array(PackedFloat64Array([rect.center.x, rect.center.y, rect.size.x, rect.size.y]))
		first += rectangles.size()
	_response = definitions[0].workbench_options.response
	_epoch = epoch
	_session = previous_session + 1
	owner.set_meta(SESSION_META,_session)
	_history.resize(MAX_AGE + 1)
	_accepted_samples.resize(_members.size())
	_accepted_samples.fill(-1)
	return OK


func pack_sample(drives: Array[bool]) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or not _initialized or _session == 0 or drives.size() != _members.size(): return {}
	var serial: int = (_serial + 1) % SAMPLE_SERIAL_LIMIT
	var states := PackedFloat64Array()
	var bodies: Array[Dictionary] = []
	var history: Array[Dictionary] = []
	for slot: int in range(_members.size()):
		var rid: RID = _body_rids[slot]
		var direct := PhysicsServer2D.body_get_direct_state(rid)
		if direct == null: return {}
		var pose: Transform2D = direct.transform
		var com: Vector2 = pose * direct.center_of_mass_local
		# Frozen provisional bodies have zero inverse mass. Read the authored
		# server properties directly, also for a hull with a custom COM.
		var mass: float = PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_MASS)
		var inertia: float = PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_INERTIA)
		var friction: float = PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_FRICTION)
		var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity")) * _bodies[slot].gravity_scale
		if not pose.is_finite() or not com.is_finite() or not direct.linear_velocity.is_finite() or not is_finite(direct.angular_velocity): return {}
		if not is_finite(mass) or not is_finite(inertia) or not is_finite(gravity) or not is_finite(friction) or mass <= 0 or inertia <= 0: return {}
		var member: Dictionary = _members[slot].duplicate()
		member.merge({"gravity":gravity, "external_drive":drives[slot]})
		bodies.append(member)
		history.append({"pose":pose, "com":com, "mass":mass, "inertia":inertia, "gravity":gravity, "external_drive":drives[slot]})
		var proxy_id: int = member.first_proxy
		for rectangle: Dictionary in _rects[slot]:
			var center: Vector2 = pose * Vector2(rectangle.center)
			states.append_array(PackedFloat64Array([proxy_id, center.x, center.y, pose.get_rotation(),
				rectangle.size.x, rectangle.size.y, direct.linear_velocity.x, direct.linear_velocity.y,
				direct.angular_velocity, mass, serial, inertia, com.x, com.y, friction, fixed_delta(), _session]))
			proxy_id += 1
	_serial = serial
	_history[serial % _history.size()] = {"serial":serial, "bodies":history, "step":manual_step_count()}
	return {"session":_session, "epoch":_epoch, "states":states, "geometry":_geometry.duplicate(), "bodies":bodies}


# Copied sample geometry for comparing a published result with the actual
# cellular mask it used. The live pose may already be one Rapier step newer.
func display_pose(slot: int, frame: Dictionary) -> Transform2D:
	# Only display transforms use this path. The actor/input/physics owners
	# still read the authoritative main-thread RID.
	if frame.get("session") == _session and frame.get("epoch") == _epoch:
		var member: Dictionary = _members[slot]
		var entry: Dictionary = frame.instances.get(member.instance_id,{})
		if entry.get("generation") == member.generation and entry.get("pose") is Transform2D:
			return entry.pose
	return body_transform(slot)


func retire_provisional_samples() -> void:
	for slot: int in range(_history.size()): _history[slot] = {}


func sampled_pose(instance_id: int, serial: int) -> Dictionary:
	if not _initialized or serial < 0 or _history.is_empty(): return {}
	var frame: Dictionary = _history[serial % _history.size()]
	if frame.get("serial") != serial: return {}
	for slot: int in range(_members.size()):
		if _members[slot].instance_id == instance_id:
			return {"pose":frame.bodies[slot].pose, "session":_session, "epoch":_epoch, "sample":serial}
	return {}


func _refuse(reason: String) -> int:
	last_application["refusal"] = reason
	return 0


func apply_packet(snapshot_serial: int, packet: Dictionary) -> int:
	last_application = {"accepted":false, "refusal":"", "snapshot":snapshot_serial, "bodies":[]}
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or not _initialized or _session == 0: return _refuse("retired")
	if packet.get("epoch") != _epoch or packet.get("session") != _session or packet.get("response") != _response: return _refuse("owner_or_response")
	if not packet.get("valid",false): return _refuse("native_refusal")
	if snapshot_serial <= _last_snapshot: return _refuse("duplicate_snapshot")
	var rows: Variant = packet.get("rows")
	if not rows is Array or rows.size() != _members.size(): return _refuse("layout")
	var seen: Dictionary = {}
	var actions: Array[Dictionary] = []
	for row: Variant in rows:
		if not row is Dictionary or not row.get("id") is int: return _refuse("body")
		var slot: int = row.id - 1
		if slot < 0 or slot >= _members.size() or seen.has(slot): return _refuse("body")
		seen[slot] = true
		var member: Dictionary = _members[slot]
		if row.get("instance_id") != member.instance_id or row.get("generation") != member.generation or row.get("budget") != member.budget: return _refuse("identity")
		if not row.get("sample") is int or row.sample < 0 or row.sample >= SAMPLE_SERIAL_LIMIT: return _refuse("sample")
		for key: String in ["impulse","correction","com"]:
			if not row.get(key) is Vector2 or not Vector2(row[key]).is_finite(): return _refuse("wrench")
		if not (row.get("torque") is int or row.get("torque") is float) or not is_finite(float(row.torque)): return _refuse("wrench")
		var serial: int = row.sample
		var age: int = posmod(_serial - serial, SAMPLE_SERIAL_LIMIT)
		var record: Dictionary = _history[serial % _history.size()]
		if age > MAX_AGE or record.get("serial") != serial or manual_step_count() - int(record.step) > MAX_AGE:
			actions.append({"id":row.id, "sample":serial, "refusal":"age"})
			continue
		var previous: int = _accepted_samples[slot]
		var forward: int = posmod(serial - previous, SAMPLE_SERIAL_LIMIT)
		if previous >= 0 and (forward == 0 or forward > SAMPLE_SERIAL_LIMIT / 2):
			actions.append({"id":row.id, "sample":serial, "refusal":"duplicate"})
			continue
		var sample: Dictionary = record.bodies[slot]
		if sample.com != row.com or sample.gravity != row.get("gravity") or sample.external_drive != row.get("external_drive") or not is_equal_approx(sample.mass, float(row.get("mass",-1))) or not is_equal_approx(sample.inertia,float(row.get("inertia",-1))): return _refuse("sample_properties")
		var direct := PhysicsServer2D.body_get_direct_state(_body_rids[slot])
		if direct == null: return _refuse("retired")
		var pose: Transform2D = direct.transform
		if not pose.is_finite(): return _refuse("nonfinite_pose")
		if not _within_sample_geometry(slot, sample.pose, pose):
			actions.append({"id":row.id, "sample":serial, "refusal":"geometry"})
			continue
		var correction: Vector2 = row.correction
		if correction.length_squared() <= MOTION_EPSILON_SQUARED: correction = Vector2.ZERO
		var torque: float = float(row.torque) + (row.com - pose * direct.center_of_mass_local - correction).cross(row.impulse)
		var scale: float = 1.0 / (1.0 + float(age) * 0.25)
		if not is_finite(torque) or not (Vector2(row.impulse) * scale).is_finite(): return _refuse("wrench")
		actions.append({"id":row.id, "instance_id":member.instance_id, "sample":serial, "age":age,
			"impulse":row.impulse * scale, "torque":torque * scale, "correction":correction})
	# Validate the complete batch before mutating any RID. A stale peer does
	# not spend another body's independently retained sample authority.
	_last_snapshot = snapshot_serial
	_last_results_applied = 0
	for action: Dictionary in actions:
		if action.has("refusal"): continue
		var slot: int = action.id - 1
		_accepted_samples[slot] = action.sample
		_apply(slot, action)
	last_application.bodies = actions
	last_application.accepted = actions.any(func(row: Dictionary) -> bool: return not row.has("refusal"))
	return _last_results_applied


func _within_sample_geometry(slot: int, sampled: Transform2D, current: Transform2D) -> bool:
	for rect: Dictionary in _rects[slot]:
		for sign_x: float in [-1.0,1.0]:
			for sign_y: float in [-1.0,1.0]:
				var corner: Vector2 = rect.center + rect.size * Vector2(sign_x, sign_y) * 0.5
				if (current * corner).distance_to(sampled * corner) > MAX_CORNER_TRAVEL: return false
	return true


func _apply(slot: int, action: Dictionary) -> void:
	var rid: RID = _body_rids[slot]
	var correction: Vector2 = action.correction
	if correction != Vector2.ZERO:
		var pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		pose.origin += correction
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, pose)
		_transforms[slot] = pose
		var velocity: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		if velocity.x * correction.x < 0: velocity.x = 0
		if velocity.y * correction.y < 0: velocity.y = 0
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)
	if action.impulse != Vector2.ZERO: PhysicsServer2D.body_apply_central_impulse(rid, action.impulse)
	if action.torque != 0.0: PhysicsServer2D.body_apply_torque_impulse(rid, action.torque)
	if correction != Vector2.ZERO or action.impulse != Vector2.ZERO or action.torque != 0.0:
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, false)
		_last_results_applied += 1


func shutdown() -> void:
	_session = 0
	_history.clear()
	super.shutdown()
