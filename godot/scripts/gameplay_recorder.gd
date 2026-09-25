extends RefCounted

# REC-001 desktop gameplay evidence recorder.
#
# The recorder consumes only immutable CyberSimulationSnapshot publications. It
# never owns or queries mutable World state. Material render patches are folded
# into a private ROI buffer on the presentation thread, then copied into a
# bounded single-producer queue. A dedicated writer thread performs JSON/BMP/raw
# encoding and disk I/O. Queue pressure drops capture attempts, never simulation
# ticks.
const SCHEMA_ID: String = "cybersand-state-recording-v1"
const EVIDENCE_KIND: String = "simulation-state-evidence-not-exact-replay"
const DEFAULT_CAPTURE_HZ: int = 15
const DEFAULT_QUEUE_CAPACITY: int = 8
const MAX_QUEUE_CAPACITY: int = 64
const DROP_EVENT_LIMIT: int = 256
const RENDER_PATCH_METADATA_STRIDE: int = 6
const PLAYER_PALETTE_INDEX: int = 255
const BODY_PALETTE_INDEX: int = 254
const BMP_PALETTE_ENTRIES: int = 256
const BMP_HEADER_BYTES: int = 14 + 40 + BMP_PALETTE_ENTRIES * 4

var _mutex: Mutex = Mutex.new()
var _writer_semaphore: Semaphore = Semaphore.new()
var _writer_thread: Thread = Thread.new()
var _queue: Array[Dictionary] = []

var _active: bool = false
var _accepting: bool = false
var _writer_enabled: bool = true
var _stop_requested: bool = false
var _failed: bool = false
var _failure_reason: String = ""
var _incomplete_reason: String = ""

var _roi: Rect2i = Rect2i()
var _roi_material_ids: PackedByteArray = PackedByteArray()
var _capture_hz: int = DEFAULT_CAPTURE_HZ
var _capture_interval_usec: int = 66667
var _queue_capacity: int = DEFAULT_QUEUE_CAPACITY
var _retain_raw_ids: bool = true
var _output_root: String = "user://recordings"
var _session_name: String = ""
var _session_path: String = ""
var _identity: Dictionary = {}
var _config: Dictionary = {}

var _start_monotonic_usec: int = 0
var _start_wall_unix_usec: int = 0
var _start_wall_utc: String = ""
var _next_capture_usec: int = 0
var _last_render_snapshot_serial: int = 0
var _primed: bool = false

var _capture_attempts: int = 0
var _enqueued_frames: int = 0
var _written_frames: int = 0
var _dropped_frames: int = 0
var _queue_high_water: int = 0
var _drop_events: Array[Dictionary] = []
var _drop_events_omitted: int = 0
var _render_publications_observed: int = 0
var _patch_apply_usec_total: int = 0
var _patch_apply_usec_max: int = 0
var _capture_copy_usec_total: int = 0
var _capture_copy_usec_max: int = 0
var _write_usec_total: int = 0
var _write_usec_max: int = 0


