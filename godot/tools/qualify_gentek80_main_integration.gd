extends "res://tests/test_architectural_generator.gd"

# Bounded join qualification: accepted Genteks, large authored starts, the real
# keyboard/native/Rapier owner and unopened Art share the ordinary Workbench.
# Only the window-focus predicate is supplied by the apparatus (as in the
# existing Workbench input regression); keyboard dispatch itself is unchanged.
const Setup = preload("res://scripts/workbench_setup.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const STYLES: Array[String] = ["ring-pier", "tripod-frame", "cascade-terrace",
	"scalloped-vault", "suspended-deck", "buttress-wall", "cathedral-megaframe"]
const LANDSCAPE_NAME := "gentek-main-graftloom"
const EXPECTATION := "user://gentek-main-expectation.json"

class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var phase := ""
var archive_hash := ""
var archive_files := PackedStringArray()
var expected: Dictionary = {}
var completed_styles := 0

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func lazy_art(label: String) -> bool:
	var panel: Window = wb.art_batches
	var names := DirAccess.get_files_at("user://art-traffic")
	names.sort()
	var ok: bool = not panel.visible and panel.conversation_loaded and panel.conversation.is_empty() \
		and not panel.provider.resume_active and panel.provider.log_path.is_empty() \
		and panel.provider.parent_log_path.is_empty() \
		and names == archive_files \
		and FileAccess.get_sha256("user://art-traffic/legacy.jsonl") == archive_hash
	return check(ok, label + ": unopened Art stays deferred and historical traffic stays exact")

func stored_materials(label: String) -> Dictionary:
	var extent := Setup.extent_of(wb.applied)
	var generation := int(host.latest_snapshot.render_world_generation)
	var admission: Dictionary = host.simulation_worker.material_capture_request(generation, extent.x * extent.y * 2)
	if not check(admission.get("ok", false), label + ": native material capture admitted"): return {}
	var token := int(admission.token)
	if not await until(func() -> bool: return not host.simulation_worker.material_capture_poll(token).is_empty(), label + ": native capture completed"):
		host.simulation_worker.material_capture_cancel(token)
		return {}
	var captured: Dictionary = host.simulation_worker.material_capture_poll(token)
	host.simulation_worker.material_capture_finish(token, false)
	if not check(captured.get("ok", false) and captured.get("extent") == extent \
		and captured.get("cells") is PackedByteArray and captured.cells.size() == extent.x * extent.y * 2,
		label + ": exact native stored-material extent"): return {}
	check(Store.digest(captured.cells) == captured.sha256, label + ": native material SHA256 recomputes")
	return captured

func reference_cells(setup: Dictionary) -> PackedByteArray:
	# Independent ordered authored-stamp replay, not Setup.rectangles().
	var extent := Setup.extent_of(setup)
	var cells := PackedByteArray()
	cells.resize(extent.x * extent.y)
	for stamp: Array in setup.edits:
		if stamp.size() == 5:
			for y: int in range(int(stamp[1]), int(stamp[1]) + int(stamp[3])):
				for x: int in range(int(stamp[0]), int(stamp[0]) + int(stamp[2])):
					cells[y * extent.x + x] = int(stamp[4])
		else:
			var radius := int(stamp[2])
			for y: int in range(maxi(0, int(stamp[1]) - radius), mini(extent.y, int(stamp[1]) + radius + 1)):
				for x: int in range(maxi(0, int(stamp[0]) - radius), mini(extent.x, int(stamp[0]) + radius + 1)):
					if (x - int(stamp[0])) ** 2 + (y - int(stamp[1])) ** 2 <= radius * radius:
						cells[y * extent.x + x] = int(stamp[3])
	return cells

func decode_claim(value: Variant) -> Variant:
	if value is Dictionary:
		if value.size() == 1 and value.has("integer_decimal"): return int(value.integer_decimal)
		var decoded := {}
		for name: String in value: decoded[name] = decode_claim(value[name])
		return decoded
	if value is Array:
		var decoded: Array = []
		for item: Variant in value: decoded.append(decode_claim(item))
		return decoded
	return value

func compare_materials(captured: Dictionary, cells: PackedByteArray, label: String) -> bool:
	if captured.is_empty(): return false
	var stored: PackedByteArray = captured.cells
	if not check(stored.size() == cells.size() * 2, label + ": equal complete cell counts"): return false
	var mismatches := 0
	for index: int in cells.size():
		if stored.decode_u16(index * 2) != int(cells[index]): mismatches += 1
	return check(mismatches == 0, label + ": all native material identities agree (%d cells)" % cells.size())

