extends "res://tests/test_workbench_agent_mounted.gd"
## Actual panel-selected capacity -> exclusive native owner -> original framebuffer.
## Fake Responses only; never uses a model service or a synthetic World.

func _call(tool: String, args: Dictionary) -> Dictionary:
	var serial: int = panel.client._serial
	_fake(tool,"capacity-expanded-%d" % serial,args)
	if not await until(func() -> bool: return _next_request(serial),"expanded capacity "+tool):
		return {}
	return _receipt()

func _run() -> void:
	evidence_dir = OS.get_environment("WB_AGENT_EVIDENCE_DIR")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	wb = host.shared_workbench
	if not await until(Callable(self,"_ready_native"),"native startup"):
		_finish()
		return
	var fresh: Dictionary = Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(2048,2048))
	if not check(wb.apply(fresh),"fresh native canvas") or not await until(Callable(self,"_ready_blank"),"fresh canvas ACK"):
		_finish()
		return
	mount = wb._agent_mount
	panel = mount.panel()
	mount._toggle.button_pressed = true
	panel._on_whole_canvas()
	panel._cell_limit.value = 16384
	panel._guard.button_pressed = true
	panel._guard_region[0].value = 700
	panel._guard_region[1].value = 700
	panel._guard_region[2].value = 1
	panel._guard_region[3].value = 1
	panel._task.text = "Verify an explicitly authorized 16384-cell native operation."
	panel._model.text = "fake-only-no-service"
	panel.client.configure_fake_transport_for_tests(true)
	wb._set_view(Vector2(480,480),Vector2i(256,256))
	panel._on_start()
	if not await until(Callable(self,"_ready_panel_task"),"expanded native authorization"):
		_finish()
		return
	var window := {"x":500,"y":500,"width":128,"height":128}
	var observed: Dictionary = await _call("observe",{"region":window,"detail":"cells"})
	check(observed.get("native_counts",{}).get("0",-1) == 16384,"expanded native inspection not entirely Empty")
	check(observed.get("observation_cell_limit") == 16384,"native acknowledged limit missing")
	_capture_original("expanded-before")
	var too_large: Dictionary = await mount._bridge.call_tool("observe",{"region":{"x":500,"y":500,"width":129,"height":128},"detail":"cells"})
	check(too_large.get("reason") == "observation_cell_budget","native owner did not enforce selected inspection limit")
	var refused: Dictionary = await _call("prepare_edit",{"observation_id":observed.get("observation_id",""),"operations":[{"shape":"rectangle","x0":500,"y0":500,"x1":628,"y1":627,"material":58,"replace_only_material":0}]})
	check(refused.get("status") == "refused","selected edit limit not enforced by native owner")
	refused = await _call("prepare_edit",{"observation_id":observed.get("observation_id",""),"operations":[{"shape":"disc","x":700,"y":700,"radius":0,"material":58,"replace_only_material":0}]})
	check(refused.get("reason") == "protected_region","expanded task bypassed protection")
	var prepared: Dictionary = await _call("prepare_edit",{"observation_id":observed.get("observation_id",""),"operations":[{"shape":"rectangle","x0":500,"y0":500,"x1":627,"y1":627,"material":58,"replace_only_material":0}]})
	check(prepared.get("status") == "proposed" and prepared.get("changed_cells") == 16384,"actual16384-cell proposal failed")
	var applied: Dictionary = await _call("apply_edit",{"proposal_id":prepared.get("proposal_id","")})
	check(applied.get("status") == "applied" and applied.get("confirmed_writes") == 16384,"actual16384-cell native apply missing")
	check(applied.get("readback",[]).size() == 16384,"native readback lost expanded footprint")
	check(applied.get("authored_start",{}).get("status") == "recorded","expanded apply did not persist in authored start")
	var correct := true
	for row: Dictionary in applied.get("readback",[]):
		correct = correct and row.get("actual",-1) == 58
	check(correct,"expanded native readback contains incorrect material")
	var duplicate: Dictionary = await _call("apply_edit",{"proposal_id":prepared.get("proposal_id","")})
	check(duplicate == applied,"expanded duplicate replay changed receipt")
	observed = await _call("observe",{"region":window,"detail":"cells"})
	check(observed.get("native_counts",{}).get("58",-1) == 16384,"actual native16384-cell construction missing")
	_capture_original("expanded-after")
	check(host.latest_snapshot.tick_index == 0,"edit unexpectedly advanced simulation")
	panel._on_stop()
	await until(func() -> bool: return not panel._retire_pending and not mount._authorised,"expanded native Stop ACK")
	refused = await mount._bridge.call_tool("apply_edit",{"proposal_id":"late-unissued"})
	check(refused.get("status") == "refused","Stop admitted a late native edit")
	# Qualify the actual UI maximum as another explicitly authorized task.
	panel._cell_limit.value = 65536
	wb._set_view(Vector2(880,480),Vector2i(320,320))
	panel._on_start()
	var maximum_writes := 0
	if await until(Callable(self,"_ready_panel_task"),"maximum native authorization"):
		window = {"x":900,"y":500,"width":256,"height":256}
		observed = await _call("observe",{"region":window,"detail":"cells"})
		check(observed.get("native_counts",{}).get("0",-1) == 65536,"maximum native inspection not entirely Empty")
		check(observed.get("observation_cell_limit") == 65536,"maximum acknowledged cap missing")
		_capture_original("maximum-before")
		prepared = await _call("prepare_edit",{"observation_id":observed.get("observation_id",""),"operations":[{"shape":"rectangle","x0":900,"y0":500,"x1":1155,"y1":755,"material":58,"replace_only_material":0}]})
		check(prepared.get("status") == "proposed" and prepared.get("changed_cells") == 65536,"maximum actual proposal failed")
		var maximum_applied: Dictionary = await _call("apply_edit",{"proposal_id":prepared.get("proposal_id","")})
		maximum_writes = int(maximum_applied.get("confirmed_writes",0))
		check(maximum_applied.get("status") == "applied" and maximum_writes == 65536,"maximum actual native apply failed")
		check(maximum_applied.get("authored_start",{}).get("status") == "recorded","maximum apply did not record authored start")
		observed = await _call("observe",{"region":window,"detail":"cells"})
		check(observed.get("native_counts",{}).get("58",-1) == 65536,"maximum native readback missing")
		_capture_original("maximum-after")
		panel._on_stop()
		await until(func() -> bool: return not panel._retire_pending and not mount._authorised,"maximum native Stop ACK")
	# Use ordinary authored-start Save/Load, then inspect a new native generation.
	var old_generation: int = host.latest_snapshot.render_world_generation
	var saved_name := "wb531-capacity-reopen-%d" % int(Time.get_unix_time_from_system())
	if not check(not Setup.read_named(saved_name).has("setup"),"refuse to overwrite an existing named start"):
		_finish()
		return
	wb._name.text = saved_name
	if check(wb.save_setup(),"expanded authored-start save"):
		var stored: Dictionary = Setup.read_named(saved_name)
		check(stored.has("setup") and stored.setup.edits == wb.applied.edits,"saved construction lost expanded edits")
		if check(wb.load_setup(),"expanded authored-start load") and await until(func() -> bool: return _ready_blank() and host.latest_snapshot.render_world_generation != old_generation,"reopened new native generation"):
			panel._on_start()
			if await until(Callable(self,"_ready_panel_task"),"reopened expanded authorization"):
				observed = await _call("observe",{"region":{"x":500,"y":500,"width":128,"height":128},"detail":"cells"})
				check(observed.get("native_counts",{}).get("58",-1) == 16384,"reopened native16384-cell block lost")
				_capture_original("reopened-expanded")
				observed = await _call("observe",{"region":{"x":900,"y":500,"width":256,"height":256},"detail":"cells"})
				check(observed.get("native_counts",{}).get("58",-1) == 65536,"reopened native65536-cell block lost")
				_capture_original("reopened-maximum")
				check(host.latest_snapshot.tick_index == 0,"save/load resumed simulation")
				panel._on_stop()
				await until(func() -> bool: return not panel._retire_pending and not mount._authorised,"reopened native Stop ACK")
		check(DirAccess.remove_absolute(ProjectSettings.globalize_path(Setup._path(saved_name))) == OK,"temporary named-start cleanup")
	print("WB531_EXPANDED_CELLS "+JSON.stringify({"first_grant":16384,"first_native_writes":applied.get("confirmed_writes",0),"maximum_grant":65536,"maximum_native_writes":maximum_writes,"reopened_native_generation":host.latest_snapshot.render_world_generation,"native_tick":host.latest_snapshot.tick_index,"original_pngs":6,"genuine_api_calls":0}))
	_finish()
