extends VBoxContainer

# Copied inspection data and isolated experiments; no shared World access.
signal close_requested
const Catalogue = preload("res://scripts/material_lab_catalogue.gd")
const Experiment = preload("res://scripts/material_lab_experiment.gd")
const Service = preload("res://scripts/material_lab_service.gd")
const WorldPanel = preload("res://scripts/material_lab_world_panel.gd")
const EFFECT_KINDS: Array[String] = ["replace_with_defaults","keep_existing","set_state"]
var catalogue := Catalogue.new()
var experiment := Experiment.new()
var service := Service.new()
var world_panel := WorldPanel.new()
var selected_id: int = 3
var candidate: Dictionary = {}
var candidate_state: String = "No candidate"
var candidate_digest: String = ""
var last_backend_result: Dictionary = {}
var applied_policy: Dictionary = {}
var policy_context: String = "Compiled defaults; active World not observed"
var _revision: int = 0
var _job_revision: int = 0
var _job_op: String = ""
var _job_reaction_slot: int = -1
var _reaction_input_revision: int = 0
var _job_reaction_input_revision: int = -1
var _job_world_revision: int = -1
var _job_candidate: Dictionary = {}
var _job_candidate_digest: String = ""
var _loading: bool = false
var _running: bool = false
var _file_action: String = ""
var _search := LineEdit.new()
var _filter := OptionButton.new()
var _list := ItemList.new()
var _summary := Label.new()
var _status := Label.new()
var _tabs := TabContainer.new()
var _property_tree := Tree.new()
var _inspector_notes := TextEdit.new()
var _candidate_form := VBoxContainer.new()
var _candidate_feedback := TextEdit.new()
var _candidate_label := Label.new()
var _candidate_name := LineEdit.new()
var _python := LineEdit.new()
var _compiler := LineEdit.new()
var _fields: Dictionary = {}
var _colour := ColorPickerButton.new()
var _hard := CheckBox.new()
var _granular := CheckBox.new()
var _visual := OptionButton.new()
var _reaction_picker := OptionButton.new()
var _reaction_fields: Dictionary = {}
var _effect_fields: Dictionary = {}
var _reaction_report := TextEdit.new()
var _partner := OptionButton.new()
var _experiment_partner := OptionButton.new()
var _experiment_request := Label.new()
var _roll := SpinBox.new()
var _seed := SpinBox.new()
var _steps := SpinBox.new()
var _workers := OptionButton.new()
var _family := OptionButton.new()
var _preview := TextureRect.new()
var _experiment_summary := Label.new()
var _experiment_report := TextEdit.new()
var _cell_x := SpinBox.new()
var _cell_y := SpinBox.new()
var _target_x := SpinBox.new()
var _target_y := SpinBox.new()
var _contact_roll := SpinBox.new()
var last_contact_report: Dictionary = {}
var _file := FileDialog.new()

