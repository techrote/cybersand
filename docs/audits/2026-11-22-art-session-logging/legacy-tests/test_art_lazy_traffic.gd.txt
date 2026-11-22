extends SceneTree
## Regression: starting Workbench must not read/copy saved Art traffic.
## Reopening creates only small linked JSONL segments; historical images/export survive.
const Provider = preload("res://scripts/art_provider.gd")

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

func size_of(path: String) -> int:
	var file := FileAccess.open(path,FileAccess.READ)
	return file.get_length() if file != null else -1

func traffic_files() -> PackedStringArray:
	var files := DirAccess.get_files_at("user://art-traffic")
	files.sort()
	return files

func wait_history(panel: Window) -> void:
	var deadline := Time.get_ticks_msec()+120000
	while not panel.conversation_loaded and panel.provider.resume_error.is_empty() and Time.get_ticks_msec()<deadline:
		await process_frame

func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	var cfg_path := "user://art-provider.cfg"
	var had_cfg := FileAccess.file_exists(cfg_path)
	var saved_cfg := FileAccess.get_file_as_bytes(cfg_path) if had_cfg else PackedByteArray()
	var suffix := str(Time.get_ticks_usec())
	var base := "user://art-traffic/lazy-history-"+suffix
	var old_path := base+"-old.jsonl"
	var export_path := base+"-export.jsonl"
	var child_path := ""
	check(DirAccess.make_dir_recursive_absolute("user://art-traffic") == OK,"fixture traffic directory")
	var original := FileAccess.open(old_path,FileAccess.WRITE)
	check(original != null,"fixture created")
	if original == null:
		quit(1)
		return
	var image_url := "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMwnnn3PwAFVQKpTzibEAAAAABJRU5ErkJggg=="
	original.store_line(JSON.stringify({"kind":"request","data":{"body":{"input":[{"role":"user","content":[{"type":"input_image","image_url":image_url}]}]}}}))
	original.store_line(JSON.stringify({"kind":"conversation","data":{"role":"user","content":"previous canvas request","image_offset":0}}))
	original.store_line(JSON.stringify({"kind":"response","data":{"body":"X".repeat(2*1024*1024)}}))
	original.flush()
	original = null
	var source_size := size_of(old_path)
	var config := ConfigFile.new()
	config.load(cfg_path)
	config.set_value("session","traffic_path",old_path)
	check(config.save(cfg_path) == OK,"existing session configured")
	var initial_files := traffic_files()

	var host: Node = load("res://main.tscn").instantiate()
	root.add_child(host)
	check(host.shared_workbench.art_batches == null and traffic_files() == initial_files and size_of(old_path) == source_size,
		"startup leaves Art unconstructed and never copies traffic")
	# Explicitly construct a hidden panel to separately check that construction
	# alone does not read or duplicate a saved conversation.
	var panel: Window = host.shared_workbench._ensure_art_batches()
	for _i in range(3): await process_frame
	check(not panel.visible and not panel.conversation_loaded,"Workbench starts with Art hidden and transcript deferred")
	check(panel.provider.log_path.is_empty() and panel.provider.parent_log_path == old_path,"startup remembers old session without opening a new log")
	check(traffic_files() == initial_files and size_of(old_path) == source_size,"startup does not copy even a large saved traffic archive")

	panel.show()
	await wait_history(panel)
	check(panel.conversation_loaded and panel.conversation.size() == 1,"intentional Art open restores previous conversation")
	check(panel.conversation[0].get("image_log_path","") == old_path,"legacy image offsets gain original segment identity")
	check(panel.provider.historical_image(0,old_path) == image_url,"historical image remains readable without copying")
	check(traffic_files() == initial_files and size_of(old_path) == source_size,"reading history does not duplicate or alter old traffic")

	panel.remember_turn("assistant","new reply")
	child_path = panel.provider.log_path
	check(not child_path.is_empty() and child_path != old_path and FileAccess.file_exists(child_path),"first event creates a distinct new session segment")
	check(size_of(old_path) == source_size and size_of(child_path) < 16384,"child is small and original archive remains unchanged")
	var chain: Array[String] = panel.provider.traffic_chain(child_path)
	check(chain.size() == 2 and chain[0] == old_path and chain[1] == child_path,"segment links resolve from oldest to newest")

	var replay := Provider.new()
	root.add_child(replay)
	var restored: Array = replay.resume_traffic(child_path)
	check(restored == panel.conversation and replay.log_path.is_empty(),"replay restores transcript without creating another file")
	check(replay.parent_log_path == child_path and replay.historical_image(0,old_path) == image_url,"read-only replay retains the historical source")
	replay.queue_free()
	check(panel.provider.export_traffic(export_path) == OK,"explicit full-session export succeeds")
	check(size_of(export_path) == source_size + size_of(child_path),"explicit export concatenates all archived and new bytes exactly")
	check(size_of(old_path) == source_size,"export does not mutate the historical source")

	panel.hide()
	host.queue_free()
	await process_frame
	await process_frame
	var before_relaunch := traffic_files()
	var host2: Node = load("res://main.tscn").instantiate()
	root.add_child(host2)
	check(host2.shared_workbench.art_batches == null and traffic_files() == before_relaunch,
		"relaunch keeps the linked conversation unopened and Art unconstructed")
	var panel2: Window = host2.shared_workbench._ensure_art_batches()
	for _i in range(3): await process_frame
	check(not panel2.conversation_loaded and traffic_files() == before_relaunch,"relaunch does not copy the new linked conversation")
	panel2.show()
	await wait_history(panel2)
	check(panel2.conversation == restored and panel2.provider.log_path.is_empty(),"multi-segment transcript survives a Workbench restart")
	check(traffic_files() == before_relaunch,"reopen is read-only until a user action")
	host2.queue_free()
	await process_frame
	await process_frame

	var restore := FileAccess.open(cfg_path,FileAccess.WRITE) if had_cfg else null
	if restore != null:
		restore.store_buffer(saved_cfg)
		restore.flush()
	restore = null
	if not had_cfg: DirAccess.remove_absolute(cfg_path)
	for path: String in [export_path,child_path,old_path]:
		if not path.is_empty(): DirAccess.remove_absolute(path)
	print("ART_LAZY_TRAFFIC ",JSON.stringify({"checks":checks,"failures":failures,"original_bytes":source_size,"display":DisplayServer.get_name()}))
	quit(0 if failures.is_empty() else 1)
