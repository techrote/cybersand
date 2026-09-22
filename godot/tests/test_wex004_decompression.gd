extends SceneTree

const DecompressionDiagnostic = preload("res://scripts/decompression_diagnostic.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("WEX-004: " + message)


func _world() -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	_check(world != null, "native world unavailable")
	if world != null:
		_check(world.diagnostic_reset({"workers": 1}), "diagnostic reset failed")
	return world


func _source(pressure_pa: float = 202650.0, amount: float = 8.0) -> Dictionary:
	return {
		"region_id": 1,
		"generation": 7,
		"pressure_pa": pressure_pa,
		"amount": amount,
	}


func _opening(
	opening_id: int,
	position: Vector2,
	normal: Vector2,
	destination_pressure_pa: float = 101325.0,
	area: float = 1.0,
	opening_generation: int = 11,
	destination_generation: int = 13
) -> Dictionary:
	return {
		"id": opening_id,
		"generation": opening_generation,
		"destination_region_id": 100 + opening_id,
		"destination_generation": destination_generation,
		"position": position,
		"normal": normal,
		"area": area,
		"destination_pressure_pa": destination_pressure_pa,
	}


func _live_generations(
	opening_count: int,
	opening_generation: int = 11,
	destination_generation: int = 13
) -> PackedInt32Array:
	var values := PackedInt32Array()
	for _index: int in range(opening_count):
		values.append(opening_generation)
		values.append(destination_generation)
	return values


func _simple_cell_case(
	opening: Vector2i,
	target: Vector2i,
	normal: Vector2
) -> Dictionary:
	var world: Object = _world()
	if world == null:
		return {}
	var model := DecompressionDiagnostic.new()
	_check(
		world.diagnostic_fill_rect(target, Vector2i.ONE, CyberCellWorld.SAND),
		"D0 fill failed"
	)
	_check(
		model.begin(world, _source(), [_opening(1, Vector2(opening), normal)]),
		"D0 registration failed"
	)
	var metrics: Dictionary = model.step(
		world, PackedFloat32Array(), 7, _live_generations(1)
	)
	var move_step := Vector2i(
		roundi(normal.normalized().x),
		roundi(normal.normalized().y)
	)
	if move_step == Vector2i.ZERO:
		move_step = Vector2i(1, 0)
	_check(
		world.material_at(target.x, target.y) == CyberCellWorld.EMPTY,
		"D0 source cell did not relocate"
	)
	var destination: Vector2i = target + move_step
	_check(
		world.material_at(destination.x, destination.y) == CyberCellWorld.SAND,
		"D0 debris did not move along opening normal"
	)
	_check(int(metrics.cellular_moves) == 1, "D0 did not account one relocation")
	_check(float(metrics.applied_work) > 0.0, "D0 applied no bounded work")
	_check(
		float(metrics.current_pressure_pa) < float(metrics.initial_pressure_pa),
		"D0 source pressure did not decay"
	)
	return metrics


func _run_cell_scenarios() -> Dictionary:
	var first: Dictionary = _simple_cell_case(
		Vector2i(100, 100), Vector2i(96, 100), Vector2.RIGHT
	)
	var repeat: Dictionary = _simple_cell_case(
		Vector2i(100, 100), Vector2i(96, 100), Vector2.RIGHT
	)
	var shifted: Dictionary = _simple_cell_case(
		Vector2i(220, 260), Vector2i(216, 260), Vector2.RIGHT
	)
	var mirrored: Dictionary = _simple_cell_case(
		Vector2i(300, 100), Vector2i(304, 100), Vector2.LEFT
	)
	_check(
		int(first.cellular_moves) == int(repeat.cellular_moves),
		"D0 repeat changed move count"
	)
	_check(
		is_equal_approx(float(first.applied_work), float(repeat.applied_work)),
		"D0 repeat changed work"
	)
	_check(
		int(shifted.cellular_moves) == int(first.cellular_moves),
		"D0 shifted case changed outcome"
	)
	_check(
		int(mirrored.cellular_moves) == int(first.cellular_moves),
		"D0 mirrored case changed outcome"
	)

	# D1: a direct hard obstruction suppresses the target rather than creating
	# through-wall attraction.
	var blocked: Object = _world()
	var blocked_model := DecompressionDiagnostic.new()
	_check(
		blocked.diagnostic_fill_rect(
			Vector2i(96, 100), Vector2i.ONE, CyberCellWorld.SAND
		),
		"D1 debris fill failed"
	)
	_check(
		blocked.diagnostic_fill_rect(
			Vector2i(98, 100), Vector2i.ONE, CyberCellWorld.WALL
		),
		"D1 wall fill failed"
	)
	_check(
		blocked_model.begin(
			blocked, _source(), [_opening(1, Vector2(100, 100), Vector2.RIGHT)]
		),
		"D1 registration failed"
	)
	var blocked_metrics: Dictionary = blocked_model.step(
		blocked, PackedFloat32Array(), 7, _live_generations(1)
	)
	_check(
		blocked.material_at(96, 100) == CyberCellWorld.SAND,
		"D1 moved debris through blocked path"
	)
	_check(
		int(blocked_metrics.cellular_moves) == 0,
		"D1 accounted a through-wall move"
	)
	_check(
		int(blocked_metrics.occlusion_rejections) > 0,
		"D1 did not observe occlusion rejection"
	)

	var blocked_shifted: Object = _world()
	var blocked_shifted_model := DecompressionDiagnostic.new()
	_check(
		blocked_shifted.diagnostic_fill_rect(
			Vector2i(216, 260), Vector2i.ONE, CyberCellWorld.SAND
		),
		"D1 shifted debris fill failed"
	)
	_check(
		blocked_shifted.diagnostic_fill_rect(
			Vector2i(218, 260), Vector2i.ONE, CyberCellWorld.WALL
		),
		"D1 shifted wall fill failed"
	)
	_check(
		blocked_shifted_model.begin(
			blocked_shifted,
			_source(),
			[_opening(1, Vector2(220, 260), Vector2.RIGHT)]
		),
		"D1 shifted registration failed"
	)
	var blocked_shifted_metrics: Dictionary = blocked_shifted_model.step(
		blocked_shifted, PackedFloat32Array(), 7, _live_generations(1)
	)
	_check(
		blocked_shifted.material_at(216, 260) == CyberCellWorld.SAND
		and int(blocked_shifted_metrics.cellular_moves) == 0
		and int(blocked_shifted_metrics.occlusion_rejections) > 0,
		"D1 shifted control changed obstacle outcome"
	)

	# D2: an offset target moves with the opening normal, not diagonally toward
	# the breach point.
	var offset: Object = _world()
	var offset_model := DecompressionDiagnostic.new()
	_check(
		offset.diagnostic_fill_rect(
			Vector2i(96, 103), Vector2i.ONE, CyberCellWorld.DUST
		),
		"D2 debris fill failed"
	)
	_check(
		offset_model.begin(
			offset, _source(), [_opening(1, Vector2(100, 100), Vector2.RIGHT)]
		),
		"D2 registration failed"
	)
	var offset_metrics: Dictionary = offset_model.step(
		offset, PackedFloat32Array(), 7, _live_generations(1)
	)
	_check(
		offset.material_at(96, 103) == CyberCellWorld.EMPTY,
		"D2 source did not move"
	)
	_check(
		offset.material_at(97, 103) == CyberCellWorld.DUST,
		"D2 became point-attraction instead of normal-directed outflow"
	)
	_check(int(offset_metrics.cellular_moves) == 1, "D2 accounting mismatch")

	var offset_mirrored: Object = _world()
	var offset_mirrored_model := DecompressionDiagnostic.new()
	_check(
		offset_mirrored.diagnostic_fill_rect(
			Vector2i(304, 103), Vector2i.ONE, CyberCellWorld.DUST
		),
		"D2 mirrored debris fill failed"
	)
	_check(
		offset_mirrored_model.begin(
			offset_mirrored,
			_source(),
			[_opening(1, Vector2(300, 100), Vector2.LEFT)]
		),
		"D2 mirrored registration failed"
	)
	var offset_mirrored_metrics: Dictionary = offset_mirrored_model.step(
		offset_mirrored, PackedFloat32Array(), 7, _live_generations(1)
	)
	_check(
		offset_mirrored.material_at(304, 103) == CyberCellWorld.EMPTY
		and offset_mirrored.material_at(303, 103) == CyberCellWorld.DUST
		and int(offset_mirrored_metrics.cellular_moves) == 1,
		"D2 mirrored case changed normal-directed outcome"
	)

	return {
		"first": first,
		"blocked": blocked_metrics,
		"blocked_shifted": blocked_shifted_metrics,
		"offset": offset_metrics,
		"offset_mirrored": offset_mirrored_metrics,
	}


func _run_budget_and_stale_scenarios() -> Dictionary:
	# D5: reverse input order intentionally. Registration must sort identity and
	# partition one finite source budget.
	var shared: Object = _world()
	var shared_model := DecompressionDiagnostic.new()
	_check(
		shared.diagnostic_fill_rect(
			Vector2i(96, 96), Vector2i.ONE, CyberCellWorld.SALT
		),
		"D5 first fill failed"
	)
	_check(
		shared.diagnostic_fill_rect(
			Vector2i(96, 104), Vector2i.ONE, CyberCellWorld.GUNPOWDER
		),
		"D5 second fill failed"
	)
	var openings: Array = [
		_opening(20, Vector2(100, 104), Vector2.RIGHT, 0.0, 2.0),
		_opening(10, Vector2(100, 96), Vector2.RIGHT, 0.0, 1.0),
	]
	_check(
		shared_model.begin(shared, _source(202650.0, 20.0), openings),
		"D5 registration failed"
	)
	var registered: Dictionary = shared_model.metrics()
	var events: Array = registered.events
	_check(events.size() == 2, "D5 event count mismatch")
	if events.size() == 2:
		_check(
			int(events[0].opening_id) == 10 and int(events[1].opening_id) == 20,
			"D5 opening order is not canonical"
		)
		var sum_budget: float = (
			float(events[0].initial_budget) + float(events[1].initial_budget)
		)
		_check(
			is_equal_approx(sum_budget, float(registered.initial_budget)),
			"D5 duplicated source budget"
		)
	_check(
		float(registered.initial_budget) <= 12.0 + 0.00001,
		"D5 exceeded source budget cap"
	)
	var shared_metrics: Dictionary = shared_model.step(
		shared, PackedFloat32Array(), 7, _live_generations(2)
	)
	_check(
		float(shared_metrics.last_step_applied_work) <= 2.5 + 0.00001,
		"D5 exceeded global per-step work cap"
	)
	_check(
		is_equal_approx(
			float(shared_metrics.remaining_budget),
			float(shared_metrics.initial_budget) - float(shared_metrics.applied_work)
		),
		"D5 source work ledger does not close"
	)

	var shared_shifted: Object = _world()
	var shared_shifted_model := DecompressionDiagnostic.new()
	_check(
		shared_shifted.diagnostic_fill_rect(
			Vector2i(216, 96), Vector2i.ONE, CyberCellWorld.SALT
		),
		"D5 shifted first fill failed"
	)
	_check(
		shared_shifted.diagnostic_fill_rect(
			Vector2i(216, 104), Vector2i.ONE, CyberCellWorld.GUNPOWDER
		),
		"D5 shifted second fill failed"
	)
	var shifted_openings: Array = [
		_opening(20, Vector2(220, 104), Vector2.RIGHT, 0.0, 2.0),
		_opening(10, Vector2(220, 96), Vector2.RIGHT, 0.0, 1.0),
	]
	_check(
		shared_shifted_model.begin(
			shared_shifted, _source(202650.0, 20.0), shifted_openings
		),
		"D5 shifted registration failed"
	)
	var shared_shifted_registered: Dictionary = shared_shifted_model.metrics()
	var shared_shifted_metrics: Dictionary = shared_shifted_model.step(
		shared_shifted, PackedFloat32Array(), 7, _live_generations(2)
	)
	_check(
		is_equal_approx(
			float(shared_shifted_registered.initial_budget),
			float(registered.initial_budget)
		)
		and is_equal_approx(
			float(shared_shifted_metrics.last_step_applied_work),
			float(shared_metrics.last_step_applied_work)
		),
		"D5 shifted case changed shared-budget accounting"
	)

	# Registration capacity is an explicit refusal.
	var capacity: Object = _world()
	var capacity_model := DecompressionDiagnostic.new()
	var too_many: Array = []
	for index: int in range(5):
		too_many.append(
			_opening(index + 1, Vector2(100, 100 + index), Vector2.RIGHT)
		)
	_check(
		not capacity_model.begin(capacity, _source(), too_many),
		"capacity overflow was accepted"
	)
	var capacity_metrics: Dictionary = capacity_model.metrics()
	_check(
		int(capacity_metrics.capacity_refusals) == 1,
		"capacity refusal was not recorded"
	)

	# D6a: any external diagnostic-world mutation is a conservative authority
	# invalidation for Arm B. A wall mutation must cancel before work.
	var stale_topology: Object = _world()
	var stale_topology_model := DecompressionDiagnostic.new()
	_check(
		stale_topology.diagnostic_fill_rect(
			Vector2i(96, 100), Vector2i.ONE, CyberCellWorld.SAND
		),
		"D6 fill failed"
	)
	_check(
		stale_topology_model.begin(
			stale_topology,
			_source(),
			[_opening(1, Vector2(100, 100), Vector2.RIGHT)]
		),
		"D6 registration failed"
	)
	_check(
		stale_topology.diagnostic_fill_rect(
			Vector2i(400, 400), Vector2i.ONE, CyberCellWorld.WALL
		),
		"D6 topology mutation failed"
	)
	var stale_metrics: Dictionary = stale_topology_model.step(
		stale_topology, PackedFloat32Array(), 7, _live_generations(1)
	)
	_check(
		int(stale_metrics.stale_cancellations) == 1,
		"D6 topology change did not cancel event"
	)
	_check(
		float(stale_metrics.last_step_applied_work) == 0.0,
		"D6 applied stale work"
	)
	_check(
		stale_topology.material_at(96, 100) == CyberCellWorld.SAND,
		"D6 moved debris after cancellation"
	)

	# D6b: opening-generation mismatch also cancels before work.
	var stale_generation: Object = _world()
	var stale_generation_model := DecompressionDiagnostic.new()
	_check(
		stale_generation.diagnostic_fill_rect(
			Vector2i(96, 100), Vector2i.ONE, CyberCellWorld.SAND
		),
		"D6 generation fill failed"
	)
	_check(
		stale_generation_model.begin(
			stale_generation,
			_source(),
			[_opening(1, Vector2(100, 100), Vector2.RIGHT)]
		),
		"D6 generation registration failed"
	)
	var bad_generations := PackedInt32Array([12, 13])
	var generation_metrics: Dictionary = stale_generation_model.step(
		stale_generation, PackedFloat32Array(), 7, bad_generations
	)
	_check(
		int(generation_metrics.stale_cancellations) == 1,
		"D6 generation mismatch did not cancel"
	)
	_check(
		float(generation_metrics.last_step_applied_work) == 0.0,
		"D6 generation mismatch applied work"
	)

	return {
		"shared": shared_metrics,
		"shared_shifted": shared_shifted_metrics,
		"capacity": capacity_metrics,
		"stale_topology": stale_metrics,
		"stale_generation": generation_metrics,
	}


func _run_pressure_controls() -> Dictionary:
	# D7: differential below the frozen threshold creates no event budget.
	var low: Object = _world()
	var low_model := DecompressionDiagnostic.new()
	_check(
		low.diagnostic_fill_rect(
			Vector2i(96, 100), Vector2i.ONE, CyberCellWorld.SAND
		),
		"D7 fill failed"
	)
	_check(
		low_model.begin(
			low,
			_source(101325.0, 8.0),
			[_opening(1, Vector2(100, 100), Vector2.RIGHT, 101200.0)]
		),
		"D7 registration failed"
	)
	var low_registered: Dictionary = low_model.metrics()
	_check(
		float(low_registered.initial_budget) == 0.0,
		"D7 near-equal pressure received work budget"
	)
	var low_metrics: Dictionary = low_model.step(
		low, PackedFloat32Array(), 7, _live_generations(1)
	)
	_check(float(low_metrics.applied_work) == 0.0, "D7 generated jitter work")
	_check(
		low.material_at(96, 100) == CyberCellWorld.SAND,
		"D7 moved debris"
	)

	# D8: vacuum is zero absolute pressure and remains finite/capped.
	var vacuum: Object = _world()
	var vacuum_model := DecompressionDiagnostic.new()
	_check(
		vacuum.diagnostic_fill_rect(
			Vector2i(96, 100), Vector2i.ONE, CyberCellWorld.SAND
		),
		"D8 fill failed"
	)
	_check(
		vacuum_model.begin(
			vacuum,
			_source(202650.0, 100.0),
			[_opening(1, Vector2(100, 100), Vector2.RIGHT, 0.0, 64.0)]
		),
		"D8 registration failed"
	)
	var vacuum_registered: Dictionary = vacuum_model.metrics()
	_check(
		float(vacuum_registered.initial_budget) <= 12.0 + 0.00001,
		"D8 exceeded finite source cap"
	)
	var vacuum_metrics: Dictionary = vacuum_model.step(
		vacuum, PackedFloat32Array(), 7, _live_generations(1)
	)
	_check(
		is_finite(float(vacuum_metrics.current_pressure_pa)),
		"D8 pressure became non-finite"
	)
	_check(
		float(vacuum_metrics.current_pressure_pa) >= 0.0,
		"D8 produced negative absolute pressure"
	)
	_check(
		float(vacuum_metrics.last_step_applied_work) <= 1.25 + 0.00001,
		"D8 exceeded event work cap"
	)
	_check(
		int(vacuum_metrics.cellular_moves) <= 32,
		"D8 exceeded cellular move cap"
	)
	return {"low": low_metrics, "vacuum": vacuum_metrics}


func _body_states(
	center: Vector2 = Vector2(96, 100),
	sample_serial: int = 1
) -> PackedFloat32Array:
	var states := PackedFloat32Array()
	CyberRigidBodyCoupling.append_input(
		states,
		1,
		center,
		0.0,
		Vector2(4, 4),
		Vector2.ZERO,
		0.0,
		1.0,
		sample_serial
	)
	return states


func _run_decay_scenario() -> Dictionary:
	# D0 lifetime evidence: hold one generic body value snapshot in the local
	# field so event accounting can be observed for the complete frozen 12-step
	# horizon without changing geometry or the force law.
	var world: Object = _world()
	var model := DecompressionDiagnostic.new()
	_check(
		model.begin(
			world,
			_source(202650.0, 100.0),
			[_opening(1, Vector2(100, 100), Vector2.RIGHT, 0.0)]
		),
		"D0 decay registration failed"
	)
	var states: PackedFloat32Array = _body_states()
	var work_trace: Array[float] = []
	var pressure_trace: Array[float] = []
	for _step: int in range(13):
		var metrics: Dictionary = model.step(
			world, states, 7, _live_generations(1)
		)
		work_trace.append(float(metrics.last_step_applied_work))
		pressure_trace.append(float(metrics.current_pressure_pa))
	_check(work_trace.size() == 13, "D0 decay trace length mismatch")
	_check(work_trace[0] > 0.0, "D0 decay trace never started")
	var strict_decay_seen: bool = false
	for index: int in range(1, 12):
		_check(
			work_trace[index] <= work_trace[index - 1] + 0.00001,
			"D0 work increased inside the frozen lifetime envelope"
		)
		if work_trace[index] < work_trace[index - 1] - 0.00001:
			strict_decay_seen = true
	_check(strict_decay_seen, "D0 lifetime envelope never produced visible decay")
	_check(
		absf(work_trace[12]) <= 0.000001,
		"D0 event applied work after the 12-step lifetime"
	)
	var final_metrics: Dictionary = model.metrics()
	var events: Array = final_metrics.events
	_check(events.size() == 1, "D0 decay event disappeared from evidence")
	if events.size() == 1:
		_check(int(events[0].age) == 12, "D0 event age did not reach 12")
		_check(not bool(events[0].active), "D0 event remained active after lifetime")
	_check(
		pressure_trace[11] < pressure_trace[0]
		and pressure_trace[11] >= 0.0,
		"D0 source pressure did not decay finitely"
	)
	return {
		"work_trace": work_trace,
		"pressure_trace": pressure_trace,
		"metrics": final_metrics,
	}


func _percentile(sorted_values: Array[int], fraction: float) -> int:
	if sorted_values.is_empty():
		return 0
	var index: int = clampi(
		ceili(float(sorted_values.size()) * fraction) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]


func _run_cost_population() -> Dictionary:
	# 64 source-identical first-step repetitions. Setup is intentionally outside
	# the timed interval; the population measures only the bounded event step.
	var timings_usec: Array[int] = []
	for iteration: int in range(64):
		var world: Object = _world()
		var model := DecompressionDiagnostic.new()
		_check(
			model.begin(
				world,
				_source(202650.0, 100.0),
				[_opening(1, Vector2(100, 100), Vector2.RIGHT, 0.0, 64.0)]
			),
			"cost population registration failed"
		)
		var states: PackedFloat32Array = _body_states(Vector2(96, 100), iteration + 1)
		var started_usec: int = Time.get_ticks_usec()
		var metrics: Dictionary = model.step(
			world, states, 7, _live_generations(1)
		)
		var elapsed_usec: int = Time.get_ticks_usec() - started_usec
		timings_usec.append(elapsed_usec)
		_check(
			float(metrics.last_step_applied_work) <= 1.25 + 0.00001,
			"cost population exceeded per-event work cap"
		)
	timings_usec.sort()
	return {
		"count": timings_usec.size(),
		"p50_usec": _percentile(timings_usec, 0.50),
		"p95_usec": _percentile(timings_usec, 0.95),
		"p99_usec": _percentile(timings_usec, 0.99),
		"max_usec": timings_usec[-1] if not timings_usec.is_empty() else 0,
	}


func _run_rapier_scenario() -> Dictionary:
	# D3: ordinary rectangle through the existing main-thread Rapier bridge.
	var world: Object = _world()
	if world == null:
		return {}
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(64, 64)
	root.add_child(viewport)

	var body := RigidBody2D.new()
	body.mass = 1.0
	body.gravity_scale = 0.0
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.position = Vector2(96, 100)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4, 4)
	collision.shape = shape
	body.add_child(collision)
	viewport.add_child(body)
	await process_frame

	var bridge := CyberRapierPhysicsBridge.new()
	var bodies: Array[RigidBody2D] = [body]
	_check(
		bridge.initialize(
			viewport.world_2d.space,
			bodies,
			PackedVector2Array([Vector2(4, 4)])
		) == OK,
		"D3 Rapier bridge initialization failed"
	)
	bridge.reset_body(0, Vector2(96, 100), 0.0)
	var states: PackedFloat32Array = bridge.pack_body_states()
	var model := DecompressionDiagnostic.new()
	_check(
		model.begin(
			world,
			_source(),
			[_opening(1, Vector2(100, 100), Vector2.RIGHT, 0.0)]
		),
		"D3 registration failed"
	)
	var metrics: Dictionary = model.step(
		world, states, 7, _live_generations(1)
	)
	var results: PackedFloat32Array = model.body_results()
	_check(
		results.size() >= CyberRigidBodyCoupling.RESULT_STRIDE,
		"D3 produced no body result"
	)
	if results.size() >= CyberRigidBodyCoupling.RESULT_STRIDE:
		_check(
			results[CyberRigidBodyCoupling.RESULT_IMPULSE_X] > 0.0,
			"D3 impulse did not point outward"
		)
		_check(
			absf(results[CyberRigidBodyCoupling.RESULT_IMPULSE_Y]) < 0.00001,
			"D3 impulse became point-attraction"
		)
	var before: Vector2 = bridge.body_transform(0).origin
	_check(
		bridge.apply_cellular_results(1, results) == 1,
		"D3 bridge did not apply result"
	)
	bridge.step()
	var after: Vector2 = bridge.body_transform(0).origin
	_check(after.x > before.x, "D3 real Rapier body did not move outward")
	_check(
		absf(after.y - before.y) < 0.01,
		"D3 body acquired unintended vertical motion"
	)
	_check(float(metrics.rapier_work) > 0.0, "D3 Rapier work unaccounted")
	_check(
		float(metrics.last_step_applied_work) <= 1.25 + 0.00001,
		"D3 exceeded event cap"
	)
	bridge.shutdown()
	viewport.queue_free()
	return metrics


