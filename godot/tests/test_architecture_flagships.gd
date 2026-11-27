extends SceneTree
## Development compilation pilot. These projections are explicitly not native
## readbacks; the independent native campaign must construct the same recipes.
const Flagships=preload("res://scripts/batch_lab/architecture_flagships.gd")
const Catalogue=preload("res://scripts/batch_lab/native_module_catalogue.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
var checks:=0
var failures:=0

func check(value: bool,label: String) -> bool:
	checks+=1; print("FLAGSHIP_PLAN_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)
	return value

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var templates:=Catalogue.template_library()
	if not check(templates.ok,"forty exact source templates load without native flags"): quit(1); return
	var evidence:=OS.get_environment("FLAGSHIP_PLAN_EVIDENCE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	for family: String in Flagships.families():
		var built:=Flagships.build(family,templates.library)
		if not check(built.ok,"finite flagship "+family+" / "+str(built.get("reason",""))): continue
		var size:=Flagships.extent(family)
		var world:=PackedByteArray(); world.resize(size.x*size.y*2)
		var complete: Array=[]; var good:=true
		for stage: Dictionary in built.plan.stages:
			var region:=Compiler.rect(stage.region)
			var source:=PackedByteArray(); source.resize(region.get_area()*2)
			for y: int in region.size.y:
				var offset:=((region.position.y+y)*size.x+region.position.x)*2
				for x: int in region.size.x: source.encode_u16((y*region.size.x+x)*2,world.decode_u16(offset+x*2))
			var context:={"source_cells":source,"source_sha256":Compiler.digest(source),"region":stage.region,"world_region":[0,0,size.x,size.y],
				"generation":1,"paused":true,"allowed_materials":[0,7,28,58]}
			var result:=Compiler.compile(stage,context,templates.library,complete)
			if not check(result.ok,stage.id+" / "+str(result.get("reason",""))): good=false; break
			for y: int in region.size.y:
				for x: int in region.size.x:
					world.encode_u16(((region.position.y+y)*size.x+region.position.x+x)*2,result.projected_cells.decode_u16((y*region.size.x+x)*2))
			complete.append(stage.id)
			await process_frame
		if not good: continue
		check(complete.size()==built.plan.stages.size(),"complete finite projection "+family)
		for raw: Array in Flagships.clearances(family):
			var area:=Compiler.rect(raw); var empty:=true
			for y: int in range(area.position.y,area.end.y):
				for x: int in range(area.position.x,area.end.x):
					if world.decode_u16((y*size.x+x)*2)!=0: empty=false; break
			check(empty,"independent global macro-void oracle "+family+" "+str(raw))
		if not evidence.is_empty():
			var file:=FileAccess.open(evidence.path_join(family+"-projection.u16le"),FileAccess.WRITE); file.store_buffer(world); file.close()
			file=FileAccess.open(evidence.path_join(family+"-campaign.json"),FileAccess.WRITE); file.store_string(Compiler.canonical(built.campaign)); file.close()
			file=FileAccess.open(evidence.path_join(family+"-projection.json"),FileAccess.WRITE)
			file.store_string(Compiler.canonical({"family":family,"extent":[size.x,size.y],"sha256":Compiler.digest(world),"scope":"Development zero-write compiler projection; not native construction evidence."})); file.close()
	print("ARCHITECTURE_FLAGSHIP_PLANS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
