extends SceneTree
## Frozen five-arm matched native construction apparatus. No model is called.
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const Retriever = preload("res://scripts/batch_lab/architectural_retrieval.gd")
const Registration := "res://data/batch_lab/architecture_experiment_registration.v1.json"
const REGISTRATION_SHA256 := "aa25936785d542f74fef1183b0ba394b6224d9aebc5cb0459679c863f7a3e028"
const EXTENT := Vector2i(256,192)
const SHAPES := {"industrial_hangar":[6,4],"service_network":[8,3],"organic_cavern":[4,6]}
const PARTS := {"industrial_hangar":"mechanical_housing","service_network":"service_gallery","organic_cavern":"irregular_transition"}
const REFERENCES := {"industrial_hangar":"goldmaps-pr146","service_network":"goldmaps-pr159","organic_cavern":"goldmaps-pr125"}
var controller: Node
var library: RefCounted
var cases: Array = []
var failures: Array[String] = []
var output := ""
var source_commit := ""
var part_evidence: Array = []
var checks := 0

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(condition: bool, label: String) -> bool:
	checks+=1
	print("ARCHITECTURE_COMPARISON_CHECK ",checks," ",label," ",condition)
	if not condition: failures.append(label); push_error(label)
	return condition

func box(x: int, y: int, width: int, height: int, material: int) -> Dictionary:
	return {"shape":"rectangle","x0":x,"y0":y,"x1":x+width-1,"y1":y+height-1,"material":material}

func settle(label: String) -> bool:
	var deadline := Time.get_ticks_msec()+180000
	while controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	if controller.is_running(): controller.stop()
	return check(not controller.is_running(),label)

