extends SceneTree

# Actual source/composite/history owners from Main, without starting a native
# World or physics session. Headless transforms cannot establish these pixels.
const Context = preload("res://tests/palette_qualification_context.gd")
const VIEW := Vector2i(48, 27)
const OUTPUT := VIEW * 4
const WORLD := Vector2i(128, 96)
const TOLERANCE := 2.0 / 255.0
const GLOW_FIXTURE_EMISSION_INTENSITY := 16.0

class QuietMain extends "res://scripts/main.gd":
	var freeze_glow_layout_for_timing := false
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _notification(_what: int) -> void: pass
	func _exit_tree() -> void: pass
	func update_glow_parameters(content: Rect2) -> void:
		if not freeze_glow_layout_for_timing:
			super.update_glow_parameters(content)

var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var viewport: SubViewport
var host: Control
var artifact_dir := ""
var pacing: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("NATIVE_CAMERA_EFFECTS: " + message)


func _blank() -> Image:
	var result := Image.create_empty(WORLD.x, WORLD.y, false, Image.FORMAT_RG8)
	result.fill(Color(0, 0, 0, 1))
	return result


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	return result


func _retain(pixels: Image, label: String) -> void:
	if artifact_dir.is_empty(): return
	_check(pixels.save_png(artifact_dir.path_join(label + ".png")) == OK,
		"retain " + label)


func _colour_error(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _shift_error(before: Image, after: Image, shift: Vector2i) -> float:
	var error := 0.0
	for y: int in range(8, OUTPUT.y - 8):
		for x: int in range(8, OUTPUT.x - 8):
			error = maxf(error, _colour_error(after.get_pixel(x, y),
				before.get_pixel(x + shift.x, y + shift.y)))
	return error


func _mount() -> void:
	viewport = SubViewport.new()
	viewport.size = OUTPUT
	viewport.disable_3d = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	host = load("res://main.tscn").instantiate()
	host.set_script(QuietMain)
	for body: RigidBody2D in host.get_node("RigidBodies").get_children():
		body.freeze = true
	viewport.add_child(host)
	# Keep the real scene's onready references, then isolate the canvas.
	host.world_view.reparent(host)
	host.get_node("Layout").hide()
	host.world_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.world_view.custom_minimum_size = Vector2.ZERO
	host.world_view.position = Vector2.ZERO
	host.world_view.size = Vector2(OUTPUT)
	host.world_view.material = null
	host.world_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.current_view_size = VIEW
	host.world_extent = WORLD
	host.character_position = Vector2(-1000, -1000)
	host.cadence_lod_enabled = false
	host.render_channels = 2
	host.image = _blank()
	host.texture = ImageTexture.create_from_image(host.image)
	host.previous_texture = ImageTexture.create_from_image(host.image)
	host.world_shader = ShaderMaterial.new()
	host.world_shader.shader = CyberPaletteShader.for_current_renderer(
		load("res://shaders/material_palette.gdshader"))
	Context.emit(get_script().resource_path, host.world_shader.shader)
	host.material_appearance_lut = CyberMaterialAppearanceLut.create_texture()
	host.material_appearance_program = CyberMaterialAppearanceLut.create_program_texture()
	host.setup_glow_pipeline()
	host.glow_source_shader.set_shader_parameter("presentation_time_override", 0.0)
	for shader: ShaderMaterial in host.vapour_trail_shaders:
		shader.set_shader_parameter("presentation_time_override", 0.0)
		shader.set_shader_parameter("rise_px_per_second", 0.0)


func _glow() -> void:
	# A static, neutral emission row avoids animation or material appearance
	# changing the independent translation oracle. The production emission and
	# composite shaders remain unchanged and use the production viewport owner.
	# Keep the test signal strong enough that retaining a frame differs by more
	# than the unchanged 2/255 translation tolerance in each tested direction.
	# Intensity 2 produced only 2/255 axial gradients on ANGLE: that negative
	# control correctly failed and was not sufficient qualification evidence.
	var program := Image.create_empty(4, 256, false, Image.FORMAT_RGBAH)
	program.set_pixel(1, 58, Color(0, 1, 1, 1))
	program.set_pixel(2, 58, Color(1, 1, GLOW_FIXTURE_EMISSION_INTENSITY, GLOW_FIXTURE_EMISSION_INTENSITY))
	program.set_pixel(3, 58, Color(0.3, 0.6, 1.0, 0))
	host.glow_source_shader.set_shader_parameter("material_program_lut",
		ImageTexture.create_from_image(program))
	var world := _blank()
	world.set_pixel(50, 36, Color(58.0 / 255.0, 1, 0, 1))
	host.texture.update(world)
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE, Vector2i.LEFT]:
		host.camera_origin = Vector2(31.5, 24.25)
		host.update_glow_parameters(host.view_content_rect())
		var before: Image = await _capture()
		var baseline := before
		var maximum := 0.0
		for step: int in range(1, 13):
			host.camera_origin = Vector2(31.5, 24.25) + Vector2(direction) * float(step) / 4.0
			host.update_glow_parameters(host.view_content_rect())
			var after: Image = await _capture()
			var error := _shift_error(before, after, direction)
			maximum = maxf(maximum, error)
			_check(error <= TOLERANCE,
				"glow moved by one display pixel %s step %d (error %.6f)" % [direction, step, error])
			before = after
		var negative_error := _shift_error(baseline, baseline, direction)
		records.append({"kind":"glow", "direction":[direction.x, direction.y],
			"steps":12, "maximum_pixel_error":maximum,
			"negative_control_pixel_error":negative_error,
			"translation_tolerance":TOLERANCE,
			"fixture_emission_intensity":GLOW_FIXTURE_EMISSION_INTENSITY})
		_check(negative_error > TOLERANCE,
			"glow negative control detects a retained/stepped frame %s (error %.6f; tolerance %.6f)"
			% [direction, negative_error, TOLERANCE])
		if direction == Vector2i.RIGHT:
			_retain(baseline, "glow-before")
			_retain(before, "glow-after-12-pixels")
	_check(host.glow_viewport.size == Vector2i(91, 56),
		"odd-height view retains bounded half-resolution grid and halo guards")


