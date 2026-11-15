extends SceneTree

# CAMERA-STACK-RECON-001: real native World, Main, Rapier and upload/ACK path.
# These bounded cohorts establish ordering/progress and honest counters, never
# physical GPU motion smoothness. #609 owns the latter diagnosis and repair.
const Setup = preload("res://scripts/workbench_setup.gd")
const WAIT_MS: int = 45000
var host: Control
var ui: Control
var menu: Window
var checks: int = 0
var failures: Array[String] = []
var evidence: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, reason: String) -> bool:
	checks += 1
	if not ok:
		failures.append(reason)
		push_error("CAMERA_STACK_CLOCKS: "+reason)
	return ok

func wait_for(predicate: Callable, timeout_ms: int = WAIT_MS) -> bool:
	var until: int = Time.get_ticks_msec()+timeout_ms
	while Time.get_ticks_msec()<until:
		if predicate.call(): return true
		if host != null and host.simulation_worker.has_failed(): break
		await process_frame
	return false

func mount() -> bool:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not check(await wait_for(func() -> bool:
		return host.shared_workbench != null and not host.shared_workbench.applied.is_empty()),
		"real Workbench mounted"): return false
	ui = host.shared_workbench
	menu = ui.engine_lab
	return check(ClassDB.class_exists(&"CyberDemoBridge") and host.latest_snapshot.backend_name.begins_with("native"),
		"actual native backend loaded")

func recipe() -> Dictionary:
	var data: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	data.actors = [Setup.instance("kestrel",1,Vector2(250,190))]
	data.selected = 1
	data.next_id = 2
	for x: int in range(32,481,16): data.edits.append([x,420,18,58])
	# Moving native grains publish real texture changes away from the pilot.
	for y: int in range(80,161,16): data.edits.append([85,y,11,2])
	return data

func install() -> bool:
	menu.cancel_benchmark("Fixture replacement")
	if not host.paused: ui.toggle_pause()
	if not await wait_for(func() -> bool: return host.pending_microscenario_apply.is_empty() and not ui.busy()):
		return check(false,"prior fixture retired")
	var epoch: int = host._physical_epoch
	if not check(ui.apply(recipe()),"fresh native/actor fixture admitted: "+ui.message): return false
	return check(await wait_for(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch>epoch \
			and host.physical_actor_session != null and host._physical_terrain_ready \
			and host.latest_snapshot.rigid_body_epoch == host._physical_epoch),
		"source-matched native World and Rapier fixture installed")

func configure(pixel: int, rapier: int, render: int, coupled: bool) -> void:
	menu._widgets["fps"].value = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	menu._widgets["pixel"].value = pixel
	menu._widgets["rapier"].value = rapier
	menu._widgets["render"].value = render
	menu._widgets["wait_sample"].button_pressed = coupled
	menu._widgets["sample_wake"].button_pressed = coupled

func play() -> bool:
	if not check(ui.toggle_pause(),"fixture starts Play"): return false
	return check(await wait_for(func() -> bool:
		return host.physical_actor_session.tick>=2 and host.latest_snapshot.tick_index>=2),
		"actual native and Rapier steps progress before capture")

