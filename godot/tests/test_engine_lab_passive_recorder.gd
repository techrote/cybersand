extends SceneTree

# ENG-LAB-001: executable, source-local passive recorder correctness protocol.
const Recorder = preload("res://scripts/engine_lab_passive_recorder.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ENG_LAB_PASSIVE: " + label)


func sample(at_usec: int, tick: int, rapier: int, gen: int = 1) -> Dictionary:
	return {"at_usec":at_usec, "native_tick":tick, "rapier_steps":rapier,
		"world_generation":gen, "render_serial":tick / 12 + 1,
		"render_age_usec":1000, "render_full":tick==24,
		"native_sim_ms":8.0, "worker_step_ms":10.0, "rapier_step_ms":0.15,
		"rapier_owner_id":101, "paused":false, "simulation_failed":false,
		"hold_counts":{"workbench_sample":tick / 6, "workbench_terrain":0,
			"workbench_no_snapshot":0, "lockstep":0}}


func _run() -> void:
	var r := Recorder.new()
	expect(not r.begin({}, 0), "invalid zero timestamp refused")
	expect(not r.begin({}, 1000000, 500), "too-short benchmark refused")
	expect(r.begin({"world":"owned"}, 1000000, 600000), "valid bounded capture")
	expect(not r.begin({}, 1000000, 600000), "overlapping capture refused")
	var first: Dictionary = sample(1000000,0,0)
	expect(r.observe(first), "first immutable row")
	first.native_tick = 1000
	expect(r.samples[0].native_tick == 0, "caller cannot mutate retained sample")
	expect(r.observe(sample(1200000,12,10)), "second row")
	expect(r.observe(sample(1400000,24,20)), "third row")
	expect(r.observe(sample(1600000,36,30)), "complete on elapsed monotonic wall clock")
	expect(r.finished and not r.running and r.outcome.status == "passed",
		"complete receipt only at duration")
	expect(r.outcome.frame_count == 4 and r.outcome.native_ticks == 36
		and r.outcome.rapier_steps == 30, "real deltas not inferred frame counts")
	expect(is_equal_approx(float(r.outcome.actual_native_hz),60.0)
		and is_equal_approx(float(r.outcome.actual_rapier_hz),50.0),
		"physical clocks computed from wall elapsed time")
	expect(r.outcome.frame_interval_ms.count == 3
		and is_equal_approx(float(r.outcome.frame_interval_ms.p95),200.0),
		"complete frame interval distribution")
	expect(r.outcome.full_publications_observed == 1
		and r.outcome.accepted_publications_observed == 3,
		"render counts only accepted serial increments")
	expect(r.outcome.coupling_held_physics_frames.workbench_sample == 6,
		"hold delta uses start and end monotonic counters")
	expect(r.observe(sample(1800000,48,40)) == false,
		"cannot silently append after successful completion")

	# Godot Object.get_instance_id() is a signed 64-bit handle. A valid
	# identity may have the sign bit set; only zero is an invalid sentinel.
	var signed_owner := Recorder.new()
	expect(signed_owner.begin({},1000000,600000), "signed owner fixture starts")
	var negative_identity: Dictionary = sample(1000000,0,0)
	negative_identity.rapier_owner_id = -9223371963974547928
	expect(signed_owner.observe(negative_identity),
		"valid signed-negative Object instance ID is admitted")
	signed_owner.abort("completed_unit_boundary",1100000)
	expect(signed_owner.outcome.reason == "completed_unit_boundary", "signed owner retains normal abort cause")

	var reset := Recorder.new()
	expect(reset.begin({},1000000,800000), "reset fixture starts")
	expect(reset.observe(sample(1000000,100,100)), "reset initial")
	expect(not reset.observe(sample(1200000,1,1,2)), "reset owner-generation is refused")
	expect(reset.finished and reset.outcome.status == "incomplete" and
		reset.outcome.reason == "clock_reversal_or_owner_generation_change",
		"World replacement invalidates comparable window")
	var stale := Recorder.new()
	expect(stale.begin({},1000000,800000), "stale fixture starts")
	expect(stale.observe(sample(1000000,0,0)), "stale initial")
	expect(not stale.observe(sample(1000000,0,0)), "duplicate timestamp refused")
	expect(stale.outcome.status == "incomplete", "stale result not called passing")
	var pause := Recorder.new()
	expect(pause.begin({},1000000,800000), "pause fixture starts")
	var paused: Dictionary = sample(1000000,0,0)
	paused.paused = true
	expect(not pause.observe(paused), "paused World not counted as active tick comparison")
	expect(pause.outcome.reason == "world_paused_or_failed_during_capture", "pause reason")
	var cancel := Recorder.new()
	expect(cancel.begin({},1000000,800000), "cancel fixture starts")
	expect(cancel.observe(sample(1000000,0,0)), "cancel initial")
	cancel.abort("cancelled_by_owner",1200000)
	expect(cancel.outcome.status == "incomplete" and cancel.outcome.raw_samples.size() == 1,
		"cancellation retains partial evidence and its honest status")

	var capacity := Recorder.new()
	expect(capacity.begin({},1000000,20000000), "capacity fixture starts")
	for i: int in range(Recorder.MAX_SAMPLES):
		if not capacity.observe(sample(1000000+i,0,0)):
			break
	expect(not capacity.observe(sample(1000000+Recorder.MAX_SAMPLES,0,0)),
		"bounded in-memory buffer refuses 4097th record")
	expect(capacity.outcome.reason == "bounded_sample_capacity_exceeded" and
		capacity.outcome.raw_samples.size() == Recorder.MAX_SAMPLES,
		"bounded raw evidence retained, not overwritten")

	print("ENG_LAB_PASSIVE: %d checks, %d failures" % [checks, failures])
	quit(failures)
