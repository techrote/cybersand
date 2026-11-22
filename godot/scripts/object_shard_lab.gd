extends Control

const Session = preload("res://scripts/object_shard_lab_session.gd")
const View = preload("res://scripts/object_shard_lab_view.gd")
const Presets = preload("res://scripts/object_shard_lab_presets.gd")
const Capture = preload("res://scripts/object_shard_capture.gd")
const SCENARIOS: Array[String] = Presets.TITLES
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
var burner_toggle: CheckButton
var capture_label: Label
var preset_number: int = 1
var automatically_reported_failure: bool = false
var loading_scene: bool = false
var load_serial: int = 0
var load_progress: Dictionary = {}
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
	session.capture_enabled = true
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
	_button(toolbar, "Export bug report / trace", _export)
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
	var experiments := HBoxContainer.new()
	experiments.add_theme_constant_override("separation", 10)
	layout.add_child(experiments)
	_button(experiments, "Erase lower Wood band", _erase_lower_band)
	_button(experiments, "Erode resting cell", _erode_resting_cell)
	burner_toggle = CheckButton.new()
	burner_toggle.text = "External Fire burner"
	burner_toggle.toggled.connect(func(value: bool) -> void:
		if session != null and not loading_scene:
			session.set_burner(Presets.burner_band(session.frame), value)
			_present())
	experiments.add_child(burner_toggle)
	capture_label = Label.new()
	capture_label.add_theme_font_size_override("font_size", 12)
	capture_label.add_theme_color_override("font_color", Color("a5b5c5"))
	experiments.add_child(capture_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	layout.add_child(body)
	canvas = View.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.cell_pressed.connect(_cell_pressed)
	canvas.stroke_requested.connect(_stroke_requested)
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
	load_serial += 1
	var request: int = load_serial
	loading_scene = true
	preset_number = scenario
	var preset: Dictionary = Presets.definition(scenario)
	var result: Dictionary = session.open(int(preset.scenario), int(preset.seed), {"width": preset.width, "height": preset.height})
	if result.get("ok", false):
		var operations: Array[Dictionary] = Presets.edits(preset)
		load_progress = {"completed": 0, "total": operations.size(), "per_frame_limit": 32}
		for offset: int in range(0, operations.size(), 32):
			var authored: Dictionary = session.author_cells(operations.slice(offset, offset + 32))
			if not authored.get("ok", false):
				session.status = "Scenario authoring refused: " + str(authored)
				result = authored
				break
			load_progress.completed = mini(offset + 32, operations.size())
			session.status = "Authoring native material %d / %d · paused · choose Reset or another scene to cancel" % [int(load_progress.completed), operations.size()]
			_present()
			await get_tree().process_frame
			if request != load_serial:
				return
		if bool(preset.burner):
			session.set_burner(Presets.burner_band(session.frame), true)
	loading_scene = false
	if result.get("ok", false):
		session.status = "Paused · native material ready · cut, inspect or Resume"
	automatically_reported_failure = false
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
	help_label.text = Presets.hint(scenario)
	_present()


func _physics_process(_delta: float) -> void:
	if session == null or loading_scene:
		return
	var edits: int = session.drain_edits()
	if not session.paused:
		session.advance()
	if edits > 0 or not session.paused or session.failed:
		_present()
	if session.failed and not automatically_reported_failure:
		automatically_reported_failure = true
		_save_report(false)


func _toggle_pause() -> void:
	if session == null or session.failed or loading_scene:
		return
	session.set_paused(not session.paused)
	pause_button.text = "Resume" if session.paused else "Pause"
	_present()


func _single_step() -> void:
	if session == null or loading_scene:
		return
	session.set_paused(true)
	pause_button.text = "Resume"
	session.advance(true)
	_present()


func _erase_lower_band() -> void:
	if session == null or session.frame.is_empty() or loading_scene:
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
		var refused: int = 0
		for position: Vector2i in edits:
			if not session.queue_edit(position, 0).get("ok", false):
				refused += 1
		if refused > 0:
			help_label.text = "Lower-band input: %d queued, %d refused by the bounded queue. Let it drain, then repeat; unqueued cells were not edited." % [edits.size() - refused, refused]
			session._event("BulkInputCapacity", {"requested": edits.size(), "queued": edits.size() - refused, "refused": refused})
	_present()


func _cell_pressed(position: Vector2i, button: int) -> void:
	if session == null or loading_scene:
		return
	if button == MOUSE_BUTTON_RIGHT or brush_select.selected == 5:
		inspection_label.text = _inspection_text(session.inspect(position))
		inspection_label.scroll_to_line(0)
		return
	if brush_select.selected == 1:
		var result: Dictionary = session.queue_edit(position, -2)
		if not result.get("ok", false):
			inspection_label.text = "[b]Ignition refused[/b]\n" + str(result.get("outcome", "unknown"))
	else:
		var material: int = MATERIALS[brush_select.selected]
		var result: Dictionary = session.queue_edit(position, material, 255 if material == 3 else 0)
		if not result.get("ok", false):
			inspection_label.text = "[b]Edit not queued[/b]\n" + str(result.get("outcome", "unknown")) + "\n" + str(result.get("detail", ""))
	_present()


func _stroke_requested(cells: Array[Vector2i], button: int) -> void:
	if session == null or button != MOUSE_BUTTON_LEFT or loading_scene:
		return
	if brush_select.selected == 5:
		if not cells.is_empty():
			inspection_label.text = _inspection_text(session.inspect(cells[-1]))
		return
	var material: int = -2 if brush_select.selected == 1 else MATERIALS[brush_select.selected]
	for position: Vector2i in cells:
		var result: Dictionary = session.queue_edit(position, material, 255 if material == 3 else 0)
		if not result.get("ok", false):
			inspection_label.text = "[b]Stroke admission[/b]\n" + str(result.get("outcome", "unknown"))
			break
	_present()


func _erode_resting_cell() -> void:
	if session == null or session.bridge == null or loading_scene:
		return
	for shard: Dictionary in session.frame.get("shards", []):
		if not session.bridge.bodies.has(int(shard.id)):
			continue
		var body: Dictionary = session.bridge.bodies[int(shard.id)]
		var sleeping: bool = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_SLEEPING)
		if not sleeping:
			continue
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		for at: int in range(shard.materials.size()):
			if int(shard.roles[at]) != 1:
				continue
			var point: Vector2 = pose * Vector2(float(at % int(shard.width)) + 0.5, float(at / int(shard.width)) + 0.5)
			var position := Vector2i(floori(point.x), floori(point.y))
			var actual: Dictionary = session.inspect(position)
			if int(actual.get("id", 0)) == int(shard.id) and int(actual.get("cell", -1)) == at:
				session.queue_edit(position, 0)
				inspection_label.text = "[b]Resting erosion queued[/b]\nShard %d · cell %d\nOne actual structural cell; Rapier remains authoritative." % [int(shard.id), at]
				return
	inspection_label.text = "[b]No sleeping body[/b]\nAllow a detached structure to settle naturally before this controlled erosion."


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
	canvas.fixture_cells = session.burner_cells
	canvas.fixture_enabled = session.burner_enabled
	burner_toggle.set_pressed_no_signal(session.burner_enabled)
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
	var admission: Dictionary = session.frame.get("admission", {})
	text += "Canvas %d×%d · slots %d/%d\nEligible %d · deferred %d\n" % [int(session.frame.width), int(session.frame.height),
		int(admission.get("slots_used", session.bridge.bodies.size())), int(admission.get("slot_limit", 3)),
		int(admission.get("eligible", 0)), int(admission.get("deferred", 0))]
	if not str(admission.get("reason", "")).is_empty():
		text += "[color=#ffcf66]%s[/color]\n" % str(admission.reason)
	text += "Discovery %d cells · pending %d\nQueued edits %d/%d · %d/frame\n" % [int(admission.get("work_last", 0)),
		int(admission.get("pending_seeds", 0)), session.pending_edits.size(), session.MAX_PENDING_EDITS, session.MAX_EDITS_PER_FRAME]
	var shown_candidates: int = 0
	for candidate: Dictionary in admission.get("candidates", []):
		if str(candidate.get("reason", "")) == "Anchored":
			continue
		text += "Candidate %d cells · %s\n" % [int(candidate.get("cells", 0)), str(candidate.get("reason", "unknown"))]
		shown_candidates += 1
		if shown_candidates >= 3:
			break
	if not session.last_edit_result.is_empty() and not session.last_edit_result.get("ok", true):
		text += "[color=#ffcf66]Edit: %s[/color]\n" % str(session.last_edit_result.get("outcome", "unknown"))
	text += "Chemistry %s · output %s\nSand lodging %s · Water contact %s\n" % [
		"yes" if capabilities.get("reaction", false) else "no", "yes" if capabilities.get("emission", false) else "no",
		"yes" if capabilities.get("ingestion", false) else "no", "yes" if capabilities.get("surface_contact", false) else "no"]
	if int(capabilities.get("transfer_budget_per_tick", 64)) == 0:
		text += "[color=#ffcf66]Transfer capacity zero · retain products[/color]\n"
	var physics_observation: Dictionary = session.bridge.diagnostics()
	for shard: Dictionary in session.frame.get("shards", []):
		text += "\n[b]Shard %d[/b]  %s\n" % [int(shard.id), str(shard.lifecycle)]
		text += "Wood/structure %d · products %d\nSand cargo %d · shapes %d\n" % [
			int(shard.structural), int(shard.products), int(shard.cargo), shard.rectangles.size() / 4]
		text += "Material r%d · geometry r%d\n" % [int(shard.material_revision), int(shard.geometry_revision)]
		for physical: Dictionary in physics_observation.get("bodies", []):
			if int(physical.id) == int(shard.id):
				text += "%s · ω %.3f rad/s\nMass %.0f · COM %.1f, %.1f\nContacts %d · installed r%d\n" % [
					"Sleeping" if physical.get("sleeping", false) else "Awake", float(physical.get("angular_velocity", 0)),
					float(physical.get("mass", 0)), float(physical.get("com_x", 0)), float(physical.get("com_y", 0)),
					int(physical.get("reported_contacts", 0)), int(physical.get("geometry_revision", 0))]
		if shard.split_pending:
			text += "[color=#ffcf66]split_pending · one compound[/color]\n"
		if shard.get("ingress_fenced", false):
			text += "[color=#ffcf66]Pocket admission held until clear[/color]\n"
	var metrics: Dictionary = session.frame.get("metrics", {})
	text += "\n[b]Native events[/b]\nPromotions %d · products born %d\nSand ingested %d · output waits %d\n" % [
		int(metrics.get("promotions", 0)), int(metrics.get("products_created", 0)),
		int(metrics.get("sand_ingested", 0)), int(metrics.get("output_blocked", 0))]
	text += "Water extinctions %d (owner accounting)\nFixture Fire authored %d\n" % [int(session.frame.get("accounting", {}).get("extinguished", 0)), session.authored_fixture_fire]
	text += "\nStep %.2f ms · peak %.2f ms\nPromotion max %.2f ms\n" % [
		float(session.last_frame_usec) / 1000.0, float(session.frame_max_usec) / 1000.0,
		float(session.promotion_max_usec) / 1000.0]
	inventory_label.text = text
	var capture_state: Dictionary = session.capture.metadata()
	capture_label.text = "Trace %.1f / 32 MiB" % (float(capture_state.bytes) / 1048576.0)
	if not capture_state.complete_prefix:
		capture_label.text = "Trace incomplete · export details"
	last_presentation_usec = Time.get_ticks_usec() - started
	_frame_counter += 1


func _export() -> void:
	_save_report(true)


func _save_report(open_folder: bool) -> void:
	if session == null:
		return
	var report: Dictionary = session.export_result()
	report["presentation_usec"] = last_presentation_usec
	report["render_upload_usec"] = canvas.upload_usec
	report["preset"] = Presets.definition(preset_number)
	report["scene_setup"] = {"in_progress": loading_scene, "progress": load_progress}
	var directory: String = "user://objectshard-results"
	DirAccess.make_dir_recursive_absolute(directory)
	var name: String = "objectshard-%d-%d.json" % [int(session.frame.get("session", 0)), Time.get_unix_time_from_system()]
	var path: String = directory.path_join(name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status_label.text = "Result export failed: " + error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(Capture.json_value(report), "  ") + "\n")
	file.close()
	status_label.text = "Saved " + ProjectSettings.globalize_path(path)
	if open_folder:
		OS.shell_open(ProjectSettings.globalize_path(directory))
