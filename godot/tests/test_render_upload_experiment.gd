extends SceneTree

# RENDER-UPLOAD-001: graphical correctness for the opt-in publication strategy.
# This isolated fixture calls the actual Main upload/ACK path with immutable
# native-shaped packets; it does not create another native simulation owner.
const Context = preload("res://tests/palette_qualification_context.gd")
const Experiment = preload("res://scripts/render_upload_experiment.gd")
const Main = preload("res://scripts/main.gd")
const SIZE := Vector2i(129, 97)
const FRAME := Vector2i(96, 64)
var assertions := 0
var failures: Array[String] = []
var records: Array = []
var expected_refusals: Array = []
var captures: Array = []
var output_path := "user://render-upload-correctness.json"
var palette_shader: Shader
var emission_shader: Shader
var trail_shader: Shader
var palette: ImageTexture
var program: ImageTexture

func _init() -> void:
	print("RENDER_UPLOAD_PID ", OS.get_process_id())
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		push_error("RENDER_UPLOAD_ASSERTION: " + message)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i].begins_with("--output="):
			output_path = args[i].trim_prefix("--output=")
		elif args[i] == "--output" and i + 1 < args.size():
			output_path = args[i + 1]
	if DisplayServer.get_name() == "headless":
		_expect(false, "graphical backend is mandatory; headless is not qualification")
		_finish()
		return
	root.size = Vector2i(320, 240)
	await process_frame
	await process_frame
	palette_shader = CyberPaletteShader.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	emission_shader = load("res://shaders/material_emission.gdshader")
	trail_shader = load("res://shaders/material_vapour_trail.gdshader")
	palette = CyberMaterialAppearanceLut.create_texture()
	program = CyberMaterialAppearanceLut.create_program_texture()
	for fmt in [Image.FORMAT_R8, Image.FORMAT_RG8]:
		await _byte_history(fmt)
	await _main_ack_recovery()
	await _framebuffers()
	_finish()

func _finish() -> void:
	var receipt := {"schema": "render-upload-correctness-v1", "ok": failures.is_empty(),
		"assertions": assertions, "failures": failures, "context": Context.identity(get_script().resource_path, palette_shader),
		"records": records, "expected_refusals": expected_refusals, "captures": captures,
		"scope": "actual graphical texture readback, Main immutable-packet ACK/recovery, unchanged palette/emission/vapour shader framebuffer comparison; no native simulation laws exercised"}
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write RENDER-UPLOAD-001 correctness receipt")
		quit(2)
		return
	file.store_string(JSON.stringify(receipt, "\t"))
	file.close()
	print("RENDER_UPLOAD_CORRECTNESS ", JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)

func _pattern(fmt: Image.Format, size: Vector2i = SIZE) -> Image:
	var channels := 1 if fmt == Image.FORMAT_R8 else 2
	var bytes := PackedByteArray()
	bytes.resize(size.x * size.y * channels)
	for i in size.x * size.y:
		bytes[i * channels] = i % 132
		if channels == 2:
			bytes[i * channels + 1] = (i * 29) % 256
	bytes[bytes.size() - channels] = 255
	return Image.create_from_data(size.x, size.y, false, fmt, bytes)

func _rgba(image: Image) -> Image:
	var copy: Image = image.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	return copy

