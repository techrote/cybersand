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
	var source: Shader = palette.get_meta(SOURCE_META, palette) as Shader
	if not uses_bounded_crossfade(driver_name):
		return source
	# One shared Shader per source keeps every consumer on one compiled program.
	var bounded: Shader = _bounded_by_source.get(source.code) as Shader
	if bounded == null:
		bounded = Shader.new()
		bounded.code = BOUNDED_CROSSFADE_DEFINE + source.code
		bounded.set_meta(SOURCE_META, source)
		_bounded_by_source[source.code] = bounded
	return bounded
