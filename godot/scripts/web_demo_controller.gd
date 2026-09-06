extends "res://scripts/main.gd"

# Web compatibility owner. The original desktop scene/worker remains intact.
# Every native call here runs on Godot's main thread; cellular ticks remain
# fixed at 60 Hz and render publication has its own bounded cadence.
var native_world: Variant
var demo_bridge: Variant
var player: CyberSampledCharacter = CyberSampledCharacter.new()
var ui: CyberWebDemoMenu
var demo_id: String = "neon_works"
var quality: int = 1
var ready_to_play: bool = false
var rapier_available: bool = false
var rapier_reason: String = "Not tested"
var focused: bool = true
var input_armed: bool = false
var publication_clock: float = 0.0
var force_publication: bool = true
var brush_radius: int = 4
var total_moves: int = 0
var paint_commands: int = 0
var imported_count: int = 0
var export_text: String = ""
var last_save_error: String = ""
var last_hash: String = ""
var test_enabled: bool = false
var test_callback: JavaScriptObject
var test_clock: float = 0.0

func _ready() -> void:
	$Layout/World.custom_minimum_size.y = 180
	$Layout/Status.custom_minimum_size.y = 38
	$Layout/Status.add_theme_font_size_override("font_size", 14)
	$Layout/Help.add_theme_font_size_override("font_size", 14)
	$Layout/Title.text = "CYBERSAND / M11"
	$Layout/Help.text = "A/D move · Space jetpack · LMB/RMB paint/erase · 1–6 slots · Q/E materials · X blast · P pause · R reset · Esc menu"
	for body: RigidBody2D in [test_rigid_body_1, test_rigid_body_2, test_rigid_body_3]:
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	Engine.max_physics_steps_per_frame = 2
	if CyberWebCapabilities.native_available():
		native_world = ClassDB.instantiate(&"CyberNativeCellWorld")
		demo_bridge = ClassDB.instantiate(&"CyberDemoBridge")
		var probe: Dictionary = CyberWebCapabilities.rapier_probe()
		rapier_available = bool(probe.ok)
		rapier_reason = str(probe.reason)
		print("WEB_RAPIER_PROBE ", JSON.stringify(probe))
	ui = CyberWebDemoMenu.new()
	add_child(ui)
	ui.setup(self)
	if native_world == null or demo_bridge == null:
		ui.capability.text = "FATAL / CYBERSAND WASM UNAVAILABLE"
		ui.message("The native extension did not load. This build cannot run the CyberSand simulation.")
		push_error("CyberSand native Web extension unavailable")
		return
	render_channels = 2
	render_image_format = Image.FORMAT_RG8
	image = Image.create_empty(1024, 1024, false, render_image_format)
	image.fill(Color(0, 0, 0, 1))
	texture = ImageTexture.create_from_image(image)
	previous_texture = ImageTexture.create_from_image(image)
	material_appearance_lut = CyberMaterialAppearanceLut.create_texture()
	material_appearance_program = CyberMaterialAppearanceLut.create_program_texture()
	world_view.texture = texture
	world_shader.set_shader_parameter("current_world_texture", texture)
	world_shader.set_shader_parameter("previous_world_texture", previous_texture)
	world_shader.set_shader_parameter("material_lut", material_appearance_lut)
	world_shader.set_shader_parameter("material_program_lut", material_appearance_program)
	world_shader.set_shader_parameter("material_lut_size", Vector2(CyberMaterialAppearanceLut.ATLAS_WIDTH, CyberMaterialAppearanceLut.ATLAS_HEIGHT))
	setup_glow_pipeline()
	set_quality(1)
	ready_to_play = true
	select_demo(demo_id, false)
	ui.capability.text = CyberWebCapabilities.status(native_world, rapier_available)
	ui.message(rapier_reason if not rapier_available else "")
	_init_browser_test()
	print("WEB_DEMO_READY ", ui.capability.text)

func _exit_tree() -> void:
	rapier_bridge.shutdown()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		focused = false
		input_armed = false
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		focused = true
		input_armed = false

func release_game_input() -> void:
	input_armed = false

