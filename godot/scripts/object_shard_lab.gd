extends Control

const Session = preload("res://scripts/object_shard_lab_session.gd")
const View = preload("res://scripts/object_shard_lab_view.gd")
const SCENARIOS: Array[String] = ["A · Ordinary detachment", "B · Burning Wood tree", "C · Water and Sand exchange", "D · Three independent shards"]
const BRUSHES: Array[String] = ["Erase", "Ignite", "Sand", "Water", "Wood", "Inspect"]
const MATERIALS: Array[int] = [0, 6, 2, 3, 7, -1]
const ADMITTED_MATERIAL_NAMES: Dictionary = {0: "Empty", 1: "Wall", 2: "Sand", 3: "Water", 4: "Smoke", 6: "Fire", 7: "Wood"}
const INSPECTION_HINT: String = "Inspect a cell to see its actual owner, material, burn state and temperature."

var session: CyberObjectShardLabSession
var canvas: CyberObjectShardLabView
var scenario_select: OptionButton
var brush_select: OptionButton
var pause_button: Button
var overlay_toggle: CheckButton
var status_label: Label
var subtitle_label: Label
var inventory_label: RichTextLabel
var inspection_label: RichTextLabel
var help_label: Label
var last_presentation_usec: int = 0
var _frame_counter: int = 0


func _ready() -> void:
	get_window().title = "CyberSand · ObjectShard Lab · Draft / HOLD"
	get_window().size = Vector2i(1280, 840)
	get_window().min_size = Vector2i(960, 640)
	get_window().content_scale_size = Vector2i(1280, 840)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_build_interface()
	session = Session.new()
	_open(1)
	set_physics_process(true)


func _exit_tree() -> void:
	if session != null:
		session.close()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("0c121b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "OBJECTSHARD LAB"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("b2e2e8"))
	layout.add_child(title)
	subtitle_label = Label.new()
	subtitle_label.text = "Source-bound experimental material runtime · Draft / HOLD"
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color("a5b5c5"))
	layout.add_child(subtitle_label)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	layout.add_child(toolbar)
	scenario_select = OptionButton.new()
	for text: String in SCENARIOS:
		scenario_select.add_item(text)
	scenario_select.custom_minimum_size.x = 250
	scenario_select.item_selected.connect(func(index: int) -> void: _open(index + 1))
	toolbar.add_child(scenario_select)
	pause_button = _button(toolbar, "Resume", _toggle_pause)
	_button(toolbar, "Single step", _single_step)
	_button(toolbar, "Reset", func() -> void: _open(scenario_select.selected + 1))
	_button(toolbar, "Erase lower Wood band", _erase_lower_band)
	_button(toolbar, "Export result", _export)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	layout.add_child(tools)
	var brush_label := Label.new()
	brush_label.text = "Left drag:"
	tools.add_child(brush_label)
	brush_select = OptionButton.new()
	for text: String in BRUSHES:
		brush_select.add_item(text)
	tools.add_child(brush_select)
	var pointer_label := Label.new()
	pointer_label.text = "Right click inspects exact inventory."
	pointer_label.add_theme_color_override("font_color", Color("a5b5c5"))
	tools.add_child(pointer_label)
	overlay_toggle = CheckButton.new()
	overlay_toggle.text = "Shapes / centre of mass / pocket"
	overlay_toggle.toggled.connect(func(value: bool) -> void: canvas.overlays = value; canvas.queue_redraw())
	tools.add_child(overlay_toggle)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	layout.add_child(body)
	canvas = View.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.cell_pressed.connect(_cell_pressed)
	body.add_child(canvas)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 285
	side.add_theme_constant_override("separation", 12)
	body.add_child(side)
	var side_title := Label.new()
	side_title.text = "MATERIAL OWNERSHIP"
	side_title.add_theme_color_override("font_color", Color("b2e2e8"))
	side.add_child(side_title)
	inventory_label = RichTextLabel.new()
	inventory_label.bbcode_enabled = true
	inventory_label.fit_content = false
	inventory_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_label.custom_minimum_size = Vector2(285, 220)
	inventory_label.add_theme_font_size_override("normal_font_size", 14)
	side.add_child(inventory_label)
	inspection_label = RichTextLabel.new()
	inspection_label.bbcode_enabled = true
	inspection_label.fit_content = false
	inspection_label.custom_minimum_size = Vector2(285, 110)
	inspection_label.add_theme_font_size_override("normal_font_size", 13)
	inspection_label.text = INSPECTION_HINT
	side.add_child(inspection_label)
	var scope := Label.new()
	scope.text = "This slice keeps disconnected islands\nin one compound (split_pending).\n\nNo general fracture, internal fluid\nsolver, or durable save/restore."
	scope.add_theme_font_size_override("font_size", 13)
	scope.add_theme_color_override("font_color", Color("93a2b4"))
	side.add_child(scope)
	help_label = Label.new()
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.custom_minimum_size.y = 48
	help_label.add_theme_font_size_override("font_size", 14)
	layout.add_child(help_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("7fd4b0"))
	layout.add_child(status_label)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _open(scenario: int) -> void:
	if session == null:
		return
	var result: Dictionary = session.open(scenario, 12)
	if session.native != null:
		var milestone: int = int(session.native.capabilities().get("implemented_milestone", 0))
		var summaries: Array[String] = ["M0 · native ownership transfer and Rapier motion",
			"M1 · native ownership, motion and continuing selected chemistry",
			"M2 · moving native material, continuing chemistry and bounded real exchange"]
		subtitle_label.text = summaries[clampi(milestone, 0, 2)] + "     /     Draft / HOLD"
		for index: int in range(1, SCENARIOS.size()):
			scenario_select.set_item_disabled(index, milestone < (1 if index == 1 else 2))
	pause_button.text = "Resume"
	if not result.get("ok", false):
		status_label.text = session.status
		return
	scenario_select.select(scenario - 1)
	inspection_label.text = INSPECTION_HINT
	inspection_label.scroll_to_line(0)
	inventory_label.scroll_to_line(0)
	var hints: Array[String] = [
		"A · Erase through a Wood support, then Resume. Discovery uses ordinary committed material changes. The freed inventory becomes one Rapier body.",
		"B · The genuine Wood tree begins burning. Resume, then remove its lower support. Inspect Wood state_b before and after promotion; emitted Fire remains native material.",
		"C · Detach the pocket structure. Place Sand over the green pocket and Water against burning Wood. Cargo and Water exposure are separate ownership operations.",
		"D · Three Wood structures have independent native identities. Remove their supports, ignite them and compare motion, products, geometry and accounting."
	]
	help_label.text = hints[scenario - 1]
	_present()


