extends SceneTree

# Matched presentation-cost comparison (capture apparatus, not a regression).
# Renders identical RG8 input at the production 320x180 view in a 1920x1080
# HDR 2D viewport through two sets of presentation sources, interleaved in
# blocks, and records RenderingServer per-viewport measured GPU render time
# for the world viewport and the glow-source viewport. Graphical only.
#   <godot> --path godot --script res://tests/measure_material_presentation_cost.gd -- \
#     --output=<file.json> --a-root=<dir> --a-lut=<path> [--b-root=res://shaders]
#     [--frames=300] [--blocks=6]

const VIEW: Vector2i = Vector2i(320, 180)
const OUTPUT: Vector2i = Vector2i(1920, 1080)
var arguments: Dictionary = {
	"output": "", "a-root": "res://shaders", "a-lut": "res://scripts/material_appearance_lut.gd",
	"b-root": "res://shaders", "b-lut": "res://scripts/material_appearance_lut.gd",
	"frames": "300", "blocks": "6", "warmup": "120",
}


func _init() -> void:
	call_deferred("_run")


func _source(root_dir: String, lut_path: String) -> Dictionary:
	var shaders: Dictionary = {}
	for name: String in ["material_palette.gdshader", "material_emission.gdshader", "glow_composite.gdshader"]:
		var shader: Shader = Shader.new()
		shader.code = FileAccess.get_file_as_string(root_dir.path_join(name))
		shaders[name] = shader
	var script: GDScript = GDScript.new()
	script.source_code = FileAccess.get_file_as_string(lut_path).replace("class_name CyberMaterialAppearanceLut", "")
	script.reload()
	return {"shaders": shaders, "lut": script.call("create_texture"), "program": script.call("create_program_texture")}


func _street() -> Image:
	# Same composition as the capture fixture's street plate, tiled across a
	# 1024x1024 world so the camera sits inside representative content.
	var image: Image = Image.create_empty(1024, 1024, false, Image.FORMAT_RG8)
	image.fill(Color(0, 0, 0, 1))
	var ids: Array[int] = [43, 35, 72, 62, 64, 71, 65, 46, 58, 68, 69, 77, 78, 80, 50, 54, 76, 59, 60, 41, 61, 3, 16, 2, 4, 22, 37, 20, 21, 24, 30, 33]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261018
	for index: int in range(900):
		var w: int = rng.randi_range(6, 40)
		var h: int = rng.randi_range(4, 30)
		var x: int = rng.randi_range(0, 1024 - w)
		var y: int = rng.randi_range(0, 1024 - h)
		var id: int = ids[rng.randi_range(0, ids.size() - 1)]
		var condition: int = 255 if id == 3 else (200 if id in [4, 22, 37] else 0)
		image.fill_rect(Rect2i(x, y, w, h), Color(id / 255.0, condition / 255.0, 0, 1))
	return image


func _effects() -> Image:
	var image: Image = Image.create_empty(1024, 1024, false, Image.FORMAT_RG8)
	image.fill(Color(0, 0, 0, 1))
	var ids: Array[int] = [6, 8, 36, 34, 28, 77, 78, 79, 80, 5, 4, 22, 37, 12, 32, 33]
	for y: int in range(0, 1024, 6):
		for x: int in range(0, 1024, 8):
			var id: int = ids[(x / 8 + y / 6) % ids.size()]
			var condition: int = 160 if id in [6, 4, 22, 37, 28, 36] else (12 if id == 34 else 0)
			image.fill_rect(Rect2i(x, y, 7, 5), Color(id / 255.0, condition / 255.0, 0, 1))
	return image


