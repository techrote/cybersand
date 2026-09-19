extends SceneTree

const Pack = preload("res://scripts/microscenario_reference_pack.gd")
var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func wait_for(predicate: Callable, timeout_ms: int = 20000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	root.size = Vector2i(1600,1200)
	var definition: Dictionary = Pack.interaction_fixture()

	# Desktop owner: opening Definition JSON is a modal pause boundary. A bounded
	# run may have one already-admitted step, but no further steps may be scheduled.
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	expect(desktop.microscenario_apply_definition(definition,"Inspect"),"desktop definition refused")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.get("micro_active",false)),
		"desktop definition did not acknowledge")
	desktop._refresh_microscenario_controls()
	var panel: CyberMicroScenarioPanel = desktop.microscenario_panel
	var bench: CyberMicroScenarioWorkbench = panel.workbench
	expect(bench.run_declared_window(),"desktop bounded run refused")
	expect(await wait_for(func() -> bool: return int(desktop.tower_context.get("tick",0)) >= 5),"desktop bounded run did not progress")
	panel._open_definition()
	var modal_tick: int = int(desktop.tower_context.get("tick",0))
	expect(panel.definition_dialog.visible and desktop.paused,"definition modal did not pause")
	expect(bench._run_target < 0 and bench._awaiting_tick < 0,"definition modal left bounded-run driver active")
	await create_timer(0.5).timeout
	var after_modal_tick: int = int(desktop.tower_context.get("tick",0))
	expect(after_modal_tick <= modal_tick + 1,"definition modal continued bounded stepping")
	panel.definition_dialog.hide()

	# Clean view stays clean across normal status refresh, including the telemetry label.
	desktop.debug_stats_visible = true
	desktop.microscenario_toggle_hud()
	expect(desktop.microscenario_hud_hidden and not desktop.status_label.visible,"F8 did not hide status telemetry")
	desktop.update_status()
	expect(not desktop.status_label.visible,"normal status refresh restored telemetry in clean view")
	desktop.microscenario_toggle_hud()

	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	desktop.queue_free()
	await process_frame

	# Synchronous Web owner: resetting the same complete definition invalidates the
	# old run waiter immediately. The definition hash is not a World-instance identity.
	var web: Control = load("res://web_main.tscn").instantiate()
	root.add_child(web)
	await process_frame
	web.focused = true
	web.ui.close_menu()
	expect(web.ready_to_play and web.microscenario_apply_definition(definition,"Inspect"),"Web definition refused")
	web._refresh_microscenario_controls()
	var web_bench: CyberMicroScenarioWorkbench = web.microscenario_panel.workbench
	expect(web_bench.run_declared_window(),"Web bounded run refused")
	web.microscenario_reset()
	web._refresh_microscenario_controls()
	expect(int(web.native_world.get_tick_index()) == 0,"same-definition reset did not rebuild at tick zero")
	expect(web_bench._run_target < 0 and web_bench._awaiting_tick < 0,"same-definition reset retained stale bounded-run waiter")
	expect(not web.tower_single_step,"same-definition reset left a stale single-step command")
	await create_timer(0.25).timeout
	web._refresh_microscenario_controls()
	expect(web.microscenario_error.is_empty(),"valid same-definition reset later reported a false run timeout")
	web.rapier_bridge.shutdown()
	web.queue_free()
	await process_frame

	print("MICROSCENARIO_WORKBENCH_LIFECYCLE: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
