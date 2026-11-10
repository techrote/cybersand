extends SceneTree
const AgentPanel = preload("res://scripts/workbench_agent_panel.gd")
const Geometry = preload("res://scripts/workbench_agent_footprint.gd")
var checks := 0
var failures := 0
func check(ok: bool, why: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("WB_RASTER_MODES: "+why)
func _init() -> void: call_deferred("run")
func run() -> void:
 var scope := Rect2i(0,0,64,64)
 var points: Array = []
 for i: int in range(32): points.append([i,0])
 var op := {"shape":"pixels","material":58,"points":points}
 var r: Dictionary = Geometry.compile([op],Vector2i(64,64),scope,[],[0,58],[0,58,2],64)
 check(r.status == "validated_geometry" and r.distinct_cells == 32,"32 point raster")
 points.append([32,0])
 check(Geometry.compile([op],Vector2i(64,64),scope,[],[0,58],[0,58,2],64).status == "refused","33 point admission")
 var stamp := {"shape":"scanlines","x":4,"y":4,"width":4,"height":3,"scale":2,"material":58,"rows":[{"repeat":1,"spans":[[0,4]]},{"repeat":1,"spans":[[0,1],[3,1]]},{"repeat":1,"spans":[[0,4]]}]}
 r = Geometry.compile([stamp],Vector2i(64,64),scope,[],[0,58],[0,58,2],48)
 check(r.status == "validated_geometry" and r.distinct_cells == 40 and not r.footprint.has(Vector2i(6,6)),"scaled exact mask with holes")
 check(Geometry.compile([stamp],Vector2i(64,64),scope,[],[0,58],[0,58,2],47).status == "refused","bounding mask budget")
 check(Geometry.compile([stamp],Vector2i(64,64),scope,[Rect2i(4,4,1,1)],[0,58],[0,58,2],48).reason == "protected_region","native protected rectangle")
 var bad: Dictionary = stamp.duplicate(true)
 bad.rows = [{"repeat":3,"spans":[[1,2],[2,1]]}]
 check(Geometry.compile([bad],Vector2i(64,64),scope,[],[0,58],[0,58,2],48).status == "refused","overlapping spans")
 bad = stamp.duplicate(true)
 bad.x = 9223372036854775807
 check(Geometry.compile([bad],Vector2i(64,64),scope,[],[0,58],[0,58,2],48).status == "refused","int64 coordinate overflow")
 var command := {"schema_version":1,"action":"prepare_edit","observation_id":"o","operations":[stamp]}
 check(preload("res://scripts/workbench_authoring_envelope.gd").valid(command),"bounded scanline worker envelope")
 command.operations = [{"shape":"pixels","material":58,"points":[[1,1]]}]
 check(preload("res://scripts/workbench_authoring_envelope.gd").valid(command),"bounded pixel worker envelope")
 command.operations[0].points = [[1.5,1]]
 check(not preload("res://scripts/workbench_authoring_envelope.gd").valid(command),"fractional worker envelope")
 var panel := AgentPanel.new()
 root.add_child(panel)
 await process_frame
 panel._task.text = "Tools task"
 panel._boilerplate_editor.text = "Tool-only wording"
 panel._flush_boilerplate_editor()
 panel._select_authoring_mode(1)
 check(panel._mode_name == "scanline" and panel._task.text.is_empty() and panel._mode_guide.visible,"separate scanline task/interface")
 check(panel._boilerplate_sections.has("packet_stamp") and not panel._boilerplate_sections.has("tool_prepare_edit"),"separate scanline wording")
 panel._task.text = "Print task"
 panel._boilerplate_editor.text = "Print-only wording"
 panel._flush_boilerplate_editor()
 panel._select_authoring_mode(0)
 check(panel._task.text == "Tools task" and panel._boilerplate_sections.system == "Tool-only wording","tools mode state overwritten")
 panel._select_authoring_mode(1)
 check(panel._task.text == "Print task" and panel._boilerplate_sections.system == "Print-only wording","print mode state overwritten")
 var previous_nv := OS.get_environment("CYBERSAND_WB_NVIDIA_PROFILE")
 var previous_openai := OS.get_environment("CYBERSAND_WB_OPENAI_PROFILE")
 var config_path := "user://nvidia-preset-selection-test.json"
 var config_file := FileAccess.open(config_path,FileAccess.WRITE)
 config_file.store_string(JSON.stringify({"provider":"nvidia_chat","model":"nvidia/nemotron-3.5-super-vl-120b-a12b","credentials":{"env":"NVIDIA_API_KEY"}}))
 config_file.close()
 OS.set_environment("CYBERSAND_WB_NVIDIA_PROFILE",ProjectSettings.globalize_path(config_path))
 OS.set_environment("CYBERSAND_WB_OPENAI_PROFILE",ProjectSettings.globalize_path("res://../tools/workbench_api_agent/profiles/openai-responses.example.json"))
 panel._provider.select(2)
 panel._provider_selected(2)
 check(panel._profile_data.provider == "nvidia_chat" and panel._model.text == "nvidia/nemotron-3.5-super-vl-120b-a12b","NVIDIA dropdown leaves old profile/model")
 panel._provider.select(1)
 panel._provider_selected(1)
 check(panel._profile_data.provider == "openai_responses","OpenAI preset cannot be restored")
 OS.set_environment("CYBERSAND_WB_NVIDIA_PROFILE",previous_nv)
 OS.set_environment("CYBERSAND_WB_OPENAI_PROFILE",previous_openai)
 DirAccess.remove_absolute(config_path)
 panel._log_status("error","provider_model_changed")
 panel._refresh_dashboard()
 check(panel._state.text.contains("unexpected model name") and not panel._state.clip_text and panel._state.max_lines_visible == 3,"error is clipped or opaque")
 panel.queue_free()
 await process_frame
 await process_frame
 print("WB_RASTER_MODES: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
