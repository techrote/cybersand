extends Window

# ENGINE-LAB-001: second-layer Workbench controls; no modal warnings.
# Only the explicitly saved native worker request persists between launches.
const LauncherSettings = preload("res://scripts/feature_launcher.gd")
const MAX_CAPTURE_FRAMES: int = 12000
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
var _default_render_hz: int = 60
var _default_pixel_hz: int = 60
var _default_sample_wake: bool = true
var _default_wait_sample: bool = true
var last_report: Dictionary = {}
var _capture_before: Dictionary = {}
var _capture_settings: Dictionary = {}
var _capture_identity: Dictionary = {}
var _capture_scripted: bool = false
var _capture_seconds: float = BENCH_SECONDS
var _capture_last_usec: int = 0
var _capture_last_uploads: int = 0
var _frame_intervals := PackedFloat64Array()
var _snapshot_ages := PackedFloat64Array()
var _displayed_ages := PackedFloat64Array()
var _main_times := PackedFloat64Array()
var _upload_times := PackedFloat64Array()

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
	_default_render_hz = host.render_snapshot_hz
	var initial_pacing: Dictionary = host.simulation_worker.engine_lab_pixel_pacing()
	_default_pixel_hz = int(initial_pacing.target_hz)
	_default_sample_wake = bool(initial_pacing.sample_wake)
	_default_wait_sample = host.engine_lab_wait_native_sample
	# Capture-only aggregation does no frame work during ordinary authoring.
	set_process(false)

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
	_note(controls,"Successful uploads are acknowledged immediately. Publication targets are separate from achieved frame and upload rates.")

	_section(controls,"PIXEL / RAPIER CLOCKS")
	_spin(controls,"pixel","Native Pixel target tick cadence (Hz)",
		1,240,_default_pixel_hz,func(value: int) -> void:
			host.simulation_worker.set_engine_lab_pixel_pacing(
				value,(_widgets["sample_wake"] as CheckButton).button_pressed))
	_spin(controls,"rapier","Rapier callback cadence (Hz)",
		1,240,Engine.physics_ticks_per_second,
		func(value: int) -> void: host.engine_lab_set_rapier_hz(value))
	_note(controls,"Each simulation/flight step retains fixed 1/60 seconds. Non-60 cadence changes wall-clock simulation speed.")
	_check(controls,"wait_sample","Rapier waits for native sample completion (default)",
		_default_wait_sample,func(value: bool) -> void: host.engine_lab_wait_native_sample = value)
	_check(controls,"sample_wake","Native worker wakes early on a new Rapier sample (default)",
		_default_sample_wake,func(value: bool) -> void:
			host.simulation_worker.set_engine_lab_pixel_pacing(
				int((_widgets["pixel"] as SpinBox).value),value))
	_note(controls,"Uncheck both to reduce clock coupling. Early sample wake can exceed the Pixel target; repeated samples and terrain installation can limit achieved rates.")

	_section(controls,"NATIVE WORKER TOPOLOGY (NEXT LAUNCH)")
	var saved: int = int(ProjectSettings.get_setting("cybersand/native_worker_threads",0))
	if FileAccess.file_exists(WORKER_PATH):
		var requested: int = LauncherSettings.engine_lab_worker_request(FileAccess.get_file_as_string(WORKER_PATH))
		if requested >= 0: saved = requested
	_spin(controls,"workers","Native worker count (0 = automatic)",
		0,32 if saved > 16 else 16,saved,func(_value: int) -> void: pass)
	_button(controls,"Save worker request for next launch",_save_workers)

	_section(controls,"OVERRIDES / QUICK PRESETS")
	_check(controls,"advanced","Advanced override — unlock up to 1000 Hz and 32 workers",
		saved > 16,func(value: bool) -> void:
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
	_note(controls,"Measure completed native ticks, Rapier steps, successful texture uploads, callback intervals and snapshot ages. Changing settings or session invalidates the comparison.")
	var tests: HBoxContainer = _row(controls)
	_button(tests,"Measure while I fly",func() -> void: start_benchmark(false))
	_button(tests,"Repeatable four-direction input",func() -> void: start_benchmark(true))
	_button(controls,"Stop benchmark",func() -> void: cancel_benchmark())
	_note(controls,"Scripted pilot: +X, -Y, -X, +Y, switching every 60 completed Rapier steps; same input sequence at every setting.")
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
	cancel_benchmark("Baseline restored during capture")
	_set_spin("fps",_default_fps)
	_set_spin("render",_default_render_hz)
	_set_spin("pixel",_default_pixel_hz)
	_set_spin("rapier",_default_rapier_hz)
	_set_toggle("wait_sample",_default_wait_sample)
	_set_toggle("sample_wake",_default_sample_wake)
	Engine.max_fps = _default_fps
	DisplayServer.window_set_vsync_mode(_default_vsync)
	(_widgets["vsync"] as OptionButton).select(
		_default_vsync if _default_vsync >= 0 and _default_vsync <= 2 else 1)
	host.engine_lab_set_render_hz(_default_render_hz)
	host.engine_lab_set_rapier_hz(_default_rapier_hz)
	host.engine_lab_wait_native_sample = _default_wait_sample
	host.simulation_worker.set_engine_lab_pixel_pacing(_default_pixel_hz,_default_sample_wake)
	_status.text = "Baseline rates and coupling restored. Saved worker setting unchanged."

func open() -> void:
	popup_centered_clamped(Vector2i(900,730),0.95)
	_refresh()

func _identity() -> Dictionary:
	return {"physical_epoch":host._physical_epoch,
		"session_object":host.physical_actor_session.get_instance_id() if host.physical_actor_session != null else 0,
		"session_epoch":host.physical_actor_session.epoch if host.physical_actor_session != null else 0,
		"uploaded_world_generation":host.last_uploaded_world_generation,
		"selected_actor":workbench.selected_id()}

func _sample() -> Dictionary:
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	var now: int = Time.get_ticks_usec()
	return {"time_usec":now,
		"process_frames":Engine.get_process_frames(),
		"physics_frames":Engine.get_physics_frames(),
		"native_ticks":int(snapshot.tick_index) if snapshot != null else -1,
		"rapier_steps":host.physical_actor_session.tick if host.physical_actor_session != null else -1,
		"render_uploaded_serial":host.last_uploaded_render_snapshot_serial,
		"successful_uploads":host.engine_lab_successful_uploads,
		"snapshot_serial":snapshot.serial if snapshot != null else -1,
		"snapshot_age_ms":maxf(0.0,float(now-snapshot.published_usec)/1000.0) if snapshot != null else null,
		"displayed_material_age_ms":maxf(0.0,float(now-host.engine_lab_uploaded_generated_usec)/1000.0) if host.engine_lab_uploaded_generated_usec > 0 else null,
		"worker_overruns":snapshot.worker_overruns if snapshot != null else -1,
		"worker_step_ms":snapshot.worker_step_time_ms if snapshot != null else null,
		"snapshot_publication_ms":snapshot.snapshot_publication_time_ms if snapshot != null else null,
		"native_backend":snapshot.backend_name if snapshot != null else "unavailable",
		"fps_now":Engine.get_frames_per_second(),
		"frame_time_ms":host.frame_time_ms}

func configuration() -> Dictionary:
	var pacing: Dictionary = host.simulation_worker.engine_lab_pixel_pacing()
	return {"fps_cap":Engine.max_fps,"vsync":int(DisplayServer.window_get_vsync_mode()),
		"rapier_target_hz":Engine.physics_ticks_per_second,
		"pixel_target_hz":pacing.target_hz,"native_wake_on_sample":pacing.sample_wake,
		"render_target_hz":host.render_snapshot_hz,
		"render_ack_policy":"mandatory_immediate_after_successful_upload",
		"rapier_waits_for_native_sample":host.engine_lab_wait_native_sample,
		"simulated_seconds_per_step":1.0/60.0,
		"native_workers_current_request":int(ProjectSettings.get_setting("cybersand/native_worker_threads",0)),
		"native_workers_next_launch":int((_widgets["workers"] as SpinBox).value)}

func start_benchmark(scripted: bool, seconds: float = BENCH_SECONDS) -> bool:
	if _capturing: return false
	if workbench.applied.is_empty() or host.paused or host.physical_actor_session == null \
			or host.simulation_worker.has_failed() or not host.pending_microscenario_apply.is_empty():
		_status.text = "Start Play in a stable session before capturing."
		return false
	if scripted and not host.engine_lab_set_scripted_input(true):
		_status.text = "Select a human-controlled flyer and start Play."
		return false
	_capture_seconds = clampf(seconds,0.25,60.0)
	_capture_scripted = scripted
	_capture_before = _sample()
	_capture_settings = configuration()
	_capture_identity = _identity()
	_capture_last_usec = int(_capture_before.time_usec)
	_capture_last_uploads = int(_capture_before.successful_uploads)
	_frame_intervals.clear()
	_snapshot_ages.clear()
	_displayed_ages.clear()
	_main_times.clear()
	_upload_times.clear()
	last_report.clear()
	_capturing = true
	host.engine_lab_measure_callbacks = true
	_status.text = "Recording %.1f seconds..." % _capture_seconds
	set_process(true)
	return true

func cancel_benchmark(reason: String = "Stopped by owner") -> void:
	if _capturing: _finish_benchmark(reason)

func _process(_delta: float) -> void:
	if not _capturing: return
	# Small copied counters only, and only while a bounded benchmark is active.
	# This is not #609's per-body pose trace and cannot establish GPU smoothness.
	if _identity() != _capture_identity:
		_finish_benchmark("Session, selection or World identity changed")
		return
	if host.paused or host.simulation_worker.has_failed() or not host.pending_microscenario_apply.is_empty():
		_finish_benchmark("Session paused, failed or began replacement")
		return
	if configuration() != _capture_settings:
		_finish_benchmark("Settings changed during capture")
		return
	if _capture_scripted and not host.engine_lab_scripted_input:
		_finish_benchmark("Scripted input lease ended")
		return
	if _frame_intervals.size() >= MAX_CAPTURE_FRAMES:
		_finish_benchmark("Capture frame capacity reached")
		return
	var now: int = Time.get_ticks_usec()
	_frame_intervals.append(float(now-_capture_last_usec)/1000.0)
	_capture_last_usec = now
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	if snapshot != null:
		_snapshot_ages.append(maxf(0.0,float(now-snapshot.published_usec)/1000.0))
	if host.engine_lab_uploaded_generated_usec > 0:
		_displayed_ages.append(maxf(0.0,float(now-host.engine_lab_uploaded_generated_usec)/1000.0))
	_main_times.append(host.engine_lab_main_callback_ms)
	if host.engine_lab_successful_uploads > _capture_last_uploads:
		_upload_times.append(host.upload_time_ms)
		_capture_last_uploads = host.engine_lab_successful_uploads
	if now-int(_capture_before.time_usec) >= int(_capture_seconds*1000000.0):
		_finish_benchmark("")

static func _distribution(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty(): return {"samples":0,"available":false}
	var ordered: PackedFloat64Array = values.duplicate()
	ordered.sort()
	return {"samples":ordered.size(),"available":true,
		"p50_ms":ordered[maxi(0,ceili(float(ordered.size())*0.50)-1)],
		"p95_ms":ordered[maxi(0,ceili(float(ordered.size())*0.95)-1)],
		"p99_ms":ordered[maxi(0,ceili(float(ordered.size())*0.99)-1)],
		"max_ms":ordered[-1]}

func _finish_benchmark(reason: String) -> void:
	if not _capturing: return
	_capturing = false
	set_process(false)
	host.engine_lab_measure_callbacks = false
	if _capture_scripted: host.engine_lab_set_scripted_input(false)
	var after: Dictionary = _sample()
	var elapsed: float = maxf(0.001,
		float(int(after.time_usec)-int(_capture_before.time_usec))/1000000.0)
	var counts: Dictionary = {}
	for key: String in ["process_frames","physics_frames","native_ticks",
			"rapier_steps","render_uploaded_serial","successful_uploads","worker_overruns"]:
		counts[key] = int(after[key])-int(_capture_before[key])
		if int(counts[key]) < 0 and reason.is_empty(): reason = "A monotonic counter restarted"
	var valid: bool = reason.is_empty()
	last_report = {"schema":"camera-stack-engine-lab-actual-clock-v2",
		"valid":valid,"invalid_reason":reason,
		"input_mode":"four_direction_60_steps_per_leg" if _capture_scripted else "manual",
		"elapsed_seconds":elapsed,"requested_seconds":_capture_seconds,
		"settings":_capture_settings,"settings_after":configuration(),
		"identity_before":_capture_identity,"identity_after":_identity(),
		"before":_capture_before,"after":after,"counts":counts,
		"render_callback_fps":float(counts.process_frames)/elapsed if valid else null,
		"native_actual_hz":float(counts.native_ticks)/elapsed if valid else null,
		"rapier_actual_hz":float(counts.rapier_steps)/elapsed if valid else null,
		"texture_upload_actual_hz":float(counts.successful_uploads)/elapsed if valid else null,
		"frame_interval":_distribution(_frame_intervals),
		"snapshot_age":_distribution(_snapshot_ages),
		"displayed_material_age":_distribution(_displayed_ages),
		"main_callback":_distribution(_main_times),
		"successful_upload_wall_time":_distribution(_upload_times),
		"unmeasured":["GPU present time","worker wait duration","worker backlog depth"],
		"runtime":{"os":OS.get_name(),"display_server":DisplayServer.get_name(),
			"godot":Engine.get_version_info().string,
			"source_commit":OS.get_environment("CYBERSAND_EVAL_SOURCE_SHA")}}
	var stamp: String = Time.get_datetime_string_from_system().replace(":","-")
	var filename: String = "user://engine-lab-"+stamp+"-"+str(Time.get_ticks_usec())+".json"
	var file: FileAccess = FileAccess.open(filename,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(last_report,"  ")+"\n")
		file.close()
	_output.text = JSON.stringify({"valid":valid,"reason":reason,
		"elapsed":elapsed,"render_callback_fps":last_report.render_callback_fps,
		"native_hz":last_report.native_actual_hz,"rapier_hz":last_report.rapier_actual_hz,
		"texture_upload_hz":last_report.texture_upload_actual_hz},"  ")
	_status.text = ("Saved " if valid else "Invalid comparison saved: ")+ProjectSettings.globalize_path(filename) if file != null else "Capture ended; file could not be saved"

func _refresh() -> void:
	if host == null or _status == null or _capturing: return
	var state: Dictionary = _sample()
	var pace: Dictionary = host.simulation_worker.engine_lab_pixel_pacing()
	_status.text = "FPS %.0f  |  native tick %d  |  Rapier step %d  |  uploads %d  |  Pixel target %dHz" % [
		float(state.fps_now),int(state.native_ticks),int(state.rapier_steps),
		int(state.successful_uploads),int(pace.target_hz)]
