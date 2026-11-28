extends Window

signal interaction_mode_requested(mode: String)
signal manipulation_settings_requested(settings: Dictionary)
signal capacity_requested(config: Dictionary)
signal demo_requested(kind: String, count: int)
signal placement_requested(instance_id: int, position: Vector2, rotation_degrees: float)
signal tuning_requested(instance_id: int, options: Dictionary)

# A lazy inspector over the ordinary Workbench's existing actor/session owner.
# Visibility has no effect on controller scheduling or physics lifetime.
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Usables = preload("res://scripts/usable_catalog.gd")
const AmbientExamples = preload("res://scripts/ambient/ambient_examples.gd")
const SOURCE_LABELS := {"human":"Human / Pilot", "scripted":"Scripted NPC",
	"policy":"External Policy", "passive":"Passive / Uncontrolled"}
var wb: Control
var family := OptionButton.new()
var model := OptionButton.new()
var instances := OptionButton.new()
var source := OptionButton.new()
var enabled := CheckButton.new()
var cadence := SpinBox.new()
var policy := OptionButton.new()
var usable := OptionButton.new()
var catalogue_info := Label.new()
var pilot_info := Label.new()
var status := Label.new()
var observation := TextEdit.new()
var command := TextEdit.new()
var details := VBoxContainer.new()
var tabs := TabContainer.new()
var pages: Dictionary = {}
var interaction_mode := OptionButton.new()
var operation_info := Label.new()
var apply_info := Label.new()
var demo := OptionButton.new()
var demo_count := SpinBox.new()
var stiffness := SpinBox.new()
var damping := SpinBox.new()
var max_force := SpinBox.new()
var snap := CheckButton.new()
var grid_size := SpinBox.new()
var rotation_step := SpinBox.new()
var fine_step := SpinBox.new()
var placement_x := SpinBox.new()
var placement_y := SpinBox.new()
var placement_angle := SpinBox.new()
var logical_limit := SpinBox.new()
var body_limit := SpinBox.new()
var proxy_limit := SpinBox.new()
var capacity_info := Label.new()
var capacity_limit_info := Label.new()
var diagnostics := TextEdit.new()
var tuning: Dictionary = {}
var _tuning_id := -1
var _tuning_dirty := false
var _sandbox_state: Dictionary = {}
var _settings_dirty := false
var _capacity_dirty := false
var _placement_dirty := false
var _placement_id := -1
var _models: Array[String] = []
var _last_refresh := 0
var _shown_id := -1
var _shown_control: Dictionary = {}
var _roster_key := ""
var _issued: Dictionary = {}
var _apply_requests: Dictionary = {}
var _edit_versions := {"settings":0,"capacity":0,"tuning":0,"placement":0}
var _last_apply_kind := ""
var _ambient_examples := OptionButton.new()


func mount(workbench: Control) -> void:
	wb = workbench
	title = "CyberSand / Workbench Configuration"
	size = Vector2i(760,700)
	min_size = Vector2i(600,440)
	transient = true
	exclusive = false
	close_requested.connect(_close_and_focus)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	margin.add_child(column)
	var row: Control = wb._row(column)
	wb._label(row,"Pointer")
	for entry: Array in [["Paint","paint"],["Grab physical part","grab"],["Place whole actor (paused)","place"],["Other Workbench tool","inspect"]]:
		interaction_mode.add_item(entry[0])
		interaction_mode.set_item_metadata(interaction_mode.item_count-1,entry[1])
	interaction_mode.set_item_disabled(3,true)
	row.add_child(interaction_mode)
	interaction_mode.item_selected.connect(func(index: int) -> void:
		interaction_mode_requested.emit(str(interaction_mode.get_item_metadata(index))))
	wb._button(row,"Play / Pause",wb.toggle_pause)
	wb._button(row,"Close",_close_and_focus)
	pilot_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(pilot_info)
	operation_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(operation_info)
	apply_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(apply_info)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	for caption: String in ["Actors","Controllers","Equipment","Physics","Capacity","Diagnostics"]:
		_page(caption)
	_build_actors(pages.Actors)
	_build_controllers(pages.Controllers)
	_build_equipment(pages.Equipment)
	_build_physics(pages.Physics)
	_build_capacity(pages.Capacity)
	_build_diagnostics(pages.Diagnostics)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 40
	column.add_child(status)
	_fill_models()
	refresh(true)


func _close_and_focus() -> void:
	# After closing a native Configuration window, restore keyboard focus
	# explicitly to the playable parent. Do not steal focus on app switching.
	hide()
	if wb != null and is_instance_valid(wb.host):
		wb.host.get_window().grab_focus()


