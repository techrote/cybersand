extends SceneTree

# Two invocations with the same CYBERSAND_WORKBENCH_TEST_NAME exercise a real
# filesystem handoff. The ordinary launcher constructs Main in each process.
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Couple = preload("res://scripts/rigid_body_coupling.gd")
var main: Control
var bench
var checks := 0
var failures := 0
var case_name := ""

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error("WORKBENCH: " + description)
	return condition

func wait_for(predicate: Callable, description: String) -> bool:
	var until := Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while not predicate.call() and Time.get_ticks_msec() < until:
		await process_frame
	return check(predicate.call(), description + (" / " + str(bench.status.text) if bench != null else ""))

func ready(map: String, epoch: int = 0) -> bool:
	return bench != null and main.pending_microscenario_apply.is_empty() and main._physical_epoch > epoch \
		and main._physical_terrain_ready and bench.applied.get("map") == map

func cell(pos: Vector2i) -> int:
	return main.image.get_pixel(pos.x,pos.y).r8

func published(map: String) -> bool:
	var excavated := Vector2i(250,214 if map == Setup.MAPS[0] else 233)
	return cell(Vector2i(161,123)) == CyberCellWorld.SAND and cell(Vector2i(171,125)) == CyberCellWorld.WATER \
		and cell(excavated) == CyberCellWorld.EMPTY and cell(excavated + Vector2i(5,0)) == CyberCellWorld.WALL

func inspect_install(map: String) -> bool:
	var actor = main.physical_actor_session
	if not check(actor != null and actor.bridge == main.rapier_bridge and actor.bodies() == main.rigid_bodies \
		and actor.bodies().size() == 5 and main.latest_snapshot.rigid_body_epoch == actor.epoch,
		"one accepted epoch, five collider bodies in the shared physical owner"):
		return false
	var bodies: Array = actor.bodies()
	var prop: RigidBody2D = bodies.back()
	var space := PhysicsServer2D.body_get_space(prop.get_rid())
	for body: RigidBody2D in bodies:
		check(PhysicsServer2D.body_get_space(body.get_rid()) == space, "same live Rapier space")
	check(prop.mass == 1.0 and is_equal_approx(prop.gravity_scale,0.094) and is_equal_approx(prop.linear_damp,0.15) \
		and is_equal_approx(prop.angular_damp,0.35) and prop.physics_material_override.rough \
		and prop.physics_material_override.absorbent and prop.get_child(0).shape.size == Vector2(8,14),
		"passive reference body properties")
	check(actor.observation(1).model == Setup.BARREL and actor.observation(1).producer == "passive" \
		and actor.observation(1).equipment.usable_index == -1 and not actor.takeover(1,actor.epoch,&"human"),
		"barrel has no usable or pilot takeover")
	check(actor.observation(0).position.is_equal_approx(Vector2(160,176)) \
		and actor.observation(1).position.is_equal_approx(Vector2(160,150)), "actual reconstructed body origins")
	for child: Control in main.get_node("Layout").get_children():
		check(not child.visible or child == bench or child == main.world_view, "only toolbar and viewport visible / " + str(child.name))
	check(bench.applied.map == map and bench.pilot_slot == 0 and main.paused, "applied map and selected flyer")
	var assignments: Array = main.tower_context.liquid_solver_policy.assignments
	var family := ""
	for assignment: Dictionary in assignments:
		if int(assignment.material) == CyberCellWorld.WATER:
			family = assignment.applied_family
	check(family == ("cellular_yield_v1" if map == Setup.MAPS[0] else "freemass_v1"),"native Water family " + family)
	return await wait_for(func(): return published(map), "copied sand/water/excavation after reconstruction")

func canvas_position(pos: Vector2i) -> Vector2:
	var rect: Rect2 = main.view_content_rect()
	var screen: Vector2 = main.world_view.get_global_transform_with_canvas() * (
		rect.position + (Vector2(pos) + Vector2(0.5,0.5)) / Vector2(main.current_view_size) * rect.size)
	return screen

