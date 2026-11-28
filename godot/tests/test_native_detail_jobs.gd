extends SceneTree
## Typed worker geometry/guard tests. Synthetic source fixtures never establish
## native application; the separate matched harness retains actual observations.
const Jobs = preload("res://scripts/batch_lab/native_detail_jobs.gd")
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Topology = preload("res://tests/test_native_module_catalogue.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks+=1
	if not condition: failures.append(label); push_error(label)

static func _fill(cells: PackedByteArray, box: Rect2i, material: int, width := 64) -> void:
	for y: int in range(box.position.y,box.end.y):
		for x: int in range(box.position.x,box.end.x): cells.encode_u16((y*width+x)*2,material)

static func fixture(kind: String, seed_value := 0) -> Dictionary:
	var cells := PackedByteArray(); cells.resize(64*64*2)
	for box: Rect2i in [Rect2i(4,4,56,4),Rect2i(4,8,4,40),Rect2i(56,8,4,40),Rect2i(4,48,56,4)]: _fill(cells,box,58)
	_fill(cells,Rect2i(1,1,2,2),13)
	var context := {"region":[0,0,64,64],"source_cells":cells,"source_sha256":Module.digest(cells),"generation":1,
		"allowed_materials":[0,7,28,58],"max_cells":1024,"protected":[[1,1,2,2]],"clearances":[[40,16,8,24]],
		"fixed_regions":[],"variable_regions":[],"attachment_cells":[]}
	var params := {"region":[8,8,48,40],"material":28,"seed":seed_value,"max_cells":512}
	match kind:
		"contextual_ribs": params.merge({"facing":"down","width":2,"depth":6,"spacing":8,"density":1.0})
		"surface_trim": params.merge({"facing":"down","length":12,"depth":1,"spacing":16,"density":1.0})
		"anchored_clutter": params.merge({"facing":"right","width":3,"depth":4,"spacing":6,"density":0.7,"irregularity":2})
		"service_panel": params.region=[8,8,20,20]; params.merge({"frame_thickness":2,"ribs":2})
		"mechanical_infill": params.merge({"orientation":"vertical","thickness":1,"spacing":6})
		"short_pipe": params.merge({"waypoints":[[8,20],[20,20],[20,47]],"width":1})
		"framed_opening": params.region=[8,8,24,40]; params.merge({"opening":"door","frame_thickness":2})
		"edge_wear":
			_fill(cells,Rect2i(8,40,16,8),58)
			context.source_sha256=Module.digest(cells); context.variable_regions=[[8,40,16,8]]; context.fixed_regions=[[8,44,8,4]]; context.attachment_cells=[[23,47]]
			params.region=[8,40,16,8]; params.material=0; params["amount"]=16
	return {"kind":kind,"params":Module.canonical(params),"context":context}

static func stage_context(host: Dictionary) -> Dictionary:
	return {"region":host.region.duplicate(),"source_cells":host.source_cells,"source_sha256":host.source_sha256,
		"world_region":[0,0,64,64],"generation":host.get("generation",1),"paused":true,"allowed_materials":[0,7,13,28,58]}

func _initialize() -> void:
	check(Jobs.describe_jobs().size()==8,"eight finite code-owned executor descriptors")
	for descriptor: Dictionary in Jobs.describe_jobs():
		check(descriptor.controls.size()>0 and descriptor.model_calls==0 and not descriptor.native_writes,"typed controls expose no model or native mutation "+descriptor.kind)
	for kind: String in Jobs.KINDS:
		var item := fixture(kind); var before: PackedByteArray=item.context.source_cells.duplicate()
		var result := Jobs.compile_job(kind,item.params,item.context)
		check(result.ok,"typed worker compiles grounded fixture "+kind+" "+str(result.get("reason","")))
		if not result.ok: continue
		check(result.zero_writes and result.status=="proposed" and result.model_calls==0,"worker output remains a proposal "+kind)
		check(item.context.source_cells==before,"worker never mutates source snapshot "+kind)
		check(result.budget.unique_cells==result.operations[0].points.size() and result.budget.unique_cells<=item.params.max_cells,"exact bounded unique operation budget "+kind)
		var repeated := Jobs.compile_job(kind,item.params,item.context)
		check(Module.json_bytes(result)==Module.json_bytes(repeated),"seed and source reproduce exact worker output "+kind)
		var staged := Jobs.stage_from_job(result,"detail-"+kind.replace("_","-"),"Independent bounded detail fixture")
		check(staged.ok and staged.stage.input_snapshot_sha256==item.context.source_sha256 and staged.stage.input_generation==1,"worker stage pins exact source and generation "+kind)
		var preview := Compiler.compile(staged.stage,stage_context(item.context))
		check(preview.ok,"ordinary native StagePlan admits typed result "+kind+" "+str(preview.get("reason","")))
		if not preview.ok: continue
		check(preview.budget.checked_cells==result.budget.unique_cells,"host independently recalculates worker change budget "+kind)
		var safe := true; var unique := {}; var region := Module.rect(item.params.region)
		for pair: Array in result.operations[0].points:
			var point := Vector2i(int(pair[0]),int(pair[1])); unique[point]=true
			if not region.has_point(point) or Module._in_regions(point,item.context.protected+item.context.clearances+item.context.fixed_regions) or pair in item.context.attachment_cells: safe=false
			var prior := before.decode_u16((point.y*64+point.x)*2)
			if kind=="edge_wear":
				if prior!=58 or not Module._in_regions(point,item.context.variable_regions): safe=false
			elif prior!=0: safe=false
		check(safe and unique.size()==result.budget.unique_cells,"independent cell permission/scope/attachment oracle "+kind)
		check(Topology.components(preview.projected_cells,Vector2i(64,64))==Topology.components(before,Vector2i(64,64)),"source-connected material topology preserved in fixture "+kind)
		var changed := result.duplicate(true); changed.operations[0].points.append([1,1])
		check(not Jobs.stage_from_job(changed,"tampered-worker","Changed proposal").ok,"typed output cannot change unnoticed before stage handoff "+kind)
	_test_refusals()
	_test_independent_controls()
	print("NATIVE_DETAIL_JOBS_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"scope":"Pure typed workers and independent exact geometry/guard oracles; native application is separately qualified."}))
	quit(0 if failures.is_empty() else 1)

func _test_refusals() -> void:
	var item := fixture("contextual_ribs")
	check(not Jobs.compile_job("arbitrary-python",item.params,item.context).ok,"unknown executable tool refuses")
	var params: Dictionary = item.params.duplicate(true); params["script"]="return World.paint()"
	check(not Jobs.compile_job(item.kind,params,item.context).ok,"executable/code fields never enter typed registry")
	params=item.params.duplicate(true); params.seed=0.5
	check(not Jobs.compile_job(item.kind,params,item.context).ok,"fractional seed refuses")
	params=item.params.duplicate(true); params.max_cells=1025
	check(not Jobs.compile_job(item.kind,params,item.context).ok,"worker cannot expand host resource permission")
	params=item.params.duplicate(true); params.material=13
	check(not Jobs.compile_job(item.kind,params,item.context).ok,"worker cannot expand host material permission")
	params=item.params.duplicate(true); params.region=[0,0,129,8]
	check(not Jobs.compile_job(item.kind,params,item.context).ok,"oversized/out-of-inspection job refuses")
	params=item.params.duplicate(true); params.region=[-1,8,48,40]
	check(not Jobs.compile_job(item.kind,params,item.context).ok,"negative native job region refuses")
	var host: Dictionary=item.context.duplicate(true); host.source_sha256="0".repeat(64)
	check(not Jobs.compile_job(item.kind,item.params,host).ok,"tampered source digest refuses")
	host=item.context.duplicate(true); host.protected=[[8,8,48,40]]
	check(not Jobs.compile_job(item.kind,item.params,host).ok,"completely protected job refuses without clipping a frame")
	host=item.context.duplicate(true); host.clearances=[[4,4,4,4]]
	check(not Jobs.compile_job(item.kind,item.params,host).ok,"already occupied declared clearance refuses")
	host=item.context.duplicate(true); host.clearances=[[60,60,8,8]]
	check(not Jobs.compile_job(item.kind,item.params,host).ok,"uninspected declared clearance refuses")
	host=item.context.duplicate(true); host.region=[2147483600,0,64,64]
	check(not Jobs.compile_job(item.kind,item.params,host).ok,"integer-overflow World origin refuses")
	item=fixture("short_pipe"); params=item.params.duplicate(true); params.waypoints=[[8,20],[20,21],[20,47]]
	check(not Jobs.compile_job(item.kind,params,item.context).ok,"diagonal service route is not silently rasterized")
	params=item.params.duplicate(true); params.waypoints[0]=[10,20]
	check(not Jobs.compile_job(item.kind,params,item.context).ok,"unanchored endpoint refuses")
	params=item.params.duplicate(true); params.waypoints=[[8,20],[8,20]]
	check(not Jobs.compile_job(item.kind,params,item.context).ok,"zero-length pipe segment refuses")
	item=fixture("framed_opening"); host=item.context.duplicate(true); host.source_cells=item.context.source_cells.duplicate(); host.source_cells.encode_u16((20*64+20)*2,58); host.source_sha256=Module.digest(host.source_cells)
	check(not Jobs.compile_job(item.kind,item.params,host).ok,"frame cannot erase observed blocked passage")
	params=item.params.duplicate(true); params.max_cells=3
	check(not Jobs.compile_job(item.kind,params,item.context).ok,"whole-frame budget refuses partial geometry")
	item=fixture("edge_wear"); host=item.context.duplicate(true); host.variable_regions=[]
	check(not Jobs.compile_job(item.kind,item.params,host).ok,"damage needs explicit noncritical variable geometry")
	host=item.context.duplicate(true); host.source_cells=item.context.source_cells.duplicate(); _fill(host.source_cells,Rect2i(8,40,16,8),28); host.source_sha256=Module.digest(host.source_cells)
	check(not Jobs.compile_job(item.kind,item.params,host).ok,"damage cannot bypass Metal source erasure refusal")
	host=item.context.duplicate(true); host.source_cells=PackedByteArray(); host.source_cells.resize(64*64*2); _fill(host.source_cells,Rect2i(9,10,3,1),58)
	host.source_sha256=Module.digest(host.source_cells); host.clearances=[]; host.fixed_regions=[]; host.attachment_cells=[]; host.variable_regions=[[10,10,1,1]]
	params={"region":[9,9,3,3],"material":0,"amount":1,"max_cells":1,"seed":0}
	check(not Jobs.compile_job("edge_wear",params,host).ok,"damage does not sever a one-cell bridge")
	var empty := PackedByteArray(); empty.resize(512*512*2)
	host={"region":[0,0,512,512],"source_cells":empty,"source_sha256":Module.digest(empty),"allowed_materials":[28],"max_cells":512,"clearances":[]}
	for i: int in 5: host.clearances.append([0,0,512,512])
	var exhausted := Jobs.compile_job("contextual_ribs",{"region":[8,8,32,32]},host)
	check(not exhausted.ok and exhausted.status=="exhausted","finite scan exhaustion remains explicit")

func _test_independent_controls() -> void:
	var item := fixture("anchored_clutter",19)
	var baseline := Jobs.compile_job(item.kind,item.params,item.context)
	var params: Dictionary=item.params.duplicate(true); params.width=1
	var geometry := Jobs.compile_job(item.kind,params,item.context)
	check(baseline.ok and geometry.ok and baseline.operations!=geometry.operations,"geometry width independently changes emitted native proposal")
	params=item.params.duplicate(true); params.irregularity=0
	var irregular := Jobs.compile_job(item.kind,params,item.context)
	check(irregular.ok and irregular.operations!=baseline.operations,"irregularity independently changes anchored cluster depth")
	params=item.params.duplicate(true); params.density=0.2
	var sparse := Jobs.compile_job(item.kind,params,item.context)
	check(sparse.ok and sparse.budget.unique_cells<baseline.budget.unique_cells,"clutter density independently lowers emitted local detail")
	item=fixture("edge_wear",19); baseline=Jobs.compile_job(item.kind,item.params,item.context)
	params=item.params.duplicate(true); params.amount=3
	var wear := Jobs.compile_job(item.kind,params,item.context)
	check(wear.ok and wear.budget.unique_cells==3 and baseline.budget.unique_cells>3,"damage amount independently bounds noncritical removal")
