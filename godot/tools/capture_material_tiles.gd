extends SceneTree

# Static RG8 material inputs rendered through the actual production CyberSand
# palette shader and LUT by Godot's graphical OpenGL renderer.
# This is a presentation capture, not a native World simulation.
const LUT = preload("res://material_appearance_lut.gd")
const TILE: int = 64
const MARGIN: int = 4
const PITCH: int = TILE + MARGIN * 2
const COLUMNS: int = 12
const FIXED_TIME: float = 1.37

var output_dir: String = ""
var materials: Array = []
var results: Array = []
var failures: int = 0
var shader: Shader
var palette: ImageTexture
var programs: ImageTexture
var atlas_size: Vector2i = Vector2i.ZERO

func _init() -> void:
	call_deferred("_run")

func _filled(material_id: int, x: int, y: int, variant: String) -> bool:
	if variant == "full":
		return true
	# Reproducible, offset, ragged-edged block per material. Parameters depend
	# on identity and pixel coordinates, not on host random-number state.
	var cx: int = 32 + (material_id * 13 % 9) - 4
	var cy: int = 32 + (material_id * 7 % 9) - 4
	var rx: int = 18 + (material_id * 3 % 8)
	var ry: int = 18 + (material_id * 5 % 8)
	var l: int = (y * 11 + material_id * 17) % 7 - 3
	var r: int = (y * 19 + material_id * 23) % 7 - 3
	var t: int = (x * 13 + material_id * 29) % 7 - 3
	var b: int = (x * 17 + material_id * 31) % 7 - 3
	return x >= cx - rx + l and x <= cx + rx + r and y >= cy - ry + t and y <= cy + ry + b

