extends "res://tests/test_material_lab_ui.gd"

# Run non-headless with a real display. Images are the actual mounted native
# application viewport, never reconstructed UI illustrations.
# -- --output=/absolute/external/directory [--source=commit]
var source_revision: String = "unavailable"
var images: Array[String] = []
var ui_source_hashes: Dictionary = {}

func save_view(name: String) -> bool:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		expect(false,"Graphical viewport readback is empty: " + name)
		return false
	var path: String = output_directory.path_join(name + ".png")
	var error: Error = image.save_png(path)
	expect(error == OK,"Real graphical viewport PNG saved: " + path)
	if error == OK: images.append(path)
	return error == OK

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_directory = argument.trim_prefix("--output=").simplify_path()
		elif argument.begins_with("--source="): source_revision = argument.trim_prefix("--source=")
	var repository: String = ProjectSettings.globalize_path("res://..").simplify_path().trim_suffix("/")
	if output_directory.is_empty() or not output_directory.is_absolute_path() \
		or output_directory == repository or output_directory.begins_with(repository + "/"):
		expect(false,"Capture requires --output= with an absolute directory outside the source repository.")
		finish()
		return
	if DisplayServer.get_name() == "headless":
		expect(false,"Real graphical capture requires a display, not --headless.")
		finish()
		return
	expect(DirAccess.make_dir_recursive_absolute(output_directory) == OK,"Graphical output directory created")
	root.size = Vector2i(1680,1050)
	root.content_scale_size = Vector2i(1680,1050)
	DisplayServer.window_set_size(Vector2i(1680,1050))
	for path: String in ["scripts/material_lab_screen.gd","scripts/material_lab_panel.gd","scripts/material_lab_service.gd",
		"scripts/material_lab_catalogue.gd","scripts/material_lab_experiment.gd","tests/capture_material_lab.gd","tests/test_material_lab_ui.gd"]:
		ui_source_hashes[path] = FileAccess.get_sha256("res://" + path)
	screen = load(SCENE).instantiate()
	root.add_child(screen)
	current_scene = screen
	await process_frame
	panel = screen.find_child("MaterialsLabPanel",true,false)
	if panel == null or not panel.catalogue.native_available:
		expect(false,"Matching native Materials Lab panel is unavailable.")
		finish()
		return
	panel._python.text = "python" if OS.get_name() == "Windows" else "python3"
	search_select(3)
	panel._search.text = ""
	panel._search.text_changed.emit("")
	panel._tabs.current_tab = 0
	await save_view("01-inspector-water")
	search_select(21)
	await save_view("02-inspector-slush")
	search_select(2)
	panel._tabs.current_tab = 1
	if not await authoring("New powder 132"):
		finish()
		return
	panel._candidate_name.text = "Non-hard violet powder"
	panel._candidate_name.text_changed.emit(panel._candidate_name.text)
	panel._fields.density.value = 1439
	panel._colour.color = Color8(210,90,180,255)
	panel._colour.color_changed.emit(panel._colour.color)
	panel._granular.button_pressed = true
	if not await selected_directory("Export compiled bundle…",output_directory):
		finish()
		return
	var candidate_receipt: Dictionary = panel.last_backend_result.duplicate(true)
	await save_view("03-candidate-compiled-powder")
	search_select(23)
	if not await authoring("Duplicate selected"):
		finish()
		return
	panel._tabs.current_tab = 2
	panel._reaction_fields.probability.value = 0
	panel._roll.value = 1
	if not await authoring("Compile candidate reaction"):
		finish()
		return
	var reaction_receipt: Dictionary = panel.last_backend_result.duplicate(true)
	# The mounted Candidate tab carries the full compiled receipt; the reaction
	# page displays the authored rule and its exact probability alongside native
	# diagnostic controls, without claiming candidate World mutation.
	await save_view("04-candidate-reaction-threshold-zero")
	panel._partner.select(panel._partner.get_item_index(3))
	panel._tabs.current_tab = 3
	panel._seed.value = 2
	panel._steps.value = 120
	panel._workers.select(panel._workers.get_item_index(4))
	press("Prepare experiment")
	press("Run set number of steps")
	if not await wait_for(func() -> bool: return not panel._running,"graphical native test",45000):
		finish()
		return
	var native_receipt: Dictionary = panel.experiment.capture(source_revision)
	expect(native_receipt.ok and native_receipt.completed_tick == 120,"Graphical native experiment completed")
	await save_view("05-native-salt-water-result")
	panel._family.select(2)
	press("Prepare experiment")
	var applied_test_policy: Dictionary = panel.experiment.readback().applied_policy
	press("Show applied Water settings")
	search_select(3)
	expect(panel._summary.tooltip_text.contains("cellular_yield_v1"),"Graphical inspector shows actual installed test-owner Water CY policy")
	await save_view("06-inspector-applied-cy-policy")
	var manifest: Dictionary = {"schema_version":1,"source_revision":source_revision,
		"platform":OS.get_name(),"engine":Engine.get_version_info().get("string","unknown"),
		"display":DisplayServer.get_name(),"viewport":[root.size.x,root.size.y],"images":images,
		"ui_script_sha256_before_scene_load":ui_source_hashes,
		"candidate_receipt":candidate_receipt,"reaction_receipt":reaction_receipt,
		"native_experiment":native_receipt,"applied_test_policy":applied_test_policy,
		"scope":"Actual graphical Linux application; no Windows or human acceptance claim."}
	var file := FileAccess.open(output_directory.path_join("capture-receipt.json"),FileAccess.WRITE)
	if file == null:
		expect(false,"Graphical capture receipt cannot be written")
	else:
		file.store_string(JSON.stringify(manifest,"\t") + "\n")
		file.close()
	finish()

func finish() -> void:
	if is_instance_valid(panel): panel.experiment.close()
	print("MATERIAL_LAB_GRAPHICAL_CAPTURE: %d assertions; %d failures; images=%d; artifacts=%s" % [assertions,failures,images.size(),output_directory])
	quit(1 if failures else 0)
