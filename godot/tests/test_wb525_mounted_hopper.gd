extends "res://tests/test_workbench_agent_hopper_godot.gd"
## Literal frozen apparatus through the MOUNTED panel and asynchronous fake
## Responses transport. Real World/receipts/frames; zero paid calls. The +512
## physical frame remains an experimental derived control, not signed parity.
var agent_panel: Control
var agent_mount: RefCounted

func _panel_call(name: String, arguments: Dictionary) -> Dictionary:
	var client: Node = agent_panel.client
	var serial: int = client._serial
	client.receive_fake_response(client.current_epoch(),serial,200,{
		"id":"wb525-response-%d" % serial,"status":"completed","output":[{
			"type":"function_call","name":name,"call_id":"wb525-call-%d" % serial,
			"arguments":JSON.stringify(arguments)}]})
	if not await wait_for(func() -> bool:
		return not client.is_active() or (client._serial > serial and not client.pending_fake_payload().is_empty()),
		"mounted fake Responses/native call did not settle: "+name):
		return {}
	var input: Array = client.pending_fake_payload().get("input",[])
	if not check(client.is_active() and not input.is_empty(),"mounted client aborted "+name):
		return {}
	var receipt: Variant = JSON.parse_string(str(input[0].get("output","")))
	if not receipt is Dictionary:
		check(false,"missing real serialized native receipt "+name)
		return {}
	var evidence: String = OS.get_environment("WB_AGENT_527_IMAGE_DIR")
	if not evidence.is_empty():
		var record: FileAccess = FileAccess.open(evidence.path_join("panel-call-%d-%s.json" % [serial,name]),FileAccess.WRITE)
		if check(record != null,"cannot retain actual native panel receipt"):
			record.store_string(JSON.stringify({"tool":name,"arguments":arguments,"native_receipt":receipt},"  ")+"\n")
			record.close()
	# Recover exact original PNG supplied by the native/render join, without
	# re-rendering, annotation, crop or material inference from pixels.
	if input.size() > 1:
		var content: Array = input[1].get("content",[])
		if content.size() > 1:
			var url: String = str(content[1].get("image_url",""))
			if url.begins_with("data:image/png;base64,"):
				receipt["framebuffer_png"] = Marshalls.base64_to_raw(url.trim_prefix("data:image/png;base64,"))
	return receipt