func paint_cell(position: Vector2i, material: int) -> bool:
	wb._brush.value = 1
	if not check(wb.paint(position, material), "ordinary paint/erase admitted"): return false
	return await until(func() -> bool: return paint_completed() and host.image.get_pixelv(position).r8 == material, "ordinary paint/erase acknowledged by native World")

func load_landscape(first: bool) -> bool:
	var source_path := OS.get_environment("GENTEK_MAIN_LANDSCAPE")
	if first:
		if not check(FileAccess.get_sha256(source_path) == OS.get_environment("GENTEK_MAIN_LANDSCAPE_SHA256"), "pinned original landscape source bytes"): return false
		DirAccess.make_dir_recursive_absolute(Setup.DIRECTORY)
		if not check(DirAccess.copy_absolute(source_path, Setup._path(LANDSCAPE_NAME)) == OK, "stage original landscape for ordinary Load start"): return false
	wb._name.text = LANDSCAPE_NAME
	var generation := int(host.latest_snapshot.render_world_generation)
	if not check(wb.load_setup(), "ordinary large-landscape Load start admitted"): return false
	if not await until(func() -> bool: return installed() and int(host.latest_snapshot.render_world_generation) > generation \
		and host._physical_terrain_ready and host.image.get_size() == Vector2i(2048, 1024), "large landscape and Rapier owner installed"): return false
	if not check(wb._generated_active.is_empty(), "authored landscape retires prior generator source"): return false
	var runs: Dictionary = Setup.rectangles(wb.applied)
	if not check(not runs.has("error") and runs.runs.size() / 5 > 6553, "actual 2048x1024 source exceeds old host-claim boundary"): return false
	var captured := await stored_materials("large landscape")
	if not compare_materials(captured, reference_cells(wb.applied), "complete landscape"): return false
	if first:
		check(wb.applied.edits.size() == 13839, "exact original landscape rectangle count retained")
		check(Store.digest(reference_cells(wb.applied)) == OS.get_environment("GENTEK_MAIN_LANDSCAPE_GRID_SHA256"), "independent original landscape raster matches pinned identity")
	var serial := int(host.tower_context.get("micro_capture_serial", 0))
	host.microscenario_capture()
	if not await until(func() -> bool: return int(host.tower_context.get("micro_capture_serial", 0)) > serial, "native large-map observation captured"): return false
	var capture: Dictionary = host.tower_context.micro_capture
	var validated: Dictionary = Contract.validate(capture.definition)
	check(validated.get("ok", false) and capture.definition_hash == validated.hash \
		and validated.definition.rectangles == runs.runs, "large-map full geometry and canonical definition remain authoritative")
	var observation: Dictionary = capture.liquid_host_observation_record
	var claims: Dictionary = decode_claim(observation.values.host_claims.values)
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt", {})
	check(claims.has("definition_projection") and not claims.definition.has("rectangles") \
		and int(claims.definition_projection.rectangle_count) == runs.runs.size() / 5 \
		and claims.definition_projection.validated_complete_definition_sha256 == validated.hash,
		"large-map observation projects only the redundant oversized claim")
	check(receipt.get("workbench_extent") == Vector2i(2048, 1024) \
		and receipt.get("receipt_hash", "") == observation.identity.native_receipt_hash \
		and not str(receipt.get("receipt_hash", "")).is_empty() \
		and int(receipt.get("initial_body_count", -1)) == host.physical_actor_session.bodies().size(),
		"positive native prepared receipt binds extent, real bodies and host observation")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	check(int(bridge.workbench_start_rectangle_capacity()) == 32768, "native rectangle capacity remains 32768")
	var row := {"case": "landscape", "first": first, "source_rectangles": 13839,
		"installed_rectangles": runs.runs.size() / 5, "extent": [2048, 1024],
		"stored_material_sha256": captured.sha256, "definition_sha256": validated.hash,
		"actor_count": wb.applied.actors.size(), "native_rectangle_capacity": 32768,
		"native_receipt_sha256": receipt.receipt_hash, "claim_projection": claims.definition_projection}
	report.cases.append(row)
	if first:
		if not await paint_cell(Vector2i(400, 400), 58): return false
		if not await paint_cell(Vector2i(410, 400), 0): return false
		if not check(wb.save_setup(), "large landscape edited authored start saved"): return false
		var saved: Dictionary = Setup.read_named(LANDSCAPE_NAME)
		check(saved.setup.edits.size() == 13841, "every original rectangle and two edits preserved")
		expected.landscape_save_sha256 = FileAccess.get_sha256(Setup._path(LANDSCAPE_NAME))
	else:
		check(FileAccess.get_sha256(Setup._path(LANDSCAPE_NAME)) == expected.landscape_save_sha256, "large authored save survives Gentek use and fresh process unchanged")
	wb._set_view(Vector2.ZERO, Vector2i(2048, 1024))
	await framebuffer("main-landscape-" + phase + ("-initial" if first else "-after-genteks"))
	return lazy_art("landscape admission")

