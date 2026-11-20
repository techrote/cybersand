extends "res://tools/qualify_gentek80_workbench.gd"

# Supplemental acceptance only. This file is intentionally outside res:// and
# must never be copied over a candidate script. All UI/native lifecycle helpers
# below are inherited from the exact candidate being exercised.
const MIXTURES := [
	{"id": "a", "seed": 161803, "modules": ["suspended_deck", "rib_vault", "cathedral_megaframe", "interlaced_viaduct", "megatruss_station"]},
	{"id": "b", "seed": 271828, "modules": ["ring_pier", "tripod_frame", "seeded_typology_megablock", "metabolist_spine", "rosework_gatehouse"]},
	{"id": "c", "seed": 314159, "modules": ["cascade_terrace", "scalloped_vault", "buttress_wall", "interlock_brutalism", "suspended_arcology"]}
]
var completed_mixtures := 0
var capture_names: Array[String] = []

func framebuffer(label: String, popup: Window = null) -> void:
	await super.framebuffer(label, popup)
	if DisplayServer.get_name() != "headless": capture_names.append(label + ".png")

func _mixed_initial_project(seed_value: int) -> Dictionary:
	var value: Dictionary = Project.default_project()
	value.extent = [512, 512]
	value.origin = [0, 0]
	value.zone_scale = 64
	value.seed = seed_value
	value.styles = []
	for slot: int in 5:
		value.styles.append({"enabled": true, "share": 20.0, "preset": Project.builtin_presets()[slot].duplicate(true)})
	return value

func _select_mixed_slot(panel: ConfirmationDialog, slot: int, module_name: String, events: Array) -> bool:
	var presets: Array = Project.builtin_presets()
	var catalogue_index := -1
	for index: int in presets.size():
		if str(presets[index].module) == module_name:
			if not check(catalogue_index == -1, "unique catalogue module " + module_name): return false
			catalogue_index = index
	if not check(catalogue_index >= 13, "Gentek module exists " + module_name): return false
	var chooser: OptionButton = panel._style_controls[slot].chooser
	for item: int in chooser.item_count:
		if chooser.get_item_id(item) != catalogue_index: continue
		chooser.select(item)
		chooser.item_selected.emit(item)
		var actual: Dictionary = panel.project().styles[slot].preset
		if not check(actual == presets[catalogue_index], "ordinary slot selection preserves complete preset " + module_name): return false
		events.append({"slot": slot, "catalogue_index": catalogue_index, "item_index": item,
			"module": module_name, "preset_id": actual.id, "signal": "OptionButton.item_selected",
			"preset": actual.duplicate(true)})
		return true
	return check(false, "requested Gentek reachable in ordinary dropdown: " + module_name)

func _material_bytes() -> PackedByteArray:
	var values := PackedByteArray()
	if host.image == null or host.image.get_width() != 512 or host.image.get_height() != 512: return values
	values.resize(512 * 512)
	for y: int in 512:
		for x: int in 512: values[y * 512 + x] = host.image.get_pixel(x, y).r8
	return values

func _edited_source(source: PackedByteArray, edits: Array) -> PackedByteArray:
	# Independent material readback oracle for the two ordinary disc strokes.
	# The actual radius is read from the saved native-authoring stamps, since the
	# Workbench currently clamps its accepted setup brush radius to at least two.
	var result: PackedByteArray = source.duplicate()
	for stamp: Array in edits:
		if not check(stamp.size() == 4, "saved mixed edit is an ordinary disc stroke"): return PackedByteArray()
		var x := int(stamp[0])
		var y := int(stamp[1])
		var radius := int(stamp[2])
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if dx * dx + dy * dy > radius * radius: continue
				if x + dx >= 0 and x + dx < 512 and y + dy >= 0 and y + dy < 512:
					result[(y + dy) * 512 + x + dx] = int(stamp[3])
	return result

func _saved_edits_valid(saved: Dictionary, label: String) -> bool:
	if not check(saved.get("generated", false) and saved.get("setup", {}).get("edits", []).size() == 2, label + " exactly two ordered edits saved"): return false
	var edits: Array = saved.setup.edits
	return check(edits[0].size() == 4 and edits[1].size() == 4 and
		int(edits[0][0]) == 101 and int(edits[0][1]) == 99 and int(edits[0][3]) == 58 and
		int(edits[1][0]) == 111 and int(edits[1][1]) == 99 and int(edits[1][3]) == 0 and
		int(edits[0][2]) == int(edits[1][2]) and int(edits[0][2]) >= 2 and int(edits[0][2]) <= 24,
		label + " exact paint and erase stroke order/materials retained")

