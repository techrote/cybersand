extends SceneTree

const Catalogue = preload("res://scripts/micro_scenario_catalogue.gd")
const Host = preload("res://scripts/micro_scenario_host.gd")
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	if ok: return
	failures += 1
	push_error(message)

func wait_applied(controller: Control) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if controller.pending_micro_apply.is_empty(): return controller.micro_active
	return false

func wait_tick(controller: Control, tick: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if controller.latest_snapshot != null and controller.latest_snapshot.tick_index == tick: return true
	return false

func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	var fixture: Dictionary = Catalogue.definition("communicating-reservoirs", 9)
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	expect(desktop.micro_apply_definition(fixture, "inspect"), "desktop request rejected")
	expect(not desktop.tower_command({"step": true}), "pending reset could be overwritten by step")
	expect(await wait_applied(desktop), "desktop reset not acknowledged")
	expect(desktop.paused and not desktop.tower_active and desktop.latest_snapshot.tick_index == 0,
		"desktop generic selection did not start paused/fresh")
	expect(desktop.micro_current_definition.seed == 9, "desktop seed lost")
	expect(not desktop.tower_command({"release": 0}), "generic fixture accepted Tower releases")
	expect(desktop.tower_command({"step": true}), "desktop step rejected")
	expect(await wait_tick(desktop, 1), "desktop single step did not advance one tick")
	await create_timer(0.08).timeout
	expect(desktop.latest_snapshot.tick_index == 1, "desktop step continued running")
	expect(desktop.micro_capture_observation(), "desktop capture request rejected")
	var deadline: int = Time.get_ticks_msec() + 10000
	while desktop.pending_micro_capture != 0 and Time.get_ticks_msec() < deadline: await process_frame
	expect(desktop.pending_micro_capture == 0, "desktop capture not acknowledged")
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://micro-observation.json"))
	expect(report is Dictionary and report.definition.seed == 9 and report.world.tick == 1,
		"desktop capture mixed identities/ticks")
	var immutable_hash: String = str(report.definition_hash) if report is Dictionary else ""
	fixture.events.clear()
	expect(desktop.micro_current_definition.events.size() == 3, "main-thread input aliased worker definition")
	desktop.micro_reset_current()
	expect(await wait_applied(desktop) and desktop.latest_snapshot.tick_index == 0,
		"desktop reset did not clear event/tick state")
	expect(str(desktop.tower_context.micro.definition_hash) == immutable_hash, "reset changed frozen definition")
	var no_tools: Dictionary = desktop.micro_current_definition.duplicate(true)
	no_tools.tools = []
	expect(desktop.micro_apply_definition(no_tools, "play"), "desktop play selection rejected")
	expect(await wait_applied(desktop), "desktop play did not apply")
	expect(not desktop.queue_brush_mutation(100,100,0,2)
		and not desktop.simulation_worker.queue_emit_disc(100,100,0,2), "undeclared brush accepted")
	expect(not desktop.tower_context.micro.instrumentation, "Play retained optional instrumentation")
	desktop.micro_toggle_hud()
	await process_frame
	expect(not desktop.micro_panel.visible and not desktop.status_label.visible, "HUD hide was undone")
	desktop.micro_toggle_hud()
	desktop.tower_reset()
	deadline = Time.get_ticks_msec() + 10000
	while (not desktop.pending_water_exit.is_empty() or desktop.micro_active) \
		and Time.get_ticks_msec() < deadline: await process_frame
	expect(desktop.pending_water_exit.is_empty() and not desktop.micro_active \
		and desktop.micro_current_definition.id == "experiment-tower", "Tower exit retained generic state")
	desktop.queue_free()
	await process_frame

	var web: Control = load("res://web_main.tscn").instantiate()
	root.add_child(web)
	await process_frame
	web.set_physics_process(false)
	web.ui.close_menu()
	web.focused = true
	web.input_armed = false
	fixture = Catalogue.definition("communicating-reservoirs", 9)
	expect(web.micro_apply_definition(fixture, "benchmark"), "Web synchronous generic reset failed")
	expect(web.micro_active and web.paused and not web.tower_active, "Web generic activation lost state")
	expect(not web._encode_current().ok, "Web generic timeline mislabeled as CYSD1 save")
	expect(not web.queue_explosion_mutation(100,100,4), "undeclared explosion tool accepted")
	web.paused = false
	for tick: int in range(121): web._physics_process(1.0/60.0)
	expect(web.native_world.get_tick_index() == 121, "Web owner skipped/added a tick")
	var web_result: Dictionary = Host.observe(web.native_world)
	var control: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var run: CyberMicroScenarioHost = Host.new()
	expect(run.reset(control, fixture, "benchmark"), "direct owner control reset failed")
	control.simulation_window_enabled = false
	control.cadence_lod_enabled = false
	for tick: int in range(121):
		expect(run.apply_due(control) and control.simulation_tick(), "direct owner control failed")
	expect(web_result == Host.observe(control), "Web synchronous owner changed no-input fixture result")
	web.tower_command({"step": true})
	web._physics_process(1.0/60.0)
	web._physics_process(1.0/60.0)
	expect(web.native_world.get_tick_index() == 122, "Web single step advanced more than one tick")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F4; key.pressed = true
	web._unhandled_key_input(key)
	web.micro_refresh_ui()
	expect(not web.micro_panel.visible, "Web F4 failed to hide HUD")
	web._unhandled_key_input(key)
	key.keycode = KEY_R
	web._unhandled_key_input(key)
	expect(web.micro_active and web.native_world.get_tick_index() == 0, "Web R loaded old demo instead of resetting scenario")
	var before_invalid: Dictionary = Host.observe(web.native_world)
	expect(not web.micro_apply_definition({}, "inspect") \
		and Host.observe(web.native_world) == before_invalid, "Web invalid reset mutated World")
	web.tower_reset()
	expect(not web.micro_active and web.tower_active, "Web Tower exit retained generic state")
	expect(web.native_world.simulation_window_enabled == web.simulation_window_enabled \
		and web.native_world.cadence_lod_enabled == web.cadence_lod_enabled,
		"Web generic exit did not restore legacy owner configuration")
	web.queue_free()
	await process_frame
	await failed_owner_capture()
	print("MS-000 controller regression: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)

func failed_owner_capture() -> void:
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", 1)
	var worker: CyberSimulationWorker = CyberSimulationWorker.new()
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", null)
	worker.set_frame_state(0, false, true, Vector2i.ZERO, Vector2i.ZERO, Vector2i(320,180), 0,0,true,true,true)
	expect(worker.start_worker(Vector2(40,40)) == OK, "failure probe owner failed to start")
	worker.queue_lab({"micro_reset": Catalogue.definition("communicating-reservoirs"), "request_id": 41})
	var deadline: int = Time.get_ticks_msec() + 5000
	while worker.take_latest_snapshot(-1).lab_context.get("micro_result", {}).get("request_id", 0) != 41 \
		and Time.get_ticks_msec() < deadline: await process_frame
	expect(worker.take_latest_snapshot(-1).lab_context.get("micro_result", {}).get("ok", false), "failure probe reset not acknowledged")
	worker.queue_lab({"step": true})
	deadline = Time.get_ticks_msec() + 5000
	while not worker.has_failed() and Time.get_ticks_msec() < deadline: await process_frame
	var failed: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	expect(failed.simulation_failed, "failure probe did not quarantine")
	worker.queue_lab({"micro_capture": 42})
	deadline = Time.get_ticks_msec() + 5000
	while worker.take_latest_snapshot(-1).lab_context.get("micro_capture", {}).get("request_id", 0) != 42 \
		and Time.get_ticks_msec() < deadline: await process_frame
	var captured: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	var report: Dictionary = captured.lab_context.get("micro_capture", {})
	expect(report.get("request_id",0) == 42 and report.get("state_status", "") == "failed-diagnostic-only" \
		and report.get("world", {}).is_empty(), "failed owner did not acknowledge diagnostic-only capture")
	expect(captured.simulation_failed and captured.failed_tick_index == failed.failed_tick_index \
		and captured.render_patch_cells == failed.render_patch_cells, "capture retried failure or changed physical publication")
	expect(failed.lab_context.get("micro_capture", {}).is_empty(), "capture mutated previous immutable failure publication")
	worker.stop_worker()
