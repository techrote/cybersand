extends SceneTree

# Exactness regression for the independent hard-surface collider invalidation
# stream. Actual PackedInt32Array payloads are compared directly with a complete
# display-projection rebuild; no hash is used as packet-equivalence evidence.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("HARD_SURFACE_INCREMENTAL: " + message)


func _new_world(workers: int = 1) -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	_expect(bool(world.diagnostic_reset({"workers": workers})), "diagnostic reset failed")
	return world


func _same(world: Object, label: String) -> PackedInt32Array:
	var incremental: PackedInt32Array = world.get_hard_surface_chunk_rectangles()
	var full: PackedInt32Array = world.diagnostic_full_hard_surface_chunk_rectangles()
	_expect(
		incremental.size() > 0 and incremental == full,
		"incremental packet differs from full packet bytes: " + label
	)
	return incremental


func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native world is unavailable")
	if _failures != 0:
		quit(_failures)
		return
	_test_focused_incremental_contract()
	_test_render_exchange_independence()
	_test_worker_count_parity()
	_test_reactive_stress_equivalence()
	if _failures == 0:
		print("HARD_SURFACE_INCREMENTAL %d checks passed" % _checks)
	quit(_failures)


func _test_focused_incremental_contract() -> void:
	var world: Object = _new_world()
	_same(world, "initial")
	var stats: Dictionary = world.diagnostic_hard_surface_packet_stats()
	_expect(int(stats.get("full_mask_copies", 0)) == 1, "initial packet did not copy one full mask")

	# A 2x2 edit at (63,63) crosses both 64-cell collider-tile boundaries.
	_expect(
		world.diagnostic_fill_rect(Vector2i(63, 63), Vector2i(2, 2), CyberCellWorld.WOOD),
		"cross-boundary Wood edit failed"
	)
	_same(world, "cross-boundary Wood")
	stats = world.diagnostic_hard_surface_packet_stats()
	_expect(int(stats.get("last_invalidated_tiles", -1)) == 4,
		"cross-boundary edit did not invalidate exactly four tiles")
	_expect(int(stats.get("last_changed_tiles", -1)) == 4,
		"cross-boundary edit did not change exactly four masks")

	_expect(
		world.diagnostic_fill_rect(Vector2i(63, 63), Vector2i(2, 2), CyberCellWorld.FIRE),
		"cross-boundary Fire edit failed"
	)
	_same(world, "Wood/Fire")
	stats = world.diagnostic_hard_surface_packet_stats()
	_expect(int(stats.get("last_invalidated_tiles", -1)) == 4,
		"Wood/Fire transition lost cross-boundary invalidation")

	# ABA: invalidation remains pending, but final occupancy and complete packet
	# return to the exact preceding words.
	_expect(
		world.diagnostic_fill_rect(Vector2i(20, 20), Vector2i(1, 1), CyberCellWorld.WOOD),
		"ABA Wood setup failed"
	)
	var aba_before: PackedInt32Array = _same(world, "ABA baseline")
	_expect(
		world.diagnostic_fill_rect(Vector2i(20, 20), Vector2i(1, 1), CyberCellWorld.FIRE),
		"ABA Fire transition failed"
	)
	_expect(
		world.diagnostic_fill_rect(Vector2i(20, 20), Vector2i(1, 1), CyberCellWorld.WOOD),
		"ABA Wood restore failed"
	)
	var aba_after: PackedInt32Array = _same(world, "ABA restore")
	stats = world.diagnostic_hard_surface_packet_stats()
	_expect(aba_after == aba_before, "ABA restore changed complete packet words")
	_expect(int(stats.get("last_invalidated_tiles", -1)) == 1,
		"ABA did not retain the touched tile")
	_expect(int(stats.get("last_changed_tiles", -1)) == 0,
		"ABA rebuilt a tile whose final occupancy was unchanged")

	_expect(
		world.diagnostic_fill_rect(Vector2i(70, 20), Vector2i(1, 1), CyberCellWorld.GLASS),
		"Glass setup failed"
	)
	_same(world, "Glass")
	_expect(
		world.diagnostic_fill_rect(Vector2i(70, 20), Vector2i(1, 1), CyberCellWorld.LAVA),
		"Glass/Lava transition failed"
	)
	_same(world, "Glass/Lava")

	_expect(
		world.diagnostic_fill_rect(Vector2i(130, 20), Vector2i(1, 1), CyberCellWorld.METAL),
		"Metal setup failed"
	)
	_same(world, "Metal")
	_expect(
		world.diagnostic_fill_rect(Vector2i(130, 20), Vector2i(1, 1), CyberCellWorld.ACID),
		"Metal/Acid transition failed"
	)
	_same(world, "Metal/Acid")

	var hard_revision: int = int(world.hard_surface_revision)
	_expect(
		world.water_experiment_fill_rect(Vector2i(200, 20), Vector2i(1, 1), 1, 0),
		"fractional Water setup failed"
	)
	var water_packet: PackedInt32Array = _same(world, "fractional Water")
	_expect(int(world.hard_surface_revision) == hard_revision,
		"fractional Water changed hard-surface revision")
	var repeat_before: Dictionary = world.diagnostic_hard_surface_packet_stats()
	var repeated: PackedInt32Array = world.get_hard_surface_chunk_rectangles()
	var repeat_after: Dictionary = world.diagnostic_hard_surface_packet_stats()
	_expect(repeated == water_packet, "repeated same-revision query changed packet words")
	_expect(
		int(repeat_after.get("tile_mask_copies", -1)) ==
			int(repeat_before.get("tile_mask_copies", -2)),
		"repeated same-revision query copied another tile mask"
	)

	var full_copies: int = int(repeat_after.get("full_mask_copies", 0))
	_expect(bool(world.diagnostic_reset({"workers": 1})), "reset coverage reset failed")
	_same(world, "post-reset")
	stats = world.diagnostic_hard_surface_packet_stats()
	_expect(int(stats.get("full_mask_copies", 0)) == full_copies + 1,
		"World replacement did not request one explicit full refresh")


