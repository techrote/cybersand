extends SceneTree

# Sustained actual worker/main-thread execution. This deliberately uses public
# owner-aware input while native chemistry and real Rapier intervals continue.
# It is an unpaced correctness/throughput run, not display-FPS qualification.
const Host = preload("res://scripts/object_shard_worker_host.gd")
const ENDPOINT: int = 3600
var host = Host.new()
var checks: int = 0
var failures: int = 0
var output_path: String = ""
var trace_path: String = ""
var pump_budget_usec: int = 4000
var actions_queued: int = 0
var seen_moving: Dictionary = {}
var seen_sleeping: Dictionary = {}
var first_poses: Dictionary = {}
var maximum_displacements: Dictionary = {}
var largest_body_count: int = 0
var contacts_seen: bool = false
var fire_seen: bool = false
var smoke_seen: bool = false
var continued_edit_tick: int = 0
var erosion_reference: Dictionary = {}
var erosion_rotation_maximum: float = 0.0
var erosion_translation_maximum: float = 0.0
var tick_costs: Array[int] = []
var poll_count: int = 0
var source_identity: String = ""


func _init() -> void:
	Engine.max_fps = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--trace="):
			trace_path = argument.trim_prefix("--trace=")
		elif argument.begins_with("--pump-usec="):
			pump_budget_usec = int(argument.trim_prefix("--pump-usec="))
	source_identity = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	call_deferred("_run")


func _run() -> void:
	var started: int = Time.get_ticks_usec()
	_expect(pump_budget_usec in [0, 2000, 4000], "only a preflight receipt pump budget is selected")
	if failures:
		quit(1)
		return
	_expect(host.open({"scenario": 4, "seed": 12, "width": 192, "height": 128}, 8719, trace_path).get("ok", false),
		"three reacting native structures opened on an exclusive worker")
	_expect(await _idle(), "actual initial native/terrain barrier completes")
	if failures:
		await _finish(started)
		return
	var initial_tick: int = int(host.frame.tick)
	_expect(int(host.worker.diagnostics().owner_thread) != OS.get_main_thread_id(), "native owner is the real separate thread")
	# Three independent complete support cuts. One queue does not defer normal
	# ticking indefinitely; subsequent edits below deliberately overlap tick work.
	for trunk_x: int in [48, 96, 144]:
		for y: int in range(90, 110):
			for x: int in range(trunk_x - 2, trunk_x + 2):
				if host.actions.size() >= Host.ACTION_CAPACITY:
					_expect(await _idle(), "bounded support stroke drains without dropping admitted edits")
				_expect(_queue(Vector2i(x, y), 0), "structural support edit admitted")
	_expect(await _idle() and _balanced(), "support edits complete with exact material ledger")
	while int(host.frame.tick) < ENDPOINT and not host.failed:
		var before: int = int(host.frame.tick)
		var tick_started: int = Time.get_ticks_usec()
		_expect(host.request_tick().get("ok", false), "one next semantic interval requested")
		if before % 12 == 0:
			host.poll()
			_expect(host.pending.get("operation") == "tick", "native tick is actually in flight before the live edit")
			# Paint during live tick work through the same named action path as the
			# mouse. Inputs are real Sand, Water and external Fire, never decoration.
			var ordinal: int = before / 12
			var material: int = [2, 3, 6][ordinal % 3]
			_expect(_queue(Vector2i(8 + (ordinal % 5), 18), material), "continued material edit admitted during progression")
		if not await _idle(before + 1):
			_expect(false, "sustained tick/action receipt sequence completes: " + host.status)
			break
		tick_costs.append(Time.get_ticks_usec() - tick_started)
		_expect(int(host.frame.tick) == before + 1 and int(host.publication.tick) == int(host.frame.tick),
			"native interval advances once and its matching material/pose publication completes")
		_expect(int(host.bridge.diagnostics().last_completed_semantic_tick) == int(host.frame.tick),
			"real physics completion names the same native semantic tick")
		_observe()
		if int(host.frame.tick) % 60 == 0:
			_expect(_balanced(), "sustained material counts equal the full native quantity ledger")
		if int(host.frame.tick) == 2400:
			_expect(seen_sleeping.size() == 3, "all three real bodies have naturally settled before further destruction")
			_expect(await _erase_settled_cell(), "continued play erases one actual owned cell after long settling")
			_expect(_balanced(), "post-settling destructive edit is exactly accounted")
		if int(host.frame.tick) % 600 == 0:
			print(JSON.stringify({"progress": "objectshard-continuous-physics", "tick": host.frame.tick,
				"actual_bodies": host.bridge.bodies.size(), "edits": actions_queued,
				"physics_steps": host.bridge.steps, "elapsed_usec": Time.get_ticks_usec() - started}))
	_expect(not host.failed and int(host.frame.tick) == ENDPOINT, "all 3600 native ticks reached with a healthy actual host")
	_expect(host.completed_ticks == ENDPOINT - initial_tick, "host counts every native/physics interval exactly once")
	_expect(largest_body_count == 3 and host.bridge.bodies.size() == 3, "three distinct native material owners retain real bodies")
	_expect(seen_moving.size() == 3 and contacts_seen, "all three real bodies moved and made observed Rapier contact")
	for distance: float in maximum_displacements.values():
		_expect(distance > 10.0, "each detached body makes a substantial actual fall rather than a trivial pose change")
	_expect(seen_sleeping.size() == 3, "each moving owner naturally reached sleeping state")
	var final_sleeping: int = 0
	for body: Dictionary in host.bridge.diagnostics().bodies:
		if bool(body.sleeping):
			final_sleeping += 1
	_expect(final_sleeping == 3, "continued play and post-rest erosion end in actual sustained sleeping state")
	_expect(not erosion_reference.is_empty() and erosion_rotation_maximum < 0.10 and erosion_translation_maximum < 0.50,
		"one-cell post-rest erosion does not reintroduce the late violent rotation or penetration")
	_expect(continued_edit_tick == 2400 and actions_queued >= 300, "many live edits and a post-settling destructive edit actually ran")
	_expect(int(host.frame.metrics.get("products_created", 0)) > 0 and fire_seen and smoke_seen,
		"genuine chemistry, Fire and Smoke remained active in the long session")
	_expect(int(host.frame.accounting.authored_created[2]) > 0 and int(host.frame.accounting.authored_created[3]) > 0,
		"real authored Sand and Water were accepted during continuous play")
	_expect(_balanced(), "final owned-plus-World inventory has no loss or duplicate ownership")
	await _finish(started)


