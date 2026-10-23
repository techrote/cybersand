extends SceneTree

# Display-backed UI/pixel witnesses. Headless is an explicit failure, not a skip.
# Every retained image comes from the actual workbench / GraphEdit viewport.
const Scene = preload("res://worldgen_workbench.tscn")
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}
var output: String = ""
var captures: Array[Dictionary] = []

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func pixels(viewport: Viewport) -> Image:
	var image: Image = viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image

func changed(a: Image, b: Image, bounds: Rect2i) -> int:
	if a.get_size() != b.get_size(): return -1
	var data_a: PackedByteArray = a.get_data()
	var data_b: PackedByteArray = b.get_data()
	var clipped: Rect2i = bounds.intersection(Rect2i(Vector2i.ZERO, a.get_size()))
	var count: int = 0
	for y: int in range(clipped.position.y, clipped.end.y):
		for x: int in range(clipped.position.x, clipped.end.x):
			var index: int = (y * a.get_width() + x) * 4
			if absi(int(data_a[index]) - int(data_b[index])) + absi(int(data_a[index + 1]) - int(data_b[index + 1])) + absi(int(data_a[index + 2]) - int(data_b[index + 2])) > 12: count += 1
	return count

func drain(app: Variant) -> void:
	var steps: int = 0
	while (app._has_active_chunk or not app.pending_chunks.is_empty()) and steps < 4096:
		app.service_generation()
		steps += 1
	expect(steps < 4096 and app._blocked_chunks.is_empty(), "Rendered preview failed to complete: " + app.last_error)

func drain_auxiliary(app: Variant) -> void:
	var frames: int = 0
	while (not app.tools2.aux_active.is_empty() or not app.tools2.aux_jobs.is_empty()) and frames < 4096:
		app.tools2.service_auxiliary()
		frames += 1
		await process_frame
	expect(frames < 4096 and app.last_error.is_empty(), "Displayed auxiliary jobs failed to complete: " + app.last_error)

func select_overlay(app: Variant, index: int) -> void:
	app.tools2.overlay_picker.select(index)
	app.tools2.overlay_picker.item_selected.emit(index)

func show_cards(app: Variant) -> void:
	var ancestor: Node = app.tools2.seed_cards.get_parent()
	while ancestor != null and not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer:
		ancestor.scroll_vertical = maxi(0, ancestor.scroll_vertical + roundi(app.tools2.aux_status.global_position.y - ancestor.global_position.y) - 12)

func save(image: Image, name: String, app: Variant) -> void:
	var record: Dictionary = {"name":name, "width":image.get_width(), "height":image.get_height(), "pixel_hash":image.get_data().hex_encode().sha256_text(), "recipe_sha256":JSON.stringify(app.active_recipe, "", true, true).sha256_text(), "revision":app.active_revision, "fingerprint":app.active_fingerprint, "session":app.tools2.session, "plane":app.tools2.selected_plane, "stage":app.tools2.selected_stage, "diagnostic":app.diagnostic_channel}
	if not output.is_empty():
		var path: String = output.path_join(name + ".png")
		expect(image.save_png(path) == OK, "Could not retain actual renderer image: " + name)
		record.file_sha256 = FileAccess.get_sha256(path)
	captures.append(record)

