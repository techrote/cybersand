extends SceneTree

# SOL281 opt-in ejection-policy A/B protocol: identical source geometry,
# stable 12-float result ABI, exact material census and deterministic parity.
# No real Rapier body is created here; the separate compound host test owns it.
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const CENTER := Vector2i(64, 64)
const ORIGIN := Vector2i(48, 60)
const SIZE := Vector2i(33, 28)
const SAND: int = 2
const WALL: int = 1
const EMPTY: int = 0
const MODES: Array[String] = ["open", "lateral", "longitudinal", "wall", "exhausted"]

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		printerr("FAIL SOL281 EJECTION ", description)

func _init() -> void:
	call_deferred("_run")

func _fresh(native: bool, workers: int, policy: int) -> Object:
	if native:
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		check(world != null, "native diagnostic world constructs")
		if world == null:
			return null
		check(world.diagnostic_reset({"workers":workers, "telemetry":false,
			"ejection_policy":policy}), "native policy %d worker %d admitted" % [policy, workers])
		check(world.get_ejection_policy() == policy, "native policy applied and readable")
		world.set_simulation_window_enabled(false)
		return world
	var fallback := CyberCellWorld.new()
	fallback.cells.fill(EMPTY)
	fallback.updated_at.fill(0)
	fallback.quiet_ticks.fill(0)
	fallback.flow_budget.fill(0)
	fallback.flow_direction.fill(CyberCellWorld.FLOW_DIRECTION_NONE)
	fallback.active_blocks.fill(0)
	fallback.next_active_blocks.fill(0)
	fallback.block_movable_counts.fill(0)
	fallback.simulation_window_enabled = false
	fallback.cadence_lod_enabled = false
	fallback.body_ejection_policy = policy
	return fallback

func _fill(world: Object, native: bool, at: Vector2i, size: Vector2i, material: int) -> void:
	if native:
		check(world.diagnostic_fill_rect(at, size, material), "native rectangle admitted")
	else:
		for y: int in range(at.y, at.y + size.y):
			for x: int in range(at.x, at.x + size.x):
				world.set_cell(x, y, material)

func _states(serial: int) -> PackedFloat32Array:
	var states := PackedFloat32Array()
	Coupling.append_input(states, 1, Vector2(CENTER) + Vector2(0.5, 0.5), 0.0,
		Vector2.ONE, Vector2.ZERO, 0.0, 1.0, serial)
	return states

func _stored_cells(world: Object, native: bool) -> PackedByteArray:
	if native:
		var snapshot: Dictionary = world.diagnostic_snapshot(ORIGIN, SIZE, false)
		return snapshot.get("cells", PackedByteArray())
	var packed := PackedByteArray()
	packed.resize(SIZE.x * SIZE.y)
	for y: int in range(SIZE.y):
		for x: int in range(SIZE.x):
			packed[y * SIZE.x + x] = world.cells[world.cell_index(ORIGIN.x + x, ORIGIN.y + y)]
	return packed

func _at(cells: PackedByteArray, x: int, y: int) -> int:
	return int(cells[(y - ORIGIN.y) * SIZE.x + x - ORIGIN.x])

func _digest(cells: PackedByteArray) -> String:
	var hash_value: int = 2166136261
	for material: int in cells:
		hash_value = ((hash_value ^ material) * 16777619) & 0xFFFFFFFF
	return "%08x" % hash_value

