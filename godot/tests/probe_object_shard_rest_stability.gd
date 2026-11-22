extends SceneTree

# Controlled actual-Rapier probe, not a replacement material simulation. The
# independent cell fixture uses the M2 tree silhouette and exact unit-cell mass.
# Synthetic mass-only and shape-only interventions isolate adapter mechanisms;
# they are explicitly not advertised material transactions.
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
const REGISTRATION = {
	"schema": "objectshard-rest-stability-registration-v1",
	"fixed_delta": 1.0 / 60.0,
	"settle_steps": 1800,
	"post_intervention_steps": 1800,
	"rest_speed_cells_per_second": 0.25,
	"rest_angular_speed_radians_per_second": 0.015,
	"rest_consecutive_steps": 180,
	"non_support_erosion_max_rotation_radians": 0.10,
	"non_support_erosion_max_translation_cells": 3.0,
	"non_support_erosion_max_step_rotation_radians": 0.05,
	"scope": "Naturally settled tree; one crown surface cell removed on a broad contact face, as inferred from owner D mass/COM. An isolated physics intervention is not a replay of the owner's incomplete input history."
}

var variant: String = "erode"
var count: int = 3
var initial_tilt: float = 0.12
var output_path: String = "user://objectshard-rest-probe.json"
var trace: FileAccess
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []
var bridge: CyberObjectShardPhysicsBridge


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="):
			variant = argument.trim_prefix("--variant=")
		elif argument.begins_with("--bodies="):
			count = int(argument.trim_prefix("--bodies="))
		elif argument.begins_with("--tilt="):
			initial_tilt = float(argument.trim_prefix("--tilt="))
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	if variant not in ["unchanged", "replace-identical", "mass-only", "shape-only", "erode"] or count < 1 or count > 3:
		push_error("Unknown probe intervention or body count")
		quit(2)
		return
	trace = FileAccess.open(output_path + ".jsonl", FileAccess.WRITE)
	if trace == null:
		push_error("Cannot create probe trace")
		quit(2)
		return
	_write({"registration": REGISTRATION, "engine": Engine.get_version_info(), "variant": variant, "bodies": count, "initial_tilt": initial_tilt})
	bridge = Bridge.new()
	_expect(bridge.initialize(7001).get("ok", false), "actual Rapier initialization")
	if failures:
		_finish({})
		return
	_expect(bridge.install_terrain([{"id": 0, "session": 7001, "revision": 1, "digest": "floor-110",
		"rectangles": PackedInt32Array([0, 110, 240, 3, 0, 0, 1, 110, 239, 0, 1, 110])}]).get("ok", false), "actual floor installation")
	for index: int in range(count):
		var cells: Dictionary = _tree_cells()
		var shard: Dictionary = _publication(cells, index + 1, 1)
		shard.position_x = 35.0 + float(index) * 48.0 if count > 1 else 86.0
		shard.position_y = 60.0
		shard.rotation = initial_tilt
		_expect(bridge.reserve_body(shard).get("ok", false), "compound reservation")
		_expect(bridge.activate(shard).get("ok", false), "compound activation")
		var rid: RID = bridge.bodies[index + 1].rid
		PhysicsServer2D.body_set_max_contacts_reported(rid, 32)
		rows.append({"shard": shard, "cells": cells, "rest_steps": 0, "rest_tick": -1,
			"before": {}, "max_rotation": 0.0, "max_translation": 0.0, "max_step_rotation": 0.0,
			"first_instability_tick": -1, "last": _sample(index + 1), "sleep_ticks": 0,
			"maximum_speed": 0.0, "maximum_angular_speed": 0.0})
	var held: Dictionary = {}
	var total_steps: int = int(REGISTRATION.settle_steps) + int(REGISTRATION.post_intervention_steps)
	for tick: int in range(total_steps):
		if tick == int(REGISTRATION.settle_steps):
			for row: Dictionary in rows:
				row.before = _sample(int(row.shard.id))
				_expect(int(row.rest_steps) >= int(REGISTRATION.rest_consecutive_steps), "natural sustained rest before intervention")
				_intervene(row, tick)
		var result: Dictionary = bridge.step()
		var samples: Array[Dictionary] = []
		for row: Dictionary in rows:
			var sample: Dictionary = _sample(int(row.shard.id))
			sample["tick"] = tick
			samples.append(sample)
			var speed: float = Vector2(float(sample.vx), float(sample.vy)).length()
			var angular: float = absf(float(sample.angular_velocity))
			row.maximum_speed = maxf(float(row.maximum_speed), speed)
			row.maximum_angular_speed = maxf(float(row.maximum_angular_speed), angular)
			row.sleep_ticks = int(row.sleep_ticks) + int(bool(sample.sleeping))
			if speed <= float(REGISTRATION.rest_speed_cells_per_second) and angular <= float(REGISTRATION.rest_angular_speed_radians_per_second):
				row.rest_steps = int(row.rest_steps) + 1
				if int(row.rest_steps) == int(REGISTRATION.rest_consecutive_steps) and int(row.rest_tick) < 0:
					row.rest_tick = tick
			else:
				row.rest_steps = 0
			if not row.before.is_empty():
				var angle: float = absf(wrapf(float(sample.rotation) - float(row.before.rotation), -PI, PI))
				var distance: float = Vector2(float(sample.x), float(sample.y)).distance_to(Vector2(float(row.before.x), float(row.before.y)))
				var step_angle: float = absf(wrapf(float(sample.rotation) - float(row.last.rotation), -PI, PI))
				row.max_rotation = maxf(float(row.max_rotation), angle)
				row.max_translation = maxf(float(row.max_translation), distance)
				row.max_step_rotation = maxf(float(row.max_step_rotation), step_angle)
				if int(row.first_instability_tick) < 0 and (angle > float(REGISTRATION.non_support_erosion_max_rotation_radians) or step_angle > float(REGISTRATION.non_support_erosion_max_step_rotation_radians)):
					row.first_instability_tick = tick
			row.last = sample
		_write({"tick": tick, "physics_step": bridge.steps, "result": result, "bodies": samples})
		if not result.get("ok", false):
			held = result
			break
		if tick % 120 == 0:
			await process_frame
	_expect(held.is_empty(), "physics motion remains within the existing envelope")
	for row: Dictionary in rows:
		_expect(not row.before.is_empty(), "intervention checkpoint reached")
		_expect(float(row.max_rotation) <= float(REGISTRATION.non_support_erosion_max_rotation_radians), "no unexplained large post-rest rotation")
		_expect(float(row.max_translation) <= float(REGISTRATION.non_support_erosion_max_translation_cells), "bounded post-rest displacement")
		_expect(float(row.max_step_rotation) <= float(REGISTRATION.non_support_erosion_max_step_rotation_radians), "no abrupt angular jump after rest")
	_finish(held)


