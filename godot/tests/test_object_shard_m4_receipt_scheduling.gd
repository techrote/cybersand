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
	await _finish()

func _finish() -> void:
	if f.host!=null:
		f.host.set_process(true)
		f.host.set_physics_process(true)
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-receipt-scheduling-v1",
		"checks":f.checks,"failures":f.failures,"evidence":evidence,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display_driver":DisplayServer.get_name()}))
	quit(0 if f.failures.is_empty() else 1)
