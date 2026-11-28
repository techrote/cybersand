extends "res://scripts/simulation_worker.gd"

# Qualification-only adversary: delay one real owner capture beyond the
# controller's ordinary thirty-second deadline. The actual native operation
# still completes; no fake result or shortened production deadline is used.
var qualification_delay_next_capture := false


func _consume_persistent_request() -> Dictionary:
	_mutex.lock()
	var delay: bool = qualification_delay_next_capture and _persistent_request.get("kind","") == "capture"
	if delay: qualification_delay_next_capture = false
	_mutex.unlock()
	if delay: OS.delay_msec(31500)
	return super._consume_persistent_request()
