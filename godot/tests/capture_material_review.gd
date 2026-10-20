extends SceneTree

# Material presentation review fixture. It renders explicit immutable RG8
# inputs through the production palette, emission and glow-composite shaders
# and saves the actual framebuffer readback. It is a capture apparatus, not an
# automatic regression runner (the name deliberately avoids the test_ prefix).
#
# Graphical only: a headless DisplayServer submits no frames.
#   <godot> --path godot --script res://tests/capture_material_review.gd -- \
#     --output=<absolute dir> [--plates=inventory,liquids,...] [--clip-frames=90]
#     [--shader-root=<dir with the three .gdshader files>] [--lut-script=<path>]
#     [--fallback-r8]
#
# --fallback-r8 presents the inputs as the desktop GDScript fallback does:
# R8 material IDs only, with condition projection disabled.
#
# --shader-root/--lut-script render another revision's presentation sources
# (for example extracted with git show) through this same fixture, so a
# baseline and candidate differ only in those sources.
#
# Every image pair holds the RG8 bytes, camera, view/output size, glow, blend
# and presentation_time_override constant; manifest.json records them.

const PALETTE_FILE: String = "material_palette.gdshader"
const EMISSION_FILE: String = "material_emission.gdshader"
const COMPOSITE_FILE: String = "glow_composite.gdshader"
const Pack = preload("res://scripts/microscenario_reference_pack.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const VIEW: Vector2i = Vector2i(320, 180)
const BACKGROUND: Color = Color(0.031, 0.043, 0.071, 1.0) # main.tscn Background
const PLATES: Array[String] = [
	"inventory", "liquids", "construction", "emission", "transition", "street", "laboratory",
	"reactions", "shapes", "statics", "building", "growth",
]
# Native creation values of the material-selected condition byte (see
# native/include/cybersand/material.hpp initial_state_a and
# material_appearance.hpp). Other projected materials start at zero.
const INITIAL_CONDITION: Dictionary = {
	3: 255, 4: 240, 6: 240, 11: 32, 12: 255, 15: 1, 18: 32, 22: 180, 30: 180, 34: 12, 37: 120,
}
const SYNTHETIC_MOLTEN_GLASS_HEAT: int = 200

var output_dir: String = ""
var shader_root: String = "res://shaders"
var lut_script_path: String = "res://scripts/material_appearance_lut.gd"
var shaders: Dictionary = {}
var fallback_r8: bool = false
var plate_filter: Array[String] = []
var clip_frames: int = 90
var clip_fps: float = 30.0
var still_times: Array[float] = [0.0, 1.37]
var palette_lut: ImageTexture
var program_lut: ImageTexture
var names: Array[String] = []
var manifest: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
		elif argument.begins_with("--plates="):
			for plate: String in argument.trim_prefix("--plates=").split(",", false):
				plate_filter.append(plate)
		elif argument.begins_with("--shader-root="):
			shader_root = argument.trim_prefix("--shader-root=")
		elif argument.begins_with("--lut-script="):
			lut_script_path = argument.trim_prefix("--lut-script=")
		elif argument == "--fallback-r8":
			fallback_r8 = true
		elif argument.begins_with("--clip-frames="):
			clip_frames = maxi(0, int(argument.trim_prefix("--clip-frames=")))


func _wanted(plate: String) -> bool:
	return plate_filter.is_empty() or plate in plate_filter


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("MATERIAL_REVIEW_CAPTURE: skipped (headless DisplayServer has no frame submission)")
		quit(0)
		return
	_parse_arguments()
	if output_dir.is_empty():
		push_error("--output=<absolute directory> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var sources: Dictionary = {}
	for file_name: String in [PALETTE_FILE, EMISSION_FILE, COMPOSITE_FILE]:
		var code: String = FileAccess.get_file_as_string(shader_root.path_join(file_name))
		var shader: Shader = Shader.new()
		shader.code = code
		shaders[file_name] = shader
		sources[file_name] = code.sha256_text()
	# A detached copy of the LUT compiler; its class_name would shadow the
	# project's global class, so it is removed before compilation.
	var lut_code: String = FileAccess.get_file_as_string(lut_script_path)
	sources["material_appearance_lut.gd"] = lut_code.sha256_text()
	var lut_script: GDScript = GDScript.new()
	lut_script.source_code = lut_code.replace("class_name CyberMaterialAppearanceLut", "")
	if lut_script.reload() != OK:
		push_error("LUT script failed to compile: " + lut_script_path)
		quit(3)
		return
	palette_lut = lut_script.call("create_texture")
	program_lut = lut_script.call("create_program_texture")
	var namer: Object = load("res://scripts/main.gd").new()
	for material_id: int in range(CyberMaterialAppearanceLut.MATERIAL_COUNT):
		names.append(str(namer.material_name(material_id)))
	namer.free()
	manifest = {
		"fixture": "res://tests/capture_material_review.gd",
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"godot": Engine.get_version_info().string,
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"adapter": RenderingServer.get_video_adapter_name(),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"view_size": [VIEW.x, VIEW.y],
		"shader_root": shader_root,
		"lut_script": lut_script_path,
		"presentation_source_sha256": sources,
		"hdr_2d": true,
		"fallback_r8": fallback_r8,
		"material_names": names,
		"plates": {},
	}
	for plate: String in PLATES:
		if not _wanted(plate):
			continue
		var started: int = Time.get_ticks_msec()
		var inputs: Dictionary = _plate_inputs(plate)
		if inputs.is_empty():
			push_error("plate %s produced no input" % plate)
			continue
		await _capture_plate(plate, inputs)
		print("MATERIAL_REVIEW_CAPTURE: %s %d ms" % [plate, Time.get_ticks_msec() - started])
	var file: FileAccess = FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("MATERIAL_REVIEW_CAPTURE: wrote ", output_dir)
	quit(0)


# --- RG8 input construction -------------------------------------------------

func _blank(size: Vector2i) -> Image:
	var image: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RG8)
	image.fill(Color(0, 0, 0, 1))
	return image


func _condition_for(material_id: int) -> int:
	if material_id == 36:
		return SYNTHETIC_MOLTEN_GLASS_HEAT
	return int(INITIAL_CONDITION.get(material_id, 0))


func _put(image: Image, x: int, y: int, material_id: int, condition: int = -1) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var value: int = _condition_for(material_id) if condition < 0 else condition
	image.set_pixel(x, y, Color(float(material_id) / 255.0, float(value) / 255.0, 0.0, 1.0))


func _fill(image: Image, x: int, y: int, w: int, h: int, material_id: int, condition: int = -1) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_put(image, xx, yy, material_id, condition)


func _tray(image: Image, x: int, y: int, liquid: int) -> void:
	# 32x32 Wall tray: inner 28 wide, a raised right step, a shallow film over
	# the step, a one-cell lip on the left wall and droplets above.
	_fill(image, x, y + 8, 2, 24, 1)
	_fill(image, x + 30, y + 8, 2, 24, 1)
	_fill(image, x, y + 30, 32, 2, 1)
	_fill(image, x + 21, y + 24, 9, 6, 1)
	_fill(image, x + 2, y + 16, 19, 14, liquid)
	_fill(image, x + 21, y + 22, 9, 2, liquid)
	_fill(image, x + 2, y + 15, 6, 1, liquid)
	for droplet: Vector2i in [Vector2i(6, 2), Vector2i(12, 5), Vector2i(18, 1), Vector2i(25, 9)]:
		_put(image, x + droplet.x, y + droplet.y, liquid)
	_fill(image, x + 14, y + 9, 2, 2, liquid)


func _plate_inputs(plate: String) -> Dictionary:
	match plate:
		"inventory": return _inventory()
		"liquids": return _liquids()
		"construction": return _construction()
		"emission": return _emission()
		"transition": return _transition()
		"street": return _street()
		"laboratory": return _laboratory()
		"reactions": return _reactions()
		"shapes": return _shapes()
		"statics": return _statics()
		"building": return _building()
		"growth": return _growth()
	return {}


func _inventory() -> Dictionary:
	var image: Image = _blank(VIEW)
	var swatches: Array = []
	for material_id: int in range(CyberMaterialAppearanceLut.MATERIAL_COUNT):
		var column: int = material_id % 12
		var row: int = material_id / 12
		var x: int = 2 + column * 26
		var y: int = 1 + row * 16
		_fill(image, x, y + 1, 16, 11, material_id)
		_fill(image, x + 18, y + 3, 1, 9, material_id)
		_fill(image, x + 20, y + 3, 2, 9, material_id)
		_put(image, x + 23, y + 4, material_id)
		_fill(image, x + 23, y + 8, 2, 2, material_id)
		_fill(image, x, y + 12, 25, 1, 1)
		swatches.append({"id": material_id, "rect": [x, y + 1, 16, 11]})
	return {"current": image, "previous": image, "cameras": [Vector2i.ZERO],
		"notes": "All 132 rows including Empty and reserved invalid ID 10 (12 per row since the MAT-002 expansion). Each swatch: 16x11 block, 1- and 2-cell partitions, single and 2x2 droplets, Wall ledge. Condition bytes are native creation values (synthetic for Molten Glass heat).",
		"swatches": swatches, "synthetic": true}


func _liquids() -> Dictionary:
	var image: Image = _blank(VIEW)
	var top: Array[int] = [3, 16, 20, 21, 24]
	var bottom: Array[int] = [30, 33, 12, 32, 8]
	var trays: Array = []
	for index: int in range(5):
		_tray(image, 6 + index * 62, 2, top[index])
		_tray(image, 6 + index * 62, 52, bottom[index])
		trays.append({"id": top[index], "rect": [6 + index * 62, 2, 32, 32]})
		trays.append({"id": bottom[index], "rect": [6 + index * 62, 52, 32, 32]})
	# Dry/wet construction pairs with a step and a one-cell Water film.
	var pairs: Array[Vector2i] = [Vector2i(59, 60), Vector2i(41, 61)]
	for index: int in range(2):
		var x: int = 6 + index * 156
		_fill(image, x, 120, 70, 50, pairs[index].x)
		_fill(image, x + 74, 126, 70, 44, pairs[index].y)
		_fill(image, x + 74, 120, 30, 6, pairs[index].y)
		_fill(image, x + 112, 125, 14, 1, 3)
		trays.append({"id": pairs[index].x, "rect": [x, 120, 70, 50]})
		trays.append({"id": pairs[index].y, "rect": [x + 74, 126, 70, 44]})
	_fill(image, 0, 172, 320, 8, 1)
	return {"current": image, "previous": image, "cameras": [Vector2i.ZERO],
		"notes": "Matched 32x32 Wall trays (step, shallow film, lip, droplets) for Water, Oil, Paste, Slush, Brine / Cement, Mercury, Acid, Toxic Sludge, Lava; dry/wet Asphalt and Cobblestone slabs with a one-cell Water film.",
		"regions": trays, "synthetic": true}


func _construction() -> Dictionary:
	var size: Vector2i = Vector2i(VIEW.x + 24, VIEW.y + 12)
	var image: Image = _blank(size)
	var grid: Array[int] = [
		50, 54, 52, 53, 51, 62, 63, 64,
		65, 66, 67, 68, 69, 28, 35, 71,
		72, 9, 55, 70, 38, 43, 41, 46,
		48, 49, 47, 44, 31, 58, 59, 76,
	]
	var regions: Array = []
	for index: int in range(grid.size()):
		var material_id: int = grid[index]
		var x: int = 3 + (index % 8) * 40
		var y: int = 2 + (index / 8) * 44
		_fill(image, x, y, 34, 26, material_id)
		# Inside corner, 1-cell and 2-cell partitions and a short ledge.
		_fill(image, x, y + 29, 14, 3, material_id)
		_fill(image, x, y + 32, 3, 9, material_id)
		_fill(image, x + 18, y + 29, 1, 12, material_id)
		_fill(image, x + 22, y + 29, 2, 12, material_id)
		_fill(image, x + 27, y + 38, 7, 3, material_id)
		regions.append({"id": material_id, "rect": [x, y, 34, 26]})
	return {"current": image, "previous": image,
		"cameras": [Vector2i.ZERO, Vector2i(7, 3)],
		"pan": {"from": [0, 0], "to": [24, 12]},
		"notes": "Large 34x26 panels plus inside corner, 1/2-cell partitions and a ledge for metals (rough and manufactured), glass/ice, masonry, timber and roofing. World is larger than the view for pan checks.",
		"regions": regions, "synthetic": true}


func _emission() -> Dictionary:
	var image: Image = _blank(VIEW)
	_fill(image, 160, 0, 160, 180, 38)
	var items: Array = [
		[6, 240], [6, 120], [6, 30], [8, -1], [36, 200], [36, 40], [34, 12], [34, 4],
		[28, 0], [28, 32], [28, 160], [77, -1], [78, -1], [79, -1], [80, -1], [5, -1],
		[4, 240], [4, 120], [4, 30], [4, 5], [22, 180], [22, 90], [22, 20], [37, 120],
		[37, 60], [37, 10], [71, -1],
	]
	var regions: Array = []
	for half: int in range(2):
		for index: int in range(items.size()):
			var x: int = half * 160 + 4 + (index % 7) * 22
			var y: int = 4 + (index / 7) * 44
			if half == 1:
				_fill(image, x - 2, y - 2, 20, 18, 0)
			_fill(image, x, y, 16, 14, int(items[index][0]), int(items[index][1]))
			if half == 0:
				regions.append({"id": int(items[index][0]), "condition": int(items[index][1]),
					"rect": [x, y, 16, 14]})
	return {"current": image, "previous": image, "cameras": [Vector2i.ZERO],
		"notes": "Left: dark (Empty) surround; right: identical items in Empty pockets inside Limestone. Condition bytes: Fire/Smoke 240,120,30(,5); Molten Glass 200/40 heat (synthetic); Spark 12/4; Metal charge 0/32/160 (synthetic); Steam 180/90/20; Foam 120/60/10.",
		"regions": regions, "synthetic": true}


func _transition() -> Dictionary:
	# Known previous/current pairs. Cases A-B change displayed ID with at least
	# one temporally smoothed side (production crossfade); C keeps the ID; D is
	# an unsupported pair. A and B deliberately change the neighbourhood too.
	var previous: Image = _blank(VIEW)
	var current: Image = _blank(VIEW)
	var cases: Array = []
	# A: exposed Water surface becomes buried Sand.
	_fill(previous, 10, 40, 40, 20, 3)
	_fill(current, 10, 30, 40, 30, 2)
	cases.append({"case": "A water->sand, cover changes", "rect": [10, 40, 40, 20], "eligible": true})
	# B: Sand next to Wall becomes Water beside Empty.
	_fill(previous, 70, 30, 40, 30, 2)
	_fill(previous, 110, 30, 4, 30, 1)
	_fill(current, 70, 40, 40, 20, 3)
	cases.append({"case": "B sand->water, neighbours change", "rect": [70, 40, 40, 20], "eligible": true})
	# C: same-ID Sand whose upper neighbours disappear (no crossfade).
	_fill(previous, 130, 30, 40, 30, 2)
	_fill(current, 130, 40, 40, 20, 2)
	cases.append({"case": "C same-id sand", "rect": [130, 40, 40, 20], "eligible": false})
	# D: unsupported Wall -> Stone pair (hard switch).
	_fill(previous, 190, 40, 40, 20, 1)
	_fill(current, 190, 40, 40, 20, 13)
	cases.append({"case": "D unsupported wall->stone", "rect": [190, 40, 40, 20], "eligible": false})
	# E: dissipating Smoke and Fire; a Foam pocket collapses.
	_fill(previous, 250, 30, 30, 30, 4, 40)
	_fill(previous, 282, 30, 30, 30, 37, 20)
	_fill(current, 250, 45, 30, 15, 4, 8)
	cases.append({"case": "E smoke/foam removal", "rect": [250, 30, 62, 30], "eligible": true})
	_fill(previous, 0, 100, 320, 4, 1)
	_fill(current, 0, 100, 320, 4, 1)
	return {"current": current, "previous": previous, "cameras": [Vector2i.ZERO],
		"blends": [0.0, 0.25, 0.5, 0.75, 1.0], "cases": cases,
		"notes": "Explicit previous/current RG8 pairs for crossfade endpoints. References render previous-only and current-only at blend 1.",
		"synthetic": true}


func _street() -> Dictionary:
	var image: Image = _blank(VIEW)
	# Ground: asphalt road, a wet patch with a Water film, an Oil puddle, cobbles.
	_fill(image, 0, 150, 320, 30, 59)
	_fill(image, 60, 150, 70, 30, 60)
	_fill(image, 72, 149, 40, 1, 3)
	_fill(image, 150, 148, 30, 2, 16)
	_fill(image, 200, 150, 120, 30, 41)
	_fill(image, 240, 150, 40, 30, 61)
	# Brick building with glass, a steel annexe, a timber shed and a pipe run.
	_fill(image, 10, 70, 80, 80, 43)
	_fill(image, 20, 85, 18, 22, 35)
	_fill(image, 56, 85, 18, 22, 72)
	_fill(image, 10, 62, 80, 8, 48)
	_fill(image, 100, 90, 60, 60, 62)
	_fill(image, 100, 84, 60, 6, 64)
	_fill(image, 108, 100, 20, 12, 71)
	_fill(image, 135, 100, 16, 50, 65)
	_fill(image, 170, 110, 40, 40, 46)
	_fill(image, 168, 104, 44, 6, 47)
	_fill(image, 220, 60, 90, 90, 58)
	_fill(image, 228, 70, 74, 4, 68)
	_fill(image, 228, 80, 74, 4, 69)
	_fill(image, 230, 92, 30, 1, 77)
	_fill(image, 262, 92, 30, 1, 78)
	_fill(image, 235, 100, 60, 8, 80)
	_fill(image, 228, 115, 30, 20, 50)
	_fill(image, 262, 115, 36, 20, 54)
	_fill(image, 220, 140, 90, 10, 76)
	# Material in motion or reacting: Sand pile, a Water tank, Smoke and Fire.
	for row: int in range(10):
		_fill(image, 175 - row, 100 - row, 30 + row * 2, 1, 2)
	_fill(image, 0, 120, 8, 30, 1)
	_fill(image, 0, 112, 8, 8, 3)
	_fill(image, 180, 40, 30, 20, 4, 200)
	_fill(image, 190, 60, 10, 6, 6, 200)
	_fill(image, 120, 50, 20, 14, 22, 150)
	_fill(image, 30, 40, 26, 10, 37, 90)
	return {"current": image, "previous": image, "cameras": [Vector2i.ZERO],
		"notes": "Synthetic gameplay-scale street composition mixing construction, metals, glass, wet surfaces, liquids and atmosphere.",
		"synthetic": true}


func _reactions() -> Dictionary:
	# Synthetic contact compositions for neighbour-driven presentation.
	var image: Image = _blank(VIEW)
	_fill(image, 0, 170, 320, 10, 1)
	# Deep Water tank (depth shading, surface froth) with a Lava shelf entering it.
	_fill(image, 4, 70, 3, 100, 1)
	_fill(image, 90, 70, 3, 100, 1)
	_fill(image, 7, 95, 83, 75, 3)
	_fill(image, 50, 80, 40, 15, 8)
	_fill(image, 60, 95, 30, 8, 8)
	# Acid pooled on Stone/Metal with a Toxic Sludge puddle.
	_fill(image, 100, 150, 70, 20, 13)
	_fill(image, 110, 140, 50, 10, 12)
	_fill(image, 170, 140, 30, 30, 28)
	_fill(image, 172, 132, 26, 8, 32)
	# Burning timber: Fire against Oak Timber and Wood with burn progress.
	_fill(image, 210, 140, 40, 30, 46, 120)
	_fill(image, 210, 120, 40, 20, 6, 200)
	_fill(image, 252, 150, 20, 20, 7, 160)
	# Neon and LED mounted on brick (rim light), molten glass on stone.
	_fill(image, 100, 20, 110, 60, 43)
	_fill(image, 110, 40, 40, 3, 77)
	_fill(image, 160, 40, 40, 3, 78)
	_fill(image, 130, 55, 50, 4, 80)
	_fill(image, 120, 66, 30, 3, 79)
	_fill(image, 280, 150, 36, 20, 13)
	_fill(image, 284, 140, 28, 10, 36, 220)
	# Free smoke and steam columns (soft edges).
	_fill(image, 222, 40, 22, 60, 4, 200)
	_fill(image, 254, 30, 20, 70, 22, 160)
	_fill(image, 284, 60, 26, 30, 37, 100)
	return {"current": image, "previous": image, "cameras": [Vector2i.ZERO],
		"notes": "Synthetic contact plate: deep Water with Lava entering, Acid/Sludge on Stone and Metal, Fire on Oak Timber/Wood with burn progress, neon/LED on brick, Molten Glass on Stone, free Smoke/Steam/Foam columns.",
		"synthetic": true}


func _shapes() -> Dictionary:
	# Shape-aware fills: the same material in different run widths/orientations.
	var image: Image = _blank(VIEW)
	# Pipes: horizontal runs of bore 3, 5 and 7, a vertical riser and an L joint.
	_fill(image, 4, 6, 120, 3, 68)
	_fill(image, 4, 14, 120, 5, 68)
	_fill(image, 4, 24, 120, 7, 69)
	_fill(image, 130, 6, 5, 60, 68)
	_fill(image, 130, 61, 50, 5, 68)
	_fill(image, 142, 6, 3, 50, 69)
	# Hazard: a large panel, a thin horizontal strip and a thin vertical post.
	_fill(image, 190, 6, 60, 30, 76)
	_fill(image, 190, 42, 120, 4, 76)
	_fill(image, 300, 6, 4, 34, 76)
	# Insulation wall exposed on its left face, cable bundles both ways.
	_fill(image, 4, 40, 50, 40, 75)
	_fill(image, 60, 40, 60, 7, 74)
	_fill(image, 60, 50, 6, 40, 74)
	# Planks both ways and corrugated cladding both ways.
	_fill(image, 72, 52, 50, 15, 46)
	_fill(image, 72, 70, 12, 40, 46)
	_fill(image, 90, 72, 40, 18, 64)
	_fill(image, 90, 94, 14, 36, 64)
	# Stained-glass window set in brick with quoins; tiles; broken concrete.
	_fill(image, 190, 52, 70, 60, 43)
	_fill(image, 205, 62, 40, 36, 55)
	_fill(image, 266, 52, 50, 40, 70)
	_fill(image, 140, 96, 44, 34, 58)
	_fill(image, 162, 118, 22, 12, 0)
	# Neon bars horizontal and vertical.
	_fill(image, 4, 90, 50, 4, 77)
	_fill(image, 4, 100, 50, 3, 78)
	_fill(image, 60, 96, 4, 40, 79)
	_fill(image, 266, 100, 4, 40, 77)
	_fill(image, 276, 104, 40, 5, 79)
	_fill(image, 0, 170, 320, 10, 1)
	_fill(image, 190, 120, 70, 50, 58)
	return {"current": image, "previous": image, "cameras": [Vector2i.ZERO],
		"notes": "Synthetic shape plate: pipes of bore 3/5/7 horizontal, vertical and L-joined; hazard panel, strip and post; insulation, cables, planks and corrugation in both orientations; stained glass in brick; tiles; broken reinforced concrete; neon bars both ways.",
		"synthetic": true}


func _statics() -> Dictionary:
	# Every static material as a block with open air around it, a thin vertical
	# bar and a thin horizontal strip, so shape-aware fills show their edges.
	var image: Image = _blank(VIEW)
	var ids: Array[int] = [1, 5, 7, 9, 28, 31, 35]
	for id: int in range(38, 81):
		ids.append(id)
	var regions: Array = []
	for index: int in range(ids.size()):
		var x: int = 2 + (index % 10) * 32
		var y: int = 3 + (index / 10) * 36
		_fill(image, x, y, 22, 16, ids[index])
		_fill(image, x + 24, y, 3, 22, ids[index])
		_fill(image, x, y + 19, 22, 3, ids[index])
		regions.append({"id": ids[index], "rect": [x, y, 22, 16]})
	return {"current": image, "previous": image, "cameras": [Vector2i.ZERO],
		"notes": "All static materials: 22x16 block, 3-wide vertical bar and 3-tall strip each, open air around.",
		"regions": regions, "synthetic": true}


func _building() -> Dictionary:
	# MAT-002 building catalogue: each material as a block with open air around
	# it, a thin vertical bar and a thin horizontal strip (shape-aware fills).
	var image: Image = _blank(VIEW)
	var regions: Array = []
	var index: int = 0
	for id: int in range(CyberCellWorld.FIRST_BUILDING_MATERIAL, CyberCellWorld.LAST_MATERIAL + 1):
		var x: int = 2 + (index % 9) * 35
		var y: int = 2 + (index / 9) * 29
		_fill(image, x, y, 24, 19, id)
		_fill(image, x + 26, y, 3, 25, id)
		_fill(image, x, y + 22, 24, 3, id)
		regions.append({"id": id, "rect": [x, y, 24, 19]})
		index += 1
	return {"current": image, "previous": image, "cameras": [Vector2i.ZERO],
		"notes": "MAT-002 building materials 81+: 24x19 block, 3-wide vertical bar and 3-tall strip each, open air around.",
		"regions": regions, "synthetic": true}


func _growth() -> Dictionary:
	# Living and firework presentation: Plant, Moss Wall and Fungus mounds with
	# overhangs (flowers, shrooms, vines, hyphae), mites, idle and activated
	# Rockets, Steam/Smoke, Rust, Toxic Sludge, Oil and Mercury pools.
	var image: Image = _blank(VIEW)
	_fill(image, 0, 150, 320, 30, 40)
	_fill(image, 6, 120, 70, 30, 11, 120)
	_fill(image, 20, 70, 50, 10, 11, 120)
	_fill(image, 84, 126, 60, 24, 18, 120)
	_fill(image, 96, 70, 46, 10, 18, 120)
	_fill(image, 152, 112, 40, 38, CyberCellWorld.MOSS_WALL)
	_fill(image, 150, 60, 44, 8, CyberCellWorld.MOSS_WALL)
	for i: int in range(10):
		_put(image, 200 + i * 3, 140 - (i % 3) * 4, 15, 1)
	_fill(image, 236, 120, 3, 6, 17)
	_put(image, 252, 92, 17, 3)
	_put(image, 266, 74, 17, 5)
	_put(image, 280, 60, 17, 2)
	_fill(image, 200, 20, 30, 14, 22, 150)
	_fill(image, 236, 20, 30, 14, 4, 120)
	_fill(image, 272, 20, 40, 14, 4, 20)
	_fill(image, 200, 150, 24, 30, 29)
	_fill(image, 226, 150, 30, 30, 32)
	_fill(image, 258, 150, 30, 30, 16)
	_fill(image, 290, 150, 30, 30, 33)
	_fill(image, 6, 20, 60, 30, CyberCellWorld.PINE_PLANKS)
	_fill(image, 70, 10, 6, 50, CyberCellWorld.BIRCH_LOG)
	_fill(image, 80, 10, 8, 50, CyberCellWorld.OAK_LOG)
	_fill(image, 92, 20, 30, 30, 65)
	return {"current": image, "previous": image, "cameras": [Vector2i.ZERO],
		"notes": "Growth decor, mites, idle/activated Rockets (synthetic flight bytes), Steam/Smoke at two lifetimes, Rust, Toxic Sludge, Oil, Mercury, woods and Rusted Steel.",
		"synthetic": true}


func _snapshot_image(world: Variant) -> Image:
	var packet: Dictionary = world.take_render_snapshot(true)
	var size: Vector2i = Vector2i(1024, 1024)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size.x * size.y * 2)
	var rectangles: PackedInt32Array = packet.get("rectangles", PackedInt32Array())
	var cells: PackedByteArray = packet.get("cells", PackedByteArray())
	for offset: int in range(0, rectangles.size(), 6):
		var px: int = rectangles[offset]
		var py: int = rectangles[offset + 1]
		var pw: int = rectangles[offset + 2]
		var ph: int = rectangles[offset + 3]
		var data_offset: int = rectangles[offset + 4]
		var stride: int = rectangles[offset + 5]
		for row: int in range(ph):
			for byte_index: int in range(pw * 2):
				bytes[((py + row) * size.x + px) * 2 + byte_index] = cells[data_offset + row * stride + byte_index]
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RG8, bytes)


