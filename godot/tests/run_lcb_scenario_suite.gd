extends SceneTree

# LCB scenario suite runner: controlled, fixed-tick, native-only execution of a
# list of frozen MicroScenario definitions. Writes one JSON result per case
# plus a summary. Exit 0 only when every case completed; refused, faulted and
# failed-condition cases are retained and reported, never relabelled complete.
const Runner = preload("res://tests/lcb_scenario_runner.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = {"list":"", "workers":"1", "output-dir":"", "source-sha":"unavailable"}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if not argument.begins_with("--") or pair.size() != 2 or not options.has(pair[0]):
			_finish("Use --list=FILE --workers=N --output-dir=DIR [--source-sha=SHA]")
			return
		options[pair[0]] = pair[1]
	var workers: int = int(options.workers) if str(options.workers).is_valid_int() else 0
	if workers < 1 or workers > 32 or str(options["output-dir"]).is_empty():
		_finish("Invalid worker count or output directory")
		return
	var list := FileAccess.open(options.list, FileAccess.READ)
	if list == null:
		_finish("Definition list unavailable")
		return
	var summary: Array = []
	var all_completed: bool = true
	for line: String in list.get_as_text().split("\n"):
		var path: String = line.strip_edges()
		if path.is_empty(): continue
		var source: Dictionary = Runner.read_text(path)
		var result: Dictionary = Runner.run_text(source.text, workers, -1, str(options["source-sha"])) \
			if source.ok else {"status":"refused", "error":source.error}
		result["path"] = path
		all_completed = all_completed and result.status == "completed"
		var name: String = str(result.get("id", path.get_file().get_basename())) + "-w%d.json" % workers
		if not _write(str(options["output-dir"]).path_join(name), result): return
		summary.append({"id":result.get("id", ""), "path":path, "status":result.status,
			"outcome":result.get("capture", {}).get("outcome", ""), "error":result.get("error", "")})
		print("LCB_SCENARIO ", result.status, " ", result.get("id", path), " ", result.get("error", ""))
	if not _write(str(options["output-dir"]).path_join("summary-w%d.json" % workers),
		{"workers":workers, "cases":summary, "all_completed":all_completed}): return
	quit(0 if all_completed else 1)

func _write(path: String, value: Variant) -> bool:
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		_finish("Cannot write " + path)
		return false
	output.store_string(JSON.stringify(value, "  ") + "\n")
	output.close()
	return true

func _finish(message: String) -> void:
	printerr("LCB_SUITE_ERROR: ", message)
	quit(2)
