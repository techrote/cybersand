class_name CyberWorkerBenchmark
extends RefCounted

# Reference workload, never the player's World. One native tick per frame;
# frame intervals include test/UI scheduling, not normal gameplay rendering.
# Worker selection is applied to each fresh reference World. This helper never
# rewrites the process-wide project setting to retune another live owner.
const SUPPORTED_REQUESTS: Array[int] = [1, 2, 4, 6, 0]
const WARMUP_TICKS: int = 10
const SAMPLE_TIMEOUT_MS: int = 120000


static func statistics(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "p95": 0.0, "max": 0.0}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {"mean": total / values.size(), "p95": ordered[ceili(values.size() * 0.95) - 1], "max": ordered[-1]}


static func worker_resolution(requested: int) -> Dictionary:
	var logical: int = maxi(1, int(ClassDB.class_call_static(
		&"CyberNativeCellWorld", &"logical_processor_count")))
	var automatic: int = int(ClassDB.class_call_static(
		&"CyberNativeCellWorld", &"auto_worker_threads", logical))
	var threaded: bool = not OS.has_feature("web") or OS.has_feature("threads")
	if requested not in SUPPORTED_REQUESTS:
		return {"ok": false, "requested_workers": requested,
			"logical_threads": logical, "auto_workers": automatic,
			"threaded_runtime": threaded, "error": "Unsupported worker request"}
	var resolved: int = 1
	var source: String = "no-thread-runtime"
	if threaded:
		if requested == 0:
			resolved = automatic
			source = "native-auto-policy"
		else:
			# Match normal native construction: explicit requests are bounded by
			# available logical processors and the native 32-worker ceiling.
			resolved = clampi(requested, 1, mini(32, logical))
			source = "explicit-request-clamped-to-host"
	return {"ok": true, "requested_workers": requested,
		"resolved_workers": resolved, "logical_threads": logical,
		"auto_workers": automatic, "threaded_runtime": threaded,
		"resolution_source": source}


static func fixture(side: int) -> PackedInt32Array:
	# Closed boundaries with interleaved falling Sand and Water blocks.
	var rectangles := PackedInt32Array([0, 0, side, 2, 1, 0, 0, 2, side, 1,
		side - 2, 0, 2, side, 1, 0, side - 2, side, 2, 1])
	for y: int in range(16, side - 32, 48):
		for x: int in range(16, side - 32, 48):
			rectangles.append_array(PackedInt32Array([
				x, y, 28, 24, 2 if (x + y) % 96 == 32 else 3]))
	return rectangles


