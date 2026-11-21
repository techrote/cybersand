extends SceneTree
## Real native Workbench owner plus adversarial real filesystem transactions.
## Run only with an isolated XDG_DATA_HOME/APPDATA. The Python qualification
## harness also executes restart/crash modes in distinct Godot processes.
const ArtPanel = preload("res://scripts/art_batch_panel.gd")
const Provider = preload("res://scripts/art_provider.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const PROFILE := "user://art-provider.cfg"
const JOURNAL := "user://art-pending-history"
var checks := 0
var failures: Array[String] = []
var host: Node
var panel: Window
var original := ""
var original_hash := ""
var scenario := "suite"
var sabotaged := false
var sabotage_label := ""
var sabotage_path := ""
var sabotage_backup := ""
var native_receipts: Array[Dictionary] = []
var cleanup_receipt_path := ""
var cleanup_receipt_bytes := ""

func _initialize() -> void:
	scenario = OS.get_environment("ART_HISTORY_DURABILITY_CASE")
	if scenario.is_empty(): scenario = "suite"
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("ART_HISTORY_DURABILITY_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error("ART_HISTORY_DURABILITY: "+label)
	return ok

func write_text(path: String, value: String) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if not check(file != null,"fixture writable: "+path): return false
	file.store_string(value)
	file.flush()
	var error := file.get_error()
	file = null
	return check(error == OK,"fixture flush: "+path)

func journal_files() -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(JOURNAL): return out
	for name: String in DirAccess.get_files_at(JOURNAL):
		if name.ends_with(".json"): out.append(JOURNAL.path_join(name))
	out.sort()
	return out

func journal_receipt_id(path: String) -> String:
	var item: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return str(item.get("id","")) if item is Dictionary else ""

func receipt(action: String, label: String) -> Dictionary:
	return {"action":action,"status":"completed","label":label,"applied":1}

func emit_receipt(action: String, label: String) -> void:
	host.shared_workbench.paint_editor.history_action_finished.emit(receipt(action,label))

func saved_path() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE) != OK: return ""
	return str(cfg.get_value("session","traffic_path",""))

func until(predicate: Callable, label: String, limit_ms: int = 60000) -> bool:
	var deadline := Time.get_ticks_msec()+limit_ms
	while Time.get_ticks_msec()<deadline:
		if bool(predicate.call()): return true
		await process_frame
	return check(false,label+" timed out")

func close_host() -> void:
	if is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame
	host = null
	panel = null

func start_host() -> void:
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	check(host.shared_workbench.art_batches == null,"native Workbench starts without constructing Art")

func start_fixture(name: String, open_art: bool = false) -> bool:
	await close_host()
	DirAccess.make_dir_recursive_absolute("user://art-traffic")
	original = "user://art-traffic/durability-"+name+".jsonl"
	if not write_text(original,JSON.stringify({"kind":"conversation","data":{"role":"user","content":"Original "+name}})+"\n"): return false
	original_hash = FileAccess.get_sha256(original)
	var cfg := ConfigFile.new()
	cfg.set_value("session","traffic_path",original)
	if not check(cfg.save(PROFILE) == OK,"configure "+name+" source"): return false
	start_host()
	if open_art: return await open_panel()
	return true

func open_panel() -> bool:
	panel = host.shared_workbench._ensure_art_batches()
	panel.show()
	if not await until(func() -> bool: return not panel.provider.resume_active,"incremental restore"): return false
	return check(panel.conversation_loaded,"explicit Art open restores bound conversation")

func count_turns(turns: Array, label: String) -> int:
	var count := 0
	for turn: Dictionary in turns:
		if str(turn.get("content","")).contains('"label":"'+label+'"'): count += 1
	return count

func count_raw(path: String, label: String) -> int:
	if not FileAccess.file_exists(path): return 0
	var count := 0
	for line: String in FileAccess.get_file_as_string(path).split("\n",false):
		var item: Variant = JSON.parse_string(line)
		if item is Dictionary and item.get("kind") == "history_result" \
				and item.get("data") is Dictionary and str(item.data.get("label","")) == label:
			count += 1
	return count

func replay_count(label: String, expected: int = 1) -> void:
	var reader := Provider.new()
	var turns: Array = reader.resume_traffic(saved_path())
	check(reader.resume_ok and count_turns(turns,label) == expected,"fresh reader sees exactly %d visible %s result" % [expected,label])
	reader.free()

func preserved(label: String) -> void:
	check(FileAccess.get_sha256(original) == original_hash,label+" preserves exact original archive bytes")

func block_path(path: String) -> String:
	var backup := path+".durability-backup"
	if not check(DirAccess.rename_absolute(path,backup) == OK,"retain original before filesystem obstruction"): return ""
	if not check(DirAccess.make_dir_absolute(path) == OK,"directory refuses actual file write"): return ""
	return backup

func unblock_path(path: String, backup: String) -> void:
	check(DirAccess.remove_absolute(path) == OK,"remove controlled directory obstruction")
	check(Provider.Archive.atomic_replace(backup,path).get("ok",false),"atomically restore original fixture file")

func last_traffic() -> Dictionary:
	var lines: PackedStringArray = panel.provider.traffic.split("\n",false)
	if lines.is_empty(): return {}
	var parsed: Variant = JSON.parse_string(lines[lines.size()-1])
	return parsed if parsed is Dictionary else {}

func obstruct_after_raw() -> void:
	if sabotaged or not panel.provider.last_event_stored: return
	var event := last_traffic()
	if event.get("kind") != "history_result" or not event.get("data") is Dictionary \
			or str(event.data.get("label","")) != sabotage_label: return
	sabotaged = true
	sabotage_backup = block_path(sabotage_path)

func normal_loaded() -> void:
	if not await start_fixture("normal",true): return
	var before: int = panel.conversation.size()
	emit_receipt("undo","normal-loaded")
	print("ART_HISTORY_DURABILITY_STATE ",JSON.stringify({"case":"normal-loaded","error":panel.input_error,"warning":panel.provider.log_warning,"pending":journal_files().size(),"turns":panel.conversation}))
	check(panel.conversation.size() == before+1 and count_turns(panel.conversation,"normal-loaded") == 1,"loaded native completion commits exactly one visible turn")
	check(journal_files().is_empty(),"fully committed loaded result removes journal")
	panel._drain_pending_history_receipts()
	panel._drain_pending_history_receipts()
	replay_count("normal-loaded")
	preserved("normal loaded completion")

func archive_failure(between_raw_and_turn: bool) -> void:
	var name := "conversation-failure" if between_raw_and_turn else "raw-failure"
	if not await start_fixture(name,true): return
	check(panel.remember_turn("assistant","Writable segment"),"prepare active append-only segment")
	var active_path: String = panel.provider.log_path
	var before: int = panel.conversation.size()
	var active_hash := FileAccess.get_sha256(active_path)
	var backup := ""
	if between_raw_and_turn:
		sabotaged = false; sabotage_label = name; sabotage_path = active_path
		panel.provider.traffic_changed.connect(obstruct_after_raw)
	else: backup = block_path(active_path)
	var immutable := receipt("undo",name)
	immutable.api_key = "durability-fixture-secret"
	host.shared_workbench.paint_editor.history_action_finished.emit(immutable)
	immutable.label = "changed-after-callback"
	if between_raw_and_turn:
		panel.provider.traffic_changed.disconnect(obstruct_after_raw)
		backup = sabotage_backup
		check(sabotaged and count_raw(backup,name) == 1,"raw event committed before actual conversation filesystem failure")
	else: check(FileAccess.get_sha256(backup) == active_hash,"raw append failure preserves writable segment bytes")
	check(panel.conversation.size() == before,"failed archive append never invents visible conversation")
	check(journal_files().size() == 1,"failed "+name+" retains exactly one durable receipt")
	check(not panel.input_error.is_empty(),"failed "+name+" is actionable")
	var pending_bytes := FileAccess.get_file_as_string(journal_files()[0]) if journal_files().size() == 1 else ""
	check(pending_bytes.contains(name) and pending_bytes.contains("_history_receipt_id"),"durable receipt has immutable result and stable identity")
	check(not pending_bytes.contains("durability-fixture-secret") and not pending_bytes.contains("changed-after-callback"),"journal redacts credentials and owns an immutable completion copy")
	preserved(name)
	unblock_path(active_path,backup)
	panel._drain_pending_history_receipts()
	check(count_turns(panel.conversation,name) == 1 and journal_files().is_empty(),"restored disk commits pending result without repeating native edit")
	check(count_raw(active_path,name) == 1,"recovery deduplicates raw history event")
	replay_count(name)
	preserved(name+" recovery")

func capture_cleanup_receipt() -> void:
	if not panel.provider.last_event_stored: return
	var event := last_traffic()
	if event.get("kind") != "conversation" or not event.get("data") is Dictionary \
			or not str(event.data.get("content","")).contains('"label":"cleanup-older"'): return
	var files := journal_files()
	if files.size() != 1: return
	cleanup_receipt_path = files[0]
	cleanup_receipt_bytes = FileAccess.get_file_as_string(cleanup_receipt_path)

func check_latest_context(label: String) -> void:
	check(panel.last_result.contains('"label":"cleanup-newer"'),label+" retains newest native result")
	panel.context_mode.select(1)
	var context: Array = panel.model_context()
	check(context.size() == 13 and str(context[0].get("content","")).begins_with("Earlier turns omitted") \
		and str(context[0].get("content","")).contains('"label":"cleanup-newer"') \
		and not str(context[0].get("content","")).contains('"label":"cleanup-older"'),
		label+" compact context omission marker uses newest confirmed result")
	check(count_turns(panel.conversation,"cleanup-older") == 1 and count_turns(panel.conversation,"cleanup-newer") == 1,
		label+" preserves both native turns exactly once")

func cleanup_context() -> void:
	if not await start_fixture("cleanup-context",true): return
	cleanup_receipt_path = ""; cleanup_receipt_bytes = ""
	panel.provider.traffic_changed.connect(capture_cleanup_receipt)
	emit_receipt("undo","cleanup-older")
	panel.provider.traffic_changed.disconnect(capture_cleanup_receipt)
	check(not cleanup_receipt_path.is_empty() and cleanup_receipt_bytes.contains('"label":"cleanup-older"'),
		"retain exact older receipt bytes at real committed-turn cleanup boundary")
	emit_receipt("redo","cleanup-newer")
	for index in range(13):
		check(panel.remember_turn("assistant","Later ordinary message %02d" % index),"append ordinary turn to require compacted native context %02d" % index)
	check(panel.conversation.size() == 16 and journal_files().is_empty(),"both native results committed before cleanup-only recovery")
	check_latest_context("before cleanup replay")
	var active_path := saved_path()
	var active_hash := FileAccess.get_sha256(active_path)
	await close_host()
	# Restore the real staged bytes left at the historical cleanup boundary.
	# The separate crash-seed case performs an actual OS kill at this boundary.
	write_text(cleanup_receipt_path,cleanup_receipt_bytes)
	start_host()
	if not await open_panel(): return
	check(journal_files().is_empty(),"restart removes older fully committed pending receipt")
	check_latest_context("restart cleanup-only replay")
	check(FileAccess.get_sha256(active_path) == active_hash,"cleanup-only restart never appends or rewrites committed archive")
	replay_count("cleanup-older")
	replay_count("cleanup-newer")
	check(panel.remember_turn("assistant","After restart writable continuation"),"create active writable segment before late journal arrives")
	var late_path := saved_path()
	var late_hash := FileAccess.get_sha256(late_path)
	check(panel.provider.log_path == late_path and not late_path.is_empty(),"late journal probe exercises already-loaded active writer")
	write_text(cleanup_receipt_path,cleanup_receipt_bytes)
	panel._drain_pending_history_receipts()
	check(panel.provider.resume_active and not panel.conversation_loaded \
		and journal_files().size() == 1,"late reintroduced journal starts incremental validation before deduplication")
	if not await until(func() -> bool: return not panel.provider.resume_active,"late journal incremental replay"): return
	check(panel.conversation_loaded and journal_files().is_empty(),"late journal incremental replay completes cleanup")
	check_latest_context("already-loaded cleanup-only replay")
	check(FileAccess.get_sha256(late_path) == late_hash and FileAccess.get_sha256(active_path) == active_hash,"late journal cleanup preserves exact archive bytes")
	preserved("old receipt cleanup and newest context")

func profile_failure() -> void:
	if not await start_fixture("profile-checkpoint",true): return
	var bytes_hash := FileAccess.get_sha256(PROFILE)
	var backup := block_path(PROFILE)
	emit_receipt("redo","checkpoint-refused")
	check(journal_files().size() == 1,"failed profile checkpoint retains receipt journal")
	check(panel.provider.log_path.is_empty() and count_turns(panel.conversation,"checkpoint-refused") == 0,"failed checkpoint cannot adopt unreferenced segment or visible turn")
	var staged_archive_count := DirAccess.get_files_at("user://art-traffic").size()
	for attempt in range(5):
		panel._drain_pending_history_receipts()
		check(DirAccess.get_files_at("user://art-traffic").size() == staged_archive_count and journal_files().size() == 1,
			"profile checkpoint retry %d reuses one staged segment and one durable receipt" % attempt)
	check(FileAccess.get_sha256(backup) == bytes_hash,"profile checkpoint refusal preserves original profile bytes")
	preserved("profile checkpoint refusal")
	unblock_path(PROFILE,backup)
	panel._drain_pending_history_receipts()
	check(count_turns(panel.conversation,"checkpoint-refused") == 1 and journal_files().is_empty(),"repaired profile checkpoint allows durable retry")
	check(DirAccess.get_files_at("user://art-traffic").size() == staged_archive_count \
		and count_raw(saved_path(),"checkpoint-refused") == 1,"profile repair adopts original staged segment without duplicate raw event or archive growth")
	replay_count("checkpoint-refused")
	preserved("profile checkpoint recovery")

func known_profile_outage() -> void:
	if not await start_fixture("known-profile"): return
	var profile_text := FileAccess.get_file_as_string(PROFILE)
	var backup := block_path(PROFILE)
	emit_receipt("undo","known-directory-outage")
	check(host.shared_workbench.art_batches == null and journal_files().size() == 1,"known-session unreadable profile durably stages without constructing Art")
	unblock_path(PROFILE,backup)
	write_text(PROFILE,"[session\ntraffic_path=corrupt\n")
	emit_receipt("redo","known-corrupt-outage")
	check(host.shared_workbench.art_batches == null and journal_files().size() == 2,"known-session corrupt profile retains next source-bound receipt")
	for path: String in journal_files():
		var item: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(item is Dictionary and item.get("source") == original,"outage receipt remains associated with original session")
	write_text(PROFILE,profile_text)
	check(DirAccess.rename_absolute(PROFILE,"user://temporarily-absent-profile.cfg") == OK,"temporarily remove known profile without directory replacement")
	panel = host.shared_workbench._ensure_art_batches()
	panel.show()
	emit_receipt("undo","known-missing-profile-open")
	check(journal_files().size() == 3,"Art opened during missing known profile retains its earlier session association")
	for path: String in journal_files():
		var item: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(item is Dictionary and item.get("source") == original,"missing-profile Art receipt stays bound to session A")
	check(Provider.Archive.atomic_replace("user://temporarily-absent-profile.cfg",PROFILE).get("ok",false),"restore known profile after Art was opened")
	await close_host()
	start_host()
	if not await open_panel(): return
	check(count_turns(panel.conversation,"known-directory-outage") == 1 and count_turns(panel.conversation,"known-corrupt-outage") == 1 \
		and count_turns(panel.conversation,"known-missing-profile-open") == 1,"repaired profile restores all original-session outage receipts")
	check(journal_files().is_empty(),"known-session outage recovery completes journal cleanup")
	preserved("known-session profile outages")

func unknown_profile_outage() -> void:
	await close_host()
	write_text(PROFILE,"[session\ntraffic_path=corrupt\n")
	start_host()
	emit_receipt("undo","unknown-corrupt-profile")
	check(host.shared_workbench.art_batches == null and journal_files().is_empty(),"unknown corrupt profile cannot fabricate a source association")
	check(not str(host.shared_workbench.message).is_empty(),"unknown corrupt profile reports actionable persistence failure")
	await close_host()
	DirAccess.remove_absolute(PROFILE)
	check(DirAccess.make_dir_absolute(PROFILE) == OK,"unknown unreadable profile directory fixture")
	start_host()
	emit_receipt("redo","unknown-directory-profile")
	check(journal_files().is_empty() and not str(host.shared_workbench.message).is_empty(),"unknown unreadable profile fails explicitly")
	await close_host()
	DirAccess.remove_absolute(PROFILE)
	start_host()
	emit_receipt("undo","missing-profile-with-archives")
	check(journal_files().is_empty() and not str(host.shared_workbench.message).is_empty(),"missing profile with retained archives cannot claim no session ever existed")
	var missing: Dictionary = ArtPanel.read_history_session()
	check(missing.get("state") == "error","missing profile plus archive evidence has explicit unassociated state")
	await close_host()
	check(DirAccess.rename_absolute("user://art-traffic","user://durability-held-traffic") == OK,"retain existing archives outside virgin-profile fixture")
	var had_journal := DirAccess.dir_exists_absolute(JOURNAL)
	if had_journal: check(DirAccess.rename_absolute(JOURNAL,"user://durability-held-journal") == OK,"retain existing journal outside virgin-profile fixture")
	start_host()
	emit_receipt("undo","no-profile-ever")
	check(host.shared_workbench.art_batches == null and journal_files().is_empty(),"genuinely absent profile handles no session without eager Art")
	var session: Dictionary = ArtPanel.read_history_session()
	check(session.get("state") == "no_session","absent profile has explicit no-session state")
	await close_host()
	check(DirAccess.rename_absolute("user://durability-held-traffic","user://art-traffic") == OK,"restore exact previous archive directory after virgin fixture")
	if had_journal: check(DirAccess.rename_absolute("user://durability-held-journal",JOURNAL) == OK,"restore exact previous journal directory after virgin fixture")
	var cfg := ConfigFile.new()
	cfg.set_value("session","incomplete","missing traffic_path")
	check(cfg.save(PROFILE) == OK,"incomplete session metadata fixture")
	start_host()
	emit_receipt("undo","incomplete-session-metadata")
	check(journal_files().is_empty() and not str(host.shared_workbench.message).is_empty(),"incomplete session metadata explicitly refuses guessing conversation")
	await close_host()
	cfg.set_value("session","traffic_path",42)
	check(cfg.save(PROFILE) == OK,"invalid session metadata fixture")
	start_host()
	emit_receipt("undo","invalid-session-metadata")
	check(journal_files().is_empty() and not str(host.shared_workbench.message).is_empty(),"invalid session metadata cannot silently erase native receipt")
	await close_host()
	if not await start_fixture("unrelated-after-unknown",true): return
	check(count_turns(panel.conversation,"unknown-corrupt-profile") == 0 and count_turns(panel.conversation,"unknown-directory-profile") == 0,"unknown receipts never attach to subsequently selected unrelated session")

func session_isolation() -> void:
	if not await start_fixture("session-a"): return
	var source_a := original
	var source_a_hash := original_hash
	emit_receipt("undo","session-a-only")
	check(journal_files().size() == 1,"unopened valid saved profile durably stages")
	if not await start_fixture("session-b",true): return
	check(count_turns(panel.conversation,"session-a-only") == 0 and journal_files().size() == 1,"session B does not consume session A pending receipt")
	emit_receipt("redo","session-b-only")
	check(count_turns(panel.conversation,"session-b-only") == 1 and journal_files().size() == 1,"session B commits its own result without migrating A")
	await close_host()
	var cfg := ConfigFile.new()
	cfg.set_value("session","traffic_path",source_a)
	check(cfg.save(PROFILE) == OK,"restore explicit session A selection")
	start_host()
	if not await open_panel(): return
	check(count_turns(panel.conversation,"session-a-only") == 1 and count_turns(panel.conversation,"session-b-only") == 0,"session A alone recovers its own result")
	check(journal_files().is_empty() and FileAccess.get_sha256(source_a) == source_a_hash,"session-isolated replay preserves A archive and cleans only completed receipt")

func invalid_journal() -> void:
	for variant: String in ["malformed","oversized","wrong-id","unsafe-source","wrong-order"]:
		if not await start_fixture("invalid-"+variant): return
		emit_receipt("undo","valid-before-"+variant)
		var valid_files := journal_files()
		if not check(valid_files.size() == 1,"stage valid receipt before corrupt journal probe"): return
		var valid_bytes := FileAccess.get_file_as_string(valid_files[0])
		var invalid := JOURNAL.path_join("00000000000000000001-11111111111111111111111111111111.json")
		var body := "not JSON\n"
		if variant == "oversized": body = "x".repeat(ArtPanel.MAX_HISTORY_RECEIPT_BYTES+1)
		elif variant in ["wrong-id","unsafe-source"]:
			var item: Dictionary = JSON.parse_string(valid_bytes)
			item.id = "00000000000000000001-11111111111111111111111111111111"
			if variant == "unsafe-source":
				item.receipt._history_receipt_id = item.id
				item.source = "user://art-traffic/../outside.jsonl"
			body = JSON.stringify(item)+"\n"
		elif variant == "wrong-order":
			var item: Dictionary = JSON.parse_string(valid_bytes)
			invalid = JOURNAL.path_join("00000000000000000001_"+str(item.id)+".json")
			body = valid_bytes # Frozen payload remains valid; only filename/order disagree.
		write_text(invalid,body)
		panel = host.shared_workbench._ensure_art_batches()
		panel.show()
		await until(func() -> bool: return not panel.provider.resume_active,"invalid journal restore")
		check(count_turns(panel.conversation,"valid-before-"+variant) == 0 and journal_files().size() == 2,"invalid "+variant+" journal fails closed before writing valid receipts")
		if variant == "wrong-order":
			check(panel.input_error.contains("publication order"),"schema2 filename/body order mismatch reaches explicit publication-order refusal")
		check(FileAccess.get_file_as_string(valid_files[0]) == valid_bytes and FileAccess.get_file_as_string(invalid) == body,"invalid journal handling preserves both original records")
		preserved("invalid "+variant)
		check(DirAccess.remove_absolute(invalid) == OK,"remove fixture corruption for recovery")
		panel._ensure_history_loaded()
		await until(func() -> bool: return not panel.provider.resume_active,"repaired journal permits explicit restoration")
		panel._drain_pending_history_receipts()
		check(count_turns(panel.conversation,"valid-before-"+variant) == 1 and journal_files().is_empty(),"valid journal recovers after "+variant+" obstruction removed")
	if not await start_fixture("partial-journal"): return
	DirAccess.make_dir_recursive_absolute(JOURNAL)
	var partial := JOURNAL.path_join("interrupted.json.partial-incomplete")
	write_text(partial,"{incomplete record")
	emit_receipt("undo","complete-beside-partial")
	if not await open_panel(): return
	check(count_turns(panel.conversation,"complete-beside-partial") == 1 and FileAccess.get_file_as_string(partial) == "{incomplete record","partial unpublished receipt is ignored and preserved without losing complete records")
	DirAccess.remove_absolute(partial)

func journal_refusal() -> void:
	if not await start_fixture("journal-refusal",true): return
	check(journal_files().is_empty(),"journal refusal begins with no unrelated pending records")
	if DirAccess.dir_exists_absolute(JOURNAL): check(DirAccess.remove_absolute(JOURNAL) == OK,"remove empty fixture journal directory")
	write_text(JOURNAL,"journal location unavailable")
	emit_receipt("undo","journal-write-refused")
	check(not panel.input_error.is_empty() and count_turns(panel.conversation,"journal-write-refused") == 0,"journal write failure is explicit and cannot pretend transaction committed")
	check(FileAccess.get_file_as_string(JOURNAL) == "journal location unavailable","journal failure never replaces obstructing file")
	DirAccess.remove_absolute(JOURNAL)
	panel._drain_pending_history_receipts()
	check(count_turns(panel.conversation,"journal-write-refused") == 1 and journal_files().is_empty(),"bounded retained receipt recovers after journal becomes writable")
	replay_count("journal-write-refused")
	preserved("journal-write failure")
	check(DirAccess.remove_absolute(JOURNAL) == OK,"empty journal permits second resource-bound fixture")
	write_text(JOURNAL,"bounded retry obstruction")
	for index in range(ArtPanel.MAX_VOLATILE_HISTORY_RECEIPTS+1):
		emit_receipt("undo","bounded-%03d" % index)
	check(panel.pending_history_receipts.size() == ArtPanel.MAX_VOLATILE_HISTORY_RECEIPTS \
		and panel.input_error.contains("capacity"),"unwritable journal has bounded volatile storage and explicit overflow refusal")
	DirAccess.remove_absolute(JOURNAL)
	panel._drain_pending_history_receipts()
	var recovered := 0
	for turn: Dictionary in panel.conversation:
		if str(turn.content).contains('"label":"bounded-'): recovered += 1
	check(recovered == ArtPanel.MAX_VOLATILE_HISTORY_RECEIPTS and journal_files().is_empty(),"all admitted bounded retry receipts recover in order after storage returns")

func queued_callback_order(open_art: bool) -> void:
	var name := "queued-loaded" if open_art else "queued-unopened"
	if not await start_fixture(name,open_art): return
	check(journal_files().is_empty(),name+" begins without unrelated durable receipts")
	if DirAccess.dir_exists_absolute(JOURNAL):
		check(DirAccess.remove_absolute(JOURNAL) == OK,name+" removes empty journal for real file obstruction")
	if not write_text(JOURNAL,"queued callback journal obstruction"): return
	emit_receipt("undo",name+"-older")
	var queue: Array = panel.pending_history_receipts if open_art else host.shared_workbench._unopened_history_pending
	if not check(queue.size() == 1 and bool(queue[0].get("volatile",false)),
		name+" first completion is explicitly retained for bounded storage retry"): return
	var older_id := str(queue[0].id)
	var older_digest := JSON.stringify(queue[0].receipt).sha256_text()
	check(DirAccess.remove_absolute(JOURNAL) == OK,name+" repairs disk before periodic retry")
	# Stay in this same synchronous stack: the second grouped native completion
	# arrives after repair but before Workbench or Art can retry the older one.
	emit_receipt("redo",name+"-newer")
	queue = panel.pending_history_receipts if open_art else host.shared_workbench._unopened_history_pending
	if not check(queue.size() == 2 and bool(queue[0].get("volatile",false)) \
		and bool(queue[1].get("volatile",false)) and journal_files().is_empty(),
		name+" newer completion waits behind older volatile receipt despite writable disk"): return
	var newer_id := str(queue[1].id)
	var newer_digest := JSON.stringify(queue[1].receipt).sha256_text()
	check(str(queue[0].id) == older_id and JSON.stringify(queue[0].receipt).sha256_text() == older_digest,
		name+" later callback preserves the earlier immutable native completion")
	if open_art:
		check(count_turns(panel.conversation,name+"-older") == 0 and count_turns(panel.conversation,name+"-newer") == 0,
			name+" neither unstaged completion appears as a committed model turn")
		panel._drain_pending_history_receipts()
	else:
		check(host.shared_workbench.art_batches == null,name+" grouped completion preserves lazy Art construction")
		if not await until(func() -> bool: return host.shared_workbench._unopened_history_pending.is_empty(),
			name+" bounded retry stages grouped completions"): return
		var records: Array[Dictionary] = []
		for path: String in journal_files():
			var row: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if row is Dictionary: records.append(row)
		check(records.size() == 2 and str(records[0].id) == older_id and str(records[1].id) == newer_id,
			name+" repaired journal publishes both stable IDs in completion order")
		if records.size() == 2:
			check(JSON.stringify(records[0].receipt).sha256_text() == older_digest \
				and JSON.stringify(records[1].receipt).sha256_text() == newer_digest,
				name+" durable staging preserves both immutable native completions")
		if not await open_panel(): return
	var actual := []
	for turn: Dictionary in panel.conversation:
		if str(turn.content).contains('"label":"'+name+'-older"'): actual.append("older")
		if str(turn.content).contains('"label":"'+name+'-newer"'): actual.append("newer")
	check(actual == ["older","newer"] and journal_files().is_empty(),
		name+" recovers exactly once in original completion order")
	check(panel.last_result.contains('"label":"'+name+'-newer"'),name+" latest result is the newer completion")
	replay_count(name+"-older")
	replay_count(name+"-newer")
	preserved(name+" grouped completion recovery")

func native_idle() -> bool:
	if host == null: return false
	var bench: Node = host.shared_workbench
	var worker: RefCounted = host.simulation_worker
	var paint: Dictionary = worker.paint_state()
	return not bench.applied.is_empty() and not bench.busy() and not bench.paint_editor.busy() \
		and host.pending_microscenario_apply.is_empty() and not bool(paint.busy) and not bool(paint.get("receipt_ready",false))

func remember_native(value: Dictionary) -> void:
	native_receipts.append(value.duplicate(true))

func native_history() -> void:
	if not await start_fixture("real-native"): return
	if not await until(native_idle,"initial native Workbench ready"): return
	var bench: Node = host.shared_workbench
	var worker: RefCounted = host.simulation_worker
	var data: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	if not check(bench.apply(data),"apply real 512x512 blank native canvas"): return
	if not await until(native_idle,"new native canvas ready"): return
	check(bench.paint_editor.begin_deferred_brush(Vector2i(25,25),58,0,910001),"real native paint admitted through shared owner")
	if not await until(native_idle,"native paint committed"): return
	native_receipts = []
	bench.paint_editor.history_action_finished.connect(remember_native)
	check(bench.paint_editor.undo(),"ordinary native Undo admitted while Art unconstructed")
	if not await until(native_idle,"native Undo completed"): return
	check(native_receipts.size() == 1 and str(native_receipts[0].get("status","")) == "completed" \
		and int(native_receipts[0].get("applied",0)) > 0,"actual native owner confirms edited cells before receipt persistence")
	check(bench.art_batches == null and journal_files().size() == 1,"real native Undo preserves lazy Art and durable receipt")
	panel = bench._ensure_art_batches()
	check(bench.paint_editor.redo(),"ordinary native Redo admits before asynchronous Art restoration")
	panel.show()
	check(panel.provider.resume_active,"Art restoration starts incrementally while native Redo is in flight")
	if not await until(func() -> bool: return native_idle() and not panel.provider.resume_active,"native Redo and Art restoration settle"): return
	check(native_receipts.size() == 2 and panel.conversation.size() == 3 and journal_files().is_empty(),"real Undo and Redo each commit one ordered Art turn")
	if panel.conversation.size() >= 3:
		check(str(panel.conversation[1].content).contains("Human undo") and str(panel.conversation[2].content).contains("Human redo"),"native completion chronology matches restored model context")
	check(int(worker.paint_state().revision) >= 1,"actual native revision advanced through authored operations")
	var active_path: String = panel.provider.log_path
	var backup := block_path(active_path)
	check(bench.paint_editor.undo(),"real native Undo admits before raw archive append refusal")
	if not await until(native_idle,"native Undo under archive failure completed"): return
	check(native_receipts.size() == 3 and journal_files().size() == 1,"actual successful native Undo remains durable despite raw archive refusal")
	if journal_files().size() == 1:
		var item: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(journal_files()[0]))
		check(int(item.epoch) == int(worker.art_state().epoch) and item.receipt.get("action") == "undo","pending receipt captures native world epoch and immutable completion")
	unblock_path(active_path,backup)
	panel._drain_pending_history_receipts()
	check(native_receipts.size() == 3 and journal_files().is_empty() and panel.conversation.size() == 4,"writable-again recovery records actual native edit once without re-executing it")
	preserved("native Undo/Redo restoration")

