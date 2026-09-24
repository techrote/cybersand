extends SceneTree

const Pack = preload("res://scripts/microscenario_reference_pack.gd")
var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func wait_for(predicate: Callable, timeout_ms: int = 60000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func screenshot(name: String) -> void:
	var directory: String = OS.get_environment("MS001_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK,"screenshot write failed: " + name)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	root.size = Vector2i(1600,1200)
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	var panel: CyberMicroScenarioPanel = desktop.microscenario_panel
	var bench: CyberMicroScenarioWorkbench = panel.workbench

	var flood: Dictionary = Pack.flood_control(0)
	expect(desktop.microscenario_apply_definition(flood,"Play"),"desktop Flood definition refused")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.get("micro_active",false)),
		"desktop Flood reset did not acknowledge")
	desktop._refresh_microscenario_controls()
	expect(str(desktop.tower_context.microscenario.id) == Pack.FLOOD_ID,"desktop did not install Flood catalogue identity")
	expect(bench.overlay.regions.size() == 3 and bench.instructions.text.contains("protected"),"Flood UI lacks explorable objective guidance")
	expect(not bench.material_picker.disabled and bench.radius_input.editable,"Flood terrain tools are unavailable")
	await screenshot("ms001-flood-control")
	expect(bench.run_declared_window(),"Flood declared run refused")
	expect(await wait_for(func() -> bool: return int(desktop.tower_context.get("tick",-1)) == 180 and bench._run_target < 0),"Flood UI run did not reach declared horizon")
	expect(str(desktop.tower_context.microscenario.outcome) == "fail","untreated Flood UI run did not expose failure")

	var stress: Dictionary = Pack.simulation_stress("mixed",0)
	expect(desktop.microscenario_apply_definition(stress,"Benchmark"),"desktop Stress definition refused")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty() and int(desktop.tower_context.get("tick",-1)) == 0),
		"desktop Stress reset did not acknowledge")
	desktop._refresh_microscenario_controls()
	expect(str(desktop.tower_context.microscenario.id) == Pack.STRESS_PREFIX + "mixed","desktop did not install Stress catalogue identity")
	expect(bench.overlay.regions.size() == 3 and bench.instructions.text.contains("bounded workload"),"Stress UI lacks workload guidance")
	await screenshot("ms001-stress-mixed")
	expect(bench.run_declared_window(),"Stress declared run refused")
	expect(await wait_for(func() -> bool: return int(desktop.tower_context.get("tick",-1)) == 180 and bench._run_target < 0),"Stress UI run did not reach declared horizon")
	expect(str(desktop.tower_context.microscenario.outcome) == "complete","Stress UI run did not complete")
	desktop.microscenario_capture()
	expect(await wait_for(func() -> bool: return not bench.retained_capture.is_empty()),"Stress UI capture did not publish")
	expect(bench.retained_capture.work_statistics.available and int(bench.retained_capture.work_statistics.sampled_ticks) == 180,
		"Stress UI capture lacks comparable native work telemetry")

	var rem003: Dictionary = Pack.player_granular_review(0)
	expect(desktop.microscenario_apply_definition(rem003,"Play"),"desktop REM-003 review definition refused")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()
		and desktop.tower_context.get("micro_active",false)),
		"desktop REM-003 review reset did not acknowledge")
	desktop._refresh_microscenario_controls()
	expect(str(desktop.tower_context.microscenario.id) == Pack.REM003_ID,
		"desktop did not install REM-003 review catalogue identity")
	expect(bool(desktop.tower_context.microscenario.player_enabled),
		"REM-003 owner-review scenario did not enable the sampled player")
	expect(bench.overlay.regions.size() == 5
		and bench.instructions.text.contains("Owner gameplay review")
		and bench.instructions.text.contains("harder landings"),
		"REM-003 owner-review scenario lacks registered gameplay guidance")
	expect(bench.material_picker.disabled and not bench.radius_input.editable,
		"REM-003 owner-review scenario unexpectedly enabled paint authoring")
	await screenshot("rem003-player-granular-review")

	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	desktop.queue_free()
	await process_frame
	print("MICROSCENARIO_REFERENCE_PACK_UI: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
