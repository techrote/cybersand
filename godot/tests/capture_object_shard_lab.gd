extends SceneTree

# The ordinary Lab scene renders source-owned material and actual Rapier poses.
# This is a visible-renderer capture; headless/dummy images are refused.
var destination: String = ""
var stage: String = "m0"
var failures: int = 0
var observations: Array[Dictionary] = []


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--objectshard-capture="):
			destination = argument.trim_prefix("--objectshard-capture=")
		elif argument.begins_with("--objectshard-stage="):
			stage = argument.trim_prefix("--objectshard-stage=")
	call_deferred("_run")


func _run() -> void:
	if destination.is_empty() or DisplayServer.get_name() == "headless":
		push_error("ObjectShard captures require --objectshard-capture and an actual display renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	var scene: PackedScene = load("res://object_shard_lab.tscn")
	var lab = scene.instantiate()
	root.add_child(lab)
	current_scene = lab
	await process_frame
	if lab.session.failed:
		push_error(lab.session.status)
		quit(1)
		return
	await _capture(lab, "objectshard-a-native-supported")
	lab._erase_lower_band()
	while not lab.session.pending_edits.is_empty():
		lab.session.drain_edits()
	for tick: int in range(8):
		lab.session.advance(true)
	lab._present()
	await _capture(lab, "objectshard-a-transferred-falling")
	for tick: int in range(72):
		lab.session.advance(true)
	lab._present()
	await _capture(lab, "objectshard-a-impact")
	lab.canvas.overlays = true
	lab._present()
	await _capture(lab, "objectshard-a-exact-shapes")
	if stage != "m0":
		lab._open(2)
		lab.canvas.overlays = false
		for tick: int in range(4):
			lab.session.advance(true)
		lab._erase_lower_band()
		while not lab.session.pending_edits.is_empty():
			lab.session.drain_edits()
		for tick: int in range(8):
			lab.session.advance(true)
		var brush_ignitions: int = _ignite_exposed_wood(lab.session, 24)
		for tick: int in range(72):
			lab.session.advance(true)
		lab._present()
		await _capture(lab, "objectshard-b-real-combustion", {"ordinary_ignite_brush_cells": brush_ignitions})
		for tick: int in range(460):
			lab.session.advance(true)
		lab.canvas.overlays = true
		lab._present()
		await _capture(lab, "objectshard-b-consumed-geometry", {"ordinary_ignite_brush_cells": brush_ignitions})
	if stage == "m2":
		lab._open(3)
		lab._erase_lower_band()
		while not lab.session.pending_edits.is_empty():
			lab.session.drain_edits()
		var cargo: int = 0
		for tick: int in range(150):
			lab.session.advance(true)
			cargo = 0
			for shard: Dictionary in lab.session.frame.shards:
				cargo += int(shard.cargo)
			if cargo > 0 or lab.session.failed:
				break
		if cargo == 0:
			failures += 1
			push_error("Rendered C scenario did not capture real Sand")
		lab.canvas.overlays = true
		lab._present()
		for shard: Dictionary in lab.session.frame.shards:
			for cell: int in range(shard.roles.size()):
				if int(shard.roles[cell]) == 3:
					var pose: Transform2D = lab.session._pose(shard)
					var center: Vector2 = pose * Vector2(float(cell % int(shard.width)) + 0.5, float(cell / int(shard.width)) + 0.5)
					lab._cell_pressed(Vector2i(floori(center.x), floori(center.y)), MOUSE_BUTTON_RIGHT)
		await _capture(lab, "objectshard-c-carried-sand", {"actual_cargo_cells": cargo})
		var water: Dictionary = _author_water_contact(lab.session)
		var extinguished: bool = false
		for tick: int in range(6):
			lab.session.advance(true)
			for shard: Dictionary in lab.session.frame.shards:
				if int(shard.id) == int(water.get("id", -1)):
					var cell: int = int(water.cell)
					extinguished = int(shard.materials[cell]) == 7 and int(shard.states_b[cell]) == 0 \
						and int(shard.incarnations[cell]) == int(water.incarnation)
			if extinguished or lab.session.failed:
				break
		if not water.get("ok", false) or not extinguished:
			failures += 1
			push_error("Rendered C scenario did not extinguish the same Wood incarnation")
		else:
			for shard: Dictionary in lab.session.frame.shards:
				if int(shard.id) == int(water.id):
					var center: Vector2 = lab.session._pose(shard) * Vector2(float(int(water.cell) % int(shard.width)) + 0.5,
						float(int(water.cell) / int(shard.width)) + 0.5)
					lab._cell_pressed(Vector2i(floori(center.x), floori(center.y)), MOUSE_BUTTON_RIGHT)
		lab._present()
		await _capture(lab, "objectshard-c-water-extinction", {"water_contact": water, "same_wood_extinguished": extinguished})
		lab._open(4)
		lab._erase_lower_band()
		while not lab.session.pending_edits.is_empty():
			lab.session.drain_edits()
		for tick: int in range(100):
			lab.session.advance(true)
		lab.canvas.overlays = false
		lab._present()
		await _capture(lab, "objectshard-d-three-owners")
		await _capture_retired_domain(lab)
	var report: Dictionary = {"schema": "objectshard-render-campaign-v1", "stage": stage,
		"engine": Engine.get_version_info(), "platform": OS.get_name(), "display": DisplayServer.get_name(),
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"renderer": RenderingServer.get_video_adapter_name(), "failures": failures, "observations": observations,
		"physical_owner_acceptance": "not established by automated rendered captures"}
	var output: FileAccess = FileAccess.open(destination.path_join("render-campaign.json"), FileAccess.WRITE)
	if output == null:
		failures += 1
	else:
		output.store_string(JSON.stringify(report, "  ") + "\n")
		output.close()
	print(JSON.stringify({"schema": report.schema, "captures": observations.size(), "failures": failures,
		"display": report.display, "renderer": report.renderer, "destination": destination}))
	lab.session.close()
	quit(failures)


func _capture(lab: Node, name: String, evidence: Dictionary = {}) -> void:
	if lab.session.scenario > 0 and lab.scenario_select.selected + 1 != lab.session.scenario:
		failures += 1
		push_error("Displayed scenario does not match the actual native session")
	if lab.overlay_toggle.button_pressed != lab.canvas.overlays:
		failures += 1
		push_error("Overlay control does not describe the rendered geometry")
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var path: String = destination.path_join(name + ".png")
	if picture == null or picture.is_empty() or picture.save_png(path) != OK:
		failures += 1
		push_error("Failed actual ObjectShard render: " + name)
	if lab.session.failed:
		failures += 1
		push_error("ObjectShard held during capture: " + lab.session.status)
	var observation: Dictionary = lab.session.export_result()
	observation["image"] = name + ".png"
	observation["presentation_usec"] = lab.last_presentation_usec
	observation["render_upload_usec"] = lab.canvas.upload_usec
	observation["evidence"] = evidence
	observations.append(observation)


func _author_water_contact(session: CyberObjectShardLabSession) -> Dictionary:
	# Ordinary World editing authors Water; the actual native pose/contact path
	# must independently accept the exposure. No contact event is injected.
	for shard: Dictionary in session.frame.shards:
		if not session.bridge.bodies.has(int(shard.id)):
			continue
		var pose: Transform2D = PhysicsServer2D.body_get_state(session.bridge.bodies[int(shard.id)].rid,
			PhysicsServer2D.BODY_STATE_TRANSFORM)
		for cell: int in range(shard.materials.size()):
			if int(shard.materials[cell]) != 7 or int(shard.states_b[cell]) == 0:
				continue
			var center := Vector2(float(cell % int(shard.width)) + 0.5, float(cell / int(shard.width)) + 0.5)
			for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var local := Vector2i(floori(center.x + offset.x), floori(center.y + offset.y))
				if local.x >= 0 and local.y >= 0 and local.x < int(shard.width) and local.y < int(shard.height) \
					and int(shard.materials[local.y * int(shard.width) + local.x]) != 0:
					continue
				var point: Vector2 = pose * (center + offset)
				var position := Vector2i(floori(point.x), floori(point.y))
				if int(session.native.inspect(position).get("material", -1)) == 0 \
					and session.edit(position, 3, 255).get("ok", false):
					return {"ok": true, "id": shard.id, "cell": cell, "incarnation": shard.incarnations[cell],
						"world_position": position, "burn_before": shard.states_b[cell]}
	return {"ok": false}


func _ignite_exposed_wood(session: CyberObjectShardLabSession, limit: int) -> int:
	var count: int = 0
	for shard: Dictionary in session.frame.shards:
		var width: int = int(shard.width)
		var pose: Transform2D = session._pose(shard)
		for cell: int in range(shard.materials.size()):
			if int(shard.materials[cell]) != 7 or int(shard.states_b[cell]) > 0:
				continue
			var exposed: bool = false
			for neighbor: int in [cell - 1, cell + 1, cell - width, cell + width]:
				if neighbor >= 0 and neighbor < shard.materials.size() and int(shard.materials[neighbor]) == 0:
					exposed = true
			if not exposed:
				continue
			var point: Vector2 = pose * Vector2(float(cell % width) + 0.5, float(cell / width) + 0.5)
			if session.ignite(Vector2i(floori(point.x), floori(point.y))).get("ok", false):
				count += 1
			if count >= limit:
				return count
	return count


func _capture_retired_domain(lab: Node) -> void:
	lab.session.close()
	lab.session.native = ClassDB.instantiate(&"CyberObjectShardLab")
	var configured: Dictionary = lab.session.native.configure({"scenario": 0, "seed": 12, "transfer_budget": 0})
	if not configured.get("ok", false) or not lab.session.open(0, 12).get("ok", false):
		failures += 1
		push_error("Retained-domain render fixture could not configure real zero transfer capacity")
		return
	lab.help_label.text = "Lifecycle diagnostic · real Wood burns away after actual motion. Zero transfer capacity retains products at the final physical anchor after the body retires."
	lab.scenario_select.add_item("Lifecycle · retained material")
	lab.scenario_select.select(lab.scenario_select.item_count - 1)
	lab.session.edit(Vector2i(80, 50), 7, 0, 24)
	var retained: Dictionary = {}
	var last_pose := Transform2D.IDENTITY
	for tick: int in range(100):
		for shard: Dictionary in lab.session.frame.shards:
			if lab.session.bridge.bodies.has(int(shard.id)):
				last_pose = lab.session._pose(shard)
		lab.session.advance(true)
		if lab.session.failed:
			break
		for shard: Dictionary in lab.session.frame.shards:
			if int(shard.structural) == 0 and int(shard.products) > 0 and not shard.has_body:
				retained = shard
		if not retained.is_empty():
			break
	if retained.is_empty() or Vector2(float(retained.position_x), float(retained.position_y)).distance_to(last_pose.origin) > 0.01:
		failures += 1
		push_error("Draining render did not retain the actual final material anchor")
	else:
		for cell: int in range(retained.roles.size()):
			if int(retained.roles[cell]) == 2:
				var center: Vector2 = last_pose * Vector2(float(cell % int(retained.width)) + 0.5, float(cell / int(retained.width)) + 0.5)
				lab._cell_pressed(Vector2i(floori(center.x), floori(center.y)), MOUSE_BUTTON_RIGHT)
				break
	lab.canvas.overlays = true
	lab._present()
	await _capture(lab, "objectshard-retired-material-anchor", {"last_physical_pose": last_pose,
		"actual_retained_domain": not retained.is_empty(), "transfer_budget_per_tick": 0})
