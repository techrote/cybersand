extends SceneTree

# Run with:
#   godot --headless --path godot --script res://tests/test_cell_world.gd
# This remains a focused interaction suite rather than a substitute for manual
# gameplay testing or full-scene performance measurement.

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_smoke_displaces(CyberCellWorld.WATER, "Water")
	_test_smoke_displaces(CyberCellWorld.SAND, "Sand")
	_test_smoke_volume_displaces(CyberCellWorld.WATER, "Water")
	_test_smoke_volume_displaces(CyberCellWorld.SAND, "Sand")
	_test_water_spreads_without_a_heap()
	_test_wide_water_mound_levels_quickly()
	_test_rigid_body_mask_blocks_material()
	_test_rigid_body_sweep_displaces_without_leaving_a_phantom_mask()
	_test_excluded_active_grains_do_not_support()
	_test_ejection_does_not_cross_another_body()
	_test_vertical_chain_does_not_form_empty_scanlines()
	if _failures == 0:
		print("11 Godot interaction tests passed")
	quit(_failures)


func _fresh_world() -> CyberCellWorld:
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
	world.cadence_lod_enabled = false
	return world


func _test_smoke_displaces(upper_material: int, label: String) -> void:
	var world: CyberCellWorld = _fresh_world()
	world.set_cell(100, 100, upper_material)
	world.set_cell(100, 101, CyberCellWorld.SMOKE)
	world.simulation_tick()
	_expect(
		world.material_at(100, 100) == CyberCellWorld.SMOKE,
		"Smoke did not rise through %s" % label
	)
	_expect(
		world.material_at(100, 101) == upper_material,
		"%s did not move down during density exchange" % label
	)


func _test_smoke_volume_displaces(upper_material: int, label: String) -> void:
	var world: CyberCellWorld = _fresh_world()
	const LEFT: int = 400
	const RIGHT: int = 404
	const FLOOR_Y: int = 140
	for x: int in range(LEFT, RIGHT + 1):
		world.set_cell(x, FLOOR_Y, CyberCellWorld.WALL)
	for y: int in range(100, FLOOR_Y + 1):
		world.set_cell(LEFT, y, CyberCellWorld.WALL)
		world.set_cell(RIGHT, y, CyberCellWorld.WALL)
	for y: int in range(125, 128):
		for x: int in range(LEFT + 1, RIGHT):
			world.set_cell(x, y, upper_material)
	for y: int in range(128, 131):
		for x: int in range(LEFT + 1, RIGHT):
			world.set_cell(x, y, CyberCellWorld.SMOKE)

	for _tick: int in range(20):
		world.simulation_tick()

	var smoke_count: int = 0
	var upper_count: int = 0
	var deepest_smoke: int = -1
	var shallowest_upper: int = CyberCellWorld.WORLD_HEIGHT
	for y: int in range(100, FLOOR_Y):
		for x: int in range(LEFT + 1, RIGHT):
			var material_id: int = world.material_at(x, y)
			if material_id == CyberCellWorld.SMOKE:
				smoke_count += 1
				deepest_smoke = maxi(deepest_smoke, y)
			elif material_id == upper_material:
				upper_count += 1
				shallowest_upper = mini(shallowest_upper, y)
	_expect(smoke_count == 9, "Smoke count changed while crossing %s" % label)
	_expect(upper_count == 9, "%s count changed during density exchange" % label)
	_expect(
		deepest_smoke < shallowest_upper,
		"%s remained supported on a trapped Smoke volume" % label
	)


