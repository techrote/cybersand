extends "res://scripts/simulation_worker.gd"

# PLAY-WAIT-001: test-only, instrumented equivalent of the production
# take_latest_snapshot(after_serial) lock/serial path. The live native World
# remains exclusive to the existing CyberSimulationWorker and Rapier remains
# owned by Main. Only the Main caller writes these arrays.
var sampling: bool = false
var mutex_acquire_wait_usec: Array[float] = []
var mutex_critical_section_usec: Array[float] = []
var returned_new_snapshots: int = 0
var returned_no_new_snapshot: int = 0


func begin_sample() -> void:
	mutex_acquire_wait_usec.clear()
	mutex_critical_section_usec.clear()
	returned_new_snapshots = 0
	returned_no_new_snapshot = 0
	sampling = true


func end_sample() -> void:
	sampling = false


func take_latest_snapshot(after_serial: int) -> CyberSimulationSnapshot:
	var entered_usec: int = Time.get_ticks_usec()
	_mutex.lock()
	var acquired_usec: int = Time.get_ticks_usec()
	var result: CyberSimulationSnapshot = _published_snapshot
	if result != null and result.serial <= after_serial:
		result = null
	var leaving_critical_usec: int = Time.get_ticks_usec()
	_mutex.unlock()
	if sampling:
		mutex_acquire_wait_usec.append(float(acquired_usec - entered_usec))
		mutex_critical_section_usec.append(float(leaving_critical_usec - acquired_usec))
		if result == null:
			returned_no_new_snapshot += 1
		else:
			returned_new_snapshots += 1
	return result
