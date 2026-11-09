extends SceneTree
## Real wording editor and file transport, no Python/provider calls.
const AgentPanel = preload("res://scripts/workbench_agent_panel.gd")
const RunnerClient = preload("res://scripts/workbench_agent_runner_client.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("WB_AGENT_BOILERPLATE: " + detail)
func _init() -> void:
 call_deferred("_run")
func _run() -> void:
 var panel := AgentPanel.new()
 root.add_child(panel)
 await process_frame
 panel.client.configure_fake_transport_for_tests(true)
 check(panel._boilerplate_load_problem.is_empty() and panel._boilerplate_sections.size() == 12,"manifest not loaded into all12 sections")
 check(panel._boilerplate_section.item_count == 12 and not panel._boilerplate_window.visible,"editor opens uninvited or hides sections")
 check(panel._task.custom_minimum_size.y >= 190,"wording controls crush main prompt")
 panel.client._active = true
 var epoch: int = panel.client.current_epoch()
 panel._boilerplate_section.select(1)
 panel._select_boilerplate_section(1)
 await process_frame
 check(panel.client.is_active() and panel.client.current_epoch() == epoch,"viewing sections interrupts active work")
 panel._boilerplate_editor.text = "Edited task introduction"
 panel._flush_boilerplate_editor()
 check(panel.client.is_active() and panel.client.current_epoch() == epoch and panel._boilerplate_sections.task_prefix == "Edited task introduction","staged edit interrupts or changes active run")
 panel.client.stop_task("test cleanup")
 for i: int in range(panel._boilerplate_section.item_count):
  panel._boilerplate_section.select(i)
  panel._select_boilerplate_section(i)
  panel._boilerplate_editor.text = "Edited " + str(panel._boilerplate_section.get_item_metadata(i))
  panel._flush_boilerplate_editor()
  check(panel._boilerplate_sections[str(panel._boilerplate_section.get_item_metadata(i))] == panel._boilerplate_editor.text,"ornamental wording section")
 panel._restore_boilerplate_section()
 check(panel._boilerplate_sections.tool_prepare_pixels == panel._boilerplate_defaults.tool_prepare_pixels,"selected default restoration fails")
 var client := RunnerClient.new()
 root.add_child(client)
 client.configure_fake_transport_for_tests(true)
 var full := {}
 for key: String in RunnerClient.BOILERPLATE_KEYS: full[key] = ""
 full.system = '"'.repeat(8192)
 full.workflow = '"'.repeat(8192)
 full.summary_policy = '"'.repeat(8192)
 check(client._boilerplate_problem(full).is_empty(),"valid24KiB wording rejected")
 check(JSON.stringify(full).to_utf8_buffer().size() > 32768,"fixture does not exceed control cap")
 var invalid: Dictionary = full.duplicate(true)
 invalid.system = "é".repeat(4097)
 check(not client._boilerplate_problem(invalid).is_empty(),"section cap counts chars instead of bytes")
 invalid = full.duplicate(true)
 invalid.permissions = "extra"
 check(not client._boilerplate_problem(invalid).is_empty(),"whole-map cap ignored")
 check(not client._boilerplate_problem({"model_reply":"not owned"}).is_empty(),"unowned output section admitted")
 var folder := "user://wb-wording-test-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
 check(not DirAccess.dir_exists_absolute(folder) and DirAccess.make_dir_recursive_absolute(folder.path_join("native")) == OK,"directory collision")
 client._bridge_root = ProjectSettings.globalize_path(folder)
 client._active_boilerplate = full.duplicate(true)
 var fields: Dictionary = client._boilerplate_file_fields()
 check(fields.get("boilerplate_file") == "config/boilerplate.json" and JSON.stringify(fields).to_utf8_buffer().size() < 512,"large wording sent inline")
 var path := client._bridge_root.path_join("config/boilerplate.json")
 var bytes := FileAccess.get_file_as_bytes(path)
 check(client._hash(bytes) == fields.get("boilerplate_sha256"),"file/hash disagree")
 full.system = "later edit"
 check(client._active_boilerplate.system != full.system and FileAccess.get_file_as_bytes(path) == bytes,"later edit changes frozen transport")
 var op := {"shape":"disc","x":1,"y":1,"radius":0,"material":58,"replace_only_material":2}
 var args := {"observation_id":"native-observation","operations":[op]}
 check(client._valid_arguments("prepare_edit",args),"native Sand predicate rejected by transport")
 for bad: Variant in [2.5,-1,255,"2"]:
  args.operations[0].replace_only_material = bad
  check(not client._valid_arguments("prepare_edit",args),"non-native or fractional predicate admitted")
 args.operations[0].replace_only_material = 2
 args.operations[0].material = 2
 check(not client._valid_arguments("prepare_edit",args),"predicate expands output allowlist")
 client.queue_free()
 panel.queue_free()
 await process_frame
 await process_frame
 DirAccess.remove_absolute(path)
 DirAccess.remove_absolute(folder.path_join("config"))
 DirAccess.remove_absolute(folder.path_join("native"))
 DirAccess.remove_absolute(folder)
 print("WB_AGENT_BOILERPLATE: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
