extends SceneTree

# Exercise the actual mutex-owned worker queue while its thread is stopped, so
# saturation and cancellation are deterministic. The production snapshot builder
# additionally verifies copied telemetry against the native world adapter.
const Worker = preload("res://scripts/simulation_worker.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const EPOCH: int = 17
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_EFFECT_ADMISSION: " + message)


func requests(count: int, epoch: int = EPOCH, first_actor: int = 0) -> Array:
	var result: Array = []
	for index: int in range(count):
		var actor: int = (first_actor + index) % 8
		result.append({"actor_slot": actor, "epoch": epoch, "sequence": 1,
			"kind": "deposit", "source": Vector2(100 + 32 * actor, 100),
			"origin": Vector2(109 + 32 * actor, 100), "source_body_id": actor + 1,
			"source_part": 0, "radius": 1, "strength": 1.0, "material": 2})
	return result


func states(x: float = 100.0) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	Coupling.append_input(result, 1, Vector2(x, 100), 0.0, Vector2(8, 6),
		Vector2.ZERO, 0.0, 1.0, 1)
	return result


func frame(worker: CyberSimulationWorker, paused: bool) -> void:
	worker.set_frame_state(0, false, paused, Vector2i(100, 100), Vector2i(70, 70),
		Vector2i(100, 100), 0, 0, true, true, true)


func run() -> void:
	var worker := Worker.new()
	worker.set_physical_actor_epoch(EPOCH)
	var batch: Array = requests(8)
	var accepted: Dictionary = worker.set_rigid_body_states(states(), EPOCH, batch)
	expect(accepted.status == "queued" and accepted.queued == 8 and accepted.refused == 0,
		"the complete eight-request batch fits")
	var queued: Array = worker._pending_physical_effects.duplicate(true)
	batch[0].origin = Vector2.ZERO
	accepted.queued = -1
	expect(worker._pending_physical_effects == queued, "producer mutation cannot change queued effects")
	expect(worker.physical_actor_effect_admission().last_batch.queued == 8,
		"returned admission result does not alias internal history")
	var updated_states: PackedFloat32Array = states(110.0)
	var refused: Dictionary = worker.set_rigid_body_states(updated_states, EPOCH, requests(1))
	expect(refused.status == "refused" and refused.reason == "pending_capacity"
		and refused.queued == 0 and refused.refused == 1, "full queue explicitly refuses the new batch")
	expect(worker._pending_physical_effects == queued, "saturation preserves every earlier request")
	expect(worker._rigid_body_states == updated_states and worker._rigid_body_epoch == EPOCH,
		"effect saturation does not withhold the newest body sample")
	refused = worker.set_rigid_body_states(updated_states, EPOCH, requests(9))
	expect(refused.reason == "batch_capacity" and refused.refused == 9 and refused.queued == 0,
		"an oversized batch receives one complete refusal")
	expect(worker._pending_physical_effects == queued, "oversized batch never contributes an eight-request prefix")
	var stats: Dictionary = worker.physical_actor_effect_admission()
	expect(stats.capacity == 8 and stats.pending_requests == 8 and stats.accepted_batches == 1
		and stats.accepted_requests == 8 and stats.refused_batches == 2
		and stats.refused_requests == 10 and stats.overflow_batches == 2,
		"bounded telemetry counts actual admission and overflow outcomes")
	var no_effects: Dictionary = worker.set_rigid_body_states(updated_states, EPOCH)
	expect(no_effects.status == "no_effects" and no_effects.requested == 0
		and worker.physical_actor_effect_admission() == stats,
		"body-only frames preserve the latest nonempty batch outcome")
	stats.last_batch.reason = "mutated"
	expect(worker.physical_actor_effect_admission().last_batch.reason == "batch_capacity",
		"getter returns a deep copy")
	worker._publish_snapshot(0.0, false, Worker.DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC,
		true, updated_states, EPOCH)
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	expect(snapshot != null and snapshot.physical_actor_effect_admission == worker.physical_actor_effect_admission(),
		"production snapshot publishes the complete admission telemetry")
	expect(snapshot.physical_actor_effects.is_empty(), "queue receipts do not impersonate applied-cell receipts")
	var retained: Dictionary = snapshot.physical_actor_effect_admission.duplicate(true)
	expect(not worker.cancel_physical_actor_effects(EPOCH + 1, 0)
		and not worker.cancel_physical_actor_effects(EPOCH, 8)
		and worker._pending_physical_effects == queued, "wrong epoch or actor cannot revoke this queue")
	expect(worker.cancel_physical_actor_effects(EPOCH, 0), "actor-specific cancellation is admitted")
	var surviving: Array = worker._admit_physical_effects(queued, EPOCH)
	expect(surviving.size() == 7 and worker._pending_physical_effects.size() == 7,
		"cancellation retires queued and already-copied work for only one actor")
	var seven: Array = worker._pending_physical_effects.duplicate(true)
	refused = worker.set_rigid_body_states(updated_states, EPOCH, requests(2))
	expect(refused.reason == "pending_capacity" and refused.refused == 2
		and worker._pending_physical_effects == seven, "one free slot never partially admits a two-request batch")
	expect(worker.set_rigid_body_states(updated_states, EPOCH, requests(1)).status == "queued"
		and worker._pending_physical_effects.size() == 8, "fresh work can use the cancelled actor's freed slot")
	expect(worker.cancel_physical_actor_effects(EPOCH) and worker._pending_physical_effects.is_empty(),
		"all-actor cancellation drains the queue")
	expect(worker.physical_actor_effect_admission().accepted_requests == 9
		and worker.physical_actor_effect_admission().refused_requests == 12,
		"cancellation preserves historical admissions and refusals")
	worker.set_physical_actor_epoch(EPOCH + 1)
	stats = worker.physical_actor_effect_admission()
	expect(stats.epoch == EPOCH + 1 and stats.pending_requests == 0 and stats.accepted_batches == 0
		and stats.accepted_requests == 0 and stats.refused_batches == 0 and stats.refused_requests == 0
		and stats.overflow_batches == 0 and stats.last_batch.is_empty(),
		"owner replacement resets the fixed-size telemetry and pending queue")
	expect(snapshot.physical_actor_effect_admission == retained,
		"later cancellation and epoch changes cannot mutate a retained snapshot")
	expect(worker._admit_physical_effects(queued, EPOCH).is_empty(), "copied old-epoch packets stay retired")
	refused = worker.set_rigid_body_states(updated_states, EPOCH, requests(1))
	expect(refused.reason == "epoch" and worker._pending_physical_effects.is_empty(),
		"stale-epoch submission has an explicit refusal")
	stats = worker.physical_actor_effect_admission()
	expect(stats.epoch == EPOCH + 1 and stats.last_batch.epoch == EPOCH and stats.refused_requests == 1
		and stats.overflow_batches == 0, "stale-call telemetry distinguishes owner and request epochs")
	worker.set_rigid_body_states(updated_states, EPOCH + 1, requests(1, EPOCH + 1))
	queued = worker._pending_physical_effects.duplicate(true)
	frame(worker, true)
	refused = worker.set_rigid_body_states(updated_states, EPOCH + 1, requests(1, EPOCH + 1))
	expect(refused.reason == "paused" and worker._pending_physical_effects.is_empty()
		and worker._admit_physical_effects(queued, EPOCH + 1).is_empty(),
		"pause refuses new work and revokes prior copied packets")
	frame(worker, false)
	expect(worker.set_rigid_body_states(updated_states, EPOCH + 1, requests(1, EPOCH + 1)).status == "queued",
		"resume admits fresh generation work")
	worker.queue_reset(Vector2(100, 100), false, false)
	refused = worker.set_rigid_body_states(updated_states, EPOCH + 1, requests(1, EPOCH + 1))
	expect(refused.reason == "reset_pending" and worker._pending_physical_effects.is_empty(),
		"pending reset refuses work without leaving stale queue entries")
	var validator := Worker.new()
	validator.set_physical_actor_epoch(EPOCH)
	var malformed: Array = requests(1)
	malformed.append({"actor_slot": 8})
	refused = validator.set_rigid_body_states(states(), EPOCH, malformed)
	expect(refused.reason == "actor_slot" and refused.refused == 2
		and validator._pending_physical_effects.is_empty(), "invalid actor slot cannot partially enqueue its valid peer")
	malformed[1] = "not a request"
	expect(validator.set_rigid_body_states(states(), EPOCH, malformed).reason == "actor_slot",
		"non-dictionary request is refused before generation access")
	validator.queue_lab({"release": 0})
	expect(validator.set_rigid_body_states(states(), EPOCH, requests(1)).reason == "lab_pending",
		"pending lab transition explicitly refuses actor work")
	var failed := Worker.new()
	failed.set_physical_actor_epoch(EPOCH)
	failed._published_snapshot = CyberSimulationSnapshot.new()
	failed._published_snapshot.simulation_failed = true
	expect(failed.set_rigid_body_states(states(), EPOCH, requests(1)).reason == "simulation_failed",
		"published failed-world quarantine refuses effect admission")
	print("Physical actor effect admission: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
