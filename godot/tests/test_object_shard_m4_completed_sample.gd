extends SceneTree

# Delay only Main's transport callbacks. Every body segment, final GCR packet,
# native preparation and semantic tick still comes from the ordinary owners.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted
var evidence: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _fence() -> Dictionary:
	return f.host.simulation_worker.object_shard_owner_profile().get("motion_fence",{})

func _clocks() -> Dictionary:
	var actual_owner: Dictionary = f.host.simulation_worker.object_shard_owner_frame()
	return {"native_tick":int(actual_owner.get("tick",-1)),"actor_tick":f.host.physical_actor_session.tick,
		"rapier_steps":f.host.rapier_bridge.manual_step_count(),"material_steps":f.runtime().physical_steps}

func _pump_until(predicate: Callable, message: String) -> bool:
	var deadline: int = Time.get_ticks_msec()+15000
	while not predicate.call() and Time.get_ticks_msec()<deadline and f.runtime().held_reason.is_empty():
		f.runtime()._poll_once()
		if not predicate.call(): await process_frame
	return f.expect(bool(predicate.call()),message+" / "+str(_fence()))

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower"):
		await _finish(); return
	if not await f.cut_supports("tower"):
		await _finish(); return
	f.play()
	if not await f.until(func(): return f.body_count()>0,"actual ordinary support removal creates a native-owned Rapier body"):
		await _finish(); return
	if not await f.pause():
		await _finish(); return
	f.host.set_process(false)
	f.host.set_physics_process(false)
	var before: Dictionary = _clocks()
	var interval_before: int = f.runtime().physical_intervals
	var acknowledgements_before: int = f.runtime().native_pose_acknowledgements
	var echoes_before: int = f.runtime().native_pose_echo_checks
	var bodies_before: int = f.body_count()
	var reused_before: int = int(_fence().reused_prepared_samples)
	if not f.expect(f.bench.step_once(),"ordinary paused Step requests one genuine physical interval"):
		await _finish(); return
	var deadline: int = Time.get_ticks_msec()+15000
	while int(f.runtime()._motion_lease)==0 and Time.get_ticks_msec()<deadline:
		f.host._physics_process(1.0/60.0)
		if int(f.runtime()._motion_lease)==0: await process_frame
	if not f.expect(int(f.runtime()._motion_lease)>0,"actual worker grants the paused interval a current-source lease"):
		await _finish(); return
	var lease: int = int(f.runtime()._motion_lease)
	if not await _pump_until(func(): return f.runtime()._complete_requested and int(f.runtime()._pending_serial)==0,
		"four real acknowledged segments finish before Main sends interval completion"):
		await _finish(); return
	var final_serial: int = int(f.host._workbench_wait_sample)
	var delayed: Dictionary = _clocks()
	f.expect(delayed.native_tick==before.native_tick and delayed.actor_tick==before.actor_tick+1 \
		and delayed.rapier_steps==before.rapier_steps+4 and delayed.material_steps==before.material_steps+4,
		"actual shared Rapier and actor clocks advance once while native tick awaits completion")
	f.expect(f.runtime().native_pose_acknowledgements==acknowledgements_before+4*bodies_before \
		and f.runtime().native_pose_echo_checks==echoes_before+4*bodies_before,
		"every detached native owner has four actual segment acknowledgements and exact pose echoes")
	f.expect(int(_fence().current_sample)==final_serial and int(_fence().lease)==lease,
		"real final ordinary publication exists while its original physical lease is held")
	# Allow asynchronous worker service across these Main callbacks, deliberately
	# withholding only completion. Callback count is not a worker-turn count.
	for turn: int in range(32): await process_frame
	f.expect(_clocks()==delayed and int(_fence().lease)==lease and not _fence().tick_due,
		"delaying completion cannot consume chemistry or reapply physical controls")
	evidence.delayed_completion = {"before":before,"after_segments":delayed,"lease":lease,
		"final_sample":final_serial,"worker_fence":_fence(),"delayed_callbacks":32,
		"native_bodies":bodies_before,"native_acknowledgements":f.runtime().native_pose_acknowledgements-acknowledgements_before,
		"native_pose_echoes":f.runtime().native_pose_echo_checks-echoes_before}
	f.runtime()._poll_once() # Queue exactly the already completed interval.
	if not f.expect(int(f.runtime()._pending_serial)>0,"Main queues the final packet-bound completion"):
		await _finish(); return
	# A later legitimate Main observation has a newer serial but no physical
	# step. It cannot replace the already admitted final packet or grant time.
	f.host._publish_physical_body_state()
	var newer_serial: int = int(f.host._workbench_wait_sample)
	f.expect(newer_serial!=final_serial,"later actual Main observation has a distinct sample identity")
	if not await _pump_until(func(): return int(f.runtime()._motion_lease)==0 and f.tick()==int(before.native_tick)+1,
		"the exact completed interval produces one native semantic tick"):
		await _finish(); return
	var receipt: Dictionary = f.runtime().last_receipt.duplicate(true)
	var completed_fence: Dictionary = _fence()
	f.expect(receipt.get("ok",false) and receipt.get("completed_interval",false) \
		and int(receipt.get("workbench_sample_serial",-1))==final_serial,
		"actual native final preparation acknowledges the pinned ordinary serial")
	f.expect(receipt.get("native_tick_before_prepare")==before.native_tick \
		and receipt.get("native_tick_after_prepare")==before.native_tick,
		"final coupling preparation occurs under the lease without advancing native time")
	f.expect(int(completed_fence.completed_sample)==final_serial and not completed_fence.tick_due \
		and int(completed_fence.due_sample)==-1 and int(completed_fence.lease)==0,
		"successful native tick consumes the pinned sample and retires its one-shot permit")
	f.expect(int(completed_fence.reused_prepared_samples)==reused_before+1,
		"the due turn uses the already installed final sample exactly once")
	f.expect(int(f.runtime().physical_intervals)==interval_before+1 \
		and f.host.rapier_bridge.manual_step_count()==delayed.rapier_steps \
		and f.runtime().physical_steps==delayed.material_steps,
		"native completion does not create another physical interval or segment")
	var replay_values: Dictionary = {"motion_lease":lease,"main_space_id":f.runtime().bridge.space.get_id(),
		"workbench_sample_serial":final_serial}
	for key: String in ["world_generation","shard_session","world_incarnation"]:
		replay_values[key] = f.runtime().capabilities.get(key)
	var replay: Dictionary = f.host.simulation_worker.object_shard_submit_owner_control("complete_motion",replay_values)
	var replay_result: Dictionary = replay
	if replay.get("ok",false):
		deadline = Time.get_ticks_msec()+15000
		while Time.get_ticks_msec()<deadline:
			var rows: Array = f.host.simulation_worker.object_shard_take_owner_results(8)
			if not rows.is_empty():
				replay_result = rows[0].get("result",{})
				break
			await process_frame
	f.expect(not replay_result.get("ok",false),"retired physical completion cannot replay its native tick")
	for turn: int in range(16): await process_frame
	f.expect(int(_clocks().native_tick)==int(before.native_tick)+1 and int(_fence().completed_sample)==final_serial \
		and f.host.rapier_bridge.manual_step_count()==delayed.rapier_steps,
		"newer observation and stale completion grant no extra native or Rapier time")
	evidence.completed = {"receipt":receipt,"newer_sample":newer_serial,"worker_fence":completed_fence,
		"replay_admission":replay,"replay_result":replay_result,"clocks":_clocks()}
	f.host.set_process(true)
	f.host.set_physics_process(true)
	await f.pause()
	await f.validate_quantity_ledger()
	await _finish()

func _finish() -> void:
	if f.host != null:
		f.host.set_process(true)
		f.host.set_physics_process(true)
	f.validate_display()
	evidence.display = f.display_witness()
	evidence.inventory_witnesses = f.inventory_witnesses
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-completed-sample-v1",
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks":f.checks,"failures":f.failures,"evidence":evidence}))
	quit(0 if f.failures.is_empty() else 1)