func _ready() -> void:
	var compact := Theme.new()
	compact.default_font_size = 13
	theme = compact
	add_theme_constant_override("separation",6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(service)
	service.completed.connect(_backend_completed)
	_build()
	_refresh_candidate()
	reload_catalogue()

func _label(parent: Node, text: String, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	if wrap: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _row(parent: Node) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",5)
	row.add_theme_constant_override("v_separation",3)
	parent.add_child(row)
	return row

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _spin(parent: Node, text: String, field: SpinBox, low: int, high: int, value: int) -> void:
	_label(parent,text)
	field.min_value = low
	field.max_value = high
	field.step = 1
	field.value = value
	field.custom_minimum_size.x = 95
	field.get_line_edit().text_changed.connect(func(_text: String) -> void: field.set_meta("lab_pending_text",true))
	field.value_changed.connect(func(_value: float) -> void: field.set_meta("lab_pending_text",false))
	parent.add_child(field)

func _text(parent: Node, field: TextEdit, min_height: int = 150) -> void:
	field.editable = false
	field.add_theme_color_override("font_readonly_color",Color(0.86,0.89,0.93))
	field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size.y = min_height
	parent.add_child(field)

func _tab(title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = "Content"
	page.add_theme_constant_override("separation",6)
	_mount_tab(title,page)
	return page

func _mount_tab(title: String, content: Control) -> void:
	# Preserve usable controls at ordinary desktop sizes. Large tabs retain
	# their natural layout and scroll only when their content exceeds the bay.
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	scroll.add_child(content)

func _build() -> void:
	var header := _row(self)
	var title := _label(header,"MATERIALS LAB")
	title.add_theme_font_size_override("font_size",21)
	_button(header,"Reload native catalogue",reload_catalogue)
	_button(header,"Close",func() -> void:
		_pause_experiment()
		close_requested.emit())
	_label(self,"Inspect native behaviour · author isolated candidates · test reproducible material contacts",true)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 245
	add_child(split)
	var browser := VBoxContainer.new()
	browser.custom_minimum_size.x = 220
	split.add_child(browser)
	_search.placeholder_text = "Name, ID, kernel, family, partner…"
	_search.text_changed.connect(func(_value: String) -> void: _refresh_list())
	browser.add_child(_search)
	for filter: String in Catalogue.FILTERS: _filter.add_item(filter)
	_filter.item_selected.connect(func(_index: int) -> void: _refresh_list())
	browser.add_child(_filter)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(index: int) -> void: select_material(int(_list.get_item_metadata(index))))
	browser.add_child(_list)
	_label(browser,"ID 10 is reserved and invalid.\nCategories do not confer physics or reactions.",true)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_tabs)
	_build_inspector(_tab("Inspect"))
	_build_candidate(_tab("Candidate"))
	_build_reactions(_tab("Reactions"))
	_build_experiment(_tab("Native test"))
	world_panel.name = "Candidate test"
	_mount_tab("Candidate test",world_panel)
	world_panel.test_requested.connect(_world_job)
	world_panel.export_requested.connect(func(_scenario: Dictionary) -> void: _open_file("world_bundle",true))
	world_panel.cancel_requested.connect(func() -> void:
		if service.busy: service.cancel("Candidate World test cancelled from the Materials Lab."))
	var case_actions := _row(world_panel)
	world_panel.move_child(case_actions,2)
	_button(case_actions,"Save World recipe…",func() -> void: _open_file("export_world_case",true))
	_button(case_actions,"Import World recipe…",func() -> void: _open_file("import_world_case",false))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Opening native catalogue…"
	add_child(_status)
	_file.access = FileDialog.ACCESS_FILESYSTEM
	_file.filters = PackedStringArray(["*.json ; JSON presets and test cases"])
	_file.file_selected.connect(_file_selected)
	_file.dir_selected.connect(_file_selected)
	add_child(_file)

func _build_inspector(page: VBoxContainer) -> void:
	var actions := _row(page)
	_button(actions,"Duplicate selected as candidate",duplicate_selected)
	_button(actions,"New synthetic powder 132",create_synthetic)
	_button(actions,"Test selected material",start_experiment)
	_property_tree.columns = 6
	_property_tree.column_titles_visible = true
	_property_tree.hide_root = true
	_property_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_property_tree.custom_minimum_size.y = 240
	var headings := ["Property","Declared","Effective","Actual consumer","Applicability","Editability"]
	for index: int in range(headings.size()):
		_property_tree.set_column_title(index,headings[index])
		_property_tree.set_column_custom_minimum_width(index,[120,90,125,210,160,130][index])
	page.add_child(_property_tree)
	_text(page,_inspector_notes,165)

func _build_candidate(page: VBoxContainer) -> void:
	var actions := _row(page)
	_button(actions,"Duplicate selected",duplicate_selected)
	_button(actions,"New powder 132",create_synthetic)
	_button(actions,"Import preset…",func() -> void: _open_file("import_preset",false))
	_button(actions,"Validate",func() -> void: _candidate_job("validate"))
	_button(actions,"Compile + native test",func() -> void: _candidate_job("compile_test"))
	_button(actions,"Cancel authoring",func() -> void:
		if service.busy: service.cancel("Authoring cancelled from the Materials Lab.")
		else: _status.text = "No authoring job is running.")
	_button(actions,"Export compiled bundle…",func() -> void: _open_file("compile_bundle",true))
	_button(actions,"Save / export preset…",func() -> void: _open_file("export_preset",true))
	_candidate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_candidate_label)
	var environment := _row(page)
	_label(environment,"Python")
	_python.text = "python" if OS.get_name() == "Windows" else "python3"
	_python.custom_minimum_size.x = 180
	_python.tooltip_text = "Executable path, without shell arguments. Source authoring requires Python 3 and full repository history."
	environment.add_child(_python)
	_label(environment,"C++ compiler")
	_compiler.placeholder_text = "Auto-detect C++20 compiler"
	_compiler.custom_minimum_size.x = 220
	environment.add_child(_compiler)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 360
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	_candidate_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_candidate_form)
	_label(_candidate_form,"Candidate label (identity stays fixed)")
	_candidate_form.add_child(_candidate_name)
	_candidate_name.text_changed.connect(func(value: String) -> void:
		if not _loading and not candidate.is_empty():
			candidate.name = value
			_mark_draft())
	for key: String in ["density","viscosity_index"]:
		var row := _row(_candidate_form)
		var field := SpinBox.new()
		_spin(row,key,field,0,65535 if key == "density" else 255,0)
		_fields[key] = field
		field.get_line_edit().text_changed.connect(func(_text: String) -> void:
			if not _loading and not candidate.is_empty(): _mark_draft())
		field.value_changed.connect(func(value: float) -> void:
			if not _loading and not candidate.is_empty():
				candidate.descriptor[key] = int(value)
				_mark_draft())
	_label(_candidate_form,"Base RGBA (compiled descriptor colour)")
	_colour.custom_minimum_size = Vector2(140,30)
	_colour.edit_alpha = true
	_candidate_form.add_child(_colour)
	_colour.color_changed.connect(func(value: Color) -> void:
		if not _loading and not candidate.is_empty():
			candidate.descriptor.rgba = [value.r8,value.g8,value.b8,value.a8]
			_mark_draft())
	_hard.text = "Hard surface capability"
	_granular.text = "Granular support capability"
	_candidate_form.add_child(_hard)
	_candidate_form.add_child(_granular)
	_hard.toggled.connect(func(value: bool) -> void:
		if not _loading and not candidate.is_empty():
			candidate.capabilities.hard_surface = value
			_mark_draft())
	_granular.toggled.connect(func(value: bool) -> void:
		if not _loading and not candidate.is_empty():
			candidate.capabilities.granular_support = value
			_mark_draft())
	_label(_candidate_form,"Visual state projection")
	for label: String in ["Zero","State A","State B"]: _visual.add_item(label)
	_candidate_form.add_child(_visual)
	_visual.item_selected.connect(func(index: int) -> void:
		if not _loading and not candidate.is_empty():
			candidate.appearance.visual_state_source = index
			_mark_draft())
	_label(_candidate_form,"Choose a native template for its supported kernel and state contract. Identity, kernel, state defaults and write radius stay fixed. Candidates need a separately reviewed production consumer before affecting the game.",true)
	_text(split,_candidate_feedback,260)

func _build_reactions(page: VBoxContainer) -> void:
	_label(page,"Native resolver diagnostic — supplied byte roll; World scheduling, masks and sleep are not observed here.",true)
	var row := _row(page)
	_label(row,"Selected material + partner")
	row.add_child(_partner)
	_partner.item_selected.connect(func(index: int) -> void: _select_partner(_partner.get_item_id(index)))
	_spin(row,"Roll",_roll,0,255,0)
	_roll.value_changed.connect(func(_value: float) -> void: _retire_reaction_diagnostic())
	_roll.get_line_edit().text_changed.connect(func(_text: String) -> void: _retire_reaction_diagnostic())
	_button(row,"Inspect native result",inspect_reaction)
	_label(page,"Candidate sparse rule editor — existing authored slots; conflicting pairs are rejected.",true)
	page.add_child(_reaction_picker)
	_reaction_picker.item_selected.connect(func(_index: int) -> void:
		_refresh_reaction_fields()
		_show_candidate_rule())
	row = _row(page)
	for key: String in ["first","second","first_product","second_product"]:
		var group := VBoxContainer.new()
		row.add_child(group)
		_label(group,key.replace("_"," ").capitalize())
		var picker := OptionButton.new()
		picker.custom_minimum_size.x = 165
		group.add_child(picker)
		_reaction_fields[key] = picker
		picker.item_selected.connect(func(index: int) -> void: _edit_reaction(key,picker.get_item_id(index)))
	row = _row(page)
	var threshold := SpinBox.new()
	_spin(row,"Threshold T",threshold,0,255,0)
	_reaction_fields["probability"] = threshold
	threshold.get_line_edit().text_changed.connect(func(_text: String) -> void:
		if not _loading and not candidate.is_empty(): _mark_draft())
	threshold.value_changed.connect(func(value: float) -> void: _edit_reaction("probability",int(value)))
	var match_picker := OptionButton.new()
	for label: String in ["Ordered","Unordered, role preserving","Symmetric"]: match_picker.add_item(label)
	row.add_child(match_picker)
	_reaction_fields["match"] = match_picker
	match_picker.item_selected.connect(func(index: int) -> void: _edit_reaction("match",index))
	_button(row,"Validate candidate",func() -> void: _candidate_job("validate"))
	_button(row,"Compile candidate reaction",func() -> void: _candidate_job("compile_test"))
	_button(row,"Test reaction in World",_test_reaction_world)
	row = _row(page)
	for endpoint: String in ["first","second"]:
		var group := VBoxContainer.new()
		row.add_child(group)
		_label(group,endpoint.capitalize() + " endpoint effect")
		var kind := OptionButton.new()
		for caption: String in ["Replace with defaults","Keep existing","Set state B"]: kind.add_item(caption)
		group.add_child(kind)
		var value := SpinBox.new()
		_spin(group,"State B",value,0,255,0)
		var detail := _label(group,"",true)
		detail.custom_minimum_size.x = 270
		_effect_fields[endpoint] = {"kind":kind,"state_b":value,"detail":detail}
		value.get_line_edit().text_changed.connect(func(_text: String) -> void:
			if not _loading and not candidate.is_empty(): _mark_draft())
		kind.item_selected.connect(func(index: int) -> void: _edit_effect(endpoint,index))
		value.value_changed.connect(func(_number: float) -> void: _edit_effect(endpoint,kind.selected))
	_label(page,"Chance = (T + 1) / 256; T=0 still selects roll 0. Replace uses legacy product defaults. Effects v2 retain a non-Water participant or set its declared Metal charge / Combustible burn countdown. These effects require Test reaction in World and role-preserving matching.",true)
	_text(page,_reaction_report,220)

