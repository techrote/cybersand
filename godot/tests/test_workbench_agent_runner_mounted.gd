extends "res://tests/test_wb525_capacity_and_camera_render.gd"
## Real UI -> Python #552 Runner -> native World and original framebuffer. Fixture only.
func _run() -> void:
 evidence_dir = OS.get_environment("WB_AGENT_EVIDENCE_DIR")
 host = load("res://main.tscn").instantiate()
 root.add_child(host)
 wb = host.shared_workbench
 if not await until(Callable(self,"_ready_native"),"runner native startup"):
  _finish()
  return
 var fresh: Dictionary = Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(2048,2048))
 if not check(wb.apply(fresh),"runner fresh canvas") or not await until(Callable(self,"_ready_blank"),"runner fresh canvas ACK"):
  _finish()
  return
 mount = wb._agent_mount
 panel = mount.panel()
 mount._toggle.button_pressed = true
 panel._provider.select(4)
 panel._provider_selected(4)
 panel._task.text = "Create registered nine cells, erase its center, inspect eight remaining cells, then complete four native ticks."
 panel._set_budgets(14,12,1024,180)
 panel._region[0].value = 0
 panel._region[1].value = 0
 panel._region[2].value = 64
 panel._region[3].value = 64
 panel._guard.button_pressed = true
 panel._guard_region[0].value = 50
 panel._guard_region[1].value = 50
 panel._guard_region[2].value = 1
 panel._guard_region[3].value = 1
 panel.client.acceptance = {"native_counts":{"58":8},"completed_ticks":4,"min_applied_edits":2}
 wb._set_view(Vector2(24,24),Vector2i(32,32))
 check(not panel.client._fake_transport,"runner accidentally uses legacy fake transport")
 check(FileAccess.file_exists(panel.client.runner_script()),"Python desktop bridge missing")
 panel._on_start()
 if not await until(func() -> bool: return not panel.client._finished_receipt.is_empty(),"actual Python Runner final receipt"):
  print("WB_PROVIDER_UI_LAST_STATE ",panel._state.text)
  panel._on_stop()
  _finish()
  return
 if not await until(func() -> bool: return not panel._retire_pending and not mount._authorised and panel.client._runner_pid == 0,"real native Stop and owned child shutdown"):
  _finish()
  return
 var report: Dictionary = panel.client._finished_receipt.duplicate(true)
 check(report.get("provider") == "fixture","qualified genuine provider unexpectedly")
 check(report.get("stop_acknowledged") == true and panel.client._native_stop_acknowledged(),"Python result lacks actual native Stop ACK")
 check(report.get("measured",{}).get("applied_edits") == 2,"Runner did not apply two native edits")
 check(report.get("measured",{}).get("native_ticks") == 4 and host.latest_snapshot.tick_index == 4,"Python/native completed tick mismatch")
 check(report.get("native_acceptance",{}).get("passed") == true,"Runner native/framebuffer acceptance failed")
 check(not panel.client.is_active() and panel.client._runner_pid == 0,"finished child or active task leaked")
 var observed_eight := false
 var observed_nine := false
 var matched := 0
 var native_dir: String = panel.client._bridge_root.path_join("native")
 for name: String in DirAccess.get_files_at(native_dir):
  if not name.ends_with(".json"): continue
  var parsed := JSON.new()
  if parsed.parse(FileAccess.get_file_as_string(native_dir.path_join(name))) != OK or not parsed.data is Dictionary:
   check(false,"retained native JSON unreadable")
   continue
  var receipt: Dictionary = parsed.data
  if receipt.get("status") == "observed":
   observed_nine = observed_nine or receipt.get("native_counts",{}).get("58") == 9
   observed_eight = observed_eight or receipt.get("native_counts",{}).get("58") == 8
   check(receipt.get("image_status") == "matched_post_draw","observation not matched to original framebuffer")
  var png_name := name.get_basename()+".png"
  if FileAccess.file_exists(native_dir.path_join(png_name)):
   var png := FileAccess.get_file_as_bytes(native_dir.path_join(png_name))
   check(png.size() > 8 and png[0] == 137 and png[1] == 80,"retained original PNG signature missing")
   matched += 1
   if not evidence_dir.is_empty():
    DirAccess.make_dir_recursive_absolute(evidence_dir)
    var image_file := FileAccess.open(evidence_dir.path_join("runner-native-"+png_name),FileAccess.WRITE)
    image_file.store_buffer(png)
  if not evidence_dir.is_empty():
   var receipt_file := FileAccess.open(evidence_dir.path_join("runner-native-"+name),FileAccess.WRITE)
   receipt_file.store_string(JSON.stringify(receipt,"  "))
 check(observed_nine and observed_eight,"native readbacks did not establish9 then8 cells")
 check(matched >= 4,"original observed/Step PNGs missing")
 var late: Dictionary = await mount._bridge.call_tool("apply_edit",{"proposal_id":"late-unissued"})
 check(late.get("status") == "refused","Stop allowed late native mutation")
 if not evidence_dir.is_empty():
  var report_file := FileAccess.open(evidence_dir.path_join("runner-report.json"),FileAccess.WRITE)
  report_file.store_string(JSON.stringify(report,"  "))
  panel.client.export_diagnostics(evidence_dir.path_join("runner-traffic.jsonl"))
 # A second real Python child is stopped in its native Step dispatch callback.
 # No pipe/provider wait can delay the panel's independent native retirement.
 panel.client.acceptance = {}
 panel.client.fixture_turns = [
  {"tool":"observe","args":{"region":{"x":28,"y":28,"width":8,"height":8},"detail":"cells"}},
  {"tool":"step","args":{"ticks":4}},
  {"final":"Human Stop should fence this continuation."}]
 var stop_injected := [false]
 var stop_at_step := func(tool: String,_args: Dictionary,_epoch: int,_id: String) -> void:
  if tool == "step" and not stop_injected[0]:
   stop_injected[0] = true
   panel._on_stop()
 panel.client.tool_requested.connect(stop_at_step)
 var prior_epoch: int = panel.client._runner_epoch
 panel._on_start()
 if not await until(func() -> bool: return panel.client._runner_epoch != prior_epoch and not panel._start_pending,"second native authorization and fresh Python child epoch"):
  _finish()
  return
 if not await until(func() -> bool: return not panel.client._finished_receipt.is_empty(),"human Stop while real Python/native Step is pending"):
  _finish()
  return
 if not await until(func() -> bool: return not panel._retire_pending and not mount._authorised and panel.client._runner_pid == 0,"second-run native Stop and child cleanup"):
  _finish()
  return
 panel.client.tool_requested.disconnect(stop_at_step)
 check(stop_injected[0],"did not inject Stop during actual Python/native Step")
 check(panel.client._finished_receipt.get("stop_acknowledged") == true and panel.client._native_stop_acknowledged(),"human Stop not shared back to Python as real native ACK")
 var stopped_tick: int = host.latest_snapshot.tick_index
 await process_frame
 await process_frame
 check(host.latest_snapshot.tick_index == stopped_tick,"native tick advanced after Stop acknowledgement")
 if not evidence_dir.is_empty():
  var stopped_file := FileAccess.open(evidence_dir.path_join("runner-human-stop-report.json"),FileAccess.WRITE)
  stopped_file.store_string(JSON.stringify(panel.client._finished_receipt,"  "))
 print("WB_PROVIDER_UI_MOUNTED "+JSON.stringify({"provider":"fixture","genuine_api_calls":0,"applied_edits":2,"native_ticks":4,"original_pngs":matched,"stop_acknowledged":report.get("stop_acknowledged"),"owned_child_closed":panel.client._runner_pid == 0,"human_stop_during_step":stop_injected[0]}))
 _finish()