func _case(native: bool, workers: int, policy: int, mode: String, serial: int) -> Dictionary:
	var label: String = ("%s/w%d/p%d/%s" %
		["native" if native else "fallback", workers, policy, mode])
	var world: Object = _fresh(native, workers, policy)
	if world == null:
		return {}
	var expected_sand: int = 1
	match mode:
		"open":
			_fill(world, native, CENTER, Vector2i.ONE, SAND)
		"lateral":
			_fill(world, native, Vector2i(60, 64), Vector2i(9, 10), SAND)
			expected_sand = 90
		"longitudinal":
			_fill(world, native, Vector2i(56, 64), Vector2i(17, 10), SAND)
			expected_sand = 170
		"wall":
			_fill(world, native, CENTER, Vector2i.ONE, SAND)
			_fill(world, native, Vector2i(48, 65), Vector2i(33, 1), WALL)
		"exhausted":
			_fill(world, native, Vector2i(56, 64), Vector2i(17, 18), SAND)
			expected_sand = 306
		_:
			check(false, label + " unknown case")
	var began_us: int = Time.get_ticks_usec()
	world.prepare_rigid_body_coupling(_states(serial), true)
	var duration_us: int = Time.get_ticks_usec() - began_us
	var result: PackedFloat32Array = world.rigid_body_results()
	check(result.size() == Coupling.RESULT_STRIDE, label + " full stable result")
	if result.size() != Coupling.RESULT_STRIDE:
		return {}
	check(int(result[Coupling.RESULT_BODY_ID]) == 1
		and int(result[Coupling.RESULT_SAMPLE_SERIAL]) == serial,
		label + " retains original body/sample ABI offsets")
	var displaced: int = int(result[Coupling.RESULT_DISPLACED_COUNT])
	var unresolved: int = int(result[Coupling.RESULT_UNRESOLVED_COUNT])
	var immovable: int = int(result[Coupling.RESULT_UNRESOLVED_IMMOVABLE_COUNT])
	var no_target: int = int(result[Coupling.RESULT_UNRESOLVED_NO_TARGET_COUNT])
	var relocation: int = int(result[Coupling.RESULT_UNRESOLVED_RELOCATION_REFUSED_COUNT])
	check(unresolved == immovable + no_target + relocation,
		label + " exact unresolved partition")
	check(immovable == 0 and relocation == 0, label + " no invented refusal")
	var should_move: bool = mode == "open" or (policy == 1
		and (mode == "lateral" or mode == "longitudinal"))
	check(displaced == (1 if should_move else 0)
		and unresolved == (0 if should_move else 1)
		and no_target == (0 if should_move else 1),
		label + " precommitted policy outcome")
	var stored: PackedByteArray = _stored_cells(world, native)
	check(stored.size() == SIZE.x * SIZE.y, label + " source-owned region readable")
	if stored.size() != SIZE.x * SIZE.y:
		return {}
	var sand_count: int = 0
	for material: int in stored:
		if material == SAND:
			sand_count += 1
	check(sand_count == expected_sand, label + " Sand conserved exactly")
	check(_at(stored, CENTER.x, CENTER.y) == (EMPTY if should_move else SAND),
		label + " source identity conserved or vacated exactly")
	if should_move:
		var target: Vector2i = Vector2i(64, 65)
		if mode == "lateral":
			target = Vector2i(59, 65)
		elif mode == "longitudinal":
			target = Vector2i(64, 74)
		check(_at(stored, target.x, target.y) == SAND,
			label + " deterministic intended target receives Sand")
	if native:
		check(not world.has_failed(), label + " native owner stays healthy")
	return {"mode":mode, "policy":policy, "native":native, "workers":workers,
		"displaced":displaced, "unresolved":unresolved, "no_target":no_target,
		"sand":sand_count, "digest":_digest(stored),
		"duration_usec":duration_us}

func _run() -> void:
	check(Coupling.RESULT_STRIDE == 12 and Coupling.RESULT_SAMPLE_SERIAL == 8,
		"experimental policy does not change existing result ABI")
	var signatures: Dictionary = {}
	var cases: Array[Dictionary] = []
	var serial: int = 100
	for native: bool in [false, true]:
		for workers: int in [1, 4]:
			for policy: int in [0, 1]:
				for mode: String in MODES:
					serial += 1
					var sample: Dictionary = _case(native, workers, policy, mode, serial)
					cases.append(sample)
					if sample.is_empty():
						continue
					var key: String = ("%s/%d/%s" %
						["native" if native else "fallback", policy, mode])
					var signature: String = ("%d,%d,%d,%s" % [
						sample.displaced, sample.unresolved, sample.sand, sample.digest])
					if signatures.has(key):
						check(signatures[key] == signature, key + " workers 1/4 deterministic parity")
					else:
						signatures[key] = signature
	# Construction-time admission rejection does not replace a healthy old owner.
	var admission: Object = _fresh(true, 1, 1)
	if admission != null:
		_fill(admission, true, CENTER, Vector2i.ONE, SAND)
		check(not admission.diagnostic_reset({"workers":1, "ejection_policy":2}),
			"out-of-range diagnostic policy refused")
		check(not admission.diagnostic_reset({"workers":1, "ejection_policy":0.5}),
			"nonintegral diagnostic policy refused")
		check(admission.get_ejection_policy() == 1,
			"invalid policy retains prior selected owner")
		var retained: PackedByteArray = _stored_cells(admission, true)
		check(retained.size() == SIZE.x * SIZE.y and _at(retained, 64, 64) == SAND,
			"invalid policy retains old authoritative source cell")
		check(admission.reset_demo_world() and admission.get_ejection_policy() == 0,
			"ordinary demo reset returns the search policy to baseline")
	var report: Dictionary = {"schema":"cybersand.sol281.ejection-policy-protocol.v1",
		"platform":OS.get_name(), "checks":checks, "failures":failures,
		"baseline_candidates_max":81, "extended_candidates_max":289,
		"cases":cases, "signature_groups":signatures,
		"scope":"deterministic bounded diagnostic-only A/B protocol; no Rapier or release acceptance"}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("SOL281_EJECTION_POLICY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
