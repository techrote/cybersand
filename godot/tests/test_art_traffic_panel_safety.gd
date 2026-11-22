extends SceneTree
## Mounted Art window remains usable with missing or unreadable old traffic.
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

func write_text(path: String, value: String) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE)
	if f != null:
		f.store_string(value)
		f = null

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	DirAccess.make_dir_recursive_absolute("user://art-traffic")
	DirAccess.make_dir_recursive_absolute("user://art-pending-history")
	var legacy := "user://art-traffic/invalid-old.jsonl"
	write_text(legacy,"invalid old traffic\n")
	var legacy_sha := FileAccess.get_sha256(legacy)
	write_text("user://art-pending-history/orphan.json","legacy data retained\n")
	var orphan_sha := FileAccess.get_sha256("user://art-pending-history/orphan.json")
	var cfg := ConfigFile.new()
	cfg.set_value("session","traffic_path",legacy)
	check(cfg.save("user://art-provider.cfg") == OK,"stale profile configured")
	var host: Control = load("res://main.tscn").instantiate()
	root.add_child(host)
	var panel: Window = host.shared_workbench._ensure_art_batches()
	await process_frame
	panel.show()
	await process_frame
	check(panel.conversation_loaded and panel.conversation.is_empty(),"corrupt old archive does not become model context")
	check(not panel.provider.resume_active and panel.provider.parent_log_path.is_empty(),"no restoration or predecessor binding")
	panel._open_conversation()
	check(panel.conversation_editor.visible,"new in-memory Conversation can open despite old archive")
	panel.conversation_editor.hide()
	check(panel.remember_turn("user","new-session"),"new session writes despite invalid old archive")
	var current: String = str(panel.provider.log_path)
	check(not current.is_empty() and current != legacy,"new session has independent file")
	check(panel.history_block_reason().is_empty(),"past-session failure does not block native Undo/Redo")
	var exported := "user://art-session-export.jsonl"
	check(panel.provider.export_traffic(exported) == OK,"current-session audit exports")
	check(FileAccess.get_file_as_string(exported).contains("new-session") and not FileAccess.get_file_as_string(exported).contains("invalid old traffic"),"export contains only current session data")
	panel.stop_all("Cancelled current operation")
	check(panel.provider.log_path == current,"Stop does not rotate session file")
	panel.save_profile()
	var saved := ConfigFile.new()
	check(saved.load("user://art-provider.cfg") == OK and not saved.has_section_key("session","traffic_path"),"preferences no longer persist traffic pointers")
	check(FileAccess.get_sha256(legacy) == legacy_sha and FileAccess.get_sha256("user://art-pending-history/orphan.json") == orphan_sha,"legacy traffic and journal untouched")
	host.queue_free()
	await process_frame
	await process_frame
	print("ART_TRAFFIC_PANEL ",JSON.stringify({"checks":checks,"failures":failures,"scope":"no-history-restore"}))
	quit(0 if failures.is_empty() else 1)
