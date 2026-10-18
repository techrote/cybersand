extends SceneTree

# Actual-pixel checks for presentation contracts changed by the material
# readability pass. Like test_water_presentation_render.gd this needs a real
# display; a headless DisplayServer submits no frames and the test skips.
#   <godot> --path godot --script res://tests/test_material_presentation_render.gd

const SIDE: Vector2i = Vector2i(48, 24)
const TOLERANCE: float = 2.0 / 255.0
var failures: int = 0
var palette_lut: ImageTexture
var program_lut: ImageTexture


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)


func _cell(image: Image, x: int, y: int, material_id: int, condition: int = 0) -> void:
	image.set_pixel(x, y, Color(float(material_id) / 255.0, float(condition) / 255.0, 0, 1))


func _block(image: Image, rect: Rect2i, material_id: int, condition: int = 0) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			_cell(image, x, y, material_id, condition)


func _blank() -> Image:
	var image: Image = Image.create_empty(SIDE.x, SIDE.y, false, Image.FORMAT_RG8)
	image.fill(Color(0, 0, 0, 1))
	return image


func _render(current: Image, previous: Image, time: float, blend: float = 1.0,
		camera: Vector2i = Vector2i.ZERO, view: Vector2i = SIDE) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = view
	viewport.disable_3d = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var current_texture: ImageTexture = ImageTexture.create_from_image(current)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/material_palette.gdshader")
	material.set_shader_parameter("world_size_px", Vector2(current.get_size()))
	material.set_shader_parameter("view_size_px", Vector2(view))
	material.set_shader_parameter("view_rect_uv", Vector4(0, 0, 1, 1))
	material.set_shader_parameter("camera_origin_px", Vector2(camera))
	material.set_shader_parameter("player_origin_px", Vector2(-100, -100))
	material.set_shader_parameter("condition_projection_enabled", 1.0)
	material.set_shader_parameter("snapshot_blend", blend)
	material.set_shader_parameter("presentation_time_override", time)
	material.set_shader_parameter("current_world_texture", current_texture)
	material.set_shader_parameter("previous_world_texture", ImageTexture.create_from_image(previous))
	material.set_shader_parameter("material_lut", palette_lut)
	material.set_shader_parameter("material_program_lut", program_lut)
	material.set_shader_parameter("material_lut_size", Vector2(
		CyberMaterialAppearanceLut.ATLAS_WIDTH, CyberMaterialAppearanceLut.ATLAS_HEIGHT))
	var rect: TextureRect = TextureRect.new()
	rect.size = Vector2(view)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = current_texture
	rect.material = material
	viewport.add_child(rect)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result: Image = viewport.get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return result


func _render_emission(world: Image, time: float) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = SIDE
	viewport.use_hdr_2d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/material_emission.gdshader")
	material.set_shader_parameter("world_texture", ImageTexture.create_from_image(world))
	material.set_shader_parameter("material_program_lut", program_lut)
	material.set_shader_parameter("world_size_px", Vector2(world.get_size()))
	material.set_shader_parameter("view_size_px", Vector2(SIDE))
	material.set_shader_parameter("condition_projection_enabled", 1.0)
	material.set_shader_parameter("presentation_time_override", time)
	var source: ColorRect = ColorRect.new()
	source.size = Vector2(SIDE)
	source.material = material
	viewport.add_child(source)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return result


func _difference(a: Image, b: Image, rect: Rect2i, offset: Vector2i = Vector2i.ZERO) -> float:
	var largest: float = 0.0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x + offset.x, y + offset.y)
			largest = maxf(largest, maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))))
	return largest


