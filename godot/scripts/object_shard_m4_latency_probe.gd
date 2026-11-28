class_name CyberObjectShardM4LatencyProbe
extends RefCounted

# Observational only. Stages are independently sampled and MUST NOT be added:
# worker reports and scene callbacks contain nested work, and worker/main
# operations may overlap. This probe never gates native or Rapier progression.
const STAGES: Array[String] = [
	"input_capture", "queue_admission", "native_execution", "receipt_delivery",
	"physics_work", "publication_prepare", "texture_upload_submission",
	"scene_callback", "upload_to_post_draw",
]
const MAX_EVENTS: int = 512
const MAX_STAGE_SAMPLES: int = 256
const MAX_CADENCE_COHORTS: int = 64

var enabled: bool = false
var epoch: int = 1
var events: Array[Dictionary] = []
var _samples: Dictionary = {}
var _last_snapshot_serial: int = 0
var _last_upload: Dictionary = {}
var _last_worker_metrics: Dictionary = {}
var _post_draw_candidate_count: int = 0
var _input_sequence: int = 0
var _workload: Dictionary = {"owned_material_bodies": 0, "paused": true, "camera": "unspecified"}
var _draw_cadence: Dictionary = {}
var _progress_cadence: Dictionary = {}
var _last_draw_usec: int = -1
var _last_draw_cohort: String = ""
var _last_progress_usec: int = -1
var _last_progress_tick: int = -1
var _last_progress_world: int = -1
var _last_progress_cohort: String = ""
var _snapshot_world: int = -1
var _cadence_capacity_drops: int = 0


func configure(requested: bool) -> void:
	if requested == enabled:
		return
	if requested:
		# Each explicit start is a fresh recording. Stopping preserves the
		# completed sample window for Save diagnostics without collecting more.
		epoch += 1
		events.clear()
		_samples.clear()
		_last_worker_metrics.clear()
		_last_upload.clear()
		_last_snapshot_serial = 0
		_snapshot_world = -1
		_post_draw_candidate_count = 0
		_input_sequence = 0
		_reset_cadence()
	else:
		_last_upload.clear()
	enabled = requested


func retire(reason: String) -> void:
	if enabled:
		_append({"stage": "lifecycle", "reason": reason, "epoch": epoch,
			"time_usec": Time.get_ticks_usec()})
	epoch += 1
	_last_upload.clear()
	_last_snapshot_serial = 0
	_snapshot_world = -1
	_reset_cadence()


# Main supplies only workload labels. These never advance native or physical
# time. A changed label breaks the interval so a pause, reset or camera switch
# cannot be folded into a different workload's measured rate.
func observe_workload(owned_material_bodies: int, paused: bool, camera: String) -> bool:
	if not enabled or owned_material_bodies < 0 or owned_material_bodies > 64 or camera.length() > 64:
		return false
	var next: Dictionary = {"owned_material_bodies": owned_material_bodies, "paused": paused, "camera": camera}
	if next != _workload:
		_last_draw_usec = -1
		_last_progress_usec = -1
	_workload = next
	return true


func _cohort() -> String:
	return "%d|%s|%s" % [int(_workload.owned_material_bodies), str(_workload.paused), str(_workload.camera)]


func _reset_cadence() -> void:
	_draw_cadence.clear()
	_progress_cadence.clear()
	_last_draw_usec = -1
	_last_draw_cohort = ""
	_last_progress_usec = -1
	_last_progress_tick = -1
	_last_progress_world = -1
	_last_progress_cohort = ""
	_cadence_capacity_drops = 0


func _cadence_sample(destination: Dictionary, key: String, duration: int, units: int) -> void:
	if duration <= 0 or units <= 0:
		return
	if not destination.has(key):
		if destination.size() >= MAX_CADENCE_COHORTS:
			_cadence_capacity_drops += 1
			return
		destination[key] = {"workload": _workload.duplicate(), "intervals": [],
			"interval_count": 0, "units": 0, "elapsed_usec": 0, "maximum_usec": 0}
	var row: Dictionary = destination[key]
	var values: Array = row.intervals
	if values.size() >= MAX_STAGE_SAMPLES:
		values.pop_front()
	values.append(duration)
	row.interval_count += 1
	row.units += units
	row.elapsed_usec += duration
	row.maximum_usec = maxi(int(row.maximum_usec), duration)


func _observe_progress(snapshot: CyberSimulationSnapshot, now_usec: int) -> void:
	var key: String = _cohort()
	var same_owner: bool = snapshot.render_world_generation == _last_progress_world
	if same_owner and _last_progress_usec >= 0 and now_usec <= _last_progress_usec:
		return
	if same_owner and snapshot.tick_index <= _last_progress_tick:
		# A fresh render publication without a semantic step is not progress.
		return
	if same_owner and key == _last_progress_cohort and _last_progress_usec >= 0 \
			and now_usec > _last_progress_usec and not bool(_workload.paused):
		_cadence_sample(_progress_cadence, key, now_usec - _last_progress_usec,
			snapshot.tick_index - _last_progress_tick)
	_last_progress_world = snapshot.render_world_generation
	_last_progress_tick = snapshot.tick_index
	_last_progress_usec = now_usec
	_last_progress_cohort = key


