extends Node

## Dedicated developer scene. It is absent from the production launcher.
const Controller = preload("res://goblin/goblin_controller.gd")
const Fixtures = preload("res://goblin/goblin_fixtures.gd")
const Policy = preload("res://goblin/goblin_policy.gd")

class GoblinPointer extends Control:
	var campaign: Node
	var target := Vector2(60, 60)
	var position_on_canvas := Vector2(70, 150)
	var has_target := false
	var failed := false
	var overlays := false
	var trajectory: Array[Vector2] = []
	var edit_regions: Array[Rect2] = []
	func observe(row: Dictionary) -> void:
		var after: Dictionary = row.get("after", {})
		for actor: Dictionary in after.get("actors", []):
			if int(actor.get("id", -1)) == int(after.get("pilot_actor", -2)) and actor.get("observed", false):
				var point := Vector2(float(actor.position[0]), float(actor.position[1]))
				if trajectory.is_empty() or point.distance_squared_to(trajectory.back()) > 0.25:
					trajectory.append(point)
					if trajectory.size() > 128: trajectory.pop_front()
		var capture: Dictionary = row.get("capture_after", {})
		var region: Array = capture.get("region", [])
		if row.get("status") in ["completed", "partial"] and int(row.get("native_receipt", {}).get("applied", 0)) > 0 and region.size() == 4:
			edit_regions.append(Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3])))
			if edit_regions.size() > 32: edit_regions.pop_front()
	func screen_point(cell: Vector2) -> Vector2:
		var host: Control = campaign.adapter.host
		var area: Rect2 = host.view_content_rect()
		return area.position + (cell - host.camera_origin) * area.size / Vector2(host.current_view_size)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func show_action(action: Dictionary) -> void:
		var args: Dictionary = action.get("args", {})
		if args.has("x") and args.has("y") and action.id != "camera":
			target = Vector2(float(args.x), float(args.y))
			has_target = true
		elif args.has("x0"):
			target = Vector2(float(args.x0 + args.x1) / 2.0, float(args.y0 + args.y1) / 2.0)
			has_target = true
		else:
			has_target = false
		failed = false
	func _process(delta: float) -> void:
		if campaign == null or campaign.adapter == null or campaign.adapter.host == null: return
		var host: Control = campaign.adapter.host
		var cell := target
		var observation: Dictionary = campaign.latest_observation
		if not has_target:
			for actor: Dictionary in observation.get("actors", []):
				if int(actor.id) == int(observation.get("pilot_actor", -1)) and actor.get("observed", false):
					cell = Vector2(float(actor.position[0]), float(actor.position[1]))
		var area: Rect2 = host.view_content_rect()
		var desired: Vector2 = area.position + (cell - host.camera_origin) * area.size / Vector2(host.current_view_size)
		desired.x = clampf(desired.x, 24, get_viewport_rect().size.x - 24)
		desired.y = clampf(desired.y - 26, 52, get_viewport_rect().size.y - 28)
		position_on_canvas = position_on_canvas.lerp(desired, minf(1.0, delta * 12.0))
		queue_redraw()
	func _draw() -> void:
		if campaign == null or campaign.adapter == null: return
		if overlays and campaign.adapter.host != null:
			for index: int in range(1, trajectory.size()):
				draw_line(screen_point(trajectory[index - 1]), screen_point(trajectory[index]), Color(0.4, 0.85, 1.0, 0.5), 1.5)
			for region: Rect2 in edit_regions:
				var first := screen_point(region.position)
				draw_rect(Rect2(first, screen_point(region.end) - first), Color(0.8, 1.0, 0.4, 0.4), false, 1.0)
		var p := position_on_canvas + Vector2(0, sin(Time.get_ticks_msec() * 0.005) * 2.0)
		var green := Color("f4aa74") if failed else Color("b1ec71")
		draw_circle(p + Vector2(0, 2), 14, Color(0.02, 0.04, 0.03, 0.8))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -4), p + Vector2(-21, -13), p + Vector2(-15, 5)]), green)
		draw_colored_polygon(PackedVector2Array([p + Vector2(8, -4), p + Vector2(21, -13), p + Vector2(15, 5)]), green)
		draw_circle(p, 12, green)
		draw_circle(p + Vector2(-5, -2), 2.5, Color("18332b"))
		draw_circle(p + Vector2(5, -2), 2.5, Color("18332b"))
		draw_line(p + Vector2(-4, 5), p + Vector2(4, 5), Color("18332b"), 2)
		draw_line(p + Vector2(2, 5), p + Vector2(2, 9), Color.WHITE, 2)
		if has_target: draw_line(p + Vector2(0, 15), p + Vector2(0, 23), green, 2)

