extends SceneTree
# Genuine Godot framebuffer capture of external provisional world-design packs.
# Reuses the production palette, material LUT, emission and glow shaders exactly.
# Does NOT run World/physics, infer simulation conditions, or modify any pack.
#
# godot --path godot --script res://tools/capture_world_design_pack.gd -- \
#   --pack=/absolute/pack.json --output=/absolute/captures --mode=both \
#   --scale=2 --time=1.37 --glow=on --design-revision=<exact SHA>
#
# Output includes actual readback PNGs, native RG8 inputs and a success-only
# manifest; errors print machine-readable status and exit with a nonzero code.

const Adapter = preload("res://tools/world_design_pack_adapter.gd")
const BACKGROUND: Color = Color(0.031, 0.043, 0.071, 1.0)
const PAD_CELLS: int = 32 # More than the glow/emission footprint at tile seams.
const DEFAULT_TILE_CELLS: int = 512

var pack_path: String = ""
var output_path: String = ""
var mode: String = "both"
var scale: int = 2
var presentation_time: float = 1.37
var glow_enabled: bool = true
var tile_cells: int = DEFAULT_TILE_CELLS
var design_revision: String = ""
var max_working_mib: int = 256
var require_verified_source: bool = false
var test_fail_publication: bool = false
var test_pause_before_publication_ms: int = 0
var attempt_id: String = ""
var staging_path: String = ""
var manifest: Dictionary = {}
var resource_budget: Dictionary = {}
var palette_selection: Dictionary = {}
var palette_shader: Shader
var emission_shader: Shader
var composite_shader: Shader
var palette_lut: ImageTexture
var program_lut: ImageTexture


func _init() -> void:
	call_deferred("_run")


func _parse_arguments() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="):
			pack_path = argument.trim_prefix("--pack=")
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--scale="):
			var number: String = argument.trim_prefix("--scale=")
			if not number.is_valid_int():
				return "--scale requires an integer"
			scale = int(number)
		elif argument.begins_with("--time="):
			var number: String = argument.trim_prefix("--time=")
			if not number.is_valid_float():
				return "--time requires a finite number"
			presentation_time = float(number)
		elif argument.begins_with("--glow="):
			var value: String = argument.trim_prefix("--glow=")
			if value != "on" and value != "off":
				return "--glow must be on or off"
			glow_enabled = value == "on"
		elif argument.begins_with("--tile-cells="):
			var number: String = argument.trim_prefix("--tile-cells=")
			if not number.is_valid_int():
				return "--tile-cells requires an integer"
			tile_cells = int(number)
		elif argument.begins_with("--design-revision="):
			design_revision = argument.trim_prefix("--design-revision=")
		elif argument.begins_with("--max-working-mib="):
			var number: String = argument.trim_prefix("--max-working-mib=")
			if not number.is_valid_int():
				return "--max-working-mib requires an integer"
			max_working_mib = int(number)
		elif argument.begins_with("--require-verified-source="):
			var value: String = argument.trim_prefix("--require-verified-source=")
			if value not in ["on", "off"]:
				return "--require-verified-source must be on or off"
			require_verified_source = value == "on"
		elif argument == "--test-fail-publication=on":
			if OS.get_environment("CYBERSAND_CAPTURE_FAULT_INJECTION") != "1":
				return "publication fault injection requires explicit test environment"
			test_fail_publication = true
		elif argument.begins_with("--test-pause-before-publication-ms="):
			if OS.get_environment("CYBERSAND_CAPTURE_FAULT_INJECTION") != "1":
				return "publication pause injection requires explicit test environment"
			var number: String = argument.trim_prefix("--test-pause-before-publication-ms=")
			if not number.is_valid_int() or int(number) < 1 or int(number) > 30000:
				return "test pause must be between 1 and 30000 milliseconds"
			test_pause_before_publication_ms = int(number)
		else:
			return "unknown argument: " + argument
	if pack_path.is_empty() or output_path.is_empty():
		return "explicit --pack and --output are required"
	if not pack_path.is_absolute_path():
		return "--pack must be absolute"
	if max_working_mib < 16 or max_working_mib > Adapter.MAX_BUDGET_MIB:
		return "--max-working-mib must be within 16..1024"
	if not (mode in ["both", "combined", "individual"]):
		return "--mode must be both, combined or individual"
	if scale < 1 or scale > 8:
		return "--scale must be between 1 and 8"
	if is_nan(presentation_time) or is_inf(presentation_time) or presentation_time < 0.0:
		return "--time must be finite and nonnegative"
	if tile_cells < 64 or tile_cells > 2048 or tile_cells % 2 != 0 or (tile_cells + PAD_CELLS * 2) * scale > 8192:
		return "--tile-cells must be even (64..2048), with padded view <=8192 pixels"
	if not output_path.is_absolute_path():
		return "--output must be an absolute directory"
	var source_dir: String = pack_path.get_base_dir().simplify_path()
	var destination: String = output_path.simplify_path()
	if destination == source_dir or destination.begins_with(source_dir + "/"):
		return "--output must not be inside the input pack's source directory"
	return ""


