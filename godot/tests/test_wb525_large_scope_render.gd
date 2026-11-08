extends "res://tests/test_wb525_capacity_and_camera_render.gd"
## Real full-canvas authority, bounded native reads/writes, fake HTTP only.

func model_call(tool: String, arguments: Dictionary) -> Dictionary:
	var serial: int = panel.client._serial
	_fake(tool,"large-%d" % serial,arguments)
	if not await until(func() -> bool: return _next_request(serial),"large scope "+tool): return {}
	return _receipt()

func bounded(observed: Dictionary, x: int = -1, y: int = -1) -> void:
	var r: Dictionary = observed.get("region",{})
	check(observed.get("status") == "observed" and observed.get("image_status") == "matched_post_draw","matched observation missing")
	check(int(r.get("width",0)) > 0 and int(r.get("height",0)) > 0 and int(r.get("width",0))*int(r.get("height",0)) <= 4096,"unbounded native read")
	check(observed.get("region_selection") == "camera_window","inspection window not identified")
	check(observed.has("viewport_logical_region") and observed.has("viewport_framebuffer_rect"),"viewport mapping missing")
	if x >= 0: check(int(r.get("x",-1)) == x and int(r.get("y",-1)) == y,"inspection window clamp incorrect")

func _run() -> void:
	evidence_dir = OS.get_environment("WB_AGENT_EVIDENCE_DIR")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	wb = host.shared_workbench
	if not await until(Callable(self,"_ready_native"),"native startup"):
		_finish()
		return
	var fresh: Dictionary = Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(2048,2048))
	if not check(wb.apply(fresh),"blank canvas") or not await until(Callable(self,"_ready_blank"),"blank canvas ACK"):
		_finish()
		return
	mount = wb._agent_mount
	panel = mount.panel()
	mount._toggle.button_pressed = true
	# Explicit legacy grant; larger defaults have their own native capacity test.
	panel._cell_limit.value = 4096
	panel._on_whole_canvas()
	check(panel._rect_from_fields(panel._region) == Rect2i(0,0,2048,2048),"whole canvas selection incorrect")
	panel._guard.button_pressed = true
	panel._guard_region[0].value = 1802
	panel._guard_region[1].value = 1802
	panel._guard_region[2].value = 2
	panel._guard_region[3].value = 2
	panel._task.text = "Work across the canvas with bounded inspections and protected edits."
	panel._model.text = "fake-only-no-service"
	panel.client.configure_fake_transport_for_tests(true)
	panel._set_budgets(128,256,32768)
	wb._set_view(Vector2(1740,1740),Vector2i(256,256))
	panel._on_start()
	if not await until(Callable(self,"_ready_panel_task"),"4194304-cell native authorization"):
		_finish()
		return
	var observed: Dictionary = await model_call("observe",{"region":null,"detail":"cells"})
	bounded(observed)
	check(observed.get("native_material_ids",[]).size() == 4096,"default window size incorrect")
	_capture_original("whole-canvas-default")
	var large: Dictionary = await mount._bridge.call_tool("observe",{"region":{"x":1700,"y":1700,"width":65,"height":64},"detail":"cells"})
	check(large.get("status") == "refused" and large.get("reason") == "observation_cell_budget","native observation budget enlarged")
	observed = await model_call("observe",{"region":{"x":1800,"y":1800,"width":2,"height":2},"detail":"cells"})
	check(observed.get("status") == "observed" and observed.get("native_material_ids",[]).size() == 4,"distant observation failed")
	large = await model_call("prepare_edit",{"observation_id":observed.get("observation_id",""),"operations":[{"shape":"rectangle","x0":1700,"y0":1700,"x1":1764,"y1":1763,"material":58,"replace_only_material":0}]})
	check(large.get("status") == "refused","4160-cell edit allowed")
	var guard: Dictionary = await model_call("prepare_edit",{"observation_id":observed.get("observation_id",""),"operations":[{"shape":"rectangle","x0":1802,"y0":1802,"x1":1802,"y1":1802,"material":58,"replace_only_material":0}]})
	check(guard.get("status") == "refused","protection bypassed")
	var prepared: Dictionary = await model_call("prepare_edit",{"observation_id":observed.get("observation_id",""),"operations":[{"shape":"rectangle","x0":1800,"y0":1800,"x1":1801,"y1":1801,"material":58,"replace_only_material":0}]})
	check(prepared.get("status") == "proposed" and prepared.get("changed_cells") == 4,"distant native proposal failed")
	var applied: Dictionary = await model_call("apply_edit",{"proposal_id":prepared.get("proposal_id","")})
	check(applied.get("status") == "applied" and applied.get("confirmed_writes") == 4,"four native writes missing")
	check(host.latest_snapshot.tick_index == 0,"authoring advanced native ticks")
	# 4096 is per operation, not total task authorization or edited-cell quota.
	var batched_writes := 0
	for x: int in [1400,1464]:
		wb._set_view(Vector2(x-16,1684),Vector2i(256,256))
		var window := {"x":x,"y":1700,"width":64,"height":64}
		var before_batch: Dictionary = await model_call("observe",{"region":window,"detail":"cells"})
		check(before_batch.get("native_counts",{}).get("0",-1) == 4096,"batch fixture not entirely Empty")
		var batch: Dictionary = await model_call("prepare_edit",{"observation_id":before_batch.get("observation_id",""),
			"operations":[{"shape":"rectangle","x0":x,"y0":1700,"x1":x+63,"y1":1763,"material":58,"replace_only_material":0}]})
		check(batch.get("status") == "proposed" and batch.get("changed_cells") == 4096,"full batch not proposed")
		var receipt: Dictionary = await model_call("apply_edit",{"proposal_id":batch.get("proposal_id","")})
		check(receipt.get("status") == "applied" and receipt.get("confirmed_writes") == 4096,"full batch not applied")
		var after_batch: Dictionary = await model_call("observe",{"region":window,"detail":"cells"})
		check(after_batch.get("native_counts",{}).get("58",-1) == 4096,"native batch readback not conserved")
		batched_writes += int(receipt.get("confirmed_writes",0))
		_capture_original("batch-%d" % x)
	check(batched_writes == 8192 and host.latest_snapshot.tick_index == 0,"task-wide 4096 quota or extra ticks")
	var duplicate: Dictionary = await model_call("apply_edit",{"proposal_id":prepared.get("proposal_id","")})
	check(duplicate == applied,"duplicate changed receipt")
	var stepped: Dictionary = await model_call("step",{"ticks":1})
	check(stepped.get("status") == "stepped" and stepped.get("after_tick") == 1,"large-scope Step failed")
	bounded(stepped.get("observation",{}))
	wb._set_view(Vector2(-100,-100),Vector2i(256,256))
	bounded(await model_call("observe",{"region":null,"detail":"cells"}),96,96)
	wb._set_view(Vector2(1900,1900),Vector2i(256,256))
	bounded(await model_call("observe",{"region":null,"detail":"cells"}),1888,1888)
	_capture_original("whole-canvas-edge")
	panel._on_stop()
	await until(func() -> bool: return not panel._retire_pending and not mount._authorised,"whole-canvas Stop")
	check(host.latest_snapshot.tick_index == 1,"Stop advanced ticks")
	panel._guard.button_pressed = false
	panel._signed_frame.button_pressed = true
	panel._on_whole_canvas()
	check(panel._rect_from_fields(panel._region) == Rect2i(-512,-512,2048,2048),"signed scope incorrect")
	panel._on_start()
	if await until(Callable(self,"_ready_panel_task"),"signed whole-canvas authorization"):
		bounded(await model_call("observe",{"region":null,"detail":"cells"}),1376,1376)
		_capture_original("whole-canvas-signed")
		stepped = await model_call("step",{"ticks":1})
		check(stepped.get("status") == "stepped" and stepped.get("after_tick") == 2,"signed Step failed")
		bounded(stepped.get("observation",{}),1376,1376)
		panel._on_stop()
		await until(func() -> bool: return not panel._retire_pending and not mount._authorised,"signed Stop")
	# A smaller authorized area checks both actual clamps with the camera outside it.
	panel._signed_frame.button_pressed = false
	panel._region[0].value = 1000
	panel._region[1].value = 1000
	panel._region[2].value = 128
	panel._region[3].value = 128
	panel._on_start()
	if await until(Callable(self,"_ready_panel_task"),"large partial-scope authorization"):
		bounded(await model_call("observe",{"region":null,"detail":"cells"}),1064,1064)
		wb._set_view(Vector2.ZERO,Vector2i(256,256))
		bounded(await model_call("observe",{"region":null,"detail":"cells"}),1000,1000)
		panel._on_stop()
		await until(func() -> bool: return not panel._retire_pending and not mount._authorised,"partial-scope Stop")
	print("WB525_LARGE_SCOPE "+JSON.stringify({"authorized_cells":2048*2048,"max_observation_cells":4096,"confirmed_writes":applied.get("confirmed_writes",0),"native_ticks":host.latest_snapshot.tick_index,"genuine_api_calls":0}))
	_finish()