func select_style(identity: String) -> bool:
	dialog.open_new()
	dialog._architecture_button.pressed.emit()
	var form: ConfirmationDialog = dialog._architecture
	var project: Dictionary = Project.default_project()
	project.extent = [512, 512]
	project.zone_scale = 64
	project.seed = 605
	project.automatic_tunnels = false
	project.styles = [{"enabled": true, "share": 100.0, "preset": Project.builtin_presets()[0].duplicate(true)}]
	if not check(form.set_project(project), identity + ": ordinary architecture form initialized"): return false
	var chooser: OptionButton = form._style_controls[0].chooser
	var presets: Array = Project.builtin_presets()
	var found := false
	for item: int in chooser.item_count:
		var index := chooser.get_item_id(item)
		if index >= 0 and index < presets.size() and presets[index].id == identity:
			chooser.select(item)
			chooser.item_selected.emit(item)
			found = true
			break
	if not check(found and form.project().styles[0].preset.id == identity, identity + ": selected through ordinary dropdown"): return false
	if completed_styles == 0:
		check(chooser.item_count == 93, "all 80 Genteks and 13 accepted presets remain accessible")
		await framebuffer("main-architecture-form", form)
		if DisplayServer.get_name() != "headless":
			chooser.show_popup()
			await process_frame
			await process_frame
			var popup: PopupMenu = chooser.get_popup()
			check(popup.visible, "ordinary catalogue dropdown visibly expanded")
			await framebuffer("main-expanded-catalogue", popup)
			popup.hide()
	preview_clock.begin()
	form._apply()
	return true

func rectangle(region: Rect2i, material: int) -> bool:
	var cells := PackedInt32Array()
	cells.resize(region.get_area() * 3)
	var cursor := 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			cells[cursor] = x
			cells[cursor + 1] = y
			cells[cursor + 2] = material
			cursor += 3
	if not check(wb.paint_editor.commit_cells(cells, "Gentek integration authored rectangle"), "ordinary native PAINT rectangle admitted"): return false
	return await until(func() -> bool: return not wb.paint_editor.busy() and paint_completed(), "ordinary native PAINT rectangle completed")

