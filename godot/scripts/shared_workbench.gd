extends VBoxContainer

const Setup = preload("res://scripts/workbench_setup.gd")
const Fleet = Setup.Fleet
const RESPONSE_LABELS := ["LA-SA · selective arrivals","LA · all events","LA · events off","RFT · fixed 20"]
const ZOOMS := [Vector2i(240,135),Vector2i(480,270),Vector2i(960,540)]
const TOOL_NAMES := ["Paint","Place body","Select body","Move selected","Place source"]
var host: Control
var applied: Dictionary = {}
var pilot_slot := -1
var fire_enabled := false
var step_requested := false
var step_serial := 0
var step_pending := false
var message := ""
var _tool := OptionButton.new()
var _model := OptionButton.new()
var _instances := OptionButton.new()
var _material := OptionButton.new()
var _response := OptionButton.new()
var _camera := OptionButton.new()
var _brush := SpinBox.new()
var _fire := CheckButton.new()
var _stream := CheckButton.new()
var _fields := {}
var _position := []
var _extent := []
var _details := VBoxContainer.new()
var _liquids: CyberLiquidComparisonPanel
var _detail_label := Label.new()
var _name := LineEdit.new()
var _status := Label.new()
var _last_cell := Vector2i(-1,-1)
var _drag_button := 0
var _pan := false
var _stream_was_active := false
var _saved_view := {}
var _reload_rollback := {}
var _requested_response: String = "LA-SELECTIVE"
var _zoom := 1
var _last_status_ms := -1000
var _runtime_label := ""

func _row(parent: Control) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",4)
	row.add_theme_constant_override("v_separation",2)
	parent.add_child(row)
	return row

