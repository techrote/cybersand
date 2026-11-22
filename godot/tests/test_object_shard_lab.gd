extends SceneTree

const Session = preload("res://scripts/object_shard_lab_session.gd")
const View = preload("res://scripts/object_shard_lab_view.gd")
var failures: int = 0
var checks: int = 0
var reports: Array[Dictionary] = []
var test_stage: String = "m2"


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	if not ClassDB.class_exists(&"CyberObjectShardLab"):
		_expect(false, "exact-source ObjectShard native extension is loaded")
		_finish()
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--objectshard-stage="):
			test_stage = argument.trim_prefix("--objectshard-stage=")
	await _ordinary()
	if test_stage != "m0":
		await _burning(test_stage == "m2")
		await _perforated()
	if test_stage == "m2":
		await _exchange()
		await _multiple()
		await _draining_anchor()
	await _scene_presentation()
	_finish()


func _ordinary() -> void:
	var session = Session.new()
	_expect(session.open(1, 12).get("ok", false), "A: native Lab opens")
	if session.failed:
		session.close()
		return
	var original: int = _world_count(session.frame, 7)
	var erased: int = _erase_lowest_wood(session)
	_expect(erased > 0 and original > erased, "A: ordinary edits remove a real support band")
	for tick: int in range(20):
		session.advance(true)
		if not session.bridge.bodies.is_empty() or session.failed:
			break
	_expect(not session.failed and session.bridge.bodies.size() == 1, "A: mutation-driven discovery activates one body")
	if session.failed or session.bridge.bodies.is_empty():
		reports.append(session.export_result())
		session.close()
		return
	var row: Dictionary = session.frame.shards[0]
	_expect(_world_count(session.frame, 7) + int(row.structural) == original - erased,
		"A: ownership transfer neither loses nor duplicates Wood")
	var phases: Array[String] = []
	for event: Dictionary in session.events:
		if str(event.kind) in ["CommittedInactive", "MaskApplied", "Active"]:
			phases.append(str(event.kind))
	_expect(phases == ["CommittedInactive", "MaskApplied", "Active"], "A: installed terrain/mask precedes activation")
	var first: Dictionary = session.bridge.sample_poses()[0]
	for tick: int in range(120):
		session.advance(true)
		if session.failed:
			break
	var later: Array = session.bridge.sample_poses()
	_expect(not session.failed and not later.is_empty() and float(later[0].y) > float(first.y) + 0.5,
		"A: real Rapier advances transferred inventory")
	_expect(not later.is_empty() and absf(float(later[0].rotation) - float(first.rotation)) > 0.01,
		"A: actual off-centre terrain contact produces rotation")
	var deepest: float = 0.0
	if not later.is_empty():
		var pose := Transform2D(float(later[0].rotation), Vector2(float(later[0].x), float(later[0].y)))
		for index: int in range(0, row.rectangles.size(), 4):
			var x: float = float(row.rectangles[index])
			var y: float = float(row.rectangles[index + 1])
			var w: float = float(row.rectangles[index + 2])
			var h: float = float(row.rectangles[index + 3])
			for corner: Vector2 in [Vector2(x, y), Vector2(x + w, y), Vector2(x, y + h), Vector2(x + w, y + h)]:
				deepest = maxf(deepest, (pose * corner).y)
	_expect(deepest <= float(session.frame.height) - 16.0, "A: moving occupied geometry does not catastrophically cross the floor")
	_expect(int(session.samples[-1].get("snapshot_copies", 0)) == 2,
		"A: native tick and accepted motion each publish once; unchanged terrain readback adds no copy")
	var motion_report: Dictionary = session.export_result()
	motion_report["evidence"] = {"starting_wood": original, "ordinary_erased_wood": erased,
		"promoted_wood": int(row.structural), "phase_order": phases, "first_pose": first,
		"later_poses": later, "deepest_geometry_y": deepest, "checkpoint": "before controlled reset"}
	reports.append(motion_report)
	var old_session: int = int(session.frame.session)
	var stale: Dictionary = session.frame.shards[0].duplicate(true)
	_expect(session.open(1, 12).get("ok", false), "A: reset disposes the entire old session explicitly")
	_expect(int(session.frame.session) != old_session, "A: reset never reuses session identity")
	var receipt: Dictionary = {"kind": "BodyActivated"}
	for key: String in ["session", "id", "generation", "transaction", "body_generation", "payload_digest",
		"geometry_revision", "mask_digest", "shape_digest"]:
		receipt[key] = stale[key]
	_expect(not session.native.acknowledge(receipt).get("ok", false), "A: obsolete activation receipt is nonmutating")
	var reset_report: Dictionary = session.export_result()
	reset_report["evidence"] = {"checkpoint": "after controlled reset", "previous_session": old_session,
		"obsolete_ack_refused": true}
	reports.append(reset_report)
	session.close()
	await process_frame


