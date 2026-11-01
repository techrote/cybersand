extends SceneTree

# NONQUALIFYING shader-equivalence probe. Does not replace Main/PACE003.
# Root supplies exact baseline/candidate shader bytes and runs the processes
# sequentially with one identical pinned renderer/runtime configuration.
const SIZE := Vector2i(640, 360)
const CONDITIONS := [0, 1, 127, 128, 254, 255]
const SHAPES := [
	Rect2i(2, 2, 16, 16), Rect2i(2, 21, 16, 1),
	Rect2i(2, 25, 16, 3), Rect2i(2, 31, 16, 4),
	Rect2i(21, 2, 1, 16), Rect2i(25, 2, 3, 16),
	Rect2i(31, 2, 4, 16), Rect2i(25, 25, 1, 1),
	Rect2i(34, 32, 4, 1), Rect2i(34, 32, 1, 4)]
var output_dir: String
var palette: Shader
var palette_lut: ImageTexture
var program_lut: ImageTexture
var frames: Array[Dictionary] = []
var submissions: Array[int] = []
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _frame() -> void:
	submissions.append(Time.get_ticks_usec())

func _world(phase: int, smoke_previous: bool = false) -> Image:
	var world := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RG8)
	world.fill(Color(0, 0, 0, 1))
	for material_id: int in range(132):
		var origin := Vector2i((material_id % 16) * 40, floori(float(material_id) / 16.0) * 40)
		for shape_index: int in range(SHAPES.size()):
			var shape: Rect2i = SHAPES[shape_index]
			var condition: int = CONDITIONS[(shape_index + phase) % CONDITIONS.size()]
			var shown_id: int = 4 if smoke_previous else material_id
			for y: int in range(shape.position.y, shape.end.y):
				for x: int in range(shape.position.x, shape.end.x):
					world.set_pixel(origin.x + x, origin.y + y,
						Color(float(shown_id) / 255.0, float(condition) / 255.0, 0, 1))
	return world

