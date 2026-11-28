extends SceneTree

const Host = preload("res://scripts/object_shard_worker_host.gd")
var checks: int = 0
var failures: int = 0
var host = Host.new()
var retained_receipt: Dictionary = {}


func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label + " · " + host.status)


func _until_idle(seconds: int = 10) -> bool:
	var deadline: int = Time.get_ticks_msec() + seconds * 1000
	while Time.get_ticks_msec() < deadline:
		host.poll()
		if host.failed:
			return false
		if host.state == "Idle" and host.actions.is_empty() and host.pending.is_empty():
			return true
		await process_frame
	return false


func _until_state(target: String, seconds: int = 10) -> bool:
	var deadline: int = Time.get_ticks_msec() + seconds * 1000
	while Time.get_ticks_msec() < deadline:
		host.poll()
		if host.state == target:
			return true
		if host.failed:
			return false
		await process_frame
	return false


func _author_rectangle(origin: Vector2i, size: Vector2i) -> bool:
	for y: int in range(size.y):
		for x: int in range(size.x):
			if host.actions.size() >= Host.ACTION_CAPACITY:
				if not await _until_idle():
					return false
			var result: Dictionary = host.queue_action("edit", {"position": origin + Vector2i(x, y), "material": 7,
				"state_a": 0, "state_b": 0, "temperature": 200})
			if not result.get("ok", false):
				return false
	return await _until_idle()


func _ticks(count: int) -> bool:
	for index: int in range(count):
		var before: int = host.completed_ticks
		if not host.request_tick().get("ok", false) or not await _until_idle():
			return false
		if host.completed_ticks != before + 1:
			return false
	return true


func _wood_in_world() -> int:
	return host.frame.get("world_materials", PackedByteArray()).count(7)


func _structural() -> int:
	var count: int = 0
	for shard: Dictionary in host.frame.get("shards", []):
		if shard.get("owns_inventory", false):
			count += int(shard.structural)
	return count


func _foreign_host_operations() -> Array:
	return [host.poll(), host.reset(0, 12), host.request_tick(),
		host.queue_action("edit", {"position": Vector2i(10, 10), "material": 0}),
		host.close(), host.cancel_prepared(), host.resume_prepared(), host.diagnostics()]


