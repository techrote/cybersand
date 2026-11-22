extends SceneTree

const Host = preload("res://scripts/object_shard_worker_host.gd")
var host = Host.new()
var checks: int = 0
var failures: int = 0
var cases: Array[Dictionary] = []


func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label + " · " + host.status)


func _idle() -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		host.poll()
		if host.failed:
			return false
		if host.state == "Idle" and host.actions.is_empty() and host.pending.is_empty():
			return true
		await process_frame
	return false


func _state(target: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		host.poll()
		if host.state == target:
			return true
		if host.failed:
			return false
		await process_frame
	return false


func _receipt() -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var rows: Array[Dictionary] = host.worker.take_results(1)
		if not rows.is_empty():
			return rows[0]
		await process_frame
	return {}


func _close() -> bool:
	host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.state != "Closed" and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	return host.state == "Closed"


func _block(origin: Vector2i) -> bool:
	for y: int in range(4):
		for x: int in range(4):
			if not host.queue_action("edit", {"position": origin + Vector2i(x, y), "material": 7}).get("ok", false):
				return false
	return await _idle()


func _run() -> void:
	_expect(host.open({"scenario": 0, "seed": 12}, 7101).get("ok", false) and await _idle(), "Actual exclusive worker and Rapier host open")
	_expect(await _block(Vector2i(40, 40)), "First real detached component is authored through native edits")
	for attempt: int in range(8):
		host.request_tick()
		if not await _idle() or host.bridge.bodies.size() == 1:
			break
	_expect(host.bridge.bodies.size() == 1, "A real dynamic owner exists before the cancellation adversary")
	host.defer_prepared_promotion = true
	_expect(await _block(Vector2i(80, 40)), "Second independent component is authored without touching the active owner")
	var before_native_tick: int = int(host.frame.tick)
	var before_completed: int = host.completed_ticks
	var before_steps: int = host.bridge.steps
	_expect(host.request_tick().get("ok", false) and await _state("PreparedForReview"), "Native tick reaches a genuine non-authoritative promotion barrier")
	_expect(int(host.frame.tick) == before_native_tick + 1 and host.bridge.steps == before_steps,
		"Chemistry has advanced exactly once while the Rapier interval is still pending")
	_expect(host.cancel_prepared().get("ok", false) and await _idle(), "Native cancellation releases the preparation barrier")
	var cancellation: Dictionary = {"native_before": before_native_tick, "native_after": host.frame.tick,
		"completed_before": before_completed, "completed_after": host.completed_ticks,
		"physics_before": before_steps, "physics_after": host.bridge.steps, "bodies": host.bridge.bodies.size()}
	cases.append({"case": "cancel_keeps_clock_pair", "observation": cancellation})
	_expect(host.completed_ticks == before_completed + 1 and host.bridge.steps > before_steps and host.bridge.bodies.size() == 1,
		"Cancelling a prepared promotion completes the already-started native tick's physical interval exactly once")
	_expect(int(host.frame.tick) == before_native_tick + 1 and host.frame.world_materials.count(7) == 16,
		"Cancellation preserves the uncommitted World component and executes no extra chemistry")
	host.defer_prepared_promotion = false
	_expect(host.request_tick().get("ok", false) and await _state("Awaiting:motion"), "A real applied-motion result is outstanding before stop")
	var delayed: Dictionary = await _receipt()
	_expect(not delayed.is_empty() and delayed.get("operation") == "motion" and delayed.result.get("applied", false),
		"Delayed stop adversary uses an actual successful native motion receipt")
	before_steps = host.bridge.steps
	host.close()
	var late: Dictionary = host.accept_receipt(delayed)
	_expect(late.get("outcome") == "TransportClosingOrClosed" and host.state == "Closing" and host.bridge.steps == before_steps,
		"A receipt delivered after stop cannot advance Rapier or replace the shutdown state")
	_expect(await _close(), "Late-receipt refusal still permits native disposal and thread join")
	cases.append({"case": "late_close", "result": late, "physics_before": before_steps})

	host = Host.new()
	_expect(host.open({"scenario": 0, "seed": 12}, 7103).get("ok", false) and await _idle(), "Fresh owner opens for cancellation during shutdown")
	host.defer_prepared_promotion = true
	_expect(await _block(Vector2i(60, 40)) and host.request_tick().get("ok", false) and await _state("PreparedForReview"),
		"Shutdown adversary uses an actual prepared component still owned by World")
	before_steps = host.bridge.steps
	host.close()
	var cancel_after_close: Dictionary = host.cancel_prepared()
	_expect(cancel_after_close.get("outcome") == "TransportClosingOrClosed" and host.state == "Closing"
		and not host.failed and host.bridge.steps == before_steps,
		"Public cancellation after close is nonmutating and cannot replace the live shutdown state")
	_expect(await _close(), "Prepared inventory is disposed and the thread joins without a second shutdown repair")
	_expect(host.cancel_prepared().get("outcome") == "TransportClosingOrClosed" and host.state == "Closed",
		"Old preparation data cannot reopen a closed host through cancellation")
	cases.append({"case": "cancel_after_close", "result": cancel_after_close})

	host = Host.new()
	_expect(host.open({"scenario": 0, "seed": 12}, 7102).get("ok", false) and await _idle(), "A fresh native owner opens for operation-identity adversary")
	_expect(host.queue_action("edit", {"position": Vector2i(30, 30), "material": 7}).get("ok", false), "Actual named mutation is admitted")
	host.poll()
	var forged: Dictionary = await _receipt()
	_expect(forged.get("operation") == "edit" and forged.get("result", {}).get("ok", false), "Operation-identity probe captures the real successful native edit result")
	var before_publication: int = host.publication_sequence
	forged.operation = "reset"
	var rejected: Dictionary = host.accept_receipt(forged)
	_expect(rejected.get("outcome") == "WorkerOperationMismatch" and host.state == "Held" and host.last_action.is_empty()
		and host.publication_sequence == before_publication,
		"A mismatched operation label cannot certify or publish a different named operation")
	_expect(await _close(), "Identity failure retains the real owner until explicit disposal succeeds")
	cases.append({"case": "operation_identity", "result": rejected})
	print(JSON.stringify({"schema": "objectshard-worker-adverse-test-v1", "checks": checks, "failures": failures,
		"scope": "Actual worker/native/Rapier cancellation clocks, late shutdown receipts and operation binding", "cases": cases}))
	quit(0 if failures == 0 else 1)
