extends SceneTree

# Source-level guards for the Windows ANGLE palette compile cost. FXC reports a
# potentially uninitialized return value for early-return dispatch functions and
# can then fail validation, so these stay single-exit. A second material_colour
# inline on the ANGLE path multiplies D3DCompile time several times over.
const PALETTE_PATH: String = "res://shaders/material_palette.gdshader"
const SINGLE_EXIT_FUNCTIONS: Array[String] = [
	"vec4 apply_building_finish(",
	"vec4 apply_material_flair(",
	"vec4 apply_neighbour_relief(",
	"vec4 apply_structured_fill(",
]

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("PALETTE_COMPILE_BOUNDS FAILED: ", message)


func _body(code: String, signature: String) -> String:
	var start: int = code.find(signature)
	if start < 0:
		return ""
	var open: int = code.find("{", code.find(")", start))
	var depth: int = 0
	for index: int in range(open, code.length()):
		var character: String = code[index]
		if character == "{":
			depth += 1
		elif character == "}":
			depth -= 1
			if depth == 0:
				return code.substr(open, index - open + 1)
	return ""


func _count_calls(code: String, name: String) -> int:
	var expression := RegEx.new()
	expression.compile("\\b" + name + "\\(")
	return expression.search_all(code).size()


func _run() -> void:
	var palette: Shader = load(PALETTE_PATH) as Shader
	var code: String = palette.code
	for signature: String in SINGLE_EXIT_FUNCTIONS:
		var body: String = _body(code, signature)
		_expect(not body.is_empty(), "missing " + signature)
		_expect(_count_calls(body.replace("return ", "return("), "return") == 1, signature + " is not single-exit")
	_expect(_count_calls(_body(code, "vec4 apply_building_finish("), "apply_burn") == 1,
		"building burn tail is not shared")
	_expect(_count_calls(_body(code, "vec4 apply_structured_fill("), "apply_burn") == 1,
		"structured burn tail is not shared")

	var fragment: String = _body(code, "void fragment(")
	var bounded_start: int = fragment.find("#ifdef CYBER_BOUNDED_CROSSFADE")
	var bounded_else: int = fragment.find("#else", bounded_start)
	var bounded_end: int = fragment.find("#endif", bounded_else)
	_expect(bounded_start >= 0 and bounded_else > bounded_start and bounded_end > bounded_else,
		"fragment has no bounded crossfade selection")
	var bounded_side: String = fragment.substr(bounded_start, bounded_else - bounded_start)
	var exact_side: String = fragment.substr(bounded_else, bounded_end - bounded_else)
	_expect(_count_calls(bounded_side, "material_colour") == 0, "bounded path inlines a second material_colour")
	_expect(_count_calls(exact_side, "material_colour") == 1, "exact path lost the previous material_colour")
	_expect(_count_calls(fragment, "material_colour") == 2, "unexpected material_colour call count")

	_expect(CyberPaletteShader.palette_for_driver(palette, "opengl3") == palette,
		"native OpenGL must keep the unmodified palette")
	var bounded: Shader = CyberPaletteShader.palette_for_driver(palette, "opengl3_angle")
	_expect(bounded != palette and bounded.code.begins_with(CyberPaletteShader.BOUNDED_CROSSFADE_DEFINE),
		"ANGLE must select the bounded palette")
	_expect(CyberPaletteShader.palette_for_driver(palette, "opengl3_angle") == bounded,
		"ANGLE consumers must share one compiled palette")
	_expect(CyberPaletteShader.palette_for_driver(bounded, "opengl3_angle") == bounded,
		"reselecting the ANGLE palette must not stack a second define")
	_expect(CyberPaletteShader.palette_for_driver(bounded, "opengl3") == palette,
		"native OpenGL must resolve a selected palette back to its source")

	if _failures == 0:
		print("PALETTE_COMPILE_BOUNDS: PASS")
	quit(1 if _failures > 0 else 0)
