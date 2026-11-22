extends SceneTree

# Actual pinned Rapier execution; the receipt factory is an explicit adapter
# fixture, not a substitute for the separate worker/native ownership tests.
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
var checks: int = 0
var failures: int = 0
var bridge
var shard: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	bridge = Bridge.new()
	_expect(bridge.initialize(901).get("ok", false), "actual Rapier space opened")
	var result: Dictionary = bridge.begin_motion_tick(42)
	_expect(result.get("ok", false) and result.get("finished", false) and bridge.steps == 1,
		"empty space completes one actual step without an invented native receipt")
	_setup(902)
	var rid: RID = bridge.bodies[1].rid
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(600.0, 0.0))
	var start: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	result = bridge.begin_motion_tick(42)
	_expect(result.get("ok", false) and not result.finished and bridge.steps == 0,
		"begin reserves an operation but cannot advance an owned body")
	var operation: int = int(result.operation_sequence)
	var segment: Dictionary = bridge.advance_motion_segment()
	_expect(segment.get("ok", false) and bridge.steps == 1 and not segment.finished,
		"advance performs exactly one bounded actual solver segment")
	var receipt: Dictionary = _receipt(segment.poses, 42)
	var segment_serial: int = int(segment.segment_sequence)
	var waiting_pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var waiting_serial: int = bridge.pose_serial
	# Public messages are detached values. Mutating a caller's copy cannot
	# alter the private expected identity that authorizes the next solver step.
	segment.poses[0].pose_serial = -1
	segment.poses[0].generation = 9000
	var changed: Dictionary = shard.duplicate(true)
	changed.geometry_revision = 2
	changed.geometry_digest = "forbidden-mid-segment"
	for frame: int in range(6):
		await process_frame
		_expect(not bridge.advance_motion_segment().get("ok", false), "delayed native ACK blocks further segments")
		_expect(not bridge.step().get("ok", false) and not bridge.begin_motion_tick(42).get("ok", false),
			"neither legacy stepping nor a second operation bypasses the barrier")
		_expect(not bridge.install_geometry(changed).get("ok", false)
			and not bridge.install_terrain([]).get("ok", false)
			and not bridge.reserve_body(shard).get("ok", false)
			and not bridge.activate(shard).get("ok", false)
			and not bridge.remove_body(1).get("ok", false),
			"material geometry and body roster stay fixed while an applied receipt is pending")
		var inspected: Dictionary = bridge.diagnostics()
		_expect(bridge.sample_poses().is_empty() and bridge.pose_serial == waiting_serial
			and inspected.awaiting_native and bridge.steps == 1,
			"inspection cannot mint a competing admission serial or advance time")
		var held: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		_expect(held == waiting_pose, "actual Rapier pose stays unchanged while main polls controls")
	_expect(not bridge.initialize(-1).get("ok", false) and bridge.bodies[1].rid == rid,
		"invalid session request cannot dispose a pending body")
	result = bridge.acknowledge_motion_segment(receipt)
	_expect(result.get("ok", false) and not result.finished and bridge.steps == 1,
		"exact native application unlocks the next segment without stepping itself")
	var applied: int = int(result.motion.applied_segments)
	_expect(not bridge.acknowledge_motion_segment(receipt).get("ok", false)
		and int(bridge.last_motion.applied_segments) == applied and bridge.motion_phase == "Ready",
		"duplicate receipt in Ready is a nonmutating typed refusal")
	while not result.finished:
		segment = bridge.advance_motion_segment()
		_expect(segment.get("ok", false) and int(segment.operation_sequence) == operation
			and int(segment.segment_sequence) > segment_serial,
			"all segments retain one operation and monotonic independent identities")
		segment_serial = int(segment.segment_sequence)
		result = bridge.acknowledge_motion_segment(_receipt(segment.poses, 42))
		_expect(result.get("ok", false), "every later segment consumes its own exact application receipt")
	var final_pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(absf(final_pose.origin.x - start.origin.x - 10.0) < 0.01
		and int(result.motion.substeps) <= Bridge.MAX_MOTION_SUBSTEPS,
		"delayed acknowledgements preserve complete unclamped motion within the original work cap")
	_expect(is_equal_approx(float(result.motion.applied_delta), Bridge.FIXED_DELTA)
		and is_equal_approx(float(result.motion.completed_delta), Bridge.FIXED_DELTA),
		"fully completed interval records both actual and native-applied time")
	var finished_steps: int = bridge.steps
	_expect(bridge.advance_motion_segment().get("finished", false) and bridge.steps == finished_steps,
		"completed operation cannot step again without an explicit new begin")
	_expect(not bridge.acknowledge_motion_segment(receipt).get("ok", false) and not bridge.motion_refused,
		"late duplicate after completion does not poison a healthy session")
	var completed_operation: int = bridge.motion_operation_sequence
	_expect(not bridge.begin_motion_tick(42).get("ok", false)
		and not bridge.begin_motion_tick(41).get("ok", false)
		and bridge.steps == finished_steps and bridge.motion_operation_sequence == completed_operation,
		"repeated or older native tick cannot create another physics interval")

	# Explicit whole-session disposal is the sole cancellation/reset path after
	# actual movement. Old receipts never authorize replacement owner geometry.
	_setup(903)
	bridge.begin_motion_tick(42)
	segment = bridge.advance_motion_segment()
	var obsolete: Dictionary = _receipt(segment.poses, 42)
	var obsolete_serial: int = int(segment.poses[0].pose_serial)
	bridge.shutdown()
	_expect(not bridge.acknowledge_motion_segment(obsolete).get("ok", false)
		and bridge.bodies.is_empty() and not bridge.space.is_valid(),
		"shutdown retires pending physics; delayed ACK cannot resurrect its RIDs")
	_expect(not bridge.initialize(903).get("ok", false) and bridge.bodies.is_empty(),
		"shutdown cannot make a retired native session eligible again")
	_setup(904)
	bridge.begin_motion_tick(42)
	segment = bridge.advance_motion_segment()
	_expect(int(segment.poses[0].pose_serial) > obsolete_serial, "pose identities never recycle across reinitialization")
	finished_steps = bridge.steps
	result = bridge.acknowledge_motion_segment(obsolete)
	_expect(not result.get("ok", false) and bridge.motion_refused and bridge.steps == finished_steps,
		"old-session work cannot satisfy new pending owner geometry")
	_expect(not bridge.advance_motion_segment().get("ok", false) and bridge.steps == finished_steps,
		"invalid actual-segment receipt holds the clocks without undoing its real movement")

	_setup(905)
	bridge.begin_motion_tick(42)
	segment = bridge.advance_motion_segment()
	receipt = _receipt(segment.poses, 43)
	_expect(not bridge.acknowledge_motion_segment(receipt).get("ok", false)
		and int(bridge.last_motion.applied_segments) == 0,
		"a wrong semantic clock cannot be acknowledged as current material application")
	_setup(906)
	bridge.begin_motion_tick(42)
	segment = bridge.advance_motion_segment()
	bridge.bodies[1].geometry_revision = 2 # Deliberately corrupt the host roster.
	result = bridge.acknowledge_motion_segment(_receipt(segment.poses, 42))
	_expect(not result.get("ok", false) and result.outcome == "MotionOwnerRosterChanged",
		"unexpected owner/geometry changes cannot inherit an earlier segment receipt")

	_setup(907)
	var thread := Thread.new()
	_expect(thread.start(_wrong_thread) == OK, "foreign-thread refusal fixture starts")
	while thread.is_alive():
		await process_frame
	var foreign: Dictionary = thread.wait_to_finish()
	_expect(not foreign.get("ok", false) and foreign.outcome == "MainPhysicsOwnerRequired" and bridge.steps == 0,
		"foreign thread is rejected before reading or operating shared Rapier state")
	_expect(not bridge.begin_motion_tick(-1).get("ok", false) and bridge.steps == 0,
		"unknown native clock cannot advance a production motion interval")
	bridge.shutdown()
	_compare_synchronous_control()
	print(JSON.stringify({"schema": "objectshard-incremental-motion-test-v1", "checks": checks,
		"failures": failures, "engine": Engine.get_version_info(), "platform": OS.get_name()}))
	quit(failures)


