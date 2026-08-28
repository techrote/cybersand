extends SceneTree

# Focused regression for the reported platform-edge slowdown: a mixed waterfall
# crosses the interest-window margin while reactive and hard materials are
# repeatedly introduced. The native tick must keep advancing, and hard-surface
# geometry must be published as compact rectangles rather than rescanned in
# GDScript on the main thread.

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native world is unavailable")
	if _failures != 0:
		quit(_failures)
		return

	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	world.set_simulation_window(Vector2i.ZERO, Vector2i(320, 180), 32, 36)
	world.emit_disc(334, 158, 9, CyberCellWorld.WATER)
	world.emit_disc(329, 154, 7, CyberCellWorld.SAND)
	world.emit_disc(128, 110, 5, CyberCellWorld.LAVA)
	world.emit_disc(132, 110, 5, CyberCellWorld.WATER)

	var maximum_rectangle_build_ms: float = 0.0
	for tick: int in range(240):
		if tick % 30 == 0:
			world.emit_disc(337, 169, 3, CyberCellWorld.WALL)
			world.emit_disc(337, 165, 3, CyberCellWorld.WATER)
		_expect(bool(world.simulation_tick()), "native tick reported a failure")
		if tick % 6 == 0:
			var build_start_usec: int = Time.get_ticks_usec()
			var rectangles: PackedInt32Array = world.get_hard_surface_rectangles()
			maximum_rectangle_build_ms = maxf(
				maximum_rectangle_build_ms,
				float(Time.get_ticks_usec() - build_start_usec) / 1000.0
			)
			_expect(rectangles.size() % 4 == 0, "packed hard-surface rectangles are malformed")

	_expect(int(world.tick_failure_count) == 0, "native tick fault counter changed")
	_expect(int(world.tick_index) >= 240, "native simulation stopped advancing")
	var final_rectangles: PackedInt32Array = world.get_hard_surface_rectangles()
	_expect(not final_rectangles.is_empty(), "hard-surface rectangle set is empty")

	if _failures == 0:
		print(
			"Native edge/contact regression passed; max native rectangle refresh %.3f ms" %
			maximum_rectangle_build_ms
		)
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
