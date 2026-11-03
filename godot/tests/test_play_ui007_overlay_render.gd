extends SceneTree

const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

# Graphical unit only: real pixels from the production target overlay, without
# Main, native jobs, actor bodies, terrain shaders or gameplay qualification.
# A headless invocation fails explicitly instead of reporting a skipped pass.
const Overlay = preload("res://scripts/playable_course_overlay.gd")
const Course = preload("res://scripts/player_playground_course.gd")
var assertions: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_UI007_PIXELS: " + message)


func ring_alpha(image: Image, point: Vector2, radius: float) -> float:
	var centre := Vector2i((point + Vector2(radius,0)).floor())
	var maximum: float = 0.0
	for y: int in range(centre.y-2, centre.y+3):
		for x: int in range(centre.x-2, centre.x+3):
			if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
				maximum = maxf(maximum, image.get_pixel(x,y).a)
	return maximum


func save_capture(image: Image, path: String) -> Dictionary:
	expect(image.save_png(path) == OK, "raw overlay pixels are retained")
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return {"path":path,"sha256":context.finish().hex_encode(),
		"width":image.get_width(),"height":image.get_height()}


func run() -> void:
	var started: int = Time.get_ticks_usec()
	expect(DisplayServer.get_name() != "headless", "a real graphical display is required for pixel assertions")
	expect(OS.get_environment("CYBERSAND_SOURCE_REVISION").length() == 40,
		"a complete executed source revision is retained with the raw pixels")
	var directory: String = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	expect(not directory.is_empty(), "an explicit raw graphical artifact directory is required")
	if failures > 0:
		quit(1)
		return
	expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "graphical artifact directory is writable")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024,512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var overlay: Control = Overlay.new()
	viewport.add_child(overlay)
	for rig: StringName in Course.MECHANICAL_PRESETS:
		var case_started: int = Time.get_ticks_usec()
		var identity: Dictionary = {"rig":str(rig),"actor_epoch":1,"world_generation":1,
			"source_tick":1,"physics_tick":1,"target_index":0}
		overlay.present_course(identity,Vector2(Course.VIEW.position),Course.VIEW.size,Rect2(0,0,1024,512))
		await RenderingServer.frame_post_draw
		var initial: Image = viewport.get_texture().get_image()
		expect(not initial.is_empty() and initial.get_used_rect().size != Vector2i.ZERO,
			str(rig) + ": actual graphical overlay produces nontransparent pixels")
		var alphas: Array[float] = []
		for index: int in range(4):
			alphas.append(ring_alpha(initial,overlay._point(Course.checkpoints(rig)[index]),26.0))
		expect(alphas[0] >= 0.8 and alphas[1] > 0.1 and alphas[1] < 0.4
			and alphas[2] > 0.1 and alphas[2] < 0.4 and alphas[3] > 0.1 and alphas[3] < 0.4,
			str(rig) + ": next target and all future rings appear at exact authored world coordinates")
		var record: Dictionary = {"rig":str(rig),"initial_alpha":alphas,
			"initial":save_capture(initial,directory.path_join(str(rig)+"-targets.png"))}
		identity.target_index = 2
		overlay.present_course(identity,Vector2(Course.VIEW.position),Course.VIEW.size,Rect2(0,0,1024,512))
		await RenderingServer.frame_post_draw
		var completed: Image = viewport.get_texture().get_image()
		alphas = []
		for index: int in range(4):
			alphas.append(ring_alpha(completed,overlay._point(Course.checkpoints(rig)[index]),26.0))
		expect(alphas[0] > 0.4 and alphas[0] < 0.7 and alphas[1] > 0.4 and alphas[1] < 0.7
			and alphas[2] >= 0.8 and alphas[3] > 0.1 and alphas[3] < 0.4,
			str(rig) + ": completed/current/future target states produce distinct actual pixels")
		record.completed_alpha = alphas
		record.completed = save_capture(completed,directory.path_join(str(rig)+"-completed.png"))
		# Deliberately invalid presentation-only identity is the negative control.
		identity.actor_epoch = -1
		overlay.present_course(identity,Vector2(Course.VIEW.position),Course.VIEW.size,Rect2(0,0,1024,512))
		await RenderingServer.frame_post_draw
		var cleared: Image = viewport.get_texture().get_image()
		expect(not overlay.visible and cleared.get_used_rect().size == Vector2i.ZERO,
			str(rig) + ": invalid identity removes all actual target pixels")
		record.invalid_identity_cleared = cleared.get_used_rect().size == Vector2i.ZERO
		record.elapsed_usec = Time.get_ticks_usec()-case_started
		expect(record.elapsed_usec <= Watchdogs.microseconds("operation_seconds"), str(rig) + ": graphical unit respects configured operation watchdog")
		rows.append(record)
	viewport.queue_free()
	await process_frame
	expect(Time.get_ticks_usec()-started <= Watchdogs.microseconds("complex_fixture_seconds"), "complete graphical unit respects configured fixture watchdog")
	print("PLAY_UI007_PIXELS_RESULT ",JSON.stringify({"schema":"play-ui007-pixels-v1",
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"assertions":assertions,"failures":failures,"rows":rows,"elapsed_usec":Time.get_ticks_usec()-started,
		"display_server":DisplayServer.get_name(),"real_graphical_pixels":true,
		"presentation_identity_is_model":true,"main_host_qualified":false,"native_worker_qualified":false,
		"rapier_actor_qualified":false,"terrain_output_qualified":false,"main_startup_qualified":false,
		"rendered_fps_measured":false,"physical_devices_qualified":false,"human_feel_qualified":false}))
	quit(0 if failures == 0 else 1)
