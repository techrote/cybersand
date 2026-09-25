extends SceneTree

const Recorder = preload("res://scripts/gameplay_recorder.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_patch_reconstruction_and_overflow()
	_test_actor_only_motion_and_representation()
	_test_threaded_output_and_provenance()
	_test_async_finalization()
	_test_incomplete_disposition()
	if _failures == 0:
		print("Gameplay recorder regression passed")
	quit(_failures)


func _base_snapshot(serial: int, published_usec: int) -> CyberSimulationSnapshot:
	var snapshot: CyberSimulationSnapshot = CyberSimulationSnapshot.new()
	snapshot.serial = serial
	snapshot.published_usec = published_usec + 500
	snapshot.world_revision = serial
	snapshot.simulation_world_revision = 1000 + serial
	snapshot.render_channels = 2
	# Deliberately newer consumer state proves recorder metadata is bound to the
	# material render generation rather than relabelled by this later snapshot.
	snapshot.tick_index = 900 + serial
	snapshot.character_position = Vector2(99.0, 99.0)
	snapshot.character_velocity = Vector2.ZERO
	snapshot.character_grounded = false
	snapshot.player_representation = "sampled-baseline"
	snapshot.player_body_id = 0
	snapshot.backend_name = "test-native"
	snapshot.scheduler_thread_capacity_hint = 4
	snapshot.simulation_time_ms = 2.5
	snapshot.worker_step_time_ms = 3.0
	snapshot.worker_overruns = 4

	snapshot.render_tick_index = 100 + serial
	snapshot.render_generated_usec = published_usec
	snapshot.render_simulation_time_ms = 1.25
	snapshot.render_worker_step_time_ms = 1.5
	snapshot.render_worker_overruns = 2
	snapshot.render_character_position = Vector2(11.25, 20.5)
	snapshot.render_character_velocity = Vector2(2.0, -1.0)
	snapshot.render_character_grounded = true
	snapshot.render_rigid_body_states = PackedFloat32Array([
		1.0, 12.0, 22.0, 0.125, 8.0, 14.0, 3.0, 4.0, 0.25, 5.0, 77.0,
	])
	snapshot.current_rigid_body_states = snapshot.render_rigid_body_states.duplicate()
	snapshot.render_context = {
		"micro_active": true,
		"profile": {"name": "Baseline"},
		"profile_hash": "transport-test",
		"water_policy_hash": "",
		"player_environment_profile": {
			"id": "earth-feel-2x-gravity",
			"hash": "penv-test",
			"effective_mass": 1.0,
			"gravity_acceleration": 184.0,
			"terminal_fall_speed": 86.0,
		},
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
	# A conflicting later context makes accidental consumer-snapshot use visible.
	snapshot.lab_context = {
		"micro_active": true,
		"profile": {"name": "WrongLaterProfile"},
		"profile_hash": "wrong-later-hash",
		"player_environment_profile": {
			"id": "wrong-later-player-profile",
			"gravity_acceleration": 1.0,
		},
		"microscenario": {
			"id": "wrong/later-snapshot",
			"presentation": {"profile": "wrong-later-tuning"},
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


func _stale_render_snapshot(serial: int, render_serial: int, published_usec: int) -> CyberSimulationSnapshot:
	var snapshot: CyberSimulationSnapshot = _base_snapshot(serial, published_usec)
	snapshot.render_snapshot_serial = render_serial
	# Same material generation as the first fixture frame, but a later actor
	# sample. The recorder must reuse material bytes without relabelling them.
	snapshot.render_tick_index = 101
	snapshot.render_generated_usec = published_usec - 20000
	snapshot.character_position = Vector2(15.25 + serial, 20.5)
	snapshot.character_velocity = Vector2(5.0, 0.0)
	snapshot.character_grounded = true
	snapshot.render_patch_rectangles = PackedInt32Array([
		10, 20, 4, 3, 0, 8,
	])
	snapshot.render_patch_cells = PackedByteArray([
		1, 0, 2, 0, 3, 0, 4, 0,
		5, 0, 6, 0, 7, 0, 8, 0,
		9, 0, 12, 0, 13, 0, 14, 0,
	])
	return snapshot


func _barrel_actor_snapshot(serial: int, render_serial: int, published_usec: int) -> CyberSimulationSnapshot:
	var snapshot: CyberSimulationSnapshot = _stale_render_snapshot(
		serial,
		render_serial,
		published_usec
	)
	snapshot.player_representation = "barrel-rapier"
	snapshot.player_body_id = 1
	snapshot.current_rigid_body_states = PackedFloat32Array([
		1.0, 30.0, 40.0, 0.25, 8.0, 14.0, 6.0, -2.0, 0.5, 7.0, 88.0,
	])
	return snapshot


func _test_patch_reconstruction_and_overflow() -> void:
	var recorder = Recorder.new()
	var start_error: Error = recorder.start_recording({
		"roi": Rect2i(11, 21, 2, 2),
		"capture_hz": 60,
		"queue_capacity": 2,
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
	_expect(int(first_status.render_publications_observed) == 1, "first render publication was not counted")

	# A newer actor sample with the same material generation must produce a
	# review frame without applying the material patch a second time.
	recorder.ingest_snapshot(_stale_render_snapshot(20, 1, base_usec + 20000))
	var stale_status: Dictionary = recorder.status()
	_expect(int(stale_status.capture_attempts) == 2, "actor-only motion was not captured")
	_expect(int(stale_status.enqueued_frames) == 2, "actor-only frame was not retained")
	_expect(int(stale_status.dropped_frames) == 0, "actor-only frame fabricated a queue drop")
	_expect(
		int(stale_status.render_publications_observed) == 1,
		"unchanged material generation was applied twice"
	)

	recorder.ingest_snapshot(_delta_snapshot(2, base_usec + 40000))
	_expect(
		recorder._roi_material_ids == PackedByteArray([6, 7, 12, 23]),
		"dropped capture prevented authoritative publication state from advancing"
	)
	var overflow_status: Dictionary = recorder.status()
	_expect(int(overflow_status.render_publications_observed) == 2, "delta render publication was not counted")
	_expect(int(overflow_status.dropped_frames) == 1, "queue overflow did not drop one capture")
	_expect(int(overflow_status.enqueued_frames) == 2, "queue overflow admitted an extra frame")
	_expect(recorder._drop_events.size() == 1, "drop provenance was not retained")
	_expect(
		str(recorder._drop_events[0].reason) == "queue-full",
		"drop provenance did not identify queue pressure"
	)
	recorder.stop_recording()


func _test_actor_only_motion_and_representation() -> void:
	var recorder = Recorder.new()
	var start_error: Error = recorder.start_recording({
		"roi": Rect2i(10, 20, 40, 40),
		"capture_hz": 60,
		"queue_capacity": 4,
	}, {"source": "test"}, false)
	_expect(start_error == OK, "actor-only recorder failed to start")
	if start_error != OK:
		return
	var base_usec: int = Time.get_ticks_usec() + 100
	recorder.ingest_snapshot(_full_snapshot(1, base_usec))
	recorder.ingest_snapshot(_stale_render_snapshot(2, 1, base_usec + 20000))
	recorder.ingest_snapshot(_barrel_actor_snapshot(3, 1, base_usec + 40000))
	_expect(recorder._queue.size() == 3, "actor-only cadence did not retain three frames")
	if recorder._queue.size() == 3:
		var first_ids: PackedByteArray = recorder._queue[0].material_ids
		var second_ids: PackedByteArray = recorder._queue[1].material_ids
		var third_ids: PackedByteArray = recorder._queue[2].material_ids
		_expect(first_ids == second_ids and second_ids == third_ids, "actor-only capture changed material bytes")
		var sampled: Dictionary = recorder._queue[1].metadata
		_expect(
			str(sampled.player.representation) == "sampled-baseline",
			"sampled representation identity was lost"
		)
		_expect(
			int(sampled.material_generation.completed_simulation_tick) == 101,
			"actor-only frame relabelled material generation tick"
		)
		_expect(
			int(sampled.actor_sample.completed_simulation_tick) == 902,
			"actor-only sample tick was not retained"
		)
		var barrel: Dictionary = recorder._queue[2].metadata
		_expect(
			str(barrel.player.representation) == "barrel-rapier",
			"barrel representation was recorded as sampled"
		)
		_expect(int(barrel.player.body_id) == 1, "barrel player body identity was not retained")
		_expect(
			absf(float(barrel.player.origin[0]) - 26.0) < 0.0001
			and absf(float(barrel.player.origin[1]) - 33.0) < 0.0001,
			"barrel player origin did not come from the active body sample"
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
	_expect(
		int(manifest.counters.render_publications_observed) == 1,
		"manifest did not retain render-publication count"
	)
	_expect(
		manifest.counters.has("render_patch_apply_usec_max"),
		"manifest did not retain render-patch folding cost"
	)

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
				int(frame.completed_simulation_tick) == 903,
				"actor-sample completed simulation tick was not retained"
			)
			_expect(
				int(frame.material_generation.completed_simulation_tick) == 103,
				"material-generation completed simulation tick was not retained separately"
			)
			_expect(
				int(frame.consumer_snapshot_tick) == 903,
				"later consumer snapshot tick was not retained separately"
			)
			_expect(
				int(frame.render_generated_monotonic_usec) < int(frame.consumer_snapshot_published_monotonic_usec),
				"render-generation timing was not distinguished from consumer publication timing"
			)
			_expect(
				str(frame.player.representation) == "sampled-baseline",
				"active sampled representation was not retained"
			)
			_expect(
				str(frame.scenario.id) == "rem003/player-granular-review",
				"render-generation scenario identity was not retained"
			)
			_expect(
				str(frame.scenario.tuning_profile) == "candidate-c1/owner-review-v1",
				"tuning profile identity was not retained"
			)
			_expect(
				str(frame.player.environment_profile.id) == "wrong-later-player-profile",
				"actor-sample player/environment profile was not retained"
			)
			_expect(
				absf(float(frame.scenario.player_environment_profile.gravity_acceleration) - 1.0) < 0.0001,
				"scenario evidence lost actor-sample player/environment settings"
			)
			_expect(
				absf(float(frame.player.origin[0]) - 99.0) < 0.0001,
				"player state was not taken from the actor sample"
			)
			_expect(
				absf(float(frame.simulation_time_ms) - 2.5) < 0.0001,
				"actor-sample simulation timing was not retained"
			)
			_expect(
				int(frame.recording_configuration.capture_hz) == 60,
				"per-frame recording configuration was not retained"
			)
			_expect(
				str(frame.session_identity.source_revision) == "test-sha",
				"per-frame source identity was not retained"
			)
			_expect(
				str(frame.session_identity.runtime_artifact_sha256) == "test-runtime",
				"per-frame runtime identity was not retained"
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


func _test_async_finalization() -> void:
	var recorder = Recorder.new()
	var session: String = "async-finalize-%d" % Time.get_ticks_usec()
	var output_root: String = "user://rec001-tests"
	var start_error: Error = recorder.start_recording({
		"roi": Rect2i(11, 21, 2, 2),
		"capture_hz": 60,
		"queue_capacity": 2,
		"output_root": output_root,
		"session_name": session,
	}, {"source": "test"}, true)
	_expect(start_error == OK, "async-finalization recorder failed to start")
	if start_error != OK:
		return
	recorder.ingest_snapshot(_full_snapshot(5, Time.get_ticks_usec() + 100))
	var requested: Dictionary = recorder.request_stop()
	_expect(bool(requested.finalizing), "request_stop did not enter finalizing state")
	_expect(not bool(requested.accepting), "request_stop kept admitting frames")
	var deadline: int = Time.get_ticks_msec() + 5000
	while recorder.is_active() and Time.get_ticks_msec() < deadline:
		OS.delay_msec(1)
	var final_status: Dictionary = recorder.poll_finalization()
	_expect(not bool(final_status.active), "asynchronous finalization did not complete")
	_expect(int(final_status.written_frames) == 1, "asynchronous finalization lost queued frame")
	var manifest_path: String = output_root.path_join(session).path_join("recording.json")
	_expect(FileAccess.file_exists(manifest_path), "async finalization did not write manifest")


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
