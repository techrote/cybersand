extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var result: Dictionary = await CyberInteractionPolicyProbe.run()
	print(JSON.stringify(result))
	var fallback: Dictionary = await CyberInteractionPolicyProbe.run(true)
	print(JSON.stringify(fallback))
	quit(0 if result.ok and fallback.ok else 1)