var controller: Node
var launch: Dictionary = {}
var last_tape: Dictionary = {}
var fixture: OptionButton
var personality: OptionButton
var seed_value: SpinBox
var action_budget: SpinBox
var pacing: SpinBox
var start_button: Button
var pause_button: Button
var stop_button: Button
var replay_button: Button
var step_button: Button
var reduce_button: Button
var reproduction_button: Button
var reuse_memory: CheckBox
var overlay_toggle: CheckBox
var coverage_label: RichTextLabel
var novelty_label: Label
var clock_label: Label
var personality_label: Label
var memory_label: RichTextLabel
var finding_list: ItemList
var classification: OptionButton
var review_note: LineEdit
var findings_status: Label
var memory_buttons: Array[Button] = []
var tab_container: TabContainer
var _refresh_clock := 0.0
var _finding_ids: Array[String] = []
var panel: PanelContainer
var state_label: Label
var goal_label: Label
var observation_label: Label
var history_label: RichTextLabel
var export_label: Label
var pointer: GoblinPointer
var recent: Array[String] = []


func _ready() -> void:
	launch = Controller.read_launch()
	controller = Controller.new()
	add_child(controller)
	_make_ui()
	controller.changed.connect(_refresh)
	controller.action_started.connect(pointer.show_action)
	controller.action_observed.connect(_observed)
	controller.finished.connect(_finished)
	if not launch.get("ok", false):
		state_label.text = "Launch refused"
		goal_label.text = str(launch.get("error", "isolated profile required"))
		start_button.disabled = true
		return
	var config: Dictionary = launch.launch
	fixture.select(maxi(0, Fixtures.ids().find(config.get("fixture_id", "material_playground"))))
	personality.select(maxi(0, Policy.PERSONALITIES.find(config.get("policy", "WANDERER"))))
	seed_value.value = int(config.get("seed", 13))
	action_budget.value = int(config.get("budget", 64))
	pacing.value = maxi(100, int(config.get("pacing_ms", 150)))
	goal_label.text = "Start a campaign to mount the real Workbench in this disposable profile."
	_refresh()


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	pointer = GoblinPointer.new()
	pointer.campaign = controller
	layer.add_child(pointer)
	panel = PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -420
	panel.offset_right = -18
	panel.offset_top = 18
	panel.offset_bottom = -18
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(380, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152720")
	style.border_color = Color("729a60")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "goblin / experimental playtester"
	heading.add_theme_font_size_override("font_size", 19)
	heading.add_theme_color_override("font_color", Color("b1ec71"))
	column.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "Real Workbench · disposable test profile"
	subtitle.add_theme_font_size_override("font_size", 13)
	column.add_child(subtitle)
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tab_container)
	var play := _tab("Play")
	fixture = OptionButton.new()
	for id: String in Fixtures.ids(): fixture.add_item(str(Fixtures.describe(id).label))
	play.add_child(fixture)
	personality = OptionButton.new()
	for id: String in Policy.PERSONALITIES: personality.add_item(str(Policy.describe(id).get("label", id)))
	play.add_child(personality)
	personality.item_selected.connect(func(_index: int) -> void: _refresh())
	personality_label = _text(play, "", 12)
	var grid := GridContainer.new()
	grid.columns = 2
	play.add_child(grid)
	seed_value = _number(grid, "Seed", -2147483648, 2147483647, 13)
	action_budget = _number(grid, "Action budget", 1, 1024, 64)
	pacing = _number(grid, "Pacing (ms)", 0, 3000, 150)
	var buttons := HBoxContainer.new()
	play.add_child(buttons)
	start_button = _button(buttons, "Start", _start)
	pause_button = _button(buttons, "Pause", controller.pause_decisions)
	step_button = _button(buttons, "Step", _step)
	stop_button = _button(buttons, "Stop", controller.stop)
	replay_button = _button(play, "Replay previous campaign", _replay)
	replay_button.disabled = true
	reuse_memory = CheckBox.new()
	reuse_memory.text = "Reuse matching memory (new personalities)"
	reuse_memory.tooltip_text = "Successor personalities can propose a matching authored prefix. The original six remain unchanged comparators. Imported records are unverified hints."
	play.add_child(reuse_memory)
	overlay_toggle = CheckBox.new()
	overlay_toggle.text = "Observed trajectory and edit overlays"
	overlay_toggle.toggled.connect(func(value: bool) -> void: pointer.overlays = value)
	play.add_child(overlay_toggle)
	state_label = _text(play, "idle", 16)
	state_label.custom_minimum_size.x = 330
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label = _text(play, "", 14)
	goal_label.custom_minimum_size.x = 330
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	observation_label = _text(play, "", 13)
	observation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clock_label = _text(play, "", 12)
	history_label = RichTextLabel.new()
	history_label.custom_minimum_size = Vector2(330, 135)
	history_label.scroll_following = true
	history_label.add_theme_font_size_override("normal_font_size", 12)
	play.add_child(history_label)
	export_label = _text(column, "Transcripts export automatically after each action.", 12)
	export_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := _text(play, "The pointer marks goblin's intended tool target or observed pilot. Blue trails and green boxes show actual observations. Pause holds decisions; Step admits one; Stop drains input and pauses the scene.", 12)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_make_discovery_tab()
	_make_memory_tab()
	var guide := _tab("Guide")
	_text(guide, "A disposable in-game QA laboratory", 18)
	_text(guide, "Choose a scenario and personality, set a seed and finite budget, then press Start. Each campaign installs a fresh authored fixture. Different policies share the same real Workbench adapters.", 14)
	_text(guide, "Coverage is credited from actual admitted observations. Native ticks, actor ticks, action count and wall-clock elapsed time remain separate. A novel or refused action is not automatically a bug.", 14)
	_text(guide, "Reduction repeats the recorded target from a fresh authored start before removing spans. Its interactive limit is 128 actions and 12 probes; longer cases use the source tool. Reproduced failures still need independent engineering review.", 14)
	_text(guide, "Memory is isolated from owner saves. Import reads the fixed corpus staged by the launcher. Export writes a bounded portable record. Retained prefixes can be reused only with matching fixture/source/runtime identity; asynchronous physical state is never resumed.", 14)
	_text(guide, "Draft / HOLD. Optional AMBIENT, ObjectShard, Strata, Materials Lab, Gentek and Art adapters remain unavailable unless a real versioned capability is supplied.", 14)
	var collapse := Button.new()
	collapse.text = "goblin"
	collapse.position = Vector2(12, 12)
	collapse.pressed.connect(func() -> void: panel.visible = not panel.visible)
	layer.add_child(collapse)


