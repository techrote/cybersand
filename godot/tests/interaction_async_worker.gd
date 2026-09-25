extends CyberSimulationWorker

# Exclusive-owner scripted actions; fixed trace is read only after join.
var trace: PackedFloat64Array = PackedFloat64Array()
var last_tick: int = 0

func prepare() -> void:
	trace.resize(241*4)
	trace.fill(0)

func _publish_snapshot(
		step_ms: float,
		paused: bool,
		interval: int,
		force_full: bool = false,
		rigid_body_states: PackedFloat32Array = PackedFloat32Array()
) -> void:
	super._publish_snapshot(step_ms, paused, interval, force_full, rigid_body_states)
	var tick: int = int(_world.get_tick_index())
	if tick > last_tick and tick <= 240 and not _simulation_failed:
		trace[tick*4] = tick
		trace[tick*4+1] = _character.position.x
		trace[tick*4+2] = _character.position.y
		trace[tick*4+3] = float(_character.grounded)
		last_tick = tick
	if tick == 90 or tick == 150:
		_mutex.lock()
		_horizontal_input = 1.0 if tick == 90 else 0.0
		_mutex.unlock()
	if tick == 150:
		_world.diagnostic_fill_rect(Vector2i(64,100),Vector2i(160,101),0)
	if tick >= 240:
		_mutex.lock()
		_running = false
		_mutex.unlock()
