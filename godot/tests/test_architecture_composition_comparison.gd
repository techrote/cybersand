extends SceneTree
## Registered distinct-output native comparison. Source recipes + all controls
## are offline tools. Every actual application uses the existing Batch native host.
const Controller=preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Module=preload("res://scripts/batch_lab/native_module.gd")
const Library=preload("res://scripts/batch_lab/native_module_library.gd")
const Catalogue=preload("res://scripts/batch_lab/architecture_comparison_catalogue.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Recipes=preload("res://scripts/batch_lab/architecture_comparison_recipes.gd")
const REGISTRATION:="res://data/batch_lab/m67/comparison-registration.v1.json"
const REGISTRATION_SHA:="1dbdb552dfcbb7f6e81fdd7807ea77aca4384eca523293ababb007b0664ef34f"
const HELDOUT:={"res://data/batch_lab/m67/heldout-briefs-a.v1.json":"28058f7d415e86f566833c0c068ff02e517bd4416148bcaf0d2ba789ee6b18b7",
	"res://data/batch_lab/m67/held-out-c-briefs.v1.json":"b5e268c2060b3f2319683e187a6fb8d43d8d06f59083ce0c8eb413fa8a215fdd"}
var controller: Node
var library:=Library.new()
var output:=""
var source_revision:=""
var development_core_capacity:=0
var cases: Array=[]
var module_observations: Array=[]
var sources: Array=[]
var checks:=0
var failures: Array=[]

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	var cap:=OS.get_environment("ARCHITECTURE_DEVELOPMENT_CORE_CAPACITY")
	if not cap.is_empty():
		if not cap.is_valid_int() or int(cap)<1 or int(cap)>256:quit(1);return
		development_core_capacity=int(cap);ProjectSettings.set_setting("cybersand/native_active_core_capacity",development_core_capacity)
	run.call_deferred()

func check(value: bool,label: String) -> bool:
	checks+=1;print("M67_NATIVE_COMPARISON_CHECK ",checks," ",label," ",value)
	if not value:failures.append(label);push_error(label)
	return value

func write_bytes(path: String,bytes: PackedByteArray) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_buffer(bytes);file.close();return FileAccess.get_sha256(path)==Compiler.digest(bytes)

func write_json(relative: String,value: Variant) -> bool:
	return write_bytes(output.path_join(relative),Module.json_bytes(value))

func settle() -> bool:
	var deadline:=Time.get_ticks_msec()+180000
	while controller.is_running() and Time.get_ticks_msec()<deadline:await process_frame
	if controller.is_running():controller.stop()
	return check(not controller.is_running(),"bounded native attempt retires")

func apply(config: Dictionary) -> Dictionary:
	if not controller.configure_tile(0,config).ok:return {"ok":false,"reason":"Native apparatus tile configuration refused."}
	var queued: Dictionary=controller.start([0])
	if not queued.ok:return queued
	if not await settle():return {"ok":false,"reason":"Native apparatus timeout."}
	return {"ok":true,"tile":controller.tiles[0]}

func run() -> void:
	output=OS.get_environment("M67_COMPARISON_EVIDENCE_DIR");source_revision=OS.get_environment("CYBERSAND_SOURCE_REVISION")
	if not check(not output.is_empty() and source_revision.length()==40 and source_revision.is_valid_hex_number(false),"exact comparison source and output identity"):finish();return
	for child: String in ["modules","records","planes","programs"]:DirAccess.make_dir_recursive_absolute(output.path_join(child))
	if not check(FileAccess.get_sha256(REGISTRATION)==REGISTRATION_SHA,"registration frozen before held-out reveal"):finish();return
	if not check(Catalogue.load_frozen().ok,"exact pre-reveal experimental catalogue independent of evolving owner library"):finish();return
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REGISTRATION))
	var briefs: Array=Recipes.development_briefs()
	for path: String in HELDOUT:
		if not check(FileAccess.get_sha256(path)==HELDOUT[path],"independently frozen brief identity "+path):finish();return
		var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));briefs.append_array(document.briefs)
	if not check(briefs.size()==6,"two development plus four held-out briefs"):finish();return
	controller=Controller.new();root.add_child(controller);await process_frame;controller.configure_grid(1,1);controller.max_parallel=1
	for recipe: Dictionary in Catalogue.recipes():
		var config:=Controller.defaults();config.extent=recipe.extent.duplicate();config.source_region=[0,0,recipe.extent[0],recipe.extent[1]]
		config.materials=Catalogue.MATERIALS.duplicate();config.operations=recipe.operations.duplicate(true);config.budget_cells=65536
		var built: Dictionary=await apply(config)
		if not check(built.ok and built.tile.state=="completed","actual native part "+recipe.id):finish();return
		var harvested:=library.harvest_tile(built.tile,recipe.metadata,Module.rect(recipe.harvest_region))
		if not check(harvested.ok,"current-process exact native harvest "+recipe.id):finish();return
		var record_path:="records/module-"+str(recipe.id)+".json"
		check(write_json(record_path,Controller._encode(controller._record(built.tile))),"retain native module source record "+recipe.id)
		module_observations.append({"id":recipe.id,"module_sha256":harvested.module.content_sha256,"geometry_sha256":harvested.module.geometry.sha256,
			"record_path":record_path,"record_sha256":FileAccess.get_sha256(output.path_join(record_path))})
		check(library.export_module(recipe.id,output.path_join("modules").path_join(str(recipe.id)+".json")).ok,"export actual native part "+recipe.id)
	if not check(library.count()==40 and library.summaries().all(func(item: Dictionary)->bool:return item.native_readback_verified),"all forty module choices have current-process native evidence"):finish();return
	for brief: Dictionary in briefs:
		var fixture:=Recipes.source_plane(brief)
		if not check(fixture.ok,"bounded source fixture "+brief.id):finish();return
		var source_config:=Controller.defaults();source_config.extent=[256,192];source_config.source_region=[0,0,256,192];source_config.materials=[0,7,13,28,58];source_config.budget_cells=32768
		var source_ops: Array=[]
		for row: Array in Recipes.source_rectangles(brief):source_ops.append(Recipes.box(row[0],row[1],row[2],row[3],row[4]))
		source_config.operations=source_ops
		var source_built: Dictionary=await apply(source_config)
		if not check(source_built.ok and source_built.tile.state=="completed" and source_built.tile.material_cells==fixture.cells,"actual native source equals frozen complete plane "+brief.id):finish();return
		var source_path:="planes/"+str(brief.id)+".source.u16le";var source_record_path:="records/"+str(brief.id)+".source.json"
		check(write_bytes(output.path_join(source_path),source_built.tile.material_cells),"retain native baseline plane "+brief.id)
		check(write_json(source_record_path,Controller._encode(controller._record(source_built.tile))),"retain native baseline receipt "+brief.id)
		sources.append({"brief_id":brief.id,"source_plane_path":source_path,"source_sha256":fixture.sha256,"record_path":source_record_path,"record_sha256":FileAccess.get_sha256(output.path_join(source_record_path))})
		for seed_value: Variant in registration.seeds:
			for arm: String in Recipes.ARMS:
				await run_case(brief,arm,int(seed_value),fixture,source_path)
		write_manifest()
	check(cases.size()==60,"all sixty registered proposals retained including refusals")
	finish()