func restart_seed() -> void:
	if not await start_fixture("restart",true): return
	check(panel.remember_turn("assistant","Writable restart segment"),"prepare restart source")
	sabotaged = false; sabotage_label = "raw-before-crash"; sabotage_path = panel.provider.log_path
	panel.provider.traffic_changed.connect(obstruct_after_raw)
	emit_receipt("redo","raw-before-crash")
	panel.provider.traffic_changed.disconnect(obstruct_after_raw)
	check(sabotaged and count_raw(sabotage_backup,"raw-before-crash") == 1,"restart seed retains real raw-only commit")
	var expected := ["raw-before-crash"]
	for index in range(75):
		var label := "restart-%03d" % index
		expected.append(label)
		emit_receipt("undo",label)
	check(journal_files().size() == 76,"75 additional immutable receipts survive blocked archive writes")
	# Leave the obstruction in place through process exit. The independent
	# recovery process restores access before opening Art; an automatic live
	# retry during shutdown must not consume the intended restart fixture.
	var ids := []
	for path: String in journal_files(): ids.append(path.get_file().trim_suffix(".json"))
	write_text("user://art-durability-restart.json",JSON.stringify({"source":saved_path(),"original":original,"original_sha256":original_hash,"expected":expected,"ids":ids,"blocked_path":sabotage_path,"backup_path":sabotage_backup})+"\n")
	preserved("shutdown with 75+ pending receipts")

