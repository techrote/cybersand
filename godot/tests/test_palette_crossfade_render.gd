extends SceneTree

const Context = preload("res://tests/palette_qualification_context.gd")

# Render the bounded ANGLE variant on each available real backend. A native-GL
# run exercises the code variant but is never labelled an ANGLE compiler result.
# The outgoing colour oracle uses flat primary-colour LUT rows and a registered
# non-neutral program; it does not call/extract the production base-colour helper.
const SIZE := Vector2i(64, 36)
const TILE := 4
const TOLERANCE := 2.0 / 255.0
const MATERIALS := 132
const FIXTURE_VERSION := "palette-bounded-crossfade-v3"
const PROGRAM_SHA256 := "6ab9c18f2f2993eda7c552b86a28d639a70fb03e0ffdfb2ae070da5c587bb60d"
const PROBE_SIZE := Vector2i(16, 256)
const PROGRAM_PROBE_CODE := """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D program_pixels : filter_nearest, repeat_disable;
void fragment() {
	int scalar_index = int(floor(UV.x * 16.0));
	int column = scalar_index / 4;
	float row = floor(UV.y * 256.0);
	vec4 command = texture(program_pixels, vec2((float(column) + 0.5) / 4.0, (row + 0.5) / 256.0));
	float value = command[scalar_index % 4];
	if (scalar_index == 15) value /= 64.0;
	COLOR = vec4(vec3(value), 1.0);
}
"""
const COLOURS: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE, Color.CYAN,
	Color.MAGENTA, Color.YELLOW, Color.WHITE]
const REFERENCE_CODE := """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D expected_pixels : filter_nearest, repeat_disable;
void fragment() { COLOR = texture(expected_pixels, UV); }
"""
var assertions := 0
var failures := 0
var bounded: Shader
var reference: Shader
var palette: ImageTexture
var program: ImageTexture
var canonical_program: Image
var edited_program: Image
var bound_program: Texture2D
var program_bindings: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var output_dir: String
var draw_records: Array[Dictionary] = []
var oracle_inputs: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("PALETTE_CROSSFADE_RENDER: " + message)

func _base_colour(material_id: int, condition: int) -> Color:
	# Registered inputs: RGB primary/secondary/white, value .25 -> .75,
	# green tint at half the smooth response, red/blue emission at 0 -> .125.
	# Exact primary endpoints avoid depending on CPU/GPU sRGB approximations.
	var position: float = clampf((float(condition) / 255.0 - 0.25) / 0.5, 0.0, 1.0)
	var response: float = position * position * (3.0 - 2.0 * position)
	var rgb: Color = COLOURS[material_id % COLOURS.size()] * lerpf(0.25, 0.75, response)
	rgb = rgb.lerp(Color(0, 1, 0, rgb.a), response * 0.5)
	rgb += Color(0.5, 0, 0.25, 0) * (response * 0.125)
	rgb.a = 1.0
	return rgb

func _textures() -> void:
	var lut := Image.create_empty(64, 256, false, Image.FORMAT_RGBA8)
	# Edit the canonical CPU image before upload. ANGLE's texture readback
	# clamps HDR flair tags, even when the returned Image format is RGBAH.
	canonical_program = CyberMaterialAppearanceLut.create_program_image()
	_expect(canonical_program.get_size() == Vector2i(4, 256) and canonical_program.get_format() == Image.FORMAT_RGBAH,
		"canonical program is not the registered HDR image")
	_expect(_bytes_sha256(canonical_program.get_data()) == PROGRAM_SHA256, "canonical program bytes differ from independent registration")
	_expect(canonical_program.get_pixel(3, 2).a == 33.0 and canonical_program.get_pixel(3, 3).a == 29.0,
		"canonical Sand/Water HDR flair tags differ")
	var commands: Image = canonical_program.duplicate()
	for material_id: int in range(256):
		for x: int in range(64):
			lut.set_pixel(x, material_id, COLOURS[material_id % COLOURS.size()])
		var flair: float = commands.get_pixel(3, material_id).a
		commands.set_pixel(0, material_id, Color(0, 1, 0, 0.5))
		commands.set_pixel(1, material_id, Color(0.25, 0.75, 0.25, 0.75))
		commands.set_pixel(2, material_id, Color(1, 1, 0, 0.125))
		commands.set_pixel(3, material_id, Color(0.5, 0, 0.25, flair))
	palette = ImageTexture.create_from_image(lut)
	edited_program = commands
	program = ImageTexture.create_from_image(commands)

func _bytes_sha256(data: PackedByteArray) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(data)
	return digest.finish().hex_encode()

func _texture_identity(texture: Texture2D) -> Dictionary:
	return {"object_id":texture.get_instance_id(), "rid":texture.get_rid().get_id()} if texture != null else {"object_id":0,"rid":0}

