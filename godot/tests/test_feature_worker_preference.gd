extends SceneTree

# Exercise the real Engine Lab writer, on-disk JSON, actual launcher _ready,
# and the request consumed when the next SimulationWorker is constructed.
const Launcher = preload("res://feature_launcher.tscn")
const EngineLab = preload("res://scripts/workbench_engine_lab.gd")
const SimulationWorker = preload("res://scripts/simulation_worker.gd")
const SETTING: String = "cybersand/native_worker_threads"
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures.append(message)
		push_error("WORKER_PREFERENCE: " + message)

func _launch_and_observe(expected: int, label: String) -> void:
	# A fresh launcher reads the saved profile before constructing its worker.
	ProjectSettings.set_setting(SETTING, 2)
	var launcher: Control = Launcher.instantiate()
	root.add_child(launcher)
	await process_frame
	check(int(ProjectSettings.get_setting(SETTING)) == expected, label + " reaches launcher setting")
	var worker = SimulationWorker.new()
	check(worker._native_worker_request == expected, label + " reaches newly constructed worker")
	worker = null
	launcher.queue_free()
	await process_frame

func _run() -> void:
	var previous: Variant = ProjectSettings.get_setting(SETTING, null)
	var existed: bool = FileAccess.file_exists(EngineLab.WORKER_PATH)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(EngineLab.WORKER_PATH) if existed else PackedByteArray()
	set_meta("cybersand_launch_args_consumed", true)
	var lab = EngineLab.new()
	var workers := SpinBox.new()
	workers.min_value = 0
	workers.max_value = 32
	workers.step = 1
	lab.add_child(workers)
	lab._widgets["workers"] = workers
	var status := Label.new()
	lab.add_child(status)
	lab._status = status
	for requested: int in [0, 1, 4, 32]:
		workers.value = requested
		lab._save_workers()
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(EngineLab.WORKER_PATH))
		check(saved is Dictionary and saved.get("native_threads") is float,
			"Engine Lab numeric JSON round-trip uses Godot's floating-point representation")
		await _launch_and_observe(requested, "saved " + str(requested))
	for invalid: Variant in [-1, 33, 1.5, "4", true, null]:
		var file := FileAccess.open(EngineLab.WORKER_PATH, FileAccess.WRITE)
		check(file != null, "invalid preference fixture opens")
		if file != null:
			file.store_string(JSON.stringify({"native_threads": invalid}))
			file.close()
		await _launch_and_observe(2, "invalid " + str(invalid) + " retains default")
	lab.free()
	if existed:
		var restore := FileAccess.open(EngineLab.WORKER_PATH, FileAccess.WRITE)
		check(restore != null, "original worker preference can be restored")
		if restore != null:
			restore.store_buffer(original)
			restore.close()
	else:
		check(DirAccess.remove_absolute(ProjectSettings.globalize_path(EngineLab.WORKER_PATH)) == OK,
			"isolated worker preference is removed")
	ProjectSettings.set_setting(SETTING, previous)
	print("WORKER_PREFERENCE_RESULT ", JSON.stringify({"source": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"assertions": assertions, "failures": failures,
		"scope": "Real Engine Lab save, profile JSON, launcher ready and new worker request; no native tick"}))
	quit(0 if failures.is_empty() else 1)
