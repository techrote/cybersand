extends SceneTree
const Campaign = preload("res://scripts/batch_lab/architecture_campaign.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	print("ARCHITECTURE_CAMPAIGN_CHECK ",label," ",value)
	if not value: failures += 1; push_error(label)

func stage(identity: String, x: int = 0) -> Dictionary:
	var value := Compiler.stage_defaults(identity,Rect2i(x,0,32,32))
	value.materials=[0,58]
	value.operations=[{"shape":"rectangle","x0":x+4,"y0":20,"x1":x+7,"y1":20,"material":58}]
	value.budget.max_checked_cells=8
	return value

func leaf(identity: String, x: int = 0) -> Dictionary:
	return {"id":identity,"parent_id":"district","title":"Build "+identity,"kind":"structure","region":[x,0,32,32],"depends_on":[],"executor":"typed","stage":stage(identity,x),"raster_candidates_limit":32}

func sample() -> Dictionary:
	var second:=leaf("services",32)
	second.depends_on=["frame"]
	return {"format":Campaign.FORMAT,"id":"bounded-test","title":"Two-phase bay","intent":"Construct a frame then services with separate owner decisions.","region":[0,0,64,32],"budget":{"native_checks":48,"raster_candidates":192,"max_retries_per_job":2},"nodes":[
		{"id":"district","parent_id":"","title":"Assembly bay","kind":"group","region":[0,0,64,32],"depends_on":[]},leaf("frame"),second]}

func context(x: int = 0) -> Dictionary:
	var cells:=PackedByteArray()
	cells.resize(32*32*2)
	return {"source_cells":cells,"source_sha256":Compiler.digest(cells),"region":[x,0,32,32],"world_region":[0,0,64,32],"generation":7,"paused":true,"allowed_materials":[0,58]}

func preview(value: RefCounted, identity: String = "frame") -> Dictionary:
	for item: Dictionary in value.native_plan().stages:
		if item.id==identity: return Compiler.compile(item,context(int(item.region[0])),null,item.depends_on)
	return {}

func terminal(ticket: Dictionary, sequence: int = 11, status: String = "completed", count: int = 4) -> Dictionary:
	var receipts: Array=[]
	if count>0: receipts=[{"backend":"CyberNativeCellWorld","status":"completed","checked":count,"changed":count,"confirmed":count,"requested":count,"unchanged":0,"excluded":0,"refused":0,"readback":range(count)}]
	return {"kind":"native-stage","plan_id":ticket.campaign_id,"plan_sha256":ticket.plan_sha256,"stage_id":ticket.job_id,"stage_sha256":ticket.stage_sha256,
		"preview_sha256":ticket.preview_sha256,"generation":ticket.generation,"source_sha256":ticket.source_sha256,"expected_sha256":ticket.projected_sha256,
		"native_submission":sequence,"status":status,"native_receipts":receipts,"native_receipts_sha256":Compiler.digest(Compiler.canonical(receipts).to_utf8_buffer()),
		"checked_cells":count,"changed_cells":count,"result_sha256":ticket.projected_sha256,"final_readback_available":true}

func state(value: RefCounted, identity: String) -> String:
	for row: Dictionary in value.summary().nodes:
		if row.id==identity: return row.state
	return ""

func prepare(value: RefCounted, identity: String = "frame") -> Dictionary:
	return value.bind_preview(identity,preview(value,identity)).get("ticket",{})

func queue(value: RefCounted, ticket: Dictionary, sequence: int = 11) -> void:
	check(value.reserve_approval(ticket).ok,"reserve owner decision "+str(sequence))
	check(value.mark_queued(ticket,{"sequence":sequence,"request_id":"request-"+str(sequence),"untrusted_extra":"must not persist"}).ok,"actual submission queued "+str(sequence))

func _initialize() -> void:
	var valid:=Campaign.validate(sample())
	check(valid.ok and valid.order==["frame","services"],"bounded hierarchy flattens in deterministic dependency order")
	check(valid.native_plan.stages[1].depends_on==["frame"],"hierarchy dependency reaches native stage contract")
	var altered:=sample()
	altered.nodes[1].parent_id="missing"
	check(not Campaign.validate(altered).ok,"missing parent refused")
	altered=sample(); altered.nodes[0].parent_id="district"
	check(not Campaign.validate(altered).ok,"parent cycle refused without unbounded traversal")
	altered=sample(); altered.nodes[1].depends_on=["services"]
	check(not Campaign.validate(altered).ok,"dependency cycle refused")
	altered=sample(); altered.nodes[1].depends_on=["district"]
	check(not Campaign.validate(altered).ok,"group self-dependency refused")
	altered=sample(); altered.nodes[1].id="services"
	check(not Campaign.validate(altered).ok,"duplicate node refused")
	altered=sample(); altered.nodes[1].region=[0,0,513,32]
	check(not Campaign.validate(altered).ok,"leaf scope cannot relax existing stage bounds")
	altered=sample(); altered.budget.native_checks=15
	check(not Campaign.validate(altered).ok,"declared native sums exceed aggregate ceiling")
	altered=sample(); altered.budget.raster_candidates=63
	check(not Campaign.validate(altered).ok,"declared raster sums exceed aggregate ceiling")
	altered=sample(); altered.nodes[1].scopes={"connectors":[[63,0,2,1]]}
	check(not Campaign.validate(altered).ok,"cross-boundary connector guards stay within campaign")
	altered=sample(); altered.nodes[1].stage.protected="not-an-array"
	check(not Campaign.validate(altered).ok,"malformed stage guard schema refused before summary")
	altered=sample(); altered.nodes[1].stage.notes="x".repeat(2*1024*1024)
	check(not Campaign.validate(altered).ok,"flattened two-MiB native plan limit independently retained")
	altered=sample()
	for index: int in 4:
		altered.nodes.append({"id":"nested-"+str(index),"parent_id":"district" if index==0 else "nested-"+str(index-1),"title":"Nested group","kind":"group","region":[0,0,64,32],"depends_on":[]})
	altered.nodes[1].parent_id="nested-3"
	check(not Campaign.validate(altered).ok,"hierarchy depth remains finite")
	altered=sample(); altered.nodes.append({"id":"empty","title":"Empty group","kind":"group","region":[0,0,64,32]})
	check(not Campaign.validate(altered).ok,"empty groups refused")
	altered=sample(); altered.nodes[2].depends_on=["frame-group"]
	altered.nodes.append({"id":"frame-group","parent_id":"district","title":"Frame assembly","kind":"group","region":[0,0,32,32]})
	altered.nodes[1].parent_id="frame-group"
	var expanded:=Campaign.validate(altered)
	check(expanded.ok and expanded.native_plan.stages[1].depends_on==["frame"],"group dependency expands to real leaves")

	var campaign:=Campaign.new()
	check(campaign.load_campaign(sample()).ok,"new campaign admitted without writes")
	check(campaign.ready_jobs()==["frame"],"only satisfied native prerequisites become ready")
	var compiled:=preview(campaign)
	check(compiled.ok and compiled.budget.checked_cells==4,"pure host compiler supplies actual cost")
	var ticket: Dictionary=campaign.bind_preview("frame",compiled,{"connectors":[[32,0,2,2]]}).ticket
	check(ticket.plan_sha256==Compiler.digest(Compiler.canonical(campaign.native_plan()).to_utf8_buffer()),"ticket binds exact flattened native plan")
	check(campaign.invalidate_regions([[32,0,1,1]],7).invalidated==["frame"],"guard connector overlap invalidates outside write rectangle")
	check(not campaign.reserve_approval(ticket).ok,"old ticket cannot approve invalidated scope")
	ticket=prepare(campaign)
	var forged: Dictionary=ticket.duplicate(true); forged.host_budget.checked_cells=1
	check(not campaign.reserve_approval(forged).ok,"altered approval ticket refused")
	queue(campaign,ticket)
	check(state(campaign,"frame")=="queued" and campaign.ready_jobs().is_empty(),"queued native work never claims completed")
	check(not campaign.reserve_approval(ticket).ok,"one native mutation reservation at a time")
	var wrong:=terminal(ticket); wrong.native_submission=99
	check(not campaign.observe_terminal(ticket,wrong).ok and state(campaign,"frame")=="queued","wrong submission cannot retire active job")
	check(campaign.observe_terminal(ticket,terminal(ticket)).completed,"exact correlated native terminal alone completes")
	check(campaign.ready_jobs()==["services"],"completed native dependency releases successor")
	check(not campaign.observe_terminal(ticket,terminal(ticket)).ok,"duplicate late terminal rejected")
	check(campaign.summary().budget.used_native_checks==4 and campaign.summary().budget.used_raster_candidates==4,"actual resource accounting retained")
	check(not Compiler.canonical(campaign.export_history()).contains("must not persist"),"submission metadata is explicitly whitelisted")
	check(not campaign.revise_job("frame",stage("frame")).ok,"completed geometry cannot be overwritten by revision")
	check(campaign.validate_revision("services",stage("services",32)).ok and state(campaign,"services")=="planned","revision preflight is pure")
	var saved:=campaign.export_history()
	check(not Compiler.canonical(saved).contains("lifetime"),"saved history carries no reusable runtime approval capability")
	var restored:=Campaign.new()
	check(restored.open_history(saved).ok,"complete historical record reopens for inspection")
	check(state(restored,"frame")=="planned" and restored.ready_jobs()==["frame"] and restored.summary().historical_only,"historical completion grants no current-World completion")
	check(restored.export_history().historical.size()==1,"old decisions retained as explicit historical snapshot")
	var second_restore:=Campaign.new()
	check(second_restore.open_history(restored.export_history()).ok and second_restore.export_history().historical.size()==2,"history remains flat on repeated reopen")
	check(not restored.reserve_approval(ticket).ok,"saved ticket cannot cross coordinator lifetime")
	check(campaign.skip("services").ok and not campaign.skip("services").ok,"skip is explicit and cannot inflate repeated history")
	check(restored.skip("frame").ok and restored.ready_jobs().is_empty(),"declined dependency never acts as completion")

	campaign=Campaign.new(); campaign.load_campaign(sample()); ticket=prepare(campaign)
	check(campaign.reserve_approval(ticket).ok and campaign.reject_admission(ticket,"Host source changed").ok,"prequeue refusal retires without invented terminal")
	check(state(campaign,"frame")=="refused" and campaign.summary().budget.used_native_checks==0,"prequeue refusal consumes no native budget")
	ticket=prepare(campaign); queue(campaign,ticket)
	var cancelled:=campaign.request_cancel()
	check(cancelled.await_native_terminal and state(campaign,"frame")=="queued","Stop retains pending native acknowledgement")
	check(campaign.observe_terminal(ticket,terminal(ticket,11,"partial",2)).status=="partial","stopped partial native prefix retained")
	check(campaign.ready_jobs().is_empty() and campaign.summary().state=="cancelled","cancelled campaign never auto-resumes")
	check(campaign.export_history().evidence_at_save.frame.native_checked_cells==2,"partial execution uses actual acknowledged count")

	campaign=Campaign.new(); altered=sample(); altered.budget.max_retries_per_job=0; campaign.load_campaign(altered); ticket=prepare(campaign); queue(campaign,ticket)
	check(campaign.observe_terminal(ticket,terminal(ticket,11,"refused",0)).ok and campaign.ready_jobs().is_empty(),"finite retry budget counts actual queued attempts")
	campaign=Campaign.new(); campaign.load_campaign(sample()); ticket=prepare(campaign); queue(campaign,ticket)
	var malformed:=terminal(ticket); malformed.native_receipts_sha256="0".repeat(64)
	var quarantined:=campaign.observe_terminal(ticket,malformed)
	check(not quarantined.ok and quarantined.retired and quarantined.requires_fresh_campaign,"correlated malformed terminal retires visibly without certification")
	check(campaign.summary().active_job_id.is_empty() and campaign.ready_jobs().is_empty() and campaign.summary().budget.used_native_checks==4,"unverified terminal conservatively reserves budget and stops campaign")

	campaign=Campaign.new(); campaign.load_campaign(sample()); ticket=prepare(campaign)
	var revised:=stage("frame"); revised.operations[0].x1=8
	check(campaign.revise_job("frame",revised).ok and not campaign.reserve_approval(ticket).ok,"revision invalidates exact prior preview")
	check(campaign.summary().revision==2,"revision identity increments within campaign")
	campaign.load_campaign(sample())
	check(campaign.summary().revision==1,"new campaign has its own finite revision budget")
	for index: int in Campaign.MAX_REVISIONS-1: check(campaign.revise_job("frame",stage("frame")).ok,"finite revision "+str(index+1))
	check(not campaign.revise_job("frame",stage("frame")).ok,"revision bound enforced")
	var invalid_saved:=saved.duplicate(true); invalid_saved.erase("decisions")
	check(not Campaign.new().open_history(invalid_saved).ok,"malformed historical envelope refuses safely")
	invalid_saved=saved.duplicate(true); invalid_saved.historical=[{"historical":[]}]
	check(not Campaign.new().open_history(invalid_saved).ok,"recursive imported history refused")
	campaign=Campaign.new(); altered=sample(); altered.nodes[2].depends_on=[]; altered.budget.native_checks=8; altered.nodes[1].stage.budget.max_checked_cells=4; altered.nodes[2].stage.budget.max_checked_cells=4; campaign.load_campaign(altered)
	var old_other:=prepare(campaign,"services")
	ticket=prepare(campaign); queue(campaign,ticket); campaign.observe_terminal(ticket,terminal(ticket,11,"partial",2))
	ticket=prepare(campaign); queue(campaign,ticket,12); campaign.observe_terminal(ticket,terminal(ticket,12))
	check(not campaign.reserve_approval(old_other).ok,"old preview cannot bypass aggregate budget consumed by retries")
	check(campaign.note_stale_dependencies(["frame"]).ok and state(campaign,"frame")=="stale","host stale prerequisite removes current completed authority")
	check(campaign.note_preview_refusal("frame","Native dependency changed").ok and state(campaign,"frame")=="refused","host compile refusal records before any reservation")
	print("ARCHITECTURE_CAMPAIGN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
