extends SceneTree
## Independent endpoint, exact guard coverage and host handoff adversaries.
const Jobs=preload("res://scripts/batch_lab/native_detail_jobs.gd")
const Module=preload("res://scripts/batch_lab/native_module.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Fixtures=preload("res://tests/test_native_detail_jobs.gd")
const Topology=preload("res://tests/test_native_module_catalogue.gd")
var checks:=0
var failures: Array[String]=[]

func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)

func pipe_fixture(vertical:=false) -> Dictionary:
	var cells:=PackedByteArray(); cells.resize(64*64*2)
	var attachments: Array=[]
	for axis: int in [11,28]:
		for band: int in range(20,24):
			var point:=Vector2i(band,axis) if vertical else Vector2i(axis,band)
			cells.encode_u16((point.y*64+point.x)*2,28); attachments.append([point.x,point.y])
	return {"region":[0,0,64,64],"source_cells":cells,"source_sha256":Module.digest(cells),"generation":1,
		"allowed_materials":[28],"max_cells":128,"protected":[],"clearances":[],"fixed_regions":[],"variable_regions":[],"attachment_cells":attachments}

func _initialize() -> void:
	for vertical: bool in [false,true]:
		for reversed: bool in [false,true]:
			for width: int in range(1,5):
				var host:=pipe_fixture(vertical)
				var route: Array=[[21,12],[21,27]] if vertical else [[12,21],[27,21]]
				if reversed: route.reverse()
				var params:={"region":[20,12,4,16] if vertical else [12,20,16,4],"material":28,"width":width,"max_cells":128,"waypoints":route}
				var job:=Jobs.compile_job("short_pipe",params,host)
				var name:="width"+str(width)+(" vertical" if vertical else " horizontal")+(" reversed" if reversed else " forward")
				check(job.ok,"opposed observed four-cell native faces admit "+name+" "+str(job.get("reason","")))
				if not job.ok: continue
				var expected: Dictionary={}; var shift: int=(width-1)/2
				for axis: int in range(12,28):
					for band: int in range(21-shift,21-shift+width): expected[Vector2i(band,axis) if vertical else Vector2i(axis,band)]=true
				var actual: Dictionary={}
				for raw: Array in job.operations[0].points: actual[Vector2i(raw[0],raw[1])]=true
				check(actual==expected and job.budget.unique_cells==16*width and job.connections.size()==width*2,"exact butt-capped band and every terminal source contact "+name)
				var stage:=Jobs.stage_from_job(job,"pipe-contract","Exact width-bearing service connection")
				var preview:=Compiler.compile(stage.stage,Fixtures.stage_context(host))
				check(preview.ok and Topology.components(preview.projected_cells,Vector2i(64,64))==1,"host joins both native face components without painting either source "+name)
	_test_pipe_refusals()
	_test_exact_guards()
	print("NATIVE_DETAIL_CONTRACTS_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _test_pipe_refusals() -> void:
	var host:=pipe_fixture()
	var params:={"region":[12,20,16,4],"material":28,"width":4,"max_cells":128,"waypoints":[[12,21],[27,21]]}
	var changed:=host.duplicate(true); changed.source_cells=host.source_cells.duplicate()
	changed.source_cells.encode_u16((21*64+20)*2,58); changed.source_sha256=Module.digest(changed.source_cells)
	check(not Jobs.compile_job("short_pipe",params,changed).ok,"unrelated occupied mid-route cell refuses without implicit clipping")
	changed=host.duplicate(true); changed.source_cells=host.source_cells.duplicate()
	changed.source_cells.encode_u16((20*64+11)*2,0); changed.source_sha256=Module.digest(changed.source_cells)
	check(not Jobs.compile_job("short_pipe",params,changed).ok,"missing transverse source face cell refuses width4 endpoint")
	changed=host.duplicate(true); changed.protected=[[12,20,1,4]]
	check(not Jobs.compile_job("short_pipe",params,changed).ok,"protected first emitted pipe band refuses")
	changed=host.duplicate(true); changed.attachment_cells.append([20,21])
	check(not Jobs.compile_job("short_pipe",params,changed).ok,"attachment cell in route remains prohibited")
	var cells:=PackedByteArray(); cells.resize(64*64*2)
	for y: int in range(20,24): cells.encode_u16((y*64+11)*2,28)
	for x: int in range(28,32): cells.encode_u16((40*64+x)*2,28)
	host.source_cells=cells; host.source_sha256=Module.digest(cells); host.attachment_cells=[]; host.max_cells=256
	params={"region":[12,20,20,20],"material":28,"width":4,"max_cells":256,"waypoints":[[12,21],[29,21],[29,39]]}
	var elbow:=Jobs.compile_job("short_pipe",params,host)
	check(elbow.ok,"width4 orthogonal elbow joins opposed axial source faces")
	if elbow.ok:
		var stage:=Jobs.stage_from_job(elbow,"pipe-elbow","Exact square interior elbow")
		var preview:=Compiler.compile(stage.stage,Fixtures.stage_context(host))
		check(preview.ok and Topology.components(preview.projected_cells,Vector2i(64,64))==1,"width4 interior elbow remains a single connected native proposal")

func _test_exact_guards() -> void:
	var sparse: Array=[[10,10],[11,10],[10,11],[10,10]]
	var rectangles:=Jobs._attachment_guards(sparse,Rect2i(0,0,64,64),[])
	var exact:=true
	for y: int in 64:
		for x: int in 64:
			if Module._in_regions(Vector2i(x,y),rectangles)!=([x,y] in sparse): exact=false
	check(exact and rectangles.size()==2,"sparse L guard preserves its empty aperture and deduplicates points")
	var dense: Array=[]
	for y: int in range(24,36):
		for x: int in range(12,32): dense.append([x,y])
	check(Jobs._attachment_guards(dense,Rect2i(0,0,64,64),[])==[[12,24,20,12]],"identical adjacent row runs compact to one exact rectangle")
	check(Jobs._attachment_guards([[11,10],[20,20]],Rect2i(0,0,16,16),[[10,10,2,2]]).is_empty(),"already guarded and uninspected immutable points need no broadened stage guards")
	var item:=Fixtures.fixture("edge_wear")
	var job:=Jobs.compile_job("edge_wear",item.params,item.context)
	check(job.ok and Module._in_regions(Vector2i(23,47),job.guard_scopes),"worker handoff carries explicit source attachment into native protection")
	var stage:=Jobs.stage_from_job(job,"wear-guard-adversary","Host independently preserves source contact")
	stage.stage.operations[0].points.append([23,47])
	check(not Compiler.compile(stage.stage,Fixtures.stage_context(item.context)).ok,"native stage compiler independently refuses injected connector erasure")
	item=Fixtures.fixture("contextual_ribs")
	for index: int in 65: item.context.attachment_cells.append([10+(index%13)*2,16+(index/13)*2])
	var refused:=Jobs.compile_job(item.kind,item.params,item.context)
	check(not refused.ok and refused.code=="stage_scope_budget","fragmented exact contact scope refuses instead of widening its holes")
	item=Fixtures.fixture("contextual_ribs"); item.context["native_protected_region_count"]=64
	refused=Jobs.compile_job(item.kind,item.params,item.context)
	check(not refused.ok and refused.code=="stage_scope_budget","combined retained host and emitted stage protection ceiling is enforced")
