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
var wb: Node
var library := Library.new()
var session: Node
var status := Label.new()
var tabs := TabContainer.new()
var search := LineEdit.new()
var part_filter := OptionButton.new()
var modules := ItemList.new()
var module_ids: Array[String] = []
var module_view: Control
var inspect := TextEdit.new()
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
var area_fields: Array[SpinBox] = []
var origin_fields: Array[SpinBox] = []
var allow_turns := CheckBox.new()
var stage_list := ItemList.new()
var stage_editor := TextEdit.new()
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
	session.changed.connect(_refresh_session)
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
	_button(top,"Import module…",func() -> void: _choose_file("import_module"))
	_button(top,"Export module…",func() -> void: _choose_file("export_module"))
	_button(top,"Undo native edit",func() -> void: _history(false),"Uses the ordinary Workbench authoring history.")
	_button(top,"Redo native edit",func() -> void: _history(true))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 3
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(status)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	_build_modules()
	_build_stages()
	_build_references()
	_file.access = FileDialog.ACCESS_FILESYSTEM
	_file.filters = PackedStringArray(["*.json ; Architecture and module documents"])
	_file.file_selected.connect(_file_selected)
	add_child(_file)

func _build_modules() -> void:
	var body := _scroll_tab("Modules")
	var find := _row(body)
	search.placeholder_text = "Search names, tags and structural parts"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_text: String) -> void: _refresh_modules())
	find.add_child(search)
	part_filter.add_item("All parts")
	for part: String in Module.PART_TYPES: part_filter.add_item(part.replace("_"," "))
	part_filter.item_selected.connect(func(_index: int) -> void: _refresh_modules())
	find.add_child(part_filter)
	var split := HSplitContainer.new()
	split.custom_minimum_size.y = 270
	body.add_child(split)
	modules.custom_minimum_size.x = 250
	modules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modules.item_selected.connect(_select_module)
	split.add_child(modules)
	module_view = View.new()
	module_view.custom_minimum_size = Vector2(270,250)
	module_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(module_view)
	inspect.editable = false
	inspect.custom_minimum_size.y = 100
	body.add_child(inspect)
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
	_label(variant,"Compatible role palette")
	palette.text = "{}"
	palette.placeholder_text = "Example: {\"frame\":28}"
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variant.add_child(palette)
	seed = _spin(variant,"Seed",0,2147483647,37901)
	keep = _spin(variant,"Detail retained",0,1,1,0.05)
	_button(variant,"Propose placement",propose_placement,"Create a finite stage; inspect and approve its actual footprint before native construction.")

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
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 310
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	stage_list.custom_minimum_size.y = 120
	stage_list.item_selected.connect(func(index: int) -> void:
		var answer: Dictionary = session.select(index)
		if answer.ok: _last_stage = ""; _refresh_session())
	left.add_child(stage_list)
	_label(left,"Typed stage · edit intent, parts, boundaries or operations, then Revise")
	stage_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	left.add_child(stage_editor)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(preview_label)
	preview_view = View.new()
	preview_view.custom_minimum_size = Vector2(350,260)
	preview_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview_view)
	evidence_text.editable = false
	evidence_text.custom_minimum_size.y = 120
	right.add_child(evidence_text)
	var actions := HFlowContainer.new()
	body.add_child(actions)
	_button(actions,"Inspect + zero-write preview",preview_stage)
	_button(actions,"Approve stage",approve_stage)
	_button(actions,"Revise stage",revise_stage)
	_button(actions,"Skip stage",func() -> void: session.skip())
	_button(actions,"Stop / cancel",stop_all)
	_button(actions,"Next stage",func() -> void:
		if not session.plan.is_empty():
			if session.select(mini(session.selected+1,session.plan.stages.size()-1)).ok: _last_stage=""; _refresh_session())

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
	var filters := {}
	if part_filter.selected>0: filters.part_type = Module.PART_TYPES[part_filter.selected-1]
	var found: Array = library.search(search.text,filters)
	modules.clear()
	module_ids.clear()
	for item: Dictionary in found:
		module_ids.append(item.id)
		modules.add_item("%s · %d × %d\n%s" % [item.name,item.extent[0],item.extent[1],item.part_type.replace("_"," ")])
	if not found.is_empty(): modules.select(0); _select_module(0)
	else:
		inspect.text = "Harvest a completed native Batch tile or a World region. Imported modules require fresh native admission."
		module_view.set_result(null,Vector2i.ZERO,PackedByteArray(),"No selected native module")

