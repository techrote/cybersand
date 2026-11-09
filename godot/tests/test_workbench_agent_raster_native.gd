extends "res://tests/test_wb525_capacity_and_camera_render.gd"
## Actual Python child -> native proposal/readback/PNG -> Stop in both modes.
func job(scanline: bool) -> bool:
 var label := "scanline" if scanline else "pixels"
 var fresh: Dictionary = Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(2048,2048))
 fresh.edits.append([28,28,1,1,2])
 fresh.edits.append([32,32,1,1,58]) # Existing wall inside the scanline mask's blank hole.
 if not check(wb.apply(fresh),label+" fresh recipe") or not await until(Callable(self,"_ready_blank"),label+" reset ACK"): return false
 panel._authoring_mode.select(1 if scanline else 0)
 panel._select_authoring_mode(1 if scanline else 0)
 panel._provider.select(4)
 panel._provider_selected(4)
 panel._task.text = "Test "+label+" exact placement, preserve protected Sand and blank mask areas."
 panel._set_budgets(24,24,4096,180)
 panel._rate_limit.value = 500000
 panel._region[0].value = 0
 panel._region[1].value = 0
 panel._region[2].value = 128
 panel._region[3].value = 128
 var points: Array = []
 for i: int in range(32): points.append([30+i,30])
 var area := {"x":28,"y":28,"width":64,"height":8}
 var inspect := {"tool":"observe","args":{"region":area,"detail":"cells"}}
 var first: Dictionary
 var erase: Dictionary
 var refused: Dictionary
 var wall_count := 37 if scanline else 32
 if scanline:
  first = {"tool":"prepare_stamp","args":{"observation_id":"$last_obs","stamp":{"x":30,"y":30,"width":4,"height":3,"scale":2,"material":58,"rows":[{"repeat":1,"spans":[[0,4]]},{"repeat":1,"spans":[[0,1],[3,1]]},{"repeat":1,"spans":[[0,4]]}]}}}
  erase = {"tool":"prepare_stamp","args":{"observation_id":"$last_obs","stamp":{"x":30,"y":30,"width":1,"height":1,"scale":2,"material":0,"rows":[{"repeat":1,"spans":[[0,1]]}]}}}
  refused = {"tool":"prepare_stamp","args":{"observation_id":"$last_obs","stamp":{"x":28,"y":28,"width":1,"height":1,"scale":1,"material":58,"rows":[{"repeat":1,"spans":[[0,1]]}]}}}
 else:
  first = {"tool":"prepare_pixels","args":{"observation_id":"$last_obs","material":58,"points":points}}
  erase = {"tool":"prepare_pixels","args":{"observation_id":"$last_obs","material":0,"points":[[31,30]]}}
  refused = {"tool":"prepare_pixels","args":{"observation_id":"$last_obs","material":58,"points":[[28,28]]}}
 panel.client.acceptance = {"native_counts":{"58":wall_count,"2":1},"completed_ticks":4,"min_applied_edits":2}
 var malformed: Dictionary = first.duplicate(true)
 if scanline: malformed.args.stamp.rows = [{"repeat":3,"spans":[[1,2],[2,1]]}]
 else: malformed.args.points.append([62,30])
 panel.client.fixture_turns = [inspect,malformed,malformed,refused,inspect,first,{"tool":"apply_edit","args":{"proposal_id":"$last_proposal"}},inspect,erase,{"tool":"apply_edit","args":{"proposal_id":"$last_proposal"}},inspect,{"tool":"step","args":{"ticks":4}},{"final":label+" completed"}]
 wb._set_view(Vector2(24,24),Vector2i(80,32))
 var prior_runner := str(panel.client._finished_receipt.get("runner_id",""))
 panel._on_start()
 if not await until(func() -> bool: return not panel.client._finished_receipt.is_empty() and str(panel.client._finished_receipt.get("runner_id","")) != prior_runner,label+" actual native final"):
  print("WB_RASTER_FAILURE_STATE ",panel._state.text)
  panel._on_stop()
  return false
 if not await until(func() -> bool: return not panel._retire_pending and not mount._authorised and panel.client._runner_pid == 0,label+" Stop ACK and exit"): return false
 var report: Dictionary = panel.client._finished_receipt
 check(report.get("status") == "passed",label+" runner status "+str(report.get("reason")))
 check(report.get("native_acceptance",{}).get("passed") == true and host.latest_snapshot.tick_index == 4,label+" native counts/ticks")
 check(report.get("stop_acknowledged") == true,label+" Stop")
 var originals := 0
 var refuses := 0
 var applies := 0
 var observations: Array = []
 var expected := {}
 if scanline:
  for yy: int in range(30,36):
   for xx: int in range(30,38):
    if yy not in [32,33] or xx in [30,31,36,37]: expected[Vector2i(xx,yy)] = true
 else:
  for point: Array in points: expected[Vector2i(point[0],point[1])] = true
 var folder: String = panel.client._bridge_root.path_join("native")
 if not evidence_dir.is_empty(): DirAccess.make_dir_recursive_absolute(evidence_dir)
 var names: Array = Array(DirAccess.get_files_at(folder))
 names.sort()
 for name: String in names:
  var bytes := FileAccess.get_file_as_bytes(folder.path_join(name))
  if name.ends_with(".png"): originals += 1
  if name.ends_with(".json"):
   var parsed := JSON.new()
   if parsed.parse(bytes.get_string_from_utf8()) == OK and parsed.data is Dictionary:
    var receipt: Dictionary = parsed.data
    if receipt.get("status") == "refused" and receipt.get("reason") == "source_material_protected": refuses += 1
    if receipt.get("status") == "observed": observations.append(receipt)
    if receipt.get("status") == "applied":
     applies += 1
     if applies == 1:
      var actual := {}
      for row: Dictionary in receipt.get("readback",[]):
       check(row.get("actual") == row.get("after"),label+" native write mismatch")
       actual[Vector2i(int(row.x),int(row.y))] = true
      check(actual == expected,label+" exact chosen pixels/scaled scanlines differ")
  if not evidence_dir.is_empty():
   var saved := FileAccess.open(evidence_dir.path_join(label+"-"+name),FileAccess.WRITE)
   saved.store_buffer(bytes)
 check(refuses == 1 and applies == 2,label+" native refusal/recovery missing")
 if check(observations.size() >= 4,label+" original observations"):
  check(observations[0].identity == observations[1].identity and observations[0].native_material_ids == observations[1].native_material_ids,label+" protected refusal mutated native cells")
 check(originals >= 5,label+" original PNGs missing")
 var late: Dictionary = await mount._bridge.call_tool("apply_edit",{"proposal_id":"late-unissued"})
 check(late.get("status") == "refused",label+" late write after Stop")
 if not evidence_dir.is_empty():
  var saved := FileAccess.open(evidence_dir.path_join(label+"-report.json"),FileAccess.WRITE)
  saved.store_string(JSON.stringify(report,"  "))
  panel.client.export_diagnostics(evidence_dir.path_join(label+"-traffic.jsonl"))
 print("WB_RASTER_NATIVE "+JSON.stringify({"mode":label,"genuine_api_calls":0,"refusals":refuses,"original_pngs":originals,"exact_first_write_cells":expected.size(),"final_walls":wall_count,"native_ticks":host.latest_snapshot.tick_index,"stop_acknowledged":report.get("stop_acknowledged")}))
 return true

