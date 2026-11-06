extends SceneTree

# Native adapter-only deterministic packet benchmark. It measures collider
# enumeration, full-packet byte oracle and native render exchange separately.
# It does NOT measure the desktop physics callback or GDScript worker copy/ACK.
# Run before/after source-matched runtime builds on the same machine,
# fixture seed and iteration count. Record each runtime's distinct identity.
var _timings: Dictionary = {
	"collider_us": [], "oracle_us": [], "render_exchange_us": []
}


func _init() -> void:
	call_deferred("_run")


func _percentiles(values: Array) -> Dictionary:
	var sorted: Array = values.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return {}
	var count: int = sorted.size()
	var total: float = 0.0
	for value: int in sorted:
		total += float(value)
	return {
		"mean_us": total / float(count),
		"p50_us": int(sorted[int((count - 1) * 0.50)]),
		"p95_us": int(sorted[int((count - 1) * 0.95)]),
		"max_us": int(sorted.back())
	}


func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		push_error("BENCH_HARD_SURFACE: native extension is unavailable")
		quit(1)
		return
	var iterations: int = 120
	var seed: int = 406
	var runtime_path := ""
	var expected_sha := ""
	var source_revision := ""
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ticks="):
			iterations = int(arg.trim_prefix("--ticks="))
		elif arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--runtime-path="):
			runtime_path = arg.trim_prefix("--runtime-path=")
		elif arg.begins_with("--runtime-sha256="):
			expected_sha = arg.trim_prefix("--runtime-sha256=")
		elif arg.begins_with("--source-head="):
			source_revision = arg.trim_prefix("--source-head=")
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if iterations < 10 or iterations > 2000 or runtime_path.is_empty() or expected_sha.length() != 64 or source_revision.is_empty():
		push_error("BENCH_HARD_SURFACE: require --ticks=10..2000 --source-head=<SHA> --runtime-path=<path> --runtime-sha256=<SHA>")
		quit(1)
		return
	var actual_sha: String = FileAccess.get_sha256(runtime_path)
	if actual_sha != expected_sha:
		push_error("BENCH_HARD_SURFACE: installed native runtime SHA-256 does not match")
		quit(1)
		return
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	world.simulation_window_enabled = false
	if not bool(world.reset_demo_world()):
		push_error("BENCH_HARD_SURFACE: native fixture reset failed")
		quit(1)
		return
	var random := RandomNumberGenerator.new()
	random.seed = seed
	# Same concentrated reactive controls as the exact-packet test, plus
	# sparse painting across the finite 1024 square.
	world.emit_disc(128, 256, 20, CyberCellWorld.WOOD)
	world.emit_disc(128, 256, 4, CyberCellWorld.FIRE)
	world.emit_disc(320, 192, 14, CyberCellWorld.GLASS)
	world.emit_disc(320, 170, 8, CyberCellWorld.LAVA)
	world.emit_disc(512, 384, 12, CyberCellWorld.METAL)
	world.emit_disc(512, 364, 8, CyberCellWorld.ACID)
	var paint: Array[int] = [CyberCellWorld.WALL, CyberCellWorld.GLASS, CyberCellWorld.EMPTY, CyberCellWorld.WOOD, CyberCellWorld.SAND, CyberCellWorld.WATER]
	var pair_failures := 0
	for tick: int in range(iterations):
		if tick % 3 == 0:
			world.emit_disc(random.randi_range(8, 1015), random.randi_range(8, 1015),
				random.randi_range(2, 16), paint[random.randi_range(0, paint.size() - 1)])
		if not bool(world.simulation_tick()):
			push_error("BENCH_HARD_SURFACE: native tick failed at tick %d" % tick)
			quit(1)
			return
		var stamp: int = Time.get_ticks_usec()
		var packed: PackedInt32Array = world.get_hard_surface_chunk_rectangles()
		_timings.collider_us.append(Time.get_ticks_usec() - stamp)
		stamp = Time.get_ticks_usec()
		var full: PackedInt32Array = world.diagnostic_full_hard_surface_chunk_rectangles()
		_timings.oracle_us.append(Time.get_ticks_usec() - stamp)
		if packed != full:
			pair_failures += 1
			push_error("BENCH_HARD_SURFACE: actual packet bytes diverged at tick %d" % tick)
			quit(1)
			return
		stamp = Time.get_ticks_usec()
		var render_packet: Dictionary = world.take_render_snapshot(false)
		_timings.render_exchange_us.append(Time.get_ticks_usec() - stamp)
		if bool(render_packet.get("failed", false)):
			push_error("BENCH_HARD_SURFACE: native render exchange returned failed")
			quit(1)
			return
	var stats: Dictionary = world.diagnostic_hard_surface_packet_stats()
	var receipt: Dictionary = {
		"source_head": source_revision,
		"native_runtime_sha256": actual_sha,
		"engine": Engine.get_version_info(),
		"kind": "native-adapter-only, NOT worker publication",
		"fixture": "default-demo-reactive-1024x1024",
		"seed": seed, "ticks": iterations,
		"worker_threads": int(world.get_worker_threads()),
		"packet_byte_mismatches": pair_failures,
		"hard_surface": stats,
		"collider": _percentiles(_timings.collider_us),
		"full_packet_oracle": _percentiles(_timings.oracle_us),
		"render_exchange": _percentiles(_timings.render_exchange_us)
	}
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			push_error("BENCH_HARD_SURFACE: cannot write receipt")
			quit(1)
			return
		file.store_string(JSON.stringify(receipt, "  "))
		file.close()
	print("BENCH_HARD_SURFACE ", JSON.stringify(receipt))
	quit(0)