func _build_experiment(page: VBoxContainer) -> void:
	_label(page,"Existing materials run in an isolated native MicroScenario. Candidate-only IDs and edits are never installed in this World.",true)
	_experiment_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_experiment_summary)
	var row := _row(page)
	_label(row,"Partner for new pair")
	row.add_child(_experiment_partner)
	_experiment_partner.item_selected.connect(func(index: int) -> void: _select_partner(_experiment_partner.get_item_id(index)))
	_experiment_request.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_experiment_request)
	row = _row(page)
	_spin(row,"Seed",_seed,0,2147483647,2)
	_spin(row,"Ticks",_steps,1,Experiment.MAX_DURATION,120)
	_label(row,"Workers")
	_workers.add_item("1",1)
	_workers.add_item("4",4)
	row.add_child(_workers)
	_label(row,"Water test policy")
	for family: String in ["Current default","FreeMass","CellularYield"]: _family.add_item(family)
	row.add_child(_family)
	for field: SpinBox in [_seed,_steps]:
		field.value_changed.connect(func(_value: float) -> void: _refresh_experiment_request())
	_workers.item_selected.connect(func(_index: int) -> void: _refresh_experiment_request())
	_family.item_selected.connect(func(_index: int) -> void: _refresh_experiment_request())
	row = _row(page)
	_button(row,"Prepare selected + partner",start_experiment)
	_button(row,"Step",func() -> void: _step_experiment(1))
	_button(row,"Run bounded window",func() -> void:
		experiment.cancel_reference("Reference comparison cancelled to resume the source run.")
		if not experiment.active(): start_experiment()
		_running = experiment.active() and not experiment.completed()
		_status.text = "Running the prepared native definition." if _running else "Prepared native window is complete; Prepare creates a fresh run."
		_refresh_experiment())
	_button(row,"Pause",_pause_experiment)
	_button(row,"Inspect test-owner policy",func() -> void:
		if experiment.active():
			set_policy_readback(experiment.readback().get("applied_policy",{}),"Isolated native test owner")
			_tabs.current_tab = 0)
	_button(row,"Repeat / compare reference",_compare_reference)
	_button(row,"Save test case…",func() -> void: _open_file("export_test",true))
	_button(row,"Import test case…",func() -> void: _open_file("import_test",false))
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)
	var view := VBoxContainer.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(view)
	_preview.custom_minimum_size = Vector2(360,240)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.gui_input.connect(_pick_experiment_cell)
	view.add_child(_preview)
	row = _row(view)
	_spin(row,"Source X",_cell_x,0,1023,242)
	_spin(row,"Y",_cell_y,0,1023,238)
	_button(row,"Read stored cell",_inspect_test_cell)
	row = _row(view)
	_spin(row,"Target X",_target_x,0,1023,243)
	_spin(row,"Y",_target_y,0,1023,238)
	_spin(row,"Supplied roll",_contact_roll,0,255,0)
	row = _row(view)
	_button(row,"Inspect contact",_inspect_test_contact)
	_button(row,"Swap endpoints",func() -> void:
		_commit_contact_fields()
		var source: Vector2i = Vector2i(int(_cell_x.value),int(_cell_y.value))
		_cell_x.value = _target_x.value
		_cell_y.value = _target_y.value
		_target_x.value = source.x
		_target_y.value = source.y
		_inspect_test_contact())
	for field: SpinBox in [_cell_x,_cell_y,_target_x,_target_y,_contact_roll]:
		field.value_changed.connect(func(_value: float) -> void:
			_retire_contact_report())
		field.get_line_edit().text_changed.connect(func(_text: String) -> void: _retire_contact_report())
	_label(view,"Left-click the preview for source; right-click for target. Inspection pauses this test owner. Native stored values establish facts; the supplied resolver roll does not predict scheduling or an executed reaction.",true)
	_text(split,_experiment_report,300)

func reload_catalogue() -> void:
	var partner_id: int = _partner.get_selected_id() if _partner.selected >= 0 else 23
	if not catalogue.reload():
		_status.text = "Native inspection unavailable. Rebuild the matching GDExtension and reopen the Lab. " + catalogue.error
		return
	_fill_material_picker(_partner)
	_fill_material_picker(_experiment_partner)
	world_panel.set_materials(catalogue.materials)
	_select_partner(partner_id)
	for key: String in ["first","second","first_product","second_product"]:
		_fill_material_picker(_reaction_fields[key])
	_refresh_list()
	select_material(selected_id)
	_status.text = "Native catalogue loaded. Production material identities and physics are read-only."

func _fill_material_picker(picker: OptionButton) -> void:
	picker.clear()
	for material: Dictionary in catalogue.materials:
		if material.get("valid",false): picker.add_item("%03d  %s" % [material.id,material.name],int(material.id))

func _select_partner(id: int) -> void:
	_retire_reaction_diagnostic()
	for picker: OptionButton in [_partner,_experiment_partner]:
		picker.select(picker.get_item_index(id))
	_refresh_experiment_request()

func _refresh_experiment_request() -> void:
	var first: String = "%03d" % selected_id
	if selected_id >= 0 and selected_id < catalogue.materials.size(): first += " " + str(catalogue.materials[selected_id].name)
	var second: String = _partner.get_item_text(_partner.selected) if _partner.selected >= 0 else "choose partner"
	_experiment_request.text = "Prepare new pair: %s + %s · seed %d · %d ticks · %d worker(s) · Water %s. Run/Step use the prepared definition below." % [first,second,int(_seed.value),int(_steps.value),_workers.get_selected_id(),Experiment.WATER_FAMILIES[_family.selected]]

func _refresh_list() -> void:
	_list.clear()
	for id: int in catalogue.search(_search.text,Catalogue.FILTERS[_filter.selected]):
		var material: Dictionary = catalogue.materials[id]
		var index: int = _list.add_item("%03d  %s%s" % [id,material.name," [reserved]" if id == 10 else ""])
		_list.set_item_metadata(index,id)
		if id == selected_id: _list.select(index)

