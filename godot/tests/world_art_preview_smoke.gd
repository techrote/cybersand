extends SceneTree
## Actual display-backed end-to-end operation of the independent interactive scene.
## Uses the UI controls, the production material shaders and real viewport readback.
const SCENE = preload("res://tools/world_art_preview.tscn")
const RenderRig = preload("res://tools/world_art_render_rig.gd")
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
		var reference: Color = image.get_pixel(0, 0)
		var variation := false
		for gy: int in range(1, 16):
			for gx: int in range(1, 32):
				var pixel: Color = image.get_pixel((gx * (image.get_width() - 1)) / 32,
					(gy * (image.get_height() - 1)) / 16)
				if Vector3(pixel.r, pixel.g, pixel.b).distance_to(
						Vector3(reference.r, reference.g, reference.b)) > 0.025:
					variation = true
					break
			if variation:
				break
		_expect(variation, "nonblank pixel variation " + name)

func _check_export_guards(preview: Variant) -> void:
	var prior_export: String = preview.export_root
	var prior_pack: String = preview.pack_path
	var prior_root: String = preview.art_root
	var protected: String = output.path_join("protected-source")
	DirAccess.make_dir_recursive_absolute(protected)
	preview.art_root = protected
	preview.pack_path = protected.path_join("collection/pack.json")
	for unsafe: String in [protected.path_join("new-output"),
			protected.path_join("sibling-collection/new-output"),
			protected.replace("/", "\\") + "\\new-output"]:
		preview.export_root = unsafe
		_expect(preview._new_export_directory("viewport").is_empty(),
			"source export refused through normalized path " + unsafe)
	if OS.get_name() == "Windows":
		preview.export_root = protected.to_upper().path_join("new-output")
		_expect(preview._new_export_directory("viewport").is_empty(),
			"Windows source export refused through case alias")
	var link: String = output.path_join("protected-source-link")
	var linked := false
	if OS.get_name() == "Windows":
		var command_output: Array = []
		linked = OS.execute("cmd.exe", ["/d", "/c", "mklink", "/J",
			link.replace("/", "\\"), protected.replace("/", "\\")], command_output) == 0
	else:
		linked = DirAccess.open(output).create_link(protected, link) == OK
	_expect(linked, "source alias fixture created")
	if linked:
		preview.export_root = link.path_join("new-output")
		_expect(preview._new_export_directory("viewport").is_empty(),
			"symlink or junction export refused before source write")
		DirAccess.remove_absolute(link)
	_expect(DirAccess.open(protected).get_directories().is_empty(),
		"refused exports created no source directories")
	preview.export_root = prior_export
	preview.pack_path = prior_pack
	preview.art_root = prior_root

func _check_emission_letterbox() -> void:
	var source := Image.create_empty(16, 128, false, Image.FORMAT_RG8)
	source.fill(Color(36.0 / 255.0, 200.0 / 255.0, 0, 1))
	var test_rig = RenderRig.new()
	root.add_child(test_rig)
	test_rig.setup(source, Vector2i(512, 512))
	test_rig.set_view(Vector2(-120, -64), Vector2(256, 256))
	test_rig.set_presentation(1.37, true, true)
	await _frame()
	var glow: Image = test_rig.get_texture().get_image()
	test_rig.set_presentation(1.37, false, true)
	await _frame()
	var unlit: Image = test_rig.get_texture().get_image()
	for point: Vector2i in [Vector2i(0, 256), Vector2i(511, 256), Vector2i(256, 0), Vector2i(256, 511)]:
		_expect(glow.get_pixelv(point).is_equal_approx(unlit.get_pixelv(point)),
			"bright world edge does not fill distant letterbox " + str(point))
	for point: Vector2i in [Vector2i(239, 256), Vector2i(272, 256), Vector2i(256, 127), Vector2i(256, 384)]:
		_expect(glow.get_pixelv(point).get_luminance() > unlit.get_pixelv(point).get_luminance(),
			"production glow still extends just beyond world edge " + str(point))
	_expect(glow.get_pixel(256, 256).get_luminance() > unlit.get_pixel(256, 256).get_luminance(),
		"emission remains aligned with source cells")
	glow.convert(Image.FORMAT_RGB8)
	glow.save_png(output.path_join("emission-letterbox.png"))
	test_rig.set_presentation(1.37, true, true)
	test_rig.set_view(Vector2(1000, 1000), Vector2(256, 256))
	await _frame()
	var outside: Image = test_rig.get_texture().get_image()
	_expect(outside.get_pixel(256, 256).is_equal_approx(unlit.get_pixel(0, 256)),
		"off-world camera has no repeated emission")
	test_rig.queue_free()

