extends SceneTree

# Independent compiler boundary checks: hostile JSON types, integer identity,
# measured zone connectivity/quotas and native admission of exact edge seeds.
const Project = preload("res://scripts/architectural_generator_project.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
# Keep this expected inventory independent of the production preset/catalogue lists.
const CLASSIC_MODULE_IDS: Array[String] = ["trestle","stacked_arcade","flying_buttress","sawtooth_gallery",
	"cantilever_spine","rib_vault","nested_arcade","suspended_deck",
	"bowstring_truss","diamond_truss","portal_frame","ladder_bridge","stepped_aqueduct","split_pier",
	"cable_gallery","clerestory_hall","mushroom_deck","zigzag_bridge","scalloped_vault","lattice_tower",
	"offset_arcade","bridgehouse","forked_gantry","buttress_wall",
	"fan_truss","pratt_truss","vierendeel_frame","suspension_pylon","harp_bridge","double_cantilever",
	"stepped_buttress","colonnade","basilica","crenellated_bridge","pointed_arcade","inverted_arch",
	"hourglass_pier","tripod_frame","chevron_hall","hanging_arcade","shelf_stack","staggered_balcony",
	"monopod_tower","wedge_gallery","crown_bridge","zigzag_pier","drum_vault","pyramidal_frame",
	"warren_truss","kingpost_frame","queenpost_frame","lenticular_bridge","radial_stay_bridge","twin_mast_bridge",
	"a_frame_hall","butterfly_hall","ziggurat_arcade","corbel_arcade","chain_vault","ring_pier",
	"folded_plate_hall","space_frame","crossbeam_stack","yoke_bridge","lantern_tower","spine_arcade",
	"cascade_terrace","inverted_trestle","cranked_beam","barrel_arcade","buttress_crown","triptych_arcade"]
const SHOWCASE_MODULE_IDS: Array[String] = ["megatruss_station","cathedral_megaframe",
	"seeded_typology_megablock","metabolist_spine","interlaced_viaduct","rosework_gatehouse",
	"interlock_brutalism","suspended_arcology"]
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("ARCH_PROJECT " + label)
	return ok

func refused(value: Variant, label: String) -> void:
	var result: Variant = Project.compile(value)
	check(result is Dictionary and result.get("ok", true) == false and result.get("error", null) is String and not str(result.get("error", "")).is_empty(), "actionable refusal: " + label)

func bad(path: Array, value: Variant, label: String) -> void:
	var input: Dictionary = Project.default_project()
	var cursor: Variant = input
	for index: int in range(path.size() - 1): cursor = cursor[path[index]]
	cursor[path[-1]] = value
	refused(input,label)

func hostile_json() -> void:
	for value: Variant in [null, true, 1, "project", [], [1]]:
		refused(value,"non-object top level " + str(value))
	for key: String in ["format", "version", "planner", "seed", "origin", "extent", "zone_scale", "corridor_width", "styles"]:
		for value: Variant in [null, true, "invalid", [], {}]:
			bad([key],value,key + " type " + type_string(typeof(value)))
	for key: String in ["automatic_tunnels", "automatic_doors", "automatic_windows"]:
		for value: Variant in [null, 1, "false", [], {}]:
			bad([key],value,key + " requires a Boolean")
	for value: Variant in [-1, 0.25, 9007199254740992, INF, NAN]: bad(["seed"],value,"non-exact/out-of-range seed")
	for value: Variant in [[], [0], [0,0,0], [true,0], [0.5,0], [INF,0], [-1000001,0], [999000,0]]:
		bad(["origin"],value,"invalid source coordinate " + str(value))
	for value: Variant in [[512,1024], [0,0], [4096,4096], [2048,1024], [false,512], [512.5,512], [512]]:
		bad(["extent"],value,"invalid extent " + str(value))
	for value: Variant in [0, 15, 63, 1024, 64.5]: bad(["zone_scale"],value,"invalid allocation scale " + str(value))
	for value: Variant in [[], [null], [{}], ["style"]]: bad(["styles"],value,"malformed style array")
	for value: Variant in [null, true, "style", [], {}]: bad(["styles",0,"preset"],value,"preset object boundary")
	for key: String in ["format", "version", "id", "name", "module", "module_version", "theme", "geometry", "materials", "apertures", "deterioration"]:
		for value: Variant in [null, true, "invalid", [], {}]:
			# Nonempty arbitrary names are valid; fields named apertures also
			# intentionally admit an empty dictionary for global inheritance.
			if (key in ["name", "id"] and value is String) or (key == "apertures" and value is Dictionary): continue
			bad(["styles",0,"preset",key],value,"preset " + key + " type " + type_string(typeof(value)))
	for key: String in ["room_size", "floor_height", "wall_thickness", "door_width", "shaft_width"]:
		for value: Variant in [null, true, "32", {}, [], 1.5, -1, INF, NAN]:
			bad(["styles",0,"preset","geometry",key],value,"geometry " + key + " invalid numeric value")
	for key: String in ["wall", "floor", "window"]:
		for value: Variant in [null, true, "62", {}, [], 1.5, 0, 256, INF, NAN]:
			bad(["styles",0,"preset","materials",key],value,"material " + key + " invalid numeric value")
	for value: Variant in [-0.1, 0.61, INF, NAN]: bad(["styles",2,"preset","deterioration"],value,"unbounded deterioration")
	for value: Variant in ["", "  ", "n".repeat(129)]: bad(["styles",0,"preset","name"],value,"invalid preset label")
	for value: Variant in ["", "MixedCase", "two words", "id/with/path", "i".repeat(65)]: bad(["styles",0,"preset","id"],value,"invalid stable preset identifier")
	for value: Variant in [{"automatic_doors":1}, {"automatic_windows":"false"}, {"automatic_windows":null}, {"unknown":true}]:
		bad(["styles",0,"preset","apertures"],value,"invalid aperture override")
	var unknown: Dictionary = Project.default_project()
	unknown.unapproved = true
	refused(unknown,"unknown project field")
	unknown = Project.default_project()
	unknown[7] = "not a JSON object key"
	refused(unknown,"non-string project key")
	unknown = Project.default_project()
	for _i: int in 3: unknown.styles.append(unknown.styles[0].duplicate(true))
	refused(unknown,"six slots exceed the five-style bound")
	for path: Array in [["styles",0,"share"], ["styles",0,"enabled"]]:
		for value: Variant in [null,"true",{},[]]: bad(path,value,"malformed selection or quota")
	for value: Variant in [-1, 101, INF, NAN]: bad(["styles",0,"share"],value,"nonfinite/out-of-range quota")
	unknown = Project.default_project()
	for style: Dictionary in unknown.styles: style.enabled = false
	refused(unknown,"no selected styles")
	unknown = Project.default_project()
	unknown.zone_scale = 512
	refused(unknown,"45/30/25 cannot meet two-point tolerance on four blocks")
	unknown = Project.default_project()
	unknown.styles[0].share = 0.0001
	unknown.styles[1].share = 74.9999
	refused(unknown,"positive selected style must receive at least one actual block")

func component_count(zones: Dictionary, slot: int) -> int:
	var width := int(zones.width)
	var height := int(zones.height)
	var visited := {}
	var count := 0
	for index: int in zones.cells.size():
		if int(zones.cells[index]) != slot or visited.has(index): continue
		count += 1
		var queue: Array[int] = [index]
		visited[index] = true
		var next := 0
		while next < queue.size():
			var point := Vector2i(queue[next] % width,queue[next] / width)
			next += 1
			for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var adjacent := point + delta
				if adjacent.x < 0 or adjacent.y < 0 or adjacent.x >= width or adjacent.y >= height: continue
				var cell := adjacent.y*width + adjacent.x
				if not visited.has(cell) and int(zones.cells[cell]) == slot:
					visited[cell] = true
					queue.append(cell)
	return count

func expanded_styles() -> void:
	var presets: Array = Project.builtin_presets()
	check(presets.size() >= 13, "thirteen or more selectable built-in styles")
	var ids := {}
	for preset: Dictionary in presets:
		check(Project.validate_preset(preset).is_empty(), "built-in style passes validation: " + str(preset.id))
		check(not ids.has(preset.id), "unique built-in style ID: " + str(preset.id))
		ids[preset.id] = true
	var five := Project.default_project()
	for index: int in range(3,5):
		five.styles.append({"enabled":true,"share":0.0,"preset":presets[index].duplicate(true)})
	for index: int in 5: five.styles[index].share = [25.0,25.0,25.0,12.5,12.5][index]
	for seed: int in [161803,271828,314159]:
		five.seed = seed
		for scale: int in [64,128,256]:
			five.zone_scale = scale
			var result: Dictionary = Project.compile(five)
			if not check(result.get("ok",false), "five-style seeded plan: %d/%d" % [seed,scale]): continue
			check(result.coverage.size() == 5 and result.recipe.modules.size() == 5, "five independent native modules and zone reports")
			for entry: Dictionary in result.coverage:
				check(component_count(result.zones,int(entry.slot)) == 1 and absf(float(entry.achieved_percent)-float(entry.requested_percent)) <= 2.0, "five-style connected quota")
			if seed == 161803 and scale == 64 and ClassDB.class_exists(&"CyberWorldGenerator"):
				var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
				var configured: Dictionary = generator.configure(result.recipe)
				check(configured.get("ok",false), "five-style native admission: " + str(configured.get("error","")))
				if configured.get("ok",false):
					var chunk: Dictionary = generator.generate_chunk(Vector2i.ZERO)
					check(chunk.get("ok",false), "five-style native material raster: " + str(chunk.get("error","")))
	five.styles.append({"enabled":false,"share":0.0,"preset":presets[5]})
	refused(five,"six style slots refused")

func new_native_algorithms() -> void:
	var catalogue: Array = Project.builtin_presets()
	var outputs := {}
	for module: String in ["terraced","hex_hive","arcade"]:
		var found: Dictionary = {}
		for preset: Dictionary in catalogue:
			if preset.module == module: found = preset.duplicate(true)
		if not check(not found.is_empty(), "native module has a selectable builtin preset: " + module): continue
		check(int(found.module_version) == 2 and Project.validate_preset(found).is_empty(),
			"owner-reviewed module has valid explicit v2 identity and geometry: " + module)
		var archived: Dictionary = found.duplicate(true)
		archived.module_version = 1
		check(Project.validate_preset(archived).is_empty(),
			"earlier native v1 generated-start recipes remain importable: " + module)
		var configured_project: Dictionary = Project.default_project()
		configured_project.styles = [{"enabled":true,"share":100.0,"preset":found}]
		var compilation: Dictionary = Project.compile(configured_project)
		if not check(compilation.get("ok",false), "new module compiles into native recipe: " + module): continue
		check(compilation.recipe.modules.size() == 1 and compilation.recipe.modules[0].module == module and
			int(compilation.recipe.modules[0].version) == 2, "refined native module v2 identity is preserved")
		if not ClassDB.class_exists(&"CyberWorldGenerator"): continue
		var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
		var admitted: Dictionary = generator.configure(compilation.recipe)
		if not check(admitted.get("ok",false), "new native module admitted: " + module + " " + str(admitted.get("error",""))): continue
		var cells: PackedByteArray = PackedByteArray()
		for cy: int in 2:
			for cx: int in 2:
				var packet: Dictionary = generator.generate_chunk(Vector2i(cx,cy))
				if check(packet.get("ok",false), "new module sampled: " + module + " " + str(packet.get("error",""))):
					cells.append_array(packet.cells)
		outputs[module] = Store.digest(cells)
	check(outputs.size() == 3 and outputs.terraced != outputs.hex_hive and
		outputs.hex_hive != outputs.arcade and outputs.arcade != outputs.terraced,
		"three new native algorithms produce materially distinct deterministic geometry")

func classic_genteks() -> void:
	var presets: Array = Project.builtin_presets()
	var hashes := {}
	for module: String in CLASSIC_MODULE_IDS + SHOWCASE_MODULE_IDS:
		var found: Dictionary = {}
		for preset: Dictionary in presets:
			if preset.module == module: found = preset.duplicate(true)
		if not check(not found.is_empty(), "classic Gentek builtin: " + module): continue
		check(int(found.module_version) == 1 and Project.validate_preset(found).is_empty(),
			"classic Gentek has valid v1 identity: " + module)
		if module == "cathedral_megaframe":
			for dimension: String in ["room_size","floor_height"]:
				var too_small: Dictionary = found.duplicate(true)
				too_small.geometry[dimension] = 6 * int(found.geometry.wall_thickness) + 15
				check(not Project.validate_preset(too_small).is_empty(), "Cathedral refuses collapsed nested openings: " + dimension)
				too_small.geometry[dimension] += 1
				check(Project.validate_preset(too_small).is_empty(), "Cathedral admits exact dimensional boundary: " + dimension)
		var bad_version: Dictionary = found.duplicate(true)
		bad_version.module_version = 2
		check(not Project.validate_preset(bad_version).is_empty(), "classic Gentek refuses v2: " + module)
		var configured: Dictionary = Project.default_project()
		configured.styles = [{"enabled":true,"share":100.0,"preset":found}]
		configured.extent = [512,512]
		var compiled: Dictionary = Project.compile(configured)
		if not check(compiled.get("ok",false), "classic Gentek compiles: " + module): continue
		check(compiled.recipe.modules.size() == 1 and compiled.recipe.modules[0].module == module and
			int(compiled.recipe.modules[0].version) == 1, "classic identity reaches recipe: " + module)
		if not ClassDB.class_exists(&"CyberWorldGenerator"): continue
		var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
		var admitted: Dictionary = generator.configure(compiled.recipe)
		if not check(admitted.get("ok",false), "classic native admission: " + module): continue
		var chunk: Dictionary = generator.generate_chunk(Vector2i.ZERO)
		if check(chunk.get("ok",false), "classic native raster: " + module):
			var digest: String = Store.digest(chunk.cells)
			check(not hashes.has(digest), "classic first-chunk geometry differs: " + module)
			hashes[digest] = module
	check(hashes.size() == 80, "eighty CLASSIC and showcase Genteks produce distinct first-chunk material geometry")

func planner_invariants() -> void:
	for seed: int in range(64):
		for scale: int in [64,128,256]:
			var input: Dictionary = Project.default_project()
			input.seed = seed
			input.origin = [-1031,-777]
			input.zone_scale = scale
			var before: Dictionary = input.duplicate(true)
			var result: Dictionary = Project.compile(input)
			if not check(result.get("ok",false), "seed/grid accepted %d/%d" % [seed,scale]): continue
			check(input == before,"compiler preserves caller ownership")
			var measured := {}
			for slot: int in result.zones.cells: measured[slot] = int(measured.get(slot,0)) + 1
			for entry: Dictionary in result.coverage:
				var actual: float = 100.0*int(measured.get(entry.slot,0))/result.zones.cells.size()
				check(component_count(result.zones,entry.slot) == 1, "independent four-connected zone %d/%d/%d" % [seed,scale,entry.slot])
				check(absf(actual-float(entry.requested_percent)) <= 2.0 and absf(actual-float(entry.achieved_percent)) < 0.0000001 and int(measured[entry.slot]) == int(entry.blocks), "measured quota and report agree")
	var single: Dictionary = Project.default_project()
	single.styles = [single.styles[1]]
	single.styles[0].share = 100.0
	single.zone_scale = 512
	var result: Dictionary = Project.compile(single)
	check(result.get("ok",false) and result.coverage.size() == 1 and result.coverage[0].achieved_percent == 100 and component_count(result.zones,0) == 1,"one-style coarse grid remains finite and connected")
	var pair: Dictionary = Project.default_project()
	pair.styles.resize(2)
	pair.styles[0].share = 50.0
	pair.styles[1].share = 50.0
	pair.zone_scale = 512
	result = Project.compile(pair)
	check(result.get("ok",false) and result.coverage.size() == 2 and component_count(result.zones,0) == 1 and component_count(result.zones,1) == 1,"two exact halves on a coarse grid remain connected")
	var sparse_slots: Dictionary = Project.default_project()
	sparse_slots.styles[0].enabled = false
	sparse_slots.styles[1].share = 60.0
	sparse_slots.styles[2].share = 40.0
	result = Project.compile(sparse_slots)
	check(result.get("ok",false) and result.coverage[0].slot == 1 and result.coverage[1].slot == 2 and not result.zones.cells.has(0),"disabled nonterminal slots do not relabel selected style identities")
	if result.get("ok",false):
		check(component_count(result.zones,1) == 1 and component_count(result.zones,2) == 1,"sparse selected slots retain independent connectivity")
	var custom: Dictionary = single.styles[0].preset.duplicate(true)
	custom.id = "custom-identity"
	custom.apertures = {"automatic_doors":false,"automatic_windows":false}
	var imported: Dictionary = Project.import_preset(single,custom,0)
	check(imported.get("ok",false) and imported.recipe.modules[0].parameters.automatic_doors == 0 and imported.recipe.modules[0].parameters.automatic_windows == 0,"custom aperture overrides are resolved into explicit native parameters")
	check(single.styles[0].preset.id != custom.id,"preset import does not mutate original project")
	check(not Project.import_preset(single,custom,1).get("ok",true) and not Project.import_preset(single,custom,-1).get("ok",true),"out-of-range imported style slots are actionable refusals")

func native_identity_edges() -> void:
	if not check(ClassDB.class_exists(&"CyberWorldGenerator"), "source-built native generator is required for identity edges"): return
	for seed: int in [0,9007199254740991]:
		var input: Dictionary = Project.default_project()
		input.seed = seed
		input.origin = [-1031,-777]
		input.automatic_tunnels = false
		var first: Dictionary = Project.compile(input)
		var second: Dictionary = Project.compile(JSON.parse_string(JSON.stringify(input)))
		if not check(first.get("ok",false) and second.get("ok",false),"edge seed compiles after JSON parsing"): continue
		check(first.recipe == second.recipe and first.project_hash == second.project_hash and first.zones == second.zones,"repeat/JSON compile preserves exact seed and resolved recipe")
		var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
		var first_config: Dictionary = generator.configure(first.recipe)
		if not check(first_config.get("ok",false),"edge seed native admission: " + str(first_config.get("error",""))): continue
		var coordinate := Vector2i(-8,-6)
		var packet: Dictionary = generator.generate_chunk(coordinate)
		# Adapter fingerprints include their revision. Reopen means a fresh
		# owner at revision one, not reconfiguration of the previous owner.
		var reopened: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
		var second_config: Dictionary = reopened.configure(second.recipe)
		var repeat: Dictionary = reopened.generate_chunk(coordinate)
		if not packet.get("ok",false) or not repeat.get("ok",false) or first_config.fingerprint != second_config.fingerprint:
			print("ARCH_PROJECT_EDGE seed=",seed," first_error=",packet.get("error","")," repeat_error=",repeat.get("error","")," first_fingerprint=",first_config.fingerprint," repeat_fingerprint=",second_config.fingerprint)
		check(packet.get("ok",false) and repeat.get("ok",false) and packet.cells == repeat.cells and first_config.fingerprint == second_config.fingerprint,"negative native chunk and recipe identity survive maximum/zero seed reconstruction")
		var corrupted: Dictionary = first.recipe.duplicate(true)
		corrupted.modules[0].parameters.wall_material = 10
		var refused_material: Dictionary = reopened.configure(corrupted)
		check(not refused_material.get("ok",true) and not str(refused_material.get("error","")).is_empty(),"native authority rejects reserved structural material with diagnosis")
		check(reopened.get_configuration() == second.recipe,"native failed custom material preserves accepted configuration")
	var catalogue_generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var catalogue: Dictionary = catalogue_generator.get_catalogue()
	# Zero denotes legacy entries that must omit minimum_recipe_schema entirely.
	# Explicit version keys also reject unintended Gentek v2 catalogue entries.
	var expected_schemas := {"arcology:1":0,"arcology:2":4,"vault:1":0,"vault:2":4,"aqueduct:1":0,
		"terraced:1":4,"terraced:2":4,"hex_hive:1":4,"hex_hive:2":4,"arcade:1":4,"arcade:2":4}
	for module: String in CLASSIC_MODULE_IDS + SHOWCASE_MODULE_IDS:
		expected_schemas[module + ":1"] = 4
	check(CLASSIC_MODULE_IDS.size() == 72 and SHOWCASE_MODULE_IDS.size() == 8 and expected_schemas.size() == 91,
		"expected catalogue names seventy-two CLASSIC v1, eight showcase v1 and eleven retained variants")
	var versions := {}
	for entry: Dictionary in catalogue.modules:
		var identity: String = str(entry.id) + ":" + str(entry.version)
		check(not versions.has(identity), "native catalogue module/version is unique: " + identity)
		versions[identity] = true
		if not check(expected_schemas.has(identity), "native catalogue has a reviewed module/version: " + identity): continue
		if int(expected_schemas[identity]) == 4:
			check(int(entry.get("minimum_recipe_schema", -1)) == 4,
				"schema-4-only catalogue variant declares its minimum schema: " + identity)
		else:
			check(not entry.has("minimum_recipe_schema"),
				"legacy module metadata remains free of schema-4 restrictions: " + identity)
	for identity: String in expected_schemas:
		check(versions.has(identity), "native catalogue exposes expected module/version: " + identity)
	check(catalogue.modules.size() == expected_schemas.size(),
		"native catalogue contains exactly the reviewed legacy and architectural variants")


func large_world_2048_contracts() -> void:
	# An expanded World has more raster cells, not additional native solver blocks.
	var project: Dictionary = Project.default_project()
	project.extent = [2048,2048]
	project.zone_scale = 128
	project.origin = [-256,384]
	project.seed = 1701
	var original: Dictionary = project.duplicate(true)
	var first: Dictionary = Project.compile(project)
	if not check(first.get("ok",false), "2048-square planner compiles: " + str(first.get("error",""))): return
	check(project == original, "large project compilation leaves the caller immutable")
	check(first.zones.width == 16 and first.zones.height == 16 and first.zones.cell_size == 128 and
			first.zones.cells.size() == 256, "2048-square uses exactly 256 native planner cells")
	check(first.recipe.spatial.assignments[0].specification.width == 16 and
			first.recipe.spatial.assignments[0].specification.height == 16 and
			first.recipe.spatial.assignments[0].specification.cell_size == 128,
			"native spatial assignment has no increased solver dimensions")
	check(first.recipe.modules.size() == 3 and first.recipe.modules[0].bounds == [-256,384,2048,2048],
			"2048-square native module bounds retain signed origin and complete extent")
	for coverage: Dictionary in first.coverage:
		check(component_count(first.zones,int(coverage.slot)) == 1,
			"2048-square style remains four-connected in the finite planning grid")
	var replay: Dictionary = Project.compile(JSON.parse_string(JSON.stringify(project)))
	check(replay.get("ok",false) and replay.recipe == first.recipe and
			replay.project_hash == first.project_hash and replay.zones == first.zones,
			"2048-square signed-origin compiler is deterministic after JSON roundtrip")
	var wrong_zone: Dictionary = project.duplicate(true)
	wrong_zone.zone_scale = 64
	refused(wrong_zone,"2048-square refuses a 32x32 planner instead of widening native limits")
	var unsupported: Dictionary = project.duplicate(true)
	unsupported.extent = [4096,4096]
	refused(unsupported,"4096-square remains reserved for independently qualified world-size work")
	unsupported.extent = [2048,1024]
	refused(unsupported,"rectangular extent is not silently admitted by this square project planner")
	var five: Dictionary = project.duplicate(true)
	var presets: Array = Project.builtin_presets()
	for slot: int in range(3,5):
		five.styles.append({"enabled":true,"share":0.0,"preset":presets[slot].duplicate(true)})
	for slot: int in five.styles.size():
		five.styles[slot].share = 20.0
	var result: Dictionary = Project.compile(five)
	if not check(result.get("ok",false), "five-style 2048-square compiles: " + str(result.get("error",""))): return
	check(result.recipe.modules.size() == 5 and result.zones.cells.size() == 256 and
			result.recipe.limits.max_operations_per_chunk == 160000000,
			"five-style 2048-square retains existing bounded native chunk work policy")
	if not check(ClassDB.class_exists(&"CyberWorldGenerator"), "native extension required for large-world contract"): return
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	if not check(generator.configure(result.recipe).get("ok",false), "2048-square native module plan admitted"): return
	for coordinate: Vector2i in [Vector2i(-2,3),Vector2i(13,18)]:
		var chunk: Dictionary = generator.generate_chunk(coordinate)
		check(chunk.get("ok",false) and chunk.get("state","") == "ready" and
				chunk.get("cells",PackedByteArray()).size() == 128*128,
				"2048-square signed-origin edge chunk produces actual native materials: " + str(coordinate))

func run() -> void:
	hostile_json()
	expanded_styles()
	new_native_algorithms()
	classic_genteks()
	planner_invariants()
	large_world_2048_contracts()
	native_identity_edges()
	print("ARCHITECTURAL_PROJECT_CONTRACT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
