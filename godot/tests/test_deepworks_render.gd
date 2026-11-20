extends SceneTree

# Actual production-compositor evidence, separate from native chemistry tests.
# Every image comes from Deepworks itself. Layer hides preserve the same native
# packets and frozen material surfaces, so changed pixels measure visibility.
const Map = preload("res://scripts/exhibition/deepworks_map.gd")
const Cell = preload("res://scripts/cell_world.gd")
const ALL_LAYERS := Vector4.ONE
const PIXEL_DELTA: int = 4
const MIN_REAR_PIXELS: int = 128
const MIN_FAR_PIXELS: int = 256
const MIN_ATMOSPHERE_PIXELS: int = 4
const D1_PHASE_COUNT: int = 61
const D1_ARMS: Array[String] = ["hybrid", "stack"]

var checks: int = 0
var failures: int = 0
var artifact_errors: Array[String] = []
var output_directory: String = ""
var evidence: Dictionary = {"hud": [], "layers": {}, "atmosphere": [], "artifacts": []}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Deepworks render checks require an actual rendering display")
		quit(2)
		return
	var started: int = Time.get_ticks_msec()
	output_directory = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--deepworks-render-output="):
			output_directory = argument.trim_prefix("--deepworks-render-output=")
	if not output_directory.is_empty():
		_artifact_check(DirAccess.make_dir_recursive_absolute(output_directory) == OK, "Could not create render evidence directory")
	var viewport := SubViewport.new()
	viewport.name = "DeepworksRenderWitness"
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var controller: Control = load("res://deepworks.tscn").instantiate()
	viewport.add_child(controller)
	controller.set_process(false)
	_expect(controller.ui_ready and not controller.faulted, "Production Deepworks host did not install")
	if controller.faulted:
		await _finish(controller, viewport, started)
		return
	_expect(controller.paused, "Exhibition must install paused before the first draw")
	controller.compositor.set_options({"freeze_material_animation": true})
	# Frozen surfaces still bake once after each admitted packet. Pin their
	# shader clock as well, so those bakes do not sample staggered engine TIME.
	for surface in controller.compositor._surfaces:
		_set_material_phase(surface, 0.0)
	controller.compositor.set_time(0.0)
	evidence["recipe_sha256"] = Map.recipe_hash(controller.definition)
	evidence["source_commit"] = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	if evidence["source_commit"].is_empty():
		evidence["source_commit"] = OS.get_environment("GITHUB_SHA")
	evidence["material_phase_seconds"] = 0.0
	await _settle()
	# Reproduce the header's former minimum-height failure at both usual window
	# sizes. Pixel differences inside the real map catch an opaque UI overlay,
	# even if the compositor's logical size and native layer allocations are fine.
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		viewport.size = size
		controller.set_hud_visible(true)
		controller.show_overview()
		await _settle()
		var map_rect := Rect2i(controller.compositor.global_position + controller.compositor.content_rect().position,
			controller.compositor.content_rect().size)
		var header: Rect2 = controller._top.get_global_rect()
		_expect(header.size.y <= 90.0, "Header obscures the map at " + str(size))
		_expect(not header.intersects(Rect2(map_rect)), "Header overlaps the map at " + str(size))
		_expect(not controller._side.get_global_rect().intersects(Rect2(map_rect)), "Guide overlaps the map at " + str(size))
		_expect(map_rect.size.x >= 500 and map_rect.size.y >= 500, "HUD leaves no useful map view at " + str(size))
		var with_map: Image = _pixels(viewport)
		controller.compositor.set_options({"layer_visibility": Vector4.ZERO})
		await _settle()
		var without_map: Image = _pixels(viewport)
		var visible: int = _changed_pixels(with_map, without_map, map_rect)
		_expect(visible >= map_rect.get_area() / 8, "Native map pixels are hidden under the HUD at " + str(size))
		evidence["hud"].append({"viewport": [size.x, size.y], "header_height": header.size.y,
			"map_size": [map_rect.size.x, map_rect.size.y], "visible_map_pixels": visible})
		_save_image(with_map, "hud-%dx%d.png" % [size.x, size.y])
		controller.compositor.set_options({"layer_visibility": ALL_LAYERS})
		await _settle()
	# A full-size overview makes every final pixel one authored world cell and
	# puts world-centred parallax at its neutral anchor for unambiguous masks.
	viewport.size = Vector2i(1024, 1024)
	var hide := InputEventKey.new()
	hide.keycode = KEY_F8
	hide.pressed = true
	controller._unhandled_key_input(hide)
	controller.show_overview()
	await _settle()
	_expect(not controller.hud_visible and not controller._top.visible and not controller._side.visible,
		"F8 did not hide the complete HUD")
	_expect(controller.compositor.position == Vector2.ZERO and controller.compositor.size == Vector2(1024, 1024),
		"F8 did not give the complete viewport to the map")
	var complete: Image = _pixels(viewport)
	_expect(complete.get_size() == Map.SIZE, "Overview capture is not 1024 square")
	_save_image(complete, "overview-all-layers.png")
	for layer: int in [1, 3]:
		var visibility: Vector4 = ALL_LAYERS
		visibility[layer] = 0.0
		controller.compositor.set_options({"layer_visibility": visibility})
		await _settle()
		var hidden: Image = _pixels(viewport)
		var counts: Array[int] = []
		for district: int in range(16):
			var changed: int = _changed_pixels(complete, hidden, Rect2i(Map.origin(district), Vector2i(256, 256)))
			counts.append(changed)
			var minimum: int = MIN_REAR_PIXELS if layer == 1 else MIN_FAR_PIXELS
			_expect(changed >= minimum, "%s is not visibly contributing in %s: %d pixels" %
				[Map.LAYERS[layer], Map.district_code(district), changed])
		evidence["layers"][Map.LAYERS[layer]] = counts
		_save_image(hidden, "overview-without-" + Map.LAYERS[layer] + ".png")
		controller.compositor.set_options({"layer_visibility": ALL_LAYERS})
		await _settle()
		_expect(_pixels(viewport).get_data() == complete.get_data(),
			"Frozen pixels drifted while only a layer-visibility toggle changed")
	# Snapshot allocated worlds are insufficient evidence of visible weather.
	# Step only atmosphere, capture each authored source's first native pulse,
	# and compare visible/hidden atmosphere at the same immutable packet. Actual
	# nonempty, non-Wall effects cells mask the witness; static riser walls cannot
	# satisfy it. A neighbourhood around each source excludes unrelated wisps.
	_expect(controller.runtime.set_layer_paused("play", true), "Could not pause foreground chemistry for the render witness")
	_expect(controller.runtime.set_layer_paused("scripted", true), "Could not pause rear chemistry for the render witness")
	var sources: Array[Dictionary] = []
	for event: Dictionary in controller.definition["events"]:
		if str(event["id"]).ends_with("-local-atmosphere"):
			sources.append(event)
	sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["first_tick"]) < int(b["first_tick"]))
	_expect(sources.size() == 16, "Every district needs a real automatic atmosphere source")
	for source: Dictionary in sources:
		var target_tick: int = int(source["first_tick"]) + 1
		var district: int = int(source["district"])
		while controller.runtime.layer_tick("effects") < target_tick:
			var result: Dictionary = controller.runtime.step_once()
			_expect(bool(result.get("ok", false)), "Atmosphere step failed before " + str(source["id"]))
			if not bool(result.get("ok", false)):
				await _finish(controller, viewport, started)
				return
		var published: bool = controller._publish_layers()
		_expect(published and not controller.faulted, "Could not publish the atmosphere witness")
		if not published or controller.faulted:
			await _finish(controller, viewport, started)
			return
		_expect(controller.compositor._surfaces[2].layer_tick == target_tick, "Atmosphere surface contains a stale native tick")
		controller.compositor.set_options({"layer_visibility": ALL_LAYERS})
		await _settle()
		var air_on: Image = _pixels(viewport)
		var cells: PackedByteArray = controller.compositor._surfaces[2].cell_image.get_data()
		controller.compositor.set_options({"layer_visibility": Vector4(1, 1, 0, 1)})
		await _settle()
		var air_off: Image = _pixels(viewport)
		var source_rect: Rect2i = source["rect"]
		var witness: Rect2i = source_rect.grow(5).intersection(Rect2i(Map.origin(district), Vector2i(256, 256)))
		var actual_air: int = _changed_pixels(air_on, air_off, witness, cells)
		var fired: Dictionary = controller.runtime.event_stats()["fired"]
		_expect(int(fired.get(source["id"], 0)) >= 1, "The witnessed atmosphere source did not fire")
		_expect(actual_air >= MIN_ATMOSPHERE_PIXELS,
			"Native atmosphere is occluded in %s: %d visible material pixels" % [Map.district_code(district), actual_air])
		var prefix: String = "atmosphere-%s" % Map.district_code(district).to_lower()
		var native_cells: Array[Dictionary] = _native_air_cells(cells, witness)
		var packet_sha256: String = _save_bytes(cells, prefix + "-effects.rg8")
		_save_image(air_on, prefix + "-air-on.png")
		_save_image(air_off, prefix + "-air-off.png")
		evidence["atmosphere"].append({"district": Map.district_code(district), "effects_tick": target_tick,
			"visible_native_air_pixels": actual_air, "source": source["id"], "material": source["material"],
			"source_rect": _rect_values(source_rect), "witness_rect": _rect_values(witness),
			"native_mask_cells": native_cells.size(), "native_cells": native_cells,
			"effects_packet_sha256": packet_sha256, "material_phase_seconds": 0.0,
			"air_on": prefix + "-air-on.png", "air_off": prefix + "-air-off.png"})
		controller.compositor.set_options({"layer_visibility": ALL_LAYERS})
		if district == 12:
			await _sweep_d1_phases(controller, viewport, witness, cells)
	_expect(controller.runtime.layer_tick("play") == 0 and controller.runtime.layer_tick("scripted") == 0,
		"Rendering atmosphere advanced the paused chemistry worlds")
	_expect(controller.runtime.layer_tick("background") == 0, "Frozen far background acquired a simulation tick")
	await _finish(controller, viewport, started)


