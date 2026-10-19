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
var palette_shader: Shader
var emission_shader: Shader
var trail_shader: Shader


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
		camera: Vector2i = Vector2i.ZERO, view: Vector2i = SIDE, extra: Dictionary = {}) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = view
	viewport.disable_3d = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var current_texture: ImageTexture = ImageTexture.create_from_image(current)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = palette_shader
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
	for key: String in extra:
		material.set_shader_parameter(key, extra[key])
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


func _render_emission(world: Image, time: float, output: Vector2i = SIDE,
		camera: Vector2i = Vector2i.ZERO) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = output
	viewport.use_hdr_2d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = emission_shader
	material.set_shader_parameter("world_texture", ImageTexture.create_from_image(world))
	material.set_shader_parameter("material_program_lut", program_lut)
	material.set_shader_parameter("world_size_px", Vector2(world.get_size()))
	material.set_shader_parameter("view_size_px", Vector2(SIDE))
	material.set_shader_parameter("camera_origin_px", Vector2(camera))
	material.set_shader_parameter("condition_projection_enabled", 1.0)
	material.set_shader_parameter("presentation_time_override", time)
	var source: ColorRect = ColorRect.new()
	source.size = Vector2(output)
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
	# Retain these across fixtures instead of repeatedly compiling an identical
	# large shader as each temporary viewport is freed.
	palette_shader = load("res://shaders/material_palette.gdshader")
	emission_shader = load("res://shaders/material_emission.gdshader")
	trail_shader = load("res://shaders/material_vapour_trail.gdshader")
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
	# Chemical Glass is a liquid tank with rising bubbles, so it is not listed.
	var still_ids: Array[int] = [CyberCellWorld.GLASS, CyberCellWorld.SLATE,
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

	await _check_fidelity_pass_two(full)

	if failures == 0:
		print("MATERIAL_PRESENTATION_RENDER: actual pixels passed (time override, still scenery, anchoring, crossfade endpoints, conditions, all 132 ID slots, invalid bounds, growth blockers, vapour footprint, half-resolution single-cell fireworks)")
	quit(failures)


# Second fidelity pass (MAT-002): building catalogue stillness, Empty-cell
# growth decor, the vapour-trail sampler and firework presentation.
func _check_fidelity_pass_two(full: Rect2i) -> void:
	# Static building finishes are time-independent. Glinting metals, snow
	# glitter and phosphor breathing are deliberate exceptions.
	var animated_ids: Array[int] = [CyberCellWorld.PACKED_SNOW, CyberCellWorld.ALUMINIUM_PANEL,
		CyberCellWorld.GOLD_LEAF, CyberCellWorld.BRASS_PANEL, CyberCellWorld.PHOSPHOR_PANEL]
	var static_ids: Array[int] = []
	for id: int in range(CyberCellWorld.FIRST_BUILDING_MATERIAL, CyberCellWorld.LAST_MATERIAL + 1):
		if not id in animated_ids:
			static_ids.append(id)
	var offset: int = 0
	while offset < static_ids.size():
		var still: Image = _blank()
		var rects: Array[Rect2i] = []
		for slot: int in range(8):
			if offset + slot >= static_ids.size():
				break
			var rect: Rect2i = Rect2i(slot * 6, 0, 6, 24)
			_block(still, rect, static_ids[offset + slot])
			rects.append(rect)
		var a: Image = await _render(still, still, 0.0)
		var b: Image = await _render(still, still, 11.7)
		for index: int in range(rects.size()):
			_expect(_difference(a, b, rects[index]) <= TOLERANCE,
				"building material %d finish changed over time" % static_ids[offset + index])
			_expect(_mean_luma(a, rects[index]) > 0.0,
				"building material %d rendered black" % static_ids[offset + index])
		offset += 8

	# Growth decor: Empty cells above Plant/Fungus and below an overhang gain
	# presentation-only growth; the quality hook removes it; material cells
	# are unaffected by the hook.
	var garden: Image = _blank()
	_block(garden, Rect2i(0, 16, 24, 8), CyberCellWorld.PLANT, 64)
	_block(garden, Rect2i(24, 16, 24, 8), CyberCellWorld.FUNGUS, 64)
	_block(garden, Rect2i(0, 0, 48, 3), CyberCellWorld.MOSS_WALL)
	var with_decor: Image = await _render(garden, garden, 1.0)
	var without_decor: Image = await _render(garden, garden, 1.0, 1.0, Vector2i.ZERO, SIDE, {"growth_decor": 0.0})
	_expect(_difference(with_decor, without_decor, Rect2i(0, 9, 24, 7)) > 0.1,
		"no flowers/grass grew above Plant")
	_expect(_difference(with_decor, without_decor, Rect2i(24, 9, 24, 7)) > 0.1,
		"no mushrooms grew above Fungus")
	_expect(_difference(with_decor, without_decor, Rect2i(0, 3, 48, 5)) > 0.1,
		"no vines hang beneath the Moss Wall overhang")
	_expect(_difference(with_decor, without_decor, Rect2i(0, 16, 48, 8)) <= TOLERANCE and
		_difference(with_decor, without_decor, Rect2i(0, 0, 48, 3)) <= TOLERANCE,
		"growth decor changed material cells")
	# A wall interrupts the host search. Decorative growth must not appear
	# through it, and unrelated hard surfaces must never sprout.
	var blocked: Image = garden.duplicate()
	_block(blocked, Rect2i(0, 13, 48, 1), CyberCellWorld.WALL)
	_block(blocked, Rect2i(0, 5, 48, 1), CyberCellWorld.WALL)
	var blocked_on: Image = await _render(blocked, blocked, 1.0)
	var blocked_off: Image = await _render(blocked, blocked, 1.0, 1.0, Vector2i.ZERO, SIDE, {"growth_decor": 0.0})
	_expect(_difference(blocked_on, blocked_off, Rect2i(0, 6, 48, 7)) <= TOLERANCE,
		"growth passed through a solid blocker")
	var nonhost: Image = _blank()
	_block(nonhost, Rect2i(0, 16, 48, 8), CyberCellWorld.GRANITE_BLOCK)
	_expect(_difference(await _render(nonhost, nonhost, 1.0),
		await _render(nonhost, nonhost, 1.0, 1.0, Vector2i.ZERO, SIDE, {"growth_decor": 0.0}), full) <= TOLERANCE,
		"a non-host material produced growth decor")
	var panned_growth: Image = await _render(garden, garden, 1.0, 1.0, Vector2i(3, 2))
	_expect(_difference(with_decor, panned_growth, Rect2i(3, 3, 42, 13), Vector2i(-3, -2)) <= TOLERANCE,
		"growth decor moved with the camera")

	# Vapour trail: zero strength is an exact no-op; a remembered vapour only
	# brightens Empty cells.
	var trail_image: Image = Image.create_empty(SIDE.x, SIDE.y, false, Image.FORMAT_RGBAH)
	trail_image.fill(Color(1.0, 1.0, 0.0, 1.0))
	var trail: ImageTexture = ImageTexture.create_from_image(trail_image)
	var scene: Image = _blank()
	_block(scene, Rect2i(0, 12, 48, 12), CyberCellWorld.GRANITE_BLOCK)
	var plain: Image = await _render(scene, scene, 2.0)
	var off: Image = await _render(scene, scene, 2.0, 1.0, Vector2i.ZERO, SIDE,
		{"vapour_trail_texture": trail, "vapour_trail_strength": 0.0})
	var on: Image = await _render(scene, scene, 2.0, 1.0, Vector2i.ZERO, SIDE,
		{"vapour_trail_texture": trail, "vapour_trail_strength": 1.0})
	_expect(_difference(plain, off, full) <= TOLERANCE, "disabled vapour trail changed the output")
	_expect(_mean_luma(on, Rect2i(0, 0, 48, 12)) > _mean_luma(plain, Rect2i(0, 0, 48, 12)) + 0.2,
		"vapour afterimage did not appear over Empty cells")
	_expect(_difference(plain, on, Rect2i(0, 12, 48, 12)) <= TOLERANCE,
		"vapour afterimage was drawn over solid material")
	var outside: Image = await _render(scene, scene, 2.0, 1.0, Vector2i.ZERO, SIDE,
		{"vapour_trail_texture": trail, "vapour_trail_strength": 1.0,
		"vapour_trail_origin_px": Vector2(SIDE.x, 0)})
	_expect(_difference(plain, outside, full) <= TOLERANCE,
		"vapour outside the history footprint smeared its edge into the view")

	# Fireworks: a flying Rocket is a bright, blooming source; an idle one
	# emits nothing. Mites glisten over time.
	var rockets: Image = _blank()
	_block(rockets, Rect2i(4, 4, 8, 8), CyberCellWorld.ROCKET, 0)
	_block(rockets, Rect2i(20, 4, 8, 8), CyberCellWorld.ROCKET, 3)
	_block(rockets, Rect2i(34, 4, 8, 8), CyberCellWorld.MITE, 1)
	var fireworks: Image = await _render(rockets, rockets, 1.0)
	_expect(_mean_luma(fireworks, Rect2i(20, 4, 8, 8)) > _mean_luma(fireworks, Rect2i(4, 4, 8, 8)) + 0.15,
		"activated firework is not brighter than an idle rocket")
	var rocket_glow: Image = await _render_emission(rockets, 1.0)
	_expect(_mean_luma(rocket_glow, Rect2i(20, 4, 8, 8)) > 0.2 and
		_mean_luma(rocket_glow, Rect2i(4, 4, 8, 8)) < 0.02,
		"firework bloom source is wrong")
	var mites_later: Image = await _render(rockets, rockets, 2.3)
	_expect(_difference(fireworks, mites_later, Rect2i(34, 4, 8, 8)) > 0.05, "mite iridescence does not animate")

	await _check_vapour_trail_feedback()
	await _check_single_cell_emission()
	await _check_catalogue_rendering()

	# Colour intent: Toxic Sludge is darker than Acid; Steam is near-white.
	var liquids: Image = _blank()
	_block(liquids, Rect2i(0, 0, 16, 24), CyberCellWorld.TOXIC_SLUDGE)
	_block(liquids, Rect2i(16, 0, 16, 24), CyberCellWorld.ACID, 255)
	_block(liquids, Rect2i(32, 0, 16, 24), CyberCellWorld.STEAM, 180)
	var tinted: Image = await _render(liquids, liquids, 1.0)
	_expect(_mean_luma(tinted, Rect2i(0, 0, 16, 24)) < _mean_luma(tinted, Rect2i(16, 0, 16, 24)) - 0.15,
		"Toxic Sludge is not a deep, dark green")
	var steam_colour: Color = tinted.get_pixel(40, 12)
	_expect(steam_colour.s < 0.15, "Steam is tinted instead of white")


# Exercise the actual 2:1 source-viewport footprint, including the top/left
# border and a camera offset. Large firework blocks at 1:1 resolution cannot
# detect a missed quadrant in the downsample filter.
func _check_single_cell_emission() -> void:
	var output: Vector2i = SIDE / 2
	for camera: Vector2i in [Vector2i.ZERO, Vector2i(3, 5)]:
		for block: Vector2i in [Vector2i.ZERO, Vector2i(10, 8), SIDE - Vector2i(2, 2)]:
			for quadrant: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var world: Image = Image.create_empty(64, 40, false, Image.FORMAT_RG8)
				var source: Vector2i = camera + block + quadrant
				_cell(world, source.x, source.y, CyberCellWorld.ROCKET, 1)
				var rendered: Image = await _render_emission(world, 1.0, output, camera)
				var target: Vector2i = block / 2
				_expect(rendered.get_pixelv(target).get_luminance() > 0.20,
					"single-cell firework missed its 2x2 output footprint: camera %s, block %s, quadrant %s" % [camera, block, quadrant])
	var idle: Image = _blank()
	_cell(idle, 10, 8, CyberCellWorld.ROCKET, 0)
	_expect(_mean_luma(await _render_emission(idle, 1.0, output), Rect2i(Vector2i.ZERO, output)) < 0.0001,
		"idle single-cell Rocket emitted light")
	var spark: Image = _blank()
	_cell(spark, 10, 8, CyberCellWorld.SPARK, 255)
	_expect((await _render_emission(spark, 1.0, output)).get_pixel(5, 4).get_luminance() > 0.1,
		"single-cell Spark missed its downsampled bloom source")


# Every defined row reaches the real palette shader, including the animated
# building exceptions omitted by the stillness test. Reserved/unknown IDs are
# tested as negative controls at both ends of the unused byte range.
func _check_catalogue_rendering() -> void:
	var empty_render: Image = await _render(_blank(), _blank(), 1.0)
	var atlas := Image.create_empty(SIDE.x * 12, SIDE.y * 11, false, Image.FORMAT_RGBA8)
	atlas.blit_rect(empty_render, Rect2i(Vector2i.ZERO, SIDE), Vector2i.ZERO)
	for material_id: int in range(1, CyberCellWorld.LAST_MATERIAL + 1):
		if material_id == 10:
			continue
		var swatch: Image = _blank()
		_block(swatch, Rect2i(Vector2i.ZERO, SIDE), material_id, 180)
		var rendered: Image = await _render(swatch, swatch, 1.0)
		atlas.blit_rect(rendered, Rect2i(Vector2i.ZERO, SIDE),
			Vector2i(material_id % 12, material_id / 12) * SIDE)
		_expect(_difference(rendered, empty_render, Rect2i(4, 4, 40, 16)) > TOLERANCE,
			"material %d rendered as Empty" % material_id)
		var invalid_pixels: int = 0
		for y: int in range(4, 20):
			for x: int in range(4, 44):
				var colour: Color = rendered.get_pixel(x, y)
				if colour.r > 0.6 and colour.b > 0.6 and colour.g < 0.1:
					invalid_pixels += 1
		_expect(invalid_pixels < 640, "material %d rendered the invalid-ID fallback" % material_id)
	for invalid_id: int in [10, CyberCellWorld.LAST_MATERIAL + 1, 255]:
		var swatch: Image = _blank()
		_block(swatch, Rect2i(Vector2i.ZERO, SIDE), invalid_id)
		var rendered: Image = await _render(swatch, swatch, 1.0)
		if invalid_id == 10:
			atlas.blit_rect(rendered, Rect2i(Vector2i.ZERO, SIDE), Vector2i(10, 0) * SIDE)
		var colour: Color = rendered.get_pixel(24, 12)
		_expect(colour.r > 0.6 and colour.b > 0.6 and colour.g < 0.1,
			"invalid material %d did not render the explicit magenta fallback" % invalid_id)
	var evidence: String = OS.get_environment("CYBERSAND_PRESENTATION_EVIDENCE")
	if not evidence.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(evidence) == OK,
			"could not create the presentation evidence directory")
		_expect(atlas.save_png(evidence.path_join("material-id-slots-000-131.png")) == OK,
			"could not retain the rendered catalogue evidence")


