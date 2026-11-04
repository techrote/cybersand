extends SceneTree

# Source-matched GDExtension proof through existing public value APIs. The
# standalone native apparatus separately proves actual distributed claimants,
# private block deadlines, masks, shared obligations and saved-state boundaries.
const WALL: int = 1
const GLASS: int = 35
const MOLTEN_GLASS: int = 36
const PHASES: Array[Vector2i] = [Vector2i(11, 0), Vector2i(8, 1), Vector2i(10, 2), Vector2i(26, 3)]
var assertions: int = 0
var failures: int = 0
var cohorts: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("H1_GODOT: " + message)


func _world(workers: int, x: int, pair: bool = false) -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	_expect(world.diagnostic_reset({"workers": workers, "telemetry": true}), "native diagnostic reset")
	_expect(world.diagnostic_fill_rect(Vector2i(x - 2, 7), Vector2i(6, 3), WALL), "sealed chamber")
	_expect(world.diagnostic_fill_rect(Vector2i(x, 8), Vector2i.ONE, MOLTEN_GLASS), "source insertion")
	if pair:
		_expect(world.diagnostic_fill_rect(Vector2i(x + 1, 8), Vector2i.ONE, MOLTEN_GLASS), "heat partner")
	return world


func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		push_error("H1_GODOT requires the actual source-matched native extension")
		quit(1)
		return
	for p: Vector2i in PHASES:
		var one: Object = _world(1, p.x)
		var four: Object = _world(4, p.x)
		var countdown: int = 180
		var first_decrement: int = 0
		var conversion_tick: int = 0
		for tick: int in range(1, 769):
			if countdown > 0 and tick % 4 == p.y:
				countdown -= 1
				if first_decrement == 0:
					first_decrement = tick
				if countdown == 0:
					conversion_tick = tick
			_expect(bool(one.simulation_tick()) and bool(four.simulation_tick()), "healthy real native ticks")
			# inspect_pressure_cell exposes stored material/a even when its PF-only
			# available flag is false. We assert no pressure-solver availability.
			var readback: Dictionary = one.inspect_pressure_cell(Vector2i(p.x, 8))
			_expect(int(readback.state_a) == countdown, "actual four-tick cooling countdown")
			_expect(int(readback.material) == (GLASS if countdown == 0 else MOLTEN_GLASS), "actual product")
			_expect(one.get_physical_state_hash() == four.get_physical_state_hash(), "configured one/four physical parity")
			if tick > 744:
				_expect(int(one.scheduler_jobs_last_tick) == 0 and int(four.scheduler_jobs_last_tick) == 0,
					"converted region retires scheduled work")
		cohorts.append({"phase": p.y, "x": p.x, "first_decrement_tick": first_decrement,
			"conversion_tick": conversion_tick, "completed_ticks": int(one.tick_index),
			"configured_workers": [1, 4], "physical_hash": str(one.get_physical_state_hash()),
			"actual_distributed_workers_claimed": false})
		one = null
		four = null
	for workers: int in [1, 4]:
		var hot: Object = _world(workers, 11, true)
		for tick: int in range(1, 129):
			_expect(bool(hot.simulation_tick()), "hot control tick")
			var readback: Dictionary = hot.inspect_pressure_cell(Vector2i(11, 8))
			_expect(int(readback.material) == MOLTEN_GLASS and int(readback.state_a) == 180,
				"preserve H2 hot fixed point")
			if tick > 64:
				_expect(int(hot.scheduler_jobs_last_tick) == 0, "hot180 pool sleeps")
		hot = null
	print("H1_GODOT_PROOF: " + JSON.stringify({"schema": "mat354.h1.godot.v1",
		"assertions": assertions, "failures": failures, "cohorts": cohorts,
		"scope": "actual native cooling and hot180 retirement; native standalone owns distributed-worker proof"}))
	quit(1 if failures else 0)
