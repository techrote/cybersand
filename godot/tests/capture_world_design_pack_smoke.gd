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


func _invoke(pack: String, out_dir: String, time: String, bad_scale: bool = false) -> int:
	var command: PackedStringArray = PackedStringArray([
		"--rendering-method", RenderingServer.get_current_rendering_method(),
		"--rendering-driver", RenderingServer.get_current_rendering_driver_name(),
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/capture_world_design_pack.gd", "--",
		"--pack=" + pack, "--output=" + out_dir, "--mode=both",
		"--scale=999" if bad_scale else "--scale=2",
		"--time=" + time, "--glow=on", "--design-revision=synthetic-fixture"
	])
	var output: Array = []
	var exit: int = OS.execute(OS.get_executable_path(), command, output, true)
	print("WORLD_PACK_GRAPHICAL child_exit=", exit, " command=", str(command))
	for line: Variant in output:
		print(str(line).substr(0, 2000))
	return exit



func _check_manifest(out_dir: String, pack_hash: String) -> void:
	var path: String = out_dir.path_join("capture-manifest.json")
	_check(FileAccess.file_exists(path), "complete manifest exists: " + out_dir)
	if not FileAccess.file_exists(path):
		return
	var parser: JSON = JSON.new()
	_check(parser.parse(FileAccess.get_file_as_string(path)) == OK, "valid manifest JSON")
	if typeof(parser.data) != TYPE_DICTIONARY:
		_check(false, "manifest must be an object")
		return
	var record: Dictionary = parser.data
	_check(record.get("status") == "complete" and record.get("success") == true,
		"complete manifest contains actual success")
	_check(record.get("pack_sha256") == pack_hash, "exact source pack content hash")
	_check(record.get("captures", []).size() == 5 and record.get("inputs", []).size() == 3,
		"combined, two features, two details, three original RG8 inputs")
	var palette: Dictionary = record.get("palette_selection", {})
	_check(palette.get("source_bound", false) and palette.get("source_file_bound", false),
		"real production palette selector supplies source-bound shader")
	_check(str(record.get("executable_sha256", "")).length() == 64,
		"actual executable content SHA-256 recorded")
	_check(record.get("resource_budget", {}).get("ok", false),
		"capture was admitted by preallocation resource budget")
	var source_identity: Dictionary = record.get("source_identity", {})
	_check(source_identity.has("source_revision_declared") and source_identity.has("verified_source_revision"),
		"caller declaration and independent checkout revision separate")
	for entry: Dictionary in record.get("captures", []) + record.get("inputs", []):
		var relative: String = str(entry.get("file", ""))
		var absolute: String = out_dir.path_join(relative)
		_check(FileAccess.file_exists(absolute), "manifest-listed file present: " + relative)
		if FileAccess.file_exists(absolute):
			_check(FileAccess.get_sha256(absolute) == entry.get("sha256"),
				"manifest-listed file SHA-256 matches: " + relative)
			_check(FileAccess.get_file_as_bytes(absolute).size() == int(entry.get("bytes", -1))
				and int(entry.get("bytes", -1)) > 0, "manifest file byte count matches: " + relative)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WORLD_PACK_GRAPHICAL: NOT RUN: real graphical renderer required")
		quit(77)
		return
	var root_dir: String = ProjectSettings.globalize_path(
		"user://world-pack-capture-smoke-" + str(Time.get_ticks_usec()))
	if DirAccess.make_dir_recursive_absolute(root_dir) != OK:
		quit(2)
		return
	var fixture: Dictionary = {
		"schema_id": "cybersand.world-feature-pack.proposal", "schema_version": 1,
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
	var input_dir: String = root_dir.path_join("input")
	var output_dir: String = root_dir.path_join("output")
	if DirAccess.make_dir_recursive_absolute(input_dir) != OK or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		quit(2)
		return
	var pack_path: String = input_dir.path_join("synthetic-pack.json")
	var file: FileAccess = FileAccess.open(pack_path, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(fixture) + "\n")
	file.close()
	var pack_hash: String = FileAccess.get_sha256(pack_path)
	var run_a: String = output_dir.path_join("run-a")
	var run_b: String = output_dir.path_join("run-b")
	_check(not run_a.begins_with(input_dir + "/") and not run_b.begins_with(input_dir + "/"),
		"capture roots cannot overlap input pack source tree")
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
	_check_manifest(run_a, pack_hash)
	_check_manifest(run_b, pack_hash)
	var input_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		run_a.path_join("inputs/combined.rg8"))
	_check(input_bytes.size() == 80 * 40 * 2 and input_bytes.has(43) and input_bytes.has(77),
		"real RG8 readback input contains valid, nonzero native material IDs")
	_check(FileAccess.get_sha256(pack_path) == pack_hash,
		"source pack remains byte-identical after both runs")
	_check(not FileAccess.file_exists(input_dir.path_join("capture-manifest.json")),
		"source pack directory has no generated capture manifest")
	# The first invocation succeeded. A subsequent malformed option to the
	# SAME destination must fail closed rather than retaining a success marker.
	var reuse_exit: int = _invoke(pack_path, run_a, "1.37", true)
	_check(reuse_exit != 0, "R1 bad scale after success is a real nonzero process exit")
	_check(not FileAccess.file_exists(run_a.path_join("capture-manifest.json")),
		"R1 previous success manifest invalidated before malformed --scale")
	var failed_status: String = FileAccess.get_file_as_string(run_a.path_join("capture-status.json"))
	_check('"success": false' in failed_status or '"success":false' in failed_status,
		"R1 failed retry records an explicit non-success status")
	var invalid_pack: String = input_dir.path_join("invalid.json")
	file = FileAccess.open(invalid_pack, FileAccess.WRITE)
	file.store_string('{"schema_id":"cybersand.world-feature-pack.proposal","schema_version":1,"scene":{"size":[16,16],"placements":[]},"features":[{"id":"bad","size":[4,4],"rectangles":[[0,0,9,4,1]]}]}')
	file.close()
	var rejected_path: String = output_dir.path_join("reject")
	var invalid_exit: int = _invoke(invalid_pack, rejected_path, "1.37")
	_check(invalid_exit != 0, "bad rectangle must fail as a process")
	_check(not FileAccess.file_exists(rejected_path.path_join("capture-manifest.json")),
		"failed capture never writes a successful-looking manifest")
	print("WORLD_PACK_GRAPHICAL assertions=%d failures=%d adapter=%s" % [
		assertions, failures, RenderingServer.get_video_adapter_name()])
	quit(1 if failures > 0 else 0)
