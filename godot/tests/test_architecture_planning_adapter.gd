extends SceneTree
const Adapter = preload("res://scripts/batch_lab/architecture_planning_adapter.gd")
const Recipes = preload("res://scripts/batch_lab/architecture_intent_recipes.gd")
const Catalogue = preload("res://scripts/batch_lab/native_module_catalogue.gd")
const Campaign = preload("res://scripts/batch_lab/architecture_campaign.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
var checks:=0
var failures:=0
var emitted: Array=[]

func check(value: bool,label: String) -> void:
	checks+=1; print("ARCHITECTURE_PLANNING_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)

func inspection() -> Dictionary:
	var cells:=PackedByteArray(); cells.resize(128*96*2)
	return {"ok":true,"kind":"native-inspection-snapshot","cells":cells,"region":[8,8,128,96],"source_sha256":Compiler.digest(cells),"generation":3,"captured_revision":2,"stale":false}

func response(request: Dictionary) -> Dictionary:
	var recipe:=Recipes.build(request.request_id+"-response","industrial_hangar",0,Compiler.rect(request.inspection.region),123)
	return {"format":Adapter.FORMAT,"request_id":request.request_id,"inspection_sha256":request.inspection.source_sha256,"generation":request.inspection.generation,
		"alternatives":[{"id":"a","title":"Fixture hall","summary":"A typed fixture proving the proposal-only adapter.","campaign":recipe.campaign}],"uncertainty":["Fixture, not actual inference."]}

func _initialize() -> void:
	var adapter:=Adapter.new()
	adapter.transport_requested.connect(func(request: Dictionary) -> void: emitted.append(request))
	var native:=inspection()
	var original: PackedByteArray=native.cells.duplicate()
	var proposed:=adapter.submit_intent({"text":"industrial hangar","seed":123},native)
	check(proposed.ok and proposed.status=="proposed" and proposed.alternatives.size()==3,"short recognized intent produces three named finite alternatives")
	check(emitted.is_empty() and proposed.provenance.real_model_calls==0,"offline grammar makes zero transport or model calls")
	check(native.cells==original,"planning never changes copied native inspection")
	var hashes: Array=[]
	for item: Dictionary in proposed.alternatives:
		check(Campaign.validate(item.campaign).ok,"alternative validates existing native limits "+item.id)
		var current: PackedByteArray=native.cells.duplicate(); var done: Array=[]
		for stage: Dictionary in Campaign.validate(item.campaign).native_plan.stages:
			var context: Dictionary={"region":native.region,"world_region":[0,0,256,256],"source_cells":current,"source_sha256":Compiler.digest(current),"generation":3,"paused":true,"allowed_materials":[0,58,28]}
			var compiled:=Compiler.compile(stage,context,null,done)
			check(compiled.ok,"offline alternative host projection "+item.id+"/"+stage.id+" "+str(compiled.get("reason","")))
			if not compiled.ok: break
			current=compiled.projected_cells; done.append(stage.id)
		hashes.append(Compiler.digest(current))
	check(hashes[0]!=hashes[1] and hashes[1]!=hashes[2] and hashes[0]!=hashes[2],"alternatives produce genuinely distinct projected geometry")
	check(not Compiler.canonical(adapter.summary()).contains("operations"),"frequent summaries omit full programs and material planes")
	check(adapter.alternative("option-1").campaign.id==proposed.alternatives[0].campaign.id,"selected option returns separate copied full campaign")
	check(not adapter.accept_response(proposed.request_id,proposed).ok,"already admitted response cannot arrive twice")
	var templates:=Catalogue.template_library()
	var claimed: Array=templates.library.summaries().filter(func(row: Dictionary)->bool:return row.id=="parabolic-arch-rib")
	# This is a pure host-boundary fixture, not a native observation artifact.
	claimed[0].native_readback_verified=true
	var library_option:=adapter.submit_intent({"text":"industrial hangar curved arch"},native,claimed)
	check(library_option.ok and library_option.alternatives[-1].id=="option-library","ordinary offline intent workflow exposes a genuinely module-based option")
	check(library_option.library_retrieval.status=="selected" and library_option.context_pack.parts[0].module_id=="parabolic-arch-rib","planning context carries the compact compositional choice")
	var full: Dictionary=library_option.alternatives[-1].campaign
	var current: PackedByteArray=native.cells.duplicate();var completed: Array=[]
	for item: Dictionary in Campaign.validate(full).native_plan.stages:
		var built:=Compiler.compile(item,{"region":native.region,"world_region":[0,0,256,256],"source_cells":current,"source_sha256":Compiler.digest(current),"generation":3,"paused":true,"allowed_materials":[0,58,28]},templates.library,completed)
		check(built.ok,"library composition compiles independently through host stage "+item.id+" "+str(built.get("reason","")))
		if built.ok:current=built.projected_cells;completed.append(item.id)
	var unknown:=adapter.submit_intent({"text":"make something fascinating"},native)
	check(unknown.status=="needs-clarification" and unknown.alternatives.is_empty(),"unknown intent requests explicit family choice")
	var ambiguous:=adapter.submit_intent({"text":"hangar and arcology"},native)
	check(ambiguous.status=="needs-clarification","ambiguous architectural vocabulary is visible")
	check(adapter.revise_intent({"text":"a broad open space","family":"industrial_hangar"},native).status=="proposed","owner clarification makes an independent finite proposal")
	var bad:=inspection(); bad.stale=true
	check(not adapter.submit_intent({"text":"hangar"},bad).ok,"stale native inspection refused")
	bad=inspection(); bad.cells.encode_u16(0,58)
	check(not adapter.submit_intent({"text":"hangar"},bad).ok,"unbound native material bytes refused")
	check(not adapter.submit_intent({"text":"hangar"},native,[],{"max_alternatives":4}).ok,"finite alternatives limit enforced")
	var pending:=adapter.submit_intent({"text":"industrial hangar"},native,[],{"mode":"proposal_transport"})
	check(pending.status=="awaiting-proposal" and emitted.size()==1,"explicit proposal-only transport request emitted separately")
	var first: Dictionary=emitted[-1]
	check(not first.has("cells") and not first.inspection.has("cells"),"transport receives bounded inspection facts rather than raw native/artwork payload")
	adapter.cancel_planning()
	check(not adapter.accept_response(first.request_id,response(first)).ok,"cancelled late response cannot become a fresh proposal")
	adapter.submit_intent({"text":"industrial hangar"},native,[],{"mode":"proposal_transport"})
	var next: Dictionary=emitted[-1]
	check(next.request_id!=first.request_id,"new request gets a fresh non-reused identity")
	var wrong:=response(next); wrong.inspection_sha256="0".repeat(64)
	check(not adapter.accept_response(next.request_id,wrong).ok and adapter.summary().state=="refused","response bound to another source is refused and retired")
	adapter.submit_intent({"text":"industrial hangar"},native,[],{"mode":"proposal_transport"}); next=emitted[-1]
	var good:=response(next)
	check(adapter.accept_response(next.request_id,good).status=="proposed","valid injected typed fixture becomes reviewable proposal only")
	check(adapter.result().provenance.real_model_calls==null,"transport fixture cannot self-certify genuine model usage")
	adapter.submit_intent({"text":"industrial hangar"},native,[],{"mode":"proposal_transport"}); next=emitted[-1]
	wrong=response(next); wrong.alternatives[0].campaign.region=[0,0,256,256]
	check(not adapter.accept_response(next.request_id,wrong).ok,"model cannot widen inspected construction scope")
	adapter.submit_intent({"text":"industrial hangar"},native,[],{"mode":"proposal_transport"}); next=emitted[-1]
	wrong=response(next); wrong.alternatives[0].campaign.nodes[1].stage.materials.append(19)
	check(not adapter.accept_response(next.request_id,wrong).ok,"model cannot widen proposed palette authority")
	var saved:=adapter.export_history(); var reopened:=Adapter.new()
	check(reopened.open_history(saved).historical_only and reopened.summary().state=="historical" and reopened.result().is_empty(),"reopen never restores transport request, selection or approval")
	check(not reopened.accept_response(next.request_id,response(next)).ok,"historical request cannot receive a live response")
	for family: String in Recipes.FAMILIES:
		for variant: int in 3:
			var built:=Recipes.build("grammar-"+family+"-"+str(variant),family,variant,Rect2i(8,8,128,96),123)
			check(built.ok,"finite authored grammar "+family+"/"+str(variant))
	print("ARCHITECTURE_PLANNING_ADAPTER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
