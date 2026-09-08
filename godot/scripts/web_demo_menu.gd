class_name CyberWebDemoMenu
extends Control

var host: Variant
var overlay: ColorRect
var pages: Dictionary = {}
var buttons: Dictionary = {}
var save_text: TextEdit
var notice: Label
var capability: Label
var open: bool = true
var benchmark_text: TextEdit

func _label(parent: Node, text: String, font_size: int = 18) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, id: String, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.name = id
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	buttons[id] = button
	return button

func _page(parent: Node, id: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	parent.add_child(page)
	pages[id] = page
	return page

func setup(controller: Control) -> void:
	host = controller
	name = "WebMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var menu_button: Button = _button(self, "menu", "MENU / ESC", func() -> void: show_page("home"))
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_button.position = Vector2(size.x - 172, 10)
	menu_button.size = Vector2(152, 40)
	menu_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	overlay = ColorRect.new()
	overlay.color = Color(0.018, 0.027, 0.04, 0.97)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var centre: CenterContainer = CenterContainer.new()
	overlay.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	centre.add_child(panel)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.048, 0.063)
	style.border_color = Color(0.23, 0.62, 0.67)
	style.set_border_width_all(1)
	style.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_label(column, "CYBERSAND / WEB DEMO", 28)
	capability = _label(column, "Native engine starting", 14)
	capability.modulate = Color(0.48, 0.8, 0.83)
	if host.logical_threads < 4:
		var warning: Label = _label(column, "4 physical CPU cores are the recommended minimum.\nYour browser reports fewer than 4 logical threads; physical cores cannot be detected.", 14)
		warning.modulate = Color(1.0, 0.75, 0.35)
	column.add_child(HSeparator.new())

	var home: VBoxContainer = _page(column, "home")
	_label(home, "DEMONSTRATIONS", 14)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	home.add_child(grid)
	for i: int in range(CyberDemoWorlds.IDS.size()):
		var id: String = CyberDemoWorlds.IDS[i]
		var button: Button = _button(grid, id, CyberDemoWorlds.TITLES[i], func() -> void: host.select_demo(id))
		button.custom_minimum_size = Vector2(344, 53)
		button.tooltip_text = CyberDemoWorlds.DESCRIPTIONS[i]
		if id == "physics_pit":
			button.disabled = not host.rapier_available
			if button.disabled:
				button.text = "Physics Pit / unavailable"
				button.tooltip_text = "This build is cellular-only. The other worlds remain available."
	_label(home, "SESSION", 14)
	var session: HBoxContainer = HBoxContainer.new()
	home.add_child(session)
	_button(session, "continue", "Continue", close_menu)
	_button(session, "restart", "Restart world", func() -> void: host.select_demo(host.demo_id))
	_button(session, "save_load", "Save / Load", func() -> void: show_page("save"))
	var quality_row: HBoxContainer = HBoxContainer.new()
	home.add_child(quality_row)
	_label(quality_row, "QUALITY  ", 14)
	for i: int in range(3):
		var names: Array[String] = ["LOW", "NORMAL", "HIGH"]
		_button(quality_row, "quality_%d" % i, names[i], func() -> void: host.set_quality(i))
	var other: HBoxContainer = HBoxContainer.new()
	home.add_child(other)
	_button(other, "controls", "Controls", func() -> void: show_page("controls"))
	_button(other, "about", "About", func() -> void: show_page("about"))
	_button(other, "performance", "Performance", func() -> void: show_page("benchmark"))

	var benchmark: VBoxContainer = _page(column, "benchmark")
	_label(benchmark, "AUTO: <4 threads: 2 workers · 4–11: 4 workers · 12+: 6 workers", 15)
	_label(benchmark, "Compatibility builds use one worker. Tests do not change Auto.", 14)
	var run_row: HBoxContainer = HBoxContainer.new()
	benchmark.add_child(run_row)
	_button(run_row, "benchmark_run", "Benchmark", func() -> void: host.start_benchmark(false))
	_button(run_row, "stress_run", "Stress test", func() -> void: host.start_benchmark(true))
	_button(run_row, "benchmark_cancel", "Cancel", func() -> void: host.benchmark_cancelled = true)
	benchmark_text = TextEdit.new()
	benchmark_text.editable = false
	benchmark_text.custom_minimum_size = Vector2(704, 250)
	benchmark_text.add_theme_font_size_override("font_size", 14)
	benchmark_text.text = "Benchmark: compare 1, 2, 4 and 6 workers on two workloads.\nStress test: 600 measured ticks on a dense 960×960 world.\n\nYour game stays paused and unchanged.\nResults show simulation time and test frame intervals.\nEach workload has a two-minute time limit. Cancel or press Esc to stop."
	benchmark.add_child(benchmark_text)
	_button(benchmark, "benchmark_copy", "Copy results", func() -> void:
		if not host.benchmark_result.is_empty():
			benchmark_text.text = JSON.stringify(host.benchmark_result, "  ")
			benchmark_text.grab_focus()
			benchmark_text.select_all()
			if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
				DisplayServer.clipboard_set(benchmark_text.text)
	)
	_button(benchmark, "benchmark_back", "Back", func() -> void: show_page("home"))
	set_benchmark_busy(false)

	var save: VBoxContainer = _page(column, "save")
	_label(save, "LOCAL SLOT", 14)
	var local: HBoxContainer = HBoxContainer.new()
	save.add_child(local)
	_button(local, "save_slot", "Save Slot", func() -> void: host.save_slot())
	_button(local, "load_slot", "Load Slot", func() -> void: host.load_slot())
	_label(save, "PORTABLE / CYSD1 BASE64", 14)
	save_text = TextEdit.new()
	save_text.name = "PortableSave"
	save_text.custom_minimum_size = Vector2(704, 220)
	save_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	save_text.placeholder_text = "Export a level here, or paste a CYSD1 save."
	save_text.add_theme_font_size_override("font_size", 14)
	save.add_child(save_text)
	var portable: HBoxContainer = HBoxContainer.new()
	save.add_child(portable)
	_button(portable, "export", "Export Current", func() -> void: host.export_save())
	_button(portable, "import", "Import", func() -> void: host.import_save(save_text.text))
	_button(portable, "copy", "Copy", _copy_save)
	_button(portable, "clear", "Clear", func() -> void: save_text.text = "")
	_button(save, "save_back", "Back", func() -> void: show_page("home"))

	var controls: VBoxContainer = _page(column, "controls")
	_label(controls, "A / D    Move        SPACE    Jetpack\nARROWS   Pan         F        Follow / free camera\nLMB      Paint       RMB      Erase\n1–6      Quick materials     Q / E    Cycle materials\nC        Calm / spray        T        Surface adhesion\nX        Blast at pointer    P        Pause\nG        Glow                F3       Statistics\nR        Restart world       ESC      Menu", 18)
	_button(controls, "controls_back", "Back", func() -> void: show_page("home"))
	var about: VBoxContainer = _page(column, "about")
	var description: Label = _label(about, "M11 technical demonstrator.\n\nThe existing C++ cellular solver runs as WebAssembly.\nGodot owns the display, controls, and sampled character.\n\nSaves reconstruct level state, not exact replay state.\nLocal browser storage may be cleared; keep a portable copy.\n\nNo accounts. No telemetry. No backend.\nThird-party notices accompany this export.", 18)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(about, "about_back", "Back", func() -> void: show_page("home"))
	notice = _label(column, "", 15)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 22
	show_page("home")

func show_page(id: String) -> void:
	if host != null and host.benchmark_running and id != "benchmark":
		return
	open = true
	overlay.show()
	for key: String in pages:
		pages[key].visible = key == id
	if host != null:
		host.release_game_input()
	if notice != null:
		notice.text = ""

func close_menu() -> void:
	if host == null or not host.ready_to_play or host.benchmark_running:
		return
	open = false
	overlay.hide()
	host.release_game_input()
	get_viewport().gui_release_focus()

func message(text: String) -> void:
	if notice != null:
		notice.text = text

func _copy_save() -> void:
	save_text.grab_focus()
	save_text.select_all()
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(save_text.text)
	message("Text selected. Use Ctrl+C if the browser blocks clipboard access.")

func test_rects() -> Dictionary:
	var result: Dictionary = {}
	for key: String in buttons:
		var button: Button = buttons[key]
		if button.is_visible_in_tree() and not button.disabled:
			var rect: Rect2 = button.get_global_rect()
			result[key] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	return result

func set_benchmark_busy(busy: bool) -> void:
	for id: String in ["benchmark_run", "stress_run", "benchmark_copy", "benchmark_back"]:
		buttons[id].disabled = busy
	buttons["benchmark_cancel"].disabled = not busy
