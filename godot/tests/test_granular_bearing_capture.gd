extends "res://tests/test_ejection_topology_capture.gd"

# Measurement owner only. Every physics/cellular parameter is inherited from A2.
const SNAP_ORIGIN := Vector2i(92, 0)
const SNAP_SIZE := Vector2i(40, 212)
var _details: bool = false


func _motion(body: RigidBody2D) -> Array:
	var pose: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	return [pose.origin.x, pose.origin.y, pose.get_rotation(), velocity.x, velocity.y,
		PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)]


func _backend(body: RigidBody2D) -> Dictionary:
	var state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(body.get_rid())
	if state == null:
		return {"available":false}
	var contacts: Array = []
	var rotation: float = state.transform.get_rotation()
	for index: int in range(state.get_contact_count()):
		var normal: Vector2 = state.get_contact_local_normal(index)
		var position: Vector2 = state.get_contact_local_position(index)
		var impulse: Vector2 = state.get_contact_impulse(index)
		var world_normal := normal.rotated(rotation)
		contacts.append({"local_normal":[normal.x,normal.y],"rotated_normal":[world_normal.x,world_normal.y],
			"reported_position":[position.x,position.y],"reported_impulse":[impulse.x,impulse.y]})
	return {"available":true,"gravity":[state.total_gravity.x,state.total_gravity.y],
		"boundary":"after cellular API calls; contacts belong to preceding Rapier step",
		"linear_damp":state.total_linear_damp,"angular_damp":state.total_angular_damp,
		"step":state.step,"constant_force":[state.get_constant_force().x,state.get_constant_force().y],
		"constant_torque":state.get_constant_torque(),"contacts":contacts,
		"contact_capacity":16,"at_capacity":state.get_contact_count() >= 16}


func _cell(snapshot: Dictionary, x: int, y: int) -> int:
	if x < SNAP_ORIGIN.x or x >= SNAP_ORIGIN.x + SNAP_SIZE.x or y < 0 or y >= SNAP_SIZE.y:
		return -1
	return int(snapshot.cells[y * SNAP_SIZE.x + x - SNAP_ORIGIN.x])


func _mask_geometry(world: Object, before: Dictionary, after: Dictionary,
		input: PackedFloat32Array, previous: Dictionary) -> Dictionary:
	var center := Vector2(input[1], input[2])
	var angle: float = input[3]
	var half_size := Vector2(input[4],input[5]) * 0.5
	var extent := Vector2(absf(cos(angle))*half_size.x+absf(sin(angle))*half_size.y,
		absf(sin(angle))*half_size.x+absf(cos(angle))*half_size.y)
	var overlap: Dictionary = {}
	var post_overlap: int = 0
	var mask_cells: int = 0
	for y: int in range(floori(center.y-extent.y),ceili(center.y+extent.y)):
		for x: int in range(floori(center.x-extent.x),ceili(center.x+extent.x)):
			if world.rigid_body_id_at(x,y) != 1:
				continue
			mask_cells += 1
			if _cell(before,x,y) == CyberCellWorld.SAND:
				overlap["%d,%d" % [x,y]] = true
			if _cell(after,x,y) == CyberCellWorld.SAND:
				post_overlap += 1
	var persistent: int = 0
	for key: String in overlap:
		if previous.has(key):
			persistent += 1
	var corners: Array[Vector2] = []
	for local: Vector2 in [Vector2(-4,-7),Vector2(4,-7),Vector2(4,7),Vector2(-4,7)]:
		corners.append(center + local.rotated(angle))
	var contour: Array = []
	for x: int in range(maxi(96,floori(center.x-extent.x)),mini(128,ceili(center.x+extent.x))):
		var column_x: float = x + 0.5
		var lower: float = -INF
		for edge: int in range(4):
			var a: Vector2 = corners[edge]
			var b: Vector2 = corners[(edge+1)%4]
			if absf(b.x-a.x) < 0.00000001:
				continue
			var fraction: float = (column_x-a.x)/(b.x-a.x)
			if fraction >= 0.0 and fraction <= 1.0:
				lower = maxf(lower,a.y+(b.y-a.y)*fraction)
		if not is_finite(lower):
			continue
		var top_sand: int = -1
		for y: int in range(1,208):
			if _cell(before,x,y) == CyberCellWorld.SAND:
				top_sand = y
				break
		if top_sand >= 0:
			contour.append([x,top_sand,lower,lower-top_sand])
	return {"mask_cells":mask_cells,"pre_overlap":overlap.size(),"post_ejection_overlap":post_overlap,
		"persistent_overlap":persistent,"new_overlap":overlap.size()-persistent,
		"lower_extent":center.y+extent.y,"initial_surface_entry":center.y+extent.y-160,
		"pre_ejection_contour_columns":contour,"overlap_keys":overlap}


