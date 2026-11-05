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
var _roster := OptionButton.new()
var _actor_action: String = ""
var _liquid_action := false
var _pending_request_serial := 0
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
var _processor_label := ""

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

func setup(controller: Control, recovery: Dictionary = {}) -> void:
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
	_label(row,"Pilot")
	_picker(row,_roster,["Choose flyer…"],_roster_changed)
	_fill_roster()
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
	var names: Array = Fleet.names()
	names.append("Passive barrel")
	_label(row,"Place model")
	_picker(row,_model,names)
	_model.tooltip_text = "Model for Place at X/Y, cursor placement, and Replace selected. Use Pilot to switch immediately."
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
	_details.visibility_changed.connect(_details_visibility_changed)
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
	_liquids.use_one_shot_normalization()
	_button(_row(_details),"Apply liquid selection",apply_liquids)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(_detail_label)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	DisplayServer.window_set_title("CyberSand · Development workbench")
	_processor_label = "%s · %d logical CPUs" % [OS.get_processor_name(),OS.get_processor_count()]
	var binary := "cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"
	var binary_hash := FileAccess.get_sha256("res://addons/cybersand_native/bin/"+binary)
	_runtime_label = "%s · Godot %s · native %s · definitions %s" % [OS.get_name(),Engine.get_version_info().string,binary_hash.left(12),Fleet.registry_hash().left(12)]
	if recovery.is_empty(): new_canvas.call_deferred()
	else: apply.call_deferred(recovery)


func _fill_roster() -> void:
	_roster.clear()
	_roster.add_item("Observer / choose flyer",0)
	for index: int in range(Fleet.count()): _roster.add_item(Fleet.names()[index],index+1)
	_roster.tooltip_text = "Pilot an existing flyer. If absent, switch the selected flyer at its saved spawn or place a flyer at X/Y."


func _sync_roster() -> void:
	var selected := actor(applied,selected_id())
	_roster.select(Fleet.index_for_id(str(selected.get("model","")))+1)


func _roster_changed(index: int) -> void:
	# The popup displays the applied pilot until owner acknowledgement.
	_sync_roster()
	if index == 0: select_instance(0)
	else: pilot_model(Fleet.stable_id(index-1))


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
	message = "Refused · " + reason.trim_prefix("MicroScenario rejected; ")
	return false

func busy() -> bool:
	return not host.pending_microscenario_apply.is_empty() or step_pending or host.simulation_worker.has_failed()

func _editable() -> bool:
	if busy() or applied.is_empty():
		return refuse("Wait for the current owner transaction.")
	return true

# On edits, build other actors at their actual positions while leaving the
# saved spawn recipe intact. A deliberate restore/load uses saved spawns.
func apply(candidate: Dictionary, preserve: bool = false, reset_id: int = 0,
		convert_liquid_inventory: bool = false, resume_play: bool = false) -> bool:
	if busy(): return refuse("Wait for the current owner transaction.")
	if preserve:
		if applied.is_empty(): return refuse("No installed session to retain.")
		# A retained request can change ownership/settings, never substitute a
		# different starting paint history for the native cells being copied.
		candidate = candidate.duplicate()
		candidate.edits = applied.edits
	var error := Setup.validate(candidate,not preserve)
	if not error.is_empty(): return refuse(error)
	var runs := []
	if not preserve:
		var recipe := Setup.rectangles(candidate)
		if recipe.has("error"): return refuse(recipe.error)
		runs = recipe.runs
	# Retained authoring transfers the current native cells. Stamp replay and
	# its rectangle limit apply only when constructing an authored start.
	var definitions := Setup.physical_definitions(candidate)
	if preserve:
		for a: Dictionary in definitions:
			if int(a.instance_id) == reset_id: continue
			var state := body_state(int(a.instance_id))
			if not state.is_empty():
				a.position = state.position
				a.retained_motion = {"rotation":state.rotation,"linear_velocity":state.linear_velocity,
					"angular_velocity":state.angular_velocity}
		_saved_view = {"origin":host.camera_origin,"size":host.current_view_size}
	else:
		_saved_view.clear()
	_cancel()
	var ok: bool = host.workbench_apply(candidate,definitions,runs,Setup.extent_of(candidate),
		PackedInt32Array(candidate.liquid_policy),candidate.normalize,int(candidate.rule_radius),str(candidate.response),preserve,convert_liquid_inventory,resume_play)
	if not ok: return refuse(host.microscenario_error)
	_pending_request_serial = int(host.pending_microscenario_apply.serial)
	return true

