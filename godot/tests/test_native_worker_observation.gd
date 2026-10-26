extends SceneTree

# Configured pool size and the maximum actual participants in one dispatch are
# different observations. Thread participation may vary between runs and ticks.
var assertions: int = 0
var failures: int = 0
var bridge: Variant
var participation: Array = []

func _initialize() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error("NATIVE_WORKER_OBSERVATION: " + message)
	return value

func _run() -> void:
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	var worlds: Array = []
	for configured: int in [1, 4]:
		var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(world.diagnostic_reset({"workers": configured}), "requested worker configuration constructs")
		world.set_simulation_window_enabled(false)
		var rectangles := PackedInt32Array()
		# Four separated same-phase cores contain real falling Water and Sand.
		# These are body-free Current materials, not a new liquid-family fixture.
		for x: int in [32, 160, 288, 416]:
			rectangles.append_array(PackedInt32Array([x, 20, 24, 12, 3, x, 64, 16, 8, 2]))
		if not expect(bridge.build_world(world, rectangles), "multiple-core Current fixture builds"):
			_finish()
			return
		var initial: Dictionary = bridge.inspect_statistics(world)
		if not expect(initial.ok and initial["values"].has("worker_threads_configured")
			and initial["values"].has("worker_threads_observed")
			and initial["values"].has("worker_threads_observed_available"), "source-matched worker statistics required"):
			_finish()
			return
		expect(initial.completed_tick == 0 and initial["values"].worker_threads_observed == 0
			and initial["values"].worker_threads_observed_available,
			"no completed dispatch is fabricated at tick zero")
		participation.append({"fixture": "moving", "tick": 0, "configured": configured,
			"observed": initial["values"].worker_threads_observed, "available": initial["values"].worker_threads_observed_available,
			"scheduled_cores": initial["values"].scheduled_cores})
		_check_shape(initial, configured)
		_check_copy(world, initial)
		worlds.append(world)
	var multijob_phase: bool = false
	for tick: int in range(1, 9):
		for index: int in range(worlds.size()):
			var configured: int = 1 if index == 0 else 4
			var world: Variant = worlds[index]
			if not expect(world.simulation_tick(), "actual native work completes"):
				_finish()
				return
			var stats: Dictionary = bridge.inspect_statistics(world)
			_check_shape(stats, configured)
			var observed: int = int(stats["values"].worker_threads_observed)
			var maximum_jobs: int = 0
			for jobs: int in stats.phase_jobs_last_tick:
				maximum_jobs = maxi(maximum_jobs, jobs)
			expect(stats.completed_tick == tick and stats["values"].scheduled_cores >= 4
				and stats["values"].visited_cells > 0 and stats["values"].moved_cells > 0,
				"completed multiple-core work backs the observed count")
			expect(stats["values"].worker_threads_observed_available and observed >= 1
				and observed <= configured and observed <= maximum_jobs,
				"actual dispatch participation is bounded by configuration and scheduled jobs")
			if configured == 1:
				expect(observed == 1, "nonempty inline execution reports one actual participant")
			else:
				multijob_phase = multijob_phase or maximum_jobs >= 2
			participation.append({"fixture": "moving", "tick": tick, "configured": configured, "observed": observed,
				"available": stats["values"].worker_threads_observed_available,
				"maximum_phase_jobs": maximum_jobs, "scheduled_cores": stats["values"].scheduled_cores})
			_check_copy(world, stats)
		# Logical authority must agree. Observed participation is intentionally not
		# compared: which native threads claim jobs is a scheduling observation.
		expect(worlds[0].get_physical_state_hash() == worlds[1].get_physical_state_hash(),
			"configured one/four Worlds retain identical physical authority")
	expect(multijob_phase, "configured-four owner executes genuine multiple-job phases")
	_check_idle()
	_check_serial_unmeasured()
	_check_quarantine()
	print("NATIVE_WORKER_PARTICIPATION: ", JSON.stringify(participation))
	_finish()

func _check_shape(stats: Dictionary, configured: int, available: bool = true) -> void:
	expect(stats.ok and stats["values"].worker_threads_configured is int
		and stats["values"].worker_threads_observed is int
		and stats["values"].worker_threads_observed_available is bool
		and stats["values"].worker_threads_observed_available == available
		and stats["values"].worker_threads_configured == configured,
		"configured and observed counts are exact copied integer fields")
	expect(stats.unavailable.has("per-worker utilization")
		and stats.scope.contains("maximum distinct participants in one dispatch")
		and stats.scope.contains("SerialInPlace participation is unmeasured")
		and stats.scope.contains("not per-worker utilization"), "participant-count scope preserves utilization qualification")