func _burning(require_exchange: bool) -> void:
	var session = Session.new()
	_expect(session.open(2, 12).get("ok", false), "B: genuine Wood burning scenario opens")
	if session.failed:
		session.close()
		return
	# Allow native World opportunities before transfer; no shard-local reset or
	# artificial visual flame is used to establish combustion.
	for tick: int in range(4):
		session.advance(true)
	_erase_lowest_wood(session)
	for tick: int in range(20):
		session.advance(true)
		if not session.bridge.bodies.is_empty() or session.failed:
			break
	_expect(not session.failed and not session.bridge.bodies.is_empty(), "B: already-burning native material promotes")
	if session.failed or session.bridge.bodies.is_empty():
		reports.append(session.export_result())
		session.close()
		return
	var burning: bool = false
	var burning_cell: int = -1
	var maximum_burn: int = -1
	for row: Dictionary in session.frame.shards:
		for cell: int in range(row.states_b.size()):
			if int(row.materials[cell]) == 7 and int(row.states_b[cell]) > 0:
				burning = true
				if int(row.states_b[cell]) > maximum_burn:
					maximum_burn = int(row.states_b[cell])
					burning_cell = cell
	_expect(burning, "B: burn state survives transfer")
	# Rapier sleep and the semantic chemistry clock are independent. Freeze no
	# native clock: the actual body sleeps while twenty native ticks continue.
	var body_id: int = int(session.frame.shards[0].id)
	var burn_before: int = int(session.frame.shards[0].states_b[burning_cell]) if burning_cell >= 0 else 0
	var body_rid: RID = session.bridge.bodies[body_id].rid
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_SLEEPING, true)
	var sleep_observed: bool = false
	var sleeping_burn_opportunities: int = 0
	for tick: int in range(20):
		var was_sleeping: bool = bool(PhysicsServer2D.body_get_state(body_rid, PhysicsServer2D.BODY_STATE_SLEEPING))
		var before_opportunity: int = int(session.frame.shards[0].states_b[burning_cell]) if burning_cell >= 0 else 0
		sleep_observed = sleep_observed or was_sleeping
		session.advance(true)
		if session.failed:
			break
		if was_sleeping and burning_cell >= 0 and int(session.frame.shards[0].states_b[burning_cell]) < before_opportunity:
			sleeping_burn_opportunities += 1
	var burn_after: int = int(session.frame.shards[0].states_b[burning_cell]) if burning_cell >= 0 else 0
	_expect(sleep_observed and burn_after < burn_before and burn_after > 0, "B: actual sleeping body continues Wood lifecycle on semantic ticks")
	_expect(sleeping_burn_opportunities > 0, "B: a genuine combustion opportunity executes while actual Rapier state is sleeping")
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_SLEEPING, false)
	var fire_seen: bool = false
	var smoke_seen: bool = false
	var retained_fire_seen: bool = false
	var retained_smoke_seen: bool = false
	var geometry_changed: bool = false
	var geometry_ack_snapshot_seen: bool = false
	var observed_geometry: int = int(session.frame.shards[0].geometry_revision)
	for tick: int in range(560):
		session.advance(true)
		if session.failed:
			break
		fire_seen = fire_seen or _world_count(session.frame, 6) > 0
		smoke_seen = smoke_seen or _world_count(session.frame, 4) > 0
		for row: Dictionary in session.frame.shards:
			geometry_changed = geometry_changed or int(row.geometry_revision) > 1
			if int(row.geometry_revision) > observed_geometry:
				geometry_ack_snapshot_seen = int(row.applied_physics_revision) == int(row.geometry_revision) \
					and int(session.samples[-1].get("snapshot_copies", 0)) >= 2
				observed_geometry = int(row.geometry_revision)
			retained_fire_seen = retained_fire_seen or row.materials.has(6)
			retained_smoke_seen = retained_smoke_seen or row.materials.has(4)
		if tick % 40 == 0:
			await process_frame
	_expect(not session.failed, "B: continuing chemistry and geometry remain operational")
	_expect(int(session.frame.metrics.get("products_created", 0)) > 0, "B: native Wood creates authentic products")
	if require_exchange:
		var emitted: PackedInt64Array = session.frame.accounting.get("emitted", PackedInt64Array())
		_expect(emitted.size() > 6 and emitted[6] > 0, "B: actual shard-owned Fire transfers into World")
		_expect(fire_seen and smoke_seen, "B: actual World Fire and subsequent Smoke are observed")
	else:
		_expect(retained_fire_seen and retained_smoke_seen, "M1: retained authentic Fire executes selected Fire-to-Smoke lifecycle")
	_expect(geometry_changed, "B: consumption changes exact rigid geometry")
	_expect(geometry_ack_snapshot_seen, "B: a real geometry acknowledgement refreshes the native publication before presentation")
	var chemistry_report: Dictionary = session.export_result()
	chemistry_report["evidence"] = {"burn_before_sleep": burn_before, "burn_after_sleep": burn_after,
		"sleeping_burn_opportunities": sleeping_burn_opportunities,
		"actual_sleep_observed": sleep_observed, "world_fire_seen": fire_seen, "world_smoke_seen": smoke_seen,
		"retained_fire_seen": retained_fire_seen, "retained_smoke_seen": retained_smoke_seen,
		"geometry_changed": geometry_changed, "exchange_required": require_exchange}
	reports.append(chemistry_report)
	session.close()
	await process_frame


