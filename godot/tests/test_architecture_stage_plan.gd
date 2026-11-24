extends SceneTree
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Examples = preload("res://scripts/batch_lab/architecture_examples.gd")
const Retrieval = preload("res://scripts/batch_lab/architectural_retrieval.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	print("ARCHITECTURE_PLAN_CHECK ",label," ",value)
	if not value: failures += 1; push_error(label)

func context() -> Dictionary:
	var cells := PackedByteArray()
	cells.resize(64*64*2)
	return {"source_cells":cells,"source_sha256":Compiler.digest(cells),"region":[100,100,64,64],
		"world_region":[0,0,512,512],"generation":1,"paused":true,"allowed_materials":[0,58,28]}

func stage() -> Dictionary:
	var value := Compiler.stage_defaults("floor",Rect2i(100,100,64,64))
	value.materials = [0,58,28]
	value.operations = [{"shape":"rectangle","x0":104,"y0":150,"x1":159,"y1":153,"material":58}]
	value.budget.max_checked_cells = 224
	value.clearances = [[104,140,56,10]]
	return value

func _initialize() -> void:
	var baseline := context()
	var initial: PackedByteArray = baseline.source_cells.duplicate()
	var first: Dictionary = Compiler.compile(stage(),baseline)
	check(first.ok,"valid typed structural stage compiles")
	if first.ok:
		check(first.zero_writes and first.kind=="zero-write-compilation","preview is explicitly a zero-write projection")
		check(first.budget.checked_cells==224 and first.budget.unique_cells==224 and first.budget.changed_cells==224,"host calculates all material counts")
		check(first.footprint==[104,150,56,4],"host calculates exact nonzero-origin footprint")
		check(baseline.source_cells==initial,"compiler never mutates caller native inspection")
		var exact := true
		for y: int in 64:
			for x: int in 64:
				var expected := 58 if x>=4 and x<60 and y>=50 and y<54 else 0
				if first.projected_cells.decode_u16((y*64+x)*2)!=expected: exact = false
		check(exact,"independent complete 4096-cell rectangle oracle")
	var modified := stage()
	modified.input_snapshot_sha256=baseline.source_sha256
	modified.input_generation=baseline.generation
	check(Compiler.compile(modified,baseline).ok,"delegated worker output compiles against its exact inspected source and World generation")
	var worker_source:=context()
	worker_source.source_cells.encode_u16(0,58)
	worker_source.source_sha256=Compiler.digest(worker_source.source_cells)
	check(not Compiler.compile(modified,worker_source).ok,"an unrelated in-region edit invalidates delegated output before preview")
	worker_source=context(); worker_source.generation=2
	check(not Compiler.compile(modified,worker_source).ok,"identical geometry in a replacement World does not reuse a delegated job")
	modified.input_snapshot_sha256=22
	check(not Compiler.compile(modified,baseline).ok,"non-text delegated source identity is refused without a parser exception")
	modified=stage(); modified.input_generation=baseline.generation
	check(not Compiler.compile(modified,baseline).ok,"generation-only worker metadata cannot claim a complete source pin")
	modified=stage(); modified.input_snapshot_sha256=baseline.source_sha256; modified.input_generation=1.5
	check(not Compiler.compile(modified,baseline).ok,"fractional worker generation is refused")
	modified=stage(); modified.input_snapshot_sha256=baseline.source_sha256
	check(Compiler.compile(modified,baseline).ok,"historical copied source may pin bytes without asserting a live generation")
	modified = stage()
	modified.budget.max_checked_cells = 223
	modified.budget.estimated_cells = 1
	check(not Compiler.compile(modified,baseline).ok,"model-estimated counts cannot bypass exact native budget")
	modified = stage()
	modified.operations.append(modified.operations[0].duplicate())
	modified.budget.max_checked_cells = 448
	var repeated: Dictionary = Compiler.compile(modified,baseline)
	check(repeated.ok and repeated.budget.checked_cells==224 and repeated.budget.emitted_input_points==448 and repeated.budget.conservative_scan_bound==448 and repeated.budget.unique_cells==224,"overlapping inputs normalize to exact native work while retaining raster cost")
	modified = stage()
	modified.operations[0].x0 = 99
	check(not Compiler.compile(modified,baseline).ok,"in-world footprint outside stage region is refused")
	modified = stage()
	modified.protected = [[110,150,1,1]]
	check(not Compiler.compile(modified,baseline).ok,"one protected intersecting cell refuses the complete proposal")
	modified.protected = [[110,149,1,1]]
	check(Compiler.compile(modified,baseline).ok,"adjacent protection boundary is not widened")
	modified = stage()
	modified.clearances = [[110,150,1,1]]
	check(not Compiler.compile(modified,baseline).ok,"occupied clearance refuses before construction")
	modified = stage()
	modified.depends_on = ["missing"]
	check(not Compiler.compile(modified,baseline).ok,"dependency needs completed native stage evidence")
	check(Compiler.compile(modified,baseline,null,["missing"]).ok,"explicit completed dependency unlocks compilation")
	modified = stage()
	modified.connections = [{"kind":"solid-contact","a":[110,150],"b":[111,150]}]
	check(Compiler.compile(modified,baseline).ok,"orthogonal structural contact checks actual projected cells")
	modified.connections[0].b = [111,149]
	check(not Compiler.compile(modified,baseline).ok,"diagonal or remote endpoints cannot claim a contact")
	modified.connections = [{"kind":"empty-contact","a":[110,149],"b":[110,150]}]
	check(not Compiler.compile(modified,baseline).ok,"blocked passage contact is refused")
	var altered := context()
	altered.source_cells.encode_u16((50*64+10)*2,2)
	altered.source_sha256 = Compiler.digest(altered.source_cells)
	check(not Compiler.compile(stage(),altered).ok,"out-of-permission native source material is protected")
	altered = context()
	altered.source_sha256 = "false"
	check(not Compiler.compile(stage(),altered).ok,"unbound material inspection is rejected")
	altered = context()
	altered.paused = false
	check(not Compiler.compile(stage(),altered).ok,"live simulation cannot be labelled a static preview")
	modified = stage()
	modified.materials.append(65535)
	check(not Compiler.compile(modified,baseline).ok,"unknown destination material is refused")
	modified = stage()
	modified.operations = []
	for i: int in 280:
		modified.operations.append({"shape":"airbrush","x":131,"y":131,"radius":31,"density":0.00001,"material":58})
	check(not Compiler.compile(modified,baseline).ok,"low-density work cannot hide rejected samples from conservative scan budget")
	var plan := {"format":Compiler.FORMAT,"id":"test","intent":"Finite architectural test","stages":[stage()]}
	check(Compiler.validate_plan(plan).ok,"finite plan validates")
	var reopened: Variant = JSON.parse_string(Compiler.canonical(plan))
	check(Compiler.digest(Compiler.canonical(reopened).to_utf8_buffer())==Compiler.digest(Compiler.canonical(plan).to_utf8_buffer()),"JSON reopening preserves exact plan identity")
	plan.stages.append(stage())
	check(not Compiler.validate_plan(plan).ok,"duplicate stage identity is refused")
	plan.stages[1].id = "ceiling"
	plan.stages[0].depends_on = ["ceiling"]
	check(not Compiler.validate_plan(plan).ok,"forward dependency and cycle are refused")
	var corpus: Dictionary=Retrieval.load_default_corpus()
	var card_ids: Array=[]
	if corpus.get("ok",false):
		for card: Dictionary in corpus.corpus.cards: card_ids.append(card.id)
	check(not card_ids.is_empty(),"frozen source-bound design corpus loads for recipe validation")
	for family: String in Examples.families():
		var sample := Examples.plan(family)
		check(Compiler.validate_plan(sample).ok,"finite example plan "+family)
		check(sample.provenance.reference_card_ids.all(func(id: String) -> bool: return id in card_ids),"every example design card resolves to the frozen corpus "+family)
		var size := Examples.extent(family)
		var cells := PackedByteArray()
		cells.resize(size.x*size.y*2)
		var ctx := {"source_cells":cells,"source_sha256":Compiler.digest(cells),"region":[16,16,size.x,size.y],
			"world_region":[0,0,512,512],"generation":1,"paused":true,"allowed_materials":[0,58,28,13,7,19]}
		var completed: Array = []
		for item: Dictionary in sample.stages:
			var built: Dictionary = Compiler.compile(item,ctx,null,completed)
			check(built.ok,"example stage "+item.id+" / "+str(built.get("reason","")))
			if not built.ok: break
			ctx.source_cells = built.projected_cells
			ctx.source_sha256 = built.projected_sha256
			completed.append(item.id)
	print("ARCHITECTURE_STAGE_PLAN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
