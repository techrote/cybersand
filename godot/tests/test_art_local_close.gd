extends SceneTree
## ART-LOCAL-CLOSE-744: real Workbench window + HTTPRequest against a keyless
## loopback fixture. Only timing counters and a bounded per-case report leave
## this process; no model output, credentials or historical audit contents.
var host: Control
var panel: Window
var checks := 0
var failures: Array[String] = []
var results: Array[Dictionary] = []
const MAX_CASE_USEC := 12000000


func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_LOCAL_CLOSE_CHECK ",label," ",ok)
	if not ok:
		failures.append(label)
		push_error(label)


func ready() -> bool:
	return host != null and host.shared_workbench != null 		and not host.shared_workbench.applied.is_empty() and not host.shared_workbench.busy() 		and host.shared_workbench.paint_editor != null and not host.shared_workbench.paint_editor.busy()


func wait_ready() -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while not ready() and Time.get_ticks_msec()<deadline:
		await process_frame
	return ready()


func measure_idle_frames(count: int) -> int:
	var largest := 0
	var previous := Time.get_ticks_usec()
	for index: int in range(count):
		await process_frame
		var current := Time.get_ticks_usec()
		largest = maxi(largest,current-previous)
		previous = current
	return largest


func execute_case(label: String, model: String, close_window: bool,
		stop_first: bool = false, inaccessible: bool = false, reopen: bool = false) -> void:
	panel.show()
	await process_frame
	panel.source.select(0)
	if panel.current_provider != "LM Studio": panel.change_provider(0)
	panel.endpoint.text = "http://127.0.0.1:1/v1" if inaccessible else OS.get_environment("WB_ART_CLOSE_ENDPOINT")
	panel.model.text = model
	panel.input_mode.select(1)
	panel.image_input.button_pressed = false
	panel.turn_limit.value = 1
	panel.seconds.value = 3
	panel.input.text = "Return an empty JSON drawing array."
	var before_log := str(panel.provider.log_path)
	var began_usec := Time.get_ticks_usec()
	panel.send_prompt()
	var send_usec := Time.get_ticks_usec() - began_usec
	check(panel.provider.active and panel.remaining_turns == 0,
		label+" started exactly one local request")
	if stop_first:
		panel.stop_all("Local fixture Stop")
	if close_window:
		panel.close_requested.emit()
		check(not panel.visible and panel.last_close_timing.get("hidden",false),
			label+" close signal actually hides Art")
		if not stop_first:
			check(bool(panel.last_close_timing.get("provider_active_before",false)),
				label+" X/Hide does not silently cancel the model request")
	if reopen:
		panel.show()
		check(panel.visible,label+" reopening keeps the existing Art window")
	var previous := Time.get_ticks_usec()
	var largest_gap := 0
	var elapsed_usec := 0
	while elapsed_usec < MAX_CASE_USEC:
		await process_frame
		var now := Time.get_ticks_usec()
		largest_gap = maxi(largest_gap,now-previous)
		previous = now
		elapsed_usec = now-began_usec
		if not panel.provider.active and panel.remaining_turns == 0:
			break
	check(elapsed_usec < MAX_CASE_USEC,label+" completion/cancel remains bounded")
	# Leave a few ordinary frames to expose post-callback visible/hidden stalls.
	var trailing_gap: int = await measure_idle_frames(12)
	largest_gap = maxi(largest_gap,trailing_gap)
	var timing: Dictionary = panel.provider.last_request_timing.duplicate(true)
	check(int(timing.get("serial",-1))>0,label+" keeps request identity without a URL/key")
	if stop_first:
		check(timing.get("status")=="cancelled" and not panel.provider.active,
			label+" Stop fences the old response")
	else:
		check(timing.get("status")=="completed",label+" returns a terminal HTTP receipt")
		if not inaccessible and model != "fixture-valid":
			check(int(timing.get("http_code",0)) == 404 and panel.input_error.contains("HTTP 404"),
				label+" invalid model has explicit HTTP failure")
		if model == "fixture-valid": check(panel.input_error.is_empty() or panel.input_error=="Model finished.",
			label+" valid model response does not enter failure state")
	check(largest_gap < 2500000,label+" no >2.5-second main-thread gap in this hosted fixture")
	var current_log := str(panel.provider.log_path)
	check(not current_log.is_empty() and (before_log.is_empty() or current_log == before_log),
		label+" does not create or switch to a second Art audit")
	var event := {"case":label,"send_usec":send_usec,"close":panel.last_close_timing.duplicate(true) if close_window else {},
		"stop":panel.last_stop_timing.duplicate(true) if stop_first else {},
		"provider":timing,"frame_gap_max_usec":largest_gap,"elapsed_usec":elapsed_usec}
	results.append(event)
	panel.hide()
	await process_frame


func run() -> void:
	root.size = Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	check(not OS.get_environment("WB_ART_CLOSE_ENDPOINT").is_empty(),"test uses a local fixture endpoint")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await wait_ready():
		check(false,"source-matched native Workbench becomes ready")
		finish()
		return
	panel = host.shared_workbench._ensure_art_batches()
	panel.image_input.button_pressed = false
	panel.show()
	await process_frame
	panel.close_requested.emit()
	check(not panel.visible and not panel.provider.active,
		"idle Art close does not issue a model request")
	var idle_close: Dictionary = panel.last_close_timing.duplicate(true)
	var baseline_gap := await measure_idle_frames(35)
	for index: int in range(3):
		await execute_case("404-hidden-%d"%index,"fixture-invalid",true)
	await execute_case("404-open","fixture-invalid",false)
	await execute_case("404-delayed-hidden","fixture-invalid-slow",true)
	await execute_case("404-reopened","fixture-invalid-slow",true,false,false,true)
	await execute_case("stop-before-close","fixture-invalid-slow",true,true)
	await execute_case("unreachable-hidden","fixture-invalid",true,false,true)
	await execute_case("valid-hidden","fixture-valid",true)
	check(DirAccess.get_files_at("user://art-traffic").size() == 1,
		"all scenarios append to exactly one session JSONL")
	check(not panel.provider.active and panel.provider.log_path != "",
		"closing/reopening never leaves a live HTTP owner")
	print("ART_LOCAL_CLOSE_BASELINE ",JSON.stringify({"idle_close":idle_close,"max_frame_gap_usec":baseline_gap}))
	finish()


func finish() -> void:
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await process_frame
	print("ART_LOCAL_CLOSE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"cases":results,"scope":"real-hidden-Art-loopback-no-cloud","display":DisplayServer.get_name()}))
	quit(0 if failures.is_empty() else 1)
