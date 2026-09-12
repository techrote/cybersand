class_name CyberTowerPanel
extends VBoxContainer

var host: Variant
var floor_picker: OptionButton
var tube_picker: OptionButton
var info: Label
var labels: Array[Label] = []
var label_points: Array[Vector2] = []
var shown_floor: int = -1

func button(row: Node, text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.pressed.connect(action)
	row.add_child(b)
	return b

func setup(controller: Control) -> void:
	host = controller
	name = "ExperimentControls"
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	floor_picker = OptionButton.new()
	floor_picker.focus_mode = Control.FOCUS_NONE
	for i: int in range(5): floor_picker.add_item("%d / %s" % [i+1,CyberExperimentTower.FLOORS[i]])
	floor_picker.item_selected.connect(func(i: int) -> void: host.tower_floor_select(i))
	row.add_child(floor_picker)
	button(row,"Pause / resume",func() -> void: host.paused = not host.paused)
	button(row,"Single step",func() -> void: host.tower_command({"step":true}))
	button(row,"Fresh tower",func() -> void: host.tower_reset())
	button(row,"Tuning",func() -> void: host.tower_tuning())
	button(row,"Water Feel",func() -> void: host.water_lab_reset())
	button(row,"Water policy",func() -> void: host.water_lab_open())
	button(row,"Save Water policy",func() -> void: host.water_lab_save_profile())
	var release: HBoxContainer = HBoxContainer.new()
	add_child(release)
	tube_picker = OptionButton.new()
	tube_picker.focus_mode = Control.FOCUS_NONE
	tube_picker.item_selected.connect(func(i: int) -> void: host.tower_focus_tube(i))
	release.add_child(tube_picker)
	button(release,"Open plug",func() -> void: host.tower_command({"release":tube_picker.selected}))
	button(release,"Open neighbours",func() -> void: host.tower_command({"release":tube_picker.selected,"adjacent":true}))
	button(release,"Sequence +30 / +90 ticks",func() -> void: host.tower_command({"schedule":tube_picker.selected}))
	button(release,"Blind A/B/C",func() -> void: host.water_lab_prepare_blind())
	button(release,"Next blind",func() -> void: host.water_lab_apply_blind())
	button(release,"Export observation",func() -> void: host.tower_observation())
	info = Label.new()
	info.add_theme_font_size_override("font_size",14)
	add_child(info)
	visible = false

func refresh(active: bool, floor_index: int, context: Dictionary) -> void:
	visible = active
	if not active:
		for label: Label in labels: label.visible = false
		return
	if context.get("water_active",false):
		floor_picker.disabled=true
		tube_picker.disabled=true
		for label: Label in labels: label.visible=false
		var policy: Dictionary=context.get("water_policy",{})
		var accounting: Dictionary=context.get("water_accounting",{})
		info.text="%s\nScenario %s / seed %s / recipe %s / presentation four-level %s" % [
			str(context.get("status","Water Feel Lab")),
			str(policy.get("scenario_id","")),
			str(policy.get("seed","")),
			str(context.get("water_recipe_hash","")).left(12),
			str(policy.get("interface_mode","coverage"))]
		info.text+="\nWater integer %s +%s -%s / pause, single-step, reset and export remain available" % [
			str(accounting.get("current",0)),str(accounting.get("explicit_source",0)),
			str(accounting.get("explicit_sink",0))]
		return
	floor_picker.disabled=false
	tube_picker.disabled=false
	if shown_floor != floor_index:
		shown_floor = floor_index
		floor_picker.select(floor_index)
		tube_picker.clear()
		for label: Label in labels: label.queue_free()
		labels.clear();label_points.clear()
		var index: int = 0
		for tube: Array in CyberExperimentTower.tubes(floor_index):
			var name_text: String = host.material_name(int(tube[1]))
			tube_picker.add_item("%d / %s" % [index+1,name_text+" / "+str(tube[3])])
			var label: Label = Label.new()
			label.text = name_text
			label.tooltip_text = str(tube[3])
			label.add_theme_font_size_override("font_size",14)
			label.add_theme_color_override("font_shadow_color",Color.BLACK)
			label.add_theme_constant_override("shadow_offset_x",1)
			label.add_theme_constant_override("shadow_offset_y",1)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			host.world_view.add_child(label)
			labels.append(label)
			label_points.append(Vector2(int(tube[0]),CyberExperimentTower.floor_y(floor_index)+14))
			index += 1
	info.text = "Amber = erasable plug / arrows pan / A,D + Space navigate / 1–6 floor materials. %s" % str(context.get("status","Baseline · starts paused"))
	var chosen: Array=CyberExperimentTower.tubes(floor_index)[tube_picker.selected]
	info.text += "\n"+str(chosen[3] if str(chosen[3])!="" else CyberExperimentTower.tubes(floor_index)[maxi(0,tube_picker.selected-1)][3])+" / prepared contents below; amber mixing gates are manually erasable"
	var content: Rect2 = host.view_content_rect()
	for i: int in range(labels.size()):
		var point: Vector2 = content.position+(label_points[i]-host.camera_origin)/Vector2(host.current_view_size)*content.size
		labels[i].position = point
		labels[i].visible = content.has_point(point)
