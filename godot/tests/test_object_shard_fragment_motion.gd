extends SceneTree

# Natural solver impulses on a one-cell offcut. Initial angular velocity is
# zero; landing partly beyond a ledge creates the spin. This reproduces the
# failure class, not the owner's exact unrecorded cutting sequence.
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
const RAPIER: StringName = &"RapierPhysicsServer2D"
const DELTA: float = 1.0/240.0
var checks: int = 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var session: int = 1900

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("OBJECTSHARD_FRAGMENT_MOTION: "+message)

func _box(width: int,height: int,position: Vector2) -> Dictionary:
	var mass: float = float(width*height)
	return {"session":session,"id":1,"generation":1,"body_generation":1,"transaction":1,
		"geometry_revision":1,"geometry_digest":"fragment-motion","rectangles":PackedInt32Array([0,0,width,height]),
		"width":width,"height":height,"origin_x":int(position.x),"origin_y":int(position.y),
		"position_x":position.x,"position_y":position.y,"rotation":0.0,"mass":mass,
		"com_x":width*.5,"com_y":height*.5,"inertia":mass*float(width*width+height*height)/12.0}

func _step(space: RID) -> void:
	ClassDB.class_call_static(RAPIER,&"space_step",space,DELTA)
	ClassDB.class_call_static(RAPIER,&"space_flush_queries",space)

