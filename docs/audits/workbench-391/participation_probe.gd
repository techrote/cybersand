extends SceneTree
const Setup = preload("res://scripts/workbench_setup.gd")
var host
var ui
func wait_for(test: Callable, timeout := 60000) -> bool:
	var end := Time.get_ticks_msec() + timeout
	while Time.get_ticks_msec() < end:
		await process_frame
		if test.call(): return true
	return false
func _initialize() -> void:
	run.call_deferred()
func done(err: String, samples: Array) -> void:
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	if snapshot != null:
		print("WB_END ",JSON.stringify({"tick":snapshot.tick_index,"paused":host.paused,"failed":snapshot.simulation_failed,"refusal":host.tower_context.get("workbench_refusal",""),"error":snapshot.last_tick_error}))
	print("WB_NATIVE_PARTICIPATION ",JSON.stringify({"error":err,"platform":OS.get_name(),
		"logical_processors":OS.get_processor_count(),"samples":samples}))
	host.free()
	quit(1 if not err.is_empty() else 0)
func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	root.add_child(host)
	current_scene=host
	ui=host.shared_workbench
	if not await wait_for(func(): return not ui.applied.is_empty()): done("no blank",[]); return
	var data: Dictionary=ui.applied.duplicate(true)
	var dense := OS.get_environment("WORKBENCH_DENSE_NEGATIVE") == "1"
	var nx := 10 if dense else 8
	var ny := 6 if dense else 2
	for y in range(ny):
		for x in range(nx):
			data.edits.append([64+x*(192 if dense else 256),90+y*(320 if dense else 960),20,2 if (x+y)%2==0 else 14])
	data.actors=[Setup.instance("scooper",1,Vector2(1400,1250)),Setup.instance("needle",2,Vector2(80,150)),
		Setup.instance(Setup.BARREL,3,Vector2(1480,1250))]
	data.selected=1
	data.next_id=4
	if not ui.apply(data) or not await wait_for(func(): return host.physical_actor_session!=null and not ui.busy()): done("apply "+ui.message,[]);return
	if not ui.toggle_pause(): done("resume",[]);return
	host.simulation_worker.set_worker_participation_sampling(true)
	var samples: Array=[]
	var last := 0
	var observed := 0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() < start+7000:
		await process_frame
		var snapshot: CyberSimulationSnapshot=host.latest_snapshot
		var p: Dictionary=snapshot.native_worker_participation
		if p.is_empty() or int(p.sequence)==last: continue
		last=int(p.sequence)
		var row: Dictionary=p.duplicate(true)
		row["backend"]=snapshot.backend_name
		row["worker_request"]=snapshot.native_worker_request
		row["elapsed_ms"]=Time.get_ticks_msec()-start
		row["physical_bodies"]=host.physical_actor_session.bodies().size()
		samples.append(row)
		observed=maxi(observed,int(p.workers_observed))
	done("" if observed>1 and host.latest_snapshot.tick_index>19 and not host.latest_snapshot.simulation_failed else "could not demonstrate multiple participants",samples)