func _perforated() -> void:
	var session = Session.new()
	_expect(session.open(1, 12).get("ok", false), "M1: mutable perforated native fixture opens")
	if session.failed:
		session.close()
		return
	var width: int = int(session.frame.width)
	var cells: PackedByteArray = session.frame.world_materials
	var holes: Array[Vector2i] = []
	for y: int in range(2, int(session.frame.height) - 2, 3):
		for x: int in range(2, width - 2, 3):
			var at: int = y * width + x
			if cells[at] == 7 and cells[at - 1] == 7 and cells[at + 1] == 7 and cells[at - width] == 7 and cells[at + width] == 7:
				holes.append(Vector2i(x, y))
	for position: Vector2i in holes:
		session.edit(position, 0)
	_erase_lowest_wood(session)
	for tick: int in range(30):
		session.advance(true)
		if session.failed or not session.bridge.bodies.is_empty():
			break
	var shapes: int = 0
	for row: Dictionary in session.frame.shards:
		shapes += row.rectangles.size() / 4
	_expect(not session.failed and not session.bridge.bodies.is_empty() and shapes > 8,
		"M1: actual native perforated geometry exceeds eight shapes and activates with holes intact")
	var report: Dictionary = session.export_result()
	report["evidence"] = {"fixture": "ordinary native perforation", "holes": holes.size(), "actual_shape_count": shapes}
	reports.append(report)
	session.close()
	await process_frame


func _multiple() -> void:
	var session = Session.new()
	_expect(session.open(4, 12).get("ok", false), "D: multiple-body scenario opens")
	if session.failed:
		session.close()
		return
	_erase_lowest_wood(session)
	for tick: int in range(30):
		session.advance(true)
		if session.bridge.bodies.size() == 3 or session.failed:
			break
	_expect(not session.failed and session.bridge.bodies.size() == 3, "D: three independent inventories become bodies")
	var ids: Dictionary = {}
	for row: Dictionary in session.frame.shards:
		ids[row.id] = true
	_expect(ids.size() == 3, "D: three stable native identities are distinct")
	for tick: int in range(90):
		session.advance(true)
		if session.failed:
			break
	_expect(not session.failed, "D: three owners remain bounded and operational")
	reports.append(session.export_result())
	session.close()
	await process_frame