func _sweep_d1_phases(controller: Control, viewport: SubViewport, witness: Rect2i, native_air: PackedByteArray) -> void:
	# Every effects phase is required in the production Hybrid view. Stack is
	# the same-phase control for projected relief; all native owners and their
	# immutable packets stay fixed across both arms and the complete sweep.
	_expect(controller.mode_index == 3 and int(controller.compositor._material.get_shader_parameter("mode")) == 3,
		"D1 phase sweep must exercise the production Hybrid compositor")
	var originals: Dictionary = {}
	var packet_identity: Dictionary = {}
	for index: int in range(Map.LAYERS.size()):
		var id: String = Map.LAYERS[index]
		var surface = controller.compositor._surfaces[index]
		originals[id] = surface.cell_image.get_data()
		packet_identity[id] = {"reset_generation": surface.reset_generation,
			"layer_tick": surface.layer_tick, "serial": surface.last_serial,
			"sha256": _save_bytes(originals[id], "d1-tick46-" + id + ".rg8")}
	var ticks_before: Dictionary = _layer_ticks(controller)
	var owner_before: Dictionary = _native_identity(controller)
	var sources_before: Dictionary = controller.runtime.event_stats()
	var native_cells: Array[Dictionary] = _native_air_cells(native_air, witness)
	_expect(ticks_before == {"play": 0, "scripted": 0, "effects": 46, "background": 0},
		"D1 presentation sweep must use the actual first-pulse native tick")
	_expect(native_cells.size() == 6, "D1 native pulse must contain exactly six material cells")
	var sweep: Dictionary = {"phases": [], "arms": D1_ARMS, "native_mask_cells": native_cells.size(),
		"capture_coordinates": "Unscaled witness-ROI PNGs; add witness_rect origin to each image pixel for world coordinates",
		"corridor_oracle": "Same native cell signed RGB contribution (air_on - air_off) must match Hybrid and Stack",
		"witness_rect": _rect_values(witness), "packet_identity": packet_identity,
		"ticks_before": ticks_before, "native_owner_before": owner_before,
		"fixed_material_phase_seconds": {"play": 0.0, "scripted": 0.0, "background": 0.0},
		"swept_material_surface": "effects", "depth_compositor_phase_seconds": 0.0}
	evidence["d1_phase_sweep"] = sweep
	var first_failure_retained: bool = false
	for phase: int in range(D1_PHASE_COUNT):
		_set_material_phase(controller.compositor._surfaces[2], float(phase))
		var images: Dictionary = {}
		var arms: Dictionary = {}
		for arm: String in D1_ARMS:
			controller.compositor.set_options({"mode": arm, "layer_visibility": ALL_LAYERS})
			await _settle()
			var effects_image: Image = _pixels(controller.compositor._surfaces[2])
			var air_on: Image = _pixels(viewport)
			controller.compositor.set_options({"layer_visibility": Vector4(1, 1, 0, 1)})
			await _settle()
			var air_off: Image = _pixels(viewport)
			var visible: int = _changed_pixels(air_on, air_off, witness, native_air)
			var prefix: String = "d1-phase-%02d-%s" % [phase, arm]
			_save_image(air_on.get_region(witness), prefix + "-air-on-roi.png")
			_save_image(air_off.get_region(witness), prefix + "-air-off-roi.png")
			var samples: Array[Dictionary] = []
			for cell: Dictionary in native_cells:
				var point := Vector2i(cell["position"][0], cell["position"][1])
				var on: Array[int] = _rgba(air_on, point)
				var off: Array[int] = _rgba(air_off, point)
				var contribution: Array[int] = _rgb_contribution(on, off)
				var delta: int = maxi(absi(contribution[0]), maxi(absi(contribution[1]), absi(contribution[2])))
				samples.append({"position": cell["position"], "material": cell["material"],
					"visual_state_a": cell["visual_state_a"], "air_on_rgba8": on, "air_off_rgba8": off,
					"effects_surface_rgba8": _rgba(effects_image, point), "maximum_rgb_channel_delta": delta,
					"contribution_rgb": contribution, "passes_channel_threshold": delta >= PIXEL_DELTA})
			arms[arm] = {"visible_native_air_pixels": visible, "cells": samples,
				"meets_original_minimum": visible >= MIN_ATMOSPHERE_PIXELS,
				"air_on_roi": prefix + "-air-on-roi.png", "air_off_roi": prefix + "-air-off-roi.png"}
			images[arm] = {"on": air_on, "off": air_off}
		var mismatches: Array[Dictionary] = []
		for index: int in range(native_cells.size()):
			var hybrid: Dictionary = arms["hybrid"]["cells"][index]
			var stack: Dictionary = arms["stack"]["cells"][index]
			if hybrid["contribution_rgb"] != stack["contribution_rgb"]:
				mismatches.append({"position": native_cells[index]["position"],
					"hybrid_contribution_rgb": hybrid["contribution_rgb"], "stack_contribution_rgb": stack["contribution_rgb"]})
		var unchanged: bool = _packets_unchanged(controller, originals, packet_identity)
		var ticks_unchanged: bool = _layer_ticks(controller) == ticks_before
		_expect(arms["hybrid"]["visible_native_air_pixels"] >= MIN_ATMOSPHERE_PIXELS,
			"Native atmosphere is occluded in D1 at phase %d: %d visible material pixels" % [phase, arms["hybrid"]["visible_native_air_pixels"]])
		_expect(mismatches.is_empty(),
			"Projected relief obscures D1's clear atmosphere corridor at phase %d: %d native contributions differ from Stack" % [phase, mismatches.size()])
		_expect(unchanged and ticks_unchanged, "D1 phase %d changed native packet identity, bytes or ticks" % phase)
		var failed: bool = not arms["hybrid"]["meets_original_minimum"] or not mismatches.is_empty() or not unchanged or not ticks_unchanged
		var full_context: Array[String] = []
		if phase == 0 or (failed and not first_failure_retained):
			for arm: String in D1_ARMS:
				var prefix: String = "d1-phase-%02d-%s" % [phase, arm]
				for state: String in ["on", "off"]:
					var filename: String = prefix + "-air-" + state + "-full.png"
					_save_image(images[arm][state], filename)
					full_context.append(filename)
			if failed: first_failure_retained = true
		var record: Dictionary = {"phase_seconds": phase, "arms": arms,
			"native_mask_cells": native_cells.size(), "packet_bytes_unchanged": unchanged,
			"native_ticks_unchanged": ticks_unchanged, "corridor_contributions_match": mismatches.is_empty(),
			"contribution_mismatches": mismatches, "full_frame_context": full_context}
		sweep["phases"].append(record)
		print("DEEPWORKS_D1_PHASE ", JSON.stringify(record))
	_expect(sweep["phases"].size() == D1_PHASE_COUNT, "All sixty-one registered D1 phases must be retained")
	sweep["ticks_after"] = _layer_ticks(controller)
	sweep["native_owner_after"] = _native_identity(controller)
	sweep["packet_bytes_unchanged"] = _packets_unchanged(controller, originals, packet_identity)
	_expect(sweep["native_owner_after"] == owner_before,
		"D1 presentation sweep changed native owner identity or physical state")
	_expect(controller.runtime.event_stats() == sources_before, "Presentation sweep advanced the source programme")
	_expect(sweep["packet_bytes_unchanged"] and sweep["ticks_after"] == ticks_before,
		"D1 presentation sweep must preserve all four native packets and clocks")
	_set_material_phase(controller.compositor._surfaces[2], 0.0)
	controller.compositor.set_options({"mode": "hybrid", "layer_visibility": ALL_LAYERS})
	await _settle()


