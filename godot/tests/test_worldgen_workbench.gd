extends SceneTree

# Native generation and authoring ownership only. No simulation, Rapier,
# streamed-world persistence, Windows GPU, or browser acceptance is inferred.
const Workbench = preload("res://scripts/worldgen_workbench.gd")
const WorkbenchScene = preload("res://worldgen_workbench.tscn")
var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _init() -> void:
	call_deferred("run")

func small_recipe() -> Dictionary:
	return {"schema": 1, "seed": 917, "chunk_size": 32, "candidate": "strata", "parameters": {"surface_y": 0, "relief": 0, "fluid_level": 64}, "themes": {"weights": {"basalt": 1}, "exclude": []}}

func check_adapter() -> void:
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	expect(not generator.generate_chunk(Vector2i.ZERO).ok, "Unconfigured generator returned cells")
	var recipe: Dictionary = small_recipe()
	var accepted: Dictionary = generator.configure(recipe)
	expect(accepted.ok and int(accepted.revision) > 0, "Native profile did not configure")
	if not accepted.ok:
		return
	expect(str(accepted.fingerprint).length() == 16, "Fingerprint is not a lossless hex identity")
	var catalogue: Dictionary = generator.get_catalogue()
	expect(catalogue.candidates.size() == 3 and catalogue.modules.size() >= 3, "Native candidate/module catalogue missing")
	var oracle: Dictionary = generator.generate_chunk(Vector2i(-2, -1))
	expect(oracle.ok and oracle.cells.size() == 1024, "Signed native chunk request failed")
	var borrowed: Dictionary = generator.get_configuration()
	borrowed.parameters.surface_y = 999
	borrowed.themes.weights.basalt = 0
	expect(generator.get_configuration() == recipe, "Configuration query leaked nested mutation into the accepted recipe")
	var begun: Dictionary = generator.begin_chunk(Vector2i(-2, -1))
	expect(begun.ok, "Incremental chunk did not begin")
	var pending: Dictionary = generator.advance(11)
	expect(pending.ok and pending.state == "running" and pending.completed_cells == 11 and not pending.has("cells"), "Pending job exposed partial cells or ignored its budget")
	var unchanged: Dictionary = generator.advance(0)
	expect(unchanged.completed_cells == 11 and not unchanged.has("cells"), "Zero budget advanced or published a partial chunk")
	expect(not generator.advance(-1).ok, "Negative cell budget was admitted")
	var invalid_profiles: Array[Dictionary] = [
		{"scheam": 1},
		{"schema": 1.5},
		{"seed": 1.25},
		{"seed": -1},
		{"parameters": {"feature_scales": 64}},
		{"overrides": [{"id": "bad-material", "bounds": [0, 0, 4, 4], "material": 10}]},
		{"overrides": [{"id": "bad-material", "bounds": [0, 0, 4, 4], "material": 255}]},
		{"modules": [{"id": "unknown", "module": "not-a-module", "bounds": [0, 0, 64, 64]}]},
	]
	for invalid: Dictionary in invalid_profiles:
		var rejected: Dictionary = generator.configure(invalid)
		expect(not rejected.ok and not str(rejected.error).is_empty(), "Invalid adapter configuration was accepted: " + str(invalid))
		expect(generator.get_configuration() == recipe, "Rejected configuration replaced the accepted recipe")
	var ready: Dictionary = generator.advance(1013)
	expect(ready.ok and ready.state == "ready" and ready.completed_cells == 1024, "Rejected configuration destroyed the earlier pending job")
	expect(ready.hash == oracle.hash and ready.cells == oracle.cells and ready.revision == accepted.revision, "Resumed job does not match its original generation identity")
	ready.cells[0] = 255
	var copied_again: Dictionary = generator.advance(0)
	expect(copied_again.ok and copied_again.cells == oracle.cells, "Ready payload shares mutable bytes with the native retained result")
	expect(generator.begin_chunk(Vector2i(1, 1)).ok, "Second pending job failed")
	expect(generator.advance(7).completed_cells == 7, "Second pending job budget mismatch")
	var again: Dictionary = generator.configure(recipe)
	expect(again.ok and int(again.revision) == int(accepted.revision) + 1 and again.fingerprint != accepted.fingerprint, "Identical reconfigure did not advance its revision-bound plan identity")
	expect(generator.advance(1).state == "idle", "Accepted replacement retained an old generation job")
	var repeated: Dictionary = generator.generate_chunk(Vector2i(-2, -1))
	expect(repeated.cells == oracle.cells and repeated.hash == oracle.hash, "New plan revision changed deterministic cell content")
	var independent_input: Dictionary = recipe.duplicate(true)
	expect(generator.configure(independent_input).ok, "Input ownership fixture failed")
	independent_input.parameters.surface_y = 12345
	expect(generator.get_configuration() == recipe, "Caller mutated the native accepted input after configure")
	var json_recipe: Dictionary = JSON.parse_string(JSON.stringify(recipe))
	expect(generator.configure(json_recipe).ok, "Exactly integral JSON numeric fields were rejected")
	var actual_json: Dictionary = generator.generate_chunk(Vector2i(-2, -1))
	expect(actual_json.cells == oracle.cells and actual_json.hash == oracle.hash, "JSON numeric parsing changed the generated cells")

