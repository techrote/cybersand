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
		if begin == 0:
			# A genuinely completed apply must replay its original receipt if the
			# model retries an opaque proposal, without issuing a second native edit.
			# This extra fake HTTP turn fits the existing 24-call test-only budget.
			var old_edits: Array = workbench.applied.edits.duplicate(true)
			var old_revision: int = main.simulation_worker.agent_manual_intent_revision()
			var replay_generation: int = main.latest_snapshot.render_world_generation
			var replayed: Dictionary = await _panel_call("apply_edit",{
				"proposal_id":prepared.get("proposal_id","")})
			check(replayed.get("status") == "applied"
				and replayed.get("proposal_id","") == applied.get("proposal_id","")
				and replayed.get("readback",[]) == applied.get("readback",[])
				and replayed.get("changed_cells",-1) == applied.get("changed_cells",-2)
				and replayed.get("authored_start",{}) == applied.get("authored_start",{})
				and workbench.applied.edits == old_edits
				and main.simulation_worker.agent_manual_intent_revision() == old_revision
				and main.latest_snapshot.render_world_generation == replay_generation
				and main.latest_snapshot.tick_index == 0,
				"mounted duplicate native apply did not replay exact receipt without second mutation "+variant)
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
	# Leave a valid native prepare unapplied. It must not reappear when the
	# human stops, saves the authored apparatus and reopens a new generation.
	# The test's 24 fake-HTTP call allowance still bounds both variants.
	var pending_site: Dictionary = {"x":-39,"y":-4,"width":1,"height":1}
	var before_pending: Dictionary = await _panel_call("observe",{
		"region":pending_site,"detail":"cells"})
	check(before_pending.get("status")=="observed"
		and before_pending.get("native_counts",{}).get("0",-1)==1,
		"unapplied site was not native Empty before Stop "+variant)
	var pending: Dictionary = await _panel_call("prepare_edit",{
		"observation_id":before_pending.get("observation_id",""),
		"operations":[{
			"shape":"rectangle","x0":-39,"y0":-4,"x1":-39,"y1":-4,
			"material":58,"replace_only_material":0}]})
	check(pending.get("status")=="proposed"
		and not str(pending.get("proposal_id","")).is_empty(),
		"mounted panel failed to prepare an unapplied native proposal "+variant)
	var original_request_count: int = agent_panel.client._request_count
	var obsolete_epoch: int = agent_panel.client.current_epoch()
	var obsolete_serial: int = agent_panel.client._serial
	var stop_generation: int = main.latest_snapshot.render_world_generation
	agent_panel._on_stop()
	if not await wait_for(func() -> bool:
		return not agent_panel._retire_pending and not agent_mount._authorised and not agent_panel.client.is_active(),
		"mounted native Stop did not acknowledge "+variant):
		return
	var stopped_tick: int = main.latest_snapshot.tick_index
	for _frame: int in range(4):
		await process_frame
	check(main.latest_snapshot.tick_index == stopped_tick and stopped_tick == TOTAL_TICKS,
		"native mutated after mounted Stop ACK "+variant)
	check(agent_panel.proposal_overlay._cells.is_empty(),
		"mounted Stop failed to clear the unapplied proposal preview "+variant)
	# Save/Load is the normal human workbench UI path, not a native-state
	# checkpoint or an agent-provided filesystem operation.
	var name: String = "wb-agent-528-panel-reopen-" + variant
	workbench._name.text = name
	if not check(workbench.save_setup(),
		"mounted authored-start save refused "+variant):
		return
	var saved_start: Dictionary = Setup.read_named(name)
	check(saved_start.has("setup")
		and saved_start.setup.edits==workbench.applied.edits,
		"mounted authored-start file did not retain human/agent geometry "+variant)
	if not check(workbench.load_setup(),
		"mounted authored-start load refused "+variant):
		return
	if not await wait_for(func() -> bool:
		return _native_ready() and main.latest_snapshot.render_world_generation != stop_generation and main.latest_snapshot.tick_index==0,
		"mounted authored-start load did not create a fresh paused World "+variant):
		return
	var reopened_generation: int = main.latest_snapshot.render_world_generation
	# The old fake-provider response may arrive while a NEW task is active.
	# Neither the old response nor the retired native proposal has authority.
	agent_panel._task.text = "Read-only audit of reopened authored start; do not mutate."
	agent_panel._on_start()
	if not await wait_for(func() -> bool:
		return agent_panel.client.is_active() and not agent_panel._start_pending and agent_mount._authorised,
		"mounted panel could not authorize new generation after Save/Load "+variant):
		return
	agent_panel.client.receive_fake_response(obsolete_epoch,obsolete_serial,200,{
		"id":"wb525-late-retired-%s" % variant,"status":"completed","output":[{
			"type":"function_call","name":"apply_edit",
			"call_id":"wb525-retired-%s" % variant,
			"arguments":JSON.stringify({"proposal_id":pending.get("proposal_id","")})}]})
	for _frame: int in range(4):
		await process_frame
	check(main.latest_snapshot.tick_index==0
		and main.latest_snapshot.render_world_generation==reopened_generation,
		"late old-generation API completion changed new native World "+variant)
	var reopened_source: Dictionary = await _panel_call("observe",{
		"region":SOURCE_OBSERVATION,"detail":"cells"})
	check(reopened_source.get("status")=="observed"
		and reopened_source.get("native_counts",{}).get("2",-1)==32
		and reopened_source.get("image_status")=="matched_post_draw"
		and reopened_source.get("identity",{}).get("completed_tick",-1)==0,
		"mounted reopened start lacked 32 original Sand and matching PNG "+variant)
	preserve_png(variant,"mounted-reopened-authored-start",reopened_source)
	var reopened_guard: Dictionary = await _panel_call("observe",{
		"region":{"x":30,"y":-3,"width":5,"height":7},"detail":"cells"})
	check(reopened_guard.get("native_counts",{}).get("58",-1)==17,
		"mounted reopened start lost 17 protected Hard Wall cells "+variant)
	var reopened_pending: Dictionary = await _panel_call("observe",{
		"region":pending_site,"detail":"cells"})
	check(reopened_pending.get("status")=="observed"
		and reopened_pending.get("native_counts",{}).get("0",-1)==1,
		"retired unapplied proposal leaked into reopened native World "+variant)
	var reopened_request_count: int = agent_panel.client._request_count
	agent_panel._on_stop()
	await wait_for(func() -> bool:
		return not agent_panel._retire_pending and not agent_mount._authorised and not agent_panel.client.is_active(),
		"mounted reopened task did not receive native Stop ACK "+variant)
	check(main.latest_snapshot.tick_index==0
		and main.latest_snapshot.render_world_generation==reopened_generation,
		"reopened read-only panel audit mutated native World "+variant)
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(
		Setup._path(name)))==OK,
		"mounted test failed to clean named authored-start file "+variant)
	print("WB525_MOUNTED_HOPPER "+JSON.stringify({"variant":variant,
		"sand":final.get("native_counts",{}).get("2",-1),
		"protected":guard.get("native_counts",{}).get("58",-1),
		"completed_ticks":total,"applied_batches":batches,"fake_request_budget":24,
		"fake_requests_used":original_request_count,"reopen_fake_requests_used":reopened_request_count,
		"reopened_initial_sand":reopened_source.get("native_counts",{}).get("2",-1),
		"reopened_protected":reopened_guard.get("native_counts",{}).get("58",-1),
		"reopened_unapplied_empty":reopened_pending.get("native_counts",{}).get("0",-1),
		"reopened_native_tick":main.latest_snapshot.tick_index,
		"reopened_matched_png":reopened_source.get("image_status",""),
		"genuine_api_calls":0,
		"experimental_frame_not_signed_trajectory_acceptance":true}))