func run() -> void:
	output = OS.get_environment("ARCHITECTURE_COMPARISON_DIR")
	source_commit = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	if not check(not output.is_empty(),"explicit comparison artifact directory") \
		or not check(source_commit.length()==40 and source_commit.is_valid_hex_number(false),"exact source commit supplied"):
		finish(); return
	DirAccess.make_dir_recursive_absolute(output.path_join("planes"))
	DirAccess.make_dir_recursive_absolute(output.path_join("modules"))
	if not check(FileAccess.get_sha256(Registration)==REGISTRATION_SHA256,"frozen registration identity unchanged"): finish(); return
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Registration))
	var corpus := Retriever.load_default_corpus()
	if not check(corpus.ok,"frozen architectural corpus available"): finish(); return
	library = Library.new()
	controller = Controller.new(); root.add_child(controller); await process_frame
	controller.configure_grid(3,1)
	var families: Array = registration.families
	for i: int in families.size():
		var size: Array = SHAPES[families[i]]
		var config := Controller.defaults()
		config.extent = [64,64]; config.source_region = [0,0,64,64]; config.materials = [0,28,58]
		config.operations = [box(0,0,size[0],size[1],28)]
		check(controller.configure_tile(i,config).ok,"configure native part source "+families[i])
	check(controller.start().ok,"three source parts admitted to native Batch Lab")
	if not await settle("three source parts finish natively"): finish(); return
	for i: int in families.size():
		var family: String = families[i]
		var size: Array = SHAPES[family]
		var tile: Dictionary = controller.tiles[i]
		var metadata := {"id":"comparison-"+family.replace("_","-"),"name":family.replace("_"," ")+" service component",
			"part_type":PARTS[family],"tags":["comparison",family,"service-detail"],"design_card_ids":[REFERENCES[family]],
			"allowed_transforms":["identity"],"roles":[{"name":"service","material_ids":[28],"compatible_materials":[28],"source":"authored"}],
			"attachments":[{"id":"mount","kind":"socket","point":[0,0],"facing":[0,-1],
				"compatibility":["service_mount"],"required":false,"source":"authored"}]}
		var harvested: Dictionary = library.harvest_tile(tile,metadata,Rect2i(0,0,size[0],size[1]))
		if not check(harvested.ok,"harvest actual native part "+family+": "+str(harvested.get("reason",""))): finish(); return
		var module: Dictionary = harvested.module
		check(library.export_module(module.id,output.path_join("modules").path_join(module.id+".json")).ok,"persist native part "+family)
		part_evidence.append({"id":module.id,"content_sha256":module.content_sha256,"geometry_sha256":module.geometry.sha256,
			"native_attempt":Controller._encode(controller._record(tile)),"part_region":[0,0,size[0],size[1]]})
	if not check(library.summaries().all(func(item: Dictionary) -> bool: return item.native_readback_verified),"module retrieval receives only current-process native qualification"):
		finish(); return
	# The registration fixes all context/arms/seeds before any outcome is observed.
	# Native results never change construction rules, random rejection conditions or ranking.
	for family: String in families:
		controller.configure_grid(4,3)
		var pending: Array = []
		for seed_value: Variant in registration.seeds:
			var fixture := family_fixture(family,int(seed_value))
			for arm: String in registration.arms:
				var recipe := case_recipe(family,arm,int(seed_value),fixture,corpus.corpus)
				var identity := "%s-%s-%d" % [family,arm,int(seed_value)]
				var config := Controller.defaults()
				config.extent = [EXTENT.x,EXTENT.y]; config.source_region = [0,0,EXTENT.x,EXTENT.y]
				config.seed = int(seed_value); config.materials = [0,28,58]; config.protection = [[2,2,4,4]]
				config.budget_cells = int(registration.budget_cells)
				config.provider = "random" if arm=="random_valid" else "procedural"
				config.source_rectangles = fixture.source_rectangles
				config.operations = recipe.get("operations",[])
				var index := pending.size()
				var admission: Dictionary = controller.configure_tile(index,config)
				check(recipe.get("ok",false) and admission.ok,"configure frozen native case "+identity)
				pending.append({"id":identity,"family":family,"arm":arm,"seed":int(seed_value),"recipe":recipe,
					"config":config,"context":fixture.context.duplicate(true)})
		var indexes: Array[int] = []
		for i: int in pending.size(): indexes.append(i)
		check(controller.start(indexes).ok,"native family cohort queued "+family)
		await settle("native family cohort retired "+family)
		for i: int in pending.size():
			var case: Dictionary = pending[i]
			var tile: Dictionary = controller.tiles[i]
			var before_path: String = "planes/"+case.id+".before.u16le"
			var after_path: String = "planes/"+case.id+".after.u16le"
			write_bytes(output.path_join(before_path),tile.source_materials)
			write_bytes(output.path_join(after_path),tile.material_cells)
			cases.append({"id":case.id,"family":case.family,"arm":case.arm,"seed":case.seed,"status":tile.state,
				"reason":tile.reason,"extent":[EXTENT.x,EXTENT.y],"budget_cells":int(registration.budget_cells),
				"recipe_sha256":Module.digest(Module.json_bytes(case.config.operations)),"operations":case.config.operations,
				"before":{"encoding":"u16le","path":before_path,"sha256":Module.digest(tile.source_materials)},
				"after":{"encoding":"u16le","path":after_path,"sha256":Module.digest(tile.material_cells)},
				"receipts":tile.receipts.duplicate(true),"native_provenance":tile.provenance.duplicate(true),
				"context":case.context,"timings":tile.timings,"strategy":case.recipe.get("strategy",{}),
				"context_pack":case.recipe.get("context_pack",{}),"retrieval":case.recipe.get("retrieval",{}),
				"selected_modules":case.recipe.get("selected_modules",[]),"proposed_detail_cells":144})
			check(tile.state=="completed" and not tile.material_cells.is_empty(),"native case retains complete material readback "+case.id)
			if tile.image!=null: tile.image.save_png(output.path_join(case.id+".native-material-id.png"))
		write_manifest()
	check(cases.size()==int(registration.expected_attempts),"all 30 registered attempts retained")
	finish()

