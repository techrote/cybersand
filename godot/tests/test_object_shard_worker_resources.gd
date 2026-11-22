extends SceneTree

const Worker = preload("res://scripts/object_shard_native_worker.gd")
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []
var worker
var mailbox: Array[Dictionary] = []


func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _wait(sequence: int, controls: bool = false) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		mailbox.append_array(worker.take_results(16, controls))
		for at: int in range(mailbox.size()):
			if int(mailbox[at].sequence) == sequence:
				var value: Dictionary = mailbox[at]
				mailbox.remove_at(at)
				return value
		await process_frame
	return {}


func _stop() -> Dictionary:
	worker.request_stop()
	var deadline: int = Time.get_ticks_msec() + 10000
	while not worker.diagnostics().stopped and Time.get_ticks_msec() < deadline:
		await process_frame
	return worker.join_if_stopped()


func _run() -> void:
	# Measure the offered rehearsal sizes explicitly. The 512-square case is
	# an upper-bound publication diagnostic, not an offered gameplay preset or
	# evidence that the original default-canvas native 6 MiB budget scales up.
	for extent: Vector2i in [Vector2i(128, 128), Vector2i(192, 128), Vector2i(256, 160), Vector2i(320, 192), Vector2i(512, 512)]:
		worker = Worker.new()
		mailbox.clear()
		var side: int = extent.x
		var height: int = extent.y
		_expect(worker.start({"scenario": 0, "seed": 12, "width": side, "height": height}, side).get("ok", false), "Actual resource-probe owner starts")
		var opened: Dictionary = await _wait(0)
		_expect(not opened.is_empty() and opened.result.get("ok", false), "Actual bounded canvas constructs")
		if opened.is_empty() or not opened.result.get("ok", false):
			await _stop()
			continue
		var session: int = int(opened.session)
		for index: int in range(32):
			worker.submit("snapshot", {}, session, side)
		var deadline: int = Time.get_ticks_msec() + 10000
		while int(worker.diagnostics().data_results) < 32 and Time.get_ticks_msec() < deadline:
			await process_frame
		var full: Dictionary = worker.diagnostics()
		_expect(int(full.data_results) == 32 and int(full.pending_data) == 0, "Exactly32 complete copied frames occupy the reserved data reply capacity")
		_expect(int(full.retained_reply_value_bytes) >= side * height * 5 * 32,
			"Byte accounting includes the full real material and RGBA payload of every retained frame")
		_expect(int(full.maximum_snapshot_value_bytes) < 2 * 1024 * 1024,
			"Measured empty-canvas snapshot remains below the registered2MiB value-payload budget even at512square")
		var observed: Dictionary = worker.submit("observe", {}, session, side)
		var control: Dictionary = await _wait(int(observed.sequence), true)
		_expect(not control.is_empty() and control.result.get("ok", false) and worker.diagnostics().data_results == 32,
			"A real independent control result still completes with32large data frames retained")
		rows.append({"width": side, "height": height, "full_backlog": full,
			"native_accounted_bytes": opened.frame.metrics.get("world_bytes", 0) + opened.frame.metrics.get("coordinator_bytes", 0),
			"scope": "Construction and deliberately saturated publication backlog; not steady-state engine timing"})
		while not worker.take_results(40).is_empty():
			pass
		_expect(worker.diagnostics().retained_reply_value_bytes == 0, "Draining copied values returns their accounted backlog bytes to zero")
		_expect((await _stop()).get("ok", false), "Large publication backlog does not prevent native-owner shutdown")
	# A real faulty schedule exceeds the native promotion-pause deadline. This
	# is an admitted fault-injection API sequence, not a mocked quarantine flag.
	worker = Worker.new()
	mailbox.clear()
	worker.start({"scenario": 0, "seed": 12}, 7001)
	var initial: Dictionary = await _wait(0)
	var session: int = int(initial.session)
	var ticket: Dictionary = worker.submit("edit", {"position": Vector2i(40, 40), "material": 7}, session, 7001)
	await _wait(int(ticket.sequence))
	var prepared: Dictionary = {}
	for attempt: int in range(8):
		ticket = worker.submit("prepare", {}, session, 7001)
		prepared = await _wait(int(ticket.sequence))
		if prepared.result.get("ok", false):
			break
	_expect(prepared.result.get("ok", false), "Real native promotion reaches its unacknowledged precommit barrier")
	var quarantined: Dictionary = {}
	for attempt: int in range(256):
		ticket = worker.submit("tick", {"poses": []}, session, 7001)
		quarantined = await _wait(int(ticket.sequence))
		if quarantined.result.get("outcome") == "Quarantined":
			break
	_expect(quarantined.result.get("outcome") == "Quarantined" and quarantined.frame.quarantined,
		"Native safe-point deadline actually quarantines the deliberately broken schedule")
	var stopped: Dictionary = await _stop()
	_expect(stopped.get("ok", false) and stopped.get("outcome") == "Stopped",
		"Exclusive shutdown/reset recovers an actual quarantined coordinator without losing the owner thread")
	rows.append({"fault": "unacknowledged native promotion deadline", "last_native_result": quarantined.result,
		"terminal": stopped, "worker": worker.diagnostics()})
	print(JSON.stringify({"schema": "objectshard-worker-resource-test-v1", "checks": checks, "failures": failures,
		"scope": "Actual native copy-capacity and quarantine/shutdown evidence; value-byte counts exclude allocator overhead", "rows": rows}))
	quit(0 if failures == 0 else 1)
