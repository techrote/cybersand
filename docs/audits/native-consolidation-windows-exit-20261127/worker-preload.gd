extends SceneTree
const Worker = preload("res://scripts/simulation_worker.gd")
func _initialize() -> void:
	finish.call_deferred()
func finish() -> void:
	assert(Worker != null)
	print("EXIT_CONTROL_FINISHED")
	quit()
