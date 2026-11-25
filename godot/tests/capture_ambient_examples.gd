extends SceneTree

# Opt-in graphical evidence helper over the ordinary Workbench. This is not a
# headless correctness test or a claim of physical Windows/display acceptance.
# Example geometry, actor state and editor widgets are the actual application.
const Examples = preload("res://scripts/ambient/ambient_examples.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var host: Control
var wb: Control
var failures: Array[String] = []
var captures: Array = []
var phases: Array = []
var folder := ""
var started := 0


func _initialize() -> void:
	started = Time.get_ticks_msec()
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	root.size = Vector2i(1600, 1000)
	root.gui_embed_subwindows = true
	set_meta("cybersand_feature", "shared_workbench")
	# Ordinary persisted-start admission keeps startup bounded before loading
	# the explicit examples; it does not replace native/physical preparation.
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	set_meta("cybersand_playable_recovery", {"workbench":Setup.fresh(bridge.call(&"default_liquid_policy"), Vector2i(512, 512))})
	run.call_deferred()


func check(condition: bool, label: String) -> bool:
	if not condition:
		failures.append(label)
		push_error("AMBIENT_CAPTURE: " + label)
	return condition


func installed() -> bool:
	return wb != null and not wb.applied.is_empty() and not wb.busy() \
		and host.pending_microscenario_apply.is_empty()


func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		await process_frame
	return check(false, label + " / " + str(wb.message if wb != null else "opening"))


func physical_tick() -> int:
	return int(host.physical_actor_session.tick) if host != null and host.physical_actor_session != null else -1


func native_tick() -> int:
	return int(host.latest_snapshot.tick_index) if host != null and host.latest_snapshot != null else -1


func capture(label: String, caption: String) -> void:
	# A frame must actually have been drawn. A headless placeholder is refused.
	await process_frame
	await RenderingServer.frame_post_draw
	var path := folder.path_join(label + ".png")
	var frame := root.get_texture().get_image()
	if not check(frame != null and not frame.is_empty(), "real rendered image " + label): return
	if not check(frame.save_png(path) == OK, "write real framebuffer " + label): return
	# The rendered body frame can lag current physics while it remains bound to
	# the uploaded material revision. Record both identities without equating them.
	var displayed: Dictionary = host.workbench_display_frame()
	var rendered_actor_frame := {"available":not displayed.is_empty(),
		"mode":"matched uploaded material" if not displayed.is_empty() else "current physical fallback; no matched frame available"}
	for key: String in ["session", "epoch", "sample_tick", "tick", "revision", "world_generation"]:
		if displayed.has(key): rendered_actor_frame[key] = displayed[key]
	if displayed.has("epoch"):
		check(int(displayed.epoch) == int(host.physical_actor_session.epoch), "rendered actor frame belongs to current owner: " + label)
	var material_display := {"generation":int(host.last_uploaded_world_generation),
		"render_serial":int(host.last_uploaded_render_snapshot_serial), "revision":int(host.last_uploaded_revision)}
	var actors := []
	for actor: Dictionary in wb.applied.get("actors", []):
		var view: Dictionary = host.physical_actor_session.workbench_control(int(actor.id))
		var decision: Dictionary = view.get("diagnostics", {}).get("ambient", {})
		if not host.paused: check(int(decision.get("decisions", 0)) > 0, "playing captured actor has made an actual decision: " + label)
		actors.append({"instance_id":actor.id, "model":actor.model,
			"profile_id":actor.control.get("ambient", {}).get("id", ""),
			"current_physical_position":view.get("observation", {}).get("position", Vector2.ZERO),
			"decisions":decision.get("decisions", 0), "intent":decision.get("intent", {})})
	captures.append({"path":path, "caption":caption, "native_tick":native_tick(),
		"physical_tick":physical_tick(), "paused":host.paused, "actors":actors,
		"material_display":material_display, "rendered_actor_frame":rendered_actor_frame,
		"pose_semantics":"actors contain current copied physics poses; rendered_actor_frame identifies the separate displayed pose publication"})
	print("AMBIENT_CAPTURE_FRAME ", label, " native=", native_tick(), " physical=", physical_tick())


func show_example(example: Dictionary) -> void:
	if not host.paused: wb.toggle_pause()
	if not check(wb.load_ambient_example(str(example.id)), "ordinary example admission " + str(example.id)): return
	if not await until(installed, "native and actor acknowledgement " + str(example.id)): return
	if not check(host.physical_actor_session != null, "ordinary physical owner admitted: " + str(example.id)): return
	wb._camera.select(2)
	wb.set_camera(2)
	wb.select_instance(1)
	await capture(str(example.id) + "-authored", str(example.description) + " Authored start; paused.")
	var first_native := native_tick()
	var first_physical := physical_tick()
	var begin := Time.get_ticks_usec()
	if not check(wb.toggle_pause(), "ordinary Play " + str(example.id)): return
	var progressed := await until(func() -> bool:
		return physical_tick() >= first_physical + 120 and native_tick() >= first_native + 119,
		"two seconds of completed native and physical progression " + str(example.id))
	phases.append({"example":example.id, "requested_physical_ticks":120,
		"physical_ticks":physical_tick() - first_physical, "native_ticks":native_tick() - first_native,
		"wall_usec":Time.get_ticks_usec() - begin, "memory_bytes":OS.get_static_memory_usage(), "passed":progressed})
	if not progressed: return
	await capture(str(example.id) + "-playing", str(example.name) + " during ordinary Play, after at least 120 physical ticks.")
	if str(example.id) == "ambient-oil-water":
		wb.set_ambient_overlay(1, true)
		await capture("ambient-oil-water-overlay", "Optional copied perception overlay; actor and material owners continue normally.")
		wb.open_ambient_profile(1)
		var editor: Window = wb._ambient_profile_editor
		editor._selected_module = 1
		editor._module_list.select(1)
		editor._show_module()
		editor.refresh_inspection()
		check(editor._inspector.text.contains("Intent"), "live editor displays selected intent")
		await capture("ambient-behaviour-profile-editor", "Actual Behaviour profile editor, Oil material picker, units and live read-only decision inspector.")
		editor.hide()
		wb.set_ambient_overlay(1, false)
	wb.toggle_pause()


func run() -> void:
	folder = OS.get_environment("CYBERSAND_AMBIENT_CAPTURE")
	if not check(not folder.is_empty(), "set CYBERSAND_AMBIENT_CAPTURE to a new evidence directory") \
		or not check(DisplayServer.get_name() != "headless", "graphical display required"):
		await finish(); return
	DirAccess.make_dir_recursive_absolute(folder)
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await until(func() -> bool: return host.shared_workbench != null, "ordinary Workbench opens"):
		await finish(); return
	wb = host.shared_workbench
	if not await until(installed, "ordinary native owner ready"):
		await finish(); return
	var requested := OS.get_environment("CYBERSAND_AMBIENT_CAPTURE_EXAMPLE")
	for example: Dictionary in Examples.legacy_entries():
		if not requested.is_empty() and str(example.id) != requested: continue
		await show_example(example)
		if not failures.is_empty(): break
	check(not captures.is_empty(), "at least one requested ordinary example captured")
	await finish()


func finish() -> void:
	var report := {"schema":"ambient-graphical-evidence/v1", "godot":Engine.get_version_info().string,
		"platform":OS.get_name(), "display":DisplayServer.get_name(),
		"renderer":RenderingServer.get_video_adapter_name(),
		"renderer_vendor":RenderingServer.get_video_adapter_vendor(),
		"rendering_method":RenderingServer.get_current_rendering_method(),
		"rendering_driver":RenderingServer.get_current_rendering_driver_name(),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"physical_display_acceptance":false, "elapsed_seconds":float(Time.get_ticks_msec() - started) / 1000.0,
		"failures":failures, "phases":phases, "captures":captures}
	if not folder.is_empty():
		var file := FileAccess.open(folder.path_join("capture-report.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	print("AMBIENT_CAPTURE ", JSON.stringify({"failures":failures,"captures":captures.size(),"phases":phases}))
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