func _living() -> Image:
	# Second-pass content: Plant/Fungus/Moss Wall hosts with open air (growth
	# decor scans), building catalogue panels, Rust, Sludge, Oil, Mercury,
	# Steam/Smoke, Mites and flying Rockets.
	var image: Image = Image.create_empty(1024, 1024, false, Image.FORMAT_RG8)
	image.fill(Color(0, 0, 0, 1))
	var ids: Array[int] = [11, 18, 97, 29, 65, 32, 16, 33, 22, 4, 15, 17]
	for id: int in range(81, 132):
		ids.append(id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261019
	for index: int in range(700):
		var w: int = rng.randi_range(6, 36)
		var h: int = rng.randi_range(3, 24)
		var x: int = rng.randi_range(0, 1024 - w)
		var y: int = rng.randi_range(0, 1024 - h)
		var id: int = ids[rng.randi_range(0, ids.size() - 1)]
		var condition: int = 200 if id in [4, 22] else (3 if id == 17 else (64 if id in [11, 18] else 0))
		image.fill_rect(Rect2i(x, y, w, h), Color(id / 255.0, condition / 255.0, 0, 1))
	return image


func _rig(source: Dictionary, world: Image, glow: bool) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = OUTPUT
	viewport.disable_3d = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var texture: ImageTexture = ImageTexture.create_from_image(world)
	var palette: ShaderMaterial = ShaderMaterial.new()
	palette.shader = source.shaders["material_palette.gdshader"]
	for pair: Array in [["world_size_px", Vector2(1024, 1024)], ["view_size_px", Vector2(VIEW)],
			["view_rect_uv", Vector4(0, 0, 1, 1)], ["camera_origin_px", Vector2(352, 420)],
			["player_origin_px", Vector2(-100, -100)], ["condition_projection_enabled", 1.0],
			["snapshot_blend", 0.5], ["current_world_texture", texture], ["previous_world_texture", texture],
			["material_lut", source.lut], ["material_program_lut", source.program],
			["material_lut_size", Vector2(64, 256)]]:
		palette.set_shader_parameter(pair[0], pair[1])
	var rect: TextureRect = TextureRect.new()
	rect.size = Vector2(OUTPUT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = texture
	rect.material = palette
	viewport.add_child(rect)
	var glow_viewport: SubViewport = SubViewport.new()
	glow_viewport.size = VIEW / 2
	glow_viewport.use_hdr_2d = true
	glow_viewport.transparent_bg = true
	glow_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if glow else SubViewport.UPDATE_DISABLED)
	viewport.add_child(glow_viewport)
	var emission: ShaderMaterial = ShaderMaterial.new()
	emission.shader = source.shaders["material_emission.gdshader"]
	for pair: Array in [["world_texture", texture], ["material_program_lut", source.program],
			["world_size_px", Vector2(1024, 1024)], ["view_size_px", Vector2(VIEW)],
			["camera_origin_px", Vector2(352, 420)], ["condition_projection_enabled", 1.0]]:
		emission.set_shader_parameter(pair[0], pair[1])
	var emitter: ColorRect = ColorRect.new()
	emitter.size = Vector2(glow_viewport.size)
	emitter.material = emission
	glow_viewport.add_child(emitter)
	var overlay: TextureRect = TextureRect.new()
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	overlay.texture = glow_viewport.get_texture()
	var composite: ShaderMaterial = ShaderMaterial.new()
	composite.shader = source.shaders["glow_composite.gdshader"]
	overlay.material = composite
	overlay.size = Vector2(OUTPUT)
	overlay.visible = glow
	viewport.add_child(overlay)
	for target: SubViewport in [viewport, glow_viewport]:
		RenderingServer.viewport_set_measure_render_time(target.get_viewport_rid(), true)
	return {"viewport": viewport, "glow_viewport": glow_viewport}


func _percentile(values: Array, fraction: float) -> float:
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[clampi(int(round(fraction * (sorted.size() - 1))), 0, sorted.size() - 1)])


func _run() -> void:
	for raw: String in OS.get_cmdline_user_args():
		if raw.begins_with("--") and "=" in raw:
			arguments[raw.substr(2, raw.find("=") - 2)] = raw.substr(raw.find("=") + 1)
	if DisplayServer.get_name() == "headless":
		print("MATERIAL_PRESENTATION_COST: skipped (headless)")
		quit(0)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var sources: Dictionary = {
		"a": _source(arguments["a-root"], arguments["a-lut"]),
		"b": _source(arguments["b-root"], arguments["b-lut"]),
	}
	var scenes: Dictionary = {"mixed": _street(), "effects": _effects(), "living": _living()}
	var frames: int = int(arguments.frames)
	var samples: Dictionary = {}
	for block: int in range(int(arguments.blocks)):
		for scene: String in scenes:
			for glow: bool in [false, true]:
				var order: Array = ["a", "b"] if block % 2 == 0 else ["b", "a"]
				for label: String in order:
					var key: String = "%s/%s/%s" % [scene, "glow" if glow else "noglow", label]
					var rig: Dictionary = _rig(sources[label], scenes[scene], glow)
					for warm: int in range(int(arguments.warmup) if block == 0 else 20):
						await RenderingServer.frame_post_draw
					if not samples.has(key):
						samples[key] = {"world_gpu_ms": [], "glow_gpu_ms": [], "frame_cpu_ms": []}
					var previous_usec: int = Time.get_ticks_usec()
					for frame: int in range(frames):
						await RenderingServer.frame_post_draw
						var now: int = Time.get_ticks_usec()
						samples[key].world_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rig.viewport.get_viewport_rid()))
						samples[key].glow_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rig.glow_viewport.get_viewport_rid()))
						samples[key].frame_cpu_ms.append(float(now - previous_usec) / 1000.0)
						previous_usec = now
					rig.viewport.queue_free()
					await process_frame
	var summary: Dictionary = {
		"adapter": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"godot": Engine.get_version_info().string,
		"view": [VIEW.x, VIEW.y], "output": [OUTPUT.x, OUTPUT.y],
		"frames_per_block": frames, "blocks": int(arguments.blocks), "snapshot_blend": 0.5,
		"a_root": arguments["a-root"], "b_root": arguments["b-root"],
		"metrics": "world_gpu_ms/glow_gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu for the 1920x1080 world viewport and the 160x90 glow source; frame_cpu_ms = wall time between frame_post_draw signals (whole application frame, vsync off)",
		"results": {},
	}
	for key: String in samples:
		var entry: Dictionary = {}
		for metric: String in samples[key]:
			var values: Array = samples[key][metric]
			entry[metric] = {"median": snappedf(_percentile(values, 0.5), 0.0001),
				"p95": snappedf(_percentile(values, 0.95), 0.0001), "n": values.size()}
		summary.results[key] = entry
		print("%-22s world median %.4f p95 %.4f | glow median %.4f | frame median %.3f" % [key,
			entry.world_gpu_ms.median, entry.world_gpu_ms.p95, entry.glow_gpu_ms.median, entry.frame_cpu_ms.median])
	if not str(arguments.output).is_empty():
		var file: FileAccess = FileAccess.open(arguments.output, FileAccess.WRITE)
		file.store_string(JSON.stringify(summary, "  ") + "\n")
		file.close()
	quit(0)