func _render_trail(world: Image, history: Texture2D, camera: Vector2i, history_origin: Vector2i,
		delta: float) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = SIDE
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = trail_shader
	material.set_shader_parameter("world_texture", ImageTexture.create_from_image(world))
	material.set_shader_parameter("history_texture", history)
	material.set_shader_parameter("world_size_px", Vector2(world.get_size()))
	material.set_shader_parameter("view_size_px", Vector2(SIDE))
	material.set_shader_parameter("camera_origin_px", Vector2(camera))
	material.set_shader_parameter("history_origin_px", Vector2(history_origin))
	material.set_shader_parameter("delta_seconds", delta)
	material.set_shader_parameter("condition_projection_enabled", 1.0)
	material.set_shader_parameter("presentation_time_override", 0.0)
	material.set_shader_parameter("rise_px_per_second", 0.0)
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


# The afterimage keeps the brighter of current vapour and the decayed history,
# clears on a zero delta, and follows the world when the camera pans.
func _check_vapour_trail_feedback() -> void:
	var steam: Image = Image.create_empty(64, 40, false, Image.FORMAT_RG8)
	steam.fill(Color(0, 0, 0, 1))
	_block(steam, Rect2i(10, 8, 6, 6), CyberCellWorld.STEAM, 255)
	_block(steam, Rect2i(30, 8, 6, 6), CyberCellWorld.SMOKE, 255)
	var empty: Image = Image.create_empty(64, 40, false, Image.FORMAT_RG8)
	empty.fill(Color(0, 0, 0, 1))
	var black: ImageTexture = ImageTexture.create_from_image(Image.create_empty(SIDE.x, SIDE.y, false, Image.FORMAT_RGBAH))
	var first: Image = await _render_trail(steam, black, Vector2i.ZERO, Vector2i.ZERO, 0.0)
	_expect(first.get_pixel(12, 10).r > 0.9 and first.get_pixel(32, 10).g > 0.9,
		"vapour trail did not record current Steam/Smoke")
	_expect(first.get_pixel(2, 2).r == 0.0 and first.get_pixel(2, 2).g == 0.0,
		"vapour trail recorded vapour in an Empty cell")
	var history: ImageTexture = ImageTexture.create_from_image(first)
	var faded: Image = await _render_trail(empty, history, Vector2i.ZERO, Vector2i.ZERO, 0.2)
	var steam_left: float = faded.get_pixel(12, 10).r
	var smoke_left: float = faded.get_pixel(32, 10).g
	_expect(steam_left > 0.4 and steam_left < 0.8, "vanished Steam did not leave a decaying afterimage")
	_expect(smoke_left > steam_left, "Smoke afterimage does not outlast Steam")
	var cleared: Image = await _render_trail(empty, history, Vector2i.ZERO, Vector2i.ZERO, 0.0)
	_expect(cleared.get_pixel(12, 10).r == 0.0, "zero delta did not clear the history")
	var panned: Image = await _render_trail(empty, history, Vector2i(3, 2), Vector2i.ZERO, 0.2)
	_expect(absf(panned.get_pixel(9, 8).r - steam_left) < 0.05,
		"afterimage did not stay world-anchored when the camera panned")