func _set_material_phase(surface: SubViewport, phase: float) -> void:
	surface._material.set_shader_parameter("presentation_time_override", phase)
	surface.render_target_update_mode = SubViewport.UPDATE_ONCE


func _layer_ticks(controller: Control) -> Dictionary:
	var result: Dictionary = {}
	for id: String in Map.LAYERS:
		result[id] = controller.runtime.layer_tick(id)
	return result


func _native_identity(controller: Control) -> Dictionary:
	var result: Dictionary = {}
	for id: String in Map.LAYERS:
		var world: Object = controller.runtime._worlds[id]
		if world.has_failed():
			_expect(false, "Native owner failed during D1 presentation sweep: " + id)
			result[id] = {"failed": true}
			continue
		var state: Dictionary = world.diagnostic_snapshot(Vector2i.ZERO, Vector2i.ONE, false)
		result[id] = {"generation": controller.runtime.generation(), "native_instance_id": world.get_instance_id(),
			"world_generation": world.get_liquid_policy_session_generation(), "state_hash": state.get("hash", ""),
			"completed_ticks": state.get("completed_ticks", -1), "attempted_ticks": state.get("attempted_ticks", -1)}
		_expect(not str(result[id]["state_hash"]).is_empty(), "Native state identity unavailable: " + id)
	return result


