extends SceneTree

const Rendezvous = preload("res://scripts/workbench_native_rendezvous.gd")
const Worker = preload("res://scripts/simulation_worker.gd")

class Mailbox extends RefCounted:
	var mutex := Mutex.new()
	var thread := Thread.new()
	var entered := Semaphore.new()
	var value: Dictionary

	func poll() -> Dictionary:
		if not mutex.try_lock(): return {"status":"contended"}
		var result: Dictionary = value
		mutex.unlock()
		return result

	func change_after(next: Dictionary, delay_usec: int, locked: bool = false) -> Error:
		return thread.start(func() -> void:
			if locked:
				mutex.lock()
				entered.post()
			OS.delay_usec(delay_usec)
			if not locked: mutex.lock()
			value = next
			mutex.unlock())

	func join() -> void:
		if thread.is_started(): thread.wait_to_finish()

class CompletionClock extends Rendezvous:
	var boundary_offset: int = 0
	var retained_marker: Callable

	func _completion_time_usec() -> int:
		return deadline_usec + boundary_offset

	func _separate_render_thread() -> bool:
		return true

	func _queue_render_marker(callback: Callable) -> void:
		# Retain a pending native callback without executing rendering work.
		# This isolates the decision boundary in both scheduling policies.
		retained_marker = callback

class MailboxWorker extends Worker:
	func install(value: CyberSimulationSnapshot) -> void:
		_running = true
		_published_physics_snapshot = value
		_published_snapshot = value
		_workbench_sample = {"epoch":7, "session":11}

var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var expected := {"sample":5, "epoch":7, "session":11, "world_generation":3}


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("NATIVE_RENDEZVOUS: " + label)


func snapshot(sample: int = 4) -> CyberSimulationSnapshot:
	var result := CyberSimulationSnapshot.new()
	result.rigid_body_epoch = 7
	result.physics_world_generation = 3
	result.lab_context = {"workbench_completed_sample":sample, "workbench_refusal":"",
		"workbench_gcr":{"epoch":7, "session":11, "valid":true,
			"sample_tick":20, "rows":[{"sample":sample}, {"sample":sample}]}}
	return result


func active(value: CyberSimulationSnapshot) -> Dictionary:
	return {"status":"active", "epoch":7, "session":11, "snapshot":value}


func catchup(frame: int = 1) -> RefCounted:
	var waiter = Rendezvous.new()
	waiter.begin_callback(frame)
	waiter.begin_callback(frame)
	return waiter


func retain(label: String, result: Dictionary) -> void:
	var row := result.duplicate()
	row.erase("snapshot")
	row["case"] = label
	observations.append(row)


