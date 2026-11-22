extends SceneTree

var checks: int = 0
var failures: int = 0
var scene
var original_manifest_path: String = ""


func _init() -> void:
	Engine.max_fps = 240
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _ready_idle(seconds: int = 20) -> bool:
	var deadline: int = Time.get_ticks_msec() + seconds * 1000
	while Time.get_ticks_msec() < deadline:
		if scene.host.failed:
			return false
		if scene.host.state == "Idle" and scene.host.actions.is_empty() and scene.queued_cuts.is_empty():
			return true
		await process_frame
	return false


func _run() -> void:
	original_manifest_path = OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")
	var observed_manifest: String = original_manifest_path
	if observed_manifest.is_empty():
		# A source-labelled fixture tests byte readback only. This test never
		# describes the fixture as a sealed or delivered package.
		observed_manifest = "user://objectshard-m3-manifest-readback-fixture.json"
		var fixture: FileAccess = FileAccess.open(observed_manifest, FileAccess.WRITE)
		fixture.store_string(JSON.stringify({"source_commit": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
			"scope": "Manifest readback fixture; not delivered-package custody"}))
		fixture.close()
		OS.set_environment("CYBERSAND_PACKAGE_MANIFEST", observed_manifest)
	var packed: PackedScene = load("res://object_shard_worker_rehearsal.tscn")
	_expect(packed != null, "Owner opt-in rehearsal scene loads")
	if packed == null:
		_finish({})
		return
	scene = packed.instantiate()
	root.add_child(scene)
	_expect(await _ready_idle(), "Owner scene starts the actual native worker and real Rapier host")
	if not scene.host.failed:
		var manifest_digest: String = FileAccess.get_sha256(observed_manifest)
		_expect(scene.host.diagnostics().get("package_manifest_sha256") == manifest_digest
			and scene.host.diagnostics().get("package_identity", {}).get("source_commit") == OS.get_environment("CYBERSAND_SOURCE_REVISION"),
			"Incident diagnostics retain the exact observed manifest bytes and source readback")
		_expect(scene.host.capture.header.get("package_manifest_sha256") == manifest_digest
			and scene.host.capture.header.get("package_identity", {}).get("status") == "observed-package-manifest",
			"Prospective trace header binds the same package identity before actions begin")
		_expect(scene.view.world_texture != null and scene.view.frame.width == 192,
			"Owner view receives a real material texture from the applied native publication")
		scene._cut_support()
		_expect(await _ready_idle(), "Visible support tool drains bounded ordinary native edit actions")
		for tick: int in range(10):
			scene.host.request_tick()
			await process_frame
			if not await _ready_idle():
				break
			if not scene.host.bridge.bodies.is_empty():
				break
		_expect(not scene.host.failed and scene.host.bridge.bodies.size() == 1,
			"The owner's ordinary support tool genuinely promotes native Wood into Rapier")
		_expect(scene.view.poses.is_empty() and scene.view.frame.tick == scene.host.publication.tick,
			"The scene renders accepted native poses rather than unacknowledged RID overrides")
		scene._export()
		_expect(not scene.last_export.is_empty() and FileAccess.file_exists(scene.last_export), "Owner Export writes a real bounded incident report")
		var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.last_export))
		_expect(result.get("schema") == "objectshard-worker-rehearsal-v1" and result.get("scope", "").contains("not attached"),
			"Export labels standalone integration scope honestly")
		_expect(result.get("capture", {}).get("complete_prefix", false) and not result.get("replay", {}).get("receipt_timing_replayed", true),
			"Export retains source-bound action evidence without claiming asynchronous arrival replay")
		var trace: String = ProjectSettings.globalize_path(scene.host.capture.path)
		_expect(FileAccess.file_exists(trace) and FileAccess.get_file_as_string(trace).contains("standalone-exclusive-worker-rehearsal"),
			"The prospective trace identifies this exact host family")
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--report-copy="):
				var path: String = argument.trim_prefix("--report-copy=")
				var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
				output.store_string(JSON.stringify(result, "  ") + "\n")
				output.close()
				DirAccess.copy_absolute(trace, path + ".jsonl")
	var report: Dictionary = scene.host.diagnostics()
	scene.host.close()
	var deadline: int = Time.get_ticks_msec() + 10000
	while scene.host.state != "Closed" and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(scene.host.state == "Closed", "Owner scene stops its exclusive native owner and releases main-thread resources")
	scene.queue_free()
	await process_frame
	OS.set_environment("CYBERSAND_PACKAGE_MANIFEST", original_manifest_path)
	_finish(report)


func _finish(report: Dictionary) -> void:
	print(JSON.stringify({"schema": "objectshard-worker-scene-test-v1", "checks": checks, "failures": failures,
		"scope": "Actual owner scene and native/Rapier actions; headless view upload does not establish rendered physical acceptance",
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "report": report}))
	quit(0 if failures == 0 else 1)
