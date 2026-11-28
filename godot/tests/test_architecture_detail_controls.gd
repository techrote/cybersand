extends SceneTree
## Controlled source fixtures only. Native job compilation and UI admission are
## independently exercised by actual Workbench tests; this suite invents no World.
const Pane=preload("res://scripts/batch_lab/architecture_detail_panel.gd")
const Module=preload("res://scripts/batch_lab/native_module.gd")
var checks:=0
var failures:=0

class SessionFixture extends Node:
	var context: Dictionary
	var stale:=false
	var inspections:=0
	var selected_instances: Array=[]
	func detail_context(_region: Rect2i,identity: String="") -> Dictionary:
		inspections+=1; selected_instances.append(identity)
		return {"ok":true,"context":context.duplicate(true),"instances":[{"instance_id":"fixture-source","module_id":"authored-fixture","name":"Controlled source fixture"}],"scope":"Pure fixture; no actual native observation."}
	func inspection_view() -> Dictionary:
		return {"ok":true,"stale":stale,"source_sha256":context.source_sha256,"generation":context.generation}

class WorkflowFixture extends Node:
	var plans: Array=[]
	func busy() -> bool: return false
	func load_plan(value: Dictionary) -> Dictionary:
		plans.append(value.duplicate(true)); return {"ok":true,"reason":"Controlled typed proposal retained; no native admission."}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error("ARCHITECTURE_DETAIL_CONTROLS: "+label)

func run() -> void:
	var session:=SessionFixture.new(); root.add_child(session)
	var source:=PackedByteArray(); source.resize(64*64*2)
	for x: int in range(4,60): source.encode_u16((30*64+x)*2,58)
	session.context={"region":[0,0,64,64],"source_cells":source,"source_sha256":Module.digest(source),"generation":1,"allowed_materials":[0,7,13,28,58],
		"protected":[],"clearances":[],"fixed_regions":[],"variable_regions":[],"attachment_cells":[],"max_cells":16384}
	var workflow:=WorkflowFixture.new(); root.add_child(workflow)
	var pane:=Pane.new(); root.add_child(pane); pane.bind(session,workflow)
	await process_frame
	check(pane.kind.item_count==8 and session.inspections==0 and workflow.plans.is_empty(),"opening eight friendly detail controls never inspects or admits native work automatically")
	for index: int in 4:
		pane.inspection_fields[index].value=[0,0,64,64][index]
		pane.area_fields[index].value=[10,20,20,10][index]
	pane.fields.facing.select(1)
	await pane.inspect_source()
	check(session.inspections==1 and pane.instance.item_count==2 and pane.source_label.text.contains("Pure fixture"),"scope inspection lists actual adapter-provided instance identities without inventing a selected target")
	await pane.prepare()
	check(not pane._job.is_empty() and pane._job.zero_writes and pane.result_label.text.contains("ZERO-WRITE"),"typed dimensions compile an explicit source-grounded zero-write detail proposal")
	check(pane._job.budget.unique_cells>0 and pane._job.materials==[28] and pane.params().width==2,"named material and geometry controls produce bounded typed fields")
	pane.fields.depth.value=7
	pane.review()
	check(workflow.plans.is_empty() and pane.result_label.text.contains("No current"),"editing dimensions invalidates prior generated output before stage admission")
	await pane.prepare(); pane.review()
	check(workflow.plans.size()==1 and workflow.plans[0].stages[0].input_snapshot_sha256==session.context.source_sha256 and workflow.plans[0].stages[0].input_generation==1,"reviewed job preserves exact source bytes and generation in the native stage contract")
	session.stale=true; pane.review()
	check(workflow.plans.size()==1 and pane.result_label.text.contains("snapshot changed"),"a stale actual-source adapter cannot be silently replaced during review")
	session.stale=false
	pane.kind.select(2); pane._build_fields()
	check(pane.fields.has("irregularity") and pane.fields.irregularity.max_value==4 and pane.fields.density.max_value==1.0,"clutter amount and irregularity are independently bounded friendly controls")
	pane.kind.select(5); pane._build_fields()
	for index: int in 12: pane.add_path_point(Vector2i(12+index,20))
	check(pane.params().waypoints.size()==8,"orthogonal route editor has an explicit eight-waypoint resource ceiling")
	for index: int in 12: pane.remove_path_point()
	check(pane.params().waypoints.size()==2,"route editor preserves its two-point minimum without malformed partial arrays")
	pane.kind.select(7); pane._build_fields()
	check(pane.material_choice.item_count==1 and pane.params().material==0 and pane.fields.amount.max_value==256,"wear exposes only bounded explicit removal controls")
	await pane.prepare()
	check(pane._job.is_empty() and pane.result_label.text.contains("explicitly selected"),"wear refuses a blanket region without a named native instance")
	pane.instance.select(1); await pane.prepare()
	check(pane._job.is_empty() and session.selected_instances.back()=="fixture-source","wear forwards the exact chosen native instance and refuses absent authored variable scope")
	pane.discard(); check(pane._job.is_empty() and workflow.plans.size()==1,"discard retires proposals without native or workflow side effects")
	pane.queue_free(); session.queue_free(); workflow.queue_free()
	await process_frame; await process_frame
	print("ARCHITECTURE_DETAIL_CONTROLS: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
