extends CyberSimulationWorker

# Test-only subclass: production pacing/publication/ownership are exercised.
# Native observations are read by their owner and retained in fixed storage.
# The main thread reads this array only after stop_worker() joins the owner.
var diagnostic_limit: int = 1800
var diagnostic_trace: PackedFloat64Array = PackedFloat64Array()
var recorded_tick: int = 0

func prepare_trace(limit: int) -> bool:
	if limit < 1 or limit > CyberPhysicsCharacterisation.MAX_TICKS:
		return false
	diagnostic_limit = limit
	diagnostic_trace.resize((limit+1)*12)
	diagnostic_trace.fill(0.0)
	return true

func _publish_snapshot(
		step_ms: float,
		paused: bool,
		interval: int,
		force_full: bool = false,
		rigid_body_states: PackedFloat32Array = PackedFloat32Array()
) -> void:
	super._publish_snapshot(step_ms, paused, interval, force_full, rigid_body_states)
	var tick: int = int(_world.get_tick_index())
	if tick > recorded_tick and tick <= diagnostic_limit and not _simulation_failed:
		var offset: int = tick*12
		diagnostic_trace[offset] = tick
		diagnostic_trace[offset+1] = step_ms
		diagnostic_trace[offset+2] = _world.get_rigid_body_unresolved_last_tick()
		diagnostic_trace[offset+3] = _world.get_rigid_body_displaced_last_tick()
		var metrics: Array = _world.diagnostic_body_metrics()
		if not metrics.is_empty():
			var d: Array = metrics[0]
			for i: int in range(8): diagnostic_trace[offset+4+i] = d[2+i]
		recorded_tick = tick
	if tick >= diagnostic_limit:
		_mutex.lock()
		_running = false
		_mutex.unlock()
