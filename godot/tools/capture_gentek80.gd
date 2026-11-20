extends SceneTree

# GENTEK-80-INTEGRATION-001: ordinary project compiler and actual native chunks.
# This is a material preview/contract campaign; Workbench interaction is separate.
const Project = preload("res://scripts/architectural_generator_project.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
const Palette = preload("res://scripts/material_appearance_lut.gd")
const MaterialCatalogue = preload("res://scripts/material_lab_catalogue.gd")
const SHOWCASES: Array[String] = ["megatruss_station", "cathedral_megaframe",
	"seeded_typology_megablock", "metabolist_spine", "interlaced_viaduct",
	"rosework_gatehouse", "interlock_brutalism", "suspended_arcology"]
const BASE_SEED := 271828
var output := ""
var phase := "capture"
var selected_modules: PackedStringArray = []
var checks := 0
var failures: Array[String] = []
var cases: Array = []
var rejections: Array = []
var catalogue: RefCounted

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	var args := OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--output" and i + 1 < args.size(): output = args[i + 1]
		if args[i] == "--phase" and i + 1 < args.size(): phase = args[i + 1]
		if args[i] == "--modules" and i + 1 < args.size(): selected_modules = args[i + 1].split(",", false)
	if output.is_empty(): output = ProjectSettings.globalize_path("user://gentek80-campaign")
	DirAccess.make_dir_recursive_absolute(output)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("GENTEK80: " + label)
	return ok

func save_json(relative: String, value: Variant) -> void:
	var file := FileAccess.open(output.path_join(relative), FileAccess.WRITE)
	if check(file != null, "write " + relative): file.store_string(JSON.stringify(value, "\t", true, true) + "\n")

func write_cells(relative: String, cells: PackedByteArray) -> void:
	var file := FileAccess.open(output.path_join(relative), FileAccess.WRITE)
	if check(file != null, "write " + relative): file.store_buffer(cells)

func project_for(style: Dictionary, seed: int = BASE_SEED, extent: int = 512) -> Dictionary:
	var project: Dictionary = Project.default_project()
	project.extent = [extent, extent]
	project.seed = seed
	project.automatic_tunnels = false
	project.styles = [{"enabled":true,"share":100.0,"preset":style.duplicate(true)}]
	return project

func profiles(style: Dictionary) -> Array:
	var result: Array = [{"profile":"default","project":project_for(style)},
		{"profile":"seed-1701","project":project_for(style,1701)}]
	for spec: Array in [["compact",48,64,2],["tall",112,96,4]]:
		var variant: Dictionary = style.duplicate(true)
		variant.geometry.room_size = spec[1]
		variant.geometry.floor_height = spec[2]
		variant.geometry.wall_thickness = spec[3]
		variant.geometry.door_width = 10
		variant.geometry.shaft_width = 0
		result.append({"profile":spec[0],"project":project_for(variant)})
	var material_variant: Dictionary = style.duplicate(true)
	material_variant.materials = {"wall":58,"floor":62,"window":55}
	result.append({"profile":"material-controls","project":project_for(material_variant)})
	if str(style.module) in SHOWCASES:
		for control: String in ["automatic_windows","automatic_doors"]:
			var off: Dictionary = style.duplicate(true)
			off.apertures[control] = false
			result.append({"profile":"windows-off" if control == "automatic_windows" else "doors-off",
				"project":project_for(off)})
		var signed_project := project_for(style)
		signed_project.origin = [-517,-263]
		result.append({"profile":"signed-origin","project":signed_project})
		for wall: int in [1,5]:
			var thickness: Dictionary = style.duplicate(true)
			thickness.geometry.wall_thickness = wall
			result.append({"profile":"thin" if wall == 1 else "heavy","project":project_for(thickness)})
	# Challenge the ordinary maximum project size for every catalogue entry.
	result.append({"profile":"large-1024","project":project_for(style,BASE_SEED,1024)})
	return result

func raster(recipe: Dictionary, bounds: Rect2i, replay: bool = false) -> Dictionary:
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var began := Time.get_ticks_usec()
	var accepted: Dictionary = generator.configure(recipe)
	var prepare_us := Time.get_ticks_usec() - began
	if not check(accepted.get("ok",false), "native admission: " + str(accepted.get("error",""))): return {}
	var side := int(recipe.chunk_size)
	var coordinates: Array[Vector2i] = []
	for y: int in range(floori(float(bounds.position.y)/side), floori(float(bounds.end.y-1)/side)+1):
		for x: int in range(floori(float(bounds.position.x)/side), floori(float(bounds.end.x-1)/side)+1):
			coordinates.append(Vector2i(x,y))
	if replay: coordinates.reverse()
	var cells := PackedByteArray()
	cells.resize(bounds.size.x*bounds.size.y)
	var receipts: Dictionary = {}
	var native_us := 0
	var operations := 0
	began = Time.get_ticks_usec()
	for coordinate: Vector2i in coordinates:
		var clock := Time.get_ticks_usec()
		var packet: Dictionary
		if replay:
			packet = generator.begin_chunk(coordinate)
			var turns := 0
			while packet.get("ok",false) and packet.get("state","") != "ready" and turns < side*side/137+2:
				packet = generator.advance(137)
				turns += 1
		else:
			packet = generator.generate_chunk(coordinate)
		native_us += Time.get_ticks_usec()-clock
		if not check(packet.get("ok",false) and packet.get("state","") == "ready",
			"complete chunk " + str(coordinate) + ": " + str(packet.get("error",""))): return {}
		receipts[str(coordinate)] = packet.receipt_hash
		operations += int(packet.get("operations",0))
		for py: int in side:
			var gy: int = coordinate.y*side+py
			if gy < bounds.position.y or gy >= bounds.end.y: continue
			for px: int in side:
				var gx: int = coordinate.x*side+px
				if gx >= bounds.position.x and gx < bounds.end.x:
					cells[(gy-bounds.position.y)*bounds.size.x+gx-bounds.position.x] = packet.cells[py*side+px]
	return {"cells":cells,"material_sha256":Store.digest(cells),"fingerprint":accepted.fingerprint,
		"recipe_sha256":Store.recipe_hash(recipe),"receipts":receipts,"preparation_us":prepare_us,
		"native_raster_us":native_us,"raster_and_copy_us":Time.get_ticks_usec()-began,
		"logical_operations":operations,"material_bytes":cells.size(),"preview_rgba_bytes":4*cells.size(),
		"chunks":coordinates.size(),"preparation_receipt":accepted}

func render(case: Dictionary, index: int) -> void:
	var project: Dictionary = case.project
	var preset: Dictionary = project.styles[0].preset
	var name := str(preset.module) + "--" + str(case.profile)
	var started := Time.get_ticks_usec()
	var compiled: Dictionary = Project.compile(project)
	if not check(compiled.get("ok",false), name+" project compiles: "+str(compiled.get("error",""))):
		cases.append({"name":name,"status":"failure","stage":"project-compile","project":project,
			"error":compiled.get("error","")})
		return
	var bounds := Rect2i(Vector2i(int(project.origin[0]),int(project.origin[1])),Vector2i(int(project.extent[0]),int(project.extent[1])))
	var data := raster(compiled.recipe,bounds)
	if data.is_empty():
		cases.append({"name":name,"status":"failure","stage":"native-raster","project":project})
		return
	var counts: Dictionary = {}
	var occupancy := PackedByteArray()
	occupancy.resize(data.cells.size())
	var rgba := PackedByteArray()
	rgba.resize(4*data.cells.size())
	var valid := true
	for i: int in data.cells.size():
		var material := int(data.cells[i])
		if material >= catalogue.materials.size() or not catalogue.materials[material].get("valid",false): valid = false
		counts[str(material)] = int(counts.get(str(material),0))+1
		occupancy[i] = 0 if material == 0 else 1
		if material >= Palette.BASE_RGBA8.size(): continue
		var colour: int = int(Palette.BASE_RGBA8[material])
		rgba[4*i] = (colour>>24)&255
		rgba[4*i+1] = (colour>>16)&255
		rgba[4*i+2] = (colour>>8)&255
		rgba[4*i+3] = 255
	check(valid,name+" every output cell is in the actual accepted material catalogue")
	check(int(counts.get("0",0)) > 0 and int(counts.get("0",0)) < data.cells.size(),name+" has deliberate occupied and empty space")
	var image := Image.create_from_data(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8,rgba)
	check(image.save_png(output.path_join(name+".png")) == OK,name+" PNG saved")
	write_cells(name+".cells",data.cells)
	data.erase("cells")
	data.merge({"name":name,"status":"pass" if valid else "failure","index":index,
		"module":preset.module,"module_version":preset.module_version,"preset_id":preset.id,"label":preset.name,
		"family":"showcase" if str(preset.module) in SHOWCASES else "classic","profile":case.profile,
		"project":project,"project_sha256":compiled.project_hash,"extent":project.extent,
		"origin":project.origin,"seed":project.seed,"geometry":preset.geometry,"materials":preset.materials,
		"apertures":preset.apertures,"occupancy_sha256":Store.digest(occupancy),"material_counts":counts,
		"png":name+".png","raw":name+".cells","elapsed_us":Time.get_ticks_usec()-started,
		"godot_static_memory_bytes":OS.get_static_memory_usage(),"godot_static_peak_bytes":OS.get_static_memory_peak_usage()})
	if case.profile == "default":
		save_json(name+".project.json",project)
		save_json(name+".recipe.json",compiled.recipe)
	cases.append(data)
	print("GENTEK80 "+name+" "+str(data.material_sha256))

func refusal_cases(style: Dictionary) -> void:
	for spec: Array in [["room-outside-bounds","room_size",257],["door-does-not-fit","door_width",int(style.geometry.room_size)]]:
		var bad: Dictionary = style.duplicate(true)
		bad.geometry[spec[1]] = spec[2]
		var result: Dictionary = Project.compile(project_for(bad))
		var refused: bool = not result.get("ok",true) and not str(result.get("error","")).is_empty()
		check(refused,str(style.module)+" rejects "+str(spec[0]))
		rejections.append({"module":style.module,"profile":spec[0],"expected_refusal":true,
			"status":"pass" if refused else "failure","stage":"project","error":result.get("error",""),"project":project_for(bad)})
	var invalid_material: Dictionary = style.duplicate(true)
	invalid_material.materials.wall = 10
	var compiled: Dictionary = Project.compile(project_for(invalid_material))
	if check(compiled.get("ok",false),str(style.module)+" material existence remains native authority"):
		var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
		var result: Dictionary = generator.configure(compiled.recipe)
		var refused: bool = not result.get("ok",true) and not str(result.get("error","")).is_empty()
		check(refused,str(style.module)+" native catalogue rejects reserved material 10")
		rejections.append({"module":style.module,"profile":"reserved-material-10","expected_refusal":true,
			"status":"pass" if refused else "failure","stage":"native","error":result.get("error",""),
			"project":project_for(invalid_material)})

func replay_defaults() -> void:
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("native-campaign.json")))
	if not check(saved is Dictionary and saved.get("cases") is Array,"capture manifest exists before independent reload"): return
	for original: Dictionary in saved.cases:
		if original.get("profile","") != "default" or original.get("status","") != "pass": continue
		var project: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join(str(original.name)+".project.json")))
		var compiled: Dictionary = Project.compile(project)
		if not check(compiled.get("ok",false),str(original.name)+" JSON project reload"): continue
		check(compiled.project_hash == original.project_sha256,str(original.name)+" project identity survives reload")
		var bounds := Rect2i(Vector2i(int(project.origin[0]),int(project.origin[1])),Vector2i(int(project.extent[0]),int(project.extent[1])))
		var data := raster(compiled.recipe,bounds,true)
		if data.is_empty(): continue
		check(data.material_sha256 == original.material_sha256,str(original.name)+" process reload/reverse/sliced material equality")
		check(data.recipe_sha256 == original.recipe_sha256,str(original.name)+" canonical recipe equality")
		check(data.fingerprint == original.fingerprint,str(original.name)+" fingerprint equality")
		check(data.receipts == original.receipts,str(original.name)+" complete chunk receipt equality")
		data.erase("cells")
		data.merge({"name":original.name,"module":original.module,"profile":"process-reload-reverse-sliced"})
		cases.append(data)
		print("GENTEK80 replay "+str(original.name))

