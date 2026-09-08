class_name CyberWorkerBenchmark
extends RefCounted

# Reference workload, never the player's world. One native tick per frame;
# frame intervals include test/UI scheduling, not normal gameplay rendering.
static func statistics(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "p95": 0.0, "max": 0.0}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {"mean": total / values.size(), "p95": ordered[ceili(values.size() * 0.95) - 1], "max": ordered[-1]}

static func fixture(side: int) -> PackedInt32Array:
	# Closed boundaries with interleaved falling Sand and Water blocks.
	var rectangles := PackedInt32Array([0, 0, side, 2, 1, 0, 0, 2, side, 1, side - 2, 0, 2, side, 1, 0, side - 2, side, 2, 1])
	for y: int in range(16, side - 32, 48):
		for x: int in range(16, side - 32, 48):
			rectangles.append_array(PackedInt32Array([x, y, 28, 24, 2 if (x + y) % 96 == 32 else 3]))
	return rectangles

static func sample(tree: SceneTree, workers: int, side: int, ticks: int, progress: Callable, cancelled: Callable) -> Dictionary:
	var previous: int = int(ProjectSettings.get_setting("cybersand/native_worker_threads", 0))
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_worker_threads", previous)
	await tree.process_frame
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if not bridge.build_world(world, fixture(side)):
		return {"ok": false, "error": "Could not construct reference world"}
	world.set_simulation_window(Vector2i.ZERO, Vector2i(side, side), 0, 0)
	var native_times: Array[float] = []
	var frame_times: Array[float] = []
	var moves: int = 0
	var phases: int = 0
	var last_frame: int = 0
	var started: int = Time.get_ticks_msec()
	for tick: int in range(ticks + 10):
		await tree.process_frame
		if cancelled.call() or Time.get_ticks_msec() - started > 120000:
			return {"ok": false, "cancelled": true}
		var now: int = Time.get_ticks_usec()
		# Deterministic replenishment maintains pressure after the initial fall.
		if tick % 12 == 0:
			for x: int in range(32, side - 32, 64):
				world.emit_disc(x, 12, 8, 2 if x % 128 == 32 else 3, 0)
		if not world.simulation_tick():
			return {"ok": false, "error": str(world.get_last_tick_error())}
		if tick >= 10:
			native_times.append(float(world.get_simulation_time_ms()))
			frame_times.append((now - last_frame) / 1000.0)
			moves += int(world.get_moves_last_tick())
			phases += int(world.get_scheduler_parallel_phases_last_tick())
		last_frame = now
		if tick % 15 == 0:
			progress.call("%d workers · %d×%d · %d/%d ticks" % [int(world.get_worker_threads()), side, side, maxi(0, tick - 9), ticks])
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bridge.export_level(world))
	return {"ok": true, "requested_workers": workers, "workers": int(world.get_worker_threads()), "side": side, "ticks": ticks, "native_ms": statistics(native_times), "frame_interval_ms": statistics(frame_times), "moves": moves, "parallel_phases": phases, "level_hash": hash.finish().hex_encode()}

static func run(tree: SceneTree, stress: bool, _workers: int, progress: Callable, cancelled: Callable, reference_ticks: int = 120) -> Dictionary:
	var logical: int = CyberWebCapabilities.reported_logical_threads()
	var threaded: bool = not OS.has_feature("web") or OS.has_feature("threads")
	var counts: Array[int] = []
	counts.assign([0] if stress else [1, 2, 4, 6])
	var sizes: Array[int] = []
	sizes.assign([960] if stress else [480, 960])
	var rows: Array = []
	var seen: Array[int] = []
	for requested: int in counts:
		var actual: int = (0 if stress else clampi(requested, 1, logical)) if threaded else 1
		if actual in seen:
			continue
		seen.append(actual)
		for side: int in sizes:
			var row: Dictionary = await sample(tree, actual, side, 600 if stress else reference_ticks, progress, cancelled)
			await tree.process_frame
			if not row.ok:
				return {"ok": false, "cancelled": row.get("cancelled", false), "error": row.get("error", "Cancelled or time limit reached"), "rows": rows}
			rows.append(row)
	var parity: bool = true
	var hashes: Dictionary = {}
	for row: Dictionary in rows:
		if hashes.has(row.side) and hashes[row.side] != row.level_hash:
			parity = false
		hashes[row.side] = row.level_hash
	return {"ok": parity, "parity": parity if seen.size() > 1 else null, "mode": "stress" if stress else "benchmark", "logical_threads": logical, "auto_workers": int(ClassDB.class_call_static(&"CyberNativeCellWorld", &"auto_worker_threads", logical)), "runtime": "web" if OS.has_feature("web") else "native", "date": Time.get_datetime_string_from_system(true), "rows": rows, "note": "Separate reference worlds; frame intervals include test scheduling, not gameplay FPS. First 10 ticks excluded. Stress uses 600 measured ticks; benchmark uses 120. No automatic retuning. Null parity means only one worker count was tested."}
