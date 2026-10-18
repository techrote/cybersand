extends SceneTree

var _failures: int = 0


class TestWorld extends RefCounted:
	var cells: Dictionary = {}
	var masks: Dictionary = {}
	var calls: int = 0
	var reject_writes: bool = false

	func material_at(x: int, y: int) -> int:
		if masks.has(Vector2i(x, y)):
			return 1
		return int(cells.get(Vector2i(x, y), 0))

	func rigid_body_id_at(x: int, y: int) -> int:
		return int(masks.get(Vector2i(x, y), 0))

	func emit_disc(x: int, y: int, radius: int, material: int) -> void:
		assert(radius == 0, "effect escaped the per-cell adapter boundary")
		calls += 1
		if not reject_writes and not masks.has(Vector2i(x, y)):
			cells[Vector2i(x, y)] = material

	func has_failed() -> bool:
		return false


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("ACT-004 physical effects: " + message)


func _request(sequence: int = 1, kind: String = "deposit") -> Dictionary:
	return {
		"actor_slot": 0, "epoch": 1, "sequence": sequence,
		"source_body_id": 1, "source_part": 0,
		"kind": kind, "source": Vector2(100.5, 100.5),
		"origin": Vector2(106.5, 100.5), "radius": 2,
		"strength": 1.0, "material": 2,
	}


func _world() -> TestWorld:
	var world := TestWorld.new()
	world.masks[Vector2i(100, 100)] = 1
	world.masks[Vector2i(101, 100)] = 1
	return world


func _changed(receipts: Array) -> int:
	var count: int = 0
	for receipt: Dictionary in receipts:
		count += int(receipt["changed_cells"])
	return count


func _identity_and_counts() -> void:
	var world: TestWorld = _world()
	var effects := CyberPhysicalActorEffects.new()
	var request: Dictionary = _request()
	var receipts: Array = effects.apply(world, [request], 1)
	_check(_changed(receipts) == 13 and world.calls == 13, "Sand disc actual cell count")
	_check(bool(receipts[0]["consumed"]) and receipts[0]["status"] == "applied", "accepted receipt")
	_check(effects.apply(world, [request], 1)[0]["reason"] == "sequence", "duplicate was not refused")
	_check(world.calls == 13, "duplicate effect wrote cells")
	var old: Dictionary = _request(2)
	old["epoch"] = 0
	_check(effects.apply(world, [old], 1)[0]["reason"] == "epoch", "stale epoch admitted")
	effects.reset(2)
	request["epoch"] = 2
	request["origin"] = Vector2(114.5, 100.5)
	_check(_changed(effects.apply(world, [request], 2)) == 13, "fresh epoch could not reuse sequence")
	_check(effects.apply(world, [], 1)[0]["reason"] == "epoch", "owner epoch rolled backwards")

	var rejecting: TestWorld = _world()
	rejecting.reject_writes = true
	effects = CyberPhysicalActorEffects.new()
	receipts = effects.apply(rejecting, [_request()], 1)
	_check(_changed(receipts) == 0 and rejecting.calls == 13, "attempted writes counted as changed cells")
	_check(receipts[0]["status"] == "no_change", "refusing adapter produced false success")


func _barriers_and_source_identity() -> void:
	for barrier: String in ["wall", "other_body", "wrong_source", "wall_source", "diagonal"]:
		var world: TestWorld = _world()
		var request: Dictionary = _request()
		match barrier:
			"wall": world.cells[Vector2i(103, 100)] = 1
			"other_body": world.masks[Vector2i(103, 100)] = 2
			"wrong_source": request["source_body_id"] = 2
			"wall_source":
				world.masks.clear()
				world.cells[Vector2i(100, 100)] = 1
			"diagonal":
				world.masks.erase(Vector2i(101, 100))
				world.cells[Vector2i(101, 100)] = 1
				request["origin"] = Vector2(105.5, 105.5)
		var effects := CyberPhysicalActorEffects.new()
		var receipts: Array = effects.apply(world, [request], 1)
		_check(_changed(receipts) == 0 and world.calls == 0, barrier + " allowed effect through obstruction")
		world.cells.clear()
		world.masks.clear()
		_check(effects.apply(world, [request], 1)[0]["reason"] == "sequence", "blocked attempt replayed after clearance")

	var world: TestWorld = _world()
	world.cells[Vector2i(107, 100)] = 1
	world.cells[Vector2i(105, 100)] = 3 # Existing liquid must survive deposition.
	world.masks[Vector2i(106, 99)] = 2
	var effects := CyberPhysicalActorEffects.new()
	var receipts: Array = effects.apply(world, [_request()], 1)
	_check(_changed(receipts) > 0, "unblocked portion of footprint was lost")
	_check(world.material_at(107, 100) == 1, "depositor replaced protected terrain")
	_check(world.material_at(108, 100) == 0, "footprint crossed protected one-cell wall")
	_check(world.material_at(105, 100) == 3, "depositor replaced existing material")
	_check(not world.cells.has(Vector2i(106, 99)), "depositor wrote beneath another body")


