extends SceneTree
const Recipes=preload("res://scripts/batch_lab/architecture_comparison_recipes.gd")
const Catalogue=preload("res://scripts/batch_lab/architecture_comparison_catalogue.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
var checks:=0
var failures:=0
func check(value: bool,label: String) -> void:
	checks+=1; print("M67_RECIPE_CHECK ",label," ",value)
	if not value:failures+=1;push_error(label)
func _initialize() -> void:
	var templates:=Catalogue.template_library()
	check(templates.ok,"unqualified templates available for pure baseline construction")
	for brief: Dictionary in Recipes.development_briefs():
		var source:=Recipes.source_plane(brief)
		check(source.ok,"frozen scalar source "+brief.id)
		var hashes: Array=[]
		for arm: String in ["hand_typed","procedural_structure","reference_guided"]:
			var built:=Recipes.build(brief,arm,47017,templates.library)
			check(built.ok,"registered finite baseline "+brief.id+" "+arm)
			if not built.ok:continue
			var compiled:=Compiler.compile(built.stage,{"region":[0,0,256,192],"world_region":[0,0,256,192],"source_cells":source.cells,"source_sha256":source.sha256,"generation":1,"paused":true,"allowed_materials":[0,7,28,58]},templates.library)
			hashes.append(compiled.get("projected_sha256","refused:"+str(compiled.get("reason",""))))
			print("M67_DEVELOPMENT_BASELINE ",brief.id," ",arm," ",compiled.ok," ",compiled.get("reason",""))
		check(hashes[0]!=hashes[1] or hashes[1]!=hashes[2],"new development arms are not all equivalent "+brief.id)
	check(not Recipes.build(Recipes.development_briefs()[0],"retrieval_guided",47017,templates.library).ok,"native comparison cannot run imported template claims as qualified parts")
	print("M67_COMPARISON_RECIPES: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