# Resolve the target before validating later options (notably --scale). A bad
# second invocation MUST invalidate the previous manifest for that target.
# No data outside the declared capture output is removed.
func _prepare_target() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--pack="):
			pack_path = argument.trim_prefix("--pack=")
	if output_path.is_empty() or not output_path.is_absolute_path():
		return "cannot identify an absolute --output target"
	if pack_path.is_empty() or not pack_path.is_absolute_path():
		return "cannot identify an absolute --pack source"
	var source_dir: String = pack_path.get_base_dir().simplify_path()
	var destination: String = output_path.simplify_path()
	if destination == source_dir or destination.begins_with(source_dir + "/"):
		return "--output must not be inside the input pack's source directory"
	if destination == "/" or destination == "C:/" or destination == "C:\\":
		return "--output must not be a filesystem root"
	output_path = destination
	if DirAccess.make_dir_recursive_absolute(output_path) != OK:
		return "cannot create output directory"
	attempt_id = "%d-%d" % [Time.get_ticks_usec(), randi()]
	var previous: String = output_path.path_join("capture-manifest.json")
	if FileAccess.file_exists(previous) and DirAccess.remove_absolute(previous) != OK:
		return "cannot invalidate previous success manifest"
	if not _write_json(output_path.path_join("capture-status.json"),
		{"status": "running", "success": false, "attempt_id": attempt_id,
			"message": "new attempt invalidated any earlier success marker"}):
		return "cannot publish running attempt status"
	return ""


func _status(code: int, error: String) -> void:
	var result: Dictionary = {"status": "failed" if code != 0 else "complete",
		"success": code == 0, "exit_code": code, "attempt_id": attempt_id,
		"message": error}
	print("WORLD_DESIGN_CAPTURE ", JSON.stringify(result))
	if code != 0:
		if not output_path.is_empty() and output_path.is_absolute_path() and DirAccess.dir_exists_absolute(output_path):
			_write_json(output_path.path_join("capture-status.json"), result)
		if not staging_path.is_empty() and DirAccess.dir_exists_absolute(staging_path):
			# A publication failure may occur after the success manifest was
			# written but before the directory rename. The uncommitted sibling
			# must never retain a misleading complete-success marker.
			var unpublished: String = staging_path.path_join("capture-manifest.json")
			if FileAccess.file_exists(unpublished):
				if DirAccess.remove_absolute(unpublished) != OK:
					push_error("failed to invalidate uncommitted staging manifest: " + unpublished)
			_write_json(staging_path.path_join("capture-status.json"), result)
	quit(code)


func _write_json(path: String, value: Variant) -> bool:
	var temp: String = path + ".pending"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return false
	return DirAccess.rename_absolute(temp, path) == OK


func _save_png(image: Image, relative: String, category: String, extra: Dictionary = {}) -> bool:
	var absolute: String = staging_path.path_join(relative)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	if image == null or image.is_empty() or image.save_png(absolute) != OK:
		return false
	var entry: Dictionary = {"file": relative, "kind": category,
		"size": [image.get_width(), image.get_height()],
		"bytes": FileAccess.get_file_as_bytes(absolute).size(),
		"sha256": FileAccess.get_sha256(absolute),
		"provenance": "Godot SubViewport framebuffer readback"}
	entry.merge(extra, true)
	manifest.captures.append(entry)
	return true


func _save_input(input: Dictionary, relative: String) -> bool:
	var absolute: String = staging_path.path_join(relative)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var file: FileAccess = FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(input.data)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_sha256(absolute) != input.rg8_sha256:
		return false
	manifest.inputs.append({"file": relative, "format": "Image.FORMAT_RG8",
		"size": [input["size"].x, input["size"].y], "bytes": input.rg8_bytes,
		"sha256": input.rg8_sha256, "condition_policy": "synthetic_native_initial",
		"geometry": input.geometry})
	return true


