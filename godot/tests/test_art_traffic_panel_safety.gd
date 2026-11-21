extends SceneTree
## Actual Workbench controls under a broken, then repaired, saved conversation.
## The qualification runner supplies a fresh XDG_DATA_HOME/APPDATA for this test.
const Provider = preload("res://scripts/art_provider.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_TRAFFIC_PANEL_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)

func saved_path() -> String:
	var config := ConfigFile.new()
	if config.load("user://art-provider.cfg") != OK: return ""
	return str(config.get_value("session","traffic_path",""))

func write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		check(false,"fixture writable: "+path)
		return
	file.store_string(value)
	file.close()

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	DirAccess.make_dir_recursive_absolute("user://art-traffic")
	var original := "user://art-traffic/panel-recoverable-legacy.jsonl"
	var config := ConfigFile.new()
	config.set_value("session","traffic_path",original)
	check(config.save("user://art-provider.cfg") == OK,"configure absent legacy source")
	var host: Node = load("res://main.tscn").instantiate()
	root.add_child(host)
	check(host.shared_workbench.art_batches == null,"startup keeps Art unconstructed")
	# The safety controls below intentionally exercise a separately created,
	# still-hidden panel; this must not force saved-history restoration.
	var panel: Window = host.shared_workbench._ensure_art_batches()
	for _frame in range(3): await process_frame
	check(not panel.visible and not panel.conversation_loaded,"hidden startup leaves missing saved history unexamined")
	panel.change_provider(1)
	panel.model.text = "isolated-test-model"
	panel.save_profile()
	check(not panel.conversation_loaded and panel.provider.log_path.is_empty(),"hidden provider/model selection performs no replay or traffic write")
	check(saved_path() == original,"profile changes retain unavailable conversation pointer")
	panel.show()
	await process_frame
	check(not panel.conversation_loaded and not panel.provider.resume_ok,"missing segment refuses restoration")
	check(not panel.input_error.is_empty() and panel.conversation.is_empty(),"restore refusal is visible without inventing conversation")
	panel._open_conversation()
	check(not panel.conversation_editor.visible,"Edit and Clear cannot act on failed restoration")
	panel.send_prompt()
	panel.remember_turn("user","must not replace saved conversation")
	check(not panel.provider.active and panel.provider.log_path.is_empty(),"failed restore blocks send and continuation")
	check(saved_path() == original and DirAccess.get_files_at("user://art-traffic").is_empty(),"failed operations preserve saved pointer and create no archive")
	write_text(original,JSON.stringify({"kind":"conversation","data":{"role":"user","content":"Recoverable old message"}})+"\n")
	var original_hash := FileAccess.get_sha256(original)
	panel._ensure_history_loaded()
	var restore_deadline := Time.get_ticks_msec()+60000
	while panel.provider.resume_active and Time.get_ticks_msec()<restore_deadline: await process_frame
	check(panel.conversation_loaded,"restoring absent file allows retry in the same panel")
	check(panel.conversation_loaded and panel.conversation.size() == 1 and panel.conversation[0].content == "Recoverable old message","retry recovers previous conversation exactly")
	var settle_deadline := Time.get_ticks_msec()+60000
	while (host.shared_workbench.busy() or host.shared_workbench.paint_editor.busy()) and Time.get_ticks_msec()<settle_deadline:
		await process_frame
	check(not host.shared_workbench.busy(),"native Workbench settles before checkpoint failure probe")
	# Real filesystem refusal, portable across Linux and Windows: the existing
	# profile is retained under a sibling while a directory occupies its target.
	var saved_config := "user://panel-config-before-failure.cfg"
	var config_hash := FileAccess.get_sha256("user://art-provider.cfg")
	check(DirAccess.rename_absolute("user://art-provider.cfg",saved_config) == OK and DirAccess.make_dir_absolute("user://art-provider.cfg") == OK,"stage controlled profile-publication refusal")
	panel._open_conversation()
	panel.conversation_editor.content.text = "Rejected checkpoint edit"
	panel._apply_conversation_edits()
	check(panel.conversation_editor.visible and panel.conversation[0].content == "Recoverable old message","failed profile publication cannot report successful edit")
	check(not panel.provider.last_event_stored and panel.provider.log_path.is_empty() and panel.provider.parent_log_path == original,"failed checkpoint cannot adopt an unreferenced segment")
	check(FileAccess.get_sha256(saved_config) == config_hash,"failed checkpoint leaves previous profile bytes intact")
	check(DirAccess.remove_absolute("user://art-provider.cfg") == OK and Provider.Archive.atomic_replace(saved_config,"user://art-provider.cfg").get("ok",false),"restore controlled profile after refusal")
	check(saved_path() == original,"failed checkpoint retains previous saved conversation")
	panel.conversation_editor.hide()
	panel.remember_turn("assistant","Fresh reply")
	var child: String = panel.provider.log_path
	check(not child.is_empty() and child != original and saved_path() == child,"committed first event publishes new linked pointer")
	var check_replay := Provider.new()
	var check_turns: Array = check_replay.resume_traffic(child)
	check(check_replay.resume_ok and check_turns.size() == 2 and check_turns[0].content == "Recoverable old message","later successful continuation never adopts cancelled failed-checkpoint edit")
	check_replay.free()
	check(FileAccess.get_sha256(original) == original_hash,"continuation leaves historical bytes unchanged")
	var destination := "user://panel-export.jsonl"
	write_text(destination,"previous completed export\n")
	panel.log_draw = true
	panel._begin_traffic_export(destination)
	check(not panel.provider.export_active and FileAccess.get_file_as_string(destination) == "previous completed export\n","pending native-result receipt blocks export before it can omit that result")
	panel.log_draw = false
	panel._begin_traffic_export(destination)
	check(panel.provider.export_active,"UI export is incremental and interruptible")
	panel.stop_all()
	check(not panel.provider.export_active and panel.export_message.contains("cancelled"),"ordinary Stop cancels active export")
	check(FileAccess.get_file_as_string(destination) == "previous completed export\n","cancelled export preserves previous destination")
	panel._begin_traffic_export(destination)
	panel._cancel_traffic_export()
	check(not panel.provider.export_active and FileAccess.get_file_as_string(destination) == "previous completed export\n","dedicated Cancel export preserves destination")
	panel._begin_traffic_export(destination)
	var deadline := Time.get_ticks_msec()+30000
	while panel.provider.export_active and Time.get_ticks_msec()<deadline: await process_frame
	check(not panel.provider.export_active and panel.export_message.contains("completed"),"UI export finishes through ordinary process polling")
	check(FileAccess.get_file_as_string(destination).contains("Fresh reply"),"completed export includes continued conversation")
	var before_failure := saved_path()
	panel.provider.log_path = "user://absent-panel-safety-directory/no/log.jsonl"
	panel.remember_turn("assistant","live only after disk refusal")
	check(not panel.provider.last_event_stored and saved_path() == before_failure,"failed traffic append cannot replace committed session pointer")
	panel.provider.log_path = child
	panel.provider.log_warning = ""
	deadline = Time.get_ticks_msec()+60000
	while (host.shared_workbench.busy() or host.shared_workbench.paint_editor.busy()) and Time.get_ticks_msec()<deadline:
		await process_frame
	check(not host.shared_workbench.busy() and not host.shared_workbench.paint_editor.busy(),"native Workbench settles before explicit conversation editing")
	panel._open_conversation()
	check(panel.conversation_editor.visible,"Edit remains usable after failure recovery")
	panel.conversation_editor.draft.clear()
	panel._apply_conversation_edits()
	check(panel.conversation.is_empty(),"explicit Clear draft and Apply still works")
	var replay := Provider.new()
	check(replay.resume_traffic(child).is_empty() and replay.resume_ok,"explicitly cleared conversation remains clear on replay")
	replay.free()
	check(FileAccess.get_sha256(original) == original_hash,"all controls preserve original legacy archive")
	var partials: Array[String] = []
	for name: String in DirAccess.get_files_at("user://"):
		if name.ends_with(".partial"): partials.append(name)
	check(partials.is_empty(),"completed or cancelled settings/export operations leave no partial files")
	host.queue_free()
	await process_frame
	await process_frame
	var reopened: Node = load("res://main.tscn").instantiate()
	root.add_child(reopened)
	check(reopened.shared_workbench.art_batches == null,"reopened Workbench has no eager Art panel")
	var reopened_panel: Window = reopened.shared_workbench._ensure_art_batches()
	reopened_panel.show()
	reopened.shared_workbench.paint_editor.history_action_finished.emit({"action":"undo","status":"completed","label":"confirmed during restore","applied":1})
	check(reopened_panel.provider.resume_active and reopened_panel.pending_history_receipts.size() == 1,"confirmed editor receipt arriving during restore is retained")
	deadline = Time.get_ticks_msec()+60000
	while reopened_panel.provider.resume_active and Time.get_ticks_msec()<deadline: await process_frame
	check(reopened_panel.conversation_loaded and reopened_panel.pending_history_receipts.is_empty() and reopened_panel.conversation.size() == 1,"successful restore drains confirmed receipt exactly once")
	check(reopened_panel.conversation[0].content.contains("confirmed during restore"),"restored model context includes confirmed editor result")
	reopened.queue_free()
	await process_frame
	await process_frame
	print("ART_TRAFFIC_PANEL ",JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}))
	quit(0 if failures.is_empty() else 1)
