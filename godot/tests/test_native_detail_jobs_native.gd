extends SceneTree
## Frozen 8 jobs × 3 matched arms, through existing StagePlan and native Batch.
## Worker and random proposals remain separate from actual material receipts.
const Jobs = preload("res://scripts/batch_lab/native_detail_jobs.gd")
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Fixtures = preload("res://tests/test_native_detail_jobs.gd")
const REGISTRATION := "res://data/batch_lab/m67/detail-experiment.v1.json"
const REGISTRATION_SHA256 := "4e69cbdbca9a908ed2062cfc60b7bf448c4a44a73c1a5cd90b8640daabb16852"
var controller: Node
var checks := 0
var failures: Array[String] = []
var cases: Array = []
var output := ""
var source_revision := ""
var development_capacity := 0
var registered_proposals: Array = []

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	var raw := OS.get_environment("ARCHITECTURE_DEVELOPMENT_CORE_CAPACITY")
	if not raw.is_empty():
		if not raw.is_valid_int() or int(raw)<1 or int(raw)>256: push_error("Invalid explicit development core capacity."); quit(1); return
		development_capacity=int(raw); ProjectSettings.set_setting("cybersand/native_active_core_capacity",development_capacity)
		print("NATIVE_DETAIL_DEVELOPMENT_CORE_CAPACITY ",development_capacity,"; separate from default-capacity qualification")
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks+=1; print("NATIVE_DETAIL_NATIVE_CHECK ",checks," ",label," ",value)
	if not value: failures.append(label); push_error(label)
	return value

func write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_buffer(bytes); file.close()
	return FileAccess.get_sha256(path)==Module.digest(bytes)

func settle() -> bool:
	var deadline := Time.get_ticks_msec()+240000
	while controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	if controller.is_running(): controller.stop()
	return check(not controller.is_running(),"bounded native detail cohort retired")

func random_program(item: Dictionary, target: Dictionary) -> Dictionary:
	var region := Module.rect(item.params.region)
	var guards: Array=item.context.protected+item.context.fixed_regions+target.clearances
	var candidates: Array=[]
	for y: int in range(region.position.y,region.end.y):
		for x: int in range(region.position.x,region.end.x):
			var point := Vector2i(x,y)
			if Module._in_regions(point,guards) or [x,y] in item.context.attachment_cells: continue
			var material: int=item.context.source_cells.decode_u16((y*64+x)*2)
			if item.kind=="edge_wear":
				if material!=58 or not Module._in_regions(point,item.context.variable_regions): continue
			elif material!=0: continue
			candidates.append([x,y])
	var random := RandomNumberGenerator.new(); random.seed=47017
	for i: int in range(candidates.size()-1,0,-1):
		var swap := random.randi_range(0,i); var held: Variant=candidates[i]; candidates[i]=candidates[swap]; candidates[swap]=held
	if candidates.size()<int(target.budget.unique_cells): return {"ok":false,"reason":"Random-valid eligible set cannot match the registered seeded cell count."}
	var chosen: Array=candidates.slice(0,int(target.budget.unique_cells))
	return {"ok":true,"operations":[{"shape":"pixels","material":item.params.material,"points":chosen}]}

