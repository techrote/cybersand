extends SceneTree
## Source-bound native Build -> Harvest -> exact identity and asymmetric replay.
## Uses the existing Batch controller/native owner, one active World at a time.
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const Catalogue = preload("res://scripts/batch_lab/native_module_catalogue.gd")
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Pure = preload("res://tests/test_native_module_catalogue.gd")
const ARENA := Vector2i(128,128)
const ASYMMETRIC := ["offset-buttress","offset-manifold","diagonal-transfer-spine","pump-on-plinth"]
var controller: Node
var library := Library.new()
var checks := 0
var failures: Array[String] = []
var observations: Array = []
var output := ""
var source_revision := ""
var development_core_capacity := 0

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	var capacity := OS.get_environment("ARCHITECTURE_DEVELOPMENT_CORE_CAPACITY")
	if not capacity.is_empty():
		if not capacity.is_valid_int() or int(capacity)<1 or int(capacity)>256:
			check(false,"development core capacity must be an explicit integer 1–256")
			quit(1); return
		development_core_capacity=int(capacity)
		ProjectSettings.set_setting("cybersand/native_active_core_capacity",development_core_capacity)
		print("NATIVE_CATALOGUE_DEVELOPMENT_CORE_CAPACITY ",development_core_capacity,"; development memory configuration, not production-default qualification")
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print("NATIVE_CATALOGUE_NATIVE_CHECK ",checks," ",label," ",value)
	if not value: failures.append(label); push_error(label)
	return value

func settle(label: String) -> bool:
	var deadline := Time.get_ticks_msec()+240000
	while controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	if controller.is_running(): controller.stop()
	return check(not controller.is_running(),label)

func write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_buffer(bytes); file.close()
	return FileAccess.get_sha256(path)==Module.digest(bytes)

func record(tile: Dictionary, identity: String, phase: String, transform := "identity") -> void:
	var path := "observations/"+identity+"-"+phase+"-"+transform+".json"
	var encoded := Controller._encode(controller._record(tile))
	check(write_bytes(output.path_join(path),Module.json_bytes(encoded)),"retain original native record "+identity+" "+phase+" "+transform)
	observations.append({"id":identity,"phase":phase,"transform":transform,"status":tile.state,
		"attempt_id":tile.attempt_id,"record_path":path,"record_sha256":FileAccess.get_sha256(output.path_join(path)),
		"material_sha256":tile.material_sha256,"source_sha256":Module.digest(tile.source_materials),
		"source_revision":tile.provenance.get("source_revision",""),"native_binary_sha256":tile.provenance.get("native_binary_sha256","")})

