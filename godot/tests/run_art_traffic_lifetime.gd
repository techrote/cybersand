extends SceneTree
## One fresh-process phase for tools/ci/qualify_art_traffic_lifetime.py.
## Only generated fixtures in the harness's isolated user:// are permitted.
const IMAGE_URL := "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMwnnn3PwAFVQKpTzibEAAAAABJRU5ErkJggg=="
var checks := 0
var failures: Array[String] = []
var result: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("ART_LIFETIME " + label)
	return value

func io_snapshot() -> Dictionary:
	var snapshot := {}
	if OS.get_name() == "Linux":
		var file := FileAccess.open("/proc/self/io",FileAccess.READ)
		if file != null:
			while not file.eof_reached():
				var line := file.get_line()
				var parts := line.split(":")
				if parts.size() == 2: snapshot[parts[0]] = int(parts[1].strip_edges())
	return snapshot

func checkpoint() -> void:
	result.checks = checks
	result.failures = failures
	result.io = io_snapshot()
	result.static_memory_peak = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	var path := OS.get_environment("ART_LIFETIME_RECEIPT")
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result,"\t"))
		file.flush()
	print("ART_LIFETIME_PROCESS ",JSON.stringify(result))

func expected_history(panel: Variant, count: int) -> void:
	var expected: Array[String] = ["legacy seed"]
	for i in range(1,count+1): expected.append("fresh process %d"%i)
	var actual: Array[String] = []
	var sources := {}
	for turn: Dictionary in panel.conversation:
		actual.append(str(turn.content))
		var path := str(turn.get("image_log_path",""))
		check(turn.has("image_offset") and not path.is_empty(),"image retains segment and byte offset")
		if turn.has("image_offset"):
			var image_url: String = panel.provider.historical_image(int(turn.image_offset),path)
			check(image_url==IMAGE_URL,"image resolves across historical segment")
			var decoded := Image.new()
			check(decoded.load_png_from_buffer(Marshalls.base64_to_raw(image_url.trim_prefix("data:image/png;base64,")))==OK and decoded.get_size()==Vector2i.ONE,"historical image bytes decode as valid PNG")
		sources[path] = true
	check(actual==expected,"transcript ordering across fresh processes")
	check(sources.size()==expected.size(),"each historical image retains its original segment identity")
	result.contents = actual

