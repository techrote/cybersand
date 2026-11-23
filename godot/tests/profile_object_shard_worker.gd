extends SceneTree

# Matched scheduling experiment, not a performance threshold. Both modes execute
# the same native input and real Rapier intervals. Only receipt notification
# consumption changes; neither callback policy grants additional semantic time.
const Host = preload("res://scripts/object_shard_worker_host.gd")
const INTERVALS: int = 240
var host = Host.new()
var notifications: bool = true
var pump_usec: int = 0
var output_path: String = ""
var checks: int = 0
var failures: int = 0
var poll_count: int = 0
var edit_count: int = 0
var last_process_usec: int = 0
var process_intervals: Array[int] = []
var semantic_intervals: Array[int] = []
var observation_costs: Array[int] = []
var pump_costs: Array[int] = []
var active_pump_costs: Array[int] = []
var first_poses: Dictionary = {}
var maximum_displacements: Dictionary = {}
var contact_owners: Dictionary = {}
var sleeping_owners: Dictionary = {}
var publication_digests: Array[String] = []


func _init() -> void:
	Engine.max_fps = 60
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--notifications="):
			notifications = argument.trim_prefix("--notifications=") == "on"
		elif argument.begins_with("--pump-usec="):
			pump_usec = int(argument.trim_prefix("--pump-usec="))
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	call_deferred("_run")


func _run() -> void:
	var started: int = Time.get_ticks_usec()
	_expect(pump_usec in [0, 2000, 4000, 8000, 12000], "only an explicit bounded receipt-pump budget selected")
	if failures:
		quit(1)
		return
	_expect(host.set_event_driven(notifications).get("ok", false), "matched receipt policy selected")
	_expect(host.open({"scenario": 4, "seed": 12, "width": 192, "height": 128}, 9271).get("ok", false),
		"source-matched native worker opened")
	_expect(await _idle(), "initial terrain publication completes")
	var cuts: Array[Dictionary] = []
	for trunk_x: int in [48, 96, 144]:
		for y: int in range(90, 110):
			for x: int in range(trunk_x - 2, trunk_x + 2):
				cuts.append({"position": Vector2i(x, y), "material": 0, "state_a": 0, "state_b": 0, "temperature": 200})
	var fixture_accepted: int = 0
	for offset: int in range(0, cuts.size(), Host.Worker.MAX_EDIT_BATCH):
		var batch: Array = cuts.slice(offset, mini(cuts.size(), offset + Host.Worker.MAX_EDIT_BATCH))
		_expect(host.author_batch(batch).get("ok", false) and await _idle(), "identical bounded support fixture authored")
		fixture_accepted += int(host.last_author_result.get("accepted", 0))
	_expect(fixture_accepted == cuts.size(), "every fixture edit has an actual native receipt")
	_expect(_balanced(), "initial exact quantity ledger")
	if failures:
		await _finish(started, 0, 0)
		return
	# Fixture/setup time is retained separately. All sampled intervals below are
	# the live 240-tick experiment, including promotion, collisions and inputs.
	var initial_tick: int = int(host.frame.tick)
	var play_started: int = Time.get_ticks_usec()
	process_intervals.clear()
	pump_costs.clear()
	active_pump_costs.clear()
	last_process_usec = play_started
	for ordinal: int in range(INTERVALS):
		var tick_started: int = Time.get_ticks_usec()
		_expect(host.request_tick().get("ok", false), "exactly one semantic interval requested")
		await _process_poll(false)
		if ordinal % 4 == 0:
			_expect(host.pending.get("operation") == "tick", "native tick is in flight before input capture")
			var material: int = [2, 3, 6][(ordinal / 4) % 3]
			var parameters: Dictionary = {"position": Vector2i(8 + ((ordinal / 4) % 5), 18),
				"material": material, "state_a": 255 if material == 3 else (180 if material == 6 else 0),
				"state_b": 0, "temperature": 650 if material == 6 else 200}
			_expect(host.queue_action("edit", parameters).get("ok", false), "genuine live material input admitted")
			edit_count += 1
		_pump_receipts()
		if not await _idle(initial_tick + ordinal + 1):
			_expect(false, "interval and queued input complete: " + host.status)
			break
		semantic_intervals.append(Time.get_ticks_usec() - tick_started)
		_expect(int(host.frame.tick) == initial_tick + ordinal + 1 and int(host.publication.tick) == int(host.frame.tick),
			"one coherent semantic/physics publication")
		_expect(int(host.bridge.diagnostics().last_completed_semantic_tick) == int(host.frame.tick),
			"actual physics completed exactly the same semantic interval")
		_observe()
		_expect(_balanced(), "full World plus ObjectShard quantity ledger remains exact")
		if (ordinal + 1) % 60 == 0:
			print(JSON.stringify({"progress": "objectshard-worker-profile", "notifications": notifications, "pump_budget_usec": pump_usec,
				"completed": ordinal + 1, "elapsed_usec": Time.get_ticks_usec() - play_started}))
	var play_elapsed: int = Time.get_ticks_usec() - play_started
	_expect(host.completed_ticks == INTERVALS and int(host.frame.tick) == initial_tick + INTERVALS,
		"all requested real intervals completed without a manufactured clock")
	_expect(host.bridge.bodies.size() == 3 and maximum_displacements.size() == 3,
		"three distinct native owners have actual moving Rapier bodies")
	for distance: float in maximum_displacements.values():
		_expect(distance > 10.0, "each actual body substantially fell")
	_expect(contact_owners.size() == 3, "each actual body made real contact")
	_expect(edit_count == 60 and int(host.frame.accounting.authored_created[2]) > 0 \
		and int(host.frame.accounting.authored_created[3]) > 0 and int(host.frame.accounting.authored_created[6]) > 0,
		"ongoing real Sand/Water/Fire inputs executed")
	await _finish(started, play_elapsed, initial_tick)