func set_policy_readback(receipt: Dictionary, context: String) -> void:
	applied_policy = receipt.duplicate(true)
	policy_context = context if not receipt.is_empty() else "Compiled defaults; active World not observed"
	if is_node_ready(): select_material(selected_id)

func select_material(id: int) -> void:
	if selected_id != id: _retire_reaction_diagnostic()
	selected_id = id
	_list.deselect_all()
	for index: int in range(_list.item_count):
		if int(_list.get_item_metadata(index)) == id:
			_list.select(index)
			break
	_refresh_experiment_request()
	var info: Dictionary = catalogue.inspect(id,applied_policy)
	if not info.get("ok",false):
		_summary.text = "Material inspection unavailable: " + str(info)
		return
	_summary.text = "%03d / %s   ·   %s   ·   %s" % [id,info.name,info.get("origin","native"),info.get("solver",{}).get("label","")]
	_summary.text += "\n" + policy_context
	if not applied_policy.is_empty(): _summary.text += " · policy " + str(applied_policy.get("policy_hash","unavailable")).left(16)
	_property_tree.clear()
	var root := _property_tree.create_item()
	for record: Dictionary in info.get("rows",[]):
		var item := _property_tree.create_item(root)
		var keys := ["property","declared","effective","consumer","applicability","editability"]
		for column: int in range(keys.size()):
			var value: String = str(record.get(keys[column],"—"))
			item.set_text(column,value)
			item.set_tooltip_text(column,value)
	var notes: Array[String] = []
	for note: Variant in info.get("notes",[]): notes.append(str(note))
	notes.append("Capabilities: " + str(info.get("capabilities",{})))
	notes.append("Semantic families: " + str(info.get("families",[])))
	notes.append("Appearance: " + JSON.stringify(info.get("appearance",{})))
	notes.append("Sparse reaction partners: " + str(info.get("partners",[])))
	for rule: Dictionary in info.get("reactions",[]): notes.append(JSON.stringify(rule))
	_inspector_notes.text = "\n\n".join(notes)

func duplicate_selected() -> void:
	if selected_id == 10:
		_status.text = "ID 10 is reserved and invalid; choose a valid material template."
		return
	_start_job({"op":"create","template_id":selected_id,"synthetic":false})

func create_synthetic() -> void:
	_start_job({"op":"create","template_id":2,"synthetic":true})

func _mark_draft() -> void:
	_revision += 1
	candidate_state = "Draft"
	candidate_digest = ""
	last_backend_result = {}
	_candidate_feedback.text = "Draft — this revision has not been validated or tested.\n\nPrevious results apply only to the previous candidate revision. Validate or compile the current edits to obtain a new receipt."
	_reaction_report.text = "Draft candidate — previous compiled reaction results have been retired. Validate or compile the current revision."
	world_panel.set_candidate(candidate)
	world_panel.invalidate("Candidate edited. The previous World comparison does not qualify this revision.")
	_refresh_candidate_status()

func _refresh_candidate_status() -> void:
	world_panel.set_candidate(candidate)
	_candidate_label.text = candidate_state
	if not candidate_digest.is_empty(): _candidate_label.text += "  ·  digest " + candidate_digest
	if not candidate.is_empty():
		_candidate_label.text += "\nTemplate %d → candidate %d / %s. No production activation." % [candidate.template_id,candidate.target_id,candidate.descriptor.name]

func _refresh_candidate(preferred_slot: int = -1) -> void:
	_loading = true
	_candidate_form.visible = not candidate.is_empty()
	var selected_slot: int = _reaction_picker.get_selected_id() if _reaction_picker.selected >= 0 else -1
	if preferred_slot >= 0: selected_slot = preferred_slot
	_reaction_picker.clear()
	if not candidate.is_empty():
		_candidate_name.text = candidate.name
		for key: String in _fields: _fields[key].value = candidate.descriptor[key]
		var rgba: Array = candidate.descriptor.rgba
		_colour.color = Color8(rgba[0],rgba[1],rgba[2],rgba[3])
		_hard.button_pressed = candidate.capabilities.hard_surface
		_hard.disabled = int(candidate.target_id) == 132
		_granular.button_pressed = candidate.capabilities.granular_support
		_visual.select(int(candidate.appearance.visual_state_source))
		var supported: bool = int(candidate.descriptor.kernel) in [18,23,25]
		_fields.viscosity_index.editable = supported
		_fields.viscosity_index.tooltip_text = "Candidate descriptor consumed by generic yielding motion." if supported else "This kernel has no supported descriptor-viscosity edit."
		for rule: Dictionary in candidate.reactions:
			_reaction_picker.add_item("Slot %d / %s" % [rule.slot,rule.rule_id],int(rule.slot))
		var selected_index: int = _reaction_picker.get_item_index(selected_slot)
		if selected_index >= 0: _reaction_picker.select(selected_index)
	_reaction_picker.disabled = _reaction_picker.item_count == 0
	_refresh_candidate_status()
	_loading = false
	_refresh_reaction_fields()

func _candidate_job(op: String) -> void:
	_commit_candidate_fields()
	if candidate.is_empty():
		_status.text = "Duplicate a material or create the isolated powder candidate first."
		return
	var request: Dictionary = {"op":op,"candidate":candidate.duplicate(true)}
	if op == "compile_test":
		if not _compiler.text.strip_edges().is_empty(): request["cxx"] = _compiler.text.strip_edges()
		var rule: Dictionary = _selected_reaction()
		if not rule.is_empty(): request["diagnostic"] = {"source":rule.first,"target":rule.second,"roll":int(_roll.value)}
	_start_job(request)

func _world_job(scenario: Dictionary, output_dir: String = "") -> void:
	_commit_candidate_fields()
	if candidate.is_empty() or scenario.is_empty():
		_status.text = "Duplicate an existing material before testing a candidate in World."
		return
	if service.busy:
		_status.text = "The current authoring job is still running."
		return
	var request: Dictionary = {"op":"compile_world_test","candidate":candidate.duplicate(true),"scenario":scenario.duplicate(true)}
	if not _compiler.text.strip_edges().is_empty(): request.cxx = _compiler.text.strip_edges()
	if not output_dir.is_empty(): request.output_dir = output_dir
	world_panel.show_pending()
	_start_job(request)

func _start_job(request: Dictionary) -> void:
	if service.busy:
		_status.text = "The current authoring job is still running."
		return
	_job_revision = _revision
	_job_op = str(request.op)
	_job_world_revision = world_panel.revision
	_job_reaction_slot = _reaction_picker.get_selected_id() if request.has("diagnostic") and _reaction_picker.selected >= 0 else -1
	_job_reaction_input_revision = _reaction_input_revision
	_job_candidate = {}
	_job_candidate_digest = ""
	if request.has("candidate"):
		if not request.candidate is Dictionary:
			_reject_backend("Submit a structured material definition before requesting qualification.")
			return
		_job_candidate = _normalized_candidate(request.candidate)
		_job_candidate_digest = _candidate_sha256(_job_candidate)
		if _job_candidate_digest.is_empty():
			_reject_backend("Candidate values must use the supported integer, text, boolean and structured fields.")
			return
		# Capture the exact canonical request before the process can reply.
		request = request.duplicate(true)
		request.candidate = _job_candidate.duplicate(true)
	_status.text = "Authoring: %s…" % _job_op
	service.request(request,_python.text.strip_edges())