func canvas_stamp(pos: Vector2i, tool: int, held: bool = false) -> void:
	bench.tool_choice.select(tool)
	for pressed: bool in ([true] if held else [true,false]):
		var click := InputEventMouseButton.new()
		click.position = canvas_position(pos)
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(click,true)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func play_contact(map: String) -> void:
	var old_tick: int = main.latest_snapshot.tick_index
	check(bench.step_once(),"paused step admitted")
	await wait_for(func(): return not bench.step_pending,"both clocks completed the single step")
	check(main.paused and main.latest_snapshot.tick_index == old_tick + 1 and main.physical_actor_session.tick == 1,
		"step advances one native and one physical tick")
	check(bench.toggle_pause(),"play")
	await wait_for(func(): return main.physical_actor_session.tick >= 4, "normal physics sampling rearmed")
	var max_contact := [0,0]
	var thrust := false
	var touch := false
	var lifted := false
	var prop_start: float = main.physical_actor_session.observation(1).position.y
	var frame_has_focus: bool = main._actor_window_has_focus()
	key(KEY_W,true)
	for frame in 95:
		await physics_frame
		var view: Dictionary = main.physical_actor_session.observation(0)
		if frame == 39:
			key(KEY_W,false)
		thrust = thrust or absf(float(view.player_movement.thrust)) > 0.01
		var prop: RigidBody2D = main.rigid_bodies.back()
		var state := PhysicsServer2D.body_get_direct_state(prop.get_rid())
		for contact in state.get_contact_count():
			for i in range(main.rigid_bodies.size()-1):
				touch = touch or state.get_contact_collider(contact) == main.rigid_bodies[i].get_rid()
		lifted = lifted or main.physical_actor_session.observation(1).position.y < prop_start - 2.0
		var results: PackedFloat32Array = main.latest_snapshot.rigid_body_results
		for offset in range(0,results.size(),Couple.RESULT_STRIDE):
			var slot := 1 if int(results[offset]) == 5 else 0
			max_contact[slot] = maxi(max_contact[slot],int(results[offset+Couple.RESULT_CONTACT_COUNT]))
	key(KEY_W,false)
	print("WORKBENCH_MOTION ",map," thrust=",thrust," touch=",touch," barrel_lift=",lifted,
		" native contacts=",max_contact," focus=",frame_has_focus)
	check(thrust, "keyboard thrust reached live flyer")
	check(touch and lifted, "flyer contacted and pushed passive barrel upward")
	check(max_contact[0] > 0 and max_contact[1] > 0,"native material contacts for both actors")
	key(KEY_W,true)
	await physics_frame
	main._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(main.physical_actor_session.observation(0).lease_remaining == 0 and not bench._drag, "window focus loss cancelled input")
	check(bench.select_pilot(1),"observer selection")
	var view: Dictionary = main.physical_actor_session.observation(0)
	check(view.lease_remaining == 0 and view.pending_input_edges == 0,"changing focus retires thrust")
	check(bench.select_pilot(0),"reselect pilot")
	for frame in 3:
		await physics_frame
	check(main.physical_actor_session.observation(0).lease_remaining == 0,"held key cannot rearm new pilot")
	key(KEY_W,false)
	check(bench.toggle_pause(),"pause")
	check(bench.step_once() and not bench.step_once() and not bench.reset_setup(),"rapid pause-step fences duplicate step and reset")
	await wait_for(func(): return not bench.step_pending,"worker acknowledged the requested step serial")
	check(main.tower_context.workbench_step_serial == bench.step_serial,"matching completed worker command")
	check(main.physical_actor_session.observation(0).lease_remaining == 0,"pause cancels command")
	var previous: int = main._physical_epoch
	check(bench.reset_setup(),"authored reset requested")
	await wait_for(func(): return ready(map,previous), "reset acknowledged")
	check(main.physical_actor_session.tick == 0 and main.physical_actor_session.observation(0).lease_remaining == 0,
		"reset contains no stale movement")
	await inspect_install(map)