func _process(delta: float) -> void:
	if not ready_to_play:
		return
	frame_time_ms = delta * 1000.0
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_physical_key_pressed(KEY_A) and not Input.is_physical_key_pressed(KEY_D) and not Input.is_physical_key_pressed(KEY_SPACE):
		input_armed = focused and not ui.open
	if not ui.open and focused:
		update_camera(delta)
	_sync_web_colliders()
	publication_clock += delta
	if force_publication or publication_clock >= 1.0 / float(render_snapshot_hz):
		publication_clock = fmod(publication_clock, 1.0 / float(render_snapshot_hz))
		_publish_world()
	update_shader_parameters()
	if rigid_bodies.is_empty():
		for i: int in range(3):
			world_shader.set_shader_parameter("rigid_body_data_%d" % i, Vector4(-1000, -1000, 0, 0))
	status_accumulator += delta
	if status_accumulator >= STATUS_INTERVAL:
		status_accumulator = 0.0
		update_status()
	if test_enabled:
		test_clock += delta
		if test_clock >= 0.15:
			test_clock = 0
			_publish_test_state()

func _physics_process(_delta: float) -> void:
	if not ready_to_play or ui.open or not focused:
		return
	native_world.set_simulation_window(Vector2i(camera_origin.floor()), current_view_size, simulation_margin.x, simulation_margin.y)
	if input_armed:
		_paint_pointer()
	if paused:
		return
	if rapier_bridge.is_initialized():
		if rapier_bridge.pending_hard_surface_chunk_count() > 0:
			return
		rapier_bridge.apply_cellular_results(int(native_world.get_tick_index()), native_world.rigid_body_results())
		rapier_bridge.step()
		native_world.prepare_rigid_body_coupling(rapier_bridge.pack_body_states(), true)
	else:
		native_world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	if not native_world.simulation_tick():
		paused = true
		ui.show_page("home")
		ui.message("Simulation stopped: " + str(native_world.get_last_tick_error()))
		return
	total_moves += int(native_world.get_moves_last_tick())
	var horizontal: float = get_horizontal_input() if input_armed else 0.0
	var jetpack: bool = input_armed and Input.is_physical_key_pressed(KEY_SPACE)
	player.simulate(1.0 / 60.0, horizontal, jetpack, native_world)
	character_position = player.position

func _world_pointer() -> Vector2i:
	var content: Rect2 = view_content_rect()
	var local: Vector2 = world_view.get_local_mouse_position()
	if not content.has_point(local) or content.size.x <= 0 or content.size.y <= 0:
		return Vector2i(-1, -1)
	var point: Vector2 = camera_origin.floor() + (local - content.position) / content.size * Vector2(current_view_size)
	return Vector2i(point.floor())

func _paint_pointer() -> void:
	var point: Vector2i = _world_pointer()
	if point.x < 0 or point.y < 0 or point.x >= 1024 or point.y >= 1024:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		native_world.paint_disc(point.x, point.y, brush_radius, 0, 0)
		paint_commands += 1
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		native_world.emit_disc(point.x, point.y, brush_radius, selected_material_id, 1 if coherent_emission_enabled else 0)
		paint_commands += 1

func _publish_world() -> void:
	var packet: Dictionary = native_world.take_render_snapshot(force_publication)
	var rectangles: PackedInt32Array = packet.get("rectangles", PackedInt32Array())
	var cells: PackedByteArray = packet.get("cells", PackedByteArray())
	if rectangles.is_empty():
		return
	if upload_texture_patches(rectangles, cells, int(native_world.get_revision()), 2):
		force_publication = false
		last_render_patch_count = rectangles.size() / 6
		last_render_patch_bytes = cells.size()
		last_render_was_full_refresh = bool(packet.get("full_refresh", false))
	else:
		force_publication = true
		render_patch_rejection_count += 1

