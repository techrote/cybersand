class_name CyberActorPrototypePanel
extends PopupPanel

signal apply_requested(model_id: StringName, producer: StringName, demo_npcs: bool)
signal equipment_requested(usable_index: int, power: float)

# Preserve the original setA indices for callers using the first prototype panel.
const MODELS: Array[StringName] = [&"", &"runner", &"skimmer", &"crawler"]
const PRODUCERS: Array[StringName] = [&"human", &"demo", &"policy"]
const Catalog = preload("res://scripts/actor_rig_catalog.gd")
const PhysicalCatalog = preload("res://scripts/physical_actor_catalog.gd")
const Flight = preload("res://scripts/physical_flight_profile.gd")
const UsableCatalog = preload("res://scripts/usable_catalog.gd")

var set_choice: OptionButton
var model_choice: OptionButton
var producer_choice: OptionButton
var npc_choice: CheckBox
var effort_slider: HSlider
var effort_label: Label
var description: Label
var usable_choice: OptionButton
var usable_power_slider: HSlider
var usable_power_label: Label
var usable_description: Label
var _equipment_physical: bool = false
var _equip_only_button: Button
var status: Label
var _visible_models: Array[StringName] = []


func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.045, 0.065, 1.0)
	background.border_color = Color(0.25, 0.35, 0.45)
	background.set_border_width_all(1)
	background.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", background)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(540, 0)
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "ACTOR-RIGS"
	title.add_theme_font_size_override("font_size", 23)
	column.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "%d retained articulated actors + four 4LY single-body free-flight drones; sampled references remain available" % PhysicalCatalog.RIG_IDS.size()
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	set_choice = OptionButton.new()
	for set_id: StringName in PhysicalCatalog.SET_IDS:
		var first: StringName = PhysicalCatalog.rigs_in_set(set_id)[0]
		set_choice.add_item(str(set_id) + " — " + str(PhysicalCatalog.entry(first).theme))
	set_choice.item_selected.connect(_select_set)
	column.add_child(set_choice)
	model_choice = OptionButton.new()
	model_choice.item_selected.connect(_refresh_description)
	column.add_child(model_choice)
	producer_choice = OptionButton.new()
	for label: String in ["Pilot: keyboard", "Pilot: scripted demonstration", "Pilot: external policy input"]:
		producer_choice.add_item(label)
	producer_choice.item_selected.connect(_refresh_producer)
	column.add_child(producer_choice)
	npc_choice = CheckBox.new()
	column.add_child(npc_choice)
	var power_row: HBoxContainer = HBoxContainer.new()
	column.add_child(power_row)
	effort_label = Label.new()
	effort_label.custom_minimum_size.x = 150
	power_row.add_child(effort_label)
	effort_slider = HSlider.new()
	effort_slider.min_value = 0.0
	effort_slider.max_value = 1.0
	effort_slider.step = 0.05
	effort_slider.value = 0.7
	effort_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effort_slider.value_changed.connect(_refresh_effort)
	power_row.add_child(effort_slider)
	var equipment_title := Label.new()
	equipment_title.text = "ACTOR EQUIPMENT"
	equipment_title.add_theme_font_size_override("font_size", 17)
	column.add_child(equipment_title)
	usable_choice = OptionButton.new()
	usable_choice.add_item("None — world pointer returns to painting")
	for definition: Dictionary in UsableCatalog.DEFINITIONS:
		usable_choice.add_item("%s — %s" % [str(definition.id).to_upper(), str(definition.name)])
	usable_choice.item_selected.connect(_refresh_usable)
	column.add_child(usable_choice)
	var usable_power_row := HBoxContainer.new()
	column.add_child(usable_power_row)
	usable_power_label = Label.new()
	usable_power_label.custom_minimum_size.x = 150
	usable_power_row.add_child(usable_power_label)
	usable_power_slider = HSlider.new()
	usable_power_slider.min_value = 0.0
	usable_power_slider.max_value = 1.0
	usable_power_slider.step = 0.05
	usable_power_slider.value = 0.8
	usable_power_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	usable_power_slider.value_changed.connect(_refresh_usable_power)
	usable_power_row.add_child(usable_power_slider)
	usable_description = Label.new()
	usable_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	usable_description.custom_minimum_size.y = 54
	column.add_child(usable_description)
	var equipment_row := HBoxContainer.new()
	column.add_child(equipment_row)
	var equip_only := Button.new()
	equip_only.text = "Equip only"
	equip_only.pressed.connect(_equip_only)
	_equip_only_button = equip_only
	equipment_row.add_child(equip_only)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 180
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(description)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.modulate = Color(0.75, 0.82, 0.9)
	status.text = "Applying restores the selected map, including its materials, to its starting layout. External policy mode waits for actions.\nAim with the pointer; [ / ] changes power. Release control keys after switching."
	column.add_child(status)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	var apply: Button = Button.new()
	apply.text = "Apply + restore this map"
	apply.pressed.connect(_apply)
	row.add_child(apply)
	var close: Button = Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	row.add_child(close)
	_populate_models(&"setA", &"")
	_refresh_effort(effort_slider.value)
	_refresh_usable_power(usable_power_slider.value)
	_refresh_usable(0)