func _laboratory() -> Dictionary:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		return {}
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not world.diagnostic_reset({"workers": 1}):
		return {}
	var host: CyberMicroScenarioHost = Host.new()
	var definition: Dictionary = Pack.laboratory(0)
	if not host.install(world, definition, "Inspect", false):
		push_error(host.last_error)
		return {}
	var ticks: int = 90
	var previous: Image
	for tick: int in range(ticks):
		if tick == ticks - 1:
			previous = _snapshot_image(world)
		if not host.advance():
			push_error(host.last_error)
			return {}
	var current: Image = _snapshot_image(world)
	return {"current": current, "previous": previous,
		"cameras": [Vector2i(16, 62), Vector2i(160, 62)],
		"notes": "Native Materials Laboratory materials/contact-lab seed 0, workers 1, mode Inspect, observers off; previous = full RG8 publication after tick %d, current after tick %d." % [ticks - 1, ticks],
		"scenario": "materials/contact-lab", "seed": 0, "workers": 1, "ticks": ticks,
		"synthetic": false}


# --- Rendering -------------------------------------------------------------

func _make_rig(current: Image, previous: Image, scale: int) -> Dictionary:
	var output_size: Vector2i = VIEW * scale
	var viewport: SubViewport = SubViewport.new()
	viewport.size = output_size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.use_hdr_2d = true # main.gd enables HDR 2D on the root viewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND
	background.size = Vector2(output_size)
	viewport.add_child(background)
	var condition_enabled: float = 1.0
	if fallback_r8:
		current = current.duplicate()
		previous = previous.duplicate()
		current.convert(Image.FORMAT_R8)
		previous.convert(Image.FORMAT_R8)
		condition_enabled = 0.0
	var current_texture: ImageTexture = ImageTexture.create_from_image(current)
	var previous_texture: ImageTexture = ImageTexture.create_from_image(previous)
	var world_size: Vector2 = Vector2(current.get_size())

	var palette: ShaderMaterial = ShaderMaterial.new()
	palette.shader = shaders[PALETTE_FILE]
	palette.set_shader_parameter("world_size_px", world_size)
	palette.set_shader_parameter("view_size_px", Vector2(VIEW))
	palette.set_shader_parameter("view_rect_uv", Vector4(0, 0, 1, 1))
	palette.set_shader_parameter("player_origin_px", Vector2(-1000, -1000))
	palette.set_shader_parameter("condition_projection_enabled", condition_enabled)
	palette.set_shader_parameter("water_presentation_mode", 0.0)
	palette.set_shader_parameter("current_world_texture", current_texture)
	palette.set_shader_parameter("previous_world_texture", previous_texture)
	palette.set_shader_parameter("material_lut", palette_lut)
	palette.set_shader_parameter("material_program_lut", program_lut)
	palette.set_shader_parameter("material_lut_size", Vector2(
		CyberMaterialAppearanceLut.ATLAS_WIDTH, CyberMaterialAppearanceLut.ATLAS_HEIGHT))
	var world_rect: TextureRect = TextureRect.new()
	world_rect.size = Vector2(output_size)
	world_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	world_rect.stretch_mode = TextureRect.STRETCH_SCALE
	world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_rect.texture = current_texture
	world_rect.material = palette
	viewport.add_child(world_rect)

	# Mirrors main.gd setup_glow_pipeline/update_glow_parameters.
	var glow_viewport: SubViewport = SubViewport.new()
	glow_viewport.disable_3d = true
	glow_viewport.transparent_bg = true
	glow_viewport.use_hdr_2d = true
	glow_viewport.size = Vector2i(maxi(80, VIEW.x / 2), maxi(45, VIEW.y / 2))
	glow_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(glow_viewport)
	var emission: ShaderMaterial = ShaderMaterial.new()
	emission.shader = shaders[EMISSION_FILE]
	emission.set_shader_parameter("world_texture", current_texture)
	emission.set_shader_parameter("material_program_lut", program_lut)
	emission.set_shader_parameter("world_size_px", world_size)
	emission.set_shader_parameter("view_size_px", Vector2(VIEW))
	emission.set_shader_parameter("condition_projection_enabled", condition_enabled)
	var source: ColorRect = ColorRect.new()
	source.color = Color.WHITE
	source.size = Vector2(glow_viewport.size)
	source.material = emission
	glow_viewport.add_child(source)
	var composite: ShaderMaterial = ShaderMaterial.new()
	composite.shader = shaders[COMPOSITE_FILE]
	var overlay: TextureRect = TextureRect.new()
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	overlay.texture = glow_viewport.get_texture()
	overlay.material = composite
	overlay.size = Vector2(output_size)
	viewport.add_child(overlay)
	return {"viewport": viewport, "palette": palette, "emission": emission,
		"overlay": overlay, "glow_viewport": glow_viewport, "scale": scale}


