extends "res://tests/test_architectural_generator.gd"

# GENTEK-2048-001: actual 2048-square Shared Workbench source, author,
# cancellation, saved-start and independent application-process restoration.
# Do not replace the 512/1024 oracle or alter the native module catalogue.
const CASES: Array[String] = ["cathedral", "mixed"]
const SIZE := 2048
const GRID := 16
const ZONE := 128

func _project_for(kind: String) -> Dictionary:
	var result: Dictionary = Project.default_project()
	result.extent = [SIZE, SIZE]
	result.zone_scale = ZONE
	result.seed = 605 if kind == "cathedral" else 1701
	result.origin = [0, 0] if kind == "cathedral" else [-256, 384]
	result.automatic_tunnels = false
	var ids: Array[String] = ["cathedral_megaframe"]
	if kind == "mixed":
		ids = ["cathedral_megaframe", "megatruss_station", "seeded_typology_megablock",
			"interlaced_viaduct", "suspended_arcology"]
	result.styles.clear()
	for i: int in ids.size():
		var chosen: Dictionary = {}
		for preset: Dictionary in Project.builtin_presets():
			if preset.module == ids[i]:
				chosen = preset.duplicate(true)
				break
		if chosen.is_empty():
			check(false, "missing reviewed Gentek " + ids[i])
			return {}
		result.styles.append({"enabled": true, "share": 100.0 / ids.size(), "preset": chosen})
	return result

func _case(kind: String, reopening: bool) -> bool:
	var label := "gentek2048-" + kind
	var authored: Dictionary = _project_for(kind)
	if not check(not authored.is_empty(), label + " has source-bound style selection"): return false
	var compiled: Dictionary = Project.compile(authored)
	if not check(compiled.get("ok", false), label + " compiles: " + str(compiled.get("error", ""))): return false
	check(int(compiled.zones.width) == GRID and int(compiled.zones.height) == GRID and
		int(compiled.zones.cell_size) == ZONE and compiled.zones.cells.size() == GRID * GRID,
		label + " uses 256 native planning cells, not a larger solver")
	for coverage: Dictionary in compiled.coverage:
		check(components(compiled.zones, int(coverage.slot)) == 1,
			label + " style remains connected in the finite planning grid")
	var save_name := label + "-start"
	var saved: Dictionary = {}
	wb._name.text = save_name
	preview_clock.begin()
	if reopening:
		saved = Store.read_named(save_name)
		if not check(saved.get("generated", false), label + " saved native start found in a fresh process"): return false
		if not check(wb.load_setup(), label + " starts actual fresh-process native regeneration"): return false
	else:
		if not check(dialog.start_architectural(authored), label + " ordinary 2048-square generator started"): return false
	if not await preview_ready(label + ("-reopen" if reopening else "-author")): return false
	var packet: Dictionary = dialog._ready_packet.duplicate(true)
	if not check(packet.extent == Vector2i(SIZE, SIZE) and packet.cells.size() == SIZE * SIZE,
			label + " contains 4194304 actual native material cells"): return false
	check(packet.receipt_hashes.size() == 256, label + " exactly 256 source chunk receipts")
	check(packet.sha256 == Store.digest(packet.cells) and packet.recipe_sha256 == Store.recipe_hash(packet.recipe),
		label + " material and compiled recipe provenance match native bytes")
	check(dialog._preview.texture != null and dialog._preview.texture.get_size() == Vector2(SIZE, SIZE),
		label + " preview texture retains full 2048-square dimensions")
	if reopening:
		check(packet.sha256 == saved.generation.sha256 and
			packet.recipe_sha256 == saved.generation.recipe_sha256 and
			packet.receipt_hashes == saved.generation.receipt_hashes,
			label + " fresh native output exactly reconstructs saved material/receipts")
	else:
		check(dialog._architecture_result.zones.width == GRID and
			dialog._architecture_result.zones.height == GRID,
			label + " Workbench receives the original 16x16 zone diagnostics")
		dialog._zone_toggle.button_pressed = true
		check(dialog._zone_overlay.visible, label + " visible zone overlay")
		await framebuffer(label + "-zones", dialog)
		dialog._zone_toggle.button_pressed = false
	if not check(dialog.attests(packet), label + " generated map is eligible for explicit installation"): return false
	dialog.confirmed.emit()
	dialog.hide()
	var target_installed := func() -> bool:
		return installed() and host.image.get_width() == SIZE and host.image.get_height() == SIZE and str(wb._generated_active.get("sha256", "")) == str(packet.sha256)
	if not await until(target_installed, label + " actual 2048 World installed by native owner"): return false
	check(host.tower_context.get("liquid_construction_receipt", {}).get("generated_source_sha256", "") == packet.sha256,
		label + " native construction receipt acknowledges exact material image")
	if reopening:
		check(saved.setup.edits.size() >= 2 and wb.applied.edits == saved.setup.edits,
			label + " ordered authored paint/erase survives fresh-process reconstruction")
		check(host.image.get_pixel(101, 99).r8 == 58 and host.image.get_pixel(111, 99).r8 == 0,
			label + " distant generated and authored material cells survive reopen")
	else:
		wb._brush.value = 2
		if not check(wb.paint(Vector2i(101, 99), 58), label + " ordinary paint accepted"): return false
		if not await until(func() -> bool: return host.image.get_pixel(101, 99).r8 == 58, label + " native material paint readback"): return false
		if not check(wb.paint(Vector2i(111, 99), 0), label + " ordinary erase accepted"): return false
		if not await until(func() -> bool: return host.image.get_pixel(111, 99).r8 == 0, label + " native erase readback"): return false
		if not await until(paint_completed, label + " paint completion receipts before save"): return false
		if not check(wb.save_setup(), label + " saves the generated baseline and edits"): return false
		saved = Store.read_named(save_name)
		check(saved.get("generated",false) and saved.setup.edits.size() >= 2 and
			saved.generation.sha256 == packet.sha256,
			label + " persisted generated start contains exact provenance and edits")
		var original_epoch: int = host._physical_epoch
		var invalid: Dictionary = authored.duplicate(true)
		invalid.extent = [4096,4096]
		check(not dialog.start_architectural(invalid), label + " 4096 remains explicitly refused")
		check(installed() and host._physical_epoch == original_epoch and
			wb._generated_active.sha256 == packet.sha256,
			label + " refused unsupported extent preserves the installed World")
		var changed: Dictionary = authored.duplicate(true)
		changed.seed += 1
		if check(dialog.start_architectural(changed), label + " second 2048 preview begins"):
			dialog._process(0.0)
			dialog._cancel_preview()
			check(installed() and host._physical_epoch == original_epoch and
				wb._generated_active.sha256 == packet.sha256,
				label + " cancelling a new 2048 preview preserves installed World")
			dialog.hide()
	report.cases.append({
		"case": label, "phase": "reopen" if reopening else "author",
		"extent": [SIZE,SIZE], "origin": authored.origin, "seed": authored.seed,
		"modules": compiled.recipe.modules.size(), "zones": GRID * GRID,
		"native_chunks": packet.receipt_hashes.size(), "native_material_sha256": packet.sha256,
		"recipe_sha256": packet.recipe_sha256, "material_bytes": packet.cells.size(),
		"edits": saved.get("setup",{}).get("edits",[]).size(), "display": DisplayServer.get_name()
	})
	return failures == 0