func run_case(brief: Dictionary,arm: String,seed_value: int,source: Dictionary,source_path: String) -> void:
	var started:=Time.get_ticks_usec();var identity:="%s-%s-%d"%[brief.id,arm,seed_value]
	var program:=Recipes.build(brief,arm,seed_value,library)
	var row: Dictionary={"case_id":identity,"cohort":"development" if brief.cohort=="development" else "held_out","brief_id":brief.id,"family":brief.family,
		"arm":arm,"seed":seed_value,"extent":[256,192],"status":"refused-before-native","source_plane_path":source_path,"source_sha256":source.sha256,
		"result_plane_path":source_path,"result_sha256":source.sha256,"raw_native_record_path":"","raw_native_record_sha256":"","native_attempted":false,
		"brief_sha256":Compiler.digest(Compiler.canonical(brief).to_utf8_buffer()),"brief":brief.duplicate(true),"actual_counts":{"checked":0,"changed":0},
		"module_ids":[],"module_hashes":[],"compile_reason":"","program_sha256":"","query_sha256":Compiler.digest(Compiler.canonical(Recipes.query_for(brief)).to_utf8_buffer()),
		"selected_modules":program.get("selected_modules",[]).duplicate(true),"reference_ids":program.get("reference_ids",[]).duplicate(),"context_pack":program.get("context_pack",{}).duplicate(true),
		"relation_status":program.get("relation_status","not-executed"),"model_calls":0}
	var program_path:="programs/"+identity+".json";check(write_json(program_path,program),"retain exact proposed program "+identity)
	row.program_sha256=FileAccess.get_sha256(output.path_join(program_path));row["program_path"]=program_path
	if not program.ok:
		row.compile_reason=str(program.get("reason","Registered tool refused."));row["selection_status"]=program.get("status","refused");row.elapsed_usec=Time.get_ticks_usec()-started;cases.append(row);return
	for item: Dictionary in program.get("selected_modules",[]):row.module_ids.append(item.module_id);row.module_hashes.append(item.module_sha256)
	var context: Dictionary={"region":[0,0,256,192],"world_region":[0,0,256,192],"source_cells":source.cells.duplicate(),"source_sha256":source.sha256,"generation":1,"paused":true,"allowed_materials":[0,7,28,58]}
	var compiled:=Compiler.compile(program.stage,context,library)
	if not compiled.ok:
		row.compile_reason=str(compiled.get("reason","Host compilation refused."));row.elapsed_usec=Time.get_ticks_usec()-started;cases.append(row);return
	row["preview_sha256"]=compiled.preview_sha256;row["projected_sha256"]=compiled.projected_sha256;row["host_budget"]=compiled.budget.duplicate()
	row["module_contact_result"]=compiled.get("module_contact_result",{}).duplicate(true)
	var config:=Controller.defaults();config.extent=[256,192];config.source_region=[0,0,256,192];config.materials=[0,7,28,58];config.budget_cells=32768
	config.seed=seed_value;config.source_rectangles=Recipes.source_rectangles(brief);config.protection=[[2,2,4,4]];config.operations=compiled.operations.duplicate(true)
	var built: Dictionary=await apply(config)
	if not check(built.ok,"native case admission "+identity):row.status="apparatus-failure";row.elapsed_usec=Time.get_ticks_usec()-started;cases.append(row);return
	var tile: Dictionary=built.tile;row.native_attempted=true;row.status=tile.state;row.compile_reason=tile.reason
	var result_path:="planes/"+identity+".result.u16le";var record_path:="records/"+identity+".json"
	check(write_bytes(output.path_join(result_path),tile.material_cells) and write_json(record_path,Controller._encode(controller._record(tile))),"retain exact native case readback and receipts "+identity)
	row.result_plane_path=result_path;row.result_sha256=Compiler.digest(tile.material_cells);row.raw_native_record_path=record_path;row.raw_native_record_sha256=FileAccess.get_sha256(output.path_join(record_path))
	check(tile.source_materials==source.cells,"matched native source plane "+identity)
	check(tile.state!="completed" or tile.material_cells==compiled.projected_cells,"completed native material matches exact host projection "+identity)
	var checked_cells:=0;var changed_cells:=0
	for receipt: Dictionary in tile.receipts:checked_cells+=int(receipt.get("checked",0));changed_cells+=int(receipt.get("changed",0))
	row.actual_counts={"checked":checked_cells,"changed":changed_cells,"receipt_chunks":tile.receipts.size()};row["native_provenance"]=tile.provenance.duplicate(true)
	row["native_record_scope"]="Actual Batch native application/readback of the independently compiled frozen program; this apparatus does not substitute for live collaborative owner-approval lifecycle qualification."
	row.elapsed_usec=Time.get_ticks_usec()-started
	if tile.image!=null:tile.image.save_png(output.path_join("planes").path_join(identity+".native-material-id.png"))
	cases.append(row)

