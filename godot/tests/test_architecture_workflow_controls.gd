extends SceneTree
## UI contracts against controlled value fixtures; no native World is created.
const Pane=preload("res://scripts/batch_lab/architecture_workflow_panel.gd")
const ArchitecturePanel=preload("res://scripts/batch_lab/architecture_stage_panel.gd")
const Module=preload("res://scripts/batch_lab/native_module.gd")
const Witness=preload("res://tests/support/architecture_actor_witness.gd")
var checks:=0
var failures:=0

class HostlessWorkbench extends Node:
	var host: Node
	var paint_editor: Node
	var art_batches: Node
	var applied: Dictionary={"extent":[512,512]}

class FacadeFixture extends Node:
	signal changed
	var proposals:=0
	var adoptions: Array=[]
	var selections: Array=[]
	var cancellations:=0
	var preparations:=0
	var can_prepare:=false
	var prepared:=false
	var last_intent: Dictionary={}
	var last_options: Dictionary={}
	func summary() -> Dictionary:
		return {"message":"Controlled UI fixture; no native execution.","prior_campaigns":2,"can_prepare_local_job":can_prepare,"prepared_local_job":prepared,"planning":{"state":"options-ready","alternatives":[
			{"id":"open","title":"Open hall","summary":"Broad central void."},{"id":"offset","title":"Offset gallery","summary":"A supported unequal gallery."}],"questions":[]},
			"session":{"stages":[{"id":"structure","index":0},{"id":"details","index":1}]},
			"campaign":{"title":"Fixture campaign","historical_only":false,"budget":{"used_native_checks":0,"reserved_native_checks":0},"nodes":[
				{"id":"group","parent_id":"","title":"Compose the space","kind":"group","state":"planned"},
				{"id":"structure","parent_id":"group","title":"Build primary frame","kind":"structure","executor":"native-modules","state":"review","region":[16,16,128,128],"depends_on":[],"host_budget":{"checked_cells":180}},
				{"id":"details","parent_id":"group","title":"Add contextual trim","kind":"detail","executor":"procedural-detail","state":"planned","region":[16,16,128,128],"depends_on":["structure"],"host_budget":{}}]}}
	func propose_intent(value: Dictionary,_region: Rect2i,options: Dictionary) -> Dictionary:
		proposals+=1; last_intent=value.duplicate(); last_options=options.duplicate(); changed.emit()
		return {"ok":true,"zero_writes":true,"reason":"Fixture options; no native writes."}
	func select_alternative(identity: String) -> Dictionary:
		adoptions.append(identity); changed.emit(); return {"ok":true}
	func select(index: int) -> Dictionary:
		selections.append(index); return {"ok":true}
	func cancel() -> Dictionary:
		cancellations+=1; return {"ok":true}
	func prepare_selected_job() -> Dictionary:
		preparations+=1; prepared=true
		return {"ok":true,"zero_writes":true,"queued":false,"completed":false,"stage_id":"details"}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error("ARCHITECTURE_WORKFLOW_CONTROLS: "+label)

func _connector(identity: String,y: int,facing_y: int) -> Dictionary:
	return {"id":identity,"kind":"line","point":[0,y],"end":[1,y],"facing":[0,facing_y],"compatibility":["fixture-frame"],"required":false,"source":"authored",
		"role":"frame","approach":"face","polarity":"neutral","capacity":1,"contact":{"policy":"full","minimum_cells":2,"tolerance":0}}