func _idle(expected_tick: int = -1) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		# One explicit poll per process callback. Notification mode may consume
		# additional already-completed receipts through the bounded deferred path.
		await _process_poll()
		if host.failed:
			return false
		if host.state == "Idle" and host.actions.is_empty() and host.pending.is_empty() \
			and (expected_tick < 0 or int(host.frame.tick) >= expected_tick):
			return true
	return false


func _process_poll(pump_allowed: bool = true) -> void:
	await process_frame
	var now: int = Time.get_ticks_usec()
	if last_process_usec > 0:
		process_intervals.append(now - last_process_usec)
	last_process_usec = now
	host.poll()
	poll_count += 1
	if pump_allowed:
		_pump_receipts()


func _pump_receipts() -> void:
	if pump_usec == 0:
		return
	var active: bool = not host.pending.is_empty()
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = host.pump_receipts(pump_usec)
	var elapsed: int = Time.get_ticks_usec() - started
	pump_costs.append(elapsed)
	if active:
		active_pump_costs.append(elapsed)
	_expect(result.get("ok", false), "bounded receipt pump remains healthy")


func _observe() -> void:
	var started: int = Time.get_ticks_usec()
	for body: Dictionary in host.bridge.diagnostics().bodies:
		var id: int = int(body.id)
		var position := Vector2(float(body.x), float(body.y))
		if not first_poses.has(id):
			first_poses[id] = position
		maximum_displacements[id] = maxf(float(maximum_displacements.get(id, 0.0)), position.distance_to(first_poses[id]))
		if int(body.reported_contacts) > 0:
			contact_owners[id] = true
		if bool(body.sleeping):
			sleeping_owners[id] = true
	var canonical: Dictionary = {"tick": host.publication.tick, "world": host.publication.world_materials,
		"accounting": host.publication.accounting, "shards": []}
	for shard: Dictionary in host.publication.shards:
		var row: Dictionary = {}
		for key: String in ["id", "generation", "body_generation", "geometry_revision", "applied_physics_revision",
			"position_x", "position_y", "rotation", "materials", "states_a", "states_b", "temperature", "owns_inventory"]:
			row[key] = shard[key]
		canonical.shards.append(row)
	publication_digests.append(JSON.stringify(canonical).sha256_text())
	observation_costs.append(Time.get_ticks_usec() - started)


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
			return false
	return true


