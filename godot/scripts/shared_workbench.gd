extends VBoxContainer

const Setup = preload("res://scripts/workbench_setup.gd")
var host: Control
var applied: Dictionary = {}
var map_choice := OptionButton.new()
var tool_choice := OptionButton.new()
var pilot_choice := OptionButton.new()
var water_choice := OptionButton.new()
var file_name := LineEdit.new()
var status := Label.new()
var message := ""
var pilot_slot := -1
var step_requested := false
var step_serial := 0
var step_pending := false
var starting := true
var _drag := false
var _last_stamp := Vector2i(-1,-1)

func _button(row: Control, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		file_name.release_focus()
		action.call())
	row.add_child(button)

func _choice(row: Control, picker: OptionButton, labels: Array, action: Callable) -> void:
	picker.focus_mode = Control.FOCUS_NONE
	for label: String in labels:
		picker.add_item(label)
	picker.item_selected.connect(func(index: int) -> void:
		file_name.release_focus()
		cancel_stroke()
		action.call(index))
	row.add_child(picker)

func setup(controller: Control) -> void:
	host = controller
	host.tower_panel.refresh(false,0,{})
	for child: Control in host.get_node("Layout").get_children():
		if child != host.world_view:
			child.hide()
	host.get_node("Layout").add_child(self)
	host.get_node("Layout").move_child(self,0)
	host.world_view.custom_minimum_size = Vector2(0,180)
	host.world_view.mouse_filter = Control.MOUSE_FILTER_STOP
	host.world_view.gui_input.connect(_world_input)
	host.world_view.mouse_exited.connect(cancel_stroke)
	var row := HFlowContainer.new()
	add_child(row)
	_choice(row,map_choice,Setup.TITLES,open_map)
	_button(row,"New",func(): open_map(map_choice.selected))
	_choice(row,tool_choice,[host.material_name(CyberCellWorld.SAND),host.material_name(CyberCellWorld.WATER),
		"Erase","Place flyer","Place barrel"],func(_i: int): cancel_stroke())
	_choice(row,pilot_choice,["Pilot lander","Observe barrel"],select_pilot)
	_choice(row,water_choice,["Water · Current","Water · whole-cell"],change_policy)
	_button(row,"Play / pause [P]",toggle_pause)
	_button(row,"Step [.]",step_once)
	_button(row,"Reset [R]",reset_setup)
	file_name.placeholder_text = "Setup name"
	file_name.text = "landing"
	file_name.custom_minimum_size.x = 112
	file_name.text_submitted.connect(func(_s: String): file_name.release_focus())
	row.add_child(file_name)
	_button(row,"Save",save_setup)
	_button(row,"Load",load_setup)
	_button(row,"Launcher [F2]",func(): get_node("/root/FeatureNavigation").return_to_launcher())
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",14)
	add_child(status)
	open_map(0)

func _preset(index: int) -> Dictionary:
	var editor: CyberLiquidComparisonPanel = host.playable_session_panel.policy_editor
	if editor.bridge == null:
		return {"ok":false,"error":"Native liquid policy interface unavailable."}
	return editor._preset(index)

func open_map(index: int) -> bool:
	if index < 0 or index >= Setup.MAPS.size():
		return refuse("Unsupported workbench map.")
	var preset := _preset(0)
	if not preset.ok:
		return refuse(preset.error)
	var policy := PackedInt32Array(applied.liquid_policy) if not applied.is_empty() else PackedInt32Array(preset.request)
	return apply(Setup.fresh(Setup.MAPS[index],policy))

func refuse(reason: String) -> bool:
	host.microscenario_error = ""
	message = "Refused · " + reason
	sync_choices()
	return false

func sync_choices() -> void:
	if applied.is_empty():
		return
	map_choice.select(Setup.MAPS.find(applied.map))
	pilot_choice.select(0 if applied.controlled == Setup.FLYER else 1)
	var current := _preset(0)
	water_choice.select(0 if current.ok and current.request == PackedInt32Array(applied.liquid_policy) else 1)

func apply(candidate: Dictionary) -> bool:
	var reason := Setup.validate(candidate)
	if not reason.is_empty():
		return refuse(reason)
	reason = host.playable_session_unavailable_reason()
	if not reason.is_empty() or step_pending:
		return refuse(reason if not reason.is_empty() else "Wait for the current step.")
	var policy := PackedInt32Array(candidate.liquid_policy)
	var admitted := false
	for index in 2:
		var preset := _preset(index)
		if preset.ok and preset.request == policy:
			admitted = true
			break
	if not admitted:
		return refuse("Unsupported liquid policy for this workbench.")
	var config: Dictionary = host._playable_actor_configuration(&"arcadelander")
	config.workbench_actors = Setup.physical_definitions(candidate)
	var definition := Setup.definition(candidate)
	reason = Setup.spawn_error(candidate,definition.rectangles)
	if not reason.is_empty():
		return refuse(reason)
	host.cancel_playable_course_input()
	if not host.microscenario_apply_exploratory_liquid(definition,policy,false,"Play",config):
		return refuse(host.microscenario_error)
	host.pending_microscenario_apply.workbench = candidate.duplicate(true)
	host.microscenario_error = ""
	message = ""
	sync_choices()
	return true

func installed(candidate: Dictionary) -> void:
	applied = candidate.duplicate(true)
	applied.liquid_policy = Array(host.tower_context.liquid_solver_policy.envelope)
	starting = true
	step_requested = false
	step_pending = false
	# Articulated actors render from copied Rapier poses. Clear the initial
	# sandbox shader's three reference-body slots on owner replacement.
	for i: int in 3:
		host.world_shader.set_shader_parameter("rigid_body_data_%d" % i,Vector4(-1000,-1000,0,0))
	cancel_stroke()
	select_pilot(0 if applied.controlled == Setup.FLYER else 1, true)
	sync_choices()
	message = "W / Space thrust · A/D turn · Shift brake · click or drag to paint"