func _queue(position: Vector2i, material: int) -> bool:
	var parameters: Dictionary = {"position": position, "material": material, "state_a": 0, "state_b": 0, "temperature": 200}
	if material == 3:
		parameters.state_a = 255
	if material == 6:
		parameters.state_a = 180
		parameters.temperature = 650
	var receipt: Dictionary = host.queue_action("edit", parameters)
	if receipt.get("ok", false):
		actions_queued += 1
	return bool(receipt.get("ok", false))


func _idle(expected_tick: int = -1) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		host.poll()
		poll_count += 1
		if pump_budget_usec > 0 and not host.pump_receipts(pump_budget_usec).get("ok", false):
			return false
		if host.failed:
			return false
		if host.state == "Idle" and host.actions.is_empty() and host.pending.is_empty() \
			and (expected_tick < 0 or int(host.frame.tick) >= expected_tick):
			return true
		await process_frame
	return false


func _observe() -> void:
	var physical: Dictionary = host.bridge.diagnostics()
	largest_body_count = maxi(largest_body_count, physical.bodies.size())
	for body: Dictionary in physical.bodies:
		var id: int = int(body.id)
		var position := Vector2(float(body.x), float(body.y))
		if not first_poses.has(id):
			first_poses[id] = position
		var displacement: float = position.distance_to(first_poses[id])
		maximum_displacements[id] = maxf(float(maximum_displacements.get(id, 0.0)), displacement)
		if displacement > 0.5:
			seen_moving[id] = true
		if bool(body.sleeping):
			seen_sleeping[id] = true
		contacts_seen = contacts_seen or int(body.reported_contacts) > 0
		if not erosion_reference.is_empty() and id == int(erosion_reference.id):
			erosion_rotation_maximum = maxf(erosion_rotation_maximum,
				absf(float(body.rotation) - float(erosion_reference.rotation)))
			erosion_translation_maximum = maxf(erosion_translation_maximum,
				position.distance_to(Vector2(erosion_reference.x, erosion_reference.y)))
	for shard: Dictionary in host.publication.shards:
		if shard.get("owns_inventory", false):
			_expect(int(shard.applied_physics_revision) == int(shard.geometry_revision) and not shard.geometry_pending,
				"visible material never outruns its installed exact geometry")
	var materials: PackedByteArray = host.publication.world_materials
	fire_seen = fire_seen or materials.has(6)
	smoke_seen = smoke_seen or materials.has(4)