func _sync_web_colliders() -> void:
	if not rapier_bridge.is_initialized():
		return
	var revision: int = int(native_world.get_hard_surface_revision())
	if revision != last_hard_surface_revision:
		var rectangles: PackedInt32Array = native_world.get_hard_surface_chunk_rectangles()
		if rapier_bridge.queue_hard_surface_chunk_snapshot(rectangles):
			last_hard_surface_revision = revision
	rapier_bridge.process_hard_surface_collider_budget(HARD_SURFACE_CHUNKS_PER_FRAME, HARD_SURFACE_FRAME_BUDGET_USEC)

func _activate_physics(active: bool, saved_bodies: Array = []) -> void:
	for body: RigidBody2D in [test_rigid_body_1, test_rigid_body_2, test_rigid_body_3]:
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
	rapier_bridge.shutdown()
	rigid_bodies.clear()
	last_hard_surface_revision = -1
	if not active or not rapier_available:
		return
	rigid_bodies = [test_rigid_body_1, test_rigid_body_2, test_rigid_body_3]
	for body: RigidBody2D in rigid_bodies:
		body.freeze = false
		body.collision_layer = 1
		body.collision_mask = 1
	var sizes: PackedVector2Array = PackedVector2Array([Vector2(8, 14), Vector2(8, 14), Vector2(8, 14)])
	rapier_start_error = rapier_bridge.initialize(get_world_2d().space, rigid_bodies, sizes)
	if rapier_start_error != OK:
		rapier_available = false
		_activate_physics(false)
		return
	for i: int in range(3):
		var position: Vector2 = Vector2([124, 244, 384][i], 90 - i * 15)
		var rotation: float = 0.0
		if i < saved_bodies.size():
			position = Vector2(saved_bodies[i][0], saved_bodies[i][1])
			rotation = float(saved_bodies[i][2])
		rapier_bridge.reset_body(i, position, rotation)
		if i < saved_bodies.size():
			var rid: RID = rigid_bodies[i].get_rid()
			PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(saved_bodies[i][3], saved_bodies[i][4]))
			PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, float(saved_bodies[i][5]))
			PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, bool(saved_bodies[i][6]))
	rapier_bridge.refresh_all_states()
	rapier_bridge.reset_result_tracking()
	_sync_web_colliders()

func select_demo(id: String, close: bool = true) -> void:
	if not ready_to_play or not CyberDemoWorlds.valid_id(id):
		return
	if id == "physics_pit" and not rapier_available:
		ui.message("Physics Pit is unavailable in this build.")
		return
	if not demo_bridge.build_world(native_world, CyberDemoWorlds.rectangles(id)):
		ui.message(str(demo_bridge.get_last_error()))
		return
	demo_id = id
	player.reset(CyberDemoWorlds.spawn(id))
	character_position = player.position
	camera_origin = Vector2.ZERO
	camera_follow_enabled = false
	paused = false
	total_moves = 0
	_activate_physics(id == "physics_pit")
	native_world.set_liquid_surface_adhesion_enabled(liquid_surface_adhesion_enabled)
	force_publication = true
	_publish_world()
	update_shader_parameters()
	update_status()
	if close:
		ui.close_menu()

func set_quality(index: int) -> void:
	quality = clampi(index, 0, 2)
	var views: Array[Vector2i] = [Vector2i(320, 180), Vector2i(480, 270), Vector2i(640, 360)]
	var margins: Array[Vector2i] = [Vector2i(16, 18), Vector2i(32, 36), Vector2i(64, 72)]
	current_view_size = views[quality]
	simulation_margin = margins[quality]
	render_snapshot_hz = [30, 45, 60][quality]
	camera_origin = clamped_camera_origin(camera_origin)
	if native_world != null:
		native_world.set_simulation_window(Vector2i(camera_origin.floor()), current_view_size, simulation_margin.x, simulation_margin.y)
	if ui != null and ui.notice != null:
		ui.message("%s / %d×%d view / %d Hz publication" % [["LOW", "NORMAL", "HIGH"][quality], current_view_size.x, current_view_size.y, render_snapshot_hz])

