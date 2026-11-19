extends Window

# ENGINE-LAB-001: second-layer Workbench controls; no modal warnings.
# Only the explicitly saved native worker request persists between launches.
const WORKER_PATH: String = "user://cybersand-engine-lab-workers.json"
const BENCH_SECONDS: float = 10.0

var host: Control
var workbench: Control
var _widgets: Dictionary = {}
var _syncing: bool = false
var _status: Label
var _output: TextEdit
var _capturing: bool = false
var _trace_running: bool = false
var _trace_scripted: bool = false
var _test_it_process_pid: int = -1
var _default_fps: int = 0
var _default_vsync: int = 1
var _default_rapier_hz: int = 60

# Short field labels must retain a horizontal minimum width. The original
# HFlowContainer let the label shrink to one glyph and then expanded its
# SpinBox to the label's many-line height (Owner Windows screenshot).
func _label(parent: Control, caption: String) -> Label:
	var item := Label.new()
	item.text = caption
	item.autowrap_mode = TextServer.AUTOWRAP_OFF
	item.clip_text = true
	item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(item)
	return item

# Explanatory prose is allowed to wrap, but only inside the full-width column.
func _note(parent: Control, caption: String) -> Label:
	var item := Label.new()
	item.text = caption
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(item)
	return item

func _row(parent: Control) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.custom_minimum_size.y = 36
	result.add_theme_constant_override("separation",12)
	parent.add_child(result)
	return result

func _spin(parent: Control, key: String, title_text: String,
		low: int, high: int, initial: int, callback: Callable) -> SpinBox:
	var line: HBoxContainer = _row(parent)
	var caption := _label(line,title_text)
	caption.custom_minimum_size.x = 390
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var field := SpinBox.new()
	field.min_value = float(low)
	field.max_value = float(high)
	field.step = 1
	field.value = float(initial)
	field.custom_minimum_size = Vector2(155,32)
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.size_flags_horizontal = Control.SIZE_SHRINK_END
	line.add_child(field)
	field.value_changed.connect(func(value: float) -> void:
		if not _syncing: callback.call(int(value)))
	_widgets[key] = field
	return field

func _check(parent: Control,key: String,title_text: String,
		initial: bool,callback: Callable) -> CheckButton:
	var field := CheckButton.new()
	field.text = title_text
	field.custom_minimum_size.y = 34
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.button_pressed = initial
	field.toggled.connect(func(value: bool) -> void:
		if not _syncing: callback.call(value))
	parent.add_child(field)
	_widgets[key] = field
	return field

