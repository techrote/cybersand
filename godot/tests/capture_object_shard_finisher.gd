extends SceneTree

# Additional 001R source-material renders. The historical ten-image M2 campaign
# remains a separate required inventory in the same exact-source qualification.
const Capture = preload("res://scripts/object_shard_capture.gd")
var destination: String = ""
var failures: int = 0
var observations: Array[Dictionary] = []
var lab: Node


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--objectshard-capture="):
			destination = argument.trim_prefix("--objectshard-capture=")
	call_deferred("_run")


func _run() -> void:
	if destination.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Finisher PNG evidence requires an actual display renderer and output directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	lab = load("res://object_shard_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await process_frame

	await _open(7)
	_cut_row(int(lab.session.frame.height) - 18 - 20)
	_step(120)
	lab.canvas.overlays = true
	await _capture("objectshard-001r-main-priority")

	await _open(8)
	lab.canvas.overlays = false
	await _capture("objectshard-001r-irregular-256")

	await _open(10)
	_step(80)
	if lab.session.authored_fixture_fire <= 0:
		failures += 1
		push_error("External burner must create real native Fire")
	await _capture("objectshard-001r-external-fire")

	await _open(6)
	lab._erase_lower_band()
	while not lab.session.pending_edits.is_empty():
		lab.session.drain_edits()
	_step(1800)
	lab._erode_resting_cell()
	lab.session.drain_edits()
	_step(180)
	lab.canvas.overlays = true
	await _capture("objectshard-001r-resting-erosion")

	await _open(11)
	lab._erase_lower_band()
	while not lab.session.pending_edits.is_empty():
		lab.session.drain_edits()
	_step(180)
	lab.canvas.overlays = false
	await _capture("objectshard-001r-extended-320")

	var report: Dictionary = {"schema": "objectshard-finisher-render-campaign-v1", "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"captures": observations.size(), "failures": failures, "observations": observations,
		"physical_owner_acceptance": "Actual rendered native/Rapier evidence; not Windows/NVIDIA owner acceptance"}
	var stream: FileAccess = FileAccess.open(destination.path_join("render-campaign.json"), FileAccess.WRITE)
	if stream != null:
		stream.store_string(JSON.stringify(Capture.json_value(report), "\t") + "\n")
		stream.close()
	else:
		failures += 1
	print(JSON.stringify({"schema": report.schema, "captures": observations.size(), "failures": failures}))
	lab.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _open(number: int) -> void:
	lab._open(number)
	while lab.loading_scene:
		await process_frame
	lab.set_physics_process(false)
	await process_frame


func _cut_row(y: int) -> void:
	var width: int = int(lab.session.frame.width)
	var materials: PackedByteArray = lab.session.frame.world_materials
	for x: int in range(width):
		if int(materials[y * width + x]) == 7:
			lab.session.edit(Vector2i(x, y), 0)


func _step(count: int) -> void:
	for tick: int in range(count):
		lab.session.advance(true)
		if lab.session.failed:
			break


func _capture(name: String) -> void:
	lab._present()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var image_name: String = name + ".png"
	if picture.is_empty() or picture.save_png(destination.path_join(image_name)) != OK or lab.session.failed:
		failures += 1
		push_error("Actual finisher capture failed: " + name + " " + lab.session.status)
	observations.append({"image": image_name, "preset": lab.preset_number, "report": lab.session.export_result()})