func restart_recover() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://art-durability-restart.json"))
	if not check(manifest is Dictionary,"independent process loads restart witness"): return
	original = manifest.original; original_hash = manifest.original_sha256
	check(journal_files().size() == 76,"new process sees complete durable pending population")
	unblock_path(str(manifest.blocked_path),str(manifest.backup_path))
	start_host()
	check(host.shared_workbench.art_batches == null,"new process does not eagerly load conversation")
	if not await open_panel(): return
	var actual := []
	for turn: Dictionary in panel.conversation:
		for label: String in manifest.expected:
			if str(turn.content).contains('"label":"'+label+'"'): actual.append(label)
	check(actual == manifest.expected,"independent process restores all receipts once in original chronology")
	check(journal_files().is_empty(),"restart clears only fully committed receipts")
	replay_count("raw-before-crash")
	var raw_count := 0
	for segment: Dictionary in panel.provider._validated_segments: raw_count += count_raw(str(segment.path),"raw-before-crash")
	if not panel.provider.log_path.is_empty(): raw_count += count_raw(panel.provider.log_path,"raw-before-crash")
	check(raw_count == 1,"restart raw-commit boundary does not append duplicate raw result")
	preserved("independent restart recovery")

func kill_at_committed_turn() -> void:
	if not panel.provider.last_event_stored: return
	var event := last_traffic()
	if event.get("kind") != "conversation" or not str(event.get("data",{}).get("content","")).contains('"label":"killed-after-turn"'): return
	var files := journal_files()
	check(files.size() == 1,"crash boundary still has durable receipt")
	var proof := {"case":"crash-seed","receipt_id":journal_receipt_id(files[0]) if not files.is_empty() else "","boundary":"conversation-committed-before-journal-delete","source":saved_path(),"original":original,"original_sha256":original_hash,"journal":files[0] if not files.is_empty() else "","checks":checks,"failures":failures}
	write_text("user://art-durability-crash-boundary.json",JSON.stringify(proof)+"\n")
	print("ART_HISTORY_DURABILITY_CRASH_BOUNDARY ",JSON.stringify(proof))
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline: OS.delay_msec(100)
	check(false,"qualification parent did not terminate crash-boundary process")