func _setup(incarnation: int) -> void:
	_expect(bridge.initialize(incarnation).get("ok", false), "new actual Rapier fixture")
	shard = _shard(incarnation)
	_expect(bridge.reserve_body(shard).get("ok", false) and bridge.activate(shard).get("ok", false),
		"bounded compound reserved and activated")
	PhysicsServer2D.body_set_param(bridge.bodies[1].rid, PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE, 0.0)


func _shard(incarnation: int) -> Dictionary:
	return {"session": incarnation, "id": 1, "generation": 1, "body_generation": 1,
		"transaction": 1, "geometry_revision": 1, "geometry_digest": "incremental-fixture",
		"rectangles": PackedInt32Array([0, 0, 2, 2]), "width": 2, "height": 2,
		"origin_x": 70, "origin_y": 20, "position_x": 70.0, "position_y": 20.0, "rotation": 0.0,
		"mass": 4.0, "com_x": 1.0, "com_y": 1.0, "inertia": 8.0 / 3.0}


func _receipt(poses: Array, tick: int) -> Dictionary:
	var accepted: Array = []
	for pose: Dictionary in poses:
		var row: Dictionary = {}
		for key: String in ["session", "id", "generation", "body_generation", "geometry_revision", "pose_serial"]:
			row[key] = int(pose[key])
		accepted.append(row)
	return {"ok": true, "applied": true, "semantic_tick": tick, "accepted_pose_serials": accepted}


func _wrong_thread() -> Dictionary:
	return bridge.advance_motion_segment()


func _compare_synchronous_control() -> void:
	var control = Bridge.new()
	var incremental = Bridge.new()
	for host in [control, incremental]:
		_expect(host.initialize(1001).get("ok", false), "comparison space initialized")
		var body: Dictionary = _shard(1001)
		_expect(host.reserve_body(body).get("ok", false) and host.activate(body).get("ok", false), "comparison body activated")
		PhysicsServer2D.body_set_param(host.bodies[1].rid, PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE, 0.0)
		PhysicsServer2D.body_set_state(host.bodies[1].rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(123.0, 0.0))
		PhysicsServer2D.body_set_state(host.bodies[1].rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.5)
	for tick: int in range(60):
		var sync: Dictionary = control.step_motion(_receipt.bind(tick), tick)
		var async: Dictionary = incremental.begin_motion_tick(tick)
		while async.get("ok", false) and not async.get("finished", false):
			var next: Dictionary = incremental.advance_motion_segment()
			if not next.get("ok", false):
				async = next
				break
			async = incremental.acknowledge_motion_segment(_receipt(next.poses, tick))
		_expect(sync.get("ok", false) and async.get("ok", false), "synchronous and incremental controls both complete actual physics")
	var left: Transform2D = PhysicsServer2D.body_get_state(control.bodies[1].rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var right: Transform2D = PhysicsServer2D.body_get_state(incremental.bodies[1].rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(left == right and control.steps == incremental.steps,
		"same-state-machine controls produce byte-identical actual Rapier transforms after 60 intervals")
	control.shutdown()
	incremental.shutdown()


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