func _intervene(row: Dictionary, tick: int) -> void:
	var original: Dictionary = row.shard
	if variant == "unchanged":
		_write({"intervention": variant, "tick": tick, "id": original.id, "before": row.before})
		return
	# The exact cell inferred for two owner D bodies from mass/COM before/after.
	# When the tree lies on its side this removes one cell of a broad contact face.
	row.cells.erase(Vector2i(28, 10))
	var changed: Dictionary = _publication(row.cells, int(original.id), 2)
	if variant == "replace-identical":
		changed = original.duplicate(true)
		changed.geometry_revision = 2
		changed.geometry_digest = "identical-revision-2"
	elif variant == "mass-only":
		changed.rectangles = original.rectangles
	elif variant == "shape-only":
		for key: String in ["mass", "com_x", "com_y", "inertia"]:
			changed[key] = original[key]
	var result: Dictionary = bridge.install_geometry(changed)
	_expect(result.get("ok", false), "geometry intervention installed")
	_write({"intervention": variant, "tick": tick, "id": original.id, "before": row.before,
		"after_install": _sample(int(original.id)), "result": result, "publication": changed})
	row.shard = changed


func _tree_cells() -> Dictionary:
	var cells: Dictionary = {}
	for y: int in range(8, 35):
		for x: int in range(11, 15):
			cells[Vector2i(x, y)] = true
	for y: int in range(1, 19):
		for x: int in range(1, 29):
			if not (y < 5 and (x < 6 or x > 23)):
				cells[Vector2i(x, y)] = true
	for y: int in range(1, 15):
		cells.erase(Vector2i(21, y))
	# The separately authored short-burning left cell had already been consumed.
	cells.erase(Vector2i(1, 10))
	return cells