func crash_seed() -> void:
	if not await start_fixture("crash",true): return
	check(panel.remember_turn("assistant","Writable crash segment"),"prepare crash source")
	panel.provider.traffic_changed.connect(kill_at_committed_turn)
	emit_receipt("undo","killed-after-turn")
	check(false,"self-termination must interrupt before journal cleanup")

func crash_recover() -> void:
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://art-durability-crash-boundary.json"))
	if not check(proof is Dictionary and proof.get("boundary") == "conversation-committed-before-journal-delete","fresh process verifies actual crash boundary witness"): return
	original = proof.original; original_hash = proof.original_sha256
	check(journal_files().size() == 1,"killed process left durable pending receipt")
	start_host()
	if not await open_panel(): return
	check(count_turns(panel.conversation,"killed-after-turn") == 1 and journal_files().is_empty(),"real crash recovery deduplicates committed visible result and removes pending receipt")
	replay_count("killed-after-turn")
	preserved("real process crash recovery")

func seed_secret_context(name: String) -> bool:
	if not await start_fixture(name,true): return false
	panel.provider.secrets.append("Canvas")
	check(panel.provider.secrets.size() == 1,"capture process has a process-local redaction secret")
	for index in range(13):
		if not check(panel.remember_turn("assistant","Secret-state warmup %02d" % index),"prepare long conversation before secret-state boundary %02d" % index): return false
	return true

