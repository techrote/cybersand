extends SceneTree

# Real discovered recipe, full Shared Workbench and fresh-process reopen.
# Initial generation must not inject a recipe through _saved_recipe.
const Store = preload("res://scripts/workbench_generated_map.gd")
const SAVE_NAME := "wb-generator-installed-regression"
var host: Control
var wb: Control
var dialog: ConfirmationDialog
var checks := 0
var failures := 0
var completed := false

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label + (" / " + wb.message if wb != null else ""))
	return ok

func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 240000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		if host.simulation_worker.has_failed(): break
		await process_frame
	return check(predicate.call(), label + (" / " + dialog._status.text if dialog != null else ""))

func installed() -> bool:
	return not wb.applied.is_empty() and not wb.busy() and host.pending_microscenario_apply.is_empty()

func capture(label: String) -> void:
	var destination := OS.get_environment("WB_GENERATOR_SCREENSHOTS")
	if destination.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(destination)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(destination.path_join(label + ".png")) == OK, "original framebuffer " + label)

func exercise() -> void:
	check(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberWorldGenerator"), "compiled native cell World and generator loaded")
	if OS.get_environment("WB_GENERATOR_REQUIRE_GRAPHICS") == "1":
		if not check(DisplayServer.get_name() != "headless", "actual graphical display required"): return
	print("WB_GENERATOR_RUNTIME os=", OS.get_name(), " display=", DisplayServer.get_name(), " renderer=", RenderingServer.get_video_adapter_name(), " godot=", Engine.get_version_info().string)
	if not await until(installed, "full Shared Workbench installed"): return
	dialog = wb._generated_dialog
	dialog.open_new()
	if not check(dialog._profile.item_count >= 2, "installed dropdown contains real recipes"): return
	var expected_profiles := OS.get_environment("WB_GENERATOR_PROFILE_COUNT")
	if not expected_profiles.is_empty():
		if not check(dialog._profile.item_count == int(expected_profiles), "full Workbench profile count matches package manifest"): return
	check(dialog._profile.get_item_text(dialog._profile.selected) == "gen007-deepworks", "real Deepworks profile selected")
	await capture("generator-profiles")
	var reopening := OS.get_environment("WB_GENERATOR_REOPEN") == "1"
	var saved := {}
	if reopening:
		saved = Store.read_named(SAVE_NAME)
		if not check(saved.get("generated", false), "new process reads named generated start"): return
		dialog.hide()
		wb._name.text = SAVE_NAME
		if not check(wb.load_setup(), "existing Load start reconstructs saved recipe"): return
	else:
		dialog._extent.select(0)
		dialog._preview_button.pressed.emit()
	if not await until(func() -> bool: return dialog._phase == "ready" or dialog._status.text.begins_with("Refused"), "native profile preview finishes"): return
	if not check(dialog._phase == "ready", "real native discovered-profile preview accepted"): return
	var packet: Dictionary = dialog._ready_packet.duplicate(true)
	check(packet.cells.size() == 512 * 512 and not packet.receipt_hashes.is_empty(), "512-square native play plane and source receipts")
	await capture("generator-native-preview")
	dialog.confirmed.emit()
	dialog.hide()
	if not await until(func() -> bool: return installed() and not wb._generated_active.is_empty(), "generated map installed in same native worker"): return
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt", {})
	check(receipt.get("generated_source_sha256", "") == packet.sha256, "native constructor independently verifies generated source")
	if reopening:
		check(wb.applied.edits == saved.setup.edits, "fresh process preserves authored edits")
		check(wb.applied.actors == saved.setup.actors and wb.applied.liquid_policy == saved.setup.liquid_policy, "fresh process preserves actors and solver settings")
		check(wb._generated_active.recipe_sha256 == saved.generation.recipe_sha256, "recipe provenance survives reopen")
		if not await until(func() -> bool: return host.image.get_width() == 512 and host.image.get_pixel(101,99).r8 == 58 and host.image.get_pixel(111,99).r8 == 28, "native reopened edits have exact material IDs"): return
	else:
		wb._brush.value = 2
		if not check(wb.paint(Vector2i(101,99),58), "paint generated terrain with Hard Wall"): return
		if not await until(func() -> bool: return host.image.get_width() == 512 and host.image.get_pixel(101,99).r8 == 58, "native wall edit applied"): return
		if not check(wb.paint(Vector2i(111,99),28), "paint generated terrain with Metal"): return
		if not await until(func() -> bool: return host.image.get_pixel(111,99).r8 == 28, "native Metal edit applied"): return
		if not await until(installed, "paint receipts retired before save"): return
		wb._name.text = SAVE_NAME
		if not check(wb.save_setup(), "save named generated start after native painting"): return
		saved = Store.read_named(SAVE_NAME)
		check(saved.get("generated", false) and saved.setup.edits.size() >= 2, "saved recipe contains both edits")
	await capture("generator-reopened" if reopening else "generator-painted-saved")
	if reopening:
		check(wb.paint(Vector2i(123,99),58), "continue authoring after complete process restart")
		if not await until(func() -> bool: return host.image.get_pixel(123,99).r8 == 58, "continued edit applied natively"): return
	completed = true

func run() -> void:
	root.size = Vector2i(1280,900)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	host = current_scene
	wb = host.shared_workbench
	await exercise()
	check(completed, "complete installed generate/install/paint/save or fresh-process reopen flow executed")
	host.queue_free()
	await process_frame
	await process_frame
	print("WB_GENERATOR_INSTALLED checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
