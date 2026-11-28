extends SceneTree

# Real Rapier adapter tests. The receipt observer below is deliberately a unit
# boundary; native ownership/contact qualification is a separate actual-Lab test.
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
var checks: int = 0
var failures: int = 0
var bridge: CyberObjectShardPhysicsBridge
var previous: Dictionary = {}
var receipts: int = 0
var receipt_fault: String = ""
var observed_max_translation: float = 0.0
var observed_max_rotation: float = 0.0
var observed_max_corner: float = 0.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	bridge = Bridge.new()
	_expect(bridge.initialize(801).get("ok", false), "actual Rapier space initialized")
	var result: Dictionary = bridge.step_motion(_accept, 42)
	_expect(result.get("ok", false) and receipts == 0 and int(result.motion.substeps) == 1,
		"empty space has one actual step and no redundant native mask receipt")
	_setup(802, 2, 2)
	var rid: RID = bridge.bodies[1].rid
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(600.0, 0.0))
	var start: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	result = bridge.step_motion(_accept, 42)
	var moved: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(result.get("ok", false) and receipts >= 5 and receipts <= Bridge.MAX_MOTION_SUBSTEPS,
		"fast translation is admitted through bounded actual solver segments")
	_expect(absf(moved.origin.x - start.origin.x - 10.0) < 0.01,
		"fast motion advances the complete semantic interval without a velocity clamp")
	_expect(observed_max_translation <= 4.0 and observed_max_corner <= 8.0,
		"every observed translation and swept corner remains inside existing native guards")
	_expect(is_equal_approx(float(result.motion.completed_delta), Bridge.FIXED_DELTA),
		"completed simulated time equals one semantic interval")
	_setup(803, 2, 2)
	rid = bridge.bodies[1].rid
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 30.0)
	result = bridge.step_motion(_accept, 42)
	moved = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(result.get("ok", false) and observed_max_rotation <= 0.20,
		"legitimate half-radian motion is admitted as bounded actual rotations")
	_expect(absf(moved.get_rotation() - 0.5) < 0.001, "angular motion is not clamped or discarded")
	# A hundred-cell compound makes the physical COM-to-corner budget stricter
	# than the nominal angular budget even with the corrected reference frame.
	_setup(804, 100, 100)
	rid = bridge.bodies[1].rid
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 30.0)
	result = bridge.step_motion(_accept, 42)
	_expect(result.get("ok", false) and receipts > 5 and receipts <= Bridge.MAX_MOTION_SUBSTEPS,
		"large bounds select additional segments for the corner sweep guard")
	_expect(observed_max_corner <= 8.0 and observed_max_translation <= 4.0,
		"large rotating compound never relies only on the angular guard")
	var serial: int = bridge.pose_serial
	var inspection: Dictionary = bridge.diagnostics()
	_expect(bridge.pose_serial == serial and int(inspection.last_sampled_pose_serial) == serial,
		"diagnostic inspection cannot mint a material-admission pose serial")
	_setup(805, 2, 2)
	rid = bridge.bodies[1].rid
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(10000.0, 0.0))
	start = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var before_steps: int = bridge.steps
	result = bridge.step_motion(_accept, 42)
	moved = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(not result.get("ok", false) and str(result.outcome) == "MotionSubstepCapacity",
		"unbounded requested work receives an explicit resource refusal")
	_expect(bridge.steps == before_steps and moved.is_equal_approx(start) and receipts == 0,
		"known over-budget motion is refused before physics advances")
	_expect(float(result.motion.completed_delta) == 0.0 and int(result.motion.maximum_substeps) == 16,
		"refusal exposes simulated time and the unchanged bounded resource ceiling")
	# Each fixture represents an acknowledged fresh native session. Session IDs
	# cannot be reused to clear the M3 motion clock/retirement watermark.
	var fault_session: int = 806
	for fault: String in ["missing-owner", "stale-serial", "wrong-tick", "duplicate-owner", "not-applied"]:
		_setup(fault_session, 2, 2)
		fault_session += 1
		receipt_fault = fault
		result = bridge.step_motion(_accept, 42)
		_expect(not result.get("ok", false) and str(result.outcome) == "NativeSegmentRefused",
			"invalid applied receipt is held: " + fault)
		_expect(receipts == 1 and int(result.motion.applied_segments) == 0,
			"no later solver segment follows an invalid admission receipt: " + fault)
		before_steps = bridge.steps
		bridge.step_motion(_accept, 42)
		_expect(bridge.steps == before_steps and bridge.sample_poses().is_empty(),
			"held clocks cannot silently resume after refused physics: " + fault)
	bridge.shutdown()
	print(JSON.stringify({"schema": "objectshard-motion-segment-test-v1", "engine": Engine.get_version_info(),
		"checks": checks, "failures": failures, "platform": OS.get_name()}))
	quit(failures)


