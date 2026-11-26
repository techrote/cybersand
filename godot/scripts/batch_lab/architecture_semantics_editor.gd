extends Window
## Friendly authored metadata editing; geometry/provenance are never editable.
## Draft validation and commit remain library-owned, content-pinned operations.
signal committed(identity: String)
signal semantics_changed(value: Dictionary)
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const V2 := "cybersand-native-module-v2"
const RECT_KEYS := ["clearances","protected_regions","fixed_regions","variation_regions"]
const FACING := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
var library: RefCounted
var status := Label.new()
var tabs := TabContainer.new()
var version := CheckBox.new()
var anchor: Array[SpinBox] = []
var transforms: Dictionary = {}
var connector_list := ItemList.new()
var connector_fields: Dictionary = {}
var region_kind := OptionButton.new()
var region_list := ItemList.new()
var region_fields: Array[SpinBox] = []
var role_list := ItemList.new()
var role_name := LineEdit.new()
var role_sources := GridContainer.new()
var role_allowed := GridContainer.new()
var role_source_checks: Dictionary = {}
var role_allowed_checks: Dictionary = {}
var save_button := Button.new()
var _module := {}
var _draft := {}
var _candidate := {}
var _loading := false

func _ready() -> void:
	title = "Module semantics · authored declarations"
	size = Vector2i(960,660)
	min_size = Vector2i(760,540)
	transient = true
	exclusive = false
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	add_child(margin)
	var body := VBoxContainer.new()
	margin.add_child(body)
	_label(body,"These are authored meanings over observed native geometry. They do not establish structural safety or gameplay acceptance.")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	_build_anchor()
	_build_connectors()
	_build_regions()
	_build_roles()
	var actions := HFlowContainer.new()
	body.add_child(actions)
	_button(actions,"Validate metadata draft",validate_draft)
	save_button.text = "Save validated metadata"
	save_button.disabled = true
	save_button.pressed.connect(commit_draft)
	actions.add_child(save_button)
	_button(actions,"Close without applying",hide)
	hide()