func _source(variant: String) -> Image:
	var img: Image = Image.create_empty(atlas_size.x, atlas_size.y, false, Image.FORMAT_RG8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	for index: int in range(materials.size()):
		var row: Dictionary = materials[index]
		var material_id: int = int(row["id"])
		var condition: int = int(row["condition"])
		var origin := Vector2i(index % COLUMNS * PITCH + MARGIN,
			index / COLUMNS * PITCH + MARGIN)
		var texel := Color(float(material_id) / 255.0, float(condition) / 255.0, 0.0, 1.0)
		for y: int in range(TILE):
			for x: int in range(TILE):
				if _filled(material_id, x, y, variant):
					img.set_pixel(origin.x + x, origin.y + y, texel)
	return img

func _capture(variant: String) -> void:
	var source: Image = _source(variant)
	var texture: ImageTexture = ImageTexture.create_from_image(source)
	var viewport := SubViewport.new()
	viewport.size = atlas_size
	viewport.disable_3d = true
	viewport.use_hdr_2d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("current_world_texture", texture)
	material.set_shader_parameter("previous_world_texture", texture)
	material.set_shader_parameter("material_lut", palette)
	material.set_shader_parameter("material_program_lut", programs)
	material.set_shader_parameter("material_lut_size", Vector2(LUT.ATLAS_WIDTH, LUT.ATLAS_HEIGHT))
	material.set_shader_parameter("world_size_px", Vector2(atlas_size))
	material.set_shader_parameter("view_size_px", Vector2(atlas_size))
	material.set_shader_parameter("view_rect_uv", Vector4(0.0, 0.0, 1.0, 1.0))
	material.set_shader_parameter("camera_origin_px", Vector2.ZERO)
	material.set_shader_parameter("player_origin_px", Vector2(-10000.0, -10000.0))
	material.set_shader_parameter("condition_projection_enabled", 1.0)
	material.set_shader_parameter("snapshot_blend", 1.0)
	material.set_shader_parameter("presentation_time_override", FIXED_TIME)
	material.set_shader_parameter("structured_detail", 1.0)
	material.set_shader_parameter("growth_decor", 1.0)
	material.set_shader_parameter("vapour_trail_strength", 0.0)
	material.set_shader_parameter("water_presentation_mode", 0.0)
	var rect := TextureRect.new()
	rect.size = Vector2(atlas_size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.texture = texture
	rect.material = material
	viewport.add_child(rect)
	root.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var framebuffer: Image = viewport.get_texture().get_image()
	framebuffer.convert(Image.FORMAT_RGBA8)
	var directory: String = output_dir.path_join(variant)
	DirAccess.make_dir_recursive_absolute(directory)
	for index: int in range(materials.size()):
		var row: Dictionary = materials[index]
		var material_id: int = int(row["id"])
		var origin := Vector2i(index % COLUMNS * PITCH + MARGIN,
			index / COLUMNS * PITCH + MARGIN)
		var tile: Image = framebuffer.get_region(Rect2i(origin, Vector2i(TILE, TILE)))
		if variant == "random_block":
			for y: int in range(TILE):
				for x: int in range(TILE):
					if not _filled(material_id, x, y, variant):
						tile.set_pixel(x, y, Color(0.0, 0.0, 0.0, 1.0))
		var file_name: String = "%03d_%s.png" % [material_id, str(row["name"]).replace("-", "_")]
		var path: String = directory.path_join(file_name)
		var status: Error = tile.save_png(path)
		if status != OK:
			failures += 1
			push_error("Failed to save " + path)
		else:
			results.append({"variant": variant, "id": material_id, "name": str(row["name"]),
				"condition": int(row["condition"]), "path": variant.path_join(file_name),
				"sha256": FileAccess.get_sha256(path)})
	print("TILE_CAPTURE ", variant, " exported=", materials.size(), " failures=", failures)
	viewport.queue_free()
	await process_frame

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Graphical DisplayServer required for real shader rendering")
		quit(2)
		return
	output_dir = OS.get_environment("CYBERSAND_TILE_OUTPUT")
	if output_dir.is_empty():
		push_error("CYBERSAND_TILE_OUTPUT must be set")
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://material_index.json"))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Expected res://material_index.json array")
		quit(2)
		return
	materials = parsed
	if materials.size() != 131:
		push_error("Expected 130 paintable materials plus Empty control, got %d" % materials.size())
		quit(3)
		return
	atlas_size = Vector2i(COLUMNS * PITCH, ceili(float(materials.size()) / float(COLUMNS)) * PITCH)
	root.size = atlas_size
	root.content_scale_size = atlas_size
	DirAccess.make_dir_recursive_absolute(output_dir)
	shader = Shader.new()
	shader.code = FileAccess.get_file_as_string("res://material_palette.gdshader")
	palette = LUT.create_texture()
	programs = LUT.create_program_texture()
	await _capture("full")
	await _capture("random_block")
	var record: Dictionary = {
		"schema": "cybersand-material-tile-gallery-v1",
		"source_sha": OS.get_environment("CYBERSAND_SOURCE_SHA"),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"godot": Engine.get_version_info().string,
		"display_server": DisplayServer.get_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"video_vendor": RenderingServer.get_video_adapter_vendor(),
		"time_seconds": FIXED_TIME,
		"tile_size": [TILE, TILE],
		"input": "Synthetic immutable RG8 identity/condition cells; not a physics tick",
		"appearance": "CyberSand production material_palette.gdshader and material_appearance_lut.gd",
		"background": "Black outside the random material block",
		"glow": "No emission/glow post-pass; palette shader including its intrinsic finishes and relief",
		"material_count": materials.size(),
		"files": results,
		"shader_sha256": FileAccess.get_sha256("res://material_palette.gdshader"),
		"lut_sha256": FileAccess.get_sha256("res://material_appearance_lut.gd")
	}
	var manifest: FileAccess = FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if manifest == null:
		failures += 1
	else:
		manifest.store_string(JSON.stringify(record, "  ") + "\n")
		manifest.close()
	print("TILE_CAPTURE_RESULT ", JSON.stringify({"files": results.size(), "failures": failures}))
	quit(0 if failures == 0 and results.size() == 262 else 1)