func start_recording(
		config: Dictionary,
		identity: Dictionary,
		writer_enabled: bool = true
) -> Error:
	if is_active():
		return ERR_ALREADY_IN_USE

	_reset_session_state()
	var requested_roi: Rect2i = config.get(
		"roi",
		Rect2i(0, 0, CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT)
	)
	var left: int = clampi(requested_roi.position.x, 0, CyberCellWorld.WORLD_WIDTH - 1)
	var top: int = clampi(requested_roi.position.y, 0, CyberCellWorld.WORLD_HEIGHT - 1)
	var right: int = clampi(
		requested_roi.position.x + maxi(requested_roi.size.x, 1),
		left + 1,
		CyberCellWorld.WORLD_WIDTH
	)
	var bottom: int = clampi(
		requested_roi.position.y + maxi(requested_roi.size.y, 1),
		top + 1,
		CyberCellWorld.WORLD_HEIGHT
	)
	_roi = Rect2i(left, top, right - left, bottom - top)
	_roi_material_ids.resize(_roi.size.x * _roi.size.y)
	_roi_material_ids.fill(0)

	_capture_hz = clampi(int(config.get("capture_hz", DEFAULT_CAPTURE_HZ)), 1, 60)
	_capture_interval_usec = maxi(1, roundi(1000000.0 / float(_capture_hz)))
	_queue_capacity = clampi(
		int(config.get("queue_capacity", DEFAULT_QUEUE_CAPACITY)),
		1,
		MAX_QUEUE_CAPACITY
	)
	_retain_raw_ids = bool(config.get("retain_raw_ids", true))
	_output_root = str(config.get("output_root", "user://recordings"))
	_session_name = str(config.get("session_name", "")).strip_edges()
	if _session_name.is_empty():
		_session_name = _default_session_name()
	_session_path = _output_root.path_join(_session_name)
	_identity = identity.duplicate(true)
	_config = {
		"capture_hz": _capture_hz,
		"capture_interval_usec": _capture_interval_usec,
		"queue_capacity": _queue_capacity,
		"roi": [_roi.position.x, _roi.position.y, _roi.size.x, _roi.size.y],
		"retain_raw_ids": _retain_raw_ids,
		"material_channels_retained": ["material_id"],
		"visual_condition_channel": "intentionally omitted in REC-001 v1",
		"temperature_state": "unavailable from immutable render publication; omitted",
	}
	_start_monotonic_usec = Time.get_ticks_usec()
	_start_wall_unix_usec = roundi(Time.get_unix_time_from_system() * 1000000.0)
	_start_wall_utc = Time.get_datetime_string_from_system(true)
	_next_capture_usec = _start_monotonic_usec
	_writer_enabled = writer_enabled
	_active = true
	_accepting = true

	if not writer_enabled:
		return OK

	var absolute_session: String = ProjectSettings.globalize_path(_session_path)
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_session)
	if mkdir_error != OK:
		_failed = true
		_failure_reason = "could not create recording directory: error %d" % int(mkdir_error)
		_incomplete_reason = _failure_reason
		_accepting = false
		_active = false
		return mkdir_error

	var start_manifest_error: String = _write_manifest_file("recording")
	if not start_manifest_error.is_empty():
		_failed = true
		_failure_reason = start_manifest_error
		_incomplete_reason = start_manifest_error
		_accepting = false
		_active = false
		return ERR_CANT_CREATE

	var thread_error: Error = _writer_thread.start(Callable(self, "_writer_loop"))
	if thread_error != OK:
		_failed = true
		_failure_reason = "could not start recording writer thread: error %d" % int(thread_error)
		_incomplete_reason = _failure_reason
		_accepting = false
		_stop_requested = true
		_write_manifest_file("incomplete")
		_active = false
		return thread_error

	return OK


func stop_recording(reason: String = "") -> Dictionary:
	_mutex.lock()
	if not _active:
		var inactive_status: Dictionary = _status_locked()
		_mutex.unlock()
		return inactive_status
	_accepting = false
	if not reason.is_empty() and _incomplete_reason.is_empty():
		_incomplete_reason = reason
	_stop_requested = true
	_mutex.unlock()

	if _writer_enabled:
		_writer_semaphore.post()
		if _writer_thread.is_started():
			_writer_thread.wait_to_finish()
	else:
		_mutex.lock()
		_queue.clear()
		_mutex.unlock()

	_mutex.lock()
	_active = false
	var result: Dictionary = _status_locked()
	_mutex.unlock()
	return result


func is_active() -> bool:
	_mutex.lock()
	var result: bool = _active
	_mutex.unlock()
	return result


func has_failed() -> bool:
	_mutex.lock()
	var result: bool = _failed
	_mutex.unlock()
	return result


func status() -> Dictionary:
	_mutex.lock()
	var result: Dictionary = _status_locked()
	_mutex.unlock()
	return result


func session_path() -> String:
	_mutex.lock()
	var result: String = _session_path
	_mutex.unlock()
	return result