func emit_secret_receipt(label: String) -> void:
	var value := receipt("undo",label)
	value.reason = "Canvas"
	host.shared_workbench.paint_editor.history_action_finished.emit(value)

func secret_pending_proof(label: String) -> Dictionary:
	var files := journal_files()
	if not check(files.size() == 1,"secret-state failure retains exactly one durable receipt"): return {}
	var raw := FileAccess.get_file_as_string(files[0])
	var item: Variant = JSON.parse_string(raw)
	if not check(item is Dictionary and item.get("schema") == 2 and item.get("turn") is Dictionary,
		"secret-state receipt stores its frozen conversation projection"): return {}
	check(not raw.contains("Canvas") and str(item.turn.get("content","")).contains("[redacted]"),
		"pending raw receipt and frozen turn contain captured redaction without original secret")
	check(str(item.turn.content).sha256_text() == str(item.receipt.get("_history_turn_sha256","")) \
		and int(item.receipt.get("_history_world_epoch",-1)) == int(item.epoch),
		"frozen turn is bound to raw receipt digest and captured world epoch")
	var source := saved_path()
	return {"case":scenario,"label":label,"receipt_id":item.id,"journal":files[0],
		"source":source,"source_sha256":FileAccess.get_sha256(source),"original":original,
		"original_sha256":original_hash,"expected_content":item.turn.content,"checks":checks,"failures":failures}

