extends SceneTree
## Eight reusable parts are populated only after actual native construction and harvest.
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const Examples = preload("res://scripts/batch_lab/native_module_examples.gd")
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
var controller: Node
var failures: Array[String] = []
var checks := 0
var results: Array = []

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(condition: bool, label: String) -> bool:
	checks+=1
	print("NATIVE_PART_CHECK ",checks," ",label," ",condition)
	if not condition: failures.append(label); push_error(label)
	return condition

func settle(label: String) -> bool:
	var deadline := Time.get_ticks_msec()+120000
	while controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	return check(not controller.is_running(),label)

func run() -> void:
	var output := OS.get_environment("NATIVE_MODULE_EVIDENCE_DIR")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var recipes := Examples.recipes()
	var library := Library.new()
	controller = Controller.new(); root.add_child(controller); await process_frame
	controller.configure_grid(4,2)
	for i: int in recipes.size():
		var config := Controller.defaults()
		config.extent = recipes[i].extent; config.source_region = [0,0,64,64]
		config.materials = [0,7,28,58]; config.operations = recipes[i].operations
		check(controller.configure_tile(i,config).ok,"configure native part "+recipes[i].id)
	check(controller.start().ok,"source parts queued in existing native Batch Lab")
	if not await settle("all native source parts retired"): finish(output); return
	for i: int in recipes.size():
		var tile: Dictionary = controller.tiles[i]
		var recipe: Dictionary = recipes[i]
		if not check(tile.state=="completed","native part completed "+recipe.id): continue
		var harvested := library.harvest_tile(tile,recipe.metadata,Module.rect(recipe.harvest_region))
		if not check(harvested.ok,"actual native readback harvested "+recipe.id+": "+str(harvested.get("reason",""))): continue
		var module: Dictionary = harvested.module
		var compiled := Module.compile(module,{"origin":[0,0]},
			{"region":Rect2i(0,0,64,64),"protected":[],"allowed_materials":[0,7,28,58],"max_cells":4096})
		check(compiled.ok and compiled.zero_writes,"harvested part preview is zero-write "+recipe.id)
		var config := Controller.defaults()
		config.extent = [64,64]; config.source_region = [0,0,64,64]
		config.materials = [0,7,28,58]; config.operations = compiled.operations
		check(controller.configure_tile(i,config).ok,"prepare exact native replay "+recipe.id)
		results.append({"id":module.id,"module_sha256":module.content_sha256,"geometry_sha256":module.geometry.sha256,
			"source_attempt_id":tile.attempt_id,"native_binary_sha256":tile.provenance.native_binary_sha256,
			"source_revision":tile.provenance.source_revision,"region":recipe.harvest_region,
			"observed_cells":compiled.budget.unique_cells,"replay_verified":false})
		if not output.is_empty():
			check(library.export_module(module.id,output.path_join(module.id+".module.json")).ok,"export native part "+module.id)
			if tile.image!=null:
				var thumbnail: Image = tile.image.get_region(Module.rect(recipe.harvest_region))
				check(thumbnail.save_png(output.path_join(module.id+".native-material-id.png"))==OK,"save observed part geometry "+module.id)
	if not failures.is_empty(): finish(output); return
	check(controller.start().ok,"all exact harvested recipes queued for native replay")
	if not await settle("all native harvested replays retired"): finish(output); return
	for i: int in recipes.size():
		var tile: Dictionary = controller.tiles[i]
		var module := library.get_module(recipes[i].id)
		var extent := Vector2i(int(module.extent[0]),int(module.extent[1]))
		var observed := PackedByteArray(); observed.resize(extent.x*extent.y*2)
		var outside_empty := true
		for y: int in 64:
			for x: int in 64:
				var material: int = tile.material_cells.decode_u16((y*64+x)*2)
				if x<extent.x and y<extent.y: observed.encode_u16((y*extent.x+x)*2,material)
				elif material!=0: outside_empty = false
		var exact: bool = tile.state=="completed" and observed==Module.validate(module).cells
		check(exact,"exact native extracted replay "+module.id)
		check(outside_empty and tile.metrics.get("outside_unchanged",false),"outside source part remains untouched "+module.id)
		results[i].replay_verified = exact
		results[i]["replay_attempt_id"] = tile.attempt_id
		results[i]["replay_material_sha256"] = tile.material_sha256
	check(library.count()==8 and library.summaries().all(func(item: Dictionary) -> bool: return item.native_readback_verified),"eight parts have current-session native readback qualification")
	if not output.is_empty(): check(library.save(output.path_join("starter-library-v1.json")).ok,"all eight reusable module documents saved")
	finish(output)

func finish(output: String) -> void:
	if controller!=null: controller.queue_free()
	var report := {"schema":1,"passed":failures.is_empty(),"checks":checks,"failures":failures,"parts":results,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"engine":Engine.get_version_info().string,
		"scope":"Executed native parts, exact cropped material geometry and fresh native replay. No physical gameplay or subjective design certification."}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("native-module-examples-report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t")); file.close()
	print("NATIVE_PARTS_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
