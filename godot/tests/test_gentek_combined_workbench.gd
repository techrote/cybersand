extends "res://tests/test_architectural_generator.gd"

# GENTEK-COMBINED-WB-EVAL-001. Drive the existing selector signals, preview,
# native install, painting and both existing persistence formats. The Python
# runner executes singles, author and reopen as separate application processes.
const SHOWCASES: Array[String] = [
	"megatruss_station", "cathedral_megaframe", "seeded_typology_megablock",
	"metabolist_spine", "interlaced_viaduct", "rosework_gatehouse",
	"interlock_brutalism", "suspended_arcology",
]
const COMPOSITIONS: Array = [
	["cathedral_megaframe", "megatruss_station", "seeded_typology_megablock", "interlaced_viaduct", "suspended_arcology"],
	["metabolist_spine", "rosework_gatehouse", "interlock_brutalism", "cathedral_megaframe", "megatruss_station"],
]
var panel: ConfirmationDialog

func framebuffer(label: String, popup: Window = null) -> void:
	if DisplayServer.get_name() == "headless": return
	# Wait for an actual drawn frame for every timing receipt, but retain a
	# compact gallery rather than a screenshot for every seed/parameter probe.
	await RenderingServer.frame_post_draw
	if not (label.ends_with("-baseline") or label.begins_with("mixed-") or
			label in ["advanced-selector", "advanced-selector-menu", "single-installed"]): return
	var viewport: Viewport = popup if popup != null and not popup.is_embedded() else root
	check(viewport.get_texture().get_image().save_png(output_dir().path_join(label + ".png")) == OK,
		"original graphical framebuffer " + label)

func mount_workbench() -> bool:
	if OS.get_environment("CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS") == "1":
		if not check(DisplayServer.get_name() != "headless", "graphical campaign has a real display"): return false
	root.size = Vector2i(1280, 720)
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
	if not await until(installed, "Shared Workbench native World ready"): return false
	dialog.open_new()
	dialog._architecture_button.pressed.emit()
	panel = dialog._architecture
	check(panel.visible and panel._style_controls.size() == 5, "existing Architectural Generator opens with five slots")
	var catalogue: Array = Project.builtin_presets()
	check(catalogue.size() == 93, "93 presets: 13 established plus 80 CLASSIC/showcase")
	for controls: Dictionary in panel._style_controls:
		check(controls.chooser.item_count == catalogue.size(), "each existing chooser contains the complete catalogue")
	for preset: Dictionary in catalogue:
		check(str(preset.module).to_lower() not in ["frameweaver", "mosaic", "receptor"], "SWARM research stays outside UI catalogue")
	return failures == 0

func choose_modules(ids: Array, seed: int, origin: Vector2i = Vector2i.ZERO, shares: Array = []) -> bool:
	dialog._architecture_button.pressed.emit()
	panel = dialog._architecture
	panel._seed.value = seed
	panel._x.value = origin.x
	panel._y.value = origin.y
	panel._select_id(panel._extent, 512)
	panel._select_id(panel._zone_scale, 64)
	panel._tunnels.button_pressed = false
	panel._doors.button_pressed = true
	panel._windows.button_pressed = true
	var catalogue: Array = Project.builtin_presets()
	for slot: int in 5:
		var controls: Dictionary = panel._style_controls[slot]
		controls.enabled.button_pressed = slot < ids.size()
		controls.share.value = (float(shares[slot]) if not shares.is_empty() else 100.0 / ids.size()) if slot < ids.size() else 0.0
	for slot: int in ids.size():
		var index := -1
		for candidate: int in catalogue.size():
			if catalogue[candidate].module == ids[slot]: index = candidate
		if not check(index >= 0, "catalogue contains exact module " + str(ids[slot])): return false
		var chooser: OptionButton = panel._style_controls[slot].chooser
		check(chooser.get_item_text(index) == catalogue[index].name, "visible chooser label matches exact catalogue preset")
		chooser.select(index)
		chooser.item_selected.emit(index)
		var selected: Dictionary = panel.project().styles[slot].preset
		if not check(selected.module == ids[slot] and int(selected.module_version) == 1 and selected.id == catalogue[index].id,
			"existing chooser signal selects correct native identity " + str(ids[slot])): return false
	var project: Dictionary = panel.project()
	var compiled: Dictionary = Project.compile(project)
	return check(compiled.get("ok", false), "UI-authored shares and settings compile: " + str(compiled.get("error", "")))

