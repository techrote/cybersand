extends SceneTree

# Value-only timing contract. Synthetic clocks test bookkeeping, not Rapier,
# native execution, real mouse latency or real rendered presentation.
const Probe = preload("res://scripts/object_shard_m4_latency_probe.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var probe: CyberObjectShardM4LatencyProbe = Probe.new()
	_expect(probe.mark_input(Vector2i(1, 2), "brush") == 0,
		"Disabled instrumentation is inert")
	_expect(not probe.record_duration("queue_admission", 1, 3),
		"Disabled probe never collects timing samples")
	probe.configure(true)
	_expect(probe.mark_input(Vector2i(1, 2), "erase") == 1,
		"Opt-in probe records observation time without inventing a native receipt")
	_expect(not probe.record_duration("queue_admission", 9, 8),
		"Negative timing interval refuses")
	_expect(not probe.record_duration("invented_stage", 1, 2),
		"Unregistered timing stage refuses")
	_expect(probe.record_duration("queue_admission", 12, 37, {"admitted": true}),
		"Actual stage start/end metadata is retained")
	_expect(probe.record_duration("scene_callback", 1, 200),
		"Enclosing callback is separately recorded")
	_expect(probe.record_duration("texture_upload_submission", 20, 120),
		"Nested upload is sampled independently of the enclosing callback")
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.serial = 1
	snapshot.tick_index = 5
	snapshot.render_snapshot_serial = 9
	snapshot.render_world_generation = 2
	snapshot.world_revision = 7
	snapshot.published_usec = 100
	snapshot.worker_step_time_ms = 4.0
	snapshot.snapshot_copy_time_ms = 1.0
	snapshot.render_exchange_time_ms = 1.0
	probe.observe_snapshot(snapshot, 180)
	probe.observe_snapshot(snapshot, 190)
	_expect(probe.summary().stages.receipt_delivery.count == 1,
		"Repeated snapshot serials cannot duplicate delivery timing")
	_expect(not probe.record_native_receipt_stage(1, 2, {}),
		"Unknown native work cannot be relabelled as execution time")
	probe.mark_upload(snapshot, 201, 250, false)
	_expect(probe.observe_post_draw(260).outcome == "NoVisibleUpload",
		"Refused texture upload is not counted as presentation")
	probe.mark_upload(snapshot, 301, 350, true)
	var post_draw: Dictionary = probe.observe_post_draw(360)
	_expect(post_draw.get("ok", false) and not post_draw.get("causal_frame_identity_proven", true),
		"Deferred post-draw callback is observed without claiming that exact render serial was displayed")
	_expect(probe.observe_post_draw(370).outcome == "NoVisibleUpload",
		"Duplicate frame callbacks do not create duplicate presentations")
	var summary: Dictionary = probe.summary()
	_expect(summary.no_additive_stage_total and not summary.input_to_post_draw_causally_proven,
		"Overlapping durations and uncorrelated input are never summed into fake latency")
	_expect(summary.post_draw_callbacks_after_upload == 1 and summary.proven_presented_uploads == 0 \
			and not summary.frame_serial_coherence_proven \
			and summary.stages.scene_callback.count == 1,
		"Reported scope distinguishes accepted upload and unproven post-draw serial")
	_expect(summary.worker_metrics.scope == "worker_reported_potentially_nested_not_a_sum",
		"Native render/snapshot costs remain source-labelled, not fake disjoint stages")
	var old_epoch: int = probe.epoch
	probe.retire("F2")
	_expect(probe.epoch == old_epoch + 1 and probe.observe_post_draw(400).outcome == "NoVisibleUpload",
		"Navigation fences stale deferred post-draw callbacks")
	for i: int in range(650):
		probe.record_duration("queue_admission", i, i + 1)
	_expect(probe.events.size() == Probe.MAX_EVENTS and
		probe.summary().stages.queue_admission.count == Probe.MAX_STAGE_SAMPLES,
		"Instrumentation is bounded during sustained input, not disk-growing")
	_expect(not probe.export_jsonl("res://never-write.json").ok,
		"Explicit export cannot write into checked-out project tree")
	print(JSON.stringify({"schema": "objectshard-m4-workbench-probe-test-v1",
		"checks": checks, "failures": failures, "semantic_physics_claims": 0,
		"events_retained": probe.events.size(),
		"scope": "value-only measurement bookkeeping and lifecycle fences"}))
	quit(0 if failures == 0 else 1)