func _test_water_spreads_without_a_heap() -> void:
	var world: CyberCellWorld = _fresh_world()
	const LEFT: int = 200
	const RIGHT: int = 260
	const FLOOR_Y: int = 180
	for x: int in range(LEFT, RIGHT + 1):
		world.set_cell(x, FLOOR_Y, CyberCellWorld.WALL)
	for y: int in range(120, FLOOR_Y + 1):
		world.set_cell(LEFT, y, CyberCellWorld.WALL)
		world.set_cell(RIGHT, y, CyberCellWorld.WALL)
	for y: int in range(169, 179):
		for x: int in range(228, 232):
			world.set_cell(x, y, CyberCellWorld.WATER)

	for _tick: int in range(600):
		world.simulation_tick()

	var water_count: int = 0
	var maximum_column_height: int = 0
	for x: int in range(LEFT + 1, RIGHT):
		var column_height: int = 0
		for y: int in range(120, FLOOR_Y):
			if world.material_at(x, y) == CyberCellWorld.WATER:
				water_count += 1
				column_height += 1
		maximum_column_height = maxi(maximum_column_height, column_height)
	_expect(water_count == 40, "Water count changed while leveling")
	_expect(maximum_column_height <= 1, "free Water retained a heap instead of self-leveling")


func _test_wide_water_mound_levels_quickly() -> void:
	var world: CyberCellWorld = _fresh_world()
	const LEFT: int = 100
	const RIGHT: int = 420
	const FLOOR_Y: int = 320
	const CENTRE_X: int = 260
	const HALF_WIDTH: int = 105
	const START_HEIGHT: int = 48
	for x: int in range(LEFT, RIGHT + 1):
		world.set_cell(x, FLOOR_Y, CyberCellWorld.WALL)
	for y: int in range(250, FLOOR_Y + 1):
		world.set_cell(LEFT, y, CyberCellWorld.WALL)
		world.set_cell(RIGHT, y, CyberCellWorld.WALL)

	var initial_water_count: int = 0
	for offset_x: int in range(-HALF_WIDTH, HALF_WIDTH + 1):
		var column_height: int = maxi(
			0,
			START_HEIGHT - floori(
				float(absi(offset_x) * START_HEIGHT) / float(HALF_WIDTH + 1)
			)
		)
		for depth: int in range(1, column_height + 1):
			world.set_cell(CENTRE_X + offset_x, FLOOR_Y - depth, CyberCellWorld.WATER)
			initial_water_count += 1

	# At 60 Hz this is six seconds. The reported prototype needed about thirty
	# seconds and then retained a four-pixel mound.
	for _tick: int in range(360):
		world.simulation_tick()

	var water_count: int = 0
	var minimum_column_height: int = CyberCellWorld.WORLD_HEIGHT
	var maximum_column_height: int = 0
	for x: int in range(LEFT + 1, RIGHT):
		var column_height: int = 0
		for y: int in range(250, FLOOR_Y):
			if world.material_at(x, y) == CyberCellWorld.WATER:
				water_count += 1
				column_height += 1
		if column_height > 0:
			minimum_column_height = mini(minimum_column_height, column_height)
			maximum_column_height = maxi(maximum_column_height, column_height)
	_expect(water_count == initial_water_count, "wide Water fixture changed cell count")
	_expect(
		maximum_column_height - minimum_column_height <= 2,
		"wide Water fixture exceeded the two-pixel resting-height target (%d..%d)"
		% [minimum_column_height, maximum_column_height]
	)
	_expect(
		world._liquid_lateral_flow_rate(CyberCellWorld.WATER) == 24,
		"Water viscosity no longer maps to the tuned lateral flow rate"
	)


func _test_rigid_body_mask_blocks_material() -> void:
	var world: CyberCellWorld = _fresh_world()
	var body_states: PackedFloat32Array = PackedFloat32Array()
	CyberRigidBodyCoupling.append_input(
		body_states,
		1,
		Vector2(100.5, 101.5),
		0.0,
		Vector2(3.0, 1.0),
		Vector2.ZERO,
		0.0,
		1.0,
		1
	)
	world.set_cell(100, 100, CyberCellWorld.SAND)
	world.prepare_rigid_body_coupling(body_states)
	world.simulation_tick()
	_expect(
		world.cells[world.cell_index(100, 100)] == CyberCellWorld.SAND,
		"Sand moved through the rigid-body occupancy mask"
	)
	_expect(
		world.material_at(100, 101) == CyberCellWorld.WALL,
		"Rigid-body occupancy was not exposed as a solid query"
	)