func _cadence_summary(source: Dictionary, units: String) -> Array:
	var rows: Array = []
	for key: String in source:
		var row: Dictionary = source[key]
		var sorted: Array = row.intervals.duplicate()
		sorted.sort()
		if sorted.is_empty():
			continue
		rows.append({"workload": row.workload.duplicate(), "interval_count": row.interval_count,
			"units": units, "units_observed": row.units, "elapsed_usec": row.elapsed_usec,
			"observed_units_per_second": float(row.units) * 1000000.0 / float(row.elapsed_usec),
			"recent_interval_samples": sorted.size(),
			"recent_p50_interval_usec": sorted[ceili(float(sorted.size()) * 0.50) - 1],
			"recent_p95_interval_usec": sorted[ceili(float(sorted.size()) * 0.95) - 1],
			"maximum_interval_usec": row.maximum_usec})
	return rows


func mark_input(position: Vector2i, operation: String, captured_usec: int = 0) -> int:
	if not enabled:
		return 0
	var now_usec: int = Time.get_ticks_usec()
	if captured_usec < 0 or captured_usec > now_usec:
		return 0
	_input_sequence += 1
	_append({"stage": "input_capture", "epoch": epoch, "input_id": _input_sequence,
		"time_usec": captured_usec if captured_usec > 0 else now_usec,
		"position": [position.x, position.y], "operation": operation,
		"causally_matched_to_native_receipt": false})
	return _input_sequence


func record_duration(stage: String, start_usec: int, end_usec: int,
		details: Dictionary = {}) -> bool:
	if not enabled or stage not in STAGES or start_usec < 0 or end_usec < start_usec:
		return false
	var duration: int = end_usec - start_usec
	var values: Array = _samples.get(stage, [])
	if values.size() >= MAX_STAGE_SAMPLES:
		values.pop_front()
	values.append(duration)
	_samples[stage] = values
	_append({"stage": stage, "epoch": epoch, "start_usec": start_usec,
		"end_usec": end_usec, "duration_usec": duration,
		"scope": "observed_duration_not_additive", "details": details.duplicate(true)})
	return true


# No fabricated "native execution" timing: the existing worker_step_time_ms
# encloses other worker-side activity and its substage metrics can overlap.
# Save the exact source-native worker fields with their actual scope.
func observe_snapshot(snapshot: CyberSimulationSnapshot, observed_usec: int = 0) -> void:
	if not enabled or snapshot == null:
		return
	if snapshot.render_world_generation != _snapshot_world:
		_snapshot_world = snapshot.render_world_generation
		_last_snapshot_serial = 0
	if snapshot.serial <= _last_snapshot_serial:
		return
	_last_snapshot_serial = snapshot.serial
	var now_usec: int = observed_usec if observed_usec > 0 else Time.get_ticks_usec()
	_observe_progress(snapshot, now_usec)
	_last_worker_metrics = {
		"worker_step_time_ms": snapshot.worker_step_time_ms,
		"snapshot_copy_time_ms": snapshot.snapshot_copy_time_ms,
		"render_exchange_time_ms": snapshot.render_exchange_time_ms,
		"hard_surface_packet_time_ms": snapshot.hard_surface_packet_time_ms,
		"snapshot_publication_time_ms": snapshot.snapshot_publication_time_ms,
		"snapshot_serial": snapshot.serial, "tick": snapshot.tick_index,
		"world_revision": snapshot.world_revision,
		"world_generation": snapshot.render_world_generation,
		"scope": "worker_reported_potentially_nested_not_a_sum",
	}
	_append({"stage": "worker_reported", "epoch": epoch,
		"observed_usec": now_usec, "values": _last_worker_metrics.duplicate()})
	if snapshot.published_usec > 0 and now_usec >= snapshot.published_usec:
		record_duration("receipt_delivery", snapshot.published_usec, now_usec,
			{"snapshot_serial": snapshot.serial,
			"scope": "snapshot_publication_to_main_observation_includes_queue_age"})


func record_native_receipt_stage(start_usec: int, finished_usec: int,
		native_receipt: Dictionary) -> bool:
	# This is available only after a same-World native receipt supplies two
	# actual monotonic timestamps bound to one operation. No synthetic default.
	if not native_receipt.get("same_world", false) \
			or not native_receipt.get("native_receipt_id") is int:
		return false
	return record_duration("native_execution", start_usec, finished_usec,
		{"native_receipt_id": native_receipt.native_receipt_id,
			"scope": "native_owned_execution_exclusive_of_admission_wait"})