func _set_state(rig: Dictionary, camera: Vector2i, time: float, glow: bool, blend: float) -> void:
	var palette: ShaderMaterial = rig.palette
	var emission: ShaderMaterial = rig.emission
	palette.set_shader_parameter("camera_origin_px", Vector2(camera))
	palette.set_shader_parameter("presentation_time_override", time)
	palette.set_shader_parameter("snapshot_blend", blend)
	emission.set_shader_parameter("camera_origin_px", Vector2(camera))
	emission.set_shader_parameter("presentation_time_override", time)
	rig.overlay.visible = glow
	rig.glow_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if glow else SubViewport.UPDATE_DISABLED)


func _grab(rig: Dictionary) -> Image:
	# Two submitted frames: the glow SubViewport must have drawn the new state
	# before the outer viewport samples it.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = rig.viewport.get_texture().get_image()
	# Compatibility HDR 2D keeps sRGB values; conversion clamps like the display.
	image.convert(Image.FORMAT_RGB8)
	return image


func _free_rig(rig: Dictionary) -> void:
	rig.viewport.queue_free()
	await process_frame


func _save(image: Image, plate: String, name: String) -> String:
	var relative: String = plate.path_join(name + ".png")
	DirAccess.make_dir_recursive_absolute(output_dir.path_join(relative).get_base_dir())
	image.save_png(output_dir.path_join(relative))
	return relative


