extends SceneTree
## Session-only native history audit. Real PAINT authority is tested separately
## by test_art_undo and the shared Workbench native edit regressions.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_HISTORY_SESSION_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	DirAccess.make_dir_recursive_absolute("user://art-traffic")
	DirAccess.make_dir_recursive_absolute("user://art-pending-history")
	var old_receipt := "user://art-pending-history/old-immutable.json"
	var f := FileAccess.open(old_receipt,FileAccess.WRITE)
	f.store_string("historical unassociated journal\n")
	f = null
	var receipt_sha := FileAccess.get_sha256(old_receipt)
	var profile := ConfigFile.new()
	profile.set_value("session","traffic_path","user://art-traffic/missing-legacy.jsonl")
	check(profile.save("user://art-provider.cfg") == OK,"stale session association configured")
	var host: Control = load("res://main.tscn").instantiate()
	root.add_child(host)
	var bench: Control = host.shared_workbench
	check(bench.art_batches == null,"native Workbench starts without old Art panel")
	check(bench.art_history_guard().is_empty(),"native history not blocked by previous Art session")
	var panel: Window = bench._ensure_art_batches()
	await process_frame
	check(panel.conversation_loaded and panel.conversation.is_empty(),"fresh memory has no inherited native receipts")
	check(not panel.provider.resume_active and panel.provider.parent_log_path.is_empty(),"pending-history orphan never triggers transcript scan")
	# Synthetic receipt exercises the Art projection, not a second native edit.
	panel.history_edited({"action":"undo","status":"completed","applied":7,"label":"synthetic verification"},42)
	var first: String = str(panel.provider.log_path)
	check(not first.is_empty(),"native result creates the session's single audit lazily")
	var text_data := FileAccess.get_file_as_string(first)
	check(text_data.contains("native_history_action") and text_data.contains("world_epoch"),"confirmed-action projection saved in the same root log")
	check(panel.conversation.size() == 1 and str(panel.conversation[0].content).contains("Human undo"),"current session model context sees the action")
	panel.history_edited({"action":"redo","status":"completed","applied":7,"label":"synthetic verification"},42)
	check(panel.provider.log_path == first and FileAccess.get_file_as_string(first).contains("Human redo"),"later native receipt appends to current file")
	check(FileAccess.get_sha256(old_receipt) == receipt_sha,"old journal entry neither read nor modified")
	host.queue_free()
	await process_frame
	await process_frame
	var first_sha := FileAccess.get_sha256(first)
	var host2: Control = load("res://main.tscn").instantiate()
	root.add_child(host2)
	var other: Window = host2.shared_workbench._ensure_art_batches()
	await process_frame
	check(other.conversation_loaded and other.conversation.is_empty(),"new game cannot inherit previous Undo/Redo context")
	check(other.provider.log_path.is_empty() and other.provider.parent_log_path.is_empty(),"new game has no stale Art association")
	check(FileAccess.get_sha256(first) == first_sha and FileAccess.get_sha256(old_receipt) == receipt_sha,"session transition preserves original evidence bytes")
	host2.queue_free()
	await process_frame
	await process_frame
	print("ART_HISTORY_SESSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"session-only"}))
	quit(0 if failures.is_empty() else 1)
