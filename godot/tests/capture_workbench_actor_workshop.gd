extends SceneTree

# Captures the ordinary live Shared Workbench framebuffer. No mock, headless
# substitute, custom renderer or actor physics owner is created by this fixture.
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var host: Control
var ui: Control
var output := ""
var images: Array[Dictionary] = []
var failure := ""


func _initialize() -> void:
	run.call_deferred()


func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	if predicate.call(): return true
	failure = label
	push_error("WB_ACTOR_CAPTURE: " + label)
	return false


func capture(name: String, caption: String) -> bool:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(name + ".png")) != OK:
		failure = "Unable to capture actual Workbench framebuffer: " + name
		return false
	images.append({"file":name + ".png", "caption":caption,
		"native_tick":host.latest_snapshot.tick_index,
		"rapier_tick":host.physical_actor_session.tick,
		"pilot":ui.pilot_id(), "inspected":ui.selected_id()})
	return true


func campaign() -> bool:
	set_meta("cybersand_feature", "shared_workbench")
	root.size = Vector2i(1440,960)
	root.gui_embed_subwindows = true
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await until(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty(), "ordinary Workbench startup"): return false
	ui = host.shared_workbench
	if not ui.load_mixed_actor_workshop():
		failure = "Mixed Actor Workshop refused: " + ui.message
		return false
	if not await until(func() -> bool: return not ui.busy() and ui.applied.actors.size() == 6 and host._physical_terrain_ready, "Mixed Actor Workshop native adoption"): return false
	host.camera_follow_enabled = false
	host.current_view_size = Vector2i(960,540)
	host.camera_origin = Vector2.ZERO
	host.update_worker_frame_state()
	host.update_shader_parameters()
	if host.paused: ui.toggle_pause()
	var first: int = host.physical_actor_session.tick
	if not await until(func() -> bool: return host.physical_actor_session.tick >= first + 100, "concurrent autonomous progression"): return false
	if not await capture("01-mixed-cast", "Actual Shared Workbench: human flyer, three scripted mechanisms, external-policy fixture and passive barrel; labels show producer roles."): return false
	if not ui.select_instance(3):
		failure = "NPC inspection refused"
		return false
	ui.open_actor_composition()
	first = host.physical_actor_session.tick
	if not await until(func() -> bool: return host.physical_actor_session.tick >= first + 25, "NPC continues with composition inspector open"): return false
	if not await capture("02-npc-inspector", "Crawler selected for inspection while the flyer retains the human pilot and all enabled NPCs keep running."): return false
	ui._actor_panel.hide()
	if not ui.pilot_instance(5):
		failure = "Moving ground actor takeover refused"
		return false
	if not await capture("03-ground-takeover", "Existing Stuntbuggy body taken over from the external-policy fixture; the same authored actor remains in the material canvas."): return false
	if not ui.hand_back_pilot():
		failure = "Ground actor handback refused"
		return false
	first = host.physical_actor_session.tick
	if not await until(func() -> bool: return host.physical_actor_session.tick >= first + 20, "policy handback progression"): return false
	return await capture("04-policy-handback", "Ground actor handed back to its external-policy test producer; heterogeneous autonomous cast continues in the same World.")


func run() -> void:
	output = OS.get_environment("WB_ACTOR_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless" or output.is_empty():
		push_error("WB_ACTOR_CAPTURE requires a graphical engine and WB_ACTOR_CAPTURE_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var ok := await campaign()
	var result := {"status":"passed" if ok else "failed", "failure":failure,
		"renderer":RenderingServer.get_video_adapter_name(), "display":DisplayServer.get_name(),
		"images":images, "window":[root.size.x,root.size.y],
		"scope":"Actual application framebuffer and functional host operation; subjective owner playfeel remains separate."}
	var file := FileAccess.open(output.path_join("workshop.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"  ") + "\n")
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await process_frame
	print("WB_ACTOR_CAPTURE ", JSON.stringify(result))
	quit(0 if ok else 1)