func _vapour() -> void:
	host.set_glow_enabled(false)
	host.camera_origin = Vector2(32.25, 24.25)
	host.world_view.texture = host.texture
	host.world_view.material = host.world_shader
	host.world_shader.set_shader_parameter("current_world_texture", host.texture)
	host.world_shader.set_shader_parameter("previous_world_texture", host.previous_texture)
	host.world_shader.set_shader_parameter("material_lut", host.material_appearance_lut)
	host.world_shader.set_shader_parameter("material_program_lut", host.material_appearance_program)
	host.world_shader.set_shader_parameter("presentation_time_override", 0.0)
	host.world_shader.set_shader_parameter("growth_decor", 0.0)
	var gas := _blank()
	gas.fill_rect(Rect2i(80, 24, 1, 28), Color(float(CyberCellWorld.STEAM) / 255.0, 1, 0, 1))
	gas.fill_rect(Rect2i(32, 51, 49, 1), Color(float(CyberCellWorld.STEAM) / 255.0, 1, 0, 1))
	host.texture.update(gas)
	host.reset_vapour_trail()
	host.update_shader_parameters()
	await _capture()
	host.texture.update(_blank())
	await process_frame
	host.vapour_trail_usec = Time.get_ticks_usec() - 20000
	host.update_shader_parameters()
	var remembered: Image = await _capture()
	_check(host.vapour_trail_viewports[0].size == VIEW + Vector2i.ONE
		and host.vapour_trail_viewports[1].size == VIEW + Vector2i.ONE,
		"both vapour generations include partial edge cells")
	_check(host.world_shader.get_shader_parameter("vapour_trail_size_px") == Vector2(VIEW + Vector2i.ONE),
		"palette knows the actual guarded history extent")
	# The legacy extent drops precisely these partially visible cells. Prove
	# that the positive uses the guard, not some unrelated scene brightness.
	host.world_shader.set_shader_parameter("vapour_trail_size_px", Vector2(VIEW))
	var wrong_extent: Image = await _capture()
	for point: Vector2i in [Vector2i(OUTPUT.x - 1, OUTPUT.y / 2),
			Vector2i(OUTPUT.x / 2, OUTPUT.y - 1), OUTPUT - Vector2i.ONE]:
		_check(_colour_error(remembered.get_pixelv(point), wrong_extent.get_pixelv(point)) > 0.08,
			"vapour guard supplies the partial edge cell " + str(point))
	host.world_shader.set_shader_parameter("vapour_trail_size_px", Vector2(VIEW + Vector2i.ONE))
	host.camera_origin += Vector2(0.25, 0.25)
	host.world_shader.set_shader_parameter("camera_origin_px", host.presentation_camera_origin())
	host.configure_pixel_camera(host.world_shader)
	var shifted: Image = await _capture()
	var error := _shift_error(remembered, shifted, Vector2i.ONE)
	_check(error <= TOLERANCE, "fixed vapour history follows one display-pixel translation")
	records.append({"kind":"vapour", "partial_edges":3, "maximum_pixel_error":error})
	_retain(remembered, "vapour-guarded")
	_retain(wrong_extent, "vapour-missing-guard-negative-control")


