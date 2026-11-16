extends SceneTree

# Project/preset compiler qualification. Actual native cells are separately
# exercised by test_architectural_generator.gd and the C++ material campaign.
const Project = preload("res://scripts/architectural_generator_project.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("MEGABLOCK_PROJECT " + label)

func _initialize() -> void:
	var preset: Dictionary = {}
	var matches := 0
	for item: Dictionary in Project.builtin_presets():
		if item.module == "seeded_typology_megablock":
			preset = item.duplicate(true)
			matches += 1
	check(matches == 1 and preset.get("module_version",0) == 1, "one explicit v1 preset")
	if preset.is_empty():
		quit(1)
		return
	var path := ProjectSettings.globalize_path("res://../examples/worldgen/architectural/seeded-typology-megablock.style.json")
	var imported: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(imported is Dictionary and Project.validate_preset(imported).is_empty(), "standalone style is valid")
	check(JSON.stringify(imported) == JSON.stringify(JSON.parse_string(JSON.stringify(preset))), "standalone style equals builtin")
	for extent: int in [256,512,1024]:
		for seed: int in [0,7,9007199254740991]:
			for windows: bool in [false,true]:
				for doors: bool in [false,true]:
					var project := Project.default_project()
					project.seed = seed
					project.origin = [-197,-151]
					project.extent = [extent,extent]
					project.automatic_tunnels = false
					project.automatic_windows = windows
					project.automatic_doors = doors
					project.styles = [{"enabled":true,"share":100.0,"preset":preset.duplicate(true)}]
					var result := Project.compile(project)
					check(result.get("ok",false), "existing project schema compiles")
					if not result.get("ok",false): continue
					var module: Dictionary = result.recipe.modules[0]
					check(module.module == "seeded_typology_megablock" and module.version == 1, "native identity")
					check(module.bounds == [-197,-151,extent,extent], "global module anchor including partial crops")
					check(module.parameters.automatic_windows == int(windows) and module.parameters.automatic_doors == int(doors), "existing aperture controls reach native parameters")
					check(module.parameters.bay_width == 96 and module.parameters.floor_height == 64 and module.parameters.wall == 4, "existing geometry controls reach native parameters")
	for geometry: Array in [[48,48,2],[128,96,5],[42,42,5]]:
		var changed := preset.duplicate(true)
		changed.geometry.room_size = geometry[0]
		changed.geometry.floor_height = geometry[1]
		changed.geometry.wall_thickness = geometry[2]
		check(Project.validate_preset(changed).is_empty(), "valid compact, large and minimum dimensions")
	for key: String in ["room_size","floor_height"]:
		var changed := preset.duplicate(true)
		changed.geometry[key] = 35
		check(not Project.validate_preset(changed).is_empty(), "collapsed clearances refused at project boundary")
	print("Megablock project: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