func _button(row: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = caption
	button.pressed.connect(func() -> void:
		_commit_field()
		action.call())
	row.add_child(button)
	return button

func _label(row: Control, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	row.add_child(label)

func _picker(row: Control, picker: OptionButton, names: Array, action: Callable = Callable()) -> void:
	picker.focus_mode = Control.FOCUS_NONE
	for caption: String in names:
		picker.add_item(caption)
	if action.is_valid(): picker.item_selected.connect(action)
	row.add_child(picker)

func _spin(row: Control, caption: String, field: SpinBox, low: float, high: float, step: float, value: float) -> SpinBox:
	_label(row,caption)
	field.min_value = low
	field.max_value = high
	field.step = step
	field.value = value
	field.custom_minimum_size.x = 78
	field.get_line_edit().focus_entered.connect(_cancel)
	row.add_child(field)
	return field

func setup(controller: Control) -> void:
	host = controller
	host.tower_panel.refresh(false,0,{})
	var layout: Control = host.get_node("Layout")
	for child: Control in layout.get_children():
		if child != host.world_view: child.hide()
	layout.add_child(self)
	layout.move_child(self,0)
	host.world_view.custom_minimum_size = Vector2(0,180)
	host.world_view.mouse_filter = Control.MOUSE_FILTER_STOP
	host.world_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.world_view.gui_input.connect(_world_input)
	var compact := Theme.new()
	compact.default_font_size = 13
	theme = compact
	var row := _row(self)
	_label(row,"WORKBENCH")
	_button(row,"Play / Pause [P]",toggle_pause)
	_button(row,"Step [.]",step_once)
	_button(row,"Reset selected [R]",reset_selected)
	_button(row,"Restore start",restore_start)
	_button(row,"New blank",new_canvas)
	_picker(row,_camera,["Free camera","Follow selected","Overview"],func(i: int) -> void: set_camera(i))
	_button(row,"−",func() -> void: zoom_by(1))
	_button(row,"+",func() -> void: zoom_by(-1))
	_button(row,"Details",func() -> void: _details.visible = not _details.visible)
	_button(row,"Menu [F2]",func() -> void: get_tree().change_scene_to_file("res://feature_launcher.tscn"))
	row = _row(self)
	_picker(row,_tool,TOOL_NAMES)
	var names: Array = Fleet.NAMES.duplicate()
	names.append("Passive barrel")
	_picker(row,_model,names)
	_button(row,"Place at X/Y",func() -> void: place(model_choice(),entered_position()))
	_label(row,"Instance")
	_picker(row,_instances,[],func(i: int) -> void: select_instance(_instances.get_item_id(i)))
	_button(row,"Focus",focus_selected)
	_button(row,"Replace with model",replace_selected)
	_button(row,"Remove",remove_selected)
	_picker(row,_material,Setup.MATERIAL_NAMES,func(i: int) -> void:
		if not applied.is_empty(): applied.material = Setup.MATERIALS[i])
	_spin(row,"Brush",_brush,2,24,1,8)
	_brush.value_changed.connect(func(value: float) -> void:
		if not applied.is_empty(): applied.brush = int(value))
	_button(row,"Source at X/Y",func() -> void: place_source(Vector2i(entered_position())))
	_button(row,"Burst [B]",burst)
	_stream.text = "Stream ≤600 ticks"
	_stream.focus_mode = Control.FOCUS_NONE
	_stream.toggled.connect(stream)
	row.add_child(_stream)
	row = _row(self)
	for axis: String in ["X","Y"]:
		_position.append(_spin(row,axis,SpinBox.new(),0,2047,0.01,200))
	_button(row,"Save reset spawn",save_spawn)
	_button(row,"Use body position",capture_spawn)
	_button(row,"Move to X/Y",move_selected)
	_picker(row,_response,RESPONSE_LABELS,func(i: int) -> void: _requested_response = Setup.RESPONSES[i])
	_button(row,"Apply settings",apply_settings)
	_button(row,"Defaults",defaults)
	_fire.text = "Thruster fire"
	_fire.focus_mode = Control.FOCUS_NONE
	_fire.toggled.connect(func(enabled: bool) -> void:
		fire_enabled = enabled
		if not applied.is_empty(): applied.fire = enabled)
	row.add_child(_fire)
	add_child(_details)
	_details.hide()
	row = _row(_details)
	for key: String in Setup.DEFAULT_OPTIONS:
		var low := 5.0 if key == "budget" else (1.0 if key == "boost_multiplier" else (0.01 if key in ["mass_multiplier","inertia_multiplier"] else 0.0))
		var high := 80.0 if key == "budget" else (8.0 if key == "boost_multiplier" else 64.0)
		_fields[key] = _spin(row,key.replace("_multiplier"," ×").capitalize(),SpinBox.new(),low,high,1 if key == "budget" else 0.01,Setup.DEFAULT_OPTIONS[key])
	_button(row,"Reload JSON + reset",reload_definitions)
	row = _row(_details)
	for axis: String in ["New width","height"]:
		_extent.append(_spin(row,axis,SpinBox.new(),512,2048,64,2048))
	_name.text = "my-canvas"
	_name.custom_minimum_size.x = 150
	_name.focus_entered.connect(_cancel)
	row.add_child(_name)
	_button(row,"Save named start",save_setup)
	_button(row,"Load start",load_setup)
	_liquids = host.playable_session_panel.policy_editor
	_liquids.reparent(_details)
	_button(_row(_details),"Apply liquid selection",apply_liquids)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(_detail_label)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	DisplayServer.window_set_title("CyberSand · Development workbench")
	var binary := "cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"
	var binary_hash := FileAccess.get_sha256("res://addons/cybersand_native/bin/"+binary)
	_runtime_label = "%s · Godot %s · native %s · definitions %s" % [OS.get_name(),Engine.get_version_info().string,binary_hash.left(12),Fleet.registry_hash().left(12)]
	new_canvas.call_deferred()

func _commit_field() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit and focus.get_parent() is SpinBox: focus.get_parent().apply()
	if focus != null: focus.release_focus()

func selected_id() -> int:
	return int(applied.get("selected",0))

func model_choice() -> String:
	return Fleet.stable_id(_model.selected) if Fleet.valid_index(_model.selected) else Setup.BARREL

func entered_position() -> Vector2:
	return Vector2(_position[0].value,_position[1].value)

func actor(setup_data: Dictionary, id: int) -> Dictionary:
	for a: Dictionary in setup_data.get("actors",[]):
		if int(a.id) == id: return a
	return {}

func body_state(id: int) -> Dictionary:
	if id <= 0 or host.physical_actor_session == null: return {}
	return host.physical_actor_session.workbench_actor_state(id)

func refuse(reason: String) -> bool:
	message = "Refused · " + reason
	return false

func busy() -> bool:
	return not host.pending_microscenario_apply.is_empty() or step_pending or host.simulation_worker.has_failed()

func _editable() -> bool:
	if busy() or not host.paused or applied.is_empty():
		return refuse("Pause and wait for the current owner transaction.")
	return true

# On edits, build other actors at their actual positions while leaving the
# saved spawn recipe intact. A deliberate restore/load uses saved spawns.
func apply(candidate: Dictionary, preserve: bool = false, reset_id: int = 0) -> bool:
	if busy(): return refuse("Wait for the current owner transaction.")
	var error := Setup.validate(candidate)
	if not error.is_empty(): return refuse(error)
	var recipe := Setup.rectangles(candidate)
	if recipe.has("error"): return refuse(recipe.error)
	var definitions := Setup.physical_definitions(candidate)
	if preserve:
		for a: Dictionary in definitions:
			if int(a.instance_id) == reset_id: continue
			var state := body_state(int(a.instance_id))
			if not state.is_empty():
				a.position = state.position
				a.retained_motion = {"rotation":state.rotation,"linear_velocity":state.linear_velocity,
					"angular_velocity":state.angular_velocity}
		error = Setup.placement_error(definitions)
		if not error.is_empty(): return refuse(error)
		_saved_view = {"origin":host.camera_origin,"size":host.current_view_size}
	else:
		_saved_view.clear()
	_cancel()
	var ok: bool = host.workbench_apply(candidate,definitions,recipe.runs,Setup.extent_of(candidate),
		PackedInt32Array(candidate.liquid_policy),candidate.normalize,int(candidate.rule_radius),str(candidate.response),preserve)
	return true if ok else refuse(host.microscenario_error)

func new_canvas() -> bool:
	if _liquids == null or _liquids.bridge == null: return refuse("Native policy interface unavailable.")
	if not applied.is_empty() and not _editable(): return false
	var size := Vector2i(int(_extent[0].value),int(_extent[1].value))
	return apply(Setup.fresh(_liquids.bridge.default_liquid_policy(),size))

func installed(candidate: Dictionary) -> void:
	applied = candidate.duplicate(true)
	_reload_rollback.clear()
	var policy: Dictionary = host.tower_context.get("liquid_solver_policy",{})
	if policy.has("envelope"): applied.liquid_policy = Array(policy.envelope)
	_liquids.requested_policy = PackedInt32Array(applied.liquid_policy)
	_liquids._dirty = false
	_liquids._refresh_choices()
	_liquids.geometry_picker.select(1 if int(applied.rule_radius) == 3 else 0)
	_liquids.normalize_water.set_pressed_no_signal(applied.normalize)
	if not _saved_view.is_empty():
		host.camera_origin = _saved_view.origin
		host.current_view_size = _saved_view.size
		_saved_view.clear()
	else:
		_camera.select(0)
		_zoom = 1
		host.current_view_size = ZOOMS[_zoom]
		host.camera_origin = Vector2.ZERO
	var size := Setup.extent_of(applied)
	_extent[0].value = size.x
	_extent[1].value = size.y
	for axis: int in 2: _position[axis].max_value = size[axis]-1
	_material.select(Setup.MATERIALS.find(int(applied.material)))
	_brush.set_value_no_signal(applied.brush)
	_requested_response = applied.response
	_response.select(Setup.RESPONSES.find(_requested_response))
	fire_enabled = applied.fire
	_fire.set_pressed_no_signal(fire_enabled)
	_stream.set_pressed_no_signal(false)
	_instances.clear()
	_instances.add_item("Observer",0)
	for a: Dictionary in applied.actors:
		_instances.add_item("%d · %s" % [int(a.id),str(a.model).capitalize()],int(a.id))
	select_instance(selected_id(),true)
	if not applied.source.is_empty():
		host.workbench_source(Vector2i(applied.source[0],applied.source[1]),int(applied.source[2]),"configure")
	for i: int in 3:
		host.world_shader.set_shader_parameter("rigid_body_data_%d" % i,Vector4(-1000,-1000,0,0))
	host.update_worker_frame_state()
	message = "Paused · left paint/tool, right erase, middle pan, wheel zoom."

func select_instance(id: int, installing: bool = false) -> bool:
	if not installing and busy(): return refuse("Wait for owner acknowledgement.")
	var a := actor(applied,id)
	if a.is_empty() and id != 0: return refuse("Unknown instance.")
	_cancel()
	applied.selected = id
	pilot_slot = -1
	if id != 0 and a.model != Setup.BARREL and host.physical_actor_session != null:
		pilot_slot = host.physical_actor_session.slot_for_instance(id)
	_instances.select(_instances.get_item_index(id))
	var options: Dictionary = a.get("options",Setup.DEFAULT_OPTIONS)
	for key: String in _fields: _fields[key].value = options[key]
	if not a.is_empty():
		_position[0].value = a.spawn[0]
		_position[1].value = a.spawn[1]
	return true

func place(model: String, pos: Vector2) -> bool:
	if not _editable(): return false
	var next := applied.duplicate(true)
	next.actors.append(Setup.instance(model,int(next.next_id),pos))
	next.selected = next.next_id
	next.next_id = int(next.next_id)+1
	return apply(next,true,int(next.selected))

func replace_selected() -> bool:
	if not _editable() or selected_id() == 0: return refuse("Select a body while paused.")
	var next := applied.duplicate(true)
	var old := actor(next,selected_id())
	var replacement := Setup.instance(model_choice(),int(next.next_id),Setup.point(old.spawn))
	next.actors[next.actors.find(old)] = replacement
	next.selected = next.next_id
	next.next_id = int(next.next_id)+1
	return apply(next,true,int(next.selected))

func remove_selected() -> bool:
	if not _editable() or selected_id() == 0: return refuse("Select a body while paused.")
	var next := applied.duplicate(true)
	next.actors.erase(actor(next,selected_id()))
	next.selected = 0
	return apply(next,true)

func save_spawn() -> bool:
	if not _editable() or selected_id() == 0: return refuse("Select a body while paused.")
	var next := applied.duplicate(true)
	var value := entered_position()
	actor(next,selected_id()).spawn = [value.x,value.y]
	var error := Setup.validate(next)
	if not error.is_empty(): return refuse(error)
	applied = next
	message = "Saved reset spawn at %s" % value
	return true

func capture_spawn() -> bool:
	var state := body_state(selected_id())
	if state.is_empty(): return refuse("No authoritative body position.")
	_position[0].value = state.position.x
	_position[1].value = state.position.y
	return save_spawn()

func move_selected() -> bool:
	if not _editable() or selected_id() == 0: return refuse("Select a body while paused.")
	var next := applied.duplicate(true)
	var pos := entered_position()
	actor(next,selected_id()).spawn = [pos.x,pos.y]
	return apply(next,true,selected_id())

func reset_selected() -> bool:
	if not _editable() or selected_id() == 0: return refuse("Select a body while paused.")
	return apply(applied,true,selected_id())

func restore_start() -> bool:
	return _editable() and apply(applied)

func apply_settings() -> bool:
	if not _editable(): return false
	var next := applied.duplicate(true)
	next.response = _requested_response
	var a := actor(next,selected_id())
	if not a.is_empty():
		for key: String in _fields: a.options[key] = _fields[key].value
	return apply(next,true)

func defaults() -> bool:
	if not _editable(): return false
	var next := applied.duplicate(true)
	next.response = Setup.RESPONSES[0]
	var a := actor(next,selected_id())
	if not a.is_empty(): a.options = Setup.DEFAULT_OPTIONS.duplicate()
	return apply(next,true)

func reload_definitions(manifest: String = Fleet.DEFAULT_MANIFEST) -> bool:
	if not _editable(): return false
	var previous := Fleet.registry_snapshot()
	if not Fleet.reload_definitions(manifest): return refuse(Fleet.last_error())
	var next := applied.duplicate(true)
	for a: Dictionary in next.actors:
		if a.model != Setup.BARREL: a.hash = Fleet.definition_hash(Fleet.index_for_id(a.model))
	if not apply(next,true,selected_id()):
		Fleet.restore_registry(previous)
		return false
	_reload_rollback = previous
	return true

func apply_liquids() -> bool:
	if not _editable(): return false
	var next := applied.duplicate(true)
	var validation: Dictionary = _liquids.bridge.validate_liquid_policy(_liquids.requested_policy)
	if not validation.get("accepted",false): return refuse(str(validation.get("refusal",{})))
	next.liquid_policy = Array(_liquids.requested_policy)
	next.normalize = _liquids.normalize_water.button_pressed
	next.rule_radius = maxi(_liquids.geometry_picker.get_selected_id(),int(validation.receipt.get("minimum_rule_radius",2)))
	return apply(next,true)

func save_setup() -> bool:
	if not _editable(): return false
	var error := Setup.write_named(_name.text,applied)
	if not error.is_empty(): return refuse(error)
	message = "Saved starting setup · " + _name.text
	return true

func load_setup() -> bool:
	if not _editable(): return false
	var result := Setup.read_named(_name.text)
	return refuse(result.error) if result.has("error") else apply(result.setup)

func _cancel() -> void:
	if host != null: host.cancel_playable_course_input()

func cancel_stroke() -> void:
	_drag_button = 0
	_pan = false
	_last_cell = Vector2i(-1,-1)
	_stream.set_pressed_no_signal(false)

func toggle_pause() -> bool:
	if applied.is_empty() or busy(): return refuse("Wait for the session.")
	if not host.paused: _cancel()
	host.paused = not host.paused
	host.update_worker_frame_state()
	return true

func step_once() -> bool:
	if not _editable(): return false
	var stopped: String = host.tower_context.get("workbench_refusal","")
	if not stopped.is_empty(): return refuse(stopped)
	step_serial += 1
	step_requested = true
	step_pending = true
	return true

func paint(pos: Vector2i, material: int) -> bool:
	if busy() or applied.is_empty(): return false
	if material not in Setup.MATERIALS or not Rect2i(Vector2i.ZERO,Setup.extent_of(applied)).has_point(pos): return false
	var stamp := [pos.x,pos.y,int(applied.brush),material]
	var new_stamp: bool = applied.edits.is_empty() or applied.edits.back() != stamp
	if new_stamp and applied.edits.size() >= Setup.MAX_STAMPS: return refuse("Starting paint capacity exhausted.")
	# The usual stroke path costs one record. Check coalesced capacity only when
	# the maximum possible row count would exceed the reconstruction budget.
	var runs := 2*int(applied.brush)+1
	for old: Array in applied.edits: runs += 2*int(old[2])+1
	if new_stamp and runs > Setup.MAX_RUNS:
		applied.edits.append(stamp)
		var recipe := Setup.rectangles(applied)
		applied.edits.pop_back()
		if recipe.has("error"): return refuse(recipe.error)
	if not host.queue_brush_mutation(pos.x,pos.y,int(applied.brush),material): return refuse("Worker refused brush.")
	if new_stamp: applied.edits.append(stamp)
	return true

func place_source(pos: Vector2i) -> bool:
	if applied.is_empty() or busy(): return refuse("Wait for the session.")
	var next := applied.duplicate(true)
	next.source = [pos.x,pos.y,int(applied.material)]
	var error := Setup.validate(next)
	if not error.is_empty(): return refuse(error)
	if not host.workbench_source(pos,int(applied.material),"configure"): return refuse("Worker refused source.")
	applied.source = next.source
	_stream.set_pressed_no_signal(false)
	return true

func burst() -> bool:
	if busy() or applied.get("source",[]).is_empty(): return refuse("Place a powder source first.")
	return host.workbench_source(Vector2i(applied.source[0],applied.source[1]),int(applied.source[2]),"burst")

func stream(enabled: bool) -> bool:
	if busy() or applied.get("source",[]).is_empty():
		_stream.set_pressed_no_signal(false)
		return refuse("Place a powder source first.")
	return host.workbench_source(Vector2i(applied.source[0],applied.source[1]),int(applied.source[2]),"stream" if enabled else "stop")

func _set_view(origin: Vector2, size: Vector2i) -> void:
	if applied.is_empty(): return
	var extent := Setup.extent_of(applied)
	host.current_view_size = size.min(extent)
	host.camera_origin = origin.clamp(Vector2.ZERO,Vector2(extent-host.current_view_size))
	host.update_worker_frame_state()

func focus_selected() -> void:
	var state := body_state(selected_id())
	if not state.is_empty(): _set_view(Vector2(state.position)-Vector2(host.current_view_size)*0.5,host.current_view_size)

func set_camera(index: int) -> void:
	if applied.is_empty(): return
	if index == 2:
		_set_view(Vector2.ZERO,Setup.extent_of(applied))
	elif index == 1:
		_set_view(host.camera_origin,ZOOMS[_zoom])
		focus_selected()
	else:
		_set_view(host.camera_origin,ZOOMS[_zoom])

func zoom_by(direction: int) -> void:
	if applied.is_empty(): return
	var centre := Vector2(host.camera_origin) + Vector2(host.current_view_size)*0.5
	_zoom = clampi(_zoom+direction,0,ZOOMS.size()-1)
	_camera.select(0)
	_set_view(centre-Vector2(ZOOMS[_zoom])*0.5,ZOOMS[_zoom])

func _input(event: InputEvent) -> void:
	if host == null or applied.is_empty() or busy(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event is InputEventJoypadButton:
		var pads := Input.get_connected_joypads()
		if event.pressed and event.button_index == JOY_BUTTON_START and not pads.is_empty() and event.device == pads[0]:
			toggle_pause()
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F:
		var mode := (_camera.selected+1) % _camera.item_count
		_camera.select(mode)
		set_camera(mode)
	elif event.keycode == KEY_TAB and not applied.actors.is_empty():
		var next := (_instances.selected+1) % _instances.item_count
		select_instance(_instances.get_item_id(maxi(1,next)))
	elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
		var index: int = event.keycode-KEY_1
		if not Fleet.valid_index(index): return
		_model.select(index)
		for a: Dictionary in applied.actors:
			if a.model == model_choice():
				select_instance(int(a.id))
				get_viewport().set_input_as_handled()
				return
		_tool.select(1)
		message = "Click the canvas to place " + Fleet.NAMES[index]
	else: return
	get_viewport().set_input_as_handled()

func _pick(pos: Vector2i) -> void:
	for a: Dictionary in applied.actors:
		var state := body_state(int(a.id))
		if state.is_empty(): continue
		var local := (Vector2(pos)-Vector2(state.position)).rotated(-float(state.rotation))
		if Setup.bounds(str(a.model)).grow(2).has_point(local):
			select_instance(int(a.id))
			return
	select_instance(0)

func _world_input(event: InputEvent) -> void:
	if applied.is_empty() or busy(): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan = event.pressed
			if _pan: _camera.select(0)
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			return
		if event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return
		_commit_field()
		_drag_button = event.button_index if event.pressed else 0
		_last_cell = Vector2i(-1,-1)
	elif event is InputEventMouseMotion:
		if _pan:
			var area: Rect2 = host.view_content_rect()
			if area.has_area(): _set_view(Vector2(host.camera_origin)-event.relative*Vector2(host.current_view_size)/area.size,host.current_view_size)
			return
	else: return
	var pixel: Vector2i = host.view_pixel_from_local_point(event.position)
	if pixel.x < 0: return
	var pos := Vector2i(host.camera_origin.floor()) + pixel
	if _drag_button == 0 or pos == _last_cell: return
	_last_cell = pos
	if _drag_button == MOUSE_BUTTON_RIGHT or _tool.selected == 0:
		paint(pos,0 if _drag_button == MOUSE_BUTTON_RIGHT else int(applied.material))
		return
	_drag_button = 0
	match _tool.selected:
		1: place(model_choice(),Vector2(pos))
		2: _pick(pos)
		3:
			_position[0].value = pos.x
			_position[1].value = pos.y
			move_selected()
		4: place_source(pos)

func _process(_delta: float) -> void:
	if host == null: return
	if step_pending:
		if host.simulation_worker.has_failed() or not str(host.tower_context.get("workbench_refusal","")).is_empty():
			step_requested = false
			step_pending = false
			refuse(str(host.tower_context.get("workbench_refusal","World failed")))
		elif int(host.tower_context.get("workbench_step_serial",-1)) == step_serial:
			step_pending = false
	if not _reload_rollback.is_empty() and host.pending_microscenario_apply.is_empty():
		Fleet.restore_registry(_reload_rollback)
		_reload_rollback.clear()
	if not applied.is_empty() and _camera.selected == 1: focus_selected()
	if Time.get_ticks_msec()-_last_status_ms < 150: return
	_last_status_ms = Time.get_ticks_msec()
	var cursor: Vector2i = host.view_pixel_from_local_point(host.world_view.get_local_mouse_position())
	if cursor.x >= 0: cursor += Vector2i(host.camera_origin.floor())
	var context: Dictionary = host.tower_context
	var source: Dictionary = context.get("workbench_source",{})
	if _stream_was_active and not source.get("stream_enabled",false):
		_stream.set_pressed_no_signal(false)
	_stream_was_active = source.get("stream_enabled",false)
	if host.physical_actor_overlay != null:
		host.physical_actor_overlay.show_workbench_source(source)
	var gcr: Dictionary = context.get("workbench_gcr",{})
	var state := "Preparing" if not host.pending_microscenario_apply.is_empty() else ("Paused" if host.paused else "Playing")
	var reason: String = host.microscenario_error if not host.microscenario_error.is_empty() else message
	_status.text = "%s · cell %s · %s · %s   |   source %d inserted / %d blocked" % [
		state,cursor,str(applied.get("extent","")),reason,int(source.get("inserted",0)),int(source.get("blocked",0))]
	_status.text += " · granular %s" % gcr.get("response","pending")
	if _details.visible:
		var selected := body_state(selected_id())
		var policy: Dictionary = context.get("liquid_solver_policy",{})
		var assignments := []
		for a: Dictionary in policy.get("assignments",[]):
			assignments.append("%s %s/%s" % [a.get("name",a.material),a.applied_family,a.applied_variant])
		var selected_row: Dictionary = {}
		for receipt: Dictionary in gcr.get("rows",[]):
			if receipt.instance_id == selected_id(): selected_row = receipt
		var delivery: Dictionary = {}
		if host.physical_actor_session != null:
			var ledger: Dictionary = host.rapier_bridge.last_application
			for entry: Dictionary in ledger.get("bodies",[]):
				if int(entry.id)-1 == host.physical_actor_session.slot_for_instance(selected_id()):
					delivery = entry
					break
			if delivery.is_empty(): delivery = {"refusal":ledger.get("refusal","pending")}
		var actual := "Observer" if selected.is_empty() else "%s #%d · mass %.3f · inertia %.3f · force ceiling %.2f · torque ceiling %.2f" % [
			selected.model,selected_id(),selected.mass,selected.inertia,selected.force_limit,selected.torque_limit]
		_detail_label.text = "%s\n%s\nWorld requested %s / native %s · body budget %s · native J %s / torque %s · arrivals %s · proxies %s\nRapier application %s\nLiquid r%d · %s\n%s" % [
			_runtime_label,actual,_requested_response,gcr.get("response","pending"),selected_row.get("budget","—"),selected_row.get("impulse","—"),
			selected_row.get("torque","—"),selected_row.get("arrival_count","—"),selected_row.get("proxy_count","—"),str(delivery),
			int(policy.get("maximum_rule_radius",0)),", ".join(assignments),Fleet.controls(Fleet.index_for_id(str(actor(applied,selected_id()).get("model",""))))]
		_detail_label.text += "\nWorld limits · %s bodies, %s proxies, %s raster cells · arrivals %s bytes" % [
			gcr.get("body_limit","—"),gcr.get("proxy_limit","—"),gcr.get("world_mask_cell_limit","—"),gcr.get("arrival_storage_bytes","—")]
