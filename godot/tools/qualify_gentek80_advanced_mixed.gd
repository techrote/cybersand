extends "res://tests/test_architectural_generator.gd"

# GENTEK-WINDOWS-FINAL-001: two full five-showcase compositions, not the
# historical five-legacy/three-active-slot Workbench coverage. Uses the actual
# Shared Workbench, native proposal/host, native paint/erase and saved starts.
const AdvancedProject = preload("res://scripts/architectural_generator_project.gd")
const AdvancedStore = preload("res://scripts/workbench_generated_map.gd")
const AdvancedSetup = preload("res://scripts/workbench_setup.gd")

const MODULES := [
	["cathedral_megaframe", "megatruss_station", "seeded_typology_megablock",
		"interlaced_viaduct", "suspended_arcology"],
	["metabolist_spine", "rosework_gatehouse", "interlock_brutalism",
		"cathedral_megaframe", "megatruss_station"]
]
const SHARES := [[30.0, 25.0, 20.0, 15.0, 10.0],
	[20.0, 20.0, 20.0, 20.0, 20.0]]
const LABELS := ["gentek-advanced-five-a", "gentek-advanced-five-b-negative-origin"]

func mixed_style_project(second: bool) -> Dictionary:
	var index: int = 1 if second else 0
	var project: Dictionary = AdvancedProject.default_project()
	project.extent = [512, 512]
	project.origin = [-512, -256] if second else [0, 0]
	project.zone_scale = 64
	project.seed = 271828 if second else 161803
	project.automatic_tunnels = false
	project.automatic_doors = true
	project.automatic_windows = not second
	project.styles = []
	for slot: int in 5:
		var found: Dictionary = {}
		for source: Dictionary in AdvancedProject.builtin_presets():
			if str(source.module) == MODULES[index][slot]:
				found = source.duplicate(true)
				break
		if not check(not found.is_empty(), "advanced module is present: " + MODULES[index][slot]):
			return {}
		# All controls enter the production compiler/recipe, never a fake raster.
		if slot == 0:
			found.geometry.room_size = mini(256, int(found.geometry.room_size) + 16)
			found.geometry.floor_height = mini(256, int(found.geometry.floor_height) + 16)
			found.materials.wall = 130
			found.materials.floor = 114
			found.materials.window = 120
			found.apertures["automatic_windows"] = not second
			found.apertures["automatic_doors"] = true
		if slot == 1:
			found.deterioration = 0.1 if second else 0.05
		project.styles.append({"enabled": true, "share": SHARES[index][slot], "preset": found})
	return project

func _project_file(name: String) -> String:
	return output_dir().path_join(name + ".project.json")

func _source_project(name: String) -> Dictionary:
	var path: String = _project_file(name)
	if not check(FileAccess.file_exists(path), name + " original editable project exists"):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(value is Dictionary, name + " editable source JSON parsed"):
		return {}
	return value

