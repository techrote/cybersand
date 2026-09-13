extends CyberSimulationWorker
# Test-only subclass; the production desktop Thread owns every native query/write.
var maximum_rest: int = 0
var invalidated: bool = false
var removed: bool = false
var seen_tick: int = -1
var final_packet: Dictionary = {}
func _publish_snapshot(step_ms: float, paused: bool, interval: int, force_full: bool = false) -> void:
	super._publish_snapshot(step_ms,paused,interval,force_full)
	var tick: int = int(_world.get_tick_index())
	if tick == seen_tick:
		return
	seen_tick = tick
	var packet: Dictionary = _world.diagnostic_soliding_snapshot()
	var candidate: Dictionary = preload("res://scripts/soliding_probe.gd").wall_candidate(packet)
	maximum_rest = maxi(maximum_rest,int(candidate.get("rest_ticks",0)))
	if tick == 330:
		_world.diagnostic_fill_rect(Vector2i(32,60),Vector2i(32,2),0)
		packet = _world.diagnostic_soliding_snapshot()
		candidate = preload("res://scripts/soliding_probe.gd").wall_candidate(packet)
		invalidated = not candidate.get("stationary",true)
	if tick == 340:
		_world.diagnostic_fill_rect(Vector2i(36,52),Vector2i(8,8),0)
		packet = _world.diagnostic_soliding_snapshot()
		removed = preload("res://scripts/soliding_probe.gd").wall_candidate(packet).is_empty()
	if tick >= 360 or _simulation_failed:
		final_packet = packet.duplicate(true)
		_mutex.lock()
		_running = false
		_mutex.unlock()