func prepare(kind: String, arm: String) -> Dictionary:
	var seed_value := 0 if arm=="deterministic" else 47017
	var item := Fixtures.fixture(kind,seed_value)
	var target := Jobs.compile_job(kind,item.params,item.context)
	var identity := kind.replace("_","-")+"-"+arm.replace("_","-")
	var base := {"id":identity,"job":kind,"arm":arm,"seed":seed_value,"extent":[64,64],"params":item.params,
		"source_sha256":item.context.source_sha256,"context":{"region":item.context.region,"job_region":item.params.region,
			"protected":item.context.protected,"fixed_regions":item.context.fixed_regions,"variable_regions":item.context.variable_regions,
			"attachment_cells":item.context.attachment_cells,"clearances":[]},"status":"proposed","reason":"","model_calls":0}
	if not target.ok: base.status="compile-refused"; base.reason=target.reason; return {"case":base,"item":item}
	var seeded_fixture := Fixtures.fixture(kind,47017)
	var shared := Jobs.compile_job(kind,seeded_fixture.params,seeded_fixture.context)
	if not shared.ok: base.status="compile-refused"; base.reason=shared.reason; return {"case":base,"item":item}
	base.context.clearances=shared.clearances.duplicate(true)
	var stage: Dictionary
	if arm=="random_valid":
		var random := random_program(item,shared)
		if not random.ok: base.status="compile-refused"; base.reason=random.reason; return {"case":base,"item":item}
		stage=Compiler.stage_defaults(identity,Rect2i(0,0,64,64))
		stage.operations=random.operations; stage.materials=[item.params.material]; stage.clearances=shared.clearances.duplicate(true)
		stage.protected=item.context.protected.duplicate(true)+item.context.fixed_regions.duplicate(true)
		for point: Array in item.context.attachment_cells: stage.protected.append([point[0],point[1],1,1])
		stage["input_snapshot_sha256"]=item.context.source_sha256; stage["input_generation"]=1
		stage.budget.max_checked_cells=512
	else:
		var typed := Jobs.stage_from_job(target,identity,"Registered bounded "+kind+" "+arm+" control")
		if not typed.ok: base.status="compile-refused"; base.reason=typed.reason; return {"case":base,"item":item}
		stage=typed.stage; stage.clearances=shared.clearances.duplicate(true)
	var preview := Compiler.compile(stage,Fixtures.stage_context(item.context))
	base["stage"]=stage; base["program_sha256"]=Module.digest(Module.json_bytes(stage.operations))
	base["worker_output_sha256"]=target.proposal_sha256 if arm!="random_valid" else ""
	if not preview.ok: base.status="compile-refused"; base.reason=preview.reason; return {"case":base,"item":item}
	base["projection_sha256"]=preview.projected_sha256; base["compiled_budget"]=preview.budget
	var stale := Fixtures.stage_context(item.context); stale.source_cells=item.context.source_cells.duplicate(); stale.source_cells.encode_u16((60*64+60)*2,58); stale.source_sha256=Module.digest(stale.source_cells)
	base["source_pin_refusal_verified"]=not Compiler.compile(stage,stale).ok
	check(base.source_pin_refusal_verified,"source-pinned delegated stage refuses changed actual input "+identity)
	return {"case":base,"item":item,"preview":preview}