func _run() -> void:
	_expect(host.open({"scenario": 0, "seed": 12, "width": 192, "height": 128}, 6001).get("ok", false), "Actual async host opens")
	_expect(await _until_idle(), "Native owner thread and main Rapier terrain complete their real startup barrier")
	if failures:
		await _close()
		return
	_expect(int(host.worker.diagnostics().owner_thread) != OS.get_main_thread_id(), "Material owner stays on another thread")
	_expect(host.bridge.space.is_valid() and ClassDB.class_exists(&"RapierPhysicsServer2D"), "Main owns a real Rapier space")
	var original_session: int = host.session
	var foreign := Thread.new()
	_expect(foreign.start(Callable(self, "_foreign_host_operations")) == OK, "Actual foreign-thread host contract adversary starts")
	while foreign.is_alive():
		await process_frame
	var foreign_results: Array = foreign.wait_to_finish()
	var all_foreign_refused: bool = foreign_results.size() == 8
	for result: Dictionary in foreign_results:
		all_foreign_refused = all_foreign_refused and result.get("outcome") == "MainPhysicsOwnerRequired"
	_expect(all_foreign_refused and host.session == original_session and host.state == "Idle" and host.pending.is_empty(),
		"Every public host operation rejects a foreign thread without changing either owner")
	_expect(await _author_rectangle(Vector2i(44, 40), Vector2i(8, 8)), "Named ordinary edits author an actual detached Wood block")
	_expect(_wood_in_world() == 64 and _structural() == 0, "World exclusively owns all 64 authored Wood cells before admission")
	var floor_y: int = -1
	for y: int in range(48, int(host.frame.height)):
		if int(host.frame.world_materials[y * int(host.frame.width) + 48]) == 1:
			floor_y = y
			break
	var promoted: bool = false
	for attempt: int in range(8):
		if not await _ticks(1):
			break
		if _structural() == 64:
			promoted = true
			break
	_expect(promoted and host.bridge.bodies.size() == 1, "Async prepare/reserve/commit/terrain/mask/activation completes for actual material")
	_expect(_wood_in_world() == 0 and int(host.frame.accounting.promoted[7]) == 64, "Promotion debits World once and credits exact shard inventory")
	_expect(host.frame.shards[0].applied_physics_revision == host.frame.shards[0].geometry_revision, "Activated shape revision matches the native material owner")
	var local_bottom: int = 0
	var rectangles: PackedInt32Array = host.frame.shards[0].rectangles
	for at: int in range(0, rectangles.size(), 4):
		local_bottom = maxi(local_bottom, int(rectangles[at + 1]) + int(rectangles[at + 3]))
	if failures:
		await _close()
		return
	var before_publication: int = host.publication_sequence
	var before_tick: int = int(host.frame.tick)
	_expect(host.request_tick().get("ok", false) and await _until_state("Awaiting:motion"), "One actual bounded Rapier piece waits for its native applied receipt")
	var held_steps: int = host.bridge.steps
	var held_publication: Dictionary = host.publication
	var held_pose_serial: int = host.bridge.pose_serial
	var live_frames: int = 0
	for index: int in range(30):
		host.poll(false)
		live_frames += 1
		await process_frame
	_expect(live_frames == 30 and host.bridge.steps == held_steps and host.bridge.pose_serial == held_pose_serial,
		"Delayed worker receipt leaves UI processing live and performs no further physics or pose sampling")
	_expect(host.publication_sequence == before_publication and host.publication == held_publication,
		"Presentation keeps the last applied material/pose publication while motion acknowledgement is delayed")
	_expect(int(host.frame.tick) == before_tick + 1, "Waiting for physics admission does not execute additional chemistry")
	var native_rows: Array[Dictionary] = host.worker.take_results(16)
	_expect(native_rows.size() == 1, "Actual native segment completion produced one copied receipt")
	if native_rows.size() == 1:
		retained_receipt = native_rows[0].duplicate(true)
		_expect(native_rows[0].result.get("applied", false), "The copied receipt records actual native occupancy application")
		_expect(host.accept_receipt(native_rows[0]).get("ok", false), "Main validates the exact real segment receipt before continuing")
		var duplicate_steps: int = host.bridge.steps
		_expect(host.accept_receipt(retained_receipt).get("outcome") == "ExpiredOrDuplicate" and host.bridge.steps == duplicate_steps,
			"Duplicate worker result cannot step Rapier twice")
		var forged: Dictionary = retained_receipt.duplicate(true)
		forged.transport_generation = 6002
		_expect(host.accept_receipt(forged).get("outcome") == "StaleTransportGeneration" and not host.failed,
			"A stale transport generation is refused without disrupting the admitted pending segment")
	_expect(await _until_idle(), "The remaining actual segments finish after delayed receipt consumption resumes")
	_expect(host.publication_sequence > before_publication and host.publication.tick == host.frame.tick,
		"Only completed motion publishes the new coherent native material/pose snapshot")
	_expect(await _ticks(240), "Actual independently threaded native/Rapier simulation runs through falling, collision and settling")
	var observation: Dictionary = host.bridge.diagnostics()
	_expect(observation.bodies.size() == 1 and observation.bodies[0].sleeping,
		"The real body naturally sleeps after contact; the rehearsal never forces sleep")
	var body: Dictionary = observation.bodies[0]
	_expect(floor_y > 48 and float(body.y) > 40.0 and absf(float(body.y) + float(local_bottom) - float(floor_y)) < 1.0,
		"Rapier has moved the material block onto the independently observed native floor")
	var shard: Dictionary = host.frame.shards[0]
	var erased: Vector2i = Vector2i.ZERO
	var located: bool = false
	var transform := Transform2D(float(shard.rotation), Vector2(float(shard.position_x), float(shard.position_y)))
	for index: int in range(shard.materials.size()):
		if int(shard.roles[index]) != 1:
			continue
		var point: Vector2 = transform * (Vector2(index % int(shard.width), index / int(shard.width)) + Vector2.ONE * 0.5)
		var position := Vector2i(floori(point.x), floori(point.y))
		if not Host._owned_cell(host.publication, position).is_empty():
			erased = position
			located = true
			break
	var previous_geometry: int = int(shard.geometry_revision)
	_expect(located and host.queue_action("edit", {"position": erased, "material": 0}).get("ok", false) and await _until_idle(),
		"A named pointer erase targets the actual moving-owner inventory through the strict transaction")
	_expect(_structural() == 63 and _wood_in_world() == 0, "Exactly one owned structural cell is erased; no second World owner appears")
	_expect(int(host.frame.shards[0].geometry_revision) > previous_geometry and
		int(host.frame.shards[0].applied_physics_revision) == int(host.frame.shards[0].geometry_revision),
		"The worker edit waits for actual main shape installation and native geometry acknowledgement")
	_expect(await _ticks(120), "The erased body continues actual native chemistry and Rapier contact")
	var stable: Dictionary = host.bridge.diagnostics().bodies[0]
	_expect(stable.sleeping and absf(float(stable.rotation) - float(body.rotation)) < 0.10,
		"Small resting geometry mutation naturally re-settles without an unexplained large angular jump")
	var old_session: int = host.session
	_expect(host.request_tick().get("ok", false) and await _until_state("Awaiting:motion"), "Another actual motion segment is pending before reset adversary")
	_expect(host.reset(0, 12).get("ok", false) and await _until_idle(), "Explicit reset stays live while an old native motion receipt is pending")
	_expect(host.session != old_session and host.bridge.bodies.is_empty() and _structural() == 0,
		"Only the acknowledged new session removes old RIDs and material owners")
	_expect(int(host.frame.accounting.reset_disposed[7]) >= 63, "Reset reports disposal of the retained prior-session Wood inventory")
	_expect(host.accept_receipt(retained_receipt).get("outcome") == "ExpiredOrDuplicate" and not host.failed,
		"Old-session reply cannot resurrect an owner after reset")
	host.defer_prepared_promotion = true
	_expect(await _author_rectangle(Vector2i(50, 40), Vector2i(4, 4)), "Fresh ordinary edit fixture is authored after reset")
	var prepared: bool = false
	for attempt: int in range(8):
		host.request_tick()
		var deadline: int = Time.get_ticks_msec() + 10000
		while Time.get_ticks_msec() < deadline:
			host.poll()
			if host.state == "PreparedForReview":
				prepared = true
				break
			if host.failed or (host.state == "Idle" and host.completed_ticks > 0):
				break
			await process_frame
		if prepared or host.failed:
			break
	_expect(prepared and _wood_in_world() == 16 and _structural() == 0,
		"Asynchronous precommit staging still leaves all authoritative inventory in World")
	_expect(host.cancel_prepared().get("ok", false) and await _until_idle(), "Precommit cancellation receives a real native terminal receipt")
	_expect(_wood_in_world() == 16 and _structural() == 0 and host.bridge.bodies.is_empty(),
		"Cancellation retains exact native inventory and activates no collider")
	host.defer_prepared_promotion = false
	_expect(await _ticks(3) and _structural() == 16, "Cancelled material remains eligible for a later genuine promotion")
	await _close()


func _close() -> void:
	var report: Dictionary = host.diagnostics()
	host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.state != "Closed" and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	_expect(host.state == "Closed", "Explicit asynchronous shutdown disposes native session and releases main RIDs")
	print(JSON.stringify({"schema": "objectshard-worker-rehearsal-test-v1", "checks": checks, "failures": failures,
		"scope": "Actual standalone exclusive native thread and real main-thread Rapier; not production Workbench integration",
		"report": report}))
	quit(0 if failures == 0 else 1)