func mixed_style_authoring(reopening: bool) -> void:
	for second: bool in [false, true]:
		var index: int = 1 if second else 0
		var label: String = LABELS[index]
		var project: Dictionary = mixed_style_project(second)
		if project.is_empty(): return
		var compiled: Dictionary = AdvancedProject.compile(project)
		if not check(compiled.get("ok", false),
			label + " all five advanced native modules compiled"): return
		check(compiled.recipe.modules.size() == 5 and compiled.coverage.size() == 5,
			label + " five real independent native masks and module receipts")
		for slot: int in 5:
			check(str(compiled.recipe.modules[slot].module) == MODULES[index][slot]
				and int(compiled.recipe.modules[slot].version) == 1,
				label + " exact module/version at slot " + str(slot + 1))
		var recipe_sha: String = AdvancedStore.recipe_hash(compiled.recipe)
		if reopening:
			var editable: Dictionary = _source_project(label)
			if editable.is_empty(): return
			var recompiled: Dictionary = AdvancedProject.compile(editable)
			if not check(recompiled.get("ok", false) and
				AdvancedStore.recipe_hash(recompiled.get("recipe", {})) == recipe_sha,
				label + " original editable project recompiled exactly in new process"): return
			wb._name.text = label
			preview_clock.begin()
			if not check(wb.load_setup(), label + " ordinary named-start Load initiates regeneration"): return
		else:
			write_json(label + ".project.json", project)
			preview_clock.begin()
			if not check(dialog.start_architectural(project), label + " actual native preview requested"): return
		if not await preview_ready(label + ("-reopened" if reopening else "-author")): return
		var packet: Dictionary = dialog._ready_packet.duplicate(true)
		check(packet.cells.size() == 512 * 512 and packet.receipt_hashes.size() > 0,
			label + " complete native material and receipt payload")
		check(packet.recipe_sha256 == recipe_sha,
			label + " UI/native packet preserves five-style source recipe identity")
		if not reopening:
			check_style_diagnostics(project, label)
			dialog._zone_toggle.button_pressed = true
			check(dialog._zone_overlay.visible,
				label + " style-zone overlay visible above native material")
			await framebuffer(label + "-zone-overlay", dialog)
			dialog._zone_toggle.button_pressed = false
		var prior_generation: int = int(host.latest_snapshot.render_world_generation)
		dialog.confirmed.emit()
		dialog.hide()
		if not await until(func() -> bool:
			return installed() and str(wb._generated_active.get("sha256", "")) == packet.sha256,
			label + " ordinary Workbench native installation"): return
		check(int(host.latest_snapshot.render_world_generation) > prior_generation,
			label + " fresh native World publication acknowledged")
		check(host.tower_context.get("liquid_construction_receipt", {}).get(
			"generated_source_sha256", "") == packet.sha256,
			label + " native host corroborates exact material bytes")
		var saved: Dictionary = {}
		if reopening:
			saved = AdvancedStore.read_named(label)
			if not check(saved.get("generated", false), label + " named map exists after restart"): return
			check(wb.applied.edits == saved.setup.edits and saved.setup.edits.size() >= 2,
				label + " native paint/erase edits replayed in exact order")
			check(saved.generation.recipe_sha256 == recipe_sha and
				wb._generated_active.recipe_sha256 == recipe_sha,
				label + " saved and live native recipe hashes survive restart")
			if not await until(func() -> bool: return host.image.get_width() == 512 and host.image.get_pixel(101, 99).r8 == 58 and host.image.get_pixel(111, 99).r8 == 0,
				label + " actual native material restored from saved ordered edits"): return
		else:
			wb._brush.value = 1
			if not check(wb.paint(Vector2i(101, 99), 58),
				label + " real native paint accepted"): return
			if not await until(func() -> bool: return host.image.get_width() == 512 and host.image.get_pixel(101, 99).r8 == 58,
				label + " real native paint visible"): return
			if not check(wb.paint(Vector2i(111, 99), 0),
				label + " real native erase accepted"): return
			if not await until(func() -> bool: return host.image.get_pixel(111, 99).r8 == 0 and paint_completed(),
				label + " native erase acknowledged"): return
			wb._name.text = label
			if not check(wb.save_setup(), label + " named starting map saved"): return
			saved = AdvancedStore.read_named(label)
			if not check(saved.get("generated", false) and saved.setup.edits.size() >= 2,
				label + " two ordered authored edits persisted"): return
			check(saved.generation.recipe_sha256 == recipe_sha,
				label + " saved native recipe matches editable project")
			var source_map: String = ProjectSettings.globalize_path(AdvancedSetup._path(label))
			check(DirAccess.copy_absolute(source_map, output_dir().path_join(label + ".start.json")) == OK,
				label + " original named Workbench start retained with evidence")
		await framebuffer(label + ("-reopened-map" if reopening else "-painted-map"))
		report.cases.append({
			"case": "advanced-five-reopen" if reopening else "advanced-five-author",
			"scenario": label, "modules": MODULES[index], "requested_shares": SHARES[index],
			"seed": project.seed, "origin": project.origin,
			"geometry": project.styles.map(func(s: Dictionary) -> Dictionary: return s.preset.geometry),
			"materials": project.styles.map(func(s: Dictionary) -> Dictionary: return s.preset.materials),
			"coverage": compiled.coverage, "native_receipts": packet.receipt_hashes,
			"source_sha256": packet.sha256, "recipe_sha256": packet.recipe_sha256,
			"edits": saved.setup.edits, "process_id": OS.get_process_id(),
			"display": DisplayServer.get_name()
		})
	complete = report.cases.filter(func(c: Dictionary) -> bool:
		return str(c.get("case", "")).begins_with("advanced-five-")).size() == 2
