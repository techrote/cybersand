extends SceneTree
## Independently exercises harvested-part plans through the ordinary Workbench
## native executor. Retains actual receipts and planes, never inferred receipts.
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const Parts = preload("res://scripts/batch_lab/native_module_examples.gd")
const Compositions = preload("res://scripts/batch_lab/architecture_module_compositions.gd")
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var checks := 0
var failures: Array[String] = []
var library := Library.new()
var source_parts: Array = []
var compositions: Array = []
var evidence := ""
var controller: Node
var main: Control
var wb: Control
var panel: Window
var session: Node

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(condition: bool, label: String) -> bool:
	checks += 1
	print("ARCHITECTURE_MODULE_NATIVE_CHECK ",label," ",condition)
	if not condition: failures.append(label); push_error(label)
	return condition

func until(test: Callable, label: String, timeout_ms := 120000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not test.call() and Time.get_ticks_msec()<deadline: await process_frame
	return check(test.call(),label)

func installed() -> bool:
	return not wb.applied.is_empty() and not wb.busy() and main.pending_microscenario_apply.is_empty()

func write_json(name_text: String, value: Variant) -> void:
	var file := FileAccess.open(evidence.path_join(name_text),FileAccess.WRITE)
	if not check(file!=null,"write evidence "+name_text): return
	file.store_buffer(Module.json_bytes(value)); file.close()

func write_plane(name_text: String, cells: PackedByteArray) -> Dictionary:
	var file := FileAccess.open(evidence.path_join(name_text),FileAccess.WRITE)
	if not check(file!=null,"write native material plane "+name_text): return {}
	file.store_buffer(cells); file.close()
	return {"path":name_text,"sha256":Module.digest(cells),"encoding":"u16le"}

func crop(plane: PackedByteArray, extent: Vector2i, area: Rect2i) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(area.get_area()*2)
	for y: int in area.size.y:
		for x: int in area.size.x:
			cells.encode_u16((y*area.size.x+x)*2,plane.decode_u16(((area.position.y+y)*extent.x+area.position.x+x)*2))
	return cells

func outside_equal(before: PackedByteArray, after: PackedByteArray, area: Rect2i) -> bool:
	if before.size()!=512*512*2 or after.size()!=before.size(): return false
	for y: int in 512:
		for x: int in 512:
			if not area.has_point(Vector2i(x,y)) and before.decode_u16((y*512+x)*2)!=after.decode_u16((y*512+x)*2): return false
	return true

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

func build_parts() -> bool:
	var recipes := Parts.recipes()
	controller = Controller.new(); root.add_child(controller); await process_frame
	controller.configure_grid(4,2)
	for i: int in recipes.size():
		var config := Controller.defaults()
		config.extent = [64,64]; config.source_region = [0,0,64,64]
		config.materials = [0,7,28,58]; config.operations = recipes[i].operations
		if not check(controller.configure_tile(i,config).ok,"configure real source part "+recipes[i].id): return false
	if not check(controller.start().ok,"start eight native source parts"): return false
	if not await until(func(): return not controller.is_running(),"all source parts completed native work"): return false
	for i: int in recipes.size():
		var tile: Dictionary = controller.tiles[i]
		var recipe: Dictionary = recipes[i]
		if not check(tile.state=="completed","source part native completion "+recipe.id): return false
		var harvested := library.harvest_tile(tile,recipe.metadata,Module.rect(recipe.harvest_region))
		if not check(harvested.ok,"source part harvested from actual readback "+recipe.id): return false
		var components := face_components(harvested.cells,harvested.extent)
		if not check(components==1,"actual native starter part is face-connected "+recipe.id): return false
		source_parts.append({"id":recipe.id,"module_sha256":harvested.module.content_sha256,
			"geometry_sha256":harvested.module.geometry.sha256,"attempt_id":tile.attempt_id,
			"native_receipts":tile.receipts,"source_provenance":tile.provenance,"material_sha256":tile.material_sha256,"face_connected_components":components})
	check(library.summaries().all(func(value: Dictionary) -> bool: return value.native_readback_verified),"all eight current-process source modules qualified by real native readback")
	check(library.save(evidence.path_join("source-part-library.json")).ok,"save exact native source module library")
	controller.queue_free(); controller = null
	await process_frame
	return failures.is_empty()

func run() -> void:
	evidence = OS.get_environment("ARCHITECTURE_MODULE_COMPOSITIONS_DIR")
	if evidence.is_empty(): evidence = ProjectSettings.globalize_path("user://architecture-module-compositions-evidence")
	DirAccess.make_dir_recursive_absolute(evidence)
	if not await build_parts(): await finish(); return
	root.size = Vector2i(1280,900)
	change_scene_to_file("res://feature_launcher.tscn"); await scene_changed
	current_scene.launch("shared_workbench"); await scene_changed
	main = current_scene; wb = main.shared_workbench
	if not await until(installed,"ordinary native Workbench ready for independent module composition"): await finish(); return
	wb.open_architecture_lab()
	panel = wb.architecture_lab; panel.hide()
	panel.library = library; session = panel.session; session.library = library
	for recipe: Dictionary in Compositions.plans(library):
		for field: SpinBox in wb._extent: field.value = 512
		if not check(wb.new_canvas(),"new authored World for "+recipe.id): break
		if not await until(func(): return installed() and Setup.extent_of(wb.applied)==Vector2i(512,512),"fresh native World installed "+recipe.id): break
		var before: Dictionary = await wb.capture_batch_source(Rect2i(0,0,512,512))
		if not check(before.get("ok",false),"whole native World baseline "+recipe.id): break
		var area := Compiler.rect(recipe.stages[0].region)
		var initial: PackedByteArray = before.config.source_cells
		var record_start: int = session.records.size()
		var stage_results: Array = []
		if not check(session.load_plan(recipe).ok,"load pinned module composition "+recipe.id): break
		for i: int in recipe.stages.size():
			session.select(i)
			var previewed: Dictionary = await session.preview_selected()
			if not check(previewed.ok,"native-inspected zero-write module stage "+recipe.stages[i].id+" / "+session.message): break
			var projection: PackedByteArray = previewed.preview.projected_cells.duplicate()
			var unchanged: Dictionary = await wb.capture_batch_source(area)
			check(unchanged.get("ok",false) and unchanged.config.source_provenance.crop_sha256==previewed.preview.source_sha256,"preview preserves actual native source "+recipe.stages[i].id)
			if not check((await session.approve()).ok,"approve bounded native module stage "+recipe.stages[i].id): break
			if not await until(func(): return not session.busy(),"native module stage retired "+recipe.stages[i].id): break
			if not check(session.stage_state()=="completed","native module stage exact completion "+recipe.stages[i].id+" / "+session.message): break
			var observed: Dictionary = await wb.capture_batch_source(Rect2i(0,0,512,512))
			if not check(observed.get("ok",false),"whole native World readback "+recipe.stages[i].id): break
			check(crop(observed.config.source_cells,Vector2i(512,512),area)==projection,"every native stage cell matches independent projection "+recipe.stages[i].id)
			check(outside_equal(initial,observed.config.source_cells,area),"all outside-region native material unchanged "+recipe.stages[i].id)
			var retained: Dictionary = session.records.back().duplicate(true)
			check(retained.native_receipts.size()>0 and retained.result_sha256==Module.digest(projection),"retained actual receipts bind module stage "+recipe.stages[i].id)
			stage_results.append(retained)
		if not check(stage_results.size()==3,"three actual native stages complete "+recipe.id): continue
		var final_capture: Dictionary = await wb.capture_batch_source(area)
		if not check(final_capture.get("ok",false),"final authored native module composition "+recipe.id): continue
		var cells: PackedByteArray = final_capture.config.source_cells
		var components := face_components(cells,area.size)
		check(components==1,"all actual native primary geometry is face-connected "+recipe.id)
		var final_plane := write_plane(recipe.id+".u16le",cells)
		check(Controller.material_image(cells,area.size).save_png(evidence.path_join(recipe.id+"-material-id.png"))==OK,"diagnostic material image "+recipe.id)
		var metadata := {"id":recipe.id+"-harvest","name":recipe.name,"tags":["native-module-composition",recipe.id],
			"part_type":"unclassified","allowed_transforms":["identity","mirror_x"],"recipe":recipe}
		check(library.harvest_capture(final_capture,metadata).ok,"actual module composition can itself be harvested "+recipe.id)
		check(library.export_module(metadata.id,evidence.path_join(recipe.id+".module.json")).ok,"export reusable native composition "+recipe.id)
		var result := {"id":recipe.id,"extent":recipe.extent,"origin":recipe.origin,"recipe":recipe,
			"plan_sha256":Module.digest(Module.json_bytes(recipe)),"source_plane":write_plane(recipe.id+"-before.u16le",crop(initial,Vector2i(512,512),area)),
			"final_plane":final_plane,"stages":stage_results,"whole_world_source_sha256":Module.digest(initial),
			"module_instances":recipe.stages[0].modules.size()+recipe.stages[1].modules.size()+recipe.stages[2].modules.size(),
			"independent_receipt_count":session.records.size()-record_start,
			"scope":"Actual native stage execution and exact material equality. Images are diagnostic material IDs, not graphical or gameplay acceptance."}
		result["family"] = recipe.name
		result["plane"] = final_plane.path
		result["sha256"] = final_plane.sha256
		result["native_records"] = stage_results.duplicate(true)
		result["face_connected_components"] = components
		write_json(recipe.id+"-plan.json",recipe)
		wb._name.text = "architecture-"+recipe.id
		if check(wb.save_setup(),"ordinary portable authored start saved "+recipe.id):
			var start_bytes := FileAccess.get_file_as_bytes(Setup._path(wb._name.text))
			var start_file := FileAccess.open(evidence.path_join(recipe.id+"-workbench-start.json"),FileAccess.WRITE)
			if start_file!=null: start_file.store_buffer(start_bytes); start_file.close()
			check(not start_bytes.is_empty() and FileAccess.get_sha256(evidence.path_join(recipe.id+"-workbench-start.json"))==Module.digest(start_bytes),"portable authored start bytes preserved "+recipe.id)
		compositions.append(result)
		write_json(recipe.id+"-native.json",result)
	check(compositions.size()==3,"all three multi-scale native module compositions executed")
	check(library.save(evidence.path_join("native-compositions-library.json")).ok,"save native module compositions and original reusable parts")
	write_json("module-compositions.json",{"examples":compositions,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"godot":Engine.get_version_info().string})
	await finish()

func finish() -> void:
	var report_file := FileAccess.open(evidence.path_join("native-module-compositions-report.json"),FileAccess.WRITE)
	check(report_file!=null,"write evidence native-module-compositions-report.json")
	var report := {"schema":"cybersand-native-module-compositions-v1","passed":failures.is_empty(),"checks":checks,"failures":failures,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"godot":Engine.get_version_info().string,
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so") if OS.get_name()=="Linux" else FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"),
		"source_parts":source_parts,"compositions":compositions,"model_calls":0}
	if report_file!=null: report_file.store_buffer(Module.json_bytes(report)); report_file.close()
	print("ARCHITECTURE_MODULE_COMPOSITIONS_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"compositions":compositions.size()}))
	if is_instance_valid(controller): controller.queue_free()
	if is_instance_valid(main): main.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
