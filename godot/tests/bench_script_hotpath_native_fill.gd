extends SceneTree

# SCRIPT-HOTPATH-001: source-matched, same-process Godot A/B. This measures
# planning only, not native sample capture, application, GPU or presentation.
# Run: godot --headless --path godot -s res://tests/bench_script_hotpath_native_fill.gd
const Shapes = preload("res://scripts/workbench_paint_editor_shapes.gd")
const WARMUP := 1
const REPEATS := 6

var backend: Object

func _initialize() -> void:
	run.call_deferred()

func make_grid(width: int, height: int, value: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(width * height)
	result.fill(value)
	return result

func stats(times: Array[int]) -> Dictionary:
	times.sort()
	var total := 0
	for value: int in times:
		total += value
	return {"median_usec": times[times.size() / 2],
		"p95_usec": times[ceili(float(times.size()) * 0.95) - 1],
		"mean_usec": float(total) / times.size(), "samples_usec": times}

func bench(label: String, seed: Vector2i, origin: Vector2i, size: Vector2i,
		materials: PackedInt32Array, extent: Vector2i, limit: int) -> bool:
	var argument := [seed, origin, size, materials, extent, limit]
	var reference: Dictionary = Shapes.fill_connected_reference.callv(argument)
	var compiled: Dictionary = backend.callv(&"fill_connected", argument)
	if reference != compiled:
		push_error(label + ": native differs from script reference")
		return false
	var results := {}
	for mode: String in ["script", "native", "dispatched"]:
		var samples: Array[int] = []
		for attempt: int in range(WARMUP + REPEATS):
			var started: int = Time.get_ticks_usec()
			var response: Dictionary
			match mode:
				"script": response = Shapes.fill_connected_reference.callv(argument)
				"native": response = backend.callv(&"fill_connected", argument)
				_: response = Shapes.fill_connected.callv(argument)
			var elapsed: int = Time.get_ticks_usec() - started
			if response != reference:
				push_error(label + ": " + mode + " changed output")
				return false
			if attempt >= WARMUP:
				samples.append(elapsed)
		results[mode] = stats(samples)
	var gain := float(results.script.median_usec) / float(maxi(1, results.native.median_usec))
	print("SCRIPT_HOTPATH_BENCH ", JSON.stringify({
		"case":label,"width":size.x,"height":size.y,"limit":limit,
		"cells_planned":int(reference.get("count", 0)), "result_accepted":reference.get("accepted", false),
		"native_speedup_x":gain,"measurements":results
	}))
	return true

func run() -> void:
	if not ClassDB.class_exists(&"CyberNativePaintPlanner"):
		push_error("Build the source-matched GDExtension to benchmark compiled planner.")
		quit(2)
		return
	backend = ClassDB.instantiate(&"CyberNativePaintPlanner")
	if backend == null or not backend.has_method(&"fill_connected") or \
			not backend.has_method(&"interface_version") or int(backend.interface_version()) != 1:
		push_error("Native planner interface version mismatch.")
		quit(2)
		return
	var extent := Vector2i(512, 512)
	var full := make_grid(512, 512, 2)
	var ok := bench("full-512-square", Vector2i(256, 256), Vector2i.ZERO,
		extent, full, extent, 262144)
	var pockets := make_grid(512, 512, 1)
	for y: int in range(8, 504):
		for x: int in range(8, 504):
			if x % 31 > 0 and y % 31 > 0:
				pockets[y * 512 + x] = 2
	ok = bench("fragmented", Vector2i(257, 257), Vector2i.ZERO,
		extent, pockets, extent, 262144) and ok
	var bounded := make_grid(512, 512, 1)
	for y: int in range(128, 384):
		for x: int in range(128, 384):
			bounded[y * 512 + x] = 2
	ok = bench("bounded-65536", Vector2i(200, 200), Vector2i.ZERO,
		extent, bounded, extent, 65536) and ok
	print("SCRIPT_HOTPATH_BENCH_RESULT ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