func _save_rg8(image: Image, plate: String, name: String) -> Dictionary:
	var relative: String = plate.path_join(name + ".rg8")
	DirAccess.make_dir_recursive_absolute(output_dir.path_join(plate))
	var data: PackedByteArray = image.get_data()
	var file: FileAccess = FileAccess.open(output_dir.path_join(relative), FileAccess.WRITE)
	file.store_buffer(data)
	file.close()
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return {"path": relative, "size": [image.get_width(), image.get_height()],
		"sha256": context.finish().hex_encode()}


func _capture_plate(plate: String, inputs: Dictionary) -> void:
	var current: Image = inputs.current
	var previous: Image = inputs.previous
	var record: Dictionary = inputs.duplicate()
	record.erase("current")
	record.erase("previous")
	record.current_rg8 = _save_rg8(current, plate, "input-current")
	record.previous_rg8 = _save_rg8(previous, plate, "input-previous")
	record.images = []
	var cameras: Array = inputs.cameras
	var blends: Array = inputs.get("blends", [1.0])

	# Production-scale stills (320x180 logical in a 1920x1080 output).
	var rig: Dictionary = _make_rig(current, previous, 6)
	for camera: Vector2i in cameras:
		for time: float in still_times:
			for glow: bool in [false, true]:
				for blend: float in blends:
					_set_state(rig, camera, time, glow, blend)
					var image: Image = await _grab(rig)
					var name: String = "still_cam%d-%d_t%.2f_%s_b%.2f" % [
						camera.x, camera.y, time, "glow" if glow else "noglow", blend]
					record.images.append({"path": _save(image, plate, name), "camera": [camera.x, camera.y],
						"time": time, "glow": glow, "blend": blend, "output": [VIEW.x * 6, VIEW.y * 6]})
	await _free_rig(rig)

	if plate == "transition":
		# Endpoint references: each snapshot rendered alone at blend 1.
		for side: String in ["previous", "current"]:
			var only: Image = previous if side == "previous" else current
			var reference: Dictionary = _make_rig(only, only, 1)
			_set_state(reference, Vector2i.ZERO, 0.0, false, 1.0)
			var image: Image = await _grab(reference)
			record.images.append({"path": _save(image, plate, "reference_%s_t0.00_noglow" % side),
				"reference": side, "time": 0.0, "glow": false, "blend": 1.0, "output": [VIEW.x, VIEW.y]})
			await _free_rig(reference)
		rig = _make_rig(current, previous, 1)
		for blend: float in blends:
			_set_state(rig, Vector2i.ZERO, 0.0, false, blend)
			var image: Image = await _grab(rig)
			record.images.append({"path": _save(image, plate, "blend_x1_t0.00_noglow_b%.2f" % blend),
				"time": 0.0, "glow": false, "blend": blend, "output": [VIEW.x, VIEW.y]})
		await _free_rig(rig)

	if clip_frames > 0:
		# Fixed-world animation: 1x glow-off frames for temporal measurement and
		# 2x glow-on frames for viewing. Time advances at clip_fps.
		var camera: Vector2i = cameras[0]
		for spec: Array in [[1, false, "anim_x1_noglow"], [2, true, "anim_x2_glow"]]:
			rig = _make_rig(current, previous, int(spec[0]))
			var frames: Array = []
			for frame: int in range(clip_frames):
				_set_state(rig, camera, float(frame) / clip_fps, bool(spec[1]), 1.0)
				var image: Image = await _grab(rig)
				frames.append(_save(image, plate, "%s/f%03d" % [spec[2], frame]))
			record[spec[2]] = {"frames": frames, "fps": clip_fps, "scale": spec[0],
				"glow": spec[1], "camera": [camera.x, camera.y], "time_start": 0.0}
			await _free_rig(rig)
		if inputs.has("pan"):
			# Camera pan with time frozen, then the same pan with time running.
			var pan_from: Vector2i = Vector2i(inputs.pan.from[0], inputs.pan.from[1])
			var pan_to: Vector2i = Vector2i(inputs.pan.to[0], inputs.pan.to[1])
			for running: bool in [false, true]:
				rig = _make_rig(current, previous, 2)
				var frames: Array = []
				var steps: int = maxi(absi(pan_to.x - pan_from.x), absi(pan_to.y - pan_from.y))
				var name: String = "pan_x2_glow_%s" % ("running" if running else "frozen")
				for frame: int in range(steps + 1):
					var camera_at: Vector2i = Vector2i(
						pan_from.x + (pan_to.x - pan_from.x) * frame / steps,
						pan_from.y + (pan_to.y - pan_from.y) * frame / steps)
					_set_state(rig, camera_at, float(frame) / clip_fps if running else 0.0, true, 1.0)
					var image: Image = await _grab(rig)
					frames.append({"path": _save(image, plate, "%s/f%03d" % [name, frame]),
						"camera": [camera_at.x, camera_at.y]})
				record[name] = {"frames": frames, "fps": clip_fps, "scale": 2, "glow": true}
				await _free_rig(rig)
	manifest.plates[plate] = record
