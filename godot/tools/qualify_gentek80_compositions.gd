extends "res://tests/test_architectural_generator.gd"

# Qualification-only. These are the two distinct five-active showcase projects
# from showcase_mixed_gallery(), now exercised through real Shared Workbench UI.
# Author and reopen must run in separate OS processes with one isolated profile.
const COMPOSITIONS := [
	["cathedral_megaframe", "seeded_typology_megablock", "megatruss_station",
		"interlaced_viaduct", "suspended_arcology"],
	["metabolist_spine", "rosework_gatehouse", "interlock_brutalism",
		"cathedral_megaframe", "megatruss_station"]
]
const SHARES := [[30.0,25.0,20.0,15.0,10.0], [20.0,20.0,20.0,20.0,20.0]]
const NAMES := ["gentek80-five-showcase-a", "gentek80-five-showcase-b-negative"]
const PROJECT_FILES := ["user://gentek80-five-showcase-a.json", "user://gentek80-five-showcase-b-negative.json"]
var completed_count := 0

func _project(index: int) -> Dictionary:
	var p: Dictionary = Project.default_project()
	p.extent = [512, 512]
	p.origin = [0, 0] if index == 0 else [-512, -512]
	p.seed = 161803 + index * 110025
	p.zone_scale = 64
	p.automatic_tunnels = false
	p.styles = []
	var catalogue: Array = Project.builtin_presets()
	for module: String in COMPOSITIONS[index]:
		var match_preset: Dictionary = {}
		for preset: Dictionary in catalogue:
			if str(preset.module) == module:
				match_preset = preset.duplicate(true)
				break
		if not check(not match_preset.is_empty(), "advanced showcase exists: " + module):
			return {}
		var slot: int = p.styles.size()
		# Exercise real mixed composition controls, not only builtin defaults.
		if index == 0 and slot == 0:
			match_preset.geometry.room_size = int(match_preset.geometry.room_size) + 16
			match_preset.geometry.floor_height = int(match_preset.geometry.floor_height) + 16
			match_preset.materials.wall = 130
			match_preset.materials.floor = 114
			match_preset.materials.window = 120
			match_preset.apertures["automatic_doors"] = true
			match_preset.apertures["automatic_windows"] = true
			match_preset.deterioration = 0.05
		elif index == 1 and slot == 2:
			match_preset.geometry.floor_height = int(match_preset.geometry.floor_height) + 8
			match_preset.materials.wall = 58
			match_preset.apertures["automatic_doors"] = false
			match_preset.apertures["automatic_windows"] = false
			match_preset.deterioration = 0.1
		p.styles.append({"enabled": true, "share": SHARES[index][slot], "preset": match_preset})
	return p

func _install_case(packet: Dictionary, label: String) -> bool:
	var before: int = int(host.latest_snapshot.render_world_generation)
	dialog.confirmed.emit()
	dialog.hide()
	if not await until(func() -> bool: return installed() and str(wb._generated_active.get("sha256", "")) == str(packet.sha256),
			label + " native World install acknowledged"): return false
	check(int(host.latest_snapshot.render_world_generation) > before, label + " native World generation advanced")
	check(host.tower_context.get("liquid_construction_receipt", {}).get("generated_source_sha256", "") == packet.sha256,
			label + " native constructor verifies source materials")
	return true