static func _integer_candidate(value: Variant) -> Variant:
	# JSON.parse uses floats; all numeric preset fields have integer domains.
	# Dictionary dot-assignment creates StringName keys, while Python JSON
	# returns String keys. Normalize the same JSON text representation.
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[str(key) if typeof(key) == TYPE_STRING_NAME else key] = _integer_candidate(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_integer_candidate(item))
		return result
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value): return int(value)
	if typeof(value) == TYPE_STRING_NAME: return str(value)
	return value

static func _python_space(codepoint: int) -> bool:
	# Python str.strip's Unicode whitespace, including non-ASCII label edges.
	return codepoint in [9,10,11,12,13,28,29,30,31,32,133,160,5760,8232,8233,8239,8287,12288] or (codepoint >= 8192 and codepoint <= 8202)

static func _normalized_candidate(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = _integer_candidate(value)
	if typeof(normalized.get("name")) == TYPE_STRING:
		var label: String = normalized.name
		var first: int = 0
		var end: int = label.length()
		while first < end and _python_space(label.unicode_at(first)): first += 1
		while end > first and _python_space(label.unicode_at(end - 1)): end -= 1
		normalized.name = label.substr(first,end - first)
	if normalized.get("reactions") is Array:
		var sortable: bool = true
		for rule: Variant in normalized.reactions:
			if not rule is Dictionary or typeof(rule.get("slot")) != TYPE_INT:
				sortable = false
				break
		if sortable:
			normalized.reactions.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.slot < b.slot)
	return normalized

static func _json_string(value: String) -> String:
	var out: String = "\""
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		match codepoint:
			34: out += "\\\""
			92: out += "\\\\"
			8: out += "\\b"
			9: out += "\\t"
			10: out += "\\n"
			12: out += "\\f"
			13: out += "\\r"
			_:
				out += "\\u%04x" % codepoint if codepoint < 32 else String.chr(codepoint)
	return out + "\""

static func _canonical_json(value: Variant, depth: int = 0) -> String:
	# Python compiler.canonical_json parity for the integer-only candidate
	# schema: sorted keys, indent=2, ensure_ascii=False, no lossy number coercion.
	# Empty return denotes unsupported input; valid empty JSON is [] or {}.
	if depth > 32: return ""
	match typeof(value):
		TYPE_NIL: return "null"
		TYPE_BOOL: return "true" if value else "false"
		TYPE_INT: return str(value)
		TYPE_STRING: return _json_string(value)
		TYPE_ARRAY, TYPE_DICTIONARY:
			var object: bool = value is Dictionary
			if value.is_empty(): return "{}" if object else "[]"
			var children: PackedStringArray = []
			var indentation: String = "  ".repeat(depth + 1)
			if object:
				var keys: Array = value.keys()
				for key: Variant in keys:
					if typeof(key) != TYPE_STRING: return ""
				keys.sort()
				for key: String in keys:
					var encoded: String = _canonical_json(value[key],depth + 1)
					if encoded.is_empty(): return ""
					children.append(indentation + _json_string(key) + ": " + encoded)
			else:
				for item: Variant in value:
					var encoded: String = _canonical_json(item,depth + 1)
					if encoded.is_empty(): return ""
					children.append(indentation + encoded)
			return ("{\n" if object else "[\n") + ",\n".join(children) + "\n" + "  ".repeat(depth) + ("}" if object else "]")
	return ""

static func _candidate_sha256(value: Dictionary) -> String:
	var encoded: String = _canonical_json(value)
	return "" if encoded.is_empty() else (encoded + "\n").sha256_text()

func _candidate_response_error(result: Dictionary, compiled: bool) -> String:
	var expected_state: String = {"create":"draft","validate":"validated_candidate","import":"validated_candidate",
		"export":"validated_candidate","import_world_case":"validated_candidate","export_world_case":"validated_candidate",
		"compile_test":"compiled_tested","compile_world_test":"compiled_tested"}.get(_job_op,"")
	if expected_state.is_empty() or result.get("state") != expected_state:
		return "Authoring response state does not match the requested operation."
	if typeof(result.get("runtime_active")) != TYPE_BOOL or result.runtime_active:
		return "Authoring response must acknowledge that the candidate is not runtime-active."
	if not compiled and result.has("receipt"):
		return "Only an executed compile operation can return a native qualification receipt."
	if compiled and _job_candidate.is_empty(): return "Compiled result has no captured submitted material definition."
	if not _job_candidate.is_empty():
		if _candidate_sha256(_normalized_candidate(candidate)) != _job_candidate_digest:
			return "Current material values differ from the submitted definition; edits remain Draft."
		if not result.get("candidate") is Dictionary:
			return "Qualified response is missing its submitted material definition."
		var returned: Dictionary = _integer_candidate(result.candidate)
		if _canonical_json(returned) != _canonical_json(_job_candidate):
			return "Qualified response describes a different material from the submitted definition."
		if result.get("digest") != _job_candidate_digest:
			return "Qualified response digest does not match the canonical submitted material."
	if compiled:
		if result.get("state") != "compiled_tested" or typeof(result.get("runtime_active")) != TYPE_BOOL or result.runtime_active:
			return "Compiled result lacks an isolated compiled/tested acknowledgment."
		var receipt: Variant = result.get("receipt")
		var schema: String = "cybersand.material-lab.world-receipt" if _job_op == "compile_world_test" else "cybersand.material-lab.native-receipt"
		if not receipt is Dictionary or receipt.get("schema_id") != schema or not WorldPanel._whole(receipt.get("schema_version"),1,1):
			return "Compiled result has no receipt for the requested native backend."
		if receipt.get("candidate_digest") != _job_candidate_digest:
			return "Native execution receipt does not match the canonical submitted material."
	return ""

