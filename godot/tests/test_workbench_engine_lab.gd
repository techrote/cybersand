extends SceneTree

# ENGINE-LAB-001: real Workbench host, real simulation-worker and UI callbacks.
const TIMEOUT_MS: int = 90000
var assertions: int = 0
var failures: Array[String] = []
var host: Control
var menu: Window

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, explanation: String) -> void:
	assertions += 1
	if not ok:
		failures.append(explanation)
		push_error("ENGINE_LAB_001: "+explanation)

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
			menu._widgets.has("render") and menu._widgets.has("ack") and
			menu._widgets.has("pixel") and menu._widgets.has("rapier") and
			menu._widgets.has("workers") and menu._widgets.has("wait_sample") and
			menu._widgets.has("sample_wake"),"all requested controls exist")
		check(host.engine_lab_wait_native_sample and
			host.engine_lab_ack_delay_frames==0 and
			int(host.simulation_worker.engine_lab_pixel_pacing().target_hz)==60,
			"default coupling, ACK, and native tick unchanged")
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
		menu._widgets["ack"].value = 2
		check(host.engine_lab_ack_delay_frames==2,
			"render ACK delay changes live")
		var preview: Dictionary = menu.configuration()
		check(int(preview.pixel_target_hz)==30 and
			not bool(preview.rapier_waits_for_native_sample) and
			int(preview.render_target_hz)==90,
			"configuration readback reflects the actual controls")
		menu.reset_baseline()
		check(Engine.physics_ticks_per_second==60 and
			host.render_snapshot_hz==60 and
			host.engine_lab_ack_delay_frames==0 and
			host.engine_lab_wait_native_sample,
			"reset restores baseline physics, render and sync")
		check(bool(host.simulation_worker.engine_lab_pixel_pacing().sample_wake)
			and int(host.simulation_worker.engine_lab_pixel_pacing().target_hz)==60,
			"reset restores worker wake and Pixel target")
		check(not host.engine_lab_set_scripted_input(true),
			"scripted benchmark cannot seize a paused flyer")
	host.queue_free()
	await process_frame
	await process_frame
	print("ENGINE_LAB_RESULT ",JSON.stringify({"checks":assertions,"failures":failures,
		"runtime":"real Main/Workbench/natively built World",
		"controls":"fps,vsync,render,pixel,rapier,ack,native_sample_gate,native_wake,workers,benchmark"}))
	quit(int(not failures.is_empty()))