func _distribution(values: Array[int]) -> Dictionary:
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	var result: Dictionary = {"count": sorted.size()}
	if not sorted.is_empty():
		for pair: Array in [["p50", 0.50], ["p95", 0.95], ["p99", 0.99]]:
			result[pair[0]] = sorted[mini(sorted.size() - 1, int(ceil(float(sorted.size()) * float(pair[1]))) - 1)]
		result["maximum"] = sorted[-1]
	return result


func _finish(started: int, play_elapsed: int, initial_tick: int) -> void:
	var report: Dictionary = host.diagnostics()
	var identity: Dictionary = {"revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine_sha256": FileAccess.get_sha256(OS.get_executable_path()), "files": {}}
	for path: String in ["res://scripts/object_shard_worker_host.gd", "res://scripts/object_shard_native_worker.gd",
		"res://scripts/object_shard_physics_bridge.gd", "res://tests/profile_object_shard_worker.gd"]:
		identity.files[path] = FileAccess.get_sha256(path)
	for path: String in ["res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
		"res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
		"res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so",
		"res://addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"]:
		if FileAccess.file_exists(path):
			identity.files[path] = FileAccess.get_sha256(path)
	host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.state != "Closed" and Time.get_ticks_msec() < deadline:
		await process_frame
		host.poll()
	_expect(host.state == "Closed", "worker/material/physics disposal acknowledged")
	var result: Dictionary = {"schema": "objectshard-worker-scheduling-profile-v1", "checks": checks, "failures": failures,
		"identity": identity, "engine": Engine.get_version_info(), "platform": OS.get_name(),
		"notifications": notifications, "pump_budget_usec": pump_usec, "requested_process_hz": 60,
		"scope": "Matched 60-Hz-process-cadence scheduling experiment; no display FPS or monitor latency claim. Explicit poll once per process callback; optional main-owner receipt pump has a bounded wait/work budget plus its current handler. Neither receipts nor pump grant new semantic time.",
		"presentation": "Not measured by this headless scheduling profile; mark_presented is deliberately not invoked.",
		"initial_tick": initial_tick, "final_tick": report.tick, "completed_intervals": report.completed_ticks,
		"play_elapsed_usec": play_elapsed, "semantic_ticks_per_wall_second": float(report.completed_ticks) * 1000000.0 / maxf(1.0, float(play_elapsed)),
		"setup_and_finish_inclusive_usec": Time.get_ticks_usec() - started,
		"process_callback_interval_usec": _distribution(process_intervals),
		"semantic_interval_and_input_usec": _distribution(semantic_intervals),
		"publication_comparison_observation_usec": _distribution(observation_costs),
		"observation_scope": "Snapshot hashing is test observation work outside host-stage/semantic-interval timing and inside wall progression; both modes execute the same observation.",
		"pump_call_usec": _distribution(pump_costs), "pump_call_while_pending_usec": _distribution(active_pump_costs),
		"host_stages_usec": report.timings_usec, "host_stage_scope": report.timing_scope,
		"host_stage_sample_capacity": report.timing_sample_capacity, "poll_count": poll_count,
		"actual_live_inputs": edit_count, "actual_physics_steps": report.physics.physics_steps,
		"maximum_displacements": maximum_displacements, "contact_owners": contact_owners.keys(),
		"sleeping_owners": sleeping_owners.keys(), "publication_digests": publication_digests,
		"native_accounting": report.accounting, "host": report}
	if not output_path.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			_expect(false, "profile output file opens")
			result.checks = checks
			result.failures = failures
		else:
			file.store_string(JSON.stringify(result, "  ") + "\n")
			file.close()
	for key: String in ["host", "publication_digests", "native_accounting", "host_stages_usec", "identity"]:
		result.erase(key)
	print(JSON.stringify(result))
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