func _read_pack() -> Dictionary:
	if not FileAccess.file_exists(pack_path):
		return {"ok": false, "error": "pack not found: " + pack_path}
	var content: String = FileAccess.get_file_as_string(pack_path)
	var parser: JSON = JSON.new()
	var code: Error = parser.parse(content)
	if code != OK:
		return {"ok": false, "error": "invalid pack JSON line %d: %s" % [
			parser.get_error_line(), parser.get_error_message()]}
	var info: Dictionary = Adapter.inspect(parser.data)
	if not info.ok:
		return info
	return {"ok": true, "pack": parser.data, "info": info,
		"sha256": FileAccess.get_sha256(pack_path)}


func _load_shaders() -> bool:
	var original_palette: Shader = load("res://shaders/material_palette.gdshader")
	if original_palette == null:
		return false
	palette_shader = CyberPaletteShader.for_current_renderer(original_palette)
	palette_selection = CyberPaletteShader.provenance(palette_shader)
	if not palette_selection.get("source_bound", false) or not palette_selection.get("source_file_bound", false):
		return false
	emission_shader = load("res://shaders/material_emission.gdshader")
	composite_shader = load("res://shaders/glow_composite.gdshader")
	if palette_shader == null or emission_shader == null or composite_shader == null:
		return false
	palette_lut = CyberMaterialAppearanceLut.create_texture()
	program_lut = CyberMaterialAppearanceLut.create_program_texture()
	if palette_lut == null or program_lut == null:
		return false
	return true



# Best-effort Git checkout identity is separate from caller-supplied strings.
# An exported pack outside Git still has a verified content SHA-256.
func _source_identity() -> Dictionary:
	var declared: String = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	var checkout: String = ""
	var clean: bool = false
	var root_path: String = ProjectSettings.globalize_path("res://").get_base_dir()
	var result: Array = []
	var code: int = OS.execute("git", PackedStringArray([
		"-C", root_path, "rev-parse", "--verify", "HEAD"]), result, true)
	if code == 0 and result.size() > 0:
		var value: String = str(result[0]).strip_edges()
		if value.length() == 40 and value.is_valid_hex_number():
			checkout = value
	if not checkout.is_empty():
		result.clear()
		code = OS.execute("git", PackedStringArray([
			"-C", root_path, "status", "--porcelain", "--untracked-files=no",
			"--", "godot/tools", "godot/shaders", "godot/scripts"]), result, true)
		clean = code == 0 and (result.is_empty() or str(result[0]).strip_edges().is_empty())
	return {"source_revision_declared": declared,
		"verified_source_revision": checkout if clean else "",
		"git_checkout_head": checkout,
		"capture_source_tree_clean": clean,
		"declared_matches_verified": clean and not declared.is_empty() and declared == checkout,
		"source_verification": "clean Git checkout for capture tool/shaders/scripts" if clean else "unverified working source"}


func _create_stage() -> bool:
	staging_path = output_path + ".world-capture-stage-" + attempt_id
	if DirAccess.dir_exists_absolute(staging_path) or FileAccess.file_exists(staging_path):
		return false
	return DirAccess.make_dir_absolute(staging_path) == OK


func _verify_staging() -> bool:
	for entry: Dictionary in manifest.inputs + manifest.captures:
		var path: String = staging_path.path_join(str(entry["file"]))
		if not FileAccess.file_exists(path):
			return false
		if FileAccess.get_sha256(path) != entry["sha256"]:
			return false
		if FileAccess.get_file_as_bytes(path).size() != int(entry["bytes"]):
			return false
	return true