func run() -> void:
	output=OS.get_environment("NATIVE_DETAIL_EVIDENCE_DIR"); source_revision=OS.get_environment("CYBERSAND_SOURCE_REVISION")
	if not check(not output.is_empty() and source_revision.length()==40 and Module._hex(source_revision+"0".repeat(24)),"explicit artifact directory and exact source identity"): finish(); return
	for child: String in ["planes","native","recipes"]: DirAccess.make_dir_recursive_absolute(output.path_join(child))
	if not check(FileAccess.get_sha256(REGISTRATION)==REGISTRATION_SHA256,"exact frozen detail registration identity"): finish(); return
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REGISTRATION))
	check(registration.expected_cases==24 and registration.jobs==Jobs.KINDS,"frozen finite 24-case registration")
	var pending: Array=[]
	for kind: String in registration.jobs:
		for arm: String in registration.arms: pending.append(prepare(kind,arm))
	# Retain all proposals/refusals before observing the first native outcome.
	var proposals: Array=[]
	for item: Dictionary in pending: proposals.append(item.case.duplicate(true))
	registered_proposals=proposals.duplicate(true)
	check(pending.all(func(item: Dictionary) -> bool: return item.has("preview")),"all frozen apparatus cases compile before native execution")
	check(write_bytes(output.path_join("frozen-proposals.json"),Module.json_bytes(proposals)),"retain fixed proposals before native outcomes")
	if OS.get_environment("NATIVE_DETAIL_PREFLIGHT_ONLY")=="1":
		var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":proposals,"source_revision":source_revision,
			"scope":"Pure compilation preflight only; no native owner, receipts or material application."}
		write_bytes(output.path_join("preflight.json"),Module.json_bytes(report))
		print("NATIVE_DETAIL_PREFLIGHT_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"cases":proposals.size(),"failures":failures}))
		quit(0 if failures.is_empty() else 1); return
	controller=Controller.new(); root.add_child(controller); await process_frame
	controller.max_parallel=1; controller.configure_grid(4,4)
	for offset: int in range(0,pending.size(),16):
		var batch: Array=pending.slice(offset,mini(offset+16,pending.size())); var slots: Array=[]; var by_slot: Dictionary={}
		for item: Dictionary in batch:
			if not item.has("preview"): cases.append(item.case); continue
			var index := slots.size(); var config := Controller.defaults()
			config.extent=[64,64]; config.source_region=[0,0,64,64]; config.source_extent=[64,64]; config.source_cells=item.item.context.source_cells.duplicate()
			config.materials=item.case.stage.materials.duplicate(); config.protection=item.case.stage.protected.duplicate(true)
			config.operations=item.preview.operations.duplicate(true); config.budget_cells=512; config.seed=item.case.seed
			if not check(controller.configure_tile(index,config).ok,"configure source-bound native detail "+item.case.id):
				item.case.status="configuration-refused"; cases.append(item.case); continue
			slots.append(index); by_slot[index]=item
		if slots.is_empty(): continue
		check(controller.start(slots).ok,"queue finite native detail cohort")
		if not await settle(): break
		for index: int in slots:
			var item: Dictionary=by_slot[index]; var tile: Dictionary=controller.tiles[index]; var row: Dictionary=item.case
			row.status=tile.state; row.reason=tile.reason
			var before_path: String="planes/"+row.id+".before.u16le"; var after_path: String="planes/"+row.id+".after.u16le"
			var native_path: String="native/"+row.id+".json"; var recipe_path: String="recipes/"+row.id+".json"
			check(write_bytes(output.path_join(before_path),tile.source_materials) and write_bytes(output.path_join(after_path),tile.material_cells),"retain complete native material planes "+row.id)
			check(write_bytes(output.path_join(native_path),Module.json_bytes(Controller._encode(controller._record(tile)))) and write_bytes(output.path_join(recipe_path),Module.json_bytes(row.stage)),"retain original native receipts and exact stage "+row.id)
			row["before"]={"path":before_path,"sha256":Module.digest(tile.source_materials),"encoding":"u16le"}
			row["after"]={"path":after_path,"sha256":Module.digest(tile.material_cells),"encoding":"u16le"}
			row["native_record"]={"path":native_path,"sha256":FileAccess.get_sha256(output.path_join(native_path))}
			row["recipe"]={"path":recipe_path,"sha256":FileAccess.get_sha256(output.path_join(recipe_path))}
			row["timings"]=tile.timings.duplicate(true); row["native_provenance"]=tile.provenance.duplicate(true)
			if not check(tile.source_materials.size()==8192 and tile.material_cells.size()==8192,"complete native readback available "+row.id):
				row["readback_unavailable"]=true; row.erase("stage"); cases.append(row); continue
			check(tile.state=="completed" and tile.material_cells==item.preview.projected_cells,"actual native result equals approved full projection "+row.id)
			check(tile.source_materials==item.item.context.source_cells and tile.metrics.get("outside_unchanged",false),"native source identity and outside arena preservation "+row.id)
			var scope_ok := true
			for y: int in 64:
				for x: int in 64:
					var point := Vector2i(x,y); var before: int=tile.source_materials.decode_u16((y*64+x)*2); var after: int=tile.material_cells.decode_u16((y*64+x)*2)
					if (not Module.rect(row.context.job_region).has_point(point) or Module._in_regions(point,row.context.protected+row.context.fixed_regions) or [x,y] in row.context.attachment_cells) and before!=after: scope_ok=false
					if Module._in_regions(point,row.context.clearances) and after!=0: scope_ok=false
			check(scope_ok,"independent whole-plane scope/guard/clearance/attachment oracle "+row.id)
			if tile.image!=null: tile.image.save_png(output.path_join(row.id+".native-material-id.png"))
			row.erase("stage"); cases.append(row)
	check(cases.size()==24,"all registered detail outcomes retained in denominator")
	finish()

func finish() -> void:
	if controller!=null: controller.queue_free()
	var observed := {}
	for row: Dictionary in cases: observed[row.id]=true
	for proposal: Dictionary in registered_proposals:
		if not observed.has(proposal.id):
			var missing:=proposal.duplicate(true); missing.status="native-observation-unavailable"; missing.reason="Harness ended before this registered case had a retained terminal observation."
			cases.append(missing)
	var report := {"format":"cybersand-native-detail-comparison-evidence-v1","passed":failures.is_empty(),"checks":checks,"failures":failures,
		"source_revision":source_revision,"engine":Engine.get_version_info().string,"registration_sha256":FileAccess.get_sha256(REGISTRATION),
		"fixture_source_sha256":FileAccess.get_sha256("res://tests/test_native_detail_jobs.gd"),"worker_source_sha256":FileAccess.get_sha256("res://scripts/batch_lab/native_detail_jobs.gd"),
		"development_core_capacity_override":development_capacity,"native_active_core_capacity":ProjectSettings.get_setting("cybersand/native_active_core_capacity",1024),
		"cases":cases,"model_calls":0,"scope":"Frozen source-bound native tool/constraint comparison. No model inference, physics stability, machine flow, actor traversal or aesthetic preference claim."}
	if not output.is_empty(): write_bytes(output.path_join("cases.json"),Module.json_bytes(report))
	print("NATIVE_DETAIL_NATIVE_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases.size(),"source_revision":source_revision,"development_core_capacity_override":development_capacity}))
	quit(0 if failures.is_empty() else 1)