func _backend_completed(result: Dictionary) -> void:
	# A pending editor may still contain text which has not lost focus. Admit
	# it before comparing request revisions, so a reply cannot erase new text.
	_commit_candidate_fields()
	world_panel.commit_fields()
	if _revision != _job_revision:
		_status.text = "Completed job refers to an older revision. Current edits remain Draft."
		if _job_op == "compile_world_test": world_panel.show_failure(_status.text)
		return
	if _job_op in ["compile_world_test","import_world_case","export_world_case"] and _job_world_revision != world_panel.revision:
		_status.text = "World operation completed for an older recipe. Current test settings remain untested."
		world_panel.show_failure(_status.text)
		return
	last_backend_result = result.duplicate(true)
	if not result.get("ok",false):
		candidate_state = "Draft — validation failed"
		candidate_digest = ""
		_status.text = "\n".join(result.get("errors",["Authoring failed"]))
		_candidate_feedback.text = _status.text
		if _job_op == "compile_world_test": world_panel.show_failure(_status.text)
		_refresh_candidate_status()
		return
	var response_receipt: Variant = result.get("receipt",{})
	if not response_receipt is Dictionary:
		_reject_backend("Native receipt must be an object; this result cannot qualify the candidate.")
		return
	var world_result: bool = _job_op == "compile_world_test"
	var binding_error: String = _candidate_response_error(result,_job_op in ["compile_test","compile_world_test"])
	if not binding_error.is_empty():
		_reject_backend(binding_error)
		return
	var next_candidate: Dictionary = candidate.duplicate(true)
	if result.has("candidate"):
		if not result.candidate is Dictionary:
			_reject_backend("Authoring result is missing its material definition.")
			return
		next_candidate = _integer_candidate(result.candidate)
	world_panel.set_candidate(next_candidate)
	if world_result:
		if not world_panel.show_receipt(response_receipt,_job_candidate_digest):
			_reject_backend("Native World receipt rejected: " + world_panel.last_error)
			return
	if _job_op == "import_world_case":
		if not result.get("scenario") is Dictionary or not world_panel.set_scenario(_integer_candidate(result.scenario)):
			_reject_backend("World recipe rejected: " + world_panel.last_error)
			return
		world_panel.invalidate("Source-bound recipe imported. Compile + compare World for a fresh native result.")
	# Commit returned data only after every identity/receipt/recipe check passes.
	candidate = next_candidate
	_revision += 1
	candidate_digest = str(result.get("digest",""))
	candidate_state = {"draft":"Draft","validated_candidate":"Validated candidate","compiled_tested":"Compiled/tested — isolated native backend"}.get(str(result.get("state","draft")),str(result.get("state","Draft")))
	if world_result: candidate_state = "Compiled/tested — isolated native World"
	_candidate_feedback.text = _candidate_result_text(result)
	if result.has("receipt") and not world_result:
		_reaction_report.text = "COMPILED CANDIDATE / ISOLATED NATIVE RESOLVER\n\n" + JSON.stringify(result.receipt.get("observed",{}).get("diagnostic",{}),"\t") + "\n\n" + str(result.get("boundary",""))
		_reaction_report.text += "\n\nCHANGES ACROSS PRODUCTION + CANDIDATE PAIRS\n" + JSON.stringify(result.receipt.get("observed",{}).get("comparison",{}),"\t")
		if _job_reaction_input_revision != _reaction_input_revision: _retire_reaction_diagnostic()
	_status.text = "%s completed. %s" % [_job_op,candidate_state]
	_refresh_candidate(_job_reaction_slot if result.has("receipt") else -1)
	if world_result:
		_tabs.current_tab = 4
	if _job_op in ["import_world_case","export_world_case"]: _tabs.current_tab = 4
	if _job_op in ["create","import"]: _tabs.current_tab = 1

func _reject_backend(message: String) -> void:
	candidate_state = "Draft — backend result refused"
	candidate_digest = ""
	last_backend_result = {"ok":false,"state":"draft","runtime_active":false,"errors":[message]}
	_status.text = message
	_candidate_feedback.text = message
	world_panel.set_candidate(candidate)
	world_panel.invalidate(message)
	world_panel.show_failure(message)
	_refresh_candidate_status()

func _candidate_result_text(result: Dictionary) -> String:
	var lines: Array[String] = [candidate_state,"",str(result.get("boundary","Editable candidate. Select supported fields, then validate."))]
	if result.has("digest"): lines.append("\nPreset digest: " + str(result.digest))
	if result.has("case_digest"): lines.append("\nWorld recipe digest: " + str(result.case_digest))
	lines.append("\nCHANGES FROM TEMPLATE")
	for change: Dictionary in result.get("changes",[]):
		lines.append("%s: %s → %s" % [change.path,change.before,change.after])
	if result.get("changes",[]).is_empty(): lines.append("No validated changes yet.")
	if result.has("receipt"):
		var receipt: Dictionary = result.receipt
		lines.append("\nNATIVE TEST / %s / %s" % [receipt.get("platform",""),receipt.get("compiler_version","")])
		if receipt.get("schema_id","") == "cybersand.material-lab.world-receipt":
			lines.append("Actual native World execution. Open Candidate test for stored cells, reference comparison and quantity checks.")
			lines.append(JSON.stringify(receipt.get("checks",{}),"\t"))
			lines.append("\nCandidate executable SHA-256: " + str(receipt.get("candidate_build",{}).get("native_executable_sha256","")))
		else:
			lines.append(JSON.stringify(receipt.get("observed",{}),"\t"))
			lines.append("\nExecutable SHA-256: " + str(receipt.get("native_executable_sha256","")))
	if result.has("output_dir"): lines.append("\nCompiled bundle: " + str(result.output_dir))
	return "\n".join(lines)

func _selected_reaction() -> Dictionary:
	if candidate.is_empty() or _reaction_picker.selected < 0 or _reaction_picker.selected >= candidate.reactions.size(): return {}
	return candidate.reactions[_reaction_picker.selected]

func _refresh_reaction_fields() -> void:
	_loading = true
	var rule: Dictionary = _selected_reaction()
	for key: String in ["first","second","first_product","second_product"]:
		var picker: OptionButton = _reaction_fields[key]
		picker.disabled = rule.is_empty()
		if not rule.is_empty(): picker.select(picker.get_item_index(int(rule[key])))
	_reaction_fields.probability.editable = not rule.is_empty()
	_reaction_fields.match.disabled = rule.is_empty()
	if not rule.is_empty():
		_reaction_fields.probability.value = rule.probability
		_reaction_fields.match.select(int(rule.match))
	else:
		_reaction_report.text = "Duplicate a reactive material (for example Salt) to edit its authored rules. Powder 132 has no admitted pair-rule consumer."
	for endpoint: String in ["first","second"]:
		var controls: Dictionary = _effect_fields[endpoint]
		controls.kind.disabled = rule.is_empty()
		controls.state_b.editable = false
		controls.detail.text = "Select an owned reaction slot."
		if rule.is_empty(): continue
		var effect: Dictionary = rule.effects[endpoint]
		var index: int = EFFECT_KINDS.find(str(effect.kind))
		controls.kind.select(index)
		var participant: int = int(rule[endpoint])
		var kernel: String = str(catalogue.materials[participant].kernel_name) if participant >= 0 and participant < catalogue.materials.size() else ""
		var retain_allowed: bool = participant > 0 and participant != 3 and participant != 10 and int(rule.match) != 2
		var state_allowed: bool = retain_allowed and kernel in ["Metal","Combustible"]
		controls.kind.set_item_disabled(1,not retain_allowed)
		controls.kind.set_item_disabled(2,not state_allowed)
		controls.state_b.value = int(effect.get("state_b",0))
		controls.state_b.editable = state_allowed and index == 2
		_reaction_fields[endpoint + "_product"].disabled = index != 0
		controls.detail.text = "Product defaults replace material and stored state." if index == 0 else "Material, state A and temperature are retained."
		if index == 1: controls.detail.text += " State B is retained."
		if index == 2: controls.detail.text += " State B: " + ("charge countdown." if kernel == "Metal" else "burn countdown.")
		if not retain_allowed: controls.detail.text += " Retention requires a non-Water participant and role-preserving matching."
	_loading = false