func family_fixture(family: String, seed_value: int) -> Dictionary:
	var source: Array = [[2,2,4,4,13],[8,176,240,8,58],[8,20,240,4,58],[8,24,4,152,58],[244,24,4,152,58]]
	var positions: Array = []
	var anchors: Array = []
	var zones: Array = []
	var jitter := seed_value%7-3
	var size: Array = SHAPES[family]
	if family=="industrial_hangar":
		for i: int in 6:
			var x := 24+i*40+jitter
			source.append([x,24,4,36,58]); positions.append([x-1,60]); anchors.append([x,56,4,4])
	elif family=="service_network":
		for i: int in 6:
			var x := 24+i*40+jitter
			source.append([x,24,4,88,58]); positions.append([x+4,80]); anchors.append([x,76,4,12])
	else:
		source.append([8,140,240,4,58])
		var top_depth := [48,36,56]
		var bank_top := [128,120,132]
		for i: int in 3:
			var x := 30+i*80+jitter
			source.append([x-2,24,8,top_depth[i]-24,58]); positions.append([x,top_depth[i]]); anchors.append([x-2,top_depth[i]-2,8,2])
		for i: int in 3:
			var x := 62+i*80+jitter
			source.append([x-2,bank_top[i],8,140-bank_top[i],58]); positions.append([x,bank_top[i]-6]); anchors.append([x-2,bank_top[i],8,2])
	for i: int in positions.size():
		var point: Array = positions[i]
		zones.append({"id":"mount-%d"%i,"rect":[point[0]-2,point[1]-2,size[0]+4,size[1]+4],
			"minimum_fraction":0.05,"maximum_fraction":0.5})
	var context := {"structural_materials":[58],"detail_materials":[28],"anchor_rects":anchors,
		"clearance_rects":[[16,148,224,24]],"detail_zones":zones,"protection_rects":[[2,2,4,4]],
		"route":[[20,160],[236,160]],"clearance_radius":2}
	return {"source_rectangles":source,"positions":positions,"context":context}

func query_for(family: String) -> Dictionary:
	var query := {"required_parts":[PARTS[family]],"require_native_geometry":true,"available_region":[256,192],"limit":3}
	match family:
		"industrial_hangar": query["topologies"]=["suspended","parallel_lanes"]; query["required_connections"]=["roof_anchor","service_access"]
		"service_network": query["topologies"]=["linear_chain","branch_rejoin"]; query["required_connections"]=["service_access"]
		"organic_cavern": query["topologies"]=["opposed_banks","vertical_chain","multi_level"]; query["required_connections"]=["rock_anchor","bank_handoff"]
	return query

