extends SceneTree

# Focused scheduling probe, not a pass/fail gameplay benchmark. It creates the
# same sparse shower twice and reports serial versus four-phase pool timing.
const WARMUP_TICKS: int = 4
const MEASURED_TICKS: int = 24


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var serial_world: CyberCellWorld = _shower_world(false)
	var threaded_world: CyberCellWorld = _shower_world(true)
	var serial_ms: float = _measure(serial_world)
	var threaded_ms: float = _measure(threaded_world)
	var speedup: float = serial_ms / maxf(threaded_ms, 0.001)
	print(
		(
			"Scheduler probe: serial %.2f ms/tick, phased %.2f ms/tick, %.2fx; "
			+ "last tick %d jobs, %d parallel phases, %d sparse ballistic moves"
		) % [
			serial_ms,
			threaded_ms,
			speedup,
			threaded_world.scheduler_jobs_last_tick,
			threaded_world.scheduler_parallel_phases_last_tick,
			threaded_world.sparse_flight_moves_last_tick,
		]
	)
	quit()


func _shower_world(threaded: bool) -> CyberCellWorld:
	var world: CyberCellWorld = CyberCellWorld.new()
	world.cells.fill(CyberCellWorld.EMPTY)
	world.updated_at.fill(0)
	world.quiet_ticks.fill(0)
	world.flow_budget.fill(0)
	world.flow_direction.fill(CyberCellWorld.FLOW_DIRECTION_NONE)
	world.active_blocks.fill(0)
	world.next_active_blocks.fill(0)
	world.block_movable_counts.fill(0)
	world.tick_index = 0
	world.update_epoch = 1
	world.revision = 0
	world.simulation_window_enabled = false
	world.cadence_lod_enabled = true
	world.threaded_scheduler_enabled = threaded

	for x: int in range(48, 912, 3):
		world.set_cell(x, 500, CyberCellWorld.WALL)
		for y: int in range(32 + (x % 5), 420, 5):
			var selector: int = (x * 7 + y * 11) % 3
			var material_id: int = CyberCellWorld.SAND
			if selector == 1:
				material_id = CyberCellWorld.WATER
			elif selector == 2:
				material_id = CyberCellWorld.SMOKE
			world.set_cell(x, y, material_id)
	return world


func _measure(world: CyberCellWorld) -> float:
	for _tick: int in range(WARMUP_TICKS):
		world.simulation_tick()
	var start_usec: int = Time.get_ticks_usec()
	for _tick: int in range(MEASURED_TICKS):
		world.simulation_tick()
	return (
		float(Time.get_ticks_usec() - start_usec)
		/ 1000.0
		/ float(MEASURED_TICKS)
	)