func author(map: String) -> void:
	var index: int = Setup.MAPS.find(map)
	if not ready(map):
		var epoch: int = main._physical_epoch
		check(bench.open_map(index),"open second map")
		if not await wait_for(func(): return ready(map,epoch), "map installation"):
			return
	canvas_stamp(Vector2i(161,123),0,true)
	check(bench.applied.edits.has([161,123,CyberCellWorld.SAND]) and bench._drag,"viewport GUI sand stamp starts a held stroke")
	main._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = canvas_position(Vector2i(177,123))
	root.push_input(drag,true)
	check(not bench._drag and bench.applied.edits.size() == 1,"focus loss prevents a held drag from painting more terrain")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = drag.position
	root.push_input(release,true)
	check(bench.paint(Vector2i(171,125),CyberCellWorld.WATER),"author Water")
	check(bench.paint(Vector2i(250,214 if index == 0 else 233),CyberCellWorld.EMPTY),"excavate floor")
	await wait_for(func(): return published(map), "queued brush reached authoritative published cells")
	var epoch: int = main._physical_epoch
	canvas_stamp(Vector2i(160,176),3)
	check(not main.pending_microscenario_apply.is_empty(), "viewport GUI flyer placement submitted")
	if not await wait_for(func(): return ready(map,epoch), "preserve terrain through flyer placement"):
		return
	epoch = main._physical_epoch
	check(bench.place(Setup.BARREL,Vector2i(160,150)), "move barrel")
	if not await wait_for(func(): return ready(map,epoch), "preserve terrain through barrel placement"):
		return
	epoch = main._physical_epoch
	check(bench.change_policy(1 if index == 0 else 0), "apply supported Water selection")
	if not await wait_for(func(): return ready(map,epoch), "policy rebuild"):
		return
	await inspect_install(map)
	var screenshot_path := OS.get_environment("CYBERSAND_WORKBENCH_CAPTURE")
	if index == 0 and not screenshot_path.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(screenshot_path)
	bench.file_name.text = case_name + str(index)
	check(bench.save_setup() and bench.save_setup(),"named starting setup saved and safely overwritten")
	await play_contact(map)

func invalid() -> void:
	var actor = main.physical_actor_session
	var generation: int = main.latest_snapshot.render_world_generation
	var candidate: Dictionary = bench.applied.duplicate(true)
	candidate.actors["scooper"] = candidate.actors[Setup.FLYER]
	check(not bench.apply(candidate),"unsupported actor rejected")
	var bad := case_name + "-invalid"
	DirAccess.make_dir_recursive_absolute(Setup.DIRECTORY)
	var file := FileAccess.open(Setup._path(bad),FileAccess.WRITE)
	file.store_string("{damaged")
	file.close()
	bench.file_name.text = bad
	check(not bench.load_setup() and "Invalid setup JSON" in bench.message, "malformed load visible")
	DirAccess.remove_absolute(Setup._path(bad))
	check(not bench.apply({"version":99}) and not bench.open_map(9),"unsupported version and map rejected")
	check(not bench.place(Setup.BARREL,Vector2i(161,123)), "placing a prop over authored paint refused")
	check(actor == main.physical_actor_session and main.latest_snapshot.render_world_generation == generation \
		and main.pending_microscenario_apply.is_empty(),"all refusals retain the current session")

func run() -> void:
	case_name = OS.get_environment("CYBERSAND_WORKBENCH_TEST_NAME")
	if case_name.is_empty():
		case_name = "regression-" + str(OS.get_process_id())
	Engine.max_fps = 120
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	bench = main.shared_workbench
	if await wait_for(func(): return ready(Setup.MAPS[0]),"normal launcher to mixed map A"):
		var reading := "--read-setups" in OS.get_cmdline_user_args()
		for map: String in Setup.MAPS:
			if reading:
				var epoch: int = main._physical_epoch
				bench.file_name.text = case_name + str(Setup.MAPS.find(map))
				check(bench.load_setup(),"load file in separate process")
				if await wait_for(func(): return ready(map,epoch), "fresh process load"):
					await inspect_install(map)
				DirAccess.remove_absolute(Setup._path(bench.file_name.text))
			else:
				await author(map)
		invalid()
		var epoch: int = main._physical_epoch
		check(bench.open_map(0),"switch back to fresh map A")
		if await wait_for(func(): return ready(Setup.MAPS[0],epoch),"repeat map switch"):
			await wait_for(func(): return cell(Vector2i(161,123)) == 0 and cell(Vector2i(250,214)) == CyberCellWorld.WALL,
				"fresh map dropped old strokes and restored terrain")
		if OS.get_environment("CYBERSAND_WORKBENCH_TEST_NAME").is_empty():
			for index in Setup.MAPS.size():
				DirAccess.remove_absolute(Setup._path(case_name + str(index)))
		get_root().get_node("FeatureNavigation").return_to_launcher()
		await scene_changed
		check(current_scene.scene_file_path == "res://feature_launcher.tscn", "F2 return tears down Main")
	print("WORKBENCH assertions=",checks," failures=",failures)
	quit(1 if failures > 0 else 0)
