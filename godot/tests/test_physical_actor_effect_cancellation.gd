extends SceneTree

# Deterministic cancellation interleaving at a real native material write.
# The wrapper only gates that call; all reads, masks and mutations use native.
const Worker = preload("res://scripts/simulation_worker.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const EPOCH: int = 23
var checks: int = 0
var failures: int = 0


class GatedWorld extends RefCounted:
	var target: Object
	var gate: bool = true
	var entered := Semaphore.new()
	var resume := Semaphore.new()
	var state := Mutex.new()
	var cancellation_returned: bool = false
	var writes_after_cancel: int = 0
	var writes: int = 0

	func material_at(x: int, y: int) -> int:
		return target.material_at(x,y)

	func rigid_body_id_at(x: int, y: int) -> int:
		return target.rigid_body_id_at(x,y)

	func has_failed() -> bool:
		return target.has_failed()

	func emit_disc(x: int, y: int, radius: int, material: int) -> void:
		if gate:
			gate = false
			entered.post()
			resume.wait()
		state.lock()
		if cancellation_returned: writes_after_cancel += 1
		state.unlock()
		target.emit_disc(x,y,radius,material)
		writes += 1

	func did_cancel() -> void:
		state.lock()
		cancellation_returned = true
		state.unlock()


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_EFFECT_CANCELLATION: " + label)


func request(actor: int, sequence: int = 1) -> Dictionary:
	return {"actor_slot":actor,"epoch":EPOCH,"sequence":sequence,
		"kind":"deposit","source":Vector2(100 + 32 * actor,100),
		"origin":Vector2(109 + 32 * actor,100),"source_body_id":actor + 1,
		"source_part":0,"radius":1,"strength":1.0,"material":2}


func body_states() -> PackedFloat32Array:
	var states := PackedFloat32Array()
	for actor: int in 2:
		Coupling.append_input(states,actor+1,Vector2(100+32*actor,100),0.0,Vector2(8,6),Vector2.ZERO,0.0,1.0,1)
	return states


func make_worker() -> CyberSimulationWorker:
	var worker := Worker.new()
	check(worker._world.get_class() == "CyberNativeCellWorld","real native World is required")
	check(worker._world.diagnostic_reset({"workers":1}),"native material fixture reset")
	worker._world.prepare_rigid_body_coupling(body_states(),false)
	worker.set_physical_actor_epoch(EPOCH)
	return worker


func run() -> void:
	var worker := make_worker()
	check(worker.set_rigid_body_states(body_states(),EPOCH,[request(0),request(1)]).queued == 2,
		"independent actors enter the production queue")
	var extracted: Array = worker._pending_physical_effects.duplicate(true)
	worker._pending_physical_effects.clear()
	check(worker.cancel_physical_actor_effects(EPOCH,0),"actor cancellation is admitted after extraction")
	worker._consume_physical_effects(extracted,EPOCH)
	check(worker._world.material_at(109,100) == 0 and worker._world.material_at(141,100) == 2,
		"cancelled extracted output cannot edit material while another actor still can")
	check(worker._physical_effect_receipts.size() == 1 and worker._physical_effect_receipts[0].actor_slot == 1,
		"only the independent surviving actor receives a consumption receipt")
	worker = make_worker()
	check(worker.set_rigid_body_states(body_states(),EPOCH,[request(0)]).queued == 1,"race fixture request queued")
	extracted = worker._pending_physical_effects.duplicate(true)
	worker._pending_physical_effects.clear()
	var gated := GatedWorld.new()
	gated.target = worker._world
	worker._world = gated
	var consumer := Thread.new()
	check(consumer.start(func(): worker._consume_physical_effects(extracted,EPOCH)) == OK,"finite native consume starts")
	gated.entered.wait()
	# The consume thread is paused exactly before its first real cell mutation.
	# A second thread must not acquire the cancellation fence at that point.
	var acquired: bool = worker._mutex.try_lock()
	check(not acquired,"cancellation fence covers the actual native write, not just admission")
	if acquired: worker._mutex.unlock()
	var cancellation_started := Semaphore.new()
	var canceller := Thread.new()
	check(canceller.start(func():
		cancellation_started.post()
		var accepted: bool = worker.cancel_physical_actor_effects(EPOCH,0)
		gated.did_cancel()
		return accepted) == OK,"cancellation races with the held finite transaction")
	cancellation_started.wait()
	gated.resume.post()
	consumer.wait_to_finish()
	check(bool(canceller.wait_to_finish()),"cancellation completes after the in-flight material transaction")
	check(gated.writes > 0 and gated.writes_after_cancel == 0,
		"committed native effects finish before cancellation returns; no late writes follow")
	var writes: int = gated.writes
	var revision: int = gated.target.get_revision()
	extracted[0].request.sequence = 2
	extracted[0].request.origin += Vector2(0,8)
	worker._consume_physical_effects(extracted,EPOCH)
	check(gated.writes == writes and gated.target.get_revision() == revision,
		"fresh sequence cannot revive a copied retired generation after cancellation")
	print("Physical actor effect cancellation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
