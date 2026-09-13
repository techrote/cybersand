extends SceneTree
const PROBE = preload("res://scripts/soliding_probe.gd")
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var results: Array = []
	var ok: bool = true
	for workers: int in [1,4]:
		var result: Dictionary = await PROBE.run(root,workers)
		results.append(result)
		ok = ok and result.ok
	print("SOLIDING_STATIONARY ",JSON.stringify({"ok":ok,"results":results}))
	quit(0 if ok else 1)