func _sha(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()

func _check_texture(texture: Texture2D, wanted: Image, label: String) -> void:
	var actual := texture.get_image()
	_expect(actual != null and actual.get_size() == wanted.get_size(), label + " shape/readback")
	if actual == null or actual.get_size() != wanted.get_size():
		return
	var lhs := _rgba(actual).get_data()
	var rhs := _rgba(wanted).get_data()
	_expect(lhs == rhs, label + " every material/condition byte")
	records.append({"case": label, "actual_sha256": _sha(lhs), "expected_sha256": _sha(rhs), "equal": lhs == rhs})

func _metadata(rectangles: Array[Rect2i], channels: int) -> PackedInt32Array:
	var metadata := PackedInt32Array()
	var offset := 0
	for rect: Rect2i in rectangles:
		metadata.append_array(PackedInt32Array([rect.position.x, rect.position.y,
			rect.size.x, rect.size.y, offset, rect.size.x * channels]))
		offset += rect.get_area() * channels
	return metadata

func _helper_state(helper: RefCounted) -> Dictionary:
	return {"serial": helper.accepted_serial, "generation": helper.accepted_generation,
		"slots": helper._slot_serials.duplicate(), "journals": [helper._dirty_slots[0].duplicate(), helper._dirty_slots[1].duplicate()],
		"current_rid": helper.current.get_rid(), "previous_rid": helper.previous.get_rid(),
		"current_bytes": helper.current.get_image().get_data(), "previous_bytes": helper.previous.get_image().get_data(),
		"pending_bytes": helper._pending_staging_bytes, "pending_batches": helper._batch_count}

func _byte_history(fmt: Image.Format) -> void:
	var label := "R8" if fmt == Image.FORMAT_R8 else "RG8"
	var channels := 1 if fmt == Image.FORMAT_R8 else 2
	var image := _pattern(fmt)
	var helper := Experiment.new()
	_expect(helper.initialize(image, 0, 7), label + " initialize")
	if not helper.initialized:
		return
	_expect(helper.canary_result.get("passed", false), label + " startup byte canary")
	_check_texture(helper.current, image, label + " initial current all132 IDs and condition bytes")
	_check_texture(helper.previous, image, label + " initial previous")
	var naive: Array[Image] = [image.duplicate(), image.duplicate()]
	var naive_slot := 0
	var naive_failed := false
	var operations: Array = [
		[Rect2i(0, 0, 1, 1)], [Rect2i(128, 96, 1, 1)],
		[Rect2i(63, 0, 2, 97)], [Rect2i(0, 63, 129, 2)],
		[Rect2i(4, 4, 3, 3), Rect2i(103, 81, 5, 7)],
		[Rect2i(4, 4, 3, 3)], [Rect2i(0, 0, 129, 97)]]
	var serial := 0
	for op: Array in operations:
		serial += 1
		var prior: Image = image.duplicate()
		var rects: Array[Rect2i] = []
		for rect: Rect2i in op:
			rects.append(rect)
			image.fill_rect(rect, Color(float((serial * 13) % 132) / 255.0, float((serial * 43) % 256) / 255.0, 0, 1))
		var full := serial == operations.size()
		var result: Dictionary = helper.publish(image, _metadata(rects, channels), serial, 7, full)
		_expect(result.accepted, label + " publication %d accepted" % serial)
		var target := 1 - naive_slot
		for rect: Rect2i in rects:
			naive[target].blit_rect(image, rect, rect.position)
		naive_slot = target
		if serial == 2:
			naive_failed = naive[target].get_data() != image.get_data()
		await RenderingServer.frame_post_draw
		_check_texture(helper.current, image, label + " publication %d current" % serial)
		_check_texture(helper.previous, prior, label + " publication %d previous" % serial)
	_expect(naive_failed, label + " negative control detects latest-patch-only ping-pong corruption")
	# Three accepted updates occur without a frame yield; final slots must be the
	# last two complete revisions, even though native serials may be coalesced.
	var prior: Image
	for burst in range(3):
		prior = image.duplicate()
		serial += 3
		var rect := Rect2i(8 + burst * 50, 13 + burst * 31, 2, 2)
		image.fill_rect(rect, Color(float(CyberCellWorld.WATER + burst) / 255.0, float(burst * 127) / 255.0, 0, 1))
		var result: Dictionary = helper.publish(image, _metadata([rect], channels), serial, 7, false)
		_expect(result.accepted, label + " same-frame coalesced serial accepted")
	await RenderingServer.frame_post_draw
	_check_texture(helper.current, image, label + " burst current")
	_check_texture(helper.previous, prior, label + " burst previous")
	_expect(helper._pending_staging_bytes == 0 and helper._batch_count == 0, label + " frame releases retained staging")
	var valid := _metadata([Rect2i(1, 1, 2, 2)], channels)
	var bad_cases: Array = [
		[image, valid, serial, 7, false, "repeated serial"],
		[image, valid, serial - 1, 7, false, "reordered serial"],
		[image, valid, serial + 1, 6, false, "stale generation"],
		[image, valid, serial + 1, 8, false, "replacement without full"],
		[image, valid, serial + 1, 7, true, "false full declaration"],
		[image, PackedInt32Array(), serial + 1, 7, false, "empty metadata"],
		[image, PackedInt32Array([0, 0, 1]), serial + 1, 7, false, "malformed metadata"],
		[image, _metadata([Rect2i(128, 96, 2, 2)], channels), serial + 1, 7, false, "bounds"],
		[_pattern(fmt, Vector2i(65, 67)), valid, serial + 1, 7, false, "size without reinitialize"]]
	for bad: Array in bad_cases:
		var before := _helper_state(helper)
		var result: Dictionary = helper.publish(bad[0], bad[1], bad[2], bad[3], bad[4])
		_expect(not result.accepted, label + " rejects " + bad[5])
		_expect(before == _helper_state(helper), label + " rejection preserves both revisions/journals " + bad[5])
		expected_refusals.append({"scope": label, "case": bad[5], "reason": result.error})
	serial += 1
	var old: Image = image.duplicate()
	image = _pattern(fmt)
	var replaced: Dictionary = helper.publish(image, _metadata([Rect2i(Vector2i.ZERO, SIZE)], channels), serial, 8, true)
	_expect(replaced.accepted, label + " explicit World replacement accepted")
	_check_texture(helper.current, image, label + " replacement current")
	_check_texture(helper.previous, old, label + " replacement preceding material snapshot")
	var resized := _pattern(fmt, Vector2i(65, 67))
	_expect(helper.initialize(resized, serial + 1, 9), label + " resize/recreation")
	_check_texture(helper.current, resized, label + " recreated current")
	_check_texture(helper.previous, resized, label + " recreated previous")
	helper.close()
	_expect(not helper.initialized and helper.current == null and helper.previous == null and helper._pending_staging_bytes == 0,
		label + " shutdown releases texture ownership/staging")

func _main_fixture(strategy: String, initial: Image) -> Control:
	var controller: Control = Main.new()
	controller.render_upload_strategy_override = strategy
	controller.world_extent = initial.get_size()
	controller.render_channels = 1 if initial.get_format() == Image.FORMAT_R8 else 2
	controller.render_image_format = initial.get_format()
	controller.image = initial.duplicate()
	controller.world_shader = ShaderMaterial.new()
	controller.world_shader.shader = palette_shader
	controller.glow_source_shader = ShaderMaterial.new()
	controller.glow_source_shader.shader = emission_shader
	controller.world_view = TextureRect.new()
	controller.current_view_size = FRAME
	controller._render_upload_context = {"serial": 0, "generation": 7, "full": true}
	controller.last_uploaded_world_generation = 7
	controller.create_render_textures()
	controller.world_view.texture = controller.texture
	return controller

func _packet(source: Image, rectangles: Array[Rect2i], serial: int, generation: int = 7, full: bool = false) -> CyberSimulationSnapshot:
	var s := CyberSimulationSnapshot.new()
	s.serial = serial
	s.render_snapshot_serial = serial
	s.render_world_generation = generation
	s.world_revision = serial + 100
	s.render_channels = 1 if source.get_format() == Image.FORMAT_R8 else 2
	s.render_full_refresh = full
	s.render_patch_rectangles = _metadata(rectangles, s.render_channels)
	for rect: Rect2i in rectangles:
		s.render_patch_cells.append_array(source.get_region(rect).get_data())
	return s

func _dispose(controller: Control) -> void:
	if controller._render_upload_experiment != null:
		controller._render_upload_experiment.close()
	controller.world_view.free()
	controller.free()

func _main_ack_recovery() -> void:
	var image := _pattern(Image.FORMAT_RG8)
	var controller := _main_fixture("drawable", image)
	_expect(controller.render_upload_status.active == "drawable", "Main opt-in starts drawable")
	for serial in [1, 2]:
		var rect := Rect2i(12 + serial * 30, 12, 3, 4)
		image.fill_rect(rect, Color(float(serial) / 255.0, 1, 0, 1))
		controller.consume_render_snapshot(_packet(image, [rect], serial))
		_expect(controller.simulation_worker._acknowledged_render_snapshot_serial == serial, "Main ACK accepted %d" % serial)
	var accepted: Image = image.duplicate()
	var old_current: Texture2D = controller.texture
	var old_previous: Texture2D = controller.previous_texture
	var rect := Rect2i(1, 1, 4, 4)
	image.fill_rect(rect, Color(0, 1, 0, 1))
	# Production duplicate-error-log suppression avoids classifying intentional
	# negative fixtures as unexpected engine failures; rejection/refresh/ACK logic
	# below remains the real Main implementation.
	controller.last_rejected_render_snapshot_serial = 3
	controller.consume_render_snapshot(_packet(image, [rect], 3, 6))
	_expect(controller.simulation_worker._acknowledged_render_snapshot_serial == 2, "Main withholds ACK on candidate continuity failure")
	_expect(controller.simulation_worker._render_full_refresh_requested, "Main requests native full refresh after candidate refusal")
	_expect(controller.last_uploaded_render_snapshot_serial == 2 and controller.last_uploaded_revision == 102,
		"Main retains accepted publication/revision identity on refusal")
	_expect(controller.texture == old_current and controller.previous_texture == old_previous, "Main refuses to expose partially reconstructed texture pair")
	_check_texture(controller.texture, accepted, "Main refusal accepted display retained")
	expected_refusals.append({"scope": "Main", "case": "stale generation", "reason": controller.last_render_patch_validation_error})
	controller.last_rejected_render_snapshot_serial = 4
	controller.consume_render_snapshot(_packet(image, [rect], 4, 7, false))
	_expect(controller.simulation_worker._acknowledged_render_snapshot_serial == 2 and controller._render_upload_fallback_pending,
		"Main continues withholding ACK for partial payload during recovery")
	controller.consume_render_snapshot(_packet(image, [Rect2i(Vector2i.ZERO, SIZE)], 5, 7, true))
	_expect(controller.simulation_worker._acknowledged_render_snapshot_serial == 5 and controller.last_uploaded_world_generation == 7,
		"Main ACKs exact complete fallback refresh")
	_expect(controller.render_upload_status.active == "full" and controller._render_upload_experiment == null,
		"Main resumes reliable ImageTexture path after recovery")
	_check_texture(controller.texture, image, "Main full fallback current")
	_check_texture(controller.previous_texture, accepted, "Main full fallback previous retains last accepted image")
	image.fill_rect(rect, Color(float(CyberCellWorld.SAND) / 255.0, 0, 0, 1))
	controller.consume_render_snapshot(_packet(image, [rect], 6))
	_expect(controller.simulation_worker._acknowledged_render_snapshot_serial == 6, "Main publication resumes after fallback")
	controller.create_render_textures()
	_expect(controller.render_upload_status.active == "full", "Main failed candidate stays disabled after local recreation")
	_dispose(controller)

func _scene_image() -> Image:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RG8)
	image.fill(Color(0, 0, 0, 1))
	for id in range(132):
		var rect := Rect2i((id % 12) * 10, (id / 12) * 7, 9, 6)
		image.fill_rect(rect, Color(float(id) / 255.0, float((id * 37) % 256) / 255.0, 0, 1))
	image.fill_rect(Rect2i(2, 79, 36, 14), Color(float(CyberCellWorld.WATER) / 255.0, 0.8, 0, 1))
	image.fill_rect(Rect2i(42, 79, 17, 14), Color(float(CyberCellWorld.SAND) / 255.0, 0.5, 0, 1))
	image.fill_rect(Rect2i(65, 79, 17, 14), Color(float(CyberCellWorld.STEAM) / 255.0, 1, 0, 1))
	image.fill_rect(Rect2i(90, 79, 17, 14), Color(float(CyberCellWorld.SMOKE) / 255.0, 1, 0, 1))
	return image

