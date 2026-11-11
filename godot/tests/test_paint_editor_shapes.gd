extends SceneTree

# PAINT-001: geometry control + actual exclusive native-worker material readback.
# Run with the same Godot/native runtime as other Godot test scripts:
# godot --headless --path godot --script res://tests/test_paint_editor_shapes.gd
const Shapes = preload("res://scripts/workbench_paint_editor_shapes.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

var failures: int = 0
var checks: int = 0
var planning_usec: Dictionary = {}


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
	expect(filled.get("cells", PackedInt32Array()) == Shapes.rectangle(
		Vector2i(803, 82), Vector2i(800, 80), true, extent).get("cells", PackedInt32Array()),
		"reverse drag has exact identical filled raster")
	expect(filled.get("cells", PackedInt32Array()) == PackedInt32Array([
		800,80,801,80,802,80,803,80,800,81,801,81,802,81,803,81,800,82,801,82,802,82,803,82
	]), "filled rectangle exact row-major raster")
	var outline: Dictionary = Shapes.rectangle(Vector2i(820, 80), Vector2i(825, 84), false, extent)
	expect(outline.get("accepted", false) and outline.get("count", 0) == 18, "perimeter without interior")
	expect(outline.get("cells", PackedInt32Array()) == Shapes.rectangle(
		Vector2i(825, 84), Vector2i(820, 80), false, extent).get("cells", PackedInt32Array()),
		"reverse drag has exact identical perimeter")
	var one_row: Dictionary = Shapes.rectangle(Vector2i(825, 100), Vector2i(821, 100), false, extent)
	expect(one_row.get("accepted", false) and one_row.get("count", 0) == 5, "degenerate rectangle is one row")
	var one_column: Dictionary = Shapes.rectangle(Vector2i(825, 104), Vector2i(825, 100), false, extent)
	expect(one_column.get("accepted", false) and one_column.get("cells", PackedInt32Array())
		== PackedInt32Array([825,100,825,101,825,102,825,103,825,104]),
		"one-column outline contains each row exactly once")
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


	# Single-material stencil geometry is independent of source material and
	# MUST receive the same ordinary host/ACK authorization as any shape.
	var stencil: Dictionary = Shapes.stamp(
		filled.get("cells", PackedInt32Array()),
		Vector2i(800, 80), Vector2i(900, 130), extent)
	expect(stencil.get("accepted", false) and stencil.get("count", 0) == 12,
		"bounded stencil translation retains unique cell count")
	expect(stencil.get("cells", PackedInt32Array())[0] == 900
		and stencil.get("cells", PackedInt32Array())[1] == 130
		and stencil.get("cells", PackedInt32Array())[22] == 903
		and stencil.get("cells", PackedInt32Array())[23] == 132,
		"stencil destination is row-major and translated exactly")
	var source_twice := PackedInt32Array([800,80,800,80])
	var dedup: Dictionary = Shapes.stamp(source_twice, Vector2i(800,80), Vector2i(900,130), extent)
	expect(dedup.get("accepted", false) and dedup.get("count", 0) == 1,
		"stencil de-duplicates source coordinates before a native command")
	expect(not Shapes.stamp(
		filled.get("cells", PackedInt32Array()), Vector2i(800,80), Vector2i(2047,130), extent
	).get("accepted", true), "out-of-bounds stamp refuses entire operation")
	expect(not Shapes.stamp(
		PackedInt32Array([800,80,801]), Vector2i(800,80), Vector2i(900,130), extent
	).get("accepted", true), "odd-length source mask is refused")
	expect(not Shapes.stamp(
		PackedInt32Array([2048,80]), Vector2i(800,80), Vector2i(900,130), extent
	).get("accepted", true), "source coordinate outside canvas is refused")
	var oversized_stencil := PackedInt32Array()
	oversized_stencil.resize(8194)
	expect(not Shapes.stamp(
		oversized_stencil, Vector2i(0,0), Vector2i(10,10), extent
	).get("accepted", true), "4097-cell stencil refused before application")


	# FILL: synthetic authoritative-ID fixture only (algorithm test). It is
	# not a native observation or proof of applied paint; the ordinary host
	# must capture those IDs and revalidate source generation before commit.
	var pocket_materials := PackedInt32Array()
	pocket_materials.resize(49)
	for sample_y: int in range(1, 6):
		for sample_x: int in range(1, 6):
			pocket_materials[sample_y * 7 + sample_x] = 7
	var pocket: Dictionary = Shapes.fill_connected(
		Vector2i(903, 303), Vector2i(900, 300), Vector2i(7, 7),
		pocket_materials, extent)
	expect(pocket.get("accepted", false) and pocket.get("count", 0) == 25
		and pocket.get("source_material_id", -1) == 7,
		"closed four-neighbor native-ID pocket fills 25 cells")
	var pocket_cells: PackedInt32Array = pocket.get("cells", PackedInt32Array())
	expect(pocket_cells.size() == 50 and pocket_cells[0] == 901
		and pocket_cells[1] == 301
		and pocket_cells[48] == 905
		and pocket_cells[49] == 305,
		"connected fill is uniquely row-major, bounded and deterministic")
	var unknown_border := PackedInt32Array()
	unknown_border.resize(49)
	for i: int in range(49):
		unknown_border[i] = 7
	var unsafe_crop: Dictionary = Shapes.fill_connected(
		Vector2i(903, 303), Vector2i(900, 300), Vector2i(7, 7),
		unknown_border, extent)
	expect(not unsafe_crop.get("accepted", true)
		and unsafe_crop.get("cells", PackedInt32Array()).is_empty()
		and str(unsafe_crop.get("unread_edge","")) in ["left","right","top","bottom"],
		"component reaching unread crop boundary returns direction without partial fill")
	var grown: Rect2i = Shapes.grow_fill_capture(Rect2i(900,300,7,7),
		str(unsafe_crop.get("unread_edge","")),extent)
	expect(grown.has_area() and grown.encloses(Rect2i(900,300,7,7))
		and grown.size.x*grown.size.y <= Shapes.MAX_FILL_SAMPLE_CELLS,
		"unread edge grows an enclosing native capture within finite budget")
	expect(not Shapes.grow_fill_capture(Rect2i(1,1,512,512),"right",extent).has_area(),
		"maximum-size native capture refuses growth with no hidden writes")
	var exact_source := PackedInt32Array()
	exact_source.resize(66 * 66)
	for sample_y: int in range(1, 65):
		for sample_x: int in range(1, 65):
			exact_source[sample_y * 66 + sample_x] = 7
	var exact_fill: Dictionary = Shapes.fill_connected(
		Vector2i(1004, 204), Vector2i(1000, 200), Vector2i(66, 66),
		exact_source, extent)
	expect(exact_fill.get("accepted", false) and exact_fill.get("count", 0) == 4096,
		"closed 4096-cell connected fill passes exact native limit")
	var over_source := PackedInt32Array()
	over_source.resize(67 * 66)
	for sample_y: int in range(1, 65):
		for sample_x: int in range(1, 66):
			over_source[sample_y * 67 + sample_x] = 7
	var refused_over: Dictionary = Shapes.fill_connected(
		Vector2i(1004, 204), Vector2i(1000, 200), Vector2i(67, 66),
		over_source, extent)
	expect(not refused_over.get("accepted", true)
		and refused_over.get("cells", PackedInt32Array()).is_empty(),
		"4160 connected cells refuse atomically rather than truncating at 4096")
	var corner_materials := PackedInt32Array()
	corner_materials.resize(64)
	corner_materials[0] = 7
	var world_corner: Dictionary = Shapes.fill_connected(
		Vector2i(0, 0), Vector2i(0, 0), Vector2i(8, 8),
		corner_materials, extent)
	expect(world_corner.get("accepted", false) and world_corner.get("count", 0) == 1,
		"real canvas boundary is safe, unlike an unread crop edge")
	expect(not Shapes.fill_connected(
		Vector2i(903, 303), Vector2i(900, 300), Vector2i(7, 7),
		PackedInt32Array([7]), extent).get("accepted", true),
		"missing source materials refuse")
	var reserved_materials := pocket_materials.duplicate()
	reserved_materials[0] = 10
	expect(not Shapes.fill_connected(
		Vector2i(903, 303), Vector2i(900, 300), Vector2i(7, 7),
		reserved_materials, extent).get("accepted", true),
		"native material slot 10 is reserved, even when outside the connected component")
	var unknown_materials := pocket_materials.duplicate()
	unknown_materials[0] = 132
	expect(not Shapes.fill_connected(
		Vector2i(903, 303), Vector2i(900, 300), Vector2i(7, 7),
		unknown_materials, extent).get("accepted", true),
		"material ID above accepted native enum refuses fill")
	var invalid_materials := pocket_materials.duplicate()
	invalid_materials[0] = -1
	expect(not Shapes.fill_connected(
		Vector2i(903, 303), Vector2i(900, 300), Vector2i(7, 7),
		invalid_materials, extent).get("accepted", true),
		"invalid source material refuses without treating unknown as a boundary")
	expect(not Shapes.fill_connected(
		Vector2i(800, 80), Vector2i(900, 300), Vector2i(7, 7),
		pocket_materials, extent).get("accepted", true),
		"seed outside authoritative native sample refuses")
	expect(not Shapes.fill_connected(
		Vector2i(903, 303), Vector2i(2044, 300), Vector2i(7, 7),
		pocket_materials, extent).get("accepted", true),
		"source capture outside canvas refuses")


	# Material-aware stencil preview is NOT native-applied and MUST NOT be
	# submitted as multiple independent owner queue commands. The source IDs
	# below are synthetic fixtures; a real host must capture/fence native IDs.
	var multi_source := PackedInt32Array([100,100,101,100,100,101,101,101])
	var multi_materials := PackedInt32Array([7,0,7,2])
	var multi: Dictionary = Shapes.stamp_materials(
		multi_source, multi_materials, Vector2i(100,100), Vector2i(200,200), extent)
	expect(multi.get("accepted", false) and multi.get("count", 0) == 4
		and multi.get("cells", PackedInt32Array()) == PackedInt32Array([
			200,200,201,200,200,201,201,201
		]), "multi-material stencil retains four exact translated cells in row-major order")
	expect(multi.get("staging_only", false) and multi.get("atomic_commit_required", false)
		and not multi.get("applied", true), "multi-material plan cannot claim an atomic native commit")
	var groups: Array = multi.get("groups", [])
	expect(groups.size() == 3, "multi-material stencil has three independent native IDs")
	if groups.size() == 3:
		expect(groups[0].get("material_id", -1) == 0
			and groups[0].get("cells", PackedInt32Array()) == PackedInt32Array([201,200])
			and groups[1].get("material_id", -1) == 2
			and groups[1].get("cells", PackedInt32Array()) == PackedInt32Array([201,201])
			and groups[2].get("material_id", -1) == 7
			and groups[2].get("cells", PackedInt32Array()) == PackedInt32Array([200,200,200,201]),
			"multi-material native-ID groups are deterministic, sorted and preserve Empty zero")
	var dedup_multi: Dictionary = Shapes.stamp_materials(
		PackedInt32Array([100,100,100,100]),
		PackedInt32Array([7,7]), Vector2i(100,100), Vector2i(200,200), extent)
	expect(dedup_multi.get("accepted", false) and dedup_multi.get("count", 0) == 1,
		"duplicate identical source cells and material IDs coalesce")
	expect(not Shapes.stamp_materials(
		PackedInt32Array([100,100,100,100]),
		PackedInt32Array([7,2]), Vector2i(100,100), Vector2i(200,200), extent
	).get("accepted", true), "conflicting material IDs for same source cell refuse entire paste")
	expect(not Shapes.stamp_materials(
		multi_source, PackedInt32Array([7,0,2]),
		Vector2i(100,100), Vector2i(200,200), extent
	).get("accepted", true), "partial material snapshot refuses")
	expect(not Shapes.stamp_materials(
		multi_source, PackedInt32Array([7,0,-1,2]),
		Vector2i(100,100), Vector2i(200,200), extent
	).get("accepted", true), "invalid negative native material ID refuses")
	expect(not Shapes.stamp_materials(
		multi_source, PackedInt32Array([7,0,10,2]),
		Vector2i(100,100), Vector2i(200,200), extent
	).get("accepted", true), "reserved native slot 10 refuses multi-material paste")
	expect(not Shapes.stamp_materials(
		multi_source, PackedInt32Array([7,0,132,2]),
		Vector2i(100,100), Vector2i(200,200), extent
	).get("accepted", true), "unknown native material ID 132 refuses multi-material paste")
	expect(not Shapes.stamp_materials(
		multi_source, PackedInt32Array([7,0,256,2]),
		Vector2i(100,100), Vector2i(200,200), extent
	).get("accepted", true), "invalid high native material ID refuses")
	expect(not Shapes.stamp_materials(
		multi_source, multi_materials, Vector2i(100,100), Vector2i(2047,2047), extent
	).get("accepted", true), "off-canvas multi-material destination refuses without clipping")
	var oversized_multi := PackedInt32Array()
	oversized_multi.resize(8194)
	var oversized_ids := PackedInt32Array()
	oversized_ids.resize(4097)
	expect(not Shapes.stamp_materials(
		oversized_multi, oversized_ids, Vector2i(0,0), Vector2i(1,1), extent
	).get("accepted", true), "4097-cell multi-material source refuses before grouping")

	_test_operation_budgets()

	# These five accepted plans exercise the existing native owner once each.
	# A successful queue result by itself is NOT treated as an applied receipt.
	var worker := CyberSimulationWorker.new()
	var actual_native: bool = worker._world.get_class() == "CyberNativeCellWorld"
	expect(actual_native, "runtime is actual CyberNativeCellWorld, never serial fallback")
	if not actual_native:
		print("PAINT_EDITOR_SHAPES ", JSON.stringify({
			"checks": checks, "failures": failures, "actual_native_readback": false,
			"backend": worker._world.get_class(), "planning_usec": planning_usec,
		}))
		quit(1)
		return
	worker.set_frame_state(
		0.0, false, true, Vector2i(800, 80), Vector2i(720, 40),
		Vector2i(160, 100), 0, 0, true, true, true
	)
	var outside: Vector2i = Vector2i(822, 82)
	var before: int = int(worker._world.material_at(outside.x, outside.y))
	var emitted: Array[Dictionary] = [diagonal, filled, outline, thick, stencil]
	var queued := true
	for plan: Dictionary in emitted:
		if not plan.get("accepted", false) or not worker.queue_emit_cells(
			plan.cells, CyberCellWorld.NEON_MAGENTA):
			queued = false
	expect(queued, "five exact-cell plans admitted by existing worker")
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
		"actual_native_readback": actual_native and start_error == OK and snapshot != null and queued,
		"backend": worker._world.get_class(), "planning_usec": planning_usec,
	}))
	quit(1 if failures else 0)