func pilot() -> bool:
	var session: CyberPhysicalActorSession = host.physical_actor_session
	if not check(session != null and wb.pilot_slot >= 0 and not wb.body_state(wb.selected_id()).is_empty(), "generated architecture has a selected real Rapier Midge"): return false
	var material_before := await stored_materials("before concurrent flyer/material play")
	if material_before.is_empty(): return false
	var focus: Control = root.gui_get_focus_owner()
	if focus != null: focus.release_focus()
	key(KEY_W, false)
	key(KEY_D, false)
	if not check(wb.toggle_pause(), "ordinary Play resumes native and Rapier owners"): return false
	if not await until(func() -> bool: return not host._actor_input_rearm, "neutral keyboard frame rearms human input"): return false
	var before: Dictionary = session.workbench_actor_state(wb.selected_id())
	var native_tick := int(host.latest_snapshot.tick_index)
	var physical_tick := int(session.tick)
	key(KEY_W, true)
	key(KEY_D, true)
	var peak_force := 0.0
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and (int(host.latest_snapshot.tick_index) < native_tick + 30 or int(session.tick) < physical_tick + 30):
		await process_frame
		var state: Dictionary = session.workbench_actor_state(wb.selected_id())
		peak_force = maxf(peak_force, Vector2(state.get("controller", {}).get("applied_force", Vector2.ZERO)).length())
		if host.simulation_worker.has_failed(): break
	key(KEY_W, false)
	key(KEY_D, false)
	var after: Dictionary = session.workbench_actor_state(wb.selected_id())
	var distance := Vector2(before.position).distance_to(Vector2(after.position))
	check(int(host.latest_snapshot.tick_index) >= native_tick + 30 and int(session.tick) >= physical_tick + 30,
		"generated architecture permits concurrent native and Rapier progression")
	check(peak_force > 0.0 and distance > 0.25, "actual keyboard publisher produces flyer thrust and displacement")
	var progression := {"case": "keyboard-flyer", "model": "midge", "native_ticks": int(host.latest_snapshot.tick_index) - native_tick,
		"rapier_ticks": int(session.tick) - physical_tick, "peak_force": peak_force, "distance": distance,
		"input": "InputEventKey W+D through ordinary Main keyboard publisher; focus predicate supplied"}
	if not check(wb.toggle_pause(), "ordinary Pause stops live playback"): return false
	var material_after := await stored_materials("after concurrent flyer/material play")
	if material_after.is_empty(): return false
	var before_cells: PackedByteArray = material_before.cells
	var after_cells: PackedByteArray = material_after.cells
	var changed := 0
	var sand_changed := 0
	var sand_before := 0
	var sand_after := 0
	for index: int in before_cells.size() / 2:
		var a := before_cells.decode_u16(index * 2)
		var b := after_cells.decode_u16(index * 2)
		if a == 2: sand_before += 1
		if b == 2: sand_after += 1
		if a != b:
			changed += 1
			if a == 2 or b == 2: sand_changed += 1
	check(changed > 0 and sand_changed > 0 and sand_before == 64 and sand_after == 64,
		"real native Sand moves while preserving its 64 cells during concurrent flyer play")
	progression.merge({"material_id": 2, "material_name": "Sand", "sand_cells_before": sand_before,
		"sand_cells_after": sand_after, "changed_material_cells": changed, "changed_sand_occupancy_cells": sand_changed,
		"stored_material_sha256_before": material_before.sha256, "stored_material_sha256_after": material_after.sha256})
	report.cases.append(progression)
	wb._set_view(Vector2(160, 0), Vector2i(240, 150))
	await framebuffer("main-cathedral-playable-flyer-" + phase)
	return lazy_art("human input and native simulation")

func style_case(identity: String) -> bool:
	var name := "gentek-main-" + identity
	if phase == "author":
		if not await select_style(identity): return false
	else:
		wb._name.text = name
		preview_clock.begin()
		if not check(wb.load_setup(), identity + ": fresh-process ordinary Load start admitted"): return false
	if not await preview_ready("main-" + identity + "-" + phase + "-preview"): return false
	var packet: Dictionary = dialog._ready_packet.duplicate(true)
	var previous := int(host.latest_snapshot.render_world_generation)
	dialog.confirmed.emit()
	dialog.hide()
	if not await until(func() -> bool: return installed() and int(host.latest_snapshot.render_world_generation) > previous \
		and wb._generated_active.get("sha256", "") == packet.sha256, identity + ": generated native World installed"): return false
	check(host.tower_context.get("liquid_construction_receipt", {}).get("generated_source_sha256", "") == packet.sha256,
		identity + ": native construction attests actual generated source")
	if phase == "author":
		if not compare_materials(await stored_materials(identity + " intact"), packet.cells, identity + " intact generated material raster"): return false
		if not await paint_cell(Vector2i(12, 12), 58): return false
		if not await paint_cell(Vector2i(20, 12), 0): return false
		if identity == "cathedral-megaframe":
			if not await rectangle(Rect2i(208, 8, 96, 120), 0): return false
			if not await rectangle(Rect2i(280, 20, 8, 8), 2): return false
			if not check(wb.place("midge", Vector2(248, 68)), "ordinary Place installs Midge beside generated Cathedral"): return false
			if not await until(func() -> bool: return installed() and host._physical_terrain_ready, "generated terrain and real flyer adopted"): return false
		wb._name.text = name
		if not check(wb.save_setup(), identity + ": generated authored start saved"): return false
	var saved: Dictionary = Store.read_named(name)
	if not check(saved.get("generated", false) and saved.generation.recipe_sha256 == packet.recipe_sha256 \
		and saved.setup.edits == wb.applied.edits and saved.setup.actors == wb.applied.actors,
		identity + ": saved recipe, acknowledged edits and actors retained"): return false
	var captured := await stored_materials(identity + " authored")
	if captured.is_empty(): return false
	var row := {"source_sha256": packet.sha256, "recipe_sha256": packet.recipe_sha256,
		"stored_material_sha256": captured.sha256, "actors": saved.setup.actors.size(), "edits": saved.setup.edits.size(),
		"setup_sha256": Store.recipe_hash(saved.setup), "actors_sha256": Store.recipe_hash({"actors": saved.setup.actors}),
		"ordered_edits_sha256": Store.recipe_hash({"edits": saved.setup.edits}),
		"saved_file_sha256": FileAccess.get_sha256(Setup._path(name))}
	if phase == "author": expected.styles[identity] = row
	else: check(JSON.parse_string(JSON.stringify(row)) == expected.styles[identity], identity + ": fresh process exactly restores native materials, complete setup, actors and ordered edits")
	report.cases.append({"case": "gentek", "id": identity, "identity": row})
	wb._set_view(Vector2.ZERO, Vector2i(512, 512))
	await framebuffer("main-" + identity + "-" + phase + "-installed")
	if identity == "cathedral-megaframe":
		if not await pilot(): return false
	else:
		var tick := int(host.latest_snapshot.tick_index)
		if not check(wb.step_once(), identity + ": ordinary Step admitted"): return false
		if not await until(func() -> bool: return not wb.step_pending and int(host.latest_snapshot.tick_index) == tick + 1, identity + ": actual native tick completed"): return false
	completed_styles += 1
	print("GENTEK_MAIN_PROGRESS ", phase, " ", completed_styles, "/", STYLES.size(), " ", identity)
	return lazy_art(identity + " preview/install/save")

