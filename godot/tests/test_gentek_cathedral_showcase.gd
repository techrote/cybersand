extends "res://tests/test_architectural_generator.gd"

# Reuse GEN-007's actual CyberWorldGenerator readback and material LUT preview.
# The sibling JSON projects/recipes and .materials.u8 files are the source maps;
# crops never replace them. There is no second terrain rasterizer in this test.
var maps: Dictionary = {}

func cathedral_preset(module: String = "cathedral_megaframe") -> Dictionary:
	for preset: Dictionary in Project.builtin_presets():
		if preset.module == module: return preset.duplicate(true)
	check(false, "showcase preset exists: " + module)
	return {}

func capture(spec: Dictionary) -> void:
	var label: String = spec.name
	var preset := cathedral_preset(spec.get("module", "cathedral_megaframe"))
	if preset.is_empty(): return
	if bool(spec.get("match_hero",false)):
		var hero: Dictionary = cathedral_preset()
		preset.geometry = hero.geometry.duplicate(true)
		preset.materials = hero.materials.duplicate(true)
		preset.theme = hero.theme
	for key: String in spec.get("geometry", {}): preset.geometry[key] = spec.geometry[key]
	var project: Dictionary = Project.default_project()
	var size: int = spec.get("size", 512)
	project.extent = [size, size]
	project.origin = spec.get("origin", [0, 0])
	project.seed = spec.get("seed", 271828)
	project.automatic_tunnels = false
	project.automatic_windows = spec.get("windows", true)
	project.automatic_doors = spec.get("doors", true)
	project.styles = [{"enabled":true,"share":100.0,"preset":preset}]
	var compiled: Dictionary = Project.compile(project)
	if not check(compiled.get("ok", false), label + " project compiles: " + str(compiled.get("error", ""))): return
	var bounds := Rect2i(Vector2i(project.origin[0], project.origin[1]), Vector2i(size, size))
	var data: Dictionary = generation(compiled.recipe, bounds)
	if not data.has("cells"): return
	var materials: PackedByteArray = data.cells
	var counts: Dictionary = {}
	for material: int in materials: counts[material] = int(counts.get(material, 0)) + 1
	check(int(counts.get(0, 0)) > size * size / 5, label + " retains substantial negative space")
	check(int(counts.get(0, 0)) < size * size * 19 / 20, label + " contains substantial architecture")
	preview(label, materials, Vector2i(size, size))
	write_json(label + ".project.json", compiled.project)
	write_json(label + ".recipe.json", compiled.recipe)
	var raw := FileAccess.open(output_dir().path_join(label + ".materials.u8"), FileAccess.WRITE)
	if check(raw != null, label + " retains full native material map"): raw.store_buffer(materials)
	var recorded: Dictionary = data.duplicate(true)
	recorded.erase("cells")
	recorded.merge({"name":label,"module":preset.module,"module_version":preset.module_version,
		"seed":project.seed,"origin":project.origin,"extent":project.extent,
		"geometry":preset.geometry,"windows":project.automatic_windows,"doors":project.automatic_doors,
		"material_counts":counts,"negative_space_fraction":float(counts.get(0, 0)) / materials.size(),
		"png_sha256":FileAccess.get_sha256(output_dir().path_join(label + ".png"))})
	report.cases.append(recorded)
	maps[label] = {"data":data,"recipe":compiled.recipe,"bounds":bounds,"project":compiled.project}
	print("CATHEDRAL_CAPTURE name=", label, " sha256=", data.material_sha256,
		" native_us=", data.native_raster_us, " void=", recorded.negative_space_fraction)

func compare_pair(left: String, right: String, context: String) -> void:
	if not maps.has(left) or not maps.has(right): return
	var material_delta := changed_cells(maps[left].data.cells, maps[right].data.cells)
	var occupancy_delta := changed_cells(maps[left].data.cells, maps[right].data.cells, true)
	check(material_delta > 0, context + " changes native material output")
	if context in ["room-size response","floor-height response","wall-mass response","portal toggle"]:
		check(occupancy_delta > 0, context + " changes structure rather than only material assignment")
	if context == "clerestory toggle":
		check(occupancy_delta == 0, "clerestory switch preserves every occupied structural cell")
		var glazed: PackedByteArray = maps[left].data.cells
		var opaque: PackedByteArray = maps[right].data.cells
		var glazing: int = maps[left].project.styles[0].preset.materials.window
		var wall: int = maps[left].project.styles[0].preset.materials.wall
		var changed_only_glazing := true
		for i: int in glazed.size():
			if glazed[i] != opaque[i] and not (glazed[i] == glazing and opaque[i] == wall):
				changed_only_glazing = false
		check(changed_only_glazing, "windows off substitutes only glazing with structural wall")
		check(not opaque.has(glazing) and glazed.has(glazing), "glazing disappears cleanly with windows disabled")
	report.cases.append({"case":context,"left":left,"right":right,
		"different_material_cells":material_delta,"different_occupied_empty_cells":occupancy_delta})

