extends SceneTree

# Production Main publication, actual drawable readback and pixel-equivalent
# terrain/effect/mask shaders. This is a correctness/transfer-volume gate;
# software-renderer timing is not physical Windows/NVIDIA acceptance.
const Main = preload("res://scripts/main.gd")
const Publisher = preload("res://scripts/blit_material_publisher.gd")
const Palette = preload("res://scripts/palette_shader_selector.gd")
const Clearance = preload("res://scripts/workbench_presentation_coherence.gd")
const Appearance = preload("res://scripts/material_appearance_lut.gd")
var assertions: int = 0
var failures: int = 0
var observations: Array[Dictionary] = []
var histories_completed: int = 0
var shader_pairs_completed: int = 0
var large_completed: bool = false


func _init() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("MATERIAL_TILE_PUBLICATION: " + label)


func _host(extent: Vector2i, channels: int, mode: String, seed_value: int = 0) -> Control:
	var host: Control = Main.new()
	host.world_extent = extent
	host.render_channels = channels
	host.render_image_format = Image.FORMAT_R8 if channels == 1 else Image.FORMAT_RG8
	host.image = Image.create_from_data(extent.x, extent.y, false, host.render_image_format,
		_pattern(extent, channels, seed_value))
	host.world_view = TextureRect.new()
	host.world_shader = ShaderMaterial.new()
	host.world_shader.shader = Palette.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	host.world_view.material = host.world_shader
	host.shared_workbench = Control.new()
	host._material_publication_mode = mode
	host.create_render_textures()
	host._bind_material_texture_consumers()
	return host


func _release(host: Control) -> void:
	host.world_view.free()
	host.shared_workbench.free()
	host.free()


