extends SceneTree

# Actual submitted pixels and actual controls. This test intentionally refuses
# the headless display and is discovered by the ordinary hosted display shards.
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Scene = preload("res://wave_flow_evaluation.tscn")
const Lab = preload("res://scripts/wave_flow_session.gd")
var screen: Variant
var assertions: int = 0
var failures: int = 0
var captures: Array = []
var output: String = ""


func _initialize() -> void:
	run.call_deferred()


func expect(ok: bool, reason: String) -> bool:
	assertions += 1
	if not ok:
		failures += 1
		push_error("WAVE_FLOW_RENDER: " + reason)
	return ok


func until(predicate: Callable, reason: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("graphical_case_seconds")
	while Time.get_ticks_msec() < deadline and not predicate.call(): await process_frame
	return expect(predicate.call(), reason)


func click(button: Button) -> void:
	var center: Vector2 = button.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.global_position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		button.get_viewport().push_input(event, true)
		await process_frame


func find_button(text: String) -> Button:
	for node: Node in screen.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and node.text == text: return node
	return null


func pick(picker: OptionButton, index: int) -> bool:
	await click(picker)
	var popup: PopupMenu = picker.get_popup()
	if not expect(popup.visible, "actual option popup opens"): return false
	popup.set_item_accelerator(index, KEY_F19)
	var event := InputEventKey.new()
	event.keycode = KEY_F19
	event.pressed = true
	var accepted: bool = popup.activate_item_by_event(event)
	popup.set_item_accelerator(index, KEY_NONE)
	popup.hide()
	await process_frame
	return expect(accepted and picker.selected == index, "actual menu selection applied")


func layout(label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
	for button: Button in [screen.scene_picker, screen.solver_picker, find_button("Reset scene"), screen.pause_button]:
		expect(button != null and button.is_visible_in_tree() and bounds.encloses(button.get_global_rect()), label + " primary control fits viewport")
	expect(screen.view.size.x >= 128 and screen.view.size.y >= 128 and bounds.encloses(screen.view.get_global_rect()), label + " usable visible simulation view")


func capture(kind: String, ticks: int) -> void:
	if not await pick(screen.scene_picker, Lab.SCENES.find(kind)): return
	var reset: Button = find_button("Reset scene")
	if not expect(reset != null, "visible reset action"): return
	await click(reset)
	if not expect(screen.lab.scene_id == kind and screen.lab.status().enabled and screen.paused, "Reset constructs selected actual Wave fixture"): return
	await click(screen.pause_button)
	if not await until(func() -> bool: return screen.lab.ticks >= ticks or not screen.lab.error.is_empty(), "live native ticks progress " + kind): return
	await click(screen.pause_button)
	if not expect(screen.paused and screen.lab.error.is_empty(), "Pause keeps a healthy completed World " + kind): return
	screen._present()
	for frame: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	layout(kind)
	var status: Dictionary = screen.lab.status()
	expect(status.quantity_delta == 0 and status.completed_tick >= ticks, "rendered fixture represents conserved progressed native state " + kind)
	if kind in ["body", "needle"]:
		expect(screen.lab.actors != null and screen.overlay.visible and status.contacts > 0,
			"visible actual Rapier body and positive Water contact " + kind)
		var actual: Dictionary = screen.lab.actors.workbench_actor_state(1)
		expect(actual.model == ("needle" if kind == "needle" else "reference_barrel"), "actual authored body identity " + kind)
	var pixels: Image = root.get_texture().get_image()
	if not expect(pixels != null and not pixels.is_empty(), "actual framebuffer readable " + kind): return
	# Detect real blue Water inside the fitted view; labels/background alone must
	# not qualify an absent or broken native texture/shader.
	var view_rect: Rect2 = screen.view.get_global_rect()
	var blue: int = 0
	for y: int in range(1, 32):
		for x: int in range(1, 32):
			var point := Vector2i(view_rect.position + view_rect.size * Vector2(x / 32.0, y / 32.0))
			if point.x < 0 or point.y < 0 or point.x >= pixels.get_width() or point.y >= pixels.get_height(): continue
			var color: Color = pixels.get_pixelv(point)
			if color.b - color.r > 0.25 and color.g > 0.2: blue += 1
	expect(blue > 5, "submitted framebuffer contains the native Water surface " + kind)
	var path: String = output.path_join("wave-flow-" + kind + ".png")
	expect(pixels.save_png(path) == OK, "raw screenshot retained " + kind)
	captures.append({"scene":kind, "screenshot":path.get_file(), "ticks":status.completed_tick,
		"quantity":status.water_quantity, "quantity_delta":status.quantity_delta, "water_samples":blue,
		"contacts":status.contacts, "view":str(view_rect), "window":str(root.size)})


func run() -> void:
	if not expect(DisplayServer.get_name() != "headless", "real rendering display required; headless is not graphical qualification"):
		quit(1)
		return
	output = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if output.is_empty(): output = OS.get_environment("CYBERSAND_PRESENTATION_EVIDENCE")
	if output.is_empty(): output = ProjectSettings.globalize_path("user://wave-flow-render")
	expect(DirAccess.make_dir_recursive_absolute(output) == OK, "capture directory available")
	root.content_scale_size = Vector2i.ZERO
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 720)
	screen = Scene.instantiate()
	root.add_child(screen)
	for frame: int in range(5): await process_frame
	if not expect(screen.lab != null and screen.lab.world != null, "real evaluation scene starts"):
		screen.free()
		quit(1)
		return
	layout("first open at 1280×720")
	await pick(screen.size_picker, 0)
	await pick(screen.solver_picker, 1)
	await click(find_button("Reset scene"))
	expect(not screen.lab.status().enabled and screen.lab.solver == "freemass_v1", "actual UI disables Wave for FreeMass")
	await pick(screen.solver_picker, 0)
	for row: Array in [["dam",120], ["interference_add",180], ["body",90], ["needle",60]]:
		await capture(row[0], row[1])
		if failures > 0: break
	var receipt: Dictionary = {"source_commit":OS.get_environment("GITHUB_SHA"),
		"kind":"actual Godot/Rapier/native graphical evaluation; no physical GPU or human acceptance claim",
		"assertions":assertions, "failures":failures, "captures":captures}
	var file := FileAccess.open(output.path_join("wave-flow-render.json"), FileAccess.WRITE)
	expect(file != null, "capture receipt writable")
	if file != null:
		file.store_string(JSON.stringify(receipt, "\t") + "\n")
		file.close()
	screen.free()
	await process_frame
	await process_frame
	print("WAVE_FLOW_RENDER: ", JSON.stringify({"assertions":assertions, "failures":failures, "captures":captures.size()}))
	quit(int(failures > 0 or captures.size() != 4))