func replay_contracts() -> void:
	var name := "cathedral-megaframe-hero-512"
	if not maps.has(name): return
	var original: Dictionary = maps[name]
	for mode: String in ["same-seed", "reverse-order", "sliced"]:
		var repeated := generation(original.recipe, original.bounds, mode == "reverse-order", mode == "sliced")
		if not repeated.has("cells"): continue
		check(repeated.cells == original.data.cells, mode + " replays byte-identical material cells")
		check(repeated.receipts == original.data.receipts, mode + " replays identical chunk receipts")
		report.cases.append({"case":mode,"material_sha256":repeated.material_sha256,
			"receipt_count":repeated.receipts.size(),"identical_cells":repeated.cells == original.data.cells,
			"identical_receipts":repeated.receipts == original.data.receipts})
	var signed_project: Dictionary = original.project.duplicate(true)
	signed_project.origin = [-385, -257]
	var compiled := Project.compile(signed_project)
	if not check(compiled.get("ok", false), "signed-coordinate project compiles"): return
	var bounds := Rect2i(-385, -257, 512, 512)
	var a := generation(compiled.recipe, bounds)
	var b := generation(compiled.recipe, bounds, true, true)
	if not a.has("cells") or not b.has("cells"): return
	check(a.cells == b.cells and a.receipts == b.receipts, "negative/global origin is order and slicing invariant")
	write_json("cathedral-megaframe-signed-origin.recipe.json", compiled.recipe)
	report.cases.append({"case":"signed-origin-order-slicing","origin":[-385,-257],
		"material_sha256":a.material_sha256,"identical_cells":a.cells == b.cells,
		"identical_receipts":a.receipts == b.receipts,"receipts":a.receipts})

func detail_crops() -> void:
	var name := "cathedral-megaframe-hero-1024"
	if not maps.has(name): return
	var source := Image.load_from_file(output_dir().path_join(name + ".png"))
	if not check(source != null, "detail crops use retained 1024 native source PNG"): return
	# Both are literal 1:1 crops; coordinates are recorded for independent replay.
	for crop: Dictionary in [
		{"name":"cathedral-megaframe-detail-apex-buttress", "rect":[0,0,384,192]},
		{"name":"cathedral-megaframe-detail-arcade-clerestory", "rect":[0,144,384,208]}]:
		var r: Array = crop.rect
		var detail := source.get_region(Rect2i(r[0],r[1],r[2],r[3]))
		check(detail.save_png(output_dir().path_join(crop.name + ".png")) == OK, "retained detail crop " + crop.name)
		report.cases.append({"case":"detail-crop","name":crop.name,"source":name + ".png", "rect":r,
			"source_material_sha256":maps[name].data.material_sha256})

func benchmark() -> void:
	# End-to-end native chunk calls include the same recipe/mask overhead in all arms.
	# First sample is warmup; five measured repeats report median and spread.
	var rows: Array = []
	for name: String in ["comparison-arched-viaduct", "comparison-nested-arcade", "cathedral-megaframe-hero-512"]:
		if not maps.has(name): continue
		var sample: Dictionary = maps[name]
		var times: Array[int] = []
		for turn: int in 6:
			var run_data := generation(sample.recipe, sample.bounds)
			if not run_data.has("cells"): continue
			check(run_data.cells == sample.data.cells, name + " benchmark remains deterministic")
			if turn > 0: times.append(run_data.native_raster_us)
		if not check(times.size() == 5, name + " supplies five measured timings"): continue
		times.sort()
		rows.append({"name":name,"native_raster_us_sorted":times,"median_us":times[2],
			"cells":512*512,"median_ns_per_cell":float(times[2])*1000.0/(512*512)})
	report.performance = {"description":"one warmup, five measured full native 512x512 chunk generations; matched seed, geometry, palette and existing spatial-mask/receipt path",
		"clock":"Godot monotonic Time.get_ticks_usec","rows":rows}