func _page(caption: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = caption
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	scroll.add_child(column)
	pages[caption] = column


func _note(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _build_actors(column: Control) -> void:
	_note(column,"Explore a prepared playground, or compose your own. Loading a playground replaces the current authored start; save your work first.")
	var row: Control = wb._row(column)
	for entry: Array in [["Living Mixed Workshop","mixed"],["Barrel Crowd","barrels"],["Mechanical Chaos","mechanical"]]:
		demo.add_item(entry[0])
		demo.set_item_metadata(demo.item_count-1,entry[1])
	row.add_child(demo)
	wb._spin(row,"Crowd count",demo_count,1,256,1,64)
	demo_count.tooltip_text = "Barrel Crowd population. Other examples use their authored cast. Higher counts are experiments, not frame-rate promises."
	wb._button(row,"Load playground",func() -> void:
		demo_requested.emit(str(demo.get_item_metadata(demo.selected)),int(demo_count.value)))
	wb._button(row,"Mixed Actor Workshop",func() -> void: wb.load_mixed_actor_workshop())
	row = wb._row(column)
	wb._label(row, "Ambient examples")
	for example: Dictionary in AmbientExamples.entries():
		_ambient_examples.add_item(str(example.name))
		_ambient_examples.set_item_metadata(_ambient_examples.item_count - 1, example.id)
	row.add_child(_ambient_examples)
	wb._button(row, "Load scene", func() -> void:
		if _ambient_examples.selected >= 0: wb.load_ambient_example(str(_ambient_examples.get_item_metadata(_ambient_examples.selected))))
	row = wb._row(column)
	wb._label(row,"Family")
	family.add_item("All physical actors")
	for id: String in Catalog.ids():
		var label: String = Catalog.entry(id).get("family","")
		var found := false
		for i: int in family.item_count:
			if family.get_item_text(i) == label: found = true
		if not found: family.add_item(label)
	row.add_child(family)
	family.item_selected.connect(func(_index: int) -> void: _fill_models())
	row = wb._row(column)
	row.add_child(model)
	model.fit_to_longest_item = false
	model.clip_text = true
	model.get_popup().max_size = Vector2i(700,450)
	model.custom_minimum_size.x = 280
	model.item_selected.connect(func(_index: int) -> void: _model_info())
	wb._button(row,"Place at Workbench X/Y",_place)
	wb._button(row,"Replace inspected",_replace)
	catalogue_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(catalogue_info)
	row = wb._row(column)
	wb._label(row,"Inspect")
	instances.custom_minimum_size.x = 280
	instances.fit_to_longest_item = false
	instances.clip_text = true
	instances.get_popup().max_size = Vector2i(700,450)
	row.add_child(instances)
	instances.item_selected.connect(func(index: int) -> void:
		wb.select_instance(instances.get_item_id(index))
		refresh(true))
	wb._button(row,"Focus",wb.focus_selected)
	wb._button(row,"Reset",wb.reset_selected)
	wb._button(row,"Remove",wb.remove_selected)
	_note(column,"Inspection keeps the current pilot and NPC sources. Reset, replacement, equipment Apply and authored placement prepare a new owner before changing the applied composition.")
	row = wb._row(column)
	wb._spin(row,"Spawn X",placement_x,0,16384,0.25,0)
	wb._spin(row,"Y",placement_y,0,16384,0.25,0)
	wb._spin(row,"Angle °",placement_angle,-180,180,0.25,0)
	for field: SpinBox in [placement_x,placement_y,placement_angle]:
		field.value_changed.connect(func(_value: float) -> void: _mark_dirty("placement"))
	row = wb._row(column)
	wb._button(row,"Apply authored placement (paused)",_apply_placement)
	wb._button(row,"Read current pose",_read_current_pose)
	_note(column,"Pause and choose Place whole actor to drag on the canvas. Q/E rotate, Shift uses fine steps, Escape cancels. Release commits once. Save start stores authored position and orientation, not live momentum or ragdoll deformation.")


func _build_controllers(column: Control) -> void:
	_note(column,"Inspect and pilot are separate. Only explicit pilot controls transfer human authority. Opening this window releases held human inputs while unrelated NPCs continue.")
	var row: Control = wb._row(column)
	wb._button(row,"Pilot inspected",func() -> void:
		wb.pilot_instance(wb.selected_id())
		refresh(true))
	wb._button(row,"Hand back",func() -> void:
		wb.hand_back_pilot()
		refresh(true))
	wb._button(row,"Release pilot",func() -> void:
		wb.release_pilot()
		refresh(true))
	row = wb._row(column)
	wb._label(row,"Controller")
	row.add_child(source)
	source.item_selected.connect(func(_index: int) -> void: _apply_control())
	enabled.text = "Decisions enabled"
	row.add_child(enabled)
	enabled.toggled.connect(func(_value: bool) -> void: _apply_control())
	row = wb._row(column)
	wb._spin(row,"Decision interval (physics ticks)",cadence,1,12,1,6)
	wb._button(row,"Apply interval",_apply_control)
	row = wb._row(column)
	policy.add_item("Deterministic test producer")
	policy.add_item("External submissions")
	row.add_child(policy)
	policy.item_selected.connect(func(_index: int) -> void: _apply_control())
	_note(column,"Live source changes preserve bodies and equipment. A grabbed actor temporarily stops its drive; release resumes its compatible source. External Policy is an adapter, not a running model or network service.")
	wb._button(row, "Behaviour profile…", func() -> void: wb.open_ambient_profile(wb.selected_id()))
	row = wb._row(column)
	wb._button(row,"Advanced observations and policy…",func() -> void: details.visible = not details.visible)
	column.add_child(details)
	details.hide()
	_note(details,"Copied physical observations only. Issue a fresh observation, edit its command values, then submit while running. Late, foreign and retired replies are refused by the session.")
	row = wb._row(details)
	wb._button(row,"Issue observation",_issue)
	wb._button(row,"Submit command",_submit)
	wb._button(row,"Send fresh test action",_fresh_test_action)
	observation.editable = false
	observation.custom_minimum_size.y = 180
	details.add_child(observation)
	command.custom_minimum_size.y = 170
	command.placeholder_text = "Issue observation to prepare an authorized command."
	details.add_child(command)


func _build_equipment(column: Control) -> void:
	_note(column,"Starting loadout belongs to the saved composition. Applying it prepares a replacement session and restarts controller/resource state; live source handoff preserves the current item.")
	var row: Control = wb._row(column)
	wb._label(row,"Mounted equipment")
	usable.add_item("None",-1)
	for index: int in Usables.count(): usable.add_item(Usables.name_for(index),index)
	row.add_child(usable)
	wb._button(row,"Apply equipment / restart",func() -> void: wb.apply_actor_equipment(wb.selected_id(),usable.get_selected_id()))
	_note(column,"Human equipment: M / Alt use, N drop, U attach. The pointer remains reserved for the chosen canvas tool. A released equipment body retains its actual body/proxy allocation. Unsupported mounts refuse instead of inventing an attachment.")


func _build_physics(column: Control) -> void:
	_note(column,"Live Grab pulls the clicked physical part with a bounded damped force. Joints and collisions remain active. A temporary grab is never saved as authored placement.")
	var row: Control = wb._row(column)
	wb._spin(row,"Stiffness",stiffness,5,2400,5,160)
	wb._spin(row,"Damping",damping,0,160,1,24)
	row = wb._row(column)
	wb._spin(row,"Maximum force",max_force,10,1000000,10,24000)
	stiffness.tooltip_text = "Mass-normalized spring response, in s⁻². Higher values pull more strongly."
	damping.tooltip_text = "Velocity damping, in s⁻¹. Reduces oscillation while retaining physical motion."
	max_force.tooltip_text = "Absolute force cap in mass × cell/s². Unsafe or nonfinite settings are refused."
	_note(column,"Paused Place transforms the whole assembly. The preview does no native preparation until commit. Bounds or preparation refusal leaves the applied world intact.")
	row = wb._row(column)
	snap.text = "Snap to grid"
	row.add_child(snap)
	wb._spin(row,"Grid cells",grid_size,0.25,256,0.25,8)
	row = wb._row(column)
	wb._spin(row,"Rotate step °",rotation_step,0.25,180,0.25,15)
	wb._spin(row,"Fine move cells",fine_step,0.01,16,0.01,1)
	for field: SpinBox in [stiffness,damping,max_force,grid_size,rotation_step,fine_step]:
		field.value_changed.connect(func(_value: float) -> void: _mark_dirty("settings"))
	snap.toggled.connect(func(_pressed: bool) -> void: _mark_dirty("settings"))
	row = wb._row(column)
	wb._button(row,"Apply manipulation settings",_apply_settings)
	_note(column,"Inspected actor tuning — changes prepare a replacement owner and restart controller/resource state. Model-incompatible controls are disabled. The shared material response law stays unchanged.")
	row = wb._row(column)
	for key: String in Setup.DEFAULT_OPTIONS:
		var low := 5.0 if key == "budget" else (1.0 if key == "boost_multiplier" else (0.01 if key in ["mass_multiplier","inertia_multiplier"] else 0.0))
		var high := 80.0 if key == "budget" else (8.0 if key == "boost_multiplier" else 64.0)
		var field := SpinBox.new()
		tuning[key] = field
		wb._spin(row,key.replace("_multiplier"," ×").capitalize(),field,low,high,1.0 if key == "budget" else 0.01,Setup.DEFAULT_OPTIONS[key])
		field.value_changed.connect(func(_value: float) -> void: _mark_dirty("tuning"))
	row = wb._row(column)
	wb._button(row,"Apply actor tuning / restart",_apply_tuning)
	_note(column,"Live Paint retains the existing Brush, Eraser and right-button erasing. Pause for Line, Rectangle, Fill, selection, Paste and Undo/Redo. Grab and Place own the pointer exclusively; close this window to interact with the canvas.")


func _build_capacity(column: Control) -> void:
	_note(column,"Choose the population ceiling independently from physical-body and native-mask budgets. A barrel consumes one real body; multipart machines and compound flyers use their actual allocations.")
	var row: Control = wb._row(column)
	wb._spin(row,"Logical actors",logical_limit,1,4096,1,8)
	row = wb._row(column)
	wb._spin(row,"Response bodies",body_limit,1,4096,1,64)
	wb._spin(row,"Native masks",proxy_limit,1,4096,1,64)
	for field: SpinBox in [logical_limit,body_limit,proxy_limit]:
		field.value_changed.connect(func(_value: float) -> void: _mark_dirty("capacity"))
	row = wb._row(column)
	wb._label(row,"Stage preset")
	for count: int in [16,32,64,128,256]:
		wb._button(row,str(count),func() -> void: stage_capacity_preset(count))
	row = wb._row(column)
	wb._button(row,"Apply capacity",_apply_capacity)
	capacity_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(capacity_info)
	capacity_limit_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(capacity_limit_info)
	_note(column,"Large populations can be extremely slow. Actors, controllers, joints and equipment are not automatically removed to recover FPS. Only real allocation, identity and native-structure limits refuse. The saved composition retains the capacity required to reopen it.")


func _build_diagnostics(column: Control) -> void:
	_note(column,"Current source, physical part and capacity receipts. Prepared-owner operations are asynchronous; a pending request is not a completed placement. Native publication stalls and actor/controller costs are separate measurements.")
	diagnostics.editable = false
	diagnostics.custom_minimum_size = Vector2(0,300)
	diagnostics.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(diagnostics)


func stage_capacity_preset(count: int) -> void:
	logical_limit.value = count
	body_limit.value = mini(int(body_limit.max_value),maxi(int(body_limit.value),count * Catalog.MAX_PARTS))
	proxy_limit.value = mini(int(proxy_limit.max_value),maxi(int(proxy_limit.value),count * Catalog.MAX_PARTS))
	_mark_dirty("capacity")


func _apply_settings() -> void:
	var values := _staged_values("settings")
	_begin_apply("settings",values)
	manipulation_settings_requested.emit(values.duplicate(true))
	_poll_apply("settings")


func _apply_capacity() -> void:
	var values := _staged_values("capacity")
	_begin_apply("capacity",values)
	capacity_requested.emit(values.duplicate(true))
	_poll_apply("capacity")


func _apply_tuning() -> void:
	var id: int = wb.selected_id()
	var values := _staged_values("tuning")
	_begin_apply("tuning",values,id)
	tuning_requested.emit(id,values.duplicate(true))
	_poll_apply("tuning")


func _apply_placement() -> void:
	var id: int = wb.selected_id()
	var values := _staged_values("placement")
	_begin_apply("placement",values,id)
	placement_requested.emit(id,Vector2(values.x,values.y),float(values.angle))
	_poll_apply("placement")


func _read_current_pose() -> void:
	var state: Dictionary = wb.actor_placement_pose(wb.selected_id())
	if state.is_empty():
		wb.refuse("Select an installed actor before reading its current pose.")
		return
	var position: Vector2 = state.get("position",Vector2.ZERO)
	placement_x.value = position.x
	placement_y.value = position.y
	placement_angle.value = wrapf(rad_to_deg(float(state.get("rotation",0.0))),-180.0,180.0)
	_mark_dirty("placement")


func _editing(fields: Array) -> bool:
	for field: SpinBox in fields:
		if field.get_line_edit().has_focus(): return true
	return false


func _mark_dirty(kind: String) -> void:
	_edit_versions[kind] = int(_edit_versions[kind])+1
	match kind:
		"settings": _settings_dirty = true
		"capacity": _capacity_dirty = true
		"tuning": _tuning_dirty = true
		"placement": _placement_dirty = true
	if _last_apply_kind == kind:
		apply_info.text = "%s · New values staged; Apply again to request them." % kind.capitalize()


func _staged_values(kind: String) -> Dictionary:
	match kind:
		"settings":
			return {"stiffness":stiffness.value,"damping":damping.value,
				"max_force":max_force.value,"snap_enabled":snap.button_pressed,"grid_size":grid_size.value,
				"rotation_step":rotation_step.value,"fine_step":fine_step.value}
		"capacity":
			return {"version":1,"logical_limit":int(logical_limit.value),"body_limit":int(body_limit.value),
				"proxy_limit":int(proxy_limit.value)}
		"tuning":
			var options: Dictionary = {}
			for key: String in tuning: options[key] = tuning[key].value
			return options
		"placement":
			return {"x":placement_x.value,"y":placement_y.value,"angle":placement_angle.value}
	return {}


func _accepted_values(kind: String, state: Dictionary, id: int) -> Dictionary:
	match kind:
		"settings": return state.get("settings",{})
		"capacity": return state.get("capacity",{})
		"tuning", "placement":
			var actor_data: Dictionary = wb.actor(wb.applied,id)
			if actor_data.is_empty(): return {}
			if kind == "tuning": return actor_data.get("options",Setup.DEFAULT_OPTIONS)
			if not actor_data.has("spawn"): return {}
			return {"x":float(actor_data.spawn[0]),"y":float(actor_data.spawn[1]),
				"angle":float(actor_data.get("spawn_rotation_degrees",0.0))}
	return {}


func _same_values(expected: Dictionary, actual: Dictionary) -> bool:
	if expected.is_empty(): return false
	for key: String in expected:
		if not actual.has(key): return false
		var a: Variant = expected[key]
		var b: Variant = actual[key]
		if a is bool or b is bool:
			if a != b: return false
		elif key == "angle" and expected.has("x") and expected.has("y") \
				and (a is float or a is int) and (b is float or b is int):
			# The physical commit normalizes +180° to -180°. These are the
			# same authored orientation, not a failed asynchronous Apply.
			if absf(wrapf(float(a)-float(b),-180.0,180.0)) > 0.01: return false
		elif key in ["x","y"] and expected.has("angle") \
				and (a is float or a is int) and (b is float or b is int):
			# Spawn controls offer quarter-cell precision even near the 16k
			# canvas bound; relative float equality is too loose there.
			if absf(float(a)-float(b)) > 0.01: return false
		elif (a is float or a is int) and (b is float or b is int):
			if not is_equal_approx(float(a),float(b)): return false
		elif a != b:
			return false
	return true


func _owner_run_id() -> String:
	if wb == null or wb.host == null or wb.host.physical_actor_session == null: return ""
	return str(wb.host.physical_actor_session.run_id)


func _begin_apply(kind: String, values: Dictionary, id: int = -1) -> void:
	_last_apply_kind = kind
	_apply_requests[kind] = {"values":values.duplicate(true),"actor_id":id,
		"edit_version":int(_edit_versions[kind]),"phase":"issued","saw_preparing":false,
		"run_id":_owner_run_id(),"message_before":str(wb.message)}
	apply_info.text = "%s · Requested; awaiting actual adoption acknowledgement." % kind.capitalize()


func _preparation_message_matches(kind: String, id: int, message: String) -> bool:
	match kind:
		"capacity": return message.begins_with("Preparing capacity")
		"tuning": return message.begins_with("Preparing physical tuning for #%d" % id)
		"placement": return message.begins_with("Preparing #%d placement" % id)
	return false


func _poll_apply(kind: String) -> void:
	if wb.has_method("actor_sandbox_state"):
		set_sandbox_state(wb.call("actor_sandbox_state"))
	else:
		_observe_apply(kind,_sandbox_state)


func _focused_apply(kind: String) -> bool:
	match kind:
		"settings": return _editing([stiffness,damping,max_force,grid_size,rotation_step,fine_step])
		"capacity": return _editing([logical_limit,body_limit,proxy_limit])
		"tuning": return _editing(tuning.values())
		"placement": return _editing([placement_x,placement_y,placement_angle])
	return false


func _clear_adopted_stage(kind: String, request: Dictionary) -> bool:
	# An earlier acknowledgement must never erase an edit made while it was pending.
	if int(request.edit_version) != int(_edit_versions[kind]) or _focused_apply(kind):
		return false
	if not _same_values(request.values,_staged_values(kind)): return false
	match kind:
		"settings": _settings_dirty = false
		"capacity": _capacity_dirty = false
		"tuning": _tuning_dirty = false
		"placement": _placement_dirty = false
	return true


func _apply_feedback(kind: String, detail: String) -> void:
	if _last_apply_kind == kind: apply_info.text = "%s · %s" % [kind.capitalize(),detail]


func _observe_apply(kind: String, state: Dictionary) -> void:
	if not _apply_requests.has(kind): return
	var request: Dictionary = _apply_requests[kind]
	if str(request.phase) in ["accepted","rejected","failed","invalidated"]: return
	if kind in ["tuning","placement"] and int(request.actor_id) != wb.selected_id():
		_last_apply_kind = kind
		request.phase = "invalidated"
		_apply_feedback(kind,"Inspection changed; request for #%d is not an acknowledgement for #%d. New actor fields are independent." % [int(request.actor_id),wb.selected_id()])
		return
	var message := str(wb.message)
	# A second Apply can be synchronously refused while an unrelated owner
	# transaction is already pending; only a request not yet admitted can
	# receive that synchronous refusal. Later unrelated refusals cannot
	# cancel a request whose own preparation has already started.
	if not bool(request.saw_preparing) and message.begins_with("Refused") and message != str(request.message_before):
		request.phase = "rejected"
		_apply_feedback(kind,"%s · Proposed values retained." % message)
		return
	var pending := bool(state.get("preparing",false))
	if pending and kind != "settings" and (\
		bool(request.saw_preparing) or _preparation_message_matches(kind,int(request.actor_id),message)):
		request.phase = "pending"
		request.saw_preparing = true
		_apply_feedback(kind,"Pending prepared-owner transaction; nothing installed yet.")
		return
	var accepted: Dictionary = _accepted_values(kind,state,int(request.actor_id))
	var owner_changed := not str(request.run_id).is_empty() and not _owner_run_id().is_empty() and _owner_run_id() != str(request.run_id)
	# Capacity/tuning/placement are asynchronous: matching old data alone is
	# not a receipt. The corresponding owner preparation must have been observed.
	var adopted := kind == "settings" or bool(request.saw_preparing)
	if not pending and adopted and _same_values(request.values,accepted):
		request.phase = "accepted"
		var cleared := _clear_adopted_stage(kind,request)
		_apply_feedback(kind,"Accepted in applied configuration." if cleared else "Previous Apply accepted; newer/focused edits remain staged.")
		return
	if bool(request.saw_preparing):
		request.phase = "failed"
		_apply_feedback(kind,"Owner did not adopt the proposal; staged values retained. "+message)
	elif owner_changed:
		request.phase = "invalidated"
		_apply_feedback(kind,"Owner/session changed without matching adoption; staged values retained.")
	else:
		_apply_feedback(kind,"Issued; awaiting accepted configuration or a preparation receipt.")


func set_sandbox_state(state: Dictionary) -> void:
	_sandbox_state = state.duplicate(true)
	var mode := str(state.get("mode","paint"))
	for index: int in interaction_mode.item_count:
		if str(interaction_mode.get_item_metadata(index)) == mode: interaction_mode.select(index)
	var pending := bool(state.get("preparing",false))
	var paused: bool = wb.host.paused if wb != null and wb.host != null else true
	var hints := {"paint":"Brush / Eraser live; precision shapes and history require Pause.",
		"grab":"Running: drag an individual part with physics. Release or Escape ends the grab.",
		"place":"Paused: drag the complete actor; Q/E rotate, Shift fine, Escape cancel.",
		"inspect":"Other Workbench canvas tool selected; inspection does not transfer the pilot."}
	operation_info.text = "Preparing owner…" if pending else "%s · %s" % ["Paused" if paused else "Running",hints.get(mode,mode)]
	var settings: Dictionary = state.get("settings",{})
	if not _settings_dirty and not _editing([stiffness,damping,max_force,grid_size,rotation_step,fine_step]):
		for item: Array in [["stiffness",stiffness],["damping",damping],["max_force",max_force],
				["grid_size",grid_size],["rotation_step",rotation_step],["fine_step",fine_step]]:
			if settings.has(item[0]): item[1].set_value_no_signal(float(settings[item[0]]))
		if settings.has("snap_enabled"): snap.set_pressed_no_signal(bool(settings.snap_enabled))
	var capacity: Dictionary = state.get("capacity",{})
	for item: Array in [["max_logical",logical_limit],["max_bodies",body_limit],["max_proxies",proxy_limit]]:
		if capacity.has(item[0]): item[1].max_value = int(capacity[item[0]])
	if capacity.has("max_logical"): demo_count.max_value = int(capacity.max_logical)
	if not _capacity_dirty and not _editing([logical_limit,body_limit,proxy_limit]):
		for item: Array in [["logical_limit",logical_limit],["body_limit",body_limit],["proxy_limit",proxy_limit]]:
			if capacity.has(item[0]): item[1].set_value_no_signal(int(capacity[item[0]]))
	capacity_info.text = "Current: %d actors · %d bodies · %d native masks · %d authored joints\nAvailable: %d actor slots · %d bodies · %d masks" % [
		int(capacity.get("actors",0)),int(capacity.get("bodies",0)),int(capacity.get("proxies",0)),int(capacity.get("joints",0)),
		maxi(0,int(capacity.get("logical_limit",0))-int(capacity.get("actors",0))),
		maxi(0,int(capacity.get("body_limit",0))-int(capacity.get("bodies",0))),
		maxi(0,int(capacity.get("proxy_limit",0))-int(capacity.get("proxies",0)))]
	capacity_limit_info.text = str(capacity.get("limit_reason","Budgets are checked before preparation; rejected changes keep the current world."))
	diagnostics.text = JSON.stringify(_json(state),"  ")
	_observe_apply("settings",state)
	_observe_apply("capacity",state)
	_observe_apply("tuning",state)
	_observe_apply("placement",state)


func _fill_models() -> void:
	_models.clear()
	model.clear()
	for id: String in Catalog.ids():
		var entry := Catalog.entry(id)
		if family.selected > 0 and entry.family != family.get_item_text(family.selected): continue
		_models.append(id)
		model.add_item(entry.name)
	_model_info()


func _model_info() -> void:
	if model.selected < 0: return
	var entry := Catalog.entry(_models[model.selected])
	catalogue_info.text = "%s · %s\n%s\n%d physical parts / %d native masks · %s" % [entry.name,entry.family,
		entry.description,entry.parts,entry.proxy_count,", ".join(entry.capabilities)]
	catalogue_info.tooltip_text = entry.controls + "\n" + "\n".join(entry.limitations)


func _place() -> void:
	if model.selected >= 0: wb.place(_models[model.selected],wb.entered_position())


func _replace() -> void:
	if model.selected >= 0 and wb.selected_id() > 0: wb._replace_actor(_models[model.selected])


func _apply_control() -> void:
	var a: Dictionary = wb.actor(wb.applied,wb.selected_id())
	if a.is_empty() or source.selected < 0: return
	var config := Catalog.control_for(a)
	var choice := str(source.get_item_metadata(source.selected))
	config.source = "policy" if choice == "ambient" else choice
	config.enabled = enabled.button_pressed
	config.decision_ticks = int(cadence.value)
	config.policy = "ambient" if choice == "ambient" else ("fixture" if policy.selected == 0 else "external")
	if choice == "ambient" and not config.has("ambient"):
		config["ambient"] = Catalog.AmbientProfile.preset("drifting_flyer" if bool(Catalog.AmbientActuator.capabilities(str(a.model)).vertical) else "oil_moth")
	wb.set_actor_control(int(a.id),config)
	refresh(true)


func refresh(force: bool = false) -> void:
	if wb == null: return
	var inspected: int = wb.selected_id()
	var key := ""
	for a: Dictionary in wb.applied.get("actors",[]): key += "%s:%s;" % [a.id,a.model]
	if force or key != _roster_key:
		_roster_key = key
		instances.clear()
		instances.add_item("No inspected actor",0)
		for a: Dictionary in wb.applied.get("actors",[]):
			instances.add_item("#%d · %s" % [a.id,Catalog.entry(a.model).get("name",a.model)],a.id)
	instances.select(maxi(0,instances.get_item_index(inspected)))
	var a: Dictionary = wb.actor(wb.applied,inspected)
	if _tuning_id > 0 and _tuning_id != inspected and _tuning_dirty:
		_last_apply_kind = "tuning"
		_apply_feedback("tuning","Unapplied tuning for #%d was discarded when inspecting #%d." % [_tuning_id,inspected])
	if _placement_id > 0 and _placement_id != inspected and _placement_dirty:
		_last_apply_kind = "placement"
		_apply_feedback("placement","Unapplied placement for #%d was discarded when inspecting #%d." % [_placement_id,inspected])
	if _tuning_id != inspected or (not _tuning_dirty and not _editing(tuning.values())):
		_tuning_id = inspected
		var options: Dictionary = a.get("options",Setup.DEFAULT_OPTIONS)
		var fleet_tuning := Catalog.Fleet.index_for_id(str(a.get("model",""))) >= 0
		var flight_plant := str(a.get("model","")) in Catalog.Flight.IDS
		for option_key: String in tuning:
			tuning[option_key].set_value_no_signal(float(options.get(option_key,Setup.DEFAULT_OPTIONS[option_key])))
			tuning[option_key].editable = not a.is_empty() and (fleet_tuning or option_key == "budget" or (not flight_plant and option_key in ["mass_multiplier","inertia_multiplier"]))
		_tuning_dirty = false
	if _placement_id != inspected or (not _placement_dirty and not _editing([placement_x,placement_y,placement_angle])):
		_placement_id = inspected
		if not a.is_empty():
			placement_x.set_value_no_signal(float(a.spawn[0]))
			placement_y.set_value_no_signal(float(a.spawn[1]))
			placement_angle.set_value_no_signal(float(a.get("spawn_rotation_degrees",0.0)))
		_placement_dirty = false
	if wb.has_method("actor_sandbox_state"):
		set_sandbox_state(wb.call("actor_sandbox_state"))
	_observe_apply("tuning",_sandbox_state)
	_observe_apply("placement",_sandbox_state)
	if _shown_id != inspected:
		_issued.clear()
		observation.text = "No inspected actor." if a.is_empty() else ""
	var config: Dictionary = {} if a.is_empty() else Catalog.control_for(a)
	if force or _shown_id != inspected or config != _shown_control:
		_shown_id = inspected
		_shown_control = config.duplicate(true)
		source.clear()
		if not a.is_empty():
			for mode: String in Catalog.entry(a.model).controllers:
				source.add_item(SOURCE_LABELS[mode])
				source.set_item_metadata(source.item_count-1,mode)
				if mode == config.source: source.select(source.item_count-1)
			if Catalog.AmbientActuator.supports(str(a.model)):
				source.add_item("Procedural NPC / Ambient")
				source.set_item_metadata(source.item_count - 1, "ambient")
				if config.source == "policy" and config.policy == "ambient": source.select(source.item_count - 1)
			enabled.set_pressed_no_signal(config.enabled)
			cadence.set_value_no_signal(config.decision_ticks)
			policy.select(0 if config.policy == "fixture" else 1)
			policy.visible = config.source == "policy" and config.policy != "ambient"
			usable.select(maxi(0,usable.get_item_index(int(config.usable_index))))
			usable.disabled = not bool(Catalog.entry(a.model).equipment)
	pilot_info.text = "Pilot: %s · Inspecting: %s" % [wb.pilot_description(),"none" if a.is_empty() else "#%d %s" % [inspected,a.model]]
	status.text = wb.message
	if not a.is_empty() and wb.host.physical_actor_session != null:
		var control: Dictionary = wb.host.physical_actor_session.workbench_control(inspected)
		status.text = "#%d %s · %s · decisions %d ticks · lease %d ticks\nAccepted %d / refused %d · %s\n%s" % [inspected,a.model,
			str(control.get("status","waiting")),int(control.get("decision_ticks",6)),int(control.get("lease_remaining",0)),
			int(control.get("accepted",0)),int(control.get("rejected",0)),str(control.get("error","")),wb.message]
		if details.visible and _issued.is_empty(): observation.text = JSON.stringify(_json(wb.actor_observation(inspected,false)),"  ")


func _issue() -> void:
	_issued = wb.actor_observation(wb.selected_id(),true)
	if _issued.is_empty():
		observation.text = "Select an External Policy actor with external submissions enabled, then Play."
		return
	observation.text = JSON.stringify(_json(_issued),"  ")
	var action := {"move":Vector2(0.5,0)}
	var packet: Dictionary = wb.host.physical_actor_session.make_command(_issued,int(_issued.get("last_sequence",-1))+1,action,12)
	command.text = JSON.stringify(_json(packet),"  ")


func _submit() -> void:
	var packet: Variant = JSON.parse_string(command.text)
	if not packet is Dictionary:
		wb.refuse("Policy command must be a JSON object.")
		return
	if packet.get("action") is Dictionary:
		for key: String in ["move","aim"]:
			var value: Variant = packet.action.get(key)
			if value is Array and value.size() == 2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float):
				packet.action[key] = Vector2(value[0],value[1])
	wb.submit_actor_policy(wb.selected_id(),packet)
	refresh()


func _fresh_test_action() -> void:
	# This is explicitly a local test producer, not a way to rebind a delayed
	# external reply. The remote-command button above preserves its issued ID.
	var packet: Variant = JSON.parse_string(command.text)
	if not packet is Dictionary or not packet.get("action") is Dictionary:
		wb.refuse("Issue an observation first, then enter the test action values.")
		return
	var view: Dictionary = wb.actor_observation(wb.selected_id(),true)
	if view.is_empty():
		wb.refuse("Play an enabled External Policy actor before a local test action.")
		return
	var fresh: Dictionary = wb.host.physical_actor_session.make_command(view,int(view.last_sequence)+1,packet.action,12)
	wb.submit_actor_policy(wb.selected_id(),fresh)
	_issued = view
	observation.text = JSON.stringify(_json(view),"  ")
	command.text = JSON.stringify(_json(fresh),"  ")
	refresh()


func _json(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[str(key)] = _json(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_json(item))
		return result
	return value


func _process(_delta: float) -> void:
	if visible and Time.get_ticks_msec() - _last_refresh >= 200:
		_last_refresh = Time.get_ticks_msec()
		refresh()