func ingest_snapshot(snapshot: CyberSimulationSnapshot) -> void:
	if snapshot == null:
		return
	_mutex.lock()
	var accepting: bool = _accepting
	_mutex.unlock()
	if not accepting:
		return

	if snapshot.simulation_failed:
		_mark_incomplete_and_stop(
			"simulation failed at attempted tick %d; last retained completed tick %d" % [
				snapshot.failed_tick_index,
				snapshot.tick_index,
			],
			false
		)
		return

	var render_advanced: bool = false
	if (
		snapshot.render_snapshot_serial > 0
		and snapshot.render_snapshot_serial > _last_render_snapshot_serial
	):
		var patch_started: int = Time.get_ticks_usec()
		var patch_error: String = _apply_render_publication(snapshot)
		var patch_usec: int = Time.get_ticks_usec() - patch_started
		_mutex.lock()
		_render_publications_observed += 1
		_patch_apply_usec_total += patch_usec
		_patch_apply_usec_max = maxi(_patch_apply_usec_max, patch_usec)
		_mutex.unlock()
		if not patch_error.is_empty():
			_mark_incomplete_and_stop(patch_error, true)
			return
		_last_render_snapshot_serial = snapshot.render_snapshot_serial
		render_advanced = true

	# One evidence frame belongs to one immutable render generation. Later worker
	# snapshots may legitimately carry the same material payload with a newer
	# simulation tick; those must not relabel or duplicate the material frame.
	if not _primed or not render_advanced:
		return

	var render_usec: int = snapshot.render_generated_usec
	if render_usec <= 0:
		render_usec = snapshot.published_usec
	if render_usec < _next_capture_usec:
		return
	while _next_capture_usec <= render_usec:
		_next_capture_usec += _capture_interval_usec

	_capture_attempts += 1
	_mutex.lock()
	if _queue.size() >= _queue_capacity:
		_record_drop_locked(snapshot, "queue-full")
		_mutex.unlock()
		return
	_mutex.unlock()

	var copy_started: int = Time.get_ticks_usec()
	var material_copy: PackedByteArray = _roi_material_ids.duplicate()
	var metadata: Dictionary = _frame_metadata(snapshot)
	var copy_usec: int = Time.get_ticks_usec() - copy_started

	_mutex.lock()
	# There is only one producer. The writer can only drain between the earlier
	# capacity check and this append, so this cannot become fuller in between.
	if _queue.size() >= _queue_capacity:
		_record_drop_locked(snapshot, "queue-full-after-copy")
		_mutex.unlock()
		return
	_enqueued_frames += 1
	var frame_index: int = _enqueued_frames
	metadata["frame_index"] = frame_index
	_queue.append({
		"frame_index": frame_index,
		"material_ids": material_copy,
		"metadata": metadata,
	})
	_queue_high_water = maxi(_queue_high_water, _queue.size())
	_capture_copy_usec_total += copy_usec
	_capture_copy_usec_max = maxi(_capture_copy_usec_max, copy_usec)
	_mutex.unlock()
	if _writer_enabled:
		_writer_semaphore.post()


func _apply_render_publication(snapshot: CyberSimulationSnapshot) -> String:
	var rectangles: PackedInt32Array = snapshot.render_patch_rectangles
	var payload: PackedByteArray = snapshot.render_patch_cells
	var channels: int = snapshot.render_channels
	if channels != 1 and channels != 2:
		return "recorder rejected render publication with unsupported channel count %d" % channels
	if rectangles.is_empty():
		return "recorder rejected render publication with empty patch metadata"
	if rectangles.size() % RENDER_PATCH_METADATA_STRIDE != 0:
		return "recorder rejected malformed render patch metadata"
	if payload.is_empty():
		return "recorder rejected render publication with empty payload"

	var full_refresh_covers_roi: bool = false
	for offset: int in range(0, rectangles.size(), RENDER_PATCH_METADATA_STRIDE):
		var patch_x: int = rectangles[offset]
		var patch_y: int = rectangles[offset + 1]
		var patch_width: int = rectangles[offset + 2]
		var patch_height: int = rectangles[offset + 3]
		var data_offset: int = rectangles[offset + 4]
		var row_stride: int = rectangles[offset + 5]
		if patch_width <= 0 or patch_height <= 0 or data_offset < 0 or row_stride <= 0:
			return "recorder rejected invalid render patch geometry"
		var required_end: int = (
			data_offset
			+ (patch_height - 1) * row_stride
			+ patch_width * channels
		)
		if required_end > payload.size():
			return "recorder rejected truncated render patch payload"

		if (
			patch_x <= _roi.position.x
			and patch_y <= _roi.position.y
			and patch_x + patch_width >= _roi.position.x + _roi.size.x
			and patch_y + patch_height >= _roi.position.y + _roi.size.y
		):
			full_refresh_covers_roi = true

		var x0: int = maxi(patch_x, _roi.position.x)
		var y0: int = maxi(patch_y, _roi.position.y)
		var x1: int = mini(patch_x + patch_width, _roi.position.x + _roi.size.x)
		var y1: int = mini(patch_y + patch_height, _roi.position.y + _roi.size.y)
		if x0 >= x1 or y0 >= y1:
			continue
		for world_y: int in range(y0, y1):
			var source_row: int = data_offset + (world_y - patch_y) * row_stride
			var target_row: int = (world_y - _roi.position.y) * _roi.size.x
			for world_x: int in range(x0, x1):
				var source_index: int = source_row + (world_x - patch_x) * channels
				var target_index: int = target_row + (world_x - _roi.position.x)
				_roi_material_ids[target_index] = payload[source_index]

	if snapshot.render_full_refresh and full_refresh_covers_roi:
		_primed = true
	return ""


