extends SceneTree

# Actual offscreen framebuffer submission on the selected graphical backend.
# The main window may be minimized; SubViewport.UPDATE_ALWAYS still draws the
# real pixel overlay. Headless node-state checks live in test_flyer_emission.
const Session = preload("res://scripts/physical_actor_session.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const Preferences = preload("res://scripts/flyer_preferences.gd")
const Overlay = preload("res://scripts/physical_actor_overlay.gd")
const VIEW := Vector2i(128, 96)
var checks: int = 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var host: Node2D
var viewport: SubViewport
var overlay: Control

func _initialize() -> void: run.call_deferred()

func check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures.append(detail)
		push_error("FLYER_EXHAUST_RENDER: " + detail)

func definition(model: String) -> Dictionary:
	return {"model":model,"instance_id":1,"producer":"human","position":Vector2(64, 48),
		"canvas_extent":Vector2i(512,512),"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,
		"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0,
		"customization":Preferences.tuning_defaults(Fleet.capabilities(Fleet.index_for_id(model)))}}

func capture(parts: Array, label: String) -> Image:
	overlay.present(parts, Vector2.ZERO, VIEW, Rect2(Vector2.ZERO, Vector2(VIEW)))
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	check(image != null and image.get_size() == VIEW, "actual framebuffer " + label)
	var directory: String = OS.get_environment("CYBERSAND_FLYER_RENDER_EVIDENCE")
	if directory.is_empty(): directory = OS.get_environment("CYBERSAND_PRESENTATION_EVIDENCE")
	if directory.is_empty(): directory = "user://flyer-exhaust-render"
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join(label + ".png")
	check(image.save_png(path) == OK, "retain actual pixels " + label)
	captures.append({"label":label,"path":path,"sha256":FileAccess.get_sha256(path)})
	return image

func difference(a: Image, b: Image) -> int:
	var changed: int = 0
	for y: int in VIEW.y:
		for x: int in VIEW.x:
			var first: Color = a.get_pixel(x, y)
			var second: Color = b.get_pixel(x, y)
			if maxf(absf(first.r-second.r), maxf(absf(first.g-second.g), absf(first.b-second.b))) > 2.0/255.0:
				changed += 1
	return changed

func thrust(session: CyberPhysicalActorSession) -> void:
	check(session.submit_workbench_action(1, {"move":Vector2.UP,"primary":true,"effort":1.0},
		{"q":false,"e":false,"s":false,"boost":false}, false), "live actuation with chemical Fire disabled")
	session.advance(1.0/60.0)

func model_case(model: String) -> void:
	var session := Session.new()
	host.add_child(session)
	check(session.configure([definition(model)], host.get_world_2d().space, 1), "actual Rapier graph " + model)
	if not session.active(): session.free(); return
	var off: Image = await capture(session.render_parts(), model + "-off")
	thrust(session)
	var parts: Array = session.render_parts()
	var jets: Array = parts.filter(func(part: Dictionary) -> bool: return part.has("gcr_exhaust"))
	check(jets.size() == 1, "one physical-body exhaust payload " + model)
	if jets.is_empty(): session.free(); return
	var pixels: Array = overlay.exhaust_pixels(jets[0].gcr_exhaust)
	check(not pixels.is_empty() and pixels.size() <= Overlay.MAX_EXHAUST_PIXELS, "bounded pixel plume " + model)
	for pixel: Dictionary in pixels:
		check(pixel.cell is Vector2i and Color(pixel.color).a == 1.0, "opaque native-grid exhaust pixels")
	var on: Image = await capture(parts, model + "-on")
	check(difference(on, off) >= 8, "real rendered exhaust differs from absent effect " + model)
	check(session.pack_workbench_sample().emitters.is_empty(), "rendered plume does not require native Fire injection " + model)
	if model == "scooper": check(parts.size() == 5, "all five hull shapes share that one plume")
	if model == "kestrel":
		var body: RigidBody2D = session.bodies()[0]
		body.global_rotation = PI * 0.5
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)
		session.bridge.refresh_all_states()
		thrust(session)
		var rotated: Array = session.render_parts()
		var shown: Dictionary = rotated[0].gcr_exhaust
		check(Transform2D(shown.pose).is_equal_approx(session.bridge.body_transform(0)), "rotated plume uses actual selected physics pose")
		var sum_x: float = 0.0
		var rotated_pixels: Array = overlay.exhaust_pixels(shown)
		for pixel: Dictionary in rotated_pixels: sum_x += pixel.cell.x
		check(not rotated_pixels.is_empty() and sum_x/rotated_pixels.size() < body.global_position.x - 3.0,
			"rotating thrust right rotates its exhaust left")
		await capture(rotated, "kestrel-quarter-turn")
	session.set_suspended(true)
	var stopped: Array = session.render_parts()
	check(stopped.filter(func(part: Dictionary) -> bool: return part.has("gcr_exhaust")).is_empty(), "pause removes active exhaust " + model)
	var cancelled: Image = await capture(stopped, model + "-cancelled")
	check(difference(on, cancelled) >= 8, "cancelled effect leaves no glowing residual " + model)
	session.free()
	await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("FLYER_EXHAUST_RENDER: skipped (requires actual framebuffer submission)")
		quit(0)
		return
	viewport = SubViewport.new()
	viewport.size = VIEW
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	overlay = Overlay.new()
	viewport.add_child(overlay)
	host = Node2D.new()
	root.add_child(host)
	for model: String in ["kestrel", "afterglow", "scooper"]: await model_case(model)
	host.free()
	viewport.queue_free()
	await process_frame
	await process_frame
	print("FLYER_EXHAUST_RENDER ", JSON.stringify({"checks":checks,"failures":failures,
		"display_server":DisplayServer.get_name(),"rendering_driver":RenderingServer.get_current_rendering_driver_name(),
		"engine":Engine.get_version_info().string,"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"fixture_sha256":FileAccess.get_sha256(get_script().resource_path),"captures":captures}))
	quit(int(not failures.is_empty()))