# Same-filesystem sibling rename gives a directory-level publication point.
# Previous output (including unrelated data) moves intact to a uniquely named
# sibling rather than being deleted. A failure leaves no complete marker at D.
func _publish_capture() -> bool:
	if not _verify_staging():
		return false
	if test_pause_before_publication_ms > 0:
		print("WORLD_DESIGN_CAPTURE validated staging, paused before publication")
		OS.delay_msec(test_pause_before_publication_ms)
	manifest.status = "complete"
	manifest.success = true
	manifest.capture_count = manifest.captures.size()
	manifest.input_count = manifest.inputs.size()
	manifest.attempt_id = attempt_id
	if not _write_json(staging_path.path_join("capture-manifest.json"), manifest):
		return false
	if not _write_json(staging_path.path_join("capture-status.json"),
		{"status": "complete", "success": true, "attempt_id": attempt_id,
			"capture_count": manifest.capture_count, "input_count": manifest.input_count}):
		return false
	# Test-only failure at the post-validation/pre-rename publication seam.
	# Failure remains non-authoritative at the destination.
	if test_fail_publication:
		return false
	var previous_path: String = ""
	if DirAccess.dir_exists_absolute(output_path):
		previous_path = output_path + ".world-capture-previous-" + attempt_id
		if DirAccess.dir_exists_absolute(previous_path) or FileAccess.file_exists(previous_path):
			return false
		if DirAccess.rename_absolute(output_path, previous_path) != OK:
			return false
	if DirAccess.rename_absolute(staging_path, output_path) != OK:
		if not previous_path.is_empty():
			DirAccess.rename_absolute(previous_path, output_path)
		return false
	staging_path = ""
	return true


func _make_rig(input: Image, camera: Vector2i, view: Vector2i) -> Dictionary:
	var output_size: Vector2i = view * scale
	var viewport: SubViewport = SubViewport.new()
	viewport.size = output_size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND
	background.size = Vector2(output_size)
	viewport.add_child(background)
	var source_texture: ImageTexture = ImageTexture.create_from_image(input)
	var world_size: Vector2 = Vector2(input.get_size())
	var palette: ShaderMaterial = ShaderMaterial.new()
	palette.shader = palette_shader
	palette.set_shader_parameter("world_size_px", world_size)
	palette.set_shader_parameter("view_size_px", Vector2(view))
	palette.set_shader_parameter("view_rect_uv", Vector4(0.0, 0.0, 1.0, 1.0))
	palette.set_shader_parameter("camera_origin_px", Vector2(camera))
	palette.set_shader_parameter("player_origin_px", Vector2(-1000, -1000))
	palette.set_shader_parameter("condition_projection_enabled", 1.0)
	palette.set_shader_parameter("water_presentation_mode", 0.0)
	palette.set_shader_parameter("structured_detail", 1.0)
	palette.set_shader_parameter("growth_decor", 1.0)
	palette.set_shader_parameter("snapshot_blend", 1.0)
	palette.set_shader_parameter("presentation_time_override", presentation_time)
	palette.set_shader_parameter("current_world_texture", source_texture)
	palette.set_shader_parameter("previous_world_texture", source_texture)
	palette.set_shader_parameter("material_lut", palette_lut)
	palette.set_shader_parameter("material_program_lut", program_lut)
	palette.set_shader_parameter("material_lut_size", Vector2(
		CyberMaterialAppearanceLut.ATLAS_WIDTH, CyberMaterialAppearanceLut.ATLAS_HEIGHT))
	var world_rect: TextureRect = TextureRect.new()
	world_rect.size = Vector2(output_size)
	world_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	world_rect.stretch_mode = TextureRect.STRETCH_SCALE
	world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_rect.texture = source_texture
	world_rect.material = palette
	viewport.add_child(world_rect)
	# Same three stages as capture_material_review.gd, with a world-aligned camera.
	var glow_viewport: SubViewport = SubViewport.new()
	glow_viewport.disable_3d = true
	glow_viewport.transparent_bg = true
	glow_viewport.use_hdr_2d = true
	glow_viewport.size = Vector2i(maxi(1, (view.x + 1) / 2), maxi(1, (view.y + 1) / 2))
	glow_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(glow_viewport)
	var emission: ShaderMaterial = ShaderMaterial.new()
	emission.shader = emission_shader
	emission.set_shader_parameter("world_texture", source_texture)
	emission.set_shader_parameter("material_program_lut", program_lut)
	emission.set_shader_parameter("world_size_px", world_size)
	emission.set_shader_parameter("view_size_px", Vector2(view))
	emission.set_shader_parameter("camera_origin_px", Vector2(camera))
	emission.set_shader_parameter("condition_projection_enabled", 1.0)
	emission.set_shader_parameter("presentation_time_override", presentation_time)
	var source: ColorRect = ColorRect.new()
	source.size = Vector2(glow_viewport.size)
	source.color = Color.WHITE
	source.material = emission
	glow_viewport.add_child(source)
	var composite: ShaderMaterial = ShaderMaterial.new()
	composite.shader = composite_shader
	var overlay: TextureRect = TextureRect.new()
	overlay.size = Vector2(output_size)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	overlay.texture = glow_viewport.get_texture()
	overlay.material = composite
	overlay.visible = glow_enabled
	viewport.add_child(overlay)
	if not glow_enabled:
		glow_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return {"viewport": viewport, "camera": camera, "view": view}