func _percentile(values: Array[int], fraction: float) -> int:
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(fraction * sorted.size()) - 1, 0, sorted.size() - 1)] if not sorted.is_empty() else 0


func _measure_effect_cohort(label: String, legacy_glow_grid: bool) -> Dictionary:
	# Freeze only the static glow layout, equally in all three cohorts. This
	# avoids measuring repeated viewport reallocations when installing the
	# literal former grid. Main still submits its palette and alternates the
	# real vapour history owner on every measured frame; every pass renders.
	host.freeze_glow_layout_for_timing = false
	host.update_glow_parameters(host.view_content_rect())
	if legacy_glow_grid:
		var size := Vector2i(maxi(80, host.current_view_size.x / 2),
			maxi(45, host.current_view_size.y / 2))
		host.glow_viewport.size = size
		host.glow_source.size = Vector2(size)
		host.glow_source_shader.set_shader_parameter("view_size_px", Vector2(host.current_view_size))
		host.glow_source_shader.set_shader_parameter("camera_origin_px", host.camera_origin.floor())
		host.glow_composite_shader.set_shader_parameter("source_uv_offset", Vector2.ZERO)
		host.glow_composite_shader.set_shader_parameter("source_uv_scale", Vector2.ONE)
	host.freeze_glow_layout_for_timing = true
	host.reset_vapour_trail()
	for frame: int in range(8):
		host.update_shader_parameters()
		await RenderingServer.frame_post_draw
	var frames_usec: Array[int] = []
	var uniforms_usec: Array[int] = []
	var start: int = Time.get_ticks_usec()
	for frame: int in range(30):
		var frame_start: int = Time.get_ticks_usec()
		host.update_shader_parameters()
		uniforms_usec.append(Time.get_ticks_usec() - frame_start)
		await RenderingServer.frame_post_draw
		frames_usec.append(Time.get_ticks_usec() - frame_start)
		if Time.get_ticks_usec() - start >= 1000000: break
	var elapsed: int = Time.get_ticks_usec() - start
	_check(not frames_usec.is_empty() and elapsed > 0, "actual rendered whole-effects pacing samples " + label)
	var glow_size: Vector2i = host.glow_viewport.size
	var trail_size: Vector2i = host.vapour_trail_viewports[0].size
	return {"label":label, "legacy_glow_grid":legacy_glow_grid,
		"glow_source_pixels":[glow_size.x, glow_size.y], "vapour_source_pixels":[trail_size.x, trail_size.y],
		"frame_count":frames_usec.size(), "requested_frames":30, "warmup_frames":8,
		"measurement_budget_usec":1000000, "budget_limited":frames_usec.size() < 30,
		"elapsed_usec":elapsed, "frame_median_usec":_percentile(frames_usec, 0.5),
		"frame_p95_usec":_percentile(frames_usec, 0.95),
		"uniform_median_usec":_percentile(uniforms_usec, 0.5),
		"uniform_p95_usec":_percentile(uniforms_usec, 0.95),
		"frame_samples_usec":frames_usec, "uniform_samples_usec":uniforms_usec}


