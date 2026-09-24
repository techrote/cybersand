extends SceneTree

# REM-002 / #81 focused regression for the bounded historical #11 semantics.
# This is not REM-004 production gameplay acceptance.

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("REM-002: " + message)


func _body_states(center: Vector2, velocity_y: float, serial: int) -> PackedFloat32Array:
	var states := PackedFloat32Array()
	CyberRigidBodyCoupling.append_input(
		states,
		1,
		center,
		0.0,
		Vector2(8, 14),
		Vector2(0, velocity_y),
		0.0,
		1.0,
		serial
	)
	return states


func _native_world() -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	_check(world != null, "native world unavailable")
	if world != null:
		_check(world.diagnostic_reset({"workers": 1}), "native diagnostic reset failed")
	return world


func _fill_native(world: Object, material: int) -> void:
	_check(
		world.diagnostic_fill_rect(Vector2i(96, 100), Vector2i(16, 16), material),
		"native support fill failed"
	)


func _native_bearing_and_controls() -> void:
	var states: PackedFloat32Array = _body_states(Vector2(104, 93), 1.0, 1)
	var world: Object = _native_world()
	if world == null:
		return
	_fill_native(world, CyberCellWorld.SAND)
	world.prepare_rigid_body_coupling(states, true)
	var metrics_rows: Array = world.diagnostic_body_metrics()
	_check(metrics_rows.size() == 1, "native bearing produced no body diagnostics")
	if metrics_rows.size() == 1:
		var row: Array = metrics_rows[0]
		_check(row.size() >= 20, "native bearing diagnostics missing support fields")
		if row.size() >= 20:
			_check(float(row[18]) < 0.0, "packed Sand produced no upward bearing")
			_check(int(row[19]) > 0, "packed Sand produced no support samples")
	var result: PackedFloat32Array = world.rigid_body_results()
	_check(
		result.size() >= CyberRigidBodyCoupling.RESULT_STRIDE
		and result[CyberRigidBodyCoupling.RESULT_IMPULSE_Y] < 0.0,
		"native packed Sand produced no bounded upward body result"
	)

	# P5-equivalent support loss: remove the real supporting bed. No cached
	# bearing/collider may survive the next accepted body sample.
	_check(
		world.diagnostic_fill_rect(
			Vector2i(96, 100), Vector2i(16, 16), CyberCellWorld.EMPTY
		),
		"native excavation failed"
	)
	world.prepare_rigid_body_coupling(
		_body_states(Vector2(104, 93), 1.0, 2), true
	)
	metrics_rows = world.diagnostic_body_metrics()
	if metrics_rows.size() == 1 and metrics_rows[0].size() >= 20:
		var excavated: Array = metrics_rows[0]
		_check(int(excavated[19]) == 0, "excavation left stale support samples")
		_check(absf(float(excavated[18])) <= 0.000001, "excavation left stale bearing")

	# Liquids are not granular bearing.
	var water: Object = _native_world()
	if water != null:
		_fill_native(water, CyberCellWorld.WATER)
		water.prepare_rigid_body_coupling(states, true)
		var water_rows: Array = water.diagnostic_body_metrics()
		if water_rows.size() == 1 and water_rows[0].size() >= 20:
			_check(int(water_rows[0][19]) == 0, "Water became granular support")
			_check(absf(float(water_rows[0][18])) <= 0.000001, "Water produced granular bearing")

	# Hard terrain stays a Rapier/static-terrain owner, not granular bearing.
	var hard: Object = _native_world()
	if hard != null:
		_fill_native(hard, CyberCellWorld.WALL)
		hard.prepare_rigid_body_coupling(states, true)
		var hard_rows: Array = hard.diagnostic_body_metrics()
		if hard_rows.size() == 1 and hard_rows[0].size() >= 20:
			_check(int(hard_rows[0][19]) == 0, "hard terrain became granular bearing")
			_check(absf(float(hard_rows[0][18])) <= 0.000001, "hard terrain produced granular bearing")


func _fallback_bearing_and_excavation() -> void:
	var world := CyberCellWorld.new()
	world.cells.fill(CyberCellWorld.EMPTY)
	world.updated_at.fill(0)
	world.quiet_ticks.fill(0)
	world.flow_budget.fill(0)
	world.flow_direction.fill(CyberCellWorld.FLOW_DIRECTION_NONE)
	world.active_blocks.fill(0)
	world.next_active_blocks.fill(0)
	world.block_movable_counts.fill(0)
	world.simulation_window_enabled = false
	for y: int in range(100, 116):
		for x: int in range(96, 112):
			world.set_cell(x, y, CyberCellWorld.SAND)

	world.prepare_rigid_body_coupling(
		_body_states(Vector2(104, 93), 1.0, 1), true
	)
	_check(world.rigid_body_support_counts[1] > 0, "fallback produced no support samples")
	_check(world.rigid_body_bearing_y[1] < 0.0, "fallback produced no bearing")

	for y: int in range(100, 116):
		for x: int in range(96, 112):
			world.set_cell(x, y, CyberCellWorld.EMPTY)
	world.prepare_rigid_body_coupling(
		_body_states(Vector2(104, 93), 1.0, 2), true
	)
	_check(world.rigid_body_support_counts[1] == 0, "fallback excavation left support")
	_check(absf(world.rigid_body_bearing_y[1]) <= 0.000001, "fallback excavation left bearing")


