extends SceneTree

# Measured application-owner campaign, not a synthetic actor-count benchmark.
# The same script may be copied into the untouched baseline worktree: its
# baseline mode uses only old Setup-v2/flyer APIs and identical cell geometry.
const Setup = preload("res://scripts/workbench_setup.gd")
var host: Control
var wb: Control
var failures: Array[String] = []
var rows: Array = []
var measured_ms := 3000


func _initialize() -> void:
	Engine.max_fps = 60
	run.call_deferred()


func wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker.has_failed(): break
		await process_frame
	failures.append("Timed out: "+str(host.microscenario_error)+" / "+str(wb.message))
	return false


func geometry(size: Vector2i) -> Dictionary:
	var data := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),size)
	var floor_y := size.y-52
	var scale_x := size.x/1024
	data.edits = [[8,floor_y,size.x-16,12,58],[8,80,8,floor_y-80,58],[size.x-24,80,8,floor_y-80,58],
		[270*scale_x,floor_y-20,20,20,58],[420*scale_x,floor_y-34,24,34,58],[570*scale_x,floor_y-20,20,20,58],
		[650*scale_x,floor_y-50,96*scale_x,50,2],[770*scale_x,floor_y-20,92*scale_x,20,3]]
	return data


func recipe(kind: String, size: Vector2i) -> Dictionary:
	var data := geometry(size)
	var specs: Array = []
	match kind:
		"flyer": specs = [["scooper",1,180,180,"human",-1]]
		"one_script": specs = [["runner",2,225,350,"scripted",-1]]
		"heterogeneous": specs = [["runner",2,225,350,"scripted",-1],["crawler",3,600,350,"scripted",-1],["skimmer",4,400,220,"scripted",-1]]
		"mixed": specs = [["scooper",1,180,180,"human",-1],["runner",2,225,350,"scripted",-1],["skimmer",4,400,220,"scripted",-1],["stuntbuggy",5,510,350,"policy",-1]]
		"equipment": specs = [["scooper",1,180,180,"human",-1],["runner",2,225,350,"scripted",3],["crawler",3,600,350,"scripted",8],["skimmer",4,400,220,"scripted",1],["stuntbuggy",5,510,350,"policy",-1]]
	for spec: Array in specs:
		var a := Setup.instance(spec[0],spec[1],Vector2(spec[2]*size.x/1024,spec[3]+size.y-512))
		if kind != "flyer":
			a["control"] = {"version":1,"source":spec[4],"enabled":true,"decision_ticks":6,"policy":"fixture","usable_index":spec[5]}
		data.actors.append(a)
		data.next_id = maxi(int(data.next_id),int(a.id)+1)
	data.selected = int(data.actors[0].id) if not data.actors.is_empty() else 0
	return data


func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"count":0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in values: total+=value
	return {"count":values.size(),"mean":total/values.size(),"p50":sorted[mini(sorted.size()-1,int(sorted.size()*0.5))],
		"p95":sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],"max":sorted.back()}


