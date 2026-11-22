extends SceneTree

# Generated source -> ordinary mounted PAINT -> authored-start save. Run again
# in a fresh application process with PAINT_GENERATED_REOPEN=1 and the same
# XDG_DATA_HOME to verify reconstruction through the existing generator dialog.
const Setup = preload("res://scripts/workbench_setup.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
const SAVE_NAME := "paint001-generated-acceptance"
const EXPECTED_PATH := "user://paint001-generated-native-expectation.json"
const AUTHORED_REGION := Rect2i(40, 40, 120, 110)
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var bench: Control
var editor: Control
var dialog: ConfirmationDialog
var checks := 0
var failures: Array[String] = []
var completed := false
var started_usec := 0


func _initialize() -> void:
	started_usec = Time.get_ticks_usec()
	run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("PAINT_EDITOR_GENERATED_WORKBENCH " + label)
	return ok


func until(predicate: Callable, label: String, limit_ms: int = 60000) -> bool:
	var deadline: int = Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): break
		await process_frame
	return check(false, label + " / " + str(bench.message) + " / " + dialog._status.text)


func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() \
		and host.pending_microscenario_apply.is_empty() and not host.simulation_worker.paint_state().busy


func settled() -> bool:
	return not editor.busy() and not host.simulation_worker.paint_state().busy


func local(cell: Vector2i) -> Vector2:
	var area: Rect2 = host.view_content_rect()
	return area.position + (Vector2(cell) + Vector2(0.5, 0.5) - Vector2(host.presentation_camera_origin())) \
		* area.size / Vector2(host.current_view_size)


func gesture(tool: String, from: Vector2i, to: Vector2i, material: int = 58,
		button: int = MOUSE_BUTTON_LEFT) -> bool:
	editor.select_tool(tool)
	editor.select_material(material)
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.position = local(from)
	bench._world_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = local(to)
	motion.relative = motion.position - press.position
	bench._world_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = button
	release.position = local(to)
	bench._world_input(release)
	if not await until(settled, tool + " native operation completes"): return false
	if tool == "Select": return true
	return check(editor.last_receipt.get("status") == "completed", tool + " native completion acknowledged")


func capture(region: Rect2i) -> PackedInt32Array:
	var worker: RefCounted = host.simulation_worker
	var state: Dictionary = worker.paint_state()
	var admission: Dictionary = worker.paint_queue({"kind": "capture", "region": region,
		"expected_generation": int(state.generation), "expected_revision": int(state.revision),
		"expected_tick": int(state.tick)})
	if not check(admission.status == "queued", "independent native capture admitted"): return PackedInt32Array()
	if not await until(func() -> bool: return worker.paint_state().receipt_ready,
			"independent native capture receipt"): return PackedInt32Array()
	var result: Dictionary = worker.paint_take_result()
	check(result.status == "completed", "independent native capture completed")
	return result.get("materials", PackedInt32Array())


func screenshot(label: String) -> void:
	var directory := OS.get_environment("PAINT_CAPTURE_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK,
		"actual graphical framebuffer " + label)


func generator_ready() -> bool:
	return dialog._phase == "ready" or dialog._status.text.begins_with("Refused")


func json_equivalent(actual: Variant, expected: Variant) -> bool:
	# Store.read_named deliberately restores validated integer types; JSON
	# expectation files decode all numbers as floats. Compare both in the
	# same JSON value domain, preserving every field/value and array order.
	return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected))