func _result_for_sample(sample_serial: int) -> PackedFloat32Array:
	return PackedFloat32Array([
		1.0,
		0.0,
		-1.0,
		0.0,
		-0.25,
		1.0,
		0.0,
		0.0,
		float(sample_serial),
	])


func _sample_age_contract() -> void:
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(64, 64)
	root.add_child(viewport)

	var body := RigidBody2D.new()
	body.mass = 1.0
	body.gravity_scale = 0.0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 14)
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
			PackedVector2Array([Vector2(8, 14)])
		) == OK,
		"sample-age bridge initialization failed"
	)
	bridge.enable_diagnostics()
	bridge.reset_body(0, Vector2(104, 93), 0.0)

	var first: PackedFloat32Array = bridge.pack_body_states()
	var first_serial: int = roundi(first[CyberRigidBodyCoupling.INPUT_SAMPLE_SERIAL])
	bridge.pack_body_states() # age one
	_check(
		bridge.apply_cellular_results(1, _result_for_sample(first_serial)) == 1,
		"one-sample-old body result was not accepted"
	)
	_check(
		int(bridge.diagnostic_applications[0]) == 1
		and int(bridge.diagnostic_applications[4]) == 0,
		"one-sample-old diagnostic age/stale contract changed"
	)

	var old: PackedFloat32Array = bridge.pack_body_states()
	var old_serial: int = roundi(old[CyberRigidBodyCoupling.INPUT_SAMPLE_SERIAL])
	for _index: int in range(9):
		bridge.pack_body_states()
	_check(
		bridge.apply_cellular_results(2, _result_for_sample(old_serial)) == 0,
		"age-nine body result was accepted"
	)
	_check(
		int(bridge.diagnostic_applications[0]) == 9
		and int(bridge.diagnostic_applications[4]) == 1,
		"stale body result was not reported/rejected"
	)

	bridge.shutdown()
	viewport.queue_free()
	await process_frame


func _p4_p5_current_source() -> void:
	# Old current source reached the deep floor around tick 155. These bounded
	# current-source cases therefore catch disappearance of the narrow #11 repair
	# without turning REM-002 into REM-004.
	var p4_one: Dictionary = await CyberPhysicsCharacterisation.run_case(root, {
		"mode": "barrel",
		"material": CyberCellWorld.SAND,
		"ticks": 600,
		"seed": 0,
		"drop": 1.0,
		"depth": 384,
		"telemetry": true,
	})
	_check(bool(p4_one.get("ok", false)), "P4 one-height fixture failed to execute")
	_check(int(p4_one.get("floor_contact_tick", 0)) < 0, "P4 one-height reached hard floor")
	_check(float(p4_one.get("peak_depth", 999.0)) <= 8.0, "P4 one-height exceeded bounded depth")
	_check(int(p4_one.get("support_samples", 0)) > 0, "P4 one-height observed no real support")
	var one_bearing: Array = p4_one.get("bearing_impulse", [0.0, 0.0])
	_check(one_bearing.size() >= 2 and float(one_bearing[1]) < 0.0, "P4 one-height observed no bearing")

	var p4_four: Dictionary = await CyberPhysicsCharacterisation.run_case(root, {
		"mode": "barrel",
		"material": CyberCellWorld.SAND,
		"ticks": 600,
		"seed": 0,
		"drop": 4.0,
		"depth": 384,
		"telemetry": true,
	})
	_check(bool(p4_four.get("ok", false)), "P4 four-height fixture failed to execute")
	_check(int(p4_four.get("floor_contact_tick", 0)) < 0, "P4 four-height reached hard floor")
	_check(float(p4_four.get("peak_depth", 999.0)) <= 8.0, "P4 four-height exceeded bounded depth")

	var p5: Dictionary = await CyberPhysicsCharacterisation.run_case(root, {
		"mode": "barrel",
		"material": CyberCellWorld.SAND,
		"layout": "excavate",
		"ticks": 900,
		"seed": 0,
		"drop": 1.0,
		"depth": 384,
		"telemetry": true,
	})
	_check(bool(p5.get("ok", false)), "P5 excavation fixture failed to execute")
	_check(int(p5.get("floor_contact_tick", 0)) < 0, "P5 excavation reached hard floor")
	_check(
		float(p5.get("peak_depth", 0.0)) > 8.0,
		"P5 excavation did not release the previously supported body"
	)

	print("REM002_P4P5 ", JSON.stringify({
		"p4_one_peak": p4_one.get("peak_depth"),
		"p4_one_final": p4_one.get("final_depth"),
		"p4_one_support_samples": p4_one.get("support_samples"),
		"p4_four_peak": p4_four.get("peak_depth"),
		"p4_four_final": p4_four.get("final_depth"),
		"p5_peak": p5.get("peak_depth"),
		"p5_final": p5.get("final_depth"),
		"p5_support_samples": p5.get("support_samples"),
	}))


func _run() -> void:
	_native_bearing_and_controls()
	_fallback_bearing_and_excavation()
	await _sample_age_contract()
	await _p4_p5_current_source()
	if not _failed:
		print("REM-002 bounded body/granular reconciliation passed")
	quit(1 if _failed else 0)
