extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var result: Dictionary = CyberInteractionPolicyProbe.run()
	print(JSON.stringify(result))
	var fallback: Dictionary = CyberInteractionPolicyProbe.run(true)
	print(JSON.stringify(fallback))
	quit(0 if result.ok and fallback.ok else 1)