func _test_operation_budgets() -> void:
	# Existing callers retain 4096-cell admission. The mounted executor opts
	# into larger, still whole-operation-bounded plans and owns their ACKs.
	for side: int in [512, 1024, 2048]:
		var extent := Vector2i(side, side)
		var started: int = Time.get_ticks_usec()
		var large: Dictionary = Shapes.rectangle(
			Vector2i.ZERO, Vector2i(511, 511), true, extent, Shapes.MAX_OPERATION_CELLS)
		planning_usec["max_rectangle_%d" % side] = Time.get_ticks_usec() - started
		expect(large.get("accepted", false) and large.get("count", 0) == 262144,
			"262144-cell rectangle admitted explicitly on %d world" % side)
		var cells: PackedInt32Array = large.get("cells", PackedInt32Array())
		var exact_order: bool = cells.size() == 524288
		for i: int in range(int(cells.size() / 2)):
			if cells[i * 2] != i % 512 or cells[i * 2 + 1] != int(i / 512):
				exact_order = false
				break
		expect(exact_order, "every large rectangle coordinate is exact row-major on %d world" % side)
		expect(not Shapes.rectangle(Vector2i.ZERO, Vector2i(511, 511), true, extent,
			262143).get("accepted", true), "whole oversized rectangle refused before raster on %d world" % side)
		started = Time.get_ticks_usec()
		var normal: Dictionary = Shapes.line(Vector2i(40, 40), Vector2i(140, 80), 2, extent)
		planning_usec["normal_line_%d" % side] = Time.get_ticks_usec() - started
		expect(normal.get("accepted", false), "normal feature line admitted on %d world" % side)
	var extent := Vector2i(2048, 2048)
	var started: int = Time.get_ticks_usec()
	var thick: Dictionary = Shapes.line(Vector2i(30, 60), Vector2i(1800, 400), 8, extent,
		Shapes.MAX_OPERATION_CELLS)
	planning_usec["large_thick_line_2048"] = Time.get_ticks_usec() - started
	expect(thick.get("accepted", false) and thick.get("count", 0) > 4096,
		"large thick line passes explicit operation budget")
	expect(thick.get("cells", PackedInt32Array()) == Shapes.line(
		Vector2i(1800, 400), Vector2i(30, 60), 8, extent, Shapes.MAX_OPERATION_CELLS).get("cells"),
		"large thick line remains reverse-drag exact")
	for invalid_limit: int in [0, -1, 262145]:
		expect(not Shapes.line(Vector2i(1, 1), Vector2i(2, 2), 0, extent, invalid_limit).get("accepted", true),
			"line refuses invalid explicit operation budget %d" % invalid_limit)
		expect(not Shapes.rectangle(Vector2i(1, 1), Vector2i(2, 2), true, extent,
			invalid_limit).get("accepted", true), "rectangle refuses invalid explicit operation budget %d" % invalid_limit)
		expect(not Shapes.stamp(PackedInt32Array([1, 1]), Vector2i(1, 1), Vector2i(2, 2),
			extent, invalid_limit).get("accepted", true), "stencil refuses invalid explicit operation budget %d" % invalid_limit)
		expect(not Shapes.stamp_materials(PackedInt32Array([1, 1]), PackedInt32Array([7]),
			Vector2i(1, 1), Vector2i(2, 2), extent, invalid_limit).get("accepted", true),
			"multi-material stencil refuses invalid explicit operation budget %d" % invalid_limit)
		expect(not Shapes.fill_connected(Vector2i.ZERO, Vector2i.ZERO, Vector2i.ONE,
			PackedInt32Array([7]), extent, invalid_limit).get("accepted", true),
			"fill refuses invalid explicit operation budget %d" % invalid_limit)
	var source: Dictionary = Shapes.rectangle(Vector2i(10, 10), Vector2i(137, 137), true, extent, 16384)
	var ids := PackedInt32Array()
	ids.resize(16384)
	for i: int in range(ids.size()):
		ids[i] = [0, 2, 7][i % 3]
	started = Time.get_ticks_usec()
	var paste: Dictionary = Shapes.stamp_materials(source.cells, ids, Vector2i(10, 10),
		Vector2i(11, 11), extent, Shapes.MAX_OPERATION_CELLS)
	planning_usec["mixed_stencil_16384"] = Time.get_ticks_usec() - started
	expect(paste.get("accepted", false) and paste.get("count", 0) == 16384
		and paste.get("materials", PackedInt32Array()) == ids,
		"overlapping translated large stencil retains exact source identity including Empty")
	var sample := PackedInt32Array()
	sample.resize(512 * 512)
	started = Time.get_ticks_usec()
	var fill: Dictionary = Shapes.fill_connected(Vector2i(100, 100), Vector2i.ZERO,
		Vector2i(512, 512), sample, Vector2i(512, 512), Shapes.MAX_OPERATION_CELLS)
	planning_usec["bounded_fill_262144"] = Time.get_ticks_usec() - started
	expect(fill.get("accepted", false) and fill.get("count", 0) == 262144,
		"bounded 512-square capture fills exactly at operation ceiling and real world borders")
	var cropped: Dictionary = Shapes.fill_connected(Vector2i(100, 100), Vector2i.ZERO,
		Vector2i(512, 512), sample, extent, Shapes.MAX_OPERATION_CELLS)
	expect(not cropped.get("accepted", true) and cropped.get("cells", PackedInt32Array()).is_empty(),
		"same maximum sample refuses unread crop edge without a partial plan")
	expect(not Shapes.fill_connected(Vector2i.ZERO, Vector2i.ZERO, Vector2i(513, 512),
		sample, extent, Shapes.MAX_OPERATION_CELLS).get("accepted", true),
		"sample above 262144 refuses before fill")
	var diagonal_only := PackedInt32Array()
	diagonal_only.resize(49)
	diagonal_only[24] = 7
	diagonal_only[32] = 7
	var four_connected: Dictionary = Shapes.fill_connected(Vector2i(13, 13), Vector2i(10, 10),
		Vector2i(7, 7), diagonal_only, extent, Shapes.MAX_OPERATION_CELLS)
	expect(four_connected.get("accepted", false) and four_connected.get("count", 0) == 1,
		"diagonal contact never joins a four-connected fill")
