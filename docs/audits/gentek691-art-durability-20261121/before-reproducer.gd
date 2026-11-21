extends SceneTree
const ArtPanel = preload("res://scripts/art_batch_panel.gd")
const Provider = preload("res://scripts/art_provider.gd")
var checks := 0
var failures: Array[String] = []
var panel: Window
var sabotage_done := false
var child := ""
var backup := ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_DURABILITY_BEFORE_CHECK ", label, " ", ok)
	if not ok: failures.append(label)

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func pending() -> int:
	return DirAccess.get_files_at(ArtPanel.HISTORY_RECEIPT_DIR).size() if DirAccess.dir_exists_absolute(ArtPanel.HISTORY_RECEIPT_DIR) else 0

func sabotage_conversation() -> void:
	if sabotage_done or not panel.provider.last_event_stored: return
	if not panel.provider.traffic.contains('"label":"between-raw-and-turn"'): return
	sabotage_done = true
	check(DirAccess.rename_absolute(child,backup) == OK and DirAccess.make_dir_absolute(child) == OK,
		"filesystem obstruction placed after committed raw event")

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	DirAccess.make_dir_recursive_absolute("user://art-traffic")
	var original := "user://art-traffic/durability-original.jsonl"
	write_text(original,JSON.stringify({"kind":"conversation","data":{"role":"user","content":"Original immutable turn"}})+"\n")
	var original_hash := FileAccess.get_sha256(original)
	var cfg := ConfigFile.new()
	cfg.set_value("session","traffic_path",original)
	check(cfg.save("user://art-provider.cfg") == OK,"saved profile fixture")
	var host: Node = load("res://main.tscn").instantiate()
	root.add_child(host)
	check(host.shared_workbench.art_batches == null,"native-backed Workbench keeps Art lazy")
	check(DirAccess.rename_absolute("user://art-provider.cfg","user://profile-backup.cfg") == OK and DirAccess.make_dir_absolute("user://art-provider.cfg") == OK,"unreadable profile real filesystem fixture")
	var before: String = host.shared_workbench.message
	host.shared_workbench.paint_editor.history_action_finished.emit({"action":"undo","status":"completed","label":"unreadable-profile","applied":1})
	var retained: bool = pending() > 0
	var explicit_failure: bool = host.shared_workbench.message != before and host.shared_workbench.message.contains("receipt")
	print("BEFORE_FINDING_A ",JSON.stringify({"pending":pending(),"message":host.shared_workbench.message,"original_message":before,"retained":retained,"explicit_failure":explicit_failure}))
	check(retained or explicit_failure,"A confirmed native receipt is retained or explicit failure is surfaced")
	DirAccess.remove_absolute("user://art-provider.cfg")
	DirAccess.rename_absolute("user://profile-backup.cfg","user://art-provider.cfg")
	panel = host.shared_workbench._ensure_art_batches()
	panel.show()
	var deadline := Time.get_ticks_msec()+60000
	while panel.provider.resume_active and Time.get_ticks_msec()<deadline: await process_frame
	check(panel.conversation_loaded,"load valid session for loaded-Art fault")
	check(panel.remember_turn("assistant","Create writable continuation"),"create writable continuation")
	child = panel.provider.log_path
	backup = child+".saved-for-fault"
	var old_count: int = panel.conversation.size()
	check(DirAccess.rename_absolute(child,backup) == OK and DirAccess.make_dir_absolute(child) == OK,"raw append blocked by actual directory")
	host.shared_workbench.paint_editor.history_action_finished.emit({"action":"undo","status":"completed","label":"raw-append-refused","applied":1})
	print("BEFORE_FINDING_B_RAW ",JSON.stringify({"pending":pending(),"turns":panel.conversation.size(),"error":panel.input_error}))
	check(pending()>0,"B raw append failure retains durable receipt")
	DirAccess.remove_absolute(child)
	DirAccess.rename_absolute(backup,child)
	panel.provider.log_warning = ""
	panel.provider.traffic_changed.connect(sabotage_conversation)
	host.shared_workbench.paint_editor.history_action_finished.emit({"action":"redo","status":"completed","label":"between-raw-and-turn","applied":1})
	panel.provider.traffic_changed.disconnect(sabotage_conversation)
	print("BEFORE_FINDING_B_TURN ",JSON.stringify({"pending":pending(),"turns":panel.conversation.size(),"raw_committed":FileAccess.get_file_as_string(backup).contains("between-raw-and-turn"),"error":panel.input_error}))
	check(sabotage_done and FileAccess.get_file_as_string(backup).contains("between-raw-and-turn"),"raw event really committed before conversation failure")
	check(pending()>0,"B conversation append failure retains durable receipt")
	check(panel.conversation.size()==old_count,"failed conversation writes never invent live turn")
	DirAccess.remove_absolute(child)
	DirAccess.rename_absolute(backup,child)
	check(FileAccess.get_sha256(original)==original_hash,"all failures preserve original archive bytes")
	print("ART_DURABILITY_BEFORE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),"godot":Engine.get_version_info().string}))
	host.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