func mixed_style_authoring(reopening: bool) -> void:
	# Called by the existing test's real Shared Workbench startup path.
	var save_name := "cathedral-megaframe-showcase"
	var project: Dictionary = Project.default_project()
	project.extent = [512,512]
	project.seed = 271828
	project.automatic_tunnels = false
	project.styles = [{"enabled":true,"share":100.0,"preset":cathedral_preset()}]
	var saved: Dictionary = {}
	if reopening:
		saved = Store.read_named(save_name)
		if not check(saved.get("generated",false), "fresh process reads Cathedral generated-start save"): return
		wb._name.text = save_name
		preview_clock.begin()
		if not check(wb.load_setup(), "existing Load reconstructs Cathedral recipe"): return
	else:
		dialog.open_new()
		if not await architectural_form_views(project): return
		preview_clock.begin()
		dialog._architecture._apply()
	if not await preview_ready("cathedral-preview-reopened" if reopening else "cathedral-preview-new"): return
	var packet: Dictionary = dialog._ready_packet.duplicate(true)
	check(packet.recipe.modules.size() == 1 and packet.recipe.modules[0].module == "cathedral_megaframe" and
		packet.recipe.modules[0].version == 1, "real preview preserves Cathedral v1 native module identity")
	check(packet.cells.size() == 512*512 and packet.receipt_hashes.size() == 16,
		"actual preview has all native material cells and chunk receipts")
	dialog.confirmed.emit()
	dialog.hide()
	if not await until(func() -> bool: return installed() and str(wb._generated_active.get("sha256","")) == str(packet.sha256),
		"Cathedral proposal installed into ordinary native Workbench"): return
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt",{})
	check(receipt.get("generated_source_sha256", "") == packet.sha256,
		"native constructor independently acknowledges Cathedral materials")
	if reopening:
		check(wb.applied.edits == saved.setup.edits, "Cathedral save preserves ordered authored edits")
		check(wb._generated_active.recipe_sha256 == saved.generation.recipe_sha256,
			"Cathedral native recipe provenance survives process restart")
		if not await until(func() -> bool: return host.image.get_width() == 512 and host.image.get_pixel(101,99).r8 == 58,
			"Cathedral authored native cell survives fresh-process reconstruction"): return
	else:
		wb._brush.value = 2
		if not check(wb.paint(Vector2i(101,99),58), "ordinary paint over Cathedral generated start"): return
		if not await until(func() -> bool: return host.image.get_width() == 512 and host.image.get_pixel(101,99).r8 == 58,
			"native Cathedral paint acknowledged"): return
		if not await until(paint_completed, "Cathedral edit receipts finish before Save"): return
		wb._name.text = save_name
		if not check(wb.save_setup(), "existing Save retains Cathedral generated baseline and authored edit"): return
		saved = Store.read_named(save_name)
		check(saved.get("generated",false) and saved.setup.edits.size() >= 1,
			"Cathedral persisted as ordinary generated-start v1")
	await framebuffer("cathedral-workbench-reopened" if reopening else "cathedral-workbench-authored")
	report.cases.append({"case":"cathedral-reopen" if reopening else "cathedral-author",
		"material_sha256":packet.sha256,"recipe_sha256":packet.recipe_sha256,
		"native_receipts":packet.receipt_hashes.size(),"display":DisplayServer.get_name(),
		"save_name":save_name,"authored_edits":saved.setup.edits.size()})
	complete = true

