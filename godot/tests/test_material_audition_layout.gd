extends SceneTree

# Actual mounted Lab geometry. A fake owner isolates presentation from native
# qualification; a graphical run may additionally capture its framebuffer.
const ContractFixtures = preload("res://tests/test_material_audition_ui_contract.gd")
var checks := 0
var failures := 0

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MAT_AUDITION_LAYOUT: " + message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var scene: Control = load("res://materials_lab.tscn").instantiate()
	root.add_child(scene)
	var panel: Variant = scene.find_child("MaterialsLabPanel",true,false)
	var owner := ContractFixtures.Owner.new()
	for row: Dictionary in [
		{"property":"physical_state","declared":2,"effective":2,"change_class":"restart","applicability":"Changing phase requires different kernels and state contracts."},
		{"property":"hard_surface","declared":false,"effective":false,"change_class":"isolated","applicability":"Capability authoring remains in the isolated definition backend."},
		{"property":"name","declared":"Sand","effective":"Sand","change_class":"metadata","applicability":"Names describe material identity; they do not change simulation."}]:
		row.kind = "material"
		row.material_id = 2
		row.consumer = "Compiled native catalogue"
		owner.state.capabilities.append(row)
	panel.bind_current_scene(owner)
	panel.select_material(2)
	panel._tabs.current_tab = 5
	var audition: Control = panel.audition_panel
	var scroll: ScrollContainer = panel._tabs.get_child(5)
	for size: Vector2i in [Vector2i(1000,650),Vector2i(1280,720)]:
		root.size = size
		scroll.scroll_vertical = 0
		for frame: int in range(6): await process_frame
		var visible: Rect2 = scroll.get_global_rect()
		expect(visible.size.x > 500 and visible.size.y > 300,"ordinary window retains a useful current-scene bay: " + str(size))
		expect(visible.encloses(audition._buttons.apply.get_global_rect()),"Apply is immediately visible: " + str(size))
		expect(visible.encloses(audition._buttons.revert.get_global_rect()),"Revert is immediately visible: " + str(size))
		expect(visible.encloses(audition._buttons.reset.get_global_rect()),"Reset is immediately visible: " + str(size))
		expect(audition.size.x <= visible.size.x+1,"long native applicability text wraps inside the bay: " + str(size))
		var bar := scroll.get_v_scroll_bar()
		expect(bar.max_value > bar.page,"additional properties and profile controls are vertically scrollable: " + str(size))
		scroll.scroll_vertical = int(bar.max_value)
		for frame: int in range(3): await process_frame
		expect(visible.encloses(audition._buttons.demo.get_global_rect()),"demo controls remain reachable at the bottom: " + str(size))
		if DisplayServer.get_name() != "headless":
			var destination := OS.get_environment("MAT_AUDITION_LAYOUT_CAPTURE")
			if not destination.is_empty():
				DirAccess.make_dir_recursive_absolute(destination)
				scroll.scroll_vertical = 0
				await process_frame
				await RenderingServer.frame_post_draw
				expect(root.get_texture().get_image().save_png(destination.path_join("audition-%dx%d.png" % [size.x,size.y]))==OK,"actual graphical framebuffer captured")
	scene.queue_free()
	await process_frame
	print("MAT_AUDITION_LAYOUT: %d checks, %d failures; display=%s; fake-owner presentation only" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
