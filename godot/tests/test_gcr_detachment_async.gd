extends SceneTree

# Actual worker publications with bounded adverse receipts; no physics steps or
# efficacy trajectories. Corruptions are publication controls, not native faults.
const Session = preload("res://scripts/solid_detachment_session.gd")
const SolidWorker = preload("res://scripts/solid_detachment_worker.gd")

class ReceiptWorker:
	extends SolidWorker
	var fault: String = ""
	func set_gcr_compound_states(states: PackedFloat64Array, lease_value: Dictionary, epoch: int) -> bool:
		var value: Dictionary = lease_value.duplicate(true)
		if fault=="refused-first":
			value.body_generation += 1
		return super.set_gcr_compound_states(states,value,epoch)
	func _publish_snapshot(step_ms: float, paused: bool, interval: int, force_full: bool = false,
			body_states: PackedFloat32Array = PackedFloat32Array(),body_epoch: int = 0) -> void:
		var saved: Dictionary = _gcr_compound_preparation.duplicate(true)
		if not saved.is_empty():
			_gcr_compound_preparation=saved.duplicate(true)
			match fault:
				"sample": _gcr_compound_preparation.sample += 1
				"session": _gcr_compound_preparation.session += 1
				"epoch": _gcr_compound_preparation.epoch += 1
				"token": _gcr_compound_preparation.lease.token = "0:0"
				"body-generation": _gcr_compound_preparation.lease.body_generation += 1
				"physics-epoch": _gcr_compound_preparation.lease.physics_epoch += 1
				"count": _gcr_compound_preparation.record_count += 1
		super._publish_snapshot(step_ms,paused,interval,force_full,body_states,body_epoch)
		_gcr_compound_preparation=saved

class ReceiptSession:
	extends Session
	var fault: String = ""
	func _create_worker() -> CyberSimulationWorker:
		var value := ReceiptWorker.new()
		value.fault=fault
		return value

var checks: int = 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL GCR DETACHMENT ASYNC ",message)

func release(session: RefCounted, completion: Dictionary) -> void:
	completion["released"] = await session.cut_and_release()
	completion["finished"] = true

func adverse(fault: String) -> void:
	var session := ReceiptSession.new()
	session.fault=fault
	check(await session.open(root,1,"empty",true,"R2"),"actual adverse owner opens "+fault)
	if session.worker==null:
		return
	var completion: Dictionary = {}
	release(session,completion)
	var observed: CyberSimulationSnapshot
	var deadline: int = Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline and not completion.get("finished",false):
		observed=session.worker.take_latest_snapshot(-1)
		if observed!=null and observed.current_rigid_body_states.size()==66:
			break
		await process_frame
	check(observed!=null and observed.current_rigid_body_states.size()==66,"real echoed geometry publication "+fault)
	if observed!=null and observed.current_rigid_body_states.size()==66:
		check(is_instance_valid(session.body) and session.body.freeze and session.physics_paused and session._release_in_progress,"wrong ack cannot unfreeze body "+fault)
		check(session.bridge.manual_step_count()==0,"wrong ack has zero Rapier steps "+fault)
		check(not completion.get("released",false),"wrong ack cannot report release "+fault)
		if fault=="refused-first":
			check(observed.gcr_compound_preparation.is_empty(),"refused first prepare has no success ack")
	session.close()
	for _turn: int in range(120):
		if completion.get("finished",false):
			break
		await process_frame
	check(completion.get("finished",false) and not completion.get("released",false),"retired prime returns refusal "+fault)

