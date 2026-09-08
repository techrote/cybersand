extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var result: Dictionary = await CyberWebWorkerProbe.run(self)
	print("WEB_WORKER_PARITY ", JSON.stringify(result))
	quit(0 if result.passed else 1)