func _edit_reaction(key: String, value: int) -> void:
	if _loading: return
	var rule: Dictionary = _selected_reaction()
	if rule.is_empty(): return
	rule[key] = value
	if key in ["first","second"] and rule.effects[key].kind != "replace_with_defaults": rule[key + "_product"] = value
	_mark_draft()
	_refresh_reaction_fields()
	_show_candidate_rule()

func _edit_effect(endpoint: String, index: int) -> void:
	if _loading or index < 0 or index >= EFFECT_KINDS.size(): return
	var rule: Dictionary = _selected_reaction()
	if rule.is_empty(): return
	var effect: Dictionary = {"kind":EFFECT_KINDS[index]}
	if index == 2: effect.state_b = int(_effect_fields[endpoint].state_b.value)
	if index != 0: rule[endpoint + "_product"] = int(rule[endpoint])
	rule.effects[endpoint] = effect
	rule.effects.version = 2 if rule.effects.first.kind != "replace_with_defaults" or rule.effects.second.kind != "replace_with_defaults" else 1
	_mark_draft()
	_refresh_reaction_fields()
	_show_candidate_rule()

func _test_reaction_world() -> void:
	_commit_candidate_fields()
	world_panel.commit_fields()
	var rule: Dictionary = _selected_reaction()
	if rule.is_empty():
		_status.text = "Select a candidate reaction first."
		return
	var recipe: Dictionary = world_panel.scenario()
	recipe.first = int(rule.first)
	recipe.second = int(rule.second)
	if not world_panel.set_scenario(recipe):
		_status.text = world_panel.last_error
		return
	_tabs.current_tab = 4
	_world_job(recipe)

func _show_candidate_rule() -> void:
	var rule: Dictionary = _selected_reaction()
	if rule.is_empty(): return
	_reaction_report.text = "Candidate rule (not active):\n" + JSON.stringify(rule,"\t") + "\nChance: %d / 256 = %.6f%%" % [int(rule.probability)+1,100.0*(int(rule.probability)+1)/256.0]

func _retire_reaction_diagnostic() -> void:
	_reaction_input_revision += 1
	if _reaction_report.text.is_empty(): return
	_show_candidate_rule()
	_reaction_report.text = "Diagnostic inputs changed. Inspect native result or compile the candidate reaction for a fresh resolver receipt.\n\n" + (_reaction_report.text if not _selected_reaction().is_empty() else "")

func _exit_tree() -> void:
	_running = false
	experiment.close()

func inspect_reaction() -> void:
	_commit_spinbox(_roll)
	if _partner.selected >= 0:
		_reaction_report.text = JSON.stringify(Experiment.resolver_diagnostic(selected_id,_partner.get_selected_id(),int(_roll.value)),"\t")

func start_experiment() -> void:
	_commit_spinbox(_seed)
	_commit_spinbox(_steps)
	_running = false
	if _partner.selected < 0: return
	var definition: Dictionary = Experiment.definition_for_pair(selected_id,_partner.get_selected_id(),int(_seed.value),int(_steps.value))
	if definition.is_empty() or not experiment.start(definition,_workers.get_selected_id(),Experiment.WATER_FAMILIES[_family.selected]):
		_status.text = "Native experiment rejected: " + experiment.last_error
		return
	_tabs.current_tab = 3
	_status.text = "Experiment prepared. Applied Water policy is read back from this isolated native owner."
	_sync_experiment_controls()
	_refresh_experiment()

func _sync_experiment_controls() -> void:
	var configuration: Dictionary = experiment.configuration()
	if not configuration.get("ok",false): return
	_seed.value = int(configuration.seed)
	_steps.value = int(configuration.duration_ticks)
	_workers.select(_workers.get_item_index(int(configuration.workers)))
	_family.select(Experiment.WATER_FAMILIES.find(str(configuration.water_family_request)))
	var pair: Dictionary = configuration.pair
	if not pair.is_empty():
		_select_partner(int(pair.second))
		select_material(int(pair.first))
		_refresh_list()
	if policy_context == "Isolated native test owner":
		set_policy_readback(experiment.readback().get("applied_policy",{}),policy_context)
	_refresh_experiment_request()

func _pause_experiment() -> void:
	_running = false
	if experiment.reference_running():
		experiment.cancel_reference()
		_experiment_report.text = JSON.stringify(experiment.reference_progress(),"\t")
		_status.text = "Reference comparison cancelled; the source run is preserved."
	elif experiment.active():
		_status.text = "Native run paused at completed tick %d." % int(experiment.readback().get("completed_tick",0))
		_refresh_experiment()

func _step_experiment(count: int) -> void:
	if not experiment.step(count):
		_running = false
		_status.text = "Experiment stopped: " + experiment.last_error
	_refresh_experiment()

func _refresh_experiment() -> void:
	last_contact_report.clear()
	var readback: Dictionary = experiment.readback()
	_experiment_report.text = JSON.stringify(readback,"\t")
	if readback.get("ok",false):
		var counts: Array[String] = []
		for key: String in readback.get("material_counts",{}):
			var id: int = int(key)
			if id == 0 or id == 1: continue
			var label: String = str(catalogue.materials[id].name) if id < catalogue.materials.size() else str(id)
			counts.append("%s %s" % [label,readback.material_counts[key]])
		_experiment_summary.text = "Prepared: %s · %s\nNative tick %s / %s · seed %s · %s worker(s) · Water %s · %s\n%s" % [readback.definition_title,str(readback.definition_hash).left(16),readback.completed_tick,readback.duration_ticks,readback.seed,readback.workers,readback.water_family_request,"Completed" if readback.completed else ("Running" if _running else "Paused / prepared"),", ".join(counts)]
	else:
		_experiment_summary.text = "Native test unavailable: " + str(readback.get("error","No prepared experiment."))
		_preview.texture = null
	var image: Image = experiment.preview_image()
	if image != null and not image.is_empty(): _preview.texture = ImageTexture.create_from_image(image)

func _inspect_test_cell() -> void:
	_commit_spinbox(_cell_x)
	_commit_spinbox(_cell_y)
	_running = false
	experiment.cancel_reference("Reference paused to inspect native cell storage.")
	_refresh_experiment()
	var observation: Dictionary = experiment.inspect_cell(Vector2i(int(_cell_x.value),int(_cell_y.value)))
	_experiment_report.text = JSON.stringify(observation,"\t")
	_status.text = "Stored native cell read at the paused completed tick." if observation.get("ok",false) else str(observation.get("error","Cell readback refused."))

