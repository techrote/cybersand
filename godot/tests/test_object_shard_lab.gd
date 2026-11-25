extends SceneTree

const Session = preload("res://scripts/object_shard_lab_session.gd")
var failures: int = 0
var checks: int = 0
var reports: Array[Dictionary] = []


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
	await _ordinary()
	var stage: String = "m2"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--objectshard-stage="):
			stage = argument.trim_prefix("--objectshard-stage=")
	if stage != "m0":
		await _burning()
		await _multiple()
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


func _burning() -> void:
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
	var first_revision: int = 0
	for row: Dictionary in session.frame.shards:
		first_revision = int(row.material_revision)
		for state: int in row.states_b:
			burning = burning or state > 0
	_expect(burning, "B: burn state survives transfer")
	var fire_seen: bool = false
	var smoke_seen: bool = false
	var geometry_changed: bool = false
	for tick: int in range(560):
		session.advance(true)
		if session.failed:
			break
		fire_seen = fire_seen or _world_count(session.frame, 6) > 0
		smoke_seen = smoke_seen or _world_count(session.frame, 4) > 0
		for row: Dictionary in session.frame.shards:
			geometry_changed = geometry_changed or int(row.geometry_revision) > 1
		if tick % 40 == 0:
			await process_frame
	_expect(not session.failed, "B: continuing chemistry and geometry remain operational")
	_expect(int(session.frame.metrics.get("products_created", 0)) > 0, "B: native Wood creates authentic products")
	var emitted: PackedInt64Array = session.frame.accounting.get("emitted", PackedInt64Array())
	_expect(emitted.size() > 6 and emitted[6] > 0, "B: actual shard-owned Fire transfers into World")
	_expect(fire_seen and smoke_seen, "B: actual World Fire and subsequent Smoke are observed")
	_expect(geometry_changed, "B: consumption changes exact rigid geometry")
	reports.append(session.export_result())
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


func _world_count(frame: Dictionary, material: int) -> int:
	var count: int = 0
	for value: int in frame.get("world_materials", PackedByteArray()):
		if value == material:
			count += 1
	return count


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
		"failures": failures, "engine": Engine.get_version_info(), "platform": OS.get_name(), "scenarios": reports}
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
