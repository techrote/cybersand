extends SceneTree

# Deterministically exercise the production worker's mutex handoff, including a
# packet already extracted by its worker loop. The actual native World consumes
# accepted requests and the actual snapshot builder publishes their receipts.
const Worker = preload("res://scripts/simulation_worker.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const EPOCH: int = 21
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("USABLE002_ADMISSION " + message)


func _frame() -> Dictionary:
	var actors: Array = []
	for owner: int in range(8):
		var center := Vector2(100.5 + owner * 64, 100.5)
		actors.append({"actor_id": owner, "generation": 0, "equipment_epoch": 1,
			"instance_id": "admission-%d" % owner, "usable_index": 0, "state": "held",
			"body_id": owner + 1, "position": center, "rotation": 0.0, "half_extents": Vector2(2, 2),
			"muzzle": center + Vector2(4, 0), "direction": Vector2.RIGHT, "owner_origin": center,
			"active": true, "lease_deadline": 100,
			"parts": [{"body_id": owner + 1, "position": center, "rotation": 0.0, "half_extents": Vector2(2, 2)}]})
	return {"version": 1, "run_id": "admission-fixture", "epoch": EPOCH,
		"tick": 1, "suspended": false, "actors": actors, "devices": []}


func _states(frame: Dictionary) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for row: Dictionary in frame.actors:
		Coupling.append_input(result, int(row.body_id), row.position, row.rotation,
			Vector2(row.half_extents) * 2.0, Vector2.ZERO, 0.0, 1.0, 1)
	return result


func _request(frame: Dictionary, owner: int = 0, sequence: int = 1) -> Dictionary:
	var result: Dictionary = {"version": 1, "run_id": frame.run_id, "epoch": frame.epoch,
		"sequence": sequence, "request_id": "admission-%d-%d" % [owner, sequence],
		"operation": "use", "power": 1.0}
	for field: String in ["actor_id", "generation", "equipment_epoch", "instance_id", "usable_index", "body_id"]:
		result[field] = frame.actors[owner][field]
	return result


func _extract(worker: CyberSimulationWorker) -> Array:
	var result: Array = worker._pending_physical_usables.duplicate(true)
	worker._pending_physical_usables.clear()
	return result


func _worker() -> CyberSimulationWorker:
	var worker := Worker.new()
	worker.set_physical_actor_epoch(EPOCH)
	_check(worker._world.has_method("diagnostic_reset") and bool(worker._world.diagnostic_reset({"workers": 1})),
		"real native worker fixture required")
	return worker


func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		push_error("USABLE002_ADMISSION requires CyberNativeCellWorld")
		quit(1)
		return
	var frame: Dictionary = _frame()
	var states: PackedFloat32Array = _states(frame)
	var worker: CyberSimulationWorker = _worker()
	var request: Dictionary = _request(frame)
	var accepted: Dictionary = worker.set_physical_usable_state(frame, [request], states)
	_check(accepted.status == "queued" and accepted.queued == 1, "valid atomic batch refused")
	_check(worker._rigid_body_states == states and worker._physical_usable_frame == frame,
		"physical pose/mask publication not atomic")
	var retained: Dictionary = frame.duplicate(true)
	frame.actors[0].muzzle = Vector2(-200, -200)
	request.power = 0.0
	accepted.queued = 99
	_check(worker._physical_usable_frame == retained and worker._pending_physical_usables[0].power == 1.0,
		"caller mutation affected an admitted copied packet")
	_check(worker._physical_usable_admission.queued == 1, "returned admission aliases telemetry")
	frame = retained
	var queued: Array = worker._pending_physical_usables.duplicate(true)
	var refused: Dictionary = worker.set_physical_usable_state(frame, [_request(frame, 0, 2), _request(frame, 1)])
	_check(refused.status == "refused" and refused.reason == "actor_inflight" and refused.queued == 0 \
		and worker._pending_physical_usables == queued, "occupied actor allowed a partial peer batch")
	var extracted: Array = _extract(worker)
	refused = worker.set_physical_usable_state(frame, [_request(frame, 0, 3)])
	_check(refused.reason == "actor_inflight", "extracted request lost its in-flight reservation")
	worker._world.prepare_rigid_body_coupling(states, false)
	worker._consume_physical_usables(extracted, EPOCH, true, frame)
	var result: Dictionary = worker._physical_usables.snapshot()
	_check(result.receipts.size() == 1 and result.receipts[0].accepted and result.receipts[0].changed_cells > 0,
		"accepted packet did not execute through native owner")
	_check(worker._physical_usable_inflight.is_empty(), "executed packet retained in-flight slot")
	worker._publish_snapshot(0.0, false, Worker.DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC, true, states, EPOCH)
	var publication: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	_check(publication != null and publication.physical_usables.receipts == result.receipts,
		"production snapshot omitted exact equipment receipt")
	var published_copy: Dictionary = publication.physical_usables.duplicate(true)
	worker.set_physical_usable_state(frame, [_request(frame, 1)], states)
	extracted = _extract(worker)
	_check(worker.cancel_physical_actor_effects(EPOCH, 1), "shared actor cancellation refused")
	worker._consume_physical_usables(extracted, EPOCH, true, frame)
	result = worker._physical_usables.snapshot()
	_check(int(result.write_count_last) == 0, "cancelled extracted equipment became native material")
	_check(publication.physical_usables == published_copy, "later owner state mutated retained snapshot")
	refused = worker.set_physical_usable_state(frame, [_request(frame, 1, 2)], states)
	_check(refused.reason == "cancelled_generation", "copied same-generation frame revived cancelled request")
	frame.actors[1].generation += 1
	frame.tick += 1
	worker.set_physical_usable_state(frame, [_request(frame, 1, 2)], states)
	extracted = _extract(worker)
	var cancelled_frame: Dictionary = frame.duplicate(true)
	cancelled_frame.actors[1].generation += 1
	cancelled_frame.actors[1].active = false
	cancelled_frame.tick += 1
	worker.set_physical_usable_state(cancelled_frame, [], states)
	worker._consume_physical_usables(extracted, EPOCH, true, frame)
	_check(worker._physical_usables.snapshot().write_count_last == 0,
		"new control generation did not retire extracted request")
	refused = worker.set_physical_usable_state(frame, [_request(frame, 1, 3)])
	_check(refused.status == "refused" and refused.reason in ["frame_tick", "stale_generation"],
		"old copied frame resurrected cancelled generation")
	var validator: CyberSimulationWorker = _worker()
	frame = _frame()
	for mutation: Dictionary in [{"power": NAN}, {"body_id": 65}, {"actor_id": true},
		{"equipment_epoch": 0}, {"instance_id": "wrong"}, {"operation": "arbitrary"}]:
		var malformed: Dictionary = _request(frame, 1)
		malformed.merge(mutation, true)
		refused = validator.set_physical_usable_state(frame, [_request(frame), malformed], states)
		_check(refused.status == "refused" and refused.refused == 2 and validator._pending_physical_usables.is_empty(),
			"invalid request partially admitted valid peer: " + str(mutation))
	var batch: Array = []
	for owner: int in range(8):
		batch.append(_request(frame, owner))
	batch.append(_request(frame, 0, 2))
	refused = validator.set_physical_usable_state(frame, batch, states)
	_check(refused.reason == "batch_capacity" and validator._pending_physical_usables.is_empty(),
		"nine-request batch admitted prefix")
	batch.pop_back()
	accepted = validator.set_physical_usable_state(frame, batch, states)
	_check(accepted.queued == 8 and validator._physical_usable_inflight.size() == 8,
		"eight distinct actors did not fit bounded queue")
	extracted = _extract(validator)
	validator.set_frame_state(0, false, true, Vector2i(100, 100), Vector2i(80, 80), Vector2i(80, 80), 0, 0, true, true, true)
	validator._world.prepare_rigid_body_coupling(states, false)
	validator._consume_physical_usables(extracted, EPOCH, false, frame)
	_check(validator._physical_usables.snapshot().write_count_last == 0 and validator._physical_usable_inflight.is_empty(),
		"pause retained or executed queued equipment")
	validator.set_frame_state(0, false, false, Vector2i(100, 100), Vector2i(80, 80), Vector2i(80, 80), 0, 0, true, true, true)
	for row: Dictionary in frame.actors:
		row.generation += 1
	frame.tick += 1
	validator.set_physical_usable_state(frame, [_request(frame)], states)
	extracted = _extract(validator)
	validator.queue_reset(Vector2(100, 100), false, false)
	validator._consume_physical_usables(extracted, EPOCH, true, frame)
	_check(validator._physical_usables.snapshot().projectiles.is_empty() \
		and validator._physical_usables.snapshot().write_count_last == 0, "reset did not retire extracted work")
	for row: Dictionary in frame.actors:
		row.generation += 1
	frame.tick += 1
	refused = validator.set_physical_usable_state(frame, [_request(frame)], states)
	_check(refused.reason == "reset_pending", "pending reset admitted new equipment")
	validator.set_physical_actor_epoch(EPOCH + 1)
	refused = validator.set_physical_usable_state(frame, [_request(frame)], states)
	_check(refused.reason == "epoch", "old physical owner admitted after epoch change")
	var ambiguous: Dictionary = _frame()
	ambiguous.actors[1].parts[0].body_id = 1
	refused = worker.set_physical_usable_state(ambiguous, [])
	_check(refused.reason == "duplicate_body_owner", "duplicate physical part ownership accepted")
	var device_frame: Dictionary = _frame()
	device_frame.actors[0].usable_index = 22
	device_frame.actors[0].state = "fixed"
	var device: Dictionary = {}
	for key: String in ["instance_id", "actor_id", "equipment_epoch", "usable_index", "body_id", "position", "rotation", "half_extents", "state"]:
		device[key] = device_frame.actors[0][key]
	device_frame.devices = [device]
	for mutation: Dictionary in [{"position": Vector2(300, 300)}, {"rotation": PI / 2.0},
		{"half_extents": Vector2(-2, 2)}, {"equipment_epoch": 17}, {"instance_id": "another-device"}]:
		var invalid_frame: Dictionary = device_frame.duplicate(true)
		invalid_frame.devices[0].merge(mutation, true)
		refused = worker.set_physical_usable_state(invalid_frame, [])
		_check(refused.reason in ["device_owner", "device_pose"],
			"processor pose/identity differed from its published physical mount: " + str(mutation))
	print("USABLE002_ADMISSION checks=%d failures=%d native=executed" % [checks, failures])
	quit(1 if failures > 0 else 0)
