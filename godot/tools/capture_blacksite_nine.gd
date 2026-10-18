extends SceneTree

# Captures the production desktop/native renderer at three pixels per cell.
# The nine exported tile PNGs are exact crops of the same 2880-square image;
# stitching them reproduces the full composition, including the shared glow.
const Scene = preload("res://scripts/blacksite_nine.gd")
const Layout = preload("res://scripts/blacksite_nine_layout.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Blacksite Nine capture requires a rendering display.")
		quit(1)
		return
	var output: String = "user://blacksite-nine-captures"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Could not create capture directory: " + output)
		quit(1)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2920, 2912)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var controller: Control = load("res://main.tscn").instantiate()
	viewport.add_child(controller)
	await process_frame
	if not controller.blacksite_nine_presentation.launch():
		push_error("Blacksite Nine launch was refused")
		controller.queue_free()
		await process_frame
		quit(1)
		return
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if (controller.pending_microscenario_apply.is_empty()
			and controller.blacksite_nine_presentation.active()
			and controller.last_uploaded_render_snapshot_serial > 0): break
	if not controller.blacksite_nine_presentation.active() or not controller.pending_microscenario_apply.is_empty():
		push_error("The native owner did not acknowledge Blacksite Nine")
		controller.queue_free()
		await process_frame
		quit(1)
		return
	controller.microscenario_toggle_hud()
	controller.blacksite_nine_presentation.frame_view(0)
	for frame: int in range(10): await process_frame
	await RenderingServer.frame_post_draw
	var checked: Dictionary = CyberMicroScenarioContract.validate(controller.microscenario_definition)
	var content: Rect2 = controller.view_content_rect()
	var top_left: Vector2 = controller.world_view.global_position + content.position
	var area := Rect2i(Vector2i(top_left.round()), Vector2i(content.size.round()))
	var picture: Image = viewport.get_texture().get_image().get_region(area)
	var tick: int = int(controller.tower_context.get("tick", -1))
	if not checked.get("ok",false) or tick != 0 or not controller.paused or picture.get_size() != Vector2i(2880,2880):
		push_error("Capture must be paused at tick zero and exactly 2880×2880; got " + str(picture.get_size()))
		controller.queue_free()
		await process_frame
		quit(1)
		return
	var manifest: Dictionary = {"scene":Scene.SCENARIO_ID, "title":Scene.TITLE,
		"recipe_version":Scene.VERSION, "definition_sha256":checked.hash,
		"record_count":controller.microscenario_definition.rectangles.size()/5,
		"godot":Engine.get_version_info().string, "display":DisplayServer.get_name(),
		"renderer":RenderingServer.get_video_adapter_name(), "identity":CyberMicroScenarioIdentity.current(),
		"tick":tick, "paused":true, "world_origin":[32,32], "world_size":[960,960],
		"pixels_per_cell":3, "overview":"blacksite-nine.png",
		"definition_file":"blacksite-nine.scenario.json", "tiles":[]}
	var succeeded: bool = picture.save_png(output.path_join("blacksite-nine.png")) == OK
	var definition_file := FileAccess.open(output.path_join("blacksite-nine.scenario.json"),FileAccess.WRITE)
	if definition_file == null:
		succeeded = false
	else:
		definition_file.store_string(str(checked.canonical_json) + "\n")
		definition_file.flush()
		succeeded = definition_file.get_error() == OK and succeeded
		definition_file.close()
	for index: int in range(9):
		var file_name: String = Layout.CODES[index].to_lower() + "-" + Layout.IDS[index].replace("_","-") + ".png"
		var tile: Image = picture.get_region(Rect2i((index%3)*960,(index/3)*960,960,960))
		succeeded = tile.save_png(output.path_join(file_name)) == OK and succeeded
		manifest.tiles.append({"file":file_name,"code":Layout.CODES[index],"name":Layout.TITLES[index],
			"column":index%3,"row":index/3,"world_origin":[Layout.tile_origin(index).x,Layout.tile_origin(index).y],
			"world_size":[320,320]})
		print("CAPTURED ", output.path_join(file_name))
	var report := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if report == null:
		succeeded = false
	else:
		report.store_string(JSON.stringify(manifest,"  ") + "\n")
		report.flush()
		succeeded = report.get_error() == OK and succeeded
		report.close()
	print("BLACKSITE_CAPTURE ", JSON.stringify({"ok":succeeded,"size":[picture.get_width(),picture.get_height()],
		"hash":checked.hash,"records":manifest.record_count,"directory":output}))
	controller.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit(0 if succeeded else 1)