func _frame_metadata(snapshot: CyberSimulationSnapshot) -> Dictionary:
	var context: Dictionary = (
		snapshot.render_context
		if not snapshot.render_context.is_empty()
		else snapshot.lab_context
	)
	var micro: Dictionary = context.get("microscenario", {})
	var presentation: Dictionary = micro.get("presentation", {})
	var profile: Dictionary = context.get("profile", {})
	var bodies: Array[Dictionary] = []
	var body_states: PackedFloat32Array = snapshot.render_rigid_body_states
	var stride: int = CyberRigidBodyCoupling.INPUT_STRIDE
	for offset: int in range(0, body_states.size() - stride + 1, stride):
		bodies.append({
			"id": roundi(body_states[offset + CyberRigidBodyCoupling.INPUT_BODY_ID]),
			"center": [
				body_states[offset + CyberRigidBodyCoupling.INPUT_CENTER_X],
				body_states[offset + CyberRigidBodyCoupling.INPUT_CENTER_Y],
			],
			"rotation_radians": body_states[offset + CyberRigidBodyCoupling.INPUT_ROTATION],
			"extent": [
				body_states[offset + CyberRigidBodyCoupling.INPUT_SIZE_X],
				body_states[offset + CyberRigidBodyCoupling.INPUT_SIZE_Y],
			],
			"linear_velocity": [
				body_states[offset + CyberRigidBodyCoupling.INPUT_VELOCITY_X],
				body_states[offset + CyberRigidBodyCoupling.INPUT_VELOCITY_Y],
			],
			"angular_velocity": body_states[offset + CyberRigidBodyCoupling.INPUT_ANGULAR_VELOCITY],
			"mass": body_states[offset + CyberRigidBodyCoupling.INPUT_MASS],
			"sample_serial": roundi(body_states[offset + CyberRigidBodyCoupling.INPUT_SAMPLE_SERIAL]),
		})

	var render_usec: int = snapshot.render_generated_usec
	if render_usec <= 0:
		render_usec = snapshot.published_usec
	var render_tick: int = snapshot.render_tick_index
	if render_tick <= 0:
		render_tick = snapshot.tick_index
	var player_position: Vector2 = snapshot.render_character_position
	var player_velocity: Vector2 = snapshot.render_character_velocity
	var player_grounded: bool = snapshot.render_character_grounded
	var elapsed_usec: int = maxi(0, render_usec - _start_monotonic_usec)
	var source_identity: Dictionary = {}
	var source_value: Variant = _identity.get("source", {})
	if source_value is Dictionary:
		source_identity = source_value
	var native_identity: Dictionary = {}
	var native_value: Variant = _identity.get("native_runtime", {})
	if native_value is Dictionary:
		native_identity = native_value
	return {
		"schema_id": SCHEMA_ID,
		"evidence_kind": EVIDENCE_KIND,
		"snapshot_serial": snapshot.serial,
		"render_snapshot_serial": snapshot.render_snapshot_serial,
		"completed_simulation_tick": render_tick,
		"render_generated_monotonic_usec": render_usec,
		"consumer_snapshot_tick": snapshot.tick_index,
		"consumer_snapshot_published_monotonic_usec": snapshot.published_usec,
		"elapsed_monotonic_usec": elapsed_usec,
		"wall_unix_usec_estimate": _start_wall_unix_usec + elapsed_usec,
		"world_revision": snapshot.world_revision,
		"backend": snapshot.backend_name,
		"worker_count": snapshot.scheduler_thread_capacity_hint,
		"simulation_time_ms": snapshot.render_simulation_time_ms,
		"worker_step_time_ms": snapshot.render_worker_step_time_ms,
		"worker_overruns": snapshot.render_worker_overruns,
		"render_publication": {
			"serial": snapshot.render_snapshot_serial,
			"channels": snapshot.render_channels,
			"full_refresh": snapshot.render_full_refresh,
			"patch_count": snapshot.render_patch_rectangles.size() / RENDER_PATCH_METADATA_STRIDE,
			"payload_bytes": snapshot.render_patch_cells.size(),
		},
		"player": {
			"representation": "sampled-character",
			"origin": [player_position.x, player_position.y],
			"extent": [CyberSampledCharacter.BODY_SIZE.x, CyberSampledCharacter.BODY_SIZE.y],
			"velocity": [player_velocity.x, player_velocity.y],
			"grounded": player_grounded,
		},
		"rigid_bodies": bodies,
		"scenario": {
			"active": bool(context.get("micro_active", false)),
			"id": str(micro.get("id", "")),
			"definition_hash": str(micro.get("definition_hash", "")),
			"source_recipe": str(micro.get("source_recipe", "")),
			"source_recipe_hash": str(micro.get("source_recipe_hash", "")),
			"seed": int(micro.get("seed", 0)),
			"mode": str(micro.get("mode", "")),
			"tuning_profile": str(presentation.get("profile", "")),
		},
		"transport_profile": {
			"name": str(profile.get("name", "")),
			"hash": str(context.get("profile_hash", "")),
		},
		"water_policy_hash": str(context.get("water_policy_hash", "")),
		"recording_configuration": _config.duplicate(true),
		"recording_roi": [_roi.position.x, _roi.position.y, _roi.size.x, _roi.size.y],
		"session_identity": {
			"source_revision": str(source_identity.get("source_revision", "unavailable")),
			"source_revision_status": str(source_identity.get("revision_status", "unavailable")),
			"script_set_sha256": str(source_identity.get("script_set_sha256", "unavailable")),
			"native_sha256": str(source_identity.get("native_sha256", "unavailable")),
			"platform": str(source_identity.get("platform", "unavailable")),
			"godot": str(source_identity.get("godot", "unavailable")),
			"runtime_source_commit": str(native_identity.get("source_commit", "unavailable")),
			"runtime_artifact_sha256": str(native_identity.get("sha256", "unavailable")),
		},
	}

