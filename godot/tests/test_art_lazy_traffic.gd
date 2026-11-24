extends SceneTree
## A saved log is an audit artifact, never a new-session model context.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_LAZY_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	DirAccess.make_dir_recursive_absolute("user://art-traffic")
	var old := "user://art-traffic/lazy-legacy.jsonl"
	var f := FileAccess.open(old,FileAccess.WRITE)
	f.store_line(JSON.stringify({"kind":"conversation","data":{"role":"user","content":"old text"}}))
	f = null
	var original_sha := FileAccess.get_sha256(old)
	var profile := ConfigFile.new()
	profile.set_value("session","traffic_path",old)
	check(profile.save("user://art-provider.cfg") == OK,"legacy profile pointer seeded")
	var app: Control = load("res://main.tscn").instantiate()
	root.add_child(app)
	check(app.shared_workbench.art_batches == null,"game startup keeps Art lazy")
	var panel: Window = app.shared_workbench._ensure_art_batches()
	await process_frame
	check(panel.conversation_loaded and panel.conversation.is_empty(),"in-memory conversation begins empty without loading prior archive")
	check(panel.provider.log_path.is_empty() and panel.provider.parent_log_path.is_empty(),"hidden Art creates no child or parent")
	panel.show()
	for i in range(2): await process_frame
	panel.hide()
	panel.show()
	for i in range(2): await process_frame
	check(panel.conversation.is_empty() and panel.provider.log_path.is_empty(),"show/hide cannot restore history or create an archive")
	check(panel.remember_turn("user","current marker A"),"first real event accepted")
	var first: String = str(panel.provider.log_path)
	var content := FileAccess.get_file_as_string(first)
	check(not first.is_empty() and first != old and content.contains("session_start") and not content.contains("session_parent"),"first session writes a new root log")
	check(not content.contains("old text"),"new root contains no legacy transcript")
	panel.remember_turn("assistant","current marker B")
	check(panel.provider.log_path == first and FileAccess.get_file_as_string(first).contains("current marker B"),"same session appends to one file")
	check(FileAccess.get_sha256(old) == original_sha,"original archive bytes unchanged")
	app.queue_free()
	await process_frame
	await process_frame
	var first_sha := FileAccess.get_sha256(first)
	var next: Control = load("res://main.tscn").instantiate()
	root.add_child(next)
	var next_panel: Window = next.shared_workbench._ensure_art_batches()
	await process_frame
	check(next_panel.conversation_loaded and next_panel.conversation.is_empty(),"next game session has no inherited turns")
	check(next_panel.provider.log_path.is_empty() and next_panel.provider.parent_log_path.is_empty(),"next game starts without prior audit link")
	check(next_panel.remember_turn("user","another-game"),"new session can append independently")
	check(next_panel.provider.log_path != first and not FileAccess.get_file_as_string(next_panel.provider.log_path).contains("current marker A"),"new game writes distinct standalone JSONL")
	check(FileAccess.get_sha256(first) == first_sha and FileAccess.get_sha256(old) == original_sha,"new game changes no previous traffic bytes")
	next.queue_free()
	await process_frame
	await process_frame
	print("ART_LAZY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"one-root-log-per-game-session"}))
	quit(0 if failures.is_empty() else 1)
