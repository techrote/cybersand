extends SceneTree

# PLAY-AUTO-002 / #266: fixed-input reference Worlds at explicit 1/2/4/6 and
# production Auto policy. This is native pool/parity/timing evidence, not a
# claim about rendered gameplay FPS or subjective desktop responsiveness.
var assertions: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_AUTO002: " + message)


func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		expect(false, "native phased backend is required")
		print("PLAY_AUTO002_RESULT ", JSON.stringify({
			"assertions": assertions, "failures": failures,
			"error": "native backend unavailable"}))
		quit(1)
		return

	var setting_before: int = int(ProjectSettings.get_setting(
		"cybersand/native_worker_threads", 0))
	var cancel: Callable = func() -> bool: return false
	var progress: Callable = func(_text: String) -> void: pass
	var first: Dictionary = await CyberWorkerBenchmark.sample(
		self, 1, 480, 8, progress, cancel)
	var second: Dictionary = await CyberWorkerBenchmark.sample(
		self, 2, 480, 8, progress, cancel)
	var automatic: Dictionary = await CyberWorkerBenchmark.sample(
		self, 0, 480, 8, progress, cancel)
	var cancelled: Dictionary = await CyberWorkerBenchmark.sample(
		self, 1, 480, 8, progress, func() -> bool: return true)
	var stats: Dictionary = CyberWorkerBenchmark.statistics([1.0, 2.0, 3.0, 4.0])

	expect(bool(first.get("ok", false)) and int(first.requested_workers) == 1
		and int(first.actual_workers) == int(first.resolved_workers),
		"one-worker control has exact requested/resolved/actual readback")
	expect(bool(second.get("ok", false)) and int(second.requested_workers) == 2
		and int(second.actual_workers) == int(second.resolved_workers),
		"two-worker request has exact bounded readback")
	var auto_ok: bool = bool(automatic.get("ok", false)) \
		and int(automatic.requested_workers) == 0
	if bool(automatic.get("threaded_runtime", false)):
		auto_ok = auto_ok \
			and str(automatic.resolution_source) == "native-auto-policy" \
			and int(automatic.actual_workers) == int(automatic.auto_workers)
	else:
		auto_ok = auto_ok \
			and str(automatic.resolution_source) == "no-thread-runtime" \
			and int(automatic.resolved_workers) == 1 \
			and int(automatic.actual_workers) == 1
	expect(auto_ok,
		"Auto row reports either native policy capacity or disclosed no-thread fallback")
	expect(first.level_hash == second.level_hash
		and first.level_hash == automatic.level_hash,
		"same fixed input has equal terminal level hash across worker policies")
	expect(int(first.moves) > 0 and float(first.native_ms.mean) > 0.0
		and float(first.frame_interval_ms.p95) > 0.0
		and float(first.completed_hz) > 0.0,
		"reference control reports real moves and finite native/frame timing")
	expect(int(first.maximum_workers_observed) == 1
		and int(first.worker_participation_ticks) == 0,
		"one-worker control cannot invent multiple task-claiming participants")
	expect(float(first.terminal_export_hash_ms) >= 0.0,
		"terminal serialization cost is recorded separately from measured HZ")
	expect(bool(cancelled.get("cancelled", false))
		and bool(cancelled.get("global_setting_unchanged", false)),
		"bounded cancellation returns without changing process configuration")
	expect(float(stats.mean) == 2.5 and float(stats.p95) == 4.0,
		"timing reducer remains deterministic")
	expect(int(ProjectSettings.get_setting("cybersand/native_worker_threads", 0)) == setting_before,
		"individual samples never mutate the process-wide worker setting")

	# Eight measured ticks keep this automatically discovered regression bounded;
	# the full user benchmark retains its 120-tick default and 600-tick stress mode.
	var suite: Dictionary = await CyberWorkerBenchmark.run(
		self, false, 0, progress, cancel, 8)
	var rows: Array = suite.get("rows", [])
	var distinct_actual: Array = suite.get("distinct_actual_counts", [])
	expect(bool(suite.get("ok", false)) and rows.size() == 10,
		"matrix contains 1/2/4/6/Auto at both reference sizes")
	expect(bool(suite.get("readback_consistent", false))
		and bool(suite.get("global_setting_unchanged", false)),
		"matrix preserves exact worker readback and global configuration")
	if distinct_actual.size() > 1:
		expect(suite.get("parity") == true,
			"distinct actual worker counts retain fixed-input level parity")
	else:
		expect(suite.get("parity") == null,
			"one-count runtime reports parity as unavailable, not invented")

	var requests: Dictionary = {}
	var sizes: Dictionary = {}
	var hashes: Dictionary = {}
	var participating_row: Dictionary = {}
	var multiworker_rows: int = 0
	for row: Dictionary in rows:
		requests[int(row.requested_workers)] = true
		sizes[int(row.side)] = true
		if hashes.has(int(row.side)):
			expect(hashes[int(row.side)] == row.level_hash,
				"per-size hash is identical for request " + str(row.requested_workers))
		else:
			hashes[int(row.side)] = row.level_hash
		expect(bool(row.readback_consistent) and bool(row.global_setting_unchanged),
			"row discloses stable requested/resolved/actual ownership")
		expect(float(row.native_ms.mean) > 0.0 and float(row.completed_hz) > 0.0
			and int(row.moves) > 0 and str(row.level_hash).length() == 64,
			"row has finite native work, throughput and a complete digest")
		expect(float(row.terminal_export_hash_ms) >= 0.0,
			"row separates terminal export/hash cost from measured tick interval")
		expect(int(row.maximum_eligible_blocks) > 0
			and int(row.maximum_scheduler_jobs) >= 1,
			"row reports eligible native scheduler work")
		expect(int(row.maximum_workers_observed) >= 1
			and int(row.maximum_workers_observed) <= int(row.actual_workers),
			"copied TickStats participant count is bounded by the actual pool")
		if int(row.actual_workers) > 1:
			multiworker_rows += 1
			if int(row.maximum_workers_observed) > 1:
				participating_row = row.duplicate(true)

	for requested: int in CyberWorkerBenchmark.SUPPORTED_REQUESTS:
		expect(requests.has(requested),
			"matrix retains requested policy " + ("Auto" if requested == 0 else str(requested)))
	expect(sizes.has(480) and sizes.has(960),
		"both bounded material workload sizes executed")
	if bool(suite.get("threaded_runtime", false)) and multiworker_rows > 0:
		expect(not participating_row.is_empty()
			and int(participating_row.maximum_workers_observed) > 1
			and int(participating_row.worker_participation_ticks) > 0
			and int(participating_row.parallel_phase_ticks) > 0
			and int(participating_row.maximum_scheduler_jobs) > 1,
			"at least one eligible row has multiple actual task-claiming pool workers")
	else:
		expect(multiworker_rows == 0,
			"non-threaded runtime truthfully exposes no multiworker row")
	expect(int(ProjectSettings.get_setting("cybersand/native_worker_threads", 0)) == setting_before,
		"complete matrix leaves production construction setting unchanged")

	print("PLAY_AUTO002_RESULT ", JSON.stringify({
		"assertions": assertions,
		"failures": failures,
		"rows": rows.size(),
		"requested_counts": suite.get("requested_counts", []),
		"distinct_actual_counts": distinct_actual,
		"logical_threads": suite.get("logical_threads", -1),
		"auto_workers": suite.get("auto_workers", -1),
		"parallel_participation_rows": suite.get("parallel_participation_rows", 0),
		"participating_request": participating_row.get("requested_workers", null),
		"participating_actual_workers": participating_row.get("actual_workers", null),
		"maximum_workers_observed": participating_row.get("maximum_workers_observed", 0),
		"worker_participation_ticks": participating_row.get("worker_participation_ticks", 0),
		"participating_parallel_ticks": participating_row.get("parallel_phase_ticks", 0),
		"global_setting_before": setting_before,
		"global_setting_after": ProjectSettings.get_setting(
			"cybersand/native_worker_threads", 0),
		"fixed_input_parity": suite.get("parity", null),
		"rendered_gameplay_fps_measured": false,
		"causal_speedup_claimed": false,
		"per_worker_utilization_measured": false,
		"player_world_reconfigured": false
	}))
	quit(0 if failures == 0 else 1)