func recipe_file(name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../examples/worldgen/" + name + ".json")))
	return parsed if parsed is Dictionary else {}

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GEN-007 Workbench GUI/pixel checks require a display-backed renderer")
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gen007-workbench-render-output="): output = argument.trim_prefix("--gen007-workbench-render-output=")
	if not output.is_empty(): expect(DirAccess.make_dir_recursive_absolute(output) == OK, "Could not create renderer evidence directory")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var app: Variant = Scene.instantiate()
	viewport.add_child(app)
	app.set_process(false)
	expect(app.generator != null and app.generator.has_method(&"inspect_generation") and app.generator.has_method(&"adopt_configuration"), "Matching GEN-007 native runtime is required")
	if app.generator == null or not app.generator.has_method(&"inspect_generation") or not app.generator.has_method(&"adopt_configuration"):
		app.queue_free()
		viewport.queue_free()
		quit(1)
		return
	expect(app.load_spatial_example("typed-vector-utilities"), "Rendered vector example did not configure")
	app.view_size = Vector2(64, 64)
	app.set_camera_origin(Vector2(-32,64))
	app.preview.grid_visible = false
	app.preview.guides_visible = false
	drain(app)
	await settle()
	var preview_rect := Rect2i(app.preview.global_position + app.preview.content_rect().position, app.preview.content_rect().size)
	expect(preview_rect.size.x >= 500 and preview_rect.size.y >= 350, "Workbench controls leave no useful preview area")
	expect(app.preview.get_global_rect().end.x <= viewport.size.x + 1, "Workbench toolbar minimum widths push the preview outside the viewport")
	var final_image: Image = pixels(viewport)
	save(final_image, "workbench-materials", app)
	expect(app.select_diagnostic("spatial:tangent"), "Native tangent diagnostic unavailable")
	drain(app)
	await settle()
	var false_colour: Image = pixels(viewport)
	expect(changed(final_image, false_colour, preview_rect) > 1000, "Typed false-colour view did not render real diagnostic data")
	save(false_colour, "workbench-vector-field", app)
	select_overlay(app, 2)
	await settle()
	var arrows: Image = pixels(viewport)
	expect(changed(false_colour, arrows, preview_rect) > 100, "Actual vector-arrow overlay rendered no useful pixels")
	save(arrows, "workbench-vector-arrows", app)
	select_overlay(app, 3)
	await settle()
	var streamlines: Image = pixels(viewport)
	expect(changed(false_colour, streamlines, preview_rect) > 100, "Bounded streamlines rendered no useful pixels")
	save(streamlines, "workbench-streamlines", app)
	completed.field_views = 4
	select_overlay(app, 0)
	app.select_diagnostic("")
	expect(app.tools2.select_stage("candidate"), "Actual candidate stage unavailable")
	drain(app)
	await settle()
	var candidate: Image = pixels(viewport)
	expect(changed(final_image, candidate, preview_rect) > 100, "Stage scrubber did not reveal the actual pre-modifier candidate")
	save(candidate, "workbench-candidate-stage", app)
	app.tools2.select_stage("final")
	drain(app)
	await settle()
	expect(changed(final_image, pixels(viewport), preview_rect) == 0, "Returning to final stage did not reproduce accepted material pixels")
	completed.stage_views = 2
	app.tools2.open_graph()
	app.tools2._graph_selected(app.tools2.graph.get_node("operator_5"))
	await settle()
	var graph_image: Image = pixels(app.tools2.graph_window)
	expect(graph_image.get_width() >= 800 and graph_image.get_height() >= 540, "Graph canvas has no real rendered viewport")
	var before_hide: Image = graph_image
	app.tools2.graph.hide()
	await settle()
	var without_graph: Image = pixels(app.tools2.graph_window)
	expect(changed(before_hide, without_graph, Rect2i(Vector2i.ZERO, graph_image.get_size())) > 3000, "Typed nodes/ports are not visibly rendered in GraphEdit")
	app.tools2.graph.show()
	await settle()
	save(pixels(app.tools2.graph_window), "workbench-graph-canvas", app)
	app.tools2.graph_window.hide()
	completed.graph_canvas = 1
	expect(app.apply_recipe(recipe_file("semantic-refinery")), "Rendered four-plane fixture failed")
	app.view_size = Vector2(256,192)
	app.set_camera_origin(Vector2(-128,-128))
	app.tools2.select_plane(4)
	drain(app)
	await settle()
	preview_rect = Rect2i(app.preview.global_position + app.preview.content_rect().position, app.preview.content_rect().size)
	var composite: Image = pixels(viewport)
	save(composite, "workbench-four-plane-composite", app)
	for plane: int in range(4):
		app.tools2.select_plane(plane)
		drain(app)
		await settle()
		var isolated: Image = pixels(viewport)
		expect(changed(composite, isolated, preview_rect) > 100, "Plane isolation produced no visible difference for " + str(plane))
		save(isolated, "workbench-isolated-" + app.tools2.selected_plane, app)
	app.tools2.select_plane(4)
	drain(app)
	select_overlay(app, 1)
	app.page_picker.select(8)
	app.page_picker.item_selected.emit(8)
	app.tools2.hierarchy.get_root().get_first_child().select(0)
	app.tools2._select_feature()
	await settle()
	var overlay: Image = pixels(viewport)
	expect(changed(composite, overlay, preview_rect) > 100, "Feature/socket/route overlay rendered no native semantic geometry")
	save(overlay, "workbench-route-socket-hierarchy", app)
	completed.plane_hierarchy_views = 5
	app.page_picker.select(10)
	app.page_picker.item_selected.emit(10)
	select_overlay(app, 4)
	await settle()
	save(pixels(viewport), "workbench-feature-density", app)
	select_overlay(app, 5)
	await settle()
	save(pixels(viewport), "workbench-measured-chunk-time", app)
	select_overlay(app, 6)
	await settle()
	save(pixels(viewport), "workbench-logical-work", app)
	completed.quality_views = 3
	select_overlay(app, 1)
	app.page_picker.select(9)
	app.page_picker.item_selected.emit(9)
	app._inspect_point(Vector2(-64, -64))
	expect(app.tools2.trace.get("ok", false) and app.tools2.trace.get("preview_comparison", {}).get("status", "") == "matches accepted native proposal", "Visible inspector did not match actual accepted four-plane output")
	await settle()
	var inspector: Image = pixels(viewport)
	expect(app.tools2.trace_view.is_visible_in_tree() and app.tools2.trace_view.text.contains("COPIED NATIVE DETAIL") and app.tools2.trace_view.text.contains("stages"), "Provenance pane has no real native stage detail")
	save(inspector, "workbench-cell-provenance", app)
	completed.inspector = 1
	app.page_picker.select(10)
	app.page_picker.item_selected.emit(10)
	app.tools2.seed_input.text = "19301,19317,19337,19361"
	expect(app.tools2.start_seed_browser(), "Visible declared seed suite did not start")
	await drain_auxiliary(app)
	expect(app.tools2.aux_results.size() == 4, "Visible seed browser omitted declared variants")
	await settle()
	show_cards(app)
	await settle()
	var seed_cards: Image = pixels(viewport)
	expect(changed(inspector, seed_cards, Rect2i(0,0,420,1000)) > 1000, "Populated seed cards did not change the visible quality pane")
	save(seed_cards, "workbench-seed-browser", app)
	expect(app.tools2.pin_before(), "Visible same-seed comparison baseline did not pin")
	var edited: Dictionary = app.active_recipe.duplicate(true)
	edited.overrides = edited.get("overrides", []).duplicate(true)
	edited.overrides.append({"id":"gui-comparison-change", "priority":1000, "bounds":[-112,-112,12,12], "material":124})
	edited.grammar.rules[0].tags.append("gui-edited-district")
	expect(app.apply_recipe(edited), "Visible material / semantic edit was not accepted")
	drain(app)
	expect(app.tools2.start_comparison(), "Visible before/after job did not start")
	await drain_auxiliary(app)
	expect(app.tools2.last_comparison.get("materials", {}).get("play", {}).get("changed_cells", 0) > 0 and app.tools2.last_comparison.get("semantic_changed", 0) > 0, "Visible comparison omitted the actual material or semantic edit")
	await settle()
	show_cards(app)
	await settle()
	var comparison: Image = pixels(viewport)
	expect(changed(seed_cards, comparison, Rect2i(0,0,420,1000)) > 1000, "Populated before/after comparison did not visibly replace the seed browser")
	save(comparison, "workbench-before-after", app)
	completed.comparison_browser = 2
	for key: String in ["field_views", "stage_views", "graph_canvas", "plane_hierarchy_views", "quality_views", "inspector", "comparison_browser"]:
		expect(int(completed.get(key, 0)) > 0, "Render helper did not complete: " + key)
	if not output.is_empty():
		var evidence: Dictionary = {"schema":1, "source_commit":OS.get_environment("CYBERSAND_SOURCE_SHA"), "runtime_sha256":FileAccess.get_sha256(ProjectSettings.globalize_path("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")) if OS.get_name() == "Linux" else FileAccess.get_sha256(ProjectSettings.globalize_path("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll")), "platform":OS.get_name(), "display":DisplayServer.get_name(), "renderer":RenderingServer.get_video_adapter_name(), "godot":Engine.get_version_info(), "captures":captures, "completed":completed, "assertions":assertions, "failures":failures}
		evidence.source_file_sha256 = {}
		for source: String in ["res://scripts/worldgen_workbench.gd", "res://scripts/worldgen_workbench_tools.gd", "res://scripts/worldgen_preview.gd", "res://worldgen_workbench.tscn", "res://tests/test_gen007_workbench_render.gd"]:
			evidence.source_file_sha256[source] = FileAccess.get_sha256(source)
		var file: FileAccess = FileAccess.open(output.path_join("workbench-render-evidence.json"), FileAccess.WRITE)
		expect(file != null, "Could not retain renderer identity manifest")
		if file != null:
			evidence.assertions = assertions
			evidence.failures = failures
			file.store_string(JSON.stringify(evidence, "  ", true, true) + "\n")
			file.close()
	app.queue_free()
	viewport.queue_free()
	await process_frame
	print("GEN007_WORKBENCH_RENDER: %d assertions; %d failures; completed=%s" % [assertions, failures, JSON.stringify(completed)])
	quit(1 if failures else 0)