func kill_at_secret_turn() -> void:
	if not panel.provider.last_event_stored: return
	var event := last_traffic()
	if event.get("kind") != "conversation" or not event.get("data") is Dictionary \
			or not str(event.data.get("content","")).contains('"label":"secret-turn"'): return
	var proof := secret_pending_proof("secret-turn")
	if proof.is_empty(): return
	proof.boundary = "secret-turn-committed-before-journal-delete"
	write_text("user://art-durability-crash-boundary.json",JSON.stringify(proof)+"\n")
	print("ART_HISTORY_DURABILITY_CRASH_BOUNDARY ",JSON.stringify(proof))
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline: OS.delay_msec(100)
	check(false,"qualification parent did not terminate secret-state crash-boundary process")

func secret_turn_seed() -> void:
	if not await seed_secret_context("secret-turn"): return
	panel.provider.traffic_changed.connect(kill_at_secret_turn)
	emit_secret_receipt("secret-turn")
	check(false,"parent termination must preserve secret-state journal before cleanup")

func secret_raw_seed() -> void:
	if not await seed_secret_context("secret-raw"): return
	sabotaged = false; sabotage_label = "secret-raw"; sabotage_path = panel.provider.log_path
	panel.provider.traffic_changed.connect(obstruct_after_raw)
	emit_secret_receipt("secret-raw")
	panel.provider.traffic_changed.disconnect(obstruct_after_raw)
	check(sabotaged and count_raw(sabotage_backup,"secret-raw") == 1,
		"secret-state raw receipt committed before real conversation append refusal")
	check(count_turns(panel.conversation,"secret-raw") == 0,"failed secret-state conversation write creates no visible turn")
	var proof := secret_pending_proof("secret-raw")
	if proof.is_empty(): return
	proof.blocked_path = sabotage_path
	proof.backup_path = sabotage_backup
	proof.source_sha256 = FileAccess.get_sha256(sabotage_backup)
	write_text("user://art-durability-secret-raw.json",JSON.stringify(proof)+"\n")
	preserved("secret-state raw append interruption")
	# Keep the obstruction through shutdown so automatic live retry cannot
	# consume a fixture intended for a genuinely independent recovery process.

