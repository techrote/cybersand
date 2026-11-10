extends SceneTree
const P = preload("res://scripts/art_provider.gd")
var main: Control
var panel
var checks := 0
var failures := 0
var original_settings := ""
var had_settings := false
func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1; print("PROVIDER_CHECK ",label," ",ok)
	if not ok: failures += 1; push_error(label)
func until(test: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+180000
	while not test.call() and Time.get_ticks_msec()<deadline: await process_frame
	var ok: bool = test.call(); check(ok,label); return ok
func run() -> void:
	had_settings = FileAccess.file_exists("user://art-provider.cfg")
	if had_settings: original_settings = FileAccess.get_file_as_string("user://art-provider.cfg")
	root.size = Vector2i(1920,1080)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	panel = main.shared_workbench.art_batches
	if not await until(func(): return not main.shared_workbench.applied.is_empty() and not main.shared_workbench.busy(),"native workbench ready"): quit(1); return
	var one := P.payload("OpenAI","manual-alias","hello","instructions",4096,"PNG")
	check(one.max_output_tokens==4096 and one.input[0].content[1].type=="input_image" and not one.store,"OpenAI Responses image and cap shaping")
	one = P.payload("NVIDIA","alias","hello","instructions",8192,"PNG")
	check(one.max_tokens==8192 and one.messages[1].content[1].image_url.url.ends_with("PNG"),"NVIDIA multimodal compatible shaping")
	one = P.payload("LM Studio","alias","hello","instructions",32768)
	check(one.max_tokens==32768 and one.messages[1].content is String and not one.has("api_key"),"local request without fabricated key")
	check(P.decode("OpenAI",{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"}}).error.contains("incomplete"),"reasoning/output truncation is explicit")
	check(P.decode("NVIDIA",{"choices":[{"finish_reason":"length","message":{"content":"[]"}}]}).error.contains("limit"),"chat truncation cannot partially draw")
	check(P.operations("```json\n[{\"shape\":\"pixels\"}]\n```") is Array,"fenced structured response accepted")
	panel.provider.secrets.append("TEST-secret-not-real")
	check(not panel.provider.redact('Bearer abcdefghijklmnop TEST-secret-not-real sk-abcdefghijklmnop').contains("abcdefghijklmnop"),"credential redaction")
	var base := OS.get_environment("WB_ART_TEST_ENDPOINT")
	if base.is_empty(): base = "http://localhost:1234/v1"
	var model_name := OS.get_environment("WB_ART_TEST_MODEL")
	if model_name.is_empty(): model_name = "wb-art-local"
	var profile := OS.get_environment("WB_ART_TEST_PROVIDER")
	if profile in ["OpenAI","NVIDIA"]:
		var index := 1 if profile=="OpenAI" else 2
		panel.source.select(index); panel.change_provider(index)
		panel.keys[profile] = "dummy-key-123"
	panel.image_input.button_pressed = OS.get_environment("WB_ART_TEST_IMAGE")=="1"
	panel.endpoint.text = base
	panel.model.text = model_name
	panel.fields[0].value = 0; panel.fields[1].value = 0
	panel.fields[2].value = 64; panel.fields[3].value = 128
	# Genuine inference from the same UI action used by the owner.
	for cap: int in [4096,8192,16384]:
		panel.tokens.value = cap
		panel.input.text = 'Return only a JSON array drawing a Hard Wall rectangle exactly from (10,10) through (12,12), inclusive. Use one rectangle operation with material 58. No other operations.'
		panel.send_prompt()
		check(panel.provider.active or panel.capturing,"UI starts asynchronous provider request at cap "+str(cap))
		await until(func(): return not panel.provider.active and not panel.capturing,"provider request finished at cap "+str(cap))
		check(panel.input_error.is_empty(),"model structured response admitted: "+panel.input_error)
		await until(func(): return not panel.executor.active,"native drawing acknowledged")
		await until(func(): return main.image.get_pixel(10,10).r8==58 and main.image.get_pixel(12,12).r8==58,"genuine model command applied to native World")
		check(panel.executor.last_receipt.get("backend")=="CyberNativeCellWorld","real native response identity")
	if OS.get_environment("WB_ART_COLLAB_TEST")=="1":
		panel.turn_limit.value = 2
		panel.context_mode.select(1)
		panel.input.text = "Draw a rectangle from (20,20) to (23,23). If a canvas result says it was applied, revise by adding a rectangle from (25,25) to (27,27). Return only drawing JSON."
		var before: int = panel.provider.serial
		panel.send_prompt()
		await until(func(): return not panel.provider.active and not panel.executor.active and not panel.log_draw and panel.remaining_turns==0,"two-turn collaboration finished")
		check(panel.provider.serial==before+2,"two requests consumed the explicit allowance")
		check(main.image.get_pixel(20,20).r8==58 and main.image.get_pixel(25,25).r8==58,"native draw and revision")
		panel.turn_limit.value = 1
		panel.context_mode.select(3)
		panel.input.text = "Return only a JSON array with one rectangle. Set shape to rectangle, x0 to 20, y0 to 20, x1 to 23, y1 to 23, and material to 0."
		panel.send_prompt()
		await until(func(): return not panel.provider.active and not panel.executor.active and not panel.log_draw,"human follow-up finished")
		await until(func(): return main.image.get_pixel(20,20).r8==0 and main.image.get_pixel(25,25).r8==58,"human follow-up erased first rectangle")
		panel.minimum_interval.value = 2
		panel.next_request_ms = Time.get_ticks_msec()+2000
		var serial_before_stop: int = panel.provider.serial
		panel.send_prompt()
		panel.stop_all()
		await create_timer(2.1).timeout
		check(panel.provider.serial==serial_before_stop+1 and not panel.provider.active,"Stop cancelled a paced request")
		panel.minimum_interval.value = 0
		panel.turn_limit.value = 2
		panel.spend_limit.value = 0.001
		panel.input_price.value = 1000
		panel.input.text = 'Return exactly one rectangle with x0=30, y0=30, x1=32, y1=32, material=58.'
		var serial_before_spend: int = panel.provider.serial
		panel.send_prompt()
		await until(func(): return not panel.provider.active and not panel.executor.active and not panel.log_draw and panel.remaining_turns==0,"spending-limited run finished")
		check(panel.provider.serial==serial_before_spend+1 and panel.run_spend>=0.001,"reported usage stops the next request at the estimate ceiling")
		panel.spend_limit.value = 0
		panel.input_price.value = 0
		panel.turn_limit.value = 1

	# Replacement also fences a response from the old World.
	panel.input.text = "Draw a wall rectangle from (40,40) through (60,60)."
	panel.send_prompt()
	check(main.shared_workbench.new_canvas(),"replace World during provider request")
	await until(func(): return not main.shared_workbench.busy() and not main.shared_workbench.applied.is_empty(),"replacement acknowledged")
	await until(func(): return not panel.provider.active and not panel.capturing,"old response retired after replacement")
	check(main.image.get_pixel(40,40).r8==0,"no stale provider drawing after replacement")
	# Cancellation fences any response even when a server continues generating.
	panel.input.text = "Draw a wall rectangle from (40,40) through (60,60)."
	panel.send_prompt()
	panel.stop_all()
	for i: int in range(30): await process_frame
	check(not panel.provider.active and main.image.get_pixel(40,40).r8==0,"Stop during inference prevents late drawing")
	check(FileAccess.file_exists(panel.provider.log_path),"durable traffic exists")
	var log_text := FileAccess.get_file_as_string(panel.provider.log_path)
	check(log_text.contains('"request"') and log_text.contains('"response"') and log_text.contains('"native_result"'),"full request response and native traffic retained")
	check(not log_text.contains("TEST-secret-not-real"),"durable log excludes secret")
	var resumed = P.new()
	root.add_child(resumed)
	var restored: Array = resumed.resume_traffic(panel.provider.log_path)
	check(restored == panel.conversation and resumed.log_path != panel.provider.log_path,"restore transcript with independent traffic file")
	if panel.image_input.button_pressed:
		var original_image := ""
		for entry: Dictionary in restored:
			if entry.has("image_offset"):
				original_image = resumed.historical_image(int(entry.image_offset))
				if not original_image.is_empty(): break
		check(original_image.begins_with("data:image/png;base64,"),"original canvas image restored from request log")
	resumed.queue_free()

	var folder := OS.get_environment("WB_ART_EVIDENCE_DIR")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		DirAccess.copy_absolute(panel.provider.log_path,folder+"/provider-native-traffic.jsonl")
		if DisplayServer.get_name()!="headless":
			panel.popup_centered()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/provider-ui.png")
	print("ART_PROVIDER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"provider":panel.current_provider,"requested_model":model_name,"model":panel.provider.returned_model,"usage":panel.provider.usage,"log":ProjectSettings.globalize_path(panel.provider.log_path)}))
	main.queue_free()
	await process_frame
	if had_settings:
		var file := FileAccess.open("user://art-provider.cfg",FileAccess.WRITE); file.store_string(original_settings)
	else: DirAccess.remove_absolute("user://art-provider.cfg")
	await process_frame
	quit(1 if failures else 0)