func _render(index: int, phase: int, moment: float, blend: float,
		smoke_previous: bool, structured: float) -> void:
	var current := _world(phase)
	var previous := _world(phase, smoke_previous)
	var current_texture := ImageTexture.create_from_image(current)
	var previous_texture := ImageTexture.create_from_image(previous)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.use_hdr_2d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var material := ShaderMaterial.new()
	material.shader = palette
	var uniforms: Dictionary = {
		"world_size_px": Vector2(SIZE), "view_size_px": Vector2(SIZE),
		"view_rect_uv": Vector4(0, 0, 1, 1), "camera_origin_px": Vector2.ZERO,
		"player_origin_px": Vector2(-1000, -1000),
		"condition_projection_enabled": 1.0, "snapshot_blend": blend,
		"presentation_time_override": moment, "structured_detail": structured,
		"growth_decor": 1.0, "vapour_trail_strength": 0.0,
		"water_presentation_mode": float(phase % 3),
		"material_lut_size": Vector2(CyberMaterialAppearanceLut.ATLAS_WIDTH,
			CyberMaterialAppearanceLut.ATLAS_HEIGHT)}
	for key: String in uniforms:
		material.set_shader_parameter(key, uniforms[key])
	material.set_shader_parameter("current_world_texture", current_texture)
	material.set_shader_parameter("previous_world_texture", previous_texture)
	material.set_shader_parameter("material_lut", palette_lut)
	material.set_shader_parameter("material_program_lut", program_lut)
	var rect := TextureRect.new()
	rect.size = Vector2(SIZE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.texture = current_texture
	rect.material = material
	viewport.add_child(rect)
	var started: int = Time.get_ticks_usec()
	print("CYBERSAND_SHADER_ATLAS_STAGE ", JSON.stringify({"stage":"render_requested",
		"index":index, "monotonic_usec":started}))
	root.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var captured: Image = viewport.get_texture().get_image()
	var filename: String = "atlas_%02d.png" % index
	var rawname: String = "atlas_%02d.raw" % index
	var raw: PackedByteArray = captured.get_data()
	var file: FileAccess = FileAccess.open(output_dir.path_join(rawname), FileAccess.WRITE)
	if file == null:
		failures += 1
	else:
		file.store_buffer(raw)
		file.close()
	var raw_format: int = captured.get_format()
	captured.convert(Image.FORMAT_RGBA8)
	var saved: Error = captured.save_png(output_dir.path_join(filename))
	if saved != OK:
		failures += 1
	frames.append({"index": index, "phase": phase, "time": moment,
		"blend": blend, "smoke_previous": smoke_previous,
		"structured_detail": structured, "water_presentation_mode": phase % 3,
		"size": [SIZE.x, SIZE.y], "filename": filename, "raw_filename": rawname,
		"raw_format": raw_format, "raw_sha256": _sha(raw),
		"png_sha256": FileAccess.get_sha256(output_dir.path_join(filename)),
		"current_texture_sha256": _sha(current.get_data()),
		"previous_texture_sha256": _sha(previous.get_data()),
		"started_usec": started, "captured_usec": Time.get_ticks_usec()})
	print("CYBERSAND_SHADER_ATLAS_FRAME ", JSON.stringify(frames.back()))
	viewport.queue_free()
	await process_frame

func _run() -> void:
	var shader_path: String = OS.get_environment("CYBERSAND_ATLAS_SHADER")
	output_dir = OS.get_environment("CYBERSAND_ATLAS_OUTPUT")
	if DisplayServer.get_name() == "headless" or shader_path.is_empty() or output_dir.is_empty():
		push_error("Actual renderer, explicit shader bytes and output directory required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var shader_bytes: PackedByteArray = FileAccess.get_file_as_bytes(shader_path)
	print("CYBERSAND_SHADER_ATLAS_STAGE ", JSON.stringify({"stage":"shader_source_loaded",
		"shader_sha256":_sha(shader_bytes), "monotonic_usec":Time.get_ticks_usec()}))
	palette = Shader.new()
	palette.code = shader_bytes.get_string_from_utf8()
	print("CYBERSAND_SHADER_ATLAS_STAGE ", JSON.stringify({"stage":"shader_resource_created",
		"monotonic_usec":Time.get_ticks_usec()}))
	palette_lut = CyberMaterialAppearanceLut.create_texture()
	program_lut = CyberMaterialAppearanceLut.create_program_texture()
	print("CYBERSAND_SHADER_ATLAS_STAGE ", JSON.stringify({"stage":"lookup_textures_created",
		"monotonic_usec":Time.get_ticks_usec()}))
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	RenderingServer.frame_post_draw.connect(_frame)
	var index: int = 0
	for moment: float in [3.0, 9.5]:
		for phase: int in range(6):
			await _render(index, phase, moment, 1.0, false, 1.0)
			index += 1
	for blend: float in [0.0, 0.5, 1.0]:
		await _render(index, 0, 3.0, blend, true, 1.0)
		index += 1
	await _render(index, 0, 3.0, 1.0, false, 0.0)
	var record: Dictionary = {"schema": "play-pace003-palette-parity-atlas-v1",
		"scope": "NONQUALIFYING isolated shader visual regression; not Main/PACE003",
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"shader_path": shader_path, "shader_sha256": _sha(shader_bytes),
		"shader_bytes": shader_bytes.size(), "godot": Engine.get_version_info(),
		"platform": OS.get_name(), "display_server": DisplayServer.get_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"palette_lut_sha256": _sha(palette_lut.get_image().get_data()),
		"program_lut_sha256": _sha(program_lut.get_image().get_data()),
		"frames": frames, "frame_submissions_usec": submissions,
		"failures": failures}
	var report: FileAccess = FileAccess.open(output_dir.path_join("atlas.json"), FileAccess.WRITE)
	if report == null:
		quit(2)
		return
	report.store_string(JSON.stringify(record, "\t") + "\n")
	report.close()
	print("CYBERSAND_SHADER_ATLAS_RESULT ", JSON.stringify({"frames": frames.size(), "failures": failures}))
	quit(0 if failures == 0 and frames.size() == 16 else 1)