func _campaign(reopening: bool) -> void:
	if OS.get_environment("CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS") == "1":
		if not check(DisplayServer.get_name() != "headless", "actual graphical display required"): return
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
	capture_this_style = true
	if not await until(installed, "ordinary Shared Workbench ready"): return
	catalogue_size = Project.builtin_presets().size()
	if not check(catalogue_size == 93, "exactly 80 Genteks plus 13 existing presets"): return
	for mixture: Dictionary in MIXTURES:
		var label: String = "mixed-" + str(mixture.id)
		var phase: String = "reopen" if reopening else "author"
		var prefix: String = phase + "-" + label
		var began := Time.get_ticks_usec()
		var saved := {}
		var selected_project := {}
		var events: Array = []
		var initial_packet := {}
		var replay_packet := {}
		if reopening:
			wb._name.text = "gentek80-" + label
			saved = Store.read_named(wb._name.text)
			if not _saved_edits_valid(saved, label): return
			preview_clock.begin()
			if not check(wb.load_setup(), label + " ordinary Load start begins in independent process"): return
		else:
			dialog.open_new()
			dialog._architecture_button.pressed.emit()
			var panel: ConfirmationDialog = dialog._architecture
			if not check(panel.set_project(_mixed_initial_project(int(mixture.seed))), label + " initializes all five ordinary cards"): return
			for slot: int in 5:
				if not _select_mixed_slot(panel, slot, str(mixture.modules[slot]), events): return
			selected_project = panel.project().duplicate(true)
			if not check(selected_project.seed == mixture.seed and selected_project.extent == [512, 512] and
				selected_project.origin == [0, 0] and selected_project.zone_scale == 64 and
				selected_project.automatic_tunnels and selected_project.automatic_doors and selected_project.automatic_windows,
				label + " retains ordinary default automatic features and requested bounds"): return
			for slot: int in 5:
				if not check(selected_project.styles[slot].enabled and is_equal_approx(float(selected_project.styles[slot].share), 20.0) and
					selected_project.styles[slot].preset == events[slot].preset, label + " five equal shares and exact actual preset parameters/materials"): return
			for frame: int in 3: await process_frame
			await framebuffer(prefix + "-form", panel)
			write_json(prefix + "-project.json", selected_project)
			preview_clock.begin()
			# This is the same ConfirmationDialog Apply signal wired to _apply by
			# the accepted UI; no synthetic recipe bypasses the panel.
			panel.confirmed.emit()
		if not await preview_ready(prefix + "-preview"): return
		var packet: Dictionary = dialog._ready_packet.duplicate(true)
		if not check(packet.cells.size() == 512 * 512 and Store.digest(packet.cells) == packet.sha256 and
			Store.recipe_hash(packet.recipe) == packet.recipe_sha256 and packet.receipt_hashes.size() > 0,
			label + " complete native material/recipe bytes and generation receipts"): return
		if not reopening:
			initial_packet = {"material_sha256": packet.sha256, "recipe_sha256": packet.recipe_sha256}
			check_style_diagnostics(selected_project, label)
			write_json(prefix + "-coverage.json", {"coverage": dialog._architecture_result.coverage, "zones": dialog._architecture_result.zones})
			dialog._zone_toggle.button_pressed = true
			check(dialog._zone_overlay.visible and dialog._zone_overlay.texture != null, label + " actual zone overlay is visible")
			await framebuffer(prefix + "-zone-overlay", dialog)
			dialog._zone_toggle.button_pressed = false
			check(dialog.attests(packet), label + " overlay preserves native proposal")
			# Repeat the identical selected form through its ordinary Apply action.
			dialog._architecture_button.pressed.emit()
			var repeat_panel: ConfirmationDialog = dialog._architecture
			if not check(repeat_panel.project() == selected_project, label + " reopen form preserves the complete recipe inputs"): return
			preview_clock.begin()
			repeat_panel.confirmed.emit()
			if not await preview_ready(prefix + "-replay"): return
			packet = dialog._ready_packet.duplicate(true)
			replay_packet = {"material_sha256": packet.sha256, "recipe_sha256": packet.recipe_sha256}
			if not check(initial_packet == replay_packet and Store.digest(packet.cells) == packet.sha256,
				label + " repeated ordinary Apply reproduces exact materials and recipe"): return
			preview(prefix + "-native-materials", packet.cells, Vector2i(512, 512))
		var prior_tick: int = int(host.latest_snapshot.tick_index)
		if not await _install(packet, label): return
		var installed_material_hash := Store.digest(_material_bytes())
		var restored_material_hash := ""
		if reopening:
			if not check(wb.applied.edits == saved.setup.edits and packet.recipe_sha256 == saved.generation.recipe_sha256 and
				packet.sha256 == saved.generation.sha256 and Store.recipe_hash(packet.recipe) == Store.recipe_hash(saved.generation.recipe),
				label + " independent process restores exact saved recipe, source materials and ordered edits"): return
			if not await until(func() -> bool: return (host.image.get_width() == 512 and host.image.get_pixel(101, 99).r8 == 58 and
				host.image.get_pixel(111, 99).r8 == 0 and paint_completed()), label + " saved edits acknowledged in actual native World"): return
			var expected: PackedByteArray = _edited_source(packet.cells, saved.setup.edits)
			var actual: PackedByteArray = _material_bytes()
			restored_material_hash = Store.digest(actual)
			if not check(expected == actual, label + " all 262144 restored material cells equal source plus exact saved edits"): return
			await framebuffer(prefix + "-restored-world")
		else:
			if not check(_material_bytes() == packet.cells, label + " all installed native World materials match generated source"): return
			await framebuffer(prefix + "-installed-world")
			prior_tick = int(host.latest_snapshot.tick_index)
			if not await _edit_and_save(label, packet): return
			saved = Store.read_named("gentek80-" + label)
			if not _saved_edits_valid(saved, label): return
			await framebuffer(prefix + "-edited-world")
		write_json(prefix + "-saved-start.json", saved)
		write_json(prefix + "-recipe.json", packet.recipe)
		var expected_edits_hash := Store.digest(_edited_source(packet.cells, saved.setup.edits))
		report.cases.append({"case": "mixed-reopen" if reopening else "mixed-author", "mixture_id": mixture.id,
			"modules": mixture.modules, "seed": mixture.seed, "extent": [512, 512], "origin": [0, 0], "zone_scale": 64,
			"selected_project": selected_project, "selection_events": events, "source_sha256": packet.sha256,
			"recipe_sha256": packet.recipe_sha256, "native_receipt_hashes": packet.receipt_hashes,
			"initial": initial_packet, "replay": replay_packet, "edits": saved.setup.edits,
			"edits_sha256": Store.recipe_hash({"edits": saved.setup.edits}),
			"expected_edited_material_sha256": expected_edits_hash,
			"installed_material_sha256": installed_material_hash, "restored_material_sha256": restored_material_hash,
			"post_tick_material_sha256": Store.digest(_material_bytes()) if not reopening else null,
			"saved_start": "gentek80-" + label, "tick_before": prior_tick,
			"tick_after": int(host.latest_snapshot.tick_index),
			"construction_receipt": host.tower_context.get("liquid_construction_receipt", {}).duplicate(true),
			"elapsed_us": Time.get_ticks_usec() - began, "display": DisplayServer.get_name()})
		completed_mixtures += 1
		print("GENTEK80_MIXED_PROGRESS ", phase, " ", completed_mixtures, "/3 ", label)
	complete = completed_mixtures == MIXTURES.size()