func cohort(label: String, pixel: int, rapier: int, render: int, coupled: bool, follow: bool) -> void:
	if not await install(): return
	configure(pixel,rapier,render,coupled)
	ui._zoom = 0
	ui._camera.select(1 if follow else 0)
	ui._camera.item_selected.emit(1 if follow else 0)
	if not await play(): return
	var position_before: Vector2 = host.physical_actor_session.workbench_actor_state(1).position
	var camera_before: Vector2 = host.camera_origin
	if not check(menu.start_benchmark(true,2.0),"bounded scripted capture starts"): return
	var epoch: int = host._physical_epoch
	var native_tick: int = host.latest_snapshot.tick_index
	var rapier_tick: int = host.physical_actor_session.tick
	var render_serial: int = host.last_uploaded_render_snapshot_serial
	var uploads: int = host.engine_lab_successful_uploads
	var ordering_ok: bool = true
	var acknowledged_samples: int = 0
	var acknowledgement_advances: int = 0
	var previous_ack: int = render_serial
	var samples: int = 0
	var until: int = Time.get_ticks_msec()+15000
	while menu._capturing and Time.get_ticks_msec()<until:
		await process_frame
		if not follow:
			ui._set_view(host.camera_origin+Vector2(0.125,0.0625),host.current_view_size)
		var snapshot: CyberSimulationSnapshot = host.latest_snapshot
		if snapshot == null: continue
		host.simulation_worker._mutex.lock()
		var ack: int = host.simulation_worker._acknowledged_render_snapshot_serial
		host.simulation_worker._mutex.unlock()
		# Immediate ACK must actually catch up to every successful upload.
		# The separate <= ordering check alone would pass a permanently stale ACK.
		if ack == host.last_uploaded_render_snapshot_serial: acknowledged_samples += 1
		if ack > previous_ack: acknowledgement_advances += 1
		previous_ack = ack
		ordering_ok = ordering_ok and snapshot.tick_index>=native_tick \
			and host.physical_actor_session.tick>=rapier_tick \
			and snapshot.rigid_body_epoch==epoch \
			and host.last_uploaded_render_snapshot_serial>=render_serial \
			and host.engine_lab_successful_uploads>=uploads \
			and ack<=host.last_uploaded_render_snapshot_serial \
			and snapshot.render_tick_index<=snapshot.tick_index \
			and snapshot.render_patch_cells.size()<=512*512*2
		native_tick = snapshot.tick_index
		rapier_tick = host.physical_actor_session.tick
		render_serial = host.last_uploaded_render_snapshot_serial
		uploads = host.engine_lab_successful_uploads
		samples += 1
	if menu._capturing: menu.cancel_benchmark("Cohort watchdog")
	var report: Dictionary = menu.last_report.duplicate(true)
	var position_after: Vector2 = host.physical_actor_session.workbench_actor_state(1).position
	report["case"] = label
	report["camera_mode"] = "Follow" if follow else "Free pan"
	report["actor_displacement_cells"] = position_after.distance_to(position_before)
	report["camera_displacement_cells"] = host.camera_origin.distance_to(camera_before)
	report["ordering_samples"] = samples
	report["ordering_valid"] = ordering_ok
	report["acknowledged_samples"] = acknowledged_samples
	report["acknowledgement_advances"] = acknowledgement_advances
	evidence.append(report)
	check(bool(report.get("valid",false)),label+" capture preserves identity/settings")
	check(ordering_ok and samples>0,label+" monotonic completions, ACK after upload and bounded immutable payload")
	check(acknowledged_samples==samples and acknowledgement_advances>0,
		label+" immediate ACK catches every observed successful upload and advances")
	var counts: Dictionary = report.get("counts",{})
	check(int(counts.get("native_ticks",0))>0 and int(counts.get("rapier_steps",0))>0,
		label+" completed Pixel and Rapier clocks advance")
	check(int(counts.get("successful_uploads",0))>0 and \
		int(counts.get("render_uploaded_serial",-1))>=int(counts.get("successful_uploads",0)),
		label+" real uploads counted separately from serial advancement")
	check(position_after.distance_to(position_before)>0.01 and host.camera_origin.distance_to(camera_before)>0.01,
		label+" real actor and camera move while material publishes")
	check(report.get("snapshot_age",{}).get("available",false) and \
		report.get("displayed_material_age",{}).get("available",false),
		label+" actual snapshot and uploaded-material ages recorded")
	check(not host.engine_lab_scripted_input,label+" completed capture releases scripted lease")
	ui.toggle_pause()