func _setup(incarnation: int, width: int, height: int) -> void:
	_expect(bridge.initialize(incarnation).get("ok", false), "new motion fixture")
	previous.clear()
	receipts = 0
	receipt_fault = ""
	observed_max_translation = 0.0
	observed_max_rotation = 0.0
	observed_max_corner = 0.0
	var mass: float = float(width * height)
	var shard: Dictionary = {"session": incarnation, "id": 1, "generation": 1, "body_generation": 1,
		"transaction": 1, "geometry_revision": 1, "geometry_digest": "unit-fixture",
		"rectangles": PackedInt32Array([0, 0, width, height]), "width": width, "height": height,
		"origin_x": 70, "origin_y": 20, "position_x": 70.0, "position_y": 20.0, "rotation": 0.0,
		"mass": mass, "com_x": float(width) * 0.5, "com_y": float(height) * 0.5,
		"inertia": mass * float(width * width + height * height) / 12.0}
	_expect(bridge.reserve_body(shard).get("ok", false) and bridge.activate(shard).get("ok", false),
		"actual compound reserved and activated")
	PhysicsServer2D.body_set_param(bridge.bodies[1].rid, PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE, 0.0)
	for pose: Dictionary in bridge.sample_poses():
		previous[int(pose.id)] = pose


func _accept(poses: Array) -> Dictionary:
	receipts += 1
	var accepted: Array[Dictionary] = []
	for pose: Dictionary in poses:
		var before: Dictionary = previous[int(pose.id)]
		var body: Dictionary = bridge.bodies[int(pose.id)]
		var com: Vector2 = PhysicsServer2D.body_get_param(body.rid,PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
		var current := Transform2D(float(pose.rotation),Vector2(float(pose.x),float(pose.y)))
		var prior := Transform2D(float(before.rotation),Vector2(float(before.x),float(before.y)))
		var distance: float = (current*com).distance_to(prior*com)
		var rotation: float = absf(float(pose.rotation) - float(before.rotation))
		var corner: float = distance + float(body.motion_radius) * rotation
		observed_max_translation = maxf(observed_max_translation, distance)
		observed_max_rotation = maxf(observed_max_rotation, rotation)
		observed_max_corner = maxf(observed_max_corner, corner)
		previous[int(pose.id)] = pose
		var identity: Dictionary = {}
		for key: String in ["session", "id", "generation", "body_generation", "geometry_revision", "pose_serial"]:
			identity[key] = int(pose[key])
		accepted.append(identity)
	if receipt_fault == "missing-owner":
		accepted.clear()
	elif receipt_fault == "stale-serial":
		accepted[0].pose_serial = int(accepted[0].pose_serial) - 1
	elif receipt_fault == "duplicate-owner":
		accepted.append(accepted[0].duplicate())
	return {"ok": true, "applied": receipt_fault != "not-applied", "semantic_tick": 43 if receipt_fault == "wrong-tick" else 42,
		"accepted_pose_serials": accepted}


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