func _selected_module() -> Dictionary:
	var selected_items := modules.get_selected_items()
	if selected_items.is_empty() or selected_items[0]>=module_ids.size(): return {}
	return library.get_module(module_ids[selected_items[0]])

func _select_module(index: int) -> void:
	if index<0 or index>=module_ids.size(): return
	var value := library.get_module(module_ids[index])
	var checked := Module.validate(value)
	if not checked.ok: _result(checked); return
	module_view.set_result(ImageTexture.create_from_image(Controller.material_image(checked.cells,checked.extent)),checked.extent,checked.cells,"Native material-ID geometry; static view")
	var summary := Module.summary(value)
	for item: Dictionary in library.summaries():
		if item.id==value.id: summary=item; break
	inspect.text = JSON.stringify(summary,"  ")
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
	session.cancel()
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
	if _result(session.load_plan(proposal)):
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
	if _result(session.load_plan(candidate)):
		_last_stage = ""
		_refresh_session()

func preview_stage() -> void:
	if _harvesting: _note("Wait for native harvest."); return
	var answer: Dictionary = await session.preview_selected()
	if answer.get("ok",false):
		var preview: Dictionary = answer.preview
		var region: Rect2i = Compiler.rect(preview.region)
		preview_view.set_result(ImageTexture.create_from_image(Controller.material_image(preview.projected_cells,region.size)),region.size,
			preview.projected_cells,"Zero-write projection; not applied native geometry")
		preview_label.text = "ZERO-WRITE PREVIEW · %d native cell checks · %d distinct cells · %d changes\nProjection only. Approve to construct; physics is not simulated here." % [preview.budget.checked_cells,preview.budget.unique_cells,preview.budget.changed_cells]
	_refresh_session()

func approve_stage() -> void:
	if _harvesting: _note("Wait for native harvest."); return
	await session.approve()
	_refresh_session()

func revise_stage() -> void:
	var value: Variant = JSON.parse_string(stage_editor.text)
	if _result(session.revise(value)): _last_stage=""; _refresh_session()

func _refresh_session() -> void:
	if session==null or stage_list==null: return
	_note(session.message)
	stage_list.clear()
	if not session.plan.is_empty():
		for item: Dictionary in session.plan.stages: stage_list.add_item(item.id+" · "+str(session.states.get(item.id,"proposed")))
		stage_list.select(session.selected)
		var identity: String = str(session.stage().get("id",""))+"/"+Compiler.digest(Compiler.canonical(session.stage()).to_utf8_buffer())
		if identity!=_last_stage:
			stage_editor.text = JSON.stringify(session.stage(),"  ")
			_last_stage = identity
	if session.preview.is_empty(): preview_label.text = "No current approval preview. Inspect + preview reads the native World and computes exact permissions and cost."
	if not session.records.is_empty():
		var evidence: Dictionary = session.records.back().duplicate(true)
		evidence.erase("result_materials_base64")
		if evidence.has("native_receipts"):
			for receipt: Dictionary in evidence.native_receipts: receipt.erase("readback")
		evidence_text.text = JSON.stringify(evidence,"  ")

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
	_file.file_mode = FileDialog.FILE_MODE_SAVE_FILE if action in ["save_session","export_module"] else FileDialog.FILE_MODE_OPEN_FILE
	_file.title = action.replace("_"," ").capitalize()
	_file.popup_centered_ratio(0.8)

func _file_selected(path: String) -> void:
	match _action:
		"save_session": _result(session.save_session(path))
		"open_session":
			if _result(session.open_session(path)): _last_stage=""; _refresh_session()
		"import_module":
			if _result(library.import_module(path)): _refresh_modules(); _result(library.save())
		"export_module":
			var module := _selected_module()
			if module.is_empty(): _note("Select a module first.")
			else: _result(library.export_module(module.id,path))
		"import_plan":
			var file := FileAccess.open(path,FileAccess.READ)
			if file==null or file.get_length()>Compiler.MAX_INPUT_BYTES: _note("Plan is unavailable or exceeds 2 MiB."); return
			var value: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if _result(session.load_plan(value)): _last_stage=""; _refresh_session(); tabs.current_tab=1

func _close() -> void:
	stop_all()
	hide()