func select_pilot(index: int, installing: bool = false) -> bool:
	if applied.is_empty() or index not in [0,1] or (not installing and busy()):
		return refuse("Pilot selection unavailable.")
	host.cancel_playable_course_input()
	pilot_slot = -1
	if index == 0:
		for slot: int in Setup.physical_definitions(applied).size():
			if host.physical_actor_session.observation(slot).get("model") == Setup.FLYER:
				pilot_slot = slot
				break
	applied.controlled = Setup.FLYER if pilot_slot >= 0 else "observer"
	pilot_choice.select(index)
	return true

func change_policy(index: int) -> bool:
	if applied.is_empty() or index not in [0,1]:
		return refuse("Unsupported Water setting.")
	var preset := _preset(index)
	if not preset.ok:
		return refuse(preset.error)
	var candidate := applied.duplicate(true)
	candidate.liquid_policy = Array(preset.request)
	return apply(candidate)

func busy() -> bool:
	return applied.is_empty() or not host.pending_microscenario_apply.is_empty() or step_pending or host.simulation_worker.has_failed()

func toggle_pause() -> bool:
	if busy():
		return refuse("Wait for an accepted session or step.")
	host.cancel_playable_course_input()
	host.paused = not host.paused
	if not host.paused:
		starting = false
	host.update_worker_frame_state()
	return true

func step_once() -> bool:
	if busy() or not host.paused:
		return refuse("Pause before stepping.")
	host.cancel_playable_course_input()
	starting = false
	step_requested = true
	step_serial += 1
	step_pending = true
	return true

func reset_setup() -> bool:
	return not applied.is_empty() and apply(applied)

func save_setup() -> bool:
	file_name.release_focus()
	if busy():
		return refuse("Wait for the accepted starting setup.")
	var error := Setup.write_named(file_name.text,applied)
	if not error.is_empty():
		return refuse(error)
	message = "Saved starting setup · " + file_name.text
	return true

func load_setup() -> bool:
	file_name.release_focus()
	var result := Setup.read_named(file_name.text)
	return refuse(result.error) if result.has("error") else apply(result.setup)

func place(model: String, pos: Vector2i) -> bool:
	if busy() or not host.paused or model not in [Setup.FLYER,Setup.BARREL]:
		return refuse("Pause to place a supported body.")
	var next := applied.duplicate(true)
	next.actors[model] = [pos.x,pos.y]
	return apply(next)

func paint(pos: Vector2i, material: int) -> bool:
	if busy() or material not in [CyberCellWorld.SAND,CyberCellWorld.WATER,CyberCellWorld.EMPTY] \
		or not Setup.ROOM.grow(-Setup.BRUSH_RADIUS).has_point(pos):
		return refuse("Brush outside the room or unavailable.")
	if host.paused:
		if not starting:
			return refuse("Reset before editing the starting terrain.")
		if applied.edits.size() >= Setup.MAX_STROKES:
			return refuse("Starting brush history is full.")
		# Emission cannot install cells in an occupied native body mask.
		# Exclude the two starting assemblies plus the brush footprint.
		for slot: int in 2:
			for part: Dictionary in host.physical_actor_session.observation(slot).parts:
				var footprint := Rect2(Vector2(part.position) - Vector2(part.size)*0.5,Vector2(part.size))
				if footprint.grow(Setup.BRUSH_RADIUS + 1).has_point(Vector2(pos)):
					return refuse("Move the brush clear of the starting bodies.")
	if not host.queue_brush_mutation(pos.x,pos.y,Setup.BRUSH_RADIUS,material):
		return refuse("The worker refused the brush request.")
	if host.paused:
		applied.edits.append([pos.x,pos.y,material])
	message = "Starting terrain edited" if host.paused else "Live terrain edited"
	return true

func cancel_stroke() -> void:
	_drag = false
	_last_stamp = Vector2i(-1,-1)

func _world_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		cancel_stroke()
		if event.pressed:
			file_name.release_focus()
			_drag = true
	elif not event is InputEventMouseMotion or not _drag or not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		return
	if not _drag:
		return
	var pos: Vector2i = host.view_pixel_from_local_point(event.position)
	if pos.x < 0:
		cancel_stroke()
		return
	pos += Vector2i(host.camera_origin.floor())
	if pos == _last_stamp:
		return
	_last_stamp = pos
	if tool_choice.selected >= 3:
		cancel_stroke()
		place(Setup.FLYER if tool_choice.selected == 3 else Setup.BARREL,pos)
	else:
		paint(pos,[CyberCellWorld.SAND,CyberCellWorld.WATER,CyberCellWorld.EMPTY][tool_choice.selected])

func _process(_delta: float) -> void:
	if host == null:
		return
	if step_pending and int(host.tower_context.get("workbench_step_serial",-1)) == step_serial:
		step_pending = false
	var state := "Building…" if not host.pending_microscenario_apply.is_empty() else (
		"Edit start" if starting else ("Paused · Reset to edit start" if host.paused else "Running"))
	var detail: String = host.microscenario_error if not host.microscenario_error.is_empty() else message
	if host.simulation_worker.has_failed():
		detail = "World stopped · F2 returns to the launcher."
	status.text = "WORKBENCH   |   %s   |   %s" % [state,detail]