func persistent_ack() -> void:
	var session = Session.new()
	check(await session.open(root,1,"empty",true,"R2"),"actual successful owner")
	if not await session.cut_and_release():
		check(false,"actual successful prime");session.close();return
	session.set_paused(true)
	var first: CyberSimulationSnapshot = session.worker.take_latest_snapshot(-1)
	check(first!=null and first.gcr_compound_preparation.get("installed",false),"native success ack exists")
	if first==null:
		session.close();return
	var before: Dictionary = first.gcr_compound_preparation.duplicate(true)
	var latest: CyberSimulationSnapshot = first
	var deadline: int = Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		var next: CyberSimulationSnapshot = session.worker.take_latest_snapshot(latest.serial)
		if next!=null:
			latest=next
			if latest.serial>first.serial+1:
				break
		await process_frame
	check(latest.serial>first.serial,"later actual publication exists")
	check(latest.gcr_compound_preparation==before,"duplicate prepare preserves successful install ack")
	check(first.gcr_compound_preparation==before,"earlier snapshot/lease immutable")
	check(session.bridge.manual_step_count()==0,"ack persistence does not step Rapier")
	session.close()

func failed_publication() -> void:
	# Exclusive pre-thread value-publication seam. This is not an injected native
	# failure or evidence of World quarantine; those have independent gates.
	var owner := SolidWorker.new()
	var previous := CyberSimulationSnapshot.new()
	previous.serial=5
	previous.rigid_body_results=PackedFloat32Array([1,3,4,0,0,0,0,0,1])
	previous.gcr_body_results=PackedFloat64Array([1,3,4,0,0,0,0,0,1,7,0,0,1,73])
	previous.gcr_compound_results=PackedFloat64Array([1,3,4,0,0,0,0,0,1,7,0,0,2,73])
	previous.gcr_compound_preparation={"installed":true,"sample":1,"lease":{"token":"1:1","body_id":1,"body_generation":7,"physics_epoch":1}}
	previous.gcr_compound_diagnostics={"computed":true,"impulse":Vector2(3,4)}
	previous.gcr_result_generation_usec=13
	previous.current_rigid_body_states=PackedFloat32Array([1,50,50,0,2,2,0,0,0,520,1])
	var old_ack: Dictionary = previous.gcr_compound_preparation.duplicate(true)
	var old_diag: Dictionary = previous.gcr_compound_diagnostics.duplicate(true)
	var native_tick: int = int(owner._world.get_tick_index())
	var native_attempted: int = int(owner._world.get_attempted_tick_index())
	var native_failures: int = int(owner._world.get_tick_failure_count())
	owner._snapshot_serial=5;owner._published_snapshot=previous;owner._simulation_failed=true
	owner._publish_failure_snapshot()
	var failed: CyberSimulationSnapshot = owner.take_latest_snapshot(-1)
	check(failed!=null and failed!=previous and failed.simulation_failed and failed.paused,"failed publication is distinct and held")
	if failed!=null:
		check(failed.rigid_body_results.is_empty() and failed.gcr_body_results.is_empty() and failed.gcr_compound_results.is_empty(),"failed publication clears every actionable wrench")
		check(failed.gcr_compound_preparation.is_empty() and failed.gcr_compound_diagnostics.is_empty() and failed.gcr_result_generation_usec==0,"failed publication clears ack/diagnostics/generation cost")
		check(failed.current_rigid_body_states==previous.current_rigid_body_states,"failed publication retains last mask observation")
		check(failed.failed_tick_index==native_attempted and failed.tick_failure_count==native_failures,"failed publication copies actual native counters")
	check(previous.rigid_body_results.size()==9 and previous.gcr_body_results.size()==14 and previous.gcr_compound_results.size()==14,"previous wrench payload immutable")
	check(previous.gcr_compound_preparation==old_ack and previous.gcr_compound_diagnostics==old_diag and previous.gcr_result_generation_usec==13 and not previous.simulation_failed,"previous ack/diagnostics/status immutable")
	check(int(owner._world.get_tick_index())==native_tick and int(owner._world.get_attempted_tick_index())==native_attempted and int(owner._world.get_tick_failure_count())==native_failures,"value failure publication cannot tick or fail World")

func _run() -> void:
	failed_publication()
	for fault: String in ["refused-first","sample","session","epoch","token","body-generation","physics-epoch","count"]:
		await adverse(fault)
	await persistent_ack()
	print("GCR_DETACHMENT_ASYNC_MECHANICAL ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),
		"scope":"real owner/echo/ack controls; zero physics steps; publication corruptions are not native quarantine faults"}))
	quit(0 if failures.is_empty() else 1)
