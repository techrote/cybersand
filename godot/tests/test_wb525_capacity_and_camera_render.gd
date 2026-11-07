extends "res://tests/test_workbench_agent_mounted.gd"
## Independent regression: real maximum native receipts survive fake Responses
## transport, and camera-only motion redraws without retiring a real proposal.

func until(predicate: Callable, reason: String) -> bool:
	# Cold Windows ANGLE initialization can block the first frame beyond the
	# inherited fixture's 45-second cap. Use the existing bounded operation
	# allowance; this still requires the actual native readiness/ack predicate.
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			if Time.get_ticks_msec() <= deadline:
				return true
			break
		await process_frame
	# A synchronous render frame may cross the deadline. Reject a late ACK
	# when control returns instead of accepting a final post-deadline poll.
	return check(false,reason + " exceeded its execution allowance")

func _run() -> void:
	evidence_dir = OS.get_environment("WB_AGENT_EVIDENCE_DIR")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	wb = host.shared_workbench
	if not await until(Callable(self,"_ready_native"),"native startup"):
		_finish()
		return
	mount = wb._agent_mount
	panel = mount.panel()
	mount._toggle.button_pressed = true
	var fresh: Dictionary = Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(2048,2048))
	if not check(wb.apply(fresh),"blank native 2048 canvas") or not await until(
			Callable(self,"_ready_blank"),"blank native installation"):
		_finish()
		return
	wb._set_view(Vector2(1080,200),host.current_view_size)
	panel._task.text = "Verify exact maximum authorized wall and camera preview."
	panel._model.text = "fake-no-network"
	panel._region[0].value = 1120
	panel._region[1].value = 220
	panel._region[2].value = 64
	panel._region[3].value = 64
	panel._guard.button_pressed = false
	panel.client.configure_fake_transport_for_tests(true)
	panel._on_start()
	if not await until(Callable(self,"_ready_panel_task"),"native authorization"):
		_finish()
		return
	var serial: int = panel.client._serial
	_fake("observe","max-observe",{"region":null,"detail":"cells"})
	if not await until(func() -> bool: return _next_request(serial),"max native observation"):
		_finish()
		return
	var observed: Dictionary = _receipt()
	check(observed.get("status") == "observed" and observed.get("native_material_ids",[]).size() == 4096,
		"observation lacks 4096 actual native IDs")
	_capture_original("capacity-before")
	var tick: int = host.latest_snapshot.tick_index
	var edits: int = wb.applied.edits.size()
	serial = panel.client._serial
	_fake("prepare_edit","max-prepare",{"observation_id":observed.get("observation_id",""),
		"operations":[{"shape":"rectangle","x0":1120,"y0":220,"x1":1183,"y1":283,
			"material":58,"replace_only_material":null}]})
	if not await until(func() -> bool: return _next_request(serial),"4096-row proposed receipt"):
		_finish()
		return
	var prepared: Dictionary = _receipt()
	check(prepared.get("status") == "proposed" and prepared.get("footprint",[]).size() == 4096,
		"max native proposal was lost at client boundary")
	check(host.latest_snapshot.tick_index == tick and wb.applied.edits.size() == edits,
		"prepare mutated native time or authored start")
	var calls: Array[int] = [0,0]
	panel.proposal_overlay.set_world_to_screen(func(cell: Vector2i) -> Variant:
		calls[0] += 1
		return mount.project_cell(cell))
	panel.scope_overlay.set_world_to_screen(func(region: Rect2i) -> Variant:
		calls[1] += 1
		return mount.project_region(region))
	await RenderingServer.frame_post_draw
	await process_frame
	var before_calls: Array[int] = calls.duplicate()
	var before_rect: Variant = mount.project_cell(Vector2i(1120,220))
	var view_size: Vector2i = host.current_view_size
	wb._set_view(Vector2(1088,208),view_size)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	check(calls[0] > before_calls[0] and calls[1] > before_calls[1],
		"same-size camera pan did not redraw both native-coordinate overlays")
	check(mount.project_cell(Vector2i(1120,220)) != before_rect,
		"camera pan did not change projected cell")
	check(panel.client.is_active() and panel.proposal_overlay._cells.size() == 4096,
		"camera-only pan retired valid native proposal")
	var pan_calls: Array[int] = calls.duplicate()
	wb._set_view(host.camera_origin,view_size + Vector2i(16,16))
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	check(calls[0] > pan_calls[0] and calls[1] > pan_calls[1],"zoom did not redraw both overlays")
	serial = panel.client._serial
	_fake("apply_edit","max-apply",{"proposal_id":prepared.get("proposal_id","")})
	if not await until(func() -> bool: return _next_request(serial),"4096-row native applied receipt"):
		_finish()
		return
	var applied: Dictionary = _receipt()
	check(applied.get("status") == "applied" and applied.get("readback",[]).size() == 4096,
		"known 4096-cell applied outcome was lost")
	check(applied.get("issued_writes") == 4096 and applied.get("confirmed_writes") == 4096,
		"maximum native writes were not individually confirmed")
	check(applied.get("authored_start",{}).get("status") == "recorded",
		"verified maximum apply did not record authored start")
	check(host.latest_snapshot.tick_index == tick,"authoring advanced native ticks")
	var correct: bool = true
	for row: Dictionary in applied.get("readback",[]):
		correct = correct and row.has("actual") and row.actual == 58
	check(correct,"native maximum readback contains incorrect material")
	serial = panel.client._serial
	_fake("apply_edit","max-duplicate",{"proposal_id":prepared.get("proposal_id","")})
	if await until(func() -> bool: return _next_request(serial),"maximum duplicate apply receipt"):
		check(_receipt() == applied,"duplicate apply changed retained native receipt")
	serial = panel.client._serial
	_fake("observe","max-after",{"region":null,"detail":"cells"})
	if await until(func() -> bool: return _next_request(serial),"maximum applied native readback"):
		var after: Dictionary = _receipt()
		check(after.get("native_counts",{}).get("58",0) == 4096,"4096 real Hard Wall cells absent")
		_capture_original("capacity-after")
	print("WB525_CAPACITY_CAMERA "+JSON.stringify({"prepared_cells":prepared.get("footprint",[]).size(),
		"prepared_json_chars":JSON.stringify(prepared).length(),"applied_cells":applied.get("readback",[]).size(),
		"applied_json_chars":JSON.stringify(applied).length(),"camera_draws_before":before_calls,
		"camera_draws_after":calls,"native_tick":host.latest_snapshot.tick_index}))
	panel._on_stop()
	await until(func() -> bool: return not panel._retire_pending and not mount._authorised,"native Stop ACK")
	# Break the test callback reference cycle before releasing the real host.
	panel.proposal_overlay.set_world_to_screen(Callable())
	panel.scope_overlay.set_world_to_screen(Callable())
	var refresh_callback: Callable = Callable(mount,"_refresh_projection")
	host.queue_free()
	await process_frame
	await process_frame
	check(not process_frame.is_connected(refresh_callback),"scene exit retained global camera callback")
	_finish()