func update_status() -> void:
	if native_world == null:
		return
	$Layout/Title.text = "CYBERSAND / " + CyberDemoWorlds.title(demo_id).to_upper()
	var text: String = "%s / %s / %s" % [material_name(selected_material_id), "PAUSED" if paused else "60 TPS target", "CALM" if coherent_emission_enabled else "SPRAY"]
	if debug_stats_visible:
		text += "   |   tick %d / %.2f ms native / %.2f ms upload / %d active blocks / %d patches" % [int(native_world.get_tick_index()), float(native_world.get_simulation_time_ms()), upload_time_ms, int(native_world.get_active_blocks_last_tick()), last_render_patch_count]
	status_label.text = text

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if ui.open:
			ui.close_menu()
		else:
			ui.show_page("home")
		get_viewport().set_input_as_handled()
		return
	if not ready_to_play or ui.open:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			selected_material_id = [2, 3, 1, 4, 20, 21][int(event.keycode) - KEY_1]
		KEY_Q, KEY_E:
			var direction: int = -1 if event.keycode == KEY_Q else 1
			var index: int = PAINTABLE_MATERIAL_IDS.find(selected_material_id)
			selected_material_id = PAINTABLE_MATERIAL_IDS[posmod(index + direction, PAINTABLE_MATERIAL_IDS.size())]
		KEY_P:
			paused = not paused
		KEY_R:
			select_demo(demo_id)
		KEY_F:
			camera_follow_enabled = not camera_follow_enabled
		KEY_C:
			coherent_emission_enabled = not coherent_emission_enabled
		KEY_T:
			liquid_surface_adhesion_enabled = not liquid_surface_adhesion_enabled
			native_world.set_liquid_surface_adhesion_enabled(liquid_surface_adhesion_enabled)
		KEY_G:
			glow_enabled = not glow_enabled
		KEY_F3:
			debug_stats_visible = not debug_stats_visible
		KEY_X:
			var point: Vector2i = _world_pointer()
			if point.x >= 0:
				demo_bridge.queue_explosion(native_world, point.x, point.y, 20)
	update_status()

func _metadata() -> Dictionary:
	var bodies: Array = []
	for body: RigidBody2D in rigid_bodies:
		var rid: RID = body.get_rid()
		var pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var velocity: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		bodies.append([pose.origin.x, pose.origin.y, pose.get_rotation(), velocity.x, velocity.y, float(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)), bool(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING))])
	return {"demo": demo_id, "player": [player.position.x, player.position.y, player.velocity.x, player.velocity.y], "material": selected_material_id, "quality": quality, "coherent": coherent_emission_enabled, "adhesion": liquid_surface_adhesion_enabled, "glow": glow_enabled, "bodies": bodies}

func _encode_current() -> Dictionary:
	var world: PackedByteArray = demo_bridge.export_level(native_world)
	return CyberDemoSaveCodec.encode(world, _metadata())

func export_save() -> void:
	var encoded: Dictionary = _encode_current()
	if not encoded.ok:
		last_save_error = str(encoded.error)
		ui.message(last_save_error)
		return
	export_text = str(encoded.text)
	ui.save_text.text = export_text
	last_save_error = ""
	ui.message("Exported %d bytes. Keep this text to restore the level." % encoded.binary.size())

func import_save(text: String) -> void:
	_import_decoded(CyberDemoSaveCodec.decode_text(text))

func _import_decoded(decoded: Dictionary) -> void:
	if not decoded.ok:
		last_save_error = str(decoded.error)
		ui.message(last_save_error)
		return
	var metadata: Dictionary = decoded.metadata
	if str(metadata.demo) == "physics_pit" and not rapier_available:
		last_save_error = "This save requires Rapier; current world unchanged."
		ui.message(last_save_error)
		return
	if not demo_bridge.import_level(native_world, decoded.world):
		last_save_error = str(demo_bridge.get_last_error())
		ui.message(last_save_error)
		return
	demo_id = str(metadata.demo)
	player.position = Vector2(metadata.player[0], metadata.player[1])
	player.velocity = Vector2(metadata.player[2], metadata.player[3])
	player.grounded = false
	character_position = player.position
	selected_material_id = int(metadata.material)
	coherent_emission_enabled = bool(metadata.coherent)
	liquid_surface_adhesion_enabled = bool(metadata.adhesion)
	glow_enabled = bool(metadata.glow)
	native_world.set_liquid_surface_adhesion_enabled(liquid_surface_adhesion_enabled)
	set_quality(int(metadata.quality))
	camera_origin = clamped_camera_origin(player.centre() - Vector2(current_view_size) * 0.5)
	camera_follow_enabled = false
	_activate_physics(demo_id == "physics_pit", metadata.get("bodies", []))
	force_publication = true
	_publish_world()
	imported_count += 1
	last_save_error = ""
	ui.message("Level restored. Continue from the menu.")
	update_status()