func secret_recover(turn_was_committed: bool) -> void:
	var manifest_path := "user://art-durability-crash-boundary.json" if turn_was_committed else "user://art-durability-secret-raw.json"
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var label := "secret-turn" if turn_was_committed else "secret-raw"
	if not check(proof is Dictionary and proof.get("case") == label+"-seed" and proof.get("label") == label,
		"independent process loads matching secret-state failure witness"): return
	original = proof.original; original_hash = proof.original_sha256
	var files := journal_files()
	check(files.size() == 1 and journal_receipt_id(files[0]) == str(proof.receipt_id) \
		and Provider.valid_history_receipt_id(str(proof.receipt_id)),
		"independent process sees the original stable secret-state receipt identity")
	if not turn_was_committed: unblock_path(str(proof.blocked_path),str(proof.backup_path))
	check(FileAccess.get_sha256(str(proof.source)) == str(proof.source_sha256),
		"committed archive bytes survive secret-state shutdown boundary")
	start_host()
	panel = host.shared_workbench._ensure_art_batches()
	check(panel.provider.secrets.is_empty(),"independent recovery process has no previous process-local secret")
	panel.show()
	if not await until(func() -> bool: return not panel.provider.resume_active,"secret-state incremental recovery"): return
	check(panel.conversation_loaded and journal_files().is_empty(),"changed secret state recovers and cleans durable receipt")
	check(count_turns(panel.conversation,label) == 1,"changed secret state preserves exactly one visible native result")
	var captured := ""
	for turn: Dictionary in panel.conversation:
		if str(turn.content).contains('"label":"'+label+'"'): captured = str(turn.content)
	check(captured == str(proof.expected_content) and captured.contains("[redacted]") and not captured.contains("Canvas"),
		"recovered turn exactly preserves captured redaction despite absent secret")
	check(panel.last_result == captured,"latest result equals the frozen committed conversation projection")
	panel.context_mode.select(1)
	var context: Array = panel.model_context()
	check(context.size() == 13 and str(context[0].get("content","")).begins_with("Earlier turns omitted") \
		and str(context[0].get("content","")).contains(captured) \
		and not str(context[0].get("content","")).contains("Canvas"),
		"compact model context uses correctly redacted latest result after restart")
	var raw_count := 0
	for segment: Dictionary in panel.provider._validated_segments: raw_count += count_raw(str(segment.path),label)
	if not panel.provider.log_path.is_empty(): raw_count += count_raw(panel.provider.log_path,label)
	check(raw_count == 1,"changed secret state does not duplicate raw history event")
	check(FileAccess.get_sha256(str(proof.source)) == str(proof.source_sha256),
		"secret-state recovery never rewrites the earlier committed archive")
	var reader := Provider.new()
	var turns: Array = reader.resume_traffic(saved_path())
	check(reader.resume_ok and reader.secrets.is_empty() and count_turns(turns,label) == 1,
		"another fresh reader independently confirms exactly one redacted result")
	reader.free()
	preserved("changed process-local secret recovery")

func chmod_fixture(path: String, mode: String) -> bool:
	var output: Array = []
	var result := OS.execute("chmod",PackedStringArray([mode,ProjectSettings.globalize_path(path)]),output,true)
	return check(result == 0,"real POSIX fixture chmod "+mode+" returns success")

func listing_is_refused(path: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null: return true
	var result := directory.list_dir_begin()
	if result == OK: directory.list_dir_end()
	return result != OK

func posix_listing() -> void:
	if not check(OS.get_name() == "Linux","execute-only directory test requires actual Linux POSIX permissions"): return
	if not await start_fixture("posix-archive-listing"): return
	await close_host()
	check(DirAccess.rename_absolute(PROFILE,"user://posix-profile-backup.cfg") == OK,
		"temporarily absent profile retains original bytes for POSIX listing probe")
	if not chmod_fixture("user://art-traffic","111"): return
	check(listing_is_refused("user://art-traffic"),"execute-only archive directory genuinely refuses enumeration")
	var session: Dictionary = ArtPanel.read_history_session()
	check(session.get("state") == "error","unreadable archive listing cannot establish a virgin Art profile")
	start_host()
	emit_receipt("undo","unreadable-archive-listing")
	check(not str(host.shared_workbench.message).is_empty() and host.shared_workbench.art_batches == null,
		"unknown session with inaccessible listing fails visibly without eager Art")
	await close_host()
	chmod_fixture("user://art-traffic","755")
	check(Provider.Archive.atomic_replace("user://posix-profile-backup.cfg",PROFILE).get("ok",false),
		"restore original profile after POSIX archive-listing refusal")
	preserved("POSIX archive-listing refusal")
	if not await start_fixture("posix-journal-listing"): return
	emit_receipt("undo","journal-before-permission-refusal")
	var files := journal_files()
	if not check(files.size() == 1,"stage original durable receipt before journal listing refusal"): return
	var receipt_hash := FileAccess.get_sha256(files[0])
	panel = host.shared_workbench._ensure_art_batches()
	if not chmod_fixture(JOURNAL,"111"): return
	check(listing_is_refused(JOURNAL),"execute-only pending journal genuinely refuses enumeration")
	var pending: Dictionary = panel._read_pending_history_receipts()
	check(not bool(pending.ok),"unreadable pending directory fails closed instead of looking empty")
	emit_receipt("redo","journal-during-permission-refusal")
	check(not panel.input_error.is_empty() and panel.pending_history_receipts.size() == 1 \
		and bool(panel.pending_history_receipts[0].get("volatile",false)),
		"journal enumeration failure retains bounded new receipt with explicit persistence failure")
	check(FileAccess.get_sha256(files[0]) == receipt_hash,"permission refusal preserves original pending receipt bytes")
	panel.show()
	check(not panel.conversation_loaded,"explicit restore cannot silently ignore unreadable pending journal")
	chmod_fixture(JOURNAL,"755")
	panel._ensure_history_loaded()
	if not await until(func() -> bool: return not panel.provider.resume_active,"journal-listing permission recovery"): return
	panel._drain_pending_history_receipts()
	check(panel.conversation_loaded and count_turns(panel.conversation,"journal-before-permission-refusal") == 1 \
		and count_turns(panel.conversation,"journal-during-permission-refusal") == 1 and journal_files().is_empty(),
		"restored directory permissions recover both receipts once without native re-execution")
	preserved("POSIX pending-listing recovery")

func listing_clock_seed() -> void:
	if not check(OS.get_name() == "Linux","clock/listing seed requires actual Linux POSIX permissions"): return
	if not await start_fixture("listing-clock"): return
	ArtPanel._history_receipt_clock_us = int(Time.get_unix_time_from_system()*1000000.0)+600000000
	emit_receipt("undo","listing-older-first")
	var files := journal_files()
	if not check(files.size() == 1,"future-clock capture stages one immutable older receipt"): return
	var item: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(files[0]))
	check(Provider.valid_history_receipt_id(item.get("id")) and item.get("order") is String,
		"older journal records separate stable identity and durable ordering")
	write_text("user://art-durability-listing-clock.json",JSON.stringify({"older_id":item.id,
		"older_order":item.get("order",""),"original":original,"original_sha256":original_hash})+"\n")
	check(host.shared_workbench.art_batches == null,"future-clock capture preserves lazy Art construction")
	preserved("future-clock receipt capture")