func _button(parent: Control,caption: String,callback: Callable) -> Button:
	var item := Button.new()
	item.text = caption
	item.custom_minimum_size.y = 32
	item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func _section(parent: Control,caption: String) -> void:
	parent.add_child(HSeparator.new())
	var heading := _label(parent,caption)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func mount(controller: Control,wb: Control) -> void:
	# In case callers mount an existing window, hide before force_native.
	hide()
	host = controller
	workbench = wb
	title = "CyberSand / Engine Lab / performance experiments"
	size = Vector2i(900,730)
	min_size = Vector2i(740,520)
	transient = true
	# The game viewport uses canvas_items scaling. A separate native Window
	# needs physical-pixel layout, not a compressed copy of the game canvas.
	force_native = not OS.has_feature("web") and DisplayServer.get_name() != "headless" \
		and DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS)
	content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	handle_input_locally = true
	hide()
	close_requested.connect(hide)
	_default_fps = Engine.max_fps
	_default_vsync = DisplayServer.window_get_vsync_mode()
	_default_rapier_hz = Engine.physics_ticks_per_second

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,12)
	add_child(margin)
	var full := VBoxContainer.new()
	full.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(full)
	_note(full,"ENGINE LAB · Live changes, current session · nonproduction experiment")
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	full.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.custom_minimum_size.x = 650
	scroll.add_child(controls)

	_section(controls,"DISPLAY / RENDER")
	_spin(controls,"fps","Frame-rate cap (0 = uncapped)",0,240,Engine.max_fps,
		func(value: int) -> void: Engine.max_fps = value)
	var sync_row: HBoxContainer = _row(controls)
	var sync_label := _label(sync_row,"VSync mode")
	sync_label.custom_minimum_size.x = 390
	sync_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vsync := OptionButton.new()
	vsync.custom_minimum_size = Vector2(220,32)
	vsync.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vsync.size_flags_horizontal = Control.SIZE_SHRINK_END
	vsync.add_item("Disabled",DisplayServer.VSYNC_DISABLED)
	vsync.add_item("Enabled",DisplayServer.VSYNC_ENABLED)
	vsync.add_item("Adaptive",DisplayServer.VSYNC_ADAPTIVE)
	vsync.tooltip_text = "Adaptive VSync may fall back to enabled depending on graphics driver."
	vsync.select(_default_vsync if _default_vsync >= 0 and _default_vsync <= 2 else 1)
	vsync.item_selected.connect(func(index: int) -> void:
		if not _syncing: DisplayServer.window_set_vsync_mode(vsync.get_item_id(index)))
	sync_row.add_child(vsync)
	_widgets["vsync"] = vsync
	_spin(controls,"render","Material snapshot publication target (Hz)",
		1,240,host.render_snapshot_hz,
		func(value: int) -> void: host.engine_lab_set_render_hz(value))
	_spin(controls,"ack","Render ACK delay (frame callbacks; 0 = immediate)",
		0,4,host.engine_lab_ack_delay_frames,
		func(value: int) -> void: host.engine_lab_set_ack_delay(value))
	_note(controls,"ACK remains mandatory after upload; changing its delay alters back-pressure.")

	_section(controls,"PIXEL / RAPIER CLOCKS")
	_spin(controls,"pixel","Native Pixel target tick cadence (Hz)",
		1,240,60,func(value: int) -> void:
			host.simulation_worker.set_engine_lab_pixel_pacing(
				value,(_widgets["sample_wake"] as CheckButton).button_pressed))
	_spin(controls,"rapier","Rapier callback cadence (Hz)",
		1,240,Engine.physics_ticks_per_second,
		func(value: int) -> void: host.engine_lab_set_rapier_hz(value))
	_note(controls,"Each simulation/flight step retains fixed 1/60 seconds. Non-60 cadence changes wall-clock simulation speed.")
	_check(controls,"wait_sample","Rapier waits for native sample completion (default)",
		host.engine_lab_wait_native_sample,func(value: bool) -> void: host.engine_lab_wait_native_sample = value)
	_check(controls,"sample_wake","Native worker wakes early on a new Rapier sample (default)",
		bool(host.simulation_worker.engine_lab_pixel_pacing().sample_wake),func(value: bool) -> void:
			host.simulation_worker.set_engine_lab_pixel_pacing(
				int((_widgets["pixel"] as SpinBox).value),value))
	_note(controls,"Uncheck both for independent clocks. Stale responses and uninstalled terrain remain refused; asynchronous material contact needs separate qualification.")

	_section(controls,"NATIVE WORKER TOPOLOGY (NEXT LAUNCH)")
	var saved: int = int(ProjectSettings.get_setting("cybersand/native_worker_threads",0))
	if FileAccess.file_exists(WORKER_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORKER_PATH))
		if parsed is Dictionary:
			saved = clampi(int(parsed.get("native_threads",saved)),0,32)
	_spin(controls,"workers","Native worker count (0 = automatic)",
		0,16,saved,func(_value: int) -> void: pass)
	_button(controls,"Save worker request for next launch",_save_workers)

	_section(controls,"OVERRIDES / QUICK PRESETS")
	_check(controls,"advanced","Advanced override — unlock up to 1000 Hz and 32 workers",
		false,func(value: bool) -> void:
			for key: String in ["fps","render","pixel","rapier"]:
				(_widgets[key] as SpinBox).max_value = 1000 if value else 240
			(_widgets["workers"] as SpinBox).max_value = 32 if value else 16)
	var actions: HBoxContainer = _row(controls)
	_button(actions,"Restore baseline",reset_baseline)
	_button(actions,"Uncouple Pixel + Rapier",func() -> void:
		_set_toggle("wait_sample",false)
		_set_toggle("sample_wake",false)
		host.engine_lab_wait_native_sample = false
		host.simulation_worker.set_engine_lab_pixel_pacing(
			int((_widgets["pixel"] as SpinBox).value),false))
	_button(actions,"Unlock FPS",func() -> void:
		_set_spin("fps",0)
		(_widgets["vsync"] as OptionButton).select(0)
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED))

	_section(controls,"10-SECOND REAL CLOCK / FLIGHT BENCHMARK")
	_note(controls,"Capture actual completed native ticks, Rapier steps, render uploads, process frames, guard vetoes, and elapsed wall time.")
	var tests: HBoxContainer = _row(controls)
	_button(tests,"Measure while I fly",func() -> void: start_benchmark(false))
	_button(tests,"Repeatable four-direction input",func() -> void: start_benchmark(true))
	_note(controls,"Scripted pilot: +X, -Y, -X, +Y, switching every 60 completed Rapier steps; same input sequence at every setting.")
	_section(controls,"ACTUAL RENDERED-FRAME POSE TRACE (10 SECONDS)")
	_note(controls,"Compare live/bound/drawn Rapier poses with requested and pixel-snapped camera offsets, guard reasons and framebuffer projection. Opt-in; no disk writes during flight.")
	var pose_trace_buttons: HBoxContainer = _row(controls)
	_button(pose_trace_buttons,"Trace poses: manual",func() -> void: start_pose_trace(false))
	_button(pose_trace_buttons,"Trace poses: scripted",func() -> void: start_pose_trace(true))
	_button(pose_trace_buttons,"Stop trace",finish_pose_trace)
	_button(controls,"TEST IT → ZIP (automated 2048 Needle / Free & Follow A/B)",launch_test_it)
	_note(controls,"Writes JSON Lines to the local Godot user-data directory. Captures each Main overlay frame, up to the explicit 12,000-frame buffer; dropped frames are counted.")
	_output = TextEdit.new()
	_output.editable = false
	_output.custom_minimum_size.y = 105
	_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(_output)
	_status = _note(full,"Ready.")
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)
	_refresh()

