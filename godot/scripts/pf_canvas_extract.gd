extends SceneTree

const Setup = preload("res://scripts/workbench_setup.gd")
const LABELS: Array[String] = [Setup.DEFAULT_LABEL, Setup.BENCH_LABEL, Setup.STRESS_LABEL]

func _initialize() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if output.is_empty():
		push_error("PF_CANVAS_EXTRACT: --output=PATH required")
		quit(2)
		return
	var error := DirAccess.make_dir_recursive_absolute(output)
	if error != OK:
		push_error("PF_CANVAS_EXTRACT: cannot create output: %s" % error_string(error))
		quit(2)
		return
	for label: String in LABELS:
		var recipe: Dictionary = Setup.builtin(label, PackedInt32Array())
		var result: Dictionary = Setup.rectangles(recipe)
		if recipe.is_empty() or result.has("error"):
			push_error("PF_CANVAS_EXTRACT: %s refused: %s" % [label, str(result)])
			quit(1)
			return
		var extent := Setup.extent_of(recipe)
		var runs: Array = result.get("runs", [])
		var file := FileAccess.open(output.path_join(label + ".rects"), FileAccess.WRITE)
		if file == null:
			push_error("PF_CANVAS_EXTRACT: cannot open %s" % label)
			quit(2)
			return
		file.store_line("%d %d %d" % [extent.x, extent.y, runs.size() / 5])
		for i: int in range(0, runs.size(), 5):
			file.store_line("%d %d %d %d %d" % [
				int(runs[i]), int(runs[i + 1]), int(runs[i + 2]), int(runs[i + 3]), int(runs[i + 4])
			])
		file.close()
		print("PF_CANVAS_EXTRACT %s extent=%dx%d rectangles=%d" % [
			label, extent.x, extent.y, runs.size() / 5
		])
	quit(0)