func _run() -> void:
	var cell: Dictionary = _run_cell_scenarios()
	var budget: Dictionary = _run_budget_and_stale_scenarios()
	var pressure: Dictionary = _run_pressure_controls()
	var decay: Dictionary = _run_decay_scenario()
	var cost: Dictionary = _run_cost_population()
	var rapier: Dictionary = await _run_rapier_scenario()
	var report := {
		"ok": not _failed,
		"cell_applied": (
			float(cell.first.applied_work) if cell.has("first") else -1.0
		),
		"blocked_occlusions": (
			int(cell.blocked.occlusion_rejections) if cell.has("blocked") else -1
		),
		"shared_initial_budget": (
			float(budget.shared.initial_budget) if budget.has("shared") else -1.0
		),
		"shared_applied": (
			float(budget.shared.applied_work) if budget.has("shared") else -1.0
		),
		"vacuum_budget": (
			float(pressure.vacuum.initial_budget) if pressure.has("vacuum") else -1.0
		),
		"rapier_work": (
			float(rapier.rapier_work) if not rapier.is_empty() else -1.0
		),
		"decay_work_trace": decay.work_trace if decay.has("work_trace") else [],
		"decay_final_pressure_pa": (
			float(decay.metrics.current_pressure_pa)
			if decay.has("metrics") else -1.0
		),
		"cost": cost,
		"platform": OS.get_name(),
		"godot": str(Engine.get_version_info().get("string", "")),
		"workers": 1,
	}
	print("WEX004_DECOMPRESSION ", JSON.stringify(report))
	quit(1 if _failed else 0)
