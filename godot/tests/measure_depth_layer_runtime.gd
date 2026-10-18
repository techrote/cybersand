extends SceneTree

const Runtime = preload("res://scripts/depth/depth_layer_runtime.gd")
const Fixture = preload("res://scripts/depth/depth_lab_fixture.gd")
const WARMUP: int = 30
const SAMPLES: int = 120
const DELTA: float = 1.0 / 60.0

var _output: String = "user://depth-runtime-cost.json"

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--depth-cost-output="):
			_output = argument.trim_prefix("--depth-cost-output=")
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		push_error("Native extension required")
		quit(2)
		return
	var cases: Array[Dictionary] = [
		{"id": "default_60_20_30", "rates": {"play":60.0,"scripted":20.0,"effects":30.0,"background":0.0}},
		{"id": "reduced_60_10_15", "rates": {"play":60.0,"scripted":10.0,"effects":15.0,"background":0.0}},
	]
	var output: Dictionary = {
		"schema": "cybersand.depth-runtime-cost.v1",
		"fixture": Fixture.TITLE,
		"engine": Engine.get_version_info(),
		"platform": OS.get_name(),
		"processor": OS.get_processor_name(),
		"world_size": Runtime.WORLD_SIZE,
		"native_backing_per_plane": Runtime.STORAGE_SIZE,
		"scope": "Host elapsed owner/update and copied-publication timing only; excludes texture upload, shaders and window presentation.",
		"cases": [],
	}
	for definition: Dictionary in cases:
		output["cases"].append(_measure_case(definition))
	var path: String = ProjectSettings.globalize_path(_output)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open cost output " + path)
		quit(1)
		return
	file.store_string(JSON.stringify(output, "\t") + "\n")
	file.close()
	print("DEPTH_RUNTIME_COST: ", path)
	quit(0)

func _measure_case(definition: Dictionary) -> Dictionary:
	var runtime: CyberDepthLayerRuntime = Runtime.new()
	var reset_start: int = Time.get_ticks_usec()
	if not runtime.reset(Fixture.build()):
		return {"id": definition["id"], "error": runtime.last_error}
	var reset_ms: float = float(Time.get_ticks_usec() - reset_start) / 1000.0
	runtime.configure_rates(definition["rates"])
	runtime.set_weather("rain")
	var publication_start: int = Time.get_ticks_usec()
	for id: String in Runtime.IDS:
		runtime.snapshot_layer(id, true)
	var publication_ms: float = float(Time.get_ticks_usec() - publication_start) / 1000.0
	for _i: int in range(WARMUP):
		runtime.advance(DELTA, false)
	var advance_samples: Array[float] = []
	var publication_samples: Array[float] = []
	for _i: int in range(SAMPLES):
		var start: int = Time.get_ticks_usec()
		runtime.advance(DELTA, false)
		advance_samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
		start = Time.get_ticks_usec()
		for id: String in Runtime.IDS:
			runtime.snapshot_layer(id, false)
		publication_samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
	return {
		"id": definition["id"],
		"rates": definition["rates"],
		"reset_construction_ms": reset_ms,
		"initial_publication_ms": publication_ms,
		"initial_rg8_bytes": Runtime.STORAGE_SIZE.x * Runtime.STORAGE_SIZE.y * 2 * Runtime.IDS.size(),
		"owner_advance": _summary(advance_samples),
		"copied_snapshot_publication": _summary(publication_samples),
		"runtime": runtime.stats(),
	}

func _summary(samples: Array[float]) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in samples:
		total += value
	return {
		"count": samples.size(),
		"mean_ms": total / maxf(float(samples.size()), 1.0),
		"p50_ms": sorted[clampi(int(sorted.size() * 0.50), 0, sorted.size() - 1)],
		"p95_ms": sorted[clampi(int(sorted.size() * 0.95), 0, sorted.size() - 1)],
		"max_ms": sorted[-1],
		"total_ms": total,
	}
