extends SceneTree

# ACT-004 capacity/identity regression for both copied rectangle adapters.
# No joint or material tuning is inferred from these protocol fixtures.
var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("ACT-004 body capacity: " + message)


func _append(states: PackedFloat32Array, id: int, center: Vector2, serial: int) -> void:
	CyberRigidBodyCoupling.append_input(
		states, id, center, 0.0, Vector2(4, 4), Vector2(0, 1), 0.0, 1.0, serial
	)


func _center(id: int) -> Vector2:
	return Vector2(40 + ((id - 1) % 8) * 12, 40 + ((id - 1) / 8) * 12)


func _fresh_fallback() -> CyberCellWorld:
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
	world.cadence_lod_enabled = false
	return world


func _fill(world: Object, native: bool, cell: Vector2i, material: int) -> void:
	if native:
		_check(world.diagnostic_fill_rect(cell, Vector2i.ONE, material), "native fill failed")
	else:
		world.set_cell(cell.x, cell.y, material)


func _receipt_map(results: PackedFloat32Array) -> Dictionary:
	var rows: Dictionary = {}
	_check(results.size() % CyberRigidBodyCoupling.RESULT_STRIDE == 0, "partial output record")
	for offset: int in range(0, results.size(), CyberRigidBodyCoupling.RESULT_STRIDE):
		var id: int = int(results[offset])
		_check(not rows.has(id), "duplicate receipt for body %d" % id)
		rows[id] = results.slice(offset, offset + CyberRigidBodyCoupling.RESULT_STRIDE)
	return rows


func _exercise(world: Object, native: bool) -> void:
	var label: String = "native" if native else "fallback"
	_check(CyberRigidBodyCoupling.MAX_BODIES == 64, "actor/part capacity is not 8 by 8")
	var states := PackedFloat32Array()
	for id: int in range(1, 65):
		_append(states, id, _center(id), 7)
		# A boundary grain gives each part its own observable upward pressure.
		_fill(world, native, Vector2i(_center(id)) + Vector2i(0, 2), CyberCellWorld.SAND)
	world.prepare_rigid_body_coupling(states, true)
	var rows: Dictionary = _receipt_map(world.rigid_body_results())
	_check(rows.size() == 64, label + " truncated the articulated batch")
	for id: int in range(1, 65):
		_check(rows.has(id), label + " lost body %d" % id)
		_check(
			world.material_at(int(_center(id).x), int(_center(id).y)) == CyberCellWorld.WALL,
			label + " omitted part occupancy %d" % id
		)
		if rows.has(id):
			var row: PackedFloat32Array = rows[id]
			_check(int(row[8]) == 7, label + " changed per-part sample identity")
			_check(row[2] < 0.0 and row[5] > 0.0, label + " lost part boundary response")
			for value: float in row:
				_check(is_finite(value), label + " published non-finite body response")
	if native:
		# This also exercises diagnostic storage above the old 17-entry array.
		var metrics: Array = world.diagnostic_body_metrics()
		_check(metrics.size() == 64, "diagnostic rows do not cover all admitted parts")
		if metrics.size() == 64:
			_check(int(metrics[63][0]) == 64, "highest diagnostic identity was corrupted")

	# Omitting parts removes both endpoints and observations. Empty input also
	# retires sweep history before a later assembly reuses a numeric slot.
	world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	_check(world.rigid_body_results().is_empty(), label + " retained retired receipts")
	for id: int in range(1, 65):
		_check(
			world.material_at(int(_center(id).x), int(_center(id).y)) == CyberCellWorld.EMPTY,
			label + " left a retired mask"
		)
	var first := PackedFloat32Array()
	_append(first, 64, Vector2(200, 200), 8)
	world.prepare_rigid_body_coupling(first, false)
	world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	_fill(world, native, Vector2i(204, 200), CyberCellWorld.SAND)
	var replacement := PackedFloat32Array()
	_append(replacement, 64, Vector2(208, 200), 9)
	world.prepare_rigid_body_coupling(replacement, true)
	_check(
		world.material_at(204, 200) == CyberCellWorld.SAND,
		label + " reused part identity swept through the retired assembly"
	)
	rows = _receipt_map(world.rigid_body_results())
	_check(rows.size() == 1 and rows.has(64), label + " failed clean highest-slot reuse")

	# Keep the first complete valid duplicate. Malformed IDs must not round into
	# another part, and an invalid record must not claim that part's slot.
	world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	var mixed := PackedFloat32Array()
	_append(mixed, 17, Vector2(300, 300), 10)
	_append(mixed, 17, Vector2(310, 300), 11)
	_append(mixed, 65, Vector2(320, 300), 10)
	_append(mixed, 18, Vector2(330, 300), 10)
	mixed[3 * CyberRigidBodyCoupling.INPUT_STRIDE] = 18.5
	_append(mixed, 19, Vector2(340, 300), 10)
	mixed[4 * CyberRigidBodyCoupling.INPUT_STRIDE + 1] = NAN
	_append(mixed, 19, Vector2(350, 300), 10)
	_append(mixed, 20, Vector2(360, 300), 10)
	mixed[6 * CyberRigidBodyCoupling.INPUT_STRIDE + 10] = -1.0
	mixed.append(64.0) # incomplete trailing record
	world.prepare_rigid_body_coupling(mixed, false)
	rows = _receipt_map(world.rigid_body_results())
	_check(rows.size() == 2 and rows.has(17) and rows.has(19), label + " malformed admission")
	_check(world.material_at(300, 300) == CyberCellWorld.WALL, label + " lost first duplicate")
	_check(world.material_at(310, 300) == CyberCellWorld.EMPTY, label + " rasterized later duplicate")
	_check(world.material_at(330, 300) == CyberCellWorld.EMPTY, label + " rounded fractional ID")
	_check(world.material_at(350, 300) == CyberCellWorld.WALL, label + " invalid row reserved a slot")
	if rows.has(17):
		_check(int(rows[17][8]) == 10, label + " duplicate replaced source sample identity")

	# Input work is bounded to 64 complete records. A valid record hidden behind
	# a full invalid batch cannot expand that budget by becoming a 65th record.
	world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	var over_capacity := PackedFloat32Array()
	for _index: int in range(64):
		_append(over_capacity, 0, Vector2.ZERO, 0)
	_append(over_capacity, 64, Vector2(400, 400), 12)
	world.prepare_rigid_body_coupling(over_capacity, false)
	_check(world.rigid_body_results().is_empty(), label + " scanned past its record budget")
	_check(world.material_at(400, 400) == CyberCellWorld.EMPTY, label + " accepted overflow row")

	# Far but finite escaped transforms must not overflow integer raster bounds.
	var escaped := PackedFloat32Array()
	_append(escaped, 64, Vector2(1.0e20, 1.0e20), 13)
	world.prepare_rigid_body_coupling(escaped, false)
	rows = _receipt_map(world.rigid_body_results())
	_check(rows.size() == 1 and rows.has(64), label + " lost escaped-body retirement identity")
	_check(world.material_at(1023, 1023) == CyberCellWorld.EMPTY, label + " escaped body gained edge mask")
	world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	print("ACT004_BODY_CAPACITY ", label, " parts=64 admission/receipts/retirement checked")


func _run() -> void:
	var native: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	_check(native != null, "native adapter unavailable")
	if native != null:
		_check(native.diagnostic_reset({"workers": 1, "telemetry": true}), "native fixture reset")
		_exercise(native, true)
	_exercise(_fresh_fallback(), false)
	if _failures == 0:
		print("ACT-004 body capacity fixtures passed")
	quit(1 if _failures > 0 else 0)
