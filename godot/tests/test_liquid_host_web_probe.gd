extends SceneTree

const Probe = preload("res://scripts/liquid_host_web_probe.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var controller: Control = load("res://web_main.tscn").instantiate()
	root.add_child(controller)
	await process_frame
	controller.set_process(false);controller.set_physics_process(false)
	var result: Dictionary = Probe.run(controller)
	var water_runs: Array = result.get("water_runs",[])
	if water_runs.size()!=6:
		result.ok = false
		result.failures.append("native prerequisite must complete all six common-Water arms")
	print("LIQUID_HOST_WEB_PROBE_NATIVE: ",JSON.stringify(result))
	controller.queue_free()
	await process_frame
	if not result.ok: push_error("Explicit Web host apparatus failed its native prerequisite")
	quit(0 if result.ok else 1)