func run() -> void:
	var started := Time.get_ticks_usec()
	if not check(ClassDB.class_exists(&"CyberWorldGenerator"),"source-built native generator is available"):
		finish(started)
		return
	catalogue = MaterialCatalogue.new()
	if not check(catalogue.reload(),"actual native material catalogue: "+str(catalogue.error)):
		finish(started)
		return
	if phase == "replay":
		replay_defaults()
		finish(started)
		return
	if not check(phase == "capture","known campaign phase"):
		finish(started)
		return
	var styles: Array = []
	var seen: Dictionary = {}
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var native_catalogue: Dictionary = generator.get_catalogue()
	var native_ids: Dictionary = {}
	for module: Dictionary in native_catalogue.modules:
		var identity := str(module.id)+":"+str(module.version)
		check(not native_ids.has(identity),"native identity unique "+identity)
		native_ids[identity] = module
	for style: Dictionary in Project.builtin_presets():
		check(not seen.has(style.id),"unique selectable preset "+str(style.id))
		seen[style.id] = true
		if int(style.module_version) != 1: continue
		styles.append(style)
		var identity := str(style.module)+":1"
		check(native_ids.has(identity) and int(native_ids[identity].get("minimum_recipe_schema",0)) == 4,
			"UI/native schema-4 Gentek equivalence "+identity)
	check(styles.size() == 80,"exactly 80 Genteks")
	check(Project.builtin_presets().size() == 93,"80 Genteks plus 13 preserved legacy presets")
	check(native_ids.size() == 91,"80 Genteks plus 11 preserved native module/version identities")
	if not selected_modules.is_empty():
		var filtered: Array = []
		for style: Dictionary in styles:
			if str(style.module) in selected_modules: filtered.append(style)
		check(filtered.size() == selected_modules.size(),"all requested campaign modules exist")
		styles = filtered
	save_json("catalogue.json",{"genteks":styles,"native":native_catalogue,"material_metadata":catalogue.native_metadata,
		"materials":catalogue.materials,"render_kind":"native chunk cells through ordinary project compiler; opaque material palette"})
	var index := 0
	for style: Dictionary in styles:
		index += 1
		for case: Dictionary in profiles(style): render(case,index)
		refusal_cases(style)
	var material_hashes: Dictionary = {}
	var occupancy_hashes: Dictionary = {}
	for case: Dictionary in cases:
		if case.get("profile","") != "default" or case.get("status","") != "pass": continue
		check(not material_hashes.has(case.material_sha256),str(case.module)+" default native material output is unique")
		check(not occupancy_hashes.has(case.occupancy_sha256),str(case.module)+" default occupied/empty silhouette is unique")
		material_hashes[case.material_sha256] = case.module
		occupancy_hashes[case.occupancy_sha256] = case.module
	check(material_hashes.size() == styles.size(),"complete distinct default gallery")
	finish(started)

func finish(started: int) -> void:
	var report := {"schema":1,"phase":phase,"complete":true,"checks":checks,"failures":failures,
		"cases":cases,"rejections":rejections,"elapsed_us":Time.get_ticks_usec()-started,
		"godot_version":Engine.get_version_info(),"platform":OS.get_name(),
		"godot_static_peak_bytes":OS.get_static_memory_peak_usage()}
	save_json("native-campaign.json" if phase == "capture" else "process-reload.json",report)
	print("GENTEK80 RESULT checks="+str(checks)+" failures="+str(failures.size())+" cases="+str(cases.size()))
	quit(0 if failures.is_empty() else 1)