func run() -> void:
	var mode := OS.get_environment("ART_LIFETIME_MODE")
	var ordinal := int(OS.get_environment("ART_LIFETIME_ORDINAL"))
	var expected_user := OS.get_environment("ART_LIFETIME_USER_DIR").replace("\\","/").simplify_path()
	var actual_user := OS.get_user_data_dir().replace("\\","/").simplify_path()
	if OS.get_name()=="Windows":
		expected_user = expected_user.to_lower()
		actual_user = actual_user.to_lower()
	if not check(not expected_user.is_empty() and actual_user==expected_user,"controlled test user directory"):
		checkpoint()
		quit(1)
		return
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	result = {"mode":mode,"ordinal":ordinal,"user_directory":OS.get_user_data_dir(),"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"process_pid":OS.get_process_id(),"completed":false}
	checkpoint()
	var start := Time.get_ticks_usec()
	var host: Node = load("res://main.tscn").instantiate()
	root.add_child(host)
	var panel: Variant = host.shared_workbench.art_batches
	for _i in range(3): await process_frame
	result.startup_ms = (Time.get_ticks_usec()-start)/1000.0
	result.startup_io = io_snapshot()
	if mode in ["idle","baseline_idle"]:
		if mode=="idle":
			check(not panel.visible and not panel.conversation_loaded,"idle Workbench keeps Art history deferred")
			check(panel.provider.log_path.is_empty(),"idle Workbench creates no traffic segment")
		else:
			check(not panel.visible,"historical baseline Art remains hidden")
		result.log_path = panel.provider.log_path
	elif mode=="cancel_restore":
		var config_before := FileAccess.get_file_as_string("user://art-provider.cfg")
		panel.show()
		await process_frame
		check(panel.provider.resume_active and not panel.conversation_loaded,"large visible restore is incremental")
		panel.stop_all()
		check(not panel.provider.resume_active and not panel.conversation_loaded,"Stop cancels restore without accepting partial history")
		check(panel.history_load_error.contains("cancelled") and panel.input_error.contains("preserved"),"restore cancellation is explicit")
		check(panel.provider.log_path.is_empty() and FileAccess.get_file_as_string("user://art-provider.cfg")==config_before,"restore cancellation retains committed profile and creates no segment")
		result.resume_error = panel.provider.resume_error
	else:
		start = Time.get_ticks_usec()
		panel.show()
		var previous_frame := Time.get_ticks_usec()
		var frames := 0
		var longest_frame := 0
		var deadline := Time.get_ticks_msec()+600000
		while not panel.conversation_loaded and panel.provider.resume_error.is_empty() and Time.get_ticks_msec()<deadline:
			await process_frame
			var now := Time.get_ticks_usec()
			longest_frame = maxi(longest_frame,now-previous_frame)
			previous_frame = now
			frames += 1
		result.restore_ms = (Time.get_ticks_usec()-start)/1000.0
		result.restore_frames = frames
		result.restore_longest_frame_ms = longest_frame/1000.0
		check(panel.conversation_loaded and panel.provider.resume_ok,"explicit Art open restores a valid conversation")
		result.resume_warning = panel.provider.resume_warning
		expected_history(panel,ordinal-1 if mode in ["continue","crash_write"] else ordinal)
		panel._open_conversation()
		check(panel.conversation_editor.visible and panel.conversation_editor.baseline==panel.conversation and panel.conversation_editor.content.text=="legacy seed","Art history displays restored messages")
		if DisplayServer.get_name()!="headless" and mode=="reopen":
			await process_frame
			await RenderingServer.frame_post_draw
			var frame: Image = panel.conversation_editor.get_texture().get_image()
			var screenshot := OS.get_environment("ART_LIFETIME_RECEIPT").get_basename()+"-history.png"
			check(frame!=null and not frame.is_empty() and frame.save_png(screenshot)==OK,"restored history graphical evidence")
			result.screenshot = screenshot
		panel.conversation_editor.hide()
		if mode in ["continue","crash_write"]:
			var old_path: String = panel.provider.parent_log_path
			check(panel.provider.log_event("request",{"body":{"input":[{"role":"user","content":[{"type":"input_image","image_url":IMAGE_URL}]}]}}),"new request committed")
			panel.remember_turn("user","fresh process %d"%ordinal,panel.provider.last_request_offset)
			check(not panel.provider.log_path.is_empty() and panel.provider.log_path!=old_path,"continuation creates a distinct segment")
			var config := ConfigFile.new()
			check(config.load("user://art-provider.cfg")==OK and config.get_value("session","traffic_path","")==panel.provider.log_path,"latest committed segment persisted")
			expected_history(panel,ordinal)
			result.log_path = panel.provider.log_path
			result.chain = panel.provider.traffic_chain(panel.provider.log_path)
			if mode=="crash_write":
				# Simulate termination after the operating system accepted part of the
				# next JSONL record; committed predecessor bytes remain untouched.
				var interrupted := FileAccess.open(panel.provider.log_path,FileAccess.READ_WRITE)
				interrupted.seek_end()
				interrupted.store_string('{"kind":"conversation","data":')
				interrupted.flush()
				interrupted = null
				result.kill_ready = true
				checkpoint()
				while true: await process_frame
		elif mode in ["export","cancel_export","crash_export"]:
			var destination := OS.get_environment("ART_LIFETIME_EXPORT")
			var begin: int = panel.provider.begin_export(destination)
			check(begin==OK,"explicit export admitted")
			var progress: Dictionary = {}
			if begin==OK:
				progress = panel.provider.poll_export(65536)
				if mode=="cancel_export":
					check(not progress.get("done",false),"export remains incomplete at cancellation")
					panel.provider.cancel_export()
					check(not panel.provider.export_active,"cancel stops incremental export")
				elif mode=="crash_export":
					check(not progress.get("done",false),"export remains incomplete at crash")
					# Hold this deterministic write boundary until the outer process
					# actually kills the engine; the UI must not finish it first.
					panel.set_process(false)
					result.export = progress
					result.kill_ready = true
					checkpoint()
					while true: await process_frame
				else:
					while not progress.get("done",true):
						await process_frame
						progress = panel.provider.poll_export(1048576)
					check(int(progress.get("error",FAILED))==OK,"complete export committed")
			result.export = progress
			result.chain = panel.provider.traffic_chain(panel.provider.log_path if not panel.provider.log_path.is_empty() else panel.provider.parent_log_path)
		elif mode=="cancel_continue":
			var endpoint := OS.get_environment("ART_LIFETIME_ENDPOINT")
			check(endpoint.begins_with("http://127.0.0.1:"),"only local fixture endpoint is permitted")
			var error: String = panel.provider.send("LM Studio",endpoint,"slow","","continuation cancellation","test",4096,5)
			check(error.is_empty() and panel.provider.active,"continuation HTTP request started")
			var received := OS.get_environment("ART_LIFETIME_REQUEST_RECEIVED")
			var receive_deadline := Time.get_ticks_msec()+5000
			while not FileAccess.file_exists(received) and panel.provider.active and Time.get_ticks_msec()<receive_deadline:
				await process_frame
			check(FileAccess.file_exists(received) and panel.provider.active,"delayed loopback server received active continuation before Stop")
			result.request_received = FileAccess.file_exists(received)
			panel.stop_all()
			for _i in range(3): await process_frame
			check(not panel.provider.active,"Stop cancels active continuation")
			result.log_path = panel.provider.log_path
			result.chain = panel.provider.traffic_chain(panel.provider.log_path)
	panel.hide()
	host.queue_free()
	for _i in range(3): await process_frame
	result.completed = true
	checkpoint()
	quit(0 if failures.is_empty() else 1)