func _mean_luma(image: Image, rect: Rect2i) -> float:
	var total: float = 0.0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			total += image.get_pixel(x, y).get_luminance()
	return total / float(rect.get_area())


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("MATERIAL_PRESENTATION_RENDER: skipped (headless DisplayServer has no frame submission)")
		quit(0)
		return
	palette_lut = CyberMaterialAppearanceLut.create_texture()
	program_lut = CyberMaterialAppearanceLut.create_program_texture()
	var full: Rect2i = Rect2i(Vector2i.ZERO, SIDE)

	# Fixed presentation time reaches palette and emission; animated finishes
	# still animate (Oil's approved wave included) when the sample changes.
	var animated: Image = _blank()
	_block(animated, Rect2i(0, 0, 16, 24), CyberCellWorld.OIL)
	_block(animated, Rect2i(16, 0, 16, 24), CyberCellWorld.FIRE, 200)
	_block(animated, Rect2i(32, 0, 16, 24), CyberCellWorld.NEON_CYAN)
	var oil: Rect2i = Rect2i(0, 0, 16, 24)
	var early: Image = await _render(animated, animated, 3.0)
	var repeat: Image = await _render(animated, animated, 3.0)
	var later: Image = await _render(animated, animated, 9.5)
	_expect(_difference(early, repeat, full) <= TOLERANCE, "fixed palette time is not repeatable")
	_expect(_difference(early, later, oil) > 0.02, "Oil wave no longer animates")
	_expect(_difference(early, later, Rect2i(16, 0, 16, 24)) > 0.02, "Fire palette ignored the time sample")
	var glow_early: Image = await _render_emission(animated, 3.0)
	var glow_repeat: Image = await _render_emission(animated, 3.0)
	var glow_later: Image = await _render_emission(animated, 3.25)
	_expect(_difference(glow_early, glow_repeat, full) <= TOLERANCE, "fixed emission time is not repeatable")
	_expect(_difference(glow_early, glow_later, full) > 0.004, "emission pass ignored the time sample")

	# Still scenery: glazing, Ice and wet construction are time-independent.
	var still: Image = _blank()
	var still_ids: Array[int] = [CyberCellWorld.GLASS, CyberCellWorld.CHEMICAL_GLASS,
		CyberCellWorld.DARK_GLASS, CyberCellWorld.ICE, CyberCellWorld.WET_ASPHALT,
		CyberCellWorld.WET_COBBLESTONE, CyberCellWorld.WROUGHT_IRON, CyberCellWorld.CEMENT]
	for index: int in range(still_ids.size()):
		_block(still, Rect2i(index * 6, 0, 6, 24), still_ids[index])
	var still_a: Image = await _render(still, still, 0.0)
	var still_b: Image = await _render(still, still, 11.7)
	_expect(_difference(still_a, still_b, full) <= TOLERANCE, "still-scenery finish changed over time")

	# Shape-aware fills are still and follow the run: a pipe is brighter on
	# its centre line than its rim, whichever way the run points.
	var shaped: Image = _blank()
	_block(shaped, Rect2i(0, 2, 30, 5), CyberCellWorld.STEEL_PIPE)
	_block(shaped, Rect2i(36, 0, 5, 24), CyberCellWorld.STEEL_PIPE)
	_block(shaped, Rect2i(0, 10, 16, 14), CyberCellWorld.HAZARD_STRIPE)
	_block(shaped, Rect2i(18, 10, 14, 14), CyberCellWorld.INSULATION)
	_block(shaped, Rect2i(42, 0, 6, 24), CyberCellWorld.STAINED_GLASS)
	var shaped_a: Image = await _render(shaped, shaped, 0.0)
	var shaped_b: Image = await _render(shaped, shaped, 8.3)
	# Material cells only: Empty cells above pipes may show animated steam leaks.
	for still_rect: Rect2i in [Rect2i(0, 2, 30, 5), Rect2i(36, 0, 5, 24), Rect2i(0, 10, 16, 14),
			Rect2i(18, 10, 14, 14), Rect2i(42, 0, 6, 24)]:
		_expect(_difference(shaped_a, shaped_b, still_rect) <= TOLERANCE,
			"shape-aware fill changed over time in %s" % str(still_rect))
	_expect(_mean_luma(shaped_a, Rect2i(0, 4, 30, 1)) > _mean_luma(shaped_a, Rect2i(0, 2, 30, 1)) + 0.03,
		"horizontal pipe lacks cross-section shading")
	_expect(_mean_luma(shaped_a, Rect2i(38, 0, 1, 24)) > _mean_luma(shaped_a, Rect2i(36, 0, 1, 24)) + 0.03,
		"vertical pipe lacks cross-section shading")

	# World anchoring: a one-cell camera pan shifts output by exactly one cell.
	var world: Image = Image.create_empty(64, 40, false, Image.FORMAT_RG8)
	world.fill(Color(0, 0, 0, 1))
	_block(world, Rect2i(0, 0, 64, 40), CyberCellWorld.RED_BRICK)
	_block(world, Rect2i(10, 8, 30, 20), CyberCellWorld.STEEL_PLATE)
	_block(world, Rect2i(44, 4, 12, 30), CyberCellWorld.WET_COBBLESTONE)
	_block(world, Rect2i(2, 30, 30, 8), CyberCellWorld.OIL)
	var at_origin: Image = await _render(world, world, 2.0, 1.0, Vector2i(0, 0))
	var panned: Image = await _render(world, world, 2.0, 1.0, Vector2i(3, 2))
	_expect(_difference(at_origin, panned, Rect2i(3, 2, SIDE.x - 3, SIDE.y - 2), Vector2i(-3, -2)) <= TOLERANCE,
		"texture swam with the camera")

	# Crossfade endpoints: an eligible changed pixel at blend 0 matches the
	# previous snapshot alone, including its own neighbourhood relief.
	# Same-ID and unsupported pairs keep their non-crossfaded behavior.
	var previous: Image = _blank()
	var current: Image = _blank()
	_block(previous, Rect2i(2, 10, 12, 8), CyberCellWorld.WATER, 255)
	_block(current, Rect2i(2, 6, 12, 12), CyberCellWorld.SAND)
	_block(previous, Rect2i(18, 6, 12, 12), CyberCellWorld.SAND)
	_block(current, Rect2i(18, 10, 12, 8), CyberCellWorld.SAND)
	_block(previous, Rect2i(34, 10, 12, 8), CyberCellWorld.WALL)
	_block(current, Rect2i(34, 10, 12, 8), CyberCellWorld.STONE)
	var eligible: Rect2i = Rect2i(2, 10, 12, 8)
	var same_id: Rect2i = Rect2i(18, 10, 12, 8)
	var unsupported: Rect2i = Rect2i(34, 10, 12, 8)
	var old_alone: Image = await _render(previous, previous, 0.0)
	var new_alone: Image = await _render(current, current, 0.0)
	var start: Image = await _render(current, previous, 0.0, 0.0)
	var finish: Image = await _render(current, previous, 0.0, 1.0)
	_expect(_difference(start, old_alone, eligible) <= TOLERANCE,
		"blend 0 eligible pixels did not use the previous neighbourhood")
	_expect(_difference(finish, new_alone, eligible) <= TOLERANCE, "blend 1 eligible pixels differ from current")
	_expect(_difference(start, new_alone, same_id) <= TOLERANCE, "same-ID pixels were crossfaded")
	_expect(_difference(start, new_alone, unsupported) <= TOLERANCE, "unsupported pair was crossfaded")

	# Condition meanings and invalid rows.
	var conditions: Image = _blank()
	_block(conditions, Rect2i(0, 0, 12, 24), CyberCellWorld.SMOKE, 240)
	_block(conditions, Rect2i(12, 0, 12, 24), CyberCellWorld.SMOKE, 8)
	_block(conditions, Rect2i(24, 0, 12, 24), CyberCellWorld.CEMENT, 180)
	_block(conditions, Rect2i(36, 0, 12, 24), 10)
	var conditioned: Image = await _render(conditions, conditions, 0.0)
	_expect(_mean_luma(conditioned, Rect2i(0, 0, 12, 24)) > _mean_luma(conditioned, Rect2i(12, 0, 12, 24)) + 0.04,
		"fresh Smoke is not more visible than nearly expired Smoke")
	var cured: Image = conditions.duplicate()
	_block(cured, Rect2i(24, 0, 12, 24), CyberCellWorld.CEMENT, 0)
	var cured_render: Image = await _render(cured, cured, 0.0)
	_expect(_mean_luma(conditioned, Rect2i(24, 0, 12, 24)) > _mean_luma(cured_render, Rect2i(24, 0, 12, 24)),
		"wet Cement cure response inverted")
	# Flair branch, not just the LUT curve: wet Cement (cure remaining) swells
	# over time while cured Cement (condition 0, in the still set above) does
	# not; Paste projects no condition, so its G byte must not matter.
	var wet_later: Image = await _render(conditions, conditions, 17.0)
	_expect(_difference(conditioned, wet_later, Rect2i(24, 0, 12, 24)) > 1.5 / 255.0,
		"wet Cement finish ignores its cure-remaining condition")
	var paste_zero: Image = _blank()
	var paste_byte: Image = _blank()
	_block(paste_zero, full, CyberCellWorld.PASTE, 0)
	_block(paste_byte, full, CyberCellWorld.PASTE, 200)
	_expect(_difference(await _render(paste_zero, paste_zero, 4.0),
		await _render(paste_byte, paste_byte, 4.0), full) <= TOLERANCE,
		"Paste appearance depends on an unprojected condition byte")
	var invalid: Color = conditioned.get_pixel(42, 12)
	_expect(invalid.r > 0.6 and invalid.b > 0.6 and invalid.g < 0.35, "reserved ID 10 is not visibly invalid")

	if failures == 0:
		print("MATERIAL_PRESENTATION_RENDER: actual pixels passed (time override, still scenery, anchoring, crossfade endpoints, conditions, invalid row)")
	quit(failures)
