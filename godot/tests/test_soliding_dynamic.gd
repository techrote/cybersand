extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var host: Node = Node.new();root.add_child(host)
	var ok: bool = true
	var selected: String = str(ProjectSettings.get_setting("physics/2d/physics_engine"))
	ProjectSettings.set_setting("physics/2d/physics_engine","GodotPhysics2D")
	var refused: Dictionary = await preload("res://scripts/soliding_dynamic_probe.gd").run(host,1,14)
	ProjectSettings.set_setting("physics/2d/physics_engine",selected)
	ok = not refused.ok and str(refused.error).begins_with("Rapier admission:")
	print("SOLIDING_BACKEND_REFUSAL ",ok)
	var session: Object = ClassDB.instantiate(&"CyberSolidingSession")
	var thread: Thread = Thread.new()
	var started: int = thread.start(func() -> bool: return not session.configure(8,14,1))
	ok = started == OK and bool(thread.wait_to_finish()) and ok
	ok = session.configure(8,14,1) and ok
	thread = Thread.new()
	started = thread.start(func() -> bool: return not session.tick() and session.status().is_empty())
	ok = started == OK and bool(thread.wait_to_finish()) and ok
	print("SOLIDING_THREAD_GUARD ",ok)
	session = null
	for workers: int in [1,4]:
		for height: int in [8,14]:
			var result: Dictionary = await preload("res://scripts/soliding_dynamic_probe.gd").run(host,workers,height)
			print("SOLIDING_DYNAMIC ",JSON.stringify(result))
			ok = result.ok and ok
	quit(0 if ok else 1)
