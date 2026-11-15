extends SceneTree

# Real native owner regression: intentionally do not consume its latest-value
# snapshots while native ticks complete. The separate bounded event stream must
# retain each completion, and a diagnostic ACK gate may hold only material.
var failures: int = 0
var checks: int = 0
var events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func wait_snapshot(worker: CyberSimulationWorker, predicate: Callable) -> CyberSimulationSnapshot:
	var deadline: int = Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		var state: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		if state != null and predicate.call(state): return state
		await process_frame
	return null

func wait_native_events(worker: CyberSimulationWorker, count: int) -> bool:
	var deadline: int = Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		var drained: Dictionary=worker.take_render_cadence_events()
		events.append_array(drained.events)
		if events.filter(func(e: Dictionary) -> bool: return e.kind=="native_tick").size()>=count:
			return true
		await process_frame
	return false

func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	expect(ClassDB.class_exists(&"CyberNativeCellWorld"),"real native runtime required")
	if failures>0: quit(failures); return
	var worker := CyberSimulationWorker.new()
	worker.set_frame_state(0.0,false,true,Vector2i(160,90),Vector2i.ZERO,Vector2i(320,180),0,0,false,false,true)
	worker.set_engine_lab_pixel_pacing(60,false)
	worker.set_engine_lab_ack_gated_publication(true)
	expect(worker.begin_render_cadence_trace(),"begin bounded worker capture")
	expect(not worker.begin_render_cadence_trace(),"active capture cannot be erased")
	expect(worker.start_worker(Vector2(150,145))==OK,"native worker starts")
	var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	expect(initial!=null,"initial publication exists")
	if initial==null: worker.stop_worker(); quit(failures); return
	worker.set_frame_state(0.0,false,false,Vector2i(160,90),Vector2i.ZERO,Vector2i(320,180),0,0,false,false,true)
	expect(await wait_native_events(worker,4),"actual native events arrive without consuming snapshots")
	# The completion event is emitted before its immutable status handoff.
	# Wait for that observed completion to reach the latest-value snapshot;
	# consuming immediately after the event races the producer's publication.
	var held: CyberSimulationSnapshot = await wait_snapshot(worker,func(s: CyberSimulationSnapshot) -> bool:
		return s.tick_index>=initial.tick_index+4 and s.render_publication_gate_holds>0)
	expect(held!=null and held.tick_index>=initial.tick_index+4 and held.render_publication_gate_holds>0,
		"native ticks continue while render ACK gate holds")
	if held==null: worker.stop_worker(); quit(failures); return
	expect(held.serial>initial.serial+1,"intermediate latest-value snapshots were deliberately skipped")
	expect(held.render_snapshot_serial==initial.render_snapshot_serial,"unACKed material serial is held")
	expect(held.last_native_tick_completed_usec>=held.last_native_tick_started_usec and held.last_native_tick_started_usec>0,
		"snapshot retains actual completed native interval")
	expect(held.worker_handoff_usec>=held.last_native_tick_completed_usec,"native completion precedes handoff")
	# A rejected/missing material upload cannot be acknowledged. A resync must
	# publish a complete repair without fabricating an ACK for the missing bytes.
	worker.request_render_full_refresh()
	var repaired: CyberSimulationSnapshot = await wait_snapshot(worker,func(s: CyberSimulationSnapshot) -> bool:
		return s.render_snapshot_serial>initial.render_snapshot_serial)
	expect(repaired!=null and repaired.render_full_refresh and repaired.render_acknowledged_serial==0,
		"explicit full resync bypasses unACKed missing snapshot")
	if repaired==null: worker.stop_worker(); quit(failures); return
	worker.set_frame_state(0.0,false,true,Vector2i(160,90),Vector2i.ZERO,Vector2i(320,180),0,0,false,false,true)
	var paused_state: CyberSimulationSnapshot = await wait_snapshot(worker,func(s: CyberSimulationSnapshot) -> bool:
		return s.paused and s.serial>repaired.serial)
	expect(paused_state!=null,"native owner acknowledges pause")
	if paused_state==null: worker.stop_worker(); quit(failures); return
	var later_status: CyberSimulationSnapshot = await wait_snapshot(worker,func(s: CyberSimulationSnapshot) -> bool:
		return s.serial>paused_state.serial)
	expect(later_status!=null and later_status.tick_index==paused_state.tick_index and
		later_status.last_native_tick_completed_usec==paused_state.last_native_tick_completed_usec,
		"status-only publication cannot invent a completed native tick")
	worker.queue_reset(Vector2(150,145))
	var reset: CyberSimulationSnapshot = await wait_snapshot(worker,func(s: CyberSimulationSnapshot) -> bool:
		return s.render_world_generation>repaired.render_world_generation)
	expect(reset!=null and reset.render_full_refresh and reset.render_snapshot_serial>repaired.render_snapshot_serial,
		"accepted World reset bypasses old unACKed material")
	if reset==null: worker.stop_worker(); quit(failures); return
	expect(reset.last_native_tick_completed_usec==-1 and reset.last_native_tick_world_generation==-1,
		"new paused World cannot inherit predecessor completion timestamp")
	worker.acknowledge_render_snapshot(reset.render_snapshot_serial)
	worker.queue_emit_disc(500,300,0,CyberCellWorld.STEAM)
	var released: CyberSimulationSnapshot = await wait_snapshot(worker,func(s: CyberSimulationSnapshot) -> bool:
		return s.render_snapshot_serial>reset.render_snapshot_serial)
	expect(released!=null and released.render_acknowledged_serial==reset.render_snapshot_serial,
		"ordinary material publication resumes after actual ACK")
	worker.stop_worker()
	var capture: Dictionary=worker.finish_render_cadence_trace()
	events.append_array(capture.events)
	var native_count: int=0
	var publication_count: int=0
	var gate_count: int=0
	var ack_count: int=0
	var native_ticks: Dictionary={}
	var bypass_count: int=0
	for event: Dictionary in events:
		expect(int(event.completed_usec)>=int(event.start_usec),"event timestamps ordered")
		if event.kind=="native_tick":
			native_count+=1
			var generation: int=int(event.world_generation)
			expect(int(event.tick_index)==int(native_ticks.get(generation,0))+1,
				"native completion event sequence survives skipped snapshots")
			native_ticks[generation]=int(event.tick_index)
		if event.kind=="render_publication":
			publication_count+=1
			if event.forced_refresh_bypasses_ack: bypass_count+=1
		if event.kind=="render_gate_hold": gate_count+=1
		if event.kind=="worker_ack" and not event.initial_observation: ack_count+=1
	expect(native_count>=4 and publication_count>=2 and gate_count>=1 and ack_count>=1,
		"all real event kinds retained")
	expect(capture.dropped==0,"capture did not drop events")
	expect(worker.take_render_cadence_events().events.is_empty(),"finished trace transferred buffer ownership")
	expect(bypass_count>=2,"resync and reset bypasses are explicit trace evidence")
	_check_capture_bounds(worker)
	print("RENDER_CADENCE_WORKER: ",checks," checks, ",failures," failures; native=",native_count,
		" publications=",publication_count," holds=",gate_count," ACK=",ack_count)
	quit(failures)

func _check_capture_bounds(worker: CyberSimulationWorker) -> void:
	expect(worker.begin_render_cadence_trace(),"finished capture can restart")
	var current_generation: int=int(worker.take_render_cadence_events().generation)
	worker._append_render_cadence_event({"kind":"expired"},current_generation-1)
	for index: int in range(CyberSimulationWorker.RENDER_CADENCE_TRACE_CAPACITY+3):
		worker._append_render_cadence_event({"kind":"bounded_probe","index":index},current_generation)
	var bounded: Dictionary=worker.finish_render_cadence_trace()
	expect(bounded.events.size()==CyberSimulationWorker.RENDER_CADENCE_TRACE_CAPACITY and bounded.dropped==3,
		"bounded recorder counts overflow and rejects old capture generations")
	expect(bounded.events[0].kind=="bounded_probe","expired turn cannot contaminate new capture")