func _save_program_bytes(image: Image, label: String) -> Dictionary:
	if output_dir.is_empty(): return {}
	var path := output_dir.path_join(label + ".rgba16f")
	var handle := FileAccess.open(path, FileAccess.WRITE)
	_expect(handle != null, "cannot retain CPU program bytes " + label)
	if handle == null: return {}
	handle.store_buffer(image.get_data())
	handle.close()
	return {"file":label+".rgba16f", "sha256":FileAccess.get_sha256(path),
		"bytes":image.get_data().size(), "size":[4,256], "format":image.get_format()}

func _program_scalar(image: Image, x: int, y: int) -> float:
	var command: Color = image.get_pixel(x / 4, y)
	return command[x % 4] / (64.0 if x == 15 else 1.0)

func _program_pixel_error(actual: Image, expected_program: Image, x: int, y: int) -> float:
	var value := _program_scalar(expected_program, x, y)
	var colour := actual.get_pixel(x, y)
	return maxf(maxf(absf(colour.r-value),absf(colour.g-value)),maxf(absf(colour.b-value),absf(colour.a-1.0)))

func _program_error(actual: Image, expected_program: Image) -> float:
	var maximum := 0.0
	for y: int in range(PROBE_SIZE.y):
		for x: int in range(PROBE_SIZE.x):
			maximum = maxf(maximum, _program_pixel_error(actual, expected_program, x, y))
	return maximum

func _probe_program(texture: Texture2D, role: String) -> Dictionary:
	var requested_usec := Time.get_ticks_usec()
	var viewport := SubViewport.new()
	viewport.size = PROBE_SIZE
	viewport.disable_3d = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var probe_shader := Shader.new()
	probe_shader.code = PROGRAM_PROBE_CODE
	var material := ShaderMaterial.new()
	material.shader = probe_shader
	material.set_shader_parameter("program_pixels", texture)
	var before: Texture2D = material.get_shader_parameter("program_pixels")
	_expect(_texture_identity(before) == _texture_identity(texture), "program probe sampled a substituted texture")
	var rect := TextureRect.new()
	rect.size = Vector2(PROBE_SIZE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.texture = texture
	rect.material = material
	viewport.add_child(rect)
	root.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var readback_usec := Time.get_ticks_usec()
	var after: Texture2D = material.get_shader_parameter("program_pixels")
	_expect(_texture_identity(after) == _texture_identity(before), "program probe binding changed during rendering")
	var receipt := {"role":role, "binding_before":_texture_identity(before), "binding_after":_texture_identity(after),
		"requested_usec":requested_usec, "readback_usec":readback_usec, "capture":Context.capture(image,"program_"+role)}
	viewport.queue_free()
	await process_frame
	return {"image":image,"receipt":receipt}

func _program_probes() -> Dictionary:
	# These two extra data draws follow all original 24 frames. The positive
	# samples the exact object retrieved from a production material binding.
	var canonical_bytes := _save_program_bytes(canonical_program, "program_canonical")
	var edited_bytes := _save_program_bytes(edited_program, "program_edited")
	var edited_sha := _bytes_sha256(edited_program.get_data())
	_expect(bound_program != null and _texture_identity(bound_program) == _texture_identity(program), "no actual production program binding retained")
	var positive: Dictionary = await _probe_program(bound_program, "production_bound")
	var clamped: Image = edited_program.duplicate()
	for y: int in range(256):
		var command := clamped.get_pixel(3, y)
		command.a = minf(command.a, 1.0)
		clamped.set_pixel(3, y, command)
	var negative_texture := ImageTexture.create_from_image(clamped)
	_expect(_texture_identity(negative_texture) != _texture_identity(bound_program), "negative control must use a separate texture")
	var negative: Dictionary = await _probe_program(negative_texture, "clamped_control")
	var positive_error := _program_error(positive.image, edited_program)
	var clamped_error := _program_error(negative.image, clamped)
	var rejection_error := _program_error(negative.image, edited_program)
	var sand_error := _program_pixel_error(negative.image, edited_program, 15, 2)
	var water_error := _program_pixel_error(negative.image, edited_program, 15, 3)
	_expect(positive_error <= TOLERANCE, "actual production GPU program differs from registered instructions")
	_expect(clamped_error <= TOLERANCE, "negative GPU control is not the registered clamped programme")
	_expect(rejection_error > TOLERANCE, "positive comparator accepted clamped GPU instructions")
	_expect(sand_error > TOLERANCE and water_error > TOLERANCE, "clamped Sand/Water HDR tags were not independently rejected")
	_expect(_bytes_sha256(canonical_program.get_data()) == PROGRAM_SHA256 and _bytes_sha256(edited_program.get_data()) == edited_sha
		and _texture_identity(bound_program) == _texture_identity(program), "program inputs changed during probe retention")
	return {"schema":"palette-program-gpu-inputs-v1", "scalar_count":4096, "flair_scale":64,
		"canonical":canonical_bytes, "edited":edited_bytes, "production_bindings":program_bindings,
		"probe_shader_sha256":PROGRAM_PROBE_CODE.sha256_text(), "positive":positive.receipt, "negative":negative.receipt,
		"positive_max_error":positive_error, "negative_control_max_error":clamped_error,
		"negative_rejection_max_error":rejection_error, "sand_rejection_error":sand_error, "water_rejection_error":water_error}

func _world(condition: int, outgoing: bool) -> Image:
	var image := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RG8)
	for y: int in range(SIZE.y):
		for x: int in range(SIZE.x):
			var material_id: int = mini((y / TILE) * 16 + x / TILE, MATERIALS - 1)
			var current_id: int = 3 if material_id == 2 else 2
			image.set_pixel(x, y, Color(float(material_id if outgoing else current_id) / 255.0,
				float(condition if outgoing else 255) / 255.0, 0, 1))
	return image