func _measure_effects() -> void:
	# A/B/A isolates the extra glow guard cost within the actual whole effects
	# pipeline. The palette, new native mapping, and guarded vapour history are
	# identical in all cohorts. This is explicitly not an old-application build
	# comparison, a physics benchmark, or a timing assertion on shared CI hosts.
	viewport.size = Vector2i(960, 540)
	host.world_view.size = Vector2(viewport.size)
	host.current_view_size = Vector2i(240, 135)
	host.world_extent = Vector2i(512, 288)
	host.camera_origin = Vector2(63.25, 60.25)
	var world := Image.create_empty(512, 288, false, Image.FORMAT_RG8)
	world.fill(Color(0, 0, 0, 1))
	for y: int in range(0, 288, 16):
		for x: int in range(0, 512, 16):
			var cell_id: int = CyberCellWorld.LAVA if (x / 16 + y / 16) % 2 == 0 else CyberCellWorld.STEAM
			world.fill_rect(Rect2i(x, y, 12, 12), Color(float(cell_id) / 255.0, 1, 0, 1))
	host.texture = ImageTexture.create_from_image(world)
	host.previous_texture = ImageTexture.create_from_image(world)
	host.world_view.texture = host.texture
	host.world_shader.set_shader_parameter("previous_world_texture", host.previous_texture)
	host.glow_source_shader.set_shader_parameter("world_texture", host.texture)
	host.glow_source_shader.set_shader_parameter("material_program_lut", host.material_appearance_program)
	host.set_glow_enabled(true)
	host.set_vapour_trail_enabled(true)
	var old_vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var guarded_before: Dictionary = await _measure_effect_cohort("guarded-before", false)
	var old_grid: Dictionary = await _measure_effect_cohort("former-glow-grid-control", true)
	var guarded_after: Dictionary = await _measure_effect_cohort("guarded-after", false)
	DisplayServer.window_set_vsync_mode(old_vsync)
	host.freeze_glow_layout_for_timing = false
	var mean_guarded_median := (float(guarded_before.frame_median_usec) + float(guarded_after.frame_median_usec)) / 2.0
	pacing = {"schema":"native-camera-effects-pacing-v1", "advisory":true,
		"scope":"actual Main palette, emission/composite and alternating vapour history; static camera/world; static glow layout frozen equally; no native simulation; no image readback during timing; CPU/GPU/frame wait combined",
		"control":"former unguarded glow dimensions and UV mapping only; current palette/native mapping and guarded vapour history in all cohorts",
		"output_pixels":[960, 540], "view_cells":[240, 135], "world_cells":[512, 288],
		"vsync":"requested disabled; driver/compositor may constrain cadence",
		"cohorts":[guarded_before, old_grid, guarded_after],
		"guarded_to_old_grid_median_ratio":mean_guarded_median / float(maxi(int(old_grid.frame_median_usec), 1)),
		"repeat_guarded_median_ratio":float(guarded_after.frame_median_usec) / float(maxi(int(guarded_before.frame_median_usec), 1))}


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("NATIVE_CAMERA_EFFECTS_RESULT " + JSON.stringify({"checks":0,"failures":[],"skipped":"graphical display required"}))
		quit(0)
		return
	artifact_dir = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if not artifact_dir.is_empty():
		artifact_dir = artifact_dir.path_join("camera-effects")
		DirAccess.make_dir_recursive_absolute(artifact_dir)
	_mount()
	await _glow()
	await _vapour()
	await _measure_effects()
	viewport.queue_free()
	await process_frame
	var result := {"checks":checks, "failures":failures, "records":records, "comparative_pacing":pacing}
	if not artifact_dir.is_empty():
		var receipt := FileAccess.open(artifact_dir.path_join("effects-render.json"), FileAccess.WRITE)
		if receipt != null: receipt.store_string(JSON.stringify(result, "\t") + "\n")
	print("NATIVE_CAMERA_EFFECTS_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