func _record_drop_locked(snapshot: CyberSimulationSnapshot, reason: String) -> void:
	_dropped_frames += 1
	var render_usec: int = snapshot.render_generated_usec
	if render_usec <= 0:
		render_usec = snapshot.published_usec
	var render_tick: int = snapshot.render_tick_index
	if render_tick <= 0:
		render_tick = snapshot.tick_index
	var event: Dictionary = {
		"attempt": _capture_attempts,
		"reason": reason,
		"render_snapshot_serial": snapshot.render_snapshot_serial,
		"completed_simulation_tick": render_tick,
		"render_generated_monotonic_usec": render_usec,
		"consumer_snapshot_published_monotonic_usec": snapshot.published_usec,
		"capture_observed_monotonic_usec": Time.get_ticks_usec(),
	}
	if _drop_events.size() < DROP_EVENT_LIMIT:
		_drop_events.append(event)
	else:
		_drop_events_omitted += 1

func _writer_loop() -> void:
	while true:
		_writer_semaphore.wait()
		var job: Dictionary = {}
		var should_stop: bool = false
		_mutex.lock()
		if not _queue.is_empty():
			job = _queue.pop_front()
		should_stop = _stop_requested and _queue.is_empty() and job.is_empty()
		_mutex.unlock()

		if not job.is_empty():
			var write_started: int = Time.get_ticks_usec()
			var write_error: String = _write_frame(job)
			var write_usec: int = Time.get_ticks_usec() - write_started
			_mutex.lock()
			_write_usec_total += write_usec
			_write_usec_max = maxi(_write_usec_max, write_usec)
			if write_error.is_empty():
				_written_frames += 1
			_mutex.unlock()
			if not write_error.is_empty():
				_mark_incomplete_and_stop(write_error, true)
			continue

		if should_stop:
			break

	var disposition: String = _final_disposition()
	var final_error: String = _write_manifest_file(disposition)
	if not final_error.is_empty():
		_mutex.lock()
		_failed = true
		if _failure_reason.is_empty():
			_failure_reason = final_error
		if _incomplete_reason.is_empty():
			_incomplete_reason = final_error
		_mutex.unlock()