func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_container.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	return column


func _make_discovery_tab() -> void:
	var column := _tab("Discovery")
	novelty_label = _text(column, "No admitted gameplay observations yet.", 14)
	coverage_label = RichTextLabel.new()
	coverage_label.custom_minimum_size = Vector2(320, 220)
	column.add_child(coverage_label)
	_text(column, "Interesting observation queue", 16)
	finding_list = ItemList.new()
	finding_list.custom_minimum_size = Vector2(320, 155)
	finding_list.item_selected.connect(_finding_selected)
	column.add_child(finding_list)
	findings_status = _text(column, "Triage is separate from independent defect confirmation.", 12)
	classification = OptionButton.new()
	for category: String in Controller.Findings.CLASSIFICATIONS:
		if not category.begins_with("confirmed_"): classification.add_item(category.replace("_", " "))
	column.add_child(classification)
	review_note = LineEdit.new()
	review_note.placeholder_text = "Brief review note for this observation"
	review_note.max_length = 1000
	column.add_child(review_note)
	_button(column, "Record triage", _classify)
	reduce_button = _button(column, "Reproduce and reduce previous tape", _reduce)
	reproduction_button = _button(column, "Export reproduction bundle", _export_reproduction)


func _make_memory_tab() -> void:
	var column := _tab("Memory")
	_text(column, "Bounded experiment corpus", 18)
	memory_label = RichTextLabel.new()
	memory_label.custom_minimum_size = Vector2(320, 300)
	column.add_child(memory_label)
	memory_buttons.append(_button(column, "Export memory", _export_memory))
	memory_buttons.append(_button(column, "Import staged corpus", _import_memory))
	memory_buttons.append(_button(column, "Clear experimental memory", _clear_memory))
	_text(column, "Only fixed marked test files are read or written. The corpus stores authored action prefixes and observation identities; it contains no shell commands, arbitrary paths or full physical checkpoints.", 13)


