extends SceneTree
## Actual display-backed end-to-end operation of the independent interactive scene.
## Uses the UI controls, the production material shaders and real viewport readback.
const SCENE = preload("res://tools/world_art_preview.tscn")
var failures: int = 0
var output := ""
var results: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, label: String) -> void:
	results.append({"check": label, "ok": condition})
	if not condition:
		failures += 1
		push_error("WORLD ART SMOKE FAIL: " + label)

func _frame() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

func _save_frame(preview: Variant, name: String) -> void:
	await _frame()
	var image: Image = preview.rig.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "viewport framebuffer " + name)
	if image != null and not image.is_empty():
		image.convert(Image.FORMAT_RGB8)
		_expect(image.save_png(output.path_join(name + ".png")) == OK, "write actual pixels " + name)
		var center := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
		var corner := image.get_pixel(1, 1)
		_expect(Vector3(center.r, center.g, center.b).distance_to(Vector3(corner.r, corner.g, corner.b)) > 0.005, "nonblank pixel variation " + name)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Actual graphical display required")
		quit(77)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--smoke-output="):
			output = arg.trim_prefix("--smoke-output=")
	if output.is_empty() or not output.is_absolute_path():
		push_error("--smoke-output=/absolute/path required")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	var preview = SCENE.instantiate()
	root.add_child(preview)
	for i: int in range(5):
		await process_frame
	_expect(preview._collections.size() == 15, "discover 15 source collections")
	_expect(preview.rig.renderer_identity().palette.source_bound, "selected production palette source bound")
	_expect(preview.rig.renderer_identity().palette.source_file_bound, "production palette source on disk")
	var inspected_features := 0
	for i: int in range(preview._collections.size()):
		# Exercise actual collection ItemList selection and signal dispatch.
		preview.collection_list.select(i)
		preview.collection_list.item_selected.emit(i)
		_expect(preview._loaded and preview.last_error.is_empty(), "pack loads " + str(i + 1))
		_expect(preview._native_size.x > 0 and preview._native_size.y > 0, "native dimensions " + str(i + 1))
		_expect(preview._feature_ids.size() == 8, "eight reusable features " + str(i + 1))
		var entries: int = preview._feature_ids.size()
		for j: int in range(entries):
			preview.feature_picker.select(j + 1)
			preview.feature_picker.item_selected.emit(j + 1)
			_expect(preview._result.geometry.family == "feature", "feature selection %d.%d" % [i + 1, j + 1])
			inspected_features += 1
			if preview.variant_picker.item_count > 1:
				preview.variant_picker.select(1)
				preview.variant_picker.item_selected.emit(1)
				_expect(preview._result.geometry.variant != "", "variant selected %d.%d" % [i + 1, j + 1])
		preview.feature_picker.select(0)
		preview.feature_picker.item_selected.emit(0)
		if i in [0, 4, 7, 8, 13, 14]:
			await _save_frame(preview, preview._collections[i].get_base_dir().get_file())
		if i == 13:
			_expect(preview._native_size.x > 1024, "Coral Telegraph wide original")
			await preview.export_art("combined")
			var wide_dir: String = preview.last_export_dir
			var wide_png: Image = Image.load_from_file(wide_dir.path_join("combined.png"))
			_expect(wide_png != null and wide_png.get_width() == preview._native_size.x * 2,
				"full wide framebuffer export contains rightmost cells")
			_expect(FileAccess.file_exists(wide_dir.path_join("metadata.json")), "full export metadata")
	_expect(inspected_features == 120, "120 authored reusable feature identities navigated")
	preview.choose_collection(0)
	preview.fit_view()
	var old_zoom: float = preview._zoom
	var centre: Vector2 = Vector2(preview.rig.size) * 0.5
	var zoom_event := InputEventMouseButton.new()
	zoom_event.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_event.pressed = true
	zoom_event.position = centre
	preview.viewport_container.gui_input.emit(zoom_event)
	_expect(preview._zoom > old_zoom, "cursor-centred scroll zoom")
	var old_origin: Vector2 = preview._origin
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_MIDDLE
	mouse_down.pressed = true
	mouse_down.position = centre
	preview.viewport_container.gui_input.emit(mouse_down)
	var pan_event := InputEventMouseMotion.new()
	pan_event.position = centre + Vector2(20, 10)
	pan_event.relative = Vector2(20, 10)
	preview.viewport_container.gui_input.emit(pan_event)
	_expect(preview._origin != old_origin, "middle-drag camera pan")
	preview.actual_pixels()
	_expect(is_equal_approx(preview._zoom, 1.0), "actual pixel zoom")
	preview._inspect(Vector2(preview.rig.size) * 0.5)
	_expect(preview.pointer_label.text.contains("Material ID"), "native pointer inspection")
	preview.fit_view()
	preview.pin_current()
	await _frame()
	_expect(preview._baseline != null and not preview._baseline.is_empty(), "pin true framebuffer")
	var first_hash: String = preview.pack_hash
	var disposable_dir: String = output.path_join("disposable-art")
	DirAccess.make_dir_recursive_absolute(disposable_dir)
	var disposable_pack: String = disposable_dir.path_join("pack.json")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(preview.pack_path))
	# Change a real authored rectangle to a distinct native material ID.
	var scene: Dictionary = doc["scene"] if doc.has("scene") else doc["combined_scene"]
	var terrain: Array = scene.get("rectangles", scene.get("terrain_rectangles", []))
	_expect(not terrain.is_empty(), "disposable reload fixture has terrain")
	if not terrain.is_empty():
		var changed: Array = terrain[0]
		changed[4] = 78 if changed[4] != 78 else 62
		terrain[0] = changed
		if scene.has("rectangles"):
			scene["rectangles"] = terrain
		else:
			scene["terrain_rectangles"] = terrain
	var file := FileAccess.open(disposable_pack, FileAccess.WRITE)
	file.store_string(JSON.stringify(doc))
	file.close()
	_expect(preview.open_pack(disposable_pack, true), "reload modified disposable copy")
	_expect(preview.pack_hash != first_hash, "loaded content identity changes")
	preview.toggle_comparison()
	_expect(preview.baseline_overlay.visible, "show pinned original framebuffer")
	preview.toggle_comparison()
	_expect(not preview.baseline_overlay.visible, "return to current framebuffer")
	var good_hash: String = preview.pack_hash
	file = FileAccess.open(disposable_pack, FileAccess.WRITE)
	file.store_string("{ malformed json")
	file.close()
	_expect(not preview.reload_pack(), "malformed reload rejected")
	_expect(preview.pack_hash == good_hash and preview._loaded, "last successful image remains after invalid reload")
	preview.choose_collection(4) # Emberglass: luminous source materials.
	preview.fit_view()
	preview._glow = true
	preview._presentation_time = 1.37
	preview._update_presentation()
	await _frame()
	var glow_image: Image = preview.rig.get_texture().get_image()
	preview._glow = false
	preview._update_presentation()
	await _frame()
	var no_glow_image: Image = preview.rig.get_texture().get_image()
	_expect(glow_image.get_data() != no_glow_image.get_data(), "glow toggle changes actual rendered pixels")
	preview._glow = true
	preview._presentation_time = 21.33
	preview._update_presentation()
	await _frame()
	var timed_image: Image = preview.rig.get_texture().get_image()
	_expect(timed_image.get_data() != glow_image.get_data(), "presentation time changes actual rendered pixels")
	await preview.export_art("viewport")
	var first_dir: String = preview.last_export_dir
	_expect(FileAccess.file_exists(first_dir.path_join("viewport.png")), "viewport export PNG")
	_expect(FileAccess.file_exists(first_dir.path_join("metadata.json")), "export source identity")
	await preview.export_art("viewport")
	_expect(first_dir != preview.last_export_dir, "new unique directory for second export")
	_expect(FileAccess.file_exists(first_dir.path_join("viewport.png")), "first export retained")
	var summary := {"status": "pass" if failures == 0 else "fail", "failures": failures,
		"collections": preview._collections.size(), "features": inspected_features,
		"display": DisplayServer.get_name(), "backend": RenderingServer.get_current_rendering_driver_name(),
		"source_revision": preview.design_revision, "results": results}
	var report := FileAccess.open(output.path_join("smoke-report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(summary, "  ") + "\n")
	report.close()
	print("WORLD_ART_SMOKE " + JSON.stringify(summary))
	quit(0 if failures == 0 else 1)