func _write_frame(job: Dictionary) -> String:
	var frame_index: int = int(job.frame_index)
	var base_name: String = "frame-%06d" % frame_index
	var ids: PackedByteArray = job.material_ids
	var metadata: Dictionary = job.metadata.duplicate(true)

	if _retain_raw_ids:
		var ids_name: String = base_name + ".ids"
		var ids_error: String = _write_binary_file(_session_path.path_join(ids_name), ids)
		if not ids_error.is_empty():
			return ids_error
		metadata["material_ids_file"] = ids_name
		metadata["material_ids_layout"] = "row-major top-down uint8 serialized material IDs"

	var display_ids: PackedByteArray = ids.duplicate()
	_draw_review_overlays(display_ids, metadata)
	var bmp_name: String = base_name + ".bmp"
	var bmp_error: String = _write_indexed_bmp(
		_session_path.path_join(bmp_name),
		display_ids
	)
	if not bmp_error.is_empty():
		return bmp_error
	metadata["review_bitmap_file"] = bmp_name
	metadata["review_bitmap_note"] = (
		"8-bit indexed BMP; material palette indices equal serialized material IDs; "
		+ "index 255 is sampled-player outline and 254 is an axis-aligned rigid-body "
		+ "review outline; exact rigid-body rotation remains in JSON metadata"
	)

	var json_name: String = base_name + ".json"
	var json_error: String = _write_text_file(
		_session_path.path_join(json_name),
		JSON.stringify(metadata, "  ") + "\n"
	)
	if not json_error.is_empty():
		return json_error
	return ""


func _draw_review_overlays(display_ids: PackedByteArray, metadata: Dictionary) -> void:
	var player: Dictionary = metadata.get("player", {})
	var player_origin: Array = player.get("origin", [])
	var player_extent: Array = player.get("extent", [])
	if player_origin.size() == 2 and player_extent.size() == 2:
		_draw_world_rect_outline(
			display_ids,
			float(player_origin[0]),
			float(player_origin[1]),
			float(player_extent[0]),
			float(player_extent[1]),
			PLAYER_PALETTE_INDEX
		)
	for body_variant: Variant in metadata.get("rigid_bodies", []):
		if not body_variant is Dictionary:
			continue
		var body: Dictionary = body_variant
		var center: Array = body.get("center", [])
		var extent: Array = body.get("extent", [])
		if center.size() != 2 or extent.size() != 2:
			continue
		_draw_world_rect_outline(
			display_ids,
			float(center[0]) - float(extent[0]) * 0.5,
			float(center[1]) - float(extent[1]) * 0.5,
			float(extent[0]),
			float(extent[1]),
			BODY_PALETTE_INDEX
		)


func _draw_world_rect_outline(
		display_ids: PackedByteArray,
		world_x: float,
		world_y: float,
		width: float,
		height: float,
		palette_index: int
) -> void:
	var x0: int = floori(world_x) - _roi.position.x
	var y0: int = floori(world_y) - _roi.position.y
	var x1: int = ceili(world_x + width) - 1 - _roi.position.x
	var y1: int = ceili(world_y + height) - 1 - _roi.position.y
	if x1 < 0 or y1 < 0 or x0 >= _roi.size.x or y0 >= _roi.size.y:
		return
	x0 = clampi(x0, 0, _roi.size.x - 1)
	y0 = clampi(y0, 0, _roi.size.y - 1)
	x1 = clampi(x1, 0, _roi.size.x - 1)
	y1 = clampi(y1, 0, _roi.size.y - 1)
	for x: int in range(x0, x1 + 1):
		display_ids[y0 * _roi.size.x + x] = palette_index
		display_ids[y1 * _roi.size.x + x] = palette_index
	for y: int in range(y0, y1 + 1):
		display_ids[y * _roi.size.x + x0] = palette_index
		display_ids[y * _roi.size.x + x1] = palette_index