func _packets_unchanged(controller: Control, originals: Dictionary, identity: Dictionary) -> bool:
	for index: int in range(Map.LAYERS.size()):
		var id: String = Map.LAYERS[index]
		var surface = controller.compositor._surfaces[index]
		if (surface.cell_image.get_data() != originals[id]
				or surface.reset_generation != identity[id]["reset_generation"]
				or surface.layer_tick != identity[id]["layer_tick"]
				or surface.last_serial != identity[id]["serial"]):
			return false
	return true


func _native_air_cells(cells: PackedByteArray, region: Rect2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var offset: int = (y * 1024 + x) * 2
			var material: int = cells[offset]
			if material != Cell.EMPTY and material != Cell.WALL:
				result.append({"position": [x, y], "material": material, "visual_state_a": cells[offset + 1]})
	return result


func _rect_values(rect: Rect2i) -> Array[int]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _rgb_contribution(on: Array[int], off: Array[int]) -> Array[int]:
	return [on[0] - off[0], on[1] - off[1], on[2] - off[2]]


func _rgba(image: Image, point: Vector2i) -> Array[int]:
	var colour: Color = image.get_pixelv(point)
	return [roundi(colour.r * 255.0), roundi(colour.g * 255.0), roundi(colour.b * 255.0), roundi(colour.a * 255.0)]


func _finish(controller: Control, viewport: SubViewport, started: int) -> void:
	var file: FileAccess = null
	if not output_directory.is_empty():
		file = FileAccess.open(output_directory.path_join("deepworks-render-evidence.json"), FileAccess.WRITE)
		_artifact_check(file != null, "Could not open render evidence output")
	evidence["checks"] = checks
	evidence["failures"] = failures
	# Artifact I/O is separate from render assertions, keeping check counts the
	# same with and without optional evidence capture. Any I/O error still fails
	# the command and is reported in the final console record.
	evidence["artifact_errors"] = artifact_errors
	evidence["elapsed_ms"] = Time.get_ticks_msec() - started
	evidence["godot"] = Engine.get_version_info().string
	evidence["display"] = DisplayServer.get_name()
	evidence["renderer"] = RenderingServer.get_video_adapter_name()
	evidence["pixel_channel_threshold"] = PIXEL_DELTA
	evidence["minimum_rear_pixels_per_district"] = MIN_REAR_PIXELS
	evidence["minimum_far_pixels_per_district"] = MIN_FAR_PIXELS
	evidence["minimum_native_air_pixels_per_source"] = MIN_ATMOSPHERE_PIXELS
	if file != null:
		file.store_string(JSON.stringify(evidence, "  ") + "\n")
		file.flush()
		_artifact_check(file.get_error() == OK, "Could not write complete render evidence")
		file.close()
	print("DEEPWORKS_RENDER_EVIDENCE ", JSON.stringify(evidence))
	controller.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	print("Deepworks rendered visibility: %d checks, %d failures, %d artifact errors" % [checks, failures, artifact_errors.size()])
	quit(1 if failures or not artifact_errors.is_empty() else 0)


func _pixels(viewport: SubViewport) -> Image:
	var image: Image = viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _changed_pixels(left: Image, right: Image, region: Rect2i, native_air: PackedByteArray = PackedByteArray()) -> int:
	if left.get_size() != right.get_size() or not Rect2i(Vector2i.ZERO, left.get_size()).encloses(region):
		_expect(false, "Invalid rendered pixel-comparison region")
		return 0
	var a: PackedByteArray = left.get_data()
	var b: PackedByteArray = right.get_data()
	var width: int = left.get_width()
	var changed: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if not native_air.is_empty():
				var material: int = native_air[(y * 1024 + x) * 2]
				if material == Cell.EMPTY or material == Cell.WALL:
					continue
			var offset: int = (y * width + x) * 4
			if (absi(a[offset] - b[offset]) >= PIXEL_DELTA or absi(a[offset + 1] - b[offset + 1]) >= PIXEL_DELTA
					or absi(a[offset + 2] - b[offset + 2]) >= PIXEL_DELTA):
				changed += 1
	return changed


func _save_image(image: Image, filename: String) -> void:
	if not output_directory.is_empty():
		var path: String = output_directory.path_join(filename)
		var saved: bool = image.save_png(path) == OK
		_artifact_check(saved, "Could not save " + filename)
		if saved:
			evidence["artifacts"].append({"filename": filename, "sha256": FileAccess.get_sha256(path),
				"bytes": FileAccess.get_file_as_bytes(path).size(), "width": image.get_width(), "height": image.get_height()})


func _save_bytes(bytes: PackedByteArray, filename: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var digest: String = hashing.finish().hex_encode()
	if not output_directory.is_empty():
		var path: String = output_directory.path_join(filename)
		var file := FileAccess.open(path, FileAccess.WRITE)
		_artifact_check(file != null, "Could not open " + filename)
		if file != null:
			file.store_buffer(bytes)
			file.flush()
			var saved: bool = file.get_error() == OK
			file.close()
			_artifact_check(saved and FileAccess.get_sha256(path) == digest, "Could not retain exact " + filename)
			if saved:
				evidence["artifacts"].append({"filename": filename, "sha256": digest, "bytes": bytes.size()})
	return digest


func _artifact_check(condition: bool, message: String) -> void:
	if not condition:
		artifact_errors.append(message)
		push_error(message)


func _settle() -> void:
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
