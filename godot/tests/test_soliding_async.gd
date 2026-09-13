extends SceneTree
const OWNER = preload("res://tests/soliding_async_worker.gd")
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var ok: bool = true
	var results: Array = []
	for workers: int in [1,4]:
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		assert(world.diagnostic_reset({"workers":workers}))
		world.diagnostic_fill_rect(Vector2i(36,52),Vector2i(8,8),1)
		world.diagnostic_fill_rect(Vector2i(32,60),Vector2i(32,2),40)
		assert(world.diagnostic_soliding_configure(Vector2i(32,32),Vector2i(32,32)))
		var worker = OWNER.new()
		worker._world = world
		worker.set_frame_state(0,false,false,Vector2i(64,64),Vector2i.ZERO,Vector2i(128,128),0,0,true,true,true)
		assert(worker.start_worker(Vector2(80,80)) == OK)
		var deadline: int = Time.get_ticks_msec()+20000
		var snapshot: CyberSimulationSnapshot
		while Time.get_ticks_msec()<deadline:
			await physics_frame
			snapshot = worker.take_latest_snapshot(-1)
			if snapshot != null and (snapshot.tick_index>=360 or snapshot.simulation_failed):
				break
		worker.stop_worker()
		var passed: bool = worker.maximum_rest>=300 and worker.invalidated and worker.removed and worker.final_packet.get("ok",false)
		results.append({"workers":workers,"ok":passed,"maximum_rest":worker.maximum_rest,"invalidated":worker.invalidated,"removed":worker.removed,"tick":worker.seen_tick})
		ok = ok and passed
		worker = null
		world = null
	print("SOLIDING_DESKTOP_ASYNC ",JSON.stringify({"ok":ok,"results":results}))
	quit(0 if ok else 1)