func _expected(condition: int) -> Image:
	var image := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBAF)
	for y: int in range(SIZE.y):
		for x: int in range(SIZE.x):
			image.set_pixel(x, y, _base_colour(mini((y / TILE) * 16 + x / TILE, MATERIALS - 1), condition))
	return image

func _draw(current: Image, previous: Image, blend: float,
		camera := Vector2i.ZERO, expected: Image = null) -> Image:
	var requested_usec: int = Time.get_ticks_usec()
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.use_hdr_2d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var material := ShaderMaterial.new()
	material.shader = bounded if expected == null else reference
	var texture := ImageTexture.create_from_image(current)
	if expected != null:
		material.set_shader_parameter("expected_pixels", ImageTexture.create_from_image(expected))
	else:
		var values := {"world_size_px":Vector2(SIZE), "view_size_px":Vector2(SIZE),
			"view_rect_uv":Vector4(0, 0, 1, 1), "camera_origin_px":Vector2(camera),
			"player_origin_px":Vector2(-1000, -1000), "condition_projection_enabled":0.0,
			"snapshot_blend":blend, "presentation_time_override":3.0, "growth_decor":0.0,
			"vapour_trail_strength":0.0, "material_lut_size":Vector2(64, 256)}
		for key: String in values:
			material.set_shader_parameter(key, values[key])
		material.set_shader_parameter("current_world_texture", texture)
		material.set_shader_parameter("previous_world_texture", ImageTexture.create_from_image(previous))
		material.set_shader_parameter("material_lut", palette)
		material.set_shader_parameter("material_program_lut", program)
	var rect := TextureRect.new()
	rect.size = Vector2(SIZE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.texture = texture
	rect.material = material
	viewport.add_child(rect)
	root.add_child(viewport)
	var program_before: Dictionary = {}
	if expected == null:
		bound_program = material.get_shader_parameter("material_program_lut")
		program_before = _texture_identity(bound_program)
		_expect(program_before == _texture_identity(program), "production draw sampled a substituted program texture")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var completed_usec: int = Time.get_ticks_usec()
	if expected == null:
		var after: Texture2D = material.get_shader_parameter("material_program_lut")
		var program_after := _texture_identity(after)
		_expect(program_after == program_before, "production program binding changed during rendering")
		program_bindings.append({"draw_index":draw_records.size(), "before":program_before, "after":program_after})
	draw_records.append({"role":"production" if expected == null else "independent_reference",
		"blend":blend, "camera":[camera.x,camera.y], "requested_usec":requested_usec,
		"readback_usec":completed_usec, "request_to_readback_seconds":float(completed_usec-requested_usec)/1000000.0})
	viewport.queue_free()
	await process_frame
	return image

func _difference(left: Image, right: Image, area: Rect2i,
		offset := Vector2i.ZERO) -> float:
	var largest := 0.0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var a: Color = left.get_pixel(x, y)
			var b: Color = right.get_pixel(x + offset.x, y + offset.y)
			largest = maxf(largest, maxf(maxf(absf(a.r-b.r), absf(a.g-b.g)),
				maxf(absf(a.b-b.b), absf(a.a-b.a))))
	return largest

func _save(image: Image, label: String) -> Dictionary:
	if output_dir.is_empty(): return {}
	var raw_path: String = output_dir.path_join(label + ".raw")
	var raw := FileAccess.open(raw_path, FileAccess.WRITE)
	_expect(raw != null, "cannot retain raw frame " + label)
	if raw == null: return {}
	raw.store_buffer(image.get_data())
	raw.close()
	var display: Image = image.duplicate()
	display.convert(Image.FORMAT_RGBA8)
	var png_path: String = output_dir.path_join(label + ".png")
	_expect(display.save_png(png_path) == OK, "cannot retain PNG " + label)
	return {"raw":raw_path, "raw_sha256":FileAccess.get_sha256(raw_path),
		"size":[image.get_width(),image.get_height()], "format":image.get_format(),
		"png":png_path, "png_sha256":FileAccess.get_sha256(png_path)}

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PALETTE_CROSSFADE_RENDER: skipped (headless DisplayServer has no frame submission)")
		quit(0)
		return
	var source: Shader = load("res://shaders/material_palette.gdshader")
	bounded = CyberPaletteShader.palette_for_driver(source, "opengl3_angle")
	Context.emit(get_script().resource_path, bounded)
	reference = Shader.new()
	reference.code = REFERENCE_CODE
	output_dir = OS.get_environment("CYBERSAND_PALETTE_CROSSFADE_OUTPUT")
	if not output_dir.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(output_dir) == OK, "cannot create evidence directory")
	_textures()
	var full := Rect2i(Vector2i.ZERO, SIZE)
	for condition: int in [0, 128, 255]:
		var current := _world(condition, false)
		var previous := _world(condition, true)
		var expected := _expected(condition)
		var reference_image: Image = await _draw(current, previous, 0, Vector2i.ZERO, expected)
		var complete: Image = await _draw(current, current, 1)
		oracle_inputs.append({"condition":condition,
			"reference":Context.capture(reference_image,"reference_%d" % condition),
			"current":Context.capture(complete,"current_%d" % condition)})
		for blend: float in [0.0, 0.5, 1.0]:
			var actual: Image = await _draw(current, previous, blend)
			var oracle: Image = reference_image if blend == 0.0 else complete
			if blend == 0.5:
				oracle = reference_image.duplicate()
				for y: int in range(SIZE.y):
					for x: int in range(SIZE.x):
						oracle.set_pixel(x, y, reference_image.get_pixel(x, y).lerp(complete.get_pixel(x, y), 0.5))
			var maximum: float = _difference(actual, oracle, full)
			for material_id: int in range(MATERIALS):
				var tile := Rect2i((material_id % 16) * TILE, (material_id / 16) * TILE, TILE, TILE)
				_expect(_difference(actual, oracle, tile) <= TOLERANCE,
					"ID %d condition %d blend %.1f differs from the registered base/full mixture" % [material_id, condition, blend])
			var panned: Image = await _draw(current, previous, blend, Vector2i(3, 2))
			var pan_error: float = _difference(actual, panned,
				Rect2i(3, 2, SIZE.x-3, SIZE.y-2), Vector2i(-3, -2))
			_expect(pan_error <= TOLERANCE, "bounded crossfade swam with camera")
			rows.append({"condition":condition, "blend":blend, "material_slots":MATERIALS,
				"max_rgba_difference":maximum, "camera_pan_difference":pan_error,
				"pan_capture":Context.capture(panned,"pan_%d_%02d" % [condition,roundi(blend*10)]),
				"capture":_save(actual, "condition_%d_blend_%02d" % [condition, roundi(blend*10)])})
	var program_inputs: Dictionary = await _program_probes()
	var result := {"fixture":FIXTURE_VERSION, "assertions":assertions, "failures":failures, "program_inputs":program_inputs,
		"backend":RenderingServer.get_current_rendering_driver_name(),
		"variant_selection":"explicit bounded variant; does not relabel a native backend as ANGLE",
		"shader":CyberPaletteShader.provenance(bounded),
		"reference_shader_sha256":REFERENCE_CODE.sha256_text(), "rows":rows,"oracle_inputs":oracle_inputs,
		"cache_state":OS.get_environment("CYBERSAND_SHADER_CACHE_STATE") if not OS.get_environment("CYBERSAND_SHADER_CACHE_STATE").is_empty() else "unknown",
		"draw_timings":draw_records, "timing_scope":"request to actual readback, includes compilation when needed; not a compiler-only timer",
		"tolerance":TOLERANCE, "material_slots":MATERIALS, "conditions":[0,128,255], "blends":[0,0.5,1]}
	if not output_dir.is_empty():
		var report := FileAccess.open(output_dir.path_join("crossfade.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify(result, "\t") + "\n")
			report.close()
		else:
			_expect(false, "cannot retain crossfade report")
			result.failures = failures
	print("PALETTE_CROSSFADE_RENDER_RESULT ", JSON.stringify(result))
	quit(0 if failures == 0 else 1)
