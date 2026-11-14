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
var _default_fps: int = 0
var _default_vsync: int = 1
var _default_rapier_hz: int = 60

func _label(parent: Control, caption: String) -> Label:
	var item := Label.new()
	item.text = caption
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func _row(parent: Control) -> HFlowContainer:
	var result := HFlowContainer.new()
	result.add_theme_constant_override("h_separation",10)
	result.add_theme_constant_override("v_separation",3)
	parent.add_child(result)
	return result

func _spin(parent: Control, key: String, title_text: String,
		low: int, high: int, initial: int, callback: Callable) -> SpinBox:
	var line: HFlowContainer = _row(parent)
	_label(line,title_text)
	var field := SpinBox.new()
	field.min_value = float(low)
	field.max_value = float(high)
	field.step = 1
	field.value = float(initial)
	field.custom_minimum_size.x = 110
	line.add_child(field)
	field.value_changed.connect(func(value: float) -> void:
		if not _syncing: callback.call(int(value)))
	_widgets[key] = field
	return field

func _check(parent: Control,key: String,title_text: String,
		initial: bool,callback: Callable) -> CheckButton:
	var field := CheckButton.new()
	field.text = title_text
	field.button_pressed = initial
	field.toggled.connect(func(value: bool) -> void:
		if not _syncing: callback.call(value))
	parent.add_child(field)
	_widgets[key] = field
	return field

func _button(parent: Control,caption: String,callback: Callable) -> Button:
	var item := Button.new()
	item.text = caption
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func _section(parent: Control,caption: String) -> void:
	parent.add_child(HSeparator.new())
	_label(parent,caption)

func mount(controller: Control,wb: Control) -> void:
	host = controller
	workbench = wb
	title = "CyberSand / Engine Lab / performance experiments"
	size = Vector2i(770,690)
	min_size = Vector2i(510,400)
	transient = true
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
	margin.add_child(full)
	_label(full,"ENGINE LAB · Live changes, current session · nonproduction experiment")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	full.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(controls)

	_section(controls,"DISPLAY / RENDER")
	_spin(controls,"fps","Frame-rate cap (0 = uncapped)",0,240,Engine.max_fps,
		func(value: int) -> void: Engine.max_fps = value)
	var sync_row: HFlowContainer = _row(controls)
	_label(sync_row,"VSync mode")
	var vsync := OptionButton.new()
	vsync.add_item("Disabled",DisplayServer.VSYNC_DISABLED)
	vsync.add_item("Enabled",DisplayServer.VSYNC_ENABLED)
	vsync.add_item("Adaptive (may fall back to Enabled)",DisplayServer.VSYNC_ADAPTIVE)
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
	_label(controls,"ACK remains mandatory after upload; changing its delay alters back-pressure.")

	_section(controls,"PIXEL / RAPIER CLOCKS")
	_spin(controls,"pixel","Native Pixel target tick cadence (Hz)",
		1,240,60,func(value: int) -> void:
			host.simulation_worker.set_engine_lab_pixel_pacing(
				value,(_widgets["sample_wake"] as CheckButton).button_pressed))
	_spin(controls,"rapier","Rapier callback cadence (Hz)",
		1,240,Engine.physics_ticks_per_second,
		func(value: int) -> void: host.engine_lab_set_rapier_hz(value))
	_label(controls,"Each simulation/flight step retains fixed 1/60 seconds. Non-60 cadence changes wall-clock simulation speed.")
	_check(controls,"wait_sample","Rapier waits for native sample completion (default)",
		true,func(value: bool) -> void: host.engine_lab_wait_native_sample = value)
	_check(controls,"sample_wake","Native worker wakes early on a new Rapier sample (default)",
		true,func(value: bool) -> void:
			host.simulation_worker.set_engine_lab_pixel_pacing(
				int((_widgets["pixel"] as SpinBox).value),value))
	_label(controls,"Uncheck both to let the clocks run most independently; native World and terrain safety remain authoritative.")

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
	var actions: HFlowContainer = _row(controls)
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
	_label(controls,"Capture actual completed native ticks, Rapier steps, render uploads, process frames, guard vetoes, and elapsed wall time.")
	var tests: HFlowContainer = _row(controls)
	_button(tests,"Measure while I fly",func() -> void: start_benchmark(false))
	_button(tests,"Repeatable four-direction input",func() -> void: start_benchmark(true))
	_label(controls,"Scripted pilot: +X, -Y, -X, +Y, switching every 60 completed Rapier steps; same input sequence at every setting.")
	_output = TextEdit.new()
	_output.editable = false
	_output.custom_minimum_size.y = 105
	controls.add_child(_output)
	_status = _label(full,"Ready.")
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
	popup_centered_clamped(Vector2i(770,690),0.9)
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

func _refresh() -> void:
	if host == null or _status == null or _capturing: return
	var state: Dictionary = _sample()
	var pace: Dictionary = host.simulation_worker.engine_lab_pixel_pacing()
	_status.text = "FPS %.0f  |  native tick %d  |  Rapier step %d  |  render serial %d  |  Pixel target %dHz  |  guard vetoes %d" % [
		float(state.fps_now),int(state.native_ticks),int(state.rapier_steps),
		int(state.render_uploaded_serial),int(pace.target_hz),
		int(state.guard.get("budget_vetoes",0))]
