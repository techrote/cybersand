extends SceneTree

## The #651 2-dense/10-sparse, 2048-square RG8 input sequence through the
## production Main publisher. The native and Rapier owners are measured by
## the separate mounted Workbench scenarios in the same campaign.
const Main = preload("res://scripts/main.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const Case := "transition_2048_w1"
const Extent := Vector2i(2048, 2048)
const Channels := 2
const Warmup := 30
const Samples := 180

var host: Control
var frames: Array[Dictionary] = []
var failures: Array[String] = []
var output: String
var strategy: String
var initialized_usec: int
var initial_sha: String
var steady_sparse: bool
var fixed_material: bool


func _initialize() -> void:
	initialized_usec = Time.get_ticks_usec()
	Engine.max_fps = 0
	steady_sparse = OS.get_environment("CYBERSAND_PUBPRES_PROBE_STEADY_SPARSE") == "1"
	fixed_material = OS.get_environment("CYBERSAND_PUBPRES_PROBE_FIXED_MATERIAL") == "1"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt="):
			output = arg.trim_prefix("--receipt=")
		if arg.begins_with("--material="):
			strategy = arg.trim_prefix("--material=")
	if output.is_empty() or strategy not in ["full", "blit"] or DisplayServer.get_name() == "headless":
		push_error("PUBPRES_TRANSITION requires a graphical process, publication strategy and evidence path")
		quit(2)
		return
	_run.call_deferred()


func _check(value: bool, reason: String) -> bool:
	if not value:
		failures.append(reason)
	return value


func _input(index: int) -> Dictionary:
	var dense := not steady_sparse and index % 12 < 2
	var region := Rect2i(Vector2i.ZERO, Extent) if dense else Rect2i(96, 96, 8, 8)
	var patch := Image.create_empty(region.size.x, region.size.y, false, Image.FORMAT_RG8)
	var material_id := 3 if index % 2 == 0 and not (fixed_material and dense) else 58
	patch.fill(Color(float(material_id) / 255.0, float((index * 37) % 256) / 255.0, 0, 1))
	return {"dense": dense, "region": region, "patch": patch}


func _initial_plane() -> Image:
	var plane := Image.create_empty(Extent.x, Extent.y, false, Image.FORMAT_RG8)
	if steady_sparse:
		# Match the off-patch substrate at the start of transition timing.
		# The most recent dense generation at sample zero is sequence 25.
		plane.fill(Color8(58, (25 * 37) % 256, 0))
	else:
		for y: int in range(8, Extent.y, 64):
			plane.fill_rect(Rect2i(0, y, Extent.x, 16), Color(58.0 / 255.0, 0, 0, 1))
	return plane


func _build_host() -> void:
	host = Main.new()
	host.world_extent = Extent
	host.render_channels = Channels
	host.render_image_format = Image.FORMAT_RG8
	host.image = _initial_plane()
	initial_sha = _hash(host.image.get_data())
	host.world_view = TextureRect.new()
	host.world_view.size = Vector2(640, 360)
	host.world_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.world_view.stretch_mode = TextureRect.STRETCH_SCALE
	host.world_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.world_shader = ShaderMaterial.new()
	host.world_shader.shader = CyberPaletteShader.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	host.world_view.material = host.world_shader
	host.current_view_size = Vector2i(320, 180)
	host.create_render_textures()
	host.world_view.texture = host.texture
	var uniforms := {"world_size_px": Vector2(Extent), "view_size_px": Vector2(320, 180),
		"view_rect_uv": Vector4(0, 0, 1, 1), "camera_origin_px": Vector2(32, 32),
		"player_origin_px": Vector2(-1000, -1000), "condition_projection_enabled": 1.0,
		"presentation_time_override": 4.0, "snapshot_blend": 1.0,
		"current_world_texture": host.texture, "previous_world_texture": host.previous_texture,
		"material_lut": CyberMaterialAppearanceLut.create_texture(),
		"material_program_lut": CyberMaterialAppearanceLut.create_program_texture()}
	for key: String in uniforms:
		host.world_shader.set_shader_parameter(key, uniforms[key])
	root.add_child(host.world_view)


func _hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _publication_status() -> Dictionary:
	if host.has_method("material_publication_status"):
		return host.call("material_publication_status")
	# Accepted main predates publication telemetry. Observe its real texture
	# classes; do not substitute a newer renderer into the reference source.
	_check(strategy == "full" and host.texture is ImageTexture and host.previous_texture is ImageTexture,
		"legacy source did not use its complete ImageTexture history pair")
	return {"requested_mode": strategy, "backend": "full", "policy": "", "fallback_reason": "",
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"submitted_bytes": Extent.x * Extent.y * Channels,
		"observation_scope": "Legacy finish_texture_upload rotates two ImageTextures and calls one complete update; stage timing unavailable."}


func _submit(index: int) -> Dictionary:
	var input := _input(index)
	var region: Rect2i = input.region
	var patch: Image = input.patch
	var bytes := patch.get_data()
	var started := Time.get_ticks_usec()
	var accepted: bool = host.upload_texture_patches(PackedInt32Array([
		region.position.x, region.position.y, region.size.x, region.size.y, 0, region.size.x * Channels]),
		bytes, index + 1, Channels)
	var completed := Time.get_ticks_usec()
	_check(accepted and host.last_uploaded_revision == index + 1, "publication %d was not accepted" % index)
	host.world_shader.set_shader_parameter("snapshot_blend", 0.5 if index % 3 == 0 else 1.0)
	var status: Dictionary = _publication_status()
	_check(status.get("requested_mode") == strategy, "publication strategy did not reach Main")
	var phase := "sparse"
	if not steady_sparse:
		match index % 12:
			0: phase = "enter_dense"
			1: phase = "dense"
			2: phase = "enter_sparse"
	return {"sample": index - Warmup, "sequence": index, "dense": input.dense,
		"phase": phase, "accepted_revision": host.last_uploaded_revision, "accepted": accepted,
		"patch_bytes": bytes.size(), "publish_begin_usec": started, "publish_end_usec": completed,
		"publication_ms": float(completed - started) / 1000.0, "material": status}


func _check_history() -> Dictionary:
	# Build the expected final pair independently from the most recent full
	# patch onward. Readback and PNG encoding are outside the sample window.
	var final_index := Warmup + Samples - 1
	var first := -1 if steady_sparse else final_index - final_index % 12
	var expected: Image = _initial_plane() if steady_sparse else _input(first).patch
	var expected_previous: PackedByteArray
	for index: int in range(first + 1, final_index + 1):
		var input := _input(index)
		var region: Rect2i = input.region
		if index == final_index:
			expected_previous = expected.get_data()
		expected.blit_rect(input.patch, Rect2i(Vector2i.ZERO, region.size), region.position)
	var expected_current := expected.get_data()
	var current: Image = host.texture.get_image()
	var previous: Image = host.previous_texture.get_image()
	if not _check(current != null and previous != null, "could not read both material history textures"):
		return {}
	current.convert(Image.FORMAT_RG8)
	previous.convert(Image.FORMAT_RG8)
	var current_matches := current.get_size() == Extent and current.get_data() == expected_current
	var previous_matches := previous.get_size() == Extent and previous.get_data() == expected_previous
	_check(current_matches and previous_matches, "final GPU history differs from the exact independent sequence")
	_check(host.image.get_data() == expected_current, "final CPU plane differs from independent sequence")
	return {"current_matches": current_matches, "previous_matches": previous_matches,
		"current_sha256": _hash(current.get_data()), "previous_sha256": _hash(previous.get_data())}


func _run() -> void:
	root.size = Vector2i(960, 720)
	RenderingServer.call_on_render_thread(Callable(DisplayServer, "window_set_vsync_mode").bind(DisplayServer.VSYNC_DISABLED))
	_build_host()
	await RenderingServer.frame_post_draw
	var vsync := DisplayServer.window_get_vsync_mode()
	_check(vsync == DisplayServer.VSYNC_DISABLED, "could not match the donor's uncapped transition display")
	var preparation_usec := Time.get_ticks_usec() - initialized_usec
	var previous_frame_usec := Time.get_ticks_usec()
	for index: int in range(Warmup + Samples):
		var row := _submit(index)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if index >= Warmup:
			row["frame_ms"] = float(now - previous_frame_usec) / 1000.0
			row["post_draw_usec"] = now
			row["godot_static_memory_peak_bytes"] = OS.get_static_memory_peak_usage()
			var video_bytes := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
			row["reported_video_memory_bytes"] = video_bytes if video_bytes > 0 else null
			frames.append(row)
		previous_frame_usec = now
	var history := _check_history()
	var screenshot := root.get_texture().get_image()
	var screenshot_path := output.trim_suffix(".json") + "-after.png"
	var screenshot_sha := ""
	if _check(screenshot != null and not screenshot.is_empty(), "missing original framebuffer"):
		if _check(screenshot.save_png(screenshot_path) == OK, "could not save original framebuffer"):
			screenshot_sha = FileAccess.get_sha256(screenshot_path)
	var result := {"schema": "pubpres-transition-v1", "case": Case, "complete": failures.is_empty(),
		"tape": "steady_sparse" if steady_sparse else ("fixed_material" if fixed_material else "transition"),
		"failures": failures, "material_strategy": strategy, "context": Context.identity(get_script().resource_path, host.world_shader.shader),
		"application_main_sha256": FileAccess.get_sha256("res://scripts/main.gd"),
		"initial_plane_sha256": initial_sha, "setup_usec": preparation_usec, "warmup_frames": Warmup,
		"display": {"window": [root.size.x, root.size.y], "max_fps": Engine.max_fps, "vsync_mode": vsync},
		"size": [Extent.x, Extent.y], "channels": Channels, "samples": frames, "history": history,
		"screenshot_sha256": screenshot_sha, "scope": "Detached production Main renderer seam. Measures publication and post-draw intervals. No native or Rapier owner runs in this lane."}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("PUBPRES_TRANSITION could not write receipt")
		quit(2)
		return
	file.store_string(JSON.stringify(result) + "\n")
	file.close()
	host.world_view.free()
	host.free()
	quit(int(not failures.is_empty()))