static func sample(tree: SceneTree, requested_workers: int, side: int, ticks: int,
		progress: Callable, cancelled: Callable) -> Dictionary:
	var resolution: Dictionary = worker_resolution(requested_workers)
	if not bool(resolution.get("ok", false)) or side < 64 or side > 1024 or ticks < 1:
		return {"ok": false, "error": str(resolution.get("error", "Invalid benchmark dimensions")),
			"requested_workers": requested_workers, "side": side, "ticks": ticks}
	var global_setting_before: int = int(ProjectSettings.get_setting(
		"cybersand/native_worker_threads", 0))
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if world == null:
		return {"ok": false, "error": "Native World unavailable",
			"requested_workers": requested_workers, "side": side, "ticks": ticks}
	# diagnostic_reset reconstructs this unshared reference World with an
	# explicit resolved count. It does not edit ProjectSettings or a live game.
	if not bool(world.diagnostic_reset({"workers": int(resolution.resolved_workers)})):
		return {"ok": false, "error": "Per-World worker configuration refused",
			"requested_workers": requested_workers,
			"resolved_workers": int(resolution.resolved_workers),
			"side": side, "ticks": ticks}
	await tree.process_frame
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if bridge == null or not bool(bridge.build_world(world, fixture(side))):
		return {"ok": false,
			"error": "Could not construct reference World: " + (str(bridge.get_last_error()) if bridge != null else "bridge unavailable"),
			"requested_workers": requested_workers,
			"resolved_workers": int(resolution.resolved_workers),
			"side": side, "ticks": ticks}
	world.set_simulation_window(Vector2i.ZERO, Vector2i(side, side), 0, 0)

	var native_times: Array[float] = []
	var frame_times: Array[float] = []
	var moves: int = 0
	var parallel_phases: int = 0
	var parallel_phase_ticks: int = 0
	var scheduler_jobs: int = 0
	var maximum_scheduler_jobs: int = 0
	var eligible_blocks: int = 0
	var maximum_eligible_blocks: int = 0
	var active_blocks: int = 0
	var last_frame_usec: int = 0
	var measured_started_usec: int = -1
	var started_msec: int = Time.get_ticks_msec()
	for tick: int in range(ticks + WARMUP_TICKS):
		await tree.process_frame
		if cancelled.call() or Time.get_ticks_msec() - started_msec > SAMPLE_TIMEOUT_MS:
			return {"ok": false, "cancelled": true,
				"requested_workers": requested_workers,
				"resolved_workers": int(resolution.resolved_workers),
				"side": side, "ticks": ticks,
				"global_setting_unchanged": int(ProjectSettings.get_setting(
					"cybersand/native_worker_threads", 0)) == global_setting_before}
		var now_usec: int = Time.get_ticks_usec()
		# Deterministic replenishment maintains pressure after the initial fall.
		if tick % 12 == 0:
			for x: int in range(32, side - 32, 64):
				world.emit_disc(x, 12, 8, 2 if x % 128 == 32 else 3, 0)
		if not bool(world.simulation_tick()):
			return {"ok": false, "error": str(world.get_last_tick_error()),
				"requested_workers": requested_workers,
				"resolved_workers": int(resolution.resolved_workers),
				"side": side, "ticks": ticks}
		if tick >= WARMUP_TICKS:
			if measured_started_usec < 0:
				measured_started_usec = now_usec
			native_times.append(float(world.get_simulation_time_ms()))
			frame_times.append(float(now_usec - last_frame_usec) / 1000.0)
			moves += int(world.get_moves_last_tick())
			var phases: int = int(world.get_scheduler_parallel_phases_last_tick())
			var jobs: int = int(world.get_scheduler_jobs_last_tick())
			var eligible: int = int(world.get_eligible_blocks_last_tick())
			parallel_phases += phases
			parallel_phase_ticks += int(phases > 0)
			scheduler_jobs += jobs
			maximum_scheduler_jobs = maxi(maximum_scheduler_jobs, jobs)
			eligible_blocks += eligible
			maximum_eligible_blocks = maxi(maximum_eligible_blocks, eligible)
			active_blocks += int(world.get_active_blocks_last_tick())
		last_frame_usec = now_usec
		if tick % 15 == 0:
			var label: String = "Auto" if requested_workers == 0 else str(requested_workers)
			progress.call("%s→%d requested/resolved · %d actual · %d×%d · %d/%d ticks" % [
				label, int(resolution.resolved_workers), int(world.get_worker_threads()),
				side, side, maxi(0, tick - WARMUP_TICKS + 1), ticks])

	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bridge.export_level(world))
	var actual_workers: int = int(world.get_worker_threads())
	var measured_wall_ms: float = maxf(0.001,
		float(Time.get_ticks_usec() - measured_started_usec) / 1000.0)
	var global_setting_after: int = int(ProjectSettings.get_setting(
		"cybersand/native_worker_threads", 0))
	var result: Dictionary = {
		"ok": true,
		"requested_workers": requested_workers,
		"resolved_workers": int(resolution.resolved_workers),
		"actual_workers": actual_workers,
		# Compatibility alias for the existing benchmark presentation.
		"workers": actual_workers,
		"logical_threads": int(resolution.logical_threads),
		"auto_workers": int(resolution.auto_workers),
		"threaded_runtime": bool(resolution.threaded_runtime),
		"resolution_source": str(resolution.resolution_source),
		"construction": "fresh-reference-world+diagnostic-explicit-count+ordinary-demo-rebuild",
		"readback_consistent": actual_workers == int(resolution.resolved_workers),
		"global_setting_before": global_setting_before,
		"global_setting_after": global_setting_after,
		"global_setting_unchanged": global_setting_after == global_setting_before,
		"side": side,
		"ticks": ticks,
		"warmup_ticks": WARMUP_TICKS,
		"native_ms": statistics(native_times),
		"frame_interval_ms": statistics(frame_times),
		"measured_wall_ms": measured_wall_ms,
		"completed_hz": float(ticks) * 1000.0 / measured_wall_ms,
		"moves": moves,
		"parallel_phases": parallel_phases,
		"parallel_phase_ticks": parallel_phase_ticks,
		"scheduler_jobs": scheduler_jobs,
		"maximum_scheduler_jobs": maximum_scheduler_jobs,
		"eligible_blocks": eligible_blocks,
		"maximum_eligible_blocks": maximum_eligible_blocks,
		"active_blocks": active_blocks,
		"parallel_participation": parallel_phase_ticks > 0 and maximum_scheduler_jobs > 1,
		"backend": str(world.get_backend_name()),
		"level_hash": hash.finish().hex_encode()
	}
	# Drop the only references before the next row. The native persistent pool
	# belongs to this World and is destroyed between requested-count samples.
	world = null
	bridge = null
	await tree.process_frame
	return result


