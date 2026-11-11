extends SceneTree

# Actual mounted authoring controls, Python compiler and two real native Worlds.
# Native owner receipts, rather than rendered pixels, establish the outcomes.
const SCENE: String = "res://materials_lab.tscn"
var checks: int = 0
var failures: int = 0
var panel: Variant
var screen: Control
var output_directory: String
var capture_directory: String = ""
var result: Dictionary = {}
var capture_manifest: Dictionary = {}
var capture_source_hashes: Dictionary = {}

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="): capture_directory = argument.trim_prefix("--capture-output=")
	call_deferred("run")

func expect(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MATERIAL_LAB_WORLD: " + detail)

func wait_job() -> bool:
	var deadline: int = Time.get_ticks_msec() + 300000
	var frames: int = 0
	while panel.service.busy and Time.get_ticks_msec() < deadline:
		await process_frame
		frames += 1
	expect(not panel.service.busy,"Authoring process completed within its wall bound")
	expect(frames > 1,"The desktop processes frames while native compilation runs")
	return not panel.service.busy

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child: Node in node.get_children():
		var found: Button = find_button(child,caption)
		if found != null: return found
	return null

func press(caption: String) -> void:
	var button := find_button(panel,caption)
	expect(button != null and not button.disabled,"Mounted enabled button: " + caption)
	if button != null and not button.disabled: button.pressed.emit()

func save_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	expect(file != null,"Evidence file can be written")
	if file != null:
		file.store_string(JSON.stringify(value,"\t") + "\n")
		file.close()

func run() -> void:
	if not capture_directory.is_empty():
		root.size = Vector2i(1680,1050)
		root.content_scale_size = Vector2i(1680,1050)
		DisplayServer.window_set_size(Vector2i(1680,1050))
		capture_source_hashes = _capture_sources()
	output_directory = ProjectSettings.globalize_path("user://materials_lab/world-ui-%d" % Time.get_ticks_usec())
	expect(DirAccess.make_dir_recursive_absolute(output_directory) == OK,"World acceptance directory created")
	screen = load(SCENE).instantiate()
	root.add_child(screen)
	current_scene = screen
	await process_frame
	panel = screen.find_child("MaterialsLabPanel",true,false)
	if panel == null or not panel.catalogue.native_available:
		expect(false,"Matching native Materials Lab is required")
		finish()
		return
	var view: Variant = panel.world_panel
	expect(view._run_button.disabled,"An absent candidate cannot start a World test")
	press("New powder 132")
	await wait_job()
	expect(view._run_button.disabled and view._summary.text.contains("132"),"Synthetic132 remains descriptor-test-only")
	panel.select_material(2)
	press("Duplicate selected")
	await wait_job()
	expect(panel.candidate.target_id == 2 and not view._run_button.disabled,"Existing Sand candidate admits World testing")
	panel._fields.density.value = 500
	panel._colour.color = Color8(17,91,203,255)
	panel._colour.color_changed.emit(panel._colour.color)
	view._partner.select(view._partner.get_item_index(3))
	view._partner.item_selected.emit(view._partner.selected)
	view._workers.select(view._workers.get_item_index(4))
	view._workers.item_selected.emit(view._workers.selected)
	view._ticks.value = 120
	panel._tabs.current_tab = 4
	press("Export World test bundle…")
	expect(panel._file.file_mode == FileDialog.FILE_MODE_OPEN_DIR,"World export selects an external parent directory")
	panel._file.hide()
	panel._file.dir_selected.emit(output_directory)
	if not await wait_job():
		finish()
		return
	result = panel.last_backend_result.duplicate(true)
	if not result.get("ok",false):
		expect(false,"Actual compiled World result: " + str(result.get("errors",[])))
		finish()
		return
	var receipt: Dictionary = result.receipt
	expect(receipt.schema_id == "cybersand.material-lab.world-receipt" and not receipt.runtime_active,"Receipt identifies actual isolated World, never runtime-active")
	expect(result.state == "compiled_tested" and receipt.candidate.world_simulation,"Compiled/tested status follows real native execution")
	expect(int(receipt.candidate.descriptor_readback.density) == 500,"Generated density reached actual World descriptor consumer")
	var rgba: Array = receipt.candidate.descriptor_readback.rgba
	expect(rgba.size() == 4 and int(rgba[0]) == 17 and int(rgba[1]) == 91 and int(rgba[2]) == 203 and int(rgba[3]) == 255,"Compiled native appearance bytes match the UI edit")
	for backend: String in ["reference","candidate"]:
		for key: String in ["deterministic_repeat","worker_1_4_equal","persistence_checkpoint","persistence_replay","quantity_balanced"]:
			expect(receipt[backend].checks[key],backend + " native check: " + key)
		expect(int(receipt[backend].final.completed_ticks) == 120,"Native owner completed the requested bounded window")
		expect(receipt[backend].final.physical_state_hash is String,"64-bit native hashes remain exact strings through Godot JSON")
	expect(receipt.reference.final.water_quantity == receipt.candidate.final.water_quantity,"Density edit conserves actual native Water quantity")
	expect(receipt.candidate.final.target_below_reservoir < receipt.reference.final.target_below_reservoir,"Lower density visibly changes actual Sand penetration")
	expect(not receipt.comparison.equal,"Edited candidate differs from its untouched source-matched reference")
	expect(not view.receipt.is_empty() and view._reference_preview.texture != null and view._candidate_preview.texture != null,"Both previews are populated from native stored cells")
	expect(view._report.text.contains("500") or view._report.text.contains("native"),"Compact result identifies native test consequences")
	var stored: Dictionary = view.inspect_cell(Vector2i(242,238))
	expect(stored.get("ok",false) and stored.reference.has("state_a") and stored.candidate.has("temperature"),"Coordinate inspector exposes actual stored native state")
	expect(not view.inspect_cell(Vector2i(0,0)).get("ok",true),"Stored-cell inspector refuses outside-grid coordinates")
	view._stage.select(1)
	view._stage.item_selected.emit(1)
	expect(view.inspect_cell(Vector2i(242,238)).stage == "initial","Before/after view refers to the matching native snapshot")
	view._stage.select(0)
	view._stage.item_selected.emit(0)
	var bundle: String = str(result.output_dir)
	# Generated-file parity is checked by the compiler/tooling tests. This
	# Godot test reads receipts/presets, never generated native definitions.
	for relative: String in ["world-receipt.json","preset.json","reference/catalogue.json","candidate/catalogue.json"]:
		expect(FileAccess.file_exists(bundle.path_join(relative)),"Reusable World bundle includes " + relative)
	expect(not FileAccess.file_exists(bundle.path_join("candidate/lab-world-probe")),"Export contains source and evidence, not a native executable")
	var original_digest: String = panel.candidate_digest
	save_json(output_directory.path_join("ui-world-receipt.json"),receipt)
	if not capture_directory.is_empty():
		expect(DisplayServer.get_name() != "headless","Graphical evidence requires an actual display")
		DirAccess.make_dir_recursive_absolute(capture_directory)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = screen.get_viewport().get_texture().get_image()
		expect(not image.is_empty() and image.save_png(capture_directory.path_join("07-candidate-world-density.png")) == OK,"Actual desktop comparison screenshot saved")
		save_json(capture_directory.path_join("world-ui-receipt.json"),receipt)
		capture_manifest = {"engine":Engine.get_version_info(),"platform":OS.get_name(),"display":DisplayServer.get_name(),
			"viewport":[image.get_width(),image.get_height()],"image_sha256":FileAccess.get_sha256(capture_directory.path_join("07-candidate-world-density.png")),
			"source_sha256":capture_source_hashes,"native_source_identity":receipt.source_identity,
			"runtime_active":false,"scope":"Actual desktop viewport of two compiled native World stored-cell previews; no shader parity claim."}
	# Round-trip the bundle's ordinary versioned preset through the real service.
	panel._fields.density.value = 501
	expect(view.receipt.is_empty() and view._reference_preview.texture == null,"Candidate edits retire the prior native result")
	panel._file_action = "import_preset"
	panel._file_selected(bundle.path_join("preset.json"))
	await wait_job()
	expect(panel.candidate_digest == original_digest and panel.candidate.descriptor.density == 500,"World bundle preset round-trips through strict real import")
	# A real finished backend response must not qualify settings edited in flight.
	view._seed.value = 3
	press("Compile + compare World")
	view._seed.value = 4
	await wait_job()
	expect(panel._status.text.contains("older recipe") and view.receipt.is_empty(),"Finished native result cannot qualify a different current recipe")
	expect(not view._run_button.disabled,"A discarded old response releases the controls for the next test")
	expect(panel.candidate_digest == original_digest,"Recipe race does not corrupt the candidate preset")
	print("MATERIAL_LAB_WORLD_BUNDLE=" + bundle)
	finish()

func _capture_sources() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in ["scripts/material_lab_screen.gd","scripts/material_lab_panel.gd","scripts/material_lab_world_panel.gd",
		"scripts/material_lab_service.gd","scripts/material_lab_catalogue.gd","scripts/material_lab_experiment.gd","tests/test_material_lab_world.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes

func finish() -> void:
	if not capture_manifest.is_empty():
		expect(capture_source_hashes == _capture_sources(),"Graphical UI source stayed unchanged through the run")
		capture_manifest["checks"] = checks
		capture_manifest["failures"] = failures
		save_json(capture_directory.path_join("world-capture-manifest.json"),capture_manifest)
	if is_instance_valid(screen):
		screen.queue_free()
		await process_frame
	print("Materials Lab World UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