func _exchange() -> void:
	var session = Session.new()
	_expect(session.open(3, 12).get("ok", false), "C: actual external Water/Sand fixture opens")
	if session.failed:
		session.close()
		return
	var initial_sand: int = _world_count(session.frame, 2)
	_erase_lowest_wood(session)
	var cargo: int = 0
	for tick: int in range(150):
		session.advance(true)
		if session.failed:
			break
		cargo = 0
		for row: Dictionary in session.frame.shards:
			cargo += int(row.cargo)
		if cargo > 0:
			break
	_expect(not session.failed and session.bridge.bodies.size() == 1, "C: real pocket body remains active during contact")
	_expect(cargo > 0 and int(session.frame.metrics.get("sand_ingested", 0)) > 0,
		"C: authored World Sand physically falls through the aperture and becomes native cargo")
	_expect(_world_count(session.frame, 2) + cargo == initial_sand, "C: World-to-pocket ownership transfer preserves every baseline Sand cell")
	var inspected_cargo: Dictionary = {}
	for row: Dictionary in session.frame.shards:
		for cell: int in range(row.roles.size()):
			if int(row.roles[cell]) == 3:
				inspected_cargo = {"material": int(row.materials[cell]), "state_a": int(row.states_a[cell]),
					"state_b": int(row.states_b[cell]), "temperature": int(row.temperature[cell]), "incarnation": int(row.incarnations[cell])}
	_expect(not inspected_cargo.is_empty() and int(inspected_cargo.get("material", -1)) == 2
		and int(inspected_cargo.get("state_a", -1)) == 0 and int(inspected_cargo.get("state_b", -1)) == 0
		and int(inspected_cargo.get("temperature", -1)) == 200,
		"C: visible carried Sand retains the admitted native tuple and ambient temperature")
	var water: Dictionary = _put_water_by_hot_surface(session)
	_expect(water.get("ok", false), "C: actual World Water is authored beside exposed burning Wood")
	var extinguished: bool = false
	for tick: int in range(6):
		session.advance(true)
		if session.failed:
			break
		for row: Dictionary in session.frame.shards:
			if int(row.id) == int(water.get("id", -1)):
				var cell: int = int(water.get("cell", -1))
				if cell >= 0:
					extinguished = int(row.materials[cell]) == 7 and int(row.states_b[cell]) == 0 \
						and int(row.incarnations[cell]) == int(water.incarnation)
		if extinguished:
			break
	_expect(not session.failed and extinguished and int(session.frame.accounting.get("extinguished", 0)) > 0,
		"C: external Water exposure extinguishes the same surviving Wood incarnation")
	var ingested: PackedInt64Array = session.frame.accounting.get("ingested", PackedInt64Array())
	_expect(ingested.size() > 3 and ingested[3] == 0, "C: Water remains World-owned; no liquid sidecar transfer is invented")
	var report: Dictionary = session.export_result()
	report["evidence"] = {"initial_world_sand": initial_sand, "world_sand_after": _world_count(session.frame, 2),
		"cargo_after": cargo, "cargo_tuple": inspected_cargo, "water_contact": water, "same_cell_extinguished": extinguished}
	reports.append(report)
	session.close()
	await process_frame


