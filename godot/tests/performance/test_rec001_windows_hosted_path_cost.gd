extends SceneTree

# REC-001 / #135: isolated Windows hosted GDScript recorder-path cost probe.
# SYNTHETIC immutable snapshots, not live World/Rapier/gameplay performance.
# Runs two counterbalanced OFF/ON pairs at timer-paced ~60 publications/s.
# NEVER pauses an authoritative simulation to retain a capture.
const Recorder = preload("res://scripts/gameplay_recorder.gd")
const FRAMES: int = 72
const ROI: Rect2i = Rect2i(16, 16, 128, 96)
const SNAPSHOT_INTERVAL_SEC: float = 0.017
const CASES: Array[String] = ["off", "on", "on", "off"]
const PREFIX: String = "REC001_HOST_PROBE "

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_execute")


func _execute() -> void:
	if OS.get_name() != "Windows":
		_failures.append("This experiment requires actual Windows execution")
	# Godot extension runtime is verified by the CI provenance verifier and
	# by constructing actual CyberSimulationSnapshot instances in each arm.
	# ClassDB.class_exists is not a valid admission oracle for GDExtension classes.
	if not _failures.is_empty():
		_report([])
		return

	var results: Array[Dictionary] = []
	for index: int in range(CASES.size()):
		var one: Dictionary = await _run_case(CASES[index], index)
		results.append(one)
	for row: Dictionary in results:
		if row.has("error"):
			_failures.append(str(row.error))
		elif row.get("arm") == "on":
			var counters: Dictionary = row.get("recorder", {})
			if int(counters.get("written_frames", 0)) < 4:
				_failures.append("ON case retained fewer than four frames")
			if int(counters.get("capture_attempts", 0)) != (
				int(counters.get("enqueued_frames", 0)) +
				int(counters.get("dropped_frames", 0))
			):
				_failures.append("capture attempts do not equal enqueued + dropped")
			if int(counters.get("written_frames", 0)) != int(counters.get("enqueued_frames", -1)):
				_failures.append("writer failed to finalize all enqueued frames")
			if int(counters.get("queue_high_water", 0)) > 8:
				_failures.append("bounded queue capacity exceeded")
			if bool(counters.get("failed", false)) or not str(counters.get("incomplete_reason", "")).is_empty():
				_failures.append("recording failed or incomplete: " + str(counters))
	_report(results)


func _report(rows: Array) -> void:
	var report: Dictionary = {
		"schema": "rec001-hosted-recorder-path-cost-v1",
		"evidence_class": "actual Windows Godot GDScript recorder; synthetic snapshot stimulus; no live World/Rapier",
		"godot_version": str(Engine.get_version_info().get("string", "")),
		"platform": OS.get_name(),
		"display_server": DisplayServer.get_name(),
		"fixture": "synthetic/rec001-actor-motion-with-material-deltas",
		"roi": [ROI.position.x, ROI.position.y, ROI.size.x, ROI.size.y],
		"frames_per_arm": FRAMES,
		"requested_interval_usec": roundi(SNAPSHOT_INTERVAL_SEC * 1000000.0),
		"capture_hz": 15,
		"queue_capacity": 8,
		"authoritative_native_world_ticks": 0,
		"observed_native_worker_participation": 0,
		"rows": rows,
		"failures": _failures,
	}
	print(PREFIX + JSON.stringify(report))
	quit(0 if _failures.is_empty() else 1)