static func run(tree: SceneTree, stress: bool, host_workers: int,
		progress: Callable, cancelled: Callable, reference_ticks: int = 120) -> Dictionary:
	var counts: Array[int] = [0] if stress else SUPPORTED_REQUESTS.duplicate()
	var sizes: Array[int] = [960] if stress else [480, 960]
	var rows: Array = []
	var global_setting_before: int = int(ProjectSettings.get_setting(
		"cybersand/native_worker_threads", 0))
	for requested: int in counts:
		for side: int in sizes:
			var row: Dictionary = await sample(tree, requested, side,
				600 if stress else reference_ticks, progress, cancelled)
			await tree.process_frame
			if not bool(row.get("ok", false)):
				return {"ok": false, "cancelled": row.get("cancelled", false),
					"error": row.get("error", "Cancelled or time limit reached"),
					"rows": rows, "failed_row": row,
					"global_setting_before": global_setting_before,
					"global_setting_after": int(ProjectSettings.get_setting(
						"cybersand/native_worker_threads", 0))}
			rows.append(row)

	var parity: bool = true
	var hashes: Dictionary = {}
	var actual_counts: Dictionary = {}
	var parallel_rows: int = 0
	var readback_consistent: bool = true
	var settings_unchanged: bool = true
	for row: Dictionary in rows:
		if hashes.has(row.side) and hashes[row.side] != row.level_hash:
			parity = false
		hashes[row.side] = row.level_hash
		actual_counts[int(row.actual_workers)] = true
		parallel_rows += int(bool(row.parallel_participation))
		readback_consistent = readback_consistent and bool(row.readback_consistent)
		settings_unchanged = settings_unchanged and bool(row.global_setting_unchanged)
	var global_setting_after: int = int(ProjectSettings.get_setting(
		"cybersand/native_worker_threads", 0))
	settings_unchanged = settings_unchanged and global_setting_after == global_setting_before
	var resolution: Dictionary = worker_resolution(0)
	return {
		"ok": parity and readback_consistent and settings_unchanged,
		"parity": parity if actual_counts.size() > 1 else null,
		"readback_consistent": readback_consistent,
		"global_setting_unchanged": settings_unchanged,
		"global_setting_before": global_setting_before,
		"global_setting_after": global_setting_after,
		"mode": "stress" if stress else "benchmark",
		"logical_threads": int(resolution.get("logical_threads", 1)),
		"auto_workers": int(resolution.get("auto_workers", 1)),
		"threaded_runtime": bool(resolution.get("threaded_runtime", false)),
		"host_workers": host_workers,
		"requested_counts": counts,
		"distinct_actual_counts": actual_counts.keys(),
		"parallel_participation_rows": parallel_rows,
		"runtime": "web" if OS.has_feature("web") else "native",
		"date": Time.get_datetime_string_from_system(true),
		"rows": rows,
		"note": "Separate fresh reference Worlds; no global worker-setting mutation. Frame intervals include test scheduling, not gameplay FPS. First 10 ticks excluded. Stress uses 600 measured ticks; benchmark uses 120 by default. Auto is resolved from the production native policy, then applied per World. Timings are observations, not a speedup claim."
	}
