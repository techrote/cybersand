extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var stress: bool = "--stress" in arguments
	var result: Dictionary = await CyberWorkerBenchmark.run(self, stress, 0, func(text: String) -> void: print(text), func() -> bool: return false)
	for argument: String in arguments:
		if argument.begins_with("--report="):
			var file: FileAccess = FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			if file == null:
				push_error("Could not write benchmark report")
				quit(1)
				return
			file.store_string(JSON.stringify(result, "  "))
			file.close()
	print("WORKER_BENCHMARK ", JSON.stringify(result))
	quit(0 if result.get("ok", false) else 1)