func _publication(cells: Dictionary, id: int, revision: int) -> Dictionary:
	var rectangles: Array[Rect2i] = []
	# Independent row-run oracle: exact occupied union, then vertical coalescing.
	for y: int in range(0, 51):
		var x: int = 0
		while x < 31:
			if not cells.has(Vector2i(x, y)):
				x += 1
				continue
			var start: int = x
			while x < 31 and cells.has(Vector2i(x, y)):
				x += 1
			var merged: bool = false
			for index: int in range(rectangles.size()):
				var rect: Rect2i = rectangles[index]
				if rect.position.x == start and rect.size.x == x - start and rect.end.y == y:
					rect.size.y += 1
					rectangles[index] = rect
					merged = true
					break
			if not merged:
				rectangles.append(Rect2i(start, y, x - start, 1))
	var packed := PackedInt32Array()
	for rect: Rect2i in rectangles:
		packed.append_array(PackedInt32Array([rect.position.x, rect.position.y, rect.size.x, rect.size.y]))
	var sum := Vector2.ZERO
	for cell: Vector2i in cells:
		sum += Vector2(cell) + Vector2.ONE * 0.5
	var center: Vector2 = sum / float(cells.size())
	var inertia: float = 0.0
	for cell: Vector2i in cells:
		inertia += (Vector2(cell) + Vector2.ONE * 0.5).distance_squared_to(center) + 1.0 / 6.0
	return {"session": 7001, "id": id, "generation": 1, "body_generation": 1,
		"transaction": id, "geometry_revision": revision, "geometry_digest": str(id * 100 + revision),
		"rectangles": packed, "origin_x": 0, "origin_y": 0, "mass": float(cells.size()),
		"com_x": center.x, "com_y": center.y, "inertia": inertia}


func _sample(id: int) -> Dictionary:
	var body: Dictionary = bridge.bodies[id]
	var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var center: Vector2 = PhysicsServer2D.body_get_param(body.rid, PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
	var state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(body.rid)
	var contacts: Array = []
	if state != null:
		for index: int in range(state.get_contact_count()):
			var normal: Vector2 = state.get_contact_local_normal(index)
			var at: Vector2 = state.get_contact_local_position(index)
			contacts.append({"normal": [normal.x, normal.y], "position": [at.x, at.y],
				"local_shape": state.get_contact_local_shape(index), "other_shape": state.get_contact_collider_shape(index)})
	return {"id": id, "x": pose.origin.x, "y": pose.origin.y, "rotation": pose.get_rotation(),
		"continuous_rotation": body.rotation, "vx": velocity.x, "vy": velocity.y,
		"angular_velocity": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY),
		"sleeping": PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING),
		"geometry_revision": body.geometry_revision, "geometry_digest": body.geometry_digest,
		"shapes": PhysicsServer2D.body_get_shape_count(body.rid),
		"mass": PhysicsServer2D.body_get_param(body.rid, PhysicsServer2D.BODY_PARAM_MASS),
		"inertia": PhysicsServer2D.body_get_param(body.rid, PhysicsServer2D.BODY_PARAM_INERTIA),
		"com": [center.x, center.y], "inverse_mass": state.inverse_mass if state != null else -1.0,
		"inverse_inertia": state.inverse_inertia if state != null else -1.0, "contacts": contacts}


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
		_write({"failure": message})


func _write(value: Dictionary) -> void:
	trace.store_line(JSON.stringify(value))


func _finish(held: Dictionary) -> void:
	var result_rows: Array[Dictionary] = []
	for row: Dictionary in rows:
		var result: Dictionary = row.duplicate()
		result.erase("cells")
		result_rows.append(result)
	var result: Dictionary = {"schema": "objectshard-rest-stability-probe-v1", "engine": Engine.get_version_info(),
		"platform": OS.get_name(), "variant": variant, "body_count": count, "initial_tilt": initial_tilt, "checks": checks,
		"failures": failures, "registration": REGISTRATION, "held": held, "bodies": result_rows}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "  ") + "\n")
	output.close()
	trace.close()
	bridge.shutdown()
	print(JSON.stringify({"schema": "objectshard-rest-stability-probe-v1", "probe": output_path,
		"variant": variant, "bodies": count, "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