func case_recipe(family: String, arm: String, seed_value: int, fixture: Dictionary, corpus: Dictionary) -> Dictionary:
	var size: Array = SHAPES[family]
	var positions: Array = fixture.positions.duplicate(true)
	var module_id := "comparison-"+family.replace("_","-")
	var context_pack := {}
	var retrieval := {}
	if arm=="reference_guided":
		for card: Dictionary in corpus.cards:
			if card.id==REFERENCES[family]:
				context_pack = {"authority":"REFERENCE_KNOWLEDGE_ONLY_NO_WRITE_PERMISSION","references":[{
					"id":card.id,"source":card.source,"observed":card.observed,"interpreted":card.interpreted,
					"strategies":card.construction_strategy,"qualification":card.qualification}]}
	if arm=="retrieval_guided":
		var found := Retriever.retrieve(query_for(family),library.summaries())
		if not found.ok or found.results.is_empty(): return {"ok":false,"reason":"Retrieval returned no qualified module context.","operations":[]}
		var candidates: Array = found.results[0].compatible_modules
		if candidates.is_empty(): return {"ok":false,"reason":"Retrieval has no native-qualified module.","operations":[]}
		module_id = str(candidates[0].id)
		context_pack = found.context_pack
		retrieval = {"query":found.query,"frozen_file_sha256":found.frozen_file_sha256,"corpus_sha256":found.corpus_sha256,
			"ranked_cards":found.results.map(func(item: Dictionary) -> Dictionary: return {"id":item.card.id,"score":item.score,"reasons":item.reasons,"compatible_modules":item.compatible_modules}),
			"limits":found.limits}
	if arm=="random_valid":
		var random := RandomNumberGenerator.new(); random.seed=seed_value
		positions.clear()
		for part: int in 6:
			var accepted := false
			for attempt: int in 4096:
				var point := Vector2i(random.randi_range(16,239-int(size[0])),random.randi_range(30,171-int(size[1])))
				var area := Rect2i(point,Vector2i(size[0],size[1]))
				var overlap := false
				for source: Array in fixture.source_rectangles:
					if area.intersects(Rect2i(source[0],source[1],source[2],source[3])): overlap=true; break
				for old: Array in positions:
					if area.grow(1).intersects(Rect2i(old[0],old[1],size[0],size[1])): overlap=true; break
				if not overlap: positions.append([point.x,point.y]); accepted=true; break
			if not accepted: return {"ok":false,"reason":"Frozen random-valid rejection budget exhausted.","operations":[]}
	var operations: Array = []
	var selected: Array = []
	for point: Array in positions:
		if arm=="hand_typed": operations.append(box(point[0],point[1],size[0],size[1],28))
		else:
			var module: Dictionary = library.get_module(module_id)
			var placement := {"origin":point,"transform":"identity"}
			var compiled := Module.compile(module,placement,{"region":Rect2i(Vector2i.ZERO,EXTENT),"protected":[Rect2i(2,2,4,4)],"allowed_materials":[0,28,58],"max_cells":65536})
			if not compiled.ok: return compiled
			operations.append_array(compiled.operations)
			selected.append({"id":module.id,"content_sha256":module.content_sha256,"placement":placement,"placement_sha256":compiled.placement_sha256})
	return {"ok":true,"operations":operations,"selected_modules":selected,"context_pack":context_pack,"retrieval":retrieval,
		"strategy":{"family":family,"arm":arm,"seed":seed_value,"positions":positions,"component_count":6,"component_cells":24,
			"reference_card":REFERENCES[family] if arm in ["reference_guided","retrieval_guided"] else "",
			"scope":"Offline typed/deterministic controls. Geometry equivalence is expected across context-aware arms; retrieval selects admissible module metadata, not a model-generated architecture."}}

func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: check(false,"write evidence plane "+path); return
	file.store_buffer(bytes); file.close()

func write_manifest() -> void:
	var native_name := "cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so"
	var manifest := {"schema_version":"cybersand.architectural-native-experiment.v1","source_commit":source_commit,
		"runtime":{"bridge_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/"+native_name),"godot":Engine.get_version_info().string,"platform":OS.get_name()},
		"registration_sha256":REGISTRATION_SHA256,"corpus_sha256":Retriever.CORPUS_SHA256,"model_calls":0,
		"cases":cases,"native_parts":part_evidence,"harness_sha256":FileAccess.get_sha256("res://tests/test_architecture_comparison.gd"),
		"scope":"Actual native material experiments, source-bound receipts and matched offline controls. No model-quality, subjective preference or physical gameplay claim."}
	write_bytes(output.path_join("cases.json"),Module.json_bytes(manifest))

func finish() -> void:
	if not output.is_empty() and not source_commit.is_empty(): write_manifest()
	if controller!=null: controller.queue_free()
	var report := {"schema":1,"passed":failures.is_empty(),"checks":checks,"failures":failures,"attempts":cases.size(),"source_commit":source_commit,
		"manifest":output.path_join("cases.json"),"model_calls":0,"scope":"Native execution and custody only; independent reducer owns geometric comparisons."}
	print("ARCHITECTURE_COMPARISON_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
