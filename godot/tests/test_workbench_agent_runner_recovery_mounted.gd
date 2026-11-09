extends "res://tests/test_wb525_capacity_and_camera_render.gd"
## True native protected-source refusal -> same Python Runner correction -> Step/Stop.
func _run() -> void:
 evidence_dir = OS.get_environment("WB_AGENT_EVIDENCE_DIR")
 host = load("res://main.tscn").instantiate()
 root.add_child(host)
 wb = host.shared_workbench
 if not await until(Callable(self,"_ready_native"),"recovery native startup"):
  _finish()
  return
 var fresh: Dictionary = Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(2048,2048))
 fresh.edits.append([28,28,1,1,2]) # One human-authored Sand cell in the starting recipe.
 if not check(wb.apply(fresh),"human Sand recipe refused") or not await until(Callable(self,"_ready_blank"),"human Sand recipe native ACK"):
  _finish()
  return
 mount = wb._agent_mount
 panel = mount.panel()
 mount._toggle.button_pressed = true
 panel._provider.select(4)
 panel._provider_selected(4)
 panel._task.text = "Preserve human Sand, recover the registered refused predicate, build nine safe walls, erase one, finish four ticks."
 panel._set_budgets(14,12,1024,180)
 panel._rate_limit.value = 500000 # Fixture-only finite grant; pacing has separate controls.
 panel._region[0].value = 0
 panel._region[1].value = 0
 panel._region[2].value = 64
 panel._region[3].value = 64
 panel._boilerplate_section.select(0)
 panel._select_boilerplate_section(0)
 panel._boilerplate_editor.text = "Edited system wording: preserve native protections and report receipts accurately."
 panel._flush_boilerplate_editor()
 panel.client.acceptance = {"native_counts":{"58":8,"2":1},"completed_ticks":4,"min_applied_edits":2}
 var area := {"x":28,"y":28,"width":8,"height":8}
 panel.client.fixture_turns = [
  {"tool":"observe","args":{"region":area,"detail":"cells"}},
  {"tool":"prepare_edit","args":{"observation_id":"$last_obs","operations":[{"shape":"disc","x":28,"y":28,"radius":0,"material":58,"replace_only_material":2}]}},
  {"tool":"observe","args":{"region":area,"detail":"cells"}},
  {"tool":"prepare_edit","args":{"observation_id":"$last_obs","operations":[{"shape":"rectangle","x0":30,"y0":30,"x1":32,"y1":32,"material":58,"replace_only_material":0}]}},
  {"tool":"apply_edit","args":{"proposal_id":"$last_proposal"}},
  {"tool":"observe","args":{"region":area,"detail":"cells"}},
  {"tool":"prepare_edit","require_native_counts":{"58":9},"args":{"observation_id":"$last_obs","operations":[{"shape":"rectangle","x0":31,"y0":31,"x1":31,"y1":31,"material":0,"replace_only_material":58}]}},
  {"tool":"apply_edit","args":{"proposal_id":"$last_proposal"}},
  {"tool":"observe","args":{"region":area,"detail":"cells"}},
  {"tool":"step","args":{"ticks":4}},
  {"final":"Protected-source refusal recovered without modifying Sand."}]
 wb._set_view(Vector2(24,24),Vector2i(32,32))
 panel._on_start()
 if not await until(func() -> bool: return not panel.client._finished_receipt.is_empty(),"actual protected-source refusal recovery final"):
  print("WB_REFUSAL_LAST_STATE ",panel._state.text)
  panel._on_stop()
  _finish()
  return
 if not await until(func() -> bool: return not panel._retire_pending and not mount._authorised and panel.client._runner_pid == 0,"recovery native Stop and child exit"):
  _finish()
  return
 var report: Dictionary = panel.client._finished_receipt
 check(report.get("status") == "passed","refusal recovery did not reach passed final: "+str(report.get("reason")))
 check(report.get("model_final_unverified_report") == "Protected-source refusal recovered without modifying Sand.","registered correction final not reached")
 check(report.get("measured",{}).get("applied_edits") == 2 and host.latest_snapshot.tick_index == 4,"recovery edits/ticks incorrect")
 check(report.get("native_acceptance",{}).get("passed") == true and report.get("stop_acknowledged") == true,"recovery native proof/Stop missing")
 var files: Array = Array(DirAccess.get_files_at(panel.client._bridge_root.path_join("native")))
 files.sort()
 var observations: Array = []
 var refusals := 0
 var images := 0
 if not evidence_dir.is_empty(): DirAccess.make_dir_recursive_absolute(evidence_dir)
 for name: String in files:
  var source: String = panel.client._bridge_root.path_join("native").path_join(name)
  var bytes := FileAccess.get_file_as_bytes(source)
  if name.ends_with(".json"):
   var parsed := JSON.new()
   if parsed.parse(bytes.get_string_from_utf8()) == OK and parsed.data is Dictionary:
    var receipt: Dictionary = parsed.data
    if receipt.get("status") == "observed": observations.append(receipt)
    if receipt.get("status") == "refused" and receipt.get("reason") == "source_material_protected":
     refusals += 1
     check(receipt.get("issued_writes",0) == 0 and receipt.get("confirmed_writes",0) == 0,"protected refusal issued native writes")
  elif name.ends_with(".png"): images += 1
  if not evidence_dir.is_empty():
   var target := FileAccess.open(evidence_dir.path_join("recovery-"+name),FileAccess.WRITE)
   target.store_buffer(bytes)
 check(refusals == 1 and observations.size() >= 4,"actual native refusal or refresh observations missing")
 if observations.size() >= 2:
  check(observations[0].get("native_counts",{}).get("2") == 1 and observations[1].get("native_counts",{}).get("2") == 1,"human Sand changed during refusal")
  check(observations[0].get("identity",{}).get("world_revision") == observations[1].get("identity",{}).get("world_revision"),"refused prepare changed actual native revision")
 check(images >= 5,"original matched PNG evidence lost")
 var wording := JSON.new()
 check(wording.parse(FileAccess.get_file_as_string(panel.client._bridge_root.path_join("config/boilerplate.json"))) == OK and wording.data.system.begins_with("Edited system wording:"),"edited wording did not reach actual child configuration")
 if not evidence_dir.is_empty():
  var final := FileAccess.open(evidence_dir.path_join("recovery-report.json"),FileAccess.WRITE)
  final.store_string(JSON.stringify(report,"  "))
  panel.client.export_diagnostics(evidence_dir.path_join("recovery-traffic.jsonl"))
 print("WB_PROVIDER_REFUSAL_RECOVERY "+JSON.stringify({"genuine_api_calls":0,"actual_protected_refusals":refusals,"human_sand_preserved":true,"safe_wall_cells":8,"native_ticks":4,"matched_original_pngs":images,"stop_acknowledged":report.get("stop_acknowledged")}))
 _finish()
