extends SceneTree

# The ordinary Main physics callback must consume already admitted work even
# when idle/render callbacks are delayed. It still admits only one new fixed
# interval, and a paused Step consumes exactly one native and actor interval.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted
var evidence: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _clocks() -> Dictionary:
	var actual: Dictionary = f.host.simulation_worker.object_shard_owner_frame()
	return {"native_tick":int(actual.get("tick",-1)),"actor_tick":f.host.physical_actor_session.tick,
		"physical_intervals":f.runtime().physical_intervals,"physical_segments":f.runtime().physical_steps,
		"acknowledgements":f.runtime().native_pose_acknowledgements,
		"echoes":f.runtime().native_pose_echo_checks}

func _peek_receipts() -> Array:
	# Observe a copied transport envelope without consuming it or modifying the
	# worker/native owner. Negative controls below mutate only these test copies.
	var worker: CyberSimulationWorker = f.host.simulation_worker
	worker._mutex.lock()
	var copied: Array = worker._m4_control_results.duplicate(true)
	worker._mutex.unlock()
	return copied

func _inspect_delayed_segment(before: Dictionary) -> void:
	var deadline: int = Time.get_ticks_msec()+15000
	while int(f.runtime()._pending_serial)==0 and Time.get_ticks_msec()<deadline:
		f.host._physics_process(1.0/60.0)
		if int(f.runtime()._pending_serial)==0: await process_frame
	while _peek_receipts().is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	var rows: Array = _peek_receipts()
	if not f.expect(rows.size()==1,"one actual segment has one delayed owner receipt"): return
	var row: Dictionary = rows[0]
	f.expect(row.get("compact_motion",false) and row.get("frame",{}).is_empty(),
		"successful intermediate motion omits only its full presentation frame")
	f.expect(f.runtime()._receipt_matches_pending(row),"the actual serial and owner identities authenticate")
	for key: String in ["serial","world_generation","shard_session"]:
		var stale: Dictionary = row.duplicate(true)
		stale[key] = int(stale[key])+1
		f.expect(not f.runtime()._receipt_matches_pending(stale),
			"reordered or foreign "+key+" cannot authenticate as the pending receipt")
	var receipt: Dictionary = row.get("result",{})
	var poses: Array = f.runtime()._pending_poses.duplicate(true)
	var observed: Dictionary = {"shards":receipt.get("applied_pose_echoes",[])}
	f.expect(f.runtime().bridge._valid_motion_receipt(receipt,poses,int(f.runtime()._semantic_tick)) \
		and f.runtime()._native_pose_echo_matches(poses,observed),
		"native applied identities and copied actual native coordinates independently match real Rapier")
	if not poses.is_empty() and not observed.shards.is_empty():
		for key: String in ["pose_serial","geometry_revision","position_x","rotation"]:
			var altered: Dictionary = observed.duplicate(true)
			altered.shards[0][key] += 1
			f.expect(not f.runtime()._native_pose_echo_matches(poses,altered),
				"changed native echo "+key+" refuses without a full presentation snapshot")
		var missing: Dictionary = observed.duplicate(true)
		missing.shards.pop_back()
		f.expect(not f.runtime()._native_pose_echo_matches(poses,missing),"an incomplete native pose roster refuses")
	var stale_tick: Dictionary = receipt.duplicate(true)
	stale_tick.semantic_tick = int(stale_tick.get("semantic_tick",0))+1
	f.expect(not f.runtime().bridge._valid_motion_receipt(stale_tick,poses,int(f.runtime()._semantic_tick)),
		"a later native tick cannot acknowledge this physical segment")
	var intermediate: Dictionary = {"final_segment":false}
	for key: String in ["ok","applied","pose_echo_complete"]:
		var refused: Dictionary = receipt.duplicate(true)
		refused[key] = false
		f.expect(not CyberSimulationWorker._m4_compact_motion_eligible("accept_motion",intermediate,refused),
			"a refused "+key+" result must retain the full diagnostic frame")
	f.expect(not CyberSimulationWorker._m4_compact_motion_eligible("accept_motion",{"final_segment":true},receipt),
		"a final physical segment always publishes its complete native frame")
	f.expect(not CyberSimulationWorker._m4_compact_motion_eligible("accept_motion",{},receipt),
		"an unmarked legacy packet retains its full frame")
	var delayed: Dictionary = _clocks()
	for callback: int in range(16): await process_frame
	f.expect(_clocks()==delayed and delayed.native_tick==before.native_tick \
		and delayed.physical_segments==before.physical_segments+1,
		"delaying the intermediate receipt consumes one real segment and no semantic or duplicate physical time")
	evidence.delayed_segment = {"serial":row.serial,"native_receipt":receipt,
		"actual_rapier_poses":poses,"clocks":delayed,"callbacks_without_consumption":16}