func new_canvas() -> bool:
	if _liquids == null or _liquids.bridge == null: return refuse("Native policy interface unavailable.")
	if not applied.is_empty() and not host.simulation_worker.has_failed() and not _editable(): return false
	var size := Vector2i(int(_extent[0].value),int(_extent[1].value))
	var candidate := Setup.fresh(_liquids.bridge.default_liquid_policy(),size)
	if host.simulation_worker.has_failed(): return host.workbench_restart(candidate)
	return apply(candidate)

func installed(candidate: Dictionary) -> void:
	_pending_request_serial = 0
	applied = candidate.duplicate(true)
	var roster_choice := _model.selected
	_model.clear()
	for name_text: String in Fleet.names(): _model.add_item(name_text)
	_model.add_item("Passive barrel")
	_model.select(clampi(roster_choice,0,_model.item_count-1))
	_fill_roster()
	_reload_rollback.clear()
	var policy: Dictionary = host.tower_context.get("liquid_solver_policy",{})
	if policy.has("envelope"): applied.liquid_policy = Array(policy.envelope)
	_liquids.requested_policy = PackedInt32Array(applied.liquid_policy)
	_liquids._dirty = false
	_liquids._refresh_choices()
	_liquids.geometry_picker.select(1 if int(applied.rule_radius) == 3 else 0)
	_liquids.normalize_water.set_pressed_no_signal(false)
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
	var rounded_on_apply: bool = _liquid_action and bool(candidate.normalize)
	if not _actor_action.is_empty():
		_reveal_selected()
		var state := body_state(selected_id())
		message = "%s %s #%d at %s (session %d)." % [_actor_action,str(state.get("model","")).capitalize(),
			selected_id(),str(state.get("position","?")),host._physical_epoch]
		_actor_action = ""
	elif _liquid_action:
		_liquid_action = false
		message = "Liquid settings applied."
	else:
		message = "Choose a flyer to pilot, or use Place model to add an independent body."
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt",{}).get("workbench_conversion",{})
	message += _inventory_report(receipt,rounded_on_apply)


func _material_counts(counts: Dictionary) -> String:
	var names := PackedStringArray()
	var ids := counts.keys()
	ids.sort()
	for id: Variant in ids:
		var cells := int(counts[id])
		if cells > 0: names.append("%d %s" % [cells,host.material_name(int(id))])
	return ", ".join(names)


func _inventory_report(receipt: Dictionary, rounded_on_apply: bool) -> String:
	if receipt.is_empty(): return ""
	var halo := int(receipt.get("preserved_halo_cells",0))
	var clipped := int(receipt.get("clipped_material_cells",0))
	var losses := PackedStringArray()
	if clipped > 0:
		losses.append("%d cells beyond reserved storage (%s, %d visible Water units)" % [
			clipped,_material_counts(receipt.clipped_materials),int(receipt.clipped_visible_water)])
	# State can also be clipped from an Empty cell or gas compartment. These
	# counts are separate from the material ledger. Each clipped subset is
	# annotated on its total rather than counted twice.
	for field: Array in [["water_overfill","%d pressure overfill units"],["gas_amount","%d gas units"],
			["inertial_cells","inertial state in %d cells"],["pressure_flow_cells","pressure flow in %d cells"]]:
		var total := int(receipt.get("discarded_"+field[0],0))
		var beyond := int(receipt.get("clipped_"+field[0],0))
		if total > 0:
			var loss: String = field[1] % total
			if beyond > 0: loss += " (%d beyond storage)" % beyond
			losses.append(loss)
		elif beyond > 0:
			losses.append(field[1] % beyond + " beyond storage")
	if receipt.get("clipped_thermal_cells",0):
		losses.append("thermal state in %d cells beyond storage" % int(receipt.clipped_thermal_cells))
	if receipt.get("clipped_gas_labels",0):
		losses.append("%d gas labels beyond storage" % int(receipt.clipped_gas_labels))
	var added := int(receipt.get("normalization_produced",0))
	var removed := int(receipt.get("normalization_consumed",0))
	if not receipt.get("requested",false) and not rounded_on_apply and not added and not removed and halo == 0 and losses.is_empty(): return ""
	var report := " Water quantity %d → %d." % [int(receipt.water_before),int(receipt.water_after)]
	if rounded_on_apply or added or removed: report += " Rounding added %d and removed %d Water units." % [added,removed]
	if halo > 0:
		report += " Kept %d cells outside the canvas (%s), including %d visible Water units." % [
			halo,_material_counts(receipt.preserved_halo_materials),int(receipt.preserved_halo_visible_water)]
	if not losses.is_empty(): report += " Discarded " + ", ".join(losses) + "."
	return report