func listing_clock_recover() -> void:
	if not check(OS.get_name() == "Linux","clock/listing recovery requires actual Linux POSIX permissions"): return
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://art-durability-listing-clock.json"))
	if not check(proof is Dictionary and Provider.valid_history_receipt_id(proof.get("older_id")),
		"new normal-clock process loads previous future-clock receipt witness"): return
	original = proof.original; original_hash = proof.original_sha256
	if not check(journal_files().size() == 1,"normal-clock process starts with older pending receipt"): return
	if not chmod_fixture(JOURNAL,"300"): return
	check(listing_is_refused(JOURNAL),"write/execute-only journal genuinely refuses enumeration")
	start_host()
	emit_receipt("redo","listing-newer-second")
	var queue: Array = host.shared_workbench._unopened_history_pending
	var newer_id := ""
	var native_digest := ""
	if check(queue.size() == 1 and bool(queue[0].get("volatile",false)),
		"unlistable journal delays new durable ordering in one bounded volatile receipt"):
		newer_id = str(queue[0].id)
		native_digest = JSON.stringify(queue[0].receipt).sha256_text()
		check(Provider.valid_history_receipt_id(newer_id) and newer_id < str(proof.older_id),
			"normal-clock completion has lexically earlier stable ID than older future-clock receipt")
	check(not str(host.shared_workbench.message).is_empty() and host.shared_workbench.art_batches == null,
		"ordering cannot be determined silently or by eagerly constructing Art")
	chmod_fixture(JOURNAL,"755")
	if not await until(func() -> bool: return host.shared_workbench._unopened_history_pending.is_empty(),"unopened receipt retries after directory listing restored"): return
	var ordered_records: Array[Dictionary] = []
	for path: String in journal_files():
		var row: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if row is Dictionary: ordered_records.append(row)
	check(ordered_records.size() == 2 and str(ordered_records[0].id) == str(proof.older_id) \
		and str(ordered_records[1].id) == newer_id \
		and str(ordered_records[1].get("order","")) > str(proof.older_order),
		"durable journal order follows completion chronology despite reversed stable IDs")
	if ordered_records.size() == 2:
		check(JSON.stringify(ordered_records[1].receipt).sha256_text() == native_digest,
			"assigning durable order preserves immutable native receipt and frozen projection binding")
	if not await open_panel(): return
	var actual := []
	for turn: Dictionary in panel.conversation:
		if str(turn.content).contains('"label":"listing-older-first"'): actual.append("older")
		if str(turn.content).contains('"label":"listing-newer-second"'): actual.append("newer")
	check(actual == ["older","newer"] and journal_files().is_empty(),
		"recovered model context contains both completions exactly once in original chronology")
	check(panel.last_result.contains('"label":"listing-newer-second"'),"clock rollback recovery retains the latest result")
	preserved("clock rollback and inaccessible journal recovery")

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	check(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberDemoBridge"),"actual native bindings loaded")
	if scenario == "suite":
		var phases: Array[Callable] = [normal_loaded,archive_failure.bind(false),archive_failure.bind(true),
			profile_failure,cleanup_context,known_profile_outage,unknown_profile_outage,session_isolation,
			invalid_journal,journal_refusal,queued_callback_order.bind(false),queued_callback_order.bind(true),native_history]
		var completed := 0
		for phase: Callable in phases:
			await phase.call()
			completed += 1
			if not failures.is_empty(): break # A red fixture cannot contaminate later evidence.
		check(completed == phases.size(),"all thirteen adversarial scenario families executed")
	elif scenario == "normal-loaded": await normal_loaded()
	elif scenario == "raw-failure": await archive_failure(false)
	elif scenario == "conversation-failure": await archive_failure(true)
	elif scenario == "profile-failure": await profile_failure()
	elif scenario == "cleanup-context": await cleanup_context()
	elif scenario == "known-profile-outage": await known_profile_outage()
	elif scenario == "unknown-profile-outage": await unknown_profile_outage()
	elif scenario == "session-isolation": await session_isolation()
	elif scenario == "invalid-journal": await invalid_journal()
	elif scenario == "journal-refusal": await journal_refusal()
	elif scenario == "queued-unopened": await queued_callback_order(false)
	elif scenario == "queued-loaded": await queued_callback_order(true)
	elif scenario == "native-history": await native_history()
	elif scenario == "restart-seed": await restart_seed()
	elif scenario == "restart-recover": await restart_recover()
	elif scenario == "crash-seed": await crash_seed()
	elif scenario == "crash-recover": await crash_recover()
	elif scenario == "secret-turn-seed": await secret_turn_seed()
	elif scenario == "secret-turn-recover": await secret_recover(true)
	elif scenario == "secret-raw-seed": await secret_raw_seed()
	elif scenario == "secret-raw-recover": await secret_recover(false)
	elif scenario == "posix-listing": await posix_listing()
	elif scenario == "listing-clock-seed": await listing_clock_seed()
	elif scenario == "listing-clock-recover": await listing_clock_recover()
	else: check(false,"unknown adversarial scenario "+scenario)
	await close_host()
	var binary := "cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"
	print("ART_HISTORY_DURABILITY_RESULT ",JSON.stringify({"case":scenario,"checks":checks,"failures":failures,"os":OS.get_name(),"godot":Engine.get_version_info().string,"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/"+binary),"test_sha256":FileAccess.get_sha256("res://tests/test_art_history_durability.gd")}))
	quit(0 if failures.is_empty() else 1)
