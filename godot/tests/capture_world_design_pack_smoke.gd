extends SceneTree
# Explicit graphical E2E test. Not named test_* because headless CI must not
# accidentally record a skipped draw as success.
# godot --path godot --script res://tests/capture_world_design_pack_smoke.gd
# Requires an actual display-backed renderer; returns 77 on headless.
var failures: int = 0
var assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("WORLD_PACK_GRAPHICAL: " + message)


func _invoke(pack: String, out_dir: String, time: String) -> int:
	var command: PackedStringArray = PackedStringArray([
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/capture_world_design_pack.gd", "--",
		"--pack=" + pack, "--output=" + out_dir, "--mode=both",
		"--scale=2", "--time=" + time, "--glow=on",
		"--design-revision=synthetic-fixture"
	])
	var output: Array = []
	var exit: int = OS.execute(OS.get_executable_path(), command, output, true)
	print("WORLD_PACK_GRAPHICAL child_exit=", exit, " command=", str(command))
	for line: Variant in output:
		print(str(line).substr(0, 2000))
	return exit


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WORLD_PACK_GRAPHICAL: NOT RUN: real graphical renderer required")
		quit(77)
		return
	var root_dir: String = ProjectSettings.globalize_path("user://world-pack-capture-smoke")
	if DirAccess.make_dir_recursive_absolute(root_dir) != OK:
		quit(2)
		return
	var fixture: Dictionary = {
		"schema_id": "cybersand.world-feature-pack.proposal",
		"features": [
			{"id": "brick", "size": [48, 24],
				"rectangles": [[0, 0, 48, 24, 43]], "variants": []},
			{"id": "neon", "size": [16, 16],
				"rectangles": [[0, 0, 16, 16, 77]], "variants": []}
		],
		"scene": {"size": [80, 40], "rectangles": [],
			"placements": [
				{"feature": "brick", "x": 2, "y": 2, "variant": null},
				{"feature": "neon", "x": 58, "y": 10, "variant": "base"}
			]}
	}
	var pack_path: String = root_dir.path_join("synthetic-pack.json")
	var file: FileAccess = FileAccess.open(pack_path, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(fixture) + "\n")
	file.close()
	var run_a: String = root_dir.path_join("run-a")
	var run_b: String = root_dir.path_join("run-b")
	var first_exit: int = _invoke(pack_path, run_a, "1.37")
	var second_exit: int = _invoke(pack_path, run_b, "1.37")
	_check(first_exit == 0 and second_exit == 0, "both real Godot child processes must exit 0")
	var first_path: String = run_a.path_join("combined.png")
	var second_path: String = run_b.path_join("combined.png")
	_check(FileAccess.file_exists(first_path) and FileAccess.file_exists(second_path),
		"combined framebuffer PNGs exist")
	if FileAccess.file_exists(first_path) and FileAccess.file_exists(second_path):
		var first: Image = Image.load_from_file(first_path)
		var second: Image = Image.load_from_file(second_path)
		_check(first != null and second != null and first.get_size() == Vector2i(160, 80),
			"true 2x pixel output, no approximation or cropping")
		_check(FileAccess.get_sha256(first_path) == FileAccess.get_sha256(second_path),
			"fixed time produces identical PNG bytes")
		var colours: Dictionary = {}
		# Inspect masonry within the brick region, away from antialiased edges
		# or the neon/glow source. Actual shader patterning must be observable.
		for y: int in range(8, 40):
			for x: int in range(8, 70):
				colours[first.get_pixel(x, y).to_html(false)] = true
		_check(colours.size() >= 6,
			"material 43 has genuine production shader pixel variation (>5 colours)")
	var manifest_path: String = run_a.path_join("capture-manifest.json")
	_check(FileAccess.file_exists(manifest_path), "complete machine-readable manifest exists")
	if FileAccess.file_exists(manifest_path):
		var parser: JSON = JSON.new()
		_check(parser.parse(FileAccess.get_file_as_string(manifest_path)) == OK,
			"capture manifest is valid JSON")
		var record: Variant = parser.data
		if typeof(record) == TYPE_DICTIONARY:
			_check(record.get("status") == "complete" and bool(record.get("success", false)),
				"manifest reports successful rendering only after all outputs")
			_check(record.get("captures", []).size() == 5,
				"combined, 2 independent features and 2 detail crops are present")
			_check(record.get("inputs", []).size() == 3,
				"RG8 input bytes/hashes stored for combined and both features")
	var invalid_pack: String = root_dir.path_join("invalid.json")
	file = FileAccess.open(invalid_pack, FileAccess.WRITE)
	file.store_string('{"scene":{"size":[16,16],"placements":[]},"features":[{"id":"bad","size":[4,4],"rectangles":[[0,0,9,4,1]]}]}')
	file.close()
	var rejected_path: String = root_dir.path_join("reject")
	var invalid_exit: int = _invoke(invalid_pack, rejected_path, "1.37")
	_check(invalid_exit != 0, "bad rectangle must fail as a process")
	_check(not FileAccess.file_exists(rejected_path.path_join("capture-manifest.json")),
		"failed capture never writes a successful-looking manifest")
	print("WORLD_PACK_GRAPHICAL assertions=%d failures=%d adapter=%s" % [
		assertions, failures, RenderingServer.get_video_adapter_name()])
	quit(1 if failures > 0 else 0)
