extends VBoxContainer
## Human intent and bounded task overview over one host-owned workflow facade.
## This component never owns a provider, native executor or second session.
signal review_stage(index: int)
signal save_history_requested
signal open_history_requested
signal art_configuration_requested
signal art_proposal_requested
const Recipes=preload("res://scripts/batch_lab/architecture_intent_recipes.gd")
var workflow: Node
var intent := TextEdit.new()
var seed: SpinBox
var family := OptionButton.new()
var region_fields: Array[SpinBox] = []
var options := ItemList.new()
var options_info := Label.new()
var tasks := Tree.new()
var task_detail := Label.new()
var status := Label.new()
var totals := Label.new()
var _option_ids: Array[String] = []
var _stage_indexes := {}
var _summary := {}
var _refresh_queued := false
var _last_tree := ""

func _ready() -> void:
	var title := Label.new()
	title.text="Discuss intent · inspect actual World · review options · approve one native task at a time"
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(title)
	intent.placeholder_text="Describe the structure, usable space, connections and visual character. For example: a three-level industrial service gallery with a clear central route."
	intent.custom_minimum_size.y=80
	intent.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(intent)
	var row:=HFlowContainer.new()
	add_child(row)
	for spec: Array in [["Region X",0,2047,16],["Y",0,2047,16],["Width",1,512,384],["Height",1,512,256]]:
		region_fields.append(_number(row,spec[0],spec[1],spec[2],spec[3]))
	seed=_number(row,"Seed",0,2147483647,37901)
	family.add_item("Infer family from intent")
	family.set_item_metadata(0,"")
	for key: String in Recipes.FAMILIES:
		family.add_item(key.replace("_"," ").capitalize())
		family.set_item_metadata(family.item_count-1,key)
	row.add_child(family)
	var actions:=HFlowContainer.new()
	add_child(actions)
	_button(actions,"Inspect region + propose options",propose)
	_button(actions,"Prepare Art proposal…",func() -> void: art_proposal_requested.emit())
	_button(actions,"Configure Art…",func() -> void: art_configuration_requested.emit())
	_button(actions,"Cancel discussion / stop task",cancel)
	_button(actions,"Save decision history…",func() -> void: save_history_requested.emit())
	_button(actions,"Open decision history…",func() -> void: open_history_requested.emit())
	var scope:=Label.new()
	scope.text="Inspect + propose uses the offline planner. Prepare Art proposal inspects the region and shows the exact request before a separate Send. Options need a fresh native preview and approval for each construction stage."
	scope.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(scope)
	options_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(options_info)
	options.custom_minimum_size.y=90
	options.item_selected.connect(_option_selected)
	add_child(options)
	_button(self,"Adopt selected option for review",adopt)
	totals.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(totals)
	tasks.columns=3
	tasks.hide_root=true
	tasks.column_titles_visible=true
	tasks.set_column_title(0,"Task and executor")
	tasks.set_column_title(1,"State")
	tasks.set_column_title(2,"Host native checks")
	tasks.set_column_expand(0,true)
	tasks.set_column_expand(1,false)
	tasks.set_column_custom_minimum_width(1,105)
	tasks.set_column_expand(2,false)
	tasks.set_column_custom_minimum_width(2,132)
	tasks.custom_minimum_size.y=220
	tasks.size_flags_vertical=Control.SIZE_EXPAND_FILL
	tasks.item_selected.connect(_task_selected)
	add_child(tasks)
	task_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	task_detail.max_lines_visible=4
	task_detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(task_detail)
	_button(self,"Review selected native task",review_selected)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible=3
	status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(status)
	refresh()

func bind(value: Node) -> void:
	if is_instance_valid(workflow) and workflow.changed.is_connected(_schedule_refresh): workflow.changed.disconnect(_schedule_refresh)
	workflow=value
	if is_instance_valid(workflow): workflow.changed.connect(_schedule_refresh)
	if is_node_ready(): refresh()