func write_manifest() -> void:
	write_json("cases.json",{"format":"cybersand-m67-composition-native-comparison-v1","source_revision":source_revision,"platform":OS.get_name(),"godot":Engine.get_version_info().string,
		"development_core_capacity":development_core_capacity,"registration_sha256":REGISTRATION_SHA,"heldout_sources":HELDOUT,"catalogue_id":Catalogue.CATALOGUE_ID,
		"catalogue_recipe_sha256":Compiler.digest(Compiler.canonical(Catalogue.recipes()).to_utf8_buffer()),"cases":cases,"source_observations":sources,"module_observations":module_observations,
		"frozen_catalogue_sha256":Catalogue.SHA256,"frozen_catalogue_source_commit":Catalogue.SOURCE_COMMIT,
		"harness_sha256":FileAccess.get_sha256("res://tests/test_architecture_composition_comparison.gd"),"recipes_sha256":FileAccess.get_sha256("res://scripts/batch_lab/architecture_comparison_recipes.gd"),
		"model_calls":0,"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"scope":"Registered deterministic tool/capability comparison with true native execution and retained refusals. No inference-quality, human-preference, physics or actor-traversal claim."})

func finish() -> void:
	if not output.is_empty():write_manifest()
	if controller!=null:controller.queue_free()
	print("M67_NATIVE_COMPOSITION_COMPARISON_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases.size(),"source_revision":source_revision}))
	quit(1 if not failures.is_empty() else 0)