func _case(index: int, reopening: bool) -> bool:
	var name: String = NAMES[index]
	var path: String = PROJECT_FILES[index]
	var expected: Dictionary = _project(index)
	if not check(not expected.is_empty(), name + " project constructed"): return false
	var compiled: Dictionary = Project.compile(expected)
	if not check(compiled.get("ok", false) and compiled.coverage.size() == 5,
			name + " all five showcase zones compile"): return false
	dialog.open_new()
	dialog._architecture_button.pressed.emit()
	var panel: ConfirmationDialog = dialog._architecture
	if reopening:
		if not check(panel.load_project(path), name + " editable project reopened from disk"): return false
	else:
		if not check(panel.set_project(expected), name + " ordinary five-slot Workbench panel accepts project"): return false
		if not check(panel.save_project(path), name + " editable project saved to independent JSON file"): return false
	var actual: Dictionary = panel.project()
	var restored: Dictionary = Project.compile(actual)
	if not check(restored.get("ok", false) and restored.project_hash == compiled.project_hash,
			name + " full styles, seed, signed origin, geometry, materials and ratios restored"): return false
	if not check(FileAccess.file_exists(path), name + " editable project exists"): return false
	var project_file_hash: String = FileAccess.get_sha256(path)
	var modules: Array[String] = []
	var shares: Array[float] = []
	var configurations: Array[Dictionary] = []
	for slot: Dictionary in actual.styles:
		check(bool(slot.enabled) and float(slot.share) > 0, name + " all five style slots active")
		modules.append(str(slot.preset.module))
		shares.append(float(slot.share))
		configurations.append({"geometry": slot.preset.geometry.duplicate(true),
			"materials": slot.preset.materials.duplicate(true),
			"apertures": slot.preset.apertures.duplicate(true),
			"deterioration": float(slot.preset.deterioration)})
	check(modules.size() == 5 and modules == COMPOSITIONS[index],
			name + " exact five selected advanced showcase modules")
	if index == 1:
		check(int(actual.origin[0]) < 0 and int(actual.origin[1]) < 0, "signed negative global origin retained")
	if not reopening:
		await framebuffer(name + "-five-slot-project", panel)
	panel.hide()
	var saved: Dictionary = {}
	preview_clock.begin()
	if reopening:
		saved = Store.read_named(name)
		if not check(saved.get("generated", false), name + " named starting map exists in fresh process"): return false
		wb._name.text = name
		if not check(wb.load_setup(), name + " ordinary Workbench Load starts native replay"): return false
	else:
		if not check(dialog.start_architectural(actual), name + " real Shared Workbench five-style preview begins"): return false
	if not await preview_ready(name + ("-reopen" if reopening else "-author")): return false
	var packet: Dictionary = dialog._ready_packet.duplicate(true)
	if not check(packet.cells.size() == 512 * 512 and packet.receipt_hashes.size() > 0,
			name + " native material and chunk receipts complete"): return false
	if not await _install_case(packet, name): return false
	if reopening:
		check(saved.generation.sha256 == packet.sha256 and saved.generation.recipe_sha256 == packet.recipe_sha256,
				name + " original named-map material and native recipe identities reconstructed")
		check(wb.applied.edits == saved.setup.edits and saved.setup.edits.size() >= 2,
				name + " original paint and erase edits persisted")
		if not await until(func() -> bool: return host.image.get_width() == 512 and host.image.get_pixel(101, 99).r8 == 58 and host.image.get_pixel(111, 99).r8 == 0,
				name + " native image reconstructs both material edits"): return false
	else:
		wb._brush.value = 1
		if not check(wb.paint(Vector2i(101, 99), 58), name + " ordinary paint accepted"): return false
		if not await until(func() -> bool: return host.image.get_width() == 512 and host.image.get_pixel(101, 99).r8 == 58,
				name + " paint visible in native World"): return false
		if not check(wb.paint(Vector2i(111, 99), 0), name + " ordinary erase accepted"): return false
		if not await until(func() -> bool: return host.image.get_pixel(111, 99).r8 == 0 and paint_completed(),
				name + " erase visible in native World"): return false
		wb._name.text = name
		if not check(wb.save_setup(), name + " named starting map saved"): return false
		saved = Store.read_named(name)
		check(saved.get("generated", false) and saved.setup.edits.size() >= 2 and saved.generation.recipe_sha256 == packet.recipe_sha256,
				name + " saved named map embeds original recipe and ordered edits")
	await framebuffer(name + ("-reopened-edited-native-world" if reopening else "-authored-edited-native-world"))
	report.cases.append({
		"case": "five-showcase-reopen" if reopening else "five-showcase-author",
		"name": name, "editable_project": path, "project_file_sha256": project_file_hash,
		"project_sha256": restored.project_hash, "seed": actual.seed, "origin": actual.origin,
		"active_slots": 5, "modules": modules, "shares": shares,
		"configurations": configurations, "named_map": name,
		"source_sha256": packet.sha256, "recipe_sha256": packet.recipe_sha256,
		"native_receipts": packet.receipt_hashes.size(), "process_id": OS.get_process_id(),
		"display": DisplayServer.get_name(), "source_commit": OS.get_environment("CYBERSAND_SOURCE_REVISION")
	})
	completed_count += 1
	return true

func run() -> void:
	var phase: String = OS.get_environment("CYBERSAND_GENTEK80_COMPOSITION_PHASE")
	var reopening: bool = phase == "reopen"
	var began: int = Time.get_ticks_usec()
	report.merge({"phase": phase, "godot": Engine.get_version_info().string, "os": OS.get_name(), "display": DisplayServer.get_name()})
	if check(phase in ["author", "reopen"], "known five-showcase phase") and \
			check(ClassDB.class_exists(&"CyberWorldGenerator"), "source-built generator available"):
		if OS.get_environment("CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS") == "1" and \
				not check(DisplayServer.get_name() != "headless", "graphical display required"):
			pass
		else:
			root.size = Vector2i(1600, 1000)
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
			if await until(installed, "ordinary Shared Workbench ready"):
				for index: int in 2:
					if not await _case(index, reopening): break
	complete = completed_count == 2 and failures == 0
	report.merge({"schema": "gentek80-five-showcase-workbench-v1", "phase": phase,
		"checks": checks, "failures": failures, "complete": complete, "completed": complete,
		"process_id": OS.get_process_id(), "projects": completed_count,
		"source_commit": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"elapsed_us": Time.get_ticks_usec() - began}, true)
	write_json("gentek80-five-showcase-" + phase + ".json", report)
	if host != null:
		preview_clock.queue_free()
		host.queue_free()
		await process_frame
		await process_frame
	print("GENTEK80_FIVE_SHOWCASE phase=", phase, " projects=", completed_count,
			" checks=", checks, " failures=", failures, " complete=", complete)
	quit(1 if failures else 0)
