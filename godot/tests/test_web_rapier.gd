extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://web_main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var result: Dictionary = await CyberWebRapierProbe.run(scene)
	print("WEB_RAPIER_TEST ", JSON.stringify(result))
	scene.queue_free()
	await process_frame
	quit(0 if result.ok else 1)