func save_slot() -> void:
	var encoded: Dictionary = _encode_current()
	if not encoded.ok:
		ui.message(str(encoded.error))
		return
	var temporary: String = CyberDemoSaveCodec.LOCAL_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		ui.message("Local storage unavailable. Use Export Current.")
		return
	file.store_buffer(encoded.binary)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, CyberDemoSaveCodec.LOCAL_PATH) != OK:
		ui.message("Local save failed. Use Export Current.")
		return
	ui.message("Local slot written. Keep a portable copy; browser storage can be cleared.")

func load_slot() -> void:
	var file: FileAccess = FileAccess.open(CyberDemoSaveCodec.LOCAL_PATH, FileAccess.READ)
	if file == null:
		ui.message("No local slot available.")
		return
	if file.get_length() > CyberDemoSaveCodec.MAX_BINARY:
		file.close()
		ui.message("Local save exceeds size limit.")
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	_import_decoded(CyberDemoSaveCodec.decode_binary(bytes))

# Opt-in browser acceptance hook. No network calls, telemetry, arbitrary code
# execution or engine pointers. Normal URLs never expose this interface.
func _init_browser_test() -> void:
	if not OS.has_feature("web"):
		return
	test_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('test') === '1'", true))
	if not test_enabled:
		return
	JavaScriptBridge.eval("window.cybersandTest = {state: {}, invoke: null};", true)
	test_callback = JavaScriptBridge.create_callback(_test_command)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.cybersandTest.invoke = test_callback

func _test_command(arguments: Array) -> void:
	if not test_enabled or arguments.size() != 1:
		return
	var command: Variant = JSON.parse_string(str(arguments[0]))
	if not command is Dictionary:
		return
	match str(command.get("op", "")):
		"set_text":
			ui.save_text.text = str(command.get("text", ""))
		"hash":
			var bytes: PackedByteArray = demo_bridge.export_level(native_world)
			var hasher: HashingContext = HashingContext.new()
			hasher.start(HashingContext.HASH_SHA256)
			hasher.update(bytes)
			last_hash = hasher.finish().hex_encode()
	_publish_test_state()

func _publish_test_state() -> void:
	var content: Rect2 = view_content_rect()
	content.position += world_view.global_position
	var body_positions: Array = []
	for i: int in range(rigid_bodies.size()):
		var pose: Transform2D = rapier_bridge.body_transform(i)
		body_positions.append([pose.origin.x, pose.origin.y])
	var state: Dictionary = {"ready": ready_to_play, "demo": demo_id, "menu": ui.open, "tick": int(native_world.get_tick_index()), "moves": total_moves, "player": [player.position.x, player.position.y], "paused": paused, "paint_commands": paint_commands, "rapier": rapier_available, "rapier_reason": rapier_reason, "bodies": body_positions, "imports": imported_count, "error": last_save_error, "text": export_text, "hash": last_hash, "buttons": ui.test_rects(), "view": [content.position.x, content.position.y, content.size.x, content.size.y], "logical": [current_view_size.x, current_view_size.y], "camera": [camera_origin.x, camera_origin.y], "probe": int(native_world.material_at(420, 25)), "native_ms": float(native_world.get_simulation_time_ms()), "upload_ms": upload_time_ms, "render_rejections": render_patch_rejection_count, "local_slot": FileAccess.file_exists(CyberDemoSaveCodec.LOCAL_PATH)}
	JavaScriptBridge.eval("window.cybersandTest.state = " + JSON.stringify(state) + ";", true)