func run() -> void:
	var began := Time.get_ticks_usec()
	report = {"schema":1,"case":"GENTEK-SHOWCASE-CATHEDRAL-001","cases":[],
		"godot":Engine.get_version_info().string,"os":OS.get_name(),"display":DisplayServer.get_name(),
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_COMMIT"),
		"runtime_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
		"palette_sha256":FileAccess.get_sha256("res://scripts/material_appearance_lut.gd"),
		"source_map_encoding":"row-major uint8 native material IDs; no rescale or recolouring beyond existing BASE_RGBA8 LUT"}
	var phase := OS.get_environment("CYBERSAND_CATHEDRAL_PHASE")
	if phase in ["author","reopen"]:
		if check(ClassDB.class_exists(&"CyberWorldGenerator"), "source-built native generator available"):
			await authoring(phase == "reopen", true)
		check(complete, "mandatory complete Cathedral " + phase + " phase")
		var phase_file := FileAccess.open(output_dir().path_join("cathedral-" + phase + "-report.json"), FileAccess.WRITE)
		check(phase_file != null, "write Cathedral " + phase + " final evidence")
		report.merge({"phase":phase,"checks":checks,"failures":failures,"complete":complete,
			"elapsed_us":Time.get_ticks_usec()-began})
		if phase_file != null: phase_file.store_string(JSON.stringify(report,"\t",true,true) + "\n")
		if host != null:
			preview_clock.queue_free()
			host.queue_free()
			await process_frame
			await process_frame
		print("CATHEDRAL_WORKBENCH_RESULTS phase=",phase," checks=",checks," failures=",failures," complete=",complete)
		quit(1 if failures else 0)
		return
	var specs: Array[Dictionary] = [
		{"name":"cathedral-megaframe-hero-512"},
		{"name":"cathedral-megaframe-hero-1024", "size":1024},
		{"name":"cathedral-megaframe-seed-a", "seed":271828},
		{"name":"cathedral-megaframe-seed-b", "seed":314159},
		{"name":"cathedral-megaframe-seed-c", "seed":161803},
		{"name":"cathedral-megaframe-seed-d", "seed":57721},
		{"name":"cathedral-megaframe-compact", "geometry":{"room_size":48,"floor_height":64}},
		{"name":"cathedral-megaframe-broad", "geometry":{"room_size":96}},
		{"name":"cathedral-megaframe-tall", "geometry":{"floor_height":128}},
		{"name":"cathedral-megaframe-thin", "geometry":{"wall_thickness":1}},
		{"name":"cathedral-megaframe-heavy", "geometry":{"wall_thickness":5}},
		{"name":"cathedral-megaframe-windows-on", "windows":true},
		{"name":"cathedral-megaframe-windows-off", "windows":false},
		{"name":"cathedral-megaframe-doors-on", "doors":true},
		{"name":"cathedral-megaframe-doors-off", "doors":false},
		{"name":"cathedral-megaframe-limit", "geometry":{"room_size":46,"floor_height":46,"wall_thickness":5,"door_width":10}},
		{"name":"comparison-arched-viaduct", "module":"arcade", "match_hero":true},
		{"name":"comparison-pointed-arcade", "module":"pointed_arcade", "match_hero":true},
		{"name":"comparison-basilica", "module":"basilica", "match_hero":true},
		{"name":"comparison-nested-arcade", "module":"nested_arcade", "match_hero":true}]
	var only := OS.get_environment("CYBERSAND_CATHEDRAL_CASES")
	if check(ClassDB.class_exists(&"CyberWorldGenerator"), "source-built native generator available"):
		for spec: Dictionary in specs:
			if not only.is_empty() and spec.name not in only.split(","): continue
			capture(spec)
	if only.is_empty():
		check(maps.size() == specs.size(), "all sixteen required Cathedral maps and four comparisons retained")
		var seed_hashes: Dictionary = {}
		for suffix: String in ["a","b","c","d"]:
			var key := "cathedral-megaframe-seed-" + suffix
			if maps.has(key): seed_hashes[maps[key].data.material_sha256] = true
		check(seed_hashes.size() == 4, "four selected seeds produce distinct native material maps")
		for pair: Array in [
			["hero-512","broad","room-size response"], ["hero-512","tall","floor-height response"],
			["thin","heavy","wall-mass response"], ["windows-on","windows-off","clerestory toggle"],
			["doors-on","doors-off","portal toggle"]]:
			compare_pair("cathedral-megaframe-" + pair[0], "cathedral-megaframe-" + pair[1], pair[2])
		for key: String in ["comparison-arched-viaduct","comparison-pointed-arcade","comparison-basilica"]:
			compare_pair("cathedral-megaframe-hero-512", key, "hierarchical geometry comparison")
		replay_contracts()
		benchmark()
	detail_crops()
	report.partial_iteration = not only.is_empty()
	var final_file := FileAccess.open(output_dir().path_join("cathedral-showcase-report.json"), FileAccess.WRITE)
	check(final_file != null, "write complete Cathedral campaign evidence")
	report.checks = checks
	report.failures = failures
	report.elapsed_us = Time.get_ticks_usec() - began
	if final_file != null: final_file.store_string(JSON.stringify(report,"\t",true,true) + "\n")
	print("CATHEDRAL_RESULTS checks=", checks, " failures=", failures, " maps=", maps.size())
	quit(1 if failures else 0)
