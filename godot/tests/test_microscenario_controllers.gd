extends SceneTree

const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
var failures: int = 0
var assertions: int = 0

class DesktopSpy:
	extends "res://scripts/main.gd"
	var reset_calls: int = 0
	var captured: Dictionary = {}
	func tower_reset() -> void:
		reset_calls += 1
		super.tower_reset()
	func _write_microscenario_capture(report: Dictionary) -> void:
		captured = report.duplicate(true)

class WebSpy:
	extends "res://scripts/web_demo_controller.gd"
	var captured: Dictionary = {}
	func _write_microscenario_capture(report: Dictionary) -> void:
		captured = report.duplicate(true)

func _init() -> void:
	call_deferred("_run")

func expect(value: bool, message: String) -> void:
	assertions += 1
	if value: return
	failures += 1
	push_error(message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func key(code: Key, pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	root.size = Vector2i(1600, 1200)
	var desktop: Control = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopSpy)
	root.add_child(desktop)
	await process_frame
	var button: Button = desktop.get_node("Layout/ExperimentTowerLauncher")
	expect(button.focus_mode == Control.FOCUS_NONE, "root Tower button retained keyboard focus")
	# Send real GUI mouse and Space events through the viewport, not just signals.
	for pressed: bool in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = button.get_global_rect().get_center()
		mouse.global_position = mouse.position
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		root.push_input(mouse, true)
		await process_frame
	expect(desktop.reset_calls == 1, "mouse click did not invoke Tower exactly once")
	expect(root.gui_get_focus_owner() != button, "mouse entry left Tower focusable")
	for event: InputEventKey in [key(KEY_SPACE,true), key(KEY_SPACE,true,true), key(KEY_SPACE,false)]:
		root.push_input(event)
		await process_frame
	expect(desktop.reset_calls == 1, "Space press/hold/release re-entered Tower")
	desktop._unhandled_key_input(key(KEY_F9,true))
	desktop._unhandled_key_input(key(KEY_F9,true,true))
	desktop._unhandled_key_input(key(KEY_F9,false))
	expect(desktop.reset_calls == 2, "F9 non-echo handling is not exactly once")
	expect(await wait_for(func() -> bool: return desktop.pending_water_exit.is_empty()), "Tower prerequisite reset did not acknowledge")
	var definition: Dictionary = Catalogue.unequal_head(2)
	var wanted: String = Contract.validate(definition).hash
	expect(desktop.microscenario_apply_definition(definition, "Inspect"), "desktop generic reset refused")
	expect(not desktop.tower_command({"step":true}), "pending desktop reset was overwritten by a step")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.get("micro_active",false)), "desktop generic reset did not acknowledge")
	desktop._refresh_microscenario_controls()
	expect(desktop.microscenario_panel.picker.get_item_text(desktop.microscenario_panel.picker.selected) == "fixtures/unequal-head"
		and int(desktop.microscenario_panel.seed_input.value) == 2, "launcher selection did not match the installed fixture")
	expect(desktop.tower_context.microscenario.definition_hash == wanted, "desktop definition identity mismatch")
	expect(desktop.tower_context.tick == 0 and desktop.paused, "desktop reset did not start paused at tick zero")
	expect(not desktop.set_cadence_lod(true) and not desktop.set_liquid_surface_adhesion(false), "fixed desktop fixture accepted a live semantic override")
	expect(desktop.rigid_bodies.is_empty(), "body-disabled generic fixture retained bodies")
	expect(not desktop.queue_brush_mutation(70,190,0,3), "undeclared generic brush accepted")
	expect(not desktop.tower_command({"release":0}), "Tower release accepted in generic fixture")
	expect(desktop.tower_command({"step":true}), "desktop single step refused")
	expect(await wait_for(func() -> bool: return desktop.tower_context.get("tick",0) == 1), "desktop single step did not complete")
	await create_timer(0.08).timeout
	expect(desktop.tower_context.tick == 1, "desktop single step ran multiple ticks")
	desktop.microscenario_capture()
	expect(await wait_for(func() -> bool: return not desktop.captured.is_empty()), "desktop capture did not cross owner boundary")
	expect(desktop.captured.completed_tick == 1 and desktop.captured.definition_hash == wanted, "desktop capture lost completed-tick identity")
	expect(desktop.tower_context.micro_capture.is_read_only()
		and desktop.tower_context.micro_capture.definition.rectangles.is_read_only(), "cross-owner capture is mutable")
	var retained: Dictionary = desktop.captured.duplicate(true)
	var invalid: Dictionary = definition.duplicate(true)
	invalid.seed = -1
	expect(not desktop.microscenario_apply_definition(invalid), "invalid desktop definition accepted")
	expect(desktop.tower_context.tick == 1, "invalid desktop reset changed World")
	desktop._unhandled_key_input(key(KEY_R,true))
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.get("tick",-1) == 0), "R did not freshly reset the selected generic fixture")
	expect(desktop.tower_context.microscenario.definition_hash == wanted, "R lost selected generic definition")
	expect(retained.completed_tick == 1, "reset mutated retained capture")
	desktop.microscenario_toggle_hud()
	expect(not desktop.microscenario_panel.visible and not button.visible, "HUD hide left launch controls visible")
	for label: Label in desktop.tower_panel.labels: expect(not label.visible, "HUD hide left Tower labels visible")
	desktop._unhandled_key_input(key(KEY_F8,true))
	expect(desktop.microscenario_panel.visible and button.visible, "F8 did not restore HUD")
	desktop.tower_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_water_exit.is_empty() and not desktop.tower_context.get("micro_active",true)), "generic -> Tower reset was blocked by the floor guard")
	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	desktop.queue_free()
	await process_frame

	var web: Control = load("res://web_main.tscn").instantiate()
	web.set_script(WebSpy)
	root.add_child(web)
	await process_frame
	web.set_physics_process(false) # Explicit test stepping; presentation still consumes state.
	web.focused = true
	web.ui.close_menu()
	expect(web.ready_to_play, "synchronous controller did not initialize")
	expect(web.microscenario_apply_definition(definition, "Benchmark"), "Web-owner generic definition refused")
	expect(web.micro_host.summary().definition_hash == wanted, "owners disagree on definition identity")
	web.microscenario_capture()
	expect(web.captured.completed_tick == 0 and not web.captured.replay_complete, "Web initial capture is not truthful")
	expect(not web._encode_current().ok, "generic level export falsely represents scenario continuation")
	expect(not web.set_quality(2) and not web.set_liquid_surface_adhesion(false), "fixed synchronous fixture accepted a live semantic override")
	expect(not web.queue_explosion_mutation(80,180,4), "unregistered generic explosion accepted")
	expect(not web.queue_brush_mutation(80,180,0,2), "undeclared Web generic brush accepted")
	expect(web.tower_command({"step":true}), "Web single step refused")
	web._physics_process(1.0/60.0)
	web._physics_process(1.0/60.0)
	expect(web.native_world.get_tick_index() == 1, "Web single step was not exactly one tick")
	web.microscenario_capture()
	# The desktop and synchronous owner preserve their own coupling metadata, so
	# compare semantic content and exact quantity, not their full state_hash.
	expect(web.captured.native.content_hash == retained.native.content_hash
		and web.captured.native.water_integer == retained.native.water_integer,
		"body/player-disabled fixture differs between existing owners")
	web.microscenario_panel._open_definition()
	web.microscenario_panel.definition_text.text = "{invalid"
	web.microscenario_panel._apply_definition()
	expect(web.native_world.get_tick_index() == 1, "invalid pasted JSON changed the World")
	web.microscenario_panel.definition_dialog.hide()
	var before: Dictionary = web.captured.native.duplicate(true)
	expect(not web.microscenario_apply_definition(invalid), "invalid Web definition accepted")
	web.microscenario_capture()
	expect(web.captured.native == before, "rejected Web reset mutated state")
	web._unhandled_key_input(key(KEY_R,true))
	expect(web.native_world.get_tick_index() == 0 and web.micro_host.summary().definition_hash == wanted, "Web R did not retain the selected fixture")
	web.tower_reset()
	expect(not web.tower_context.get("micro_active",false), "Web generic -> Tower reset failed")
	web.rapier_bridge.shutdown()
	web.queue_free()
	await process_frame
	print("MICROSCENARIO_CONTROLLERS: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
