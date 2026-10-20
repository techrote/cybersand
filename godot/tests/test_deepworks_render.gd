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

var checks: int = 0
var failures: int = 0
var artifact_errors: Array[String] = []
var output_directory: String = ""
var evidence: Dictionary = {"hud": [], "layers": {}, "atmosphere": []}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Deepworks render checks require an actual rendering display")
		quit(2)
		return
	var started: int = Time.get_ticks_msec()
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
		evidence["atmosphere"].append({"district": Map.district_code(district), "effects_tick": target_tick,
			"visible_native_air_pixels": actual_air, "source": source["id"], "material": source["material"]})
		controller.compositor.set_options({"layer_visibility": ALL_LAYERS})
		if district in [0, 7, 15]:
			_save_image(air_on, "atmosphere-%s.png" % Map.district_code(district).to_lower())
	_expect(controller.runtime.layer_tick("play") == 0 and controller.runtime.layer_tick("scripted") == 0,
		"Rendering atmosphere advanced the paused chemistry worlds")
	_expect(controller.runtime.layer_tick("background") == 0, "Frozen far background acquired a simulation tick")
	await _finish(controller, viewport, started)


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
		_artifact_check(image.save_png(output_directory.path_join(filename)) == OK, "Could not save " + filename)


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