func selected_set_id() -> StringName:
	return PhysicalCatalog.SET_IDS[clampi(set_choice.selected, 0, PhysicalCatalog.SET_IDS.size() - 1)]


func configure_selection(model_id: StringName, producer: StringName, demo_npcs: bool) -> void:
	var set_id: StringName = Catalog.set_for(model_id) if Catalog.has_rig(model_id) else &"setA"
	if str(model_id).begins_with("rapier/"):
		set_id = PhysicalCatalog.set_for(StringName(str(model_id).trim_prefix("rapier/")))
	set_choice.select(maxi(0, PhysicalCatalog.SET_IDS.find(set_id)))
	_populate_models(set_id, model_id)
	producer_choice.select(maxi(0, PRODUCERS.find(producer)))
	npc_choice.button_pressed = demo_npcs
	_refresh_description(model_choice.selected)


func configure_equipment(usable_index: int, power: float, physical: bool = false) -> void:
	_equipment_physical = physical
	var item_index: int = clampi(usable_index + 1, 0, UsableCatalog.count())
	usable_choice.select(item_index)
	usable_power_slider.value = clampf(power, 0.0, 1.0)
	_refresh_usable(item_index)


func selected_usable_index() -> int:
	return usable_choice.selected - 1


func _refresh_usable(index: int) -> void:
	if index <= 0:
		usable_description.text = "No actor equipment. Painting is available once the owner acknowledges unequip and pointer buttons are released."
		return
	var definition: Dictionary = UsableCatalog.entry(index - 1)
	usable_description.text = "%s — %s\n%s" % [str(definition.name), str(definition.description), UsableCatalog.controls_text(index - 1)]
	if _equipment_physical:
		var controls: String = "Left/M: use. Right: precision pulse or supported early payload activation. N: drop. U: nearby pickup."
		if str(definition.category) == "object":
			controls = "Left/M: deploy the carried processor. It works after settling. U: pick up when nearby. N: release without operating."
		usable_description.text = "%s — %s\n%s" % [str(definition.name), str(definition.description), controls]


func _refresh_usable_power(value: float) -> void:
	usable_power_label.text = "Equipment power: %d%%" % roundi(value * 100.0)


func _equip_only() -> void:
	if _flight_selected():
		set_error("4LY drone loadout is explicitly empty; equipment selection is unavailable.")
		return
	equipment_requested.emit(selected_usable_index(), usable_power_slider.value)


func _select_set(index: int) -> void:
	set_choice.select(index)
	var set_id: StringName = selected_set_id()
	_populate_models(set_id, StringName("rapier/" + str(PhysicalCatalog.rigs_in_set(set_id)[0])))


func _populate_models(set_id: StringName, selected: StringName) -> void:
	model_choice.clear()
	_visible_models.assign([&""])
	model_choice.add_item("Sampled — baseline character (runtime surfacing)")
	for rig_id: StringName in Catalog.rigs_in_set(set_id):
		_visible_models.append(rig_id)
		model_choice.add_item("Sampled — " + Catalog.name_for(rig_id))
	_visible_models.append_array([&"physical/barrel", &"physical/ripper"])
	model_choice.add_item("Rapier reference — barrel (single hull)")
	model_choice.add_item("Rapier reference — Ripper (single hull)")
	for rig_id: StringName in PhysicalCatalog.rigs_in_set(set_id):
		_visible_models.append(StringName("rapier/" + str(rig_id)))
		model_choice.add_item(("4LY free-flight drone — " if rig_id in Flight.IDS else "Articulated Rapier — ") + PhysicalCatalog.name_for(rig_id))
	model_choice.select(maxi(0, _visible_models.find(selected)))
	npc_choice.text = "Add up to 7 other rigs in this set as scripted demo NPCs"
	_refresh_description(model_choice.selected)


func _flight_selected() -> bool:
	if model_choice == null or model_choice.selected < 0 or model_choice.selected >= _visible_models.size():
		return false
	var model: String = str(_visible_models[model_choice.selected])
	return model.begins_with("rapier/") and StringName(model.trim_prefix("rapier/")) in Flight.IDS