func _check_copy(world: Variant, stats: Dictionary) -> void:
	var bytes_before: PackedByteArray = bridge.export_physical_state(world)
	var quantity_before: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(512, 128))
	expect(int(quantity_before.get("water_integer", 0)) > 0, "read-only quantity control contains actual Water")
	var completed: int = int(world.get_tick_index())
	var attempted: int = int(world.get_attempted_tick_index())
	var revision: int = int(world.get_revision())
	var pristine: Dictionary = stats.duplicate(true)
	for repeat: int in range(3):
		expect(bridge.inspect_statistics(world) == pristine, "repeated copied statistics preserve their complete value")
	stats["values"].worker_threads_configured = -99
	stats["values"].worker_threads_observed = -98
	stats["values"].worker_threads_observed_available = false
	stats.phase_jobs_last_tick[0] = -97
	stats.unavailable.clear()
	expect(bridge.inspect_statistics(world) == pristine, "mutating copied worker values and nested arrays cannot alter native statistics")
	expect(not bytes_before.is_empty() and bridge.export_physical_state(world) == bytes_before,
		"statistics do not change complete native physical bytes")
	expect(world.water_experiment_observation(Vector2i.ZERO, Vector2i(512, 128)) == quantity_before,
		"statistics preserve Water quantity and authoritative observation")
	expect(int(world.get_tick_index()) == completed and int(world.get_attempted_tick_index()) == attempted
		and int(world.get_revision()) == revision, "statistics do not tick, retry, or dirty the World")

func _check_idle() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers": 4}), "idle configured-four owner constructs")
	world.set_simulation_window_enabled(false)
	# Demo construction requires a nonempty command list; one explicit Empty
	# carve preserves a genuinely empty native World without inventing work.
	expect(bridge.build_world(world, PackedInt32Array([0, 0, 1, 1, 0])) and world.simulation_tick(),
		"empty native World completes its idle tick")
	var stats: Dictionary = bridge.inspect_statistics(world)
	expect(stats.ok and stats.completed_tick == 1 and stats["values"].scheduled_cores == 0
		and stats["values"].worker_threads_configured == 4 and stats["values"].worker_threads_observed == 0
		and stats["values"].worker_threads_observed_available,
		"completed idle tick reports zero actual participants despite configured-four pool")
	participation.append({"fixture": "idle", "tick": stats.completed_tick,
		"configured": stats["values"].worker_threads_configured, "observed": stats["values"].worker_threads_observed,
		"available": stats["values"].worker_threads_observed_available,
		"scheduled_cores": stats["values"].scheduled_cores})

func _check_serial_unmeasured() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	# Native admission permits multiple workers only for the phased backend.
	if not expect(world.diagnostic_reset({"workers": 1, "serial": true}), "supported SerialInPlace control constructs"):
		return
	world.set_simulation_window_enabled(false)
	expect(bridge.build_world(world, PackedInt32Array([32, 20, 8, 4, 2, 160, 20, 8, 4, 3]))
		and world.simulation_tick(), "unmeasured SerialInPlace backend completes real work")
	var stats: Dictionary = bridge.inspect_statistics(world)
	_check_shape(stats, 1, false)
	expect(stats.completed_tick == 1 and stats["values"].visited_cells > 0 and stats["values"].moved_cells > 0
		and stats["values"].worker_threads_observed == 0 and not stats["values"].worker_threads_observed_available,
		"SerialInPlace raw zero is unavailable participation, not idle proof")
	participation.append({"fixture": "serial-unmeasured", "tick": stats.completed_tick,
		"configured": stats["values"].worker_threads_configured, "observed": stats["values"].worker_threads_observed,
		"available": stats["values"].worker_threads_observed_available,
		"visited_cells": stats["values"].visited_cells, "moved_cells": stats["values"].moved_cells})

func _check_quarantine() -> void:
	var previous: Variant = ProjectSettings.get_setting("cybersand/native_active_core_capacity", null)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", 1)
	var limited: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", previous)
	limited.set_simulation_window_enabled(false)
	expect(bridge.build_world(limited, PackedInt32Array([20, 20, 1, 1, 2, 160, 20, 1, 1, 2])), "capacity-refusal fixture builds")
	expect(not limited.simulation_tick() and limited.has_failed(), "real failed native tick quarantines its statistics")
	var attempted: int = int(limited.get_attempted_tick_index())
	var rejected: Dictionary = bridge.inspect_statistics(limited)
	expect(not rejected.ok and not rejected.has("values") and not rejected.has("completed_tick")
		and not rejected.error.is_empty() and int(limited.get_attempted_tick_index()) == attempted,
		"quarantined worker counts refuse without partial data or retry")
	expect(not bridge.inspect_statistics(null).ok, "null owner supplies no worker statistics")

func _finish() -> void:
	print("NATIVE_WORKER_OBSERVATION: %d assertions; %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