func _begin_delayed_interval(single_step: bool) -> bool:
	f.host.set_process(false)
	f.host.set_physics_process(false)
	if single_step:
		if not f.expect(f.bench.step_once(),"an ordinary Step starts the idle-lease challenge"): return false
	else:
		if not f.play(): return false
	var deadline: int = Time.get_ticks_msec()+15000
	while int(f.runtime()._pending_serial)==0 and Time.get_ticks_msec()<deadline:
		f.host._physics_process(1.0/60.0)
		if int(f.runtime()._pending_serial)==0: await process_frame
	while _peek_receipts().is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	return f.expect(int(f.runtime()._motion_lease)>0 and _peek_receipts().size()==1,
		"the real worker is idle inside one admitted physical lease")

func _pause_and_brush_during_lease() -> bool:
	var before: Dictionary = _clocks()
	var sand_before: int = f.material_count(2)
	if not await _begin_delayed_interval(false): return false
	if not f.expect(f.bench.paint(Vector2i(430,190),2),"ordinary Sand brush queues while a segment receipt is delayed"): return false
	if not f.expect(f.bench.toggle_pause(),"ordinary Pause queues while the physical lease is still active"): return false
	var delayed: Dictionary = _clocks()
	var idle_before: int = int(f.host.simulation_worker.object_shard_owner_profile().segment_idle_polls)
	for callback: int in range(16): await process_frame
	f.expect(_clocks()==delayed and delayed.native_tick==before.native_tick,
		"queued Pause and brush cannot advance chemistry or replay physical work during a delayed receipt")
	f.expect(int(f.host.simulation_worker.object_shard_owner_profile().segment_idle_polls)>idle_before,
		"the adversarial pause actually exercises the worker's idle leased path")
	f.host.set_process(true)
	f.host.set_physics_process(true)
	if not await f.pause(): return false
	var after: Dictionary = _clocks()
	f.expect(after.native_tick==before.native_tick+1 and after.physical_intervals==before.physical_intervals+1,
		"Pause completes its one already admitted native and physical interval exactly once")
	# Existing actor-clock semantics suspend controller/equipment time
	# immediately on Pause, even when an admitted material interval drains.
	# The separately tested paused Step deliberately advances the actor once.
	f.expect(after.actor_tick==before.actor_tick,"intervening Pause retains the existing immediate actor-clock suspension")
	f.expect(f.material_count(2)>sand_before,"the queued ordinary brush drains after the lease into the coherent native World")
	evidence.pause_and_brush = {"before":before,"delayed":delayed,"after":after,
		"sand_before":sand_before,"sand_after":f.material_count(2)}
	return true

func _failed_motion_and_replacement() -> bool:
	# A deliberately invalid protocol request must produce a full diagnostic
	# publication. This separate negative changes only copied request fields;
	# it supplies no replacement physics/material state and never steps Rapier.
	f.host.set_process(false)
	f.host.set_physics_process(false)
	var before: Dictionary = _clocks()
	var old_generation: int = int(f.frame().world_generation)
	var deadline: int = Time.get_ticks_msec()+15000
	while not f.runtime().acquire_interval() and Time.get_ticks_msec()<deadline: await process_frame
	if not f.expect(int(f.runtime()._motion_lease)>0,"negative protocol case obtains an actual exact-source lease"): return false
	var native_pose: Dictionary = f.frame().shards[0]
	var bad_pose: Dictionary = {}
	for key: String in ["session","id","generation","body_generation","geometry_revision","pose_serial",
		"rotation","vx","vy","angular_velocity","sleeping"]: bad_pose[key] = native_pose[key]
	bad_pose.x = native_pose.position_x
	bad_pose.y = native_pose.position_y
	bad_pose.geometry_revision = int(bad_pose.geometry_revision)+1
	bad_pose.pose_serial = int(bad_pose.pose_serial)+1
	var values: Dictionary = {"poses":[bad_pose],"final_segment":false,
		"motion_lease":f.runtime()._motion_lease,
		"workbench_sample":f.host.rapier_bridge.pack_material_motion_sample()}
	for key: String in ["world_generation","shard_session","world_incarnation"]:
		values[key] = f.runtime().capabilities[key]
	var ticket: Dictionary = f.host.simulation_worker.object_shard_submit_owner_control("accept_motion",values)
	if not f.expect(ticket.get("ok",false),"actual owner transport admits the bounded negative request for native validation"): return false
	while _peek_receipts().is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	var rows: Array = f.host.simulation_worker.object_shard_take_owner_results(8)
	if not f.expect(rows.size()==1,"the actual failed command returns one receipt"): return false
	var row: Dictionary = rows[0]
	f.expect(int(row.serial)==int(ticket.serial) and not row.result.get("ok",false) \
		and not row.get("compact_motion",true) and row.frame.get("ok",false) \
		and not row.frame.get("shards",[]).is_empty(),
		"a real native motion refusal retains the complete diagnostic frame")
	f.expect(_clocks()==before,"native rejection advances no semantic, actor or physical time")
	evidence.failed_motion = {"outcome":row.result,"frame_sequence":row.frame.get("publication_sequence"),
		"frame_shards":row.frame.get("shards",[]).size(),"before":before,"after":_clocks()}
	if not f.expect(f.bench.restore_start(),"ordinary Restore start is admitted while the refused lease is idle"): return false
	f.host.set_process(true)
	f.host.set_physics_process(true)
	if not await f.until(f.installed,"the replacement completes through the ordinary owner lifecycle"): return false
	f.play()
	if not await f.until(func(): return int(f.diagnostics().world_generation)>old_generation,
		"Restore installs a different actual World generation after the idle lease"): return false
	if not await f.pause(): return false
	f.expect(f.runtime().held_reason.is_empty() and int(f.runtime()._motion_lease)==0 \
		and f.host.simulation_worker.object_shard_owner_profile().motion_fence.lease==0,
		"the retired lease cannot survive or replay into the restored World")
	evidence.restored_generation = f.diagnostics().world_generation
	return true

