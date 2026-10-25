extends CyberSimulationWorker
var observe_initial: bool = false
var initial_values: Dictionary = {}
func arm() -> void:
	_mutex.lock();observe_initial = true;_mutex.unlock()
func initial() -> Dictionary:
	_mutex.lock();var value: Dictionary = initial_values.duplicate(true);_mutex.unlock();return value
func _publish_snapshot(step_ms: float, is_paused: bool, interval: int, force_full: bool = false,
		states: PackedFloat32Array = PackedFloat32Array(), epoch: int = 0) -> void:
	super._publish_snapshot(step_ms,is_paused,interval,force_full,states,epoch)
	_mutex.lock();var capture: bool = observe_initial and initial_values.is_empty();_mutex.unlock()
	if not capture: return
	var values: Dictionary = {"water":_water_observe().water_integer,"tick":_world.get_tick_index()}
	_mutex.lock();initial_values = values;_mutex.unlock()
