extends SceneTree

const Context = preload("res://tests/palette_qualification_context.gd")

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
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
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


func _material_specialization_contract(palette: Shader, bounded: Shader) -> void:
	var material := ShaderMaterial.new()
	material.shader = bounded
	material.set_shader_parameter("world_size_px", Vector2(317, 259))
	material.set_shader_parameter("snapshot_blend", 0.37)
	var changes: Array[int] = [0]
	material.changed.connect(func(): changes[0] += 1)
	CyberPaletteShader.select_material_shader(material, true)
	var tiled: Shader = material.shader
	var identity: Dictionary = CyberPaletteShader.provenance(tiled)
	_expect(tiled != bounded and tiled.code.begins_with(
		CyberPaletteShader.BOUNDED_CROSSFADE_DEFINE + CyberPaletteShader.MATERIAL_TILES_DEFINE),
		"tiled specialization must preserve the ANGLE compile bound")
	_expect(identity.source_bound and identity.source_file_bound
		and identity.variant == "angle_bounded_crossfade" and identity.material_sampling == "tiled_specialized"
		and CyberPaletteShader.source_shader(tiled) == palette,
		"tiled ANGLE provenance must retain its actual file and both transformations")
	_expect(material.get_shader_parameter("world_size_px") == Vector2(317, 259)
		and is_equal_approx(float(material.get_shader_parameter("snapshot_blend")), 0.37),
		"specialization must preserve existing matching uniform values")
	var after_creation: int = changes[0]
	for publication: int in range(8): CyberPaletteShader.select_material_shader(material, true)
	_expect(material.shader == tiled and changes[0] == after_creation,
		"ordinary publications must neither allocate nor reassign the selected Shader")
	CyberPaletteShader.select_material_shader(material, false)
	_expect(material.shader == bounded and material.get_shader_parameter("world_size_px") == Vector2(317, 259),
		"full fallback must restore the original Shader and preserve uniforms")
	CyberPaletteShader.select_material_shader(material, true)
	_expect(material.shader == tiled, "live mode switches must reuse the owned bounded shader pair")
	_expect(CyberPaletteShader.palette_for_driver(tiled, "opengl3_angle") == bounded
		and CyberPaletteShader.palette_for_driver(tiled, "opengl3") == palette,
		"renderer reselection must resolve through material specialization")
	tiled.code += "\n// independently mutated material variant\n"
	_expect(not CyberPaletteShader.provenance(tiled).source_bound,
		"material variant mutation must invalidate source custody")
	CyberPaletteShader.select_material_shader(material, true)
	_expect(material.shader != tiled and CyberPaletteShader.provenance(material.shader).source_bound,
		"mutated owned specialization must be rebuilt from its exact base")
	tiled = null
	var retired: WeakRef = weakref(material.shader)
	var replacement := Shader.new()
	replacement.code = palette.code
	material.shader = replacement
	CyberPaletteShader.select_material_shader(material, true)
	_expect(retired.get_ref() == null and CyberPaletteShader.source_shader(material.shader) == replacement,
		"external Shader replacement must release the old variant and retain new resource custody")
	var old_variant: Shader = material.shader
	replacement.code += "\n// edited actual base resource\n"
	_expect(not CyberPaletteShader.provenance(old_variant).source_bound,
		"base edit must invalidate the old material specialization")
	CyberPaletteShader.select_material_shader(material, true)
	_expect(material.shader != old_variant and CyberPaletteShader.provenance(material.shader).source_bound,
		"base edit must replace the single owned tiled specialization")


func _run() -> void:
	var palette: Shader = load(PALETTE_PATH) as Shader
	Context.emit(get_script().resource_path, palette)
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


	var identity: Dictionary = CyberPaletteShader.provenance(bounded)
	_expect(identity.source_path == PALETTE_PATH and identity.source_bound
		and identity.source_sha256 == code.sha256_text()
		and identity.source_file_bound and identity.source_file_sha256 == FileAccess.get_sha256(PALETTE_PATH)
		and identity.variant_sha256 == bounded.code.sha256_text()
		and identity.variant == "angle_bounded_crossfade", "variant custody is not source-bound")
	_expect(CyberPaletteShader.provenance(palette).variant == "full_crossfade",
		"native shader provenance is incorrectly labelled")
	var editable := Shader.new()
	editable.code = "shader_type canvas_item; void fragment() { COLOR = vec4(1.0); }"
	var first: Shader = CyberPaletteShader.palette_for_driver(editable, "opengl3_angle")
	var first_hash: String = first.code.sha256_text()
	editable.code += "\n// changed source revision\n"
	_expect(not CyberPaletteShader.provenance(first).source_bound,
		"source mutation must invalidate the old variant custody")
	var refreshed: Shader = CyberPaletteShader.palette_for_driver(first, "opengl3_angle")
	_expect(refreshed != first and refreshed.code.sha256_text() != first_hash
		and CyberPaletteShader.provenance(refreshed).source_bound,
		"source edits must select a freshly bound variant")
	refreshed.code += "\n// independently mutated selected variant\n"
	_expect(not CyberPaletteShader.provenance(refreshed).source_bound,
		"selected-byte mutation must invalidate provenance")
	var repaired: Shader = CyberPaletteShader.palette_for_driver(refreshed, "opengl3_angle")
	_expect(repaired != refreshed and repaired.code == CyberPaletteShader.BOUNDED_CROSSFADE_DEFINE + editable.code,
		"a mutated cache entry must not be reused")
	var independent := Shader.new()
	independent.code = editable.code
	var independent_variant: Shader = CyberPaletteShader.palette_for_driver(independent, "opengl3_angle")
	_expect(CyberPaletteShader.source_shader(independent_variant) == independent,
		"equal shader bytes must not steal a different source resource's custody")
	_expect(CyberPaletteShader.palette_for_driver(repaired, "opengl3") == editable,
		"native reselection after source edit must retain its actual source")
	_material_specialization_contract(palette, bounded)
	print("PALETTE_COMPILE_BOUNDS_RESULT ", JSON.stringify({"assertions":_assertions,
		"failures":_failures, "production_variant":CyberPaletteShader.provenance(bounded)}))

	if _failures == 0:
		print("PALETTE_COMPILE_BOUNDS: PASS")
	quit(1 if _failures > 0 else 0)
