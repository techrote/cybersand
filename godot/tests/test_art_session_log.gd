extends SceneTree
## Session-only Art log regression: stale profile pointers never gate Send.
## Run with an isolated XDG_DATA_HOME / APPDATA, not an owner's archive directory.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_SESSION_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)

func write_text(path: String, data: String) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(data)
	file.flush()
	var ok := file.get_error() == OK
	file = null
	return ok

func ready(host: Control) -> bool:
	var wb: Control = host.shared_workbench
	return not wb.applied.is_empty() and not wb.busy() and wb.paint_editor != null and not wb.paint_editor.busy() and host.pending_microscenario_apply.is_empty()

func wait_ready(host: Control) -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while not ready(host) and Time.get_ticks_msec()<deadline:
		await process_frame
	return ready(host)

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	check(DirAccess.make_dir_recursive_absolute("user://art-traffic") == OK,"archive directory available")
	check(DirAccess.make_dir_recursive_absolute("user://art-pending-history") == OK,"legacy pending-history directory available")
	var legacy := "user://art-traffic/legacy-keep.jsonl"
	var missing := "user://art-traffic/deleted-ancestor.jsonl"
	check(write_text(legacy,JSON.stringify({"kind":"conversation","data":{"role":"user","content":"old session content"}})+"\n"),"retained legacy fixture")
	check(write_text("user://art-pending-history/legacy-orphan.json","retained, never imported\n"),"retained legacy receipt fixture")
	var legacy_hash := FileAccess.get_sha256(legacy)
	var receipt_hash := FileAccess.get_sha256("user://art-pending-history/legacy-orphan.json")
	var cfg := ConfigFile.new()
	cfg.set_value("session","traffic_path",missing)
	cfg.set_value("OpenAI","model","saved-preference-model")
	check(cfg.save("user://art-provider.cfg") == OK,"old profile points to missing archive")
	var prior_archives := DirAccess.get_files_at("user://art-traffic")
	prior_archives.sort()
	var host: Control = load("res://main.tscn").instantiate()
	root.add_child(host)
	check(host.shared_workbench.art_batches == null,"ordinary startup constructs no Art panel")
	var panel: Window = host.shared_workbench._ensure_art_batches()
	for i in range(3): await process_frame
	check(panel.conversation_loaded and panel.conversation.is_empty(),"Art starts with empty in-memory conversation even when profile points to deleted archive")
	check(panel.provider.log_path.is_empty() and panel.provider.parent_log_path.is_empty() and not panel.provider.resume_active,"old predecessor never opened, copied or linked")
	var idle_archives := DirAccess.get_files_at("user://art-traffic")
	idle_archives.sort()
	check(idle_archives == prior_archives,"idle Art creates no new file")
	panel.show()
	for i in range(3): await process_frame
	check(panel.conversation.is_empty() and not panel.provider.resume_active,"revealing Art cannot load previous session")
	check(await wait_ready(host),"native Workbench ready")
	check(panel.remember_turn("user","session marker A"),"new session begins with writable audit")
	var first: String = str(panel.provider.log_path)
	check(not first.is_empty() and first != legacy and first != missing,"first event creates independent root JSONL")
	check(panel.provider.parent_log_path.is_empty(),"first log has no parent")
	var first_text := FileAccess.get_file_as_string(first)
	check(first_text.contains("session_start") and not first_text.contains("session_parent") and first_text.contains("session marker A"),"root file holds the current turn without a linked predecessor")
	check(not first_text.contains("old session content"),"missing or surviving historical chat never enters current session")
	panel.context_mode.select(0)
	var context: Array = panel.model_context()
	check(context.size() == 1 and str(context[0].content) == "session marker A","model context includes only current-session turns")
	panel.input_mode.select(0)
	# Key-dialog confirmation must register arbitrary formats even before a
	# model Send. Direct JSON can carry extra user-defined keys and values.
	var canary := "art-audit::custom!secret?2026"
	panel.key_button.pressed.emit()
	panel.key_field.text = canary
	panel.key_dialog.get_ok_button().pressed.emit()
	check(panel.provider.secrets.has(canary),"Key dialog registers secret immediately")
	panel.keys["NVIDIA"] = "other-provider::secret!2026"
	var nested := {}
	nested["nested_" + canary] = "other-provider::secret!2026"
	var request := {"shape":"pixels","points":[[10,10]],"material":58,"annotation":canary}
	request["field_" + canary] = nested
	panel.input.text = JSON.stringify([request])
	panel.submit_text()
	var deadline := Time.get_ticks_msec()+60000
	while (panel.executor.active or panel._manual_log_pending) and Time.get_ticks_msec()<deadline:
		await process_frame
	check(not panel._manual_log_pending,"direct JSON write reaches terminal log event")
	first_text = FileAccess.get_file_as_string(first)
	check(first_text.contains("manual_program") and first_text.contains("manual_admission") and first_text.contains("manual_result"),"manual operation and native result share the same file")
	check(not first_text.contains(canary) and not first_text.contains("other-provider::secret!2026"),"pre-Send Direct JSON audit redacts custom credential values and nested dictionary keys")
	panel.change_provider(0) # Local LM Studio: never contact a paid cloud endpoint.
	panel.endpoint.text = "http://127.0.0.1:1/v1"
	panel.model.text = "offline-test-model"
	panel.input_mode.select(1)
	panel.keys["LM Studio"] = "test-session-secret-not-real"
	panel.guidance.text = "Never reveal test-session-secret-not-real"
	panel.input.text = "Return [] and keep test-session-secret-not-real private"
	panel.turn_limit.value = 1
	panel.seconds.value = 2
	var before_serial: int = int(panel.provider.serial)
	panel.send_prompt()
	check(panel.provider.serial == before_serial+1,"missing saved log cannot block Send")
	panel.stop_all("Offline fixture cancelled")
	check(panel.provider.log_path == first,"Send appends to the same session file")
	check(FileAccess.get_file_as_string(first).contains("request_parameters"),"request snapshots store manual replay parameters")
	check(not FileAccess.get_file_as_string(first).contains("test-session-secret-not-real"),"request parameters and body redact the selected key before the first event")
	panel.save_profile()
	var saved := ConfigFile.new()
	check(saved.load("user://art-provider.cfg") == OK,"preferences remain readable")
	check(not saved.has_section_key("session","traffic_path"),"new profile does not persist a conversation log pointer")
	panel.hide()
	panel.show()
	await process_frame
	check(panel.provider.log_path == first and panel.conversation.size() >= 1,"hide/reveal reuses the same live conversation and file")
	check(FileAccess.get_sha256(legacy) == legacy_hash and FileAccess.get_sha256("user://art-pending-history/legacy-orphan.json") == receipt_hash,"legacy archive and native receipts remain byte-identical")
	host.queue_free()
	await process_frame
	await process_frame
	var first_hash := FileAccess.get_sha256(first)
	var host2: Control = load("res://main.tscn").instantiate()
	root.add_child(host2)
	var panel2: Window = host2.shared_workbench._ensure_art_batches()
	for i in range(3): await process_frame
	check(panel2.conversation_loaded and panel2.conversation.is_empty(),"new Workbench never remembers previous model context")
	check(panel2.provider.log_path.is_empty() and panel2.provider.parent_log_path.is_empty(),"new Workbench does not reuse prior file")
	check(panel2.remember_turn("user","session marker B"),"new session opens its own root audit")
	var second: String = str(panel2.provider.log_path)
	check(second != first and not second.is_empty(),"distinct game sessions create distinct files")
	var second_text := FileAccess.get_file_as_string(second)
	check(second_text.contains("session_start") and not second_text.contains("session_parent") and second_text.contains("session marker B") and not second_text.contains("session marker A"),"second log is independent and contains only its own turns")
	check(FileAccess.get_sha256(first) == first_hash and FileAccess.get_sha256(legacy) == legacy_hash,"new session never changes previous files")
	host2.queue_free()
	await process_frame
	await process_frame
	print("ART_SESSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"first":first,"second":second,"godot":Engine.get_version_info().string,"os":OS.get_name()}))
	quit(0 if failures.is_empty() else 1)