func form_generate(label: String, ids: Array) -> Dictionary:
	preview_clock.begin()
	# ConfirmationDialog's existing signal invokes the production _apply path.
	panel.confirmed.emit()
	if not await preview_ready(label): return {}
	var packet: Dictionary = dialog._ready_packet.duplicate(true)
	check(packet.cells.size() == 512 * 512 and packet.receipt_hashes.size() > 0, label + " complete native material payload")
	check(dialog.attests(packet), label + " is a source-attested installable preview")
	var modules: Array = packet.recipe.modules
	if not check(modules.size() == ids.size(), label + " preserves enabled module count"): return {}
	var authored: Dictionary = panel.project()
	var compiled: Dictionary = Project.compile(authored)
	check(compiled.get("ok", false) and Store.recipe_hash(compiled.recipe) == packet.recipe_sha256,
		label + " native preview consumes exactly the current form's compiled recipe")
	for slot: int in ids.size():
		check(modules[slot].module == ids[slot] and int(modules[slot].version) == 1,
			label + " no silent module/version substitution in slot " + str(slot + 1))
		var prefix: String = "style-%d-%s" % [slot, authored.styles[slot].preset.id]
		check(modules[slot].id == prefix and modules[slot].application == "spatial:" + prefix + "-mask",
			label + " exact style identity is attached to its own native spatial mask")
		var coverage: Dictionary = compiled.coverage[slot]
		check(int(coverage.slot) == slot and coverage.id == authored.styles[slot].preset.id and
			is_equal_approx(float(coverage.requested_percent), float(authored.styles[slot].share)),
			label + " exact requested share and preset identity reach zone coverage")
	return packet

func install_packet(packet: Dictionary, label: String) -> bool:
	var previous_request: int = int(host.tower_context.get("scenario_request_serial", -1))
	dialog.confirmed.emit()
	dialog.hide()
	if not await until(func() -> bool: return installed() and str(wb._generated_active.get("sha256", "")) == str(packet.sha256),
		label + " installs native material source"): return false
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt", {})
	check(receipt.get("generated_source_sha256", "") == packet.sha256, label + " native constructor independently acknowledges material digest")
	check(int(host.tower_context.get("scenario_request_serial", -1)) > previous_request, label + " native installation request completed")
	return failures == 0

func paint_probe(label: String) -> bool:
	wb._brush.value = 1
	if not check(wb.paint(Vector2i(13, 17), 28), label + " ordinary Workbench paint accepted"): return false
	if not await until(func() -> bool: return host.image.get_width() == 512 and host.image.get_pixel(13, 17).r8 == 28,
		label + " native material readback confirms paint"): return false
	return await until(paint_completed, label + " native edit receipts complete")

func individual_showcases() -> void:
	for id: String in SHOWCASES:
		var start_checks: int = checks
		var start_failures: int = failures
		if not choose_modules([id], 271828): return
		if id == SHOWCASES[0]:
			await process_frame
			check(panel.visible and not panel.get_ok_button().disabled, "advanced selection and Generate preview are usable")
			var bounds := Rect2i(Vector2i.ZERO, root.size) if panel.is_embedded() else DisplayServer.screen_get_usable_rect(root.current_screen)
			check(bounds.encloses(Rect2i(panel.position, panel.size)), "existing form fits the actual work area")
			await framebuffer("advanced-selector", panel)
			var chooser: OptionButton = panel._style_controls[0].chooser
			chooser.show_popup()
			await process_frame
			await process_frame
			check(chooser.get_popup().visible, "long built-in selector opens as a usable popup")
			await framebuffer("advanced-selector-menu", chooser.get_popup())
			chooser.get_popup().hide()
		var baseline: Dictionary = await form_generate(id + "-baseline", [id])
		if baseline.is_empty(): return
		preview("native-" + id, baseline.cells, Vector2i(512, 512))
		if not await install_packet(baseline, id): return
		if not await paint_probe(id): return
		if id == SHOWCASES[0]: await framebuffer("single-installed")
		dialog._architecture_button.pressed.emit()
		panel._seed.value = 314159
		var different_seed: Dictionary = await form_generate(id + "-seed-changed", [id])
		if different_seed.is_empty(): return
		var seed_delta: int = changed_cells(baseline.cells, different_seed.cells)
		check(seed_delta > 0, id + " changing seed changes native output")
		dialog._architecture_button.pressed.emit()
		panel._seed.value = 271828
		var reconstructed: Dictionary = await form_generate(id + "-seed-restored", [id])
		if reconstructed.is_empty(): return
		check(reconstructed.sha256 == baseline.sha256 and reconstructed.recipe_sha256 == baseline.recipe_sha256 and
			reconstructed.receipt_hashes == baseline.receipt_hashes, id + " original seed exactly reconstructs native cells and receipts")
		dialog._architecture_button.pressed.emit()
		var room: SpinBox = panel._style_controls[0].geometry.room_size
		var former_room: int = int(room.value)
		room.value = former_room + 16
		var variation: Dictionary = await form_generate(id + "-room-varied", [id])
		if variation.is_empty(): return
		var geometry_delta: int = changed_cells(baseline.cells, variation.cells, true)
		check(geometry_delta > 0, id + " exposed Room / bay changes occupied/empty geometry")
		report.cases.append({"case": "individual-showcase", "module": id, "module_version": 1,
			"seed": 271828, "changed_seed": 314159, "seed_changed_cells": seed_delta,
			"baseline_sha256": baseline.sha256, "restored_sha256": reconstructed.sha256,
			"changed_seed_sha256": different_seed.sha256, "variation_sha256": variation.sha256,
			"room_before": former_room, "room_after": former_room + 16,
			"geometry_changed_cells": geometry_delta, "installed_and_painted": true,
			"checks": checks - start_checks, "failures": failures - start_failures})
		if failures > start_failures: return
	complete = true