func drain(app: CyberWorldGenerationWorkbench) -> void:
	var calls: int = 0
	while (app._has_active_chunk or not app.pending_chunks.is_empty()) and calls < 512:
		app.service_generation()
		calls += 1
	expect(calls < 512 and not app._has_active_chunk and app.pending_chunks.is_empty(), "Bounded generation queue failed to drain")
	expect(app.cache.size() <= Workbench.MAX_CACHE_CHUNKS, "Preview cache exceeded its explicit chunk bound")

func material_at(app: CyberWorldGenerationWorkbench, x: int, y: int) -> int:
	var size: int = int(app.active_recipe.get("chunk_size", 128))
	var coordinate := Vector2i(floori(float(x) / size), floori(float(y) / size))
	var packet: Dictionary = app.generator.generate_chunk(coordinate)
	if not bool(packet.get("ok", false)):
		expect(false, "Native cell oracle failed: " + str(packet.get("error", "")))
		return -1
	return int(packet.cells[(y - coordinate.y * size) * size + x - coordinate.x * size])

func check_workbench() -> void:
	expect(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://feature_launcher.tscn", "Workbench must remain opt-in behind the combined desktop launcher")
	root.size = Vector2i(1600, 1000)
	var app: CyberWorldGenerationWorkbench = WorkbenchScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	await process_frame
	expect(app.generator != null and app.active_revision > 0, "Workbench did not configure its private native generator")
	expect(app.parameter_inputs.size() == 12 and app.tool_picker.item_count == 11, "Authoring controls are incomplete")
	if app.generator == null:
		app.queue_free()
		return
	expect(app.apply_recipe(small_recipe()), "Small authoring fixture failed: " + app.last_error)
	app.set_camera_origin(Vector2(-1, -1))
	expect(Vector2i(-1, -1) in app.visible_chunks(), "Negative cells used truncation instead of floor chunk coordinates")
	app.set_camera_origin(app.camera_origin + Vector2(0.25, 0.25))
	expect(app.camera_origin.is_equal_approx(Vector2(-0.75, -0.75)), "Subcell panning was rounded asymmetrically instead of accumulating motion")
	expect(app.pending_chunks.size() <= Workbench.MAX_QUEUED_CHUNKS, "Pan request queue exceeded its bound")
	drain(app)
	for coordinate: Vector2i in app.visible_chunks():
		expect(app.cache.has(coordinate), "Visible chunk missing after bounded generation")
	var packet: Dictionary = app.last_packet.duplicate(true)
	var revision: int = app.active_revision
	var retained_count: int = app.cache.size()
	var prior_cells: PackedByteArray = app.cache[Vector2i(packet.chunk_x, packet.chunk_y)].cells.duplicate()
	var stale: Dictionary = packet.duplicate(true)
	stale.revision = revision - 1
	expect(not app.accept_chunk(stale) and app.cache.size() == retained_count, "Stale chunk entered the current preview")
	var actual_coordinate := Vector2i(packet.chunk_x, packet.chunk_y)
	expect(not app.accept_chunk(packet, actual_coordinate + Vector2i.ONE), "Completion for a different request entered the preview slot")
	var missing_coordinate: Dictionary = packet.duplicate(true)
	missing_coordinate.erase("chunk_x")
	expect(not app.accept_chunk(missing_coordinate), "Missing chunk coordinates silently aliased chunk zero")
	missing_coordinate = packet.duplicate(true)
	missing_coordinate.chunk_y = str(missing_coordinate.chunk_y)
	expect(not app.accept_chunk(missing_coordinate), "Non-integer chunk coordinate metadata was coerced into the cache")
	var invalid: Dictionary = packet.duplicate(true)
	invalid.cells = PackedByteArray([1])
	expect(not app.accept_chunk(invalid), "Malformed chunk byte extent entered the preview")
	invalid = packet.duplicate(true)
	invalid.cells[0] = 10
	expect(not app.accept_chunk(invalid), "Reserved material entered the preview")
	expect(app.cache[Vector2i(packet.chunk_x, packet.chunk_y)].cells == prior_cells, "Rejected packet altered the earlier preview")
	app.profile_editor.text = '{"parameters":{"feature_scales":64}}'
	app.apply_json()
	expect(app.active_revision == revision and app.cache.size() == retained_count and not app.last_error.is_empty(), "Rejected JSON changed the accepted revision/cache")
	expect(app.apply_recipe(small_recipe()), "Rejected preview could not accept a fresh profile")
	app.service_generation()
	var first_packet: Dictionary = app.last_packet.duplicate(true)
	if not first_packet.is_empty():
		var coordinate := Vector2i(first_packet.chunk_x, first_packet.chunk_y)
		expect(app.accept_chunk(first_packet), "Valid native packet rejected")
		first_packet.cells[0] = 255
		expect(app.cache[coordinate].cells[0] != 255, "Preview cache borrowed caller-mutable cell bytes")
	var profile: Dictionary = small_recipe()
	profile.seed = 4294967297
	profile.themes = {"weights": {"basalt": 2.0, "industrial": 0.4, "garden": 0.2}, "exclude": []}
	expect(app.apply_recipe(profile), "Advanced recipe fixture failed")
	app.parameter_inputs.relief.value = 19
	app.apply_controls()
	expect(app.active_recipe.seed == profile.seed and app.active_recipe.themes == profile.themes, "Changing one fine control silently rewrote advanced theme weights or seed")
	expect(app.active_recipe.parameters.relief == 19, "Fine numeric control did not reach native configuration")
	# Scene-space input mapping retains world coordinates and excludes letterbox.
	var view: CyberWorldGenerationPreview = app.preview
	var content: Rect2 = view.content_rect()
	var center: Vector2 = content.position + content.size * 0.5
	expect(view.screen_to_world(center).is_equal_approx(app.camera_origin + app.view_size * 0.5), "Preview pointer mapping differs from the displayed world rectangle")
	var world_point := Vector2(-12.25, 34.5)
	expect(view.screen_to_world(view.world_to_screen(world_point)).is_equal_approx(world_point), "Preview coordinate mapping does not round-trip")
	# A single authored rectangle must retain exact material across chunk seams.
	expect(app.apply_recipe(small_recipe()), "Hard override fixture failed")
	app.tool_picker.select(3)
	app.material_picker.select(app.material_picker.get_item_index(62))
	app.add_gesture(PackedVector2Array([Vector2(-5, 30), Vector2(5, 34)]))
	expect(app.active_recipe.overrides.size() == 1 and app.active_recipe.overrides[0].bounds == [-5, 30, 11, 5], "Hard override pointer bounds were not exact inclusive cells")
	for point: Vector2i in [Vector2i(-1, 31), Vector2i(0, 31), Vector2i(-1, 32), Vector2i(0, 32)]:
		expect(material_at(app, point.x, point.y) == 62, "Hard override lost authority at a chunk edge")
	app.tool_picker.select(0)
	app.add_gesture(PackedVector2Array([Vector2(20, 20), Vector2(90, 30)]))
	expect(app.active_recipe.strokes.size() == 1 and not app.active_recipe.strokes[0].themes.weights.is_empty(), "Theme brush did not preserve its world-coordinate guide")
	app.tool_picker.select(2)
	app.radius_input.value = 4
	app.material_picker.select(app.material_picker.get_item_index(0))
	app.add_gesture(PackedVector2Array([Vector2(20, 50), Vector2(90, 50)]))
	for x: int in [31, 32, 63, 64]:
		expect(material_at(app, x, 50) == 0, "Authored carved route is interrupted at a chunk seam")
	# Module UI snaps a vault rectangle to its prepared maze grid.
	Workbench._select_text(app.module_picker, "vault")
	app._refresh_module_editor()
	app.tool_picker.select(4)
	app.add_gesture(PackedVector2Array([Vector2(64, 128), Vector2(116, 172)]))
	expect(app.active_recipe.modules.size() == 1 and app.active_recipe.modules[0].bounds == [64, 128, 64, 64], "Vault authoring did not create a valid grid-aligned module extent")
	var with_module: Dictionary = app.active_recipe.duplicate(true)
	app.undo_authoring()
	expect(app.active_recipe.get("modules", []).is_empty() and app.active_recipe.paths.size() == 1, "Undo did not restore the previous accepted authoring profile")
	expect(app.apply_recipe(with_module), "Module profile could not be restored")
	app.clear_authoring()
	expect(app.active_recipe.strokes.is_empty() and app.active_recipe.paths.is_empty() and app.active_recipe.overrides.is_empty() and app.active_recipe.modules.is_empty(), "Clear authoring retained generated marks")
	# Demand generation visits fresh areas without accumulating an unbounded map.
	for index: int in range(6):
		app.set_camera_origin(Vector2(index * 1024 - 128, 64))
		expect(app.pending_chunks.size() <= Workbench.MAX_QUEUED_CHUNKS, "Distant pan accumulated old requests")
		drain(app)
	expect(app.cache.size() == Workbench.MAX_CACHE_CHUNKS, "Cache did not exercise its eviction bound")
	# GEN-007 preflights exhausted work before accepting any replacement.
	var limited: Dictionary = small_recipe()
	limited.limits = {"max_operations_per_chunk": 1}
	var retained_recipe: Dictionary = app.active_recipe.duplicate(true)
	var retained_revision: int = app.active_revision
	var retained_cache: Dictionary = app.cache.duplicate(true)
	var retained_history: int = app._undo.size()
	expect(not app.apply_recipe(limited), "Exhausted-work candidate was committed")
	expect(app.active_recipe == retained_recipe and app.active_revision == retained_revision and app.cache == retained_cache and app._undo.size() == retained_history, "Budget rejection replaced valid recipe, preview or history")
	for index: int in range(4):
		app.set_camera_origin(Vector2(index * 1024, 64))
		drain(app)
		expect(not app.cache.is_empty() and app._blocked_chunks.size() <= Workbench.MAX_QUEUED_CHUNKS, "Valid predecessor could not continue after budget rejection")
	expect(app.apply_recipe(small_recipe()), "Failed generation could not recover by accepted replacement")
	# Profile save/load round-trips accepted input, not edited invalid JSON.
	var saved_recipe: Dictionary = app.active_recipe.duplicate(true)
	var saved_cells: Dictionary = app.generator.generate_chunk(Vector2i(0, 2))
	app.profile_editor.text = '{"broken":true}'
	var save_path: String = "user://worldgen-workbench-test-profile.json"
	expect(app.save_profile(save_path), "Accepted profile could not be saved")
	expect(app.load_profile(save_path), "Saved profile could not be loaded")
	expect(JSON.parse_string(app.profile_editor.text) == JSON.parse_string(JSON.stringify(saved_recipe)), "Save exported unaccepted editor text")
	app.apply_json()
	expect(JSON.parse_string(JSON.stringify(app.active_recipe)) == JSON.parse_string(JSON.stringify(saved_recipe)), "Saved profile fields failed their JSON round-trip")
	var restored_cells: Dictionary = app.generator.generate_chunk(Vector2i(0, 2))
	expect(restored_cells.cells == saved_cells.cells and restored_cells.hash == saved_cells.hash, "Saved profile changed native cell output after its JSON round-trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	# The adapter allows {} as defaults; the UI must not mistake it for unconfigured.
	expect(app.apply_recipe({}), "Empty default profile was rejected")
	expect(not app.pending_chunks.is_empty(), "Accepted default profile was treated as an absent generator")
	app.queue_free()
	await process_frame

func run() -> void:
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		push_error("Source-matched CyberWorldGenerator GDExtension is required; missing/stale runtime is not acceptance")
		quit(1)
		return
	check_adapter()
	await check_workbench()
	print("WORLDGEN_WORKBENCH: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