func _write_indexed_bmp(path: String, display_ids: PackedByteArray) -> String:
	var width: int = _roi.size.x
	var height: int = _roi.size.y
	if display_ids.size() != width * height:
		return "recording frame material buffer has unexpected size"
	var row_stride: int = (width + 3) & ~3
	var image_bytes: int = row_stride * height
	var file_size: int = BMP_HEADER_BYTES + image_bytes
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(file_size)

	bytes[0] = 0x42
	bytes[1] = 0x4D
	_put_u32_le(bytes, 2, file_size)
	_put_u32_le(bytes, 10, BMP_HEADER_BYTES)
	_put_u32_le(bytes, 14, 40)
	_put_u32_le(bytes, 18, width)
	_put_u32_le(bytes, 22, height)
	_put_u16_le(bytes, 26, 1)
	_put_u16_le(bytes, 28, 8)
	_put_u32_le(bytes, 34, image_bytes)
	_put_u32_le(bytes, 38, 2835)
	_put_u32_le(bytes, 42, 2835)
	_put_u32_le(bytes, 46, BMP_PALETTE_ENTRIES)
	_put_u32_le(bytes, 50, BMP_PALETTE_ENTRIES)

	var palette: Array[int] = CyberMaterialAppearanceLut.BASE_RGBA8
	for index: int in range(BMP_PALETTE_ENTRIES):
		var rgba: int = 0xFF00FFFF
		if index < palette.size():
			rgba = palette[index]
		if index == BODY_PALETTE_INDEX:
			rgba = 0x37F3E4FF
		elif index == PLAYER_PALETTE_INDEX:
			rgba = 0xFFFFFFFF
		var palette_offset: int = 54 + index * 4
		bytes[palette_offset] = (rgba >> 8) & 0xFF
		bytes[palette_offset + 1] = (rgba >> 16) & 0xFF
		bytes[palette_offset + 2] = (rgba >> 24) & 0xFF
		bytes[palette_offset + 3] = 0

	for file_y: int in range(height):
		var source_y: int = height - 1 - file_y
		var target_row: int = BMP_HEADER_BYTES + file_y * row_stride
		var source_row: int = source_y * width
		for x: int in range(width):
			bytes[target_row + x] = display_ids[source_row + x]

	return _write_binary_file(path, bytes)