func run() -> void:
	var began := Time.get_ticks_usec()
	var phase := OS.get_environment("CYBERSAND_GENTEK2048_PHASE")
	report.phase = phase
	report.godot = Engine.get_version_info().string
	report.display = DisplayServer.get_name()
	report.native_runtime = ClassDB.class_exists(&"CyberWorldGenerator")
	if check(phase in ["author","reopen"], "registered actual Workbench phase") and check(ClassDB.class_exists(&"CyberWorldGenerator"), "real native generator is loaded"):
		root.size = Vector2i(1600, 900)
		change_scene_to_file("res://feature_launcher.tscn")
		await scene_changed
		current_scene.launch("shared_workbench")
		await scene_changed
		host = current_scene
		wb = host.shared_workbench
		dialog = wb._generated_dialog
		preview_clock = PreviewClock.new()
		preview_clock.dialog = dialog
		root.add_child(preview_clock)
		if await until(installed, "Shared Workbench native World is ready"):
			complete = true
			for kind: String in CASES:
				if not await _case(kind, phase == "reopen"):
					complete = false
					break
	var retained_cases := 0
	for entry: Dictionary in report.cases:
		if str(entry.get("case", "")).begins_with("gentek2048-"):
			retained_cases += 1
	check(complete and retained_cases == CASES.size(), "both 2048-square registered scenarios completed; timing records are separate")
	report.checks = checks
	report.failures = failures
	report.complete = complete
	report.elapsed_us = Time.get_ticks_usec() - began
	write_json("gentek2048-" + phase + ".json", report)
	if host != null:
		preview_clock.queue_free()
		host.queue_free()
		await process_frame
		await process_frame
	print("GENTEK2048_RESULTS phase=", phase, " checks=", checks, " failures=", failures, " complete=", complete)
	quit(1 if failures else 0)
