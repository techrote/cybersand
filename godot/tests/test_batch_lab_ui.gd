extends SceneTree
## Real native attempts plus actual Godot panel rendering and control bindings.
## Run graphically; a headless invocation explicitly refuses graphical qualification.
const BatchPanel = preload("res://scripts/batch_lab/batch_lab_panel.gd")
var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var timings := {}
var directory := ""
var panel: Window


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	print("BATCH_LAB_UI_CHECK ", label, " ", value)
	if not value:
		failures.append(label)
		push_error(label)


func settle(seconds := 180.0, wait_render := true) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var working: bool = panel._active()
		if not working and (not wait_render or (not panel._rendering and panel._render_queue.is_empty())):
			await process_frame
			panel.refresh()
			return true
		await process_frame
	return false


func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := directory.path_join(name + ".png")
	var ok := image != null and not image.is_empty() and image.save_png(path) == OK
	check(ok, "actual Godot screenshot " + name)
	if ok:
		captures.append({"file":name + ".png", "sha256":FileAccess.get_sha256(path),
			"width":image.get_width(), "height":image.get_height(), "kind":"godot-framebuffer"})


func run() -> void:
	directory = OS.get_environment("BATCH_LAB_EVIDENCE_DIR")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("user://batch-lab-ui-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(directory)
	check(DisplayServer.get_name() != "headless", "graphical display required; headless pixels are not screenshot evidence")
	if DisplayServer.get_name() == "headless":
		_finish()
		return
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i.ZERO
	root.gui_embed_subwindows = true
	panel = BatchPanel.new()
	root.add_child(panel)
	panel.position = Vector2i(30, 35)
	panel.show()
	await process_frame
	check(panel.controller.tiles.size() == 4 and panel.grid.columns == 2,
		"first opening exposes the genuine 2x2 feasibility grid")
	check(not panel._active(), "opening alone starts no native attempts or model requests")
	var start := Time.get_ticks_msec()
	panel.start_grid()
	check(await settle(), "2x2 execution and shader captures settle")
	timings.grid_2x2_ms = Time.get_ticks_msec() - start
	for index: int in 4:
		var tile: Dictionary = panel.controller.tiles[index]
		check(tile.state == "completed", "2x2 tile %d is native completed" % index)
		check(not tile.material_cells.is_empty() and int(tile.metrics.get("changed", 0)) > 0,
			"2x2 tile %d retains actual changed cells" % index)
		check(panel.rendered.get(index, {}).has("texture"), "2x2 tile %d uses captured shader image" % index)
	await capture("grid-2x2")
	check(panel.apply_example("architecture", 4, 19301, "procedural").get("ok", false), "4x4 configuration accepted")
	start = Time.get_ticks_msec()
	panel.start_grid()
	check(await settle(300.0), "all sixteen independent native attempts and shader captures settle")
	timings.grid_4x4_ms = Time.get_ticks_msec() - start
	var attempt_ids := {}
	for index: int in 16:
		var tile: Dictionary = panel.controller.tiles[index]
		check(tile.state == "completed", "4x4 tile %d completed through native owner" % index)
		check(not str(tile.get("attempt_id", "")).is_empty() and not attempt_ids.has(tile.get("attempt_id")),
			"4x4 tile %d has independent attempt identity" % index)
		attempt_ids[tile.get("attempt_id")] = true
		check(tile.material_cells.size() == 128 * 128 * 2, "4x4 tile %d retains full uint16 native plane" % index)
		check(panel.rendered.get(index, {}).has("texture"), "4x4 tile %d has real Godot material rendering" % index)
	check(panel.cards.size() == 16 and panel.grid.columns == 4, "sixteen genuine results occupy the 4x4 grid")
	await process_frame
	check(panel.grid.get_parent().get_global_rect().encloses(panel.cards[15].label.get_global_rect()),
		"all sixteen thumbnails and final-row metadata fit the overview without scrolling")
	await capture("grid-4x4")
	for pressed: bool in [true, false]:
		var pointer := InputEventMouseButton.new()
		pointer.button_index = MOUSE_BUTTON_LEFT
		pointer.pressed = pressed
		pointer.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		pointer.position = panel.cards[6].image.get_global_rect().get_center()
		pointer.global_position = pointer.position
		panel.push_input(pointer, true)
		await process_frame
	check(panel.selected == 6, "actual viewport mouse input selects the thumbnail under the pointer")
	var captures_before: int = panel.render_count
	var refresh_before: int = panel.presentation_refresh_usec
	var cached_begin := Time.get_ticks_usec()
	for iteration: int in 32:
		panel.select_tile(iteration % 16)
		panel.refresh()
		panel.main_view.set_framing(Vector2(64, 64), 1.0 + float(iteration % 4))
		await process_frame
	timings.cached_32_inspections_ms = float(Time.get_ticks_usec() - cached_begin) / 1000.0
	timings.cached_presentation_cpu_ms = float(panel.presentation_refresh_usec - refresh_before) / 1000.0
	timings.initial_shader_capture_ms = panel.render_elapsed_ms
	timings.shader_capture_count = panel.render_count
	check(panel.render_count == captures_before, "32 selections, zooms and refreshes reuse immutable shader images without any recapture")
	var receipt_before := JSON.stringify(panel.controller.tiles[5].receipts).sha256_text()
	panel.cards[5].button.pressed.emit()
	panel.refresh()
	check(panel.selected == 5, "tile button selects its real attempt")
	check(panel.main_view.texture != null and panel.main_view.native_cells == panel.controller.tiles[5].material_cells,
		"inspection image and hover use selected authoritative plane")
	check(JSON.stringify(panel.controller.tiles[5].receipts).sha256_text() == receipt_before,
		"inspection never mutates original native receipts")
	var first_material: int = panel.controller.tiles[5].material_cells.decode_u16(0)
	check(panel.main_view.material_at(Vector2i.ZERO) == first_material, "native ID hover reads stored uint16 bytes")
	panel.main_view.native_scale()
	check(absf(panel.main_view.pixels_per_cell() - 1.0) < 0.00001, "inspection 1:1 means one displayed pixel per native cell")
	await capture("tile-inspector")
	panel.set_compare([1, 5, 9])
	panel.refresh()
	check(panel.compare_views.size() == 3, "three independent attempts can be compared")
	panel._sync_comparison(Vector2(61, 47), 2.0)
	for view: Control in panel.compare_views:
		check(view.center == Vector2(61, 47) and view.zoom == 2.0, "comparison framing synchronizes native coordinates and zoom")
	check(is_equal_approx(panel.compare_views[0].pixels_per_cell(), panel.compare_views[2].pixels_per_cell()),
		"comparison uses equivalent native-cell scale")
	await capture("comparison")
	panel.set_blind(true)
	panel.refresh()
	check(panel.tabs.is_tab_hidden(1), "blind comparison hides configuration")
	check(not panel.details.text.contains("deterministic-v1") and not panel.details.text.contains("prompt_version"),
		"blind inspector excludes model and prompt identity")
	check(panel._blind_codes.size() == 16, "blind order supplies anonymous identity for every outcome")
	for card: Dictionary in panel.cards:
		check(not card.label.text.contains("seed") and not card.label.text.contains("P0") and not card.label.text.contains("P3"),
			"blind thumbnail hides treatment and seed")
	await capture("blinded-comparison")
	panel.set_blind(false)
	panel.select_tile(0)
	panel.refresh()
	panel.copy_configuration()
	panel.select_tile(15)
	panel.paste_configuration()
	check(panel.controller.tiles[15].config.seed == panel.controller.tiles[0].config.seed,
		"copy/paste configuration does not require re-execution")
	check(panel._result_config(panel.controller.tiles[15]).seed != panel.controller.tiles[15].config.seed,
		"completed result keeps its original seed identity when next-attempt config changes")
	var native_before: PackedByteArray = panel.controller.tiles[15].material_cells.duplicate()
	var neighbour_before: PackedByteArray = panel.controller.tiles[0].material_cells.duplicate()
	panel.preview_selected()
	check(panel.controller.tiles[15].material_cells == native_before, "compilation preview writes zero native cells")
	var replay_hash := str(panel.controller.tiles[15].get("material_sha256", ""))
	panel.replay_selected()
	check(await settle(), "selected replay runs to native completion")
	check(str(panel.controller.tiles[15].get("material_sha256", "")) == replay_hash,
		"replay retains original program/source despite changed next-attempt config")
	var history_identity := str(panel.controller.tiles[15].attempts[0])
	var retained_count: int = panel.controller.attempts.size()
	check(panel.controller.select_attempt(15, history_identity).get("ok", false), "retained original attempt can be inspected again")
	panel.rendered.erase(15)
	panel.refresh()
	check(panel.controller.attempts.size() == retained_count, "history inspection creates no native attempt")
	check(panel.controller.tiles[15].material_sha256 == replay_hash, "history inspection preserves original native materials")
	var session := directory.path_join("session.json")
	check(panel.controller.save_session(session).get("ok", false), "settled full grid saves")
	var export_path := directory.path_join("export")
	check(panel.export_grid(export_path).get("ok", false), "grid export includes native planes and provenance")
	var second := BatchPanel.new()
	root.add_child(second)
	check(second.controller.load_session(session).get("ok", false), "new panel reopens saved native results")
	check(second.controller.tiles.size() == 16, "reopened session retains sixteen attempts")
	for index: int in 16:
		check(second.controller.tiles[index].material_cells == panel.controller.tiles[index].material_cells,
			"reopened tile %d retains exact native materials" % index)
	second.queue_free()
	await process_frame
	panel.select_tile(1)
	panel.provider.select(4)
	panel.model.text = "unapproved-cloud-comparison"
	panel.start_selected()
	check(await settle(), "unavailable cloud attempt returns to interactive state")
	check(panel.controller.tiles[1].state == "refused", "cloud spending is refused without authority")
	check(panel.controller.tiles[0].material_cells == neighbour_before,
		"a refused neighbouring attempt cannot alter another tile")
	await capture("failure-retained")
	check(panel.apply_example("pipework", 2, 19301, "procedural").get("ok", false), "new grid retains old attempts in session ledger")
	var stop_config: Dictionary = panel.controller.tiles[0].config.duplicate(true)
	stop_config.provider = "direct"
	stop_config.extent = [512, 512]
	stop_config.source_region = [0, 0, 512, 512]
	stop_config.source_rectangles = []
	stop_config.protection = []
	stop_config.operations = [{"shape":"rectangle", "x0":0, "y0":0, "x1":511, "y1":511, "material":58},
		{"shape":"rectangle", "x0":0, "y0":0, "x1":511, "y1":511, "material":0}]
	stop_config.budget_cells = 262144
	check(panel.controller.configure_tile(0, stop_config).get("ok", false), "long native attempt configured for real Stop")
	panel.select_tile(0)
	panel.start_grid()
	var stop_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < stop_deadline and int(panel.controller.tiles[0].metrics.get("changed", 0)) == 0:
		await process_frame
	check(panel.controller.tiles[0].state == "running" and int(panel.controller.tiles[0].metrics.get("changed", 0)) > 0,
		"Stop is exercised after genuine native writes while suffix remains pending")
	panel.refresh()
	check(not panel._stop_button.disabled, "Stop control remains enabled during native execution")
	panel._stop_button.pressed.emit()
	check(await settle(60.0), "Stop control retires active and queued attempts")
	check(panel.controller.tiles[0].state in ["partial", "stopped"], "stopped tile reports partial or stopped rather than completed")
	check(not panel.controller.tiles[0].material_cells.is_empty(), "stopped tile retains authoritative partial readback")
	await capture("stopped-grid")
	check(panel.export_grid(directory.path_join("partial-export")).get("ok", false),
		"partial and stopped grid exports without dropping unsuccessful attempts")
	var retained_results: int = panel.controller.attempts.size()
	check(panel.controller.reset().get("ok", false) and panel.controller.attempts.size() == retained_results,
		"reset clears the grid without deleting retained attempt history")
	check(panel.export_grid(directory.path_join("idle-grid-export")).get("ok", false),
		"unexecuted grid exports configuration and retained history without fabricated results")
	panel.stop_grid()
	check(await settle(), "Stop leaves no queued native or rendering work")
	_finish()


func _finish() -> void:
	var summary := {"schema":1, "suite":"batch-lab-ui", "complete":failures.is_empty(),
		"checks":checks, "failures":failures, "timings_ms":timings, "captures":captures,
		"godot":Engine.get_version_info().string, "os":OS.get_name(),
		"display":DisplayServer.get_name(), "rendering_driver":RenderingServer.get_current_rendering_driver_name(),
		"graphics_adapter":RenderingServer.get_video_adapter_name(),
		"evidence_kind":"actual native execution and Godot framebuffer; not model quality or physical owner acceptance"}
	var output := FileAccess.open(directory.path_join("summary.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(summary, "  ") + "\n")
		output.close()
	print("BATCH_LAB_UI_RESULT ", JSON.stringify(summary))
	if is_instance_valid(panel): panel.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
