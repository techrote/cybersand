extends SceneTree

const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

const Recorder = preload("res://scripts/gameplay_recorder.gd")
const Main = preload("res://scripts/main.gd")

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--recording-roi-override-test"):
		_test_explicit_roi_override()
	else:
		_test_camera_recording_bounds()
		_test_fractional_camera_recording()
		_test_recording_world_extents()
		_test_patch_reconstruction_and_overflow()
		_test_actor_only_motion_and_representation()
		_test_threaded_output_and_provenance()
		_test_async_finalization()
		_test_incomplete_disposition()
	if _failures == 0:
		print("Gameplay recorder regression passed")
	print("GAMEPLAY_RECORDER_RESULT " + JSON.stringify({"checks": _checks, "failures": _failures}))
	quit(_failures)


func _camera_host(
		origin: Vector2,
		view_size: Vector2i = Vector2i(240, 135),
		extent: Vector2i = Vector2i(1024, 1024),
		pixels_per_cell: float = 4.0
) -> Control:
	# Keep Main out of the scene tree: these tests exercise its real camera and
	# recording methods without starting another simulation or application UI.
	var host = Main.new()
	host.world_view = TextureRect.new()
	host.add_child(host.world_view)
	host.world_view.size = Vector2(view_size) * pixels_per_cell
	host.current_view_size = view_size
	host.world_extent = extent
	host.camera_origin = origin
	return host


func _test_camera_recording_bounds() -> void:
	var cases: Array[Dictionary] = [
		{"name": "both fractional edges", "camera": Vector2(63.25, 31.75),
			"presented": Vector2(63.25, 31.75), "roi": Rect2i(63, 31, 241, 136)},
		{"name": "fractional right edge", "camera": Vector2(63.25, 31.0),
			"presented": Vector2(63.25, 31.0), "roi": Rect2i(63, 31, 241, 135)},
		{"name": "fractional bottom edge", "camera": Vector2(63.0, 31.75),
			"presented": Vector2(63.0, 31.75), "roi": Rect2i(63, 31, 240, 136)},
		{"name": "integral origin", "camera": Vector2(63.0, 31.0),
			"presented": Vector2(63.0, 31.0), "roi": Rect2i(63, 31, 240, 135)},
		{"name": "display rounding down", "camera": Vector2(63.1, 31.1),
			"presented": Vector2(63.0, 31.0), "roi": Rect2i(63, 31, 240, 135)},
		{"name": "display rounding up", "camera": Vector2(63.9, 31.9),
			"presented": Vector2(64.0, 32.0), "roi": Rect2i(64, 32, 240, 135)},
		{"name": "top left clamp", "camera": Vector2(-0.25, -0.75),
			"presented": Vector2.ZERO, "roi": Rect2i(0, 0, 240, 135)},
		{"name": "fractional last cells", "camera": Vector2(783.75, 888.75),
			"presented": Vector2(783.75, 888.75), "roi": Rect2i(783, 888, 241, 136)},
		{"name": "bottom right clamp", "camera": Vector2(784.25, 889.25),
			"presented": Vector2(784.0, 889.0), "roi": Rect2i(784, 889, 240, 135)},
		{"name": "view larger than world", "camera": Vector2(4.25, 8.75),
			"world": Vector2i(120, 90), "presented": Vector2.ZERO,
			"roi": Rect2i(0, 0, 120, 90)},
		{"name": "one axis larger than world", "camera": Vector2(4.25, 31.75),
			"world": Vector2i(120, 1024), "presented": Vector2(0.0, 31.75),
			"roi": Rect2i(0, 31, 120, 136)},
		{"name": "fractional display scale", "camera": Vector2(63.25, 31.75),
			"scale": 2.5, "presented": Vector2(63.2, 31.6),
			"roi": Rect2i(63, 31, 241, 136)},
	]
	for entry: Dictionary in cases:
		var extent: Vector2i = entry.get("world", Vector2i(1024, 1024))
		var host = _camera_host(entry.camera, Vector2i(240, 135), extent, float(entry.get("scale", 4.0)))
		var presented: Vector2 = host.presentation_camera_origin()
		_expect(presented.is_equal_approx(entry.presented), "%s: unexpected presented camera origin" % entry.name)
		var config: Dictionary = host.recording_configuration()
		_expect(config.roi == entry.roi, "%s: recording bounds %s do not match %s" % [entry.name, config.roi, entry.roi])
		_expect(config.get("world_extent", Vector2i.ZERO) == extent, "%s: actual world extent was not copied" % entry.name)
		host.free()

	# With no laid-out content, Main uses its clamped continuous camera. This
	# represented remainder disappears in a float32 Vector2 sum with the view
	# size, so the end bound must be calculated using scalar components.
	var host = _camera_host(Vector2(63.000003814697265625, 31.0))
	host.world_view.size = Vector2.ZERO
	_expect(host.presentation_camera_origin().x > 63.0, "small fractional origin was lost before ROI calculation")
	_expect(host.recording_configuration().roi == Rect2i(63, 31, 241, 135), "small fractional edge was lost when adding the view width")
	host.free()