func _test_render_exchange_independence() -> void:
	var control: Object = _new_world()
	var observed: Object = _new_world()
	var control_full: Dictionary = control.take_render_snapshot(true)
	var observed_full: Dictionary = observed.take_render_snapshot(true)
	_expect(_render_packets_equal(control_full, observed_full),
		"initial render packets differ before collider observation")

	_expect(
		control.diagnostic_fill_rect(Vector2i(300, 300), Vector2i(2, 2), CyberCellWorld.GLASS),
		"control render edit failed"
	)
	_expect(
		observed.diagnostic_fill_rect(Vector2i(300, 300), Vector2i(2, 2), CyberCellWorld.GLASS),
		"observed render edit failed"
	)
	_same(observed, "render-dirty ownership")
	var control_delta: Dictionary = control.take_render_snapshot(false)
	var observed_delta: Dictionary = observed.take_render_snapshot(false)
	_expect(_render_packets_equal(control_delta, observed_delta),
		"collider query changed render status, serial, metadata or RG8 bytes")


func _render_packets_equal(left: Dictionary, right: Dictionary) -> bool:
	var left_rectangles: PackedInt32Array = left.get("rectangles", PackedInt32Array())
	var right_rectangles: PackedInt32Array = right.get("rectangles", PackedInt32Array())
	var left_cells: PackedByteArray = left.get("cells", PackedByteArray())
	var right_cells: PackedByteArray = right.get("cells", PackedByteArray())
	return (
		int(left.get("serial", -1)) == int(right.get("serial", -2))
		and int(left.get("status", -1)) == int(right.get("status", -2))
		and bool(left.get("full_refresh", false)) == bool(right.get("full_refresh", true))
		and int(left.get("channels", 0)) == int(right.get("channels", -1))
		and left_rectangles == right_rectangles
		and left_cells == right_cells
	)


