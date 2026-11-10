extends SceneTree
var main: Control
var panel
func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()
func wait_for(test: Callable,seconds: int = 180) -> bool:
	var deadline := Time.get_ticks_msec()+seconds*1000
	while not test.call() and Time.get_ticks_msec()<deadline: await process_frame
	return test.call()
func run() -> void:
	root.size = Vector2i(1920,1080)
	change_scene_to_file("res://feature_launcher.tscn"); await scene_changed
	current_scene.launch("shared_workbench"); await scene_changed
	main=current_scene
	var wb: Node=main.shared_workbench
	panel=wb.art_batches
	if not await wait_for(func(): return not wb.applied.is_empty() and not wb.busy()): quit(1);return
	panel.endpoint.text=OS.get_environment("WB_ART_TEST_ENDPOINT")
	panel.model.text=OS.get_environment("WB_ART_TEST_MODEL")
	panel.tokens.value=8192
	panel.fields[0].value=0;panel.fields[1].value=0;panel.fields[2].value=64;panel.fields[3].value=128
	panel.input.text=OS.get_environment("WB_ART_BENCH_PROMPT")
	var begin := Time.get_ticks_msec()
	panel.send_prompt()
	var replied: bool=await wait_for(func(): return not panel.provider.active,190)
	var reply_ms := Time.get_ticks_msec()-begin
	var applied: bool=await wait_for(func(): return not panel.executor.active,60)
	# Show the entire authorized 64x128 area, centered with integer scaling.
	wb._set_view(Vector2(-16,-4),Vector2i(96,144))
	for i: int in range(5):await process_frame
	await RenderingServer.frame_post_draw
	var folder := OS.get_environment("WB_ART_EVIDENCE_DIR")
	root.get_texture().get_image().save_png(folder+"/workbench.png")
	var rendered: Image=root.get_texture().get_image()
	var rect: Rect2=main.world_view.get_global_rect()
	var scale := Vector2(rendered.get_width(),rendered.get_height())/root.get_visible_rect().size
	var crop := Rect2i(rect.position*scale,rect.size*scale).intersection(Rect2i(Vector2i.ZERO,rendered.get_size()))
	rendered.get_region(crop).save_png(folder+"/canvas.png")
	main.image.save_png(folder+"/native-materials.png")
	DirAccess.copy_absolute(panel.provider.log_path,folder+"/traffic.jsonl")
	var count := 0
	for y: int in range(128):
		for x: int in range(64):
			if main.image.get_pixel(x,y).r8==58:count+=1
	var report := {"prompt":panel.input.text,"requested_model":panel.model.text,"returned_model":panel.provider.returned_model,"reply_ms":reply_ms,"total_ms":Time.get_ticks_msec()-begin,"replied":replied,"executor_finished":applied,"error":panel.input_error,"result":panel.executor.result,"usage":panel.provider.usage,"native_wall_cells":count,"native_backend":panel.executor.last_receipt.get("backend","not applied"),"area":[0,0,64,128],"output_allowance":8192}
	var file := FileAccess.open(folder+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("ART_BENCH ",JSON.stringify(report))
	main.queue_free();await process_frame;await process_frame
	# Model failures are measured results, not a failed harness or fabricated pass.
	quit(0 if replied and applied else 1)
