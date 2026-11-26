extends SceneTree

# Disposable subprocess fixture. The parent installs a real OS file-size limit
# after a valid initial manifest exists, then releases this child with a marker.
const Recorder = preload("res://scripts/gameplay_recorder.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("RECORDER_TEST_OUTPUT")
	var marker := OS.get_environment("RECORDER_TEST_CONTINUE")
	var recorder := Recorder.new()
	var error := recorder.start_recording({"roi":Rect2i(0,0,32,32),
		"output_root":output,"session_name":"session","capture_hz":60},
		{"source":"disposable-storage-fault-fixture"}, true)
	if error != OK:
		printerr("RECORDER_TEST_START_REFUSED ", error, " ", recorder.status())
		quit(2)
		return
	var manifest := output.path_join("session/recording.json")
	var before_hash := FileAccess.get_sha256(manifest)
	print("RECORDER_TEST_READY ", JSON.stringify({"manifest":manifest,
		"bytes":FileAccess.get_file_as_bytes(manifest).size(),"sha256":before_hash}))
	var deadline := Time.get_ticks_msec() + 15000
	while not FileAccess.file_exists(marker) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not FileAccess.file_exists(marker):
		recorder.stop_recording("parent did not release test fixture")
		quit(2)
		return
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.serial = 1
	snapshot.published_usec = Time.get_ticks_usec() + 100
	snapshot.tick_index = 1
	snapshot.render_snapshot_serial = 1
	snapshot.render_full_refresh = true
	snapshot.render_channels = 2
	snapshot.render_tick_index = 1
	snapshot.render_generated_usec = snapshot.published_usec
	snapshot.render_patch_rectangles = PackedInt32Array([0,0,32,32,0,64])
	snapshot.render_patch_cells.resize(2048)
	snapshot.render_patch_cells.fill(2)
	recorder.ingest_snapshot(snapshot)
	var final := recorder.stop_recording()
	var bytes := FileAccess.get_file_as_bytes(manifest)
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	var frame := output.path_join("session/frame-000001.ids")
	print("RECORDER_TEST_RESULT ", JSON.stringify({"status":final,
		"manifest_bytes":bytes.size(),"manifest_sha256":FileAccess.get_sha256(manifest),
		"prior_manifest_preserved":FileAccess.get_sha256(manifest)==before_hash,
		"manifest_disposition":parsed.get("disposition","invalid") if parsed is Dictionary else "invalid",
		"frame_bytes":FileAccess.get_file_as_bytes(frame).size() if FileAccess.file_exists(frame) else 0}))
	quit()