func run() -> void:
	var facade:=FacadeFixture.new(); root.add_child(facade)
	var pane:=Pane.new(); root.add_child(pane); pane.bind(facade)
	await process_frame
	check(facade.proposals==0 and facade.adoptions.is_empty() and facade.selections.is_empty(),"opening and rendering task overview never dispatches a proposal or adopts work")
	check(pane.options.item_count==2 and pane.family.item_count==7,"named finite alternatives and explicit family clarification are usable controls")
	var group: TreeItem=pane.tasks.get_root().get_first_child()
	check(group.get_child_count()==2 and group.get_text(0).contains("Compose"),"task hierarchy retains composition group and bounded executor children")
	check(group.get_first_child().get_text(2)=="180" and group.get_first_child().get_next().get_text(2)=="—","only host-compiled budget is displayed as numeric task cost")
	check(pane.totals.text.contains("2 prior campaign histories retained") and pane.totals.text.contains("no current execution authority"),"bounded archived campaign count remains explicitly historical")
	pane.intent.text="An industrial service gallery with a clear route"
	pane.family.select(5)
	await pane.propose()
	check(facade.proposals==1 and facade.last_intent.family=="service_network" and facade.last_options.mode=="offline","owner chooses explicit family and deterministic offline proposal mode")
	pane.options.select(1); pane.adopt()
	check(facade.adoptions==["offset"],"adoption maps exactly the chosen finite option without implicit native approval")
	var reviewed: Array=[]
	pane.review_stage.connect(func(index: int) -> void: reviewed.append(index))
	group.select(0); pane.review_selected()
	check(reviewed.is_empty(),"group row cannot masquerade as an executable native stage")
	group.get_first_child().select(0); pane.review_selected()
	check(reviewed==[0] and facade.selections==[0],"selected leaf maps to the single host session stage")
	pane.cancel(); check(facade.cancellations==1,"visible Stop delegates once to the host workflow")
	var workbench:=HostlessWorkbench.new(); root.add_child(workbench)
	var panel:=ArchitecturePanel.new(); panel.wb=workbench; root.add_child(panel)
	await process_frame
	check(is_instance_valid(panel.detail_panel) and panel.detail_panel.kind.item_count==8,"shipped panel mounts the eight-job typed detail controls without a second native session")
	check(panel.prepare_local_button.disabled,"local preparation is unavailable without a host-ready delegated task")
	var real_workflow: Node=panel.workflow
	panel.workflow=facade; facade.can_prepare=true; panel._refresh_session()
	check(not panel.prepare_local_button.disabled,"local preparation availability uses the host's public readiness flag")
	var record_count: int=panel.session.records.size()
	await panel.prepare_local_job()
	check(facade.preparations==1 and panel.session.records.size()==record_count and panel.session.preview.is_empty() and panel.status.text.contains("No native work was queued"),"visible Prepare delegates once and preserves the preview/approval boundary")
	panel.workflow=real_workflow; panel._refresh_session()
	var cells:=PackedByteArray(); cells.resize(2*4*2)
	for index: int in 8: cells.encode_u16(index*2,58)
	var module: Dictionary=Module.harvest(cells,Vector2i(2,4),Rect2i(0,0,2,4),{"format":Module.FORMAT_V2,"id":"snap-ui-fixture","name":"Snap UI fixture",
		"allowed_transforms":["identity","mirror_x"],"attachments":[_connector("head",0,-1),_connector("foot",3,1)]}).module
	panel.library.add(module)
	panel.search.text="snap-ui-fixture"; panel._refresh_modules()
	for i: int in 4: panel.area_fields[i].value=[0,0,64,64][i]
	panel.origin_fields[0].value=20; panel.origin_fields[1].value=24
	var source:=PackedByteArray(); source.resize(64*64*2)
	var compiled:=Module.compile(module,{"origin":[20,20]}, {"region":[0,0,64,64],"allowed_materials":[0,58],"max_cells":4096})
	for offset: int in range(0,compiled.cells.size(),3): source.encode_u16((compiled.cells[offset+1]*64+compiled.cells[offset])*2,compiled.cells[offset+2])
	# Controlled snapshot fixture, deliberately not a native admission claim.
	panel.session._inspection={"ok":true,"kind":"native-inspection-snapshot","region":[0,0,64,64],"cells":source,"source_sha256":Module.digest(source),
		"generation":1,"captured_revision":panel.session.revision_token(),"provenance":{},"world_fence":{}}
	for connector: Dictionary in compiled.connections:
		connector["module_instance"]="placed-fixture"; connector["generation"]=1; connector["stage_id"]="fixture"
		connector["contact_materials"]=[]
		for point: Array in connector.own_contact_cells: connector.contact_materials.append([point[0],point[1],58])
		panel.session._placed_connectors.append(connector)
	panel._snap_inventory=panel.session.connection_targets()
	for connector: Dictionary in panel._snap_inventory.targets: panel.target_connector.add_item(connector.id)
	panel.target_connector.select(1); panel.source_connector.select(0)
	panel.find_snap_poses()
	check(panel._snap_candidates.size()>=1 and panel._snap_candidates[0].placement.origin==[20,24],"actual snap UI resolves opposing occupied full spans at the exact local-to-world pose")
	check(panel.snap_list.get_item_text(0).contains("2 contact cells") and panel.snap_list.get_item_text(0).contains("↔"),"candidate display exposes exact contact span and count")
	var before_plan: String=panel.session.plan.id
	panel.keep.value=0.5; panel.propose_snap()
	check(panel.session.plan.id==before_plan and panel.status.text.contains("changed"),"edited variation controls retire a previously displayed snap proposal")
	panel.keep.value=1.0; panel.propose_snap()
	check(panel.session.stage().get("module_bindings",[]).size()==1 and panel.session.stage().modules[0].has("instance_id"),"selected snap creates a content-pinned instance and explicit binding, never native completion")
	check(panel.session.records.all(func(record: Dictionary) -> bool: return record.kind!="native-stage") and panel.session.preview.is_empty(),"controlled snap fixture creates no native receipt or current approval")
	var action:=Witness.action({"position":Vector2(10,10),"velocity":Vector2.ZERO,"rotation":0.0,"angular_velocity":0.0},Vector2(120,10))
	check(action.move.length()<=1.0 and action.move.y<0 and not action.primary and not action.auxiliary,"bounded Midge pilot uses thrust/turn commands without dispenser or pose APIs")
	check(Witness.action({"position":Vector2(INF,0)},Vector2.ZERO).is_empty(),"nonfinite actor observation cannot produce a flight command")
	check(panel.flagship.item_count==4 and panel.example.item_count==9,"four large hierarchical flagships are discoverable alongside all nine original examples")
	var previous_plan: String=panel.session.plan.id
	panel.load_flagship()
	check(panel.session.plan.id==previous_plan and panel.status.text.contains("requires at least") and workbench.applied.extent==[512,512],"flagship refuses a smaller existing World without changing the current plan or World")
	await panel.add_curated_templates()
	check(panel.library.count()>=40 and panel.library.summaries().all(func(item: Dictionary) -> bool: return not item.get("native_readback_verified",false)),"curated browser bootstrap retains all forty distinct templates without invented native qualification")
	panel.search.text="tapered-pier"; panel._refresh_modules()
	check(panel.module_summary.text.contains("UNEXECUTED TEMPLATE") and not panel.keep.editable,"template status and fixed geometry are explicit in the ordinary inspector")
	panel.load_delegated_workshop()
	check(panel.session.plan.id=="delegated-workshop" and panel.workflow.summary().campaign.nodes.filter(func(item: Dictionary)->bool:return item.get("executor","")=="procedural").size()==3 and panel.session.preview.is_empty(),"workshop button loads three finite worker proposals without approval")
	var initial_stage: String=panel.session.stage().id
	panel.revise_workshop_gallery()
	check(panel.session.stage().id==initial_stage and panel.session.preview.is_empty(),"gallery convenience action cannot replace an unrelated selected task")
	for index: int in panel.session.plan.stages.size():
		if panel.session.plan.stages[index].id=="access-gallery": panel.workflow.select(index); break
	panel.revise_workshop_gallery()
	check(panel.session.stage().operations[0].x0==64 and panel.session.stage().operations[0].x1==175 and panel.session.preview.is_empty(),"gallery repair uses the shared host proposal without creating approval")
	await panel.recover_workshop()
	check(panel.session.plan.id=="delegated-workshop" and panel.session.preview.is_empty(),"recovery convenience action refuses when no actual partial native receipt exists")
	workbench.applied.extent=[1024,1024]
	panel.load_flagship()
	check(panel.session.plan.id.begins_with("flagship-") and panel.workflow.summary().campaign.nodes.size()>12 and panel.session.preview.is_empty(),"large typed hierarchy loads into an adequate existing World as unapproved tasks")
	var normalized:=Witness.descriptor({"id":"large-route","witness":{"spawn":[400,928],"goal":[680,928],"corridor":[384,888,320,96],"landing_pad":[648,984,64,16],"tick_budget":2400}})
	check(normalized.waypoints==[[680,928]] and normalized.landing==[680.0,982.0] and Witness.inspection_region(normalized,Vector2i(1024,1024)).has_point(Vector2i(680,984)),"large native witness normalization captures the real route and landing beyond the top-left tile")
	panel.queue_free(); workbench.queue_free(); pane.queue_free(); facade.queue_free()
	await process_frame; await process_frame
	print("ARCHITECTURE_WORKFLOW_CONTROLS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
