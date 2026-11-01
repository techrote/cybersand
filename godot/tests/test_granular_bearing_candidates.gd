extends "res://tests/test_granular_bearing_capture.gd"

# GBD-2026-11-01. Same one-pack/step/response owner as339; no combined arm.
var _candidate: String = "B0"
var _bank_material: int = CyberCellWorld.SAND


func _conserve(snapshot: Dictionary, expected: Dictionary) -> void:
	_check(int(snapshot.water_mass) == int(expected.water_mass),"stored Water quantity changed")
	if _bank_material != CyberCellWorld.WATER:
		_check(snapshot.counts == expected.counts,"stored material counts changed")
	else:
		for material: int in range(snapshot.counts.size()):
			if material != CyberCellWorld.WATER and material != CyberCellWorld.EMPTY:
				_check(snapshot.counts[material] == expected.counts[material],"nonWater material changed")
		for y: int in range(SNAP_SIZE.y):
			for local_x: int in range(SNAP_SIZE.x):
				var x: int = SNAP_ORIGIN.x + local_x
				if x < 96 or x >= 128 or y < 1 or y >= 208:
					_check(int(snapshot.cells[y*SNAP_SIZE.x+local_x]) != CyberCellWorld.WATER,"Water escaped closed fixture")


func _capture_case(name: String, world: Object, directory: String) -> Dictionary:
	world.set_simulation_window(Vector2i(92,0),Vector2i(40,212),0,0)
	for rectangle: Array in [[95,0,1,209],[128,0,1,209],[95,208,34,1],[95,0,34,1]]:
		_check(world.diagnostic_fill_rect(Vector2i(rectangle[0],rectangle[1]),Vector2i(rectangle[2],rectangle[3]),CyberCellWorld.WALL),"fixture hard fill")
	_check(world.diagnostic_fill_rect(Vector2i(96,160),Vector2i(32,48),_bank_material),"fixture bank fill")
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
	var initial := Vector2(112,139)
	var velocity := Vector2.ZERO
	var angular_velocity: float = 1.0
	if true:
		initial.y = 160.0-2.0-(absf(cos(0.08))*7.0+absf(sin(0.08))*4.0)
		velocity.y = 0.0 if name == "excavation" else 90.0 if name in ["hard","water"] else float(name.substr(5))
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
	var segments: Array = []
	var segment: int = 0
	var removed: Dictionary = {}
	var previous_overlap: Dictionary = {}
	var event_file := FileAccess.open(directory+"/events.jsonl",FileAccess.WRITE)
	_check(event_file != null,"event file open")
	var total_events: int = 0
	var raw_unresolved: int = 0
	var raw_displaced: int = 0
	var peak_pending: int = 0
	for tick: int in range(600):
		_watchdog.publish("%s/%s tick=%d" % [_candidate,name,tick])
		if tick > 0 and tick % 60 == 0:
			segments.append(world.diagnostic_ejection_corpus())
			_check(world.diagnostic_ejection_stream(),"segment restart")
			segment += 1
		if name == "excavation" and tick == 300:
			var edit_before: Dictionary = world.diagnostic_snapshot(SNAP_ORIGIN,SNAP_SIZE)
			_check(world.diagnostic_fill_rect(Vector2i(96,1),Vector2i(32,207),CyberCellWorld.EMPTY),"authoritative excavation")
			var edit_after: Dictionary = world.diagnostic_snapshot(SNAP_ORIGIN,SNAP_SIZE)
			removed = {"tick":tick,"before_counts":edit_before.counts,"after_counts":edit_after.counts,
				"before_water":edit_before.water_mass,"after_water":edit_after.water_mass}
			baseline = edit_after
		var before_step: Array = _motion(body)
		var step_start: int = Time.get_ticks_usec()
		bridge.step()
		var after_step: Array = _motion(body)
		var input: PackedFloat32Array = bridge.pack_body_states() # Exactly one sample.
		var pre: Dictionary = world.diagnostic_snapshot(SNAP_ORIGIN,SNAP_SIZE)
		var coupling_start: int = Time.get_ticks_usec()
		world.prepare_rigid_body_coupling(input,true)
		var coupling_usec: int = Time.get_ticks_usec() - coupling_start
		var candidate_metrics: Dictionary = world.diagnostic_bearing_candidate()
		_check(candidate_metrics.candidate == _candidate,"candidate identity drift")
		_check(int(candidate_metrics.invalid_geometry) == 0,"invalid translated geometry")
		_check(float(candidate_metrics.lookahead) <= 2.0 and int(candidate_metrics.maximum_ray_cells) <= 3,"lookahead bound")
		_check(int(candidate_metrics.extra_cells) <= 2 * int(candidate_metrics.boundaries),"work bound")
		_check(int(candidate_metrics.selected_support) == int(candidate_metrics.current_support) + int(candidate_metrics.predicted_only),"support accounting")
		var producer_usec: int = Time.get_ticks_usec()
		var metrics: Array = world.diagnostic_body_metrics()
		var pre_results: Array = Array(world.rigid_body_results())
		var bearing: Dictionary = world.diagnostic_bearing_state() if _details else {}
		var post: Dictionary = world.diagnostic_snapshot(SNAP_ORIGIN,SNAP_SIZE)
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
			capsule["candidate"] = _candidate
			capsule["capture_segment"] = segment
			capsule["event_ordinal_native"] = capsule.event_ordinal
			capsule["event_ordinal"] = total_events + 1
			event_file.store_line(JSON.stringify(capsule,"",false,true))
			total_events += 1
		raw_unresolved += int(world.get_rigid_body_unresolved_last_tick())
		raw_displaced += int(world.get_rigid_body_displaced_last_tick())
		_check(world.simulation_tick(),"native tick failed")
		var results: PackedFloat32Array = world.rigid_body_results()
		var after_metrics: Array = world.diagnostic_body_metrics()
		bridge.apply_cellular_results(tick+1,results)
		var final_snapshot: Dictionary = world.diagnostic_snapshot(SNAP_ORIGIN,SNAP_SIZE)
		_conserve(final_snapshot,baseline)
		_conserve(pre,baseline)
		_conserve(post,baseline)
		if _details:
			pass # conservation is required in both observer modes
			var masked_after_tick: int = 0
			for y: int in range(maxi(0,floori(input[2]-10)),mini(212,ceili(input[2]+10))):
				for x: int in range(maxi(92,floori(input[1]-10)),mini(132,ceili(input[1]+10))):
					if world.rigid_body_id_at(x,y) == 1 and _cell(final_snapshot,x,y) == CyberCellWorld.SAND:
						masked_after_tick += 1
			geometry["post_tick_overlap_at_packed_pose"] = masked_after_tick
		var row: Dictionary = {"tick":tick,"candidate":_candidate,"candidate_metrics":candidate_metrics,"coupling_usec":coupling_usec,"body_input":Array(input),"before_step":before_step,
			"after_step":after_step,"pre_tick_metrics":metrics,"pre_tick_results":pre_results,
			"post_tick_metrics":after_metrics,"requested_results":Array(results),
			"bridge_application":Array(bridge.diagnostic_applications),"after_application":_motion(body),
			"physical_hash":world.get_physical_state_hash(),"events":batch.capsules.size(),
			"stored_counts":final_snapshot.counts,"stored_water_mass":final_snapshot.water_mass,"pre_water_mass":pre.water_mass,"post_water_mass":post.water_mass,"attempted_tick":final_snapshot.attempted_ticks,
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
	segments.append(world.diagnostic_ejection_corpus())
	var counters: Dictionary = segments[0].duplicate(true)
	for key: String in ["attempts","duplicates","dropped","searched_no_target","target_found","relocation_refused",
		"dropped_capacity","dropped_oversized","dropped_stale_or_sidecar","replay_disagreements","stream_emitted","stream_pending_drops","stream_total_drops"]:
		counters[key] = 0
		for receipt: Dictionary in segments:
			counters[key] += int(receipt[key])
	for receipt: Dictionary in segments:
		_check(receipt.owner_current and receipt.capture_instance_id == counters.capture_instance_id
			and receipt.capture_reset_generation == counters.capture_reset_generation,"segment owner fence")
	_check(int(counters.dropped) == 0 and int(counters.attempts) == total_events,"event loss")
	counters["complete"] = not _failed
	counters["maximum_pending_seen"] = peak_pending
	counters["events_written"] = total_events
	var fixture: Dictionary = {"name":name,"left":96,"surface":160,"width":32,"depth":48,
		"body_size":[8,14],"mass":1,"ticks":600,"workers":1,"real_rapier":true,
		"candidate":_candidate,"bank_material":_bank_material,"initial_position":[initial.x,initial.y],"initial_rotation":0.08,"initial_velocity":[velocity.x,velocity.y],
		"initial_angular_velocity":angular_velocity,"raw_unresolved":raw_unresolved,"raw_displaced":raw_displaced}
	counters["fixture"] = fixture
	var acquisition: Dictionary = {"complete":not _failed,"fixture":fixture,"native_counters":counters,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"mode":"acquire","details":_details,"candidate":_candidate,"segments":segments,"excavation":removed}
	_write(directory+"/acquisition.json",acquisition)
	_write(directory+"/trajectory.json",{"frames":frames,"fixture":fixture,"details":_details})
	bridge.shutdown()
	viewport.queue_free()
	await process_frame
	return {"ok":not _failed,"arm":name,"events":total_events,"no_target":counters.searched_no_target,
		"success":counters.target_found,"details":_details,"frames":frames.size()}

func _candidate_controls() -> void:
	var world: Object = _new_world()
	_check(world.diagnostic_bearing_candidate().candidate == "B0","ordinary default changed")
	var physical: String = world.get_physical_state_hash()
	for mode: String in ["unknown","Y1+A2","y1"]:
		_check(not world.diagnostic_reset({"bearing_experiment":"GBD-2026-11-01","bearing_candidate":mode})
			and world.get_physical_state_hash() == physical,"malformed mode changed authority")
	_check(not world.diagnostic_reset({"bearing_candidate":"Y1"}),"candidate activated without explicit experiment")
	for mode: String in ["B0","Y1","A2"]:
		_check(world.diagnostic_reset({"workers":1,"bearing_trace":true,"bearing_experiment":"GBD-2026-11-01","bearing_candidate":mode}),"mode select")
		_check(world.diagnostic_fill_rect(Vector2i(96,100),Vector2i(24,8),CyberCellWorld.SAND),"support fill")
		world.prepare_rigid_body_coupling(PackedFloat32Array([1,108,95,0,8,8,0,90,0,1,1]),true)
		var info: Dictionary = world.diagnostic_bearing_candidate()
		_check(info.candidate == mode,"mode receipt")
		if mode == "A2":
			_check(info.current_support == 0 and info.predicted_only == 8,"lookahead admission missing")
		else:
			_check(info.selected_support == 0,"current geometry changed")
		world.prepare_rigid_body_coupling(PackedFloat32Array([1,108,96,0,8,8,0,30,0,1,2]),true)
		var law: Dictionary = world.diagnostic_bearing_state()
		var expected: float = -16.0 if mode == "Y1" else -(92.0/60.0 + (30.0-92.0/60.0)*0.18)
		_check(absf(float(law.bearing_y)-expected) < 0.00001,"candidate formula isolation")
		for material: int in [CyberCellWorld.EMPTY,CyberCellWorld.WALL,CyberCellWorld.WATER]:
			_check(world.diagnostic_reset({"bearing_trace":true,"bearing_experiment":"GBD-2026-11-01","bearing_candidate":mode}),"negative reset")
			world.diagnostic_fill_rect(Vector2i(96,100),Vector2i(24,8),material)
			world.prepare_rigid_body_coupling(PackedFloat32Array([1,108,95,0,8,8,0,90,0,1,1]),true)
			_check(world.diagnostic_bearing_candidate().selected_support == 0 and world.diagnostic_bearing_state().bearing_y == 0,"nongranular support")
	_check(world.diagnostic_reset({"bearing_trace":true,"bearing_experiment":"GBD-2026-11-01","bearing_candidate":"A2"}),"foreign reset")
	world.diagnostic_fill_rect(Vector2i(96,100),Vector2i(24,8),CyberCellWorld.SAND)
	world.prepare_rigid_body_coupling(PackedFloat32Array([1,108,95,0,8,8,0,90,0,1,1,
		2,108,100.5,0,8,1,0,0,0,1,1]),true)
	_check(world.diagnostic_bearing_candidate().selected_support == 0,"lookahead crossed foreign mask")
	for vy: float in [0.0,-10.0]:
		_check(world.diagnostic_reset({"bearing_trace":true,"bearing_experiment":"GBD-2026-11-01","bearing_candidate":"A2"}),"rising reset")
		world.diagnostic_fill_rect(Vector2i(96,100),Vector2i(24,8),CyberCellWorld.SAND)
		world.prepare_rigid_body_coupling(PackedFloat32Array([1,108,96,0,8,8,0,vy,0,1,1]),true)
		var info: Dictionary = world.diagnostic_bearing_candidate()
		_check(info.lookahead == 0 and info.current_support == info.selected_support and info.extra_cells == 0,"zero/rising semantics changed")
	_check(world.diagnostic_reset({"workers":1}) and world.diagnostic_bearing_candidate().candidate == "B0","normal reset retained candidate")


func _run() -> void:
	_watchdog = WATCHDOG.new()
	_check(_watchdog.start("bearing-candidates",120000) == OK,"watchdog")
	var mode: String = _argument("--mode=")
	if mode == "replay":
		_replay_series()
	elif mode == "controls":
		await _bearing_controls()
		_candidate_controls()
		print("CANDIDATE_CONTROLS ",JSON.stringify({"ok":not _failed}))
	else:
		var name: String = _argument("--arm=")
		_check(name in ["speed0","speed30","speed90","excavation","hard","water"],"unregistered arm")
		_candidate = _argument("--candidate=")
		_check(_candidate in ["B0","Y1","A2"],"unregistered candidate")
		_details = _argument("--details=") == "on"
		_bank_material = CyberCellWorld.WALL if name == "hard" else CyberCellWorld.WATER if name == "water" else CyberCellWorld.SAND
		var directory: String = _argument("--output=")
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK,"output directory")
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		_check(world.diagnostic_reset({"workers":1,"bearing_trace":_details,
			"bearing_experiment":"GBD-2026-11-01","bearing_candidate":_candidate}),"candidate fresh reset")
		var result: Dictionary = await _capture_case(name,world,directory)
		result["candidate"] = _candidate
		print("CANDIDATE_CAPTURE ",JSON.stringify(result))
	_check(_watchdog.stop(),"watchdog stop")
	quit(1 if _failed else 0)
