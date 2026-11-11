extends SceneTree
var host: Control
var panel
var checks := []
var evidence := ""
var frames := 0
var max_frame_ms := 0
var last_frame_ms := 0
func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	process_frame.connect(func() -> void:
		var now := Time.get_ticks_msec()
		if last_frame_ms > 0: max_frame_ms = maxi(max_frame_ms,now-last_frame_ms)
		last_frame_ms = now
		frames += 1)
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"label":label})
	print("ART_SMOKE ",label," ",ok)
func until(test: Callable, label: String, seconds: int = 30) -> bool:
	var deadline := Time.get_ticks_msec()+seconds*1000
	while not test.call() and Time.get_ticks_msec()<deadline: await process_frame
	var ok: bool = test.call()
	check(ok,label)
	return ok
func idle() -> bool:
	return not panel.provider.active and not panel.capturing and not panel.executor.active and not panel.log_draw and panel.remaining_turns == 0
func digest(bytes: PackedByteArray) -> String:
	var hash_bytes := HashingContext.new()
	hash_bytes.start(HashingContext.HASH_SHA256)
	hash_bytes.update(bytes)
	return hash_bytes.finish().hex_encode()
func capture(name_text: String) -> String:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check(img.save_png(evidence+"/"+name_text+".png")==OK,name_text+" original framebuffer saved")
	var rect: Rect2 = host.view_content_rect()
	rect.position += host.world_view.get_global_rect().position
	var scale := Vector2(img.get_width(),img.get_height())/root.get_visible_rect().size
	var region := Rect2i(rect.position*scale,rect.size*scale).intersection(Rect2i(Vector2i.ZERO,img.get_size()))
	var canvas := img.get_region(region)
	check(canvas.save_png(evidence+"/"+name_text+"-canvas.png")==OK,name_text+" original canvas crop saved")
	return digest(canvas.get_data())
func area(x: int,y: int,w: int,h: int) -> void:
	var values := [x,y,w,h]
	for i: int in range(4): panel.fields[i].value = values[i]
