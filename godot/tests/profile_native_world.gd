extends SceneTree

# Focused developer probe for the compiled scheduler. This is intentionally not
# part of normal startup or an exhaustive gameplay test suite.


func _init() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		push_error("CyberNativeCellWorld is unavailable")
		quit(1)
		return
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	world.simulation_window_enabled = false

	# A sparse airborne shower resembles the reported worst case while avoiding
	# setup through scene nodes or the renderer.
	for y: int in range(8, 300, 3):
		for x: int in range(8, CyberCellWorld.WORLD_WIDTH - 8, 3):
			world.emit_disc(x, y, 0, CyberCellWorld.SAND)

	var start_usec: int = Time.get_ticks_usec()
	var ticks: int = 60
	for _tick: int in range(ticks):
		world.simulation_tick()
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var cells: PackedByteArray = world.get_cells()
	if cells.size() != CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT:
		push_error("native render snapshot has wrong extent")
		quit(1)
		return
	print(
		"native_profile workers=%d ticks=%d mean_ms=%.3f visited=%d moved=%d jobs=%d" % [
			world.get_worker_threads(),
			ticks,
			elapsed_ms / float(ticks),
			world.scanned_last_tick,
			world.moves_last_tick,
			world.scheduler_jobs_last_tick,
		]
	)
	quit(0)