func _number(parent: Node,label: String,low: int,high: int,value: int) -> SpinBox:
	var group:=VBoxContainer.new()
	parent.add_child(group)
	var title:=Label.new(); title.text=label; group.add_child(title)
	var spin:=SpinBox.new(); spin.min_value=low; spin.max_value=high; spin.value=value
	spin.custom_minimum_size.x=84; group.add_child(spin)
	return spin

func _button(parent: Node,label: String,action: Callable) -> Button:
	var button:=Button.new(); button.text=label; button.pressed.connect(action); parent.add_child(button)
	return button

func region() -> Rect2i:
	return Rect2i(int(region_fields[0].value),int(region_fields[1].value),int(region_fields[2].value),int(region_fields[3].value))

func intent_snapshot() -> Dictionary:
	var area := region()
	return {"text":intent.text.strip_edges(),"seed":int(seed.value),"family":str(family.get_item_metadata(family.selected)),
		"region":[area.position.x,area.position.y,area.size.x,area.size.y]}

func propose() -> void:
	if not is_instance_valid(workflow): status.text="The host planning adapter is unavailable in this source."; return
	if intent.text.strip_edges().is_empty() or intent.text.length()>4096: status.text="Describe the intent in 1–4,096 characters."; return
	var answer: Dictionary=await workflow.propose_intent({"text":intent.text.strip_edges(),"seed":int(seed.value),"family":str(family.get_item_metadata(family.selected))},region(),{"mode":"offline","max_alternatives":3,"materials":[58,28]})
	status.text=str(answer.get("reason","Review the finite options below."))
	refresh()

func adopt() -> void:
	if not is_instance_valid(workflow): return
	var selected:=options.get_selected_items()
	if selected.is_empty() or selected[0]>=_option_ids.size(): status.text="Select a current named option to review."; return
	var answer: Dictionary=workflow.select_alternative(_option_ids[selected[0]])
	status.text=str(answer.get("reason","Plan adopted for review; no native cells applied."))
	refresh()

func cancel() -> void:
	if is_instance_valid(workflow):
		var answer: Dictionary=workflow.cancel()
		status.text=str(answer.get("reason","Cancellation requested."))

func _schedule_refresh() -> void:
	if _refresh_queued: return
	_refresh_queued=true
	call_deferred("refresh")

func refresh() -> void:
	_refresh_queued=false
	if not is_node_ready(): return
	if not is_instance_valid(workflow):
		status.text="Planning adapter unavailable. Typed staged construction remains available."
		return
	_summary=workflow.summary()
	status.text=str(_summary.get("message",""))
	var planning: Dictionary=_summary.get("planning",{})
	var alternatives: Array=planning.get("alternatives",planning.get("options",[]))
	var selected_id:=""
	var selected:=options.get_selected_items()
	if not selected.is_empty() and selected[0]<_option_ids.size(): selected_id=_option_ids[selected[0]]
	options.clear(); _option_ids.clear()
	for item: Dictionary in alternatives.slice(0,3):
		_option_ids.append(str(item.get("id","")))
		options.add_item(str(item.get("title",item.get("id","Option"))))
		options.set_item_tooltip(options.item_count-1,str(item.get("summary",item.get("description",""))))
	if not _option_ids.is_empty(): options.select(maxi(0,_option_ids.find(selected_id)))
	var questions: Variant=planning.get("questions",planning.get("clarifications",[]))
	var lines: Array[String]=[]
	if questions is Array:
		for question: Variant in questions.slice(0,4): lines.append(str(question.get("question",question)) if question is Dictionary else str(question))
	options_info.text="Planning: "+str(planning.get("status",planning.get("state","idle")))
	if not lines.is_empty(): options_info.text+="\n"+"\n".join(lines)
	var campaign: Dictionary=_summary.get("campaign",{})
	var stages: Array=_summary.get("session",{}).get("stages",[])
	_stage_indexes.clear()
	for stage: Dictionary in stages: _stage_indexes[str(stage.id)]=int(stage.index)
	var rows: Array=campaign.get("nodes",[])
	if rows.is_empty():
		for stage: Dictionary in stages:
			rows.append({"id":stage.id,"parent_id":"","title":stage.title,"kind":"stage","executor":"native","state":stage.state,
				"region":stage.region,"depends_on":stage.depends_on,"ready":stage.blocked_by.is_empty(),"reason":"", "host_budget":stage.host_budget})
	var fingerprint:=""
	for item: Dictionary in rows: fingerprint+=str([item.id,item.get("parent_id",""),item.get("title",""),item.get("kind",""),item.get("executor",""),item.get("state",""),item.get("region",[]),item.get("depends_on",[]),item.get("host_budget",{}),item.get("reason","")])
	if fingerprint!=_last_tree:
		_rebuild_tree(rows)
		_last_tree=fingerprint
	var completed:=0; var executable:=0
	for item: Dictionary in rows:
		if item.get("kind")!="group":
			executable+=1
			if item.get("state")=="completed": completed+=1
	var budget: Dictionary=campaign.get("budget",{})
	totals.text="%s · %d / %d tasks completed by native evidence\n%d verified native checks used · %d checks reserved for admitted work" % [campaign.get("title",_summary.get("session",{}).get("plan_id","No plan")),completed,executable,budget.get("used_native_checks",0),budget.get("reserved_native_checks",0)]
	totals.text+="\n%d prior campaign histories retained · historical decisions grant no current execution authority" % int(_summary.get("prior_campaigns",0))
	if campaign.get("historical_only",false): totals.text+="\nHISTORICAL REOPEN · inspect, plan and approve again; saved task status is not current World authority."