func _capture_case(name: String, world: Object, directory: String) -> Dictionary:
	world.set_simulation_window(Vector2i(92,0),Vector2i(40,212),0,0)
	for rectangle: Array in [[95,0,1,209],[128,0,1,209],[95,208,34,1],[95,0,34,1]]:
		_check(world.diagnostic_fill_rect(Vector2i(rectangle[0],rectangle[1]),Vector2i(rectangle[2],rectangle[3]),CyberCellWorld.WALL),"fixture hard fill")
	_check(world.diagnostic_fill_rect(Vector2i(96,160),Vector2i(32,48),CyberCellWorld.SAND),"fixture Sand fill")
	_check(world.diagnostic_ejection_stream(),"event stream enable")
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(128,128)
	root.add_child(viewport)
	var body := RigidBody2D.new()
	body.mass = 1.0
	body.gravity_scale = 0.094
	body.linear_damp = 0.15
	body.angular_damp = 0.35
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.max_contacts_reported = 16 if _details else 0
	var initial := Vector2(112,97 if name == "drop4" else 139)
	var velocity := Vector2.ZERO
	var angular_velocity: float = 1.0
	if name.begins_with("speed"):
		initial.y = 160.0-2.0-(absf(cos(0.08))*7.0+absf(sin(0.08))*4.0)
		velocity.y = float(name.substr(5))
		angular_velocity = 0.0
	body.position = initial
	body.rotation = 0.08
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8,14)
	collision.shape = shape
	body.add_child(collision)
	viewport.add_child(body)
	await process_frame
	var bridge := CyberRapierPhysicsBridge.new()
	var bodies: Array[RigidBody2D] = [body]
	_check(bridge.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(8,14)])) == OK,"bridge initialize")
	bridge.enable_diagnostics(_details)
	bridge.reset_body(0,initial,0.08)
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,angular_velocity)
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,velocity)
	bridge.refresh_all_states()
	bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
	var baseline: Dictionary = world.diagnostic_snapshot(SNAP_ORIGIN,SNAP_SIZE)
	var frames: Array = []
	var previous_overlap: Dictionary = {}
	var event_file := FileAccess.open(directory+"/events.jsonl",FileAccess.WRITE)
	_check(event_file != null,"event file open")
	var total_events: int = 0
	var raw_unresolved: int = 0
	var raw_displaced: int = 0
	var peak_pending: int = 0
	for tick: int in range(600):
		_watchdog.publish("%s tick=%d" % [name,tick])
		var before_step: Array = _motion(body)
		var step_start: int = Time.get_ticks_usec()
		bridge.step()
		var after_step: Array = _motion(body)
		var input: PackedFloat32Array = bridge.pack_body_states() # Exactly one sample.
		var pre: Dictionary = world.diagnostic_snapshot(SNAP_ORIGIN,SNAP_SIZE) if _details else {}
		world.prepare_rigid_body_coupling(input,true)
		var producer_usec: int = Time.get_ticks_usec()
		var metrics: Array = world.diagnostic_body_metrics()
		var pre_results: Array = Array(world.rigid_body_results())
		var bearing: Dictionary = world.diagnostic_bearing_state() if _details else {}
		var post: Dictionary = world.diagnostic_snapshot(SNAP_ORIGIN,SNAP_SIZE) if _details else {}
		var geometry: Dictionary = _mask_geometry(world,pre,post,input,previous_overlap) if _details else {}
		if _details:
			previous_overlap = geometry.overlap_keys
			geometry.erase("overlap_keys")
			_check(geometry.mask_cells == bearing.mask_cells,"native/test mask mismatch")
			_check(int(bearing.probe_drops) == 0,"support probe capacity lost values")
		var batch: Dictionary = world.diagnostic_take_ejection_events()
		_check(int(batch.stream_total_limit) == 8192 and batch.has("capture_instance_id"),"stream version fence")
		peak_pending = maxi(peak_pending,batch.capsules.size())
		for capsule: Dictionary in batch.capsules:
			event_file.store_line(JSON.stringify(capsule,"",false,true))
			total_events += 1
		raw_unresolved += int(world.get_rigid_body_unresolved_last_tick())
		raw_displaced += int(world.get_rigid_body_displaced_last_tick())
		_check(world.simulation_tick(),"native tick failed")
		var results: PackedFloat32Array = world.rigid_body_results()
		var after_metrics: Array = world.diagnostic_body_metrics()
		bridge.apply_cellular_results(tick+1,results)
		var final_snapshot: Dictionary = world.diagnostic_snapshot(SNAP_ORIGIN,SNAP_SIZE)
		_check(final_snapshot.counts == baseline.counts,"stored material conservation failed")
		if _details:
			_check(pre.counts == baseline.counts and post.counts == baseline.counts,"coupling material conservation failed")
			var masked_after_tick: int = 0
			for y: int in range(maxi(0,floori(input[2]-10)),mini(212,ceili(input[2]+10))):
				for x: int in range(maxi(92,floori(input[1]-10)),mini(132,ceili(input[1]+10))):
					if world.rigid_body_id_at(x,y) == 1 and _cell(final_snapshot,x,y) == CyberCellWorld.SAND:
						masked_after_tick += 1
			geometry["post_tick_overlap_at_packed_pose"] = masked_after_tick
		var row: Dictionary = {"tick":tick,"body_input":Array(input),"before_step":before_step,
			"after_step":after_step,"pre_tick_metrics":metrics,"pre_tick_results":pre_results,
			"post_tick_metrics":after_metrics,"requested_results":Array(results),
			"bridge_application":Array(bridge.diagnostic_applications),"after_application":_motion(body),
			"physical_hash":world.get_physical_state_hash(),"events":batch.capsules.size(),
			"stored_counts":final_snapshot.counts,"attempted_tick":final_snapshot.attempted_ticks,
			"completed_tick":final_snapshot.completed_ticks}
		if _details:
			row["bearing"] = bearing
			row["geometry"] = geometry
			row["application_details"] = bridge.diagnostic_application_details.duplicate(true)
			row["backend"] = _backend(body)
			row["producer_usec"] = producer_usec
			row["step_start_usec"] = step_start
		frames.append(row)
		if tick % 60 == 59:
			await process_frame
	event_file.close()
	var counters: Dictionary = world.diagnostic_ejection_corpus()
	_check(int(counters.dropped) == 0 and int(counters.attempts) == total_events,"event loss")
	counters["complete"] = not _failed
	counters["maximum_pending_seen"] = peak_pending
	counters["events_written"] = total_events
	var fixture: Dictionary = {"name":name,"left":96,"surface":160,"width":32,"depth":48,
		"body_size":[8,14],"mass":1,"ticks":600,"workers":1,"real_rapier":true,
		"initial_position":[initial.x,initial.y],"initial_rotation":0.08,"initial_velocity":[velocity.x,velocity.y],
		"initial_angular_velocity":angular_velocity,"raw_unresolved":raw_unresolved,"raw_displaced":raw_displaced}
	counters["fixture"] = fixture
	var acquisition: Dictionary = {"complete":not _failed,"fixture":fixture,"native_counters":counters,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"mode":"acquire","details":_details}
	_write(directory+"/acquisition.json",acquisition)
	_write(directory+"/trajectory.json",{"frames":frames,"fixture":fixture,"details":_details})
	bridge.shutdown()
	viewport.queue_free()
	await process_frame
	return {"ok":not _failed,"arm":name,"events":total_events,"no_target":counters.searched_no_target,
		"success":counters.target_found,"details":_details,"frames":frames.size()}


