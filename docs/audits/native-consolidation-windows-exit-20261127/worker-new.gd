extends SceneTree
const Worker = preload("res://scripts/simulation_worker.gd")
func _initialize() -> void:
	finish.call_deferred()
func finish() -> void:
	var worker = Worker.new()
	assert(worker._world.get_class() == "CyberNativeCellWorld")
	print("EXIT_CONTROL_FINISHED")
	quit()
