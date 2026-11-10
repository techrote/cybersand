extends SceneTree

const Dialog = preload("res://scripts/workbench_generator_dialog.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func settings() -> Dictionary:
	return {"small":false,"native":false,"saved_first":false}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("EXPLORE_LAYOUT " + label)

func geometry(dialog: Window, label: String) -> void:
	var bounds := Rect2i(Vector2i.ZERO,root.size) if dialog.is_embedded() else DisplayServer.screen_get_usable_rect(root.current_screen)
	var rect := Rect2i(dialog.position,dialog.size)
	print("EXPLORE_LAYOUT_GEOMETRY ",JSON.stringify({"label":label,"embedded":dialog.is_embedded(),
		"bounds":str(bounds),"position":str(dialog.position),"size":str(dialog.size)}))
	check(bounds.encloses(rect),label+" window fits available bounds")
	for button: Button in [dialog.get_ok_button(),dialog.get_cancel_button()]:
		check(button.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(button.get_global_rect()),
			label+" action button inside visible dialog: "+button.text)

func run() -> void:
	var options := settings()
	var side := 720 if options.small else 1080
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1280,720) if side==720 else Vector2i(1920,1080)
	root.gui_embed_subwindows=not options.native
	var owner := Control.new()
	root.add_child(owner)
	var dialog := Dialog.new()
	owner.add_child(dialog)
	dialog.mount(owner)
	# Deliberately show before the first container layout in this fresh process.
	if options.saved_first: open_saved_fixture(dialog)
	else: dialog.open_new()
	for i: int in 5: await process_frame
	geometry(dialog,"first")
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var viewport: Viewport=dialog if not dialog.is_embedded() else root
		check(viewport.get_texture().get_image().save_png(output.path_join("dialog-first.png"))==OK,"original rendered capture")
	dialog.hide()
	dialog.open_new()
	for i: int in 3: await process_frame
	geometry(dialog,"reopened")
	dialog.hide()
	if options.saved_first: dialog.open_new()
	else: open_saved_fixture(dialog)
	for i: int in 3: await process_frame
	geometry(dialog,"other-entry")
	root.size=Vector2i(1100,500)
	for i: int in 5: await process_frame
	geometry(dialog,"resized")
	dialog.size=Vector2i(dialog.size.x,360)
	for i: int in 3: await process_frame
	var scroll: ScrollContainer=dialog.get_child(0)
	scroll.scroll_vertical=10000
	await process_frame
	check(scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page and scroll.scroll_vertical>0,
		"oversized content remains reachable by vertical scrolling")
	geometry(dialog,"scrolled")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		var viewport: Viewport=dialog if not dialog.is_embedded() else root
		check(viewport.get_texture().get_image().save_png(output.path_join("dialog-scrolled.png"))==OK,"scrolled rendered capture")
	dialog.hide()
	owner.queue_free()
	await process_frame
	print("EXPLORE_LAYOUT_RESULTS checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func open_saved_fixture(dialog: Window) -> void:
	# Geometry-only saved-load fixture: valid native recipe/configuration, but
	# deliberately synthetic material identities; no World install is attempted.
	var recipe := {"schema":1,"seed":17,"chunk_size":64,"candidate":"strata"}
	var generator: Variant=ClassDB.instantiate(&"CyberWorldGenerator")
	var config: Dictionary=generator.configure(recipe)
	check(config.get("ok",false),"saved-dialog native recipe admitted")
	var bridge: Variant=ClassDB.instantiate(&"CyberDemoBridge")
	var setup: Dictionary=Setup.fresh(bridge.default_liquid_policy(),Vector2i(512,512))
	var provenance := {"schema":1,"recipe":recipe,"origin":[0,0],"extent":[512,512],
		"sha256":"0".repeat(64),"recipe_sha256":Store.recipe_hash(recipe),
		"generator_fingerprint":str(config.fingerprint),"plane_revision":"",
		"generator_revision":int(config.revision),"receipt_hashes":["0".repeat(16)]}
	dialog.open_saved(setup,provenance)
	dialog._stop()
