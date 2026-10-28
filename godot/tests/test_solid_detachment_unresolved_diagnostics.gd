extends SceneTree

# Source-matched protocol characterization for unresolved rigid-body/cellular
# overlaps. This changes no movement rule: it proves that the appended diagnostic
# fields partition the existing aggregate unresolved count without moving the
# stable v1 field offsets (body/result/sample remain at 0..8).
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const CELL := Vector2i(64, 64)
const PLANT: int = 11
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL SOL281 UNRESOLVED ", message)

func _init() -> void:
	call_deferred("_run")

func _states(serial: int) -> PackedFloat32Array:
	var states := PackedFloat32Array()
	Coupling.append_input(states, 1, Vector2(CELL) + Vector2(0.5, 0.5), 0.0,
		Vector2.ONE, Vector2.ZERO, 0.0, 1.0, serial)
	return states

func _fresh_native() -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world != null, "native world class is available")
	if world == null:
		return null
	check(world.diagnostic_reset({"workers":1, "telemetry":true}),
		"native diagnostic world constructs")
	world.set_simulation_window_enabled(false)
	return world

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

func _fill(world: Object, native: bool, origin: Vector2i, size: Vector2i, material: int) -> bool:
	if native:
		return world.diagnostic_fill_rect(origin, size, material)
	for y: int in range(origin.y, origin.y + size.y):
		for x: int in range(origin.x, origin.x + size.x):
			world.set_cell(x, y, material)
	return true

func _exercise_case(label: String, native: bool, mode: String, serial: int) -> Dictionary:
	var world: Object = _fresh_native() if native else _fresh_fallback()
	if world == null:
		return {}
	match mode:
		"displaced":
			check(_fill(world, native, CELL, Vector2i.ONE, CyberCellWorld.SAND),
				label + " successful displacement fixture fills")
		"immovable":
			check(_fill(world, native, CELL, Vector2i.ONE, PLANT),
				label + " immovable fixture fills")
		"no_target":
			# Body overlap normal points down for this centred 1×1 proxy. Occupy
			# every bounded 1..9 cell / ±4 tangent candidate with movable Sand.
			check(_fill(world, native, Vector2i(60, 64), Vector2i(9, 10),
				CyberCellWorld.SAND), label + " exhausted-search fixture fills")
		_:
			check(false, label + " unknown mode")
	world.prepare_rigid_body_coupling(_states(serial), true)
	var results: PackedFloat32Array = world.rigid_body_results()
	check(results.size() == Coupling.RESULT_STRIDE,
		label + " publishes one complete appended result record")
	if results.size() != Coupling.RESULT_STRIDE:
		return {}
	check(int(results[Coupling.RESULT_BODY_ID]) == 1
		and int(results[Coupling.RESULT_SAMPLE_SERIAL]) == serial,
		label + " preserves stable body and sample offsets")
	var displaced: int = int(results[Coupling.RESULT_DISPLACED_COUNT])
	var unresolved: int = int(results[Coupling.RESULT_UNRESOLVED_COUNT])
	var immovable: int = int(results[Coupling.RESULT_UNRESOLVED_IMMOVABLE_COUNT])
	var no_target: int = int(results[Coupling.RESULT_UNRESOLVED_NO_TARGET_COUNT])
	var relocation: int = int(results[Coupling.RESULT_UNRESOLVED_RELOCATION_REFUSED_COUNT])
	check(unresolved == immovable + no_target + relocation,
		label + " reason fields exactly partition aggregate unresolved")
	match mode:
		"displaced":
			check(displaced == 1 and unresolved == 0,
				label + " open destination displaces without refusal")
		"immovable":
			check(displaced == 0 and unresolved == 1 and immovable == 1
				and no_target == 0 and relocation == 0,
				label + " non-hard immovable material is classified exactly")
		"no_target":
			check(displaced == 0 and unresolved == 1 and immovable == 0
				and no_target == 1 and relocation == 0,
				label + " bounded empty-target exhaustion is classified exactly")
	if native:
		var metrics: Array = world.diagnostic_body_metrics()
		check(metrics.size() == 1 and metrics[0].size() >= 23,
			label + " native diagnostic row appends cause fields")
		if metrics.size() == 1 and metrics[0].size() >= 23:
			check(int(metrics[0][20]) == immovable and int(metrics[0][21]) == no_target
				and int(metrics[0][22]) == relocation,
				label + " native inspection agrees with copied result record")
	return {"label":label, "mode":mode, "native":native, "displaced":displaced,
		"unresolved":unresolved, "immovable":immovable, "no_target":no_target,
		"relocation_refused":relocation}

func _run() -> void:
	check(Coupling.RESULT_SAMPLE_SERIAL == 8 and Coupling.RESULT_STRIDE == 12,
		"appended diagnostics retain the stable v1 offsets")
	var cases: Array[Dictionary] = []
	var serial: int = 40
	for native: bool in [false, true]:
		var implementation: String = "native" if native else "fallback"
		for mode: String in ["displaced", "immovable", "no_target"]:
			serial += 1
			cases.append(_exercise_case(implementation + "/" + mode, native, mode, serial))
	var report: Dictionary = {"schema":"cybersand.sol281.unresolved-causes.v1",
		"platform":OS.get_name(), "checks":checks, "failures":failures,
		"result_stride":Coupling.RESULT_STRIDE, "cases":cases,
		"scope":"diagnostic partition only; no movement, ejection or material-law change"}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("SOL281_UNRESOLVED_DIAGNOSTICS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