func _tools_and_pattern() -> void:
	var world: TestWorld = _world()
	for x: int in range(104, 109):
		world.cells[Vector2i(x, 100)] = 2
	world.cells[Vector2i(107, 100)] = 1
	var effects := CyberPhysicalActorEffects.new()
	var receipts: Array = effects.apply(world, [_request(1, "dig")], 1)
	_check(_changed(receipts) == 3, "DIG did not preserve original protected footprint contract")
	_check(world.material_at(107, 100) == 1 and world.material_at(108, 100) == 2,
		"DIG crossed protected wall")

	world = _world()
	effects = CyberPhysicalActorEffects.new()
	var rocket: Dictionary = _request(1, "blast")
	rocket["pattern"] = "rocket_charge"
	receipts = effects.apply(world, [rocket], 1)
	_check(_changed(receipts) == 5 and world.material_at(106, 100) == 6, "Rocketjumper Fire centre")
	for offset: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]:
		_check(world.material_at(106 + offset.x, 100 + offset.y) == 26, "Rocketjumper Gunpowder ring")
	_check(world.material_at(106, 101) == 0, "Rocketjumper filled its intended ring interior")

	# Excavation and ring deposition can touch the same cell twice. Changed
	# cells report distinct affected positions; attempted writes remain separate.
	world = _world()
	world.cells[Vector2i(108, 100)] = 2
	effects = CyberPhysicalActorEffects.new()
	receipts = effects.apply(world, [rocket], 1)
	_check(_changed(receipts) == 5 and int(receipts[0]["attempted_writes"]) == 6,
		"Rocketjumper double-counted a dug and redeposited ring cell")

	world = _world()
	world.cells[Vector2i(106, 100)] = 5 # Cloner is protected even at blast centre.
	effects = CyberPhysicalActorEffects.new()
	_check(_changed(effects.apply(world, [rocket], 1)) == 0 and world.calls == 0,
		"Rocketjumper pattern bypassed protected centre")


func _budgets_and_validation() -> void:
	var world: TestWorld = _world()
	var effects := CyberPhysicalActorEffects.new()
	var wide: Dictionary = _request()
	wide["radius"] = 4
	var receipts: Array = effects.apply(world, [wide], 1)
	_check(_changed(receipts) == 49, "radius-four footprint was truncated")
	_check(int(receipts[0]["attempted_writes"]) <= 64 and int(receipts[0]["reads"]) <= 1024,
		"effect exceeded read/write bounds")
	var excess: Array = []
	for _index: int in range(9): excess.append(_request(2))
	_check(effects.apply(world, excess, 1)[0]["reason"] == "request_capacity", "oversized batch admitted")
	_check(world.calls == 49, "oversized batch partially executed")
	effects = CyberPhysicalActorEffects.new()
	receipts = effects.apply(world, [_request(2), _request(3)], 1)
	_check(receipts.size() == 2 and receipts[1]["reason"] == "actor_budget", "one actor consumed two effects per frame")

	for mutation: Dictionary in [
		{"actor_slot": 8}, {"actor_slot": true}, {"radius": 5}, {"radius": 1.5},
		{"source": Vector2(NAN, 100)}, {"origin": Vector2(1.0e20, 1.0e20)},
		{"origin": Vector2(500, 100)}, {"strength": INF}, {"strength": true},
		{"material": 1}, {"pattern": "arbitrary"}, {"native_write": true},
	]:
		var request: Dictionary = _request()
		request.merge(mutation, true)
		var fresh: TestWorld = _world()
		var validator := CyberPhysicalActorEffects.new()
		receipts = validator.apply(fresh, [request], 1)
		_check(_changed(receipts) == 0 and fresh.calls == 0 and not receipts[0]["consumed"],
			"invalid request admitted: " + str(mutation))


func _native_adapter_smoke() -> void:
	# This same test can run as an isolated pure-GDScript contract test. The
	# registered native lane additionally proves the production adapter path.
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		print("ACT004_EFFECTS native adapter unavailable in isolated contract host")
		return
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	_check(world.diagnostic_reset({"workers": 1}), "native effect fixture reset")
	var states := PackedFloat32Array()
	CyberRigidBodyCoupling.append_input(states, 64, Vector2(100.5, 100.5), 0.0,
		Vector2(2, 2), Vector2.ZERO, 0.0, 1.0, 1)
	world.prepare_rigid_body_coupling(states, false)
	_check(world.rigid_body_id_at(100, 100) == 64, "native source-mask query lost highest identity")
	var request: Dictionary = _request()
	request["source_body_id"] = 64
	var effects := CyberPhysicalActorEffects.new()
	var receipts: Array = effects.apply(world, [request], 1)
	_check(_changed(receipts) == 13 and world.material_at(106, 100) == 2, "native depositor receipt")
	world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	_check(world.rigid_body_id_at(100, 100) == 0 and world.material_at(100, 100) == 0,
		"source-mask exemption wrote material beneath the actor")
	print("ACT004_EFFECTS native adapter=executed")


func _run() -> void:
	_identity_and_counts()
	_barriers_and_source_identity()
	_tools_and_pattern()
	_budgets_and_validation()
	_native_adapter_smoke()
	if _failures == 0:
		print("ACT-004 physical usable effects passed")
	quit(1 if _failures > 0 else 0)