func _readback(input: Image, camera: Vector2i, view: Vector2i) -> Dictionary:
	var rig: Dictionary = _make_rig(input, camera, view)
	# The child glow viewport must submit before the parent samples it.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result: Image = rig.viewport.get_texture().get_image()
	rig.viewport.queue_free()
	await process_frame
	if result == null or result.is_empty() or result.get_size() != view * scale:
		return {"ok": false, "error": "Godot viewport did not submit requested pixels"}
	result.convert(Image.FORMAT_RGB8) # Same display-clamped readback as material review.
	return {"ok": true, "image": result}


func _render_rg8(input: Dictionary) -> Dictionary:
	var size: Vector2i = input["size"]
	if size.x * scale > 32768 or size.y * scale > 32768:
		return {"ok": false, "error": "output exceeds bounded Image extent"}
	var img: Image = Image.create_from_data(size.x, size.y, false,
		Image.FORMAT_RG8, input.data)
	if img == null or img.is_empty() or img.get_data() != input.data:
		return {"ok": false, "error": "RG8 Image bytes did not survive construction"}
	var output: Image = Image.create_empty(size.x * scale, size.y * scale,
		false, Image.FORMAT_RGB8)
	for y: int in range(0, size.y, tile_cells):
		for x: int in range(0, size.x, tile_cells):
			var inner: Rect2i = Rect2i(x, y, mini(tile_cells, size.x - x),
				mini(tile_cells, size.y - y))
			# Every tile begins on the same even world-cell sampling phase.
			# Constant 32-cell overdraw (including outside world bounds) makes
			# the half-resolution emission shader phase-consistent at seams.
			var start: Vector2i = inner.position - Vector2i(PAD_CELLS, PAD_CELLS)
			var view: Vector2i = inner.size + Vector2i(PAD_CELLS * 2, PAD_CELLS * 2)
			if view.x % 2 != 0:
				view.x += 1
			if view.y % 2 != 0:
				view.y += 1
			var tile: Dictionary = await _readback(img, start, view)
			if not tile.ok:
				return tile
			var source_rect: Rect2i = Rect2i((inner.position - start) * scale,
				inner.size * scale)
			output.blit_rect(tile.image, source_rect, inner.position * scale)
	return {"ok": true, "image": output, "tiles": [
		(size.x + tile_cells - 1) / tile_cells, (size.y + tile_cells - 1) / tile_cells]}


func _details(combined: Image, info: Dictionary) -> bool:
	var placements: Array[Dictionary] = info.placements
	if placements.size() < 2:
		return true # Not possible to provide two distinct placement details.
	for i: int in [0, placements.size() - 1]:
		var p: Dictionary = placements[i]
		var f: Dictionary = info.features[p.feature]
		var f_size: Vector2i = Vector2i(f["size"][0], f["size"][1])
		var origin: Vector2i = Vector2i(p.origin[0], p.origin[1])
		var min_point: Vector2i = Vector2i(maxi(0, origin.x - 16),
			maxi(0, origin.y - 16))
		var end: Vector2i = Vector2i(mini(info["size"].x, origin.x + f_size.x + 16),
			mini(info["size"].y, origin.y + f_size.y + 16))
		var rect: Rect2i = Rect2i(min_point * scale, (end - min_point) * scale)
		var crop: Image = combined.get_region(rect)
		var filename: String = "details/%s-%s.png" % [
			"first" if i == 0 else "last", p.feature]
		if not _save_png(crop, filename, "full-resolution crop",
			{"source": "combined.png", "world_rect": [
				min_point.x, min_point.y, end.x - min_point.x, end.y - min_point.y]}):
			return false
	return true