func _check_small_asymmetric_view(preview: Variant) -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(preview._collections[0]))
	pack.scene.size = [512, 8192]
	pack.scene.rectangles = [[0, 0, 512, 8, 40], [0, 8184, 512, 8, 40],
		[0, 0, 8, 8192, 40], [504, 0, 8, 8192, 40]]
	pack.scene.placements = []
	var fixture_dir: String = output.path_join("small-window-tall-source")
	DirAccess.make_dir_recursive_absolute(fixture_dir)
	var path: String = fixture_dir.path_join("pack.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(pack))
	file.close()
	_expect(preview.open_pack(path), "small-window extreme tall source loads")
	preview.rig.set_resolution(Vector2i(200, 200))
	preview.fit_view()
	var extent: Vector2 = Vector2(preview.rig.size) / preview._zoom
	_expect(preview._origin.x <= 0 and preview._origin.y <= 0
		and preview._origin.x + extent.x >= 512 and preview._origin.y + extent.y >= 8192,
		"fit-all retains both ends of extreme tall world in small viewport")
	await _save_frame(preview, "small-window-tall-fit")
	preview._on_canvas_resized()
	preview.choose_collection(0)

func _run_direct_pack_probe(report_path: String) -> void:
	var preview = SCENE.instantiate()
	root.add_child(preview)
	for i: int in range(5):
		await process_frame
	_expect(preview._loaded, "direct --pack source loads independently")
	var source_hash: String = FileAccess.get_sha256(preview.pack_path)
	await preview.export_art("viewport")
	_expect(not preview.last_export_dir.is_empty()
		and FileAccess.file_exists(preview.last_export_dir.path_join("viewport.png")),
		"direct --pack exports outside source folder within guessed discovery ancestor")
	_expect(FileAccess.get_sha256(preview.pack_path) == source_hash,
		"direct --pack export preserves source bytes")
	preview.export_root = preview.pack_path.get_base_dir().path_join("forbidden")
	_expect(preview._new_export_directory("viewport").is_empty(),
		"direct --pack still protects actual source directory")
	preview.export_root = preview.art_root.path_join("explicit-root-forbidden")
	preview._choose_art_root(preview.art_root)
	_expect(preview._new_export_directory("viewport").is_empty(),
		"explicitly selecting discovery ancestor protects its entire tree")
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	report.store_string(JSON.stringify({"status": "pass" if failures == 0 else "fail",
		"failures": failures, "results": results}, "  ") + "\n")
	report.close()
	quit(0 if failures == 0 else 1)

func _check_direct_pack_cli(preview: Variant) -> void:
	var input_dir: String = output.path_join("direct-pack-source")
	DirAccess.make_dir_recursive_absolute(input_dir)
	var path: String = input_dir.path_join("pack.json")
	DirAccess.copy_absolute(preview._collections[0], path)
	var report_path: String = output.path_join("direct-pack-report.json")
	var child_output: Array = []
	var status: int = OS.execute(OS.get_executable_path(), [
		"--path", ProjectSettings.globalize_path("res://"), "--audio-driver", "Dummy",
		"--rendering-driver", RenderingServer.get_current_rendering_driver_name(),
		"--quit-after", "600", "--script", "res://tests/world_art_preview_smoke.gd", "--",
		"--pack=" + path, "--export-root=" + output.path_join("direct-pack-exports"),
		"--direct-pack-probe=" + report_path], child_output, true)
	var log_file := FileAccess.open(output.path_join("direct-pack.log"), FileAccess.WRITE)
	log_file.store_string("\n".join(child_output))
	log_file.close()
	_expect(status == 0 and FileAccess.file_exists(report_path), "independent --pack launch and export completes")
	if FileAccess.file_exists(report_path):
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		for result: Dictionary in report.results:
			_expect(result.ok, result.check)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Actual graphical display required")
		quit(77)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--direct-pack-probe="):
			await _run_direct_pack_probe(arg.trim_prefix("--direct-pack-probe="))
			return
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
	_check_export_guards(preview)
	_check_direct_pack_cli(preview)
	await _check_emission_letterbox()
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
	await _check_small_asymmetric_view(preview)
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
	preview.fit_width()
	_expect(preview._fit_policy == "width", "fit-width is an explicit camera policy")
	preview.fit_height()
	_expect(preview._fit_policy == "height", "fit-height is an explicit camera policy")
	preview.fit_view()
	_expect(preview._fit_policy == "all", "whole composition fits independently of aspect")
	_expect(preview.minimap.visible, "world overview navigation displayed")
	preview._navigate_from_minimap(Vector2(preview._native_size.x * 0.8, preview._native_size.y * 0.2))
	_expect(preview._fit_policy == "manual", "minimap navigation switches to manual camera mode")
	var minimap_origin: Vector2 = preview._origin
	preview._pan_by_keyboard(Vector2.RIGHT)
	_expect(preview._origin.x > minimap_origin.x, "arrow-key-equivalent pan moves the camera")
	preview.actual_pixels()
	_expect(is_equal_approx(preview._zoom, 1.0), "actual pixel zoom")
	preview._inspect(Vector2(preview.rig.size) * 0.5)
	_expect(preview.pointer_label.text.contains("Material ID"), "native pointer inspection")
	preview.fit_view()
	preview.feature_picker.select(1)
	preview.feature_picker.item_selected.emit(1)
	preview.variant_picker.select(1)
	preview.variant_picker.item_selected.emit(1)
	preview._background_enabled = false
	preview._update_presentation()
	preview.pin_current()
	await _frame()
	_expect(preview._baseline != null and not preview._baseline.is_empty(), "pin true framebuffer")
	var first_hash: String = preview.pack_hash
	var first_path: String = preview.pack_path
	var first_feature: String = preview._chosen_feature()
	var first_variant: String = preview._chosen_variant()
	var first_dimensions: Vector2i = preview._native_size
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
	_expect(preview.open_pack(disposable_pack), "reload modified disposable copy")
	_expect(preview.pack_hash != first_hash, "loaded content identity changes")
	preview._background_enabled = true
	preview._update_presentation()
	preview.toggle_comparison()
	_expect(preview.baseline_overlay.visible, "show pinned original framebuffer")
	_expect(not preview._background_enabled, "before comparison restores pinned background policy")
	await preview.export_art("viewport")
	var pinned_export: String = preview.last_export_dir
	var pinned_image: Image = Image.load_from_file(pinned_export.path_join("viewport.png"))
	if pinned_image != null:
		pinned_image.convert(Image.FORMAT_RGB8)
	_expect(pinned_image != null and pinned_image.get_data() == preview._baseline.get_data(),
		"pinned-before screenshot exports original captured framebuffer pixels")
	var pinned_meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		pinned_export.path_join("metadata.json")))
	_expect(typeof(pinned_meta) == TYPE_DICTIONARY
		and pinned_meta.get("pack_sha256", "") == first_hash
		and pinned_meta.get("visible_frame", "") == "pinned-before",
		"pinned-before PNG carries original source identity")
	_expect(typeof(pinned_meta) == TYPE_DICTIONARY
		and pinned_meta.get("pack_path", "") == first_path
		and pinned_meta.get("selected_feature", "") == first_feature
		and pinned_meta.get("selected_variant", "") == first_variant
		and int(pinned_meta.get("native_dimensions", [0, 0])[0]) == first_dimensions.x
		and int(pinned_meta.get("native_dimensions", [0, 0])[1]) == first_dimensions.y
		and not pinned_meta.get("presentation", {}).get("background", true),
		"pinned export retains original path feature variant dimensions and presentation")
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
	await preview.export_art("detail")
	_expect(FileAccess.file_exists(preview.last_export_dir.path_join("detail.png")),
		"detail crop exports actual framebuffer PNG")
	preview.feature_picker.select(1)
	preview.feature_picker.item_selected.emit(1)
	preview.variant_picker.select(0)
	preview._playing = true
	var export_time: float = preview._presentation_time
	(func() -> void: preview.time_slider.value = export_time + 3.0).call_deferred()
	await preview.export_art("feature")
	preview._playing = false
	var feature_dir: String = preview.last_export_dir
	_expect(FileAccess.file_exists(feature_dir.path_join("feature.png")), "selected feature export PNG")
	var feature_metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		feature_dir.path_join("metadata.json")))
	_expect(typeof(feature_metadata) == TYPE_DICTIONARY
		and feature_metadata.get("source_rg8_sha256", "") == preview._result.get("rg8_sha256", ""),
		"feature export metadata identifies actual selected RG8 source")
	_expect(typeof(feature_metadata) == TYPE_DICTIONARY
		and is_equal_approx(feature_metadata.presentation.time, export_time),
		"animated full export keeps captured presentation time in provenance")
	_expect(is_equal_approx(preview.rig._time, preview.time_slider.value),
		"presentation change during export reaches viewer after snapshot completes")
	await preview.export_art("combined")
	var combined_metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		preview.last_export_dir.path_join("metadata.json")))
	_expect(typeof(combined_metadata) == TYPE_DICTIONARY
		and combined_metadata.selected_feature == "" and combined_metadata.selected_variant == "",
		"full composition export does not inherit current feature selection")
	preview.feature_picker.select(0)
	preview.feature_picker.item_selected.emit(0)
	preview._playing = true
	var prior_time: float = preview._presentation_time
	for tick: int in range(6):
		await process_frame
	_expect(preview._presentation_time > prior_time, "play updates shader presentation time")
	preview._playing = false
	await _frame()
	var ui_image: Image = root.get_texture().get_image()
	_expect(ui_image != null and not ui_image.is_empty(), "actual desktop application window framebuffer")
	if ui_image != null and not ui_image.is_empty():
		ui_image.convert(Image.FORMAT_RGB8)
		_expect(ui_image.save_png(output.path_join("application-window.png")) == OK,
			"save full UI window screenshot")
	var summary := {"status": "pass" if failures == 0 else "fail", "failures": failures,
		"collections": preview._collections.size(), "features": inspected_features,
		"display": DisplayServer.get_name(), "backend": RenderingServer.get_current_rendering_driver_name(),
		"source_revision": preview.design_revision, "results": results}
	var report := FileAccess.open(output.path_join("smoke-report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(summary, "  ") + "\n")
	report.close()
	print("WORLD_ART_SMOKE " + JSON.stringify(summary))
	quit(0 if failures == 0 else 1)
