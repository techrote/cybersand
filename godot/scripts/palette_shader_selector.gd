class_name CyberPaletteShader
extends RefCounted

# ANGLE compiles GL shaders through D3DCompile, whose time grows faster than
# linearly with emitted code. Two inlined material_colour copies cost minutes on
# that path, so it alone selects the single-copy crossfade. Native OpenGL keeps
# the full previous-side finish and the unmodified shader resource.
const BOUNDED_CROSSFADE_DEFINE: String = "#define CYBER_BOUNDED_CROSSFADE\n"
const ANGLE_DRIVER_NAME: String = "opengl3_angle"
const SOURCE_META: StringName = &"cyber_palette_source"
const MATERIAL_TILES_DEFINE: String = "#define CYBER_MATERIAL_TILES\n"
const MATERIAL_BASE_META: StringName = &"cyber_material_base_shader"
const MATERIAL_CACHE_META: StringName = &"cyber_material_shader_pair"

static var _bounded_by_source: Dictionary = {}


static func uses_bounded_crossfade(driver_name: String = "") -> bool:
	if driver_name.is_empty():
		driver_name = RenderingServer.get_current_rendering_driver_name()
	return driver_name == ANGLE_DRIVER_NAME


static func for_current_renderer(palette: Shader) -> Shader:
	return palette_for_driver(palette, RenderingServer.get_current_rendering_driver_name())


static func palette_for_driver(palette: Shader, driver_name: String) -> Shader:
	# Main's scene material is shared across instances, so a recreated Main can
	# pass in the variant it already selected. Always resolve from the source.
	var source: Shader = source_shader(palette)
	if not uses_bounded_crossfade(driver_name):
		return source
	# One shared Shader per source keeps every consumer on one compiled program.
	# Keep one current entry per source resource, including during live editing.
	# The code comparison below invalidates source revisions without retaining
	# a compiled variant for every old revision of that same resource.
	var key: int = source.get_instance_id()
	var expected_code: String = BOUNDED_CROSSFADE_DEFINE + source.code
	var bounded: Shader = _bounded_by_source.get(key) as Shader
	# A shader resource may be edited/reloaded in the editor. Neither a stale
	# source nor a caller-mutated variant may silently reuse old compiled bytes.
	if bounded == null or bounded.code != expected_code:
		bounded = Shader.new()
		bounded.code = expected_code
		bounded.set_meta(SOURCE_META, source)
		_bounded_by_source[key] = bounded
	return bounded


static func source_shader(palette: Shader) -> Shader:
	var base: Shader = palette.get_meta(MATERIAL_BASE_META, palette) as Shader
	return base.get_meta(SOURCE_META, base) as Shader


static func _material_tiled_code(base_code: String) -> String:
	# Preserve the ANGLE prefix and its single material_colour expansion.
	if base_code.begins_with(BOUNDED_CROSSFADE_DEFINE):
		return BOUNDED_CROSSFADE_DEFINE + MATERIAL_TILES_DEFINE \
			+ base_code.substr(BOUNDED_CROSSFADE_DEFINE.length())
	return MATERIAL_TILES_DEFINE + base_code


static func select_material_shader(material: ShaderMaterial, tiled: bool) -> void:
	if material == null or material.shader == null: return
	# A material owns at most its original Shader and one tiled specialization.
	# No global cache retains replaced materials, source resources or variants.
	# Comparing immutable String values does not construct code every upload.
	var cache: Dictionary = material.get_meta(MATERIAL_CACHE_META, {})
	var selected: Shader = material.shader
	var base: Shader = cache.get("base") as Shader
	var variant: Shader = cache.get("tiled") as Shader
	var changed: bool = false
	if base == null or (selected != base and selected != variant):
		base = selected.get_meta(MATERIAL_BASE_META, selected) as Shader
		cache = {"base":base, "base_code":base.code}
		variant = null
		changed = true
	var base_code: String = base.code
	if cache.get("base_code", "") != base_code:
		cache = {"base":base, "base_code":base_code}
		variant = null
		changed = true
	var desired: Shader = base
	if tiled:
		if variant == null or variant.code != cache.get("tiled_code", ""):
			variant = Shader.new()
			variant.code = _material_tiled_code(base_code)
			variant.set_meta(MATERIAL_BASE_META, base)
			cache["tiled"] = variant
			cache["tiled_code"] = variant.code
			changed = true
		desired = variant
	if changed: material.set_meta(MATERIAL_CACHE_META, cache)
	# set_shader preserves matching uniforms, but rebuilds backend material
	# state even for equal resources. Never call it on ordinary publications.
	if material.shader != desired: material.shader = desired


static func provenance(palette: Shader) -> Dictionary:
	var base: Shader = palette.get_meta(MATERIAL_BASE_META, palette) as Shader
	var tiled: bool = base != palette
	var source: Shader = source_shader(palette)
	var bounded: bool = base.code.begins_with(BOUNDED_CROSSFADE_DEFINE)
	var expected_base: String = BOUNDED_CROSSFADE_DEFINE + source.code if bounded else source.code
	var expected: String = _material_tiled_code(expected_base) if tiled else expected_base
	var file_hash: String = FileAccess.get_sha256(source.resource_path) if not source.resource_path.is_empty() else ""
	return {
		"source_path":source.resource_path,
		"source_sha256":source.code.sha256_text(),
		"source_file_sha256":file_hash,
		"material_sampling_include_sha256":FileAccess.get_sha256("res://shaders/material_tile_sampling.gdshaderinc"),
		"source_file_bound":not file_hash.is_empty() and file_hash == source.code.sha256_text(),
		"variant_sha256":palette.code.sha256_text(),
		"variant":"angle_bounded_crossfade" if bounded else "full_crossfade",
		"material_sampling":"tiled_specialized" if tiled else "full_or_dynamic",
		"source_bound":base.code == expected_base and palette.code == expected,
	}
