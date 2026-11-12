extends SceneTree

var host: Control
var panel
var failures := 0

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("SCANLINE_CHECK ",label," ",ok)
	if not ok: failures += 1

func until(test: Callable, seconds: int = 30) -> bool:
	var deadline := Time.get_ticks_msec()+seconds*1000
	while not test.call() and Time.get_ticks_msec()<deadline: await process_frame
	return test.call()

func idle() -> bool:
	return not panel.provider.active and not panel.capturing and not panel.executor.active and not panel.log_draw and panel.remaining_turns == 0

func run() -> void:
	var endpoint := OS.get_environment("WB_ART_TEST_ENDPOINT")
	var evidence := OS.get_environment("WB_ART_EVIDENCE_DIR")
	if endpoint.is_empty() or evidence.is_empty():
		push_error("Set WB_ART_TEST_ENDPOINT and WB_ART_EVIDENCE_DIR.")
		quit(1)
		return
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	host = current_scene
	var wb = host.shared_workbench
	panel = wb.art_batches
	if not await until(func(): return not wb.applied.is_empty() and not wb.busy()):
		quit(1)
		return
	panel.input_mode.select(2)
	panel.input_mode.item_selected.emit(2)
	panel.current_provider = "LM Studio"
	panel.endpoint.text = endpoint
	panel.model.text = "wb-art-vision"
	panel.tokens.value = 4096
	panel.context_mode.select(3)
	panel.turn_limit.value = 1
	panel.image_input.button_pressed = false
	panel.fields[0].value = 0
	panel.fields[1].value = 0
	panel.fields[2].value = 256
	panel.fields[3].value = 256
	panel.input.text = "Draw a row at y=250 with a span at x=0, length 128, material 58."
	panel.send_prompt()
	check(panel.provider.active,"inference active before Stop")
	panel.stop.pressed.emit()
	await create_timer(0.4).timeout
	check(idle() and host.image.get_pixel(0,250).r8==0,"Stop during inference fences drawing")
	var start := Time.get_ticks_msec()
	panel.minimum_interval.value = 0.5
	var completed := 0
	for turn: int in range(12):
		var y := 16+turn*8
		panel.input.text = 'Return exactly this complete JSON array: [{"y":%d,"repeat":4,"scale":1,"spans":[{"x":10,"length":120,"material":58}]}].' % y
		panel.send_prompt()
		if not await until(idle,45):
			panel.stop_all()
			check(false,"scanline request timed out")
			break
		var applied := await until(func(): return host.image.get_pixel(10,y).r8==58 and host.image.get_pixel(129,y+3).r8==58,2)
		check(applied,"model scanline %d applied through native readback" % (turn+1))
		if applied: completed += 1
		else: print("SCANLINE_MODEL_ERROR ",panel.input_error)
	var duration := Time.get_ticks_msec()-start
	var durable_log: String = panel.provider.log_path
	panel.next_request_ms = Time.get_ticks_msec()+1000
	var serial: int = panel.provider.serial
	panel.send_prompt()
	check(panel.waiting_until_ms > Time.get_ticks_msec(),"request waiting for pacing")
	panel.stop.pressed.emit()
	await create_timer(1.15).timeout
	check(panel.provider.serial==serial+1 and idle(),"Stop during pacing prevents dispatch")
	panel.minimum_interval.value = 0
	panel.provider.log_path = "user://missing-scanline-fixture/traffic.jsonl"
	panel.input.text = 'Return exactly this complete JSON array: [{"y":130,"spans":[{"x":10,"length":12,"material":58}]}].'
	panel.send_prompt()
	check(await until(idle,45),"drawing finishes despite failed logging")
	check(await until(func(): return host.image.get_pixel(10,130).r8==58,2) and not panel.provider.log_warning.is_empty(),"native draw survives log I/O failure")
	panel.provider.log_path = durable_log
	# Inject a deterministic stencil to place Stop exactly at the first receipt.
	panel.request_area = Rect2i(0,0,256,256)
	panel.request_materials = [0,58]
	var operations: Array = panel.local_operations(panel.stencil_operations([{"y":160,"repeat":80,"spans":[[0,256,58]]}]))
	var halt := func(_receipt: Dictionary) -> void: panel.stop.pressed.emit()
	panel.executor.native_receipt.connect(halt,CONNECT_ONE_SHOT)
	panel.executor.submit(operations,panel.request_area,[],panel.request_materials)
	check(await until(func(): return not panel.executor.active),"Stop at native scanline receipt retires batch")
	var prefix: int = panel.executor.result.checked
	check(await until(func(): return host.image.get_pixel(0,160).r8==58,2),"confirmed prefix remains visible")
	await create_timer(0.4).timeout
	check(prefix==4096 and panel.executor.result.status=="partial" and host.image.get_pixel(0,176).r8==0,"Stop preserves first chunk and fences remaining rows")
	DirAccess.make_dir_recursive_absolute(evidence)
	var export_path := evidence.path_join("scanline-traffic.jsonl")
	check(DirAccess.copy_absolute(durable_log,export_path)==OK,"durable scanline traffic exported")
	var exported := FileAccess.get_file_as_string(export_path)
	check(exported.contains('"kind":"cancelled"') and exported.contains('"kind":"native_result"') and exported.contains('"kind":"pace_wait"'),"export contains early Stop, receipts and pacing")
	print("SCANLINE_SESSION ",JSON.stringify({"completed":completed,"elapsed_ms":duration,"stop_prefix":prefix,"failures":failures}))
	quit(0 if failures == 0 else 1)
