extends Window

# A lazy inspector over the ordinary Workbench's existing actor/session owner.
# Visibility has no effect on controller scheduling or physics lifetime.
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Usables = preload("res://scripts/usable_catalog.gd")
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
var _models: Array[String] = []
var _last_refresh := 0
var _shown_id := -1
var _roster_key := ""
var _issued: Dictionary = {}


func mount(workbench: Control) -> void:
	wb = workbench
	title = "CyberSand / Actor Composition"
	size = Vector2i(700,650)
	min_size = Vector2i(540,400)
	transient = true
	exclusive = false
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var row: Control = wb._row(column)
	wb._button(row,"Mixed Actor Workshop",func() -> void: wb.load_mixed_actor_workshop())
	wb._button(row,"Play / Pause",wb.toggle_pause)
	wb._button(row,"Close",hide)
	pilot_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(pilot_info)
	row = wb._row(column)
	wb._label(row,"Family")
	family.add_item("All physical actors")
	for id: String in Catalog.ids():
		var label: String = Catalog.entry(id).get("family","")
		var found := false
		for i: int in family.item_count:
			if family.get_item_text(i) == label: found = true
		if not found: family.add_item(label)
	family.select(1)
	row.add_child(family)
	family.item_selected.connect(func(_index: int) -> void: _fill_models())
	row = wb._row(column)
	row.add_child(model)
	model.fit_to_longest_item = false
	model.clip_text = true
	model.get_popup().max_size = Vector2i(700,450)
	model.custom_minimum_size.x = 300
	model.item_selected.connect(func(_index: int) -> void: _model_info())
	wb._button(row,"Place at Workbench X/Y",_place)
	wb._button(row,"Replace inspected",_replace)
	catalogue_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(catalogue_info)
	row = wb._row(column)
	wb._label(row,"Inspect")
	instances.custom_minimum_size.x = 280
	row.add_child(instances)
	instances.item_selected.connect(func(index: int) -> void:
		wb.select_instance(instances.get_item_id(index))
		refresh(true))
	wb._button(row,"Focus",wb.focus_selected)
	wb._button(row,"Reset",wb.reset_selected)
	wb._button(row,"Remove",wb.remove_selected)
	row = wb._row(column)
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
	policy.add_item("Deterministic test producer")
	policy.add_item("External submissions")
	row.add_child(policy)
	policy.item_selected.connect(func(_index: int) -> void: _apply_control())
	row = wb._row(column)
	wb._label(row,"Mounted equipment")
	usable.add_item("None",-1)
	for index: int in Usables.count(): usable.add_item(Usables.name_for(index),index)
	row.add_child(usable)
	wb._button(row,"Apply equipment / restart",func() -> void: wb.apply_actor_equipment(wb.selected_id(),usable.get_selected_id()))
	var help := Label.new()
	help.text = "Inspecting does not take control. NPCs continue while this panel is closed or terrain is painted. Human tools use M / Alt, N drop and U attach; the paint pointer stays with PAINT."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	row = wb._row(column)
	wb._button(row,"Observations and policy adapter…",func() -> void: details.visible = not details.visible)
	column.add_child(details)
	details.hide()
	var description := Label.new()
	description.text = "Copied physical observations only. Issue a fresh observation, edit its command values, then submit while running. Late, foreign and retired replies are refused by the session. No network service or learned model is started."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(description)
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
	_fill_models()
	refresh(true)


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
	config.source = source.get_item_metadata(source.selected)
	config.enabled = enabled.button_pressed
	config.decision_ticks = int(cadence.value)
	config.policy = "fixture" if policy.selected == 0 else "external"
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
	if _shown_id != inspected:
		_issued.clear()
		observation.text = "No inspected actor." if a.is_empty() else ""
	if force or _shown_id != inspected:
		_shown_id = inspected
		source.clear()
		if not a.is_empty():
			var config := Catalog.control_for(a)
			for mode: String in Catalog.entry(a.model).controllers:
				source.add_item(SOURCE_LABELS[mode])
				source.set_item_metadata(source.item_count-1,mode)
				if mode == config.source: source.select(source.item_count-1)
			enabled.set_pressed_no_signal(config.enabled)
			cadence.set_value_no_signal(config.decision_ticks)
			policy.select(0 if config.policy == "fixture" else 1)
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