func _run() -> void:
	var error: String = _prepare_target()
	if not error.is_empty():
		_status(5, error)
		return
	error = _parse_arguments()
	if not error.is_empty():
		_status(2, error)
		return
	if DisplayServer.get_name() == "headless":
		_status(3, "graphical DisplayServer required; headless is NOT a pass")
		return
	var loaded: Dictionary = _read_pack()
	if not loaded.ok:
		_status(2, loaded.error)
		return
	var info: Dictionary = loaded.info
	resource_budget = Adapter.capture_resource_budget(info, scale, tile_cells, mode, max_working_mib)
	if not resource_budget.ok:
		_status(2, resource_budget.error)
		return
	var source_identity: Dictionary = _source_identity()
	if require_verified_source and not source_identity.declared_matches_verified:
		_status(2, "mandatory source revision verification failed; declared revision does not match a clean Git checkout")
		return
	if not _load_shaders():
		_status(3, "failed to load production material shaders/LUT")
		return
	if not _create_stage():
		_status(5, "cannot create isolated capture staging directory")
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	manifest = {"status": "incomplete", "success": false,
		"fixture": "res://tools/capture_world_design_pack.gd",
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"source_revision_role": "caller declaration; not independently verified",
		"source_identity": source_identity,
		"design_pack_revision": design_revision,
		"design_revision_declared": design_revision,
		"design_revision_verified": null,
		"design_revision_verification": "external content-addressed pack; Git revision not asserted",
		"pack_path": pack_path,
		"pack_sha256": loaded.sha256, "family": info.family,
		"scene_dimensions_cells": [info["size"].x, info["size"].y],
		"features_declared": info.features.size(),
		"godot_version": Engine.get_version_info().string,
		"os": OS.get_name(), "display": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"palette_selection": palette_selection,
		"executable_path": OS.get_executable_path(),
		"executable_sha256": FileAccess.get_sha256(OS.get_executable_path()),
		"resource_budget": resource_budget,
		"graphics_adapter": RenderingServer.get_video_adapter_name(),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"rendering_config": {"mode": mode, "scale": scale, "time": presentation_time,
			"glow": glow_enabled, "tile_cells": tile_cells, "tile_padding_cells": PAD_CELLS,
			"hdr_2d": true, "condition_projection_enabled": 1.0,
			"water_presentation_mode": 0.0, "structured_detail": 1.0},
		"condition_policy": {
			"kind": "SYNTHETIC, not native simulation observation",
			"initial_material_condition_bytes": Adapter.INITIAL_CONDITION,
			"molten_glass_id_36_synthetic_heat": Adapter.SYNTHETIC_MOLTEN_GLASS_HEAT,
			"other_material_ids": 0,
			"source": "godot/tests/capture_material_review.gd creation-state policy"},
		"shader_sha256": {
			"palette": FileAccess.get_sha256("res://shaders/material_palette.gdshader"),
			"emission": FileAccess.get_sha256("res://shaders/material_emission.gdshader"),
			"glow_composite": FileAccess.get_sha256("res://shaders/glow_composite.gdshader"),
			"appearance_lut_script": FileAccess.get_sha256("res://scripts/material_appearance_lut.gd")},
		"inputs": [], "captures": []}
	if mode == "combined" or mode == "both":
		var combined: Dictionary = Adapter.build_combined(loaded.pack)
		if not combined.ok:
			_status(2, combined.error)
			return
		if not _save_input(combined, "inputs/combined.rg8"):
			_status(5, "cannot persist/verify combined RG8")
			return
		var rendered: Dictionary = await _render_rg8(combined)
		if not rendered.ok:
			_status(4, "combined renderer: " + rendered.error)
			return
		if not _save_png(rendered.image, "combined.png", "combined viewport render",
			{"tiles": rendered.tiles, "world_origin": [0, 0]}):
			_status(5, "cannot save combined PNG")
			return
		if not _details(rendered.image, info):
			_status(5, "cannot save combined detail crops")
			return
	if mode == "individual" or mode == "both":
		for feature: Dictionary in loaded.pack.features:
			var feature_id: String = feature.id
			var standalone: Dictionary = Adapter.build_feature(loaded.pack, feature_id)
			if not standalone.ok:
				_status(2, standalone.error)
				return
			if not _save_input(standalone, "inputs/%s.rg8" % feature_id):
				_status(5, "cannot persist/verify feature RG8: " + feature_id)
				return
			var rendered: Dictionary = await _render_rg8(standalone)
			if not rendered.ok:
				_status(4, "feature %s renderer: %s" % [feature_id, rendered.error])
				return
			if not _save_png(rendered.image, "features/%s.png" % feature_id,
				"standalone feature viewport render", {"variant": "base"}):
				_status(5, "cannot save feature PNG: " + feature_id)
				return
	if not _publish_capture():
		_status(5, "failed to verify/publish isolated capture; incomplete staging retained")
		return
	_status(0, "published verified genuine Godot framebuffer captures in " + output_path)
