extends SceneTree

# Glow control contract: the Boolean, overlay visibility and source-viewport
# update mode agree after desktop/Web G, initialization and Web level restore.
# Non-graphical: it checks node state, not rendered pixels.

var failures: int = 0
var assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func expect(value: bool, message: String) -> void:
	assertions += 1
	if value: return
	failures += 1
	push_error(message)


func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func agrees(controller: Object, enabled: bool, context: String) -> void:
	expect(controller.glow_enabled == enabled, "%s: flag is not %s" % [context, enabled])
	expect(controller.glow_overlay.visible == enabled, "%s: overlay visibility disagrees" % context)
	var mode: int = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	expect(controller.glow_viewport.render_target_update_mode == mode,
		"%s: source viewport update mode disagrees" % context)


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	agrees(desktop, true, "desktop initialization")
	desktop._unhandled_key_input(key(KEY_G))
	agrees(desktop, false, "desktop G off")
	desktop._unhandled_key_input(key(KEY_G))
	agrees(desktop, true, "desktop G on")
	desktop.set_glow_enabled(true)
	agrees(desktop, true, "desktop idempotent on")
	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	desktop.queue_free()
	await process_frame

	var web: Control = load("res://web_main.tscn").instantiate()
	root.add_child(web)
	await process_frame
	web.set_physics_process(false)
	web.focused = true
	web.ui.close_menu()
	expect(web.ready_to_play, "Web controller did not initialize")
	agrees(web, true, "Web initialization")
	web._unhandled_key_input(key(KEY_G))
	agrees(web, false, "Web G off")
	var saved: Dictionary = web._encode_current()
	expect(saved.ok, "Web level export failed")
	web._unhandled_key_input(key(KEY_G))
	agrees(web, true, "Web G on")
	if saved.ok:
		web.import_save(str(saved.text))
		expect(web.last_save_error.is_empty(), "Web level restore failed: " + web.last_save_error)
		agrees(web, false, "Web restore of glow-off level")
	web.set_glow_enabled(false)
	agrees(web, false, "Web idempotent off")
	web.queue_free()
	await process_frame

	print("MATERIAL_GLOW_CONTROL: %d assertions, %d failures" % [assertions, failures])
	quit(failures)
