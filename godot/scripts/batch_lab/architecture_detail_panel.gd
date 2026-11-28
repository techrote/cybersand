extends VBoxContainer
## Friendly typed controls over bounded code-owned jobs. One supplied Session
## owns source capture and one supplied Workflow owns stage admission.
signal review_requested
const Jobs=preload("res://scripts/batch_lab/native_detail_jobs.gd")
const Module=preload("res://scripts/batch_lab/native_module.gd")
const Setup=preload("res://scripts/workbench_setup.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
var session: Node
var workflow: Node
var kind:=OptionButton.new()
var material_choice:=OptionButton.new()
var instance:=OptionButton.new()
var description:=Label.new()
var source_label:=Label.new()
var result_label:=Label.new()
var inspection_fields: Array[SpinBox]=[]
var area_fields: Array[SpinBox]=[]
var seed: SpinBox
var budget: SpinBox
var controls:=HFlowContainer.new()
var fields: Dictionary={}
var path_fields: Array=[]
var _path_rows: VBoxContainer
var _descriptions: Array=[]
var _context: Dictionary={}
var _job: Dictionary={}
var _prepared_inputs: PackedByteArray
var _busy:=false
var _epoch:=0

func _ready() -> void:
	_label(self,"Bounded detail jobs · dimensions, irregularity, clutter and declared noncritical wear")
	_descriptions=Jobs.describe_jobs()
	for item: Dictionary in _descriptions:
		kind.add_item(item.name); kind.set_item_metadata(kind.item_count-1,item.kind)
	kind.item_selected.connect(func(_index: int) -> void: _build_fields())
	add_child(kind)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(description)
	var inspection:=HFlowContainer.new(); add_child(inspection)
	for spec: Array in [["Inspect X",0,2047,16],["Y",0,2047,16],["Width",1,512,128],["Height",1,512,128]]:
		inspection_fields.append(_spin(inspection,spec[0],spec[1],spec[2],spec[3]))
	var area:=HFlowContainer.new(); add_child(area)
	for spec: Array in [["Detail X",0,2047,32],["Y",0,2047,32],["Width",1,128,64],["Height",1,128,64]]:
		area_fields.append(_spin(area,spec[0],spec[1],spec[2],spec[3]))
	var scope:=HFlowContainer.new(); add_child(scope)
	_button(scope,"Inspect actual source + scopes",inspect_source)
	instance.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scope.add_child(instance)
	instance.add_item("No specific placed instance"); instance.set_item_metadata(0,"")
	source_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(source_label)
	var common:=HFlowContainer.new(); add_child(common)
	seed=_spin(common,"Seed",0,2147483647,37901)
	budget=_spin(common,"Maximum changed cells",1,Jobs.MAX_CELLS,4096)
	common.add_child(material_choice)
	add_child(controls)
	var actions:=HFlowContainer.new(); add_child(actions)
	_button(actions,"Prepare bounded detail proposal",prepare)
	_button(actions,"Review generated native stage",review)
	_button(actions,"Discard detail proposal",discard)
	result_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(result_label)
	_label(self,"Preparation writes no World cells and dispatches no model. Stage preview recaptures the exact source and requires explicit approval. Wear requires a current native instance with authored variable geometry; fixed regions and connector faces remain protected.")
	_build_fields()

func bind(session_value: Node,workflow_value: Node) -> void:
	session=session_value; workflow=workflow_value

func _label(parent: Node,text: String) -> Label:
	var label:=Label.new(); label.text=text; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label); return label

func _button(parent: Node,text: String,action: Callable) -> Button:
	var button:=Button.new(); button.text=text; button.pressed.connect(action); parent.add_child(button); return button

func _spin(parent: Node,label: String,low: float,high: float,value: float,step:=1.0) -> SpinBox:
	var column:=VBoxContainer.new(); parent.add_child(column); _label(column,label)
	var spin:=SpinBox.new(); spin.min_value=low; spin.max_value=high; spin.step=step; spin.value=value
	spin.custom_minimum_size.x=92; column.add_child(spin); return spin

