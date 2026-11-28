extends SceneTree
const Frozen=preload("res://scripts/batch_lab/architecture_comparison_catalogue.gd")
const Module=preload("res://scripts/batch_lab/native_module.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value:failures.append(label);push_error(label)
	return value
func _initialize() -> void:
	var frozen:=Frozen.load_frozen()
	if not check(frozen.ok,"exact pre-reveal recipe bytes"):finish();return
	var templates:=Frozen.template_library()
	if not check(templates.ok and templates.count==40,"forty frozen pure projected templates"):finish();return
	check(templates.library.summaries().all(func(row: Dictionary)->bool:return not row.native_readback_verified),"immutable source export cannot self-qualify native observations")
	var baseline:=OS.get_environment("M67_COMPARISON_BASELINE_DIR")
	var rows: Array=[]
	for recipe: Dictionary in frozen.recipes:
		var source:=Frozen.source_plane(recipe)
		var module: Dictionary=templates.library.get_module(recipe.id)
		check(source.ok and not module.is_empty(),"frozen source raster "+recipe.id)
		if baseline.is_empty():continue
		var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(baseline.path_join("records/module-"+str(recipe.id)+".json")))
		var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(baseline.path_join("modules/"+str(recipe.id)+".json")))
		check(Marshalls.base64_to_raw(record.material_cells_base64)==source.cells,"complete native baseline plane unchanged "+recipe.id)
		check(module.geometry.sha256==original.geometry.sha256,"exact harvested geometry unchanged "+recipe.id)
		check(Frozen.semantic_identity(module)==Frozen.semantic_identity(original),"exact authored metadata unchanged "+recipe.id)
		rows.append({"id":recipe.id,"source_sha256":source.sha256,"geometry_sha256":module.geometry.sha256,"semantic_sha256":Frozen.semantic_identity(module)})
	if not baseline.is_empty():
		var report:={"format":"cybersand-frozen-comparison-catalogue-equivalence-v1","passed":failures.is_empty(),"checks":checks,"failures":failures,
			"frozen_export_sha256":Frozen.SHA256,"recipe_sha256":Frozen.RECIPE_SHA256,"pre_reveal_catalogue_commit":Frozen.SOURCE_COMMIT,
			"baseline_source":"2861317ebe279dca8c2d000c48a6933221507aac","rows":rows,
			"scope":"Pure recipe projection and authored metadata checked against retained original actual native planes/exports. No new native attempts or copied current-session observation flags."}
		var file:=FileAccess.open(baseline.path_join("frozen-catalogue-equivalence-b.json"),FileAccess.WRITE);file.store_buffer(Module.json_bytes(report));file.close()
	finish()
func finish() -> void:
	print("M67_FROZEN_COMPARISON_CATALOGUE_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}));quit(1 if not failures.is_empty() else 0)
