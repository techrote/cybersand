extends SceneTree
## Practical declared-variable wear on a default part. Pure proposal checks;
## actual native application is separately witnessed by the stage workflow.
const Catalogue=preload("res://scripts/batch_lab/native_module_catalogue.gd")
const Module=preload("res://scripts/batch_lab/native_module.gd")
const Jobs=preload("res://scripts/batch_lab/native_detail_jobs.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Topology=preload("res://tests/test_native_module_catalogue.gd")
var checks:=0
var failures: Array[String]=[]

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)

func _initialize() -> void:
	var boot:=Catalogue.template_library()
	check(boot.ok,"unqualified catalogue bootstrap succeeds")
	if not boot.ok: finish(); return
	var module: Dictionary=boot.library.get_module("fractured-wall-transition")
	var validated:=Module.validate(module)
	check(validated.ok,"authored variable shoulder preserves module validity")
	if not validated.ok: finish(); return
	var cells: PackedByteArray=validated.cells
	var shoulder:=Rect2i(28,44,12,12)
	var observed:=true
	for y: int in range(shoulder.position.y,shoulder.end.y):
		for x: int in range(shoulder.position.x,shoulder.end.x):
			if cells.decode_u16((y*64+x)*2)!=58: observed=false
	check(observed,"entire authored expendable shoulder is observed Hardwall")
	var compiled:=Module.compile(module,{"origin":[0,0],"transform":"identity"},{"region":[0,0,64,64],"allowed_materials":[0,7,28,58],"protected":[],"max_cells":4096})
	check(compiled.ok,"default part compiles unchanged exact native geometry")
	if not compiled.ok: finish(); return
	var contacts: Array=[]
	for connector: Dictionary in compiled.connections:
		for point: Array in connector.get("own_contact_cells",[]): contacts.append(point)
	var context:={"region":[0,0,64,64],"source_cells":cells,"source_sha256":Module.digest(cells),"generation":1,
		"allowed_materials":[0,28,58],"max_cells":256,"protected":module.protected_regions,"clearances":module.clearances,
		"fixed_regions":module.fixed_regions,"variable_regions":module.variation_regions,"attachment_cells":contacts}
	var params:={"region":[28,44,12,12],"material":0,"amount":16,"max_cells":16,"seed":37901}
	var job:=Jobs.compile_job("edge_wear",params,context)
	check(job.ok and job.get("budget",{}).get("unique_cells",0)==16,"default part supports sixteen bounded noncritical wear cells")
	if not job.ok: finish(); return
	var stage:=Jobs.stage_from_job(job,"default-part-wear","Bounded wear on authored expendable shoulder")
	var preview:=Compiler.compile(stage.stage,{"region":[0,0,64,64],"world_region":[0,0,64,64],"source_cells":cells,
		"source_sha256":Module.digest(cells),"generation":1,"paused":true,"allowed_materials":[0,28,58]})
	check(preview.ok,"ordinary source-pinned StagePlan admits declared part wear")
	if not preview.ok: finish(); return
	var safe:=true; var metal_preserved:=true
	for y: int in 64:
		for x: int in 64:
			var point:=Vector2i(x,y); var before:=cells.decode_u16((y*64+x)*2); var after: int=preview.projected_cells.decode_u16((y*64+x)*2)
			if before==after: continue
			if not shoulder.has_point(point) or before!=58 or after!=0 or Module._in_regions(point,module.fixed_regions) or [x,y] in contacts: safe=false
			if before==28: metal_preserved=false
	check(safe and metal_preserved,"whole-plane oracle preserves fixed backbone/base, connectors and Metal fragments")
	check(Topology.components(preview.projected_cells,Vector2i(64,64))==1,"bounded wear retains one observed material face component")
	var blocked:=context.duplicate(true); blocked.protected=[[28,44,12,12]]
	check(not Jobs.compile_job("edge_wear",params,blocked).ok,"owner protection overrides declared variable wear permission")
	check(not boot.library.summaries().any(func(item: Dictionary)->bool:return item.native_readback_verified),"pure wear demonstration grants no native qualification")
	finish()

func finish() -> void:
	print("NATIVE_DETAIL_CATALOGUE_WEAR_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