func _shutdown_during_lease() -> void:
	if not await _begin_delayed_interval(true): return
	var worker: CyberSimulationWorker = f.host.simulation_worker
	var before: Dictionary = _clocks()
	await f.close()
	f.expect(not worker._running and not worker._thread.is_started(),
		"ordinary scene shutdown joins the real worker while its physical lease is idle")
	evidence.shutdown = {"before":before,"worker_running":worker._running,"thread_started":worker._thread.is_started()}

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower") or not await f.cut_supports("tower"):
		await _finish(); return
	f.play()
	if not await f.until(func(): return f.body_count()>0,"ordinary support cut produces native-owned material") \
		or not await f.pause():
		await _finish(); return
	f.host.set_process(false)
	f.host.set_physics_process(false)
	var before: Dictionary = _clocks()
	var worker_before: Dictionary = f.host.simulation_worker.object_shard_owner_profile()
	if not f.expect(f.bench.step_once(),"one paused Step is admitted through the ordinary control"):
		await _finish(); return
	await _inspect_delayed_segment(before)
	var callbacks: int = 0
	var deadline: int = Time.get_ticks_msec()+15000
	while _clocks().native_tick < before.native_tick+1 and Time.get_ticks_msec()<deadline \
		and f.runtime().held_reason.is_empty():
		# No host._process(), runtime.poll() or private receipt pump here.
		f.host._physics_process(1.0/60.0)
		callbacks += 1
		await process_frame
	var after: Dictionary = _clocks()
	f.expect(after.native_tick==before.native_tick+1,
		"physics callbacks complete one actual native tick without an idle/render callback")
	f.expect(after.physical_intervals==before.physical_intervals+1 and after.actor_tick==before.actor_tick+1,
		"that native tick belongs to exactly one real physical and actor interval")
	f.expect(after.physical_segments-before.physical_segments>=4,
		"the moving structure retains bounded actual Rapier substeps")
	f.expect(after.acknowledgements-before.acknowledgements==after.echoes-before.echoes \
		and after.acknowledgements>before.acknowledgements,
		"every completed segment still has native acknowledgement and exact pose echo")
	var worker_after: Dictionary = f.host.simulation_worker.object_shard_owner_profile()
	f.expect(int(worker_after.get("segment_service_turns",0))>int(worker_before.get("segment_service_turns",0)),
		"the exclusive worker actually services leased segments separately from semantic turns")
	f.expect(int(worker_after.get("compact_motion_receipts",0))-int(worker_before.get("compact_motion_receipts",0))>=3 \
		and int(worker_after.get("full_motion_publications",0))-int(worker_before.get("full_motion_publications",0))==1,
		"actual intermediate receipts are compact while the final physical segment has a full native publication")
	for callback: int in range(16):
		f.host._physics_process(1.0/60.0)
		await process_frame
	f.expect(_clocks()==after and not f.bench.step_requested,
		"further paused physics callbacks cannot replay a completion or advance any clock")
	f.expect(f.runtime().held_reason.is_empty(),"transport scheduling leaves the real owner unheld")
	evidence.merge({"before":before,"after":after,"physics_callbacks_until_completion":callbacks,
		"segment_service_turns":int(worker_after.get("segment_service_turns",0))-int(worker_before.get("segment_service_turns",0)),
		"control_timing":f.runtime().diagnostics().get("control_timing",{})})
	f.host.set_process(true)
	f.host.set_physics_process(true)
	await f.until(func(): return f.runtime().physics_ready() and f.coherent(),
		"normal idle publication resumes on the completed owner state")
	f.validate_physics()
	await f.validate_quantity_ledger()
	if await _pause_and_brush_during_lease() and await _failed_motion_and_replacement():
		await _shutdown_during_lease()
	await _finish()

func _finish() -> void:
	if f.host!=null:
		f.host.set_process(true)
		f.host.set_physics_process(true)
	f.validate_display()
	evidence.display_coherence = f.display_witness()
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-receipt-scheduling-v1",
		"checks":f.checks,"failures":f.failures,"evidence":evidence,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display_driver":DisplayServer.get_name()}))
	quit(0 if f.failures.is_empty() else 1)
