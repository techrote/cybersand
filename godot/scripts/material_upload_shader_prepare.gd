extends RefCounted

## Explicit preparation for the opt-in compact/drawable publication strategy.
## The caller must run this on Main after the actual palette/effect materials
## have their ordinary sampler uniforms. Copies keep the same Shader resources
## and unrelated texture bindings; no accepted material texture is changed.
##
## Tiny real draws exercise sampler-format combinations before interactive
## publication. This moves first-use work into reported initialization; it does
## not reduce that work. Tiny readbacks complete these offscreen draws before
## returning. force_draw redraws all active viewports, so the returned CPU wall
## time includes those draws as well. No scanout or GPU execution time is measured.

const SIDE := 2


static func prepare(parent: Node, palette: ShaderMaterial,
		emission: ShaderMaterial = null, vapour: ShaderMaterial = null,
		channels: int = 2, hdr_2d: bool = true) -> Dictionary:
	var start := Time.get_ticks_usec()
	var result := {"prepared": false, "error": "", "initialization_usec": 0,
		"draw_usec": 0, "readback_usec": 0, "readback_count": 0,
		"phases": [], "source_texture_count": 0,
		"temporary_viewport_count": 0, "temporary_material_count": 0,
		"source_logical_bytes": 0, "viewport_pixels": 0,
		"channels": channels, "hdr_2d": hdr_2d,
		"gpu_completion_measured": false,
		"scope": "Explicit initialization/activation; all force_draw wall time retained"}
	if parent == null or not parent.is_inside_tree() or palette == null or palette.shader == null:
		result.error = "shader preparation requires mounted parent and actual palette material"
	elif channels not in [1, 2]:
		result.error = "shader preparation supports R8 and RG8 material planes"
	elif DisplayServer.get_name() == "headless":
		result.error = "shader preparation requires a graphical backend"
	if not str(result.error).is_empty():
		result.initialization_usec = Time.get_ticks_usec() - start
		return result

	var format: Image.Format = Image.FORMAT_RG8 if channels == 2 else Image.FORMAT_R8
	var sample := Image.create_empty(SIDE, SIDE, false, format)
	sample.fill(Color(3.0 / 255.0, 127.0 / 255.0, 0, 1))
	var compact := ImageTexture.create_from_image(sample)
	var drawable := DrawableTexture2D.new()
	drawable.setup(SIDE, SIDE, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8,
		Color(3.0 / 255.0, 127.0 / 255.0, 0, 1), false)
	if compact == null or not compact.get_rid().is_valid() or not drawable.get_rid().is_valid():
		result.error = "shader preparation texture allocation failed"
		result.initialization_usec = Time.get_ticks_usec() - start
		return result
	result.source_texture_count = 2
	result.source_logical_bytes = SIDE * SIDE * (channels + 4)

	var surfaces: Array[Dictionary] = []
	surfaces.append(_surface(parent, palette, "palette", hdr_2d, false))
	if emission != null and emission.shader != null:
		surfaces.append(_surface(parent, emission, "emission", hdr_2d, true))
	if vapour != null and vapour.shader != null:
		surfaces.append(_surface(parent, vapour, "vapour", hdr_2d, false))
	result.temporary_viewport_count = surfaces.size()
	result.temporary_material_count = surfaces.size()
	result.viewport_pixels = surfaces.size() * SIDE * SIDE
	var bindings: Array[Array] = [[compact, compact], [drawable, compact],
		[drawable, drawable], [compact, drawable]]
	var labels := ["compact_compact", "drawable_compact", "drawable_drawable", "compact_drawable"]
	for index: int in range(bindings.size()):
		var phase_start := Time.get_ticks_usec()
		var current: Texture2D = bindings[index][0]
		var previous: Texture2D = bindings[index][1]
		for surface: Dictionary in surfaces:
			var material: ShaderMaterial = surface.material
			var item: RID = surface.item
			RenderingServer.canvas_item_clear(item)
			if surface.kind == "palette":
				material.set_shader_parameter("current_world_texture", current)
				material.set_shader_parameter("previous_world_texture", previous)
				RenderingServer.canvas_item_add_texture_rect(item,
					Rect2(0, 0, SIDE, SIDE), current.get_rid())
			else:
				material.set_shader_parameter("world_texture", current)
				RenderingServer.canvas_item_add_rect(item, Rect2(0, 0, SIDE, SIDE), Color.WHITE)
			var viewport: SubViewport = surface.viewport
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var draw_start := Time.get_ticks_usec()
		RenderingServer.force_draw(false, 0.0)
		var draw_usec := Time.get_ticks_usec() - draw_start
		result.draw_usec += draw_usec
		var readback_start := Time.get_ticks_usec()
		for surface: Dictionary in surfaces:
			var viewport: SubViewport = surface.viewport
			var completed: Image = viewport.get_texture().get_image()
			result.readback_count += 1
			if completed == null or completed.is_empty() or completed.get_size() != Vector2i(SIDE, SIDE):
				result.error = "shader preparation offscreen readback failed"
		var readback_usec := Time.get_ticks_usec() - readback_start
		result.readback_usec += readback_usec
		result.phases.append({"bindings": labels[index], "draw_usec": draw_usec,
			"readback_usec": readback_usec,
			"elapsed_usec": Time.get_ticks_usec() - phase_start})
		if not str(result.error).is_empty():
			break
	for surface: Dictionary in surfaces:
		RenderingServer.free_rid(surface.item)
		var viewport: SubViewport = surface.viewport
		parent.remove_child(viewport)
		viewport.free()
	result.prepared = str(result.error).is_empty()
	result.initialization_usec = Time.get_ticks_usec() - start
	return result


static func _surface(parent: Node, original: ShaderMaterial, kind: String,
		hdr_2d: bool, transparent: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "MaterialUploadPrepare_" + kind
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.size = Vector2i(SIDE, SIDE)
	viewport.use_hdr_2d = hdr_2d
	viewport.transparent_bg = transparent
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# An independent canvas prevents the preparation viewport from rendering the
	# live scene. No process/physics iteration occurs while this helper runs.
	viewport.world_2d = World2D.new()
	parent.add_child(viewport)
	var material := original.duplicate() as ShaderMaterial
	var item := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(item, viewport.find_world_2d().canvas)
	RenderingServer.canvas_item_set_material(item, material.get_rid())
	RenderingServer.canvas_item_set_default_texture_filter(item,
		RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	RenderingServer.canvas_item_set_default_texture_repeat(item,
		RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_DISABLED)
	return {"viewport": viewport, "material": material, "item": item, "kind": kind}