func _test_rigid_body_sweep_displaces_without_leaving_a_phantom_mask() -> void:
	var world: CyberCellWorld = _fresh_world()
	var start_states: PackedFloat32Array = PackedFloat32Array()
	CyberRigidBodyCoupling.append_input(
		start_states,
		1,
		Vector2(100.5, 100.5),
		0.0,
		Vector2.ONE,
		Vector2.ZERO,
		0.0,
		1.0,
		1
	)
	world.prepare_rigid_body_coupling(start_states, false)
	world.set_cell(103, 100, CyberCellWorld.SAND)

	var end_states: PackedFloat32Array = PackedFloat32Array()
	CyberRigidBodyCoupling.append_input(
		end_states,
		1,
		Vector2(105.5, 100.5),
		0.0,
		Vector2.ONE,
		Vector2(5.0, 0.0),
		0.0,
		1.0,
		2
	)
	world.prepare_rigid_body_coupling(end_states)

	var sand_count: int = 0
	for y: int in range(96, 105):
		for x: int in range(96, 111):
			if world.cells[world.cell_index(x, y)] == CyberCellWorld.SAND:
				sand_count += 1
	_expect(
		world.rigid_body_displaced_last_tick == 1,
		"moving rigid-body sweep did not displace crossed material"
	)
	_expect(sand_count == 1, "moving rigid-body sweep did not conserve displaced material")
	_expect(
		world.rigid_body_occupancy[world.cell_index(103, 100)] == 0,
		"swept path remained as a phantom collision mask"
	)
	_expect(
		world.rigid_body_occupancy[world.cell_index(105, 100)] == 1,
		"new rigid-body endpoint was not retained in the collision mask"
	)


func _test_vertical_chain_does_not_form_empty_scanlines() -> void:
	var world: CyberCellWorld = _fresh_world()
	for y: int in range(100, 103):
		world.set_cell(140, y, CyberCellWorld.SAND)
	world.simulation_tick()
	for y: int in range(101, 104):
		_expect(
			world.material_at(140, y) == CyberCellWorld.SAND,
			"Bottom-up Sand chain left an alternating empty scanline at y=%d" % y
		)


func _test_excluded_active_grains_do_not_support() -> void:
	var world: CyberCellWorld = _fresh_world()
	for y: int in range(100, 103):
		for x: int in range(63, 66):
			world.set_cell(x, y, CyberCellWorld.SAND)
	world.set_simulation_window(Vector2i(400, 400), Vector2i(32, 32), 0, 0)
	world.simulation_tick()
	_expect(
		not CyberInteractionPolicy.supports_at(world, 64, 100, false, false),
		"paused active grains outside the interest window provided support"
	)


func _test_ejection_does_not_cross_another_body() -> void:
	var world: CyberCellWorld = _fresh_world()
	world.set_cell(104, 113, CyberCellWorld.WATER)
	var states: PackedFloat32Array = PackedFloat32Array([
		1, 104, 107, 0, 8, 14, 0, 0, 0, 1, 1,
		2, 104, 115, 0, 32, 1, 0, 0, 0, 1, 1,
	])
	world.prepare_rigid_body_coupling(states, true)
	var water_count: int = 0
	for y: int in range(96, 128):
		for x: int in range(88, 121):
			water_count += int(world.cells[world.cell_index(x, y)] == CyberCellWorld.WATER)
	_expect(world.cells[world.cell_index(104, 113)] == CyberCellWorld.WATER,
		"ejection crossed another body's transient mask")
	_expect(water_count == 1, "blocked ejection lost or duplicated its payload")
	_expect(world.rigid_body_displaced_last_tick == 0,
		"blocked ejection reported a displacement")
	_expect(world.rigid_body_unresolved_last_tick == 1,
		"blocked ejection did not report one unresolved overlap")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