func _assemble_phase_report(phase: String, began: int) -> Dictionary:
	var runtime := "res://addons/cybersand_native/bin/" + ("cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so")
	report.merge({"schema": "gentek80-mixed-workbench-phase-v1", "phase": phase,
		"checks": checks, "failures": failures, "complete": complete, "completed": complete,
		"mixtures": completed_mixtures, "expected_mixtures": MIXTURES,
		"catalogue_choices": catalogue_size, "process_id": OS.get_process_id(),
		"source_commit": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"native_build_commit": OS.get_environment("CYBERSAND_MIXED_BUILD_SOURCE"),
		"driver_path": get_script().resource_path, "driver_sha256": FileAccess.get_sha256(get_script().resource_path),
		"runtime_sha256": FileAccess.get_sha256(runtime), "captures": capture_names,
		"graphical": DisplayServer.get_name() != "headless", "elapsed_us": Time.get_ticks_usec() - began,
		"scope": "Three five-card CLASSIC+showcase projects through ordinary Workbench selection, Apply, installation, ordered edits, saved start and independent-process reopening. This does not certify structural support or walkable interfaces between zones."}, true)
	return report

func run() -> void:
	var phase := OS.get_environment("CYBERSAND_MIXED_WB_PHASE")
	var began := Time.get_ticks_usec()
	report.merge({"godot": Engine.get_version_info().string, "os": OS.get_name(), "display": DisplayServer.get_name()}, true)
	if check(phase in ["author", "reopen"], "known supplemental mixed Workbench phase") and check(ClassDB.class_exists(&"CyberWorldGenerator"), "source-qualified native generator available"):
		await _campaign(phase == "reopen")
	check(complete, "all three mandatory mixed projects completed")
	write_json("mixed-workbench-" + phase + ".json", _assemble_phase_report(phase, began))
	if preview_clock != null: preview_clock.queue_free()
	if host != null: host.queue_free()
	await process_frame
	await process_frame
	print("GENTEK80_MIXED_WORKBENCH phase=", phase, " mixtures=", completed_mixtures, " checks=", checks, " failures=", failures, " complete=", complete)
	quit(1 if failures else 0)