func mark_upload(snapshot: CyberSimulationSnapshot, start_usec: int,
		end_usec: int, accepted: bool) -> void:
	if not enabled or snapshot == null:
		return
	record_duration("texture_upload_submission", start_usec, end_usec, {
		"render_serial": snapshot.render_snapshot_serial,
		"world_generation": snapshot.render_world_generation,
		"world_revision": snapshot.world_revision, "accepted": accepted,
		"scope": "main_thread_texture_submission_not_GPU_scanout"})
	if accepted and snapshot.render_snapshot_serial > 0:
		_last_upload = {"epoch": epoch, "render_serial": snapshot.render_snapshot_serial,
			"world_generation": snapshot.render_world_generation,
			"world_revision": snapshot.world_revision, "completed_usec": end_usec}


func observe_post_draw(now_usec: int = 0) -> Dictionary:
	if not enabled:
		return {"ok": false, "outcome": "ProbeDisabled"}
	var finished: int = now_usec if now_usec > 0 else Time.get_ticks_usec()
	var key: String = _cohort()
	if _last_draw_usec >= 0 and finished <= _last_draw_usec:
		return {"ok": false, "outcome": "InvalidPostDrawClock"}
	if key == _last_draw_cohort and _last_draw_usec >= 0:
		_cadence_sample(_draw_cadence, key, finished - _last_draw_usec, 1)
	_last_draw_usec = finished
	_last_draw_cohort = key
	if _last_upload.is_empty() or int(_last_upload.epoch) != epoch:
		return {"ok": false, "outcome": "NoVisibleUpload"}
	if finished < int(_last_upload.completed_usec):
		return {"ok": false, "outcome": "InvalidPostDrawClock"}
	var observed: Dictionary = _last_upload.duplicate()
	_last_upload.clear()
	_post_draw_candidate_count += 1
	record_duration("upload_to_post_draw", int(observed.completed_usec), finished,
		{"candidate_render_serial": observed.render_serial,
			"world_generation": observed.world_generation,
			"world_revision": observed.world_revision,
			"scope": "deferred_post_draw_callback_after_upload_no_exact_frame_identity",
			"causal_frame_identity_proven": false})
	# The signal carries no exact material/pose serial. It is not evidence of
	# completed presentation of this particular submission or GPU scanout.
	return {"ok": true, "outcome": "PostDrawCallbackObserved",
		"candidate_render_serial": observed.render_serial,
		"causal_frame_identity_proven": false}


func uploaded_identity() -> Dictionary:
	return _last_upload.duplicate()


func summary() -> Dictionary:
	var stages: Dictionary = {}
	for stage: String in STAGES:
		var values: Array = _samples.get(stage, [])
		if values.is_empty():
			continue
		var sorted: Array = values.duplicate()
		sorted.sort()
		var p50: int = mini(sorted.size() - 1, ceili(float(sorted.size()) * 0.50) - 1)
		var p95: int = mini(sorted.size() - 1, ceili(float(sorted.size()) * 0.95) - 1)
		stages[stage] = {"count": sorted.size(), "p50_usec": sorted[p50],
			"p95_usec": sorted[p95], "maximum_usec": sorted.back()}
	return {"schema": "objectshard-m4-workbench-latency-v1", "enabled": enabled,
		"epoch": epoch, "events_retained": events.size(),
		"post_draw_callbacks_after_upload": _post_draw_candidate_count,
		"proven_presented_uploads": 0, "stages": stages,
		"worker_metrics": _last_worker_metrics.duplicate(),
		"no_additive_stage_total": true,
		"input_to_post_draw_causally_proven": false,
		"frame_serial_coherence_proven": false,
		"cadence": {"display_backend": DisplayServer.get_name(),
			"render_scope": "headless_callback_only" if DisplayServer.get_name() == "headless" else "renderer_post_draw_callback",
			"hardware_present_verified": false,
			"body_count_scope": "owned material bodies including sleeping; no awake-body inference",
			"post_draw_intervals": _cadence_summary(_draw_cadence, "post_draw_callbacks"),
			"native_progress_delivery": _cadence_summary(_progress_cadence, "native_semantic_ticks"),
			"progress_scope": "main_observed_native_progress_may_coalesce_ticks_not_worker_execution_cadence",
			"percentile_scope": "most_recent_bounded_intervals_per_workload",
			"cohort_capacity": MAX_CADENCE_COHORTS,
			"capacity_dropped_intervals": _cadence_capacity_drops},
		"scope": "ordinary_Workbench_opt_in_main_thread_observation"}


# An explicit operator/test action only. No automatic disk writes during play.
func export_jsonl(user_path: String) -> Dictionary:
	if not enabled or not user_path.begins_with("user://"):
		return {"ok": false, "outcome": "DisabledOrUnsafePath"}
	var file: FileAccess = FileAccess.open(user_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "outcome": "FileOpenFailed"}
	for event: Dictionary in events:
		file.store_line(JSON.stringify(event))
	file.store_line(JSON.stringify({"stage": "summary", "epoch": epoch, "values": summary()}))
	file.flush()
	file.close()
	return {"ok": true, "outcome": "BoundedTraceWritten",
		"events": events.size(), "summary_records": 1, "path": user_path}


func _append(row: Dictionary) -> void:
	if events.size() >= MAX_EVENTS:
		events.pop_front()
	events.append(row.duplicate(true))
