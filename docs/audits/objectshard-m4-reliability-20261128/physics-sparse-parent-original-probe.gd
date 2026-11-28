extends "res://tests/test_object_shard_m4_same_world_physical_chain.gd"

# Reuse only the existing actual-native setup/acknowledgement helpers. Every
# observed pose comes from real Rapier and every applied receipt from the same
# CyberNativeCellWorld. No synthetic native response, interpolated pose or
# semantic-time replay stands in for the collision.
var cases: Array[Dictionary] = []
var native_acknowledgements: int = 0

func _run() -> void:
	if not expect(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberDemoBridge") \
		and ClassDB.class_exists(RAPIER),"actual source-matched native World and pinned Rapier available"):
		_finish()
		return
	for horizontal: float in [.5]:
		if not _natural_native_case(horizontal): break
	_finish()

func _natural_native_case(horizontal: float) -> bool:
	world = ClassDB.instantiate(&"CyberNativeCellWorld")
	adapter = ClassDB.instantiate(&"CyberDemoBridge")
	var native_identity: int = world.get_instance_id()
	var sample: Dictionary = {"session":601,"epoch":601,"states":PackedFloat64Array(),
		"geometry":PackedFloat64Array(),"bodies":[]}
	var profile: Dictionary = Profiles.resolve(Profiles.preset(0))
	var options: Dictionary = {"workbench_extent":Vector2i(256,256),"workbench_response":"LA-SELECTIVE",
		"workbench_sample":sample,"region":PackedInt32Array([0,0,256,256]),"intent":"exploratory",
		"definition_hash":"m4-natural-small-fragment-collision-v1".sha256_text(),
		"initial_bodies":PackedFloat32Array(),"workbench_worker_threads":1}
	# The ordinary Metal ledge is a hard native surface outside the supported
	# structural-material roster, so only the Wood offcut may acquire an owner.
	var token: int = adapter.prepare_liquid_world(world,PackedInt32Array([0,240,256,8,1,20,180,8,2,28]),
		profile.packed,PackedInt32Array([1,8,12,0]),PackedInt32Array(),adapter.default_liquid_policy(),options)
	if not expect(token>0 and adapter.commit_liquid_world(world,token),"ordinary empty-roster native World with physical ledge prepared"): return false
	if not expect(world.simulation_tick() and world.object_shard_attach(Rect2i(0,0,256,256)).get("ok",false),
		"same-World coordinator attaches after one ordinary semantic tick"): return false
	for x: int in range(2,28):
		expect(world.object_shard_edit_cell(Vector2i(x,4),7,170,0,200).get("ok",false),"actual connected Wood strip authored above distant ledge")
	var prepared: Dictionary = _promote()
	if prepared.is_empty(): return false
	var shard: Dictionary = prepared.shards[0]
	var id: int = int(shard.id)
	expect(int(shard.width)==28 and int(shard.height)==3 and is_equal_approx(float(shard.mass),26.0),"native connected strip retains padded storage")
	main_space = PhysicsServer2D.space_create()
	PhysicsServer2D.space_set_active(main_space,false)
	bridge = ShardBridge.new()
	if not expect(bridge.initialize(int(prepared.session),main_space,16,256).get("ok",false),"Main owns real shared space"): return false
	if not expect(bridge.reserve_body(shard).get("ok",false) and world.object_shard_acknowledge(_ack(shard,"PhysicsReserved")).get("ok",false),
		"actual rigid reservation permits one native material debit"): return false
	var after_debit: Dictionary = world.object_shard_snapshot()
	shard = _current_shard(id)
	var installed: Dictionary = bridge.install_terrain(after_debit.terrain_chunks)
	if not expect(installed.get("ok",false),"actual postdebit terrain colliders installed and read back"): return false
	var ack: Dictionary = _ack(shard,"TerrainInstalled")
	var chunks: Array = []
	for required: Dictionary in after_debit.promotion.chunks:
		for actual: Dictionary in installed.chunks:
			if int(required.id)==int(actual.id): chunks.append(actual)
	ack.chunks = chunks
	if not expect(world.object_shard_acknowledge(ack).get("ok",false),"exact native terrain receipt accepted"): return false
	shard = _current_shard(id)
	if not expect(bridge.activate(shard).get("ok",false) and world.object_shard_acknowledge(_ack(shard,"BodyActivated")).get("ok",false),
		"one-cell physical owner activates after native debit and installed terrain"): return false
	if not _erode_left_to_single(id): return false
	shard = _current_shard(id)
	print("SPARSE_PARENT ",JSON.stringify({"width":shard.width,"height":shard.height,"mass":shard.mass,"inertia":shard.inertia,"com_x":shard.com_x,"com_y":shard.com_y,"rectangles":shard.rectangles,"origin_x":shard.position_x,"origin_y":shard.position_y}))
	var rid: RID = bridge.bodies[id].rid
	# A small existing horizontal drift; vertical speed and spin arise entirely
	# from ordinary gravity and the real off-centre collision below.
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(horizontal,0))
	var initial_tick: int = world.get_tick_index()
	var peak_angular: float = 0.0
	var maximum_segment_rotation: float = 0.0
	var previous_angle: float = 0.0
	var last_poses: Array = []
	var healthy: bool = true
	for step: int in range(480):
		var previous_pose: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
		ClassDB.class_call_static(RAPIER,&"space_step",main_space,1.0/240.0)
		ClassDB.class_call_static(RAPIER,&"space_flush_queries",main_space)
		physical_steps += 1
		var motion: Dictionary = bridge.capture_completed_main_step(step+1,1.0/240.0)
		if not motion.get("ok",false):
			var actual_pose: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
			var com: Vector2 = PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
			print("SPARSE_REFUSAL ",JSON.stringify({"step":step,"motion":motion,"com_translation":(actual_pose*com).distance_to(previous_pose*com),"origin_translation":actual_pose.origin.distance_to(previous_pose.origin),"rotation":wrapf(actual_pose.get_rotation()-previous_pose.get_rotation(),-PI,PI),"angular":PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)}))
			expect(false,"natural collision must yield bounded actual pose: "+str(motion))
			healthy = false
			break
		last_poses = motion.poses
		var tick_before_ack: int = world.get_tick_index()
		var applied: Dictionary = world.object_shard_accept_motion(last_poses)
		if not expect(bridge._valid_motion_receipt(applied,last_poses,tick_before_ack),"every real solver segment has its exact native applied-pose receipt"):
			healthy = false
			break
		native_acknowledgements += 1
		expect(world.get_tick_index()==tick_before_ack,"physical pose acknowledgement advances zero semantic time")
		var echoed: Dictionary = _current_shard(id)
		var pose: Dictionary = last_poses[0]
		expect(float(echoed.position_x)==float(pose.x) and float(echoed.position_y)==float(pose.y) \
			and float(echoed.rotation)==float(pose.rotation) and int(echoed.pose_serial)==int(pose.pose_serial),
			"independent full native readback equals actual completed physical pose")
		peak_angular = maxf(peak_angular,absf(float(pose.angular_velocity)))
		maximum_segment_rotation = maxf(maximum_segment_rotation,absf(float(pose.rotation)-previous_angle))
		previous_angle = float(pose.rotation)
		if step%4==3:
			if not expect(world.simulation_tick(),"one ordinary semantic tick follows four acknowledged physical segments"):
				healthy = false
				break
			expect(world.get_tick_index()==initial_tick+(step+1)/4,"native time progresses once per complete physical interval")
	var expected_ticks: int = 120
	expect(healthy and world.get_tick_index()==initial_tick+expected_ticks,"gravity fall, ledge impact and post-impact motion complete 120 native intervals")
	expect(peak_angular>50.0 and maximum_segment_rotation>.20,"native acknowledgements cover genuine collision-induced rotation beyond old ceiling")
	expect(_wood_count()==1 and world.get_instance_id()==native_identity,"exact original material inventory and native World identity survive impact")
	if healthy:
		var duplicate: Dictionary = world.object_shard_accept_motion(last_poses)
		expect(not duplicate.get("ok",true) and not duplicate.get("applied",true),"duplicate completed physical pose is refused without replay")
		expect(world.get_tick_index()==initial_tick+expected_ticks and _wood_count()==1,"duplicate refusal advances no time and loses no inventory")
	cases.append({"initial_horizontal_velocity":horizontal,"peak_angular_velocity":peak_angular,
		"maximum_segment_rotation":maximum_segment_rotation,"completed_native_intervals":world.get_tick_index()-initial_tick,
		"native_instance_id":native_identity,"healthy":healthy})
	bridge.shutdown()
	bridge = null
	PhysicsServer2D.free_rid(main_space)
	main_space = RID()
	world = null
	adapter = null
	return healthy

