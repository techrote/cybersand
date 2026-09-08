extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Dictionary = {0: 2, 1: 2, 2: 2, 3: 2, 4: 4, 5: 4, 11: 4, 12: 6, 16: 6, 20: 6, 64: 6}
	for logical: int in cases:
		var actual: int = int(ClassDB.class_call_static(&"CyberNativeCellWorld", &"auto_worker_threads", logical))
		if actual != cases[logical]:
			push_error("Auto boundary failed: %d -> %d" % [logical, actual])
			quit(1)
			return
	ProjectSettings.set_setting("cybersand/native_worker_threads", 0)
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var logical: int = int(ClassDB.class_call_static(&"CyberNativeCellWorld", &"logical_processor_count"))
	var expected: int = int(ClassDB.class_call_static(&"CyberNativeCellWorld", &"auto_worker_threads", logical))
	if int(world.get_worker_threads()) != expected:
		push_error("Created world ignored Auto")
		quit(1)
		return
	print("Auto boundaries passed; logical=%d actual=%d" % [logical, expected])
	quit(0)