func _number(parent: Node, title: String, low: float, high: float, initial: float) -> SpinBox:
	_text(parent, title, 13)
	var number := SpinBox.new()
	number.min_value = low
	number.max_value = high
	number.step = 1
	number.value = initial
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(number)
	return number


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _text(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _start() -> void:
	if controller.running or controller.maintenance_running or not launch.get("ok", false): return
	recent.clear()
	pointer.trajectory.clear()
	pointer.edit_regions.clear()
	controller.reduction_result.clear()
	var config := {"fixture_id": Fixtures.ids()[fixture.selected], "policy": Policy.PERSONALITIES[personality.selected],
		"seed": int(seed_value.value), "budget": int(action_budget.value), "pacing_ms": int(pacing.value),
		"evidence_kind": "graphical_godot", "reuse_memory": reuse_memory.button_pressed}
	var result: Dictionary = await controller.run_campaign(config, launch.provenance)
	_show_refusal(result)


func _replay() -> void:
	if controller.running or controller.maintenance_running or last_tape.is_empty(): return
	var replay: Dictionary = last_tape.duplicate(true)
	controller.reduction_result.clear()
	recent.clear()
	var result: Dictionary = await controller.run_campaign({"pacing_ms": int(replay.header.get("pacing_ms", 0)), "evidence_kind": "graphical_godot"}, launch.provenance, replay)
	_show_refusal(result)


func _show_refusal(result: Dictionary) -> void:
	if result.has("error") and not result.has("schema"):
		state_label.text = "Campaign refused"
		goal_label.text = str(result.error)


func _observed(row: Dictionary) -> void:
	recent.append("%03d  %s · %s" % [int(row.index) + 1, str(row.action.id), str(row.status)])
	if recent.size() > 8: recent.pop_front()
	history_label.text = "\n".join(recent)
	pointer.failed = row.assertions.any(func(item: Dictionary) -> bool: return item.status == "fail")
	pointer.observe(row)


func _finished(tape: Dictionary) -> void:
	if not controller.maintenance_running: last_tape = tape.duplicate(true)
	export_label.text = "Saved transcript: " + controller.export_path if not controller.export_path.is_empty() else "Evidence export failed: " + controller.last_error
	replay_button.disabled = tape.get("steps", []).is_empty()
	_refresh()


func _refresh() -> void:
	if state_label == null: return
	var busy: bool = controller.running or controller.maintenance_running
	start_button.disabled = busy or not launch.get("ok", false)
	pause_button.disabled = not controller.running
	pause_button.text = "Resume" if controller.decisions_paused else "Pause"
	stop_button.disabled = not busy
	step_button.disabled = not controller.running
	replay_button.disabled = busy or last_tape.is_empty()
	fixture.disabled = busy
	personality.disabled = busy
	seed_value.editable = not busy
	action_budget.editable = not busy
	pacing.editable = not busy
	var baseline: bool = Policy.PERSONALITIES[personality.selected] in Policy.BASELINE_PERSONALITIES
	reuse_memory.disabled = busy or baseline
	if baseline: reuse_memory.button_pressed = false
	reduce_button.disabled = busy or last_tape.get("steps", []).is_empty() or last_tape.get("steps", []).size() > 128
	reproduction_button.disabled = busy or last_tape.is_empty()
	for button: Button in memory_buttons: button.disabled = busy
	personality_label.text = str(Policy.describe(Policy.PERSONALITIES[personality.selected]).get("description", ""))
	state_label.text = "%s · %d completed / %d attempted / %d budget" % [controller.state, controller.completed, controller.attempted, controller.budget]
	goal_label.text = controller.goal
	var seen: Dictionary = controller.latest_observation
	if not seen.is_empty():
		var native: Dictionary = seen.get("native", {})
		observation_label.text = "Latest: %s\nNative tick %s · revision %s · actor tick %s\n%s · material %s" % [
			controller.latest_action, str(native.get("tick", "—")), str(native.get("revision", "—")),
			str(seen.get("actor_tick", "—")), "Paused" if seen.get("paused", true) else "Playing", str(seen.get("material", "—"))]
	_refresh_discovery()
	_refresh_clocks()


func _process(delta: float) -> void:
	_refresh_clock += delta
	if _refresh_clock >= 0.25:
		_refresh_clock = 0.0
		_refresh_clocks()


func _refresh_clocks() -> void:
	if controller == null or clock_label == null: return
	var clocks: Dictionary = controller.clock_summary()
	clock_label.text = "Real elapsed %.1fs · pacing %.1fs · decision pause %.1fs\nAction count %d · native/actor clocks shown above" % [
		float(clocks.real_elapsed_msec) / 1000.0, float(clocks.pacing_msec) / 1000.0,
		float(clocks.decision_pause_msec) / 1000.0, int(clocks.action_count)]


func _refresh_discovery() -> void:
	if coverage_label == null: return
	var discovery: Dictionary = controller.discovery_summary()
	var unique: Dictionary = discovery.coverage.get("unique", {})
	var lines: Array[String] = ["Observed coverage"]
	for dimension: String in unique:
		lines.append("%s: %d" % [dimension.replace("_", " ").capitalize(), int(unique[dimension])])
	lines.append("\nCompleted, partial and refused outcomes remain distinct.")
	coverage_label.text = "\n".join(lines)
	var intention: Dictionary = discovery.get("intention", {})
	novelty_label.text = "Novelty %d · intention %s\n%d observations awaiting review" % [int(discovery.novelty.get("score", 0)),
		str(intention.get("id", "none")).replace("_", " "), int(discovery.findings.get("records", 0))]
	var selected_id := ""
	if not finding_list.get_selected_items().is_empty():
		var selected: int = finding_list.get_selected_items()[0]
		if selected < _finding_ids.size(): selected_id = _finding_ids[selected]
	finding_list.clear()
	_finding_ids.clear()
	for item: Dictionary in controller.findings.records:
		_finding_ids.append(str(item.id))
		finding_list.add_item("%d:%03d %s · %s" % [int(item.run_serial), int(item.step) + 1, str(item.action), str(item.classification).replace("_", " ")])
	if selected_id in _finding_ids: finding_list.select(_finding_ids.find(selected_id))
	var memory: Dictionary = discovery.memory
	memory_label.text = "%s\n\n%d / %d records\n%d reusable authored prefixes\n%d imported unverified records\n%d observations processed\n%d records evicted\n\nClassifications\n%s\n\nNo physical checkpoint resume." % [
		str(discovery.corpus_status), int(memory.get("records", 0)), int(memory.get("capacity", 64)),
		int(memory.get("reusable_prefixes", 0)), int(memory.get("imported_unverified", 0)), int(memory.get("total_observed", 0)),
		int(memory.get("evicted", 0)), JSON.stringify(memory.get("classifications", {}), "  ")]


func _step() -> void:
	controller.step_decision()


func _finding_selected(index: int) -> void:
	if index < 0 or index >= controller.findings.records.size(): return
	var item: Dictionary = controller.findings.records[index]
	findings_status.text = "%s\n%s\nFailed invariants: %s" % [str(item.adjudication), str(item.reason), ", ".join(item.failed_invariants)]
	var selected := str(item.classification).replace("_", " ")
	for choice: int in range(classification.item_count):
		if classification.get_item_text(choice) == selected: classification.select(choice)
	review_note.text = str(item.review_note)


func _classify() -> void:
	if controller.running or controller.maintenance_running: return
	var selected := finding_list.get_selected_items()
	if selected.is_empty():
		findings_status.text = "Select an observed record first."
		return
	var result: Dictionary = controller.findings.classify(_finding_ids[selected[0]],
		classification.get_item_text(classification.selected).replace(" ", "_"), review_note.text)
	findings_status.text = "Triage recorded." if result.get("ok", false) else str(result.get("error", "refused"))
	if result.get("ok", false): controller._write_fixed(Controller.FINDINGS_PATH, controller.findings.export_data())
	_refresh_discovery()


func _reduce() -> void:
	if controller.running or controller.maintenance_running or last_tape.is_empty(): return
	var original := last_tape.duplicate(true)
	var result: Dictionary = await controller.reduce_tape(original, launch.provenance)
	last_tape = original
	findings_status.text = "Reduction: %s" % str(result.get("status", result.get("error", "unknown")))
	_refresh()


func _export_reproduction() -> void:
	var result: Dictionary = controller.export_reproduction(last_tape, controller.reduction_result.get("reduced_tape", {}))
	export_label.text = "Reproduction: " + str(result.get("path", "")) if result.get("ok", false) else str(result.get("error", "export failed"))


func _export_memory() -> void:
	var result: Dictionary = controller.export_memory()
	export_label.text = "Memory: " + str(result.get("path", "")) if result.get("ok", false) else str(result.get("error", "export failed"))


func _import_memory() -> void:
	var result: Dictionary = controller.import_memory()
	export_label.text = str(controller.corpus_status) if result.get("ok", false) else str(result.get("error", "import refused"))
	_refresh()


func _clear_memory() -> void:
	var result: Dictionary = controller.clear_memory()
	export_label.text = str(controller.corpus_status) if result.get("ok", false) else str(result.get("error", "clear refused"))
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and controller != null:
		controller.stop()
