extends SceneTree

func _initialize() -> void:
	finish.call_deferred()
func finish() -> void:
	pass
	print("EXIT_CONTROL_FINISHED")
	quit()
