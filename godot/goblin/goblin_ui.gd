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
	var panel := PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(get_viewport().get_visible_rect().size.x - 390, 24)
	panel.custom_minimum_size = Vector2(366, 0)
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
	heading.text = "goblin / developer playtest"
	heading.add_theme_font_size_override("font_size", 21)
	heading.add_theme_color_override("font_color", Color("b1ec71"))
	column.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "Real Workbench · disposable test profile"
	subtitle.add_theme_font_size_override("font_size", 13)
	column.add_child(subtitle)
	fixture = OptionButton.new()
	for id: String in Fixtures.ids(): fixture.add_item(str(Fixtures.describe(id).label))
	column.add_child(fixture)
	personality = OptionButton.new()
	for id: String in Policy.PERSONALITIES: personality.add_item(id)
	column.add_child(personality)
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	seed_value = _number(grid, "Seed", -2147483648, 2147483647, 13)
	action_budget = _number(grid, "Action budget", 1, 256, 64)
	pacing = _number(grid, "Pacing (ms)", 0, 3000, 150)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	start_button = _button(buttons, "Start", _start)
	pause_button = _button(buttons, "Pause", controller.pause_decisions)
	stop_button = _button(buttons, "Stop", controller.stop)
	replay_button = _button(column, "Replay previous campaign", _replay)
	replay_button.disabled = true
	state_label = _text(column, "idle", 16)
	goal_label = _text(column, "", 14)
	goal_label.custom_minimum_size.x = 330
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	observation_label = _text(column, "", 13)
	observation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_label = RichTextLabel.new()
	history_label.custom_minimum_size = Vector2(330, 135)
	history_label.scroll_following = true
	history_label.add_theme_font_size_override("normal_font_size", 12)
	column.add_child(history_label)
	export_label = _text(column, "Transcripts export automatically after each action.", 12)
	export_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := _text(column, "The green pointer marks goblin's tool target or observed pilot. Pause stops decisions; Stop releases input and pauses the scene.", 12)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


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
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _start() -> void:
	if controller.running or not launch.get("ok", false): return
	recent.clear()
	var config := {"fixture_id": Fixtures.ids()[fixture.selected], "policy": Policy.PERSONALITIES[personality.selected],
		"seed": int(seed_value.value), "budget": int(action_budget.value), "pacing_ms": int(pacing.value),
		"evidence_kind": "graphical_godot"}
	var result: Dictionary = await controller.run_campaign(config, launch.provenance)
	_show_refusal(result)


func _replay() -> void:
	if controller.running or last_tape.is_empty(): return
	var replay: Dictionary = last_tape.duplicate(true)
	recent.clear()
	var result: Dictionary = await controller.run_campaign({"pacing_ms": int(pacing.value), "evidence_kind": "graphical_godot"}, launch.provenance, replay)
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


func _finished(tape: Dictionary) -> void:
	last_tape = tape.duplicate(true)
	export_label.text = "Saved transcript: " + controller.export_path if not controller.export_path.is_empty() else "Evidence export failed: " + controller.last_error
	replay_button.disabled = tape.get("steps", []).is_empty()
	_refresh()


func _refresh() -> void:
	if state_label == null: return
	start_button.disabled = controller.running or not launch.get("ok", false)
	pause_button.disabled = not controller.running
	pause_button.text = "Resume" if controller.decisions_paused else "Pause"
	stop_button.disabled = not controller.running
	replay_button.disabled = controller.running or last_tape.is_empty()
	fixture.disabled = controller.running
	personality.disabled = controller.running
	state_label.text = "%s · %d completed / %d attempted / %d budget" % [controller.state, controller.completed, controller.attempted, controller.budget]
	goal_label.text = controller.goal
	var seen: Dictionary = controller.latest_observation
	if not seen.is_empty():
		var native: Dictionary = seen.get("native", {})
		observation_label.text = "Latest: %s\nNative tick %s · revision %s · actor tick %s\n%s · material %s" % [
			controller.latest_action, str(native.get("tick", "—")), str(native.get("revision", "—")),
			str(seen.get("actor_tick", "—")), "Paused" if seen.get("paused", true) else "Playing", str(seen.get("material", "—"))]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and controller != null:
		controller.stop()
