extends SceneTree

# ENGINE-LAB-001: real Workbench host, real simulation-worker and UI callbacks.
const TIMEOUT_MS: int = 90000
const Launcher = preload("res://scripts/feature_launcher.gd")
const WORKER_FILE: String = "user://cybersand-engine-lab-workers.json"
const WORKER_RECEIPT: String = "user://engine-lab-worker-reopen-test.json"
var assertions: int = 0
var failures: Array[String] = []
var host: Control
var menu: Window

func _initialize() -> void:
	if "--worker-request-reopen" in OS.get_cmdline_user_args():
		_worker_reopen.call_deferred()
	else:
		_run.call_deferred()

func check(ok: bool, explanation: String) -> void:
	assertions += 1
	if not ok:
		failures.append(explanation)
		push_error("ENGINE_LAB_001: "+explanation)

func _validate_visible_layout() -> void:
	# Regress the owner's 405-pixel screenshot: the previous HFlow rows
	# collapsed one label to glyph width and stretched its SpinBox to ~700px.
	menu.open()
	await process_frame
	await process_frame
	await process_frame
	check(menu.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED,
		"Engine Lab layout uses physical-pixel scaling")
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web") \
			and DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		check(menu.force_native,
			"graphical Engine Lab runs as an independently sized native window")
	for width: int in [900,760]:
		menu.size = Vector2i(width,650)
		await process_frame
		await process_frame
		for key: String in ["fps","render","pixel","rapier","workers"]:
			var field: SpinBox = menu._widgets[key]
			var row: Control = field.get_parent()
			var title_label: Label = row.get_child(0) as Label
			check(row is HBoxContainer,
				"%s uses a nonwrapping horizontal field row" % key)
			check(title_label != null and
				title_label.autowrap_mode == TextServer.AUTOWRAP_OFF and
				title_label.size.x >= 300.0 and title_label.size.y <= 48.0,
				"%s label remains horizontal at window width %d" % [key,width])
			check(field.size.x >= 145.0 and field.size.y <= 50.0,
				"%s SpinBox is bounded, not full-height" % key)
			check(field.position.x >= title_label.position.x + title_label.size.x - 1.0,
				"%s input follows label without overlap" % key)
			check(field.position.x + field.size.x <= row.size.x + 2.0,
				"%s input fits the content column" % key)
		var vsync: OptionButton = menu._widgets["vsync"]
		check(vsync.get_parent() is HBoxContainer and
			vsync.size.y <= 50.0 and vsync.size.x >= 200.0,
			"VSync selector keeps normal one-row dimensions")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot_path: String = OS.get_environment("CYBERSAND_ENGINE_LAB_SCREENSHOT")
		if not screenshot_path.is_empty():
			var capture: Image = menu.get_texture().get_image()
			if capture != null and not capture.is_empty():
				var result: Error = capture.save_png(screenshot_path)
				check(result == OK,"graphical Engine Lab screenshot saved")
	menu.hide()


