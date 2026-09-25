extends SceneTree

const Recorder = preload("res://scripts/gameplay_recorder.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_patch_reconstruction_and_overflow()
	_test_threaded_output_and_provenance()
	_test_incomplete_disposition()
	if _failures == 0:
		print("Gameplay recorder regression passed")
	quit(_failures)


func _base_snapshot(serial: int, published_usec: int) -> CyberSimulationSnapshot:
	var snapshot: CyberSimulationSnapshot = CyberSimulationSnapshot.new()
	snapshot.serial = serial
	snapshot.published_usec = published_usec
	snapshot.world_revision = serial
	snapshot.render_channels = 2
	snapshot.tick_index = 100 + serial
	snapshot.backend_name = "test-native"
	snapshot.scheduler_thread_capacity_hint = 4
	snapshot.simulation_time_ms = 1.25
	snapshot.worker_step_time_ms = 1.5
	snapshot.character_position = Vector2(11.25, 20.5)
	snapshot.character_velocity = Vector2(2.0, -1.0)
	snapshot.character_grounded = true
	snapshot.rigid_body_states = PackedFloat32Array([
		1.0, 12.0, 22.0, 0.125, 8.0, 14.0, 3.0, 4.0, 0.25, 5.0, 77.0,
	])
	snapshot.lab_context = {
		"micro_active": true,
		"profile": {"name": "Baseline"},
		"profile_hash": "transport-test",
		"water_policy_hash": "",
		"microscenario": {
			"id": "rem003/player-granular-review",
			"definition_hash": "definition-test",
			"source_recipe": "test-recipe",
			"source_recipe_hash": "recipe-test",
			"seed": 0,
			"mode": "Play",
			"presentation": {"profile": "candidate-c1/owner-review-v1"},
		},
	}
	return snapshot


func _full_snapshot(serial: int, published_usec: int) -> CyberSimulationSnapshot:
	var snapshot: CyberSimulationSnapshot = _base_snapshot(serial, published_usec)
	snapshot.render_snapshot_serial = serial
	snapshot.render_full_refresh = true
	snapshot.render_patch_rectangles = PackedInt32Array([
		10, 20, 4, 3, 0, 8,
	])
	snapshot.render_patch_cells = PackedByteArray([
		1, 0, 2, 0, 3, 0, 4, 0,
		5, 0, 6, 0, 7, 0, 8, 0,
		9, 0, 12, 0, 13, 0, 14, 0,
	])
	return snapshot


func _delta_snapshot(serial: int, published_usec: int) -> CyberSimulationSnapshot:
	var snapshot: CyberSimulationSnapshot = _base_snapshot(serial, published_usec)
	snapshot.render_snapshot_serial = serial
	snapshot.render_full_refresh = false
	snapshot.render_patch_rectangles = PackedInt32Array([
		12, 22, 1, 1, 0, 2,
	])
	snapshot.render_patch_cells = PackedByteArray([23, 0])
	return snapshot


func _test_patch_reconstruction_and_overflow() -> void:
	var recorder = Recorder.new()
	var start_error: Error = recorder.start_recording({
		"roi": Rect2i(11, 21, 2, 2),
		"capture_hz": 60,
		"queue_capacity": 1,
	}, {"source": "test"}, false)
	_expect(start_error == OK, "in-memory recorder failed to start")
	var base_usec: int = Time.get_ticks_usec() + 100
	recorder.ingest_snapshot(_full_snapshot(1, base_usec))

	_expect(recorder._primed, "full publication did not prime recorder ROI")
	_expect(
		recorder._roi_material_ids == PackedByteArray([6, 7, 12, 13]),
		"recorder did not reconstruct expected ROI material IDs"
	)
	var first_status: Dictionary = recorder.status()
	_expect(int(first_status.enqueued_frames) == 1, "first frame was not enqueued")
	_expect(int(first_status.queue_high_water) == 1, "queue high-water was not recorded")

	recorder.ingest_snapshot(_delta_snapshot(2, base_usec + 20000))
	_expect(
		recorder._roi_material_ids == PackedByteArray([6, 7, 12, 23]),
		"dropped capture prevented authoritative publication state from advancing"
	)
	var overflow_status: Dictionary = recorder.status()
	_expect(int(overflow_status.dropped_frames) == 1, "queue overflow did not drop one capture")
	_expect(int(overflow_status.enqueued_frames) == 1, "queue overflow admitted an extra frame")
	_expect(recorder._drop_events.size() == 1, "drop provenance was not retained")
	_expect(
		str(recorder._drop_events[0].reason) == "queue-full",
		"drop provenance did not identify queue pressure"
	)
	recorder.stop_recording()


func _test_threaded_output_and_provenance() -> void:
	var recorder = Recorder.new()
	var session: String = "threaded-%d" % Time.get_ticks_usec()
	var output_root: String = "user://rec001-tests"
	var start_error: Error = recorder.start_recording({
		"roi": Rect2i(11, 21, 2, 2),
		"capture_hz": 60,
		"queue_capacity": 2,
		"output_root": output_root,
		"session_name": session,
		"retain_raw_ids": true,
	}, {
		"source": {"source_revision": "test-sha"},
		"native_runtime": {"sha256": "test-runtime"},
	}, true)
	_expect(start_error == OK, "threaded recorder failed to start")
	if start_error != OK:
		return

	recorder.ingest_snapshot(_full_snapshot(3, Time.get_ticks_usec() + 100))
	var final_status: Dictionary = recorder.stop_recording()
	_expect(not bool(final_status.failed), "threaded recorder reported failure")
	_expect(int(final_status.written_frames) == 1, "threaded recorder did not write one frame")

	var root: String = output_root.path_join(session)
	var manifest_path: String = root.path_join("recording.json")
	_expect(FileAccess.file_exists(manifest_path), "final recording manifest is missing")
	if not FileAccess.file_exists(manifest_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	_expect(parsed is Dictionary, "recording manifest is not valid JSON")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	_expect(str(manifest.disposition) == "complete", "normal stop did not finalize complete")
	_expect(
		str(manifest.evidence_kind) == Recorder.EVIDENCE_KIND,
		"manifest did not distinguish state evidence from replay"
	)
	_expect(
		str(manifest.state_scope.temperature).contains("unavailable"),
		"manifest fabricated or omitted temperature availability scope"
	)
	_expect(
		str(manifest.identity.source.source_revision) == "test-sha",
		"manifest did not retain supplied source identity"
	)
	_expect(int(manifest.counters.dropped_frames) == 0, "no-pressure run reported drops")

	var ids_path: String = root.path_join("frame-000001.ids")
	var bmp_path: String = root.path_join("frame-000001.bmp")
	var frame_path: String = root.path_join("frame-000001.json")
	_expect(FileAccess.file_exists(ids_path), "raw material-ID frame is missing")
	_expect(FileAccess.file_exists(bmp_path), "indexed review bitmap is missing")
	_expect(FileAccess.file_exists(frame_path), "per-frame metadata is missing")

	if FileAccess.file_exists(ids_path):
		var ids_file: FileAccess = FileAccess.open(ids_path, FileAccess.READ)
		var ids: PackedByteArray = ids_file.get_buffer(ids_file.get_length())
		ids_file.close()
		_expect(ids == PackedByteArray([6, 7, 12, 13]), "raw material IDs changed during encoding")

	if FileAccess.file_exists(bmp_path):
		var bmp_file: FileAccess = FileAccess.open(bmp_path, FileAccess.READ)
		var signature: PackedByteArray = bmp_file.get_buffer(2)
		bmp_file.close()
		_expect(signature == PackedByteArray([0x42, 0x4D]), "review bitmap is not a BMP")

	if FileAccess.file_exists(frame_path):
		var frame_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(frame_path))
		_expect(frame_value is Dictionary, "frame metadata is not valid JSON")
		if frame_value is Dictionary:
			var frame: Dictionary = frame_value
			_expect(
				int(frame.completed_simulation_tick) == 103,
				"completed simulation tick was not retained"
			)
			_expect(
				str(frame.scenario.id) == "rem003/player-granular-review",
				"active scenario identity was not retained"
			)
			_expect(
				str(frame.scenario.tuning_profile) == "candidate-c1/owner-review-v1",
				"tuning profile identity was not retained"
			)
			_expect(frame.rigid_bodies.size() == 1, "rigid-body input state was not retained")
			if frame.rigid_bodies.size() == 1:
				_expect(
					absf(float(frame.rigid_bodies[0].rotation_radians) - 0.125) < 0.0001,
					"rigid-body rotation was not retained"
				)
				_expect(
					int(frame.rigid_bodies[0].sample_serial) == 77,
					"rigid-body sample serial was not retained"
				)


func _test_incomplete_disposition() -> void:
	var recorder = Recorder.new()
	var session: String = "incomplete-%d" % Time.get_ticks_usec()
	var output_root: String = "user://rec001-tests"
	var start_error: Error = recorder.start_recording({
		"roi": Rect2i(11, 21, 2, 2),
		"capture_hz": 60,
		"queue_capacity": 2,
		"output_root": output_root,
		"session_name": session,
	}, {"source": "test"}, true)
	_expect(start_error == OK, "incomplete-disposition recorder failed to start")
	if start_error != OK:
		return
	recorder.ingest_snapshot(_full_snapshot(4, Time.get_ticks_usec() + 100))
	recorder.stop_recording("synthetic interruption")
	var manifest_path: String = output_root.path_join(session).path_join("recording.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	_expect(parsed is Dictionary, "incomplete manifest is not valid JSON")
	if parsed is Dictionary:
		var manifest: Dictionary = parsed
		_expect(str(manifest.disposition) == "incomplete", "interrupted run was called complete")
		_expect(
			str(manifest.incomplete_reason) == "synthetic interruption",
			"incomplete reason was not retained"
		)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