func run_variant(rows: Array, variant: String) -> void:
	var old_generation: int = main.latest_snapshot.render_world_generation
	if not check(workbench.apply(initial_start(rows,variant)),"literal authored start refused "+variant):
		return
	if not await wait_for(func() -> bool:
		return _native_ready() and main.latest_snapshot.render_world_generation != old_generation,
		"native authored start not installed "+variant):
		return
	agent_mount = workbench._agent_mount
	agent_panel = agent_mount.panel()
	agent_mount._toggle.button_pressed = true
	agent_panel._signed_frame.button_pressed = true
	agent_panel._task.text = "Frozen 32 human Sand; build registered chute; protect motif; at most 480 total ticks."
	agent_panel._model.text = "fake-only-no-paid-service"
	agent_panel._region[0].value = -40
	agent_panel._region[1].value = -5
	agent_panel._region[2].value = 80
	agent_panel._region[3].value = 48
	# A bounding rectangle covers every one of the exact17 motif cells and
	# extra Empty space; the fixed agent operations do not touch either.
	agent_panel._guard_region[0].value = 30
	agent_panel._guard_region[1].value = -3
	agent_panel._guard_region[2].value = 5
	agent_panel._guard_region[3].value = 7
	agent_panel._guard.button_pressed = true
	main.shared_workbench._set_view(Vector2(460,490),main.current_view_size)
	agent_panel.client.configure_fake_transport_for_tests(true)
	# Explicit TEST-ONLY transcript budget. Production paid limits unchanged.
	agent_panel.client.request_budget = 24
	agent_panel.client.tool_budget = 24
	agent_panel._on_start()
	if not await wait_for(func() -> bool:
		return agent_panel.client.is_active() and not agent_panel._start_pending,
		"mounted native task authorization missing "+variant):
		return
	var initial: Dictionary = await _panel_call("observe",{"region":SOURCE_OBSERVATION,"detail":"cells"})
	check(initial.get("status") == "observed" and initial.get("native_counts",{}).get("2",0) == 32,
		"mounted initial native Sand !=32 "+variant)
	preserve_png(variant,"mounted-initial",initial)
	var operations: Array = author_ops(rows,variant)
	check(operations.size() == 26,"literal reference operation inventory changed")
	var batches: int = 0
	for begin: int in range(0,operations.size(),8):
		var observed: Dictionary = await _panel_call("observe",{"region":AUTHORING_OBSERVATION,"detail":"counts"})
		var prepared: Dictionary = await _panel_call("prepare_edit",{
			"observation_id":observed.get("observation_id",""),
			"operations":operations.slice(begin,mini(begin+8,operations.size()))})
		if not check(prepared.get("status") == "proposed","mounted prepare refused "+variant):
			break
		var applied: Dictionary = await _panel_call("apply_edit",{"proposal_id":prepared.get("proposal_id","")})
		if not check(applied.get("status") == "applied" and applied.get("authored_start",{}).get("status") == "recorded",
			"mounted native apply not confirmed "+variant):
			break
		batches += 1
	check(batches == 4 and main.latest_snapshot.tick_index == 0,"mounted construction incomplete or stepped")
	var total: int = 0
	for _round: int in range(4):
		if total + TICKS_PER_CALL > TOTAL_TICKS:
			check(false,"aggregate frozen allowance exceeded")
			break
		var stepped: Dictionary = await _panel_call("step",{"ticks":TICKS_PER_CALL})
		if not check(stepped.get("status") == "stepped" and stepped.get("completed") == TICKS_PER_CALL
			and stepped.get("before_tick") == total and stepped.get("after_tick") == total + TICKS_PER_CALL
			and stepped.get("still_paused") == true
			and stepped.get("observation",{}).get("image_status") == "matched_post_draw",
			"mounted step lacks exact native/frame ACK "+variant):
			break
		total += TICKS_PER_CALL
	var final: Dictionary = await _panel_call("observe",{"region":target_region(rows,variant),"detail":"cells"})
	check(final.get("status") == "observed" and final.get("native_counts",{}).get("2",0) == 32,
		"mounted native terminal catchment !=32 "+variant)
	preserve_png(variant,"mounted-terminal",final)
	var guard: Dictionary = await _panel_call("observe",{
		"region":{"x":30,"y":-3,"width":5,"height":7},"detail":"cells"})
	check(guard.get("native_counts",{}).get("58",0) == 17,"mounted protected motif changed")
	check(total == TOTAL_TICKS and main.latest_snapshot.tick_index == TOTAL_TICKS,
		"mounted TOTAL native ticks !=480")
	agent_panel._on_stop()
	await wait_for(func() -> bool: return not agent_panel._retire_pending and not agent_mount._authorised,
		"mounted native Stop did not acknowledge")
	var stopped_tick: int = main.latest_snapshot.tick_index
	for _frame: int in range(4):
		await process_frame
	check(main.latest_snapshot.tick_index == stopped_tick and stopped_tick == TOTAL_TICKS,
		"native mutated after mounted Stop ACK")
	print("WB525_MOUNTED_HOPPER "+JSON.stringify({"variant":variant,
		"sand":final.get("native_counts",{}).get("2",-1),"protected":guard.get("native_counts",{}).get("58",-1),
		"completed_ticks":total,"applied_batches":batches,"fake_request_budget":24,
		"fake_requests_used":agent_panel.client._request_count,"genuine_api_calls":0,
		"experimental_frame_not_signed_trajectory_acceptance":true}))
