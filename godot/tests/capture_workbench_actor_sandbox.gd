extends SceneTree

# Graphical evidence from the ordinary Workbench, authoritative native worker
# and patched Rapier. The fixture uses actual viewport events for manipulation;
# image capture never substitutes a custom renderer or mock actor owner.
const Capacity = preload("res://scripts/workbench_sandbox_capacity.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var host: Control
var ui: Control
var output := ""
var images: Array[Dictionary] = []
var failure := ""


func _initialize() -> void: run.call_deferred()


func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		await process_frame
	if predicate.call(): return true
	failure = label+" / "+(ui.message if ui != null else "starting")
	push_error("WB_ACTOR_SANDBOX_CAPTURE: "+failure)
	return false


func require(condition: bool, reason: String) -> bool:
	if condition: return true
	failure = reason
	push_error("WB_ACTOR_SANDBOX_CAPTURE: "+reason)
	return false


func progress(count: int, reason: String) -> bool:
	var session = host.physical_actor_session
	var native_before: int = host.latest_snapshot.tick_index
	var first: int = session.tick
	return await until(func() -> bool: return host.physical_actor_session == session \
		and session.tick >= first+count and host.latest_snapshot.tick_index > native_before,reason)


func capture(name: String, caption: String) -> bool:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not require(image != null and not image.is_empty(),"Empty actual framebuffer: "+name): return false
	if not require(image.save_png(output.path_join(name+".png")) == OK,"Cannot save framebuffer: "+name): return false
	var usage := Capacity.summary(ui.applied.actors,ui.applied.get("sandbox_capacity",Capacity.defaults()))
	images.append({"file":name+".png","caption":caption,
		"actors":ui.applied.actors.size(),"actual_bodies":host.physical_actor_session.bodies().size(),
		"authored_bodies":usage.bodies,"authored_proxies":usage.proxies,"authored_joints":usage.joints,
		"native_tick":host.latest_snapshot.tick_index,"rapier_tick":host.physical_actor_session.tick,
		"pilot":ui.pilot_id(),"inspected":ui.selected_id(),"paused":host.paused,
		"mode":ui.actor_interaction.mode(),"grab_active":ui.actor_interaction.grab_state().active,
		"preview_active":not ui.actor_interaction.placement.is_empty()})
	return true


func canvas_position(point: Vector2) -> Vector2:
	var content: Rect2 = host.view_content_rect()
	var local: Vector2 = content.position+(point-host.camera_origin.floor())*content.size/Vector2(host.current_view_size)
	return host.world_view.get_global_transform_with_canvas()*local


func pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = canvas_position(point)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	host.world_view.get_viewport().push_input(event,true)
	await process_frame


func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = canvas_position(point)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	host.world_view.get_viewport().push_input(event,true)
	await process_frame


func placement_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	host.get_viewport().push_input(event,true)
	await process_frame
	event.pressed = false
	host.get_viewport().push_input(event,true)


func paused() -> bool:
	if not host.paused and not ui.toggle_pause(): return require(false,"Pause refused")
	var serial: int = host.simulation_worker.workbench_pause_request_serial()
	return await until(func() -> bool: return host.paused and host.latest_snapshot.paused \
		and int(host.latest_snapshot.lab_context.get("workbench_pause_ack_serial",-1)) >= serial \
		and (host.physical_actor_session == null or host.physical_actor_session._suspended),"native and Rapier acknowledge Pause")


func load_playground(kind: String, count: int = 64) -> bool:
	if is_instance_valid(ui._actor_panel): ui._actor_panel.hide()
	ui.actor_interaction.set_mode("paint")
	if not await paused(): return false
	if not require(ui.load_actor_sandbox(kind,count),"Demo refused: "+kind+" / "+ui.message): return false
	if not await until(func() -> bool: return not ui.busy() and host._physical_terrain_ready \
		and ui._pending_sandbox_demo.is_empty(),kind+" native/Rapier owner adoption"): return false
	ui.set_camera(2)
	root.grab_focus()
	await process_frame
	if not require(ui.toggle_pause(),kind+" Play refused"): return false
	return await progress(20,kind+" concurrent native/Rapier progression")


func mixed_interaction() -> bool:
	if not require(ui.select_instance(3),"Crawler inspection refused"): return false
	ui.open_actor_composition()
	var panel: Window = ui._actor_panel
	panel.position = Vector2i(190,150)
	panel.tabs.current_tab = 1
	if not await progress(10,"NPCs continue with configuration open"): return false
	if not require(not host.paused and ui.pilot_id() == 1 and ui.selected_id() == 3,
		"Inspector must preserve running NPCs and explicit human pilot"): return false
	if not await capture("02-running-controllers","Unified configuration inspects the scripted crawler while the human flyer retains piloting authority and both simulation owners continue."): return false
	panel.tabs.current_tab = 3
	await process_frame
	if not await capture("03-physics-configuration","Physics tab exposes bounded physical-grab response, paused placement increments, optional grid snapping and compatible actor tuning."): return false
	panel.hide()
	if not await paused(): return false
	root.grab_focus()
	ui.actor_interaction.set_mode("place")
	var assembly: Dictionary = host.physical_actor_session.capture_workbench_assembly(2)
	if not require(not assembly.is_empty(),"Runner assembly missing"): return false
	var picked: Vector2 = assembly.parts[0].position
	await pointer(picked,true)
	await motion(picked+Vector2(24,-48))
	await placement_key(KEY_E)
	if not require(not ui.actor_interaction.placement.is_empty(),"Actual pointer failed to create placement preview"): return false
	if not await capture("04-paused-assembly-preview","Paused runner placement previews the complete retained assembly at a new position and 15-degree rotation. No native transaction or live body transform occurs before commit."): return false
	await placement_key(KEY_ESCAPE)
	await pointer(picked,false)
	ui.actor_interaction.set_mode("grab")
	if not require(ui.toggle_pause(),"Play for physical grab refused"): return false
	if not await progress(3,"Play resumes before grabbing"): return false
	assembly = host.physical_actor_session.capture_workbench_assembly(6)
	if not require(not assembly.is_empty(),"Physical barrel missing"): return false
	picked = assembly.parts[0].position
	await pointer(picked,true)
	var target := picked+Vector2(-40,-54)
	await motion(target)
	if not await progress(12,"Physical grab and native materials continue"): return false
	if not require(bool(ui.actor_interaction.grab_state().active),"Actual pointer grab was cancelled before framebuffer capture"): return false
	if not await capture("05-live-physical-grab","A real passive barrel follows a bounded spring at its clicked physical point while independently controlled actors and materials continue."): return false
	await pointer(target,false)
	return require(not ui.actor_interaction.grab_state().active,"Release did not revoke mouse force")


func campaign() -> bool:
	set_meta("cybersand_feature","shared_workbench")
	root.size = Vector2i(1280,960)
	root.gui_embed_subwindows = true
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await until(func() -> bool: return host.shared_workbench != null \
		and not host.shared_workbench.applied.is_empty() and not host.shared_workbench.busy(),"ordinary Workbench startup"): return false
	ui = host.shared_workbench
	if not await load_playground("mixed"): return false
	if not await capture("01-living-mixed-workshop","Living Mixed Workshop: six real actors, independent sources, equipment, hard terrain, sand and open space for painting and manipulation."): return false
	if not await mixed_interaction(): return false
	if not await load_playground("barrels",64): return false
	if not require(ui.applied.actors.size() == 64 and host.physical_actor_session.bodies().size() == 64,
		"Barrel Crowd must contain exactly 64 real physical bodies"): return false
	if not await progress(90,"64 barrels descend into the physical playground"): return false
	if not await capture("06-barrel-crowd-64","Barrel Crowd: 64 real passive actors and 64 retained physical bodies, with stepped confinement, a sand basin and open space."): return false
	ui.open_actor_composition()
	ui._actor_panel.position = Vector2i(190,150)
	ui._actor_panel.tabs.current_tab = 4
	if not await progress(5,"64 barrels progress with capacity configuration open"): return false
	if not await capture("07-capacity-64","Sandbox Capacity reports distinct actor, body, native-mask and joint budgets. Numeric limits and presets are staged until Apply."): return false
	if not await load_playground("mechanical"): return false
	if not await capture("08-mechanical-chaos","Mechanical Chaos: six multipart physical actors, actual joints, independent control sources, equipment and stepped terrain."): return false
	ui.open_actor_composition()
	ui._actor_panel.position = Vector2i(190,150)
	ui._actor_panel.tabs.current_tab = 5
	if not await progress(5,"mechanical diagnostics retain runtime progression"): return false
	return await capture("09-mechanical-diagnostics","Diagnostics expose current selection, manipulation state, resource budgets and preparation status in the same configuration window.")


func run() -> void:
	output = OS.get_environment("WB_ACTOR_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless" or output.is_empty():
		push_error("WB_ACTOR_SANDBOX_CAPTURE requires a graphical engine and WB_ACTOR_CAPTURE_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var ok := await campaign()
	var result := {"status":"passed" if ok else "failed","failure":failure,"images":images,
		"display":DisplayServer.get_name(),"renderer":RenderingServer.get_video_adapter_name(),
		"engine":Engine.get_version_info().string,"window":[root.size.x,root.size.y],
		"scope":"Actual ordinary Workbench framebuffer and native/Rapier progression. Hosted graphical evidence does not establish owner Windows/NVIDIA performance or subjective playfeel."}
	var file := FileAccess.open(output.path_join("sandbox.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"  ")+"\n")
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await process_frame
	print("WB_ACTOR_SANDBOX_CAPTURE ",JSON.stringify(result))
	quit(0 if ok else 1)