func _framebuffers() -> void:
	var image := _scene_image()
	var initial: Image = image.duplicate()
	var full := _main_fixture("full", image)
	var drawable := _main_fixture("drawable", image)
	_expect(full.render_upload_status.active == "full" and drawable.render_upload_status.active == "drawable", "framebuffer strategy admission")
	for serial in [1, 2]:
		var rect := Rect2i(2 + serial * 8, 78, 8, 17)
		image.fill_rect(rect, Color(0, 0, 0, 1))
		var moved := Rect2i(8 + serial * 8, 77, 8, 3)
		image.fill_rect(moved, Color(float(CyberCellWorld.WATER) / 255.0, 0.5, 0, 1))
		var packet := _packet(image, [rect, moved], serial)
		full.consume_render_snapshot(packet)
		drawable.consume_render_snapshot(packet)
	var views: Array = [
		{"origin": Vector2.ZERO, "view": SIZE},
		{"origin": Vector2(17.25, 11.5), "view": Vector2i(87, 65)},
		{"origin": Vector2(55, 62), "view": Vector2i(64, 32)}]
	for view_index in views.size():
		for blend in [0.0, 0.25, 0.5, 0.75, 1.0]:
			await _render_pair(full, drawable, "palette", views[view_index], blend,
				"palette_view%d_blend%.2f" % [view_index, blend])
		await _render_pair(full, drawable, "emission", views[view_index], 1.0, "emission_view%d" % view_index)
	# Deliberately incorrect previous texture is the temporal visible negative
	# control. An oracle insensitive to stale history would not reject this.
	var saved_previous: Texture2D = drawable.previous_texture
	drawable.previous_texture = ImageTexture.create_from_image(initial)
	await _render_pair(full, drawable, "palette", views[0], 0.25, "negative_stale_previous", false)
	drawable.previous_texture = saved_previous
	var vapour_view := {"origin": Vector2(60, 70), "view": Vector2i(64, 27)}
	var seeded: Array = await _render_pair(full, drawable, "vapour", vapour_view, 1.0, "vapour_seed")
	var rect := Rect2i(60, 75, 58, 20)
	image.fill_rect(rect, Color(0, 0, 0, 1))
	var packet := _packet(image, [rect], 3)
	full.consume_render_snapshot(packet)
	drawable.consume_render_snapshot(packet)
	var trail: Array = await _render_pair(full, drawable, "vapour", vapour_view, 1.0, "vapour_history_after_remove", true, seeded)
	await _render_pair(full, drawable, "palette", vapour_view, 0.5, "palette_vapour_composite", true, trail)
	_dispose(full)
	_dispose(drawable)
	# R8 has no condition channel: exercise the actual shader's neutral fallback
	# as well as the byte-level R8 checks above.
	var r8: Image = initial.duplicate()
	r8.convert(Image.FORMAT_R8)
	var r8_full := _main_fixture("full", r8)
	var r8_drawable := _main_fixture("drawable", r8)
	var r8_rect := Rect2i(10, 78, 15, 17)
	r8.fill_rect(r8_rect, Color(0, 0, 0, 1))
	var r8_packet := _packet(r8, [r8_rect], 1)
	r8_full.consume_render_snapshot(r8_packet)
	r8_drawable.consume_render_snapshot(r8_packet)
	for blend in [0.0, 0.25, 0.5, 0.75, 1.0]:
		await _render_pair(r8_full, r8_drawable, "palette", views[0], blend, "R8_palette_blend%.2f" % blend)
	await _render_pair(r8_full, r8_drawable, "emission", views[0], 1.0, "R8_emission")
	await _render_pair(r8_full, r8_drawable, "vapour", vapour_view, 1.0, "R8_vapour_neutral_condition")
	_dispose(r8_full)
	_dispose(r8_drawable)

