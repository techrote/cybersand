extends SceneTree

# PAINT-001: geometry control + actual exclusive native-worker material readback.
# Run with the same Godot/native runtime as other Godot test scripts:
# godot --headless --path godot --script res://tests/test_paint_editor_shapes.gd
const Shapes = preload("res://scripts/workbench_paint_editor_shapes.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PAINT_EDITOR_SHAPES " + label)


func _run() -> void:
	var extent := Vector2i(2048, 2048)
	var diagonal: Dictionary = Shapes.line(Vector2i(760, 80), Vector2i(765, 85), 0, extent)
	expect(diagonal.get("accepted", false) and diagonal.get("count", 0) == 6, "exact diagonal line cells")
	expect(diagonal.get("cells", PackedInt32Array()) == PackedInt32Array([
		760,80,761,81,762,82,763,83,764,84,765,85
	]), "line plan is deterministic row-major")

	var reverse: Dictionary = Shapes.line(Vector2i(765, 85), Vector2i(760, 80), 0, extent)
	expect(reverse.get("cells", PackedInt32Array()) == diagonal.get("cells", PackedInt32Array()), "reversed diagonal is identical")
	# Bresenham's midpoint ties are direction-sensitive unless the planner
	# canonicalizes its endpoints. An equal-length diagonal cannot detect it.
	var tie: Dictionary = Shapes.line(Vector2i(760, 90), Vector2i(761, 92), 0, extent)
	expect(tie.get("cells", PackedInt32Array()) == PackedInt32Array([
		760, 90, 761, 91, 761, 92
	]), "shallow midpoint tie uses stable canonical rasterization")
	for delta: Vector2i in [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(6, 3),
		Vector2i(-7, 4), Vector2i(0, 9), Vector2i(9, 0)
	]:
		for radius: int in [0, 2]:
			var a: Vector2i = Vector2i(780, 120)
			var b: Vector2i = a + delta
			var forward: Dictionary = Shapes.line(a, b, radius, extent)
			var backward: Dictionary = Shapes.line(b, a, radius, extent)
			expect(bool(forward.get("accepted", false))
				and bool(backward.get("accepted", false))
				and forward.get("cells", PackedInt32Array()) == backward.get("cells", PackedInt32Array()),
				"reverse drag is pixel-identical for %s radius %d" % [str(delta), radius])
	var thick: Dictionary = Shapes.line(Vector2i(850, 80), Vector2i(850, 80), 1, extent)
	expect(thick.get("accepted", false) and thick.get("count", 0) == 5, "radius-one native disc lattice")
	var clipped: Dictionary = Shapes.line(Vector2i(0, 0), Vector2i(0, 0), 2, extent)
	expect(clipped.get("accepted", false) and clipped.get("count", 0) == 6 and clipped.get("clipped", false),
		"clipped boundary disc never targets off-world cells")

	var filled: Dictionary = Shapes.rectangle(Vector2i(800, 80), Vector2i(803, 82), true, extent)
	expect(filled.get("accepted", false) and filled.get("count", 0) == 12, "inclusive filled rectangle")
	var outline: Dictionary = Shapes.rectangle(Vector2i(820, 80), Vector2i(825, 84), false, extent)
	expect(outline.get("accepted", false) and outline.get("count", 0) == 18, "perimeter without interior")
	expect(outline.get("cells", PackedInt32Array()) == Shapes.rectangle(
		Vector2i(825, 84), Vector2i(820, 80), false, extent).get("cells", PackedInt32Array()),
		"reverse drag has exact identical perimeter")
	var one_row: Dictionary = Shapes.rectangle(Vector2i(825, 100), Vector2i(821, 100), false, extent)
	expect(one_row.get("accepted", false) and one_row.get("count", 0) == 5, "degenerate rectangle is one row")
	var capacity: Dictionary = Shapes.rectangle(Vector2i(900, 50), Vector2i(963, 113), true, extent)
	expect(capacity.get("accepted", false) and capacity.get("count", 0) == 4096 and capacity.cells.size() == 8192,
		"full 4096-cell native command bound")
	expect(not Shapes.rectangle(Vector2i(900, 50), Vector2i(964, 114), true, extent).get("accepted", true),
		"4096+ preflight refusal, no partial command")
	expect(not Shapes.line(Vector2i(900, 80), Vector2i(1900, 80), 24, extent).get("accepted", true),
		"unbounded thick line refuses rather than splitting into hidden commands")
	expect(not Shapes.line(Vector2i(-1, 80), Vector2i(700, 80), 0, extent).get("accepted", true),
		"out-of-canvas anchor refused")
	expect(not Shapes.rectangle(Vector2i(800, 80), Vector2i(2048, 81), false, extent).get("accepted", true),
		"out-of-canvas drag corner refused")
	expect(not Shapes.line(Vector2i(800, 80), Vector2i(800, 80), 25, extent).get("accepted", true),
		"invalid radius refused")
	expect(not Shapes.line(Vector2i(800, 80), Vector2i(800, 80), 0, Vector2i(2049, 2048)).get("accepted", true),
		"invalid canvas size refused")

	# These three accepted plans exercise the existing native owner once each.
	# A successful queue result by itself is NOT treated as an applied receipt.
	var worker := CyberSimulationWorker.new()
	worker.set_frame_state(
		0.0, false, true, Vector2i(800, 80), Vector2i(720, 40),
		Vector2i(160, 100), 0, 0, true, true, true
	)
	var outside: Vector2i = Vector2i(822, 82)
	var before: int = int(worker._world.material_at(outside.x, outside.y))
	var emitted: Array[Dictionary] = [diagonal, filled, outline, thick]
	var queued := true
	for plan: Dictionary in emitted:
		if not plan.get("accepted", false) or not worker.queue_emit_cells(
			plan.cells, CyberCellWorld.NEON_MAGENTA):
			queued = false
	expect(queued, "four exact-cell plans admitted by existing worker")
	var start_error: Error = worker.start_worker(Vector2(150.0, 145.0))
	expect(start_error == OK, "exclusive native worker started")
	var snapshot: CyberSimulationSnapshot
	if start_error == OK:
		var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
		var after_serial: int = -1 if initial == null else initial.serial
		var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
		while Time.get_ticks_msec() < deadline:
			await process_frame
			snapshot = worker.take_latest_snapshot(after_serial)
			if snapshot != null:
				break
		expect(snapshot != null, "exclusive owner published after all commands")
	worker.stop_worker()
	expect(worker._pending_cell_emissions.is_empty(), "pending brush queue drained at join")
	if start_error == OK and snapshot != null and queued:
		for plan: Dictionary in emitted:
			for offset: int in range(0, plan.cells.size(), 2):
				var x: int = plan.cells[offset]
				var y: int = plan.cells[offset + 1]
				expect(int(worker._world.material_at(x, y)) == CyberCellWorld.NEON_MAGENTA,
					"native material at (%d,%d)" % [x,y])
		expect(int(worker._world.material_at(outside.x, outside.y)) == before,
			"outline interior unchanged by native owner")
	print("PAINT_EDITOR_SHAPES ", JSON.stringify({
		"checks": checks, "failures": failures,
		"actual_native_readback": start_error == OK and snapshot != null and queued
	}))
	quit(1 if failures else 0)