func run() -> void:
	evidence = OS.get_environment("WB_ART_EVIDENCE_DIR")
	if evidence.is_empty() or OS.get_environment("WB_ART_TEST_ENDPOINT").is_empty(): quit(1);return
	if DisplayServer.get_name()=="headless": push_error("Graphical smoke requires a framebuffer");quit(1);return
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1600,1000)
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host = current_scene
	var wb: Node = host.shared_workbench
	panel = wb.art_batches
	# Ignore the human brush outline, which follows the physical mouse independently.
	host.brush_preview.modulate.a = 0
	if not await until(func(): return not wb.applied.is_empty() and not wb.busy(),"native canvas ready"): quit(1);return
	panel.endpoint.text = OS.get_environment("WB_ART_TEST_ENDPOINT")
	panel.model.text = "graphical-fixture"
	panel.image_input.button_pressed = true
	panel.context_mode.select(0)
	panel.turn_limit.value = 1
	panel.minimum_interval.value = 0
	panel.conversation.clear()
	area(0,0,1024,1024)
	panel.protect.button_pressed = true
	var guard := [128,12,32,4]
	for i: int in range(4): panel.protected_fields[i].value = guard[i]
	wb._set_view(Vector2(0,0),Vector2i(1900,1100))
	var blank_hash := await capture("00-blank")
	panel.traffic_window.popup(Rect2i(10,10,700,400))
	panel.input.text = "SMOKE_INITIAL polygon and airbrush composition"
	max_frame_ms = 0
	last_frame_ms = Time.get_ticks_msec()
	var start := Time.get_ticks_msec()
	panel.draw.pressed.emit()
	if not await until(func(): return panel.executor.active and panel.executor.result.changed>=8192,"incremental native changes during active draw"): quit(1);return
	var first_changes: int = panel.executor.result.changed
	var first_hash := await capture("01-incremental")
	check(first_hash!=blank_hash and panel.executor.active,"visible output before completion")
	await until(func(): return panel.executor.result.changed>first_changes+8192,"second incremental native prefix")
	var second_hash := await capture("02-incremental")
	check(second_hash!=first_hash and panel.executor.active,"second distinct active framebuffer")
	var before_stop: int = panel.executor.result.checked
	panel.stop.pressed.emit()
	await until(idle,"Stop retires model and native drawing")
	var stopped: Dictionary = panel.executor.result.duplicate()
	# Allow the already-completed native prefix to reach its rendered snapshot.
	await create_timer(0.15).timeout
	var native_stopped: String = digest(host.image.get_data())
	var stopped_hash := await capture("03-stopped")
	await create_timer(0.5).timeout
	var late_hash := await capture("04-after-stop")
	check(panel.executor.result.checked==stopped.checked,"Stop prevents late native receipts")
	check(native_stopped==digest(host.image.get_data()),"Stop preserves native material image")
	check(stopped_hash==late_hash,"Stop preserves rendered canvas pixels")
	check(stopped.status=="partial" and stopped.checked-before_stop<=4096,"Stop preserves only admitted native prefix")
	check(host.image.get_pixel(130,13).r8==0 and stopped.excluded>=128,"protected rectangle untouched")
	check(host.image.get_pixel(100,900).r8==0,"uncompleted polygon remainder untouched")
	var first_ms := Time.get_ticks_msec()-start
	# Preserve the real conversation; only change the next work area.
	area(1200,200,512,512)
	panel.protect.button_pressed = false
	panel.input.text = "SMOKE_LOCAL follow-up in changed area"
	panel.draw.pressed.emit()
	await until(idle,"local follow-up with retained history finishes")
	await until(func(): return host.image.get_pixel(1210,210).r8==58,"local geometry translated into new world area")
	await capture("05-local-followup")
	check(panel.executor.last_receipt.get("backend")=="CyberNativeCellWorld","actual compiled native World receipts")
	# The hosted adapters use world coordinates. Keep the same conversation.
	panel.current_provider = "OpenAI"
	panel.keys.OpenAI = "smoke-dummy-key-not-real"
	area(1200,750,512,256)
	panel.input.text = "SMOKE_WORLD follow-up in changed area"
	panel.draw.pressed.emit()
	await until(idle,"world-coordinate follow-up finishes")
	await until(func(): return host.image.get_pixel(1210,760).r8==58,"world geometry appears in third area")
	await capture("06-world-followup")
	panel.input.text = "SMOKE_STALE intentionally stale geometry"
	panel.draw.pressed.emit()
	await until(idle,"stale hosted packet finishes without mutation")
	check(panel.executor.result.changed==0 and panel.executor.result.checked==panel.executor.result.excluded,"stale coordinates excluded")
	await process_frame
	check(panel.state.text.contains("No pixels applied"),"all-skipped draw has explicit UI feedback")
	check(host.image.get_pixel(1000,1000).r8==0,"stale packet did not write outside selected area")
	check(panel.conversation.size()>=12,"conversation and native feedback retained across sends")
	panel.traffic_window.hide()
	await capture("07-final")
	host.image.save_png(evidence+"/native-materials.png")
	DirAccess.copy_absolute(panel.provider.log_path,evidence+"/traffic.jsonl")
	var failed := checks.filter(func(row: Dictionary) -> bool: return not row.ok).size()
	var result := {"checks":checks,"failures":failed,"frames":frames,"max_frame_ms":max_frame_ms,"stop_prefix":stopped,"initial_stop_ms":first_ms,"native_backend":panel.executor.last_receipt.get("backend"),"fixture":"scripted HTTP responses; no genuine provider inference"}
	var file := FileAccess.open(evidence+"/smoke-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "));file.close()
	print("ART_SMOKE_RESULT ",JSON.stringify(result))
	host.queue_free();await process_frame;await process_frame
	quit(1 if failed else 0)
