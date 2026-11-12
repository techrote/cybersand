extends SceneTree

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()

func run() -> void:
	var endpoint := OS.get_environment("WB_ART_TEST_ENDPOINT")
	if endpoint.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Set WB_ART_TEST_ENDPOINT and use a graphical Godot runtime.")
		quit(1)
		return
	root.size = Vector2i(1920,1080)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	var host = current_scene
	var workbench = host.shared_workbench
	var panel = workbench.art_batches
	var deadline := Time.get_ticks_msec()+30000
	while (workbench.applied.is_empty() or workbench.busy()) and Time.get_ticks_msec()<deadline:
		await process_frame
	panel.input_mode.select(2)
	panel.input_mode.item_selected.emit(2)
	panel.context_mode.select(3)
	panel.image_input.button_pressed = true
	panel.endpoint.text = endpoint
	panel.model.text = "wb-art-vision"
	panel.tokens.value = 4096
	panel.fields[2].value = 64
	panel.fields[3].value = 128
	var serial: int = panel.provider.serial
	panel.input.text = "Do not apply this cancelled observation."
	panel.send_prompt()
	var started_capture: bool = panel.capturing
	panel.stop.pressed.emit()
	for frame: int in range(3): await process_frame
	var capture_stopped: bool = started_capture and not panel.capturing and not panel.provider.active and panel.provider.serial==serial+1
	panel.input.text = 'Inspect the canvas. Add a short wall with one row at y=12 and one span at x=10, length 4, material 58. Return only a complete JSON array with one row object. Close the outer array.'
	panel.send_prompt()
	deadline = Time.get_ticks_msec()+120000
	while (panel.provider.active or panel.capturing or panel.executor.active or panel.log_draw) and Time.get_ticks_msec()<deadline:
		await process_frame
	await process_frame
	var first: bool = host.image.get_pixel(10,12).r8 == 58
	panel.context_mode.select(1)
	panel.input.text = "Revise the short wall visible in the image. Erase its first cell at x=10, y=12. Return one row with spans [[10,1,0]]. Return the complete array."
	panel.send_prompt()
	deadline = Time.get_ticks_msec()+120000
	while (panel.provider.active or panel.capturing or panel.executor.active or panel.log_draw) and Time.get_ticks_msec()<deadline:
		await process_frame
	await process_frame
	var revised: bool = host.image.get_pixel(10,12).r8 == 0 and host.image.get_pixel(11,12).r8 == 58
	print("SCANLINE_VISION ",JSON.stringify({"capture_stopped":capture_stopped,"first":first,"revised":revised,"error":panel.input_error,"log":ProjectSettings.globalize_path(panel.provider.log_path)}))
	var observed: bool = panel.provider.traffic.count("\"kind\":\"observation\"")==2
	quit(0 if capture_stopped and first and revised and observed else 1)
