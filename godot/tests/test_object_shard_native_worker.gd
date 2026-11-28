extends SceneTree

const Worker = preload("res://scripts/object_shard_native_worker.gd")
var checks: int = 0
var failures: int = 0
var worker
var pending: Array[Dictionary] = []


func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _wait_for(sequence: int, control_only: bool = false) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		pending.append_array(worker.take_results(16, control_only))
		for index: int in range(pending.size()):
			if int(pending[index].sequence) == sequence:
				var result: Dictionary = pending[index]
				pending.remove_at(index)
				return result
		await process_frame
	return {}


func _run() -> void:
	worker = Worker.new()
	_expect(worker.start({"scenario": 0, "seed": 12, "width": 192, "height": 128}, 901).get("ok", false), "Worker thread starts")
	var opened: Dictionary = await _wait_for(0)
	_expect(not opened.is_empty() and opened.result.get("ok", false), "Actual native owner constructs on its exclusive thread")
	if opened.is_empty():
		worker.request_stop()
		_finish()
		return
	var session: int = int(opened.session)
	var initial_tick: int = int(opened.frame.tick)
	_expect(int(opened.owner_thread) != OS.get_main_thread_id(), "The native owner is not the Godot main thread")
	_expect(opened.frame.world_materials.size() == 192 * 128, "Copied native World publication contains real material")
	_expect(not worker.submit("tick", {"poses": []}, session, 900).get("ok", true), "Stale transport generation is refused before execution")
	_expect(not worker.submit("tick", {"poses": []}, session + 1, 901).get("ok", true), "Another native session cannot use this transport")
	_expect(not worker.submit("snapshot", {"rid": RID()}, session, 901).get("ok", true), "RIDs never cross into the native worker")
	_expect(not worker.submit("snapshot", {"object": RefCounted.new()}, session, 901).get("ok", true), "Godot objects never cross into the native worker")
	var oversized := PackedByteArray()
	oversized.resize(4097)
	_expect(not worker.submit("snapshot", {"bytes": oversized}, session, 901).get("ok", true), "Oversized copied payload is refused before queue admission")
	var aggregate := PackedFloat64Array()
	aggregate.resize(4096)
	_expect(not worker.submit("snapshot", {"first": aggregate, "second": aggregate}, session, 901).get("ok", true),
		"Aggregate value-byte limit rejects several individually admissible buffers")
	_expect(not worker.submit("reset", {"scenario": "0", "seed": 12}, session, 901).get("ok", true), "Transport never coerces a string into a native scenario identity")
	_expect(not worker.submit("edit", {"position": Vector2i(10, 10), "material": true}, session, 901).get("ok", true), "Transport never coerces a boolean into a native material identity")
	var edit: Dictionary = {"position": Vector2i(10, 10), "material": 7, "state_a": 3, "state_b": 0, "temperature": 417}
	var ticket: Dictionary = worker.submit("edit", edit, session, 901)
	edit.material = 0
	var changed: Dictionary = await _wait_for(int(ticket.sequence))
	_expect(changed.result.get("ok", false), "Ordinary material edit executes on actual native owner")
	_expect(int(changed.frame.world_materials[10 * 192 + 10]) == 7, "Mutation after submission cannot alter the copied native request")
	_expect(int(changed.owner_thread) == int(opened.owner_thread), "The same exclusive native owner performs later calls")
	var tick: Dictionary = worker.submit("tick", {"poses": []}, session, 901)
	var advanced: Dictionary = await _wait_for(int(tick.sequence))
	_expect(advanced.result.get("ok", false) and int(advanced.frame.tick) == initial_tick + 1, "Actual native semantic clock advances once")
	_expect(int(opened.frame.tick) == initial_tick and int(opened.frame.world_materials[10 * 192 + 10]) == 0,
		"Retained native publications are immutable after later mutation")
	var admitted: int = 0
	var refused: int = 0
	for index: int in range(100):
		var request: Dictionary = worker.submit("snapshot", {}, session, 901)
		if request.get("ok", false):
			admitted += 1
		else:
			refused += 1
	_expect(refused > 0 and admitted <= 65, "Data and result capacity bound an undrained producer")
	var deadline: int = Time.get_ticks_msec() + 10000
	while int(worker.diagnostics().data_results) < 32 and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(int(worker.diagnostics().data_results) == 32, "Actual native data replies saturate their separate capacity")
	var observation: Dictionary = worker.submit("observe", {}, session, 901)
	_expect(observation.get("ok", false), "Control request remains admissible under full data replies")
	var observed: Dictionary = await _wait_for(int(observation.sequence), true)
	_expect(not observed.is_empty() and observed.result.get("ok", false), "The independent control consumer completes while data remains saturated")
	_expect(int(worker.diagnostics().data_results) == 32, "Control receipt does not falsely drain the blocked data inventory")
	var reset: Dictionary = worker.submit("reset", {"scenario": 0, "seed": 12}, session, 901)
	var restarted: Dictionary = await _wait_for(int(reset.sequence), true)
	_expect(not restarted.is_empty() and restarted.result.get("ok", false) and int(restarted.session) != session,
		"Explicit reset executes under the same owner and changes native session")
	_expect(int(restarted.frame.tick) == initial_tick and int(restarted.frame.world_materials[10 * 192 + 10]) == 0,
		"Reset disposes old material and exposes the new World, not an old cached frame")
	_expect(not worker.submit("edit", edit, session, 901).get("ok", true), "Obsolete session cannot issue another edit after reset")
	# Drain the old requests. They retain their admitted identity and must not
	# acquire authority over the reset World merely because they were queued.
	var stale_results: int = 0
	deadline = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		for row: Dictionary in worker.take_results(40):
			if str(row.result.get("outcome", "")) == "StaleTransportIdentity":
				stale_results += 1
		var diagnostic: Dictionary = worker.diagnostics()
		if int(diagnostic.pending_data) == 0 and int(diagnostic.data_results) == 0 and int(diagnostic.inflight_sequence) == 0:
			break
		await process_frame
	_expect(stale_results > 0, "Already queued old-session requests are retired without native execution")
	_expect(int(worker.diagnostics().maximum_pending) <= Worker.DATA_CAPACITY + Worker.CONTROL_CAPACITY,
		"Observed queue high-water remains inside independent finite capacities")
	worker.request_stop()
	deadline = Time.get_ticks_msec() + 10000
	while not worker.diagnostics().stopped and Time.get_ticks_msec() < deadline:
		await process_frame
	var terminal: Dictionary = worker.join_if_stopped()
	_expect(terminal.get("ok", false) and terminal.get("outcome") == "Stopped", "Stop/reset/destruction finish on the exclusive native thread")
	_expect(int(terminal.owner_thread) == int(opened.owner_thread), "Terminal disposal retains the original native thread identity")
	worker.request_stop()
	_expect(worker.join_if_stopped() == terminal, "Duplicate stop retains the original exact terminal receipt")
	_expect(not worker.submit("snapshot", {}, int(restarted.session), 901).get("ok", true), "Closed transport never reopens an obsolete operation")
	_finish()


func _finish() -> void:
	print(JSON.stringify({"schema": "objectshard-native-worker-test-v1", "checks": checks, "failures": failures,
		"scope": "Actual native exclusive-worker transport; full Rapier host rehearsal is a separate test", "transport": worker.diagnostics()}))
	quit(0 if failures == 0 else 1)
