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
		for tick: int in range(80):
			lab.session.advance(true)
		lab._present()
		await _capture(lab, "objectshard-b-real-combustion")
		for tick: int in range(460):
			lab.session.advance(true)
		lab.canvas.overlays = true
		lab._present()
		await _capture(lab, "objectshard-b-consumed-geometry")
		lab._open(4)
		lab._erase_lower_band()
		for tick: int in range(100):
			lab.session.advance(true)
		lab.canvas.overlays = false
		lab._present()
		await _capture(lab, "objectshard-d-three-owners")
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


func _capture(lab: Node, name: String) -> void:
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
	observations.append(observation)