func _make_snapshot(index: int, published_usec: int, generation_usec: int) -> CyberSimulationSnapshot:
	var snapshot: CyberSimulationSnapshot = CyberSimulationSnapshot.new()
	var generation: int = int(index / 18)
	snapshot.serial = index + 1
	snapshot.tick_index = index + 1
	snapshot.published_usec = published_usec
	snapshot.world_revision = generation + 1
	snapshot.simulation_world_revision = generation + 1
	snapshot.backend_name = "synthetic-no-world"
	snapshot.scheduler_thread_capacity_hint = 0
	snapshot.render_snapshot_serial = generation + 1
	snapshot.render_tick_index = generation * 18
	snapshot.render_generated_usec = generation_usec
	snapshot.render_channels = 2
	snapshot.render_full_refresh = index == 0
	snapshot.character_position = Vector2(30.0 + float(index % 32) * 0.35, 36.0)
	snapshot.character_velocity = Vector2(0.35, 0.0)
	snapshot.character_grounded = false
	snapshot.player_representation = "sampled-baseline"
	snapshot.player_body_id = 0
	snapshot.current_rigid_body_states = PackedFloat32Array()
	snapshot.render_rigid_body_states = PackedFloat32Array()
	snapshot.render_context = {
		"micro_active": true,
		"profile": {"name": "synthetic-probe-not-gameplay"},
		"microscenario": {
			"id": "synthetic/rec001-hosted-cost-probe",
			"definition_hash": "unqualified-synthetic",
			"source_recipe": "fixed-ROI-actor-motion-and-material-deltas",
			"source_recipe_hash": "unqualified-synthetic",
			"seed": 1,
			"mode": "Play",
			"presentation": {},
		},
	}
	snapshot.lab_context = snapshot.render_context.duplicate(true)
	if index == 0:
		var full: PackedByteArray = PackedByteArray()
		full.resize(ROI.size.x * ROI.size.y * 2)
		for offset: int in range(0, full.size(), 2):
			full[offset] = 1 + (int(offset / 2) % 3)
			full[offset + 1] = 0
		snapshot.render_patch_rectangles = PackedInt32Array([
			ROI.position.x, ROI.position.y, ROI.size.x, ROI.size.y, 0, ROI.size.x * 2
		])
		snapshot.render_patch_cells = full
	elif index % 18 == 0:
		snapshot.render_patch_rectangles = PackedInt32Array([
			ROI.position.x + generation, ROI.position.y + generation, 1, 1, 0, 2
		])
		snapshot.render_patch_cells = PackedByteArray([3, 0])
	return snapshot


func _percentile(values: Array[int], fraction: float) -> int:
	if values.is_empty():
		return -1
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, floori(fraction * float(sorted.size() - 1)))]


func _run_case(arm: String, index: int) -> Dictionary:
	var recorder = Recorder.new()
	var enabled: bool = arm == "on"
	if enabled:
		var start: Error = recorder.start_recording({
			"roi": ROI,
			"capture_hz": 15,
			"queue_capacity": 8,
			"retain_raw_ids": true,
			"output_root": "user://rec001-hosted-path-cost",
			"session_name": "case-%d-%s" % [index, arm],
		}, {
			"source": {"revision": OS.get_environment("CYBERSAND_SOURCE_REVISION")},
			"native_runtime": {"mode": "pinned-committed-windows-dll"},
			"platform": {"os": OS.get_name(), "godot": Engine.get_version_info()},
			"fixture": "synthetic/rec001-hosted-cost-probe",
		})
		if start != OK:
			return {"error": "failed to start recorder for case %d: %d" % [index, int(start)]}

	var operation_us: Array[int] = []
	var cadence_us: Array[int] = []
	var prior_publish_usec: int = 0
	var generation_usec: int = 0
	var first_usec: int = Time.get_ticks_usec()
	for frame: int in range(FRAMES):
		await create_timer(SNAPSHOT_INTERVAL_SEC).timeout
		var begin: int = Time.get_ticks_usec()
		if frame % 18 == 0:
			generation_usec = begin
		var snapshot: CyberSimulationSnapshot = _make_snapshot(frame, begin, generation_usec)
		if enabled:
			recorder.ingest_snapshot(snapshot)
		operation_us.append(Time.get_ticks_usec() - begin)
		if prior_publish_usec > 0:
			cadence_us.append(begin - prior_publish_usec)
		prior_publish_usec = begin
	var total_usec: int = Time.get_ticks_usec() - first_usec
	var status: Dictionary = {}
	var finished_usec: int = 0
	var output: String = ""
	if enabled:
		var finish_begin: int = Time.get_ticks_usec()
		status = recorder.stop_recording()
		finished_usec = Time.get_ticks_usec() - finish_begin
		output = ProjectSettings.globalize_path(recorder.session_path())
		for expected: String in ["recording.json", "frame-000001.ids", "frame-000001.bmp", "frame-000001.json"]:
			if not FileAccess.file_exists(output.path_join(expected)):
				return {"error": "required actual writer output missing: " + expected, "arm": arm}
	return {
		"arm": arm,
		"sequence": index,
		"synthetic_published_snapshots": FRAMES,
		"elapsed_usec_excluding_finalize": total_usec,
		"finalization_usec": finished_usec,
		"operation_p50_usec": _percentile(operation_us, 0.50),
		"operation_p95_usec": _percentile(operation_us, 0.95),
		"operation_p99_usec": _percentile(operation_us, 0.99),
		"operation_max_usec": _percentile(operation_us, 1.0),
		"publication_interval_p50_usec": _percentile(cadence_us, 0.50),
		"publication_interval_p95_usec": _percentile(cadence_us, 0.95),
		"publication_interval_max_usec": _percentile(cadence_us, 1.0),
		"recorder": status,
		"output_directory": output,
	}