func author() -> void:
	# Reuse EXPLORE-001's admitted native strata/override path and bounded
	# dialog generation. The source has real terrain and Water, plus a clear
	# authored area and separate flyer clearance; no second simulation World.
	var recipe: Dictionary = {"schema": 1, "seed": 917, "chunk_size": 64,
		"candidate": "strata", "parameters": {"surface_y": 0, "relief": 0, "fluid_level": 64},
		"themes": {"weights": {"basalt": 1}, "exclude": []}, "overrides": [
			{"id": "paint-clear-area", "bounds": [288, 288, 192, 192], "material": 0},
			{"id": "paint-generated-wall", "bounds": [304, 304, 64, 64], "material": 58},
			{"id": "paint-generated-water", "bounds": [384, 304, 32, 32], "material": 3},
			{"id": "paint-generated-sand", "bounds": [400, 352, 16, 16], "material": 2},
			{"id": "paint-generated-floor", "bounds": [288, 456, 192, 8], "material": 58}]}
	dialog.open_new()
	dialog._saved_recipe = recipe
	dialog._extent.select(0)
	dialog._x.set_value_no_signal(256)
	dialog._y.set_value_no_signal(256)
	dialog._start()
	if not await until(generator_ready, "native generated 512-square preview", 180000): return
	if not check(dialog._phase == "ready", "native generator preview accepted"): return
	var source: Dictionary = dialog._ready_packet.duplicate(true)
	if not check(source.cells.size() == 512 * 512 and not source.receipt_hashes.is_empty(),
			"complete native source material bytes and generation receipts"): return
	check(source.cells[60 * 512 + 60] == 58 and source.cells[50 * 512 + 130] == 3
		and source.cells[170 * 512 + 170] == 0, "generated terrain, Water and flyer clearance")
	var setup: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy), Vector2i(512, 512))
	if not check(bench.install_generated_start(setup, source), "generated World install admitted"): return
	dialog.hide()
	if not await until(ready, "generated native World installed"): return
	check(bench._generated_active.sha256 == source.sha256 and bench.applied.edits.is_empty(),
		"generated source retained outside authored edit history")
	check(host.latest_snapshot.backend_name == "native-phased", "actual native-phased World")
	if not check(bench.place("midge", Vector2(180, 160)), "real flyer placement admitted"): return
	if not await until(ready, "flyer and retained generated World installed"): return
	check(bench.select_instance(1), "flyer selected")
	check(not bench.body_state(1).is_empty(), "real Rapier flyer registered")
	bench._set_view(Vector2(24, 24), Vector2i(240, 135))
	bench._brush.value = 0
	await process_frame
	var tick: int = host.simulation_worker.paint_state().tick
	if not await gesture("Rectangle", Vector2i(56, 56), Vector2i(71, 71), 7): return
	if not await gesture("Rectangle", Vector2i(64, 56), Vector2i(71, 63), 3): return
	if not await gesture("Brush", Vector2i(56, 56), Vector2i(56, 56), 58, MOUSE_BUTTON_RIGHT): return
	if not await gesture("Line", Vector2i(120, 120), Vector2i(150, 130), 77): return
	var copied: PackedInt32Array = await capture(Rect2i(56, 56, 16, 16))
	if not check(copied.size() == 256 and copied[0] == 0 and copied[8] == 3 and copied[255] == 7,
			"native mixed material source includes exact Empty and Water"): return
	if not await gesture("Select", Vector2i(56, 56), Vector2i(71, 71)): return
	check(editor.selection == Rect2i(56, 56, 16, 16), "selection uses panned/zoomed world cells")
	if not check(editor.copy_selection(), "native Copy admitted"): return
	if not await until(settled, "native Copy completed"): return
	check(editor.clipboard.get("materials") == copied, "clipboard preserves native material identities")
	editor.select_tool("Paste")
	if not check(editor.tool_name() == "Paste", "Paste tool selected"): return
	if not check(editor.paste_at(Vector2i(64, 64)), "overlapping mixed Paste admitted"): return
	if not await until(settled, "native mixed Paste completed"): return
	check(await capture(Rect2i(64, 64, 16, 16)) == copied,
		"overlap copies immutable native source including Empty")
	if not await gesture("Rectangle", Vector2i(98, 98), Vector2i(101, 101), 0): return
	check(await capture(Rect2i(98, 98, 4, 4)) == PackedInt32Array([
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]), "erase removes original generated terrain")
	var actual: PackedInt32Array = await capture(AUTHORED_REGION)
	if not check(actual.size() == AUTHORED_REGION.get_area(), "all authored cells captured natively"): return
	var expected_start: PackedByteArray = source.cells.duplicate()
	for y: int in range(AUTHORED_REGION.size.y):
		for x: int in range(AUTHORED_REGION.size.x):
			expected_start[(AUTHORED_REGION.position.y + y) * 512 + AUTHORED_REGION.position.x + x] = actual[y * AUTHORED_REGION.size.x + x]
	check(host.simulation_worker.paint_state().tick == tick and host.paused,
		"authoring remained paused; no evolved simulation snapshot is being saved")
	check(bench._generated_active.sha256 == source.sha256 and Store.digest(bench._generated_active.cells) == source.sha256,
		"painting preserved original generated source bytes and provenance")
	bench._name.text = SAVE_NAME
	if not check(bench.save_setup(), "generated authored start saved after native acknowledgements"): return
	var saved: Dictionary = Store.read_named(SAVE_NAME)
	if not check(saved.get("generated", false), "existing generated-start format readable"): return
	check(saved.generation.sha256 == source.sha256 and saved.setup.edits == bench.applied.edits
		and not saved.setup.edits.is_empty(), "saved source identity and exact acknowledged edits")
	check(saved.setup.actors == bench.applied.actors and saved.setup.selected == 1
		and saved.setup.liquid_policy == bench.applied.liquid_policy, "save preserves actors, selection and solver policy")
	var expectation: Dictionary = {"generation": saved.generation, "actors": saved.setup.actors,
		"selected": saved.setup.selected, "liquid_policy": saved.setup.liquid_policy,
		"response": saved.setup.response, "rule_radius": saved.setup.rule_radius,
		"edits": saved.setup.edits, "prepared_sha256": Store.digest(expected_start),
		"native_region": Marshalls.raw_to_base64(PackedByteArray(Array(actual)))}
	var file := FileAccess.open(EXPECTED_PATH, FileAccess.WRITE)
	if not check(file != null, "independent native expectation file opened"): return
	file.store_string(JSON.stringify(expectation))
	file.close()
	editor.select_tool("Select")
	editor.selection = Rect2i(56, 56, 24, 24)
	await screenshot("paint001-generated-authored")
	completed = true
	print("PAINT_GENERATED_SOURCE ", JSON.stringify({"source_sha256": source.sha256,
		"prepared_sha256": expectation.prepared_sha256, "recipe_sha256": source.recipe_sha256,
		"native_receipts": source.receipt_hashes.size(), "authored_stamps": saved.setup.edits.size()}))