func _rebuild_tree(rows: Array) -> void:
	var previous:=""
	if tasks.get_selected()!=null: previous=str(tasks.get_selected().get_metadata(0).get("id",""))
	tasks.clear()
	var root:=tasks.create_item()
	var parents:={"":root}
	var remaining:=rows.slice(0,256)
	for pass_index: int in 16:
		if remaining.is_empty(): break
		var next: Array=[]
		for row: Dictionary in remaining:
			var parent: String=row.get("parent_id","")
			if not parents.has(parent): next.append(row); continue
			var item:=tasks.create_item(parents[parent])
			item.set_text(0,str(row.get("title",row.id))+" · "+str(row.get("executor",row.get("kind","task"))))
			item.set_text(1,str(row.get("state","planned")))
			var budget: Dictionary=row.get("host_budget",{})
			item.set_text(2,str(budget.get("checked_cells",budget.get("native_checks","—"))))
			item.set_metadata(0,row.duplicate(true))
			item.set_tooltip_text(0,str(row.get("reason","")))
			parents[str(row.id)]=item
			if row.id==previous: item.select(0)
		remaining=next

func _option_selected(index: int) -> void:
	if index>=0 and index<options.item_count:
		options_info.text="Option: "+options.get_item_text(index)+"\n"+options.get_item_tooltip(index)

func _task_selected() -> void:
	var item:=tasks.get_selected()
	if item==null: return
	var row: Dictionary=item.get_metadata(0)
	task_detail.text="%s · region %s\nDependencies: %s\n%s" % [row.get("title",row.id),str(row.get("region",[])),str(row.get("depends_on",[])),row.get("reason","")]
	if row.get("kind")=="group": task_detail.text+="\nSelect a bounded executable child for native preview and approval."

func review_selected() -> void:
	if not is_instance_valid(workflow): return
	var item:=tasks.get_selected()
	if item==null: status.text="Select an executable task."; return
	var row: Dictionary=item.get_metadata(0)
	if not _stage_indexes.has(str(row.id)): status.text="This is a composition group; select an executable child."; return
	var index: int=_stage_indexes[str(row.id)]
	var answer: Dictionary=workflow.select(index)
	if answer.get("ok",false): review_stage.emit(index)
	else: status.text=str(answer.get("reason","Task selection refused."))