func run() -> void:
	output = OS.get_environment("NATIVE_CATALOGUE_EVIDENCE_DIR")
	source_revision = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	if not check(not output.is_empty() and source_revision.length()==40 and Module._hex(source_revision+"0".repeat(24)),"explicit evidence directory and exact source revision"):
		finish(); return
	for child: String in ["modules","observations","planes"]: DirAccess.make_dir_recursive_absolute(output.path_join(child))
	var recipes := Catalogue.recipes()
	check(recipes.size()==40,"forty curated source definitions")
	controller = Controller.new(); root.add_child(controller); await process_frame
	controller.max_parallel=1
	controller.configure_grid(4,4)
	for offset: int in range(0,recipes.size(),16):
		var batch: Array = recipes.slice(offset,mini(offset+16,recipes.size()))
		for i: int in batch.size():
			var recipe: Dictionary = batch[i]; var config := Controller.defaults()
			config.extent = recipe.extent.duplicate(); config.source_region = [0,0,recipe.extent[0],recipe.extent[1]]
			config.materials = Catalogue.MATERIALS.duplicate(); config.operations=recipe.operations.duplicate(true); config.budget_cells=65536
			check(controller.configure_tile(i,config).ok,"configure actual native source "+recipe.id)
		check(controller.start(range(batch.size())).ok,"queue bounded native source cohort "+str(offset))
		if not await settle("retire native source cohort "+str(offset)): finish(); return
		for i: int in batch.size():
			var recipe: Dictionary = batch[i]; var tile: Dictionary = controller.tiles[i]
			record(tile,recipe.id,"source")
			if not check(tile.state=="completed" and tile.get("_native_readback_current_process",false),"fresh native source completed "+recipe.id): continue
			var independent := Pure.source_plane(recipe)
			check(independent.ok and tile.material_cells==independent.cells,"actual native source matches independent rectangle oracle "+recipe.id)
			var harvested := library.harvest_tile(tile,recipe.metadata,Module.rect(recipe.harvest_region))
			if not check(harvested.ok,"harvest exact observed part "+recipe.id+" "+str(harvested.get("reason",""))): continue
			var size := Vector2i(int(harvested.module.extent[0]),int(harvested.module.extent[1]))
			check(Pure.components(harvested.cells,size)==1,"native source part has one face component "+recipe.id)
			check(library.export_module(recipe.id,output.path_join("modules").path_join(recipe.id+".json")).ok,"export native reusable module "+recipe.id)
			check(write_bytes(output.path_join("planes").path_join(recipe.id+".u16le"),harvested.cells),"retain exact observed material plane "+recipe.id)
			if tile.image!=null:
				var image: Image = tile.image.get_region(Module.rect(recipe.harvest_region))
				check(image.save_png(output.path_join("planes").path_join(recipe.id+".native-material-id.png"))==OK,"retain labelled native material-ID diagnostic "+recipe.id)
	if not failures.is_empty(): finish(); return
	check(library.count()==40 and library.summaries().all(func(item: Dictionary) -> bool: return item.native_readback_verified),"forty modules qualified only from actual current-session native harvest")
	check(library.save(output.path_join("curated-library-v2.json")).ok,"save complete native module library")
	var jobs: Array = []
	for module: Dictionary in library.all():
		jobs.append({"id":module.id,"transform":"identity"})
		if module.id in ASYMMETRIC:
			for transform: String in Module.TRANSFORMS:
				if transform!="identity": jobs.append({"id":module.id,"transform":transform})
	check(jobs.size()==60,"forty identity plus twenty asymmetric orthogonal replay jobs")
	for offset: int in range(0,jobs.size(),16):
		var batch: Array = jobs.slice(offset,mini(offset+16,jobs.size())); var expected: Array = []
		for i: int in batch.size():
			var job: Dictionary = batch[i]; var module := library.get_module(job.id)
			var compiled := Module.compile(module,{"origin":[7,9],"transform":job.transform},
				{"region":[0,0,128,128],"protected":[[2,2,3,3]],"allowed_materials":Catalogue.MATERIALS,"max_cells":16384})
			if not check(compiled.ok,"compile harvested replay "+job.id+" "+job.transform): finish(); return
			var config := Controller.defaults(); config.extent=[128,128]; config.source_region=[0,0,128,128]
			config.materials=Catalogue.MATERIALS.duplicate(); config.protection=[[2,2,3,3]]; config.source_rectangles=[[2,2,3,3,13]]
			config.operations=compiled.operations; config.budget_cells=16384
			check(controller.configure_tile(i,config).ok,"configure actual native replay "+job.id+" "+job.transform)
			expected.append(_oracle(module,job.transform))
		check(controller.start(range(batch.size())).ok,"queue native replay cohort "+str(offset))
		if not await settle("retire native replay cohort "+str(offset)): finish(); return
		for i: int in batch.size():
			var job: Dictionary = batch[i]; var tile: Dictionary = controller.tiles[i]
			record(tile,job.id,"replay",job.transform)
			check(tile.state=="completed" and tile.material_cells==expected[i],"exact native replay matches complete scalar plane "+job.id+" "+job.transform)
			check(tile.metrics.get("outside_unchanged",false),"native arena outside footprint unchanged "+job.id+" "+job.transform)
			var marker_ok := true
			for y: int in range(2,5):
				for x: int in range(2,5):
					if tile.material_cells.decode_u16((y*128+x)*2)!=13: marker_ok=false
			check(marker_ok,"protected Stone marker retained "+job.id+" "+job.transform)
			check(write_bytes(output.path_join("planes").path_join(job.id+"-"+job.transform+"-replay.u16le"),tile.material_cells),"retain exact replay plane "+job.id+" "+job.transform)
	var imported := Library.new()
	check(imported.load_library(output.path_join("curated-library-v2.json")).ok,"complete native library reopens through ordinary validated document path")
	check(imported.count()==40 and imported.summaries().all(func(item: Dictionary) -> bool: return not item.native_readback_verified),"reopened historical library grants no current-session native flag")
	finish()

func _oracle(module: Dictionary, transform: String) -> PackedByteArray:
	var cells: PackedByteArray = Module.validate(module).cells
	var width: int = module.extent[0]; var height: int = module.extent[1]
	var result := PackedByteArray(); result.resize(128*128*2)
	for y: int in range(2,5):
		for x: int in range(2,5): result.encode_u16((y*128+x)*2,13)
	for y: int in height:
		for x: int in width:
			var tx := x; var ty := y
			match transform:
				"mirror_x": tx=width-1-x
				"mirror_y": ty=height-1-y
				"rotate_90": tx=height-1-y; ty=x
				"rotate_180": tx=width-1-x; ty=height-1-y
				"rotate_270": tx=y; ty=width-1-x
			var material := cells.decode_u16((y*width+x)*2)
			if material>0: result.encode_u16(((ty+9)*128+tx+7)*2,material)
	return result

func finish() -> void:
	if controller!=null: controller.queue_free()
	var report := {"format":"cybersand-native-catalogue-qualification-v1","passed":failures.is_empty(),"checks":checks,"failures":failures,
		"catalogue_id":Catalogue.CATALOGUE_ID,"source_revision":source_revision,"engine":Engine.get_version_info().string,
		"development_core_capacity_override":development_core_capacity,"native_active_core_capacity":ProjectSettings.get_setting("cybersand/native_active_core_capacity",1024),
		"runtime_configuration_scope":"explicit low-memory development override; hosted default-capacity qualification remains separate" if development_core_capacity>0 else "normal default-capacity source-bound execution",
		"recipe_sha256":Module.digest(Module.json_bytes(Catalogue.recipes())),"modules":library.summaries(),"observations":observations,
		"model_calls":0,"scope":"Actual native source construction, exact material harvest, forty translated identity replays and twenty selected asymmetric mirror/quarter-turn replays. No physical stability, actor traversal or owner aesthetic acceptance."}
	if not output.is_empty(): write_bytes(output.path_join("native-catalogue-report.json"),Module.json_bytes(report))
	print("NATIVE_CATALOGUE_NATIVE_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"modules":library.count(),"observations":observations.size(),"source_revision":source_revision}))
	quit(0 if failures.is_empty() else 1)