func _inspect_test_contact() -> void:
	_commit_contact_fields()
	_running = false
	experiment.cancel_reference("Reference paused to inspect native contact facts.")
	_refresh_experiment()
	last_contact_report = experiment.inspect_contact(Vector2i(int(_cell_x.value),int(_cell_y.value)),
		Vector2i(int(_target_x.value),int(_target_y.value)),int(_contact_roll.value))
	_experiment_report.text = Experiment.contact_report_text(last_contact_report)
	_status.text = "Contact snapshot read from the paused native owner; no reaction was executed by inspection." if last_contact_report.get("ok",false) else str(last_contact_report.get("error","Contact readback refused."))

func _commit_contact_fields() -> void:
	for field: SpinBox in [_cell_x,_cell_y,_target_x,_target_y,_contact_roll]: _commit_spinbox(field)

func _retire_contact_report() -> void:
	if not last_contact_report.is_empty():
		last_contact_report.clear()
		_experiment_report.text = "Contact inputs changed. Inspect contact to read the current native cells and supplied roll."

func _pick_experiment_cell(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return
	if _preview.texture == null or not experiment.active(): return
	var image_size: Vector2 = _preview.texture.get_size()
	if image_size.x <= 0 or image_size.y <= 0: return
	var scale: float = minf(_preview.size.x / image_size.x,_preview.size.y / image_size.y)
	if scale <= 0: return
	var drawn: Rect2 = Rect2((_preview.size - image_size * scale) / 2.0,image_size * scale)
	if not drawn.has_point(event.position): return
	var point: Vector2i = experiment.preview_region().position + Vector2i(((event.position - drawn.position) / scale).floor())
	if event.button_index == MOUSE_BUTTON_LEFT:
		_cell_x.value = point.x
		_cell_y.value = point.y
	else:
		_target_x.value = point.x
		_target_y.value = point.y
	_inspect_test_contact()
	_preview.accept_event()

func _compare_reference() -> void:
	_running = false
	_refresh_experiment()
	var progress: Dictionary = experiment.begin_reference()
	_experiment_report.text = JSON.stringify(progress,"\t")
	_status.text = "Replaying a fresh native reference; Pause cancels the comparison." if progress.get("ok",false) else str(progress.get("error","Reference comparison failed."))

func _process(_delta: float) -> void:
	if experiment.reference_running():
		var progress: Dictionary = experiment.advance_reference(1)
		if not experiment.reference_running() or int(progress.get("completed_tick",0)) % 4 == 0:
			_experiment_report.text = JSON.stringify(progress,"\t")
			_status.text = "Reference replay %d / %d ticks; source run paused." % [int(progress.get("completed_tick",0)),int(progress.get("target_tick",0))]
		if not experiment.reference_running():
			_status.text = ("Reference matches the recorded native content and Water quantity." if progress.get("equal",false) else "Reference completed with a native difference.") if progress.get("ok",false) else str(progress.get("error","Reference comparison failed."))
		return
	if _running:
		if not experiment.step(1):
			_running = false
			_status.text = "Native experiment stopped: " + experiment.last_error
		elif experiment.completed():
			_running = false
			_status.text = "Prepared native window completed. Readback belongs to the definition shown above."
		if not _running or experiment.completed_tick() % 4 == 0: _refresh_experiment()

func _open_file(action: String, saving: bool) -> void:
	_commit_candidate_fields()
	world_panel.commit_fields()
	if action in ["export_preset","compile_bundle","world_bundle","export_world_case"] and candidate.is_empty():
		_status.text = "Create a candidate before saving a preset."
		return
	_file_action = action
	_file.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	if action in ["compile_bundle","world_bundle"]: _file.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_file.title = action.replace("_"," ").capitalize()
	DirAccess.make_dir_recursive_absolute("user://materials_lab/presets")
	_file.current_dir = ProjectSettings.globalize_path("user://materials_lab/presets")
	_file.current_file = "material-preset.json" if action == "export_preset" else "material-test.json"
	if action == "export_world_case": _file.current_file = "material-world-recipe.json"
	_file.popup_centered_ratio(0.7)

func _file_selected(path: String) -> void:
	_commit_candidate_fields()
	world_panel.commit_fields()
	match _file_action:
		"world_bundle":
			_world_job(world_panel.scenario(),path.path_join("material-world-%d-%d" % [candidate.target_id,Time.get_ticks_usec()]))
		"compile_bundle":
			var directory: String = path.path_join("material-%d-%d" % [candidate.target_id,Time.get_ticks_usec()])
			var request: Dictionary = {"op":"compile_test","candidate":candidate.duplicate(true),"output_dir":directory}
			if not _compiler.text.strip_edges().is_empty(): request.cxx = _compiler.text.strip_edges()
			var rule: Dictionary = _selected_reaction()
			if not rule.is_empty(): request.diagnostic = {"source":rule.first,"target":rule.second,"roll":int(_roll.value)}
			_start_job(request)
		"import_preset": _start_job({"op":"import","path":path})
		"export_preset": _start_job({"op":"export","candidate":candidate.duplicate(true),"path":path})
		"import_world_case": _start_job({"op":"import_world_case","path":path})
		"export_world_case": _start_job({"op":"export_world_case","candidate":candidate.duplicate(true),"scenario":world_panel.scenario(),"path":path})
		"import_test":
			_running = false
			if not experiment.start_case_json(FileAccess.get_file_as_string(path)):
				_status.text = "Test case rejected: " + experiment.last_error
			else:
				_status.text = "Test case loaded with its native policy and source-bound configuration."
				_sync_experiment_controls()
				_tabs.current_tab = 3
				_refresh_experiment()
		"export_test":
			var data: String = experiment.case_json()
			if data.is_empty():
				_status.text = experiment.last_error if not experiment.last_error.is_empty() else "Prepare a valid native test before saving."
				return
			var file := FileAccess.open(path,FileAccess.WRITE)
			if file == null:
				_status.text = "Could not save the test case."
				return
			file.store_string(data + "\n")
			file.close()
			_status.text = "Saved reproducible test case: " + path

func _commit_candidate_fields() -> void:
	# Button activation can precede the SpinBox focus-exit callback. Commit
	# displayed text before copying a candidate or capturing its revision.
	for field: SpinBox in _fields.values(): _commit_spinbox(field)
	if _reaction_fields.has("probability"): _commit_spinbox(_reaction_fields.probability)
	for controls: Dictionary in _effect_fields.values(): _commit_spinbox(controls.state_b)
	_commit_spinbox(_roll)

func _commit_spinbox(field: SpinBox) -> void:
	if field.get_line_edit().has_focus() or field.get_meta("lab_pending_text",false):
		field.apply()
		field.set_meta("lab_pending_text",false)
		field.get_line_edit().release_focus()