func exercise_main() -> void:
	if OS.get_environment("CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS") == "1":
		if not check(DisplayServer.get_name() != "headless", "actual graphical display required"): return
	if not check(Project.builtin_presets().size() == 93 and ClassDB.class_exists(&"CyberWorldGenerator"), "complete catalogue and actual native generator available"): return
	var user_dir := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	var required_dir := OS.get_environment("ART_LIFETIME_USER_DIR").replace("\\", "/").simplify_path()
	if OS.get_name() == "Windows":
		user_dir = user_dir.to_lower()
		required_dir = required_dir.to_lower()
	if not check(not required_dir.is_empty() and user_dir == required_dir, "disposable fixture profile required"): return
	archive_hash = FileAccess.get_sha256("user://art-traffic/legacy.jsonl")
	archive_files = DirAccess.get_files_at("user://art-traffic")
	archive_files.sort()
	if not check(not archive_hash.is_empty() and archive_files.size() == 1, "seeded existing Art archive present"): return
	if phase == "reopen":
		var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXPECTATION))
		if not check(decoded is Dictionary, "previous-process expectations exist"): return
		expected = decoded
	else: expected = {"styles": {}}
	root.size = Vector2i(1600, 1000)
	set_meta("cybersand_feature", "shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	dialog = wb._generated_dialog
	preview_clock = PreviewClock.new()
	preview_clock.dialog = dialog
	root.add_child(preview_clock)
	if not await until(installed, "ordinary Workbench starts"): return
	if not lazy_art("startup"): return
	if not await load_landscape(phase == "author"): return
	for identity: String in STYLES:
		if not await style_case(identity): return
	if not await load_landscape(false): return
	if phase == "author":
		var file := FileAccess.open(EXPECTATION, FileAccess.WRITE)
		if not check(file != null, "write independent-process expectations"): return
		file.store_string(JSON.stringify(expected))
		file.close()
	complete = completed_styles == STYLES.size() and failures == 0

func run() -> void:
	phase = OS.get_environment("GENTEK_MAIN_PHASE")
	var began := Time.get_ticks_usec()
	if check(phase in ["author", "reopen"], "explicit integration phase"):
		await exercise_main()
	key(KEY_W, false)
	key(KEY_D, false)
	check(complete, "complete Gentek/main cross-integration campaign")
	report.merge({"schema": "gentek80-main-integration-phase-v1", "phase": phase,
		"source_commit": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "process_id": OS.get_process_id(),
		"godot": Engine.get_version_info().string, "os": OS.get_name(), "display": DisplayServer.get_name(),
		"checks": checks, "failures": failures, "completed": complete, "styles": completed_styles,
		"style_ids": STYLES, "catalogue_choices": Project.builtin_presets().size(),
		"archive_sha256": archive_hash, "elapsed_us": Time.get_ticks_usec() - began}, true)
	write_json("gentek-main-" + phase + ".json", report)
	if is_instance_valid(preview_clock): preview_clock.queue_free()
	if is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame
	print("GENTEK_MAIN_INTEGRATION phase=", phase, " styles=", completed_styles, " checks=", checks, " failures=", failures, " complete=", complete)
	quit(1 if failures else 0)
