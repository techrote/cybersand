extends SceneTree

const DesktopTool = preload("res://scripts/main.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tool: Control = DesktopTool.new()
	_expect(tool.set_brush_shape("square"), "square tool setup failed")
	_expect(tool.set_brush_size(4), "square tool size failed")
	var square: PackedInt32Array = tool.brush_footprint_cells(760, 80)

	_expect(tool.set_brush_shape("rectangle"), "rectangle tool setup failed")
	_expect(tool.set_brush_size(3), "rectangle tool short edge failed")
	_expect(tool.set_brush_rectangle_ratio(2), "rectangle ratio failed")
	tool.set_brush_rectangle_vertical(false)
	var rectangle: PackedInt32Array = tool.brush_footprint_cells(800, 80)

	_expect(tool.set_brush_shape("circle"), "circle tool setup failed")
	_expect(tool.set_brush_size(4), "even circle tool size failed")
	var even_circle: PackedInt32Array = tool.brush_footprint_cells(840, 80)
	var even_dimensions: Vector2i = tool.brush_dimensions()
	var even_start := Vector2i(
		840 - int((even_dimensions.x - 1) / 2),
		80 - int((even_dimensions.y - 1) / 2)
	)
	_expect(even_circle.size() / 2 == 12, "4 px circle did not rasterize to 12 cells")
	tool.free()

	var worker := CyberSimulationWorker.new()
	worker.set_frame_state(
		0.0,
		false,
		true,
		Vector2i(800, 80),
		Vector2i(720, 40),
		Vector2i(160, 100),
		0,
		0,
		true,
		true,
		true
	)

	var outside := Vector2i(even_start.x, even_start.y)
	var outside_before: int = int(worker._world.material_at(outside.x, outside.y))
	var material: int = CyberCellWorld.NEON_MAGENTA
	_expect(worker.queue_emit_cells(square, material), "square owner command was rejected")
	_expect(worker.queue_emit_cells(rectangle, material), "rectangle owner command was rejected")
	_expect(worker.queue_emit_cells(even_circle, material), "even-circle owner command was rejected")
	_expect(
		not worker.queue_emit_cells(PackedInt32Array([1]), material),
		"odd-length cell command was accepted"
	)

	var too_large := PackedInt32Array()
	too_large.resize((CyberSimulationWorker.MAX_BRUSH_FOOTPRINT_CELLS + 1) * 2)
	_expect(
		not worker.queue_emit_cells(too_large, material),
		"oversize cell command exceeded the bounded footprint capacity"
	)

	var start_error: Error = worker.start_worker(Vector2(150.0, 145.0))
	_expect(start_error == OK, "desktop owner did not start")
	if start_error == OK:
		var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		var after_serial: int = -1 if initial == null else initial.serial
		var deadline: int = Time.get_ticks_msec() + 5000
		var applied_snapshot: CyberSimulationSnapshot
		while Time.get_ticks_msec() < deadline:
			await process_frame
			applied_snapshot = worker.take_latest_snapshot(after_serial)
			if applied_snapshot != null:
				break
		_expect(applied_snapshot != null, "desktop owner did not publish after brush commands")
	worker.stop_worker()

	_expect(worker._pending_cell_emissions.is_empty(), "brush commands remained queued after owner join")
	for points: PackedInt32Array in [square, rectangle, even_circle]:
		for offset: int in range(0, points.size(), 2):
			_expect(
				int(worker._world.material_at(points[offset], points[offset + 1])) == material,
				"owner did not apply an exact brush footprint cell"
			)
	_expect(
		int(worker._world.material_at(outside.x, outside.y)) == outside_before,
		"even-circle command painted an excluded bounding-box corner"
	)

	print("BRUSH_OWNER_COMMANDS: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