func _run() -> void:
 evidence_dir = OS.get_environment("WB_AGENT_EVIDENCE_DIR")
 host = load("res://main.tscn").instantiate()
 root.add_child(host)
 wb = host.shared_workbench
 if not await until(Callable(self,"_ready_native"),"raster native startup"):
  _finish()
  return
 mount = wb._agent_mount
 panel = mount.panel()
 mount._toggle.button_pressed = true
 if not await job(false) or not await job(true):
  _finish()
  return
 # Scanline mode shares the human-owned Stop path, exercised during native Step.
 panel.client.acceptance = {}
 panel.client.fixture_turns = [{"tool":"observe","args":{"region":null,"detail":"counts"}},{"tool":"step","args":{"ticks":4}},{"final":"Stop must fence this."}]
 var injected := [false]
 var callback := func(tool: String,_args: Dictionary,_epoch: int,_id: String) -> void:
  if tool == "step" and not injected[0]:
   injected[0] = true
   panel._on_stop()
 panel.client.tool_requested.connect(callback)
 var epoch: int = panel.client.current_epoch()
 panel._on_start()
 if await until(func() -> bool: return injected[0] and panel.client.current_epoch() > epoch and not panel._retire_pending and panel.client._runner_pid == 0,"scanline human Stop"):
  check(panel.client._native_stop_acknowledged(),"scanline human Stop unacknowledged")
  var tick: int = host.latest_snapshot.tick_index
  for i: int in range(5): await process_frame
  check(host.latest_snapshot.tick_index == tick,"scanline ticks after Stop")
 _finish()