func _replay_series() -> void:
	var path: String = _argument("--capsule-input=")
	var corpus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var world: Object = _new_world()
	var fallback := CyberCellWorld.new()
	var physical: String = world.get_physical_state_hash()
	var revision: int = world.get_revision()
	var matched: int = 0
	for capsule: Dictionary in corpus.capsules:
		_watchdog.publish("replay capsule=%d" % matched)
		var serialized: String = JSON.stringify(capsule,"",false,true)
		var copied: Dictionary = JSON.parse_string(serialized)
		var copied_before: String = JSON.stringify(copied,"",false,true)
		var native: Dictionary = world.diagnostic_replay_ejection(copied)
		_load_fallback(fallback,copied)
		var cells_before: PackedByteArray = fallback.cells.duplicate()
		var masks_before: PackedByteArray = fallback.rigid_body_occupancy.duplicate()
		var differential: Dictionary = _fallback_trace(fallback,copied)
		var actual: Vector2i = fallback._find_body_ejection_target(int(copied.source[0]),int(copied.source[1]),
			int(copied.body_id),Vector2(copied.normal[0],copied.normal[1]),float(copied.penetration))
		var equal: bool = bool(native.get("valid",false)) and native.replay_hash == copied.replay_hash \
			and _same_target(native.target,copied.target) and _same_trace(native.trace,copied.trace) \
			and _same_target(differential.target,copied.target) and _same_trace(differential.trace,copied.trace) \
			and _same_target([actual.x,actual.y],copied.target)
		_check(equal,"native/fallback replay mismatch")
		_check_immutable(JSON.stringify(copied,"",false,true) == copied_before \
			and JSON.stringify(capsule,"",false,true) == serialized and fallback.cells == cells_before \
			and fallback.rigid_body_occupancy == masks_before,"replay input/fallback mutation")
		matched += int(equal)
	_check_immutable(physical == world.get_physical_state_hash() and revision == world.get_revision(),"replay World mutation")
	var report: Dictionary = {"ok":not _failed,"capsules":corpus.capsules.size(),"matched":matched,
		"mutation_failures":_mutation_failures,"input_sha256":FileAccess.get_sha256(path),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION")}
	_write(_argument("--replay-report="),report)
	print("BEARING_REPLAY ",JSON.stringify(report))


func _run() -> void:
	_watchdog = WATCHDOG.new()
	_check(_watchdog.start("granular-bearing",120000) == OK,"watchdog start")
	if _argument("--mode=") == "replay":
		_replay_series()
		_check(_watchdog.stop(),"watchdog stop")
		quit(1 if _failed else 0)
		return
	var name: String = _argument("--arm=")
	_check(name in ["drop1","drop4","speed0","speed30","speed60","speed90"],"unregistered arm")
	_details = _argument("--details=") == "on"
	var directory: String = _argument("--output=")
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK,"output directory")
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	_check(world.diagnostic_reset({"workers":1,"bearing_trace":_details}),"native reset")
	var result: Dictionary = await _capture_case(name,world,directory)
	print("BEARING_CAPTURE ",JSON.stringify(result))
	_check(_watchdog.stop(),"watchdog stop")
	quit(1 if _failed else 0)
