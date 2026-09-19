extends SceneTree

const Pack = preload("res://scripts/microscenario_reference_pack.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
var assertions: int = 0
var failures: int = 0
class DesktopSpy:
	extends "res://scripts/main.gd"
	var captured: Dictionary = {}
	func _write_microscenario_capture(report: Dictionary) -> void:
		captured = report.duplicate(true)
		super._write_microscenario_capture(report)
class WebSpy:
	extends "res://scripts/web_demo_controller.gd"
	var captured: Dictionary = {}
	func _write_microscenario_capture(report: Dictionary) -> void:
		captured = report.duplicate(true)
		super._write_microscenario_capture(report)
func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)
func wait_for(predicate: Callable, window: bool = false) -> bool:
	var deadline: int = Time.get_ticks_msec() + (60000 if window and DisplayServer.get_name() != "headless" else 15000)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false
func click(button: Button) -> void:
	for pressed: bool in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = button.get_global_rect().get_center()
		mouse.global_position = mouse.position
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		root.push_input(mouse,true)
		await process_frame
func screenshot(name: String) -> void:
	var directory: String = OS.get_environment("MS001_SCREENSHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK,"GUI screenshot write failed")
func semantic(report: Dictionary) -> Dictionary:
	return {"tick":report.completed_tick,"content_hash":report.native.content_hash,"water_integer":report.native.water_integer,"water_cells":report.native.water_cells}
func _init() -> void:
	call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	root.size = Vector2i(1600,1200)
	var json: String = FileAccess.get_file_as_string("res://tests/fixtures/ms001-salt-water-v1.json")
	var checked: Dictionary = Contract.parse(json)
	expect(checked.ok and checked.hash == Contract.validate(Pack.interaction_fixture()).hash,"Retained generated JSON differs from its generator")
	if not checked.ok:
		quit(1)
		return
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1}),"Headless oracle owner reset failed")
	var oracle: CyberMicroScenarioHost = Host.new()
	expect(oracle.install(world,checked.definition,"Benchmark"),oracle.last_error)
	for tick: int in range(120):
		if not oracle.advance():
			expect(false,oracle.last_error)
			quit(1)
			return
	var headless: Dictionary = oracle.capture()
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopSpy)
	root.add_child(desktop)
	await process_frame
	var panel: CyberMicroScenarioPanel = desktop.microscenario_panel
	panel._open_definition()
	panel.definition_text.text = json
	panel._apply_definition()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.get("micro_active",false)),"Pasted generated fixture did not acknowledge")
	desktop._refresh_microscenario_controls()
	var bench: CyberMicroScenarioWorkbench = panel.workbench
	expect(bench.visible and bench.current.definition_hash == checked.hash,"Workbench did not consume the complete generated definition")
	expect(not desktop.get_node("Layout/Help").text.contains("jetpack"),"Actor-free fixture advertises player controls")
	expect(bench.store_active("A"),"Baseline slot rejected")
	await click(bench.run_button)
	expect(await wait_for(func() -> bool: return int(desktop.tower_context.get("tick",-1)) == 120 and bench._run_target < 0, true),"Bounded desktop window did not stop at the declared tick")
	desktop.microscenario_capture()
	expect(await wait_for(func() -> bool: return not desktop.captured.is_empty()),"Desktop owner capture failed")
	expect(semantic(desktop.captured) == semantic(headless),"Generated fixture differs between desktop UI and headless owner")
	expect(desktop.tower_context.micro_capture.is_read_only() and desktop.tower_context.micro_capture.observations.is_read_only(),"Owner handoff is mutable")
	expect(FileAccess.file_exists("user://microscenario-observation.json") and not FileAccess.file_exists("user://microscenario-observation.json.tmp"),"Atomic GUI capture did not commit cleanly")
	bench.open_details()
	expect(bench.details_text.text.contains("declared_observations") and bench.details_text.text.contains("native_sha256") and bench.details_text.text.contains("dose-initial"),"Details omit identities or complete declared results")
	expect(bench.details().scenario.observations.size() == checked.definition.observations.size(),"UI discarded declared results")
	await screenshot("materials-generated-results")
	desktop.microscenario_toggle_hud()
	await process_frame
	expect(not panel.visible and not bench.overlay.visible and not bench.details_dialog.visible,"Clean view left an overlay or dialog visible")
	desktop.microscenario_toggle_hud()
	await process_frame
	var candidate: Dictionary = Pack.interaction_fixture("salt-water",0,16)
	panel._open_definition()
	panel.definition_text.text = JSON.stringify(candidate)
	panel._apply_definition()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.get("tick",-1) == 0),"Candidate reset did not start fresh")
	desktop._refresh_microscenario_controls()
	expect(bench.store_active("B"),"Candidate slot rejected")
	desktop.captured.clear()
	expect(bench.run_declared_window(),"Candidate bounded window refused")
	expect(await wait_for(func() -> bool: return desktop.tower_context.get("tick",-1) == 120 and bench._run_target < 0, true),"Candidate window did not stop")
	desktop.microscenario_capture()
	expect(await wait_for(func() -> bool: return not desktop.captured.is_empty()),"Candidate capture failed")
	var compared: Dictionary = bench.comparison.summary()
	expect(compared.matched_runtime_tick_seed,"A/B did not retain matching runtime/tick/seed captures")
	expect(compared.slots.A.definition_hash != compared.slots.B.definition_hash,"A/B silently collapsed different definitions")
	bench.open_comparison()
	await screenshot("materials-fresh-reset-ab")
	expect(bench.load_slot("A"),"Stored baseline reload rejected")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.get("tick",-1) == 0),"Stored baseline was not a fresh reset")
	expect(desktop.tower_context.microscenario.definition_hash == checked.hash and desktop.paused,"Stored baseline identity or paused reset lost")
	var invalid: Dictionary = candidate.duplicate(true)
	invalid.seed = -1
	expect(not desktop.microscenario_apply_definition(invalid),"Invalid candidate accepted")
	expect(desktop.tower_context.microscenario.definition_hash == checked.hash,"Invalid candidate replaced the baseline")
	desktop.microscenario_apply_definition(Pack.laboratory(),"Play")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"Full Materials Laboratory reset failed")
	desktop._refresh_microscenario_controls()
	expect(bench.run_declared_window(),"Full laboratory window refused")
	expect(await wait_for(func() -> bool: return desktop.tower_context.get("tick",-1) == 240 and bench._run_target < 0, true),"Full laboratory window failed")
	expect(bench.overlay.regions.size() == 3 and not bench.material_picker.disabled,"Full laboratory regions/tools unavailable")
	expect(desktop.get_node("Layout/Help").text.contains("LMB paint") and desktop.get_node("Layout/Help").text.contains("RMB erase"),"Laboratory brush controls hidden")
	await screenshot("materials-laboratory")
	desktop.microscenario_toggle_hud()
	await process_frame
	await screenshot("materials-clean-view")
	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	desktop.queue_free()
	await process_frame

	var web: Control = load("res://web_main.tscn").instantiate()
	web.set_script(WebSpy)
	root.add_child(web)
	await process_frame
	web.focused = true
	web.ui.close_menu()
	expect(web.ready_to_play and web.microscenario_apply_definition(checked.definition,"Inspect"),"Native synchronous Web controller failed to load generated fixture")
	web._refresh_microscenario_controls()
	var web_bench: CyberMicroScenarioWorkbench = web.microscenario_panel.workbench
	expect(web_bench.store_active("A") and web_bench.run_declared_window(),"Web-controller workbench failed to start")
	expect(await wait_for(func() -> bool: return web.tower_context.get("tick",-1) == 120 and web_bench._run_target < 0, true),"Web-controller bounded window failed")
	web.microscenario_capture()
	expect(semantic(web.captured) == semantic(headless),"Generated fixture differs between native Web controller and headless owner")
	expect(web_bench.retained_capture.observations.size() == checked.definition.observations.size(),"Web UI omitted generated observations")
	expect(web_bench.load_slot("A") and web.native_world.get_tick_index() == 0,"Web A/B was not a fresh synchronous reset")
	web.rapier_bridge.shutdown()
	web.queue_free()
	await process_frame
	print("MICROSCENARIO_WORKBENCH: %d assertions; %d failures; display=%s" % [assertions,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
