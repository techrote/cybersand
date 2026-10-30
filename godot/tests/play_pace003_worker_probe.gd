extends "res://tests/play_wait001_snapshot_probe.gd"

# Test-only owner instrumentation. Inherits WAIT001's exact timed snapshot
# acquisition. The native rows below have ONE writer: _publish_snapshot on the
# exclusive owner (or the initial, not-yet-started Main call). Main reads them
# only after stop_worker has joined. There is no shared sampling-enable flag.
const MAX_NATIVE_ROWS: int = 12000
var native_rows: Array[Dictionary] = []
var native_rows_overflow: bool = false
var stop_join_usec: int = -1
var _native_observer: Variant
var _observed_generation: int = -1
var _observed_tick: int = -1


func _publish_snapshot(worker_step_time_ms: float, paused: bool,
		render_snapshot_interval_usec: int, force_render_full_refresh: bool = false,
		rigid_body_states: PackedFloat32Array = PackedFloat32Array(),
		rigid_body_epoch: int = 0) -> void:
	# Timestamp native completion before the ordinary publication. The recorded
	# native timer excludes publication and this diagnostic copied-statistics cost.
	var completed_usec: int = Time.get_ticks_usec()
	super._publish_snapshot(worker_step_time_ms, paused, render_snapshot_interval_usec,
		force_render_full_refresh, rigid_body_states, rigid_body_epoch)
	if _simulation_failed or paused or _world == null:
		return
	var tick: int = int(_world.tick_index)
	if tick <= 0 or (_observed_generation == _world_generation and _observed_tick == tick):
		return
	_observed_generation = _world_generation
	_observed_tick = tick
	if native_rows.size() >= MAX_NATIVE_ROWS:
		native_rows_overflow = true
		return
	var probe_started: int = Time.get_ticks_usec()
	if _native_observer == null:
		_native_observer = ClassDB.instantiate(&"CyberDemoBridge")
	var stats: Dictionary = _native_observer.inspect_statistics(_world)
	var values: Dictionary = stats.get("values", {})
	var row: Dictionary = {"completed_usec":completed_usec, "tick":tick,
		"native_completed_tick":int(stats.get("completed_tick", -1)),
		"generation":_world_generation, "actor_epoch":rigid_body_epoch,
		"native_ms":float(_world.simulation_time_ms), "worker_step_ms":worker_step_time_ms,
		"workers_observed":int(values.get("worker_threads_observed", 0)),
		"capacity":int(_world.get_worker_threads()),
		"parallel_phases":int(_world.scheduler_parallel_phases_last_tick),
		"jobs":int(_world.scheduler_jobs_last_tick),
		"overruns":_worker_overruns, "statistics_ok":bool(stats.get("ok", false))}
	# Record the query/copy cost separately; array append itself is included.
	native_rows.append(row)
	row.probe_usec = Time.get_ticks_usec() - probe_started


func stop_worker() -> void:
	var started: int = Time.get_ticks_usec()
	super.stop_worker()
	stop_join_usec = Time.get_ticks_usec() - started