func _erase_settled_cell() -> bool:
	for shard: Dictionary in host.publication.shards:
		if not shard.get("owns_inventory", false):
			continue
		var transform := Transform2D(float(shard.rotation), Vector2(float(shard.position_x), float(shard.position_y)))
		for index: int in range(shard.materials.size()):
			if int(shard.roles[index]) != 1:
				continue
			var point: Vector2 = transform * (Vector2(index % int(shard.width), index / int(shard.width)) + Vector2.ONE * 0.5)
			var position := Vector2i(floori(point.x), floori(point.y))
			var owned: Dictionary = Host._owned_cell(host.publication, position)
			if owned.is_empty() or int(owned.id) != int(shard.id) or int(owned.cell) != index:
				continue
			var structural_before: int = int(shard.structural)
			var revision_before: int = int(shard.geometry_revision)
			erosion_reference = {"id": shard.id, "x": shard.position_x, "y": shard.position_y, "rotation": shard.rotation}
			if not _queue(position, 0) or not await _idle():
				return false
			for after: Dictionary in host.publication.shards:
				if int(after.id) == int(shard.id):
					continued_edit_tick = int(host.frame.tick)
					return int(after.structural) == structural_before - 1 \
						and int(after.geometry_revision) > revision_before \
						and int(after.applied_physics_revision) == int(after.geometry_revision)
	return false


func _balanced() -> bool:
	var actual := PackedInt64Array()
	actual.resize(256)
	for material: int in host.frame.world_materials:
		actual[material] += 1
	for shard: Dictionary in host.frame.shards:
		if shard.get("owns_inventory", false):
			for material: int in shard.materials:
				if material != 0:
					actual[material] += 1
	var ledger: Dictionary = host.frame.accounting
	for material: int in range(1, 256):
		var expected: int = int(ledger.setup_created[material]) + int(ledger.authored_created[material]) \
			- int(ledger.authored_destroyed[material]) + int(ledger.world_tick_delta[material]) \
			+ int(ledger.created[material]) - int(ledger.destroyed[material]) \
			- int(ledger.expired[material]) - int(ledger.reset_disposed[material])
		if actual[material] != expected:
			push_error("Actual native inventory mismatch for material %d: %d versus ledger %d" % [material, actual[material], expected])
			return false
	return true


func _finish(started: int) -> void:
	var report: Dictionary = host.diagnostics()
	host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.state != "Closed" and Time.get_ticks_msec() < deadline:
		host.poll()
		await process_frame
	_expect(host.state == "Closed", "long-running worker and RIDs shut down through acknowledged disposal")
	tick_costs.sort()
	var timing: Dictionary = {"count": tick_costs.size(), "scope": "Unpaced actual-host tick plus queued input completion; no target-display FPS claim"}
	if not tick_costs.is_empty():
		for pair: Array in [["p50_usec", 0.50], ["p95_usec", 0.95], ["p99_usec", 0.99]]:
			timing[pair[0]] = tick_costs[mini(tick_costs.size() - 1, int(ceil(float(tick_costs.size()) * float(pair[1]))) - 1)]
		timing["maximum_usec"] = tick_costs[-1]
	var result: Dictionary = {"schema": "objectshard-continuous-physics-test-v1", "checks": checks, "failures": failures,
		"source_revision": source_identity, "engine": Engine.get_version_info(), "platform": OS.get_name(),
		"tick": report.tick, "completed_ticks": report.completed_ticks, "actions_queued": actions_queued,
		"moving_owners": seen_moving.size(), "sleeping_owners": seen_sleeping.size(), "maximum_displacements": maximum_displacements,
		"real_contacts": contacts_seen, "fire_seen": fire_seen, "smoke_seen": smoke_seen,
		"post_settle_edit_tick": continued_edit_tick, "physics_steps": report.physics.physics_steps,
		"pump_budget_usec": pump_budget_usec,
		"post_erosion_maximum_rotation": erosion_rotation_maximum,
		"post_erosion_maximum_translation": erosion_translation_maximum,
		"publication_sequence": report.publication_sequence, "native_accounting": report.accounting,
		"worker": report.worker, "timing": timing, "poll_count": poll_count,
		"elapsed_usec": Time.get_ticks_usec() - started, "report": report}
	if not output_path.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			_expect(false, "continuous test report file opens")
			result.checks = checks
			result.failures = failures
		else:
			file.store_string(JSON.stringify(result, "  ") + "\n")
			file.close()
	result.erase("report")
	result.erase("native_accounting")
	result.erase("worker")
	print(JSON.stringify(result))
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
