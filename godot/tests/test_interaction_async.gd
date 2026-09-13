extends SceneTree

const Observer = preload("res://tests/interaction_async_worker.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var results: Array = []
	var ok: bool = true
	for material: int in [2,14,29]:
		var world = await CyberInteractionPolicyProbe.fresh(false,4)
		CyberInteractionPolicyProbe.fill(world,64,100,160,100,material)
		CyberInteractionPolicyProbe.fill(world,64,200,160,1,1)
		CyberInteractionPolicyProbe.fill(world,63,0,1,201,1)
		CyberInteractionPolicyProbe.fill(world,224,0,1,201,1)
		var owner = Observer.new()
		owner._world = world
		owner.prepare()
		owner.set_frame_state(0,false,false,Vector2i(144,150),Vector2i(60,60),Vector2i(170,180),0,0,true,true,true)
		if owner.start_worker(Vector2(100,72)) != OK:
			quit(1)
			return
		var deadline: int = Time.get_ticks_msec()+20000
		var snapshot: CyberSimulationSnapshot
		while true:
			await process_frame
			snapshot = owner.take_latest_snapshot(-1)
			owner.acknowledge_render_snapshot(snapshot.render_snapshot_serial)
			if snapshot.tick_index >= 240 or snapshot.simulation_failed or Time.get_ticks_msec() >= deadline:
				break
		owner.stop_worker()
		var passed: bool = not snapshot.simulation_failed and owner.last_tick == 240
		passed = passed and owner.trace[90*4+2] <= 86 and owner.trace[90*4+3] == 1
		passed = passed and owner.trace[150*4+1] > 130 and owner.trace[150*4+2] <= 86
		passed = passed and owner.trace[240*4+2] > 110
		ok = ok and passed
		results.append({"material":material,"ok":passed,"completed_ticks":owner.last_tick,"workers":4,"overruns":snapshot.worker_overruns,"trace":owner.trace})
	var report: Dictionary = {"ok":ok,"results":results,"mode":"desktop-player-asynchronous"}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file: FileAccess = FileAccess.open(args[0],FileAccess.WRITE)
		if file == null:
			quit(1)
			return
		file.store_string(JSON.stringify(report))
	print("INTERACTION_ASYNC ",JSON.stringify(report))
	quit(0 if ok else 1)
