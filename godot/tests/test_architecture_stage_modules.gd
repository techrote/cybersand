extends SceneTree
## Independent compiler adversaries. Synthetic planes are explicitly fixtures;
## only the separate native integration harness can qualify their application.
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const Parts = preload("res://scripts/batch_lab/native_module_examples.gd")
const Compositions = preload("res://scripts/batch_lab/architecture_module_compositions.gd")
const ArtPlan = preload("res://scripts/art_batch_plan.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> bool:
	checks += 1
	print("ARCHITECTURE_STAGE_MODULE_CHECK ",label," ",condition)
	if not condition: failures.append(label); push_error(label)
	return condition

func context(region := Rect2i(0,0,64,64)) -> Dictionary:
	var cells := PackedByteArray()
	cells.resize(region.get_area()*2)
	return {"source_cells":cells,"source_sha256":Compiler.digest(cells),"region":Compiler.rect_array(region),
		"world_region":[0,0,512,512],"generation":1,"paused":true,"allowed_materials":[0,7,13,28,58]}

func stage() -> Dictionary:
	var output := Compiler.stage_defaults("module-fixture",Rect2i(0,0,64,64))
	output.materials = [0,7,13,28,58]
	return output

func connector(identity: String, kind: String, point: Array, facing: Array) -> Dictionary:
	return {"id":identity,"kind":kind,"point":point,"facing":facing,"compatibility":["support"],"required":true,"source":"authored"}

func fixture(identity: String, cells: PackedByteArray, metadata: Dictionary) -> Dictionary:
	var details := metadata.duplicate(true)
	details["id"] = identity
	details["name"] = identity
	details["allowed_transforms"] = ["identity","mirror_x","rotate_90"]
	details["provenance"] = {"kind":"synthetic-compiler-test-plane","native_construction_status":"not-executed"}
	var harvested := Module.harvest(cells,Vector2i(4,4),Rect2i(0,0,4,4),details)
	check(harvested.ok,"fixture manifest validates "+identity+" / "+str(harvested.get("reason","")))
	return harvested.get("module",{})

func selected(module: Dictionary, origin: Array, transform := "identity", palette: Dictionary = {}) -> Dictionary:
	return {"module_id":module.id,"module_sha256":module.content_sha256,
		"placement":{"origin":origin,"transform":transform,"palette":palette}}

func compile_parts(library: RefCounted, placements: Array, baseline: Dictionary = {}) -> Dictionary:
	var proposal := stage()
	proposal.modules = placements
	return Compiler.compile(proposal,context() if baseline.is_empty() else baseline,library)

func _initialize() -> void:
	var solid := PackedByteArray()
	solid.resize(32)
	for i: int in 16: solid.encode_u16(i*2,58)
	var left := fixture("socket",solid,{"attachments":[connector("mount","socket",[3,1],[1,0])]})
	var right := fixture("receptor",solid,{"attachments":[connector("anchor","receptor",[0,1],[-1,0])]})
	var library := Library.new()
	check(library.add(left).ok and library.add(right).ok,"independent paired module fixtures admitted")
	var good := [selected(left,[8,8]),selected(right,[12,8])]
	var source := context()
	var original: PackedByteArray = source.source_cells.duplicate()
	var paired := compile_parts(library,good,source)
	check(paired.ok and paired.module_connections.size()==2,"opposite-facing occupied required endpoints compile")
	check(source.source_cells==original,"required attachment verification is zero-write")
	var named:=good.duplicate(true)
	named[0]["instance_id"]="legacy-named-socket"
	named[1]["instance_id"]="legacy-named-receptor"
	check(compile_parts(library,named,source).ok,"explicit v1 instance names preserve legacy attachment interpretation")
	var occupied_names:=source.duplicate(true); occupied_names["live_module_instances"]=["legacy-named-socket"]
	check(not compile_parts(library,named,occupied_names).ok,"v1 explicit names cannot alias an earlier live part's detail scope")
	check(compile_parts(library,good,occupied_names).ok,"v1 implicit stage-local integer identities retain their original meaning")
	check(not compile_parts(library,[good[0]]).ok,"unpaired required socket refuses")
	check(not compile_parts(library,[good[0],selected(right,[13,8])]).ok,"one-cell gap cannot satisfy a structural attachment")
	check(not compile_parts(library,[good[0],selected(right,[12,9])]).ok,"diagonal endpoints cannot satisfy a structural attachment")
	check(compile_parts(library,[selected(left,[12,8],"mirror_x"),selected(right,[8,8],"mirror_x")]).ok,"mirrored point and facing transform together")
	var wrong := right.duplicate(true)
	wrong.id = "wrong-kind"
	wrong.attachments[0].kind = "socket"
	wrong.content_sha256 = Module.content_digest(wrong)
	check(library.add(wrong).ok and not compile_parts(library,[good[0],selected(wrong,[12,8])]).ok,"socket cannot masquerade as complementary receptor")
	wrong = right.duplicate(true)
	wrong.id = "wrong-tag"
	wrong.attachments[0].compatibility = ["pipe"]
	wrong.content_sha256 = Module.content_digest(wrong)
	check(library.add(wrong).ok and not compile_parts(library,[good[0],selected(wrong,[12,8])]).ok,"unrelated authored interface tags refuse")
	var empty_tip := solid.duplicate()
	empty_tip.encode_u16((1*4+3)*2,0)
	var floating := fixture("floating-socket",empty_tip,{"attachments":[connector("mount","socket",[3,1],[1,0])]})
	check(library.add(floating).ok and not compile_parts(library,[selected(floating,[8,8]),good[1]]).ok,"required endpoint on Empty geometry cannot claim native attachment")
	empty_tip = solid.duplicate()
	empty_tip.encode_u16((1*4)*2,0)
	var empty_partner := fixture("floating-receptor",empty_tip,{"attachments":[connector("anchor","receptor",[0,1],[-1,0])]})
	check(library.add(empty_partner).ok and not compile_parts(library,[good[0],selected(empty_partner,[12,8])]).ok,"Empty partner cannot ground a required socket")
	var line := connector("line","line",[3,0],[1,0])
	line["end"] = [3,3]
	var lined := fixture("required-line",solid,{"attachments":[line]})
	check(library.add(lined).ok and not compile_parts(library,[selected(lined,[8,8]),good[1]]).ok,"unsupported required attachment line refuses explicitly")
	var half := PackedByteArray()
	half.resize(32)
	for y: int in 4:
		for x: int in 2: half.encode_u16((y*4+x)*2,58)
	var guarded := fixture("guarded",half,{"protected_regions":[[2,0,2,4]],"clearances":[[2,0,2,4]]})
	check(library.add(guarded).ok,"protected module fixture admitted")
	var protected_preview := compile_parts(library,[selected(guarded,[8,8])])
	check(protected_preview.ok and protected_preview.new_protected_regions==[[10,8,2,4]],"module protection is transformed and retained by stage host")
	var proposal := stage()
	proposal.modules = [selected(guarded,[8,8])]
	proposal.operations = [{"shape":"rectangle","x0":10,"y0":8,"x1":10,"y1":8,"material":58}]
	check(not Compiler.compile(proposal,source,library).ok,"later direct operation cannot overwrite module protection")
	proposal.modules = [selected(guarded,[8,8],"mirror_x")]
	proposal.operations[0].x0 = 8; proposal.operations[0].x1 = 8
	check(not Compiler.compile(proposal,source,library).ok,"mirrored protection is enforced in world coordinates")
	var fill := fixture("fill",solid,{})
	check(library.add(fill).ok and not compile_parts(library,[selected(guarded,[8,8]),selected(fill,[10,8])]).ok,"second module cannot overwrite first module protection")
	var obstructed := context()
	obstructed.source_cells.encode_u16((8*64+10)*2,13)
	obstructed.source_sha256 = Compiler.digest(obstructed.source_cells)
	check(not compile_parts(library,[selected(guarded,[8,8])],obstructed).ok,"transparent Empty never clears an occupied required passage")
	var retained_guard := fixture("retained-guard",half,{"protected_regions":[[2,0,2,4]]})
	check(library.add(retained_guard).ok and compile_parts(library,[selected(retained_guard,[8,8])],obstructed).ok,"nonclearance protection preserves existing stored material without painting it")
	var role_module := fixture("palette",solid,{"roles":[{"name":"structure","material_ids":[58],"compatible_materials":[58,7,28],"source":"authored"}]})
	check(library.add(role_module).ok,"explicit palette fixture admitted")
	var palette := compile_parts(library,[selected(role_module,[8,8],"identity",{"structure":7})])
	check(palette.ok and palette.projected_cells.decode_u16((8*64+8)*2)==7,"declared Wood destination is compiled through explicit role")
	check(not compile_parts(library,[selected(role_module,[8,8],"identity",{"structure":13})]).ok,"unlisted palette destination cannot bypass module role")
	var occupied := context()
	occupied.source_cells.encode_u16((8*64+8)*2,28)
	occupied.source_sha256 = Compiler.digest(occupied.source_cells)
	check(not compile_parts(library,[selected(role_module,[8,8])],occupied).ok,"stage cannot replace existing Metal because it appears in destination allowlist")
	check(compile_parts(library,[selected(role_module,[8,8],"identity",{"structure":28})],occupied).ok,"matching stored Metal is retained while other Empty cells are filled")
	var tampered := selected(role_module,[8,8])
	tampered.module_sha256 = "0".repeat(64)
	check(not compile_parts(library,[tampered]).ok,"composition pins exact module manifest identity")
	check(source.source_cells==original,"all failing module adversaries retain caller native plane")
	_test_compositions()
	print("ARCHITECTURE_STAGE_MODULE_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"scope":"Independent pure compiler fixtures, no native execution or architectural preference claim."}))
	quit(0 if failures.is_empty() else 1)

func _test_compositions() -> void:
	var library := Library.new()
	check(Compositions.plans(library).is_empty(),"missing harvested identities refuse module composition factory")
	for recipe: Dictionary in Parts.recipes():
		var raster := ArtPlan.new()
		if not check(raster.configure(recipe.operations,Rect2i(0,0,64,64)),"fixture source recipe rasterizes "+recipe.id): continue
		var cells := PackedByteArray()
		cells.resize(64*64*2)
		while not raster.exhausted():
			var chunk: Dictionary = raster.next_chunk(4096)
			if chunk.is_empty(): continue
			for i: int in range(0,chunk.points.size(),2):
				cells.encode_u16((int(chunk.points[i+1])*64+int(chunk.points[i]))*2,int(chunk.material))
		var metadata: Dictionary = recipe.metadata.duplicate(true)
		metadata.provenance = {"kind":"synthetic-compiler-test-plane","native_construction_status":"not-executed"}
		var value := Module.harvest(cells,Vector2i(64,64),Module.rect(recipe.harvest_region),metadata)
		check(value.ok and library.add(value.module).ok,"composition fixture manifest admitted "+recipe.id)
		check(value.ok and face_components(value.cells,value.extent)==1,"starter part geometry has face-connected structural contact "+recipe.id)
	check(library.summaries().all(func(value: Dictionary) -> bool: return not value.native_readback_verified),"synthetic composition fixtures remain unqualified for native retrieval")
	var examples := Compositions.plans(library)
	check(examples.size()==3,"three distinct module composition plans available")
	for recipe: Dictionary in examples:
		check(Compiler.validate_plan(recipe).ok,"finite typed module plan "+recipe.id)
		var baseline := context(Compiler.rect(recipe.stages[0].region))
		var completed: Array = []
		var total_instances := 0
		for item: Dictionary in recipe.stages:
			check(item.operations.is_empty() and not item.modules.is_empty(),"composition stage exclusively reuses modules "+item.id)
			total_instances += item.modules.size()
			var compiled := Compiler.compile(item,baseline,library,completed)
			if not check(compiled.ok,"sequential exact module projection "+item.id+" / "+str(compiled.get("reason",""))): break
			check(compiled.zero_writes and compiled.budget.changed_cells>0,"composition host computes bounded positive native effects "+item.id)
			baseline.source_cells = compiled.projected_cells.duplicate()
			baseline.source_sha256 = compiled.projected_sha256
			baseline.generation += 1
			completed.append(item.id)
		check(completed.size()==3 and total_instances>=30,"complete multi-scale repeated module composition "+recipe.id)
		check(face_components(baseline.source_cells,Compiler.rect(baseline.region).size)==1,"all primary module geometry forms one face-connected assembly "+recipe.id)

func face_components(cells: PackedByteArray, size: Vector2i) -> int:
	var visited := PackedByteArray()
	visited.resize(size.x*size.y)
	var components := 0
	for start: int in size.x*size.y:
		if visited[start]!=0 or cells.decode_u16(start*2)==0: continue
		components += 1
		var pending: Array[int] = [start]
		visited[start] = 1
		while not pending.is_empty():
			var at: int = pending.pop_back()
			var point := Vector2i(at%size.x,at/size.x)
			for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next := point+step
				if next.x<0 or next.y<0 or next.x>=size.x or next.y>=size.y: continue
				var index := next.y*size.x+next.x
				if visited[index]==0 and cells.decode_u16(index*2)!=0:
					visited[index] = 1; pending.append(index)
	return components