func author_mixed() -> void:
	for scenario: int in COMPOSITIONS.size():
		var label := "mixed-a" if scenario == 0 else "mixed-b"
		var ids: Array = COMPOSITIONS[scenario]
		var shares: Array = [30.0, 25.0, 20.0, 15.0, 10.0] if scenario == 0 else [20.0, 20.0, 20.0, 20.0, 20.0]
		if not choose_modules(ids, 161803 + scenario * 110025, Vector2i.ZERO if scenario == 0 else Vector2i(-512, -256), shares): return
		panel._windows.button_pressed = scenario == 1
		panel._style_controls[1].geometry.room_size.value += 8
		if scenario == 1:
			# Exercise the existing declarative style-import path for values which
			# are embedded in presets, not add a new editing interface.
			var custom: Dictionary = panel.project().styles[4].preset.duplicate(true)
			custom.id += "-evaluation"
			custom.name += " Evaluation"
			custom.materials = {"wall": 130, "floor": 114, "window": 120}
			custom.apertures = {"automatic_doors": true, "automatic_windows": false}
			custom.deterioration = 0.12
			write_json(label + "-slot5.style.json", custom)
			if not check(panel.import_style(output_dir().path_join(label + "-slot5.style.json"), 4), "existing Import style retains advanced native module"): return
		var project_path: String = output_dir().path_join(label + ".project.json")
		if not check(panel.save_project(project_path), label + " saves complete editable architectural project"): return
		var authored: Dictionary = panel.project()
		await framebuffer(label + "-form", panel)
		var packet: Dictionary = await form_generate(label + "-preview", ids)
		if packet.is_empty(): return
		check_style_diagnostics(authored, label)
		for entry: Dictionary in dialog._architecture_result.coverage:
			check(components(dialog._architecture_result.zones, int(entry.slot)) == 1, label + " each Gentek has a connected zone")
		preview(label + "-native", packet.cells, Vector2i(512, 512))
		dialog._zone_toggle.button_pressed = true
		await framebuffer(label + "-zones", dialog)
		dialog._zone_toggle.button_pressed = false
		if not await install_packet(packet, label): return
		if not await paint_probe(label): return
		wb._name.text = "gentek-combined-" + label
		if not check(wb.save_setup(), label + " saves installed generated map and paint"): return
		var saved: Dictionary = Store.read_named(wb._name.text)
		check(saved.get("generated", false) and saved.generation.recipe_sha256 == packet.recipe_sha256,
			label + " saved map binds complete compiled recipe")
		await framebuffer(label + "-installed")
		var receipt: Dictionary = {"case": "mixed-author", "selection": label, "modules": ids,
			"project": authored, "project_sha256": Store.recipe_hash(authored),
			"recipe_sha256": packet.recipe_sha256, "native_sha256": packet.sha256,
			"receipt_hashes": packet.receipt_hashes, "saved_edits": saved.setup.edits,
			"coverage": dialog._architecture_result.coverage,
			"author_pid": OS.get_process_id(), "author_process": OS.get_environment("CYBERSAND_COMBINED_PROCESS"),
			"campaign_id": OS.get_environment("CYBERSAND_COMBINED_CAMPAIGN")}
		write_json(label + "-authored.json", receipt)
		report.cases.append(receipt)
		if failures: return
	complete = true