func _refresh_description(index: int) -> void:
	var rig_id: StringName = _visible_models[index]
	var flight: bool = _flight_selected()
	usable_choice.disabled = flight
	usable_power_slider.editable = not flight
	_equip_only_button.disabled = flight
	if flight:
		usable_choice.select(0)
		_refresh_usable(0)
		npc_choice.text = "Add the other three 4LY drones as scripted neutral demo companions"
	else:
		npc_choice.text = "Add up to 7 other rigs in this set as scripted demo NPCs"
	var articulated: bool = str(rig_id).begins_with("rapier/")
	var physical: bool = str(rig_id).begins_with("physical/")
	producer_choice.disabled = rig_id == &"" or physical
	npc_choice.disabled = rig_id == &"" or physical
	effort_label.get_parent().visible = not physical
	if physical:
		producer_choice.select(0)
		npc_choice.button_pressed = false
		description.text = "REFERENCE RAPIER %s\nOne live collision hull, driven by impulses and torque. A/D drive; Q/E torque; Space upward thruster pulse (0.6 s cooldown; works airborne). Release controls after switching.\n\nKeyboard pilot only. This preserves the original comparison trial. Choose an Articulated Rapier entry for the complete actor and scripted pilot." % str(rig_id).trim_prefix("physical/").to_upper()
		effort_slider.editable = false
		return
	if articulated:
		var bare_id := StringName(str(rig_id).trim_prefix("rapier/"))
		var rig: Dictionary = PhysicalCatalog.entry(bare_id)
		if flight:
			var profile: Dictionary = Flight.entry(bare_id)
			description.text = "%s / 4LY ASSISTED FREE-FLIGHT\n%s\n\n%s\n\nOne physical rectangle (%s cells), mass %.2f authored units. Desired speed: %.1f horizontal / %.1f vertical cells/s; acceleration %.1f; braking %.1f cells/s². Thrust limit %.1f; response %.3f s.\nController: %s. Assistance: bounded velocity tracking + upright stabilization when an admitted live command exists; neutral brakes/hovers; cancellation/expiry/power-off removes force.\nDefault loadout: EMPTY. F5 Apply resets map + actor and clears input history; no live mass/collider conversion.\nScripted demonstration currently sends neutral hover only; external policy requires fresh admitted actions." % [
				str(rig.name).to_upper(), str(rig.description), PhysicalCatalog.controls_text(bare_id),
				str(profile.collider_size), float(profile.mass), float(profile.desired_speed[0]), float(profile.desired_speed[1]),
				float(profile.acceleration), float(profile.braking), float(profile.max_force),
				float(profile.velocity_response_seconds), Flight.CONTROLLER_ID]
			effort_slider.editable = false
			effort_label.get_parent().visible = false
		else:
			description.text = "%s / ARTICULATED RAPIER\n%s\n\n%s\n\n%d moving parts · %d joints. Scripted pilots patrol, use their abilities and recover using local feedback.\nM: use mounted tool · N: release held tool · U: reattach nearby tool." % [str(rig.name).to_upper(), str(rig.description), PhysicalCatalog.controls_text(bare_id), rig.parts.size(), rig.joints.size()]
			effort_slider.editable = producer_choice.selected == 0
		return
	if rig_id == &"":
		description.text = "Restore the existing sampled character and player/environment profile."
		effort_slider.editable = false
		return
	var definition: Dictionary = Catalog.entry(rig_id)
	description.text = "%s • %s\n%s\n\n%s" % [str(definition.name).to_upper(),
		str(definition.set), str(definition.description), Catalog.controls_text(rig_id)]
	if not definition.limitations.is_empty():
		description.text += "\n\n" + str(definition.limitations[0])
	effort_slider.editable = definition.channels.has("effort") and producer_choice.selected == 0


func _refresh_producer(_index: int) -> void:
	_refresh_description(model_choice.selected)


func _refresh_effort(value: float) -> void:
	effort_label.text = "Keyboard power: %d%%" % roundi(value * 100.0)


func _apply() -> void:
	apply_requested.emit(_visible_models[model_choice.selected], PRODUCERS[producer_choice.selected],
		npc_choice.button_pressed)


func show_selection() -> void:
	popup_centered(Vector2i(620, 780))
	# Wrapped labels need one layout frame before their final minimum height.
	# Fit again on first opening rather than retaining a tall provisional popup.
	await get_tree().process_frame
	if visible:
		popup_centered(Vector2i(620, 780))


func set_context(map_name: String) -> void:
	status.text = "Map: %s\nApplying restores this map's starting layout; edits and motion reset. External policy waits for actions. [ / ] changes keyboard power. P resumes play after applying." % map_name


func set_error(message: String) -> void:
	status.text = message
