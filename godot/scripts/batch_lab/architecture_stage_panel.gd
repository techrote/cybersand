extends Window
## Optional architecture authoring. All construction passes through reviewed
## typed stages and the ordinary native Workbench executor/history.
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Session = preload("res://scripts/batch_lab/architecture_stage_session.gd")
const Examples = preload("res://scripts/batch_lab/architecture_examples.gd")
const ModuleCompositions = preload("res://scripts/batch_lab/architecture_module_compositions.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const Module = preload("res://scripts/batch_lab/native_module.gd")
const View = preload("res://scripts/batch_lab/batch_lab_view.gd")
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const DocumentEditor = preload("res://scripts/batch_lab/architecture_document_editor.gd")
const ModuleCanvas = preload("res://scripts/batch_lab/architecture_module_canvas.gd")
const SemanticsEditor = preload("res://scripts/batch_lab/architecture_semantics_editor.gd")
const WorkflowPanel = preload("res://scripts/batch_lab/architecture_workflow_panel.gd")
const Connections = preload("res://scripts/batch_lab/native_module_connections.gd")
const Catalogue = preload("res://scripts/batch_lab/native_module_catalogue.gd")
const Flagships = preload("res://scripts/batch_lab/architecture_flagships.gd")
const HierarchyDemo = preload("res://scripts/batch_lab/architecture_hierarchy_demo.gd")
const DetailPanel = preload("res://scripts/batch_lab/architecture_detail_panel.gd")
var wb: Node
var library := Library.new()
var session: Node
var workflow: Node
var workflow_panel: Control
var detail_panel: Control
var status := Label.new()
var tabs := TabContainer.new()
var search := LineEdit.new()
var part_filter := OptionButton.new()
var modules := ItemList.new()
var module_ids: Array[String] = []
var module_view: Control
var inspect := TextEdit.new()
var module_summary := Label.new()
var module_semantics: Window
var palette_controls := HFlowContainer.new()
var palette_choices: Dictionary = {}
var source_connector := OptionButton.new()
var target_connector := OptionButton.new()
var snap_list := ItemList.new()
var snap_status := Label.new()
var _snap_inventory := {}
var _snap_candidates: Array = []
var _snap_request := {}
var module_guides := CheckBox.new()
var _thumbnail_cache: Dictionary = {}
var _thumbnail_queue: Array = []
var _thumbnail_epoch := 0
var _selected_content := ""
var _search_timer := Timer.new()
var module_name := LineEdit.new()
var module_tags := LineEdit.new()
var module_kind := OptionButton.new()
var transform := OptionButton.new()
var palette := LineEdit.new()
var seed: SpinBox
var keep: SpinBox
var columns: SpinBox
var rows: SpinBox
var gap: SpinBox
var flagship := OptionButton.new()
var area_fields: Array[SpinBox] = []
var origin_fields: Array[SpinBox] = []
var allow_turns := CheckBox.new()
var stage_list := ItemList.new()
var stage_editor := DocumentEditor.new()
var stage_advanced := CheckBox.new()
var stage_intent := TextEdit.new()
var stage_region: Array[SpinBox] = []
var stage_brief := Label.new()
var stage_parts := ItemList.new()
var result_tabs := TabContainer.new()
var prepare_local_button: Button
var workshop_revision_button: Button
var workshop_recovery_button: Button
var source_view: Control
var native_view: Control
var source_label := Label.new()
var native_label := Label.new()
var _last_source := ""
var _last_native := ""
var _last_view_state := ""
var _refresh_scheduled := false
var preview_view: Control
var preview_label := Label.new()
var example := OptionButton.new()
var reference_query := LineEdit.new()
var reference_text := TextEdit.new()
var evidence_text := TextEdit.new()
var _file := FileDialog.new()
var _action := ""
var _harvesting := false
var _epoch := 0
var _last_stage := ""
var _starter_controller: Node
var _building_starters := false
var art_proposal_mount: Node
var art_proposal_dialog: ConfirmationDialog
var _art_proposal_digest := ""

func _ready() -> void:
	title = "Architecture · native modules and staged construction"
	size = Vector2i(1160,780)
	min_size = Vector2i(840,580)
	transient = true
	exclusive = false
	close_requested.connect(_close)
	var dense := Theme.new()
	dense.default_font_size = 14
	theme = dense
	session = Session.new()
	session.wb = wb
	session.library = library
	add_child(session)
	session.changed.connect(_schedule_session_refresh)
	var workflow_path:="res://scripts/batch_lab/architecture_workflow.gd"
	if ResourceLoader.exists(workflow_path):
		workflow=load(workflow_path).new()
		add_child(workflow)
		workflow.bind_session(session)
		workflow.changed.connect(_schedule_session_refresh)
	_build()
	if FileAccess.file_exists(Library.DEFAULT_PATH):
		var restored: Dictionary = library.load_library()
		_note(str(restored.get("reason","Saved module library loaded.")))
	_refresh_modules()
	load_example()

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row

func _label(parent: Node, text: String) -> Label:
	var value := Label.new()
	value.text = text
	parent.add_child(value)
	return value

func _button(parent: Node, text: String, action: Callable, tip := "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _spin(parent: Node, name: String, min_value: float, max_value: float, value: float, step := 1.0) -> SpinBox:
	_label(parent,name)
	var field := SpinBox.new()
	field.min_value = min_value
	field.max_value = max_value
	field.step = step
	field.value = value
	field.custom_minimum_size.x = 72
	parent.add_child(field)
	return field

func _scroll_tab(name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body

func _view_controls(parent: Node, view: Control) -> void:
	var controls := HFlowContainer.new()
	parent.add_child(controls)
	_button(controls,"Fit",view.fit,"Show the complete native extent.")
	_button(controls,"1:1",view.native_scale,"One material cell per view pixel. Pan to inspect a larger extent.")
	_label(controls,"Wheel: zoom · right/middle drag: pan")

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
	add_child(margin)
	var body := VBoxContainer.new()
	margin.add_child(body)
	var top := HFlowContainer.new()
	body.add_child(top)
	_button(top,"Save session…",func() -> void: _choose_file("save_session"))
	_button(top,"Open session…",func() -> void: _choose_file("open_session"))
	_button(top,"Save modules",save_modules)
	_button(top,"Build 8 starter parts",build_starter_parts,"Construct the typed structural parts in private native Batch tiles, then harvest their actual readback. Existing Batch experiments are preserved.")
	_button(top,"Add curated templates",add_curated_templates,"Add forty code-authored part templates without writing to a World. They remain unexecuted source projections until an exact native replay is observed.")
	_button(top,"Import module…",func() -> void: _choose_file("import_module"))
	_button(top,"Import library…",func() -> void: _choose_file("import_library"),"Open a bounded library with its exact source module identities. Imported qualification remains historical.")
	_button(top,"Export module…",func() -> void: _choose_file("export_module"))
	_button(top,"Undo native edit",func() -> void: _history(false),"Uses the ordinary Workbench authoring history.")
	_button(top,"Redo native edit",func() -> void: _history(true))
	_button(top,"Stop / cancel",stop_all,"Cancel planning and stop any admitted native work. Already applied cells remain in ordinary Undo history.")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 3
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(status)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	_build_modules()
	_build_stages()
	_build_references()
	_build_workflow()
	var detail_body:=_scroll_tab("Detail jobs")
	detail_panel=DetailPanel.new(); detail_body.add_child(detail_panel)
	detail_panel.bind(session,workflow)
	detail_panel.review_requested.connect(func() -> void: _last_stage=""; _refresh_session(); tabs.current_tab=1)
	_file.access = FileDialog.ACCESS_FILESYSTEM
	_file.filters = PackedStringArray(["*.json ; Architecture and module documents"])
	_file.file_selected.connect(_file_selected)
	add_child(_file)

func _build_modules() -> void:
	var body := _scroll_tab("Modules")
	var find := _row(body)
	search.placeholder_text = "Search names, tags and structural parts"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_text: String) -> void: _schedule_search())
	_search_timer.one_shot=true
	_search_timer.wait_time=0.12
	_search_timer.timeout.connect(_refresh_modules)
	add_child(_search_timer)
	find.add_child(search)
	part_filter.add_item("All parts")
	for part: String in Module.PART_TYPES: part_filter.add_item(part.replace("_"," "))
	part_filter.item_selected.connect(func(_index: int) -> void: _refresh_modules())
	find.add_child(part_filter)
	var split := HSplitContainer.new()
	split.custom_minimum_size.y = 270
	body.add_child(split)
	modules.custom_minimum_size.x = 250
	modules.fixed_icon_size = Vector2i(80,56)
	modules.icon_mode = ItemList.ICON_MODE_LEFT
	modules.add_theme_constant_override("v_separation",8)
	modules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modules.item_selected.connect(_select_module)
	split.add_child(modules)
	module_view = ModuleCanvas.new()
	module_view.custom_minimum_size = Vector2(270,250)
	module_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(module_view)
	_view_controls(body,module_view)
	var guides := HFlowContainer.new()
	body.add_child(guides)
	module_guides.text = "Show authored / inferred guides"
	module_guides.button_pressed = true
	module_guides.toggled.connect(func(value: bool) -> void: module_view.show_guides=value; module_view.queue_redraw())
	guides.add_child(module_guides)
	_label(guides,"White anchor · green authored connector · purple inferred · blue clearance · red protected · gold variable")
	module_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(module_summary)
	var connector_row := _row(body)
	_label(connector_row,"Inspect connector")
	source_connector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	source_connector.item_selected.connect(func(index: int) -> void:
		module_view.selected_connector=str(source_connector.get_item_metadata(index))
		module_view.queue_redraw())
	connector_row.add_child(source_connector)
	_button(guides,"Edit module semantics…",edit_semantics,"Edit anchor, roles, connectors and local regions as explicit authored metadata. Geometry and provenance stay read-only.")
	inspect.editable = false
	body.add_child(inspect)
	inspect.hide()
	module_semantics = SemanticsEditor.new()
	module_semantics.library = library
	module_semantics.committed.connect(func(_id: String) -> void: _selected_content=""; _refresh_modules(); _result(library.save()))
	add_child(module_semantics)
	var name_row := _row(body)
	_label(name_row,"Name")
	module_name.text = "Native structural part"
	module_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(module_name)
	_label(name_row,"Tags")
	module_tags.placeholder_text = "industrial, support"
	module_tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(module_tags)
	for part: String in Module.PART_TYPES: module_kind.add_item(part.replace("_"," "))
	module_kind.select(Module.PART_TYPES.size()-1)
	name_row.add_child(module_kind)
	_button(name_row,"Rename / tag",annotate_module)
	var region := _row(body)
	_label(region,"Harvest / authorized region")
	for spec: Array in [["X",0,2047,16],["Y",0,2047,16],["W",1,512,128],["H",1,512,128]]:
		area_fields.append(_spin(region,spec[0],spec[1],spec[2],spec[3]))
	var harvest := _row(body)
	_button(harvest,"Harvest native region",harvest_region,"Capture actual stored material identities. Geometry is observed; structural semantics remain explicitly authored.")
	_button(harvest,"Harvest selected Batch tile",harvest_selected_tile)
	allow_turns.text = "Allow grid mirror / quarter turns"
	allow_turns.tooltip_text = "Explicit author permission. This does not establish support orientation or physical suitability."
	harvest.add_child(allow_turns)
	var place := _row(body)
	_label(place,"Placement")
	origin_fields.append(_spin(place,"X",0,2047,16))
	origin_fields.append(_spin(place,"Y",0,2047,16))
	for item: String in Module.TRANSFORMS: transform.add_item(item.replace("_"," "))
	place.add_child(transform)
	columns = _spin(place,"Columns",1,8,1)
	rows = _spin(place,"Rows",1,8,1)
	gap = _spin(place,"Gap",0,128,8)
	var variant := _row(body)
	_label(body,"Compatible material roles · unchanged geometry uses the original material identities")
	body.add_child(palette_controls)
	palette.text = "{}"
	# Kept as a bounded programmatic value for existing typed integrations; the
	# ordinary flow uses named role/material choices instead of JSON entry.
	palette.max_length = 8192
	body.add_child(palette)
	palette.hide()
	seed = _spin(variant,"Seed",0,2147483647,37901)
	keep = _spin(variant,"Detail retained",0,1,1,0.05)
	_button(variant,"Propose placement",propose_placement,"Create a finite stage; inspect and approve its actual footprint before native construction.")
	_build_snap(body)

func _actions() -> Node:
	return workflow if is_instance_valid(workflow) else session

func authoring_busy() -> bool:
	var owner := _actions()
	return _harvesting or _building_starters or (is_instance_valid(owner) and owner.busy())

func _build_workflow() -> void:
	var body:=_scroll_tab("Intent and tasks")
	workflow_panel=WorkflowPanel.new()
	body.add_child(workflow_panel)
	workflow_panel.bind(workflow)
	workflow_panel.review_stage.connect(func(_index: int) -> void:
		_last_stage=""; _refresh_session(); tabs.current_tab=1)
	workflow_panel.save_history_requested.connect(func() -> void: _choose_file("save_decisions"))
	workflow_panel.open_history_requested.connect(func() -> void: _choose_file("open_decisions"))
	workflow_panel.art_configuration_requested.connect(func() -> void: wb.open_art_batches())
	workflow_panel.art_proposal_requested.connect(prepare_art_proposal)

func prepare_art_proposal() -> Dictionary:
	if not is_instance_valid(workflow) or not is_instance_valid(wb):
		return {"ok":false,"reason":"The ordinary Workbench is unavailable."}
	if not is_instance_valid(art_proposal_mount):
		art_proposal_mount = preload("res://scripts/batch_lab/art_architecture_mount.gd").new()
		add_child(art_proposal_mount)
		art_proposal_mount.bind(self)
		art_proposal_mount.changed.connect(_art_proposal_changed)
	var answer: Dictionary = await art_proposal_mount.prepare()
	if answer.get("ok",false): _show_art_proposal_disclosure()
	_note(str(answer.get("reason","Proposal preparation refused.")))
	return answer

func _show_art_proposal_disclosure() -> void:
	var disclosed: Dictionary = art_proposal_mount.disclosure()
	if disclosed.is_empty(): return
	if is_instance_valid(art_proposal_dialog): art_proposal_dialog.queue_free()
	art_proposal_dialog = ConfirmationDialog.new()
	art_proposal_dialog.title = "Review Architecture request before sending"
	art_proposal_dialog.ok_button_text = "Send this proposal request"
	art_proposal_dialog.cancel_button_text = "Cancel request"
	art_proposal_dialog.min_size = Vector2i(640,420)
	add_child(art_proposal_dialog)
	var body := VBoxContainer.new()
	art_proposal_dialog.add_child(body)
	var destination := Label.new()
	destination.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	destination.custom_minimum_size.x = 600
	destination.text = "%s · %s\n%s\nUp to %d output tokens · %.0f seconds · %s\n%s\nSend authorizes one provider request. Construction still requires a separate preview and approval for each stage." % [
		disclosed.provider,disclosed.model,disclosed.endpoint,disclosed.tokens,disclosed.seconds,disclosed.endpoint_category,disclosed.scope]
	body.add_child(destination)
	var text := TextEdit.new()
	text.editable = false
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.custom_minimum_size = Vector2(600,260)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.text = "Provider instructions:\n"+str(disclosed.instructions)+"\n\nAdmitted Architecture request (reference data):\n"+str(disclosed.request_text)
	body.add_child(text)
	_art_proposal_digest = str(disclosed.digest)
	art_proposal_dialog.confirmed.connect(send_art_proposal)
	art_proposal_dialog.canceled.connect(func() -> void: art_proposal_mount.cancel("Unsent Architecture request cancelled"))
	art_proposal_dialog.popup_centered_clamped(Vector2i(800,600),0.90)

func send_art_proposal() -> Dictionary:
	if not is_instance_valid(art_proposal_mount): return {"ok":false,"reason":"Prepare a proposal request first."}
	var answer: Dictionary = art_proposal_mount.send_disclosed(_art_proposal_digest)
	if is_instance_valid(art_proposal_dialog): art_proposal_dialog.hide()
	_note(str(answer.get("reason","Proposal request refused.")))
	return answer

func _art_proposal_changed(message: String) -> void:
	_note(message)
	if is_instance_valid(art_proposal_dialog) and art_proposal_mount.disclosure().is_empty():
		art_proposal_dialog.hide()

func _build_snap(parent: Node) -> void:
	_label(parent,"Connection proposals · exact grid poses against inspected native contacts")
	var row:=HFlowContainer.new()
	parent.add_child(row)
	_button(row,"Inspect native target connectors",inspect_snap_targets)
	row.add_child(target_connector)
	target_connector.custom_minimum_size.x=280
	_button(row,"Find bounded snap poses",find_snap_poses)
	snap_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(snap_status)
	snap_status.text="Targets are contacts from completed native placements in this session. Inspect the authorized region; imported declarations alone are not target authority."
	snap_list.custom_minimum_size.y=100
	parent.add_child(snap_list)
	_button(parent,"Propose selected snapped placement",propose_snap,"Create one content-pinned stage with an explicit connector binding; fresh native preview and approval still follow.")

func inspect_snap_targets() -> void:
	if _harvesting or _building_starters or _actions().busy(): _note("Wait for the current native action."); return
	var epoch:=_epoch
	var captured: Dictionary=await session.inspect_region(_region())
	if epoch!=_epoch: return
	if not _result(captured): return
	_snap_inventory=session.connection_targets()
	target_connector.clear(); snap_list.clear(); _snap_candidates.clear(); _snap_request.clear()
	for target: Dictionary in _snap_inventory.get("targets",[]):
		target_connector.add_item("%s / %s · %s" % [target.module_instance,target.id,str(target.point)])
	target_connector.disabled=target_connector.item_count==0
	snap_status.text="%d contact descriptor(s) rechecked against the current native snapshot. This verifies contact material cells, not the whole part or physical support. %d omitted revision(s)." % [target_connector.item_count,_snap_inventory.get("omissions",[]).size()]
	_refresh_result_views(true)

func find_snap_poses() -> void:
	_snap_candidates.clear(); snap_list.clear(); _snap_request.clear()
	var module:=_selected_module()
	if module.is_empty() or source_connector.item_count==0 or str(source_connector.get_item_metadata(source_connector.selected)).is_empty(): snap_status.text="Select a version 2 source module and declared connector."; return
	if target_connector.selected<0 or target_connector.selected>=_snap_inventory.get("targets",[]).size(): snap_status.text="Inspect and select a native target connector first."; return
	var inspected: Dictionary=session.inspection_view()
	var inventory: Dictionary=session.connection_targets()
	if not inspected.get("ok",false) or inspected.get("stale",true) or not inventory.get("ok",false) or Compiler.rect(inspected.region)!=_region():
		snap_status.text="The selected native inspection is stale or belongs to another region. Inspect target connectors again."; return
	var target: Dictionary=_snap_inventory.targets[target_connector.selected]
	var still_present:=false
	for current: Dictionary in inventory.targets:
		if current.module_instance==target.module_instance and current.id==target.id and current==target: still_present=true; break
	if not still_present: snap_status.text="Target contact identity changed. Inspect again."; return
	var palette_value: Variant=JSON.parse_string(palette.text)
	if not palette_value is Dictionary: snap_status.text="Role palette is invalid."; return
	var references: Dictionary={}
	for current: Dictionary in inventory.targets: references[Module.json_bytes([current.module_instance,current.id]).get_string_from_utf8()]=true
	var bindings: Array=[]
	for contact: Dictionary in inventory.get("reserved_contacts",[]):
		var a:=Module.json_bytes([contact.a.instance,contact.a.connector]).get_string_from_utf8()
		var b:=Module.json_bytes([contact.b.instance,contact.b.connector]).get_string_from_utf8()
		if references.has(a) and references.has(b): bindings.append({"a":contact.a.duplicate(),"b":contact.b.duplicate()})
	var instance:="ui-snap-"+str(Time.get_ticks_usec())
	var controls:={"region":inspected.region,"projected_cells":inspected.cells,"protected":[],"clearances":[],
		"allowed_materials":Setup.MATERIALS.duplicate(),"max_cells":262144,"transforms":module.allowed_transforms.duplicate(),
		"source_instance":instance,"existing_connectors":inventory.targets,"bindings":bindings,
		"reserved_contacts":inventory.get("reserved_contacts",[]),"preferred_origin":[int(origin_fields[0].value),int(origin_fields[1].value)],
		"limit":24,"search_budget":256,"palette":palette_value,"variation":{"seed":int(seed.value),"keep_fraction":keep.value}}
	var answer:=Connections.snap_candidates(module,str(source_connector.get_item_metadata(source_connector.selected)),target,controls)
	for candidate: Dictionary in answer.get("candidates",[]):
		var placement: Dictionary=candidate.placement
		# The shared finite solver includes all retained native reservations,
		# including partners outside this inspection. Stage compilation repeats it.
		_snap_candidates.append(candidate)
		snap_list.add_item("%s at %s · %d contact cells · %s ↔ %s" % [placement.transform,str(placement.origin),candidate.contact.cell_count,str(candidate.contact.a_span),str(candidate.contact.b_span)])
	_snap_request={"module_id":module.id,"module_sha256":module.content_sha256,"instance_id":instance,"source_sha256":inspected.source_sha256,
		"generation":inspected.generation,"region":inspected.region.duplicate(),"palette":palette_value.duplicate(),"variation":controls.variation.duplicate()}
	if not _snap_candidates.is_empty(): snap_list.select(0)
	snap_status.text="%d zero-write pose proposal(s) · %d considered%s. Contact spans are exact grid declarations; native preview still checks permissions, protected geometry and current capacity." % [_snap_candidates.size(),answer.get("considered",0)," · finite search exhausted" if answer.get("truncated",false) else ""]
	if _snap_candidates.is_empty(): snap_status.text+="\n"+"; ".join(answer.get("reasons",[]))

func propose_snap() -> void:
	if _actions().busy() or _harvesting: _note("Wait for the current native action."); return
	var selection:=snap_list.get_selected_items()
	if selection.is_empty() or selection[0]>=_snap_candidates.size(): _note("Find and select a bounded snap pose first."); return
	var module:=_selected_module()
	var inspected: Dictionary=session.inspection_view()
	if module.get("content_sha256")!=_snap_request.get("module_sha256") or not inspected.get("ok",false) or inspected.get("stale",true) or inspected.source_sha256!=_snap_request.source_sha256:
		_note("Source module or native inspection changed. Find fresh snap poses."); return
	var candidate: Dictionary=_snap_candidates[selection[0]]
	var current_palette: Variant=JSON.parse_string(palette.text)
	if not current_palette is Dictionary or Module.json_bytes(current_palette)!=Module.json_bytes(_snap_request.palette) or \
		Module.json_bytes({"seed":int(seed.value),"keep_fraction":keep.value})!=Module.json_bytes(_snap_request.variation) or _region()!=Compiler.rect(_snap_request.region) or \
		str(source_connector.get_item_metadata(source_connector.selected))!=str(candidate.source_connector.connector):
		_note("Connector, region or variation controls changed. Find fresh snap poses for these values."); return
	var stage:=Compiler.stage_defaults("snap-"+str(Time.get_ticks_usec()),Compiler.rect(_snap_request.region))
	stage.intent="Connect "+module.name+" to a native inspected authored contact."
	stage.modules=[{"module_id":module.id,"module_sha256":module.content_sha256,"instance_id":_snap_request.instance_id,"placement":candidate.placement.duplicate(true)}]
	stage["module_bindings"]=[{"a":candidate.source_connector.duplicate(),"b":candidate.target.duplicate()}]
	var plan:={"format":Compiler.FORMAT,"id":"snap-plan-"+str(Time.get_ticks_usec()),"intent":stage.intent,"stages":[stage]}
	if _result(_actions().load_plan(Module.canonical(plan))):
		_last_stage=""; _refresh_session(); tabs.current_tab=1
		_note("Snapped placement proposed. Inspect + preview, then explicitly approve this exact native stage.")

func _build_stages() -> void:
	var body := VBoxContainer.new()
	body.name = "Construction"
	tabs.add_child(body)
	var top := _row(body)
	for family: String in Examples.families(): example.add_item(family)
	for family: String in ModuleCompositions.families(): example.add_item(family)
	example.tooltip_text = "Six typed side elevations and three compositions of harvested starter parts. Build the starter library before loading a modular example."
	example.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(example)
	_button(top,"Load example",load_example)
	_button(top,"Import typed plan…",func() -> void: _choose_file("import_plan"))
	var large:=_row(body)
	for family: String in Flagships.families():
		var extent: Vector2i=Flagships.extent(family)
		flagship.add_item("%s · %d × %d" % [Flagships.TITLES[family],extent.x,extent.y])
		flagship.set_item_metadata(flagship.item_count-1,family)
	flagship.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	large.add_child(flagship)
	_button(large,"Load flagship tasks",load_flagship,"Load a finite hierarchy into the existing World. A smaller World is refused; use ordinary New to choose the stated size first. Loading does not construct or erase geometry.")
	var workshop := HFlowContainer.new()
	body.add_child(workshop)
	_button(workshop,"Load delegated workshop",load_delegated_workshop,"Load a finite proposal with three bounded local workers. Requires a 512 × 512 World and the curated parts; nothing is approved or constructed.")
	workshop_revision_button=_button(workshop,"Propose clear access gallery",revise_workshop_gallery,"Replace the selected workshop access proposal with a side gallery around the protected passage. Preview and approval remain separate.")
	workshop_recovery_button=_button(workshop,"Propose recovery from stopped trial",recover_workshop,"Requires the current workshop's acknowledged partial cladding receipt and an unchanged native region. Loading recovery does not apply it.")
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 310
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	stage_list.custom_minimum_size.y = 120
	stage_list.item_selected.connect(func(index: int) -> void:
		var answer: Dictionary = _actions().select(index)
		if answer.ok: _last_stage = ""; _refresh_session())
	left.add_child(stage_list)
	var details_scroll := ScrollContainer.new()
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(details_scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(details)
	_label(details,"Stage intent")
	stage_intent.custom_minimum_size.y = 70
	stage_intent.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	details.add_child(stage_intent)
	var region := HFlowContainer.new()
	details.add_child(region)
	for spec: Array in [["X",0,2047,0],["Y",0,2047,0],["W",1,512,128],["H",1,512,128]]:
		stage_region.append(_spin(region,spec[0],spec[1],spec[2],spec[3]))
	stage_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(stage_brief)
	stage_parts.custom_minimum_size.y = 100
	details.add_child(stage_parts)
	stage_advanced.text = "Advanced typed stage · optional paged editor"
	stage_advanced.toggled.connect(func(value: bool) -> void:
		stage_editor.visible=value
		if value and not session.plan.is_empty(): stage_editor.text=JSON.stringify(session.stage(),"  "))
	details.add_child(stage_advanced)
	details.add_child(stage_editor)
	stage_editor.hide()
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	result_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(result_tabs)
	source_view = _result_pane("Inspected source",source_label)
	preview_view = _result_pane("Zero-write projection",preview_label)
	native_view = _result_pane("Native result",native_label)
	source_label.text = "No actual native region inspected yet. Inspect + preview captures its material identities without writes."
	preview_label.text = "No current approval preview."
	native_label.text = "No verified native result retained for this stage."
	evidence_text.editable = false
	evidence_text.custom_minimum_size.y = 96
	evidence_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	right.add_child(evidence_text)
	var actions := HFlowContainer.new()
	body.add_child(actions)
	prepare_local_button=_button(actions,"Prepare local job",prepare_local_job,"For a ready delegated task, inspect its actual source and prepare a finite procedural proposal. Preview and approval remain separate owner decisions.")
	prepare_local_button.disabled=true
	_button(actions,"Inspect + zero-write preview",preview_stage)
	_button(actions,"Approve stage",approve_stage)
	_button(actions,"Revise stage",revise_stage)
	_button(actions,"Skip stage",func() -> void: _actions().skip())
	_button(actions,"Stop / cancel",stop_all)
	_button(actions,"Next stage",func() -> void:
		if not session.plan.is_empty():
			if _actions().select(mini(session.selected+1,session.plan.stages.size()-1)).ok: _last_stage=""; _refresh_session())

func _result_pane(name_text: String, label: Label) -> Control:
	var body := VBoxContainer.new()
	body.name=name_text
	result_tabs.add_child(body)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 4
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(label)
	var view := View.new()
	view.custom_minimum_size = Vector2(310,220)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(view)
	_view_controls(body,view)
	return view

func _build_references() -> void:
	var body := VBoxContainer.new()
	body.name = "References"
	tabs.add_child(body)
	var row := _row(body)
	reference_query.placeholder_text = "Architectural intent, family, space, material or connection"
	reference_query.text = "industrial hangar open central space supports service galleries"
	reference_query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(reference_query)
	_button(row,"Retrieve design cards",retrieve)
	reference_text.editable = false
	reference_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	reference_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(reference_text)
	_label(body,"References guide intent. A card or Gold recommendation never proves native admission or physical acceptance.")

func _note(value: String) -> void:
	status.text = value
	status.tooltip_text = value

func _result(answer: Dictionary) -> bool:
	_note(str(answer.get("reason","Done." if answer.get("ok",false) else "Request refused.")))
	return answer.get("ok",false)

func _region() -> Rect2i:
	return Rect2i(int(area_fields[0].value),int(area_fields[1].value),int(area_fields[2].value),int(area_fields[3].value))

func _tags() -> Array:
	var values: Array = []
	for tag: String in module_tags.text.split(",",false):
		if not tag.strip_edges().is_empty(): values.append(tag.strip_edges())
	return values

func _metadata() -> Dictionary:
	var id := module_name.text.to_lower().strip_edges().replace(" ","-")
	var pattern := RegEx.create_from_string("[^a-z0-9_-]")
	id = pattern.sub(id,"",true).left(40)
	if id.is_empty(): id="native-part"
	id += "-"+str(Time.get_ticks_usec())
	return {"id":id,"name":module_name.text.strip_edges(),"tags":_tags(),"part_type":Module.PART_TYPES[module_kind.selected],
		"allowed_transforms":Module.TRANSFORMS.duplicate() if allow_turns.button_pressed else ["identity"],
		"provenance":{"semantic_declarations":"User-selected type/tags and transformations; attachment/support meaning is not inferred."}}

func _refresh_modules() -> void:
	if not is_instance_valid(modules): return
	var previous := ""
	var selection := modules.get_selected_items()
	if not selection.is_empty() and selection[0]<module_ids.size(): previous=module_ids[selection[0]]
	var filters := {}
	if part_filter.selected>0: filters.part_type = Module.PART_TYPES[part_filter.selected-1]
	var found: Array = library.search(search.text,filters)
	modules.clear()
	module_ids.clear()
	_thumbnail_epoch += 1
	_thumbnail_queue.clear()
	for item: Dictionary in found:
		module_ids.append(item.id)
		var index := modules.add_item("%s · %d × %d\n%s · %s" % [item.name,item.extent[0],item.extent[1],item.part_type.replace("_"," "),"native observed" if item.get("native_readback_verified",false) else "stored geometry"])
		modules.set_item_tooltip(index,"%s\n%s\nThumbnail: sampled material identities. Select for exact geometry and authored connection guides." % [item.id,", ".join(item.tags)])
		var key: String = item.get("geometry_sha256",item.get("content_sha256",""))
		if _thumbnail_cache.has(key): modules.set_item_icon(index,_thumbnail_cache[key])
		else: _thumbnail_queue.append({"index":index,"id":item.id,"key":key,"epoch":_thumbnail_epoch})
	set_process(not _thumbnail_queue.is_empty())
	if not found.is_empty():
		var chosen := maxi(0,module_ids.find(previous))
		modules.select(chosen); _select_module(chosen)
	else:
		inspect.text = "Harvest a completed native Batch tile or a World region. Imported modules require fresh native admission."
		module_summary.text = inspect.text
		_selected_content=""
		module_view.set_result(null,Vector2i.ZERO,PackedByteArray(),"No selected native module")
		module_view.set_semantics({})

func _schedule_search() -> void:
	_search_timer.start()

func _process(_delta: float) -> void:
	_next_thumbnail()

func _next_thumbnail() -> void:
	if _thumbnail_queue.is_empty() or not is_inside_tree(): set_process(false); return
	var task: Dictionary = _thumbnail_queue.pop_front()
	if int(task.epoch)==_thumbnail_epoch:
		var value := library.get_module(task.id)
		if not value.is_empty():
			var extent := Vector2i(int(value.extent[0]),int(value.extent[1]))
			var cells := Marshalls.base64_to_raw(value.geometry.cells_base64)
			if cells.size()==extent.x*extent.y*2:
				var ratio := minf(80.0/extent.x,56.0/extent.y)
				var size := Vector2i(maxi(1,roundi(extent.x*ratio)),maxi(1,roundi(extent.y*ratio)))
				var sample := PackedByteArray()
				sample.resize(size.x*size.y*2)
				# At most 4,480 samples per frame, independent of module area.
				for y: int in size.y:
					for x: int in size.x:
						var sx := mini(extent.x-1,floori(float(x)*extent.x/size.x))
						var sy := mini(extent.y-1,floori(float(y)*extent.y/size.y))
						sample.encode_u16((y*size.x+x)*2,cells.decode_u16((sy*extent.x+sx)*2))
				var texture := ImageTexture.create_from_image(Controller.material_image(sample,size))
				if _thumbnail_cache.size()>=128: _thumbnail_cache.erase(_thumbnail_cache.keys()[0])
				_thumbnail_cache[task.key]=texture
				if task.index<modules.item_count and module_ids[task.index]==task.id: modules.set_item_icon(task.index,texture)
	if _thumbnail_queue.is_empty(): set_process(false)

func _material_name(identity: int) -> String:
	var index := Setup.MATERIALS.find(identity)
	return "%s (%d)" % [Setup.MATERIAL_NAMES[index],identity] if index>=0 else "Material %d" % identity

func _build_palette(module: Dictionary) -> void:
	for child: Node in palette_controls.get_children(): child.queue_free()
	palette_choices.clear()
	palette.text="{}"
	for role: Dictionary in module.roles:
		var group := VBoxContainer.new()
		palette_controls.add_child(group)
		_label(group,role.name)
		var choice := OptionButton.new()
		choice.add_item("Keep original")
		choice.set_item_metadata(0,-1)
		for identity: int in role.compatible_materials:
			choice.add_item(_material_name(identity))
			choice.set_item_metadata(choice.item_count-1,identity)
			choice.set_item_disabled(choice.item_count-1,identity not in Setup.MATERIALS)
		choice.item_selected.connect(func(_index: int) -> void: _palette_changed())
		group.add_child(choice)
		palette_choices[role.name]=choice
	if module.roles.is_empty(): _label(palette_controls,"No authored material roles. Define roles in Edit module semantics to enable substitution.")

func _palette_changed() -> void:
	var value := {}
	for role: String in palette_choices:
		var choice: OptionButton=palette_choices[role]
		if choice.selected>0: value[role]=int(choice.get_item_metadata(choice.selected))
	palette.text=JSON.stringify(value)

func edit_semantics() -> void:
	var value := _selected_module()
	if value.is_empty(): _note("Select a module to edit its authored declarations."); return
	module_semantics.open_module(value)

func _selected_module() -> Dictionary:
	var selected_items := modules.get_selected_items()
	if selected_items.is_empty() or selected_items[0]>=module_ids.size(): return {}
	return library.get_module(module_ids[selected_items[0]])

func _select_module(index: int) -> void:
	if index<0 or index>=module_ids.size(): return
	var value := library.get_module(module_ids[index])
	var checked := Module.validate(value)
	if not checked.ok: _result(checked); return
	if _selected_content!=value.content_sha256:
		module_view.set_result(ImageTexture.create_from_image(Controller.material_image(checked.cells,checked.extent)),checked.extent,checked.cells,"Exact stored native material identities · authored guides are separate")
		module_view.set_semantics(value)
		module_view.fit()
		_build_palette(value)
		source_connector.clear()
		for connector: Dictionary in value.attachments:
			source_connector.add_item("%s · %s · %s" % [connector.id,connector.kind,", ".join(connector.compatibility)])
			source_connector.set_item_metadata(source_connector.item_count-1,connector.id)
		if source_connector.item_count==0: source_connector.add_item("No authored or inferred connectors"); source_connector.set_item_metadata(0,"")
		source_connector.disabled=value.attachments.is_empty()
		_selected_content=value.content_sha256
	var summary := Module.summary(value)
	for item: Dictionary in library.summaries():
		if item.id==value.id: summary=item; break
	# This compatibility value is deliberately bounded; no provenance or geometry
	# documents are sent to a TextEdit during ordinary selection/receipt updates.
	inspect.text = JSON.stringify({"id":value.id,"name":value.name,"extent":value.extent,
		"native_readback_verified":summary.get("native_readback_verified",false),"content_sha256":value.content_sha256})
	var source_status:="Stored geometry and historical provenance. This manifest has no current-session native replay."
	if value.provenance.get("kind","")=="unexecuted-typed-recipe-projection": source_status="UNEXECUTED TEMPLATE · code-projected material geometry. No native harvest or completed placement is claimed."
	if summary.get("native_readback_verified",false): source_status="Current-session exact native observation / replay. Physical owner acceptance is separate."
	module_summary.text = "%s · %d × %d cells · %d connector(s) · %d clearance(s)\n%s\nContent %s · geometry %s" % [value.name,value.extent[0],value.extent[1],value.attachments.size(),value.clearances.size(),source_status,str(value.content_sha256).left(12),str(value.geometry.sha256).left(12)]
	keep.editable=not value.variation_regions.is_empty()
	keep.tooltip_text="Only explicitly authored variable geometry may be thinned; fixed geometry and connector faces are preserved." if keep.editable else "This part declares no variable geometry. Its exact cells are retained."
	if not keep.editable: keep.value=1.0
	module_name.text = value.name
	module_tags.text = ", ".join(value.tags)
	module_kind.select(Module.PART_TYPES.find(value.part_type))
	for i: int in transform.item_count: transform.set_item_disabled(i,Module.TRANSFORMS[i] not in value.allowed_transforms)
	transform.select(Module.TRANSFORMS.find(value.allowed_transforms[0]))

func harvest_region() -> void:
	if session.busy() or _harvesting: _note("Wait for the current architecture action."); return
	_harvesting = true
	var epoch := _epoch
	var metadata := _metadata()
	var captured: Dictionary = await wb.capture_batch_source(_region())
	_harvesting = false
	if epoch!=_epoch: _note("Harvest cancelled; no module was added."); return
	if not _result(captured): return
	var harvested: Dictionary = library.harvest_capture(captured,metadata)
	if _result(harvested):
		_refresh_modules()
		var saved: Dictionary = library.save()
		if saved.ok: _note("Native region harvested and saved with exact material geometry. Name/tags are authored declarations; attachments remain undeclared.")
		else: _note("Native module is available in this session, but saving failed: "+str(saved.get("reason","unknown write failure")))

func harvest_tile(tile: Dictionary) -> Dictionary:
	if session.busy() or _harvesting: return {"ok":false,"reason":"Wait for the current architecture action."}
	var answer: Dictionary = library.harvest_tile(tile,_metadata())
	if _result(answer):
		_refresh_modules()
		var saved: Dictionary = library.save()
		if not saved.ok: return {"ok":false,"reason":"Module harvested into this session, but persistence failed: "+str(saved.get("reason","unknown write failure"))}
		tabs.current_tab = 0
	return answer

func harvest_selected_tile() -> void:
	if not is_instance_valid(wb.batch_lab): _note("Open Batch Lab and select a completed native tile first."); return
	var panel: Window = wb.batch_lab
	if panel.blind: _note("Leave blinded comparison before harvesting a named module."); return
	harvest_tile(panel.controller.tiles[panel.selected])

func annotate_module() -> void:
	var module := _selected_module()
	if module.is_empty(): _note("Select a module first."); return
	if _result(library.annotate(module.id,module_name.text.strip_edges(),_tags())):
		_refresh_modules()
		_result(library.save())

func save_modules() -> void:
	_result(library.save())

func add_curated_templates() -> void:
	if session.busy() or _harvesting or _building_starters: _note("Wait for the current architecture action."); return
	var epoch:=_epoch
	_note("Preparing forty bounded source templates. This action performs no native construction.")
	await get_tree().process_frame
	var projected: Dictionary=Catalogue.template_library()
	if not _result(projected): return
	var added:=0; var existing:=0
	for module: Dictionary in projected.library.all():
		if epoch!=_epoch: break
		if not library.get_module(module.id).is_empty(): existing+=1; continue
		if library.add(module).ok: added+=1
		await get_tree().process_frame
	_refresh_modules()
	var saved: Dictionary=library.save()
	_note("%d curated source templates added; %d existing module identities preserved. Templates are unexecuted until exact native replay. %s" % [added,existing,"Saved." if saved.ok else "Save failed: "+str(saved.get("reason","unknown write failure"))])

func build_starter_parts() -> void:
	if session.busy() or _harvesting or _building_starters: _note("Wait for the current architecture action."); return
	_building_starters = true
	var epoch := _epoch
	var recipes: Array = preload("res://scripts/batch_lab/native_module_examples.gd").recipes()
	_starter_controller = Controller.new()
	add_child(_starter_controller)
	_starter_controller.configure_grid(4,2)
	for i: int in recipes.size():
		var config: Dictionary = Controller.defaults()
		config.extent = recipes[i].extent.duplicate()
		config.source_region = [0,0,64,64]
		config.materials = [0,7,28,58]
		config.operations = recipes[i].operations.duplicate(true)
		if not _starter_controller.configure_tile(i,config).ok:
			_starter_controller.queue_free(); _starter_controller=null; _building_starters=false
			_note("A starter recipe failed validation; the existing library is retained.")
			return
	_starter_controller.start()
	_note("Building eight starter parts in independent native Worlds. Stop remains available under Construction.")
	var deadline := Time.get_ticks_msec()+180000
	while _starter_controller.is_running() and Time.get_ticks_msec()<deadline:
		if epoch!=_epoch: _starter_controller.stop()
		await get_tree().process_frame
	if _starter_controller.is_running():
		_starter_controller.stop()
		while _starter_controller.is_running(): await get_tree().process_frame
	var added := 0
	var refused := 0
	var existing := 0
	if epoch==_epoch:
		for i: int in recipes.size():
			if not library.get_module(recipes[i].metadata.id).is_empty(): existing+=1; continue
			var answer: Dictionary = library.harvest_tile(_starter_controller.tiles[i],recipes[i].metadata,Module.rect(recipes[i].harvest_region))
			if answer.ok: added += 1
			else: refused += 1
	_starter_controller.queue_free()
	_starter_controller=null
	_building_starters=false
	_refresh_modules()
	var save_reason := ""
	if added>0:
		var saved: Dictionary = library.save()
		if not saved.ok: save_reason=" Saving failed; modules remain in this session only: "+str(saved.get("reason","unknown write failure"))
	_note("Starter native construction: %d parts harvested; %d already present; %d refused. Cancelled work is not added.%s" % [added,existing,refused,save_reason])

func stop_all() -> void:
	_epoch += 1
	if is_instance_valid(art_proposal_mount): art_proposal_mount.cancel("Architecture owner stopped the proposal request")
	_actions().cancel()
	if is_instance_valid(detail_panel): detail_panel.discard()
	_snap_candidates.clear(); _snap_request.clear(); snap_list.clear()
	if is_instance_valid(_starter_controller): _starter_controller.stop()

func propose_placement() -> void:
	if session.busy() or _harvesting: _note("Wait for the current architecture action."); return
	var module := _selected_module()
	if module.is_empty(): _note("Select a native module first."); return
	var palette_value: Variant = JSON.parse_string(palette.text)
	if not palette_value is Dictionary: _note("Palette substitutions use a role-to-material object."); return
	var region := _region()
	var selected_transform: String = Module.TRANSFORMS[transform.selected]
	var size: Vector2i = Module.transformed_size(Vector2i(int(module.extent[0]),int(module.extent[1])),selected_transform)
	var stage := Compiler.stage_defaults("place-"+module.id,region)
	stage.intent = "Place reusable native "+module.name+" with explicit transformation and palette."
	for row: int in int(rows.value):
		for column: int in int(columns.value):
			stage.modules.append({"module_id":module.id,"module_sha256":module.content_sha256,"placement":{
				"origin":[int(origin_fields[0].value)+column*(size.x+int(gap.value)),int(origin_fields[1].value)+row*(size.y+int(gap.value))],
				"transform":selected_transform,"palette":palette_value.duplicate(),"variation":{"seed":int(seed.value)+row*int(columns.value)+column,"keep_fraction":keep.value}}})
	var proposal := {"format":Compiler.FORMAT,"id":"module-placement-"+str(Time.get_ticks_usec()),"intent":stage.intent,"stages":[stage]}
	if _result(_actions().load_plan(proposal)):
		_last_stage = ""
		tabs.current_tab = 1
		_refresh_session()

func load_example() -> void:
	if session==null or example.item_count==0: return
	var selected_family := example.get_item_text(example.selected)
	var candidate: Dictionary = ModuleCompositions.plan(selected_family,library) if selected_family in ModuleCompositions.families() else Examples.plan(selected_family)
	if candidate.is_empty():
		_note("This modular example needs the eight starter part identities. Build 8 starter parts in Modules, or import their native library, then load the example again.")
		return
	if _result(_actions().load_plan(candidate)):
		_last_stage = ""
		_refresh_session()

func load_flagship() -> void:
	if not is_instance_valid(workflow) or session.busy(): _note("Wait for the current architecture action and its host workflow."); return
	if flagship.selected<0: return
	var family: String=flagship.get_item_metadata(flagship.selected)
	var required: Vector2i=Flagships.extent(family)
	if wb==null or not wb.get("applied") is Dictionary or wb.applied.is_empty(): _note("Open an installed World before choosing a flagship."); return
	var actual:=Setup.extent_of(wb.applied)
	if actual.x<required.x or actual.y<required.y:
		_note("This flagship requires at least %d × %d cells; the current World is %d × %d. Save your start, then use ordinary New to choose that size. No World was changed." % [required.x,required.y,actual.x,actual.y]); return
	var built: Dictionary=Flagships.build(family,library,int(seed.value))
	if not _result(built): return
	if _result(workflow.load_campaign(built.campaign)):
		_last_stage=""; _refresh_session(); workflow_panel.refresh(); tabs.current_tab=3
		_note("Flagship task hierarchy loaded. Review each bounded stage and its actual native source before approving construction.")

func load_delegated_workshop() -> void:
	if _harvesting or not is_instance_valid(workflow): _note("Wait for the installed authoring host."); return
	if wb==null or not wb.get("applied") is Dictionary or wb.applied.is_empty(): _note("Open an installed World before loading the workshop."); return
	var actual: Vector2i=Setup.extent_of(wb.applied)
	if actual.x<512 or actual.y<512: _note("The delegated workshop needs a World of at least 512 × 512. Save your start and use ordinary New first. No World was changed."); return
	var built: Dictionary=HierarchyDemo.build(library)
	if not built.get("ok",false): _note(str(built.get("reason","Missing curated parts."))+" Use Add curated templates or import the matching qualified catalogue first."); return
	if _result(workflow.load_campaign(built.campaign)):
		_last_stage=""; _refresh_session(); workflow_panel.refresh(); tabs.current_tab=3
		_note("Delegated workshop proposal loaded. Review the task tree, prepare each ready local job, then preview and approve each stage explicitly.")

func revise_workshop_gallery() -> void:
	if _harvesting or not is_instance_valid(workflow): return
	var answer: Dictionary=workflow.revise_workshop_gallery()
	if answer.get("ok",false): _last_stage=""
	_refresh_session(); _result(answer)
	if answer.get("ok",false): _note("Clear access gallery proposed. Inspect its new zero-write preview, then approve this revision explicitly.")

func recover_workshop() -> void:
	if _harvesting or not is_instance_valid(workflow): return
	var answer: Dictionary=await workflow.propose_workshop_recovery()
	if answer.get("ok",false): _last_stage=""
	_refresh_session(); _result(answer)
	if answer.get("ok",false): workflow_panel.refresh(); tabs.current_tab=3; _note("Fresh recovery proposed from the exact stopped native result. Earlier history remains retained. Preview and approve each recovery stage explicitly.")

func prepare_local_job() -> void:
	if _harvesting: _note("Wait for native harvest."); return
	if not is_instance_valid(workflow): _note("The host workflow is unavailable."); return
	var answer: Dictionary=await workflow.prepare_selected_job()
	if answer.get("ok",false): _last_stage=""
	_refresh_session()
	if answer.get("ok",false):
		_note("Local job prepared from the actual inspected World. No native work was queued. Inspect + zero-write preview, then approve this stage to construct.")
	else: _note(str(answer.get("reason","Local preparation refused.")))

func preview_stage() -> void:
	if _harvesting: _note("Wait for native harvest."); return
	var answer: Dictionary = await _actions().preview_selected()
	if answer.get("ok",false):
		var preview: Dictionary = answer.preview
		var region: Rect2i = Compiler.rect(preview.region)
		preview_view.set_result(ImageTexture.create_from_image(Controller.material_image(preview.projected_cells,region.size)),region.size,
			preview.projected_cells,"Zero-write projection; not applied native geometry")
		preview_view.fit()
		preview_label.text = "ZERO-WRITE PREVIEW · %d native cell checks · %d distinct cells · %d changes\nProjection only. Approve to construct; physics is not simulated here." % [preview.budget.checked_cells,preview.budget.unique_cells,preview.budget.changed_cells]
		result_tabs.current_tab=1
		_refresh_result_views(true)
	_refresh_session()

func approve_stage() -> void:
	if _harvesting: _note("Wait for native harvest."); return
	await _actions().approve()
	_refresh_session()

func revise_stage() -> void:
	var value: Variant
	if stage_advanced.button_pressed:
		var parsed: Dictionary = stage_editor.parsed()
		if not _result(parsed): return
		value=parsed.value
	else:
		value=session.stage().duplicate(true)
		if value.is_empty(): _note("Select a stage to revise."); return
		if stage_intent.text.length()>4096: _note("Stage intent must fit 4,096 characters."); return
		value.intent=stage_intent.text.strip_edges()
		value.region=[]
		for field: SpinBox in stage_region: value.region.append(int(field.value))
	if _result(_actions().revise(value)): _last_stage=""; _refresh_session()

func _schedule_session_refresh() -> void:
	if _refresh_scheduled: return
	_refresh_scheduled=true
	call_deferred("_refresh_session")

func _refresh_session() -> void:
	_refresh_scheduled=false
	if session==null or stage_list==null: return
	var summary: Dictionary = session.summary()
	var coordinated: Dictionary=workflow.summary() if is_instance_valid(workflow) else {}
	if is_instance_valid(prepare_local_button): prepare_local_button.disabled=not coordinated.get("can_prepare_local_job",false)
	var selected_state: Dictionary=summary.stages[summary.selected] if summary.get("selected",-1)>=0 and summary.selected<summary.stages.size() else {}
	var workshop_current: bool=coordinated.get("campaign",{}).get("campaign_id","")=="delegated-workshop" and not session.busy()
	if is_instance_valid(workshop_revision_button): workshop_revision_button.disabled=not (workshop_current and selected_state.get("id")=="access-gallery" and selected_state.get("state")!="completed")
	if is_instance_valid(workshop_recovery_button): workshop_recovery_button.disabled=not (workshop_current and selected_state.get("id")=="cladding-trial" and selected_state.get("state")=="partial")
	_note(str(summary.message))
	stage_list.clear()
	if not summary.stages.is_empty():
		for item: Dictionary in summary.stages: stage_list.add_item(str(item.title)+" · "+str(item.state))
		stage_list.select(summary.selected)
		var selected: Dictionary = summary.stages[summary.selected]
		var identity := "%d/%s" % [int(summary.revision),str(selected.id)]
		if identity!=_last_stage:
			var value: Dictionary=session.stage()
			stage_intent.text=str(value.get("intent",""))
			for i: int in 4: stage_region[i].value=value.region[i]
			stage_parts.clear()
			for placement: Dictionary in value.get("modules",[]):
				stage_parts.add_item("%s · %s at %s" % [placement.module_id,placement.placement.get("transform","identity"),str(placement.placement.get("origin",[]))])
			if selected.module_count==0: stage_parts.add_item("%d typed native operation(s)" % int(selected.operation_count))
			if stage_advanced.button_pressed: stage_editor.text=JSON.stringify(value,"  ")
			_last_stage = identity
		var budget: Dictionary=selected.host_budget
		stage_brief.text="%d module(s) · %d typed operation(s)\nDependencies: %s\n%s" % [selected.module_count,selected.operation_count,
			"none" if selected.depends_on.is_empty() else ", ".join(selected.depends_on),
			"Blocked by: "+", ".join(selected.blocked_by) if not selected.blocked_by.is_empty() else "Dependencies currently satisfied."]
		if not budget.is_empty(): stage_brief.text+="\nHost compilation: %d native checks · %d changed cells · %d scan bound" % [budget.get("checked_cells",0),budget.get("changed_cells",0),budget.get("conservative_scan_bound",0)]
		else: stage_brief.text+="\nNo current host budget. Inspect + preview computes actual footprint and cost."
		if coordinated.get("prepared_local_job",false): stage_brief.text+="\nLOCAL JOB PREPARED · source-bound proposal only; preview and approval are still required."
		elif coordinated.get("can_prepare_local_job",false): stage_brief.text+="\nReady delegated task. Prepare local job before previewing its actual proposed geometry."
		var result: Dictionary=selected.native_result
		evidence_text.text="Selected stage: %s · %s\n" % [selected.id,selected.state]
		if not str(result.get("result_sha256","")).is_empty():
			evidence_text.text+="Retained native %s · %d checked · %d changed\nResult %s\n%s" % [result.status,result.checked_cells,result.changed_cells,str(result.result_sha256).left(20),
				"Matches this stage recipe; later World edits may differ." if result.same_stage else "Historical recipe identity differs from the current proposal."]
		else: evidence_text.text+="No retained exact native result for this stage. Proposed and queued work is not completed construction."
		var view_state := "%s/%s/%s" % [identity,selected.preview_sha256,result.get("result_sha256","")]
		if view_state!=_last_view_state:
			_refresh_result_views()
			_last_view_state=view_state
	if not summary.has_current_preview:
		preview_label.text = "NO CURRENT APPROVAL PREVIEW · any visible projection is retained history. Inspect + preview again before approval; it is not the live World."

func _refresh_result_views(force := false) -> void:
	var inspected: Dictionary=session.inspection_view()
	if inspected.get("ok",false):
		var source_key := "%s/%s" % [inspected.source_sha256,str(inspected.region)]
		if force or source_key!=_last_source:
			var region:=Compiler.rect(inspected.region)
			source_view.set_result(ImageTexture.create_from_image(Controller.material_image(inspected.cells,region.size)),region.size,inspected.cells,"Actual inspected native snapshot; not a live feed")
			source_view.fit()
			_last_source=source_key
		source_label.text="%s · region %s · generation %d\nNative source %s. Captured material snapshot; physics and later edits may differ." % ["STALE INSPECTION" if inspected.stale else "INSPECTED NATIVE SOURCE",str(inspected.region),int(inspected.generation),str(inspected.source_sha256).left(16)]
	else: source_label.text=str(inspected.get("reason","No inspected native source."))
	var retained: Dictionary=session.native_result_view()
	if retained.get("ok",false):
		var result_key := "%s/%s" % [retained.stage_id,retained.source_sha256]
		if result_key!=_last_native:
			var region:=Compiler.rect(retained.region)
			native_view.set_result(ImageTexture.create_from_image(Controller.material_image(retained.cells,region.size)),region.size,retained.cells,"Verified native material result retained at stage retirement")
			native_view.fit()
			_last_native=result_key
			if session.stage_state() in ["completed","partial","cancelled"]: result_tabs.current_tab=2
		native_label.text="RETAINED NATIVE %s · %d checked · %d changed\nExact result %s. Recorded at stage retirement; later World state may differ." % [str(retained.status).to_upper(),int(retained.checked_cells),int(retained.changed_cells),str(retained.source_sha256).left(16)]
	else:
		native_label.text=str(retained.get("reason","No retained native result for this stage."))
		if not _last_native.is_empty(): native_view.set_result(null,Vector2i.ONE,PackedByteArray(),"No native result for selected stage"); _last_native=""

func retrieve() -> void:
	var script: Script = load("res://scripts/batch_lab/architectural_retrieval.gd")
	if script==null: _note("Architectural design-card retrieval is unavailable in this source."); return
	var result: Dictionary = script.retrieve({"text":reference_query.text,"limit":4},library.summaries())
	if not _result(result): return
	reference_text.text = str(result.get("context_text",JSON.stringify(result.get("context_pack",{}),"  ")))
	_note("Retrieved a bounded context pack. Native compatibility and owner acceptance remain separate from design guidance.")

func _history(redo: bool) -> void:
	if session.busy() or _harvesting: _note("Stop and wait for native acknowledgement before history changes."); return
	if wb.paint_editor==null: _note("Ordinary Workbench history is unavailable."); return
	var accepted: bool = wb.paint_editor.redo() if redo else wb.paint_editor.undo()
	if accepted:
		session.preview.clear()
		# A previous stage receipt remains historical evidence, while dependencies
		# must be re-established after the owner edits its authored geometry.
		for identity: String in session.states:
			if session.states[identity]=="completed": session.states[identity]="proposed"
		_note("Ordinary native history requested. Stage dependencies now require fresh inspection and approval.")
	else: _note(wb.message)

func _choose_file(action: String) -> void:
	if session.busy() or _harvesting: _note("Wait for the current architecture action."); return
	_action = action
	_file.file_mode = FileDialog.FILE_MODE_SAVE_FILE if action in ["save_session","export_module","save_decisions"] else FileDialog.FILE_MODE_OPEN_FILE
	_file.title = action.replace("_"," ").capitalize()
	_file.popup_centered_ratio(0.8)

func _file_selected(path: String) -> void:
	match _action:
		"save_session": _result(session.save_session(path))
		"open_session":
			var opened: Dictionary=workflow.open_session(path) if is_instance_valid(workflow) and workflow.has_method("open_session") else session.open_session(path)
			if _result(opened):
				if is_instance_valid(workflow) and not workflow.has_method("open_session"): workflow.load_plan(session.plan)
				_last_stage=""; _refresh_session()
		"save_decisions":
			if not is_instance_valid(workflow): _note("Planning adapter is unavailable."); return
			_result(Library._atomic_write(path,workflow.export_history(),64*1024*1024))
		"open_decisions":
			if not is_instance_valid(workflow): _note("Planning adapter is unavailable."); return
			var loaded:=Library._read_json(path,64*1024*1024)
			if _result(loaded) and _result(workflow.open_history(loaded.value)): _last_stage=""; _refresh_session(); tabs.current_tab=3
		"import_module":
			if _result(library.import_module(path)): _refresh_modules(); _result(library.save())
		"import_library":
			if _result(library.load_library(path)): _selected_content=""; _refresh_modules(); _result(library.save())
		"export_module":
			var module := _selected_module()
			if module.is_empty(): _note("Select a module first.")
			else: _result(library.export_module(module.id,path))
		"import_plan":
			var file := FileAccess.open(path,FileAccess.READ)
			if file==null or file.get_length()>Compiler.MAX_INPUT_BYTES: _note("Plan is unavailable or exceeds 2 MiB."); return
			var value: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if _result(_actions().load_plan(value)): _last_stage=""; _refresh_session(); tabs.current_tab=1

func _close() -> void:
	stop_all()
	hide()