func _run() -> void:
	var mailbox := Mailbox.new()
	mailbox.value = active(snapshot())
	var waiter = Rendezvous.new()
	waiter.begin_callback(1)
	var result: Dictionary = waiter.wait_for_sample(mailbox.poll, expected)
	check(result.status == "not_catchup" and result.polls == 0 and result.sleeps == 0,
		"one ordinary callback never waits or polls")
	waiter.begin_callback(1)
	var completed: CyberSimulationSnapshot = snapshot(5)
	check(mailbox.change_after(active(completed), 2500) == OK, "actual asynchronous publisher starts")
	result = waiter.wait_for_sample(mailbox.poll, expected)
	mailbox.join()
	check(result.status == "ready" and result.get("snapshot") == completed,
		"catch-up callback observes exact immutable completion from a real thread")
	check(result.sleeps > 0 and result.polls > 1, "wait sleeps between nonblocking reads")
	check(result.requested_sleep_usec <= Rendezvous.MAX_FRAME_WAIT_USEC,
		"requested sleeps respect one fixed-step window")
	retain("completion", result)
	var first_deadline: int = waiter.deadline_usec
	waiter.begin_callback(1)
	var next_expected := expected.duplicate()
	next_expected.sample = 6
	result = waiter.wait_for_sample(mailbox.poll, next_expected)
	check(result.status == "timeout" and waiter.deadline_usec == first_deadline,
		"later callback shares the original absolute deadline")
	retain("shared-deadline-timeout", result)
	waiter.begin_callback(1)
	result = waiter.wait_for_sample(mailbox.poll, next_expected)
	check(result.status == "timeout" and result.polls == 0 and result.sleeps == 0,
		"exhausted process frame cannot obtain another wait budget")
	waiter.begin_callback(2)
	check(waiter.deadline_usec == 0 and waiter.callback_count == 1 and waiter.total_wait_usec == 0,
		"only the next actual process-frame identity resets the budget")

	var malformed: Array[Dictionary] = []
	var wrong := active(snapshot(5)); wrong.epoch = 8
	malformed.append({"label":"worker epoch", "value":wrong, "status":"owner_changed"})
	wrong = active(snapshot(5)); wrong.session = 12
	malformed.append({"label":"worker session", "value":wrong, "status":"owner_changed"})
	var value: CyberSimulationSnapshot = snapshot(5); value.rigid_body_epoch = 8
	malformed.append({"label":"snapshot epoch", "value":active(value), "status":"owner_changed"})
	value = snapshot(5); value.physics_world_generation = 4
	malformed.append({"label":"World generation", "value":active(value), "status":"owner_changed"})
	value = snapshot(5); value.simulation_failed = true
	malformed.append({"label":"failed native owner", "value":active(value), "status":"failed"})
	value = snapshot(5); value.lab_context.workbench_refusal = "invalid sample"
	malformed.append({"label":"native refusal", "value":active(value), "status":"native_refusal"})
	value = snapshot(5); value.lab_context.workbench_gcr.session = 12
	malformed.append({"label":"feedback session", "value":active(value), "status":"native_refusal"})
	value = snapshot(5); value.lab_context.workbench_gcr.valid = false
	malformed.append({"label":"invalid feedback", "value":active(value), "status":"native_refusal"})
	value = snapshot(5); value.lab_context.workbench_gcr.rows[1].sample = 4
	malformed.append({"label":"mismatched body sample", "value":active(value), "status":"native_refusal"})
	value = snapshot(5); value.lab_context.workbench_gcr.rows = []
	malformed.append({"label":"empty response", "value":active(value), "status":"native_refusal"})
	malformed.append({"label":"retired mailbox", "value":active(null), "status":"retired"})
	malformed.append({"label":"user pause/reset", "value":{"status":"transition"}, "status":"transition"})
	for row: Dictionary in malformed:
		mailbox.value = row.value
		result = catchup().wait_for_sample(mailbox.poll, expected)
		check(result.status == row.status and not result.has("snapshot") and result.sleeps == 0,
			str(row.label) + " refuses immediately without granting a physical packet")
		retain(str(row.label), result)

	# A no-new-sample status publication may be locally paused even while the
	# user is playing. Its exact completed response remains valid.
	value = snapshot(5); value.paused = true
	mailbox.value = active(value)
	result = catchup().wait_for_sample(mailbox.poll, expected)
	check(result.status == "ready", "local paused status is not confused with user pause")

	mailbox.value = active(snapshot())
	check(mailbox.change_after({"status":"retired"}, 1500) == OK, "retiring publisher starts")
	result = catchup().wait_for_sample(mailbox.poll, expected)
	mailbox.join()
	check(result.status == "retired" and not result.has("snapshot"), "stop during wait cannot admit old authority")
	retain("stop-during-wait", result)

	mailbox.value = active(snapshot())
	check(mailbox.change_after(active(snapshot(5)), 30000, true) == OK, "contended publisher starts")
	mailbox.entered.wait()
	result = catchup().wait_for_sample(mailbox.poll, expected)
	mailbox.join()
	check(result.status == "timeout" and result.lock_misses > 0 and not result.has("snapshot"),
		"mutex contention uses nonblocking reads and refuses completion after the deadline")
	check(result.requested_sleep_usec <= Rendezvous.MAX_FRAME_WAIT_USEC,
		"contended waits retain the bounded requested sleep total")
	retain("mutex-contention", result)
	result = catchup(2).wait_for_sample(mailbox.poll, expected)
	check(result.status == "ready", "later genuine callback may observe the late completion")
	result = catchup().wait_for_sample(func() -> Dictionary:
		OS.delay_usec(20000)
		return active(snapshot(5)), expected)
	check(result.status == "timeout" and not result.has("snapshot") and result.sleeps == 0,
		"an unexpectedly slow observation cannot accept a completion after the deadline")
	retain("late-reader", result)

	# The recorded ce9f ready decision crossed its deadline by 9 microseconds
	# during row validation. Inject only the final clock read, exercising the
	# actual owner/sample validation and final ready-result fence deterministically.
	for overlap: bool in [false,true]:
		for offset: int in [-1,0,9]:
			var boundary := CompletionClock.new()
			boundary.boundary_offset = offset
			boundary.begin_callback(42,overlap)
			boundary.begin_callback(42,overlap)
			result = boundary.wait_for_sample(func() -> Dictionary: return active(snapshot(5)),expected)
			var before_deadline: bool = offset < 0
			check(result.status == ("ready" if before_deadline else "timeout"),
				"final decision at offset %d respects expiry in overlap=%s" % [offset,overlap])
			check(result.has("snapshot") == before_deadline and result.polls==1 and result.sleeps==0,
				"final expired decision supplies no snapshot after real row validation")
			check(int(result.completed_usec)==boundary.deadline_usec+offset and
				int(result.deadline_usec)==boundary.deadline_usec,
				"final timestamp and original shared deadline remain explicit")
			retain("final-boundary-%s-%d" % [overlap,offset],result)

	var worker := MailboxWorker.new()
	worker.install(snapshot())
	check(worker.try_read_physics_mailbox().status == "active", "production mailbox exposes only retained immutable reference")
	worker._published_physics_snapshot = null
	check(worker.try_read_physics_mailbox().status == "retired", "missing early mailbox cannot fall back to graphical authority")
	worker.install(snapshot())
	worker._combined_physics_publication = true
	worker._published_snapshot = snapshot(5)
	check(worker.try_read_physics_mailbox().snapshot == worker._published_snapshot,
		"explicit combined control retains its selected graphical delivery")
	worker._published_physics_snapshot = null
	check(worker.try_read_physics_mailbox().status == "retired", "combined mode retains explicit retirement fence")
	for transition: String in ["_paused", "_reset_requested", "_world_change_inflight"]:
		worker.install(snapshot())
		worker.set(transition, true)
		check(worker.try_read_physics_mailbox().status == "transition", transition + " prevents a wait")
		worker.set(transition, false)
	for transition: String in ["_lab_request", "_prepared_physical_publication", "_prepared_physical_frame_hold"]:
		worker.install(snapshot())
		worker.set(transition, {"serial":1})
		check(worker.try_read_physics_mailbox().status == "transition", transition + " prevents a wait")
		worker.set(transition, {})
	worker._running = false
	check(worker.try_read_physics_mailbox().status == "retired", "stopped worker cannot be polled as live")
	worker = null
	var report := {"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks":checks, "failures":failures, "observations":observations,
		"scope":"Rendezvous deadline, async mailbox and owner fences; real physical equivalence is a separate application gate."}
	var output: String = OS.get_environment("CYBERSAND_NATIVE_RENDEZVOUS_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t") + "\n")
	print("NATIVE_RENDEZVOUS: ", checks, " assertions, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
