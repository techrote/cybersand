extends SceneTree

const Observer = preload("res://tests/physics_async_worker.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ticks: int = int(args[1]) if args.size()>1 else 120
	var seeds: int = int(args[2]) if args.size()>2 else 1
	if ticks < 1 or ticks > CyberPhysicsCharacterisation.MAX_TICKS or seeds < 1 or seeds > 20:
		push_error("asynchronous fixture requires 1..7200 ticks and 1..20 seeds")
		quit(1)
		return
	for seed: int in range(seeds):
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		if not world.diagnostic_reset({"workers":1}):
			push_error("asynchronous diagnostic construction failed")
			quit(1)
			return
		var left: int = 96+seed*3
		var surface: int = 192+(seed*7%20)
		var floor_y: int = surface+384
		CyberPhysicsCharacterisation.fill(world,left-1,0,1,floor_y+1,1)
		CyberPhysicsCharacterisation.fill(world,left+96,0,1,floor_y+1,1)
		CyberPhysicsCharacterisation.fill(world,left-1,floor_y,98,1,1)
		CyberPhysicsCharacterisation.fill(world,left,surface,96,384,2)
		world.set_simulation_window(Vector2i(left-4,0),Vector2i(104,floor_y+4),0,0)
		var initial: Dictionary = world.diagnostic_snapshot(Vector2i(left-1,surface-128),Vector2i(98,513))
		initial.erase("cells")
		var viewport: SubViewport = SubViewport.new()
		viewport.world_2d = World2D.new()
		viewport.size = Vector2i(128,128)
		root.add_child(viewport)
		var body: RigidBody2D = RigidBody2D.new()
		body.mass = 1.0
		body.gravity_scale = 0.094
		body.linear_damp = 0.15
		body.angular_damp = 0.35
		body.position = Vector2(left+48,surface-21)
		var collision: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(8,14)
		collision.shape = shape
		body.add_child(collision)
		viewport.add_child(body)
		await process_frame
		var bridge: CyberRapierPhysicsBridge = CyberRapierPhysicsBridge.new()
		var bodies: Array[RigidBody2D] = [body]
		if bridge.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(8,14)])) != OK:
			push_error("asynchronous Rapier construction failed")
			quit(1)
			return
		bridge.reset_body(0,Vector2(left+48,surface-21),0.0)
		bridge.enable_diagnostics()
		bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
		var worker = Observer.new()
		worker._world = world
		if not worker.prepare_trace(ticks):
			push_error("asynchronous trace capacity rejected")
			quit(1)
			return
		worker.set_frame_state(0,false,false,Vector2i(left+48,surface),Vector2i(left-4,0),Vector2i(104,floor_y+4),0,0,true,true,true)
		worker.set_rigid_body_states(bridge.pack_body_states())
		if worker.start_worker(Vector2(left+16,surface-14)) != OK:
			push_error("asynchronous worker start failed")
			quit(1)
			return
		var rows: Array = []
		var ages: Array = []
		ages.resize(10)
		ages.fill(0)
		var peak: float = 0.0
		var floor_tick: int = -1
		var applied: Vector2 = Vector2.ZERO
		var deadline: int = Time.get_ticks_msec()+maxi(20000,ticks*50)
		var snapshot: CyberSimulationSnapshot
		while true:
			await physics_frame
			snapshot = worker.take_latest_snapshot(-1)
			if snapshot.simulation_failed or Time.get_ticks_msec()>deadline:
				worker.stop_worker()
				bridge.shutdown()
				viewport.queue_free()
				push_error("asynchronous physics fixture failed or timed out")
				quit(1)
				return
			bridge.apply_cellular_results(snapshot.serial,snapshot.rigid_body_results)
			var d: PackedFloat64Array = bridge.diagnostic_applications
			if d[5] > 0: ages[clampi(int(d[0]),0,9)] += 1
			applied += Vector2(d[1],d[2])
			if snapshot.tick_index>=ticks: break
			bridge.step()
			worker.set_rigid_body_states(bridge.pack_body_states())
			worker.acknowledge_render_snapshot(snapshot.render_snapshot_serial)
			var transform: Transform2D = bridge.body_transform(0)
			var depth: float = maxf(0,transform.origin.y+absf(cos(transform.get_rotation()))*7+absf(sin(transform.get_rotation()))*4-surface)
			peak = maxf(peak,depth)
			if floor_tick<0 and depth>=383: floor_tick=snapshot.tick_index
			if bridge.manual_step_count()%60==0:
				rows.append({"cell_tick":snapshot.tick_index,"rapier_tick":bridge.manual_step_count(),"depth":depth,"rotation":transform.get_rotation(),"x":transform.origin.x,"y":transform.origin.y})
		worker.stop_worker()
		var final: Dictionary = world.diagnostic_snapshot(Vector2i(left-1,surface-128),Vector2i(98,513),true)
		final.erase("cells")
		var report: Dictionary = {"ok":true,"mode":"desktop-asynchronous","seed":seed,"completed_ticks":final.completed_ticks,
			"rapier_ticks":bridge.manual_step_count(),"peak_depth":peak,"floor_contact_tick":floor_tick,"age_histogram":ages,
			"applied_impulse":[applied.x,applied.y],"initial":initial,"final":final,"rows":rows,
			"worker_trace":worker.diagnostic_trace,"worker_overruns":snapshot.worker_overruns,"platform":OS.get_name()}
		if not args.is_empty():
			var file: FileAccess = FileAccess.open(args[0].path_join("async-s%02d.json"%seed),FileAccess.WRITE)
			if file == null:
				push_error("asynchronous output file unavailable")
				quit(1)
				return
			file.store_string(JSON.stringify(report))
			file.close()
		report.erase("worker_trace")
		print("PHYSICS_ASYNC ",JSON.stringify(report))
		bridge.shutdown()
		viewport.queue_free()
		await process_frame
	quit(0)