func _render_pair(full: Control, drawable: Control, kind: String, view: Dictionary,
		blend: float, label: String, expect_equal: bool = true, histories: Array = []) -> Array:
	var viewports: Array[SubViewport] = []
	var controllers: Array[Control] = [full, drawable]
	var retained: Array[Texture2D] = []
	for index in range(2):
		var controller := controllers[index]
		var viewport := SubViewport.new()
		viewport.size = FRAME
		viewport.disable_3d = true
		viewport.use_hdr_2d = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var material := ShaderMaterial.new()
		material.shader = palette_shader if kind == "palette" else (emission_shader if kind == "emission" else trail_shader)
		material.set_shader_parameter("world_size_px", Vector2(SIZE))
		material.set_shader_parameter("view_size_px", Vector2(view.view))
		material.set_shader_parameter("camera_origin_px", view.origin)
		material.set_shader_parameter("condition_projection_enabled", 1.0 if controller.render_channels == 2 else 0.0)
		material.set_shader_parameter("presentation_time_override", 3.25)
		material.set_shader_parameter("material_program_lut", program)
		material.set_shader_parameter("world_texture", controller.texture)
		material.set_shader_parameter("current_world_texture", controller.texture)
		material.set_shader_parameter("previous_world_texture", controller.previous_texture)
		material.set_shader_parameter("snapshot_blend", blend)
		material.set_shader_parameter("material_lut", palette)
		material.set_shader_parameter("material_lut_size", Vector2(CyberMaterialAppearanceLut.ATLAS_WIDTH, CyberMaterialAppearanceLut.ATLAS_HEIGHT))
		material.set_shader_parameter("player_origin_px", Vector2(-1000, -1000))
		material.set_shader_parameter("view_rect_uv", Vector4(0, 0, 1, 1))
		if kind == "vapour":
			material.set_shader_parameter("delta_seconds", 0.0 if histories.is_empty() else 0.2)
			material.set_shader_parameter("history_origin_px", view.origin)
		if not histories.is_empty():
			var history := ImageTexture.create_from_image(histories[index])
			retained.append(history)
			material.set_shader_parameter("history_texture", history)
			material.set_shader_parameter("vapour_trail_texture", history)
			material.set_shader_parameter("vapour_trail_origin_px", view.origin)
			material.set_shader_parameter("vapour_trail_strength", 1.0)
		var rect := TextureRect.new()
		rect.size = Vector2(FRAME)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.texture = controller.texture
		rect.material = material
		viewport.add_child(rect)
		viewports.append(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var images: Array = [viewports[0].get_texture().get_image(), viewports[1].get_texture().get_image()]
	var lhs := _rgba(images[0]).get_data()
	var rhs := _rgba(images[1]).get_data()
	var equal := lhs == rhs
	_expect(equal == expect_equal, label + (" framebuffer equality" if expect_equal else " stale-history negative control"))
	records.append({"case": label, "framebuffer_equal": equal, "expected_equal": expect_equal,
		"full_sha256": _sha(lhs), "drawable_sha256": _sha(rhs), "blend": blend,
		"origin": [view.origin.x, view.origin.y], "view": [view.view.x, view.view.y]})
	if label in ["palette_view0_blend0.50", "emission_view0", "vapour_history_after_remove", "negative_stale_previous"]:
		for i in range(2):
			var filename := label + ("_full.png" if i == 0 else "_drawable.png")
			var path := output_path.get_base_dir().path_join(filename)
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var status := _rgba(images[i]).save_png(path)
			_expect(status == OK, "save compact framebuffer exemplar " + filename)
			captures.append({"path": filename, "sha256": FileAccess.get_sha256(path)})
	for viewport: SubViewport in viewports:
		viewport.queue_free()
	await process_frame
	return images