func _erode_left_to_single(id: int) -> bool:
	for local_x: int in range(1,26):
		var shard: Dictionary = _current_shard(id)
		var cell: int = int(shard.width)+local_x
		var request: Dictionary = {"session":shard.session,"id":shard.id,"generation":shard.generation,
			"sequence":world.object_shard_snapshot().next_transaction,"body_generation":shard.body_generation,
			"geometry_revision":shard.applied_physics_revision,"pose_serial":shard.pose_serial,
			"material_revision":shard.material_revision,"cell":cell,"incarnation":shard.incarnations[cell],
			"capability_version":1,"expected":{"material":shard.materials[cell],"state_a":shard.states_a[cell],
				"state_b":shard.states_b[cell],"temperature":shard.temperature[cell]}}
		if not expect(world.object_shard_erase_shard(request).get("ok",false),"ordinary exact moving-cell erase leaves a connected shorter strip"): return false
		var changed: Dictionary = _current_shard(id)
		if not expect(bridge.install_geometry(changed).get("ok",false) and world.object_shard_acknowledge(_ack(changed,"GeometryInstalled")).get("ok",false),"actual geometry installed and natively acknowledged before next cut"): return false
	return expect(is_equal_approx(float(_current_shard(id).mass),1.0),"repeated connected erosion leaves one actual carrier in the original parent")

func _finish() -> void:
	if bridge!=null: bridge.shutdown()
	bridge = null
	if main_space.is_valid(): PhysicsServer2D.free_rid(main_space)
	world = null
	adapter = null
	print(JSON.stringify({"schema":"objectshard-m4-sparse-parent-erosion-probe-v1","checks":checks,"failures":failures,
		"actual_physical_segments":physical_steps,"native_pose_acknowledgements":native_acknowledgements,
		"cases":cases,"platform":OS.get_name(),"engine":Engine.get_version_info(),
		"scope":"real same-World material debit, real gravity/ledge collision, every actual Rapier pose natively acknowledged, exact material inventory and single semantic clock"}))
	quit(0 if failures.is_empty() else 1)