func _seed_reactive_pairs(world: Object) -> void:
	for y: int in [20, 84, 148, 212]:
		for x: int in [20, 84, 148, 212]:
			_expect(world.diagnostic_fill_rect(Vector2i(x, y), Vector2i(1, 1), CyberCellWorld.GLASS),
				"parity Glass setup failed")
			_expect(world.diagnostic_fill_rect(Vector2i(x + 1, y), Vector2i(1, 1), CyberCellWorld.LAVA),
				"parity Lava setup failed")
			_expect(world.diagnostic_fill_rect(Vector2i(x, y + 2), Vector2i(1, 1), CyberCellWorld.METAL),
				"parity Metal setup failed")
			_expect(world.diagnostic_fill_rect(Vector2i(x + 1, y + 2), Vector2i(1, 1), CyberCellWorld.ACID),
				"parity Acid setup failed")
			_expect(world.diagnostic_fill_rect(Vector2i(x, y + 4), Vector2i(1, 1), CyberCellWorld.WOOD),
				"parity Wood setup failed")
			_expect(world.diagnostic_fill_rect(Vector2i(x + 1, y + 4), Vector2i(1, 1), CyberCellWorld.FIRE),
				"parity Fire setup failed")


func _test_worker_count_parity() -> void:
	var serial: Object = _new_world(1)
	var parallel: Object = _new_world(4)
	_seed_reactive_pairs(serial)
	_seed_reactive_pairs(parallel)
	_same(serial, "serial parity setup")
	_same(parallel, "parallel parity setup")
	var starting_revision: int = int(serial.hard_surface_revision)
	var saw_hard_change: bool = false
	for tick: int in range(8):
		_expect(bool(serial.simulation_tick()), "serial parity tick %d failed" % tick)
		_expect(bool(parallel.simulation_tick()), "parallel parity tick %d failed" % tick)
		var serial_packet: PackedInt32Array = _same(serial, "serial tick %d" % tick)
		var parallel_packet: PackedInt32Array = _same(parallel, "parallel tick %d" % tick)
		_expect(serial_packet == parallel_packet,
			"complete collider packet differs by worker count at tick %d" % tick)
		_expect(serial.get_physical_state_hash() == parallel.get_physical_state_hash(),
			"native physical state differs by worker count at tick %d" % tick)
		_expect(int(serial.hard_surface_revision) == int(parallel.hard_surface_revision),
			"hard-surface revision differs by worker count at tick %d" % tick)
		saw_hard_change = saw_hard_change or int(serial.hard_surface_revision) > starting_revision
	_expect(saw_hard_change, "worker parity fixture never produced a hard-surface tick mutation")


func _test_reactive_stress_equivalence() -> void:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	world.simulation_window_enabled = false
	_same(world, "initial demo world")
	var rng := RandomNumberGenerator.new()
	rng.seed = 406
	# Reactive structures straddling 64-cell collision seams.
	world.emit_disc(128, 256, 20, CyberCellWorld.WOOD)
	world.emit_disc(128, 256, 4, CyberCellWorld.FIRE)
	world.emit_disc(320, 192, 14, CyberCellWorld.GLASS)
	world.emit_disc(320, 170, 8, CyberCellWorld.LAVA)
	world.emit_disc(512, 384, 12, CyberCellWorld.METAL)
	world.emit_disc(512, 364, 8, CyberCellWorld.ACID)
	var materials: Array[int] = [
		CyberCellWorld.WALL,
		CyberCellWorld.STONE,
		CyberCellWorld.GLASS,
		CyberCellWorld.EMPTY,
		CyberCellWorld.WOOD,
		CyberCellWorld.SAND,
		CyberCellWorld.WATER,
	]
	for step: int in range(90):
		if step % 3 == 0:
			var x: int = rng.randi_range(8, 1015)
			var y: int = rng.randi_range(8, 1015)
			world.emit_disc(
				x,
				y,
				rng.randi_range(2, 18),
				materials[rng.randi_range(0, materials.size() - 1)]
			)
		_expect(bool(world.simulation_tick()), "native tick failed at stress step %d" % step)
		_same(world, "stress step %d" % step)
	var stats: Dictionary = world.diagnostic_hard_surface_packet_stats()
	_expect(int(stats.get("chunks_reused", 0)) > int(stats.get("chunks_rebuilt", 0)),
		"unchanged collision chunks were not reused (%s)" % str(stats))
	print("HARD_SURFACE_INCREMENTAL stress stats %s" % JSON.stringify(stats))