func _physics_process(_delta: float) -> void:
	if session == null or session.paused:
		return
	session.advance()
	_present()


func _toggle_pause() -> void:
	if session == null or session.failed:
		return
	session.paused = not session.paused
	pause_button.text = "Resume" if session.paused else "Pause"
	_present()


func _single_step() -> void:
	if session == null:
		return
	session.paused = true
	pause_button.text = "Resume"
	session.advance(true)
	_present()


func _erase_lower_band() -> void:
	if session == null or session.frame.is_empty():
		return
	# Discover the authored bottom Wood row from the actual native picture.
	# Each removal uses the ordinary edit API; this is not a cut/physics command.
	var width: int = int(session.frame.width)
	var height: int = int(session.frame.height)
	var cells: PackedByteArray = session.frame.world_materials
	var lowest: int = -1
	for y: int in range(height - 1, -1, -1):
		for x: int in range(width):
			if cells[y * width + x] == 7:
				lowest = y
				break
		if lowest >= 0:
			break
	if lowest >= 0:
		var edits: Array[Vector2i] = []
		for y: int in range(maxi(0, lowest - 11), lowest + 1):
			for x: int in range(width):
				if cells[y * width + x] == 7:
					edits.append(Vector2i(x, y))
		for position: Vector2i in edits:
			session.edit(position, 0)
	_present()


func _cell_pressed(position: Vector2i, button: int) -> void:
	if session == null:
		return
	if button == MOUSE_BUTTON_RIGHT or brush_select.selected == 5:
		inspection_label.text = _inspection_text(session.inspect(position))
		inspection_label.scroll_to_line(0)
		return
	if brush_select.selected == 1:
		var result: Dictionary = session.ignite(position)
		if not result.get("ok", false):
			inspection_label.text = "[b]Ignition refused[/b]\n" + str(result.get("outcome", "unknown"))
	else:
		var material: int = MATERIALS[brush_select.selected]
		var result: Dictionary = session.edit(position, material, 255 if material == 3 else 0)
		if not result.get("ok", false):
			inspection_label.text = "[b]World edit refused[/b]\n" + str(result.get("outcome", "unknown")) \
				+ "\nMoving inventory has its own native owner. Inspect or ignite that material."
	_present()


