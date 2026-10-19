extends SceneTree

# Actual framebuffer checks of main.gd's production ping-pong owner. The small
# isolated harness supplies immutable world textures and moves the real trail
# SubViewports into the tree without starting a simulation or physics owner.
# Headless node-state checks cannot establish that feedback actually renders.
const MAIN_SCRIPT: Script = preload("res://scripts/main.gd")
const VIEW: Vector2i = Vector2i(48, 24)
var failures: int = 0
var assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	assertions += 1
	if value:
		return
	failures += 1
	push_error(message)


func _vapour_world() -> Image:
	var world: Image = Image.create_empty(CyberCellWorld.WORLD_WIDTH,
		CyberCellWorld.WORLD_HEIGHT, false, Image.FORMAT_RG8)
	world.fill_rect(Rect2i(4, 4, 16, 16), Color(float(CyberCellWorld.STEAM) / 255.0, 1, 0, 1))
	world.fill_rect(Rect2i(28, 4, 16, 16), Color(float(CyberCellWorld.SMOKE) / 255.0, 1, 0, 1))
	return world


func _peak(image: Image) -> float:
	var peak: float = 0.0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			peak = maxf(peak, maxf(pixel.r, pixel.g))
	return peak


func _advance(controller: Control, elapsed_seconds: float = -1.0) -> Image:
	await process_frame
	if elapsed_seconds >= 0.0:
		controller.vapour_trail_usec = Time.get_ticks_usec() - roundi(elapsed_seconds * 1000000.0)
	controller.update_vapour_trail()
	var scheduled: int = controller.vapour_trail_latest
	await RenderingServer.frame_post_draw
	return controller.vapour_trail_viewports[scheduled].get_texture().get_image()


