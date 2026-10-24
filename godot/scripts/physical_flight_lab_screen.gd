extends Control

# Playable, in-game frontend over the exact same persistent native/Rapier
# episode used by headless qualification. F2 or Exit returns to feature menu.
const Episode = preload("res://scripts/physical_flight_episode.gd")
const Course = preload("res://scripts/physical_flight_course.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
const View = preload("res://scripts/physical_flight_course_view.gd")

var episode: CyberPhysicalFlightEpisode
var profile_choice: OptionButton
var scenario_choice: OptionButton
var producer_choice: OptionButton
var telemetry: Label
var hint: Label
var course_view: CyberPhysicalFlightCourseView
var _fault_shown: bool = false
var _policy_queue: Array = []
var _refresh_count: int = 0


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.026, 0.042, 0.065)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	_label(layout, "4LY / PHYSICAL FLIGHT LAB", 28)
	_label(layout, "Actual native-material world + Rapier bodies / 60 Hz / fixed two-output velocity interface", 15)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	layout.add_child(row)
	profile_choice = _picker(row, ["Trainer", "Hauler", "Drifter", "Dart"])
	scenario_choice = _picker(row, Course.IDS)
	producer_choice = _picker(row, ["human", "scripted teacher", "external policy"])
	profile_choice.item_selected.connect(func(_index: int) -> void: fresh_reset())
	scenario_choice.item_selected.connect(func(_index: int) -> void: fresh_reset())
	producer_choice.item_selected.connect(func(_index: int) -> void: fresh_reset())
	var reset_button := Button.new()
	reset_button.text = "Fresh physical reset"
	reset_button.pressed.connect(fresh_reset)
	row.add_child(reset_button)
	var exit_button := Button.new()
	exit_button.text = "Exit / F2"
	exit_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://feature_launcher.tscn"))
	row.add_child(exit_button)
	episode = Episode.new()
	episode.name = "FlightEpisodeNativeRapierHost"
	add_child(episode)
	course_view = View.new()
	course_view.episode = episode
	layout.add_child(course_view)
	telemetry = _label(layout, "Initializing actual flight owner...", 16)
	telemetry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint = _label(layout, "W/A/S/D or arrow keys: desired velocity. Human, scripted teacher and external policy use the same admitted two-output actuator.", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fresh_reset()


func _label(parent: Node, value: String, points: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", points)
	parent.add_child(label)
	return label


func _picker(parent: Node, items: Array) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size.x = 160.0
	for item: Variant in items:
		picker.add_item(str(item))
	parent.add_child(picker)
	return picker


func _selected_profile() -> StringName:
	return Profile.IDS[profile_choice.selected]


func _selected_source() -> StringName:
	match producer_choice.selected:
		0: return &"human"
		1: return &"teacher"
		_: return &"policy"


func fresh_reset() -> void:
	if episode == null or not episode.is_inside_tree():
		return
	_fault_shown = false
	_policy_queue.clear()
	var selected: String = Course.IDS[scenario_choice.selected]
	if not episode.reset(_selected_profile(), selected, 0, "development", _selected_source()):
		telemetry.text = "ACTUAL HOST UNAVAILABLE: " + episode.last_error
		_fault_shown = true
	else:
		_update_telemetry()
	course_view.queue_redraw()


func supply_external_action(action: Dictionary, observation_id: String) -> bool:
	# Optional host-local integration seam. External policy must provide a fresh
	# issued observation ID; no synthetic policy is shipped with this screen.
	if _selected_source() != &"policy" or not _policy_queue.is_empty():
		return false
	if observation_id != str(episode.observe().get("observation_id", "")):
		return false
	_policy_queue.append({"action": action.duplicate(true), "observation_id": observation_id})
	return true


func _human_action() -> Dictionary:
	var right: float = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
	var left: float = float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var down: float = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	var up: float = float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	return {"move": Vector2(right - left, down - up).limit_length(1.0)}


func _physics_process(_delta: float) -> void:
	if episode == null or episode.scenario.is_empty() or _fault_shown:
		return
	var existing: Dictionary = episode.transition(0)
	if bool(existing.episode_done):
		return
	var tick: int = int(existing.physical_ticks_total)
	var action: Variant = null
	var observation_id: String = ""
	if tick % Episode.DECISION_TICKS == 0:
		var view: Dictionary = episode.observe()
		observation_id = str(view.get("observation_id", ""))
		match _selected_source():
			&"human":
				action = _human_action()
			&"teacher":
				action = episode.reference_action()
			&"policy":
				# Never substitute a hidden teacher or neutral controller for an
				# absent externally connected policy.
				if _policy_queue.is_empty():
					return
				var item: Dictionary = _policy_queue.pop_front()
				action = item.action
				observation_id = str(item.observation_id)
	var result: Dictionary = episode.tick(action, observation_id, 1)
	if bool(result.failed):
		_fault_shown = true
	_refresh_count += 1
	if _refresh_count % 5 == 0 or bool(result.episode_done):
		_update_telemetry()
	course_view.queue_redraw()


func _update_telemetry() -> void:
	var view: Dictionary = episode.observe()
	if view.is_empty():
		return
	var relative: Vector2 = view.goal_delta_cells
	var centre: Vector2 = episode.active_goal() - relative
	var velocity: Vector2 = view.velocity_cells_per_second
	var status: Dictionary = episode.transition(0)
	var metrics: Dictionary = episode.metrics()
	telemetry.text = "%s / %s / %s     tick %d / %d     waypoint %d / %d\n" % [
		Profile.name_for(_selected_profile()), Course.IDS[scenario_choice.selected],
		str(_selected_source()), int(status.physical_ticks_total),
		int(episode.scenario.max_ticks), int(status.waypoint) + 1,
		episode.scenario.goals.size()]
	telemetry.text += "position (%.1f, %.1f)  velocity (%.2f, %.2f)  goal distance %.2f  stopping radius %.1f / speed ≤ %.1f  dwell %d / %d\n" % [
		centre.x, centre.y, velocity.x, velocity.y, relative.length(),
		float(episode.scenario.arrival_radius), float(episode.scenario.speed_tolerance),
		int(status.dwell_ticks), int(episode.scenario.dwell_ticks)]
	telemetry.text += "mode %s  command live %s  lease %d  assistance valid %s  contacts %d  overshoots %d\n" % [
		str(view.actuator_mode), str(view.command_live), int(view.lease_remaining_ticks),
		str(view.assistance_valid), int(metrics.contact_ticks), int(metrics.overshoot_events)]
	telemetry.text += "result %s%s" % [
		str(status.reason), " | no external policy attached" if _selected_source() == &"policy" and _policy_queue.is_empty() else ""]


func _exit_tree() -> void:
	if episode != null:
		episode.close()
