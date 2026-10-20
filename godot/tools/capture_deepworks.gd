extends SceneTree

const Map = preload("res://scripts/exhibition/deepworks_map.gd")
var output_path: String = "user://deepworks-captures"
var quick: bool = false
var captures: Array[Dictionary] = []
var capture_failed: bool = false

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--deepworks-output="):
			output_path = argument.trim_prefix("--deepworks-output=")
		elif argument == "--quick":
			quick = true
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Deepworks capture requires a graphical renderer")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path)) != OK:
		push_error("Cannot create capture directory")
		quit(2)
		return
	root.size = Vector2i(1280, 960)
	root.content_scale_size = Vector2i(1280, 960)
	var scene: PackedScene = load("res://deepworks.tscn")
	var lab: Control = scene.instantiate()
	root.add_child(lab)
	lab.set_process(false)
	if lab.faulted:
		quit(1)
		return
	lab.show_overview()
	await _settle()
	if not _save(root.get_texture().get_image(), "deepworks-guide.png"):
		quit(1)
		return
	lab.set_hud_visible(false)
	root.size = Vector2i(2048, 2048)
	root.content_scale_size = Vector2i(2048, 2048)
	await _settle()
	lab.show_overview()
	await _settle()
	var atlas: Image = root.get_texture().get_image()
	if atlas == null or atlas.get_size() != Vector2i(2048, 2048) or not _save(atlas, "deepworks-atlas.png"):
		push_error("Full atlas did not render at requested dimensions")
		quit(1)
		return
	var identity: Dictionary = {"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"recipe_sha256": Map.recipe_hash(lab.definition), "map_size": [1024, 1024],
		"engine": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"method": RenderingServer.get_current_rendering_method(),
		"quick": quick, "initial_state": "paused, tick zero, hybrid depth, frozen material animation"}
	for index: int in range(16):
		var tile: Image = atlas.get_region(Rect2i(Map.origin(index) * 2, Vector2i(512, 512)))
		if not _save(tile, "%s-%s.png" % [Map.district_code(index).to_lower(), Map.SHORT_TITLES[index].to_lower().replace(" ", "-")]):
			quit(1)
			return
	if not quick:
		root.size = Vector2i(1024, 1024)
		root.content_scale_size = Vector2i(1024, 1024)
		for index: int in [1, 5, 7, 8, 10, 14, 15]:
			lab.select_district(index)
			await _settle()
			_save(root.get_texture().get_image(), "detail-%s.png" % Map.district_code(index).to_lower())
		# A matched set of isolated planes reveals complete authored coverage.
		lab.show_overview()
		lab.select_mode(2)
		for layer_index: int in range(4):
			for index: int in range(4): lab.set_layer_visible(index, index == layer_index)
			await _settle()
			_save(root.get_texture().get_image(), "layer-%s.png" % Map.LAYERS[layer_index])
		for index: int in range(4): lab.set_layer_visible(index, true)
		lab.select_mode(3)
		for _tick: int in range(240):
			if not bool(lab.runtime.step_once().get("ok", false)):
				push_error("Native exhibit tick failed during capture")
				quit(1)
				return
		if not lab._publish_layers():
			quit(1)
			return
		root.size = Vector2i(2048, 2048)
		root.content_scale_size = Vector2i(2048, 2048)
		lab.show_overview()
		await _settle()
		_save(root.get_texture().get_image(), "deepworks-after-240-ticks.png")
		root.size = Vector2i(1024, 1024)
		root.content_scale_size = Vector2i(1024, 1024)
		for index: int in [2, 5, 8, 9]:
			lab.select_district(index)
			await _settle()
			_save(root.get_texture().get_image(), "reaction-%s.png" % Map.district_code(index).to_lower())
	identity["runtime"] = lab.runtime.stats()
	identity["events"] = lab.runtime.event_stats()
	identity["compositor"] = lab.compositor.get_diagnostics()
	identity["captures"] = captures
	identity["capture_failures"] = capture_failed
	if capture_failed:
		quit(1)
		return
	var file := FileAccess.open(output_path.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(identity, "\t") + "\n")
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		push_error("Could not write capture manifest")
		quit(1)
		return
	print("DEEPWORKS_CAPTURE: actual rendered map, sixteen exact crops and controls saved to ", output_path)
	lab.queue_free()
	await process_frame
	quit(0)

func _save(image: Image, filename: String) -> bool:
	if image == null or image.is_empty() or image.save_png(output_path.path_join(filename)) != OK:
		push_error("Could not save rendered " + filename)
		capture_failed = true
		return false
	captures.append({"file": filename, "width": image.get_width(), "height": image.get_height(),
		"sha256": FileAccess.get_sha256(output_path.path_join(filename))})
	return true

func _settle() -> void:
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
