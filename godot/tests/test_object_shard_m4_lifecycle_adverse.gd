extends SceneTree

# Adversarial scheduling uses the actual ordinary worker and shared-space
# physics. Only Main callback scheduling is delayed; no native pose, receipt,
# material state or collision result is fabricated.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted
var evidence: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _clocks() -> Dictionary:
	var actual_owner: Dictionary = f.host.simulation_worker.object_shard_owner_frame()
	return {"native_tick":int(actual_owner.get("tick",-1)),"actor_tick":f.host.physical_actor_session.tick,
		"rapier_steps":f.host.rapier_bridge.manual_step_count(),"material_steps":f.runtime().physical_steps}

func _inventory_admission_negatives() -> int:
	var source: Dictionary = {}
	for key: String in ["world_generation","session","world_incarnation","publication_sequence","tick","world_revision","next_transaction"]:
		source[key] = f.frame().get(key)
	for key: String in ["native_instance_id","transport_generation","owner_epoch","shard_session"]:
		source[key] = f.runtime().capabilities.get(key)
	var before: Dictionary = _clocks()
	var malformed_source: Dictionary = source.duplicate(true)
	malformed_source["unexpected_payload"] = [1,2,3]
	var malformed: Dictionary = f.host.simulation_worker.object_shard_request_inventory_inspection(malformed_source)
	f.expect(not malformed.get("ok",false) and malformed.get("outcome")=="InvalidInventorySource",
		"actual worker refuses arbitrary payload in its bounded inventory source envelope")
	var stale_source: Dictionary = source.duplicate(true)
	stale_source.publication_sequence = int(stale_source.publication_sequence)-1
	var stale: Dictionary = {}
	for attempt: int in range(128):
		stale = f.host.simulation_worker.object_shard_request_inventory_inspection(stale_source)
		if stale.get("outcome")!="OwnerBusy": break
		await process_frame
	f.expect(not stale.get("ok",false) and stale.get("outcome")=="InventorySourceChanged",
		"actual idle worker refuses an older inventory publication without reading native cells")
	f.expect(_clocks()==before,"malformed and stale read admission consumes no native, actor or Rapier time")
	var admitted: Dictionary = {}
	for attempt: int in range(128):
		admitted = f.runtime().request_inventory_inspection()
		if admitted.get("outcome")!="OwnerBusy": break
		await process_frame
	if not f.expect(admitted.get("ok",false),"one genuine exact-source inventory read is queued before retirement"):
		return 0
	var duplicate: Dictionary = f.runtime().request_inventory_inspection()
	f.expect(not duplicate.get("ok",false) and int(duplicate.get("token",-1))==0 \
		and duplicate.get("outcome") in ["InventoryInspectionSlotOccupied","OwnerBusy"],
		"a second read cannot replace the single pending or completed inspection slot")
	f.expect(_clocks()==before,"read admission and duplicate refusal advance no physical or semantic clock")
	evidence.inventory_read_admission = {"source":source,"before_clocks":before,"after_clocks":_clocks(),
		"malformed":malformed,"stale":stale,"admitted":admitted,"duplicate":duplicate}
	return int(admitted.token)

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower"):
		await _finish(); return
	await f.pause()
	await f.cut_supports("tower")
	f.play()
	if not await f.until(func(): return f.body_count()>0,"ordinary native material genuinely detaches before lifecycle stress"):
		await _finish(); return
	await f.pause()
	await f.until(f.whole_canvas_coherent,"lifecycle baseline has exact native World and body publication")
	var initial_wood: int = f.material_count(7)
	var installed_sequence: int = int(f.frame().publication_sequence)
	var native_tick: int = int(_clocks().native_tick)
	var actor_tick: int = int(f.host.physical_actor_session.tick)
	var rapier_steps: int = int(f.host.rapier_bridge.manual_step_count())
	var material_steps: int = int(f.runtime().physical_steps)
	var refused: int = int(f.runtime().motion_permits_refused)
	# Delay Main polling while its real worker publishes an ordinary live
	# Sand edit. An earlier installed material frame must not authorize a step.
	f.host.set_process(false)
	f.host.set_physics_process(false)
	f.expect(f.bench.toggle_pause(),"Resume can be queued while Main polling is deliberately delayed")
	f.expect(f.host.simulation_worker.queue_emit_disc(440,400,0,2),"actual ordinary brush command queues before delayed Main callback")
	var changed_frame: Dictionary = {}
	var deadline: int = Time.get_ticks_msec()+Fixture.Watchdogs.milliseconds("operation_seconds")
	while changed_frame.is_empty() and Time.get_ticks_msec()<deadline:
		changed_frame = f.host.simulation_worker.object_shard_owner_frame(installed_sequence)
		if changed_frame.is_empty(): await process_frame
	if not f.expect(not changed_frame.is_empty(),"real worker publishes a newer exact source while Main retains its prior installed frame"):
		await _finish(); return
	f.expect(int(f.frame().publication_sequence)==installed_sequence,"delayed Main has not silently consumed the new owner frame")
	f.expect(int(changed_frame.get("tick",-1))==native_tick,
		"actual worker's newer brush publication has not advanced native semantic time")
	var attempts: Array[Dictionary] = []
	var total_attempts: int = 0
	var final_attempt: Dictionary = {}
	var all_actor_ticks_unchanged: bool = true
	var all_native_ticks_unchanged: bool = true
	var all_rapier_steps_unchanged: bool = true
	var all_material_steps_unchanged: bool = true
	var attempt_deadline: int = Time.get_ticks_msec()+5000
	# Publication can precede the end of that real worker turn. A busy-owner
	# refusal is safe, but does not exercise exact installed-source comparison.
	# Retry only that actual scheduling state, while Main polling stays off.
	# The bound is wall time, not a platform-dependent count of render callbacks.
	while Time.get_ticks_msec()<attempt_deadline and total_attempts<4096:
		# The ordinary physical callback now deliberately consumes available
		# receipts before admission. Challenge the same actual permit API with
		# the deliberately retained stale frame, while both pumps remain off.
		# Calling Main here would validly synchronize the new publication.
		f.runtime().acquire_interval()
		final_attempt = _clocks()
		final_attempt["refusal"] = f.runtime().last_motion_permit.duplicate(true)
		total_attempts += 1
		if attempts.size()<128: attempts.append(final_attempt.duplicate(true))
		all_actor_ticks_unchanged = all_actor_ticks_unchanged and int(final_attempt.actor_tick)==actor_tick
		all_native_ticks_unchanged = all_native_ticks_unchanged and int(final_attempt.native_tick)==native_tick
		all_rapier_steps_unchanged = all_rapier_steps_unchanged and int(final_attempt.rapier_steps)==rapier_steps
		all_material_steps_unchanged = all_material_steps_unchanged and int(final_attempt.material_steps)==material_steps
		if not (all_native_ticks_unchanged and all_actor_ticks_unchanged and all_rapier_steps_unchanged and all_material_steps_unchanged) \
			or f.runtime().last_motion_permit.get("outcome")!="OwnerBusy": break
		await process_frame
	f.expect(all_actor_ticks_unchanged,"every delayed Main attempt consumes no actor tick")
	f.expect(all_native_ticks_unchanged,"every delayed Main attempt consumes no actual worker native tick")
	f.expect(all_rapier_steps_unchanged,"every delayed Main attempt consumes no shared Rapier step")
	f.expect(all_material_steps_unchanged,"every delayed Main attempt consumes no material physical time")
	f.expect(int(f.runtime().motion_permits_refused)>refused and not f.runtime().last_motion_permit.get("ok",false),
		"actual mutex-owned motion admission refuses the superseded installed source")
	f.expect(f.runtime().last_motion_permit.get("outcome")=="InstalledFrameChanged",
		"idle exclusive owner explicitly refuses the exact stale installed publication")
	evidence.delayed_main = {"old_sequence":installed_sequence,"worker_sequence":changed_frame.get("publication_sequence"),
		"refusal":f.runtime().last_motion_permit.duplicate(true),"native_tick":native_tick,"actor_tick":actor_tick,"rapier_steps":rapier_steps,
		"attempts":attempts,"final_attempt":final_attempt,"attempt_count":total_attempts,"retained_attempt_limit":128,
		"attempt_limit":4096,"wall_time_limit_msec":5000,
		"all_attempt_clocks_unchanged":all_native_ticks_unchanged and all_actor_ticks_unchanged and all_rapier_steps_unchanged and all_material_steps_unchanged}
	f.host.set_process(true)
	f.host.set_physics_process(true)
	await f.advance(4,"ordinary Main recovers by polling and acknowledging the actual new source")
	await f.pause()
	await f.until(f.coherent,"post-delay displayed material remains coherent")
	var old_inspection_token: int = await _inventory_admission_negatives()
	if old_inspection_token<=0:
		await _finish(); return
	var target: Dictionary = f.moving_target(7)
	var observation: Dictionary = f.runtime().visible_observation()
	var old_generation: int = int(f.frame().world_generation)
	if not f.expect(not target.is_empty(),"retirement race starts with an exact displayed moving Wood witness"):
		await _finish(); return
	var queued: Dictionary = f.bench.object_shard_m4_action(target.position,"erase",observation,target)
	f.expect(queued.get("ok",false),"real moving edit enters owner queue immediately before Restore")
	var restored: bool = f.bench.restore_start()
	evidence.immediate_restore_admitted = restored
	if not restored:
		# Refusing a pending mutation is an allowed safe ordering. It must
		# complete normally and leave Restore usable on the same owner.
		await f.until(func(): return f.bench.object_shard_m4_port.pending_count()==0,"refused racing Restore lets the original accepted edit finish")
		restored = f.bench.restore_start()
	if not f.expect(restored,"ordinary Restore is admitted directly or after the accepted edit drains"):
		await _finish(); return
	await f.until(f.installed,"Restore replaces the actual ordinary native World")
	f.play()
	if not await f.until(func(): return int(f.diagnostics().get("world_generation",0))>old_generation and f.runtime().physics_ready(),
		"replacement publishes a fresh owner generation and actual geometry acknowledgements"):
		await _finish(); return
	await f.pause()
	await f.until(f.whole_canvas_coherent,"fresh World and live material inventory are jointly displayed")
	var retired_inspection: Dictionary = f.runtime().take_inventory_inspection(old_inspection_token)
	f.expect(not retired_inspection.get("ok",false) and retired_inspection.get("outcome")=="InventoryInspectionRetired",
		"World retirement cannot deliver an accepted read from the queued prior owner")
	evidence.retired_inventory_read = retired_inspection
	f.expect(f.material_count(7)==initial_wood,"queued old-owner edit never debits or duplicates the reopened authored Wood inventory")
	var stale: Dictionary = f.bench.object_shard_m4_action(target.position,"erase",observation,target)
	f.expect(not stale.get("ok",false),"retired World source witness cannot be replayed against the new owner")
	f.expect(str(f.runtime().held_reason).is_empty() and not f.host.simulation_worker.has_failed(),"queue/retirement ordering leaves no stale pose hold or native failure")
	await f.validate_quantity_ledger()
	f.validate_physics()
	evidence.final = f.diagnostics()
	await _finish()

func _finish() -> void:
	if f.host != null:
		f.host.set_process(true)
		f.host.set_physics_process(true)
	f.validate_display()
	evidence.display_coherence = f.display_witness()
	evidence.inventory_witnesses = f.inventory_witnesses
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-lifecycle-adverse-v1","checks":f.checks,"failures":f.failures,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"evidence":evidence,
		"scope":"actual ordinary worker publications, delayed Main callback, refused stale motion, queued moving edit and World replacement"}))
	quit(0 if f.failures.is_empty() else 1)