func _set_spin(key: String,value: int) -> void:
	_syncing = true
	(_widgets[key] as SpinBox).value = value
	_syncing = false

func _set_toggle(key: String,value: bool) -> void:
	_syncing = true
	(_widgets[key] as CheckButton).button_pressed = value
	_syncing = false

func _save_workers() -> void:
	var file: FileAccess = FileAccess.open(WORKER_PATH,FileAccess.WRITE)
	if file == null:
		_status.text = "Could not save worker setting."
		return
	file.store_string(JSON.stringify({"native_threads":int((_widgets["workers"] as SpinBox).value)})+"\n")
	file.close()
	_status.text = "Native workers saved. Close and relaunch the Workbench to apply."

func reset_baseline() -> void:
	_set_spin("fps",_default_fps)
	_set_spin("render",60)
	_set_spin("pixel",60)
	_set_spin("rapier",_default_rapier_hz)
	_set_spin("ack",0)
	_set_toggle("wait_sample",true)
	_set_toggle("sample_wake",true)
	Engine.max_fps = _default_fps
	DisplayServer.window_set_vsync_mode(_default_vsync)
	(_widgets["vsync"] as OptionButton).select(
		_default_vsync if _default_vsync >= 0 and _default_vsync <= 2 else 1)
	host.engine_lab_set_render_hz(60)
	host.engine_lab_set_rapier_hz(_default_rapier_hz)
	host.engine_lab_set_ack_delay(0)
	host.engine_lab_wait_native_sample = true
	host.simulation_worker.set_engine_lab_pixel_pacing(60,true)
	_status.text = "Baseline rates, coupling and ACK restored. Saved worker setting unchanged."