func _water_identity(context: Dictionary) -> String:
	for assignment: Dictionary in context.get("liquid_solver_policy",{}).get("assignments",[]):
		if int(assignment.material)==CyberCellWorld.WATER:
			return "%s/%s" % [str(assignment.applied_family).trim_suffix("_v1"),assignment.applied_variant]
	return "pending"


func _details_visibility_changed() -> void:
	if is_instance_valid(host):
		host.simulation_worker.set_worker_participation_sampling(_details.is_visible_in_tree())


func _participation_report(snapshot: CyberSimulationSnapshot) -> String:
	if snapshot == null: return "Waiting for the native worker."
	var requested := "Auto" if snapshot.native_worker_request <= 0 else str(snapshot.native_worker_request)
	var result := "%s · native pool %s" % [_processor_label,requested]
	var sample := snapshot.native_worker_participation
	if sample.is_empty() or sample.world_generation != snapshot.render_world_generation:
		return result + " · waiting for a completed tick sample."
	result += ", capacity %d" % int(sample.worker_capacity)
	result += "\nTick %d · %d task claimants (peak in one cell-update phase) · cell-update phase jobs %s" % [
		sample.completed_tick,sample.workers_observed,str(sample.phase_jobs)]
	if sample.has("native_tick_ms"):
		var elapsed: float = sample.native_tick_ms
		var budget_ms := 1000.0/60.0
		result += " · %.2f ms (%.0f%% of the %.2f ms tick budget)" % [elapsed,100.0*elapsed/budget_ms,budget_ms]
	return result + ". An inline owner counts as one claimant. CPU utilization is a separate measure."


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
	_sync_roster()
	if not installing:
		_reveal_selected()
		message = "Observer selected." if a.is_empty() else "Selected %s #%d." % [str(a.model).capitalize(),id]
	return true


func _reveal_selected() -> void:
	var state := body_state(selected_id())
	var visible_cells := Rect2(Vector2(host.camera_origin),Vector2(host.current_view_size))
	if not state.is_empty() and not visible_cells.grow(-8).has_point(state.position): focus_selected()


func _change_actor(candidate: Dictionary, id: int, label: String) -> bool:
	if not apply(candidate,true,id,false,not host.paused): return false
	_actor_action = label
	message = "Preparing %s #%d…" % [str(actor(candidate,id).model).capitalize(),id]
	return true


func pilot_model(model: String) -> bool:
	if busy() or applied.is_empty(): return refuse("Wait for the current owner transaction.")
	if not Fleet.valid_index(Fleet.index_for_id(model)): return refuse("Unknown pilot model.")
	var current := actor(applied,selected_id())
	if current.get("model","") == model: return select_instance(selected_id())
	for other: Dictionary in applied.actors:
		if other.model == model: return select_instance(int(other.id))
	if not current.is_empty() and current.model != Setup.BARREL:
		return _replace_actor(model)
	return place(model,entered_position())


func place(model: String, pos: Vector2) -> bool:
	if busy() or applied.is_empty(): return refuse("Wait for the current owner transaction.")
	var next := applied.duplicate(true)
	next.actors.append(Setup.instance(model,int(next.next_id),pos))
	next.selected = next.next_id
	next.next_id = int(next.next_id)+1
	return _change_actor(next,int(next.selected),"Placed")

func replace_selected() -> bool:
	if busy() or selected_id() == 0: return refuse("Select a body before replacing it.")
	return _replace_actor(model_choice())


func _replace_actor(model: String) -> bool:
	var next := applied.duplicate(true)
	var old := actor(next,selected_id())
	var replacement := Setup.instance(model,int(next.next_id),Setup.point(old.spawn))
	# A model change keeps the selected instance's applied comparison tuning.
	# Independent placement and the explicit Defaults action still use defaults.
	replacement.options = old.options.duplicate(true)
	next.actors[next.actors.find(old)] = replacement
	next.selected = next.next_id
	next.next_id = int(next.next_id)+1
	return _change_actor(next,int(next.selected),"Switched to")

func remove_selected() -> bool:
	if not _editable(): return false
	if selected_id() == 0: return refuse("Select an instance first.")
	var next := applied.duplicate(true)
	next.actors.erase(actor(next,selected_id()))
	next.selected = 0
	return apply(next,true,0,false,not host.paused)

func save_spawn() -> bool:
	if not _editable(): return false
	if selected_id() == 0: return refuse("Select an instance first.")
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
	if not _editable(): return false
	if selected_id() == 0: return refuse("Select an instance first.")
	var next := applied.duplicate(true)
	var pos := entered_position()
	actor(next,selected_id()).spawn = [pos.x,pos.y]
	return _change_actor(next,selected_id(),"Moved")