func _run() -> void:
	_expect(ClassDB.class_exists(RAPIER),"actual pinned Rapier backend is available")
	if not failures.is_empty():
		_finish()
		return
	var old_limit_exceeded: int = 0
	var maximum_angular: float = 0.0
	for x: float in [27.0,27.2,27.4,27.6,27.8]:
		for speed: float in [60.0,100.0,140.0,180.0]:
			session += 1
			var bridge = Bridge.new()
			var space: RID = PhysicsServer2D.space_create()
			PhysicsServer2D.space_set_active(space,false)
			_expect(bridge.initialize(session,space).get("ok",false),"borrowed actual Rapier space initialized")
			_expect(bridge.install_terrain([{"id":0,"session":session,"revision":1,"digest":"ledge",
				"rectangles":PackedInt32Array([20,40,8,2])}]).get("ok",false),"real off-centre ledge installed")
			# Match native one-cell storage's empty one-cell ring and stable
			# material lattice origin. The physical shape itself is exactly1x1.
			var shard: Dictionary = _box(1,1,Vector2(x-1.0,37.6))
			shard.width = 3
			shard.height = 3
			shard.rectangles = PackedInt32Array([1,1,1,1])
			shard.com_x = 1.5
			shard.com_y = 1.5
			shard.vy = speed
			_expect(bridge.reserve_body(shard).get("ok",false) and bridge.activate(shard).get("ok",false),"unit fragment's mass COM inertia and real collider activated")
			var rid: RID = bridge.bodies[1].rid
			_expect(is_zero_approx(float(PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))),"initial spin is zero, never scripted")
			var maximum_segment: float = 0.0
			var last_angle: float = 0.0
			var result: Dictionary = {}
			var peak: float = 0.0
			for step: int in range(12):
				_step(space)
				var angular: float = float(PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
				peak = maxf(peak,absf(angular))
				result = bridge.capture_completed_main_step(step+1,DELTA)
				if not result.get("ok",false): break
				var pose: Dictionary = result.poses[0]
				maximum_segment = maxf(maximum_segment,absf(float(pose.rotation)-last_angle))
				last_angle = float(pose.rotation)
				_expect(is_equal_approx(float(pose.angular_velocity),angular),"capture preserves actual unclamped solver angular velocity")
			_expect(result.get("ok",false) and not bridge.motion_refused and bridge.steps==12,"natural collision and continuing spin stay operational: "+str([x,speed,result]))
			if maximum_segment>Bridge.MAX_SEGMENT_ROTATION: old_limit_exceeded += 1
			maximum_angular = maxf(maximum_angular,peak)
			cases.append({"x":x,"initial_downward_speed":speed,"peak_angular_velocity":peak,
				"maximum_segment_rotation":maximum_segment,"ok":result.get("ok",false),"physical_segments":bridge.steps})
			bridge.shutdown()
			PhysicsServer2D.free_rid(space)
	_expect(old_limit_exceeded>=5 and maximum_angular>60.0,"actual collisions exercise the original small-fragment failure class")
	_expect(is_equal_approx(Bridge.segment_rotation_limit(20.0),.20),"large or slender structures retain original angular ceiling")
	_expect(Bridge.segment_rotation_limit(.1)<=PI/2.0,"absolute observed rotation cannot exceed a quarter-turn")
	_expect(Bridge.segment_rotation_limit(INF)==0.0,"invalid geometry cannot receive a motion allowance")
	_natural_fall(1.0)
	_natural_fall(1.3)
	_refusal("large_rotation",20,1,Vector2.ZERO,60.0,"SegmentMotionEnvelopeExceeded")
	_refusal("translation",1,1,Vector2(1200,0),0.0,"SegmentMotionEnvelopeExceeded")
	_refusal("corner_motion",100,1,Vector2(0,1500),30.0,"SegmentMotionEnvelopeExceeded")
	_refusal("corrupt_angular_readback",1,1,Vector2.ZERO,1000.0,"UnresolvedCompleteRotation")
	_terrain_replacement_preserves_independent_actor()
	_finish()

func _natural_fall(horizontal: float) -> void:
	session += 1
	var bridge = Bridge.new()
	var space: RID = PhysicsServer2D.space_create()
	PhysicsServer2D.space_set_active(space,false)
	bridge.initialize(session,space)
	bridge.install_terrain([{"id":0,"session":session,"revision":1,"digest":"ledge",
		"rectangles":PackedInt32Array([20,40,8,2])}])
	var shard: Dictionary = _box(1,1,Vector2(26,3))
	shard.width = 3
	shard.height = 3
	shard.rectangles = PackedInt32Array([1,1,1,1])
	shard.com_x = 1.5
	shard.com_y = 1.5
	shard.vx = horizontal
	_expect(bridge.reserve_body(shard).get("ok",false) and bridge.activate(shard).get("ok",false),"natural fall starts with zero vertical and angular velocity")
	var peak: float = 0.0
	var maximum_angle: float = 0.0
	var previous: float = 0.0
	var result: Dictionary = {}
	for step: int in range(240):
		_step(space)
		peak = maxf(peak,absf(float(PhysicsServer2D.body_get_state(bridge.bodies[1].rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))))
		result = bridge.capture_completed_main_step(step+1,DELTA)
		if not result.get("ok",false): break
		maximum_angle = maxf(maximum_angle,absf(float(result.poses[0].rotation)-previous))
		previous = float(result.poses[0].rotation)
	_expect(result.get("ok",false) and bridge.steps==240 and not bridge.motion_refused,"gravity-generated ledge impact and continuing motion avoid protective halt")
	_expect(peak>50.0 and maximum_angle>.20,"gravity collision genuinely exercises angular displacement beyond old fixed ceiling")
	if horizontal>1.2:
		_expect(maximum_angle>2.0/Vector2(3,3).length(),"adversarial natural fall exercises the failed two-cell-arc trial")
	cases.append({"control":"natural-gravity-fall","initial_horizontal_velocity":horizontal,"peak_angular_velocity":peak,
		"maximum_segment_rotation":maximum_angle,"physical_segments":bridge.steps,"ok":result.get("ok",false)})
	bridge.shutdown()
	PhysicsServer2D.free_rid(space)

func _terrain_replacement_preserves_independent_actor() -> void:
	session += 1
	var bridge = Bridge.new()
	var space: RID = PhysicsServer2D.space_create()
	PhysicsServer2D.space_set_active(space,false)
	bridge.initialize(session,space)
	var chunk: Dictionary = {"id":0,"session":session,"revision":1,"digest":"floor-and-remote-support",
		"rectangles":PackedInt32Array([0,90,192,4,20,60,8,30])}
	_expect(bridge.install_terrain([chunk]).get("ok",false),"terrain replacement control installs floor and remote support in one chunk")
	# Independent physical actor, absent from the structural bridge registry.
	var actor: RID = PhysicsServer2D.body_create()
	var shape: RID = PhysicsServer2D.rectangle_shape_create()
	PhysicsServer2D.shape_set_data(shape,Vector2(4,7))
	PhysicsServer2D.body_add_shape(actor,shape)
	PhysicsServer2D.body_set_mode(actor,PhysicsServer2D.BODY_MODE_RIGID)
	PhysicsServer2D.body_set_state(actor,PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0,Vector2(160,70)))
	PhysicsServer2D.body_set_param(actor,PhysicsServer2D.BODY_PARAM_FRICTION,.78)
	PhysicsServer2D.body_set_space(actor,space)
	for step: int in range(720): _step(space)
	var resting: Transform2D = PhysicsServer2D.body_get_state(actor,PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(absf(resting.origin.y-83.0)<.1,"independent barrel settles naturally on unchanged floor")
	var maximum_displacement: float = 0.0
	var maximum_upward: float = 0.0
	for cut: int in range(8):
		chunk.revision = cut+2
		chunk.digest = "remote-cut-"+str(cut)
		chunk.rectangles = PackedInt32Array([0,90,192,4,20,60,8,22-cut])
		var previous_terrain: RID = bridge.terrain[0].rid
		_expect(bridge.install_terrain([chunk]).get("ok",false),"remote cut installs replacement static geometry")
		_expect(bridge.terrain[0].rid!=previous_terrain and PhysicsServer2D.body_get_shape_count(bridge.terrain[0].rid)==2,
			"replacement has exactly the two current shapes and no retained old collider")
		for step: int in range(60):
			_step(space)
			var pose: Transform2D = PhysicsServer2D.body_get_state(actor,PhysicsServer2D.BODY_STATE_TRANSFORM)
			var velocity: Vector2 = PhysicsServer2D.body_get_state(actor,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			maximum_displacement = maxf(maximum_displacement,pose.origin.distance_to(resting.origin))
			maximum_upward = maxf(maximum_upward,-velocity.y)
	_expect(bridge.bodies.is_empty(),"independent barrel never becomes a structural owner")
	_expect(maximum_displacement<.1 and maximum_upward<1.0,"same-chunk remote static replacement does not launch an independent barrel")
	cases.append({"control":"same-chunk-terrain-replacement","maximum_barrel_displacement":maximum_displacement,
		"maximum_barrel_upward_speed":maximum_upward,"replacements":8})
	PhysicsServer2D.free_rid(actor)
	PhysicsServer2D.free_rid(shape)
	bridge.shutdown()
	PhysicsServer2D.free_rid(space)

func _refusal(label: String,width: int,height: int,velocity: Vector2,angular: float,expected: String) -> void:
	session += 1
	var bridge = Bridge.new()
	var space: RID = PhysicsServer2D.space_create()
	PhysicsServer2D.space_set_active(space,false)
	bridge.initialize(session,space)
	var shard: Dictionary = _box(width,height,Vector2(20,20))
	shard.vx = velocity.x
	shard.vy = velocity.y
	shard.angular_velocity = angular
	_expect(bridge.reserve_body(shard).get("ok",false) and bridge.activate(shard).get("ok",false),"negative-control actual body installs: "+label)
	_step(space)
	if label=="corrupt_angular_readback":
		# Rapier bounds its own per-step angular speed, so a natural completed
		# step cannot supply this corruption. Inject it explicitly after the
		# genuine step to exercise the existing unresolvable-readback guard.
		PhysicsServer2D.body_set_state(bridge.bodies[1].rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,angular)
	var refused: Dictionary = bridge.capture_completed_main_step(1,DELTA)
	_expect(not refused.get("ok",false) and refused.get("outcome","")==expected and bridge.motion_refused,"unsafe actual segment retains protective refusal: "+label)
	_expect(bridge.pose_serial==0 and bridge.steps==0,"refusal cannot mint a native pose or claim applied time: "+label)
	cases.append({"negative_control":label,"receipt":refused})
	bridge.shutdown()
	PhysicsServer2D.free_rid(space)

func _finish() -> void:
	print(JSON.stringify({"schema":"objectshard-fragment-motion-v1","checks":checks,"failures":failures,
		"cases":cases,"platform":OS.get_name(),"engine":Engine.get_version_info(),
		"scope":"actual Rapier natural off-centre collision, bridge readback and protective envelope controls; native ACK is independently covered by coordinator/integration suites"}))
	quit(0 if failures.is_empty() else 1)