func _pattern(extent: Vector2i, channels: int, seed_value: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(extent.x * extent.y * channels)
	for pixel: int in range(extent.x * extent.y):
		data[pixel * channels] = (pixel * 19 + seed_value) % 132
		if channels == 2: data[pixel * channels + 1] = (pixel * 23 + seed_value) % 256
	return data


func _check_gpu(host: Control, current: PackedByteArray, previous: PackedByteArray, label: String) -> void:
	var a: Image = host.texture.get_image()
	var b: Image = host.previous_texture.get_image()
	check(a != null and a.get_size() == host.world_extent and a.get_format() == host.render_image_format
		and a.get_data() == current, label + " current GPU plane exact")
	check(b != null and b.get_size() == host.world_extent and b.get_format() == host.render_image_format
		and b.get_data() == previous, label + " previous GPU plane exact")
	check(host._presentation_current_bytes == current and host._presentation_previous_bytes == previous,
		label + " GPU and safety certificates describe the same bytes")


func _patch(host: Control, area: Rect2i, value: int, condition: int, label: String) -> Dictionary:
	var old: PackedByteArray = host.image.get_data()
	var expected: Image = host.image.duplicate()
	var patch := Image.create(area.size.x, area.size.y, false, host.render_image_format)
	patch.fill(Color(float(value) / 255.0, float(condition) / 255.0, 0.0, 1.0))
	expected.blit_rect(patch, Rect2i(Vector2i.ZERO, area.size), area.position)
	var metadata := PackedInt32Array([area.position.x, area.position.y, area.size.x, area.size.y,
		0, area.size.x * host.render_channels])
	var prior_current_rid: RID = host._material_publication_rid(host.texture)
	var prior_previous_rid: RID = host._material_publication_rid(host.previous_texture)
	check(host.upload_texture_patches(metadata, patch.get_data(), host.last_uploaded_revision + 1,
		host.render_channels), label + " accepted")
	_check_gpu(host, expected.get_data(), old, label)
	check(host._material_publication_rid(host.texture) == prior_previous_rid and
		host._material_publication_rid(host.previous_texture) == prior_current_rid,
		label + " exact bounded drawable pair swapped")
	var result: Dictionary = host.material_publication_status()
	observations.append({"label":label, "publication":result})
	return result


func _occupancy_history_contract() -> void:
	var saved: String = OS.get_environment("CYBERSAND_DIAG_RENDER_CADENCE")
	for mode: String in ["repaired", "legacy"]:
		OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE", mode)
		var host: Control = _host(Vector2i(160, 160), 2, "full")
		host.image.fill(Color(0, 0, 0, 1))
		host.image.set_pixel(10, 8, Color(6.0 / 255.0, 1, 0, 1))
		host.create_render_textures()
		host._bind_material_texture_consumers()
		var before: PackedByteArray = host.image.get_data()
		check(host.upload_texture_patches(PackedInt32Array([9, 8, 3, 1, 0, 6]),
			PackedByteArray([0, 0, 0, 0, 0, 0]), 1, 2), mode + " old-only Fire erase accepted")
		var retained: Image = host._presentation_previous_image
		if mode == "repaired":
			check(retained != null and retained.get_data() == before,
				"retained image preserves exact old material after patch mutation")
			check(host._presentation_previous_occupied.is_empty(),
				"exact image path performs no duplicate legacy occupancy-map work")
		else:
			check(retained == null and host._presentation_previous_occupied.has(8 * 160 + 10),
				"legacy small-patch path still retains old occupied cell")
		check(not host._presentation_previous_unknown, mode + " small history remains known")
		var boxes: Array = [{"center":Vector2(0.5, 0.5), "size":Vector2.ONE}]
		var start := Transform2D(0, Vector2(8, 8))
		var target := Transform2D(0, Vector2(12, 8))
		var active: Dictionary = Clearance.assess(start, target, boxes, host.image,
			host._presentation_previous_occupied, host._presentation_previous_unknown,
			true, Clearance.MAX_SCAN_CELLS, 0, retained)
		var expired: Dictionary = Clearance.assess(start, target, boxes, host.image,
			host._presentation_previous_occupied, host._presentation_previous_unknown,
			false, Clearance.MAX_SCAN_CELLS, 0, retained)
		check(not active.safe and active.reason == "material_in_swept_mask",
			mode + " genuine old-only material still blocks swept motion")
		check(expired.safe, mode + " old-only material stops blocking after blend expiry")
		check(host.upload_texture_patches(host._full_material_rectangle(), host.image.get_data(), 2, 2),
			mode + " oversized full history publication accepted")
		if mode == "legacy":
			check(host._presentation_previous_unknown and host._presentation_previous_image == null,
				"legacy oversized history remains conservatively unknown")
			var unknown: Dictionary = Clearance.assess(start, target, boxes, host.image,
				host._presentation_previous_occupied, true, true)
			check(not unknown.safe and unknown.reason == "previous_texture_unbounded",
				"legacy unknown history cannot silently admit physical presentation")
		else:
			check(not host._presentation_previous_unknown and host._presentation_previous_image != null,
				"exact image remains valid beyond the legacy map capacity")
		_release(host)
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE", saved)


func _history_and_fallback(channels: int) -> void:
	var host: Control = _host(Vector2i(317, 259), channels, "blit", 5)
	check(host.texture is Publisher.MaterialPlane, "graphical production selected blit publication")
	check(host._material_blit_publisher.columns * host._material_blit_publisher.rows <= 256, "dirty tile count within bounded capacity")
	check(host.texture.get_rid() == host.texture.drawable.get_rid(),
		"public texture RID is the actual drawable history")
	_check_gpu(host, host.image.get_data(), host.image.get_data(), "initial NPOT plane")
	var first: Dictionary = _patch(host, Rect2i(63, 63, 2, 2), 6, 251, "four-tile seam")
	check(first.updated_tiles == 4, "a four-tile seam submits exactly four tiles")
	var second: Dictionary = _patch(host, Rect2i(257, 140, 1, 1), 3, 173, "disjoint recycled slot")
	check(second.updated_tiles == 5, "recycled slot restores preceding four tiles and the new tile")
	_patch(host, Rect2i(316, 258, 1, 1), 127, 255, "bottom right padded tile")
	_patch(host, Rect2i(316, 258, 1, 1), 127, 1, "condition-only edit")
	var unchanged: PackedByteArray = host.image.get_data()
	for turn: int in range(2):
		check(host.upload_texture_patches(host._full_material_rectangle(), unchanged,
			host.last_uploaded_revision + 1, channels), "byte-identical full resync accepted")
		_check_gpu(host, unchanged, unchanged, "full resync")
	check(host.material_publication_status().submitted_bytes == 0,
		"resync of two identical slots submits no unchanged tiles")
	var current_id: int = host._presentation_current_content_id
	var previous_id: int = host._presentation_previous_content_id
	for mode: String in ["full", "blit", "full", "blit"]:
		check(host.set_material_publication_mode(mode), "live publication mode switch " + mode)
		_check_gpu(host, unchanged, unchanged, "mode switch " + mode)
		check(host._presentation_current_content_id == current_id
			and host._presentation_previous_content_id == previous_id,
			"mode switch preserves exact content identity")
	_patch(host, Rect2i(0, 0, 1, 1), 19, 99, "post-switch edit")
	var distinct_current: PackedByteArray = host.image.get_data()
	var distinct_previous: PackedByteArray = host._presentation_previous_bytes
	for mode: String in ["full", "blit"]:
		check(host.set_material_publication_mode(mode), "different-history live mode switch "+mode)
		_check_gpu(host, distinct_current, distinct_previous, "different-history mode switch "+mode)
	_patch(host, Rect2i(200, 240, 1, 1), 7, 155, "first recycled slot after different-history switch")
	# A foreign valid drawable must be refused before any copy/ACK. Ownership
	# and shape checks avoid accepting a void backend call that did no work.
	var broken := DrawableTexture2D.new()
	broken.setup(1,1,DrawableTexture2D.DRAWABLE_FORMAT_RGBA8,Color.BLACK,false)
	check(broken.get_rid().is_valid(), "valid-RID wrong-shape adversary constructed")
	host.previous_texture.drawable = broken
	var old: PackedByteArray = host.image.get_data()
	var exact := _pattern(host.world_extent, channels, 19)
	check(host.upload_texture_patches(host._full_material_rectangle(), exact,
		host.last_uploaded_revision + 1, channels), "structurally failed tile path uses full fallback")
	check(host.texture is ImageTexture and host.previous_texture is ImageTexture
		and host.material_publication_status().backend == "full",
		"failure retires both drawable targets and reports full fallback")
	check(not str(host.material_publication_status().fallback_reason).is_empty(),
		"detected fallback reason is observable")
	_check_gpu(host, exact, old, "recovered full update")
	# A corrupted tile size must not submit geometrically different
	# copy coordinates or acknowledge an drawable update using the wrong map.
	check(host.set_material_publication_mode("blit"), "size adversary restores a valid drawable pair")
	host._material_blit_publisher.tile_side -= 1
	var invalid_old: PackedByteArray = host.image.get_data()
	var invalid_new := _pattern(host.world_extent, channels, 31)
	var invalid_revision: int = host.last_uploaded_revision + 1
	check(host.upload_texture_patches(host._full_material_rectangle(), invalid_new,
		invalid_revision, channels), "non-power-of-two tile side recovers through full publication")
	check(host.texture is ImageTexture and host.previous_texture is ImageTexture,
		"invalid address mapping retires both drawable resources")
	check(host.last_uploaded_revision == invalid_revision,
		"fallback acknowledges the actual full publication revision")
	_check_gpu(host, invalid_new, invalid_old, "recovered invalid tile side")
	var retired_content: int = host._presentation_current_content_id
	host.world_extent = Vector2i(129, 71)
	host.image = Image.create_from_data(129, 71, false, host.render_image_format,
		_pattern(host.world_extent, channels, 43))
	host._material_publication_mode = "blit"
	host.create_render_textures()
	host._bind_material_texture_consumers()
	check(host.texture is Publisher.MaterialPlane and host._material_blit_publisher.columns * host._material_blit_publisher.rows == 6,
		"World replacement creates a bounded pair for the new extent")
	check(host._presentation_current_content_id > retired_content,
		"World replacement never recycles material content identities")
	_check_gpu(host, host.image.get_data(), host.image.get_data(), "resized World replacement")
	_patch(host, Rect2i(128, 70, 1, 1), 6, 255, "edit after World replacement")
	_release(host)
	histories_completed += 1


func _owner_and_format_contract(channels: int) -> void:
	var extent := Vector2i(33,19)
	var format: Image.Format = Image.FORMAT_R8 if channels == 1 else Image.FORMAT_RG8
	var current_bytes := PackedByteArray()
	var previous_bytes := PackedByteArray()
	current_bytes.resize(extent.x*extent.y*channels)
	previous_bytes.resize(current_bytes.size())
	for index: int in range(current_bytes.size()):
		current_bytes[index] = index%256
		previous_bytes[index] = 255-index%256
	var current := Image.create_from_data(extent.x,extent.y,false,format,current_bytes)
	var previous := Image.create_from_data(extent.x,extent.y,false,format,previous_bytes)
	var publisher: Publisher = Publisher.create_pair(current,previous)
	check(publisher != null, "all-byte distinct-history factory accepted")
	if publisher == null: return
	check(publisher.current.get_image().get_data() == current_bytes
		and publisher.previous.get_image().get_data() == previous_bytes,
		"every 0..255 logical material/condition byte survives GPU copies in both histories")
	var physical: Image = publisher.current.drawable.get_image()
	check(physical.get_format() == Image.FORMAT_RGBA8 and not physical.has_mipmaps(),
		"actual GPU storage is linear RGBA8 without mipmaps")
	var rgba: PackedByteArray = physical.get_data()
	var exact_padding: bool = true
	for pixel: int in range(extent.x*extent.y):
		if rgba[pixel*4+2] != 0 or rgba[pixel*4+3] != 255 \
				or (channels == 1 and rgba[pixel*4+1] != 0): exact_padding = false
	check(exact_padding, "copy shader writes exact RG/zero/opaque channels without blending")
	var resources: Array[int] = publisher.resource_identity()
	var ids: Array[RID] = [publisher.current.get_rid(),publisher.previous.get_rid()]
	var changed: Image = current.duplicate()
	changed.set_pixel(32,18,Color(2.0/255.0,3.0/255.0,0,1))
	var areas: Array[Rect2i] = [Rect2i(32,18,1,1)]
	check(publisher.publish(changed,areas), "first sparse publication after distinct-history factory accepted")
	check(publisher.current.get_image().get_data() == changed.get_data()
		and publisher.previous.get_image().get_data() == current_bytes,
		"new sparse update reconciles all inherited previous-history differences")
	check(publisher.current.get_rid() == ids[1] and publisher.previous.get_rid() == ids[0]
		and publisher.resource_identity() == resources, "pair rotates while all bounded GPU resources remain stable")
	var before: PackedByteArray = publisher.current.get_image().get_data()
	var side: int = publisher.tile_side
	publisher.tile_side = 0
	check(not publisher.publish(changed,areas), "zero tile side refused before division")
	publisher.tile_side = side
	var columns: int = publisher.columns
	publisher.columns += 1
	check(not publisher.publish(changed,areas), "invalid tile layout refused before dirty indexing")
	publisher.columns = columns
	var pending: PackedByteArray = publisher.previous.pending
	publisher.previous.pending = PackedByteArray()
	check(not publisher.publish(changed,areas), "invalid pending capacity refused before dirty indexing")
	publisher.previous.pending = pending
	var sink: DrawableTexture2D = publisher.retirement_sink
	publisher.retirement_sink = publisher.current.drawable
	check(not publisher.publish(changed,areas), "history cannot become the retirement sink")
	publisher.retirement_sink = sink
	var target: DrawableTexture2D = publisher.previous.drawable
	var foreign := DrawableTexture2D.new()
	foreign.setup(extent.x,extent.y,DrawableTexture2D.DRAWABLE_FORMAT_RGBA8_SRGB,Color.BLACK,false)
	publisher.previous.drawable = foreign
	check(not publisher.publish(changed,areas), "foreign valid-RID SRGB target is refused")
	publisher.previous.drawable = target
	var stage: ImageTexture = publisher.staging[1]
	publisher.staging[1] = ImageTexture.create_from_image(Image.create(side,side,false,format))
	check(not publisher.publish(changed,areas), "foreign staging allocation is refused")
	publisher.staging[1] = stage
	check(publisher.current.get_image().get_data() == before
		and publisher.resource_identity() == resources, "rejected mutations leave actual histories and owned resources unchanged")
	check(publisher.current.update(previous), "legacy direct texture update routes through the same exact GPU copy")
	check(publisher.current.get_image().get_data() == previous_bytes,
		"legacy update exposes actual updated GPU material bytes")
	var retained: Texture2D = publisher.current
	var owner: WeakRef = weakref(publisher)
	publisher = null
	check(owner.get_ref() == null, "retained public texture does not keep publisher/staging alive")
	check(retained.get_image().get_data() == previous_bytes,
		"retained public texture independently owns its actual drawable history")
	check(not retained.update(current), "texture refuses updates after its publisher retires")


func _large_sparse_transfer() -> void:
	var host: Control = _host(Vector2i(2048, 2048), 2, "blit")
	check(host._material_blit_publisher.tile_side == 128 and host._material_blit_publisher.columns * host._material_blit_publisher.rows == 256,
		"2048² RG8 uses 128² tiles and 256 bounded tile records")
	var resources: Array[int] = host._material_blit_publisher.resource_identity()
	check(host._material_blit_publisher.gpu_storage_bytes() == 44728324, "2048² fixed RGBA8 histories and RG8 stages allocate 44,728,324 bytes")
	var result: Dictionary = _patch(host, Rect2i(1023, 1024, 1, 1), 3, 77, "2048² single cell")
	check(result.gpu_blit_calls == 1 and result.retirement_blit_calls == 1, "sparse copy includes bounded retirement draw")
	check(result.updated_tiles == 1 and result.submitted_bytes == 32768,
		"single changed cell submits 32KiB instead of complete 8MiB plane")
	var old: PackedByteArray = host.image.get_data()
	var prior_current: RID = host._material_publication_rid(host.texture)
	var prior_previous: RID = host._material_publication_rid(host.previous_texture)
	var dense: PackedByteArray = _pattern(host.world_extent, 2, 77)
	var started: int = Time.get_ticks_usec()
	check(host.upload_texture_patches(host._full_material_rectangle(), dense, 2, 2),
		"dense 2048² RG8 full refresh accepted")
	var elapsed: int = Time.get_ticks_usec() - started
	_check_gpu(host, dense, old, "dense 2048² full refresh")
	result = host.material_publication_status()
	check(result.gpu_blit_calls == 1 and result.retirement_blit_calls == 1 and result.whole_gpu_copy, "dense update uses one full GPU copy and one retirement draw")
	check(resources == host._material_blit_publisher.resource_identity(), "dense and sparse updates allocate no new GPU resources")
	check(result.estimated_target_write_bytes == 16777216 and result.gpu_storage_format == "RGBA8_LINEAR", "physical RGBA writes reported separately from logical RG staging bytes")
	check(result.updated_tiles == 256 and result.submitted_bytes == 8388608,
		"dense 2048² refresh submits all 256 tiles and exactly 8MiB")
	check(host._material_publication_rid(host.texture) == prior_previous
		and host._material_publication_rid(host.previous_texture) == prior_current,
		"dense full refresh retains the bounded drawable pair")
	observations.append({"label":"dense 2048² full refresh", "elapsed_usec":elapsed,
		"publication":result})
	_release(host)
	large_completed = true


func _view(host: Control, shader_path: String, blend: float) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(193, 129)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rectangle: Control
	if shader_path.ends_with("material_palette.gdshader"):
		var terrain := TextureRect.new()
		terrain.texture = host.texture
		terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		terrain.stretch_mode = TextureRect.STRETCH_SCALE
		rectangle = terrain
	else:
		# Production effects/masks are ColorRects. Binding the same full
		# texture as a default-linear Canvas TEXTURE and a nearest uniform
		# contaminates GLES texture state and fabricates blended material IDs.
		var effect := ColorRect.new()
		effect.color = Color.WHITE
		rectangle = effect
	rectangle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rectangle.size = Vector2(viewport.size)
	var material := ShaderMaterial.new()
	var source: Shader = load(shader_path)
	material.shader = Palette.for_current_renderer(source) if shader_path.ends_with("material_palette.gdshader") else source
	rectangle.material = material
	if shader_path.ends_with("blacksite_nine_grade.gdshader"):
		# blend_mul needs a visible underlay; multiplying transparent clear
		# would make two broken/unexercised grade paths look equally correct.
		var underlay := ColorRect.new()
		underlay.color = Color.WHITE
		underlay.size = Vector2(viewport.size)
		viewport.add_child(underlay)
	viewport.add_child(rectangle)
	host.configure_material_textures(material)
	host.configure_material_textures(material, true)
	material.set_shader_parameter("world_size_px", Vector2(host.world_extent))
	material.set_shader_parameter("view_size_px", Vector2(host.world_extent) + Vector2(7, 9))
	material.set_shader_parameter("camera_origin_px", Vector2(-3.25, -2.75))
	material.set_shader_parameter("player_origin_px", Vector2(-2000, -2000))
	material.set_shader_parameter("snapshot_blend", blend)
	material.set_shader_parameter("presentation_time_override", 12.25)
	material.set_shader_parameter("condition_projection_enabled", 1.0)
	material.set_shader_parameter("material_lut", Appearance.create_texture())
	material.set_shader_parameter("material_program_lut", Appearance.create_program_texture())
	material.set_shader_parameter("delta_seconds", 0.0)
	return viewport


func _shader_equivalence() -> bool:
	var blit: Control = _host(Vector2i(317, 259), 2, "blit", 0)
	var full: Control = _host(Vector2i(317, 259), 2, "full", 0)
	var previous := Image.create_from_data(317, 259, false, Image.FORMAT_RG8,
		_pattern(blit.world_extent, 2, 0))
	var current := Image.create_from_data(317, 259, false, Image.FORMAT_RG8,
		_pattern(blit.world_extent, 2, 31))
	for plane: Image in [previous, current]:
		# Backdrops require common Empty material, while crossfades also need
		# old-only/current-only cells. These regions cross actual staging tile seams.
		plane.fill_rect(Rect2i(16, 16, 90, 90), Color(0, 0, 0, 1))
	previous.fill_rect(Rect2i(63, 12, 8, 10), Color(6.0 / 255.0, 1.0, 0, 1))
	current.fill_rect(Rect2i(63, 12, 8, 10), Color(0, 0, 0, 1))
	previous.fill_rect(Rect2i(12, 63, 10, 8), Color(0, 0, 0, 1))
	current.fill_rect(Rect2i(12, 63, 10, 8), Color(6.0 / 255.0, 0.75, 0, 1))
	for host: Control in [blit, full]:
		check(host.upload_texture_patches(host._full_material_rectangle(), previous.get_data(), 1, 2),
			"nonvacuous previous shader plane published")
		check(host.upload_texture_patches(host._full_material_rectangle(), current.get_data(), 2, 2),
			"different current/previous shader planes published")
	for filename: String in ["material_palette", "material_emission", "material_vapour_trail",
			"blacksite_nine_backdrop", "blacksite_nine_grade", "neon_reliquary_backdrop"]:
		var blends: Array = [0.0, 0.37, 1.0] if filename == "material_palette" else [0.37]
		for blend: float in blends:
			var a: SubViewport = _view(full, "res://shaders/" + filename + ".gdshader", blend)
			var b: SubViewport = _view(blit, "res://shaders/" + filename + ".gdshader", blend)
			await process_frame
			await RenderingServer.frame_post_draw
			var expected: Image = a.get_texture().get_image()
			var actual: Image = b.get_texture().get_image()
			if expected != null and actual != null and expected.get_data() != actual.get_data():
				var artifact_dir: String = OS.get_environment("CYBERSAND_MATERIAL_TILE_OUTPUT").get_base_dir()
				if not artifact_dir.is_empty():
					expected.save_png(artifact_dir.path_join(filename + "-full.png"))
					actual.save_png(artifact_dir.path_join(filename + "-blit.png"))
			check(_nontrivial_pixels(expected),
				"shader oracle draws nontrivial visible content: " + filename)
			check(expected != null and actual != null and expected.get_data() == actual.get_data(),
				"exact full/blit shader pixels: %s blend %.2f" % [filename, blend])
			shader_pairs_completed += 1
			observations.append({"shader":filename, "blend":blend,
				"full_sha256":_sha(expected.get_data()),
				"blit_sha256":_sha(actual.get_data())})
			a.queue_free()
			b.queue_free()
			await process_frame
	_release(full)
	_release(blit)
	return true


func _nontrivial_pixels(source: Image) -> bool:
	if source == null or source.is_empty(): return false
	var converted: Image = source.duplicate()
	converted.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = converted.get_data()
	var first: PackedByteArray = bytes.slice(0, 4)
	var different: bool = false
	var visible_colour: bool = false
	for index: int in range(0, bytes.size(), 4):
		if bytes[index] != first[0] or bytes[index + 1] != first[1] \
				or bytes[index + 2] != first[2] or bytes[index + 3] != first[3]: different = true
		if bytes[index + 3] > 0 and bytes[index] + bytes[index + 1] + bytes[index + 2] > 0:
			visible_colour = true
		if different and visible_colour: return true
	return false


func _sha(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _run() -> void:
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE", "repaired")
	_occupancy_history_contract()
	if DisplayServer.get_name() == "headless":
		var host: Control = _host(Vector2i(73, 65), 2, "blit")
		check(host.texture is ImageTexture and host.previous_texture is ImageTexture,
			"unsupported driver deterministically uses verified full pair")
		check(not str(host.material_publication_status().fallback_reason).is_empty(), "fallback explained")
		_release(host)
	else:
		for channels: int in [1, 2]:
			_history_and_fallback(channels)
			_owner_and_format_contract(channels)
		_large_sparse_transfer()
		check(histories_completed == 2 and large_completed, "all history and transfer tests reached completion")
		check(await _shader_equivalence() == true and shader_pairs_completed == 8, "all shader comparisons reached completion")
	var report := {"godot":Engine.get_version_info(), "display":DisplayServer.get_name(),
		"driver":RenderingServer.get_current_rendering_driver_name(),
		"assertions":assertions, "failures":failures, "observations":observations,
		"scope":("Unsupported/headless driver full fallback only; graphical cases not run." if DisplayServer.get_name() == "headless"
			else "Actual GPU drawable readback and production shader equality; no physical GPU acceptance.")}
	var output: String = OS.get_environment("CYBERSAND_MATERIAL_TILE_OUTPUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		check(file != null, "output opened")
		if file != null:
			report["assertions"] = assertions
			report["failures"] = failures
			file.store_string(JSON.stringify(report, "\t"))
	print("MATERIAL_TILE_PUBLICATION: %d assertions, %d failures" % [assertions, failures])
	quit(failures)
