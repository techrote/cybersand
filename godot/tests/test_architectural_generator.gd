extends SceneTree

# Source-matched GEN-007 A+B qualification. The runner invokes native,
# author and reopen in distinct processes with a shared isolated user profile.
const Project = preload("res://scripts/architectural_generator_project.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
const Palette = preload("res://scripts/material_appearance_lut.gd")
const SAVE_NAME := "architecture-ab-qualification"
var checks := 0
var failures := 0
var complete := false
var report: Dictionary = {"schema": 1, "cases": []}
var host: Control
var wb: Control
var dialog: ConfirmationDialog
var preview_clock: PreviewClock

class PreviewClock extends Node:
	# Observe the real dialog after its normal process turn, without accelerating
	# generation. The first draw callback runs before any screenshot encoding.
	var dialog: ConfirmationDialog
	var sample: Dictionary = {}

	func _ready() -> void:
		process_priority = 1000
		if DisplayServer.get_name() != "headless":
			RenderingServer.frame_post_draw.connect(_frame_drawn)

	func begin() -> void:
		sample = {"request_started_us": Time.get_ticks_usec(), "ready_us": 0, "first_frame_drawn_us": null}

	func _process(_delta: float) -> void:
		if not sample.is_empty() and int(sample.ready_us) == 0 and dialog._phase == "ready":
			sample.ready_us = Time.get_ticks_usec()

	func _frame_drawn() -> void:
		if not sample.is_empty() and sample.first_frame_drawn_us == null and int(sample.ready_us) > 0:
			sample.first_frame_drawn_us = Time.get_ticks_usec()

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	run.call_deferred()

func check(ok: bool, detail: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("ARCHITECTURE: " + detail + (" / " + wb.message if wb != null else ""))
	return ok

func output_dir() -> String:
	var path := OS.get_environment("CYBERSAND_ARCHITECTURE_OUTPUT")
	if path.is_empty(): path = ProjectSettings.globalize_path("user://architecture-qualification")
	DirAccess.make_dir_recursive_absolute(path)
	return path

func write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(output_dir().path_join(name), FileAccess.WRITE)
	if check(file != null, "write evidence " + name):
		file.store_string(JSON.stringify(value, "\t", true, true) + "\n")

func preview(name: String, cells: PackedByteArray, extent: Vector2i) -> int:
	var began := Time.get_ticks_usec()
	var pixels := PackedByteArray()
	pixels.resize(cells.size() * 4)
	for i: int in cells.size():
		var rgba: int = int(Palette.BASE_RGBA8[int(cells[i])])
		pixels[i * 4] = (rgba >> 24) & 255
		pixels[i * 4 + 1] = (rgba >> 16) & 255
		pixels[i * 4 + 2] = (rgba >> 8) & 255
		pixels[i * 4 + 3] = 255
	var image := Image.create_from_data(extent.x, extent.y, false, Image.FORMAT_RGBA8, pixels)
	check(image.save_png(output_dir().path_join(name + ".png")) == OK, "native material preview " + name)
	return Time.get_ticks_usec() - began

func components(zones: Dictionary, slot: int) -> int:
	var visited: Dictionary = {}
	var count := 0
	var width: int = zones.width
	var height: int = zones.height
	for i: int in zones.cells.size():
		if int(zones.cells[i]) != slot or visited.has(i): continue
		count += 1
		var queue: Array[int] = [i]
		visited[i] = true
		var at := 0
		while at < queue.size():
			var cell: int = queue[at]
			at += 1
			var x: int = cell % width
			var y: int = cell / width
			for p: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if p.x < 0 or p.y < 0 or p.x >= width or p.y >= height: continue
				var next: int = p.y * width + p.x
				if int(zones.cells[next]) == slot and not visited.has(next):
					visited[next] = true
					queue.append(next)
	return count

func generation(recipe: Dictionary, bounds: Rect2i, reverse: bool = false, sliced: bool = false) -> Dictionary:
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var began := Time.get_ticks_usec()
	var accepted: Dictionary = generator.configure(recipe)
	var prepare_us := Time.get_ticks_usec() - began
	if not check(accepted.get("ok", false), "native recipe accepted: " + str(accepted.get("error", ""))): return {}
	var side: int = int(recipe.get("chunk_size", 64))
	var coords: Array[Vector2i] = []
	var first := Vector2i(floori(float(bounds.position.x) / side), floori(float(bounds.position.y) / side))
	var last := Vector2i(floori(float(bounds.end.x - 1) / side), floori(float(bounds.end.y - 1) / side))
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1): coords.append(Vector2i(x, y))
	if reverse: coords.reverse()
	var cells := PackedByteArray()
	cells.resize(bounds.size.x * bounds.size.y)
	var receipts: Dictionary = {}
	var operations: int = 0
	var native_us: int = 0
	began = Time.get_ticks_usec()
	for coordinate: Vector2i in coords:
		var packet: Dictionary
		var native_began := Time.get_ticks_usec()
		if sliced:
			packet = generator.begin_chunk(coordinate)
			var turns := 0
			while packet.get("ok", false) and packet.get("state", "") != "ready" and turns < side * side / 137 + 2:
				packet = generator.advance(137)
				turns += 1
		else: packet = generator.generate_chunk(coordinate)
		native_us += Time.get_ticks_usec() - native_began
		if not check(packet.get("ok", false) and packet.get("state", "") == "ready", "complete native chunk " + str(coordinate) + ": " + str(packet.get("error", ""))): return {}
		operations += int(packet.get("operations", 0))
		receipts[str(coordinate)] = packet.receipt_hash
		for y: int in side:
			var gy: int = coordinate.y * side + y
			if gy < bounds.position.y or gy >= bounds.end.y: continue
			for x: int in side:
				var gx: int = coordinate.x * side + x
				if gx >= bounds.position.x and gx < bounds.end.x:
					cells[(gy - bounds.position.y) * bounds.size.x + gx - bounds.position.x] = packet.cells[y * side + x]
	var elapsed := Time.get_ticks_usec() - began
	return {"cells": cells, "material_sha256": Store.digest(cells), "recipe_sha256": Store.recipe_hash(recipe),
		"fingerprint": accepted.fingerprint, "receipts": receipts, "preparation_us": prepare_us,
		"raster_and_copy_us": elapsed, "native_raster_us": native_us, "material_copy_us": elapsed - native_us,
		"logical_operations": operations, "native_chunks": coords.size(),
		"material_bytes": cells.size(), "preview_rgba_bytes": cells.size() * 4}

func changed_cells(a: PackedByteArray, b: PackedByteArray, occupancy_only: bool = false) -> int:
	var count := 0
	if not check(a.size() == b.size(), "comparable material extents"): return 0
	for i: int in a.size():
		var different: bool = ((a[i] == 0) != (b[i] == 0)) if occupancy_only else a[i] != b[i]
		if different: count += 1
	return count

func small_project() -> Dictionary:
	var project: Dictionary = Project.default_project()
	project.extent = [512, 512]
	return project

func zone_occupancy(cells: PackedByteArray, extent: Vector2i, zones: Dictionary) -> Array:
	var counts: Dictionary = {}
	var scale: int = int(zones.cell_size)
	var width: int = int(zones.width)
	for slot: int in zones.cells:
		if not counts.has(slot): counts[slot] = {"slot": slot, "zone_cells": 0, "occupied_cells": 0}
		counts[slot].zone_cells += scale * scale
	for y: int in extent.y:
		for x: int in extent.x:
			if cells[y * extent.x + x] == 0: continue
			var slot: int = zones.cells[(y / scale) * width + x / scale]
			counts[slot].occupied_cells += 1
	var result: Array = []
	for slot: int in counts:
		result.append(counts[slot])
	return result

func has_macro_route(trace: Dictionary) -> bool:
	for contribution: Dictionary in trace.get("contributions", []):
		if contribution.get("stage", "") == "candidate_route" and contribution.get("id", "") == "macro-network":
			return true
	return false

func cross_zone_routes(compiled: Dictionary, cells: PackedByteArray) -> void:
	var enabled: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var disabled: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var off_recipe: Dictionary = compiled.recipe.duplicate(true)
	off_recipe.architecture.automatic_tunnels = false
	if not check(enabled.configure(compiled.recipe).get("ok", false) and disabled.configure(off_recipe).get("ok", false),
		"cross-zone route receipt owners configured"): return
	var zones: Dictionary = compiled.zones
	var side: int = int(zones.cell_size)
	var width: int = int(zones.width)
	var height: int = int(zones.height)
	var extent := Vector2i(width * side, height * side)
	var origin := Vector2i(int(zones.origin[0]), int(zones.origin[1]))
	var boundary_pairs := 0
	var crossings := 0
	var invalid_traces := 0
	var blocked_cells := 0
	var disabled_route_receipts := 0
	var style_pairs: Dictionary = {}
	for y: int in height:
		for x: int in width:
			var slot: int = int(zones.cells[y * width + x])
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other := Vector2i(x, y) + direction
				if other.x >= width or other.y >= height: continue
				var other_slot: int = int(zones.cells[other.y * width + other.x])
				if slot == other_slot: continue
				for offset: int in side:
					var local := Vector2i((x + 1) * side - 1, y * side + offset) if direction == Vector2i.RIGHT else Vector2i(x * side + offset, (y + 1) * side - 1)
					var adjacent := local + direction
					boundary_pairs += 1
					var first: Dictionary = enabled.inspect_cell(origin + local)
					var second: Dictionary = enabled.inspect_cell(origin + adjacent)
					if not first.get("ok", false) or not second.get("ok", false):
						invalid_traces += 1
						continue
					if not has_macro_route(first) or not has_macro_route(second): continue
					crossings += 1
					style_pairs[str(mini(slot, other_slot)) + "/" + str(maxi(slot, other_slot))] = true
					for point: Vector2i in [local, adjacent]:
						if cells[point.y * extent.x + point.x] != 0: blocked_cells += 1
						var off_trace: Dictionary = disabled.inspect_cell(origin + point)
						if not off_trace.get("ok", false): invalid_traces += 1
						for contribution: Dictionary in off_trace.get("contributions", []):
							if contribution.get("stage", "") == "candidate_route": disabled_route_receipts += 1
	check(invalid_traces == 0, "cross-style inspection receipts are complete")
	check(crossings > 0, "automatic macro-network routes cross actual style-zone boundaries")
	check(blocked_cells == 0, "both native raster cells of every cross-style macro-route pair are Empty")
	check(disabled_route_receipts == 0, "tunnel-off removes automatic candidate-route receipts at those same boundary crossings")
	report.cases.append({"case": "automatic-routes-cross-style-boundaries", "seed": compiled.project.seed,
		"extent": [extent.x, extent.y], "boundary_cell_pairs": boundary_pairs, "route_crossings": crossings,
		"style_pairs": style_pairs.keys(), "blocked_raster_cells": blocked_cells,
		"disabled_route_receipts": disabled_route_receipts, "invalid_traces": invalid_traces})

func compiler_contracts() -> void:
	var input: Dictionary = Project.default_project()
	var saved_input: Dictionary = input.duplicate(true)
	var compiled: Dictionary = Project.compile(input)
	if not check(compiled.get("ok", false), "default project compiles: " + str(compiled.get("error", ""))): return
	check(input == saved_input, "compilation does not mutate caller project")
	check(compiled.recipe.schema == 4, "new recipe uses explicit schema4")
	check(not compiled.recipe.has("semantic_planes"), "architectural prototype preserves ordinary native chunk recipe path")
	var restored: Dictionary = Project.compile(JSON.parse_string(JSON.stringify(input, "", true, true)))
	check(restored.get("ok", false) and restored.recipe == compiled.recipe and restored.project_hash == compiled.project_hash,
		"canonical JSON roundtrip preserves compiler identity and recipe")
	for item: Dictionary in compiled.coverage:
		var blocks := 0
		for slot: int in compiled.zones.cells:
			if slot == int(item.slot): blocks += 1
		var achieved: float = 100.0 * blocks / compiled.zones.cells.size()
		check(absf(achieved - float(item.requested_percent)) <= 2.0, "measured quota within two percentage points for " + str(item.id))
		check(is_equal_approx(achieved, float(item.achieved_percent)) and blocks == int(item.blocks), "coverage diagnostic matches independently counted zone blocks")
		check(components(compiled.zones, int(item.slot)) == 1, "one actual four-connected component for " + str(item.id))
	var custom: Dictionary = input.styles[0].preset.duplicate(true)
	custom.id = "owner-workshop"
	custom.name = "Owner Workshop"
	custom.geometry.room_size = 64
	var imported: Dictionary = Project.import_preset(input, JSON.parse_string(JSON.stringify(custom)), 0)
	check(imported.get("ok", false), "validated user JSON style import")
	if imported.get("ok", false):
		check(str(imported.project.styles[0].preset.id) == "owner-workshop", "custom stable identity retained")
		check(imported.recipe != compiled.recipe, "user geometry changes native compiled recipe")
		var independent: Dictionary = Project.compile(JSON.parse_string(JSON.stringify(imported.project)))
		check(independent.get("ok", false) and independent.recipe == imported.recipe, "custom preset is embedded and has no external reload dependency")
	for mutation: Array in [["zone_scale", 63], ["zone_scale", 1024], ["extent", [768, 1024]], ["seed", -1], ["automatic_doors", "false"]]:
		var invalid: Dictionary = input.duplicate(true)
		invalid[mutation[0]] = mutation[1]
		var refused: Dictionary = Project.compile(invalid)
		check(not refused.get("ok", false) and not str(refused.get("error", "")).is_empty(), "invalid project explicitly refused: " + str(mutation))
	var invalid: Dictionary = input.duplicate(true)
	invalid.styles[0].preset.geometry.wall_thickness = 100
	check(not Project.compile(invalid).get("ok", false), "impossible aperture and wall geometry refused")
	invalid = input.duplicate(true)
	invalid.styles[0].preset.module_version = 1
	check(not Project.compile(invalid).get("ok", false), "unsupported preset module version refused")
	invalid = input.duplicate(true)
	for style: Dictionary in invalid.styles: style.enabled = false
	check(not Project.compile(invalid).get("ok", false), "empty style selection refused")
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var accepted: Dictionary = generator.configure(compiled.recipe)
	check(accepted.get("ok", false), "native compiler accepts project recipe")
	if accepted.get("ok", false):
		var budget: Dictionary = compiled.recipe.duplicate(true)
		budget.limits = {"max_operations_per_chunk": 1}
		var configured: Dictionary = generator.configure(budget)
		var refused: bool = not configured.get("ok", false)
		if not refused: refused = not generator.generate_chunk(Vector2i.ZERO).get("ok", false)
		check(refused, "native exhausted generation work budget explicitly refuses")
	write_json("project-default.json", input)
	write_json("project-custom.json", imported.get("project", {}))

func native_contracts() -> void:
	compiler_contracts()
	var hashes: Dictionary = {}
	for seed: int in [161803, 271828, 314159]:
		var project: Dictionary = Project.default_project()
		project.seed = seed
		var compiled: Dictionary = Project.compile(project)
		if not check(compiled.get("ok", false), "seeded project accepted"): return
		var data := generation(compiled.recipe, Rect2i(0, 0, 1024, 1024))
		if data.is_empty(): return
		if seed == 161803: cross_zone_routes(compiled, data.cells)
		check(not hashes.has(data.material_sha256), "three seeds produce distinct material layouts")
		hashes[data.material_sha256] = true
		var preview_us: int = preview("three-style-seed-" + str(seed), data.cells, Vector2i(1024, 1024))
		var metrics: Dictionary = data.duplicate(true)
		metrics.erase("cells")
		metrics.erase("receipts")
		metrics.merge({"case": "three-style", "seed": seed, "extent": [1024, 1024], "planner_us": compiled.planner_us,
			"coverage": compiled.coverage, "project_sha256": compiled.project_hash, "preview_colour_and_png_us": preview_us,
			"zone_material_occupancy": zone_occupancy(data.cells, Vector2i(1024, 1024), compiled.zones)})
		report.cases.append(metrics)
		var intact: Dictionary = project.duplicate(true)
		intact.styles[2].preset.deterioration = 0.0
		var intact_compiled: Dictionary = Project.compile(intact)
		if check(intact_compiled.get("ok", false), "damage-off comparison compiles"):
			var intact_data := generation(intact_compiled.recipe, Rect2i(0, 0, 1024, 1024))
			if not intact_data.is_empty():
				var intact_counts := zone_occupancy(intact_data.cells, Vector2i(1024, 1024), compiled.zones)
				report.cases.append({"case": "ruin-deterioration", "seed": seed,
					"deterioration": project.styles[2].preset.deterioration,
					"before": intact_counts, "after": metrics.zone_material_occupancy})
				preview("ruins-before-deterioration-seed-" + str(seed), intact_data.cells, Vector2i(1024, 1024))
		for coverage: Dictionary in compiled.coverage:
			check(components(compiled.zones, int(coverage.slot)) == 1, "each seeded zone remains connected")
		write_json("zones-" + str(seed) + ".json", compiled.zones)
		write_json("resolved-recipe-" + str(seed) + ".json", compiled.recipe)
	var project := small_project()
	var compiled: Dictionary = Project.compile(project)
	if not check(compiled.get("ok", false), "512 project accepted"): return
	var original := generation(compiled.recipe, Rect2i(0, 0, 512, 512))
	if original.is_empty(): return
	var small_preview_us: int = preview("controls-all-on", original.cells, Vector2i(512, 512))
	var reversed := generation(compiled.recipe, Rect2i(0, 0, 512, 512), true)
	check(not reversed.is_empty() and reversed.cells == original.cells and reversed.receipts == original.receipts,
		"reverse chunk request order preserves exact native materials and receipts")
	var sliced := generation(compiled.recipe, Rect2i(-64, -64, 128, 128), true, true)
	var ordinary := generation(compiled.recipe, Rect2i(-64, -64, 128, 128))
	check(not sliced.is_empty() and sliced.cells == ordinary.cells and sliced.receipts == ordinary.receipts,
		"work slicing and signed boundary requests preserve exact results")
	for toggle: String in ["automatic_tunnels", "automatic_doors", "automatic_windows"]:
		var off: Dictionary = project.duplicate(true)
		off[toggle] = false
		var off_compiled: Dictionary = Project.compile(off)
		if not check(off_compiled.get("ok", false), toggle + " off compiles"): continue
		var data := generation(off_compiled.recipe, Rect2i(0, 0, 512, 512))
		if data.is_empty(): continue
		var changed := changed_cells(original.cells, data.cells)
		check(changed > 0, toggle + " produces actual material differences")
		preview(toggle + "-off", data.cells, Vector2i(512, 512))
		report.cases.append({"case": toggle, "changed_cells": changed, "on_sha256": original.material_sha256,
			"off_sha256": data.material_sha256, "off_recipe_sha256": data.recipe_sha256})
	var negative: Dictionary = project.duplicate(true)
	negative.origin = [-257, -193]
	var negative_compiled: Dictionary = Project.compile(negative)
	if check(negative_compiled.get("ok", false), "unaligned negative global origin accepted"):
		var a := generation(negative_compiled.recipe, Rect2i(-257, -193, 512, 512))
		var b := generation(negative_compiled.recipe, Rect2i(-257, -193, 512, 512), true)
		check(not a.is_empty() and a.cells == b.cells and a.receipts == b.receipts, "negative origin stable across request order")
	var shapes: Array[PackedByteArray] = []
	for slot: int in [0, 1]:
		var single: Dictionary = project.duplicate(true)
		single.automatic_tunnels = false
		single.automatic_doors = false
		single.automatic_windows = false
		for i: int in single.styles.size():
			single.styles[i].enabled = i == slot
			single.styles[i].share = 100.0 if i == slot else 0.0
		var one: Dictionary = Project.compile(single)
		if not check(one.get("ok", false), "single style geometry control accepted"): continue
		var data := generation(one.recipe, Rect2i(0, 0, 512, 512))
		if not data.is_empty(): shapes.append(data.cells)
	if check(shapes.size() == 2, "two geometry control samples completed"):
		var count := changed_cells(shapes[0], shapes[1], true)
		check(count > 1024, "Industrial and Habitation differ in occupied/empty geometry, independently of colour")
		report.cases.append({"case": "structural-style-difference", "occupied_empty_difference_cells": count})
	var metrics: Dictionary = original.duplicate(true)
	metrics.erase("cells")
	metrics.erase("receipts")
	metrics.merge({"case": "three-style", "seed": project.seed, "extent": [512, 512], "planner_us": compiled.planner_us,
		"coverage": compiled.coverage, "project_sha256": compiled.project_hash, "preview_colour_and_png_us": small_preview_us})
	report.cases.append(metrics)
	var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://../examples/worldgen/district-arcology.json"))
	if check(legacy is Dictionary, "legacy performance comparison recipe available"):
		for side: int in [512, 1024]:
			var baseline := generation(legacy, Rect2i(0, 0, side, side))
			if not baseline.is_empty():
				baseline.erase("cells")
				baseline.erase("receipts")
				baseline.merge({"case": "legacy-district-arcology-comparison", "seed": legacy.seed, "extent": [side, side],
					"scope": "same requested region size; different recipe and architectural complexity"})
				report.cases.append(baseline)
	complete = true

func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 300000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		if host.simulation_worker.has_failed(): break
		await process_frame
	return check(predicate.call(), label + (" / " + dialog._status.text if dialog != null else ""))

func installed() -> bool:
	return not wb.applied.is_empty() and not wb.busy() and host.pending_microscenario_apply.is_empty()

func paint_completed() -> bool:
	if not installed(): return false
	var state: Dictionary = host.simulation_worker.paint_state()
	for key: String in ["busy", "art_busy", "legacy_busy", "transition_busy"]:
		if bool(state.get(key, false)): return false
	return true

func framebuffer(label: String, popup: Window = null) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var viewport: Viewport = popup if popup != null and not popup.is_embedded() else root
	check(viewport.get_texture().get_image().save_png(output_dir().path_join(label + ".png")) == OK, "original framebuffer " + label)

func preview_ready(label: String) -> bool:
	if not await until(func() -> bool: return dialog._phase == "ready" or dialog._status.text.begins_with("Refused"), label + " finishes"): return false
	if not check(dialog._phase == "ready", label + " accepted"): return false
	await framebuffer(label, dialog)
	var timing: Dictionary = preview_clock.sample.duplicate(true)
	preview_clock.sample.clear()
	if not check(int(timing.ready_us) >= int(timing.request_started_us), "normal process turn records preview readiness"): return false
	var graphical: bool = DisplayServer.get_name() != "headless"
	if not check((timing.first_frame_drawn_us != null) == graphical, "first drawn frame is recorded only on a real display"): return false
	if graphical:
		check(int(timing.first_frame_drawn_us) >= int(timing.ready_us), "first complete preview draw follows ready state")
	var packet: Dictionary = dialog._ready_packet
	timing.merge({"case": "ui-preview-latency", "label": label, "extent": [packet.extent.x, packet.extent.y],
		"seed": packet.recipe.seed, "recipe_sha256": packet.recipe_sha256, "material_sha256": packet.sha256,
		"request_to_ready_us": int(timing.ready_us) - int(timing.request_started_us),
		"request_to_first_drawn_frame_us": int(timing.first_frame_drawn_us) - int(timing.request_started_us) if graphical else null,
		"native_configure_to_ready_us": int(timing.ready_us) - int(dialog._start_usec),
		"display": DisplayServer.get_name(), "status": dialog._status.text,
		"scope": "Real Shared Workbench with normal process-frame scheduling; request includes project compilation; first drawn frame is RenderingServer completion, excluding PNG encoding and OS presentation."})
	report.cases.append(timing)
	return true

func architectural_form_views(project: Dictionary) -> bool:
	var former_size: Vector2i = root.size
	var former_scale: Vector2i = root.content_scale_size
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	dialog._architecture_button.pressed.emit()
	var panel: ConfirmationDialog = dialog._architecture
	if not check(panel.set_project(project), "focused panel accepts owner controls"): return false
	for frame: int in 4: await process_frame
	var bounds := Rect2i(Vector2i.ZERO, root.size) if panel.is_embedded() else DisplayServer.screen_get_usable_rect(root.current_screen)
	check(bounds.encloses(Rect2i(panel.position, panel.size)), "configured Architectural form fits 1280x720 viewport or native work area")
	for button: Button in [panel.get_ok_button(), panel.get_cancel_button()]:
		check(button.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(panel.size)).encloses(button.get_global_rect()), "configured form action stays visible: " + button.text)
	await framebuffer("architecture-form-overview", panel)
	var scroll: ScrollContainer = panel.get_child(0)
	for slot: int in 3:
		panel._style_tabs.current_tab = slot
		for frame: int in 2: await process_frame
		scroll.ensure_control_visible(panel._style_tabs)
		await process_frame
		await framebuffer("architecture-form-style-%d" % (slot + 1), panel)
		report.cases.append({"case": "architectural-form-view", "slot": slot,
			"preset_id": project.styles[slot].preset.id, "root_size": [root.size.x, root.size.y],
			"embedded": panel.is_embedded(), "display": DisplayServer.get_name(),
			"capture": "architecture-form-style-%d.png" % (slot + 1) if DisplayServer.get_name() != "headless" else null})
	scroll.scroll_vertical = 10000
	await process_frame
	await framebuffer("architecture-form-files-and-actions", panel)
	panel._style_tabs.current_tab = 0
	scroll.scroll_vertical = 0
	root.content_scale_size = former_scale
	root.size = former_size
	for frame: int in 2: await process_frame
	return true