func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	var end: int = Time.get_ticks_msec()+TIMEOUT_MS
	while Time.get_ticks_msec()<end:
		if host.shared_workbench != null and not host.shared_workbench.applied.is_empty():
			break
		if host.simulation_worker.has_failed(): break
		await process_frame
	check(host.shared_workbench != null and not host.shared_workbench.applied.is_empty(),
		"real native Workbench installed")
	if host.shared_workbench != null:
		menu = host.shared_workbench.engine_lab
	check(menu != null and menu.has_method("reset_baseline"),
		"second-layer performance menu mounted")
	if menu != null:
		check(menu._widgets.has("fps") and menu._widgets.has("vsync") and
			menu._widgets.has("render") and not menu._widgets.has("ack") and
			menu._widgets.has("pixel") and menu._widgets.has("rapier") and
			menu._widgets.has("workers") and menu._widgets.has("wait_sample") and
			menu._widgets.has("sample_wake"),"all requested controls exist")
		check(host.engine_lab_wait_native_sample and
			int(host.simulation_worker.engine_lab_pixel_pacing().target_hz)==60,
			"default coupling and native tick unchanged; delayed ACK absent")
		menu._widgets["fps"].value = 144
		check(Engine.max_fps==144,"UI changes live render FPS cap")
		menu._widgets["pixel"].value = 30
		check(int(host.simulation_worker.engine_lab_pixel_pacing().target_hz)==30,
			"Pixel tick target reaches worker")
		menu._widgets["sample_wake"].button_pressed = false
		check(not bool(host.simulation_worker.engine_lab_pixel_pacing().sample_wake),
			"native sample wake can be uncoupled")
		menu._widgets["wait_sample"].button_pressed = false
		check(not host.engine_lab_wait_native_sample,
			"Rapier native-sample wait can be uncoupled")
		menu._widgets["rapier"].value = 120
		check(Engine.physics_ticks_per_second==120,
			"Rapier callback target changes live")
		menu._widgets["render"].value = 90
		check(host.render_snapshot_hz==90,
			"render snapshot target changes live")
		var preview: Dictionary = menu.configuration()
		check(preview.render_ack_policy == "mandatory_immediate_after_successful_upload",
			"only immediate upload acknowledgement is admitted")
		check(int(preview.pixel_target_hz)==30 and
			not bool(preview.rapier_waits_for_native_sample) and
			int(preview.render_target_hz)==90,
			"configuration readback reflects the actual controls")
		menu.reset_baseline()
		check(Engine.physics_ticks_per_second==60 and
			host.render_snapshot_hz==60 and
			host.engine_lab_wait_native_sample,
			"reset restores baseline physics, render and sync")
		check(bool(host.simulation_worker.engine_lab_pixel_pacing().sample_wake)
			and int(host.simulation_worker.engine_lab_pixel_pacing().target_hz)==60,
			"reset restores worker wake and Pixel target")
		check(not host.engine_lab_set_scripted_input(true),
			"scripted benchmark cannot seize a paused flyer")
		await _validate_visible_layout()
		await _worker_request_roundtrip()
	host.queue_free()
	await process_frame
	await process_frame
	print("ENGINE_LAB_RESULT ",JSON.stringify({"checks":assertions,"failures":failures,
		"runtime":"real Main/Workbench/natively built World",
		"controls":"fps,vsync,render,pixel,rapier,immediate_ack,native_sample_gate,native_wake,workers,benchmark"}))
	quit(int(not failures.is_empty()))


func _worker_request_roundtrip() -> void:
	for workers: int in [0,1,4,32]:
		check(Launcher.engine_lab_worker_request(JSON.stringify({"native_threads":workers})) == workers,
			"saved whole worker request survives real Godot JSON parsing")
	for invalid: Variant in [-1,33,4.5,"4",true,null]:
		check(Launcher.engine_lab_worker_request(JSON.stringify({"native_threads":invalid})) == -1,
			"invalid worker request is refused without truncation")
	check(Launcher.engine_lab_worker_request("[]") == -1,
		"non-object worker configuration is refused")
	var old_exists: bool = FileAccess.file_exists(WORKER_FILE)
	var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(WORKER_FILE) if old_exists else PackedByteArray()
	if FileAccess.file_exists(WORKER_RECEIPT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WORKER_RECEIPT))
	menu._widgets["workers"].value = 4
	menu._save_workers()
	var pid: int = OS.create_process(OS.get_executable_path(),PackedStringArray([
		"--headless","--path",ProjectSettings.globalize_path("res://"),
		"--script","res://tests/test_workbench_engine_lab.gd","--","--worker-request-reopen"]),false)
	var until: int = Time.get_ticks_msec()+45000
	while pid > 0 and OS.is_process_running(pid) and Time.get_ticks_msec()<until:
		await process_frame
	if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORKER_RECEIPT)) if FileAccess.file_exists(WORKER_RECEIPT) else null
	check(pid > 0 and receipt is Dictionary and bool(receipt.get("valid",false)),
		"fresh Godot process applies saved workers before the native World constructor")
	if old_exists:
		var restore := FileAccess.open(WORKER_FILE,FileAccess.WRITE)
		if restore != null:
			restore.store_buffer(old_bytes)
			restore.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WORKER_FILE))
	if FileAccess.file_exists(WORKER_RECEIPT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WORKER_RECEIPT))

func _worker_reopen() -> void:
	var launcher: Control = load("res://feature_launcher.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	var worker := CyberSimulationWorker.new()
	var request: int = int(ProjectSettings.get_setting("cybersand/native_worker_threads",0))
	var capacity: int = int(worker._world.get_worker_threads()) if worker._world.has_method("get_worker_threads") else -1
	var receipt: Dictionary = {"valid":request==4 and worker._native_worker_request==4 and capacity==4,
		"saved_request":request,"constructor_request":worker._native_worker_request,"native_capacity":capacity}
	var file := FileAccess.open(WORKER_RECEIPT,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(receipt)+"\n")
		file.close()
	worker.stop_worker()
	worker = null
	launcher.queue_free()
	await process_frame
	print("ENGINE_LAB_WORKERS_REOPEN_RESULT ",JSON.stringify(receipt))
	quit(int(not bool(receipt.valid)))
