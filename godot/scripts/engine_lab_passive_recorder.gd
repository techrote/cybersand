class_name CyberEngineLabPassiveRecorder
extends RefCounted

# ENG-LAB-001 Phase A. Main-thread value-only recorder, no native/physics calls.
# One bounded in-memory window; callers own the physical and render clocks.
const MAX_SAMPLES: int = 4096
const MAX_DURATION_USEC: int = 20000000
const MIN_DURATION_USEC: int = 100000
const SCHEMA: String = "cybersand-engine-lab-passive-v1"

var running: bool = false
var finished: bool = false
var identity: Dictionary = {}
var samples: Array[Dictionary] = []
var started_usec: int = 0
var ended_usec: int = 0
var duration_usec: int = 10000000
var failure: String = ""
var outcome: Dictionary = {}


func begin(source: Dictionary, start_usec: int, requested_usec: int = 10000000) -> bool:
	if running or start_usec <= 0 or requested_usec < MIN_DURATION_USEC or requested_usec > MAX_DURATION_USEC:
		return false
	identity = source.duplicate(true)
	samples.clear()
	started_usec = start_usec
	ended_usec = 0
	duration_usec = requested_usec
	failure = ""
	outcome = {}
	finished = false
	running = true
	return true


static func distribution(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"count":0}
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var sum: float = 0.0
	for value: float in values:
		sum += value
	var n: int = sorted_values.size()
	return {"count":n, "mean":sum / float(n),
		"p50":sorted_values[ceili(0.50 * n) - 1],
		"p95":sorted_values[ceili(0.95 * n) - 1],
		"p99":sorted_values[ceili(0.99 * n) - 1],
		"max":sorted_values[n - 1]}


func observe(sample: Dictionary) -> bool:
	if not running:
		return false
	var at_usec: int = int(sample.get("at_usec", -1))
	var tick: int = int(sample.get("native_tick", -1))
	var rapier: int = int(sample.get("rapier_steps", -1))
	var generation: int = int(sample.get("world_generation", -1))
	var render_serial: int = int(sample.get("render_serial", -1))
	var owner_id: int = int(sample.get("rapier_owner_id", 0))
	if at_usec < started_usec or tick < 0 or rapier < 0 or generation <= 0 or render_serial < 0 or owner_id == 0:
		abort("invalid_clock_or_ownership_sample", maxi(at_usec, started_usec))
		return false
	if bool(sample.get("paused", true)) or bool(sample.get("simulation_failed", false)):
		abort("world_paused_or_failed_during_capture", at_usec)
		return false
	if not samples.is_empty():
		var previous: Dictionary = samples.back()
		if (at_usec <= int(previous.at_usec) or tick < int(previous.native_tick)
			or rapier < int(previous.rapier_steps)
			or generation != int(previous.world_generation)
			or owner_id != int(previous.rapier_owner_id)):
			abort("clock_reversal_or_owner_generation_change", at_usec)
			return false
		if render_serial < int(previous.render_serial):
			abort("render_serial_reversed", at_usec)
			return false
	if samples.size() >= MAX_SAMPLES:
		abort("bounded_sample_capacity_exceeded", at_usec)
		return false
	samples.append(sample.duplicate(true))
	if at_usec - started_usec >= duration_usec:
		complete(at_usec)
	return true


func abort(reason: String, at_usec: int) -> void:
	if not running:
		return
	failure = reason
	_finalize(maxi(at_usec, started_usec))


func complete(at_usec: int) -> void:
	if not running:
		return
	_finalize(maxi(at_usec, started_usec))


func _finalize(at_usec: int) -> void:
	running = false
	finished = true
	ended_usec = at_usec
	if failure.is_empty() and samples.size() < 3:
		failure = "insufficient_samples"
	if failure.is_empty() and ended_usec - started_usec < duration_usec:
		failure = "incomplete_wall_clock_window"
	outcome = report()


func report() -> Dictionary:
	var frames: Array[float] = []
	var native_time: Array[float] = []
	var worker_time: Array[float] = []
	var rapier_time: Array[float] = []
	var render_age: Array[float] = []
	var publications: int = 0
	var full_publications: int = 0
	var prior: Dictionary = {}
	for row: Dictionary in samples:
		if not prior.is_empty():
			frames.append(float(int(row.at_usec) - int(prior.at_usec)) / 1000.0)
			if int(row.native_tick) > int(prior.native_tick):
				native_time.append(float(row.get("native_sim_ms", 0.0)))
				worker_time.append(float(row.get("worker_step_ms", 0.0)))
			if int(row.rapier_steps) > int(prior.rapier_steps):
				rapier_time.append(float(row.get("rapier_step_ms", 0.0)))
			if int(row.render_serial) > int(prior.render_serial):
				publications += 1
				if bool(row.get("render_full", false)):
					full_publications += 1
		var age_usec: int = int(row.get("render_age_usec", -1))
		if age_usec >= 0:
			render_age.append(float(age_usec) / 1000.0)
		prior = row
	var elapsed_sec: float = maxf(0.000001, float(ended_usec - started_usec) / 1000000.0)
	var native_ticks: int = int(samples.back().native_tick) - int(samples.front().native_tick) if samples.size() > 1 else 0
	var rapier_steps: int = int(samples.back().rapier_steps) - int(samples.front().rapier_steps) if samples.size() > 1 else 0
	var holds: Dictionary = {}
	if samples.size() > 1:
		var first_holds: Dictionary = samples.front().get("hold_counts", {})
		var last_holds: Dictionary = samples.back().get("hold_counts", {})
		for key: String in ["workbench_sample", "workbench_terrain", "workbench_no_snapshot", "lockstep"]:
			holds[key] = maxi(0, int(last_holds.get(key, 0)) - int(first_holds.get(key, 0)))
	return {"schema":SCHEMA, "status":"passed" if failure.is_empty() else "incomplete",
		"reason":failure if not failure.is_empty() else "normal_completion",
		"identity":identity, "started_usec":started_usec, "ended_usec":ended_usec,
		"duration_requested_usec":duration_usec, "elapsed_seconds":elapsed_sec,
		"frame_count":samples.size(), "native_ticks":native_ticks,
		"rapier_steps":rapier_steps, "actual_native_hz":float(native_ticks) / elapsed_sec,
		"actual_rapier_hz":float(rapier_steps) / elapsed_sec,
		"full_publications_observed":full_publications,
		"accepted_publications_observed":publications,
		"coupling_held_physics_frames":holds,
		"frame_interval_ms":distribution(frames),
		"native_completed_tick_cost_ms":distribution(native_time),
		"worker_completed_tick_cost_ms":distribution(worker_time),
		"rapier_completed_step_cost_ms":distribution(rapier_time),
		"render_payload_age_at_frame_ms":distribution(render_age),
		"peak_static_memory_bytes":OS.get_static_memory_peak_usage(),
		"limitations":[
			"No inputs were injected, but human input and unrelated application activity were not suppressed",
			"Only the latest worker-completed native tick duration is available per Main callback; skipped native ticks cannot be individually timed",
			"Rapier step cost is the most recent completed manual step, not a CPU/GPU scheduler trace",
			"Render serial counts are accepted Main publications; they are not native dirty-capture counts or GPU transfer completion",
			"Workbench hold counts measure skipped physics callbacks, not blocked wall time",
			"World state is not restored by this passive recording; matching a saved start is the owner's responsibility",
			"Godot static peak allocation is not whole-process RSS or VRAM",
		],
		"raw_samples":samples.duplicate(true)}