func measure(kind: String, size: Vector2i) -> void:
	if not host.paused: wb.toggle_pause()
	var data := recipe(kind,size)
	if not wb.apply(data): failures.append("Prepare "+kind+": "+wb.message); return
	if not await wait_for(func() -> bool: return host.pending_microscenario_apply.is_empty() and not wb.busy() and wb.applied.actors.size()==data.actors.size()): return
	if not wb.toggle_pause(): failures.append("Play "+kind); return
	var warm_tick: int = host.latest_snapshot.tick_index+12
	if not await wait_for(func() -> bool: return host.latest_snapshot.tick_index>=warm_tick): return
	var start_tick: int = host.latest_snapshot.tick_index
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var start_rapier: int = session.tick if session != null else 0
	var begin := Time.get_ticks_usec()
	var start_memory := OS.get_static_memory_usage()
	var previous := begin
	var previous_serial := -1
	var frames: Array = []
	var publication: Array = []
	var simulation: Array = []
	var worker: Array = []
	var observations: Array = []
	var decision_start := 0
	if session != null and session.get("_decision_total_usec") != null:
		for value: int in session.get("_decision_total_usec"): decision_start += value
	while Time.get_ticks_usec()-begin < measured_ms*1000:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		previous = now
		var snapshot: CyberSimulationSnapshot = host.latest_snapshot
		if snapshot.simulation_failed or not str(snapshot.lab_context.get("workbench_refusal","")).is_empty():
			failures.append(kind+" failed: "+snapshot.last_tick_error+" / "+str(snapshot.lab_context.get("workbench_refusal","")))
			break
		if snapshot.serial != previous_serial:
			previous_serial = snapshot.serial
			publication.append(snapshot.snapshot_publication_time_ms)
			simulation.append(snapshot.simulation_time_ms)
			worker.append(snapshot.worker_step_time_ms)
		if session != null and frames.size()%30 == 0:
			var observed_at := Time.get_ticks_usec()
			for slot: int in session._definitions.size(): session._view(slot,false)
			observations.append(Time.get_ticks_usec()-observed_at)
	var elapsed := float(Time.get_ticks_usec()-begin)/1000000.0
	var decision_total := 0
	if session != null and session.get("_decision_total_usec") != null:
		for value: int in session.get("_decision_total_usec"): decision_total += value
	var end_tick: int = host.latest_snapshot.tick_index
	var end_rapier: int = session.tick if session != null else 0
	var pauses := 0
	for value: float in frames:
		if value>=100.0: pauses+=1
	var row := {"case":kind,"extent":[size.x,size.y],"elapsed_seconds":elapsed,
		"native_ticks":end_tick-start_tick,"rapier_steps":end_rapier-start_rapier,
		"native_ticks_per_second":float(end_tick-start_tick)/elapsed,
		"rapier_steps_per_second":float(end_rapier-start_rapier)/elapsed,
		"frame_ms":stats(frames),"frames_at_least_100ms":pauses,
		"native_simulation_ms":stats(simulation),"worker_step_ms":stats(worker),
		"native_publication_ms":stats(publication),"all_actor_copied_observation_usec":stats(observations),
		"controller_total_usec":decision_total-decision_start,
		"godot_static_memory_start":start_memory,"godot_static_memory_end":OS.get_static_memory_usage(),
		"godot_static_memory_peak":OS.get_static_memory_peak_usage(),
		"actor_count":data.actors.size(),"body_count":session.bodies().size() if session != null else 0,
		"native_backend":host.latest_snapshot.backend_name,"display":DisplayServer.get_name()}
	if end_tick<=start_tick: failures.append(kind+" had no native progression")
	if session != null and end_rapier<=start_rapier: failures.append(kind+" had no Rapier progression")
	wb.toggle_pause()
	if kind == "equipment":
		var paused_tick: int = session.tick
		var edit := Vector2i(size.x-124,size.y-212)
		row["paused_paint_queued"] = wb.paint(edit,58)
		if not await wait_for(func() -> bool: return host.image.get_pixelv(edit).r8==58): return
		row["paused_rapier_unchanged"] = session.tick==paused_tick
		wb.toggle_pause()
		row["resumed_after_paint"] = await wait_for(func() -> bool: return session.tick>=paused_tick+8)
		wb.toggle_pause()
	rows.append(row)
	print("WB_ACTOR_PERFORMANCE_CASE ",JSON.stringify(row))


func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	wb = host.shared_workbench
	if not await wait_for(func() -> bool: return not wb.applied.is_empty() and not wb.busy()): quit(1); return
	var duration := OS.get_environment("WB_ACTOR_MEASURE_MS")
	if duration.is_valid_int(): measured_ms = clampi(int(duration),1000,30000)
	var baseline := OS.get_environment("WB_ACTOR_BASELINE") == "1"
	var kinds: Array = ["none","flyer"] if baseline else ["none","flyer","one_script","heterogeneous","mixed","equipment"]
	for size: Vector2i in [Vector2i(1024,512),Vector2i(2048,1024)]:
		for kind: String in kinds: await measure(kind,size)
	var result := {"version":1,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),
		"baseline":baseline,"rows":rows,"failures":failures,
		"note":"Headless timings do not measure GPU publication or owner playfeel." if DisplayServer.get_name()=="headless" else "Actual graphical application timings on the reported adapter; automated execution does not establish subjective owner playfeel.",
		"graphics_adapter":RenderingServer.get_video_adapter_name() if DisplayServer.get_name()!="headless" else "none"}
	var path := OS.get_environment("WB_ACTOR_PERFORMANCE_OUTPUT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result,"  ")+"\n")
	host.queue_free()
	await process_frame
	await process_frame
	print("WB_ACTOR_PERFORMANCE ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