func open() -> void:
	popup_centered_clamped(Vector2i(900,730),0.95)
	_refresh()

func _sample() -> Dictionary:
	return {"time_usec":Time.get_ticks_usec(),
		"process_frames":Engine.get_process_frames(),
		"physics_frames":Engine.get_physics_frames(),
		"native_ticks":int(host.latest_snapshot.tick_index) if host.latest_snapshot != null else -1,
		"rapier_steps":host.physical_actor_session.tick if host.physical_actor_session != null else -1,
		"render_uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"guard":host.workbench_presentation_totals.duplicate(true),
		"fps_now":Engine.get_frames_per_second(),
		"frame_time_ms":host.frame_time_ms}

func configuration() -> Dictionary:
	var pacing: Dictionary = host.simulation_worker.engine_lab_pixel_pacing()
	return {"fps_cap":Engine.max_fps,"vsync":int(DisplayServer.window_get_vsync_mode()),
		"rapier_target_hz":Engine.physics_ticks_per_second,
		"pixel_target_hz":pacing.target_hz,"native_wake_on_sample":pacing.sample_wake,
		"render_target_hz":host.render_snapshot_hz,
		"render_ack_delay_frames":host.engine_lab_ack_delay_frames,
		"rapier_waits_for_native_sample":host.engine_lab_wait_native_sample,
		"native_workers_current_request":int(ProjectSettings.get_setting("cybersand/native_worker_threads",0)),
		"native_workers_next_launch":int((_widgets["workers"] as SpinBox).value)}

func start_benchmark(scripted: bool) -> void:
	if _capturing: return
	if workbench.applied.is_empty() or host.paused:
		_status.text = "Start Play before capturing an active session."
		return
	if scripted and not host.engine_lab_set_scripted_input(true):
		_status.text = "Select a human-controlled flyer and start Play."
		return
	_capturing = true
	_status.text = "Recording ten seconds..."
	var before: Dictionary = _sample()
	var settings: Dictionary = configuration()
	await get_tree().create_timer(BENCH_SECONDS).timeout
	if scripted: host.engine_lab_set_scripted_input(false)
	var after: Dictionary = _sample()
	var elapsed: float = maxf(0.001,
		float(int(after.time_usec)-int(before.time_usec))/1000000.0)
	var counts: Dictionary = {}
	for key: String in ["process_frames","physics_frames","native_ticks",
			"rapier_steps","render_uploaded_serial"]:
		counts[key] = int(after[key])-int(before[key])
	var guard: Dictionary = {}
	for key: String in after.guard:
		guard[key] = int(after.guard[key])-int(before.guard.get(key,0))
	var report: Dictionary = {"schema":"engine-lab-001-actual-clock-v1",
		"input_mode":"four_direction_60_steps_per_leg" if scripted else "manual",
		"elapsed_seconds":elapsed,"settings":settings,
		"before":before,"after":after,"counts":counts,"guard_delta":guard,
		"render_callback_fps":float(counts.process_frames)/elapsed,
		"native_actual_hz":float(counts.native_ticks)/elapsed,
		"rapier_actual_hz":float(counts.rapier_steps)/elapsed}
	var stamp: String = Time.get_datetime_string_from_system().replace(":","-")
	var filename: String = "user://engine-lab-"+stamp+("-scripted" if scripted else "-manual")+".json"
	var file: FileAccess = FileAccess.open(filename,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"  ")+"\n")
		file.close()
	_output.text = JSON.stringify({"settings":settings,"mode":report.input_mode,
		"elapsed":elapsed,"render_fps":report.render_callback_fps,
		"native_hz":report.native_actual_hz,"rapier_hz":report.rapier_actual_hz,
		"guard":guard},"  ")
	_status.text = "Saved "+ProjectSettings.globalize_path(filename) if file != null else "Capture completed, file could not be saved"
	_capturing = false