func _inspection_text(cell: Dictionary) -> String:
	if not cell.get("ok", false):
		return "[b]Inspection unavailable[/b]\n" + JSON.stringify(cell, "  ")
	var material: int = int(cell.get("material", -1))
	var material_name: String = str(cell.get("material_name", ADMITTED_MATERIAL_NAMES.get(material, "Material %d" % material))).capitalize()
	var owner: String = str(cell.get("owner", "unknown"))
	if owner == "ObjectShard":
		owner += " %d · cell %d" % [int(cell.id), int(cell.cell)]
	return "[b]%s[/b] · %s\nstate_a %d · state_b %d\ntemperature %d · incarnation %d\n\n[b]Exact cell[/b]\n%s" % [
		material_name, owner, int(cell.get("state_a", 0)), int(cell.get("state_b", 0)),
		int(cell.get("temperature", 0)), int(cell.get("incarnation", 0)), JSON.stringify(cell, "  ")]


func _present() -> void:
	if session == null or session.frame.is_empty():
		return
	var started: int = Time.get_ticks_usec()
	var poses: Array = session.bridge.sample_poses() if session.bridge != null else []
	canvas.present(session.frame, poses)
	overlay_toggle.set_pressed_no_signal(canvas.overlays)
	status_label.text = session.status
	if session.failed:
		status_label.add_theme_color_override("font_color", Color("ff9b89"))
		pause_button.text = "Held · reset required"
	else:
		status_label.add_theme_color_override("font_color", Color("7fd4b0"))
	var text: String = "Session %d · tick %d\n" % [int(session.frame.session), int(session.frame.tick)]
	var capabilities: Dictionary = session.native.capabilities()
	text += "M%d · capability v%d\n" % [int(capabilities.get("implemented_milestone", 0)), int(capabilities.get("version", 0))]
	text += "Chemistry %s · output %s\nSand lodging %s · Water contact %s\n" % [
		"yes" if capabilities.get("reaction", false) else "no", "yes" if capabilities.get("emission", false) else "no",
		"yes" if capabilities.get("ingestion", false) else "no", "yes" if capabilities.get("surface_contact", false) else "no"]
	if int(capabilities.get("transfer_budget_per_tick", 64)) == 0:
		text += "[color=#ffcf66]Transfer capacity zero · retain products[/color]\n"
	for shard: Dictionary in session.frame.get("shards", []):
		text += "\n[b]Shard %d[/b]  %s\n" % [int(shard.id), str(shard.lifecycle)]
		text += "Wood/structure %d · products %d\nSand cargo %d · shapes %d\n" % [
			int(shard.structural), int(shard.products), int(shard.cargo), shard.rectangles.size() / 4]
		text += "Material r%d · geometry r%d\n" % [int(shard.material_revision), int(shard.geometry_revision)]
		if shard.split_pending:
			text += "[color=#ffcf66]split_pending · one compound[/color]\n"
		if shard.get("ingress_fenced", false):
			text += "[color=#ffcf66]Pocket admission held until clear[/color]\n"
	var metrics: Dictionary = session.frame.get("metrics", {})
	text += "\n[b]Native events[/b]\nPromotions %d · products born %d\nSand ingested %d · output waits %d\n" % [
		int(metrics.get("promotions", 0)), int(metrics.get("products_created", 0)),
		int(metrics.get("sand_ingested", 0)), int(metrics.get("output_blocked", 0))]
	text += "Water extinctions %d\n" % int(session.frame.get("accounting", {}).get("extinguished", 0))
	text += "\nStep %.2f ms · peak %.2f ms\nPromotion max %.2f ms\n" % [
		float(session.last_frame_usec) / 1000.0, float(session.frame_max_usec) / 1000.0,
		float(session.promotion_max_usec) / 1000.0]
	inventory_label.text = text
	last_presentation_usec = Time.get_ticks_usec() - started
	_frame_counter += 1


func _export() -> void:
	if session == null:
		return
	var report: Dictionary = session.export_result()
	report["presentation_usec"] = last_presentation_usec
	report["render_upload_usec"] = canvas.upload_usec
	var directory: String = "user://objectshard-results"
	DirAccess.make_dir_recursive_absolute(directory)
	var name: String = "objectshard-%d-%d.json" % [int(session.frame.get("session", 0)), Time.get_unix_time_from_system()]
	var path: String = directory.path_join(name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status_label.text = "Result export failed: " + error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	status_label.text = "Saved " + ProjectSettings.globalize_path(path)
	OS.shell_open(ProjectSettings.globalize_path(directory))