func _put_water_by_hot_surface(session: CyberObjectShardLabSession) -> Dictionary:
	# This authors ordinary World Water outside the rigid skeleton. The native
	# contact sampler must independently witness it; there is no exposure command.
	for row: Dictionary in session.frame.get("shards", []):
		if not session.bridge.bodies.has(int(row.id)):
			continue
		var rid: RID = session.bridge.bodies[int(row.id)].rid
		var pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		for cell: int in range(row.materials.size()):
			if int(row.materials[cell]) != 7 or int(row.states_b[cell]) == 0:
				continue
			var center := Vector2(float(cell % int(row.width)) + 0.5, float(cell / int(row.width)) + 0.5)
			for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var adjacent := Vector2i(floori(center.x + offset.x), floori(center.y + offset.y))
				if adjacent.x >= 0 and adjacent.y >= 0 and adjacent.x < int(row.width) and adjacent.y < int(row.height) \
					and int(row.materials[adjacent.y * int(row.width) + adjacent.x]) != 0:
					continue
				var point: Vector2 = pose * (center + offset)
				var position := Vector2i(floori(point.x), floori(point.y))
				var before: Dictionary = session.native.inspect(position)
				if not before.get("ok", false) or int(before.get("material", -1)) != 0:
					continue
				var result: Dictionary = session.edit(position, 3, 255)
				if result.get("ok", false):
					return {"ok": true, "id": int(row.id), "cell": cell, "incarnation": int(row.incarnations[cell]),
						"burn_before": int(row.states_b[cell]), "world_position": position, "whole_world_water_quanta": 255}
	return {"ok": false}


func _world_count(frame: Dictionary, material: int) -> int:
	var count: int = 0
	for value: int in frame.get("world_materials", PackedByteArray()):
		if value == material:
			count += 1
	return count


