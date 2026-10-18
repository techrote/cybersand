extends SceneTree

# Uses the normal desktop scene, native owner and material/glow pipeline.
# Default: Neon Reliquary. --tile=<demo or scenario ID> selects one district.
# --all-tiles captures the complete top-to-bottom set into separate subfolders.
# A real rendering display is required; software OpenGL under Xvfb is sufficient.
const Tiles = preload("res://scripts/showcase_tiles.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Scene capture needs a rendering display; use Xvfb or desktop Godot.")
		quit(1)
		return
	var output: String = "user://neon-reliquary-captures"
	var tile_id: String = "neon_reliquary"
	var all_tiles: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=")
		elif argument.begins_with("--tile="):
			tile_id = argument.trim_prefix("--tile=")
		elif argument == "--all-tiles":
			all_tiles = true
	if not Tiles.contains(tile_id):
		push_error("Unknown showcase tile: " + tile_id)
		quit(1)
		return
	var sources: Array = Tiles.RECIPES if all_tiles else [Tiles.recipe(tile_id)]
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	root.size = Vector2i(1920, 1080)
	var scene: Control = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var succeeded: bool = true
	for source: GDScript in sources:
		var directory: String = output.path_join(source.ID) if all_tiles else output
		if not await _capture_tile(scene, source, directory):
			succeeded = false
			break
	scene.queue_free()
	await process_frame
	quit(0 if succeeded else 1)

func _capture_tile(scene: Control, source: GDScript, output: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Could not create capture directory: " + output)
		return false
	if not scene.showcase_presentation.launch(source.SCENARIO_ID):
		push_error("Showcase launch refused: " + source.TITLE)
		return false
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if (scene.pending_microscenario_apply.is_empty()
			and scene.showcase_presentation.current_scenario_id() == source.SCENARIO_ID
			and scene.last_uploaded_render_snapshot_serial > 0):
			break
	if (scene.showcase_presentation.current_scenario_id() != source.SCENARIO_ID
		or not scene.pending_microscenario_apply.is_empty()):
		push_error("Showcase owner did not acknowledge installation: " + source.TITLE)
		return false
	if not scene.microscenario_hud_hidden:
		scene.microscenario_toggle_hud()
	var checked: Dictionary = CyberMicroScenarioContract.validate(scene.microscenario_definition)
	if not checked.get("ok", false):
		push_error("Capture has no valid accepted scenario definition")
		return false
	var position: Vector2i = Tiles.stack_position(source.ID)
	var manifest: Dictionary = {
		"scene":source.SCENARIO_ID,
		"title":source.TITLE,
		"stack_position":[position.x, position.y],
		"recipe_version":source.VERSION,
		"definition_sha256":checked.hash,
		"godot":Engine.get_version_info().string,
		"display":DisplayServer.get_name(),
		"renderer":RenderingServer.get_video_adapter_name(),
		"identity":CyberMicroScenarioIdentity.current(),
		"views":[],
	}
	var views: Array[Dictionary] = source.viewpoints()
	for index: int in range(views.size()):
		if not scene.showcase_presentation.frame_view(index):
			push_error("Showcase framing refused")
			return false
		# Let the layout, accepted publication and existing glow viewport converge.
		for frame: int in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var tick: int = int(scene.tower_context.get("tick", -1))
		if not scene.paused or tick != 0:
			push_error("Showcase capture must preserve the paused authored composition")
			return false
		var file_name: String = "%s-%02d.png" % [source.ID.replace("_", "-"), index]
		var picture: Image = root.get_texture().get_image()
		if picture.save_png(output.path_join(file_name)) != OK:
			push_error("Could not save " + file_name)
			return false
		manifest.views.append({"file":file_name, "name":views[index].name,
			"origin":[scene.camera_origin.x, scene.camera_origin.y],
			"size":[scene.current_view_size.x, scene.current_view_size.y],
			"tick":tick, "paused":scene.paused})
		print("CAPTURED ", output.path_join(file_name))
	return _write_manifest(output.path_join("capture.json"), manifest)

func _write_manifest(path: String, manifest: Dictionary) -> bool:
	var report := FileAccess.open(path, FileAccess.WRITE)
	if report == null:
		push_error("Could not open capture manifest: %s (%s)" % [
			path, error_string(FileAccess.get_open_error())])
		return false
	report.store_string(JSON.stringify(manifest, "  ") + "\n")
	var write_error: Error = report.get_error()
	report.flush()
	var flush_error: Error = report.get_error()
	report.close()
	if write_error != OK or flush_error != OK:
		push_error("Could not save capture manifest: %s (write: %s; flush: %s)" % [
			path, error_string(write_error), error_string(flush_error)])
		return false
	return true