func _build_fields() -> void:
	_epoch+=1; _job.clear(); _prepared_inputs=PackedByteArray()
	for child: Node in controls.get_children(): controls.remove_child(child); child.queue_free()
	fields.clear(); path_fields.clear()
	var item: Dictionary=_descriptions[kind.selected]
	description.text=str(item.intent)+"\n"+str(item.source_rule)+" · bounded code executor · native approval still required."
	material_choice.clear()
	var palette: Array=[0] if item.requires_variable_scope else [28,58,7,13]
	for identity: int in palette:
		material_choice.add_item(Setup.MATERIAL_NAMES[Setup.MATERIALS.find(identity)]); material_choice.set_item_metadata(material_choice.item_count-1,identity)
	for spec: Dictionary in item.controls:
		if spec.type=="choice":
			var column:=VBoxContainer.new(); controls.add_child(column); _label(column,str(spec.key).replace("_"," ").capitalize())
			var choice:=OptionButton.new(); column.add_child(choice)
			for option: String in spec.options: choice.add_item(option.capitalize()); choice.set_item_metadata(choice.item_count-1,option)
			choice.select(maxi(0,spec.options.find(spec.get("default","")))); fields[spec.key]=choice
		elif spec.type=="cell-path":
			_path_rows=VBoxContainer.new(); controls.add_child(_path_rows)
			_label(_path_rows,"Orthogonal route waypoints · 2–8 world-cell points")
			add_path_point(Vector2i(int(area_fields[0].value),int(area_fields[1].value)))
			add_path_point(Vector2i(int(area_fields[0].value)+int(area_fields[2].value)-1,int(area_fields[1].value)))
			var actions:=HFlowContainer.new(); _path_rows.add_child(actions)
			_button(actions,"Add waypoint",func() -> void: add_path_point(Vector2i(int(path_fields.back()[0].value),int(path_fields.back()[1].value))))
			_button(actions,"Remove last waypoint",remove_path_point)
		else:
			fields[spec.key]=_spin(controls,str(spec.key).replace("_"," ").capitalize(),spec.min,spec.max,spec.default,0.05 if spec.type=="number" else 1.0)
	result_label.text="No prepared detail proposal. Choose the region and bounded controls, then inspect actual native source."

func add_path_point(point: Vector2i) -> void:
	if path_fields.size()>=8: return
	var row:=HFlowContainer.new(); _path_rows.add_child(row)
	path_fields.append([_spin(row,"X",0,2047,point.x),_spin(row,"Y",0,2047,point.y),row])

func remove_path_point() -> void:
	if path_fields.size()<=2: return
	var row: Array=path_fields.pop_back(); row[2].queue_free()

func inspection_region() -> Rect2i:
	return Rect2i(int(inspection_fields[0].value),int(inspection_fields[1].value),int(inspection_fields[2].value),int(inspection_fields[3].value))

func params() -> Dictionary:
	var value:={"region":[int(area_fields[0].value),int(area_fields[1].value),int(area_fields[2].value),int(area_fields[3].value)],
		"material":int(material_choice.get_item_metadata(material_choice.selected)),"seed":int(seed.value),"max_cells":int(budget.value)}
	for spec: Dictionary in _descriptions[kind.selected].controls:
		if spec.type=="cell-path":
			value[spec.key]=[]
			for point: Array in path_fields: value[spec.key].append([int(point[0].value),int(point[1].value)])
		elif spec.type=="choice": value[spec.key]=fields[spec.key].get_item_metadata(fields[spec.key].selected)
		elif spec.type=="number": value[spec.key]=float(fields[spec.key].value)
		else: value[spec.key]=int(fields[spec.key].value)
	return Module.canonical(value)

func _input_bytes() -> PackedByteArray:
	return Module.json_bytes([kind.get_item_metadata(kind.selected),params(),Compiler.rect_array(inspection_region()),instance.get_item_metadata(instance.selected)])

func _material_permissions(allowed: Array) -> void:
	for index: int in material_choice.item_count:
		material_choice.set_item_disabled(index,int(material_choice.get_item_metadata(index)) not in allowed)

func _available() -> bool:
	if _busy: result_label.text="A native source inspection is already in progress."; return false
	if not is_instance_valid(session) or not session.has_method("detail_context") or not is_instance_valid(workflow):
		result_label.text="This source does not expose the host detail-context adapter."; return false
	if workflow.busy(): result_label.text="Wait for the current native stage before preparing a new detail proposal."; return false
	return true