# Launch a fresh-proc deterministic suite. This is deliberately separate from
# the existing authored World, uses bundled Godot and one local ZIP, and does
# not silently install tools or upload anything. Duplicate clicks are refused.
func launch_test_it() -> void:
	if OS.get_name() != "Windows":
		_status.text = "Test It executable is Windows-only. Use the native CI fixture on other hosts."
		return
	if _test_it_process_pid > 0 and OS.is_process_running(_test_it_process_pid):
		_status.text = "Test It is already running as process %d." % _test_it_process_pid
		return
	var test_file: String = ProjectSettings.globalize_path("res://../Run-Test-It.ps1")
	if not FileAccess.file_exists(test_file):
		_status.text = "Missing packaged Run-Test-It.ps1; extract the complete current ZIP."
		return
	var process: int = OS.create_process("powershell.exe",
		PackedStringArray(["-NoProfile","-ExecutionPolicy","Bypass","-File",test_file,"-Coherence"]),true)
	if process <= 0:
		_status.text = "Failed to start Test It PowerShell process; run Test It.cmd instead."
		return
	_test_it_process_pid = process
	_status.text = ("Test It started in separate process %d. Results: Test-It-Results/*.zip. "+
		"Close or pause this Workbench to avoid sharing GPU load.") % process


func start_pose_trace(scripted: bool) -> void:
	if _capturing: return
	if workbench.applied.is_empty() or host.paused:
		_status.text = "Start Play before tracing the Workbench presentation."
		return
	if scripted and not host.engine_lab_set_scripted_input(true):
		_status.text = "Select a human-controlled flyer and start Play before scripted tracing."
		return
	if not host.begin_workbench_pose_trace(configuration()):
		if scripted: host.engine_lab_set_scripted_input(false)
		_status.text = "Pose trace unavailable; install a physical Workbench session."
		return
	_trace_running = true
	_trace_scripted = scripted
	_capturing = true
	_status.text = "Pose trace active: every displayed overlay frame, up to 10 seconds."
	await get_tree().create_timer(BENCH_SECONDS).timeout
	if _trace_running: finish_pose_trace()


func finish_pose_trace() -> void:
	if not _trace_running: return
	_trace_running = false
	if _trace_scripted: host.engine_lab_set_scripted_input(false)
	_trace_scripted = false
	_capturing = false
	var report: Dictionary = host.finish_workbench_pose_trace()
	_output.text = JSON.stringify(report,"  ")
	_status.text = ("Pose trace saved: "+str(report.get("path","")) +
		" | frames "+str(report.get("frames",0)) +
		" | dropped "+str(report.get("dropped",0))) \
		if report.get("status","")=="saved" else "Pose trace failed: "+JSON.stringify(report)


func _refresh() -> void:
	if host == null or _status == null or _capturing: return
	var state: Dictionary = _sample()
	var pace: Dictionary = host.simulation_worker.engine_lab_pixel_pacing()
	_status.text = "FPS %.0f  |  native tick %d  |  Rapier step %d  |  render serial %d  |  Pixel target %dHz  |  guard vetoes %d" % [
		float(state.fps_now),int(state.native_ticks),int(state.rapier_steps),
		int(state.render_uploaded_serial),int(pace.target_hz),
		int(state.guard.get("budget_vetoes",0))]
	var timing: Dictionary = host.workbench_presentation_frame.get("material_timing",{})
	if not timing.is_empty():
		var material_age: int = int(timing.get("material_age_usec",-1))
		var upload_interval: int = int(timing.get("upload_interval_usec",-1))
		_status.text += "\nMaterial age %s  |  blend %.1f ms  |  measured upload interval %s" % [
			"%.1f ms" % (float(material_age)/1000.0) if material_age>=0 else "unknown",
			float(timing.get("blend_duration_usec",0))/1000.0,
			"%.1f ms" % (float(upload_interval)/1000.0) if upload_interval>0 else "unknown"]