static func _put_u16_le(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xFF
	bytes[offset + 1] = (value >> 8) & 0xFF


static func _put_u32_le(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xFF
	bytes[offset + 1] = (value >> 8) & 0xFF
	bytes[offset + 2] = (value >> 16) & 0xFF
	bytes[offset + 3] = (value >> 24) & 0xFF


func _write_binary_file(path: String, bytes: PackedByteArray) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not open recording output for write: " + path
	file.store_buffer(bytes)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return "recording write failed for %s: error %d" % [path, int(error)]
	return ""


func _write_text_file(path: String, text: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not open recording metadata for write: " + path
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return "recording metadata write failed for %s: error %d" % [path, int(error)]
	return ""


func _write_manifest_file(disposition: String) -> String:
	var payload: Dictionary = _manifest_payload(disposition)
	return _write_text_file(
		_session_path.path_join("recording.json"),
		JSON.stringify(payload, "  ") + "\n"
	)


func _manifest_payload(disposition: String) -> Dictionary:
	_mutex.lock()
	var drops: Array[Dictionary] = _drop_events.duplicate(true)
	var payload: Dictionary = {
		"schema_id": SCHEMA_ID,
		"schema_version": 1,
		"evidence_kind": EVIDENCE_KIND,
		"disposition": disposition,
		"incomplete_reason": _incomplete_reason,
		"failure": _failed,
		"failure_reason": _failure_reason,
		"session": {
			"name": _session_name,
			"path": _session_path,
			"start_utc": _start_wall_utc,
			"start_wall_unix_usec": _start_wall_unix_usec,
			"start_monotonic_usec": _start_monotonic_usec,
			"end_utc": Time.get_datetime_string_from_system(true),
			"end_monotonic_usec": Time.get_ticks_usec(),
		},
		"configuration": _config.duplicate(true),
		"identity": _identity.duplicate(true),
		"material_palette": {
			"encoding": "RGBA8 integers 0xRRGGBBAA indexed by serialized material ID",
			"rgba8": CyberMaterialAppearanceLut.BASE_RGBA8.duplicate(),
			"review_overlay_indices": {
				"rigid_body": BODY_PALETTE_INDEX,
				"sampled_player": PLAYER_PALETTE_INDEX,
			},
		},
		"state_scope": {
			"material_ids": "retained for every written frame",
			"player": "sampled-character position/extent/velocity/grounded",
			"rigid_bodies": "copied owner input transform/extent/velocity/mass/sample serial",
			"temperature": "unavailable from immutable render publication; not fabricated",
			"visual_condition_channel": "intentionally omitted in REC-001 v1",
			"replay": "not an exact replay stream",
		},
		"counters": {
			"render_publications_observed": _render_publications_observed,
			"capture_attempts": _capture_attempts,
			"enqueued_frames": _enqueued_frames,
			"written_frames": _written_frames,
			"dropped_frames": _dropped_frames,
			"queue_high_water": _queue_high_water,
			"queue_capacity": _queue_capacity,
			"render_patch_apply_usec_total": _patch_apply_usec_total,
			"render_patch_apply_usec_max": _patch_apply_usec_max,
			"capture_copy_usec_total": _capture_copy_usec_total,
			"capture_copy_usec_max": _capture_copy_usec_max,
			"writer_write_usec_total": _write_usec_total,
			"writer_write_usec_max": _write_usec_max,
		},
		"drops": {
			"retained": drops,
			"retention_limit": DROP_EVENT_LIMIT,
			"omitted_count": _drop_events_omitted,
		},
	}
	_mutex.unlock()
	return payload


func _final_disposition() -> String:
	_mutex.lock()
	var incomplete: bool = (
		_failed
		or not _incomplete_reason.is_empty()
		or _written_frames == 0
	)
	if _written_frames == 0 and _incomplete_reason.is_empty():
		_incomplete_reason = "stopped before any frame was written"
	var result: String = "incomplete" if incomplete else "complete"
	_mutex.unlock()
	return result


func _mark_incomplete_and_stop(reason: String, recorder_failure: bool) -> void:
	var should_post: bool = false
	_mutex.lock()
	if _incomplete_reason.is_empty():
		_incomplete_reason = reason
	if recorder_failure:
		_failed = true
		if _failure_reason.is_empty():
			_failure_reason = reason
	_accepting = false
	if not _stop_requested:
		_stop_requested = true
		should_post = _writer_enabled
	_mutex.unlock()
	if should_post:
		_writer_semaphore.post()


func _status_locked() -> Dictionary:
	return {
		"active": _active,
		"accepting": _accepting,
		"primed": _primed,
		"failed": _failed,
		"failure_reason": _failure_reason,
		"incomplete_reason": _incomplete_reason,
		"session_path": _session_path,
		"capture_hz": _capture_hz,
		"queue_capacity": _queue_capacity,
		"queued_frames": _queue.size(),
		"queue_high_water": _queue_high_water,
		"render_publications_observed": _render_publications_observed,
		"capture_attempts": _capture_attempts,
		"enqueued_frames": _enqueued_frames,
		"written_frames": _written_frames,
		"dropped_frames": _dropped_frames,
		"render_patch_apply_usec_total": _patch_apply_usec_total,
		"render_patch_apply_usec_max": _patch_apply_usec_max,
		"capture_copy_usec_total": _capture_copy_usec_total,
		"capture_copy_usec_max": _capture_copy_usec_max,
		"writer_write_usec_total": _write_usec_total,
		"writer_write_usec_max": _write_usec_max,
	}


func _default_session_name() -> String:
	var stamp: String = Time.get_datetime_string_from_system(true)
	for token: String in ["-", ":", "T", "Z", " "]:
		stamp = stamp.replace(token, "")
	return "cybersand-%s-%d" % [stamp, Time.get_ticks_usec()]


func _reset_session_state() -> void:
	_queue.clear()
	_active = false
	_accepting = false
	_stop_requested = false
	_failed = false
	_failure_reason = ""
	_incomplete_reason = ""
	_roi = Rect2i()
	_roi_material_ids = PackedByteArray()
	_identity = {}
	_config = {}
	_start_monotonic_usec = 0
	_start_wall_unix_usec = 0
	_start_wall_utc = ""
	_next_capture_usec = 0
	_last_render_snapshot_serial = 0
	_primed = false
	_render_publications_observed = 0
	_patch_apply_usec_total = 0
	_patch_apply_usec_max = 0
	_capture_attempts = 0
	_enqueued_frames = 0
	_written_frames = 0
	_dropped_frames = 0
	_queue_high_water = 0
	_drop_events.clear()
	_drop_events_omitted = 0
	_capture_copy_usec_total = 0
	_capture_copy_usec_max = 0
	_write_usec_total = 0
	_write_usec_max = 0