func authoring(reopening: bool) -> void:
	if OS.get_environment("CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS") == "1":
		if not check(DisplayServer.get_name() != "headless", "requested graphical acceptance has an actual display"): return
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
	if not await until(installed, "ordinary Shared Workbench native World ready"): return
	var saved := {}
	if reopening:
		saved = Store.read_named(SAVE_NAME)
		if not check(saved.get("generated", false), "fresh process reads generated-start v1"): return
		wb._name.text = SAVE_NAME
		preview_clock.begin()
		if not check(wb.load_setup(), "ordinary Load start reconstructs embedded recipe"): return
	else:
		dialog.open_new()
		var project: Dictionary = Project.default_project()
		project.automatic_tunnels = false
		project.automatic_windows = false
		if not await architectural_form_views(project): return
		var small: Dictionary = project.duplicate(true)
		small.extent = [512, 512]
		if not check(dialog._architecture.set_project(small), "512 preview prelude accepts same styles and controls"): return
		var prelude_epoch: int = host._physical_epoch
		preview_clock.begin()
		dialog._architecture._apply()
		if not await preview_ready("architecture-preview-512"): return
		check(dialog._ready_packet.cells.size() == 512 * 512 and host._physical_epoch == prelude_epoch, "512 preview is complete without replacing installed World")
		dialog._architecture_button.pressed.emit()
		if not check(dialog._architecture.set_project(project), "restore owner 1024 configuration after measured prelude"): return
		preview_clock.begin()
		dialog._architecture._apply()
	if not await preview_ready("architecture-preview-reopened" if reopening else "architecture-preview-new"): return
	var packet: Dictionary = dialog._ready_packet.duplicate(true)
	var chunk_side: int = int(packet.recipe.chunk_size)
	check(packet.cells.size() == 1024 * 1024 and packet.receipt_hashes.size() == (1024 / chunk_side) * (1024 / chunk_side), "complete 1024-square native map and receipts")
	if not reopening:
		var material_texture: Texture2D = dialog._preview.texture
		dialog._zone_toggle.button_pressed = true
		check(dialog._zone_overlay.visible and dialog._zone_overlay.texture != null, "optional zone overlay is visible over complete native material preview")
		await framebuffer("architecture-preview-overlay-on", dialog)
		dialog._zone_toggle.button_pressed = false
		await framebuffer("architecture-preview-overlay-off", dialog)
		check(not dialog._zone_overlay.visible and dialog._preview.texture == material_texture and dialog.attests(packet), "overlay toggling preserves authoritative native texture, materials and provenance")
		var old_epoch: int = host._physical_epoch
		var next_project: Dictionary = dialog._architecture_project.duplicate(true)
		next_project.seed = 271828
		next_project.styles[0].share = 50.0
		next_project.styles[1].share = 25.0
		next_project.styles[1].preset.geometry.floor_height = 64
		check(dialog.start_architectural(next_project), "start edited seed, ratios and floor height")
		dialog._process(0.0)
		dialog._cancel_preview()
		check(host._physical_epoch == old_epoch, "cancelled proposal does not replace existing native World")
		check(not dialog.attests(packet), "cancelled or superseded work cannot attest prior material bytes")
		check(dialog.restore_previous_preview() and dialog.attests(packet), "previous accepted preview and settings are recoverable before installation")
		var previous_sha: String = packet.sha256
		preview_clock.begin()
		check(dialog.start_architectural(next_project), "regenerate complete edited configuration")
		if not await preview_ready("architecture-preview-changed"): return
		packet = dialog._ready_packet.duplicate(true)
		check(packet.sha256 != previous_sha and dialog._architecture_project.seed == 271828, "edited seed, geometry and shares reach actual native output")
	dialog.confirmed.emit()
	dialog.hide()
	if not await until(func() -> bool: return installed() and not wb._generated_active.is_empty(), "source map committed by existing native owner"): return
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt", {})
	check(receipt.get("generated_source_sha256", "") == packet.sha256, "native constructor independently checks generator materials")
	if reopening:
		check(wb.applied.edits == saved.setup.edits, "fresh process preserves authored paint and erase operations")
		check(wb._generated_active.recipe_sha256 == saved.generation.recipe_sha256, "resolved native recipe provenance survives restart")
		if not await until(func() -> bool: return host.image.get_width() == 1024 and host.image.get_pixel(101, 99).r8 == 58 and host.image.get_pixel(111, 99).r8 == 0, "exact native authored materials survive restart"): return
		check(wb.paint(Vector2i(123, 99), 28), "continue painting after process restart")
		if not await until(func() -> bool: return host.image.get_pixel(123, 99).r8 == 28, "continued native paint applied"): return
	else:
		wb._brush.value = 2
		if not check(wb.paint(Vector2i(101, 99), 58), "ordinary material paint"): return
		if not await until(func() -> bool: return host.image.get_width() == 1024 and host.image.get_pixel(101, 99).r8 == 58, "native paint applied"): return
		if not check(wb.paint(Vector2i(111, 99), 0), "ordinary material erase"): return
		if not await until(func() -> bool: return host.image.get_pixel(111, 99).r8 == 0, "native erase applied"): return
		if not await until(paint_completed, "all native edit completion receipts acknowledged before save"): return
		wb._name.text = SAVE_NAME
		if not check(wb.save_setup(), "save generated baseline and ordered edits"): return
		saved = Store.read_named(SAVE_NAME)
		check(saved.get("generated", false) and saved.setup.edits.size() >= 2, "saved v1 manifest contains authored edits")
		var installed_hash: String = wb._generated_active.sha256
		var epoch: int = host._physical_epoch
		var invalid: Dictionary = Project.default_project()
		invalid.styles[0].preset.geometry.wall_thickness = 100
		check(not dialog.start_architectural(invalid), "invalid proposal refused")
		check(host._physical_epoch == epoch and wb._generated_active.sha256 == installed_hash, "invalid generation leaves installed native World unchanged")
		var changed: Dictionary = Project.default_project()
		changed.seed = 271828
		changed.styles[0].share = 50.0
		changed.styles[1].share = 25.0
		check(dialog.start_architectural(changed), "changed seed and shares start another native proposal")
		dialog._process(0.0)
		dialog._stop()
		check(host._physical_epoch == epoch and wb._generated_active.sha256 == installed_hash and installed(), "cancelled generation preserves installed native World")
		check(not dialog.attests(packet), "cancelled or superseded generation cannot attest an older packet")
		dialog.hide()
	await framebuffer("architecture-workbench-reopened" if reopening else "architecture-workbench-painted")
	report.cases.append({"case": "reopen" if reopening else "author", "source_sha256": packet.sha256,
		"recipe_sha256": packet.recipe_sha256, "native_receipts": packet.receipt_hashes.size(),
		"saved_edits": saved.get("setup", {}).get("edits", []).size(), "display": DisplayServer.get_name()})
	complete = true

func run() -> void:
	var began := Time.get_ticks_usec()
	var phase := OS.get_environment("CYBERSAND_ARCHITECTURE_PHASE")
	if phase.is_empty(): phase = "native"
	report.phase = phase
	report.godot = Engine.get_version_info().string
	report.os = OS.get_name()
	report.display = DisplayServer.get_name()
	if check(ClassDB.class_exists(&"CyberWorldGenerator"), "native generator runtime available"):
		if phase == "native": native_contracts()
		elif phase in ["author", "reopen"]: await authoring(phase == "reopen")
		else: check(false, "unknown qualification phase")
	check(complete, "mandatory complete " + phase + " phase")
	var report_file := FileAccess.open(output_dir().path_join("architecture-" + phase + ".json"), FileAccess.WRITE)
	check(report_file != null, "write final phase evidence")
	report.checks = checks
	report.failures = failures
	report.elapsed_us = Time.get_ticks_usec() - began
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
		report_file.close()
	if host != null:
		preview_clock.queue_free()
		host.queue_free()
		await process_frame
		await process_frame
	print("ARCHITECTURE_RESULTS phase=", phase, " checks=", checks, " failures=", failures, " complete=", complete)
	quit(1 if failures else 0)