func _region_snapshot(
		serial: int,
		published_usec: int,
		region: Rect2i,
		materials: Dictionary,
		full_refresh: bool
) -> CyberSimulationSnapshot:
	var snapshot: CyberSimulationSnapshot = _base_snapshot(serial, published_usec)
	snapshot.render_snapshot_serial = serial
	snapshot.render_full_refresh = full_refresh
	snapshot.render_patch_rectangles = PackedInt32Array([
		region.position.x, region.position.y, region.size.x, region.size.y, 0, region.size.x * 2,
	])
	snapshot.render_patch_cells.resize(region.size.x * region.size.y * 2)
	snapshot.render_patch_cells.fill(0)
	for world_cell: Vector2i in materials:
		var local_cell: Vector2i = world_cell - region.position
		var offset: int = (local_cell.y * region.size.x + local_cell.x) * 2
		snapshot.render_patch_cells[offset] = int(materials[world_cell])
		snapshot.render_patch_cells[offset + 1] = 173
	return snapshot


func _expect_recorded_cell(recorder, frame: PackedByteArray, world_cell: Vector2i, material_id: int, label: String) -> void:
	var roi: Rect2i = recorder._roi
	if not roi.has_point(world_cell):
		_expect(false, "%s: visible cell %s was excluded from recording ROI %s" % [label, world_cell, roi])
		return
	var local_cell: Vector2i = world_cell - roi.position
	var index: int = local_cell.y * roi.size.x + local_cell.x
	_expect(index < frame.size() and frame[index] == material_id, "%s: recorded material ID was omitted or changed" % label)


func _test_fractional_camera_recording() -> void:
	# Repeat beyond the legacy 1024-square extent to test Main -> Recorder
	# admission as well as retention of the actual visible edge material IDs.
	for origin: Vector2 in [Vector2(63.25, 31.75), Vector2(1400.25, 1100.75)]:
		var extent: Vector2i = Vector2i(1024, 1024) if origin.x < 1024.0 else Vector2i(2048, 1536)
		var host = _camera_host(origin, Vector2i(240, 135), extent)
		var expected_roi: Rect2i = Rect2i(floori(origin.x), floori(origin.y), 241, 136)
		var config: Dictionary = host.recording_configuration()
		config.capture_hz = 60
		config.queue_capacity = 2
		var recorder = Recorder.new()
		var start_error: Error = recorder.start_recording(config, {"source": "fractional-camera-test"}, false)
		_expect(start_error == OK, "fractional-camera recording failed to start")
		if start_error != OK:
			host.free()
			continue
		_expect(recorder._roi == expected_roi, "recorder admission changed the displayed cell bounds")
		var admitted_roi: Rect2i = recorder._roi
		_expect(recorder._config.get("world_extent", []) == [extent.x, extent.y], "recorder did not retain actual world extent")
		var right: Vector2i = expected_roi.position + Vector2i(240, 0)
		var bottom: Vector2i = expected_roi.position + Vector2i(0, 135)
		var corner: Vector2i = expected_roi.position + Vector2i(240, 135)
		var base_usec: int = Time.get_ticks_usec() + 100
		recorder.ingest_snapshot(_region_snapshot(1, base_usec, expected_roi, {
			expected_roi.position: 6, right: 23, bottom: 24, corner: 25,
		}, true))
		_expect(recorder._primed, "full publication did not prime the presented camera ROI")
		_expect(recorder._queue.size() == 1, "presented camera full frame was not retained")
		if recorder._queue.size() == 1:
			var first: PackedByteArray = recorder._queue[0].material_ids
			_expect(first.size() == expected_roi.size.x * expected_roi.size.y, "recorded frame omitted an edge row or column")
			_expect_recorded_cell(recorder, first, expected_roi.position, 6, "first visible cell")
			_expect_recorded_cell(recorder, first, right, 23, "partially visible right edge")
			_expect_recorded_cell(recorder, first, bottom, 24, "partially visible bottom edge")
			_expect_recorded_cell(recorder, first, corner, 25, "partially visible corner")

		# A session freezes its admitted integer ROI, even when the camera moves
		# and a newly requested configuration would use a different rectangle.
		host.camera_origin += Vector2(12.5, 8.5)
		_expect(host.recording_configuration().roi != expected_roi, "camera movement did not exercise a different default ROI")
		_expect(recorder._roi == admitted_roi, "camera movement changed the active recording ROI")
		recorder.ingest_snapshot(_region_snapshot(2, base_usec + 20000, Rect2i(corner, Vector2i.ONE), {corner: 28}, false))
		_expect(recorder._queue.size() == 2, "visible corner delta was not retained")
		if recorder._queue.size() == 2:
			_expect_recorded_cell(recorder, recorder._queue[0].material_ids, corner, 25, "immutable first corner frame")
			_expect_recorded_cell(recorder, recorder._queue[1].material_ids, corner, 28, "updated corner frame")
			var recorded_config: Dictionary = recorder._queue[1].metadata.recording_configuration
			_expect(recorded_config.roi == [expected_roi.position.x, expected_roi.position.y, 241, 136], "frame metadata did not preserve the fixed ROI")
			_expect(recorded_config.get("world_extent", []) == [extent.x, extent.y], "frame metadata lost the actual world extent")
		recorder.stop_recording()
		host.free()