func inspect_source() -> void:
	if not _available(): return
	_busy=true
	var epoch:=_epoch
	var answer: Dictionary=await session.detail_context(inspection_region(),"")
	_busy=false
	if epoch!=_epoch: return
	if not answer.get("ok",false): source_label.text=str(answer.get("reason","Native detail context refused.")); return
	_context=answer.context
	_material_permissions(_context.allowed_materials)
	var previous: String=str(instance.get_item_metadata(instance.selected))
	instance.clear(); instance.add_item("No specific placed instance"); instance.set_item_metadata(0,"")
	for item: Dictionary in answer.get("instances",[]):
		var identity: String=str(item.get("instance_id",item.get("module_instance","")))
		var current: bool=item.get("current_geometry_verified",false)
		var variable: bool=int(item.get("variable_region_count",0))>0
		instance.add_item(str(item.get("name",item.get("module_id",identity)))+" · "+identity+" · "+("verified variable scope" if current and variable else "no current wear scope"))
		instance.set_item_metadata(instance.item_count-1,identity)
		instance.set_item_disabled(instance.item_count-1,not current or not variable)
		instance.set_item_tooltip(instance.item_count-1,str(item.get("reason","")) if not current else "Exact placed geometry rechecked. Variable scope is authored; this is not a physical stability certificate." if variable else "This exact part declares no variable geometry for wear.")
		if identity==previous and current and variable: instance.select(instance.item_count-1)
	source_label.text="Actual native source %s · generation %d · %d retained native instance(s). Wear choices require verified authored variable scope. %s" % [str(_context.source_sha256).left(16),int(_context.generation),instance.item_count-1,answer.get("scope","")]

func prepare() -> void:
	if not _available(): return
	var identity: String=str(instance.get_item_metadata(instance.selected))
	if _descriptions[kind.selected].requires_variable_scope and identity.is_empty():
		result_label.text="Wear requires an explicitly selected current native instance with authored variable geometry. Inspect source scopes and choose that instance first."; return
	var inputs:=_input_bytes()
	var epoch:=_epoch
	_busy=true
	var answer: Dictionary=await session.detail_context(inspection_region(),identity if _descriptions[kind.selected].requires_variable_scope else "")
	_busy=false
	if epoch!=_epoch or inputs!=_input_bytes(): result_label.text="Detail controls changed during source inspection. Prepare the revised job."; return
	if not answer.get("ok",false): result_label.text=str(answer.get("reason","Native detail context refused.")); return
	_context=answer.context
	_material_permissions(_context.allowed_materials)
	var result: Dictionary=Jobs.compile_job(str(kind.get_item_metadata(kind.selected)),params(),_context)
	if not result.get("ok",false): _job.clear(); result_label.text=str(result.get("reason","No source-grounded detail fits.")); return
	_job=result; _prepared_inputs=inputs
	result_label.text="ZERO-WRITE DETAIL PROPOSAL · %d distinct cells · %d component(s) · %d inspected candidates\nExact footprint %s · source %s · parameters %s. Review the generated stage before native approval." % [result.budget.unique_cells,result.budget.components,result.budget.scan_cells,str(result.footprint),str(result.source_sha256).left(16),str(result.params_sha256).left(16)]

func review() -> void:
	if not _available(): return
	if _job.is_empty() or _input_bytes()!=_prepared_inputs: result_label.text="No current proposal for these controls. Prepare the detail job first."; return
	var current: Dictionary=session.inspection_view()
	if not current.get("ok",false) or current.get("stale",true) or current.source_sha256!=_job.source_sha256 or int(current.generation)!=int(_job.input_generation):
		result_label.text="The native source snapshot changed. Prepare this detail job again before review."; return
	var generated: Dictionary=Jobs.stage_from_job(_job,"detail-"+str(Time.get_ticks_usec()),str(_descriptions[kind.selected].intent))
	if not generated.get("ok",false): result_label.text=str(generated.get("reason","Worker proposal changed.")); return
	var answer: Dictionary=workflow.load_plan({"format":Compiler.FORMAT,"id":"detail-plan-"+str(Time.get_ticks_usec()),"intent":generated.stage.intent,"stages":[generated.stage]})
	result_label.text=str(answer.get("reason","Review the current native stage; approval is still required."))
	if answer.get("ok",false): review_requested.emit()

func discard() -> void:
	_epoch+=1; _job.clear(); _prepared_inputs=PackedByteArray()
	result_label.text="Detail proposal discarded. No native construction was requested."