func _draining_anchor() -> void:
	var session = Session.new()
	session.native = ClassDB.instantiate(&"CyberObjectShardLab")
	_expect(session.native.configure({"scenario": 0, "seed": 12, "transfer_budget": 0}).get("ok", false),
		"Draining: explicit zero transfer capacity retains real product carriers")
	_expect(session.open(0, 12).get("ok", false), "Draining: empty real Lab opens")
	_expect(int(session.native.capabilities().get("transfer_budget_per_tick", -1)) == 0, "Draining: native resource limit is actually applied")
	_expect(session.edit(Vector2i(80, 50), 7, 0, 24).get("ok", false), "Draining: ordinary authoring creates one burning Wood cell")
	for tick: int in range(12):
		session.advance(true)
		if not session.bridge.bodies.is_empty() or session.failed:
			break
	_expect(not session.failed and session.bridge.bodies.size() == 1, "Draining: true single-cell inventory promotes")
	if session.failed or session.bridge.bodies.is_empty():
		session.close()
		return
	for tick: int in range(8):
		session.advance(true)
	var initial: Dictionary = session.frame.shards[0]
	var id: int = int(initial.id)
	var rid: RID = session.bridge.bodies[id].rid
	var moved: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(moved.origin.distance_to(Vector2(initial.origin_x, initial.origin_y)) > 0.5, "Draining: Rapier actually moves the local lattice before retirement")
	# Transfer capacity is zero, so authentic Wood-created products remain in
	# their local carriers while actual Rapier motion and native chemistry continue.
	var draining: Dictionary = {}
	for tick: int in range(100):
		if session.bridge.bodies.has(id):
			moved = PhysicsServer2D.body_get_state(session.bridge.bodies[id].rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		session.advance(true)
		if session.failed:
			break
		for shard: Dictionary in session.frame.shards:
			if int(shard.id) == id and int(shard.structural) == 0 and int(shard.products) > 0 and not bool(shard.has_body):
				draining = shard
		if not draining.is_empty():
			break
	_expect(not session.failed and not draining.is_empty() and not session.bridge.bodies.has(id),
		"Draining: last Wood consumption retires the actual body while products remain owned")
	var inspected: Dictionary = {}
	if not draining.is_empty():
		var anchor := Vector2(float(draining.position_x), float(draining.position_y))
		_expect(anchor.distance_to(moved.origin) < 0.01, "Draining: native snapshot keeps the last physical anchor instead of capture coordinates")
		var view = View.new()
		_expect(view.material_pose(draining).origin.distance_to(moved.origin) < 0.01,
			"Draining: the ordinary render adapter retains the same anchor without a live RID pose")
		view.free()
		for cell: int in range(draining.roles.size()):
			if int(draining.roles[cell]) == 2:
				var center := Vector2(float(cell % int(draining.width)) + 0.5, float(cell / int(draining.width)) + 0.5)
				var point: Vector2 = moved * center
				inspected = session.inspect(Vector2i(floori(point.x), floori(point.y)))
				_expect(str(inspected.get("owner", "")) == "ObjectShard" and int(inspected.get("cell", -1)) == cell,
					"Draining: owner inspection resolves retained products at their actual final location")
				break
		_expect(not inspected.is_empty(), "Draining: retained product is inspectable after body retirement")
	var report: Dictionary = session.export_result()
	report["evidence"] = {"fixture": "moved body retired with zero transfer capacity and retained products", "last_physical_pose": moved,
		"retained_domain": not draining.is_empty(), "inspected_product": inspected}
	reports.append(report)
	session.close()
	await process_frame


func _scene_presentation() -> void:
	var scene: PackedScene = load("res://object_shard_lab.tscn")
	var lab = scene.instantiate()
	root.add_child(lab)
	await process_frame
	_expect(not lab.session.failed, "Scene: ordinary owner Lab opens with actual native and Rapier adapters")
	if test_stage != "m0":
		lab._open(2)
		_expect(lab.scenario_select.selected == 1 and lab.session.scenario == 2,
			"Scene: programmatic scenario change updates the visible selected scenario")
	lab.inspection_label.text = "obsolete previous owner"
	lab._open(1)
	_expect(not lab.inspection_label.text.contains("obsolete previous owner"), "Scene: reset clears stale inventory inspection")
	var wood: Vector2i = Vector2i(-1, -1)
	for cell: int in range(lab.session.frame.world_materials.size()):
		if int(lab.session.frame.world_materials[cell]) == 7:
			wood = Vector2i(cell % int(lab.session.frame.width), cell / int(lab.session.frame.width))
			break
	_expect(wood.x >= 0, "Scene: inspectable Wood belongs to the actual World")
	lab._cell_pressed(wood, MOUSE_BUTTON_RIGHT)
	var summary: String = lab.inspection_label.text.get_slice("{", 0)
	_expect(summary.contains("Wood") and summary.contains("World") and summary.contains("state_b") and summary.contains("temperature"),
		"Scene: material, owner, chemical state and temperature precede the scrollable exact tuple")
	lab.canvas.overlays = true
	lab._present()
	_expect(lab.overlay_toggle.button_pressed, "Scene: overlay control matches actual visible shapes")
	lab.queue_free()
	await process_frame


func _erase_lowest_wood(session: CyberObjectShardLabSession) -> int:
	var frame: Dictionary = session.frame
	var width: int = int(frame.width)
	var cells: PackedByteArray = frame.world_materials
	for y: int in range(int(frame.height) - 1, -1, -1):
		var points: Array[Vector2i] = []
		for x: int in range(width):
			if cells[y * width + x] == 7:
				points.append(Vector2i(x, y))
		if points.is_empty():
			continue
		points.clear()
		for band_y: int in range(maxi(0, y - 11), y + 1):
			for x: int in range(width):
				if cells[band_y * width + x] == 7:
					points.append(Vector2i(x, band_y))
		for point: Vector2i in points:
			_expect(session.edit(point, 0).get("ok", false), "ordinary material erase accepted")
		return points.size()
	return 0


func _finish() -> void:
	var result: Dictionary = {"schema": "objectshard-lab-integration-test-v1", "checks": checks,
		"failures": failures, "stage": test_stage, "engine": Engine.get_version_info(), "platform": OS.get_name(), "scenarios": reports}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--objectshard-report="):
			var path: String = argument.trim_prefix("--objectshard-report=")
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if output == null:
				failures += 1
				push_error("Could not retain ObjectShard test result")
			else:
				output.store_string(JSON.stringify(result, "  ") + "\n")
				output.close()
	print(JSON.stringify({"schema": result.schema, "checks": checks, "failures": failures,
		"engine": Engine.get_version_info(), "platform": OS.get_name()}))
	quit(failures)