func reopen_mixed() -> void:
	for scenario: int in COMPOSITIONS.size():
		var label := "mixed-a" if scenario == 0 else "mixed-b"
		var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output_dir().path_join(label + "-authored.json")))
		if not check(not authored.is_empty() and authored.campaign_id == OS.get_environment("CYBERSAND_COMBINED_CAMPAIGN"),
			label + " consumes this campaign's completed author receipt"): return
		# PIDs may be reused after exit (and repeat in isolated PID namespaces).
		# The runner verifies complete process termination and supplies a new
		# nonce to each actual subprocess; PID inequality alone is not proof.
		check(not str(authored.author_process).is_empty() and
			authored.author_process != OS.get_environment("CYBERSAND_COMBINED_PROCESS"),
			label + " fresh application invocation differs from author")
		dialog._architecture_button.pressed.emit()
		if not check(panel.load_project(output_dir().path_join(label + ".project.json")), label + " Load project restores editable controls"): return
		var restored: Dictionary = panel.project()
		check(Store.recipe_hash(restored) == authored.project_sha256,
			label + " full project identity, module versions, seed, shares, geometry, materials, apertures and deterioration survive")
		for slot: int in 5:
			check(restored.styles[slot].preset.module == COMPOSITIONS[scenario][slot], label + " restored advanced module " + str(slot + 1))
		await framebuffer(label + "-reopened-project", panel)
		var regenerated: Dictionary = await form_generate(label + "-reopened-project-preview", COMPOSITIONS[scenario])
		if regenerated.is_empty(): return
		check(regenerated.sha256 == authored.native_sha256 and regenerated.recipe_sha256 == authored.recipe_sha256 and
			regenerated.receipt_hashes == authored.receipt_hashes, label + " loaded project exactly reconstructs native materials")
		# Workbench map Load is a separate existing persistence route. It must
		# recover the installed result and paint without requiring the form.
		wb._name.text = "gentek-combined-" + label
		preview_clock.begin()
		if not check(wb.load_setup(), label + " named map Load starts fresh native reconstruction"): return
		if not await preview_ready(label + "-reopened-map-preview"): return
		var packet: Dictionary = dialog._ready_packet.duplicate(true)
		check(packet.sha256 == authored.native_sha256 and packet.recipe_sha256 == authored.recipe_sha256 and
			packet.receipt_hashes == authored.receipt_hashes, label + " map native material and receipt reconstruction is exact")
		if not await install_packet(packet, label + " fresh map"): return
		# The evidence JSON reader yields numeric floats, while the validated
		# Workbench setup restores integer edits. Compare their canonical values.
		check(Store.recipe_hash({"edits": wb.applied.edits}) == Store.recipe_hash({"edits": authored.saved_edits}),
			label + " saved ordered paint operations survive exit")
		if not await until(func() -> bool: return host.image.get_width() == 512 and host.image.get_pixel(13, 17).r8 == 28,
			label + " fresh native World contains saved painted material"): return
		await framebuffer(label + "-reopened-installed")
		preview(label + "-reopened-native", packet.cells, Vector2i(512, 512))
		report.cases.append({"case": "mixed-reopen", "selection": label, "modules": COMPOSITIONS[scenario],
			"project_sha256": Store.recipe_hash(restored), "recipe_sha256": packet.recipe_sha256,
			"native_sha256": packet.sha256, "author_pid": authored.author_pid, "reopen_pid": OS.get_process_id(),
			"author_process": authored.author_process, "reopen_process": OS.get_environment("CYBERSAND_COMBINED_PROCESS"),
			"saved_paint_material": int(host.image.get_pixel(13, 17).r8), "complete_project_fields_retained": true})
		if failures: return
	complete = true

func run() -> void:
	var began := Time.get_ticks_usec()
	var phase: String = OS.get_environment("CYBERSAND_COMBINED_PHASE")
	report.merge({"phase": phase, "source_commit": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"campaign_id": OS.get_environment("CYBERSAND_COMBINED_CAMPAIGN"), "pid": OS.get_process_id(),
		"process_instance": OS.get_environment("CYBERSAND_COMBINED_PROCESS"),
		"godot": Engine.get_version_info().string, "os": OS.get_name(), "os_version": OS.get_version(),
		"display": DisplayServer.get_name(), "rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "physical_windows11_acceptance": false,
		"interaction": "automated existing UI signals and production preview/install/persistence; not manual owner acceptance"})
	if check(ClassDB.class_exists(&"CyberWorldGenerator"), "native generator runtime exists") and await mount_workbench():
		match phase:
			"singles": await individual_showcases()
			"author": await author_mixed()
			"reopen": await reopen_mixed()
			_: check(false, "unknown combined qualification phase")
	check(complete, "mandatory complete " + phase + " campaign")
	var receipt_file := FileAccess.open(output_dir().path_join("combined-" + phase + ".json"), FileAccess.WRITE)
	check(receipt_file != null, "write final combined campaign receipt")
	report.checks = checks
	report.failures = failures
	report.complete = complete
	report.elapsed_us = Time.get_ticks_usec() - began
	if receipt_file != null:
		receipt_file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
		receipt_file.close()
	if host != null:
		preview_clock.queue_free()
		host.queue_free()
		await process_frame
		await process_frame
	print("GENTEK_COMBINED_RESULTS phase=", phase, " checks=", checks, " failures=", failures, " complete=", complete)
	quit(1 if failures else 0)
