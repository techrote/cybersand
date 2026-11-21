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
	var old_archive_path: String = saved_path()
	var old_archive_hash: String = FileAccess.get_sha256(old_archive_path)
	reopened.shared_workbench.paint_editor.history_action_finished.emit({"action":"undo","status":"completed","label":"confirmed while hidden","applied":1})
	check(reopened.shared_workbench.art_batches == null
		and DirAccess.get_files_at("user://art-pending-history").size() == 1,
		"unopened Art journals native Undo without constructing the window or reading its transcript")
	var reopened_panel: Window = reopened.shared_workbench._ensure_art_batches()
	check(not reopened_panel.visible and not reopened_panel.conversation_loaded
		and reopened_panel.provider.log_path.is_empty() and not reopened_panel.provider.resume_active,
		"explicitly created hidden Art panel still defers old conversation restore")
	check(reopened_panel.history_block_reason().is_empty(),
		"hidden deferred Art receipt does not block the immediately following Redo")
	reopened_panel.show()
	reopened.shared_workbench.paint_editor.history_action_finished.emit({"action":"redo","status":"completed","label":"confirmed during restore","applied":1})
	check(reopened_panel.provider.resume_active and reopened_panel.pending_history_receipts.size() == 1
		and DirAccess.get_files_at("user://art-pending-history").size() == 2,
		"visible restore buffers concurrent Redo alongside earlier unopened-panel Undo")
	deadline = Time.get_ticks_msec()+60000
	while reopened_panel.provider.resume_active and Time.get_ticks_msec()<deadline: await process_frame
	check(reopened_panel.conversation_loaded and reopened_panel.pending_history_receipts.is_empty()
		and reopened_panel.conversation.size() == 2,
		"explicit restore drains both independently confirmed history receipts exactly once")
	if reopened_panel.conversation.size() == 2:
		check(reopened_panel.conversation[0].content.contains("confirmed while hidden")
			and reopened_panel.conversation[1].content.contains("confirmed during restore"),
			"deferred native Undo and Redo retain their original chronological order")
	check(FileAccess.get_sha256(old_archive_path) == old_archive_hash
		and reopened_panel.provider.log_path != old_archive_path,
		"deferred history continuation never overwrites or copies the original traffic archive")
	check(DirAccess.get_files_at("user://art-pending-history").is_empty(),
		"successful history restoration clears the durable receipt journal")
	reopened.queue_free()
	await process_frame
	await process_frame

	# More than 64 confirmed native receipts must survive a hidden shutdown.
	var batch_host: Node = load("res://main.tscn").instantiate()
	root.add_child(batch_host)
	check(batch_host.shared_workbench.art_batches == null,
		"new Workbench has no Art panel before its 75 native history events")
	var batch_parent := saved_path()
	var batch_parent_hash := FileAccess.get_sha256(batch_parent)
	for index in range(75):
		batch_host.shared_workbench.paint_editor.history_action_finished.emit(
			{"action":"undo","status":"completed","label":"durable-%03d" % index,"applied":1})
	var pending_files := DirAccess.get_files_at("user://art-pending-history")
	check(batch_host.shared_workbench.art_batches == null and pending_files.size() == 75,
		"75 hidden native receipts are durably journalled without opening the Art transcript")
	var recovered_receipt_path := "user://art-pending-history/".path_join(pending_files[0]) if not pending_files.is_empty() else ""
	var recovered_receipt_bytes := FileAccess.get_file_as_string(recovered_receipt_path) if not recovered_receipt_path.is_empty() else ""
	check(FileAccess.get_sha256(batch_parent) == batch_parent_hash,
		"large hidden receipt batches do not mutate the historical Art archive")
	batch_host.queue_free()
	await process_frame
	await process_frame
	var restored_host: Node = load("res://main.tscn").instantiate()
	root.add_child(restored_host)
	check(restored_host.shared_workbench.art_batches == null,
		"restarted Workbench keeps Art lazy until explicitly opened")
	var restored_panel: Window = restored_host.shared_workbench._ensure_art_batches()
	check(not restored_panel.visible and not restored_panel.conversation_loaded
		and restored_panel.pending_history_receipts.is_empty()
		and DirAccess.get_files_at("user://art-pending-history").size() == 75,
		"fresh Workbench process discovers 75 durable receipts without loading the conversation")
	restored_panel.show()
	deadline = Time.get_ticks_msec()+60000
	while restored_panel.provider.resume_active and Time.get_ticks_msec()<deadline: await process_frame
	var original_count := 2
	check(restored_panel.conversation_loaded and restored_panel.conversation.size() == original_count+75
		and DirAccess.get_files_at("user://art-pending-history").is_empty(),
		"restart restores all 75 receipts exactly once and removes committed journal files")
	var ordered: bool = restored_panel.conversation.size() == original_count+75
	if ordered:
		for index in range(75):
			if not str(restored_panel.conversation[original_count+index].content).contains("durable-%03d" % index):
				ordered = false
				break
	check(ordered,"durable receipts retain original Undo chronology across shutdown and restart")
	check(FileAccess.get_sha256(batch_parent) == batch_parent_hash,
		"recovered receipts preserve the immutable prior archive bytes")
	restored_host.queue_free()
	await process_frame
	await process_frame

	# Model a crash after archive commit but before sidecar unlink: the ID in
	# the committed conversation must prevent a duplicate replay.
	if not recovered_receipt_path.is_empty(): write_text(recovered_receipt_path,recovered_receipt_bytes)
	var dedupe_host: Node = load("res://main.tscn").instantiate()
	root.add_child(dedupe_host)
	check(dedupe_host.shared_workbench.art_batches == null,
		"interrupted-cleanup test starts without constructing Art")
	var dedupe_panel: Window = dedupe_host.shared_workbench._ensure_art_batches()
	dedupe_panel.show()
	deadline = Time.get_ticks_msec()+60000
	while dedupe_panel.provider.resume_active and Time.get_ticks_msec()<deadline: await process_frame
	check(dedupe_panel.conversation_loaded and dedupe_panel.conversation.size() == original_count+75
		and DirAccess.get_files_at("user://art-pending-history").is_empty(),
		"archive-committed journal receipt is deduplicated after simulated interrupted cleanup")
	dedupe_host.queue_free()
	await process_frame
	await process_frame
	print("ART_TRAFFIC_PANEL ",JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}))
	quit(0 if failures.is_empty() else 1)