func reset_selected() -> bool:
	if host.simulation_worker.has_failed():
		return host.workbench_restart(applied)
	if selected_id() == 0: return refuse("Choose a flyer under Pilot or select an instance to reset.")
	return _change_actor(applied,selected_id(),"Reset")

func restore_start() -> bool:
	if applied.is_empty(): return refuse("No starting setup is installed.")
	if host.simulation_worker.has_failed(): return host.workbench_restart(applied)
	return apply(applied)

func apply_settings() -> bool:
	if not _editable(): return false
	var next := applied.duplicate(true)
	next.response = _requested_response
	var a := actor(next,selected_id())
	if not a.is_empty():
		for key: String in _fields: a.options[key] = _fields[key].value
	return apply(next,true,0,false,not host.paused)

func defaults() -> bool:
	if not _editable(): return false
	var next := applied.duplicate(true)
	next.response = Setup.RESPONSES[0]
	var a := actor(next,selected_id())
	if not a.is_empty(): a.options = Setup.DEFAULT_OPTIONS.duplicate()
	return apply(next,true,0,false,not host.paused)

func reload_definitions(manifest: String = Fleet.DEFAULT_MANIFEST) -> bool:
	if not _editable(): return false
	var previous := Fleet.registry_snapshot()
	if not Fleet.reload_definitions(manifest): return refuse(Fleet.last_error())
	var next := applied.duplicate(true)
	for a: Dictionary in next.actors:
		if a.model != Setup.BARREL: a.hash = Fleet.definition_hash(Fleet.index_for_id(a.model))
	if not apply(next,true,selected_id(),false,not host.paused):
		Fleet.restore_registry(previous)
		return false
	_reload_rollback = previous
	return true

func apply_liquids() -> bool:
	if busy() or applied.is_empty(): return refuse("Wait for the current owner transaction.")
	var next := applied.duplicate(true)
	var validation: Dictionary = _liquids.bridge.validate_liquid_policy(_liquids.requested_policy)
	if not validation.get("accepted",false): return refuse(str(validation.get("refusal",{})))
	next.liquid_policy = Array(_liquids.requested_policy)
	next.normalize = _liquids.normalize_water.button_pressed
	next.rule_radius = maxi(_liquids.geometry_picker.get_selected_id(),int(validation.receipt.get("minimum_rule_radius",2)))
	if not apply(next,true,0,true,not host.paused): return false
	_liquid_action = true
	message = "Preparing liquid settings…"
	return true

func save_setup() -> bool:
	if not _editable(): return false
	var error := Setup.write_named(_name.text,applied)
	if not error.is_empty(): return refuse(error)
	message = "Saved starting setup · " + _name.text
	return true

func load_setup() -> bool:
	if not host.simulation_worker.has_failed() and not _editable(): return false
	var result := Setup.read_named(_name.text)
	if result.has("error"): return refuse(result.error)
	if host.simulation_worker.has_failed(): return host.workbench_restart(result.setup)
	return apply(result.setup)

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
	if not host.paused: return refuse("Pause before requesting one step.")
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
		var current := _instances.selected-1
		var direction := -1 if event.shift_pressed else 1
		var next := posmod(current+direction,applied.actors.size())+1
		select_instance(_instances.get_item_id(next))
	elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
		var index: int = event.keycode-KEY_1
		if not Fleet.valid_index(index): return
		pilot_model(Fleet.stable_id(index))
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
	if _pending_request_serial > 0 and host.pending_microscenario_apply.is_empty():
		_pending_request_serial = 0
		_actor_action = ""
		_liquid_action = false
		_saved_view.clear()
		_sync_roster()
		refuse(host.microscenario_error if not host.microscenario_error.is_empty() else "The requested change was not installed.")
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
	var reason: String = message
	# Show a current fault separately. Completed request errors are consumed
	# once above; an old rejection must not follow later successful actions.
	var owner_error: String = context.get("workbench_refusal","")
	if host.latest_snapshot != null and host.latest_snapshot.simulation_failed:
		owner_error = host.latest_snapshot.last_tick_error
	if not owner_error.is_empty() and not reason.contains(owner_error):
		reason += " · " + owner_error
	_status.text = "%s · cell %s · %s · %s   |   source %d inserted / %d blocked" % [
		state,cursor,str(applied.get("extent","")),reason,int(source.get("inserted",0)),int(source.get("blocked",0))]
	_status.text += " · granular %s · active Water %s" % [gcr.get("response","pending"),_water_identity(context)]
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
		_detail_label.text += "\n" + _participation_report(host.latest_snapshot)