func _test_recording_world_extents() -> void:
	var cases: Array[Dictionary] = [
		{"config": {}, "roi": Rect2i(0, 0, 1024, 1024), "extent": [1024, 1024]},
		{"config": {"world_extent": Vector2i(2048, 1536)},
			"roi": Rect2i(0, 0, 2048, 1536), "extent": [2048, 1536]},
		{"config": {"roi": Rect2i(1000, 1000, 100, 100)},
			"roi": Rect2i(1000, 1000, 24, 24), "extent": [1024, 1024]},
		{"config": {"roi": Rect2i(60, 45, 10, 10), "world_extent": Vector2i(64, 48)},
			"roi": Rect2i(60, 45, 4, 3), "extent": [64, 48]},
		{"config": {"roi": Rect2i(2000, 1500, 100, 80), "world_extent": Vector2i(2048, 1536)},
			"roi": Rect2i(2000, 1500, 48, 36), "extent": [2048, 1536]},
	]
	for entry: Dictionary in cases:
		var recorder = Recorder.new()
		var start_error: Error = recorder.start_recording(entry.config, {"source": "extent-test"}, false)
		_expect(start_error == OK, "valid recording world extent was rejected")
		_expect(recorder._roi == entry.roi, "recorder did not clamp ROI against its supplied or legacy world extent")
		_expect(recorder._config.get("world_extent", []) == entry.extent, "recording extent metadata disagrees with its admission bounds")
		recorder.stop_recording()
	for extent: Vector2i in [Vector2i(0, 48), Vector2i(64, 0), Vector2i(-1, 48), Vector2i(64, -1)]:
		var recorder = Recorder.new()
		var start_error: Error = recorder.start_recording({"world_extent": extent, "roi": Rect2i(0, 0, 4, 3)}, {}, false)
		_expect(start_error == ERR_INVALID_PARAMETER, "nonpositive recording extent was accepted: %s" % extent)
		_expect(not recorder.is_active(), "invalid recording extent opened an active session")
		recorder.stop_recording()


func _test_explicit_roi_override() -> void:
	# Separate invocation keeps process-wide CLI overrides out of the default
	# camera cases: -- --recording-roi-override-test
	# --record-roi=1000,700,100,120 --record-hz=120 --record-queue=0
	var host = _camera_host(Vector2(63.25, 31.75), Vector2i(240, 135), Vector2i(1050, 768))
	var config: Dictionary = host.recording_configuration()
	_expect(config.roi == Rect2i(1000, 700, 100, 120), "explicit CLI ROI did not override the presented camera bounds")
	_expect(int(config.capture_hz) == 60, "CLI recording cadence clamp changed")
	_expect(int(config.queue_capacity) == 1, "CLI recording queue clamp changed")
	_expect(config.get("world_extent", Vector2i.ZERO) == Vector2i(1050, 768), "CLI ROI override discarded actual world extent")
	var recorder = Recorder.new()
	var start_error: Error = recorder.start_recording(config, {"source": "cli-override-test"}, false)
	_expect(start_error == OK, "CLI ROI recording failed to start")
	_expect(recorder._roi == Rect2i(1000, 700, 50, 68), "CLI ROI was not clamped to the actual world bounds")
	_expect(recorder._config.get("world_extent", []) == [1050, 768], "CLI recording extent was not retained")
	host.camera_origin = Vector2(100.75, 80.25)
	_expect(host.recording_configuration().roi == Rect2i(1000, 700, 100, 120), "camera movement changed the explicit CLI ROI")
	recorder.stop_recording()
	host.free()


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
		"roi": Rect2i(10, 20, 4, 3),
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
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
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
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error(message)