func negative_controls() -> void:
	if not await install(): return
	configure(60,60,60,true)
	if not await play(): return
	check(menu.start_benchmark(true,5.0),"settings-change negative capture starts")
	await process_frame
	menu._widgets["render"].value = 30
	check(await wait_for(func() -> bool: return not menu._capturing,3000),"settings change terminates comparable capture")
	var changed: Dictionary = menu.last_report.duplicate(true)
	evidence.append({"case":"settings-change-negative","report":changed})
	check(not bool(changed.get("valid",true)) and changed.get("native_actual_hz") == null \
		and not host.engine_lab_scripted_input,"settings-change negative retains raw evidence without misleading rates or pilot lease")

	check(menu.start_benchmark(true,5.0),"Stop negative capture starts")
	await process_frame
	menu.cancel_benchmark()
	check(not menu.last_report.valid and not host.engine_lab_scripted_input and not host.engine_lab_measure_callbacks,
		"Stop cancels capture and callback measurement immediately")
	evidence.append({"case":"owner-stop-negative","report":menu.last_report.duplicate(true)})

	check(menu.start_benchmark(true,5.0),"reset negative capture starts")
	var old_session: int = host._engine_lab_scripted_session
	var old_epoch: int = host._engine_lab_scripted_epoch
	var old_actor: int = host._engine_lab_scripted_actor
	var epoch: int = host._physical_epoch
	ui.toggle_pause()
	check(ui.apply(recipe()),"reset admitted while a benchmark is pending")
	check(await wait_for(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch>epoch \
			and host.physical_actor_session != null and not menu._capturing),
		"reset completes and retires old benchmark")
	check(not menu.last_report.valid and not host.engine_lab_scripted_input,
		"replacement invalidates benchmark and releases its old input")
	evidence.append({"case":"replacement-negative","report":menu.last_report.duplicate(true)})
	# Force an outstanding old-session callback through the production controller.
	# Its old actor ID is deliberately reused in the new session.
	var before: Array = host.physical_actor_session._commands.duplicate(true)
	host.engine_lab_scripted_input = true
	host._engine_lab_scripted_session = old_session
	host._engine_lab_scripted_epoch = old_epoch
	host._engine_lab_scripted_actor = old_actor
	host._publish_workbench_keyboard()
	check(not host.engine_lab_scripted_input and host.physical_actor_session._commands==before,
		"stale benchmark callback cannot command or cancel a replacement actor")

func _run() -> void:
	if await mount():
		await cohort("baseline-60-60-60",60,60,60,true,true)
		await cohort("pixel-15-rapier-120-render-15",15,120,15,false,true)
		await cohort("pixel-120-rapier-30-render-60",120,30,60,false,false)
		await negative_controls()
		menu.reset_baseline()
		# The existing 1 Hz owner wait may delay exit by one interval. Bound the
		# actual shutdown, then start a fresh real World to detect leaked ownership.
		host.simulation_worker.set_engine_lab_pixel_pacing(1,false)
		await create_timer(0.1).timeout
		var worker: RefCounted = host.simulation_worker
		var stopped_at: int = Time.get_ticks_usec()
		host.queue_free()
		await process_frame
		await process_frame
		var stop_ms: float = float(Time.get_ticks_usec()-stopped_at)/1000.0
		check(not worker._thread.is_started() and stop_ms<5000.0,"worker stops within bounded 1 Hz shutdown window")
		evidence.append({"case":"shutdown-1hz","elapsed_ms":stop_ms,"thread_stopped":not worker._thread.is_started()})
		host = null
		worker = null
		if await mount():
			check(host.engine_lab_wait_native_sample and not host.engine_lab_scripted_input,
				"fresh host restarts with default wait and no stale scripted lease")
			host.queue_free()
			await process_frame
			await process_frame
	print("CAMERA_STACK_CLOCKS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"runtime":"native World / actual Rapier / Main upload ACK",
		"source_commit":OS.get_environment("CYBERSAND_EVAL_SOURCE_SHA"),
		"runtime_identity":{"os":OS.get_name(),"display_server":DisplayServer.get_name(),
			"godot":Engine.get_version_info().string},
		"physical_gpu_smoothness":"not established","cases":evidence}))
	quit(int(not failures.is_empty()))