func reopen() -> void:
	var file := FileAccess.open(EXPECTED_PATH, FileAccess.READ)
	if not check(file != null, "previous-process native expectation available"): return
	var expected: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not check(expected is Dictionary, "previous-process expectation parsed"): return
	var saved: Dictionary = Store.read_named(SAVE_NAME)
	if not check(saved.get("generated", false), "fresh-process generated authored start readable"): return
	check(json_equivalent(saved.generation, expected.generation) and json_equivalent(saved.setup.edits, expected.edits),
		"fresh-process saved provenance and authored history unchanged")
	bench._name.text = SAVE_NAME
	if not check(bench.load_setup(), "ordinary named Load opens existing generator regeneration"): return
	if not await until(generator_ready, "saved native generation regenerated", 180000): return
	if not check(dialog._phase == "ready", "saved native preview source identities accepted"): return
	check(dialog._ready_packet.sha256 == expected.generation.sha256
		and dialog._ready_packet.receipt_hashes == expected.generation.receipt_hashes,
		"fresh process regenerates original native material source and receipts")
	dialog._install()
	dialog.hide()
	if not await until(ready, "fresh-process generated authored World installed"): return
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt", {})
	check(receipt.get("generated_prepared_material_sha256") == expected.prepared_sha256,
		"entire fresh prepared native World matches prior acknowledged material state")
	check(receipt.get("generated_source_sha256") == expected.generation.sha256,
		"native prepared receipt preserves original generator source identity")
	var actual: PackedInt32Array = await capture(AUTHORED_REGION)
	check(PackedByteArray(Array(actual)) == Marshalls.base64_to_raw(expected.native_region),
		"fresh-process native readback preserves every authored region cell")
	check(json_equivalent(bench.applied.actors, expected.actors) and bench.applied.selected == expected.selected
		and not bench.body_state(1).is_empty(), "fresh-process actor placement and selected real flyer preserved")
	check(json_equivalent(bench.applied.liquid_policy, expected.liquid_policy) and bench.applied.response == expected.response
		and bench.applied.rule_radius == expected.rule_radius, "fresh-process solver and response configuration preserved")
	bench._set_view(Vector2(24, 24), Vector2i(240, 135))
	bench._brush.value = 0
	await process_frame
	if not await gesture("Line", Vector2i(120, 140), Vector2i(145, 145), 131): return
	var continued: PackedInt32Array = await capture(Rect2i(120, 140, 1, 1))
	check(continued == PackedInt32Array([131]), "continued native editing after generated-map reopening")
	await screenshot("paint001-generated-reopened")
	completed = true


func run() -> void:
	set_meta("cybersand_feature", "shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	root.size = Vector2i(1440, 1000)
	bench = host.shared_workbench
	editor = bench.paint_editor
	dialog = bench._generated_dialog
	if await until(ready, "ordinary Workbench installed"):
		if OS.get_environment("PAINT_GENERATED_REOPEN") == "1": await reopen()
		else: await author()
	check(completed, "complete generated authoring/reopening workflow actually executed")
	host.queue_free()
	await process_frame
	await process_frame
	print("PAINT_EDITOR_GENERATED_WORKBENCH ", JSON.stringify({"checks": checks, "failures": failures,
		"completed": completed, "reopen": OS.get_environment("PAINT_GENERATED_REOPEN"),
		"elapsed_usec": Time.get_ticks_usec() - started_usec}))
	quit(int(not failures.is_empty()))
