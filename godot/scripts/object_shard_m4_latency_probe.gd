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

var enabled: bool = false
var epoch: int = 1
var events: Array[Dictionary] = []
var _samples: Dictionary = {}
var _last_snapshot_serial: int = 0
var _last_upload: Dictionary = {}
var _last_worker_metrics: Dictionary = {}
var _presentation_count: int = 0
var _input_sequence: int = 0


func configure(requested: bool) -> void:
	enabled = requested


func retire(reason: String) -> void:
	if enabled:
		_append({"stage": "lifecycle", "reason": reason, "epoch": epoch,
			"time_usec": Time.get_ticks_usec()})
	epoch += 1
	_last_upload.clear()
	_last_snapshot_serial = 0


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
	if not enabled or snapshot == null or snapshot.serial <= _last_snapshot_serial:
		return
	_last_snapshot_serial = snapshot.serial
	var now_usec: int = observed_usec if observed_usec > 0 else Time.get_ticks_usec()
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
	if not enabled or _last_upload.is_empty() or int(_last_upload.epoch) != epoch:
		return {"ok": false, "outcome": "NoVisibleUpload"}
	var finished: int = now_usec if now_usec > 0 else Time.get_ticks_usec()
	if finished < int(_last_upload.completed_usec):
		return {"ok": false, "outcome": "InvalidPostDrawClock"}
	var observed: Dictionary = _last_upload.duplicate()
	_last_upload.clear()
	_presentation_count += 1
	record_duration("upload_to_post_draw", int(observed.completed_usec), finished,
		{"render_serial": observed.render_serial, "world_generation": observed.world_generation,
			"world_revision": observed.world_revision,
			"scope": "Godot_frame_post_draw_not_physical_scanout"})
	return {"ok": true, "outcome": "PostDrawObserved", "render_serial": observed.render_serial,
		"world_generation": observed.world_generation,
		"world_revision": observed.world_revision}


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
		"presented_uploads": _presentation_count, "stages": stages,
		"worker_metrics": _last_worker_metrics.duplicate(),
		"no_additive_stage_total": true,
		"input_to_post_draw_causally_proven": false,
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
	file.flush()
	file.close()
	return {"ok": true, "outcome": "BoundedTraceWritten",
		"events": events.size(), "path": user_path}


func _append(row: Dictionary) -> void:
	if events.size() >= MAX_EVENTS:
		events.pop_front()
	events.append(row.duplicate(true))
