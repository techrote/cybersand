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
	for i: int in range(5): floor_picker.add_item("%d / %s" % [i+1,CyberExperimentTower.FLOORS[i]])
	floor_picker.item_selected.connect(func(i: int) -> void: host.tower_floor_select(i))
	row.add_child(floor_picker)
	button(row,"Pause / resume",func() -> void: host.paused = not host.paused)
	button(row,"Single step",func() -> void: host.tower_command({"step":true}))
	button(row,"Fresh tower",func() -> void: host.tower_reset())
	button(row,"Tuning",func() -> void: host.tower_tuning())
	var release: HBoxContainer = HBoxContainer.new()
	add_child(release)
	tube_picker = OptionButton.new()
	release.add_child(tube_picker)
	button(release,"Open plug",func() -> void: host.tower_command({"release":tube_picker.selected}))
	button(release,"Open neighbours",func() -> void: host.tower_command({"release":tube_picker.selected,"adjacent":true}))
	button(release,"Sequence +30 / +90 ticks",func() -> void: host.tower_command({"schedule":tube_picker.selected}))
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
	if shown_floor != floor_index:
		shown_floor = floor_index
		floor_picker.select(floor_index)
		tube_picker.clear()
		for label: Label in labels: label.queue_free()
		labels.clear();label_points.clear()
		var index: int = 0
		for tube: Array in CyberExperimentTower.tubes(floor_index):
			var name_text: String = host.material_name(int(tube[1]))
			tube_picker.add_item("%d / %s" % [index+1,name_text])
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
	var content: Rect2 = host.view_content_rect()
	for i: int in range(labels.size()):
		var point: Vector2 = content.position+(label_points[i]-host.camera_origin)/Vector2(host.current_view_size)*content.size
		labels[i].position = point
		labels[i].visible = content.has_point(point)
