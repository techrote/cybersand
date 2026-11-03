class_name CyberPaletteShader
extends RefCounted

# ANGLE compiles GL shaders through D3DCompile, whose time grows faster than
# linearly with emitted code. Two inlined material_colour copies cost minutes on
# that path, so it alone selects the single-copy crossfade. Native OpenGL keeps
# the full previous-side finish and the unmodified shader resource.
const BOUNDED_CROSSFADE_DEFINE: String = "#define CYBER_BOUNDED_CROSSFADE\n"
const ANGLE_DRIVER_NAME: String = "opengl3_angle"
const SOURCE_META: StringName = &"cyber_palette_source"

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
	return palette.get_meta(SOURCE_META, palette) as Shader


static func provenance(palette: Shader) -> Dictionary:
	var source: Shader = source_shader(palette)
	var bounded: bool = palette.code.begins_with(BOUNDED_CROSSFADE_DEFINE)
	var expected: String = BOUNDED_CROSSFADE_DEFINE + source.code if bounded else source.code
	var file_hash: String = FileAccess.get_sha256(source.resource_path) if not source.resource_path.is_empty() else ""
	return {
		"source_path":source.resource_path,
		"source_sha256":source.code.sha256_text(),
		"source_file_sha256":file_hash,
		"source_file_bound":not file_hash.is_empty() and file_hash == source.code.sha256_text(),
		"variant_sha256":palette.code.sha256_text(),
		"variant":"angle_bounded_crossfade" if bounded else "full_crossfade",
		"source_bound":palette.code == expected,
	}