func _label(parent: Node, value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _row(parent: Node) -> HFlowContainer:
	var row := HFlowContainer.new()
	parent.add_child(row)
	return row

func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _number(parent: Node, title_text: String, maximum := 512, minimum := 0) -> SpinBox:
	var field := VBoxContainer.new()
	parent.add_child(field)
	_label(field,title_text)
	var number := SpinBox.new()
	number.min_value = minimum
	number.max_value = maximum
	number.custom_minimum_size.x = 88
	number.value_changed.connect(func(_value: float) -> void: _invalidate())
	field.add_child(number)
	return number

func _text(parent: Node, title_text: String, width := 170) -> LineEdit:
	var field := VBoxContainer.new()
	parent.add_child(field)
	_label(field,title_text)
	var edit := LineEdit.new()
	edit.custom_minimum_size.x = width
	edit.max_length = 512
	edit.text_changed.connect(func(_value: String) -> void: _invalidate())
	field.add_child(edit)
	return edit

func _choice(parent: Node, title_text: String, values: Array) -> OptionButton:
	var field := VBoxContainer.new()
	parent.add_child(field)
	_label(field,title_text)
	var choice := OptionButton.new()
	for value: String in values: choice.add_item(value)
	choice.item_selected.connect(func(_index: int) -> void: _invalidate())
	field.add_child(choice)
	return choice

func _tab(name_text: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name_text
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body

func _build_anchor() -> void:
	var body := _tab("Anchor and transforms")
	_label(body,"Anchor coordinates are local material cells. Exact grid transforms require explicit author permission.")
	var row := _row(body)
	anchor.append(_number(row,"Anchor X",511))
	anchor.append(_number(row,"Anchor Y",511))
	var choices := _row(body)
	for name_text: String in Module.TRANSFORMS:
		var check := CheckBox.new()
		check.text = name_text.replace("_"," ").capitalize()
		check.toggled.connect(func(_value: bool) -> void: _invalidate())
		choices.add_child(check)
		transforms[name_text] = check
	version.text = "Use explicit version 2 line / capacity / fixed-region contracts"
	version.toggled.connect(_change_version)
	body.add_child(version)
	_label(body,"Version 1 retains its original connector behavior. Upgrading is an explicit metadata change; review each new role, polarity and contact requirement before committing.")

func _build_connectors() -> void:
	var body := _tab("Connectors")
	_label(body,"Point and line declarations refer to occupied local faces. Snap offers poses; only the native stage host can approve contact and capacity.")
	_label(body,"Use Add or Replace to retain the fields below in the connector list before validating the complete metadata draft.")
	connector_list.custom_minimum_size.y = 100
	connector_list.item_selected.connect(_select_connector)
	body.add_child(connector_list)
	var first := _row(body)
	connector_fields.id = _text(first,"Connector ID",180)
	connector_fields.kind = _choice(first,"Kind",["vertex","line","socket","receptor"])
	connector_fields.role = _text(first,"Role (v2)",160)
	connector_fields.facing = _choice(first,"Outward facing",["Up (0, −1)","Right (1, 0)","Down (0, 1)","Left (−1, 0)"])
	var coordinates := _row(body)
	for key: String in ["x","y","end_x","end_y"]: connector_fields[key] = _number(coordinates,key.replace("_"," ").capitalize(),511)
	var semantics := _row(body)
	connector_fields.compatibility = _text(semantics,"Compatible tags (comma separated)",260)
	connector_fields.polarity = _choice(semantics,"Polarity (v2)",["neutral","socket","receptor"])
	connector_fields.capacity = _number(semantics,"Capacity (v2)",16,1)
	connector_fields.required = CheckBox.new()
	connector_fields.required.text = "Required contact"
	connector_fields.required.toggled.connect(func(_value: bool) -> void: _invalidate())
	semantics.add_child(connector_fields.required)
	var contact := _row(body)
	connector_fields.policy = _choice(contact,"Line contact (v2)",["full","overlap"])
	connector_fields.minimum_cells = _number(contact,"Minimum cells (v2)",512,1)
	_label(contact,"Approach: face · tolerance: 0 cells · saved edits are explicitly authored")
	var buttons := _row(body)
	_button(buttons,"Add connector from fields",func() -> void: store_connector(false))
	_button(buttons,"Replace selected connector",func() -> void: store_connector(true))
	_button(buttons,"Remove selected connector",remove_connector)

func _build_regions() -> void:
	var body := _tab("Clearance and regions")
	_label(body,"Clearance stays empty. Protection forbids other writes. Fixed regions never thin; variable regions alone permit bounded detail variation.")
	for title_text: String in ["Clearance · must be empty","Protected","Fixed · version 2","Variable detail"]: region_kind.add_item(title_text)
	region_kind.item_selected.connect(func(_index: int) -> void: _refresh_regions())
	body.add_child(region_kind)
	region_list.custom_minimum_size.y = 130
	region_list.item_selected.connect(_select_region)
	body.add_child(region_list)
	var row := _row(body)
	for name_text: String in ["X","Y","Width","Height"]: region_fields.append(_number(row,name_text,512,1 if name_text in ["Width","Height"] else 0))
	var actions := _row(body)
	_button(actions,"Add rectangle",func() -> void: store_region(false))
	_button(actions,"Replace selected rectangle",func() -> void: store_region(true))
	_button(actions,"Remove selected rectangle",remove_region)

func _build_roles() -> void:
	var body := _tab("Material roles")
	_label(body,"A role groups observed material identities and explicitly allowed substitutions. Stage permissions still limit which materials can be applied.")
	_label(body,"Use Add or Replace to retain the fields below in the role list before validating the complete metadata draft.")
	role_list.custom_minimum_size.y = 90
	role_list.item_selected.connect(_select_role)
	body.add_child(role_list)
	role_name.placeholder_text = "Role name, for example frame or service"
	role_name.max_length = 64
	role_name.text_changed.connect(func(_value: String) -> void: _invalidate())
	body.add_child(role_name)
	_label(body,"Observed source materials belonging to this role")
	role_sources.columns = 4
	body.add_child(role_sources)
	_label(body,"Permitted replacement materials")
	role_allowed.columns = 4
	body.add_child(role_allowed)
	var actions := _row(body)
	_button(actions,"Add role from fields",func() -> void: store_role(false))
	_button(actions,"Replace selected role",func() -> void: store_role(true))
	_button(actions,"Remove selected role",remove_role)

func open_module(value: Dictionary, show_window := true) -> void:
	_loading = true
	_module = value.duplicate(true)
	_draft.clear()
	for key: String in ["format","anchor","allowed_transforms","attachments","clearances","protected_regions","variation_regions","roles"]:
		_draft[key] = value[key].duplicate(true) if value[key] is Array or value[key] is Dictionary else value[key]
	if value.format==V2: _draft.fixed_regions = value.get("fixed_regions",[]).duplicate(true)
	for axis: int in 2:
		anchor[axis].max_value = int(value.extent[axis])-1
		anchor[axis].value = value.anchor[axis]
	for key: String in transforms: transforms[key].button_pressed = key in value.allowed_transforms
	version.button_pressed = value.format==V2
	_refresh_connectors()
	_refresh_regions()
	_refresh_roles()
	var summary := Module.summary(value)
	_build_material_checks(summary.get("observed_material_ids",[]))
	_loading = false
	_invalidate()
	status.text = "%s · metadata based on %s. Geometry and provenance remain read-only." % [value.name,str(value.content_sha256).left(12)]
	if show_window: popup_centered()

func _invalidate() -> void:
	if _loading: return
	_candidate.clear()
	save_button.disabled = true

func _change_version(enabled: bool) -> void:
	if _loading or _draft.is_empty(): return
	if not enabled and _module.format==V2:
		version.set_pressed_no_signal(true)
		status.text = "A version 2 module cannot silently downgrade its connector contracts."
		return
	_draft.format = V2 if enabled else Module.FORMAT
	if enabled:
		_draft.fixed_regions = _draft.get("fixed_regions",[])
		for connector: Dictionary in _draft.attachments:
			if connector.has("contact"): continue
			connector.role = connector.id
			connector.approach = "face"
			connector.polarity = connector.kind if connector.kind in ["socket","receptor"] else "neutral"
			connector.capacity = 1
			var span := 1
			if connector.kind=="line": span=absi(int(connector.end[0])-int(connector.point[0]))+absi(int(connector.end[1])-int(connector.point[1]))+1
			connector.contact = {"policy":"full","minimum_cells":span,"tolerance":0}
	else:
		_draft.erase("fixed_regions")
		for connector: Dictionary in _draft.attachments:
			for key: String in ["role","approach","polarity","capacity","contact"]: connector.erase(key)
	_refresh_connectors()
	_invalidate()
	status.text = "Version change is a draft. Review every connector role, contact span and capacity; Validate then Save is required."

func _strings(value: String) -> Array:
	var result: Array = []
	for raw: String in value.split(",",false):
		var item := raw.strip_edges()
		if not item.is_empty() and item not in result: result.append(item)
	return result

func store_connector(replace_selected: bool) -> void:
	if _draft.is_empty(): return
	var fields := connector_fields
	var kind: String = fields.kind.get_item_text(fields.kind.selected)
	var facing: Vector2i = FACING[fields.facing.selected]
	var value := {"id":fields.id.text.strip_edges(),"kind":kind,
		"point":[int(fields.x.value),int(fields.y.value)],"facing":[facing.x,facing.y],
		"compatibility":_strings(fields.compatibility.text),"required":fields.required.button_pressed,"source":"authored"}
	if kind=="line": value.end=[int(fields.end_x.value),int(fields.end_y.value)]
	if _draft.format==V2:
		value.merge({"role":fields.role.text.strip_edges(),"approach":"face","polarity":fields.polarity.get_item_text(fields.polarity.selected),
			"capacity":int(fields.capacity.value),"contact":{"policy":fields.policy.get_item_text(fields.policy.selected),"minimum_cells":int(fields.minimum_cells.value),"tolerance":0}})
	var selection := connector_list.get_selected_items()
	if replace_selected:
		if selection.is_empty(): status.text="Select a connector to replace."; return
		_draft.attachments[selection[0]] = value
	elif _draft.attachments.size()<128: _draft.attachments.append(value)
	else: status.text="Connector draft is full (128)."; return
	_refresh_connectors()
	_changed()

func remove_connector() -> void:
	var selection := connector_list.get_selected_items()
	if selection.is_empty() or _draft.is_empty(): return
	_draft.attachments.remove_at(selection[0])
	_refresh_connectors()
	_changed()

func _refresh_connectors() -> void:
	connector_list.clear()
	for item: Dictionary in _draft.get("attachments",[]):
		connector_list.add_item("%s · %s · %s · %s" % [item.id,item.kind,"required" if item.required else "optional",item.source])
	if connector_list.item_count>0: connector_list.select(0); _select_connector(0)

func _select_connector(index: int) -> void:
	var item: Dictionary = _draft.attachments[index]
	var was_loading := _loading
	_loading = true
	connector_fields.id.text = item.id
	connector_fields.kind.select(["vertex","line","socket","receptor"].find(item.kind))
	connector_fields.role.text = item.get("role","")
	connector_fields.x.value = item.point[0]
	connector_fields.y.value = item.point[1]
	connector_fields.end_x.value = item.get("end",item.point)[0]
	connector_fields.end_y.value = item.get("end",item.point)[1]
	connector_fields.facing.select(FACING.find(Vector2i(int(item.facing[0]),int(item.facing[1]))))
	connector_fields.compatibility.text = ", ".join(item.compatibility)
	connector_fields.required.button_pressed = item.required
	connector_fields.polarity.select(["neutral","socket","receptor"].find(item.get("polarity","neutral")))
	connector_fields.capacity.value = item.get("capacity",1)
	connector_fields.policy.select(["full","overlap"].find(item.get("contact",{}).get("policy","full")))
	connector_fields.minimum_cells.value = item.get("contact",{}).get("minimum_cells",1)
	_loading = was_loading

func store_region(replace_selected: bool) -> void:
	if _draft.is_empty(): return
	var key: String = RECT_KEYS[region_kind.selected]
	if key=="fixed_regions" and _draft.format!=V2: status.text="Fixed regions require an explicit version 2 upgrade."; return
	var value: Array = []
	for field: SpinBox in region_fields: value.append(int(field.value))
	var selection := region_list.get_selected_items()
	if replace_selected:
		if selection.is_empty(): status.text="Select a rectangle to replace."; return
		_draft[key][selection[0]] = value
	elif _draft.get(key,[]).size()<128: _draft[key].append(value)
	else: status.text="Region draft is full (128)."; return
	_refresh_regions()
	_changed()

func remove_region() -> void:
	var selection := region_list.get_selected_items()
	if selection.is_empty() or _draft.is_empty(): return
	_draft[RECT_KEYS[region_kind.selected]].remove_at(selection[0])
	_refresh_regions()
	_changed()

func _refresh_regions() -> void:
	region_list.clear()
	for box: Array in _draft.get(RECT_KEYS[region_kind.selected],[]): region_list.add_item("(%d, %d) · %d × %d cells" % box)
	if region_list.item_count>0: region_list.select(0); _select_region(0)

func _select_region(index: int) -> void:
	var box: Array = _draft[RECT_KEYS[region_kind.selected]][index]
	var was_loading := _loading
	_loading = true
	for i: int in 4: region_fields[i].value=box[i]
	_loading = was_loading

func _material_name(identity: int) -> String:
	var index := Setup.MATERIALS.find(identity)
	return "%s (%d)" % [Setup.MATERIAL_NAMES[index],identity] if index>=0 else "Material %d" % identity

func _build_material_checks(identities: Array) -> void:
	for child: Node in role_sources.get_children(): child.queue_free()
	for child: Node in role_allowed.get_children(): child.queue_free()
	role_source_checks.clear()
	role_allowed_checks.clear()
	var observed := identities.duplicate()
	observed.erase(0)
	observed.sort()
	var allowed: Array = Setup.MATERIALS.duplicate()
	for role: Dictionary in _draft.roles:
		for identity: int in role.compatible_materials:
			if identity not in allowed: allowed.append(identity)
	allowed.erase(0); allowed.sort()
	for pair: Array in [[observed,role_sources,role_source_checks],[allowed,role_allowed,role_allowed_checks]]:
		for identity: int in pair[0]:
			var check := CheckBox.new()
			check.text = _material_name(identity)
			check.toggled.connect(func(_value: bool) -> void: _invalidate())
			pair[1].add_child(check)
			pair[2][identity]=check
	if role_list.item_count>0: role_list.select(0); _select_role(0)

func store_role(replace_selected: bool) -> void:
	if _draft.is_empty(): return
	var value := {"name":role_name.text.strip_edges(),"material_ids":[],"compatible_materials":[],"source":"authored"}
	for identity: int in role_source_checks:
		if role_source_checks[identity].button_pressed: value.material_ids.append(identity)
	for identity: int in role_allowed_checks:
		if role_allowed_checks[identity].button_pressed: value.compatible_materials.append(identity)
	var selection := role_list.get_selected_items()
	if replace_selected:
		if selection.is_empty(): status.text="Select a role to replace."; return
		_draft.roles[selection[0]] = value
	elif _draft.roles.size()<32: _draft.roles.append(value)
	else: status.text="Material-role draft is full (32)."; return
	_refresh_roles()
	_changed()

func remove_role() -> void:
	var selection := role_list.get_selected_items()
	if selection.is_empty() or _draft.is_empty(): return
	_draft.roles.remove_at(selection[0])
	_refresh_roles()
	_changed()

func _refresh_roles() -> void:
	role_list.clear()
	for role: Dictionary in _draft.get("roles",[]): role_list.add_item("%s · %s → %s" % [role.name,str(role.material_ids),str(role.compatible_materials)])
	if role_list.item_count>0: role_list.select(0); _select_role(0)

func _select_role(index: int) -> void:
	var role: Dictionary = _draft.roles[index]
	var was_loading := _loading
	_loading = true
	role_name.text = role.name
	for identity: int in role_source_checks: role_source_checks[identity].button_pressed=identity in role.material_ids
	for identity: int in role_allowed_checks: role_allowed_checks[identity].button_pressed=identity in role.compatible_materials
	_loading = was_loading

func _changed() -> void:
	_invalidate()
	status.text = "Metadata draft changed. Validate the complete declarations, then Save explicitly. Native geometry is unchanged."
	semantics_changed.emit(patch())

func patch() -> Dictionary:
	var result := _draft.duplicate(true)
	if result.is_empty(): return result
	result.anchor = [int(anchor[0].value),int(anchor[1].value)]
	result.allowed_transforms = []
	for key: String in transforms:
		if transforms[key].button_pressed: result.allowed_transforms.append(key)
	return Module.canonical(result)

func validate_draft() -> Dictionary:
	if library==null or not library.has_method("draft_metadata"):
		status.text = "The metadata library adapter is unavailable in this source. Nothing changed."
		return {"ok":false,"reason":status.text}
	var answer: Dictionary = library.call("draft_metadata",_module.id,_module.content_sha256,patch())
	_candidate = answer.get("module",{}).duplicate(true) if answer.get("ok",false) else {}
	save_button.disabled = _candidate.is_empty()
	status.text = "Valid metadata draft. Save will retire current-session qualification for this changed manifest." if answer.get("ok",false) else str(answer.get("reason","Metadata draft refused."))
	return answer

func commit_draft() -> Dictionary:
	if _candidate.is_empty(): return {"ok":false,"reason":"Validate this exact metadata draft before saving."}
	var answer: Dictionary = library.call("commit_metadata",_module.id,_module.content_sha256,_candidate)
	status.text = "Metadata saved. The changed manifest needs fresh native replay qualification." if answer.get("ok",false) else str(answer.get("reason","Metadata commit refused."))
	if answer.get("ok",false): committed.emit(_module.id); hide()
	else: _invalidate()
	return answer