func _publish_snapshot(controller: Control, pixels: Image, serial: int, full_refresh: bool,
		world_generation: int = 1) -> void:
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.serial = serial
	snapshot.render_snapshot_serial = serial
	snapshot.render_world_generation = world_generation
	snapshot.world_revision = serial
	snapshot.render_channels = 2
	snapshot.render_full_refresh = full_refresh
	snapshot.render_patch_rectangles = PackedInt32Array([0, 0,
		CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT, 0, CyberCellWorld.WORLD_WIDTH * 2])
	snapshot.render_patch_cells = pixels.get_data()
	controller.simulation_worker._published_snapshot = snapshot
	controller.consume_worker_snapshot()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("MATERIAL_VAPOUR_PIPELINE: skipped (headless DisplayServer has no frame submission)")
		quit(0)
		return
	var controller: Control = MAIN_SCRIPT.new()
	controller.world_shader = ShaderMaterial.new()
	controller.world_shader.shader = load("res://shaders/material_palette.gdshader")
	controller.world_view = TextureRect.new()
	controller.current_view_size = VIEW
	controller.camera_origin = Vector2.ZERO
	controller.render_channels = 2
	controller.render_image_format = Image.FORMAT_RG8
	controller.last_uploaded_world_generation = 1
	controller.image = _vapour_world()
	controller.texture = ImageTexture.create_from_image(controller.image)
	controller.previous_texture = ImageTexture.create_from_image(controller.image)
	controller.setup_vapour_trail_pipeline()
	controller.setup_vapour_trail_pipeline()
	_expect(controller.vapour_trail_viewports.size() == 2, "repeated setup allocated more than two history buffers")
	for viewport: SubViewport in controller.vapour_trail_viewports:
		viewport.reparent(root)
	for material: ShaderMaterial in controller.vapour_trail_shaders:
		material.set_shader_parameter("presentation_time_override", 0.0)
		material.set_shader_parameter("rise_px_per_second", 0.0)
	var seeded: Image = await _advance(controller)
	_expect(seeded.get_pixel(12, 10).r > 0.9 and seeded.get_pixel(36, 10).g > 0.9,
		"production trail viewports did not seed Steam and Smoke")
	var first: int = controller.vapour_trail_latest
	controller.update_vapour_trail()
	_expect(controller.vapour_trail_latest == first,
		"multiple refresh calls in one frame advanced the history twice")
	var world_size := Vector2i(CyberCellWorld.WORLD_WIDTH, CyberCellWorld.WORLD_HEIGHT)
	var empty := Image.create_empty(world_size.x, world_size.y, false, Image.FORMAT_RG8)
	controller.texture.update(empty)
	controller.paused = true
	var decayed: Image = await _advance(controller, 0.2)
	_expect(controller.vapour_trail_latest != first, "production owner did not alternate its target")
	_expect(decayed.get_pixel(12, 10).r > 0.45 and decayed.get_pixel(12, 10).r < 0.7,
		"paused Steam trail did not decay by elapsed presentation time")
	_expect(decayed.get_pixel(36, 10).g > decayed.get_pixel(12, 10).r,
		"production Smoke trail does not outlast Steam")
	# A slow frame must use its whole elapsed interval, not prolong the trail
	# by clamping the decay to an unrelated simulation-step limit.
	controller.texture.update(_vapour_world())
	await _advance(controller)
	controller.texture.update(empty)
	var after_stall: Image = await _advance(controller, 1.0)
	_expect(after_stall.get_pixel(36, 10).g > 0.17 and _peak(after_stall) < 0.25,
		"a long frame clamped elapsed time and left a stale vapour ghost")

	controller.texture.update(_vapour_world())
	await _advance(controller)
	_publish_snapshot(controller, empty, 1, false)
	controller.camera_origin = Vector2(3, 2)
	var panned: Image = await _advance(controller, 0.2)
	_expect(panned.get_pixel(9, 8).r > 0.45 and panned.get_pixel(9, 8).r < 0.7,
		"ordinary publication lost history or moved it with the camera")
	controller.camera_origin = Vector2.ZERO
	controller.texture.update(_vapour_world())
	await _advance(controller)
	_publish_snapshot(controller, empty, 2, true)
	_expect(_peak(await _advance(controller, 0.2)) > 0.6,
		"a transport full refresh erased history without a World reset")
	controller.texture.update(_vapour_world())
	await _advance(controller)
	_publish_snapshot(controller, empty, 3, true, 2)
	var reset: Image = await _advance(controller, 0.02)
	_expect(_peak(reset) == 0.0, "an accepted World generation retained the previous world's vapour")
	# Both buffers must be invalidated; the second post-reset frame must not
	# resurrect history from the buffer that was not rendered on the first.
	_expect(_peak(await _advance(controller, 0.02)) == 0.0,
		"the other ping-pong buffer resurrected vapour after reset")

	controller.texture.update(_vapour_world())
	await _advance(controller)
	controller.texture.update(empty)
	controller.current_view_size = Vector2i(64, 32)
	var resized: Image = await _advance(controller, 0.02)
	_expect(resized.get_size() == Vector2i(64, 32) and _peak(resized) == 0.0,
		"resizing retained or stretched history from the old viewport")
	controller.current_view_size = VIEW
	var restored_size: Image = await _advance(controller, 0.02)
	_expect(restored_size.get_size() == VIEW and _peak(restored_size) == 0.0,
		"returning to a previous size resurrected an old buffer")

	_expect(controller.has_method("set_vapour_trail_enabled"), "production vapour has no persistent disable control")
	if controller.has_method("set_vapour_trail_enabled"):
		controller.texture.update(_vapour_world())
		await _advance(controller)
		controller.set_vapour_trail_enabled(false)
		for index: int in range(3):
			await process_frame
			controller.update_vapour_trail()
			_expect(controller.world_shader.get_shader_parameter("vapour_trail_strength") == 0.0,
				"the next frame overrode the disabled vapour setting")
			for viewport: SubViewport in controller.vapour_trail_viewports:
				_expect(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
					"disabled vapour still scheduled a framebuffer pass")
		controller.texture.update(empty)
		controller.set_vapour_trail_enabled(true)
		_expect(_peak(await _advance(controller, 0.02)) == 0.0,
			"re-enabling vapour resurrected the disabled history")
		controller.texture.update(_vapour_world())
		_expect(_peak(await _advance(controller)) > 0.9,
			"re-enabled vapour failed to resume current gas recording")

	# The R8 fallback has no projected condition channel. It must use the
	# documented neutral lifetime rather than interpreting missing G as zero.
	controller.reset_vapour_trail()
	var fallback := _vapour_world()
	fallback.convert(Image.FORMAT_R8)
	controller.texture = ImageTexture.create_from_image(fallback)
	controller.render_channels = 1
	var fallback_frame: Image = await _advance(controller)
	_expect(absf(fallback_frame.get_pixel(12, 10).r - 0.91) < 0.02 and
		absf(fallback_frame.get_pixel(36, 10).g - 0.86) < 0.02,
		"R8 vapour used a missing condition byte")

	# Keep raw float framebuffer evidence outside the source tree. The CI
	# harness may select its artifact directory with this optional variable.
	var evidence: String = OS.get_environment("CYBERSAND_PRESENTATION_EVIDENCE")
	if not evidence.is_empty():
		DirAccess.make_dir_recursive_absolute(evidence)
		seeded.save_exr(evidence.path_join("vapour-seeded.exr"))
		decayed.save_exr(evidence.path_join("vapour-decayed.exr"))
		reset.save_exr(evidence.path_join("vapour-reset.exr"))
	for viewport: SubViewport in controller.vapour_trail_viewports:
		viewport.queue_free()
	controller.world_view.free()
	controller.free()
	await process_frame
	print("MATERIAL_VAPOUR_PIPELINE: actual pixels, %d assertions, %d failures" % [assertions, failures])
	quit(failures)
